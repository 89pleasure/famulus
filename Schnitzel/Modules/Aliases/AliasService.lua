-- AliasService: the player's own names for other players.
--
-- An alias belongs to a character name and is only ever shown to the player
-- who set it; nothing is sent to anyone. The list is account-wide data, not
-- a setting: it lives in SchnitzelDB.aliases, outside the profiles, so
-- "reset page" and switching profiles leave it alone.
--
--   SchnitzelDB.aliases = { [key] = { name = "Jaina Proudmoore", alias = "Anna" } }
--
-- The key is the full character name in lower case with every separator
-- turned into "-". The client hands out the same name in several spellings
-- ("First Last" on unit frames, "First-Last" in chat links), and a name typed
-- by hand should match whatever its capitals are.

local _, ns = ...

local AliasService = {}
ns.AliasService = AliasService

local IsPlainText = ns.ChatService.IsPlainText

local MAX_ALIAS_BYTES = 48

local list -- sorted copy for the window, rebuilt after a change
local count = 0

local function Store(create)
    local global = ns.global
    if not global then
        return nil
    end
    if type(global.aliases) ~= "table" then
        if not create then
            return nil
        end
        global.aliases = {}
    end
    return global.aliases
end

local function Trim(text)
    return (string.gsub(string.gsub(text, "^%s+", ""), "%s+$", ""))
end

-- First name and surname as one name. Without a surname, name is returned
-- as it is, so a full name can be passed in one piece as well.
function AliasService.FullName(name, surname)
    if not IsPlainText(name) then
        return nil
    end
    if IsPlainText(surname) then
        return name .. " " .. surname
    end
    return name
end

function AliasService.Key(name, surname)
    local full = AliasService.FullName(name, surname)
    if not full then
        return nil
    end
    full = string.gsub(Trim(full), "[%s%-]+", "-")
    if full == "" then
        return nil
    end
    return string.lower(full)
end

-- The alias for a character, or nil. Safe to call with secret values and
-- cheap while no alias is stored.
function AliasService.Get(name, surname)
    if count == 0 then
        return nil
    end
    local key = AliasService.Key(name, surname)
    local entry = key and Store()[key]
    return entry and entry.alias or nil
end

-- Escape sequences would let an alias carry colours, textures or links into
-- chat lines and tooltips; an alias is plain text.
local function CleanAlias(alias)
    if not IsPlainText(alias) then
        return nil
    end
    alias = Trim(string.gsub(string.gsub(alias, "|", ""), "[%c]", " "))
    if #alias > MAX_ALIAS_BYTES then
        alias = string.sub(alias, 1, MAX_ALIAS_BYTES)
        -- Do not cut a UTF-8 character in half.
        alias = string.gsub(alias, "[\192-\255][\128-\191]*$", function(tail)
            local lead = string.byte(tail)
            local need = (lead >= 240 and 4) or (lead >= 224 and 3) or 2
            return #tail == need and tail or ""
        end)
    end
    return alias ~= "" and alias or nil
end

-- Sets the alias of a character; an empty or missing alias removes it.
-- Returns true if the list changed.
function AliasService.Set(name, alias)
    local key = AliasService.Key(name)
    if not key then
        return false
    end
    alias = CleanAlias(alias)
    local store = Store(alias ~= nil)
    local entry = store and store[key]
    if alias then
        name = string.gsub(Trim(name), "%s+", " ")
        if entry and entry.alias == alias and entry.name == name then
            return false
        end
        if not entry then
            count = count + 1
        end
        store[key] = { name = name, alias = alias }
    else
        if not entry then
            return false
        end
        store[key] = nil
        count = count - 1
        if count == 0 then
            ns.global.aliases = nil
        end
    end
    list = nil
    ns:Fire("ALIASES_CHANGED")
    return true
end

function AliasService.Count()
    return count
end

-- All aliases as an array of { name = ..., alias = ... }, sorted by alias.
-- The array is shared; callers must not change it.
function AliasService.List()
    if not list then
        list = {}
        local store = Store()
        if store then
            for _, entry in pairs(store) do
                list[#list + 1] = entry
            end
            table.sort(list, function(a, b)
                local left, right = string.lower(a.alias), string.lower(b.alias)
                if left ~= right then
                    return left < right
                end
                return a.name < b.name
            end)
        end
    end
    return list
end

-- How an alias is written where it replaces a name: alone, or with the
-- character's name behind it.
function AliasService.Format(alias, name, style)
    if style == "both" then
        return alias .. " (" .. name .. ")"
    end
    return alias
end

ns:On("DATABASE_READY", function()
    count, list = 0, nil
    local store = Store()
    if not store then
        return
    end
    -- The saved file can be edited by hand; drop what is not an alias.
    for key, entry in pairs(store) do
        if type(key) == "string" and type(entry) == "table" and type(entry.name) == "string" and type(entry.alias) == "string" then
            count = count + 1
        else
            store[key] = nil
        end
    end
    if count == 0 then
        ns.global.aliases = nil
    end
end)
