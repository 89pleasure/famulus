-- Data of the chronicle: the sample entries' zones, names and people per
-- language (/fam chronicle demo, the settings' pictures). Read by
-- ChronicleService at run time.

local _, ns = ...
local ChronicleService = ns.ChronicleService

ChronicleService.DEMO_ZONES = {
    enUS = { "Badlands", "Uldaman", "Stranglethorn Vale", "Tanaris" },
    deDE = { "Ödland", "Uldaman", "Schlingendorntal", "Tanaris" },
    esES = { "Tierras Inhóspitas", "Uldaman", "Vega de Tuercespina", "Tanaris" },
    frFR = { "Terres ingrates", "Uldaman", "Vallée de Strangleronce", "Tanaris" },
    itIT = { "Maleterre", "Uldaman", "Valle di Rovotorto", "Tanaris" },
    plPL = { "Badlands", "Uldaman", "Stranglethorn Vale", "Tanaris" },
    ukUA = { "Badlands", "Uldaman", "Stranglethorn Vale", "Tanaris" },
}

ChronicleService.DEMO_NAMES = {
    enUS = { tailoring = "Tailoring", mining = "Mining", boss = "Archaedas", challenge = "Explorer of the Badlands", bag = "Sleeping Bag", mount = "Brown Horse", knight = "Knight" },
    deDE = { tailoring = "Schneiderei", mining = "Bergbau", boss = "Archaedas", challenge = "Erkunder des Ödlands", bag = "Schlafsack", mount = "Braunes Pferd", knight = "Ritter" },
    esES = { tailoring = "Sastrería", mining = "Minería", boss = "Archaedas", challenge = "Explorar las Tierras Inhóspitas", bag = "Saco de dormir", mount = "Caballo marrón", knight = "Caballero" },
    frFR = { tailoring = "Couture", mining = "Minage", boss = "Archaedas", challenge = "Explorer les Terres ingrates", bag = "Sac de couchage", mount = "Cheval brun", knight = "Chevalier" },
    itIT = { tailoring = "Sartoria", mining = "Estrazione", boss = "Archaedas", challenge = "Esplora Maleterre", bag = "Sacco a pelo", mount = "Cavallo marrone", knight = "Cavaliere" },
    plPL = { tailoring = "Tailoring", mining = "Mining", boss = "Archaedas", challenge = "Explorer of the Badlands", bag = "Sleeping Bag", mount = "Brown Horse", knight = "Knight" },
    ukUA = { tailoring = "Tailoring", mining = "Mining", boss = "Archaedas", challenge = "Explorer of the Badlands", bag = "Sleeping Bag", mount = "Brown Horse", knight = "Knight" },
}

ChronicleService.DEMO_PEOPLE = {
    enUS = { "Mira Stormfeather", "Borin Ironbeard", "Lysa Morningdew" },
    deDE = { "Mira Sturmfeder", "Borin Eisenbart", "Lysa Morgentau" },
    esES = { "Mira Plumatormenta", "Borin Barbahierro", "Lysa Rocíoalba" },
    frFR = { "Mira Plume-d'orage", "Borin Barbe-de-fer", "Lysa Rosée-du-matin" },
    itIT = { "Mira Piumatempesta", "Borin Barbaferrea", "Lysa Rugiadalba" },
    plPL = { "Mira Burzowe Pióro", "Borin Żelazna Broda", "Lysa Poranna Rosa" },
    ukUA = { "Міра Бурепер", "Борін Залізнобород", "Ліса Ранкороса" },
}
