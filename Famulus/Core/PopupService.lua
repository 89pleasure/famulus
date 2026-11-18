-- PopupService: helpers for Blizzard's StaticPopup dialogs.
--
-- Writing fields onto a dialog or its tables taints Blizzard's popup code
-- ("action blocked"), so these helpers only find, hide and read dialogs.
-- Typing into a dialog's edit box is the one exception: SetText is a widget
-- method, not a field on Blizzard's tables.

local _, ns = ...

local PopupService = {}
ns.PopupService = PopupService

function PopupService.Hide(which)
    StaticPopup_Hide(which)
end

-- One closure per popup name, created on first use and reused afterwards.
local hiders = {}

-- Hides the popup on the next frame. The game's own handler for an event may
-- run after ours and open the popup anyway.
function PopupService.HideSoon(which)
    local hide = hiders[which]
    if not hide then
        hide = function()
            StaticPopup_Hide(which)
        end
        hiders[which] = hide
    end
    C_Timer.After(0, hide)
end

-- The first visible dialog among the given names, and its name.
function PopupService.FindVisible(names)
    for i = 1, #names do
        local dialog = StaticPopup_FindVisible(names[i])
        if dialog then
            return dialog, names[i]
        end
    end
    return nil
end

-- The dialog's edit box; the accessor differs between client versions.
function PopupService.GetEditBox(dialog)
    if not dialog then
        return nil
    end
    return (dialog.GetEditBox and dialog:GetEditBox()) or dialog.EditBox or dialog.editBox
end
