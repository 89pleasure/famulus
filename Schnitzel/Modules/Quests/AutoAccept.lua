-- Accepts offered quests. Safety rules: see QuestService.lua.

local _, ns = ...
local QuestService = ns.QuestService

local accept = ns:NewFeature({
    id = "autoAccept",
    category = "quests",
    default = false,
    requires = { "AcceptQuest", "C_GossipInfo.GetAvailableQuests", "C_GossipInfo.SelectAvailableQuest" },
    options = {
        { key = "skipTrivial", type = "toggle", default = true },
    },
})

-- Picks up after AutoTurnIn had its turn at the NPC's list.
QuestService.AddPicker(accept, {
    order = 20,
    gossip = function(self)
        local skipTrivial = self:Get("skipTrivial")
        local quests = C_GossipInfo.GetAvailableQuests()
        for i = 1, #quests do
            local quest = quests[i]
            if quest.questID and not quest.repeatable and not (skipTrivial and quest.isTrivial) then
                C_GossipInfo.SelectAvailableQuest(quest.questID)
                return true
            end
        end
        return false
    end,
    greeting = function(self)
        if not (GetNumAvailableQuests and GetAvailableQuestInfo and SelectAvailableQuest) then
            return false
        end
        local skipTrivial = self:Get("skipTrivial")
        for i = 1, GetNumAvailableQuests() do
            local isTrivial, _, isRepeatable = GetAvailableQuestInfo(i)
            if not isRepeatable and not (skipTrivial and isTrivial) then
                SelectAvailableQuest(i)
                return true
            end
        end
        return false
    end,
})

function accept:OnEnable()
    self:RegisterEvent("QUEST_DETAIL")
    if ConfirmAcceptQuest then
        self:RegisterEvent("QUEST_ACCEPT_CONFIRM")
    end
end

function accept:QUEST_DETAIL()
    if ns:IsPaused() then
        return
    end
    local questID = QuestService.CurrentQuestID()
    if QuestService.IsRepeatable(questID) or (self:Get("skipTrivial") and QuestService.IsTrivial(questID)) then
        return
    end
    if QuestFlagsPVP and QuestFlagsPVP() then
        return
    end
    if QuestGetAutoAccept and QuestGetAutoAccept() and AcknowledgeAutoAcceptQuest then
        -- The game already put the quest into the log; just close the window.
        AcknowledgeAutoAcceptQuest()
    else
        AcceptQuest()
    end
end

-- A group member started an escort quest and the game asks whether to join.
function accept:QUEST_ACCEPT_CONFIRM()
    if not ns:IsPaused() then
        ConfirmAcceptQuest()
        ns.PopupService.Hide("QUEST_ACCEPT")
    end
end
