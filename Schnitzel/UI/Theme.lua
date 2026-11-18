-- Look of the settings window: palettes, accent colours, fonts, media paths
-- and a tiny tween driver.
--
-- Colours are named tokens ("card", "text", "accent", ...). Widgets never
-- set a colour directly; they paint a region with a token (UI.Paint,
-- UI.Tint, UI.Ink). The painted regions are remembered in a weak table, so
-- switching between light and dark or picking another accent repaints the
-- open window at once, without a reload.

local ADDON_NAME, ns = ...

local UI = {}
ns.UI = UI

local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
UI.media = {
    circle = MEDIA .. "circle.tga",
    chevron = MEDIA .. "chevron.tga",
    close = MEDIA .. "close.tga",
    check = MEDIA .. "check.tga",
    search = MEDIA .. "search.tga",
    info = MEDIA .. "info.tga",
    reset = MEDIA .. "reset.tga",
    sun = MEDIA .. "sun.tga",
    moon = MEDIA .. "moon.tga",
    gear = MEDIA .. "gear.tga",
    sparkle = MEDIA .. "sparkle.tga",
    tag = MEDIA .. "tag.tga",
    shadow = MEDIA .. "shadow.tga",
    logo = MEDIA .. "logo.tga",
}

---------------------------------------------------------------------------
-- Fonts: Inter in three weights. Clients whose own texts need glyphs that
-- Inter lacks (Korean, Chinese) keep the game's font.
---------------------------------------------------------------------------

local FONT_DIR = MEDIA .. "Fonts\\"
UI.fonts = {
    regular = FONT_DIR .. "Inter-Regular.ttf",
    medium = FONT_DIR .. "Inter-Medium.ttf",
    semibold = FONT_DIR .. "Inter-SemiBold.ttf",
}

local GAME_FONT_LOCALES = { koKR = true, zhCN = true, zhTW = true }

function UI.FontPath(weight)
    if GAME_FONT_LOCALES[GetLocale and GetLocale() or ""] then
        return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    end
    return UI.fonts[weight or "regular"] or UI.fonts.regular
end

---------------------------------------------------------------------------
-- Palettes. Grounds are opaque; "hover" and "pressed" are washes laid over
-- them. Accent-derived tokens (accent, accentSoft, onAccent) come from the
-- chosen accent and depend on the palette as well.
---------------------------------------------------------------------------

local function hex(value, alpha)
    local r = tonumber(value:sub(1, 2), 16) / 255
    local g = tonumber(value:sub(3, 4), 16) / 255
    local b = tonumber(value:sub(5, 6), 16) / 255
    return { r, g, b, alpha or 1 }
end

local palettes = {
    dark = {
        window = hex("15171c"),
        sidebar = hex("101215"),
        card = hex("1c1f25"),
        cardBorder = hex("292d35"),
        control = hex("23272e"),
        controlBorder = hex("343943"),
        field = hex("121418"),
        inset = hex("121418"),
        divider = hex("262a31"),
        text = hex("eceef2"),
        textDim = hex("b4bac5"),
        textMuted = hex("7d8492"),
        track = hex("3a3f4a"),
        knob = hex("ffffff"),
        hover = { 1, 1, 1, 0.045 },
        pressed = { 1, 1, 1, 0.08 },
        thumb = { 1, 1, 1, 0.18 },
        shadow = { 0, 0, 0, 0.55 },
        warning = hex("f5b14c"),
        danger = hex("f06a6a"),
    },
    light = {
        window = hex("f3f4f7"),
        sidebar = hex("e9ebf0"),
        card = hex("ffffff"),
        cardBorder = hex("dfe2e8"),
        control = hex("ffffff"),
        controlBorder = hex("d3d7df"),
        field = hex("ffffff"),
        inset = hex("eceef2"),
        divider = hex("eceef2"),
        text = hex("161920"),
        textDim = hex("3d4350"),
        textMuted = hex("6b7280"),
        track = hex("cfd4dc"),
        knob = hex("ffffff"),
        hover = { 0, 0, 0, 0.035 },
        pressed = { 0, 0, 0, 0.06 },
        thumb = { 0, 0, 0, 0.18 },
        shadow = { 0, 0, 0, 0.22 },
        warning = hex("b7791f"),
        danger = hex("d64545"),
    },
}

-- Each accent has a shade for each palette, chosen so that text in the
-- accent colour stays readable on the cards.
local accents = {
    amber = { dark = "f2a93b", light = "d4850f", onDark = "1a1206", onLight = "ffffff" },
    blue = { dark = "5b9bff", light = "2f6feb", onDark = "08142b", onLight = "ffffff" },
    green = { dark = "3ec38f", light = "1a9466", onDark = "06190f", onLight = "ffffff" },
    violet = { dark = "9a8cff", light = "6a5af0", onDark = "120d2b", onLight = "ffffff" },
    rose = { dark = "f2668f", light = "d93d6a", onDark = "2b0812", onLight = "ffffff" },
}

UI.themes = { "dark", "light" }
UI.accents = { "amber", "blue", "green", "violet", "rose" }

local colors = {}
UI.colors = colors

-- Fills `colors` for a palette and accent; returns true if anything changed.
local currentTheme, currentAccent
local function Compose(theme, accent)
    theme = palettes[theme] and theme or "dark"
    accent = accents[accent] and accent or "amber"
    if theme == currentTheme and accent == currentAccent then
        return false
    end
    currentTheme, currentAccent = theme, accent
    for token, value in pairs(palettes[theme]) do
        colors[token] = value
    end
    local shades = accents[accent]
    local base = hex(theme == "dark" and shades.dark or shades.light)
    colors.accent = base
    colors.accentSoft = { base[1], base[2], base[3], theme == "dark" and 0.16 or 0.12 }
    colors.accentLine = { base[1], base[2], base[3], 0.55 }
    colors.onAccent = hex(theme == "dark" and shades.onDark or shades.onLight)
    UI.isDark = theme == "dark"
    return true
end
Compose("dark", "amber")

function UI.Color(name)
    local c = colors[name] or colors.text
    return c[1], c[2], c[3], c[4]
end

-- Colour of an accent swatch, independent of the chosen accent.
function UI.AccentSwatch(accent)
    local shades = accents[accent] or accents.amber
    local c = hex(UI.isDark and shades.dark or shades.light)
    return c[1], c[2], c[3], 1
end

---------------------------------------------------------------------------
-- Painting. mode: "fill" (SetColorTexture), "tint" (SetVertexColor on an
-- image) or "ink" (SetTextColor). alpha multiplies the token's alpha.
---------------------------------------------------------------------------

local painted = setmetatable({}, { __mode = "k" })

local function Apply(region, entry)
    local r, g, b, a = UI.Color(entry.token)
    a = a * entry.alpha
    if entry.mode == "fill" then
        region:SetColorTexture(r, g, b, a)
    elseif entry.mode == "tint" then
        region:SetVertexColor(r, g, b, a)
    else
        region:SetTextColor(r, g, b, a)
    end
end

local function Paint(mode, region, token, alpha)
    local entry = painted[region]
    if not entry then
        entry = {}
        painted[region] = entry
    end
    entry.mode, entry.token, entry.alpha = mode, token, alpha or 1
    Apply(region, entry)
end

function UI.Paint(texture, token, alpha)
    Paint("fill", texture, token, alpha)
end

function UI.Tint(texture, token, alpha)
    Paint("tint", texture, token, alpha)
end

function UI.Ink(fontString, token, alpha)
    Paint("ink", fontString, token, alpha)
end

-- Follows the saved theme and accent; repaints everything that was painted.
function UI.ApplyTheme()
    if not Compose(ns:GetOption("general", "theme"), ns:GetOption("general", "accent")) then
        return
    end
    for region, entry in pairs(painted) do
        Apply(region, entry)
    end
    ns:Fire("THEME_CHANGED")
end

ns:On("OPTION_CHANGED", function(section, key)
    if section == "general" and (key == "theme" or key == "accent") then
        UI.ApplyTheme()
    end
end)
ns:On("PROFILE_CHANGED", UI.ApplyTheme)
ns:On("DATABASE_READY", UI.ApplyTheme)

-- Size of one physical screen pixel in the frame's coordinates, so hairlines
-- stay crisp at every UI scale.
function UI.Pixel(frame)
    if PixelUtil and PixelUtil.GetNearestPixelSize then
        return PixelUtil.GetNearestPixelSize(1, frame:GetEffectiveScale(), 1)
    end
    return 1
end

---------------------------------------------------------------------------
-- Tweens. The driver frame is hidden (and therefore costs nothing) whenever
-- no animation is running.
---------------------------------------------------------------------------

local driver = CreateFrame("Frame")
driver:Hide()
local tweens = {}

driver:SetScript("OnUpdate", function(_, elapsed)
    for i = #tweens, 1, -1 do
        local tween = tweens[i]
        tween.elapsed = tween.elapsed + elapsed
        local progress = tween.elapsed / tween.duration
        if progress >= 1 then
            progress = 1
            table.remove(tweens, i)
        end
        local rest = 1 - progress
        tween.fn(1 - rest * rest * rest) -- ease out
    end
    if #tweens == 0 then
        driver:Hide()
    end
end)

-- fn(progress) is called every frame with progress easing from 0 to 1.
-- A new tween for the same key replaces the running one.
function UI.CancelTween(key)
    for i = #tweens, 1, -1 do
        if tweens[i].key == key then
            table.remove(tweens, i)
        end
    end
end

function UI.Tween(key, duration, fn)
    UI.CancelTween(key)
    tweens[#tweens + 1] = { key = key, elapsed = 0, duration = duration, fn = fn }
    driver:Show()
end
