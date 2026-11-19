-- Confirms bind-on-pickup loot while solo.

local _, ns = ...

local confirmBoP = ns:NewFeature({
    id = "confirmBoP",
    category = "loot",
    default = false,
    requires = { "ConfirmLootSlot", "IsInGroup" },
})

function confirmBoP:OnEnable()
    self:RegisterEvent("LOOT_BIND_CONFIRM")
end

function confirmBoP:LOOT_BIND_CONFIRM(_, slot)
    -- In a group somebody else might need the item, so the question stays.
    if ns:IsPaused() or IsInGroup() or not slot then
        return
    end
    local item = GetLootSlotLink and GetLootSlotLink(slot)
    ConfirmLootSlot(slot)
    ns.JournalService.Report("loot", { item = item })
    ns.PopupService.HideSoon("LOOT_BIND")
end
