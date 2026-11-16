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
local WINDOW_SCALES = { 80, 90, 100, 110, 120, 130, 140 }

local window
local pages, pageOrder = {}, {}
local currentPage, searchText = nil, ""
local rows, navButtons = {}, {}
local renderedKey -- page or search the rows were last laid out for
local resetArmed, resetToken = false, 0
local aliasEditor -- input row of the aliases page, once it has been shown
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
        disabled = function()
            return unusable() or not ns:IsCategoryEnabled(feature.category)
        end,
        -- Shows the player's own choice even while the category is off.
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
        -- While its feature is switched off, an option stays listed as a
        -- slim row without help text; search always shows it in full.
        compact = function()
            return ns:GetOption(feature.id, "enabled") ~= true
        end,
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

---------------------------------------------------------------------------
-- Alias list. Unlike the other rows these are data, not settings: one row
-- to type a name and its alias into, then one row per stored alias.
---------------------------------------------------------------------------

local function Empty()
    return ""
end

local ALIAS_EDIT_ITEM = { kind = "aliasEdit", label = Empty, desc = Empty }
local ALIAS_EMPTY_ITEM = {
    kind = "info",
    label = function()
        return L.ui_alias_empty
    end,
    desc = function()
        return L.ui_alias_empty_desc
    end,
}

local function AddAliasItems(items)
    items[#items + 1] = ALIAS_EDIT_ITEM
    local list = ns.AliasService.List()
    if #list == 0 then
        items[#items + 1] = ALIAS_EMPTY_ITEM
        return
    end
    for _, entry in ipairs(list) do
        items[#items + 1] = {
            kind = "alias",
            entry = entry,
            label = function()
                return entry.alias
            end,
            desc = function()
                return entry.name
            end,
        }
    end
end

local function CreateAliasEditor(row)
    local editor = CreateFrame("Frame", nil, row)
    editor:SetPoint("TOPLEFT", 16, -14)
    editor:SetPoint("BOTTOMRIGHT", -16, 14)

    local fieldWidth = math.floor((ROW_WIDTH - 32 - 100 - 16) / 2)
    local name = UI.Input(editor, 48)
    name:SetPoint("LEFT")
    name:SetWidth(fieldWidth)
    local alias = UI.Input(editor, 32)
    alias:SetPoint("LEFT", name, "RIGHT", 8, 0)
    alias:SetWidth(fieldWidth)
    editor.name, editor.alias = name, alias

    local function Save()
        local character = strtrim(name.edit:GetText() or "")
        local text = strtrim(alias.edit:GetText() or "")
        if character == "" then
            name.edit:SetFocus()
        elseif text == "" then
            alias.edit:SetFocus()
        else
            ns.AliasService.Set(character, text)
            name.edit:SetText("")
            alias.edit:SetText("")
            alias.edit:ClearFocus()
        end
    end
    local function FocusAlias()
        alias.edit:SetFocus()
    end
    name.onEnter, name.onTab = FocusAlias, FocusAlias
    alias.onEnter = Save
    alias.onTab = function()
        name.edit:SetFocus()
    end

    editor.save = UI.Button(editor, Save)
    editor.save:SetPoint("RIGHT")

    function editor:Relabel()
        name.placeholder:SetText(L.ui_alias_name)
        alias.placeholder:SetText(L.ui_alias_alias)
        self.save:SetLabel(L.ui_alias_save)
    end

    -- Puts a character into the fields, ready to type or change the alias.
    function editor:Load(character, text)
        name.edit:SetText(character or "")
        alias.edit:SetText(text or "")
        alias.edit:SetFocus()
    end

    function editor:ClearFocus()
        name.edit:ClearFocus()
        alias.edit:ClearFocus()
    end
    return editor
end

local function AddPage(id, items, isCategory)
    pages[id] = { id = id, items = items, isCategory = isCategory }
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
        AddPage(category, items, true)
    end
    pages.aliases.extra = AddAliasItems

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
        GeneralItem("windowScale", "select", function()
            local list = {}
            for i, percent in ipairs(WINDOW_SCALES) do
                list[i] = { value = percent, text = percent .. "%" }
            end
            return list
        end),
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

-- The rows of a page: its settings, then whatever the page lists besides.
local function PageItems(page)
    if not page.extra then
        return page.items
    end
    local items = {}
    for i, item in ipairs(page.items) do
        items[i] = item
    end
    page.extra(items)
    return items
end

local function SearchItems(query)
    query = string.lower(query)
    local results = {}
    for _, id in ipairs(pageOrder) do
        local category = string.lower(L["cat_" .. id])
        for _, item in ipairs(PageItems(pages[id])) do
            if item.kind ~= "info" and item.kind ~= "aliasEdit" then
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
    if kind == "aliasEdit" and not row.editor then
        row.editor = CreateAliasEditor(row)
    elseif kind == "alias" and not row.remove then
        row.remove = UI.IconButton(row, "close", function()
            ns.AliasService.Set(row.item.entry.name, nil)
        end)
        row.remove:SetPoint("RIGHT", -16, 0)
    end
    if row.editor then
        row.editor:SetShown(kind == "aliasEdit")
    end
    if row.remove then
        row.remove:SetShown(kind == "alias")
    end
    if kind == "aliasEdit" then
        aliasEditor = row.editor
        aliasEditor:Relabel()
    end

    local indent = (item.child and not flat) and 40 or 16
    local compact = not flat and item.compact ~= nil and item.compact()
    local padding = compact and 9 or 13
    local controlWidth = (kind == "toggle" and 30) or (kind == "select" and 150) or (kind == "alias" and 24) or 0
    local textWidth = ROW_WIDTH - indent - 16 - controlWidth - (controlWidth > 0 and 24 or 0)

    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", indent, -padding)
    row.label:SetWidth(textWidth)
    row.label:SetText(item.label())

    local note = item.note and item.note()
    row.desc:SetShown(not compact)
    row.desc:SetWidth(textWidth)
    row.desc:SetText(compact and "" or (note or item.desc()))
    row.desc:SetTextColor(UI.Color(note and "warning" or "textMuted"))

    local height
    if kind == "aliasEdit" then
        height = 56
    elseif compact then
        height = math.max(32, padding * 2 + row.label:GetStringHeight())
    else
        height = math.max(46, padding * 2 + row.label:GetStringHeight() + 5 + row.desc:GetStringHeight())
    end
    row.height = math.floor(height + 0.5)
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
    if item.kind == "alias" then
        ns:EditAlias(item.entry.name)
    elseif item.kind == "toggle" then
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
        local kind = self.item.kind
        if not self.disabled and kind ~= "info" and kind ~= "aliasEdit" then
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
            -- A switched-off category is greyed out here as well.
            button.label:SetAlpha(ns:IsCategoryEnabled(id) and 1 or 0.45)
            if ns:IsCategoryEnabled(id) then
                local active, total = CategoryCount(id)
                button.count:SetText(active .. "/" .. total)
                button.count:SetTextColor(UI.Color(active > 0 and "accent" or "textMuted"))
            else
                button.count:SetText(L.ui_category_off)
                button.count:SetTextColor(UI.Color("textMuted"))
            end
        end
    end
    local active, total = ns:CountActiveFeatures()
    window.status:SetText("v" .. ns.version .. "\n" .. L.ui_active_count:format(active, total))
end

-- Title, subtitle and, on category pages, the master switch at the right
-- of the header.
local function RefreshHeader(animate)
    local master = window.master
    if searchText ~= "" then
        master:Hide()
        return
    end
    local page = pages[currentPage]
    local enabled = not page.isCategory or ns:IsCategoryEnabled(currentPage)
    window.title:SetText(L["cat_" .. currentPage])
    window.subtitle:SetText(L["cat_" .. currentPage .. "_desc"])
    master:SetShown(page.isCategory == true)
    if page.isCategory then
        master.caption:SetText(enabled and L.ui_category_on or L.ui_category_off)
        master:SetWidth(master.caption:GetStringWidth() + 10 + 30)
        master.toggle:Set(enabled, animate)
    end
end

-- True if "reset page" would change anything on the current page.
local function PageDiffersFromDefaults()
    local page = pages[currentPage]
    if page.isCategory and not ns:IsCategoryEnabled(currentPage) then
        return true
    end
    for _, item in ipairs(page.items) do
        if item.section and not ns:IsSectionDefault(item.section) then
            return true
        end
    end
    return false
end

local function UpdateResetButton()
    local button = window.resetButton
    local usable = searchText == "" and PageDiffersFromDefaults()
    if not usable then
        resetArmed = false
    end
    button:SetDisabled(not usable)
    button:SetLabel(resetArmed and L.ui_reset_confirm or L.ui_reset_page)
    button.label:SetTextColor(UI.Color(resetArmed and "warning" or "text"))
end

local function DisarmReset()
    if resetArmed then
        resetArmed = false
        UpdateResetButton()
    end
end

local function ApplyScale()
    if window then
        window:SetScale((tonumber(ns:GetOption("general", "windowScale")) or 100) / 100)
    end
end

-- Refreshes switches and counters without touching the layout.
local function RefreshState(animate)
    for i = 1, #rows do
        if rows[i]:IsShown() then
            RowRefresh(rows[i], animate)
        end
    end
    RefreshHeader(animate)
    UpdateResetButton()
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
        items = PageItems(pages[currentPage])
    end
    RefreshHeader(false)

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
    -- Rows that fold or unfold on the same page must not make it jump.
    local key = searching and ("search:" .. searchText) or currentPage
    if key ~= renderedKey then
        renderedKey = key
        window.scroll:ScrollToTop()
    end

    -- "Reset page" only where the page has something to reset.
    local resettable = not searching and pages[currentPage].isCategory == true
    if not searching then
        for _, item in ipairs(items) do
            if item.section then
                resettable = true
                break
            end
        end
    end
    window.resetButton:SetShown(resettable)
    UpdateResetButton()
    window.closeButton:SetLabel(L.ui_close)
    window.search.placeholder:SetText(L.ui_search)
    window.tagline:SetText(L.ui_tagline)

    RefreshSidebar()
end

local function SelectPage(id)
    DisarmReset()
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
    if pages[currentPage].isCategory then
        ns:SetOption("categories", currentPage, true)
    end
end

-- The first click asks, the second one within a few seconds resets.
local function ResetClicked()
    if resetArmed then
        resetArmed = false
        UpdateResetButton()
        ResetPage()
        return
    end
    resetArmed = true
    resetToken = resetToken + 1
    local token = resetToken
    UpdateResetButton()
    C_Timer.After(4, function()
        if token == resetToken then
            DisarmReset()
        end
    end)
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
    ApplyScale()
    UI.Fill(window, "window")
    local frameSize = UI.GradientFrame(window, "frameTop", "frameBottom", 3)
    -- The frame lies outside the window; keep it on screen as well.
    window:SetClampRectInsets(-frameSize, frameSize, frameSize, -frameSize)

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
    window.subtitle:SetWidth(ROW_WIDTH - 190)

    -- Master switch of the category, in line with the switches of the rows.
    local master = CreateFrame("Button", nil, window)
    master:SetHeight(24)
    master:SetPoint("TOPRIGHT", -(PAD + 16), -38)
    master.toggle = UI.Toggle(master)
    master.toggle:SetPoint("RIGHT")
    master.caption = UI.Text(master, 12, "textDim")
    master.caption:SetPoint("RIGHT", master.toggle, "LEFT", -10, 0)
    master.caption:SetJustifyV("MIDDLE")
    master:SetScript("OnEnter", function(self)
        self.caption:SetTextColor(UI.Color("text"))
    end)
    master:SetScript("OnLeave", function(self)
        self.caption:SetTextColor(UI.Color("textDim"))
    end)
    master:SetScript("OnClick", function()
        ns:SetOption("categories", currentPage, not ns:IsCategoryEnabled(currentPage))
    end)
    window.master = master

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

    window.resetButton = UI.Button(footer, ResetClicked)
    window.resetButton:SetPoint("LEFT", PAD, 0)

    window.closeButton = UI.Button(footer, function()
        window:Hide()
    end)
    window.closeButton:SetPoint("RIGHT", -PAD, 0)

    window:SetScript("OnShow", function(self)
        ns:Fire("OPTIONS_SHOWN") -- lets switches that mirror game options catch up
        Render()
        self:SetAlpha(0)
        UI.Tween(self, 0.12, function(progress)
            self:SetAlpha(progress)
        end)
    end)
    window:SetScript("OnHide", function()
        UI.CloseMenu()
        DisarmReset()
        renderedKey = nil
        window.search.edit:ClearFocus()
        if aliasEditor then
            aliasEditor:ClearFocus()
        end
    end)
end

function ns:ToggleOptions()
    if not window then
        Build()
    end
    window:SetShown(not window:IsShown())
end

-- Opens the aliases page with the character in the input row, so that only
-- the alias is left to type. Used by the context menu and the list itself.
function ns:EditAlias(name)
    if not window then
        Build()
    end
    if not window:IsShown() then
        window:Show()
    end
    if currentPage ~= "aliases" or searchText ~= "" then
        SelectPage("aliases")
    end
    window.scroll:ScrollToTop()
    if aliasEditor then
        aliasEditor:Load(name, ns.AliasService.Get(name))
    end
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

ns:On("OPTION_CHANGED", function(section, key)
    if section == "general" and key == "windowScale" then
        ApplyScale()
    end
    -- Switching a feature folds or unfolds its options, which moves rows.
    local feature = ns.features[section]
    if key == "enabled" and feature and #feature.options > 0 then
        RequestRefresh("layout")
    else
        RequestRefresh("state")
    end
end)
ns:On("FEATURE_STATE", function()
    RequestRefresh("state")
end)
ns:On("LOCALE_CHANGED", function()
    RequestRefresh("layout")
end)
ns:On("ALIASES_CHANGED", function()
    RequestRefresh("layout")
end)
ns:On("PROFILE_CHANGED", function()
    ApplyScale()
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
