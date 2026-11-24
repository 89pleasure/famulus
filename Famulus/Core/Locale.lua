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
