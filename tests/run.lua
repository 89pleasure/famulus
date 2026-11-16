-- Loads Schnitzel against the mock client and exercises every feature.
-- Run from the repository root:  luajit tests/run.lua

package.path = "tests/?.lua;" .. package.path
local mock = require("wowmock")

local passed, failed = 0, 0

local function check(condition, description)
    if condition then
        passed = passed + 1
    else
        failed = failed + 1
        print("  FAIL: " .. description)
    end
end

local function section(title)
    print(title)
    mock.reset()
end

local function lastChat()
    return mock.chat[#mock.chat] or ""
end

local function setState(values)
    mock.state = values
end

---------------------------------------------------------------------------
section("Loading")
---------------------------------------------------------------------------

local framesBefore = #mock.frames
local ns, files = mock.LoadAddon("Schnitzel", "Schnitzel")
check(#files == 16, "TOC lists 16 Lua files (got " .. #files .. ")")
for _, file in ipairs(files) do
    local handle = io.open("Schnitzel/" .. file, "r")
    check(handle ~= nil, "TOC file exists: " .. file)
    if handle then
        handle:close()
    end
end
check(#mock.frames - framesBefore == 2, "loading creates only the event frame and the tween driver (got " .. (#mock.frames - framesBefore) .. ")")
check(ns:CountActiveFeatures() == 0, "no feature runs before login")

---------------------------------------------------------------------------
section("Localization")
---------------------------------------------------------------------------

local en, de = ns.locales.enUS, ns.locales.deDE
local function placeholders(text)
    local found = {}
    for spec in text:gmatch("%%[sd]") do
        found[#found + 1] = spec
    end
    return table.concat(found, ",")
end
for key, text in pairs(en) do
    check(de[key] ~= nil, "deDE has key " .. key)
    if de[key] then
        check(placeholders(text) == placeholders(de[key]), "same placeholders in " .. key)
    end
end
for key in pairs(de) do
    check(en[key] ~= nil, "deDE key also exists in enUS: " .. key)
end
for _, category in ipairs(ns.categories) do
    check(en["cat_" .. category] and en["cat_" .. category .. "_desc"], "category strings for " .. category)
end
for _, feature in ipairs(ns.featureList) do
    check(en["f_" .. feature.id] and en["f_" .. feature.id .. "_desc"], "feature strings for " .. feature.id)
    for _, option in ipairs(feature.options) do
        local key = "o_" .. feature.id .. "_" .. option.key
        check(en[key] and en[key .. "_desc"], "option strings for " .. key)
    end
    local known = false
    for _, category in ipairs(ns.categories) do
        known = known or category == feature.category
    end
    check(known, "feature " .. feature.id .. " is in a known category")
end

---------------------------------------------------------------------------
section("Login")
---------------------------------------------------------------------------

setState({})
mock.Fire("ADDON_LOADED", "SomeOtherAddon")
check(SchnitzelDB == nil, "other addons' ADDON_LOADED is ignored")
mock.Fire("ADDON_LOADED", "Schnitzel")
check(type(SchnitzelDB) == "table" and type(SchnitzelDB.profile) == "table", "database is created")
mock.Fire("PLAYER_LOGIN")

local active, total = ns:CountActiveFeatures()
check(total == 16, "16 features registered (got " .. total .. ")")
check(active == 3, "3 features on by default (got " .. active .. ")")
check(ns.features.fastLoot.enabled and ns.features.mapCoords.enabled and ns.features.chatArrowKeys.enabled, "the default-on features are the harmless ones")
check(ns:CountRegisteredEvents() == 1, "only LOOT_READY is registered after login (got " .. ns:CountRegisteredEvents() .. ")")
check(lastChat():find("/sz", 1, true) ~= nil, "first login prints the hint")
check(next(SchnitzelDB.profile) == nil, "nothing is saved while everything is on default")
check(mock.CountOnUpdateFrames() == 0, "no OnUpdate handler runs while idle (got " .. mock.CountOnUpdateFrames() .. ")")
check(mock.ActiveTimers() == 0, "no timer runs while idle")
check(mock.count("Settings.RegisterAddOnCategory") == 1, "entry in the game options is registered")

local function enable(id, value)
    ns:SetOption(id, "enabled", value ~= false)
end

---------------------------------------------------------------------------
section("Vendor: repair")
---------------------------------------------------------------------------

setState({ canRepair = true, repairCost = 1200, money = 5000 })
mock.Fire("MERCHANT_SHOW")
check(mock.count("RepairAllItems") == 0, "repair does nothing while switched off")

enable("autoRepair")
check(ns.features.autoRepair.enabled, "switching on works without reload")
mock.Fire("MERCHANT_SHOW")
check(mock.count("RepairAllItems") == 1, "repairs when the merchant opens")
check(lastChat():find("1200c", 1, true) ~= nil, "reports the cost")

mock.reset()
setState({ canRepair = true, repairCost = 1200, money = 100 })
mock.Fire("MERCHANT_SHOW")
check(mock.count("RepairAllItems") == 0, "does not repair without enough gold")
check(#mock.chat == 1, "says that gold is missing")

mock.reset()
setState({ canRepair = true, repairCost = 1200, money = 5000, shift = true })
mock.Fire("MERCHANT_SHOW")
check(mock.count("RepairAllItems") == 0, "pause key skips the repair")

mock.reset()
setState({ canRepair = true, repairCost = 1200, money = 5000, canGuildRepair = true })
ns:SetOption("autoRepair", "guildFunds", true)
mock.Fire("MERCHANT_SHOW")
check(mock.calls[1][1] == "RepairAllItems" and mock.calls[1][2] == true, "guild funds are used first")
mock.Advance(0.6)
check(mock.count("RepairAllItems") == 1 and lastChat():find("guild", 1, true) ~= nil, "guild repair is reported")

mock.reset()
setState({ canRepair = true, repairCost = 1200, money = 5000, canGuildRepair = true, guildRepairFails = true })
mock.Fire("MERCHANT_SHOW")
mock.Advance(0.6)
check(mock.count("RepairAllItems") == 2, "falls back to own gold when the guild does not pay")

mock.reset()
ns:SetOption("general", "chatOutput", false)
setState({ canRepair = true, repairCost = 50, money = 5000 })
ns:SetOption("autoRepair", "guildFunds", false)
mock.Fire("MERCHANT_SHOW")
check(mock.count("RepairAllItems") == 1 and #mock.chat == 0, "chat feedback can be switched off")
ns:SetOption("general", "chatOutput", true)

enable("autoRepair", false)
check(ns:CountRegisteredEvents() == 1, "switching off removes the event again")

---------------------------------------------------------------------------
section("Vendor: sell junk")
---------------------------------------------------------------------------

local function bags()
    return {
        [0] = {
            { itemID = 1, quality = 0, stackCount = 5, hyperlink = "junk1" },
            { itemID = 2, quality = 1, stackCount = 1, hyperlink = "white" },
            false,
            { itemID = 3, quality = 0, stackCount = 1, hyperlink = "worthless", hasNoValue = true },
        },
        [1] = {
            { itemID = 4, quality = 0, stackCount = 2, hyperlink = "junk2" },
            { itemID = 5, quality = 0, stackCount = 1, hyperlink = "locked", isLocked = true },
        },
    }
end
local prices = { junk1 = 10, junk2 = 100, locked = 7 }

enable("sellJunk")
setState({ bags = bags(), prices = prices })
MerchantFrame.shown = true
mock.Fire("MERCHANT_SHOW")
check(mock.count("UseContainerItem") == 0, "selling is spread over time, not done in one burst")
mock.Advance(1)
check(mock.count("UseContainerItem") == 2, "sells the two sellable grey items (got " .. mock.count("UseContainerItem") .. ")")
check(lastChat():find("2", 1, true) and lastChat():find("250c", 1, true), "reports count and value: " .. lastChat())
check(mock.ActiveTimers() == 0, "the sell ticker stops when done")

mock.reset()
setState({ bags = bags(), prices = prices })
mock.Fire("MERCHANT_SHOW")
mock.Advance(0.16)
MerchantFrame.shown = false
mock.Fire("MERCHANT_CLOSED")
mock.Advance(1)
check(mock.count("UseContainerItem") == 1, "stops selling when the merchant closes")
check(mock.ActiveTimers() == 0, "no ticker left after closing")

mock.reset()
setState({ bags = bags(), prices = prices })
MerchantFrame.shown = true
mock.Fire("MERCHANT_SHOW")
enable("sellJunk", false)
mock.Advance(1)
check(mock.count("UseContainerItem") == 0, "switching the feature off stops a running sale")
MerchantFrame.shown = false

---------------------------------------------------------------------------
section("Quests")
---------------------------------------------------------------------------

local gossip = {
    activeQuests = {
        { questID = 10, isComplete = false },
        { questID = 11, isComplete = true, repeatable = true },
        { questID = 12, isComplete = true },
    },
    availableQuests = {
        { questID = 20, isTrivial = true },
        { questID = 21, repeatable = true },
        { questID = 22 },
    },
}
setState(gossip)
mock.Fire("GOSSIP_SHOW")
check(#mock.calls == 0, "gossip is untouched while both quest features are off")

enable("autoAccept")
mock.Fire("GOSSIP_SHOW")
check(mock.count("SelectAvailableQuest") == 1 and mock.calls[1][2] == 22, "picks the first normal quest, skipping trivial and repeatable ones")

mock.reset()
ns:SetOption("autoAccept", "skipTrivial", false)
mock.Fire("GOSSIP_SHOW")
check(mock.calls[1][2] == 20, "trivial quests are taken when the option allows it")
ns:SetOption("autoAccept", "skipTrivial", true)

mock.reset()
enable("autoTurnIn")
mock.Fire("GOSSIP_SHOW")
check(#mock.calls == 1 and mock.calls[1][1] == "SelectActiveQuest" and mock.calls[1][2] == 12, "turn-in goes first and makes exactly one selection")

mock.reset()
setState({ questID = 30 })
mock.Fire("QUEST_DETAIL")
check(mock.count("AcceptQuest") == 1, "accepts an offered quest")
mock.reset()
setState({ questID = 30, shift = true })
mock.Fire("QUEST_DETAIL")
check(mock.count("AcceptQuest") == 0, "pause key lets the player read the quest")
setState({ questID = 30, pvpQuest = true })
mock.Fire("QUEST_DETAIL")
check(mock.count("AcceptQuest") == 0, "never accepts a PvP-flagging quest")
setState({ questID = 30, trivial = { [30] = true } })
mock.Fire("QUEST_DETAIL")
check(mock.count("AcceptQuest") == 0, "does not accept trivial quests")

mock.reset()
setState({ questID = 31, completable = true })
mock.Fire("QUEST_PROGRESS")
check(mock.count("CompleteQuest") == 1, "continues a completable quest")
mock.reset()
setState({ questID = 31, completable = true, questCost = 500 })
mock.Fire("QUEST_PROGRESS")
check(mock.count("CompleteQuest") == 0, "never hands in a quest that costs gold")
setState({ questID = 31, completable = true, repeatable = { [31] = true } })
mock.Fire("QUEST_PROGRESS")
check(mock.count("CompleteQuest") == 0, "never hands in a repeatable quest")

mock.reset()
setState({ questID = 31, choices = 1 })
mock.Fire("QUEST_COMPLETE")
check(mock.count("GetQuestReward") == 1, "takes the reward when there is nothing to choose")
mock.reset()
setState({ questID = 31, choices = 3 })
mock.Fire("QUEST_COMPLETE")
check(mock.count("GetQuestReward") == 0, "leaves the reward choice to the player")

enable("autoAccept", false)
check(ns:CountRegisteredEvents() == 5, "turn-in alone keeps the shared quest list events (got " .. ns:CountRegisteredEvents() .. ")")
enable("autoTurnIn", false)
check(ns:CountRegisteredEvents() == 1, "all quest events are gone when both are off (got " .. ns:CountRegisteredEvents() .. ")")

---------------------------------------------------------------------------
section("Loot and items")
---------------------------------------------------------------------------

setState({ lootItems = 4 })
mock.Advance(1)
mock.Fire("LOOT_READY")
check(mock.count("LootSlot") == 4, "fast loot takes every slot")
mock.Fire("LOOT_READY")
check(mock.count("LootSlot") == 4, "a repeated LOOT_READY within 0.3 s is ignored")
mock.reset()
mock.cvars.autoLootDefault = "0"
mock.Advance(1)
mock.Fire("LOOT_READY")
check(mock.count("LootSlot") == 0, "fast loot respects the auto-loot setting")
mock.cvars.autoLootDefault = "1"

enable("confirmBoP")
mock.reset()
setState({ inGroup = true })
mock.Fire("LOOT_BIND_CONFIRM", 2)
check(mock.count("ConfirmLootSlot") == 0, "bind-on-pickup stays a question in a group")
setState({})
mock.Fire("LOOT_BIND_CONFIRM", 2)
mock.Advance(0.05)
check(mock.count("ConfirmLootSlot") == 1 and mock.count("StaticPopup_Hide") == 1, "confirms and closes the popup when solo")
enable("confirmBoP", false)

enable("easyDelete")
local editBox = CreateFrame("EditBox")
local dialog = CreateFrame("Frame")
dialog.editBoxWidget = editBox
setState({ popups = { DELETE_GOOD_ITEM = dialog } })
mock.Fire("DELETE_ITEM_CONFIRM")
mock.Advance(0.05)
check(editBox:GetText() == "DELETE", "fills in the delete confirmation word")
enable("easyDelete", false)

---------------------------------------------------------------------------
section("Social")
---------------------------------------------------------------------------

enable("acceptInvites")
setState({})
mock.Fire("PARTY_INVITE_REQUEST", "Stranger", false, false, false, true, false, "Player-1-NOBODY")
check(mock.count("AcceptGroup") == 0, "invites from strangers stay untouched")
mock.Fire("PARTY_INVITE_REQUEST", "Friend", false, false, false, true, false, "Player-1-FRIEND")
check(mock.count("AcceptGroup") == 1, "accepts a friend's invite")
check(mock.count("StaticPopup_Hide") == 0, "does not close the popup before the group exists")
mock.Fire("GROUP_ROSTER_UPDATE")
check(mock.count("StaticPopup_Hide") == 1, "closes the popup once in the group")
mock.Fire("GROUP_ROSTER_UPDATE")
check(mock.count("StaticPopup_Hide") == 1, "and stops listening to roster updates")
mock.Fire("PARTY_INVITE_REQUEST", "Guildie", false, false, false, true, false, "Player-1-GUILD")
check(mock.count("AcceptGroup") == 2, "accepts a guild member's invite")
mock.Fire("PARTY_INVITE_REQUEST", "NoGuid")
check(mock.count("AcceptGroup") == 2, "an invite without sender id is left alone")
enable("acceptInvites", false)

enable("declineDuels")
mock.reset()
mock.Fire("DUEL_REQUESTED", "Rival")
mock.Advance(0.05)
check(mock.count("CancelDuel") == 1 and lastChat():find("Rival", 1, true) ~= nil, "declines duels and says who asked")
enable("declineDuels", false)

---------------------------------------------------------------------------
section("Tooltips")
---------------------------------------------------------------------------

check(#TooltipDataProcessor.postCalls == 0, "no tooltip hook is installed while the feature is off")
local lines = 0
GameTooltip.AddDoubleLine = function()
    lines = lines + 1
end
enable("tooltipIDs")
check(#TooltipDataProcessor.postCalls == 2, "item and spell hooks are installed on first use")
TooltipDataProcessor.postCalls[1].fn(GameTooltip, { id = 6948 })
check(lines == 1, "adds the ID line")
TooltipDataProcessor.postCalls[1].fn(CreateFrame("GameTooltip"), { id = 6948 })
check(lines == 1, "leaves other tooltips alone")
enable("tooltipIDs", false)
TooltipDataProcessor.postCalls[1].fn(GameTooltip, { id = 6948 })
check(lines == 1, "the hook is inert after switching off")
enable("tooltipIDs")
check(#TooltipDataProcessor.postCalls == 2, "switching on again does not hook twice")
enable("tooltipIDs", false)

local owners = 0
GameTooltip.SetOwner = function()
    owners = owners + 1
end
enable("tooltipCursor")
GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
check(owners == 1, "tooltip is re-anchored to the cursor")
enable("tooltipCursor", false)
GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
check(owners == 1, "and left alone when switched off")

---------------------------------------------------------------------------
section("Interface")
---------------------------------------------------------------------------

check(mock.CountOnUpdateFrames() == 0, "map coordinates do not update while the map is closed")
WorldMapFrame.shown = true
check(mock.CountOnUpdateFrames() == 1, "they update only while the map is open")
mock.Advance(0.3)
WorldMapFrame.shown = false
enable("mapCoords", false)
WorldMapFrame.shown = true
check(mock.CountOnUpdateFrames() == 0, "and not at all when switched off")
WorldMapFrame.shown = false
enable("mapCoords")

mock.reset()
enable("cameraZoom")
check(mock.cvars.cameraDistanceMaxZoomFactor == "2.6", "camera takes the highest factor the client accepts")
enable("cameraZoom", false)
check(mock.cvars.cameraDistanceMaxZoomFactor == "1.9", "switching off restores the player's own value")

local shown = {}
UIErrorsFrame.TryDisplayMessage = function(_, _, message)
    shown[#shown + 1] = message
end
enable("hideErrors")
check(not UIErrorsFrame.events.UI_ERROR_MESSAGE, "takes the error event away from the game's frame")
mock.Fire("UI_ERROR_MESSAGE", 1, ERR_OUT_OF_RAGE)
mock.Fire("UI_ERROR_MESSAGE", 1, "Inventory is full.")
check(#shown == 1 and shown[1] == "Inventory is full.", "hides spam, keeps real errors")
enable("hideErrors", false)
UIErrorsFrame.events.UI_ERROR_MESSAGE = nil
enable("hideErrors")
enable("hideErrors", false)
check(UIErrorsFrame.events.UI_ERROR_MESSAGE == true, "gives the event back when switched off")

enable("levelScreenshot")
mock.reset()
mock.Fire("PLAYER_LEVEL_UP", 12)
mock.Advance(2)
check(mock.count("Screenshot") == 1, "screenshot after level up")
enable("levelScreenshot", false)

---------------------------------------------------------------------------
section("Settings window")
---------------------------------------------------------------------------

check(SchnitzelOptionsFrame == nil, "the window does not exist before it is opened")
SlashCmdList.SCHNITZEL("")
local window = SchnitzelOptionsFrame
check(window ~= nil and window:IsShown(), "/sz opens the window")
mock.Advance(0.3)
check(window:GetAlpha() == 1, "fade-in finishes")
check(mock.CountOnUpdateFrames() == 0, "no animation keeps running afterwards (got " .. mock.CountOnUpdateFrames() .. ")")

-- Collect the row buttons and navigation buttons that were created.
local function visibleRows()
    local list = {}
    for _, frame in ipairs(mock.frames) do
        if frame.item and frame:IsVisible() then
            list[#list + 1] = frame
        end
    end
    return list
end
local function navButton(text)
    for _, frame in ipairs(mock.frames) do
        if frame.label and frame.bar and frame.label:GetText() == text then
            return frame
        end
    end
end

check(window.title:GetText() == "Vendors", "first page is Vendors")
local rows = visibleRows()
check(#rows == 3, "vendor page shows repair, its guild option and junk (got " .. #rows .. ")")

-- Toggle through the row itself.
mock.Click(rows[1])
check(ns.features.autoRepair.enabled, "clicking a row switches the feature on")
mock.Advance(0.3)
mock.Click(rows[1])
check(not ns.features.autoRepair.enabled, "and off again")
mock.Advance(0.3)

-- Every page renders, in both languages.
for _, language in ipairs({ "enUS", "deDE" }) do
    ns:SetOption("general", "language", language)
    mock.Advance(0.1)
    for _, page in ipairs({ "vendor", "quests", "loot", "social", "tooltip", "interface", "general", "about" }) do
        local button = navButton(ns.L["cat_" .. page])
        check(button ~= nil, "navigation entry for " .. page .. " in " .. language)
        if button then
            mock.Click(button)
            check(window.title:GetText() == ns.L["cat_" .. page], "page title for " .. page)
            check(#visibleRows() > 0, "page " .. page .. " has rows")
        end
    end
end
check(window.title:GetText() == "Über", "language switch applies immediately, without reload")

-- Search across pages.
window.search.edit:SetText("repar")
check(window.title:GetText() == "Suche" and #visibleRows() >= 1, "search finds the repair feature in German")
window.search.edit:SetText("zzzz")
check(#visibleRows() == 0, "search with no hit shows no rows")
window.search.edit:SetText("")
check(window.title:GetText() == "Über", "clearing the search returns to the page")

-- Reset page.
ns:SetOption("general", "language", "enUS")
mock.Advance(0.1)
mock.Click(navButton("Vendors"))
enable("autoRepair")
enable("sellJunk")
mock.Advance(0.1)
mock.Click(window.resetButton)
mock.Advance(0.1)
check(not ns.features.autoRepair.enabled and not ns.features.sellJunk.enabled, "reset page puts the page back to defaults")

-- Dropdown menu.
mock.Click(navButton("General"))
local generalRows = visibleRows()
mock.Click(generalRows[2]) -- pause key
mock.Advance(0.05)
local picked = false
for _, frame in ipairs(mock.frames) do
    if frame.value == "CTRL" and frame:IsVisible() then
        mock.Click(frame)
        picked = true
        break
    end
end
check(picked and ns:GetOption("general", "pauseModifier") == "CTRL", "dropdown changes the pause key")
ns:SetOption("general", "pauseModifier", "SHIFT")

-- Character profile.
enable("declineDuels")
mock.Click(generalRows[5])
mock.Advance(0.1)
check(ns:UsesCharacterProfile() and ns.features.declineDuels.enabled, "character profile starts as a copy")
enable("declineDuels", false)
mock.Click(generalRows[5])
mock.Advance(0.1)
check(not ns:UsesCharacterProfile() and ns.features.declineDuels.enabled, "switching back restores the account settings")
enable("declineDuels", false)

-- Minimap button.
check(SchnitzelMinimapButton ~= nil and SchnitzelMinimapButton:IsShown(), "minimap button exists")
ns:SetOption("general", "minimapButton", false)
check(not SchnitzelMinimapButton:IsShown(), "and can be hidden")
ns:SetOption("general", "minimapButton", true)

SlashCmdList.SCHNITZEL("")
check(not window:IsShown(), "/sz closes the window again")
mock.reset()
SlashCmdList.SCHNITZEL("status")
check(lastChat():find("3 of 16", 1, true) ~= nil, "/sz status reports: " .. lastChat())

---------------------------------------------------------------------------
section("Saved settings")
---------------------------------------------------------------------------

enable("sellJunk")
check(SchnitzelDB.profile.sellJunk and SchnitzelDB.profile.sellJunk.enabled == true, "a changed option is saved")
enable("sellJunk", false)
check(SchnitzelDB.profile.sellJunk == nil, "an option back on default is removed from the saved file")

---------------------------------------------------------------------------
print("")
if mock.errors then
    for _, message in ipairs(mock.errors) do
        print("  ERROR in handler: " .. message)
    end
    failed = failed + #mock.errors
end

local names = {}
for name in pairs(mock.undefinedGlobals) do
    names[#names + 1] = name
end
table.sort(names)
print("Optional globals probed (missing in the mock): " .. table.concat(names, ", "))
print(string.format("%d checks passed, %d failed", passed, failed))
os.exit(failed == 0 and 0 or 1)
