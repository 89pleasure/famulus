-- What a card of the chronicle's book holds (UI/Book.lua): a sunken strip
-- at the top with whose event it is and the icon of its kind, below it
-- the picture, and beside that the text and the time and place in the
-- foot. The card is as high as
-- that needs. The book sets the room inside the card's edge (UI.BookPad),
-- the same on every side, below the strip too; the event's weight sets the
-- picture and the headline. The text keeps the same distance from the picture.
--
--   story = {
--       content = UI.ChronicleCard,
--       weight = "low" or "medium" or "high", -- see WEIGHTS
--       kind, texture, icon, number, count, item, spell, -- the picture (UI.SetBookPicture)
--       chip = { text = "Companion", class = "MAGE" or nil },
--       title = "Fallen", detail = "at level 13" or nil,
--       footer = "21:14  ·  Duskwood",
--       reaction = { icon = "cheer", lit = true, count = 3 } or nil, -- at the
--               -- foot's right: the reaction, in the accent once given or
--               -- received, and how many there are
--   }

local _, ns = ...
local UI = ns.UI

local LINE, LINE_GAP = 14, 4 -- the foot, and its distance from the text
local STRIP = 28 -- the sunken strip at the top that names whose event it is
local CHIP = 18 -- the class icon in it
local KIND = 13 -- the icon of the event's kind, on the strip's right
local TEXT_GAP = 12 -- between the picture and the text, whatever its size
local REACTION = 18 -- the reaction's icon, at the foot's right
local REACTION_GAP = 4 -- between it and its count
local FOOT_GAP = 10 -- between the foot's text and the reaction

-- How much an event weighs: its picture and headline. The book makes a
-- heavier card wider; a heavy one is also a milestone (story.big, the book's accent).
local WEIGHTS = {
    low = { picture = 40, title = 12, font = "medium", number = 18 },
    medium = { picture = 48, title = 13, font = "medium", number = 22 },
    high = { picture = 56, title = 15, font = "semibold", number = 26 },
}

local function Build(part)
    UI.BookPicture(part)
    -- The strip is sunken like an option under its feature, round at the
    -- card's top corners, with a fine line below.
    local pixel = UI.Pixel(part)
    local strip = CreateFrame("Frame", nil, part)
    part.strip = strip
    strip:SetHeight(STRIP)
    strip:SetPoint("TOPLEFT")
    strip:SetPoint("TOPRIGHT")
    UI.Round(strip, "sunken", 9, { inset = pixel, square = { BOTTOMLEFT = true, BOTTOMRIGHT = true } })
    local stripLine = UI.Line(strip)
    stripLine:SetPoint("BOTTOMLEFT", pixel, 0)
    stripLine:SetPoint("BOTTOMRIGHT", -pixel, 0)
    -- Whose event it is: the class icon where it is known, and the name.
    part.chipClass = UI.ClassIcon(strip, CHIP)
    part.chipClass:SetPoint("LEFT", strip, "LEFT", UI.BookPad, 0)
    part.chipText = UI.Text(strip, 11, "textMuted")
    part.chipText:SetWordWrap(false)
    -- And on the right, the icon of its kind.
    part.kindIcon = UI.Icon(strip, "sparkle", KIND, "accent")
    part.kindIcon:SetPoint("RIGHT", strip, "RIGHT", -UI.BookPad, 0)
    part.title = UI.Text(part, 13, "text", "medium")
    part.title:SetSpacing(1)
    part.detail = UI.Text(part, 12, "textMuted")
    part.detail:SetSpacing(2)
    part.detail:SetPoint("TOPLEFT", part.title, "BOTTOMLEFT", 0, -4)
    part.footer = UI.Text(part, 11, "textMuted")
    part.footer:SetWordWrap(false)
    -- A reaction at the foot's right: its icon, and how many there are.
    part.reaction = UI.Icon(part, "cheer", REACTION, "textMuted")
    part.reactionCount = UI.Text(part, 11, "textMuted", "semibold")
    part.reactionCount:SetWordWrap(false)
end

function UI.ChronicleCard(part, story, width)
    if not part.title then
        Build(part)
    end
    local weight = WEIGHTS[story.weight] or WEIGHTS.medium
    local look = UI.BookPictures[story.kind] or UI.BookPictures.zone
    local pad, size = UI.BookPad, weight.picture
    local textWidth = width - pad * 2 - size - TEXT_GAP
    UI.SetBookPicture(part, story, size, weight.number)

    -- The strip: whose event it is, and the icon of its kind.
    local chip = story.chip or {}
    local classShown = UI.SetClass(part.chipClass, chip.class)
    local nameLeft = pad + (classShown and CHIP + 6 or 0)
    part.chipText:ClearAllPoints()
    part.chipText:SetPoint("LEFT", part.strip, "LEFT", nameLeft, 0)
    part.chipText:SetWidth(math.max(1, width - nameLeft - pad - KIND - 8))
    part.chipText:SetText(chip.text or "")
    part.kindIcon:SetTexture(UI.media[story.icon or look.mark] or UI.media[look.mark])

    -- The text, as high as it is.
    part.title:SetWidth(textWidth)
    part.title:SetText(story.title or "")
    UI.SetFont(part.title, weight.title, weight.font)
    UI.Ink(part.title, look.title or "text")
    local textHeight = part.title:GetStringHeight()
    part.detail:SetShown(story.detail ~= nil)
    if story.detail then
        part.detail:SetWidth(textWidth)
        part.detail:SetText(story.detail)
        textHeight = textHeight + 4 + part.detail:GetStringHeight()
    end

    -- The reaction, at the foot's right: muted until given or received.
    local reaction, reactionWidth = story.reaction, 0
    local counted = reaction ~= nil and (reaction.count or 0) > 0
    part.reaction:SetShown(reaction ~= nil)
    part.reactionCount:SetShown(counted)
    if reaction then
        local ink = reaction.lit and "accent" or "textMuted"
        part.reaction:SetTexture(UI.media[reaction.icon] or UI.media.cheer)
        UI.Tint(part.reaction, ink)
        UI.Ink(part.reactionCount, ink)
        part.reactionCount:SetText(counted and tostring(reaction.count) or "")
        reactionWidth = FOOT_GAP + REACTION + (counted and REACTION_GAP + part.reactionCount:GetStringWidth() or 0)
    end

    -- The foot: when and where.
    part.footer:SetShown(story.footer ~= nil)
    part.footer:SetWidth(math.max(1, textWidth - reactionWidth))
    part.footer:SetText(story.footer or "")

    -- The strip above, then picture and text side by side: both begin at
    -- the same height, and the foot ends with the taller of the two.
    -- Below the strip the room is the book's at the sides: the strip's line
    -- takes a pixel of it like the frame's hairline does.
    local body = STRIP + pad - 1
    local blockHeight = textHeight + LINE_GAP + LINE
    local bodyHeight = math.max(size, blockHeight)
    local height = math.floor(body + bodyHeight + pad + 0.5)
    local left = pad + size + TEXT_GAP
    part.picture:ClearAllPoints()
    part.picture:SetPoint("TOPLEFT", part, "TOPLEFT", pad, -body)
    part.title:ClearAllPoints()
    part.title:SetPoint("TOPLEFT", part, "TOPLEFT", left, -body)
    part.footer:ClearAllPoints()
    part.footer:SetPoint("TOPLEFT", part, "TOPLEFT", left, -(body + bodyHeight - LINE))
    -- The count at the card's right edge, the icon before it; on the foot's line.
    local footMiddle = -(body + bodyHeight - LINE / 2)
    part.reactionCount:ClearAllPoints()
    part.reactionCount:SetPoint("RIGHT", part, "TOPRIGHT", -pad, footMiddle)
    part.reaction:ClearAllPoints()
    if counted then
        part.reaction:SetPoint("RIGHT", part.reactionCount, "LEFT", -REACTION_GAP, 0)
    else
        part.reaction:SetPoint("RIGHT", part, "TOPRIGHT", -pad, footMiddle)
    end
    return height
end
