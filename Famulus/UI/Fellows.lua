-- The fellow travellers' overview: the three closest as tiles, everyone else
-- in a list; a click opens the person's story, which shows their card beside
-- a book. UI/Options.lua builds the model and places the parts.
--
--   local overview = UI.FellowOverview(content, cardParent, cardWidth)
--   local height = overview:SetModel(model, width)
--   overview:SetCard(person, inStory, actions) -- the card alone, beside a story
--
--   model = {
--       top = { person, ... },     -- at most three, the most time together first
--       rest = { person, ... },    -- the list, sorted by model.sort
--       more = <n>,                -- people beyond the list
--       sort = "last" | "time", sortValues = { { value, text }, ... },
--       onChoose(guid), onSort(value),
--       onWhisper(guid),           -- the speech bubble on tiles, rows and the card
--       onStory(guid), onAlias(guid), onForget(guid), -- the card's buttons
--       onChronicle(who),          -- beside a story: their events in the chronicle
--   }
--   person = { guid, name, realName, classFile, levelClass, tier, progress,
--              nextText, timeText, hours, minutes, statsText, times, bosses,
--              together, lastText, lastShort, firstText, firstLevelText,
--              whisper,             -- the client can open a whisper to them
--              chronicle }          -- beside a story: their name in the chronicle, if it has entries
--
-- Frames are made as needed and used again; nothing runs per frame.

local _, ns = ...
local L = ns.L
local UI = ns.UI

local GAP = 12 -- between tiles
local TILE_H = 222
local TITLE_H = 30 -- a section title and the space below it
local HEADS_H = 30 -- the list's column heads
local ROW_H = 54
local CARD_PAD = 20
local RANKS = { "I", "II", "III" }

local function Card(parent)
    local frame = CreateFrame("Button", nil, parent)
    frame.shape = UI.Card(frame, "card", "cardBorder", 10)
    local pixel = UI.Pixel(frame)
    local sheen = UI.Line(frame, "sheenSoft")
    sheen:SetPoint("TOPLEFT", 10, -pixel)
    sheen:SetPoint("TOPRIGHT", -10, -pixel)
    return frame
end

-- Chosen: a fine accent border, like the card of a running feature.
local function MarkChosen(frame, chosen)
    frame.shape.border:SetColor(chosen and "cardActive" or "cardBorder")
end

local function Centered(parent, size, token, weight)
    local text = UI.Text(parent, size, token, weight)
    text:SetJustifyH("CENTER")
    return text
end

---------------------------------------------------------------------------
-- Tiles
---------------------------------------------------------------------------

local function CreateTile(overview)
    local tile = Card(overview)
    tile:SetHeight(TILE_H)
    tile.rank = 0
    tile.numeral = UI.Text(tile, 18, "textMuted")
    UI.SetDisplayFont(tile.numeral, 18)
    tile.numeral:SetPoint("TOPLEFT", 16, -14)
    -- Opposite the rank: a whisper to them.
    tile.whisper = UI.IconButton(tile, "chat", function(self)
        overview.model.onWhisper(self:GetParent().guid)
    end, 28)
    tile.whisper:SetPoint("TOPRIGHT", -10, -9)
    tile.crest = UI.Crest(tile, 68)
    tile.crest:SetPoint("TOP", 0, -18)
    tile.name = Centered(tile, 17, "text")
    UI.SetDisplayFont(tile.name, 17)
    tile.name:SetPoint("TOP", tile.crest, "BOTTOM", 0, -10)
    tile.name:SetWordWrap(false)
    tile.sub = Centered(tile, 11, "textMuted")
    tile.sub:SetPoint("TOP", tile.name, "BOTTOM", 0, -5)
    tile.badge = UI.TierBadge(tile)
    tile.badge:SetPoint("TOP", tile.sub, "BOTTOM", 0, -9)
    tile.stats = Centered(tile, 12, "textDim", "medium")
    tile.stats:SetPoint("TOP", tile.badge, "BOTTOM", 0, -10)
    -- The foot: in the group now, or when and where last.
    tile.footFrame = CreateFrame("Frame", nil, tile)
    tile.footFrame:SetPoint("BOTTOMLEFT")
    tile.footFrame:SetPoint("BOTTOMRIGHT")
    tile.footFrame:SetHeight(30)
    tile.footGround = UI.Round(tile.footFrame, "sunken", 9, { inset = 1, square = { TOPLEFT = true, TOPRIGHT = true } })
    tile.footText = Centered(tile.footFrame, 11, "textMuted", "medium")
    tile.footText:SetPoint("CENTER")
    tile.footText:SetJustifyV("MIDDLE")
    -- Under the mouse the tile lights up, like a clickable card in the book.
    tile.hover = UI.Round(tile, "hover", 8, { inset = 4, sublevel = 2 })
    tile.hover:Hide()
    tile:SetScript("OnEnter", function(self)
        self.hover:Fade(true)
    end)
    tile:SetScript("OnLeave", function(self)
        self.hover:Fade(false)
    end)
    tile:SetScript("OnClick", function(self)
        self.hover:Hide()
        overview.model.onChoose(self.guid)
    end)
    return tile
end

local function FillTile(tile, person, rank, chosen)
    tile.guid, tile.rank = person.guid, rank
    for _, text in ipairs({ tile.name, tile.sub, tile.stats, tile.footText }) do
        text:SetWidth(tile:GetWidth() - 24)
    end
    tile.numeral:SetText(RANKS[rank])
    tile.crest:SetPerson(person.name, person.classFile)
    tile.crest:SetProgress(person.progress)
    tile.name:SetText(person.name)
    tile.sub:SetText(person.levelClass)
    tile.badge:SetTier(person.tier)
    tile.stats:SetText(person.statsText)
    tile.footText:SetText(person.lastText)
    UI.Ink(tile.footText, person.together and "accent" or "textMuted")
    tile.whisper:SetShown(person.whisper and true or false)
    tile.whisper.tip = L.ui_fellow_whisper
    MarkChosen(tile, chosen)
    if not tile:IsMouseOver() then
        tile.hover:Hide()
    end
end

-- A tile of the closest companions on another frame, to look at only: the
-- picture of the fellow travellers' settings (UI/Previews.lua). Its width
-- is set before UI.FillFellowTile(tile, person, rank); person as in the
-- overview's model.
function UI.FellowTile(parent)
    local tile = CreateTile(parent)
    tile:EnableMouse(false)
    tile.whisper:EnableMouse(false)
    return tile
end

function UI.FillFellowTile(tile, person, rank)
    FillTile(tile, person, rank, false)
end
UI.FELLOW_TILE_H = TILE_H

---------------------------------------------------------------------------
-- List
---------------------------------------------------------------------------

local COLUMNS = { name = 0, bond = 0.46, time = 0.66, last = 0.82 } -- share of the width

local function CreateRow(overview)
    local row = CreateFrame("Button", nil, overview.list)
    row:SetHeight(ROW_H)
    row.hover = UI.Round(row, "hover", 8, { sublevel = 1 })
    row.hover:Hide()
    row.chosen = UI.Round(row, "accentSoft", 8, { sublevel = 1 })
    row.chosen:Hide()
    row.line = UI.Line(row, "divider")
    row.line:SetPoint("TOPLEFT", 12, 0)
    row.line:SetPoint("TOPRIGHT", -12, 0)
    row.crest = UI.Crest(row, 38)
    row.crest:SetPoint("LEFT", 14, 0)
    row.name = UI.Text(row, 13, "text", "medium")
    row.name:SetPoint("TOPLEFT", row.crest, "TOPRIGHT", 12, -2)
    row.name:SetWordWrap(false)
    row.sub = UI.Text(row, 11, "textMuted")
    row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
    row.sub:SetWordWrap(false)
    row.badge = UI.TierBadge(row)
    row.time = UI.Text(row, 12, "textDim", "medium")
    row.time:SetJustifyV("MIDDLE")
    row.last = UI.Text(row, 12, "textMuted")
    row.last:SetJustifyV("MIDDLE")
    row.last:SetWordWrap(false)
    row.whisper = UI.IconButton(row, "chat", function(self)
        overview.model.onWhisper(self:GetParent().guid)
    end, 28)
    row.whisper:SetPoint("RIGHT", -10, 0)
    row:SetScript("OnEnter", function(self)
        self.hover:Fade(true)
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:Fade(false)
    end)
    row:SetScript("OnClick", function(self)
        overview.model.onChoose(self.guid)
    end)
    return row
end

local function PlaceColumns(row, width)
    -- Name and line end before the bond column.
    row.name:SetWidth(width * COLUMNS.bond - 78)
    row.sub:SetWidth(width * COLUMNS.bond - 78)
    row.badge:ClearAllPoints()
    row.badge:SetPoint("LEFT", row, "LEFT", width * COLUMNS.bond, 0)
    row.time:ClearAllPoints()
    row.time:SetPoint("LEFT", row, "LEFT", width * COLUMNS.time, 0)
    row.last:ClearAllPoints()
    row.last:SetPoint("LEFT", row, "LEFT", width * COLUMNS.last, 0)
    -- The last column ends before the whisper button.
    row.last:SetWidth(width * (1 - COLUMNS.last) - 48)
end

local function FillRow(row, person, first, chosen)
    row.guid = person.guid
    row.crest:SetPerson(person.name, person.classFile)
    row.crest:SetProgress(person.progress)
    row.name:SetText(person.name)
    row.sub:SetText(person.realName and (person.realName .. "  ·  " .. person.levelClass) or person.levelClass)
    row.badge:SetTier(person.tier)
    row.time:SetText(person.timeText)
    row.last:SetText(person.lastShort)
    UI.Ink(row.last, person.together and "accent" or "textMuted")
    row.whisper:SetShown(person.whisper and true or false)
    row.whisper.tip = L.ui_fellow_whisper
    row.line:SetShown(not first)
    row.chosen:SetShown(chosen)
end

---------------------------------------------------------------------------
-- The card of the chosen person
---------------------------------------------------------------------------

local STRIP_H = 62 -- the strip of numbers on the card
local STRIP_TOP = 11 -- from its top edge to the top of the numbers
-- Between the parts of the card: who, the bond, the numbers, when you met.
-- The card runs the full height; with this the parts fill it, and a two-line
-- "met" sentence still ends well above the buttons.
local SECTION_GAP = 32
-- The card's buttons, squares with an icon; the whisper a little larger.
local ICON_BUTTON, WHISPER_BUTTON = 34, 40

-- The time together with the digits large and "h" and "min" small beside
-- them, centred in the cell: "2 h 40 min". Under an hour only the minutes,
-- on the hour only the hours.
local function SetTime(cell, hours, minutes)
    local showHours, showMinutes = hours > 0, minutes > 0 or hours == 0
    cell.hours:SetShown(showHours)
    cell.hoursUnit:SetShown(showHours)
    cell.minutes:SetShown(showMinutes)
    cell.minutesUnit:SetShown(showMinutes)
    local parts = {}
    if showHours then
        parts[#parts + 1] = { cell.hours, cell.hoursUnit, tostring(hours), L.ui_unit_hours }
    end
    if showMinutes then
        parts[#parts + 1] = { cell.minutes, cell.minutesUnit, tostring(minutes), L.ui_unit_minutes }
    end
    local total = 0
    for index, part in ipairs(parts) do
        part[1]:SetText(part[3])
        part[2]:SetText(part[4])
        total = total + (index > 1 and 6 or 0) + part[1]:GetStringWidth() + 3 + part[2]:GetStringWidth()
    end
    local x = -total / 2
    for _, part in ipairs(parts) do
        local number, unit = part[1], part[2]
        number:ClearAllPoints()
        number:SetPoint("TOPLEFT", cell, "TOP", x, -STRIP_TOP)
        -- The unit sits on the number's baseline, near enough: the smaller
        -- type has the shorter descender.
        unit:ClearAllPoints()
        unit:SetPoint("BOTTOMLEFT", number, "BOTTOMRIGHT", 3, 2)
        x = x + number:GetStringWidth() + 3 + unit:GetStringWidth() + 6
    end
end

local function CreateProfile(overview, parent, width)
    local card = Card(parent)
    card:SetWidth(width)
    local inner = width - CARD_PAD * 2
    card.crest = UI.Crest(card, 88)
    card.crest:SetPoint("TOP", 0, -24)
    card.name = Centered(card, 22, "text")
    UI.SetDisplayFont(card.name, 22)
    card.name:SetPoint("TOP", card.crest, "BOTTOM", 0, -12)
    card.name:SetWidth(inner)
    card.name:SetWordWrap(false)
    card.sub = Centered(card, 12, "textMuted")
    card.sub:SetPoint("TOP", card.name, "BOTTOM", 0, -6)
    card.sub:SetWidth(inner)
    card.sub:SetWordWrap(false)
    card.status = Centered(card, 12, "textMuted", "medium")
    card.status:SetPoint("TOP", card.sub, "BOTTOM", 0, -6)
    -- The bond: where you stand, the next tier, and how much time is left.
    card.bond = UI.TierBar(card, inner)
    card.bond:SetPoint("TOP", card.status, "BOTTOM", 0, -SECTION_GAP)
    card.remaining = Centered(card, 11, "textMuted")
    card.remaining:SetPoint("TOP", card.bond, "BOTTOM", 0, -8)

    -- Below it, the numbers in one sunken strip: the time takes half of it,
    -- times and bosses a quarter each. All three numbers are the same size;
    -- in the time, "h" and "min" stand small beside the digits.
    card.strip = CreateFrame("Frame", nil, card)
    card.strip:SetSize(inner, STRIP_H)
    card.strip:SetPoint("TOP", card.remaining, "BOTTOM", 0, -SECTION_GAP)
    UI.Card(card.strip, "sunken", "divider", 8)
    card.cells = {}
    local shares = { 0.5, 0.25, 0.25 }
    local x = 0
    for index, share in ipairs(shares) do
        local cell = CreateFrame("Frame", nil, card.strip)
        cell:SetSize(inner * share, STRIP_H)
        cell:SetPoint("TOPLEFT", x, 0)
        if index > 1 then
            local line = UI.VLine(cell, "divider")
            line:SetPoint("TOPLEFT", 0, -8)
            line:SetPoint("BOTTOMLEFT", 0, 8)
        end
        cell.label = Centered(cell, 11, "textMuted")
        cell.label:SetPoint("BOTTOM", 0, 10)
        if index == 1 then
            cell.hours = UI.Text(cell, 20, "text", "semibold")
            cell.hoursUnit = UI.Text(cell, 11, "textMuted")
            cell.minutes = UI.Text(cell, 20, "text", "semibold")
            cell.minutesUnit = UI.Text(cell, 11, "textMuted")
        else
            cell.value = Centered(cell, 20, "text", "semibold")
            cell.value:SetPoint("TOP", 0, -STRIP_TOP)
        end
        card.cells[index] = cell
        x = x + inner * share
    end

    -- When you met; when you were last together says the status below the name.
    card.first = Centered(card, 12, "textDim")
    card.first:SetPoint("TOP", card.strip, "BOTTOM", 0, -SECTION_GAP)
    card.first:SetWidth(inner)
    card.first:SetSpacing(3)
    -- The player's level then, on a line of its own so the sentence above does not break.
    card.firstLevel = Centered(card, 11, "textMuted")
    card.firstLevel:SetPoint("TOP", card.first, "BOTTOM", 0, -4)

    card.storyButton = UI.Button(card, function()
        overview.actions.onStory(card.guid)
    end, "primary")
    -- The buttons beside a story are icons in one row; the tooltip names them.
    card.whisper = UI.Button(card, function()
        overview.actions.onWhisper(card.guid)
    end, "primary", "chat")
    -- Their own events, if the chronicle has any: that book is the chronicle's.
    card.chronicle = UI.Button(card, function()
        overview.actions.onChronicle(card.chronicleWho)
    end, "secondary", "flag")
    card.alias = UI.Button(card, function()
        overview.actions.onAlias(card.guid)
    end, "secondary", "tag")
    card.forget = UI.Button(card, function()
        overview.actions.onForget(card.guid)
    end, "secondary", "trash")
    card.whisper:SetIconOnly(WHISPER_BUTTON, 18)
    for _, button in ipairs({ card.chronicle, card.alias, card.forget }) do
        button:SetIconOnly(ICON_BUTTON)
    end
    return card
end

local BUTTON_GAP = 10
local BUTTON_MID = 36 -- the middle line of the card's buttons, above its foot

-- The buttons that are shown, side by side on the middle line, from x on:
-- rightwards (step 1) or leftwards (step -1).
local function ButtonLine(card, buttons, x, step)
    for _, button in ipairs(buttons) do
        if button:IsShown() then
            button:ClearAllPoints()
            button:SetPoint(step > 0 and "LEFT" or "RIGHT", card, "BOTTOM", x, BUTTON_MID)
            x = x + step * (button:GetWidth() + BUTTON_GAP)
        end
    end
end

-- One row at the foot. The whisper stands on the card's middle axis, like
-- everything above it: the alias to its left (and the chronicle, if there is
-- one, beyond it), forget to its right. Without it the rest is centred.
local function PlaceButtons(card)
    if card.whisper:IsShown() then
        local half = card.whisper:GetWidth() / 2 + BUTTON_GAP
        card.whisper:ClearAllPoints()
        card.whisper:SetPoint("CENTER", card, "BOTTOM", 0, BUTTON_MID)
        ButtonLine(card, { card.alias, card.chronicle }, -half, -1)
        ButtonLine(card, { card.forget }, half, 1)
        return
    end
    local buttons, width = { card.storyButton, card.chronicle, card.alias, card.forget }, -BUTTON_GAP
    for _, button in ipairs(buttons) do
        if button:IsShown() then
            width = width + button:GetWidth() + BUTTON_GAP
        end
    end
    ButtonLine(card, buttons, -width / 2, 1)
end

-- inStory: beside the person's own story, where "Your story" is not needed.
local function FillProfile(card, person, inStory)
    card.guid = person.guid
    card.crest:SetPerson(person.name, person.classFile)
    card.crest:SetProgress(person.progress)
    card.name:SetText(person.name)
    card.sub:SetText(person.realName and (person.realName .. "  ·  " .. person.levelClass) or person.levelClass)
    card.status:SetText(person.lastText)
    UI.Ink(card.status, person.together and "accent" or "textMuted")
    card.bond:SetTier(person.tier, person.progress)
    card.remaining:SetText(person.nextText or "")
    local time, times, bosses = card.cells[1], card.cells[2], card.cells[3]
    SetTime(time, person.hours, person.minutes)
    time.label:SetText(L.ui_fellow_col_time)
    times.value:SetText(tostring(person.times))
    times.label:SetText(L.ui_fellow_stat_times)
    bosses.value:SetText(tostring(person.bosses))
    bosses.label:SetText(L.ui_fellow_stat_bosses)
    card.first:SetText(person.firstText or "")
    card.firstLevel:SetText(person.firstLevelText or "")

    card.storyButton:SetLabel(L.ui_fellow_story)
    card.whisper:SetLabel(L.ui_fellow_whisper)
    card.alias:SetLabel(L.ui_fellow_alias)
    card.chronicle:SetLabel(L.ui_fellow_chronicle)
    card.forget:SetLabel(L.ui_fellow_forget)
    card.storyButton:SetShown(not inStory)
    card.whisper:SetShown(inStory and person.whisper and true or false)
    card.chronicleWho = inStory and person.chronicle or nil
    card.chronicle:SetShown(card.chronicleWho ~= nil)
    PlaceButtons(card)
end

---------------------------------------------------------------------------
-- The whole overview
---------------------------------------------------------------------------

function UI.FellowOverview(parent, cardParent, cardWidth)
    local overview = CreateFrame("Frame", nil, parent)
    overview.tiles, overview.rows = {}, {}

    overview.closest = UI.Text(overview, 12, "textMuted", "medium")
    overview.closest:SetPoint("TOPLEFT", 2, -2)

    overview.others = UI.Text(overview, 12, "textMuted", "medium")
    overview.sort = CreateFrame("Button", nil, overview)
    overview.sort:SetSize(210, 28)
    overview.sortBox = UI.Dropdown(overview.sort)
    overview.sortBox:SetAllPoints(overview.sort)
    overview.sort:SetScript("OnClick", function(self)
        local model = overview.model
        UI.OpenMenu(self, model.sortValues, model.sort, model.onSort)
    end)

    overview.list = Card(overview)
    overview.heads = {}
    for _, key in ipairs({ "name", "bond", "time", "last" }) do
        local head = UI.Text(overview.list, 10, "textMuted", "semibold")
        head.key = key
        overview.heads[#overview.heads + 1] = head
    end
    overview.more = UI.Text(overview.list, 12, "textMuted")

    overview.card = CreateProfile(overview, cardParent, cardWidth)
    overview.card:Hide()

    -- Lays everything out for the model; returns the height of the left column.
    function overview:SetCard(person, inStory, actions)
        self.actions = actions
        FillProfile(self.card, person, inStory)
    end

    function overview:SetModel(model, width)
        self.model, self.actions = model, model
        self:SetWidth(width)
        local chosen = model.chosen and model.chosen.guid

        self.closest:SetText(L.ui_fellow_closest)
        local tileWidth = (width - GAP * 2) / 3
        for index = 1, 3 do
            local person = model.top[index]
            local tile = self.tiles[index]
            if person then
                tile = tile or CreateTile(self)
                self.tiles[index] = tile
                tile:SetWidth(tileWidth)
                tile:ClearAllPoints()
                tile:SetPoint("TOPLEFT", self, "TOPLEFT", (index - 1) * (tileWidth + GAP), -TITLE_H)
                FillTile(tile, person, index, person.guid == chosen)
                tile:Show()
            elseif tile then
                tile:Hide()
            end
        end
        local y = TITLE_H + TILE_H + 26

        local hasList = #model.rest > 0
        self.others:SetShown(hasList)
        self.sort:SetShown(hasList)
        self.list:SetShown(hasList)
        for index = #model.rest + 1, #self.rows do
            self.rows[index]:Hide()
        end
        if not hasList then
            self:SetHeight(y - 26)
            return y - 26
        end

        self.others:SetText(L.ui_fellow_others:format(#model.rest + model.more))
        self.others:ClearAllPoints()
        self.others:SetPoint("LEFT", self, "TOPLEFT", 2, -(y + 14))
        self.sort:ClearAllPoints()
        self.sort:SetPoint("RIGHT", self, "TOPRIGHT", 0, -(y + 14))
        for _, entry in ipairs(model.sortValues) do
            if entry.value == model.sort then
                self.sortBox.text:SetText(entry.text)
            end
        end
        y = y + 28 + 10

        local list = self.list
        list:SetWidth(width)
        list:ClearAllPoints()
        list:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
        for _, head in ipairs(self.heads) do
            head:SetText(ns.Upper(L["ui_fellow_col_" .. head.key]))
            head:ClearAllPoints()
            head:SetPoint("TOPLEFT", list, "TOPLEFT", head.key == "name" and 16 or width * COLUMNS[head.key], -12)
        end
        local rowY = HEADS_H
        for index, person in ipairs(model.rest) do
            local row = self.rows[index] or CreateRow(self)
            self.rows[index] = row
            row:SetWidth(width)
            PlaceColumns(row, width)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", list, "TOPLEFT", 0, -rowY)
            FillRow(row, person, index == 1, person.guid == chosen)
            row:Show()
            rowY = rowY + ROW_H
        end
        self.more:SetShown(model.more > 0)
        if model.more > 0 then
            self.more:SetText(ns.Plural("ui_fellow_more", model.more):format(model.more) .. "  ·  " .. L.ui_fellow_more_desc)
            self.more:ClearAllPoints()
            self.more:SetPoint("TOPLEFT", list, "TOPLEFT", 16, -(rowY + 10))
            rowY = rowY + 36
        end
        list:SetHeight(rowY + 6)
        -- Without a height the client cannot place the tiles and the list.
        self:SetHeight(y + rowY + 6)
        return y + rowY + 6
    end

    return overview
end

---------------------------------------------------------------------------
-- Nearby: friends and guild who are online, in sections ("Here in Tanaris",
-- "Similar level", "Also online", "Out of reach"), each a list. UI/Options.lua builds the
-- model.
--
--   local list = UI.NearbyList(parent)
--   local height = list:SetModel(model, width)
--
--   model = {
--       sections = { { title = "Here in Tanaris", note = "4", more = "2 more" or nil,
--                      people = { person, ... } }, ... },
--       onChoose(person),  -- a click on a fellow traveller's row
--       onWhisper(person), -- the button at the row's end
--   }
--   person = { name, label (the alias, else the name), sub, class, progress,
--              tier or nil, level, diff, place, here, out (drawn faint),
--              guid (a fellow traveller's) or nil }
---------------------------------------------------------------------------

local NEAR_ROW = 52
local NEAR_COLUMNS = { level = 0.47, place = 0.58, bond = 0.8 } -- share of the width
local SECTION_SPACE = 22 -- between two sections
local NEAR_FAINT = 0.6 -- a row of someone out of reach

local function CreateNearRow(list)
    local row = CreateFrame("Button", nil, list)
    -- Above the sections' cards, whichever was made first.
    row:SetFrameLevel(list:GetFrameLevel() + 3)
    row:SetHeight(NEAR_ROW)
    row.hover = UI.Round(row, "hover", 8, { sublevel = 1 })
    row.hover:Hide()
    row.line = UI.Line(row, "divider")
    row.line:SetPoint("TOPLEFT", 12, 0)
    row.line:SetPoint("TOPRIGHT", -12, 0)
    row.crest = UI.Crest(row, 36)
    row.crest:SetPoint("LEFT", 14, 0)
    row.name = UI.Text(row, 13, "text", "medium")
    row.name:SetPoint("TOPLEFT", row.crest, "TOPRIGHT", 12, -1)
    row.name:SetWordWrap(false)
    row.sub = UI.Text(row, 11, "textMuted")
    row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -4)
    row.sub:SetWordWrap(false)
    row.level = UI.Text(row, 12, "textDim", "medium")
    row.level:SetJustifyV("MIDDLE")
    row.diff = UI.Text(row, 11, "textMuted")
    row.diff:SetPoint("LEFT", row.level, "RIGHT", 5, 0)
    row.place = UI.Text(row, 12, "textMuted")
    row.place:SetJustifyV("MIDDLE")
    row.place:SetWordWrap(false)
    row.badge = UI.TierBadge(row)
    row.whisper = UI.IconButton(row, "chat", function(self)
        list.model.onWhisper(self:GetParent().person)
    end, 28)
    row.whisper:SetPoint("RIGHT", -10, 0)
    row:SetScript("OnEnter", function(self)
        if self.person and self.person.guid then
            self.hover:Fade(true)
        end
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:Fade(false)
    end)
    row:SetScript("OnClick", function(self)
        if self.person and self.person.guid then
            self.hover:Hide()
            list.model.onChoose(self.person)
        end
    end)
    return row
end

local function FillNearRow(row, person, first, width)
    row.person = person
    row:SetWidth(width)
    row:SetAlpha(person.out and NEAR_FAINT or 1)
    row.crest:SetPerson(person.name, person.class)
    row.crest:SetProgress(person.progress or 0)
    row.name:SetText(person.label or person.name)
    row.sub:SetText(person.sub or "")
    row.name:SetWidth(width * NEAR_COLUMNS.level - 72)
    row.sub:SetWidth(width * NEAR_COLUMNS.level - 72)
    row.level:SetText(person.level or "")
    row.level:ClearAllPoints()
    row.level:SetPoint("LEFT", row, "LEFT", width * NEAR_COLUMNS.level, 0)
    row.diff:SetText(person.diff or "")
    row.place:SetText(person.place or "")
    UI.Ink(row.place, person.here and "accent" or "textMuted")
    row.place:SetWidth(width * (NEAR_COLUMNS.bond - NEAR_COLUMNS.place) - 10)
    row.place:ClearAllPoints()
    row.place:SetPoint("LEFT", row, "LEFT", width * NEAR_COLUMNS.place, 0)
    row.badge:SetShown(person.tier ~= nil)
    if person.tier then
        row.badge:SetTier(person.tier)
        row.badge:ClearAllPoints()
        row.badge:SetPoint("LEFT", row, "LEFT", width * NEAR_COLUMNS.bond, 0)
    end
    row.whisper.tip = L.ui_near_whisper
    row.line:SetShown(not first)
    if not row:IsMouseOver() then
        row.hover:Hide()
    end
end

function UI.NearbyList(parent)
    local list = CreateFrame("Frame", nil, parent)
    list.sections, list.rows = {}, {}

    function list:SetModel(model, width)
        self.model = model
        self:SetWidth(width)
        local y, used = 0, 0
        for index, section in ipairs(model.sections) do
            local part = self.sections[index]
            if not part then
                part = {}
                part.title = UI.Text(self, 12, "textMuted", "medium")
                part.card = Card(self)
                part.card:SetFrameLevel(self:GetFrameLevel() + 1)
                part.card:EnableMouse(false)
                part.more = UI.Text(part.card, 12, "textMuted")
                self.sections[index] = part
            end
            part.title:SetText(section.note and (section.title .. "  ·  " .. section.note) or section.title)
            part.title:ClearAllPoints()
            part.title:SetPoint("TOPLEFT", self, "TOPLEFT", 2, -y)
            part.title:Show()
            y = y + TITLE_H
            part.card:SetWidth(width)
            part.card:ClearAllPoints()
            part.card:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
            part.card:Show()
            local rowY = 4
            for position, person in ipairs(section.people) do
                used = used + 1
                local row = self.rows[used] or CreateNearRow(self)
                self.rows[used] = row
                FillNearRow(row, person, position == 1, width)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -(y + rowY))
                row:Show()
                rowY = rowY + NEAR_ROW
            end
            part.more:SetShown(section.more ~= nil)
            if section.more then
                part.more:SetText(section.more)
                part.more:ClearAllPoints()
                part.more:SetPoint("TOPLEFT", part.card, "TOPLEFT", 16, -(rowY + 8))
                rowY = rowY + 32
            end
            part.card:SetHeight(rowY + 4)
            y = y + rowY + 4 + SECTION_SPACE
        end
        for index = #model.sections + 1, #self.sections do
            self.sections[index].title:Hide()
            self.sections[index].card:Hide()
        end
        for index = used + 1, #self.rows do
            self.rows[index]:Hide()
        end
        local height = math.max(1, y - SECTION_SPACE)
        self:SetHeight(height)
        return height
    end

    return list
end

---------------------------------------------------------------------------
-- What a card of the fellow travellers' books holds (UI/Book.lua): a
-- picture or a person's crest, the text, the people of a group as plates,
-- and a sunken strip below that says, in the accent, what the event adds.
--
--   story = {
--       content = UI.FellowCard,
--       kind, texture, icon, number, ...  -- the picture (UI.SetBookPicture)
--       noPicture = true,           -- the text takes the card's whole width
--       crest = { name = "Mira Stormfeather", class = "MAGE", progress = 0.4 },
--                                   -- a person's crest instead of the picture
--       big = true,                 -- a milestone: larger text, more room
--       title = "On the road in Uldaman", detail = "20:00 to 22:40" or nil,
--       when = "21:14",             -- optional: closes the detail line
--       people = { { name = "Mira", class = "MAGE", note = "until 22:40" or nil } },
--       foot = "Again with Mira and Borin",
--   }
---------------------------------------------------------------------------

local PICTURE = 54
local STRIP = 30 -- the sunken strip below
local PERSON_H, PERSON_ICON, PERSON_GAP = 22, 16, 4 -- a person's plate

-- The people as plates (class icon, else the initial, the name and a
-- note), row after row within `width`. Notes each plate's place (plate.x,
-- plate.y) and returns the height they take.
local function LayPeople(part, people, width)
    local list = people or {}
    local x, y = 0, 0
    for index, each in ipairs(list) do
        local plate = part.people[index]
        if not plate then
            plate = CreateFrame("Frame", nil, part)
            plate:SetHeight(PERSON_H)
            UI.Card(plate, "field", "fieldBorder", PERSON_H / 2)
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
            part.people[index] = plate
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
            x, y = 0, y + PERSON_H + PERSON_GAP
        end
        plate.x, plate.y = x, y
        plate:Show()
        x = x + plateWidth + PERSON_GAP
    end
    for index = #list + 1, #part.people do
        part.people[index]:Hide()
    end
    part.peopleCount = #list
    return #list > 0 and y + PERSON_H or 0
end

local function BuildCard(part)
    UI.BookPicture(part)
    part.title = UI.Text(part, 13, "text", "medium")
    part.title:SetSpacing(1)
    part.detail = UI.Text(part, 12, "textMuted")
    part.detail:SetSpacing(2)
    part.detail:SetPoint("TOPLEFT", part.title, "BOTTOMLEFT", 0, -4)
    part.people = {}
    local pixel = UI.Pixel(part)
    local foot = CreateFrame("Frame", nil, part)
    part.foot = foot
    foot:SetHeight(STRIP)
    foot:SetPoint("BOTTOMLEFT")
    foot:SetPoint("BOTTOMRIGHT")
    UI.Round(foot, "sunken", 9, { inset = pixel, square = { TOPLEFT = true, TOPRIGHT = true } })
    local footLine = UI.Line(foot)
    footLine:SetPoint("TOPLEFT", pixel, 0)
    footLine:SetPoint("TOPRIGHT", -pixel, 0)
    part.footIcon = UI.Icon(foot, "people", 13, "accent")
    part.footIcon:SetPoint("LEFT", foot, "LEFT", 12, 0)
    part.footText = UI.Text(foot, 11, "accent2", "medium")
    part.footText:SetPoint("LEFT", part.footIcon, "RIGHT", 7, 0)
    part.footText:SetWordWrap(false)
end

function UI.FellowCard(part, story, width)
    if not part.title then
        BuildCard(part)
    end
    local look = UI.BookPictures[story.kind] or UI.BookPictures.zone
    local big = story.big and true or false
    local pad = big and 15 or 12
    local size = story.noPicture and 0 or PICTURE
    local beside = size > 0 and size + 12 or 0
    local textWidth = width - pad * 2 - beside

    -- Picture: an icon, or a number; or a person's crest.
    local crest = story.crest
    part.picture:SetShown(size > 0 and crest == nil)
    if crest and not part.crest then
        part.crest = UI.Crest(part, PICTURE)
    end
    if part.crest then
        part.crest:SetShown(crest ~= nil and size > 0)
        if crest then
            part.crest:SetPerson(crest.name, crest.class)
            part.crest:SetProgress(crest.progress)
        end
    end
    UI.SetBookPicture(part, story, PICTURE)

    -- Text: headline and detail, the time closing the detail line, below
    -- them the people.
    part.title:SetWidth(textWidth)
    part.title:SetText(story.title or "")
    UI.SetFont(part.title, big and 15 or 13, big and "semibold" or "medium")
    UI.Ink(part.title, look.title or "text")
    local textHeight = part.title:GetStringHeight()
    local detail = story.detail
    if story.when then
        detail = detail and (detail .. "  ·  " .. story.when) or story.when
    end
    part.detail:SetShown(detail ~= nil)
    if detail then
        part.detail:SetWidth(textWidth)
        part.detail:SetText(detail)
        textHeight = textHeight + 4 + part.detail:GetStringHeight()
    end
    local peopleTop = textHeight + 8
    local peopleHeight = LayPeople(part, story.people, textWidth)
    if peopleHeight > 0 then
        textHeight = peopleTop + peopleHeight
    end

    local footText = story.foot
    part.foot:SetShown(footText ~= nil)
    if footText then
        part.footText:SetWidth(width - 12 - 13 - 7 - 12)
        part.footText:SetText(footText)
    end

    local bodyHeight = math.floor(math.max(size, textHeight) + pad * 2 + 0.5)
    local pictureTop = -math.floor((bodyHeight - size) / 2 + 0.5)
    part.picture:ClearAllPoints()
    part.picture:SetPoint("TOPLEFT", part, "TOPLEFT", pad, pictureTop)
    if part.crest then
        part.crest:ClearAllPoints()
        part.crest:SetPoint("TOPLEFT", part, "TOPLEFT", pad, pictureTop)
    end
    local left = pad + beside
    local top = math.floor((bodyHeight - textHeight) / 2 + 0.5)
    part.title:ClearAllPoints()
    part.title:SetPoint("TOPLEFT", part, "TOPLEFT", left, -top)
    for index = 1, part.peopleCount do
        local plate = part.people[index]
        plate:ClearAllPoints()
        plate:SetPoint("TOPLEFT", part, "TOPLEFT", left + plate.x, -(top + peopleTop + plate.y))
    end
    return bodyHeight + (footText and STRIP or 0)
end
