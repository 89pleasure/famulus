-- The picture book: how the chronicle is told. Chapters with a heading,
-- and below each a line down the middle on which its events hang, cards
-- alternating to the left and to the right, each with a small picture.
--
--   local book = UI.Book(parent, width)
--   local height = book:SetChapters(chapters, footer)
--
--   chapters = { {
--       small = "Today",                -- left of the heading, or nil
--       title = "Redridge Mountains",
--       sub = "Level 20 to 24  ·  5 events", -- right of the heading
--       events = { {
--           kind = "level",             -- see PICTURES
--           title = "Reached level 24", detail = "in Lakeshire" or nil,
--           when = "21:14",
--           times = { "20:02", "21:14" }, -- instead of `when`: an event that
--           count = 2,                  -- happened several times (a bundle)
--           number = 24,                -- shown in the picture of a level
--           icon = "horseshoe",         -- optional: a picture of its own (UI.media)
--           onClick = function() end,   -- optional: what a click on the card does
--           item = 211527, spell = 33388, -- optional: the picture shows the game's
--                                       -- tooltip of this item or spell
--           texture = 134400,           -- optional: a texture of the game's instead
--                                       -- (an item's icon), shown in its own colours
--           big = true,                 -- a milestone: larger, accent border and mark
--           chip = { initial = "A", text = "Companion", class = "MAGE" or nil } or nil,
--       } },
--   } }
--
-- Frames are created as needed and reused; nothing runs per frame.

local _, ns = ...
local UI = ns.UI

local AXIS = 44 -- width of the column the line runs through
local GAP = 14 -- between two events
local PICTURE = 54 -- the same for every event, whatever the size of its card
local DOT = 22
local FOOT = 30 -- the sunken strip that says whose event it is
local PHOTO_INSET = 2 -- an icon of the game fills its frame but for a fine line
local DOT_GAP = DOT + 12 -- between the dots of two events on the line
local HEAD_TOP, HEAD_BOTTOM = 6, 16 -- room above and below a chapter's heading
local HEAD_GAP = 16 -- between the place and the words beside it
local CHAPTER_GAP = 16 -- below a chapter's last card
local CHIP_H, CHIP_GAP, CHIP_PAD = 18, 4, 6 -- the times of a bundle
local MAX_TIMES = 10 -- plates for times; more are counted on the last one

-- Per kind: the picture's icon (none: the number), its colours, and the
-- icon on the line.
-- Also used by the live feed (UI/Feed.lua) as UI.BookPictures.
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
    -- The story of a fellow traveller: time together, and the bond's milestones.
    fellow = { icon = "people", fill = "control", border = "controlBorder", ink = "textDim", mark = "people" },
    bond = { icon = "people", fill = "accentDeep", border = "accentLine", ink = "accent2", mark = "people" },
}

---------------------------------------------------------------------------
-- Chapter heading
---------------------------------------------------------------------------

-- One line: the day, the place in the game's book font, and what happened,
-- between two lines that fade out towards the edges.
local function CreateHead(book)
    local head = CreateFrame("Frame", nil, book)
    head:SetWidth(book.width)
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
    return head
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
    head.height = math.floor(HEAD_TOP + head.title:GetStringHeight() + HEAD_BOTTOM + 0.5)
    head:SetHeight(head.height)
end

---------------------------------------------------------------------------
-- Event
---------------------------------------------------------------------------

local function CreateEvent(book)
    local event = CreateFrame("Frame", nil, book)
    event:SetWidth(book.width)

    -- The dot that sits on the line (the line itself belongs to the chapter).
    event.ring = UI.Icon(event, "circle", DOT, "accentLine", "BORDER")
    event.core = UI.Icon(event, "circle", DOT - 2, "window", "ARTWORK")
    event.core:SetPoint("CENTER", event.ring, "CENTER")
    event.mark = UI.Icon(event, "sparkle", 11, "accent", "OVERLAY")
    -- A short line from the dot to its card, so that with cards on both
    -- sides it is plain which dot belongs to which.
    event.tick = event:CreateTexture(nil, "BACKGROUND")
    event.tick:SetSize(AXIS / 2 - DOT / 2, UI.Pixel(event))
    UI.Paint(event.tick, "accentLine")
    event.mark:SetPoint("CENTER", event.ring, "CENTER")
    local card = CreateFrame("Frame", nil, event)
    event.card = card
    -- A story with onClick can be clicked; its card lights up under the
    -- mouse. The mouse is only caught where there is something to do.
    card:SetScript("OnEnter", function()
        event.hover:Fade(true)
    end)
    card:SetScript("OnLeave", function()
        event.hover:Fade(false)
    end)
    card:SetScript("OnMouseUp", function(_, button)
        local story = event.story
        if button == "LeftButton" and story and story.onClick then
            story.onClick()
        end
    end)
    -- The card is built like the card of an option in the window: the same
    -- ground and light on the top edge, the same glow under the mouse, an
    -- accent border and a mark on the left for what stands out (there a
    -- feature that is on, here a milestone), and a sunken strip below.
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

    local foot = CreateFrame("Frame", nil, card)
    event.foot = foot
    foot:SetHeight(FOOT)
    foot:SetPoint("BOTTOMLEFT")
    foot:SetPoint("BOTTOMRIGHT")
    UI.Round(foot, "sunken", 9, { inset = pixel, square = { TOPLEFT = true, TOPRIGHT = true } })
    local footLine = UI.Line(foot)
    footLine:SetPoint("TOPLEFT", pixel, 0)
    footLine:SetPoint("TOPRIGHT", -pixel, 0)

    local picture = CreateFrame("Frame", nil, card)
    event.picture = picture
    -- A picture that stands for an item or a spell shows the game's tooltip
    -- of it; the mouse is only caught where there is one (see EventSet).
    picture:SetScript("OnEnter", function(self)
        local story = event.story
        local item, spell = story and story.item, story and story.spell
        if item and GameTooltip.SetItemByID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(item)
            GameTooltip:Show()
        elseif spell and GameTooltip.SetSpellByID then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetSpellByID(spell)
            GameTooltip:Show()
        end
    end)
    picture:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    picture:SetScript("OnHide", function(self)
        if GameTooltip.IsOwned and GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
    end)
    -- The frame's corners are only slightly round, so that a square icon
    -- fills it without reaching over the line.
    event.pictureShape = UI.Card(picture, "control", "controlBorder", 5)
    event.icon = picture:CreateTexture(nil, "ARTWORK")
    event.icon:SetPoint("CENTER")
    -- An icon of the game: in its own colours, its own dark border cut off.
    event.photo = picture:CreateTexture(nil, "ARTWORK")
    event.photo:SetPoint("CENTER")
    event.photo:SetTexCoord(0.1, 0.9, 0.1, 0.9)
    -- A number stands on its icon; the icon is dimmed for it.
    event.dim = picture:CreateTexture(nil, "ARTWORK", nil, 1)
    event.dim:SetAllPoints(event.photo)
    UI.Paint(event.dim, "shadow")
    event.number = picture:CreateFontString(nil, "OVERLAY")
    event.number:SetPoint("CENTER", 0, -1)
    event.number:SetJustifyH("CENTER")
    event.number:SetShadowOffset(1, -1)
    event.number:SetShadowColor(0, 0, 0, 0.9)
    -- How often a bundled event happened, in the picture's corner.
    event.badge = CreateFrame("Frame", nil, picture)
    event.badge:SetHeight(16)
    event.badge:SetPoint("BOTTOMRIGHT", -3, 3)
    event.badgeGround = UI.Round(event.badge, "deathLine", 4)
    event.badgeText = UI.Text(event.badge, 11, "deathInk", "semibold")
    event.badgeText:SetPoint("CENTER")
    event.badgeText:SetJustifyH("CENTER")
    event.badgeText:SetJustifyV("MIDDLE")
    event.badge:Hide()
    event.plates = {} -- the times of a bundle

    event.title = UI.Text(card, 13, "text", "medium")
    event.title:SetSpacing(1)
    event.detail = UI.Text(card, 12, "textMuted")
    event.detail:SetSpacing(2)
    event.chipDot = UI.Icon(foot, "circle", 18, "accentSoft")
    event.chipDot:SetPoint("LEFT", foot, "LEFT", 12, 0)
    event.chipInitial = UI.Text(foot, 10, "accent", "semibold")
    event.chipInitial:SetPoint("CENTER", event.chipDot, "CENTER")
    event.chipInitial:SetJustifyH("CENTER")
    -- Where the class is known, its icon instead of the initial.
    event.chipClass = UI.ClassIcon(foot, 18)
    event.chipClass:SetPoint("CENTER", event.chipDot, "CENTER")
    event.chipText = UI.Text(foot, 11, "textMuted")
    event.chipText:SetPoint("LEFT", event.chipDot, "RIGHT", 6, 0)
    event.chipText:SetWordWrap(false)
    return event
end

UI.BookPictures = PICTURES

-- The times of a bundle as small plates, row after row within `width`.
-- Notes each plate's place below the first one (plate.x, plate.y) and
-- returns the height they take; without times, hides them.
local function LayTimes(event, times, width)
    local list = times or {}
    if #list > MAX_TIMES then
        list = {}
        for i = 1, MAX_TIMES - 1 do
            list[i] = times[i]
        end
        list[MAX_TIMES] = "+" .. (#times - MAX_TIMES + 1)
    end
    local x, y = 0, 0
    for index, text in ipairs(list) do
        local plate = event.plates[index]
        if not plate then
            plate = CreateFrame("Frame", nil, event.card)
            plate:SetHeight(CHIP_H)
            UI.Card(plate, "field", "cardBorder", 5)
            plate.text = UI.Text(plate, 11, "textDim", "medium")
            plate.text:SetPoint("CENTER")
            plate.text:SetJustifyH("CENTER")
            plate.text:SetJustifyV("MIDDLE")
            event.plates[index] = plate
        end
        plate.text:SetText(text)
        local plateWidth = math.floor(plate.text:GetStringWidth() + CHIP_PAD * 2 + 0.5)
        plate:SetWidth(plateWidth)
        if x > 0 and x + plateWidth > width then
            x, y = 0, y + CHIP_H + CHIP_GAP
        end
        plate.x, plate.y = x, y
        plate:Show()
        x = x + plateWidth + CHIP_GAP
    end
    for index = #list + 1, #event.plates do
        event.plates[index]:Hide()
    end
    event.plateCount = #list
    return #list > 0 and y + CHIP_H or 0
end

-- onLeft: the card stands left of the line. Sets event.cardHeight.
local function EventSet(event, story, onLeft, width)
    event.story = story
    event.onLeft = onLeft
    local look = PICTURES[story.kind] or PICTURES.zone
    local big = story.big and true or false
    local pad = big and 15 or 12
    local size = PICTURE
    local column = (width - AXIS) / 2
    local textWidth = column - pad * 2 - size - 12

    -- Picture: an icon, or a number (a level, a skill).
    event.picture:SetSize(size, size)
    event.picture:EnableMouse(story.item ~= nil or story.spell ~= nil)
    event.pictureShape.border:SetColor(look.border)
    event.pictureShape.fill:SetColor(look.fill)
    local photo = story.texture
    local icon = not photo and look.icon and (story.icon or look.icon) or nil
    local number = not icon and story.number
    event.photo:SetShown(photo ~= nil)
    event.dim:SetShown(photo ~= nil and number ~= nil and number ~= false)
    if photo then
        event.photo:SetTexture(photo)
        event.photo:SetSize(size - PHOTO_INSET * 2, size - PHOTO_INSET * 2)
    end
    event.icon:SetShown(icon ~= nil)
    event.number:SetShown(number and true or false)
    if icon then
        event.icon:SetTexture(UI.media[icon] or UI.media[look.icon])
        event.icon:SetSize(size * 0.56, size * 0.56)
        UI.Tint(event.icon, look.ink)
    end
    if number then
        UI.SetDisplayFont(event.number, 24)
        UI.Ink(event.number, photo and "text" or look.ink)
        event.number:SetText(tostring(number))
    end
    event.mark:SetTexture(UI.media[icon or story.icon or look.mark] or UI.media[look.mark])
    -- A bundle without a number counts its events in the corner.
    local counted = story.count ~= nil and not number
    event.badge:SetShown(counted)
    if counted then
        event.badgeText:SetText(tostring(story.count))
        event.badge:SetWidth(math.max(16, math.floor(event.badgeText:GetStringWidth() + 8 + 0.5)))
        event.badgeGround:SetColor(look.border)
        UI.Ink(event.badgeText, look.ink)
    end

    -- Text: headline, detail, and whom it is about.
    event.title:SetWidth(textWidth)
    event.title:SetText(story.title or "")
    UI.SetFont(event.title, big and 15 or 13, big and "semibold" or "medium")
    UI.Ink(event.title, look.title or "text")
    local textHeight = event.title:GetStringHeight()
    -- The time closes the line below the headline; a bundle lists its
    -- times below that line instead.
    local detail = story.detail
    if story.when and not story.times then
        detail = detail and (detail .. "  ·  " .. story.when) or story.when
    end
    event.detail:SetShown(detail ~= nil)
    if detail then
        event.detail:SetWidth(textWidth)
        event.detail:SetText(detail)
        textHeight = textHeight + 4 + event.detail:GetStringHeight()
    end
    local platesTop = textHeight + 6
    local platesHeight = LayTimes(event, story.times, textWidth)
    if platesHeight > 0 then
        textHeight = platesTop + platesHeight
    end
    -- Whose event it is stands in a sunken strip below, like an option
    -- under its feature.
    local chip = story.chip
    local classShown = UI.SetClass(event.chipClass, chip and chip.class)
    event.foot:SetShown(chip ~= nil)
    event.chipDot:SetShown(chip ~= nil and not classShown)
    event.chipInitial:SetShown(chip ~= nil and not classShown)
    event.chipText:SetShown(chip ~= nil)
    if chip then
        event.chipInitial:SetText(chip.initial or "")
        event.chipText:SetWidth(column - 12 - 18 - 6 - 12)
        event.chipText:SetText(chip.text or "")
    end

    local bodyHeight = math.floor(math.max(size, textHeight) + pad * 2 + 0.5)
    local cardHeight = bodyHeight + (chip and FOOT or 0)
    local card = event.card
    card:SetSize(column, cardHeight)
    card:ClearAllPoints()
    card:SetPoint(onLeft and "TOPLEFT" or "TOPRIGHT", event, onLeft and "TOPLEFT" or "TOPRIGHT", 0, 0)
    event.borderColor = big and "cardActive" or "cardBorder"
    event.shape.border:SetColor(event.borderColor)
    card:EnableMouse(story.onClick ~= nil)
    event.hover:Hide()
    event.bar:SetShown(big)

    event.picture:ClearAllPoints()
    event.picture:SetPoint("TOPLEFT", card, "TOPLEFT", pad, -math.floor((bodyHeight - size) / 2 + 0.5))
    local left = pad + size + 12
    local top = math.floor((bodyHeight - textHeight) / 2 + 0.5)
    event.title:ClearAllPoints()
    event.title:SetPoint("TOPLEFT", card, "TOPLEFT", left, -top)
    local last = event.title
    if detail then
        event.detail:ClearAllPoints()
        event.detail:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -4)
    end
    for index = 1, event.plateCount do
        local plate = event.plates[index]
        plate:ClearAllPoints()
        plate:SetPoint("TOPLEFT", card, "TOPLEFT", left + plate.x, -(top + platesTop + plate.y))
    end

    -- The dot at the height of the card's middle.
    event.ring:ClearAllPoints()
    event.ring:SetPoint("CENTER", event, "TOP", 0, -cardHeight / 2)
    event.tick:ClearAllPoints()
    event.tick:SetPoint(onLeft and "RIGHT" or "LEFT", event.ring, onLeft and "LEFT" or "RIGHT", 0, 0)

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
