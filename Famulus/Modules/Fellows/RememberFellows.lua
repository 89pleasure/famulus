-- Remembers the players the player was in a group with: when and where you
-- met, how often and how long you played together, and how many bosses
-- you defeated together. Works without the others' cooperation: the client
-- tells who is in the group. Nothing is sent to anyone.
--
-- With the option friendsOnly it remembers only friends (Battle.net friends
-- too) and guild members: the people the chronicle hears from, and more.

local _, ns = ...
local Fellows = ns.FellowService

local rememberFellows = ns:NewFeature({
    id = "rememberFellows",
    category = "fellows",
    default = false,
    requires = { "GetNumGroupMembers", "UnitGUID", "UnitName" },
    options = {
        { key = "raids", type = "toggle", default = true },
        { key = "friendsOnly", type = "toggle", default = false },
    },
})

local function Zone()
    local zone = GetRealZoneText and GetRealZoneText()
    if ns.ChatService.IsPlainText(zone) then
        return zone
    end
    return nil
end

function rememberFellows:Scan()
    local friendsOnly = self:Get("friendsOnly")
    local members = {}
    for _, member in ipairs(ns.GroupService.Members(self:Get("raids"))) do
        -- A Battle.net friend's BattleTag is kept either way: tidying up
        -- needs it to know them again while they are offline. Whether
        -- someone is a friend at all is only asked with the option.
        if friendsOnly then
            local known, tag = ns.SocialService.Unit(member.unit, member.guid)
            member.tag = tag
            if known then
                members[#members + 1] = member
            end
        else
            member.tag = ns.SocialService.BattleTag(member.guid)
            members[#members + 1] = member
        end
    end
    Fellows.Sync(members, time(), Zone(), UnitLevel and UnitLevel("player"))
end

-- Only friends: someone who becomes a friend while in the group counts
-- from then on, not only from the next change of the group; the same when
-- the player joins or leaves a guild, gains or loses a Battle.net friend,
-- or Battle.net connects again. All four come rarely (unlike
-- BN_FRIEND_INFO_CHANGED, which every status change of a friend sends).
local FRIEND_EVENTS = { "FRIENDLIST_UPDATE", "PLAYER_GUILD_UPDATE", "BN_FRIEND_LIST_SIZE_CHANGED", "BN_CONNECTED" }

function rememberFellows:ListenToFriends()
    local listen = self:Get("friendsOnly")
    for _, event in ipairs(FRIEND_EVENTS) do
        if listen then
            self:RegisterEvent(event, "Scan")
        else
            self:UnregisterEvent(event)
        end
    end
end

function rememberFellows:OnEnable()
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "Scan")
    -- Entering a battleground ends the stretch; leaving it starts it again.
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Scan")
    self:RegisterEvent("BOSS_KILL")
    self:RegisterEvent("PLAYER_LOGOUT")
    self:ListenToFriends()
    self:Scan()
end

function rememberFellows:OnDisable()
    Fellows.PartAll(time(), Zone())
end

function rememberFellows:OnOptionChanged(key)
    if key == "friendsOnly" then
        self:ListenToFriends()
    end
    if key == "raids" or key == "friendsOnly" then
        self:Scan()
    end
end

function rememberFellows:BOSS_KILL(_, _, name)
    self:Scan()
    Fellows.Boss(name, Zone(), ns.GroupService.InRaid())
end

-- The saved data is written after this event, so the stretches end here.
function rememberFellows:PLAYER_LOGOUT()
    Fellows.PartAll(time(), Zone())
end
