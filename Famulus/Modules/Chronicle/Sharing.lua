-- Shares the chronicle with friends and guild members who use the addon as
-- well, wherever they are: milestones as they happen, what someone missed
-- while offline, and a handful of the character's own statistics.
--
-- Transport: addon messages whispered to friends and guild members who are
-- online; only the greeting to the guild goes to the guild channel. Someone
-- without the addon never sees them. Nothing is accepted from anyone who is
-- neither on the friends list nor in the guild, nor from anyone the player
-- ignores; and of fresh entries only a few a minute from one sender.
--
-- Messages (fields separated by "~", at most 255 bytes):
--   1~P                   to the guild: "I am here"; answered with a hello
--   1~H~<time>            hello: "I have your news up to <time>"
--   1~E~<time>~<kind>~k=v;k=v   one chronicle entry of the sender; among
--                         the values p=<time of the sender's entry before
--                         it>, by which the receiver sees that one got lost
--   1~S~<level>~id=n;id=n~<class>   the sender's level, statistics and
--                         class ("MAGE"); older versions leave the class out
--                         and ignore it
--   1~O~<who>~<time>      offer: "I have news of <who> up to <time>"
--   1~W~<who>~<time>      want: "send me what you have of <who> after <time>"
--   1~R~<who>~<time>~<kind>~k=v;k=v   one entry of <who>, passed on
--   1~X~<time>~<kind>~<reaction>~k=v  the sender's reaction to an entry of
--                         the receiver's ("cheer", "heart", ...; empty:
--                         taken back); k=v
--                         tells two entries of one second apart
-- A hello is answered with the entries the other side lacks, the statistics
-- and the offers. Whoever answered is "linked" for the session and gets the
-- live entries, and a moment after them the statistics once more.
--
-- Reactions (option "reactions"): a click on a companion's card in the book,
-- or on the button of their card in the live feed, gives one
-- (ChronicleService.React). It goes to them REACT_DELAY later, so that a
-- click on and off again sends nothing; to someone not linked it waits for
-- their next hello. Only what went out counts as told.
--
-- Passing on: news of someone who is offline comes from a linked companion
-- who has it. It is asked for and taken only about people the player shares
-- a guild with or whose addon answered directly within the last 30 days (an
-- answer comes only from someone who has the player on their friends list or
-- in their guild), so nothing arrives about strangers. Each person is asked
-- of one companion per session, so news does not arrive once per companion.
--
-- Sending: the client refuses addon messages during boss fights and on
-- restricted maps, and it lets each prefix send ten messages at once and
-- gives back one per second, except whispers outside instances
-- (warcraft.wiki.gg, SendAddonMessage). The server has its own limit and may
-- disconnect a client that sends too much. What the client refuses is lost,
-- so everything passes through a queue a ticker empties; the ticker runs
-- only while something waits. It keeps the client's count for the guild
-- channel, and for everything a bandwidth budget like ChatThrottleLib's,
-- which starts slow after a loading screen. A message the client refuses
-- anyway waits and goes again; a refused whisper makes whispers count too.
-- The queue has two lanes. The own entries, live or caught up, go first and
-- in order, with greetings, questions and the statistics after a live
-- entry; a companion's mark ("I have your news up to <time>") must never
-- pass over an entry they have not got. The statistics in an answer, offers
-- and passed-on entries wait behind them. A hello is answered with the
-- oldest CATCH_UP entries it lacks; once the last of them has gone, the next
-- ones follow. It replaces the own entries still waiting for that companion,
-- so a live entry never goes ahead of older ones. Both sides often greet
-- twice (when the other comes online and on the first contact); the mark in
-- a hello is read when it goes out, so the second costs little. Offers go
-- only about people who are not online themselves, and not again while
-- earlier ones to the same companion still wait or went out just before.
--
-- Trace: in developer mode ("/fam dev") every step goes into the trace
-- (ns:DevTrace): what was sent and received, what was dropped or ignored and
-- why, the counts of the guild roster and the friends list, loading screens.
-- A person appears as a tag, never by name (Tag).

local _, ns = ...
local Chronicle = ns.ChronicleService
local IsPlainText = ns.ChatService.IsPlainText

local sharing = ns:NewFeature({
    id = "sharing",
    category = "chronicle",
    icon = "share", -- its entry in the settings (UI.media)
    preview = "share", -- its picture there (UI/Previews.lua)
    default = false,
    requires = {
        "C_ChatInfo.SendAddonMessage",
        "C_ChatInfo.RegisterAddonMessagePrefix",
        "C_FriendList.GetNumFriends",
        "C_FriendList.GetFriendInfoByIndex",
    },
    -- Sent only on a click, so on from the start once sharing is.
    options = {
        { key = "reactions", type = "toggle", default = true },
    },
})

local PREFIX = "Famulus"
local VERSION = "1"
local SEND_INTERVAL = 0.5 -- seconds between two looks at the queue
local ALLOWANCE = 10 -- messages the client lets a prefix send at once
local REFILL = 1 -- messages it gives back per second
-- The bandwidth budget for all messages, ChatThrottleLib's (v32) values:
-- bytes per second, at most at once, and what each message costs on top.
local BANDWIDTH = 800
local BURST = 4000
local OVERHEAD = 40
local SETTLE = 5 -- seconds after a loading screen with a tenth of the bandwidth
local MAX_NOW = 100 -- messages waiting in the first lane, own entries not counted
local MAX_LATER = 200 -- messages waiting in the second lane
local CATCH_UP = 20 -- entries sent to someone who was away, per round
local MAX_REFUSED = 5 -- tries for a message the client answers with a bare false
local MAX_OFFERS = 20 -- people whose news is offered on a hello
-- Seconds in which a companion gets no offers again: the second hello of a
-- first contact comes right after the first, a reload takes longer.
local OFFER_GAP = 60
local LINK_AGE = 30 * 86400 -- how long a direct answer vouches for someone
local MAX_TEXT = 60 -- bytes of a name or place in a message
-- Seconds from an own event to the statistics that follow it: the game counts
-- a death a moment later, and events in a row share one message.
local STATS_DELAY = 5
-- Seconds from a click on a reaction to its message: on and off again in
-- that time sends nothing.
local REACT_DELAY = 2
-- Fresh entries (ChronicleService.FRESH) taken from one sender within
-- FRESH_SPAN seconds: a person brings forth a few a minute at most, and each
-- is a card on screen. One left out is a gap the sender's next entry names,
-- so it is asked for again (handlers.E); of ten and more in one minute, which
-- nobody's play brings forth, some may be lost for good.
local MAX_FRESH = 8
local FRESH_SPAN = 60
-- Seconds after which a gap that stayed is asked about a second and last time:
-- the first hello may have reached the sender during a boss fight.
local GAP_AGAIN = 60

-- What may travel, per kind: field -> "n" (number) or "s" (text).
local FIELDS = {
    level = { level = "n", zone = "s" },
    death = { level = "n", zone = "s" },
    boss = { id = "n", name = "s", zone = "s", first = "n", instance = "s" },
    achievement = { id = "n", name = "s", icon = "n" },
    zone = { level = "n", zone = "s" },
    instance = { instance = "s", level = "n" },
    pvpRank = { rank = "n", name = "s" },
    profession = { skill = "n", name = "s", icon = "n" },
    ability = { ability = "s", name = "s", level = "n" },
    item = { item = "n", name = "s", level = "n", zone = "s" },
    mount = { mount = "n", name = "s", icon = "n", level = "n", zone = "s" },
    skill = { skill = "n", name = "s", rank = "n", icon = "n" },
    joined = { level = "n" },
}

local friends = {} -- key -> name: friends who are online
local guild = {} -- key -> name: guild members, online or not
local guildOnline = {} -- key -> name: guild members who are online
local online = {} -- key -> name: friends and guild members who are online
local linked = {} -- key -> name: whose addon answered this session
local asked = {} -- key of someone offline -> key of the companion asked about them
local gone = {} -- key -> true: the client said they are offline, the lists not yet
local helloWaiting = {} -- key -> true: a hello to them waits in the queue
local offeredAt = {} -- key -> GetTime() of the last offers queued for them
local registered = false
local greetedGuild = false
local statsPending = false -- the statistics will go out to the linked shortly
local reactionsDue = {} -- entry -> true: clicked on, to be told after REACT_DELAY
local reactionsPending = false -- that telling is on its way
local reactionWaiting = {} -- entry -> true: a reaction to it waits in the queue
local gapAsked = {} -- key -> { mark, at, twice }: when their news was asked for again (handlers.E)
local freshFrom = {} -- key -> { at = GetTime() the span began, n = fresh entries taken in it }
local tracedRoster, tracedFriends, tracedLockdown = nil, nil, false -- what the trace last said

-- A name without the realm the client may add, and one spelling for it
-- however the client writes it.
local Plain, Key = ns.SocialService.Plain, ns.SocialService.Key

-- The name of someone whose news may be passed on to the player, or nil:
-- a guild member, or someone whose addon answered directly not long ago.
local function Vouched(key)
    if guild[key] then
        return guild[key]
    end
    local link = Chronicle.Link(key)
    if link and type(link.t) == "number" and time() - link.t <= LINK_AGE then
        return link.name
    end
    return nil
end

-- The playing character, as the guild channel echoes it back.
local function OwnKey()
    local name, surname = UnitName("player")
    if not IsPlainText(name) then
        return nil
    end
    return Key(IsPlainText(surname) and (name .. " " .. surname) or name)
end

---------------------------------------------------------------------------
-- Trace (developer mode)
---------------------------------------------------------------------------

-- A person in the trace: their initials and a number from their name key,
-- "AW-1c4" for Arisa Werkatz. The same on every client and in every session,
-- so two players' traces can be laid side by side, and no name is stored.
-- Outside developer mode it costs nothing.
local function Tag(key)
    if not ns:IsDevMode() then
        return ""
    end
    if not key then
        return "guild"
    end
    local initials, hash = "", 0
    for part in string.gmatch(key, "[^%-]+") do
        initials = initials .. (string.match(part, "^[\1-\127\192-\255][\128-\191]*") or "")
    end
    for i = 1, #key do
        hash = (hash * 31 + string.byte(key, i)) % 4096
    end
    return string.format("%s-%03x", string.upper(initials), hash)
end

-- The kind of a message, "H" for "1~H~...".
local function KindOf(text)
    return type(text) == "string" and string.match(text, "^%d+~(%u)") or "?"
end

local function Trace(text, ...)
    if ns:IsDevMode() then
        ns:DevTrace("SHARE", select("#", ...) > 0 and string.format(text, ...) or text)
    end
end

-- A time in the trace; 0 is "the start" (nothing known yet).
local function When(t)
    if t == 0 then
        return "the start"
    end
    return date and date("%Y-%m-%d %H:%M:%S", t) or tostring(t)
end

---------------------------------------------------------------------------
-- Encoding
---------------------------------------------------------------------------

-- Text that is safe inside a message and on screen: no separators, no
-- escape sequences, not too long.
local function Clean(text)
    text = string.gsub(tostring(text), "[~;=|%c]", " ")
    if #text > MAX_TEXT then
        text = string.sub(text, 1, MAX_TEXT)
        text = string.gsub(text, "[\192-\255][\128-\191]*$", "") -- no half UTF-8 character
    end
    return text
end

-- The values of an entry as "k=v;k=v", those named in fields only: field
-- -> "n" (number) or "s" (text).
local function EncodeFields(entry, fields)
    local parts = {}
    for field, kind in pairs(fields) do
        local value = entry[field]
        if kind == "n" and type(value) == "number" then
            parts[#parts + 1] = field .. "=" .. string.format("%d", value)
        elseif kind == "s" and type(value) == "string" and value ~= "" then
            parts[#parts + 1] = field .. "=" .. Clean(value)
        end
    end
    table.sort(parts)
    return table.concat(parts, ";")
end

-- An entry as "1~E~..." or, with who, as "1~R~<who>~...". before: for an
-- own entry the time of the one before it (ChronicleService.OwnBefore), sent
-- along as "p" (see handlers.E); left out where the message would grow too
-- long. Older versions drop the value as one they do not know.
local function EncodeEntry(entry, who, before)
    local fields = FIELDS[entry.k]
    if not fields then
        return nil
    end
    local head = who and (VERSION .. "~R~" .. Clean(who)) or (VERSION .. "~E")
    local values = EncodeFields(entry, fields)
    local text = table.concat({ head, string.format("%d", entry.t), entry.k, values }, "~")
    if before and before > 0 then
        local longer = text .. (values ~= "" and ";" or "") .. string.format("p=%d", before)
        if #longer <= 255 then
            return longer
        end
    end
    return text
end

-- The player's reaction to a companion's entry, as it is now, as "1~X~...".
local function EncodeReaction(entry)
    return table.concat({ VERSION, "X", string.format("%d", entry.t), entry.k, entry.mine or "",
        EncodeFields(entry, Chronicle.MARKS) }, "~")
end

-- A whole number as a message writes it: digits only, and no more of them
-- than a time or an ID has. tonumber alone also reads "1e999" (infinite),
-- "nan" and "0x10"; a time that is no number would break the order of the
-- chronicle's entries.
local function Int(text)
    if type(text) ~= "string" or #text > 10 or not string.match(text, "^%d+$") then
        return nil
    end
    return tonumber(text)
end

-- "k=v;k=v" -> table, keeping only the fields that kind allows.
local function DecodeFields(text, fields)
    local values = {}
    for field, value in string.gmatch(text or "", "([%a]+)=([^;]*)") do
        local kind = fields[field]
        if kind == "n" then
            values[field] = Int(value)
        elseif kind == "s" and value ~= "" then
            values[field] = Clean(value)
        end
    end
    return values
end

-- The character's own statistics: { [id] = number } for the shared IDs
-- (ChronicleService.STATISTICS).
local function OwnStatistics()
    local wanted, values = {}, {}
    for _, id in ipairs(Chronicle.STATISTICS) do
        wanted[id] = true
    end
    if not (GetStatisticsCategoryList and GetCategoryNumAchievements and GetStatistic) then
        return values
    end
    for _, category in ipairs(GetStatisticsCategoryList() or {}) do
        for index = 1, GetCategoryNumAchievements(category) or 0 do
            local quantity, _, id = GetStatistic(category, index)
            if wanted[id] and not ns.IsSecret(quantity) then
                -- "1,234" or "1.234" or "--"
                local number = tonumber((string.gsub(tostring(quantity), "[^%d]", "")))
                if number then
                    values[id] = number
                end
            end
        end
    end
    return values
end

local function EncodeStatistics()
    local parts = {}
    for id, value in pairs(OwnStatistics()) do
        parts[#parts + 1] = string.format("%d=%d", id, value)
    end
    table.sort(parts)
    local level = UnitLevel and tonumber(UnitLevel("player")) or 0
    -- The class, for the picture beside the name on the other side.
    local _, classFile = UnitClass("player")
    if ns.IsSecret(classFile) or type(classFile) ~= "string" or not string.match(classFile, "^%u+$") then
        classFile = ""
    end
    return table.concat({ VERSION, "S", string.format("%d", level), table.concat(parts, ";"), classFile }, "~")
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------

-- What SendAddonMessage answers, as the client names it.
local RESULT = Enum and Enum.SendAddonMessageResult or {}
local THROTTLED = RESULT.AddonMessageThrottle or 3 -- too fast for this prefix
local CHANNEL_THROTTLED = RESULT.ChannelThrottle or 8
local LOCKDOWN = RESULT.AddOnMessageLockdown or 11 -- boss fight, restricted map
local OFFLINE = RESULT.TargetOffline or 12
local SUCCESS = RESULT.Success or 0

-- An answer of SendAddonMessage as the client names it, for the trace.
local function ResultName(result)
    for name, value in pairs(RESULT) do
        if value == result then
            return name
        end
    end
    return tostring(result)
end

-- A lane of the queue: first come, first served. others: how many of the
-- waiting messages carry no own entry; only they count against max.
local function NewLane(max)
    return { head = 1, tail = 0, max = max, others = 0 }
end

local nowLane, laterLane = NewLane(MAX_NOW), NewLane(MAX_LATER)
local allowance, refilled = ALLOWANCE, nil -- our count of the client's, and when it was last topped up
local bytes = 0 -- what the bandwidth budget has left
local settleUntil = 0 -- GetTime() until which the budget refills slowly
local whispersCounted = false -- the client refused a whisper: they count against the allowance too

local function Waiting(lane)
    return lane.tail - lane.head + 1
end

-- What the client said, in the developer log, once per session and kind.
local noted = {}
local function Note(what)
    if not noted[what] then
        noted[what] = true
        ns:DevLog("SHARE", what)
    end
end

-- A companion who will not answer: what was asked of them is free to ask
-- of someone else.
local function Unask(key)
    for whoKey, companion in pairs(asked) do
        if companion == key then
            asked[whoKey] = nil
        end
    end
end

local CatchUp -- below; the last entry of a round calls for the next

-- Tops up both budgets for the time since the last look.
local function Refill(clock)
    local elapsed = clock - (refilled or clock)
    refilled = clock
    allowance = math.min(ALLOWANCE, allowance + elapsed * REFILL)
    if clock < settleUntil then
        bytes = math.min(BANDWIDTH / 2, bytes + elapsed * BANDWIDTH / 10)
    else
        bytes = math.min(BURST, bytes + elapsed * BANDWIDTH)
    end
end

-- Sends what waits, as far as the budgets go: the first lane first.
local function Flush()
    if Waiting(nowLane) + Waiting(laterLane) <= 0 then
        nowLane, laterLane = NewLane(MAX_NOW), NewLane(MAX_LATER)
        sharing:StopTicker()
        return
    end
    -- During a boss fight the client would drop the message; wait it out.
    if ns.ChatService.InLockdown() then
        if not tracedLockdown then
            tracedLockdown = true
            Trace("chat lockdown: the queue waits")
        end
        return
    end
    if tracedLockdown then
        tracedLockdown = false
        Trace("chat lockdown over")
    end
    Refill(GetTime())
    while true do
        local lane = Waiting(nowLane) > 0 and nowLane or laterLane
        local item = lane[lane.head]
        if not item then
            return
        end
        local result, continueFrom, sent = nil, nil, false
        -- Someone who went offline in the meantime gets nothing: whispering
        -- into the void would print an error in the player's chat. A skipped
        -- item was replaced by a later round of catching up.
        if not item.skip and (item.channel or (online[item.key] and not gone[item.key])) then
            local text = item.text
            if type(text) == "function" then
                text = text()
            end
            local counted = item.channel or whispersCounted
            if bytes < #text + OVERHEAD or (counted and allowance < 1) then
                return -- the next look has more
            end
            result = C_ChatInfo.SendAddonMessage(PREFIX, text, item.channel or "WHISPER", online[item.key])
            if ns.IsSecret(result) then
                result = nil
            end
            -- Older clients answer true or false; false may also mean a
            -- refusal that lasts, so it is tried a few times only.
            if result == false then
                item.refused = (item.refused or 0) + 1
            end
            if result == THROTTLED or result == CHANNEL_THROTTLED or result == LOCKDOWN
                or (result == false and item.refused < MAX_REFUSED) then
                -- Refused, so not sent: the message stays first in line and
                -- waits until the client lets more through. A refused
                -- whisper means this client counts whispers after all.
                if result ~= LOCKDOWN and not item.channel then
                    whispersCounted = true
                end
                Note(result == LOCKDOWN and "lockdown" or item.channel and "throttled" or "whisper throttled")
                Trace("refused %s to %s: %s, it waits", KindOf(text), Tag(item.key), result == false and "false" or ResultName(result))
                allowance = 0
                return
            end
            bytes = bytes - (#text + OVERHEAD)
            if counted then
                allowance = allowance - 1
            end
            if result == OFFLINE and item.key then
                Note("offline")
                Trace("sent %s to %s: the client says they are offline, nothing more to them", KindOf(text), Tag(item.key))
                gone[item.key] = true
                Unask(item.key)
            elseif result == false then
                Trace("gave up %s to %s: refused %d times", KindOf(text), Tag(item.key), item.refused)
            else
                if item.more then
                    continueFrom = item.t
                end
                if result == nil or result == true or result == SUCCESS then
                    sent = true
                    Trace("sent %s to %s", KindOf(text), Tag(item.key))
                else
                    Trace("sent %s to %s: %s", KindOf(text), Tag(item.key), ResultName(result))
                end
            end
        elseif not item.skip then
            Trace("dropped %s to %s: %s", item.hello and "H" or KindOf(item.text), Tag(item.key),
                gone[item.key] and "the client said they are offline" or "not online")
        end
        if item.hello then
            helloWaiting[item.key] = nil
        end
        if not item.t then
            lane.others = lane.others - 1
        end
        lane[lane.head] = nil
        lane.head = lane.head + 1
        if continueFrom then
            CatchUp(item.key, continueFrom)
        end
        -- Whoever queued it hears whether it went out.
        if item.done then
            item.done(sent)
        end
    end
end

-- Queues a message for someone by key, or with channel for everyone there.
-- text: the message, or a function that writes it when it goes out. urgent:
-- the first lane. entryTime: the time of the own entry it carries; such a
-- message is never turned away, or the companion's mark would pass over it.
-- Each companion has at most CATCH_UP of them from catching up waiting
-- (CatchUp), and each own event one. always: never turned away either.
local function Queue(key, text, channel, urgent, entryTime, always)
    local lane = urgent and nowLane or laterLane
    if not text or (type(text) == "string" and #text > 255) then
        return
    end
    if not (entryTime or always) and lane.others >= lane.max then
        Trace("turned away %s to %s: the queue is full", KindOf(text), Tag(key))
        return
    end
    if not entryTime then
        lane.others = lane.others + 1
    end
    local item = { key = key, text = text, channel = channel, t = entryTime }
    lane.tail = lane.tail + 1
    lane[lane.tail] = item
    if not sharing.ticker then
        sharing:StartTicker(SEND_INTERVAL, Flush)
    end
    return item
end

local function Send(key, text, urgent, entryTime, always)
    return Queue(key, text, nil, urgent, entryTime, always)
end

-- The own entries key lacks after since: the oldest CATCH_UP (and the rest of
-- the last one's second), in order. They replace the own entries newer than
-- since still waiting for key, live ones included, so nothing newer goes
-- ahead of them; the last of a full round calls for the next once it has
-- gone (Flush). Own entries wait in the first lane only.
function CatchUp(key, since)
    for i = nowLane.head, nowLane.tail do
        local item = nowLane[i]
        if item.key == key and item.t and item.t > since then
            item.skip = true
        end
    end
    local entries, last = Chronicle.OwnSince(since, CATCH_UP), nil
    local before = entries[1] and Chronicle.OwnBefore(entries[1])
    for _, entry in ipairs(entries) do
        last = Send(key, EncodeEntry(entry, nil, before), true, entry.t) or last
        before = entry.t
    end
    if last and #entries >= CATCH_UP then
        last.more = true
    end
    Trace("catching up %s after %s: %d own entries%s", Tag(key), When(since), #entries,
        #entries >= CATCH_UP and ", more follow" or "")
end

-- The mark is read when the hello goes out: what arrives until then need
-- not be sent again, and one waiting hello is enough. It is never turned
-- away: after a first contact nothing would send it again. why: for the
-- trace.
local function SendHello(key, why)
    if helloWaiting[key] then
        Trace("hello to %s (%s): one waits already", Tag(key), why)
        return
    end
    local item = Send(key, function()
        return table.concat({ VERSION, "H", string.format("%d", Chronicle.NewestFrom(online[key])) }, "~")
    end, true, nil, true)
    item.hello, helloWaiting[key] = true, true
    Trace("hello to %s queued: %s", Tag(key), why)
end

-- Whether offers to key still wait in the queue.
local function OffersWaiting(key)
    for i = laterLane.head, laterLane.tail do
        if laterLane[i].key == key and laterLane[i].offer then
            return true
        end
    end
    return false
end

-- Offers the news of others this client knows, newest first, except of the
-- one who receives the offer and of people who are online and can tell it
-- themselves. Not again while earlier offers to them still wait or within
-- OFFER_GAP: the second hello of a first contact would double them.
local function SendOffers(key)
    if OffersWaiting(key) or (offeredAt[key] and GetTime() - offeredAt[key] < OFFER_GAP) then
        return
    end
    local entries, seen, count = Chronicle.Entries(), {}, 0
    for i = #entries, 1, -1 do
        local who = entries[i].who
        if who and FIELDS[entries[i].k] and not entries[i].demo then
            local whoKey = Key(who)
            if whoKey ~= key and not seen[whoKey] then
                seen[whoKey] = true
                if not online[whoKey] then
                    count = count + 1
                    local item = Send(key, table.concat({ VERSION, "O", Clean(who), string.format("%d", entries[i].t) }, "~"))
                    if not item then
                        return -- the lane is full; the next hello tries again
                    end
                    item.offer, offeredAt[key] = true, GetTime()
                    if count == MAX_OFFERS then
                        return
                    end
                end
            end
        end
    end
end

-- The statistics to every linked companion, STATS_DELAY after the first of
-- the events that called for them. Without this, a companion's view of them
-- stayed as it was at the last hello: a death did not count until one of
-- the two logged in again.
local function SendStatisticsSoon()
    if statsPending then
        return
    end
    statsPending = true
    sharing:After(STATS_DELAY, function()
        statsPending = false
        if next(linked) then
            local text = EncodeStatistics()
            for key in pairs(linked) do
                Send(key, text, true)
            end
        end
    end)
end

-- Tells the companion whose entry it is the player's reaction as it is now,
-- if they are linked and have yet to be told. It counts as told once it went
-- out; a change while it waited goes after it. To someone who is not linked
-- it waits for their next hello (TellReactions).
local function TellReaction(entry)
    local key = entry.who and Key(entry.who)
    if not key or not linked[key] or reactionWaiting[entry] or not sharing:Get("reactions")
        or not Chronicle.ReactionUntold(entry) then
        return
    end
    local reaction = entry.mine
    local item = Send(key, EncodeReaction(entry), true)
    if not item then
        return
    end
    reactionWaiting[entry] = true
    item.done = function(sent)
        reactionWaiting[entry] = nil
        if sent then
            Chronicle.ReactionTold(entry, reaction)
            TellReaction(entry)
        end
    end
    Trace("reaction to %s queued: %s", Tag(key), reaction and "given" or "taken back")
end

-- The reactions a companion has yet to be told, when they say hello.
local function TellReactions(key)
    local entries = Chronicle.Entries()
    for i = #entries, 1, -1 do
        local entry = entries[i]
        if entry.who and Chronicle.ReactionUntold(entry) and Key(entry.who) == key then
            TellReaction(entry)
        end
    end
end

-- A click on a reaction: told REACT_DELAY later, with the clicks that
-- follow it until then.
local function OnReacted(entry)
    if not sharing.enabled or type(entry) ~= "table" then
        return
    end
    reactionsDue[entry] = true
    if reactionsPending then
        return
    end
    reactionsPending = true
    sharing:After(REACT_DELAY, function()
        local due = reactionsDue
        reactionsDue, reactionsPending = {}, false
        for each in pairs(due) do
            TellReaction(each)
        end
    end)
end

-- A fresh entry of the player's own goes to every linked companion, and the
-- statistics after it.
local function OnChronicleChanged(entry)
    if not sharing.enabled or not entry or entry.demo or entry.who or entry.c ~= Chronicle.Character() then
        return
    end
    local text, count = EncodeEntry(entry, nil, Chronicle.OwnBefore(entry)), 0
    for key in pairs(linked) do
        Send(key, text, true, entry.t)
        count = count + 1
    end
    Trace("own entry %s: to %d linked", tostring(entry.k), count)
    if count > 0 then
        SendStatisticsSoon()
    end
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------

-- Writes down an entry that came in. key: who sent it.
local function Take(kind, when, fields, who, via, key)
    local allowed = FIELDS[kind]
    if not allowed then
        return
    end
    local entry = DecodeFields(fields, allowed)
    entry.t = Int(when)
    if not entry.t then
        Trace("entry not taken: its time is no number")
        return
    end
    entry.who = who
    entry.via = via
    -- Of fresh entries only MAX_FRESH from one sender in FRESH_SPAN.
    local isFresh, clock = time() - entry.t <= Chronicle.FRESH, GetTime()
    local span = isFresh and freshFrom[key]
    if span and clock - span.at >= FRESH_SPAN then
        span = nil -- (that one is over)
    end
    if span and span.n >= MAX_FRESH then
        Trace("entry from %s not taken: too many fresh ones at once", Tag(key))
        return
    end
    -- Fresh news appears on screen through the live feed, which listens
    -- to the chronicle (Modules/Chronicle/LiveFeed.lua).
    local added = Chronicle.Add(kind, entry)
    if added == false then
        Trace("entry not taken: known already, or its time is ahead of this clock")
    elseif added and isFresh then
        if not span then
            span = { at = clock, n = 0 }
            freshFrom[key] = span
        end
        span.n = span.n + 1
    end
end

local handlers = {}

-- "I am here", to the guild: greet them, they answer with their news. It
-- goes out once per session, after a login or a reload: whoever sends it
-- knows nobody yet, even if they are still linked here.
function handlers.P(key)
    SendHello(key, "their guild greeting")
end

-- "I have your news up to <time>": send what is newer, the statistics and
-- what we know of others, and the reactions to their news they missed.
function handlers.H(key, since)
    CatchUp(key, Int(since) or 0)
    Send(key, EncodeStatistics())
    SendOffers(key)
    TellReactions(key)
end

-- A reaction to one of the player's own entries ("1~X~<time>~<kind>~<reaction>~k=v").
-- One this version does not know (a newer one's), or one not of the kind's
-- set (ChronicleService.REACTION_SETS), counts as the kind's own.
function handlers.X(key, when, kind, reaction, marks)
    local own = Chronicle.REACTIONS[kind or ""]
    if not sharing:Get("reactions") or not own then
        Trace("reaction from %s not taken: %s", Tag(key), own and "reactions are off" or "a kind without reactions")
        return
    end
    if reaction == "" or reaction == nil then
        reaction = nil
    elseif not Chronicle.IsReaction(reaction, kind) then
        reaction = own
    end
    local entry = Chronicle.Receive(Int(when), kind, DecodeFields(marks, Chronicle.MARKS), online[key], reaction)
    Trace("reaction from %s %s: %s", Tag(key), reaction and "given" or "taken back",
        entry and "to an own entry" or "no such own entry, not taken")
end

-- An own entry names the time of the sender's entry before it ("p"). If that
-- is newer than anything we have of them, something got lost on the way: the
-- client drops what arrives during a boss fight, and a queue ends with a
-- /reload. The entry is then not taken, or the mark in our next hello would
-- pass over the gap for good; a hello asks for everything after the mark
-- instead, this entry included. Twice per mark at most, the second time
-- GAP_AGAIN later: if what comes then does not move the mark (a kind this
-- version does not know), entries are taken as they come, and two clients
-- never ask each other in a circle.
local PREVIOUS = { p = "n" }

function handlers.E(key, when, kind, fields)
    local before = DecodeFields(fields, PREVIOUS).p
    local mark = Chronicle.NewestFrom(online[key])
    if before and before > mark then
        local asked = gapAsked[key]
        local again = asked ~= nil and asked.mark == mark
        if not again or (not asked.twice and GetTime() - asked.at >= GAP_AGAIN) then
            gapAsked[key] = { mark = mark, at = GetTime(), twice = again or nil }
            Trace("gap in the news of %s: asking again from %s", Tag(key), When(mark))
            SendHello(key, "a gap in their news")
            return
        end
    end
    Take(kind, when, fields, online[key], nil, key)
end

function handlers.S(key, level, fields, classFile)
    local stats = {}
    for id, value in string.gmatch(fields or "", "(%d+)=(%d+)") do
        id, value = Int(id), Int(value)
        if id and value then
            stats[id] = value
        end
    end
    Chronicle.Class(online[key], classFile) -- checked there; nil from older versions
    Chronicle.Profile(online[key], { level = Int(level) or 0, stats = stats })
end

-- "I have news of <who> up to <time>": ask for it if it is news to us,
-- about someone vouched for who cannot tell it themselves right now.
function handlers.O(key, who, newest)
    if not IsPlainText(who) then
        return
    end
    local whoKey = Key(who)
    local name = Vouched(whoKey)
    local skip = not name and "not vouched for" or whoKey == OwnKey() and "about the player"
        or linked[whoKey] and "linked themselves" or asked[whoKey] and "asked of someone else"
    if skip then
        Trace("offer from %s about %s not taken: %s", Tag(key), Tag(whoKey), skip)
        return
    end
    local since = Chronicle.NewestFrom(name, true)
    if (Int(newest) or 0) <= since then
        Trace("offer from %s about %s not taken: nothing new", Tag(key), Tag(whoKey))
    elseif Send(key, table.concat({ VERSION, "W", Clean(name), string.format("%d", since) }, "~"), true) then
        asked[whoKey] = key
    end
end

-- "Send me what you have of <who> after <time>".
function handlers.W(key, who, since)
    if not IsPlainText(who) then
        return
    end
    local whoKey, found = Key(who), {}
    if whoKey == key then
        return -- their own news they have
    end
    since = Int(since) or 0
    local entries = Chronicle.Entries()
    for i = #entries, 1, -1 do
        local entry = entries[i]
        if entry.t <= since or #found == CATCH_UP then
            break
        end
        if entry.who and FIELDS[entry.k] and not entry.demo and Key(entry.who) == whoKey then
            table.insert(found, 1, entry)
        end
    end
    for _, entry in ipairs(found) do
        Send(key, EncodeEntry(entry, entry.who))
    end
    Trace("%s asks about %s: %d entries to pass on", Tag(key), Tag(whoKey), #found)
end

-- One entry of <who>, passed on: only as asked for, and only about someone
-- vouched for. It names who passed it on.
function handlers.R(key, who, when, kind, fields)
    if not IsPlainText(who) then
        return
    end
    local whoKey = Key(who)
    local name = Vouched(whoKey)
    if not name or asked[whoKey] ~= key then
        Trace("passed-on entry from %s about %s not taken: %s", Tag(key), Tag(whoKey),
            not name and "not vouched for" or "not asked of them")
        return
    end
    Take(kind, when, fields, name, online[key], key)
end

function sharing:CHAT_MSG_ADDON(_, prefix, text, channel, sender)
    if ns.IsSecret(prefix) or prefix ~= PREFIX then
        return
    end
    if not IsPlainText(text) or not IsPlainText(sender) or ns.IsSecret(channel) then
        Trace("ignored a message: sender, text or channel unreadable (secret?)")
        return
    end
    local key = Key(sender)
    local version, kind, a, b, c, d = strsplit("~", text)
    local label = string.match(kind or "", "^%u$") or "?"
    if key == OwnKey() then
        if kind == "P" then
            Trace("own guild greeting came back from the guild channel")
        end
        return
    end
    if version ~= VERSION then
        Trace("ignored %s from %s: version %s", label, Tag(key), string.match(version or "", "^%d+$") or "?")
        return
    end
    -- Only the greeting goes to the guild.
    if channel ~= "WHISPER" and not (channel == "GUILD" and kind == "P") then
        Trace("ignored %s from %s: came by %s", label, Tag(key), string.match(tostring(channel), "^%u+$") or "?")
        return
    end
    -- A guild member who speaks is online, even if the roster does not say
    -- so yet.
    if guild[key] and not online[key] then
        Trace("%s speaks, so is online, though the roster says not", Tag(key))
        guildOnline[key] = guild[key]
        online[key] = guild[key]
    end
    if not online[key] then
        -- Neither a friend nor in the guild: ignored.
        Trace("ignored %s from %s: neither a friend online nor in the guild", label, Tag(key))
        return
    end
    -- Whoever the player ignores is not heard here either (a guild member, say).
    if ns.SocialService.Ignored(sender) or (online[key] ~= sender and ns.SocialService.Ignored(online[key])) then
        Trace("ignored %s from %s: on the player's ignore list", label, Tag(key))
        return
    end
    gone[key] = nil -- whoever speaks is online, whatever the client said before
    local handler = handlers[kind]
    if not handler then
        Trace("ignored %s from %s: a kind this version does not know", label, Tag(key))
        return
    end
    Trace("got %s from %s", label, Tag(key))
    if kind == "P" then
        handler(key)
        return
    end
    -- Whoever speaks the protocol is linked. A first contact is greeted
    -- back, so that we get their news as well; they are linked by then and
    -- do not greet again.
    local firstContact = not linked[key]
    linked[key] = online[key]
    if firstContact then
        Trace("first contact with %s: linked", Tag(key))
        Chronicle.Link(key, online[key])
    end
    handler(key, a, b, c, d)
    if firstContact then
        SendHello(key, "first contact")
    end
end

---------------------------------------------------------------------------
-- Friends and guild
---------------------------------------------------------------------------

-- Who is online now: friends and guild members. Friends who came online are
-- greeted; guild members greet the guild themselves when they arrive.
local function Refresh()
    local now = {}
    for key, name in pairs(guildOnline) do
        now[key] = name
    end
    for key, name in pairs(friends) do
        now[key] = name
    end
    -- Whoever went offline starts afresh when they come back.
    for key in pairs(online) do
        if not now[key] then
            if linked[key] or helloWaiting[key] then
                Trace("%s is no longer online in the lists", Tag(key))
            end
            linked[key], gone[key] = nil, nil
            Unask(key)
        end
    end
    local previous = online
    online = now
    for key in pairs(friends) do
        if not previous[key] then
            SendHello(key, "a friend online")
        end
    end
end

function sharing:FRIENDLIST_UPDATE()
    friends = {}
    local count = 0
    ns.SocialService.EachFriend(function(info)
        if not ns.IsSecret(info.connected) and info.connected and IsPlainText(info.name) then
            friends[Key(info.name)] = Plain(info.name)
            count = count + 1
        end
    end)
    if count ~= tracedFriends then
        tracedFriends = count
        Trace("friends list: %d online", count)
    end
    Refresh()
end

function sharing:GUILD_ROSTER_UPDATE()
    guild, guildOnline = {}, {}
    local members, present = 0, 0
    local keeping = ns.SocialService.EachGuildMember(function(name, isOnline, isMobile)
        if name then
            local key = Key(name)
            guild[key] = Plain(name)
            members = members + 1
            if isOnline and not isMobile then
                guildOnline[key] = guild[key]
                present = present + 1
            end
        end
    end)
    local roster = members .. "/" .. present .. (keeping and "/kept" or "")
    if roster ~= tracedRoster then
        tracedRoster = roster
        local inGuild = IsInGuild and IsInGuild()
        if keeping then
            Trace("guild roster came empty, keeping the last one: %d members, %d online", members, present)
        else
            Trace("guild roster: %d members, %d online%s", members, present,
                members == 0 and not ns.IsSecret(inGuild) and inGuild and " (empty, though in a guild)" or "")
        end
    end
    Refresh()
    -- Greet the guild once its roster is known: the answers come by whisper
    -- and are taken only from members.
    if not greetedGuild and next(guild) then
        greetedGuild = true
        Queue(nil, VERSION .. "~P", "GUILD", true)
        Trace("guild greeting queued")
    end
end

-- The server is touchy after a loading screen (ChatThrottleLib's
-- experience): the budget starts empty and refills slowly for a while.
function sharing:PLAYER_ENTERING_WORLD()
    Refill(GetTime())
    bytes, settleUntil = 0, GetTime() + SETTLE
    Trace("loading screen: sending starts slowly for %d seconds", SETTLE)
end

function sharing:OnEnable()
    Trace("switched on")
    if not registered then
        registered = true
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        ns:On("CHRONICLE_CHANGED", OnChronicleChanged)
        ns:On("CHRONICLE_REACTED", OnReacted)
    end
    self:RegisterEvent("CHAT_MSG_ADDON")
    self:RegisterEvent("FRIENDLIST_UPDATE")
    self:RegisterEvent("GUILD_ROSTER_UPDATE")
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    -- Famulus was installed on this account just now (Core/Features.lua): the
    -- first time sharing is on, the chronicle says the player joined, and it
    -- goes to friends and guild members like any own entry, so they can
    -- welcome them. Once only; whoever had Famulus before is never announced.
    -- A moment later: switched on at login, the chronicle does not know the
    -- character yet, and an entry without it never goes out.
    if ns.global and ns.global.newcomer then
        self:After(1, function()
            ns.global.newcomer = nil
            Trace("new on this account: the chronicle says the player joined")
            Chronicle.Add("joined", { level = UnitLevel and UnitLevel("player") or nil })
        end)
    end
    if C_FriendList.ShowFriends then
        C_FriendList.ShowFriends()
    end
    if C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster() -- asks the server for a fresh roster
    end
    self:GUILD_ROSTER_UPDATE()
    self:FRIENDLIST_UPDATE()
end

function sharing:OnDisable()
    Trace("switched off")
    friends, guild, guildOnline, online, linked, asked = {}, {}, {}, {}, {}, {}
    gone, helloWaiting, offeredAt = {}, {}, {}
    tracedRoster, tracedFriends, tracedLockdown = nil, nil, false
    whispersCounted = false
    greetedGuild, statsPending = false, false -- a pending After lapses with the feature
    reactionsDue, reactionsPending, reactionWaiting = {}, false, {} -- what is untold waits for a hello
    gapAsked, freshFrom = {}, {}
    nowLane, laterLane = NewLane(MAX_NOW), NewLane(MAX_LATER)
end

-- For the bug report (Core/SelfTest.lua): counts only, never names. How many
-- are linked, how many friends and guild members are online, and how many
-- messages wait in the queue.
function sharing.Status()
    local function Count(map)
        local n = 0
        for _ in pairs(map) do
            n = n + 1
        end
        return n
    end
    return Count(linked), Count(online), Waiting(nowLane) + Waiting(laterLane)
end

-- For the tests.
sharing.EncodeEntry = EncodeEntry
sharing.Key = Key
sharing.Tag = Tag
