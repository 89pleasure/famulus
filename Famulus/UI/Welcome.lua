-- The welcome page: what the window shows when it opens for the first time.
-- With the defaults a new player sees almost nothing (everything that listens
-- to the game or sends to others is off), so the page says in a few words
-- what Famulus does and switches the main features on with one click, or
-- leaves the choice to the player.
--
-- It lies over the window below its head, on a ground of its own, and covers
-- sidebar and content; UI/Options.lua decides when. Built the first time it
-- is shown.

local _, ns = ...
local L = ns.L
local UI = ns.UI

local Welcome = {}
UI.Welcome = Welcome

-- The main features that are off by default and that the one click switches
-- on, in the order of the sidebar.
Welcome.FEATURES = { "ownJourney", "companions", "sharing", "rememberFellows", "nearbyFriends" }

-- The window opens on the page until the player has chosen (FamulusDB.welcome)
-- and only while none of the five is switched on: whoever switched one on
-- already knows their way.
function Welcome.Wanted()
    if not ns.global or ns.global.welcome then
        return false
    end
    for _, id in ipairs(Welcome.FEATURES) do
        if ns:GetOption(id, "enabled") then
            return false
        end
    end
    return true
end

-- The ones the click switches on: those the client can run that are not on yet.
function Welcome.Pending()
    local list = {}
    for _, id in ipairs(Welcome.FEATURES) do
        local feature = ns.features[id]
        if feature and not feature.failed and feature:IsAvailable() and not ns:GetOption(id, "enabled") then
            list[#list + 1] = feature
        end
    end
    return list
end

-- The player chose; the page no longer opens by itself.
function Welcome.Decide()
    if ns.global then
        ns.global.welcome = true
    end
end

-- Switches on what is pending, and the master switches of their main
-- features, so that it runs. One line in the chat says how much. Returns
-- the number.
function Welcome.SwitchOn()
    local pending = Welcome.Pending()
    for _, feature in ipairs(pending) do
        ns:SetOption("categories", feature.category, true)
        ns:SetOption(feature.id, "enabled", true)
    end
    Welcome.Decide()
    if #pending > 0 then
        ns:Notify(ns.Plural("msg_welcome_on", #pending):format(#pending))
    end
    return #pending
end

---------------------------------------------------------------------------
-- The page
---------------------------------------------------------------------------

-- Wide enough that a tile's line takes three lines at most in French, so
-- that the page fits the window with its list open.
local COLUMN = 760 -- width of everything on the page
local LOGO = 96
local TILE_GAP, TILE_PAD, BADGE = 12, 14, 30
local CELL_H = 46 -- a feature in the list
local BUTTON_H = 46

-- The three main features in a line each; the aliases already run.
local AREAS = {
    { id = "chronicle", icon = "flag" },
    { id = "fellows", icon = "people" },
    { id = "aliases", icon = "tag", running = true },
}

-- What already runs without a choice: the aliases and the live feed.
local function RunningNames()
    local names = {}
    if ns:IsCategoryEnabled("aliases") then
        names[#names + 1] = L.area_aliases
    end
    if ns.features.liveFeed and ns.features.liveFeed.enabled then
        names[#names + 1] = L.f_liveFeed
    end
    return names
end

local function CreateTile(parent, area)
    local tile = CreateFrame("Frame", nil, parent)
    tile:SetWidth(math.floor((COLUMN - TILE_GAP * 2) / 3))
    UI.Card(tile, "card", "cardBorder", 10)
    local pixel = UI.Pixel(tile)
    local sheen = UI.Line(tile, "sheenSoft")
    sheen:SetPoint("TOPLEFT", 10, -pixel)
    sheen:SetPoint("TOPRIGHT", -10, -pixel)

    local badge = CreateFrame("Frame", nil, tile)
    badge:SetSize(BADGE, BADGE)
    badge:SetPoint("TOPLEFT", TILE_PAD, -TILE_PAD)
    tile.badge = UI.Round(badge, "control", 8)
    tile.icon = UI.Icon(badge, area.icon, 16, "textMuted")
    tile.icon:SetPoint("CENTER")

    local textWidth = tile:GetWidth() - TILE_PAD * 2 - BADGE - 11
    tile.name = UI.Text(tile, 13, "text", "semibold")
    tile.name:SetPoint("TOPLEFT", badge, "TOPRIGHT", 11, 0)
    tile.name:SetWidth(textWidth)
    tile.line = UI.Text(tile, 12, "textMuted")
    tile.line:SetPoint("TOPLEFT", tile.name, "BOTTOMLEFT", 0, -3)
    tile.line:SetWidth(textWidth)
    tile.line:SetSpacing(2)
    tile.area = area
    return tile
end

-- Fills a tile; returns the height its text needs.
local function FillTile(tile)
    local area = tile.area
    local running = area.running and ns:IsCategoryEnabled(area.id)
    tile.badge:SetColor(running and "accentSoft" or "control")
    UI.Tint(tile.icon, running and "accent" or "textMuted")
    tile.name:SetText(L["area_" .. area.id])
    local line = L["ui_welcome_" .. area.id]
    if running then
        line = line .. " " .. L.ui_welcome_on
    end
    tile.line:SetText(line)
    return math.max(BADGE, tile.name:GetStringHeight() + 3 + tile.line:GetStringHeight()) + TILE_PAD * 2
end

-- One feature in the list: a mark (lit if the click switches it on or it is
-- on), its name, and whether it stays with the player or goes to others.
local function CreateCell(parent)
    local cell = CreateFrame("Frame", nil, parent)
    cell:SetSize(COLUMN / 2, CELL_H)
    cell.mark = cell:CreateTexture(nil, "ARTWORK")
    cell.mark:SetTexture(UI.media.circle)
    cell.mark:SetSize(20, 20)
    cell.mark:SetPoint("LEFT", 14, 0)
    cell.check = UI.Icon(cell, "check", 12, "onAccent", "OVERLAY")
    cell.check:SetPoint("CENTER", cell.mark, "CENTER")
    cell.name = UI.Text(cell, 13, "text", "medium")
    cell.name:SetPoint("TOPLEFT", cell.mark, "TOPRIGHT", 11, 9)
    cell.name:SetWidth(COLUMN / 2 - 14 - 20 - 11 - 12)
    cell.name:SetWordWrap(false)
    cell.tagIcon = UI.Icon(cell, "person", 12, "textMuted")
    cell.tagIcon:SetPoint("TOPLEFT", cell.name, "BOTTOMLEFT", 0, -3)
    cell.tag = UI.Text(cell, 11, "textMuted")
    cell.tag:SetPoint("LEFT", cell.tagIcon, "RIGHT", 5, 0)
    cell.tag:SetJustifyV("MIDDLE")
    cell.tag:SetWidth(COLUMN / 2 - 14 - 20 - 11 - 12 - 17)
    cell.tag:SetWordWrap(false)
    return cell
end

-- kind: "local" (stays with the player), "shares" (goes to others) or
-- "running" (on without a choice). usable: false for a feature the client
-- cannot run; it stays faint and unmarked.
local function FillCell(cell, name, tag, kind, usable)
    local running, shares = kind == "running", kind == "shares"
    cell.name:SetText(name)
    cell.tag:SetText(tag)
    UI.Tint(cell.mark, usable and not running and "accent" or "chip")
    cell.check:SetShown(usable)
    UI.Tint(cell.check, running and "textDim" or "onAccent")
    cell.tagIcon:SetTexture(UI.media[shares and "share" or (running and "check" or "person")])
    UI.Tint(cell.tagIcon, shares and "shareInk" or "textMuted")
    UI.Ink(cell.tag, shares and "shareInk" or "textMuted")
    UI.Ink(cell.name, running and "textDim" or "text")
    cell:SetAlpha(usable and 1 or 0.45)
    cell:Show()
end

-- Builds the page over `window`. size: { width, height, head, radius,
-- grain } of the window. actions: all(), choose(), later(). Returns the
-- page; page:Refresh() lays it out anew (language, state, the list open or
-- not); page.embers are its sparks, to play while it is shown.
function Welcome.Build(window, size, actions)
    local pixel = UI.Pixel(window)
    local width = size.width - pixel * 2
    local height = size.height - size.head - pixel * 2

    local page = CreateFrame("Frame", nil, window)
    page:SetPoint("TOPLEFT", window, "TOPLEFT", pixel, -(size.head + pixel))
    page:SetSize(width, height)
    -- Above everything the window holds below its head.
    page:SetFrameLevel(window:GetFrameLevel() + 100)
    page:EnableMouse(true)
    page:EnableMouseWheel(true)
    page:SetScript("OnMouseWheel", function() end)
    -- Dragging it moves the window, as dragging the window does.
    page:RegisterForDrag("LeftButton")
    page:SetScript("OnDragStart", function()
        window:StartMoving()
    end)
    page:SetScript("OnDragStop", function()
        local stop = window:GetScript("OnDragStop")
        if stop then
            stop(window)
        else
            window:StopMovingOrSizing()
        end
    end)
    page:Hide()

    -- The window's ground, square at the top where the head joins: grain
    -- running on from the head, darker towards the bottom, a glow behind
    -- the logo and sparks rising through it all.
    UI.Round(page, "window", size.radius - pixel, { square = { TOPLEFT = true, TOPRIGHT = true } })
    local dusk = page:CreateTexture(nil, "BACKGROUND", nil, 3)
    dusk:SetPoint("TOPLEFT", page, "TOPLEFT", 3, -math.floor(size.height * 0.45 - size.head))
    dusk:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -3, 3)
    UI.Shade(dusk, "VERTICAL", "clear", "dusk")
    UI.Grain(page, 3, 0, 3, height - (size.grain - size.head), width, height, true)
    page.embers = UI.Embers(page, 16, 0, width, height, 37)

    local logo = page:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(UI.media.logo)
    logo:SetSize(LOGO, LOGO)
    UI.Halo(page, logo, LOGO * 3.4, "accentHaze")

    local title = UI.Text(page, 28, "text", "semibold")
    title:SetWidth(COLUMN)
    title:SetJustifyH("CENTER")
    local lede = UI.Text(page, 14, "textDim")
    lede:SetWidth(540)
    lede:SetJustifyH("CENTER")
    lede:SetSpacing(4)

    local tiles = {}
    for index, area in ipairs(AREAS) do
        tiles[index] = CreateTile(page, area)
    end

    -- The one click, glowing a little.
    local all = UI.Button(page, function()
        actions.all()
    end, "primary", "flag")
    all:SetHeight(BUTTON_H)
    all.padding = 56
    UI.SetFont(all.label, 14, "semibold")
    UI.Shadow(all, 18, 8, 8, "accentHaze")
    page.all = all

    local note = UI.Text(page, 12, "textMuted")
    note:SetWidth(640)
    note:SetJustifyH("CENTER")
    note:SetSpacing(3)

    -- What exactly: the five, two to a line, and what already runs.
    local list = CreateFrame("Frame", nil, page)
    list:SetWidth(COLUMN)
    UI.Card(list, "sunken", "divider", 9)
    local cells = {}
    for index = 1, 6 do
        local cell = CreateCell(list)
        cell:SetPoint("TOPLEFT", list, "TOPLEFT", ((index - 1) % 2) * COLUMN / 2, -math.floor((index - 1) / 2) * CELL_H)
        cells[index] = cell
    end
    local middle = UI.VLine(list, "divider")
    middle:SetPoint("TOP", list, "TOP", 0, -pixel)
    middle:SetPoint("BOTTOM", list, "BOTTOM", 0, pixel)
    local rules = {}
    for index = 1, 2 do
        local rule = UI.Line(list, "divider")
        rule:SetPoint("TOPLEFT", list, "TOPLEFT", pixel, -index * CELL_H)
        rule:SetPoint("TOPRIGHT", list, "TOPRIGHT", -pixel, -index * CELL_H)
        rules[index] = rule
    end
    list:Hide()
    page.title, page.note, page.list, page.cells = title, note, list, cells

    local open = false
    local more = UI.Button(page, function()
        open = not open
        page:Refresh()
    end, "ghost", "chevron")
    local choose = UI.Button(page, function()
        actions.choose()
    end, "ghost")
    local later = UI.Button(page, function()
        actions.later()
    end, "ghost")
    page.more, page.choose, page.later = more, choose, later

    local function FillList()
        local index = 0
        for _, id in ipairs(Welcome.FEATURES) do
            local feature = ns.features[id]
            if feature then
                index = index + 1
                local usable = not feature.failed and feature:IsAvailable()
                local shares = id == "sharing"
                FillCell(cells[index], L["f_" .. id], shares and L.ui_welcome_shares or L.ui_welcome_local,
                    shares and "shares" or "local", usable)
            end
        end
        local running = RunningNames()
        if #running > 0 then
            index = index + 1
            FillCell(cells[index], L.ui_welcome_running:format(table.concat(running, ", ")), L.ui_welcome_running_desc,
                "running", true)
        end
        for rest = index + 1, #cells do
            cells[rest]:Hide()
        end
        local lines = math.ceil(index / 2)
        rules[1]:SetShown(lines > 1)
        rules[2]:SetShown(lines > 2)
        list:SetHeight(lines * CELL_H)
        return lines * CELL_H
    end

    function page:Refresh()
        title:SetText(L.ui_welcome_title)
        lede:SetText(L.ui_welcome_lede)
        local tileHeight = 0
        for _, tile in ipairs(tiles) do
            tileHeight = math.max(tileHeight, FillTile(tile))
        end
        all:SetLabel(L.ui_welcome_all)
        local pending = #Welcome.Pending()
        if pending > 0 then
            note:SetText(ns.Plural("ui_welcome_note", pending):format(pending))
        else
            note:SetText(L.ui_welcome_note_done)
        end
        more:SetLabel(open and L.ui_welcome_less or L.ui_welcome_more)
        -- The chevron points down while the list is shut, up while it is open.
        if open then
            more.icon:SetTexCoord(0, 1, 1, 0)
        else
            more.icon:SetTexCoord(0, 1, 0, 1)
        end
        choose:SetLabel(L.ui_welcome_choose)
        later:SetLabel(L.ui_welcome_later)
        local listHeight = FillList()
        list:SetShown(open)

        -- Top to bottom, centred. The column starts a little above the middle
        -- and stays put when the list opens, as long as the list then fits.
        local parts = {
            { LOGO, 0 },
            { title:GetStringHeight(), 10 },
            { lede:GetStringHeight(), 10 },
            { tileHeight, 22 },
            { BUTTON_H, 24 },
            { note:GetStringHeight(), 12 },
            { 28, 16 }, -- the links
        }
        local shut = 0
        for _, part in ipairs(parts) do
            shut = shut + part[1] + part[2]
        end
        local extra = listHeight + 14
        local top = math.floor((height - shut) * 0.4)
        top = math.max(16, math.min(top, height - shut - extra - 16))

        local y = top
        logo:ClearAllPoints()
        logo:SetPoint("TOP", page, "TOP", 0, -y)
        y = y + LOGO + 10
        title:ClearAllPoints()
        title:SetPoint("TOP", page, "TOP", 0, -y)
        y = y + title:GetStringHeight() + 10
        lede:ClearAllPoints()
        lede:SetPoint("TOP", page, "TOP", 0, -y)
        y = y + lede:GetStringHeight() + 22
        local tileWidth = tiles[1]:GetWidth()
        for index, tile in ipairs(tiles) do
            tile:SetHeight(tileHeight)
            tile:ClearAllPoints()
            tile:SetPoint("TOPLEFT", page, "TOP", -COLUMN / 2 + (index - 1) * (tileWidth + TILE_GAP), -y)
        end
        y = y + tileHeight + 24
        all:ClearAllPoints()
        all:SetPoint("TOP", page, "TOP", 0, -y)
        y = y + BUTTON_H + 12
        note:ClearAllPoints()
        note:SetPoint("TOP", page, "TOP", 0, -y)
        y = y + note:GetStringHeight()
        if open then
            y = y + 14
            list:ClearAllPoints()
            list:SetPoint("TOP", page, "TOP", 0, -y)
            y = y + listHeight
        end
        y = y + 16
        -- The links side by side, centred as a row.
        local gap = 8
        local row = more:GetWidth() + choose:GetWidth() + later:GetWidth() + gap * 2
        more:ClearAllPoints()
        more:SetPoint("TOPLEFT", page, "TOP", -row / 2, -y)
        choose:ClearAllPoints()
        choose:SetPoint("LEFT", more, "RIGHT", gap, 0)
        later:ClearAllPoints()
        later:SetPoint("LEFT", choose, "RIGHT", gap, 0)
    end

    -- The list is shut again when the page or the window closes.
    page:SetScript("OnHide", function()
        open = false
    end)
    window:HookScript("OnHide", function()
        open = false
    end)
    return page
end
