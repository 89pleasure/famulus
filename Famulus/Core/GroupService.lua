-- GroupService: who is in the player's group right now.
--
-- Names, GUIDs and classes of party and raid members are not secret in the
-- client, not even in combat (the identity rule only hides units outside the
-- group); every value is still checked before it is used. Battlegrounds and
-- arenas do not count: their groups are strangers thrown together.
--
--   GroupService.Members(withRaid) -> { { guid, name, level, class, unit }, ... }
--
-- name is "First Last", class the game's file name of the class ("MAGE"),
-- unit the unit token ("party2") at the moment of asking.
-- Members who are offline, or whose name the client does not know yet, are
-- left out; the next change of the group brings them.

local _, ns = ...

local GroupService = {}
ns.GroupService = GroupService

local IsPlainText = ns.ChatService.IsPlainText

-- True in a battleground or an arena.
local function InPvP()
    if not IsInInstance then
        return false
    end
    local inInstance, instanceType = IsInInstance()
    if ns.IsSecret(inInstance) or not inInstance or not IsPlainText(instanceType) then
        return false
    end
    return instanceType == "pvp" or instanceType == "arena"
end

local function Member(unit, own)
    local guid = UnitGUID(unit)
    if not IsPlainText(guid) or guid == own then
        return nil
    end
    if UnitIsConnected then
        local online = UnitIsConnected(unit)
        if ns.IsSecret(online) or not online then
            return nil
        end
    end
    local name, surname = UnitName(unit)
    if not IsPlainText(name) or name == UNKNOWNOBJECT then
        return nil
    end
    name = ns.SocialService.FullName(name, surname)
    local level = UnitLevel and UnitLevel(unit)
    if ns.IsSecret(level) or type(level) ~= "number" or level < 1 then
        level = nil
    end
    local class
    if UnitClass then
        local _, file = UnitClass(unit)
        class = IsPlainText(file) and file or nil
    end
    return { guid = guid, name = name, level = level, class = class, unit = unit }
end

-- Everyone else in the group, or an empty list outside a group, in PvP, and
-- in a raid unless withRaid is set.
function GroupService.Members(withRaid)
    local members = {}
    local count = GetNumGroupMembers and GetNumGroupMembers() or 0
    if ns.IsSecret(count) or type(count) ~= "number" or count < 2 or InPvP() then
        return members
    end
    local raid = IsInRaid and IsInRaid()
    raid = not ns.IsSecret(raid) and raid and true or false
    if raid and not withRaid then
        return members
    end
    local own = UnitGUID("player")
    local prefix, last = "party", count - 1
    if raid then
        prefix, last = "raid", count
    end
    for i = 1, last do
        local member = Member(prefix .. i, own)
        if member then
            members[#members + 1] = member
        end
    end
    return members
end

-- True while the player is in a raid group.
function GroupService.InRaid()
    local raid = IsInRaid and IsInRaid()
    return not ns.IsSecret(raid) and raid and true or false
end
