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
    -- Reactions to a friend's event (ChronicleService.REACTION_SETS).
    sad = MEDIA .. "sad.tga",
    cheer = MEDIA .. "cheer.tga",
    strong = MEDIA .. "strong.tga",
    clap = MEDIA .. "clap.tga",
    heart = MEDIA .. "heart.tga",
    fire = MEDIA .. "fire.tga",
    -- Icons of the entries in the settings tabs (feature.icon and others).
    share = MEDIA .. "share.tga",
    bell = MEDIA .. "bell.tga",
    chat = MEDIA .. "chat.tga",
    shield = MEDIA .. "shield.tga",
    tooltip = MEDIA .. "tooltip.tga",
    menu = MEDIA .. "menu.tga",
    link = MEDIA .. "link.tga",
    trash = MEDIA .. "trash.tga",
    globe = MEDIA .. "globe.tga",
    compass = MEDIA .. "compass.tga",
    person = MEDIA .. "person.tga",
    drop = MEDIA .. "drop.tga",
    resize = MEDIA .. "resize.tga",
    clock = MEDIA .. "clock.tga",
    calendar = MEDIA .. "calendar.tga",
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
-- Lines and borders are a little darker than the darker of the two grounds
-- they part, never lighter: they read like a soft groove, not a bright edge.
local ladder = {
    sidebar = { 0.070, 1 },
    window = { 0.092, 1 },
    windowBorder = { 0.054, 1 }, -- outline and the lines of head and sidebar
    card = { 0.125, 1 },
    cardBorder = { 0.074, 1 }, -- a card on the window; the line below the tabs
    control = { 0.150, 1 },
    controlBorder = { 0.105, 1 }, -- a button or picture on a card
    field = { 0.055, 1 },
    fieldBorder = { 0.045, 1 },
    inset = { 0.055, 1 },
    divider = { 0.090, 1 }, -- lines inside a card
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
    shareInk = hex("7cc4ff"), -- what goes to other players (the welcome page)
    -- The pictures of the settings (UI/Previews.lua) show the game, not the
    -- window, in the game's own colours: chat, tooltip, menu, Battle.net,
    -- the minimap, the classes. Their night sky follows the scheme (see
    -- Compose).
    sceneCaption = { 0, 0, 0, 0.42 },
    chatBox = { 0, 0, 0, 0.38 },
    chatGuild = { 0.25, 1, 0.25, 1 },
    chatParty = { 0.667, 0.667, 1, 1 },
    chatSystem = { 1, 1, 0, 1 },
    chatWhite = { 1, 1, 1, 1 },
    chatFamulus = hex("ffb347"), -- the prefix of the addon's own lines (Core/Init.lua)
    tooltipFill = { 0.035, 0.04, 0.1, 0.95 },
    tooltipBorder = hex("5d6470"),
    tooltipLabel = { 0.61, 0.64, 0.73, 1 }, -- as Modules/Aliases/TooltipAliases.lua writes "Alias"
    tooltipGuild = hex("8ef08e"),
    menuTitle = { 1, 0.82, 0, 1 },
    bnetBlue = { 0.51, 0.77, 1, 1 },
    bnetFill = { 0.04, 0.06, 0.1, 0.94 },
    bnetBorder = { 0.51, 0.77, 1, 0.25 },
    bnetChip = { 0.51, 0.77, 1, 0.12 },
    bnetGrey = { 0.54, 0.6, 0.66, 1 },
    guildyFill = { 0.055, 0.063, 0.08, 0.94 },
    guildyBorder = { 1, 1, 1, 0.12 },
    guildyHead = hex("e9d9a8"),
    minimapGround = hex("3a5246"),
    minimapLand = { 0.42, 0.49, 0.29, 0.7 },
    minimapWater = { 0.17, 0.26, 0.33, 0.8 },
    minimapRim = hex("8a7a55"),
    gameClassWARRIOR = hex("c69b6d"),
    gameClassPALADIN = hex("f48cba"),
    gameClassHUNTER = hex("aad372"),
    gameClassROGUE = hex("fff468"),
    gameClassPRIEST = hex("ffffff"),
    gameClassSHAMAN = hex("0070dd"),
    gameClassMAGE = hex("3fc7eb"),
    gameClassWARLOCK = hex("8788ee"),
    gameClassDRUID = hex("ff7c0a"),
    -- The window's own words for classes and factions (UI.Colored): the
    -- game's colours at about half their saturation and of like lightness,
    -- so that none outshines the accent. The priest's white would be the
    -- text's, so ivory.
    classWARRIOR = hex("b9a692"),
    classPALADIN = hex("d396b1"),
    classHUNTER = hex("adc093"),
    classROGUE = hex("d7d288"),
    classPRIEST = hex("dedacf"),
    classSHAMAN = hex("5f95ca"),
    classMAGE = hex("7fb9c9"),
    classWARLOCK = hex("9696cf"),
    classDRUID = hex("ce9a6c"),
    factionHorde = hex("c7837f"),
    factionAlliance = hex("829ac8"),
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
    -- The night sky of the settings' pictures, as on the website (styles.css:
    -- --sky-top, --sky-low on a dusk, --moon-mid, --moon-rim, --moon-blue).
    local hue, saturation = scheme.hue, scheme.saturation
    colors.skyTop = hsl(hue, math.min(1, saturation * 1.9), 0.04)
    colors.skyLow = mix(hsl(hue, math.min(1, saturation * 2), 0.17), base, 0.12)
    colors.star = alpha(hsl(hue, math.min(1, saturation * 0.9), 0.945), 1) -- animations set its opacity
    colors.moonRim = mix(base, WHITE, 0.38)
    colors.moonMid = mix(bright, WHITE, 0.5)
    colors.moonCore = { 1, 1, 1, 0.75 }
    colors.moonHalo = alpha(bright, 0.3)
    colors.moonGlow = alpha(base, 0.16)
    colors.moonBlue = hsl(hue + 18, 0.46, 0.78)
    colors.moonBlueHalo = alpha(colors.moonBlue, 0.35)
    -- Every scheme in small, whichever is chosen: the picture of the choice.
    for id, each in pairs(accents) do
        colors["schemeWindow_" .. id] = hsl(each.hue, each.saturation, ladder.window[1])
        colors["schemeCard_" .. id] = hsl(each.hue, each.saturation, ladder.card[1])
        colors["schemeTrack_" .. id] = hsl(each.hue, each.saturation * ladder.track[2], ladder.track[1])
        colors["schemeAccent_" .. id] = hex(each.tones[1])
        colors["schemeAccent2_" .. id] = hex(each.tones[2])
    end
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

-- The window paints thousands of regions with a few dozen colours, so a
-- region does not get a record of its own: it points to the one record of its
-- mode, token and alpha, and a level for fading (UI.SetLevel) is kept apart,
-- only while it is not 1. A record per region would cost about 0.2 KB each,
-- a good part of the window's memory.
local painted = setmetatable({}, { __mode = "k" }) -- region -> shared record
local levels = setmetatable({}, { __mode = "k" }) -- painted region -> level other than 1
local shaded = setmetatable({}, { __mode = "k" }) -- textures with a gradient, see UI.Shade
local records = {} -- mode -> token -> alpha -> { mode, token, alpha }

local function Record(mode, token, alpha)
    local byToken = records[mode]
    if not byToken then
        byToken = {}
        records[mode] = byToken
    end
    local byAlpha = byToken[token]
    if not byAlpha then
        byAlpha = {}
        byToken[token] = byAlpha
    end
    local record = byAlpha[alpha]
    if not record then
        record = { mode = mode, token = token, alpha = alpha }
        byAlpha[alpha] = record
    end
    return record
end

local function Apply(region, entry)
    local r, g, b, a = UI.Color(entry.token)
    a = a * entry.alpha * (levels[region] or 1)
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
        levels[region] = nil
        region:SetVertexColor(1, 1, 1, 1)
    end
    -- A level set while it was painted stays.
    local entry = Record(mode, token, alpha or 1)
    painted[region] = entry
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

-- A word in its own colour within a line ("Mage" in "Mage · Guild"), as the
-- game's colour code. Only for fixed tokens (classes, factions): a word
-- written this way does not follow a change of scheme. Without a word, nil.
function UI.Colored(token, text)
    if text == nil or text == "" then
        return text
    end
    local r, g, b = UI.Color(token)
    return string.format("|cff%02x%02x%02x%s|r", math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5), text)
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
    painted[texture], levels[texture] = nil, nil
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
        if (levels[region] or 1) ~= level then
            levels[region] = level ~= 1 and level or nil
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
