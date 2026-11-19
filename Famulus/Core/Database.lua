-- Settings storage.
--   FamulusDB      account-wide: { profile = {...}, window = {...}, seen = bool }
--   FamulusCharDB  per character: { useCharacter = bool, profile = {...} }
-- A profile is { [section] = { [key] = value } }. Only values that differ
-- from the default are stored, so the saved file stays tiny and a changed
-- default in a later version reaches everybody who never touched the option.

local ADDON_NAME, ns = ...

local defaults = {
    general = {
        chatOutput = true,
        pauseModifier = "SHIFT",
        language = "auto",
        minimapButton = true,
        minimapAngle = 215,
        windowScale = 100,
        accent = "lemon",
        embers = true,
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

-- The switch of a mirrored feature belongs to the game's option
-- (Core/GameOptions.lua): it never counts as a change and a reset leaves it,
-- so resetting a page cannot switch the game's option off.
local function FollowsGame(section, key)
    local feature = key == "enabled" and ns.features and ns.features[section]
    return feature and feature.mirror ~= nil or false
end

-- True while nothing in the section differs from its defaults. Only
-- differences are stored, so an untouched section is simply absent.
function ns:IsSectionDefault(section)
    local values = profile and profile[section]
    if values then
        for key in pairs(values) do
            if not FollowsGame(section, key) then
                return false
            end
        end
    end
    return true
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
                if not FollowsGame(section, key) then
                    keys[#keys + 1] = key
                end
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

local function InitDatabase()
    if type(FamulusDB) ~= "table" then
        FamulusDB = {}
    end
    if type(FamulusDB.profile) ~= "table" then
        FamulusDB.profile = {}
    end
    if type(FamulusCharDB) ~= "table" then
        FamulusCharDB = {}
    end
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
