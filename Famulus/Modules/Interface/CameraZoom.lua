-- Raises the maximum camera distance and restores the player's own value
-- when switched off. Not a mirrored option: the addon changes the game's
-- setting only for as long as the feature is on.

local _, ns = ...

local camera = ns:NewFeature({
    id = "cameraZoom",
    category = "interface",
    default = false,
    requires = { "C_CVar.GetCVar", "C_CVar.SetCVar" },
})

local ZOOM_CVAR = "cameraDistanceMaxZoomFactor"
-- Game versions cap this at different values; take the highest one accepted.
local ZOOM_CANDIDATES = { 4.0, 2.6 }
-- Read by the self-test.
camera.zoomCVar = ZOOM_CVAR
camera.zoomCandidates = ZOOM_CANDIDATES

function camera:OnEnable()
    local current = tonumber(C_CVar.GetCVar(ZOOM_CVAR))
    if not current then
        return
    end
    -- Remember the player's own value once, so switching off restores it.
    if not ns.global.cameraZoomBefore then
        ns.global.cameraZoomBefore = current
    end
    for i = 1, #ZOOM_CANDIDATES do
        local target = ZOOM_CANDIDATES[i]
        if current >= target then
            break
        end
        pcall(C_CVar.SetCVar, ZOOM_CVAR, target)
        if (tonumber(C_CVar.GetCVar(ZOOM_CVAR)) or 0) >= target - 0.01 then
            break
        end
    end
end

function camera:OnDisable()
    local before = ns.global.cameraZoomBefore
    if before then
        pcall(C_CVar.SetCVar, ZOOM_CVAR, before)
        ns.global.cameraZoomBefore = nil
    end
end
