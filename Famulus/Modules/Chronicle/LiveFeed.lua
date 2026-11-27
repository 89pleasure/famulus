-- Shows what companions have just experienced as a card on screen
-- (UI/Feed.lua), each kind of event with its own switch. The player's own
-- events appear only if asked for (option "own", off from the start): the
-- feed is about the others. A friend's card has a button to react to it, as
-- a click on their card in the chronicle does, while reactions are on
-- (option "reactions" of Sharing.lua); the card then closes.
--
-- With "keep" (off from the start) the last three cards stay on screen
-- instead of fading out. The same event of several friends at about the same
-- time (a boss defeated together, a wipe, the same challenge) shares a card.
--
-- It listens to the chronicle, not to the game: no event, no timer of its
-- own. The cards can be moved in the game's Edit Mode or with /fam feed.

local _, ns = ...

-- The kinds of events with a switch, in the order of the window. An arrival
-- in a zone is off from the start: it happens often and is rarely news.
-- "reaction": a friend reacted to one of the player's events (Sharing.lua).
local KINDS = { "level", "death", "boss", "achievement", "ability", "item", "profession", "skill", "zone", "reaction" }
local OFF_BY_DEFAULT = { zone = true }
-- The window shows the kinds as a group of chips ("kinds"), each with the
-- icon of its kind (a name from UI.media, as the chronicle's cards use).
local ICONS = {
    level = "flag",
    death = "skull",
    boss = "swords",
    achievement = "star",
    ability = "horseshoe",
    item = "chest",
    profession = "hammer",
    skill = "hammer",
    zone = "peaks",
    reaction = "cheer",
}

local options = {
    { key = "duration", type = "select", default = "normal", values = { "short", "normal", "long" } },
    { key = "keep", type = "toggle", default = false },
    { key = "sound", type = "toggle", default = true },
    { key = "own", type = "toggle", default = false },
}
for _, kind in ipairs(KINDS) do
    options[#options + 1] = { key = kind, type = "toggle", default = not OFF_BY_DEFAULT[kind], group = "kinds", icon = ICONS[kind] }
end

local feed = ns:NewFeature({
    id = "liveFeed",
    category = "chronicle",
    icon = "bell", -- its entry in the settings (UI.media)
    preview = "feed", -- its picture there (UI/Previews.lua)
    default = true,
    options = options,
})

feed.KINDS = KINDS
feed.SECONDS = { short = 4, normal = 7, long = 12 }

local FRESH = 120 -- seconds; older news (caught up on, passed on) is not announced
local listening = false

-- A soft double click comes with a card (UI.Feed.Chime), unless switched off.
function feed:Chime()
    local Feed = ns.UI and ns.UI.Feed
    if self:Get("sound") == true and Feed then
        Feed.Chime()
    end
end

-- Shows the card story() makes. In developer mode the log says whether it
-- came up, waits its turn or joined another card, so that "it did not
-- appear" can be told from "it was overlooked".
local function Show(kind, story)
    local UI = ns.UI
    if not (UI and UI.Feed) then
        return
    end
    local state
    local ok, problem = pcall(function()
        local _, how = UI.Feed.Show(story(), feed.SECONDS[feed:Get("duration")] or feed.SECONDS.normal)
        state = how or "shown"
    end)
    ns:DevLog("FEED", ok and (state .. ": " .. tostring(kind)) or ("failed: " .. tostring(kind) .. ": " .. tostring(problem)))
    if not ok then
        error(problem, 0)
    end
    feed:Chime()
end

-- The button to react to a friend's event: it gives the reaction of its kind
-- (ChronicleService.React), and Sharing.lua tells the friend, as for a click
-- in the chronicle. Taking it back is the chronicle's.
local function Reaction(entry)
    local Chronicle = ns.ChronicleService
    local reaction = Chronicle.Reaction(entry)
    if not reaction or entry.demo or not Chronicle.ReactionsOn() then
        return nil
    end
    return {
        icon = reaction,
        given = function()
            return entry.mine ~= nil
        end,
        give = function()
            -- Reactions may have been switched off since the card came.
            if Chronicle.ReactionsOn() then
                Chronicle.React(entry, true)
            end
        end,
    }
end

-- The same event of several friends at about the same time shares a card
-- (UI.Feed joins them): a boss they defeated together, deaths in one place
-- (a wipe), the same challenge. The player's own events stay on their own.
local function BundleKey(entry, kind)
    if not entry.who then
        return nil
    end
    local id = tonumber(entry.id) or (type(entry.name) == "string" and entry.name) or nil
    if (kind == "boss" or kind == "achievement") and id then
        return kind .. ":" .. tostring(id)
    elseif kind == "death" and type(entry.zone) == "string" and entry.zone ~= "" then
        return "death:" .. entry.zone
    end
    return nil
end

-- A friend as a bundle names them: the alias, else the first name.
local function Short(entry)
    local name, realName = ns.ChronicleService.Companion(entry)
    if realName then
        return name
    end
    return string.match(name, "^(%S+)") or name
end

local MAX_NAMES = 3 -- beyond that, "and 2 more"

-- "Papa and Mira", "Papa, Mira and Tom", "Papa, Mira and 2 more"
local function Names(list)
    local L = ns.L
    local names = {}
    for index = 1, math.min(#list, MAX_NAMES) do
        names[index] = list[index]
    end
    if #list > MAX_NAMES then
        local more = #list - MAX_NAMES + 1
        names[MAX_NAMES] = ns.Plural("c_feed_others", more):format(more)
    end
    if #names < 2 then
        return names[1] or ""
    end
    return L.c_and:format(table.concat(names, ", ", 1, #names - 1), names[#names])
end

-- One more friend with the same event joins a card: all of them in its head
-- and their number in the crest's corner, the place alone below it (who was
-- with whom belongs to one of them), and no button to react, as it would not
-- say to whom.
local function Join(story, other)
    local names = story.names
    names[#names + 1] = other.names[1]
    story.count = #names
    story.chip = { text = Names(names) }
    story.detail = story.place
    story.reaction = nil
end

-- A made-up friend's card (/fam feed test) has the button too; it only
-- lights up and sends nothing.
local function SampleReaction(entry)
    local Chronicle = ns.ChronicleService
    local icon = entry.who and Chronicle.ReactionsOn() and Chronicle.Reaction(entry)
    if not icon then
        return nil
    end
    local given = false
    return {
        icon = icon,
        given = function()
            return given
        end,
        give = function()
            given = true
        end,
    }
end

-- The card of an entry, as the book tells it, with the button to react and,
-- for a friend's event others may share, what lets theirs join it.
-- sample: a made-up entry, whose button sends nothing.
local function Story(entry, kind, sample)
    local story = ns.UI.FeedStory(entry)
    story.reaction = sample and SampleReaction(entry) or Reaction(entry)
    local bundle = BundleKey(entry, kind)
    if bundle then
        story.bundle, story.join = bundle, Join
        story.names = { Short(entry) }
        story.place = type(entry.zone) == "string" and entry.zone ~= "" and entry.zone or nil
    end
    return story
end

local function OnChronicleChanged(entry)
    if not feed.enabled or type(entry) ~= "table" or entry.demo then
        return
    end
    if time() - (tonumber(entry.t) or 0) > FRESH then
        return
    end
    local kind = entry.k == "friendLevel" and "level" or entry.k
    -- A kind without a switch (from a newer version) stays off screen.
    if feed:Get(kind) ~= true then
        return
    end
    if not entry.who and not feed:Get("own") then
        return
    end
    -- The player's own level-up is announced by the game itself, even with
    -- the player's own events switched on.
    if kind == "level" and not entry.who then
        return
    end
    local UI = ns.UI
    if not (UI and UI.Feed and UI.FeedStory) then
        return
    end
    Show(kind, function()
        return Story(entry, kind)
    end)
end

-- The card of a friend's reaction to one of the player's events: who in its
-- head, the reaction, and below it the event. Also the picture of the feed in
-- its settings (UI/Previews.lua).
function feed.ReactionStory(entry, who, reaction)
    local Chronicle, L = ns.ChronicleService, ns.L
    return {
        kind = "reaction",
        icon = reaction,
        chip = { text = Chronicle.Label({ who = who }) },
        title = L["c_reacted_" .. reaction],
        detail = (Chronicle.Text(entry)),
    }
end

local function OnReaction(entry, who, reaction)
    if not feed.enabled or type(entry) ~= "table" or feed:Get("reaction") ~= true then
        return
    end
    Show("reaction", function()
        return feed.ReactionStory(entry, who, reaction)
    end)
end

-- /fam feed test: a burst of sample cards, to see place, look, timing and
-- sound with one account. First the player's own level with all three rows
-- (the player's name and zone; its button lights up and sends nothing), then
-- at the same moment the samples' friends: a boss two of them defeated (one
-- card for both), a death and an item. They wait as a stack behind the first,
-- come in one after another, and the older ones shrink to rows; with "keep"
-- they stay. Nothing is stored or sent, and the switches of the kinds do not
-- apply. One sound, as for news that comes together.
function feed.Test()
    local UI = ns.UI
    local Feed = UI and UI.Feed
    if not (Feed and UI.FeedStory) then
        return
    end
    local L, Chronicle = ns.L, ns.ChronicleService
    local IsPlainText = ns.ChatService.IsPlainText
    local seconds = feed.SECONDS[feed:Get("duration")] or feed.SECONDS.normal
    local level = UnitLevel and tonumber(UnitLevel("player")) or 1
    local who = Chronicle.Character() or (UnitName and UnitName("player"))
    local zone = GetRealZoneText and GetRealZoneText()
    Feed.Show({
        kind = "level",
        chip = IsPlainText(who) and { text = who } or nil,
        title = L.c_level:format(level),
        detail = IsPlainText(zone) and zone or nil,
        number = level,
        big = true,
        reaction = SampleReaction({ k = "level", who = who or true }),
    }, seconds)
    local mira, borin = Chronicle.SamplePeople()
    local boss, alsoBoss = Chronicle.Sample("boss"), Chronicle.Sample("boss")
    alsoBoss.who, alsoBoss.with = mira, { borin }
    for _, entry in ipairs({ boss, alsoBoss, Chronicle.Sample("death"), Chronicle.Sample("item") }) do
        Feed.Show(Story(entry, entry.k, true), seconds)
    end
    feed:Chime()
end

function feed:OnEnable()
    if not listening then
        listening = true
        ns:On("CHRONICLE_CHANGED", OnChronicleChanged)
        ns:On("CHRONICLE_REACTION", OnReaction)
    end
    local Feed = ns.UI and ns.UI.Feed
    if Feed then
        Feed.SetKeep(self:Get("keep") == true)
    end
    -- In the game's Edit Mode the feed shows where it appears and can be
    -- dragged, like the game's own elements.
    self:HookScript(EditModeManagerFrame, "OnShow", function()
        ns.UI.Feed.SetMoving(true)
    end)
    self:HookScript(EditModeManagerFrame, "OnHide", function()
        ns.UI.Feed.SetMoving(false)
    end)
end

function feed:OnOptionChanged(key, value)
    local Feed = ns.UI and ns.UI.Feed
    if key == "keep" and Feed then
        Feed.SetKeep(value == true)
    end
end

function feed:OnDisable()
    local Feed = ns.UI and ns.UI.Feed
    if Feed then
        Feed.SetMoving(false)
        Feed.SetKeep(false)
        Feed.Clear()
    end
end
