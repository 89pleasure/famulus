-- Player and cursor coordinates on the world map. Optionally, a click on the
-- field puts the player's position into the chat input, ready to send.
-- (Copying to the clipboard is protected for addons.)

local _, ns = ...
local L = ns.L

local CLICK_OPTION = { key = "clickToChat", type = "toggle", default = true, requires = "ChatFrameUtil.OpenChat" }

local coords = ns:NewFeature({
    id = "mapCoords",
    category = "interface",
    default = true,
    requires = { "C_Map.GetBestMapForUnit", "C_Map.GetPlayerMapPosition" },
    options = { CLICK_OPTION },
})

local UPDATE_INTERVAL = 0.1
local BACKGROUND = { 0.07, 0.09, 0.14, 0.85 }
local BACKGROUND_HOVER = { 0.13, 0.16, 0.24, 0.95 }

-- Layout of the field: [Player:] [value slot]  [Cursor:] [value slot]
local PADDING = 10
local LABEL_GAP = 4
local COLUMN_GAP = 16

local coordFrame, coordBackground
local playerLabel, playerValue, cursorLabel, cursorValue
local sinceUpdate = 0
local shownPX, shownPY, shownCX, shownCY

-- Map positions are 0..1; shown in tenths of a percent.
local function Tenths(x, y)
    return math.floor(x * 1000 + 0.5), math.floor(y * 1000 + 0.5)
end

-- Returns the position in tenths of a percent, or -1 if it is unknown, and
-- the map it was read on.
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
    local tx, ty = Tenths(x, y)
    return tx, ty, mapID
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
    return Tenths(x, y)
end

local function FormatPosition(x, y)
    if x < 0 then
        return "–"
    end
    return string.format("%.1f, %.1f", x / 10, y / 10)
end

-- Each value gets a slot as wide as the widest usual value, "00.0, 00.0"
-- written with the font's widest digit, so the field keeps its width while
-- the numbers change. (100.0 at the very edge of a map runs into the gap.)
local function ValueSlotWidth()
    local widest = 0
    for digit = 0, 9 do
        playerValue:SetText(string.format("%d%d.%d, %d%d.%d", digit, digit, digit, digit, digit, digit))
        widest = math.max(widest, playerValue:GetStringWidth())
    end
    return widest
end

-- Places labels and value slots and sizes the field. Runs when the field is
-- built and when the language changes, never per update.
local function Layout()
    playerLabel:SetText(L.map_player .. ":")
    cursorLabel:SetText(L.map_cursor .. ":")
    local slot = ValueSlotWidth()
    cursorLabel:ClearAllPoints()
    cursorLabel:SetPoint("LEFT", playerValue, "LEFT", slot + COLUMN_GAP, 0)
    coordFrame:SetWidth(PADDING + playerLabel:GetStringWidth() + LABEL_GAP + slot
        + COLUMN_GAP + cursorLabel:GetStringWidth() + LABEL_GAP + slot + PADDING)
end

local function RefreshCoords(force)
    local px, py = PlayerPosition()
    local cx, cy = CursorPosition()
    -- New text is only built when a number actually changed.
    if not force and px == shownPX and py == shownPY and cx == shownCX and cy == shownCY then
        return
    end
    shownPX, shownPY, shownCX, shownCY = px, py, cx, cy
    playerValue:SetText(FormatPosition(px, py))
    cursorValue:SetText(FormatPosition(cx, cy))
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

---------------------------------------------------------------------------
-- Click to chat
---------------------------------------------------------------------------

local function ClickEnabled()
    return ns:IsOptionAvailable(CLICK_OPTION) and coords:Get("clickToChat") and true or false
end

local function ZoneName(mapID)
    local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
    local name = info and info.name
    if ns.ChatService.IsPlainText(name) then
        return name
    end
    return nil
end

-- "Westfall 45.3, 67.8", or nil while the position is unknown.
local function PlayerPositionText()
    local px, py, mapID = PlayerPosition()
    if px < 0 then
        return nil
    end
    local position = string.format("%.1f, %.1f", px / 10, py / 10)
    local zone = ZoneName(mapID)
    return zone and (zone .. " " .. position) or position
end

-- Clicking the field takes the keyboard focus from the chat input. An empty
-- input then closes and the game resets its chat type ("/y" becomes "/s")
-- before our click handler runs. The focus-lost callback fires before that
-- reset, so the target is read there and the input reopened with it.
local closedChatPrefix

function coords:OnChatFocusLost(editBox)
    closedChatPrefix = ns.ChatService.TargetPrefix(editBox)
end

local function OnCoordClick(_, button)
    if button == "LeftButton" and ClickEnabled() then
        ns.ChatService.InsertText(PlayerPositionText(), closedChatPrefix)
        closedChatPrefix = nil
    end
end

-- The chat input is watched only while the mouse is over the field.
local function OnCoordEnter(self)
    closedChatPrefix = nil
    coords:RegisterCallback("ChatFrame.OnEditBoxFocusLost", "OnChatFocusLost")
    coordBackground:SetColorTexture(unpack(BACKGROUND_HOVER))
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(L.map_click_to_chat, 1, 1, 1)
    GameTooltip:Show()
end

local function StopHover()
    coords:UnregisterCallback("ChatFrame.OnEditBoxFocusLost")
    closedChatPrefix = nil
    coordBackground:SetColorTexture(unpack(BACKGROUND))
end

local function OnCoordLeave()
    StopHover()
    GameTooltip:Hide()
end

-- Only a clickable field takes the mouse; otherwise clicks on that corner of
-- the map go to the map as before.
local function UpdateMouse()
    if not coordFrame then
        return
    end
    local clickable = ClickEnabled()
    coordFrame:EnableMouse(clickable)
    if clickable then
        coordFrame:SetScript("OnMouseUp", OnCoordClick)
        coordFrame:SetScript("OnEnter", OnCoordEnter)
        coordFrame:SetScript("OnLeave", OnCoordLeave)
    else
        coordFrame:SetScript("OnMouseUp", nil)
        coordFrame:SetScript("OnEnter", nil)
        coordFrame:SetScript("OnLeave", nil)
        StopHover()
    end
end

---------------------------------------------------------------------------
-- Frame
---------------------------------------------------------------------------

local function BuildCoordFrame()
    local map = WorldMapFrame
    local anchor = map.ScrollContainer or map
    coordFrame = CreateFrame("Frame", nil, map)
    coordFrame:SetSize(240, 22)
    coordFrame:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 8, 8)
    coordFrame:SetFrameLevel(math.min(9000, map:GetFrameLevel() + 500))

    coordBackground = coordFrame:CreateTexture(nil, "BACKGROUND")
    coordBackground:SetAllPoints()
    coordBackground:SetColorTexture(unpack(BACKGROUND))

    local function Text(anchor, relativeTo, relativePoint, x)
        local text = coordFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        text:SetJustifyH("LEFT")
        text:SetWordWrap(false)
        text:SetPoint(anchor, relativeTo, relativePoint, x, 0)
        return text
    end
    playerLabel = Text("LEFT", coordFrame, "LEFT", PADDING)
    playerValue = Text("LEFT", playerLabel, "RIGHT", LABEL_GAP)
    cursorLabel = Text("LEFT", playerValue, "LEFT", 0)
    cursorValue = Text("LEFT", cursorLabel, "RIGHT", LABEL_GAP)
    Layout()

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
    UpdateMouse()
    coordFrame:Show()
end

function coords:OnOptionChanged(key)
    if key == "clickToChat" then
        UpdateMouse()
    end
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
    if coordFrame then
        Layout()
        if coordFrame:IsVisible() then
            RefreshCoords(true)
        end
    end
end)
