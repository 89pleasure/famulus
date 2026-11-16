-- Small comfort tweaks for map, chat, camera and error messages.

local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Coordinates on the world map
---------------------------------------------------------------------------

local coords = ns:NewFeature({
    id = "mapCoords",
    category = "interface",
    default = true,
    requires = { "C_Map.GetBestMapForUnit", "C_Map.GetPlayerMapPosition" },
})

local UPDATE_INTERVAL = 0.1
local coordFrame, coordText
local sinceUpdate = 0
local shownPX, shownPY, shownCX, shownCY

-- Returns the position in tenths of a percent, or -1 if it is unknown.
local function PlayerPosition()
    local mapID = C_Map.GetBestMapForUnit("player")
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then
        return -1, -1
    end
    local x, y = position:GetXY()
    if not x or ns.IsSecret(x) then
        return -1, -1
    end
    return math.floor(x * 1000 + 0.5), math.floor(y * 1000 + 0.5)
end

local function CursorPosition()
    local canvas = WorldMapFrame.ScrollContainer
    if not canvas or not canvas.GetNormalizedCursorPosition or not canvas:IsMouseOver() then
        return -1, -1
    end
    local x, y = canvas:GetNormalizedCursorPosition()
    if not x or x < 0 or x > 1 or y < 0 or y > 1 then
        return -1, -1
    end
    return math.floor(x * 1000 + 0.5), math.floor(y * 1000 + 0.5)
end

local function FormatPosition(label, x, y)
    if x < 0 then
        return label .. ": –"
    end
    return string.format("%s: %.1f, %.1f", label, x / 10, y / 10)
end

local function RefreshCoords(force)
    local px, py = PlayerPosition()
    local cx, cy = CursorPosition()
    -- New text is only built when a number actually changed.
    if not force and px == shownPX and py == shownPY and cx == shownCX and cy == shownCY then
        return
    end
    shownPX, shownPY, shownCX, shownCY = px, py, cx, cy
    coordText:SetText(FormatPosition(L.map_player, px, py) .. "     " .. FormatPosition(L.map_cursor, cx, cy))
    coordFrame:SetWidth(coordText:GetStringWidth() + 20)
end

-- Runs only while the world map is open: the frame is a child of the map,
-- and hidden frames receive no OnUpdate.
local function OnCoordUpdate(_, elapsed)
    sinceUpdate = sinceUpdate + elapsed
    if sinceUpdate >= UPDATE_INTERVAL then
        sinceUpdate = 0
        RefreshCoords(false)
    end
end

local function BuildCoordFrame()
    local map = WorldMapFrame
    local anchor = map.ScrollContainer or map
    coordFrame = CreateFrame("Frame", nil, map)
    coordFrame:SetSize(240, 22)
    coordFrame:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 8, 8)
    coordFrame:SetFrameLevel(math.min(9000, map:GetFrameLevel() + 500))

    local background = coordFrame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.07, 0.09, 0.14, 0.85)

    coordText = coordFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    coordText:SetPoint("LEFT", 10, 0)

    coordFrame:SetScript("OnShow", function()
        sinceUpdate = 0
        RefreshCoords(true)
    end)
    coordFrame:SetScript("OnUpdate", OnCoordUpdate)
end

local function ShowCoordFrame()
    if not coordFrame then
        BuildCoordFrame()
    end
    coordFrame:Show()
end

function coords:OnEnable()
    if WorldMapFrame then
        ShowCoordFrame()
    else
        self:RegisterEvent("ADDON_LOADED")
    end
end

function coords:ADDON_LOADED()
    if WorldMapFrame then
        self:UnregisterEvent("ADDON_LOADED")
        ShowCoordFrame()
    end
end

function coords:OnDisable()
    if coordFrame then
        coordFrame:Hide()
    end
end

ns:On("LOCALE_CHANGED", function()
    if coordFrame and coordFrame:IsVisible() then
        RefreshCoords(true)
    end
end)

---------------------------------------------------------------------------
-- Arrow keys in chat
---------------------------------------------------------------------------

local arrowKeys = ns:NewFeature({
    id = "chatArrowKeys",
    category = "interface",
    default = true,
})

local function SetAltArrowKeyMode(needsAlt)
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local editBox = _G["ChatFrame" .. i .. "EditBox"]
        if editBox and editBox.SetAltArrowKeyMode then
            editBox:SetAltArrowKeyMode(needsAlt)
        end
    end
end

function arrowKeys:OnEnable()
    SetAltArrowKeyMode(false)
end

function arrowKeys:OnDisable()
    SetAltArrowKeyMode(true)
end

---------------------------------------------------------------------------
-- Maximum camera distance
---------------------------------------------------------------------------

local camera = ns:NewFeature({
    id = "cameraZoom",
    category = "interface",
    default = false,
    requires = { "C_CVar.GetCVar", "C_CVar.SetCVar" },
})

local ZOOM_CVAR = "cameraDistanceMaxZoomFactor"
-- Game versions cap this at different values; take the highest one accepted.
local ZOOM_CANDIDATES = { 4.0, 2.6 }

function camera:OnEnable()
    local current = tonumber(C_CVar.GetCVar(ZOOM_CVAR))
    if not current then
        return
    end
    -- Remember the player's own value once, so switching off restores it.
    if not ns.global.cameraZoomBefore then
        ns.global.cameraZoomBefore = current
    end
    for i = 1, #ZOOM_CANDIDATES do
        local target = ZOOM_CANDIDATES[i]
        if current >= target then
            break
        end
        pcall(C_CVar.SetCVar, ZOOM_CVAR, target)
        if (tonumber(C_CVar.GetCVar(ZOOM_CVAR)) or 0) >= target - 0.01 then
            break
        end
    end
end

function camera:OnDisable()
    local before = ns.global.cameraZoomBefore
    if before then
        pcall(C_CVar.SetCVar, ZOOM_CVAR, before)
        ns.global.cameraZoomBefore = nil
    end
end

---------------------------------------------------------------------------
-- Hide combat error spam
---------------------------------------------------------------------------

local errors = ns:NewFeature({
    id = "hideErrors",
    category = "interface",
    default = false,
    requires = { "UIErrorsFrame" },
})

-- Global string names, so the list matches in every client language.
local BLOCKED_GLOBALS = {
    "ERR_ABILITY_COOLDOWN",
    "ERR_SPELL_COOLDOWN",
    "ERR_ITEM_COOLDOWN",
    "ERR_OUT_OF_RAGE",
    "ERR_OUT_OF_ENERGY",
    "ERR_OUT_OF_MANA",
    "ERR_OUT_OF_FOCUS",
    "ERR_OUT_OF_RANGE",
    "ERR_SPELL_OUT_OF_RANGE",
    "ERR_BADATTACKPOS",
    "ERR_BADATTACKFACING",
    "ERR_NO_ATTACK_TARGET",
    "ERR_GENERIC_NO_TARGET",
    "ERR_INVALID_ATTACK_TARGET",
    "ERR_CLIENT_LOCKED_OUT",
    "ERR_ATTACK_STUNNED",
    "ERR_ATTACK_PACIFIED",
    "ERR_USE_TOO_FAR",
    "SPELL_FAILED_SPELL_IN_PROGRESS",
    "SPELL_FAILED_MOVING",
    "SPELL_FAILED_BAD_TARGETS",
    "SPELL_FAILED_NO_COMBO_POINTS",
    "SPELL_FAILED_UNIT_NOT_INFRONT",
    "SPELL_FAILED_TOO_CLOSE",
    "SPELL_FAILED_TARGETS_DEAD",
    "SPELL_FAILED_ITEM_NOT_READY",
    "SPELL_FAILED_NOT_READY",
}

local blocked

function errors:OnEnable()
    if not blocked then
        blocked = {}
        for i = 1, #BLOCKED_GLOBALS do
            local text = _G[BLOCKED_GLOBALS[i]]
            if type(text) == "string" then
                blocked[text] = true
            end
        end
    end
    -- Take over the error event and pass on everything that is not spam.
    UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
    self:RegisterEvent("UI_ERROR_MESSAGE")
end

function errors:OnDisable()
    UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
end

function errors:UI_ERROR_MESSAGE(_, messageType, message)
    -- A secret value cannot be looked up; such messages are always shown.
    if not ns.IsSecret(message) and blocked[message] then
        return
    end
    if UIErrorsFrame.TryDisplayMessage then
        UIErrorsFrame:TryDisplayMessage(messageType, message, 1, 0.1, 0.1)
    else
        UIErrorsFrame:AddMessage(message, 1, 0.1, 0.1, 1)
    end
end

---------------------------------------------------------------------------
-- Screenshot on level up
---------------------------------------------------------------------------

local levelShot = ns:NewFeature({
    id = "levelScreenshot",
    category = "interface",
    default = false,
    requires = { "Screenshot" },
})

local function TakeScreenshot()
    if levelShot.enabled then
        Screenshot()
    end
end

function levelShot:OnEnable()
    self:RegisterEvent("PLAYER_LEVEL_UP")
end

function levelShot:PLAYER_LEVEL_UP()
    -- Wait for the level-up banner to appear.
    C_Timer.After(1.5, TakeScreenshot)
end
