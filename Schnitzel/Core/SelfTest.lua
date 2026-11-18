-- Self-test against the real client.
--
-- The LuaJIT test suite proves the addon's own logic against a mock. This
-- file answers the other question: does the client we are running in really
-- provide what the addon assumes? "/sz test" runs the checks and stores a
-- report in SchnitzelDB.selfTest; the client writes it to disk on /reload or
-- logout, where it can be read with tools/read_selftest.lua.
--
-- Everything here is read-only except the camera probe, which changes one
-- CVar and puts it back. Nothing runs, and no event is registered, unless
-- the player asks for it ("/sz test") or switches developer mode on
-- ("/sz dev").

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
    "C_GossipInfo",
    "C_QuestLog",
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
    "ChatFrameUtil.InsertLink",
    "ChatFrameUtil.OpenChat",
    "C_Map.GetMapInfo",
    "issecretvalue",
    "securecallfunction",
    "hooksecurefunc",
    "StaticPopup_Hide",
    "StaticPopup_FindVisible",
    "StaticPopupDialogs",
    "EventRegistry.RegisterCallback",
    "CVarCallbackRegistry.RegisterCallback",
}

local EXPECT_ABSENT = {
    "GetItemInfo",
    "GetSpellInfo",
}

-- Blizzard popups the features close or fill in, by feature.
local POPUPS = {
    confirmBoP = { "LOOT_BIND" },
    acceptInvites = { "PARTY_INVITE" },
    declineDuels = { "DUEL_REQUESTED" },
    autoAccept = { "QUEST_ACCEPT" },
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
        for _, option in ipairs(feature.options) do
            if option.requires and ns.Resolve(option.requires) == nil then
                Add("feature", feature.id .. "." .. option.key, "warn", "missing API: " .. option.requires)
            end
        end
    end
end

local function CheckErrorStrings()
    local list = ns.features.hideErrors and ns.features.hideErrors.blockedGlobals
    if not list then
        return
    end
    local missing = {}
    for i = 1, #list do
        if type(_G[list[i]]) ~= "string" then
            missing[#missing + 1] = list[i]
        end
    end
    if #missing == 0 then
        Add("hideErrors", "error strings", "ok", #list .. " of " .. #list .. " exist")
    else
        Add("hideErrors", "error strings", "warn", (#list - #missing) .. " of " .. #list .. " exist; missing: " .. table.concat(missing, ", "))
    end
end

local function CheckPopups()
    local dialogs = StaticPopupDialogs
    if type(dialogs) ~= "table" then
        Add("popup", "StaticPopupDialogs", "warn", "table not found, popup names cannot be checked")
        return
    end
    local function Check(owner, which)
        if dialogs[which] ~= nil then
            Add("popup", which, "ok", owner)
        else
            Add("popup", which, "warn", "unknown popup name, used by " .. owner)
        end
    end
    for owner, names in pairs(POPUPS) do
        for i = 1, #names do
            Check(owner, names[i])
        end
    end
    local deletePopups = ns.features.easyDelete and ns.features.easyDelete.popups
    if deletePopups then
        for i = 1, #deletePopups do
            Check("easyDelete", deletePopups[i])
        end
    end
    -- easyDelete reaches the edit box through the dialog frame.
    local dialog = StaticPopup1
    if dialog then
        local how = (dialog.GetEditBox and "GetEditBox()") or (dialog.EditBox and "EditBox") or (dialog.editBox and "editBox")
        if how then
            Add("popup", "edit box access", "ok", how)
        else
            Add("popup", "edit box access", "warn", "StaticPopup1 has no GetEditBox, EditBox or editBox")
        end
    else
        Add("popup", "edit box access", "warn", "StaticPopup1 not found; check easyDelete by hand")
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

-- chatArrowKeys: every chat edit box should follow the feature's state.
local function CheckChatArrows()
    local feature = ns.features.chatArrowKeys
    if not feature then
        return
    end
    local expected = not feature.enabled
    local boxes, wrong = 0, {}
    for i = 1, NUM_CHAT_WINDOWS or 10 do
        local editBox = _G["ChatFrame" .. i .. "EditBox"]
        if editBox and editBox.GetAltArrowKeyMode then
            boxes = boxes + 1
            if editBox:GetAltArrowKeyMode() ~= expected then
                wrong[#wrong + 1] = "ChatFrame" .. i
            end
        end
    end
    if boxes == 0 then
        Add("chat", "arrow keys", "warn", "no chat edit box with GetAltArrowKeyMode found")
    elseif #wrong == 0 then
        Add("chat", "arrow keys", "ok", boxes .. " edit boxes, Alt needed: " .. tostring(expected))
    else
        Add("chat", "arrow keys", "warn", "Alt mode differs from the feature in " .. table.concat(wrong, ", "))
    end
end

local function CheckCamera()
    local feature = ns.features.cameraZoom
    if not (feature and feature.zoomCVar and C_CVar and C_CVar.GetCVar and C_CVar.SetCVar) then
        return
    end
    local cvar = feature.zoomCVar
    local before = C_CVar.GetCVar(cvar)
    local default = C_CVar.GetCVarDefault and C_CVar.GetCVarDefault(cvar)
    if tonumber(before) == nil then
        Add("camera", cvar, "fail", "CVar not readable: " .. Describe(before))
        return
    end
    if feature.enabled or (InCombatLockdown and InCombatLockdown()) then
        Add("camera", cvar, "ok", "current " .. before .. ", default " .. Describe(default) .. " (probe skipped)")
        return
    end
    -- Try each candidate, note what the client keeps, then restore.
    local accepted = {}
    local highest
    for i = 1, #feature.zoomCandidates do
        local target = feature.zoomCandidates[i]
        pcall(C_CVar.SetCVar, cvar, target)
        local kept = tonumber(C_CVar.GetCVar(cvar)) or 0
        accepted[#accepted + 1] = target .. " -> " .. kept
        if not highest and kept >= target - 0.01 then
            highest = target
        end
    end
    pcall(C_CVar.SetCVar, cvar, before)
    local detail = "current " .. before .. ", default " .. Describe(default) .. ", tried " .. table.concat(accepted, "; ")
    if highest then
        Add("camera", cvar, "ok", detail)
    else
        Add("camera", cvar, "warn", detail .. " (no candidate accepted)")
    end
end

local function CheckMap()
    local map = WorldMapFrame
    if not map then
        Add("map", "WorldMapFrame", "warn", "not loaded yet; open the map once and run the test again")
    else
        local canvas = map.ScrollContainer
        if canvas and canvas.GetNormalizedCursorPosition then
            Add("map", "cursor position", "ok", "ScrollContainer:GetNormalizedCursorPosition")
        else
            Add("map", "cursor position", "warn", "WorldMapFrame.ScrollContainer or its cursor method is missing")
        end
    end
    if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then
        return
    end
    local mapID = C_Map.GetBestMapForUnit("player")
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if not position then
        Add("map", "player position", "warn", "no position on map " .. Describe(mapID) .. " (normal inside instances)")
        return
    end
    local x = position:GetXY()
    if ns.IsSecret(x) then
        Add("map", "player position", "warn", "position is a secret value here")
    else
        Add("map", "player position", "ok", "map " .. Describe(mapID))
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
    CheckErrorStrings,
    CheckPopups,
    CheckMedia,
    CheckFonts,
    CheckChatArrows,
    CheckCamera,
    CheckMap,
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
