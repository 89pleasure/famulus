-- The settings window. Built on first open, never before: a player who
-- does not open it pays nothing for it.
--
-- Layout: sidebar (wordmark, search, navigation) | header, one panel of
-- rows, footer. Every row is described by an "item" (label, help text,
-- getter, setter); pages are just lists of items, so search can show rows
-- from all pages at once.

local _, ns = ...
local L = ns.L
local UI = ns.UI

local WIDTH, HEIGHT = 860, 560
local SIDEBAR, HEADER, FOOTER, PAD = 220, 92, 52, 28
local ROW_WIDTH = WIDTH - SIDEBAR - PAD * 2
local NAV_ROW = 34

local LANGUAGE_NAMES = { enUS = "English", deDE = "Deutsch" }
local MODIFIERS = { "SHIFT", "CTRL", "ALT", "NONE" }

local window
local pages, pageOrder = {}, {}
local currentPage, searchText = nil, ""
local rows, navButtons = {}, {}
local Render -- forward declaration

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------

local function FeatureItem(feature)
    local function unusable()
        return feature.failed or not feature:IsAvailable()
    end
    return {
        kind = "toggle",
        section = feature.id,
        label = function()
            return L["f_" .. feature.id]
        end,
        desc = function()
            return L["f_" .. feature.id .. "_desc"]
        end,
        note = function()
            if not feature:IsAvailable() then
                return L.ui_unavailable
            elseif feature.failed then
                return L.ui_failed
            end
        end,
        disabled = unusable,
        get = function()
            return not unusable() and ns:GetOption(feature.id, "enabled")
        end,
        set = function(value)
            ns:SetOption(feature.id, "enabled", value)
        end,
    }
end

local function OptionItem(feature, option)
    local prefix = "o_" .. feature.id .. "_" .. option.key
    local item = {
        kind = option.type,
        child = true,
        section = feature.id,
        label = function()
            return L[prefix]
        end,
        desc = function()
            return L[prefix .. "_desc"]
        end,
        disabled = function()
            return not feature.enabled
        end,
        get = function()
            return ns:GetOption(feature.id, option.key)
        end,
        set = function(value)
            ns:SetOption(feature.id, option.key, value)
        end,
    }
    if option.type == "select" then
        item.values = function()
            local list = {}
            for i, value in ipairs(option.values) do
                list[i] = { value = value, text = L[prefix .. "_" .. value] }
            end
            return list
        end
    end
    return item
end

local function GeneralItem(key, kind, values)
    return {
        kind = kind,
        section = "general",
        label = function()
            return L["g_" .. key]
        end,
        desc = function()
            return L["g_" .. key .. "_desc"]
        end,
        get = function()
            return ns:GetOption("general", key)
        end,
        set = function(value)
            ns:SetOption("general", key, value)
        end,
        values = values,
    }
end

local function InfoItem(key, value)
    return {
        kind = "info",
        label = function()
            return L["about_" .. key]
        end,
        desc = value,
    }
end

local function AddPage(id, items)
    pages[id] = { id = id, items = items }
    pageOrder[#pageOrder + 1] = id
end

local function BuildPages()
    for _, category in ipairs(ns.categories) do
        local items = {}
        for _, feature in ipairs(ns.featureList) do
            if feature.category == category then
                items[#items + 1] = FeatureItem(feature)
                for _, option in ipairs(feature.options) do
                    if ns:IsOptionAvailable(option) then
                        items[#items + 1] = OptionItem(feature, option)
                    end
                end
            end
        end
        AddPage(category, items)
    end

    local profileItem = GeneralItem("charProfile", "toggle")
    profileItem.section = nil -- not part of a profile, so "reset page" leaves it alone
    profileItem.get = function()
        return ns:UsesCharacterProfile()
    end
    profileItem.set = function(value)
        ns:SetUseCharacterProfile(value)
    end

    AddPage("general", {
        GeneralItem("language", "select", function()
            local list = { { value = "auto", text = L.lang_auto } }
            for _, code in ipairs(ns:GetLocaleCodes()) do
                list[#list + 1] = { value = code, text = LANGUAGE_NAMES[code] or code }
            end
            return list
        end),
        GeneralItem("pauseModifier", "select", function()
            local list = {}
            for i, modifier in ipairs(MODIFIERS) do
                list[i] = { value = modifier, text = L["mod_" .. modifier] }
            end
            return list
        end),
        GeneralItem("chatOutput", "toggle"),
        GeneralItem("minimapButton", "toggle"),
        profileItem,
    })

    AddPage("about", {
        InfoItem("version", function()
            return ns.version
        end),
        InfoItem("status", function()
            local active, total = ns:CountActiveFeatures()
            return L.about_status_value:format(active, total, ns:CountRegisteredEvents())
        end),
        InfoItem("commands", function()
            return L.about_commands_value
        end),
        InfoItem("idea", function()
            return L.about_idea_value
        end),
    })
end

local function SearchItems(query)
    query = string.lower(query)
    local results = {}
    for _, id in ipairs(pageOrder) do
        local category = string.lower(L["cat_" .. id])
        for _, item in ipairs(pages[id].items) do
            if item.kind ~= "info" then
                local haystack = string.lower(item.label() .. " " .. item.desc()) .. " " .. category
                if string.find(haystack, query, 1, true) then
                    results[#results + 1] = item
                end
            end
        end
    end
    return results
end

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------

local function ValueText(item)
    local current = item.get()
    for _, entry in ipairs(item.values()) do
        if entry.value == current then
            return entry.text
        end
    end
    return tostring(current)
end

local function RowRefresh(row, animate)
    local item = row.item
    local disabled = item.disabled ~= nil and item.disabled() or false
    row.disabled = disabled
    local alpha = disabled and 0.45 or 1
    row.label:SetAlpha(alpha)
    row.desc:SetAlpha(alpha)
    if item.kind == "toggle" then
        row.toggle:Set(item.get(), animate)
        row.toggle:SetAlpha(alpha)
    elseif item.kind == "select" then
        row.dropdown.text:SetText(ValueText(item))
        row.dropdown:SetAlpha(alpha)
    elseif item.kind == "info" then
        row.desc:SetText(item.desc())
    end
end

local function RowSetItem(row, item, index, flat)
    row.item = item
    local kind = item.kind

    if kind == "toggle" and not row.toggle then
        row.toggle = UI.Toggle(row)
        row.toggle:SetPoint("RIGHT", -16, 0)
    elseif kind == "select" and not row.dropdown then
        row.dropdown = UI.Dropdown(row)
        row.dropdown:SetPoint("RIGHT", -16, 0)
    end
    if row.toggle then
        row.toggle:SetShown(kind == "toggle")
    end
    if row.dropdown then
        row.dropdown:SetShown(kind == "select")
    end

    local indent = (item.child and not flat) and 40 or 16
    local controlWidth = (kind == "toggle" and 30) or (kind == "select" and 150) or 0
    local textWidth = ROW_WIDTH - indent - 16 - controlWidth - (controlWidth > 0 and 24 or 0)

    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", indent, -13)
    row.label:SetWidth(textWidth)
    row.label:SetText(item.label())

    local note = item.note and item.note()
    row.desc:SetWidth(textWidth)
    row.desc:SetText(note or item.desc())
    row.desc:SetTextColor(UI.Color(note and "warning" or "textMuted"))

    local height = 13 + row.label:GetStringHeight() + 5 + row.desc:GetStringHeight() + 13
    row.height = math.max(46, math.floor(height + 0.5))
    row:SetHeight(row.height)
    row.divider:SetShown(index > 1)
    row.hover:Hide()
    RowRefresh(row, false)
end

local function RowClicked(row)
    local item = row.item
    if row.disabled or item.kind == "info" then
        return
    end
    if item.kind == "toggle" then
        item.set(not item.get())
    elseif item.kind == "select" then
        UI.OpenMenu(row.dropdown, item.values(), item.get(), item.set)
    end
end

local function CreateRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetWidth(ROW_WIDTH)

    row.hover = UI.Fill(row, "hover")
    row.hover:Hide()

    row.divider = UI.Line(row)
    row.divider:SetPoint("TOPLEFT", 16, 0)
    row.divider:SetPoint("TOPRIGHT", -16, 0)

    row.label = UI.Text(row, 13, "text")
    row.desc = UI.Text(row, 12, "textMuted")
    row.desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -5)
    row.desc:SetSpacing(2)

    row:SetScript("OnEnter", function(self)
        if not self.disabled and self.item.kind ~= "info" then
            self.hover:Show()
        end
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:Hide()
    end)
    row:SetScript("OnClick", RowClicked)
    return row
end

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------

local function CategoryCount(category)
    local active, total = 0, 0
    for _, feature in ipairs(ns.featureList) do
        if feature.category == category then
            total = total + 1
            if feature.enabled then
                active = active + 1
            end
        end
    end
    return active, total
end

local function RefreshSidebar()
    local searching = searchText ~= ""
    for id, button in pairs(navButtons) do
        local selected = not searching and id == currentPage
        button.selected = selected
        button.bar:SetShown(selected)
        button.fill:SetShown(selected)
        button.label:SetText(L["cat_" .. id])
        button.label:SetTextColor(UI.Color(selected and "text" or "textDim"))
        if button.count then
            local active, total = CategoryCount(id)
            button.count:SetText(active .. "/" .. total)
            button.count:SetTextColor(UI.Color(active > 0 and "accent" or "textMuted"))
        end
    end
    local active, total = ns:CountActiveFeatures()
    window.status:SetText("v" .. ns.version .. "\n" .. L.ui_active_count:format(active, total))
end

-- Refreshes switches and counters without touching the layout.
local function RefreshState(animate)
    for i = 1, #rows do
        if rows[i]:IsShown() then
            RowRefresh(rows[i], animate)
        end
    end
    RefreshSidebar()
end

function Render()
    UI.CloseMenu()
    local searching = searchText ~= ""
    local items

    if searching then
        items = SearchItems(searchText)
        window.title:SetText(L.ui_search_title)
        if #items > 0 then
            window.subtitle:SetText(L.ui_search_results:format(#items))
        else
            window.subtitle:SetText(L.ui_search_none:format(searchText))
        end
    else
        items = pages[currentPage].items
        window.title:SetText(L["cat_" .. currentPage])
        window.subtitle:SetText(L["cat_" .. currentPage .. "_desc"])
    end

    local offset = 0
    for index, item in ipairs(items) do
        local row = rows[index]
        if not row then
            row = CreateRow(window.panel)
            rows[index] = row
        end
        RowSetItem(row, item, index, searching)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", window.panel, "TOPLEFT", 0, -offset)
        row:Show()
        offset = offset + row.height
    end
    for index = #items + 1, #rows do
        rows[index]:Hide()
    end

    window.panel:SetHeight(math.max(1, offset))
    window.panel:SetShown(#items > 0)
    window.scroll:SetContentHeight(offset + 12)
    window.scroll:ScrollToTop()

    -- "Reset page" only where the page has something to reset.
    local resettable = false
    if not searching then
        for _, item in ipairs(items) do
            if item.section then
                resettable = true
                break
            end
        end
    end
    window.resetButton:SetShown(resettable)
    window.resetButton:SetLabel(L.ui_reset_page)
    window.closeButton:SetLabel(L.ui_close)
    window.search.placeholder:SetText(L.ui_search)
    window.tagline:SetText(L.ui_tagline)

    RefreshSidebar()
end

local function SelectPage(id)
    currentPage = id
    if searchText ~= "" then
        window.search.edit:SetText("") -- triggers Render through the search callback
        window.search.edit:ClearFocus()
    else
        Render()
    end
end

local function ResetPage()
    local sections, seen = {}, {}
    for _, item in ipairs(pages[currentPage].items) do
        if item.section and not seen[item.section] then
            seen[item.section] = true
            sections[#sections + 1] = item.section
        end
    end
    ns:ResetSections(sections)
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------

local function CreateNavButton(parent, id, index, withCount)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(NAV_ROW)
    button:SetPoint("TOPLEFT", 8, -120 - (index - 1) * NAV_ROW)
    button:SetPoint("TOPRIGHT", -8, -120 - (index - 1) * NAV_ROW)

    button.fill = UI.Fill(button, "selected")
    button.fill:Hide()
    local hover = UI.Fill(button, "hover", "BORDER")
    hover:Hide()

    button.bar = button:CreateTexture(nil, "ARTWORK")
    button.bar:SetColorTexture(UI.Color("accent"))
    button.bar:SetPoint("TOPLEFT", 0, -7)
    button.bar:SetPoint("BOTTOMLEFT", 0, 7)
    button.bar:SetWidth(2)
    button.bar:Hide()

    button.label = UI.Text(button, 13, "textDim")
    button.label:SetPoint("LEFT", 14, 0)

    if withCount then
        button.count = UI.Text(button, 11, "textMuted")
        button.count:SetPoint("RIGHT", -12, 0)
    end

    button:SetScript("OnEnter", function(self)
        if not self.selected then
            hover:Show()
        end
    end)
    button:SetScript("OnLeave", function()
        hover:Hide()
    end)
    button:SetScript("OnClick", function()
        hover:Hide()
        SelectPage(id)
    end)
    navButtons[id] = button
    return button
end

local function SavePosition()
    local point, _, relativePoint, x, y = window:GetPoint(1)
    ns.global.window = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function Build()
    BuildPages()
    currentPage = pageOrder[1]

    window = CreateFrame("Frame", "SchnitzelOptionsFrame", UIParent)
    window:SetSize(WIDTH, HEIGHT)
    window:SetFrameStrata("HIGH")
    window:SetToplevel(true)
    window:SetClampedToScreen(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:RegisterForDrag("LeftButton")
    window:Hide()
    UI.Fill(window, "window")
    UI.Border(window)

    local saved = ns.global.window
    if saved and saved.point then
        window:SetPoint(saved.point, UIParent, saved.relativePoint or saved.point, saved.x or 0, saved.y or 0)
    else
        window:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    end
    window:SetScript("OnDragStart", window.StartMoving)
    window:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        SavePosition()
    end)
    table.insert(UISpecialFrames, "SchnitzelOptionsFrame") -- Escape closes it

    -- Sidebar
    local sidebar = CreateFrame("Frame", nil, window)
    sidebar:SetPoint("TOPLEFT")
    sidebar:SetPoint("BOTTOMLEFT")
    sidebar:SetWidth(SIDEBAR)
    UI.Fill(sidebar, "sidebar")

    local logo = UI.Icon(sidebar, "logo", 30)
    logo:SetPoint("TOPLEFT", 20, -22)

    local wordmark = UI.Text(sidebar, 17, "text")
    wordmark:SetPoint("TOPLEFT", logo, "TOPRIGHT", 10, 0)
    wordmark:SetText("Schnitzel")

    window.tagline = UI.Text(sidebar, 11, "textMuted")
    window.tagline:SetPoint("TOPLEFT", wordmark, "BOTTOMLEFT", 0, -3)

    window.search = UI.SearchBox(sidebar, function(text)
        text = strtrim(text)
        if text ~= searchText then
            searchText = text
            Render()
        end
    end)
    window.search:SetPoint("TOPLEFT", 16, -72)
    window.search:SetPoint("TOPRIGHT", -16, -72)

    local index = 0
    for _, id in ipairs(pageOrder) do
        index = index + 1
        local isCategory = id ~= "general" and id ~= "about"
        if id == "general" then
            -- Small gap with a hairline between features and addon pages.
            local line = UI.Line(sidebar)
            line:SetPoint("TOPLEFT", 20, -120 - (index - 1) * NAV_ROW - 8)
            line:SetPoint("TOPRIGHT", -20, -120 - (index - 1) * NAV_ROW - 8)
            index = index + 0.5
        end
        CreateNavButton(sidebar, id, index, isCategory)
    end

    window.status = UI.Text(sidebar, 11, "textMuted")
    window.status:SetPoint("BOTTOMLEFT", 20, 16)
    window.status:SetJustifyV("BOTTOM")
    window.status:SetSpacing(3)

    -- Header
    window.title = UI.Text(window, 22, "text")
    window.title:SetPoint("TOPLEFT", SIDEBAR + PAD, -26)

    window.subtitle = UI.Text(window, 12, "textMuted")
    window.subtitle:SetPoint("TOPLEFT", window.title, "BOTTOMLEFT", 0, -8)
    window.subtitle:SetWidth(ROW_WIDTH - 40)

    local close = CreateFrame("Button", nil, window)
    close:SetSize(28, 28)
    close:SetPoint("TOPRIGHT", -10, -10)
    local closeHover = UI.Fill(close, "hover")
    closeHover:Hide()
    local closeIcon = UI.Icon(close, "close", 16, "textMuted")
    closeIcon:SetPoint("CENTER")
    close:SetScript("OnEnter", function()
        closeHover:Show()
        closeIcon:SetVertexColor(UI.Color("text"))
    end)
    close:SetScript("OnLeave", function()
        closeHover:Hide()
        closeIcon:SetVertexColor(UI.Color("textMuted"))
    end)
    close:SetScript("OnClick", function()
        window:Hide()
    end)

    -- Body
    window.scroll = UI.Scroll(window)
    window.scroll:SetPoint("TOPLEFT", SIDEBAR + PAD, -HEADER)
    window.scroll:SetPoint("BOTTOMRIGHT", -PAD, FOOTER + 12)
    window.scroll.content:SetWidth(ROW_WIDTH)

    window.panel = CreateFrame("Frame", nil, window.scroll.content)
    window.panel:SetPoint("TOPLEFT")
    window.panel:SetWidth(ROW_WIDTH)
    UI.Fill(window.panel, "panel")
    UI.Border(window.panel)

    -- Footer
    local footer = CreateFrame("Frame", nil, window)
    footer:SetPoint("BOTTOMLEFT", SIDEBAR, 0)
    footer:SetPoint("BOTTOMRIGHT")
    footer:SetHeight(FOOTER)
    UI.Fill(footer, "footer")
    local footerLine = UI.Line(footer, "border")
    footerLine:SetPoint("TOPLEFT")
    footerLine:SetPoint("TOPRIGHT")

    window.resetButton = UI.Button(footer, ResetPage)
    window.resetButton:SetPoint("LEFT", PAD, 0)

    window.closeButton = UI.Button(footer, function()
        window:Hide()
    end)
    window.closeButton:SetPoint("RIGHT", -PAD, 0)

    window:SetScript("OnShow", function(self)
        Render()
        self:SetAlpha(0)
        UI.Tween(self, 0.12, function(progress)
            self:SetAlpha(progress)
        end)
    end)
    window:SetScript("OnHide", function()
        UI.CloseMenu()
        window.search.edit:ClearFocus()
    end)
end

function ns:ToggleOptions()
    if not window then
        Build()
    end
    window:SetShown(not window:IsShown())
end

---------------------------------------------------------------------------
-- Keeping the open window in sync. Several changes in one frame (for
-- example "reset page") are folded into a single refresh.
---------------------------------------------------------------------------

local pendingRefresh -- nil, "state" or "layout"

local function FlushRefresh()
    local mode = pendingRefresh
    pendingRefresh = nil
    if not window or not window:IsShown() then
        return -- OnShow renders from scratch anyway
    end
    if mode == "layout" then
        Render()
    else
        RefreshState(true)
    end
end

local function RequestRefresh(mode)
    if not window or not window:IsShown() then
        return
    end
    if not pendingRefresh then
        C_Timer.After(0, FlushRefresh)
    end
    if mode == "layout" or not pendingRefresh then
        pendingRefresh = mode
    end
end

ns:On("OPTION_CHANGED", function()
    RequestRefresh("state")
end)
ns:On("FEATURE_STATE", function()
    RequestRefresh("state")
end)
ns:On("LOCALE_CHANGED", function()
    RequestRefresh("layout")
end)
ns:On("PROFILE_CHANGED", function()
    RequestRefresh("layout")
end)

---------------------------------------------------------------------------
-- Entry in the game's own options (Options > AddOns): one button that
-- opens the real window.
---------------------------------------------------------------------------

ns:On("LOGIN", function()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then
        return
    end
    local panel = CreateFrame("Frame")
    panel:Hide()
    -- Callbacks the game's options window may call on any category panel.
    panel.OnCommit = function() end
    panel.OnDefault = function() end
    panel.OnRefresh = function() end

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Schnitzel")

    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(240, 26)
    button:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    button:SetScript("OnClick", function()
        if SettingsPanel and SettingsPanel.Close and not InCombatLockdown() then
            SettingsPanel:Close()
        end
        if not (window and window:IsShown()) then
            ns:ToggleOptions()
        end
    end)
    panel:SetScript("OnShow", function()
        button:SetText(L.ui_open_settings)
    end)

    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "Schnitzel")
    if ok and category then
        pcall(Settings.RegisterAddOnCategory, category)
    end
end)
