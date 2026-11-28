-- Localization. Every string has an identifier key; enUS is the reference and
-- the fallback. ns.L is a thin proxy, so the language can be switched at
-- runtime without a reload (the UI re-reads its strings on LOCALE_CHANGED).
--
--   ns.L.key              the text in the addon's language
--   ns.Plural(key, n)     the text for the number n: <key>_one, <key>_few or
--                         <key>, as the language's grammar wants
--   ns.PluralForm(n, code) which form that is: "one", "few" or nil
--   ns.Upper, ns.Lower    upper and lower case beyond A-Z (é, ł, і, ж ...)
--   ns.Capital(text)      the first letter in upper case

local _, ns = ...

local locales = {}
ns.locales = locales

local BASE = "enUS"
local active, activeCode

function ns:NewLocale(code)
    local strings = locales[code]
    if not strings then
        strings = {}
        locales[code] = strings
    end
    return strings
end

ns.L = setmetatable({}, {
    __index = function(_, key)
        local text = active and active[key]
        if text == nil then
            local base = locales[BASE]
            text = base and base[key]
        end
        if text == nil then
            return key
        end
        return text
    end,
    __newindex = function()
        error("ns.L is read-only; add strings in Locales/*.lua", 2)
    end,
})

-- Clients whose language another translation covers.
local SAME_AS = { enGB = "enUS", esMX = "esES" }

-- Languages that ship but are not offered yet. In game (2026-11-26) Polish
-- letters showed only in part and Ukrainian ones not at all. Their files stay
-- and are tested; the language option does not list them, and a saved
-- choice of one follows the client. See docs/languages.md.
local NOT_OFFERED = { plPL = true, ukUA = true }

-- code: a locale code such as "deDE", or "auto" to follow the game client.
-- Polish (plPL) and Ukrainian (ukUA) have no game client: only the language
-- option chooses them, once it offers them.
function ns:SetLocale(code)
    if code == nil or code == "auto" or NOT_OFFERED[code] then
        code = GetLocale()
    end
    code = SAME_AS[code] or code
    if not locales[code] then
        code = BASE
    end
    local strings = locales[code]
    if strings == active then
        return
    end
    active, activeCode = strings, code
    ns:Fire("LOCALE_CHANGED")
end

-- The locale code the addon speaks right now ("enUS", "deDE"), which can
-- differ from the client's: the language option overrides GetLocale().
function ns:GetLocaleCode()
    return activeCode or BASE
end

-- Locale codes the language option offers, reference locale first; with
-- `all`, also those that ship but are not offered yet.
function ns:GetLocaleCodes(all)
    local codes = {}
    for code in pairs(locales) do
        if code ~= BASE and (all or not NOT_OFFERED[code]) then
            codes[#codes + 1] = code
        end
    end
    table.sort(codes)
    table.insert(codes, 1, BASE)
    return codes
end

-- Whether the language option offers this locale code.
function ns:IsLocaleOffered(code)
    return locales[code] ~= nil and not NOT_OFFERED[code]
end

-- Times and dates, as the player chose under Settings › General: the clock
-- (general.timeFormat) and the order of a date (general.dateFormat, "auto"
-- for the language's own, c_date). Read at the moment they are written, so a
-- change shows the next time the window draws.
ns.TIME_FORMATS = { "24h", "12h" }
ns.DATE_FORMATS = { "{y}-{m}-{d}", "{d}.{m}.{y}", "{m}/{d}/{y}", "{d}/{m}/{y}" }

local knownDates = {}
for _, pattern in ipairs(ns.DATE_FORMATS) do
    knownDates[pattern] = true
end

-- "21:40", or on the 12-hour clock "9:40 PM" (midnight is 12 AM, noon 12 PM);
-- `format` ("24h", "12h") instead of the chosen one if given.
function ns.FormatTime(timestamp, format)
    if (format or ns:GetOption("general", "timeFormat")) ~= "12h" then
        return date("%H:%M", timestamp)
    end
    local hour = tonumber(date("%H", timestamp)) or 0
    local text = hour < 12 and ns.L.g_timeFormat_am or ns.L.g_timeFormat_pm
    return text:format((hour + 11) % 12 + 1, date("%M", timestamp))
end

-- The order of a date in effect: the chosen one, else the language's.
function ns.DatePattern()
    local pattern = ns:GetOption("general", "dateFormat")
    return knownDates[pattern] and pattern or ns.L.c_date
end

-- A day in the order in effect ("2026-11-19", "19.11.2026", "11/19/2026" ...),
-- or in `pattern` (one of ns.DATE_FORMATS) if given. Year, month and day as
-- written, with their leading zeros.
function ns.FormatDate(year, month, day, pattern)
    return (string.gsub(pattern or ns.DatePattern(), "{(%a)}", { d = day, m = month, y = year }))
end

---------------------------------------------------------------------------
-- Numbers: the form of a text a number takes
---------------------------------------------------------------------------

-- Which form a whole number takes in a language (the CLDR plural rules):
-- "one" and "few" have keys of their own (<key>_one, <key>_few); for any
-- other form (English "other", Polish "many" ...) the text is <key> itself.
local function OneIsOne(n)
    return n == 1 and "one" or nil
end

local function Few(n)
    local ten, hundred = n % 10, n % 100
    return ten >= 2 and ten <= 4 and (hundred < 12 or hundred > 14)
end

local PLURAL_RULES = {
    fr = function(n)
        return n <= 1 and "one" or nil -- 0 and 1
    end,
    pl = function(n)
        return n == 1 and "one" or Few(n) and "few" or nil
    end,
    uk = function(n)
        if n % 10 == 1 and n % 100 ~= 11 then
            return "one" -- 1, 21, 31 ...
        end
        return Few(n) and "few" or nil -- 2-4, 22-24 ...
    end,
}

-- The form the number n takes in a language (code: a locale code, else the
-- one spoken now): "one", "few" or nil for the key itself.
function ns.PluralForm(n, code)
    n = math.abs(math.floor(tonumber(n) or 0))
    return (PLURAL_RULES[string.sub(code or activeCode or BASE, 1, 2)] or OneIsOne)(n)
end

-- The text of a key for the number n, still to be formatted:
-- ns.Plural("c_ch_events", count):format(count). An untranslated key
-- follows English and its rule.
function ns.Plural(key, n)
    local strings, code = active, activeCode
    if not strings or strings[key] == nil then
        strings, code = locales[BASE], BASE
    end
    local form = ns.PluralForm(n, code)
    local text = form and strings[key .. "_" .. form]
    if text == nil then
        text = strings[key]
    end
    if text == nil then
        return key
    end
    return text
end

-- Names as a sentence lists them: "Mira", "Mira and Borin", "Mira, Borin and
-- Lysa". With `most`, no more than that many parts: the last then counts the
-- rest, in the words of more(count) ("Mira, Borin and 2 more"). The caller
-- writes that text, so its ns.Plural names its key where the test looks.
function ns.NameList(names, most, more)
    local shown = {}
    for index = 1, most and math.min(#names, most) or #names do
        shown[index] = names[index]
    end
    if most and #names > most then
        shown[most] = more(#names - most + 1)
    end
    if #shown < 2 then
        return shown[1] or ""
    end
    return ns.L.c_and:format(table.concat(shown, ", ", 1, #shown - 1), shown[#shown])
end

---------------------------------------------------------------------------
-- Upper and lower case
---------------------------------------------------------------------------

-- string.upper and string.lower change only A-Z. These also change the
-- letters of Latin-1, Latin Extended-A and Cyrillic that the languages of
-- Famulus need (é, ł, ż, і, ї, ж ...); each is two bytes in UTF-8. The
-- tables are made on first use.
local UPPER, LOWER
local TWO_BYTES = "[\195-\211][\128-\191]" -- U+00C0 to U+04FF

local function Char(code)
    return string.char(0xC0 + math.floor(code / 64), 0x80 + code % 64)
end

local function MakeCases()
    UPPER, LOWER = {}, {}
    local function Pair(upper, lower)
        local u, l = Char(upper), Char(lower)
        UPPER[l], LOWER[u] = u, l
    end
    -- Letters side by side, upper case first: from, from + 1, ... to.
    local function Pairs(from, to)
        for code = from, to - 1, 2 do
            Pair(code, code + 1)
        end
    end
    for code = 0xC0, 0xDE do -- À-Þ, not ×
        if code ~= 0xD7 then
            Pair(code, code + 0x20)
        end
    end
    Pairs(0x100, 0x12F) -- Ā-į
    Pairs(0x132, 0x137) -- Ĳ-ķ (İ and ı are no pair)
    Pairs(0x139, 0x148) -- Ĺ-ň (Ł ł, Ń ń)
    Pairs(0x14A, 0x177) -- Ŋ-ŷ (Ś ś, Œ œ)
    Pair(0x178, 0xFF) -- Ÿ ÿ
    Pairs(0x179, 0x17E) -- Ź-ž
    for code = 0x400, 0x40F do -- Ѐ-Џ (Є, І, Ї ...)
        Pair(code, code + 0x50)
    end
    for code = 0x410, 0x42F do -- А-Я
        Pair(code, code + 0x20)
    end
    Pairs(0x460, 0x481) -- Ѡ-ҁ
    Pairs(0x48A, 0x4BF) -- Ҋ-ҿ (Ґ ґ)
    Pair(0x4C0, 0x4CF) -- Ӏ ӏ
    Pairs(0x4C1, 0x4CE) -- Ӂ-ӎ
    Pairs(0x4D0, 0x4FF) -- Ӑ-ӿ
end

function ns.Upper(text)
    if not UPPER then
        MakeCases()
    end
    return (string.gsub(string.upper(text), TWO_BYTES, UPPER))
end

function ns.Lower(text)
    if not LOWER then
        MakeCases()
    end
    return (string.gsub(string.lower(text), TWO_BYTES, LOWER))
end

-- "kennengelernt ..." becomes "Kennengelernt ...", "вчора ..." "Вчора ...".
function ns.Capital(text)
    local first, rest = string.match(text, "^([%z\1-\127\194-\244][\128-\191]*)(.*)$")
    if not first then
        return text
    end
    return ns.Upper(first) .. rest
end
