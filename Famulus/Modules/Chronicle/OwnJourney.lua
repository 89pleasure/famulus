-- Writes the milestones of the player's own character into the chronicle:
-- levels, deaths, bosses, Legacy challenges and zones seen for the first
-- time since the chronicle began.

local _, ns = ...
local Chronicle = ns.ChronicleService

local journey = ns:NewFeature({
    id = "ownJourney",
    category = "chronicle",
    default = false,
    requires = { "GetRealZoneText", "UnitLevel" },
})

local DEATH_PAUSE = 5 -- seconds; the client may report one death twice
local lastDeath = 0

local function Zone()
    local zone = GetRealZoneText()
    if ns.ChatService.IsPlainText(zone) then
        return zone
    end
    return nil
end

function journey:OnEnable()
    -- Where the character stands now is no arrival.
    Chronicle.SeeZone(Zone())
    self:RegisterEvent("PLAYER_LEVEL_UP")
    self:RegisterEvent("PLAYER_DEAD")
    self:RegisterEvent("BOSS_KILL")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    if GetAchievementInfo then
        self:RegisterEvent("ACHIEVEMENT_EARNED")
    end
end

function journey:PLAYER_LEVEL_UP(_, level)
    Chronicle.Add("level", { level = level, zone = Zone() })
end

function journey:PLAYER_DEAD()
    local now = GetTime()
    if now - lastDeath < DEATH_PAUSE then
        return
    end
    lastDeath = now
    Chronicle.Add("death", { zone = Zone(), level = UnitLevel("player") })
end

function journey:BOSS_KILL(_, encounterID, name)
    Chronicle.Add("boss", { id = encounterID, name = name, zone = Zone() })
end

-- The Forever client shows achievements as "Legacy challenges".
function journey:ACHIEVEMENT_EARNED(_, achievementID, alreadyEarned)
    if alreadyEarned then
        return
    end
    local _, name = GetAchievementInfo(achievementID)
    Chronicle.Add("achievement", { id = achievementID, name = name })
end

function journey:ZONE_CHANGED_NEW_AREA()
    local zone = Zone()
    if zone and Chronicle.SeeZone(zone) then
        Chronicle.Add("zone", { zone = zone, level = UnitLevel("player") })
    end
end
