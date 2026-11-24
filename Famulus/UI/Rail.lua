-- The rail beside the chronicle's book: a column of small cards that stays
-- put while the book scrolls. UI/Options.lua decides what it shows.
--
--   local rail = UI.Rail(parent, width)
--   local height = rail:SetCards(cards)
--
--   cards = {
--       { kind = "stats", title = "This week", note = "Kip",
--         stats = { { value = "19", plus = "+4", label = "Level" }, ... } },
--       { kind = "people", title = "Companions", note = "3", hint = "Click a name ...",
--         people = { { key = "<who>", initial = "J", class = "MAGE", name = "Jule",
--                      line = "Reached level 22  ·  19:58", level = "Level 22",
--                      online = true, selected = false } },
--         onSelect = function(key) end },
--       { kind = "bars", title = "Professions",
--         bars = { { label = "Tailoring", value = 92, max = 150 } } },
--       { kind = "brief", key = "<who>", initial = "J", class = "MAGE", name = "Jule",
--         level = "Level 21", online = true,
--         selected = false, stats = { ... } or nil, empty = "No profile",
--         onSelect = function(key) end },
--       { kind = "note", title = "Profiles", text = "..." },
--       { kind = "group", title = "Most frequent group", note = "4×",
--         people = { { name = "Mira Stormfeather", class = "MAGE", progress = 0.7 } },
--         names = "Mira and Borin", line = "12 h 20 min together", text = "..." },
--   }
--
-- A number may stand alone in its row (stats: { wide = true }); a person
-- without `online` shows no state, only the words on the right (`level`).
--
-- Frames are made as needed and used again; nothing runs per frame.

local _, ns = ...
local L = ns.L
local UI = ns.UI

local GAP = 8 -- between two cards
local PAD = 16 -- inside a card, left and right
local TITLE_TOP = 12
local BODY_TOP = 34 -- below a card's title
local ROW = 50 -- a person
local BAR = 32 -- a profession
local CREST, CREST_GAP = 34, 6 -- the people of a group

---------------------------------------------------------------------------
-- Parts of a card, made when first needed
---------------------------------------------------------------------------

local function CreateCard(rail)
    local card = CreateFrame("Frame", nil, rail)
    card:SetWidth(rail.width)
    card.shape = UI.Card(card, "card", "cardBorder", 10)
    local pixel = UI.Pixel(card)
    local sheen = UI.Line(card, "sheenSoft")
    sheen:SetPoint("TOPLEFT", 10, -pixel)
    sheen:SetPoint("TOPRIGHT", -10, -pixel)
    card.title = UI.Text(card, 11, "textMuted", "medium")
    card.title:SetPoint("TOPLEFT", PAD, -TITLE_TOP)
    card.note = UI.Text(card, 11, "textMuted", "medium")
    card.note:SetPoint("TOPRIGHT", -PAD, -TITLE_TOP)
    card.note:SetJustifyH("RIGHT")
    card.text = UI.Text(card, 12, "textMuted")
    card.text:SetWidth(rail.width - PAD * 2)
    card.text:SetSpacing(2)
    card.hintLine = UI.Line(card, "cardBorder")
    card.cells, card.rows, card.bars, card.crests = {}, {}, {}, {}
    return card
end

-- A group's names in the game's book font, and the line below them.
local function GroupTexts(card)
    if not card.names then
        card.names = card:CreateFontString(nil, "OVERLAY")
        UI.SetDisplayFont(card.names, 16)
        UI.Ink(card.names, "accent2")
        card.names:SetJustifyH("LEFT")
        card.groupLine = UI.Text(card, 11, "textMuted")
        card.groupLine:SetJustifyH("LEFT")
    end
    return card.names, card.groupLine
end

-- A number with its label below it, two to a row.
local function Cell(card, index)
    local cell = card.cells[index]
    if cell then
        return cell
    end
    cell = CreateFrame("Frame", nil, card)
    cell.value = UI.Text(cell, 20, "text", "semibold")
    cell.value:SetPoint("TOPLEFT")
    cell.plus = UI.Text(cell, 12, "accent", "medium")
    cell.plus:SetPoint("BOTTOMLEFT", cell.value, "BOTTOMRIGHT", 6, 2)
    cell.label = UI.Text(cell, 11, "textMuted")
    cell.label:SetPoint("TOPLEFT", cell.value, "BOTTOMLEFT", 0, -3)
    card.cells[index] = cell
    return cell
end

-- A person: avatar, name and a line below it; level and whether they are
-- online on the right. A click narrows the book to them.
local function Row(card, index)
    local row = card.rows[index]
    if row then
        return row
    end
    row = CreateFrame("Button", nil, card)
    row:SetHeight(ROW)
    local pixel = UI.Pixel(row)
    row.divider = UI.Line(row, "cardBorder")
    row.divider:SetPoint("TOPLEFT")
    row.divider:SetPoint("TOPRIGHT")
    -- The chosen one: the accent fading out to the right, a bar on the left.
    row.fill = row:CreateTexture(nil, "BACKGROUND", nil, 1)
    row.fill:SetPoint("TOPLEFT", pixel, -pixel)
    row.fill:SetPoint("BOTTOMRIGHT", -pixel, pixel)
    UI.Shade(row.fill, "HORIZONTAL", "accentFade", "accentFadeEnd")
    row.bar = row:CreateTexture(nil, "BORDER")
    row.bar:SetWidth(2)
    row.bar:SetPoint("TOPLEFT", 0, -12)
    row.bar:SetPoint("BOTTOMLEFT", 0, 12)
    UI.Paint(row.bar, "accent")
    row.hover = UI.Round(row, "hover", 8, { inset = 4, sublevel = 2 })
    row.hover:Hide()

    row.avatar = UI.Icon(row, "circle", 30, "accentSoft")
    row.avatar:SetPoint("LEFT", 14, 0)
    row.initial = UI.Text(row, 12, "accent", "semibold")
    row.initial:SetPoint("CENTER", row.avatar, "CENTER")
    row.initial:SetJustifyH("CENTER")
    row.initial:SetJustifyV("MIDDLE")
    -- Where the class is known, its icon instead of the initial.
    row.class = UI.ClassIcon(row, 30)
    row.class:SetPoint("CENTER", row.avatar, "CENTER")
    row.name = UI.Text(row, 13, "text", "medium")
    row.name:SetPoint("TOPLEFT", 54, -9)
    row.name:SetWordWrap(false)
    row.line = UI.Text(row, 11, "textMuted")
    row.line:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -3)
    row.line:SetWordWrap(false)
    row.level = UI.Text(row, 12, "textDim")
    row.level:SetPoint("TOPRIGHT", -14, -9)
    row.level:SetJustifyH("RIGHT")
    row.state = UI.Text(row, 11, "textMuted")
    row.state:SetPoint("TOPRIGHT", row.level, "BOTTOMRIGHT", 0, -3)
    row.state:SetJustifyH("RIGHT")
    row.dot = UI.Icon(row, "circle", 6, "accent")
    row.dot:SetPoint("RIGHT", row.state, "LEFT", -5, 0)

    row:SetScript("OnEnter", function(self)
        if not self.selected then
            self.hover:Fade(true)
        end
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:Fade(false)
    end)
    row:SetScript("OnClick", function(self)
        self.hover:Hide()
        if self.onSelect then
            self.onSelect(self.key)
        end
    end)
    card.rows[index] = row
    return row
end

-- A profession: its name and points, and a slim bar below.
local function Bar(card, index)
    local bar = card.bars[index]
    if bar then
        return bar
    end
    bar = CreateFrame("Frame", nil, card)
    bar:SetHeight(BAR)
    bar.label = UI.Text(bar, 12, "text")
    bar.label:SetPoint("TOPLEFT")
    bar.label:SetWordWrap(false)
    bar.value = UI.Text(bar, 11, "textMuted")
    bar.value:SetPoint("TOPRIGHT")
    bar.value:SetJustifyH("RIGHT")
    bar.track = bar:CreateTexture(nil, "BORDER")
    bar.track:SetHeight(4)
    bar.track:SetPoint("TOPLEFT", 0, -19)
    bar.track:SetPoint("TOPRIGHT", 0, -19)
    UI.Paint(bar.track, "track")
    bar.fill = bar:CreateTexture(nil, "ARTWORK")
    bar.fill:SetHeight(4)
    bar.fill:SetPoint("TOPLEFT", bar.track, "TOPLEFT")
    UI.Shade(bar.fill, "HORIZONTAL", "accent", "accent2")
    card.bars[index] = bar
    return bar
end

local function Reset(card)
    card.title:Hide()
    card.note:Hide()
    card.text:Hide()
    card.hintLine:Hide()
    for _, list in ipairs({ card.cells, card.rows, card.bars, card.crests }) do
        for _, part in ipairs(list) do
            part:Hide()
        end
    end
    if card.names then
        card.names:Hide()
        card.groupLine:Hide()
    end
end

local function Title(card, spec)
    card.title:SetShown(spec.title ~= nil)
    card.title:SetText(spec.title or "")
    card.note:SetShown(spec.note ~= nil)
    card.note:SetText(spec.note or "")
end

---------------------------------------------------------------------------
-- Layouts, one per kind of card; each returns the card's height
---------------------------------------------------------------------------

-- Numbers two to a row from `top`, a wide one alone; returns where they end.
local function LayCells(card, stats, top, size, width)
    local column = (width - PAD * 2) / 2
    local rows, row = {}, nil
    for index, stat in ipairs(stats) do
        if stat.wide or not row or row.wide or #row == 2 then
            row = { wide = stat.wide }
            rows[#rows + 1] = row
        end
        row[#row + 1] = index
    end
    local y = top
    for _, each in ipairs(rows) do
        local height = 0
        local cellWidth = (each.wide and column * 2 or column) - 8
        for position, index in ipairs(each) do
            local stat, cell = stats[index], Cell(card, index)
            UI.SetFont(cell.value, size, "semibold")
            cell.value:SetText(stat.value or "")
            cell.plus:SetShown(stat.plus ~= nil)
            cell.plus:SetText(stat.plus or "")
            cell.label:SetWidth(cellWidth)
            cell.label:SetText(stat.label or "")
            local cellHeight = cell.value:GetStringHeight() + 3 + cell.label:GetStringHeight()
            cell:SetSize(cellWidth, cellHeight)
            cell:ClearAllPoints()
            cell:SetPoint("TOPLEFT", card, "TOPLEFT", PAD + (position - 1) * column, -y)
            cell:Show()
            height = math.max(height, cellHeight)
        end
        y = y + height + 12
    end
    return y
end

local function SetRow(row, person, width, onSelect)
    row.key, row.onSelect = person.key, onSelect
    row.selected = person.selected and true or false
    row.fill:SetShown(row.selected)
    row.bar:SetShown(row.selected)
    row.hover:Hide()
    row:EnableMouse(onSelect ~= nil)
    local classShown = UI.SetClass(row.class, person.class)
    row.avatar:SetShown(not classShown)
    row.initial:SetShown(not classShown)
    row.initial:SetText(person.initial or "?")
    row.name:SetText(person.name or "")
    row.line:SetShown(person.line ~= nil)
    row.line:SetText(person.line or "")
    row.level:SetShown(person.level ~= nil)
    row.level:SetText(person.level or "")
    local state = person.online ~= nil
    row.state:SetShown(state)
    row.dot:SetShown(state)
    row.state:SetText(person.online and L.c_online or L.c_offline)
    UI.Tint(row.dot, person.online and "accent" or "track")
    -- The words on the right take what they need; name and line the rest.
    local right = math.max(person.level and row.level:GetStringWidth() or 0, state and row.state:GetStringWidth() + 11 or 0)
    local textWidth = width - 54 - 14 - right - 10
    row.name:SetWidth(textWidth)
    row.line:SetWidth(textWidth)
    row:SetWidth(width)
end

local layouts = {}

function layouts.stats(card, spec, width)
    Title(card, spec)
    return LayCells(card, spec.stats or {}, BODY_TOP - 4, 20, width)
end

function layouts.people(card, spec, width)
    Title(card, spec)
    local y = BODY_TOP - 4
    for index, person in ipairs(spec.people or {}) do
        local row = Row(card, index)
        SetRow(row, person, width, spec.onSelect)
        row.divider:Show()
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -y)
        row:Show()
        y = y + ROW
    end
    if spec.hint then
        card.hintLine:ClearAllPoints()
        card.hintLine:SetPoint("TOPLEFT", card, "TOPLEFT", 0, -y)
        card.hintLine:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, -y)
        card.hintLine:Show()
        card.text:SetText(spec.hint)
        card.text:ClearAllPoints()
        card.text:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -(y + 10))
        card.text:Show()
        y = y + 10 + card.text:GetStringHeight() + 12
    end
    return y
end

function layouts.bars(card, spec, width)
    Title(card, spec)
    local y = BODY_TOP
    for index, each in ipairs(spec.bars or {}) do
        local bar = Bar(card, index)
        bar:SetWidth(width - PAD * 2)
        bar.label:SetText(each.label or "")
        bar.value:SetText(each.max and (each.value .. " / " .. each.max) or tostring(each.value or ""))
        bar.label:SetWidth(width - PAD * 2 - bar.value:GetStringWidth() - 8)
        local share = each.max and math.min(1, math.max(0, (each.value or 0) / each.max)) or 1
        bar.fill:SetShown(share > 0)
        bar.fill:SetWidth(math.max(1, (width - PAD * 2) * share))
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -y)
        bar:Show()
        y = y + BAR
    end
    return y + 4
end

-- A companion's profile: the person on top, their numbers below.
function layouts.brief(card, spec, width)
    local row = Row(card, 1)
    SetRow(row, spec, width, spec.onSelect)
    row.divider:Hide()
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
    row:Show()
    if spec.stats then
        return LayCells(card, spec.stats, ROW + 2, 16, width)
    end
    card.text:SetText(spec.empty or "")
    card.text:ClearAllPoints()
    card.text:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -(ROW + 2))
    card.text:Show()
    return ROW + 2 + card.text:GetStringHeight() + 14
end

-- A group that keeps coming together: their crests side by side, their
-- names in the book font, a line, and a sentence.
function layouts.group(card, spec, width)
    Title(card, spec)
    local y = BODY_TOP
    for index, person in ipairs(spec.people or {}) do
        local crest = card.crests[index]
        if not crest then
            crest = UI.Crest(card, CREST)
            card.crests[index] = crest
        end
        crest:SetPerson(person.name, person.class)
        crest:SetProgress(person.progress)
        crest:ClearAllPoints()
        crest:SetPoint("TOPLEFT", card, "TOPLEFT", PAD + (index - 1) * (CREST + CREST_GAP), -y)
        crest:Show()
    end
    if spec.people and #spec.people > 0 then
        y = y + CREST + 10
    end
    local names, line = GroupTexts(card)
    names:SetWidth(width - PAD * 2)
    names:SetText(spec.names or "")
    names:ClearAllPoints()
    names:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -y)
    names:Show()
    y = y + names:GetStringHeight() + 3
    line:SetWidth(width - PAD * 2)
    line:SetText(spec.line or "")
    line:ClearAllPoints()
    line:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -y)
    line:Show()
    y = y + line:GetStringHeight()
    if spec.text then
        card.text:SetText(spec.text)
        card.text:ClearAllPoints()
        card.text:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -(y + 10))
        card.text:Show()
        y = y + 10 + card.text:GetStringHeight()
    end
    return y + 14
end

function layouts.note(card, spec)
    Title(card, spec)
    card.text:SetText(spec.text or "")
    card.text:ClearAllPoints()
    card.text:SetPoint("TOPLEFT", card, "TOPLEFT", PAD, -BODY_TOP + 4)
    card.text:Show()
    return BODY_TOP - 4 + card.text:GetStringHeight() + 14
end

---------------------------------------------------------------------------

function UI.Rail(parent, width)
    local rail = CreateFrame("Frame", nil, parent)
    rail:SetWidth(width)
    rail.width = width
    rail.cards = {}

    -- Lays the cards out and returns the height they take.
    function rail:SetCards(cards)
        local y = 0
        for index, spec in ipairs(cards) do
            local card = self.cards[index]
            if not card then
                card = CreateCard(self)
                self.cards[index] = card
            end
            Reset(card)
            card.spec = spec
            local height = math.floor(layouts[spec.kind](card, spec, self.width) + 0.5)
            card:SetHeight(height)
            card.shape.border:SetColor(spec.selected and "cardActive" or "cardBorder")
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
            card:Show()
            y = y + height + GAP
        end
        for index = #cards + 1, #self.cards do
            self.cards[index]:Hide()
        end
        self:SetHeight(math.max(1, y))
        return y
    end

    return rail
end
