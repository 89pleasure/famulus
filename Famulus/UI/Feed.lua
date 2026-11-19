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

local WIDTH, HEIGHT, GAP = 320, 58, 8
local PICTURE = 40
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
        card:SetPoint("TOP", anchor, "TOP", 0, y)
        y = y - HEIGHT - GAP
    end
end

local function NewCard()
    local card = CreateFrame("Frame", nil, Anchor())
    card:SetSize(WIDTH, HEIGHT)
    UI.Shadow(card, 22, 12, 6)
    UI.Card(card, "window", "cardBorder", 12)

    local picture = CreateFrame("Frame", nil, card)
    picture:SetSize(PICTURE, PICTURE)
    picture:SetPoint("LEFT", 10, 0)
    card.picture = picture
    card.pictureShape = UI.Card(picture, "control", "controlBorder", 8)
    card.icon = picture:CreateTexture(nil, "ARTWORK")
    card.icon:SetPoint("CENTER")
    card.icon:SetSize(PICTURE * 0.56, PICTURE * 0.56)
    card.photo = picture:CreateTexture(nil, "ARTWORK")
    card.photo:SetPoint("CENTER")
    card.photo:SetSize(PICTURE - 10, PICTURE - 10)
    card.photo:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.number = picture:CreateFontString(nil, "OVERLAY")
    card.number:SetPoint("CENTER", 0, -1)

    card.title = UI.Text(card, 14, "text", "semibold")
    card.title:SetWordWrap(false)
    card.detail = UI.Text(card, 12, "textMuted")
    card.detail:SetWordWrap(false)
    card.detail:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)
    card.detail:SetPoint("RIGHT", card, "RIGHT", -14, 0)
    card.turn = 0
    return card
end

-- The picture follows the book's: an icon, a number, or the game's own
-- texture of an item.
local function Fill(card, story)
    local looks = UI.BookPictures
    local look = looks[story.kind] or looks.zone
    card.pictureShape.border:SetColor(look.border)
    card.pictureShape.fill:SetColor(look.fill)
    local photo = story.texture
    local icon = not photo and look.icon and (story.icon or look.icon) or nil
    local number = not photo and not icon and story.number
    card.photo:SetShown(photo ~= nil)
    card.icon:SetShown(icon ~= nil)
    card.number:SetShown(number and true or false)
    if photo then
        card.photo:SetTexture(photo)
    elseif icon then
        card.icon:SetTexture(UI.media[icon] or UI.media[look.icon])
        UI.Tint(card.icon, look.ink)
    elseif number then
        UI.SetDisplayFont(card.number, 19)
        UI.Ink(card.number, look.ink)
        card.number:SetText(tostring(number))
    end

    local detail = story.detail
    card.title:ClearAllPoints()
    if detail then
        card.title:SetPoint("TOPLEFT", card.picture, "TOPRIGHT", 12, -3)
    else
        card.title:SetPoint("LEFT", card.picture, "RIGHT", 12, 0)
    end
    card.title:SetPoint("RIGHT", card, "RIGHT", -14, 0)
    card.title:SetText(story.title or "")
    UI.Ink(card.title, look.title or "text")
    card.detail:SetShown(detail ~= nil)
    card.detail:SetText(detail or "")
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
