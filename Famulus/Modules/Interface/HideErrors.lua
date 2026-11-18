-- Hides combat error spam ("Not enough rage", "Out of range", ...).

local _, ns = ...

local errors = ns:NewFeature({
    id = "hideErrors",
    category = "interface",
    default = false,
    requires = { "UIErrorsFrame" },
})

-- Global string names, so the list matches in every client language.
local BLOCKED_GLOBALS = {
    "ERR_ABILITY_COOLDOWN",
    "ERR_SPELL_COOLDOWN",
    "ERR_ITEM_COOLDOWN",
    "ERR_OUT_OF_RAGE",
    "ERR_OUT_OF_ENERGY",
    "ERR_OUT_OF_MANA",
    "ERR_OUT_OF_FOCUS",
    "ERR_OUT_OF_RANGE",
    "ERR_SPELL_OUT_OF_RANGE",
    "ERR_BADATTACKPOS",
    "ERR_BADATTACKFACING",
    "ERR_NO_ATTACK_TARGET",
    "ERR_GENERIC_NO_TARGET",
    "ERR_INVALID_ATTACK_TARGET",
    "ERR_CLIENT_LOCKED_OUT",
    "ERR_ATTACK_STUNNED",
    "ERR_ATTACK_PACIFIED",
    "ERR_USE_TOO_FAR",
    "SPELL_FAILED_SPELL_IN_PROGRESS",
    "SPELL_FAILED_MOVING",
    "SPELL_FAILED_BAD_TARGETS",
    "SPELL_FAILED_NO_COMBO_POINTS",
    "SPELL_FAILED_UNIT_NOT_INFRONT",
    "SPELL_FAILED_TOO_CLOSE",
    "SPELL_FAILED_TARGETS_DEAD",
    "SPELL_FAILED_ITEM_NOT_READY",
    "SPELL_FAILED_NOT_READY",
}
-- Read by the self-test.
errors.blockedGlobals = BLOCKED_GLOBALS

local blocked

function errors:OnEnable()
    if not blocked then
        blocked = {}
        for i = 1, #BLOCKED_GLOBALS do
            local text = _G[BLOCKED_GLOBALS[i]]
            if type(text) == "string" then
                blocked[text] = true
            end
        end
    end
    -- Take over the error event and pass on everything that is not spam.
    UIErrorsFrame:UnregisterEvent("UI_ERROR_MESSAGE")
    self:RegisterEvent("UI_ERROR_MESSAGE")
end

function errors:OnDisable()
    UIErrorsFrame:RegisterEvent("UI_ERROR_MESSAGE")
end

function errors:UI_ERROR_MESSAGE(_, messageType, message)
    -- A secret value cannot be looked up; such messages are always shown.
    if not ns.IsSecret(message) and blocked[message] then
        return
    end
    if UIErrorsFrame.TryDisplayMessage then
        UIErrorsFrame:TryDisplayMessage(messageType, message, 1, 0.1, 0.1)
    else
        UIErrorsFrame:AddMessage(message, 1, 0.1, 0.1, 1)
    end
end
