-- The bug report: the text of ns:BugReport() (Core/SelfTest.lua) in a small
-- window of its own, already selected, so the player copies it with Ctrl+C
-- and pastes it into an issue. CopyToClipboard is protected, so this is the
-- usual way (WeakAuras' export, BugSack). "/fam report" and About › "Bug
-- report" open it; built the first time it is shown.

local _, ns = ...
local L = ns.L
local UI = ns.UI

local Report = {}
UI.Report = Report

local ISSUES = "github.com/89pleasure/famulus/issues"
local WIDTH, HEIGHT, RADIUS, PAD = 640, 500, 14, 24
local TEXT_SIZE = 11

local dialog

local function Build()
    dialog = CreateFrame("Frame", nil, UIParent)
    dialog:SetSize(WIDTH, HEIGHT)
    dialog:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    -- Above the window, which stands on HIGH.
    dialog:SetFrameStrata("DIALOG")
    dialog:SetToplevel(true)
    dialog:SetClampedToScreen(true)
    dialog:EnableMouse(true)
    dialog:SetMovable(true)
    dialog:RegisterForDrag("LeftButton")
    dialog:SetScript("OnDragStart", dialog.StartMoving)
    dialog:SetScript("OnDragStop", dialog.StopMovingOrSizing)
    dialog:Hide()
    UI.Shadow(dialog, 32, RADIUS, 10)
    UI.Card(dialog, "window", "windowBorder", RADIUS)

    local icon = UI.Icon(dialog, "info", 18, "accent")
    icon:SetPoint("TOPLEFT", PAD, -PAD)
    local title = UI.Text(dialog, 18, "text", "semibold")
    title:SetPoint("LEFT", icon, "RIGHT", 10, 0)
    dialog.title = title
    dialog.close = UI.IconButton(dialog, "close", function()
        dialog:Hide()
    end, 26)
    dialog.close:SetPoint("TOPRIGHT", -14, -14)

    local hint = UI.Text(dialog, 12, "textDim")
    hint:SetPoint("TOPLEFT", icon, "BOTTOMLEFT", 0, -14)
    hint:SetWidth(WIDTH - PAD * 2)
    hint:SetSpacing(3)
    dialog.hint = hint

    -- The text in a sunken field that scrolls.
    local field = CreateFrame("Frame", nil, dialog)
    field:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -16)
    field:SetPoint("BOTTOMRIGHT", -PAD, PAD)
    UI.Card(field, "field", "fieldBorder", 8)
    local scroll = UI.Scroll(field)
    scroll:SetPoint("TOPLEFT", 12, -10)
    scroll:SetPoint("BOTTOMRIGHT", -20, 10)
    dialog.scroll = scroll
    local width = WIDTH - PAD * 2 - 32

    local edit = CreateFrame("EditBox", nil, scroll.content)
    edit:SetPoint("TOPLEFT")
    edit:SetWidth(width)
    edit:SetMultiLine(true)
    edit:SetAutoFocus(false)
    edit:SetMaxLetters(0)
    UI.SetFont(edit, TEXT_SIZE, "regular")
    edit:SetTextColor(UI.Color("text"))
    dialog.edit = edit
    -- Edit boxes keep their own text colour; follow the theme by hand.
    ns:On("THEME_CHANGED", function()
        edit:SetTextColor(UI.Color("text"))
    end)
    -- Measures the text, so the field scrolls as far as it reaches.
    local measure = UI.Text(scroll.content, TEXT_SIZE, "text")
    measure:SetWidth(width)
    measure:Hide()
    dialog.measure = measure

    -- Read only: whatever is typed goes, and the text is selected again.
    edit:SetScript("OnTextChanged", function(self, typed)
        if typed then
            self:SetText(dialog.text)
            self:HighlightText()
        end
    end)
    -- A click into it selects it all again, ready for Ctrl+C.
    edit:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    edit:SetScript("OnMouseUp", function(self)
        self:HighlightText()
    end)
    edit:SetScript("OnEscapePressed", function()
        dialog:Hide()
    end)
    dialog:SetScript("OnHide", function()
        edit:ClearFocus()
    end)
end

function Report.Show(text)
    if not dialog then
        Build()
    end
    dialog:SetScale((tonumber(ns:GetOption("general", "windowScale")) or 100) / 100)
    dialog.title:SetText(L.ui_report_title)
    local hint = L.ui_report_hint:format(ISSUES)
    if not ns:IsDevMode() then
        hint = hint .. " " .. L.ui_report_dev
    end
    dialog.hint:SetText(hint)

    dialog.text = text
    dialog.edit:SetText(text)
    dialog.measure:SetText(text)
    local height = math.ceil(dialog.measure:GetStringHeight()) + 4
    dialog.edit:SetHeight(height)
    dialog.scroll:SetContentHeight(height)
    dialog.scroll:ScrollToTop()
    dialog:Show()
    dialog.edit:SetFocus()
    dialog.edit:HighlightText()
end

function Report.IsShown()
    return dialog ~= nil and dialog:IsShown()
end

-- For the tests.
function Report.Frame()
    return dialog
end

function ns:ShowBugReport()
    Report.Show(ns:BugReport())
end
