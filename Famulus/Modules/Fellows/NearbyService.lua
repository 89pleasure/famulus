-- NearbyService: who of the player's friends and guild is in the game right
-- now, where and at what level. One look at the friends list, the
-- Battle.net friends who play this game and the guild roster. Nothing is
-- sent, and nobody needs Famulus for it.
--
--   NearbyService.People(withGuild) -> people, here, level
--       people = { { key, name, full, guid, level, class, zone, from, grouped,
--                    out, bnet }, ... }
--       key: SocialService.Key of the name; name as the lists write it,
--       without the realm, full with it (for a whisper). class the game's
--       file name ("MAGE"), zone and
--       level may be nil. from: how the player knows them, "friend" (the
--       friends list), "battlenet" or "guild". grouped: in the player's
--       group right now. out: why the player cannot play with them, a
--       Battle.net friend in another mode or of the other faction ("Realm
--       PvP", "Horde", both joined by "  ·  "); nil if they can. mode: the
--       other mode ("PvP") if it is that, faction: "Horde" or "Alliance" if
--       it is the faction. bnet: their Battle.net account if they were
--       met on Battle.net first, for the whisper. here, level: the
--       player's own zone and level.
--   NearbyService.Here() -> zone, level
--       The player's own zone and level, without looking at the lists.
--   NearbyService.Bond(person, now) -> tier, progress, seconds, guid or nil
--       If the person is a fellow traveller: the bond's tier, the way to
--       the next one (0..1), the time together and their GUID on the list.
--   NearbyService.Ask()
--       Asks the client for a fresh friends list and guild roster, at most
--       every ASK_GAP seconds. The guild roster only comes when asked for;
--       its zones are as old as the last roster.
--   NearbyService.Quiet(inCities) -> reason or nil
--       Why nobody should be told about anyone right now: "taxi" in flight,
--       "instance" in a dungeon, raid or battleground, "rest" in a city or
--       an inn (unless inCities).
--   NearbyService.Whisper(person)
--       Opens the chat box with a whisper to them; sends nothing. To a
--       Battle.net friend by Battle.net, else to the character.
--
-- A zone is compared by its name. The friends list and the guild roster
-- name it in the player's language; Battle.net in the friend's, so a
-- Battle.net friend who plays in another language matches only where the
-- names are the same. If they are on the friends list or in the guild too,
-- the zone from there counts.
--
-- Friends list and guild hold only characters of the player's realm. A
-- Battle.net friend may play in another of Forever's modes (Normal, PvP, RP,
-- RP-PvP; realms of their own) or the other faction; they are out of reach.
-- The mode is the middle of the game's rich presence ("Forever - PvP -
-- Redridge Mountains"), the player's own from their own game account. The
-- client's realm answers do not tell it: GetRealmID says 0, realmID and the
-- realm's name are empty, and IsGameAccountOnSameRealm and the GUID's server
-- differ even for a guild member in the same mode, whom a whisper by name
-- reaches (in game, 2026-11-27).

local _, ns = ...

local NearbyService = {}
ns.NearbyService = NearbyService

local IsPlainText = ns.ChatService.IsPlainText
local Social = ns.SocialService

local ASK_GAP = 10 -- seconds; the server answers a roster request at most this often

local function Yes(value)
    return not ns.IsSecret(value) and value and true or false
end

local function Level(value)
    if ns.IsSecret(value) or type(value) ~= "number" or value < 1 then
        return nil
    end
    return value
end

local function Plain(value)
    return IsPlainText(value) and value or nil
end

-- The player's own zone and level.
local function Own()
    local zone = GetRealZoneText and Plain(GetRealZoneText()) or nil
    local level = UnitLevel and Level(UnitLevel("player")) or nil
    return zone, level
end
NearbyService.Here = Own

function NearbyService.Bond(person, now)
    local Fellows = ns.FellowService
    local guid = person.guid
    local stored = guid and Fellows.Person(guid)
    if not stored then
        guid = Fellows.Find(person.name)
        stored = guid and Fellows.Person(guid)
    end
    if not stored then
        return nil
    end
    local seconds = Fellows.Seconds(guid, stored, now)
    local tier, progress = Fellows.Tier(seconds)
    return tier, progress, seconds, guid
end

-- The game a Battle.net friend plays on this account: this one, online.
local function PlaysThisGame(game)
    if not Yes(game.isOnline) then
        return false
    end
    local program = game.clientProgram
    if BNET_CLIENT_WOW and not ns.IsSecret(program) and program ~= nil and program ~= BNET_CLIENT_WOW then
        return false
    end
    local project = game.wowProjectID
    if WOW_PROJECT_ID and (ns.IsSecret(project) or project ~= WOW_PROJECT_ID) then
        return false
    end
    return true
end

-- The mode in a rich presence, "Forever - PvP - Redridge Mountains": the
-- second of at least three parts. nil if it is not written that way.
local function Mode(presence)
    if not IsPlainText(presence) then
        return nil
    end
    local parts = {}
    for part in (presence .. " - "):gmatch("(.-) %- ") do
        parts[#parts + 1] = part
    end
    return #parts >= 3 and parts[2] ~= "" and parts[2] or nil
end
NearbyService.Mode = Mode

-- The player's own mode, from their own game account.
local function OwnMode()
    local guid = UnitGUID and UnitGUID("player")
    if not (C_BattleNet and C_BattleNet.GetGameAccountInfoByGUID) or not IsPlainText(guid) then
        return nil
    end
    local ok, game = pcall(C_BattleNet.GetGameAccountInfoByGUID, guid)
    if not ok or ns.IsSecret(game) or type(game) ~= "table" then
        return nil
    end
    return Mode(game.richPresence)
end

-- Why the player cannot group with this character, as the window says it:
-- "Realm PvP", their faction ("Horde"), or both; then the other mode and
-- the faction's token. nil if they can. Without the player's own mode only
-- the faction counts.
local function OutOfReach(game, ownMode)
    local L = ns.L
    local reasons = {}
    local mode = Mode(game.richPresence)
    if not (mode and ownMode and mode ~= ownMode) then
        mode = nil
    end
    if mode then
        reasons[#reasons + 1] = L.ui_near_realm:format(mode)
    end
    local faction = Plain(game.factionName)
    local own = UnitFactionGroup and Plain((UnitFactionGroup("player")))
    if not (faction and own and faction ~= own) then
        faction = nil
    end
    if faction then
        reasons[#reasons + 1] = Plain(_G["FACTION_" .. string.upper(faction)]) or faction
    end
    if #reasons == 0 then
        return nil
    end
    return table.concat(reasons, "  ·  "), mode, faction
end

function NearbyService.People(withGuild)
    local here, level = Own()
    local own = UnitGUID and Plain(UnitGUID("player")) or nil
    -- The full name, as the lists write it: UnitName gives first name and surname apart.
    local ownName = UnitName and ns.AliasService.FullName(UnitName("player"))
    local ownKey = ownName and Social.Key(ownName) or nil

    local people, byKey = {}, {}
    -- Someone met again on another list fills what the first did not tell.
    -- from: what the first list said, unless a later one ranks higher.
    local RANK = { friend = 1, battlenet = 2, guild = 3 }
    local function Note(name, guid, levelNow, class, zone, from, zoneTrusted, out, mode, faction, bnet)
        if not IsPlainText(name) or (guid and guid == own) then
            return
        end
        -- A whisper needs the name as the list wrote it, realm and all.
        local full = name
        name = Social.Plain(name)
        local key = Social.Key(name)
        if key == "" or key == ownKey then
            return
        end
        local person = byKey[key]
        if not person then
            -- Only someone met first on Battle.net can be out of reach: on
            -- the friends list or in the guild they share the player's realm.
            person = { key = key, name = name, full = full, from = from, out = out, mode = mode, faction = faction, bnet = bnet }
            byKey[key] = person
            people[#people + 1] = person
        elseif RANK[from] < RANK[person.from] then
            person.from = from
        end
        person.guid = person.guid or guid
        person.level = person.level or levelNow
        person.class = person.class or class
        -- A zone in the player's language beats one in the friend's.
        if zone and (not person.zone or (zoneTrusted and not person.zoneTrusted)) then
            person.zone, person.zoneTrusted = zone, zoneTrusted
        end
    end

    Social.EachFriend(function(info)
        if Yes(info.connected) then
            Note(info.name, Plain(info.guid), Level(info.level), Social.ClassFromName(info.className), Plain(info.area), "friend", true)
        end
    end)
    if withGuild then
        Social.EachGuildMember(function(name, online, mobile, guid, class, levelNow, zone)
            if name and online and not mobile then
                Note(name, guid, levelNow, class, zone, "guild", true)
            end
        end)
    end
    local ownMode = OwnMode()
    Social.EachBattleNetFriend(function(_, games, account)
        for _, game in ipairs(games) do
            if PlaysThisGame(game) then
                local out, mode, faction = OutOfReach(game, ownMode)
                Note(game.characterName, Plain(game.playerGuid), Level(game.characterLevel), Social.ClassFromName(game.className),
                    Plain(game.areaName), "battlenet", false, out, mode, faction, Plain(account))
            end
        end
    end)

    local grouped = {}
    for _, member in ipairs(ns.GroupService.Members(true)) do
        grouped[Social.Key(member.name)] = true
        if member.guid then
            grouped[member.guid] = true
        end
    end
    for _, person in ipairs(people) do
        person.zoneTrusted = nil
        person.grouped = grouped[person.key] or (person.guid ~= nil and grouped[person.guid]) or nil
    end
    return people, here, level
end

local askedAt

function NearbyService.Ask()
    local now = GetTime()
    if askedAt and now - askedAt < ASK_GAP then
        return
    end
    askedAt = now
    if C_FriendList and C_FriendList.ShowFriends then
        C_FriendList.ShowFriends()
    end
    if IsInGuild and Yes(IsInGuild()) and C_GuildInfo and C_GuildInfo.GuildRoster then
        C_GuildInfo.GuildRoster()
    end
end

function NearbyService.Quiet(inCities)
    if UnitOnTaxi and Yes(UnitOnTaxi("player")) then
        return "taxi"
    end
    if IsInInstance then
        local inside = IsInInstance()
        if Yes(inside) then
            return "instance"
        end
    end
    if not inCities and IsResting and Yes(IsResting()) then
        return "rest"
    end
    return nil
end

-- A Battle.net friend gets a Battle.net whisper, as in Blizzard's friends
-- frame: it reaches them on any realm, even when the client does not say
-- they are on another (the character's name, without a realm, would only
-- look on the player's). Friends list and guild share the player's realm.
function NearbyService.Whisper(person)
    if person.bnet and ChatFrameUtil and ChatFrameUtil.SendBNetTell then
        ChatFrameUtil.SendBNetTell(person.bnet)
        return
    end
    ns.ChatService.Whisper(person.full or person.name)
end
