-- Data of the chronicle: the last boss of every dungeon and raid. A plain
-- table, read by ChronicleService at run time; a new instance is one row here.

local _, ns = ...
local ChronicleService = ns.ChronicleService

-- The last boss of each instance, by encounter ID (what BOSS_KILL names):
-- defeating it clears the instance. One row per wing where an instance has
-- several. IDs from the client's DungeonEncounter table (Forever build
-- 1.60.1.71139 on wago.tools, the same as Classic Era but for Sunken Temple);
-- many dungeons have newer IDs than warcraft.wiki.gg lists. Not checked in game.
ChronicleService.finalBosses = {
    -- Dungeons
    [2735] = true, -- Ragefire Chasm: Bazzalan (no clear last boss)
    [592] = true, -- Wailing Caverns: Mutanus the Devourer
    [2747] = true, -- The Deadmines: Edwin VanCleef
    [2755] = true, -- Shadowfang Keep: Archmage Arugal
    [2910] = true, -- Blackfathom Deeps: Aku'mai
    [2760] = true, -- The Stockade: Bazil Thredd (no clear last boss)
    [2772] = true, -- Gnomeregan: Mekgineer Thermaplugg
    [2778] = true, -- Razorfen Kraul: Charlga Razorflank
    [2779] = true, -- Scarlet Monastery, Graveyard: Bloodmage Thalnos
    [447] = true, -- Scarlet Monastery, Library: Arcanist Doan
    [448] = true, -- Scarlet Monastery, Armory: Herod
    [450] = true, -- Scarlet Monastery, Cathedral: High Inquisitor Whitemane
    [2785] = true, -- Razorfen Downs: Amnennar the Coldbringer
    [554] = true, -- Uldaman: Archaedas
    [600] = true, -- Zul'Farrak: Chief Ukorz Sandscalp
    [429] = true, -- Maraudon: Princess Theradras
    [3584] = true, -- Sunken Temple: Shade of Eranikus (Forever's own row)
    [493] = true, -- Sunken Temple: Shade of Eranikus (Classic Era's row)
    [2790] = true, -- Blackrock Depths: Emperor Dagran Thaurissan
    [275] = true, -- Lower Blackrock Spire: Overlord Wyrmthalak
    [3069] = true, -- Upper Blackrock Spire: General Drakkisath
    [346] = true, -- Dire Maul East: Alzzin the Wildshaper
    [361] = true, -- Dire Maul West: Prince Tortheldrin
    [368] = true, -- Dire Maul North: King Gordok
    [2801] = true, -- Scholomance: Darkmaster Gandling
    [478] = true, -- Stratholme, living side: Balnazzar
    [484] = true, -- Stratholme, undead side: Baron Rivendare
    -- Forever's own dungeons: the last boss is the one the client's table
    -- orders last (OrderIndex), as the guides confirm
    [3303] = true, -- City of Dalaran: Shade of the Archmage
    [3479] = true, -- The Drowned City: Min'loth the Serpent
    [3336] = true, -- Blackmaw Hold: Unbound Spirit
    [3409] = true, -- Alcaz Prison: Blazeroar
    [3482] = true, -- Excavation Site: Wetlands: Relic Guardian
    [3354] = true, -- Ruins of Lordaeron: Rath'mael
    [3502] = true, -- The Shaper's Terrace: Nanaya
    [3451] = true, -- Krol'dok Stronghold: Overseer Mugg
    [3496] = true, -- The Hall of Thanes: Durgen Dirgehammer
    -- Raids
    [672] = true, -- Molten Core: Ragnaros
    [1084] = true, -- Onyxia's Lair: Onyxia
    [617] = true, -- Blackwing Lair: Nefarian
    [793] = true, -- Zul'Gurub: Hakkar
    [723] = true, -- Ruins of Ahn'Qiraj: Ossirian the Unscarred
    [717] = true, -- Temple of Ahn'Qiraj: C'Thun
    [1114] = true, -- Naxxramas: Kel'Thuzad
}
