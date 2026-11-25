-- The live feed: cards that appear on screen for a few seconds when the
-- chronicle writes something down, and fade out again. Nothing exists until
-- the first card is shown, and nothing runs while none is on screen. The
-- fellow travellers show theirs here too (who is nearby).
--
--   UI.Feed.Show(story, seconds)   -- story: as for the book (UI/Book.lua)
--   UI.Feed.Chime()                -- the cards' sound, once for cards that come together
--   UI.Feed.SetMoving(true)        -- shows where the cards appear; drag to move
--
--   story.reaction = {             -- optional: a button at the band's right
--       icon = "cheer",            -- end that reacts to a friend's event
--       given = function() return true end, -- whether the player has reacted
--       give = function() end,     -- reacts
--   }
--
-- A story with `people = { { name, class, progress }, ... }` shows people
-- instead of a picture: one crest, or two side by side, each with the ring
-- of the bond (UI.Crest).
--
-- Only the button to react catches the mouse; the rest of a card lets clicks
-- through to the world. While the mouse is on it the card stays, and goes a
-- moment after the mouse has left. A reaction closes the card shortly after;
-- it is taken back in the chronicle, not here. The place is saved account-wide in
-- FamulusDB.feed, like the window's.

local ADDON_NAME, ns = ...
local UI = ns.UI
local L = ns.L

local Feed = {}
UI.Feed = Feed

-- A soft double click comes with a card (tools/make_sound.js), once for cards
-- that come together. It plays on the game's sound effects channel, so it
-- follows their volume and mute like the game's own notices. The game only
-- finds a file that was in the addon folder at login or the last /reload.
Feed.SOUND = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\click.ogg"
local QUIET = 2 -- seconds; cards within this of the last sound bring none
local sounded

function Feed.Chime()
    if not PlaySoundFile then
        return
    end
    local now = GetTime()
    if sounded and now - sounded < QUIET then
        return
    end
    sounded = now
    PlaySoundFile(Feed.SOUND, "SFX")
end

-- A card is a crest on a band: the picture stands inside the band, a little
-- in from its left end. The band is as wide as its text needs.
local WIDTH, HEIGHT = 320, 64 -- the band; WIDTH is that of the mark for moving
local CREST = 48
local CREST_LEFT = 14 -- band visible left of the crest
local TEXT_LEFT = CREST_LEFT + CREST + 14
local PAIR, PAIR_GAP = 40, 4 -- two people's crests side by side
local TEXT_RIGHT = 22
local MIN_WIDTH, MAX_WIDTH = 230, 460
local GROUND_INSET = 3 -- keeps grain and dusk inside the rounded corners
local GRAIN_TEXELS = 128 -- size of grain.tga, as in UI.Grain
local GAP = 10 -- between two bands
local MAX_CARDS = 3
local FADE_IN, FADE_OUT = 0.25, 0.5
local DEFAULT_SECONDS = 7
-- The button to react, at the band's right end, in the middle.
local REACT = 32
local REACT_ICON = 18
local REACT_RIGHT = 16 -- from the band's right end
local REACT_GAP = 12 -- between the text and the button
local LINGER = 1.5 -- seconds a card stays once the mouse has left its button
local CLOSE = 1 -- seconds a card stays after a reaction, to see it lit

local anchor
local pool, shown = {}, {} -- shown: the newest first
local moving = false
local FadeOut -- (below)

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

-- The button's look: muted until the player has reacted, then in the accent
-- on the ground of an accent, as a lit chip in the window.
local function PaintReaction(button)
    local reaction = button.card.reaction
    if not reaction then
        return
    end
    local given = reaction.given() and true or false
    button.ground.fill:SetColor(given and "accentDeep" or "control")
    button.ground.border:SetColor(given and "accentLine" or "controlBorder")
    button.icon:SetTexture(UI.media[reaction.icon] or UI.media.cheer)
    UI.Tint(button.icon, given and "accent" or button.over and "text" or "textMuted")
end

-- The button to react, without a tooltip: the click and the lit button say
-- enough. While the mouse is on it the card stays, and one that is fading
-- comes back; once the mouse has left, a card whose time is up goes LINGER
-- later. A click reacts, and the card goes CLOSE later whatever the mouse
-- does; a reaction given is taken back in the chronicle only.
local function NewReactButton(card)
    local button = CreateFrame("Button", nil, card)
    button.card = card
    button:SetSize(REACT, REACT)
    button:SetPoint("RIGHT", card, "RIGHT", -REACT_RIGHT, 0)
    button:SetFrameLevel(card:GetFrameLevel() + 3)
    button:EnableMouse(true)
    button.ground = UI.Card(button, "control", "controlBorder", 8)
    button.hover = UI.Round(button, "hover", 8, { layer = "ARTWORK" })
    button.hover:Hide()
    button.icon = UI.Icon(button, "cheer", REACT_ICON, "textMuted", "OVERLAY")
    button.icon:SetPoint("CENTER")
    button:SetScript("OnEnter", function(self)
        self.over = true
        card.held = true
        if card.fading and not card.closing then
            UI.CancelTween(card)
            card.fading = false
            card.due = true
            card:SetAlpha(1)
        end
        -- Once given there is nothing more to click.
        local reaction = card.reaction
        if reaction and not reaction.given() then
            self.hover:Fade(true)
        end
        PaintReaction(self)
    end)
    button:SetScript("OnLeave", function(self)
        self.over = false
        card.held = false
        card.leaves = card.leaves + 1
        self.hover:Fade(false)
        PaintReaction(self)
        if card.due and not card.closing then
            local turn, leave = card.turn, card.leaves
            C_Timer.After(LINGER, function()
                if card.turn == turn and card.leaves == leave and card.due and not card.held then
                    FadeOut(card)
                end
            end)
        end
    end)
    button:SetScript("OnClick", function(self)
        local reaction = card.reaction
        if not reaction or card.closing or reaction.given() then
            return
        end
        reaction.give()
        if not reaction.given() then
            return -- (reactions were switched off since the card came)
        end
        self.hover:Fade(false)
        PaintReaction(self)
        card.closing = true
        local turn = card.turn
        C_Timer.After(CLOSE, function()
            if card.turn == turn and not card.fading then
                FadeOut(card)
            end
        end)
    end)
    button:Hide()
    return button
end

local function NewCard(parent)
    local card = CreateFrame("Frame", nil, parent)
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
    card.react = NewReactButton(card)
    card.turn, card.leaves = 0, 0
    return card
end

-- Width a text would take on one line.
local function TextWidth(text)
    return (text.GetUnboundedStringWidth or text.GetStringWidth)(text) or 0
end

-- People instead of a picture: one crest, or two side by side. Made when a
-- card first needs them. Returns where the text begins.
local function FillPeople(card, people)
    local pair = people and #people > 1
    local solo = people and #people == 1
    if solo and not card.solo then
        card.solo = UI.Crest(card, CREST)
        card.solo:SetPoint("LEFT", CREST_LEFT, 0)
        card.solo:SetFrameLevel(card:GetFrameLevel() + 2)
    end
    if pair and not card.pair then
        card.pair = {}
        for index = 1, 2 do
            local crest = UI.Crest(card, PAIR)
            crest:SetPoint("LEFT", CREST_LEFT + (index - 1) * (PAIR + PAIR_GAP), 0)
            crest:SetFrameLevel(card:GetFrameLevel() + 2)
            card.pair[index] = crest
        end
    end
    card.crest:SetShown(not people or #people == 0)
    if card.solo then
        card.solo:SetShown(solo and true or false)
    end
    if card.pair then
        for index, crest in ipairs(card.pair) do
            crest:SetShown(pair and true or false)
            if pair then
                crest:SetPerson(people[index].name, people[index].class)
                crest:SetProgress(people[index].progress)
            end
        end
    end
    if solo then
        card.solo:SetPerson(people[1].name, people[1].class)
        card.solo:SetProgress(people[1].progress)
    elseif pair then
        return CREST_LEFT + PAIR * 2 + PAIR_GAP + 14
    end
    return TEXT_LEFT
end

-- The crest follows the book's pictures: an icon, a number, or the game's
-- own texture of an item. A milestone has an accent border and a mark.
local function Fill(card, story)
    local textLeft = FillPeople(card, story.people)
    local looks = UI.BookPictures
    local look = looks[story.kind] or looks.zone
    card.crestBorder:SetColor(look.border)
    card.crestFill:SetColor(look.fill)
    local big = story.big and true or false
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
    local detail = story.detail
    card.title:SetWidth(0)
    card.detail:SetWidth(0)
    card.title:SetText(story.fullTitle or story.title or "")
    UI.Ink(card.title, look.title or "text")
    card.detail:SetShown(detail ~= nil)
    card.detail:SetText(detail or "")
    card.title:ClearAllPoints()
    if detail then
        card.title:SetPoint("BOTTOMLEFT", card, "LEFT", textLeft, 1)
    else
        card.title:SetPoint("LEFT", card, "LEFT", textLeft, 0)
    end

    -- A friend's event may bring the button to react, at the right end.
    local reaction = story.reaction
    card.reaction = reaction
    card.react:SetShown(reaction ~= nil)
    PaintReaction(card.react)
    local right = reaction and REACT_RIGHT + REACT + REACT_GAP or TEXT_RIGHT

    -- The band is as wide as its text needs; text beyond the widest band is
    -- cut off.
    local wanted = math.max(TextWidth(card.title), detail and TextWidth(card.detail) or 0)
    local width = math.min(MAX_WIDTH, math.max(MIN_WIDTH, math.ceil(textLeft + wanted + right)))
    card:SetWidth(width)
    -- The grain keeps one texel per pixel whatever the width.
    local tile = GRAIN_TEXELS * UI.Pixel(card)
    card.grain:SetTexCoord(0, (width - GROUND_INSET * 2) / tile, 0, (HEIGHT - GROUND_INSET * 2) / tile)
    local room = width - textLeft - right
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
    card.held, card.due, card.fading, card.closing = false, false, false, false
    card.reaction = nil
    card.react.over = false
    card.react.hover:Hide()
    card:Hide()
    pool[#pool + 1] = card
    Layout()
end

-- The card's time is up: it fades out and is gone.
function FadeOut(card)
    local turn = card.turn
    card.due, card.fading = false, true
    UI.Tween(card, FADE_OUT, function(progress)
        card:SetAlpha(1 - progress)
        if progress >= 1 and card.turn == turn then
            Release(card, true)
        end
    end)
end

function Feed.Show(story, seconds)
    Anchor()
    local card = table.remove(pool) or NewCard(anchor)
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
    -- timer of its earlier life. One the mouse is on waits until it leaves.
    C_Timer.After(seconds or DEFAULT_SECONDS, function()
        if card.turn ~= turn then
            return
        end
        if card.held then
            card.due = true
            return
        end
        FadeOut(card)
    end)
    return card
end

-- A card as the feed draws it, on another frame and never on screen by
-- itself: the picture of the live feed in its settings (UI/Previews.lua).
-- Feed.Fill(card, story) gives it an event; it is then as wide as its text.
function Feed.Card(parent)
    return NewCard(parent)
end
Feed.Fill = Fill
Feed.HEIGHT = HEIGHT

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
