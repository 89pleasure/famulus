-- Settings storage.
--   FamulusDB      account-wide: { dataVersion = n, profile = {...}, window = {...}, seen = bool,
--                  welcome = bool (the welcome page was answered, UI/Welcome.lua) }
--   FamulusCharDB  per character: { dataVersion = n, useCharacter = bool, profile = {...} }
-- A profile is { [section] = { [key] = value } }. Only values that differ
-- from the default are stored, so the saved file stays tiny and a changed
-- default in a later version reaches everybody who never touched the option.

local ADDON_NAME, ns = ...

local defaults = {
    general = {
        chatOutput = true,
        language = "auto",
        timeFormat = "24h", -- or "12h" (Core/Locale.lua)
        dateFormat = "auto", -- as the language, or one of ns.DATE_FORMATS
        minimapButton = true,
        minimapAngle = 215,
        windowScale = 100,
        accent = "lemon",
        embers = true,
        chronicleNames = true, -- the chronicle shows "Alias (Character Name)"
    },
}
ns.defaults = defaults

local profile -- the active profile table; nil until ADDON_LOADED

function ns:RegisterDefaults(section, values)
    local target = defaults[section]
    if not target then
        target = {}
        defaults[section] = target
    end
    for key, value in pairs(values) do
        target[key] = value
    end
end

function ns:GetDefault(section, key)
    local values = defaults[section]
    return values and values[key]
end

function ns:GetOption(section, key)
    local values = profile and profile[section]
    local value = values and values[key]
    if value == nil then
        local base = defaults[section]
        return base and base[key]
    end
    return value
end

function ns:SetOption(section, key, value)
    if not profile or self:GetOption(section, key) == value then
        return
    end
    local values = profile[section]
    if value == self:GetDefault(section, key) then
        if values then
            values[key] = nil
            if next(values) == nil then
                profile[section] = nil
            end
        end
    else
        if not values then
            values = {}
            profile[section] = values
        end
        values[key] = value
    end
    self:Fire("OPTION_CHANGED", section, key, value)
end

function ns:IsDefault(section, key)
    return self:GetOption(section, key) == self:GetDefault(section, key)
end

-- True while nothing in the section differs from its defaults. Only
-- differences are stored, so an untouched section is simply absent.
function ns:IsSectionDefault(section)
    local values = profile and profile[section]
    return values == nil or next(values) == nil
end

-- Puts every option of the given sections (or of all sections) back to its
-- default, announcing each change so features and the window follow along.
function ns:ResetSections(sections)
    if not profile then
        return
    end
    if not sections then
        sections = {}
        for section in pairs(profile) do
            sections[#sections + 1] = section
        end
    end
    for _, section in ipairs(sections) do
        local values = profile[section]
        if values then
            local keys = {}
            for key in pairs(values) do
                keys[#keys + 1] = key
            end
            for _, key in ipairs(keys) do
                self:SetOption(section, key, self:GetDefault(section, key))
            end
        end
    end
end

local function CopyTable(source)
    local copy = {}
    for key, value in pairs(source) do
        copy[key] = type(value) == "table" and CopyTable(value) or value
    end
    return copy
end

function ns:UsesCharacterProfile()
    return FamulusCharDB ~= nil and FamulusCharDB.useCharacter == true
end

function ns:SetUseCharacterProfile(enabled)
    enabled = enabled and true or false
    if not profile or enabled == self:UsesCharacterProfile() then
        return
    end
    if enabled then
        if type(FamulusCharDB.profile) ~= "table" then
            FamulusCharDB.profile = CopyTable(FamulusDB.profile)
        end
        FamulusCharDB.useCharacter = true
        profile = FamulusCharDB.profile
    else
        FamulusCharDB.useCharacter = false
        profile = FamulusDB.profile
    end
    self:Fire("PROFILE_CHANGED")
end

-- Saved data carries a version, so a later Famulus knows what shape an older file has. Step n
-- brings a file from version n - 1 to n. Each step has a part for the account's FamulusDB and one
-- for a character's FamulusCharDB, either may be missing. Each file keeps its own version, because
-- a character that has not logged in for a while catches up only when it does.
-- Only add steps at the end, and never change one that has been released: players' files have
-- already run it. A step must cope with any field missing.

-- For step 2: gives every key of a map its lower-case form (ns.Lower). Of two keys that
-- become the same, the one already in lower case stays.
local function LowerKeys(map)
    if type(map) ~= "table" then
        return
    end
    local moved = {}
    for key in pairs(map) do
        if type(key) == "string" and ns.Lower(key) ~= key then
            moved[#moved + 1] = key
        end
    end
    for _, key in ipairs(moved) do
        local lower = ns.Lower(key)
        if map[lower] == nil then
            map[lower] = map[key]
        end
        map[key] = nil
    end
end

local MIGRATIONS = {
    -- 1: the journal left with the quality-of-life features (2026-11-23).
    { account = function(db) db.journal = nil end },
    -- 2: the keys of names and BattleTags are in lower case beyond A-Z as well ("Émile" as
    -- "émile"), so that a name typed by hand matches whatever its capitals are (2026-11-28).
    { account = function(db)
        LowerKeys(db.aliases)
        LowerKeys(db.accountAliases)
        if type(db.accountAliases) == "table" then
            for _, account in pairs(db.accountAliases) do
                LowerKeys(type(account) == "table" and account.chars or nil)
            end
        end
        LowerKeys(type(db.chronicle) == "table" and db.chronicle.links or nil)
    end },
}
ns.MIGRATIONS = MIGRATIONS
ns.DATA_VERSION = #MIGRATIONS

-- Brings one saved file ("account" or "character") up to DATA_VERSION and returns it. A new file
-- starts at the current version and skips every step. A file from a newer Famulus is left as it
-- is, so going back to an older version does not run old steps on newer data.
function ns.MigrateSaved(saved, part)
    if type(saved) ~= "table" then
        return { dataVersion = ns.DATA_VERSION }
    end
    local version = tonumber(saved.dataVersion) or 0
    for step = version + 1, ns.DATA_VERSION do
        local migrate = MIGRATIONS[step][part]
        if migrate then
            migrate(saved)
        end
        saved.dataVersion = step -- a step that fails leaves the file at the last one that ran
    end
    return saved
end

local function InitDatabase()
    FamulusDB = ns.MigrateSaved(FamulusDB, "account")
    if type(FamulusDB.profile) ~= "table" then
        FamulusDB.profile = {}
    end
    FamulusCharDB = ns.MigrateSaved(FamulusCharDB, "character")
    if FamulusCharDB.useCharacter and type(FamulusCharDB.profile) == "table" then
        profile = FamulusCharDB.profile
    else
        FamulusCharDB.useCharacter = false
        profile = FamulusDB.profile
    end
    ns.global = FamulusDB
end

local loader = {}

ns:RegisterEvent("ADDON_LOADED", loader, function(_, _, name)
    if name ~= ADDON_NAME then
        return
    end
    ns:UnregisterEvent("ADDON_LOADED", loader)
    InitDatabase()
    ns:SetLocale(ns:GetOption("general", "language"))
    ns:Fire("DATABASE_READY")
end)

ns:On("OPTION_CHANGED", function(section, key, value)
    if section == "general" and key == "language" then
        ns:SetLocale(value)
    end
end)

ns:On("PROFILE_CHANGED", function()
    ns:SetLocale(ns:GetOption("general", "language"))
end)
