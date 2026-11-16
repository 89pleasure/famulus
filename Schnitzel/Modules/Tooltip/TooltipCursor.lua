-- Anchors the default tooltip at the mouse cursor.

local _, ns = ...

local cursor = ns:NewFeature({
    id = "tooltipCursor",
    category = "tooltip",
    default = false,
    requires = { "hooksecurefunc", "GameTooltip_SetDefaultAnchor" },
})

-- The client keeps a cursor-anchored tooltip glued to the mouse by itself,
-- so no per-frame repositioning is needed.
local function AnchorAtCursor(tooltip, parent)
    if not parent then
        return
    end
    if tooltip.IsForbidden and tooltip:IsForbidden() then
        return
    end
    tooltip:SetOwner(parent, "ANCHOR_CURSOR_RIGHT", 24, 8)
end

function cursor:OnEnable()
    self:HookFunction("GameTooltip_SetDefaultAnchor", AnchorAtCursor)
end
