-- Writes the milestones of the player's own character into the chronicle:
-- levels, deaths, bosses, Legacy challenges, professions, abilities such as
-- riding, special items, zones discovered and the first time in a dungeon or
-- a raid.

local _, ns = ...
local Chronicle = ns.ChronicleService

local journey = ns:NewFeature({
    id = "ownJourney",
    category = "chronicle",
    icon = "flag", -- its entry in the settings (UI.media)
    preview = "book", -- its picture there (UI/Previews.lua)
    default = true,
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

-- Marks the zones this character has explored before as seen, so that only
-- a zone discovered from now on is an arrival. Reads the world map: every
-- zone below the topmost map that has an uncovered part. Returns false if
-- the map could not be read (inside an instance, say); then it is tried
-- again at the next change of zone.
local LANDING = 1 -- seconds after a flight until the character counts as arrived
local explored = false

local function KnowExplored()
    local map, exploration = C_Map, C_MapExplorationInfo
    if not (map and map.GetBestMapForUnit and map.GetMapInfo and map.GetMapChildrenInfo
        and exploration and exploration.GetExploredMapTextures) then
        return true -- this client cannot tell; nothing to wait for
    end
    local id, root = map.GetBestMapForUnit("player"), nil
    for _ = 1, 8 do
        local info = id and map.GetMapInfo(id)
        if not info then
            break
        end
        root, id = info.mapID or id, info.parentMapID
        if not id or id == 0 then
            break
        end
    end
    local zoneType = Enum and Enum.UIMapType and Enum.UIMapType.Zone
    local zones = root and map.GetMapChildrenInfo(root, zoneType, true)
    if type(zones) ~= "table" or #zones == 0 then
        return false
    end
    for _, info in ipairs(zones) do
        local textures = exploration.GetExploredMapTextures(info.mapID)
        if type(textures) == "table" and #textures > 0 then
            Chronicle.SeeZone(info.name)
        end
    end
    return true
end

-- Professions: learning one is an event, and so is every SKILL_STEP points
-- of skill. A profession that turns up with more than a beginner's skill
-- was there before the chronicle began and is only taken note of.
local SKILL_STEP = 75

function journey:SKILL_LINES_CHANGED()
    self:CheckAbilities() -- some are known by a skill line
    for _, profession in ipairs(Chronicle.Professions()) do
        local rank, skillLine = profession.rank, profession.skill
        local before = Chronicle.SeeSkill(skillLine, rank)
        -- The profession's icon goes into the entry, for its picture.
        if (not before or rank < before) and rank < SKILL_STEP then
            -- New, or given up and begun again.
            if self.skillsKnown then
                Chronicle.Add("profession", { skill = skillLine, name = profession.name, icon = profession.icon })
            end
        elseif before and math.floor(rank / SKILL_STEP) > math.floor(before / SKILL_STEP) then
            Chronicle.Add("skill", {
                skill = skillLine,
                name = profession.name,
                icon = profession.icon,
                rank = math.floor(rank / SKILL_STEP) * SKILL_STEP,
            })
        end
    end
end

-- Abilities (ChronicleService.abilities): learning one is an event. What
-- the character can do when the chronicle begins is only taken note of.
-- Knows returns the spell it found the ability by (or true by its skill).
local function Knows(ability)
    if IsPlayerSpell then
        if IsPlayerSpell(ability.spell) then
            return ability.spell
        end
        for _, spell in ipairs(ability.also or {}) do
            if IsPlayerSpell(spell) then
                return spell
            end
        end
    end
    local skill = ability.skill
    local info = skill and C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID and C_SkillInfo.GetSkillLineInfoByID(skill.line)
    local rank = type(info) == "table" and info.rank
    return type(rank) == "number" and not ns.IsSecret(rank) and rank >= skill.rank
end

-- The character's class as the game names it in code ("DRUID"), or nil.
-- Rows of another class are never asked for.
local function OwnClass()
    local _, classFile = UnitClass("player")
    if ns.IsSecret(classFile) or type(classFile) ~= "string" then
        return nil
    end
    return classFile
end

local function ForClass(row, class)
    return row.class == nil or class == nil or row.class == class
end

function journey:CheckAbilities()
    local class = OwnClass()
    for _, ability in ipairs(Chronicle.abilities) do
        if ForClass(ability, class) and not Chronicle.HasAbility(ability.id) then
            local spell = Knows(ability)
            if spell and Chronicle.SeeAbility(ability.id) and self.skillsKnown then
                local name = C_Spell and C_Spell.GetSpellName
                    and C_Spell.GetSpellName(type(spell) == "number" and spell or ability.spell)
                Chronicle.Add("ability", {
                    ability = ability.id,
                    name = ns.ChatService.IsPlainText(name) and name or nil,
                    level = UnitLevel("player"),
                })
            end
        end
    end
end

-- Items (ChronicleService.items): the first time one lies in the bags or the
-- bank is an event. Only items not yet seen are asked for, so a character
-- that has them all costs nothing here.
function journey:CheckItems()
    if not (C_Item and C_Item.GetItemCount) then
        return
    end
    local class = OwnClass()
    for _, item in ipairs(Chronicle.items) do
        local id = item.item
        if ForClass(item, class) and not Chronicle.HasItem(id) then
            local count = C_Item.GetItemCount(id, true)
            if type(count) == "number" and not ns.IsSecret(count) and count > 0 and Chronicle.SeeItem(id) and self.skillsKnown then
                local name = C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
                Chronicle.Add("item", {
                    item = id,
                    name = ns.ChatService.IsPlainText(name) and name or nil,
                    level = UnitLevel("player"),
                    zone = Zone(),
                })
            end
        end
    end
end

function journey:OnEnable()
    explored = KnowExplored()
    -- What the character can do already is no news.
    self.skillsKnown = false
    self:SKILL_LINES_CHANGED()
    self:CheckItems()
    self.skillsKnown = true
    self:RegisterEvent("BAG_UPDATE_DELAYED", "CheckItems")
    self:RegisterEvent("SKILL_LINES_CHANGED")
    self:RegisterEvent("SPELLS_CHANGED", "CheckAbilities")
    -- Where the character stands now is no arrival.
    Chronicle.SeeZone(Zone())
    self:RegisterEvent("PLAYER_LEVEL_UP")
    self:RegisterEvent("PLAYER_DEAD")
    self:RegisterEvent("BOSS_KILL")
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    self:RegisterEvent("PLAYER_CONTROL_GAINED")
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

-- Who was there goes into an entry: the names in a party, in a raid only
-- how many. Neither is shared with companions (Modules/Chronicle/Sharing.lua).
local function WithGroup(entry)
    local members = ns.GroupService.Members(true)
    if #members > 0 and ns.GroupService.InRaid() then
        entry.others = #members
    elseif #members > 0 then
        entry.with = {}
        for index, member in ipairs(members) do
            entry.with[index] = member.name
        end
    end
    return entry
end

-- The last boss of an instance clears it; another one defeated for the
-- first time says so.
function journey:BOSS_KILL(_, encounterID, name)
    local entry = { id = encounterID, name = name, zone = Zone() }
    if Chronicle.SeeBoss(encounterID) then
        entry.first = 1
    end
    if not ns.IsSecret(encounterID) and encounterID and Chronicle.finalBosses[encounterID] then
        entry.instance = Zone()
    end
    Chronicle.Add("boss", WithGroup(entry))
end

-- "party" or "raid" inside a dungeon or a raid, else nil.
local function Instance()
    if not IsInInstance then
        return nil
    end
    local inside, kind = IsInInstance()
    if ns.IsSecret(inside) or not inside or not ns.ChatService.IsPlainText(kind) then
        return nil
    end
    return (kind == "party" or kind == "raid") and kind or nil
end

-- The Forever client shows achievements as "Legacy challenges".
function journey:ACHIEVEMENT_EARNED(_, achievementID, alreadyEarned)
    if alreadyEarned then
        return
    end
    local _, name, _, _, _, _, _, _, _, icon = GetAchievementInfo(achievementID)
    icon = not ns.IsSecret(icon) and type(icon) == "number" and icon or nil
    Chronicle.Add("achievement", { id = achievementID, name = name, icon = icon })
end

-- A zone is an arrival once per character: the first time it is entered on
-- the ground. Zones passed on a flight path are neither written down nor
-- marked as seen. A dungeon or a raid is such a zone too; the first time in
-- one is an event of its own, with who came along.
function journey:ZONE_CHANGED_NEW_AREA()
    if UnitOnTaxi and UnitOnTaxi("player") then
        return
    end
    if not explored then
        explored = KnowExplored()
    end
    local zone = Zone()
    if zone and Chronicle.SeeZone(zone) then
        if Instance() then
            Chronicle.Add("instance", WithGroup({ instance = zone, level = UnitLevel("player") }))
        else
            Chronicle.Add("zone", { zone = zone, level = UnitLevel("player") })
        end
    end
end

-- The end of a flight brings no change of zone with it, so the landing
-- place is looked at here. (The event also follows a stun or a fear; then
-- the zone is long known and nothing happens.)
function journey:PLAYER_CONTROL_GAINED()
    self:After(LANDING, self.ZONE_CHANGED_NEW_AREA)
end
