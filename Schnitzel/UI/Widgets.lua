-- Building blocks of the settings window. Nothing here runs at load time;
-- every function is called when the window is first opened.

local _, ns = ...
local UI = ns.UI

---------------------------------------------------------------------------
-- Fills, borders, text
---------------------------------------------------------------------------

function UI.Fill(frame, colorName, layer)
    local texture = frame:CreateTexture(nil, layer or "BACKGROUND")
    texture:SetAllPoints(frame)
    texture:SetColorTexture(UI.Color(colorName))
    return texture
end

-- Hairline border made of four edge textures. Returns a table with
-- :SetColor(colorName).
function UI.Border(frame, colorName)
    local size = UI.Pixel(frame)
    local edges = {}
    for i = 1, 4 do
        local edge = frame:CreateTexture(nil, "BORDER")
        edge:SetColorTexture(UI.Color(colorName or "border"))
        edges[i] = edge
    end
    edges[1]:SetPoint("TOPLEFT")
    edges[1]:SetPoint("TOPRIGHT")
    edges[1]:SetHeight(size)
    edges[2]:SetPoint("BOTTOMLEFT")
    edges[2]:SetPoint("BOTTOMRIGHT")
    edges[2]:SetHeight(size)
    edges[3]:SetPoint("TOPLEFT")
    edges[3]:SetPoint("BOTTOMLEFT")
    edges[3]:SetWidth(size)
    edges[4]:SetPoint("TOPRIGHT")
    edges[4]:SetPoint("BOTTOMRIGHT")
    edges[4]:SetWidth(size)

    function edges:SetColor(name)
        for i = 1, 4 do
            self[i]:SetColorTexture(UI.Color(name))
        end
    end
    return edges
end

-- Shades a texture vertically between two theme colours. Returns false if
-- the client has no gradient support; the caller then keeps a plain colour.
function UI.ApplyGradient(texture, bottomName, topName)
    if not (texture.SetGradient and CreateColor) then
        return false
    end
    texture:SetColorTexture(1, 1, 1, 1)
    local ok = pcall(texture.SetGradient, texture, "VERTICAL", CreateColor(UI.Color(bottomName)), CreateColor(UI.Color(topName)))
    return ok
end

-- Thick frame drawn just outside a window, shading from one colour at the
-- top to another at the bottom. thickness is in UI units and is snapped to
-- whole screen pixels.
function UI.GradientFrame(frame, topName, bottomName, thickness)
    local pixel = UI.Pixel(frame)
    local size = math.max(pixel, math.floor(thickness / pixel + 0.5) * pixel)

    local top = frame:CreateTexture(nil, "BORDER")
    top:SetColorTexture(UI.Color(topName))
    top:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", -size, 0)
    top:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", size, 0)
    top:SetHeight(size)

    local bottom = frame:CreateTexture(nil, "BORDER")
    bottom:SetColorTexture(UI.Color(bottomName))
    bottom:SetPoint("TOPLEFT", frame, "BOTTOMLEFT", -size, 0)
    bottom:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", size, 0)
    bottom:SetHeight(size)

    local left = frame:CreateTexture(nil, "BORDER")
    left:SetPoint("TOPRIGHT", frame, "TOPLEFT")
    left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT")
    left:SetWidth(size)

    local right = frame:CreateTexture(nil, "BORDER")
    right:SetPoint("TOPLEFT", frame, "TOPRIGHT")
    right:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT")
    right:SetWidth(size)

    for _, side in ipairs({ left, right }) do
        if not UI.ApplyGradient(side, bottomName, topName) then
            side:SetColorTexture(UI.Color(topName))
        end
    end
    return size
end

function UI.Line(frame, colorName)
    local line = frame:CreateTexture(nil, "BORDER")
    line:SetColorTexture(UI.Color(colorName or "divider"))
    line:SetHeight(UI.Pixel(frame))
    return line
end

function UI.Text(parent, size, colorName)
    local text = parent:CreateFontString(nil, "OVERLAY")
    text:SetFont(UI.font, size, "")
    text:SetShadowOffset(1, -1)
    text:SetShadowColor(0, 0, 0, 0.5)
    text:SetTextColor(UI.Color(colorName or "text"))
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    return text
end

function UI.Icon(parent, media, size, colorName)
    local icon = parent:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(UI.media[media])
    icon:SetSize(size, size)
    if colorName then
        icon:SetVertexColor(UI.Color(colorName))
    end
    return icon
end

---------------------------------------------------------------------------
-- Button
---------------------------------------------------------------------------

function UI.Button(parent, onClick)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(28)
    UI.Fill(button, "control")
    UI.Border(button)

    local hover = UI.Fill(button, "hover", "ARTWORK")
    hover:Hide()

    local label = UI.Text(button, 12, "text")
    label:SetPoint("CENTER")
    button.label = label

    function button:SetLabel(text)
        label:SetText(text)
        self:SetWidth(math.max(84, label:GetStringWidth() + 32))
    end

    -- A disabled button is greyed out and ignores hover and clicks.
    function button:SetDisabled(disabled)
        disabled = disabled and true or false
        self.disabled = disabled
        self:SetAlpha(disabled and 0.4 or 1)
        if disabled then
            hover:Hide()
            label:SetPoint("CENTER", 0, 0)
        end
    end

    button:SetScript("OnEnter", function(self)
        if not self.disabled then
            hover:Show()
        end
    end)
    button:SetScript("OnLeave", function()
        hover:Hide()
    end)
    button:SetScript("OnMouseDown", function(self)
        if not self.disabled then
            label:SetPoint("CENTER", 0, -1)
        end
    end)
    button:SetScript("OnMouseUp", function()
        label:SetPoint("CENTER", 0, 0)
    end)
    button:SetScript("OnClick", function(self, ...)
        if not self.disabled then
            onClick(self, ...)
        end
    end)
    return button
end

---------------------------------------------------------------------------
-- Toggle: a 30x16 pill with a sliding knob. Purely visual; the row that
-- owns it handles the click, so the whole row is the hit target.
---------------------------------------------------------------------------

local TOGGLE_W, TOGGLE_H, KNOB = 30, 16, 12
local KNOB_OFF, KNOB_ON = 2, TOGGLE_W - KNOB - 2

function UI.Toggle(parent)
    local toggle = CreateFrame("Frame", nil, parent)
    toggle:SetSize(TOGGLE_W, TOGGLE_H)

    local half = TOGGLE_H / 2
    local left = toggle:CreateTexture(nil, "ARTWORK")
    left:SetTexture(UI.media.circle)
    left:SetTexCoord(0, 0.5, 0, 1)
    left:SetSize(half, TOGGLE_H)
    left:SetPoint("LEFT")

    local right = toggle:CreateTexture(nil, "ARTWORK")
    right:SetTexture(UI.media.circle)
    right:SetTexCoord(0.5, 1, 0, 1)
    right:SetSize(half, TOGGLE_H)
    right:SetPoint("RIGHT")

    local middle = toggle:CreateTexture(nil, "ARTWORK")
    middle:SetPoint("TOPLEFT", half, 0)
    middle:SetPoint("BOTTOMRIGHT", -half, 0)

    local knob = toggle:CreateTexture(nil, "OVERLAY")
    knob:SetTexture(UI.media.circle)
    knob:SetSize(KNOB, KNOB)

    local knobX

    local function PlaceKnob(x)
        knobX = x
        knob:SetPoint("LEFT", toggle, "LEFT", x, 0)
    end

    function toggle:Set(on, animate)
        on = on and true or false
        local changed = self.on ~= on
        self.on = on

        local r, g, b, a = UI.Color(on and "accent" or "track")
        left:SetVertexColor(r, g, b, a)
        right:SetVertexColor(r, g, b, a)
        middle:SetColorTexture(r, g, b, a)
        knob:SetVertexColor(UI.Color(on and "onAccent" or "textDim"))

        local target = on and KNOB_ON or KNOB_OFF
        if animate and changed and knobX then
            local from = knobX
            UI.Tween(self, 0.12, function(progress)
                PlaceKnob(from + (target - from) * progress)
            end)
        else
            UI.CancelTween(self)
            PlaceKnob(target)
        end
    end

    return toggle
end

---------------------------------------------------------------------------
-- Dropdown: a value box plus one shared popup menu.
---------------------------------------------------------------------------

local DROPDOWN_W, MENU_ROW = 150, 26
local menu, catcher

local function CloseMenu()
    if menu then
        menu:Hide()
    end
end
UI.CloseMenu = CloseMenu

local function BuildMenu()
    -- Invisible full-screen button underneath the menu: a click anywhere
    -- else closes the menu.
    catcher = CreateFrame("Button", nil, UIParent)
    catcher:SetAllPoints(UIParent)
    catcher:SetFrameStrata("DIALOG")
    catcher:Hide()
    catcher:SetScript("OnClick", CloseMenu)

    menu = CreateFrame("Frame", nil, UIParent)
    menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(catcher:GetFrameLevel() + 10)
    menu:EnableMouse(true)
    menu:Hide()
    UI.Fill(menu, "control")
    UI.Border(menu)
    menu.rows = {}
    menu:SetScript("OnHide", function()
        catcher:Hide()
        menu.owner = nil
    end)
end

local function MenuRow(index)
    local row = menu.rows[index]
    if row then
        return row
    end
    row = CreateFrame("Button", nil, menu)
    row:SetHeight(MENU_ROW)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * MENU_ROW - 2)
    row:SetPoint("TOPRIGHT", 0, -(index - 1) * MENU_ROW - 2)
    local hover = UI.Fill(row, "hover", "ARTWORK")
    hover:Hide()
    row.text = UI.Text(row, 12, "text")
    row.text:SetPoint("LEFT", 12, 0)
    row:SetScript("OnEnter", function()
        hover:Show()
    end)
    row:SetScript("OnLeave", function()
        hover:Hide()
    end)
    row:SetScript("OnClick", function(self)
        local onSelect, value = menu.onSelect, self.value
        CloseMenu()
        onSelect(value)
    end)
    menu.rows[index] = row
    return row
end

-- values: array of { value = ..., text = "..." }
function UI.OpenMenu(owner, values, current, onSelect)
    if not menu then
        BuildMenu()
    end
    if menu:IsShown() and menu.owner == owner then
        CloseMenu()
        return
    end
    menu.owner = owner
    menu.onSelect = onSelect
    for i = 1, #values do
        local row = MenuRow(i)
        row.value = values[i].value
        row.text:SetText(values[i].text)
        row.text:SetTextColor(UI.Color(values[i].value == current and "accent" or "text"))
        row:Show()
    end
    for i = #values + 1, #menu.rows do
        menu.rows[i]:Hide()
    end
    -- The menu hangs off UIParent; give it the size of the scaled window.
    menu:SetScale(owner:GetEffectiveScale() / UIParent:GetEffectiveScale())
    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -4)
    menu:SetSize(owner:GetWidth(), #values * MENU_ROW + 4)
    catcher:Show()
    menu:Show()
end

function UI.Dropdown(parent)
    local dropdown = CreateFrame("Frame", nil, parent)
    dropdown:SetSize(DROPDOWN_W, 28)
    UI.Fill(dropdown, "control")
    UI.Border(dropdown)

    local chevron = UI.Icon(dropdown, "chevron", 12, "textMuted")
    chevron:SetPoint("RIGHT", -9, 0)

    local text = UI.Text(dropdown, 12, "text")
    text:SetPoint("LEFT", 12, 0)
    text:SetPoint("RIGHT", chevron, "LEFT", -6, 0)
    text:SetWordWrap(false)
    text:SetJustifyV("MIDDLE")
    dropdown.text = text
    return dropdown
end

---------------------------------------------------------------------------
-- Search box
---------------------------------------------------------------------------

function UI.SearchBox(parent, onChange)
    local box = CreateFrame("Frame", nil, parent)
    box:SetHeight(30)
    UI.Fill(box, "field")
    local border = UI.Border(box)

    local edit = CreateFrame("EditBox", nil, box)
    edit:SetPoint("TOPLEFT", 10, 0)
    edit:SetPoint("BOTTOMRIGHT", -28, 0)
    edit:SetAutoFocus(false)
    edit:SetFont(UI.font, 12, "")
    edit:SetTextColor(UI.Color("text"))
    edit:SetMaxLetters(40)
    box.edit = edit

    local placeholder = UI.Text(box, 12, "textMuted")
    placeholder:SetPoint("LEFT", 10, 0)
    box.placeholder = placeholder

    -- Clears the field and ends the search; only there while there is text.
    local clear = CreateFrame("Button", nil, box)
    clear:SetSize(22, 22)
    clear:SetPoint("RIGHT", -4, 0)
    clear:Hide()
    local clearIcon = UI.Icon(clear, "close", 10, "textMuted")
    clearIcon:SetPoint("CENTER")
    clear:SetScript("OnEnter", function()
        clearIcon:SetVertexColor(UI.Color("text"))
    end)
    clear:SetScript("OnLeave", function()
        clearIcon:SetVertexColor(UI.Color("textMuted"))
    end)
    clear:SetScript("OnClick", function()
        edit:SetText("")
        edit:ClearFocus()
    end)
    box.clear = clear

    edit:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        placeholder:SetShown(text == "")
        clear:SetShown(text ~= "")
        onChange(text)
    end)
    edit:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    edit:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
    end)
    edit:SetScript("OnEditFocusGained", function()
        border:SetColor("accent")
    end)
    edit:SetScript("OnEditFocusLost", function()
        border:SetColor("border")
    end)
    box:SetScript("OnMouseDown", function()
        edit:SetFocus()
    end)
    return box
end

---------------------------------------------------------------------------
-- Scroll area with a slim position indicator
---------------------------------------------------------------------------

local WHEEL_STEP = 48

function UI.Scroll(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll.content = content

    local thumb = parent:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(UI.Color("thumb"))
    thumb:SetWidth(3)
    thumb:Hide()

    local function Range()
        return math.max(0, content:GetHeight() - scroll:GetHeight())
    end

    function scroll:UpdateThumb()
        local range, view = Range(), self:GetHeight()
        if range <= 0 or view <= 0 then
            thumb:Hide()
            return
        end
        local length = math.max(24, view * view / content:GetHeight())
        local offset = (view - length) * (self:GetVerticalScroll() / range)
        thumb:SetHeight(length)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", 10, -offset)
        thumb:Show()
    end

    function scroll:SetContentHeight(height)
        content:SetHeight(math.max(1, height))
        self:SetVerticalScroll(math.min(self:GetVerticalScroll(), Range()))
        self:UpdateThumb()
    end

    function scroll:ScrollToTop()
        self:SetVerticalScroll(0)
        self:UpdateThumb()
    end

    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local target = self:GetVerticalScroll() - delta * WHEEL_STEP
        self:SetVerticalScroll(math.max(0, math.min(Range(), target)))
        self:UpdateThumb()
    end)
    scroll:SetScript("OnSizeChanged", function(self, width)
        content:SetWidth(width)
        self:UpdateThumb()
    end)
    return scroll
end
