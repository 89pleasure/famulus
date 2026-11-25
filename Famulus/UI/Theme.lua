-- Look of the settings window: colour schemes, fonts, media paths and a tiny
-- tween driver.
--
-- Colours are named tokens ("card", "text", "accent", ...). Widgets never
-- set a colour directly; they paint a region with a token (UI.Paint,
-- UI.Tint, UI.Ink) or shade it between two tokens (UI.Shade). The regions
-- are remembered in weak tables, so picking another scheme repaints the open
-- window at once, without a reload.

local ADDON_NAME, ns = ...

local UI = {}
ns.UI = UI

local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
-- Icons of the game, for the pictures of the chronicle: one per kind of
-- event, used where an event brings no icon of its own (an item's, a
-- spell's, a profession's). The self-test checks that the client has them.
local ICONS = "Interface\\Icons\\"
UI.gameIcons = {
    level = ICONS .. "Spell_Holy_GreaterBlessingofKings", -- the number stands on it
    death = ICONS .. "INV_Misc_Bone_HumanSkull_01",
    boss = ICONS .. "Ability_DualWield",
    zone = ICONS .. "INV_Misc_Map_01",
    achievement = ICONS .. "Spell_Holy_ChampionsBond",
    profession = ICONS .. "Trade_BlackSmithing",
    ability = ICONS .. "Spell_Nature_Swiftness",
    item = ICONS .. "INV_Misc_Bag_08",
}

UI.media = {
    circle = MEDIA .. "circle.tga",
    ring = MEDIA .. "ring.tga",
    chevron = MEDIA .. "chevron.tga",
    close = MEDIA .. "close.tga",
    check = MEDIA .. "check.tga",
    search = MEDIA .. "search.tga",
    info = MEDIA .. "info.tga",
    reset = MEDIA .. "reset.tga",
    gear = MEDIA .. "gear.tga",
    sparkle = MEDIA .. "sparkle.tga",
    tag = MEDIA .. "tag.tga",
    flag = MEDIA .. "flag.tga",
    people = MEDIA .. "people.tga",
    skull = MEDIA .. "skull.tga",
    swords = MEDIA .. "swords.tga",
    peaks = MEDIA .. "peaks.tga",
    star = MEDIA .. "star.tga",
    hammer = MEDIA .. "hammer.tga",
    horseshoe = MEDIA .. "horseshoe.tga",
    chest = MEDIA .. "chest.tga",
    -- Reactions to a friend's event (ChronicleService.REACTIONS).
    sad = MEDIA .. "sad.tga",
    cheer = MEDIA .. "cheer.tga",
    strong = MEDIA .. "strong.tga",
    clap = MEDIA .. "clap.tga",
    shadow = MEDIA .. "shadow.tga",
    grain = MEDIA .. "grain.tga",
    logo = MEDIA .. "logo.tga",
    logoRound = MEDIA .. "logo-round.tga",
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
-- Colours. A colour scheme ("accent") is a whole concept, not just one
-- colour: it tints every ground with its own hue and brings an accent that
-- runs from a base tone into a brighter one. The window is dark; there is
-- no light version.
--
-- Grounds are opaque and come from one lightness ladder, in the scheme's
-- hue; "hover", "pressed" and the like are washes laid over them.
---------------------------------------------------------------------------

local function hex(value, alpha)
    local r = tonumber(value:sub(1, 2), 16) / 255
    local g = tonumber(value:sub(3, 4), 16) / 255
    local b = tonumber(value:sub(5, 6), 16) / 255
    return { r, g, b, alpha or 1 }
end

-- hue in degrees, saturation and lightness 0..1
local function hsl(hue, saturation, lightness)
    local function channel(n)
        local k = (n + hue / 30) % 12
        local a = saturation * math.min(lightness, 1 - lightness)
        return lightness - a * math.max(-1, math.min(k - 3, 9 - k, 1))
    end
    return { channel(0), channel(8), channel(4), 1 }
end

local function mix(from, to, amount)
    return {
        from[1] + (to[1] - from[1]) * amount,
        from[2] + (to[2] - from[2]) * amount,
        from[3] + (to[3] - from[3]) * amount,
        1,
    }
end

local function alpha(color, value)
    return { color[1], color[2], color[3], value }
end

local WHITE, BLACK = { 1, 1, 1, 1 }, { 0, 0, 0, 1 }

-- Lightness of each ground and text level, and how much of the scheme's
-- saturation it takes ({ lightness, share }).
local ladder = {
    sidebar = { 0.070, 1 },
    window = { 0.092, 1 },
    card = { 0.125, 1 },
    cardBorder = { 0.185, 0.9 },
    control = { 0.150, 1 },
    controlBorder = { 0.230, 0.9 },
    field = { 0.055, 1 },
    inset = { 0.055, 1 },
    divider = { 0.160, 0.9 },
    track = { 0.240, 0.9 },
    text = { 0.945, 0.9 },
    textDim = { 0.740, 0.5 },
    textMuted = { 0.535, 0.42 },
}

-- Washes and fixed colours, the same in every scheme.
local washes = {
    knob = hex("ffffff"),
    hover = { 1, 1, 1, 0.045 },
    pressed = { 1, 1, 1, 0.08 },
    chip = { 1, 1, 1, 0.06 },
    thumb = { 1, 1, 1, 0.18 },
    sheen = { 1, 1, 1, 0.10 }, -- light catching the top edge of the window
    sheenSoft = { 1, 1, 1, 0.06 }, -- the same on a card
    sunken = { 0, 0, 0, 0.16 }, -- rows that lie deeper in their card
    grain = { 1, 1, 1, 0.03 }, -- noise over the grounds
    grainEnd = { 1, 1, 1, 0 }, -- where it fades out
    dusk = { 0, 0, 0, 0.22 }, -- the grounds grow darker towards the bottom
    clear = { 0, 0, 0, 0 },
    shadow = { 0, 0, 0, 0.55 },
    shadowSoft = { 0, 0, 0, 0.45 },
    -- Pictures of the chronicle: a death and a defeated foe have their own tones.
    deathGround = hex("2a2226"),
    deathLine = hex("40333a"),
    deathInk = hex("c8a9b3"),
    bossGround = hex("2e2416"),
    bossLine = hex("f2a93b", 0.5),
    bossInk = hex("f2c36a"),
    warning = hex("f5b14c"),
    danger = hex("f06a6a"),
}

-- hue and saturation tint the grounds; tones are the accent's base tone, its
-- brighter end and the colour of text on it.
local accents = {
    lemon = { hue = 190, saturation = 0.19, tones = { "f2d640", "fff29a", "2a2404" } },
    mint = { hue = 226, saturation = 0.30, tones = { "35d3bf", "92f0a8", "04211d" } },
    rose = { hue = 330, saturation = 0.13, tones = { "f0567c", "ff9d8c", "2b0711" } },
    lilac = { hue = 240, saturation = 0.19, tones = { "8f7cff", "e08cff", "120b33" } },
    amber = { hue = 257, saturation = 0.13, tones = { "f2a93b", "ffd670", "1a1206" } },
}

UI.accents = { "lemon", "mint", "rose", "lilac", "amber" }
local DEFAULT_ACCENT = "lemon"

local colors = {}
UI.colors = colors

-- Fills the colour table for a scheme; returns true if anything changed.
local currentAccent
local function Compose(accent)
    accent = accents[accent] and accent or DEFAULT_ACCENT
    if accent == currentAccent then
        return false
    end
    currentAccent = accent
    local scheme = accents[accent]

    for token, step in pairs(ladder) do
        colors[token] = hsl(scheme.hue, scheme.saturation * step[2], step[1])
    end
    for token, value in pairs(washes) do
        colors[token] = value
    end

    local base, bright = hex(scheme.tones[1]), hex(scheme.tones[2])
    colors.accent = base
    colors.accent2 = bright
    colors.onAccent = hex(scheme.tones[3])
    colors.accentSoft = alpha(base, 0.16)
    colors.accentLine = alpha(base, 0.55)
    colors.accentGlow = alpha(base, 0.45) -- halo around what is switched on
    colors.accentHaze = alpha(base, 0.20) -- the glow behind the logo
    colors.accentFade = alpha(base, 0.22) -- chosen entry in the sidebar ...
    colors.accentFadeEnd = alpha(base, 0.04) -- ... fading out to the right
    colors.accentEdge = mix(base, BLACK, 0.38) -- border of a filled button
    colors.accentRim = mix(base, WHITE, 0.30) -- light line just inside that border
    colors.accentRim2 = mix(bright, WHITE, 0.30)
    colors.ember = alpha(bright, 1) -- rising sparks; their animation sets the opacity
    colors.accentDeep = mix(base, BLACK, 0.80) -- ground of a picture in the chronicle
    colors.accentTrail = alpha(base, 0.28) -- the line the chronicle's events hang on
    colors.accentNone = alpha(base, 0) -- where an accent line fades out
    colors.cardActive = alpha(base, 0.26) -- border of a card that stands out (a milestone, the chosen one)
    return true
end
Compose(DEFAULT_ACCENT)

function UI.Color(name)
    local c = colors[name] or colors.text
    return c[1], c[2], c[3], c[4]
end

-- Colour of a scheme's swatch, independent of the chosen scheme.
function UI.AccentSwatch(accent)
    local scheme = accents[accent] or accents[DEFAULT_ACCENT]
    local c = hex(scheme.tones[1])
    return c[1], c[2], c[3], 1
end

---------------------------------------------------------------------------
-- Painting. mode: "fill" (SetColorTexture), "tint" (SetVertexColor on an
-- image) or "ink" (SetTextColor). alpha multiplies the token's alpha.
---------------------------------------------------------------------------

local painted = setmetatable({}, { __mode = "k" })
local shaded = setmetatable({}, { __mode = "k" }) -- textures with a gradient, see UI.Shade

local function Apply(region, entry)
    local r, g, b, a = UI.Color(entry.token)
    a = a * entry.alpha * (entry.level or 1)
    if entry.mode == "fill" then
        region:SetColorTexture(r, g, b, a)
    elseif entry.mode == "tint" then
        region:SetVertexColor(r, g, b, a)
    elseif entry.mode == "swipe" then
        region:SetSwipeColor(r, g, b, a)
    else
        region:SetTextColor(r, g, b, a)
    end
end

local function Paint(mode, region, token, alpha)
    if shaded[region] then
        -- A gradient lives in the vertex colours; a plain fill must clear it.
        shaded[region] = nil
        region:SetVertexColor(1, 1, 1, 1)
    end
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

-- The swipe of a Cooldown frame, which has no vertex colour of its own.
function UI.Swipe(cooldown, token, alpha)
    Paint("swipe", cooldown, token, alpha)
end

function UI.Ink(fontString, token, alpha)
    Paint("ink", fontString, token, alpha)
end

local function ApplyShade(texture, entry)
    local r1, g1, b1, a1 = UI.Color(entry.from)
    local r2, g2, b2, a2 = UI.Color(entry.to)
    local function At(position)
        return CreateColor(
            r1 + (r2 - r1) * position,
            g1 + (g2 - g1) * position,
            b1 + (b2 - b1) * position,
            (a1 + (a2 - a1) * position) * entry.alpha * (entry.level or 1)
        )
    end
    if entry.textured then
        texture:SetVertexColor(1, 1, 1, 1)
    else
        texture:SetColorTexture(1, 1, 1, 1)
    end
    if entry.vertical then
        -- The client shades from the bottom up; ours runs from the top down.
        texture:SetGradient("VERTICAL", At(entry.stop), At(entry.start))
    else
        texture:SetGradient("HORIZONTAL", At(entry.start), At(entry.stop))
    end
end

-- Shades a texture from one colour token into another: "HORIZONTAL" from
-- left to right, "VERTICAL" from top to bottom. Follows the theme like
-- UI.Paint does.
-- opts: start, stop (the part of the whole gradient this texture shows,
-- 0..1; for shapes made of several textures), alpha, textured (an image
-- instead of a plain fill).
function UI.Shade(texture, orientation, fromToken, toToken, opts)
    opts = opts or {}
    if not (texture.SetGradient and CreateColor) then
        -- No gradient support: the base tone alone.
        Paint(opts.textured and "tint" or "fill", texture, fromToken, opts.alpha)
        return
    end
    painted[texture] = nil
    local entry = shaded[texture]
    if not entry then
        entry = {}
        shaded[texture] = entry
    end
    entry.vertical = orientation == "VERTICAL"
    entry.from, entry.to = fromToken, toToken
    entry.start, entry.stop = opts.start or 0, opts.stop or 1
    entry.alpha = opts.alpha or 1
    entry.textured = opts.textured and true or false
    ApplyShade(texture, entry)
end

-- Opacity of a painted or shaded region on top of its colour's own alpha,
-- for fading. Not SetAlpha: on a texture that shares the vertex alpha with
-- SetVertexColor, so it would overwrite the alpha of a tinted image.
function UI.SetLevel(region, level)
    local entry = painted[region]
    if entry then
        if (entry.level or 1) ~= level then
            entry.level = level
            Apply(region, entry)
        end
        return
    end
    entry = shaded[region]
    if entry and (entry.level or 1) ~= level then
        entry.level = level
        ApplyShade(region, entry)
    end
end

-- Follows the saved scheme; repaints everything that was painted.
function UI.ApplyTheme()
    if not Compose(ns:GetOption("general", "accent")) then
        return
    end
    for region, entry in pairs(painted) do
        Apply(region, entry)
    end
    for texture, entry in pairs(shaded) do
        ApplyShade(texture, entry)
    end
    ns:Fire("THEME_CHANGED")
end

ns:On("OPTION_CHANGED", function(section, key)
    if section == "general" and key == "accent" then
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
