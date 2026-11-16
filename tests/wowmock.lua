-- A small stand-in for the WoW client API, just enough to load Schnitzel in
-- plain LuaJIT and drive it with events. It is strict where strictness finds
-- bugs: calling a widget method that is not listed below raises an error,
-- and every read of an undefined global is recorded for review.

local mock = {
    chat = {}, -- lines printed to the chat frame
    calls = {}, -- { "RepairAllItems", arg1, ... } for API calls worth asserting
    frames = {}, -- every frame created
    cvars = { autoLootDefault = "0", cameraDistanceMaxZoomFactor = "1.9" },
    state = {}, -- per-test game state
    undefinedGlobals = {},
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
    SetVertexColor SetFont SetShadowOffset SetShadowColor SetTextColor
    SetJustifyH SetJustifyV SetWordWrap SetSpacing SetAutoFocus SetMaxLetters
    SetFocus ClearFocus EnableMouseWheel SetScrollChild AddMessage AddLine
    AddDoubleLine SetOwner SetAltArrowKeyMode TryDisplayMessage
    SetGradient SetClampRectInsets
    ]],
        "%S+"
    )
do
    NOOP_METHODS[name] = true
end

local Widget = {}

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
function Widget:GetText()
    return self.text or ""
end
function Widget:GetStringWidth()
    return #(self.text or "") * 6.5
end
function Widget:GetStringHeight()
    local width = self.width or 0
    local lines = 1
    if width > 0 then
        lines = math.max(1, math.ceil(self:GetStringWidth() / width))
    end
    return lines * 14
end
function Widget:SetWidth(width)
    self.width = width
end
function Widget:SetHeight(height)
    self.height = height
end
function Widget:SetSize(width, height)
    self.width, self.height = width, height
    if self.scripts.OnSizeChanged then
        self.scripts.OnSizeChanged(self, width, height)
    end
end
function Widget:GetWidth()
    return self.width or 100
end
function Widget:GetHeight()
    return self.height or 100
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
function Widget:SetAltArrowKeyMode(altMode)
    self.altArrowKeyMode = altMode
end
function Widget:GetAltArrowKeyMode()
    return self.altArrowKeyMode
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

function Widget:CreateTexture()
    return NewWidget("Texture", self)
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
function GetBuildInfo()
    return "1.60.1", "66666", "Nov 10 2026", 16001
end
date = os.date

function CreateColor(r, g, b, a)
    return { r = r, g = g, b = b, a = a }
end

STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
NUM_BAG_SLOTS = 4
NUM_CHAT_WINDOWS = 2
DELETE_ITEM_CONFIRM_STRING = "DELETE"
ERR_OUT_OF_RAGE = "Not enough rage"
ERR_ABILITY_COOLDOWN = "Ability is not ready yet."
SlashCmdList = {}
UISpecialFrames = {}

UIParent = CreateFrame("Frame", "UIParent")
Minimap = CreateFrame("Frame", "Minimap")
GameTooltip = CreateFrame("GameTooltip", "GameTooltip")
ItemRefTooltip = CreateFrame("GameTooltip", "ItemRefTooltip")
UIErrorsFrame = CreateFrame("MessageFrame", "UIErrorsFrame")
MerchantFrame = CreateFrame("Frame", "MerchantFrame")
MerchantFrame.shown = false
WorldMapFrame = CreateFrame("Frame", "WorldMapFrame")
WorldMapFrame.shown = false
WorldMapFrame.ScrollContainer = CreateFrame("ScrollFrame", nil, WorldMapFrame)
ChatFrame1EditBox = CreateFrame("EditBox", "ChatFrame1EditBox")
ChatFrame2EditBox = CreateFrame("EditBox", "ChatFrame2EditBox")
-- The game's chat template sets ignoreArrows: Alt is needed by default.
ChatFrame1EditBox.altArrowKeyMode = true
ChatFrame2EditBox.altArrowKeyMode = true
SLASH_WHISPER1 = "/w"
SLASH_SAY1 = "/s"
SLASH_YELL1 = "/y"
function IsSecureCmd(command)
    return command == "/cast" or command == "/target"
end
AutoCompleteBox = CreateFrame("Frame", "AutoCompleteBox")
AutoCompleteBox.shown = false

-- Blizzard's CVar registry: callbacks keyed by the CVar's name.
CVarCallbackRegistry = { callbacks = {} }
function CVarCallbackRegistry:RegisterCallback(event, fn, owner)
    self.callbacks[event] = self.callbacks[event] or {}
    self.callbacks[event][owner] = fn
end
function CVarCallbackRegistry:TriggerEvent(event, ...)
    for owner, fn in pairs(self.callbacks[event] or {}) do
        fn(owner, ...)
    end
end
-- The player changes a game option in the game's own settings.
function mock.SetGameOption(name, value)
    mock.cvars[name] = value
    CVarCallbackRegistry:TriggerEvent(name, value)
end

EventRegistry = { callbacks = {} }
function EventRegistry:RegisterCallback(event, fn, owner)
    self.callbacks[event] = self.callbacks[event] or {}
    self.callbacks[event][owner] = fn
end
function EventRegistry:UnregisterCallback(event, owner)
    if self.callbacks[event] then
        self.callbacks[event][owner] = nil
    end
end
function EventRegistry:TriggerEvent(event, ...)
    for owner, fn in pairs(self.callbacks[event] or {}) do
        fn(owner, ...)
    end
end

DEFAULT_CHAT_FRAME = {
    AddMessage = function(_, text)
        mock.chat[#mock.chat + 1] = text
    end,
}

C_AddOns = {
    GetAddOnMetadata = function(_, field)
        return field == "Version" and "0.1.0-test" or nil
    end,
}

C_CVar = {
    GetCVar = function(name)
        return mock.cvars[name]
    end,
    SetCVar = function(name, value)
        record("SetCVar", name, value)
        if name == "cameraDistanceMaxZoomFactor" and tonumber(value) > 2.6 then
            return false -- this client caps the factor at 2.6
        end
        mock.cvars[name] = tostring(value)
        return true
    end,
}
function GetCVarBool(name)
    return mock.cvars[name] == "1"
end

C_CurrencyInfo = {
    GetCoinTextureString = function(copper)
        return copper .. "c"
    end,
}

-- Modifier keys
function IsShiftKeyDown()
    return mock.state.shift or false
end
function IsControlKeyDown()
    return false
end
function IsAltKeyDown()
    return false
end
function IsModifiedClick()
    return false
end

-- Merchant
function CanMerchantRepair()
    return mock.state.canRepair or false
end
function GetRepairAllCost()
    local cost = mock.state.repairCost or 0
    return cost, cost > 0
end
function RepairAllItems(guild)
    record("RepairAllItems", guild or false)
    if guild and mock.state.guildRepairFails then
        return
    end
    mock.state.repairCost = 0
end
function CanGuildBankRepair()
    return mock.state.canGuildRepair or false
end
function GetMoney()
    return mock.state.money or 0
end

-- Bags
Enum = {
    ItemQuality = { Poor = 0, Common = 1 },
    TooltipDataType = { Item = 0, Spell = 1 },
}
C_Container = {
    GetContainerNumSlots = function(bag)
        local slots = mock.state.bags and mock.state.bags[bag]
        return slots and #slots or 0
    end,
    GetContainerItemInfo = function(bag, slot)
        local slots = mock.state.bags and mock.state.bags[bag]
        local item = slots and slots[slot]
        return item or nil
    end,
    UseContainerItem = function(bag, slot)
        record("UseContainerItem", bag, slot)
        mock.state.bags[bag][slot] = false
    end,
}
C_Item = {
    GetItemInfo = function(link)
        local price = mock.state.prices and mock.state.prices[link] or 0
        return "name", link, 0, 1, 1, "type", "sub", 1, "", 1, price
    end,
}

-- Quests
C_GossipInfo = {
    GetActiveQuests = function()
        return mock.state.activeQuests or {}
    end,
    GetAvailableQuests = function()
        return mock.state.availableQuests or {}
    end,
    SelectActiveQuest = function(id)
        record("SelectActiveQuest", id)
    end,
    SelectAvailableQuest = function(id)
        record("SelectAvailableQuest", id)
    end,
}
C_QuestLog = {
    IsRepeatableQuest = function(id)
        return mock.state.repeatable and mock.state.repeatable[id] or false
    end,
    IsQuestTrivial = function(id)
        return mock.state.trivial and mock.state.trivial[id] or false
    end,
}
function GetQuestID()
    return mock.state.questID or 0
end
function AcceptQuest()
    record("AcceptQuest")
end
function ConfirmAcceptQuest()
    record("ConfirmAcceptQuest")
end
function QuestGetAutoAccept()
    return false
end
function AcknowledgeAutoAcceptQuest()
    record("AcknowledgeAutoAcceptQuest")
end
function QuestFlagsPVP()
    return mock.state.pvpQuest or false
end
function IsQuestCompletable()
    return mock.state.completable or false
end
function CompleteQuest()
    record("CompleteQuest")
end
function GetNumQuestChoices()
    return mock.state.choices or 0
end
function GetQuestReward(choice)
    record("GetQuestReward", choice)
end
function GetQuestMoneyToGet()
    return mock.state.questCost or 0
end
function GetNumActiveQuests()
    return 0
end
function GetNumAvailableQuests()
    return 0
end
function GetActiveTitle() end
function GetAvailableQuestInfo() end
function SelectActiveQuest() end
function SelectAvailableQuest() end

-- Loot
function GetNumLootItems()
    return mock.state.lootItems or 0
end
function LootSlot(slot)
    record("LootSlot", slot)
end
function ConfirmLootSlot(slot)
    record("ConfirmLootSlot", slot)
end
function IsInGroup()
    return mock.state.inGroup or false
end

-- Popups
StaticPopupDialogs = {
    LOOT_BIND = {},
    PARTY_INVITE = {},
    DUEL_REQUESTED = {},
    QUEST_ACCEPT = {},
    DELETE_GOOD_ITEM = {},
}
function StaticPopup_Hide(which)
    record("StaticPopup_Hide", which)
end
function StaticPopup_FindVisible(which)
    return mock.state.popups and mock.state.popups[which] or nil
end

-- Social
function AcceptGroup()
    record("AcceptGroup")
end
function CancelDuel()
    record("CancelDuel")
end
C_FriendList = {
    IsFriend = function(guid)
        return guid == "Player-1-FRIEND"
    end,
}
function IsGuildMember(guid)
    return guid == "Player-1-GUILD"
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
        return { mapID = mapID, name = "Elwynn Forest" }
    end,
    GetPlayerMapPosition = function()
        return {
            GetXY = function()
                return 0.4567, 0.1234
            end,
        }
    end,
}

-- Chat input. InsertLink only succeeds while a chat input is open.
ChatFrameUtil = {
    InsertLink = function(text)
        record("ChatFrameUtil.InsertLink", text)
        return mock.state.chatOpen or false
    end,
    OpenChat = function(text)
        record("ChatFrameUtil.OpenChat", text)
    end,
}

function Screenshot()
    record("Screenshot")
end
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
