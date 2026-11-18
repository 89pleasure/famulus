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
local listed = {}
for _, file in ipairs(files) do
    listed[file] = true
    local handle = io.open("Schnitzel/" .. file, "r")
    check(handle ~= nil, "TOC file exists: " .. file)
    if handle then
        handle:close()
    end
end
-- Lists the Lua files below a directory, relative to it and with forward slashes. io.popen runs
-- cmd.exe on Windows and sh elsewhere, so each gets its own command.
local function luaFilesIn(directory)
    local found = {}
    if package.config:sub(1, 1) == "\\" then
        -- "cd" prints the directory first; "dir /s /b" then prints absolute paths below it.
        local pipe = io.popen('cd "' .. directory .. '" && cd && dir /s /b /a-d *.lua')
        local root = pipe:read("*l")
        for line in pipe:lines() do
            if root and line:sub(1, #root + 1):lower() == (root .. "\\"):lower() then
                found[#found + 1] = line:sub(#root + 2):gsub("\\", "/")
            end
        end
        pipe:close()
    else
        local pipe = io.popen("cd '" .. directory .. "' && find . -name '*.lua'")
        for line in pipe:lines() do
            found[#found + 1] = line:gsub("^%./", "")
        end
        pipe:close()
    end
    table.sort(found)
    return found
end

local onDisk = luaFilesIn("Schnitzel")
check(#onDisk > 0, "the Lua files in the addon folder can be listed")
for _, file in ipairs(onDisk) do
    check(listed[file] or listed[file:gsub("/", "\\")], "Lua file is listed in the TOC: " .. file)
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
section("File layout")
---------------------------------------------------------------------------
-- One feature per file: Modules/<Category>/<Id>.lua, both capitalized.

local function capitalize(text)
    return text:sub(1, 1):upper() .. text:sub(2)
end

local function readFile(path)
    local handle = io.open(path, "r")
    if not handle then
        return nil
    end
    local text = handle:read("*a")
    handle:close()
    return text
end

for _, feature in ipairs(ns.featureList) do
    local file = "Modules/" .. capitalize(feature.category) .. "/" .. capitalize(feature.id) .. ".lua"
    local source = readFile("Schnitzel/" .. file)
    check(listed[file] and source and source:find('id = "' .. feature.id .. '"', 1, true),
        "feature " .. feature.id .. " lives in " .. file)
end
-- Every other Lua file is a service: named <Name>Service.lua, it declares no
-- feature and publishes exactly the table ns.<Name>Service.
for _, file in ipairs(files) do
    local source = readFile("Schnitzel/" .. file)
    local _, declared = source:gsub("ns:NewFeature%(", "")
    local service = file:match("([%w]+Service)%.lua$")
    if service then
        check(declared == 0, "service declares no feature: " .. file)
        check(type(ns[service]) == "table", "service publishes ns." .. service)
    elseif file:match("^Modules/") then
        check(declared == 1, "a module file is exactly one feature or a *Service.lua: " .. file .. " (declares " .. declared .. ")")
    end
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
check(total == 20, "20 features registered (got " .. total .. ")")
check(active == 6, "6 features on by default (got " .. active .. ")")
for _, feature in ipairs(ns.featureList) do
    local harmless = feature.id == "mapCoords" or feature.id == "chatArrowKeys" or feature.category == "aliases"
    check(feature.enabled == harmless, "only the harmless features are on by default: " .. feature.id)
end
check(ns:CountRegisteredEvents() == 0, "no game event is registered after login (got " .. ns:CountRegisteredEvents() .. ")")
check(mock.cvars.autoLootDefault == "0" and mock.count("SetCVar") == 0, "a fresh install changes no game setting")
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
check(ns:CountRegisteredEvents() == 0, "switching off removes the event again")

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
check(ns:CountRegisteredEvents() == 4, "turn-in alone keeps the shared quest list events (got " .. ns:CountRegisteredEvents() .. ")")
enable("autoTurnIn", false)
check(ns:CountRegisteredEvents() == 0, "all quest events are gone when both are off (got " .. ns:CountRegisteredEvents() .. ")")

---------------------------------------------------------------------------
section("Loot and items")
---------------------------------------------------------------------------

mock.cvars.autoLootDefault = "0"
local eventsBeforeLoot = ns:CountRegisteredEvents()
enable("autoLoot")
check(mock.cvars.autoLootDefault == "1", "auto loot switches on the game's option")
check(ns:CountRegisteredEvents() == eventsBeforeLoot, "and listens to nothing")
enable("autoLoot", false)
check(mock.cvars.autoLootDefault == "0", "switching off clears the game's option as well")

-- Changed in the game's options: the switch follows when the window opens
-- (and at login), without writing the option back.
mock.cvars.autoLootDefault = "1"
mock.reset()
ns:Fire("OPTIONS_SHOWN")
check(ns.features.autoLoot.enabled and ns:GetOption("autoLoot", "enabled") == true, "the switch shows the game's option once it was switched on there")
check(mock.count("SetCVar") == 0, "following the game writes nothing")
mock.cvars.autoLootDefault = "0"
ns:Fire("OPTIONS_SHOWN")
check(not ns.features.autoLoot.enabled and ns:GetOption("autoLoot", "enabled") == false, "and once it was switched off there")
check(mock.count("SetCVar") == 0, "still without writing")
mock.SetGameOption("autoLootDefault", "1")
check(ns.features.autoLoot.enabled, "the switch follows the game's options at once, with the window open")
mock.SetGameOption("autoLootDefault", "0")
check(not ns.features.autoLoot.enabled and mock.count("SetCVar") == 0, "both ways, without writing")

-- The category switch stops the feature but leaves the game's option alone.
enable("autoLoot")
ns:SetOption("categories", "loot", false)
check(not ns.features.autoLoot.enabled and mock.cvars.autoLootDefault == "1", "switching the loot category off keeps the game's auto loot")
ns:SetOption("categories", "loot", true)
check(ns.features.autoLoot.enabled and mock.cvars.autoLootDefault == "1", "switching it on again changes nothing either")
enable("autoLoot", false)
check(mock.cvars.autoLootDefault == "0", "only the feature's own switch clears it")

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
section("Aliases")
---------------------------------------------------------------------------

local Aliases = ns.AliasService
local aliasEvents = 0
ns:On("ALIASES_CHANGED", function()
    aliasEvents = aliasEvents + 1
end)
setState({})
check(Aliases.Count() == 0 and SchnitzelDB.aliases == nil, "a fresh install has no aliases and saves none")
check(mock.CountSenderFilters() == 1, "the chat filter is installed while the feature is on")
check(mock.SenderName("CHAT_MSG_SAY", "|cff3fc7ebJaina-Proudmoore|r", "Jaina-Proudmoore") == "|cff3fc7ebJaina-Proudmoore|r",
    "without an alias a sender keeps their name")

check(Aliases.Set("Jaina Proudmoore", "  Anna ") and Aliases.Count() == 1 and aliasEvents == 1, "an alias can be set and is announced")
check(SchnitzelDB.aliases["jaina-proudmoore"].alias == "Anna" and SchnitzelDB.profile.aliases == nil,
    "it is saved account-wide, outside the profile, without surrounding blanks")
check(not Aliases.Set("Jaina Proudmoore", "Anna") and aliasEvents == 1, "setting the same alias again changes nothing")
check(Aliases.Get("Jaina", "Proudmoore") == "Anna", "found by first name and surname")
check(Aliases.Get("Jaina-Proudmoore") == "Anna" and Aliases.Get("jaina proudmoore") == "Anna", "and by the full name in any spelling")
check(Aliases.Get("Jaina") == nil and Aliases.Get(nil) == nil and Aliases.Get("") == nil, "other names have none")

check(mock.SenderName("CHAT_MSG_SAY", "|cff3fc7ebJaina-Proudmoore|r", "Jaina-Proudmoore") == "|cff3fc7ebAnna|r",
    "chat shows the alias inside the class colour")
check(mock.SenderName("CHAT_MSG_SAY", "Jaina-Proudmoore", "Jaina-Proudmoore") == "Anna", "and without a colour")
check(mock.SenderName("CHAT_MSG_SAY", "Thrall", "Thrall") == "Thrall", "other senders are untouched")
ns:SetOption("chatAliases", "style", "both")
check(mock.SenderName("CHAT_MSG_SAY", "|cff3fc7ebJaina-Proudmoore|r", "Jaina-Proudmoore") == "|cff3fc7ebAnna (Jaina-Proudmoore)|r",
    "the alias can be shown with the name behind it")
ns:SetOption("chatAliases", "style", "alias")
Ambiguate = function(name)
    return (name:gsub("%-Proudmoore$", ""))
end
check(mock.SenderName("CHAT_MSG_GUILD", "|cff3fc7ebJaina|r", "Jaina-Proudmoore") == "|cff3fc7ebAnna|r",
    "a name the chat shortened is replaced as well")
Ambiguate = nil
issecretvalue = function(value)
    return value == "SECRET"
end
check(mock.SenderName("CHAT_MSG_SAY", "SECRET", "SECRET") == "SECRET" and Aliases.Get("SECRET") == nil, "secret names are passed through untouched")
issecretvalue = nil
enable("chatAliases", false)
check(mock.CountSenderFilters() == 0, "switching off removes the chat filter")
check(mock.SenderName("CHAT_MSG_SAY", "Jaina-Proudmoore", "Jaina-Proudmoore") == "Jaina-Proudmoore", "and names are back")
enable("chatAliases")
check(mock.CountSenderFilters() == 1, "switching on again installs it once")

check(Aliases.Set("Thrall", "|cffff0000Bo|r|Hx|hss") and Aliases.Get("Thrall") == "cffff0000BorHxhss", "an alias cannot carry colours or links")
check(Aliases.Set("Thrall", string.rep("ä", 40)) and #Aliases.Get("Thrall") == 48, "a long alias is cut at a whole character")
Aliases.Set("Thrall", "Boss")
check(Aliases.List()[1].alias == "Anna" and Aliases.List()[2].alias == "Boss" and #Aliases.List() == 2, "the list is sorted by alias")
check(not Aliases.Set("", "x") and not Aliases.Set("  ", "x") and not Aliases.Set(nil, "x"), "an alias needs a name")

-- Tooltip
local aliasLines = {}
GameTooltip.AddDoubleLine = function(_, left, right)
    aliasLines[#aliasLines + 1] = left .. "=" .. right
end
local unitHook = TooltipDataProcessor.postCalls[1]
check(#TooltipDataProcessor.postCalls == 1 and unitHook.dataType == Enum.TooltipDataType.Unit, "one tooltip hook for units")
setState({ tooltipUnit = "mouseover", units = {
    mouseover = { name = "Jaina", surname = "Proudmoore", isPlayer = true },
    target = { name = "Thrall", isPlayer = false },
} })
unitHook.fn(GameTooltip, {})
check(#aliasLines == 1 and aliasLines[1] == "Alias=Anna", "a player's tooltip gets the alias line")
unitHook.fn(CreateFrame("GameTooltip"), {})
check(#aliasLines == 1, "other tooltips are left alone")
mock.state.tooltipUnit = "target"
unitHook.fn(GameTooltip, {})
check(#aliasLines == 1, "a creature with the same name as a player gets none")
mock.state.tooltipUnit = "mouseover"
enable("tooltipAliases", false)
unitHook.fn(GameTooltip, {})
check(#aliasLines == 1, "switched off, the tooltip hook is silent")
enable("tooltipAliases")
check(#TooltipDataProcessor.postCalls == 1, "switching on again does not hook twice")

-- Context menu
local function menuTexts(entries)
    local texts = {}
    for i, entry in ipairs(entries) do
        texts[i] = entry.text
    end
    return table.concat(texts, "|")
end
local entries = mock.OpenMenu("MENU_UNIT_FRIEND", { name = "Varian", surname = "Wrynn" })
check(menuTexts(entries) == "-|Set alias", "a player without alias gets one entry: " .. menuTexts(entries))
entries = mock.OpenMenu("MENU_UNIT_TARGET", { unit = "mouseover", name = "Jaina", surname = "Proudmoore" })
check(menuTexts(entries) == "-|Change alias|Remove alias", "a player with alias can change or remove it: " .. menuTexts(entries))
check(#mock.OpenMenu("MENU_UNIT_TARGET", { unit = "target", name = "Thrall" }) == 0, "creatures get no entry")
check(#mock.OpenMenu("MENU_UNIT_FRIEND", { name = "Someone", bnetIDAccount = 7 }) == 0, "nor do Battle.net accounts")
check(#mock.OpenMenu("MENU_UNIT_FRIEND", {}) == 0, "nor a menu without a name")
check(Menu.callbacks.MENU_UNIT_BN_FRIEND == nil and Menu.callbacks.MENU_UNIT_SELF == nil, "menus that are not about another character are not touched")
mock.reset()
entries[3].click()
check(Aliases.Get("Jaina Proudmoore") == nil and lastChat():find("Jaina Proudmoore", 1, true) ~= nil, "removing from the menu works and is reported in one line")
enable("aliasMenu", false)
check(#mock.OpenMenu("MENU_UNIT_FRIEND", { name = "Varian", surname = "Wrynn" }) == 0, "switched off, the menus stay as they are")
enable("aliasMenu")

-- Guildy: its name formatter shows the alias wherever Guildy draws a name.
local guildy = ns.features.guildyAliases
local Format = GuildyAPI.formatters.Schnitzel
check(guildy.enabled and type(Format) == "function", "with Guildy loaded, the formatter is registered at login")
check(Format("Thrall") == "Boss" and Format("Varian Wrynn") == nil, "Guildy shows the alias, other names stay")
local refreshes = GuildyAPI.refreshes
ns:SetOption("guildyAliases", "style", "both")
check(Format("Thrall") == "Boss (Thrall)" and GuildyAPI.refreshes == refreshes + 1, "the display option applies and redraws Guildy")
ns:SetOption("guildyAliases", "style", "alias")
refreshes = GuildyAPI.refreshes
Aliases.Set("Varian Wrynn", "King")
check(Format("Varian Wrynn") == "King" and GuildyAPI.refreshes == refreshes + 1, "a new alias redraws Guildy")
Aliases.Set("Varian Wrynn", nil)
enable("guildyAliases", false)
check(GuildyAPI.formatters.Schnitzel == nil, "switching off unregisters the formatter")
refreshes = GuildyAPI.refreshes
Aliases.Set("Varian Wrynn", "King")
Aliases.Set("Varian Wrynn", nil)
check(GuildyAPI.refreshes == refreshes, "switched off, alias changes leave Guildy alone")
enable("guildyAliases")
check(GuildyAPI.formatters.Schnitzel ~= nil, "switching on registers it again")
-- Without Guildy the feature stays off and the window does not list it.
mock.loadedAddons.Guildy = nil
guildy.available = nil
check(not guildy:IsShown() and not guildy:IsAvailable() and guildy.missing == "addon Guildy", "without Guildy the feature is not available")
ns:SyncFeature(guildy)
check(not guildy.enabled and GuildyAPI.formatters.Schnitzel == nil, "and does not run")
mock.loadedAddons.Guildy = true
guildy.available = nil
ns:SyncFeature(guildy)
check(guildy.enabled, "with Guildy back it runs again")

-- The category switch stops all of them; the list itself stays.
ns:SetOption("categories", "aliases", false)
check(mock.CountSenderFilters() == 0 and #mock.OpenMenu("MENU_UNIT_FRIEND", { name = "Thrall" }) == 0, "the category switch stops the alias features")
check(GuildyAPI.formatters.Schnitzel == nil, "including the Guildy formatter")
check(Aliases.Count() == 1, "but keeps the list")
ns:SetOption("categories", "aliases", true)
check(mock.SenderName("CHAT_MSG_SAY", "Thrall", "Thrall") == "Boss", "and everything resumes")

-- Loading a saved list, including one that was edited by hand.
SchnitzelDB.aliases = { thrall = { name = "Thrall", alias = "Boss" }, broken = "x", [5] = { name = "a", alias = "b" } }
ns:Fire("DATABASE_READY")
check(Aliases.Count() == 1 and Aliases.Get("Thrall") == "Boss" and SchnitzelDB.aliases.broken == nil, "a saved list is read, broken entries are dropped")
Aliases.Set("Thrall", nil)
check(Aliases.Count() == 0 and SchnitzelDB.aliases == nil, "an empty list is not saved")
check(ns:CountRegisteredEvents() == 0 and mock.ActiveTimers() == 0, "the alias features need no game event and no timer")
GameTooltip.AddDoubleLine = nil
setState({})

---------------------------------------------------------------------------
section("Tooltips")
---------------------------------------------------------------------------

-- The alias line (on by default) installed the first hook at login.
check(#TooltipDataProcessor.postCalls == 1, "no item or spell hook is installed while the feature is off")
table.remove(TooltipDataProcessor.postCalls, 1)
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
enable("tooltipCursor")
GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
check(owners == 2, "switching on again does not hook twice")
enable("tooltipCursor", false)

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

local coordFrame
for _, frame in ipairs(mock.frames) do
    if frame.parent == WorldMapFrame and frame.scripts.OnUpdate then
        coordFrame = frame
    end
end
check(coordFrame and coordFrame.mouseEnabled == true, "the coordinate field takes clicks by default")

local function coordWidthAt(x, y)
    local original = C_Map.GetPlayerMapPosition
    C_Map.GetPlayerMapPosition = function()
        return x and { GetXY = function() return x, y end } or nil
    end
    coordFrame.scripts.OnShow(coordFrame)
    C_Map.GetPlayerMapPosition = original
    return coordFrame:GetWidth()
end
local wideWidth = coordWidthAt(0.4567, 0.1234)
check(coordWidthAt(0.05, 0.07) == wideWidth and coordWidthAt(nil) == wideWidth,
    "the field keeps its width whatever the numbers are")
coordFrame.scripts.OnEnter(coordFrame)
coordFrame.scripts.OnLeave(coordFrame)
mock.reset()
setState({})
coordFrame.scripts.OnMouseUp(coordFrame, "LeftButton")
check(mock.count("ChatFrameUtil.OpenChat") == 1 and mock.calls[#mock.calls][2] == "Elwynn Forest 45.7, 12.3",
    "a click opens the chat input with zone and player position")
mock.reset()
setState({ chatOpen = true })
coordFrame.scripts.OnMouseUp(coordFrame, "LeftButton")
check(mock.count("ChatFrameUtil.InsertLink") == 1 and mock.count("ChatFrameUtil.OpenChat") == 0,
    "an open chat input gets the position at its cursor")
-- The click takes the focus from an empty chat input; the game then closes
-- the input and resets its chat type before our click handler runs.
mock.reset()
setState({})
local yellBox = CreateFrame("EditBox")
yellBox.attributes = { chatType = "YELL" }
coordFrame.scripts.OnEnter(coordFrame)
EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusLost", yellBox)
coordFrame.scripts.OnMouseUp(coordFrame, "LeftButton")
check(mock.calls[#mock.calls][1] == "ChatFrameUtil.OpenChat" and mock.calls[#mock.calls][2] == "/y Elwynn Forest 45.7, 12.3",
    "a chat input closed by the click is reopened with its chat type (got " .. tostring(mock.calls[#mock.calls][2]) .. ")")
coordFrame.scripts.OnLeave(coordFrame)
local coordCallbacks = 0
for _, owners in pairs(EventRegistry.callbacks) do
    if owners[ns.features.mapCoords] then
        coordCallbacks = coordCallbacks + 1
    end
end
check(coordCallbacks == 0, "the field listens to the chat input only while hovered")
mock.reset()
coordFrame.scripts.OnEnter(coordFrame)
coordFrame.scripts.OnMouseUp(coordFrame, "LeftButton")
check(mock.calls[#mock.calls][2] == "Elwynn Forest 45.7, 12.3", "a remembered chat type is forgotten after leaving the field")
coordFrame.scripts.OnLeave(coordFrame)
mock.reset()
coordFrame.scripts.OnMouseUp(coordFrame, "RightButton")
check(#mock.calls == 0, "only the left button inserts")
C_ChatInfo = { InChatMessagingLockdown = function() return true end }
coordFrame.scripts.OnMouseUp(coordFrame, "LeftButton")
check(#mock.calls == 0, "nothing is inserted during chat lockdown")
C_ChatInfo = nil
ns:SetOption("mapCoords", "clickToChat", false)
check(coordFrame.mouseEnabled == false and coordFrame.scripts.OnMouseUp == nil,
    "with the option off the field leaves clicks to the map")
ns:SetOption("mapCoords", "clickToChat", true)
check(coordFrame.mouseEnabled == true, "and takes them again when it is back on")

check(ChatFrame1EditBox:GetAltArrowKeyMode() == false and ChatFrame2EditBox:GetAltArrowKeyMode() == false, "chat arrow keys work without Alt after login")
ChatFrame1EditBox:SetAltArrowKeyMode(true)
EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusGained", ChatFrame1EditBox)
check(ChatFrame1EditBox:GetAltArrowKeyMode() == false, "a reset mode is fixed again when the chat box gets focus")
local whisperBox = CreateFrame("EditBox", "ChatFrame11EditBox")
whisperBox.altArrowKeyMode = true
EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusGained", whisperBox)
check(whisperBox:GetAltArrowKeyMode() == false, "chat windows opened after login are covered as well")
enable("chatArrowKeys", false)
check(ChatFrame1EditBox:GetAltArrowKeyMode() == true and whisperBox:GetAltArrowKeyMode() == true, "switching off gives every touched chat box its Alt mode back")
local chatCallbacksLeft = 0
for _, owners in pairs(EventRegistry.callbacks) do
    if owners[ns.features.chatArrowKeys] then
        chatCallbacksLeft = chatCallbacksLeft + 1
    end
end
check(chatCallbacksLeft == 0, "EventRegistry callbacks are removed when switched off (got " .. chatCallbacksLeft .. ")")
whisperBox.altArrowKeyMode = true
EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusGained", whisperBox)
check(whisperBox:GetAltArrowKeyMode() == true, "and focus no longer changes anything")
enable("chatArrowKeys")
check(ChatFrame2EditBox:GetAltArrowKeyMode() == false, "switching on again applies at once")

-- Chat history: Enter remembers the line, Up and Down step through it.
local chatBox = ChatFrame1EditBox
local function press(key)
    chatBox.scripts.OnKeyDown(chatBox, key)
end
local function send(text, attributes)
    chatBox.attributes = attributes or { chatType = "SAY" }
    chatBox:SetText(text)
    press("ENTER")
    mock.Advance(0.1)
    chatBox:SetText("")
end
press("UP")
check(chatBox:GetText() == "", "Up does nothing while nothing was sent")
send("hello there")
send("/cast Fireball")
send("/dance")
send("see you", { chatType = "WHISPER", tellTarget = "Thrall" })
check((chatBox.historyCleared or 0) > 0, "the client's own history is emptied so it cannot compete")
chatBox:SetText("half typed")
press("UP")
check(chatBox:GetText() == "/w Thrall see you", "Up brings back the last line with its whisper target")
check(chatBox.cursor == #"/w Thrall see you", "with the cursor at the end")
press("UP")
check(chatBox:GetText() == "/dance", "harmless commands are kept")
press("UP")
check(chatBox:GetText() == "/s hello there", "secure commands such as /cast are skipped")
press("UP")
check(chatBox:GetText() == "/s hello there", "Up stops at the oldest line")
press("DOWN")
press("DOWN")
press("DOWN")
check(chatBox:GetText() == "half typed", "Down past the newest line gives back what was typed")
chatBox.attributes = { chatType = "SAY" }
chatBox:SetText("from the game")
EventRegistry:TriggerEvent("ChatFrame.OnEditBoxPreSendText", chatBox)
mock.Advance(0.1)
chatBox:SetText("")
press("UP")
check(chatBox:GetText() == "/s from the game", "a send announced by the game is remembered as well")
EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusLost", chatBox)
send("twice")
send("twice")
press("UP")
press("UP")
check(chatBox:GetText() == "/s from the game", "the same line twice in a row is kept once")
EventRegistry:TriggerEvent("ChatFrame.OnEditBoxFocusLost", chatBox)
chatBox:SetText("")
AutoCompleteBox.shown, AutoCompleteBox.parent = true, chatBox
press("UP")
check(chatBox:GetText() == "", "the arrows belong to the name list while it is open")
AutoCompleteBox.shown, AutoCompleteBox.parent = false, nil
enable("chatArrowKeys", false)
press("UP")
check(chatBox:GetText() == "", "switched off, the hook stays silent")
enable("chatArrowKeys")
press("UP")
check(chatBox:GetText() ~= "", "switched on again, the lines are still there")
chatBox:SetText("")
chatBox.attributes = nil

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
mock.reset()
mock.Fire("PLAYER_LEVEL_UP", 13)
enable("levelScreenshot", false)
mock.Advance(2)
check(mock.count("Screenshot") == 0, "a delayed call is dropped when the feature is switched off")
enable("levelScreenshot")
mock.Fire("PLAYER_LEVEL_UP", 14)
enable("levelScreenshot", false)
enable("levelScreenshot")
mock.Advance(2)
check(mock.count("Screenshot") == 0, "and also when it was switched off and on again in the meantime")
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
local optionRow = rows[2]
local function isFolded(row)
    return row.item.child and not row.desc:IsShown() and row.height < rows[1].height
end
check(isFolded(optionRow), "the option of a switched-off feature is a slim row without help text")
check(optionRow.disabled and optionRow.toggle:IsShown() and not optionRow.toggle.on, "it is greyed out but shows its value")
ns:SetOption("autoRepair", "guildFunds", true)
mock.Advance(0.3)
check(optionRow.toggle.on and isFolded(optionRow), "a chosen value shows while folded as well")
mock.Click(optionRow)
check(ns:GetOption("autoRepair", "guildFunds") == true, "and clicks on it do nothing")
ns:SetOption("autoRepair", "guildFunds", false)
mock.Advance(0.3)
check(window.resetButton:IsShown() and window.resetButton.disabled, "reset is greyed out while the page is on its defaults")
mock.Click(window.resetButton)
check(window.resetButton.label:GetText() == "Reset page", "and a click on it does nothing")
local master = window.master
check(master:IsShown() and master.toggle.on and master.caption:GetText() == "ON", "the header carries the category's master switch, labelled ON")
check(window.subtitle:GetText() == ns.L.cat_vendor_desc, "the subtitle describes the page")

-- Toggle through the row itself.
mock.Click(rows[1])
check(ns.features.autoRepair.enabled, "clicking a row switches the feature on")
mock.Advance(0.3)
check(#visibleRows() == 3 and not isFolded(optionRow) and optionRow.desc:IsShown(), "its option unfolds with its help text")
check(not optionRow.disabled, "and can be used")
check(not window.resetButton.disabled, "reset becomes available once something differs from the defaults")

-- Master switch: everything on the page stops, the choices stay.
local eventsWithRepair = ns:CountRegisteredEvents()
mock.Click(master)
mock.Advance(0.3)
check(not ns:IsCategoryEnabled("vendor") and not ns.features.autoRepair.enabled, "the master switch stops the features of its category")
check(ns:CountRegisteredEvents() == eventsWithRepair - 1, "and their game events are unregistered")
check(ns:GetOption("autoRepair", "enabled") == true, "the feature's own setting is kept")
check(not master.toggle.on and master.caption:GetText() == "OFF", "the switch in the header reads OFF")
check(window.subtitle:GetText() == ns.L.cat_vendor_desc, "the subtitle keeps describing the page")
check(rows[1].disabled and rows[1].toggle.on, "feature rows are greyed out but still show the choice")
check(navButton("Vendors").count:GetText() == "OFF", "the sidebar shows the category as OFF")
check(navButton("Vendors").label:GetAlpha() < 1 and navButton("Quests").label:GetAlpha() == 1, "and greys out its entry, but no other")
check(SchnitzelDB.profile.categories.vendor == false, "the switch is saved")
setState({ canRepair = true, repairCost = 1200, money = 5000 })
mock.Fire("MERCHANT_SHOW")
check(mock.count("RepairAllItems") == 0, "nothing of a switched-off category reacts to the game")
enable("sellJunk")
check(not ns.features.sellJunk.enabled, "a feature cannot be started while its category is off")
enable("sellJunk", false)
check(ns.features.mapCoords.enabled, "other categories keep running")
mock.Click(master)
mock.Advance(0.3)
check(ns.features.autoRepair.enabled and SchnitzelDB.profile.categories == nil, "switching the category on again resumes the features")
check(navButton("Vendors").count:GetText() == "1/2" and navButton("Vendors").label:GetAlpha() == 1, "and the sidebar entry is back to normal")
check(master.toggle.on and master.caption:GetText() == "ON", "as is the header")

mock.Click(rows[1])
check(not ns.features.autoRepair.enabled, "and off again")
mock.Advance(0.3)
check(#visibleRows() == 3 and isFolded(optionRow) and optionRow.disabled, "which folds the option again")
check(window.resetButton.disabled, "back on defaults, reset is greyed out again")
mock.Click(master)
mock.Advance(0.3)
check(not window.resetButton.disabled, "a switched-off category alone makes the page resettable")
mock.Click(master)
mock.Advance(0.3)
window.scroll:SetVerticalScroll(30)
mock.Click(rows[1])
mock.Advance(0.3)
check(window.scroll:GetVerticalScroll() == 30, "unfolding does not make the page jump")
mock.Click(rows[1])
mock.Advance(0.3)
window.scroll:SetVerticalScroll(0)

-- Every page renders, in both languages.
for _, language in ipairs({ "enUS", "deDE" }) do
    ns:SetOption("general", "language", language)
    mock.Advance(0.1)
    for _, page in ipairs({ "vendor", "quests", "loot", "social", "aliases", "tooltip", "interface", "general", "about" }) do
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
check(not window.master:IsShown(), "pages without features have no master switch")

-- Search across pages.
window.search.edit:SetText("repar")
check(window.title:GetText() == "Suche" and #visibleRows() >= 1, "search finds the repair feature in German")
check(window.search.clear:IsShown(), "the search field offers a clear button while it has text")
check(not window.master:IsShown(), "search results have no master switch")
window.search.edit:SetText("zzzz")
check(#visibleRows() == 0, "search with no hit shows no rows")
mock.Click(window.search.clear)
check(window.search.edit:GetText() == "" and window.title:GetText() == "Über", "the clear button empties the field and returns to the page")
check(not window.search.clear:IsShown(), "and disappears again")

-- Reset page.
ns:SetOption("general", "language", "enUS")
mock.Advance(0.1)
mock.Click(navButton("Vendors"))
enable("autoRepair")
enable("sellJunk")
mock.Advance(0.1)
ns:SetOption("categories", "vendor", false)
mock.Advance(0.1)
mock.Click(window.resetButton)
mock.Advance(0.1)
check(ns.features.sellJunk ~= nil and ns:GetOption("sellJunk", "enabled") == true, "the first click on reset changes nothing")
check(window.resetButton.label:GetText() == "Really reset?", "it asks for confirmation instead")
mock.Advance(4.1)
check(window.resetButton.label:GetText() == "Reset page", "the question goes away by itself")
mock.Click(window.resetButton)
mock.Click(navButton("Quests"))
mock.Click(navButton("Vendors"))
check(window.resetButton.label:GetText() == "Reset page", "and when the page is left")
mock.Click(window.resetButton)
mock.Click(window.resetButton)
mock.Advance(4.1)
check(not ns.features.autoRepair.enabled and not ns.features.sellJunk.enabled, "the second click puts the page back to defaults")
check(window.resetButton.disabled and window.resetButton.label:GetText() == "Reset page", "after which reset is greyed out")
check(ns:IsCategoryEnabled("vendor"), "including the category's master switch")

-- Aliases page: four features (Guildy is loaded in the mock), the input row, then the list.
mock.Click(navButton("Aliases"))
local aliasRows = visibleRows()
check(#aliasRows == 8, "the aliases page shows its features, the input row and an empty hint (got " .. #aliasRows .. ")")
local editor = aliasRows[7].editor
check(editor ~= nil and editor:IsVisible() and aliasRows[8].item.kind == "info", "the input row comes before the hint")
check(editor.name.placeholder:GetText() == "Character name" and editor.save.label:GetText() == "Save", "the input row is labelled")
check(navButton("Aliases").count:GetText() == "4/4" and window.master:IsShown(), "the page is a category with a master switch")
mock.Click(editor.save)
check(ns.AliasService.Count() == 0 and mock.focus == editor.name.edit, "saving without a name asks for the name")
editor.name.edit:SetText("Jaina Proudmoore")
editor.name.edit.scripts.OnEnterPressed(editor.name.edit)
check(mock.focus == editor.alias.edit, "Enter in the name field moves on to the alias")
editor.alias.edit.scripts.OnEnterPressed(editor.alias.edit)
check(ns.AliasService.Count() == 0, "saving without an alias does nothing")
editor.alias.edit:SetText("Anna")
editor.alias.edit.scripts.OnEnterPressed(editor.alias.edit)
mock.Advance(0.1)
check(ns.AliasService.Get("Jaina Proudmoore") == "Anna", "Enter in the alias field saves")
check(editor.name.edit:GetText() == "" and editor.alias.edit:GetText() == "", "and empties the input row")
aliasRows = visibleRows()
check(#aliasRows == 8 and aliasRows[8].item.kind == "alias" and aliasRows[8].label:GetText() == "Anna" and aliasRows[8].desc:GetText() == "Jaina Proudmoore",
    "the alias appears in the list with the character below it")
check(window.resetButton.disabled, "a stored alias is not a changed setting")
ns.AliasService.Set("Thrall", "Boss")
mock.Advance(0.1)
check(#visibleRows() == 9, "an alias set elsewhere shows up while the window is open")
mock.Click(aliasRows[8])
check(editor.name.edit:GetText() == "Jaina Proudmoore" and editor.alias.edit:GetText() == "Anna" and mock.focus == editor.alias.edit,
    "clicking an alias loads it into the input row")
editor.alias.edit:SetText("Annie")
mock.Click(editor.save)
mock.Advance(0.1)
check(ns.AliasService.Get("Jaina Proudmoore") == "Annie" and ns.AliasService.Count() == 2, "saving then changes that alias")
window.search.edit:SetText("annie")
check(#visibleRows() == 1 and visibleRows()[1].item.kind == "alias", "search finds an alias")
window.search.edit:SetText("proudm")
check(#visibleRows() == 1, "and a character name")
mock.Click(visibleRows()[1])
check(window.search.edit:GetText() == "" and window.title:GetText() == "Aliases" and editor.alias.edit:GetText() == "Annie",
    "clicking the hit opens it on the aliases page")
mock.Click(visibleRows()[8].remove)
mock.Advance(0.1)
check(ns.AliasService.Get("Jaina Proudmoore") == nil and #visibleRows() == 8, "the remove button deletes the alias")
editor:Load("", "")
-- From the context menu: the window opens on the page with the name filled in.
mock.Click(navButton("Vendors"))
SlashCmdList.SCHNITZEL("")
check(not window:IsShown(), "window closed for the menu test")
mock.OpenMenu("MENU_UNIT_PLAYER", { name = "Varian", surname = "Wrynn" })[2].click()
mock.Advance(0.3)
check(window:IsShown() and window.title:GetText() == "Aliases", "\"Set alias\" in a context menu opens the aliases page")
check(editor.name.edit:GetText() == "Varian Wrynn" and editor.alias.edit:GetText() == "" and mock.focus == editor.alias.edit,
    "with the character filled in and the cursor in the alias field")
mock.OpenMenu("MENU_UNIT_PLAYER", { name = "Thrall" })[2].click()
check(editor.name.edit:GetText() == "Thrall" and editor.alias.edit:GetText() == "Boss", "\"Change alias\" brings the current alias along")
editor:Load("", "")
editor:ClearFocus()
ns.AliasService.Set("Thrall", nil)
mock.Advance(0.1)
check(SchnitzelDB.aliases == nil, "the tests leave no alias behind")

-- Dropdown menu.
mock.Click(navButton("Settings"))
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

-- Window size.
check(generalRows[5].label:GetText() == "Window size" and generalRows[5].dropdown.text:GetText() == "100%", "the settings page offers the window size")
ns:SetOption("general", "windowScale", 120)
check(window.scale == 1.2, "changing it rescales the window at once")
ns:SetOption("general", "windowScale", 100)
check(window.scale == 1 and (SchnitzelDB.profile.general or {}).windowScale == nil, "and the default size is not saved")

-- Character profile.
enable("declineDuels")
mock.Click(generalRows[6])
mock.Advance(0.1)
check(ns:UsesCharacterProfile() and ns.features.declineDuels.enabled, "character profile starts as a copy")
enable("declineDuels", false)
mock.Click(generalRows[6])
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
check(lastChat():find("6 of 20", 1, true) ~= nil, "/sz status reports: " .. lastChat())

---------------------------------------------------------------------------
section("Self-test")
---------------------------------------------------------------------------

local function findCheck(result, group, name)
    for _, entry in ipairs(result.checks) do
        if entry.group == group and entry.name == name then
            return entry
        end
    end
end

check(SchnitzelDB.selfTest == nil and SchnitzelDB.dev == nil, "nothing is tested or logged unless asked for")
local eventsBefore, framesBeforeTest = ns:CountRegisteredEvents(), #mock.frames
setState({})
SlashCmdList.SCHNITZEL("test")
local result = SchnitzelDB.selfTest
check(type(result) == "table" and result.schema == 1, "/sz test stores a report")
check(result.client.toc == "16001" and result.client.version == "1.60.1", "report names the client build")
check(mock.chat[1]:find("Self-test", 1, true) ~= nil, "summary line in chat: " .. tostring(mock.chat[1]))
check(#mock.chat <= 9, "chat output is capped (got " .. #mock.chat .. " lines)")
check(result.summary.ok + result.summary.warn + result.summary.fail == #result.checks, "summary counts every check")
check(result.summary.fail == 0, "no check fails against the mock (got " .. result.summary.fail .. ")")
for _, feature in ipairs(ns.featureList) do
    check(findCheck(result, "feature", feature.id) ~= nil, "report covers feature " .. feature.id)
end
check(findCheck(result, "api", "C_Container").status == "ok", "present API is reported ok")
check(findCheck(result, "api", "MenuUtil").status == "warn", "API missing from the client is a warning")
check(findCheck(result, "api", "GetItemInfo").status == "ok", "removed API is confirmed as removed")
check(findCheck(result, "hideErrors", "error strings").detail:find("2 of 27", 1, true) ~= nil, "counts the error strings the client knows")
check(findCheck(result, "popup", "PARTY_INVITE").status == "ok", "known popup name is ok")
check(findCheck(result, "chat", "arrow keys").status == "ok", "the chat boxes match the arrow key feature")
ChatFrame2EditBox:SetAltArrowKeyMode(true)
check(findCheck(ns:RunSelfTest(), "chat", "arrow keys").detail:find("ChatFrame2", 1, true) ~= nil, "a chat box out of line is named in the report")
ChatFrame2EditBox:SetAltArrowKeyMode(false)
mock.reset()
check(findCheck(result, "popup", "DELETE_GOOD_QUEST_ITEM").status == "warn", "unknown popup name is a warning")
check(findCheck(result, "camera", "cameraDistanceMaxZoomFactor").detail:find("4 -> 1.9; 2.6 -> 2.6", 1, true) ~= nil, "camera probe records what the client accepts")
check(mock.cvars.cameraDistanceMaxZoomFactor == "1.9", "camera probe restores the player's value")
check(result.idle.events == eventsBefore and ns:CountRegisteredEvents() == eventsBefore, "the test registers no events")
check(#mock.frames - framesBeforeTest == 1, "the test creates one hidden probe frame")
SlashCmdList.SCHNITZEL("test")
check(#mock.frames - framesBeforeTest == 1, "and reuses it on the next run")

-- A feature that needs API the client lacks is a failure in the report.
local needy = ns:NewFeature({ id = "fastLootProbe", category = "loot", requires = { "C_Nope.Missing" } })
mock.reset()
result = ns:RunSelfTest()
check(findCheck(result, "feature", "fastLootProbe").status == "fail" and result.summary.fail == 1, "missing required API fails the feature")
ns.features.fastLootProbe = nil
table.remove(ns.featureList)
check(needy.enabled == false, "the probe feature never ran")

-- Camera probe is skipped in combat.
setState({ inCombat = true })
mock.reset()
result = ns:RunSelfTest()
check(mock.count("SetCVar") == 0, "no CVar is touched in combat")
setState({})

-- Developer mode.
mock.reset()
SlashCmdList.SCHNITZEL("dev")
check(SchnitzelDB.dev == true and ns:CountRegisteredEvents() == eventsBefore + 3, "/sz dev starts listening for blocked actions")
mock.Fire("ADDON_ACTION_BLOCKED", "OtherAddon", "UseAction()")
check(SchnitzelDB.devLog == nil, "other addons' blocked actions are ignored")
mock.Fire("ADDON_ACTION_BLOCKED", "Schnitzel", "StaticPopup_Hide()")
mock.Fire("LUA_WARNING", 0, "Interface/AddOns/Schnitzel/Core/Init.lua:1: something")
mock.Fire("LUA_WARNING", 0, "Interface/AddOns/Other/x.lua:1: something")
check(#SchnitzelDB.devLog == 2 and SchnitzelDB.devLog[1].text == "StaticPopup_Hide()", "own blocked actions and warnings are logged")
for i = 1, 150 do
    mock.Fire("ADDON_ACTION_FORBIDDEN", "Schnitzel", "call " .. i)
end
check(#SchnitzelDB.devLog == 100 and SchnitzelDB.devLog[100].text == "call 150", "the log keeps the newest 100 entries")
result = ns:RunSelfTest()
check(result.loggedProblems == 100, "the report says how many problems were logged")
SlashCmdList.SCHNITZEL("dev")
check(SchnitzelDB.dev == nil and SchnitzelDB.devLog == nil and ns:CountRegisteredEvents() == eventsBefore, "/sz dev again stops and clears the log")
SchnitzelDB.selfTest = nil

-- With developer mode saved from the last session, login starts both.
SchnitzelDB.dev = true
mock.reset()
ns:Fire("LOGIN")
check(ns:CountRegisteredEvents() == eventsBefore + 3 and SchnitzelDB.selfTest == nil, "login in developer mode listens, test waits for the UI")
mock.Advance(3.1)
check(type(SchnitzelDB.selfTest) == "table" and mock.ActiveTimers() == 0, "the self-test runs once, three seconds after login")
SlashCmdList.SCHNITZEL("dev")
SchnitzelDB.selfTest = nil
check(ns:CountRegisteredEvents() == eventsBefore, "idle cost is back to normal afterwards")

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
