-- Data of the chronicle: the special items. A plain table, read by
-- ChronicleService at run time; a new item is one row here.

local _, ns = ...
local ChronicleService = ns.ChronicleService

-- Items whose first arrival in the character's bags is an event, recognised
-- by their item ID. To add one: a line here; the sentence names the item as
-- the game does. Modules/Chronicle/OwnJourney.lua does the looking.
--   item     the game's item ID
--   class    optional: only this class gets it; others never ask for it
--   picture  optional name in UI.media for the book (default: a chest)
--   big      optional: a milestone of the book
ChronicleService.items = {
    { item = 211527 }, -- the sleeping bag
    -- The shaman's totems, each from a class quest (level 4, 10, 20, 30)
    { item = 5175, class = "SHAMAN" }, -- Earth Totem
    { item = 5176, class = "SHAMAN" }, -- Fire Totem
    { item = 5177, class = "SHAMAN" }, -- Water Totem
    { item = 5178, class = "SHAMAN" }, -- Air Totem
}
