-- Feature registry. A feature is the unit the player switches on or off.
--
--   local feature = ns:NewFeature({
--       id = "companions",            -- settings section and locale key
--       category = "chronicle",       -- page in the settings window
--       default = false,              -- enabled on a fresh install?
--       requires = { "C_FriendList.GetNumFriends" },  -- client API the feature needs
--       addon = "Guildy",             -- optional: only for this other addon
--       options = { { key = "style", type = "select", default = "alias" } },
--   })
--   function feature:OnEnable() self:RegisterEvent("FRIENDLIST_UPDATE") end
--   function feature:FRIENDLIST_UPDATE() ... end
--
-- Every feature lives in its own file, Modules/<Category>/<Id>.lua. Code that
-- several features share is a service: a file <Name>Service.lua publishing
-- the table ns.<Name>Service, in Core/ when any category may use it, in the
-- category's folder when only that category does.
--
-- Rules that keep the addon cheap and predictable:
--   * OnEnable runs only while the feature is switched on. A feature that is
--     off has no events, no timers and no hooks.
--   * Events and tickers registered through the
--     feature are removed automatically when it is switched off; toggling
--     never needs a reload. Delayed calls (feature:After) are dropped.
--   * Hooks cannot be removed in WoW. Install them with feature:HookFunction,
--     feature:HookScript, or feature:Once plus feature:Guard; the hook then
--     does nothing while the feature is off.
--   * A feature whose required API is missing stays off and is shown as
--     unavailable instead of raising errors.
--   * A feature with `addon = "<folder name>"` works with another addon. It
--     stays off and the window does not list it while that addon is not
--     loaded (## OptionalDeps in the .toc makes it load first).
--   * Every category has a master switch. While it is off, none of its
--     features run, whatever their own setting says; the settings are kept.

local _, ns = ...
local L = ns.L

ns.categories = { "chronicle", "fellows", "aliases" }

-- Main features ("areas") each get an entry in the window's sidebar and a
-- page layout of their own (UI/Options.lua). Every category belongs to
-- exactly one area. The order is the sidebar's; the window opens on the
-- first. The aliases come last: they serve the other two.
ns.areas = {
    { id = "chronicle", categories = { "chronicle" } },
    { id = "fellows", categories = { "fellows" } },
    { id = "aliases", categories = { "aliases" } },
}

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
    def.generation = 0

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

local IsAddOnLoaded = C_AddOns and C_AddOns.IsAddOnLoaded

-- False for a feature made for another addon while that addon is not loaded.
function Feature:IsShown()
    return self.addon == nil or (IsAddOnLoaded ~= nil and IsAddOnLoaded(self.addon) and true or false)
end

function Feature:IsAvailable()
    if self.available == nil then
        self.available = true
        if not self:IsShown() then
            self.available = false
            self.missing = "addon " .. self.addon
        elseif self.requires then
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

local function Disable(feature)
    feature.enabled = false
    if feature.OnDisable then
        xpcall(feature.OnDisable, geterrorhandler(), feature)
    end
    for event in pairs(feature.events) do
        ns:UnregisterEvent(event, feature)
    end
    wipe(feature.events)
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

SLASH_FAMULUS1 = "/famulus"
SLASH_FAMULUS2 = "/fam"

SlashCmdList.FAMULUS = function(input)
    local command = string.lower(strtrim(input or ""))
    if command == "test" then
        ns:RunSelfTest()
    elseif command == "dev" then
        ns:SetDevMode(not ns:IsDevMode())
    elseif command == "feed" or command == "feed reset" or command == "feed test" then
        local Feed = ns.UI and ns.UI.Feed
        if not Feed then
            return
        end
        if command == "feed test" then
            -- A sample card, to see place, look and timing, and to hear the
            -- sound. Its button to react lights up and sends nothing.
            local level = UnitLevel and tonumber(UnitLevel("player")) or 1
            local given = false
            local reaction = ns.ChronicleService.ReactionsOn() and {
                icon = "cheer",
                given = function()
                    return given
                end,
                give = function()
                    given = true
                end,
            } or nil
            Feed.Show({ kind = "level", title = L.c_level:format(level), number = level, big = true, reaction = reaction },
                ns.features.liveFeed.SECONDS[ns:GetOption("liveFeed", "duration")])
            ns.features.liveFeed:Chime()
        elseif command == "feed reset" then
            Feed.ResetPlace()
            ns:Print(L.msg_feed_reset)
        else
            Feed.SetMoving(not Feed.IsMoving())
            ns:Print(Feed.IsMoving() and L.msg_feed_moving or L.msg_feed_fixed)
        end
    elseif command == "chronicle demo" then
        ns:Print(L.msg_demo_added:format(ns.ChronicleService.Demo()))
    elseif command == "chronicle demo clear" then
        ns:Print(L.msg_demo_cleared:format(ns.ChronicleService.ClearDemo()))
    elseif command == "fellows demo" then
        ns:Print(L.msg_fellow_demo_added:format(ns.FellowService.Demo()))
    elseif command == "fellows demo clear" then
        ns:Print(L.msg_fellow_demo_cleared:format(ns.FellowService.ClearDemo()))
    else
        ns:ToggleOptions()
    end
end

function Famulus_OnAddonCompartmentClick()
    ns:ToggleOptions()
end
