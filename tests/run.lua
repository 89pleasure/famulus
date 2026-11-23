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
check(total == 8, "8 features registered (got " .. total .. ")")
check(active == 5, "5 features on by default (got " .. active .. ")")
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

check(window.title:GetText() == "Aliases" and window.subtitle:GetText() == ns.L.area_aliases_desc,
    "the first page is the aliases, described in the header")
check(navButton("Aliases") and navButton("Chronicle") and navButton("Settings") and navButton("About"),
    "the sidebar lists the main features and the addon's own pages")
check(not navButton("Quality of Life") and not navButton("Journal"), "and nothing else")
check(navButton("Aliases").selected and navButton("Aliases").count:GetText() == "4/4",
    "the main feature is selected and counts its active features")
mock.Click(tabButton("Display"))
check(tabButton("Display").selected and window.section.desc:GetText() == ns.L.ui_tab_display_desc, "the line under the tabs describes the tab")
local rows = visibleRows()
check(#rows == 6, "the display tab shows the four features and their options (got " .. #rows .. ")")
check(window.resetButton:IsShown() and window.resetButton.disabled, "reset is greyed out while the tab is on its defaults")
mock.Click(window.resetButton)
check(window.resetButton.label:GetText() == "Reset", "and a click on it does nothing")
local master = window.master
check(master:IsShown() and master.toggle.on and master.caption:GetText() == "ON", "the tab carries the category's master switch, labelled ON")
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
check(#aliasCards == 4 and #aliasCards[1].block.items == 2, "every feature has its own card, together with its options")
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
check(#visibleRows() == 6 and isFolded(optionRow), "the option of a switched-off feature is a slim row without help text")
check(optionRow.disabled and optionRow.dropdown:IsShown(), "it is greyed out but shows its value")
check(optionRow.bullet:IsShown() and not rows[1].bullet:IsShown(), "options are marked with a dot below their feature")
check(optionRow.sunkenLast.parts[1]:IsShown() and not optionRow.sunken:IsShown(), "an option that ends its card has the rounded ground")
check(not aliasCards[1].mark:IsShown() and aliasCards[2].mark:IsShown(), "the card of a switched-off feature loses the mark")
check(not window.resetButton.disabled, "reset becomes available once something differs from the defaults")
check(navButton("Aliases").count:GetText() == "3/4", "the sidebar counts it")
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
mock.Click(master)
mock.Advance(0.3)
check(not ns:IsCategoryEnabled("aliases") and not ns.features.tooltipAliases.enabled, "the master switch stops the features of its category")
check(mock.CountSenderFilters() == 0, "nothing of a switched-off category reacts to the game")
check(ns:GetOption("tooltipAliases", "enabled") == true and ns:GetOption("chatAliases", "enabled") == false, "the features' own settings are kept")
check(not master.toggle.on and master.caption:GetText() == "OFF", "the switch reads OFF")
check(window.section.desc:GetText() == ns.L.ui_tab_display_desc, "the description stays")
check(rows[3].disabled and rows[3].toggle.on, "feature rows are greyed out but still show the choice")
check(tabButton("Display").label:GetAlpha() < 1, "the tab of the category is greyed out")
check(FamulusDB.profile.categories.aliases == false, "the switch is saved")
enable("chatAliases")
check(not ns.features.chatAliases.enabled, "a feature cannot be started while its category is off")
enable("chatAliases", false)
check(ns.features.liveFeed.enabled, "other categories keep running")
mock.Click(master)
mock.Advance(0.3)
check(ns.features.tooltipAliases.enabled and FamulusDB.profile.categories == nil, "switching the category on again resumes the features")
check(tabButton("Display").label:GetAlpha() == 1, "and the tab is back to normal")
check(master.toggle.on and master.caption:GetText() == "ON", "as is the switch")

mock.Click(rows[1])
check(ns.features.chatAliases.enabled, "and the feature on again")
mock.Advance(0.3)
check(not isFolded(optionRow) and optionRow.desc:IsShown() and not optionRow.disabled, "which unfolds its option with its help text")
check(window.resetButton.disabled, "back on defaults, reset is greyed out again")
mock.Click(master)
mock.Advance(0.3)
check(not window.resetButton.disabled, "a switched-off category alone makes the tab resettable")
mock.Click(master)
mock.Advance(0.3)
window.scroll:SetVerticalScroll(30)
mock.Click(rows[1])
mock.Advance(0.3)
mock.Click(rows[1])
mock.Advance(0.3)
check(window.scroll:GetVerticalScroll() == 30, "folding and unfolding do not make the page jump")
window.scroll:SetVerticalScroll(0)

-- Tabs.
mock.Click(tabButton("Names"))
check(tabButton("Names").selected and window.section.desc:GetText() == ns.L.ui_tab_names_desc, "a click on a tab opens it")
mock.Advance(0.3)
check(mock.CountOnUpdateFrames() == 0, "the sliding tab bar comes to rest")
mock.Click(tabButton("Display"))
mock.Click(navButton("Settings"))
mock.Click(navButton("Aliases"))
check(tabButton("Display").selected, "a page remembers its tab")

-- Every page and tab renders, in both languages.
for _, language in ipairs({ "enUS", "deDE" }) do
    ns:SetOption("general", "language", language)
    mock.Advance(0.1)
    for _, page in ipairs({ "area_aliases", "area_chronicle", "cat_general", "cat_about" }) do
        local button = navButton(ns.L[page])
        check(button ~= nil, "navigation entry for " .. page .. " in " .. language)
        if button then
            mock.Click(button)
            check(window.title:GetText() == ns.L[page], "page title for " .. page)
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
check(window.title:GetText() == "Über", "language switch applies immediately, without reload")
check(not window.master:IsShown() and not window.tabs:IsShown(), "the about page has neither tabs nor a master switch")
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
check(window.title:GetText() == "Suche" and #visibleRows() >= 1, "search finds the context menu feature in German")
check(window.search.clear:IsShown(), "the search field offers a clear button while it has text")
check(not window.master:IsShown() and not window.tabs:IsShown(), "search results have neither tabs nor a master switch")
local firstCard
for _, frame in ipairs(mock.frames) do
    if frame.title and frame.note and frame:IsVisible() then
        firstCard = firstCard or frame
    end
end
check(firstCard and firstCard.title:GetText() == "Aliase  ·  Anzeige", "hits are grouped by where they live")
window.search.edit:SetText("zzzz")
check(#visibleRows() == 0, "search with no hit shows no rows")
mock.Click(window.search.clear)
check(window.search.edit:GetText() == "" and window.title:GetText() == "Über", "the clear button empties the field and returns to the page")
check(not window.search.clear:IsShown(), "and disappears again")

-- Reset.
ns:SetOption("general", "language", "enUS")
mock.Advance(0.1)
mock.Click(navButton("Aliases"))
mock.Click(tabButton("Display"))
check(tabButton("Display").selected, "back on the display tab")
enable("chatAliases", false)
enable("tooltipAliases", false)
enable("liveFeed", false)
mock.Advance(0.1)
ns:SetOption("categories", "aliases", false)
mock.Advance(0.1)
mock.Click(window.resetButton)
mock.Advance(0.1)
check(ns:GetOption("tooltipAliases", "enabled") == false, "the first click on reset changes nothing")
check(window.resetButton.label:GetText() == "Really reset?", "it asks for confirmation instead")
mock.Advance(4.1)
check(window.resetButton.label:GetText() == "Reset", "the question goes away by itself")
mock.Click(window.resetButton)
mock.Click(tabButton("Names"))
mock.Click(tabButton("Display"))
check(window.resetButton.label:GetText() == "Reset", "and when the tab is left")
mock.Click(window.resetButton)
mock.Click(window.resetButton)
mock.Advance(4.1)
check(ns.features.chatAliases.enabled and ns.features.tooltipAliases.enabled, "the second click puts the tab back to defaults")
check(window.resetButton.disabled and window.resetButton.label:GetText() == "Reset", "after which reset is greyed out")
check(ns:IsCategoryEnabled("aliases"), "including the category's master switch")
check(ns:GetOption("liveFeed", "enabled") == false, "other pages are left alone")
enable("liveFeed")

-- Aliases page: the list first, where aliases show on the second tab.
mock.Click(navButton("Aliases"))
mock.Click(tabButton("Names"))
check(window.title:GetText() == "Aliases" and tabButton("Names").selected and tabButton("Display"), "the aliases page has its own tabs")
check(window.master:IsShown() and not window.resetButton:IsShown(), "the list tab has the master switch, but no reset: aliases are data")
local aliasRows = visibleRows()
check(#aliasRows == 2, "the list tab shows the input row and an empty hint (got " .. #aliasRows .. ")")
local editor = aliasRows[1].editor
check(editor ~= nil and editor:IsVisible() and aliasRows[2].item.kind == "info", "the input row comes before the hint")
check(editor.name.placeholder:GetText() == "Character name" and editor.save.label:GetText() == "Save", "the input row is labelled")
check(navButton("Aliases").count:GetText() == "4/4", "the sidebar counts the alias features")
mock.Click(tabButton("Display"))
check(#visibleRows() == 6 and window.resetButton:IsShown(), "the display tab shows the four features with their options, and reset")
mock.Click(window.master)
mock.Advance(0.1)
check(navButton("Aliases").count:GetText() == "OFF" and navButton("Aliases").label:GetAlpha() < 1, "a switched-off area reads OFF in the sidebar")
mock.Click(window.master)
mock.Advance(0.1)
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
check(window.search.edit:GetText() == "" and window.title:GetText() == "Aliases" and tabButton("Names").selected and editor.alias.edit:GetText() == "Annie",
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
-- From the context menu: the window opens on the list with the name filled in.
mock.Click(tabButton("Display"))
mock.Click(navButton("Chronicle"))
SlashCmdList.FAMULUS("")
check(not window:IsShown(), "window closed for the menu test")
mock.OpenMenu("MENU_UNIT_PLAYER", { name = "Varian", surname = "Wrynn" })[2].click()
mock.Advance(0.3)
check(window:IsShown() and window.title:GetText() == "Aliases" and tabButton("Names").selected, "\"Set alias\" in a context menu opens the alias list")
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
check(#generalRows == 4, "language, chat feedback, minimap button and character profile (got " .. #generalRows .. ")")
mock.Click(generalRows[1]) -- language
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
mock.Click(generalRows[4])
mock.Advance(0.1)
check(ns:UsesCharacterProfile() and not ns.features.tooltipAliases.enabled, "character profile starts as a copy")
enable("tooltipAliases")
mock.Click(generalRows[4])
mock.Advance(0.1)
check(not ns:UsesCharacterProfile() and not ns.features.tooltipAliases.enabled, "switching back restores the account settings")
enable("tooltipAliases")

-- Settings: appearance tab.
mock.Click(tabButton("Appearance"))
local looks = visibleRows()
check(#looks == 3 and looks[1].swatches:IsShown() and looks[2].toggle:IsShown() and looks[3].dropdown:IsShown(),
    "colour scheme, sparks and window size")
check(window.themeButton == nil and ns.UI.colors.card[1] < 0.3, "the window is dark and has no light version")
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
    for _, frame in ipairs({ window, navButton("Settings").parent }) do
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
check(lastChat():find("5 of 8", 1, true) ~= nil, "/fam status reports: " .. lastChat())

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
    check(ns.features.liveFeed.enabled and ns:GetOption("liveFeed", "zone") == false and ns:GetOption("liveFeed", "level") == true,
        "the feed is on from the start; arrivals in a zone are not shown")
    -- (Two events of a kind within a second count as one; hence the times.)
    Chronicle.Add("level", { level = 14, t = time() - 19, probe = true })
    check(#Feed.Shown() == 0, "the player's own level-up is not shown: the game announces it itself")
    Chronicle.Add("ability", { ability = "riding", level = 14, t = time() - 20, probe = true })
    local card = Feed.Shown()[1]
    check(#Feed.Shown() == 1 and card:IsShown() and card.title:GetText() == "Learned to ride"
        and card.photo:IsShown() and not card.icon:IsShown() and not card.number:IsShown(),
        "an event of the player's own appears as a card with an icon of the game")
    check(card.crest:GetHeight() < card:GetHeight() and card.crest:GetWidth() < card:GetWidth()
        and card:GetWidth() >= 230 and card.mark:IsShown() and card.grain ~= nil,
        "the picture is a crest inside its band; a milestone carries the mark of an active card")
    Chronicle.Add("zone", { zone = "Nowhere", t = time() - 21, probe = true })
    Chronicle.Add("death", { zone = "Nowhere", who = "Jaina Proudmoore", t = time() - 3600, probe = true })
    check(#Feed.Shown() == 1, "a kind that is switched off and old news stay off screen")
    ns:SetOption("liveFeed", "companions", false)
    Chronicle.Add("boss", { name = "Hogger", who = "Jaina Proudmoore", t = time() - 22, probe = true })
    check(#Feed.Shown() == 1, "without companions, only the player's own events appear")
    ns:SetOption("liveFeed", "companions", true)
    Chronicle.Add("item", { item = 211527, name = "Cozy Sleeping Bag", who = "Jaina Proudmoore", probe = true })
    check(#Feed.Shown() == 2 and Feed.Shown()[1].title:GetText() == "Jaina Proudmoore receives: Cozy Sleeping Bag"
        and Feed.Shown()[1].photo:IsShown(), "a companion's event appears above the older card")
    check(Feed.Shown()[1]:GetWidth() > Feed.Shown()[2]:GetWidth() and not Feed.Shown()[1].mark:IsShown(),
        "a band is as wide as its text needs; a companion's event is no milestone")
    for skill = 1, 3 do
        Chronicle.Add("skill", { skill = skill, name = "Craft " .. skill, rank = 75, probe = true })
    end
    check(#Feed.Shown() == 3 and Feed.Shown()[3].title:GetText() == "Craft 1 raised to 75", "at most three cards; the oldest makes room")
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
    SlashCmdList.FAMULUS("chronicle demo clear")
    check(#Chronicle.Entries() == count, "/fam chronicle demo clear removes them and nothing else")
end
enable("ownJourney", false)
mock.Fire("PLAYER_LEVEL_UP", 14)
check(#Chronicle.Entries() == 5 and ns:CountRegisteredEvents() == eventsBeforeChronicle, "switched off, it hears nothing")

-- Companions: level-ups seen on the friends list.
local friend = { name = "Jaina Proudmoore", level = 19, area = "Duskwood", guid = "Player-1-FRIEND", connected = true }
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
friend.connected, friend.level = false, 0
mock.Fire("FRIENDLIST_UPDATE")
check(#Chronicle.Entries() == 6 and Chronicle.FriendLevel("Player-1-FRIEND") == 20, "a friend going offline changes nothing")
ns.AliasService.Set("Jaina Proudmoore", "Anna")
check(Chronicle.Text(friendEntry) == "Anna reaches level 20" and select(2, Chronicle.Text(friendEntry)) == "Jaina Proudmoore  ·  in Duskwood",
    "a companion appears under the alias, the character name beside it")
ns.AliasService.Set("Jaina Proudmoore", nil)
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
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~S~20~60=12;107=3456;bad=1", "WHISPER", "Jaina Proudmoore")
local profile = Chronicle.Profile("Jaina Proudmoore")
check(profile and profile.level == 20 and profile.stats[60] == 12 and profile.stats[107] == 3456, "their statistics become a profile")

-- Own milestones go out to linked friends; a greeting is answered.
mock.sent = {}
mock.Fire("PLAYER_LEVEL_UP", 14)
mock.Advance(1)
check(#mock.sent == 1 and mock.sent[1].text:find("^1~E~%d+~level~level=14;zone=Westfall$") ~= nil, "an own milestone is sent to linked friends: " .. tostring(mock.sent[1] and mock.sent[1].text))
mock.sent = {}
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~H~0", "WHISPER", "Jaina Proudmoore")
mock.Advance(2)
check(#mock.sent == 2 and mock.sent[1].text:find("~level~", 1, true) and mock.sent[2].text == "1~S~13~107=3456;60=12;932=7;98=210",
    "a greeting is answered with what they missed and the own statistics: " .. tostring(mock.sent[2] and mock.sent[2].text))
mock.sent = {}
setState({ friends = { jaina }, zone = "Westfall", level = 13, lockdown = true })
mock.Fire("PLAYER_DEAD")
mock.Advance(2)
check(#mock.sent == 0, "during a boss fight nothing is sent")
setState({ friends = { jaina }, zone = "Westfall", level = 13 })
mock.Advance(1)
check(#mock.sent == 1 and mock.sent[1].text:find("~death~", 1, true) ~= nil, "it goes out afterwards")
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
check(window.title:GetText() == "Chronicle" and tabButton("Everyone") and tabButton("My journey") and tabButton("Companions") and tabButton("Recording"),
    "the chronicle has its own page: everyone, my journey, companions, recording")
check(navButton("Chronicle").count:GetText() == "1/4", "the sidebar counts its four switches; the feed is on")
-- The entries are told as a picture book: chapters, and events on a line.
local function bookFrames(field)
    local list = {}
    for _, frame in ipairs(mock.frames) do
        if frame[field] and frame:IsVisible() then
            list[#list + 1] = frame
        end
    end
    return list
end
local events, heads = bookFrames("story"), bookFrames("chapter")
check(#visibleRows() == 0 and #events == 6 and events[1].story.title == "Reached level 20"
    and events[1].story.fullTitle == "Jaina Proudmoore reaches level 20",
    "everyone: all entries as events of a book, newest first (got " .. #events .. ")")
check(#heads == 1 and heads[1].chapter.title == "Westfall" and heads[1].chapter.small == "Today"
    and heads[1].chapter.sub:find("6 events", 1, true) ~= nil and heads[1].title:GetText() == "Westfall",
    "a day is a chapter, named after the place most of it happened in: " .. tostring(heads[1] and heads[1].chapter.sub))
check(events[1].onLeft and not events[2].onLeft and events[3].onLeft, "the cards alternate left and right of the line")
check(events[2].top > events[1].top and events[2].top < events[1].top + events[1].cardHeight
    and events[3].top >= events[1].top + events[1].cardHeight
    and events[2].top + events[2].cardHeight / 2 >= events[1].top + events[1].cardHeight / 2 + 30,
    "each side runs on by itself: a card reaches into the height of the one across, the dots keep apart")
check(events[1].story.chip and events[1].story.chip.text == "Jaina Proudmoore" and events[1].story.chip.initial == "J"
    and events[1].chipText:IsShown() and not events[2].chipText:IsShown(), "a companion's event names them in the strip below, not in the headline")
check(events[1].number:IsShown() and events[1].number:GetText() == "20" and not events[1].icon:IsShown()
    and events[1].photo:IsShown() and events[1].dim:IsShown() and events[1].story.texture == ns.UI.gameIcons.level
    and not events[1].story.big and not events[1].bar:IsShown() and events[1].foot:IsShown() and not events[2].foot:IsShown(),
    "a level shows its number on an icon of the game; a companion's is no milestone")
check(events[6].story.big and events[6].bar:IsShown() and events[6].number:GetText() == "13"
    and events[6].card:GetHeight() > events[5].card:GetHeight() and events[6].picture:GetWidth() == events[5].picture:GetWidth(),
    "the player's own level-up is a milestone: a larger card with the mark of an active card, its picture as large as any")
check(events[4].story.kind == "death" and events[4].photo:IsShown() and not events[4].icon:IsShown() and not events[4].number:IsShown()
    and events[4].story.texture == ns.UI.gameIcons.death and events[4].detail:GetText():match("%d%d:%d%d$") ~= nil,
    "other events show an icon of the game and their time")
check(window.scroll.content:GetHeight() >= window.book:GetHeight() and window.book:GetHeight() > 6 * 40,
    "the page is as long as its book")
mock.Click(tabButton("My journey"))
mock.Advance(0.1)
events = bookFrames("story")
check(#events == 5 and events[1].story.title == "Challenge completed: Challenge 501" and events[1].story.chip == nil,
    "my journey: only my own")
mock.Click(tabButton("Companions"))
mock.Advance(0.1)
check(#bookFrames("story") == 1 and #visibleRows() == 0, "companions: only theirs")
do -- an item is shown with the game's icon of it, in its own colours
    Chronicle.Add("item", { item = 211527, name = "Cozy Sleeping Bag", who = "Jaina Proudmoore" })
    local function itemEvent()
        mock.Click(tabButton("My journey"))
        mock.Advance(0.1)
        mock.Click(tabButton("Companions"))
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
    mock.Click(tabButton("Companions"))
    mock.Advance(0.1)
    check(#bookFrames("story") == 1 and bookFrames("story")[1].story.texture == ns.UI.gameIcons.level
        and bookFrames("story")[1].story.item == nil, "a frame used again shows the picture of its new event")
end
mock.Click(tabButton("Recording"))
mock.Advance(0.1)
check(#visibleRows() == 15 and visibleRows()[1].toggle ~= nil and window.master:IsShown() and #bookFrames("story") == 0,
    "recording: the four switches, the feed's eleven options and the master switch; no book (got " .. #visibleRows() .. ")")
Chronicle.Clear()
mock.Advance(0.1)
mock.Click(tabButton("Everyone"))
mock.Advance(0.1)
check(#visibleRows() == 1 and visibleRows()[1].label:GetText() == "Nothing recorded yet" and #bookFrames("story") == 0,
    "an empty chronicle says how to begin")
mock.Click(navButton("Aliases"))
SlashCmdList.FAMULUS("")

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
check(result.idle.events == eventsBefore and ns:CountRegisteredEvents() == eventsBefore, "the test registers no events")
check(#mock.frames - framesBeforeTest == 1, "the test creates one hidden probe frame")
SlashCmdList.FAMULUS("test")
check(#mock.frames - framesBeforeTest == 1, "and reuses it on the next run")

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
