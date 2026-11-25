-- A small stand-in for the WoW client API, just enough to load Famulus in
-- plain LuaJIT and drive it with events. It is strict where strictness finds
-- bugs: calling a widget method that is not listed below raises an error,
-- and every read of an undefined global is recorded for review.

local mock = {
    chat = {}, -- lines printed to the chat frame
    calls = {}, -- { "C_FriendList.ShowFriends", arg1, ... } for API calls worth asserting
    frames = {}, -- every frame created
    state = {}, -- per-test game state
    undefinedGlobals = {},
    unloadedFonts = {}, -- font path -> true: SetFont answers false, as before the client loaded the file
    now = 0,
}

local function record(name, ...)
    mock.calls[#mock.calls + 1] = { name, ... }
end
mock.record = record

function mock.count(name)
    local n = 0
    for _, call in ipairs(mock.calls) do
        if call[1] == name then
            n = n + 1
        end
    end
    return n
end

function mock.reset()
    mock.calls = {}
    mock.chat = {}
end

---------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------

local NOOP_METHODS = {}
for name in
    string.gmatch(
        [[
    SetPoint ClearAllPoints SetAllPoints SetFrameStrata SetFrameLevel SetToplevel
    SetClampedToScreen SetMovable RegisterForDrag RegisterForClicks
    StartMoving StopMovingOrSizing SetColorTexture SetTexture SetTexCoord
    SetVertexColor SetShadowOffset SetShadowColor SetTextColor
    SetJustifyH SetJustifyV SetWordWrap SetSpacing SetAutoFocus SetMaxLetters
    EnableMouseWheel SetScrollChild AddMessage AddLine
    AddDoubleLine SetOwner
    SetGradient SetClampRectInsets SetHorizTile SetVertTile
    SetLooping SetOffset SetDuration SetFromAlpha SetToAlpha SetOrder
    ]],
        "%S+"
    )
do
    NOOP_METHODS[name] = true
end

local Widget = {}

-- Keeps the last anchor, so that tests can compare where things stand
-- (mockPoint = { point, relativeTo, relativePoint, x, y }).
function Widget:SetPoint(...)
    self.mockPoint = { ... }
end

function Widget:SetScript(script, fn)
    self.scripts[script] = fn
end
function Widget:GetScript(script)
    return self.scripts[script]
end
function Widget:Show()
    if not self.shown then
        self.shown = true
        if self.scripts.OnShow then
            self.scripts.OnShow(self)
        end
    end
end
function Widget:Hide()
    if self.shown then
        self.shown = false
        if self.scripts.OnHide then
            self.scripts.OnHide(self)
        end
    end
end
function Widget:SetShown(shown)
    if shown then
        self:Show()
    else
        self:Hide()
    end
end
function Widget:IsShown()
    return self.shown
end
function Widget:IsVisible()
    local frame = self
    while frame do
        if not frame.shown then
            return false
        end
        frame = frame.parent
    end
    return true
end
function Widget:IsMouseOver()
    return self.mouseOver or false
end
function Widget:IsForbidden()
    return false
end
function Widget:RegisterEvent(event)
    self.events[event] = true
end
function Widget:UnregisterEvent(event)
    self.events[event] = nil
end
function Widget:SetText(text)
    self.text = tostring(text)
    if self.widgetType == "EditBox" and self.scripts.OnTextChanged then
        self.scripts.OnTextChanged(self, false)
    end
end
-- Like the client: a file not loaded yet answers false and keeps the old font.
function Widget:SetFont(path, size)
    if mock.unloadedFonts[path] then
        return false
    end
    self.font, self.fontSize = path, size
    self.fontSets = (self.fontSets or 0) + 1
    return true
end
function Widget:GetText()
    return self.text or ""
end
function Widget:GetStringWidth()
    return #(self.text or "") * 6.5
end
Widget.GetUnboundedStringWidth = Widget.GetStringWidth
-- The size lives in fields of the mock's own. In the client, SetWidth sets no
-- field "width" on the frame; a mock that did would hide code reading
-- frame.width without ever setting it (Book.lua did, 2026-11-24).
function Widget:GetStringHeight()
    local width = self.mockWidth or 0
    local lines = 1
    if width > 0 then
        lines = math.max(1, math.ceil(self:GetStringWidth() / width))
    end
    return lines * 14
end
function Widget:SetWidth(width)
    self.mockWidth = width
end
function Widget:SetHeight(height)
    self.mockHeight = height
end
function Widget:SetSize(width, height)
    self.mockWidth, self.mockHeight = width, height
    if self.scripts.OnSizeChanged then
        self.scripts.OnSizeChanged(self, width, height)
    end
end
function Widget:GetWidth()
    return self.mockWidth or 100
end
function Widget:GetHeight()
    return self.mockHeight or 100
end
function Widget:GetCenter()
    return 500, 400
end
function Widget:GetPoint()
    return "CENTER", nil, "CENTER", 0, 20
end
function Widget:GetEffectiveScale()
    return 1
end
function Widget:GetFrameLevel()
    return 1
end
function Widget:EnableMouse(enabled)
    self.mouseEnabled = enabled and true or false
end
function Widget:HookScript(script, hook)
    local original = self.scripts[script]
    self.scripts[script] = function(...)
        if original then
            original(...)
        end
        hook(...)
    end
end
function Widget:GetAttribute(name)
    return self.attributes and self.attributes[name]
end
function Widget:SetCursorPosition(position)
    self.cursor = position
end
function Widget:ClearHistory()
    self.historyCleared = (self.historyCleared or 0) + 1
end
function Widget:SetScale(scale)
    self.scale = scale
end
function Widget:SetAlpha(alpha)
    self.alpha = alpha
end
function Widget:GetAlpha()
    return self.alpha or 1
end
function Widget:SetVerticalScroll(value)
    self.verticalScroll = value
end
function Widget:GetVerticalScroll()
    return self.verticalScroll or 0
end
function Widget:GetNormalizedCursorPosition()
    return 0.25, 0.75
end
function Widget:SetFocus()
    mock.focus = self
end
function Widget:ClearFocus()
    if mock.focus == self then
        mock.focus = nil
    end
end
function Widget:GetUnit()
    local unit = mock.state.tooltipUnit
    return unit and mock.state.units[unit].name, unit
end
-- Cooldown frames: the swipe the crest's ring is drawn with.
for _, name in ipairs({ "SetSwipeTexture", "SetSwipeColor", "SetDrawEdge", "SetDrawBling", "SetHideCountdownNumbers", "SetReverse" }) do
    Widget[name] = function() end
end
function Widget:SetCooldown(start, duration)
    self.cooldown, self.paused = { start, duration }, false
end
function Widget:Pause()
    self.paused = true
end
function Widget:Clear()
    self.cooldown, self.paused = nil, false
end
function Widget:GetParent()
    return self.parent
end
function Widget:GetEditBox()
    return self.editBoxWidget
end

local function NewWidget(widgetType, parent)
    local widget = {
        widgetType = widgetType,
        parent = parent,
        scripts = {},
        events = {},
        shown = true,
    }
    setmetatable(widget, {
        __index = function(_, key)
            local method = Widget[key]
            if method then
                return method
            end
            if NOOP_METHODS[key] then
                return function() end
            end
            if type(key) == "string" and key:match("^[A-Z]%a+$") and (key:match("^Set") or key:match("^Get") or key:match("^Is") or key:match("^Create") or key:match("^Register")) then
                error("mock: unknown widget method " .. key, 2)
            end
            return nil
        end,
    })
    return widget
end

-- Animations: only whether a group is playing matters to the tests.
function Widget:CreateAnimationGroup()
    self.group = NewWidget("AnimationGroup", self)
    return self.group
end
function Widget:CreateAnimation(kind)
    local animation = NewWidget("Animation", self)
    animation.kind = kind
    return animation
end
function Widget:Play()
    self.playing = true
end
function Widget:Stop()
    self.playing = false
end
function Widget:IsPlaying()
    return self.playing == true
end

function Widget:CreateTexture()
    local texture = NewWidget("Texture", self)
    self.regions = self.regions or {}
    self.regions[#self.regions + 1] = texture
    return texture
end
function Widget:CreateFontString()
    return NewWidget("FontString", self)
end

function mock.Click(widget, button)
    assert(widget.scripts.OnClick, "widget has no OnClick")
    widget.scripts.OnClick(widget, button or "LeftButton")
end

function CreateFrame(widgetType, name, parent)
    local frame = NewWidget(widgetType, parent)
    mock.frames[#mock.frames + 1] = frame
    if name then
        _G[name] = frame
    end
    return frame
end

function mock.Fire(event, ...)
    -- Copy first: handlers may register and unregister while we iterate.
    local targets = {}
    for _, frame in ipairs(mock.frames) do
        if frame.events[event] and frame.scripts.OnEvent then
            targets[#targets + 1] = frame
        end
    end
    for _, frame in ipairs(targets) do
        frame.scripts.OnEvent(frame, event, ...)
    end
end

---------------------------------------------------------------------------
-- Timers and frame updates
---------------------------------------------------------------------------

local timers = {}

C_Timer = {}
function C_Timer.After(seconds, fn)
    timers[#timers + 1] = { at = mock.now + seconds, fn = fn }
end
function C_Timer.NewTicker(seconds, fn)
    local ticker = { interval = seconds, fn = fn, at = mock.now + seconds }
    function ticker:Cancel()
        self.cancelled = true
    end
    timers[#timers + 1] = ticker
    return ticker
end

function mock.ActiveTimers()
    local n = 0
    for _, timer in ipairs(timers) do
        if not timer.cancelled then
            n = n + 1
        end
    end
    return n
end

-- Advances game time in 20 ms frames, running due timers and OnUpdate.
function mock.Advance(seconds)
    local step = 0.02
    for _ = 1, math.max(1, math.floor(seconds / step + 0.5)) do
        mock.now = mock.now + step
        local due = {}
        for i = #timers, 1, -1 do
            local timer = timers[i]
            if timer.cancelled then
                table.remove(timers, i)
            elseif timer.at <= mock.now + 1e-9 then
                due[#due + 1] = timer
                if timer.interval then
                    timer.at = timer.at + timer.interval
                else
                    table.remove(timers, i)
                end
            end
        end
        for i = #due, 1, -1 do
            if not due[i].cancelled then
                due[i].fn(due[i])
            end
        end
        for _, frame in ipairs(mock.frames) do
            if frame.scripts.OnUpdate and frame:IsVisible() then
                frame.scripts.OnUpdate(frame, step)
            end
        end
    end
end

function mock.CountOnUpdateFrames()
    local n = 0
    for _, frame in ipairs(mock.frames) do
        if frame.scripts.OnUpdate and frame:IsVisible() then
            n = n + 1
        end
    end
    return n
end

---------------------------------------------------------------------------
-- Globals
---------------------------------------------------------------------------

function GetTime()
    return mock.now
end
function GetLocale()
    return mock.state.locale or "enUS"
end
function strtrim(text)
    return (text:gsub("^%s+", ""):gsub("%s+$", ""))
end
function wipe(tbl)
    for key in pairs(tbl) do
        tbl[key] = nil
    end
    return tbl
end
function geterrorhandler()
    return function(message)
        mock.errors = mock.errors or {}
        mock.errors[#mock.errors + 1] = tostring(message)
        return message
    end
end
function hooksecurefunc(name, hook)
    local original = _G[name]
    assert(type(original) == "function", "hooksecurefunc: no global function " .. tostring(name))
    _G[name] = function(...)
        local a, b, c = original(...)
        hook(...)
        return a, b, c
    end
end
function InCombatLockdown()
    return mock.state.inCombat or false
end
function PlaySoundFile(sound, channel)
    record("PlaySoundFile", sound, channel)
    return true, 1
end
function GetBuildInfo()
    return "1.60.1", "66666", "Nov 10 2026", 16001
end
date = os.date
time = os.time

function CreateColor(r, g, b, a)
    return { r = r, g = g, b = b, a = a }
end

STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
QuestTitleFont = {
    GetFont = function()
        return "Fonts\\MORPHEUS.TTF", 18, ""
    end,
}
SlashCmdList = {}
UISpecialFrames = {}

UIParent = CreateFrame("Frame", "UIParent")
Minimap = CreateFrame("Frame", "Minimap")
GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
ItemRefTooltip = CreateFrame("GameTooltip", "ItemRefTooltip")
function GameTooltip:IsOwned()
    return false
end
EditModeManagerFrame = CreateFrame("Frame", "EditModeManagerFrame")

DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, text)
        mock.chat[#mock.chat + 1] = text
    end,
}

mock.loadedAddons = { Guildy = true }

C_AddOns = {
    GetAddOnMetadata = function(_, field)
        return field == "Version" and "0.1.0-test" or nil
    end,
    IsAddOnLoaded = function(name)
        return mock.loadedAddons[name] == true, mock.loadedAddons[name] == true
    end,
}

-- The name formatter API of the addon Guildy, as far as Famulus uses it.
GuildyAPI = {
    formatters = {},
    refreshes = 0,
    RegisterNameFormatter = function(owner, fn)
        GuildyAPI.formatters[owner] = fn
    end,
    UnregisterNameFormatter = function(owner)
        GuildyAPI.formatters[owner] = nil
    end,
    Refresh = function()
        GuildyAPI.refreshes = GuildyAPI.refreshes + 1
    end,
}

Enum = {
    TooltipDataType = { Unit = 2 },
    SendAddonMessageResult = { Success = 0, AddonMessageThrottle = 3, ChannelThrottle = 8, AddOnMessageLockdown = 11, TargetOffline = 12 },
}
C_Item = {
    -- mock.state.owned = { [itemID] = <count> }; mock.state.itemNames = { [itemID] = "<name>" }
    GetItemCount = function(itemID)
        return mock.state.owned and mock.state.owned[itemID] or 0
    end,
    -- mock.state.itemIcons = { [itemID] = <file ID> }
    GetItemIconByID = function(itemID)
        return mock.state.itemIcons and mock.state.itemIcons[itemID] or nil
    end,
    GetItemNameByID = function(itemID)
        return mock.state.itemNames and mock.state.itemNames[itemID] or nil
    end,
    GetItemInfo = function() end,
}

-- Secret values. mock.SECRET stands for a value the client hides from addons
-- and, like it, refuses indexing, arithmetic, ordering and concatenation. A
-- boolean test ("not x") cannot be caught in Lua; tests/run.lua checks the
-- order of those tests in the source instead.
local function refuseSecret()
    error("attempt to use a secret value", 2)
end
mock.SECRET = setmetatable({}, {
    __index = refuseSecret,
    __newindex = refuseSecret,
    __call = refuseSecret,
    __concat = refuseSecret,
    __len = refuseSecret,
    __unm = refuseSecret,
    __add = refuseSecret,
    __sub = refuseSecret,
    __mul = refuseSecret,
    __div = refuseSecret,
    __mod = refuseSecret,
    __pow = refuseSecret,
    __lt = refuseSecret,
    __le = refuseSecret,
})
function issecretvalue(value)
    return rawequal(value, mock.SECRET)
end

-- mock.state.friends = { { name = ..., level = ..., area = ..., guid = ..., connected = true }, ... }
C_FriendList = {
    GetNumFriends = function()
        return #(mock.state.friends or {})
    end,
    GetFriendInfoByIndex = function(index)
        return (mock.state.friends or {})[index]
    end,
    ShowFriends = function()
        record("C_FriendList.ShowFriends")
    end,
    IsFriend = function(guid)
        record("C_FriendList.IsFriend")
        for _, friend in ipairs(mock.state.friends or {}) do
            if friend.guid == guid then
                return true
            end
        end
        return false
    end,
}
-- Battle.net friends:
-- mock.state.bnFriends = { { battleTag = "Anna#1234", games = { { characterName = "Jaina Proudmoore",
-- playerGuid = "Player-1-JAINA" } } }, ... }
-- A game without wowProjectID counts as this game; the first one is what the
-- friends list shows. A friend without games is offline.
WOW_PROJECT_ID = 99
local function bnGame(friend, index)
    local game = friend and friend.games and friend.games[index]
    if not game then
        return nil
    end
    return {
        characterName = game.characterName,
        playerGuid = game.playerGuid,
        wowProjectID = game.wowProjectID or WOW_PROJECT_ID,
        isOnline = true,
    }
end
function BNGetNumFriends()
    record("BNGetNumFriends")
    return #(mock.state.bnFriends or {})
end
-- mock.state.bnOffline = true: Battle.net is not connected.
function BNConnected()
    return not mock.state.bnOffline
end
C_BattleNet = {
    GetFriendAccountInfo = function(index)
        local friend = (mock.state.bnFriends or {})[index]
        if not friend then
            return nil
        end
        return { battleTag = friend.battleTag, accountName = "|Kq" .. index .. "|k", gameAccountInfo = bnGame(friend, 1) or { isOnline = false } }
    end,
    GetFriendNumGameAccounts = function(index)
        local friend = (mock.state.bnFriends or {})[index]
        return friend and #(friend.games or {}) or 0
    end,
    GetFriendGameAccountInfo = function(index, gameIndex)
        return bnGame((mock.state.bnFriends or {})[index], gameIndex)
    end,
    -- The account of the friend who plays that character right now; with
    -- stranger = true one the client knows, but not as a friend's.
    GetAccountInfoByGUID = function(guid)
        for index, friend in ipairs(mock.state.bnFriends or {}) do
            for gameIndex, game in ipairs(friend.games or {}) do
                if game.playerGuid == guid then
                    return { battleTag = friend.battleTag, isFriend = not friend.stranger, isBattleTagFriend = not friend.stranger,
                        gameAccountInfo = bnGame(friend, gameIndex) }
                end
            end
        end
        return nil
    end,
}
-- Addon messages: every call lands in mock.attempts, what the client accepted
-- in mock.sent. mock.addonResult(message) may answer with a result code in
-- place of the client. With mock.addonThrottle the client refuses like the
-- real one (warcraft.wiki.gg): ten at once, then one more per second, but
-- whispers only with mock.whisperThrottle (the wiki exempts them outside
-- instances). mock.bytesSent adds up what was accepted, for the bandwidth.
mock.sent = {}
mock.attempts = {}
local addonAllowance, addonRefilled = 10, nil
C_ChatInfo = {
    RegisterAddonMessagePrefix = function(prefix)
        record("C_ChatInfo.RegisterAddonMessagePrefix", prefix)
        return true
    end,
    SendAddonMessage = function(prefix, text, chatType, target)
        local message = { prefix = prefix, text = text, chatType = chatType, target = target }
        mock.attempts[#mock.attempts + 1] = message
        local result = 0
        if mock.addonResult then
            local answer = mock.addonResult(message)
            if answer ~= nil then
                result = answer -- false too, like older clients
            end
        end
        if result == 0 and mock.addonThrottle and (chatType ~= "WHISPER" or mock.whisperThrottle) then
            addonAllowance = math.min(10, addonAllowance + (mock.now - (addonRefilled or mock.now)))
            addonRefilled = mock.now
            if addonAllowance < 1 then
                result = Enum.SendAddonMessageResult.AddonMessageThrottle
            else
                addonAllowance = addonAllowance - 1
            end
        end
        message.result = result
        if result == 0 then
            mock.bytesSent = (mock.bytesSent or 0) + #text
            mock.sent[#mock.sent + 1] = message
        end
        return result
    end,
    InChatMessagingLockdown = function()
        return mock.state.lockdown == true
    end,
}
function strsplit(delimiter, text)
    local parts = {}
    for part in string.gmatch(text .. delimiter, "(.-)" .. delimiter:gsub("%p", "%%%0")) do
        parts[#parts + 1] = part
    end
    return unpack(parts)
end
-- Statistics: mock.state.statistics = { [id] = "<quantity as the game prints it>" }
function GetStatisticsCategoryList()
    return { 1 }
end
function GetCategoryNumAchievements()
    local count = 0
    for _ in pairs(mock.state.statistics or {}) do
        count = count + 1
    end
    return count
end
function GetStatistic(_, index)
    local ids = {}
    for id in pairs(mock.state.statistics or {}) do
        ids[#ids + 1] = id
    end
    table.sort(ids)
    local id = ids[index]
    return id and mock.state.statistics[id], false, id
end
function GetRealZoneText()
    return mock.state.zone or "Elwynn Forest"
end
function UnitLevel(unit)
    local group = mock.state.group
    for index, member in ipairs(group and group.members or {}) do
        if unit == (group.raid and "raid" .. (index + 1) or "party" .. index) then
            return member.level or 1
        end
    end
    return mock.state.level or 12
end
function GetAchievementInfo(id)
    return id, "Challenge " .. tostring(id)
end
function IsGuildMember(guid)
    return guid == "Player-1-GUILD"
end
-- mock.state.guild = { { name = ..., online = true, mobile = false }, ... }; nil: not in a guild
function IsInGuild()
    return mock.state.guild ~= nil
end
function GetNumGuildMembers()
    return #(mock.state.guild or {})
end
function GetGuildRosterInfo(index)
    local member = (mock.state.guild or {})[index]
    if member then
        return member.name, "Member", 1, 20, "Mage", "Elwynn Forest", "", "", member.online or false, 0, member.class or "MAGE", 0, 0, member.mobile or false, false, 0, member.guid
    end
end
C_GuildInfo = {
    GuildRoster = function()
        record("C_GuildInfo.GuildRoster")
    end,
}
function UnitIsInMyGuild(unit)
    local guid = UnitGUID(unit)
    for _, member in ipairs(mock.state.guild or {}) do
        if guid and member.guid == guid then
            return true
        end
    end
    return false
end

-- Tooltips
TooltipDataProcessor = {
    postCalls = {},
    AddTooltipPostCall = function(dataType, fn)
        local list = TooltipDataProcessor.postCalls
        list[#list + 1] = { dataType = dataType, fn = fn }
    end,
}
function GameTooltip_SetDefaultAnchor(tooltip, parent)
    record("GameTooltip_SetDefaultAnchor")
end

-- Map
C_Map = {
    GetBestMapForUnit = function()
        return 1
    end,
    GetMapInfo = function(mapID)
        return { mapID = mapID, name = "Elwynn Forest", parentMapID = mapID == 1 and 900 or 0 }
    end,
    -- mock.state.explored = { "<zone name>", ... }: zones with an uncovered part
    GetMapChildrenInfo = function(mapID)
        local zones = {}
        if mapID == 900 then
            for index, name in ipairs({ "Elwynn Forest", "Westfall", "Duskwood", "Redridge Mountains" }) do
                zones[index] = { mapID = 100 + index, name = name }
            end
        end
        return zones
    end,
    GetPlayerMapPosition = function()
        return {
            GetXY = function()
                return 0.4567, 0.1234
            end,
        }
    end,
}

C_MapExplorationInfo = {
    GetExploredMapTextures = function(mapID)
        local info = C_Map.GetMapChildrenInfo(900)[mapID - 100]
        for _, name in ipairs(mock.state.explored or {}) do
            if info and info.name == name then
                return { {} }
            end
        end
        return {}
    end,
}
-- mock.state.professions = { { name = "Tailoring", rank = 1, id = 197 }, ... }
function GetProfessions()
    local list = mock.state.professions or {}
    return list[1] and 1, list[2] and 2
end
function GetProfessionInfo(index)
    local info = (mock.state.professions or {})[index]
    if info then
        return info.name, 136000 + info.id, info.rank, 300, 0, 0, info.id
    end
end
-- mock.state.riding = <rank of the riding skill line>; mock.state.spells = { [id] = true }
C_SkillInfo = {
    GetSkillLineInfoByID = function(id)
        if id == 762 and mock.state.riding then
            return { skillID = id, name = "Riding", rank = mock.state.riding, maxRank = 150 }
        end
    end,
}
function IsPlayerSpell(id)
    return mock.state.spells ~= nil and mock.state.spells[id] == true
end
-- mock.links: the links SetItemRef was called with
function SetItemRef(link)
    mock.links = mock.links or {}
    mock.links[#mock.links + 1] = link
end
-- mock.opened: the skill lines whose profession window was opened
C_TradeSkillUI = {
    OpenTradeSkill = function(skillLine)
        mock.opened = mock.opened or {}
        mock.opened[#mock.opened + 1] = skillLine
        return true
    end,
}
function UnitOnTaxi()
    return mock.state.onTaxi == true
end

-- Groups: mock.state.group = { raid = false, members = { { name = "Mira", surname = "Sturmfeder",
-- guid = "Player-1-MIRA", level = 30, class = "MAGE", offline = false }, ... } }. In a party
-- they are party1, party2, ...; in a raid raid1 is the player and the members follow.
-- mock.state.instanceType: "party", "raid", "pvp", "arena" or nil (outdoors).
local function GroupMember(unit)
    local group = mock.state.group
    if type(unit) ~= "string" or not group then
        return nil
    end
    local index = tonumber(unit:match("^party(%d+)$"))
    if index and not group.raid then
        return group.members[index]
    end
    index = tonumber(unit:match("^raid(%d+)$"))
    if index and group.raid then
        return index == 1 and { player = true } or group.members[index - 1]
    end
    return nil
end
function GetNumGroupMembers()
    local group = mock.state.group
    return group and (#group.members + 1) or 0
end
function IsInRaid()
    return mock.state.group ~= nil and mock.state.group.raid == true
end
function IsInInstance()
    local kind = mock.state.instanceType
    return kind ~= nil, kind or "none"
end
function UnitGUID(unit)
    local member = GroupMember(unit)
    if unit == "player" or (member and member.player) then
        return "Player-1-SELF"
    end
    return member and member.guid or nil
end
function UnitClass(unit)
    local member = GroupMember(unit)
    local file = member and member.class or "WARRIOR"
    return file:sub(1, 1) .. file:sub(2):lower(), file, 1
end
function UnitIsConnected(unit)
    local member = GroupMember(unit)
    return not (member and member.offline)
end
UNKNOWNOBJECT = "Unknown"
CLASS_ICON_TCOORDS = {
    WARRIOR = { 0, 0.25, 0, 0.25 }, MAGE = { 0.25, 0.49609375, 0, 0.25 }, ROGUE = { 0.49609375, 0.7421875, 0, 0.25 },
    DRUID = { 0.7421875, 0.98828125, 0, 0.25 }, HUNTER = { 0, 0.25, 0.25, 0.5 }, PRIEST = { 0.49609375, 0.7421875, 0.25, 0.5 },
}
LOCALIZED_CLASS_NAMES_MALE = { MAGE = "Mage", PRIEST = "Priest", WARRIOR = "Warrior", ROGUE = "Rogue" }

-- Units: mock.state.units = { target = { name = "Jaina", surname = "Proudmoore", isPlayer = true } }
function UnitName(unit)
    local member = GroupMember(unit)
    if member and member.player then
        unit = "player"
    elseif member then
        return member.name, member.surname
    end
    local info = mock.state.units and mock.state.units[unit]
    if info then
        return info.name, info.surname
    end
end
UnitNameUnmodified = UnitName
function UnitIsPlayer(unit)
    local info = mock.state.units and mock.state.units[unit]
    return info ~= nil and info.isPlayer == true
end
Constants = {
    CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = " ", CHARACTERNAME_REALMNAME_SEPARATOR = "-" },
}

-- Context menus. mock.OpenMenu returns the entries addons added, as
-- { text = ..., click = fn } with text "-" for a divider.
Menu = { callbacks = {} }
function Menu.ModifyMenu(tag, callback)
    Menu.callbacks[tag] = Menu.callbacks[tag] or {}
    table.insert(Menu.callbacks[tag], callback)
end
function Menu.GetOpenMenuTags()
    return {}
end
function mock.OpenMenu(tag, contextData)
    local entries = {}
    local root = {
        contextData = contextData,
        CreateDivider = function()
            entries[#entries + 1] = { text = "-" }
        end,
        CreateButton = function(_, text, click)
            entries[#entries + 1] = { text = text, click = click }
        end,
    }
    for _, callback in ipairs(Menu.callbacks[tag] or {}) do
        callback(nil, root, contextData)
    end
    return entries
end

-- Chat. mock.SenderName runs the sender name filters the way the chat frame
-- does before it prints "[Name]".
local senderFilters = {}
function mock.SenderName(event, decorated, sender)
    for _, filter in ipairs(senderFilters) do
        local changed = filter(event, decorated, "text", sender)
        if changed ~= nil then
            decorated = changed
        end
    end
    return decorated
end
function mock.CountSenderFilters()
    return #senderFilters
end

-- The game's notices that someone came online or went offline, as the
-- client's English texts have them.
ERR_FRIEND_ONLINE_SS = "|Hplayer:%s|h[%s]|h has come online."
ERR_FRIEND_OFFLINE_S = "%s has gone offline."

-- mock.SystemMessage runs the message filters of CHAT_MSG_SYSTEM the way a
-- chat frame does before it prints the line: the first return value drops
-- it, a second one replaces the arguments. Returns the line as printed, or
-- nil if a filter dropped it. chatFrame defaults to a plain frame.
local messageFilters = {}
function mock.SystemMessage(message, chatFrame)
    local args = { message, "", "", "", "", "", 0, 0, "", 0, 0, "", 0, false }
    for _, filter in ipairs(messageFilters.CHAT_MSG_SYSTEM or {}) do
        local results = { filter(chatFrame or {}, "CHAT_MSG_SYSTEM", unpack(args, 1, 14)) }
        if results[1] then
            return nil
        end
        if results[2] then
            args = { unpack(results, 2, 15) }
        end
    end
    return args[1], #args
end
function mock.CountMessageFilters(event)
    return #(messageFilters[event] or {})
end

-- Chat input. InsertLink only succeeds while a chat input is open.
ChatFrameUtil = {
    AddSenderNameFilter = function(callback)
        senderFilters[#senderFilters + 1] = callback
    end,
    RemoveSenderNameFilter = function(callback)
        for i = #senderFilters, 1, -1 do
            if senderFilters[i] == callback then
                table.remove(senderFilters, i)
            end
        end
    end,
    AddMessageEventFilter = function(event, callback)
        local filters = messageFilters[event] or {}
        messageFilters[event] = filters
        for _, known in ipairs(filters) do
            if known == callback then
                return
            end
        end
        filters[#filters + 1] = callback
    end,
    RemoveMessageEventFilter = function(event, callback)
        local filters = messageFilters[event] or {}
        for i = #filters, 1, -1 do
            if filters[i] == callback then
                table.remove(filters, i)
            end
        end
    end,
}

function GetCursorPosition()
    return 600, 500
end

PixelUtil = {
    GetNearestPixelSize = function()
        return 1
    end,
}

Settings = {
    RegisterCanvasLayoutCategory = function(_, name)
        record("Settings.RegisterCanvasLayoutCategory", name)
        return { name = name }
    end,
    RegisterAddOnCategory = function()
        record("Settings.RegisterAddOnCategory")
    end,
}

---------------------------------------------------------------------------
-- Loading the addon
---------------------------------------------------------------------------

-- Record reads of globals that do not exist. Optional client API is probed
-- on purpose, so this is a report, not an error.
setmetatable(_G, {
    __index = function(_, key)
        mock.undefinedGlobals[key] = true
        return nil
    end,
})

function mock.LoadAddon(directory, name)
    local ns = {}
    local toc = assert(io.open(directory .. "/" .. name .. ".toc", "r"))
    local files = {}
    for line in toc:lines() do
        line = line:gsub("\r", "")
        if line:match("%.lua$") then
            files[#files + 1] = line:gsub("\\", "/")
        end
    end
    toc:close()
    for _, file in ipairs(files) do
        local chunk = assert(loadfile(directory .. "/" .. file))
        chunk(name, ns)
    end
    mock.ns = ns
    return ns, files
end

return mock
