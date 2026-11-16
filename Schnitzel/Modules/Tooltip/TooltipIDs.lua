-- Item and spell IDs in the tooltip.

local _, ns = ...
local L = ns.L

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
    if not data then
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
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, self:Guard(function(tooltip, data)
            AddLine(tooltip, data, "tt_item_id")
        end))
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Spell, self:Guard(function(tooltip, data)
            AddLine(tooltip, data, "tt_spell_id")
        end))
    end)
end
