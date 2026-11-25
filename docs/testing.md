# Prüfen und Testen

Teil des Projektwissens; Vorgaben, Regeln und die Übersicht aller Dateien stehen in
[AGENTS.md](../AGENTS.md). Verweise der Form „siehe X“ meinen eine Überschrift oder einen fett
gesetzten Eintrag; in welcher Datei er steht, sagt die Übersicht dort.

## Tests gegen den Mock

- `luajit tests/run.lua` lädt das Addon gegen eine nachgestellte Client-API (`tests/wowmock.lua`)
  und prüft jedes Feature, das Fenster und die Übersetzungen. Muss vor jedem Commit grün sein.
- Der Mock beweist die eigene Logik, nicht das Verhalten des Clients. Dafür gibt es den Selbsttest
  im Spiel, siehe „Test im Spiel“.
- Secret Values im Mock: `mock.SECRET` verweigert Index, Rechnen, Vergleich und Verketten.
  Eine Wahr/Falsch-Prüfung (`not x`) lässt sich in Lua nicht abfangen; deshalb prüft der Test im
  Quelltext, dass `ns.IsSecret(x)` vor jedem Test von `x` steht.
- Größen im Mock: `SetWidth`/`SetHeight`/`SetSize` legen ihren Wert in `mockWidth`/`mockHeight`
  ab, nicht in `width`/`height`. Im Client setzt `SetWidth` kein Feld am Frame; wer eine Breite als
  Feld liest, muss sie selbst setzen (`book.width`). Vorher hat der Mock einen solchen Fehler
  verdeckt (siehe „Fehler 2026-11-24“). Tests lesen die Größe über `GetWidth()`.

## Stand der Prüfung im Spiel

- **Fehler 2026-11-24 (im Spiel gefunden und behoben, Behebung im Spiel bestätigt):** Das
  Fenster öffnete sich ohne Inhalt und fast ohne Text; nach einem Klick auf „Weggefährten“ kam
  alles zurück, ein Klick auf „Chronik“ ließ die Weggefährten markiert und schnitt sie bei 600 px
  ab. Ursache: Der Kapitelkopf mit Route (`LayRoute` in `UI/Book.lua`) rechnete mit `head.width`,
  das nur der Mock kannte. Der Fehler brach `Render` ab, nachdem der Inhaltsbereich schon auf
  Buchbreite gesetzt war und bevor Seitenleiste, Kopf und Reiter beschriftet wurden. Gefunden
  über die Fehleranzeige des Spiels (siehe „Test im Spiel“). Nach der Behebung hat der
  Auftraggeber das Fenster im Spiel geöffnet: „Funktioniert“.
- **Erster Selbsttest im Spiel am 2026-11-16** (Client 1.60.1, Build 70938, deDE): 54 Prüfungen ok,
  1 Warnung, 0 fehlgeschlagen; keine blockierten Aktionen, keine Lua-Warnungen. Bestätigt:
  - Das Addon lädt, das Fenster öffnet sich, Einstellungen und Fensterposition werden gespeichert.
  - Alle 16 Features finden ihre benötigte API.
  - Die vier TGA-Texturen laden (`SetTexture` liefert wahr) und sehen im Fenster richtig aus
    (Screenshot geprüft).
  - `Texture:SetGradient("VERTICAL", CreateColor(...), CreateColor(...))` funktioniert; der
    Fensterrahmen zeigt den Verlauf.
  - Speicher: 360 KB bei 6 aktiven Features und 5 Spielereignissen.
- **Spielrunde 2026-11-16:** prüfte vor allem die inzwischen entfernten QoL-Features. Was davon
  allgemein gilt: Blizzards Panels aus Addon-Code zu schließen birgt Taint-Risiko; der eingebaute
  Verlauf der Chat-Eingabe (Hoch/Runter) reagiert in Forever nicht; das EventRegistry-Signal
  `ChatFrame.OnEditBoxFocusLost` feuert, bevor Blizzard eine leere Eingabe schließt und den
  Chat-Typ zurücksetzt.
- **Aliase (2026-11-16, nur gegen den Mock geprüft, noch nicht im Spiel):** Kategorie `aliases` mit
  drei Features und der Alias-Liste, siehe „Aliase“ unten.
- **Aliase im Spiel (2026-11-18):** Der Alias erscheint im normalen Chat und in Guildy (bestätigt).
- **Neues Fenster (2026-11-18, nur gegen den Mock geprüft, noch nicht im Spiel):** siehe „Das
  Fenster“ unten. Die Inter-Schriften laden (siehe „Schrift“). Offen im Spiel: ob runde Ecken, Schatten und Haarlinien sauber aussehen, das Umschalten
  der Farbwelten, die gleitende Reiter-Markierung, Verläufe und Glüheffekte.
- **Weggefährten (2026-11-23, nur gegen den Mock geprüft, noch nicht im Spiel):** eigener Bereich,
  siehe „Weggefährten“ unten.
- **Weggefährten nur mit Freunden und Gilde, Aufräumen (2026-11-24, nur gegen den Mock geprüft,
  noch nicht im Spiel):** siehe „Nur Freunde und Gilde, Aufräumen“ unter „Weggefährten“.
- **Neuer Rahmen und Weggefährten-Übersicht (2026-11-24, nur gegen den Mock geprüft, noch nicht im
  Spiel):** siehe „Das Fenster“ und „Weggefährten“. Offen im Spiel: Ring ums Wappen (`/fam test`,
  Gruppe `media`, Prüfung `ring`), Klassensymbole (Prüfung `class icons`), die Seite ohne
  Seitenleiste, der durchgehende Grund von Kopf und Seitenleiste. Auf einem Screenshot vom
  2026-11-24 (Beispieldaten) zu sehen: Ring mit Fortschritt und Klassensymbol (Krieger) am Wappen
  in der Geschichte einer Person.
- **Klare Kante zwischen Chronik und Weggefährten (2026-11-24):** siehe „Chronik und
  Weggefährten“. Im Spiel mit den Beispieldaten gesehen (Screenshots vom Auftraggeber, 2026-11-24):
  Reiter und Randspalte „Freunde“, die Bilanz-Karten, die Filterzeile mit „Alle zeigen“ und „Eure
  Geschichte“ in einer Zeile, auf der Karte der Person „Alias festlegen“ und „In der Chronik“
  nebeneinander, Bosse mit Namen als eigene Karten, keine Einträge aus der Chronik in „Eure
  Geschichte“. Offen im Spiel: ob `BOSS_KILL` in einer echten Gruppe den Bossnamen so liefert, wie
  die Karten ihn zeigen.
- **Klassensymbol und Charaktername in der Chronik (2026-11-24, nur gegen den Mock geprüft, noch
  nicht im Spiel):** siehe „Klasse und Name“ unter „Chronik“. Offen im Spiel: ob die Klassensymbole
  im Streifen (18 px) und in der Randspalte (30 px) sauber aussehen, ob `className` der
  Freundesliste in Forever zu `LOCALIZED_CLASS_NAMES_MALE`/`_FEMALE` passt.
- **Runden der Weggefährten (2026-11-24, nur gegen den Mock geprüft, noch nicht im Spiel):**
  siehe „Runden“ unter „Weggefährten“. Offen im Spiel: ob eine Runde über `/reload` und
  Verbindungsabbrüche hinweg zusammenbleibt, ob `ZONE_CHANGED_NEW_AREA` die Gebiete einer Runde
  vollständig liefert, wie Wappen und Namensplaketten im Buch aussehen.
- **Noch nicht im Spiel geprüft:** die übrigen Aliase (Kontextmenü, Tooltip, Eingabezeile im Fenster),
  im Fenster das Dropdown, die Suche und das Scrollen, Verhalten im Kampf (Secret Values, Taint).
- **Selbsttest 2026-11-19** (Client 1.60.1, Build 70959, deDE): 80 ok, 3 Warnungen, 0 fehlgeschlagen;
  629 KB bei 8 aktiven Features und 4 Spielereignissen.
  - Die drei Inter-Schriften laden nicht (`SetFont` liefert falsch); das Fenster nimmt die
    Spielschrift. Ursache (per `/run` geprüft): Der Client lädt eine Schriftdatei beim ersten
    `SetFont` im Hintergrund; dieser erste Aufruf liefert falsch, ein späterer wahr. Symlink und
    das Kürzen der Dateien sind es nicht (Polestars ungekürztes Inter verhielt sich gleich).
    Das Anfragen beim Login half nicht (Selbsttest 2026-11-24 weiter falsch); die Erklärung
    steht seit 2026-11-25 unter „Schrift“: Die Warnung war ein Fehlalarm, Inter wird gezeichnet.
  - Der Knopf unter Optionen › AddOns › Famulus schloss Blizzards Einstellungsfenster mit
    `SettingsPanel:Close()` aus Addon-Code. Das Spiel meldete danach „Famulus wurde blockiert …“.
    Ursache: Ohne Argument kehrt `Close` über `TransitionBackOpeningPanel` ins Spielmenü zurück und
    ruft dabei das geschützte `ToggleGameMenu`. Jetzt `SettingsPanel:Close(true)` wie bei FlareUI
    (Polestar: `HideUIPanel`); im Spiel bestätigt (keine Meldung, Famulus vorne). Offen lassen geht nicht: Famulus
    liegt dann hinter Blizzards Fenster (beide `HIGH`).
  - `devLog` hat die Blockaden doch festgehalten (beim ersten Lesen war es noch leer, vermutlich
    vor dem Speichern gelesen): um 12:13 und 12:15 je `ADDON_ACTION_FORBIDDEN` für
    `SpellStopCasting()`, `SpellStopTargeting()` und `UNKNOWN()`, zur Zeit der Tests mit dem alten
    `Close()`. Seit `Close(true)` kein Eintrag mehr (Bericht 16:39).

## Test im Spiel

WoW Forever ist auf dem Entwicklungsrechner installiert: `/Applications/World of Warcraft/_forever_`.
`Interface/AddOns/Famulus` ist dort ein Symlink auf den Ordner `Famulus/` dieses Repos, jede
Änderung ist also nach `/reload` im Spiel. Auf dem Windows-Rechner (seit 2026-11-18) liegt das Spiel
unter `D:\Games\World of Warcraft\_forever_`, das Repo unter `E:\Develop\wow\famulus`;
`Interface\AddOns\Famulus` ist dort eine Verzeichnisverknüpfung (Junction) auf `Famulus\`.

- `/fam test` prüft gegen den echten Client: benötigte API je Feature, die oben genannten unsicheren
  Stellen (Texturen, Kamerazoom, Popup-Namen, Karte, Fehlertext-Globals) und die Annahmen aus
  „WoW Forever: was man wissen muss“. Der Bericht landet in `FamulusDB.selfTest`.
- `/fam dev` schaltet den Entwicklermodus um: Der Selbsttest läuft dann drei Sekunden nach jedem
  Login, und blockierte Aktionen (`ADDON_ACTION_BLOCKED`/`_FORBIDDEN`) sowie `LUA_WARNING` des Addons
  werden in `FamulusDB.devLog` gesammelt. Standard ist aus; dann kostet das nichts.
- Das Spiel setzt beim Start alle Dateien im Addon-Ordner auf Modus 777, durch den Symlink also
  auch im Repo. Deshalb ist hier lokal `git config core.fileMode false` gesetzt; nach einem neuen
  Clone wieder setzen, sonst erscheinen alle Dateien als geändert.
- Das Spiel schreibt die Daten erst bei `/reload` oder beim Ausloggen auf die Platte. Danach liest
  `luajit tools/read_selftest.lua` den Bericht (mit `--all` auch die bestandenen Prüfungen).
- Ablauf einer Runde: Der Auftraggeber startet das Spiel, loggt ein und macht `/reload`; der
  Assistent liest den Bericht. Der Assistent kann das Spiel nicht selbst bedienen, und Eingaben ins
  Spiel zu automatisieren ist tabu (Nutzungsbedingungen).
- Lua-Fehler schreibt Blizzards Fehlerbehandlung über `C_Log.LogErrorMessage` in die Client-Logs
  unter `_forever_/Logs/`; in welche Datei, ist noch unbestätigt. `AddLuaErrorHandler` ist nur für
  sicheren Code (`assert(issecure())`), `seterrorhandler` ersetzen wir nicht.
- **Lua-Fehler sieht man im Spiel nur mit `/console scriptErrors 1`** (danach `/reload`). Auf dem
  Windows-Rechner war die Anzeige aus (kein `scriptErrors` in `WTF/Config.wtf`), und der Fehler vom
  2026-11-24 stand in keiner Datei unter `Logs/`. Sieht das Fenster halb aufgebaut aus, zuerst
  danach fragen; Meldung mit Stack und Zeile kommt dann als Fenster im Spiel.
- **BugGrabber und BugSack** sind auf dem Windows-Rechner installiert (Stand 2026-11-24, dazu
  `scriptErrors 1` in `WTF/Account/<Konto>/config-cache.wtf`). Sie fangen Lua-Fehler ab, bevor
  das Spiel sie als Fenster zeigt; im Spiel meldet sich dann nur BugSack. Gespeichert sind die
  Fehler nach `/reload` in `SavedVariables/!BugGrabber.lua` (`BugGrabberDB.errors`, mit Stack).
  Dort zuerst nachsehen, bevor man einen Fehler ausschließt.
- Screenshots des Spiels liegen in `_forever_/Screenshots/` und sind die Grundlage für
  Layout-Arbeit.
- Was der Selbsttest nicht abdeckt: ob die Chronik die richtigen Ereignisse festhält und ob das
  Teilen zwischen Spielern ankommt. Das zeigt nur das Spielen selbst (für das Teilen mit zwei
  Accounts).
