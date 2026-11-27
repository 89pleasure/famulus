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
local MAX_TRACE_ENTRIES = 500
local FOLD_SECONDS = 2 -- the same trace line again within this counts up the last one
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
    -- What Core/GroupService.lua and the fellow travellers' page lean on.
    "IsInRaid",
    "IsInInstance",
    "UnitIsConnected",
    "UnitClass",
    "UNKNOWNOBJECT",
    "LOCALIZED_CLASS_NAMES_MALE",
    -- What Core/SocialService.lua asks to tell friends and guild members.
    "C_FriendList.IsFriend",
    "UnitIsInMyGuild",
    "C_BattleNet.GetAccountInfoByGUID",
    "C_GuildInfo.GuildRoster",
    "C_FriendList.ShowFriends",
    "BNConnected",
    -- What Modules/Fellows/NearbyService.lua uses to tell who is nearby:
    -- Battle.net friends in this game, who of them is out of reach, quiet
    -- places, and the whisper (to Battle.net friends by Battle.net).
    "BNET_CLIENT_WOW",
    "WOW_PROJECT_ID",
    "C_BattleNet.GetGameAccountInfoByGUID",
    "UnitFactionGroup",
    "IsResting",
    "UnitOnTaxi",
    "ChatFrameUtil.SendTell",
    "ChatFrameUtil.SendBNetTell",
    -- What Modules/Chronicle/Sharing.lua reads from SendAddonMessage: a
    -- refused message waits and goes again, none to someone offline.
    "Enum.SendAddonMessageResult.AddonMessageThrottle",
    "Enum.SendAddonMessageResult.AddOnMessageLockdown",
    "Enum.SendAddonMessageResult.TargetOffline",
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
local probeCooldown -- a Cooldown frame in it, for the crest's ring

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
        elseif #missing > 0 and feature.addon then
            -- The other addon is there, in a version without what the feature
            -- needs (Guildy without the name API of the fork): the feature is
            -- simply not offered, nothing in Famulus is broken.
            Add("feature", feature.id, "ok", "addon " .. feature.addon .. " lacks " .. table.concat(missing, ", ")
                .. "; the feature is not offered")
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
    -- The crest of a fellow traveller: the game's class icons, and the ring
    -- drawn as a paused Cooldown swipe.
    local classes = probeFrame:CreateTexture()
    if classes:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles") and type(CLASS_ICON_TCOORDS) == "table" then
        Add("media", "class icons", "ok", "loaded")
    else
        Add("media", "class icons", "warn", "no class icons or CLASS_ICON_TCOORDS; crests show the initial")
    end
    probeCooldown = probeCooldown or CreateFrame("Cooldown", nil, probeFrame)
    local cooldown = probeCooldown
    if cooldown.Pause and cooldown.SetSwipeTexture and cooldown.Clear then
        Add("media", "ring", "ok", "Cooldown can hold a swipe")
    else
        Add("media", "ring", "warn", "Cooldown lacks Pause, SetSwipeTexture or Clear; the ring shows no progress")
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
        -- The client loads a font only for visible text, so this hidden probe
        -- says yes only once the window has used the file.
        local path = ns.UI.fonts[names[i]]
        local text = probeFrame:CreateFontString()
        local state = ns.UI.fontLoaded and ns.UI.fontLoaded[path]
        if state or text:SetFont(path, 12, "") then
            Add("media", "font " .. names[i], "ok", "loaded")
        elseif state == false then
            Add("media", "font " .. names[i], "warn", "the window asked for it, but the client has not loaded it; the window uses the game's font")
        else
            Add("media", "font " .. names[i], "ok", "not used yet; open the window, then run /fam test again to check it")
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
        -- "Who is nearby" tells who is out of reach by the mode in the rich
        -- presence ("Forever - PvP - ...") and the faction: the player's own
        -- mode, the friends' modes, and for how many the faction is named.
        local Mode = ns.NearbyService.Mode
        local ownMode
        local guid = UnitGUID and UnitGUID("player")
        if C_BattleNet.GetGameAccountInfoByGUID and ns.ChatService.IsPlainText(guid) then
            local ok, own = pcall(C_BattleNet.GetGameAccountInfoByGUID, guid)
            ownMode = ok and not ns.IsSecret(own) and type(own) == "table" and Mode(own.richPresence) or nil
        end
        local modes, factions, noMode = {}, 0, 0
        if not ns.IsSecret(total) and type(total) == "number" then
            for i = 1, total do
                local info = C_BattleNet.GetFriendAccountInfo(i)
                local game = type(info) == "table" and info.gameAccountInfo
                local name = type(game) == "table" and game.characterName
                if ns.ChatService.IsPlainText(name) and game.wowProjectID == WOW_PROJECT_ID then
                    inGame = inGame + 1
                    shapes[string.find(name, "%s") and "space" or string.find(name, "-", 1, true) and "hyphen" or "one word"] = true
                    local mode = Mode(game.richPresence)
                    if mode then
                        modes[mode] = (modes[mode] or 0) + 1
                    else
                        noMode = noMode + 1
                    end
                    if ns.ChatService.IsPlainText(game.factionName) then
                        factions = factions + 1
                    end
                end
            end
        end
        local function Sorted(set)
            local list = {}
            for each in pairs(set) do
                list[#list + 1] = each
            end
            table.sort(list)
            return #list > 0 and table.concat(list, ", ") or "none seen"
        end
        Add("names", "Battle.net friends", "ok", string.format("%s friends, %d on a character of this game (project %s), names: %s",
            Describe(total), inGame, Describe(WOW_PROJECT_ID), Sorted(shapes)))
        local counted = {}
        for mode, count in pairs(modes) do
            counted[mode .. " " .. count] = true
        end
        Add("names", "Battle.net modes", ownMode and "ok" or "warn", string.format(
            "own mode %s; friends: %s, %d without; faction named for %d",
            ownMode or "unknown (only the faction tells who is out of reach)", Sorted(counted), noMode, factions))
    else
        Add("names", "Battle.net friends", "warn", "BNGetNumFriends or C_BattleNet.GetFriendAccountInfo is missing")
    end
    -- Tidying up the fellow travellers compares with the friends list and the
    -- guild roster, also for people who are offline: whether both list them,
    -- and with GUIDs. Counts only, no names.
    local IsPlainText = ns.ChatService.IsPlainText
    if C_FriendList and C_FriendList.GetNumFriends and C_FriendList.GetFriendInfoByIndex then
        local total = C_FriendList.GetNumFriends()
        local withGuid = 0
        if not ns.IsSecret(total) and type(total) == "number" then
            for i = 1, total do
                local info = C_FriendList.GetFriendInfoByIndex(i)
                if not ns.IsSecret(info) and type(info) == "table" and IsPlainText(info.guid) then
                    withGuid = withGuid + 1
                end
            end
        end
        Add("names", "friends list", "ok", string.format("%s friends, %d with a GUID", Describe(total), withGuid))
    end
    if IsInGuild and GetNumGuildMembers and GetGuildRosterInfo then
        local inGuild = IsInGuild()
        if ns.IsSecret(inGuild) or not inGuild then
            Add("names", "guild roster", "ok", "not in a guild")
        else
            local total, online = GetNumGuildMembers()
            local usable = not ns.IsSecret(total) and type(total) == "number"
            local offline, withGuid = 0, 0
            for i = 1, usable and total or 0 do
                local _, _, _, _, _, _, _, _, isOnline, _, _, _, _, _, _, _, guid = GetGuildRosterInfo(i)
                if IsPlainText(guid) then
                    withGuid = withGuid + 1
                end
                if not ns.IsSecret(isOnline) and not isOnline then
                    offline = offline + 1
                end
            end
            Add("names", "guild roster", usable and total > 0 and "ok" or "warn", string.format(
                "%s members (%s online), %d listed as offline, %d with a GUID", Describe(total), Describe(online), offline, withGuid))
        end
    end
    -- Aliases in chat find the name in the game's notices that someone came
    -- online (in a player link) or went offline (as plain text, once).
    local online, offline = ERR_FRIEND_ONLINE_SS, ERR_FRIEND_OFFLINE_S
    local linked = type(online) == "string" and string.find(online, "|Hplayer:", 1, true) ~= nil
    local slots = type(offline) == "string" and select(2, string.gsub(offline, "%%s", "")) or 0
    Add("names", "online notices", linked and slots == 1 and "ok" or "warn", string.format(
        "online line %s, offline line has %d name slot(s)", linked and "links the name" or "has no player link", slots))
    local menu = ns.features.aliasMenu
    if menu and Menu and Menu.GetOpenMenuTags then
        Add("names", "context menu", "ok", #menu.TAGS .. " menu tags hooked while the feature is on")
    elseif menu then
        Add("names", "context menu", "warn", "Menu.GetOpenMenuTags is missing; the menu API may differ")
    end
end

-- The chronicle knows abilities and items by the game's IDs, most of them
-- taken from Classic: whether this client knows each one. One that it does
-- not know is never recorded; the line names it.
local function CheckChronicleIds()
    local Chronicle = ns.ChronicleService
    if not Chronicle then
        return
    end
    local IsPlainText = ns.ChatService.IsPlainText
    if C_Spell and C_Spell.GetSpellName then
        local total, missing = 0, {}
        for _, ability in ipairs(Chronicle.abilities) do
            local spells = { ability.spell }
            for _, spell in ipairs(ability.also or {}) do
                spells[#spells + 1] = spell
            end
            for _, spell in ipairs(spells) do
                total = total + 1
                if not IsPlainText(C_Spell.GetSpellName(spell)) then
                    missing[#missing + 1] = spell .. " (" .. ability.id .. ")"
                end
            end
        end
        if #missing == 0 then
            Add("chronicle", "ability spells", "ok", "the client knows all " .. total)
        else
            Add("chronicle", "ability spells", "warn", string.format("%d of %d unknown to the client, never recorded: %s",
                #missing, total, table.concat(missing, ", ")))
        end
    else
        Add("chronicle", "ability spells", "warn", "C_Spell.GetSpellName is missing; the IDs cannot be checked")
    end
    if C_Item and C_Item.GetItemInfoInstant then
        local missing = {}
        for _, item in ipairs(Chronicle.items) do
            if C_Item.GetItemInfoInstant(item.item) == nil then
                missing[#missing + 1] = tostring(item.item)
            end
        end
        if #missing == 0 then
            Add("chronicle", "special items", "ok", "the client knows all " .. #Chronicle.items)
        else
            Add("chronicle", "special items", "warn", string.format("%d of %d unknown to the client, never recorded: %s",
                #missing, #Chronicle.items, table.concat(missing, ", ")))
        end
    else
        Add("chronicle", "special items", "warn", "C_Item.GetItemInfoInstant is missing; the IDs cannot be checked")
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
    CheckChronicleIds,
    CheckIdleCost,
}

local function OnCheckError(message)
    return Describe(message)
end

-- Runs every check and stores the report. Returns the report. quiet: no
-- lines in the chat (the bug report runs it for its own text).
function ns:RunSelfTest(quiet)
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
    if quiet then
        return result
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

-- The trace: what the addon does step by step, where a feature cannot be
-- followed otherwise (sharing: every message sent and received, and why one
-- was ignored). Kept only in developer mode, at most MAX_TRACE_ENTRIES, in
-- FamulusDB.devTrace; tools/read_selftest.lua prints it. The same line again
-- within FOLD_SECONDS counts up the last one (twenty entries caught up are
-- one line), and each session begins with a line of its own. Never pass names
-- or other text of the player here.
local traceStarted, lastTraceAt = false, nil

local function TraceLine(trace, kind, text)
    if #trace >= MAX_TRACE_ENTRIES then
        table.remove(trace, 1)
    end
    trace[#trace + 1] = { time = date and date("%Y-%m-%d %H:%M:%S") or "?", kind = kind, text = text }
end

function ns:DevTrace(kind, text)
    if not self:IsDevMode() then
        return
    end
    local trace = ns.global.devTrace
    if type(trace) ~= "table" then
        trace = {}
        ns.global.devTrace = trace
    end
    if not traceStarted then
        traceStarted = true
        TraceLine(trace, "SESSION", "login or reload, Famulus " .. tostring(ns.version))
    end
    local now = GetTime()
    local last = trace[#trace]
    if last and last.kind == kind and last.text == text and lastTraceAt and now - lastTraceAt <= FOLD_SECONDS then
        last.n = (last.n or 1) + 1
    else
        TraceLine(trace, kind, text)
    end
    lastTraceAt = now
end

function ns:SetDevMode(enabled)
    enabled = enabled and true or false
    if not ns.global or enabled == self:IsDevMode() then
        return
    end
    ns.global.dev = enabled or nil
    if not enabled then
        ns.global.devLog, ns.global.devTrace = nil, nil
        traceStarted, lastTraceAt = false, nil
    end
    SetDevEvents(enabled)
    ns:Print(enabled and L.msg_dev_on or L.msg_dev_off)
end

---------------------------------------------------------------------------
-- Bug report: what helps to find a bug, as plain text the player copies into
-- an issue ("/fam report", About › "Bug report"; UI/Report.lua shows it).
-- In English, for whoever reads the issue. No names: the log and the trace
-- hold tags only, and nothing else here names anybody.
---------------------------------------------------------------------------

local REPORT_CHECKS = 40 -- checks that are not ok, at most
local REPORT_TRACE = 80 -- the newest lines of the trace

-- An edit box takes "|" as the start of a code, so the text has none.
local function Plain(text)
    return (string.gsub(tostring(text), "|", "/"))
end

function ns:BugReport()
    local result = self:RunSelfTest(true)
    local lines = {}
    local function Line(format, ...)
        lines[#lines + 1] = Plain(select("#", ...) > 0 and string.format(format, ...) or format)
    end

    local client = result.client or {}
    Line("Famulus %s, client %s (build %s, %s), interface %s", tostring(ns.version), client.version, client.build,
        client.date, client.toc)
    Line("Made %s, client language %s, Famulus language %s", result.time, client.locale, tostring(ns:GetLocaleCode()))
    Line("Data version %s, %s profile, developer mode %s", tostring(ns.global and ns.global.dataVersion),
        ns:UsesCharacterProfile() and "character" or "account", self:IsDevMode() and "on" or "off")

    -- What runs, what is off, and what cannot run here.
    local on, off, other = {}, {}, {}
    for _, feature in ipairs(ns.featureList) do
        local state = result.features[feature.id] or {}
        if feature.failed then
            other[#other + 1] = feature.id .. " (failed)"
        elseif not state.available then
            local why = not feature:IsShown() and "addon not loaded"
                or feature.addon and (feature.addon .. " without the API it needs") or "not available"
            other[#other + 1] = feature.id .. " (" .. why .. ")"
        elseif feature.enabled then
            on[#on + 1] = feature.id
        elseif ns:GetOption(feature.id, "enabled") then
            off[#off + 1] = feature.id .. " (area off)"
        else
            off[#off + 1] = feature.id
        end
    end
    local areasOff = {}
    for _, area in ipairs(ns.areas or {}) do
        if not ns:IsCategoryEnabled(area.id) then
            areasOff[#areasOff + 1] = area.id
        end
    end
    Line("")
    Line("On: %s", #on > 0 and table.concat(on, ", ") or "nothing")
    Line("Off: %s", #off > 0 and table.concat(off, ", ") or "nothing")
    if #other > 0 then
        Line("Cannot run: %s", table.concat(other, ", "))
    end
    if #areasOff > 0 then
        Line("Areas switched off: %s", table.concat(areasOff, ", "))
    end
    local idle = result.idle or {}
    Line("Running: %s of %s features, %s game events, %s KB memory", tostring(idle.activeFeatures),
        tostring(idle.totalFeatures), tostring(idle.events), tostring(idle.memoryKB or "?"))
    local sharing = ns.features.sharing
    if sharing and sharing.enabled and sharing.Status then
        Line("Sharing: %d linked, %d friends and guild members online, %d messages waiting", sharing.Status())
    end

    local summary = result.summary
    Line("")
    Line("Self-test: %d ok, %d warnings, %d failed", summary.ok, summary.warn, summary.fail)
    -- Failures first, then warnings.
    local listed = 0
    for _, status in ipairs({ "fail", "warn" }) do
        for _, check in ipairs(result.checks) do
            if check.status == status and listed < REPORT_CHECKS then
                listed = listed + 1
                Line("[%s] %s / %s: %s", status, tostring(check.group), tostring(check.name), tostring(check.detail))
            end
        end
    end
    if summary.fail + summary.warn > listed then
        Line("... and %d more", summary.fail + summary.warn - listed)
    end

    if not self:IsDevMode() then
        Line("")
        Line("Developer mode is off: no log, no trace.")
        return table.concat(lines, "\n")
    end
    local log = ns.global.devLog or {}
    Line("")
    Line("Developer log (%d):", #log)
    for _, entry in ipairs(log) do
        Line("%s  %s  %s", tostring(entry.time), tostring(entry.kind), tostring(entry.text))
    end
    local trace = ns.global.devTrace or {}
    local first = math.max(1, #trace - REPORT_TRACE + 1)
    Line("")
    Line("Trace (the last %d of %d lines):", #trace - first + 1, #trace)
    for i = first, #trace do
        local entry = trace[i]
        local times = (tonumber(entry.n) or 1) > 1 and ("  (" .. entry.n .. " times)") or ""
        Line("%s  %s  %s%s", tostring(entry.time), tostring(entry.kind), tostring(entry.text), times)
    end
    return table.concat(lines, "\n")
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
