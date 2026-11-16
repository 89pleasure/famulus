-- Quest automation: accept and turn in.
--
-- Safety rules (learned from other addons' bug reports):
--   * the pause key always wins
--   * never pick a reward for the player
--   * never touch repeatable quests (they can eat items or gold on every
--     visit) or quests that ask for money
--   * never accept a quest that flags the player for PvP

local _, ns = ...

local accept = ns:NewFeature({
    id = "autoAccept",
    category = "quests",
    default = false,
    requires = { "AcceptQuest", "C_GossipInfo.GetAvailableQuests", "C_GossipInfo.SelectAvailableQuest" },
    options = {
        { key = "skipTrivial", type = "toggle", default = true },
    },
})

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

local function IsRepeatable(questID)
    if not questID or questID == 0 then
        return false
    end
    local check = C_QuestLog and C_QuestLog.IsRepeatableQuest
    return check ~= nil and check(questID) or false
end

local function IsTrivial(questID)
    if not questID or questID == 0 then
        return false
    end
    local check = C_QuestLog and C_QuestLog.IsQuestTrivial
    return check ~= nil and check(questID) or false
end

local function CostsMoney()
    return GetQuestMoneyToGet ~= nil and (GetQuestMoneyToGet() or 0) > 0
end

---------------------------------------------------------------------------
-- NPC quest lists. Both features act here, so they share one handler that
-- makes exactly one selection per window: hand in first, then pick up.
---------------------------------------------------------------------------

local lists = {}

local function OnGossipShow()
    if ns:IsPaused() then
        return
    end
    if turnIn.enabled then
        local quests = C_GossipInfo.GetActiveQuests()
        for i = 1, #quests do
            local quest = quests[i]
            if quest.isComplete and quest.questID and not quest.repeatable and not IsRepeatable(quest.questID) then
                C_GossipInfo.SelectActiveQuest(quest.questID)
                return
            end
        end
    end
    if accept.enabled then
        local skipTrivial = accept:Get("skipTrivial")
        local quests = C_GossipInfo.GetAvailableQuests()
        for i = 1, #quests do
            local quest = quests[i]
            if quest.questID and not quest.repeatable and not (skipTrivial and quest.isTrivial) then
                C_GossipInfo.SelectAvailableQuest(quest.questID)
                return
            end
        end
    end
end

-- Older style quest givers that list their quests without a gossip window.
local function OnQuestGreeting()
    if ns:IsPaused() then
        return
    end
    if turnIn.enabled and GetNumActiveQuests and GetActiveTitle and SelectActiveQuest then
        for i = 1, GetNumActiveQuests() do
            local _, isComplete = GetActiveTitle(i)
            local questID = GetActiveQuestID and GetActiveQuestID(i)
            if isComplete and not IsRepeatable(questID) then
                SelectActiveQuest(i)
                return
            end
        end
    end
    if accept.enabled and GetNumAvailableQuests and GetAvailableQuestInfo and SelectAvailableQuest then
        local skipTrivial = accept:Get("skipTrivial")
        for i = 1, GetNumAvailableQuests() do
            local isTrivial, _, isRepeatable = GetAvailableQuestInfo(i)
            if not isRepeatable and not (skipTrivial and isTrivial) then
                SelectAvailableQuest(i)
                return
            end
        end
    end
end

local function UpdateListEvents()
    if accept.enabled or turnIn.enabled then
        ns:RegisterEvent("GOSSIP_SHOW", lists, OnGossipShow)
        ns:RegisterEvent("QUEST_GREETING", lists, OnQuestGreeting)
    else
        ns:UnregisterEvent("GOSSIP_SHOW", lists)
        ns:UnregisterEvent("QUEST_GREETING", lists)
    end
end

---------------------------------------------------------------------------
-- Accept
---------------------------------------------------------------------------

function accept:OnEnable()
    self:RegisterEvent("QUEST_DETAIL")
    if ConfirmAcceptQuest then
        self:RegisterEvent("QUEST_ACCEPT_CONFIRM")
    end
    UpdateListEvents()
end

function accept:OnDisable()
    UpdateListEvents()
end

function accept:QUEST_DETAIL()
    if ns:IsPaused() then
        return
    end
    local questID = GetQuestID and GetQuestID()
    if IsRepeatable(questID) or (self:Get("skipTrivial") and IsTrivial(questID)) then
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
        StaticPopup_Hide("QUEST_ACCEPT")
    end
end

---------------------------------------------------------------------------
-- Turn in
---------------------------------------------------------------------------

function turnIn:OnEnable()
    self:RegisterEvent("QUEST_PROGRESS")
    self:RegisterEvent("QUEST_COMPLETE")
    UpdateListEvents()
end

function turnIn:OnDisable()
    UpdateListEvents()
end

function turnIn:QUEST_PROGRESS()
    if ns:IsPaused() or not IsQuestCompletable() then
        return
    end
    if IsRepeatable(GetQuestID and GetQuestID()) or CostsMoney() then
        return
    end
    CompleteQuest()
end

function turnIn:QUEST_COMPLETE()
    if ns:IsPaused() then
        return
    end
    if IsRepeatable(GetQuestID and GetQuestID()) or CostsMoney() then
        return
    end
    local choices = GetNumQuestChoices()
    if choices <= 1 then
        GetQuestReward(choices)
    end
end
