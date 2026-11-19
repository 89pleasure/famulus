-- JournalService: the diary of what the addon did on the player's behalf,
-- and of what it deliberately left alone.
--
-- Every automation reports an action once; from that come the chat line
-- (for the kinds that speak in chat) and the diary entry. Entries hold a
-- kind and its values, never finished text, so the diary follows a change
-- of language. It is account-wide data, not a setting: it lives in
-- FamulusDB.journal, outside the profiles.
--
--   FamulusDB.journal = {
--       entries = { { t = <time>, c = "<character>", k = "<kind>", ... }, ... },
--       days    = { ["2026-11-19"] = { <counter> = <number>, ... }, ... },
--       total   = { <counter> = <number>, ... },
--   }
--
-- Costs nothing while idle: one table entry per action, no events, no timer.

local _, ns = ...
local L = ns.L

local JournalService = {}
ns.JournalService = JournalService

local IsPlainText = ns.ChatService.IsPlainText

local MAX_ENTRIES = 500 -- older entries drop out; the totals keep counting
local MAX_DAYS = 90 -- how long a day's totals are kept
local MAX_ITEMS = 12 -- items listed in one "sold junk" entry
local SAME_SKIP_SECONDS = 600 -- a repeated "left alone" is written once

ns:RegisterDefaults("general", { journal = true })

local session = {} -- counters since login
local character -- "First Last" of the character that is playing

---------------------------------------------------------------------------
-- Kinds of entries
---------------------------------------------------------------------------

-- A name or title for a sentence. Secret values may be formatted but not
-- tested, so they are passed through; a missing one gets a stand-in.
local function Word(value, fallback)
    if ns.IsSecret(value) then
        return value
    end
    return value or fallback
end

-- text(entry): the sentence, also used as the chat line.
-- count(entry, add): what the entry adds to the totals.
-- chat: speaks in chat as well. skipped: something the addon left alone.
local kinds = {
    repair = {
        chat = true,
        text = function(e)
            return (e.guild and L.msg_repair_guild or L.msg_repair):format(ns.FormatMoney(e.cost))
        end,
        count = function(e, add)
            add("repairs", 1)
            if not e.guild then
                add("repairSpent", e.cost)
            end
        end,
    },
    repairShort = {
        chat = true,
        skipped = true,
        text = function(e)
            return L.msg_repair_nomoney:format(ns.FormatMoney(e.cost))
        end,
    },
    junk = {
        chat = true,
        text = function(e)
            local money = ns.FormatMoney(e.value)
            if e.count == 1 then
                return L.msg_junk_sold_one:format(money)
            end
            return L.msg_junk_sold:format(e.count, money)
        end,
        count = function(e, add)
            add("junkItems", e.count)
            add("junkEarned", e.value)
        end,
    },
    questAccepted = {
        text = function(e)
            return L.j_quest_accepted:format(Word(e.quest, L.j_a_quest))
        end,
        count = function(_, add)
            add("questsAccepted", 1)
        end,
    },
    questTurnedIn = {
        text = function(e)
            return L.j_quest_turned_in:format(Word(e.quest, L.j_a_quest))
        end,
        count = function(_, add)
            add("questsTurnedIn", 1)
        end,
    },
    questSkipped = {
        skipped = true,
        text = function(e)
            local pattern = L["j_quest_skipped_" .. tostring(e.reason)] or L.j_quest_skipped_repeatable
            return pattern:format(Word(e.quest, L.j_a_quest))
        end,
    },
    invite = {
        chat = true,
        text = function(e)
            return L.msg_invite_accepted:format(Word(e.name, L.j_someone))
        end,
        count = function(_, add)
            add("invites", 1)
        end,
    },
    duel = {
        chat = true,
        text = function(e)
            return L.msg_duel_declined:format(Word(e.name, L.j_someone))
        end,
        count = function(_, add)
            add("duels", 1)
        end,
    },
    loot = {
        text = function(e)
            return L.j_loot:format(Word(e.item, L.j_an_item))
        end,
        count = function(_, add)
            add("loot", 1)
        end,
    },
}

-- Order of the totals page; money is the counter that belongs to a count.
JournalService.counters = {
    { key = "repairs", money = "repairSpent" },
    { key = "junkItems", money = "junkEarned" },
    { key = "questsAccepted" },
    { key = "questsTurnedIn" },
    { key = "invites" },
    { key = "duels" },
    { key = "loot" },
}

---------------------------------------------------------------------------
-- Storage
---------------------------------------------------------------------------

local function Store(create)
    local global = ns.global
    if not global then
        return nil
    end
    local journal = global.journal
    if type(journal) ~= "table" then
        if not create then
            return nil
        end
        journal = {}
        global.journal = journal
    end
    if type(journal.entries) ~= "table" then
        journal.entries = {}
    end
    if type(journal.days) ~= "table" then
        journal.days = {}
    end
    if type(journal.total) ~= "table" then
        journal.total = {}
    end
    return journal
end

local function DayKey(timestamp)
    return date("%Y-%m-%d", timestamp)
end
JournalService.DayKey = DayKey

local function Add(counters, key, amount)
    counters[key] = (counters[key] or 0) + (amount or 0)
end

-- Keeps what may be stored: plain strings and numbers only. A secret value
-- (a name during an encounter) is dropped; the sentence then says "someone".
local function Clean(entry)
    for key, value in pairs(entry) do
        if ns.IsSecret(value) then
            entry[key] = nil
        else
            local kind = type(value)
            if kind == "string" then
                if value == "" then
                    entry[key] = nil
                end
            elseif kind ~= "number" and kind ~= "boolean" and kind ~= "table" then
                entry[key] = nil
            end
        end
    end
    return entry
end

local function IsRepeatedSkip(entries, entry)
    for i = #entries, math.max(1, #entries - 7), -1 do
        local old = entries[i]
        if entry.t - (old.t or 0) > SAME_SKIP_SECONDS then
            return false
        end
        if old.k == entry.k and old.reason == entry.reason and old.quest == entry.quest and old.cost == entry.cost then
            return true
        end
    end
    return false
end

---------------------------------------------------------------------------
-- Reporting and reading
---------------------------------------------------------------------------

-- An automation did something, or left something alone. kind: see `kinds`;
-- entry: its values (cost, count, quest, name, ...). The table is kept.
function JournalService.Report(kind, entry)
    local spec = kinds[kind]
    if not spec then
        return
    end
    entry = entry or {}
    entry.k = kind
    if spec.chat then
        ns:Notify(spec.text(entry))
    end
    if not ns:GetOption("general", "journal") then
        return
    end
    local journal = Store(true)
    if not journal then
        return
    end

    Clean(entry)
    entry.t = time()
    entry.c = character
    local entries = journal.entries
    if spec.skipped and IsRepeatedSkip(entries, entry) then
        return
    end
    entries[#entries + 1] = entry
    if #entries > MAX_ENTRIES then
        table.remove(entries, 1)
    end

    if spec.count then
        local key = DayKey(entry.t)
        local day = journal.days[key]
        if not day then
            day = {}
            journal.days[key] = day
        end
        local function Count(counter, amount)
            Add(day, counter, amount)
            Add(journal.total, counter, amount)
            Add(session, counter, amount)
        end
        spec.count(entry, Count)
    end
    ns:Fire("JOURNAL_CHANGED")
end

-- The entries, oldest first. The array is shared; callers must not change it.
function JournalService.Entries()
    local journal = Store()
    return journal and journal.entries or {}
end

-- The sentence for an entry, and whether it tells of something left alone.
function JournalService.Text(entry)
    local spec = kinds[entry.k]
    if not spec then
        return "", false
    end
    return spec.text(entry), spec.skipped == true
end

-- Counters for "session", "week" (today and the six days before) or "total".
function JournalService.Totals(scope)
    if scope == "session" then
        return session
    end
    local journal = Store()
    if not journal then
        return {}
    end
    if scope ~= "week" then
        return journal.total
    end
    local sum, now = {}, time()
    for back = 0, 6 do
        local day = journal.days[DayKey(now - back * 86400)]
        if day then
            for counter, amount in pairs(day) do
                Add(sum, counter, amount)
            end
        end
    end
    return sum
end

-- The character an entry belongs to, if it is not the one playing.
function JournalService.OtherCharacter(entry)
    if entry.c and entry.c ~= character then
        return entry.c
    end
    return nil
end

function JournalService.Clear()
    if ns.global then
        ns.global.journal = nil
    end
    session = {}
    ns:Fire("JOURNAL_CHANGED")
end

---------------------------------------------------------------------------
-- Loading
---------------------------------------------------------------------------

ns:On("DATABASE_READY", function()
    local journal = Store()
    if not journal then
        return
    end
    -- The saved file can be edited by hand; drop what is not an entry.
    local entries, kept = journal.entries, {}
    for i = 1, #entries do
        local entry = entries[i]
        if type(entry) == "table" and type(entry.t) == "number" and kinds[entry.k] then
            kept[#kept + 1] = entry
        end
    end
    while #kept > MAX_ENTRIES do
        table.remove(kept, 1)
    end
    journal.entries = kept
    -- Days that are too old leave; the grand total keeps them.
    local oldest = DayKey(time() - MAX_DAYS * 86400)
    for key, day in pairs(journal.days) do
        if type(key) ~= "string" or type(day) ~= "table" or key < oldest then
            journal.days[key] = nil
        end
    end
end)

ns:On("LOGIN", function()
    local name, surname = UnitName("player")
    if IsPlainText(name) then
        character = IsPlainText(surname) and (name .. " " .. surname) or name
    end
end)

JournalService.MAX_ITEMS = MAX_ITEMS
