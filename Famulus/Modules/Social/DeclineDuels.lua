-- Declines duel requests.

local _, ns = ...
local L = ns.L

local duels = ns:NewFeature({
    id = "declineDuels",
    category = "social",
    default = false,
    requires = { "CancelDuel" },
})

function duels:OnEnable()
    self:RegisterEvent("DUEL_REQUESTED")
end

function duels:DUEL_REQUESTED(_, name)
    if ns:IsPaused() then
        return
    end
    CancelDuel()
    ns.PopupService.HideSoon("DUEL_REQUESTED")
    ns:Notify(L.msg_duel_declined:format(ns.Label(name)))
end
