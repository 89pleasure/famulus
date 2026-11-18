-- Adds the alias as a line to the tooltip of a player.
--
-- The name line itself stays Blizzard's: rewriting it would put addon text
-- into a line the game owns and may treat as secret.

local _, ns = ...
local L = ns.L

local AliasService = ns.AliasService

local tooltipAliases = ns:NewFeature({
    id = "tooltipAliases",
    category = "aliases",
    default = true,
    requires = {
        "TooltipDataProcessor.AddTooltipPostCall",
        "Enum.TooltipDataType.Unit",
        "UnitName",
        "UnitIsPlayer",
    },
})

local function AddLine(tooltip)
    if AliasService.Count() == 0 or tooltip ~= GameTooltip then
        return
    end
    if tooltip.IsForbidden and tooltip:IsForbidden() then
        return
    end
    if not tooltip.GetUnit then
        return
    end
    local _, unit = tooltip:GetUnit()
    if not ns.ChatService.IsPlainText(unit) then
        return
    end
    local isPlayer = UnitIsPlayer(unit)
    if ns.IsSecret(isPlayer) or not isPlayer then
        return
    end
    -- AliasService.Get refuses secret names by itself.
    local alias = AliasService.Get(UnitName(unit))
    if alias then
        tooltip:AddDoubleLine(L.tt_alias, alias, 0.61, 0.64, 0.73, 1, 1, 1)
    end
end

function tooltipAliases:OnEnable()
    self:Once("hooks", function()
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, self:Guard(AddLine))
    end)
end
