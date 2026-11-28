-- Data of the fellow travellers: the samples' zones, the bosses of two of
-- them and the people per language (/fam fellows demo, the settings'
-- pictures). Read by FellowService at run time. Mira, Borin and Lysa are the
-- companions of the chronicle's samples (Modules/Chronicle/Data/Samples.lua).

local _, ns = ...
local FellowService = ns.FellowService

FellowService.DEMO_ZONES = {
    enUS = { "Badlands", "Uldaman", "Stranglethorn Vale", "Tanaris", "Westfall", "The Deadmines" },
    deDE = { "Ödland", "Uldaman", "Schlingendorntal", "Tanaris", "Westfall", "Die Todesminen" },
    esES = { "Tierras Inhóspitas", "Uldaman", "Vega de Tuercespina", "Tanaris", "Páramos de Poniente", "Minas de la Muerte" },
    frFR = { "Terres ingrates", "Uldaman", "Vallée de Strangleronce", "Tanaris", "Marche de l'Ouest", "Les Mortemines" },
    itIT = { "Maleterre", "Uldaman", "Valle di Rovotorto", "Tanaris", "Marche Occidentali", "Miniere della Morte" },
    plPL = { "Badlands", "Uldaman", "Stranglethorn Vale", "Tanaris", "Westfall", "The Deadmines" },
    ukUA = { "Badlands", "Uldaman", "Stranglethorn Vale", "Tanaris", "Westfall", "The Deadmines" },
}
-- Bosses of the two dungeons above (zones 2 and 6); bosses elsewhere stay unnamed, as in a raid.
FellowService.DEMO_BOSSES = {
    enUS = { [2] = { "Revelosh", "Ironaya", "Archaedas" }, [6] = { "Rhahk'Zor", "Edwin VanCleef" } },
    deDE = { [2] = { "Revelosh", "Ironaya", "Archaedas" }, [6] = { "Rhahk'Zor", "Edwin van Cleef" } },
    esES = { [2] = { "Revelosh", "Ironaya", "Archaedas" }, [6] = { "Rhahk'Zor", "Edwin VanCleef" } },
    frFR = { [2] = { "Revelosh", "Ironaya", "Archaedas" }, [6] = { "Rhahk'Zor", "Edwin VanCleef" } },
    itIT = { [2] = { "Revelosh", "Ironaya", "Archaedas" }, [6] = { "Rhahk'Zor", "Edwin VanCleef" } },
    plPL = { [2] = { "Revelosh", "Ironaya", "Archaedas" }, [6] = { "Rhahk'Zor", "Edwin VanCleef" } },
    ukUA = { [2] = { "Revelosh", "Ironaya", "Archaedas" }, [6] = { "Rhahk'Zor", "Edwin VanCleef" } },
}
FellowService.DEMO_PEOPLE = {
    enUS = { "Mira Stormfeather", "Borin Ironbeard", "Lysa Morningdew", "Kael Thornwood", "Tomas Greywind", "Ena Silverbrook" },
    deDE = { "Mira Sturmfeder", "Borin Eisenbart", "Lysa Morgentau", "Kael Dornhain", "Tomas Grauwind", "Ena Silberquell" },
    esES = { "Mira Plumatormenta", "Borin Barbahierro", "Lysa Rocíoalba", "Kael Bosquespina", "Tomas Vientogrís", "Ena Arroyoplata" },
    frFR = { "Mira Plume-d'orage", "Borin Barbe-de-fer", "Lysa Rosée-du-matin", "Kael Bois-d'épine", "Tomas Vent-gris", "Ena Source-d'argent" },
    itIT = { "Mira Piumatempesta", "Borin Barbaferrea", "Lysa Rugiadalba", "Kael Boscospino", "Tomas Ventogrigio", "Ena Rivargento" },
    plPL = { "Mira Burzowe Pióro", "Borin Żelazna Broda", "Lysa Poranna Rosa", "Kael Ciernisty Bór", "Tomas Szary Wicher", "Ena Srebrny Potok" },
    ukUA = { "Міра Бурепер", "Борін Залізнобород", "Ліса Ранкороса", "Каель Терногай", "Томас Сивовій", "Ена Срібнострум" },
}
