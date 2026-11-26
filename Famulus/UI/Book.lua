-- The picture book: how the chronicle is told. Chapters with a heading,
-- and below each a line down the middle on which its events hang, cards
-- alternating to the left and to the right, each with a small picture.
--
--   local book = UI.Book(parent, width)
--   local height = book:SetChapters(chapters, footer)
--
--   chapters = { {
--       small = "19:58 – 23:20",        -- left of the heading, or nil
--       title = "This evening",
--       sub = "Level 20 to 24  ·  5 events", -- right of the heading
--       route = { "Redridge Mountains", "Duskwood" }, -- optional: below the
--                                       -- heading, the zones in the order of time
--       events = { {
--           content = UI.ChronicleCard, -- builds what the card holds, see below
--           kind = "level",             -- for its picture, see PICTURES
--           weight = "low" or "medium" or "high", -- optional: how wide the card
--                                       -- is, see WIDTHS; without, as wide as can be
--           big = true,                 -- a milestone: accent border and mark
--           onClick = function() end,   -- optional: what a click on the card does
--           tooltip = function(tip) end, -- optional: fills the game's tooltip
--                                       -- while the mouse is over the card
--           onPicture = function() end, -- optional: what a click on the picture
--           pictureHint = "...",        -- does, and what its tooltip says
--           ...                         -- whatever its content reads
--       } },
--   } }
--
-- The book sets the design: chapters, the line, the dots and the cards'
-- look. What a card holds is up to each feature: story.content(part,
-- story, width) builds it into `part`, a frame of the card's width that
-- belongs to this content alone, and returns the height it needs; the card
-- grows with it. Use the same function for every card of one kind (not a
-- new closure per story), so that its frames are used again. Shared parts
-- of the book's look: the room inside a card's edge (UI.BookPad), and the
-- picture (UI.BookPicture and UI.SetBookPicture).
--
-- Frames are created as needed and reused; nothing runs per frame.

local _, ns = ...
local UI = ns.UI

local AXIS = 44 -- width of the column the line runs through
local GAP = 14 -- between two events
-- The glowing dot on the line, by the card's weight (without one: medium,
-- a milestone high); its halo is three times as large.
local DOTS = { low = 5, medium = 7, high = 9 }
local PHOTO_INSET = 2 -- an icon of the game fills its frame but for a fine line
local DOT_GAP = 34 -- between the dots of two events on the line
-- How wide a card is, by its weight: a share of its side of the book. A
-- narrower card keeps to the line.
local WIDTHS = { low = 0.8, medium = 0.9, high = 1 }
-- The room between a card's edge and what it holds, the same on every card:
-- UI.BookPad at the sides and below, UI.BookPadTop above. Measured from the
-- outer edge; the frame's hairline takes a pixel of it, and at the top the
-- line of light takes one more, so the top gets one more to look the same.
local PAD = 14
UI.BookPad = PAD
UI.BookPadTop = PAD + 1
local HEAD_TOP, HEAD_BOTTOM = 6, 16 -- room above and below a chapter's heading
local HEAD_GAP = 16 -- between the place and the words beside it
local CHAPTER_GAP = 16 -- below a chapter's last card
local ROUTE_GAP, ROUTE_H, ROUTE_PAD = 8, 22, 9 -- the route below a heading
local ROUTE_ARROW = 10 -- the arrow between two zones of the route
local ROUTE_STEP = 6 -- between a plate and an arrow

-- Per kind: the picture's icon (none: the number), its colours, and a
-- small icon of the kind (mark) for a card's content to show. Used by the
-- cards' contents and the live feed (UI/Feed.lua) as UI.BookPictures.
local PICTURES = {
    level = { fill = "accentDeep", border = "accentLine", ink = "accent2", mark = "sparkle" },
    achievement = { icon = "star", fill = "accentDeep", border = "accentLine", ink = "accent2", mark = "star" },
    zone = { icon = "peaks", fill = "control", border = "controlBorder", ink = "textDim", mark = "peaks" },
    profession = { icon = "hammer", fill = "control", border = "controlBorder", ink = "textDim", mark = "hammer" },
    skill = { fill = "accentDeep", border = "accentLine", ink = "accent2", mark = "hammer" },
    -- An item or an ability may name its own picture (story.icon).
    item = { icon = "chest", fill = "accentDeep", border = "accentLine", ink = "accent2", mark = "chest" },
    ability = { icon = "sparkle", fill = "accentDeep", border = "accentLine", ink = "accent2", mark = "sparkle" },
    death = { icon = "skull", fill = "deathGround", border = "deathLine", ink = "deathInk", mark = "skull", title = "deathInk" },
    boss = { icon = "swords", fill = "bossGround", border = "bossLine", ink = "bossInk", mark = "swords" },
    -- A friend's reaction, in the live feed; story.icon names it ("cheer").
    reaction = { icon = "cheer", fill = "accentDeep", border = "accentLine", ink = "accent2", mark = "cheer" },
    -- The story of a fellow traveller: time together, and the bond's milestones.
    fellow = { icon = "people", fill = "control", border = "controlBorder", ink = "textDim", mark = "people" },
    bond = { icon = "people", fill = "accentDeep", border = "accentLine", ink = "accent2", mark = "people" },
}

---------------------------------------------------------------------------
-- Chapter heading
---------------------------------------------------------------------------

-- One line: when, the title in the game's book font, and what happened,
-- between two lines that fade out towards the edges; below it, if the
-- chapter has one, the route through the zones.
local function CreateHead(book)
    local head = CreateFrame("Frame", nil, book)
    head:SetWidth(book.width)
    head.width = book.width -- SetWidth sets no field of that name
    head.half = book.width / 2

    head.title = head:CreateFontString(nil, "OVERLAY")
    UI.SetDisplayFont(head.title, 22)
    UI.Ink(head.title, "accent2")
    head.title:SetWordWrap(false)
    head.title:SetPoint("TOP", head, "TOP", 0, -HEAD_TOP)
    head.small = UI.Text(head, 11, "textMuted", "medium")
    head.small:SetWordWrap(false)
    head.small:SetJustifyV("MIDDLE")
    head.small:SetPoint("RIGHT", head.title, "LEFT", -HEAD_GAP, 0)
    head.sub = UI.Text(head, 12, "textDim")
    head.sub:SetWordWrap(false)
    head.sub:SetJustifyV("MIDDLE")
    head.sub:SetPoint("LEFT", head.title, "RIGHT", HEAD_GAP, 0)

    head.left = head:CreateTexture(nil, "BORDER")
    head.left:SetHeight(UI.Pixel(head))
    UI.Shade(head.left, "HORIZONTAL", "accentNone", "accentLine")
    head.right = head:CreateTexture(nil, "BORDER")
    head.right:SetHeight(UI.Pixel(head))
    UI.Shade(head.right, "HORIZONTAL", "accentLine", "accentNone")
    head.plates, head.arrows = {}, {} -- the route
    return head
end

-- The zones of a route as plates with arrows between them, centred in a
-- row `top` below the heading's top. Returns the row's width; hides the
-- plates and arrows it does not need.
local function LayRoute(head, names, top)
    local width = 0
    for index, name in ipairs(names) do
        local plate = head.plates[index]
        if not plate then
            plate = CreateFrame("Frame", nil, head)
            plate:SetHeight(ROUTE_H)
            UI.Card(plate, "field", "fieldBorder", 6)
            plate.text = UI.Text(plate, 11, "textDim", "medium")
            plate.text:SetPoint("CENTER")
            plate.text:SetJustifyH("CENTER")
            plate.text:SetJustifyV("MIDDLE")
            plate.text:SetWordWrap(false)
            head.plates[index] = plate
        end
        plate.text:SetText(name)
        plate:SetWidth(math.floor(plate.text:GetStringWidth() + ROUTE_PAD * 2 + 0.5))
        width = width + plate:GetWidth() + (index > 1 and ROUTE_ARROW + ROUTE_STEP * 2 or 0)
    end
    local x = math.floor((head.width - width) / 2 + 0.5)
    for index = 1, #names do
        local plate = head.plates[index]
        if index > 1 then
            local arrow = head.arrows[index]
            if not arrow then
                arrow = UI.Icon(head, "chevron", ROUTE_ARROW, "accentLine")
                arrow:SetTexCoord(0, 0, 1, 0, 0, 1, 1, 1) -- the chevron turned to point right
                head.arrows[index] = arrow
            end
            arrow:ClearAllPoints()
            arrow:SetPoint("TOPLEFT", head, "TOPLEFT", x + ROUTE_STEP, -(top + (ROUTE_H - ROUTE_ARROW) / 2))
            arrow:Show()
            x = x + ROUTE_ARROW + ROUTE_STEP * 2
        end
        plate:ClearAllPoints()
        plate:SetPoint("TOPLEFT", head, "TOPLEFT", x, -top)
        plate:Show()
        x = x + plate:GetWidth()
    end
    for index = #names + 1, #head.plates do
        head.plates[index]:Hide()
    end
    for index = math.max(2, #names + 1), #head.arrows do
        if head.arrows[index] then
            head.arrows[index]:Hide()
        end
    end
    return width
end

-- The route below the heading, `top` below its top; the oldest zones give
-- way to "…" where the row would be wider than the book. Returns the height
-- it takes, nothing without a route.
local function HeadRoute(head, route, top)
    local names = route or {}
    local first = 1
    local function From(index)
        local shown = {}
        if index > 1 then
            shown[1] = "…"
        end
        for each = index, #names do
            shown[#shown + 1] = names[each]
        end
        return shown
    end
    local width = LayRoute(head, From(first), top)
    while width > head.width and first < #names do
        first = first + 1
        width = LayRoute(head, From(first), top)
    end
    head.routeShown = #names > 0 and #From(first) or 0
    return #names > 0 and ROUTE_GAP + ROUTE_H or 0
end

-- A line from the edge to the words beside the place; none where there is
-- no room for it.
local function HeadLine(line, words, anchor, side, length)
    line:SetShown(length >= 16)
    line:ClearAllPoints()
    local offset = words and 12 or HEAD_GAP
    if side == "LEFT" then
        line:SetPoint("RIGHT", anchor, "LEFT", -offset, 0)
    else
        line:SetPoint("LEFT", anchor, "RIGHT", offset, 0)
    end
    line:SetWidth(math.max(1, length))
end

local function HeadSet(head, chapter)
    head.chapter = chapter
    head.title:SetText(chapter.title or "")
    head.small:SetShown(chapter.small ~= nil)
    head.small:SetText(chapter.small or "")
    head.sub:SetShown(chapter.sub ~= nil)
    head.sub:SetText(chapter.sub or "")
    local taken = head.title:GetStringWidth() / 2 + HEAD_GAP
    local left = chapter.small and head.small:GetStringWidth() + 12 or 0
    local right = chapter.sub and head.sub:GetStringWidth() + 12 or 0
    HeadLine(head.left, chapter.small, chapter.small and head.small or head.title, "LEFT", head.half - taken - left)
    HeadLine(head.right, chapter.sub, chapter.sub and head.sub or head.title, "RIGHT", head.half - taken - right)
    local titleBottom = math.floor(HEAD_TOP + head.title:GetStringHeight() + 0.5)
    local route = HeadRoute(head, chapter.route, titleBottom + ROUTE_GAP)
    head.height = titleBottom + route + HEAD_BOTTOM
    head:SetHeight(head.height)
end

---------------------------------------------------------------------------
-- Event
---------------------------------------------------------------------------

UI.BookPictures = PICTURES

-- A picture of the book on `part`: a frame with slightly round corners
-- for an icon of the book, an icon of the game, or a number on it; a
-- bundle's count in the corner. Sets part.picture, part.icon, part.photo,
-- part.dim, part.number, part.badge and part.badgeText.
function UI.BookPicture(part)
    local picture = CreateFrame("Frame", nil, part)
    part.picture = picture
    -- A picture that stands for an item or a spell shows the game's tooltip
    -- of it, one that can be clicked says what the click does; the mouse is
    -- only caught where there is one of these.
    picture:SetScript("OnEnter", function(self)
        local item, spell = self.item, self.spell
        if item and GameTooltip.SetItemByID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(item)
            GameTooltip:Show()
        elseif spell and GameTooltip.SetSpellByID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(spell)
            GameTooltip:Show()
        elseif self.hint then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(self.hint)
            GameTooltip:Show()
        end
    end)
    picture:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    picture:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" and self.onClick then
            self.onClick()
        end
    end)
    picture:SetScript("OnHide", function(self)
        if GameTooltip.IsOwned and GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
    end)
    -- The frame's corners are only slightly round, so that a square icon
    -- fills it without reaching over the line.
    part.pictureShape = UI.Card(picture, "control", "controlBorder", 5)
    part.icon = picture:CreateTexture(nil, "ARTWORK")
    part.icon:SetPoint("CENTER")
    -- An icon of the game: in its own colours, its own dark border cut off.
    part.photo = picture:CreateTexture(nil, "ARTWORK")
    part.photo:SetPoint("CENTER")
    part.photo:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    -- A number stands on its icon; the icon is dimmed for it.
    part.dim = picture:CreateTexture(nil, "ARTWORK", nil, 1)
    part.dim:SetAllPoints(part.photo)
    UI.Paint(part.dim, "shadow")
    part.number = picture:CreateFontString(nil, "OVERLAY")
    part.number:SetPoint("CENTER", 0, -1)
    part.number:SetJustifyH("CENTER")
    part.number:SetShadowOffset(1, -1)
    part.number:SetShadowColor(0, 0, 0, 0.9)
    -- How often a bundled event happened, in the picture's corner.
    part.badge = CreateFrame("Frame", nil, picture)
    part.badge:SetHeight(16)
    part.badge:SetPoint("BOTTOMRIGHT", -3, 3)
    part.badgeGround = UI.Round(part.badge, "deathLine", 4)
    part.badgeText = UI.Text(part.badge, 11, "deathInk", "semibold")
    part.badgeText:SetPoint("CENTER")
    part.badgeText:SetJustifyH("CENTER")
    part.badgeText:SetJustifyV("MIDDLE")
    part.badge:Hide()
    return picture
end

-- Shows a story's picture (made by UI.BookPicture) at `size`: its game
-- icon (story.texture), else the icon of its kind or story.icon, else its
-- number (story.number, at `numberSize`); story.count in the corner;
-- story.item or story.spell for the tooltip; story.onPicture for a click on
-- it, with story.pictureHint as its tooltip.
function UI.SetBookPicture(part, story, size, numberSize)
    local look = PICTURES[story.kind] or PICTURES.zone
    local picture = part.picture
    picture.item, picture.spell = story.item, story.spell
    picture.onClick, picture.hint = story.onPicture, story.onPicture and story.pictureHint or nil
    picture:SetSize(size, size)
    picture:EnableMouse(story.item ~= nil or story.spell ~= nil or story.onPicture ~= nil)
    part.pictureShape.border:SetColor(look.border)
    part.pictureShape.fill:SetColor(look.fill)
    local photo = story.texture
    local icon = not photo and look.icon and (story.icon or look.icon) or nil
    local number = not icon and story.number
    part.photo:SetShown(photo ~= nil)
    part.dim:SetShown(photo ~= nil and number ~= nil and number ~= false)
    if photo then
        part.photo:SetTexture(photo)
        part.photo:SetSize(size - PHOTO_INSET * 2, size - PHOTO_INSET * 2)
    end
    part.icon:SetShown(icon ~= nil)
    part.number:SetShown(number and true or false)
    if icon then
        part.icon:SetTexture(UI.media[icon] or UI.media[look.icon])
        part.icon:SetSize(size * 0.56, size * 0.56)
        UI.Tint(part.icon, look.ink)
    end
    if number then
        UI.SetDisplayFont(part.number, numberSize or 24)
        UI.Ink(part.number, photo and "text" or look.ink)
        part.number:SetText(tostring(number))
    end
    -- A bundle without a number counts its events in the corner.
    local counted = story.count ~= nil and not number
    part.badge:SetShown(counted)
    if counted then
        part.badgeText:SetText(tostring(story.count))
        part.badge:SetWidth(math.max(16, math.floor(part.badgeText:GetStringWidth() + 8 + 0.5)))
        part.badgeGround:SetColor(look.border)
        UI.Ink(part.badgeText, look.ink)
    end
end

local function CreateEvent(book)
    local event = CreateFrame("Frame", nil, book)
    event:SetWidth(book.width)

    -- The dot that sits on the line (the line itself belongs to the chapter).
    -- A glowing dot in the accent, like what is active elsewhere in the window.
    event.dot = UI.GlowDot(event, DOTS.medium)
    -- A short line from the dot to its card, so that with cards on both
    -- sides it is plain which dot belongs to which.
    event.tick = event:CreateTexture(nil, "BACKGROUND")
    UI.Paint(event.tick, "accentLine")
    local card = CreateFrame("Frame", nil, event)
    event.card = card
    -- A story with onClick can be clicked; its card lights up under the
    -- mouse. One with a tooltip shows it there. The mouse is only caught
    -- where there is something to do or to read.
    card:SetScript("OnEnter", function(self)
        local story = event.story
        if story and story.onClick then
            event.hover:Fade(true)
        end
        if story and story.tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            story.tooltip(GameTooltip)
            GameTooltip:Show()
        end
    end)
    card:SetScript("OnLeave", function(self)
        event.hover:Fade(false)
        if GameTooltip.IsOwned and GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
    end)
    card:SetScript("OnMouseUp", function(self, button)
        local story = event.story
        if button == "LeftButton" and story and story.onClick then
            -- What the tooltip said may no longer hold after the click.
            if GameTooltip.IsOwned and GameTooltip:IsOwned(self) then
                GameTooltip:Hide()
            end
            story.onClick()
        end
    end)
    -- The card is built like the card of an option in the window: the same
    -- ground and light on the top edge, the same glow under the mouse, an
    -- accent border and a mark on the left for what stands out (there a
    -- feature that is on, here a milestone).
    local pixel = UI.Pixel(card)
    event.shape = UI.Card(card, "card", "cardBorder", 10)
    event.hover = UI.Round(card, "hover", 8, { inset = 4, sublevel = 2 })
    event.hover:Hide()
    local sheen = UI.Line(card, "sheenSoft")
    sheen:SetPoint("TOPLEFT", 10, -pixel)
    sheen:SetPoint("TOPRIGHT", -10, -pixel)
    event.bar = card:CreateTexture(nil, "BORDER")
    event.bar:SetPoint("TOPLEFT", 0, -14)
    event.bar:SetPoint("BOTTOMLEFT", 0, 14)
    event.bar:SetWidth(2)
    UI.Paint(event.bar, "accent")
    event.parts = {} -- per content builder, the frame it fills
    return event
end

-- onLeft: the card stands left of the line. Sets event.cardHeight.
local function EventSet(event, story, onLeft, width)
    event.story = story
    event.onLeft = onLeft
    local column = math.floor((width - AXIS) / 2 * (WIDTHS[story.weight] or 1) + 0.5)
    local dot = DOTS[story.weight] or story.big and DOTS.high or DOTS.medium
    UI.SetDot(event.dot, dot)
    event.tick:SetSize(AXIS / 2 - dot / 2, UI.Pixel(event))
    local card = event.card

    -- What the card holds is the feature's: its builder fills a frame of
    -- its own, and the card is as high as that needs.
    local build = story.content
    assert(type(build) == "function", "a story of the book needs a content builder")
    local part = event.parts[build]
    if not part then
        part = CreateFrame("Frame", nil, card)
        part:SetPoint("TOPLEFT")
        event.parts[build] = part
    end
    for _, other in pairs(event.parts) do
        other:SetShown(other == part)
    end
    event.content = part
    part:SetWidth(column)
    local cardHeight = math.floor(build(part, story, column) + 0.5)
    part:SetHeight(cardHeight)

    card:SetSize(column, cardHeight)
    card:ClearAllPoints()
    local side = (width - AXIS) / 2
    if onLeft then
        card:SetPoint("TOPRIGHT", event, "TOPLEFT", side, 0)
    else
        card:SetPoint("TOPLEFT", event, "TOPRIGHT", -side, 0)
    end
    local big = story.big and true or false
    event.borderColor = big and "cardActive" or "cardBorder"
    event.shape.border:SetColor(event.borderColor)
    card:EnableMouse(story.onClick ~= nil or story.tooltip ~= nil)
    event.hover:Hide()
    event.bar:SetShown(big)

    -- The dot at the height of the card's middle.
    event.dot:ClearAllPoints()
    event.dot:SetPoint("CENTER", event, "TOP", 0, -cardHeight / 2)
    event.tick:ClearAllPoints()
    event.tick:SetPoint(onLeft and "RIGHT" or "LEFT", event.dot, onLeft and "LEFT" or "RIGHT", 0, 0)

    event.cardHeight = cardHeight
    event:SetHeight(cardHeight)
end

---------------------------------------------------------------------------

function UI.Book(parent, width)
    local book = CreateFrame("Frame", nil, parent)
    book:SetWidth(width)
    book.width = width
    book.heads, book.events, book.trails = {}, {}, {}
    book.footer = UI.Text(book, 12, "textMuted")
    book.footer:SetWidth(width)
    book.footer:SetJustifyH("CENTER")

    -- Lays the chapters out and returns the height they take.
    function book:SetChapters(chapters, footer)
        local y, eventCount = 0, 0
        for index, chapter in ipairs(chapters) do
            local head = self.heads[index]
            if not head then
                head = CreateHead(self)
                self.heads[index] = head
            end
            HeadSet(head, chapter)
            head:ClearAllPoints()
            head:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
            head:Show()
            y = y + head.height
            -- The cards alternate between the two sides, and each side
            -- runs on by itself: a card begins where the one above it on
            -- its side ends, so the sides reach into each other. Only the
            -- dots on the line keep their distance, in the order of time.
            local start = y
            local columnY = { y, y }
            local lastDot
            for position, story in ipairs(chapter.events) do
                eventCount = eventCount + 1
                local event = self.events[eventCount]
                if not event then
                    event = CreateEvent(self)
                    self.events[eventCount] = event
                end
                local side = position % 2 == 1 and 1 or 2
                EventSet(event, story, side == 1, self.width)
                local height = event.cardHeight
                local top = columnY[side]
                if lastDot then
                    top = math.max(top, lastDot + DOT_GAP - height / 2)
                end
                top = math.floor(top + 0.5)
                event:ClearAllPoints()
                event:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -top)
                event:Show()
                event.top = top
                lastDot = top + height / 2
                columnY[side] = top + height + GAP
            end
            y = math.max(columnY[1], columnY[2])
            -- The chapter's line, from its first card to its last.
            local trail = self.trails[index]
            if not trail then
                trail = self:CreateTexture(nil, "BACKGROUND")
                trail:SetWidth(UI.Pixel(self))
                UI.Paint(trail, "accentTrail")
                self.trails[index] = trail
            end
            trail:ClearAllPoints()
            trail:SetPoint("TOP", self, "TOP", 0, -start)
            trail:SetHeight(math.max(1, y - GAP - start))
            trail:SetShown(#chapter.events > 0)
            y = y + CHAPTER_GAP
        end
        for index = #chapters + 1, #self.heads do
            self.heads[index]:Hide()
            if self.trails[index] then
                self.trails[index]:Hide()
            end
        end
        for index = eventCount + 1, #self.events do
            self.events[index]:Hide()
        end
        self.footer:SetShown(footer ~= nil)
        if footer then
            self.footer:SetText(footer)
            self.footer:ClearAllPoints()
            self.footer:SetPoint("TOP", self, "TOP", 0, -(y + 4))
            y = y + 4 + self.footer:GetStringHeight() + 10
        end
        self:SetHeight(math.max(1, y))
        return y
    end

    return book
end
