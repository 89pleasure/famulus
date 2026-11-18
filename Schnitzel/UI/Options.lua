-- The settings window. Built on first open, never before: a player who
-- does not open it pays nothing for it.
--
-- Layout: sidebar (logo, search, one entry per main feature, then the
-- addon's own pages) | header with title and window buttons, tabs, a line
-- with the tab's description and its actions, then cards of rows.
--
-- A page has tabs; a tab has blocks; a block is one card of rows. Every row
-- is described by an "item" (label, help text, getter, setter). Main
-- features ("areas", see Core/Features.lua) get their page from a layout:
-- by default one tab per category, or a layout of their own (aliases).

local _, ns = ...
local L = ns.L
local UI = ns.UI

local WIDTH, HEIGHT = 880, 590
local SIDEBAR, PAD, RADIUS = 224, 28, 12
local CONTENT_W = WIDTH - SIDEBAR - PAD * 2
local HEADER = 84
local NAV_ROW, NAV_TOP = 34, 142
local BLOCK_GAP, BLOCK_TITLE, CARD_GAP = 22, 24, 8

local LANGUAGE_NAMES = { enUS = "English", deDE = "Deutsch" }
local MODIFIERS = { "SHIFT", "CTRL", "ALT", "NONE" }
local WINDOW_SCALES = { 80, 90, 100, 110, 120, 130, 140 }
local AREA_ICONS = { qol = "sparkle", aliases = "tag" }

local window
local pages, pageOrder = {}, {}
local currentPage, selectedTabs, searchText = nil, {}, ""
local rows, cards, navButtons = {}, {}, {}
local renderedKey -- page, tab or search the rows were last laid out for
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

-- An option of the addon itself. Unlike feature rows, it resets on its own
-- (key) instead of with its whole section.
local function GeneralItem(key, kind, values)
    return {
        kind = kind,
        section = "general",
        key = key,
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

local function FeatureItems(category)
    local items = {}
    for _, feature in ipairs(ns.featureList) do
        if feature.category == category and feature:IsShown() then
            local item = FeatureItem(feature)
            -- Whether the feature really runs; its card shows that.
            item.active = function()
                return feature.enabled == true
            end
            items[#items + 1] = item
            for _, option in ipairs(feature.options) do
                if ns:IsOptionAvailable(option) then
                    items[#items + 1] = OptionItem(feature, option)
                end
            end
        end
    end
    return items
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

local function AliasItems()
    local items = {}
    for _, entry in ipairs(ns.AliasService.List()) do
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
    return items
end

local function CreateAliasEditor(row)
    local editor = CreateFrame("Frame", nil, row)
    editor:SetPoint("TOPLEFT", 16, -16)
    editor:SetPoint("BOTTOMRIGHT", -16, 16)

    local fieldWidth = math.floor((CONTENT_W - 32 - 96 - 20) / 2)
    local name = UI.Input(editor, 48)
    name:SetPoint("LEFT")
    name:SetWidth(fieldWidth)
    local alias = UI.Input(editor, 32)
    alias:SetPoint("LEFT", name, "RIGHT", 10, 0)
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

    editor.save = UI.Button(editor, Save, "primary")
    editor.save:SetHeight(32)
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

-- First letter of an alias for its avatar; UTF-8 aware, upper case for
-- plain letters.
local function Initial(text)
    local first = string.match(text or "", "^[%z\1-\127\194-\244][\128-\191]*") or "?"
    return string.upper(first)
end

---------------------------------------------------------------------------
-- Pages and tabs
---------------------------------------------------------------------------

-- One card per feature: the feature's row and, below it, its options.
local function FeatureBlocks(items)
    local blocks = {}
    for _, item in ipairs(items) do
        local block = blocks[#blocks]
        if item.child and block then
            block.items[#block.items + 1] = item
        else
            blocks[#blocks + 1] = { items = { item }, tight = true, active = item.active }
        end
    end
    return blocks
end

local function CategoryTab(category)
    local items = FeatureItems(category)
    local blocks = FeatureBlocks(items)
    return {
        id = category,
        category = category,
        label = function()
            return L["cat_" .. category]
        end,
        desc = function()
            return L["cat_" .. category .. "_desc"]
        end,
        settings = items,
        blocks = function()
            return blocks
        end,
    }
end

-- Layouts of main features. One returns the tabs of the area's page.
local layouts = {}

function layouts.default(area)
    local tabs = {}
    for _, category in ipairs(area.categories) do
        tabs[#tabs + 1] = CategoryTab(category)
    end
    return tabs
end

-- Aliases: the list is the heart of the page; where aliases show up is the
-- second tab. The category's master switch is the same on both.
function layouts.aliases()
    local display = CategoryTab("aliases")
    display.id = "display"
    display.label = function()
        return L.ui_tab_display
    end
    display.desc = function()
        return L.ui_tab_display_desc
    end

    local names = {
        id = "names",
        category = "aliases",
        label = function()
            return L.ui_tab_names
        end,
        desc = function()
            return L.ui_tab_names_desc
        end,
        settings = {},
        blocks = function()
            local list = AliasItems()
            return {
                { title = L.ui_alias_new, items = { ALIAS_EDIT_ITEM } },
                {
                    title = L.ui_alias_list,
                    note = tostring(#list),
                    items = #list > 0 and list or { ALIAS_EMPTY_ITEM },
                },
            }
        end,
    }
    return { names, display }
end

local function SimpleTab(id, items)
    return {
        id = id,
        label = function()
            return L["ui_tab_" .. id]
        end,
        desc = function()
            return L["ui_tab_" .. id .. "_desc"]
        end,
        settings = items,
        blocks = function()
            return { { items = items } }
        end,
    }
end

local function AddPage(page)
    pages[page.id] = page
    pageOrder[#pageOrder + 1] = page.id
end

local function SettingsTabs()
    local profileItem = GeneralItem("charProfile", "toggle")
    profileItem.section, profileItem.key = nil, nil -- not part of a profile; reset leaves it alone
    profileItem.get = function()
        return ns:UsesCharacterProfile()
    end
    profileItem.set = function(value)
        ns:SetUseCharacterProfile(value)
    end

    local general = SimpleTab("general", {
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

    local appearance = SimpleTab("appearance", {
        GeneralItem("theme", "segment", function()
            local list = {}
            for i, theme in ipairs(UI.themes) do
                list[i] = { value = theme, text = L["theme_" .. theme] }
            end
            return list
        end),
        GeneralItem("accent", "swatch", function()
            return UI.accents
        end),
        GeneralItem("windowScale", "select", function()
            local list = {}
            for i, percent in ipairs(WINDOW_SCALES) do
                list[i] = { value = percent, text = percent .. "%" }
            end
            return list
        end),
    })
    return { general, appearance }
end

local function BuildPages()
    for _, area in ipairs(ns.areas) do
        local layout = layouts[area.id] or layouts.default
        AddPage({
            id = area.id,
            area = area,
            icon = AREA_ICONS[area.id] or "sparkle",
            title = function()
                return L["area_" .. area.id]
            end,
            desc = function()
                return L["area_" .. area.id .. "_desc"]
            end,
            tabs = layout(area),
        })
    end

    AddPage({
        id = "general",
        icon = "gear",
        bottom = true,
        title = function()
            return L.cat_general
        end,
        desc = function()
            return L.cat_general_desc
        end,
        tabs = SettingsTabs(),
    })

    local about = {
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
    }
    AddPage({
        id = "about",
        icon = "info",
        bottom = true,
        title = function()
            return L.cat_about
        end,
        desc = function()
            return L.cat_about_desc
        end,
        tabs = {
            {
                id = "about",
                settings = {},
                blocks = function()
                    return { { items = about } }
                end,
            },
        },
    })
end

local function CurrentTab(page)
    page = page or pages[currentPage]
    local wanted = selectedTabs[page.id]
    for _, tab in ipairs(page.tabs) do
        if tab.id == wanted then
            return tab
        end
    end
    return page.tabs[1]
end

-- Search covers every tab of every page; hits are grouped by where they
-- live, one card per tab.
local function SearchBlocks(query)
    query = string.lower(query)
    local blocks, total = {}, 0
    for _, id in ipairs(pageOrder) do
        local page = pages[id]
        local pageTitle = page.title()
        for _, tab in ipairs(page.tabs) do
            local where = pageTitle
            if #page.tabs > 1 then
                where = pageTitle .. "  ·  " .. tab.label()
            end
            local context = string.lower(where)
            local hits = {}
            for _, block in ipairs(tab.blocks()) do
                for _, item in ipairs(block.items) do
                    if item.kind ~= "info" and item.kind ~= "aliasEdit" then
                        local haystack = string.lower(item.label() .. " " .. item.desc()) .. " " .. context
                        if string.find(haystack, query, 1, true) then
                            hits[#hits + 1] = item
                        end
                    end
                end
            end
            if #hits > 0 then
                blocks[#blocks + 1] = { title = where, items = hits }
                total = total + #hits
            end
        end
    end
    return blocks, total
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
    local kind = item.kind
    if kind == "toggle" then
        row.toggle:Set(item.get(), animate)
        row.toggle:SetAlpha(alpha)
    elseif kind == "select" then
        row.dropdown.text:SetText(ValueText(item))
        row.dropdown:SetAlpha(alpha)
    elseif kind == "segment" then
        row.segment:SetValues(item.values(), item.get())
    elseif kind == "swatch" then
        row.swatches:SetValues(item.values(), item.get())
    elseif kind == "info" then
        row.desc:SetText(item.desc())
    end
end

local function EnsureControls(row, kind)
    if kind == "toggle" and not row.toggle then
        row.toggle = UI.Toggle(row)
        row.toggle:SetPoint("RIGHT", -18, 0)
    elseif kind == "select" and not row.dropdown then
        row.dropdown = UI.Dropdown(row)
        row.dropdown:SetPoint("RIGHT", -18, 0)
    elseif kind == "segment" and not row.segment then
        row.segment = UI.Segmented(row, function(value)
            row.item.set(value)
        end)
        row.segment:SetPoint("RIGHT", -18, 0)
    elseif kind == "swatch" and not row.swatches then
        row.swatches = UI.Swatches(row, function(value)
            row.item.set(value)
        end)
        row.swatches:SetPoint("RIGHT", -14, 0)
    elseif kind == "aliasEdit" and not row.editor then
        row.editor = CreateAliasEditor(row)
    elseif kind == "alias" and not row.remove then
        row.remove = UI.IconButton(row, "close", function()
            ns.AliasService.Set(row.item.entry.name, nil)
        end)
        row.remove:SetPoint("RIGHT", -14, 0)
        row.avatar = row:CreateTexture(nil, "ARTWORK")
        row.avatar:SetTexture(UI.media.circle)
        row.avatar:SetSize(30, 30)
        row.avatar:SetPoint("LEFT", 16, 0)
        UI.Tint(row.avatar, "accentSoft")
        row.initial = UI.Text(row, 13, "accent", "semibold")
        row.initial:SetPoint("CENTER", row.avatar, "CENTER", 0, 0)
        row.initial:SetJustifyH("CENTER")
        row.initial:SetJustifyV("MIDDLE")
    end
    local controls = {
        toggle = row.toggle,
        select = row.dropdown,
        segment = row.segment,
        swatch = row.swatches,
        aliasEdit = row.editor,
        alias = row.remove,
    }
    for controlKind, control in pairs(controls) do
        if control then
            control:SetShown(controlKind == kind)
        end
    end
    if row.avatar then
        row.avatar:SetShown(kind == "alias")
        row.initial:SetShown(kind == "alias")
    end
end

local function ControlWidth(row, kind)
    if kind == "toggle" then
        return 34
    elseif kind == "select" then
        return row.dropdown:GetWidth()
    elseif kind == "segment" then
        return row.segment:GetWidth()
    elseif kind == "swatch" then
        return row.swatches:GetWidth()
    elseif kind == "alias" then
        return 26
    end
    return 0
end

-- last: the row is the last one of its card.
local function RowSetItem(row, item, index, flat, last)
    row.item = item
    local kind = item.kind
    EnsureControls(row, kind)
    if kind == "aliasEdit" then
        aliasEditor = row.editor
        aliasEditor:Relabel()
    elseif kind == "segment" or kind == "swatch" then
        RowRefresh(row, false) -- sizes the control before the text is laid out
    end

    local child = item.child and not flat
    local indent = (child and 44) or (kind == "alias" and 58) or 18
    local compact = not flat and item.compact ~= nil and item.compact()
    local padding = compact and 10 or 15
    local controlWidth = ControlWidth(row, kind)
    local textWidth = CONTENT_W - indent - 18 - controlWidth - (controlWidth > 0 and 24 or 0)

    -- An option lies a little deeper in the card than its feature, marked
    -- with a dot; the line above it runs from edge to edge.
    local pixel = UI.Pixel(row)
    row.sunken:SetShown(child and not last)
    row.sunkenLast:SetShown(child and last)
    row.bullet:SetShown(child)
    row.bullet:ClearAllPoints()
    row.bullet:SetPoint("TOPLEFT", 25, -(padding + 5))
    local edge = child and pixel or 18
    row.divider:ClearAllPoints()
    row.divider:SetPoint("TOPLEFT", edge, 0)
    row.divider:SetPoint("TOPRIGHT", -edge, 0)
    if kind == "alias" then
        row.initial:SetText(Initial(item.label()))
    end

    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", indent, -padding)
    row.label:SetWidth(textWidth)
    row.label:SetText(item.label())

    local note = item.note and item.note()
    row.desc:SetShown(not compact)
    row.desc:SetWidth(textWidth)
    row.desc:SetText(compact and "" or (note or item.desc()))
    UI.Ink(row.desc, note and "warning" or "textMuted")

    local height
    if kind == "aliasEdit" then
        height = 64
    elseif compact then
        height = math.max(36, padding * 2 + row.label:GetStringHeight())
    else
        height = math.max(54, padding * 2 + row.label:GetStringHeight() + 4 + row.desc:GetStringHeight())
    end
    row.height = math.floor(height + 0.5)
    row:SetHeight(row.height)
    row.divider:SetShown(index > 1)
    row.hover:Hide()
    RowRefresh(row, false)
end

local function RowClicked(row)
    local item = row.item
    local kind = item.kind
    if row.disabled or kind == "info" or kind == "segment" or kind == "swatch" then
        return
    end
    if kind == "alias" then
        ns:EditAlias(item.entry.name)
    elseif kind == "toggle" then
        item.set(not item.get())
    elseif kind == "select" then
        UI.OpenMenu(row.dropdown, item.values(), item.get(), item.set)
    end
end

local HOVERLESS = { info = true, aliasEdit = true, segment = true, swatch = true }

local function CreateRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetWidth(CONTENT_W)
    row:SetFrameLevel(parent:GetFrameLevel() + 3)

    row.hover = UI.Round(row, "hover", 8, { inset = 4 })
    row.hover:Hide()

    row.divider = UI.Line(row)

    -- Ground of an option row; rounded where it ends the card.
    local pixel = UI.Pixel(row)
    row.sunken = row:CreateTexture(nil, "BACKGROUND", nil, -2)
    row.sunken:SetPoint("TOPLEFT", pixel, 0)
    row.sunken:SetPoint("BOTTOMRIGHT", -pixel, 0)
    UI.Paint(row.sunken, "sunken")
    row.sunkenLast = UI.Round(row, "sunken", 9, {
        sublevel = -2,
        inset = pixel,
        square = { TOPLEFT = true, TOPRIGHT = true },
    })
    row.bullet = UI.Icon(row, "circle", 5, "textMuted")

    row.label = UI.Text(row, 13, "text", "medium")
    row.desc = UI.Text(row, 12, "textMuted")
    row.desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
    row.desc:SetSpacing(2)

    row:SetScript("OnEnter", function(self)
        if not self.disabled and not HOVERLESS[self.item.kind] then
            self.hover:Fade(true)
        end
    end)
    row:SetScript("OnLeave", function(self)
        self.hover:Fade(false)
    end)
    row:SetScript("OnClick", RowClicked)
    return row
end

-- A card behind a block of rows, with the block's title above it.
local function CreateCard(parent)
    local card = CreateFrame("Frame", nil, parent)
    card:SetWidth(CONTENT_W)
    card:SetFrameLevel(parent:GetFrameLevel() + 1)
    card.shape = UI.Card(card, "card", "cardBorder", 10)

    -- A little light on the top edge.
    local pixel = UI.Pixel(card)
    local sheen = UI.Line(card, "sheenSoft")
    sheen:SetPoint("TOPLEFT", 10, -pixel)
    sheen:SetPoint("TOPRIGHT", -10, -pixel)

    -- Mark of a card whose feature is switched on.
    card.mark = card:CreateTexture(nil, "BORDER")
    card.mark:SetPoint("TOPLEFT", 0, -14)
    card.mark:SetPoint("BOTTOMLEFT", 0, 14)
    card.mark:SetWidth(2)
    UI.Paint(card.mark, "accent")

    card.title = UI.Text(card, 12, "textDim", "semibold")
    card.title:SetPoint("BOTTOMLEFT", card, "TOPLEFT", 4, 9)
    card.note = UI.Text(card, 12, "textMuted", "medium")
    card.note:SetPoint("BOTTOMRIGHT", card, "TOPRIGHT", -4, 9)
    card.note:SetJustifyH("RIGHT")
    return card
end

-- Shows on a feature's card whether the feature runs.
local function CardRefresh(card)
    local active = card.block ~= nil and card.block.active ~= nil and card.block.active()
    card.shape.border:SetColor(active and "cardActive" or "cardBorder")
    card.mark:SetShown(active)
end

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------

local function CategoryCount(category)
    local active, total = 0, 0
    for _, feature in ipairs(ns.featureList) do
        if feature.category == category and feature:IsShown() then
            total = total + 1
            if feature.enabled then
                active = active + 1
            end
        end
    end
    return active, total
end

-- Active and total features of an area, and whether any of its categories
-- is switched on at all.
local function AreaCount(area)
    local active, total, anyOn = 0, 0, false
    for _, category in ipairs(area.categories) do
        local a, t = CategoryCount(category)
        active, total = active + a, total + t
        anyOn = anyOn or ns:IsCategoryEnabled(category)
    end
    return active, total, anyOn
end

local function RefreshSidebar()
    local searching = searchText ~= ""
    for id, button in pairs(navButtons) do
        local page = pages[id]
        local selected = not searching and id == currentPage
        button.selected = selected
        button.fill:SetShown(selected)
        button.bar:SetShown(selected)
        button.label:SetText(page.title())
        UI.Ink(button.label, selected and "text" or "textDim")
        UI.Tint(button.icon, selected and "accent" or "textMuted")
        if page.area then
            local active, total, anyOn = AreaCount(page.area)
            -- A switched-off area is greyed out here as well.
            button.label:SetAlpha(anyOn and 1 or 0.45)
            button.icon:SetAlpha(anyOn and 1 or 0.45)
            -- The counter sits on a small plate; "off" stands alone.
            button.count:SetText(anyOn and (active .. "/" .. total) or L.ui_category_off)
            UI.Ink(button.count, anyOn and selected and "accent" or "textMuted")
            button.pill:SetWidth(button.count:GetStringWidth() + 14)
            button.plate:SetShown(anyOn)
            button.plate:SetColor(selected and "accentSoft" or "chip")
        end
    end
    local active, total = ns:CountActiveFeatures()
    window.status:SetText(L.ui_active_count:format(active, total))
    window.tagline:SetText("v" .. ns.version)
    window.navHeading:SetText(L.ui_nav_features)
end

local function RefreshTabs(animate)
    local page = pages[currentPage]
    local list = {}
    for i, tab in ipairs(page.tabs) do
        list[i] = {
            id = tab.id,
            text = tab.label and tab.label() or "",
            dim = tab.category ~= nil and not ns:IsCategoryEnabled(tab.category),
        }
    end
    window.tabs:SetTabs(list, CurrentTab(page).id, animate)
end

-- The master switch of the tab's category, right in the line below the tabs.
local function RefreshMaster(animate)
    local master = window.master
    local tab = CurrentTab()
    if searchText ~= "" or not tab.category then
        master:Hide()
        return
    end
    local enabled = ns:IsCategoryEnabled(tab.category)
    master:Show()
    master.caption:SetText(enabled and L.ui_category_on or L.ui_category_off)
    master:SetWidth(master.caption:GetStringWidth() + 10 + 34)
    master.toggle:Set(enabled, animate)
end

local function HasSettings(tab)
    for _, item in ipairs(tab.settings) do
        if item.section then
            return true
        end
    end
    return false
end

-- True if "reset" would change anything on the current tab.
local function TabDiffersFromDefaults(tab)
    if tab.category and not ns:IsCategoryEnabled(tab.category) and HasSettings(tab) then
        return true
    end
    for _, item in ipairs(tab.settings) do
        if item.section then
            if item.key then
                if not ns:IsDefault(item.section, item.key) then
                    return true
                end
            elseif not ns:IsSectionDefault(item.section) then
                return true
            end
        end
    end
    return false
end

local function UpdateResetButton()
    local button = window.resetButton
    local tab = CurrentTab()
    local usable = searchText == "" and TabDiffersFromDefaults(tab)
    if not usable then
        resetArmed = false
    end
    button:SetDisabled(not usable)
    button:SetLabel(resetArmed and L.ui_reset_confirm or L.ui_reset_page)
    button:SetTone(resetArmed and "danger" or nil)
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

local function RefreshThemeButton()
    window.themeButton:SetIcon(UI.isDark and "sun" or "moon")
end

-- Refreshes switches and counters without touching the layout.
local function RefreshState(animate)
    for i = 1, #rows do
        if rows[i]:IsShown() then
            RowRefresh(rows[i], animate)
        end
    end
    for i = 1, #cards do
        if cards[i]:IsShown() then
            CardRefresh(cards[i])
        end
    end
    if searchText == "" then
        RefreshTabs(animate)
    end
    RefreshMaster(animate)
    UpdateResetButton()
    RefreshSidebar()
    RefreshThemeButton()
end

-- Places the tab bar, the description line and the scroll area from top to
-- bottom; parts a page does not need take no room.
local function LayoutHeader(showTabs, sectionText, showActions)
    local y = HEADER
    window.tabs:SetShown(showTabs)
    if showTabs then
        window.tabs:ClearAllPoints()
        window.tabs:SetPoint("TOPLEFT", window, "TOPLEFT", SIDEBAR + PAD, -y)
        y = y + 34 + 16
    end

    local section = window.section
    local hasSection = sectionText ~= nil and sectionText ~= "" or showActions
    section:SetShown(hasSection)
    if hasSection then
        local actionsWidth = 0
        if window.master:IsShown() then
            actionsWidth = actionsWidth + window.master:GetWidth() + 8
        end
        if window.resetButton:IsShown() then
            -- Room for the longer "really reset?" as well.
            actionsWidth = actionsWidth + math.max(170, window.resetButton:GetWidth()) + 8
        end
        section.desc:SetWidth(CONTENT_W - actionsWidth - 16)
        section.desc:SetText(sectionText or "")
        local height = math.max(28, section.desc:GetStringHeight())
        section:SetHeight(height)
        section:ClearAllPoints()
        section:SetPoint("TOPLEFT", window, "TOPLEFT", SIDEBAR + PAD, -y)
        y = y + height + 16
    end

    window.scroll:ClearAllPoints()
    window.scroll:SetPoint("TOPLEFT", window, "TOPLEFT", SIDEBAR + PAD, -y)
    window.scroll:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, 18)
end

-- animateTabs: let the tab bar slide (only when switching tabs).
function Render(animateTabs)
    UI.CloseMenu()
    local searching = searchText ~= ""
    local page = pages[currentPage]
    local tab = CurrentTab(page)
    local blocks, key

    if searching then
        local total
        blocks, total = SearchBlocks(searchText)
        window.title:SetText(L.ui_search_title)
        if total > 0 then
            window.subtitle:SetText(L.ui_search_results:format(total))
        else
            window.subtitle:SetText(L.ui_search_none:format(searchText))
        end
        key = "search:" .. searchText
    else
        blocks = tab.blocks()
        window.title:SetText(page.title())
        window.subtitle:SetText(page.desc())
        key = page.id .. ":" .. tab.id
        RefreshTabs(animateTabs == true)
    end

    -- Actions of the tab: reset where it has settings, the master switch
    -- where it belongs to a category.
    window.resetButton:SetShown(not searching and HasSettings(tab))
    UpdateResetButton()
    RefreshMaster(false)
    local reset = window.resetButton
    reset:ClearAllPoints()
    if window.master:IsShown() then
        reset:SetPoint("RIGHT", window.master, "LEFT", -12, 0)
    else
        reset:SetPoint("RIGHT", window.section, "RIGHT", -10, 0)
    end
    local showActions = not searching and (window.master:IsShown() or window.resetButton:IsShown())
    LayoutHeader(not searching and #page.tabs > 1, not searching and tab.desc and tab.desc() or nil, showActions)

    local content = window.scroll.content
    local y, rowCount = 0, 0
    for blockIndex, block in ipairs(blocks) do
        local card = cards[blockIndex]
        if not card then
            card = CreateCard(content)
            cards[blockIndex] = card
        end
        if block.title then
            y = y + BLOCK_TITLE
        end
        card.title:SetText(block.title or "")
        card.note:SetText(block.note or "")
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)

        local offset = 0
        for index, item in ipairs(block.items) do
            rowCount = rowCount + 1
            local row = rows[rowCount]
            if not row then
                row = CreateRow(content)
                rows[rowCount] = row
            end
            RowSetItem(row, item, index, searching, index == #block.items)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(y + offset))
            row:Show()
            offset = offset + row.height
        end
        card.block = block
        card:SetHeight(math.max(1, offset))
        card:Show()
        CardRefresh(card)
        -- Cards of single features sit close together.
        y = y + offset + (block.tight and not searching and CARD_GAP or BLOCK_GAP)
    end
    for index = rowCount + 1, #rows do
        rows[index]:Hide()
    end
    for index = #blocks + 1, #cards do
        cards[index]:Hide()
    end

    window.scroll:SetContentHeight(y)
    -- Rows that fold or unfold on the same tab must not make it jump.
    if key ~= renderedKey then
        renderedKey = key
        window.scroll:ScrollToTop()
    end

    window.search.placeholder:SetText(L.ui_search)
    RefreshSidebar()
    RefreshThemeButton()
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

local function SelectTab(id)
    DisarmReset()
    selectedTabs[currentPage] = id
    Render(true)
end

local function ResetTab()
    local tab = CurrentTab()
    local sections, seen = {}, {}
    for _, item in ipairs(tab.settings) do
        if item.section and item.key then
            ns:SetOption(item.section, item.key, ns:GetDefault(item.section, item.key))
        elseif item.section and not seen[item.section] then
            seen[item.section] = true
            sections[#sections + 1] = item.section
        end
    end
    ns:ResetSections(sections)
    if tab.category then
        ns:SetOption("categories", tab.category, true)
    end
end

-- The first click asks, the second one within a few seconds resets.
local function ResetClicked()
    if resetArmed then
        resetArmed = false
        UpdateResetButton()
        ResetTab()
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

local function CreateNavButton(parent, page)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(NAV_ROW)
    button.navId = page.id

    -- The chosen entry: the accent fading out to the right, and a glowing
    -- bar at its left edge.
    button.fill = UI.Round(button, "accentFade", 8)
    button.fill:SetGradient("HORIZONTAL", "accentFade", "accentFadeEnd", SIDEBAR - 24, NAV_ROW)
    button.fill:Hide()
    local hover = UI.Round(button, "hover", 8, { sublevel = 1 })
    hover:Hide()

    button.bar = CreateFrame("Frame", nil, button)
    button.bar:SetSize(3, NAV_ROW - 16)
    button.bar:SetPoint("LEFT")
    local stroke = button.bar:CreateTexture(nil, "ARTWORK")
    stroke:SetAllPoints(button.bar)
    UI.Shade(stroke, "VERTICAL", "accent2", "accent")
    UI.Shadow(button.bar, 6, 1, 0, "accentGlow")
    button.bar:Hide()

    button.icon = UI.Icon(button, page.icon, 16, "textMuted")
    button.icon:SetPoint("LEFT", 12, 0)

    button.label = UI.Text(button, 13, "textDim", "medium")
    button.label:SetPoint("LEFT", button.icon, "RIGHT", 10, 0)
    button.label:SetJustifyV("MIDDLE")

    if page.area then
        button.pill = CreateFrame("Frame", nil, button)
        button.pill:SetHeight(18)
        button.pill:SetPoint("RIGHT", -8, 0)
        button.plate = UI.Round(button.pill, "chip", 9)
        button.count = UI.Text(button.pill, 11, "textMuted", "medium")
        button.count:SetPoint("CENTER")
        button.count:SetJustifyH("CENTER")
        button.count:SetJustifyV("MIDDLE")
    end

    button:SetScript("OnEnter", function(self)
        if not self.selected then
            hover:Fade(true)
        end
    end)
    button:SetScript("OnLeave", function()
        hover:Fade(false)
    end)
    button:SetScript("OnClick", function()
        hover:Hide()
        SelectPage(page.id)
    end)
    navButtons[page.id] = button
    return button
end

local function SavePosition()
    local point, _, relativePoint, x, y = window:GetPoint(1)
    ns.global.window = { point = point, relativePoint = relativePoint, x = x, y = y }
end

local function BuildSidebar()
    local sidebar = CreateFrame("Frame", nil, window)
    sidebar:SetPoint("TOPLEFT")
    sidebar:SetPoint("BOTTOMLEFT")
    sidebar:SetWidth(SIDEBAR)
    local pixel = UI.Pixel(window)
    UI.Round(sidebar, "sidebar", RADIUS - pixel, {
        inset = pixel,
        sublevel = 2,
        square = { TOPRIGHT = true, BOTTOMRIGHT = true },
    })
    local edge = UI.VLine(sidebar, "cardBorder")
    edge:SetPoint("TOPRIGHT")
    edge:SetPoint("BOTTOMRIGHT")

    -- A soft glow in the accent colour behind the logo. It is one round
    -- spot, much larger than the corner it sits in; two pieces show the part
    -- inside the sidebar and leave out the window's rounded corner.
    local SPOT = { left = -116, top = -136, width = 400, height = 360 }
    local function Haze(left, top, right, bottom)
        local piece = sidebar:CreateTexture(nil, "BACKGROUND", nil, 3)
        piece:SetTexture(UI.media.shadow)
        piece:SetPoint("TOPLEFT", sidebar, "TOPLEFT", left, -top)
        piece:SetPoint("BOTTOMRIGHT", sidebar, "TOPLEFT", right, -bottom)
        piece:SetTexCoord(
            (left - SPOT.left) / SPOT.width,
            (right - SPOT.left) / SPOT.width,
            (top - SPOT.top) / SPOT.height,
            (bottom - SPOT.top) / SPOT.height
        )
        UI.Tint(piece, "accentHaze")
    end
    local hazeBottom = SPOT.top + SPOT.height
    Haze(RADIUS, pixel, SIDEBAR - pixel, hazeBottom)
    Haze(pixel, RADIUS, RADIUS, hazeBottom)

    -- The corner itself: a quarter circle in the glow's strength at that
    -- spot (the falloff of shadow.tga, see tools/make_media.py). Without
    -- it the corner shows as a dark square in the glow.
    local function SpotAlpha(x, y)
        local dx = ((x - SPOT.left) / SPOT.width - 0.5) * 64
        local dy = ((y - SPOT.top) / SPOT.height - 0.5) * 64
        local distance = math.max(0, math.sqrt(dx * dx + dy * dy) - 4)
        return (1 - math.min(1, distance / 28)) ^ 2.2
    end
    local corner = sidebar:CreateTexture(nil, "BACKGROUND", nil, 3)
    corner:SetTexture(UI.media.circle)
    corner:SetTexCoord(0, 0.5, 0, 0.5)
    corner:SetSize(RADIUS - pixel, RADIUS - pixel)
    corner:SetPoint("TOPLEFT", sidebar, "TOPLEFT", pixel, -pixel)
    UI.Tint(corner, "accentHaze", SpotAlpha(RADIUS * 0.6, RADIUS * 0.6))

    -- Logo: the accent with an "S", so it follows the chosen scheme.
    local logo = CreateFrame("Frame", nil, sidebar)
    logo:SetSize(32, 32)
    logo:SetPoint("TOPLEFT", 20, -22)
    UI.Shadow(logo, 10, 9, 0, "accentGlow")
    UI.Round(logo, "accent", 9, { layer = "ARTWORK" }):SetGradient("VERTICAL", "accent2", "accent", 32, 32)
    local letter = UI.Text(logo, 18, "onAccent", "semibold")
    letter:SetPoint("CENTER", 0, 0)
    letter:SetJustifyH("CENTER")
    letter:SetJustifyV("MIDDLE")
    letter:SetText("S")

    local wordmark = UI.Text(sidebar, 16, "text", "semibold")
    wordmark:SetPoint("TOPLEFT", logo, "TOPRIGHT", 11, -1)
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

    window.navHeading = UI.Text(sidebar, 11, "textMuted", "semibold")
    window.navHeading:SetPoint("TOPLEFT", 28, -NAV_TOP + 22)

    -- Main features from the top, the addon's own pages from the bottom.
    local top, bottom = 0, {}
    for _, id in ipairs(pageOrder) do
        local page = pages[id]
        local button = CreateNavButton(sidebar, page)
        if page.bottom then
            bottom[#bottom + 1] = button
        else
            button:SetPoint("TOPLEFT", 12, -NAV_TOP - top * (NAV_ROW + 2))
            button:SetPoint("TOPRIGHT", -12, -NAV_TOP - top * (NAV_ROW + 2))
            top = top + 1
        end
    end
    for i, button in ipairs(bottom) do
        local y = 52 + (#bottom - i) * (NAV_ROW + 2)
        button:SetPoint("BOTTOMLEFT", 12, y)
        button:SetPoint("BOTTOMRIGHT", -12, y)
    end

    local line = UI.Line(sidebar, "cardBorder")
    line:SetPoint("BOTTOMLEFT", 20, 42)
    line:SetPoint("BOTTOMRIGHT", -20, 42)

    local dot = UI.Icon(sidebar, "circle", 6, "accent")
    dot:SetPoint("BOTTOMLEFT", 24, 21)
    UI.Halo(sidebar, dot, 18, "accentGlow")
    window.status = UI.Text(sidebar, 11, "textMuted", "medium")
    window.status:SetPoint("LEFT", dot, "RIGHT", 8, 0)
    window.status:SetJustifyV("MIDDLE")
end

local function BuildHeader()
    window.title = UI.Text(window, 20, "text", "semibold")
    window.title:SetPoint("TOPLEFT", SIDEBAR + PAD, -24)

    window.subtitle = UI.Text(window, 12, "textMuted")
    window.subtitle:SetPoint("TOPLEFT", window.title, "BOTTOMLEFT", 0, -7)
    window.subtitle:SetWidth(CONTENT_W - 90)

    local close = UI.IconButton(window, "close", function()
        window:Hide()
    end, 28)
    close:SetPoint("TOPRIGHT", -12, -12)
    window.closeButton = close

    window.themeButton = UI.IconButton(window, "sun", function()
        ns:SetOption("general", "theme", UI.isDark and "light" or "dark")
    end, 28)
    window.themeButton:SetPoint("RIGHT", close, "LEFT", -4, 0)

    window.tabs = UI.Tabs(window, SelectTab)
    window.tabs:SetWidth(CONTENT_W)

    -- Line under the tabs: what the tab is about, its actions on the right.
    local section = CreateFrame("Frame", nil, window)
    section:SetWidth(CONTENT_W)
    section.desc = UI.Text(section, 12, "textMuted")
    section.desc:SetPoint("LEFT")
    section.desc:SetJustifyV("MIDDLE")
    section.desc:SetSpacing(2)
    window.section = section

    -- Master switch of the category, in line with the switches of the rows.
    local master = CreateFrame("Button", nil, section)
    master:SetHeight(28)
    master:SetPoint("RIGHT", -18, 0)
    master.toggle = UI.Toggle(master)
    master.toggle:SetPoint("RIGHT")
    master.caption = UI.Text(master, 11, "textDim", "semibold")
    master.caption:SetPoint("RIGHT", master.toggle, "LEFT", -10, 0)
    master.caption:SetJustifyV("MIDDLE")
    master:SetScript("OnEnter", function(self)
        UI.Ink(self.caption, "text")
    end)
    master:SetScript("OnLeave", function(self)
        UI.Ink(self.caption, "textDim")
    end)
    master:SetScript("OnClick", function()
        local category = CurrentTab().category
        ns:SetOption("categories", category, not ns:IsCategoryEnabled(category))
    end)
    window.master = master

    window.resetButton = UI.Button(section, ResetClicked, "ghost", "reset")
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
    UI.Shadow(window, 32, RADIUS, 10)
    UI.Card(window, "window", "cardBorder", RADIUS)

    -- Light catching the top edge, across sidebar and content alike. Its
    -- own frame, so that it lies above the sidebar's ground.
    local pixel = UI.Pixel(window)
    local gloss = CreateFrame("Frame", nil, window)
    gloss:SetFrameLevel(window:GetFrameLevel() + 30)
    gloss:SetPoint("TOPLEFT", RADIUS, -pixel)
    gloss:SetPoint("TOPRIGHT", -RADIUS, -pixel)
    gloss:SetHeight(pixel)
    UI.Fill(gloss, "sheen")

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

    BuildSidebar()
    BuildHeader()

    window.scroll = UI.Scroll(window)
    window.scroll.content:SetWidth(CONTENT_W)

    window:SetScript("OnShow", function(self)
        ns:Fire("OPTIONS_SHOWN") -- lets switches that mirror game options catch up
        Render()
        self:SetAlpha(0)
        UI.Tween(self, 0.15, function(progress)
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
    if currentPage ~= "aliases" or searchText ~= "" or CurrentTab().id ~= "names" then
        selectedTabs.aliases = "names"
        SelectPage("aliases")
    end
    window.scroll:ScrollToTop()
    if aliasEditor then
        aliasEditor:Load(name, ns.AliasService.Get(name))
    end
end

---------------------------------------------------------------------------
-- Keeping the open window in sync. Several changes in one frame (for
-- example "reset") are folded into a single refresh.
---------------------------------------------------------------------------

local pendingRefresh -- nil, "state" or "layout"

local function FlushRefresh()
    local mode = pendingRefresh
    pendingRefresh = nil
    if not window or not window:IsShown() then
        return -- OnShow renders from scratch anyway
    end
    if mode == "layout" then
        Render(true)
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
    -- Switching a feature folds or unfolds its options, which moves rows;
    -- the category's master switch changes the actions next to the tabs.
    local feature = ns.features[section]
    if (key == "enabled" and feature and #feature.options > 0) or section == "categories" then
        RequestRefresh("layout")
    else
        RequestRefresh("state")
    end
end)
ns:On("FEATURE_STATE", function()
    RequestRefresh("state")
end)
ns:On("THEME_CHANGED", function()
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
