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
do
-- The keys ns.Plural picks by a number, from the source: only they may have
-- forms of their own (<key>_one, <key>_few), in any language.
local pluralKeys = {}
for _, file in ipairs(files) do
    local handle = io.open("Famulus/" .. file:gsub("\\", "/"), "r")
    if handle then
        for key in handle:read("*a"):gmatch('Plural%("([%w_]+)"') do
            pluralKeys[key] = true
        end
        handle:close()
    end
end
check(pluralKeys.c_ch_events and pluralKeys.ui_fellow_bosses, "the keys ns.Plural picks are found in the source")
for key in pairs(pluralKeys) do
    check(en[key] ~= nil, "a key ns.Plural picks exists in enUS: " .. key)
end
local function pluralBase(key)
    local base = key:match("^(.+)_one$") or key:match("^(.+)_few$")
    return base and pluralKeys[base] and base or nil
end
local codes = ns:GetLocaleCodes(true)
check(#codes == 7 and codes[1] == "enUS", "seven languages ship, English first: " .. table.concat(codes, " "))
check(table.concat(ns:GetLocaleCodes(), " ") == "enUS deDE esES frFR itIT" and not ns:IsLocaleOffered("plPL")
    and not ns:IsLocaleOffered("ukUA") and ns:IsLocaleOffered("deDE"), "Polish and Ukrainian ship but are not offered yet")
for _, code in ipairs(codes) do
    local strings = ns.locales[code]
    check(type(strings.lang_name) == "string" and strings.lang_name ~= "" and (code == "enUS" or strings.lang_name ~= en.lang_name),
        code .. " names itself")
    for key, text in pairs(en) do
        if not pluralBase(key) then
            check(strings[key] ~= nil, code .. " has key " .. key)
        end
    end
    for key, text in pairs(strings) do
        local base = pluralBase(key)
        local reference = en[base or key]
        check(reference ~= nil, code .. " key also exists in enUS (or is a form of a key ns.Plural picks): " .. key)
        if reference then
            check(placeholders(text) == placeholders(reference), "same placeholders in " .. code .. " " .. key)
        end
    end
end

-- Every letter of every language is in the fonts the addon ships: a font
-- without it would show an empty box. Reads the fonts' character maps.
local function fontLetters(path)
    local handle = io.open(path, "rb")
    if not handle then
        return nil
    end
    local data = handle:read("*a")
    handle:close()
    local function u16(at)
        local a, b = data:byte(at + 1, at + 2)
        return a * 256 + b
    end
    local function u32(at)
        return u16(at) * 65536 + u16(at + 2)
    end
    local cmap
    for index = 0, u16(4) - 1 do
        local record = 12 + index * 16
        if data:sub(record + 1, record + 4) == "cmap" then
            cmap = u32(record + 8)
        end
    end
    if not cmap then
        return nil
    end
    for index = 0, u16(cmap + 2) - 1 do
        local record = cmap + 4 + index * 8
        local platform, encoding = u16(record), u16(record + 2)
        local sub = cmap + u32(record + 4)
        if (platform == 3 and encoding == 1 or platform == 0) and u16(sub) == 4 then
            local segments = u16(sub + 6) / 2
            local ends, starts = sub + 14, sub + 16 + segments * 2
            local deltas, offsets = starts + segments * 2, starts + segments * 4
            return function(letter)
                for segment = 0, segments - 1 do
                    if letter <= u16(ends + segment * 2) then
                        local first = u16(starts + segment * 2)
                        if letter < first then
                            return false
                        end
                        local delta, offset = u16(deltas + segment * 2), u16(offsets + segment * 2)
                        if offset == 0 then
                            return (letter + delta) % 65536 ~= 0
                        end
                        local glyph = u16(offsets + segment * 2 + offset + (letter - first) * 2)
                        return glyph ~= 0
                    end
                end
                return false
            end
        end
    end
    return nil
end
local function letters(text)
    local list = {}
    for char in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        local first = char:byte(1)
        local value = #char == 1 and first or first % (2 ^ (7 - #char))
        for index = 2, #char do
            value = value * 64 + char:byte(index) % 64
        end
        list[#list + 1] = value
    end
    return list
end
for _, weight in ipairs({ "Regular", "Medium", "SemiBold" }) do
    local has = fontLetters("Famulus/Media/Fonts/Inter-" .. weight .. ".ttf")
    check(has ~= nil and has(65) and has(0x416) and not has(0x4E00), "the character map of Inter " .. weight .. " can be read")
    if has then
        local missing = {}
        for _, code in ipairs(codes) do
            for key, text in pairs(ns.locales[code]) do
                for _, letter in ipairs(letters(text)) do
                    if letter >= 32 and not has(letter) then
                        missing[#missing + 1] = string.format("U+%04X in %s %s", letter, code, key)
                    end
                end
            end
        end
        table.sort(missing)
        check(#missing == 0, "Inter " .. weight .. " has every letter of every language: " .. table.concat(missing, ", ", 1, math.min(#missing, 5)))
    end
end

-- Plural forms: each language's rule picks <key>_one, <key>_few or <key>.
do
    local cases = {
        enUS = { [0] = "", [1] = "one", [2] = "", [21] = "" },
        deDE = { [0] = "", [1] = "one", [2] = "" },
        frFR = { [0] = "one", [1] = "one", [2] = "", [21] = "" },
        plPL = { [0] = "", [1] = "one", [2] = "few", [4] = "few", [5] = "", [12] = "", [14] = "", [21] = "", [22] = "few", [112] = "" },
        ukUA = { [0] = "", [1] = "one", [2] = "few", [5] = "", [11] = "", [12] = "", [21] = "one", [22] = "few", [101] = "one", [111] = "" },
    }
    for code, numbers in pairs(cases) do
        for n, form in pairs(numbers) do
            check((ns.PluralForm(n, code) or "") == form, code .. ": " .. n .. " takes the form \"" .. form .. "\"")
        end
    end
    -- ns.Plural picks the key of that form in the language spoken.
    local french = ns.locales.frFR
    french.test_count, french.test_count_one = "other", "one"
    ns:SetLocale("frFR")
    check(ns.Plural("test_count", 0) == "one" and ns.Plural("test_count", 2) == "other", "French: 0 is one, 2 is other")
    french.test_count, french.test_count_one = nil, nil
    check(ns.Plural("ui_fellow_bosses", 3) == french.ui_fellow_bosses, "a language without a form of its own for a number uses the key")
    check(ns.Plural("no_such_key", 3) == "no_such_key", "an unknown key comes back as it is")
    ns:SetLocale("esMX")
    check(ns:GetLocaleCode() == "esES", "a Mexican Spanish client speaks Spanish")
    ns:SetLocale("ukUA")
    check(ns:GetLocaleCode() == "enUS", "a language not offered yet speaks the client's")
    ns:SetLocale("auto")
end

-- Upper and lower case beyond A-Z.
check(ns.Upper("tage äöü ß łódź żółć élan œuvre їжак ґанок є") == "TAGE ÄÖÜ ß ŁÓDŹ ŻÓŁĆ ÉLAN ŒUVRE ЇЖАК ҐАНОК Є",
    "upper case of German, Polish, French and Ukrainian letters")
check(ns.Lower("ÄÖÜ ŁÓDŹ ŻÓŁĆ ÉLAN ŒUVRE ЇЖАК ҐАНОК Є ABC") == "äöü łódź żółć élan œuvre їжак ґанок є abc", "and lower case")
check(ns.Capital("вчора") == "Вчора" and ns.Capital("élan") == "Élan" and ns.Capital("abc") == "Abc" and ns.Capital("") == "",
    "the first letter in upper case")
end
for _, category in ipairs(ns.categories) do
    check(en["cat_" .. category], "category string for " .. category)
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
-- feature and publishes exactly the table ns.<Name>Service. Files under
-- Modules/<Category>/Data/ are data of that category's service: no feature, no
-- service of their own, and nothing but tables on it.
for _, file in ipairs(files) do
    local source = readFile("Famulus/" .. file)
    local _, declared = source:gsub("ns:NewFeature%(", "")
    local service = file:match("([%w]+Service)%.lua$")
    if service then
        check(declared == 0, "service declares no feature: " .. file)
        check(type(ns[service]) == "table", "service publishes ns." .. service)
    elseif file:match("^Modules/%u%a*/Data/") then
        check(declared == 0 and not source:find("function%s*[%w_.:]*%s*%("), "a data file holds tables only: " .. file)
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

-- Data version: a new file starts at the current version, an old one runs every step in order.
check(ns.DATA_VERSION == #ns.MIGRATIONS and ns.DATA_VERSION >= 1, "the data version is the number of migration steps")
check(FamulusDB.dataVersion == ns.DATA_VERSION and FamulusCharDB.dataVersion == ns.DATA_VERSION,
    "a new install starts both saved files at the current data version")
for step, migration in ipairs(ns.MIGRATIONS) do
    local parts = 0
    for part, migrate in pairs(migration) do
        parts = parts + 1
        check((part == "account" or part == "character") and type(migrate) == "function",
            "migration step " .. step .. " has only an account and a character part (" .. tostring(part) .. ")")
    end
    check(parts > 0, "migration step " .. step .. " does something")
end
do
    local fresh = ns.MigrateSaved(nil, "account")
    local keys = 0
    for _ in pairs(fresh) do
        keys = keys + 1
    end
    check(fresh.dataVersion == ns.DATA_VERSION and keys == 1, "a new file skips every step and holds only its version")

    local old = { profile = { general = { accent = "ember" } }, journal = { "vendor" }, seen = true }
    check(ns.MigrateSaved(old, "account") == old, "an old file is migrated in place")
    check(old.dataVersion == ns.DATA_VERSION, "an old file without a version runs up to the current one")
    check(old.journal == nil, "step 1 drops the removed journal")
    check(old.profile.general.accent == "ember" and old.seen == true, "migrating keeps the player's settings")

    local newer = { dataVersion = ns.DATA_VERSION + 1, journal = { "kept" } }
    ns.MigrateSaved(newer, "account")
    check(newer.dataVersion == ns.DATA_VERSION + 1 and newer.journal ~= nil,
        "a file from a newer Famulus is left as it is")

    local character = { zones = { "Elwynn Forest" }, useCharacter = false }
    ns.MigrateSaved(character, "character")
    check(character.dataVersion == ns.DATA_VERSION and character.zones[1] == "Elwynn Forest",
        "a character's file carries its own version and keeps its journey")

    -- Step 2: the keys of names and BattleTags, in lower case beyond A-Z as well.
    local named = {
        dataVersion = 1,
        aliases = {
            ["Émile-dupont"] = { name = "Émile Dupont", alias = "Emil" },
            ["jaina-proudmoore"] = { name = "Jaina Proudmoore", alias = "Anna" },
            ["Örn-berg"] = { name = "Örn Berg", alias = "old" },
            ["örn-berg"] = { name = "Örn Berg", alias = "new" },
        },
        accountAliases = { ["Élise#1234"] = { tag = "Élise#1234", alias = "Lise", chars = { ["Östen-berg"] = "Östen Berg" } } },
        chronicle = { links = { ["Émile-dupont"] = { name = "Émile Dupont", t = 1 } } },
    }
    ns.MigrateSaved(named, "account")
    check(named.dataVersion == ns.DATA_VERSION and named.aliases["Émile-dupont"] == nil
        and named.aliases["émile-dupont"].alias == "Emil" and named.aliases["jaina-proudmoore"].alias == "Anna",
        "step 2 writes the keys of aliases in lower case beyond A-Z")
    check(named.aliases["örn-berg"].alias == "new" and named.aliases["Örn-berg"] == nil,
        "of two keys that become the same, the one in lower case stays")
    check(named.accountAliases["Élise#1234"] == nil and named.accountAliases["élise#1234"].alias == "Lise"
        and named.accountAliases["élise#1234"].chars["östen-berg"] == "Östen Berg"
        and named.chronicle.links["émile-dupont"].t == 1 and named.chronicle.links["Émile-dupont"] == nil,
        "and those of BattleTags, their characters and the chronicle's links")
    ns.MigrateSaved({ dataVersion = 1, aliases = "broken", accountAliases = { x = 1 }, chronicle = 5 }, "account")
end
mock.Fire("PLAYER_LOGIN")

do
    local active, total = ns:CountActiveFeatures()
    check(total == 11, "11 features registered (got " .. total .. ")")
    check(active == 7, "7 features on by default (got " .. active .. ")")
end
for _, feature in ipairs(ns.featureList) do
    -- The journey is the core and stays with the player; the rest that listens or sends waits for a choice.
    local onByDefault = feature.id == "ownJourney" or feature.id == "liveFeed" or feature.category == "aliases"
    check(feature.enabled == onByDefault, "only the journey and the harmless features are on by default: " .. feature.id)
end
-- With the defaults only the journey listens to the game.
local journeyEvents = 0
for _ in pairs(ns.features.ownJourney.events) do
    journeyEvents = journeyEvents + 1
end
check(journeyEvents > 0 and ns:CountRegisteredEvents() == journeyEvents,
    "after login only the journey listens to the game (got " .. ns:CountRegisteredEvents() .. ")")
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
check(mock.SystemMessage("Jaina Proudmoore has gone offline.") == "Jaina Proudmoore has gone offline.",
    "and the notice that they went offline stays as it is")

check(Aliases.Set("Jaina Proudmoore", "  Anna ") and Aliases.Count() == 1 and aliasEvents == 1, "an alias can be set and is announced")
check(FamulusDB.aliases["jaina-proudmoore"].alias == "Anna" and FamulusDB.profile.aliases == nil,
    "it is saved account-wide, outside the profile, without surrounding blanks")
check(not Aliases.Set("Jaina Proudmoore", "Anna") and aliasEvents == 1, "setting the same alias again changes nothing")
check(Aliases.Get("Jaina", "Proudmoore") == "Anna", "found by first name and surname")
check(Aliases.Get("Jaina-Proudmoore") == "Anna" and Aliases.Get("jaina proudmoore") == "Anna", "and by the full name in any spelling")
check(Aliases.Get("Jaina") == nil and Aliases.Get(nil) == nil and Aliases.Get("") == nil, "other names have none")
check(Aliases.Key("émile dupont") == Aliases.Key("Émile", "Dupont") and ns.SocialService.Key("ÉMILE-Dupont") == "émile-dupont",
    "a name's key is in lower case beyond A-Z as well, so one typed by hand matches whatever its capitals are")
-- What several places share: a full name, a short one, a list of names, the zone.
check(ns.SocialService.FullName("Jaina", "Proudmoore") == "Jaina Proudmoore" and ns.SocialService.FullName("Jaina") == "Jaina"
    and ns.SocialService.FullName(mock.SECRET, "Proudmoore") == nil and Aliases.FullName == ns.SocialService.FullName,
    "first name and surname are one name; a secret one is none")
check(Aliases.Short("Jaina Proudmoore") == "Anna" and Aliases.Short("Mira Sturmfeder") == "Mira"
    and Aliases.Short("Mira-Sturmfeder") == "Mira" and Aliases.Short("Mira") == "Mira",
    "where room is short a person is their alias, else their first name, however the full name is written")
check(ns.NameList({}) == "" and ns.NameList({ "A" }) == "A" and ns.NameList({ "A", "B" }) == "A and B"
    and ns.NameList({ "A", "B", "C" }) == "A, B and C"
    and ns.NameList({ "A", "B", "C", "D" }, 3, function(more)
        return more .. " more"
    end) == "A, B and 2 more",
    "names are listed as a sentence does, the rest counted beyond the most it shows")
check(ns.Zone() == GetRealZoneText() and ns.SocialService.ClassFile("MAGE") == "MAGE" and ns.SocialService.ClassFile("Mage") == nil,
    "the zone as the game names it, and a class only as the game names it in code")

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

-- The notices that someone came online or went offline
local online = string.format(ERR_FRIEND_ONLINE_SS, "Jaina-Proudmoore", "Jaina-Proudmoore")
local shown, argCount = mock.SystemMessage(online)
check(mock.CountMessageFilters("CHAT_MSG_SYSTEM") == 1, "a filter for system lines is installed while the feature is on")
check(shown == "|Hplayer:Jaina-Proudmoore|h[Anna]|h has come online." and argCount == 14,
    "the online notice shows the alias, the link keeps the name: " .. tostring(shown))
check(mock.SystemMessage(string.format(ERR_FRIEND_ONLINE_SS, "Jaina Proudmoore", "Jaina Proudmoore"))
    == "|Hplayer:Jaina Proudmoore|h[Anna]|h has come online.", "also with a space in the name")
check(mock.SystemMessage("|Hplayer:Jaina-Proudmoore:12:GUILD|h[|cff3fc7ebJaina-Proudmoore|r]|h has come online.")
    == "|Hplayer:Jaina-Proudmoore:12:GUILD|h[|cff3fc7ebAnna|r]|h has come online.", "inside a class colour and with more link data")
check(mock.SystemMessage("Jaina Proudmoore has gone offline.") == "Anna has gone offline.", "the offline notice shows the alias")
ns:SetOption("chatAliases", "style", "both")
check(mock.SystemMessage(online) == "|Hplayer:Jaina-Proudmoore|h[Anna (Jaina-Proudmoore)]|h has come online."
    and mock.SystemMessage("Jaina Proudmoore has gone offline.") == "Anna (Jaina Proudmoore) has gone offline.",
    "both notices follow the display setting")
ns:SetOption("chatAliases", "style", "alias")
local strangerOnline = string.format(ERR_FRIEND_ONLINE_SS, "Arthas-Menethil", "Arthas-Menethil")
check(mock.SystemMessage(strangerOnline) == strangerOnline and mock.SystemMessage("Arthas Menethil has gone offline.") == "Arthas Menethil has gone offline."
    and mock.SystemMessage("You are now away.") == "You are now away.", "other names and other system lines are untouched")
check(mock.SystemMessage(online, { privateMessageList = { ["jaina-proudmoore"] = true } }) == online,
    "a whisper window of its own gets the line unchanged, so it still recognises it")
check(mock.SystemMessage(mock.SECRET) == mock.SECRET, "a secret line is passed through untouched")
local englishOffline = ERR_FRIEND_OFFLINE_S
ERR_FRIEND_OFFLINE_S = "%s ist jetzt offline."
check(mock.SystemMessage("Jaina Proudmoore ist jetzt offline.") == "Anna ist jetzt offline.", "the offline notice is found in the client's language")
ERR_FRIEND_OFFLINE_S = englishOffline
enable("chatAliases", false)
check(mock.CountMessageFilters("CHAT_MSG_SYSTEM") == 0 and mock.SystemMessage(online) == online, "switching off removes the filter for system lines")
enable("chatAliases")

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
check(accountAliases.enabled and ns:CountRegisteredEvents() == journeyEvents, "without an alias for an account the friends list is not watched")
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
check(ns:CountRegisteredEvents() == journeyEvents + #accountAliases.EVENTS, "from now on the friends list is watched")
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
check(ns:CountRegisteredEvents() == journeyEvents and Aliases.Get("Tyrande") == "Anna", "switched off, the friends list is left alone and known characters keep the alias")
enable("accountAliases")
check(ns:CountRegisteredEvents() == journeyEvents + #accountAliases.EVENTS, "switched on, it is watched again")
FamulusDB.accountAliases.broken = "x"
FamulusDB.accountAliases["x#1"] = { tag = "Y#2", alias = "a", chars = {} }
ns:Fire("DATABASE_READY")
check(Aliases.AccountCount() == 1 and Aliases.Count() == 2 and Aliases.Get("Tyrande") == "Anna" and FamulusDB.accountAliases.broken == nil
    and FamulusDB.accountAliases["x#1"] == nil, "saved accounts and their characters are read, broken entries are dropped")
Aliases.Set("Anna#1234", nil)
check(Aliases.Get("Tyrande") == nil and FamulusDB.accountAliases == nil and ns:CountRegisteredEvents() == journeyEvents,
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
check(ns:CountRegisteredEvents() == journeyEvents and mock.ActiveTimers() == 0, "the alias features need no game event and no timer")
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

-- The welcome page (UI/Welcome.lua), once it has been built.
local function welcomePage()
    for _, frame in ipairs(mock.frames) do
        if frame.setup and frame.step and frame.done then
            return frame
        end
    end
end

-- With the defaults the window opens on the welcome page, over sidebar and
-- content, until the player chooses.
do
    local page = welcomePage()
    check(page ~= nil and page:IsShown() and not window.area:IsShown() and page.start:IsShown() and not page.step:IsShown()
        and page.title:GetText() == "For everyone you play with." and page.eyebrow:GetText() == "WELCOME TO FAMULUS",
        "with the defaults the window opens on the welcome page, in the website's words; the head keeps only logo, name and close")
    local lit = {}
    for index, tile in ipairs(page.tiles) do
        lit[index] = tile.pill:IsShown()
    end
    check(#page.tiles == 4 and lit[1] and not lit[2] and lit[3] and lit[4],
        "four tiles as on the website; the journey, the live feed and the aliases run already")
    check(page.setup.label:GetText() == "Set up now" and page.all.label:GetText() == "Switch everything on"
        and page.note:GetText():find("only to friends and guild", 1, true) ~= nil,
        "set up step by step or all at once; sharing reaches only friends and guild")
    check(page.embers.playing, "the page's own sparks rise")
    local dots = page.scheme.swatches.dots
    check(page.scheme:IsShown() and page.scheme.label:GetText() == "Colour scheme" and #dots == #ns.UI.accents
        and dots[1].selected, "the colour scheme can be chosen on the page, the default marked")
    mock.Click(dots[2])
    mock.Advance(0.1)
    check(ns:GetOption("general", "accent") == ns.UI.accents[2] and page.scheme.swatches.dots[2].selected
        and not page.scheme.swatches.dots[1].selected and page.start:IsShown(), "a click changes it at once; the page stays")
    ns:SetOption("general", "accent", ns.UI.accents[1])
    mock.Advance(0.1)
    mock.Click(page.setup)
    check(page.step:IsShown() and not page.start:IsShown() and page.count:GetText() == "Step 1 of 5"
        and page.name:GetText() == ns.L.f_companions and page.tag.text:GetText() == "Only for you"
        and not page.option:IsShown() and page.stage:IsShown() and page.stage.current == "friends"
        and page.skip:IsShown() and page.on.label:GetText() == "Switch on and continue",
        "\"Set up now\" starts with the first step: what it does, an example, switch on or skip")
    SlashCmdList.FAMULUS("")
    check(not window:IsShown() and FamulusDB.welcome == nil and not page.embers.playing, "closing the window is no choice")
    SlashCmdList.FAMULUS("")
    check(page:IsShown() and page.start:IsShown(), "so the next opening shows the page again, from the start")
    mock.Click(page.later)
    local off = true
    for _, id in ipairs(ns.UI.Welcome.FEATURES) do
        off = off and not ns:GetOption(id, "enabled")
    end
    check(FamulusDB.welcome == true and not page:IsShown() and window.area:IsShown() and off and not page.embers.playing,
        "\"Later\" is a choice: the page goes and nothing is switched on")
end

check(ns.areas[1].id == "chronicle" and ns.areas[2].id == "fellows" and ns.areas[3].id == "aliases"
    and ns.categories[1] == "chronicle" and ns.categories[3] == "aliases",
    "the main features in order: chronicle, fellow travellers, aliases last")
check(tabButton("Everyone") and tabButton("Everyone").selected
    and window.area.name:GetText() == "Chronicle" and window.area.desc:GetText() == ns.L.area_chronicle_desc,
    "the first page is the chronicle: named in the sidebar, the content headed by its first tab")
check(navButton("Chronicle") and navButton("Fellowship") and navButton("Aliases") and navButton("Settings") and navButton("About"),
    "the head lists the main features and the addon's own pages")
mock.Click(navButton("Aliases"))
check(tabButton("Names") and tabButton("Names").selected and window.area.name:GetText() == "Aliases"
    and window.area.desc:GetText() == ns.L.area_aliases_desc, "the aliases page opens on its first tab")
check(not navButton("Quality of Life") and not navButton("Journal"), "and nothing else")
check(window.search:GetParent() == window.sidebar and window.search:IsShown(), "the search sits at the top of the sidebar")
check(navButton("Aliases"):GetParent() == window.sidebar and navButton("Settings"):GetParent() == window.sidebar
    and navButton("About"):GetParent() == window.sidebar, "the main features and the addon's own pages are entries in the sidebar")
check(navButton("Aliases").selected and navButton("Aliases"):GetHeight() > navButton("Settings"):GetHeight()
    and navButton("Aliases").count:GetText() == "0" and not navButton("Aliases").pill:IsShown(),
    "the main feature is a selected card that counts its aliases: " .. tostring(navButton("Aliases").count:GetText()))
mock.Click(tabButton("Settings"))
check(tabButton("Settings").selected and not tabButton("Names").selected, "a click on a tab chooses it")
do
    local gear = tabButton("Settings")
    check(gear.icon:IsShown() and gear.label:IsShown() and gear.label:GetText() == "Settings"
        and gear.mockPoint[1] == "BOTTOMRIGHT"
        and gear:GetWidth() > gear.label:GetStringWidth() + 16
        and not tabButton("Names").icon:IsShown() and tabButton("Names").label:IsShown()
        and tabButton("Names").mockPoint[1] == "BOTTOMLEFT",
        "an area's settings stand as a gear with their name at the right end of the tabs, its views by name at the left")
    check(window.resetButton.mockPoint[2] == gear and window.resetButton.mockPoint[1] == "RIGHT",
        "reset stands to the left of the settings")
    mock.Click(navButton("Chronicle"))
    check(tabButton("Settings") and tabButton("Settings").icon:IsShown(),
        "the chronicle's settings are named Settings as well, not after the area")
    mock.Click(navButton("Aliases"))
    mock.Click(tabButton("Settings"))
end
-- A settings tab: its features as entries on the left, the chosen one in
-- full on the right.
local function visibleEntries()
    local list = {}
    for _, frame in ipairs(mock.frames) do
        if frame.entry and frame.switch and frame:IsVisible() then
            list[#list + 1] = frame
        end
    end
    return list
end
local detail = window.detail
local entries = visibleEntries()
check(#entries == 5 and entries[1].label:GetText() == ns.L.f_chatAliases and entries[1].chosen and not entries[2].chosen,
    "the display tab lists its five features, the first one chosen (got " .. #entries .. ")")
check(not window.scroll:IsShown() and window.list:GetWidth() == 296 and detail:IsVisible() and detail.title:GetText() == ns.L.f_chatAliases
    and detail.desc:GetText() == ns.L.f_chatAliases_desc, "on the right the chosen feature in full: its name and what it does")
check(detail.crumb:GetText() == "Aliases", "above the name the page it belongs to")
check(entries[1].entry.item.icon == "chat" and entries[1].icon:IsShown() and entries[1].tile.token == "accentSoft"
    and entries[5].entry.item.icon == "shield", "every entry has its feature's icon, on a lit tile while it runs")
local iconsKnown = true
for _, feature in ipairs(ns.featureList) do
    iconsKnown = iconsKnown and feature.icon ~= nil and ns.UI.media[feature.icon] ~= nil
end
check(iconsKnown, "every feature names an icon the window has")
check(entries[1].mark:IsShown() and not entries[2].mark:IsShown() and entries[1].ground.fill.parts[1]:IsShown(),
    "the chosen entry lies on a card with the accent mark")
check(entries[1].sub:GetText() == "On  ·  1 option" and entries[3].sub:GetText() == "On" and entries[1].toggle.on,
    "below each name whether it is on and how many options it has; its switch at the right")
check(detail.pills[1].text:GetText() == "On" and detail.pills[2].text:GetText() == "Default: on" and detail.toggle.on,
    "the detail says whether it is on and what its default is")
local rows = visibleRows()
check(#rows == 1 and rows[1].item.id == "chatAliases.style" and rows[1].dropdown:IsShown() and rows[1].desc:IsShown()
    and detail.optionsTitle:GetText() == "Options" and not detail.chipsTitle:IsShown(),
    "its option is a row with its help text below \"Options\"; no chips (got " .. #rows .. ")")
-- Its picture: a few lines of chat, drawn live, one friend there under an alias.
local previewsKnown = true
for _, feature in ipairs(ns.featureList) do
    previewsKnown = previewsKnown and (feature.preview == nil or ns.UI.Previews.Has(feature.preview))
end
check(previewsKnown, "every feature's picture names a scene the window has")
local chatScene = detail.stage.scenes.chat
local function chatLine(index)
    local line = chatScene.lines[index]
    return line[1]:GetText() .. line[2]:GetText() .. line[3]:GetText(), line.outline:IsShown()
end
check(detail.stage:IsShown() and detail.stage.current == "chat" and chatScene:IsVisible() and detail.crumb.mockPoint[5] < -200,
    "above the name a picture of what it does")
check(chatLine(1) == "[Guild] [Mira Stormfeather]: I'll bring torches." and not select(2, chatLine(1))
    and chatLine(2) == "[Guild] [Dad]: Who's coming to Uldaman?" and select(2, chatLine(2))
    and chatLine(3) == "[Party] [Lysa Morningdew]: I'm in, give me five minutes."
    and chatLine(4) == "Dad has come online." and select(2, chatLine(4)),
    "the chronicle's sample people chat; one of them under an alias, marked, also in the online notice: " .. chatLine(2))
local nameAnchor = chatScene.lines[4][2].mockPoint
check(nameAnchor[1] == "TOPLEFT" and nameAnchor[2] == chatScene.lines[4][1] and nameAnchor[3] == "TOPRIGHT",
    "the parts of a line meet top to top, so a name at its start stays in its line")
local twinkling = 0
for _, group in ipairs(chatScene.animations) do
    twinkling = twinkling + (group:IsPlaying() and 1 or 0)
end
check(twinkling > 0 and twinkling == #chatScene.animations, "behind it a night sky whose stars twinkle while it shows")
ns:SetOption("chatAliases", "style", "both")
mock.Advance(0.1)
check(chatLine(2) == "[Guild] [Dad (Borin Ironbeard)]: Who's coming to Uldaman?" and chatLine(4) == "Dad (Borin Ironbeard) has come online.",
    "the picture follows the option: " .. chatLine(2))
ns:SetOption("chatAliases", "style", "alias")
mock.Advance(0.1)
check(chatLine(2) == "[Guild] [Dad]: Who's coming to Uldaman?", "and back")
ns:SetOption("general", "language", "deDE")
mock.Advance(0.1)
check(chatLine(2) == "[Gilde] [Papa]: Wer kommt mit nach Uldaman?" and chatLine(1) == "[Gilde] [Mira Sturmfeder]: Ich bring Fackeln mit.",
    "and the language: " .. chatLine(2))
ns:SetOption("general", "language", "auto")
mock.Advance(0.1)
check(chatLine(2) == "[Guild] [Dad]: Who's coming to Uldaman?", "and back to English")
check(window.resetButton:IsShown() and window.resetButton.disabled, "reset is greyed out while the tab is on its defaults")
mock.Click(window.resetButton)
check(window.resetButton.label:GetText() == "Reset", "and a click on it does nothing")
check(window.master == nil, "the pages carry no master switch any more")
-- The master switches live in Settings › General; tests flip them directly.
local function flipAliases()
    ns:SetOption("categories", "aliases", not ns:IsCategoryEnabled("aliases"))
end

-- The entry's own switch.
local optionRow = rows[1]
check(not optionRow.disabled and not detail.off:IsShown(), "the option of a running feature can be changed")
mock.Click(entries[1].switch)
check(not ns.features.chatAliases.enabled, "the switch in the entry turns the feature off")
mock.Advance(0.3)
check(entries[1].chosen and detail.title:GetText() == ns.L.f_chatAliases, "without choosing another entry")
check(optionRow:IsVisible() and optionRow.disabled and optionRow.dropdown:IsShown() and optionRow.desc:IsShown(),
    "its option stays in full, greyed out")
check(detail.off:IsShown() and detail.off:GetText() == "Switch on \"Aliases in chat\" to change its options.",
    "and the detail says why: " .. tostring(detail.off:GetText()))
check(entries[1].sub:GetText() == "Off  ·  1 option" and not entries[1].toggle.on and detail.pills[1].text:GetText() == "Off"
    and not detail.toggle.on and entries[1].tile.token == "control", "entry and detail show that it is off")
check(not window.resetButton.disabled, "reset becomes available once something differs from the defaults")
check(chatLine(2) == "[Guild] [Borin Ironbeard]: Who's coming to Uldaman?" and not select(2, chatLine(2))
    and chatLine(4) == "Borin Ironbeard has come online.", "switched off, the picture's chat shows the name: " .. chatLine(2))
check(tostring(ns.AliasService.Count()) == navButton("Aliases").count:GetText(), "the sidebar card counts the aliases: " .. tostring(navButton("Aliases").count:GetText()))
ns:SetOption("chatAliases", "style", "both")
mock.Advance(0.3)
check(optionRow.dropdown.text:GetText() == ns.L.o_chatAliases_style_both, "a chosen value shows while greyed out as well")
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
check(window.offNotice:IsShown() and #visibleRows() == 0 and #visibleEntries() == 0 and not detail:IsVisible()
    and not window.resetButton:IsShown(), "the page shows only the notice")
check(tabButton("Settings").label:GetAlpha() < 1, "the tab of the category is greyed out")
check(FamulusDB.profile.categories.aliases == false, "the switch is saved")
enable("chatAliases")
check(not ns.features.chatAliases.enabled, "a feature cannot be started while its category is off")
enable("chatAliases", false)
check(ns.features.liveFeed.enabled, "other categories keep running")
flipAliases()
mock.Advance(0.3)
check(ns.features.tooltipAliases.enabled and FamulusDB.profile.categories == nil, "switching the category on again resumes the features")
check(tabButton("Settings").label:GetAlpha() == 1 and not window.offNotice:IsShown() and #visibleEntries() == 5 and detail:IsVisible(),
    "and the tab is back to normal")

mock.Click(detail.switch)
check(ns.features.chatAliases.enabled, "the switch beside the feature's name turns it on again")
mock.Advance(0.3)
check(not optionRow.disabled and not detail.off:IsShown() and entries[1].toggle.on, "which frees its option")
check(window.resetButton.disabled, "back on defaults, reset is greyed out again")

-- Choosing another entry.
mock.Click(entries[2])
check(entries[2].chosen and not entries[1].chosen and entries[2].mark:IsShown() and not entries[1].mark:IsShown()
    and detail.title:GetText() == ns.L.f_tooltipAliases and #visibleRows() == 0 and not detail.optionsTitle:IsShown(),
    "a click on an entry shows that feature; one without options shows none")
mock.Click(entries[2].switch)
mock.Advance(0.3)
check(not ns.features.tooltipAliases.enabled and entries[2].sub:GetText() == "Off" and not detail.toggle.on and entries[2].chosen,
    "its switch turns it off and both sides follow")
mock.Click(detail.switch)
mock.Advance(0.3)
check(ns.features.tooltipAliases.enabled and entries[2].toggle.on, "and on again")

-- Tabs.
mock.Click(tabButton("Names"))
check(tabButton("Names").selected, "a click on a tab opens it")
check(#visibleEntries() == 0 and not detail:IsVisible() and window.scroll:IsShown(), "a tab without settings shows cards of rows")
mock.Advance(0.3)
check(mock.CountOnUpdateFrames() == 0, "the sliding tab bar comes to rest")
mock.Click(tabButton("Settings"))
mock.Click(navButton("Settings"))
check(navButton("Settings").bar:IsShown(), "the chosen icon carries the accent stroke")
mock.Click(navButton("Aliases"))
check(tabButton("Settings").selected, "a page remembers its tab")
check(entries[2].chosen and detail.title:GetText() == ns.L.f_tooltipAliases, "and the tab its chosen entry")
mock.Click(entries[1])

-- Every page and tab renders, in every language; German last, for what follows.
for _, language in ipairs({ "enUS", "esES", "frFR", "itIT", "deDE" }) do
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
                check(#visibleRows() > 0 or (#visibleEntries() > 0 and detail.title:GetText() ~= ""),
                    "tab " .. tab.label:GetText() .. " of " .. page .. " has rows or entries")
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
check(navButton("Aliases").count:GetText() ~= "" and not navButton("Aliases").pill:IsShown(), "the sidebar card shows its count, not OFF")
mock.Click(tabButton("Settings"))
check(#visibleEntries() == 5 and window.resetButton:IsShown(), "the display tab lists the five features, and reset")
-- The master switches in Settings › General.
mock.Click(navButton("Settings"))
mock.Click(tabButton("General"))
local switches = visibleEntries()
local function itemOf(entry)
    return entry.entry.item
end
check(itemOf(switches[1]).section == "categories" and itemOf(switches[1]).key == "chronicle" and itemOf(switches[2]).key == "fellows"
    and itemOf(switches[3]).key == "aliases" and switches[3].toggle.on and switches[1].chosen
    and detail.title:GetText() == ns.L.area_chronicle,
    "settings › general starts with the three main features, in the sidebar's order")
mock.Click(switches[3].switch)
mock.Advance(0.1)
check(not ns:IsCategoryEnabled("aliases") and navButton("Aliases").pill:IsShown() and navButton("Aliases").pill.text:GetText() == "OFF" and navButton("Aliases").count:GetText() == ""
    and navButton("Aliases").label:GetAlpha() < 1,
    "switching one off greys it in the head")
check(not window.resetButton.disabled, "and makes settings › general resettable")
mock.Click(navButton("Aliases"))
check(window.offNotice:IsShown() and #visibleRows() == 0 and #visibleEntries() == 0 and window.offNotice.text:GetText():find("Aliases", 1, true),
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
check(ns:IsCategoryEnabled("aliases") and ns:GetOption("general", "language") == "enUS",
    "reset there switches the main features back on; the language, on a tab of its own, stays")
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
check(ns.AliasService.Count() == 1 and FamulusDB.accountAliases == nil and ns:CountRegisteredEvents() == journeyEvents, "the remove button deletes the account's alias")
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
check(tabButton("General").selected and tabButton("Appearance") and tabButton("Language & time"),
    "the settings page has a general, an appearance and a language & time tab")
check(tabButton("General").label:IsShown() and not tabButton("General").icon:IsShown()
    and window.resetButton.mockPoint[2] == window.tabs,
    "the settings page's own tabs keep their names, and reset stands at the right end")
local generalRows = visibleEntries()
check(#generalRows == 6, "the three main features, chat feedback, minimap button and character profile (got " .. #generalRows .. ")")
local generalIcons = {}
for index, entry in ipairs(generalRows) do
    generalIcons[index] = entry.entry.item.icon
end
check(table.concat(generalIcons, " ") == "flag people tag chat compass person",
    "the addon's own settings have icons as well: " .. table.concat(generalIcons, " "))

-- Character profile.
enable("tooltipAliases", false)
mock.Click(generalRows[6].switch)
mock.Advance(0.1)
check(ns:UsesCharacterProfile() and not ns.features.tooltipAliases.enabled, "character profile starts as a copy")
enable("tooltipAliases")
mock.Click(generalRows[6].switch)
mock.Advance(0.1)
check(not ns:UsesCharacterProfile() and not ns.features.tooltipAliases.enabled, "switching back restores the account settings")
enable("tooltipAliases")

-- Settings: language & time tab.
ns:SetOption("general", "language", "auto")
mock.Advance(0.1)
mock.Click(tabButton("Language & time"))
local languageRows = visibleEntries()
local languageIcons = {}
for index, entry in ipairs(languageRows) do
    languageIcons[index] = entry.entry.item.icon
end
check(#languageRows == 3 and table.concat(languageIcons, " ") == "globe clock calendar",
    "language, time format and date format, with their icons: " .. table.concat(languageIcons, " "))
check(languageRows[1].value:IsShown() and languageRows[1].value:GetText() == ns.L.lang_auto and not languageRows[1].toggle:IsShown()
    and languageRows[1].tile.token == "control", "a choice shows its value in the entry instead of a switch; only a running switch lights its tile")
mock.Click(languageRows[1]) -- language
check(detail.title:GetText() == "Language" and detail.dropdown:IsShown() and not detail.toggle:IsShown()
    and detail.pills[1].text:GetText() == "Default: " .. ns.L.lang_auto and not detail.pills[2]:IsShown(),
    "chosen, the detail offers the dropdown and names the default")
mock.Click(detail.dropdown.open)
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

-- Time and date format: the clock and the order of a date, each shown by an example.
do
    local function at(hour, minute)
        return ns.FormatTime(time({ year = 2026, month = 11, day = 19, hour = hour, min = minute }))
    end
    local function pickValue(value)
        mock.Click(detail.dropdown.open)
        mock.Advance(0.05)
        for _, frame in ipairs(mock.frames) do
            if frame.value == value and frame.check and frame:IsVisible() then
                mock.Click(frame)
                mock.Advance(0.1)
                return true
            end
        end
        return false
    end
    check(languageRows[2].value:GetText() == "21:40" and languageRows[3].value:GetText() == ns.L.g_dateFormat_auto,
        "the time format shows its example, the date format follows the language")
    check(at(21, 40) == "21:40" and at(0, 5) == "00:05" and ns.FormatDate("2026", "11", "19") == "2026-11-19",
        "by default the 24-hour clock and the language's order")
    mock.Click(languageRows[2])
    check(detail.title:GetText() == "Time format" and detail.dropdown:IsShown() and detail.pills[1].text:GetText() == "Default: 21:40",
        "chosen, the time format offers its clocks and names the default by its example")
    check(pickValue("12h") and ns:GetOption("general", "timeFormat") == "12h", "the dropdown switches to the 12-hour clock")
    check(at(21, 40) == "9:40 PM" and at(9, 7) == "9:07 AM" and at(0, 5) == "12:05 AM" and at(12, 0) == "12:00 PM"
        and at(23, 59) == "11:59 PM", "on the 12-hour clock, with AM and PM; midnight is 12 AM, noon 12 PM")
    check(visibleEntries()[2].value:GetText() == "9:40 PM" and not window.resetButton.disabled, "the entry shows the new example")
    mock.Click(visibleEntries()[3])
    check(detail.title:GetText() == "Date format" and detail.pills[1].text:GetText() == "Default: " .. ns.L.g_dateFormat_auto,
        "the date format names its default")
    do -- what changes while the player chooses does not close the menu
        local function menuOpen()
            for _, frame in ipairs(mock.frames) do
                if frame.value == "{m}/{d}/{y}" and frame.check and frame:IsVisible() then
                    return true
                end
            end
            return false
        end
        mock.Click(detail.dropdown.open)
        mock.Advance(0.05)
        local opened = menuOpen()
        ns:Fire("CHRONICLE_CHANGED")
        ns:Fire("FELLOWS_CHANGED")
        mock.Advance(0.1)
        check(opened and menuOpen(), "news that comes in leaves an open dropdown of the settings open")
        ns:Fire("LOCALE_CHANGED")
        mock.Advance(0.1)
        check(menuOpen(), "and so does the same settings tab drawn again")
        mock.Click(detail.dropdown.open)
        mock.Advance(0.05)
        check(not menuOpen(), "(a second click closes it)")
    end
    ns:SetOption("general", "language", "deDE")
    check(ns.FormatDate("2026", "11", "19") == "19.11.2026" and at(21, 40) == "9:40 PM",
        "as the language, the date follows it; the clock stays as chosen")
    ns:SetOption("general", "language", "auto")
    mock.Advance(0.1) -- the window speaks anew before the dropdown opens
    check(pickValue("{m}/{d}/{y}") and ns.FormatDate("2026", "11", "19") == "11/19/2026", "a chosen order of the date")
    ns:SetOption("general", "language", "deDE")
    check(ns.FormatDate("2026", "11", "19") == "11/19/2026", "holds in every language")
    ns:SetOption("general", "language", "auto")
    ns:SetOption("general", "dateFormat", "%d nonsense")
    check(ns.FormatDate("2026", "11", "19") == "2026-11-19", "an order the addon does not know falls back to the language's")
    local orders = {}
    for _, pattern in ipairs(ns.DATE_FORMATS) do
        orders[#orders + 1] = ns.FormatDate("2026", "11", "19", pattern)
    end
    check(table.concat(orders, " ") == "2026-11-19 19.11.2026 11/19/2026 19/11/2026", "four orders to choose from: " .. table.concat(orders, " "))
    mock.Click(window.resetButton)
    mock.Click(window.resetButton)
    mock.Advance(4.1)
    check(ns:GetOption("general", "timeFormat") == "24h" and ns:GetOption("general", "dateFormat") == "auto", "reset brings back 24 hours and the language's order")
    mock.Click(visibleEntries()[1])
end

-- Settings: appearance tab.
mock.Click(tabButton("Appearance"))
local looks = visibleEntries()
check(#looks == 3 and looks[1].dot:IsShown() and looks[2].toggle:IsShown() and looks[3].value:IsShown(),
    "colour scheme, sparks and window size")
check(looks[1].chosen and detail.swatches:IsShown() and not detail.pills[1]:IsShown(), "the colour scheme shows its swatches in the detail")
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
for _, dot in ipairs(detail.swatches.dots) do
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
check(ns:GetOption("general", "accent") == "lilac", "a click on its entry changes nothing")
check(not window.resetButton.disabled, "a changed look makes the tab resettable")
mock.Click(window.resetButton)
mock.Click(window.resetButton)
mock.Advance(4.1)
check(ns:GetOption("general", "accent") == "lemon", "reset brings the default look back")
check(ns:GetOption("general", "language") == "auto" and ns:GetOption("general", "minimapAngle") == 215, "and touches nothing else")

-- Window size.
check(looks[3].label:GetText() == "Window size" and looks[3].value:GetText() == "100%", "the appearance tab offers the window size")
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
mock.Click(looks[2].switch)
mock.Advance(0.1)
check(ns:GetOption("general", "embers") == false and sparkGroups() == 0, "switching them off stops every one")
mock.Click(looks[2].switch)
mock.Advance(0.1)
check(sparkGroups() == sparksTotal, "switching them on starts them again")

-- The welcome page again: all at once, step by step and in every language
-- (UI/Welcome.lua). The opening above chose "Later"; here nothing is chosen yet.
do
    local Welcome = ns.UI.Welcome
    local page = welcomePage()
    for _, id in ipairs(Welcome.FEATURES) do
        enable(id, false)
    end
    FamulusDB.welcome = nil
    SlashCmdList.FAMULUS("")
    SlashCmdList.FAMULUS("")
    check(window:IsShown() and page:IsShown() and sparkGroups() == 0 and page.embers.playing,
        "without a choice the window opens on the welcome page; only its own sparks move")
    enable("rememberFellows")
    check(not Welcome.Wanted(), "whoever has one of the four on does not get it")
    enable("rememberFellows", false)

    -- An alias asked for from a player's menu wins; the page comes again later.
    SlashCmdList.FAMULUS("")
    ns:EditAlias("Thrall")
    check(window:IsShown() and not page:IsShown() and window.area.name:GetText() == "Aliases" and FamulusDB.welcome == nil,
        "an alias asked for opens the aliases page instead, without choosing")
    SlashCmdList.FAMULUS("")
    SlashCmdList.FAMULUS("")
    check(page:IsShown(), "the next opening shows the welcome page again")

    -- All at once: the four on, then what runs, then the chronicle.
    mock.reset()
    mock.Click(page.all)
    local running = true
    for _, id in ipairs(Welcome.FEATURES) do
        running = running and ns:GetOption(id, "enabled") == true and ns.features[id].enabled
    end
    check(running and FamulusDB.welcome == true, "one click switches the four on, and they run")
    local function shownRows()
        local list = {}
        for _, row in ipairs(page.rows) do
            if row:IsShown() then
                list[#list + 1] = row
            end
        end
        return list
    end
    local done = shownRows()
    check(page.done:IsShown() and #done == 7 and done[1].name:GetText() == ns.L.f_ownJourney
        and done[1].note:GetText() == "From the start" and done[3].name:GetText() == ns.L.f_sharing
        and done[3].note:GetText() == "" and done[3].name:GetText() == ns.L.f_sharing and done[4].name:GetText() == ns.L.f_liveFeed
        and done[7].name:GetText() == "Aliases" and done[7].note:GetText() == "Already running",
        "the end lists what runs now: the journey from the start, the steps, and the aliases that ran already")
    local roomy = true
    for _, row in ipairs(done) do
        roomy = roomy and row.name:GetStringWidth() + row.note:GetStringWidth() + 64 <= row:GetWidth()
    end
    check(roomy, "every name fits beside its note")
    mock.Click(page.open)
    local lines = 0
    for _, line in ipairs(mock.chat) do
        lines = lines + (line:find("features switched on", 1, true) and 1 or 0)
    end
    check(lines == 1 and mock.chat[#mock.chat]:find("4 features switched on. You can change them under Settings.", 1, true) ~= nil,
        "one line in the chat says how many")
    local rows = visibleRows()
    check(not page:IsShown() and window.area:IsShown() and window.area.name:GetText() == "Chronicle"
        and tabButton("Everyone") and tabButton("Everyone").selected
        and #rows == 1 and rows[1].label:GetText() == "Your chronicle is running",
        "then the chronicle opens; empty, it says that it is recording")
    SlashCmdList.FAMULUS("")
    SlashCmdList.FAMULUS("")
    check(not page:IsShown() and window.area:IsShown(), "after the choice the window opens as usual")

    -- "About" offers it again.
    for _, id in ipairs(Welcome.FEATURES) do
        enable(id, false)
    end
    FamulusDB.welcome = nil
    local function openAgain()
        mock.Click(navButton(ns.L.cat_about))
        for _, row in ipairs(visibleRows()) do
            if row.item.id == "welcome" then
                mock.Click(row.action)
                return row
            end
        end
    end
    local again = openAgain()
    check(again ~= nil and again.label:GetText() == "Welcome" and again.action.label:GetText() == "Show welcome page"
        and page:IsShown() and page.start:IsShown(), "\"About\" offers the welcome page again")

    -- Step by step.
    mock.reset()
    mock.Click(page.setup)
    mock.Click(page.on)
    check(ns.features.companions.enabled and page.count:GetText() == "Step 2 of 5" and page.name:GetText() == ns.L.f_sharing
        and page.tag.text:GetText() == "Goes to friends and guild members who use Famulus" and page.stage.current == "share"
        and not page.option:IsShown() and page.skip:IsShown() and page.skip.label:GetText() == "Skip"
        and page.stage.lit and page.stage.scenes.share.pills[1]:IsShown(),
        "\"Switch on and continue\" switches the feature on and goes on to sharing, drawn as if it were on")
    mock.Click(page.skip)
    check(not ns.features.sharing.enabled and page.name:GetText() == ns.L.f_liveFeed and page.stage.current == "feed"
        and page.option:IsShown() and page.option.name:GetText() == "Reactions" and page.option.toggle.on == true
        and page.on.label:GetText() == "Continue" and page.skip.label:GetText() == "Switch off and continue",
        "skipped stays off; the live feed is on already, with the reactions beside it")
    mock.Click(page.option)
    check(ns.features.sharing:Get("reactions") == false and page.option.toggle.on == false, "the option switches here")
    mock.Click(page.option)
    mock.Click(page.skip)
    check(not ns.features.liveFeed.enabled and page.name:GetText() == ns.L.f_rememberFellows, "\"Switch off and continue\" switches it off")
    mock.Click(page.back)
    check(page.name:GetText() == ns.L.f_liveFeed and page.on.label:GetText() == "Switch on and continue"
        and page.skip.label:GetText() == "Skip", "back goes one step back; off now, it can be switched on again")
    mock.Click(page.on)
    mock.Click(page.on)
    check(ns.features.liveFeed.enabled and ns.features.rememberFellows.enabled and page.count:GetText() == "Step 5 of 5"
        and page.on.label:GetText() == "Switch on and finish" and page.option.name:GetText() == "Include the guild",
        "the last step finishes")
    mock.Click(page.skip)
    done = shownRows()
    check(page.done:IsShown() and done[2].note:GetText() == "" and done[3].note:GetText() == "Skipped"
        and done[4].note:GetText() == "" and done[6].note:GetText() == "Skipped" and not done[6].check:IsShown(),
        "the end says what was skipped")
    mock.Click(page.again)
    check(page.count:GetText() == "Step 5 of 5", "back from the end is the last step")
    mock.Click(page.skip)
    mock.Click(page.open)
    check(FamulusDB.welcome == true and ns.features.companions.enabled and ns.features.rememberFellows.enabled
        and ns.features.liveFeed.enabled and not ns.features.sharing.enabled and not ns.features.nearbyFriends.enabled
        and mock.chat[#mock.chat]:find("3 features switched on", 1, true) ~= nil and not page:IsShown(),
        "finished: what was switched on runs, what was skipped does not, one line in the chat")

    -- The fellowship's tile says that it runs, as the others do.
    openAgain()
    check(page.start:IsShown() and page.tiles[2].pill:IsShown(), "the fellowship's tile says so once one of its features runs")

    -- The line at the end counts what the steps left switched on.
    local function toTheEnd() -- (from sharing on: skip what is off, keep what is on)
        mock.Click(page.skip)
        mock.Click(page.on)
        mock.Click(page.on)
        mock.Click(page.skip)
    end
    enable("companions", false)
    mock.Click(page.setup)
    mock.Click(page.on)
    mock.Click(page.back)
    mock.Click(page.skip)
    check(not ns.features.companions.enabled and page.name:GetText() == ns.L.f_sharing, "switched on in a step, then off again")
    toTheEnd()
    local lines = #mock.chat
    mock.Click(page.open)
    check(page.switched and next(page.switched) == nil and #mock.chat == lines and not page:IsShown(),
        "what was switched off again is not counted: no line in the chat")
    openAgain()
    mock.Click(page.setup)
    mock.Click(page.on)
    window:Hide()
    SlashCmdList.FAMULUS("")
    openAgain()
    mock.Click(page.setup)
    check(ns.features.companions.enabled and page.on.label:GetText() == "Continue", "closed half-way, the feature stays on")
    mock.Click(page.on)
    toTheEnd()
    lines = #mock.chat
    mock.Click(page.open)
    check(#mock.chat == lines, "and the count starts anew with the page: nothing switched on this time, no line")

    -- A feature whose own switch is on but whose area is off does not run:
    -- its step says what its buttons do.
    ns:SetOption("categories", "chronicle", false)
    openAgain()
    mock.Click(page.setup)
    mock.Click(page.skip)
    mock.Click(page.skip)
    check(page.name:GetText() == ns.L.f_liveFeed and ns:GetOption("liveFeed", "enabled") == true and not ns.features.liveFeed.enabled
        and page.on.label:GetText() == "Switch on and continue" and page.skip.label:GetText() == "Skip",
        "a feature whose area is switched off is offered to be switched on, not to be switched off")
    mock.Click(page.skip)
    check(ns:GetOption("liveFeed", "enabled") == true and not ns:IsCategoryEnabled("chronicle"), "skipped, both switches stay as they were")
    ns:SetOption("categories", "chronicle", true)
    window:Hide()
    SlashCmdList.FAMULUS("")

    -- In every language the page has its words, and every view fits.
    local PAGE_H = page:GetHeight()
    for _, language in ipairs(ns:GetLocaleCodes()) do
        ns:SetOption("general", "language", language)
        mock.Advance(0.1)
        openAgain()
        local laterBottom = -page.later.mockPoint[5] + page.later:GetHeight()
        local fits = page.start:IsShown() and page.title:GetText() == ns.L.ui_welcome_title and laterBottom <= PAGE_H
            and page.setup:GetWidth() + page.all:GetWidth() + 12 <= 960
        mock.Click(page.setup)
        local tallest = 0
        for number, current in ipairs(Welcome.Steps()) do
            local bottom = 64 + 14 + 12 + page.name:GetStringHeight() + 12 + 24 + 16 + page.body:GetStringHeight()
            for _, point in ipairs(page.points) do
                bottom = bottom + 16 + point:GetHeight()
            end
            if page.option:IsShown() then
                bottom = bottom + 20 + page.option:GetHeight()
            end
            tallest = math.max(tallest, bottom)
            fits = fits and page.name:GetText() == ns.L["f_" .. current.id] and page.count:GetText():find(tostring(number), 1, true) ~= nil
                and page.body:GetText() ~= nil
                and page.back:GetWidth() + page.skip:GetWidth() + page.on:GetWidth() + 40 <= page:GetWidth() - 96
            mock.Click(page.skip)
        end
        mock.Click(page.again)
        mock.Click(page.skip)
        local doneBottom = -page.again.mockPoint[5] + page.again:GetHeight()
        check(fits and page.done:IsShown() and tallest <= PAGE_H - 76 - 8 and doneBottom <= PAGE_H,
            "the welcome page in " .. language .. " (steps end at " .. tallest .. ", the end at " .. doneBottom .. " of " .. PAGE_H .. ")")
        mock.Click(page.open)
    end
    ns:SetOption("general", "language", "auto")
    -- Skipping switched the live feed off; it is on by default.
    enable("liveFeed")
    mock.Advance(0.1)

    for _, id in ipairs(Welcome.FEATURES) do
        enable(id, false)
    end
    mock.Advance(0.1)
    check(ns:CountRegisteredEvents() == journeyEvents, "switched off again, the four listen to nothing")
end

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
check(ns.features.ownJourney.enabled and not ns.features.companions.enabled and #Chronicle.Entries() == 0,
    "the journey runs from the start; nothing has happened yet")
enable("ownJourney", false)
local eventsBeforeChronicle = ns:CountRegisteredEvents()
check(eventsBeforeChronicle == 0, "switched off, the journey listens to nothing")
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
check(#Chronicle.Entries() == 5 and Chronicle.Text(Chronicle.Entries()[4]) == "Edwin VanCleef defeated for the first time"
    and Chronicle.Text(Chronicle.Entries()[5]) == "Challenge completed: Challenge 501", "bosses and challenges follow; one already earned does not")
do -- a boss again is no first; the last boss of an instance clears it
    local count, realTime = #Chronicle.Entries(), time
    time = function()
        return realTime() + 5
    end
    mock.Fire("BOSS_KILL", 77, "Edwin VanCleef")
    local again = Chronicle.Entries()[count + 1]
    check(again and again.first == nil and Chronicle.Text(again) == "Edwin VanCleef defeated", "a boss defeated before is no first")
    Chronicle.finalBosses[77] = true
    time = function()
        return realTime() + 6
    end
    mock.Fire("BOSS_KILL", 77, "Edwin VanCleef")
    local cleared = Chronicle.Entries()[count + 2]
    check(cleared and cleared.instance == "Westfall" and Chronicle.Text(cleared) == "Westfall cleared"
        and Chronicle.Text({ k = "boss", instance = "Westfall", who = "Jaina Proudmoore" }) == "Jaina Proudmoore clears Westfall"
        and Chronicle.Text({ k = "boss", name = "Hogger", first = 1, who = "Jaina Proudmoore" }) == "Jaina Proudmoore defeats Hogger for the first time",
        "the last boss clears the instance: " .. tostring(cleared and Chronicle.Text(cleared)))
    Chronicle.finalBosses[77] = nil
    FamulusCharDB.bosses = nil
    check(Chronicle.SeeBoss(77) == false and Chronicle.SeeBoss(76) == true, "bosses already in the chronicle count as known")
    time = realTime
    table.remove(Chronicle.Entries(), count + 2)
    table.remove(Chronicle.Entries(), count + 1)
end
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
do -- who was there when the player died
    local count, realTime = #Chronicle.Entries(), time
    mock.state.group = { members = { { name = "Ori", surname = "Nachtwind", guid = "Player-1-ORI", level = 20, class = "ROGUE" } } }
    -- Two entries of a kind in one second are one event; the first death lies apart.
    time = function()
        return realTime() + 30
    end
    mock.Advance(10)
    mock.Fire("PLAYER_DEAD")
    local death = Chronicle.Entries()[count + 1]
    local _, detail = Chronicle.Text(death or {})
    check(death and death.k == "death" and death.with[1] == "Ori Nachtwind" and detail and detail:find("  ·  with Ori$"),
        "a death in a party names who was there: " .. tostring(detail))
    local _, runDetail = Chronicle.TextRun({ death, { k = "death", zone = death.zone, level = death.level } })
    check(runDetail and runDetail:find("  ·  with Ori$"), "a wipe names who was there: " .. tostring(runDetail))
    mock.state.group.members[1].dead = true
    mock.Advance(15)
    _, detail = Chronicle.Text(death)
    check(death.fell and death.fell[1] == "Ori Nachtwind" and detail:find("  ·  fell together with Ori$"),
        "who dies a moment later fell together with the player: " .. tostring(detail))
    table.remove(Chronicle.Entries(), count + 1)
    -- Who already lies dead when the player falls counts at once, once.
    mock.Advance(10)
    time = function()
        return realTime() + 60
    end
    mock.Fire("PLAYER_DEAD")
    death = Chronicle.Entries()[count + 1]
    check(death and death.fell and #death.fell == 1, "who lies dead already fell together with the player")
    mock.Advance(15)
    check(#death.fell == 1, "and is named once")
    time = realTime
    mock.state.group = nil
    table.remove(Chronicle.Entries(), count + 1)
end
do -- the first time in a dungeon or a raid
    local count, zone = #Chronicle.Entries(), mock.state.zone
    mock.state.zone, mock.state.instanceType = "The Deadmines", "party"
    mock.state.group = { members = { { name = "Mira", surname = "Sturmfeder", guid = "Player-1-MIRA", level = 20, class = "MAGE" } } }
    mock.Fire("ZONE_CHANGED_NEW_AREA")
    local first = Chronicle.Entries()[count + 1]
    local title, detail = Chronicle.Text(first or {})
    check(first and first.k == "instance" and #Chronicle.Entries() == count + 1 and title == "First time in The Deadmines"
        and detail == "with Mira", "the first time in a dungeon, with who came along: " .. tostring(title) .. " / " .. tostring(detail))
    check(Chronicle.Text({ k = "instance", instance = "Molten Core", who = "Jaina Proudmoore" }) == "Jaina Proudmoore enters Molten Core for the first time",
        "a friend's first time in a raid")
    mock.Fire("ZONE_CHANGED_NEW_AREA")
    check(#Chronicle.Entries() == count + 1, "the second time is no news")
    mock.state.zone, mock.state.instanceType, mock.state.group = zone, nil, nil
    FamulusCharDB.zones["The Deadmines"] = nil
    table.remove(Chronicle.Entries(), count + 1)
end
do -- a new mount; a class mount is an ability already
    local count = #Chronicle.Entries()
    local mounts = { [6] = { "Brown Horse", 458, 132261 }, [41] = { "Warhorse", 13819, 132261 } }
    C_MountJournal = { GetMountInfoByID = function(id)
        return unpack(mounts[id] or {})
    end }
    mock.Fire("NEW_MOUNT_ADDED", 6)
    local horse = Chronicle.Entries()[count + 1]
    check(horse and horse.k == "mount" and horse.mount == 6 and horse.icon == 132261 and Chronicle.Text(horse) == "New mount: Brown Horse"
        and Chronicle.Text({ k = "mount", mount = 99, name = "Pinto", who = "Jaina Proudmoore" }) == "Jaina Proudmoore gets a new mount: Pinto",
        "a new mount, named as this client names it: " .. tostring(horse and Chronicle.Text(horse)))
    mock.Fire("NEW_MOUNT_ADDED", 41)
    check(#Chronicle.Entries() == count + 1, "a class mount is not told again as a mount")
    C_MountJournal = nil
    table.remove(Chronicle.Entries(), count + 1)
end
do -- a new PvP rank, the renown track 2800, with its title
    local count = #Chronicle.Entries()
    Enum.PvPRanks, UnitSex = { Rank_1 = 5 }, function()
        return 2
    end
    GetText = function(key)
        return key == "PVP_RANK_10_1" and "Knight" or nil
    end
    mock.Fire("MAJOR_FACTION_RENOWN_LEVEL_CHANGED", 2600, 7, 6)
    mock.Fire("MAJOR_FACTION_RENOWN_LEVEL_CHANGED", 2800, 5, 6)
    check(#Chronicle.Entries() == count, "another renown track, or a rank lost, is no news")
    mock.Fire("MAJOR_FACTION_RENOWN_LEVEL_CHANGED", 2800, 6, 5)
    local rank = Chronicle.Entries()[count + 1]
    local title, detail = Chronicle.Text(rank or {})
    check(rank and rank.k == "pvpRank" and rank.rank == 6 and title == "PvP rank 6 reached" and detail == "Knight"
        and Chronicle.Text({ k = "pvpRank", rank = 9, who = "Jaina Proudmoore" }) == "Jaina Proudmoore reaches PvP rank 9",
        "a new PvP rank with its title: " .. tostring(title) .. " / " .. tostring(detail))
    Enum.PvPRanks, UnitSex, GetText = nil, nil, nil
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
    check(learned and learned.icon == 136197 and ns.UI.FeedStory(learned).texture == 136197,
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
    local CLASSES = { WARRIOR = true, PALADIN = true, HUNTER = true, ROGUE = true, PRIEST = true,
        SHAMAN = true, MAGE = true, WARLOCK = true, DRUID = true }
    local ids = {}
    for _, ability in ipairs(Chronicle.abilities) do
        local also = ability.also == nil or type(ability.also) == "table"
        for _, spell in ipairs(ability.also or {}) do
            also = also and type(spell) == "number"
        end
        -- Its own sentences, or none at all: then the game names the spell.
        local own = ns.L["c_ability_" .. ability.id] ~= "c_ability_" .. ability.id
        local their = ns.L["c_their_ability_" .. ability.id] ~= "c_their_ability_" .. ability.id
        local sentences
        if ability.sentences then
            sentences = own and their and ns.L["c_their_ability_" .. ability.id]:find("%s", 1, true) ~= nil
        else
            sentences = not own and not their
        end
        check(type(ability.id) == "string" and not ids[ability.id] and type(ability.spell) == "number" and also
            and (ability.class == nil or CLASSES[ability.class]) and sentences
            and (ability.picture == nil or ns.UI.media[ability.picture] ~= nil),
            "ability " .. tostring(ability.id) .. " has a spell, a class there is, sentences where it says so and a picture that exists")
        ids[ability.id] = true
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
    -- A class's ability: only that class asks for it, and the game names it.
    local spellNames = { [5487] = "Bear Form", [24858] = "Moonkin Form", [13819] = "Summon Warhorse",
        [1279399] = "Summon Forsaken Warhorse" }
    C_Spell = { GetSpellName = function(id) return spellNames[id] end }
    mock.state.spells = { [5487] = true }
    mock.Fire("SPELLS_CHANGED")
    check(#Chronicle.Entries() == count + 2 and not Chronicle.HasAbility("bearForm"), "a warrior never asks for a druid's form")
    mock.state.playerClass = "DRUID"
    mock.Fire("SPELLS_CHANGED")
    local bear = Chronicle.Entries()[count + 3]
    check(#Chronicle.Entries() == count + 3 and bear.ability == "bearForm" and bear.name == "Bear Form"
        and Chronicle.Text(bear) == "Learned Bear Form" and select(2, Chronicle.Text(bear)) == "at level 13"
        and Chronicle.Text({ k = "ability", ability = "moonkinForm", name = "Mondkingestalt", who = "Jaina Proudmoore" })
            == "Jaina Proudmoore learns Moonkin Form",
        "a druid's form is written down when it is learned, named as this client names the spell")
    spellNames[5487] = nil
    check(Chronicle.Text(bear) == "Learned Bear Form" and Chronicle.Text({ k = "ability", ability = "bearForm" }) == "Learned an ability",
        "where this client cannot name it, the name the entry brought stands")
    spellNames[5487] = "Bear Form"
    -- Another race's version of the same ability counts as it.
    mock.state.playerClass = "PALADIN"
    mock.state.spells = { [1279399] = true }
    mock.Fire("SPELLS_CHANGED")
    local steed = Chronicle.Entries()[count + 4]
    check(#Chronicle.Entries() == count + 4 and steed.ability == "warhorse" and steed.name == "Summon Forsaken Warhorse",
        "a spell another race learns instead counts as the same ability")
    check(Chronicle.Text({ k = "ability", ability = "riding", who = "Jaina Proudmoore" }) == "Jaina Proudmoore learns to ride"
        and Chronicle.Text({ k = "ability", ability = "fromLater", name = "Swimming", who = "Jaina Proudmoore" }) == "Jaina Proudmoore learns Swimming",
        "a companion's ability reads as a sentence, even one this version does not know")
    -- A character that can do it already when the chronicle begins tells nothing.
    mock.state.playerClass = "DRUID"
    mock.state.spells = { [5487] = true }
    enable("ownJourney", false)
    FamulusCharDB.abilities = nil
    enable("ownJourney")
    mock.Fire("SPELLS_CHANGED")
    check(#Chronicle.Entries() == count + 4 and FamulusCharDB.abilities.riding and FamulusCharDB.abilities.ridingFast
        and FamulusCharDB.abilities.bearForm and not FamulusCharDB.abilities.catForm,
        "abilities from before the chronicle are only taken note of")
    for index = #Chronicle.Entries(), count + 1, -1 do
        Chronicle.Entries()[index] = nil
    end
    C_Spell = nil
    mock.state.riding = nil
    mock.state.spells = nil
    mock.state.playerClass = nil
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
    -- A class's item: only that class asks for it.
    mock.state.owned = { [211527] = 1, [5176] = 1 }
    mock.Fire("BAG_UPDATE_DELAYED")
    check(#Chronicle.Entries() == count + 1 and not Chronicle.HasItem(5176), "a warrior never asks for a shaman's totem")
    mock.state.playerClass = "SHAMAN"
    mock.Fire("BAG_UPDATE_DELAYED")
    check(#Chronicle.Entries() == count + 2 and Chronicle.Entries()[count + 2].item == 5176, "a shaman's totem is written down")
    Chronicle.Entries()[count + 2] = nil
    mock.state.playerClass = nil
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
    -- The sounds played so far, and the last one.
    local function sounds()
        local last
        for _, call in ipairs(mock.calls) do
            if call[1] == "PlaySoundFile" then
                last = call
            end
        end
        return mock.count("PlaySoundFile"), last
    end
    Feed.Clear()
    check(ns.features.liveFeed.enabled and ns:GetOption("liveFeed", "zone") == false and ns:GetOption("liveFeed", "level") == true
        and ns:GetOption("liveFeed", "own") == false and ns:GetOption("liveFeed", "sound") == true,
        "the feed is on from the start, with its sound; arrivals in a zone and the player's own events are not shown")
    mock.Advance(3) -- (a sound shortly before would hold back the next)
    local heard = sounds()
    -- (Two events of a kind within a second count as one; hence the times.)
    Chronicle.Add("ability", { ability = "riding", level = 14, t = time() - 18, probe = true })
    check(#Feed.Shown() == 0, "from the start the feed is about companions: the player's own events stay off screen")
    ns:SetOption("liveFeed", "own", true)
    Chronicle.Add("level", { level = 14, t = time() - 19, probe = true })
    check(#Feed.Shown() == 0, "the player's own level-up is not shown: the game announces it itself")
    check(sounds() == heard, "no card, no sound")
    Chronicle.Add("ability", { ability = "riding", level = 14, t = time() - 20, probe = true })
    local card = Feed.Shown()[1]
    check(#Feed.Shown() == 1 and card:IsShown() and card.title:GetText() == "Learned to ride"
        and card.photo:IsShown() and not card.icon:IsShown() and not card.number:IsShown(),
        "asked for, an event of the player's own appears as a card with an icon of the game")
    local count, sound = sounds()
    check(count == heard + 1 and sound[2] == ns.UI.Feed.SOUND and sound[3] == "SFX",
        "a card comes with a sound, on the game's sound effects channel")
    local file = io.open("Famulus/" .. ns.UI.Feed.SOUND:match("\\Famulus\\(.+)$"):gsub("\\", "/"), "rb")
    check(file ~= nil and file:read(4) == "OggS", "the sound is an Ogg file in the addon folder")
    if file then
        file:close()
    end
    check(card.crest:GetHeight() < card:GetHeight() and card.crest:GetWidth() < card:GetWidth()
        and card:GetWidth() >= 230 and card.shape.border.token == "cardActive" and card.mark == nil and card.grain ~= nil,
        "the picture is a crest inside its band; a milestone has the accent border, no mark at its left")
    check(card.bar:IsShown() and card.barGroup:IsPlaying(), "a line along its foot runs out while it stays")
    Chronicle.Add("zone", { zone = "Nowhere", t = time() - 21, probe = true })
    Chronicle.Add("death", { zone = "Nowhere", who = "Jaina Proudmoore", t = time() - 3600, probe = true })
    check(#Feed.Shown() == 1, "a kind that is switched off and old news stay off screen")
    ns:SetOption("liveFeed", "own", false)
    Chronicle.Add("boss", { name = "Hogger", t = time() - 22, probe = true })
    check(#Feed.Shown() == 1 and #Feed.Waiting() == 0, "switched off again, the player's own events stay off screen")
    ns:SetOption("liveFeed", "own", true)
    Chronicle.Add("item", { item = 211527, name = "Cozy Sleeping Bag", who = "Jaina Proudmoore", probe = true })
    check(#Feed.Shown() == 1 and #Feed.Waiting() == 1 and Feed.deck.count:IsShown() and Feed.deck.count.text:GetText() == "+1",
        "a card right after another waits its turn behind it: the newest stays on top a moment")
    mock.Advance(1.7)
    check(#Feed.Shown() == 2 and #Feed.Waiting() == 0 and not Feed.deck.count:IsShown()
        and Feed.Shown()[1].head:GetText() == "Jaina Proudmoore" and Feed.Shown()[1].head:IsShown()
        and Feed.Shown()[1].title:GetText() == "Received: Cozy Sleeping Bag" and Feed.Shown()[1].photo:IsShown(),
        "a companion's event appears above the older card, whose it is in its head: "
        .. Feed.Shown()[1].head:GetText() .. " / " .. Feed.Shown()[1].title:GetText())
    check(not Feed.Shown()[2].head:IsShown() and not Feed.Shown()[2].headDot:IsShown() and not Feed.Shown()[2].headDot.glow:IsShown()
        and Feed.Shown()[1].headDot:IsShown(),
        "the player's own event has no head: the card is theirs")
    check(not Feed.Shown()[1].react:IsShown() and not Feed.Shown()[2].react:IsShown() and not Feed.Shown()[1].mouseEnabled,
        "without sharing there is no button to react, and the cards let the mouse through")
    check(Feed.Shown()[1]:GetWidth() > Feed.Shown()[2]:GetWidth() and Feed.Shown()[1].shape.border.token == "cardBorder",
        "a band is as wide as its text needs; a companion's event is no milestone")
    check(sounds() == heard + 1, "cards that come together bring one sound")
    for skill = 1, 3 do
        Chronicle.Add("skill", { skill = skill, name = "Craft " .. skill, rank = 75, probe = true })
    end
    check(#Feed.Shown() == 2 and #Feed.Waiting() == 3 and Feed.deck.count.text:GetText() == "+3"
        and Feed.deck.edges[1]:IsShown() and Feed.deck.edges[2]:IsShown(),
        "many at once wait as a stack behind the top card, with their number")
    mock.Advance(1.3)
    check(#Feed.Shown() == 3 and #Feed.Waiting() == 2 and Feed.Shown()[1].title:GetText() == "Craft 1 raised to 75",
        "the next comes in once the newest has had its moment, the sooner the more wait")
    mock.Advance(2.9)
    check(#Feed.Shown() == 3 and #Feed.Waiting() == 0 and Feed.Shown()[3].title:GetText() == "Craft 1 raised to 75"
        and not Feed.deck.count:IsShown() and not Feed.deck.edges[1]:IsShown(),
        "one after another they come in; at most three cards, the oldest is pushed out, and nothing waits any more")
    local newest, older = Feed.Shown()[1], Feed.Shown()[2]
    check(not newest.slim and newest:GetHeight() == 64 and older.slim and older:GetHeight() == 34 and Feed.Shown()[3].slim
        and older.title:IsShown() and not older.detail:IsShown() and not older.sep:IsShown() and older.crest:GetWidth() == 24,
        "only the newest card is large; the older ones are slim rows: a small crest and what happened")
    ns:SetOption("liveFeed", "own", false)
    mock.Advance(3)
    check(#Feed.Shown() == 3, "a card stays for its time")
    mock.Advance(3.8)
    check(#Feed.Shown() == 0 and not newest:IsShown() and not newest.barGroup:IsPlaying(), "then it fades out and is gone")
    Chronicle.Add("level", { level = 15, who = "Jaina Proudmoore", t = time() - 23, probe = true })
    check(#Feed.Shown() == 1 and Feed.Shown()[1].number:IsShown() and Feed.Shown()[1].number:GetText() == "15",
        "a companion's level-up appears with its number")
    check(sounds() == heard + 2, "a card some time later brings its own sound")
    Feed.Clear()
    mock.Advance(3)
    ns:SetOption("liveFeed", "sound", false)
    Chronicle.Add("death", { zone = "Nowhere", who = "Jaina Proudmoore", t = time() - 26, probe = true })
    check(#Feed.Shown() == 1 and sounds() == heard + 2, "with the sound switched off, the card comes silently")
    ns:SetOption("liveFeed", "sound", true)
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
    mock.Advance(3)
    heard = sounds()
    local unitsBefore = mock.state.units
    mock.state.units = { player = { name = "Ilsa" } }
    SlashCmdList.FAMULUS("feed test")
    mock.state.units = unitsBefore
    check(#Feed.Shown() == 1 and Feed.Shown()[1].number:GetText() == "13" and sounds() == heard + 1,
        "/fam feed test shows a sample card, with its sound")
    local mira, borin = ns.ChronicleService.SamplePeople()
    local waiting = Feed.Waiting()
    check(#waiting == 3 and waiting[1].count == 2 and waiting[1].chip.text == borin:match("^%S+") .. " and " .. mira:match("^%S+")
        and Feed.deck.count.text:GetText() == "+3",
        "and at once the samples' friends: a boss two of them share, a death, an item, waiting behind it: "
        .. tostring(waiting[1] and waiting[1].chip.text))
    local sample = Feed.Shown()[1]
    check(sample.head:IsShown() and sample.head:GetText() == (ns.ChronicleService.Character() or "Ilsa")
        and sample.detail:GetText() == GetRealZoneText() and sample:GetHeight() == 76,
        "the sample card has all three rows: the player's own name, the level, the zone: "
        .. tostring(sample.head:GetText()) .. " / " .. tostring(sample.detail:GetText()))
    -- A long text is cut at the widest band instead of stretching it.
    Feed.Fill(sample, { kind = "boss", chip = { text = "Papa (Borin Ironbeard)" }, title = string.rep("Edwin VanCleef ", 6),
        detail = "The Deadmines" })
    check(sample:GetWidth() == 340 and sample.title:GetWidth() < 340, "the band is at most 340 wide: " .. sample:GetWidth())
    Feed.Fill(sample, { kind = "zone", title = "Arrived" })
    check(sample:GetHeight() == 64 and sample:GetWidth() == 230 and not sample.head:IsShown() and not sample.detail:IsShown(),
        "one row stays in the band of 64, at least 230 wide")
    Feed.Clear()
    forget()
end
do -- the live feed keeps the last three if asked; the same event of several friends shares a card
    local Feed = ns.UI.Feed
    local function forget()
        local entries = Chronicle.Entries()
        for index = #entries, 1, -1 do
            if entries[index].probe then
                table.remove(entries, index)
            end
        end
    end
    -- Resting: a row, its content faint, its band opaque, its line gone.
    local function rests(card)
        return card.resting and card.slim and card:GetHeight() == 34 and card:GetAlpha() == 1
            and math.abs(card.body:GetAlpha() - Feed.REST) < 0.01 and not card.bar:IsShown()
    end
    Feed.Clear()
    mock.Advance(3)
    check(ns:GetOption("liveFeed", "keep") == false and not Feed.IsKeeping(), "from the start the cards fade out after their time")
    ns:SetOption("liveFeed", "keep", true)
    check(Feed.IsKeeping(), "asked for, the last three stay")
    Chronicle.Add("level", { level = 30, who = "Jaina Proudmoore", t = time() - 40, probe = true })
    local first = Feed.Shown()[1]
    mock.Advance(7.6)
    check(#Feed.Shown() == 1 and first:IsShown() and rests(first),
        "past its time a kept card rests as a row: its content fainter, its band opaque, without its line")
    for level = 31, 34 do
        Chronicle.Add("level", { level = level, who = "Jaina Proudmoore", t = time() - 10 - level, probe = true })
    end
    mock.Advance(4.3)
    check(#Feed.Shown() == 3 and #Feed.Waiting() == 0 and Feed.Shown()[1].number:GetText() == "34"
        and Feed.Shown()[3].number:GetText() == "32", "kept or not, a fourth card pushes the oldest out")
    local row = Feed.Shown()[2]
    check(row.slim and row.head:IsShown() and row.head:GetText() == "Jaina Proudmoore" and row.sep:IsShown()
        and not row.headDot:IsShown() and row.number:IsShown() and not row.badge:IsShown(),
        "a friend's row names them, a dot, then what happened")
    mock.Advance(8)
    local resting = 0
    for _, card in ipairs(Feed.Shown()) do
        resting = resting + (card:IsShown() and rests(card) and 1 or 0)
    end
    check(#Feed.Shown() == 3 and resting == 3, "and the three stay on screen, resting")
    local given = false
    Feed.Show({ kind = "level", chip = { text = "Jaina Proudmoore" }, title = "Reached level 35", number = 35,
        reaction = { icon = "cheer", given = function() return given end, give = function() given = true end } }, 4)
    local reacted = Feed.Shown()[1]
    reacted.react.scripts.OnClick(reacted.react)
    mock.Advance(2)
    check(given and Feed.Shown()[1] == reacted and reacted:IsShown() and reacted:GetAlpha() == 1,
        "kept, a card stays after a reaction, its button lit")
    mock.Advance(3)
    check(rests(reacted), "(it rests once its time is up)")
    reacted.react.scripts.OnEnter(reacted.react)
    check(reacted.body:GetAlpha() == 1 and reacted.react:GetWidth() == 24, "the mouse on its button brings a resting row up")
    reacted.react.scripts.OnLeave(reacted.react)
    mock.Advance(0.6)
    check(rests(reacted) and #Feed.Shown() == 3, "and it rests again once the mouse has left")
    SlashCmdList.FAMULUS("feed")
    check(Feed.IsMoving() and Feed.mover:GetHeight() >= 76 + 2 * 34, "the mark to move the feed shows the room three cards take")
    SlashCmdList.FAMULUS("feed")
    ns:SetOption("liveFeed", "keep", false)
    mock.Advance(0.6)
    check(#Feed.Shown() == 0 and not Feed.IsKeeping() and Feed.mover:GetHeight() == 64, "switched off, the resting cards go")

    -- The same event of several friends at once shares a card.
    local friends = { "Jaina Proudmoore", "Thrall Doomhammer", "Varian Wrynn", "Tyrande Whisperwind", "Malfurion Stormrage" }
    for index, who in ipairs(friends) do
        Chronicle.Add("boss", { id = 7, name = "Hogger", zone = "Elwynn Forest", who = who, t = time() - 50 - index, probe = true })
    end
    local bundle = Feed.Shown()[1]
    check(#Feed.Shown() == 1 and #Feed.Waiting() == 0 and bundle.badge:IsShown() and bundle.badgeText:GetText() == "5"
        and bundle.head:GetText() == "Jaina, Thrall and 3 more" and bundle.detail:GetText() == "Elwynn Forest"
        and not bundle.react:IsShown(),
        "the same boss of several friends at once shares one card: who in its head, how many in the crest's corner, "
        .. "the place below: " .. tostring(bundle.head:GetText()) .. " / " .. tostring(bundle.detail:GetText()))
    mock.Advance(0.5)
    Chronicle.Add("level", { level = 36, who = "Jaina Proudmoore", t = time() - 60, probe = true })
    Chronicle.Add("death", { zone = "Duskwood", who = "Thrall Doomhammer", t = time() - 61, probe = true })
    Chronicle.Add("death", { zone = "Duskwood", who = "Varian Wrynn", t = time() - 62, probe = true })
    Chronicle.Add("death", { zone = "Westfall", who = "Tyrande Whisperwind", t = time() - 63, probe = true })
    check(#Feed.Waiting() == 3 and Feed.Waiting()[2].count == 2 and Feed.Waiting()[2].chip.text == "Thrall and Varian",
        "a story that waits takes in the same event of others too; another place is another event")
    ns:SetOption("liveFeed", "own", true)
    Chronicle.Add("death", { zone = "Duskwood", t = time() - 64, probe = true })
    check(#Feed.Waiting() == 4, "the player's own events keep a card of their own")
    ns:SetOption("liveFeed", "own", false)
    Feed.Clear()
    mock.Advance(3)
    Chronicle.Add("boss", { id = 8, name = "Edwin VanCleef", who = "Jaina Proudmoore", t = time() - 70, probe = true })
    mock.Advance(6.2)
    Chronicle.Add("boss", { id = 8, name = "Edwin VanCleef", who = "Thrall Doomhammer", t = time() - 71, probe = true })
    check(#Feed.Shown() == 2 and not Feed.Shown()[1].badge:IsShown(), "seconds later, the same event is news of its own")
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
    local received, given = 0, nil
    for _, entry in ipairs(Chronicle.Entries()) do
        received = received + #Chronicle.Reactions(entry)
        given = given or (entry.mine and entry)
    end
    check(received >= 3 and given and given.who == "Borin Ironbeard" and not Chronicle.ReactionUntold(given),
        "friends reacted to some sample events, and the player to one of Borin's, which is never sent")
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
    check(card and card:IsShown() and card.head:GetText() == "Jaina Proudmoore" and card.title:GetText() == "Fallen"
        and card.detail:GetText() == theirs.zone .. "  ·  at level 20" and card:GetHeight() == 76,
        "fresh news of a companion appears as a card on screen: who above, what, and where below, in a band of three rows: "
        .. tostring(card and card.title:GetText()) .. " / " .. tostring(card and card.detail:GetText()))
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

-- Reactions: a click on a friend's card gives one, which goes to them while
-- they are online; one to someone offline waits for their next hello.
check(sharing:Get("reactions") == true, "reactions are on with sharing")
check(Chronicle.Reaction(theirs) == "sad" and Chronicle.REACTIONS.level == "cheer" and Chronicle.REACTIONS.boss == "strong"
    and Chronicle.REACTIONS.skill == "clap" and Chronicle.REACTIONS.item == "cheer" and Chronicle.REACTIONS.zone == nil,
    "each kind has its reaction; arriving in a zone has none")
do -- the sets to choose from: the default first, every picture there, no cheering at a death
    local ok = true
    for kind, set in pairs(Chronicle.REACTION_SETS) do
        ok = ok and set[1] == Chronicle.REACTIONS[kind] and #set >= 2 and #set <= 4
        for _, reaction in ipairs(set) do
            ok = ok and ns.UI.media[reaction] ~= nil and Chronicle.IsReaction(reaction, kind)
                and ns.L["c_reaction_" .. reaction] ~= nil and ns.L["c_reacted_" .. reaction] ~= nil
        end
    end
    check(ok, "every kind's set starts with its default, has two to four, and each has a picture and its texts")
    local death = Chronicle.REACTION_SETS.death
    local cheering = false
    for _, reaction in ipairs(death) do
        cheering = cheering or reaction == "cheer" or reaction == "clap" or reaction == "fire"
    end
    check(not cheering and Chronicle.IsReaction("heart", "death") and not Chronicle.IsReaction("cheer", "death")
        and Chronicle.ReactionChoices(theirs) == death, "a death gets comfort and courage, no cheering or applause")
    -- Received to own entries: each person once (their newest), the most given
    -- first, a tie in the order of the set, an unknown reaction as the default.
    local groups = Chronicle.ReactionGroups({ { k = "level", r = { Ann = "clap", Bob = "cheer" } } })
    check(#groups == 2 and groups[1].reaction == "cheer" and groups[2].reaction == "clap",
        "a tie goes in the order of the kind's set")
    groups = Chronicle.ReactionGroups({
        { k = "level", r = { Ann = "clap", Bob = "clap" } },
        { k = "level", r = { Ann = "cheer", Cid = "fireworks", Dan = "cheer" } },
    })
    check(#groups == 2 and groups[1].reaction == "cheer" and table.concat(groups[1].names, ",") == "Cid,Dan"
        and groups[2].reaction == "clap" and table.concat(groups[2].names, ",") == "Ann,Bob",
        "counted once per person, their newest; one this version does not know counts as the default")
end
check(Chronicle.Reaction({ k = "friendLevel", who = "Jaina Proudmoore", t = 1 }) == nil and Chronicle.Reaction({ k = "level", t = 1 }) == nil,
    "neither a level seen on the friends list nor one of the player's own can be reacted to")
Chronicle.React(theirs, true)
mock.Advance(3)
check(theirs.mine == "sad" and Chronicle.ReactionUntold(theirs) and #mock.sent == 0,
    "a reaction to a friend who is offline is kept, untold")
jaina.connected = true -- she comes back
mock.Fire("FRIENDLIST_UPDATE")
mock.Advance(1)
mock.sent = {}
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~H~" .. time(), "WHISPER", "Jaina Proudmoore")
mock.Advance(2)
do
    local told
    for _, message in ipairs(mock.sent) do
        told = told or (message.target == "Jaina Proudmoore" and message.text == "1~X~" .. sharedNow .. "~death~sad~")
    end
    check(told and theirs.told == "sad" and not Chronicle.ReactionUntold(theirs),
        "at her hello it goes out, and counts as told")
end
mock.sent = {}
Chronicle.React(theirs, false)
mock.Advance(1)
Chronicle.React(theirs, true)
mock.Advance(3)
check(#mock.sent == 0, "taken back and given again within two seconds, nothing goes out")
Chronicle.React(theirs, "heart")
mock.Advance(3)
check(theirs.mine == "heart" and #mock.sent == 1 and mock.sent[1].text == "1~X~" .. sharedNow .. "~death~heart~",
    "another of the set replaces the one given, and goes out: " .. tostring(mock.sent[1] and mock.sent[1].text))
mock.sent = {}
Chronicle.React(theirs, "cheer")
check(theirs.mine == "heart", "one not of the kind's set is not given")
Chronicle.React(theirs, true)
mock.Advance(3)
check(theirs.mine == "sad" and #mock.sent == 1, "the default again replaces it as well")
mock.sent = {}
Chronicle.React(theirs, false)
mock.Advance(1)
check(#mock.sent == 0, "a click goes out two seconds later")
mock.Advance(2)
check(#mock.sent == 1 and mock.sent[1].text == "1~X~" .. sharedNow .. "~death~~" and theirs.told == nil and theirs.mine == nil,
    "taking it back tells her so, at once while she is online: " .. tostring(mock.sent[1] and mock.sent[1].text))
do -- two entries of one second are told apart
    mock.sent = {}
    local mining = { who = "Jaina Proudmoore", skill = 186, name = "Mining", rank = 150, t = sharedNow - 5 }
    Chronicle.Add("skill", mining)
    Chronicle.React(mining, true)
    mock.Advance(3)
    check(#mock.sent == 1 and mock.sent[1].text == "1~X~" .. (sharedNow - 5) .. "~skill~clap~rank=150;skill=186",
        "a reaction names what tells the entry apart: " .. tostring(mock.sent[1] and mock.sent[1].text))
end

-- Received: a friend's reaction to one of the player's own entries.
do
    local ownLevel
    for _, entry in ipairs(Chronicle.Entries()) do
        if entry.k == "level" and not entry.who and entry.level == 14 then
            ownLevel = entry
        end
    end
    local function react(text, sender)
        mock.Fire("CHAT_MSG_ADDON", "Famulus", text, "WHISPER", sender or "Jaina Proudmoore")
    end
    local at = ownLevel and ownLevel.t or 0
    ns.UI.Feed.Clear()
    react("1~X~" .. at .. "~level~cheer~")
    check(ownLevel and ownLevel.r and ownLevel.r["Jaina Proudmoore"] == "cheer" and Chronicle.Reactions(ownLevel)[1] == "Jaina Proudmoore",
        "a friend's reaction to an own entry is kept with it, by name")
    local card = ns.UI.Feed.Shown()[1]
    check(card and card.head:GetText() == "Jaina Proudmoore" and card.title:GetText() == "Celebrates with you"
        and card.detail:GetText():find("Reached level 14", 1, true) == 1
        and card.icon:IsShown() and not card.react:IsShown(), "and appears on screen: who, and to what; a reaction cannot be reacted to")
    react("1~X~" .. at .. "~level~cheer~", "Some Stranger")
    react("1~X~" .. (at + 1) .. "~level~cheer~")
    react("1~X~" .. at .. "~zone~cheer~")
    check(#Chronicle.Reactions(ownLevel) == 1, "not from strangers, not to an entry that is not there, not to a kind without reactions")
    react("1~X~" .. at .. "~level~fireworks~")
    check(ownLevel.r["Jaina Proudmoore"] == "cheer", "a reaction this version does not know counts as the kind's own")
    react("1~X~" .. at .. "~level~clap~")
    check(ownLevel.r["Jaina Proudmoore"] == "clap", "another of the kind's set is kept as it is")
    react("1~X~" .. at .. "~level~sad~")
    check(ownLevel.r["Jaina Proudmoore"] == "cheer", "one not of the kind's set counts as the kind's own")
    check(#ns.UI.Feed.Shown() == 1 and ownLevel.heard and ownLevel.heard["Jaina Proudmoore"],
        "a reaction changed to another is not news again: one card on screen for her")
    react("1~X~" .. at .. "~level~~")
    check(ownLevel.r == nil, "taken back, it is gone")
    react("1~X~" .. at .. "~level~clap~")
    check(ownLevel.r["Jaina Proudmoore"] == "clap" and #ns.UI.Feed.Shown() == 1,
        "taken back and given again, it is kept but not shown again")
    Chronicle.Receive(at, "level", {}, "Mira Stormfeather", "cheer") -- (not online here: straight in)
    mock.Advance(1.5) -- (the new card waits its turn behind the one on top)
    check(#ns.UI.Feed.Shown() == 2, "another friend's first reaction to it is news: " .. #ns.UI.Feed.Shown())
    react("1~X~" .. at .. "~level~~")
    Chronicle.Receive(at, "level", {}, "Mira Stormfeather", nil)
    ns:SetOption("sharing", "reactions", false)
    react("1~X~" .. at .. "~level~cheer~")
    check(ownLevel.r == nil, "with reactions switched off, none is taken")
    ns:SetOption("sharing", "reactions", true)
    -- Two own entries of one second: the reaction finds the one it names.
    local tailoring = { skill = 197, name = "Tailoring", rank = 75, t = at - 2 }
    local mining = { skill = 186, name = "Mining", rank = 75, t = at - 2 }
    Chronicle.Add("skill", tailoring)
    Chronicle.Add("skill", mining)
    react("1~X~" .. (at - 2) .. "~skill~clap~rank=75;skill=186")
    check(mining.r and mining.r["Jaina Proudmoore"] == "clap" and tailoring.r == nil, "of two entries in one second, the one named")
    mock.Advance(10)
    mock.sent = {}
end
jaina.connected = true

-- What comes in is checked: an entry keeps the time its friend wrote, one from
-- the future is not taken, a number is digits only, and a level-up is told once.
do
    local Feed = ns.UI.Feed
    local entriesBefore, profileBefore = FamulusDB.chronicle.entries, Chronicle.Profile("Jaina Proudmoore")
    FamulusDB.chronicle.entries = {}
    Feed.Clear()
    local function tell(text)
        mock.Fire("CHAT_MSG_ADDON", "Famulus", text, "WHISPER", "Jaina Proudmoore")
    end
    local function cards()
        return #Feed.Shown() + #Feed.Waiting()
    end

    -- A new friend's history: older than any limit, and not news.
    local now = time()
    local old = now - 100 * 86400
    tell("1~E~" .. old .. "~level~level=5;zone=Elwynn Forest")
    tell("1~E~" .. (old + 3600) .. "~level~level=6;zone=Elwynn Forest")
    local entries = Chronicle.Entries()
    check(#entries == 2 and entries[1].t == old and entries[1].level == 5 and entries[2].t == old + 3600 and entries[2].level == 6,
        "old news of a friend keeps its own time, every entry of it")
    check(cards() == 0, "and is not announced as new")
    tell("1~E~" .. old .. "~level~level=5;zone=Elwynn Forest")
    check(#Chronicle.Entries() == 2, "arriving again, it is known")

    -- Her clock runs an hour ahead of this one.
    local ahead = now + 3600
    tell("1~E~" .. ahead .. "~death~level=20;zone=Duskwood")
    check(#Chronicle.Entries() == 2 and Chronicle.NewestFrom("Jaina Proudmoore") == old + 3600,
        "an entry from the future is not taken, and the mark her next hello answers to stays")
    local realTime = time
    time = function(when)
        return when and realTime(when) or ahead
    end
    tell("1~E~" .. ahead .. "~death~level=20;zone=Duskwood")
    tell("1~E~" .. ahead .. "~death~level=20;zone=Duskwood")
    time = realTime
    entries = Chronicle.Entries()
    check(#entries == 3 and entries[3].t == ahead, "once its time has come it is taken, once, with its own time")

    -- Numbers are digits only: tonumber would read these as well.
    for _, bad in ipairs({ "nan", "inf", "1e9", "0x6B0D3D00", "-5", "12345678901", "" }) do
        tell("1~E~" .. bad .. "~death~level=20;zone=Westfall")
    end
    check(#Chronicle.Entries() == 3, "an entry whose time is not plain digits is not taken")
    tell("1~E~" .. (now - 60) .. "~zone~level=1e999;zone=Westfall")
    entries = Chronicle.Entries()
    check(#entries == 4 and entries[3].t == now - 60 and entries[3].zone == "Westfall" and entries[3].level == nil,
        "a field that is not plain digits is left out")
    tell("1~S~1e999~60=12;107=99999999999")
    local profile = Chronicle.Profile("Jaina Proudmoore")
    check(profile.level == 0 and profile.stats[60] == 12 and profile.stats[107] == nil, "and so it is in the statistics")
    FamulusDB.chronicle.profiles["Jaina Proudmoore"] = profileBefore

    -- "Follow my friends" and sharing both on: the friends list shows the
    -- level-up she tells of herself.
    FamulusDB.chronicle.entries = {}
    enable("companions")
    local at = time() - 30
    tell("1~E~" .. at .. "~level~level=21;zone=Duskwood")
    jaina.level = 21
    mock.Fire("FRIENDLIST_UPDATE")
    entries = Chronicle.Entries()
    check(#entries == 1 and entries[1].k == "level" and Chronicle.FriendLevel("Player-1-FRIEND") == 21,
        "a level-up a friend told of is not written again when the friends list shows it")
    jaina.level = 22
    mock.Fire("FRIENDLIST_UPDATE")
    entries = Chronicle.Entries()
    check(#entries == 2 and entries[2].k == "friendLevel" and entries[2].level == 22
        and Chronicle.NewestFrom("Jaina Proudmoore") == at,
        "one only the friends list shows is written, and does not move the mark her hello answers to")
    Feed.Clear()
    tell("1~E~" .. (at + 10) .. "~level~level=22;zone=Duskwood")
    entries = Chronicle.Entries()
    check(#entries == 2 and entries[2].k == "level" and entries[2].t == at + 10 and cards() == 0,
        "her own account of it then takes its place, and is no news a second time")
    enable("companions", false)
    jaina.level = 20
    Chronicle.FriendLevel("Player-1-FRIEND", 20)

    FamulusDB.chronicle.entries = entriesBefore
    Feed.Clear()
end

-- A lost entry is asked for again (an entry names the time of the one before
-- it), someone the player ignores is not heard, and of fresh entries only a
-- few at once are taken from one sender.
do
    local entriesBefore = FamulusDB.chronicle.entries
    FamulusDB.chronicle.entries = {}
    mock.Advance(10)
    mock.sent = {}
    local function tell(text)
        mock.Fire("CHAT_MSG_ADDON", "Famulus", text, "WHISPER", "Jaina Proudmoore")
    end
    local at = time() - 600
    tell("1~E~" .. at .. "~level~level=30;zone=Duskwood")
    tell("1~E~" .. (at + 60) .. "~death~level=30;zone=Duskwood;p=" .. at)
    check(#Chronicle.Entries() == 2, "an entry that names the one before it is taken while we have that one")
    tell("1~E~" .. (at + 180) .. "~zone~level=30;zone=Westfall;p=" .. (at + 120))
    mock.Advance(1)
    check(#Chronicle.Entries() == 2 and #mock.sent == 1 and mock.sent[1].text == "1~H~" .. (at + 60),
        "one that names an entry we lack is not taken, and a hello asks again from where we are: "
        .. tostring(mock.sent[1] and mock.sent[1].text))
    tell("1~E~" .. (at + 120) .. "~level~level=31;zone=Duskwood;p=" .. (at + 60))
    tell("1~E~" .. (at + 180) .. "~zone~level=31;zone=Westfall;p=" .. (at + 120))
    check(#Chronicle.Entries() == 4 and Chronicle.NewestFrom("Jaina Proudmoore") == at + 180,
        "what she sends then closes the gap")
    -- What she names may be something this version cannot keep: asked once.
    mock.sent = {}
    tell("1~E~" .. (at + 300) .. "~zone~level=31;zone=Tanaris;p=" .. (at + 240))
    check(#Chronicle.Entries() == 4, "a gap that stays is asked about")
    tell("1~E~" .. (at + 300) .. "~zone~level=31;zone=Tanaris;p=" .. (at + 240))
    mock.Advance(1)
    check(#Chronicle.Entries() == 5 and #mock.sent == 1, "once: the second time the entry is taken as it comes")
    -- The hello may have reached her during a boss fight: a minute later it goes once more.
    mock.sent = {}
    local lost = "1~E~" .. (at + 500) .. "~zone~level=31;zone=Feralas;p=" .. (at + 400)
    tell(lost)
    mock.Advance(61)
    tell(lost)
    mock.Advance(1)
    check(#Chronicle.Entries() == 5 and #mock.sent == 2, "a gap still there a minute later is asked about a second time (sent " .. #mock.sent .. ")")
    tell(lost)
    mock.Advance(1)
    check(#Chronicle.Entries() == 6 and #mock.sent == 2, "and no third time: then the entry is taken")

    -- What was passed on first and then comes from her counts as hers.
    FamulusDB.chronicle.entries = {}
    tell("1~E~" .. at .. "~level~level=30;zone=Duskwood")
    Chronicle.Add("death", { who = "Jaina Proudmoore", via = "Thrall Hellscream", t = at + 60, level = 30, zone = "Duskwood" })
    Chronicle.Add("level", { who = "Jaina Proudmoore", via = "Thrall Hellscream", t = at + 120, level = 31 })
    mock.Advance(1)
    mock.sent = {}
    tell("1~E~" .. (at + 60) .. "~death~level=30;zone=Duskwood;p=" .. at)
    tell("1~E~" .. (at + 120) .. "~level~level=31;p=" .. (at + 60))
    mock.Advance(1)
    do
        local entries = Chronicle.Entries()
        check(#entries == 3 and entries[2].via == nil and entries[3].via == nil
            and Chronicle.NewestFrom("Jaina Proudmoore") == at + 120 and #mock.sent == 0,
            "an entry passed on before and now told by her is hers: the mark moves with it, and nothing is asked again")
        Chronicle.Add("zone", { who = "Jaina Proudmoore", via = "Thrall Hellscream", t = at + 120, zone = "Tanaris" })
        Chronicle.Add("friendLevel", { who = "Jaina Proudmoore", level = 31 })
        check(Chronicle.Entries()[3].via == nil and Chronicle.Entries()[4].via == "Thrall Hellscream",
            "what is only passed on, or only seen on the friends list, makes nothing hers")
    end

    -- The player's own entries say what came before them.
    FamulusDB.chronicle.entries = {}
    mock.sent = {}
    Chronicle.Add("skill", { skill = 186, name = "Mining", rank = 75 })
    Chronicle.Add("skill", { skill = 186, name = "Mining", rank = 150 })
    mock.Advance(1)
    local own = Chronicle.Entries()
    check(#mock.sent == 2 and not mock.sent[1].text:find("p=", 1, true)
        and mock.sent[2].text == "1~E~" .. own[2].t .. "~skill~name=Mining;rank=150;skill=186;p=" .. own[1].t,
        "an own entry goes out with the time of the one before it, the first without: " .. tostring(mock.sent[2] and mock.sent[2].text))
    check(sharing.EncodeEntry({ k = "boss", t = 1, name = string.rep("n", 60), zone = string.rep("z", 60),
        instance = string.rep("i", 60), id = 12345, first = 1 }, nil, 1795000000):find("p=", 1, true) ~= nil
        and #sharing.EncodeEntry({ k = "boss", t = 1795000000, name = string.rep("n", 60), zone = string.rep("z", 60),
            instance = string.rep("i", 60), id = 1234567890, first = 1234567890 }, nil, 1795000000) <= 255,
        "and never grows past what a message holds")
    mock.Advance(10)
    mock.sent = {}

    -- Someone the player ignores is not heard.
    FamulusDB.chronicle.entries = {}
    mock.state.ignored = { ["Jaina Proudmoore"] = true }
    tell("1~E~" .. at .. "~level~level=30;zone=Duskwood")
    check(#Chronicle.Entries() == 0, "nothing is taken from someone on the player's ignore list")
    mock.state.ignored = nil

    -- Fresh entries: a few at once from one sender, old ones however many.
    mock.Advance(61) -- (past what she sent before)
    local fresh = time() - 20
    for index = 1, 12 do
        tell("1~E~" .. (fresh + index) .. "~zone~level=30;zone=Fresh " .. index)
    end
    check(#Chronicle.Entries() == 8, "of fresh entries only eight at once are taken from one sender (got " .. #Chronicle.Entries() .. ")")
    for index = 1, 12 do
        tell("1~E~" .. (at + index) .. "~zone~level=30;zone=Old " .. index)
    end
    check(#Chronicle.Entries() == 20, "what is not fresh is taken, however much")
    mock.Advance(61)
    tell("1~E~" .. (fresh + 12) .. "~zone~level=30;zone=Fresh 12")
    check(#Chronicle.Entries() == 21, "a minute later fresh ones are taken again")
    mock.Advance(61)

    FamulusDB.chronicle.entries = entriesBefore
    ns.UI.Feed.Clear()
    mock.sent = {}
end

-- The live feed: a friend's card on screen has a button that reacts to it
-- right there, as a click on their card in the chronicle does.
do
    local Feed = ns.UI.Feed
    Feed.Clear()
    mock.Advance(3)
    mock.sent = {}
    local function sent()
        local texts = {}
        for _, message in ipairs(mock.sent) do
            texts[#texts + 1] = tostring(message.text)
        end
        return table.concat(texts, " | ")
    end
    local function find(kind, at)
        for _, entry in ipairs(Chronicle.Entries()) do
            if entry.k == kind and entry.who == "Jaina Proudmoore" and entry.t == at then
                return entry
            end
        end
    end
    local at = time() - 1
    mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~E~" .. at .. "~boss~id=7;name=Hogger;zone=Elwynn Forest", "WHISPER", "Jaina Proudmoore")
    local boss = find("boss", at)
    local card = Feed.Shown()[1]
    local button = card and card.react
    check(boss and button and button:IsShown() and button.mouseEnabled and not card.mouseEnabled
        and button.ground.fill.token == "control",
        "a friend's card on screen has a button to react; only the button catches the mouse")
    check(card.title:GetWidth() <= card:GetWidth() - 76 - 16 - 32, "the text keeps clear of the button")
    GameTooltip:Hide()
    GameTooltip:SetText("")
    button.scripts.OnEnter(button)
    button.scripts.OnClick(button)
    check(boss.mine == "strong" and button.ground.fill.token == "accentDeep",
        "a click reacts with the kind's reaction and lights the button up")
    check(not GameTooltip:IsShown() and GameTooltip:GetText() == "", "the button has no tooltip: the click and its light say enough")
    button.scripts.OnClick(button)
    check(boss.mine == "strong", "a second click takes nothing back: that is the chronicle's")
    mock.Advance(0.8)
    check(Feed.Shown()[1] == card and card:IsShown() and card:GetAlpha() == 1, "the card stays a moment, to see the reaction")
    mock.Advance(1)
    check(#Feed.Shown() == 0 and not card:IsShown(), "then it closes, though the mouse is still on it")
    mock.Advance(1.5)
    check(#mock.sent == 1 and mock.sent[1].text == "1~X~" .. at .. "~boss~strong~" and boss.told == "strong",
        "and the reaction goes to the friend as from the chronicle: " .. sent())
    mock.sent = {}
    Chronicle.React(boss, false) -- as a second click on the card in the chronicle
    mock.Advance(3)
    check(#mock.sent == 1 and mock.sent[1].text == "1~X~" .. at .. "~boss~~", "taken back in the chronicle, she is told so: " .. sent())

    -- While the mouse is on the button the card stays.
    mock.sent = {}
    at = time() - 1
    mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~E~" .. at .. "~level~level=21;zone=Duskwood", "WHISPER", "Jaina Proudmoore")
    card = Feed.Shown()[1]
    button = card.react
    check(button:IsShown() and find("level", at) ~= nil, "a friend's level-up has the button as well")
    button.scripts.OnEnter(button)
    mock.Advance(8)
    check(Feed.Shown()[1] == card and card:IsShown() and card:GetAlpha() == 1,
        "while the mouse is on the button, the card stays beyond its time")
    button.scripts.OnLeave(button)
    mock.Advance(1)
    check(card:IsShown(), "and a moment longer once the mouse has left")
    mock.Advance(1.2)
    check(#Feed.Shown() == 0 and not card:IsShown() and not button.over, "then it goes")

    -- A card that is already fading comes back under the mouse. (Another
    -- second: two level-ups of one person in one second count as one. One
    -- before the last, not by the clock: time() is the real one, and a new
    -- second between the two could make both the same.)
    at = at - 1
    mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~E~" .. at .. "~level~level=22;zone=Duskwood", "WHISPER", "Jaina Proudmoore")
    card = Feed.Shown()[1]
    button = card.react
    mock.Advance(7.2)
    check(card:IsShown() and card:GetAlpha() < 1, "(the card is fading)")
    button.scripts.OnEnter(button)
    mock.Advance(4)
    check(card:IsShown() and card:GetAlpha() == 1, "a fading card comes back when the mouse is on its button")
    button.scripts.OnLeave(button)
    mock.Advance(2.1)
    check(#Feed.Shown() == 0, "and goes once the mouse has left")
    check(find("level", at).mine == nil and #mock.sent == 0, "pointing alone reacts to nothing: " .. sent())

    -- A right-click (or holding it) opens the bar; the card stays while it is open.
    do
        local Picker = ns.UI.ReactionPicker
        at = at - 1
        mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~E~" .. at .. "~level~level=23;zone=Duskwood", "WHISPER", "Jaina Proudmoore")
        card = Feed.Shown()[1]
        button = card.react
        button.scripts.OnEnter(button)
        button.scripts.OnClick(button, "RightButton")
        local options, bar = Picker.Shown()
        check(Picker.IsOpenFor(button) and #options == 3 and options[1].reaction == "cheer" and options[3].reaction == "strong"
            and find("level", at).mine == nil, "a right-click opens the level-up's set and gives nothing")
        button.scripts.OnLeave(button)
        bar.mouseOver, options[3].mouseOver = true, true -- (the mouse goes over to the bar)
        options[3].scripts.OnEnter(options[3])
        mock.Advance(9)
        check(card:IsShown() and card:GetAlpha() == 1 and Picker.IsOpenFor(button), "while the bar is open, the card stays")
        mock.Click(options[3])
        bar.mouseOver, options[3].mouseOver = nil, nil
        check(find("level", at).mine == "strong" and button.ground.fill.token == "accentDeep" and button.reactionIcon == "strong"
            and not Picker.IsOpenFor(button), "a choice gives it, the button shows it lit")
        mock.Advance(1.8)
        check(not card:IsShown(), "and the card goes as after a click")
        mock.Advance(3)
        check(#mock.sent == 1 and mock.sent[1].text == "1~X~" .. at .. "~level~strong~", "it goes to her: " .. sent())
        mock.sent = {}
        -- Closed without a choice, a card past its time goes a moment later.
        at = at - 1
        mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~E~" .. at .. "~level~level=24;zone=Duskwood", "WHISPER", "Jaina Proudmoore")
        card = Feed.Shown()[1]
        button = card.react
        button.scripts.OnEnter(button)
        button.scripts.OnMouseDown(button, "LeftButton")
        mock.Advance(0.5)
        button.scripts.OnMouseUp(button, "LeftButton")
        check(not Picker.IsOpenFor(button), "pressed and dragged off the button, no bar opens with the mouse elsewhere")
        button.mouseOver = true
        button.scripts.OnMouseDown(button, "LeftButton")
        mock.Advance(0.5)
        button.scripts.OnMouseUp(button, "LeftButton")
        button.scripts.OnClick(button, "LeftButton")
        check(Picker.IsOpenFor(button) and find("level", at).mine == nil, "held, the bar opens and the click gives nothing")
        button.mouseOver = nil
        button.scripts.OnLeave(button)
        mock.Advance(9)
        check(not Picker.IsOpenFor(button) and not card:IsShown() and find("level", at).mine == nil,
            "left alone, the bar closes and the card goes")
        Feed.Clear()
    end

    -- With reactions switched off there is no button. (A second before her
    -- death above, not one by the clock: one death of one person in one
    -- second counts as one, and time() - 1 is that second once a real
    -- second has passed since.)
    ns:SetOption("sharing", "reactions", false)
    at = sharedNow - 1
    mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~E~" .. at .. "~death~level=21;zone=Duskwood", "WHISPER", "Jaina Proudmoore")
    check(#Feed.Shown() == 1 and not Feed.Shown()[1].react:IsShown(), "with reactions switched off, a friend's card has no button")
    ns:SetOption("sharing", "reactions", true)
    Feed.Clear()

    -- The sample cards show the button too; it lights up and sends nothing.
    SlashCmdList.FAMULUS("feed test")
    card = Feed.Shown()[1]
    button = card.react
    check(button:IsShown(), "/fam feed test shows the button to react")
    button.scripts.OnClick(button)
    check(button.ground.fill.token == "accentDeep", "on the sample card it lights up")
    mock.Advance(1.6)
    check(not card:IsShown(), "and the card closes")
    -- The samples' friends come one after another: the boss two of them
    -- defeated (one card, no button: whose would it be?), then a death.
    mock.Advance(0.6)
    local friend = Feed.Shown()[1]
    check(friend.react:IsShown() and not Feed.Shown()[2].react:IsShown(), "a sample friend's card has the button as well")
    friend.react.scripts.OnClick(friend.react)
    check(friend.react.ground.fill.token == "accentDeep", "it lights up")
    mock.Advance(3)
    check(#mock.sent == 0, "and nothing is sent: " .. sent())
    Feed.Clear()
    mock.Advance(10)
    mock.sent = {}
end

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
do -- what is passed on goes oldest first and in rounds, as the own entries do
    local entriesBefore = FamulusDB.chronicle.entries
    FamulusDB.chronicle.entries = {}
    local base = time() - 9000
    for index = 1, 25 do
        Chronicle.Add("zone", { who = "Varian Wrynn", t = base + index, zone = "Zone " .. index })
    end
    mock.Advance(2)
    mock.sent = {}
    mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~W~Varian Wrynn~0", "WHISPER", "Thrall Hellscream")
    mock.Advance(20)
    local passed = {}
    for _, message in ipairs(mock.sent) do
        if message.text:find("^1~R~Varian Wrynn~") then
            passed[#passed + 1] = message.text
        end
    end
    check(#passed == 25 and passed[1]:find("zone=Zone 1$") ~= nil and passed[20]:find("zone=Zone 20$") ~= nil
        and passed[21]:find("zone=Zone 21$") ~= nil and passed[25]:find("zone=Zone 25$") ~= nil,
        "more than a round of someone's news is passed on in full, oldest first (got " .. #passed .. ")")

    -- Hellos in a row share one reading of the statistics; an own event reads them anew.
    FamulusDB.chronicle.entries = {}
    mock.Advance(31)
    local scans, list = 0, GetStatisticsCategoryList
    GetStatisticsCategoryList = function(...)
        scans = scans + 1
        return list(...)
    end
    mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~H~" .. time(), "WHISPER", "Thrall Hellscream")
    mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~H~" .. time(), "WHISPER", "Thrall Hellscream")
    check(scans == 1, "two hellos in a row are answered from one reading of the statistics (got " .. scans .. ")")
    Chronicle.Add("zone", { zone = "Somewhere New", level = 13 })
    mock.Advance(6)
    check(scans == 2, "after an own event they are read anew, so its count is in them (got " .. scans .. ")")
    GetStatisticsCategoryList = list
    mock.Advance(5)
    mock.sent = {}
    FamulusDB.chronicle.entries = entriesBefore
end
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

-- In developer mode every step of the exchange goes into the trace, a
-- person as a tag, never by name.
enable("sharing", false)
check(FamulusDB.devTrace == nil, "without developer mode nothing is traced")
ns:SetDevMode(true)
-- A new session: out of a guild for a moment, so no roster from the tests before is kept.
setState({})
ns.SocialService.EachGuildMember(function() end)
setState({ friends = {}, zone = "Westfall", level = 13, units = { player = { name = "Boris", surname = "Bloom" } },
    guild = {}, statistics = { [60] = "13" } })
enable("sharing")
mock.state.guild = { { name = "Boris Bloom-Forever", online = true }, { name = "Arisa Werkatz-Forever", online = true } }
mock.Fire("GUILD_ROSTER_UPDATE")
mock.Advance(2)
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~P", "GUILD", "Boris Bloom-Forever")
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~P", "GUILD", "Arisa Werkatz-Forever")
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~H~0", "WHISPER", "Some Stranger")
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~E~1~level", "GUILD", "Arisa Werkatz-Forever")
mock.Fire("CHAT_MSG_ADDON", "Famulus", "2~H~0", "WHISPER", "Arisa Werkatz")
mock.Advance(2)
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~H~0", "WHISPER", "Arisa Werkatz")
mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~S~14~60=29~DRUID", "WHISPER", "Arisa Werkatz")
mock.Advance(30)
do
    local arisa, stranger = sharing.Tag(sharing.Key("Arisa Werkatz")), sharing.Tag(sharing.Key("Some Stranger"))
    local lines, named = {}, false
    for _, line in ipairs(FamulusDB.devTrace or {}) do
        lines[#lines + 1] = line
        named = named or line.text:find("Arisa", 1, true) or line.text:find("Werkatz", 1, true)
            or line.text:find("Stranger", 1, true) or line.text:find("Bloom", 1, true)
    end
    local function traced(text, minimum)
        for _, line in ipairs(lines) do
            if line.text == text and (line.n or 1) >= (minimum or 1) then
                return true
            end
        end
        return false
    end
    check(arisa:find("^AW%-%x%x%x$") ~= nil and arisa == sharing.Tag(sharing.Key("Arisa Werkatz-Forever")),
        "a person is traced as initials and a number from their name, the same in any spelling: " .. arisa)
    check(lines[1] and lines[1].kind == "SESSION" and traced("switched on"), "the trace begins with the session")
    check(traced("guild roster: 0 members, 0 online (empty, though in a guild)") and traced("guild roster: 2 members, 2 online"),
        "it notes the guild roster when it changes, an empty one too")
    check(traced("guild greeting queued") and traced("sent P to guild") and traced("own guild greeting came back from the guild channel"),
        "the guild greeting is traced from the queue to its echo")
    check(traced("got P from " .. arisa) and traced("hello to " .. arisa .. " queued: their guild greeting") and traced("sent H to " .. arisa),
        "a guild greeting received is traced with the hello it is answered with")
    check(traced("ignored H from " .. stranger .. ": neither a friend online nor in the guild")
        and traced("ignored E from " .. arisa .. ": came by GUILD") and traced("ignored H from " .. arisa .. ": version 2"),
        "what is ignored is traced with the reason")
    check(traced("first contact with " .. arisa .. ": linked") and traced("got S from " .. arisa),
        "the first contact and what arrives are traced")
    check(traced("sent E to " .. arisa, 2) and traced("catching up " .. arisa .. " after the start: 20 own entries, more follow"),
        "the same line in a row counts up instead of repeating, and catching up says how far")
    check(not named, "no name of a player is stored in the trace")
end
-- The client may hand over an empty guild roster for a moment (issue #51). The last one stands
-- in for it, so a guild member who greets the guild then is still taken and answered.
do
    mock.state.guild = { { name = "Boris Bloom-Forever", online = true }, { name = "Arisa Werkatz-Forever", online = true },
        { name = "Mel Sternlicht-Forever", online = true, guid = "Player-1-MEL" } }
    mock.Fire("GUILD_ROSTER_UPDATE")
    mock.state.guild = {}
    mock.Fire("GUILD_ROSTER_UPDATE")
    local mel = sharing.Tag(sharing.Key("Mel Sternlicht"))
    mock.sent = {}
    mock.Fire("CHAT_MSG_ADDON", "Famulus", "1~P", "GUILD", "Mel Sternlicht-Forever")
    mock.Advance(2)
    local function traced(text)
        for _, line in ipairs(FamulusDB.devTrace or {}) do
            if line.text == text then
                return true
            end
        end
        return false
    end
    check(traced("guild roster came empty, keeping the last one: 3 members, 3 online"),
        "an empty guild roster keeps the last one, and the trace says so")
    check(traced("hello to " .. mel .. " queued: their guild greeting") and sentTo("Mel Sternlicht") ~= nil
        and not traced("ignored P from " .. mel .. ": neither a friend online nor in the guild"),
        "a guild member who greets the guild while the roster is empty is answered, not taken for a stranger")
    check(ns.SocialService.Online()("Arisa Werkatz") ~= nil, "who was online stays online while the roster is kept")
    -- A roster whose names cannot be read keeps the last one as well.
    mock.state.guild = { { name = mock.SECRET, online = true } }
    local names = {}
    check(ns.SocialService.EachGuildMember(function(name) names[#names + 1] = name end) == true and #names == 3,
        "a roster that names nobody keeps the last one too")
    -- A roster that names somebody again takes over; out of the guild, nothing is kept.
    mock.state.guild = { { name = "Boris Bloom-Forever", online = true } }
    mock.Fire("GUILD_ROSTER_UPDATE")
    check(traced("guild roster: 1 members, 1 online") and ns.SocialService.Online()("Arisa Werkatz") == nil,
        "a roster that names somebody replaces the kept one")
    mock.state.guild = nil
    ns.SocialService.EachGuildMember(function() end)
    mock.state.guild = {}
    local seen = 0
    check(ns.SocialService.EachGuildMember(function() seen = seen + 1 end) == false and seen == 0,
        "after leaving the guild nothing is kept for the next one")
    mock.state.guild = { { name = "Boris Bloom-Forever", online = true }, { name = "Arisa Werkatz-Forever", online = true } }
    mock.Fire("GUILD_ROSTER_UPDATE")
end
ns:SetDevMode(false)
check(FamulusDB.devTrace == nil, "switching developer mode off clears the trace")
mock.addonThrottle = false
enable("sharing", false)
enable("ownJourney", false)
check(ns:CountRegisteredEvents() == eventsBeforeSharing and sharing.ticker == nil, "switched off, it neither listens nor sends")
FamulusDB.chronicle = nil
ns:Fire("CHRONICLE_CHANGED")
FamulusDB.chronicle = { entries = chronicleBeforeSharing, friends = {} }
setState(stateBeforeChronicle)

do -- a full chronicle keeps the player's own journey
    local saved, now = FamulusDB.chronicle, time()
    local entries = { { k = "level", t = now - 5000, level = 2 } }
    for i = 2, 1001 do
        entries[i] = { k = "death", t = now - 5000 + i, who = "Mira Sturmfeder" }
    end
    FamulusDB.chronicle = { entries = entries, friends = {} }
    Chronicle.Add("death", { who = "Borin Eisenbart" })
    check(#Chronicle.Entries() == 1001 and Chronicle.Entries()[1].k == "level" and Chronicle.Entries()[2].t == now - 4997,
        "news of others keeps to half the chronicle; then their oldest goes, not the player's own oldest entry")
    entries = {}
    for i = 1, 2000 do
        entries[i] = { k = "death", t = now - 5000 + i }
    end
    FamulusDB.chronicle = { entries = entries, friends = {} }
    Chronicle.Add("death", { who = "Borin Eisenbart" })
    check(#Chronicle.Entries() == 2000 and Chronicle.Entries()[1].t == now - 4998 and Chronicle.Entries()[2000].who == "Borin Eisenbart",
        "a chronicle full of the player's own entries still takes news of others; their oldest entry goes")
    FamulusDB.chronicle = saved
end

-- The page.
if not window:IsShown() then
    SlashCmdList.FAMULUS("")
end
mock.Click(navButton("Chronicle"))
mock.Click(tabButton("Everyone")) -- the page remembers the tab the window tests left it on
mock.Advance(0.1)
check(window.area.name:GetText() == "Chronicle" and tabButton("Everyone").selected and tabButton("Everyone") and tabButton("My journey") and tabButton("Friends") and tabButton("Settings"),
    "the chronicle has its own page: everyone, my journey, companions, recording")
check(navButton("Chronicle").count:GetText() == tostring(#ns.ChronicleService.Entries()), "the chronicle's card counts its entries: " .. tostring(navButton("Chronicle").count:GetText()))
-- The entries are told as a picture book: chapters, and events on a line.
-- A card's content is a frame of its own (event.content); the tests read
-- the card and its content as one.
-- The pictures of the settings draw a book of their own; it is not the page's.
local function inPicture(frame)
    local stage = window.detail and window.detail.stage
    while frame do
        if frame == stage then
            return true
        end
        frame = frame.parent
    end
    return false
end
local function bookFrames(field)
    local list = {}
    for _, frame in ipairs(mock.frames) do
        if frame[field] and frame:IsVisible() and not inPicture(frame) then
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
    and events[1].story.chip.text == "Jaina Proudmoore",
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
check(events[1].story.chip and events[1].story.chip.text == "Jaina Proudmoore" and events[1].story.chip.class == nil
    and events[1].chipText:GetText() == "Jaina Proudmoore" and events[1].foot == nil
    and events[2].strip:IsShown() and events[2].chipText:GetText() == (Chronicle.Character() or ""),
    "every card names whose event it is in its strip, not in the headline; the player's own name their character")
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
    check(same and events[2].title.mockPoint[5] == events[1].title.mockPoint[5],
        "the text keeps the same distance from the picture on every card, and begins below the strip on each")
end
check(events[4].card:GetWidth() < events[2].card:GetWidth() and events[2].card:GetWidth() < events[6].card:GetWidth()
    and events[6].card:GetWidth() == (window.book:GetWidth() - 44) / 2
    and events[4].card.mockPoint[1] == (events[4].onLeft and "TOPRIGHT" or "TOPLEFT"),
    "the book sets a card's width by its weight, and a narrower card keeps to the line")
check(events[1].strip:IsShown() and events[2].strip:IsShown() and events[1].picture.mockPoint[5] <= -28
    and events[1].time:IsShown() and events[1].time.mockPoint[1] == "RIGHT" and events[1].mark == nil
    and events[1].kindIcon == nil and events[1].chipText.mockPoint[1] == "LEFT"
    and events[1].dot:IsShown() and events[1].dot.glow:IsShown()
    and events[4].dot:GetWidth() < events[2].dot:GetWidth() and events[2].dot:GetWidth() < events[1].dot:GetWidth()
    and events[1].dot.glow:GetWidth() == events[1].dot:GetWidth() * 3,
    "the name stands in a sunken strip above the picture, the time at its right; on the line a glowing dot, larger with the weight")
do
    local level = true
    for index = 1, 6 do
        level = level and events[index].picture.mockPoint[5] == events[index].title.mockPoint[5]
    end
    check(level and events[2].picture.mockPoint[4] == ns.UI.BookPad and events[2].picture.mockPoint[5] == -(28 + ns.UI.BookPad - 1)
    and events[6].picture.mockPoint[5] == events[2].picture.mockPoint[5] and events[1].picture.mockPoint[5] == events[2].picture.mockPoint[5],
    "picture and text begin at the same height; the room inside the edge and below the strip is the book's, the same for every weight")
end
check(events[4].photo:IsShown() and not events[4].icon:IsShown() and not events[4].number:IsShown()
    and events[4].story.texture == ns.UI.gameIcons.death and events[4].story.title == "Fallen"
    and events[4].detail:GetText() == "at level 13" and events[4].time:GetText():match("^%d%d:%d%d$") ~= nil
    and events[4].place:GetText() == "Westfall" and events[4].place:IsShown()
    and events[5].story.title == "Discovered a new zone" and events[1].place:GetText() == "Duskwood"
    and not events[1].detail:IsShown() and events[2].time:GetText():match("^%d%d:%d%d$") ~= nil
    and not events[2].place:IsShown() and not events[2].react:IsShown(),
    "other events show an icon of the game; the strip tells the time, the foot the place alone, the text never the place")
do -- a text taller than the picture: the foot adds its line, without a place there is none
    local part = CreateFrame("Frame")
    local story = { kind = "death", weight = "low", title = string.rep("Fallen ", 8), when = "21:14" }
    local without = ns.UI.ChronicleCard(part, story, 222)
    story.place = "Duskwood"
    local with = ns.UI.ChronicleCard(part, story, 222)
    check(with - without == 18 and part.place:IsShown() and part.time:GetText() == "21:14",
        "without a place and a reaction, a card has no foot (" .. without .. " / " .. with .. ")")
end
do
    ns:SetOption("general", "timeFormat", "12h")
    mock.Advance(0.1)
    local twelve, head = bookFrames("story"), bookFrames("chapter")[1]
    check(twelve[4].time:GetText():match("^%d%d?:%d%d [AP]M$") ~= nil and twelve[4].place:GetText() == "Westfall"
        and head.chapter.small:find("^%d%d?:%d%d [AP]M") ~= nil,
        "on the 12-hour clock the book writes its times with AM and PM: " .. twelve[4].time:GetText() .. " / " .. head.chapter.small)
    ns:SetOption("general", "timeFormat", "24h")
    mock.Advance(0.1)
    check(bookFrames("story")[4].time:GetText():match("^%d%d:%d%d$") ~= nil, "and back on 24 hours")
end
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
do -- the class beside a companion's name in the rail, and the character name behind an alias
    local first = bookFrames("story")[1]
    check(first.chipClass == nil and first.chipText.mockPoint[4] == ns.UI.BookPad
        and people.rows[1].initial:IsShown() and not people.rows[1].class:IsShown(),
        "the book's strip names the person alone, without a class icon; while the class is not known the rail shows the initial")
    Chronicle.Class("Jaina Proudmoore", "MAGE")
    ns.AliasService.Set("Jaina Proudmoore", "Anna")
    mock.Advance(0.1)
    first = bookFrames("story")[1]
    local row = railCard("people").rows[1]
    check(first.chipText.mockPoint[4] == ns.UI.BookPad
        and row.class:IsShown() and not row.initial:IsShown() and not row.avatar:IsShown(),
        "a known class shows its icon in the rail; in the book's strip the name stays at the edge")
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
    check(Chronicle.Class("Jaina Proudmoore") == "PRIEST"
        and railCard("people").rows[1].class:IsShown() and not railCard("people").spec.people[1].online,
        "the guild roster tells the class of a member who is offline, shown at once in the rail")
    check(Chronicle.Class("Thrall Hellscream") == nil, "only of people the chronicle tells of")
    mock.state.guild = nil
    mock.state.friends = { { name = "Jaina Proudmoore", guid = "Player-1-JAINA", connected = true, level = 20, className = "Mage" } }
    mock.Click(tabButton("Friends"))
    check(Chronicle.Class("Jaina Proudmoore") == "MAGE" and railCard("brief").spec.online,
        "the friends list tells it of a friend who is online")
    mock.state.friends = {}
    mock.Click(tabButton("Everyone"))
    check(Chronicle.Class("Jaina Proudmoore") == "MAGE" and railCard("people").rows[1].class:IsShown(),
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
        and deaths.badge:IsShown() and deaths.badgeText:GetText() == "3"
        and deaths.time:GetText() == date("%H:%M", now - 52) .. " – " .. date("%H:%M", now - 50)
        and deaths.place:GetText() == "Duskwood",
        "deaths in one place: one card, how often in the corner, from the first time to the last in the strip")
    check(levels and levels.story.title == "Reached levels 21 to 22" and levels.number:GetText() == "22"
        and not levels.badge:IsShown() and levels.story.chip.text == "Jaina Proudmoore",
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
    do -- (the arrows start at index 2: the client's Lua counts no length for two or three of them)
        local stale = false
        for _, head in ipairs(chapters) do
            for index, arrow in pairs(head.arrows) do
                stale = stale or (head:IsVisible() and arrow:IsShown() and index > head.routeShown)
            end
        end
        check(not stale, "a chapter heading used again shows no arrows of its last route")
    end
    do -- a tween that ends may cancel one that began before it
        ns.UI.Tween("test-slide", 10, function() end)
        ns.UI.Tween("test-fade", 0.01, function(progress)
            if progress >= 1 then
                ns.UI.CancelTween("test-slide")
            end
        end)
        check(pcall(mock.Advance, 0.1), "a tween that ends and cancels an older one does not break the others")
    end
    do -- the reaction bar's buttons are sized for the button that opens it, never built anew
        local Picker = ns.UI.ReactionPicker
        local function owner(size, iconSize)
            local button = ns.UI.ReactionButton(UIParent, size, iconSize)
            Picker.Attach(button, function()
                return { choices = { "cheer", "clap", "fire" }, pick = function() end }
            end)
            return button
        end
        local function hold(button)
            button.mouseOver = true
            button.scripts.OnMouseDown(button, "LeftButton")
            mock.Advance(0.5)
            button.scripts.OnMouseUp(button, "LeftButton")
            button.mouseOver = nil
        end
        local big, small = owner(32, 18), owner(24, 14)
        hold(big)
        hold(small)
        local frames = #mock.frames
        hold(big)
        local options = Picker.Shown()
        local bigOpen = Picker.IsOpenFor(big) and options[1]:GetHeight() == 32 and options[1].icon:GetHeight() == 18
        hold(small)
        options = Picker.Shown()
        check(bigOpen and Picker.IsOpenFor(small) and options[1]:GetHeight() == 24 and options[1].icon:GetHeight() == 14
            and #mock.frames == frames,
            "opened from buttons of different sizes, the bar's own are sized anew and no frame is made (made "
            .. (#mock.frames - frames) .. ")")
        Picker.Close()
        big:Hide()
        small:Hide()
    end
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
check(#events == 5 and events[1].story.title == "Challenge completed: Challenge 501"
    and events[1].story.chip.text == Chronicle.Character() and events[1].strip:IsShown(),
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
            if each.story.chip.text == "Jaina Proudmoore" then
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
    -- With reactions (sharing on): a friend's card has a button to react, as
    -- on the live feed's cards, and the card still opens the recipe book; the
    -- player's own cards show on their button who reacted.
    enable("sharing")
    local ownLevel = { level = 15, t = time() - 30 }
    Chronicle.Add("level", ownLevel)
    Chronicle.Receive(ownLevel.t, "level", {}, "Jaina Proudmoore", "cheer")
    Chronicle.Receive(ownLevel.t, "level", {}, "Mira Stormfeather", "cheer")
    mock.Advance(0.1)
    local function storyOf(test)
        for _, each in ipairs(bookFrames("story")) do
            if test(each.story) then
                return each
            end
        end
    end
    local function theirSkill()
        return storyOf(function(story) return story.kind == "skill" and story.chip.text == "Jaina Proudmoore" end)
    end
    local function mySkill()
        return storyOf(function(story) return story.kind == "skill" and story.chip.text ~= "Jaina Proudmoore" end)
    end
    local function myLevel()
        return storyOf(function(story) return story.kind == "level" and story.number == 15 end)
    end
    local theirEntry
    for _, entry in ipairs(Chronicle.Entries()) do
        if entry.k == "skill" and entry.who == "Jaina Proudmoore" then
            theirEntry = entry
        end
    end
    local said, lines = nil, {}
    local setText, addLine = GameTooltip.SetText, GameTooltip.AddLine
    GameTooltip.SetText = function(_, text)
        said, lines = text, {}
    end
    GameTooltip.AddLine = function(_, text)
        lines[#lines + 1] = text
    end
    theirs = theirSkill()
    check(theirs.react:IsShown() and not theirs.react.count:IsShown() and theirs.story.reaction.icon == "clap"
        and not theirs.story.reaction.lit and theirs.react.mouseEnabled and theirs.react.ground.fill.token == "control"
        and theirs.react:GetWidth() == 26 and theirs.card.mouseEnabled and not theirs.picture.mouseEnabled,
        "a friend's card shows a button to react, muted, as on the live feed; the card can still be clicked")
    theirs.react.scripts.OnEnter(theirs.react)
    check(said == "Click to react" and theirs.react.over, "the button says what a click does")
    theirs.react.scripts.OnLeave(theirs.react)
    said = nil
    theirs.card.scripts.OnEnter(theirs.card)
    theirs.card.scripts.OnMouseUp(theirs.card, "LeftButton")
    mock.Advance(0.1)
    check(said == nil and #mock.links == 3 and theirEntry.mine == nil,
        "a click on the card opens the recipe book again and reacts to nothing; the card has no tooltip of its own")
    mock.Click(theirSkill().react)
    mock.Advance(0.1)
    theirs = theirSkill()
    check(theirEntry.mine == "clap" and theirs.story.reaction.lit and theirs.react.ground.fill.token == "accentDeep"
        and #mock.links == 3, "a click on the button reacts, and the button lights up")
    theirs.react.scripts.OnEnter(theirs.react)
    check(said == "You reacted. Click again to take it back." and lines[1] == "Jaina Proudmoore will see it as soon as you are both online.",
        "until she is told, the button says she will be")
    mock.Click(theirs.react)
    mock.Advance(0.1)
    check(theirEntry.mine == nil and not theirSkill().story.reaction.lit, "a second click takes it back")
    local own = mySkill()
    own.card.scripts.OnMouseUp(own.card, "LeftButton")
    check(not own.react:IsShown() and #mock.opened == 2, "the player's own profession has no reaction and still opens on a click")
    local level = myLevel()
    check(level and level.react:IsShown() and level.react.count:IsShown() and level.react.count:GetText() == "2"
        and level.react:GetWidth() > 26 and level.story.reaction.icon == "cheer" and level.story.reaction.lit
        and level.react.ground.fill.token == "accentDeep" and level.react.mouseEnabled and not level.card.mouseEnabled,
        "the player's own event shows on its button how many reacted; the card itself catches no mouse")
    level.react.scripts.OnEnter(level.react)
    check(said == "Reactions from" and lines[1]:find("cheer.tga:14:14", 1, true) and lines[1]:find("Jaina Proudmoore, Mira Stormfeather", 1, true) and lines[2] == nil,
        "and who, on the mouse, after the icon of their reaction")
    mock.Click(level.react)
    check(level.story.reaction.lit and level.react.count:GetText() == "2", "a click on it does nothing")
    check(level.react.second == nil and not ns.UI.ReactionPicker.IsOpenFor(level.react), "one kind of reaction, one icon, and no textures for a second")
    mock.Click(level.react, "RightButton")
    check(not ns.UI.ReactionPicker.IsOpenFor(level.react), "the player's own card opens no bar")

    -- Holding the button or a right-click opens the bar with the kind's set.
    local Picker = ns.UI.ReactionPicker
    theirs = theirSkill()
    theirs.react.scripts.OnEnter(theirs.react)
    check(lines[#lines] == "Hold or right-click to choose another reaction.", "the tooltip says how to choose another")
    mock.Click(theirs.react, "RightButton")
    local options, bar = Picker.Shown()
    check(Picker.IsOpenFor(theirs.react) and #options == 2 and options[1].reaction == "clap" and options[2].reaction == "cheer"
        and not options[1].lit and theirEntry.mine == nil and bar:GetWidth() == 4 * 2 + 26 * 2 + 4,
        "a right-click opens the bar with the profession's set, the default first, and gives nothing")
    options[2].scripts.OnEnter(options[2])
    check(said == "Celebrate", "a choice names itself on the mouse")
    mock.Click(options[2])
    mock.Advance(0.1)
    theirs = theirSkill()
    check(theirEntry.mine == "cheer" and not Picker.IsOpenFor(theirs.react) and theirs.story.reaction.icon == "cheer"
        and theirs.story.reaction.lit, "a click on a choice gives it and closes the bar; the button shows it")
    mock.Click(theirs.react, "RightButton")
    options = Picker.Shown()
    check(options[2].lit and not options[1].lit, "the one given is lit in the bar")
    mock.Click(options[1])
    mock.Advance(0.1)
    check(theirEntry.mine == "clap", "another replaces it")
    theirs = theirSkill()
    mock.Click(theirs.react, "RightButton")
    mock.Click(Picker.Shown()[1])
    mock.Advance(0.1)
    check(theirEntry.mine == nil, "the one given, picked again, takes it back")
    theirs = theirSkill()
    mock.Click(theirs.react, "RightButton")
    mock.Click(theirs.react)
    mock.Advance(0.1)
    check(theirEntry.mine == "clap" and not Picker.IsOpenFor(theirSkill().react),
        "a plain click while the bar is open reacts and closes the bar, which would show what was")
    Chronicle.React(theirEntry, false)
    mock.Advance(0.1)
    -- Held: the bar opens after a moment, and the click that ends the hold does nothing else.
    theirs = theirSkill()
    theirs.react.mouseOver = true
    theirs.react.scripts.OnMouseDown(theirs.react, "LeftButton")
    mock.Advance(0.1)
    check(not Picker.IsOpenFor(theirs.react), "not at once")
    mock.Advance(0.4)
    check(Picker.IsOpenFor(theirs.react), "held for a moment, the bar opens")
    theirs.react.scripts.OnMouseUp(theirs.react, "LeftButton")
    mock.Click(theirs.react)
    check(theirEntry.mine == nil and Picker.IsOpenFor(theirs.react), "letting go gives nothing, the bar stays")
    options = Picker.Shown()
    theirs.react.mouseOver = nil
    theirs.react.scripts.OnLeave(theirs.react)
    mock.Advance(0.6)
    check(not Picker.IsOpenFor(theirs.react), "away from bar and button for a moment, it closes")
    theirs.react.scripts.OnMouseDown(theirs.react, "LeftButton")
    mock.Advance(0.1)
    theirs.react.scripts.OnMouseUp(theirs.react, "LeftButton")
    mock.Click(theirs.react)
    mock.Advance(0.5)
    check(theirEntry.mine == "clap" and not Picker.IsOpenFor(theirSkill().react), "a short click gives the default, no bar follows")
    theirs = theirSkill()
    theirs.react.mouseOver = true
    theirs.react.scripts.OnMouseDown(theirs.react, "LeftButton")
    mock.Advance(0.5)
    theirs.react.mouseOver = nil
    Picker.Shown()[2].mouseOver = true
    theirs.react.scripts.OnMouseUp(theirs.react, "LeftButton")
    Picker.Shown() -- (closed by then)
    mock.Advance(0.1)
    check(theirEntry.mine == "cheer" and not Picker.IsOpenFor(theirSkill().react), "let go over a choice, that one is given")
    Chronicle.React(theirEntry, false)
    mock.Advance(0.1)

    -- The player's own card: the two most given, the first in front, and all in the count.
    Chronicle.Receive(ownLevel.t, "level", {}, "Borin Ironhand", "clap")
    mock.Advance(0.1)
    level = myLevel()
    check(level.react.count:GetText() == "3" and level.story.reaction.icon == "cheer" and level.story.reaction.second == "clap"
        and level.react.second:IsShown() and level.react.disc:IsShown() and level.react:GetWidth() > 26 + 10,
        "two kinds received: the most given in front, the next half behind it, and the count of all")
    level.react.scripts.OnEnter(level.react)
    check(#lines == 2 and lines[1]:find("cheer.tga", 1, true) and lines[2]:find("clap.tga", 1, true)
        and lines[2]:find("Borin Ironhand", 1, true), "the tooltip names them by reaction, the most given first")
    Chronicle.Receive(ownLevel.t, "level", {}, "Borin Ironhand", nil)
    mock.Advance(0.1)
    ns:SetOption("sharing", "reactions", false)
    mock.Advance(0.1)
    check(not theirSkill().react:IsShown() and theirSkill().picture.mouseEnabled == false
        and not myLevel().react:IsShown() and myLevel().card.mouseEnabled == false,
        "with reactions switched off, the cards are as before")
    GameTooltip.SetText, GameTooltip.AddLine = setText, addLine
    ns:SetOption("sharing", "reactions", true)
    enable("sharing", false)
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
do
    local recording = visibleEntries()
    check(#recording == 5 and recording[1].toggle:IsShown() and #bookFrames("story") == 0 and not window.railScroll:IsShown()
        and window.list:IsShown() and window.detail:IsShown(),
        "recording: the four switches and how people are named, as entries; no book, no rail (got " .. #recording .. ")")
    check(recording[5].entry.item.key == "chronicleNames" and recording[5].toggle.on and recording[5].entry.title == "Display",
        "the character name behind an alias is a switch of its own under a heading, on from the start")
    -- The live feed in full: its three options as rows, the kinds of events as chips.
    mock.Click(recording[4])
    local detail = window.detail
    local function chips()
        local list = {}
        for _, chip in ipairs(detail.chips) do
            if chip:IsVisible() then
                list[#list + 1] = chip
            end
        end
        return list
    end
    local kinds = chips()
    -- Every kind is a chip; all are on but the zones, the last two are the zones and the reactions.
    local n = #ns.features.liveFeed.KINDS
    check(recording[4].sub:GetText() == "On  ·  " .. (n + 4) .. " options" and #visibleRows() == 4 and #kinds == n
        and detail.chipsTitle:GetText() == "Kinds of events" and detail.chipsCount:GetText() == (n - 1) .. " of " .. n .. " on",
        "the live feed: duration, keeping the last three, sound and own events as rows, every kind as a chip, all but one on")
    check(kinds[2].label:GetText() == "Deaths" and kinds[2].on and kinds[2].option.icon == "skull" and ns.UI.media.skull
        and kinds[n - 1].label:GetText() == "New zones" and not kinds[n - 1].on and not kinds[n - 1].lit.parts[1]:IsShown() and kinds[n].label:GetText() == "Reactions" and kinds[n].option.icon == "cheer",
        "each chip with its kind's icon, lit while on")
    check(detail.hint:GetText() == ns.L.o_liveFeed_kinds_desc, "below the chips what they are for")
    kinds[2].scripts.OnEnter(kinds[2])
    check(detail.hint:GetText() == ns.L.o_liveFeed_death_desc, "pointing at a chip explains it")
    kinds[2].scripts.OnLeave(kinds[2])
    check(detail.hint:GetText() == ns.L.o_liveFeed_kinds_desc, "and the explanation goes again")
    mock.Click(kinds[2])
    mock.Advance(0.1)
    check(ns:GetOption("liveFeed", "death") == false and not kinds[2].on and detail.chipsCount:GetText() == (n - 2) .. " of " .. n .. " on",
        "a click on a chip switches its kind")
    mock.Click(kinds[2])
    mock.Advance(0.1)
    check(ns:GetOption("liveFeed", "death") == true and kinds[2].on, "and back")
    detail.scroll:SetVerticalScroll(30)
    mock.Click(detail.switch)
    mock.Advance(0.1)
    check(not ns.features.liveFeed.enabled and kinds[2].disabled and kinds[2]:GetAlpha() < 1 and detail.off:IsShown(),
        "switched off, its chips are greyed out")
    mock.Click(kinds[2])
    mock.Advance(0.1)
    check(ns:GetOption("liveFeed", "death") == true, "and clicks on them do nothing")
    mock.Click(detail.switch)
    mock.Advance(0.1)
    check(ns.features.liveFeed.enabled and not kinds[2].disabled and detail.scroll:GetVerticalScroll() == 30,
        "switching it off and on does not make the detail jump")
    -- Its picture: the feed's own cards with the chronicle's sample people.
    local Sample = Chronicle.Sample
    local feed = detail.stage.scenes.feed
    local cards = feed.cards
    check(detail.stage.current == "feed" and feed:IsVisible() and detail.title.mockPoint[5] < -200
        and cards[1]:IsShown() and cards[2]:IsShown() and cards[1]:GetParent() == feed
        and cards[1].title:GetText() == ns.UI.FeedStory(Sample("level")).title and cards[1].head:GetText():find("Mira Stormfeather", 1, true)
        and cards[2].title:GetText() == ns.UI.FeedStory(Sample("boss")).title and cards[1].number:GetText() == "40",
        "above the live feed its cards, as the feed draws them: Mira's level, Borin's boss: "
        .. cards[1].head:GetText() .. " / " .. cards[1].title:GetText())
    check(feed.caption.text:GetText() == "Visible for 7 seconds" and cards[1].bar:IsShown() and feed.animations[1]:IsPlaying()
        and cards[1]:GetAlpha() == 1, "how long a card stays, with a line that runs out")
    check(#ns.UI.Feed.Shown() == 0, "the picture puts no card on the screen")
    ns:SetOption("liveFeed", "duration", "long")
    mock.Advance(0.1)
    check(feed.caption.text:GetText() == "Visible for 12 seconds", "the picture follows the duration")
    ns:SetOption("liveFeed", "duration", "normal")
    mock.Advance(0.1)
    -- Pointed at a kind: a card of that kind, faint while it is off.
    kinds[2].scripts.OnEnter(kinds[2])
    check(cards[1].title:GetText() == ns.UI.FeedStory(Sample("death")).title and not cards[2]:IsShown()
        and feed.caption.text:GetText() == "Shown" and cards[1]:GetAlpha() == 1, "pointing at a chip shows its kind's card")
    mock.Click(kinds[2])
    mock.Advance(0.1)
    check(cards[1]:GetAlpha() < 0.5 and not cards[1].bar:IsShown() and feed.caption.text:GetText() == "Not shown",
        "a kind switched off is faint")
    mock.Click(kinds[2])
    mock.Advance(0.1)
    kinds[2].scripts.OnLeave(kinds[2])
    kinds[n].scripts.OnEnter(kinds[n])
    check(cards[1].title:GetText() == ns.L.c_reacted_cheer:format("Mira Stormfeather"), "a reaction as the feed shows it")
    kinds[n].scripts.OnLeave(kinds[n])
    check(cards[2]:IsShown() and feed.caption.text:GetText() == "Visible for 7 seconds", "and back to the two cards")
    mock.Click(detail.switch)
    mock.Advance(0.1)
    check(cards[1]:GetAlpha() < 0.5 and feed.caption.text:GetText() == "No cards while this is off", "switched off, the cards are faint")
    mock.Click(detail.switch)
    mock.Advance(0.1)
    feed:Hide()
    check(not feed.animations[1]:IsPlaying(), "what moves stops when the picture is hidden")
    feed:Show()
    check(feed.animations[1]:IsPlaying(), "and goes on when it is back")
    local item = recording[1].entry.item
    item.preview = nil
    mock.Click(recording[1])
    check(not detail.stage:IsShown() and detail.title.mockPoint[5] > -100, "an entry without a picture starts with its name")
    item.preview = "book"
    mock.Click(recording[1])
    check(detail.stage:IsShown() and detail.stage.current == "book", "every entry has one, though")
end
FamulusDB.chronicle = nil
ns:Fire("CHRONICLE_CHANGED")
mock.Advance(0.1)
mock.Click(tabButton("Everyone"))
mock.Advance(0.1)
check(#visibleRows() == 1 and visibleRows()[1].label:GetText() == "Nothing recorded yet" and #bookFrames("story") == 0,
    "an empty chronicle says how to begin")
mock.Click(navButton("Aliases"))
SlashCmdList.FAMULUS("")

---------------------------------------------------------------------------
section("Widgets: painting")
---------------------------------------------------------------------------

do -- colours by token: they follow the scheme, fading and gradients; shapes of one size share their spans
    local UI = ns.UI
    local frame = CreateFrame("Frame", nil, UIParent)
    local function Recorded(texture)
        texture.SetColorTexture = function(self, r, g, b, a)
            self.fill = { r, g, b, a }
        end
        texture.SetGradient = function(self, orientation, from, to)
            self.gradient = { orientation, from, to }
        end
        return texture
    end
    local function Same(x, y)
        return math.abs(x - y) < 1e-9
    end
    local texture = Recorded(frame:CreateTexture())
    UI.Paint(texture, "card", 0.5)
    local card = UI.colors.card
    check(texture.fill[1] == card[1] and Same(texture.fill[4], card[4] * 0.5), "a painted texture takes its token's colour and the alpha on top")
    UI.SetLevel(texture, 0.5)
    check(Same(texture.fill[4], card[4] * 0.25), "a level fades it on top of that")
    UI.Paint(texture, "accent")
    check(texture.fill[1] == UI.colors.accent[1] and Same(texture.fill[4], UI.colors.accent[4] * 0.5), "painted again, it keeps its level")
    UI.SetLevel(texture, 1)
    check(Same(texture.fill[4], UI.colors.accent[4]), "back at level 1 it is whole")
    local other = Recorded(frame:CreateTexture())
    UI.Paint(other, "accent")
    local scheme = ns:GetOption("general", "accent")
    ns:SetOption("general", "accent", scheme == "mint" and "rose" or "mint")
    check(texture.fill[1] == UI.colors.accent[1] and other.fill[1] == UI.colors.accent[1] and Same(other.fill[4], UI.colors.accent[4]),
        "another scheme repaints every region with the same token")
    ns:SetOption("general", "accent", scheme)
    UI.Shade(texture, "HORIZONTAL", "accent", "accent2")
    UI.SetLevel(texture, 0.25)
    check(texture.gradient[1] == "HORIZONTAL" and Same(texture.gradient[2].a, UI.colors.accent[4] * 0.25), "a gradient fades by its own level")
    UI.Paint(texture, "card")
    check(Same(texture.fill[4], card[4]), "painted after a gradient, it starts at level 1 again")

    local shape = UI.Round(frame, "card", 6)
    for _, part in ipairs(shape.parts) do
        Recorded(part)
    end
    shape:SetGradient("HORIZONTAL", "accent", "accent2", 100, 20)
    local accent, accent2 = UI.colors.accent, UI.colors.accent2
    local first, last = shape.parts[1].gradient, shape.parts[2].gradient -- top left and top right corner
    check(first[2].r == accent[1] and Same(last[3].r, accent2[1]) and Same(shape.parts[5].gradient[2].r, accent[1] + (accent2[1] - accent[1]) * 0.06),
        "a rounded shape spreads its gradient over its parts by where each lies")
    local spanless = true
    for _, part in ipairs(shape.parts) do
        spanless = spanless and rawget(part, "span") == nil
    end
    check(#shape.parts == 7 and spanless and UI.Round(frame, "card", 6).spans == shape.spans and UI.Round(frame, "card", 8).spans ~= shape.spans,
        "shapes of the same size share where their parts lie; their textures carry nothing for it")
end

---------------------------------------------------------------------------
section("Widgets: crest")
---------------------------------------------------------------------------

do -- the glowing dot: the book's line, the head of a live feed card
    local dot = ns.UI.GlowDot(UIParent, 8, "OVERLAY")
    check(dot:GetWidth() == 8 and dot.glow:GetWidth() == 24 and dot.layer == "OVERLAY" and dot.glow.layer == "ARTWORK"
        and dot.glow.mockPoint[2] == dot, "a glowing dot: the dot, and its glow three times as large a layer below, on it")
    ns.UI.SetDot(dot, 5)
    check(dot:GetWidth() == 5 and dot.glow:GetWidth() == 15 and dot:IsShown(), "a new size changes both")
    ns.UI.SetDot(dot, nil, false)
    check(not dot:IsShown() and not dot.glow:IsShown() and dot:GetWidth() == 5, "hidden with its glow, the size kept")
end

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
mock.Click(navButton("Fellowship"))
mock.Advance(0.1)
check(window.sidebar:IsShown() and window.area.name:GetText() == "Fellowship" and window.area.desc:GetText() == ns.L.area_fellows_desc
    and pageTab("Overview") and pageTab("Overview").selected and pageTab("Settings") and not pageTab("Most often"),
    "fellow travellers: the sidebar as everywhere, the name in the head, overview and settings as tabs")
check(window.fellows:GetHeight() > 200, "the overview has a height, so the client can place what is in it")
check(window.fellows:GetWidth() == 1180 - 224 - 2 * 28 and not window.fellows.card:IsShown(),
    "the overview takes the content's width; no card beside it")
check(navButton("Fellowship").count:GetText() == tostring(ns.FellowService.Count()), "the sidebar card counts the fellow travellers: " .. tostring(navButton("Fellowship").count:GetText()))
local overview = window.fellows
check(overview and overview:IsShown() and overview.tiles[1].guid == "Player-1-MIRA" and overview.tiles[2].guid == "Player-1-TOM"
    and not (overview.tiles[3] and overview.tiles[3]:IsShown()) and not overview.list:IsShown(),
    "up to three people are tiles, the most time together first; no list below")
check(overview.tiles[1].numeral:GetText() == "I" and overview.tiles[1].name:GetText() == "Mira Sturmfeder"
    and overview.tiles[1].sub:GetText() == "Level 20 " .. ns.UI.Colored("classMAGE", "Mage") .. "" and overview.tiles[1].badge.text:GetText() == "Acquainted"
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
-- Whom the last whisper the window opened went to.
local function lastWhisper()
    for index = #mock.calls, 1, -1 do
        if mock.calls[index][1] == "ChatFrameUtil.SendTell" then
            return mock.calls[index][2]
        end
    end
end
do -- opposite the rank, a speech bubble opens a whisper to them
    local tile = overview.tiles[1]
    local before = mock.count("ChatFrameUtil.SendTell")
    check(tile.whisper:IsShown() and tile.whisper.mockPoint[1] == "TOPRIGHT", "a tile has a whisper button opposite its rank")
    GameTooltip:Hide()
    tile.whisper.scripts.OnEnter(tile.whisper)
    check(GameTooltip:IsShown() and GameTooltip:GetText() == "Whisper", "under the mouse a tooltip names it")
    tile.whisper.scripts.OnLeave(tile.whisper)
    mock.Click(tile.whisper)
    mock.Advance(0.1)
    check(mock.count("ChatFrameUtil.SendTell") == before + 1 and lastWhisper() == "Mira Sturmfeder"
        and overview:IsShown() and not overview.card:IsShown(), "it opens a whisper to them; the overview stays, no story opens")
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
do -- the card: its buttons as icons in one row, each named by a tooltip
    local card = overview.card
    local function at(button, point, x)
        local anchor = button.mockPoint
        return anchor[1] == point and anchor[2] == card and anchor[3] == "BOTTOM" and anchor[4] == x and anchor[5] == 36
    end
    local icons = not (card.whisper.label:IsShown() or card.alias.label:IsShown() or card.forget.label:IsShown())
    check(icons and card.whisper:GetWidth() == 40 and card.whisper:GetHeight() == 40 and card.whisper.variant == "primary"
        and card.alias:GetWidth() == 34 and card.forget:GetWidth() == 34 and card.forget:GetHeight() == 34
        and card.alias.variant == "secondary" and card.forget.variant == "secondary",
        "the card's buttons are icons: the whisper a little larger and in the accent, alias and forget alike")
    check(at(card.whisper, "CENTER", 0) and at(card.alias, "RIGHT", -30) and at(card.forget, "LEFT", 30),
        "the whisper on the card's middle axis, the alias to its left, forget to its right, all on one line")
    check(card.whisper.tip == "Whisper" and card.alias.tip == "Set alias" and card.forget.tip == "Forget"
        and card.whisper.label:GetText() == "Whisper", "each named by its tooltip")
    local IsOwned = GameTooltip.IsOwned
    GameTooltip.IsOwned = function(_, owner)
        return owner == card.alias
    end
    GameTooltip:Hide()
    card.alias.scripts.OnEnter(card.alias)
    local named = GameTooltip:IsShown() and GameTooltip:GetText() == "Set alias"
    card.alias.scripts.OnLeave(card.alias)
    check(named and not GameTooltip:IsShown(), "under the mouse the tooltip names the button; it goes with the mouse")
    GameTooltip.IsOwned = IsOwned
    mock.Click(card.whisper)
    mock.Advance(0.1)
    check(lastWhisper() == "Mira Sturmfeder" and card:IsShown() and card.name:GetText() == "Mira Sturmfeder",
        "the card's button opens a whisper to them; the story stays")
    local SendTell = ChatFrameUtil.SendTell
    ChatFrameUtil.SendTell = nil
    ns:Fire("FELLOWS_CHANGED")
    mock.Advance(0.1)
    local alone = card.alias.mockPoint
    check(not card.whisper:IsShown() and card.alias:IsShown() and alone[1] == "LEFT" and alone[5] == 36
        and card.forget.mockPoint[4] == alone[4] + 34 + 10, "a client that cannot open a whisper shows no button for it; the rest is centred")
    ChatFrameUtil.SendTell = SendTell
    ns:Fire("FELLOWS_CHANGED")
    mock.Advance(0.1)
end
mock.Click(window.tabs.back)
mock.Click(pageTab("Settings"))
mock.Advance(0.1)
local fellowEntries = visibleEntries()
check(#fellowEntries == 3 and fellowEntries[1].toggle:IsShown() and fellowEntries[1].sub:GetText():find("2 options", 1, true)
    and #visibleRows() == 2 and fellowEntries[2].label:GetText() == "Nearby" and fellowEntries[2].sub:GetText() == "Off  ·  3 options"
    and fellowEntries[3].entry.item.kind == "action" and fellowEntries[3].entry.title == "Tidy up"
    and pageTab("Settings").selected and window.resetButton:IsShown() and not overview:IsShown() and not overview.card:IsShown(),
    "settings: the two switches with their options, then tidying up, with reset beside the tabs; no overview")
mock.Click(fellowEntries[3])
do -- tidying up: whoever is neither a friend nor in the guild goes, after asking
    -- The chosen entry in full: its name, what it would do, the button.
    local function tidy()
        mock.Advance(0.1)
        local detail = window.detail
        return { label = detail.title, desc = detail.desc, action = detail.action }
    end
    local row = tidy()
    check(#visibleRows() == 0 and not fellowEntries[3].toggle:IsShown() and not window.detail.toggle:IsShown(),
        "tidying up has a button instead of a switch")
    check(row.label:GetText() == "Remove everyone but friends and guild" and row.action:IsShown() and not row.action.disabled
        and row.desc:GetText() == "1 person is neither on your friends list nor in your guild: Mira Sturmfeder."
        and row.action.label:GetText() == "Remove", "tidy up names who would go; Tom is in the group and stays: " .. row.desc:GetText())
    mock.state.friends = { { name = "Mira Sturmfeder", guid = "Player-1-MIRA", connected = false } }
    ns:Fire("FELLOWS_CHANGED")
    row = tidy()
    check(row.desc:GetText() == "Everyone in your fellowship is on your friends list or in your guild." and row.action.disabled,
        "with everyone a friend, there is nothing to tidy up")
    mock.state.friends = nil
    -- In a guild whose roster has not come yet, it waits rather than take members for strangers.
    -- A new session: out of a guild for a moment, so no roster from the tests before is kept.
    local eventsBefore = ns:CountRegisteredEvents()
    mock.reset()
    mock.state.guild = nil
    ns.SocialService.EachGuildMember(function() end)
    mock.state.guild = {}
    ns:Fire("FELLOWS_CHANGED")
    row = tidy()
    check(row.desc:GetText() == "Your guild roster is still loading." and row.action.disabled
        and mock.count("C_GuildInfo.GuildRoster") >= 1 and ns:CountRegisteredEvents() == eventsBefore + 1,
        "before the guild roster has come it waits, and asks for it")
    mock.state.guild = { { name = "Someone Else", guid = "Player-1-ELSE" } }
    mock.Fire("GUILD_ROSTER_UPDATE")
    row = tidy()
    check(row.desc:GetText():find("^1 person") ~= nil and not row.action.disabled and ns:CountRegisteredEvents() == eventsBefore,
        "once the roster is there it counts again, and stops listening")
    -- Later in the session the client hands over an empty roster for a moment: the last one counts.
    mock.state.guild = {}
    ns:Fire("FELLOWS_CHANGED")
    row = tidy()
    check(row.desc:GetText():find("^1 person") ~= nil and not row.action.disabled and ns:CountRegisteredEvents() == eventsBefore,
        "an empty roster later in the session keeps the last one; it neither waits nor takes members for strangers")
    mock.state.guild = { { name = "Someone Else", guid = "Player-1-ELSE" } }
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
    check(not row.action.disabled and row.desc:GetText():find("^1 person") ~= nil, "once Battle.net is back, it counts again")
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
        and lastChat():find("removed 1 who is neither a friend nor in your guild", 1, true),
        "the second click removes whom the row counted, says how many, and leaves who came later: " .. lastChat())
    FamulusDB.fellows["Player-1-NEW"] = nil
    FamulusDB.fellows["Player-1-MIRA"] = miraData
    mock.state.guild = nil
    ns:Fire("FELLOWS_CHANGED")
    mock.Advance(0.1)
end
mock.Click(navButton("Chronicle"))
check(window.area.name:GetText() == "Chronicle" and pageTab("Everyone"), "another page from the sidebar, with its own tabs")
mock.Click(navButton("Fellowship"))
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
mock.Click(navButton("Fellowship"))
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
do -- at a row's end, a speech bubble; the last column ends before it
    local row, width = overview.rows[1], overview.list:GetWidth()
    check(row.whisper:IsShown() and row.whisper.mockPoint[1] == "RIGHT" and row.last.mockPoint[4] + row.last:GetWidth() <= width - 10 - 28
        and row.whisper.tip == "Whisper", "a row has a whisper button at its end, clear of the last column, named by its tooltip")
    mock.Click(row.whisper)
    mock.Advance(0.1)
    check(lastWhisper() == "Person 1" and overview:IsShown() and not overview.card:IsShown(),
        "it opens a whisper to them; the overview stays")
end
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
check(overview.card:IsShown() and overview.card.name:GetText() == "Lysa Morgentau"
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
do
    local year, month, day = storyChapters[2].chapter.small:match("^(%d+)%-(%d+)%-(%d+)$")
    ns:SetOption("general", "dateFormat", "{d}/{m}/{y}")
    mock.Advance(0.1)
    local small = bookFrames("chapter")[2].chapter.small
    check(small == day .. "/" .. month .. "/" .. year, "an older day in the chosen order: " .. small)
    ns:SetOption("general", "dateFormat", "auto")
    mock.Advance(0.1)
end
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
do -- left of the alias; the tooltips speak the window's language
    local card = overview.card
    local anchor = card.chronicle.mockPoint
    check(anchor[1] == "RIGHT" and anchor[4] == -30 - 34 - 10 and anchor[5] == 36 and card.whisper.mockPoint[4] == 0
        and card.chronicle.tip == "In the chronicle", "the way to the chronicle stands left of the alias; the whisper stays in the middle")
    local wrong = {}
    for _, code in ipairs(ns:GetLocaleCodes()) do
        ns:SetOption("general", "language", code)
        mock.Advance(0.1)
        local L = ns.L
        if card.whisper.tip ~= L.ui_fellow_whisper or card.chronicle.tip ~= L.ui_fellow_chronicle
            or card.alias.tip ~= L.ui_fellow_alias or card.forget.tip ~= L.ui_fellow_forget then
            wrong[#wrong + 1] = code
        end
    end
    ns:SetOption("general", "language", "auto")
    mock.Advance(0.1)
    check(#wrong == 0, "the card's tooltips follow the language: " .. table.concat(wrong, ", "))
end
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
check(window.area.name:GetText() == "Fellowship" and overview.card:IsShown() and overview.card.name:GetText() == "Lysa Morgentau"
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
mock.Click(navButton("Fellowship"))
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
FamulusDB.chronicle = nil
ns:Fire("CHRONICLE_CHANGED")

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
-- (the same loading tidies the chronicle's links and stats, checked below)
mock.chronicleBeforeLoad = FamulusDB.chronicle
FamulusDB.chronicle = {
    entries = { { t = time() - 50, k = "level", who = "Mira Stormfeather", level = 30 } },
    friends = {},
    links = {
        ["old-friend"] = { name = "Old Friend", t = time() - 31 * 86400 },
        ["new-friend"] = { name = "New Friend", t = time() - 86400 },
        broken = "x",
    },
    profiles = {
        ["Old Friend"] = { level = 20, stats = {} },
        ["New Friend"] = { level = 21, stats = {} },
        ["Mira Stormfeather"] = { level = 30, stats = {} },
    },
}
ns:Fire("DATABASE_READY")
check(FamulusDB.chronicle.links["old-friend"] == nil and FamulusDB.chronicle.links.broken == nil
    and FamulusDB.chronicle.links["new-friend"] ~= nil,
    "a link older than thirty days, or a broken one, is dropped when the saved data loads")
check(FamulusDB.chronicle.profiles["Old Friend"] == nil and FamulusDB.chronicle.profiles["New Friend"] ~= nil
    and FamulusDB.chronicle.profiles["Mira Stormfeather"] ~= nil,
    "stats are kept of the people the chronicle tells of or still hears from, and of nobody else")
FamulusDB.chronicle, mock.chronicleBeforeLoad = mock.chronicleBeforeLoad, nil
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

do -- the search: a person by their own row, no more rows of people than the list shows, and no books
    for index = 1, 70 do
        FamulusDB.fellows["Player-9-PROBE" .. index] = { name = "Probe Person" .. index, last = time() - index,
            first = time() - 86400, times = 1, seconds = 60, bosses = 0 }
    end
    ns:Fire("FELLOWS_CHANGED")
    mock.Advance(0.1)
    local function people()
        local count = 0
        for _, row in ipairs(visibleRows()) do
            count = count + (row.item.kind == "fellow" and 1 or 0)
        end
        return count
    end
    window.search.edit:SetText("probe person")
    check(people() == 60 and window.area.desc:GetText():find("70", 1, true) ~= nil,
        "the search shows as many people as the list does and counts the rest: " .. people() .. " / " .. window.area.desc:GetText())
    window.search.edit:SetText("fellowship")
    check(people() == 0, "a person is found by their own row, not by the name of the page (got " .. people() .. ")")
    local learned, learn = 0, ns.ChronicleService.LearnClasses
    ns.ChronicleService.LearnClasses = function(...)
        learned = learned + 1
        return learn(...)
    end
    window.search.edit:SetText("zzzz")
    ns.ChronicleService.LearnClasses = learn
    check(ns:IsCategoryEnabled("chronicle") and learned == 0, "the search builds none of the chronicle's books (got " .. learned .. ")")
    window.search.edit:SetText("")
    for index = 1, 70 do
        FamulusDB.fellows["Player-9-PROBE" .. index] = nil
    end
    ns:Fire("FELLOWS_CHANGED")
    mock.Advance(0.1)
end

-- The timeline: every group as a book, the week beside it.
mock.Click(navButton("Fellowship"))
mock.Advance(0.1)
check(pageTab("Overview") and pageTab("Groups") and pageTab("Settings"), "fellow travellers: overview, groups and settings")
do -- (the cards, the book and the rail of one drawing share what they read)
    local read, readRuns = 0, Fellows.Runs
    Fellows.Runs = function(...)
        read = read + 1
        return readRuns(...)
    end
    mock.Click(pageTab("Groups"))
    Fellows.Runs = readRuns
    check(read == 1, "one drawing of the groups reads them once (got " .. read .. ")")
end
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
    mock.Click(navButton("Fellowship"))
    mock.Click(pageTab("Groups"))
    mock.Advance(0.1)
    check(#visibleRows() == 1 and visibleRows()[1].label:GetText() == "No groups yet" and not window.railScroll:IsShown(),
        "without any group, the timeline says how to begin, without a rail")
    FamulusDB.fellowRuns = keptRuns
    mock.Click(pageTab("Overview"))
end

-- The samples speak the addon's language, not the client's (a German client
-- set to English gets English samples, for screenshots of the English window),
-- and every set names the same people.
mock.state.locale = "deDE"
for _, code in ipairs(ns:GetLocaleCodes()) do
    ns:SetOption("general", "language", code)
    local mira = Chronicle.SamplePeople()
    local case = ({ enUS = { "Mira Stormfeather", "Badlands" }, deDE = { "Mira Sturmfeder", "Ödland" } })[code] or { mira }
    SlashCmdList.FAMULUS("chronicle demo")
    SlashCmdList.FAMULUS("fellows demo")
    local zoneSeen, sameFolk = case[2] == nil, true
    for _, entry in ipairs(Chronicle.Entries()) do
        zoneSeen = zoneSeen or (entry.demo and entry.zone == case[2])
        if entry.demo and entry.who then
            sameFolk = sameFolk and Fellows.Find(entry.who) ~= nil
        end
    end
    check(ns:GetLocaleCode() == code and mira == case[1] and (code == "enUS" or mira ~= "Mira Stormfeather")
        and Chronicle.SampleClass(mira) == "MAGE" and Chronicle.Profile(mira) ~= nil and zoneSeen and sameFolk
        and FamulusDB.fellows["Player-0-FAMDEMO01"].name == mira,
        "sample data in " .. code .. " on a German client, the chronicle's companions among the fellow travellers: " .. mira)
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
section("Nearby")
---------------------------------------------------------------------------

do
    local Nearby = ns.NearbyService
    local nearby = ns.features.nearbyFriends
    local Feed = ns.UI.Feed
    local stateBefore = mock.state
    local eventsBefore, timersBefore = ns:CountRegisteredEvents(), mock.ActiveTimers()
    Feed.Clear()
    setState({
        zone = "Tanaris",
        level = 40,
        friends = {
            { name = "Mira Sturmfeder", guid = "Player-1-MIRA", connected = true, level = 41, area = "Tanaris", className = "Mage" },
            { name = "Lysa Morgentau", guid = "Player-1-LYSA", connected = true, level = 38, area = "Feralas", className = "Priest" },
            { name = "Old Friend", guid = "Player-1-OLD", connected = false, level = 0 },
        },
        guild = {
            { name = "Kael Dornhain-Realm", guid = "Player-1-KAEL", online = true, level = 42, zone = "Tanaris", class = "ROGUE" },
            { name = "Mel Mobil", guid = "Player-1-MEL", online = true, mobile = true, level = 30, zone = "Tanaris" },
            { name = "Me Myself", guid = "Player-1-SELF", online = true, level = 40, zone = "Tanaris" },
            { name = "Hagen Steinfaust", guid = "Player-1-HAGEN", online = true, level = 60, zone = "Ironforge", class = "WARRIOR" },
            { name = "Ena Silberquell", guid = "Player-1-ENA", online = true, level = 36, zone = "Desolace", class = "MAGE" },
        },
        bnFriends = {
            { battleTag = "Bo#1", games = { { characterName = "Borin Eisenbart", playerGuid = "Player-1-BORIN", areaName = "Desolace",
                characterLevel = 39, className = "Warrior" } } },
            { battleTag = "Mi#2", games = { { characterName = "Mira Sturmfeder", playerGuid = "Player-1-MIRA", areaName = "Tanaris (DE)",
                characterLevel = 41, className = "Mage" } } },
            { battleTag = "Re#3", games = { { characterName = "Other Game", playerGuid = "Player-1-OTHER", areaName = "Tanaris", wowProjectID = 1 } } },
            { battleTag = "Pv#4", games = { { characterName = "Rhea Dunkelhain", playerGuid = "Player-2-RHEA", areaName = "Tanaris",
                characterLevel = 40, className = "Hunter", mode = "PvP" } } },
            { battleTag = "Ho#5", games = { { characterName = "Grosh Steinhauer", playerGuid = "Player-1-GROSH", areaName = "Tanaris",
                characterLevel = 40, className = "Shaman", factionName = "Horde" } } },
        },
    })

    local function find(people, name)
        for _, person in ipairs(people) do
            if person.name == name then
                return person
            end
        end
    end
    local people, here, level = Nearby.People(true)
    check(#people == 8 and here == "Tanaris" and level == 40,
        "online friends, guild and Battle.net friends in this game; the player's zone and level (got " .. #people .. ")")
    check(not find(people, "Old Friend") and not find(people, "Mel Mobil") and not find(people, "Me Myself") and not find(people, "Other Game"),
        "not: whoever is offline, on the mobile app, the player, someone in another game")
    local mira, kael, borin = find(people, "Mira Sturmfeder"), find(people, "Kael Dornhain"), find(people, "Borin Eisenbart")
    check(mira.from == "friend" and mira.zone == "Tanaris" and mira.level == 41 and mira.class == "MAGE",
        "someone on two lists counts once; the zone in the player's language beats Battle.net's")
    check(kael.from == "guild" and kael.full == "Kael Dornhain-Realm" and kael.class == "ROGUE" and kael.level == 42,
        "a guild member: the name without the realm, the full one kept for a whisper")
    check(borin.from == "battlenet" and borin.zone == "Desolace" and borin.class == "WARRIOR" and borin.level == 39,
        "a Battle.net friend in this game: zone, level and class from Battle.net")
    check(#Nearby.People(false) == 5 and not find(Nearby.People(false), "Kael Dornhain"), "without the guild only friends count")
    do -- (the roster may name no GUID; UnitName gives first name and surname apart)
        local own = mock.state.guild[3]
        own.guid = nil
        mock.state.units = { player = { name = "Me", surname = "Myself" } }
        check(own.name == "Me Myself" and #Nearby.People(true) == 8 and not find(Nearby.People(true), "Me Myself"),
            "the player is left out by their full name too, where the roster names no GUID")
        own.guid, mock.state.units = "Player-1-SELF", nil
    end
    check(find(people, "Rhea Dunkelhain").out == "Realm PvP" and find(people, "Rhea Dunkelhain").bnet == "|Kq4|k"
        and find(people, "Grosh Steinhauer").out == "Horde" and not mira.out and not borin.out and not kael.out,
        "a Battle.net friend in another mode or of the other faction is out of reach")
    check(find(people, "Rhea Dunkelhain").mode == "PvP" and not find(people, "Rhea Dunkelhain").faction
        and find(people, "Grosh Steinhauer").faction == "Horde" and not find(people, "Grosh Steinhauer").mode,
        "the mode from the rich presence against the player's own, the faction apart")
    check(borin.bnet == "|Kq1|k" and not mira.bnet and not kael.bnet,
        "the Battle.net account of whoever was met on Battle.net first, for the whisper")
    check(Nearby.Mode("Forever - RP-PvP - Stranglethorn Vale") == "RP-PvP" and Nearby.Mode("Forever - Normal - Hillsbrad - Foothills") == "Normal"
        and Nearby.Mode("Tanaris") == nil and Nearby.Mode("Forever - Tanaris") == nil and Nearby.Mode(nil) == nil,
        "the mode is the middle of at least three parts")
    mock.state.bnFriends[5].games[1].mode = "PvP"
    check(find(Nearby.People(true), "Grosh Steinhauer").out == "Realm PvP  ·  Horde", "another mode and the other faction: both")
    mock.state.bnFriends[5].games[1].mode = nil
    mock.state.noOwnGame = true
    check(not find(Nearby.People(true), "Rhea Dunkelhain").out and find(Nearby.People(true), "Grosh Steinhauer").out == "Horde",
        "without the player's own mode only the faction counts")
    mock.state.noOwnGame = nil
    mock.state.instanceType = "party"
    check(Nearby.Quiet(true) == "instance", "in a dungeon nobody is told about")
    mock.state.instanceType, mock.state.resting = nil, true
    check(Nearby.Quiet(false) == "rest" and Nearby.Quiet(true) == nil, "nor in a city or an inn, unless asked for")
    mock.state.resting = nil

    -- Switched on: who is here already comes on one card.
    check(not nearby.enabled and ns:CountRegisteredEvents() == eventsBefore, "off from the start: it listens to the game")
    mock.reset()
    enable("nearbyFriends")
    check(nearby.enabled and nearby.events.FRIENDLIST_UPDATE and nearby.events.GUILD_ROSTER_UPDATE and nearby.events.BN_FRIEND_INFO_CHANGED
        and nearby.events.ZONE_CHANGED_NEW_AREA and mock.ActiveTimers() > timersBefore, "switched on, it listens to the lists and the zone")
    check(mock.count("C_FriendList.ShowFriends") == 1 and mock.count("C_GuildInfo.GuildRoster") == 1, "and asks for fresh lists")
    check(#Feed.Shown() == 0, "the card waits a moment for the lists")
    mock.Advance(3.5)
    local card = Feed.Shown()[1]
    check(#Feed.Shown() == 1 and card.head:GetText() == "Kael and Mira" and card.title:GetText() == "Also in Tanaris"
        and card.detail:GetText() == "Level 42 and 41" and card.headDot:IsShown() and card.headDot.glow:IsShown(),
        "whoever is here already comes on one card, not who is out of reach: " .. tostring(card and card.title:GetText()))
    check(card.pair and card.pair[1]:IsShown() and card.pair[2]:IsShown() and not card.crest:IsShown() and not (card.solo and card.solo:IsShown()),
        "two people, two crests instead of a picture")
    check(mock.count("PlaySoundFile") == 1, "with the live feed's sound")
    mock.Advance(10)
    check(#Feed.Shown() == 0, "and it goes like the live feed's cards")

    -- Someone arrives.
    mock.state.friends[2].area = "Tanaris"
    mock.Fire("FRIENDLIST_UPDATE")
    mock.Advance(1.1)
    check(#Feed.Shown() == 0, "someone who arrives comes after a moment, with whoever arrives with them")
    mock.Advance(2)
    card = Feed.Shown()[1]
    check(card and card.head:GetText() == "Lysa" and card.title:GetText() == "Now in Tanaris too"
        and card.detail:GetText() == "Level 38  ·  " .. ns.UI.Colored("classPRIEST", "Priest") .. "  ·  Friends list"
        and card.solo:IsShown() and not card.pair[1]:IsShown() and not card.crest:IsShown(),
        "someone arrives: a card of their own with one crest: " .. tostring(card and card.title:GetText()))
    Feed.Clear()
    mock.state.friends[2].area = "Feralas"
    mock.Fire("FRIENDLIST_UPDATE")
    mock.Advance(1.1)
    mock.state.friends[2].area = "Tanaris"
    mock.Fire("FRIENDLIST_UPDATE")
    mock.Advance(3.5)
    check(#Feed.Shown() == 0, "back again soon after: no second card for the same person in the same zone")

    -- Cities and inns, and the group.
    mock.state.resting = true
    mock.state.bnFriends[1].games[1].areaName = "Tanaris"
    mock.Fire("BN_FRIEND_INFO_CHANGED", 1)
    mock.Advance(3.5)
    check(#Feed.Shown() == 0, "in a city or an inn no card comes")
    ns:SetOption("nearbyFriends", "cities", true)
    mock.state.guild[4].zone = "Tanaris"
    mock.Fire("GUILD_ROSTER_UPDATE")
    mock.Advance(3.5)
    card = Feed.Shown()[1]
    check(card and card.head:GetText() == "Hagen" and card.title:GetText() == "Now in Tanaris too"
        and card.detail:GetText() == "Level 60  ·  " .. ns.UI.Colored("classWARRIOR", "Warrior") .. "  ·  Guild",
        "asked for, cards come there too: " .. tostring(card and card.detail:GetText()))
    ns:SetOption("nearbyFriends", "cities", false)
    mock.state.resting = nil
    Feed.Clear()
    mock.state.group = { members = { { name = "Tom", surname = "Hartwig", guid = "Player-1-TOM", level = 40, class = "PRIEST" } } }
    mock.state.friends[4] = { name = "Tom Hartwig", guid = "Player-1-TOM", connected = true, level = 40, area = "Tanaris", className = "Priest" }
    mock.Fire("FRIENDLIST_UPDATE")
    mock.Advance(3.5)
    check(#Feed.Shown() == 0, "nobody in the player's group gets a card")
    mock.state.group = nil
    mock.Fire("FRIENDLIST_UPDATE")
    mock.Advance(3.5)
    check(#Feed.Shown() == 0, "nor when they leave it: they were here all along")

    -- The player moves on, by foot and by air.
    mock.state.zone = "Desolace"
    mock.Fire("ZONE_CHANGED_NEW_AREA")
    mock.Advance(3.5)
    card = Feed.Shown()[1]
    check(card and card.head:GetText() == "Ena" and card.title:GetText() == "Also in Desolace"
        and card.detail:GetText() == "Level 36  ·  " .. ns.UI.Colored("classMAGE", "Mage") .. "  ·  Guild" and card.solo:IsShown(),
        "the player arrives: whoever is there already: " .. tostring(card and card.title:GetText()))
    Feed.Clear()
    mock.state.friends[5] = { name = "Selina Abendrot", guid = "Player-1-SELINA", connected = true, level = 23, area = "Feralas", className = "Rogue" }
    mock.state.onTaxi, mock.state.zone = true, "Feralas"
    mock.Fire("ZONE_CHANGED_NEW_AREA")
    mock.Advance(3.5)
    check(#Feed.Shown() == 0, "in flight nothing is told")
    mock.state.onTaxi = nil
    mock.Fire("PLAYER_CONTROL_GAINED")
    mock.Advance(4.5)
    card = Feed.Shown()[1]
    check(card and card.head:GetText() == "Selina" and card.title:GetText() == "Also in Feralas",
        "landing is arriving: " .. tostring(card and card.title:GetText()))
    Feed.Clear()
    mock.Fire("PLAYER_CONTROL_GAINED")
    mock.Advance(4.5)
    check(#Feed.Shown() == 0, "control back after a stun is no landing")

    -- After a /reload the lists are only taken note of.
    mock.Fire("PLAYER_ENTERING_WORLD", false, true)
    mock.state.friends[6] = { name = "Jorek Tannwind", guid = "Player-1-JOREK", connected = true, level = 24, area = "Feralas", className = "Warrior" }
    mock.Fire("FRIENDLIST_UPDATE")
    mock.Advance(3.5)
    check(#Feed.Shown() == 0, "right after a /reload nobody is announced")

    -- The tab.
    setState({
        zone = "Tanaris",
        level = 40,
        friends = {
            { name = "Mira Sturmfeder", guid = "Player-1-MIRA", connected = true, level = 41, area = "Tanaris", className = "Mage" },
            { name = "Lysa Morgentau", guid = "Player-1-LYSA", connected = true, level = 38, area = "Feralas", className = "Priest" },
        },
        guild = {
            { name = "Kael Dornhain-Realm", guid = "Player-1-KAEL", online = true, level = 42, zone = "Tanaris", class = "ROGUE" },
            { name = "Hagen Steinfaust", guid = "Player-1-HAGEN", online = true, level = 60, zone = "Ironforge", class = "WARRIOR" },
        },
        bnFriends = {
            { battleTag = "Bo#1", games = { { characterName = "Borin Eisenbart", playerGuid = "Player-1-BORIN", areaName = "Desolace",
                characterLevel = 39, className = "Warrior" } } },
            { battleTag = "Pv#2", games = { { characterName = "Rhea Dunkelhain", playerGuid = "Player-2-RHEA", areaName = "Tanaris",
                characterLevel = 40, className = "Rogue", mode = "PvP" } } },
            { battleTag = "Ho#3", games = { { characterName = "Grosh Steinhauer", playerGuid = "Player-1-GROSH", areaName = "Tanaris",
                characterLevel = 40, className = "Warrior", factionName = "Horde" } } },
        },
    })
    FamulusDB.fellows = { ["Player-1-MIRA"] = { name = "Mira Sturmfeder", level = 41, class = "MAGE", first = time() - 86400, last = time() - 3600,
        times = 4, seconds = 40000, bosses = 2 } }
    Aliases.Set("Kael Dornhain", "Kiki")
    SlashCmdList.FAMULUS("")
    mock.Click(navButton("Fellowship"))
    mock.Click(pageTab("Nearby"))
    mock.Advance(0.1)
    local list = window.nearby
    check(list and list:IsShown() and window.railScroll:IsShown() and list:GetWidth() == 600,
        "the tab: the list, the zones beside it")
    local sections = list.sections
    check(sections[1].title:GetText() == "Here in Tanaris  ·  2" and sections[2].title:GetText() == "Similar level  ·  2  ·  up to 5 levels apart"
        and sections[3].title:GetText() == "Also online  ·  1" and sections[4].title:GetText() == "Out of reach  ·  2  ·  other realm or faction",
        "here, then a similar level, then everyone else, and last who is out of reach: " .. sections[1].title:GetText())
    local rows = list.rows
    check(rows[1].name:GetText() == "Mira Sturmfeder" and rows[1].sub:GetText() == ns.UI.Colored("classMAGE", "Mage") .. "  ·  Friends list" and rows[1].level:GetText() == "41"
        and rows[1].diff:GetText() == "+1" and rows[1].place:GetText() == "Tanaris" and rows[1].badge:IsShown()
        and rows[1].badge.text:GetText() == "Trusted", "a fellow traveller first, with the bond")
    check(rows[2].name:GetText() == "Kiki" and rows[2].sub:GetText() == "Kael Dornhain  ·  " .. ns.UI.Colored("classROGUE", "Rogue") .. "  ·  Guild" and not rows[2].badge:IsShown(),
        "under an alias the name stands below it; no bond without a group together")
    check(rows[3].name:GetText() == "Borin Eisenbart" and rows[3].place:GetText() == "Desolace" and rows[4].name:GetText() == "Lysa Morgentau"
        and rows[4].diff:GetText() == "−2" and rows[5].name:GetText() == "Hagen Steinfaust", "the nearest level first")
    check(rows[7].name:GetText() == "Rhea Dunkelhain" and rows[7].sub:GetText() == ns.UI.Colored("classROGUE", "Rogue") .. "  ·  Realm PvP"
        and rows[7].place:GetText() == "Tanaris" and rows[7]:GetAlpha() < 1 and rows[1]:GetAlpha() == 1,
        "out of reach: the realm instead of the list, the zone not in the accent, faint: " .. tostring(rows[7].sub:GetText()))
    check(rows[6].name:GetText() == "Grosh Steinhauer" and rows[6].sub:GetText() == ns.UI.Colored("classWARRIOR", "Warrior") .. "  ·  "
        .. ns.UI.Colored("factionHorde", "Horde") and ns.UI.Colored("factionHorde", "Horde") == "|cffc7837fHorde|r",
        "the other faction in its colour: " .. tostring(rows[6].sub:GetText()))
    local places = window.rail.cards[1].places
    check(window.rail.cards[1].note:GetText() == "5 online" and places[1].name:GetText() == "Tanaris" and places[1].count:GetText() == "2"
        and places[1].line:GetText() == "Level 41–42" and places[2].count:GetText() == "1", "where your people are: the player's zone first")
    mock.Click(rows[2].whisper)
    check(mock.count("ChatFrameUtil.SendTell") == 1 and mock.calls[#mock.calls][2] == "Kael Dornhain-Realm"
        and rows[2].whisper.tip == "Whisper", "the button opens a whisper, with the realm; its tooltip names it")
    mock.Click(rows[7].whisper)
    check(mock.count("ChatFrameUtil.SendBNetTell") == 1 and mock.calls[#mock.calls][2] == "|Kq2|k", "out of reach, the whisper goes by Battle.net")
    mock.Click(rows[3].whisper)
    check(mock.count("ChatFrameUtil.SendBNetTell") == 2 and mock.calls[#mock.calls][2] == "|Kq1|k" and mock.count("ChatFrameUtil.SendTell") == 1,
        "a Battle.net friend gets a Battle.net whisper, even on the player's realm")
    mock.Click(rows[1])
    mock.Advance(0.1)
    check(window.fellows.card:IsShown() and window.fellows.card.name:GetText() == "Mira Sturmfeder",
        "a click on a fellow traveller opens your story")
    mock.Click(window.tabs.back)
    mock.Click(pageTab("Nearby"))
    enable("nearbyFriends", false)
    mock.Advance(0.1)
    check(not window.nearby:IsShown() and not window.railScroll:IsShown() and visibleRows()[1] and visibleRows()[1].item.kind == "info",
        "switched off, the tab says how to switch it on")
    check(ns:CountRegisteredEvents() == eventsBefore and mock.ActiveTimers() <= timersBefore + 1,
        "switched off, it listens to nothing and its ticker stops")

    SlashCmdList.FAMULUS("")
    Aliases.Set("Kael Dornhain", nil)
    FamulusDB.fellows = nil
    Feed.Clear()
    setState(stateBefore)
end

---------------------------------------------------------------------------
section("Pictures of the settings")
---------------------------------------------------------------------------

if not window:IsShown() then
    SlashCmdList.FAMULUS("")
end
mock.Advance(0.1)
-- A function of its own: the main chunk has no room for more locals.
;(function()
    local stage = window.detail.stage
    local PAGES = { "area_chronicle", "area_fellows", "area_aliases", "cat_general" }
    -- Every entry of every settings tab, in every language: its picture is
    -- drawn, and nothing goes wrong on the way.
    for _, language in ipairs(ns:GetLocaleCodes()) do
        ns:SetOption("general", "language", language)
        mock.Advance(0.1)
        local drawn, missing = 0, {}
        for _, page in ipairs(PAGES) do
            mock.Click(navButton(ns.L[page]))
            mock.Advance(0.1)
            for _, button in ipairs(window.tabs.buttons) do
                if button:IsShown() then
                    mock.Click(button)
                    mock.Advance(0.1)
                    if window.list and window.list:IsShown() then
                        for _, entry in ipairs(visibleEntries()) do
                            mock.Click(entry)
                            mock.Advance(0.05)
                            local name = entry.entry.item.preview
                            if name and stage:IsShown() and stage.current == name and stage.scenes[name]:IsVisible() then
                                drawn = drawn + 1
                            else
                                missing[#missing + 1] = entry.label:GetText()
                            end
                        end
                    end
                end
            end
        end
        check(#missing == 0 and drawn >= 20, "in " .. language .. " every entry of every settings tab has its picture (" .. drawn
            .. " drawn; without: " .. table.concat(missing, ", ") .. ")")
    end
    ns:SetOption("general", "language", "auto")
    mock.Advance(0.1)

    -- Chooses an entry by its name; returns the scene of its picture.
    local function choose(page, tab, label)
        mock.Click(navButton(ns.L[page]))
        mock.Advance(0.05)
        mock.Click(tabButton(ns.L[tab]))
        mock.Advance(0.05)
        for _, entry in ipairs(visibleEntries()) do
            if entry.label:GetText() == label then
                mock.Click(entry)
                mock.Advance(0.05)
                return stage.scenes[stage.current], entry
            end
        end
    end
    local function pictureStories()
        local list = {}
        for _, frame in ipairs(mock.frames) do
            if frame.story and frame:IsVisible() and inPicture(frame) then
                list[#list + 1] = frame.story
            end
        end
        return list
    end
    local function set(section, key, value)
        ns:SetOption(section, key, value)
        mock.Advance(0.1)
    end

    -- Chronicle: its own book with samples.
    choose("area_chronicle", "ui_tab_record", ns.L.f_ownJourney)
    local stories = pictureStories()
    check(stage.current == "book" and #stories == 2 and stories[1].title == "Reached level 40" and stories[1].big
        and stories[1].content == ns.UI.ChronicleCard and stories[1].onClick == nil,
        "record my journey: the chronicle's own book, the player's level-up as its milestone, nothing to click")
    choose("area_chronicle", "ui_tab_record", ns.L.f_companions)
    stories = pictureStories()
    check(stage.current == "friends" and #stories == 2 and stories[1].chip.text == "Mira Stormfeather"
        and stories[2].chip.text ~= nil, "follow my friends: their level-ups, each with the friend's name")
    choose("area_chronicle", "ui_tab_record", ns.L.g_chronicleNames)
    check(stage.current == "names" and pictureStories()[1].chip.text == "Dad (Borin Ironbeard)",
        "a friend under an alias, the name behind it: " .. tostring(pictureStories()[1].chip.text))
    set("general", "chronicleNames", false)
    check(pictureStories()[1].chip.text == "Dad", "without the name")
    set("general", "chronicleNames", true)
    local share = choose("area_chronicle", "ui_tab_record", ns.L.f_sharing)
    check(stage.current == "share" and not share.pills[1]:IsShown() and share.crests[1]:GetAlpha() < 1
        and share.names[2]:GetText() == "Mira Stormfeather", "share with friends, while it is off: faint, nothing travels")
    set("sharing", "enabled", true)
    check(share.pills[1]:IsShown() and share.pills[1].text:GetText() == "Level 40" and share.pills[2].text:GetText() == "Challenge"
        and share.caption.text:GetText() == "Only to friends and guild", "switched on, news goes both ways")
    -- The live feed's cards with their button to react, as in the feed, while reactions are on.
    local feed = choose("area_chronicle", "ui_tab_record", ns.L.f_liveFeed)
    check(stage.current == "feed" and feed.cards[1].react:IsShown() and not feed.cards[1].react.mouseEnabled,
        "with reactions on, a friend's card shows its button, which catches no mouse here")
    set("sharing", "enabled", false)
    check(not feed.cards[1].react:IsShown(), "without them, none")

    -- Fellow travellers: the overview's tiles; their options as lists.
    local fellows = choose("area_fellows", "ui_tab_record", ns.L.f_rememberFellows)
    check(stage.current == "fellows" and fellows.tiles[1].name:GetText() == "Mira Stormfeather" and fellows.tiles[3].numeral:GetText() == "III"
        and not fellows.list:IsShown(), "remember fellow travellers: the three closest as the overview's tiles")
    local function optionRow(key)
        for _, row in ipairs(visibleRows()) do
            if row.item.optionKey == key then
                return row
            end
        end
    end
    local raids = optionRow("raids")
    raids.scripts.OnEnter(raids)
    check(fellows.list:IsShown() and not fellows.holder:IsShown() and not fellows.list.rows[1].out and not fellows.list.rows[2].out
        and fellows.list.rows[3].out, "pointed at, \"raids\" shows which groups count")
    raids.scripts.OnLeave(raids)
    check(fellows.holder:IsShown() and not fellows.list:IsShown(), "and the tiles come back")
    set("rememberFellows", "friendsOnly", true)
    local only = optionRow("friendsOnly")
    only.scripts.OnEnter(only)
    check(fellows.list.rows[4].out and fellows.list.rows[4].note:GetText() == "not remembered" and not fellows.list.rows[1].out,
        "\"friends and guild only\": a stranger from a random group is not remembered")
    only.scripts.OnLeave(only)
    set("rememberFellows", "friendsOnly", false)
    local tidy = choose("area_fellows", "ui_tab_record", ns.L.ui_fellow_tidy)
    check(stage.current == "tidy" and not tidy.list.rows[1].out and tidy.list.rows[3].out and tidy.list.rows[4].out
        and tidy.list.rows[3].strike:IsShown(), "tidying up: who goes is struck out")
    -- Who is nearby: the feature's own cards on the feed's place.
    local near = choose("area_fellows", "ui_tab_record", ns.L.f_nearbyFriends)
    check(stage.current == "nearby" and near.cards[1].head:GetText() == "Kael and Mira" and near.cards[1].title:GetText() == "Also in Tanaris"
        and near.cards[2].head:GetText() == "Borin" and near.cards[2].title:GetText() == ns.L.ui_near_came:format("Tanaris")
        and near.cards[1]:GetAlpha() < 1,
        "who is nearby, while it is off: its cards, faint: " .. near.cards[1].title:GetText())
    set("nearbyFriends", "enabled", true)
    set("nearbyFriends", "guild", false)
    check(near.cards[1]:GetAlpha() == 1 and near.cards[1].head:GetText() == "Mira" and near.cards[1].title:GetText() == "Also in Tanaris",
        "switched on, without the guild: only friends")
    local cities = optionRow("cities")
    cities.scripts.OnEnter(cities)
    check(near.cards[1].head:GetText() == "Mira" and near.cards[1].title:GetText() == ns.L.ui_near_came:format("Stormwind")
        and near.cards[1]:GetAlpha() < 1
        and near.caption.text:GetText() == "Not in cities and inns", "pointed at \"cities\": a card in a city, faint while it would not come")
    cities.scripts.OnLeave(cities)
    set("nearbyFriends", "guild", true)
    set("nearbyFriends", "enabled", false)

    -- Aliases: the game's own places, with the alias where the feature puts it.
    local tooltip = choose("area_aliases", "ui_tab_display", ns.L.f_tooltipAliases)
    check(stage.current == "tooltip" and tooltip.tip.title:GetText() == "Borin Ironbeard" and tooltip.tip.alias:GetText() == "Dad"
        and tooltip.tip.label:GetText() == ns.L.tt_alias and tooltip.tip.outline:IsShown(), "the tooltip with the alias line")
    set("tooltipAliases", "enabled", false)
    check(not tooltip.tip.alias:IsShown(), "switched off, without it")
    set("tooltipAliases", "enabled", true)
    local menu = choose("area_aliases", "ui_tab_display", ns.L.f_aliasMenu)
    check(stage.current == "menu" and menu.menu.entries[3]:GetText() == ns.L.menu_alias_set and menu.menu.outline:IsShown(),
        "the player menu with the feature's entry")
    local bnet = choose("area_aliases", "ui_tab_display", ns.L.f_accountAliases)
    check(stage.current == "bnet" and bnet.card.name:GetText() == "Dad" and bnet.card.note:GetText() == ns.L.ui_preview_bnet_note,
        "a Battle.net friend under the alias")

    -- Settings.
    local areas = choose("cat_general", "ui_tab_general", ns.L.area_fellows)
    check(stage.current == "areas" and not areas.panel.rows[2].badge:IsShown(), "the main features in the sidebar")
    set("categories", "fellows", false)
    check(areas.panel.rows[2].badge:IsShown() and areas.panel.rows[2].badge.text:GetText() == "OFF", "a switched-off one marked OFF")
    set("categories", "fellows", true)
    local clock = choose("cat_general", "ui_tab_language", ns.L.g_timeFormat)
    check(stage.current == "time" and clock.cards[1].example:GetText() == "19:05 – 21:40" and clock.cards[2].example:GetText() == "7:05 PM – 9:40 PM"
        and clock.cards[1].shape.border.token == "accentLine" and clock.cards[2].shape.border.token == "cardBorder",
        "both clocks on an evening of play, the one chosen in the accent")
    set("general", "timeFormat", "12h")
    check(clock.cards[2].shape.border.token == "accentLine" and clock.cards[1].shape.border.token == "cardBorder", "the 12-hour clock chosen")
    set("general", "timeFormat", "24h")
    local dates = choose("cat_general", "ui_tab_language", ns.L.g_dateFormat)
    local today = date("%Y-%m-%d")
    check(stage.current == "date" and #dates.cards == 4 and dates.cards[1].example:GetText() == today
        and dates.cards[1].small:GetText() == "YYYY-MM-DD  ·  " .. ns.L.ui_preview_date_auto and dates.cards[1].shape.border.token == "accentLine"
        and dates.cards[3].small:GetText() == "MM/DD/YYYY",
        "every order with today's date, the language's one chosen: " .. dates.cards[1].small:GetText())
    set("general", "dateFormat", "{d}.{m}.{y}")
    check(dates.cards[2].shape.border.token == "accentLine" and dates.cards[2].small:GetText() == "DD.MM.YYYY"
        and dates.cards[1].shape.border.token == "cardBorder", "a chosen order in the accent, without the note")
    set("general", "language", "deDE")
    check(dates.cards[2].small:GetText() == "TT.MM.JJJJ", "the order in letters of the language")
    set("general", "language", "auto")
    set("general", "dateFormat", "auto")
    local lang = choose("cat_general", "ui_tab_language", ns.L.g_language)
    local function chosenPills()
        local chosen, names = {}, {}
        for _, pill in ipairs(lang.pills) do
            names[#names + 1] = pill.label:GetText()
            if pill.shape.border.token == "accentLine" then
                chosen[#chosen + 1] = pill.code
            end
        end
        return table.concat(chosen, " "), table.concat(names, " ")
    end
    local chosen, names = chosenPills()
    check(stage.current == "lang" and #lang.pills == #ns:GetLocaleCodes() and chosen == "enUS"
        and names == "English Deutsch Español Français Italiano"
        and lang.card.tagline:GetText() == "Together through Azeroth",
        "every language offered by its own name, the one shown chosen, the tagline in it: " .. names)
    set("general", "language", "frFR")
    chosen = chosenPills()
    check(chosen == "frFR" and lang.card.tagline:GetText() == ns.locales.frFR.ui_tagline
        and lang.card.small:GetText() == "Français", "chosen by hand, French: " .. lang.card.tagline:GetText())
    -- A language chosen before it was taken out of the list speaks the
    -- client's, and the dropdown says so.
    set("general", "language", "ukUA")
    local languageEntry
    for _, entry in ipairs(visibleEntries()) do
        if entry.label:GetText() == ns.L.g_language then
            languageEntry = entry
        end
    end
    check(ns:GetLocaleCode() == "enUS" and languageEntry and languageEntry.entry.item.get() == "auto",
        "a saved language that is not offered reads and speaks as the game client")
    set("general", "language", "auto")
    local chatfam = choose("cat_general", "ui_tab_general", ns.L.g_chatOutput)
    local function line(index)
        local parts = chatfam.lines[index]
        return parts[1]:GetText() .. parts[2]:GetText() .. parts[3]:GetText()
    end
    check(stage.current == "chatfam" and line(3) == "Famulus: Alias for Borin Ironbeard removed." and chatfam.lines[3].outline:IsShown(),
        "the addon's own line in the chat, as it writes it: " .. line(3))
    set("general", "chatOutput", false)
    check(line(3) == "[Guild] [Borin Ironbeard]: Who's coming to Uldaman?" and not chatfam.lines[4][1]:IsShown(), "switched off, without it")
    set("general", "chatOutput", true)
    local minimap = choose("cat_general", "ui_tab_general", ns.L.g_minimapButton)
    check(stage.current == "minimap" and minimap.button:IsShown() == (ns:GetOption("general", "minimapButton") == true),
        "the minimap, with the button while it is on")
    local profile = choose("cat_general", "ui_tab_general", ns.L.g_charProfile)
    check(stage.current == "profile" and profile.boxes[1].pills[1]:IsShown() and profile.boxes[2].empty:IsShown(),
        "settings for all characters, this one among them")
    local accent = choose("cat_general", "ui_tab_appearance", ns.L.g_accent)
    check(stage.current == "accent" and #accent.schemes == 5 and accent.schemes[1].shape.border.token == "schemeAccent_lemon"
        and accent.schemes[2].shape.border.token == "cardBorder", "every colour scheme in small, the chosen one in its accent")
    local embers = choose("cat_general", "ui_tab_appearance", ns.L.g_embers)
    check(stage.current == "embers" and embers.embers.wanted and embers.embers.playing and not embers.caption:IsShown(), "the sparks rise")
    set("general", "embers", false)
    check(not embers.embers.playing and embers.caption.text:GetText() == "Off: nothing moves", "and stop")
    set("general", "embers", true)
    local scale = choose("cat_general", "ui_tab_appearance", ns.L.g_windowScale)
    local chosen
    for _, frame in ipairs(scale.frames) do
        if frame:IsShown() and frame.outlineOn:IsShown() then
            chosen = frame.label:GetText()
        end
    end
    check(stage.current == "scale" and chosen == "100%", "the window at a few sizes, the chosen one marked")
    local known = true
    for _, token in ipairs({ "skyTop", "skyLow", "star", "moonRim", "moonBlue", "chatFamulus", "tooltipFill", "classWARRIOR",
        "minimapRim", "schemeWindow_mint", "schemeAccent2_amber", "bnetBlue" }) do
        known = known and ns.UI.colors[token] ~= nil
    end
    check(known, "the pictures' colours are in the theme")
end)()
mock.Click(navButton("Aliases"))

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
check(findCheck(result, "names", "online notices").status == "ok", "the report says whether the online and offline notices name the player as expected: "
    .. findCheck(result, "names", "online notices").detail)
setState({ guild = { { name = "Ena Fremd", guid = "Player-1-ENA", online = true }, { name = "Tom Hartwig" } } })
SlashCmdList.FAMULUS("test")
result = FamulusDB.selfTest
check(findCheck(result, "names", "guild roster").detail == "2 members (nil online), 1 listed as offline, 1 with a GUID",
    "for the guild: how many, how many offline, how many with a GUID: " .. findCheck(result, "names", "guild roster").detail)
setState({ bnFriends = {
    { battleTag = "Bo#1", games = { { characterName = "Borin Eisenbart" } } },
    { battleTag = "Pv#2", games = { { characterName = "Rhea Dunkelhain", mode = "PvP" } } },
    { battleTag = "Xx#3", games = { { characterName = "Odd Presence", richPresence = "Tanaris" } } },
} })
SlashCmdList.FAMULUS("test")
result = FamulusDB.selfTest
check(findCheck(result, "names", "Battle.net modes").status == "ok" and findCheck(result, "names", "Battle.net modes").detail
    == "own mode Normal; friends: Normal 1, PvP 1, 1 without; faction named for 3",
    "for Battle.net's modes: the player's own, the friends', the factions, without names: "
    .. findCheck(result, "names", "Battle.net modes").detail)
mock.state.noOwnGame = true
SlashCmdList.FAMULUS("test")
result = FamulusDB.selfTest
check(findCheck(result, "names", "Battle.net modes").status == "warn", "without the player's own mode the report warns")
mock.state.noOwnGame = nil
setState({})
SlashCmdList.FAMULUS("test")
result = FamulusDB.selfTest
check(result.idle.events == eventsBefore and ns:CountRegisteredEvents() == eventsBefore, "the test registers no events")
check(#mock.frames - framesBeforeTest == 2, "the test creates one hidden probe frame, with a Cooldown in it")
SlashCmdList.FAMULUS("test")
check(#mock.frames - framesBeforeTest == 2, "and reuses them on the next run")
check(findCheck(result, "chronicle", "ability spells").status == "warn" and findCheck(result, "chronicle", "special items").status == "warn",
    "without the API to look them up, the chronicle's IDs stay unchecked, and the report says so")
do -- whether the client knows the chronicle's spells and items
    local unknownSpell, unknownItem = 2651, 5178
    C_Spell = { GetSpellName = function(id) return id ~= unknownSpell and "Spell" or nil end }
    C_Item.GetItemInfoInstant = function(id) return id ~= unknownItem and id or nil end
    result = ns:RunSelfTest(true)
    local spells, items = findCheck(result, "chronicle", "ability spells"), findCheck(result, "chronicle", "special items")
    check(spells.status == "warn" and spells.detail:find("2651 (elunesGrace)", 1, true) ~= nil and spells.detail:find("^1 of %d+ unknown")
        and items.status == "warn" and items.detail:find("5178", 1, true) ~= nil,
        "the report names the spells and items this client does not know: " .. spells.detail .. "; " .. items.detail)
    unknownSpell, unknownItem = nil, nil
    result = ns:RunSelfTest(true)
    check(findCheck(result, "chronicle", "ability spells").status == "ok" and findCheck(result, "chronicle", "special items").status == "ok",
        "and is content when it knows them all: " .. findCheck(result, "chronicle", "ability spells").detail)
    C_Spell, C_Item.GetItemInfoInstant = nil, nil
end

-- A feature that needs API the client lacks is a failure in the report.
local needy = ns:NewFeature({ id = "fastLootProbe", category = "chronicle", requires = { "C_Nope.Missing" } })
mock.reset()
result = ns:RunSelfTest()
check(findCheck(result, "feature", "fastLootProbe").status == "fail" and result.summary.fail == 1, "missing required API fails the feature")
ns.features.fastLootProbe = nil
table.remove(ns.featureList)
check(needy.enabled == false, "the probe feature never ran")

-- Another addon in a version without what its feature needs (the regular Guildy, without the
-- fork's name API) is no failure: the feature is simply not offered.
do
    local api = GuildyAPI
    GuildyAPI = nil
    result = ns:RunSelfTest(true)
    local guildyCheck = findCheck(result, "feature", "guildyAliases")
    check(guildyCheck.status == "ok" and guildyCheck.detail:find("^addon Guildy lacks GuildyAPI%.RegisterNameFormatter") ~= nil
        and result.summary.fail == 0, "Guildy without its API is ok in the self-test, with the reason: " .. guildyCheck.detail)
    check(ns:BugReport():find("Cannot run: guildyAliases (Guildy without the API it needs)", 1, true) ~= nil,
        "the bug report says why it cannot run")
    GuildyAPI = api
    FamulusDB.selfTest = nil
end

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

-- The bug report: what helps to find a bug, as text to copy into an issue, without names.
do
    setState({ units = { player = { name = "Ilsa", surname = "Kerbholz" } },
        guild = { { name = "Mel Sternlicht", online = true, guid = "Player-1-MEL" } } })
    mock.reset()
    SlashCmdList.FAMULUS("report")
    local Report = ns.UI.Report
    local dialog = Report.Frame()
    local edit = dialog.edit
    local text = edit:GetText()
    check(Report.IsShown() and dialog.title:GetText() == "Bug report", "/fam report opens the bug report")
    check(#mock.chat == 0 and type(FamulusDB.selfTest) == "table", "it runs the self-test quietly, without a line in the chat")
    check(text:find("Famulus " .. ns.version .. ", client 1.60.1", 1, true) ~= nil and text:find("Data version " .. ns.DATA_VERSION .. ",", 1, true) ~= nil
        and text:find("\nOn: ", 1, true) ~= nil and text:find("\nSelf-test: ", 1, true) ~= nil
        and text:find("\nRunning: ", 1, true) ~= nil, "it names version, client, data version, features and self-test:\n" .. text)
    check(text:find("Developer mode is off: no log, no trace.", 1, true) ~= nil
        and dialog.hint:GetText():find(ns.L.ui_report_dev, 1, true) ~= nil,
        "without developer mode it says so, and the hint tells how to turn it on")
    check(dialog.hint:GetText():find("github.com/89pleasure/famulus/issues", 1, true) ~= nil, "the hint says where to paste it")
    check(mock.focus == edit and edit.highlighted and edit.multiLine, "the text is selected, ready for Ctrl+C")
    check(not text:find("Ilsa", 1, true) and not text:find("Kerbholz", 1, true) and not text:find("Mel", 1, true),
        "the report names nobody")
    check(edit:GetHeight() > 300 and dialog.scroll.content:GetHeight() == edit:GetHeight(), "the field scrolls as far as the text reaches")
    local warnings = FamulusDB.selfTest.summary.warn
    check(select(2, text:gsub("\n%[warn%] ", "")) == math.min(warnings, 40)
        and (warnings <= 40 or text:find("\n... and " .. (warnings - 40) .. " more", 1, true) ~= nil),
        "it lists at most 40 checks that are not ok, and says how many more there are")

    -- Read only: what is typed goes; a click selects it all again.
    edit.text, edit.highlighted = "typed", false
    edit.scripts.OnTextChanged(edit, true)
    check(edit:GetText() == text and edit.highlighted, "typing changes nothing, and the text is selected again")
    edit.highlighted = false
    edit.scripts.OnMouseUp(edit)
    check(edit.highlighted, "a click into the text selects it all again")
    edit.scripts.OnEscapePressed(edit)
    check(not Report.IsShown() and mock.focus ~= edit, "Escape closes it")

    -- In developer mode the log and the newest lines of the trace come along; "|" never does.
    SlashCmdList.FAMULUS("dev")
    ns:DevLog("SHARE", "throttled | again")
    ns:DevTrace("SEND", "sent H to AW-799")
    local frames = #mock.frames
    mock.reset()
    SlashCmdList.FAMULUS("report")
    text = edit:GetText()
    check(text:find("Developer log (1):", 1, true) ~= nil and text:find("SHARE  throttled / again", 1, true) ~= nil
        and text:find("Trace (the last 2 of 2 lines):", 1, true) ~= nil and text:find("SEND  sent H to AW-799", 1, true) ~= nil
        and not text:find("|", 1, true), "in developer mode the log and the trace come along, without \"|\":\n" .. text)
    check(not dialog.hint:GetText():find(ns.L.ui_report_dev, 1, true), "the hint no longer asks for developer mode")
    check(#mock.frames == frames, "the window is built once and reused")

    -- While sharing runs, it counts who is linked and what waits, never by name.
    enable("sharing")
    SlashCmdList.FAMULUS("report")
    text = edit:GetText()
    check(text:find("\nSharing: %d+ linked, %d+ friends and guild members online, %d+ messages waiting") ~= nil
        and text:find("sharing", 1, true) ~= nil, "with sharing on, the report counts its state")
    enable("sharing", false)
    SlashCmdList.FAMULUS("dev")
    dialog:Hide()

    -- "About" has a button for it.
    if not window:IsShown() then
        SlashCmdList.FAMULUS("")
    end
    mock.Click(navButton("About"))
    local row
    for _, each in ipairs(visibleRows()) do
        if each.item.id == "report" then
            row = each
        end
    end
    check(row ~= nil and row.label:GetText() == "Bug report" and row.action.label:GetText() == "Copy bug report",
        "\"About\" offers the bug report")
    mock.Click(row.action)
    check(Report.IsShown() and mock.focus == edit, "its button opens the report")
    dialog:Hide()
    window:Hide()
    FamulusDB.selfTest = nil
    setState({})
    check(ns:CountRegisteredEvents() == eventsBefore, "the report leaves nothing listening")
end

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
