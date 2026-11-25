-- What a card of the chronicle's book holds (UI/Book.lua): whose event it
-- is in a sunken strip at the top (none for the player's own), below it
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
--       chip = { initial = "A", text = "Companion", class = "MAGE" or nil } or nil,
--       title = "Fallen", detail = "at level 13" or nil,
--       footer = "21:14  ·  Duskwood",
--   }

local _, ns = ...
local UI = ns.UI

local LINE, LINE_GAP = 14, 4 -- the foot, and its distance from the text
local STRIP = 28 -- the sunken strip at the top that names whose event it is
local CHIP = 18 -- the class icon or initial in it
local TEXT_GAP = 12 -- between the picture and the text, whatever its size

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
    part.chipDot = UI.Icon(strip, "circle", CHIP, "accentSoft")
    part.chipDot:SetPoint("LEFT", strip, "LEFT", UI.BookPad, 0)
    part.chipInitial = UI.Text(strip, 10, "accent", "semibold")
    part.chipInitial:SetPoint("CENTER", part.chipDot, "CENTER")
    part.chipInitial:SetJustifyH("CENTER")
    -- Where the class is known, its icon instead of the initial.
    part.chipClass = UI.ClassIcon(strip, CHIP)
    part.chipClass:SetPoint("CENTER", part.chipDot, "CENTER")
    part.chipText = UI.Text(strip, 11, "textMuted")
    part.chipText:SetPoint("LEFT", part.chipDot, "RIGHT", 6, 0)
    part.chipText:SetWordWrap(false)
    part.title = UI.Text(part, 13, "text", "medium")
    part.title:SetSpacing(1)
    part.detail = UI.Text(part, 12, "textMuted")
    part.detail:SetSpacing(2)
    part.detail:SetPoint("TOPLEFT", part.title, "BOTTOMLEFT", 0, -4)
    part.footer = UI.Text(part, 11, "textMuted")
    part.footer:SetWordWrap(false)
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

    -- The head: whose event it is.
    local chip = story.chip
    local classShown = UI.SetClass(part.chipClass, chip and chip.class)
    part.strip:SetShown(chip ~= nil)
    part.chipDot:SetShown(chip ~= nil and not classShown)
    part.chipInitial:SetShown(chip ~= nil and not classShown)
    part.chipText:SetShown(chip ~= nil)
    if chip then
        part.chipInitial:SetText(chip.initial or "")
        part.chipText:SetWidth(width - pad * 2 - CHIP - 6)
        part.chipText:SetText(chip.text or "")
    end

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

    -- The foot: when and where.
    part.footer:SetShown(story.footer ~= nil)
    part.footer:SetWidth(textWidth)
    part.footer:SetText(story.footer or "")

    -- The strip above, then picture and text side by side: both begin at
    -- the same height, and the foot ends with the taller of the two.
    -- Below the strip the room is the book's at the sides: the strip's line
    -- takes a pixel of it like the frame's hairline does.
    local body = chip and STRIP + pad - 1 or UI.BookPadTop
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
    return height
end
