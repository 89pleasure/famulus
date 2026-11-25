-- Shares the chronicle with friends and guild members who use the addon as
-- well, wherever they are: milestones as they happen, what someone missed
-- while offline, and a handful of the character's own statistics.
--
-- Transport: addon messages whispered to friends and guild members who are
-- online; only the greeting to the guild goes to the guild channel. Someone
-- without the addon never sees them. Nothing is accepted from anyone who is
-- neither on the friends list nor in the guild.
--
-- Messages (fields separated by "~", at most 255 bytes):
--   1~P                   to the guild: "I am here"; answered with a hello
--   1~H~<time>            hello: "I have your news up to <time>"
--   1~E~<time>~<kind>~k=v;k=v   one chronicle entry of the sender
--   1~S~<level>~id=n;id=n~<class>   the sender's level, statistics and
--                         class ("MAGE"); older versions leave the class out
--                         and ignore it
--   1~O~<who>~<time>      offer: "I have news of <who> up to <time>"
--   1~W~<who>~<time>      want: "send me what you have of <who> after <time>"
--   1~R~<who>~<time>~<kind>~k=v;k=v   one entry of <who>, passed on
-- A hello is answered with the entries the other side lacks, the statistics
-- and the offers. Whoever answered is "linked" for the session and gets the
-- live entries, and a moment after them the statistics once more.
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
-- gives back one per second (warcraft.wiki.gg, retail since 10.2.7; Forever
-- unconfirmed). What it refuses is lost, so everything passes through a queue
-- that keeps the same count and a ticker empties; the ticker runs only while
-- something waits. A message the client refuses anyway waits and goes again.
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
-- earlier ones to the same companion still wait.

local _, ns = ...
local Chronicle = ns.ChronicleService
local IsPlainText = ns.ChatService.IsPlainText

local sharing = ns:NewFeature({
    id = "sharing",
    category = "chronicle",
    default = false,
    requires = {
        "C_ChatInfo.SendAddonMessage",
        "C_ChatInfo.RegisterAddonMessagePrefix",
        "C_FriendList.GetNumFriends",
        "C_FriendList.GetFriendInfoByIndex",
    },
})

local PREFIX = "Famulus"
local VERSION = "1"
local SEND_INTERVAL = 0.5 -- seconds between two looks at the queue
local ALLOWANCE = 10 -- messages the client lets a prefix send at once
local REFILL = 1 -- messages it gives back per second
local MAX_NOW = 100 -- messages waiting in the first lane, own entries not counted
local MAX_LATER = 200 -- messages waiting in the second lane
local CATCH_UP = 20 -- entries sent to someone who was away, per round
local MAX_REFUSED = 5 -- tries for a message the client answers with a bare false
local MAX_OFFERS = 20 -- people whose news is offered on a hello
local LINK_AGE = 30 * 86400 -- how long a direct answer vouches for someone
local MAX_TEXT = 60 -- bytes of a name or place in a message
-- Seconds from an own event to the statistics that follow it: the game counts
-- a death a moment later, and events in a row share one message.
local STATS_DELAY = 5

-- What may travel, per kind: field -> "n" (number) or "s" (text).
local FIELDS = {
    level = { level = "n", zone = "s" },
    death = { level = "n", zone = "s" },
    boss = { id = "n", name = "s", zone = "s" },
    achievement = { id = "n", name = "s", icon = "n" },
    zone = { level = "n", zone = "s" },
    profession = { skill = "n", name = "s", icon = "n" },
    ability = { ability = "s", name = "s", level = "n" },
    item = { item = "n", name = "s", level = "n", zone = "s" },
    skill = { skill = "n", name = "s", rank = "n", icon = "n" },
}

local friends = {} -- key -> name: friends who are online
local guild = {} -- key -> name: guild members, online or not
local guildOnline = {} -- key -> name: guild members who are online
local online = {} -- key -> name: friends and guild members who are online
local linked = {} -- key -> name: whose addon answered this session
local asked = {} -- key of someone offline -> key of the companion asked about them
local gone = {} -- key -> true: the client said they are offline, the lists not yet
local helloWaiting = {} -- key -> true: a hello to them waits in the queue
local registered = false
local greetedGuild = false
local statsPending = false -- the statistics will go out to the linked shortly

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

-- An entry as "1~E~..." or, with who, as "1~R~<who>~...".
local function EncodeEntry(entry, who)
    local fields = FIELDS[entry.k]
    if not fields then
        return nil
    end
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
    local head = who and (VERSION .. "~R~" .. Clean(who)) or (VERSION .. "~E")
    return table.concat({ head, string.format("%d", entry.t), entry.k, table.concat(parts, ";") }, "~")
end

-- "k=v;k=v" -> table, keeping only the fields that kind allows.
local function DecodeFields(text, fields)
    local values = {}
    for field, value in string.gmatch(text or "", "([%a]+)=([^;]*)") do
        local kind = fields[field]
        if kind == "n" then
            values[field] = tonumber(value)
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

-- A lane of the queue: first come, first served. others: how many of the
-- waiting messages carry no own entry; only they count against max.
local function NewLane(max)
    return { head = 1, tail = 0, max = max, others = 0 }
end

local nowLane, laterLane = NewLane(MAX_NOW), NewLane(MAX_LATER)
local allowance, refilled = ALLOWANCE, nil -- our count of the client's, and when it was last topped up

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

-- Sends what waits, as far as the allowance goes: the first lane first.
local function Flush()
    if Waiting(nowLane) + Waiting(laterLane) <= 0 then
        nowLane, laterLane = NewLane(MAX_NOW), NewLane(MAX_LATER)
        sharing:StopTicker()
        return
    end
    -- During a boss fight the client would drop the message; wait it out.
    if ns.ChatService.InLockdown() then
        return
    end
    local clock = GetTime()
    allowance = math.min(ALLOWANCE, allowance + (clock - (refilled or clock)) * REFILL)
    refilled = clock
    while allowance >= 1 do
        local lane = Waiting(nowLane) > 0 and nowLane or laterLane
        local item = lane[lane.head]
        if not item then
            return
        end
        local result, continueFrom
        -- Someone who went offline in the meantime gets nothing: whispering
        -- into the void would print an error in the player's chat. A skipped
        -- item was replaced by a later round of catching up.
        if not item.skip and (item.channel or (online[item.key] and not gone[item.key])) then
            local text = item.text
            if type(text) == "function" then
                text = text()
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
                -- waits until the client lets more through.
                Note(result == LOCKDOWN and "lockdown" or "throttled")
                allowance = 0
                return
            end
            allowance = allowance - 1
            if result == OFFLINE and item.key then
                Note("offline")
                gone[item.key] = true
                Unask(item.key)
            elseif result ~= false and item.more then
                continueFrom = item.t
            end
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
    if not text or (type(text) == "string" and #text > 255)
        or (not (entryTime or always) and lane.others >= lane.max) then
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
    for _, entry in ipairs(entries) do
        last = Send(key, EncodeEntry(entry), true, entry.t) or last
    end
    if last and #entries >= CATCH_UP then
        last.more = true
    end
end

-- The mark is read when the hello goes out: what arrives until then need
-- not be sent again, and one waiting hello is enough. It is never turned
-- away: after a first contact nothing would send it again.
local function SendHello(key)
    if helloWaiting[key] then
        return
    end
    local item = Send(key, function()
        return table.concat({ VERSION, "H", string.format("%d", Chronicle.NewestFrom(online[key])) }, "~")
    end, true, nil, true)
    item.hello, helloWaiting[key] = true, true
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
-- themselves. Not again while earlier offers to them still wait: the second
-- hello of a first contact would double them.
local function SendOffers(key)
    if OffersWaiting(key) then
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
                    item.offer = true
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

-- A fresh entry of the player's own goes to every linked companion, and the
-- statistics after it.
local function OnChronicleChanged(entry)
    if not sharing.enabled or not entry or entry.demo or entry.who or entry.c ~= Chronicle.Character() then
        return
    end
    local text = EncodeEntry(entry)
    for key in pairs(linked) do
        Send(key, text, true, entry.t)
    end
    if next(linked) then
        SendStatisticsSoon()
    end
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------

-- Writes down an entry that came in.
local function Take(kind, when, fields, who, via)
    local allowed = FIELDS[kind]
    if not allowed then
        return
    end
    local entry = DecodeFields(fields, allowed)
    entry.t = tonumber(when)
    entry.who = who
    entry.via = via
    -- Fresh news appears on screen through the live feed, which listens
    -- to the chronicle (Modules/Chronicle/LiveFeed.lua).
    Chronicle.Add(kind, entry)
end

local handlers = {}

-- "I am here", to the guild: greet them, they answer with their news. It
-- goes out once per session, after a login or a reload: whoever sends it
-- knows nobody yet, even if they are still linked here.
function handlers.P(key)
    SendHello(key)
end

-- "I have your news up to <time>": send what is newer, the statistics and
-- what we know of others.
function handlers.H(key, since)
    CatchUp(key, tonumber(since) or 0)
    Send(key, EncodeStatistics())
    SendOffers(key)
end

function handlers.E(key, when, kind, fields)
    Take(kind, when, fields, online[key])
end

function handlers.S(key, level, fields, classFile)
    local stats = {}
    for id, value in string.gmatch(fields or "", "(%d+)=(%d+)") do
        stats[tonumber(id)] = tonumber(value)
    end
    Chronicle.Class(online[key], classFile) -- checked there; nil from older versions
    Chronicle.Profile(online[key], { level = tonumber(level) or 0, stats = stats })
end

-- "I have news of <who> up to <time>": ask for it if it is news to us,
-- about someone vouched for who cannot tell it themselves right now.
function handlers.O(key, who, newest)
    if not IsPlainText(who) then
        return
    end
    local whoKey = Key(who)
    local name = Vouched(whoKey)
    if not name or whoKey == OwnKey() or linked[whoKey] or asked[whoKey] then
        return
    end
    local since = Chronicle.NewestFrom(name, true)
    if (tonumber(newest) or 0) > since and Send(key, table.concat({ VERSION, "W", Clean(name), string.format("%d", since) }, "~"), true) then
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
    since = tonumber(since) or 0
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
        return
    end
    Take(kind, when, fields, name, online[key])
end

function sharing:CHAT_MSG_ADDON(_, prefix, text, channel, sender)
    if ns.IsSecret(prefix) or prefix ~= PREFIX or not IsPlainText(text) or not IsPlainText(sender) then
        return
    end
    if ns.IsSecret(channel) then
        return
    end
    local key = Key(sender)
    local version, kind, a, b, c, d = strsplit("~", text)
    if version ~= VERSION or key == OwnKey() then
        return
    end
    -- Only the greeting goes to the guild.
    if channel ~= "WHISPER" and not (channel == "GUILD" and kind == "P") then
        return
    end
    -- A guild member who speaks is online, even if the roster does not say
    -- so yet.
    if guild[key] and not online[key] then
        guildOnline[key] = guild[key]
        online[key] = guild[key]
    end
    if not online[key] then
        return -- neither a friend nor in the guild: ignored
    end
    gone[key] = nil -- whoever speaks is online, whatever the client said before
    local handler = handlers[kind]
    if not handler then
        return
    end
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
        Chronicle.Link(key, online[key])
    end
    handler(key, a, b, c, d)
    if firstContact then
        SendHello(key)
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
            linked[key], gone[key] = nil, nil
            Unask(key)
        end
    end
    local previous = online
    online = now
    for key in pairs(friends) do
        if not previous[key] then
            SendHello(key)
        end
    end
end

function sharing:FRIENDLIST_UPDATE()
    friends = {}
    ns.SocialService.EachFriend(function(info)
        if not ns.IsSecret(info.connected) and info.connected and IsPlainText(info.name) then
            friends[Key(info.name)] = Plain(info.name)
        end
    end)
    Refresh()
end

function sharing:GUILD_ROSTER_UPDATE()
    guild, guildOnline = {}, {}
    ns.SocialService.EachGuildMember(function(name, isOnline, isMobile)
        if name then
            local key = Key(name)
            guild[key] = Plain(name)
            if isOnline and not isMobile then
                guildOnline[key] = guild[key]
            end
        end
    end)
    Refresh()
    -- Greet the guild once its roster is known: the answers come by whisper
    -- and are taken only from members.
    if not greetedGuild and next(guild) then
        greetedGuild = true
        Queue(nil, VERSION .. "~P", "GUILD", true)
    end
end

function sharing:OnEnable()
    if not registered then
        registered = true
        C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
        ns:On("CHRONICLE_CHANGED", OnChronicleChanged)
    end
    self:RegisterEvent("CHAT_MSG_ADDON")
    self:RegisterEvent("FRIENDLIST_UPDATE")
    self:RegisterEvent("GUILD_ROSTER_UPDATE")
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
    friends, guild, guildOnline, online, linked, asked = {}, {}, {}, {}, {}, {}
    gone, helloWaiting = {}, {}
    greetedGuild, statsPending = false, false -- a pending After lapses with the feature
    nowLane, laterLane = NewLane(MAX_NOW), NewLane(MAX_LATER)
end

-- For the tests.
sharing.EncodeEntry = EncodeEntry
sharing.Key = Key
