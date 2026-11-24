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
--       onStory(guid), onAlias(guid), onForget(guid), -- the card's buttons
--   }
--   person = { guid, name, realName, classFile, levelClass, tier, progress,
--              nextText, timeText, statsText, times, bosses, together,
--              lastText, lastShort, firstText }
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
    tile:SetScript("OnClick", function(self)
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
    MarkChosen(tile, chosen)
end

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
    row.line:SetShown(not first)
    row.chosen:SetShown(chosen)
end

---------------------------------------------------------------------------
-- The card of the chosen person
---------------------------------------------------------------------------

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
    card.ladder = UI.TierLadder(card, inner)
    card.ladder:SetPoint("TOP", card.status, "BOTTOM", 0, -18)
    card.next = Centered(card, 11, "textMuted")
    card.next:SetPoint("TOP", card.ladder, "BOTTOM", 0, -4)

    -- Three numbers side by side: time, times, bosses.
    card.cells = {}
    for index = 1, 3 do
        local cell = CreateFrame("Frame", nil, card)
        cell:SetSize(inner / 3, 44)
        cell:SetPoint("TOPLEFT", card.next, "BOTTOM", -inner / 2 + (index - 1) * inner / 3, -16)
        cell.value = Centered(cell, 17, "text", "semibold")
        cell.value:SetPoint("TOP")
        cell.label = Centered(cell, 11, "textMuted")
        cell.label:SetPoint("TOP", cell.value, "BOTTOM", 0, -4)
        card.cells[index] = cell
    end

    card.first = Centered(card, 12, "textDim")
    card.first:SetPoint("TOP", card.next, "BOTTOM", 0, -76)
    card.first:SetWidth(inner)
    card.last = Centered(card, 12, "textMuted")
    card.last:SetPoint("TOP", card.first, "BOTTOM", 0, -5)
    card.last:SetWidth(inner)

    card.storyButton = UI.Button(card, function()
        overview.actions.onStory(card.guid)
    end, "primary")
    card.alias = UI.Button(card, function()
        overview.actions.onAlias(card.guid)
    end, "secondary")
    card.forget = UI.Button(card, function()
        overview.actions.onForget(card.guid)
    end, "ghost")
    card.forget:SetPoint("BOTTOM", 0, 16)
    return card
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
    card.ladder:SetTier(person.tier, person.progress)
    card.next:SetText(person.nextText or "")
    local values = {
        { person.timeText, L.ui_fellow_col_time },
        { tostring(person.times), L.ui_fellow_stat_times },
        { tostring(person.bosses), L.ui_fellow_stat_bosses },
    }
    for index, cell in ipairs(card.cells) do
        cell.value:SetText(values[index][1])
        cell.label:SetText(values[index][2])
    end
    card.first:SetText(person.firstText or "")
    card.last:SetText(person.together and "" or person.lastText)

    card.storyButton:SetLabel(L.ui_fellow_story)
    card.alias:SetLabel(L.ui_fellow_alias)
    card.forget:SetLabel(L.ui_fellow_forget)
    card.storyButton:SetShown(not inStory)
    card.alias:ClearAllPoints()
    if inStory then
        card.alias:SetPoint("BOTTOM", card, "BOTTOM", 0, 56)
    else
        local both = card.storyButton:GetWidth() + 10 + card.alias:GetWidth()
        card.storyButton:ClearAllPoints()
        card.storyButton:SetPoint("BOTTOMLEFT", card, "BOTTOM", -both / 2, 56)
        card.alias:SetPoint("LEFT", card.storyButton, "RIGHT", 10, 0)
    end
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
            head:SetText(string.upper(L["ui_fellow_col_" .. head.key]))
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
            self.more:SetText(L.ui_fellow_more:format(model.more) .. "  ·  " .. L.ui_fellow_more_desc)
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
