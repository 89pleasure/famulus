-- Feature registry. A feature is the unit the player switches on or off.
--
--   local feature = ns:NewFeature({
--       id = "autoRepair",            -- settings section and locale key
--       category = "vendor",          -- page in the settings window
--       default = false,              -- enabled on a fresh install?
--       requires = { "RepairAllItems" },   -- client API the feature needs
--       options = { { key = "guildFunds", type = "toggle", default = false } },
--   })
--   function feature:OnEnable() self:RegisterEvent("MERCHANT_SHOW") end
--   function feature:MERCHANT_SHOW() ... end
--
-- Every feature lives in its own file, Modules/<Category>/<Id>.lua. Code that
-- several features share is a service: a file <Name>Service.lua publishing
-- the table ns.<Name>Service, in Core/ when any category may use it, in the
-- category's folder when only that category does.
--
-- Rules that keep the addon cheap and predictable:
--   * OnEnable runs only while the feature is switched on. A feature that is
--     off has no events, no timers and no hooks.
--   * Events, EventRegistry callbacks and tickers registered through the
--     feature are removed automatically when it is switched off; toggling
--     never needs a reload. Delayed calls (feature:After) are dropped.
--   * Hooks cannot be removed in WoW. Install them with feature:HookFunction,
--     feature:HookScript, or feature:Once plus feature:Guard; the hook then
--     does nothing while the feature is off.
--   * A feature whose required API is missing stays off and is shown as
--     unavailable instead of raising errors.
--   * Every category has a master switch. While it is off, none of its
--     features run, whatever their own setting says; the settings are kept.
--   * A feature with `mirror = { cvar = ... }` is a second switch for one of
--     the game's options; Core/GameOptions.lua does all of the work.

local _, ns = ...
local L = ns.L

ns.categories = { "vendor", "quests", "loot", "social", "aliases", "tooltip", "interface" }

-- Master switches are ordinary options (section "categories"), so they are
-- saved per profile and only while they differ from the default "on".
local categoryDefaults = {}
for _, category in ipairs(ns.categories) do
    categoryDefaults[category] = true
end
ns:RegisterDefaults("categories", categoryDefaults)

function ns:IsCategoryEnabled(category)
    return self:GetOption("categories", category) ~= false
end

local features = {}
local featureList = {}
ns.features = features
ns.featureList = featureList

local Feature = {}
Feature.__index = Feature

function ns:NewFeature(def)
    assert(type(def.id) == "string" and def.category, "feature needs id and category")
    assert(not features[def.id], "duplicate feature id")
    setmetatable(def, Feature)
    def.enabled = false
    def.options = def.options or {}
    def.events = {}
    def.callbacks = {}
    def.generation = 0
    if def.mirror then
        def.requires = def.requires or {}
        table.insert(def.requires, "C_CVar.GetCVar")
        table.insert(def.requires, "C_CVar.SetCVar")
    end

    local values = { enabled = def.default and true or false }
    for _, option in ipairs(def.options) do
        values[option.key] = option.default
    end
    ns:RegisterDefaults(def.id, values)

    features[def.id] = def
    featureList[#featureList + 1] = def
    return def
end

-- handler: a function, a method name, or nil to use the method named like
-- the event. Handlers are called as handler(feature, event, ...).
function Feature:RegisterEvent(event, handler)
    if type(handler) ~= "function" then
        handler = self[handler or event]
    end
    assert(type(handler) == "function", "no handler for " .. event)
    self.events[event] = true
    ns:RegisterEvent(event, self, handler)
end

function Feature:UnregisterEvent(event)
    if self.events[event] then
        self.events[event] = nil
        ns:UnregisterEvent(event, self)
    end
end

-- Callback on Blizzard's EventRegistry (e.g. "ChatFrame.OnEditBoxFocusGained").
-- handler: a function or a method name; called as handler(feature, ...).
-- Returns false on a client without EventRegistry.
function Feature:RegisterCallback(event, handler)
    if not (EventRegistry and EventRegistry.RegisterCallback) then
        return false
    end
    if type(handler) ~= "function" then
        handler = self[handler]
    end
    assert(type(handler) == "function", "no handler for " .. event)
    self.callbacks[event] = true
    EventRegistry:RegisterCallback(event, handler, self)
    return true
end

function Feature:UnregisterCallback(event)
    if self.callbacks[event] then
        self.callbacks[event] = nil
        EventRegistry:UnregisterCallback(event, self)
    end
end

function Feature:Get(key)
    return ns:GetOption(self.id, key)
end

function Feature:Set(key, value)
    ns:SetOption(self.id, key, value)
end

-- Runs fn the first time it is called with this key and never again. Used
-- for one-time setup such as creating frames or installing hooks.
function Feature:Once(key, fn)
    local done = self.done
    if not done then
        done = {}
        self.done = done
    end
    if not done[key] then
        done[key] = true
        fn(self)
    end
end

-- Wraps a hook handler so that it does nothing while the feature is off.
function Feature:Guard(fn)
    return function(...)
        if self.enabled then
            return fn(...)
        end
    end
end

local function MarkHooked(feature, target, name)
    local hooks = feature.hooks
    if not hooks then
        hooks = {}
        feature.hooks = hooks
    end
    local names = hooks[target]
    if not names then
        names = {}
        hooks[target] = names
    end
    if names[name] then
        return false
    end
    names[name] = true
    return true
end

-- Secure post-hook, installed the first time it is asked for and active
-- only while the feature is on. hooksecurefunc never replaces the original.
--   feature:HookFunction("GameTooltip_SetDefaultAnchor", fn)
--   feature:HookFunction(someTable, "Method", fn)
function Feature:HookFunction(target, name, fn)
    if fn == nil then
        target, name, fn = _G, target, name
    end
    if MarkHooked(self, target, name) then
        if target == _G then
            hooksecurefunc(name, self:Guard(fn))
        else
            hooksecurefunc(target, name, self:Guard(fn))
        end
    end
end

-- Script hook on a frame, installed once per frame and script and active
-- only while the feature is on.
function Feature:HookScript(frame, script, fn)
    if frame and frame.HookScript and MarkHooked(self, frame, script) then
        frame:HookScript(script, self:Guard(fn))
    end
end

-- Calls fn(feature) after the given seconds, but only if the feature is still
-- on and was not switched off in the meantime.
function Feature:After(seconds, fn)
    local generation = self.generation
    C_Timer.After(seconds, function()
        if self.enabled and self.generation == generation then
            fn(self)
        end
    end)
end

-- Repeating timer that stops by itself when the feature is switched off.
function Feature:StartTicker(seconds, fn)
    self:StopTicker()
    self.ticker = C_Timer.NewTicker(seconds, fn)
end

function Feature:StopTicker()
    if self.ticker then
        self.ticker:Cancel()
        self.ticker = nil
    end
end

function Feature:IsAvailable()
    if self.available == nil then
        self.available = true
        if self.requires then
            for _, path in ipairs(self.requires) do
                if ns.Resolve(path) == nil then
                    self.available = false
                    self.missing = path
                    break
                end
            end
        end
    end
    return self.available
end

function ns:IsOptionAvailable(option)
    return option.requires == nil or ns.Resolve(option.requires) ~= nil
end

local function Disable(feature)
    feature.enabled = false
    if feature.OnDisable then
        xpcall(feature.OnDisable, geterrorhandler(), feature)
    end
    for event in pairs(feature.events) do
        ns:UnregisterEvent(event, feature)
    end
    wipe(feature.events)
    for event in pairs(feature.callbacks) do
        EventRegistry:UnregisterCallback(event, feature)
    end
    wipe(feature.callbacks)
    feature:StopTicker()
end

local function Enable(feature)
    feature.enabled = true
    feature.generation = feature.generation + 1
    if feature.OnEnable and not xpcall(feature.OnEnable, geterrorhandler(), feature) then
        -- A broken feature must not take the rest of the addon down with it.
        Disable(feature)
        feature.failed = true
        ns:Print(L.msg_feature_error:format(L["f_" .. feature.id]))
    end
end

local loggedIn = false

function ns:SyncFeature(feature)
    if not loggedIn then
        return
    end
    local wanted = not feature.failed
        and feature:IsAvailable()
        and self:IsCategoryEnabled(feature.category)
        and self:GetOption(feature.id, "enabled")
    if wanted and not feature.enabled then
        Enable(feature)
    elseif not wanted and feature.enabled then
        Disable(feature)
    end
    self:Fire("FEATURE_STATE", feature)
end

function ns:CountActiveFeatures()
    local active = 0
    for i = 1, #featureList do
        if featureList[i].enabled then
            active = active + 1
        end
    end
    return active, #featureList
end

ns:On("OPTION_CHANGED", function(section, key, value)
    if section == "categories" then
        for i = 1, #featureList do
            if featureList[i].category == key then
                ns:SyncFeature(featureList[i])
            end
        end
        return
    end
    local feature = features[section]
    if not feature then
        return
    end
    if key == "enabled" then
        ns:SyncFeature(feature)
    elseif feature.enabled and feature.OnOptionChanged then
        feature:OnOptionChanged(key, value)
    end
end)

ns:On("PROFILE_CHANGED", function()
    -- A different profile can differ in every option: restart what is running.
    for i = 1, #featureList do
        if featureList[i].enabled then
            Disable(featureList[i])
        end
    end
    for i = 1, #featureList do
        ns:SyncFeature(featureList[i])
    end
end)

local loader = {}

ns:RegisterEvent("PLAYER_LOGIN", loader, function()
    ns:UnregisterEvent("PLAYER_LOGIN", loader)
    loggedIn = true
    for i = 1, #featureList do
        ns:SyncFeature(featureList[i])
    end
    if not ns.global.seen then
        ns.global.seen = true
        ns:Print(L.msg_welcome)
    end
    ns:Fire("LOGIN")
end)

---------------------------------------------------------------------------
-- Slash commands and addon compartment
---------------------------------------------------------------------------

SLASH_SCHNITZEL1 = "/schnitzel"
SLASH_SCHNITZEL2 = "/sz"

SlashCmdList.SCHNITZEL = function(input)
    local command = string.lower(strtrim(input or ""))
    if command == "status" then
        local active, total = ns:CountActiveFeatures()
        ns:Print(L.msg_status:format(active, total, ns:CountRegisteredEvents()))
    elseif command == "test" then
        ns:RunSelfTest()
    elseif command == "dev" then
        ns:SetDevMode(not ns:IsDevMode())
    else
        ns:ToggleOptions()
    end
end

function Schnitzel_OnAddonCompartmentClick()
    ns:ToggleOptions()
end
