-- What is new, as a card at the top of the About page (Core/NewsService.lua):
-- the logo with its glow, "NEW IN 0.2.0" and a heading, then one row per
-- piece of news with its icon on an accent tile. The accent border sets it
-- apart from the plain rows below it. Built the first time About is drawn.
--
--   UI.NewsCard(parent):SetModel(model, width) -> height
--   model = { release = "0.2.0", items = { { icon, title, text }, ... } }

local _, ns = ...
local UI = ns.UI
local L = ns.L

local HEAD = 66 -- logo, eyebrow and heading
local PAD = 22
local LOGO = 30
local TILE, TILE_ICON = 32, 16
local GAP = 16 -- between tile and text
local ROW_PAD = 16
local TEXT_MAX = 600 -- longer lines read badly

local function NewRow(card)
    local row = {}
    row.tile = CreateFrame("Frame", nil, card)
    row.tile:SetSize(TILE, TILE)
    UI.Card(row.tile, "accentDeep", "accentLine", 8)
    row.icon = UI.Icon(row.tile, "flag", TILE_ICON, "accent")
    row.icon:SetPoint("CENTER")
    row.title = UI.Text(card, 14, "text", "medium")
    row.text = UI.Text(card, 12, "textDim")
    row.text:SetSpacing(3)
    row.line = UI.Line(card)
    return row
end

function UI.NewsCard(parent)
    local card = CreateFrame("Frame", nil, parent)
    card.shape = UI.Card(card, "card", "cardActive", 10)
    local pixel = UI.Pixel(card)
    local sheen = UI.Line(card, "sheenSoft")
    sheen:SetPoint("TOPLEFT", 10, -pixel)
    sheen:SetPoint("TOPRIGHT", -10, -pixel)

    local logo = card:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(UI.media.logo)
    logo:SetSize(LOGO, LOGO)
    logo:SetPoint("TOPLEFT", PAD, -(HEAD - LOGO) / 2)
    UI.Halo(card, logo, LOGO * 3, "accentHaze")
    card.eyebrow = UI.Text(card, 11, "accent", "semibold")
    card.eyebrow:SetPoint("TOPLEFT", logo, "TOPRIGHT", 14, -1)
    card.heading = UI.Text(card, 16, "text", "semibold")
    card.heading:SetPoint("TOPLEFT", card.eyebrow, "BOTTOMLEFT", 0, -4)
    local headLine = UI.Line(card)
    headLine:SetPoint("TOPLEFT", 0, -HEAD)
    headLine:SetPoint("TOPRIGHT", 0, -HEAD)
    card.rows = {}

    function card:SetModel(model, width)
        self:SetWidth(width)
        self.eyebrow:SetText(ns.Upper(L.ui_news_title:format(model.release)))
        self.heading:SetText(L.ui_news_heading)
        local textLeft = PAD + TILE + GAP
        local textWidth = math.min(TEXT_MAX, width - textLeft - PAD)
        local y = HEAD
        for index, item in ipairs(model.items) do
            local row = self.rows[index] or NewRow(self)
            self.rows[index] = row
            row.icon:SetTexture(UI.media[item.icon] or UI.media.sparkle)
            row.tile:ClearAllPoints()
            row.tile:SetPoint("TOPLEFT", self, "TOPLEFT", PAD, -(y + ROW_PAD))
            row.title:SetWidth(textWidth)
            row.title:SetText(item.title)
            row.title:ClearAllPoints()
            row.title:SetPoint("TOPLEFT", self, "TOPLEFT", textLeft, -(y + ROW_PAD))
            row.text:SetWidth(textWidth)
            row.text:SetText(item.text)
            row.text:ClearAllPoints()
            row.text:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -5)
            local height = ROW_PAD * 2 + math.max(TILE, row.title:GetStringHeight() + 5 + row.text:GetStringHeight())
            y = y + height
            -- A line below every row but the last.
            row.line:ClearAllPoints()
            row.line:SetPoint("TOPLEFT", self, "TOPLEFT", PAD, -y)
            row.line:SetPoint("TOPRIGHT", self, "TOPRIGHT", -PAD, -y)
            row.line:SetShown(index < #model.items)
            for _, part in ipairs({ row.tile, row.title, row.text }) do
                part:Show()
            end
        end
        for index = #model.items + 1, #self.rows do
            local row = self.rows[index]
            for _, part in ipairs({ row.tile, row.title, row.text, row.line }) do
                part:Hide()
            end
        end
        y = y + 2
        self:SetHeight(y)
        return y
    end

    return card
end
