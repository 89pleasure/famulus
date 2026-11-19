-- Building blocks of the settings window. Nothing here runs at load time;
-- every function is called when the window is first opened.
--
-- Rounded shapes are drawn from quarters of circle.tga for the corners and
-- three plain rectangles in between, so any size works without stretching
-- and every piece follows the theme through UI.Paint / UI.Tint.

local _, ns = ...
local UI = ns.UI

---------------------------------------------------------------------------
-- Shapes
---------------------------------------------------------------------------

local Shape = {}
Shape.__index = Shape

function Shape:SetColor(token, alpha)
    self.token, self.alpha = token, alpha or 1
    for _, part in ipairs(self.parts) do
        if part.rounded then
            UI.Tint(part, token, self.alpha)
        else
            UI.Paint(part, token, self.alpha)
        end
    end
end

-- Shades the shape from one colour token into another ("HORIZONTAL": left
-- to right, "VERTICAL": top to bottom). The shape is made of several
-- textures, so it needs the size of its frame to give each its share.
function Shape:SetGradient(orientation, fromToken, toToken, width, height, alpha)
    local vertical = orientation == "VERTICAL"
    local inset = self.inset or 0
    local length = math.max(1, (vertical and height or width) - inset * 2)
    for _, part in ipairs(self.parts) do
        -- Each end of a part is { 0 or 1 (near or far edge), offset from it }.
        local near = part.span[vertical and 3 or 1]
        local far = part.span[vertical and 4 or 2]
        local size = vertical and height or width
        UI.Shade(part, orientation, fromToken, toToken, {
            start = (near[1] * size + near[2] - inset) / length,
            stop = (far[1] * size + far[2] - inset) / length,
            alpha = alpha,
            textured = part.rounded,
        })
    end
end

local FADE = 0.12

function Shape:SetShown(shown)
    UI.CancelTween(self)
    self.level = shown and 1 or 0
    for _, part in ipairs(self.parts) do
        UI.SetLevel(part, 1)
        part:SetShown(shown)
    end
end

-- Like SetShown, but blends in or out instead of switching.
function Shape:Fade(shown)
    local from, to = self.level or 1, shown and 1 or 0
    if from == to then
        return
    end
    for _, part in ipairs(self.parts) do
        part:Show()
    end
    UI.Tween(self, FADE, function(progress)
        local level = from + (to - from) * progress
        self.level = level
        for _, part in ipairs(self.parts) do
            UI.SetLevel(part, level)
            if progress >= 1 and to == 0 then
                part:Hide()
            end
        end
    end)
end

function Shape:Show()
    self:SetShown(true)
end

function Shape:Hide()
    self:SetShown(false)
end

local CORNERS = {
    { "TOPLEFT", 1, -1, 0, 0.5, 0, 0.5 },
    { "TOPRIGHT", -1, -1, 0.5, 1, 0, 0.5 },
    { "BOTTOMLEFT", 1, 1, 0, 0.5, 0.5, 1 },
    { "BOTTOMRIGHT", -1, 1, 0.5, 1, 0.5, 1 },
}

-- A filled rectangle with rounded corners covering `frame`.
-- opts: layer, sublevel, inset (distance from the frame's edges), square
-- (set of corner names that stay square, e.g. { TOPRIGHT = true }).
function UI.Round(frame, token, radius, opts)
    opts = opts or {}
    local layer, sublevel = opts.layer or "BACKGROUND", opts.sublevel or 0
    local inset, r = opts.inset or 0, radius
    local shape = setmetatable({ parts = {}, inset = inset }, Shape)

    -- span: where the part lies inside the frame, for gradients. Each of
    -- left, right, top, bottom is { 0 or 1 (near or far edge), offset }.
    local function Part(left, right, top, bottom)
        local texture = frame:CreateTexture(nil, layer, nil, sublevel)
        texture.span = { left, right, top, bottom }
        shape.parts[#shape.parts + 1] = texture
        return texture
    end

    local nearA, nearB = { 0, inset }, { 0, inset + r }
    local farA, farB = { 1, -inset - r }, { 1, -inset }

    for _, c in ipairs(CORNERS) do
        local onLeft, onTop = c[2] > 0, c[3] < 0
        local corner = Part(
            onLeft and nearA or farA,
            onLeft and nearB or farB,
            onTop and nearA or farA,
            onTop and nearB or farB
        )
        corner:SetSize(r, r)
        corner:SetPoint(c[1], frame, c[1], c[2] * inset, c[3] * inset)
        if not (opts.square and opts.square[c[1]]) then
            corner.rounded = true
            corner:SetTexture(UI.media.circle)
            corner:SetTexCoord(c[4], c[5], c[6], c[7])
        end
    end

    local middle = Part(nearB, farA, nearA, farB)
    middle:SetPoint("TOPLEFT", frame, "TOPLEFT", inset + r, -inset)
    middle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset - r, inset)

    local left = Part(nearA, nearB, nearB, farA)
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset - r)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, inset + r)
    left:SetWidth(r)

    local right = Part(farA, farB, nearB, farA)
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -inset, -inset - r)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset, inset + r)
    right:SetWidth(r)

    shape:SetColor(token)
    return shape
end

-- A rounded card with a hairline border: the border colour fills the whole
-- shape and the (opaque) fill sits one pixel inside it.
function UI.Card(frame, fillToken, borderToken, radius, opts)
    opts = opts or {}
    local pixel = UI.Pixel(frame)
    local sublevel = opts.sublevel or 0
    local border = UI.Round(frame, borderToken, radius, {
        layer = opts.layer,
        sublevel = sublevel,
        square = opts.square,
    })
    local fill = UI.Round(frame, fillToken, math.max(1, radius - pixel), {
        layer = opts.layer,
        sublevel = sublevel + 1,
        inset = pixel,
        square = opts.square,
    })
    return { border = border, fill = fill }
end

-- Soft shadow around a frame, in eight pieces of shadow.tga. The frame
-- itself covers the middle. spread: how far it reaches beyond the edges.
-- With an accent token instead of "shadow" it is a glow. Returns a shape, so
-- it can be shown, hidden and faded.
function UI.Shadow(frame, spread, radius, drop, token)
    local size = spread + radius
    local pieces = {}
    local function Piece(l, r, t, b)
        local texture = frame:CreateTexture(nil, "BACKGROUND", nil, -8)
        texture:SetTexture(UI.media.shadow)
        texture:SetTexCoord(l, r, t, b)
        UI.Tint(texture, token or "shadow")
        pieces[#pieces + 1] = texture
        return texture
    end
    local y = -(drop or 0)

    local tl = Piece(0, 0.5, 0, 0.5)
    tl:SetSize(size, size)
    tl:SetPoint("TOPLEFT", frame, "TOPLEFT", -spread, spread + y)
    local tr = Piece(0.5, 1, 0, 0.5)
    tr:SetSize(size, size)
    tr:SetPoint("TOPRIGHT", frame, "TOPRIGHT", spread, spread + y)
    local bl = Piece(0, 0.5, 0.5, 1)
    bl:SetSize(size, size)
    bl:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -spread, -spread + y)
    local br = Piece(0.5, 1, 0.5, 1)
    br:SetSize(size, size)
    br:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", spread, -spread + y)

    local top = Piece(0.49, 0.51, 0, 0.5)
    top:SetPoint("TOPLEFT", tl, "TOPRIGHT")
    top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
    local bottom = Piece(0.49, 0.51, 0.5, 1)
    bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT")
    bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    local left = Piece(0, 0.5, 0.49, 0.51)
    left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT")
    left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
    local right = Piece(0.5, 1, 0.49, 0.51)
    right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT")
    right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
    return setmetatable({ parts = pieces }, Shape)
end

-- A round soft spot of light in a colour token, centred on `anchor`.
function UI.Halo(parent, anchor, size, token, layer)
    local halo = parent:CreateTexture(nil, layer or "BORDER")
    halo:SetTexture(UI.media.shadow)
    halo:SetSize(size, size)
    halo:SetPoint("CENTER", anchor, "CENTER")
    UI.Tint(halo, token)
    return halo
end

-- Fine noise over a ground, so that large plain areas do not look flat.
-- The texture repeats, one of its texels per screen pixel, so the grain is
-- crisp at every UI scale. left, top, right, bottom: distances from the
-- frame's edges; width, height: size of the frame.
local GRAIN_TEXELS = 128

-- fade: the grain thins out towards the bottom of its area.
function UI.Grain(frame, left, top, right, bottom, width, height, fade)
    local grain = frame:CreateTexture(nil, "BACKGROUND", nil, 4)
    grain:SetTexture(UI.media.grain, "REPEAT", "REPEAT")
    grain:SetPoint("TOPLEFT", frame, "TOPLEFT", left, -top)
    grain:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -right, bottom)
    local tile = GRAIN_TEXELS * UI.Pixel(frame)
    grain:SetTexCoord(0, (width - left - right) / tile, 0, (height - top - bottom) / tile)
    if fade then
        UI.Shade(grain, "VERTICAL", "grain", "grainEnd", { textured = true })
    else
        UI.Tint(grain, "grain")
    end
    return grain
end

-- Sparks: small glowing dots that rise, drift a little and fade, each in
-- its own rhythm. They are textures of `frame` (so they lie behind its
-- child frames) and are moved by the client's own animations; no Lua runs
-- per frame. left, width, height: the area they spread over, measured from
-- the frame's top left corner. Returns an object with :SetPlaying(bool).
function UI.Embers(frame, count, left, width, height, seed)
    local embers = { dots = {}, playing = false }
    -- Own little generator: the sparks sit in the same places every time.
    local state = seed
    local function Random()
        state = (state * 16807) % 2147483647
        return state / 2147483647
    end

    for i = 1, count do
        local dot = frame:CreateTexture(nil, "BORDER")
        dot:SetTexture(UI.media.shadow)
        local size = 5 + Random() * 8
        dot:SetSize(size, size)
        dot:SetPoint("CENTER", frame, "TOPLEFT", left + 10 + Random() * (width - 20), -(height * 0.18 + Random() * height * 0.78))
        UI.Tint(dot, "ember")
        dot:Hide()

        local duration = 5 + Random() * 6
        local rise, drift = 28 + Random() * 52, (Random() - 0.5) * 26
        local peak = 0.3 + Random() * 0.5

        local group = dot:CreateAnimationGroup()
        group:SetLooping("REPEAT")
        -- A pause of its own length first, so the sparks do not start together.
        local rest = group:CreateAnimation("Alpha")
        rest:SetFromAlpha(0)
        rest:SetToAlpha(0)
        rest:SetDuration(0.2 + Random() * 5)
        rest:SetOrder(1)
        -- Then it lights up quickly and dies away slowly while it rises.
        local function Phase(order, share, from, to)
            local fade = group:CreateAnimation("Alpha")
            fade:SetFromAlpha(from)
            fade:SetToAlpha(to)
            fade:SetDuration(duration * share)
            fade:SetOrder(order)
            local move = group:CreateAnimation("Translation")
            move:SetOffset(drift * share, rise * share)
            move:SetDuration(duration * share)
            move:SetOrder(order)
        end
        Phase(2, 0.3, 0, peak)
        Phase(3, 0.7, peak, 0)

        embers.dots[i] = { texture = dot, group = group }
    end

    function embers:SetPlaying(playing)
        playing = playing and true or false
        if playing == self.playing then
            return
        end
        self.playing = playing
        for _, dot in ipairs(self.dots) do
            dot.texture:SetShown(playing)
            if playing then
                dot.group:Play()
            else
                dot.group:Stop()
            end
        end
    end

    return embers
end

---------------------------------------------------------------------------
-- Toast: a small card that appears at the top of the screen for a few
-- seconds, e.g. when a companion reached something. Built on first use.
---------------------------------------------------------------------------

local TOAST_SECONDS = 6
local toast
local toastTurn = 0

function UI.Toast(title, detail)
    if not toast then
        toast = CreateFrame("Frame", nil, UIParent)
        toast:SetSize(340, 64)
        toast:SetFrameStrata("HIGH")
        toast:SetPoint("TOP", UIParent, "TOP", 0, -150)
        UI.Shadow(toast, 22, 12, 6)
        UI.Card(toast, "window", "cardBorder", 12)
        local picture = toast:CreateTexture(nil, "ARTWORK")
        picture:SetTexture(UI.media.logo)
        picture:SetSize(40, 40)
        picture:SetPoint("LEFT", 12, 0)
        toast.title = UI.Text(toast, 14, "text", "semibold")
        toast.title:SetPoint("TOPLEFT", picture, "TOPRIGHT", 10, -4)
        toast.title:SetPoint("RIGHT", toast, "RIGHT", -14, 0)
        toast.title:SetWordWrap(false)
        toast.detail = UI.Text(toast, 12, "textMuted")
        toast.detail:SetPoint("TOPLEFT", toast.title, "BOTTOMLEFT", 0, -4)
        toast.detail:SetPoint("RIGHT", toast, "RIGHT", -14, 0)
        toast.detail:SetWordWrap(false)
        toast:Hide()
    end
    toast.title:SetText(title or "")
    toast.detail:SetText(detail or "")
    toastTurn = toastTurn + 1
    local turn = toastTurn
    toast:SetAlpha(0)
    toast:Show()
    UI.Tween(toast, 0.2, function(progress)
        toast:SetAlpha(progress)
    end)
    -- A newer toast takes the card over; then this one must not hide it.
    C_Timer.After(TOAST_SECONDS, function()
        if turn ~= toastTurn then
            return
        end
        UI.Tween(toast, 0.4, function(progress)
            toast:SetAlpha(1 - progress)
            if progress >= 1 then
                toast:Hide()
            end
        end)
    end)
    return toast
end

---------------------------------------------------------------------------
-- Fills, lines, text, icons
---------------------------------------------------------------------------

function UI.Fill(frame, token, layer, sublevel)
    local texture = frame:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or 0)
    texture:SetAllPoints(frame)
    UI.Paint(texture, token)
    return texture
end

function UI.Line(frame, token)
    local line = frame:CreateTexture(nil, "BORDER")
    UI.Paint(line, token or "divider")
    line:SetHeight(UI.Pixel(frame))
    return line
end

function UI.VLine(frame, token)
    local line = frame:CreateTexture(nil, "BORDER")
    UI.Paint(line, token or "divider")
    line:SetWidth(UI.Pixel(frame))
    return line
end

-- Sets one of the window's fonts. SetFont returns false when the client
-- cannot load the file or has not loaded it yet (see the LOGIN handler in
-- UI/Theme.lua); a font string without a font would raise errors on
-- SetText, so it then gets the game's font instead.
function UI.SetFont(region, size, weight)
    if region:SetFont(UI.FontPath(weight), size, "") == false then
        region:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "")
    end
end

-- The game's own storybook font (the one of quest titles), for headings of
-- the chronicle. Taken from the client's font object, so every language gets
-- the file that has its glyphs; without it, the window's font.
function UI.SetDisplayFont(region, size)
    local source = QuestTitleFont
    local path = source and source.GetFont and source:GetFont()
    if type(path) ~= "string" or region:SetFont(path, size, "") == false then
        UI.SetFont(region, size, "semibold")
    end
end

-- weight: "regular" (default), "medium" or "semibold".
function UI.Text(parent, size, token, weight)
    local text = parent:CreateFontString(nil, "OVERLAY")
    UI.SetFont(text, size, weight)
    UI.Ink(text, token or "text")
    text:SetJustifyH("LEFT")
    text:SetJustifyV("TOP")
    return text
end

function UI.Icon(parent, media, size, token, layer)
    local icon = parent:CreateTexture(nil, layer or "ARTWORK")
    icon:SetTexture(UI.media[media])
    icon:SetSize(size, size)
    if token then
        UI.Tint(icon, token)
    end
    return icon
end

---------------------------------------------------------------------------
-- Button. variant: "primary" (accent), "secondary" (outlined) or "ghost"
-- (no ground until hovered). Optional icon in front of the label.
---------------------------------------------------------------------------

function UI.Button(parent, onClick, variant, icon)
    variant = variant or "secondary"
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(28)
    button.variant = variant

    local radius = variant == "primary" and 7 or 6
    local ground, face, rim
    if variant == "primary" then
        -- Depth without a bulge: a soft shadow below, a darker border, a
        -- light line just inside it, and the accent running left to right.
        local pixel = UI.Pixel(button)
        UI.Shadow(button, 6, radius, 2, "shadowSoft")
        ground = UI.Round(button, "accentEdge", radius)
        rim = UI.Round(button, "accentRim", math.max(1, radius - pixel), { sublevel = 1, inset = pixel })
        face = UI.Round(button, "accent", math.max(1, radius - pixel * 2), { sublevel = 2, inset = pixel * 2 })
    elseif variant == "secondary" then
        ground = UI.Card(button, "control", "controlBorder", radius)
    end
    local hover = UI.Round(button, variant == "primary" and "knob" or "hover", radius, { layer = "ARTWORK" })
    hover:SetColor(variant == "primary" and "knob" or "hover", variant == "primary" and 0.12 or 1)
    hover:Hide()

    local textToken = variant == "primary" and "onAccent" or (variant == "ghost" and "textDim" or "text")
    local label = UI.Text(button, 12, textToken, variant == "primary" and "semibold" or "medium")
    label:SetJustifyV("MIDDLE")
    button.label = label

    if icon then
        button.icon = UI.Icon(button, icon, 14, textToken)
    end

    local pushed = 0
    local function Layout()
        local labelWidth = label:GetStringWidth()
        local iconWidth = button.icon and 20 or 0
        local width = labelWidth + iconWidth
        if button.icon then
            button.icon:ClearAllPoints()
            button.icon:SetPoint("LEFT", button, "CENTER", -width / 2, -pushed)
            label:ClearAllPoints()
            label:SetPoint("LEFT", button.icon, "RIGHT", 6, 0)
        else
            label:ClearAllPoints()
            label:SetPoint("CENTER", 0, -pushed)
        end
    end

    function button:SetLabel(text)
        label:SetText(text)
        local padding = variant == "ghost" and 20 or 28
        local minimum = variant == "ghost" and 0 or 84
        local width = math.max(minimum, label:GetStringWidth() + (self.icon and 20 or 0) + padding)
        self:SetWidth(width)
        if face then
            -- The gradient needs the final size; it changes with the label.
            local height = self:GetHeight()
            rim:SetGradient("HORIZONTAL", "accentRim", "accentRim2", width, height)
            face:SetGradient("HORIZONTAL", "accent", "accent2", width, height)
        end
        Layout()
    end

    -- Colour of label and icon, e.g. "danger" while asking for confirmation.
    function button:SetTone(token)
        token = token or textToken
        UI.Ink(label, token)
        if self.icon then
            UI.Tint(self.icon, token)
        end
    end

    -- A disabled button is greyed out and ignores hover and clicks.
    function button:SetDisabled(disabled)
        disabled = disabled and true or false
        self.disabled = disabled
        self:SetAlpha(disabled and 0.4 or 1)
        if disabled then
            hover:Hide()
            pushed = 0
            Layout()
        end
    end

    button:SetScript("OnEnter", function(self)
        if not self.disabled then
            hover:Fade(true)
        end
    end)
    button:SetScript("OnLeave", function()
        hover:Fade(false)
    end)
    button:SetScript("OnMouseDown", function(self)
        if not self.disabled then
            pushed = 1
            Layout()
        end
    end)
    button:SetScript("OnMouseUp", function()
        pushed = 0
        Layout()
    end)
    button:SetScript("OnClick", function(self, ...)
        if not self.disabled then
            onClick(self, ...)
        end
    end)
    button.ground = ground
    return button
end

-- Small square button showing one of the media icons.
function UI.IconButton(parent, media, onClick, size)
    size = size or 26
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    local hover = UI.Round(button, "hover", 6)
    hover:Hide()
    local icon = UI.Icon(button, media, 14, "textMuted")
    icon:SetPoint("CENTER")
    button.icon = icon
    function button:SetIcon(name)
        icon:SetTexture(UI.media[name])
    end
    button:SetScript("OnEnter", function()
        hover:Fade(true)
        UI.Tint(icon, "text")
    end)
    button:SetScript("OnLeave", function()
        hover:Fade(false)
        UI.Tint(icon, "textMuted")
    end)
    button:SetScript("OnClick", onClick)
    return button
end

---------------------------------------------------------------------------
-- Toggle: a 34x20 pill with a sliding knob. Purely visual; the row that
-- owns it handles the click, so the whole row is the hit target.
---------------------------------------------------------------------------

local TOGGLE_W, TOGGLE_H, KNOB = 34, 20, 16
local KNOB_OFF, KNOB_ON = 2, TOGGLE_W - KNOB - 2

function UI.Toggle(parent)
    local toggle = CreateFrame("Frame", nil, parent)
    toggle:SetSize(TOGGLE_W, TOGGLE_H)

    local track = UI.Round(toggle, "track", TOGGLE_H / 2, { layer = "ARTWORK" })
    -- Switched on, the track runs through the accent and glows a little.
    local glow = UI.Shadow(toggle, 6, TOGGLE_H / 2, 0, "accentGlow")
    glow:Hide()

    local knobShadow = toggle:CreateTexture(nil, "OVERLAY", nil, 0)
    knobShadow:SetTexture(UI.media.circle)
    knobShadow:SetSize(KNOB + 2, KNOB + 2)
    knobShadow:SetVertexColor(0, 0, 0, 0.18)

    local knob = toggle:CreateTexture(nil, "OVERLAY", nil, 1)
    knob:SetTexture(UI.media.circle)
    knob:SetSize(KNOB, KNOB)
    UI.Tint(knob, "knob")

    local knobX

    local function PlaceKnob(x)
        knobX = x
        knob:SetPoint("LEFT", toggle, "LEFT", x, 0)
        knobShadow:SetPoint("CENTER", knob, "CENTER", 0, -1)
    end

    function toggle:Set(on, animate)
        on = on and true or false
        local changed = self.on ~= on
        self.on = on
        track:SetGradient("HORIZONTAL", on and "accent" or "track", on and "accent2" or "track", TOGGLE_W, TOGGLE_H)

        local target = on and KNOB_ON or KNOB_OFF
        if animate and changed and knobX then
            local from = knobX
            UI.Tween(self, 0.14, function(progress)
                PlaceKnob(from + (target - from) * progress)
            end)
            glow:Fade(on)
        else
            UI.CancelTween(self)
            PlaceKnob(target)
            glow:SetShown(on)
        end
    end

    return toggle
end

---------------------------------------------------------------------------
-- Colour swatches: one dot per accent; the chosen one wears a ring.
---------------------------------------------------------------------------

local SWATCH, SWATCH_GAP = 18, 10

function UI.Swatches(parent, onSelect)
    local group = CreateFrame("Frame", nil, parent)
    group:SetHeight(SWATCH + 8)
    group.dots = {}

    function group:SetValues(values, current)
        for i, value in ipairs(values) do
            local dot = self.dots[i]
            if not dot then
                dot = CreateFrame("Button", nil, self)
                dot:SetSize(SWATCH + 8, SWATCH + 8)
                dot.ring = dot:CreateTexture(nil, "ARTWORK", nil, 0)
                dot.ring:SetTexture(UI.media.circle)
                dot.ring:SetAllPoints()
                dot.gap = dot:CreateTexture(nil, "ARTWORK", nil, 1)
                dot.gap:SetTexture(UI.media.circle)
                dot.gap:SetPoint("TOPLEFT", 2, -2)
                dot.gap:SetPoint("BOTTOMRIGHT", -2, 2)
                UI.Tint(dot.gap, "card")
                dot.fill = dot:CreateTexture(nil, "ARTWORK", nil, 2)
                dot.fill:SetTexture(UI.media.circle)
                dot.fill:SetPoint("TOPLEFT", 4, -4)
                dot.fill:SetPoint("BOTTOMRIGHT", -4, 4)
                dot:SetScript("OnClick", function(d)
                    onSelect(d.value)
                end)
                dot:SetScript("OnEnter", function(d)
                    if not d.selected then
                        d.ring:SetVertexColor(UI.Color("track"))
                        d.ring:Show()
                    end
                end)
                dot:SetScript("OnLeave", function(d)
                    d.ring:SetShown(d.selected)
                    d.ring:SetVertexColor(UI.AccentSwatch(d.value))
                end)
                self.dots[i] = dot
            end
            dot.value = value
            dot.selected = value == current
            dot.fill:SetVertexColor(UI.AccentSwatch(value))
            dot.ring:SetVertexColor(UI.AccentSwatch(value))
            dot.ring:SetShown(dot.selected)
            dot:ClearAllPoints()
            dot:SetPoint("LEFT", self, "LEFT", (i - 1) * (SWATCH + SWATCH_GAP), 0)
            dot:Show()
        end
        self:SetWidth(#values * (SWATCH + SWATCH_GAP) - SWATCH_GAP + 8)
    end

    return group
end

---------------------------------------------------------------------------
-- Dropdown: a value box plus one shared popup menu.
---------------------------------------------------------------------------

local DROPDOWN_W, MENU_ROW, MENU_PAD = 160, 28, 4
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
    UI.Shadow(menu, 14, 8, 3)
    UI.Card(menu, "card", "cardBorder", 8)
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
    row:SetPoint("TOPLEFT", MENU_PAD, -(index - 1) * MENU_ROW - MENU_PAD)
    row:SetPoint("TOPRIGHT", -MENU_PAD, -(index - 1) * MENU_ROW - MENU_PAD)
    local hover = UI.Round(row, "hover", 5)
    hover:Hide()
    row.hover = hover
    row.text = UI.Text(row, 12, "text", "medium")
    row.text:SetPoint("LEFT", 10, 0)
    row.text:SetJustifyV("MIDDLE")
    row.check = UI.Icon(row, "check", 14, "accent")
    row.check:SetPoint("RIGHT", -8, 0)
    row:SetScript("OnEnter", function()
        hover:Fade(true)
    end)
    row:SetScript("OnLeave", function()
        hover:Fade(false)
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
        local selected = values[i].value == current
        row.value = values[i].value
        row.text:SetText(values[i].text)
        UI.Ink(row.text, selected and "accent" or "text")
        row.check:SetShown(selected)
        row.hover:Hide() -- a fade from the last time the menu was open
        row:Show()
    end
    for i = #values + 1, #menu.rows do
        menu.rows[i]:Hide()
    end
    -- The menu hangs off UIParent; give it the size of the scaled window.
    menu:SetScale(owner:GetEffectiveScale() / UIParent:GetEffectiveScale())
    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", owner, "BOTTOMRIGHT", 0, -4)
    menu:SetSize(owner:GetWidth(), #values * MENU_ROW + MENU_PAD * 2)
    catcher:Show()
    menu:Show()
end

function UI.Dropdown(parent)
    local dropdown = CreateFrame("Frame", nil, parent)
    dropdown:SetSize(DROPDOWN_W, 28)
    UI.Card(dropdown, "control", "controlBorder", 6)

    local chevron = UI.Icon(dropdown, "chevron", 12, "textMuted")
    chevron:SetPoint("RIGHT", -10, 0)

    local text = UI.Text(dropdown, 12, "text", "medium")
    text:SetPoint("LEFT", 12, 0)
    text:SetPoint("RIGHT", chevron, "LEFT", -6, 0)
    text:SetWordWrap(false)
    text:SetJustifyV("MIDDLE")
    dropdown.text = text
    return dropdown
end

---------------------------------------------------------------------------
-- Text fields
---------------------------------------------------------------------------

-- Shared body of the search box and the input: a rounded field whose border
-- takes the accent colour while it has the focus.
local function Field(parent, height, radius, maxLetters, leftInset, rightInset)
    local box = CreateFrame("Frame", nil, parent)
    box:SetHeight(height)
    -- Soft ring in the accent colour around the field that has the focus.
    local ring = UI.Round(box, "accentSoft", radius + 3, { sublevel = -1, inset = -3 })
    ring:Hide()
    local card = UI.Card(box, "field", "controlBorder", radius)

    local edit = CreateFrame("EditBox", nil, box)
    edit:SetPoint("TOPLEFT", leftInset, 0)
    edit:SetPoint("BOTTOMRIGHT", -rightInset, 0)
    edit:SetAutoFocus(false)
    UI.SetFont(edit, 12, "regular")
    edit:SetTextColor(UI.Color("text"))
    edit:SetMaxLetters(maxLetters or 40)
    box.edit = edit

    local placeholder = UI.Text(box, 12, "textMuted")
    placeholder:SetPoint("LEFT", leftInset, 0)
    placeholder:SetPoint("RIGHT", -8, 0) -- a long hint is cut off inside the field
    placeholder:SetWordWrap(false)
    placeholder:SetJustifyV("MIDDLE")
    box.placeholder = placeholder

    edit:SetScript("OnEditFocusGained", function()
        card.border:SetColor("accent")
        ring:Fade(true)
    end)
    edit:SetScript("OnEditFocusLost", function()
        card.border:SetColor("controlBorder")
        ring:Fade(false)
    end)
    box:SetScript("OnMouseDown", function()
        edit:SetFocus()
    end)
    -- Edit boxes keep their own text colour; follow the theme by hand.
    ns:On("THEME_CHANGED", function()
        edit:SetTextColor(UI.Color("text"))
    end)
    return box, edit, placeholder
end

function UI.SearchBox(parent, onChange)
    local box, edit, placeholder = Field(parent, 32, 8, 40, 32, 28)

    local icon = UI.Icon(box, "search", 14, "textMuted")
    icon:SetPoint("LEFT", 11, 0)

    -- Clears the field and ends the search; only there while there is text.
    local clear = UI.IconButton(box, "close", function()
        edit:SetText("")
        edit:ClearFocus()
    end, 22)
    clear:SetPoint("RIGHT", -5, 0)
    clear:Hide()
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
    return box
end

-- Text input with a placeholder. The owner sets input.onEnter and
-- input.onTab; Escape gives the focus back.
function UI.Input(parent, maxLetters)
    local box, edit, placeholder = Field(parent, 32, 7, maxLetters, 12, 12)

    edit:SetScript("OnTextChanged", function(self)
        placeholder:SetShown((self:GetText() or "") == "")
    end)
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    edit:SetScript("OnEnterPressed", function()
        if box.onEnter then
            box.onEnter()
        end
    end)
    edit:SetScript("OnTabPressed", function()
        if box.onTab then
            box.onTab()
        end
    end)
    return box
end

---------------------------------------------------------------------------
-- Tabs: labels in a row with an accent bar under the chosen one. The bar
-- slides to a newly chosen tab.
---------------------------------------------------------------------------

local TAB_GAP = 22

function UI.Tabs(parent, onSelect)
    local tabs = CreateFrame("Frame", nil, parent)
    tabs:SetHeight(34)
    tabs.buttons = {}

    local baseline = UI.Line(tabs, "divider")
    baseline:SetPoint("BOTTOMLEFT")
    baseline:SetPoint("BOTTOMRIGHT")

    -- The bar runs through the accent and throws a little light upwards.
    local bar = CreateFrame("Frame", nil, tabs)
    bar:SetHeight(2)
    local stroke = bar:CreateTexture(nil, "OVERLAY")
    stroke:SetAllPoints(bar)
    UI.Shade(stroke, "HORIZONTAL", "accent", "accent2")
    UI.Shadow(bar, 7, 1, 0, "accentGlow")
    tabs.bar = bar
    local barX, barW

    local function PlaceBar(x, w)
        barX, barW = x, w
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOMLEFT", tabs, "BOTTOMLEFT", x, 0)
        bar:SetWidth(math.max(1, w))
    end

    -- list: array of { id = ..., text = "...", dim = bool }
    function tabs:SetTabs(list, selected, animate)
        local x = 0
        local targetX, targetW
        for i, entry in ipairs(list) do
            local button = self.buttons[i]
            if not button then
                button = CreateFrame("Button", nil, self)
                button:SetHeight(34)
                button.label = UI.Text(button, 13, "textMuted", "medium")
                button.label:SetPoint("LEFT", 0, 1)
                button.label:SetJustifyV("MIDDLE")
                button:SetScript("OnClick", function(b)
                    onSelect(b.id)
                end)
                button:SetScript("OnEnter", function(b)
                    if not b.selected then
                        UI.Ink(b.label, "text")
                    end
                end)
                button:SetScript("OnLeave", function(b)
                    UI.Ink(b.label, b.selected and "text" or "textMuted")
                end)
                self.buttons[i] = button
            end
            button.id = entry.id
            button.selected = entry.id == selected
            button.label:SetText(entry.text)
            button.label:SetAlpha(entry.dim and 0.5 or 1)
            UI.Ink(button.label, button.selected and "text" or "textMuted")
            local w = button.label:GetStringWidth()
            button:SetWidth(w)
            button:ClearAllPoints()
            button:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", x, 0)
            button:Show()
            if button.selected then
                targetX, targetW = x, w
            end
            x = x + w + TAB_GAP
        end
        for i = #list + 1, #self.buttons do
            self.buttons[i]:Hide()
        end
        bar:SetShown(targetX ~= nil)
        if not targetX then
            return
        end
        if animate and barX and (barX ~= targetX or barW ~= targetW) then
            local fromX, fromW = barX, barW
            UI.Tween(bar, 0.18, function(p)
                PlaceBar(fromX + (targetX - fromX) * p, fromW + (targetW - fromW) * p)
            end)
        else
            UI.CancelTween(bar)
            PlaceBar(targetX, targetW)
        end
    end

    return tabs
end

---------------------------------------------------------------------------
-- Scroll area with a slim rounded position indicator
---------------------------------------------------------------------------

local WHEEL_STEP = 48

function UI.Scroll(parent)
    local scroll = CreateFrame("ScrollFrame", nil, parent)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(1, 1)
    scroll:SetScrollChild(content)
    scroll.content = content

    local thumb = CreateFrame("Frame", nil, parent)
    thumb:SetWidth(4)
    UI.Round(thumb, "thumb", 2, { layer = "OVERLAY" })
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
        thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", 12, -offset)
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
