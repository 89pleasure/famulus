-- Loads Famulus against the mock client and exercises every feature.
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
local ns, files = mock.LoadAddon("Famulus", "Famulus")
local listed = {}
for _, file in ipairs(files) do
    listed[file] = true
    local handle = io.open("Famulus/" .. file, "r")
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

local onDisk = luaFilesIn("Famulus")
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
    local source = readFile("Famulus/" .. file)
    check(listed[file] and source and source:find('id = "' .. feature.id .. '"', 1, true),
        "feature " .. feature.id .. " lives in " .. file)
end
-- Every other Lua file is a service: named <Name>Service.lua, it declares no
-- feature and publishes exactly the table ns.<Name>Service.
for _, file in ipairs(files) do
    local source = readFile("Famulus/" .. file)
    local _, declared = source:gsub("ns:NewFeature%(", "")
    local service = file:match("([%w]+Service)%.lua$")
    if service then
        check(declared == 0, "service declares no feature: " .. file)
        check(type(ns[service]) == "table", "service publishes ns." .. service)
    elseif file:match("^Modules/") then
        check(declared == 1, "a module file is exactly one feature or a *Service.lua: " .. file .. " (declares " .. declared .. ")")
    end
end
-- A boolean test on a secret value is an error in the client, so ns.IsSecret
-- has to come first. The mock cannot catch "not x" at run time.
local secretTestedFirst = {}
for _, file in ipairs(files) do
    local source = readFile("Famulus/" .. file)
    for _, pattern in ipairs({ "not%s+([%w_%.]+)%s+or%s+ns%.IsSecret%(%1%)", "([%w_%.]+)%s+and%s+not%s+ns%.IsSecret%(%1%)" }) do
        for name in source:gmatch(pattern) do
            secretTestedFirst[#secretTestedFirst + 1] = file .. ": " .. name
        end
    end
end
check(#secretTestedFirst == 0, "ns.IsSecret comes before any test of the value (" .. table.concat(secretTestedFirst, ", ") .. ")")

---------------------------------------------------------------------------
section("Login")
---------------------------------------------------------------------------

setState({})
mock.Fire("ADDON_LOADED", "SomeOtherAddon")
check(FamulusDB == nil, "other addons' ADDON_LOADED is ignored")
mock.Fire("ADDON_LOADED", "Famulus")
check(type(FamulusDB) == "table" and type(FamulusDB.profile) == "table", "database is created")
mock.Fire("PLAYER_LOGIN")

local active, total = ns:CountActiveFeatures()
check(total == 10, "10 features registered (got " .. total .. ")")
check(active == 6, "6 features on by default (got " .. active .. ")")
for _, feature in ipairs(ns.featureList) do
    local harmless = feature.id == "liveFeed" or feature.category == "aliases"
    check(feature.enabled == harmless, "only the harmless features are on by default: " .. feature.id)
end
check(ns:CountRegisteredEvents() == 0, "no game event is registered after login (got " .. ns:CountRegisteredEvents() .. ")")
check(lastChat():find("/fam", 1, true) ~= nil, "first login prints the hint")
check(next(FamulusDB.profile) == nil, "nothing is saved while everything is on default")
check(mock.CountOnUpdateFrames() == 0, "no OnUpdate handler runs while idle (got " .. mock.CountOnUpdateFrames() .. ")")
check(mock.ActiveTimers() == 0, "no timer runs while idle")
check(mock.count("Settings.RegisterAddOnCategory") == 1, "entry in the game options is registered")

local function enable(id, value)
    ns:SetOption(id, "enabled", value ~= false)
end

---------------------------------------------------------------------------
section("Aliases")
---------------------------------------------------------------------------

local Aliases = ns.AliasService
local aliasEvents = 0
ns:On("ALIASES_CHANGED", function()
    aliasEvents = aliasEvents + 1
end)
setState({})
check(Aliases.Count() == 0 and FamulusDB.aliases == nil, "a fresh install has no aliases and saves none")
check(mock.CountSenderFilters() == 1, "the chat filter is installed while the feature is on")
check(mock.SenderName("CHAT_MSG_SAY", "|cff3fc7ebJaina-Proudmoore|r", "Jaina-Proudmoore") == "|cff3fc7ebJaina-Proudmoore|r",
    "without an alias a sender keeps their name")

check(Aliases.Set("Jaina Proudmoore", "  Anna ") and Aliases.Count() == 1 and aliasEvents == 1, "an alias can be set and is announced")
check(FamulusDB.aliases["jaina-proudmoore"].alias == "Anna" and FamulusDB.profile.aliases == nil,
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
check(mock.SenderName("CHAT_MSG_SAY", mock.SECRET, mock.SECRET) == mock.SECRET and Aliases.Get(mock.SECRET) == nil,
    "secret names are passed through untouched")
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
check(#mock.OpenMenu("MENU_UNIT_FRIEND", { name = "Someone", bnetIDAccount = 7 }) == 0, "nor does a Battle.net friend whose BattleTag is unknown")
check(#mock.OpenMenu("MENU_UNIT_FRIEND", {}) == 0, "nor a menu without a name")
check(Menu.callbacks.MENU_UNIT_SELF == nil, "menus that are not about another player are not touched")
mock.reset()
entries[3].click()
check(Aliases.Get("Jaina Proudmoore") == nil and lastChat():find("Jaina Proudmoore", 1, true) ~= nil, "removing from the menu works and is reported in one line")
enable("aliasMenu", false)
check(#mock.OpenMenu("MENU_UNIT_FRIEND", { name = "Varian", surname = "Wrynn" }) == 0, "switched off, the menus stay as they are")
enable("aliasMenu")

-- Guildy: its name formatter shows the alias wherever Guildy draws a name.
local guildy = ns.features.guildyAliases
local Format = GuildyAPI.formatters.Famulus
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
check(GuildyAPI.formatters.Famulus == nil, "switching off unregisters the formatter")
refreshes = GuildyAPI.refreshes
Aliases.Set("Varian Wrynn", "King")
Aliases.Set("Varian Wrynn", nil)
check(GuildyAPI.refreshes == refreshes, "switched off, alias changes leave Guildy alone")
enable("guildyAliases")
check(GuildyAPI.formatters.Famulus ~= nil, "switching on registers it again")
-- Without Guildy the feature stays off and the window does not list it.
mock.loadedAddons.Guildy = nil
guildy.available = nil
check(not guildy:IsShown() and not guildy:IsAvailable() and guildy.missing == "addon Guildy", "without Guildy the feature is not available")
ns:SyncFeature(guildy)
check(not guildy.enabled and GuildyAPI.formatters.Famulus == nil, "and does not run")
mock.loadedAddons.Guildy = true
guildy.available = nil
ns:SyncFeature(guildy)
check(guildy.enabled, "with Guildy back it runs again")

-- Battle.net: an alias for a BattleTag covers every character of the account.
local accountAliases = ns.features.accountAliases
check(accountAliases.enabled and ns:CountRegisteredEvents() == 0, "without an alias for an account the friends list is not watched")
check(Aliases.BattleTag(" Anna#1234 ") == "Anna#1234" and Aliases.BattleTag("Jaina Proudmoore") == nil
    and Aliases.BattleTag("Anna#") == nil and Aliases.BattleTag(mock.SECRET) == nil, "a BattleTag is told apart from a character name")
mock.state.bnFriends = {
    { battleTag = "Anna#1234", games = { { characterName = "Jaina Proudmoore" } } },
    { battleTag = "Bert#77", games = { { characterName = "Other Game", wowProjectID = 1 }, { characterName = "Varian Wrynn" } } },
    { battleTag = "Carl#5", games = {} },
}
check(Aliases.Set("anna#1234", "Anna") and Aliases.AccountCount() == 1 and Aliases.Count() == 2, "an alias can be set for a BattleTag")
check(FamulusDB.accountAliases["anna#1234"].alias == "Anna" and FamulusDB.aliases["anna#1234"] == nil and FamulusDB.profile.accountAliases == nil,
    "it is saved account-wide in a list of its own")
check(FamulusDB.accountAliases["anna#1234"].tag == "Anna#1234", "a BattleTag typed by hand takes the spelling of the friends list")
check(Aliases.Get("Jaina", "Proudmoore") == "Anna", "the character the friend is online on has the alias at once")
check(Aliases.Get("Varian Wrynn") == nil, "characters of other friends do not")
check(ns:CountRegisteredEvents() == #accountAliases.EVENTS, "from now on the friends list is watched")
mock.state.bnFriends[1].games[1].characterName = "Sylvanas Windrunner"
mock.Fire("BN_FRIEND_INFO_CHANGED", 1)
check(Aliases.Get("Sylvanas-Windrunner") == "Anna" and Aliases.Get("Jaina Proudmoore") == "Anna", "a character the friend switches to is added, the first one is kept")
mock.state.bnFriends[1].games[2] = { characterName = "Tyrande" }
mock.Fire("BN_FRIEND_ACCOUNT_ONLINE", 4711)
check(Aliases.Get("Tyrande") == "Anna", "an event without a place in the list reads the whole list")
Aliases.Set("Bert#77", "Bert")
check(Aliases.Get("Varian Wrynn") == "Bert" and Aliases.Get("Other Game") == nil, "characters of other games are ignored")
Aliases.Set("Jaina Proudmoore", "Jay")
check(Aliases.Get("Jaina Proudmoore") == "Jay" and select(2, Aliases.Account("Jaina Proudmoore")) == "Anna", "an alias of the character itself wins over the account's")
Aliases.Set("Jaina Proudmoore", nil)
check(Aliases.Get("Jaina Proudmoore") == "Anna" and Aliases.GetOwn("Jaina Proudmoore") == nil and Aliases.GetOwn("Anna#1234") == "Anna",
    "without it the account's alias is back; GetOwn tells the two apart")
check(mock.SenderName("CHAT_MSG_SAY", "Sylvanas-Windrunner", "Sylvanas-Windrunner") == "Anna" and Format("Varian Wrynn") == "Bert",
    "chat and Guildy show the account's alias")
local accountList = Aliases.List()
check(#accountList == 3 and accountList[1].account and accountList[1].name == "Anna#1234"
    and table.concat(accountList[1].chars, ",") == "Jaina Proudmoore,Sylvanas Windrunner,Tyrande" and not accountList[3].account,
    "the list names an account by its BattleTag, with its characters")
entries = mock.OpenMenu("MENU_UNIT_BN_FRIEND", { bnetIDAccount = 3, accountInfo = { battleTag = "Carl#5" } })
check(menuTexts(entries) == "-|Set alias for all characters", "a Battle.net friend's menu offers an alias for the account: " .. menuTexts(entries))
entries = mock.OpenMenu("MENU_UNIT_BN_FRIEND_OFFLINE", { bnetIDAccount = 1, battleTag = "Anna#1234" })
check(menuTexts(entries) == "-|Change alias for all characters|Remove alias for all characters", "with an alias it can be changed or removed: " .. menuTexts(entries))
entries = mock.OpenMenu("MENU_UNIT_FRIEND", { name = "Tyrande" })
check(menuTexts(entries) == "-|Set alias|Change alias for all characters|Remove alias for all characters",
    "a character of such an account offers both: " .. menuTexts(entries))
mock.state.bnFriends[3].games[1] = { characterName = "Anduin Wrynn" }
entries = mock.OpenMenu("MENU_UNIT_PARTY", { name = "Anduin", surname = "Wrynn" })
check(menuTexts(entries) == "-|Set alias|Set alias for all characters", "so does a character a Battle.net friend is online on: " .. menuTexts(entries))
entries = mock.OpenMenu("MENU_UNIT_BN_FRIEND", { bnetIDAccount = 2, battleTag = "Bert#77" })
mock.reset()
entries[3].click()
check(Aliases.Get("Varian Wrynn") == nil and Aliases.AccountCount() == 1 and lastChat():find("Bert#77", 1, true) ~= nil,
    "removing an account's alias takes it from all its characters, reported in one line")
enable("accountAliases", false)
check(ns:CountRegisteredEvents() == 0 and Aliases.Get("Tyrande") == "Anna", "switched off, the friends list is left alone and known characters keep the alias")
enable("accountAliases")
check(ns:CountRegisteredEvents() == #accountAliases.EVENTS, "switched on, it is watched again")
FamulusDB.accountAliases.broken = "x"
FamulusDB.accountAliases["x#1"] = { tag = "Y#2", alias = "a", chars = {} }
ns:Fire("DATABASE_READY")
check(Aliases.AccountCount() == 1 and Aliases.Count() == 2 and Aliases.Get("Tyrande") == "Anna" and FamulusDB.accountAliases.broken == nil
    and FamulusDB.accountAliases["x#1"] == nil, "saved accounts and their characters are read, broken entries are dropped")
Aliases.Set("Anna#1234", nil)
check(Aliases.Get("Tyrande") == nil and FamulusDB.accountAliases == nil and ns:CountRegisteredEvents() == 0,
    "without the last account alias its characters are forgotten and the friends list is no longer watched")
mock.state.bnFriends = nil

-- The category switch stops all of them; the list itself stays.
ns:SetOption("categories", "aliases", false)
check(mock.CountSenderFilters() == 0 and #mock.OpenMenu("MENU_UNIT_FRIEND", { name = "Thrall" }) == 0, "the category switch stops the alias features")
check(GuildyAPI.formatters.Famulus == nil, "including the Guildy formatter")
check(Aliases.Count() == 1, "but keeps the list")
ns:SetOption("categories", "aliases", true)
check(mock.SenderName("CHAT_MSG_SAY", "Thrall", "Thrall") == "Boss", "and everything resumes")

-- Loading a saved list, including one that was edited by hand.
FamulusDB.aliases = { thrall = { name = "Thrall", alias = "Boss" }, broken = "x", [5] = { name = "a", alias = "b" } }
ns:Fire("DATABASE_READY")
check(Aliases.Count() == 1 and Aliases.Get("Thrall") == "Boss" and FamulusDB.aliases.broken == nil, "a saved list is read, broken entries are dropped")
Aliases.Set("Thrall", nil)
check(Aliases.Count() == 0 and FamulusDB.aliases == nil, "an empty list is not saved")
check(ns:CountRegisteredEvents() == 0 and mock.ActiveTimers() == 0, "the alias features need no game event and no timer")
GameTooltip.AddDoubleLine = nil
setState({})

---------------------------------------------------------------------------
section("Settings window")
---------------------------------------------------------------------------

check(FamulusOptionsFrame == nil, "the window does not exist before it is opened")
SlashCmdList.FAMULUS("")
local window = FamulusOptionsFrame
check(window ~= nil and window:IsShown(), "/fam opens the window")
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
        if frame.navId and frame.label:GetText() == text then
            return frame
        end
    end
end

local function tabButton(text)
    for _, button in ipairs(window.tabs.buttons) do
        if button:IsShown() and button.label:GetText() == text then
            return button
        end
    end
end

-- A tab in the bar of a page without sidebar.
local function pageTab(text)
    for _, button in ipairs(window.tabs.buttons) do
        if button:IsShown() and button.label:GetText() == text then
            return button
        end
    end
end

check(ns.areas[1].id == "chronicle" and ns.areas[2].id == "fellows" and ns.areas[3].id == "aliases"
    and ns.categories[1] == "chronicle" and ns.categories[3] == "aliases",
    "the main features in order: chronicle, fellow travellers, aliases last")
check(tabButton("Everyone") and tabButton("Everyone").selected
    and window.area.name:GetText() == "Chronicle" and window.area.desc:GetText() == ns.L.area_chronicle_desc,
    "the first page is the chronicle: named in the sidebar, the content headed by its first tab")
check(navButton("Chronicle") and navButton("Fellow travellers") and navButton("Aliases") and navButton("Settings") and navButton("About"),
    "the head lists the main features and the addon's own pages")
mock.Click(navButton("Aliases"))
check(tabButton("Names") and tabButton("Names").selected and window.area.name:GetText() == "Aliases"
    and window.area.desc:GetText() == ns.L.area_aliases_desc, "the aliases page opens on its first tab")
check(not navButton("Quality of Life") and not navButton("Journal"), "and nothing else")
check(window.search:GetParent() == window.sidebar and window.search:IsShown(), "the search sits at the top of the sidebar")
check(navButton("Aliases"):GetParent() == window.sidebar and navButton("Settings"):GetParent() == window.sidebar
    and navButton("About"):GetParent() == window.sidebar, "the main features and the addon's own pages are entries in the sidebar")
check(navButton("Aliases").selected and not navButton("Aliases").pill:IsShown(),
    "the main feature is selected and shows no counter")
mock.Click(tabButton("Settings"))
check(tabButton("Settings").selected and not tabButton("Names").selected, "a click on a tab chooses it")
local rows = visibleRows()
check(#rows == 7, "the display tab shows the five features and their options (got " .. #rows .. ")")
check(window.resetButton:IsShown() and window.resetButton.disabled, "reset is greyed out while the tab is on its defaults")
mock.Click(window.resetButton)
check(window.resetButton.label:GetText() == "Reset", "and a click on it does nothing")
check(window.master == nil, "the pages carry no master switch any more")
-- The master switches live in Settings › General; tests flip them directly.
local function flipAliases()
    ns:SetOption("categories", "aliases", not ns:IsCategoryEnabled("aliases"))
end
local function visibleCards()
    local list = {}
    for _, frame in ipairs(mock.frames) do
        if frame.mark and frame:IsVisible() then
            list[#list + 1] = frame
        end
    end
    return list
end
local aliasCards = visibleCards()
check(#aliasCards == 5 and #aliasCards[1].block.items == 2, "every feature has its own card, together with its options")
check(aliasCards[1].mark:IsShown() and aliasCards[2].mark:IsShown(), "the card of a running feature wears the accent mark")

-- Toggle through the row itself.
local optionRow = rows[2]
local function isFolded(row)
    return row.item.child and not row.desc:IsShown() and row.height < rows[1].height
end
check(not isFolded(optionRow) and optionRow.desc:IsShown() and not optionRow.disabled, "the option of a running feature is open")
mock.Click(rows[1])
check(not ns.features.chatAliases.enabled, "clicking a row switches the feature off")
mock.Advance(0.3)
check(#visibleRows() == 7 and isFolded(optionRow), "the option of a switched-off feature is a slim row without help text")
check(optionRow.disabled and optionRow.dropdown:IsShown(), "it is greyed out but shows its value")
check(optionRow.bullet:IsShown() and not rows[1].bullet:IsShown(), "options are marked with a dot below their feature")
check(optionRow.sunkenLast.parts[1]:IsShown() and not optionRow.sunken:IsShown(), "an option that ends its card has the rounded ground")
check(not aliasCards[1].mark:IsShown() and aliasCards[2].mark:IsShown(), "the card of a switched-off feature loses the mark")
check(not window.resetButton.disabled, "reset becomes available once something differs from the defaults")
check(not navButton("Aliases").pill:IsShown(), "the sidebar counts nothing")
ns:SetOption("chatAliases", "style", "both")
mock.Advance(0.3)
check(optionRow.dropdown.text:GetText() == ns.L.o_chatAliases_style_both and isFolded(optionRow), "a chosen value shows while folded as well")
mock.Click(optionRow)
mock.Advance(0.05)
local menuOpen = false
for _, frame in ipairs(mock.frames) do
    menuOpen = menuOpen or (frame.value == "alias" and frame.check ~= nil and frame:IsVisible())
end
check(not menuOpen and ns:GetOption("chatAliases", "style") == "both", "and clicks on it do nothing")
ns:SetOption("chatAliases", "style", "alias")

-- Master switch: everything on the tab stops, the choices stay.
flipAliases()
mock.Advance(0.3)
check(not ns:IsCategoryEnabled("aliases") and not ns.features.tooltipAliases.enabled, "the master switch stops the features of its category")
check(mock.CountSenderFilters() == 0, "nothing of a switched-off category reacts to the game")
check(ns:GetOption("tooltipAliases", "enabled") == true and ns:GetOption("chatAliases", "enabled") == false, "the features' own settings are kept")
check(window.area.name:GetText() == "Aliases", "the page's name stays in the head")
check(window.offNotice:IsShown() and #visibleRows() == 0 and not window.resetButton:IsShown(), "the page shows only the notice")
check(tabButton("Settings").label:GetAlpha() < 1, "the tab of the category is greyed out")
check(FamulusDB.profile.categories.aliases == false, "the switch is saved")
enable("chatAliases")
check(not ns.features.chatAliases.enabled, "a feature cannot be started while its category is off")
enable("chatAliases", false)
check(ns.features.liveFeed.enabled, "other categories keep running")
flipAliases()
mock.Advance(0.3)
check(ns.features.tooltipAliases.enabled and FamulusDB.profile.categories == nil, "switching the category on again resumes the features")
check(tabButton("Settings").label:GetAlpha() == 1 and not window.offNotice:IsShown() and #visibleRows() == 7, "and the tab is back to normal")

mock.Click(rows[1])
check(ns.features.chatAliases.enabled, "and the feature on again")
mock.Advance(0.3)
check(not isFolded(optionRow) and optionRow.desc:IsShown() and not optionRow.disabled, "which unfolds its option with its help text")
check(window.resetButton.disabled, "back on defaults, reset is greyed out again")
window.scroll:SetVerticalScroll(30)
mock.Click(rows[1])
mock.Advance(0.3)
mock.Click(rows[1])
mock.Advance(0.3)
check(window.scroll:GetVerticalScroll() == 30, "folding and unfolding do not make the page jump")
window.scroll:SetVerticalScroll(0)

-- Tabs.
mock.Click(tabButton("Names"))
check(tabButton("Names").selected, "a click on a tab opens it")
mock.Advance(0.3)
check(mock.CountOnUpdateFrames() == 0, "the sliding tab bar comes to rest")
mock.Click(tabButton("Settings"))
mock.Click(navButton("Settings"))
check(navButton("Settings").bar:IsShown(), "the chosen icon carries the accent stroke")
mock.Click(navButton("Aliases"))
check(tabButton("Settings").selected, "a page remembers its tab")

-- Every page and tab renders, in both languages.
for _, language in ipairs({ "enUS", "deDE" }) do
    ns:SetOption("general", "language", language)
    mock.Advance(0.1)
    for _, page in ipairs({ "area_aliases", "area_chronicle", "cat_general", "cat_about" }) do
        local button = navButton(ns.L[page])
        check(button ~= nil, "navigation entry for " .. page .. " in " .. language)
        if button then
            mock.Click(button)
            check(window.area.name:GetText() == ns.L[page], "page title for " .. page)
            local tabs = {}
            for _, tab in ipairs(window.tabs.buttons) do
                if tab:IsShown() and window.tabs:IsShown() then
                    tabs[#tabs + 1] = tab
                end
            end
            if #tabs == 0 then
                check(#visibleRows() > 0, "page " .. page .. " has rows")
            end
            for _, tab in ipairs(tabs) do
                mock.Click(tab)
                check(#visibleRows() > 0, "tab " .. tab.label:GetText() .. " of " .. page .. " has rows")
            end
        end
    end
end
check(window.area.name:GetText() == "Über", "language switch applies immediately, without reload")
check(navButton("Über").selected and not tabButton("Über"), "the about page is chosen in the sidebar; with a single tab it shows none")
for _, area in ipairs(ns.areas) do
    for _, category in ipairs(area.categories) do
        local owners = 0
        for _, other in ipairs(ns.areas) do
            for _, c in ipairs(other.categories) do
                owners = owners + (c == category and 1 or 0)
            end
        end
        check(owners == 1, "category " .. category .. " belongs to exactly one area")
    end
end
for _, category in ipairs(ns.categories) do
    local found = false
    for _, area in ipairs(ns.areas) do
        for _, c in ipairs(area.categories) do
            found = found or c == category
        end
    end
    check(found, "category " .. category .. " is shown in an area")
end

-- Search across pages.
window.search.edit:SetText("kontextm")
check(window.area.name:GetText() == "Suche" and #visibleRows() >= 1, "search finds the context menu feature in German")
check(window.search.clear:IsShown(), "the search field offers a clear button while it has text")
local tabsShown = false
for _, button in ipairs(window.tabs.buttons) do
    tabsShown = tabsShown or button:IsShown()
end
check(not navButton("Über").selected and not tabsShown and window.area.desc:GetText():find("^%d"),
    "search results belong to no page: no entry chosen, no tabs, the head names the hits")
local firstCard
for _, frame in ipairs(mock.frames) do
    if frame.title and frame.note and frame:IsVisible() then
        firstCard = firstCard or frame
    end
end
check(firstCard and firstCard.title:GetText() == "Aliase  ·  Einstellungen", "hits are grouped by where they live")
window.search.edit:SetText("zzzz")
check(#visibleRows() == 0, "search with no hit shows no rows")
mock.Click(window.search.clear)
check(window.search.edit:GetText() == "" and window.area.name:GetText() == "Über", "the clear button empties the field and returns to the page")
check(not window.search.clear:IsShown(), "and disappears again")

-- Reset.
ns:SetOption("general", "language", "enUS")
mock.Advance(0.1)
mock.Click(navButton("Aliases"))
mock.Click(tabButton("Settings"))
check(tabButton("Settings").selected, "back on the display tab")
enable("chatAliases", false)
enable("tooltipAliases", false)
enable("liveFeed", false)
mock.Advance(0.1)
mock.Click(window.resetButton)
mock.Advance(0.1)
check(ns:GetOption("tooltipAliases", "enabled") == false, "the first click on reset changes nothing")
check(window.resetButton.label:GetText() == "Really reset?", "it asks for confirmation instead")
mock.Advance(4.1)
check(window.resetButton.label:GetText() == "Reset", "the question goes away by itself")
mock.Click(window.resetButton)
mock.Click(tabButton("Names"))
mock.Click(tabButton("Settings"))
check(window.resetButton.label:GetText() == "Reset", "and when the tab is left")
mock.Click(window.resetButton)
mock.Click(window.resetButton)
mock.Advance(4.1)
check(ns.features.chatAliases.enabled and ns.features.tooltipAliases.enabled, "the second click puts the tab back to defaults")
check(window.resetButton.disabled and window.resetButton.label:GetText() == "Reset", "after which reset is greyed out")
check(ns:GetOption("liveFeed", "enabled") == false, "other pages are left alone")
enable("liveFeed")

-- Aliases page: the list first, where aliases show on the second tab.
mock.Click(navButton("Aliases"))
mock.Click(tabButton("Names"))
check(window.area.name:GetText() == "Aliases" and tabButton("Names").selected and tabButton("Settings"), "the aliases page has its own tabs")
check(not window.resetButton:IsShown(), "the list tab has no reset: aliases are data")
local aliasRows = visibleRows()
check(#aliasRows == 2, "the list tab shows the input row and an empty hint (got " .. #aliasRows .. ")")
local editor = aliasRows[1].editor
check(editor ~= nil and editor:IsVisible() and aliasRows[2].item.kind == "info", "the input row comes before the hint")
check(editor.name.placeholder:GetText() == "Character or BattleTag#1234" and editor.save.label:GetText() == "Save", "the input row is labelled")
check(not navButton("Aliases").pill:IsShown(), "the sidebar entry shows no counter")
mock.Click(tabButton("Settings"))
check(#visibleRows() == 7 and window.resetButton:IsShown(), "the display tab shows the five features with their options, and reset")
-- The master switches in Settings › General.
mock.Click(navButton("Settings"))
mock.Click(tabButton("General"))
local switches = visibleRows()
check(switches[1].item.section == "categories" and switches[1].item.key == "chronicle" and switches[2].item.key == "fellows"
    and switches[3].item.key == "aliases" and switches[3].toggle.on, "settings › general starts with the three main features, in the sidebar's order")
mock.Click(switches[3])
mock.Advance(0.1)
check(not ns:IsCategoryEnabled("aliases") and navButton("Aliases").pill:IsShown() and navButton("Aliases").count:GetText() == "OFF"
    and navButton("Aliases").label:GetAlpha() < 1,
    "switching one off greys it in the head")
check(not window.resetButton.disabled, "and makes settings › general resettable")
mock.Click(navButton("Aliases"))
check(window.offNotice:IsShown() and #visibleRows() == 0 and window.offNotice.text:GetText():find("Aliases", 1, true),
    "its page shows only the notice")
window.search.edit:SetText("kontextm")
check(#visibleRows() == 0, "search leaves a switched-off feature out")
window.search.edit:SetText("aliases")
check(visibleRows()[1] and visibleRows()[1].item.section == "categories", "but finds its switch")
window.search.edit:SetText("")
mock.Click(window.offNotice.button)
check(window.area.name:GetText() == ns.L.cat_general and tabButton(ns.L.ui_tab_general).selected and not window.offNotice:IsShown(),
    "the notice's button opens settings › general")
mock.Click(window.resetButton)
mock.Click(window.resetButton)
mock.Advance(0.1)
check(ns:IsCategoryEnabled("aliases"), "reset there switches the main features back on")
mock.Click(navButton("Aliases"))
mock.Click(tabButton("Names"))
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
check(#aliasRows == 2 and aliasRows[2].item.kind == "alias" and aliasRows[2].label:GetText() == "Anna" and aliasRows[2].desc:GetText() == "Jaina Proudmoore",
    "the alias appears in the list with the character below it")
check(aliasRows[2].initial:GetText() == "A" and aliasRows[2].avatar:IsShown(), "with its initial as an avatar")
ns.AliasService.Set("Thrall", "Boss")
mock.Advance(0.1)
check(#visibleRows() == 3, "an alias set elsewhere shows up while the window is open")
mock.Click(aliasRows[2])
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
mock.Click(navButton("Chronicle"))
window.search.edit:SetText("proudm")
mock.Click(visibleRows()[1])
check(window.search.edit:GetText() == "" and window.area.name:GetText() == "Aliases" and tabButton("Names").selected and editor.alias.edit:GetText() == "Annie",
    "clicking the hit opens it on the aliases page")
local annieRow
for _, row in ipairs(visibleRows()) do
    if row.item.kind == "alias" and row.label:GetText() == "Annie" then
        annieRow = row
    end
end
mock.Click(annieRow.remove)
mock.Advance(0.1)
check(ns.AliasService.Get("Jaina Proudmoore") == nil and #visibleRows() == 2, "the remove button deletes the alias")
editor:Load("", "")
-- A BattleTag in the name field makes it an alias for the whole account.
mock.state.bnFriends = { { battleTag = "Anna#1234", games = {} } }
editor.name.edit:SetText("Anna#1234")
editor.alias.edit:SetText("Anna")
mock.Click(editor.save)
mock.Advance(0.1)
local accountRow = visibleRows()[2]
check(ns.AliasService.AccountCount() == 1 and accountRow.label:GetText() == "Anna"
    and accountRow.desc:GetText() == "Battle.net  ·  Anna#1234  ·  no character seen yet",
    "a BattleTag in the name field sets an alias for the account: " .. tostring(accountRow.desc:GetText()))
mock.state.bnFriends[1].games[1] = { characterName = "Jaina Proudmoore" }
mock.Fire("BN_FRIEND_INFO_CHANGED", 1)
mock.Advance(0.1)
accountRow = visibleRows()[2]
check(accountRow.desc:GetText() == "Battle.net  ·  Anna#1234  ·  Jaina Proudmoore", "the open list shows a character as soon as it is seen")
window.search.edit:SetText("proudm")
check(#visibleRows() == 1 and visibleRows()[1].item.entry.account, "search finds the account by one of its characters")
window.search.edit:SetText("")
mock.Click(visibleRows()[2])
check(editor.name.edit:GetText() == "Anna#1234" and editor.alias.edit:GetText() == "Anna", "clicking the account loads its BattleTag into the input row")
mock.Click(visibleRows()[2].remove)
mock.Advance(0.1)
check(ns.AliasService.Count() == 1 and FamulusDB.accountAliases == nil and ns:CountRegisteredEvents() == 0, "the remove button deletes the account's alias")
mock.state.bnFriends = nil
editor:Load("", "")
-- From the context menu: the window opens on the list with the name filled in.
mock.Click(tabButton("Settings"))
mock.Click(navButton("Chronicle"))
SlashCmdList.FAMULUS("")
check(not window:IsShown(), "window closed for the menu test")
mock.OpenMenu("MENU_UNIT_PLAYER", { name = "Varian", surname = "Wrynn" })[2].click()
mock.Advance(0.3)
check(window:IsShown() and window.area.name:GetText() == "Aliases" and tabButton("Names").selected, "\"Set alias\" in a context menu opens the alias list")
check(editor.name.edit:GetText() == "Varian Wrynn" and editor.alias.edit:GetText() == "" and mock.focus == editor.alias.edit,
    "with the character filled in and the cursor in the alias field")
mock.OpenMenu("MENU_UNIT_PLAYER", { name = "Thrall" })[2].click()
check(editor.name.edit:GetText() == "Thrall" and editor.alias.edit:GetText() == "Boss", "\"Change alias\" brings the current alias along")
editor:Load("", "")
editor:ClearFocus()
ns.AliasService.Set("Thrall", nil)
mock.Advance(0.1)
check(FamulusDB.aliases == nil, "the tests leave no alias behind")

-- Settings: general tab.
mock.Click(navButton("Settings"))
mock.Click(tabButton("General"))
check(tabButton("General").selected and tabButton("Appearance"), "the settings page has a general and an appearance tab")
local generalRows = visibleRows()
check(#generalRows == 7, "the three main features, language, chat feedback, minimap button and character profile (got " .. #generalRows .. ")")
mock.Click(generalRows[4]) -- language
mock.Advance(0.05)
local picked = false
for _, frame in ipairs(mock.frames) do
    if frame.value == "enUS" and frame.check and frame:IsVisible() then
        mock.Click(frame)
        picked = true
        break
    end
end
check(picked and ns:GetOption("general", "language") == "enUS", "dropdown changes the language")
mock.Advance(0.1)
check(not window.resetButton.disabled, "a changed setting makes the tab resettable")
ns:SetOption("general", "language", "auto")

-- Character profile.
enable("tooltipAliases", false)
mock.Click(generalRows[7])
mock.Advance(0.1)
check(ns:UsesCharacterProfile() and not ns.features.tooltipAliases.enabled, "character profile starts as a copy")
enable("tooltipAliases")
mock.Click(generalRows[7])
mock.Advance(0.1)
check(not ns:UsesCharacterProfile() and not ns.features.tooltipAliases.enabled, "switching back restores the account settings")
enable("tooltipAliases")

-- Settings: appearance tab.
mock.Click(tabButton("Appearance"))
local looks = visibleRows()
check(#looks == 3 and looks[1].swatches:IsShown() and looks[2].toggle:IsShown() and looks[3].dropdown:IsShown(),
    "colour scheme, sparks and window size")
check(window.themeButton == nil and ns.UI.colors.card[1] < 0.3, "the window is dark and has no light version")

-- Fonts load lazily: a string waits on the game's font, then switches and is redrawn.
local inter = ns.UI.fonts.regular
mock.unloadedFonts[inter] = true
ns.UI.fontLoaded[inter] = nil -- as on a fresh login
local timersBeforeFont = mock.ActiveTimers()
local lazy = ns.UI.Text(window, 13)
check(lazy.font == STANDARD_TEXT_FONT and mock.ActiveTimers() == timersBeforeFont + 1, "a font not loaded yet shows the game's font and asks again")
check(ns.UI.fontLoaded[inter] == false, "the self-test learns that the window waits for the font")
mock.unloadedFonts[inter] = nil
local setsBefore = lazy.fontSets
mock.Advance(0.6)
check(lazy.font == inter and lazy.fontSize == 13 and lazy.fontSets == setsBefore + 3, "once loaded, the string switches and is redrawn")
mock.Advance(1)
check(ns.UI.fontLoaded[inter] == true and lazy.fontSets == setsBefore + 3, "and the retries stop")
local lilac
for _, dot in ipairs(looks[1].swatches.dots) do
    if dot.value == "lilac" then
        lilac = dot
    end
end
local lemon, lemonWindow = ns.UI.colors.accent[3], ns.UI.colors.window[2]
mock.Click(lilac)
mock.Advance(0.1)
check(ns:GetOption("general", "accent") == "lilac" and ns.UI.colors.accent[3] ~= lemon, "a swatch picks the colour scheme")
check(ns.UI.colors.window[2] ~= lemonWindow, "a scheme tints the grounds as well, not just the accent")
-- Every scheme is complete.
local function channelsValid(color)
    for i = 1, 4 do
        if type(color[i]) ~= "number" or color[i] < 0 or color[i] > 1 then
            return false
        end
    end
    return true
end
local schemesComplete = true
do
    for _, accent in ipairs(ns.UI.accents) do
        ns:SetOption("general", "accent", accent)
        local colors = ns.UI.colors
        for _, token in ipairs({ "window", "sidebar", "card", "text", "textMuted", "accent", "accent2", "onAccent", "accentGlow", "accentEdge", "sunken", "sheen" }) do
            schemesComplete = schemesComplete and colors[token] ~= nil and channelsValid(colors[token])
        end
        -- Text must stand out from its ground.
        schemesComplete = schemesComplete and math.abs(colors.text[2] - colors.card[2]) > 0.6
        schemesComplete = schemesComplete and (colors.accent[1] ~= colors.accent2[1] or colors.accent[2] ~= colors.accent2[2])
    end
end
check(schemesComplete, "every scheme has all its colours")
ns:SetOption("general", "accent", "lilac")
mock.Advance(0.1)
check(lilac.selected and lilac.ring:IsShown(), "the chosen swatch wears a ring")
mock.Click(looks[1])
check(ns:GetOption("general", "accent") == "lilac", "a click beside the swatches changes nothing")
check(not window.resetButton.disabled, "a changed look makes the tab resettable")
mock.Click(window.resetButton)
mock.Click(window.resetButton)
mock.Advance(4.1)
check(ns:GetOption("general", "accent") == "lemon", "reset brings the default look back")
check(ns:GetOption("general", "language") == "auto" and ns:GetOption("general", "minimapAngle") == 215, "and touches nothing else")

-- Window size.
check(looks[3].label:GetText() == "Window size" and looks[3].dropdown.text:GetText() == "100%", "the appearance tab offers the window size")
ns:SetOption("general", "windowScale", 120)
check(window.scale == 1.2, "changing it rescales the window at once")
ns:SetOption("general", "windowScale", 100)
check(window.scale == 1 and (FamulusDB.profile.general or {}).windowScale == nil, "and the default size is not saved")

-- Sparks in the background: animated by the client, only while the window
-- is open and the option is on.
local function sparkGroups()
    local playing, total = 0, 0
    for _, frame in ipairs({ window, window.sidebar }) do
        for _, region in ipairs(frame.regions or {}) do
            if region.group then
                total = total + 1
                if region.group:IsPlaying() and region:IsShown() then
                    playing = playing + 1
                end
            end
        end
    end
    return playing, total
end
local sparksPlaying, sparksTotal = sparkGroups()
check(sparksTotal > 10 and sparksPlaying == sparksTotal, "the sparks rise while the window is open (" .. sparksPlaying .. " of " .. sparksTotal .. ")")
check(looks[2].label:GetText() == "Sparks in the background" and looks[2].toggle.on, "and have a switch on the appearance tab")
mock.Click(looks[2])
mock.Advance(0.1)
check(ns:GetOption("general", "embers") == false and sparkGroups() == 0, "switching them off stops every one")
mock.Click(looks[2])
mock.Advance(0.1)
check(sparkGroups() == sparksTotal, "switching them on starts them again")

-- Minimap button.
check(FamulusMinimapButton ~= nil and FamulusMinimapButton:IsShown(), "minimap button exists")
ns:SetOption("general", "minimapButton", false)
check(not FamulusMinimapButton:IsShown(), "and can be hidden")
ns:SetOption("general", "minimapButton", true)

SlashCmdList.FAMULUS("")
check(not window:IsShown(), "/fam closes the window again")
check(sparkGroups() == 0, "a closed window animates nothing")
mock.reset()
SlashCmdList.FAMULUS("status")
check(not lastChat():find("of 10", 1, true), "/fam status is gone; it counted features")
SlashCmdList.FAMULUS("status") -- it opened the window; close it again

---------------------------------------------------------------------------
section("Chronicle")
---------------------------------------------------------------------------

local Chronicle = ns.ChronicleService
local stateBeforeChronicle = mock.state
check(not ns.features.ownJourney.enabled and not ns.features.companions.enabled and #Chronicle.Entries() == 0,
    "the chronicle records nothing until it is switched on")
local eventsBeforeChronicle = ns:CountRegisteredEvents()
setState({ zone = "Elwynn Forest", level = 12, explored = { "Duskwood" } })
enable("ownJourney")
check(ns:CountRegisteredEvents() > eventsBeforeChronicle, "switched on, it listens for milestones")
mock.Fire("PLAYER_LEVEL_UP", 13)
local levelEntry = Chronicle.Entries()[1]
check(levelEntry and levelEntry.k == "level" and levelEntry.level == 13 and levelEntry.zone == "Elwynn Forest" and Chronicle.IsOwn(levelEntry),
    "a level-up is written down with level and place")
check(Chronicle.Text(levelEntry) == "Reached level 13" and select(2, Chronicle.Text(levelEntry)) == "in Elwynn Forest", "and reads as a sentence")
mock.Fire("ZONE_CHANGED_NEW_AREA")
check(#Chronicle.Entries() == 1, "the zone the character already stood in is no arrival")
setState({ zone = "Duskwood", level = 13 })
mock.Fire("ZONE_CHANGED_NEW_AREA")
check(#Chronicle.Entries() == 1, "a zone the character explored before the chronicle began is no arrival")
setState({ zone = "Redridge Mountains", level = 13, onTaxi = true })
mock.Fire("ZONE_CHANGED_NEW_AREA")
check(#Chronicle.Entries() == 1 and not FamulusCharDB.zones["Redridge Mountains"],
    "a zone passed on a flight path is no arrival and stays undiscovered")
setState({ zone = "Westfall", level = 13, onTaxi = true })
mock.Fire("ZONE_CHANGED_NEW_AREA")
setState({ zone = "Westfall", level = 13 })
mock.Fire("PLAYER_CONTROL_GAINED")
check(#Chronicle.Entries() == 1, "the landing waits a moment")
mock.Advance(1.1)
check(#Chronicle.Entries() == 2 and Chronicle.Text(Chronicle.Entries()[2]) == "Arrived in Westfall",
    "landing in a new zone is an arrival")
Chronicle.Entries()[2] = nil
FamulusCharDB.zones["Westfall"] = nil
mock.Fire("ZONE_CHANGED_NEW_AREA")
mock.Fire("ZONE_CHANGED_NEW_AREA")
check(#Chronicle.Entries() == 2 and Chronicle.Text(Chronicle.Entries()[2]) == "Arrived in Westfall", "a new zone is an arrival, once")
mock.Fire("PLAYER_DEAD")
mock.Fire("PLAYER_DEAD")
check(#Chronicle.Entries() == 3 and Chronicle.Text(Chronicle.Entries()[3]) == "Fallen in Westfall", "a death is written once, with the place")
mock.Fire("BOSS_KILL", 77, "Edwin VanCleef")
mock.Fire("ACHIEVEMENT_EARNED", 501, false)
mock.Fire("ACHIEVEMENT_EARNED", 501, true)
check(#Chronicle.Entries() == 5 and Chronicle.Text(Chronicle.Entries()[4]) == "Edwin VanCleef defeated"
    and Chronicle.Text(Chronicle.Entries()[5]) == "Challenge completed: Challenge 501", "bosses and challenges follow; one already earned does not")
do -- who was there when a boss fell
    local count, realTime = #Chronicle.Entries(), time
    local _, alone = Chronicle.Text(Chronicle.Entries()[4])
    check(alone == "in Westfall" and Chronicle.Entries()[4].with == nil, "a boss defeated alone names nobody")
    mock.state.group = { members = {
        { name = "Mira", surname = "Sturmfeder", guid = "Player-1-MIRA", level = 20, class = "MAGE" },
        { name = "Tom", surname = "Hartwig", guid = "Player-1-TOM", level = 21, class = "PRIEST" },
    } }
    -- Two entries of a kind in one second are one event; these lie apart.
    time = function()
        return realTime() + 10
    end
    mock.Fire("BOSS_KILL", 78, "Mr. Smite")
    local boss = Chronicle.Entries()[count + 1]
    local _, detail = Chronicle.Text(boss)
    check(boss and type(boss.with) == "table" and boss.with[1] == "Mira Sturmfeder" and detail == "in Westfall  ·  with Mira and Tom",
        "a boss defeated in a party names who was there: " .. tostring(detail))
    ns.AliasService.Set("Tom Hartwig", "Tommy")
    _, detail = Chronicle.Text(boss)
    check(detail == "in Westfall  ·  with Mira and Tommy", "under their alias: " .. tostring(detail))
    ns.AliasService.Set("Tom Hartwig", nil)
    mock.state.group.raid = true
    time = function()
        return realTime() + 20
    end
    mock.Fire("BOSS_KILL", 79, "Ragnaros")
    boss = Chronicle.Entries()[count + 2]
    _, detail = Chronicle.Text(boss)
    check(boss and boss.with == nil and boss.others == 2 and detail == "in Westfall  ·  with 2 others",
        "in a raid only how many: " .. tostring(detail))
    time = realTime
    mock.state.group = nil
    table.remove(Chronicle.Entries(), count + 2)
    table.remove(Chronicle.Entries(), count + 1)
end
do -- professions
    local count = #Chronicle.Entries()
    mock.state.professions = { { name = "Mining", rank = 140, id = 186 } }
    mock.Fire("SKILL_LINES_CHANGED")
    check(#Chronicle.Entries() == count, "a profession from before the chronicle is only taken note of")
    mock.state.professions[2] = { name = "Tailoring", rank = 1, id = 197 }
    mock.Fire("SKILL_LINES_CHANGED")
    mock.Fire("SKILL_LINES_CHANGED")
    local learned = Chronicle.Entries()[count + 1]
    check(learned and learned.icon == 136197 and ns.UI.ChronicleStory(learned).texture == 136197,
        "a profession brings its own icon into the entry and the picture")
    check(#Chronicle.Entries() == count + 1 and learned.k == "profession" and Chronicle.Text(learned) == "Learned Tailoring",
        "a profession learned is written down, once")
    mock.state.professions[2].rank = 74
    mock.Fire("SKILL_LINES_CHANGED")
    check(#Chronicle.Entries() == count + 1, "points of skill alone are no news")
    mock.state.professions[2].rank = 76
    mock.state.professions[1].rank = 152
    mock.Fire("SKILL_LINES_CHANGED")
    local a, b = Chronicle.Entries()[count + 2], Chronicle.Entries()[count + 3]
    check(#Chronicle.Entries() == count + 3 and a.k == "skill" and a.rank == 150 and Chronicle.Text(a) == "Mining raised to 150"
        and Chronicle.Text(b) == "Tailoring raised to 75", "every 75 points of skill are a milestone: " .. #Chronicle.Entries() - count .. " " .. tostring(a and Chronicle.Text(a)) .. " / " .. tostring(b and Chronicle.Text(b)))
    for index = #Chronicle.Entries(), count + 1, -1 do
        Chronicle.Entries()[index] = nil
    end
    mock.state.professions = nil
end
do -- abilities, recognised by their spell
    local count = #Chronicle.Entries()
    for _, ability in ipairs(Chronicle.abilities) do
        check(type(ability.id) == "string" and type(ability.spell) == "number"
            and ns.L["c_ability_" .. ability.id] ~= "c_ability_" .. ability.id
            and ns.L["c_their_ability_" .. ability.id]:find("%s", 1, true) ~= nil
            and (ability.picture == nil or ns.UI.media[ability.picture] ~= nil),
            "ability " .. tostring(ability.id) .. " has a spell, its sentences and a picture that exists")
    end
    mock.Fire("SPELLS_CHANGED")
    check(#Chronicle.Entries() == count, "a character on foot has nothing to tell")
    mock.state.spells = { [33388] = true }
    mock.Fire("SPELLS_CHANGED")
    mock.Fire("SPELLS_CHANGED")
    local riding = Chronicle.Entries()[count + 1]
    check(#Chronicle.Entries() == count + 1 and riding.k == "ability" and riding.ability == "riding"
        and Chronicle.Text(riding) == "Learned to ride" and select(2, Chronicle.Text(riding)) == "at level 13",
        "learning an ability is written down, once")
    mock.state.spells = nil
    mock.state.riding = 150
    mock.Fire("SKILL_LINES_CHANGED")
    check(#Chronicle.Entries() == count + 2 and Chronicle.Text(Chronicle.Entries()[count + 2]) == "Learned to ride fast",
        "without the spell, the skill line tells")
    check(Chronicle.Text({ k = "ability", ability = "riding", who = "Jaina Proudmoore" }) == "Jaina Proudmoore learns to ride"
        and Chronicle.Text({ k = "ability", ability = "fromLater", name = "Swimming", who = "Jaina Proudmoore" }) == "Jaina Proudmoore learns Swimming",
        "a companion's ability reads as a sentence, even one this version does not know")
    -- A character that can do it already when the chronicle begins tells nothing.
    enable("ownJourney", false)
    FamulusCharDB.abilities = nil
    enable("ownJourney")
    mock.Fire("SPELLS_CHANGED")
    check(#Chronicle.Entries() == count + 2 and FamulusCharDB.abilities.riding and FamulusCharDB.abilities.ridingFast,
        "abilities from before the chronicle are only taken note of")
    for index = #Chronicle.Entries(), count + 1, -1 do
        Chronicle.Entries()[index] = nil
    end
    mock.state.riding = nil
end
do -- special items, recognised by their ID
    local count = #Chronicle.Entries()
    for _, item in ipairs(Chronicle.items) do
        check(type(item.item) == "number" and (item.picture == nil or ns.UI.media[item.picture] ~= nil),
            "item " .. tostring(item.item) .. " has an ID and a picture that exists")
    end
    mock.Fire("BAG_UPDATE_DELAYED")
    check(#Chronicle.Entries() == count, "bags without anything special tell nothing")
    mock.state.owned = { [211527] = 1 }
    mock.state.itemNames = { [211527] = "Cozy Sleeping Bag" }
    mock.Fire("BAG_UPDATE_DELAYED")
    mock.Fire("BAG_UPDATE_DELAYED")
    local bag = Chronicle.Entries()[count + 1]
    check(#Chronicle.Entries() == count + 1 and bag.k == "item" and bag.item == 211527
        and Chronicle.Text(bag) == "Received: Cozy Sleeping Bag" and select(2, Chronicle.Text(bag)) == "in Westfall",
        "a special item is written down the first time it is in the bags")
    mock.state.itemNames = nil
    check(Chronicle.Text({ k = "item", item = 211527, name = "Kuscheliger Schlafsack", who = "Jaina Proudmoore" })
        == "Jaina Proudmoore receives: Kuscheliger Schlafsack", "a companion's item is named as they named it, if this client cannot")
    -- What the character owns when the chronicle begins tells nothing.
    enable("ownJourney", false)
    FamulusCharDB.items = nil
    enable("ownJourney")
    mock.Fire("BAG_UPDATE_DELAYED")
    check(#Chronicle.Entries() == count + 1 and FamulusCharDB.items[211527], "items from before the chronicle are only taken note of")
    Chronicle.Entries()[count + 1] = nil
    mock.state.owned = nil
end
do -- the live feed: what was just written down appears on screen for a while
    local Feed = ns.UI.Feed
    -- The probes carry times of their own, so they are found by a mark.
    local function forget()
        local entries = Chronicle.Entries()
        for index = #entries, 1, -1 do
            if entries[index].probe then
                table.remove(entries, index)
            end
        end
    end
    Feed.Clear()
    check(ns.features.liveFeed.enabled and ns:GetOption("liveFeed", "zone") == false and ns:GetOption("liveFeed", "level") == true
        and ns:GetOption("liveFeed", "own") == false,
        "the feed is on from the start; arrivals in a zone and the player's own events are not shown")
    -- (Two events of a kind within a second count as one; hence the times.)
    Chronicle.Add("ability", { ability = "riding", level = 14, t = time() - 18, probe = true })
    check(#Feed.Shown() == 0, "from the start the feed is about companions: the player's own events stay off screen")
    ns:SetOption("liveFeed", "own", true)
    Chronicle.Add("level", { level = 14, t = time() - 19, probe = true })
    check(#Feed.Shown() == 0, "the player's own level-up is not shown: the game announces it itself")
    Chronicle.Add("ability", { ability = "riding", level = 14, t = time() - 20, probe = true })
    local card = Feed.Shown()[1]
    check(#Feed.Shown() == 1 and card:IsShown() and card.title:GetText() == "Learned to ride"
        and card.photo:IsShown() and not card.icon:IsShown() and not card.number:IsShown(),
        "asked for, an event of the player's own appears as a card with an icon of the game")
    check(card.crest:GetHeight() < card:GetHeight() and card.crest:GetWidth() < card:GetWidth()
        and card:GetWidth() >= 230 and card.mark:IsShown() and card.grain ~= nil,
        "the picture is a crest inside its band; a milestone carries the mark of an active card")
    Chronicle.Add("zone", { zone = "Nowhere", t = time() - 21, probe = true })
    Chronicle.Add("death", { zone = "Nowhere", who = "Jaina Proudmoore", t = time() - 3600, probe = true })
    check(#Feed.Shown() == 1, "a kind that is switched off and old news stay off screen")
    ns:SetOption("liveFeed", "own", false)
    Chronicle.Add("boss", { name = "Hogger", t = time() - 22, probe = true })
    check(#Feed.Shown() == 1, "switched off again, the player's own events stay off screen")
    ns:SetOption("liveFeed", "own", true)
    Chronicle.Add("item", { item = 211527, name = "Cozy Sleeping Bag", who = "Jaina Proudmoore", probe = true })
    check(#Feed.Shown() == 2 and Feed.Shown()[1].title:GetText() == "Jaina Proudmoore receives: Cozy Sleeping Bag"
        and Feed.Shown()[1].photo:IsShown(), "a companion's event appears above the older card")
    check(Feed.Shown()[1]:GetWidth() > Feed.Shown()[2]:GetWidth() and not Feed.Shown()[1].mark:IsShown(),
        "a band is as wide as its text needs; a companion's event is no milestone")
    for skill = 1, 3 do
        Chronicle.Add("skill", { skill = skill, name = "Craft " .. skill, rank = 75, probe = true })
    end
    check(#Feed.Shown() == 3 and Feed.Shown()[3].title:GetText() == "Craft 1 raised to 75", "at most three cards; the oldest makes room")
    ns:SetOption("liveFeed", "own", false)
    mock.Advance(6.5)
    check(#Feed.Shown() == 3, "a card stays for its time")
    mock.Advance(2)
    check(#Feed.Shown() == 0 and not card:IsShown(), "then it fades out and is gone")
    Chronicle.Add("level", { level = 15, who = "Jaina Proudmoore", t = time() - 23, probe = true })
    check(#Feed.Shown() == 1 and Feed.Shown()[1].number:IsShown() and Feed.Shown()[1].number:GetText() == "15",
        "a companion's level-up appears with its number")
    Feed.Clear()
    ns:SetOption("liveFeed", "level", false)
    Chronicle.Add("level", { level = 16, who = "Jaina Proudmoore", t = time() - 24, probe = true })
    check(#Feed.Shown() == 0, "each kind of event has its own switch")
    ns:SetOption("liveFeed", "level", true)
    enable("liveFeed", false)
    Chronicle.Add("level", { level = 17, who = "Jaina Proudmoore", t = time() - 25, probe = true })
    check(#Feed.Shown() == 0, "switched off, nothing appears")
    enable("liveFeed")
    -- The place: shown and dragged in the game's Edit Mode or with /fam feed.
    EditModeManagerFrame.scripts.OnShow(EditModeManagerFrame)
    check(Feed.IsMoving() and Feed.mover:IsShown() and Feed.mover.label:GetText() == ns.L.ui_feed_mover,
        "in the game's Edit Mode the feed shows where it appears")
    Feed.mover.scripts.OnDragStart(Feed.mover)
    Feed.mover.scripts.OnDragStop(Feed.mover)
    check(type(FamulusDB.feed) == "table" and FamulusDB.feed.point ~= nil, "dragging it keeps the place")
    EditModeManagerFrame.scripts.OnHide(EditModeManagerFrame)
    check(not Feed.IsMoving() and not Feed.mover:IsShown(), "leaving Edit Mode fixes it")
    SlashCmdList.FAMULUS("feed")
    check(Feed.IsMoving(), "/fam feed shows the place as well")
    SlashCmdList.FAMULUS("feed")
    SlashCmdList.FAMULUS("feed reset")
    check(not Feed.IsMoving() and FamulusDB.feed == nil, "/fam feed fixes it again, /fam feed reset puts it back")
    Feed.Clear()
    SlashCmdList.FAMULUS("feed test")
    check(#Feed.Shown() == 1 and Feed.Shown()[1].number:GetText() == "13", "/fam feed test shows a sample card")
    Feed.Clear()
    forget()
end
do -- sample entries for looking at the book
    local count = #Chronicle.Entries()
    SlashCmdList.FAMULUS("chronicle demo")
    SlashCmdList.FAMULUS("chronicle demo")
    local entries, sorted, texts = Chronicle.Entries(), true, true
    for index, entry in ipairs(entries) do
        sorted = sorted and (index == 1 or entries[index - 1].t <= entry.t)
        local title = Chronicle.Text(entry)
        texts = texts and type(title) == "string" and title ~= "" and not title:find("c_", 1, true)
    end
    check(#entries > count + 10 and sorted and texts, "/fam chronicle demo writes sample entries, once, in order, each a sentence")
    check(#Chronicle.OwnSince(0, 100) == #Chronicle.OwnSince(0, 100) and (function()
        for _, entry in ipairs(Chronicle.OwnSince(0, 100)) do
            if entry.demo then
                return false
            end
        end
        return true
    end)(), "sample entries are not passed on to companions")
    Chronicle.Profile("Real Friend", { level = 12, stats = { [60] = 1 } })
    local profiles = Chronicle.ProfileNames()
    local mira = Chronicle.Profile("Mira Stormfeather")
    check(#profiles >= 4 and mira and mira.demo and mira.level == 40 and mira.stats[60] ~= nil,
        "the companions have sample profiles with their numbers")
    local lysa = 0
    for _, entry in ipairs(Chronicle.Entries()) do
        lysa = lysa + (entry.who == "Lysa Morningdew" and 1 or 0)
    end
    check(lysa >= 3, "and a third companion tells some of the story")
    check(Chronicle.Class("Mira Stormfeather") == "MAGE" and Chronicle.Class("Borin Ironbeard") == "WARRIOR"
        and Chronicle.Class("Lysa Morningdew") == "PRIEST", "the sample companions come with their classes")
    SlashCmdList.FAMULUS("chronicle demo clear")
    check(#Chronicle.Entries() == count, "/fam chronicle demo clear removes them and nothing else")
    check(Chronicle.Class("Mira Stormfeather") == nil, "and their classes")
    check(#Chronicle.ProfileNames() == 1 and Chronicle.Profile("Real Friend"), "and only the sample profiles")
    FamulusDB.chronicle.profiles = nil
end
enable("ownJourney", false)
mock.Fire("PLAYER_LEVEL_UP", 14)
check(#Chronicle.Entries() == 5 and ns:CountRegisteredEvents() == eventsBeforeChronicle, "switched off, it hears nothing")

-- Companions: level-ups seen on the friends list.
local friend = { name = "Jaina Proudmoore", level = 19, area = "Duskwood", guid = "Player-1-FRIEND", connected = true, className = "Mage" }
setState({ friends = { friend } })
enable("companions")
mock.Fire("FRIENDLIST_UPDATE")
check(#Chronicle.Entries() == 5 and Chronicle.FriendLevel("Player-1-FRIEND") == 19, "a friend seen for the first time is only remembered")
friend.level = 20
mock.Fire("FRIENDLIST_UPDATE")
mock.Fire("FRIENDLIST_UPDATE")
local friendEntry = Chronicle.Entries()[6]
check(#Chronicle.Entries() == 6 and friendEntry.who == "Jaina Proudmoore" and not Chronicle.IsOwn(friendEntry)
    and Chronicle.Text(friendEntry) == "Jaina Proudmoore reaches level 20", "their level-up is written once")
check(Chronicle.Class("Jaina Proudmoore") == "MAGE" and ns.SocialService.ClassFromName("Warrior") == "WARRIOR"
    and ns.SocialService.ClassFromName("Nobody") == nil, "the friends list tells their class along with it, in the client's language")
friend.connected, friend.level = false, 0
mock.Fire("FRIENDLIST_UPDATE")
check(#Chronicle.Entries() == 6 and Chronicle.FriendLevel("Player-1-FRIEND") == 20, "a friend going offline changes nothing")
ns.AliasService.Set("Jaina Proudmoore", "Anna")
check(Chronicle.Text(friendEntry) == "Anna (Jaina Proudmoore) reaches level 20" and select(2, Chronicle.Text(friendEntry)) == "in Duskwood"
    and Chronicle.Label(friendEntry) == "Anna (Jaina Proudmoore)",
    "a companion appears under the alias, the character name in brackets behind it")
ns:SetOption("general", "chronicleNames", false)
check(Chronicle.Text(friendEntry) == "Anna reaches level 20" and select(2, Chronicle.Text(friendEntry)) == "in Duskwood"
    and Chronicle.Label(friendEntry) == "Anna", "switched off, the alias stands alone")
ns:SetOption("general", "chronicleNames", true)
ns.AliasService.Set("Jaina Proudmoore", nil)
check(Chronicle.Label(friendEntry) == "Jaina Proudmoore", "without an alias, the name alone")
enable("companions", false)
local chronicleBeforeSharing = {}
for i, entry in ipairs(Chronicle.Entries()) do
    chronicleBeforeSharing[i] = entry
end
FamulusDB.chronicle.entries = {}
-- Sharing: friends who use the addon exchange milestones and statistics.
local sharing = ns.features.sharing
local jaina = { name = "Jaina Proudmoore", level = 20, area = "Duskwood", guid = "Player-1-FRIEND", connected = true }
setState({ friends = { jaina }, zone = "Westfall", level = 13, units = { player = { name = "Boris", surname = "Bloom" } },
    statistics = { [60] = "12", [107] = "3,456", [98] = "210", [932] = "7", [999] = "5" } })
mock.sent = {}
local eventsBeforeSharing = ns:CountRegisteredEvents()
enable("ownJourney")
enable("sharing")
mock.Advance(1)
check(#mock.sent == 1 and mock.sent[1].text == "1~H~0" and mock.sent[1].chatType == "WHISPER" and mock.sent[1].target == "Jaina Proudmoore",
    "switched on, it greets the friends who are online, by whisper")
mock.Advance(3)
check(sharing.ticker == nil, "the queue's ticker stops when nothing waits")
local sharedNow = time()
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~E~" .. sharedNow .. "~level~level=40", "WHISPER", "Some Stranger")
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~E~" .. sharedNow .. "~level~level=40", "GUILD", "Jaina Proudmoore")
mock.Fire("CHAT_MSG_ADDON", "OtherAddon", "1~E~" .. sharedNow .. "~level~level=40", "WHISPER", "Jaina Proudmoore")
check(#Chronicle.Entries() == 0, "nothing is accepted from strangers, other channels or other addons")
mock.sent = {}
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~E~" .. sharedNow .. "~death~level=20;zone=Dusk|cffwood;gold=9", "WHISPER", "Jaina-Proudmoore")
local theirs = Chronicle.Entries()[1]
check(theirs and theirs.who == "Jaina Proudmoore" and theirs.k == "death" and theirs.level == 20 and theirs.gold == nil
    and not theirs.zone:find("|", 1, true), "a friend's entry is taken in: known fields only, escape codes removed")
check(Chronicle.Text(theirs):find("Jaina Proudmoore has fallen in", 1, true) ~= nil, "and names the companion")
do
    local card = ns.UI.Feed.Shown()[1]
    check(card and card:IsShown() and card.title:GetText():find("Jaina Proudmoore has fallen in", 1, true) ~= nil,
        "fresh news of a companion appears as a card on screen")
end
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~E~" .. sharedNow .. "~death~level=20;zone=Duskwood", "WHISPER", "Jaina Proudmoore")
check(#Chronicle.Entries() == 1, "the same news twice is written once")
mock.Advance(1)
check(#mock.sent == 1 and mock.sent[1].text == "1~H~" .. sharedNow, "a first contact is greeted back, with how far their news reaches")
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~S~20~60=12;107=3456;bad=1~PRIEST", "WHISPER", "Jaina Proudmoore")
local profile = Chronicle.Profile("Jaina Proudmoore")
check(profile and profile.level == 20 and profile.stats[60] == 12 and profile.stats[107] == 3456, "their statistics become a profile")
check(Chronicle.Class("Jaina Proudmoore") == "PRIEST", "and their class is remembered")
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~S~20~60=12~Mage|cff", "WHISPER", "Jaina Proudmoore")
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~S~20~60=12", "WHISPER", "Jaina Proudmoore")
check(Chronicle.Class("Jaina Proudmoore") == "PRIEST" and Chronicle.Profile("Jaina Proudmoore").level == 20,
    "a class that is none, or none at all from an older version, changes nothing")

-- Own milestones go out to linked friends; a greeting is answered.
mock.sent = {}
mock.Fire("PLAYER_LEVEL_UP", 14)
mock.Advance(1)
check(#mock.sent == 1 and mock.sent[1].text:find("^1~E~%d+~level~level=14;zone=Westfall$") ~= nil, "an own milestone is sent to linked friends: " .. tostring(mock.sent[1] and mock.sent[1].text))
mock.Advance(3)
check(#mock.sent == 1, "the statistics wait until the game has counted the event")
mock.Advance(2)
check(#mock.sent == 2 and mock.sent[2].text == "1~S~13~107=3456;60=12;932=7;98=210~WARRIOR",
    "a moment later the own statistics follow it: " .. tostring(mock.sent[2] and mock.sent[2].text))
mock.sent = {}
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~H~0", "WHISPER", "Jaina Proudmoore")
mock.Advance(2)
check(#mock.sent == 2 and mock.sent[1].text:find("~level~", 1, true) and mock.sent[2].text == "1~S~13~107=3456;60=12;932=7;98=210~WARRIOR",
    "a greeting is answered with what they missed and the own statistics: " .. tostring(mock.sent[2] and mock.sent[2].text))
mock.sent = {}
setState({ friends = { jaina }, zone = "Westfall", level = 13, lockdown = true })
mock.Fire("PLAYER_DEAD")
mock.Advance(2)
check(#mock.sent == 0, "during a boss fight nothing is sent")
-- The game has counted the death by the time the statistics follow.
setState({ friends = { jaina }, zone = "Westfall", level = 13, statistics = { [60] = "13", [107] = "3,456", [98] = "210", [932] = "7" } })
mock.Advance(1)
check(#mock.sent == 1 and mock.sent[1].text:find("~death~", 1, true) ~= nil, "it goes out afterwards")
mock.sent = {}
mock.state.zone = "Redridge Mountains"
mock.Fire("ZONE_CHANGED_NEW_AREA")
mock.Advance(5)
check(#mock.sent == 2 and mock.sent[1].text:find("~zone~", 1, true) ~= nil and mock.sent[2].text == "1~S~13~107=3456;60=13;932=7;98=210~WARRIOR",
    "the statistics follow the death with the new count, once for events in a row: " .. tostring(mock.sent[2] and mock.sent[2].text))
mock.state.zone = "Westfall"
mock.sent = {}
jaina.connected = false
mock.Fire("FRIENDLIST_UPDATE")
mock.Fire("BOSS_KILL", 5, "Hogger")
mock.Advance(1)
check(#mock.sent == 0, "a friend who went offline gets no whisper")
jaina.connected = true

-- Passing on: news of someone offline comes from a companion who has it, only
-- about guild members or people whose addon answered directly.
check(sharing.Key("Jaina Proudmoore-Realm") == sharing.Key("Jaina-Proudmoore"), "a name with the client's realm suffix is the same person")
enable("sharing", false)
mock.sent = {}
setState({ friends = { jaina }, zone = "Westfall", level = 13, units = { player = { name = "Boris", surname = "Bloom" } },
    guild = { { name = "Thrall Hellscream-Forever", online = true }, { name = "Varian Wrynn-Forever" }, { name = "Boris Bloom-Forever", online = true } } })
enable("sharing")
mock.Advance(2)
local function sentTo(target, text)
    for _, message in ipairs(mock.sent) do
        if message.target == target and (not text or message.text == text) then
            return message
        end
    end
end
check(sentTo(nil, "1~P") and sentTo(nil, "1~P").chatType == "GUILD" and sentTo("Jaina Proudmoore") and not sentTo("Thrall Hellscream"),
    "switched on, it greets the guild once on its channel and whispers to friends only")
mock.sent = {}
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~P", "GUILD", "Boris Bloom-Forever")
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~P", "GUILD", "Some Stranger")
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~P", "GUILD", "Thrall Hellscream-Forever")
mock.Advance(2)
check(#mock.sent == 1 and sentTo("Thrall Hellscream", "1~H~0"), "a guild member's greeting is answered by whisper; its own echo and strangers are not")
local relayedAt = time() - 600
mock.sent = {}
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~O~Varian Wrynn~" .. relayedAt, "WHISPER", "Thrall Hellscream")
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~O~Some Stranger~" .. relayedAt, "WHISPER", "Thrall Hellscream")
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~O~Boris Bloom~" .. relayedAt, "WHISPER", "Thrall Hellscream")
mock.Advance(3)
check(sentTo("Thrall Hellscream", "1~W~Varian Wrynn~0") and #mock.sent == 2 and sentTo("Thrall Hellscream", "1~H~0"),
    "news of an offline guild member is asked for; of strangers and of oneself not")
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~R~Some Stranger~" .. relayedAt .. "~level~level=30", "WHISPER", "Thrall Hellscream")
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~R~Varian Wrynn~" .. relayedAt .. "~death~level=30;zone=Duskwood", "WHISPER", "Thrall Hellscream")
local relayed
for _, entry in ipairs(Chronicle.Entries()) do
    if entry.via or entry.who == "Some Stranger" then
        check(relayed == nil, "only one passed-on entry is written")
        relayed = entry
    end
end
check(relayed and relayed.who == "Varian Wrynn" and relayed.via == "Thrall Hellscream" and relayed.k == "death"
    and select(2, Chronicle.Text(relayed)) == "at level 30  ·  via Thrall Hellscream", "a passed-on entry names who passed it on; one about a stranger is dropped")
check(Chronicle.NewestFrom("Varian Wrynn") == 0 and Chronicle.NewestFrom("Varian Wrynn", true) == relayedAt,
    "a passed-on entry does not move the mark the person answers to")
local before = #Chronicle.Entries()
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~R~Varian Wrynn~" .. (relayedAt + 1) .. "~level~level=31", "WHISPER", "Jaina Proudmoore")
check(#Chronicle.Entries() == before, "passed-on news is taken only from the companion asked")
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~E~" .. relayedAt .. "~death~level=30;zone=Duskwood", "WHISPER", "Varian Wrynn-Forever")
check(#Chronicle.Entries() == before, "the same news told later by the person themselves is written once")
-- Jaina answered directly earlier: she is vouched for while she is offline.
mock.Advance(2)
mock.sent = {}
jaina.connected = false
mock.Fire("FRIENDLIST_UPDATE")
check(Chronicle.Link(sharing.Key("Jaina Proudmoore")) ~= nil, "a direct answer is remembered")
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~O~Jaina Proudmoore~" .. (time() + 1), "WHISPER", "Thrall Hellscream")
mock.Advance(1)
check(#mock.sent == 1 and mock.sent[1].text:find("^1~W~Jaina Proudmoore~%d+$") ~= nil, "news of a friend whose addon answered before is asked for")
-- Asked by a companion: what is known of someone else goes out, passed on.
mock.sent = {}
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~W~Varian Wrynn~0", "WHISPER", "Thrall Hellscream")
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~W~Thrall Hellscream~0", "WHISPER", "Thrall Hellscream")
mock.Advance(2)
check(#mock.sent == 1 and mock.sent[1].text == "1~R~Varian Wrynn~" .. relayedAt .. "~death~level=30;zone=Duskwood",
    "asked for someone's news, it passes on what it has; nobody gets their own back")
jaina.connected = true

-- The queue keeps to the client's allowance, lets what happens now go first,
-- sends again what the client refused and stops whispering to someone the
-- client calls offline.
enable("sharing", false)
local mira = { name = "Mira Stormfeather", level = 30, area = "Westfall", guid = "Player-1-MIRA", connected = true }
local tom = { name = "Tom Greywind", level = 30, area = "Westfall", guid = "Player-1-TOM", connected = true }
local queuedAt = time()
for i = 1, 25 do
    Chronicle.Add("zone", { t = queuedAt - 3000 + i, zone = "Place " .. i, level = 13 })
end
Chronicle.Add("death", { t = queuedAt - 100, who = "Tom Greywind", level = 30, zone = "Duskwood" })
setState({ friends = { mira, tom }, zone = "Westfall", level = 13, units = { player = { name = "Boris", surname = "Bloom" } },
    guild = { { name = "Boris Bloom-Forever", online = true }, { name = "Thrall Hellscream-Forever", online = true } },
    statistics = { [60] = "13" } })
mock.Advance(10) -- the client's allowance is full again
mock.sent, mock.attempts, mock.addonThrottle = {}, {}, true
enable("sharing")
mock.Advance(1)
check(#mock.sent == 3, "switched on, it greets the guild and both friends")
local function kindsTo(target, messages)
    local kinds = {}
    for _, message in ipairs(messages or mock.sent) do
        if message.target == target then
            local kind = message.text:match("^1~(%a)")
            kinds[kind] = (kinds[kind] or 0) + 1
        end
    end
    return kinds
end
local function refused()
    local count = 0
    for _, message in ipairs(mock.attempts) do
        if message.result ~= 0 then
            count = count + 1
        end
    end
    return count
end
mock.sent = {}
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~H~0", "WHISPER", "Mira Stormfeather")
mock.Advance(0.5)
do
    local cost = 0
    for _, message in ipairs(mock.sent) do
        cost = cost + #message.text + 40
    end
    check(#mock.sent > 10 and cost <= 4000,
        "whispers are not held to the client's ten at once, only to the bandwidth budget (" .. #mock.sent .. " messages, " .. cost .. " bytes)")
end
-- Her own hello back carries the newest of the entries that reached her.
local miraHas = 0
for _, message in ipairs(mock.sent) do
    miraHas = math.max(miraHas, tonumber(message.text:match("^1~E~(%d+)")) or 0)
end
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~H~" .. miraHas, "WHISPER", "Mira Stormfeather")
mock.Advance(1)
Chronicle.Add("item", { item = 4242, name = "Lucky Coin", level = 13 }) -- an own event, as it happens
mock.Advance(60)
do
    local last, inOrder, liveAt, lastOffer = 0, true, nil, nil
    for i, message in ipairs(mock.sent) do
        local entryTime = tonumber(message.text:match("^1~E~(%d+)"))
        if entryTime then
            inOrder = inOrder and entryTime >= last
            last = entryTime
            if message.text:find("~item~item=4242", 1, true) then
                liveAt = i
            end
        elseif message.text:find("^1~O~") then
            lastOffer = i
        end
    end
    check(inOrder and liveAt and lastOffer,
        "the own entries arrive in order, the live one after those caught up")
end
local toMira = kindsTo("Mira Stormfeather")
check(toMira.E == #Chronicle.OwnSince(0, math.huge) and toMira.H == 1,
    "more than 20 missed arrive in rounds, all of them, and a second hello sends nothing twice (" .. tostring(toMira.E) .. " entries)")
check(toMira.S == 3, "the statistics go with each answer and once after the live entry")
check(toMira.O == 2 and not sentTo("Mira Stormfeather", "1~O~Tom Greywind~" .. (queuedAt - 100)),
    "offers do not go twice in a row, and not about someone who is online")
check(refused() == 0 and sharing.ticker == nil, "the client refused nothing, and the queue is empty")
mock.sent = {}
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~H~" .. time(), "WHISPER", "Mira Stormfeather")
mock.Advance(10)
check(kindsTo("Mira Stormfeather").O == 2, "a hello after the offers went out, as after a reload, gets them again")
-- A client that throttles whispers after all: one refusal, then whispers
-- keep to its count as well.
mock.whisperThrottle = true
mock.Advance(20)
mock.sent, mock.attempts = {}, {}
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~H~0", "WHISPER", "Mira Stormfeather")
mock.Advance(60)
check(refused() == 1 and (kindsTo("Mira Stormfeather").E or 0) == #Chronicle.OwnSince(0, math.huge),
    "if the client refuses a whisper, whispers count against its allowance from then on (" .. refused() .. " refused)")
mock.whisperThrottle = false

local refusedOnce = false
mock.addonResult = function()
    if not refusedOnce then
        refusedOnce = true
        return Enum.SendAddonMessageResult.AddonMessageThrottle
    end
end
mock.sent, mock.attempts = {}, {}
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~W~Varian Wrynn~0", "WHISPER", "Mira Stormfeather")
mock.Advance(3)
check(#mock.attempts == 2 and #mock.sent == 1 and mock.sent[1].text:find("^1~R~Varian Wrynn~") ~= nil,
    "a message the client refuses waits and goes again")
local falseOnce = false
mock.addonResult = function()
    if not falseOnce then
        falseOnce = true
        return false
    end
end
mock.sent, mock.attempts = {}, {}
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~W~Varian Wrynn~0", "WHISPER", "Mira Stormfeather")
mock.Advance(3)
check(#mock.attempts == 2 and #mock.sent == 1, "an older client's bare false counts as refused too")
mock.addonResult = function()
    return false
end
mock.sent, mock.attempts = {}, {}
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~W~Varian Wrynn~0", "WHISPER", "Mira Stormfeather")
mock.Advance(20)
check(#mock.attempts == 5 and sharing.ticker == nil, "but a message refused with false five times is given up (" .. #mock.attempts .. " tries)")

mock.addonResult = function(message)
    if message.target == "Tom Greywind" then
        return Enum.SendAddonMessageResult.TargetOffline
    end
end
mock.sent, mock.attempts = {}, {}
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~H~0", "WHISPER", "Tom Greywind")
mock.Advance(30)
check(#mock.attempts == 1 and mock.attempts[1].target == "Tom Greywind",
    "after the client says someone is offline, nothing more is whispered to them")
mock.addonResult = nil
mock.sent, mock.attempts = {}, {}
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~H~" .. queuedAt, "WHISPER", "Tom Greywind")
mock.Advance(10)
check(kindsTo("Tom Greywind").S == 1, "until they speak again")

local ena = { name = "Ena Silverbrook", level = 20, area = "Westfall", guid = "Player-1-ENA", connected = true }
mock.state.friends = { mira, tom, ena }
mock.sent = {}
mock.Fire("FRIENDLIST_UPDATE")
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~E~" .. (queuedAt - 5) .. "~death~level=20;zone=Westfall", "WHISPER", "Ena Silverbrook")
mock.Advance(1)
check(kindsTo("Ena Silverbrook").H == 1 and sentTo("Ena Silverbrook").text == "1~H~" .. (queuedAt - 5),
    "one hello waits per friend, and its mark is read when it goes out")
mock.sent = {}
Chronicle.Add("item", { item = 4243, name = "Lucky Charm", level = 13 }) -- live, to everyone linked
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~H~" .. (queuedAt - 2000), "WHISPER", "Ena Silverbrook")
mock.Advance(30)
do
    local last, inOrder, count, newest = 0, true, 0, nil
    for _, message in ipairs(mock.sent) do
        local entryTime = message.target == "Ena Silverbrook" and tonumber(message.text:match("^1~E~(%d+)"))
        if entryTime then
            inOrder, last, count, newest = inOrder and entryTime >= last, entryTime, count + 1, message.text
        end
    end
    check(count > 1 and inOrder and newest:find("~item~item=4243", 1, true) ~= nil,
        "a hello that comes after a live entry gets what it missed before it, and before the live one")
end

mock.sent = {}
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~P", "GUILD", "Thrall Hellscream-Forever")
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~S~40~60=1", "WHISPER", "Thrall Hellscream")
mock.Advance(3)
mock.sent = {}
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~P", "GUILD", "Thrall Hellscream-Forever")
mock.Advance(1)
check(sentTo("Thrall Hellscream") and sentTo("Thrall Hellscream").text:find("^1~H~") ~= nil,
    "a guild member who reloads and greets again is answered, though still linked")
-- Six friends catching up at once: their entries fill the first lane, and
-- the hellos back still get in.
local crowd = { mira, tom, ena }
for i = 1, 6 do
    crowd[#crowd + 1] = { name = "Friend" .. i .. " Test", level = 20, area = "Westfall", guid = "Player-1-CROWD" .. i, connected = true }
end
mock.state.friends = crowd
mock.Fire("FRIENDLIST_UPDATE")
mock.Advance(10)
mock.sent = {}
for i = 1, 6 do
    mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~H~0", "WHISPER", "Friend" .. i .. " Test")
end
mock.Advance(300)
do
    local greeted, own = 0, #Chronicle.OwnSince(0, math.huge)
    for i = 1, 6 do
        local kinds = kindsTo("Friend" .. i .. " Test")
        if kinds.H == 1 and kinds.E == own then
            greeted = greeted + 1
        end
    end
    check(greeted == 6, "with many entries waiting, every friend still gets the entries and a hello back (" .. greeted .. " of 6)")
end
-- After a loading screen the budget starts empty and refills slowly.
mock.Advance(10)
mock.Fire("PLAYER_ENTERING_WORLD")
mock.sent = {}
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~H~0", "WHISPER", "Mira Stormfeather")
mock.Advance(1)
check(#mock.sent <= 1, "after a loading screen it starts slowly (" .. #mock.sent .. " in the first second)")
mock.Advance(10)
check(#mock.sent > 10, "and is back to full speed a few seconds later (" .. #mock.sent .. ")")
mock.Advance(60)
-- A question that never went out does not keep the person from being asked
-- of someone else.
mock.state.lockdown = true
mock.sent = {}
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~O~Jaina Proudmoore~" .. (time() + 5), "WHISPER", "Tom Greywind")
mock.state.friends = { mira, ena }
mock.Fire("FRIENDLIST_UPDATE")
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~O~Jaina Proudmoore~" .. (time() + 5), "WHISPER", "Mira Stormfeather")
mock.state.lockdown = false
mock.Advance(5)
check(sentTo("Mira Stormfeather") and sentTo("Mira Stormfeather").text:find("^1~W~Jaina Proudmoore~") ~= nil and not sentTo("Tom Greywind"),
    "a question to a companion who went offline before it went out is asked of the next one")
-- A full first lane does not turn away the hello back to a first contact.
local many = {}
for i = 1, 110 do
    many[i] = { name = "Many" .. i .. " Test", level = 20, area = "Westfall", guid = "Player-1-MANY" .. i, connected = true }
end
mock.state.lockdown = true
mock.state.friends = many
mock.Fire("FRIENDLIST_UPDATE")
mock.state.guild = { { name = "Boris Bloom-Forever", online = true }, { name = "Thrall Hellscream-Forever", online = true },
    { name = "Garrosh Hellscream-Forever", online = true } }
mock.Fire("GUILD_ROSTER_UPDATE")
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~S~40~60=1", "WHISPER", "Garrosh Hellscream")
mock.state.lockdown = false
mock.sent = {}
mock.Advance(150)
check(sentTo("Garrosh Hellscream") and sentTo("Garrosh Hellscream").text:find("^1~H~") ~= nil and kindsTo("Many110 Test").H == 1,
    "with the first lane full, hellos still get in, the one back to a first contact too")
mock.addonThrottle = false
enable("sharing", false)
enable("ownJourney", false)
check(ns:CountRegisteredEvents() == eventsBeforeSharing and sharing.ticker == nil, "switched off, it neither listens nor sends")
Chronicle.Clear()
FamulusDB.chronicle = { entries = chronicleBeforeSharing, friends = {} }
setState(stateBeforeChronicle)

-- The page.
if not window:IsShown() then
    SlashCmdList.FAMULUS("")
end
mock.Click(navButton("Chronicle"))
mock.Click(tabButton("Everyone")) -- the page remembers the tab the window tests left it on
mock.Advance(0.1)
check(window.area.name:GetText() == "Chronicle" and tabButton("Everyone").selected and tabButton("Everyone") and tabButton("My journey") and tabButton("Friends") and tabButton("Settings"),
    "the chronicle has its own page: everyone, my journey, companions, recording")
check(not navButton("Chronicle").pill:IsShown(), "the chronicle's entry shows no counter")
-- The entries are told as a picture book: chapters, and events on a line.
-- A card's content is a frame of its own (event.content); the tests read
-- the card and its content as one.
local function bookFrames(field)
    local list = {}
    for _, frame in ipairs(mock.frames) do
        if frame[field] and frame:IsVisible() then
            if field == "story" then
                local event = frame
                frame = setmetatable({}, { __index = function(_, key)
                    local value = event.content and rawget(event.content, key)
                    if value ~= nil then
                        return value
                    end
                    return event[key]
                end })
            end
            list[#list + 1] = frame
        end
    end
    return list
end
local events, heads = bookFrames("story"), bookFrames("chapter")
check(#visibleRows() == 0 and #events == 6 and events[1].story.title == "Reached level 20"
    and events[1].story.fullTitle == "Jaina Proudmoore reaches level 20",
    "everyone: all entries as events of a book, newest first (got " .. #events .. ")")
-- The part of the day a session that began at `timestamp` is named after.
local function partOfDay(timestamp)
    local hour = tonumber(date("%H", timestamp))
    return hour < 5 and "night" or hour < 11 and "morning" or hour < 14 and "midday"
        or hour < 18 and "afternoon" or hour < 23 and "evening" or "night"
end
local oldestEntry = math.huge
for _, entry in ipairs(Chronicle.Entries()) do
    oldestEntry = math.min(oldestEntry, entry.t)
end
check(#heads == 1 and heads[1].chapter.title == ns.L["c_when_today_" .. partOfDay(oldestEntry)]
    and heads[1].title:GetText() == heads[1].chapter.title and heads[1].chapter.small:find("^%d%d:%d%d") ~= nil
    and heads[1].chapter.sub:find("6 events", 1, true) ~= nil,
    "a session of play is a chapter, named after the part of the day it began in, with its time: "
        .. tostring(heads[1] and heads[1].chapter.title) .. " / " .. tostring(heads[1] and heads[1].chapter.small))
check(table.concat(heads[1].chapter.route or {}, ", ") == "Elwynn Forest, Westfall" and heads[1].routeShown == 2
    and heads[1].plates[1].text:GetText() == "Elwynn Forest" and heads[1].plates[2].text:GetText() == "Westfall"
    and heads[1].arrows[2]:IsShown(),
    "below the heading, the route through the player's zones: " .. table.concat(heads[1].chapter.route or {}, ", "))
check(events[1].onLeft and not events[2].onLeft and events[3].onLeft, "the cards alternate left and right of the line")
check(events[2].top > events[1].top and events[2].top < events[1].top + events[1].cardHeight
    and events[3].top >= events[1].top + events[1].cardHeight
    and events[2].top + events[2].cardHeight / 2 >= events[1].top + events[1].cardHeight / 2 + 30,
    "each side runs on by itself: a card reaches into the height of the one across, the dots keep apart")
check(events[1].story.chip and events[1].story.chip.text == "Jaina Proudmoore" and events[1].story.chip.initial == "J"
    and events[1].chipText:IsShown() and not events[2].chipText:IsShown() and events[1].foot == nil,
    "a companion's event names them in the head of the card, not in the headline; the player's own leaves it empty")
check(events[1].number:IsShown() and events[1].number:GetText() == "20" and not events[1].icon:IsShown()
    and events[1].photo:IsShown() and events[1].dim:IsShown() and events[1].story.texture == ns.UI.gameIcons.level
    and events[1].story.weight == "high" and events[1].bar:IsShown(),
    "a level shows its number on an icon of the game; a companion's weighs high too")
check(events[6].story.weight == "high" and events[6].bar:IsShown() and events[6].number:GetText() == "13"
    and events[3].story.kind == "boss" and events[3].story.weight == "high" and events[3].bar:IsShown()
    and events[2].story.weight == "medium" and not events[2].bar:IsShown()
    and events[6].card:GetHeight() > events[2].card:GetHeight() and events[6].picture:GetWidth() > events[2].picture:GetWidth(),
    "level-ups and bosses weigh high: a larger card with the mark of an active card")
check(events[4].story.kind == "death" and events[4].story.weight == "low" and events[5].story.weight == "low"
    and events[4].picture:GetWidth() < events[2].picture:GetWidth() and events[2].picture:GetWidth() < events[6].picture:GetWidth()
    and events[4].picture.mockPoint[4] == events[6].picture.mockPoint[4],
    "deaths and new zones weigh low; the picture grows with the weight and stands at the left")
do
    local same = true
    for index = 1, 6 do
        local picture, title = events[index].picture, events[index].title
        same = same and title.mockPoint[4] - picture.mockPoint[4] - picture:GetWidth()
            == events[1].title.mockPoint[4] - events[1].picture.mockPoint[4] - events[1].picture:GetWidth()
    end
    check(same and not events[2].chipText:IsShown() and events[2].title.mockPoint[5] > events[1].title.mockPoint[5],
        "the text keeps the same distance from the picture on every card; without a name the card has no head line")
end
check(events[4].card:GetWidth() < events[2].card:GetWidth() and events[2].card:GetWidth() < events[6].card:GetWidth()
    and events[6].card:GetWidth() == (window.book:GetWidth() - 44) / 2
    and events[4].card.mockPoint[1] == (events[4].onLeft and "TOPRIGHT" or "TOPLEFT"),
    "the book sets a card's width by its weight, and a narrower card keeps to the line")
check(events[1].strip:IsShown() and events[1].chipDot.mockPoint[4] == events[1].picture.mockPoint[4]
    and events[1].picture.mockPoint[5] <= -28 and not events[2].strip:IsShown(),
    "a companion's name stands in a sunken strip of its own above the picture; the player's own have none")
do
    local level = true
    for index = 1, 6 do
        level = level and events[index].picture.mockPoint[5] == events[index].title.mockPoint[5]
    end
    check(level and events[2].picture.mockPoint[4] == ns.UI.BookPad and events[2].picture.mockPoint[5] == -ns.UI.BookPad
    and events[6].picture.mockPoint[5] == -ns.UI.BookPad and events[1].picture.mockPoint[5] == -(28 + ns.UI.BookPad),
    "picture and text begin at the same height; the room inside the edge and below the strip is the book's, the same for every weight")
end
check(events[4].photo:IsShown() and not events[4].icon:IsShown() and not events[4].number:IsShown()
    and events[4].story.texture == ns.UI.gameIcons.death and events[4].story.title == "Fallen"
    and events[4].detail:GetText() == "at level 13" and events[4].footer:GetText():match("^%d%d:%d%d  ·  Westfall$") ~= nil
    and events[5].story.title == "Discovered a new zone" and events[1].footer:GetText():match("^%d%d:%d%d  ·  Duskwood$") ~= nil
    and not events[1].detail:IsShown() and events[2].footer:GetText():match("^%d%d:%d%d$") ~= nil,
    "other events show an icon of the game; the foot always tells the time and the place, the text never the place")
check(window.scroll.content:GetHeight() >= window.book:GetHeight() and window.book:GetHeight() > 6 * 40,
    "the page is as long as its book")
check(heads[1].small:IsShown() and heads[1].sub:IsShown() and heads[1].left:IsShown() and heads[1].right:IsShown()
    and heads[1].height < 80, "a chapter's heading is one line between two lines, and the route below it")
-- Beside the book a rail that stays put: the week in numbers and the companions.
local rail = window.rail
local function railCard(kind)
    for _, card in ipairs(rail.cards) do
        if card:IsVisible() and card.spec.kind == kind then
            return card
        end
    end
end
check(window.book.width == 600 and window.railScroll:IsShown() and railCard("stats") and railCard("people"),
    "the book leaves room for a rail with the week and the companions")
local week = railCard("stats").spec.stats
check(week[1].plus == "+1" and week[2].value == "1" and week[3].value == "1" and week[4].value == "0",
    "the week in numbers: a level gained, a death, a new zone, no profession")
local people = railCard("people")
check(#people.spec.people == 1 and people.spec.people[1].name == "Jaina Proudmoore" and people.spec.people[1].level == "Level 20"
    and people.spec.people[1].line:find("Reached level 20", 1, true) == 1 and not people.spec.people[1].online,
    "a companion with their level and latest event, offline")
do -- a click on a companion narrows the book to them, a second one widens it again
    mock.Click(people.rows[1])
    check(#bookFrames("story") == 1 and bookFrames("story")[1].story.chip and window.bookFilter:IsVisible()
        and window.bookFilter.text:GetText() == "Only events of Jaina Proudmoore" and people.rows[1].selected,
        "a click on a companion shows only their events, and says so above the book")
    mock.Click(window.bookFilter.clear)
    check(#bookFrames("story") == 6 and not window.bookFilter:IsVisible(), "show all brings the whole book back")
    mock.Click(people.rows[1])
    mock.Click(tabButton("My journey"))
    mock.Click(tabButton("Everyone"))
    check(#bookFrames("story") == 6, "another tab forgets the choice")
end
do -- the class beside a companion's name, and the character name behind an alias
    local first = bookFrames("story")[1]
    check(first.chipInitial:IsShown() and first.chipDot:IsShown() and not first.chipClass:IsShown()
        and people.rows[1].initial:IsShown() and not people.rows[1].class:IsShown(),
        "while the class is not known, the initial stands beside the name")
    Chronicle.Class("Jaina Proudmoore", "MAGE")
    ns.AliasService.Set("Jaina Proudmoore", "Anna")
    mock.Advance(0.1)
    first = bookFrames("story")[1]
    local row = railCard("people").rows[1]
    check(first.story.chip.class == "MAGE" and first.chipClass:IsShown() and not first.chipInitial:IsShown()
        and not first.chipDot:IsShown() and row.class:IsShown() and not row.initial:IsShown() and not row.avatar:IsShown(),
        "a known class shows its icon instead, in the book and in the rail")
    check(first.chipText:GetText() == "Anna (Jaina Proudmoore)" and row.name:GetText() == "Anna (Jaina Proudmoore)"
        and (first.story.detail == nil or not first.story.detail:find("Proudmoore", 1, true)),
        "under an alias, the character name stands in brackets behind it")
    mock.Click(row)
    check(window.bookFilter.text:GetText() == "Only events of Anna (Jaina Proudmoore)", "above the narrowed book as well")
    mock.Click(window.bookFilter.clear)
    ns:SetOption("general", "chronicleNames", false)
    mock.Advance(0.1)
    first = bookFrames("story")[1]
    check(first.chipText:GetText() == "Anna" and railCard("people").rows[1].name:GetText() == "Anna",
        "switched off, the alias stands alone")
    ns:SetOption("general", "chronicleNames", true)
    ns.AliasService.Set("Jaina Proudmoore", nil)
    FamulusDB.chronicle.classes = nil
    mock.Advance(0.1)
end
do -- the guild roster and the friends list tell classes; shown, the chronicle remembers them
    local guildBefore, friendsBefore = mock.state.guild, mock.state.friends
    mock.state.guild = { { name = "Jaina Proudmoore-Forever", class = "PRIEST" }, { name = "Thrall Hellscream-Forever", class = "SHAMAN" } }
    mock.Click(tabButton("My journey"))
    check(Chronicle.Class("Jaina Proudmoore") == nil, "a tab without friends does not look at the lists")
    mock.Click(tabButton("Everyone"))
    local first = bookFrames("story")[1]
    check(Chronicle.Class("Jaina Proudmoore") == "PRIEST" and first.story.chip.class == "PRIEST" and first.chipClass:IsShown()
        and railCard("people").rows[1].class:IsShown() and not railCard("people").spec.people[1].online,
        "the guild roster tells the class of a member who is offline, shown at once in book and rail")
    check(Chronicle.Class("Thrall Hellscream") == nil, "only of people the chronicle tells of")
    mock.state.guild = nil
    mock.state.friends = { { name = "Jaina Proudmoore", guid = "Player-1-JAINA", connected = true, level = 20, className = "Mage" } }
    mock.Click(tabButton("Friends"))
    check(Chronicle.Class("Jaina Proudmoore") == "MAGE" and railCard("brief").spec.online,
        "the friends list tells it of a friend who is online")
    mock.state.friends = {}
    mock.Click(tabButton("Everyone"))
    check(Chronicle.Class("Jaina Proudmoore") == "MAGE" and bookFrames("story")[1].chipClass:IsShown(),
        "gone from the lists, the class stays")
    mock.state.guild, mock.state.friends = guildBefore, friendsBefore
    FamulusDB.chronicle.classes = nil
    mock.Click(tabButton("My journey"))
    mock.Click(tabButton("Everyone"))
end
do -- what repeats right away shares a card
    local now = time()
    Chronicle.Add("death", { zone = "Duskwood", level = 13, t = now - 50 })
    Chronicle.Add("death", { zone = "Duskwood", level = 13, t = now - 51 })
    Chronicle.Add("death", { zone = "Duskwood", level = 12, t = now - 52 })
    Chronicle.Add("level", { level = 22, who = "Jaina Proudmoore", t = now - 53 })
    Chronicle.Add("level", { level = 21, who = "Jaina Proudmoore", t = now - 54 })
    mock.Advance(0.1)
    local deaths, levels
    for _, event in ipairs(bookFrames("story")) do
        if event.story.count and event.story.kind == "death" then
            deaths = event
        elseif event.story.count then
            levels = event
        end
    end
    check(#bookFrames("story") == 8 and bookFrames("chapter")[1].chapter.sub:find("11 events", 1, true) ~= nil,
        "five entries, two cards; the chapter still counts every event")
    check(deaths and deaths.story.title == "Fallen 3 times" and deaths.story.detail == "at levels 12 to 13"
        and deaths.story.fullTitle == "Fallen 3 times in Duskwood"
        and deaths.badge:IsShown() and deaths.badgeText:GetText() == "3"
        and deaths.footer:GetText() == date("%H:%M", now - 52) .. " – " .. date("%H:%M", now - 50) .. "  ·  Duskwood",
        "deaths in one place: one card, how often in the corner, from the first time to the last in the foot")
    check(levels and levels.story.title == "Reached levels 21 to 22" and levels.number:GetText() == "22"
        and not levels.badge:IsShown() and levels.story.fullTitle == "Jaina Proudmoore reaches levels 21 to 22",
        "a companion's levels in a row: one card from the first to the last")
    local entries = Chronicle.Entries()
    for index = #entries, 1, -1 do
        if entries[index].t <= now - 50 and entries[index].t >= now - 54 then
            table.remove(entries, index)
        end
    end
    mock.Click(tabButton("My journey"))
    mock.Click(tabButton("Everyone"))
end
do -- a pause of two hours begins a new chapter; a night past midnight stays one
    local base = os.date("*t", time() - 5 * 3600) -- the day the night belongs to
    local function at(daysBack, hour, minute)
        return os.time({ year = base.year, month = base.month, day = base.day - daysBack, hour = hour, min = minute, sec = 0 })
    end
    local function add(kind, entry, t)
        entry.t, entry.sessionTest = t, true
        Chronicle.Add(kind, entry)
    end
    -- Yesterday evening, through three zones; a friend somewhere else.
    add("death", { zone = "Duskwood", level = 14 }, at(1, 20, 0))
    add("level", { zone = "Duskwood", level = 15 }, at(1, 20, 10))
    add("level", { who = "Jaina Proudmoore", zone = "Ashenvale", level = 22 }, at(1, 20, 20))
    add("zone", { zone = "Redridge Mountains", level = 15 }, at(1, 20, 40))
    add("death", { zone = "Duskwood", level = 15 }, at(1, 21, 0))
    -- A night two days ago that ran past midnight.
    add("death", { zone = "Westfall", level = 13 }, at(2, 23, 15))
    add("zone", { zone = "Duskwood", level = 13 }, at(1, 0, 40))
    -- A long afternoon three days ago through many zones.
    for index = 1, 14 do
        add("zone", { zone = string.format("Zone Number %02d", index), level = 12 }, at(3, 12, index * 5))
    end
    mock.Click(tabButton("My journey"))
    mock.Click(tabButton("Everyone"))
    local chapters = bookFrames("chapter")
    check(#chapters == 4, "four sessions of play, four chapters (got " .. #chapters .. ")")
    local evening, night, long = chapters[2] and chapters[2].chapter, chapters[3] and chapters[3].chapter, chapters[4]
    check(evening and evening.title == "Yesterday evening" and evening.small == "20:00 – 21:00"
        and evening.sub == "Level 14 to 15  ·  5 events",
        "yesterday's session: its part of the day, from when to when, levels and events: "
            .. tostring(evening and evening.title) .. " / " .. tostring(evening and evening.small) .. " / " .. tostring(evening and evening.sub))
    check(evening and table.concat(evening.route, ", ") == "Duskwood, Redridge Mountains, Duskwood",
        "the route follows the player in the order of time, a zone again where they went back; a friend's zone is not part of it")
    local nightDay = at(2, 23, 15) - 5 * 3600
    check(night and night.title == ns.L.c_when_day_night:format(ns.L["c_weekday_" .. date("%w", nightDay)])
        and night.small == date("%Y-%m-%d", nightDay) and night.sub:find("2 events", 1, true) ~= nil,
        "a night past midnight is one chapter, named after the evening it began: "
            .. tostring(night and night.title) .. " / " .. tostring(night and night.small))
    check(long and long.routeShown < 15 and long.plates[1].text:GetText() == "…"
        and long.plates[long.routeShown].text:GetText() == "Zone Number 14" and long.arrows[2]:IsShown()
        and not long.plates[long.routeShown + 1]:IsShown(),
        "a route too long for the book gives up its oldest zones: " .. tostring(long and long.routeShown))
    local entries = Chronicle.Entries()
    for index = #entries, 1, -1 do
        if entries[index].sessionTest then
            table.remove(entries, index)
        end
    end
    mock.Click(tabButton("My journey"))
    mock.Click(tabButton("Everyone"))
    check(#bookFrames("chapter") == 1 and not chapters[2]:IsVisible(), "the chapters no longer needed are hidden")
end
do -- my journey: the week and the professions
    mock.state.professions = { { name = "Tailoring", rank = 92, id = 197 } }
    mock.Click(tabButton("My journey"))
    local bars = railCard("bars")
    check(railCard("stats") and bars and bars.spec.bars[1].label == "Tailoring" and bars.spec.bars[1].value == 92
        and bars.spec.bars[1].max == 300 and bars.bars[1].value:GetText() == "92 / 300",
        "my journey: the week, and the character's professions with their points")
    mock.state.professions = nil
end
do -- companions: one profile each, and whether they are online
    Chronicle.Profile("Jaina Proudmoore", { level = 21, stats = { [60] = 12, [107] = 3456 } })
    mock.state.friends = { { name = "Jaina Proudmoore", guid = "Player-1-JAINA", connected = true, level = 21 } }
    mock.Click(tabButton("Friends"))
    local brief = railCard("brief")
    check(brief and brief.spec.level == "Level 21" and brief.spec.online and brief.spec.stats[1].value == "12"
        and brief.spec.stats[1].label == "Deaths" and brief.spec.stats[3].value == "-" and brief.rows[1].state:GetText() == "online",
        "companions: a profile with their numbers, online from the friends list")
    mock.Click(brief.rows[1])
    check(#bookFrames("story") == 1 and window.bookFilter:IsVisible(), "a profile narrows the book as well")
    FamulusDB.chronicle.profiles = nil
    mock.state.friends = {}
    mock.Click(tabButton("Everyone"))
end
mock.Click(tabButton("My journey"))
mock.Advance(0.1)
events = bookFrames("story")
check(#events == 5 and events[1].story.title == "Challenge completed: Challenge 501" and events[1].story.chip == nil,
    "my journey: only my own")
mock.Click(tabButton("Friends"))
mock.Advance(0.1)
check(#bookFrames("story") == 1 and #visibleRows() == 0, "companions: only theirs")
do -- an item is shown with the game's icon of it, in its own colours
    Chronicle.Add("item", { item = 211527, name = "Cozy Sleeping Bag", who = "Jaina Proudmoore" })
    local function itemEvent()
        mock.Click(tabButton("My journey"))
        mock.Advance(0.1)
        mock.Click(tabButton("Friends"))
        mock.Advance(0.1)
        for _, event in ipairs(bookFrames("story")) do
            if event.story.kind == "item" then
                return event
            end
        end
    end
    local event = itemEvent()
    check(event and event.story.texture == ns.UI.gameIcons.item and event.photo:IsShown() and not event.icon:IsShown(),
        "an item the client has no icon for shows the icon of its kind")
    mock.state.itemIcons = { [211527] = 134400 }
    event = itemEvent()
    check(event and event.story.texture == 134400 and event.photo:IsShown() and not event.icon:IsShown()
        and not event.number:IsShown() and event.photo:GetWidth() < event.picture:GetWidth(),
        "an item shows its own icon inside the frame")
    -- The picture of an item or an ability shows the game's tooltip of it.
    local shownItem, shownSpell, hidden = nil, nil, 0
    GameTooltip.SetItemByID = function(_, id)
        shownItem = id
    end
    GameTooltip.SetSpellByID = function(_, id)
        shownSpell = id
    end
    local hide = GameTooltip.Hide
    GameTooltip.Hide = function(self)
        hidden = hidden + 1
        return hide(self)
    end
    event.picture.scripts.OnEnter(event.picture)
    event.picture.scripts.OnLeave(event.picture)
    check(shownItem == 211527 and shownSpell == nil and hidden == 1 and event.picture.mouseEnabled ~= false,
        "hovering an item's picture shows the item's tooltip, leaving hides it")
    Chronicle.Add("ability", { ability = "riding", who = "Jaina Proudmoore", t = time() - 60 })
    itemEvent()
    local plain
    for _, each in ipairs(bookFrames("story")) do
        if each.story.kind == "ability" then
            each.picture.scripts.OnEnter(each.picture)
        elseif each.story.kind == "level" then
            plain = each
        end
    end
    shownItem = nil
    plain.picture.scripts.OnEnter(plain.picture)
    check(shownSpell == 33388 and shownItem == nil and plain.story.item == nil and plain.story.spell == nil,
        "an ability's picture shows its spell; other pictures show nothing")
    GameTooltip.SetItemByID, GameTooltip.SetSpellByID, GameTooltip.Hide = nil, nil, hide
    -- A click on one of the player's own professions opens it.
    Chronicle.Add("skill", { skill = 197, name = "Tailoring", rank = 75, t = time() - 120 })
    Chronicle.Add("skill", { skill = 186, name = "Mining", rank = 150, who = "Jaina Proudmoore", t = time() - 180 })
    mock.Click(tabButton("Everyone"))
    mock.Advance(0.1)
    local mine, theirs
    for _, each in ipairs(bookFrames("story")) do
        if each.story.kind == "skill" then
            if each.story.chip then
                theirs = each
            else
                mine = each
            end
        end
    end
    mock.opened = nil
    mine.card.scripts.OnMouseUp(mine.card, "RightButton")
    mine.card.scripts.OnMouseUp(mine.card, "LeftButton")
    check(mock.opened and #mock.opened == 1 and mock.opened[1] == 197 and mine.card.mouseEnabled
        and plain.card.mouseEnabled == false, "a click on an own profession opens it; other cards do nothing")
    -- A companion's recipe book opens from a link built for them, while they are online.
    local friendsBefore, guildBefore = mock.state.friends, mock.state.guild
    mock.state.friends, mock.state.guild, mock.links = {}, nil, nil
    theirs.card.scripts.OnMouseUp(theirs.card, "LeftButton")
    check(theirs.card.mouseEnabled and mock.links == nil, "a companion who is not online has no recipe book to show")
    mock.state.friends = { { name = "Jaina Proudmoore", guid = "Player-1-JAINA", connected = true, level = 20 } }
    theirs.card.scripts.OnMouseUp(theirs.card, "LeftButton")
    mock.state.friends = {}
    mock.state.guild = { { name = "Jaina Proudmoore-Forever", online = true, guid = "Player-1-GJAINA" } }
    theirs.card.scripts.OnMouseUp(theirs.card, "LeftButton")
    check(mock.links and #mock.links == 2 and mock.links[1] == "trade:Player-1-JAINA:2656:186"
        and mock.links[2] == "trade:Player-1-GJAINA:2656:186" and #mock.opened == 1,
        "online, as a friend or in the guild, the book opens from a link built for them")
    check(not Chronicle.HasBook(182) and Chronicle.BookLink("Jaina Proudmoore", 182) == nil, "a gathering profession has no book")
    mock.state.friends, mock.state.guild = friendsBefore, guildBefore
    mock.state.itemIcons = nil
    local entries = Chronicle.Entries()
    for index = #entries, 1, -1 do
        if entries[index].k == "item" or entries[index].k == "ability" or entries[index].k == "skill" then
            table.remove(entries, index)
        end
    end
    mock.Click(tabButton("My journey"))
    mock.Advance(0.1)
    mock.Click(tabButton("Friends"))
    mock.Advance(0.1)
    check(#bookFrames("story") == 1 and bookFrames("story")[1].story.texture == ns.UI.gameIcons.level
        and bookFrames("story")[1].story.item == nil, "a frame used again shows the picture of its new event")
end
mock.Click(tabButton("Settings"))
mock.Advance(0.1)
check(#visibleRows() == 16 and visibleRows()[1].toggle ~= nil and #bookFrames("story") == 0
    and not window.railScroll:IsShown() and visibleRows()[1]:GetWidth() == 900,
    "recording: the four switches, the feed's eleven options and how people are named; no book, no rail (got " .. #visibleRows() .. ")")
check(visibleRows()[16].item.key == "chronicleNames" and visibleRows()[16].toggle ~= nil and visibleRows()[16].item.get() == true,
    "the character name behind an alias is a switch of its own, on from the start")
Chronicle.Clear()
mock.Advance(0.1)
mock.Click(tabButton("Everyone"))
mock.Advance(0.1)
check(#visibleRows() == 1 and visibleRows()[1].label:GetText() == "Nothing recorded yet" and #bookFrames("story") == 0,
    "an empty chronicle says how to begin")
mock.Click(navButton("Aliases"))
SlashCmdList.FAMULUS("")

---------------------------------------------------------------------------
section("Widgets: crest")
---------------------------------------------------------------------------

do
    local crest = ns.UI.Crest(UIParent, 40)
    crest:SetPerson("Mira", "MAGE")
    check(crest.icon:IsShown() and not crest.initial:IsShown(), "a known class shows its icon")
    crest:SetPerson("Mira", nil)
    check(crest.initial:GetText() == "M" and crest.initial:IsShown() and not crest.icon:IsShown(), "without a class, the initial")
    crest:SetPerson("Ena", "NOSUCHCLASS")
    check(crest.initial:GetText() == "E" and not crest.icon:IsShown(), "a class the client has no icon for shows the initial too")
    crest:SetProgress(0.7)
    check(crest.ringShown and crest.swipe.paused and crest.swipe.progress == 0.7, "the ring stands still at the progress")
    crest:SetProgress(1)
    check(crest.swipe.paused and crest.swipe.cooldown[1] > GetTime() - 100, "at the top tier the ring is full, not a finished cooldown")
    check(crest.swipe.noCooldownCount == true, "cooldown-count addons leave the ring alone")
    local badge = ns.UI.TierBadge(UIParent)
    badge:SetTier(3)
    check(badge.text:GetText() == "Trusted" and badge:GetWidth() > 0, "the badge names the tier")
    local bar = ns.UI.TierBar(UIParent, 300)
    bar:SetTier(2, 0.5)
    check(bar.current:GetText() == "Acquainted" and bar.next:GetText() == "Trusted" and #bar.segments == 3
        and bar.segments[1].share == 1 and bar.segments[2].share == 0.5 and bar.segments[3].share == 0
        and bar.segments[2].fill:IsShown() and not bar.segments[3].fill:IsShown()
        and bar.segments[2].fill:GetWidth() == bar.segments[2]:GetWidth() / 2,
        "the bar names where you stand and the next tier; three segments, filled as far as you have come")
    bar:SetTier(2, 0.001)
    check(bar.segments[2].fill:GetWidth() == 6, "a sliver keeps its round ends")
    bar:SetTier(4, 1)
    check(bar.next:GetText() == "" and bar.segments[3].share == 1, "at the top all three are full and nothing is next")
end

---------------------------------------------------------------------------
section("Fellow travellers")
---------------------------------------------------------------------------

local Fellows = ns.FellowService
local fellows = ns.features.rememberFellows
local stateBeforeFellows, eventsBeforeFellows, realTime = mock.state, ns:CountRegisteredEvents(), time
local timersBeforeFellows = mock.ActiveTimers()
local clock = 1800000000
time = function(when)
    return when and realTime(when) or clock
end
local mira = { name = "Mira", surname = "Sturmfeder", guid = "Player-1-MIRA", level = 20, class = "MAGE" }
local tom = { name = "Tom", surname = "Hartwig", guid = "Player-1-TOM", level = 21, class = "PRIEST" }

check(Fellows.Tier(0) == 1 and select(2, Fellows.Tier(1800)) == 0.5, "under an hour: encounter, halfway at 30 min")
check(Fellows.Tier(3600) == 2 and Fellows.Tier(36000) == 3 and Fellows.Tier(144000) == 4, "tiers start at 1, 10 and 40 hours")
check(select(2, Fellows.Tier(200000)) == 1 and select(3, Fellows.Tier(200000)) == nil, "the top tier is full and has no next step")
check(select(3, Fellows.Tier(3000)) == 600, "and below it, the time to the next tier")

check(not fellows.enabled and FamulusDB.fellows == nil, "nobody is remembered until the feature is switched on")
setState({ zone = "Westfall", level = 18 })
enable("rememberFellows")
check(fellows.enabled and fellows.events.GROUP_ROSTER_UPDATE and fellows.events.BOSS_KILL and fellows.events.PLAYER_LOGOUT,
    "switched on, it listens to the group")
check(FamulusDB.fellows == nil, "outside a group nothing is written")

-- A party forms in a dungeon.
mock.state.group = { members = { mira, tom } }
mock.state.zone, mock.state.instanceType = "The Deadmines", "party"
mock.Fire("GROUP_ROSTER_UPDATE")
local miraData = FamulusDB.fellows and FamulusDB.fellows["Player-1-MIRA"]
check(Fellows.Count() == 2 and miraData and miraData.name == "Mira Sturmfeder" and miraData.level == 20
    and miraData.class == "MAGE" and miraData.times == 1 and miraData.firstZone == "The Deadmines"
    and Fellows.IsTogether("Player-1-MIRA"), "a party member is remembered: name, level, class, where you met")
check(FamulusDB.fellows["Player-1-SELF"] == nil, "the player is not their own fellow")
local fellowRuns = FamulusDB.fellowRuns
check(fellowRuns and #fellowRuns == 1 and fellowRuns[1].z[1] == "The Deadmines" and fellowRuns[1].who["Player-1-MIRA"]
    and fellowRuns[1].who["Player-1-TOM"] and select(2, Fellows.Runs()) == fellowRuns[1],
    "the group itself is written down too: where, and who is in it")
check(mock.ActiveTimers() == timersBeforeFellows, "counting the time together needs no timer")

-- An hour later a boss falls, then Tom leaves.
clock = clock + 3600
mock.Fire("BOSS_KILL", 1, "Edwin VanCleef")
local tomData = FamulusDB.fellows["Player-1-TOM"]
check(miraData.bosses == 1 and tomData.bosses == 1, "a boss counts for everyone in the group")
mock.state.group = { members = { mira } }
mock.Fire("GROUP_ROSTER_UPDATE")
check(not Fellows.IsTogether("Player-1-TOM") and tomData.seconds == 3600 and tomData.zone == "The Deadmines",
    "whoever leaves has their time together counted")
check(fellowRuns[1].b == 1 and fellowRuns[1].who["Player-1-TOM"].l == clock and fellowRuns[1].who["Player-1-TOM"].f == clock - 3600
    and fellowRuns[1].l == clock, "the group counts its bosses, and from when to when each one was in it")
local tomDay = tomData.days and tomData.days[Fellows.DayKey(clock)]
check(tomDay and tomDay.s == 3600 and tomDay.z == "The Deadmines" and tomDay.b == 1 and tomDay.f == clock - 3600 and tomDay.l == clock,
    "a day records time, zone, bosses, first and last moment")
check(tomDay.k and #tomDay.k == 1 and tomDay.k[1].n == "Edwin VanCleef" and tomDay.k[1].z == "The Deadmines" and tomDay.k[1].t == clock,
    "in a party the day names the boss itself, without the chronicle")
check(tomData.firstLevel == 18 and #Fellows.Days(tomData) == 1 and Fellows.Days(tomData)[1].key == Fellows.DayKey(clock),
    "the player's level when you met is kept, and the days can be listed")

-- A /reload: logging out ends the stretch, the group goes on.
clock = clock + 600
mock.Fire("PLAYER_LOGOUT")
check(miraData.seconds == 4200 and not Fellows.IsTogether("Player-1-MIRA"), "logging out counts the time so far")
clock = clock + 60
mock.Fire("PLAYER_ENTERING_WORLD")
check(Fellows.IsTogether("Player-1-MIRA") and miraData.times == 1, "the same group right after a reload is no new time together")
check(#fellowRuns == 1 and select(2, Fellows.Runs()) == fellowRuns[1], "and its run goes on")

-- Offline members, unknown names and battlegrounds do not count.
mira.offline = true
mock.Fire("GROUP_ROSTER_UPDATE")
check(not Fellows.IsTogether("Player-1-MIRA"), "a member who went offline is not counted")
mira.offline = nil
mock.state.group.members[2] = { name = "Unknown", guid = "Player-1-UNKNOWN" }
mock.Fire("GROUP_ROSTER_UPDATE")
check(FamulusDB.fellows["Player-1-UNKNOWN"] == nil and Fellows.IsTogether("Player-1-MIRA"),
    "a member whose name the client does not know yet is skipped")
mock.state.group.members[2] = nil
mock.state.instanceType = "pvp"
mock.Fire("PLAYER_ENTERING_WORLD")
check(not Fellows.IsTogether("Player-1-MIRA"), "battlegrounds do not count")
check(select(2, Fellows.Runs()) == nil, "with nobody counted, the group's run is over")
mock.state.instanceType = nil

-- Hours later they meet again.
clock = clock + 3 * 3600
mock.state.zone = "Westfall"
mock.Fire("GROUP_ROSTER_UPDATE")
check(miraData.times == 2 and Fellows.IsTogether("Player-1-MIRA"), "after a while apart, the next group is a new time together")
check(#fellowRuns == 2 and fellowRuns[2].z[1] == "Westfall" and fellowRuns[2].who["Player-1-TOM"] == nil,
    "and a new run, with only who is in it now")
mock.state.zone = "Elwynn Forest"
mock.Fire("ZONE_CHANGED_NEW_AREA")
mock.state.zone = "Westfall"
mock.Fire("ZONE_CHANGED_NEW_AREA")
check(table.concat(fellowRuns[2].z, ", ") == "Westfall, Elwynn Forest, Westfall", "the run keeps where it went, also coming back")

-- Raids count unless switched off.
mock.state.group = { raid = true, members = { mira, tom } }
mock.Fire("GROUP_ROSTER_UPDATE")
check(Fellows.IsTogether("Player-1-TOM") and tomData.times == 2, "raid members count by default")
check(fellowRuns[2].raid and fellowRuns[2].n == 2 and fellowRuns[2].who["Player-1-TOM"] == nil,
    "a raid's run keeps only how many were in it")
ns:SetOption("rememberFellows", "raids", false)
check(not Fellows.IsTogether("Player-1-TOM") and not Fellows.IsTogether("Player-1-MIRA"),
    "without raids, being in a raid ends the stretch at once")
ns:SetOption("rememberFellows", "raids", true)

-- Only friends and guild: strangers from the group are left out.
local ena = { name = "Ena", surname = "Fremd", guid = "Player-1-ENA", level = 22, class = "DRUID" }
local kael = { name = "Kael", surname = "Dorn", guid = "Player-1-KAEL", level = 25, class = "HUNTER" }
mock.state.friends = { { name = "Mira Sturmfeder", guid = "Player-1-MIRA", connected = true } }
mock.state.guild = { { name = "Tom Hartwig", guid = "Player-1-TOM", online = true } }
mock.state.bnFriends = { { battleTag = "Kael#1234", games = { { characterName = "Kael Dorn", playerGuid = "Player-1-KAEL" } } } }
mock.state.group = { members = { tom, mira, ena, kael } }
mock.reset()
mock.Fire("GROUP_ROSTER_UPDATE")
check(Fellows.IsTogether("Player-1-ENA") and FamulusDB.fellows["Player-1-KAEL"].tag == "Kael#1234"
    and FamulusDB.fellows["Player-1-MIRA"].tag == nil, "by default everyone counts; a Battle.net friend's BattleTag is kept")
check(mock.count("C_FriendList.IsFriend") == 0, "without the option it asks only for BattleTags, not who is a friend")
mock.state.group = { members = { tom, mira } }
mock.Fire("GROUP_ROSTER_UPDATE")
FamulusDB.fellows["Player-1-ENA"], FamulusDB.fellows["Player-1-KAEL"] = nil, nil
check(not fellows.events.FRIENDLIST_UPDATE, "the friends list does not matter while everyone counts")
ns:SetOption("rememberFellows", "friendsOnly", true)
check(fellows.events.FRIENDLIST_UPDATE and fellows.events.PLAYER_GUILD_UPDATE and fellows.events.BN_FRIEND_LIST_SIZE_CHANGED
    and fellows.events.BN_CONNECTED and not fellows.events.BN_FRIEND_INFO_CHANGED,
    "only friends: it listens to the friends list, the guild and Battle.net as well, but not to every status change")
mock.state.group = { members = { tom, mira, ena, kael } }
mock.Fire("GROUP_ROSTER_UPDATE")
check(Fellows.IsTogether("Player-1-MIRA") and Fellows.IsTogether("Player-1-TOM") and Fellows.IsTogether("Player-1-KAEL")
    and FamulusDB.fellows["Player-1-ENA"] == nil, "only friends: friends, guild members and Battle.net friends count, a stranger not")
mock.state.friends[2] = { name = "Ena Fremd", guid = "Player-1-ENA", connected = true }
mock.Fire("FRIENDLIST_UPDATE")
check(Fellows.IsTogether("Player-1-ENA"), "who becomes a friend in the group counts from then on")
mock.state.friends[2] = nil
mock.Fire("FRIENDLIST_UPDATE")
check(not Fellows.IsTogether("Player-1-ENA") and FamulusDB.fellows["Player-1-ENA"] ~= nil,
    "who is no friend any more stops counting, but stays on the list")
mock.state.bnFriends[2] = { battleTag = "Ena#2222", games = { { characterName = "Ena Fremd", playerGuid = "Player-1-ENA" } } }
mock.Fire("BN_FRIEND_LIST_SIZE_CHANGED")
check(Fellows.IsTogether("Player-1-ENA") and FamulusDB.fellows["Player-1-ENA"].tag == "Ena#2222",
    "who becomes a Battle.net friend in the group counts from then on")
mock.state.bnFriends[2] = { battleTag = "Ena#2222", stranger = true, games = { { characterName = "Ena Fremd", playerGuid = "Player-1-ENA" } } }
check(ns.SocialService.BattleTag("Player-1-ENA") == nil and not ns.SocialService.Unit(nil, "Player-1-ENA"),
    "an account the client does not plainly call a friend's is no friend")
mock.state.bnFriends[2] = nil
mock.Fire("BN_FRIEND_LIST_SIZE_CHANGED")
check(not Fellows.IsTogether("Player-1-ENA"), "and who is no Battle.net friend any more stops counting")

-- The circle at one look, for tidying up: by GUID, by name in any spelling,
-- by BattleTag while the Battle.net friend is offline.
mock.state.group = { members = { tom } }
mock.Fire("GROUP_ROSTER_UPDATE")
-- A missing list must not make friends look like strangers: a friends list
-- that has not come since the login, or Battle.net away.
do
    local friendsBefore = mock.state.friends
    mock.state.friends = nil
    local eventsBefore = ns:CountRegisteredEvents()
    mock.reset()
    local _, ready, waiting = ns.SocialService.Circle()
    check(not ready and waiting == "friends" and mock.count("C_FriendList.ShowFriends") == 1,
        "an empty friends list is not trusted before the client has sent it; it is asked for")
    ns.SocialService.Circle()
    check(mock.count("C_FriendList.ShowFriends") == 1, "and asked for once, not on every look")
    mock.Fire("FRIENDLIST_UPDATE")
    _, ready = ns.SocialService.Circle()
    check(ready and ns:CountRegisteredEvents() == eventsBefore, "once it has come, an empty friends list counts, and nobody waits any more")
    mock.state.bnOffline = true
    _, ready, waiting = ns.SocialService.Circle()
    check(not ready and waiting == "battlenet", "without Battle.net its friends cannot be told")
    mock.state.bnOffline = nil
    mock.Fire("BN_CONNECTED")
    _, ready = ns.SocialService.Circle()
    check(ready and ns:CountRegisteredEvents() == eventsBefore, "once Battle.net is back, it counts again")
    mock.state.friends = friendsBefore
end
mock.state.friends = { { name = "Mira Sturmfeder", guid = "Player-1-MIRA", connected = false } }
mock.state.guild = { { name = "Ena Fremd-Realm" } }
mock.state.bnFriends = { { battleTag = "Kael#1234", games = {} } }
local inCircle, circleReady = ns.SocialService.Circle()
check(circleReady and inCircle("Player-1-MIRA") and inCircle("Player-1-X", "Ena-Fremd") and inCircle("Player-1-X", nil, "kael#1234")
    and not inCircle("Player-1-KAEL", "Kael Dorn") and not inCircle(mock.SECRET, mock.SECRET, mock.SECRET),
    "the circle knows friends by GUID, guild members by name, Battle.net friends by BattleTag")
local function onlyMira(guid)
    return guid == "Player-1-MIRA"
end
mock.state.group = { members = { tom, ena } }
mock.Fire("GROUP_ROSTER_UPDATE")
local inGroup = Fellows.Outsiders(onlyMira)
check(not Fellows.IsTogether("Player-1-ENA") and #inGroup == 1 and inGroup[1].guid == "Player-1-KAEL",
    "with only friends, a stranger in the group is not counted, nor tidied away while there")
mock.state.group = { members = { tom } }
mock.Fire("GROUP_ROSTER_UPDATE")
local outsiders = Fellows.Outsiders(onlyMira)
check(#outsiders == 2 and outsiders[1].guid == "Player-1-ENA" and outsiders[2].guid == "Player-1-KAEL",
    "outsiders: whoever the circle does not know, by name; Tom is in the group and stays")
check(Fellows.RemoveOutsiders(inCircle) == 0 and FamulusDB.fellows["Player-1-ENA"] and FamulusDB.fellows["Player-1-KAEL"],
    "nobody goes while the circle knows them all")
mock.state.bnFriends = nil
check(Fellows.RemoveOutsiders((ns.SocialService.Circle())) == 1 and FamulusDB.fellows["Player-1-KAEL"] == nil
    and FamulusDB.fellows["Player-1-ENA"] and FamulusDB.fellows["Player-1-MIRA"], "a former Battle.net friend goes")
FamulusDB.fellows["Player-1-ENA"] = nil
mock.state.friends, mock.state.guild = nil, nil
ns:SetOption("rememberFellows", "friendsOnly", false)
check(not fellows.events.FRIENDLIST_UPDATE and not fellows.events.PLAYER_GUILD_UPDATE and not fellows.events.BN_FRIEND_LIST_SIZE_CHANGED
    and not fellows.events.BN_CONNECTED, "back to everyone, it stops listening to the friends list, the guild and Battle.net")

-- The page.
SlashCmdList.FAMULUS("")
mock.Click(navButton("Fellow travellers"))
mock.Advance(0.1)
check(window.sidebar:IsShown() and window.area.name:GetText() == "Fellow travellers" and window.area.desc:GetText() == ns.L.area_fellows_desc
    and pageTab("Overview") and pageTab("Overview").selected and pageTab("Settings") and not pageTab("Most often"),
    "fellow travellers: the sidebar as everywhere, the name in the head, overview and settings as tabs")
check(window.fellows:GetHeight() > 200, "the overview has a height, so the client can place what is in it")
check(window.fellows:GetWidth() == 1180 - 224 - 2 * 28 and not window.fellows.card:IsShown(),
    "the overview takes the content's width; no card beside it")
check(not navButton("Fellow travellers").pill:IsShown(), "no counter in the sidebar")
local overview = window.fellows
check(overview and overview:IsShown() and overview.tiles[1].guid == "Player-1-MIRA" and overview.tiles[2].guid == "Player-1-TOM"
    and not (overview.tiles[3] and overview.tiles[3]:IsShown()) and not overview.list:IsShown(),
    "up to three people are tiles, the most time together first; no list below")
check(overview.tiles[1].numeral:GetText() == "I" and overview.tiles[1].name:GetText() == "Mira Sturmfeder"
    and overview.tiles[1].sub:GetText() == "Level 20 Mage" and overview.tiles[1].badge.text:GetText() == "Acquainted"
    and overview.tiles[1].stats:GetText() == "1 h 10 min  ·  2×  ·  1 boss" and overview.tiles[1].crest.icon:IsShown(),
    "a tile: rank, name, level and class, bond, numbers: " .. overview.tiles[1].stats:GetText())
check(overview.tiles[2].footText:GetText() == "In your group now" and overview.tiles[1].footText:GetText() == "Last together today in Westfall",
    "the foot says whether they are here or when you last were together")
check(overview.tiles[1].name:GetWidth() > 0 and overview.tiles[1].name:GetWidth() < 300, "names are cut to their tile")
do -- under the mouse a tile lights up, like a clickable card in the book
    local tile = overview.tiles[1]
    check(not tile.hover.parts[1]:IsShown(), "a tile is plain until the mouse is over it")
    tile.scripts.OnEnter(tile)
    mock.Advance(0.5)
    check(tile.hover.parts[1]:IsShown() and tile.hover.level == 1, "under the mouse it lights up")
    tile.scripts.OnLeave(tile)
    mock.Advance(0.5)
    check(tile.hover.level == 0, "and fades when the mouse leaves")
end

-- A click on a tile opens the person's story: their card on the left.
mock.Click(overview.tiles[2])
mock.Advance(0.1)
check(overview.card:IsShown() and overview.card.name:GetText() == "Tom Hartwig" and overview.card.status:GetText() == "In your group now"
    and not overview:IsShown() and window.tabs.back:IsShown() and not pageTab("Overview"),
    "a click on a tile opens the story, the way back instead of the tabs")
mock.Click(window.tabs.back)
mock.Click(overview.tiles[1])
mock.Advance(0.1)
check(overview.card.name:GetWidth() == 320 - 40 and overview.card.bond.current:GetText() == "Acquainted"
    and overview.card.bond.next:GetText() == "Trusted" and overview.card.remaining:GetText() == "8 h 50 min more together",
    "the card: the bond above the numbers, and the time left to the next tier: " .. overview.card.remaining:GetText())
do
    local time = overview.card.cells[1]
    check(time.hours:GetText() == "1" and time.hoursUnit:GetText() == "h" and time.minutes:GetText() == "10"
        and time.minutesUnit:GetText() == "min" and time.label:GetText() == "Together"
        and overview.card.cells[2].value:GetText() == "2" and overview.card.cells[3].value:GetText() == "1",
        "the numbers in one strip: the time in large digits and small units, then times and bosses")
    check(overview.card.first:GetText() == "Met today in The Deadmines" and overview.card.firstLevel:GetText() == "at level 18",
        "when you met, and on a line of its own the player's level then: " .. tostring(overview.card.first:GetText()))
end
mock.Click(window.tabs.back)
mock.Click(pageTab("Settings"))
mock.Advance(0.1)
check(#visibleRows() == 4 and visibleRows()[1].toggle and visibleRows()[4].item.kind == "action" and pageTab("Settings").selected
    and window.resetButton:IsShown() and not overview:IsShown() and not overview.card:IsShown(),
    "settings: the switch and its two options, then tidying up, with reset beside the tabs; no overview")
do -- tidying up: whoever is neither a friend nor in the guild goes, after asking
    local function tidy()
        mock.Advance(0.1)
        return visibleRows()[4]
    end
    local row = tidy()
    check(row.label:GetText() == "Remove everyone but friends and guild" and row.action:IsShown() and not row.action.disabled
        and row.desc:GetText() == "One person is neither on your friends list nor in your guild: Mira Sturmfeder."
        and row.action.label:GetText() == "Remove", "tidy up names who would go; Tom is in the group and stays: " .. row.desc:GetText())
    mock.state.friends = { { name = "Mira Sturmfeder", guid = "Player-1-MIRA", connected = false } }
    ns:Fire("FELLOWS_CHANGED")
    row = tidy()
    check(row.desc:GetText() == "All your fellow travellers are on your friends list or in your guild." and row.action.disabled,
        "with everyone a friend, there is nothing to tidy up")
    mock.state.friends = nil
    -- In a guild whose roster has not come yet, it waits rather than take members for strangers.
    local eventsBefore = ns:CountRegisteredEvents()
    mock.reset()
    mock.state.guild = {}
    ns:Fire("FELLOWS_CHANGED")
    row = tidy()
    check(row.desc:GetText() == "Your guild roster is still loading." and row.action.disabled
        and mock.count("C_GuildInfo.GuildRoster") >= 1 and ns:CountRegisteredEvents() == eventsBefore + 1,
        "before the guild roster has come it waits, and asks for it")
    mock.state.guild = { { name = "Someone Else", guid = "Player-1-ELSE" } }
    mock.Fire("GUILD_ROSTER_UPDATE")
    row = tidy()
    check(row.desc:GetText():find("^One person") ~= nil and not row.action.disabled and ns:CountRegisteredEvents() == eventsBefore,
        "once the roster is there it counts again, and stops listening")
    mock.Click(row.action)
    row = tidy()
    check(row.action.label:GetText() == "Really remove?" and FamulusDB.fellows["Player-1-MIRA"] ~= nil, "the first click asks")
    mock.Advance(5)
    check(row.action.label:GetText() == "Remove", "and after a few seconds it stops asking")
    -- Battle.net gone between showing the names and the second click.
    mock.Click(row.action)
    mock.state.bnOffline = true
    mock.Click(row.action)
    row = tidy()
    check(FamulusDB.fellows["Player-1-MIRA"] ~= nil and row.action.disabled
        and row.desc:GetText() == "Battle.net is not connected right now, so your Battle.net friends cannot be checked.",
        "if Battle.net went away before the second click, nobody goes, and the row says why: " .. row.desc:GetText())
    mock.state.bnOffline = nil
    mock.Fire("BN_CONNECTED")
    row = tidy()
    check(not row.action.disabled and row.desc:GetText():find("^One person") ~= nil, "once Battle.net is back, it counts again")
    window.search.edit:SetText("everyone but")
    check(#visibleRows() == 1 and visibleRows()[1].item.kind == "action", "the search finds tidying up")
    window.search.edit:SetText("mira sturmfeder")
    local tidyHit = false
    for _, hit in ipairs(visibleRows()) do
        tidyHit = tidyHit or hit.item.kind == "action"
    end
    check(not tidyHit, "but not by the names it lists")
    window.search.edit:SetText("")
    row = tidy()
    mock.Click(row.action)
    -- Someone who comes onto the list after the row was read is not removed with the others.
    FamulusDB.fellows["Player-1-NEW"] = { name = "Neu Ling", first = time(), last = time(), times = 1, seconds = 60, bosses = 0 }
    mock.Click(row.action)
    row = tidy()
    check(FamulusDB.fellows["Player-1-MIRA"] == nil and FamulusDB.fellows["Player-1-TOM"] ~= nil
        and FamulusDB.fellows["Player-1-NEW"] ~= nil and row.desc:GetText():find("Neu Ling", 1, true) ~= nil
        and lastChat():find("removed 1 who are neither friends nor in your guild", 1, true),
        "the second click removes whom the row counted, says how many, and leaves who came later: " .. lastChat())
    FamulusDB.fellows["Player-1-NEW"] = nil
    FamulusDB.fellows["Player-1-MIRA"] = miraData
    mock.state.guild = nil
    ns:Fire("FELLOWS_CHANGED")
    mock.Advance(0.1)
end
mock.Click(navButton("Chronicle"))
check(window.area.name:GetText() == "Chronicle" and pageTab("Everyone"), "another page from the sidebar, with its own tabs")
mock.Click(navButton("Fellow travellers"))
check(pageTab("Settings").selected, "the page remembers its tab")

-- The card gives someone an alias; the overview then shows it.
mock.Click(pageTab("Overview"))
mock.Advance(0.1)
mock.Click(overview.tiles[2])
mock.Click(overview.card.alias)
mock.Advance(0.1)
check(window.area.name:GetText() == "Aliases" and tabButton("Names").selected and editor.name.edit:GetText() == "Tom Hartwig",
    "the alias button opens the alias input with the name")
ns.AliasService.Set("Tom Hartwig", "Tommy")
mock.Click(navButton("Fellow travellers"))
mock.Advance(0.1)
check(overview.tiles[2].name:GetText() == "Tommy", "under an alias, the tile shows it")
mock.Click(overview.tiles[2])
check(overview.card.sub:GetText():find("^Tom Hartwig  ·  ") ~= nil, "and the card has the name in the line below")
mock.Click(window.tabs.back)
ns.AliasService.Set("Tom Hartwig", nil)

-- From the fourth on, a list; sixty rows, the search finds everyone, once.
for i = 1, 70 do
    FamulusDB.fellows["Player-1-P" .. i] = { name = "Person " .. i, first = clock - i * 600, last = clock - i * 600, times = 1, seconds = 0, bosses = 0 }
end
ns:Fire("FELLOWS_CHANGED")
mock.Advance(0.1)
local function shownRows()
    local count = 0
    for _, row in ipairs(overview.rows) do
        count = count + (row:IsShown() and 1 or 0)
    end
    return count
end
check(overview.tiles[3]:IsShown() and overview.tiles[3].guid == "Player-1-P10" and overview.list:IsShown()
    and overview.others:GetText() == "Everyone else  ·  69", "the third tile is filled, everyone else is in the list")
check(shownRows() == 60 and overview.more:IsShown() and overview.more:GetText():find("^9 more") ~= nil
    and overview.rows[1].guid == "Player-1-P1", "the list shows sixty, last seen first, and says how many more")
mock.Click(overview.sort)
mock.Advance(0.05)
for _, frame in ipairs(mock.frames) do
    if frame.value == "time" and frame.check and frame:IsVisible() then
        mock.Click(frame)
        break
    end
end
mock.Advance(0.1)
check(overview.rows[1].guid == "Player-1-P11" and overview.sortBox.text:GetText() == "Most time together"
    and overview.tiles[1].guid == "Player-1-MIRA", "the select sorts the list by time; the tiles stay")
mock.Click(overview.rows[1])
check(overview.card.name:GetText() == "Person 11" and window.tabs.back:IsShown(), "a click on a row opens the person's story")
check(not overview.card.cells[1].hours:IsShown() and overview.card.cells[1].minutes:IsShown()
    and overview.card.cells[1].minutes:GetText() == "0", "under an hour the strip shows only the minutes")
mock.Click(window.tabs.back)
window.search.edit:SetText("person 70")
check(#visibleRows() == 1 and visibleRows()[1].item.kind == "fellow" and not overview:IsShown(),
    "the search finds someone beyond the sixty, once")
window.search.edit:SetText("")
for i = 1, 70 do
    FamulusDB.fellows["Player-1-P" .. i] = nil
end
mock.Click(overview.sort)
mock.Advance(0.05)
for _, frame in ipairs(mock.frames) do
    if frame.value == "last" and frame.check and frame:IsVisible() then
        mock.Click(frame)
        break
    end
end

-- Forgetting someone, from the card.
mock.reset()
ns:Fire("FELLOWS_CHANGED")
mock.Advance(0.1)
mock.Click(overview.tiles[1])
mock.Click(overview.card.forget)
mock.Advance(0.1)
check(Fellows.Count() == 1 and FamulusDB.fellows["Player-1-MIRA"] == nil and lastChat():find("Mira Sturmfeder removed", 1, true)
    and overview:IsShown() and not overview.card:IsShown(), "forget removes the person, says so, and goes back to the overview")

-- The story of one fellow traveller: what you did together, as a book.
local storyDay, olderDay = Fellows.DayKey(clock - 3600), Fellows.DayKey(clock - 2 * 86400)
FamulusDB.fellows["Player-1-STORY"] = {
    name = "Lysa Morgentau", class = "PRIEST", level = 30, first = clock - 5 * 86400, firstZone = "Westfall", firstLevel = 25,
    last = clock - 3600, zone = "Uldaman", times = 3, seconds = 11 * 3600, bosses = 4,
    days = {
        [storyDay] = { s = 2 * 3600, z = "Uldaman", b = 1, f = clock - 3 * 3600, l = clock - 3600,
            k = { { t = clock - 2 * 3600, n = "Archaedas", z = "Uldaman" } } },
        -- two bosses in a raid: counted, not named
        [olderDay] = { s = 3600, z = "Badlands", b = 2, f = clock - 2 * 86400 - 3600, l = clock - 2 * 86400 },
    },
}
-- The chronicle knows her too; that is the chronicle's to tell.
Chronicle.Add("level", { level = 31, who = "Lysa-Morgentau", zone = "Uldaman", t = clock - 2 * 3600 - 60 }) -- her name with a hyphen
Chronicle.Add("boss", { name = "Ironaya", zone = "Uldaman", with = { "Lysa Morgentau" }, t = clock - 2 * 3600 - 300 })
FamulusDB.fellows["Player-1-STORY"].days[Fellows.DayKey(clock - 3 * 86400)] = { s = 0, b = 1 } -- a boss, no time yet
ns:Fire("FELLOWS_CHANGED")
mock.Advance(0.1)
check(overview.tiles[1].guid == "Player-1-STORY", "the one with the most time together is first")
mock.Click(overview.tiles[1])
mock.Advance(0.1)
check(overview.card:IsShown() and overview.card.name:GetText() == "Lysa Morgentau" and not overview.card.storyButton:IsShown()
    and overview.card.alias:IsShown() and window.tabs.back:IsShown() and not pageTab("Overview") and not overview:IsShown(),
    "the story keeps the person's card on the left and a way back instead of the tabs")
check(window.fellowBook:IsShown() and window.fellowBook.width == 1180 - 224 - 2 * 28 - 320 - 20,
    "the book fills the rest of the width beside the card")
local storyChapters = bookFrames("chapter")
check(#storyChapters == 4 and storyChapters[1].chapter.small:match("^%d%d:%d%d – %d%d:%d%d$")
    and storyChapters[1].chapter.sub == "2 h 0 min together" and storyChapters[4].chapter.sub == nil,
    "a chapter per session of play, the newest first, down to the first meeting: "
        .. tostring(storyChapters[1] and storyChapters[1].chapter.small))
local sessionTitles = {}
for _, part in ipairs({ "morning", "midday", "afternoon", "evening", "night" }) do
    for _, when in ipairs({ "today", "yesterday" }) do
        sessionTitles[ns.L["c_when_" .. when .. "_" .. part]] = true
    end
end
check(sessionTitles[storyChapters[1].chapter.title] and storyChapters[2].chapter.small:match("^%d%d%d%d%-%d%d%-%d%d$"),
    "the chapters are named by the time of day, an older one with its date: "
        .. tostring(storyChapters[1].chapter.title) .. " / " .. tostring(storyChapters[2].chapter.small))
local found = {}
for _, event in ipairs(bookFrames("story")) do
    found[event.story.title] = event.story
end
check(found["You are now trusted"] and found["You are now trusted"].big, "the day you crossed ten hours is a milestone")
local spans, raidLine, partyLine = 0, nil, nil
for _, event in ipairs(bookFrames("story")) do
    local detail = event.story.detail
    if event.story.kind == "fellow" and detail and detail:find(" to ", 1, true) then
        spans = spans + 1
        if detail:find("2 bosses$") then
            raidLine = detail
        elseif not detail:find("boss", 1, true) then
            partyLine = detail
        end
    end
end
check(spans == 2 and found["On the road in Uldaman"] and found["On the road in Badlands"],
    "a stretch together says where and when")
check(found["Archaedas defeated"] and found["Archaedas defeated"].kind == "boss" and found["Archaedas defeated"].detail == "in Uldaman"
    and not found["Archaedas defeated"].big and found["Archaedas defeated"].weight == nil
    and found["Archaedas defeated"].chip == nil, "bosses defeated together, from the fellow travellers' own day log")
check(raidLine and partyLine, "bosses without a name (a raid) are counted on the day's line, named ones are not")
check(partyLine and partyLine:match("^%d%d:%d%d to %d%d:%d%d$") and raidLine:match("^%d%d:%d%d to %d%d:%d%d  ·  2 bosses$"),
    "the line says from when to when; how long, the chapter's heading says: " .. tostring(partyLine))
check(not found["Ironaya defeated"] and not found["Reached level 31"],
    "nothing from the chronicle: not her own entries, not its bosses")
check(found["Met"] and found["Met"].big and found["Met"].detail:find("at level 25", 1, true), "the first meeting, at the player's level then")
local bossCards, togetherCards = 0, 0
for _, event in ipairs(bookFrames("story")) do
    bossCards = bossCards + (event.story.kind == "boss" and 1 or 0)
    togetherCards = togetherCards + (event.story.kind == "fellow" and 1 or 0)
end
check(bossCards == 1 and togetherCards == 3 and found["Together on the road"] and found["Together on the road"].detail == "1 boss",
    "a day with only a boss and no times still tells that you were together")

-- Her own events are in the chronicle: the card leads there, and back.
check(overview.card.chronicle:IsShown() and overview.card.chronicleWho == "Lysa-Morgentau"
    and overview.card.chronicle.label:GetText() == "In the chronicle",
    "the card leads to her events in the chronicle, whatever the spelling of her name there")
mock.Click(overview.card.chronicle)
mock.Advance(0.1)
check(window.area.name:GetText() == "Chronicle" and tabButton("Friends").selected and window.bookFilter:IsVisible()
    and window.bookFilter.text:GetText() == "Only events of Lysa-Morgentau" and #bookFrames("story") == 1
    and bookFrames("story")[1].story.title == "Reached level 31" and not overview.card:IsShown(),
    "the chronicle opens on friends, narrowed to her")
check(window.bookFilter.toStory:IsShown() and window.bookFilter.toStory.label:GetText() == "Your story",
    "above her events, the way to your story with her")
mock.Click(window.bookFilter.toStory)
mock.Advance(0.1)
check(window.area.name:GetText() == "Fellow travellers" and overview.card:IsShown() and overview.card.name:GetText() == "Lysa Morgentau"
    and window.fellowBook:IsShown() and window.tabs.back:IsShown(), "and back to her story")
ns:SetOption("categories", "chronicle", false)
mock.Advance(0.1)
check(not overview.card.chronicle:IsShown(), "with the chronicle switched off, the card does not lead there")
ns:SetOption("categories", "chronicle", true)
mock.Advance(0.1)
mock.Click(window.tabs.back)
mock.Advance(0.1)
check(overview:IsShown() and not overview.card:IsShown() and pageTab("Overview")
    and #bookFrames("chapter") == 0, "back leads to the overview")
mock.Click(overview.tiles[1])
local lysa = FamulusDB.fellows["Player-1-STORY"]
FamulusDB.fellows["Player-1-STORY"] = nil
ns:Fire("FELLOWS_CHANGED")
mock.Advance(0.1)
check(overview:IsShown() and pageTab("Overview") and not window.tabs.back:IsShown(), "a story whose person is gone falls back to the overview")
FamulusDB.fellows["Player-1-STORY"] = lysa
ns:Fire("FELLOWS_CHANGED")
mock.Advance(0.1)
mock.Click(overview.tiles[1])
mock.Click(navButton("Aliases"))
mock.Click(navButton("Fellow travellers"))
check(not window.fellowBook:IsShown() and overview:IsShown() and pageTab("Overview"), "leaving the page closes the story")
-- Someone from before the day log: just the first meeting.
FamulusDB.fellows["Player-1-OLD"] = { name = "Old Friend", first = clock - 40 * 86400, firstZone = "Duskwood",
    last = clock - 39 * 86400, times = 1, seconds = 600, bosses = 0 }
ns:Fire("FELLOWS_CHANGED")
mock.Advance(0.1)
mock.Click(overview.tiles[3])
mock.Advance(0.1)
storyChapters = bookFrames("chapter")
check(#storyChapters == 1 and storyChapters[1].chapter.small:match("^%d%d%d%d%-%d%d%-%d%d$") and #bookFrames("story") == 1,
    "a person without a day log has only the chapter of the first meeting")
mock.Click(window.tabs.back)
-- A session over midnight is one stretch in one chapter, though the day log splits it.
local today = date("*t", clock)
local midnight = time({ year = today.year, month = today.month, day = today.day, hour = 0 })
FamulusDB.fellows["Player-1-OLD"].days = {
    [Fellows.DayKey(midnight - 60)] = { s = 3540, z = "Tanaris", b = 0, f = midnight - 3600, l = midnight - 60 },
    [Fellows.DayKey(midnight + 60)] = { s = 1740, z = "Tanaris", b = 0, f = midnight + 60, l = midnight + 1800 },
}
ns:Fire("FELLOWS_CHANGED")
mock.Advance(0.1)
mock.Click(overview.tiles[3])
mock.Advance(0.1)
storyChapters = bookFrames("chapter")
local stretches = {}
for _, event in ipairs(bookFrames("story")) do
    if event.story.kind == "fellow" then
        stretches[#stretches + 1] = event.story
    end
end
check(#stretches == 1 and stretches[1].detail == date("%H:%M", midnight - 3600) .. " to " .. date("%H:%M", midnight + 1800)
    and storyChapters[1].chapter.sub == "1 h 28 min together",
    "a session over midnight is one stretch: " .. tostring(stretches[1] and stretches[1].detail))
mock.Click(window.tabs.back)
FamulusDB.fellows["Player-1-STORY"], FamulusDB.fellows["Player-1-OLD"] = nil, nil
Chronicle.Clear()

-- Nobody at all: the empty hint instead of the overview.
local kept = FamulusDB.fellows
FamulusDB.fellows = {}
ns:Fire("FELLOWS_CHANGED")
mock.Advance(0.1)
check(#visibleRows() == 1 and visibleRows()[1].label:GetText() == "Nobody yet" and not overview:IsShown() and not overview.card:IsShown(),
    "without anyone, the page says how to begin")
FamulusDB.fellows = kept

-- The list has a limit; whoever was seen longest ago goes first.
for i = 1, 499 do
    FamulusDB.fellows["Player-1-Q" .. i] = { name = "Q " .. i, first = clock - i, last = clock - i, times = 1, seconds = 0, bosses = 0 }
end
mock.state.group = { members = { tom, mira } }
mock.Fire("GROUP_ROSTER_UPDATE")
check(Fellows.Count() == 500 and FamulusDB.fellows["Player-1-Q499"] == nil and FamulusDB.fellows["Player-1-MIRA"] ~= nil,
    "at 500 people the one seen longest ago makes room")

enable("rememberFellows", false)
check(ns:CountRegisteredEvents() == eventsBeforeFellows and not Fellows.IsTogether("Player-1-TOM"),
    "switched off, it neither listens nor counts")
check(FamulusDB.fellows["Player-1-TOM"].seconds == 3600, "and what it counted stays")

-- The day log keeps 30 days, newest first.
local daily = { name = "Dana", surname = "Tag", guid = "Player-1-DAYS", level = 30, class = "MAGE" }
local firstDay = clock
for i = 0, 30 do
    Fellows.Sync({ daily }, firstDay + i * 86400, "Westfall", 30)
    Fellows.Sync({}, firstDay + i * 86400 + 60, "Westfall", 30)
end
local dana = FamulusDB.fellows["Player-1-DAYS"]
local danaDays = Fellows.Days(dana)
check(#danaDays == 30 and dana.days[Fellows.DayKey(firstDay)] == nil and danaDays[1].key == Fellows.DayKey(firstDay + 30 * 86400)
    and danaDays[1].s == 60, "at most 30 days are kept, the oldest goes first")
FamulusDB.fellows["Player-1-DAYS"] = nil

-- Bosses: named in a party (a dozen a day at most), only counted in a raid.
local raider = { name = "Rai Der", guid = "Player-1-KILLS", level = 60, class = "WARRIOR" }
Fellows.Sync({ raider }, clock, "Molten Core", 60)
Fellows.Boss("Lucifron", "Molten Core", true)
Fellows.Boss(mock.SECRET, "Molten Core", false)
for i = 1, 14 do
    Fellows.Boss("Boss " .. i, "Uldaman", false)
end
Fellows.Sync({}, clock + 60, "Molten Core", 60)
local killDay = FamulusDB.fellows["Player-1-KILLS"].days[Fellows.DayKey(clock)]
check(killDay.b == 16 and #killDay.k == 12 and killDay.k[1].n == "Boss 1" and killDay.k[1].z == "Uldaman",
    "every boss counts; a raid's boss and a secret name are not written down, nor more than twelve a day")
check(Fellows.Find("rai der") == "Player-1-KILLS" and Fellows.Find("Rai-Der") == "Player-1-KILLS" and Fellows.Find("Nobody") == nil,
    "a person is found by name, in any spelling")
FamulusDB.fellows["Player-1-KILLS"] = nil

-- Tier-up days: counted from the time before the log.
local today = Fellows.DayKey(clock)
local oldPerson = { seconds = 41 * 3600, days = { [today] = { s = 3600 } } }
check(next(Fellows.Milestones("Player-1-OLD", oldPerson, clock)) == nil, "time from before the log does not invent milestones")
local newPerson = { seconds = 11 * 3600, days = { [today] = { s = 2 * 3600 } } }
check(Fellows.Milestones("Player-1-NEW", newPerson, clock)[today] == 3, "crossing 10 hours marks the day")
check(next(Fellows.Milestones("Player-1-NONE", { seconds = 120 }, clock)) == nil, "without a log there are no milestones")

-- A broken log from a hand-edited file is dropped.
FamulusDB.fellows["Player-1-BAD"] = { name = "Bad", last = clock, times = 1, firstLevel = "x",
    days = { x = { s = 5 }, [20261124] = "y", [20261123] = { s = -1 }, [20261122] = { s = 60 },
        [20261121] = { s = 60, f = "abc" }, [20261120] = { s = 60, z = {} }, [20261119] = { s = 60, b = "2" },
        [20261118] = { s = 60, k = { { t = 1, n = "Ok" }, { t = "x", n = "Bad time" }, { t = 2, n = {} }, "z", { t = 3, n = "Z", z = 4 } } },
        [20261117] = { s = 60, k = "no list" }, [20261116] = { s = 60, k = { { t = 1 } } } } }
local runsBefore = #FamulusDB.fellowRuns
table.insert(FamulusDB.fellowRuns, { f = "x", l = 2 })
table.insert(FamulusDB.fellowRuns, { f = 5, l = 3 })
table.insert(FamulusDB.fellowRuns, { f = 1, l = 2, z = { "Ok", 5 }, b = "3" })
table.insert(FamulusDB.fellowRuns, "no run")
table.insert(FamulusDB.fellowRuns, { f = 1, l = 2, z = { "Ok", 5 }, who = { ["Player-1-G"] = { f = 1, l = 2 }, ["Player-1-H"] = "bad" } })
ns:Fire("DATABASE_READY")
check(#FamulusDB.fellowRuns == runsBefore + 1 and FamulusDB.fellowRuns[1].f == 1 and FamulusDB.fellowRuns[1].b == 0
    and table.concat(FamulusDB.fellowRuns[1].z, ",") == "Ok" and FamulusDB.fellowRuns[1].who["Player-1-G"]
    and FamulusDB.fellowRuns[1].who["Player-1-H"] == nil, "broken runs are dropped, the good one keeps what is good in it, oldest first")
table.remove(FamulusDB.fellowRuns, 1)
local bad = FamulusDB.fellows["Player-1-BAD"]
check(#bad.days[20261118].k == 1 and bad.days[20261118].k[1].n == "Ok" and bad.days[20261117].k == nil
    and bad.days[20261116] and bad.days[20261116].k == nil, "broken bosses of a day are dropped, the day stays")
check(bad.days[20261122] and bad.days.x == nil and bad.days[20261124] == nil and bad.days[20261123] == nil and bad.firstLevel == nil,
    "broken days are dropped, good ones stay")
check(bad.days[20261121] == nil and bad.days[20261120] == nil and bad.days[20261119] == nil and bad.days[20261122].b == 0,
    "a day with odd times, zone or bosses is dropped; a missing boss count is zero")
FamulusDB.fellows["Player-1-BAD"] = nil

-- Sample people for a look at the list; clearing leaves the real ones.
local realFellows = Fellows.Count()
SlashCmdList.FAMULUS("fellows demo")
SlashCmdList.FAMULUS("fellows demo")
local added = Fellows.Count() - realFellows
check(added > 3 and lastChat():find("/fam fellows demo clear", 1, true), "/fam fellows demo adds sample people, once")
local demoMira = FamulusDB.fellows["Player-0-FAMDEMO01"]
local demoSum = 0
for _, day in ipairs(Fellows.Days(demoMira)) do
    demoSum = demoSum + day.s
end
check(demoMira.firstLevel and #Fellows.Days(demoMira) >= 3 and demoSum <= demoMira.seconds
    and next(Fellows.Milestones("Player-0-FAMDEMO01", demoMira, time())) ~= nil, "sample people have days to tell and a tier-up")
local demoKills, demoNames, demoRepeat = 0, {}, false
for _, day in ipairs(Fellows.Days(FamulusDB.fellows["Player-0-FAMDEMO02"])) do
    demoKills = demoKills + #day.k
    for _, kill in ipairs(day.k) do
        demoRepeat = demoRepeat or demoNames[kill.n] ~= nil
        demoNames[kill.n] = true
    end
end
check(demoKills > 1 and not demoRepeat, "and bosses with names, from the dungeons they were in, each visit going on from the last")
do -- the samples' days are told from their evenings, so both agree
    local demoRuns, miraTime = 0, 0
    for _, run in ipairs(FamulusDB.fellowRuns) do
        if run.demo then
            demoRuns = demoRuns + 1
            local seen = run.who["Player-0-FAMDEMO01"]
            miraTime = miraTime + (seen and seen.l - seen.f or 0)
        end
    end
    check(demoRuns == 11 and miraTime == demoMira.seconds and miraTime == demoSum, "the samples have their evenings, and the days add up to them")
end

-- The timeline: every group as a book, the week beside it.
mock.Click(navButton("Fellow travellers"))
mock.Advance(0.1)
check(pageTab("Overview") and pageTab("Groups") and pageTab("Settings"), "fellow travellers: overview, groups and settings")
mock.Click(pageTab("Groups"))
mock.Advance(0.1)
do
    local found = {}
    for _, event in ipairs(bookFrames("story")) do
        found[event.story.title] = event
    end
    local uldaman = found["On the road in Uldaman and Tanaris"]
    check(uldaman and uldaman.story.noPicture and not uldaman.picture:IsShown() and uldaman.peopleCount == 3
        and uldaman.people[1].name:GetText() == "Mira" and uldaman.people[2].name:GetText() == "Borin"
        and uldaman.people[2].note:GetText() == "until 22:40" and not uldaman.people[1].note:IsShown(),
        "a group's card: where, and who was in it, the earliest first; who left early says when")
    check(uldaman and uldaman.story.detail:find("^19:05 to 23:10  ·  4 h 5 min  ·  3 bosses$") ~= nil,
        "from when to when, how long, and the bosses as a number: " .. tostring(uldaman and uldaman.story.detail))
    check(uldaman and uldaman.footText:IsShown() and uldaman.footText:GetText() == "Again with Mira and Borin  ·  6 times in 30 days"
        and uldaman.foot:IsShown() and uldaman.chipText == nil, "the strip below says when the same people came together again: "
        .. tostring(uldaman and uldaman.footText:GetText()))
    local first = found["On the road in Westfall"]
    check(first and not first.foot:IsShown(), "the first time together has no such strip")
    local met = found["Met Lysa"]
    check(met and met.crest and met.crest:IsShown() and not met.picture:IsShown() and met.story.detail == "in Uldaman, at level 31"
        and met.story.onClick, "a person met: their crest, where and at which level; a click leads to your story")
    check(found["You and Borin are now trusted"] and found["You and Borin are now trusted"].story.big
        and found["You and Lysa are now acquainted"] and not found["You and Lysa are now acquainted"].story.big,
        "a new bond tier is told, from Trusted on as a milestone")
    local heads = bookFrames("chapter")
    local evening
    for _, head in ipairs(heads) do
        evening = evening or (head.chapter.small == "19:05 – 23:10" and head)
    end
    check(evening and evening.chapter.sub == "4 h 5 min together", "a chapter per session of play, as in the chronicle")
    check(not found["Archaedas defeated"], "nothing of what happened: that is the chronicle's to tell")
end
check(window.book.width == 600 and window.railScroll:IsShown() and railCard("stats") and railCard("group") and railCard("people"),
    "beside the book a rail: the week, the most frequent group, the most time together")
check(railCard("stats").spec.stats[1].wide and railCard("stats").spec.stats[1].label == "in groups"
    and railCard("stats").cells[2]:GetWidth() < railCard("stats").cells[1]:GetWidth(), "the time in groups stands alone in its row")
check(railCard("group").spec.names == "Mira and Borin" and railCard("group").spec.note == "4×" and railCard("group").crests[2]:IsShown()
    and railCard("group").names:GetText() == "Mira and Borin", "the group that came together most often this week, with their crests")
check(railCard("people").spec.people[1].name == "Mira Stormfeather" and railCard("people").spec.people[1].level == "12 h 50 min"
    and not railCard("people").rows[1].state:IsShown(), "and with whom you spent the most time, without online or offline")
mock.Click(railCard("people").rows[1])
mock.Advance(0.1)
check(overview.card:IsShown() and overview.card.name:GetText() == "Mira Stormfeather" and window.tabs.back:IsShown(),
    "a click on a person leads to your story")
mock.Click(window.tabs.back)
mock.Advance(0.1)
Fellows.Forget("Player-0-FAMDEMO03")
local lysaLeft = false
for _, run in ipairs(FamulusDB.fellowRuns) do
    lysaLeft = lysaLeft or (run.who and run.who["Player-0-FAMDEMO03"] ~= nil)
end
check(not lysaLeft, "forgetting someone takes them out of the groups too")
SlashCmdList.FAMULUS("fellows demo clear")
check(Fellows.Count() == realFellows and FamulusDB.fellows["Player-1-TOM"] ~= nil, "/fam fellows demo clear removes only them")
local demoLeft = false
for _, run in ipairs(FamulusDB.fellowRuns) do
    demoLeft = demoLeft or run.demo == true
end
check(not demoLeft, "and their evenings")
do -- no group at all: the timeline says how to begin
    local keptRuns = FamulusDB.fellowRuns
    FamulusDB.fellowRuns = nil
    mock.Click(navButton("Fellow travellers"))
    mock.Click(pageTab("Groups"))
    mock.Advance(0.1)
    check(#visibleRows() == 1 and visibleRows()[1].label:GetText() == "No groups yet" and not window.railScroll:IsShown(),
        "without any group, the timeline says how to begin, without a rail")
    FamulusDB.fellowRuns = keptRuns
    mock.Click(pageTab("Overview"))
end

-- The samples speak the addon's language, not the client's (a German client
-- set to English gets English samples, for screenshots of the English window),
-- and both sets name the same people.
mock.state.locale = "deDE"
for _, case in ipairs({ { "enUS", "Mira Stormfeather", "Badlands" }, { "deDE", "Mira Sturmfeder", "Ödland" } }) do
    ns:SetOption("general", "language", case[1])
    SlashCmdList.FAMULUS("chronicle demo")
    SlashCmdList.FAMULUS("fellows demo")
    local zoneSeen, sameFolk = false, true
    for _, entry in ipairs(Chronicle.Entries()) do
        zoneSeen = zoneSeen or (entry.demo and entry.zone == case[3])
        if entry.demo and entry.who then
            sameFolk = sameFolk and Fellows.Find(entry.who) ~= nil
        end
    end
    check(ns:GetLocaleCode() == case[1] and Chronicle.Profile(case[2]) ~= nil and zoneSeen and sameFolk
        and FamulusDB.fellows["Player-0-FAMDEMO01"].name == case[2],
        "sample data in " .. case[1] .. " on a German client, the chronicle's companions among the fellow travellers")
    SlashCmdList.FAMULUS("chronicle demo clear")
    SlashCmdList.FAMULUS("fellows demo clear")
end
FamulusDB.chronicle.profiles = nil
mock.state.locale = nil
ns:SetOption("general", "language", "auto")
check(ns:GetLocaleCode() == "enUS", "back to the client's language")
mock.Click(navButton("Aliases"))
SlashCmdList.FAMULUS("")
FamulusDB.fellows = nil
time = realTime
setState(stateBeforeFellows)

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

check(FamulusDB.selfTest == nil and FamulusDB.dev == nil, "nothing is tested or logged unless asked for")
local eventsBefore, framesBeforeTest = ns:CountRegisteredEvents(), #mock.frames
setState({})
SlashCmdList.FAMULUS("test")
local result = FamulusDB.selfTest
check(type(result) == "table" and result.schema == 1, "/fam test stores a report")
check(result.client.toc == "16001" and result.client.version == "1.60.1", "report names the client build")
check(mock.chat[1]:find("Self-test", 1, true) ~= nil, "summary line in chat: " .. tostring(mock.chat[1]))
check(#mock.chat <= 9, "chat output is capped (got " .. #mock.chat .. " lines)")
check(result.summary.ok + result.summary.warn + result.summary.fail == #result.checks, "summary counts every check")
check(result.summary.fail == 0, "no check fails against the mock (got " .. result.summary.fail .. ")")
for _, feature in ipairs(ns.featureList) do
    check(findCheck(result, "feature", feature.id) ~= nil, "report covers feature " .. feature.id)
end
check(findCheck(result, "api", "C_Timer.After").status == "ok", "present API is reported ok")
check(findCheck(result, "api", "MenuUtil").status == "warn", "API missing from the client is a warning")
check(findCheck(result, "api", "GetItemInfo").status == "ok", "removed API is confirmed as removed")
check(findCheck(result, "api", "UnitIsInMyGuild").status == "ok" and findCheck(result, "names", "guild roster").detail == "not in a guild"
    and findCheck(result, "names", "friends list").detail == "0 friends, 0 with a GUID",
    "the report says how friends list and guild roster look, without names")
setState({ guild = { { name = "Ena Fremd", guid = "Player-1-ENA", online = true }, { name = "Tom Hartwig" } } })
SlashCmdList.FAMULUS("test")
result = FamulusDB.selfTest
check(findCheck(result, "names", "guild roster").detail == "2 members (nil online), 1 listed as offline, 1 with a GUID",
    "for the guild: how many, how many offline, how many with a GUID: " .. findCheck(result, "names", "guild roster").detail)
setState({})
SlashCmdList.FAMULUS("test")
result = FamulusDB.selfTest
check(result.idle.events == eventsBefore and ns:CountRegisteredEvents() == eventsBefore, "the test registers no events")
check(#mock.frames - framesBeforeTest == 2, "the test creates one hidden probe frame, with a Cooldown in it")
SlashCmdList.FAMULUS("test")
check(#mock.frames - framesBeforeTest == 2, "and reuses them on the next run")

-- A feature that needs API the client lacks is a failure in the report.
local needy = ns:NewFeature({ id = "fastLootProbe", category = "chronicle", requires = { "C_Nope.Missing" } })
mock.reset()
result = ns:RunSelfTest()
check(findCheck(result, "feature", "fastLootProbe").status == "fail" and result.summary.fail == 1, "missing required API fails the feature")
ns.features.fastLootProbe = nil
table.remove(ns.featureList)
check(needy.enabled == false, "the probe feature never ran")

-- Developer mode.
mock.reset()
SlashCmdList.FAMULUS("dev")
check(FamulusDB.dev == true and ns:CountRegisteredEvents() == eventsBefore + 3, "/fam dev starts listening for blocked actions")
mock.Fire("ADDON_ACTION_BLOCKED", "OtherAddon", "UseAction()")
check(FamulusDB.devLog == nil, "other addons' blocked actions are ignored")
mock.Fire("ADDON_ACTION_BLOCKED", "Famulus", "StaticPopup_Hide()")
mock.Fire("LUA_WARNING", 0, "Interface/AddOns/Famulus/Core/Init.lua:1: something")
mock.Fire("LUA_WARNING", 0, "Interface/AddOns/Other/x.lua:1: something")
check(#FamulusDB.devLog == 2 and FamulusDB.devLog[1].text == "StaticPopup_Hide()", "own blocked actions and warnings are logged")
for i = 1, 150 do
    mock.Fire("ADDON_ACTION_FORBIDDEN", "Famulus", "call " .. i)
end
check(#FamulusDB.devLog == 100 and FamulusDB.devLog[100].text == "call 150", "the log keeps the newest 100 entries")
result = ns:RunSelfTest()
check(result.loggedProblems == 100, "the report says how many problems were logged")
SlashCmdList.FAMULUS("dev")
check(FamulusDB.dev == nil and FamulusDB.devLog == nil and ns:CountRegisteredEvents() == eventsBefore, "/fam dev again stops and clears the log")
FamulusDB.selfTest = nil

-- With developer mode saved from the last session, login starts both.
mock.Advance(13) -- cards of the live feed from the tests above run out
FamulusDB.dev = true
mock.reset()
ns:Fire("LOGIN")
check(ns:CountRegisteredEvents() == eventsBefore + 3 and FamulusDB.selfTest == nil, "login in developer mode listens, test waits for the UI")
mock.Advance(3.1)
check(type(FamulusDB.selfTest) == "table" and mock.ActiveTimers() == 0, "the self-test runs once, three seconds after login")
SlashCmdList.FAMULUS("dev")
FamulusDB.selfTest = nil
check(ns:CountRegisteredEvents() == eventsBefore, "idle cost is back to normal afterwards")

---------------------------------------------------------------------------
section("Saved settings")
---------------------------------------------------------------------------

enable("companions")
check(FamulusDB.profile.companions and FamulusDB.profile.companions.enabled == true, "a changed option is saved")
enable("companions", false)
check(FamulusDB.profile.companions == nil, "an option back on default is removed from the saved file")

-- A character profile starts as a copy of the account profile and then goes
-- its own way; switching restarts the features with the other choices.
local idleEvents = ns:CountRegisteredEvents()
ns:SetUseCharacterProfile(true)
check(ns:UsesCharacterProfile(), "the character profile can be switched on")
enable("companions")
check(ns.features.companions.enabled and FamulusCharDB.profile.companions.enabled == true and FamulusDB.profile.companions == nil,
    "its changes stay out of the account profile")
ns:SetUseCharacterProfile(false)
check(not ns.features.companions.enabled and ns:CountRegisteredEvents() == idleEvents,
    "switching back stops what only the character profile ran")
ns:SetUseCharacterProfile(true)
check(ns.features.companions.enabled, "and switching again starts it with the kept choices")
ns:SetUseCharacterProfile(false)
FamulusCharDB.profile = nil

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
