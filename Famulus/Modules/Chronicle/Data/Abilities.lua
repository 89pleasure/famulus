-- Data of the chronicle: the abilities whose learning is an event. A plain
-- table, read by ChronicleService at run time; a new ability is one row here.

local _, ns = ...
local ChronicleService = ns.ChronicleService

-- Abilities whose learning is an event, recognised by their spell. To add
-- one: a line here; the sentence names the spell as the game does ("Learned
-- Bear Form"). Modules/Chronicle/OwnJourney.lua does the looking.
--   id         name of the ability in entries and FamulusCharDB.abilities
--   spell      the spell the character knows once it is learned; the book
--              shows its icon and its tooltip
--   also       optional: other spells that count as the same ability (the
--              version another race learns)
--   class      optional: only this class learns it ("DRUID"); others never
--              ask for it
--   skill      optional { line = <skill line>, rank = <points> }: counts as
--              learned too, where the client does not list the spell
--   sentences  optional: has its own two sentences per language
--              (c_ability_<id>, c_their_ability_<id>) instead
--   picture    optional name in UI.media for the book
--   big        optional: a milestone of the book
-- The class abilities are those a class quest teaches, the levels in the
-- comments. IDs from Wowhead for Classic and Forever; "/fam test" says
-- whether the client knows each spell.
ChronicleService.abilities = {
    { id = "riding", spell = 33388, skill = { line = 762, rank = 75 }, picture = "horseshoe", big = true, sentences = true },
    { id = "ridingFast", spell = 33391, skill = { line = 762, rank = 150 }, picture = "horseshoe", big = true, sentences = true },
    -- Warrior
    { id = "defensiveStance", class = "WARRIOR", spell = 71 }, -- 10
    { id = "berserkerStance", class = "WARRIOR", spell = 2458 }, -- 30
    -- Paladin; the Forsaken learn their own steeds
    { id = "redemption", class = "PALADIN", spell = 7328 }, -- 12
    { id = "senseUndead", class = "PALADIN", spell = 5502 }, -- 20
    { id = "warhorse", class = "PALADIN", spell = 13819, also = { 1279399 }, picture = "horseshoe", big = true }, -- 40
    { id = "charger", class = "PALADIN", spell = 23214, also = { 1296534 }, picture = "horseshoe", big = true }, -- 60
    -- Hunter
    { id = "tameBeast", class = "HUNTER", spell = 1515 }, -- 10
    -- Rogue
    { id = "poisons", class = "ROGUE", spell = 2842, skill = { line = 40, rank = 1 } }, -- 20
    -- Priest: what each race learns by its own quest
    { id = "desperatePrayer", class = "PRIEST", spell = 13908 }, -- 10, dwarf
    { id = "starshards", class = "PRIEST", spell = 10797 }, -- 10, night elf
    { id = "hexOfWeakness", class = "PRIEST", spell = 9035 }, -- 10, troll
    { id = "touchOfWeakness", class = "PRIEST", spell = 2652 }, -- 10, undead
    { id = "feedback", class = "PRIEST", spell = 13896 }, -- 20, human
    { id = "elunesGrace", class = "PRIEST", spell = 2651 }, -- 20, night elf
    { id = "shadowguard", class = "PRIEST", spell = 18137 }, -- 20, troll
    { id = "chastise", class = "PRIEST", spell = 1277331 }, -- 20, dwarf
    { id = "darkSacrifice", class = "PRIEST", spell = 1277324 }, -- 20, undead
    -- Mage
    { id = "polymorphPig", class = "MAGE", spell = 28272 }, -- 60
    -- Warlock
    { id = "summonImp", class = "WARLOCK", spell = 688 }, -- 1
    { id = "summonVoidwalker", class = "WARLOCK", spell = 697 }, -- 10
    { id = "summonSuccubus", class = "WARLOCK", spell = 712 }, -- 20
    { id = "summonIncubus", class = "WARLOCK", spell = 713 }, -- 20
    { id = "summonFelhunter", class = "WARLOCK", spell = 691 }, -- 30
    { id = "felsteed", class = "WARLOCK", spell = 5784, picture = "horseshoe", big = true }, -- 40
    { id = "inferno", class = "WARLOCK", spell = 1122 }, -- 50
    { id = "ritualOfDoom", class = "WARLOCK", spell = 18540 }, -- 60
    { id = "dreadsteed", class = "WARLOCK", spell = 23161, picture = "horseshoe", big = true }, -- 60
    -- Druid; moonkin is a talent, not a quest
    { id = "bearForm", class = "DRUID", spell = 5487 }, -- 10
    { id = "curePoison", class = "DRUID", spell = 8946 }, -- 14
    { id = "aquaticForm", class = "DRUID", spell = 1066 }, -- 16
    { id = "catForm", class = "DRUID", spell = 768 }, -- 20
    { id = "moonkinForm", class = "DRUID", spell = 24858 }, -- 40
}
