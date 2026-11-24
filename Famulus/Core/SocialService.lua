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
--   SocialService.EachFriend(visit)
--       visit(info) for every entry of the friends list: the client's
--       FriendInfo, whose fields still need checking.
--   SocialService.EachGuildMember(visit)
--       visit(name, online, mobile, guid) for every member of the guild
--       roster; nobody outside a guild. A secret or missing name or GUID
--       comes as nil, online and mobile as true or false.
--   SocialService.EachBattleNetFriend(visit, index)
--       visit(battleTag, games) for every Battle.net friend, or only the one
--       at index. games: the client's game accounts they are online with
--       right now (empty while offline). visit may return true to stop.
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
    return (string.lower((string.gsub(SocialService.Plain(name), "[%s%-]+", "-"))))
end

local Key = SocialService.Key

local function Yes(value)
    if ns.IsSecret(value) then
        return false
    end
    return value and true or false
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

function SocialService.EachGuildMember(visit)
    if not InGuild() then
        return
    end
    for i = 1, Number(GetNumGuildMembers) do
        local name, _, _, _, _, _, _, _, online, _, _, _, _, mobile, _, _, guid = GetGuildRosterInfo(i)
        visit(IsPlainText(name) and name or nil, Yes(online), Yes(mobile), IsPlainText(guid) and guid or nil)
    end
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
            if visit(info.battleTag, games) == true then
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

    if InGuild() and Number(GetNumGuildMembers) < 1 then
        -- In a guild, yet nobody in it: the roster has not come yet.
        waiting = waiting or "guild"
        Wait(waits.guild)
    end
    SocialService.EachGuildMember(function(name, _, _, guid)
        Note(guid, name)
    end)

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
        tags[string.lower(battleTag)] = true
        for _, game in ipairs(games) do
            Note(game.playerGuid)
        end
    end)

    local function Check(guid, name, tag)
        return (IsPlainText(guid) and guids[guid]) or (IsPlainText(name) and keys[Key(name)])
            or (IsPlainText(tag) and tags[string.lower(tag)]) or false
    end
    return function(guid, name, tag)
        return Check(guid, name, tag) and true or false
    end, waiting == nil, waiting
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
        if not IsPlainText(name) then
            return nil
        end
        local key = Key(name)
        if online[key] then
            return online[key]
        end
        -- A list may write "First-Last-Realm", which keeps its realm.
        local prefix = key .. "-"
        for each, value in pairs(online) do
            if string.sub(each, 1, #prefix) == prefix then
                return value
            end
        end
        return nil
    end
end
