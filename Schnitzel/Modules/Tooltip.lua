-- Tooltip tweaks. Hooks cannot be removed in WoW, so each one is installed
-- the first time its feature is switched on and checks the feature state.

local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Item and spell IDs
---------------------------------------------------------------------------

local ids = ns:NewFeature({
    id = "tooltipIDs",
    category = "tooltip",
    default = false,
    requires = {
        "TooltipDataProcessor.AddTooltipPostCall",
        "Enum.TooltipDataType.Item",
        "Enum.TooltipDataType.Spell",
    },
})

local function AddLine(tooltip, data, labelKey)
    if not ids.enabled or not data then
        return
    end
    -- Comparison tooltips and other addons' tooltips stay untouched.
    if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then
        return
    end
    if tooltip.IsForbidden and tooltip:IsForbidden() then
        return
    end
    local id = data.id
    if not id or ns.IsSecret(id) then
        return
    end
    tooltip:AddDoubleLine(L[labelKey], id, 0.61, 0.64, 0.73, 1, 1, 1)
end

function ids:OnEnable()
    self:Once("hooks", function()
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
            AddLine(tooltip, data, "tt_item_id")
        end)
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, function(tooltip, data)
            AddLine(tooltip, data, "tt_spell_id")
        end)
    end)
end

---------------------------------------------------------------------------
-- Tooltip at the cursor
---------------------------------------------------------------------------

local cursor = ns:NewFeature({
    id = "tooltipCursor",
    category = "tooltip",
    default = false,
    requires = { "hooksecurefunc", "GameTooltip_SetDefaultAnchor" },
})

function cursor:OnEnable()
    self:Once("hook", function()
        -- The client keeps a cursor-anchored tooltip glued to the mouse by
        -- itself, so no per-frame repositioning is needed.
        hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
            if not cursor.enabled or not parent then
                return
            end
            if tooltip.IsForbidden and tooltip:IsForbidden() then
                return
            end
            tooltip:SetOwner(parent, "ANCHOR_CURSOR_RIGHT", 24, 8)
        end)
    end)
end
