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
--   1~S~<level>~id=n;id=n       the sender's level and statistics
--   1~O~<who>~<time>      offer: "I have news of <who> up to <time>"
--   1~W~<who>~<time>      want: "send me what you have of <who> after <time>"
--   1~R~<who>~<time>~<kind>~k=v;k=v   one entry of <who>, passed on
-- A hello is answered with the entries the other side lacks, the statistics
-- and the offers. Whoever answered is "linked" for the session and gets the
-- live entries.
--
-- Passing on: news of someone who is offline comes from a linked companion
-- who has it. It is asked for and taken only about people the player shares
-- a guild with or whose addon answered directly within the last 30 days (an
-- answer comes only from someone who has the player on their friends list or
-- in their guild), so nothing arrives about strangers. Each person is asked
-- of one companion per session, so news does not arrive once per companion.
--
-- The client refuses addon messages during boss fights and on restricted
-- maps and limits how fast they may go out, so everything passes through a
-- queue that a ticker empties; the ticker runs only while something waits.

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
    options = {
        { key = "toast", type = "toggle", default = true },
    },
})

local PREFIX = "Famulus"
local VERSION = "1"
local SEND_INTERVAL = 0.5 -- seconds between two messages
local MAX_QUEUE = 200
local CATCH_UP = 20 -- entries sent to someone who was away
local MAX_OFFERS = 20 -- people whose news is offered on a hello
local LINK_AGE = 30 * 86400 -- how long a direct answer vouches for someone
local LIVE_SECONDS = 120 -- an entry this fresh is announced on screen
local MAX_TEXT = 60 -- bytes of a name or place in a message

-- What may travel, per kind: field -> "n" (number) or "s" (text).
local FIELDS = {
    level = { level = "n", zone = "s" },
    death = { level = "n", zone = "s" },
    boss = { id = "n", name = "s", zone = "s" },
    achievement = { id = "n", name = "s" },
    zone = { level = "n", zone = "s" },
    profession = { skill = "n", name = "s" },
    ability = { ability = "s", name = "s", level = "n" },
    item = { item = "n", name = "s", level = "n", zone = "s" },
    skill = { skill = "n", name = "s", rank = "n" },
}

-- The character's own statistics that are shared, by the game's IDs: deaths,
-- creatures killed, quests completed, dungeons entered.
sharing.STATISTICS = { 60, 107, 98, 932 }

local friends = {} -- key -> name: friends who are online
local guild = {} -- key -> name: guild members, online or not
local guildOnline = {} -- key -> name: guild members who are online
local online = {} -- key -> name: friends and guild members who are online
local linked = {} -- key -> name: whose addon answered this session
local asked = {} -- key of someone offline -> key of the companion asked about them
local queue, queueHead = {}, 1
local registered = false
local greetedGuild = false

-- A name without the realm the client may add: "First Last-Realm" becomes
-- "First Last" (the spellings as Guildy reads them).
local function Plain(name)
    if string.find(name, " ", 1, true) then
        name = string.match(name, "^[^%-]*")
    end
    return (string.gsub(string.gsub(name, "^%s+", ""), "%s+$", ""))
end

-- One spelling for a name however the client writes it.
local function Key(name)
    return (string.lower((string.gsub(Plain(name), "[%s%-]+", "-"))))
end

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

-- The character's own statistics: { [id] = number } for the shared IDs.
local function OwnStatistics()
    local wanted, values = {}, {}
    for _, id in ipairs(sharing.STATISTICS) do
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
    return table.concat({ VERSION, "S", string.format("%d", level), table.concat(parts, ";") }, "~")
end

---------------------------------------------------------------------------
-- Sending
---------------------------------------------------------------------------

local function SendNext()
    if queueHead > #queue then
        queue, queueHead = {}, 1
        sharing:StopTicker()
        return
    end
    -- During a boss fight the client would drop the message; wait it out.
    if ns.ChatService.InLockdown() then
        return
    end
    local item = queue[queueHead]
    queue[queueHead] = false
    queueHead = queueHead + 1
    if item.channel then
        C_ChatInfo.SendAddonMessage(PREFIX, item.text, item.channel)
    -- Someone who went offline in the meantime gets nothing: whispering
    -- into the void would print an error in the player's chat.
    elseif online[item.key] then
        C_ChatInfo.SendAddonMessage(PREFIX, item.text, "WHISPER", online[item.key])
    end
end

-- To someone by key, or with channel to everyone there.
local function Send(key, text, channel)
    if not text or #text > 255 or #queue - queueHead + 1 >= MAX_QUEUE then
        return
    end
    queue[#queue + 1] = { key = key, text = text, channel = channel }
    if not sharing.ticker then
        sharing:StartTicker(SEND_INTERVAL, SendNext)
    end
end

local function SendHello(key)
    Send(key, table.concat({ VERSION, "H", string.format("%d", Chronicle.NewestFrom(online[key])) }, "~"))
end

-- Offers the news of others this client knows, newest first, except of the
-- one who receives the offer.
local function SendOffers(key)
    local entries, offered, count = Chronicle.Entries(), {}, 0
    for i = #entries, 1, -1 do
        local who = entries[i].who
        if who and FIELDS[entries[i].k] and not entries[i].demo then
            local whoKey = Key(who)
            if whoKey ~= key and not offered[whoKey] then
                offered[whoKey] = true
                count = count + 1
                Send(key, table.concat({ VERSION, "O", Clean(who), string.format("%d", entries[i].t) }, "~"))
                if count == MAX_OFFERS then
                    return
                end
            end
        end
    end
end

-- A fresh entry of the player's own goes to every linked companion.
local function OnChronicleChanged(entry)
    if not sharing.enabled or not entry or entry.demo or entry.who or entry.c ~= Chronicle.Character() then
        return
    end
    local text = EncodeEntry(entry)
    for key in pairs(linked) do
        Send(key, text)
    end
end

---------------------------------------------------------------------------
-- Receiving
---------------------------------------------------------------------------

local function Announce(entry)
    if not sharing:Get("toast") or not ns.UI or not ns.UI.Toast then
        return
    end
    local title, detail = Chronicle.Text(entry)
    ns.UI.Toast(title, detail)
end

-- Writes down an entry that came in; fresh news shows on screen.
local function Take(kind, when, fields, who, via)
    local allowed = FIELDS[kind]
    if not allowed then
        return
    end
    local entry = DecodeFields(fields, allowed)
    entry.t = tonumber(when)
    entry.who = who
    entry.via = via
    if Chronicle.Add(kind, entry) and time() - entry.t <= LIVE_SECONDS then
        Announce(entry)
    end
end

local handlers = {}

-- "I am here", to the guild: greet them, they answer with their news.
function handlers.P(key)
    if not linked[key] then
        SendHello(key)
    end
end

-- "I have your news up to <time>": send what is newer, the statistics and
-- what we know of others.
function handlers.H(key, since)
    since = tonumber(since) or 0
    for _, entry in ipairs(Chronicle.OwnSince(since, CATCH_UP)) do
        Send(key, EncodeEntry(entry))
    end
    Send(key, EncodeStatistics())
    SendOffers(key)
end

function handlers.E(key, when, kind, fields)
    Take(kind, when, fields, online[key])
end

function handlers.S(key, level, fields)
    local stats = {}
    for id, value in string.gmatch(fields or "", "(%d+)=(%d+)") do
        stats[tonumber(id)] = tonumber(value)
    end
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
    if (tonumber(newest) or 0) > since then
        asked[whoKey] = key
        Send(key, table.concat({ VERSION, "W", Clean(name), string.format("%d", since) }, "~"))
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
        SendHello(key) -- after the handler: it knows what just arrived
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
    for key in pairs(online) do
        if not now[key] then
            linked[key] = nil
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
    for i = 1, C_FriendList.GetNumFriends() or 0 do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.connected and IsPlainText(info.name) then
            friends[Key(info.name)] = Plain(info.name)
        end
    end
    Refresh()
end

function sharing:GUILD_ROSTER_UPDATE()
    guild, guildOnline = {}, {}
    if IsInGuild and IsInGuild() and GetNumGuildMembers and GetGuildRosterInfo then
        for i = 1, GetNumGuildMembers() or 0 do
            local name, _, _, _, _, _, _, _, isOnline, _, _, _, _, isMobile = GetGuildRosterInfo(i)
            if IsPlainText(name) then
                local key = Key(name)
                guild[key] = Plain(name)
                if not ns.IsSecret(isOnline) and not ns.IsSecret(isMobile) and isOnline and not isMobile then
                    guildOnline[key] = guild[key]
                end
            end
        end
    end
    Refresh()
    -- Greet the guild once its roster is known: the answers come by whisper
    -- and are taken only from members.
    if not greetedGuild and next(guild) then
        greetedGuild = true
        Send(nil, VERSION .. "~P", "GUILD")
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
    greetedGuild = false
    queue, queueHead = {}, 1
end

-- For the tests.
sharing.EncodeEntry = EncodeEntry
sharing.Key = Key
