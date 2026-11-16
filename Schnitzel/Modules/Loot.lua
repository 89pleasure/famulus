-- Looting and item handling.

local _, ns = ...

---------------------------------------------------------------------------
-- Faster auto-loot
---------------------------------------------------------------------------

local fastLoot = ns:NewFeature({
    id = "fastLoot",
    category = "loot",
    default = true,
    requires = { "GetNumLootItems", "LootSlot", "GetCVarBool", "IsModifiedClick" },
})

local lastLoot = 0

function fastLoot:OnEnable()
    self:RegisterEvent("LOOT_READY")
end

function fastLoot:LOOT_READY()
    -- Only when the player wants auto-loot for this corpse: the setting and
    -- the auto-loot modifier key cancel each other out.
    if GetCVarBool("autoLootDefault") == IsModifiedClick("AUTOLOOTTOGGLE") then
        return
    end
    local now = GetTime()
    if now - lastLoot < 0.3 then
        return
    end
    lastLoot = now
    for slot = GetNumLootItems(), 1, -1 do
        LootSlot(slot)
    end
end

---------------------------------------------------------------------------
-- Confirm bind-on-pickup loot while solo
---------------------------------------------------------------------------

local confirmBoP = ns:NewFeature({
    id = "confirmBoP",
    category = "loot",
    default = false,
    requires = { "ConfirmLootSlot", "IsInGroup" },
})

local function HideBindPopup()
    StaticPopup_Hide("LOOT_BIND")
end

function confirmBoP:OnEnable()
    self:RegisterEvent("LOOT_BIND_CONFIRM")
end

function confirmBoP:LOOT_BIND_CONFIRM(_, slot)
    -- In a group somebody else might need the item, so the question stays.
    if ns:IsPaused() or IsInGroup() or not slot then
        return
    end
    ConfirmLootSlot(slot)
    -- The game's own handler for this event may run after ours and open the
    -- popup anyway; close it on the next frame.
    C_Timer.After(0, HideBindPopup)
end

---------------------------------------------------------------------------
-- Easier item deletion
---------------------------------------------------------------------------

local easyDelete = ns:NewFeature({
    id = "easyDelete",
    category = "loot",
    default = false,
    requires = { "StaticPopup_FindVisible", "DELETE_ITEM_CONFIRM_STRING" },
})

local DELETE_POPUPS = { "DELETE_GOOD_ITEM", "DELETE_GOOD_QUEST_ITEM" }
-- Read by the self-test.
easyDelete.popups = DELETE_POPUPS

-- Only types the word. Nothing is written into the popup's own tables (that
-- would taint Blizzard's popup code) and the click stays with the player.
local function FillDeleteConfirmation()
    if not easyDelete.enabled then
        return
    end
    for i = 1, #DELETE_POPUPS do
        local dialog = StaticPopup_FindVisible(DELETE_POPUPS[i])
        if dialog then
            local editBox = (dialog.GetEditBox and dialog:GetEditBox()) or dialog.EditBox or dialog.editBox
            if editBox then
                editBox:SetText(DELETE_ITEM_CONFIRM_STRING)
            end
            return
        end
    end
end

function easyDelete:OnEnable()
    self:RegisterEvent("DELETE_ITEM_CONFIRM")
end

function easyDelete:DELETE_ITEM_CONFIRM()
    C_Timer.After(0, FillDeleteConfirmation)
end
