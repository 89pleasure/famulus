-- The settings window. Built on first open, never before: a player who
-- does not open it pays nothing for it.
--
-- Layout: sidebar (logo, search, one entry per main feature, then the
-- addon's own pages) | header with title and window buttons, tabs, a line
-- with the tab's description and its actions, then cards of rows.
--
-- A page has tabs; a tab has blocks; a block is one card of rows. Every row
-- is described by an "item" (label, help text, getter, setter). Main
-- features ("areas", see Core/Features.lua) get their page from a layout.
-- A settings tab (tab.split) shows its items differently: a list of
-- entries on the left, the chosen one in full on the right.

local _, ns = ...
local L = ns.L
local UI = ns.UI

local WIDTH, HEIGHT = 1180, 730
local SIDEBAR, PAD, RADIUS = 224, 28, 12
local CONTENT_W = WIDTH - SIDEBAR - PAD * 2
-- HEAD: the band across the top: logo, the chosen page's name, close.
-- TABS: the page's tabs at the top of the content; HEADER: from there to
-- where the content begins.
local HEAD, TABS = 76, 48
local HEADER = TABS + 20
-- The chronicle's story tabs: the book, and beside it a rail that stays put
-- while the book scrolls.
local BOOK_W, RAIL_GAP = 600, 28
local RAIL_W = CONTENT_W - BOOK_W - RAIL_GAP
local NAV_ROW = 34
local BLOCK_GAP, BLOCK_TITLE = 22, 24

local WINDOW_SCALES = { 80, 90, 100, 110, 120, 130, 140 }
local AREA_ICONS = { aliases = "tag", chronicle = "flag", fellows = "people" }
-- Icons of the addon's own settings in their entries (features: feature.icon).
local GENERAL_ICONS = {
    language = "globe",
    timeFormat = "clock",
    dateFormat = "calendar",
    chatOutput = "chat",
    minimapButton = "compass",
    charProfile = "person",
    accent = "drop",
    embers = "sparkle",
    windowScale = "resize",
    chronicleNames = "tag",
}
-- Their pictures (UI/Previews.lua; features: feature.preview).
local GENERAL_PREVIEWS = {
    language = "lang",
    timeFormat = "time",
    dateFormat = "date",
    chatOutput = "chatfam",
    minimapButton = "minimap",
    charProfile = "profile",
    accent = "accent",
    embers = "embers",
    windowScale = "scale",
    chronicleNames = "names",
}

-- Rows that stand for a person: an avatar with an initial in front, a
-- button to remove them behind. A click calls item.open, the button
-- item.remove.
local PERSON_ROWS = { alias = true, fellow = true }

local window
local pages, pageOrder = {}, {}
local currentPage, selectedTabs, searchText = nil, {}, ""
local rows, cards, navButtons = {}, {}, {}
local renderedKey -- page, tab or search the rows were last laid out for
local listKey, detailKey -- settings tab and entry the list and the detail were last laid out for
local railKey -- page and tab the chronicle's rail was last filled for
local chronicleWho -- the companion the chronicle's book is narrowed to, or nil
local fellowSort = "last" -- order of the fellow travellers' list: "last" or "time"
local fellowStory -- the fellow traveller whose story is open, or nil
local resetArmed, resetToken = false, 0
local tidyArmed, tidyToken = false, 0 -- the fellow travellers' tidying up asks first, too
local aliasEditor -- input row of the aliases page, once it has been shown
local embers = {} -- the sparks in the background, one set per ground
-- The welcome page (UI/Welcome.lua): whether it is shown, and the page once built.
-- holdWelcome: the window opens for something asked for (an alias), not for it.
local welcoming, holdWelcome, welcomePage = false, false, nil
local Render, PlayEmbers, SelectPage, RefreshState, OpenWelcome -- forward declarations
local RenderSplit, RefreshSplit -- the settings tabs, see there

-- Grain lies in a band across the top of the window, sidebar and content
-- alike, and fades out below the tabs.
local GRAIN_BAND = 210

---------------------------------------------------------------------------
-- Items
---------------------------------------------------------------------------

local function FeatureItem(feature)
    local function unusable()
        return feature.failed or not feature:IsAvailable()
    end
    return {
        kind = "toggle",
        id = feature.id,
        section = feature.id,
        icon = feature.icon or AREA_ICONS[feature.category] or "sparkle",
        -- A picture of what the feature does, shown above it in its
        -- settings tab: the name of its scene (UI/Previews.lua).
        preview = feature.preview,
        default = function()
            return ns:GetDefault(feature.id, "enabled")
        end,
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
        id = feature.id .. "." .. option.key,
        child = true,
        section = feature.id,
        -- Options of a group (option.group) are shown together as chips,
        -- each with its icon, below a heading of their own.
        group = option.group,
        icon = option.icon,
        -- Pointed at, the feature's picture may show what this option does.
        optionKey = option.key,
        default = function()
            return ns:GetDefault(feature.id, option.key)
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
    if option.group then
        local group = "o_" .. feature.id .. "_" .. option.group
        item.groupLabel = function()
            return L[group]
        end
        item.groupDesc = function()
            return L[group .. "_desc"]
        end
    end
    return item
end

-- An option of the addon itself. Unlike feature rows, it resets on its own
-- (key) instead of with its whole section.
local function GeneralItem(key, kind, values)
    return {
        kind = kind,
        id = "general." .. key,
        section = "general",
        icon = GENERAL_ICONS[key] or "gear",
        preview = GENERAL_PREVIEWS[key],
        key = key,
        default = function()
            return ns:GetDefault("general", key)
        end,
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

-- The master switch of a main feature, in Settings › General.
local function CategoryItem(category)
    return {
        kind = "toggle",
        id = "categories." .. category,
        section = "categories",
        icon = AREA_ICONS[category] or "sparkle",
        preview = "areas",
        key = category,
        default = function()
            return ns:GetDefault("categories", category)
        end,
        label = function()
            return L["area_" .. category]
        end,
        desc = function()
            return L["area_" .. category .. "_desc"]
        end,
        get = function()
            return ns:IsCategoryEnabled(category)
        end,
        set = function(value)
            ns:SetOption("categories", category, value)
        end,
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
            items[#items + 1] = FeatureItem(feature)
            for _, option in ipairs(feature.options) do
                items[#items + 1] = OptionItem(feature, option)
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
            open = function()
                ns:EditAlias(entry.name)
            end,
            remove = function()
                ns.AliasService.Set(entry.name, nil)
            end,
            label = function()
                return entry.alias
            end,
            desc = function()
                if not entry.account then
                    return entry.name
                end
                -- An account: its BattleTag, then the characters known so far.
                local chars = #entry.chars > 0 and table.concat(entry.chars, ", ") or L.ui_alias_account_empty
                return L.ui_alias_account_chars:format(L.ui_alias_account:format(entry.name), chars)
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
local Initial = UI.Initial

---------------------------------------------------------------------------
-- Pages and tabs
---------------------------------------------------------------------------

-- A settings tab of a main feature: its features, each followed by its
-- options. Shown as entries with the chosen one in full (split).
local function CategoryTab(category)
    local items = FeatureItems(category)
    -- A list of its own: a layout may add to the settings (for reset)
    -- what it shows in a block of its own.
    local shown = {}
    for index, item in ipairs(items) do
        shown[index] = item
    end
    local blocks = { { items = shown } }
    return {
        id = category,
        category = category,
        split = true,
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

-- Aliases: the list is the heart of the page; where aliases show up is the
-- second tab.
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

-- A tab of the addon's own settings, shown like the features' (split).
local function SimpleTab(id, items)
    return {
        id = id,
        split = true,
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

    local switches = {}
    for _, category in ipairs(ns.categories) do
        switches[#switches + 1] = CategoryItem(category)
    end
    local general = SimpleTab("general", {
        GeneralItem("chatOutput", "toggle"),
        GeneralItem("minimapButton", "toggle"),
        profileItem,
    })
    -- The main features' switches come first, under a heading of their own.
    local others = general.settings
    general.settings = {}
    for _, item in ipairs(switches) do
        general.settings[#general.settings + 1] = item
    end
    for _, item in ipairs(others) do
        general.settings[#general.settings + 1] = item
    end
    general.blocks = function()
        return { { title = L.ui_features, items = switches }, { items = others } }
    end

    local appearance = SimpleTab("appearance", {
        GeneralItem("accent", "swatch", function()
            return UI.accents
        end),
        GeneralItem("embers", "toggle"),
        GeneralItem("windowScale", "select", function()
            local list = {}
            for i, percent in ipairs(WINDOW_SCALES) do
                list[i] = { value = percent, text = percent .. "%" }
            end
            return list
        end),
    })

    -- How Famulus writes: its language, the clock and the order of a date.
    local languageItem = GeneralItem("language", "select", function()
        local list = { { value = "auto", text = L.lang_auto } }
        for _, code in ipairs(ns:GetLocaleCodes()) do
            list[#list + 1] = { value = code, text = ns.locales[code].lang_name or code }
        end
        return list
    end)
    -- A saved language that is not offered (yet) speaks the client's, so it reads so.
    local savedLanguage = languageItem.get
    languageItem.get = function()
        local code = savedLanguage()
        return ns:IsLocaleOffered(code) and code or "auto"
    end
    local language = SimpleTab("language", {
        languageItem,
        -- Each clock and order by an example: today at 21:40, today's date.
        GeneralItem("timeFormat", "select", function()
            local today = date("*t")
            local evening = time({ year = today.year, month = today.month, day = today.day, hour = 21, min = 40 })
            local list = {}
            for index, format in ipairs(ns.TIME_FORMATS) do
                list[index] = { value = format, text = ns.FormatTime(evening, format) }
            end
            return list
        end),
        GeneralItem("dateFormat", "select", function()
            local year, month, day = string.match(date("%Y-%m-%d"), "^(%d+)-(%d+)-(%d+)$")
            local list = { { value = "auto", text = L.g_dateFormat_auto } }
            for _, pattern in ipairs(ns.DATE_FORMATS) do
                list[#list + 1] = { value = pattern, text = ns.FormatDate(year, month, day, pattern) }
            end
            return list
        end),
    })
    return { general, appearance, language }
end

---------------------------------------------------------------------------
-- Chronicle: the story of the player and their companions. Three tabs
-- tell it as a picture book, a fourth holds the switches that record it.
---------------------------------------------------------------------------

local function DayKey(timestamp)
    return date("%Y-%m-%d", timestamp)
end

-- "Today", "Yesterday" or the date of a day key ("2026-11-19") in the
-- chosen format.
local function DayTitle(key, today, yesterday)
    if key == today then
        return L.c_today
    elseif key == yesterday then
        return L.c_yesterday
    end
    local year, month, day = string.match(key, "^(%d+)-(%d+)-(%d+)$")
    if not year then
        return key
    end
    return ns.FormatDate(year, month, day)
end

local CHRONICLE_ROWS = 50 -- events in the book; older ones stay in the saved data

-- Whether anything writes into the chronicle right now.
local function ChronicleRecording()
    local features = ns.features
    return features.ownJourney.enabled or features.companions.enabled or features.sharing.enabled
end

-- An empty book says whether it waits for the first event or for a switch.
local CHRONICLE_EMPTY_ITEM = {
    kind = "info",
    label = function()
        return ChronicleRecording() and L.c_empty_on or L.c_empty
    end,
    desc = function()
        return ChronicleRecording() and L.c_empty_on_desc or L.c_empty_desc
    end,
}
-- The book narrowed to a companion who has nothing in it yet.
local CHRONICLE_EMPTY_WHO_ITEM = {
    kind = "info",
    label = function()
        return L.c_empty_who:format(ns.ChronicleService.Label({ who = chronicleWho }))
    end,
    desc = function()
        return L.c_empty_who_desc
    end,
}

-- A function that opens the profession window of a skill line, or nil if
-- this client cannot.
local function OpenProfession(skillLine)
    skillLine = tonumber(skillLine)
    if not skillLine or not (C_TradeSkillUI and C_TradeSkillUI.OpenTradeSkill) then
        return nil
    end
    return function()
        -- Not in combat: the game does not open its panels for addons then.
        if InCombatLockdown and InCombatLockdown() then
            return
        end
        C_TradeSkillUI.OpenTradeSkill(skillLine)
    end
end

-- A function that opens a companion's recipe book in the game's window, or
-- nil if the profession has none. The game shows it only while they are
-- online; otherwise the click says so.
local function OpenBook(entry)
    local Chronicle = ns.ChronicleService
    if not entry.who or not Chronicle.HasBook(entry.skill) or not SetItemRef then
        return nil
    end
    return function()
        if InCombatLockdown and InCombatLockdown() then
            return
        end
        local link = Chronicle.BookLink(entry.who, entry.skill)
        if not link then
            ns:Print(L.msg_book_offline:format((Chronicle.Companion(entry))))
            return
        end
        pcall(SetItemRef, link, "[" .. (entry.name or "") .. "]", "LeftButton")
    end
end

-- The game's icon of an item (a texture the client knows), or nil.
local function ItemIcon(itemID)
    itemID = tonumber(itemID)
    local icon = itemID and C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(itemID)
    if ns.IsSecret(icon) or (type(icon) ~= "number" and type(icon) ~= "string") then
        return nil
    end
    return icon
end

-- The picture of an entry: an icon of the game. Its own, where it has one
-- (written down with the entry, or the item's or the spell's), else the one
-- of its kind. A level and a profession's milestone show their number on it.
local function EntryTexture(entry, kind, special)
    local recorded = tonumber(entry.icon)
    if recorded then
        return recorded
    end
    if kind == "item" then
        local icon = ItemIcon(entry.item)
        if icon then
            return icon
        end
    elseif kind == "ability" and special and C_Spell and C_Spell.GetSpellTexture then
        local icon = C_Spell.GetSpellTexture(special.spell)
        if not ns.IsSecret(icon) and type(icon) == "number" then
            return icon
        end
    end
    return UI.gameIcons[kind == "skill" and "profession" or kind]
end

-- An entry as a book shows it (see UI/Book.lua).
local function ChronicleEvent(entry)
    local Chronicle = ns.ChronicleService
    -- The card says whose event it is in its head (the chip), so its
    -- headline does not; in the book as on the live feed.
    local title, detail = Chronicle.Text(entry, true)
    local kind = entry.k == "friendLevel" and "level" or entry.k
    local own, other = Chronicle.IsOwn(entry), Chronicle.OtherCharacter(entry)
    -- An ability or an item from the service's tables may bring a picture.
    local special = kind == "ability" and Chronicle.Ability(entry.ability)
        or kind == "item" and Chronicle.Item(entry.item) or nil
    local chip
    if not own then
        chip = { text = Chronicle.Label(entry) }
    elseif other then
        chip = { text = other }
    end
    return {
        kind = kind,
        title = title,
        detail = detail,
        when = ns.FormatTime(entry.t),
        number = kind == "level" and tonumber(entry.level) or kind == "skill" and tonumber(entry.rank) or nil,
        -- The player's own level-ups and what the tables mark as great are the milestones of the book.
        icon = special and special.picture or nil,
        -- The picture is an icon of the game.
        texture = EntryTexture(entry, kind, special),
        -- A profession opens on a click: the player's own, or the recipe
        -- book of a companion. Not those of the player's other characters.
        onClick = (kind == "profession" or kind == "skill")
            and (own and not other and OpenProfession(entry.skill) or not own and OpenBook(entry)) or nil,
        -- For the game's tooltip on the picture.
        item = kind == "item" and tonumber(entry.item) or nil,
        spell = kind == "ability" and special and special.spell or nil,
        big = own and not other and (kind == "level" or (special and special.big) or false),
        chip = chip,
    }
end

-- Whether two entries next to each other in the book tell the same thing
-- again: deaths in one place, or levels of one companion. They then share a
-- card. The player's own level-ups stay milestones of their own.
local function SameRun(a, b)
    local kindA = a.k == "friendLevel" and "level" or a.k
    local kindB = b.k == "friendLevel" and "level" or b.k
    if kindA ~= kindB or a.who ~= b.who or a.c ~= b.c then
        return false
    end
    if kindA == "death" then
        return a.zone == b.zone
    end
    return kindA == "level" and a.who ~= nil
end

-- How much an event weighs in the chronicle's book: the size and look of
-- its card. Other kinds are "medium"; what the tables mark as great is "high".
local WEIGHT = { death = "low", zone = "low", skill = "medium", boss = "high", level = "high" }

-- An entry as the chronicle's book tells it: the place is not in the text,
-- the foot of the card names it.
local function Placeless(entry)
    return setmetatable({ zone = false }, { __index = entry })
end

-- An entry as the live feed tells it (UI/Feed.lua), ordered like a card of
-- the book: whose it is in the head (the chip), what happened without name
-- and place, and below it the place first, then what else the line says.
function UI.FeedStory(entry)
    local story = ChronicleEvent(entry)
    local title, detail = ns.ChronicleService.Text(Placeless(entry), true)
    local zone = type(entry.zone) == "string" and entry.zone ~= "" and entry.zone or nil
    story.title = title
    story.detail = zone and detail and (zone .. "  ·  " .. detail) or zone or detail
    return story
end

-- The reaction on a card of the chronicle's book: its button at the foot's
-- right (UI/ChronicleCard.lua), as on the live feed's cards. A companion's
-- event gets the player's with a click on the button, and loses it with
-- another; a click on the card does what it did before (a recipe book). The
-- player's own event shows how many reacted, and who on the mouse. For a
-- run: the reaction goes to its newest entry, and those received to any count.
local function CardReaction(event, run)
    local Chronicle = ns.ChronicleService
    if not Chronicle.ReactionsOn() then
        return
    end
    local newest = run[1]
    local reaction = Chronicle.Reaction(newest)
    if reaction then
        local given, untold = false, false
        for _, entry in ipairs(run) do
            given = given or entry.mine ~= nil
            untold = untold or Chronicle.ReactionUntold(entry)
        end
        local name = (Chronicle.Companion(newest))
        event.reaction = {
            icon = reaction,
            lit = given,
            onClick = function()
                for _, entry in ipairs(run) do
                    Chronicle.React(entry, not given and entry == newest)
                end
            end,
            tooltip = function(tip)
                tip:SetText(given and L.c_react_given or L.c_react)
                if given and untold then
                    tip:AddLine(L.c_react_waiting:format(name), 1, 1, 1, true)
                end
            end,
        }
        return
    end
    if not Chronicle.IsOwn(newest) then
        return
    end
    local seen, names = {}, {}
    for _, entry in ipairs(run) do
        for _, who in ipairs(Chronicle.Reactions(entry)) do
            if not seen[who] then
                seen[who] = true
                names[#names + 1] = who
            end
        end
    end
    if #names == 0 then
        return
    end
    event.reaction = {
        icon = Chronicle.REACTIONS[newest.k] or "cheer",
        lit = true,
        count = #names,
        tooltip = function(tip)
            tip:SetText(L.c_reactions_from)
            for _, who in ipairs(names) do
                tip:AddLine(Chronicle.Label({ who = who }), 1, 1, 1)
            end
        end,
    }
end

-- A run of entries as a card of the chronicle's book: the look of the
-- newest, one sentence for all; the time in the strip, the place in the
-- foot (UI/ChronicleCard.lua).
local function ChronicleRun(run)
    local Chronicle = ns.ChronicleService
    local newest = run[1]
    local event = ChronicleEvent(newest)
    local told, zone = {}, type(newest.zone) == "string" and newest.zone or nil
    for index, entry in ipairs(run) do
        told[index] = Placeless(entry)
        if entry.zone ~= zone then
            zone = nil
        end
    end
    if #run == 1 then
        event.title, event.detail = Chronicle.Text(told[1], true)
    else
        event.title, event.detail = Chronicle.TextRun(told, true)
        event.count = #run
    end
    if #run > 1 then
        event.when = L.c_ch_span:format(ns.FormatTime(run[#run].t), event.when)
    end
    event.place = zone
    local special = event.kind == "ability" and Chronicle.Ability(newest.ability)
        or event.kind == "item" and Chronicle.Item(newest.item) or nil
    event.weight = special and special.big and "high" or WEIGHT[event.kind] or "medium"
    event.big = event.weight == "high"
    -- The strip names everyone, the player's own character too.
    local me = Chronicle.Character()
    event.chip = event.chip or { text = me }
    CardReaction(event, run)
    event.content = UI.ChronicleCard
    return event
end

-- A chapter is a session of play: a pause this long begins the next one.
local SESSION_GAP = 2 * 3600
-- Until five in the morning it is still the night of the day before.
local NIGHT_SHIFT = 5 * 3600

-- What a session that began at `timestamp` is called: "This evening",
-- "Yesterday afternoon", or for an older one "Sunday night" and its date.
local function SessionTitle(timestamp, now)
    local hour = tonumber(date("%H", timestamp)) or 12
    local part = hour < 5 and "night" or hour < 11 and "morning" or hour < 14 and "midday"
        or hour < 18 and "afternoon" or hour < 23 and "evening" or "night"
    local day = timestamp - NIGHT_SHIFT
    local key = DayKey(day)
    if key == DayKey(now - NIGHT_SHIFT) then
        return L["c_when_today_" .. part]
    elseif key == DayKey(now - NIGHT_SHIFT - 86400) then
        return L["c_when_yesterday_" .. part]
    end
    return L["c_when_day_" .. part]:format(L["c_weekday_" .. date("%w", day)]), DayTitle(key)
end

-- Names a chapter for the session from `from` to `to`: its title, and
-- left of it the date of an older one, else the times.
local function SessionHead(chapter, from, to, now)
    local title, day = SessionTitle(from, now)
    local first, last = ns.FormatTime(from), ns.FormatTime(to)
    chapter.title = title
    chapter.small = day or (first == last and first or L.c_ch_span:format(first, last))
end

-- Heading of a chapter: when the session was and from when to when, the
-- levels gained and the number of events, and below it the player's route
-- through the zones, in the order of time.
local function TitleChapter(chapter, now)
    local entries = chapter.entries -- the newest first
    local low, high
    local route = {}
    -- Sample entries do not name a chapter that has real ones.
    local real = false
    for _, entry in ipairs(entries) do
        real = real or not entry.demo
    end
    for index = #entries, 1, -1 do
        local entry = entries[index]
        if not (real and entry.demo) and ns.ChronicleService.IsOwn(entry) then
            local zone = entry.zone
            if type(zone) == "string" and zone ~= "" and route[#route] ~= zone then
                route[#route + 1] = zone
            end
            local level = tonumber(entry.level)
            if level then
                low, high = math.min(low or level, level), math.max(high or level, level)
            end
        end
    end
    SessionHead(chapter, entries[#entries].t, entries[1].t, now)
    chapter.route = #route > 0 and route or nil
    local parts = {}
    if low and low ~= high then
        parts[#parts + 1] = L.c_ch_levels:format(low, high)
    elseif low then
        parts[#parts + 1] = L.c_ch_level:format(low)
    end
    local count = #chapter.entries
    parts[#parts + 1] = ns.Plural("c_ch_events", count):format(count)
    chapter.sub = table.concat(parts, "  ·  ")
    chapter.entries = nil
end

-- One chapter as the chronicle's book tells it, from entries (the newest
-- first), each on a card of its own: the picture of the chronicle's
-- settings (UI/Previews.lua). Its cards cannot be clicked and show no
-- tooltip.
function UI.ChronicleChapter(entries)
    local chapter = { entries = entries, events = {} }
    for index, entry in ipairs(entries) do
        local story = ChronicleRun({ entry })
        story.onClick, story.tooltip, story.item, story.spell = nil, nil, nil, nil
        if story.reaction then
            story.reaction.onClick, story.reaction.tooltip = nil, nil
        end
        chapter.events[index] = story
    end
    TitleChapter(chapter, time())
    return chapter
end

-- One chapter per session of play (SESSION_GAP), the newest event first;
-- what repeats right away shares a card (SameRun). wanted(entry): which
-- entries; a companion chosen in the rail narrows them further. Returns nil
-- if there is nothing to tell, else the chapters and a closing line if older
-- events were left out.
local function ChronicleBook(wanted)
    local Chronicle = ns.ChronicleService
    local entries = Chronicle.Entries()
    local now = time()
    local chapters, chapter, shown, more = {}, nil, 0, false
    local run
    for i = #entries, 1, -1 do
        local entry = entries[i]
        if wanted(entry) and (not chronicleWho or entry.who == chronicleWho) then
            if shown == CHRONICLE_ROWS then
                more = true
                break
            end
            shown = shown + 1
            local previous = chapter and chapter.entries[#chapter.entries]
            if not previous or previous.t - entry.t >= SESSION_GAP then
                chapter = { runs = {}, entries = {} }
                chapters[#chapters + 1] = chapter
                run = nil
            end
            if run and SameRun(run[#run], entry) then
                run[#run + 1] = entry
            else
                run = { entry }
                chapter.runs[#chapter.runs + 1] = run
            end
            chapter.entries[#chapter.entries + 1] = entry
        end
    end
    if #chapters == 0 then
        return nil
    end
    for _, each in ipairs(chapters) do
        each.events = {}
        for index, eachRun in ipairs(each.runs) do
            each.events[index] = ChronicleRun(eachRun)
        end
        each.runs = nil
        TitleChapter(each, now)
    end
    return chapters, more and L.c_more or nil
end

---------------------------------------------------------------------------
-- The rail beside the book (UI/Rail.lua): the week in numbers, the
-- companions, the professions, the companions' profiles.
---------------------------------------------------------------------------

local WEEK = 7 * 86400

-- When an entry happened, briefly: the time today, else the day.
local function TimeOrDay(timestamp)
    local now = time()
    local key, today = DayKey(timestamp), DayKey(now)
    if key == today then
        return ns.FormatTime(timestamp)
    end
    return DayTitle(key, today, DayKey(now - 86400))
end

local function Number(value)
    if BreakUpLargeNumbers then
        return BreakUpLargeNumbers(value)
    end
    return tostring(value)
end

-- What the character that is playing did in the last seven days.
local function ChronicleWeek()
    local Chronicle = ns.ChronicleService
    local character = Chronicle.Character()
    local since = time() - WEEK
    local counts = { level = 0, death = 0, zone = 0, profession = 0, skill = 0 }
    local entries = Chronicle.Entries()
    for i = #entries, 1, -1 do
        local entry = entries[i]
        if entry.t < since then
            break
        end
        if Chronicle.IsOwn(entry) and (not character or entry.c == character) and counts[entry.k] then
            counts[entry.k] = counts[entry.k] + 1
        end
    end
    local level = UnitLevel and UnitLevel("player")
    level = not ns.IsSecret(level) and tonumber(level) or nil
    return {
        kind = "stats",
        title = L.c_week,
        note = character and string.match(character, "^%S+") or nil,
        stats = {
            { value = level and tostring(level) or "?", plus = counts.level > 0 and ("+" .. counts.level) or nil, label = L.c_week_level },
            { value = tostring(counts.death), label = L.c_week_deaths },
            { value = tostring(counts.zone), label = L.c_week_zones },
            { value = tostring(counts.profession + counts.skill), label = L.c_week_crafts },
        },
    }
end

-- A companion as the rail shows them; line: what stands below the name.
local function Person(companion, online, line)
    local Chronicle = ns.ChronicleService
    local person = { who = companion.who }
    return {
        key = companion.who,
        initial = Initial((Chronicle.Companion(person))),
        class = Chronicle.Class(companion.who),
        name = Chronicle.Label(person),
        line = line,
        level = companion.level and L.c_p_level:format(companion.level) or nil,
        online = online(companion.who),
        selected = chronicleWho == companion.who,
    }
end

-- A click on a companion narrows the book to them; a second one widens it.
local function SelectCompanion(who)
    chronicleWho = chronicleWho ~= who and who or nil
    Render()
end

-- The companions, the one heard of last first, each with their latest event.
local function ChronicleCompanions(companions, online)
    local people = {}
    for _, companion in ipairs(companions) do
        local last = companion.last
        local line = last and (ns.ChronicleService.Text(last, true) .. "  ·  " .. TimeOrDay(last.t)) or nil
        people[#people + 1] = Person(companion, online, line)
    end
    return {
        kind = "people",
        title = L.c_companions,
        note = tostring(#people),
        hint = L.c_rail_filter,
        people = people,
        onSelect = SelectCompanion,
    }
end

-- The professions of the character that is playing, or nil.
local function ChronicleCrafts()
    local bars = {}
    for _, profession in ipairs(ns.ChronicleService.Professions()) do
        if profession.name then
            bars[#bars + 1] = { label = profession.name, value = profession.rank, max = profession.max }
        end
    end
    if #bars == 0 then
        return nil
    end
    return { kind = "bars", title = L.c_crafts, bars = bars }
end

-- One card per companion: who they are, and what they told about themselves.
local function ChronicleBriefs(companions, online)
    local cards = {}
    for _, companion in ipairs(companions) do
        local card = Person(companion, online)
        card.kind, card.onSelect, card.empty = "brief", SelectCompanion, L.c_no_profile
        local profile = companion.profile
        if profile and type(profile.stats) == "table" then
            card.stats = {}
            for _, id in ipairs(ns.ChronicleService.STATISTICS) do
                local value = tonumber(profile.stats[id])
                card.stats[#card.stats + 1] = { value = value and Number(value) or "-", label = L["c_stat_" .. id] }
            end
        end
        cards[#cards + 1] = card
    end
    if #cards == 0 then
        return { { kind = "note", title = L.c_profiles, text = L.c_profiles_empty } }
    end
    return cards
end

function layouts.chronicle()
    local Chronicle = ns.ChronicleService
    -- people: a tab with friends. Each time it is shown, the friends list and
    -- the guild roster tell the classes of the people in the book, before
    -- the book and the rail are laid out (blocks come first).
    local function Tab(id, wanted, rail, people)
        return {
            id = id,
            category = "chronicle",
            label = function()
                return L["ui_tab_" .. id]
            end,
            desc = function()
                return L["ui_tab_" .. id .. "_desc"]
            end,
            settings = {},
            -- The events are told as a book; cards only say that it is empty.
            blocks = function()
                if people then
                    Chronicle.LearnClasses()
                end
                if ChronicleBook(wanted) then
                    return {}
                end
                return { { items = { chronicleWho and CHRONICLE_EMPTY_WHO_ITEM or CHRONICLE_EMPTY_ITEM } } }
            end,
            book = function()
                return ChronicleBook(wanted)
            end,
            rail = rail,
        }
    end
    local record = CategoryTab("chronicle")
    record.id = "record"
    record.label = function()
        return L.ui_tab_record
    end
    record.desc = function()
        return L.ui_tab_record_desc
    end
    -- How the chronicle names people records nothing: an entry of its own
    -- below the features, under a heading.
    local names = GeneralItem("chronicleNames", "toggle")
    record.settings[#record.settings + 1] = names
    local featureBlocks = record.blocks()
    record.blocks = function()
        local blocks = {}
        for index, block in ipairs(featureBlocks) do
            blocks[index] = block
        end
        blocks[#blocks + 1] = { title = L.c_display, items = { names } }
        return blocks
    end
    return {
        Tab("everyone", function()
            return true
        end, function()
            local companions = Chronicle.Companions()
            local cards = { ChronicleWeek() }
            if #companions > 0 then
                cards[2] = ChronicleCompanions(companions, Chronicle.OnlineCheck())
            end
            return cards
        end, true),
        Tab("mine", Chronicle.IsOwn, function()
            return { ChronicleWeek(), ChronicleCrafts() }
        end),
        Tab("companions", function(entry)
            return not Chronicle.IsOwn(entry)
        end, function()
            return ChronicleBriefs(Chronicle.Companions(), Chronicle.OnlineCheck())
        end, true),
        record,
    }
end

---------------------------------------------------------------------------
-- Fellow travellers: the players the player was in a group with. Two tabs
-- list them, by the last time together and by the time spent together; a
-- third holds the switches. A click on someone gives them an alias.
---------------------------------------------------------------------------

local FELLOW_ROWS = 60 -- people in the list; the search finds all of them
local FELLOW_CARD_W, FELLOW_GAP = 320, 20 -- the person's card beside their story
-- A fellow traveller's story: their card on the left, the book beside it.
local FELLOW_BOOK_W = CONTENT_W - FELLOW_CARD_W - FELLOW_GAP
local FELLOW_ACTIONS -- the card's buttons, see below

local FELLOW_EMPTY_ITEM = {
    kind = "info",
    label = function()
        return L.ui_fellow_empty
    end,
    desc = function()
        return L.ui_fellow_empty_desc
    end,
}

-- "today", "yesterday" or "on <date>", to stand in a sentence.
local function When(timestamp, now)
    local key = DayKey(timestamp)
    if key == DayKey(now) then
        return L.ui_fellow_today
    elseif key == DayKey(now - 86400) then
        return L.ui_fellow_yesterday
    end
    return L.ui_fellow_on:format(DayTitle(key))
end

-- "2 h 10 min", "25 min", or nil below a minute.
local function Duration(seconds)
    local minutes = math.floor(seconds / 60)
    if minutes < 1 then
        return nil
    elseif minutes < 60 then
        return L.ui_fellow_minutes:format(minutes)
    end
    return L.ui_fellow_hours:format(math.floor(minutes / 60), minutes % 60)
end

-- The class in the client's language, from the game's file name ("MAGE").
local function ClassName(file)
    local names = LOCALIZED_CLASS_NAMES_MALE
    local name = type(file) == "string" and type(names) == "table" and names[file]
    return type(name) == "string" and name or nil
end

-- Who they are, when and where you were together, and how much.
local function FellowDesc(guid, person)
    local Fellows = ns.FellowService
    local now = time()
    local parts = {}
    if ns.AliasService.Get(person.name) then
        parts[#parts + 1] = person.name
    end
    local level, class = tonumber(person.level), ClassName(person.class)
    if level and class then
        parts[#parts + 1] = L.ui_fellow_level_class:format(level, class)
    elseif level then
        parts[#parts + 1] = L.c_p_level:format(level)
    end
    if Fellows.IsTogether(guid) then
        parts[#parts + 1] = L.ui_fellow_now
    elseif type(person.zone) == "string" then
        parts[#parts + 1] = L.ui_fellow_last:format(When(person.last, now), person.zone)
    else
        parts[#parts + 1] = L.ui_fellow_last_nowhere:format(When(person.last, now))
    end
    parts[#parts + 1] = L.ui_fellow_times:format(tonumber(person.times) or 1)
    parts[#parts + 1] = Duration(Fellows.Seconds(guid, person, now))
    local bosses = tonumber(person.bosses) or 0
    if bosses > 0 then
        parts[#parts + 1] = ns.Plural("ui_fellow_bosses", bosses):format(bosses)
    end
    -- Where it began, unless that was the same day.
    local first = tonumber(person.first)
    if first and DayKey(first) ~= DayKey(person.last) then
        if type(person.firstZone) == "string" then
            parts[#parts + 1] = L.ui_fellow_first:format(When(first, now), person.firstZone)
        else
            parts[#parts + 1] = L.ui_fellow_first_nowhere:format(When(first, now))
        end
    end
    return table.concat(parts, "  ·  ")
end

local function FellowItem(guid, person)
    return {
        kind = "fellow",
        open = function()
            ns:EditAlias(person.name)
        end,
        remove = function()
            local name = ns.FellowService.Forget(guid)
            if name then
                ns:Notify(L.msg_fellow_forgotten:format(name))
            end
        end,
        label = function()
            return ns.AliasService.Get(person.name) or person.name
        end,
        desc = function()
            return FellowDesc(guid, person)
        end,
    }
end

-- Sort orders: the ones in the group now first, then the last time together;
-- or the time spent together. Ties go by name and GUID, so the order is stable.
local function Tiebreak(a, b)
    return (a.person.name .. a.guid) < (b.person.name .. b.guid)
end

local function ByLast(a, b)
    local Fellows = ns.FellowService
    local togetherA, togetherB = Fellows.IsTogether(a.guid), Fellows.IsTogether(b.guid)
    if togetherA ~= togetherB then
        return togetherA
    elseif a.person.last ~= b.person.last then
        return a.person.last > b.person.last
    end
    return Tiebreak(a, b)
end

local function ByTime(a, b, now)
    local Fellows = ns.FellowService
    local secondsA, secondsB = Fellows.Seconds(a.guid, a.person, now), Fellows.Seconds(b.guid, b.person, now)
    if secondsA ~= secondsB then
        return secondsA > secondsB
    elseif a.person.times ~= b.person.times then
        return a.person.times > b.person.times
    end
    return Tiebreak(a, b)
end

-- "Kennengelernt ...": a sentence fragment as the start of a line.
local Capital = ns.Capital

-- One person as the overview shows them; all texts made here.
local function FellowPerson(guid, person, now)
    local Fellows = ns.FellowService
    local seconds = Fellows.Seconds(guid, person, now)
    local tier, progress, toNext = Fellows.Tier(seconds)
    local alias = ns.AliasService.Get(person.name)
    local level, class = tonumber(person.level), ClassName(person.class)
    local together = Fellows.IsTogether(guid)
    local times, bosses = tonumber(person.times) or 1, tonumber(person.bosses) or 0
    local timeText = Duration(seconds) or L.ui_fellow_minutes:format(0)

    local stats = { timeText, L.ui_fellow_times_short:format(times) }
    if bosses > 0 then
        stats[#stats + 1] = ns.Plural("ui_fellow_bosses", bosses):format(bosses)
    end
    local last
    if together then
        last = L.ui_fellow_now
    elseif type(person.zone) == "string" then
        last = L.ui_fellow_last:format(When(person.last, now), person.zone)
    else
        last = L.ui_fellow_last_nowhere:format(When(person.last, now))
    end
    local first = tonumber(person.first)
    local firstText
    if first and type(person.firstZone) == "string" then
        firstText = Capital(L.ui_fellow_first:format(When(first, now), person.firstZone))
    elseif first then
        firstText = Capital(L.ui_fellow_first_nowhere:format(When(first, now)))
    end
    return {
        guid = guid,
        person = person,
        seconds = seconds,
        name = alias or person.name,
        realName = alias and person.name or nil,
        classFile = person.class,
        levelClass = level and class and L.ui_fellow_level_class:format(level, class)
            or level and L.c_p_level:format(level) or class or "",
        tier = tier,
        progress = progress,
        nextText = toNext and L.ui_bond_next:format(Duration(toNext) or L.ui_fellow_minutes:format(1)),
        timeText = timeText,
        hours = math.floor(seconds / 3600),
        minutes = math.floor(seconds / 60) % 60,
        statsText = table.concat(stats, "  ·  "),
        times = times,
        bosses = bosses,
        together = together,
        lastText = Capital(last),
        lastShort = together and L.ui_fellow_now_short or Capital(When(person.last, now)),
        firstText = firstText,
        -- The card puts the player's level then on a line of its own: "at level 31".
        firstLevelText = first and tonumber(person.firstLevel) and L.ui_fellow_met_detail:format(tonumber(person.firstLevel)) or nil,
        sinceText =first and L.ui_fellow_since:format(DayTitle(DayKey(first))) or nil,
        whisper = ns.ChatService.CanWhisper(),
    }
end

-- A made-up person (FellowService.SamplePerson) as the overview shows them:
-- the picture of the fellow travellers' settings (UI/Previews.lua).
function UI.FellowSample(person)
    return FellowPerson("sample:" .. person.name, person, time())
end

-- "10:40 to 12:50"
local function Span(from, to)
    return L.ui_fellow_span:format(ns.FormatTime(from), ns.FormatTime(to))
end

-- The fellow travellers' books, one chapter per session of play as in the
-- chronicle. events: the newest first, each from `from` to `t`; their
-- `seconds` add up to the time together in the heading. Returns the
-- chapters and true if events beyond `limit` were left out.
local function SessionChapters(events, now, limit)
    local chapters, chapter = {}, nil
    for index, event in ipairs(events) do
        if limit and index > limit then
            break
        end
        if not chapter or chapter.start - event.t >= SESSION_GAP then
            chapter = { events = {}, start = event.from, finish = event.t, seconds = 0 }
            chapters[#chapters + 1] = chapter
        end
        event.content = event.content or UI.FellowCard
        chapter.events[#chapter.events + 1] = event
        chapter.start = math.min(chapter.start, event.from)
        chapter.seconds = chapter.seconds + (event.seconds or 0)
    end
    for _, each in ipairs(chapters) do
        SessionHead(each, each.start, each.finish, now)
        each.sub = each.seconds > 0 and L.ui_fellow_day_time:format(Duration(each.seconds) or L.ui_fellow_minutes:format(0)) or nil
        each.start, each.finish, each.seconds = nil, nil, nil
    end
    return chapters, limit ~= nil and #events > limit
end

-- A fellow traveller's story as a book: one chapter per session of play,
-- the newest first, down to the first meeting. It tells only what you did
-- together, from the fellow travellers' own records; what the person did
-- on their own is the chronicle's to tell. Returns the person (as in the
-- overview) and the chapters, or nil if they are gone.
local function FellowStory(guid)
    local Fellows = ns.FellowService
    local person
    for _, each in ipairs(Fellows.List()) do
        if each.guid == guid then
            person = each.person
        end
    end
    if not person then
        return nil
    end
    local now = time()
    local milestones = Fellows.Milestones(guid, person, now)
    local events = {}
    local first = tonumber(person.first)
    if first then
        events[1] = {
            kind = "bond",
            big = true,
            title = L.ui_fellow_met,
            detail = person.firstLevel and L.ui_fellow_met_detail:format(person.firstLevel) or nil,
            when = ns.FormatTime(first),
            t = first,
            from = first,
        }
    end

    -- A stretch together per day; a session over midnight is one stretch.
    -- shortcut: the day log keeps only a day's first and last moment, so two sessions on one day stay one; read the groups (FellowService.Runs) to tell them apart.
    local stretch
    for _, day in ipairs(Fellows.Days(person)) do
        -- A boss counted before any time: noon of its day.
        local noon = time({ year = math.floor(day.key / 10000), month = math.floor(day.key / 100) % 100, day = day.key % 100, hour = 12 })
        local from, to = day.f or noon, day.l or noon
        -- Named bosses get a card each; the others (a raid, or more than a
        -- day keeps) are counted on the stretch's line.
        local unnamed = math.max(0, day.b - #day.k)
        if stretch and stretch.timed and day.l and stretch.from - day.l < SESSION_GAP then
            stretch.from, stretch.seconds, stretch.unnamed = from, stretch.seconds + day.s, stretch.unnamed + unnamed
        else
            stretch = { kind = "fellow", from = from, t = to, seconds = day.s, unnamed = unnamed, zone = day.z, timed = day.f ~= nil }
            events[#events + 1] = stretch
        end
        for _, kill in ipairs(day.k) do
            local event = ChronicleEvent({ k = "boss", name = kill.n, zone = kill.z, t = kill.t })
            event.t, event.from = kill.t, kill.t
            events[#events + 1] = event
        end
        local tier = milestones[day.key]
        if tier then
            events[#events + 1] = {
                kind = "bond",
                big = true,
                title = L.ui_fellow_tier_up:format(ns.Lower(L["ui_bond_" .. tier])),
                t = to,
                from = to,
            }
        end
    end
    for _, event in ipairs(events) do
        if event.kind == "fellow" then
            local unnamed = event.unnamed
            local bosses = unnamed > 0 and ns.Plural("ui_fellow_bosses", unnamed):format(unnamed) or nil
            local span = event.timed and Span(event.from, event.t) or nil
            event.title = event.zone and L.ui_run_title:format(event.zone) or L.ui_fellow_together
            event.detail = span and bosses and (span .. "  ·  " .. bosses) or span or bosses
            event.unnamed, event.zone, event.timed = nil, nil, nil
        end
    end
    table.sort(events, function(a, b)
        return a.t > b.t
    end)
    local chapters = SessionChapters(events, now)
    local shown = FellowPerson(guid, person, now)
    -- Their own events are the chronicle's; the card leads there if it has any.
    shown.chronicle = ns:IsCategoryEnabled("chronicle") and ns.ChronicleService.Who(person.name) or nil
    return shown, chapters
end

-- A person has two books: their own events in the chronicle, and what you
-- did together among the fellow travellers. These lead from one to the other.
local function ShowChronicleOf(who)
    SelectPage("chronicle")
    selectedTabs.chronicle = "companions"
    chronicleWho = who
    Render()
end

local function ShowStoryOf(guid)
    SelectPage("fellows")
    selectedTabs.fellows = "overview"
    fellowStory = guid
    Render()
end

-- What the buttons on a fellow traveller's card do, in the overview and
-- beside their story.
FELLOW_ACTIONS = {
    onChronicle = ShowChronicleOf,
    onStory = function(guid)
        fellowStory = guid
        Render()
    end,
    onAlias = function(guid)
        for _, each in ipairs(ns.FellowService.List()) do
            if each.guid == guid then
                ns:EditAlias(each.person.name)
            end
        end
    end,
    -- The chat box opens with a whisper to them; they may be offline, then
    -- the game says so when it is sent.
    onWhisper = function(guid)
        local person = ns.FellowService.Person(guid)
        if person then
            ns.ChatService.Whisper(person.name)
        end
    end,
    onForget = function(guid)
        local name = ns.FellowService.Forget(guid)
        if name then
            ns:Notify(L.msg_fellow_forgotten:format(name))
        end
    end,
}

---------------------------------------------------------------------------
-- The timeline: every group you were in, the newest first, as a book. A
-- card per group (where, when, who, and how often the same people came
-- together again), the people you met and the bond tiers you reached. It
-- tells only who was together with whom; what happened is the chronicle's.
-- The rail beside it sums up the week.
---------------------------------------------------------------------------

local TIMELINE_ROWS = 50 -- events in the book; older groups stay in the saved data
local RUN_SHORT = 60 -- a group shorter than this, without a boss, is not told
local RUN_NOTE = 5 * 60 -- joined this much later or left this much earlier: the plate says when
local REGULAR_PEOPLE = 5 -- of a group, the first ones are looked at for coming together again
local TIMELINE_PEOPLE = 5 -- rows of the rail's list

local TIMELINE_EMPTY_ITEM = {
    kind = "info",
    label = function()
        return L.ui_run_empty
    end,
    desc = function()
        return L.ui_run_empty_desc
    end,
}

-- A person as the timeline names them: the alias, else the first name.
local function ShortName(person)
    return ns.AliasService.Get(person.name) or string.match(person.name, "^[^%s%-]+") or person.name
end

-- "Mira", "Mira and Borin", "Mira, Borin and Lysa"
local function JoinNames(names)
    if #names < 2 then
        return names[1] or ""
    end
    return L.c_and:format(table.concat(names, ", ", 1, #names - 1), names[#names])
end

-- From when to when someone was with a group; until now while it lasts.
local function Presence(run, guid, seen, open, now)
    if run == open and ns.FellowService.IsTogether(guid) then
        return seen.f, now
    end
    return seen.f, seen.l
end

-- The people of a group who are still on the list, the earliest first.
local function RunPeople(run, byGuid)
    local list = {}
    for guid, seen in pairs(run.who or {}) do
        if byGuid[guid] then
            list[#list + 1] = { guid = guid, seen = seen, person = byGuid[guid] }
        end
    end
    table.sort(list, function(a, b)
        if a.seen.f ~= b.seen.f then
            return a.seen.f < b.seen.f
        elseif a.seen.l ~= b.seen.l then
            return a.seen.l > b.seen.l
        end
        return (a.person.name .. a.guid) < (b.person.name .. b.guid)
    end)
    return list
end

-- The people of a set in the same order wherever they are named: the most
-- time together first.
local function ByTimeTogether(guids, data)
    local Fellows = ns.FellowService
    local seconds, list = {}, {}
    for index, guid in ipairs(guids) do
        list[index] = guid
        seconds[guid] = Fellows.Seconds(guid, data.byGuid[guid], data.now)
    end
    table.sort(list, function(a, b)
        if seconds[a] ~= seconds[b] then
            return seconds[a] > seconds[b]
        end
        return a < b
    end)
    return list
end

-- Every set of two or more of the people (of the first few), each with a
-- key that is the same whatever the order: { guids = {...}, key = "..." }.
local function Sets(people)
    local sets = {}
    local count = math.min(#people, REGULAR_PEOPLE)
    for mask = 1, 2 ^ count - 1 do
        local guids = {}
        for index = 1, count do
            if math.floor(mask / 2 ^ (index - 1)) % 2 == 1 then
                guids[#guids + 1] = people[index].guid
            end
        end
        if #guids >= 2 then
            local sorted = {}
            for index, guid in ipairs(guids) do
                sorted[index] = guid
            end
            table.sort(sorted)
            sets[#sets + 1] = { guids = guids, key = table.concat(sorted, "|") }
        end
    end
    return sets
end

-- Which set comes first: more often, then more people, then more time, then by key.
local function BetterSet(a, b)
    if not b then
        return true
    elseif a.count ~= b.count then
        return a.count > b.count
    elseif #a.guids ~= #b.guids then
        return #a.guids > #b.guids
    elseif (a.seconds or 0) ~= (b.seconds or 0) then
        return (a.seconds or 0) > (b.seconds or 0)
    end
    return a.key < b.key
end

-- What the book and the rail are made from: the groups, the people on the
-- list, and per group its people and the set of them that came together
-- most often so far. nil without any group.
local function TimelineData()
    local Fellows = ns.FellowService
    local runs, open = Fellows.Runs()
    if #runs == 0 then
        return nil
    end
    local now = time()
    local byGuid = {}
    for _, each in ipairs(Fellows.List()) do
        byGuid[each.guid] = each.person
    end
    local counts, told, metIn = {}, {}, {}
    for _, run in ipairs(runs) do
        local people = RunPeople(run, byGuid)
        local again
        if not run.raid then
            for _, set in ipairs(Sets(people)) do
                counts[set.key] = (counts[set.key] or 0) + 1
                set.count = counts[set.key]
                if set.count >= 2 and BetterSet(set, again) then
                    again = set
                end
            end
        end
        local finish = run == open and now or run.l
        -- A party with nobody left on the list (forgotten, tidied away) has nothing to tell.
        local known = run.raid or #people > 0
        if known and (finish - run.f >= RUN_SHORT or (tonumber(run.b) or 0) > 0) then
            told[#told + 1] = { run = run, finish = finish, people = people, again = again }
            -- Who was met in this group: their first time together is in it.
            for _, member in ipairs(people) do
                local first = tonumber(member.person.first)
                if first and first >= run.f - 60 and first <= finish + 60 then
                    metIn[member.guid] = run
                end
            end
        end
    end
    return { runs = runs, open = open, now = now, byGuid = byGuid, told = told, metIn = metIn }
end

-- When each person reached a new bond tier, as far as the groups tell: the
-- walk starts from the time before the first of them.
local function TierMoments(data)
    local Fellows = ns.FellowService
    local spans, order = {}, {}
    for _, run in ipairs(data.runs) do
        for guid, seen in pairs(run.who or {}) do
            if data.byGuid[guid] then
                local from, to = Presence(run, guid, seen, data.open, data.now)
                if not spans[guid] then
                    spans[guid] = {}
                    order[#order + 1] = guid
                end
                table.insert(spans[guid], { f = from, l = to })
            end
        end
    end
    table.sort(order)
    local moments = {}
    for _, guid in ipairs(order) do
        local list = spans[guid]
        local logged = 0
        for _, span in ipairs(list) do
            logged = logged + math.max(0, span.l - span.f)
        end
        local running = math.max(0, Fellows.Seconds(guid, data.byGuid[guid], data.now) - logged)
        local tier = Fellows.Tier(running)
        for _, span in ipairs(list) do
            local length = math.max(0, span.l - span.f)
            local nextAt = Fellows.TIERS[tier + 1]
            while nextAt and running + length >= nextAt do
                moments[#moments + 1] = { guid = guid, tier = tier + 1, t = span.f + (nextAt - running) }
                tier = tier + 1
                nextAt = Fellows.TIERS[tier + 1]
            end
            running = running + length
        end
    end
    return moments
end

-- A person's crest as the book shows it: where they stand on the way to the next tier.
local function CrestOf(guid, person, now)
    local Fellows = ns.FellowService
    local _, progress = Fellows.Tier(Fellows.Seconds(guid, person, now))
    return { name = person.name, class = person.class, progress = progress }
end

local function RunEvent(each, data)
    local run, finish = each.run, each.finish
    -- Each zone once, in the order it was first reached.
    local zones, seen = {}, {}
    for _, zone in ipairs(run.z or {}) do
        if not seen[zone] then
            seen[zone] = true
            zones[#zones + 1] = zone
        end
    end
    local where = #zones > 0 and JoinNames(zones) or nil
    local title
    if run.raid then
        title = where and L.ui_run_raid:format(where) or L.ui_run_raid_nowhere
    else
        title = where and L.ui_run_title:format(where) or L.ui_fellow_together
    end
    local parts = {
        run == data.open and L.ui_run_since:format(ns.FormatTime(run.f)) or Span(run.f, finish),
        Duration(finish - run.f) or L.ui_fellow_minutes:format(0),
    }
    if run.raid and run.n then
        parts[#parts + 1] = ns.Plural("ui_run_people", run.n):format(run.n)
    end
    local bosses = tonumber(run.b) or 0
    if bosses > 0 then
        parts[#parts + 1] = ns.Plural("ui_fellow_bosses", bosses):format(bosses)
    end
    -- A raid keeps only the number of people; a party says who, and who
    -- came later or left earlier.
    local plates
    if not run.raid then
        plates = {}
        for _, member in ipairs(each.people) do
            local from, to = Presence(run, member.guid, member.seen, data.open, data.now)
            local note
            if to < finish - RUN_NOTE then
                note = L.ui_run_until:format(ns.FormatTime(to))
            elseif from > run.f + RUN_NOTE then
                note = L.ui_run_from:format(ns.FormatTime(from))
            end
            plates[#plates + 1] = { name = ShortName(member.person), class = member.person.class, note = note }
        end
    end
    local foot
    if each.again then
        local names = {}
        for index, guid in ipairs(ByTimeTogether(each.again.guids, data)) do
            names[index] = ShortName(data.byGuid[guid])
        end
        foot = ns.Plural("ui_run_again", each.again.count):format(JoinNames(names), each.again.count)
    end
    return {
        kind = "fellow",
        noPicture = true,
        title = title,
        detail = table.concat(parts, "  ·  "),
        people = plates,
        foot = foot,
        t = finish,
        from = run.f,
        seconds = finish - run.f,
        rank = 1,
    }
end

local function MeetEvent(guid, person, data)
    local first = tonumber(person.first)
    local zone = type(person.firstZone) == "string" and person.firstZone or nil
    local level = tonumber(person.firstLevel)
    local detail = zone and level and L.ui_run_met_where_level:format(zone, level)
        or zone and L.c_in:format(zone) or level and L.ui_fellow_met_detail:format(level) or nil
    return {
        kind = "bond",
        title = L.ui_run_met:format(ShortName(person)),
        detail = detail,
        when = ns.FormatTime(first),
        crest = CrestOf(guid, person, data.now),
        onClick = function()
            ShowStoryOf(guid)
        end,
        t = first,
        from = first,
        rank = 3,
    }
end

local function TierEvent(moment, data)
    local person = data.byGuid[moment.guid]
    return {
        kind = "bond",
        big = moment.tier >= 3, -- like the badge: from Trusted on in the accent
        title = L.ui_run_tier:format(ShortName(person), ns.Lower(L["ui_bond_" .. moment.tier])),
        detail = L.ui_run_tier_detail:format(math.floor(ns.FellowService.TIERS[moment.tier] / 3600)),
        when = ns.FormatTime(moment.t),
        crest = CrestOf(moment.guid, person, data.now),
        onClick = function()
            ShowStoryOf(moment.guid)
        end,
        t = moment.t,
        from = moment.t,
        rank = 2,
    }
end

-- One chapter per session of play, as in the chronicle: a pause of
-- SESSION_GAP between the end of an event and the start of the chapter
-- begins the next. Returns nil if there is nothing to tell.
local function TimelineBook()
    local data = TimelineData()
    if not data then
        return nil
    end
    local events = {}
    for _, each in ipairs(data.told) do
        events[#events + 1] = RunEvent(each, data)
    end
    -- What the groups can tell: the people met in one of them, and the tiers reached.
    local since = data.runs[1].f
    for guid, person in pairs(data.byGuid) do
        if data.metIn[guid] then
            events[#events + 1] = MeetEvent(guid, person, data)
        end
    end
    for _, moment in ipairs(TierMoments(data)) do
        if moment.t >= since then
            events[#events + 1] = TierEvent(moment, data)
        end
    end
    if #events == 0 then
        return nil
    end
    table.sort(events, function(a, b)
        if a.t ~= b.t then
            return a.t > b.t
        elseif a.rank ~= b.rank then
            return a.rank < b.rank
        end
        return a.title < b.title
    end)
    local chapters, more = SessionChapters(events, data.now, TIMELINE_ROWS)
    return chapters, more and L.ui_run_more or nil
end

-- The week beside the book: the time in groups and what came of it, the
-- group that came together most often, and with whom you spent the most time.
local function TimelineRail()
    local data = TimelineData()
    if not data then
        return nil
    end
    local Fellows = ns.FellowService
    local since = data.now - WEEK
    local total, count, perPerson, sets, best = 0, 0, {}, {}, nil
    for _, each in ipairs(data.told) do
        local run, finish = each.run, each.finish
        if finish >= since then
            local length = finish - math.max(run.f, since)
            total, count = total + length, count + 1
            for _, member in ipairs(each.people) do
                local from, to = Presence(run, member.guid, member.seen, data.open, data.now)
                perPerson[member.guid] = (perPerson[member.guid] or 0) + math.max(0, to - math.max(from, since))
            end
            if not run.raid then
                for _, set in ipairs(Sets(each.people)) do
                    local entry = sets[set.key]
                    if not entry then
                        entry = { guids = set.guids, key = set.key, count = 0, seconds = 0 }
                        sets[set.key] = entry
                    end
                    entry.count, entry.seconds = entry.count + 1, entry.seconds + length
                end
            end
        end
    end
    for _, entry in pairs(sets) do
        if entry.count >= 2 and BetterSet(entry, best) then
            best = entry
        end
    end
    local people = {}
    for guid in pairs(perPerson) do
        people[#people + 1] = guid
    end
    table.sort(people, function(a, b)
        if perPerson[a] ~= perPerson[b] then
            return perPerson[a] > perPerson[b]
        end
        return a < b
    end)
    local met, tiers = 0, 0
    for guid in pairs(data.metIn) do
        local first = tonumber(data.byGuid[guid].first)
        if first and first >= since then
            met = met + 1
        end
    end
    for _, moment in ipairs(TierMoments(data)) do
        if moment.t >= since then
            tiers = tiers + 1
        end
    end
    local cards = {
        {
            kind = "stats",
            title = L.c_week,
            stats = {
                { value = Duration(total) or L.ui_fellow_minutes:format(0), label = L.ui_run_week_time, wide = true },
                { value = tostring(count), label = L.ui_run_week_runs },
                { value = tostring(#people), label = L.ui_run_week_people },
                { value = tostring(met), label = L.ui_run_week_met },
                { value = tostring(tiers), label = L.ui_run_week_tiers },
            },
        },
    }
    if best then
        local crests, names = {}, {}
        for index, guid in ipairs(ByTimeTogether(best.guids, data)) do
            local person = data.byGuid[guid]
            crests[index] = CrestOf(guid, person, data.now)
            names[index] = ShortName(person)
        end
        cards[#cards + 1] = {
            kind = "group",
            title = L.ui_run_regular,
            note = L.ui_run_regular_count:format(best.count),
            people = crests,
            names = JoinNames(names),
            line = L.ui_fellow_day_time:format(Duration(best.seconds) or L.ui_fellow_minutes:format(0)),
            text = L.ui_run_regular_desc,
        }
    end
    if #people > 0 then
        local rows = {}
        for index = 1, math.min(TIMELINE_PEOPLE, #people) do
            local guid = people[index]
            local person = data.byGuid[guid]
            local tier = Fellows.Tier(Fellows.Seconds(guid, person, data.now))
            rows[index] = {
                key = guid,
                initial = UI.Initial(person.name),
                class = person.class,
                name = ns.AliasService.Get(person.name) or person.name,
                line = L["ui_bond_" .. tier],
                level = Duration(perPerson[guid]) or L.ui_fellow_minutes:format(0),
            }
        end
        cards[#cards + 1] = {
            kind = "people",
            title = L.ui_run_most,
            note = L.ui_run_most_note,
            people = rows,
            onSelect = ShowStoryOf,
        }
    end
    return cards
end

---------------------------------------------------------------------------
-- Nearby: friends and guild who are online right now, the ones in the
-- player's zone first, then those of a similar level, then everyone else;
-- beside it, the zones they are in. Only while "Who is nearby" runs: it
-- keeps the lists fresh.
---------------------------------------------------------------------------

local FellowNearbyTab
do
    local NEAR_SIMILAR = 5 -- levels apart that still count as similar
    local NEAR_ROWS = 40 -- rows of "Also online"; the rest are counted
    local NEAR_PLACES = 8 -- zones in the rail
    
    local NEAR_OFF_ITEM = {
        kind = "info",
        label = function()
            return L.ui_near_off
        end,
        desc = function()
            return L.ui_near_off_desc
        end,
    }
    
    local NEAR_EMPTY_ITEM = {
        kind = "info",
        label = function()
            return L.ui_near_empty
        end,
        desc = function()
            return L.ui_near_empty_desc
        end,
    }
    
    -- One look per render: blocks, list and rail all ask for it.
    local nearbyLook
    
    local function NearbyData()
        local feature = ns.features.nearbyFriends
        if not (feature and feature.enabled) then
            return nil
        end
        local at = GetTime()
        if nearbyLook and nearbyLook.at == at then
            return nearbyLook
        end
        local Nearby = ns.NearbyService
        Nearby.Ask()
        local people, here, level = Nearby.People(feature:Get("guild"))
        local list = {}
        for _, person in ipairs(people) do
            -- Whoever is in the group is with the player anyway.
            if not person.grouped then
                list[#list + 1] = person
            end
        end
        nearbyLook = { at = at, people = list, here = here, level = level, now = time() }
        return nearbyLook
    end
    
    local function LevelApart(person, data)
        if not (person.level and data.level) then
            return 1000
        end
        return math.abs(person.level - data.level)
    end
    
    local function NearPerson(person, data)
        local tier, progress, seconds, guid = ns.NearbyService.Bond(person, data.now)
        local alias = ns.AliasService.Get(person.name)
        local parts = {}
        if alias then
            parts[#parts + 1] = person.name
        end
        parts[#parts + 1] = ClassName(person.class)
        parts[#parts + 1] = L["ui_near_from_" .. person.from]
        local diff
        if person.level and data.level and person.level ~= data.level then
            diff = (person.level > data.level and "+" or "−") .. math.abs(person.level - data.level)
        end
        return {
            name = person.name,
            label = alias or person.name,
            sub = table.concat(parts, "  ·  "),
            class = person.class,
            progress = progress or 0,
            tier = tier,
            seconds = seconds or -1,
            guid = guid,
            level = person.level and tostring(person.level) or "",
            diff = diff,
            place = person.zone or L.ui_near_nowhere,
            here = data.here ~= nil and person.zone == data.here,
            apart = LevelApart(person, data),
            source = person,
        }
    end
    
    -- The closest bond first, then the nearest level, then by name.
    local function NearOrder(a, b)
        if a.seconds ~= b.seconds then
            return a.seconds > b.seconds
        elseif a.apart ~= b.apart then
            return a.apart < b.apart
        end
        return a.label < b.label
    end
    
    local function NearbyModel()
        local data = NearbyData()
        if not data or #data.people == 0 then
            return nil
        end
        local here, similar, others = {}, {}, {}
        for _, person in ipairs(data.people) do
            local row = NearPerson(person, data)
            if row.here then
                here[#here + 1] = row
            elseif row.apart <= NEAR_SIMILAR then
                similar[#similar + 1] = row
            else
                others[#others + 1] = row
            end
        end
        table.sort(here, NearOrder)
        table.sort(similar, NearOrder)
        table.sort(others, function(a, b)
            if a.apart ~= b.apart then
                return a.apart < b.apart
            end
            return a.label < b.label
        end)
        local sections = {}
        if #here > 0 then
            sections[#sections + 1] = { title = L.ui_near_section_here:format(data.here), note = tostring(#here), people = here }
        end
        if #similar > 0 then
            sections[#sections + 1] = {
                title = L.ui_near_section_similar,
                note = tostring(#similar) .. "  ·  " .. ns.Plural("ui_near_similar_note", NEAR_SIMILAR):format(NEAR_SIMILAR),
                people = similar,
            }
        end
        if #others > 0 then
            local shown, more = others, nil
            if #others > NEAR_ROWS then
                shown = {}
                for index = 1, NEAR_ROWS do
                    shown[index] = others[index]
                end
                more = ns.Plural("ui_near_others", #others - NEAR_ROWS):format(#others - NEAR_ROWS)
            end
            sections[#sections + 1] = { title = L.ui_near_section_others, note = tostring(#others), people = shown, more = more }
        end
        return {
            sections = sections,
            onChoose = function(person)
                if person.guid then
                    ShowStoryOf(person.guid)
                end
            end,
            onWhisper = function(person)
                ns.NearbyService.Whisper(person.source)
            end,
        }
    end
    
    -- The zones the people are in: the player's own first, then the fullest.
    local function NearbyRail()
        local data = NearbyData()
        if not data or #data.people == 0 then
            return nil
        end
        local byZone, zones = {}, {}
        for _, person in ipairs(data.people) do
            local name = person.zone or L.ui_near_nowhere
            local zone = byZone[name]
            if not zone then
                zone = { name = name, count = 0, here = data.here ~= nil and person.zone == data.here }
                byZone[name] = zone
                zones[#zones + 1] = zone
            end
            zone.count = zone.count + 1
            if person.level then
                zone.low = math.min(zone.low or person.level, person.level)
                zone.high = math.max(zone.high or person.level, person.level)
            end
        end
        table.sort(zones, function(a, b)
            if a.here ~= b.here then
                return a.here
            elseif a.count ~= b.count then
                return a.count > b.count
            end
            return a.name < b.name
        end)
        local places = {}
        for index = 1, math.min(#zones, NEAR_PLACES) do
            local zone = zones[index]
            local line
            if zone.low and zone.low == zone.high then
                line = L.c_p_level:format(zone.low)
            elseif zone.low then
                line = L.ui_near_range:format(zone.low, zone.high)
            end
            places[index] = { name = zone.name, line = line, count = zone.count, here = zone.here }
        end
        return {
            {
                kind = "places",
                title = L.ui_near_places,
                note = ns.Plural("ui_near_places_note", #data.people):format(#data.people),
                places = places,
                more = #zones > NEAR_PLACES and ns.Plural("ui_near_places_more", #zones - NEAR_PLACES):format(#zones - NEAR_PLACES) or nil,
            },
        }
    end
    
    function FellowNearbyTab()
        return {
            id = "nearby",
            category = "fellows",
            label = function()
                return L.ui_tab_nearby
            end,
            desc = function()
                return L.ui_tab_nearby_desc
            end,
            settings = {},
            -- The list is drawn by UI.NearbyList; a card only says why it is empty.
            blocks = function()
                local data = NearbyData()
                if not data then
                    return { { items = { NEAR_OFF_ITEM } } }
                elseif #data.people == 0 then
                    return { { items = { NEAR_EMPTY_ITEM } } }
                end
                return {}
            end,
            nearby = NearbyModel,
            rail = NearbyRail,
            -- The search finds the people on the overview, not here.
            search = function()
                return {}
            end,
        }
    end
end

local function FellowTimelineTab()
    return {
        id = "timeline",
        category = "fellows",
        label = function()
            return L.ui_tab_timeline
        end,
        desc = function()
            return L.ui_tab_timeline_desc
        end,
        settings = {},
        -- The groups are told as a book; a card only says that it is empty.
        blocks = function()
            if TimelineBook() then
                return {}
            end
            return { { items = { TIMELINE_EMPTY_ITEM } } }
        end,
        book = TimelineBook,
        rail = TimelineRail,
        -- The search finds the people on the overview, not here again.
        search = function()
            return {}
        end,
    }
end

-- The overview's model: the three with the most time together, everyone
-- else sorted by the chosen order, and the person on the card.
local function FellowModel()
    local list, now = ns.FellowService.List(), time()
    if #list == 0 then
        return nil
    end
    table.sort(list, function(a, b)
        return ByTime(a, b, now)
    end)
    local model = { top = {}, rest = {}, more = 0, sort = fellowSort }
    local others = {}
    for index, each in ipairs(list) do
        if index <= 3 then
            model.top[index] = FellowPerson(each.guid, each.person, now)
        else
            others[#others + 1] = each
        end
    end
    table.sort(others, function(a, b)
        if fellowSort == "time" then
            return ByTime(a, b, now)
        end
        return ByLast(a, b)
    end)
    for index, each in ipairs(others) do
        if index > FELLOW_ROWS then
            model.more = #others - FELLOW_ROWS
            break
        end
        model.rest[index] = FellowPerson(each.guid, each.person, now)
    end
    model.sortValues = {
        { value = "last", text = L.ui_fellow_sort_last },
        { value = "time", text = L.ui_fellow_sort_time },
    }
    model.onChoose = FELLOW_ACTIONS.onStory -- a click opens the person's story
    model.onSort = function(value)
        fellowSort = value
        Render()
    end
    for key, action in pairs(FELLOW_ACTIONS) do
        model[key] = action
    end
    return model
end

-- The overview tab: tiles, list and card, drawn by UI.FellowOverview. The
-- search looks through everyone as plain person rows.
local function FellowOverviewTab()
    return {
        id = "overview",
        category = "fellows",
        label = function()
            return L.ui_tab_overview
        end,
        desc = function()
            return L.ui_tab_overview_desc
        end,
        settings = {},
        overview = FellowModel,
        blocks = function()
            if ns.FellowService.Count() == 0 then
                return { { items = { FELLOW_EMPTY_ITEM } } }
            end
            return {}
        end,
        search = function()
            local list, items = ns.FellowService.List(), {}
            for _, each in ipairs(list) do
                items[#items + 1] = FellowItem(each.guid, each.person)
            end
            return { { items = items } }
        end,
    }
end

-- Tidying up: whoever on the list is neither a friend nor in the guild,
-- or no longer, goes in one go. The row names them; like reset, the button
-- asks first.
local TIDY_NAMES = 5 -- names the row lists; the others it counts
local tidyShown -- the GUIDs the row counted when its button was armed

-- shown: the outsiders the row counts right now.
local function TidyClicked(shown)
    if not tidyArmed then
        tidyShown = {}
        for _, each in ipairs(shown) do
            tidyShown[each.guid] = true
        end
        tidyArmed = true
        tidyToken = tidyToken + 1
        local token = tidyToken
        C_Timer.After(4, function()
            if token == tidyToken and tidyArmed then
                tidyArmed = false
                RefreshState(false)
            end
        end)
        RefreshState(false)
        return
    end
    tidyArmed = false
    -- A fresh look: the list on screen may be a while old. If a list has
    -- gone missing since (Battle.net lost, say), nobody goes, and the row
    -- says what it waits for. Otherwise only who was counted when asking
    -- goes, and only if still no friend: never someone the row did not
    -- count.
    local check, ready = ns.SocialService.Circle()
    if not ready then
        Render()
        return
    end
    local removed = ns.FellowService.RemoveOutsiders(check, tidyShown or {})
    if removed > 0 then
        ns:Notify(ns.Plural("msg_fellow_tidied", removed):format(removed))
    end
    RefreshState(false)
end

-- What the row says while a list it compares with is not there yet.
local TIDY_WAIT = {
    friends = "ui_fellow_tidy_wait_friends",
    guild = "ui_fellow_tidy_wait_guild",
    battlenet = "ui_fellow_tidy_wait_battlenet",
}

local function TidyItem()
    -- Worked out once, when the row is shown: building the tab's blocks
    -- (the search does that for every tab, on every key) stays cheap and
    -- asks the client for no list.
    local ready, waiting, outsiders
    local function Look()
        if outsiders == nil then
            local check
            check, ready, waiting = ns.SocialService.Circle()
            outsiders = ready and ns.FellowService.Outsiders(check) or {}
        end
        return outsiders
    end
    return {
        kind = "action",
        id = "tidy",
        icon = "trash",
        preview = "tidy",
        label = function()
            return L.ui_fellow_tidy
        end,
        desc = function()
            Look()
            if not ready then
                return L[TIDY_WAIT[waiting]]
            elseif #outsiders == 0 then
                return L.ui_fellow_tidy_none
            end
            local names = {}
            for index = 1, math.min(#outsiders, TIDY_NAMES) do
                local person = outsiders[index].person
                names[index] = ns.AliasService.Get(person.name) or person.name
            end
            local list = table.concat(names, ", ")
            if #outsiders > TIDY_NAMES then
                local more = #outsiders - TIDY_NAMES
                list = ns.Plural("ui_fellow_tidy_more", more):format(list, more)
            end
            return ns.Plural("ui_fellow_tidy_some", #outsiders):format(#outsiders, list)
        end,
        -- The search looks for the deed, not for the names it lists.
        find = function()
            return L.ui_fellow_tidy .. " " .. L.ui_fellow_tidy_title .. " " .. L.ui_fellow_tidy_button
        end,
        button = function()
            return L.ui_fellow_tidy_button
        end,
        confirm = function()
            return L.ui_fellow_tidy_confirm
        end,
        armed = function()
            return tidyArmed
        end,
        usable = function()
            return #Look() > 0
        end,
        click = function()
            TidyClicked(Look())
        end,
    }
end

function layouts.fellows()
    local record = CategoryTab("fellows")
    record.id = "record"
    record.label = function()
        return L.ui_tab_record
    end
    record.desc = function()
        return L.ui_fellows_record_desc
    end
    -- Below the switches, an entry to tidy the list up. It works on what is
    -- stored, so it stays while remembering is switched off.
    local switches = record.blocks
    record.blocks = function()
        local blocks = {}
        for index, block in ipairs(switches()) do
            blocks[index] = block
        end
        blocks[#blocks + 1] = { title = L.ui_fellow_tidy_title, items = { TidyItem() } }
        return blocks
    end
    return {
        FellowOverviewTab(),
        FellowTimelineTab(),
        FellowNearbyTab(),
        record,
    }
end

local function BuildPages()
    for _, area in ipairs(ns.areas) do
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
            tabs = layouts[area.id](),
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
        InfoItem("commands", function()
            return L.about_commands_value
        end),
        InfoItem("idea", function()
            return L.about_idea_value
        end),
        -- The welcome page once more, to switch the main features on later.
        {
            kind = "action",
            id = "welcome",
            label = function()
                return L.about_welcome
            end,
            desc = function()
                return L.about_welcome_value
            end,
            button = function()
                return L.about_welcome_button
            end,
            confirm = function()
                return L.about_welcome_button
            end,
            armed = function()
                return false
            end,
            usable = function()
                return true
            end,
            click = function()
                OpenWelcome()
            end,
        },
        -- What helps to find a bug, ready to copy into an issue (UI/Report.lua).
        {
            kind = "action",
            id = "report",
            label = function()
                return L.about_report
            end,
            desc = function()
                return L.about_report_value
            end,
            button = function()
                return L.about_report_button
            end,
            confirm = function()
                return L.about_report_button
            end,
            armed = function()
                return false
            end,
            usable = function()
                return true
            end,
            click = function()
                ns:ShowBugReport()
            end,
        },
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
    query = ns.Lower(query)
    local blocks, total = {}, 0
    for _, id in ipairs(pageOrder) do
        local page = pages[id]
        local pageTitle = page.title()
        for _, tab in ipairs(page.tabs) do
            -- A switched-off feature is left out; its switch in the settings is not.
            if not tab.category or ns:IsCategoryEnabled(tab.category) then
                local where = pageTitle
                if #page.tabs > 1 then
                    where = pageTitle .. "  ·  " .. tab.label()
                end
                local context = ns.Lower(where)
                local hits = {}
                -- A tab that shows only part of a long list searches all of it.
                for _, block in ipairs(tab.search and tab.search() or tab.blocks()) do
                    for _, item in ipairs(block.items) do
                        if item.kind ~= "info" and item.kind ~= "aliasEdit" then
                            -- An item whose help text changes (a list of names) says what to search in.
                            local text = item.find and item.find() or (item.label() .. " " .. item.desc())
                            local haystack = ns.Lower(text) .. " " .. context
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
    end
    return blocks, total
end

---------------------------------------------------------------------------
-- Rows
---------------------------------------------------------------------------

-- The text of a select's value: the chosen one, or the one given.
local function ValueText(item, current)
    if current == nil then
        current = item.get()
    end
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
    elseif kind == "swatch" then
        row.swatches:SetValues(item.values(), item.get())
    elseif kind == "info" then
        row.desc:SetText(item.desc())
    elseif kind == "action" then
        local armed = item.armed()
        row.action:SetLabel(armed and item.confirm() or item.button())
        row.action:SetTone(armed and "danger" or nil)
        row.action:SetDisabled(not item.usable())
    end
end

local function EnsureControls(row, kind)
    if kind == "toggle" and not row.toggle then
        row.toggle = UI.Toggle(row)
        row.toggle:SetPoint("RIGHT", -18, 0)
    elseif kind == "select" and not row.dropdown then
        row.dropdown = UI.Dropdown(row)
        row.dropdown:SetPoint("RIGHT", -18, 0)
    elseif kind == "swatch" and not row.swatches then
        row.swatches = UI.Swatches(row, function(value)
            row.item.set(value)
        end)
        row.swatches:SetPoint("RIGHT", -14, 0)
    elseif kind == "aliasEdit" and not row.editor then
        row.editor = CreateAliasEditor(row)
    elseif kind == "action" and not row.action then
        row.action = UI.Button(row, function()
            row.item.click()
        end)
        row.action:SetPoint("RIGHT", -18, 0)
    elseif PERSON_ROWS[kind] and not row.remove then
        row.remove = UI.IconButton(row, "close", function()
            row.item.remove()
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
        swatch = row.swatches,
        aliasEdit = row.editor,
        action = row.action,
    }
    for controlKind, control in pairs(controls) do
        if control then
            control:SetShown(controlKind == kind)
        end
    end
    if row.avatar then
        local person = PERSON_ROWS[kind] == true
        row.remove:SetShown(person)
        row.avatar:SetShown(person)
        row.initial:SetShown(person)
    end
end

local function ControlWidth(row, kind)
    if kind == "toggle" then
        return 34
    elseif kind == "select" then
        return row.dropdown:GetWidth()
    elseif kind == "swatch" then
        return row.swatches:GetWidth()
    elseif kind == "action" then
        return row.actionWidth
    elseif PERSON_ROWS[kind] then
        return 26
    end
    return 0
end

-- index: of the row in its card. width: of the card.
local function RowSetItem(row, item, index, width)
    row.item = item
    row:SetWidth(width)
    local kind = item.kind
    EnsureControls(row, kind)
    if kind == "aliasEdit" then
        aliasEditor = row.editor
        aliasEditor:Relabel()
    elseif kind == "swatch" then
        RowRefresh(row, false) -- sizes the control before the text is laid out
    elseif kind == "action" then
        -- Room for the longer of the button's two labels, so that asking
        -- does not push it over the text.
        row.action:SetLabel(item.confirm())
        local wide = row.action:GetWidth()
        row.action:SetLabel(item.button())
        row.actionWidth = math.max(wide, row.action:GetWidth())
    end

    local indent = PERSON_ROWS[kind] and 58 or 18
    local padding = 15
    local controlWidth = ControlWidth(row, kind)
    local textWidth = width - indent - 18 - controlWidth - (controlWidth > 0 and 24 or 0)

    if PERSON_ROWS[kind] then
        row.initial:SetText(Initial(item.label()))
    end

    row.label:ClearAllPoints()
    row.label:SetPoint("TOPLEFT", indent, -padding)
    row.label:SetWidth(textWidth)
    row.label:SetText(item.label())

    local note = item.note and item.note()
    row.desc:SetWidth(textWidth)
    row.desc:SetText(note or item.desc())
    UI.Ink(row.desc, note and "warning" or "textMuted")

    local height
    if kind == "aliasEdit" then
        height = 64
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
    if row.disabled or kind == "info" or kind == "swatch" or kind == "action" then
        return
    end
    if PERSON_ROWS[kind] then
        item.open()
    elseif kind == "toggle" then
        item.set(not item.get())
    elseif kind == "select" then
        UI.OpenMenu(row.dropdown, item.values(), item.get(), item.set)
    end
end

local HOVERLESS = { info = true, aliasEdit = true, swatch = true, action = true }

local function CreateRow(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetWidth(CONTENT_W)
    row:SetFrameLevel(parent:GetFrameLevel() + 3)

    row.hover = UI.Round(row, "hover", 8, { inset = 4 })
    row.hover:Hide()

    -- The line above every row but a card's first.
    row.divider = UI.Line(row)
    row.divider:SetPoint("TOPLEFT", 18, 0)
    row.divider:SetPoint("TOPRIGHT", -18, 0)

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

    card.title = UI.Text(card, 12, "textDim", "semibold")
    card.title:SetPoint("BOTTOMLEFT", card, "TOPLEFT", 4, 9)
    card.note = UI.Text(card, 12, "textMuted", "medium")
    card.note:SetPoint("BOTTOMRIGHT", card, "TOPRIGHT", -4, 9)
    card.note:SetJustifyH("RIGHT")
    return card
end

---------------------------------------------------------------------------
-- Settings tabs: the entries on the left, the chosen one in full on the
-- right: its picture (if it has one), its text and its options. An entry
-- is an item that is no option of another; the options that follow it
-- belong to it. A block of its own, so that its names stay inside it.
---------------------------------------------------------------------------

do
    local LIST_W, SPLIT_GAP = 296, 20
    local DETAIL_W = CONTENT_W - LIST_W - SPLIT_GAP
    local ENTRY_H, ENTRY_GAP, ENTRY_TITLE = 56, 4, 24
    local ICON_TILE, ENTRY_TEXT = 30, 54 -- the icon's tile; where the name begins
    local DETAIL_PAD, PICTURE_H = 24, 196
    local CHIP_H, CHIP_GAP, CHIP_COLUMNS = 34, 8, 3

    local entryFrames, entryTitles, detailRows = {}, {}, {}
    local chosenEntries = {} -- page:tab -> id of the entry shown in full
    local ChooseEntry

    local function SplitEntries(tab)
        local list = {}
        for _, block in ipairs(tab.blocks()) do
            for index, item in ipairs(block.items) do
                local last = list[#list]
                if item.child and last then
                    last.options[#last.options + 1] = item
                else
                    list[#list + 1] = { item = item, options = {}, title = index == 1 and block.title or nil }
                end
            end
        end
        return list
    end

    local function IsDisabled(item)
        return item.disabled ~= nil and item.disabled() or false
    end

    -- Below an entry's name: why it cannot run, if so; for a switch whether
    -- it is on and how many options it has; otherwise what it does.
    local function EntrySub(entry)
        local item = entry.item
        local note = item.note and item.note()
        if note then
            return note, "warning"
        end
        if item.kind ~= "toggle" then
            return item.desc(), "textMuted"
        end
        local state = item.get() and L.ui_state_on or L.ui_state_off
        local count = #entry.options
        if count > 0 then
            return ns.Plural("ui_entry_options", count):format(state, count), "textMuted"
        end
        return state, "textMuted"
    end

    local function EntryRefresh(frame, animate)
        local item = frame.entry.item
        local kind = item.kind
        local alpha = IsDisabled(item) and 0.45 or 1
        frame.label:SetText(item.label())
        frame.label:SetAlpha(alpha)
        local sub, token = EntrySub(frame.entry)
        frame.sub:SetText(sub)
        UI.Ink(frame.sub, token)

        frame.toggle:SetShown(kind == "toggle")
        frame.switch:SetShown(kind == "toggle")
        frame.value:SetShown(kind == "select")
        frame.dot:SetShown(kind == "swatch")
        local right = 0
        if kind == "toggle" then
            frame.toggle:Set(item.get(), animate)
            frame.toggle:SetAlpha(alpha)
            right = 34
        elseif kind == "select" then
            frame.value:SetText(ValueText(item))
            right = math.min(110, math.ceil(frame.value:GetStringWidth()) + 2)
            frame.value:SetWidth(right)
        elseif kind == "swatch" then
            frame.dot:SetVertexColor(UI.AccentSwatch(item.get()))
            right = 14
        end
        local width = LIST_W - ENTRY_TEXT - 14 - (right > 0 and right + 12 or 0)
        frame.label:SetWidth(width)
        frame.sub:SetWidth(width)

        -- Its icon, in the accent while it runs.
        local on = kind == "toggle" and item.get() == true and alpha == 1
        frame.icon:SetTexture(UI.media[item.icon] or UI.media.sparkle)
        UI.Tint(frame.icon, on and "accent" or "textMuted")
        frame.tile:SetColor(on and "accentSoft" or "control")
        frame.icon:SetAlpha(alpha)

        -- The chosen entry lies on a card, with the accent mark at its left.
        frame.ground.border:SetShown(frame.chosen)
        frame.ground.fill:SetShown(frame.chosen)
        frame.mark:SetShown(frame.chosen)
    end

    -- An entry of the list: name, a line below it and, at the right, its
    -- switch, its value or its colour. A click chooses it; the switch has a
    -- hit area of its own.
    local function CreateEntry(parent)
        local entry = CreateFrame("Button", nil, parent)
        entry:SetSize(LIST_W, ENTRY_H)
        entry:SetFrameLevel(parent:GetFrameLevel() + 2)
        entry.ground = UI.Card(entry, "card", "cardBorder", 9)
        entry.hover = UI.Round(entry, "hover", 9, { sublevel = 3 })
        entry.hover:Hide()
        entry.mark = entry:CreateTexture(nil, "BORDER")
        entry.mark:SetPoint("TOPLEFT", 0, -16)
        entry.mark:SetPoint("BOTTOMLEFT", 0, 16)
        entry.mark:SetWidth(2)
        UI.Paint(entry.mark, "accent")

        -- The icon on a small tile in front of the name.
        local tile = CreateFrame("Frame", nil, entry)
        tile:SetSize(ICON_TILE, ICON_TILE)
        tile:SetPoint("LEFT", 12, 0)
        entry.tile = UI.Round(tile, "control", 8)
        entry.icon = UI.Icon(tile, "sparkle", 16, "textMuted")
        entry.icon:SetPoint("CENTER")

        entry.label = UI.Text(entry, 13, "text", "medium")
        entry.label:SetPoint("TOPLEFT", ENTRY_TEXT, -11)
        entry.label:SetWordWrap(false)
        entry.sub = UI.Text(entry, 11, "textMuted")
        entry.sub:SetPoint("TOPLEFT", entry.label, "BOTTOMLEFT", 0, -5)
        entry.sub:SetWordWrap(false)

        entry.toggle = UI.Toggle(entry)
        entry.toggle:SetPoint("RIGHT", -14, 0)
        entry.switch = CreateFrame("Button", nil, entry)
        entry.switch:SetSize(56, ENTRY_H)
        entry.switch:SetPoint("RIGHT")
        entry.switch:SetScript("OnClick", function()
            local item = entry.entry.item
            if not IsDisabled(item) then
                item.set(not item.get())
            end
        end)
        entry.value = UI.Text(entry, 12, "textDim", "medium")
        entry.value:SetPoint("RIGHT", -14, 0)
        entry.value:SetJustifyH("RIGHT")
        entry.value:SetJustifyV("MIDDLE")
        entry.value:SetWordWrap(false)
        entry.dot = UI.Icon(entry, "circle", 14)
        entry.dot:SetPoint("RIGHT", -16, 0)

        entry:SetScript("OnEnter", function(self)
            if not self.chosen then
                self.hover:Fade(true)
            end
        end)
        entry:SetScript("OnLeave", function(self)
            self.hover:Fade(false)
        end)
        entry:SetScript("OnClick", function(self)
            ChooseEntry(self.entry.item.id)
        end)
        return entry
    end

    -- The control at the right of the chosen entry's name, and its width.
    local function DetailControl(detail, kind)
        local item = detail.current
        detail.toggle:SetShown(kind == "toggle")
        detail.switch:SetShown(kind == "toggle")
        detail.dropdown:SetShown(kind == "select")
        detail.swatches:SetShown(kind == "swatch")
        detail.action:SetShown(kind == "action")
        if kind == "toggle" then
            return detail.toggle, 34
        elseif kind == "select" then
            return detail.dropdown, detail.dropdown:GetWidth()
        elseif kind == "swatch" then
            detail.swatches:SetValues(item.values(), item.get())
            return detail.swatches, detail.swatches:GetWidth()
        elseif kind == "action" then
            -- Room for the longer of its two labels.
            detail.action:SetLabel(item.confirm())
            local wide = detail.action:GetWidth()
            detail.action:SetLabel(item.button())
            return detail.action, math.max(wide, detail.action:GetWidth())
        end
        return nil, 0
    end

    -- Whether the chosen entry is on, and its default. True if there is one.
    local function DetailPills(detail)
        local item = detail.current
        local first, second = detail.pills[1], detail.pills[2]
        local default = item.default and item.default()
        first:Hide()
        second:Hide()
        if item.kind == "toggle" then
            local on = item.get() == true
            first:Set(on and L.ui_state_on or L.ui_state_off, on and not IsDisabled(item))
            second:Set(default and L.ui_default_on or L.ui_default_off, false)
            first:Show()
            second:Show()
        elseif item.kind == "select" and default ~= nil then
            first:Set(L.ui_default_value:format(ValueText(item, default)), false)
            first:Show()
        end
        return first:IsShown()
    end

    -- Refreshes the chosen entry's controls, pills and chips in place.
    local function RefreshDetail(animate)
        local detail = window.detail
        if not detail or not detail:IsShown() or not detail.current then
            return
        end
        local item = detail.current
        local alpha = IsDisabled(item) and 0.45 or 1
        if item.kind == "toggle" then
            detail.toggle:Set(item.get(), animate)
            detail.toggle:SetAlpha(alpha)
        elseif item.kind == "select" then
            detail.dropdown.text:SetText(ValueText(item))
            detail.dropdown:SetAlpha(alpha)
        elseif item.kind == "swatch" then
            detail.swatches:SetValues(item.values(), item.get())
        elseif item.kind == "action" then
            local armed = item.armed()
            detail.action:SetLabel(armed and item.confirm() or item.button())
            detail.action:SetTone(armed and "danger" or nil)
            detail.action:SetDisabled(not item.usable())
        end
        DetailPills(detail)
        UI.Previews.Refresh(detail.stage)
        local on, total = 0, 0
        for _, chip in ipairs(detail.chips) do
            if chip:IsShown() then
                local option = chip.option
                chip:Set(option.label(), option.icon, option.get(), IsDisabled(option))
                total = total + 1
                on = on + (option.get() and 1 or 0)
            end
        end
        detail.chipsCount:SetText(L.ui_chips_count:format(on, total))
    end

    -- A chip switches its option; pointed at, the line below the chips
    -- explains it, and the picture may show it.
    local function NewChip(detail)
        local chip = UI.Chip(detail.scroll.content, function(self)
            self.option.set(not self.option.get())
        end)
        chip.onEnter = function(self)
            detail.hint:SetText(self.option.desc())
            UI.Previews.Focus(detail.stage, self.option.optionKey)
        end
        chip.onLeave = function()
            detail.hint:SetText(detail.hintText or "")
            UI.Previews.Focus(detail.stage, nil)
        end
        detail.chips[#detail.chips + 1] = chip
        return chip
    end

    -- Lays out the right part of a settings tab for one entry: its picture
    -- (if it has one), name and control, whether it is on and its default, its
    -- text, then its options: rows with their help text, a group as chips.
    local function ShowEntry(entry)
        local detail, item = window.detail, entry.item
        detail.current = item
        local body = detail.scroll.content
        local width = DETAIL_W - 2 * DETAIL_PAD
        local y = DETAIL_PAD - 2

        if UI.Previews.Show(detail.stage, item.preview) then
            y = DETAIL_PAD + PICTURE_H + 20
        end

        -- Above the name, where it belongs: the page's name.
        detail.crumb:ClearAllPoints()
        detail.crumb:SetPoint("TOPLEFT", body, "TOPLEFT", DETAIL_PAD, -y)
        detail.crumb:SetWidth(width)
        detail.crumb:SetText(pages[currentPage].title())
        y = y + 20

        -- The control sits on the middle of the name's first line.
        local control, controlWidth = DetailControl(detail, item.kind)
        detail.title:ClearAllPoints()
        detail.title:SetPoint("TOPLEFT", body, "TOPLEFT", DETAIL_PAD, -y)
        detail.title:SetWidth(width - (controlWidth > 0 and controlWidth + 16 or 0))
        detail.title:SetText(item.label())
        if control then
            control:ClearAllPoints()
            control:SetPoint("RIGHT", body, "TOPRIGHT", -DETAIL_PAD, -(y + 11))
        end
        y = y + math.max(22, detail.title:GetStringHeight()) + 12

        if DetailPills(detail) then
            detail.pills[1]:ClearAllPoints()
            detail.pills[1]:SetPoint("TOPLEFT", body, "TOPLEFT", DETAIL_PAD, -y)
            y = y + 22 + 14
        end

        -- What it does, or why it cannot run.
        local note = item.note and item.note()
        detail.desc:ClearAllPoints()
        detail.desc:SetPoint("TOPLEFT", body, "TOPLEFT", DETAIL_PAD, -y)
        detail.desc:SetWidth(width)
        detail.desc:SetText(note or item.desc())
        UI.Ink(detail.desc, note and "warning" or "textDim")
        y = y + detail.desc:GetStringHeight()

        local plain, grouped = {}, {}
        for _, option in ipairs(entry.options) do
            local list = option.group and grouped or plain
            list[#list + 1] = option
        end
        -- Options of a switched-off feature stay visible, greyed, with a word why.
        local off = #entry.options > 0 and item.kind == "toggle" and not item.get()
        detail.off:SetShown(off)
        if off then
            y = y + 16
            detail.off:ClearAllPoints()
            detail.off:SetPoint("TOPLEFT", body, "TOPLEFT", DETAIL_PAD, -y)
            detail.off:SetWidth(width)
            detail.off:SetText(L.ui_options_off:format(item.label()))
            y = y + detail.off:GetStringHeight()
        end

        detail.optionsTitle:SetShown(#plain > 0)
        detail.options:SetShown(#plain > 0)
        if #plain > 0 then
            y = y + 24
            detail.optionsTitle:ClearAllPoints()
            detail.optionsTitle:SetPoint("TOPLEFT", body, "TOPLEFT", DETAIL_PAD + 2, -y)
            detail.optionsTitle:SetText(L.ui_options)
            y = y + 22
            local offset = 0
            for index, option in ipairs(plain) do
                local row = detailRows[index]
                if not row then
                    row = CreateRow(detail.options)
                    -- Pointed at, an option may show what it does in the picture.
                    row:HookScript("OnEnter", function(self)
                        UI.Previews.Focus(detail.stage, self.item and self.item.optionKey)
                    end)
                    row:HookScript("OnLeave", function()
                        UI.Previews.Focus(detail.stage, nil)
                    end)
                    detailRows[index] = row
                end
                RowSetItem(row, option, index, width)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", detail.options, "TOPLEFT", 0, -offset)
                row:Show()
                offset = offset + row.height
            end
            detail.options:ClearAllPoints()
            detail.options:SetPoint("TOPLEFT", body, "TOPLEFT", DETAIL_PAD, -y)
            detail.options:SetSize(width, math.max(1, offset))
            y = y + offset
        end
        for index = #plain + 1, #detailRows do
            detailRows[index]:Hide()
        end

        detail.chipsTitle:SetShown(#grouped > 0)
        detail.chipsCount:SetShown(#grouped > 0)
        detail.hint:SetShown(#grouped > 0)
        if #grouped > 0 then
            y = y + 24
            detail.chipsTitle:ClearAllPoints()
            detail.chipsTitle:SetPoint("TOPLEFT", body, "TOPLEFT", DETAIL_PAD + 2, -y)
            detail.chipsTitle:SetText(grouped[1].groupLabel())
            detail.chipsCount:ClearAllPoints()
            detail.chipsCount:SetPoint("TOPRIGHT", body, "TOPRIGHT", -DETAIL_PAD - 2, -y)
            y = y + 22
            local chipWidth = math.floor((width - CHIP_GAP * (CHIP_COLUMNS - 1)) / CHIP_COLUMNS)
            for index, option in ipairs(grouped) do
                local chip = detail.chips[index] or NewChip(detail)
                chip.option = option
                local column, line = (index - 1) % CHIP_COLUMNS, math.floor((index - 1) / CHIP_COLUMNS)
                chip:ClearAllPoints()
                chip:SetPoint("TOPLEFT", body, "TOPLEFT", DETAIL_PAD + column * (chipWidth + CHIP_GAP),
                    -(y + line * (CHIP_H + CHIP_GAP)))
                chip:SetWidth(chipWidth)
                chip:Show()
            end
            local lines = math.ceil(#grouped / CHIP_COLUMNS)
            y = y + lines * CHIP_H + (lines - 1) * CHIP_GAP + 12
            detail.hintText = grouped[1].groupDesc()
            detail.hint:ClearAllPoints()
            detail.hint:SetPoint("TOPLEFT", body, "TOPLEFT", DETAIL_PAD + 2, -y)
            detail.hint:SetWidth(width - 4)
            detail.hint:SetText(detail.hintText)
            y = y + 34 -- room for an explanation of two lines
        end
        for index = #grouped + 1, #detail.chips do
            detail.chips[index]:Hide()
        end

        detail.scroll:SetContentHeight(y + DETAIL_PAD)
        RefreshDetail(false)
    end

    local function CreateDetail()
        local detail = CreateFrame("Frame", nil, window)
        detail:SetPoint("TOPLEFT", window, "TOPLEFT", SIDEBAR + PAD + LIST_W + SPLIT_GAP, -(HEAD + HEADER))
        detail:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, 18)
        UI.Card(detail, "card", "cardBorder", 10)
        local pixel = UI.Pixel(detail)
        local sheen = UI.Line(detail, "sheenSoft")
        sheen:SetPoint("TOPLEFT", 10, -pixel)
        sheen:SetPoint("TOPRIGHT", -10, -pixel)

        local scroll = UI.Scroll(detail)
        scroll:SetPoint("TOPLEFT", pixel, -pixel)
        scroll:SetPoint("BOTTOMRIGHT", -pixel, pixel)
        scroll.content:SetWidth(DETAIL_W - 2 * pixel)
        detail.scroll = scroll
        local body = scroll.content

        -- The picture of what the chosen entry does, a scene drawn live.
        detail.stage = UI.Previews.Stage(body, DETAIL_W - 2 * DETAIL_PAD, PICTURE_H)
        detail.stage:SetPoint("TOPLEFT", DETAIL_PAD, -DETAIL_PAD)

        detail.crumb = UI.Text(body, 12, "textMuted")
        detail.crumb:SetWordWrap(false)
        detail.title = UI.Text(body, 17, "text", "semibold")
        detail.toggle = UI.Toggle(body)
        detail.switch = CreateFrame("Button", nil, body)
        detail.switch:SetSize(56, 40)
        detail.switch:SetPoint("CENTER", detail.toggle, "CENTER")
        detail.switch:SetScript("OnClick", function()
            local item = detail.current
            if not IsDisabled(item) then
                item.set(not item.get())
            end
        end)
        detail.dropdown = UI.Dropdown(body)
        detail.dropdown.open = CreateFrame("Button", nil, detail.dropdown)
        detail.dropdown.open:SetAllPoints(detail.dropdown)
        detail.dropdown.open:SetScript("OnClick", function()
            local item = detail.current
            if not IsDisabled(item) then
                UI.OpenMenu(detail.dropdown, item.values(), item.get(), item.set)
            end
        end)
        detail.swatches = UI.Swatches(body, function(value)
            detail.current.set(value)
        end)
        detail.action = UI.Button(body, function()
            detail.current.click()
        end)

        detail.pills = { UI.Pill(body), UI.Pill(body) }
        detail.pills[2]:SetPoint("LEFT", detail.pills[1], "RIGHT", 6, 0)
        detail.desc = UI.Text(body, 13, "textDim")
        detail.desc:SetSpacing(3)
        detail.off = UI.Text(body, 12, "textMuted")
        detail.optionsTitle = UI.Text(body, 12, "textDim", "semibold")
        -- The options lie a little deeper than the card.
        detail.options = CreateFrame("Frame", nil, body)
        UI.Card(detail.options, "window", "cardBorder", 8)
        detail.chipsTitle = UI.Text(body, 12, "textDim", "semibold")
        detail.chipsCount = UI.Text(body, 12, "textMuted", "medium")
        detail.chipsCount:SetJustifyH("RIGHT")
        detail.hint = UI.Text(body, 12, "textMuted")
        detail.hint:SetSpacing(2)
        detail.chips = {}
        detail:Hide()
        window.detail = detail
    end

    local function BuildSplit()
        local list = UI.Scroll(window)
        list:SetPoint("TOPLEFT", window, "TOPLEFT", SIDEBAR + PAD, -(HEAD + HEADER))
        list:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", SIDEBAR + PAD, 18)
        list:SetWidth(LIST_W)
        list.content:SetWidth(LIST_W)
        list:Hide()
        window.list = list
        CreateDetail()
    end

    -- Shows the entries of a settings tab and the chosen one, or hides both.
    function RenderSplit(page, tab, shown)
        if not shown then
            if window.list then
                window.list:SetContentHeight(1) -- the thumbs lie outside the frames
                window.list:Hide()
                window.detail.scroll:SetContentHeight(1)
                window.detail:Hide()
            end
            listKey, detailKey = nil, nil
            return
        end
        if not window.list then
            BuildSplit()
        end
        local list = SplitEntries(tab)
        local where = page.id .. ":" .. tab.id
        local chosen = list[1]
        for _, entry in ipairs(list) do
            if entry.item.id == chosenEntries[where] then
                chosen = entry
            end
        end
        chosenEntries[where] = chosen and chosen.item.id or nil

        local content = window.list.content
        local y, titles = 0, 0
        for index, entry in ipairs(list) do
            if entry.title then
                titles = titles + 1
                local heading = entryTitles[titles]
                if not heading then
                    heading = UI.Text(content, 12, "textDim", "semibold")
                    entryTitles[titles] = heading
                end
                y = y + (index > 1 and 12 or 0)
                heading:ClearAllPoints()
                heading:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -y)
                heading:SetText(entry.title)
                heading:Show()
                y = y + ENTRY_TITLE
            end
            local frame = entryFrames[index]
            if not frame then
                frame = CreateEntry(content)
                entryFrames[index] = frame
            end
            frame.entry = entry
            frame.chosen = entry == chosen
            frame.hover:Hide()
            frame:ClearAllPoints()
            frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
            EntryRefresh(frame, false)
            frame:Show()
            y = y + ENTRY_H + ENTRY_GAP
        end
        for index = #list + 1, #entryFrames do
            entryFrames[index]:Hide()
        end
        for index = titles + 1, #entryTitles do
            entryTitles[index]:Hide()
        end
        window.list:Show()
        window.list:SetContentHeight(y)
        if where ~= listKey then
            listKey = where
            window.list:ScrollToTop()
        end

        window.detail:SetShown(chosen ~= nil)
        if chosen then
            ShowEntry(chosen)
            local key = where .. ":" .. chosen.item.id
            if key ~= detailKey then
                detailKey = key
                window.detail.scroll:ScrollToTop()
            end
        end
    end

    -- Refreshes the entries and the chosen one in place.
    function RefreshSplit(animate)
        if not window.list or not window.list:IsShown() then
            return
        end
        for _, frame in ipairs(entryFrames) do
            if frame:IsShown() then
                EntryRefresh(frame, animate)
            end
        end
        for _, row in ipairs(detailRows) do
            if row:IsShown() then
                RowRefresh(row, animate)
            end
        end
        RefreshDetail(animate)
    end

    function ChooseEntry(id)
        local page = pages[currentPage]
        chosenEntries[page.id .. ":" .. CurrentTab(page).id] = id
        tidyArmed = false
        Render()
    end
end -- settings tabs

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------

-- Whether any of an area's categories is switched on.
local function AreaOn(area)
    for _, category in ipairs(area.categories) do
        if ns:IsCategoryEnabled(category) then
            return true
        end
    end
    return false
end

-- The sidebar lists the pages: the main features at the top (a switched-off
-- one greyed and marked OFF), the addon's own pages at the bottom. The head names the chosen page,
-- or the search while there is one.
local function RefreshNav()
    local searching = searchText ~= ""
    for _, id in ipairs(pageOrder) do
        local button, page = navButtons[id], pages[id]
        local selected = not searching and id == currentPage
        button.selected = selected
        button.fill:SetShown(selected)
        button.bar:SetShown(selected)
        button.label:SetText(page.title())
        UI.Ink(button.label, selected and "text" or "textDim")
        UI.Tint(button.icon, selected and "accent" or "textMuted")
        if page.area then
            local on = AreaOn(page.area)
            button.label:SetAlpha(on and 1 or 0.45)
            button.icon:SetAlpha(on and 1 or 0.45)
            button.pill:SetShown(not on)
            button.count:SetText(L.ui_category_off)
            button.pill:SetWidth(button.count:GetStringWidth() + 14)
        end
    end
    window.tagline:SetText(L.ui_tagline)
    local page = pages[currentPage]
    if not searching then
        window.area.name:SetText(page.title())
        window.area.desc:SetText(page.desc())
    end
end

-- The chosen page's tabs at the top of the content, left to right. In a
-- fellow traveller's story the way back stands there instead; while
-- searching there are none. A page with a single tab shows none.
local function RefreshTabs()
    local bar = window.tabs
    local page = pages[currentPage]
    local searching = searchText ~= ""
    local story = not searching and fellowStory ~= nil
    bar.back:SetShown(story)
    if story then
        bar.back:SetLabel(L.ui_fellow_back)
    end
    local shown = not searching and not story and #page.tabs > 1
    local current = CurrentTab(page).id
    local left = 0
    for index, tab in ipairs(shown and page.tabs or {}) do
        local button = bar.buttons[index] or bar.NewTab(index)
        button.id = tab.id
        button.label:SetText(tab.label and tab.label() or page.title())
        button.label:SetAlpha(tab.category ~= nil and not ns:IsCategoryEnabled(tab.category) and 0.5 or 1)
        button.selected = tab.id == current
        button.bar:SetShown(button.selected)
        UI.Ink(button.label, button.selected and "text" or "textDim")
        local width = button.label:GetStringWidth() + 24
        button:SetWidth(width)
        button:ClearAllPoints()
        button:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", left, 0)
        button:Show()
        left = left + width + 4
    end
    for index = (shown and #page.tabs or 0) + 1, #bar.buttons do
        bar.buttons[index]:Hide()
    end
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

-- Refreshes switches and counters without touching the layout.
function RefreshState(animate)
    for i = 1, #rows do
        if rows[i]:IsShown() then
            RowRefresh(rows[i], animate)
        end
    end
    RefreshSplit(animate)
    UpdateResetButton()
    RefreshNav()
    RefreshTabs()
end

-- The welcome page lies over sidebar and content; the head keeps only logo,
-- name and close. What lies below is left as it was and laid out again once
-- the page is gone.
local function EndWelcome(page, tab)
    welcoming = false
    PlayEmbers()
    selectedTabs[page] = tab
    SelectPage(page)
end

local function ShowWelcome()
    if not welcomePage then
        welcomePage = UI.Welcome.Build(window, {
            width = WIDTH,
            height = HEIGHT,
            head = HEAD,
            radius = RADIUS,
            grain = GRAIN_BAND,
        }, {
            -- One click: the main features on, then the chronicle.
            all = function()
                UI.Welcome.SwitchOn()
                EndWelcome("chronicle")
            end,
            -- The chronicle's switches, to pick from there.
            choose = function()
                UI.Welcome.Decide()
                EndWelcome("chronicle", "record")
            end,
            later = function()
                UI.Welcome.Decide()
                EndWelcome("chronicle")
            end,
        })
        PlayEmbers()
    end
    window.area:Hide()
    welcomePage:Refresh()
    welcomePage:Show()
end

function OpenWelcome()
    welcoming = true
    DisarmReset()
    tidyArmed = false
    PlayEmbers()
    Render()
end

function Render()
    UI.CloseMenu()
    if welcoming then
        ShowWelcome()
        return
    end
    if welcomePage then
        welcomePage:Hide()
    end
    window.area:Show()
    local searching = searchText ~= ""
    local page = pages[currentPage]
    local tab = CurrentTab(page)
    local blocks, key

    if searching then
        local total
        blocks, total = SearchBlocks(searchText)
        window.area.name:SetText(L.ui_search_title)
        if total > 0 then
            window.area.desc:SetText(ns.Plural("ui_search_results", total):format(total))
        else
            window.area.desc:SetText(L.ui_search_none:format(searchText))
        end
        key = "search:" .. searchText
    else
        blocks = tab.blocks()
        key = page.id .. ":" .. tab.id .. ":" .. (chronicleWho or "") .. ":" .. (fellowStory or "")
    end

    -- A switched-off main feature shows a notice instead of its content.
    local off = not searching and tab.category ~= nil and not ns:IsCategoryEnabled(tab.category)
    if off then
        blocks = {}
    end
    window.offNotice:SetShown(off)
    window.offNotice.text:SetText(L.ui_off_notice:format(page.title()))
    window.offNotice.button:SetLabel(L.ui_off_enable)

    -- A settings tab lists its entries and shows the chosen one instead of
    -- cards of rows; the search shows rows as everywhere.
    local split = not searching and not off and tab.split == true
    if split then
        blocks = {}
    end
    window.scroll:SetShown(not split)

    -- A fellow traveller's story, if one is open and the person still there.
    local storyPerson, storyChapters
    if not searching and not off and tab.overview and fellowStory then
        storyPerson, storyChapters = FellowStory(fellowStory)
        fellowStory = storyPerson and fellowStory or nil
    end

    -- A story keeps the person's card on the left; the book scrolls beside it.
    local left, contentWidth, top = SIDEBAR + PAD, CONTENT_W, HEAD + HEADER
    if storyPerson then
        left, contentWidth = left + FELLOW_CARD_W + FELLOW_GAP, contentWidth - FELLOW_CARD_W - FELLOW_GAP
    end
    window.scroll:SetPoint("TOPLEFT", window, "TOPLEFT", left, -top)
    window.scroll.content:SetWidth(contentWidth)

    -- Reset where the tab has settings, at the right end of the tabs.
    window.resetButton:SetShown(not searching and not off and not storyPerson and HasSettings(tab))
    UpdateResetButton()

    -- A tab with a rail leaves it the right part of the content.
    local railCards = not searching and not off and tab.rail and tab.rail() or nil
    local overview = not searching and not off and not storyPerson and tab.overview and tab.overview() or nil
    local nearby = not searching and not off and tab.nearby and tab.nearby() or nil
    local aside = railCards and RAIL_GAP + RAIL_W or 0
    local width = railCards and BOOK_W or contentWidth
    window.scroll:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -(PAD + aside), 18)

    local content = window.scroll.content
    local y, rowCount = 0, 0
    -- Narrowed to a companion, the book says so above it, with the way back.
    if railCards and chronicleWho then
        local bar = window.bookFilter
        if not bar then
            bar = CreateFrame("Frame", nil, content)
            bar:SetSize(BOOK_W, 28)
            bar.text = UI.Text(bar, 12, "textDim", "medium")
            bar.text:SetPoint("LEFT", 2, 0)
            bar.text:SetJustifyV("MIDDLE")
            bar.clear = UI.Button(bar, function()
                SelectCompanion(chronicleWho)
            end, "ghost")
            bar.clear:SetPoint("LEFT", bar.text, "RIGHT", 6, 0)
            -- What you did together is the fellow travellers' to tell.
            bar.toStory = UI.Button(bar, function()
                ShowStoryOf(bar.guid)
            end, "ghost")
            bar.toStory:SetPoint("LEFT", bar.clear, "RIGHT", 4, 0)
            window.bookFilter = bar
        end
        bar.text:SetText(L.c_only_who:format(ns.ChronicleService.Label({ who = chronicleWho })))
        bar.clear:SetLabel(L.c_show_all)
        bar.guid = ns:IsCategoryEnabled("fellows") and ns.FellowService.Find(chronicleWho) or nil
        bar.toStory:SetLabel(L.ui_fellow_story)
        bar.toStory:SetShown(bar.guid ~= nil)
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        bar:Show()
        y = 40
    elseif window.bookFilter then
        window.bookFilter:Hide()
    end
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
        card:SetWidth(width)
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
            RowSetItem(row, item, index, width)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -(y + offset))
            row:Show()
            offset = offset + row.height
        end
        card:SetHeight(math.max(1, offset))
        card:Show()
        y = y + offset + BLOCK_GAP
    end
    for index = rowCount + 1, #rows do
        rows[index]:Hide()
    end
    for index = #blocks + 1, #cards do
        cards[index]:Hide()
    end

    -- A tab that tells a story lays its book out below its cards.
    local chapters, footer
    if not searching and not off and tab.book then
        chapters, footer = tab.book()
    end
    if chapters then
        if not window.book then
            window.book = UI.Book(content, BOOK_W)
        end
        window.book:ClearAllPoints()
        window.book:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        y = y + window.book:SetChapters(chapters, footer)
        window.book:Show()
    elseif window.book then
        window.book:Hide()
    end

    if storyPerson then
        if not window.fellowBook then
            window.fellowBook = UI.Book(content, FELLOW_BOOK_W)
        end
        if not window.fellows then
            window.fellows = UI.FellowOverview(content, window, FELLOW_CARD_W)
        end
        window.fellowBook:ClearAllPoints()
        window.fellowBook:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        y = y + window.fellowBook:SetChapters(storyChapters)
        window.fellowBook:Show()
        local card = window.fellows.card
        window.fellows:SetCard(storyPerson, true, FELLOW_ACTIONS)
        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", window, "TOPLEFT", SIDEBAR + PAD, -top)
        card:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", SIDEBAR + PAD, 18)
        card:Show()
    elseif window.fellowBook then
        window.fellowBook:Hide()
    end

    if overview then
        if not window.fellows then
            window.fellows = UI.FellowOverview(content, window, FELLOW_CARD_W)
        end
        local fellows = window.fellows
        fellows:ClearAllPoints()
        fellows:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        y = y + fellows:SetModel(overview, width)
        fellows:Show()
        fellows.card:SetShown(storyPerson ~= nil)
    elseif window.fellows then
        window.fellows:Hide()
        window.fellows.card:SetShown(storyPerson ~= nil)
    end

    if nearby then
        if not window.nearby then
            window.nearby = UI.NearbyList(content)
        end
        window.nearby:ClearAllPoints()
        window.nearby:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
        y = y + window.nearby:SetModel(nearby, width)
        window.nearby:Show()
    elseif window.nearby then
        window.nearby:Hide()
    end

    window.scroll:SetContentHeight(y)
    -- Rows that fold or unfold on the same tab must not make it jump.
    if key ~= renderedKey then
        renderedKey = key
        window.scroll:ScrollToTop()
    end

    -- The rail scrolls by itself, if it is longer than the window.
    if railCards then
        if not window.rail then
            window.railScroll = UI.Scroll(window)
            window.railScroll:SetPoint("TOPLEFT", window, "TOPLEFT", SIDEBAR + PAD + BOOK_W + RAIL_GAP, -HEAD - HEADER)
            window.railScroll:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -PAD, 18)
            window.railScroll.content:SetWidth(RAIL_W)
            window.rail = UI.Rail(window.railScroll.content, RAIL_W)
            window.rail:SetPoint("TOPLEFT")
        end
        window.railScroll:Show()
        window.railScroll:SetContentHeight(window.rail:SetCards(railCards))
        local where = page.id .. ":" .. tab.id
        if where ~= railKey then
            railKey = where
            window.railScroll:ScrollToTop()
        end
    elseif window.rail then
        railKey = nil
        window.railScroll:SetContentHeight(1) -- its thumb lies outside it
        window.railScroll:Hide()
    end

    RenderSplit(page, tab, split)

    window.search.placeholder:SetText(L.ui_search)
    RefreshNav()
    RefreshTabs()
end

function SelectPage(id)
    DisarmReset()
    tidyArmed = false
    chronicleWho, fellowStory = nil, nil
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
    tidyArmed = false
    chronicleWho, fellowStory = nil, nil
    selectedTabs[currentPage] = id
    Render()
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

-- A page's entry in the sidebar: icon, name and, for a main feature, its
-- counter. The chosen one: the accent fading out to the right, and a glowing
-- bar at its left edge.
local function CreateNavButton(parent, page)
    local width = SIDEBAR - 24
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, NAV_ROW)
    button.navId = page.id

    button.fill = UI.Round(button, "accentFade", 8)
    button.fill:SetGradient("HORIZONTAL", "accentFade", "accentFadeEnd", width, NAV_ROW)
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
    button.icon:SetPoint("LEFT", 14, 0)
    button.label = UI.Text(button, 13, "textDim", "medium")
    button.label:SetPoint("LEFT", button.icon, "RIGHT", 10, 0)
    button.label:SetJustifyV("MIDDLE")

    if page.area then
        -- "OFF" beside a switched-off main feature.
        button.pill = CreateFrame("Frame", nil, button)
        button.pill:SetHeight(18)
        button.pill:SetPoint("RIGHT", -10, 0)
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

-- The chosen page's tabs, at the top of the content: small buttons with the
-- accent stroke on the line below them. RefreshTabs fills them.
local function CreateContentTabs()
    local pixel = UI.Pixel(window)
    local bar = CreateFrame("Frame", nil, window)
    bar:SetPoint("TOPLEFT", window, "TOPLEFT", SIDEBAR + PAD - 12, -HEAD - pixel)
    bar:SetPoint("TOPRIGHT", window, "TOPRIGHT", -PAD, -HEAD - pixel)
    bar:SetHeight(TABS)
    local line = UI.Line(window, "cardBorder")
    line:SetPoint("TOPLEFT", window, "TOPLEFT", SIDEBAR, -HEAD - TABS)
    line:SetPoint("TOPRIGHT", window, "TOPRIGHT", -pixel, -HEAD - TABS)

    bar.buttons = {}
    function bar.NewTab(index)
        local button = CreateFrame("Button", nil, bar)
        button:SetHeight(TABS)
        button.label = UI.Text(button, 13, "textDim", "medium")
        button.label:SetPoint("CENTER")
        button.label:SetJustifyV("MIDDLE")
        button.bar = CreateFrame("Frame", nil, button)
        button.bar:SetHeight(2)
        button.bar:SetPoint("BOTTOMLEFT", 10, 0)
        button.bar:SetPoint("BOTTOMRIGHT", -10, 0)
        local stroke = button.bar:CreateTexture(nil, "OVERLAY")
        stroke:SetAllPoints(button.bar)
        UI.Shade(stroke, "HORIZONTAL", "accent", "accent2")
        UI.Shadow(button.bar, 7, 1, 0, "accentGlow")
        button:SetScript("OnEnter", function(self)
            UI.Ink(self.label, "text")
        end)
        button:SetScript("OnLeave", function(self)
            UI.Ink(self.label, self.selected and "text" or "textDim")
        end)
        button:SetScript("OnClick", function(self)
            SelectTab(self.id)
        end)
        bar.buttons[index] = button
        return button
    end

    -- In a fellow traveller's story: the way back to the overview.
    bar.back = UI.Button(bar, function()
        fellowStory = nil
        Render()
    end, "ghost", "chevron")
    bar.back.icon:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0) -- the chevron turned to point left
    bar.back:SetPoint("LEFT", 2, 0)
    bar.back:Hide()

    window.resetButton = UI.Button(bar, ResetClicked, "ghost", "reset")
    window.resetButton:SetPoint("RIGHT", 0, 0)
    window.tabs = bar
end

-- The sparks move only while the window is open and the player wants them.
-- wanted: false to stop them regardless of the option.
-- While the welcome page lies over the window, only its own sparks move.
function PlayEmbers(wanted)
    local playing = wanted ~= false and window ~= nil and window:IsShown() and ns:GetOption("general", "embers") == true
    for _, set in ipairs(embers) do
        set:SetPlaying(playing and not welcoming)
    end
    if welcomePage then
        welcomePage.embers:SetPlaying(playing and welcoming)
    end
end

local function SavePosition()
    local point, _, relativePoint, x, y = window:GetPoint(1)
    ns.global.window = { point = point, relativePoint = relativePoint, x = x, y = y }
end

-- The dark ground of head and sidebar is drawn on the window itself, so
-- that the grain lies over it as over the content. left, top, right,
-- bottom: from the window's top left corner.
local function Ground(left, top, right, bottom)
    local piece = window:CreateTexture(nil, "BACKGROUND", nil, 2)
    piece:SetPoint("TOPLEFT", window, "TOPLEFT", left, -top)
    piece:SetPoint("BOTTOMRIGHT", window, "TOPLEFT", right, -bottom)
    UI.Paint(piece, "sidebar")
    return piece
end

-- A rounded corner of that ground: a quarter of circle.tga.
local function GroundCorner(point, x, y, l, r, t, b)
    local corner = RADIUS - UI.Pixel(window)
    local round = window:CreateTexture(nil, "BACKGROUND", nil, 2)
    round:SetTexture(UI.media.circle)
    round:SetTexCoord(l, r, t, b)
    round:SetSize(corner, corner)
    round:SetPoint(point, window, point, x, y)
    UI.Tint(round, "sidebar")
    return round
end

local function BuildSidebar()
    local sidebar = CreateFrame("Frame", nil, window)
    sidebar:SetPoint("TOPLEFT")
    sidebar:SetPoint("BOTTOMLEFT")
    sidebar:SetWidth(SIDEBAR)
    local pixel = UI.Pixel(window)
    Ground(pixel, HEAD, RADIUS, HEIGHT - RADIUS)
    Ground(RADIUS, HEAD, SIDEBAR - pixel, HEIGHT - pixel)
    GroundCorner("BOTTOMLEFT", pixel, pixel, 0, 0.5, 0.5, 1)
    -- Below the head a line parts the sidebar from the content; the head
    -- itself runs on to the right on the same ground.
    local edge = UI.VLine(sidebar, "windowBorder")
    edge:SetPoint("TOPRIGHT", 0, -HEAD)
    edge:SetPoint("BOTTOMRIGHT")

    -- A soft glow in the accent colour behind the logo. It is one round
    -- spot, much larger than the corner it sits in; the pieces leave out the
    -- window's rounded corner. In the head it fades out across the window.
    local SPOT = { left = -116, top = -136, width = 400, height = 360 }
    local function Haze(left, top, right, bottom)
        local piece = window:CreateTexture(nil, "BACKGROUND", nil, 3)
        piece:SetTexture(UI.media.shadow)
        piece:SetPoint("TOPLEFT", window, "TOPLEFT", left, -top)
        piece:SetPoint("BOTTOMRIGHT", window, "TOPLEFT", right, -bottom)
        piece:SetTexCoord(
            (left - SPOT.left) / SPOT.width,
            (right - SPOT.left) / SPOT.width,
            (top - SPOT.top) / SPOT.height,
            (bottom - SPOT.top) / SPOT.height
        )
        UI.Tint(piece, "accentHaze")
        return piece
    end
    local hazeBottom = SPOT.top + SPOT.height
    Haze(RADIUS, pixel, SPOT.left + SPOT.width, HEAD)
    Haze(pixel, RADIUS, RADIUS, HEAD)
    Haze(RADIUS, HEAD, SIDEBAR - pixel, hazeBottom)
    Haze(pixel, HEAD, RADIUS, hazeBottom)

    -- A few sparks that rise behind the entries.
    embers[#embers + 1] = UI.Embers(sidebar, 7, 0, SIDEBAR, HEIGHT, 11)

    -- The corner itself: a quarter circle in the glow's strength at that
    -- spot (the falloff of shadow.tga, see tools/make_media.py). Without
    -- it the corner shows as a dark square in the glow.
    local function SpotAlpha(x, y)
        local dx = ((x - SPOT.left) / SPOT.width - 0.5) * 64
        local dy = ((y - SPOT.top) / SPOT.height - 0.5) * 64
        local distance = math.max(0, math.sqrt(dx * dx + dy * dy) - 4)
        return (1 - math.min(1, distance / 28)) ^ 2.2
    end
    local corner = window:CreateTexture(nil, "BACKGROUND", nil, 3)
    corner:SetTexture(UI.media.circle)
    corner:SetTexCoord(0, 0.5, 0, 0.5)
    corner:SetSize(RADIUS - pixel, RADIUS - pixel)
    corner:SetPoint("TOPLEFT", window, "TOPLEFT", pixel, -pixel)
    UI.Tint(corner, "accentHaze", SpotAlpha(RADIUS * 0.6, RADIUS * 0.6))

    -- Logo: the flame, free on the head's left end. It is a picture with
    -- its own colours and glow and looks the same in every scheme.
    local logo = CreateFrame("Frame", nil, window)
    logo:SetSize(40, 40)
    logo:SetPoint("TOPLEFT", 15, -(HEAD - 40) / 2)
    local picture = logo:CreateTexture(nil, "ARTWORK")
    picture:SetTexture(UI.media.logo)
    picture:SetAllPoints(logo)

    local wordmark = UI.Text(logo, 16, "text", "semibold")
    wordmark:SetPoint("TOPLEFT", logo, "TOPRIGHT", 8, -4)
    wordmark:SetText("Famulus")

    window.tagline = UI.Text(logo, 11, "textMuted")
    window.tagline:SetPoint("TOPLEFT", wordmark, "BOTTOMLEFT", 0, -3)

    -- The search at the top; below it the main features, the addon's own
    -- pages at the bottom.
    window.search = UI.SearchBox(sidebar, function(text)
        text = strtrim(text)
        if text ~= searchText then
            searchText = text
            Render()
        end
    end)
    window.search:SetPoint("TOPLEFT", 16, -HEAD - 16)
    window.search:SetPoint("TOPRIGHT", -16, -HEAD - 16)

    local top, bottom = HEAD + 64, 12
    for index = #pageOrder, 1, -1 do
        local page = pages[pageOrder[index]]
        local button = CreateNavButton(sidebar, page)
        if page.bottom then
            button:SetPoint("BOTTOMLEFT", 12, bottom)
            bottom = bottom + NAV_ROW + 2
        end
    end
    for _, id in ipairs(pageOrder) do
        if not pages[id].bottom then
            navButtons[id]:SetPoint("TOPLEFT", 12, -top)
            top = top + NAV_ROW + 2
        end
    end
    local line = UI.Line(sidebar, "windowBorder")
    line:SetPoint("BOTTOMLEFT", 20, bottom + 6)
    line:SetPoint("BOTTOMRIGHT", -20, bottom + 6)
    window.sidebar = sidebar
end

-- The head right of the logo: the chosen page's name and what it is for, on
-- the sidebar's dark ground, and the close button. The ground is drawn on the window itself, so
-- that the grain lies over it as over the content.
local function BuildHead()
    local pixel = UI.Pixel(window)
    Ground(RADIUS, pixel, WIDTH - RADIUS, HEAD)
    Ground(pixel, RADIUS, RADIUS, HEAD)
    Ground(WIDTH - RADIUS, RADIUS, WIDTH - pixel, HEAD)
    GroundCorner("TOPLEFT", pixel, -pixel, 0, 0.5, 0, 0.5)
    GroundCorner("TOPRIGHT", -pixel, -pixel, 0.5, 1, 0, 0.5)

    local line = UI.Line(window, "windowBorder")
    line:SetPoint("TOPLEFT", pixel, -HEAD)
    line:SetPoint("TOPRIGHT", -pixel, -HEAD)

    local area = CreateFrame("Frame", nil, window)
    area:SetPoint("TOPLEFT", SIDEBAR + PAD, -20)
    area:SetSize(CONTENT_W - 60, 40)
    area.name = UI.Text(area, 17, "text", "semibold")
    area.name:SetPoint("TOPLEFT")
    area.desc = UI.Text(area, 12, "textMuted")
    area.desc:SetPoint("TOPLEFT", area.name, "BOTTOMLEFT", 0, -6)
    area.desc:SetWidth(CONTENT_W - 60)
    area.desc:SetWordWrap(false)
    window.area = area

    local close = UI.IconButton(window, "close", function()
        window:Hide()
    end, 28)
    close:SetPoint("TOPRIGHT", -12, -(HEAD - 28) / 2)
    window.closeButton = close
end

-- Shown instead of the content while the page's main feature is off.
local function BuildNotice()
    local notice = CreateFrame("Frame", nil, window)
    notice:SetSize(CONTENT_W, 90)
    notice:SetPoint("TOP", window, "TOPLEFT", SIDEBAR + PAD + CONTENT_W / 2, -HEAD - HEADER - 60)
    notice.text = UI.Text(notice, 14, "textDim", "medium")
    notice.text:SetPoint("TOP")
    notice.text:SetJustifyH("CENTER")
    notice.button = UI.Button(notice, function()
        selectedTabs.general = "general"
        SelectPage("general")
    end, "primary")
    notice.button:SetPoint("TOP", notice.text, "BOTTOM", 0, -18)
    notice:Hide()
    window.offNotice = notice
end

local function Build()
    BuildPages()
    currentPage = pageOrder[1]

    window = CreateFrame("Frame", "FamulusOptionsFrame", UIParent)
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
    UI.Card(window, "window", "windowBorder", RADIUS)

    -- Light catching the top edge, across sidebar and content alike. Its
    -- own frame, so that it lies above the sidebar's ground.
    local pixel = UI.Pixel(window)
    local gloss = CreateFrame("Frame", nil, window)
    gloss:SetFrameLevel(window:GetFrameLevel() + 30)
    gloss:SetPoint("TOPLEFT", RADIUS, -pixel)
    gloss:SetPoint("TOPRIGHT", -RADIUS, -pixel)
    gloss:SetHeight(pixel)
    UI.Fill(gloss, "sheen")

    -- The content's ground: grain across the top, a little darker towards the bottom, and
    -- sparks that rise behind the cards.
    local dusk = window:CreateTexture(nil, "BACKGROUND", nil, 3)
    dusk:SetPoint("TOPLEFT", window, "TOPLEFT", SIDEBAR, -HEIGHT * 0.45)
    dusk:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -4, 4)
    UI.Shade(dusk, "VERTICAL", "clear", "dusk")
    UI.Grain(window, 4, 4, 4, HEIGHT - GRAIN_BAND, WIDTH, HEIGHT, true)
    embers[#embers + 1] = UI.Embers(window, 12, SIDEBAR, WIDTH - SIDEBAR, HEIGHT, 23)

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
    table.insert(UISpecialFrames, "FamulusOptionsFrame") -- Escape closes it

    BuildSidebar()
    BuildHead()
    CreateContentTabs()
    BuildNotice()

    window.scroll = UI.Scroll(window)

    window:SetScript("OnShow", function(self)
        -- Until the player has chosen, the window opens on the welcome page;
        -- closing it is no choice.
        welcoming = not holdWelcome and UI.Welcome.Wanted()
        PlayEmbers()
        Render()
        UI.RetryFonts()
        self:SetAlpha(0)
        UI.Tween(self, 0.15, function(progress)
            self:SetAlpha(progress)
        end)
    end)
    window:SetScript("OnHide", function()
        UI.CloseMenu()
        PlayEmbers(false)
        DisarmReset()
        tidyArmed = false
        renderedKey, railKey, chronicleWho, fellowStory = nil, nil, nil, nil
        listKey, detailKey = nil, nil
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

-- Opens the aliases page with the character or BattleTag in the input row,
-- so that only the alias is left to type. Used by the context menu and the
-- list itself.
function ns:EditAlias(name)
    if not window then
        Build()
    end
    -- The alias asked for wins over the welcome page; it comes again at the
    -- next opening.
    holdWelcome = true
    if not window:IsShown() then
        window:Show()
    end
    holdWelcome = false
    local wasWelcoming = welcoming
    welcoming = false
    if wasWelcoming then
        PlayEmbers()
    end
    if wasWelcoming or currentPage ~= "aliases" or searchText ~= "" or CurrentTab().id ~= "names" then
        selectedTabs.aliases = "names"
        SelectPage("aliases")
    end
    window.scroll:ScrollToTop()
    if aliasEditor then
        aliasEditor:Load(name, ns.AliasService.GetOwn(name))
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
    elseif section == "general" and key == "embers" then
        PlayEmbers()
    end
    -- Switching a feature greys its options and says why, which moves what
    -- follows; a main feature's switch swaps its page for a notice; the
    -- chronicle names people anew, or shows reactions or not; times and dates
    -- are written anew.
    local feature = ns.features[section]
    if (key == "enabled" and feature and #feature.options > 0) or section == "categories"
        or (section == "general" and (key == "chronicleNames" or key == "timeFormat" or key == "dateFormat"))
        or (section == "sharing" and key == "reactions") then
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
ns:On("CHRONICLE_CHANGED", function()
    RequestRefresh("layout")
end)
ns:On("ALIASES_CHANGED", function()
    RequestRefresh("layout")
end)
ns:On("FELLOWS_CHANGED", function()
    RequestRefresh("layout")
end)
-- The guild roster came: tidying up can count again.
ns:On("SOCIAL_CHANGED", function()
    RequestRefresh("layout")
end)
-- Who is where changed: only the tab that shows it is drawn again.
ns:On("NEARBY_CHANGED", function()
    if window and window:IsShown() and searchText == "" and currentPage == "fellows" and CurrentTab().id == "nearby" then
        RequestRefresh("layout")
    end
end)
ns:On("PROFILE_CHANGED", function()
    ApplyScale()
    PlayEmbers()
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
    title:SetText("Famulus")

    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(240, 26)
    button:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
    button:SetScript("OnClick", function()
        -- Close(true) skips the way back to the game menu: that path calls the
        -- protected ToggleGameMenu, which the game blocks from addon code.
        if SettingsPanel and SettingsPanel.Close and not InCombatLockdown() then
            SettingsPanel:Close(true)
        end
        if not (window and window:IsShown()) then
            ns:ToggleOptions()
        end
    end)
    panel:SetScript("OnShow", function()
        button:SetText(L.ui_open_settings)
    end)

    local ok, category = pcall(Settings.RegisterCanvasLayoutCategory, panel, "Famulus")
    if ok and category then
        pcall(Settings.RegisterAddOnCategory, category)
    end
end)
