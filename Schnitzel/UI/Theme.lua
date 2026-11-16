-- Look of the settings window: palette, fonts, media paths and a tiny tween
-- driver. Flat fills, hairline borders, one warm accent colour.

local ADDON_NAME, ns = ...

local UI = {}
ns.UI = UI

local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
UI.media = {
    circle = MEDIA .. "circle.tga",
    chevron = MEDIA .. "chevron.tga",
    close = MEDIA .. "close.tga",
    logo = MEDIA .. "logo.tga",
}

UI.font = STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"

-- Grounds are opaque colours; lines and states are translucent white
-- "washes" on top of them, so they work on every ground.
local colors = {
    window = { 0.086, 0.098, 0.141, 1 },
    sidebar = { 0.063, 0.072, 0.106, 1 },
    panel = { 0.108, 0.123, 0.174, 1 },
    control = { 0.145, 0.162, 0.221, 1 },
    footer = { 0.071, 0.081, 0.118, 1 },
    field = { 0, 0, 0, 0.30 },

    text = { 0.95, 0.96, 0.98, 1 },
    textDim = { 0.84, 0.86, 0.92, 1 },
    textMuted = { 0.70, 0.73, 0.81, 1 },

    accent = { 0.96, 0.70, 0.33, 1 },
    onAccent = { 0.10, 0.08, 0.05, 1 },
    warning = { 0.98, 0.75, 0.30, 1 },

    -- Outer window frame, shading from top to bottom.
    frameTop = { 0.93, 0.68, 0.34, 1 },
    frameBottom = { 0.36, 0.22, 0.15, 1 },

    border = { 1, 1, 1, 0.10 },
    divider = { 1, 1, 1, 0.06 },
    hover = { 1, 1, 1, 0.05 },
    selected = { 1, 1, 1, 0.09 },
    track = { 1, 1, 1, 0.14 },
    thumb = { 1, 1, 1, 0.22 },
}
UI.colors = colors

function UI.Color(name)
    local c = colors[name]
    return c[1], c[2], c[3], c[4]
end

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
