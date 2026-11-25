-- The live feed: cards that appear on screen for a few seconds when the
-- chronicle writes something down, and fade out again. Nothing exists until
-- the first card is shown, and nothing runs while none is on screen.
--
--   UI.Feed.Show(story, seconds)   -- story: as for the book (UI/Book.lua)
--   UI.Feed.SetMoving(true)        -- shows where the cards appear; drag to move
--
-- The cards do not catch the mouse. The place is saved account-wide in
-- FamulusDB.feed, like the window's.

local _, ns = ...
local UI = ns.UI
local L = ns.L

local Feed = {}
UI.Feed = Feed

-- A card is a crest on a band: the picture stands inside the band, a little
-- in from its left end. The band is as wide as its text needs.
local WIDTH, HEIGHT = 320, 64 -- the band; WIDTH is that of the mark for moving
local CREST = 48
local CREST_LEFT = 14 -- band visible left of the crest
local TEXT_LEFT = CREST_LEFT + CREST + 14
local TEXT_RIGHT = 22
local MIN_WIDTH, MAX_WIDTH = 230, 460
local GROUND_INSET = 3 -- keeps grain and dusk inside the rounded corners
local GRAIN_TEXELS = 128 -- size of grain.tga, as in UI.Grain
local GAP = 10 -- between two bands
local MAX_CARDS = 3
local FADE_IN, FADE_OUT = 0.25, 0.5
local DEFAULT_SECONDS = 7

local anchor
local pool, shown = {}, {} -- shown: the newest first
local moving = false

local function Place()
    anchor:ClearAllPoints()
    local saved = ns.global and ns.global.feed
    if type(saved) == "table" and type(saved.point) == "string" then
        anchor:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
    else
        anchor:SetPoint("TOP", UIParent, "TOP", 0, -150)
    end
end

local function Anchor()
    if not anchor then
        anchor = CreateFrame("Frame", nil, UIParent)
        anchor:SetSize(WIDTH, HEIGHT)
        anchor:SetFrameStrata("MEDIUM")
        anchor:SetClampedToScreen(true)
        anchor:SetMovable(true)
        Place()
    end
    return anchor
end

-- The cards hang below each other; while the place is shown, below its mark.
local function Layout()
    local y = moving and -(HEIGHT + GAP) or 0
    for _, card in ipairs(shown) do
        card:ClearAllPoints()
        -- Left edges in line, so the crests stand above each other.
        card:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, y)
        y = y - HEIGHT - GAP
    end
end

local function NewCard()
    local card = CreateFrame("Frame", nil, Anchor())
    card:SetSize(WIDTH, HEIGHT)
    UI.Shadow(card, 22, 10, 6)
    -- The band is built like the card of an option in the window, and
    -- carries the window's ground: grain that thins out downwards, and a
    -- little dusk towards the bottom.
    local pixel = UI.Pixel(card)
    card.shape = UI.Card(card, "card", "cardBorder", 10)
    local sheen = UI.Line(card, "sheenSoft")
    sheen:SetPoint("TOPLEFT", 10, -pixel)
    sheen:SetPoint("TOPRIGHT", -10, -pixel)
    local dusk = card:CreateTexture(nil, "BACKGROUND", nil, 3)
    dusk:SetPoint("TOPLEFT", card, "LEFT", GROUND_INSET, 0)
    dusk:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -GROUND_INSET, GROUND_INSET)
    UI.Shade(dusk, "VERTICAL", "clear", "dusk")
    card.grain = UI.Grain(card, GROUND_INSET, GROUND_INSET, GROUND_INSET, GROUND_INSET, WIDTH, HEIGHT, true)
    -- Mark of a milestone, as on the card of a feature that is switched on.
    card.mark = card:CreateTexture(nil, "BORDER")
    card.mark:SetPoint("TOPLEFT", 0, -12)
    card.mark:SetPoint("BOTTOMLEFT", 0, 12)
    card.mark:SetWidth(2)
    UI.Paint(card.mark, "accent")

    -- The crest: a frame of its own above the band, with a border two
    -- pixels strong in the colour of its kind.
    local crest = CreateFrame("Frame", nil, card)
    crest:SetSize(CREST, CREST)
    crest:SetPoint("LEFT", CREST_LEFT, 0)
    crest:SetFrameLevel(card:GetFrameLevel() + 2)
    card.crest = crest
    card.crestBorder = UI.Round(crest, "controlBorder", 6)
    card.crestFill = UI.Round(crest, "control", 4, { sublevel = 1, inset = 2 })
    card.icon = crest:CreateTexture(nil, "ARTWORK")
    card.icon:SetPoint("CENTER")
    card.icon:SetSize(CREST * 0.5, CREST * 0.5)
    card.photo = crest:CreateTexture(nil, "ARTWORK")
    card.photo:SetPoint("CENTER")
    card.photo:SetSize(CREST - 6, CREST - 6)
    card.photo:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    -- A number stands on its icon; the icon is dimmed for it.
    card.dim = crest:CreateTexture(nil, "ARTWORK", nil, 1)
    card.dim:SetAllPoints(card.photo)
    UI.Paint(card.dim, "shadow")
    card.number = crest:CreateFontString(nil, "OVERLAY")
    card.number:SetPoint("CENTER", 0, -1)
    card.number:SetShadowOffset(1, -1)
    card.number:SetShadowColor(0, 0, 0, 0.9)

    card.title = UI.Text(card, 14, "text", "medium")
    card.title:SetWordWrap(false)
    card.detail = UI.Text(card, 12, "textMuted")
    card.detail:SetWordWrap(false)
    card.detail:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
    card.turn = 0
    return card
end

-- Width a text would take on one line.
local function TextWidth(text)
    return (text.GetUnboundedStringWidth or text.GetStringWidth)(text) or 0
end

-- The crest follows the book's pictures: an icon, a number, or the game's
-- own texture of an item. A milestone has an accent border and a mark.
local function Fill(card, story)
    local looks = UI.BookPictures
    local look = looks[story.kind] or looks.zone
    card.crestBorder:SetColor(look.border)
    card.crestFill:SetColor(look.fill)
    local big = story.big or story.weight == "high"
    card.shape.border:SetColor(big and "cardActive" or "cardBorder")
    card.mark:SetShown(big)
    local photo = story.texture
    local icon = not photo and look.icon and (story.icon or look.icon) or nil
    local number = not icon and story.number
    card.photo:SetShown(photo ~= nil)
    card.dim:SetShown(photo ~= nil and number ~= nil and number ~= false)
    card.icon:SetShown(icon ~= nil)
    card.number:SetShown(number and true or false)
    if photo then
        card.photo:SetTexture(photo)
    elseif icon then
        card.icon:SetTexture(UI.media[icon] or UI.media[look.icon])
        UI.Tint(card.icon, look.ink)
    end
    if number then
        UI.SetDisplayFont(card.number, 22)
        UI.Ink(card.number, photo and "text" or look.ink)
        card.number:SetText(tostring(number))
    end

    -- Text: two lines centred on the band, or one.
    local detail = story.fullDetail or story.detail
    card.title:SetWidth(0)
    card.detail:SetWidth(0)
    card.title:SetText(story.fullTitle or story.title or "")
    UI.Ink(card.title, look.title or "text")
    card.detail:SetShown(detail ~= nil)
    card.detail:SetText(detail or "")
    card.title:ClearAllPoints()
    if detail then
        card.title:SetPoint("BOTTOMLEFT", card, "LEFT", TEXT_LEFT, 1)
    else
        card.title:SetPoint("LEFT", card, "LEFT", TEXT_LEFT, 0)
    end

    -- The band is as wide as its text needs; text beyond the widest band is
    -- cut off.
    local wanted = math.max(TextWidth(card.title), detail and TextWidth(card.detail) or 0)
    local width = math.min(MAX_WIDTH, math.max(MIN_WIDTH, math.ceil(TEXT_LEFT + wanted + TEXT_RIGHT)))
    card:SetWidth(width)
    -- The grain keeps one texel per pixel whatever the width.
    local tile = GRAIN_TEXELS * UI.Pixel(card)
    card.grain:SetTexCoord(0, (width - GROUND_INSET * 2) / tile, 0, (HEIGHT - GROUND_INSET * 2) / tile)
    local room = width - TEXT_LEFT - TEXT_RIGHT
    card.title:SetWidth(room)
    card.detail:SetWidth(room)
end

-- Takes a card off the screen. inTween: called from the card's own fade,
-- which must not be cancelled from inside itself.
local function Release(card, inTween)
    for index, each in ipairs(shown) do
        if each == card then
            table.remove(shown, index)
            break
        end
    end
    card.turn = card.turn + 1
    if not inTween then
        UI.CancelTween(card)
    end
    card:Hide()
    pool[#pool + 1] = card
    Layout()
end

function Feed.Show(story, seconds)
    Anchor()
    local card = table.remove(pool) or NewCard()
    Fill(card, story)
    table.insert(shown, 1, card)
    while #shown > MAX_CARDS do
        Release(shown[#shown])
    end
    Layout()

    card.turn = card.turn + 1
    local turn = card.turn
    card:SetAlpha(0)
    card:Show()
    UI.Tween(card, FADE_IN, function(progress)
        card:SetAlpha(progress)
    end)
    -- A card that was taken off and used again must not be hidden by the
    -- timer of its earlier life.
    C_Timer.After(seconds or DEFAULT_SECONDS, function()
        if card.turn ~= turn then
            return
        end
        UI.Tween(card, FADE_OUT, function(progress)
            card:SetAlpha(1 - progress)
            if progress >= 1 and card.turn == turn then
                Release(card, true)
            end
        end)
    end)
    return card
end

-- The cards on screen, the newest first.
function Feed.Shown()
    return shown
end

function Feed.Clear()
    while #shown > 0 do
        Release(shown[#shown])
    end
end

-- Shows a mark where the cards appear; it can be dragged, and the place is
-- kept.
function Feed.SetMoving(on)
    on = on and true or false
    if on == moving then
        return
    end
    moving = on
    Anchor()
    if on and not Feed.mover then
        local mover = CreateFrame("Frame", nil, anchor)
        mover:SetAllPoints(anchor)
        UI.Card(mover, "accentDeep", "accentLine", 12)
        mover.label = UI.Text(mover, 13, "accent2", "semibold")
        mover.label:SetPoint("LEFT", 14, 0)
        mover.label:SetPoint("RIGHT", -14, 0)
        mover.label:SetJustifyH("CENTER")
        mover.label:SetJustifyV("MIDDLE")
        mover:EnableMouse(true)
        mover:RegisterForDrag("LeftButton")
        mover:SetScript("OnDragStart", function()
            anchor:StartMoving()
        end)
        mover:SetScript("OnDragStop", function()
            anchor:StopMovingOrSizing()
            local point, _, relativePoint, x, y = anchor:GetPoint(1)
            if ns.global and point then
                ns.global.feed = { point = point, relativePoint = relativePoint, x = x, y = y }
            end
        end)
        Feed.mover = mover
    end
    if Feed.mover then
        Feed.mover.label:SetText(L.ui_feed_mover)
        Feed.mover:SetShown(on)
    end
    Layout()
end

function Feed.IsMoving()
    return moving
end

-- Back to the place the feed has from the start.
function Feed.ResetPlace()
    if ns.global then
        ns.global.feed = nil
    end
    if anchor then
        Place()
    end
end
