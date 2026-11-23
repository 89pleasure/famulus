-- Famulus: core namespace, event dispatcher, internal messages, helpers.
-- Design rule: nothing in here runs per frame, and no event is registered
-- with the client until a feature that needs it is actually enabled.

local ADDON_NAME, ns = ...

ns.name = ADDON_NAME

local GetMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = (GetMetadata and GetMetadata(ADDON_NAME, "Version")) or "dev"

-- Calls a function so that an error in one handler is reported through the
-- normal error handler but does not stop the remaining handlers.
local safecall = securecallfunction or function(fn, ...)
    return fn(...)
end
ns.safecall = safecall

---------------------------------------------------------------------------
-- Event dispatcher
---------------------------------------------------------------------------
-- One frame for the whole addon. handlers[event] is an array of
-- { owner = <table>, fn = <function> }. The arrays are copy-on-write, so a
-- handler may (un)register events while an event is being dispatched and the
-- dispatch loop itself never allocates.

local eventFrame = CreateFrame("Frame")
local handlers = {}

eventFrame:SetScript("OnEvent", function(_, event, ...)
    local list = handlers[event]
    if not list then
        return
    end
    for i = 1, #list do
        local h = list[i]
        safecall(h.fn, h.owner, event, ...)
    end
end)

function ns:RegisterEvent(event, owner, fn)
    local old = handlers[event]
    local new = {}
    if old then
        for i = 1, #old do
            if old[i].owner ~= owner then
                new[#new + 1] = old[i]
            end
        end
    else
        eventFrame:RegisterEvent(event)
    end
    new[#new + 1] = { owner = owner, fn = fn }
    handlers[event] = new
end

function ns:UnregisterEvent(event, owner)
    local old = handlers[event]
    if not old then
        return
    end
    local new = {}
    for i = 1, #old do
        if old[i].owner ~= owner then
            new[#new + 1] = old[i]
        end
    end
    if #new == 0 then
        handlers[event] = nil
        eventFrame:UnregisterEvent(event)
    else
        handlers[event] = new
    end
end

-- Number of client events currently registered (shown on the About page and
-- used by the tests to prove that disabled features cost nothing).
function ns:CountRegisteredEvents()
    local n = 0
    for _ in pairs(handlers) do
        n = n + 1
    end
    return n
end

---------------------------------------------------------------------------
-- Internal messages (settings changed, locale changed, ...)
---------------------------------------------------------------------------

local listeners = {}

function ns:On(message, fn)
    local list = listeners[message]
    if not list then
        list = {}
        listeners[message] = list
    end
    list[#list + 1] = fn
end

function ns:Fire(message, ...)
    local list = listeners[message]
    if not list then
        return
    end
    for i = 1, #list do
        safecall(list[i], ...)
    end
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

-- Resolves a dotted global path such as "C_FriendList.GetNumFriends".
-- Returns nil if any part is missing, so features can declare what they need
-- and stay switched off on a client that lacks it instead of erroring.
function ns.Resolve(path)
    local value = _G
    for part in string.gmatch(path, "[^%.]+") do
        if type(value) ~= "table" then
            return nil
        end
        value = value[part]
        if value == nil then
            return nil
        end
    end
    return value
end

-- Values the client marks as "secret" (restricted combat data) must not be
-- compared or concatenated by addons.
local issecretvalue = issecretvalue
function ns.IsSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) or false
end

local PREFIX = "|cffffb347Famulus|r: "

function ns:Print(text)
    local chat = DEFAULT_CHAT_FRAME
    if chat then
        chat:AddMessage(PREFIX .. tostring(text))
    end
end

-- Feature feedback ("alias removed"). Can be silenced in the settings.
function ns:Notify(text)
    if self:GetOption("general", "chatOutput") then
        self:Print(text)
    end
end
