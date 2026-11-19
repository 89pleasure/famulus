-- The picture book: how the chronicle is told. Chapters with a heading,
-- and below each a line down the middle on which its events hang, cards
-- alternating to the left and to the right, each with a small picture.
--
--   local book = UI.Book(parent, width)
--   local height = book:SetChapters(chapters, footer)
--
--   chapters = { {
--       small = "Today",                -- line above the heading, or nil
--       title = "Redridge Mountains",
--       sub = "Level 20 to 24  ·  5 events",
--       events = { {
--           kind = "level",             -- see PICTURES
--           title = "Reached level 24", detail = "in Lakeshire" or nil,
--           when = "21:14",
--           number = 24,                -- shown in the picture of a level
--           icon = "horseshoe",         -- optional: a picture of its own (UI.media)
--           onClick = function() end,   -- optional: what a click on the card does
--           item = 211527, spell = 33388, -- optional: the picture shows the game's
--                                       -- tooltip of this item or spell
--           texture = 134400,           -- optional: a texture of the game's instead
--                                       -- (an item's icon), shown in its own colours
--           big = true,                 -- a milestone: larger, with a glow
--           chip = { initial = "A", text = "Companion" } or nil,
--       } },
--   } }
--
-- Frames are created as needed and reused; nothing runs per frame.

local _, ns = ...
local UI = ns.UI

local AXIS = 44 -- width of the column the line runs through
local GAP = 14 -- between two events
local PICTURE, PICTURE_BIG = 54, 66
local DOT = 30
local PHOTO_INSET = 6 -- between the frame of a picture and a texture of the game's
local ORNAMENT = 120 -- length of each line beside the heading's mark

-- Per kind: the picture's icon (none: the number), its colours, and the
-- icon on the line.
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
}

---------------------------------------------------------------------------
-- Chapter heading
---------------------------------------------------------------------------

local function CreateHead(book)
    local head = CreateFrame("Frame", nil, book)
    head:SetWidth(book.width)

    local function Centered(text)
        text:SetWidth(book.width)
        text:SetJustifyH("CENTER")
        return text
    end
    head.small = Centered(UI.Text(head, 11, "textMuted", "medium"))
    head.title = head:CreateFontString(nil, "OVERLAY")
    UI.SetDisplayFont(head.title, 24)
    UI.Ink(head.title, "accent2")
    head.title:SetJustifyV("TOP")
    Centered(head.title)
    head.sub = Centered(UI.Text(head, 12, "textDim"))

    -- A small mark between two lines that fade out to the sides.
    head.mark = UI.Icon(head, "sparkle", 9, "accent")
    head.left = head:CreateTexture(nil, "BORDER")
    head.left:SetSize(ORNAMENT, UI.Pixel(head))
    head.left:SetPoint("RIGHT", head.mark, "LEFT", -8, 0)
    UI.Shade(head.left, "HORIZONTAL", "accentNone", "accentLine")
    head.right = head:CreateTexture(nil, "BORDER")
    head.right:SetSize(ORNAMENT, UI.Pixel(head))
    head.right:SetPoint("LEFT", head.mark, "RIGHT", 8, 0)
    UI.Shade(head.right, "HORIZONTAL", "accentLine", "accentNone")
    return head
end

local function HeadSet(head, chapter)
    head.chapter = chapter
    local y = 4
    local function Place(text, value, gap)
        text:SetShown(value ~= nil)
        if value == nil then
            return
        end
        text:SetText(value)
        text:ClearAllPoints()
        text:SetPoint("TOP", head, "TOP", 0, -y)
        y = y + text:GetStringHeight() + gap
    end
    Place(head.small, chapter.small, 4)
    Place(head.title, chapter.title or "", 5)
    Place(head.sub, chapter.sub, 4)
    head.mark:ClearAllPoints()
    head.mark:SetPoint("CENTER", head, "TOP", 0, -(y + 8))
    head.height = math.floor(y + 8 + 22 + 0.5)
    head:SetHeight(head.height)
end

---------------------------------------------------------------------------
-- Event
---------------------------------------------------------------------------

local function CreateEvent(book)
    local event = CreateFrame("Frame", nil, book)
    event:SetWidth(book.width)

    -- Its piece of the line, and the dot that sits on it.
    event.trail = event:CreateTexture(nil, "BACKGROUND")
    event.trail:SetWidth(UI.Pixel(event))
    event.trail:SetPoint("TOP", event, "TOP", 0, 0)
    event.trail:SetPoint("BOTTOM", event, "BOTTOM", 0, 0)
    UI.Paint(event.trail, "accentTrail")
    event.ring = UI.Icon(event, "circle", DOT, "accentLine", "BORDER")
    event.core = UI.Icon(event, "circle", DOT - 2, "window", "ARTWORK")
    event.core:SetPoint("CENTER", event.ring, "CENTER")
    event.mark = UI.Icon(event, "sparkle", 14, "accent", "OVERLAY")
    event.mark:SetPoint("CENTER", event.ring, "CENTER")
    event.when = UI.Text(event, 11, "textMuted")
    event.when:SetWordWrap(false)

    local card = CreateFrame("Frame", nil, event)
    event.card = card
    -- A story with onClick can be clicked; its card lights up under the
    -- mouse. The mouse is only caught where there is something to do.
    card:SetScript("OnEnter", function()
        event.shape.border:SetColor("cardActive")
    end)
    card:SetScript("OnLeave", function()
        event.shape.border:SetColor(event.borderColor or "cardBorder")
    end)
    card:SetScript("OnMouseUp", function(_, button)
        local story = event.story
        if button == "LeftButton" and story and story.onClick then
            story.onClick()
        end
    end)
    event.glow = UI.Shadow(card, 16, 10, 0, "accentHaze")
    event.shape = UI.Card(card, "card", "cardBorder", 10)
    local sheen = UI.Line(card, "sheenSoft")
    sheen:SetPoint("TOPLEFT", 10, -UI.Pixel(card))
    sheen:SetPoint("TOPRIGHT", -10, -UI.Pixel(card))

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
    event.pictureShape = UI.Card(picture, "control", "controlBorder", 9)
    event.icon = picture:CreateTexture(nil, "ARTWORK")
    event.icon:SetPoint("CENTER")
    -- A picture of the game's own (an item's icon): in its own colours, with
    -- the icon's border cut off, inside the rounded frame.
    event.photo = picture:CreateTexture(nil, "ARTWORK")
    event.photo:SetPoint("CENTER")
    event.photo:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    event.number = picture:CreateFontString(nil, "OVERLAY")
    event.number:SetPoint("CENTER", 0, -1)
    event.number:SetJustifyH("CENTER")

    event.title = UI.Text(card, 14, "text", "semibold")
    event.title:SetSpacing(1)
    event.detail = UI.Text(card, 12, "textMuted")
    event.detail:SetSpacing(2)
    event.chipDot = UI.Icon(card, "circle", 18, "accentSoft")
    event.chipInitial = UI.Text(card, 10, "accent", "semibold")
    event.chipInitial:SetPoint("CENTER", event.chipDot, "CENTER")
    event.chipInitial:SetJustifyH("CENTER")
    event.chipText = UI.Text(card, 11, "textMuted")
    event.chipText:SetPoint("LEFT", event.chipDot, "RIGHT", 6, 0)
    event.chipText:SetWordWrap(false)
    return event
end

-- onLeft: the card stands left of the line, the time right of it.
local function EventSet(event, story, onLeft, width)
    event.story = story
    event.onLeft = onLeft
    local look = PICTURES[story.kind] or PICTURES.zone
    local big = story.big and true or false
    local pad = big and 16 or 12
    local size = big and PICTURE_BIG or PICTURE
    local column = (width - AXIS) / 2
    local textWidth = column - pad * 2 - size - 12

    -- Picture: an icon, or a number (a level, a skill).
    event.picture:SetSize(size, size)
    event.picture:EnableMouse(story.item ~= nil or story.spell ~= nil)
    event.pictureShape.border:SetColor(look.border)
    event.pictureShape.fill:SetColor(look.fill)
    local photo = story.texture
    local icon = not photo and look.icon and (story.icon or look.icon) or nil
    local number = not photo and not icon and story.number
    event.photo:SetShown(photo ~= nil)
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
    elseif number then
        UI.SetDisplayFont(event.number, big and 30 or 24)
        UI.Ink(event.number, look.ink)
        event.number:SetText(tostring(number))
    end
    event.mark:SetTexture(UI.media[icon or story.icon or look.mark] or UI.media[look.mark])

    -- Text: headline, detail, and whom it is about.
    event.title:SetWidth(textWidth)
    event.title:SetText(story.title or "")
    UI.SetFont(event.title, big and 16 or 14, "semibold")
    UI.Ink(event.title, look.title or "text")
    local textHeight = event.title:GetStringHeight()
    local detail = story.detail
    event.detail:SetShown(detail ~= nil)
    if detail then
        event.detail:SetWidth(textWidth)
        event.detail:SetText(detail)
        textHeight = textHeight + 4 + event.detail:GetStringHeight()
    end
    local chip = story.chip
    event.chipDot:SetShown(chip ~= nil)
    event.chipInitial:SetShown(chip ~= nil)
    event.chipText:SetShown(chip ~= nil)
    if chip then
        event.chipInitial:SetText(chip.initial or "")
        event.chipText:SetWidth(textWidth - 24)
        event.chipText:SetText(chip.text or "")
        textHeight = textHeight + 8 + 18
    end

    local cardHeight = math.floor(math.max(size, textHeight) + pad * 2 + 0.5)
    local card = event.card
    card:SetSize(column, cardHeight)
    card:ClearAllPoints()
    card:SetPoint(onLeft and "TOPLEFT" or "TOPRIGHT", event, onLeft and "TOPLEFT" or "TOPRIGHT", 0, 0)
    event.borderColor = big and "cardActive" or "cardBorder"
    event.shape.border:SetColor(event.borderColor)
    card:EnableMouse(story.onClick ~= nil)
    event.glow:SetShown(big)

    event.picture:ClearAllPoints()
    event.picture:SetPoint("LEFT", card, "LEFT", pad, 0)
    local left = pad + size + 12
    local top = math.floor((cardHeight - textHeight) / 2 + 0.5)
    event.title:ClearAllPoints()
    event.title:SetPoint("TOPLEFT", card, "TOPLEFT", left, -top)
    local last = event.title
    if detail then
        event.detail:ClearAllPoints()
        event.detail:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -4)
        last = event.detail
    end
    if chip then
        event.chipDot:ClearAllPoints()
        event.chipDot:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -8)
    end

    -- The dot at the height of the card's middle, the time beyond it.
    local middle = -cardHeight / 2
    event.ring:ClearAllPoints()
    event.ring:SetPoint("CENTER", event, "TOP", 0, middle)
    event.when:ClearAllPoints()
    event.when:SetJustifyH(onLeft and "LEFT" or "RIGHT")
    event.when:SetPoint(onLeft and "LEFT" or "RIGHT", event, "TOP", (onLeft and 1 or -1) * (AXIS / 2 + 4), middle)
    event.when:SetText(story.when or "")

    event.height = cardHeight + GAP
    event:SetHeight(event.height)
end

---------------------------------------------------------------------------

function UI.Book(parent, width)
    local book = CreateFrame("Frame", nil, parent)
    book:SetWidth(width)
    book.width = width
    book.heads, book.events = {}, {}
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
            for position, story in ipairs(chapter.events) do
                eventCount = eventCount + 1
                local event = self.events[eventCount]
                if not event then
                    event = CreateEvent(self)
                    self.events[eventCount] = event
                end
                EventSet(event, story, position % 2 == 1, self.width)
                event:ClearAllPoints()
                event:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
                event:Show()
                y = y + event.height
            end
            y = y + 10
        end
        for index = #chapters + 1, #self.heads do
            self.heads[index]:Hide()
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
