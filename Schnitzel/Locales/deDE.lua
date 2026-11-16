-- Deutsch. Fehlende Schlüssel fallen automatisch auf enUS zurück.

local _, ns = ...
local L = ns:NewLocale("deDE")

-- Kategorien
L.cat_general = "Einstellungen"
L.cat_general_desc = "Einstellungen für das Addon selbst, nicht für das Spiel."
L.cat_vendor = "Händler"
L.cat_vendor_desc = "Erledigungen, die bei jedem Händlerbesuch anfallen."
L.cat_quests = "Quests"
L.cat_quests_desc = "Weniger Klicks beim Annehmen und Abgeben von Quests."
L.cat_loot = "Beute & Gegenstände"
L.cat_loot_desc = "Plündern und Gegenstände verwalten ohne zusätzliche Rückfragen."
L.cat_social = "Soziales"
L.cat_social_desc = "Einladungen und Anfragen anderer Spieler."
L.cat_tooltip = "Tooltips"
L.cat_tooltip_desc = "Was Tooltips anzeigen und wo sie erscheinen."
L.cat_interface = "Interface"
L.cat_interface_desc = "Kleine Komfortfunktionen für Karte, Chat und Kamera."
L.cat_about = "Über"
L.cat_about_desc = "Version, Befehle und was gerade aktiv ist."

-- Allgemeine Optionen
L.g_chatOutput = "Rückmeldung im Chat"
L.g_chatOutput_desc = "Gibt eine kurze Zeile aus, wenn Schnitzel etwas für dich erledigt hat, etwa reparieren oder Plunder verkaufen."
L.g_pauseModifier = "Pausentaste"
L.g_pauseModifier_desc = "Halte diese Taste gedrückt, um alle Automatiken einmal zu überspringen, zum Beispiel um eine Quest vor dem Annehmen zu lesen."
L.g_language = "Sprache"
L.g_language_desc = "Sprache der Texte von Schnitzel. Änderungen gelten sofort."
L.g_minimapButton = "Minikartensymbol"
L.g_minimapButton_desc = "Zeigt ein Symbol an der Minikarte, das dieses Fenster öffnet. /sz funktioniert immer."
L.g_windowScale = "Fenstergröße"
L.g_windowScale_desc = "Größe dieses Fensters, unabhängig von der Interface-Skalierung des Spiels."
L.g_charProfile = "Einstellungen nur für diesen Charakter"
L.g_charProfile_desc = "Führt eigene Einstellungen für diesen Charakter. Sie beginnen als Kopie deiner accountweiten Einstellungen."

L.mod_SHIFT = "Umschalt"
L.mod_CTRL = "Strg"
L.mod_ALT = "Alt"
L.mod_NONE = "Keine"
L.lang_auto = "Spielclient"

-- Händler
L.f_autoRepair = "Automatisch reparieren"
L.f_autoRepair_desc = "Repariert deine gesamte Ausrüstung, sobald du einen Händler mit Reparaturfunktion öffnest."
L.o_autoRepair_guildFunds = "Zuerst Gildengold verwenden"
L.o_autoRepair_guildFunds_desc = "Bezahlt aus der Gildenbank, wenn dein Rang das erlaubt, sonst mit eigenem Gold."
L.f_sellJunk = "Plunder verkaufen"
L.f_sellJunk_desc = "Verkauft alle grauen Gegenstände, sobald du einen Händler öffnest."

-- Quests
L.f_autoAccept = "Quests automatisch annehmen"
L.f_autoAccept_desc = "Nimmt Quests an, sobald ein NSC sie anbietet."
L.o_autoAccept_skipTrivial = "Niedrigstufige Quests ignorieren"
L.o_autoAccept_skipTrivial_desc = "Graue Quests, die keine Erfahrung geben, werden nicht angenommen."
L.f_autoTurnIn = "Quests automatisch abgeben"
L.f_autoTurnIn_desc = "Gibt abgeschlossene Quests ab. Hält an, sobald du eine Belohnung wählen musst, und schließt nie wiederholbare Quests oder Quests ab, die Gold kosten."

-- Beute & Gegenstände
L.f_fastLoot = "Schnelleres Plündern"
L.f_fastLoot_desc = "Nimmt bei aktivem automatischem Plündern alles auf einmal auf statt Stück für Stück."
L.f_confirmBoP = "Beim Aufheben gebundene Beute bestätigen"
L.f_confirmBoP_desc = "Überspringt die Rückfrage „Dieser Gegenstand wird an dich gebunden“, solange du in keiner Gruppe bist."
L.f_easyDelete = "Einfacheres Zerstören"
L.f_easyDelete_desc = "Trägt das Bestätigungswort ein, wenn du einen wertvollen Gegenstand zerstörst. Den Knopf musst du weiterhin selbst klicken."

-- Soziales
L.f_acceptInvites = "Einladungen von Freunden annehmen"
L.f_acceptInvites_desc = "Tritt Gruppen automatisch bei, wenn die Einladung von einem Freund oder Gildenmitglied kommt."
L.f_declineDuels = "Duelle ablehnen"
L.f_declineDuels_desc = "Lehnt jede Duellanfrage ab."

-- Tooltips
L.f_tooltipIDs = "Gegenstands- und Zauber-IDs anzeigen"
L.f_tooltipIDs_desc = "Ergänzt Gegenstands- und Zaubertooltips um die numerische ID."
L.f_tooltipCursor = "Tooltip am Mauszeiger"
L.f_tooltipCursor_desc = "Zeigt Tooltips neben dem Mauszeiger statt in der rechten unteren Ecke."

-- Interface
L.f_mapCoords = "Koordinaten auf der Weltkarte"
L.f_mapCoords_desc = "Zeigt deine Position und die Position des Mauszeigers auf der Weltkarte."
L.f_chatArrowKeys = "Pfeiltasten im Chat"
L.f_chatArrowKeys_desc = "Textcursor bewegen und frühere Nachrichten durchblättern mit den Pfeiltasten, ohne Alt zu halten."
L.f_cameraZoom = "Maximale Kameradistanz"
L.f_cameraZoom_desc = "Erlaubt, die Kamera so weit herauszuzoomen, wie das Spiel es zulässt."
L.f_hideErrors = "Fehlermeldungen im Kampf ausblenden"
L.f_hideErrors_desc = "Blendet rote Meldungen wie „Nicht genug Wut“ oder „Fähigkeit noch nicht bereit“ aus. Andere Fehler bleiben sichtbar."
L.f_levelScreenshot = "Screenshot beim Stufenaufstieg"
L.f_levelScreenshot_desc = "Macht bei jedem Stufenaufstieg einen Screenshot."

-- Chatnachrichten
L.msg_welcome = "geladen. Mit /sz öffnest du die Einstellungen."
L.msg_repair = "Für %s repariert."
L.msg_repair_guild = "Für %s repariert (Gildengold)."
L.msg_repair_nomoney = "Nicht genug Gold zum Reparieren (%s nötig)."
L.msg_junk_sold = "%d Plundergegenstände für %s verkauft."
L.msg_junk_sold_one = "1 Plundergegenstand für %s verkauft."
L.msg_invite_accepted = "Einladung von %s angenommen."
L.msg_duel_declined = "Duell von %s abgelehnt."
L.msg_feature_error = "„%s“ wurde wegen eines Fehlers abgeschaltet."
L.msg_status = "%d von %d Funktionen aktiv, %d Spielereignisse registriert."
L.msg_selftest = "Selbsttest: %d ok, %d Warnungen, %d fehlgeschlagen. /reload schreibt den Bericht auf die Platte."
L.msg_dev_on = "Entwicklermodus an: Der Selbsttest läuft nach jedem Login, blockierte Aktionen werden protokolliert."
L.msg_dev_off = "Entwicklermodus aus."

-- Tooltip- und Kartenbeschriftungen
L.tt_item_id = "Gegenstands-ID"
L.tt_spell_id = "Zauber-ID"
L.map_player = "Spieler"
L.map_cursor = "Mauszeiger"

-- Fenster
L.ui_tagline = "Quality of Life"
L.ui_search = "Einstellungen durchsuchen"
L.ui_search_title = "Suche"
L.ui_search_results = "%d passende Einstellungen"
L.ui_search_none = "Keine Einstellung passt zu „%s“."
L.ui_reset_page = "Seite zurücksetzen"
L.ui_reset_confirm = "Wirklich zurücksetzen?"
L.ui_close = "Schließen"
L.ui_open_settings = "Schnitzel-Einstellungen öffnen"
L.ui_unavailable = "In dieser Spielversion nicht verfügbar."
L.ui_failed = "Wegen eines Fehlers abgeschaltet. Mit /reload erneut versuchen."
L.ui_active_count = "%d von %d aktiv"
L.ui_category_on = "AN"
L.ui_category_off = "AUS"
L.ui_minimap_hint_click = "Klicken öffnet die Einstellungen"
L.ui_minimap_hint_drag = "Ziehen verschiebt das Symbol"

-- Über-Seite
L.about_version = "Version"
L.about_status = "Aktiv"
L.about_status_value = "%d von %d Funktionen, %d Spielereignisse"
L.about_commands = "Befehle"
L.about_commands_value = "/sz  ·  /schnitzel  ·  /sz status  ·  /sz test"
L.about_idea = "Idee"
L.about_idea_value = "Alles ist optional. Eine abgeschaltete Funktion lauscht gar nicht erst auf das Spiel und kostet daher nichts."
