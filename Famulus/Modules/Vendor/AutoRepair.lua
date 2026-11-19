-- Repairs all items when a merchant window opens, optionally with guild gold.

local _, ns = ...
local Journal = ns.JournalService

local repair = ns:NewFeature({
    id = "autoRepair",
    category = "vendor",
    default = false,
    requires = { "CanMerchantRepair", "GetRepairAllCost", "RepairAllItems", "GetMoney" },
    options = {
        { key = "guildFunds", type = "toggle", default = false, requires = "CanGuildBankRepair" },
    },
})

local guildCost = 0

local function RepairWithOwnGold(cost)
    if GetMoney() >= cost then
        RepairAllItems()
        Journal.Report("repair", { cost = cost })
    else
        Journal.Report("repairShort", { cost = cost })
    end
end

-- The client does not say whether a guild-funded repair went through, so
-- look at what is still broken a moment later and pay the rest ourselves.
local function CheckGuildRepair()
    if not CanMerchantRepair() then
        return
    end
    local remaining, needsRepair = GetRepairAllCost()
    if needsRepair and remaining and remaining > 0 then
        RepairWithOwnGold(remaining)
    else
        Journal.Report("repair", { cost = guildCost, guild = true })
    end
end

function repair:OnEnable()
    self:RegisterEvent("MERCHANT_SHOW")
end

function repair:MERCHANT_SHOW()
    if ns:IsPaused() or not CanMerchantRepair() then
        return
    end
    local cost, needsRepair = GetRepairAllCost()
    if not needsRepair or not cost or cost <= 0 then
        return
    end
    if self:Get("guildFunds") and CanGuildBankRepair and CanGuildBankRepair() then
        guildCost = cost
        RepairAllItems(true)
        self:After(0.5, CheckGuildRepair)
    else
        RepairWithOwnGold(cost)
    end
end
