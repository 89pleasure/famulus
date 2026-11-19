-- QuestService: what the quest features share.
--
-- Safety rules (learned from other addons' bug reports):
--   * the pause key always wins
--   * never pick a reward for the player
--   * never touch repeatable quests (they can eat items or gold on every
--     visit) or quests that ask for money
--   * never accept a quest that flags the player for PvP
--
-- NPC quest lists: several features may act on the same gossip window, but
-- only one selection per window may happen. Each feature adds a picker; the
-- service listens to the list events while at least one picker's feature is
-- on, and asks the pickers in their order until one of them selects a quest.

local _, ns = ...

local QuestService = {}
ns.QuestService = QuestService

---------------------------------------------------------------------------
-- Rules
---------------------------------------------------------------------------

function QuestService.IsRepeatable(questID)
    if not questID or questID == 0 then
        return false
    end
    local check = C_QuestLog and C_QuestLog.IsRepeatableQuest
    return check ~= nil and check(questID) or false
end

function QuestService.IsTrivial(questID)
    if not questID or questID == 0 then
        return false
    end
    local check = C_QuestLog and C_QuestLog.IsQuestTrivial
    return check ~= nil and check(questID) or false
end

function QuestService.CostsMoney()
    return GetQuestMoneyToGet ~= nil and (GetQuestMoneyToGet() or 0) > 0
end

-- The quest in the open quest window.
function QuestService.CurrentQuestID()
    return GetQuestID and GetQuestID()
end

-- Its title, for the journal.
function QuestService.CurrentTitle()
    return GetTitleText and GetTitleText() or nil
end

-- Journal entries of the quest features: "questAccepted", "questTurnedIn",
-- or "questSkipped" with the reason the quest was left alone.
function QuestService.Report(kind, reason, title)
    ns.JournalService.Report(kind, { quest = title or QuestService.CurrentTitle(), reason = reason })
end

---------------------------------------------------------------------------
-- NPC quest lists
---------------------------------------------------------------------------

-- Sorted by order. A picker is
--   { feature = <feature>, order = <number>, gossip = fn, greeting = fn }
-- where gossip/greeting are called as fn(feature) and return true once they
-- selected a quest.
local pickers = {}
local listener = {}

local function Pick(kind)
    if ns:IsPaused() then
        return
    end
    for i = 1, #pickers do
        local picker = pickers[i]
        local pick = picker[kind]
        if picker.feature.enabled and pick and pick(picker.feature) then
            return
        end
    end
end

local function OnGossipShow()
    Pick("gossip")
end

-- Older style quest givers that list their quests without a gossip window.
local function OnQuestGreeting()
    Pick("greeting")
end

local listening = false

local function UpdateListEvents()
    local wanted = false
    for i = 1, #pickers do
        wanted = wanted or pickers[i].feature.enabled
    end
    if wanted == listening then
        return
    end
    listening = wanted
    if wanted then
        ns:RegisterEvent("GOSSIP_SHOW", listener, OnGossipShow)
        ns:RegisterEvent("QUEST_GREETING", listener, OnQuestGreeting)
    else
        ns:UnregisterEvent("GOSSIP_SHOW", listener)
        ns:UnregisterEvent("QUEST_GREETING", listener)
    end
end

function QuestService.AddPicker(feature, picker)
    picker.feature = feature
    local index = #pickers + 1
    while index > 1 and pickers[index - 1].order > picker.order do
        index = index - 1
    end
    table.insert(pickers, index, picker)
end

-- Runs after every state change of a feature, so a picker's feature needs no
-- OnEnable/OnDisable code for the list events.
ns:On("FEATURE_STATE", function(feature)
    for i = 1, #pickers do
        if pickers[i].feature == feature then
            UpdateListEvents()
            return
        end
    end
end)
