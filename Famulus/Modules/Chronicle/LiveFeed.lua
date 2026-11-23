-- Shows what the chronicle has just written down as a card on screen
-- (UI/Feed.lua): the player's own events and those of companions, each kind
-- of event with its own switch.
--
-- It listens to the chronicle, not to the game: no event, no timer of its
-- own. The cards can be moved in the game's Edit Mode or with /fam feed.

local _, ns = ...

-- The kinds of events with a switch, in the order of the window. An arrival
-- in a zone is off from the start: it happens often and is rarely news.
local KINDS = { "level", "death", "boss", "achievement", "ability", "item", "profession", "skill", "zone" }
local OFF_BY_DEFAULT = { zone = true }

local options = {
    { key = "duration", type = "select", default = "normal", values = { "short", "normal", "long" } },
    { key = "companions", type = "toggle", default = true },
}
for _, kind in ipairs(KINDS) do
    options[#options + 1] = { key = kind, type = "toggle", default = not OFF_BY_DEFAULT[kind] }
end

local feed = ns:NewFeature({
    id = "liveFeed",
    category = "chronicle",
    default = true,
    options = options,
})

feed.KINDS = KINDS
feed.SECONDS = { short = 4, normal = 7, long = 12 }

local FRESH = 120 -- seconds; older news (caught up on, passed on) is not announced
local listening = false

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
    if entry.who and not feed:Get("companions") then
        return
    end
    -- The player's own level-up is announced by the game itself.
    if kind == "level" and not entry.who then
        return
    end
    local UI = ns.UI
    if not (UI and UI.Feed and UI.ChronicleStory) then
        return
    end
    -- In developer mode the log says whether the card came up, so that "it
    -- did not appear" can be told from "it was overlooked".
    local ok, problem = pcall(function()
        UI.Feed.Show(UI.ChronicleStory(entry), feed.SECONDS[feed:Get("duration")] or feed.SECONDS.normal)
    end)
    ns:DevLog("FEED", ok and ("shown: " .. tostring(kind)) or ("failed: " .. tostring(kind) .. ": " .. tostring(problem)))
    if not ok then
        error(problem, 0)
    end
end

function feed:OnEnable()
    if not listening then
        listening = true
        ns:On("CHRONICLE_CHANGED", OnChronicleChanged)
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

function feed:OnDisable()
    local Feed = ns.UI and ns.UI.Feed
    if Feed then
        Feed.SetMoving(false)
        Feed.Clear()
    end
end
