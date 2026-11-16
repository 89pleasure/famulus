-- Vendor chores: repair and junk selling when a merchant window opens.

local _, ns = ...
local L = ns.L

---------------------------------------------------------------------------
-- Auto repair
---------------------------------------------------------------------------

local repair = ns:NewFeature({
    id = "autoRepair",
    category = "vendor",
    default = false,
    requires = { "CanMerchantRepair", "GetRepairAllCost", "RepairAllItems", "GetMoney" },
    options = {
        { key = "guildFunds", type = "toggle", default = false, requires = "CanGuildBankRepair" },
    },
})

local function RepairWithOwnGold(cost)
    if GetMoney() >= cost then
        RepairAllItems()
        ns:Notify(L.msg_repair:format(ns.FormatMoney(cost)))
    else
        ns:Notify(L.msg_repair_nomoney:format(ns.FormatMoney(cost)))
    end
end

local guildCost = 0

-- The client does not say whether a guild-funded repair went through, so
-- look at what is still broken a moment later and pay the rest ourselves.
local function CheckGuildRepair()
    if not repair.enabled or not CanMerchantRepair() then
        return
    end
    local remaining, needsRepair = GetRepairAllCost()
    if needsRepair and remaining and remaining > 0 then
        RepairWithOwnGold(remaining)
    else
        ns:Notify(L.msg_repair_guild:format(ns.FormatMoney(guildCost)))
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
        C_Timer.After(0.5, CheckGuildRepair)
    else
        RepairWithOwnGold(cost)
    end
end

---------------------------------------------------------------------------
-- Sell junk
---------------------------------------------------------------------------

local junk = ns:NewFeature({
    id = "sellJunk",
    category = "vendor",
    default = false,
    requires = {
        "C_Container.GetContainerNumSlots",
        "C_Container.GetContainerItemInfo",
        "C_Container.UseContainerItem",
        "C_Item.GetItemInfo",
    },
})

-- Selling is spread out, one item per tick: the server drops sales that
-- arrive in a burst. The queue is three parallel arrays that are reused.
local SELL_INTERVAL = 0.15
local POOR = (Enum and Enum.ItemQuality and Enum.ItemQuality.Poor) or 0

local queueBag, queueSlot, queueItem = {}, {}, {}
local queueSize, queuePos = 0, 0
local soldCount, soldValue = 0, 0

local function FinishSelling()
    junk:StopTicker()
    queueSize, queuePos = 0, 0
    if soldCount > 0 then
        local money = ns.FormatMoney(soldValue)
        if soldCount == 1 then
            ns:Notify(L.msg_junk_sold_one:format(money))
        else
            ns:Notify(L.msg_junk_sold:format(soldCount, money))
        end
    end
    soldCount, soldValue = 0, 0
end

local function SellNext()
    queuePos = queuePos + 1
    if queuePos > queueSize or not (MerchantFrame and MerchantFrame:IsShown()) then
        FinishSelling()
        return
    end
    local bag, slot = queueBag[queuePos], queueSlot[queuePos]
    local info = C_Container.GetContainerItemInfo(bag, slot)
    -- The bag may have changed since the queue was built: sell only if the
    -- slot still holds the very item that was queued.
    if info and info.itemID == queueItem[queuePos] and not info.isLocked then
        local _, _, _, _, _, _, _, _, _, _, price = C_Item.GetItemInfo(info.hyperlink or info.itemID)
        C_Container.UseContainerItem(bag, slot)
        soldCount = soldCount + 1
        soldValue = soldValue + (price or 0) * (info.stackCount or 1)
    end
end

function junk:OnEnable()
    self:RegisterEvent("MERCHANT_SHOW")
    self:RegisterEvent("MERCHANT_CLOSED")
end

function junk:OnDisable()
    queueSize, queuePos, soldCount, soldValue = 0, 0, 0, 0
end

function junk:MERCHANT_SHOW()
    if ns:IsPaused() then
        return
    end
    queueSize, queuePos, soldCount, soldValue = 0, 0, 0, 0
    for bag = 0, NUM_BAG_SLOTS or 4 do
        for slot = 1, C_Container.GetContainerNumSlots(bag) do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            if info and info.quality == POOR and not info.hasNoValue and info.itemID then
                queueSize = queueSize + 1
                queueBag[queueSize] = bag
                queueSlot[queueSize] = slot
                queueItem[queueSize] = info.itemID
            end
        end
    end
    if queueSize > 0 then
        self:StartTicker(SELL_INTERVAL, SellNext)
    end
end

function junk:MERCHANT_CLOSED()
    if queueSize > 0 then
        FinishSelling()
    end
end
