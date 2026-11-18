-- Auto-loot: a second switch for the game's own option. The client's
-- auto-loot is already instant, so the switch only mirrors the game's
-- setting (see Core/GameOptions.lua). No code of its own.

local _, ns = ...

ns:NewFeature({
    id = "autoLoot",
    category = "loot",
    default = false,
    mirror = { cvar = "autoLootDefault" },
})
