-- What a card of the chronicle's book holds (UI/Book.lua): a sunken strip
-- at the top with whose event it is and when, below it the picture, and
-- beside that the text and the place in the foot. The card is as high as
-- that needs. The book sets the room inside the card's edge (UI.BookPad),
-- the same on every side, below the strip too; the event's weight sets the
-- picture and the headline. The text keeps the same distance from the picture.
--
--   story = {
--       content = UI.ChronicleCard,
--       weight = "low" or "medium" or "high", -- see WEIGHTS
--       kind, texture, icon, number, count, item, spell, -- the picture (UI.SetBookPicture)
--       chip = { text = "Companion" },        -- whose it is
--       when = "21:14" or "20:02 – 21:14", -- at the strip's right
--       title = "Fallen", detail = "at level 13" or nil,
--       place = "Duskwood" or nil, -- the foot; without a place and a reaction, none
--       reaction = {               -- or nil: a button at the foot's right, as
--           icon = "cheer",        -- on the live feed's cards (UI.ReactionButton);
--           lit = true,            -- in the accent once given or received,
--           count = 3,             -- and how many there are
--           onClick = function() end,    -- optional: what a click on it does
--           tooltip = function(tip) end, -- optional: what the mouse on it shows
--       },
--   }

local _, ns = ...
local UI = ns.UI

local LINE, LINE_GAP = 14, 4 -- the foot, and its distance from the text
local STRIP = 28 -- the sunken strip at the top that names whose event it is
local TIME_GAP = 8 -- between the name and the time at the strip's right
local TEXT_GAP = 12 -- between the picture and the text, whatever its size
local REACT, REACT_ICON = 26, 16 -- the reaction's button at the foot's right, and its icon
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
    -- Whose event it is: the name, a step brighter than the time beside it.
    part.chipText = UI.Text(strip, 11, "textDim")
    part.chipText:SetWordWrap(false)
    -- And on the right, when: as wide as its text, the name ends before it.
    part.time = UI.Text(strip, 11, "textMuted")
    part.time:SetWordWrap(false)
    part.time:SetPoint("RIGHT", strip, "RIGHT", -UI.BookPad, 0)
    part.title = UI.Text(part, 13, "text", "medium")
    part.title:SetSpacing(1)
    part.detail = UI.Text(part, 12, "textMuted")
    part.detail:SetSpacing(2)
    part.detail:SetPoint("TOPLEFT", part.title, "BOTTOMLEFT", 0, -4)
    part.place = UI.Text(part, 11, "textMuted")
    part.place:SetWordWrap(false)
    -- The reaction at the foot's right: the same button as on the live
    -- feed's cards. On a friend's card a click reacts or takes it back; on
    -- the player's own it shows on the mouse who reacted. Only the button
    -- reacts, not the card.
    local react = UI.ReactionButton(part, REACT, REACT_ICON)
    part.react = react
    local function HideTip(self)
        if GameTooltip.IsOwned and GameTooltip:IsOwned(self) then
            GameTooltip:Hide()
        end
    end
    react:SetScript("OnEnter", function(self)
        local reaction = self.reaction
        if not reaction then
            return
        end
        self.over = true
        if reaction.onClick then
            self.hover:Fade(true)
        end
        self:Paint()
        if reaction.tooltip then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            reaction.tooltip(GameTooltip)
            GameTooltip:Show()
        end
    end)
    react:SetScript("OnLeave", function(self)
        self.over = false
        self.hover:Fade(false)
        if self.reaction then
            self:Paint()
        end
        HideTip(self)
    end)
    react:SetScript("OnClick", function(self)
        local reaction = self.reaction
        if reaction and reaction.onClick then
            -- What the tooltip said no longer holds after the click.
            HideTip(self)
            reaction.onClick()
        end
    end)
    react:SetScript("OnHide", function(self)
        self.over = false
        self.hover:Hide()
        HideTip(self)
    end)
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

    -- The strip: whose event it is, and when. The name runs up to the time
    -- and is cut off there; the time is never.
    local chip = story.chip or {}
    part.time:SetText(story.when or "")
    part.chipText:ClearAllPoints()
    part.chipText:SetPoint("RIGHT", part.time, "LEFT", -TIME_GAP, 0)
    part.chipText:SetPoint("LEFT", part.strip, "LEFT", pad, 0)
    part.chipText:SetText(chip.text or "")

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
    local react = part.react
    react.reaction = reaction
    react:SetShown(reaction ~= nil)
    if reaction then
        react.over = false
        react.hover:Hide()
        react:Set(reaction.icon, reaction.lit, reaction.count)
        react:EnableMouse(reaction.onClick ~= nil or reaction.tooltip ~= nil)
        reactionWidth = FOOT_GAP + react:GetWidth()
    end

    -- The foot: where, beside the reaction. Without either there is none.
    part.place:SetShown(story.place ~= nil)
    part.place:SetWidth(math.max(1, textWidth - reactionWidth))
    part.place:SetText(story.place or "")
    local foot = story.place ~= nil or reaction ~= nil

    -- The strip above, then picture and text side by side: both begin at
    -- the same height, and the foot ends with the taller of the two.
    -- Below the strip the room is the book's at the sides: the strip's line
    -- takes a pixel of it like the frame's hairline does.
    local body = STRIP + pad - 1
    local blockHeight = textHeight + (foot and LINE_GAP + LINE or 0)
    local bodyHeight = math.max(size, blockHeight)
    local height = math.floor(body + bodyHeight + pad + 0.5)
    local left = pad + size + TEXT_GAP
    part.picture:ClearAllPoints()
    part.picture:SetPoint("TOPLEFT", part, "TOPLEFT", pad, -body)
    part.title:ClearAllPoints()
    part.title:SetPoint("TOPLEFT", part, "TOPLEFT", left, -body)
    part.place:ClearAllPoints()
    part.place:SetPoint("TOPLEFT", part, "TOPLEFT", left, -(body + bodyHeight - LINE))
    -- The button at the card's right edge, on the foot's line.
    react:ClearAllPoints()
    react:SetPoint("RIGHT", part, "TOPRIGHT", -pad, -(body + bodyHeight - LINE / 2))
    return height
end
