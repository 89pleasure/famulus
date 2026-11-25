-- What a card of the chronicle's book holds (UI/Book.lua): its picture,
-- and beside it whose event it is in the head (none for the player's own),
-- the text, and the time and place in the foot. The card is as high as
-- that needs; the event's weight sets the picture, the room above and
-- below, and the headline. Picture and text keep the same left edges on
-- every card, so that the book reads calmly.
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

local LINE, LINE_GAP = 14, 4 -- the head and the foot, and their distance from the text
local SIDE = 14 -- left of the picture's column and right of the text
local COLUMN = 54 -- the picture's column; a smaller picture stands in its middle
local TEXT_GAP = 12 -- between the picture's column and the text

-- How much an event weighs: its picture, the room above and below, and the
-- headline. A heavy one is also a milestone (story.big, the book's accent).
local WEIGHTS = {
    low = { pad = 8, picture = 40, title = 12, font = "medium", number = 18 },
    medium = { pad = 12, picture = COLUMN, title = 13, font = "medium", number = 24 },
    high = { pad = 15, picture = COLUMN, title = 15, font = "semibold", number = 24 },
}

local function Build(part)
    UI.BookPicture(part)
    part.chipDot = UI.Icon(part, "circle", LINE, "accentSoft")
    part.chipInitial = UI.Text(part, 9, "accent", "semibold")
    part.chipInitial:SetPoint("CENTER", part.chipDot, "CENTER")
    part.chipInitial:SetJustifyH("CENTER")
    -- Where the class is known, its icon instead of the initial.
    part.chipClass = UI.ClassIcon(part, LINE)
    part.chipClass:SetPoint("CENTER", part.chipDot, "CENTER")
    part.chipText = UI.Text(part, 11, "textDim", "medium")
    part.chipText:SetPoint("LEFT", part.chipDot, "RIGHT", 5, 0)
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
    local pad, size = weight.pad, weight.picture
    local textWidth = width - SIDE * 2 - COLUMN - TEXT_GAP
    UI.SetBookPicture(part, story, size, weight.number)

    -- The head: whose event it is.
    local chip = story.chip
    local classShown = UI.SetClass(part.chipClass, chip and chip.class)
    part.chipDot:SetShown(chip ~= nil and not classShown)
    part.chipInitial:SetShown(chip ~= nil and not classShown)
    part.chipText:SetShown(chip ~= nil)
    if chip then
        part.chipInitial:SetText(chip.initial or "")
        part.chipText:SetWidth(textWidth - LINE - 5)
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

    local headHeight = chip and LINE + LINE_GAP or 0
    local blockHeight = headHeight + textHeight + LINE_GAP + LINE
    local height = math.floor(math.max(size, blockHeight) + pad * 2 + 0.5)
    local left = SIDE + COLUMN + TEXT_GAP
    local top = math.floor((height - blockHeight) / 2 + 0.5)
    part.picture:ClearAllPoints()
    part.picture:SetPoint("TOPLEFT", part, "TOPLEFT", SIDE + math.floor((COLUMN - size) / 2 + 0.5),
        -math.floor((height - size) / 2 + 0.5))
    part.chipDot:ClearAllPoints()
    part.chipDot:SetPoint("TOPLEFT", part, "TOPLEFT", left, -top)
    part.title:ClearAllPoints()
    part.title:SetPoint("TOPLEFT", part, "TOPLEFT", left, -(top + headHeight))
    part.footer:ClearAllPoints()
    part.footer:SetPoint("TOPLEFT", part, "TOPLEFT", left, -(top + blockHeight - LINE))
    return height
end
