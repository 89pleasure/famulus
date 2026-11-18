-- Easier item deletion: types the confirmation word into the delete popup.
-- Nothing is written into the popup's own tables (that would taint
-- Blizzard's popup code) and the click stays with the player.

local _, ns = ...

local easyDelete = ns:NewFeature({
    id = "easyDelete",
    category = "loot",
    default = false,
    requires = { "StaticPopup_FindVisible", "DELETE_ITEM_CONFIRM_STRING" },
})

-- Read by the self-test.
easyDelete.popups = { "DELETE_GOOD_ITEM", "DELETE_GOOD_QUEST_ITEM" }

local function FillConfirmation(self)
    local editBox = ns.PopupService.GetEditBox(ns.PopupService.FindVisible(self.popups))
    if editBox then
        editBox:SetText(DELETE_ITEM_CONFIRM_STRING)
    end
end

function easyDelete:OnEnable()
    self:RegisterEvent("DELETE_ITEM_CONFIRM")
end

function easyDelete:DELETE_ITEM_CONFIRM()
    -- The popup opens after this event; fill it on the next frame.
    self:After(0, FillConfirmation)
end
