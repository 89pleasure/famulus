-- ChronicleService: the story of the player's characters and of their
-- companions, one entry per event worth remembering.
--
-- The features of the category record events here; the window reads them.
-- Like the alias list this is account-wide data, not a setting: it lives in
-- FamulusDB.chronicle, outside the profiles. Entries hold a kind and its
-- values, never finished text, so the chronicle follows a change of language.
--
--   FamulusDB.chronicle = {
--       entries = { { t = <time>, k = "<kind>", c = "<own character>", ... }, ... },
--       friends = { ["<guid>"] = <last known level>, ... },
--       links = { ["<name key>"] = { name = ..., t = <time> }, ... },
--   }
--   FamulusCharDB.zones = { ["<zone name>"] = true, ... }   -- seen by this character
--   FamulusCharDB.skills = { [<skill line>] = <last known rank>, ... }
--   FamulusCharDB.abilities = { ["<ability id>"] = true, ... }   -- learned by this character
--   FamulusCharDB.items = { [<item ID>] = true, ... }            -- owned once by this character
--
-- An entry about a companion carries `who` (their character name) instead
-- of `c`, and `via` (who passed it on) when it did not come from them.
-- Nothing is sent from here; Modules/Chronicle/Sharing.lua does that.

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
    local name = entry.who or L.c_someone
    local alias = ns.AliasService and ns.AliasService.Get(name)
    if alias then
        return alias, name
    end
    return name, nil
end

-- Abilities whose learning is an event, recognised by their spell. To add
-- one: a line here and its two sentences per language (c_ability_<id>,
-- c_their_ability_<id>). Modules/Chronicle/OwnJourney.lua does the looking.
--   id       name of the ability in entries, texts and FamulusCharDB.abilities
--   spell    the spell the character knows once it is learned
--   skill    optional { line = <skill line>, rank = <points> }: counts as
--            learned too, where the client does not list the spell
--   picture  optional name in UI.media for the book
--   big      optional: a milestone of the book
ChronicleService.abilities = {
    { id = "riding", spell = 33388, skill = { line = 762, rank = 75 }, picture = "horseshoe", big = true },
    { id = "ridingFast", spell = 33391, skill = { line = 762, rank = 150 }, picture = "horseshoe", big = true },
}

-- Items whose first arrival in the character's bags is an event, recognised
-- by their item ID. To add one: a line here; the sentence names the item as
-- the game does. Modules/Chronicle/OwnJourney.lua does the looking.
--   item     the game's item ID
--   picture  optional name in UI.media for the book (default: a chest)
--   big      optional: a milestone of the book
ChronicleService.items = {
    { item = 211527 }, -- the sleeping bag
}

function ChronicleService.Item(itemID)
    for _, item in ipairs(ChronicleService.items) do
        if item.item == itemID then
            return item
        end
    end
    return nil
end

-- The name of an entry's item: as this client names it, else as the one
-- who told of it did.
local function ItemName(entry)
    local id = tonumber(entry.item)
    local name = id and C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
    if IsPlainText(name) then
        return name
    end
    return entry.name or L.c_an_item
end

function ChronicleService.Ability(id)
    for _, ability in ipairs(ChronicleService.abilities) do
        if ability.id == id then
            return ability
        end
    end
    return nil
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
    ability = {
        -- A known ability has its own sentence; one this version does not
        -- know (a companion's newer addon) is named as the game names it.
        title = function(e)
            local known = type(e.ability) == "string" and ChronicleService.Ability(e.ability)
            if e.who then
                if known then
                    return L["c_their_ability_" .. e.ability]:format((Companion(e)))
                end
                return L.c_their_profession:format((Companion(e)), e.name or L.c_an_ability)
            end
            if known then
                return L["c_ability_" .. e.ability]
            end
            return L.c_profession:format(e.name or L.c_an_ability)
        end,
        detail = function(e)
            return e.level and L.c_at_level:format(tonumber(e.level) or 0) or nil
        end,
    },
    item = {
        title = function(e)
            if e.who then
                return L.c_their_item:format((Companion(e)), ItemName(e))
            end
            return L.c_item:format(ItemName(e))
        end,
        detail = function(e)
            return Place(e) and L.c_in:format(Place(e)) or nil
        end,
    },
    profession = {
        title = function(e)
            if e.who then
                return L.c_their_profession:format((Companion(e)), e.name or L.c_a_craft)
            end
            return L.c_profession:format(e.name or L.c_a_craft)
        end,
    },
    skill = {
        title = function(e)
            if e.who then
                return L.c_their_skill:format((Companion(e)), e.name or L.c_a_craft, tonumber(e.rank) or 0)
            end
            return L.c_skill:format(e.name or L.c_a_craft, tonumber(e.rank) or 0)
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
        if old.k == kind and old.who == entry.who and old.c == entry.c and old.skill == entry.skill
            and old.rank == entry.rank and old.ability == entry.ability
            and old.item == entry.item then
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
        if entry.who == nil and entry.c == character and not entry.demo then
            table.insert(found, 1, entry)
        end
    end
    return found
end

-- Time of the newest entry about a companion, or 0. Entries another
-- companion passed on (`via`) count only with withRelayed: the relay may
-- have missed some, so they must not move the mark the companion answers to.
function ChronicleService.NewestFrom(who, withRelayed)
    local entries = ChronicleService.Entries()
    for i = #entries, 1, -1 do
        local entry = entries[i]
        if entry.who == who and (withRelayed or not entry.via) then
            return entry.t
        end
    end
    return 0
end

-- Companions whose addon answered this one directly, by name key:
-- { name = <character name>, t = <time> }. Such an answer comes only from
-- someone who has the player on their friends list or shares their guild.
-- Pass a name to record a contact now.
function ChronicleService.Link(key, name)
    local chronicle = Store(name ~= nil)
    if not chronicle then
        return nil
    end
    if type(chronicle.links) ~= "table" then
        if not name then
            return nil
        end
        chronicle.links = {}
    end
    if name then
        chronicle.links[key] = { name = name, t = time() }
    end
    return chronicle.links[key]
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
-- Headline and detail of an entry. anonymous: the headline does not name
-- the companion ("Reached level 20" instead of "Jaina reaches level 20"),
-- for places that say whose event it is by other means.
function ChronicleService.Text(entry, anonymous)
    local spec = kinds[entry.k]
    if not spec then
        return "", nil
    end
    local told = entry
    if anonymous and entry.who then
        told = setmetatable({ who = false }, { __index = entry })
    end
    local detail = spec.detail and spec.detail(entry) or nil
    -- Under an alias, the character's name stands in the detail line.
    if entry.who then
        local _, realName = Companion(entry)
        if realName then
            detail = detail and (realName .. "  ·  " .. detail) or realName
        end
        if entry.via then
            local via = L.c_via:format(entry.via)
            detail = detail and (detail .. "  ·  " .. via) or via
        end
    end
    return spec.title(told), detail
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

-- Remembers the rank of one of this character's professions; returns the
-- rank known before, or nil if the profession is new here.
function ChronicleService.SeeSkill(skillLine, rank)
    if type(FamulusCharDB) ~= "table" or type(skillLine) ~= "number" or type(rank) ~= "number" then
        return nil
    end
    if type(FamulusCharDB.skills) ~= "table" then
        FamulusCharDB.skills = {}
    end
    local before = FamulusCharDB.skills[skillLine]
    FamulusCharDB.skills[skillLine] = rank
    return before
end

-- Marks an ability as learned by this character; true if it was new.
function ChronicleService.SeeAbility(id)
    if type(FamulusCharDB) ~= "table" or type(id) ~= "string" then
        return false
    end
    if type(FamulusCharDB.abilities) ~= "table" then
        FamulusCharDB.abilities = {}
    end
    if FamulusCharDB.abilities[id] then
        return false
    end
    FamulusCharDB.abilities[id] = true
    return true
end

-- The recipe book of a companion. The game opens it from a profession link,
-- and such a link can be built: "trade:<guid>:<spell>:<skill line>" (the way
-- the addon Guildy does it). LINK_SPELL: the spell such a link carries, for
-- the professions that have a book; mining's is Smelting.
local LINK_SPELL = {
    [171] = 2259, -- Alchemy
    [164] = 2018, -- Blacksmithing
    [333] = 7411, -- Enchanting
    [202] = 4036, -- Engineering
    [165] = 2108, -- Leatherworking
    [197] = 3908, -- Tailoring
    [185] = 2550, -- Cooking
    [129] = 3273, -- First Aid
    [186] = 2656, -- Mining
}

local function NameKey(name)
    return (string.lower((string.gsub(name, "[%s%-]+", "-"))))
end

-- The GUID of a companion who is online, from the friends list or the guild
-- roster, or nil. The roster may write "First Last-Realm".
local function OnlineGUID(name)
    if not IsPlainText(name) then
        return nil
    end
    local key = NameKey(name)
    if C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
        for i = 1, C_FriendList.GetNumFriends() or 0 do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.connected and IsPlainText(info.name) and IsPlainText(info.guid) and NameKey(info.name) == key then
                return info.guid
            end
        end
    end
    if IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo then
        for i = 1, GetNumGuildMembers() or 0 do
            local member, _, _, _, _, _, _, _, isOnline, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
            if isOnline and IsPlainText(member) and IsPlainText(guid) then
                local memberKey = NameKey(member)
                if memberKey == key or memberKey:sub(1, #key + 1) == key .. "-" then
                    return guid
                end
            end
        end
    end
    return nil
end

-- Whether a profession has a recipe book that can be shown.
function ChronicleService.HasBook(skillLine)
    return LINK_SPELL[tonumber(skillLine) or 0] ~= nil
end

-- The link that opens a companion's recipe book, or nil while they are not
-- online on the friends list or in the guild.
function ChronicleService.BookLink(name, skillLine)
    local spell, guid = LINK_SPELL[tonumber(skillLine) or 0], OnlineGUID(name)
    if not spell or not guid then
        return nil
    end
    return string.format("trade:%s:%d:%d", guid, spell, skillLine)
end

-- Marks an item as owned once by this character; true if it was new.
-- HasItem asks without marking.
function ChronicleService.HasItem(itemID)
    return type(FamulusCharDB) == "table" and type(FamulusCharDB.items) == "table" and FamulusCharDB.items[itemID] == true
end

function ChronicleService.SeeItem(itemID)
    if type(FamulusCharDB) ~= "table" or type(itemID) ~= "number" then
        return false
    end
    if type(FamulusCharDB.items) ~= "table" then
        FamulusCharDB.items = {}
    end
    if FamulusCharDB.items[itemID] then
        return false
    end
    FamulusCharDB.items[itemID] = true
    return true
end

-- Sample entries, to look at the book without playing for days:
-- /fam chronicle demo writes them, /fam chronicle demo clear removes them.
-- They carry `demo` and never leave this client (see OwnSince and
-- Modules/Chronicle/Sharing.lua). Returns how many were written or removed.
local DEMO_ZONES = {
    enUS = { "Badlands", "Uldaman", "Stranglethorn Vale", "Tanaris" },
    deDE = { "Ödland", "Uldaman", "Schlingendorntal", "Tanaris" },
}
local DEMO_NAMES = {
    enUS = { tailoring = "Tailoring", mining = "Mining", boss = "Archaedas", challenge = "Explorer of the Badlands", bag = "Sleeping Bag" },
    deDE = { tailoring = "Schneiderei", mining = "Bergbau", boss = "Archaedas", challenge = "Erkunder des Ödlands", bag = "Schlafsack" },
}

function ChronicleService.ClearDemo()
    local chronicle = Store(false)
    local removed = 0
    if chronicle then
        for index = #chronicle.entries, 1, -1 do
            if chronicle.entries[index].demo then
                table.remove(chronicle.entries, index)
                removed = removed + 1
            end
        end
    end
    if removed > 0 then
        ns:Fire("CHRONICLE_CHANGED")
    end
    return removed
end

function ChronicleService.Demo()
    local chronicle = Store(true)
    if not chronicle then
        return 0
    end
    ChronicleService.ClearDemo()
    local locale = GetLocale and GetLocale() or "enUS"
    local zone, name = DEMO_ZONES[locale] or DEMO_ZONES.enUS, DEMO_NAMES[locale] or DEMO_NAMES.enUS
    local mira, borin = "Mira Sturmfeder", "Borin Eisenbart"
    local hour, day = 3600, 86400
    -- { seconds before now, kind, values }
    local samples = {
        { 2 * day + 5 * hour, "zone", { zone = zone[1], level = 37 } },
        { 2 * day + 4 * hour, "profession", { skill = 197, name = name.tailoring } },
        { 2 * day + 3.5 * hour, "death", { zone = zone[1], level = 37 } },
        { 2 * day + 3 * hour, "level", { level = 38, zone = zone[1] } },
        { 2 * day + 2 * hour, "level", { level = 40, zone = zone[3], who = mira } },
        { 2 * day + 1 * hour, "achievement", { id = 1, name = name.challenge } },
        { day + 6 * hour, "skill", { skill = 186, name = name.mining, rank = 225 } },
        { day + 5 * hour, "boss", { id = 1, name = name.boss, zone = zone[2] } },
        { day + 4.5 * hour, "level", { level = 39, zone = zone[2] } },
        { day + 4 * hour, "death", { zone = zone[3], level = 31, who = borin } },
        { day + 3 * hour, "skill", { skill = 197, name = name.tailoring, rank = 75 } },
        { day + 2 * hour, "ability", { ability = "riding", level = 40, who = mira } },
        { 3 * hour, "zone", { zone = zone[4], level = 39 } },
        { 2.5 * hour, "level", { level = 40, zone = zone[4] } },
        { 2 * hour, "ability", { ability = "riding", level = 40 } },
        { 1.5 * hour, "item", { item = 211527, name = name.bag, level = 40, zone = zone[4] } },
        { 1 * hour, "boss", { id = 2, name = name.boss, zone = zone[2], who = borin } },
        { 0.5 * hour, "item", { item = 211527, name = name.bag, zone = zone[3], who = mira } },
    }
    local now = time()
    for _, sample in ipairs(samples) do
        local entry = sample[3]
        entry.t, entry.k, entry.demo = math.floor(now - sample[1]), sample[2], true
        if not entry.who then
            entry.c = character
        end
        -- Each finds its place by time; what is there keeps its order.
        local entries = chronicle.entries
        local index = #entries + 1
        while index > 1 and entries[index - 1].t > entry.t do
            index = index - 1
        end
        table.insert(entries, index, entry)
    end
    ns:Fire("CHRONICLE_CHANGED")
    return #samples
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
