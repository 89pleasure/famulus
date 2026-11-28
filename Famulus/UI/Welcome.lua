-- The welcome page: what the window shows when it opens for the first time.
-- The journey records from the start; everything else that listens to the
-- game or sends to others is off. So the page says what Famulus does, in
-- the words of the website, and walks the player through the main features
-- one at a time: what each does, an example drawn live (the settings'
-- pictures, UI/Previews.lua), the one option worth deciding at once, switch
-- on or skip. One click switches the four that are off by default on instead.
--
-- It lies over the window below its head, on a ground of its own, and covers
-- sidebar and content; UI/Options.lua decides when. Built the first time it
-- is shown. Three views: the start, a step, the end.

local _, ns = ...
local L = ns.L
local UI = ns.UI

local Welcome = {}
UI.Welcome = Welcome

-- The main features that are off by default; while one is on, the page no
-- longer opens by itself, and one click switches them all on.
Welcome.FEATURES = { "companions", "sharing", "rememberFellows", "nearbyFriends" }

-- The steps, in the order of the sidebar: a feature each, and the option
-- shown with it (`owner`: the feature the option belongs to, if another;
-- `desc`: a shorter text for it than the settings' own).
-- The live feed is on by default; its step is where the reactions are.
Welcome.STEPS = {
    { id = "companions" },
    { id = "sharing" },
    { id = "liveFeed", option = "reactions", owner = "sharing", desc = "ui_welcome_liveFeed_option" },
    { id = "rememberFellows", option = "friendsOnly" },
    { id = "nearbyFriends", option = "guild" },
}

-- The feature a step's option belongs to.
local function OptionOwner(step)
    return ns.features[step.owner or step.id]
end

local function Usable(feature)
    return feature and not feature.failed and feature:IsAvailable()
end

-- The window opens on the page until the player has chosen (FamulusDB.welcome)
-- and only while none of the four is switched on: whoever switched one on
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
        if Usable(feature) and not ns:GetOption(id, "enabled") then
            list[#list + 1] = feature
        end
    end
    return list
end

-- The steps the client can run.
function Welcome.Steps()
    local list = {}
    for _, step in ipairs(Welcome.STEPS) do
        if Usable(ns.features[step.id]) then
            list[#list + 1] = step
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

-- Switches a feature on, and the master switch of its area, so that it runs.
function Welcome.Enable(feature)
    ns:SetOption("categories", feature.category, true)
    ns:SetOption(feature.id, "enabled", true)
end

-- Switches on what is pending. One line in the chat says how much. Returns
-- the number.
function Welcome.SwitchOn()
    local pending = Welcome.Pending()
    for _, feature in ipairs(pending) do
        Welcome.Enable(feature)
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

local COLUMN = 960 -- width of the start's tiles
local LOGO = 80
local TILE_GAP, TILE_PAD, BADGE = 12, 16, 30
local BIG_H = 46 -- the large buttons
local SIDE = 48 -- room left and right of a step
local TEXT_W = 440 -- a step's text
local STAGE_GAP, STAGE_H = 40, 340 -- the step's picture
local FOOT_H = 76 -- a step's row of buttons
local DONE_W, DONE_ROW = 720, 48 -- the end's list

-- The start's tiles: the four things Famulus does, as on the website. on():
-- whether it runs already.
local AREAS = {
    { key = "chronicle", icon = "flag", on = function()
        return ns.features.ownJourney and ns.features.ownJourney.enabled
    end },
    { key = "fellows", icon = "people", on = function()
        local fellows, nearby = ns.features.rememberFellows, ns.features.nearbyFriends
        return (fellows and fellows.enabled) or (nearby and nearby.enabled) or false
    end },
    { key = "feed", icon = "bell", name = "f_liveFeed", on = function()
        return ns.features.liveFeed and ns.features.liveFeed.enabled
    end },
    { key = "aliases", icon = "tag", on = function()
        return ns:IsCategoryEnabled("aliases")
    end },
}

local function CreateTile(parent)
    local tile = CreateFrame("Frame", nil, parent)
    tile:SetWidth(math.floor((COLUMN - TILE_GAP * 3) / 4))
    UI.Card(tile, "card", "cardBorder", 10)
    local pixel = UI.Pixel(tile)
    local sheen = UI.Line(tile, "sheenSoft")
    sheen:SetPoint("TOPLEFT", 10, -pixel)
    sheen:SetPoint("TOPRIGHT", -10, -pixel)

    local badge = CreateFrame("Frame", nil, tile)
    badge:SetSize(BADGE, BADGE)
    badge:SetPoint("TOPLEFT", TILE_PAD, -TILE_PAD)
    tile.badge = UI.Round(badge, "control", 8)
    tile.icon = UI.Icon(badge, "flag", 16, "textMuted")
    tile.icon:SetPoint("CENTER")
    tile.pill = UI.Pill(tile)
    tile.pill:SetPoint("TOPRIGHT", -TILE_PAD + 2, -TILE_PAD - 4)

    local textWidth = tile:GetWidth() - TILE_PAD * 2
    tile.name = UI.Text(tile, 14, "text", "semibold")
    tile.name:SetPoint("TOPLEFT", badge, "BOTTOMLEFT", 0, -10)
    tile.name:SetWidth(textWidth)
    tile.line = UI.Text(tile, 12, "textDim")
    tile.line:SetPoint("TOPLEFT", tile.name, "BOTTOMLEFT", 0, -6)
    tile.line:SetWidth(textWidth)
    tile.line:SetSpacing(3)
    return tile
end

-- Fills a tile; returns the height its text needs.
local function FillTile(tile, area)
    local on = area.on()
    tile.badge:SetColor(on and "accentSoft" or "control")
    tile.icon:SetTexture(UI.media[area.icon])
    UI.Tint(tile.icon, on and "accent" or "textMuted")
    tile.pill:SetShown(on)
    tile.pill:Set(L.ui_welcome_on, true)
    tile.name:SetText(area.name and L[area.name] or L["area_" .. area.key])
    tile.line:SetText(L["ui_welcome_" .. area.key])
    return TILE_PAD + BADGE + 10 + tile.name:GetStringHeight() + 6 + tile.line:GetStringHeight() + TILE_PAD
end

-- A large button: the page's main actions.
local function BigButton(parent, onClick, variant)
    local button = UI.Button(parent, onClick, variant)
    button:SetHeight(BIG_H)
    button.padding = 56
    UI.SetFont(button.label, 14, variant == "primary" and "semibold" or "medium")
    if variant == "primary" then
        UI.Shadow(button, 18, 8, 8, "accentHaze")
    end
    return button
end

-- Centred text of the page.
local function Centered(parent, size, token, weight, width)
    local text = UI.Text(parent, size, token, weight)
    text:SetWidth(width)
    text:SetJustifyH("CENTER")
    return text
end

-- Puts regions one below the other, centred; parts: { region, height, gap
-- above }. Each part keeps where it starts (part.y).
local function Stack(view, parts, top)
    local y = top
    for _, part in ipairs(parts) do
        y = y + part[3]
        part.y = y
        part[1]:ClearAllPoints()
        part[1]:SetPoint("TOP", view, "TOP", 0, -y)
        y = y + part[2]
    end
end

local function SumHeight(parts)
    local total = 0
    for _, part in ipairs(parts) do
        total = total + part[2] + part[3]
    end
    return total
end

-- Builds the page over `window`. size: { width, height, head, radius,
-- grain } of the window. actions: finish() (the chronicle opens), later().
-- Returns the page; page:Refresh() lays it out anew (language, state);
-- page.embers are its sparks, to play while it is shown.
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

    -- view: "start", "done" or the number of the step shown. switched: the
    -- features the steps switched on (id -> true), counted for the one line
    -- at the end; one switched off again is taken out. via: where the end
    -- goes back to.
    page.view, page.switched, page.via = "start", {}, "start"
    local function Go(view)
        page.view = view
        page:Refresh()
    end

    local function Finish()
        Welcome.Decide()
        local count = 0
        for _ in pairs(page.switched) do
            count = count + 1
        end
        if count > 0 then
            ns:Notify(ns.Plural("msg_welcome_on", count):format(count))
        end
        page.switched = {}
        actions.finish()
    end

    -----------------------------------------------------------------------
    -- Start
    -----------------------------------------------------------------------
    local start = CreateFrame("Frame", nil, page)
    start:SetAllPoints(page)
    page.start = start

    local logo = start:CreateTexture(nil, "ARTWORK")
    logo:SetTexture(UI.media.logo)
    logo:SetSize(LOGO, LOGO)
    UI.Halo(start, logo, LOGO * 3.4, "accentHaze")
    local eyebrow = Centered(start, 12, "accent", "semibold", COLUMN)
    local title = Centered(start, 30, "text", "semibold", COLUMN)
    local lede = Centered(start, 14, "textDim", nil, 600)
    lede:SetSpacing(4)
    page.eyebrow, page.title, page.lede = eyebrow, title, lede

    local tiles = {}
    for index = 1, #AREAS do
        tiles[index] = CreateTile(start)
    end
    page.tiles = tiles

    -- The colour scheme, chosen right here: the window follows at once.
    local scheme = CreateFrame("Frame", nil, start)
    scheme:SetHeight(26)
    scheme.label = UI.Text(scheme, 12, "textMuted", "medium")
    scheme.label:SetPoint("LEFT")
    scheme.swatches = UI.Swatches(scheme, function(value)
        ns:SetOption("general", "accent", value)
        page:Refresh()
    end)
    scheme.swatches:SetPoint("LEFT", scheme.label, "RIGHT", 10, 0)
    page.scheme = scheme

    local buttons = CreateFrame("Frame", nil, start)
    buttons:SetHeight(BIG_H)
    page.setup = BigButton(buttons, function()
        page.via = "start"
        Go(Welcome.Steps()[1] and 1 or "done")
    end, "primary")
    page.setup:SetPoint("LEFT")
    page.all = BigButton(buttons, function()
        page.switched = {}
        Welcome.SwitchOn()
        page.via = "start"
        Go("done")
    end, "secondary")
    page.all:SetPoint("LEFT", page.setup, "RIGHT", 12, 0)
    local note = Centered(start, 12, "textMuted", nil, 640)
    note:SetSpacing(3)
    page.note = note
    page.later = UI.Button(start, function()
        Welcome.Decide()
        actions.later()
    end, "ghost")

    local function RefreshStart()
        eyebrow:SetText(ns.Upper(L.ui_welcome_eyebrow))
        title:SetText(L.ui_welcome_title)
        lede:SetText(L.ui_welcome_lede)
        local tileHeight = 0
        for index, tile in ipairs(tiles) do
            tileHeight = math.max(tileHeight, FillTile(tile, AREAS[index]))
        end
        scheme.label:SetText(L.g_accent)
        scheme.swatches:SetValues(UI.accents, ns:GetOption("general", "accent"))
        scheme:SetWidth(scheme.label:GetStringWidth() + 10 + scheme.swatches:GetWidth())
        page.setup:SetLabel(L.ui_welcome_setup)
        page.all:SetLabel(L.ui_welcome_all)
        buttons:SetWidth(page.setup:GetWidth() + 12 + page.all:GetWidth())
        note:SetText(L.ui_welcome_note)
        page.later:SetLabel(L.ui_welcome_later)

        local parts = {
            { logo, LOGO, 0 },
            { eyebrow, eyebrow:GetStringHeight(), 14 },
            { title, title:GetStringHeight(), 8 },
            { lede, lede:GetStringHeight(), 12 },
            { tiles[1], tileHeight, 28 }, -- the row of tiles, laid out below
            { scheme, 26, 20 },
            { buttons, BIG_H, 24 },
            { note, note:GetStringHeight(), 14 },
            { page.later, page.later:GetHeight(), 8 },
        }
        local top = math.max(16, math.floor((height - SumHeight(parts)) * 0.42))
        Stack(start, parts, top)
        -- The tiles side by side where the stack put the row.
        local tileWidth = tiles[1]:GetWidth()
        for index, tile in ipairs(tiles) do
            tile:SetHeight(tileHeight)
            tile:ClearAllPoints()
            tile:SetPoint("TOPLEFT", start, "TOP", -COLUMN / 2 + (index - 1) * (tileWidth + TILE_GAP), -parts[5].y)
        end
    end

    -----------------------------------------------------------------------
    -- A step
    -----------------------------------------------------------------------
    local step = CreateFrame("Frame", nil, page)
    step:SetAllPoints(page)
    page.step = step

    local count = UI.Text(step, 12, "textMuted", "semibold")
    count:SetPoint("TOPLEFT", SIDE, -24)
    page.count = count
    local bars = {}
    for index = 1, #Welcome.STEPS do
        local bar = CreateFrame("Frame", nil, step)
        bar:SetHeight(4)
        bar.shape = UI.Round(bar, "track", 2)
        bars[index] = bar
    end

    local top = 64
    local area = UI.Icon(step, "flag", 14, "accent")
    area:SetPoint("TOPLEFT", SIDE, -top)
    local areaName = UI.Text(step, 12, "accent", "semibold")
    areaName:SetPoint("LEFT", area, "RIGHT", 8, 0)
    local name = UI.Text(step, 26, "text", "semibold")
    name:SetPoint("TOPLEFT", area, "BOTTOMLEFT", 0, -12)
    name:SetWidth(TEXT_W)
    page.name = name

    -- Whether it stays with the player or goes to others.
    local tag = CreateFrame("Frame", nil, step)
    tag:SetHeight(24)
    tag:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -12)
    tag.ground = UI.Round(tag, "chip", 12)
    tag.icon = UI.Icon(tag, "person", 12, "textDim")
    tag.icon:SetPoint("LEFT", 10, 0)
    tag.text = UI.Text(tag, 12, "textDim")
    tag.text:SetPoint("LEFT", tag.icon, "RIGHT", 6, 0)
    tag.text:SetJustifyV("MIDDLE")
    page.tag = tag

    local body = UI.Text(step, 14, "textDim")
    body:SetPoint("TOPLEFT", tag, "BOTTOMLEFT", 0, -16)
    body:SetWidth(TEXT_W)
    body:SetSpacing(4)
    page.body = body

    local points = {}
    for index = 1, 2 do
        local point = CreateFrame("Frame", nil, step)
        point:SetWidth(TEXT_W)
        point.dot = UI.GlowDot(point, 6)
        point.dot:SetPoint("TOPLEFT", 0, -6)
        point.title = UI.Text(point, 13, "text", "semibold")
        point.title:SetPoint("TOPLEFT", 18, 0)
        point.title:SetWidth(TEXT_W - 18)
        point.text = UI.Text(point, 13, "textDim")
        point.text:SetPoint("TOPLEFT", point.title, "BOTTOMLEFT", 0, -3)
        point.text:SetWidth(TEXT_W - 18)
        point.text:SetSpacing(3)
        points[index] = point
    end
    page.points = points

    -- The option worth deciding at once: a row with its switch; pointing at
    -- it shows it in the picture.
    local option = CreateFrame("Button", nil, step)
    option:SetWidth(TEXT_W)
    UI.Card(option, "sunken", "divider", 9)
    option.name = UI.Text(option, 13, "text", "semibold")
    option.name:SetPoint("TOPLEFT", 14, -12)
    option.name:SetWidth(TEXT_W - 28 - 54)
    option.desc = UI.Text(option, 12, "textMuted")
    option.desc:SetPoint("TOPLEFT", option.name, "BOTTOMLEFT", 0, -4)
    option.desc:SetWidth(TEXT_W - 28 - 54)
    option.desc:SetSpacing(2)
    option.toggle = UI.Toggle(option)
    option.toggle:SetPoint("RIGHT", -14, 0)
    page.option = option

    local stage = UI.Previews.Stage(step, width - SIDE * 2 - TEXT_W - STAGE_GAP, STAGE_H)
    stage:SetPoint("TOPLEFT", SIDE + TEXT_W + STAGE_GAP, -top)
    -- The picture shows what the feature would do, before it is on.
    stage.lit = true
    page.stage = stage

    option:SetScript("OnClick", function(self)
        local current = page.current
        local owner = OptionOwner(current)
        ns:SetOption(owner.id, current.option, not owner:Get(current.option))
        self.toggle:Set(owner:Get(current.option), true)
        UI.Previews.Refresh(stage)
    end)
    option:SetScript("OnEnter", function()
        UI.Previews.Focus(stage, page.current and page.current.option)
    end)
    option:SetScript("OnLeave", function()
        UI.Previews.Focus(stage, nil)
    end)

    local foot = UI.Line(step, "divider")
    foot:SetPoint("BOTTOMLEFT", step, "BOTTOMLEFT", 0, FOOT_H)
    foot:SetPoint("BOTTOMRIGHT", step, "BOTTOMRIGHT", 0, FOOT_H)
    local function Next()
        local steps = Welcome.Steps()
        local index = page.view
        Go(index < #steps and index + 1 or "done")
    end
    page.back = UI.Button(step, function()
        Go(page.view > 1 and page.view - 1 or "start")
    end, "ghost")
    page.back:SetHeight(40)
    page.back:SetPoint("BOTTOMLEFT", SIDE - 10, (FOOT_H - 40) / 2)
    page.on = UI.Button(step, function()
        local feature = ns.features[page.current.id]
        if not feature.enabled then
            Welcome.Enable(feature)
            page.switched[feature.id] = true
        end
        page.via = page.view
        Next()
    end, "primary")
    page.on:SetHeight(40)
    page.on.padding = 48
    page.on:SetPoint("BOTTOMRIGHT", -SIDE, (FOOT_H - 40) / 2)
    -- Skip: the feature stays off; one that is on already is switched off.
    page.skip = UI.Button(step, function()
        local feature = ns.features[page.current.id]
        if feature.enabled then
            ns:SetOption(feature.id, "enabled", false)
        end
        page.switched[feature.id] = nil
        page.via = page.view
        Next()
    end, "ghost")
    page.skip:SetHeight(40)
    page.skip:SetPoint("RIGHT", page.on, "LEFT", -8, 0)

    local function RefreshStep()
        local steps = Welcome.Steps()
        local index = page.view
        local current = steps[index]
        page.current = current
        local feature = ns.features[current.id]
        -- Whether it runs, as the buttons act on: its own switch may be on
        -- while its area's is off.
        local on = feature.enabled

        count:SetText(L.ui_welcome_step:format(index, #steps))
        local left = SIDE + count:GetStringWidth() + 16
        local barWidth = (width - SIDE - left - 6 * (#steps - 1)) / #steps
        for number, bar in ipairs(bars) do
            bar:SetShown(number <= #steps)
            bar:ClearAllPoints()
            bar:SetPoint("LEFT", step, "TOPLEFT", left + (number - 1) * (barWidth + 6), -24 - count:GetStringHeight() / 2)
            bar:SetWidth(barWidth)
            bar.shape:SetColor(number == index and "accent" or (number < index and "accentLine" or "track"))
        end

        area:SetTexture(UI.media[feature.category == "fellows" and "people" or "flag"])
        areaName:SetText(ns.Upper(L["area_" .. feature.category]))
        name:SetText(L["f_" .. current.id])
        local shares = current.id == "sharing"
        tag.icon:SetTexture(UI.media[shares and "share" or "person"])
        UI.Tint(tag.icon, shares and "shareInk" or "textDim")
        UI.Ink(tag.text, shares and "shareInk" or "textDim")
        tag.text:SetText(shares and L.ui_welcome_shares or L.ui_welcome_local)
        tag:SetWidth(math.floor(10 + 12 + 6 + tag.text:GetStringWidth() + 12.5))
        body:SetText(L["ui_welcome_" .. current.id .. "_lede"])

        local anchor, gap = body, 20
        for number, point in ipairs(points) do
            point.title:SetText(L["ui_welcome_" .. current.id .. "_p" .. number .. "_t"])
            point.text:SetText(L["ui_welcome_" .. current.id .. "_p" .. number])
            point:SetHeight(point.title:GetStringHeight() + 3 + point.text:GetStringHeight())
            point:ClearAllPoints()
            point:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -gap)
            anchor, gap = point, 14
        end

        option:SetShown(current.option ~= nil)
        if current.option then
            local owner = OptionOwner(current)
            option.name:SetText(L["o_" .. owner.id .. "_" .. current.option])
            option.desc:SetText(L[current.desc or ("o_" .. owner.id .. "_" .. current.option .. "_desc")])
            option:SetHeight(12 + option.name:GetStringHeight() + 4 + option.desc:GetStringHeight() + 12)
            option.toggle:Set(owner:Get(current.option))
            option:ClearAllPoints()
            option:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -20)
        end

        UI.Previews.Show(stage, feature.preview)
        page.back:SetLabel(L.ui_welcome_back)
        page.on:SetLabel(on and L.ui_welcome_continue or (index == #steps and L.ui_welcome_last or L.ui_welcome_next))
        page.skip:SetLabel(on and L.ui_welcome_off or L.ui_welcome_skip)
    end

    -----------------------------------------------------------------------
    -- The end
    -----------------------------------------------------------------------
    local done = CreateFrame("Frame", nil, page)
    done:SetAllPoints(page)
    page.done = done

    local mark = CreateFrame("Frame", nil, done)
    mark:SetSize(64, 64)
    local markGround = UI.Round(mark, "accent", 32)
    markGround:SetGradient("HORIZONTAL", "accent", "accent2", 64, 64)
    UI.Shadow(mark, 18, 32, 0, "accentGlow")
    local markIcon = UI.Icon(mark, "check", 30, "onAccent")
    markIcon:SetPoint("CENTER")
    local doneTitle = Centered(done, 28, "text", "semibold", COLUMN)
    local doneLede = Centered(done, 14, "textDim", nil, 560)
    doneLede:SetSpacing(4)
    page.doneTitle = doneTitle

    -- What runs now: the journey, the steps, and the aliases, on already.
    local list = CreateFrame("Frame", nil, done)
    list:SetWidth(DONE_W)
    UI.Card(list, "sunken", "divider", 9)
    local rows = {}
    for index = 1, 8 do
        local row = CreateFrame("Frame", nil, list)
        row:SetSize(DONE_W / 2, DONE_ROW)
        row:SetPoint("TOPLEFT", ((index - 1) % 2) * DONE_W / 2, -math.floor((index - 1) / 2) * DONE_ROW)
        row.mark = row:CreateTexture(nil, "ARTWORK")
        row.mark:SetTexture(UI.media.circle)
        row.mark:SetSize(20, 20)
        row.mark:SetPoint("LEFT", 16, 0)
        row.check = UI.Icon(row, "check", 12, "onAccent", "OVERLAY")
        row.check:SetPoint("CENTER", row.mark, "CENTER")
        row.note = UI.Text(row, 11, "textMuted")
        row.note:SetPoint("RIGHT", -16, 0)
        row.note:SetJustifyV("MIDDLE")
        row.name = UI.Text(row, 13, "text", "medium")
        row.name:SetPoint("LEFT", row.mark, "RIGHT", 12, 0)
        row.name:SetPoint("RIGHT", row.note, "LEFT", -8, 0)
        row.name:SetJustifyH("LEFT")
        row.name:SetJustifyV("MIDDLE")
        row.name:SetWordWrap(false)
        rows[index] = row
    end
    local middle = UI.VLine(list, "divider")
    middle:SetPoint("TOP", list, "TOP", 0, -pixel)
    middle:SetPoint("BOTTOM", list, "BOTTOM", 0, pixel)
    local rules = {}
    for index = 1, 3 do
        local rule = UI.Line(list, "divider")
        rule:SetPoint("TOPLEFT", list, "TOPLEFT", pixel, -index * DONE_ROW)
        rule:SetPoint("TOPRIGHT", list, "TOPRIGHT", -pixel, -index * DONE_ROW)
        rules[index] = rule
    end
    page.rows = rows

    page.open = BigButton(done, Finish, "primary")
    page.again = UI.Button(done, function()
        Go(page.via)
    end, "ghost")

    -- kind: "on", "off" (skipped) or "running" (on without a choice).
    -- note: a short word at the right; a long one would crowd out the name.
    local function FillRow(row, text, kind, note)
        row.name:SetText(text)
        row.note:SetText(note or "")
        UI.Tint(row.mark, kind == "on" and "accent" or (kind == "running" and "control" or "chip"))
        row.check:SetShown(kind ~= "off")
        UI.Tint(row.check, kind == "running" and "textDim" or "onAccent")
        UI.Ink(row.name, kind == "off" and "textMuted" or "text")
        row:Show()
    end

    local function RefreshDone()
        doneTitle:SetText(L.ui_welcome_done_title)
        doneLede:SetText(L.ui_welcome_done_lede)
        local index = 0
        local function Add(...)
            index = index + 1
            FillRow(rows[index], ...)
        end
        if ns.features.ownJourney and ns.features.ownJourney.enabled then
            Add(L.f_ownJourney, "on", L.ui_welcome_done_start)
        end
        for _, current in ipairs(Welcome.Steps()) do
            local on = ns.features[current.id].enabled
            Add(L["f_" .. current.id], on and "on" or "off", not on and L.ui_welcome_done_skipped or nil)
        end
        if ns:IsCategoryEnabled("aliases") then
            Add(L.area_aliases, "running", L.ui_welcome_done_running)
        end
        for rest = index + 1, #rows do
            rows[rest]:Hide()
        end
        local lines = math.ceil(index / 2)
        rules[1]:SetShown(lines > 1)
        rules[2]:SetShown(lines > 2)
        rules[3]:SetShown(lines > 3)
        list:SetHeight(lines * DONE_ROW)
        page.open:SetLabel(L.ui_welcome_done_open)
        page.again:SetLabel(L.ui_welcome_back)

        local parts = {
            { mark, 64, 0 },
            { doneTitle, doneTitle:GetStringHeight(), 18 },
            { doneLede, doneLede:GetStringHeight(), 10 },
            { list, lines * DONE_ROW, 28 },
            { page.open, BIG_H, 32 },
            { page.again, page.again:GetHeight(), 8 },
        }
        Stack(done, parts, math.max(16, math.floor((height - SumHeight(parts)) * 0.42)))
    end

    function page:Refresh()
        local view = self.view
        if type(view) == "number" and not Welcome.Steps()[view] then
            view = "done"
            self.view = view
        end
        start:SetShown(view == "start")
        step:SetShown(type(view) == "number")
        done:SetShown(view == "done")
        if view == "start" then
            RefreshStart()
        elseif view == "done" then
            RefreshDone()
        else
            RefreshStep()
        end
    end

    -- It starts again from the beginning when the page or the window closes.
    local function Reset()
        page.view, page.via, page.switched = "start", "start", {}
    end
    page:SetScript("OnHide", Reset)
    window:HookScript("OnHide", Reset)
    return page
end
