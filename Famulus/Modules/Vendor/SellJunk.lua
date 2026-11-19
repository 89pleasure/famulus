-- Sells poor-quality items when a merchant window opens.

local _, ns = ...
local Journal = ns.JournalService

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
local soldItems -- what went, for the journal: { { n = name, q = count }, ... }

local function ResetQueue()
    queueSize, queuePos, soldCount, soldValue = 0, 0, 0, 0
    soldItems = nil
end

local function FinishSelling()
    junk:StopTicker()
    if soldCount > 0 then
        Journal.Report("junk", { count = soldCount, value = soldValue, items = soldItems })
    end
    ResetQueue()
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
        local name, _, _, _, _, _, _, _, _, _, price = C_Item.GetItemInfo(info.hyperlink or info.itemID)
        C_Container.UseContainerItem(bag, slot)
        soldCount = soldCount + 1
        soldValue = soldValue + (price or 0) * (info.stackCount or 1)
        soldItems = soldItems or {}
        if #soldItems < Journal.MAX_ITEMS and type(name) == "string" then
            soldItems[#soldItems + 1] = { n = name, q = info.stackCount or 1 }
        end
    end
end

function junk:OnEnable()
    self:RegisterEvent("MERCHANT_SHOW")
    self:RegisterEvent("MERCHANT_CLOSED")
end

function junk:OnDisable()
    ResetQueue()
end

function junk:MERCHANT_SHOW()
    if ns:IsPaused() then
        return
    end
    ResetQueue()
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
