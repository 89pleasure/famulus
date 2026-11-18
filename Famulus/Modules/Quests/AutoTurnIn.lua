-- Hands in completed quests. Never picks a reward for the player and never
-- hands in repeatable quests or quests that cost gold (see QuestService.lua).

local _, ns = ...
local QuestService = ns.QuestService

local turnIn = ns:NewFeature({
    id = "autoTurnIn",
    category = "quests",
    default = false,
    requires = {
        "CompleteQuest",
        "GetQuestReward",
        "GetNumQuestChoices",
        "IsQuestCompletable",
        "C_GossipInfo.GetActiveQuests",
        "C_GossipInfo.SelectActiveQuest",
    },
})

-- Hands in first, so a quest giver with a finished and a new quest finishes
-- the old one before AutoAccept picks up the next.
QuestService.AddPicker(turnIn, {
    order = 10,
    gossip = function()
        local quests = C_GossipInfo.GetActiveQuests()
        for i = 1, #quests do
            local quest = quests[i]
            if quest.isComplete and quest.questID and not quest.repeatable
                and not QuestService.IsRepeatable(quest.questID) then
                C_GossipInfo.SelectActiveQuest(quest.questID)
                return true
            end
        end
        return false
    end,
    greeting = function()
        if not (GetNumActiveQuests and GetActiveTitle and SelectActiveQuest) then
            return false
        end
        for i = 1, GetNumActiveQuests() do
            local _, isComplete = GetActiveTitle(i)
            local questID = GetActiveQuestID and GetActiveQuestID(i)
            if isComplete and not QuestService.IsRepeatable(questID) then
                SelectActiveQuest(i)
                return true
            end
        end
        return false
    end,
})

local function MayHandIn()
    return not ns:IsPaused()
        and not QuestService.IsRepeatable(QuestService.CurrentQuestID())
        and not QuestService.CostsMoney()
end

function turnIn:OnEnable()
    self:RegisterEvent("QUEST_PROGRESS")
    self:RegisterEvent("QUEST_COMPLETE")
end

function turnIn:QUEST_PROGRESS()
    if MayHandIn() and IsQuestCompletable() then
        CompleteQuest()
    end
end

function turnIn:QUEST_COMPLETE()
    if not MayHandIn() then
        return
    end
    local choices = GetNumQuestChoices()
    if choices <= 1 then
        GetQuestReward(choices)
    end
end
