-- Remembers the players the player was in a group with: when and where you
-- met, how often and how long you played together, and how many bosses
-- you defeated together. Works without the others' cooperation: the client
-- tells who is in the group. Nothing is sent to anyone.

local _, ns = ...
local Fellows = ns.FellowService

local rememberFellows = ns:NewFeature({
    id = "rememberFellows",
    category = "fellows",
    default = false,
    requires = { "GetNumGroupMembers", "UnitGUID", "UnitName" },
    options = {
        { key = "raids", type = "toggle", default = true },
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
    Fellows.Sync(ns.GroupService.Members(self:Get("raids")), time(), Zone(), UnitLevel and UnitLevel("player"))
end

function rememberFellows:OnEnable()
    self:RegisterEvent("GROUP_ROSTER_UPDATE", "Scan")
    -- Entering a battleground ends the stretch; leaving it starts it again.
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "Scan")
    self:RegisterEvent("BOSS_KILL")
    self:RegisterEvent("PLAYER_LOGOUT")
    self:Scan()
end

function rememberFellows:OnDisable()
    Fellows.PartAll(time(), Zone())
end

function rememberFellows:OnOptionChanged(key)
    if key == "raids" then
        self:Scan()
    end
end

function rememberFellows:BOSS_KILL()
    self:Scan()
    Fellows.Boss()
end

-- The saved data is written after this event, so the stretches end here.
function rememberFellows:PLAYER_LOGOUT()
    Fellows.PartAll(time(), Zone())
end
