-- FellowService: the players the player was in a group with, their "fellow
-- travellers". Like the alias list this is account-wide data, not a
-- setting: it lives in FamulusDB.fellows, outside the profiles, and nothing
-- of it leaves the client.
--
--   FamulusDB.fellows = {
--       ["<guid>"] = {
--           name = "First Last", level = <last seen>, class = "MAGE",
--           first = <time>, firstZone = "<zone>",  -- when and where you met
--           last = <time>, zone = "<zone>",        -- last seen together, and where
--           times = <n>,                          -- separate times in a group
--           seconds = <n>,                        -- time spent together
--           bosses = <n>,                         -- bosses defeated together
--           firstLevel = <n>,                     -- the player's level when you met
--           days = { [YYYYMMDD] = { s = <seconds>, z = "<zone>", b = <bosses>,
--                                   f = <first time>, l = <last time> } },
--       },
--   }
--
-- Modules/Fellows/RememberFellows.lua does the counting; the window reads.
-- Changes are announced with the internal message FELLOWS_CHANGED.

local _, ns = ...

local FellowService = {}
ns.FellowService = FellowService

local IsPlainText = ns.ChatService.IsPlainText

local MAX_PEOPLE = 500 -- beyond this, whoever was seen longest ago is forgotten
local MEET_GAP = 30 * 60 -- apart for this long, the next group is a new time together
local MAX_DAYS = 30 -- days kept per person in the day log

-- Bond tiers: the time together (seconds) at which tier 1..4 starts.
FellowService.TIERS = { 0, 3600, 36000, 144000 }

-- guid -> time up to which the stretch in the group is counted. Kept in
-- memory only: logging out (and /reload) ends every stretch first.
local together = {}

local function Store(create)
    local global = ns.global
    if not global then
        return nil
    end
    local fellows = global.fellows
    if type(fellows) ~= "table" then
        if not create then
            return nil
        end
        fellows = {}
        global.fellows = fellows
    end
    return fellows
end

-- While the list is too long, the person seen longest ago goes. Whoever is
-- in the group right now stays.
local function Prune(fellows)
    local count, oldest, oldestTime = 0, nil, nil
    for guid, person in pairs(fellows) do
        count = count + 1
        if not together[guid] and (not oldestTime or person.last < oldestTime) then
            oldest, oldestTime = guid, person.last
        end
    end
    if count > MAX_PEOPLE and oldest then
        fellows[oldest] = nil
    end
end

-- The day a time falls on, as a number: 20261124 (local time).
function FellowService.DayKey(timestamp)
    return tonumber(date("%Y%m%d", timestamp))
end

-- Tier (1..4), progress towards the next one (0..1; 1 at the top) and the
-- seconds still missing (nil at the top) for a time together.
function FellowService.Tier(seconds)
    local tiers = FellowService.TIERS
    local tier = 1
    for index = #tiers, 1, -1 do
        if seconds >= tiers[index] then
            tier = index
            break
        end
    end
    local nextAt = tiers[tier + 1]
    if not nextAt then
        return tier, 1, nil
    end
    return tier, (seconds - tiers[tier]) / (nextAt - tiers[tier]), nextAt - seconds
end

-- The person's day today, created on demand; drops the oldest beyond MAX_DAYS.
local function Today(person, now)
    local days = person.days
    if type(days) ~= "table" then
        days = {}
        person.days = days
    end
    local key = FellowService.DayKey(now)
    local day = days[key]
    if not day then
        day = { s = 0, b = 0 }
        days[key] = day
        local count, oldest = 0, nil
        for other in pairs(days) do
            count = count + 1
            if not oldest or other < oldest then
                oldest = other
            end
        end
        if count > MAX_DAYS then
            days[oldest] = nil
        end
    end
    return day
end

-- Adds the time since the last count to a stretch in the group.
local function Tally(person, guid, now, zone)
    local since = together[guid]
    if since and now > since then
        person.seconds = (person.seconds or 0) + (now - since)
        -- shortcut: a stretch over midnight counts for the day it ends on; split it if the book shows odd times.
        local day = Today(person, now)
        day.s = day.s + (now - since)
        day.f = day.f or since
        day.l = now
        day.z = zone or day.z
    end
    together[guid] = now
    person.last = now
    person.zone = zone or person.zone
end

-- Brings the list in line with the group: members: GroupService.Members();
-- now: time(); zone: where the player is. Who joined starts a stretch,
-- who is still there has it counted, who left ends it. level: the
-- player's level, kept for the people met now.
function FellowService.Sync(members, now, zone, level)
    local fellows = Store(#members > 0 or next(together) ~= nil)
    if not fellows then
        return
    end
    local changed, present = false, {}
    for _, member in ipairs(members) do
        local guid = member.guid
        present[guid] = true
        local person = fellows[guid]
        if not person then
            person = { first = now, firstZone = zone, firstLevel = level, last = now, times = 0, seconds = 0, bosses = 0 }
            fellows[guid] = person
            Prune(fellows)
        end
        if not together[guid] then
            -- A group right after the last one (a disconnect, a /reload)
            -- goes on counting; only after a while apart is it a new time.
            if person.times == 0 or now - (person.last or 0) >= MEET_GAP then
                person.times = person.times + 1
            end
            changed = true
        end
        Tally(person, guid, now, zone)
        if person.name ~= member.name or (member.level and person.level ~= member.level) then
            changed = true
        end
        person.name = member.name
        person.level = member.level or person.level
        person.class = member.class or person.class
    end
    for guid in pairs(together) do
        if not present[guid] then
            local person = fellows[guid]
            if person then
                Tally(person, guid, now, zone)
            end
            together[guid] = nil
            changed = true
        end
    end
    if changed then
        ns:Fire("FELLOWS_CHANGED")
    end
end

-- Ends every stretch in the group (logging out, switching off).
function FellowService.PartAll(now, zone)
    FellowService.Sync({}, now, zone)
end

-- A boss fell: it counts for everyone in the group now.
function FellowService.Boss()
    local fellows = Store()
    if not fellows or next(together) == nil then
        return
    end
    local now = time()
    for guid in pairs(together) do
        local person = fellows[guid]
        if person then
            person.bosses = (person.bosses or 0) + 1
            local day = Today(person, now)
            day.b = day.b + 1
        end
    end
    ns:Fire("FELLOWS_CHANGED")
end

-- Removes a person from the list; returns their name, or nil.
function FellowService.Forget(guid)
    local fellows = Store()
    local person = fellows and fellows[guid]
    if not person then
        return nil
    end
    fellows[guid] = nil
    together[guid] = nil
    ns:Fire("FELLOWS_CHANGED")
    return person.name
end

-- True while the person is in the player's group.
function FellowService.IsTogether(guid)
    return together[guid] ~= nil
end

-- Everyone on the list as { guid = ..., person = <stored table> }, in no
-- particular order. The person tables are shared; callers must not change them.
function FellowService.List()
    local list = {}
    local fellows = Store()
    if fellows then
        for guid, person in pairs(fellows) do
            list[#list + 1] = { guid = guid, person = person }
        end
    end
    return list
end

function FellowService.Count()
    local count = 0
    local fellows = Store()
    if fellows then
        for _ in pairs(fellows) do
            count = count + 1
        end
    end
    return count
end

-- The time spent together, the current stretch included.
function FellowService.Seconds(guid, person, now)
    local seconds = tonumber(person.seconds) or 0
    local since = together[guid]
    if since and now > since then
        seconds = seconds + (now - since)
    end
    return seconds
end

-- The day log as a list of { key, s, z, b, f, l }, newest first.
function FellowService.Days(person)
    local list = {}
    if type(person.days) == "table" then
        for key, day in pairs(person.days) do
            list[#list + 1] = { key = key, s = day.s, z = day.z, b = day.b or 0, f = day.f, l = day.l }
        end
    end
    table.sort(list, function(a, b)
        return a.key > b.key
    end)
    return list
end

-- The days a new tier was reached: day key -> tier. The walk starts from
-- the time before the log, so time from before it (or from days that fell
-- out of it) invents no milestones. The running stretch counts for today.
function FellowService.Milestones(guid, person, now)
    local reached = {}
    local days = FellowService.Days(person)
    local stored = tonumber(person.seconds) or 0
    local stretch = FellowService.Seconds(guid, person, now) - stored
    local running = stored
    for _, day in ipairs(days) do
        running = running - day.s
    end
    running = math.max(0, running)
    local tier, today = FellowService.Tier(running), FellowService.DayKey(now)
    for index = #days, 1, -1 do
        local day = days[index]
        running = running + day.s + (day.key == today and stretch or 0)
        local dayTier = FellowService.Tier(running)
        if dayTier > tier then
            reached[day.key], tier = dayTier, dayTier
        end
    end
    return reached
end

-- Sample people, to look at the list without grouping for days:
-- /fam fellows demo writes them, /fam fellows demo clear removes them.
-- They carry `demo` and a GUID no real player has. Returns how many were
-- written or removed.
local DEMO_ZONES = {
    enUS = { "Badlands", "Uldaman", "Stranglethorn Vale", "Tanaris", "Westfall", "The Deadmines" },
    deDE = { "Ödland", "Uldaman", "Schlingendorntal", "Tanaris", "Westfall", "Die Todesminen" },
}

function FellowService.ClearDemo()
    local fellows = Store()
    local removed = 0
    if fellows then
        for guid, person in pairs(fellows) do
            if person.demo then
                fellows[guid] = nil
                removed = removed + 1
            end
        end
    end
    if removed > 0 then
        ns:Fire("FELLOWS_CHANGED")
    end
    return removed
end

function FellowService.Demo()
    local fellows = Store(true)
    if not fellows then
        return 0
    end
    FellowService.ClearDemo()
    local zone = DEMO_ZONES[GetLocale and GetLocale()] or DEMO_ZONES.enUS
    local hour, day = 3600, 86400
    -- name, class, level, { first: seconds ago, zone }, { last: seconds ago, zone }, times, seconds, bosses
    local samples = {
        { "Mira Sturmfeder", "MAGE", 40, { 9 * day, zone[5] }, { 1 * hour, zone[4] }, 14, 31 * hour + 20 * 60, 9 },
        { "Borin Eisenbart", "WARRIOR", 38, { 6 * day, zone[6] }, { 1 * day + 5 * hour, zone[2] }, 6, 11 * hour + 5 * 60, 7 },
        { "Lysa Morgentau", "PRIEST", 39, { 1 * day + 6 * hour, zone[2] }, { 1 * day + 5 * hour, zone[2] }, 1, 2 * hour + 40 * 60, 3 },
        { "Kael Dornhain", "HUNTER", 34, { 4 * day, zone[3] }, { 3 * day, zone[3] }, 2, 1 * hour + 15 * 60, 0 },
        { "Tomas Grauwind", "ROGUE", 41, { 2 * day, zone[1] }, { 2 * day, zone[1] }, 1, 25 * 60, 1 },
        { "Ena Silberquell", "DRUID", 37, { 12 * day, zone[5] }, { 8 * day, zone[6] }, 3, 4 * hour + 50 * 60, 5 },
    }
    local now = time()
    for index, sample in ipairs(samples) do
        local first, last = math.floor(now - sample[4][1]), math.floor(now - sample[5][1])
        -- One day per time together (at most six), spread from the first to the
        -- last meeting; four fifths of the time is logged, the rest came before.
        local count = math.min(sample[6], 6)
        local share = math.floor(sample[7] * 0.8 / count)
        local days = {}
        for day = 1, count do
            local at = count == 1 and last or math.floor(first + (last - first) * (day - 1) / (count - 1))
            if day < count then
                at = at - (day * 7919) % 18000 -- not every day at the same hour
            end
            local zoneOf = day == 1 and sample[4][2] or day == count and sample[5][2] or zone[(index + day) % #zone + 1]
            days[FellowService.DayKey(at)] = {
                s = share, z = zoneOf, f = at - share, l = at,
                b = math.floor(sample[8] / count) + (day == count and sample[8] % count or 0),
            }
        end
        fellows[("Player-0-FAMDEMO%02d"):format(index)] = {
            name = sample[1], class = sample[2], level = sample[3],
            first = first, firstZone = sample[4][2], firstLevel = 28 + index,
            last = last, zone = sample[5][2],
            times = sample[6], seconds = sample[7], bosses = sample[8],
            days = days, demo = true,
        }
    end
    ns:Fire("FELLOWS_CHANGED")
    return #samples
end

ns:On("DATABASE_READY", function()
    local fellows = Store()
    if not fellows then
        return
    end
    -- The saved file can be edited by hand; drop what is not a person.
    for guid, person in pairs(fellows) do
        if type(guid) ~= "string" or type(person) ~= "table" or not IsPlainText(person.name)
            or type(person.last) ~= "number" or type(person.times) ~= "number" then
            fellows[guid] = nil
        else
            if type(person.firstLevel) ~= "number" then
                person.firstLevel = nil
            end
            local days = person.days
            if type(days) == "table" then
                for key, day in pairs(days) do
                    if type(key) ~= "number" or key < 19000101 or key > 29991231 or type(day) ~= "table"
                        or type(day.s) ~= "number" or day.s < 0
                        or (day.f ~= nil and type(day.f) ~= "number") or (day.l ~= nil and type(day.l) ~= "number")
                        or (day.b ~= nil and type(day.b) ~= "number") or (day.z ~= nil and type(day.z) ~= "string") then
                        days[key] = nil
                    else
                        day.b = day.b or 0
                    end
                end
            elseif days ~= nil then
                person.days = nil
            end
        end
    end
end)
