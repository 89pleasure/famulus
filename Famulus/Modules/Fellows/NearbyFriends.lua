-- Tells the player who of their friends and guild is in the same zone: a
-- card when the player arrives where some of them are, and one when one of
-- them arrives where the player is, or comes online there. The window's tab
-- "Nearby" lists everyone online. Works without the others' cooperation:
-- the friends list, Battle.net and the guild roster tell where people are
-- (NearbyService). Nothing is sent to anyone.
--
-- No card in cities and inns (unless asked for), in instances and in
-- flight; none for people in the player's group or out of reach (another
-- realm, the other faction: the zone's name is the same, the world is not);
-- the same person in the same zone at most once in REPEAT. Cards come on the live feed's place
-- (UI/Feed.lua), for as long as the live feed's cards stay.

local _, ns = ...
local Nearby = ns.NearbyService

local nearby = ns:NewFeature({
    id = "nearbyFriends",
    category = "fellows",
    icon = "compass", -- its entry in the settings (UI.media)
    preview = "nearby", -- its picture there (UI/Previews.lua)
    default = false,
    requires = { "GetRealZoneText", "C_FriendList.GetFriendInfoByIndex" },
    options = {
        { key = "guild", type = "toggle", default = true },
        { key = "cities", type = "toggle", default = false },
        { key = "sound", type = "toggle", default = true },
    },
})

local REPEAT = 30 * 60 -- seconds; the same person in the same zone is told once in this
local ARRIVAL = 10 -- seconds after the player arrives: whoever is found then was there already
local SETTLE = 3 -- seconds after arriving before the card comes, so that the lists can answer
local BUNDLE = 2 -- seconds; whoever turns up within this comes on the same card
local LOOK_GAP = 1 -- seconds; list events within this lead to one look
local POLL = 60 -- seconds between asking for fresh lists; the guild roster does not come by itself
local HUSH = 10 -- seconds after a /reload in which the first lists are only taken note of
local MAX_NAMES = 3 -- names on a card; more are counted
local MAX_CRESTS = 2 -- crests on a card

-- Kept in memory only, from switching on.
local where = {} -- key -> zone at the last look (people online)
local told = {} -- key -> { zone, at }
local pending, pendingSet = {}, {} -- people waiting for the next card
local arrivedAt -- GetTime() when the player arrived in a zone
local hushUntil -- GetTime() until which nothing is told
local lookPlanned, cardPlanned = false, false
local flying = false -- a look found the player in flight; landing is arriving

-- How the card names someone: the alias, else the first name.
local function Short(person)
    return ns.AliasService.Get(person.name) or string.match(person.name, "^[^%s%-]+") or person.name
end

local function ClassName(file)
    local names = LOCALIZED_CLASS_NAMES_MALE
    local name = type(file) == "string" and type(names) == "table" and names[file]
    return type(name) == "string" and name or nil
end

-- "Mira", "Mira and Borin", "Mira, Borin and Lysa", "Mira, Borin and 2 more"
local function Names(list)
    local L = ns.L
    local names = {}
    for index = 1, math.min(#list, MAX_NAMES) do
        names[index] = Short(list[index])
    end
    if #list > MAX_NAMES then
        local more = #list - MAX_NAMES + 1
        names[MAX_NAMES] = ns.Plural("ui_near_others", more):format(more)
    end
    if #names < 2 then
        return names[1] or ""
    end
    return L.c_and:format(table.concat(names, ", ", 1, #names - 1), names[#names])
end

-- One person: level, class, and the bond, or how the player knows them.
local function Detail(person)
    local L = ns.L
    local parts = {}
    if person.level then
        parts[#parts + 1] = L.c_p_level:format(person.level)
    end
    parts[#parts + 1] = ClassName(person.class)
    if person.tier then
        parts[#parts + 1] = L["ui_bond_" .. person.tier]
    else
        parts[#parts + 1] = L["ui_near_from_" .. person.from]
    end
    return table.concat(parts, "  ·  ")
end

-- Several: their levels, "Level 41 and 39", or from lowest to highest.
local function Levels(list)
    local L = ns.L
    local low, high, levels = nil, nil, {}
    for _, person in ipairs(list) do
        if person.level then
            levels[#levels + 1] = person.level
            low = math.min(low or person.level, person.level)
            high = math.max(high or person.level, person.level)
        end
    end
    if not low then
        return nil
    elseif low == high then
        return L.c_p_level:format(low)
    elseif #levels == 2 then
        return L.ui_near_levels_two:format(levels[1], levels[2])
    end
    return L.ui_near_levels:format(low, high)
end

-- The card: who in its head (the crests of the first two show them), where in
-- its title, and below their levels. The closest bond first.
function nearby.Story(list, zone, came)
    local L = ns.L
    local now = time()
    for _, person in ipairs(list) do
        person.tier, person.progress, person.seconds = Nearby.Bond(person, now)
    end
    table.sort(list, function(a, b)
        if (a.seconds or -1) ~= (b.seconds or -1) then
            return (a.seconds or -1) > (b.seconds or -1)
        end
        return a.name < b.name
    end)
    local crests = {}
    for index = 1, math.min(#list, MAX_CRESTS) do
        local person = list[index]
        crests[index] = { name = person.name, class = person.class, progress = person.progress or 0 }
    end
    local story = { kind = "nearby", people = crests, chip = { text = Names(list) } }
    if #list == 1 and came then
        story.title = L.ui_near_came:format(zone)
    else
        story.title = L.ui_near_here:format(zone)
    end
    if #list == 1 then
        story.detail = Detail(list[1])
    else
        story.detail = Levels(list)
    end
    return story
end

local function ShowCard(story)
    local UI = ns.UI
    if not (UI and UI.Feed) then
        return
    end
    local live = ns.features.liveFeed
    local seconds = live and live.SECONDS[ns:GetOption("liveFeed", "duration")] or nil
    UI.Feed.Show(story, seconds)
    if nearby:Get("sound") then
        UI.Feed.Chime()
    end
    ns:DevLog("NEARBY", "shown: " .. #story.people)
end

function nearby:Flush()
    cardPlanned = false
    local list, came = pending, true
    pending, pendingSet = {}, {}
    local zone = Nearby.Here()
    if #list == 0 or not zone or Nearby.Quiet(self:Get("cities")) then
        return
    end
    local now = GetTime()
    local still = {}
    for _, person in ipairs(list) do
        if person.arrival then
            came = false
        end
        -- If the player moved on meanwhile, the card has nothing to say.
        if person.zone == zone then
            still[#still + 1] = person
            told[person.key] = { zone = zone, at = now }
        end
    end
    if #still > 0 then
        ShowCard(nearby.Story(still, zone, came))
    end
end

local function Queue(person, arrival)
    if pendingSet[person.key] then
        return
    end
    pendingSet[person.key] = true
    person.arrival = arrival
    pending[#pending + 1] = person
    if not cardPlanned then
        cardPlanned = true
        local wait = BUNDLE
        if arrival and arrivedAt then
            wait = math.max(BUNDLE, arrivedAt + SETTLE - GetTime())
        end
        nearby:After(wait, nearby.Flush)
    end
end

-- One look at the lists: who is where now, and who of them is news here.
function nearby:Look()
    lookPlanned = false
    local people, here = Nearby.People(self:Get("guild"))
    local now = GetTime()
    local why = Nearby.Quiet(self:Get("cities"))
    flying = flying or why == "taxi"
    local quiet = why or (hushUntil and now < hushUntil)
    local arriving = arrivedAt ~= nil and now - arrivedAt <= ARRIVAL
    local seen = {}
    for _, person in ipairs(people) do
        seen[person.key] = person.zone
        if here and person.zone == here and not person.grouped and not person.out and not quiet then
            local last = told[person.key]
            local fresh = not (last and last.zone == here and now - last.at < REPEAT)
            if fresh and (arriving or where[person.key] ~= here) then
                Queue(person, arriving)
            end
        end
    end
    where = seen
    ns:Fire("NEARBY_CHANGED")
end

function nearby:Changed()
    if not lookPlanned then
        lookPlanned = true
        self:After(LOOK_GAP, self.Look)
    end
end

-- The player arrived somewhere: whoever is there already comes on one card.
function nearby:Arrive()
    arrivedAt = GetTime()
    Nearby.Ask()
    self:Look()
    self:After(SETTLE - 1, self.Look)
end

function nearby:PLAYER_ENTERING_WORLD(_, _, reloading)
    if not ns.IsSecret(reloading) and reloading then
        -- After a /reload everyone is where they were: take note, tell nothing.
        hushUntil, arrivedAt = GetTime() + HUSH, nil
        pending, pendingSet = {}, {}
        Nearby.Ask()
        self:Look()
        return
    end
    self:Arrive()
end

-- Landing after a flight is arriving: in flight nothing was told. The game
-- gives control back after a stun as well; only a flight counts.
function nearby:PLAYER_CONTROL_GAINED()
    if not flying then
        return
    end
    self:After(1, function()
        if not Nearby.Quiet(true) then
            flying = false
            self:Arrive()
        end
    end)
end

function nearby:OnEnable()
    where, told, pending, pendingSet = {}, {}, {}, {}
    arrivedAt, hushUntil, lookPlanned, cardPlanned, flying = nil, nil, false, false, false
    self:RegisterEvent("FRIENDLIST_UPDATE", "Changed")
    self:RegisterEvent("GUILD_ROSTER_UPDATE", "Changed")
    -- Comes with every change of a Battle.net friend's status, where they
    -- are among them; the looks are folded together (LOOK_GAP).
    self:RegisterEvent("BN_FRIEND_INFO_CHANGED", "Changed")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", "Arrive")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_CONTROL_GAINED")
    self:StartTicker(POLL, function()
        Nearby.Ask()
    end)
    -- Switched on (or logged in): whoever is here already.
    self:Arrive()
end

function nearby:OnDisable()
    where, told, pending, pendingSet = {}, {}, {}, {}
    ns:Fire("NEARBY_CHANGED")
end

function nearby:OnOptionChanged(key)
    if key == "guild" then
        self:Look()
    end
end
