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
--       -- an own boss defeated in a group also has `with` (names in a
--       -- party) or `others` (how many in a raid); neither is shared
--       friends = { ["<guid>"] = <last known level>, ... },
--       links = { ["<name key>"] = { name = ..., t = <time> }, ... },
--       classes = { ["<name>"] = "<class file>", ... },  -- of the people in the entries
--   }
--   FamulusCharDB.zones = { ["<zone name>"] = true, ... }   -- seen by this character
--   FamulusCharDB.skills = { [<skill line>] = <last known rank>, ... }
--   FamulusCharDB.abilities = { ["<ability id>"] = true, ... }   -- learned by this character
--   FamulusCharDB.items = { [<item ID>] = true, ... }            -- owned once by this character
--
-- An entry about a companion carries `who` (their character name) instead
-- of `c`, and `via` (who passed it on) when it did not come from them.
-- Reactions (see REACTIONS): on a companion's entry the player's own is
-- `mine`, and `told` what the companion was last told of it; on an own entry
-- `r` = { ["<character name>"] = "<reaction>" } holds those received.
-- Nothing is sent from here; Modules/Chronicle/Sharing.lua does that.

local _, ns = ...
local L = ns.L

local ChronicleService = {}
ns.ChronicleService = ChronicleService

local IsPlainText = ns.ChatService.IsPlainText

local MAX_ENTRIES = 2000
local MAX_OTHERS = 1000 -- of them, news of others
local CLOCK_SLACK = 300 -- seconds a companion's clock may run ahead of ours
local MAX_AGE = 90 * 86400 -- older news is filed under "now"

local character -- "First Last" of the character that is playing
local characterClass -- its class as the game names it in code ("MAGE")

-- A zone for a sentence, or nil.
local function Place(entry)
    return type(entry.zone) == "string" and entry.zone or nil
end

-- Who was there, for a boss defeated in a group: "with Mira and Tom" (alias,
-- else first name), or "with 12 others" in a raid. Nil without a group.
local function Party(entry)
    if type(entry.with) == "table" then
        local names = {}
        for _, name in ipairs(entry.with) do
            if type(name) == "string" and name ~= "" then
                local alias = ns.AliasService and ns.AliasService.Get(name)
                names[#names + 1] = alias or string.match(name, "^(%S+)") or name
            end
        end
        if #names == 1 then
            return L.c_with:format(names[1])
        elseif #names > 1 then
            return L.c_with:format(L.c_and:format(table.concat(names, ", ", 1, #names - 1), names[#names]))
        end
    end
    local others = tonumber(entry.others)
    if others and others > 0 then
        return ns.Plural("c_with_others", others):format(others)
    end
    return nil
end

-- A companion's name as the player knows them: the alias, if there is one.
-- A sample (ChronicleService.Sample) may bring the alias it shows under.
local function Companion(entry)
    local name = entry.who or L.c_someone
    local alias = entry.sampleAlias or ns.AliasService and ns.AliasService.Get(name)
    if alias then
        return alias, name
    end
    return name, nil
end

-- A companion's name as the chronicle shows it: the alias with the
-- character's name in brackets behind it ("Anna (Jaina Proudmoore)"),
-- unless the player switched that off; without an alias, the name.
local function Label(entry)
    local name, realName = Companion(entry)
    if realName and ns:GetOption("general", "chronicleNames") then
        return name .. " (" .. realName .. ")"
    end
    return name
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
                return L.c_their_level:format(Label(e), tonumber(e.level) or 0)
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
                return Place(e) and L.c_their_death:format(Label(e), Place(e)) or L.c_their_death_nowhere:format(Label(e))
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
                return L.c_their_boss:format(Label(e), e.name or L.c_a_foe)
            end
            return L.c_boss:format(e.name or L.c_a_foe)
        end,
        detail = function(e)
            local place, party = Place(e) and L.c_in:format(Place(e)), Party(e)
            if place and party then
                return place .. "  ·  " .. party
            end
            return place or party
        end,
    },
    achievement = {
        title = function(e)
            if e.who then
                return L.c_their_achievement:format(Label(e), e.name or L.c_a_challenge)
            end
            return L.c_achievement:format(e.name or L.c_a_challenge)
        end,
    },
    zone = {
        title = function(e)
            if e.who then
                return L.c_their_zone:format(Label(e), Place(e) or "?")
            end
            return Place(e) and L.c_zone:format(Place(e)) or L.c_zone_nowhere
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
                    return L["c_their_ability_" .. e.ability]:format(Label(e))
                end
                return L.c_their_profession:format(Label(e), e.name or L.c_an_ability)
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
                return L.c_their_item:format(Label(e), ItemName(e))
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
                return L.c_their_profession:format(Label(e), e.name or L.c_a_craft)
            end
            return L.c_profession:format(e.name or L.c_a_craft)
        end,
    },
    skill = {
        title = function(e)
            if e.who then
                return L.c_their_skill:format(Label(e), e.name or L.c_a_craft, tonumber(e.rank) or 0)
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

-- Keeps at most MAX_ENTRIES, of them at most MAX_OTHERS of others, dropping
-- the oldest: in a big guild the news of others would otherwise push the
-- player's own journey out within days.
local function Trim(entries)
    local others = 0
    for _, entry in ipairs(entries) do
        if entry.who then
            others = others + 1
        end
    end
    while #entries > MAX_ENTRIES or others > MAX_OTHERS do
        local oldest = 1
        if others > MAX_OTHERS then
            while not entries[oldest].who do
                oldest = oldest + 1
            end
        end
        if entries[oldest].who then
            others = others - 1
        end
        table.remove(entries, oldest)
    end
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
        -- The class of the character beside its events in the book.
        if character and characterClass then
            ChronicleService.Class(character, characterClass)
        end
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
    Trim(entries)
    ns:Fire("CHRONICLE_CHANGED", entry)
    return true
end

-- The player's own entries newer than `since`, oldest first: the oldest
-- `limit`, and the rest of the last one's second. For companions who catch
-- up on what they missed: a call with the last one's time continues where
-- this one stopped, so nothing is skipped.
function ChronicleService.OwnSince(since, limit)
    local entries, found = ChronicleService.Entries(), {}
    local first = #entries + 1
    while first > 1 and entries[first - 1].t > since do
        first = first - 1
    end
    for i = first, #entries do
        local entry = entries[i]
        if #found >= limit and entry.t > found[#found].t then
            break
        end
        if entry.who == nil and entry.c == character and not entry.demo then
            found[#found + 1] = entry
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

---------------------------------------------------------------------------
-- Reactions: a friend celebrates an event of the player's, or mourns a
-- death with them. Each kind has one (a picture in UI.media); a kind
-- without one cannot be reacted to, such as arriving in a zone, which
-- happens all the time. The player gives one with a click on a companion's
-- card; Sharing.lua tells the companion while both are online, else at
-- their next hello.
---------------------------------------------------------------------------

ChronicleService.REACTIONS = {
    level = "cheer",
    achievement = "cheer",
    ability = "cheer",
    item = "cheer",
    boss = "strong",
    death = "sad",
    skill = "clap",
    profession = "clap",
}

-- What tells two entries of one kind in one second apart, as for the same
-- event twice in Add: field -> "n" (number) or "s" (text).
ChronicleService.MARKS = { skill = "n", rank = "n", ability = "s", item = "n" }

-- Whether reactions are given and shown: sharing is on, and so is its
-- option (Modules/Chronicle/Sharing.lua). The book and the live feed ask.
function ChronicleService.ReactionsOn()
    local sharing = ns.features.sharing
    return sharing ~= nil and sharing.enabled and sharing:Get("reactions") == true
end

-- Whether a reaction is one this version knows.
function ChronicleService.IsReaction(reaction)
    for _, known in pairs(ChronicleService.REACTIONS) do
        if known == reaction then
            return true
        end
    end
    return false
end

-- The reaction a companion's entry can get, or nil. The player's own
-- entries get none from the player, and neither does a level seen on the
-- friends list: its time is this client's, the friend's own entry has another.
function ChronicleService.Reaction(entry)
    if type(entry) ~= "table" or not entry.who then
        return nil
    end
    return ChronicleService.REACTIONS[entry.k]
end

-- Gives (on) or takes back the player's reaction to a companion's entry.
function ChronicleService.React(entry, on)
    local reaction = ChronicleService.Reaction(entry)
    if not reaction or (entry.mine ~= nil) == (on and true or false) then
        return
    end
    entry.mine = on and reaction or nil
    ns:Fire("CHRONICLE_CHANGED")
    ns:Fire("CHRONICLE_REACTED", entry)
end

-- Whether the companion has yet to be told the player's reaction as it is
-- now. Sample entries never are.
function ChronicleService.ReactionUntold(entry)
    return (entry.mine or "") ~= (entry.told or "") and not entry.demo
end

-- The companion was told `reaction` (nil: that there is none).
function ChronicleService.ReactionTold(entry, reaction)
    entry.told = reaction
end

-- A friend's reaction (nil: taken back) to one of the playing character's
-- entries: the one of `kind` at `when`, told apart by `marks` (see MARKS).
-- Returns the entry, or nil if there is none such.
function ChronicleService.Receive(when, kind, marks, who, reaction)
    if type(when) ~= "number" or not IsPlainText(who) then
        return nil
    end
    local entries = ChronicleService.Entries()
    for i = #entries, 1, -1 do
        local entry = entries[i]
        if entry.t < when then
            break
        end
        local same = entry.t == when and entry.k == kind and entry.who == nil and entry.c == character and not entry.demo
        for field in pairs(ChronicleService.MARKS) do
            if same and marks[field] ~= nil and marks[field] ~= entry[field] then
                same = false
            end
        end
        if same then
            local received = type(entry.r) == "table" and entry.r or {}
            local before = received[who]
            received[who] = reaction
            entry.r = next(received) and received or nil
            if before ~= reaction then
                ns:Fire("CHRONICLE_CHANGED")
                if reaction then
                    ns:Fire("CHRONICLE_REACTION", entry, who, reaction)
                end
            end
            return entry
        end
    end
    return nil
end

-- Who reacted to an own entry, by name, sorted.
function ChronicleService.Reactions(entry)
    local names = {}
    if type(entry.r) == "table" then
        for who, reaction in pairs(entry.r) do
            if type(who) == "string" and type(reaction) == "string" then
                names[#names + 1] = who
            end
        end
        table.sort(names)
    end
    return names
end

-- The companions the chronicle knows: whoever has an entry or a profile, the
-- one heard of most recently first. Each { who = <character name>, last =
-- <newest entry, or nil>, level = <highest level known, or nil>, profile =
-- <profile, or nil> }.
function ChronicleService.Companions()
    local entries, found, list = ChronicleService.Entries(), {}, {}
    for i = #entries, 1, -1 do
        local entry = entries[i]
        local who = entry.who
        if type(who) == "string" then
            local companion = found[who]
            if not companion then
                companion = { who = who, last = entry }
                found[who] = companion
                list[#list + 1] = companion
            end
            if not companion.level and (entry.k == "level" or entry.k == "friendLevel") then
                companion.level = tonumber(entry.level)
            end
        end
    end
    for _, who in ipairs(ChronicleService.ProfileNames()) do
        local companion = found[who]
        if not companion then
            companion = { who = who }
            found[who] = companion
            list[#list + 1] = companion
        end
        companion.profile = ChronicleService.Profile(who)
        local level = tonumber(companion.profile.level)
        if level and level > (companion.level or 0) then
            companion.level = level
        end
    end
    return list
end

-- The character's own statistics that friends see in their stats, by the
-- game's IDs: deaths, creatures killed, quests completed, dungeons entered.
-- Sharing sends them, the window shows them; a label is c_stat_<id>.
ChronicleService.STATISTICS = { 60, 107, 98, 932 }

function ChronicleService.Character()
    return character
end

-- The name a companion's entries carry, for a character name in any
-- spelling ("First Last", "First-Last"), or nil if the chronicle has no
-- entry of theirs. The fellow travellers link a person to their events.
function ChronicleService.Who(name)
    local Key = ns.SocialService.Key
    local key = IsPlainText(name) and Key(name)
    if not key then
        return nil
    end
    local entries = ChronicleService.Entries()
    for i = #entries, 1, -1 do
        local who = entries[i].who
        if type(who) == "string" and (who == name or Key(who) == key) then
            return who
        end
    end
    return nil
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
    -- Under an alias, the character's name stands in brackets wherever the
    -- companion is named (Label), not in the detail line.
    if entry.who and entry.via then
        local via = L.c_via:format(entry.via)
        detail = detail and (detail .. "  ·  " .. via) or via
    end
    return spec.title(told), detail
end

-- Several entries told as one, the way the book bundles what repeats: deaths
-- in one place, or levels of one companion. run: the entries, newest first,
-- all of one kind and one person. Headline and detail like Text.
function ChronicleService.TextRun(run, anonymous)
    local newest, count = run[1], #run
    local name = newest.who and not anonymous and Label(newest) or nil
    local zone, low, high = Place(newest), nil, nil
    for _, entry in ipairs(run) do
        local level = tonumber(entry.level)
        if level then
            low, high = math.min(low or level, level), math.max(high or level, level)
        end
        if Place(entry) ~= zone then
            zone = nil
        end
    end
    local title, detail
    if newest.k == "death" then
        if name then
            title = zone and ns.Plural("c_their_deaths", count):format(name, count, zone)
                or ns.Plural("c_their_deaths_nowhere", count):format(name, count)
        else
            title = zone and ns.Plural("c_deaths", count):format(count, zone)
                or ns.Plural("c_deaths_nowhere", count):format(count)
        end
        if low then
            detail = low == high and L.c_at_level:format(low) or L.c_at_levels:format(low, high)
        end
    else
        low, high = low or 0, high or 0
        title = name and L.c_their_levels:format(name, low, high) or L.c_levels:format(low, high)
        detail = zone and L.c_in:format(zone) or nil
    end
    return title, detail
end

-- A companion as the player knows them: alias first, then the name.
ChronicleService.Companion = Companion
-- And as the chronicle shows them: the alias with the name in brackets.
ChronicleService.Label = Label

-- The game's name of a class in code ("MAGE"), or nil for anything else.
local function ClassFile(value)
    if ns.IsSecret(value) or type(value) ~= "string" or #value > 20 or not string.match(value, "^%u+$") then
        return nil
    end
    return value
end

-- The class of a companion or of one of the player's characters, by the
-- name their entries carry: as the game names it in code ("MAGE"), or nil
-- while it is not known. Pass a class to remember it. Companions tell it
-- along with their stats (Sharing.lua), the friends list along with a
-- friend's level-up (Companions.lua), and the window takes it from the
-- guild roster and the friends list when it shows the chronicle
-- (LearnClasses).
function ChronicleService.Class(who, classFile)
    classFile = ClassFile(classFile)
    local chronicle = Store(classFile ~= nil)
    if not chronicle or not IsPlainText(who) then
        return nil
    end
    if type(chronicle.classes) ~= "table" then
        if not classFile then
            return nil
        end
        chronicle.classes = {}
    end
    if classFile then
        chronicle.classes[who] = classFile
    end
    return ClassFile(chronicle.classes[who])
end

-- Remembers the class of the character that is playing, for its entries.
local function RememberOwnClass()
    if character and characterClass then
        ChronicleService.Class(character, characterClass)
    end
end

-- Classes are kept only for the people the chronicle still tells of.
local function PruneClasses(chronicle)
    if type(chronicle.classes) ~= "table" then
        return
    end
    local known = {}
    for _, entry in ipairs(chronicle.entries) do
        known[entry.who or entry.c or false] = true
    end
    if type(chronicle.profiles) == "table" then
        for who in pairs(chronicle.profiles) do
            known[who] = true
        end
    end
    for who, classFile in pairs(chronicle.classes) do
        if not known[who] or not ClassFile(classFile) then
            chronicle.classes[who] = nil
        end
    end
end

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

-- The professions of the character that is playing, as the client lists
-- them: { name = <or nil>, icon = <file ID or nil>, rank, max = <or nil>,
-- skill = <skill line> }. OwnJourney looks for milestones in them; the
-- window shows them.
local function Indices(...)
    local list = {}
    for i = 1, select("#", ...) do
        local index = select(i, ...)
        if index then
            list[#list + 1] = index
        end
    end
    return list
end

function ChronicleService.Professions()
    local list = {}
    if not (GetProfessions and GetProfessionInfo) then
        return list
    end
    for _, index in ipairs(Indices(GetProfessions())) do
        local name, icon, rank, max, _, _, skillLine = GetProfessionInfo(index)
        if not ns.IsSecret(rank) and type(rank) == "number" and type(skillLine) == "number" then
            list[#list + 1] = {
                name = IsPlainText(name) and name or nil,
                icon = not ns.IsSecret(icon) and type(icon) == "number" and icon or nil,
                rank = rank,
                max = not ns.IsSecret(max) and type(max) == "number" and max > 0 and max or nil,
                skill = skillLine,
            }
        end
    end
    return list
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

-- Who is online now, from one look at the friends list and the guild roster
-- (SocialService.Online): a function that answers for a character name. For
-- the window, which asks for many companions at once.
function ChronicleService.OnlineCheck()
    local find = ns.SocialService.Online()
    return function(name)
        return find(name) ~= nil
    end
end

-- Remembers the classes the friends list and the guild roster tell
-- (SocialService.Classes) of the people the chronicle tells of, so that
-- they stay when those people are gone from the lists. The window does
-- this when it shows the chronicle: nothing runs in the background for it.
function ChronicleService.LearnClasses()
    local find = ns.SocialService.Classes()
    for _, companion in ipairs(ChronicleService.Companions()) do
        local classFile = find(companion.who)
        if classFile and classFile ~= ChronicleService.Class(companion.who) then
            ChronicleService.Class(companion.who, classFile)
        end
    end
end

-- Whether a profession has a recipe book that can be shown.
function ChronicleService.HasBook(skillLine)
    return LINK_SPELL[tonumber(skillLine) or 0] ~= nil
end

-- The link that opens a companion's recipe book, or nil while they are not
-- online on the friends list or in the guild.
function ChronicleService.BookLink(name, skillLine)
    local spell = LINK_SPELL[tonumber(skillLine) or 0]
    local guid = spell and ns.SocialService.Online()(name)
    if type(guid) ~= "string" then
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
-- They speak the addon's language, not the client's, so a German client set
-- to English shows English samples; the companions are the same people as in
-- the fellow travellers' samples (FellowService.Demo), in either language.
local DEMO_ZONES = {
    enUS = { "Badlands", "Uldaman", "Stranglethorn Vale", "Tanaris" },
    deDE = { "Ödland", "Uldaman", "Schlingendorntal", "Tanaris" },
    esES = { "Tierras Inhóspitas", "Uldaman", "Vega de Tuercespina", "Tanaris" },
    frFR = { "Terres ingrates", "Uldaman", "Vallée de Strangleronce", "Tanaris" },
    itIT = { "Maleterre", "Uldaman", "Valle di Rovotorto", "Tanaris" },
    plPL = { "Badlands", "Uldaman", "Stranglethorn Vale", "Tanaris" },
    ukUA = { "Badlands", "Uldaman", "Stranglethorn Vale", "Tanaris" },
}
local DEMO_NAMES = {
    enUS = { tailoring = "Tailoring", mining = "Mining", boss = "Archaedas", challenge = "Explorer of the Badlands", bag = "Sleeping Bag" },
    deDE = { tailoring = "Schneiderei", mining = "Bergbau", boss = "Archaedas", challenge = "Erkunder des Ödlands", bag = "Schlafsack" },
    esES = { tailoring = "Sastrería", mining = "Minería", boss = "Archaedas", challenge = "Explorar las Tierras Inhóspitas", bag = "Saco de dormir" },
    frFR = { tailoring = "Couture", mining = "Minage", boss = "Archaedas", challenge = "Explorer les Terres ingrates", bag = "Sac de couchage" },
    itIT = { tailoring = "Sartoria", mining = "Estrazione", boss = "Archaedas", challenge = "Esplora Maleterre", bag = "Sacco a pelo" },
    plPL = { tailoring = "Tailoring", mining = "Mining", boss = "Archaedas", challenge = "Explorer of the Badlands", bag = "Sleeping Bag" },
    ukUA = { tailoring = "Tailoring", mining = "Mining", boss = "Archaedas", challenge = "Explorer of the Badlands", bag = "Sleeping Bag" },
}
local DEMO_PEOPLE = {
    enUS = { "Mira Stormfeather", "Borin Ironbeard", "Lysa Morningdew" },
    deDE = { "Mira Sturmfeder", "Borin Eisenbart", "Lysa Morgentau" },
    esES = { "Mira Plumatormenta", "Borin Barbahierro", "Lysa Rocíoalba" },
    frFR = { "Mira Plume-d'orage", "Borin Barbe-de-fer", "Lysa Rosée-du-matin" },
    itIT = { "Mira Piumatempesta", "Borin Barbaferrea", "Lysa Rugiadalba" },
    plPL = { "Mira Burzowe Pióro", "Borin Żelazna Broda", "Lysa Poranna Rosa" },
    ukUA = { "Міра Бурепер", "Борін Залізнобород", "Ліса Ранкороса" },
}

-- The samples' three people (Mira, Borin, Lysa) in the addon's language.
function ChronicleService.SamplePeople()
    return unpack(DEMO_PEOPLE[ns:GetLocaleCode()] or DEMO_PEOPLE.enUS)
end

-- Their classes, as the fellow travellers' samples have them.
local DEMO_CLASSES = { "MAGE", "WARRIOR", "PRIEST" }

-- The class of one of the samples' people, in any language, or nil.
function ChronicleService.SampleClass(name)
    for _, people in pairs(DEMO_PEOPLE) do
        for index, person in ipairs(people) do
            if person == name then
                return DEMO_CLASSES[index]
            end
        end
    end
    return nil
end

-- One made-up entry of a kind, a friend's (own: the player's), with the
-- samples' people, zones and names. Never stored: for the pictures of the
-- settings (UI/Previews.lua). nil for a kind without a sample.
function ChronicleService.Sample(kind, own)
    local locale = ns:GetLocaleCode()
    local zone, name = DEMO_ZONES[locale] or DEMO_ZONES.enUS, DEMO_NAMES[locale] or DEMO_NAMES.enUS
    local mira, borin, lysa = ChronicleService.SamplePeople()
    local samples = {
        level = { level = 40, zone = zone[3], who = mira },
        death = { zone = zone[1], level = 31, who = borin },
        boss = { id = 1, name = name.boss, zone = zone[2], who = borin, with = { mira } },
        achievement = { id = 1, name = name.challenge, who = lysa },
        ability = { ability = "riding", level = 40, who = mira },
        item = { item = 211527, name = name.bag, zone = zone[4], who = mira },
        profession = { skill = 186, name = name.mining, who = lysa },
        skill = { skill = 186, name = name.mining, rank = 225, who = lysa },
        zone = { zone = zone[4], level = 39, who = lysa },
    }
    local entry = samples[kind]
    if not entry then
        return nil
    end
    entry.k, entry.t, entry.demo = kind, time(), true
    if own then
        entry.who, entry.with = nil, nil
    end
    return entry
end

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
        if type(chronicle.profiles) == "table" then
            for who, profile in pairs(chronicle.profiles) do
                if type(profile) == "table" and profile.demo then
                    chronicle.profiles[who] = nil
                end
            end
        end
        PruneClasses(chronicle)
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
    local locale = ns:GetLocaleCode()
    local zone, name = DEMO_ZONES[locale] or DEMO_ZONES.enUS, DEMO_NAMES[locale] or DEMO_NAMES.enUS
    local mira, borin, lysa = unpack(DEMO_PEOPLE[locale] or DEMO_PEOPLE.enUS)
    local hour, day = 3600, 86400
    -- { seconds before now, kind, values }
    local samples = {
        { 2 * day + 5 * hour, "zone", { zone = zone[1], level = 37 } },
        { 2 * day + 4 * hour, "profession", { skill = 197, name = name.tailoring } },
        { 2 * day + 3.5 * hour, "death", { zone = zone[1], level = 37 } },
        -- Repeated right away, these share a card in the book.
        { 2 * day + 3.4 * hour, "death", { zone = zone[1], level = 37 } },
        { 2 * day + 3.2 * hour, "death", { zone = zone[1], level = 37, r = { [borin] = "sad" } } },
        { 2 * day + 3 * hour, "level", { level = 38, zone = zone[1], r = { [mira] = "cheer" } } },
        { 2 * day + 2.2 * hour, "level", { level = 39, zone = zone[3], who = mira } },
        { 2 * day + 2 * hour, "level", { level = 40, zone = zone[3], who = mira } },
        { 2 * day + 1 * hour, "achievement", { id = 1, name = name.challenge } },
        { 2 * day + 0.5 * hour, "zone", { zone = zone[1], level = 38, who = lysa } },
        { day + 8 * hour, "profession", { skill = 186, name = name.mining, who = lysa } },
        { day + 7 * hour, "level", { level = 32, zone = zone[3], who = borin } },
        { day + 6 * hour, "skill", { skill = 186, name = name.mining, rank = 225 } },
        { day + 5 * hour, "boss", { id = 1, name = name.boss, zone = zone[2], with = { mira, borin } } },
        { day + 4.5 * hour, "level", { level = 39, zone = zone[2] } },
        { day + 4 * hour, "death", { zone = zone[3], level = 31, who = borin } },
        { day + 3 * hour, "skill", { skill = 197, name = name.tailoring, rank = 75 } },
        { day + 2 * hour, "ability", { ability = "riding", level = 40, who = mira } },
        { 3 * hour, "zone", { zone = zone[4], level = 39 } },
        -- Friends reacted to some of the player's events, and the player to
        -- one of Borin's.
        { 2.5 * hour, "level", { level = 40, zone = zone[4], r = { [mira] = "cheer", [borin] = "cheer", [lysa] = "cheer" } } },
        { 2 * hour, "ability", { ability = "riding", level = 40, r = { [lysa] = "cheer" } } },
        { 1.5 * hour, "item", { item = 211527, name = name.bag, level = 40, zone = zone[4] } },
        { 1 * hour, "boss", { id = 2, name = name.boss, zone = zone[2], who = borin, mine = "strong" } },
        { 0.5 * hour, "item", { item = 211527, name = name.bag, zone = zone[3], who = mira } },
        { 0.2 * hour, "achievement", { id = 1, name = name.challenge, who = lysa } },
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
    -- The companions' profiles (level and the shared statistics), as the
    -- rail of the companions' tab shows them. Received data only; never sent.
    chronicle.profiles = type(chronicle.profiles) == "table" and chronicle.profiles or {}
    local profiles = {
        [mira] = { level = 40, stats = { [60] = 14, [107] = 5230, [98] = 212, [932] = 31 } },
        [borin] = { level = 32, stats = { [60] = 22, [107] = 3815, [98] = 167, [932] = 19 } },
        [lysa] = { level = 39, stats = { [60] = 6, [107] = 4470, [98] = 238, [932] = 24 } },
    }
    for who, profile in pairs(profiles) do
        if not chronicle.profiles[who] then
            profile.t, profile.demo = now, true
            chronicle.profiles[who] = profile
        end
    end
    -- Their classes, as the fellow travellers' samples have them; a class
    -- known of a real person of the same name stays.
    for who, classFile in pairs({ [mira] = "MAGE", [borin] = "WARRIOR", [lysa] = "PRIEST" }) do
        if not ChronicleService.Class(who) then
            ChronicleService.Class(who, classFile)
        end
    end
    RememberOwnClass()
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
            if type(entry.r) ~= "table" then
                entry.r = nil
            end
            kept[#kept + 1] = entry
        end
    end
    Trim(kept)
    chronicle.entries = kept
    PruneClasses(chronicle)
end)

ns:On("LOGIN", function()
    local name, surname = UnitName("player")
    if IsPlainText(name) then
        character = IsPlainText(surname) and (name .. " " .. surname) or name
    end
    local _, classFile = UnitClass("player")
    characterClass = ClassFile(classFile)
    -- Only where the chronicle has begun: logging in writes nothing new.
    if Store() then
        RememberOwnClass()
    end
end)
