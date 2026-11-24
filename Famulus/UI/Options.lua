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
local BLOCK_GAP, BLOCK_TITLE, CARD_GAP = 22, 24, 8

local LANGUAGE_NAMES = { enUS = "English", deDE = "Deutsch" }
local WINDOW_SCALES = { 80, 90, 100, 110, 120, 130, 140 }
local AREA_ICONS = { aliases = "tag", chronicle = "flag", fellows = "people" }

-- Rows that stand for a person: an avatar with an initial in front, a
-- button to remove them behind. A click calls item.open, the button
-- item.remove.
local PERSON_ROWS = { alias = true, fellow = true }

local window
local pages, pageOrder = {}, {}
local currentPage, selectedTabs, searchText = nil, {}, ""
local rows, cards, navButtons = {}, {}, {}
local renderedKey -- page, tab or search the rows were last laid out for
local railKey -- page and tab the chronicle's rail was last filled for
local chronicleWho -- the companion the chronicle's book is narrowed to, or nil
local fellowSort = "last" -- order of the fellow travellers' list: "last" or "time"
local fellowStory -- the fellow traveller whose story is open, or nil
local resetArmed, resetToken = false, 0
local tidyArmed, tidyToken = false, 0 -- the fellow travellers' tidying up asks first, too
local aliasEditor -- input row of the aliases page, once it has been shown
local embers = {} -- the sparks in the background, one set per ground
local Render, PlayEmbers, SelectPage, RefreshState -- forward declarations

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

-- The master switch of a main feature, in Settings › General.
local function CategoryItem(category)
    return {
        kind = "toggle",
        section = "categories",
        key = category,
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
            local item = FeatureItem(feature)
            -- Whether the feature really runs; its card shows that.
            item.active = function()
                return feature.enabled == true
            end
            items[#items + 1] = item
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

    local switches = {}
    for _, category in ipairs(ns.categories) do
        switches[#switches + 1] = CategoryItem(category)
    end
    local general = SimpleTab("general", {
        GeneralItem("language", "select", function()
            local list = { { value = "auto", text = L.lang_auto } }
            for _, code in ipairs(ns:GetLocaleCodes()) do
                list[#list + 1] = { value = code, text = LANGUAGE_NAMES[code] or code }
            end
            return list
        end),
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
    return { general, appearance }
end

---------------------------------------------------------------------------
-- Chronicle: the story of the player and their companions. Three tabs
-- tell it as a picture book, a fourth holds the switches that record it.
---------------------------------------------------------------------------

local function DayKey(timestamp)
    return date("%Y-%m-%d", timestamp)
end

-- "Today", "Yesterday" or the date of a day key ("2026-11-19").
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
    return (string.gsub(L.c_date, "{(%a)}", { d = day, m = month, y = year }))
end

local CHRONICLE_ROWS = 50 -- events in the book; older ones stay in the saved data

local CHRONICLE_EMPTY_ITEM = {
    kind = "info",
    label = function()
        return L.c_empty
    end,
    desc = function()
        return L.c_empty_desc
    end,
}
-- The book narrowed to a companion who has nothing in it yet.
local CHRONICLE_EMPTY_WHO_ITEM = {
    kind = "info",
    label = function()
        return L.c_empty_who:format((ns.ChronicleService.Companion({ who = chronicleWho })))
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

-- An entry as the book shows it (see UI/Book.lua).
local function ChronicleEvent(entry)
    local Chronicle = ns.ChronicleService
    -- The book says whose event it is in the strip below the card, so its
    -- headline does not; the live feed has no strip and names them.
    local title, detail = Chronicle.Text(entry, true)
    local kind = entry.k == "friendLevel" and "level" or entry.k
    local own, other = Chronicle.IsOwn(entry), Chronicle.OtherCharacter(entry)
    -- An ability or an item from the service's tables may bring a picture.
    local special = kind == "ability" and Chronicle.Ability(entry.ability)
        or kind == "item" and Chronicle.Item(entry.item) or nil
    local chip
    if not own then
        local name = Chronicle.Companion(entry)
        chip = { initial = Initial(name), text = name }
    elseif other then
        chip = { initial = Initial(other), text = other }
    end
    return {
        kind = kind,
        title = title,
        fullTitle = (Chronicle.Text(entry)),
        detail = detail,
        when = date("%H:%M", entry.t),
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

-- The live feed shows an entry the same way (Modules/Chronicle/LiveFeed.lua).
UI.ChronicleStory = ChronicleEvent

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

-- A run of entries as one event of the book: the look of the newest, one
-- sentence for all, and each one's time, the earliest first.
local function ChronicleRun(run)
    local event = ChronicleEvent(run[1])
    if #run == 1 then
        return event
    end
    local Chronicle = ns.ChronicleService
    event.title, event.detail = Chronicle.TextRun(run, true)
    event.fullTitle = (Chronicle.TextRun(run))
    event.count = #run
    event.times = {}
    for index = #run, 1, -1 do
        event.times[#event.times + 1] = date("%H:%M", run[index].t)
    end
    return event
end

-- Heading of a chapter: the place most of its events happened in, above it
-- the day, below it the levels gained and the number of events.
local function TitleChapter(chapter)
    local counts, best, bestCount = {}, nil, 0
    local low, high
    -- Sample entries do not name a chapter that has real ones.
    local real = false
    for _, entry in ipairs(chapter.entries) do
        real = real or not entry.demo
    end
    for _, entry in ipairs(chapter.entries) do
        local zone = not (real and entry.demo) and entry.zone
        if type(zone) == "string" and zone ~= "" then
            counts[zone] = (counts[zone] or 0) + 1
            if counts[zone] > bestCount then
                best, bestCount = zone, counts[zone]
            end
        end
        local level = not (real and entry.demo) and ns.ChronicleService.IsOwn(entry) and tonumber(entry.level)
        if level then
            low, high = math.min(low or level, level), math.max(high or level, level)
        end
    end
    chapter.small = best and chapter.day or nil
    chapter.title = best or chapter.day
    local parts = {}
    if low and low ~= high then
        parts[#parts + 1] = L.c_ch_levels:format(low, high)
    elseif low then
        parts[#parts + 1] = L.c_ch_level:format(low)
    end
    local count = #chapter.entries
    parts[#parts + 1] = count == 1 and L.c_ch_event or L.c_ch_events:format(count)
    chapter.sub = table.concat(parts, "  ·  ")
    chapter.entries = nil
end

-- One chapter per day, the newest event first; what repeats right away
-- shares a card (SameRun). wanted(entry): which entries; a companion chosen
-- in the rail narrows them further. Returns nil if there is nothing to tell,
-- else the chapters and a closing line if older events were left out.
local function ChronicleBook(wanted)
    local Chronicle = ns.ChronicleService
    local entries = Chronicle.Entries()
    local now = time()
    local today, yesterday = DayKey(now), DayKey(now - 86400)
    local chapters, chapter, chapterKey, shown, more = {}, nil, nil, 0, false
    local run
    for i = #entries, 1, -1 do
        local entry = entries[i]
        if wanted(entry) and (not chronicleWho or entry.who == chronicleWho) then
            if shown == CHRONICLE_ROWS then
                more = true
                break
            end
            shown = shown + 1
            local key = DayKey(entry.t)
            if key ~= chapterKey then
                chapter = { day = DayTitle(key, today, yesterday), runs = {}, entries = {} }
                chapters[#chapters + 1] = chapter
                chapterKey = key
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
        TitleChapter(each)
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
        return date("%H:%M", timestamp)
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
    local name, realName = ns.ChronicleService.Companion({ who = companion.who })
    return {
        key = companion.who,
        initial = Initial(name),
        name = name,
        line = line or realName,
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
            for _, id in ipairs(ns.features.sharing.STATISTICS) do
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
    local function Tab(id, wanted, rail)
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
        end),
        Tab("mine", Chronicle.IsOwn, function()
            return { ChronicleWeek(), ChronicleCrafts() }
        end),
        Tab("companions", function(entry)
            return not Chronicle.IsOwn(entry)
        end, function()
            return ChronicleBriefs(Chronicle.Companions(), Chronicle.OnlineCheck())
        end),
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
    if bosses == 1 then
        parts[#parts + 1] = L.ui_fellow_boss
    elseif bosses > 1 then
        parts[#parts + 1] = L.ui_fellow_bosses:format(bosses)
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
local function Capital(text)
    return (string.gsub(text, "^%l", string.upper))
end

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
    if bosses == 1 then
        stats[#stats + 1] = L.ui_fellow_boss
    elseif bosses > 1 then
        stats[#stats + 1] = L.ui_fellow_bosses:format(bosses)
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
    }
end

-- "10:40 to 12:50"
local function Span(from, to)
    return L.ui_fellow_span:format(date("%H:%M", from), date("%H:%M", to))
end

-- A fellow traveller's story as a book: one chapter per day together, the
-- newest first, and the first meeting. It tells only what you did together,
-- from the fellow travellers' own records; what the person did on their
-- own is the chronicle's to tell. Returns the person (as in the overview)
-- and the chapters, or nil if they are gone.
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
    local today, yesterday = DayKey(now), DayKey(now - 86400)
    local milestones = Fellows.Milestones(guid, person, now)
    local first = tonumber(person.first)
    local firstKey = first and Fellows.DayKey(first)
    local met = first and {
        kind = "bond",
        big = true,
        title = L.ui_fellow_met,
        detail = person.firstLevel and L.ui_fellow_met_detail:format(person.firstLevel) or nil,
        when = date("%H:%M", first),
        t = first,
    }

    local chapters = {}
    for _, day in ipairs(Fellows.Days(person)) do
        local events = {}
        -- Named bosses get a card each; the others (a raid, or more than a
        -- day keeps) are counted on the day's line.
        local unnamed = math.max(0, day.b - #day.k)
        local bosses = unnamed == 1 and L.ui_fellow_boss or unnamed > 1 and L.ui_fellow_bosses:format(unnamed) or nil
        if day.f and day.l then
            -- How long, the chapter's heading already says.
            local span = Span(day.f, day.l)
            events[#events + 1] = { kind = "fellow", title = L.ui_fellow_together,
                detail = bosses and (span .. "  ·  " .. bosses) or span, t = day.f }
        end
        for _, kill in ipairs(day.k) do
            local event = ChronicleEvent({ k = "boss", name = kill.n, zone = kill.z, t = kill.t })
            event.t = kill.t
            events[#events + 1] = event
        end
        if #events == 0 then
            -- Counted a boss, but no time yet: still a day together.
            events[1] = { kind = "fellow", title = L.ui_fellow_together, detail = bosses, t = 0 }
        end
        local tier = milestones[day.key]
        if tier then
            events[#events + 1] = {
                kind = "bond",
                big = true,
                title = L.ui_fellow_tier_up:format(string.lower(L["ui_bond_" .. tier])),
                t = day.l or day.f or 0,
            }
        end
        if met and day.key == firstKey then
            events[#events + 1], met = met, nil
        end
        table.sort(events, function(a, b)
            return (a.t or 0) > (b.t or 0)
        end)
        -- The day's own date; a day without a zone is named by it alone.
        local dayTitle = DayTitle(string.format("%04d-%02d-%02d", math.floor(day.key / 10000), math.floor(day.key / 100) % 100, day.key % 100),
            today, yesterday)
        chapters[#chapters + 1] = {
            small = day.z and dayTitle or nil,
            title = day.z or dayTitle,
            sub = L.ui_fellow_day_time:format(Duration(day.s) or L.ui_fellow_minutes:format(0)),
            events = events,
        }
    end
    -- Met before the day log, or the day fell out of it: a chapter of its own.
    if met then
        chapters[#chapters + 1] = {
            small = DayTitle(DayKey(first), today, yesterday),
            title = type(person.firstZone) == "string" and person.firstZone or DayTitle(DayKey(first), today, yesterday),
            events = { met },
        }
    end
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
    onForget = function(guid)
        local name = ns.FellowService.Forget(guid)
        if name then
            ns:Notify(L.msg_fellow_forgotten:format(name))
        end
    end,
}

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
        ns:Notify(L.msg_fellow_tidied:format(removed))
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
                list = L.ui_fellow_tidy_more:format(list, #outsiders - TIDY_NAMES)
            end
            if #outsiders == 1 then
                return L.ui_fellow_tidy_one:format(list)
            end
            return L.ui_fellow_tidy_some:format(#outsiders, list)
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
    -- Below the switches, a card to tidy the list up. It works on what is
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
            -- A switched-off feature is left out; its switch in the settings is not.
            if not tab.category or ns:IsCategoryEnabled(tab.category) then
                local where = pageTitle
                if #page.tabs > 1 then
                    where = pageTitle .. "  ·  " .. tab.label()
                end
                local context = string.lower(where)
                local hits = {}
                -- A tab that shows only part of a long list searches all of it.
                for _, block in ipairs(tab.search and tab.search() or tab.blocks()) do
                    for _, item in ipairs(block.items) do
                        if item.kind ~= "info" and item.kind ~= "aliasEdit" then
                            -- An item whose help text changes (a list of names) says what to search in.
                            local text = item.find and item.find() or (item.label() .. " " .. item.desc())
                            local haystack = string.lower(text) .. " " .. context
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

-- last: the row is the last one of its card. width: of the card.
local function RowSetItem(row, item, index, flat, last, width)
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

    local child = item.child and not flat
    local indent = (child and 44) or (PERSON_ROWS[kind] and 58) or 18
    local compact = not flat and item.compact ~= nil and item.compact()
    local padding = compact and 10 or 15
    local controlWidth = ControlWidth(row, kind)
    local textWidth = width - indent - 18 - controlWidth - (controlWidth > 0 and 24 or 0)

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
    if PERSON_ROWS[kind] then
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
    for i = 1, #cards do
        if cards[i]:IsShown() then
            CardRefresh(cards[i])
        end
    end
    UpdateResetButton()
    RefreshNav()
    RefreshTabs()
end

function Render()
    UI.CloseMenu()
    local searching = searchText ~= ""
    local page = pages[currentPage]
    local tab = CurrentTab(page)
    local blocks, key

    if searching then
        local total
        blocks, total = SearchBlocks(searchText)
        window.area.name:SetText(L.ui_search_title)
        if total > 0 then
            window.area.desc:SetText(L.ui_search_results:format(total))
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
        bar.text:SetText(L.c_only_who:format((ns.ChronicleService.Companion({ who = chronicleWho }))))
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
            RowSetItem(row, item, index, searching, index == #block.items, width)
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
function PlayEmbers(wanted)
    local playing = wanted ~= false and window ~= nil and window:IsShown() and ns:GetOption("general", "embers") == true
    for _, set in ipairs(embers) do
        set:SetPlaying(playing)
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
    local edge = UI.VLine(sidebar, "cardBorder")
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
    local line = UI.Line(sidebar, "cardBorder")
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

    local line = UI.Line(window, "cardBorder")
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
        PlayEmbers()
        Render()
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
    if not window:IsShown() then
        window:Show()
    end
    if currentPage ~= "aliases" or searchText ~= "" or CurrentTab().id ~= "names" then
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
    -- Switching a feature folds or unfolds its options, which moves rows;
    -- a main feature's switch swaps its page for a notice.
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
