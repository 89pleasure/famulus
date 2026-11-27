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
    for index, part in ipairs(self.parts) do
        -- Each end of a part is { 0 or 1 (near or far edge), offset from it }.
        local span = self.spans[index]
        local near = span[vertical and 3 or 1]
        local far = span[vertical and 4 or 2]
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

-- Where each of the seven parts of a rounded shape lies inside its frame, for
-- gradients: the four corners (in the order of CORNERS), the middle, the left
-- and the right side. Each is { left, right, top, bottom }, and each of those
-- { 0 or 1 (near or far edge), offset }. They depend only on inset and radius,
-- so all shapes of the same size share them instead of a table per texture.
local spansBySize = {} -- inset -> radius -> spans

local function Spans(inset, r)
    local byRadius = spansBySize[inset]
    if not byRadius then
        byRadius = {}
        spansBySize[inset] = byRadius
    end
    local spans = byRadius[r]
    if not spans then
        local nearA, nearB = { 0, inset }, { 0, inset + r }
        local farA, farB = { 1, -inset - r }, { 1, -inset }
        spans = {}
        for index, c in ipairs(CORNERS) do
            local onLeft, onTop = c[2] > 0, c[3] < 0
            spans[index] = {
                onLeft and nearA or farA,
                onLeft and nearB or farB,
                onTop and nearA or farA,
                onTop and nearB or farB,
            }
        end
        spans[5] = { nearB, farA, nearA, farB } -- middle
        spans[6] = { nearA, nearB, nearB, farA } -- left
        spans[7] = { farA, farB, nearB, farA } -- right
        byRadius[r] = spans
    end
    return spans
end

-- A filled rectangle with rounded corners covering `frame`.
-- opts: layer, sublevel, inset (distance from the frame's edges), square
-- (set of corner names that stay square, e.g. { TOPRIGHT = true }).
function UI.Round(frame, token, radius, opts)
    opts = opts or {}
    local layer, sublevel = opts.layer or "BACKGROUND", opts.sublevel or 0
    local inset, r = opts.inset or 0, radius
    -- The parts are created in the order of Spans.
    local shape = setmetatable({ parts = {}, inset = inset, spans = Spans(inset, r) }, Shape)

    local function Part()
        local texture = frame:CreateTexture(nil, layer, nil, sublevel)
        shape.parts[#shape.parts + 1] = texture
        return texture
    end

    for _, c in ipairs(CORNERS) do
        local corner = Part()
        corner:SetSize(r, r)
        corner:SetPoint(c[1], frame, c[1], c[2] * inset, c[3] * inset)
        if not (opts.square and opts.square[c[1]]) then
            corner.rounded = true
            corner:SetTexture(UI.media.circle)
            corner:SetTexCoord(c[4], c[5], c[6], c[7])
        end
    end

    local middle = Part()
    middle:SetPoint("TOPLEFT", frame, "TOPLEFT", inset + r, -inset)
    middle:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -inset - r, inset)

    local left = Part()
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", inset, -inset - r)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", inset, inset + r)
    left:SetWidth(r)

    local right = Part()
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

-- A glowing dot in the accent, as the window marks what is alive or worth a
-- look: the dots on the book's line, the head of a card of the live feed. The
-- dot (`size` across) with its glow, three times as large; both are textures
-- of `parent`, the glow a layer below the dot. Place the dot, and the glow
-- follows. UI.SetDot changes the size or shows and hides both.
local DOT_GLOW = 3
local DOT_LAYERS = { BACKGROUND = "BACKGROUND", BORDER = "BACKGROUND", ARTWORK = "BORDER", OVERLAY = "ARTWORK" }

function UI.GlowDot(parent, size, layer)
    layer = layer or "ARTWORK"
    local dot = UI.Icon(parent, "circle", size, "accent", layer)
    dot.glow = UI.Halo(parent, dot, size * DOT_GLOW, "accentGlow", DOT_LAYERS[layer] or "BORDER")
    return dot
end

-- size: a new size, or nil to keep it; shown: true or false, or nil to leave it.
function UI.SetDot(dot, size, shown)
    if size then
        dot:SetSize(size, size)
        dot.glow:SetSize(size * DOT_GLOW, size * DOT_GLOW)
    end
    if shown ~= nil then
        dot:SetShown(shown)
        dot.glow:SetShown(shown)
    end
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
-- Fonts load lazily (as FlareUI found out): the client reads a font file
-- only when visible text asks for it; until then SetFont returns false and
-- the string keeps its old font (a new one has none, and SetText on it
-- throws). Once the file is in, the string switches by itself, but text
-- drawn before can stay blank; setting the same font again does nothing, a
-- size change and back draws it anew. So a string waits on the game's font
-- and is asked again until the client says yes, then redrawn.
local RETRY_SECONDS, RETRY_TICKS = 0.5, 120
local pending = setmetatable({}, { __mode = "k" }) -- font string -> { path, size }
local retryTicker, retryTicks
-- path -> true once the client said yes, false while strings wait (self-test)
UI.fontLoaded = {}

local function RetryFonts()
    retryTicks = retryTicks + 1
    for region, want in pairs(pending) do
        if region:SetFont(want.path, want.size, "") ~= false then
            pending[region] = nil
            UI.fontLoaded[want.path] = true
            region:SetFont(want.path, want.size + 1, "")
            region:SetFont(want.path, want.size, "")
        end
    end
    if not next(pending) or retryTicks >= RETRY_TICKS then
        retryTicker:Cancel()
        retryTicker = nil
    end
end

-- Asks again for strings still waiting, e.g. when the window opens after
-- the retries gave up (a hidden string's request loads nothing).
function UI.RetryFonts()
    if next(pending) and not retryTicker then
        retryTicks = 0
        retryTicker = C_Timer.NewTicker(RETRY_SECONDS, RetryFonts)
    end
end

local function ApplyFont(region, path, size)
    pending[region] = nil
    if region:SetFont(path, size, "") ~= false then
        UI.fontLoaded[path] = true
        return
    end
    region:SetFont(STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF", size, "")
    region:SetFont(path, size, "")
    pending[region] = { path = path, size = size }
    UI.fontLoaded[path] = UI.fontLoaded[path] or false
    UI.RetryFonts()
end

function UI.SetFont(region, size, weight)
    ApplyFont(region, UI.FontPath(weight), size)
end

-- The game's own storybook font (the one of quest titles), for headings of
-- the chronicle. Taken from the client's font object, so every language gets
-- the file that has its glyphs; without it, the window's font.
function UI.SetDisplayFont(region, size)
    local source = QuestTitleFont
    local path = source and source.GetFont and source:GetFont()
    if type(path) == "string" then
        ApplyFont(region, path, size)
    else
        UI.SetFont(region, size, "semibold")
    end
end

-- One of the game's fonts, named by its font object ("ChatFontNormal",
-- "GameTooltipText"), for pictures of the game (UI/Previews.lua); the
-- client has them loaded from the start. Without it, the window's font.
function UI.SetGameFont(region, object, size)
    local source = _G[object]
    local path = type(source) == "table" and source.GetFont and source:GetFont()
    if type(path) == "string" then
        ApplyFont(region, path, size)
    else
        UI.SetFont(region, size, "medium")
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

-- The game's tooltip with one line, the name of a button that shows only its
-- icon (button.tip); hidden again when the mouse leaves.
local function ShowTip(button)
    if button.tip then
        GameTooltip:SetOwner(button, "ANCHOR_TOP")
        GameTooltip:SetText(button.tip, 1, 1, 1)
        GameTooltip:Show()
    end
end

local function HideTip(button)
    if GameTooltip.IsOwned and GameTooltip:IsOwned(button) then
        GameTooltip:Hide()
    end
end

-- For buttons built elsewhere (the window's tabs): the same tooltip.
UI.ShowTip, UI.HideTip = ShowTip, HideTip

---------------------------------------------------------------------------
-- Button. variant: "primary" (accent), "secondary" (outlined) or "ghost"
-- (no ground until hovered). Optional icon in front of the label.
-- button:SetIconOnly(size) makes it a square with the icon alone; the label
-- then names it in a tooltip under the mouse.
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
        if button.iconOnly then
            button.icon:ClearAllPoints()
            button.icon:SetPoint("CENTER", 0, -pushed)
        elseif button.icon then
            button.icon:ClearAllPoints()
            button.icon:SetPoint("LEFT", button, "CENTER", -width / 2, -pushed)
            label:ClearAllPoints()
            label:SetPoint("LEFT", button.icon, "RIGHT", 6, 0)
        else
            label:ClearAllPoints()
            label:SetPoint("CENTER", 0, -pushed)
        end
    end

    -- button.padding: room left and right of the label together, for a
    -- larger button than the usual.
    function button:SetLabel(text)
        label:SetText(text)
        local padding = self.padding or (variant == "ghost" and 20 or 28)
        local minimum = variant == "ghost" and 0 or 84
        local width = math.max(minimum, label:GetStringWidth() + (self.icon and 20 or 0) + padding)
        if self.iconOnly then
            width, self.tip = self.iconOnly, text
        end
        self:SetWidth(width)
        if face then
            -- The gradient needs the final size; it changes with the label.
            local height = self:GetHeight()
            rim:SetGradient("HORIZONTAL", "accentRim", "accentRim2", width, height)
            face:SetGradient("HORIZONTAL", "accent", "accent2", width, height)
        end
        Layout()
    end

    -- A square of `size` with the icon alone (the button needs one; iconSize
    -- 16 unless given); call it before SetLabel, which then names the button
    -- in its tooltip.
    function button:SetIconOnly(size, iconSize)
        self.iconOnly = size
        self:SetSize(size, size)
        self.icon:SetSize(iconSize or 16, iconSize or 16)
        label:Hide()
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
        ShowTip(self)
    end)
    button:SetScript("OnLeave", function(self)
        hover:Fade(false)
        HideTip(self)
    end)
    -- A click that hides it (forget, a page change) takes its tooltip along.
    button:HookScript("OnHide", HideTip)
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

-- Small square button showing one of the media icons; button.tip names it in
-- a tooltip under the mouse.
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
    button:SetScript("OnEnter", function(self)
        hover:Fade(true)
        UI.Tint(icon, "text")
        ShowTip(self)
    end)
    button:SetScript("OnLeave", function(self)
        hover:Fade(false)
        UI.Tint(icon, "textMuted")
        HideTip(self)
    end)
    button:HookScript("OnHide", HideTip)
    button:SetScript("OnClick", onClick)
    return button
end

-- The button of a reaction, as the live feed's cards and the chronicle's book
-- show it: a small rounded square with the reaction's icon, muted until it is
-- given (or, on the player's own event, received), then in the accent on an
-- accent ground, like a lit chip. With a count it widens and says how many.
-- What it does is its owner's: the scripts, `button.over` while the mouse is
-- on it, and button:Paint() after that changes.
--   button:Set(icon, lit, count) -- "cheer", true or false, a number or nil
local REACTION_PAD, REACTION_COUNT_GAP = 7, 4

function UI.ReactionButton(parent, size, iconSize)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(size, size)
    button.size = size
    button.ground = UI.Card(button, "control", "controlBorder", 8)
    button.hover = UI.Round(button, "hover", 8, { layer = "ARTWORK" })
    button.hover:Hide()
    button.icon = UI.Icon(button, "cheer", iconSize, "textMuted", "OVERLAY")
    button.iconSize = iconSize
    button.count = UI.Text(button, 11, "textMuted", "semibold")
    button.count:SetWordWrap(false)
    button.count:Hide()

    function button:Set(icon, lit, count)
        self.reactionIcon, self.lit = icon, lit and true or false
        local counted = (tonumber(count) or 0) > 0
        self.count:SetShown(counted)
        self.count:SetText(counted and tostring(count) or "")
        self.icon:ClearAllPoints()
        if counted then
            self.icon:SetPoint("LEFT", self, "LEFT", REACTION_PAD, 0)
            self.count:ClearAllPoints()
            self.count:SetPoint("LEFT", self.icon, "RIGHT", REACTION_COUNT_GAP, 0)
            local width = REACTION_PAD + self.iconSize + REACTION_COUNT_GAP + self.count:GetStringWidth() + REACTION_PAD + 1
            self:SetWidth(math.max(self.size, math.ceil(width)))
        else
            self.icon:SetPoint("CENTER")
            self:SetWidth(self.size)
        end
        self:Paint()
    end

    function button:Paint()
        self.ground.fill:SetColor(self.lit and "accentDeep" or "control")
        self.ground.border:SetColor(self.lit and "accentLine" or "controlBorder")
        self.icon:SetTexture(UI.media[self.reactionIcon] or UI.media.cheer)
        local ink = self.lit and "accent" or self.over and "text" or "textMuted"
        UI.Tint(self.icon, ink)
        UI.Ink(self.count, ink)
    end
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
-- Pill: a short label on a tinted ground, e.g. whether a setting is on and
-- what its default is. Lit, it takes the accent.
---------------------------------------------------------------------------

function UI.Pill(parent)
    local pill = CreateFrame("Frame", nil, parent)
    pill:SetHeight(22)
    pill.ground = UI.Round(pill, "chip", 6)
    pill.text = UI.Text(pill, 11, "textDim", "medium")
    pill.text:SetPoint("LEFT", 8, 0)
    pill.text:SetJustifyV("MIDDLE")
    pill.text:SetWordWrap(false)

    function pill:Set(text, lit)
        self.text:SetText(text)
        self.ground:SetColor(lit and "accentSoft" or "chip")
        UI.Ink(self.text, lit and "accent" or "textDim")
        self:SetWidth(math.floor(self.text:GetStringWidth() + 16.5))
    end
    return pill
end

---------------------------------------------------------------------------
-- Chip: one switch of a group of alike switches (e.g. the kinds of events
-- the live feed shows), with an icon in front. Lit while on. The owner
-- sets chip.onEnter and chip.onLeave to explain it somewhere.
---------------------------------------------------------------------------

local CHIP_H, CHIP_RADIUS = 34, 7

function UI.Chip(parent, onClick)
    local chip = CreateFrame("Button", nil, parent)
    chip:SetHeight(CHIP_H)
    local pixel = UI.Pixel(chip)
    chip.card = UI.Card(chip, "control", "controlBorder", CHIP_RADIUS)
    chip.lit = UI.Round(chip, "accentSoft", CHIP_RADIUS - pixel, { sublevel = 2, inset = pixel })
    chip.lit:Hide()
    local hover = UI.Round(chip, "hover", CHIP_RADIUS, { sublevel = 3 })
    hover:Hide()

    chip.icon = UI.Icon(chip, "circle", 14, "textMuted")
    chip.icon:SetPoint("LEFT", 11, 0)
    chip.label = UI.Text(chip, 12, "textDim", "medium")
    chip.label:SetPoint("LEFT", chip.icon, "RIGHT", 8, 0)
    chip.label:SetPoint("RIGHT", -8, 0)
    chip.label:SetWordWrap(false)
    chip.label:SetJustifyV("MIDDLE")

    -- icon: a name from UI.media.
    function chip:Set(label, icon, on, disabled)
        on, disabled = on and true or false, disabled and true or false
        self.label:SetText(label)
        self.icon:SetTexture(UI.media[icon] or UI.media.circle)
        self.on, self.disabled = on, disabled
        self.lit:SetShown(on)
        self.card.border:SetColor(on and "accentLine" or "controlBorder")
        UI.Tint(self.icon, on and "accent" or "textMuted")
        UI.Ink(self.label, on and "text" or "textDim")
        self:SetAlpha(disabled and 0.45 or 1)
        if disabled then
            hover:Hide()
        end
    end

    chip:SetScript("OnEnter", function(self)
        if not self.disabled then
            hover:Fade(true)
        end
        if self.onEnter then
            self.onEnter(self)
        end
    end)
    chip:SetScript("OnLeave", function(self)
        hover:Fade(false)
        if self.onLeave then
            self.onLeave(self)
        end
    end)
    chip:SetScript("OnClick", function(self)
        if not self.disabled then
            onClick(self)
        end
    end)
    return chip
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
    local card = UI.Card(box, "field", "fieldBorder", radius)

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
        card.border:SetColor("fieldBorder")
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

---------------------------------------------------------------------------
-- Fellow travellers: crest, bond badge and bond ladder
---------------------------------------------------------------------------

-- The first letter of a name (UTF-8 aware), upper case.
function UI.Initial(text)
    local first = string.match(text or "", "^[%z\1-\127\194-\244][\128-\191]*") or "?"
    return ns.Upper(first)
end

local CLASS_ICONS = "Interface\\TargetingFrame\\UI-Classes-Circles"

-- The game's round class icon, hidden until a class is set (UI.SetClass).
function UI.ClassIcon(parent, size, layer)
    local icon = parent:CreateTexture(nil, layer or "ARTWORK")
    icon:SetTexture(CLASS_ICONS)
    icon:SetSize(size, size)
    icon:Hide()
    return icon
end

-- Shows a class ("MAGE") on such an icon. False, and the icon hidden, for a
-- class the client has no icon for or none at all: then the initial stands.
function UI.SetClass(icon, classFile)
    local coords = type(classFile) == "string" and CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile] or nil
    icon:SetShown(coords ~= nil)
    if coords then
        icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    end
    return coords ~= nil
end

-- A person's crest: the game's class icon (else the initial) on a disc,
-- inside a ring that shows the way to the next bond tier. The ring is a
-- paused Cooldown swipe: drawn once, nothing runs per frame. Without
-- Cooldown:Pause it is a plain full ring.
function UI.Crest(parent, size)
    local crest = CreateFrame("Frame", nil, parent)
    crest:SetSize(size, size)
    local inner = math.floor(size * 0.74 + 0.5)

    local disc = UI.Icon(crest, "circle", inner, "chip", "BACKGROUND")
    disc:SetPoint("CENTER")
    crest.icon = UI.ClassIcon(crest, inner)
    crest.icon:SetPoint("CENTER")
    crest.initial = UI.Text(crest, math.floor(size * 0.36), "textDim", "semibold")
    crest.initial:SetPoint("CENTER")
    crest.initial:SetJustifyH("CENTER")
    crest.initial:SetJustifyV("MIDDLE")

    local track = UI.Icon(crest, "ring", size, "track", "BORDER")
    track:SetPoint("CENTER")
    local swipe = CreateFrame("Cooldown", nil, crest)
    swipe:SetAllPoints(crest)
    swipe.noCooldownCount = true -- OmniCC and the like: no countdown on the ring
    crest.ringShown = swipe.Pause ~= nil and swipe.SetSwipeTexture ~= nil
    if crest.ringShown then
        swipe:SetSwipeTexture(UI.media.ring)
        swipe:SetDrawEdge(false)
        swipe:SetDrawBling(false)
        swipe:SetHideCountdownNumbers(true)
        swipe:SetReverse(true) -- the swipe paints the part that has passed
        UI.Swipe(swipe, "accent")
    else
        swipe:Hide()
        UI.Tint(track, "accentLine")
    end
    crest.swipe = swipe

    function crest:SetPerson(name, classFile)
        local known = UI.SetClass(self.icon, classFile)
        self.initial:SetShown(not known)
        if not known then
            self.initial:SetText(UI.Initial(name))
        end
    end

    -- progress: 0..1 of the way to the next tier.
    function crest:SetProgress(progress)
        -- A cooldown at its end draws nothing; the top tier stays just short of it.
        progress = math.max(0, math.min(0.999, progress or 0))
        if not self.ringShown then
            return
        end
        self.swipe.progress = progress
        if progress <= 0 then
            self.swipe:Clear()
            return
        end
        -- 100 seconds of which `progress` have passed, then held still.
        self.swipe:SetCooldown(GetTime() - progress * 100, 100)
        self.swipe:Pause()
    end
    return crest
end

-- The bond tier's name on a small plate: accent from Trusted on, muted below.
function UI.TierBadge(parent)
    local badge = CreateFrame("Frame", nil, parent)
    badge:SetHeight(18)
    badge.plate = UI.Round(badge, "chip", 9)
    badge.text = UI.Text(badge, 10, "textMuted", "semibold")
    badge.text:SetPoint("CENTER")
    badge.text:SetJustifyV("MIDDLE")
    function badge:SetTier(tier)
        local high = tier >= 3
        self.text:SetText(ns.L["ui_bond_" .. tier])
        UI.Ink(self.text, high and "accent" or "textMuted")
        self.plate:SetColor(high and "accentSoft" or "chip")
        self:SetWidth(self.text:GetStringWidth() + 16)
    end
    return badge
end

-- The way to the next bond tier: the tier you stand at on the left, the next
-- one on the right, below them three segments for the three steps up,
-- filled as far as you have come. At the top tier all three are full.
local TIER_SEGMENT_H, TIER_SEGMENT_GAP = 6, 4

function UI.TierBar(parent, width)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(width, 20 + TIER_SEGMENT_H)
    bar.current = UI.Text(bar, 12, "textDim", "semibold")
    bar.current:SetPoint("TOPLEFT")
    bar.next = UI.Text(bar, 12, "textMuted")
    bar.next:SetPoint("TOPRIGHT")
    bar.next:SetJustifyH("RIGHT")
    local segmentWidth = (width - TIER_SEGMENT_GAP * 2) / 3
    bar.segments = {}
    for index = 1, 3 do
        local segment = CreateFrame("Frame", nil, bar)
        segment:SetSize(segmentWidth, TIER_SEGMENT_H)
        segment:SetPoint("BOTTOMLEFT", (index - 1) * (segmentWidth + TIER_SEGMENT_GAP), 0)
        UI.Round(segment, "track", TIER_SEGMENT_H / 2)
        segment.fill = CreateFrame("Frame", nil, segment)
        segment.fill:SetPoint("TOPLEFT")
        segment.fill:SetPoint("BOTTOMLEFT")
        UI.Round(segment.fill, "accent", TIER_SEGMENT_H / 2)
        bar.segments[index] = segment
    end
    function bar:SetTier(tier, progress)
        self.current:SetText(ns.L["ui_bond_" .. tier])
        UI.Ink(self.current, tier >= 3 and "accent" or "textDim")
        self.next:SetText(tier < 4 and ns.L["ui_bond_" .. (tier + 1)] or "")
        for index, segment in ipairs(self.segments) do
            -- Segment n is the step from tier n to n + 1.
            local share = index < tier and 1 or index == tier and progress or 0
            segment.share = share
            -- A sliver keeps its round ends: never narrower than it is high.
            segment.fill:SetWidth(math.max(TIER_SEGMENT_H, segmentWidth * share))
            segment.fill:SetShown(share > 0)
        end
    end
    return bar
end
