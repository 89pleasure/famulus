-- SocialService: the people the player knows. "In the circle" is whoever is
-- on the friends list (Battle.net friends too) or in the player's guild.
-- Whatever reads the friends list, the guild roster or the Battle.net
-- friends does it through here.
--
--   SocialService.Unit(unit, guid) -> known, battleTag
--       Someone in the group, from the client's own checks; cheap enough
--       for every roster update. battleTag: if they are a Battle.net friend.
--   SocialService.BattleTag(guid) -> battleTag or nil
--       Only that part of Unit: the BattleTag of the Battle.net friend who
--       plays this character right now.
--   SocialService.Circle() -> check, ready, waiting
--       One look at the friends list, the guild roster and the Battle.net
--       friends. check(guid, name, battleTag) is true for someone in the
--       circle, also while they are offline. ready is false while one of
--       the lists cannot be trusted yet, and waiting says which: "friends"
--       (the friends list has not come since the login), "guild" (in a
--       guild whose roster has not come) or "battlenet" (Battle.net is not
--       connected, so the client knows no Battle.net friends). The list is
--       asked for, and SOCIAL_CHANGED follows once it is there. Whoever
--       removes people by check must not do so while ready is false: an
--       empty list would make everyone on it a stranger.
--   SocialService.Online() -> find
--       One look at who is online on the friends list and in the guild.
--       find(name) is their GUID (true if no list gives one) while they are
--       online, else nil.
--   SocialService.Classes() -> find
--       One look at the classes the lists tell: of every guild member,
--       online or not, and of friends who are online. find(name) is the
--       class as the game names it in code ("MAGE"), or nil.
--   SocialService.ClassFromName(name) -> "MAGE" or nil
--       A class from its name in the client's language ("Magierin"), as
--       the friends list gives it.
--   SocialService.EachFriend(visit)
--       visit(info) for every entry of the friends list: the client's
--       FriendInfo, whose fields still need checking.
--   SocialService.EachGuildMember(visit) -> keeping
--       visit(name, online, mobile, guid, class, level, zone) for every
--       member of the guild roster; nobody outside a guild. A secret or
--       missing name, GUID, class, level or zone comes as nil, online and
--       mobile as true or false. The zone is where they were when the
--       roster came; the client sends a new roster only when asked
--       (C_GuildInfo.GuildRoster). If the client's roster is empty or names
--       nobody while the player is in a guild, the last one that named
--       anyone this session stands in for it, and keeping is true.
--   SocialService.EachBattleNetFriend(visit, index)
--       visit(battleTag, games, accountName) for every Battle.net friend, or
--       only the one at index. games: the client's game accounts they are
--       online with right now (empty while offline). accountName: what a
--       Battle.net whisper needs. visit may return true to stop.
--   SocialService.Ignored(name) -> true or false
--       Whether the character of that name is on the player's ignore list.
--   SocialService.Plain(name), SocialService.Key(name)
--       A name as lists write it ("First Last-Realm") without the realm, and
--       one spelling for it however the client writes it.
--
-- The client tells which character a Battle.net friend plays only while
-- they are online. Whoever wants to know a Battle.net friend again later
-- keeps their BattleTag (the fellow travellers do).

local _, ns = ...

local SocialService = {}
ns.SocialService = SocialService

local IsPlainText = ns.ChatService.IsPlainText

local ASK_WAIT = 15 -- seconds before a list is asked for again

-- "First Last-Realm" becomes "First Last" (the spellings as Guildy reads them).
function SocialService.Plain(name)
    if string.find(name, " ", 1, true) then
        name = string.match(name, "^[^%-]*")
    end
    return (string.gsub(string.gsub(name, "^%s+", ""), "%s+$", ""))
end

function SocialService.Key(name)
    return ns.Lower((string.gsub(SocialService.Plain(name), "[%s%-]+", "-")))
end

local Key = SocialService.Key

local function Yes(value)
    if ns.IsSecret(value) then
        return false
    end
    return value and true or false
end

-- The game's name of a class in code ("MAGE"), or nil for anything else.
local function ClassFile(value)
    if ns.IsSecret(value) or type(value) ~= "string" or #value > 20 or not string.match(value, "^%u+$") then
        return nil
    end
    return value
end

function SocialService.ClassFromName(name)
    if not IsPlainText(name) then
        return nil
    end
    for _, names in ipairs({ LOCALIZED_CLASS_NAMES_MALE or {}, LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
        for classFile, each in pairs(names) do
            if each == name then
                return ClassFile(classFile)
            end
        end
    end
    return nil
end

-- The first value of fn(...) as a number, or 0.
local function Number(fn, ...)
    if not fn then
        return 0
    end
    local value = fn(...)
    if ns.IsSecret(value) or type(value) ~= "number" then
        return 0
    end
    return value
end

---------------------------------------------------------------------------
-- The lists
---------------------------------------------------------------------------

function SocialService.EachFriend(visit)
    if not (C_FriendList and C_FriendList.GetFriendInfoByIndex) then
        return
    end
    for i = 1, Number(C_FriendList.GetNumFriends) do
        local info = C_FriendList.GetFriendInfoByIndex(i)
        if not ns.IsSecret(info) and type(info) == "table" then
            visit(info)
        end
    end
end

local function InGuild()
    return IsInGuild and Yes(IsInGuild()) and GetGuildRosterInfo ~= nil
end

-- The client may hand over an empty guild roster for a moment while the player is in a guild
-- (Guildy saw it in Forever); a guild always has at least the player, so such a roster is never
-- true. Then the last roster that named anyone stands in for it, until a full one comes again
-- or the player is no longer in a guild. Two tables of columns, filled in place and swapped, so
-- reading the roster leaves no garbage.
local function NewRoster()
    return { n = 0, named = false, names = {}, online = {}, mobile = {}, guids = {}, classes = {}, levels = {}, zones = {} }
end
local kept, incoming = NewRoster(), NewRoster()

function SocialService.EachGuildMember(visit)
    if not InGuild() then
        kept.n, kept.named = 0, false
        return false
    end
    local n, named = Number(GetNumGuildMembers), false
    for i = 1, n do
        local name, _, _, level, _, zone, _, _, online, _, class, _, _, mobile, _, _, guid = GetGuildRosterInfo(i)
        if ns.IsSecret(level) or type(level) ~= "number" or level < 1 then
            level = nil
        end
        name = IsPlainText(name) and name or nil
        named = named or name ~= nil
        incoming.names[i], incoming.online[i], incoming.mobile[i] = name, Yes(online), Yes(mobile)
        incoming.guids[i], incoming.classes[i] = IsPlainText(guid) and guid or nil, ClassFile(class)
        incoming.levels[i], incoming.zones[i] = level, IsPlainText(zone) and zone or nil
    end
    incoming.n, incoming.named = n, named
    -- An empty roster, or one that names nobody, keeps the last one that did.
    local keeping = not named and kept.named
    if not keeping then
        kept, incoming = incoming, kept
    end
    local roster = kept -- a visit that reads the roster again swaps the tables
    for i = 1, roster.n do
        visit(roster.names[i], roster.online[i], roster.mobile[i], roster.guids[i], roster.classes[i], roster.levels[i],
            roster.zones[i])
    end
    return keeping
end

function SocialService.EachBattleNetFriend(visit, index)
    if not (C_BattleNet and C_BattleNet.GetFriendAccountInfo) then
        return
    end
    local first, last = index, index
    if not index then
        first, last = 1, Number(BNGetNumFriends)
    end
    for i = first, last do
        local info = C_BattleNet.GetFriendAccountInfo(i)
        if not ns.IsSecret(info) and type(info) == "table" and IsPlainText(info.battleTag) then
            local games = {}
            local function Add(game)
                if not ns.IsSecret(game) and type(game) == "table" then
                    games[#games + 1] = game
                end
            end
            Add(info.gameAccountInfo)
            -- A friend can be online on several licences at once.
            if C_BattleNet.GetFriendGameAccountInfo then
                for g = 1, Number(C_BattleNet.GetFriendNumGameAccounts, i) do
                    Add(C_BattleNet.GetFriendGameAccountInfo(i, g))
                end
            end
            if visit(info.battleTag, games, info.accountName) == true then
                return
            end
        end
    end
end

---------------------------------------------------------------------------
-- Someone in the group
---------------------------------------------------------------------------

function SocialService.BattleTag(guid)
    if not IsPlainText(guid) or not (C_BattleNet and C_BattleNet.GetAccountInfoByGUID) then
        return nil
    end
    local ok, info = pcall(C_BattleNet.GetAccountInfoByGUID, guid)
    if not ok or ns.IsSecret(info) or type(info) ~= "table" or not IsPlainText(info.battleTag) then
        return nil
    end
    -- Not every account the client knows of is a friend; what it does not
    -- plainly call one is not.
    if not (Yes(info.isFriend) or Yes(info.isBattleTagFriend)) then
        return nil
    end
    return info.battleTag
end

function SocialService.Unit(unit, guid)
    if not IsPlainText(guid) then
        return false, nil
    end
    local tag = SocialService.BattleTag(guid)
    if tag then
        return true, tag
    end
    -- The client wants its friends list loaded for this; right after the
    -- login it may not be yet.
    if C_FriendList and C_FriendList.IsFriend then
        local ok, friend = pcall(C_FriendList.IsFriend, guid)
        if ok and Yes(friend) then
            return true, nil
        end
    end
    if UnitIsInMyGuild and IsPlainText(unit) and Yes(UnitIsInMyGuild(unit)) then
        return true, nil
    end
    return false, nil
end

function SocialService.Ignored(name)
    if not IsPlainText(name) or not (C_FriendList and C_FriendList.IsIgnored) then
        return false
    end
    local ok, ignored = pcall(C_FriendList.IsIgnored, name)
    return ok and Yes(ignored)
end

---------------------------------------------------------------------------
-- Everyone at one look
---------------------------------------------------------------------------

-- What Circle may wait for. While it waits, the event is heard until it
-- comes (then SOCIAL_CHANGED), and the list is asked for at most every
-- ASK_WAIT seconds. seen: the event came at least once this session.
local waits = {
    friends = {
        event = "FRIENDLIST_UPDATE",
        ask = function()
            if C_FriendList and C_FriendList.ShowFriends then
                C_FriendList.ShowFriends()
            end
        end,
    },
    guild = {
        event = "GUILD_ROSTER_UPDATE",
        ask = function()
            if C_GuildInfo and C_GuildInfo.GuildRoster then
                C_GuildInfo.GuildRoster()
            end
        end,
    },
    -- Nothing to ask for: the client connects again by itself.
    battlenet = { event = "BN_CONNECTED" },
}

local function Arrived(wait)
    ns:UnregisterEvent(wait.event, wait)
    wait.listening, wait.seen = false, true
    ns:Fire("SOCIAL_CHANGED")
end

local function Wait(wait)
    if not wait.listening then
        wait.listening = true
        ns:RegisterEvent(wait.event, wait, Arrived)
    end
    local now = GetTime()
    if wait.ask and (not wait.askedAt or now - wait.askedAt >= ASK_WAIT) then
        wait.askedAt = now
        wait.ask()
    end
end

function SocialService.Circle()
    local guids, keys, tags = {}, {}, {}
    local function Note(guid, name)
        if IsPlainText(guid) then
            guids[guid] = true
        end
        if IsPlainText(name) then
            keys[Key(name)] = true
        end
    end

    local waiting
    if C_FriendList and C_FriendList.GetFriendInfoByIndex then
        if Number(C_FriendList.GetNumFriends) > 0 then
            waits.friends.seen = true
        elseif not waits.friends.seen then
            -- Right after the login the list may not be there yet; an
            -- empty one is only trusted once the client has sent it.
            waiting = "friends"
            Wait(waits.friends)
        end
        SocialService.EachFriend(function(info)
            Note(info.guid, info.name)
        end)
    end

    local keeping = SocialService.EachGuildMember(function(name, _, _, guid)
        Note(guid, name)
    end)
    if InGuild() and Number(GetNumGuildMembers) < 1 and not keeping then
        -- In a guild, yet nobody in it and no roster from before: it has not come yet.
        waiting = waiting or "guild"
        Wait(waits.guild)
    end

    -- Without Battle.net the client lists no Battle.net friends at all.
    if BNConnected then
        local connected = BNConnected()
        if not ns.IsSecret(connected) and not connected then
            waiting = waiting or "battlenet"
            Wait(waits.battlenet)
        end
    end

    -- Battle.net friends by BattleTag, online or not; and the characters
    -- they play right now.
    SocialService.EachBattleNetFriend(function(battleTag, games)
        tags[ns.Lower(battleTag)] = true
        for _, game in ipairs(games) do
            Note(game.playerGuid)
        end
    end)

    local function Check(guid, name, tag)
        return (IsPlainText(guid) and guids[guid]) or (IsPlainText(name) and keys[Key(name)])
            or (IsPlainText(tag) and tags[ns.Lower(tag)]) or false
    end
    return function(guid, name, tag)
        return Check(guid, name, tag) and true or false
    end, waiting == nil, waiting
end

-- What a map of name keys holds for a name, or nil. A list may write
-- "First-Last-Realm", which keeps its realm.
local function Find(map, name)
    if not IsPlainText(name) then
        return nil
    end
    local key = Key(name)
    if map[key] then
        return map[key]
    end
    local prefix = key .. "-"
    for each, value in pairs(map) do
        if string.sub(each, 1, #prefix) == prefix then
            return value
        end
    end
    return nil
end

function SocialService.Online()
    local online = {} -- key -> GUID, or true if no list gives one
    local function Note(name, guid)
        local key = Key(name)
        if type(online[key]) ~= "string" then
            online[key] = guid or true
        end
    end
    -- The friends list first: its GUID wins.
    SocialService.EachFriend(function(info)
        if Yes(info.connected) and IsPlainText(info.name) then
            Note(info.name, IsPlainText(info.guid) and info.guid or nil)
        end
    end)
    SocialService.EachGuildMember(function(name, isOnline, _, guid)
        if name and isOnline then
            Note(name, guid)
        end
    end)
    return function(name)
        return Find(online, name)
    end
end

function SocialService.Classes()
    local classes = {} -- key -> class
    SocialService.EachFriend(function(info)
        if Yes(info.connected) and IsPlainText(info.name) then
            classes[Key(info.name)] = SocialService.ClassFromName(info.className)
        end
    end)
    -- The roster tells members who are offline as well, and in code form.
    SocialService.EachGuildMember(function(name, _, _, _, class)
        if name and class then
            classes[Key(name)] = class
        end
    end)
    return function(name)
        return Find(classes, name)
    end
end
