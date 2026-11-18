-- Features whose switch mirrors one of the game's own options (a CVar).
--
--   ns:NewFeature({
--       id = "autoLoot",
--       category = "loot",
--       default = false,
--       mirror = { cvar = "autoLootDefault" },   -- on = "1", off = "0" unless given
--   })
--
-- Such a feature needs no code of its own. The rules:
--   * The game's option is the truth. At login, whenever the game reports a
--     change (its CVarCallbackRegistry, so no event of ours), and when the
--     settings window opens, the switch takes over the game's value without
--     writing anything back.
--   * Switching the feature on sets the game's option; switching the feature
--     itself off clears it.
--   * A category switched off stops the feature but leaves the game's option
--     alone: the category is about Famulus, not about the game.
--   * Nothing is written before the switch has followed the game once, so a
--     login never overrides what the player set in the game's options.

local _, ns = ...

local mirrored = {}
local followed = false

local function OnValue(mirror)
    return mirror.on or "1"
end

local function OffValue(mirror)
    return mirror.off or "0"
end

local function SetGameValue(cvar, value)
    if C_CVar.GetCVar(cvar) ~= value then
        C_CVar.SetCVar(cvar, value)
    end
end

-- Takes the game's value over into the feature's switch.
local function Follow(feature)
    if not feature:IsAvailable() then
        return
    end
    local gameOn = C_CVar.GetCVar(feature.mirror.cvar) == OnValue(feature.mirror)
    if (ns:GetOption(feature.id, "enabled") and true or false) ~= gameOn then
        ns:SetOption(feature.id, "enabled", gameOn)
    end
end

local function FollowAll()
    for i = 1, #mirrored do
        Follow(mirrored[i])
    end
end

-- Runs after every state sync of a feature.
ns:On("FEATURE_STATE", function(feature)
    local mirror = feature.mirror
    if not (followed and mirror and feature:IsAvailable()) then
        return
    end
    if feature.enabled then
        SetGameValue(mirror.cvar, OnValue(mirror))
    elseif ns:GetOption(feature.id, "enabled") == false and ns:IsCategoryEnabled(feature.category) then
        SetGameValue(mirror.cvar, OffValue(mirror))
    end
end)

ns:On("LOGIN", function()
    for i = 1, #ns.featureList do
        local feature = ns.featureList[i]
        if feature.mirror then
            mirrored[#mirrored + 1] = feature
        end
    end
    FollowAll()
    followed = true
    if CVarCallbackRegistry and CVarCallbackRegistry.RegisterCallback then
        for i = 1, #mirrored do
            local feature = mirrored[i]
            CVarCallbackRegistry:RegisterCallback(feature.mirror.cvar, function()
                Follow(feature)
            end, feature)
        end
    end
end)

ns:On("OPTIONS_SHOWN", FollowAll)
