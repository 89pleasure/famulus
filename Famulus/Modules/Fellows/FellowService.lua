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
--           tag = "Name#1234",                    -- their BattleTag, if seen as a Battle.net friend
--           days = { [YYYYMMDD] = { s = <seconds>, z = "<zone>", b = <bosses>,
--                                   f = <first time>, l = <last time>,
--                                   k = { { t = <time>, n = "<boss>", z = "<zone>" }, ... } } },
--       },
--   }
--
-- `k` names the bosses defeated together in a party, at most MAX_KILLS a
-- day; a raid only counts them in `b`, so that forty people do not each
-- keep every boss of the evening.
--
-- Beside the people, the groups themselves, for the timeline: who was
-- together with whom, when and where. One run lasts while anyone counts in
-- the group; it goes on after a short break with one of the same people
-- (a /reload, a disconnect), as a new "time together" would not begin.
--
--   FamulusDB.fellowRuns = { {             -- oldest first, MAX_DAYS at most
--       f = <start>, l = <end>,
--       z = { "<zone>", ... },             -- where, in the order of time
--       b = <bosses>,
--       who = { ["<guid>"] = { f = <joined>, l = <left> } }, -- in a party
--       raid = true, n = <most people at once>, -- a raid keeps only the number
--   }, ... }
--
-- `tag` lets the list know a Battle.net friend again while they are offline
-- (the client names their character only while they are online), so that
-- tidying up does not take them for a stranger. It is kept when someone
-- stops being a friend; then it simply no longer matches.
--
-- Modules/Fellows/RememberFellows.lua does the counting; the window reads.
-- Changes are announced with the internal message FELLOWS_CHANGED. None of
-- this needs the chronicle: what you did together is kept here.

local _, ns = ...

local FellowService = {}
ns.FellowService = FellowService

local IsPlainText = ns.ChatService.IsPlainText

local MAX_PEOPLE = 500 -- beyond this, whoever was seen longest ago is forgotten
local MEET_GAP = 30 * 60 -- apart for this long, the next group is a new time together
local MAX_DAYS = 30 -- days kept per person in the day log
local MAX_KILLS = 12 -- bosses named per person and day
local MAX_RUNS = 400 -- groups kept, whatever their age
local MAX_ZONES = 6 -- zones a group keeps; the oldest give way

-- Bond tiers: the time together (seconds) at which tier 1..4 starts.
FellowService.TIERS = { 0, 3600, 36000, 144000 }

-- guid -> time up to which the stretch in the group is counted. Kept in
-- memory only: logging out (and /reload) ends every stretch first.
local together = {}
-- The group being written down, while anyone counts in it.
local openRun

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

local function RunStore(create)
    local global = ns.global
    if not global then
        return nil
    end
    local runs = global.fellowRuns
    if type(runs) ~= "table" then
        if not create then
            return nil
        end
        runs = {}
        global.fellowRuns = runs
    end
    return runs
end

local function AddZone(run, zone)
    if IsPlainText(zone) and run.z[#run.z] ~= zone then
        run.z[#run.z + 1] = zone
        if #run.z > MAX_ZONES then
            table.remove(run.z, 1)
        end
    end
end

-- Groups older than the day log go, and beyond MAX_RUNS the oldest.
local function PruneRuns(runs, now)
    while #runs > 0 and runs[1] ~= openRun and (#runs > MAX_RUNS or (runs[1].l or 0) < now - MAX_DAYS * 86400) do
        table.remove(runs, 1)
    end
end

-- The group the members belong to: the one being written, else the last
-- one if it ended a moment ago with one of them in it, else a new one.
local function RunFor(members, now, raid)
    if openRun then
        return openRun
    end
    local runs = RunStore(true)
    local last = runs[#runs]
    if last and not last.demo and now - (last.l or 0) < MEET_GAP then
        local shared = last.raid and raid or false
        for _, member in ipairs(members) do
            shared = shared or (last.who ~= nil and last.who[member.guid] ~= nil)
        end
        if shared then
            openRun = last
            return last
        end
    end
    PruneRuns(runs, now)
    openRun = { f = now, l = now, z = {}, b = 0 }
    runs[#runs + 1] = openRun
    return openRun
end

-- Takes people out of the groups (forgotten, tidied away); a group left
-- with nobody in it goes too. gone: guid -> true.
local function LeaveRuns(gone)
    local runs = RunStore()
    if not runs then
        return
    end
    for index = #runs, 1, -1 do
        local run = runs[index]
        if run.who then
            for guid in pairs(gone) do
                run.who[guid] = nil
            end
            if next(run.who) == nil and not run.raid and run ~= openRun then
                table.remove(runs, index)
            end
        end
    end
end

-- Brings the list in line with the group: members: GroupService.Members();
-- now: time(); zone: where the player is. Who joined starts a stretch,
-- who is still there has it counted, who left ends it. level: the
-- player's level, kept for the people met now. raid: in a raid group,
-- whose run keeps only the number of people.
function FellowService.Sync(members, now, zone, level, raid)
    local fellows = Store(#members > 0 or next(together) ~= nil)
    if not fellows then
        return
    end
    local run = #members > 0 and RunFor(members, now, raid) or openRun
    if run then
        run.l = now
        AddZone(run, zone)
        if raid then
            run.raid = true
            run.n = math.max(run.n or 0, #members)
        end
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
        person.tag = member.tag or person.tag
        -- In the group's run: since when, until now. A raid adds nobody.
        local seen = run.who and run.who[guid]
        if seen then
            seen.l = now
        elseif not run.raid then
            run.who = run.who or {}
            run.who[guid] = { f = now, l = now }
        end
    end
    for guid in pairs(together) do
        if not present[guid] then
            local person = fellows[guid]
            if person then
                Tally(person, guid, now, zone)
            end
            local seen = run and run.who and run.who[guid]
            if seen then
                seen.l = now
            end
            together[guid] = nil
            changed = true
        end
    end
    if #members == 0 then
        openRun = nil
    end
    if changed then
        ns:Fire("FELLOWS_CHANGED")
    end
end

-- The player went to another zone: the group's run notes it.
function FellowService.Move(zone)
    if openRun then
        AddZone(openRun, zone)
    end
end

-- The groups of the last days, oldest first, and the one going on now (or
-- nil). The tables are shared; callers must not change them.
function FellowService.Runs()
    return RunStore() or {}, openRun
end

-- Ends every stretch in the group (logging out, switching off).
function FellowService.PartAll(now, zone)
    FellowService.Sync({}, now, zone)
end

-- A boss fell: it counts for everyone in the group now. name, zone: the
-- boss and where (either may be nil); raid: true in a raid group, where the
-- boss is counted but not named.
function FellowService.Boss(name, zone, raid)
    local fellows = Store()
    if not fellows or next(together) == nil then
        return
    end
    local now = time()
    local named = not raid and IsPlainText(name)
    zone = IsPlainText(zone) and zone or nil
    if openRun then
        openRun.b = (openRun.b or 0) + 1
    end
    for guid in pairs(together) do
        local person = fellows[guid]
        if person then
            person.bosses = (person.bosses or 0) + 1
            local day = Today(person, now)
            day.b = day.b + 1
            if named then
                day.k = day.k or {}
                if #day.k < MAX_KILLS then
                    day.k[#day.k + 1] = { t = now, n = name, z = zone }
                end
            end
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
    LeaveRuns({ [guid] = true })
    ns:Fire("FELLOWS_CHANGED")
    return person.name
end

-- The GUID of the person with that character name, in any spelling
-- ("First Last", "First-Last"), or nil. Of two with the same name, the one
-- seen last. The chronicle links a friend to your story with them this way.
local byKey -- name key -> GUID, made on the first Find and dropped when the list changes

function FellowService.Find(name)
    local Key = ns.SocialService.Key
    local key = IsPlainText(name) and Key(name)
    local fellows = Store()
    if not key or not fellows then
        return nil
    end
    -- The window asks for everyone it lists (who is nearby, with up to 500
    -- people here): one walk over the list for all of them.
    if not byKey then
        byKey = {}
        local lastSeen = {}
        for guid, person in pairs(fellows) do
            local each = Key(person.name)
            if not lastSeen[each] or person.last > lastSeen[each] then
                byKey[each], lastSeen[each] = guid, person.last
            end
        end
    end
    return byKey[key]
end

ns:On("FELLOWS_CHANGED", function()
    byKey = nil
end)

-- Everyone on the list whom check (see SocialService.Circle) does not know:
-- no friend and not in the guild, or not any more. As { guid, person }, by
-- name. Whoever is in the group right now is left out, also someone the
-- option "only friends and guild" does not count.
function FellowService.Outsiders(check)
    local list = {}
    local fellows = Store()
    if fellows then
        local present = {}
        for _, member in ipairs(ns.GroupService.Members(true)) do
            present[member.guid] = true
        end
        for guid, person in pairs(fellows) do
            if not together[guid] and not present[guid] and not check(guid, person.name, person.tag) then
                list[#list + 1] = { guid = guid, person = person }
            end
        end
    end
    table.sort(list, function(a, b)
        return (a.person.name .. a.guid) < (b.person.name .. b.guid)
    end)
    return list
end

-- Removes the outsiders; returns how many went. only: a set of GUIDs (the
-- ones the player was shown); whoever is not in it stays.
function FellowService.RemoveOutsiders(check, only)
    local fellows, removed, gone = Store(), 0, {}
    for _, each in ipairs(FellowService.Outsiders(check)) do
        if not only or only[each.guid] then
            fellows[each.guid] = nil
            gone[each.guid] = true
            removed = removed + 1
        end
    end
    if removed > 0 then
        LeaveRuns(gone)
        ns:Fire("FELLOWS_CHANGED")
    end
    return removed
end

-- True while the person is in the player's group.
function FellowService.IsTogether(guid)
    return together[guid] ~= nil
end

-- The stored person with that GUID, or nil. Shared; callers must not change it.
function FellowService.Person(guid)
    local fellows = Store()
    return fellows and IsPlainText(guid) and fellows[guid] or nil
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

-- The day log as a list of { key, s, z, b, f, l, k }, newest first. `k`
-- (the bosses named that day, oldest first) is shared; callers must not change it.
function FellowService.Days(person)
    local list = {}
    if type(person.days) == "table" then
        for key, day in pairs(person.days) do
            list[#list + 1] = { key = key, s = day.s, z = day.z, b = day.b or 0, f = day.f, l = day.l, k = day.k or {} }
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

-- Sample people and their evenings, to look at the list and the timeline
-- without grouping for days: /fam fellows demo writes them, /fam fellows
-- demo clear removes them. They carry `demo` and a GUID no real player has.
-- Returns how many people were written or removed. They speak the addon's
-- language, not the client's; Mira, Borin and Lysa are the companions of
-- ChronicleService.Demo.
-- Their zones, the bosses of two of them and the people per language:
-- Data/Samples.lua.

local DEMO_CLASSES = { { "MAGE", 40 }, { "WARRIOR", 38 }, { "PRIEST", 39 }, { "HUNTER", 34 }, { "ROGUE", 41 }, { "DRUID", 37 } }

-- One of the sample people (1 Mira ... 6 Ena) as a stored person looks,
-- with hours, groups and bosses of their own; never stored. For the
-- pictures of the settings (UI/Previews.lua).
local SAMPLE_TIMES = { -- { hours together, groups, bosses, last seen (hours ago), zone }
    { 26, 14, 34, 2, 2 }, { 19, 11, 21, 26, 4 }, { 8, 5, 9, 70, 3 },
    { 2, 2, 1, 120, 1 }, { 1, 1, 0, 200, 5 }, { 1, 1, 2, 300, 6 },
}

function FellowService.SamplePerson(index)
    local locale = ns:GetLocaleCode()
    local people = FellowService.DEMO_PEOPLE[locale] or FellowService.DEMO_PEOPLE.enUS
    local zones = FellowService.DEMO_ZONES[locale] or FellowService.DEMO_ZONES.enUS
    local class, times = DEMO_CLASSES[index], SAMPLE_TIMES[index]
    if not (class and times) then
        return nil
    end
    local now = time()
    return {
        name = people[index], class = class[1], level = class[2],
        seconds = times[1] * 3600, times = times[2], bosses = times[3],
        last = now - times[4] * 3600, zone = zones[times[5]],
        first = now - (22 - index) * 86400, firstZone = zones[5], firstLevel = 20 + index,
        demo = true,
    }
end
-- Their evenings, from which their days are told: the day (0 the latest
-- evening, -1 the one before ...), from and to ("HH:MM"; past midnight it
-- ends the next day), the zones (DEMO_ZONES) and who was there (DEMO_PEOPLE,
-- both in Data/Samples.lua), the whole time or as long as `part` says. Bosses fall in
-- the first zone, with names in the two dungeons.
local DEMO_RUNS = {
    { -21, "19:00", "23:00", { 5 }, { 1 } },
    { -20, "18:00", "22:00", { 5 }, { 1, 2 } },
    { -17, "19:30", "23:30", { 1 }, { 1 } },
    { -14, "20:00", "00:30", { 3 }, { 1, 2 } },
    { -12, "19:00", "21:00", { 5 }, { 6 } },
    { -8, "20:00", "23:00", { 5 }, { 1, 6 }, part = { [6] = { "20:00", "21:30" } } },
    { -5, "18:40", "22:30", { 6 }, { 1, 2 }, bosses = 2 },
    { -2, "14:20", "14:45", { 1 }, { 5 }, bosses = 1 },
    { -2, "15:00", "17:10", { 4 }, { 1, 2 } },
    { -1, "20:10", "22:55", { 3 }, { 1, 2, 4 }, part = { [4] = { "20:10", "21:25" } } },
    { 0, "19:05", "23:10", { 2, 4 }, { 1, 2, 3 }, part = { [2] = { "19:05", "22:40" }, [3] = { "19:05", "22:40" } }, bosses = 3 },
}

local function DemoGuid(index)
    return ("Player-0-FAMDEMO%02d"):format(index)
end

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
    local runs = RunStore()
    if runs then
        for index = #runs, 1, -1 do
            if runs[index].demo then
                table.remove(runs, index)
            end
        end
    end
    if removed > 0 then
        ns:Fire("FELLOWS_CHANGED")
    end
    return removed
end

function FellowService.Demo()
    local fellows, runs = Store(true), RunStore(true)
    if not fellows or not runs then
        return 0
    end
    FellowService.ClearDemo()
    local locale = ns:GetLocaleCode()
    local zones = FellowService.DEMO_ZONES[locale] or FellowService.DEMO_ZONES.enUS
    local bossesIn = FellowService.DEMO_BOSSES[locale] or FellowService.DEMO_BOSSES.enUS
    local names = FellowService.DEMO_PEOPLE[locale] or FellowService.DEMO_PEOPLE.enUS
    -- The latest evening is today's once it is over, else yesterday's.
    local now = time()
    local clock = date("*t", now)
    local midnight = now - ((clock.hour * 60 + clock.min) * 60 + clock.sec)
    if now < midnight + (23 * 60 + 20) * 60 then
        midnight = midnight - 86400
    end
    local function At(day, hm, after)
        local hour, minute = string.match(hm, "^(%d+):(%d+)$")
        local at = midnight + day * 86400 + (tonumber(hour) * 60 + tonumber(minute)) * 60
        if after and at < after then
            at = at + 86400
        end
        return at
    end
    local people = {}
    for index, name in ipairs(names) do
        people[index] = { name = name, class = DEMO_CLASSES[index][1], level = DEMO_CLASSES[index][2],
            firstLevel = 28 + index, times = 0, seconds = 0, bosses = 0, days = {}, demo = true }
    end
    for _, sample in ipairs(DEMO_RUNS) do
        local from = At(sample[1], sample[2])
        local to = At(sample[1], sample[3], from)
        local run = { f = from, l = to, z = {}, b = sample.bosses or 0, who = {}, demo = true }
        for _, zone in ipairs(sample[4]) do
            run.z[#run.z + 1] = zones[zone]
        end
        local dungeon = sample[4][1]
        local kills = {}
        for kill = 1, run.b do
            local named = bossesIn[dungeon] and bossesIn[dungeon][kill]
            if named then
                kills[#kills + 1] = { t = from + math.floor((to - from) * 0.7 * kill / (run.b + 1)), n = named, z = zones[dungeon] }
            end
        end
        for _, index in ipairs(sample[5]) do
            local part = sample.part and sample.part[index]
            local joined = part and At(sample[1], part[1]) or from
            local left = part and At(sample[1], part[2], joined) or to
            run.who[DemoGuid(index)] = { f = joined, l = left }
            -- The days as the counting would have written them.
            local person = people[index]
            local zone = left < to and run.z[1] or run.z[#run.z]
            person.first = person.first or joined
            person.firstZone = person.firstZone or run.z[1]
            person.last, person.zone = left, zone
            person.times = person.times + 1
            person.seconds = person.seconds + (left - joined)
            person.bosses = person.bosses + run.b
            local key = FellowService.DayKey(left)
            local day = person.days[key] or { s = 0, b = 0 }
            person.days[key] = day
            day.s = day.s + (left - joined)
            day.f = math.min(day.f or joined, joined)
            day.l = math.max(day.l or left, left)
            day.z = zone
            day.b = day.b + run.b
            for _, kill in ipairs(kills) do
                day.k = day.k or {}
                day.k[#day.k + 1] = { t = kill.t, n = kill.n, z = kill.z }
            end
        end
        runs[#runs + 1] = run
    end
    table.sort(runs, function(a, b)
        return a.f < b.f
    end)
    for index, person in ipairs(people) do
        fellows[DemoGuid(index)] = person
    end
    ns:Fire("FELLOWS_CHANGED")
    return #people
end

-- A group from a hand-edited file: true if it can be told, after dropping
-- what is broken in it.
local function RunIsGood(run)
    if type(run) ~= "table" or type(run.f) ~= "number" or type(run.l) ~= "number" or run.l < run.f
        or (run.b ~= nil and type(run.b) ~= "number") or (run.n ~= nil and type(run.n) ~= "number")
        or (run.who ~= nil and type(run.who) ~= "table") or (run.z ~= nil and type(run.z) ~= "table") then
        return false
    end
    run.b = run.b or 0
    run.raid = run.raid == true or nil
    local zones = {}
    for _, zone in ipairs(run.z or {}) do
        if IsPlainText(zone) then
            zones[#zones + 1] = zone
        end
    end
    run.z = zones
    for guid, seen in pairs(run.who or {}) do
        if type(guid) ~= "string" or type(seen) ~= "table" or type(seen.f) ~= "number" or type(seen.l) ~= "number" then
            run.who[guid] = nil
        end
    end
    return true
end

ns:On("DATABASE_READY", function()
    local runs = RunStore()
    if runs then
        for index = #runs, 1, -1 do
            if not RunIsGood(runs[index]) then
                table.remove(runs, index)
            end
        end
        table.sort(runs, function(a, b)
            return a.f < b.f
        end)
    elseif ns.global and ns.global.fellowRuns ~= nil then
        ns.global.fellowRuns = nil
    end
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
            if person.tag ~= nil and not IsPlainText(person.tag) then
                person.tag = nil
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
                        if type(day.k) == "table" then
                            for index = #day.k, 1, -1 do
                                local kill = day.k[index]
                                if type(kill) ~= "table" or type(kill.t) ~= "number" or not IsPlainText(kill.n)
                                    or (kill.z ~= nil and not IsPlainText(kill.z)) then
                                    table.remove(day.k, index)
                                end
                            end
                            if #day.k == 0 then
                                day.k = nil
                            end
                        elseif day.k ~= nil then
                            day.k = nil
                        end
                    end
                end
            elseif days ~= nil then
                person.days = nil
            end
        end
    end
end)
