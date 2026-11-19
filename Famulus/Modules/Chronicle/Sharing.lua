-- Shares the chronicle with friends who use the addon as well, wherever
-- they are: milestones as they happen, what a friend missed while offline,
-- and a handful of the character's own statistics.
--
-- Transport: addon messages whispered to friends who are online. A friend
-- without the addon never sees them. Nothing goes to anyone who is not on
-- the friends list, and nothing is accepted from anyone who is not on it.
--
-- Messages (fields separated by "~", at most 255 bytes):
--   1~H~<time>            hello: "I have your news up to <time>"
--   1~E~<time>~<kind>~k=v;k=v   one chronicle entry of the sender
--   1~S~<level>~id=n;id=n       the sender's level and statistics
-- A hello is answered with the entries the friend lacks and the statistics.
-- Whoever answered is "linked" for the session and gets the live entries.
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
local CATCH_UP = 20 -- entries sent to a friend who was away
local LIVE_SECONDS = 120 -- an entry this fresh is announced on screen
local MAX_TEXT = 60 -- bytes of a name or place in a message

-- What may travel, per kind: field -> "n" (number) or "s" (text).
local FIELDS = {
    level = { level = "n", zone = "s" },
    death = { level = "n", zone = "s" },
    boss = { id = "n", name = "s", zone = "s" },
    achievement = { id = "n", name = "s" },
    zone = { level = "n", zone = "s" },
}

-- The character's own statistics that are shared, by the game's IDs: deaths,
-- creatures killed, quests completed, dungeons entered.
sharing.STATISTICS = { 60, 107, 98, 932 }

local online = {} -- key -> name: friends who are online
local linked = {} -- key -> name: friends whose addon answered this session
local queue, queueHead = {}, 1
local registered = false

-- One spelling for a name however the client writes it.
local function Key(name)
    return (string.lower((string.gsub(name, "[%s%-]+", "-"))))
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

local function EncodeEntry(entry)
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
    return table.concat({ VERSION, "E", string.format("%d", entry.t), entry.k, table.concat(parts, ";") }, "~")
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
    -- A friend who went offline in the meantime gets nothing: whispering
    -- into the void would print an error in the player's chat.
    if online[item.key] then
        C_ChatInfo.SendAddonMessage(PREFIX, item.text, "WHISPER", online[item.key])
    end
end

local function Send(key, text)
    if not text or #text > 255 or #queue - queueHead + 1 >= MAX_QUEUE then
        return
    end
    queue[#queue + 1] = { key = key, text = text }
    if not sharing.ticker then
        sharing:StartTicker(SEND_INTERVAL, SendNext)
    end
end

local function SendHello(key)
    Send(key, table.concat({ VERSION, "H", string.format("%d", Chronicle.NewestFrom(online[key])) }, "~"))
end

-- A fresh entry of the player's own goes to every linked friend.
local function OnChronicleChanged(entry)
    if not sharing.enabled or not entry or entry.who or entry.c ~= Chronicle.Character() then
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

local handlers = {}

-- "I have your news up to <time>": send what is newer, and the statistics.
function handlers.H(key, since)
    since = tonumber(since) or 0
    for _, entry in ipairs(Chronicle.OwnSince(since, CATCH_UP)) do
        Send(key, EncodeEntry(entry))
    end
    Send(key, EncodeStatistics())
end

function handlers.E(key, when, kind, fields)
    local allowed = FIELDS[kind]
    if not allowed then
        return
    end
    local entry = DecodeFields(fields, allowed)
    entry.t = tonumber(when)
    entry.who = online[key]
    if Chronicle.Add(kind, entry) and time() - entry.t <= LIVE_SECONDS then
        Announce(entry)
    end
end

function handlers.S(key, level, fields)
    local stats = {}
    for id, value in string.gmatch(fields or "", "(%d+)=(%d+)") do
        stats[tonumber(id)] = tonumber(value)
    end
    Chronicle.Profile(online[key], { level = tonumber(level) or 0, stats = stats })
end

function sharing:CHAT_MSG_ADDON(_, prefix, text, channel, sender)
    if ns.IsSecret(prefix) or prefix ~= PREFIX or not IsPlainText(text) or not IsPlainText(sender) then
        return
    end
    if ns.IsSecret(channel) or channel ~= "WHISPER" then
        return
    end
    local key = Key(sender)
    if not online[key] then
        return -- not a friend, or not seen online: ignored
    end
    local version, kind, a, b, c = strsplit("~", text)
    local handler = version == VERSION and handlers[kind]
    if not handler then
        return
    end
    -- Whoever speaks the protocol is linked. A first contact is greeted
    -- back, so that we get their news as well; they are linked by then and
    -- do not greet again.
    local firstContact = not linked[key]
    linked[key] = online[key]
    handler(key, a, b, c)
    if firstContact then
        SendHello(key) -- after the handler: it knows what just arrived
    end
end

---------------------------------------------------------------------------
-- Friends
---------------------------------------------------------------------------

function sharing:FRIENDLIST_UPDATE()
    local now = {}
    for i = 1, C_FriendList.GetNumFriends() or 0 do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if info and info.connected and IsPlainText(info.name) then
            now[Key(info.name)] = info.name
        end
    end
    for key in pairs(online) do
        if not now[key] then
            linked[key] = nil
        end
    end
    local previous = online
    online = now
    -- Greet whoever came online; their answer shows whether they take part.
    for key in pairs(now) do
        if not previous[key] then
            SendHello(key)
        end
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
    if C_FriendList.ShowFriends then
        C_FriendList.ShowFriends()
    end
    self:FRIENDLIST_UPDATE()
end

function sharing:OnDisable()
    online, linked = {}, {}
    queue, queueHead = {}, 1
end

-- For the tests.
sharing.EncodeEntry = EncodeEntry
sharing.Key = Key
