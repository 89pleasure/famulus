-- SocialService: the people the player knows. "In the circle" is whoever is
-- on the friends list (Battle.net friends too) or in the player's guild.
--
--   SocialService.Unit(unit, guid) -> known, battleTag
--       Someone in the group, from the client's own checks; cheap enough
--       for every roster update. battleTag: if they are a Battle.net friend.
--   SocialService.Circle() -> check, ready
--       One look at the friends list, the guild roster and the Battle.net
--       friends. check(guid, name, battleTag) is true for someone in the
--       circle, also while they are offline. ready is false while the
--       player is in a guild whose roster has not arrived yet: the roster is
--       asked for, and SOCIAL_CHANGED follows once it is there.
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

local ROSTER_WAIT = 15 -- seconds before the guild roster is asked for again

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

-- The BattleTag of the Battle.net friend who plays the character with this
-- GUID right now, or nil.
local function BattleTagOf(guid)
    if not (C_BattleNet and C_BattleNet.GetAccountInfoByGUID) then
        return nil
    end
    local ok, info = pcall(C_BattleNet.GetAccountInfoByGUID, guid)
    if not ok or ns.IsSecret(info) or type(info) ~= "table" or not IsPlainText(info.battleTag) then
        return nil
    end
    -- Not every account the client knows of is a friend.
    local friend, tagFriend = info.isFriend, info.isBattleTagFriend
    if not ns.IsSecret(friend) and not ns.IsSecret(tagFriend) and friend == false and tagFriend == false then
        return nil
    end
    return info.battleTag
end

function SocialService.Unit(unit, guid)
    if not IsPlainText(guid) then
        return false, nil
    end
    local tag = BattleTagOf(guid)
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

-- The guild roster, asked for at most every ROSTER_WAIT seconds; the
-- event is heard once, and SOCIAL_CHANGED says the roster came.
local askedAt

local function RosterArrived()
    ns:UnregisterEvent("GUILD_ROSTER_UPDATE", SocialService)
    ns:Fire("SOCIAL_CHANGED")
end

local function AskForRoster()
    if not (C_GuildInfo and C_GuildInfo.GuildRoster) then
        return
    end
    local now = GetTime()
    if askedAt and now - askedAt < ROSTER_WAIT then
        return
    end
    askedAt = now
    ns:RegisterEvent("GUILD_ROSTER_UPDATE", SocialService, RosterArrived)
    C_GuildInfo.GuildRoster()
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

    if C_FriendList and C_FriendList.GetFriendInfoByIndex then
        for i = 1, Number(C_FriendList.GetNumFriends) do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if not ns.IsSecret(info) and type(info) == "table" then
                Note(info.guid, info.name)
            end
        end
    end

    local ready = true
    if IsInGuild and Yes(IsInGuild()) and GetGuildRosterInfo then
        local count = Number(GetNumGuildMembers)
        if count < 1 then
            -- In a guild, yet nobody in it: the roster has not come yet.
            ready = false
            AskForRoster()
        end
        for i = 1, count do
            local name, _, _, _, _, _, _, _, _, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
            Note(guid, name)
        end
    end

    -- Battle.net friends by BattleTag, online or not; and the characters
    -- they play right now.
    if C_BattleNet and C_BattleNet.GetFriendAccountInfo then
        for i = 1, Number(BNGetNumFriends) do
            local info = C_BattleNet.GetFriendAccountInfo(i)
            if not ns.IsSecret(info) and type(info) == "table" then
                if IsPlainText(info.battleTag) then
                    tags[string.lower(info.battleTag)] = true
                end
                local games = C_BattleNet.GetFriendNumGameAccounts and Number(C_BattleNet.GetFriendNumGameAccounts, i) or 0
                if games > 0 and C_BattleNet.GetFriendGameAccountInfo then
                    for g = 1, games do
                        local game = C_BattleNet.GetFriendGameAccountInfo(i, g)
                        if not ns.IsSecret(game) and type(game) == "table" then
                            Note(game.playerGuid)
                        end
                    end
                elseif not ns.IsSecret(info.gameAccountInfo) and type(info.gameAccountInfo) == "table" then
                    Note(info.gameAccountInfo.playerGuid)
                end
            end
        end
    end

    local function Check(guid, name, tag)
        return (IsPlainText(guid) and guids[guid]) or (IsPlainText(name) and keys[Key(name)])
            or (IsPlainText(tag) and tags[string.lower(tag)]) or false
    end
    return function(guid, name, tag)
        return Check(guid, name, tag) and true or false
    end, ready
end
