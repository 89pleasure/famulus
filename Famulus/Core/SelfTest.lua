-- Self-test against the real client.
--
-- The LuaJIT test suite proves the addon's own logic against a mock. This
-- file answers the other question: does the client we are running in really
-- provide what the addon assumes? "/fam test" runs the checks and stores a
-- report in FamulusDB.selfTest; the client writes it to disk on /reload or
-- logout, where it can be read with tools/read_selftest.lua.
--
-- Everything here is read-only. Nothing runs, and no event is registered, unless
-- the player asks for it ("/fam test") or switches developer mode on
-- ("/fam dev").

local ADDON_NAME, ns = ...
local L = ns.L

local REPORT_SCHEMA = 1
local MAX_LOG_ENTRIES = 100
local MAX_CHAT_LINES = 8

-- Client API the project notes (AGENTS.md) claim to exist or to be removed.
-- A mismatch is a warning: the notes are wrong, not necessarily the addon.
local EXPECT_PRESENT = {
    "C_Container",
    "C_AddOns",
    "C_Item.GetItemInfo",
    "C_Spell.GetSpellInfo",
    "C_Map",
    "C_Timer.After",
    "C_Timer.NewTicker",
    "TooltipDataProcessor.AddTooltipPostCall",
    "Settings.RegisterAddOnCategory",
    "Settings.RegisterCanvasLayoutCategory",
    "MenuUtil",
    "ChatFrameUtil.AddMessageEventFilter",
    "ChatFrameUtil.AddSenderNameFilter",
    "Menu.ModifyMenu",
    "UnitNameUnmodified",
    "C_Map.GetMapInfo",
    "issecretvalue",
    "securecallfunction",
    "hooksecurefunc",
    "EventRegistry.RegisterCallback",
}

local EXPECT_ABSENT = {
    "GetItemInfo",
    "GetSpellInfo",
}

-- A printable description of a value that is safe for secret values.
local function Describe(value)
    if ns.IsSecret(value) then
        return "<secret>"
    end
    local kind = type(value)
    if kind == "string" or kind == "number" or kind == "boolean" or kind == "nil" then
        return tostring(value)
    end
    return kind
end

local report
local probeFrame

local function Add(group, name, status, detail)
    local checks = report.checks
    checks[#checks + 1] = { group = group, name = name, status = status, detail = detail }
    report.summary[status] = report.summary[status] + 1
end

local function CheckClient()
    local version, build, buildDate, tocVersion
    if GetBuildInfo then
        version, build, buildDate, tocVersion = GetBuildInfo()
    end
    report.client = {
        version = Describe(version),
        build = Describe(build),
        date = Describe(buildDate),
        toc = Describe(tocVersion),
        locale = GetLocale and GetLocale() or "?",
    }

    local getInterface = C_AddOns and C_AddOns.GetAddOnInterfaceVersion
    local addonToc = getInterface and getInterface(ADDON_NAME)
    if addonToc and tocVersion then
        if addonToc == tocVersion then
            Add("client", "interface version", "ok", Describe(tocVersion))
        else
            Add("client", "interface version", "warn", "toc file says " .. Describe(addonToc) .. ", client is " .. Describe(tocVersion))
        end
    else
        Add("client", "interface version", "ok", "client " .. Describe(tocVersion) .. " (toc value not readable)")
    end
end

local function CheckKnownApi()
    for i = 1, #EXPECT_PRESENT do
        local path = EXPECT_PRESENT[i]
        local value = ns.Resolve(path)
        if value ~= nil then
            Add("api", path, "ok", type(value))
        else
            Add("api", path, "warn", "expected, but missing")
        end
    end
    for i = 1, #EXPECT_ABSENT do
        local path = EXPECT_ABSENT[i]
        if ns.Resolve(path) == nil then
            Add("api", path, "ok", "removed as expected")
        else
            Add("api", path, "warn", "expected to be removed, but exists")
        end
    end
end

local function CheckFeatures()
    for i = 1, #ns.featureList do
        local feature = ns.featureList[i]
        local missing = {}
        if feature.requires then
            for _, path in ipairs(feature.requires) do
                if ns.Resolve(path) == nil then
                    missing[#missing + 1] = path
                end
            end
        end
        report.features[feature.id] = {
            available = #missing == 0 and feature:IsShown(),
            enabled = feature.enabled,
            failed = feature.failed or false,
        }
        if not feature:IsShown() then
            Add("feature", feature.id, "ok", "addon " .. feature.addon .. " not loaded")
        elseif #missing > 0 then
            Add("feature", feature.id, "fail", "missing API: " .. table.concat(missing, ", "))
        elseif feature.failed then
            Add("feature", feature.id, "fail", "OnEnable raised an error")
        else
            Add("feature", feature.id, "ok", feature.enabled and "enabled" or "available")
        end
    end
end

local function CheckMedia()
    if not (ns.UI and ns.UI.media and CreateFrame) then
        return
    end
    if not probeFrame then
        probeFrame = CreateFrame("Frame")
        probeFrame:Hide()
    end
    local names = {}
    for name in pairs(ns.UI.media) do
        names[#names + 1] = name
    end
    table.sort(names)
    for i = 1, #names do
        local texture = probeFrame:CreateTexture()
        local loaded = texture:SetTexture(ns.UI.media[names[i]])
        -- The return value is the client's own verdict; a green square in
        -- the window is the visual sign of the same problem.
        if loaded then
            Add("media", names[i], "ok", "loaded")
        else
            Add("media", names[i], "warn", "SetTexture returned " .. Describe(loaded) .. "; look for green squares in the window")
        end
    end
    -- The game's icons the chronicle uses as pictures.
    local kinds = {}
    for kind in pairs(ns.UI.gameIcons or {}) do
        kinds[#kinds + 1] = kind
    end
    table.sort(kinds)
    for i = 1, #kinds do
        local texture = probeFrame:CreateTexture()
        local loaded = texture:SetTexture(ns.UI.gameIcons[kinds[i]])
        if loaded then
            Add("media", "icon " .. kinds[i], "ok", "loaded")
        else
            Add("media", "icon " .. kinds[i], "warn", "the client has no " .. ns.UI.gameIcons[kinds[i]] .. "; the chronicle's picture stays empty")
        end
    end
end

-- The window uses its own font files. SetFont returns false when the
-- client cannot load one; the window then falls back to the game's font.
local function CheckFonts()
    if not (ns.UI and ns.UI.fonts and CreateFrame) then
        return
    end
    if not probeFrame then
        probeFrame = CreateFrame("Frame")
        probeFrame:Hide()
    end
    local names = {}
    for name in pairs(ns.UI.fonts) do
        names[#names + 1] = name
    end
    table.sort(names)
    for i = 1, #names do
        local text = probeFrame:CreateFontString()
        local loaded = text:SetFont(ns.UI.fonts[names[i]], 12, "")
        if loaded then
            Add("media", "font " .. names[i], "ok", "loaded")
        else
            Add("media", "font " .. names[i], "warn", "SetFont returned " .. Describe(loaded) .. "; the window uses the game's font")
        end
    end
end

-- The alias features match characters by name. Records how this client
-- spells names, without storing anybody's name in the report.
local function CheckNames()
    local consts = Constants and Constants.CharacterNameSeparatorConsts
    if consts then
        Add("names", "separators", "ok", string.format("surname %q, realm %q",
            Describe(consts.CHARACTERNAME_SURNAME_SEPARATOR), Describe(consts.CHARACTERNAME_REALMNAME_SEPARATOR)))
    else
        Add("names", "separators", "warn", "Constants.CharacterNameSeparatorConsts is missing")
    end
    if UnitName then
        local name, second = UnitName("player")
        local shape = "name " .. (ns.IsSecret(name) and "secret" or type(name))
        if not ns.IsSecret(name) and type(name) == "string" then
            shape = shape .. (string.find(name, "[%s%-]") and " (contains a separator)" or " (one word)")
        end
        shape = shape .. ", second value " .. (ns.IsSecret(second) and "secret" or type(second))
        Add("names", "UnitName(player)", "ok", shape)
    end
    -- An alias for a BattleTag finds its characters through the Battle.net
    -- friends list: how many friends it shows in this game, and how their
    -- character names are spelled.
    if BNGetNumFriends and C_BattleNet and C_BattleNet.GetFriendAccountInfo then
        local total = BNGetNumFriends()
        local inGame, shapes = 0, {}
        if not ns.IsSecret(total) and type(total) == "number" then
            for i = 1, total do
                local info = C_BattleNet.GetFriendAccountInfo(i)
                local game = type(info) == "table" and info.gameAccountInfo
                local name = type(game) == "table" and game.characterName
                if ns.ChatService.IsPlainText(name) and game.wowProjectID == WOW_PROJECT_ID then
                    inGame = inGame + 1
                    shapes[string.find(name, "%s") and "space" or string.find(name, "-", 1, true) and "hyphen" or "one word"] = true
                end
            end
        end
        local seen = {}
        for shape in pairs(shapes) do
            seen[#seen + 1] = shape
        end
        table.sort(seen)
        Add("names", "Battle.net friends", "ok", string.format("%s friends, %d on a character of this game (project %s), names: %s",
            Describe(total), inGame, Describe(WOW_PROJECT_ID), #seen > 0 and table.concat(seen, ", ") or "none seen"))
    else
        Add("names", "Battle.net friends", "warn", "BNGetNumFriends or C_BattleNet.GetFriendAccountInfo is missing")
    end
    local menu = ns.features.aliasMenu
    if menu and Menu and Menu.GetOpenMenuTags then
        Add("names", "context menu", "ok", #menu.TAGS .. " menu tags hooked while the feature is on")
    elseif menu then
        Add("names", "context menu", "warn", "Menu.GetOpenMenuTags is missing; the menu API may differ")
    end
end

local function CheckIdleCost()
    local active, total = ns:CountActiveFeatures()
    local memory
    if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage then
        local ok, value = pcall(function()
            UpdateAddOnMemoryUsage()
            return GetAddOnMemoryUsage(ADDON_NAME)
        end)
        if ok and type(value) == "number" and not ns.IsSecret(value) then
            memory = math.floor(value + 0.5)
        end
    end
    report.idle = {
        events = ns:CountRegisteredEvents(),
        activeFeatures = active,
        totalFeatures = total,
        memoryKB = memory,
    }
end

local CHECKS = {
    CheckClient,
    CheckKnownApi,
    CheckFeatures,
    CheckMedia,
    CheckFonts,
    CheckNames,
    CheckIdleCost,
}

local function OnCheckError(message)
    return Describe(message)
end

-- Runs every check and stores the report. Returns the report.
function ns:RunSelfTest()
    report = {
        schema = REPORT_SCHEMA,
        time = date and date("%Y-%m-%d %H:%M:%S") or "?",
        addonVersion = ns.version,
        summary = { ok = 0, warn = 0, fail = 0 },
        checks = {},
        features = {},
    }
    for i = 1, #CHECKS do
        -- A check that errors must not hide the results of the others.
        local ok, message = xpcall(CHECKS[i], OnCheckError)
        if not ok then
            Add("selftest", "check " .. i, "fail", "check raised an error: " .. tostring(message))
        end
    end
    local log = ns.global and ns.global.devLog
    report.loggedProblems = log and #log or 0

    local result = report
    report = nil
    if ns.global then
        ns.global.selfTest = result
    end

    local summary = result.summary
    ns:Print(L.msg_selftest:format(summary.ok, summary.warn, summary.fail))
    local printed = 0
    for i = 1, #result.checks do
        local check = result.checks[i]
        if check.status ~= "ok" and printed < MAX_CHAT_LINES then
            printed = printed + 1
            ns:Print(string.format("  [%s] %s / %s: %s", check.status, check.group, check.name, check.detail))
        end
    end
    return result
end

---------------------------------------------------------------------------
-- Developer mode: log blocked actions and Lua warnings, test after login
---------------------------------------------------------------------------

local devOwner = {}

local function Log(kind, text)
    local log = ns.global.devLog
    if not log then
        log = {}
        ns.global.devLog = log
    end
    if #log >= MAX_LOG_ENTRIES then
        table.remove(log, 1)
    end
    log[#log + 1] = { time = date and date("%Y-%m-%d %H:%M:%S") or "?", kind = kind, text = text }
end

local function OnActionBlocked(_, event, addon, action)
    if not ns.IsSecret(addon) and addon == ADDON_NAME then
        Log(event, Describe(action))
    end
end

local function OnLuaWarning(_, event, _, text)
    if not ns.IsSecret(text) and type(text) == "string" and text:find(ADDON_NAME, 1, true) then
        Log(event, text)
    end
end

local function SetDevEvents(enabled)
    if enabled then
        ns:RegisterEvent("ADDON_ACTION_BLOCKED", devOwner, OnActionBlocked)
        ns:RegisterEvent("ADDON_ACTION_FORBIDDEN", devOwner, OnActionBlocked)
        ns:RegisterEvent("LUA_WARNING", devOwner, OnLuaWarning)
    else
        ns:UnregisterEvent("ADDON_ACTION_BLOCKED", devOwner)
        ns:UnregisterEvent("ADDON_ACTION_FORBIDDEN", devOwner)
        ns:UnregisterEvent("LUA_WARNING", devOwner)
    end
end

-- A note for the developer log; kept only in developer mode. Never pass
-- names or other text of the player here.
function ns:DevLog(kind, text)
    if ns.global and ns.global.dev == true then
        Log(kind, text)
    end
end

function ns:IsDevMode()
    return ns.global ~= nil and ns.global.dev == true
end

function ns:SetDevMode(enabled)
    enabled = enabled and true or false
    if not ns.global or enabled == self:IsDevMode() then
        return
    end
    ns.global.dev = enabled or nil
    if not enabled then
        ns.global.devLog = nil
    end
    SetDevEvents(enabled)
    ns:Print(enabled and L.msg_dev_on or L.msg_dev_off)
end

ns:On("LOGIN", function()
    if not ns:IsDevMode() then
        return
    end
    SetDevEvents(true)
    -- Give load-on-demand parts of the default UI a moment to settle.
    C_Timer.After(3, function()
        if ns:IsDevMode() then
            ns:RunSelfTest()
        end
    end)
end)
