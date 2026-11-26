-- Localization. Every string has an identifier key; enUS is the reference and
-- the fallback. ns.L is a thin proxy, so the language can be switched at
-- runtime without a reload (the UI re-reads its strings on LOCALE_CHANGED).

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

-- code: a locale code such as "deDE", or "auto" to follow the game client.
function ns:SetLocale(code)
    if code == nil or code == "auto" then
        code = GetLocale()
    end
    if code == "enGB" then
        code = "enUS"
    end
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

-- Locale codes that ship with the addon, reference locale first.
function ns:GetLocaleCodes()
    local codes = {}
    for code in pairs(locales) do
        if code ~= BASE then
            codes[#codes + 1] = code
        end
    end
    table.sort(codes)
    table.insert(codes, 1, BASE)
    return codes
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
