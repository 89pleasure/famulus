-- The live feed: cards that appear on screen for a few seconds when the
-- chronicle writes something down, and fade out again. Nothing exists until
-- the first card is shown, and nothing runs while none is on screen. The
-- fellow travellers show theirs here too (who is nearby).
--
--   UI.Feed.Show(story, seconds)   -- story: as for the book (UI/Book.lua); the card
--                                     reads chip (whose it is: { text }),
--                                     title (what happened, without name and place),
--                                     detail (where, and what else to say) and
--                                     count (a bundle's number, in the crest's corner)
--   UI.Feed.Chime()                -- the cards' sound, once for cards that come together
--   UI.Feed.SetMoving(true)        -- shows where the cards appear; drag to move
--   UI.Feed.SetKeep(true)          -- the last three stay instead of fading out
--
--   story.reaction = {             -- optional: a button at the band's right
--       icon = "cheer",            -- end that reacts to a friend's event
--       given = function() return true end, -- whether the player has reacted
--       give = function() end,     -- reacts
--   }
--   story.bundle = "boss:123"      -- optional: the same event of someone else
--   story.join = function(story, other) end -- within BUNDLE seconds is joined
--                                     into this story instead of a card of its own
--
-- A story with `people = { { name, class, progress }, ... }` shows people
-- instead of a picture: one crest, or two side by side, each with the ring
-- of the bond (UI.Crest).
--
-- The newest card comes in at the top, large; the one before it shrinks to a
-- slim row (whose it is and what happened, on one line), the others slide
-- down, and a fourth is pushed out at the bottom. Every card stays on top for
-- a moment (STEP) before the next one comes, so that none goes unseen when
-- many come at once; those that wait lie as a stack behind the top card, with
-- their number. The longer the stack, the shorter the moment. While the last
-- three stay, the newest too becomes a row once its time is up, and the rows
-- rest: their content fainter, their band as it is.
--
-- Only the button to react catches the mouse; the rest of a card lets clicks
-- through to the world. While the mouse is on it the card stays, and goes a
-- moment after the mouse has left. A reaction closes the card shortly after,
-- unless the last three stay; it is taken back in the chronicle, not here.
-- The place is saved account-wide in FamulusDB.feed, like the window's.

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
-- in from its left end. Beside it up to three rows, as a card of the book
-- orders them: whose it is, what happened, where. The band is as wide as its
-- text needs, and a little taller when it holds all three rows.
local WIDTH, HEIGHT = 320, 64 -- the band; WIDTH is that of the mark for moving
local TALL = 76 -- the band with three rows
local CREST = 48
local CREST_LEFT = 14 -- band visible left of the crest
local TEXT_LEFT = CREST_LEFT + CREST + 14
local PAIR, PAIR_GAP = 40, 4 -- two people's crests side by side
local TEXT_RIGHT = 22
local MIN_WIDTH, MAX_WIDTH = 230, 340
local HEAD_ROW, TITLE_ROW, DETAIL_ROW, ROW_GAP = 14, 17, 15, 3 -- the rows' heights
local HEAD_DOT, HEAD_DOT_GAP = 6, 7 -- the glowing dot before the name
local GROUND_INSET = 3 -- keeps grain and dusk inside the rounded corners
local GRAIN_TEXELS = 128 -- size of grain.tga, as in UI.Grain
local GAP = 10 -- between two bands
local BAR_INSET = 10 -- the running-out line's distance from the band's ends
local BADGE = 16 -- a bundle's number in the crest's corner, as in the book
local MAX_CARDS = 3
local FADE_IN, FADE_OUT = 0.25, 0.5
local DEFAULT_SECONDS = 7
-- How cards move: a new one comes from a little above its place, the others
-- glide to theirs, one pushed out sinks a little as it fades.
local SLIDE = 0.4
local ENTER_FROM = 18
local DROP = 14
-- Seconds the newest card stays on top before the next one comes, and with
-- three waiting. A card is pushed out after three of them.
local STEP, STEP_RUSH = 1.2, 0.9
local BUNDLE = 6 -- seconds after a story's first event in which others join it
-- Only the newest card is large; the older ones are slim rows: a small crest,
-- then whose it is and what happened on one line.
local SLIM = 34
local SLIM_CREST, SLIM_LEFT = 24, 6
local SLIM_TEXT = SLIM_LEFT + SLIM_CREST + 9
local SLIM_REACT, SLIM_REACT_ICON, SLIM_REACT_RIGHT = 24, 14, 5
local SLIM_RIGHT = 14 -- from the text to the row's end, without a button
local SLIM_GAP = 6 -- below a row
local SLIM_MIN = 200
local SEP_GAP = 5 -- around the dot between whose it is and what happened
-- The last three, kept: past its time a card rests as a row, its content
-- fainter and its line gone. The band stays opaque, so nothing behind it
-- shows through.
local REST = 0.6
local KEEP_HEIGHT = TALL + GAP + 2 * SLIM + SLIM_GAP
local MARK_HEAD = 34 -- the mark's label above the room for three cards
-- What waits: the edges of cards stacked behind the top one, and their number.
local DECK = 2
local DECK_INSET, DECK_STEP, DECK_EDGE = 8, 5, 24
local COUNT_W, COUNT_H, COUNT_RIGHT = 26, 18, 18
-- The button to react, at the band's right end, in the middle.
local REACT = 32
local REACT_ICON = 18
local REACT_RIGHT = 16 -- from the band's right end
local REACT_GAP = 12 -- between the text and the button
local LINGER = 1.5 -- seconds a card stays once the mouse has left its button
local CLOSE = 1 -- seconds a card stays after a reaction, to see it lit

local anchor
local pool, shown = {}, {} -- shown: the newest first
local waiting = {} -- stories that wait for their turn, the oldest first
local moving, keep = false, false
local lastEntry -- GetTime() when the newest card came
local pumpAt, pumpTurn = nil, 0 -- when the next waiting card comes; its timer's turn
local deck -- the stack behind the top card (Deck)
local FadeOut, Due, Rest, Arrange -- (below)

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

-- Where the first card hangs: at the anchor; while the place is shown, below
-- its mark, or below the mark's label when the mark holds room for three.
local function Top()
    if not moving then
        return 0
    end
    return keep and -MARK_HEAD or -(HEIGHT + GAP)
end

-- Left edges in line, so the crests stand above each other.
local function SetY(card, y)
    card.y = y
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, y)
end

-- Moves a card to its place: there at once if it has none yet, else gliding.
-- A card already on its way there goes on undisturbed.
local function Slide(card, to)
    if card.slideTo == to then
        return
    end
    card.slideTo = to
    local from = card.y
    if from == nil or from == to then
        UI.CancelTween(card.slide)
        SetY(card, to)
        return
    end
    UI.Tween(card.slide, SLIDE, function(progress)
        SetY(card, from + (to - from) * progress)
    end)
end

-- Width a text would take on one line.
local function TextWidth(text)
    return (text.GetUnboundedStringWidth or text.GetStringWidth)(text) or 0
end

-- The stack behind the top card, made when something first waits: the
-- edges of two cards looking out above it, and how many wait. They hang
-- on the top card, so they move with it; the edges below the cards, the
-- number above them.
local function Deck()
    if deck then
        return deck
    end
    deck = { edges = {} }
    for index = 1, DECK do
        local edge = CreateFrame("Frame", nil, anchor)
        edge:SetFrameLevel(anchor:GetFrameLevel())
        edge:SetHeight(DECK_EDGE)
        UI.Card(edge, "card", "cardBorder", 9)
        edge:SetAlpha(index == 1 and 0.9 or 0.6)
        edge:Hide()
        deck.edges[index] = edge
    end
    local count = CreateFrame("Frame", nil, anchor)
    count:SetSize(COUNT_W, COUNT_H)
    count:SetFrameLevel(anchor:GetFrameLevel() + 10)
    UI.Round(count, "accent", COUNT_H / 2)
    count.text = UI.Text(count, 11, "onAccent", "semibold")
    count.text:SetPoint("CENTER")
    count.text:SetJustifyH("CENTER")
    count.text:SetJustifyV("MIDDLE")
    count:Hide()
    deck.count = count
    Feed.deck = deck
    return deck
end

local function PaintDeck()
    local number, top = #waiting, shown[1]
    if number == 0 and not deck then
        return
    end
    Deck()
    for index, edge in ipairs(deck.edges) do
        local on = top ~= nil and number >= index
        edge:SetShown(on)
        if on then
            edge:ClearAllPoints()
            edge:SetPoint("TOPLEFT", top, "TOPLEFT", DECK_INSET * index, DECK_STEP * index)
            edge:SetPoint("TOPRIGHT", top, "TOPRIGHT", -DECK_INSET * index, DECK_STEP * index)
        end
    end
    local count = deck.count
    count:SetShown(top ~= nil and number > 0)
    if top and number > 0 then
        count.text:SetText("+" .. number)
        count:SetWidth(math.max(COUNT_W, math.ceil(TextWidth(count.text) + 14)))
        count:ClearAllPoints()
        count:SetPoint("CENTER", top, "TOPRIGHT", -COUNT_RIGHT, 1)
    end
end

-- The cards hang below each other, the newest on top and large, the older
-- ones as rows; so does the newest once it rests.
local function Layout()
    local y = Top()
    for index, card in ipairs(shown) do
        local slim = index > 1 or card.resting
        if card.slim ~= slim then
            card.slim = slim
            Arrange(card, true)
        end
        Slide(card, y)
        y = y - card.height - (slim and SLIM_GAP or GAP)
    end
    PaintDeck()
end

-- The button's look (UI.ReactionButton): muted until the player has reacted,
-- then in the accent on the ground of an accent, as a lit chip in the window.
local function PaintReaction(button)
    local reaction = button.card.reaction
    if reaction then
        local given = reaction.given()
        button:Set(type(given) == "string" and given or reaction.icon, given)
    end
end

-- The button to react, without a tooltip: the click and the lit button say
-- enough. While the mouse is on it the card stays, and one that is fading
-- or resting comes back; once the mouse has left, a card whose time is up
-- goes (or rests) LINGER later. A click reacts with the kind's default;
-- holding the button or a right-click opens the bar with the kind's set
-- (UI.ReactionPicker), and the card stays while it is open. Once reacted,
-- the card goes CLOSE later whatever the mouse does, unless the last three
-- stay; a reaction given is changed or taken back in the chronicle only.
local function NewReactButton(card)
    local button = UI.ReactionButton(card.body, REACT, REACT_ICON)
    button.card = card
    button:SetPoint("RIGHT", card, "RIGHT", -REACT_RIGHT, 0)
    button:SetFrameLevel(card:GetFrameLevel() + 3)
    button:EnableMouse(true)

    local function Hold()
        card.held = true
        if card.fading and not card.closing then
            UI.CancelTween(card)
            card.fading = false
            card.due = true
            card:SetAlpha(1)
        elseif card.resting then
            UI.CancelTween(card.body)
            card.body:SetAlpha(1)
        end
    end
    local function Release()
        card.held = false
        card.leaves = card.leaves + 1
        if card.resting and not card.fading then
            Rest(card)
        elseif card.due and not card.closing then
            local turn, leave = card.turn, card.leaves
            C_Timer.After(LINGER, function()
                if card.turn == turn and card.leaves == leave and card.due and not card.held then
                    Due(card)
                end
            end)
        end
    end
    -- Gives the reaction (nil: the kind's default); the card goes a moment later.
    local function Give(choice)
        local reaction = card.reaction
        if not reaction or card.closing or reaction.given() then
            return
        end
        reaction.give(choice)
        if not reaction.given() then
            return -- (reactions were switched off since the card came)
        end
        button.hover:Fade(false)
        PaintReaction(button)
        -- Kept, the card stays with its button lit.
        if keep then
            return
        end
        card.closing = true
        local turn = card.turn
        C_Timer.After(CLOSE, function()
            if card.turn == turn and not card.fading then
                FadeOut(card)
            end
        end)
    end

    button:SetScript("OnEnter", function(self)
        self.over = true
        Hold()
        -- Once given there is nothing more to click.
        local reaction = card.reaction
        if reaction and not reaction.given() then
            self.hover:Fade(true)
        end
        PaintReaction(self)
    end)
    button:SetScript("OnLeave", function(self)
        self.over = false
        self.hover:Fade(false)
        PaintReaction(self)
        -- While its bar is open the card stays; the bar lets go of it.
        if not UI.ReactionPicker.IsOpenFor(self) then
            Release()
        end
    end)
    UI.ReactionPicker.Attach(button, function()
        local reaction = card.reaction
        if not reaction or card.closing or reaction.given() or not reaction.choices then
            return nil
        end
        return {
            choices = reaction.choices,
            pick = Give,
            onOpen = Hold,
            onClose = function()
                if not button:IsMouseOver() then
                    Release()
                end
            end,
        }
    end)
    button:SetScript("OnClick", function(self, mouseButton)
        if UI.ReactionPicker.Consumed(self, mouseButton) then
            return
        end
        Give(nil)
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

    -- What the band shows lies on a frame of its own, so that a resting card
    -- can grow faint while its band stays opaque.
    card.body = CreateFrame("Frame", nil, card)
    card.body:SetAllPoints(card)
    card.body:SetFrameLevel(card:GetFrameLevel() + 1)
    local body = card.body

    -- The crest: a frame of its own above the band, with a border two
    -- pixels strong in the colour of its kind.
    local crest = CreateFrame("Frame", nil, body)
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
    -- A font before any text: the client refuses SetText without one, and
    -- Fill writes the number before the layout sizes it.
    UI.SetDisplayFont(card.number, 22)
    card.number:SetPoint("CENTER", 0, -1)
    card.number:SetShadowOffset(1, -1)
    card.number:SetShadowColor(0, 0, 0, 0.9)
    -- How many share a bundle, in the crest's corner, as in the book.
    card.badge = CreateFrame("Frame", nil, crest)
    card.badge:SetHeight(BADGE)
    card.badge:SetPoint("BOTTOMRIGHT", -3, 3)
    card.badgeGround = UI.Round(card.badge, "controlBorder", 4)
    card.badgeText = UI.Text(card.badge, 11, "text", "semibold")
    card.badgeText:SetPoint("CENTER")
    card.badgeText:SetJustifyH("CENTER")
    card.badgeText:SetJustifyV("MIDDLE")
    card.badge:Hide()

    -- The rows, placed by Arrange: whose it is (small, after a glowing dot in
    -- the accent, like the dots on the line of the book), what happened, where.
    -- In a slim row a dot stands between whose it is and what happened.
    card.headDot = UI.GlowDot(body, HEAD_DOT, "OVERLAY")
    card.head = UI.Text(body, 11, "textDim", "semibold")
    card.head:SetWordWrap(false)
    card.head:SetHeight(HEAD_ROW)
    card.head:SetJustifyV("MIDDLE")
    card.sep = UI.Text(body, 12, "textMuted")
    card.sep:SetHeight(HEAD_ROW)
    card.sep:SetJustifyV("MIDDLE")
    card.sep:SetText("·")
    card.sep:Hide()
    card.title = UI.Text(body, 14, "text", "medium")
    card.title:SetWordWrap(false)
    card.title:SetHeight(TITLE_ROW)
    card.title:SetJustifyV("MIDDLE")
    card.detail = UI.Text(body, 12, "textMuted")
    card.detail:SetWordWrap(false)
    card.detail:SetHeight(DETAIL_ROW)
    card.detail:SetJustifyV("MIDDLE")
    card.react = NewReactButton(card)

    -- How long it stays: a line along its foot that runs out by the time the
    -- card has faded. The client's animation shrinks it, no Lua per frame.
    -- A card held by the mouse on its button stays past it.
    card.bar = card:CreateTexture(nil, "OVERLAY")
    card.bar:SetHeight(2)
    card.bar:SetPoint("BOTTOMLEFT", BAR_INSET, 2)
    card.bar:SetPoint("BOTTOMRIGHT", -BAR_INSET, 2)
    UI.Shade(card.bar, "HORIZONTAL", "accent", "accent2")
    card.bar:Hide()
    card.barGroup = card.bar:CreateAnimationGroup()
    card.barRun = card.barGroup:CreateAnimation("Scale")
    card.barRun:SetScaleFrom(1, 1)
    card.barRun:SetScaleTo(0.001, 1)
    card.barRun:SetOrigin("LEFT", 0, 0)
    -- At its end the client would draw it whole again.
    card.barGroup:SetScript("OnFinished", function()
        card.bar:Hide()
    end)
    card.turn, card.leaves = 0, 0
    -- Keys of its tweens (UI.Tween), apart from its fading (the card itself)
    -- and its content growing faint or bright (card.body).
    card.slide, card.resize = {}, {}
    return card
end

-- People instead of a picture: one crest, or two side by side, made when a
-- card first needs them. Arrange shows them on a large card; a slim row shows
-- its own crest with the people's icon instead.
local function FillPeople(card, people)
    local pair = people and #people > 1
    local solo = people and #people == 1
    if solo and not card.solo then
        card.solo = UI.Crest(card.body, CREST)
        card.solo:SetPoint("LEFT", CREST_LEFT, 0)
        card.solo:SetFrameLevel(card:GetFrameLevel() + 2)
    end
    if pair and not card.pair then
        card.pair = {}
        for index = 1, 2 do
            local crest = UI.Crest(card.body, PAIR)
            crest:SetPoint("LEFT", CREST_LEFT + (index - 1) * (PAIR + PAIR_GAP), 0)
            crest:SetFrameLevel(card:GetFrameLevel() + 2)
            card.pair[index] = crest
        end
    end
    if solo then
        card.solo:SetPerson(people[1].name, people[1].class)
        card.solo:SetProgress(people[1].progress)
    elseif pair then
        for index, crest in ipairs(card.pair) do
            crest:SetPerson(people[index].name, people[index].class)
            crest:SetProgress(people[index].progress)
        end
    end
end

-- Places the content for the card's form and sizes the band: a large card of
-- up to three rows, or a slim row (card.slim): a small crest, then whose it is
-- and what happened on one line, without the line below. The band is as wide
-- as its text needs; text beyond the widest band is cut off. glide: the band
-- grows or shrinks to its new size instead of jumping.
function Arrange(card, glide)
    local slim = card.slim and true or false
    local people = card.people
    local pair = people ~= nil and #people > 1
    local head, detail = card.hasHead, card.hasDetail
    if card.fontSlim ~= slim then
        card.fontSlim = slim
        UI.SetFont(card.head, slim and 12 or 11, "semibold")
        UI.SetFont(card.title, slim and 13 or 14, "medium")
    end

    -- The picture: the crest, or on a large card the people's crests.
    local size = slim and SLIM_CREST or CREST
    local crest = card.crest
    crest:SetSize(size, size)
    crest:ClearAllPoints()
    crest:SetPoint("LEFT", slim and SLIM_LEFT or CREST_LEFT, 0)
    crest:SetShown(slim or people == nil)
    card.icon:SetSize(size * 0.5, size * 0.5)
    card.photo:SetSize(size - 6, size - 6)
    if card.number:IsShown() then
        UI.SetDisplayFont(card.number, slim and 12 or 22)
    end
    card.badge:SetShown(card.counted and not slim)
    if card.solo then
        card.solo:SetShown(not slim and people ~= nil and not pair)
    end
    if card.pair then
        for _, each in ipairs(card.pair) do
            each:SetShown(not slim and pair)
        end
    end
    local textLeft = slim and SLIM_TEXT or pair and CREST_LEFT + PAIR * 2 + PAIR_GAP + 14 or TEXT_LEFT

    -- The button to react, at the right end.
    local button, reaction = card.react, card.reaction
    local buttonSize = slim and SLIM_REACT or REACT
    if button.size ~= buttonSize then
        button.size, button.iconSize = buttonSize, slim and SLIM_REACT_ICON or REACT_ICON
        button:SetSize(buttonSize, buttonSize)
        button.icon:SetSize(button.iconSize, button.iconSize)
    end
    button:ClearAllPoints()
    button:SetPoint("RIGHT", card, "RIGHT", -(slim and SLIM_REACT_RIGHT or REACT_RIGHT), 0)
    button:SetShown(reaction ~= nil)
    PaintReaction(button)
    local right
    if reaction then
        right = slim and SLIM_REACT_RIGHT + SLIM_REACT + 8 or REACT_RIGHT + REACT + REACT_GAP
    else
        right = slim and SLIM_RIGHT or TEXT_RIGHT
    end

    card.head:SetWidth(0)
    card.title:SetWidth(0)
    card.detail:SetWidth(0)
    UI.SetDot(card.headDot, nil, head and not slim)
    card.sep:SetShown(head and slim)
    card.detail:SetShown(detail and not slim)
    card.head:ClearAllPoints()
    card.title:ClearAllPoints()
    card.detail:ClearAllPoints()
    local width, height
    if slim then
        -- Whose it is takes at most half of the room, what happened the rest.
        height = SLIM
        local name = head and TextWidth(card.head) or 0
        local between = head and SEP_GAP * 2 + TextWidth(card.sep) or 0
        width = math.min(MAX_WIDTH, math.max(SLIM_MIN, math.ceil(textLeft + name + between + TextWidth(card.title) + right)))
        local room = width - textLeft - right
        if head then
            name = math.min(math.ceil(name), math.floor(room / 2))
            card.head:SetPoint("LEFT", card, "LEFT", textLeft, 0)
            card.head:SetWidth(name)
            card.sep:ClearAllPoints()
            card.sep:SetPoint("LEFT", card.head, "RIGHT", SEP_GAP, 0)
            card.title:SetPoint("LEFT", card.sep, "RIGHT", SEP_GAP, 0)
        else
            card.title:SetPoint("LEFT", card, "LEFT", textLeft, 0)
        end
        card.title:SetWidth(room - (head and name + between or 0))
    else
        -- Up to three rows, centred on the band.
        height = head and detail and TALL or HEIGHT
        local block = (head and HEAD_ROW + ROW_GAP or 0) + TITLE_ROW + (detail and ROW_GAP + DETAIL_ROW or 0)
        local y = -math.floor((height - block) / 2)
        local headLeft = textLeft + HEAD_DOT + HEAD_DOT_GAP
        if head then
            card.headDot:ClearAllPoints()
            card.headDot:SetPoint("CENTER", card, "TOPLEFT", textLeft + HEAD_DOT / 2, y - HEAD_ROW / 2)
            card.head:SetPoint("TOPLEFT", card, "TOPLEFT", headLeft, y)
            y = y - HEAD_ROW - ROW_GAP
        end
        card.title:SetPoint("TOPLEFT", card, "TOPLEFT", textLeft, y)
        y = y - TITLE_ROW - ROW_GAP
        card.detail:SetPoint("TOPLEFT", card, "TOPLEFT", textLeft, y)
        local wanted = math.max(head and headLeft - textLeft + TextWidth(card.head) or 0, TextWidth(card.title),
            detail and TextWidth(card.detail) or 0)
        width = math.min(MAX_WIDTH, math.max(MIN_WIDTH, math.ceil(textLeft + wanted + right)))
        local room = width - textLeft - right
        card.head:SetWidth(room - (headLeft - textLeft))
        card.title:SetWidth(room)
        card.detail:SetWidth(room)
    end

    card.height = height
    -- The grain keeps one texel per pixel whatever the size.
    local tile = GRAIN_TEXELS * UI.Pixel(card)
    card.grain:SetTexCoord(0, (width - GROUND_INSET * 2) / tile, 0, (height - GROUND_INSET * 2) / tile)
    local fromWidth, fromHeight = card:GetWidth(), card:GetHeight()
    if glide and card:IsShown() and (fromWidth ~= width or fromHeight ~= height) then
        UI.Tween(card.resize, SLIDE, function(progress)
            card:SetSize(fromWidth + (width - fromWidth) * progress, fromHeight + (height - fromHeight) * progress)
        end)
    else
        UI.CancelTween(card.resize)
        card:SetSize(width, height)
    end
end

-- The crest follows the book's pictures: an icon, a number, or the game's
-- own texture of an item; people show their crests (on a slim row, their
-- icon). A milestone has an accent border; no mark at its left, the
-- running-out line along its foot is accent enough. slim: the form to show it
-- in; else the card keeps the one it has (large, for a new one).
local function Fill(card, story, slim)
    if slim ~= nil then
        card.slim = slim
    end
    FillPeople(card, story.people)
    card.people = story.people
    local looks = UI.BookPictures
    local look = looks[story.kind] or looks.zone
    card.crestBorder:SetColor(look.border)
    card.crestFill:SetColor(look.fill)
    local big = story.big and true or false
    card.shape.border:SetColor(big and "cardActive" or "cardBorder")
    local photo = not story.people and story.texture or nil
    local icon = story.people and "people" or not photo and look.icon and (story.icon or look.icon) or nil
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
        UI.Ink(card.number, photo and "text" or look.ink)
        card.number:SetText(tostring(number))
    end
    -- A bundle without a number counts its people in the corner.
    card.counted = story.count ~= nil and story.count > 1 and not number and not story.people or false
    if card.counted then
        card.badgeText:SetText(tostring(story.count))
        card.badge:SetWidth(math.max(BADGE, math.floor(TextWidth(card.badgeText) + 8 + 0.5)))
        card.badgeGround:SetColor(look.border)
        UI.Ink(card.badgeText, look.ink)
    end

    -- Text: whose it is, small (as the head of a card in the book names
    -- them; none for the player's own events), what happened, and where.
    local chip = story.chip
    local head = chip and chip.text or nil
    local detail = story.detail
    card.hasHead, card.hasDetail = head ~= nil, detail ~= nil
    card.head:SetShown(head ~= nil)
    card.head:SetText(head or "")
    card.title:SetText(story.title or "")
    UI.Ink(card.title, look.title or "text")
    card.detail:SetText(detail or "")

    -- A friend's event may bring the button to react.
    card.reaction = story.reaction
    Arrange(card)
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
    UI.CancelTween(card.slide)
    UI.CancelTween(card.resize)
    UI.CancelTween(card.body)
    card.body:SetAlpha(1)
    card.y, card.slideTo, card.news = nil, nil, nil
    card.held, card.due, card.fading, card.closing, card.resting = false, false, false, false, false
    card.reaction = nil
    card.react.over = false
    card.react.hover:Hide()
    card.barGroup:Stop()
    card:Hide()
    pool[#pool + 1] = card
    Layout()
end

-- The card's time is up: it fades out and is gone.
function FadeOut(card)
    local turn, from = card.turn, card:GetAlpha()
    card.due, card.fading = false, true
    UI.Tween(card, FADE_OUT, function(progress)
        card:SetAlpha(from * (1 - progress))
        if progress >= 1 and card.turn == turn then
            Release(card, true)
        end
    end)
end

-- A card kept past its time rests: its content grows faint (the band stays
-- as it is), and with `to` it comes up again.
function Rest(card, to)
    local body = card.body
    local from, target = body:GetAlpha(), to or REST
    UI.Tween(body, FADE_OUT, function(progress)
        body:SetAlpha(from + (target - from) * progress)
    end)
end

-- Its time is up: kept, it rests as a row; else it goes.
function Due(card)
    card.due = false
    if keep then
        card.resting = true
        card.barGroup:Stop()
        card.bar:Hide()
        Rest(card)
        Layout()
    else
        FadeOut(card)
    end
end

-- Pushed out by a newer card: out of the stack at once, it sinks a little as
-- it fades. Nothing brings it back.
local function Drop(card)
    for index, each in ipairs(shown) do
        if each == card then
            table.remove(shown, index)
            break
        end
    end
    card.turn = card.turn + 1
    card.held, card.due, card.resting = false, false, false
    card.fading, card.closing = true, true
    card.barGroup:Stop()
    card.bar:Hide()
    UI.CancelTween(card.slide)
    card.slideTo = nil
    local turn, from, alpha = card.turn, card.y or 0, card:GetAlpha()
    UI.Tween(card, FADE_OUT, function(progress)
        card:SetAlpha(alpha * (1 - progress))
        SetY(card, from - DROP * progress)
        if progress >= 1 and card.turn == turn then
            Release(card, true)
        end
    end)
end

-- The card's time begins: it comes up (or back), its line runs out, and when
-- the time is up it goes or rests. A card that was taken off and used again
-- must not be touched by the timer of its earlier life; one the mouse is on
-- waits until it leaves.
local function Run(card)
    card.turn = card.turn + 1
    local turn = card.turn
    card.due, card.fading, card.closing, card.resting = false, false, false, false
    local from = card:GetAlpha()
    UI.Tween(card, FADE_IN, function(progress)
        card:SetAlpha(from + (1 - from) * progress)
    end)
    if card.body:GetAlpha() < 1 then
        Rest(card, 1)
    end
    local seconds = card.seconds
    card.barGroup:Stop()
    card.barRun:SetDuration(seconds + (keep and 0 or FADE_OUT))
    card.bar:Show()
    card.barGroup:Play()
    C_Timer.After(seconds, function()
        if card.turn ~= turn then
            return
        end
        if card.held then
            card.due = true
            return
        end
        Due(card)
    end)
end

-- A story's turn: its card comes in at the top, the others slide down, and
-- a fourth is pushed out at the bottom.
local function Enter(story)
    local card = table.remove(pool) or NewCard(anchor)
    card.news, card.seconds = story, story.seconds or DEFAULT_SECONDS
    Fill(card, story, false)
    table.insert(shown, 1, card)
    lastEntry = GetTime()
    while #shown > MAX_CARDS do
        Drop(shown[#shown])
    end
    card.slideTo = nil
    SetY(card, Top() + ENTER_FROM)
    card:SetAlpha(0)
    card:Show()
    Layout()
    Run(card)
    return card
end

-- How long the newest card stays on top before the next one comes: shorter
-- when many wait.
local function Step(count)
    return count >= 3 and STEP_RUSH or STEP
end

-- The next waiting story comes once the newest card has had its moment; as
-- more join the stack that moment grows shorter, and a sooner timer takes
-- over from the one already set (which then does nothing). A timer only
-- while something waits.
local function Pump()
    if #waiting == 0 then
        return
    end
    local due = (lastEntry or 0) + Step(#waiting)
    if pumpAt and pumpAt <= due then
        return
    end
    pumpAt = due
    pumpTurn = pumpTurn + 1
    local turn = pumpTurn
    C_Timer.After(math.max(0, due - GetTime()), function()
        if turn ~= pumpTurn then
            return
        end
        pumpAt = nil
        local story = table.remove(waiting, 1)
        if story then
            Enter(story)
            Pump()
        end
        PaintDeck()
    end)
end

-- The same event of someone else within BUNDLE seconds joins a story that
-- waits, or one on screen; that card shows it and starts its time again.
local function Join(story, now)
    for _, other in ipairs(waiting) do
        if other.bundle == story.bundle and other.join and now - other.first < BUNDLE then
            other.join(other, story)
            return true
        end
    end
    for _, card in ipairs(shown) do
        local other = card.news
        if other and other.bundle == story.bundle and other.join and not card.fading and now - other.first < BUNDLE then
            other.join(other, story)
            Fill(card, other)
            Run(card)
            Layout()
            return true
        end
    end
    return false
end

-- Returns the card if it comes at once; else nil, and "waiting" or "joined".
function Feed.Show(story, seconds)
    Anchor()
    story.seconds = seconds or DEFAULT_SECONDS
    local now = GetTime()
    if story.bundle and Join(story, now) then
        return nil, "joined"
    end
    story.first = now
    if #waiting == 0 and (#shown == 0 or not lastEntry or now - lastEntry >= STEP) then
        return Enter(story)
    end
    waiting[#waiting + 1] = story
    Pump()
    PaintDeck()
    return nil, "waiting"
end

-- A card as the feed draws it, on another frame and never on screen by
-- itself: the picture of the live feed in its settings (UI/Previews.lua).
-- Feed.Fill(card, story) gives it an event; it is then as wide as its text.
function Feed.Card(parent)
    return NewCard(parent)
end
Feed.Fill = Fill
Feed.REST = REST

-- The cards on screen, the newest first.
function Feed.Shown()
    return shown
end

-- The stories that wait for their turn, the oldest first.
function Feed.Waiting()
    return waiting
end

function Feed.Clear()
    for index = #waiting, 1, -1 do
        waiting[index] = nil
    end
    while #shown > 0 do
        Release(shown[#shown])
    end
    lastEntry, pumpAt, pumpTurn = nil, nil, pumpTurn + 1
    PaintDeck()
end

-- The mark: as large as one card with its label in the middle; while the
-- last three stay, its label at the top and below it the room they take.
-- It lies behind the cards.
local function Mark()
    local mover = Feed.mover
    mover:SetHeight(keep and MARK_HEAD + KEEP_HEIGHT + GAP or HEIGHT)
    mover.label:ClearAllPoints()
    if keep then
        mover.label:SetPoint("TOPLEFT", 14, 0)
        mover.label:SetPoint("TOPRIGHT", -14, 0)
    else
        mover.label:SetPoint("LEFT", 14, 0)
        mover.label:SetPoint("RIGHT", -14, 0)
    end
end

-- The last three stay (the live feed's option): past its time a card rests
-- instead of fading out. Switched off, the resting ones go now, the others
-- when their time is up.
function Feed.SetKeep(on)
    on = on and true or false
    if on == keep then
        return
    end
    keep = on
    if not keep then
        for index = #shown, 1, -1 do
            local card = shown[index]
            if card.resting and not card.fading then
                FadeOut(card)
            end
        end
    end
    if Feed.mover then
        Mark()
    end
    if anchor then
        Layout()
    end
end

function Feed.IsKeeping()
    return keep
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
        mover:SetPoint("TOPLEFT", anchor, "TOPLEFT")
        mover:SetPoint("TOPRIGHT", anchor, "TOPRIGHT")
        mover:SetFrameLevel(anchor:GetFrameLevel())
        UI.Card(mover, "accentDeep", "accentLine", 12)
        mover.label = UI.Text(mover, 13, "accent2", "semibold")
        mover.label:SetHeight(MARK_HEAD)
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
        Mark()
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
