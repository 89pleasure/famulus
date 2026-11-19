-- ChronicleService: the story of the player's characters and of their
-- companions, one entry per event worth remembering.
--
-- The features of the category record events here; the window reads them.
-- Like the journal this is account-wide data, not a setting: it lives in
-- FamulusDB.chronicle, outside the profiles. Entries hold a kind and its
-- values, never finished text, so the chronicle follows a change of language.
--
--   FamulusDB.chronicle = {
--       entries = { { t = <time>, k = "<kind>", c = "<own character>", ... }, ... },
--       friends = { ["<guid>"] = <last known level>, ... },
--   }
--   FamulusCharDB.zones = { ["<zone name>"] = true, ... }   -- seen by this character
--
-- An entry about a companion carries `who` (their character name) instead
-- of `c`. Nothing is sent to anyone; everything here was seen by this client.

local _, ns = ...
local L = ns.L

local ChronicleService = {}
ns.ChronicleService = ChronicleService

local IsPlainText = ns.ChatService.IsPlainText

local MAX_ENTRIES = 2000
local CLOCK_SLACK = 300 -- seconds a companion's clock may run ahead of ours
local MAX_AGE = 90 * 86400 -- older news is filed under "now"

local character -- "First Last" of the character that is playing

-- A zone for a sentence, or nil.
local function Place(entry)
    return type(entry.zone) == "string" and entry.zone or nil
end

-- A companion's name as the player knows them: the alias, if there is one.
local function Companion(entry)
    local name = entry.who or L.j_someone
    local alias = ns.AliasService and ns.AliasService.Get(name)
    if alias then
        return alias, name
    end
    return name, nil
end

-- title(entry): the headline. detail(entry): the line below it, or nil.
-- An entry with `who` tells of a companion and names them in the headline.
local kinds = {
    level = {
        title = function(e)
            if e.who then
                return L.c_their_level:format((Companion(e)), tonumber(e.level) or 0)
            end
            return L.c_level:format(tonumber(e.level) or 0)
        end,
        detail = function(e)
            return Place(e) and L.c_in:format(Place(e)) or nil
        end,
    },
    death = {
        title = function(e)
            if e.who then
                return Place(e) and L.c_their_death:format((Companion(e)), Place(e)) or L.c_their_death_nowhere:format((Companion(e)))
            end
            return Place(e) and L.c_death:format(Place(e)) or L.c_death_nowhere
        end,
        detail = function(e)
            return e.level and L.c_at_level:format(tonumber(e.level) or 0) or nil
        end,
    },
    boss = {
        title = function(e)
            if e.who then
                return L.c_their_boss:format((Companion(e)), e.name or L.c_a_foe)
            end
            return L.c_boss:format(e.name or L.c_a_foe)
        end,
        detail = function(e)
            return Place(e) and L.c_in:format(Place(e)) or nil
        end,
    },
    achievement = {
        title = function(e)
            if e.who then
                return L.c_their_achievement:format((Companion(e)), e.name or L.c_a_challenge)
            end
            return L.c_achievement:format(e.name or L.c_a_challenge)
        end,
    },
    zone = {
        title = function(e)
            if e.who then
                return L.c_their_zone:format((Companion(e)), Place(e) or "?")
            end
            return L.c_zone:format(Place(e) or "?")
        end,
        detail = function(e)
            return e.level and L.c_at_level:format(tonumber(e.level) or 0) or nil
        end,
    },
}
-- Seen on the friends list rather than told by the friend: a level-up.
kinds.friendLevel = kinds.level

local function Store(create)
    local global = ns.global
    if not global then
        return nil
    end
    local chronicle = global.chronicle
    if type(chronicle) ~= "table" then
        if not create then
            return nil
        end
        chronicle = {}
        global.chronicle = chronicle
    end
    if type(chronicle.entries) ~= "table" then
        chronicle.entries = {}
    end
    if type(chronicle.friends) ~= "table" then
        chronicle.friends = {}
    end
    return chronicle
end

-- Writes an event down. kind: see `kinds`; entry: its values. Strings that
-- are secret or empty are dropped. An entry with `who` tells of a companion.
function ChronicleService.Add(kind, entry)
    if not kinds[kind] then
        return
    end
    local chronicle = Store(true)
    if not chronicle then
        return
    end
    entry = entry or {}
    for key, value in pairs(entry) do
        if ns.IsSecret(value) or value == "" then
            entry[key] = nil
        end
    end
    entry.k = kind
    -- An entry a companion sent brings its own time; it must be plausible.
    local now = time()
    local when = tonumber(entry.t)
    if not when or when > now + CLOCK_SLACK or when < now - MAX_AGE then
        when = now
    end
    entry.t = when
    if not entry.who then
        entry.c = character
    end

    -- Entries stay sorted by time; one that arrives late finds its place.
    local entries = chronicle.entries
    local index = #entries + 1
    while index > 1 and entries[index - 1].t > when do
        index = index - 1
    end
    -- The same event may arrive twice (live and again when catching up).
    for i = index - 1, 1, -1 do
        local old = entries[i]
        if old.t < when then
            break
        end
        if old.k == kind and old.who == entry.who and old.c == entry.c then
            return false
        end
    end
    table.insert(entries, index, entry)
    if #entries > MAX_ENTRIES then
        table.remove(entries, 1)
    end
    ns:Fire("CHRONICLE_CHANGED", entry)
    return true
end

-- The player's own entries newer than `since`, oldest first, at most `limit`
-- of the newest. For companions who catch up on what they missed.
function ChronicleService.OwnSince(since, limit)
    local entries, found = ChronicleService.Entries(), {}
    for i = #entries, 1, -1 do
        local entry = entries[i]
        if entry.t <= since or #found == limit then
            break
        end
        if entry.who == nil and entry.c == character then
            table.insert(found, 1, entry)
        end
    end
    return found
end

-- Time of the newest entry about a companion, or 0.
function ChronicleService.NewestFrom(who)
    local entries = ChronicleService.Entries()
    for i = #entries, 1, -1 do
        if entries[i].who == who then
            return entries[i].t
        end
    end
    return 0
end

-- What a companion told about themselves: { t = <time>, level = ..., stats =
-- { [<statistic id>] = <number> } }, by character name. Pass a profile to
-- store it.
function ChronicleService.Profile(who, profile)
    local chronicle = Store(profile ~= nil)
    if not chronicle or not IsPlainText(who) then
        return nil
    end
    if type(chronicle.profiles) ~= "table" then
        if not profile then
            return nil
        end
        chronicle.profiles = {}
    end
    if profile then
        profile.t = time()
        chronicle.profiles[who] = profile
        ns:Fire("CHRONICLE_CHANGED")
    end
    return chronicle.profiles[who]
end

-- Names of all companions with a profile, sorted.
function ChronicleService.ProfileNames()
    local chronicle = Store()
    local names = {}
    if chronicle and type(chronicle.profiles) == "table" then
        for who, profile in pairs(chronicle.profiles) do
            if type(who) == "string" and type(profile) == "table" then
                names[#names + 1] = who
            end
        end
        table.sort(names)
    end
    return names
end

function ChronicleService.Character()
    return character
end

-- The entries, oldest first. The array is shared; callers must not change it.
function ChronicleService.Entries()
    local chronicle = Store()
    return chronicle and chronicle.entries or {}
end

-- Headline and detail line of an entry.
function ChronicleService.Text(entry)
    local spec = kinds[entry.k]
    if not spec then
        return "", nil
    end
    local detail = spec.detail and spec.detail(entry) or nil
    -- Under an alias, the character's name stands in the detail line.
    if entry.who then
        local _, realName = Companion(entry)
        if realName then
            detail = detail and (realName .. "  ·  " .. detail) or realName
        end
    end
    return spec.title(entry), detail
end

-- A companion as the player knows them: alias first, then the name.
ChronicleService.Companion = Companion

-- True for the player's own characters, false for a companion's event.
function ChronicleService.IsOwn(entry)
    return entry.who == nil
end

-- The character an own entry belongs to, if it is not the one playing.
function ChronicleService.OtherCharacter(entry)
    if entry.c and entry.c ~= character then
        return entry.c
    end
    return nil
end

-- Last known level of a companion (by GUID); pass a level to remember it.
function ChronicleService.FriendLevel(guid, level)
    local chronicle = Store(level ~= nil)
    if not chronicle or not IsPlainText(guid) then
        return nil
    end
    if level then
        chronicle.friends[guid] = level
    end
    return chronicle.friends[guid]
end

-- Marks a zone as seen by this character; true if it was new.
function ChronicleService.SeeZone(zone)
    if not IsPlainText(zone) or type(FamulusCharDB) ~= "table" then
        return false
    end
    if type(FamulusCharDB.zones) ~= "table" then
        FamulusCharDB.zones = {}
    end
    if FamulusCharDB.zones[zone] then
        return false
    end
    FamulusCharDB.zones[zone] = true
    return true
end

function ChronicleService.Clear()
    if ns.global then
        ns.global.chronicle = nil
    end
    ns:Fire("CHRONICLE_CHANGED")
end

ns:On("DATABASE_READY", function()
    local chronicle = Store()
    if not chronicle then
        return
    end
    -- The saved file can be edited by hand; drop what is not an entry.
    local entries, kept = chronicle.entries, {}
    for i = 1, #entries do
        local entry = entries[i]
        if type(entry) == "table" and type(entry.t) == "number" and kinds[entry.k] then
            kept[#kept + 1] = entry
        end
    end
    while #kept > MAX_ENTRIES do
        table.remove(kept, 1)
    end
    chronicle.entries = kept
end)

ns:On("LOGIN", function()
    local name, surname = UnitName("player")
    if IsPlainText(name) then
        character = IsPlainText(surname) and (name .. " " .. surname) or name
    end
end)
