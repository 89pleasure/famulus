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
--           kind = "level",             -- see PICTURES
--           title = "Reached level 24", detail = "in Lakeshire" or nil,
--           when = "21:14",             -- optional: closes the detail line
--           weight = "low" or "medium" or "high", -- optional: size and look of
--                                       -- the card, see WEIGHTS
--           -- How the text is built is up to the caller (the chronicle uses all three):
--           head = true,                -- a line above the text, kept even when
--                                       -- empty; it shows the chip
--           lines = 2,                  -- the text keeps at least this many lines
--           footer = "21:14  ·  Lakeshire", -- a line below the text
--           count = 2,                  -- a bundle: how often, in the corner
--           number = 24,                -- shown in the picture of a level
--           icon = "horseshoe",         -- optional: a picture of its own (UI.media)
--           onClick = function() end,   -- optional: what a click on the card does
--           item = 211527, spell = 33388, -- optional: the picture shows the game's
--                                       -- tooltip of this item or spell
--           texture = 134400,           -- optional: a texture of the game's instead
--                                       -- (an item's icon), shown in its own colours
--           big = true,                 -- without a weight: as heavy as "high"
--           chip = { initial = "A", text = "Companion", class = "MAGE" or nil } or nil,
--                                       -- whose event it is, in the head
--           -- The fellow travellers' timeline adds:
--           noPicture = true,           -- the text takes the card's whole width
--           crest = { name = "Mira Stormfeather", class = "MAGE", progress = 0.4 },
--                                       -- a person's crest instead of the picture
--           people = { { name = "Mira", class = "MAGE", note = "until 22:40" or nil } },
--                                       -- below the text, a plate per person
--           foot = "Again with Mira and Borin", -- the strip below, in the accent
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
local FOOT = 30 -- the sunken strip below a fellow traveller's card
local PHOTO_INSET = 2 -- an icon of the game fills its frame but for a fine line
local DOT_GAP = DOT + 12 -- between the dots of two events on the line
local HEAD_TOP, HEAD_BOTTOM = 6, 16 -- room above and below a chapter's heading
local HEAD_GAP = 16 -- between the place and the words beside it
local CHAPTER_GAP = 16 -- below a chapter's last card
local CHIP_GAP = 4 -- between two plates of people
local HEAD_LINE, LINE_GAP = 14, 4 -- a chronicle's card: head and foot line, and the gap to the text
local ROUTE_GAP, ROUTE_H, ROUTE_PAD = 8, 22, 9 -- the route below a heading
local ROUTE_ARROW = 10 -- the arrow between two zones of the route
local ROUTE_STEP = 6 -- between a plate and an arrow
local PERSON_H, PERSON_ICON = 22, 16 -- a person's plate

-- How much an event weighs (story.weight): the card's padding, its
-- picture and headline. A heavy one is a milestone: accent border and mark.
local WEIGHTS = {
    low = { pad = 8, picture = 40, title = 12, font = "medium", number = 18 },
    medium = { pad = 12, picture = PICTURE, title = 13, font = "medium", number = 24 },
    high = { pad = 15, picture = PICTURE, title = 15, font = "semibold", number = 24 },
}

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
            UI.Card(plate, "field", "cardBorder", 6)
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

    event.title = UI.Text(card, 13, "text", "medium")
    event.title:SetSpacing(1)
    event.detail = UI.Text(card, 12, "textMuted")
    event.detail:SetSpacing(2)
    -- The head of a chronicle's card: whose event it is (empty for the
    -- player's own), the class icon, else the initial.
    event.chipDot = UI.Icon(card, "circle", HEAD_LINE, "accentSoft")
    event.chipInitial = UI.Text(card, 9, "accent", "semibold")
    event.chipInitial:SetPoint("CENTER", event.chipDot, "CENTER")
    event.chipInitial:SetJustifyH("CENTER")
    event.chipClass = UI.ClassIcon(card, HEAD_LINE)
    event.chipClass:SetPoint("CENTER", event.chipDot, "CENTER")
    event.chipText = UI.Text(card, 11, "textDim", "medium")
    event.chipText:SetPoint("LEFT", event.chipDot, "RIGHT", 5, 0)
    event.chipText:SetWordWrap(false)
    -- And its foot: time and place.
    event.footer = UI.Text(card, 11, "textMuted")
    event.footer:SetWordWrap(false)
    -- Or the strip says something about the event itself, in the accent.
    event.footIcon = UI.Icon(foot, "people", 13, "accent")
    event.footIcon:SetPoint("LEFT", foot, "LEFT", 12, 0)
    event.footText = UI.Text(foot, 11, "accent2", "medium")
    event.footText:SetPoint("LEFT", event.footIcon, "RIGHT", 7, 0)
    event.footText:SetWordWrap(false)
    event.people = {} -- the plates of the people in it
    return event
end

UI.BookPictures = PICTURES

-- The people of an event as plates (class icon, else the initial, the name
-- and a note), row after row within `width`, placed like the times above.
local function LayPeople(event, people, width)
    local list = people or {}
    local x, y = 0, 0
    for index, each in ipairs(list) do
        local plate = event.people[index]
        if not plate then
            plate = CreateFrame("Frame", nil, event.card)
            plate:SetHeight(PERSON_H)
            UI.Card(plate, "field", "cardBorder", PERSON_H / 2)
            plate.disc = UI.Icon(plate, "circle", PERSON_ICON, "chip")
            plate.disc:SetPoint("LEFT", 3, 0)
            plate.initial = UI.Text(plate, 9, "textDim", "semibold")
            plate.initial:SetPoint("CENTER", plate.disc, "CENTER")
            plate.initial:SetJustifyH("CENTER")
            plate.initial:SetJustifyV("MIDDLE")
            plate.class = UI.ClassIcon(plate, PERSON_ICON)
            plate.class:SetPoint("CENTER", plate.disc, "CENTER")
            plate.name = UI.Text(plate, 11, "textDim", "medium")
            plate.name:SetPoint("LEFT", plate.disc, "RIGHT", 5, 0)
            plate.name:SetWordWrap(false)
            plate.note = UI.Text(plate, 11, "textMuted")
            plate.note:SetPoint("LEFT", plate.name, "RIGHT", 5, 0)
            plate.note:SetWordWrap(false)
            event.people[index] = plate
        end
        local classShown = UI.SetClass(plate.class, each.class)
        plate.disc:SetShown(not classShown)
        plate.initial:SetShown(not classShown)
        plate.initial:SetText(UI.Initial(each.name))
        plate.note:SetShown(each.note ~= nil)
        plate.note:SetText(each.note or "")
        local noteWidth = each.note and 5 + plate.note:GetStringWidth() or 0
        local room = width - 3 - PERSON_ICON - 5 - noteWidth - 9
        plate.name:SetText(each.name or "")
        plate.name:SetWidth(math.max(1, math.min(plate.name:GetStringWidth() + 1, room)))
        local plateWidth = math.floor(3 + PERSON_ICON + 5 + plate.name:GetWidth() + noteWidth + 9 + 0.5)
        plate:SetWidth(plateWidth)
        if x > 0 and x + plateWidth > width then
            x, y = 0, y + PERSON_H + CHIP_GAP
        end
        plate.x, plate.y = x, y
        plate:Show()
        x = x + plateWidth + CHIP_GAP
    end
    for index = #list + 1, #event.people do
        event.people[index]:Hide()
    end
    event.peopleCount = #list
    return #list > 0 and y + PERSON_H or 0
end

-- onLeft: the card stands left of the line. Sets event.cardHeight.
local function EventSet(event, story, onLeft, width)
    event.story = story
    event.onLeft = onLeft
    local look = PICTURES[story.kind] or PICTURES.zone
    local weight = WEIGHTS[story.weight] or story.big and WEIGHTS.high or WEIGHTS.medium
    local big = weight == WEIGHTS.high
    local pad = weight.pad
    local size = story.noPicture and 0 or weight.picture
    local column = (width - AXIS) / 2
    local beside = size > 0 and size + 12 or 0 -- the text's distance from the picture's left edge
    local textWidth = column - pad * 2 - beside

    -- Picture: an icon, or a number (a level, a skill); or a person's crest.
    local crest = story.crest
    event.picture:SetShown(size > 0 and crest == nil)
    if crest and not event.crest then
        event.crest = UI.Crest(event.card, PICTURE)
    end
    if event.crest then
        event.crest:SetShown(crest ~= nil and size > 0)
        if crest then
            event.crest:SetPerson(crest.name, crest.class)
            event.crest:SetProgress(crest.progress)
        end
    end
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
        UI.SetDisplayFont(event.number, weight.number)
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

    -- Text: headline and detail, below them the people.
    event.title:SetWidth(textWidth)
    event.title:SetText(story.title or "")
    UI.SetFont(event.title, weight.title, weight.font)
    UI.Ink(event.title, look.title or "text")
    local textHeight = event.title:GetStringHeight()
    -- The time closes the line below the headline.
    local detail = story.detail
    if story.when then
        detail = detail and (detail .. "  ·  " .. story.when) or story.when
    end
    event.detail:SetShown(detail ~= nil)
    if detail then
        event.detail:SetWidth(textWidth)
        event.detail:SetText(detail)
        textHeight = textHeight + 4 + event.detail:GetStringHeight()
    end
    if story.lines then
        textHeight = math.max(textHeight, story.lines * (weight.title + 4))
    end
    local peopleTop = textHeight + 8
    local peopleHeight = LayPeople(event, story.people, textWidth)
    if peopleHeight > 0 then
        textHeight = peopleTop + peopleHeight
    end
    -- The head (whose event it is, or empty) and the foot line.
    local chip = story.head and story.chip or nil
    local classShown = UI.SetClass(event.chipClass, chip and chip.class)
    event.chipDot:SetShown(chip ~= nil and not classShown)
    event.chipInitial:SetShown(chip ~= nil and not classShown)
    event.chipText:SetShown(chip ~= nil)
    if chip then
        event.chipInitial:SetText(chip.initial or "")
        event.chipText:SetWidth(textWidth - HEAD_LINE - 5)
        event.chipText:SetText(chip.text or "")
    end
    local footer = story.footer
    event.footer:SetShown(footer ~= nil)
    if footer then
        event.footer:SetWidth(textWidth)
        event.footer:SetText(footer)
    end
    local textTop = story.head and HEAD_LINE + LINE_GAP or 0
    textHeight = textTop + textHeight + (footer and LINE_GAP + HEAD_LINE or 0)
    -- A sunken strip below says, in the accent, what
    -- the event itself adds.
    local footText = story.foot
    event.foot:SetShown(footText ~= nil)
    event.footIcon:SetShown(footText ~= nil)
    event.footText:SetShown(footText ~= nil)
    if footText then
        event.footText:SetWidth(column - 12 - 13 - 7 - 12)
        event.footText:SetText(footText)
    end

    local bodyHeight = math.floor(math.max(size, textHeight) + pad * 2 + 0.5)
    local cardHeight = bodyHeight + (footText and FOOT or 0)
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
    if event.crest then
        event.crest:ClearAllPoints()
        event.crest:SetPoint("TOPLEFT", card, "TOPLEFT", pad, -math.floor((bodyHeight - size) / 2 + 0.5))
    end
    local left = pad + beside
    local top = math.floor((bodyHeight - textHeight) / 2 + 0.5)
    event.chipDot:ClearAllPoints()
    event.chipDot:SetPoint("TOPLEFT", card, "TOPLEFT", left, -top)
    event.footer:ClearAllPoints()
    event.footer:SetPoint("TOPLEFT", card, "TOPLEFT", left, -(top + textHeight - HEAD_LINE))
    top = top + textTop
    event.title:ClearAllPoints()
    event.title:SetPoint("TOPLEFT", card, "TOPLEFT", left, -top)
    local last = event.title
    if detail then
        event.detail:ClearAllPoints()
        event.detail:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -4)
    end
    for index = 1, event.peopleCount do
        local plate = event.people[index]
        plate:ClearAllPoints()
        plate:SetPoint("TOPLEFT", card, "TOPLEFT", left + plate.x, -(top + peopleTop + plate.y))
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
