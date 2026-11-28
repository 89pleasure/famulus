-- Optional minimap button. Created only when the option is on. Its position
-- is written to the saved settings when a drag ends, not on every frame.

local _, ns = ...
local L = ns.L
local UI = ns.UI

local button

local function Place(angle)
    local radius = Minimap:GetWidth() / 2 + 6
    local radians = math.rad(angle)
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", math.cos(radians) * radius, math.sin(radians) * radius)
end

local function CursorAngle()
    local centerX, centerY = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    local cursorX, cursorY = GetCursorPosition()
    return math.deg(math.atan2(cursorY / scale - centerY, cursorX / scale - centerX))
end

local function OnDragUpdate(self)
    self.angle = CursorAngle()
    Place(self.angle)
end

local function Build()
    button = CreateFrame("Button", "FamulusMinimapButton", Minimap)
    button:SetSize(28, 28)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")

    local rim = button:CreateTexture(nil, "BACKGROUND")
    rim:SetTexture(UI.media.circle)
    UI.Tint(rim, "sidebar")
    rim:SetAllPoints()

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(UI.media.logoRound)
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)

    local glow = button:CreateTexture(nil, "OVERLAY")
    glow:SetTexture(UI.media.circle)
    glow:SetVertexColor(1, 1, 1, 0.18)
    glow:SetAllPoints(icon)
    glow:Hide()

    -- News not yet seen (Core/NewsService.lua).
    button.dot = UI.GlowDot(button, 6, "OVERLAY")
    button.dot:SetPoint("CENTER", button, "TOPRIGHT", -5, -5)

    button:SetScript("OnClick", function()
        ns:ToggleOptions()
    end)
    button:SetScript("OnEnter", function(self)
        glow:Show()
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Famulus", UI.Color("accent"))
        if ns.NewsService.Unread() then
            GameTooltip:AddLine(L.ui_news_minimap:format(ns.NewsService.RELEASE, L.cat_about), UI.Color("accent2"))
        end
        GameTooltip:AddLine(L.ui_minimap_hint_click, 1, 1, 1)
        GameTooltip:AddLine(L.ui_minimap_hint_drag, UI.Color("textMuted"))
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        glow:Hide()
        GameTooltip:Hide()
    end)
    button:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", OnDragUpdate)
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        if self.angle then
            ns:SetOption("general", "minimapAngle", math.floor(self.angle + 0.5))
        end
    end)
end

local function Update()
    local wanted = ns:GetOption("general", "minimapButton")
    if wanted and not button then
        if not Minimap then
            return
        end
        Build()
    end
    if button then
        button:SetShown(wanted)
        if wanted then
            Place(ns:GetOption("general", "minimapAngle"))
        end
        UI.SetDot(button.dot, nil, ns.NewsService.Unread())
    end
end

ns:On("LOGIN", Update)
ns:On("PROFILE_CHANGED", Update)
ns:On("NEWS_READ", Update)
ns:On("OPTION_CHANGED", function(section, key)
    if section == "general" and (key == "minimapButton" or key == "minimapAngle") then
        Update()
    end
end)
