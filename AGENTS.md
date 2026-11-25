# Famulus – Projektwissen für KI-Assistenten

Famulus ist ein Addon für **World of Warcraft: Forever**, das das gemeinsame Spielen unter Freunden
und in der Community verbessert, erleichtert und erweitert. Diese Datei hält fest, was der
Auftraggeber will, was entschieden wurde und was man über den Forever-Client wissen muss.
Stand: 2026-11-23, Version 0.1.0.

## Vorgaben des Auftraggebers

Der Auftraggeber spielt WoW Forever und hat drei Sammel-Addons ausprobiert, die ihm gefallen:
**OneForAll**, **FlareUI** und **Polestar**. Famulus soll sich an ihnen orientieren und sich auf
Folgendes konzentrieren und beschränken:

1. **Modernes, übersichtliches Layout.** Polestar gefällt ihm bisher am besten.
2. **Gemeinsames Spielen im Mittelpunkt (Entscheidung des Auftraggebers, 2026-11-23).** Famulus
   soll das Spielen unter Freunden und in der Community verbessern, erleichtern oder erweitern.
   Die Funktionen sind die **Chronik**, die **Weggefährten** und die **Aliase** (seit 2026-11-23).
   Keine Unitframes, Aktionsleisten, Guides, Schadensanzeigen oder Ähnliches.
   - **Reihenfolge (Entscheidung des Auftraggebers, 2026-11-24):** Die Aliase stehen überall als
     letzte der drei, im Addon (Seitenleiste, Hauptschalter) wie auf der Website (Navigation,
     Abschnitte, Texte) und in README und Projektbeschreibung. Vorher standen sie überall vorn.
     Die Begründung im Code („sie dienen den anderen beiden“) ist eine Deutung des Assistenten.
   - **Quality of Life entfernt (2026-11-23):** „Das machen unzählige andere Addons schon.“
     Entfernt sind die 16 QoL-Features (Händler, Quests, Beute, Soziales, Tooltips, Interface),
     das Tagebuch (es führte nur Buch über diese Automatiken), die Pausentaste, der Baustein
     `mirror` (`Core/GameOptions.lua`), `PopupService`, `QuestService` und die Selbsttest-Prüfungen
     dafür. Wer nachsehen will, wie sie gebaut waren: Git-Verlauf bis Commit `66f68ec`.
     Nicht wieder einbauen, ohne zu fragen.
3. **Schwachstellen der drei Vorbilder analysieren und daraus lernen.**
4. **Performance-optimiert.**
5. **Mehrsprachig.** Englisch und Deutsch reichen vorerst.

**Veröffentlichung:** Seit 2026-11-24 soll eine erste Alpha auf CurseForge erscheinen, mit
automatischem Upload (Entscheidung des Auftraggebers, siehe „Veröffentlichung auf CurseForge“;
vorher, Stand 2026-11-16: später, Zeitpunkt und Plattform offen). Feature-Set und Design sind
weiter nicht fertig und haben Vorrang vor Release-Arbeit. Entscheidungen deshalb so treffen, dass sie für fremde Spieler taugen: saubere
Versionierung, keine Annahmen über die eigene Addon-Sammlung, Verhalten neben anderen Addons im Blick.

Arbeitsweise: Er schreibt Deutsch und möchte Antworten auf Deutsch. Code, Kommentare und
Commit-Nachrichten sind Englisch, diese Datei Deutsch. Die README ist seit 2026-11-24 auf Wunsch
des Auftraggebers Englisch und knapp gehalten (vorher Deutsch und ausführlich); Einzelheiten
gehören hierher, nicht dorthin. Was Famulus von OneForAll, FlareUI und Polestar gelernt hat, steht
nicht mehr darin („da wir uns nun ganz woanders bewegen thematisch“); die Tabelle unten bleibt.

## Stand der Prüfung

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
- **Name (2026-11-19):** Das Addon heißt **Famulus** (lateinisch: Gehilfe eines Gelehrten oder
  Magiers); „Schnitzel“ war der Arbeitstitel. Verworfen, weil auf CurseForge schon für WoW Forever
  vergeben: „Wisp“ (ForeverWisp, dazu Wisp-Figuren in Wishwell und Sparky), „Ignis“
  (Rollenspiel-Addon), „Lantern“ (Lantern – QoL Core). Für „Famulus“ fand eine Websuche kein
  gleichnamiges Addon; vor der Veröffentlichung direkt auf CurseForge und Wago prüfen. Umbenannt
  sind Ordner, `.toc`, gespeicherte Variablen (`FamulusDB`, `FamulusCharDB`), Frame-Namen und die
  Befehle (`/fam`, `/famulus`) und das GitHub-Repo (`89pleasure/famulus`). Der Untertitel im Fenster war zuerst „Dein Gehilfe in Azeroth“ / „Your assistant in Azeroth“
  (`ui_tagline`), seit 2026-11-24 „Gemeinsam durch Azeroth“ / „Together through Azeroth“ (siehe
  „Logo“). Auf dem Mac muss der
  Symlink im Addon-Ordner neu angelegt werden (`Famulus` statt `Schnitzel`), und die Einstellungen
  aus `SavedVariables/Schnitzel.lua` gehen nicht von selbst über.
- **Logo (2026-11-19):** eine lodernde Flamme in drei Schichten mit Funken und weichem Schein, frei ohne Kachel
  ("Lodernd"), vom Auftraggeber am Mockup gewählt. Verworfen: abstrakte Zeichen (Monogramm, Kerzen-F,
  Laterne, Feder; "zu abstrakt und minimalistisch"), ein Maskottchen mit Gesicht und Fassungen mit
  Spielwelt-Motiv (Quest-Ausrufezeichen, Fackel, Runenkreis, Zahnrad, Schild, Ruhestein). Blizzards
  eigene Embleme (Allianz, Horde, WoW-Logo) bleiben außen vor. Den Kasten um die Flamme wollte er nach dem
  ersten Blick ins Spiel nicht. `logo.tga` (Flamme allein: Fenster,
  Addon-Liste) und `logo-round.tga` (auf dunkler Scheibe: Minikarte), 128 px, gezeichnet in
  `tools/make_media.py`. Das Logo hat feste Farben und folgt der Farbwelt nicht. Auf dem
  Windows-Rechner ist kein eigenes Python installiert; `make_media.py` braucht nur die
  Standardbibliothek und lief dort mit einem vorhandenen Python 3.12. Im Spiel noch nicht gesehen.
  **Bestätigt nach der Wende zum gemeinsamen Spielen (2026-11-24):** Der Auftraggeber war unsicher,
  ob die Flamme noch passt. Am Mockup „Famulus Logo – Varianten“ sah er zwei Weiterentwicklungen
  (drei Flammenzungen aus einem gemeinsamen Feuer; die Flamme auf gekreuzten Scheiten als
  Lagerfeuer) und behielt die Flamme. Gedeutet wird sie jetzt als Lagerfeuer, an dem sich die
  Gefährten treffen (Vorschlag des Assistenten); das trägt der Text, nicht das Bild.
  **Neuer Untertitel (2026-11-24, Wahl des Auftraggebers):** „Gemeinsam durch Azeroth“ / „Together
  through Azeroth“ statt „Dein Gehilfe in Azeroth“ (klang nach den entfernten QoL-Funktionen), im
  Fensterkopf (`ui_tagline`) und auf der Website (`tagline`). Er muss in eine Zeile passen: Im Kopf
  hat er bei 11 px nur etwa 180 px bis zum Seitennamen (`SIDEBAR + PAD`). Ebenfalls vorgeschlagen
  und nicht gewählt: „Eure Reise, gemeinsam erzählt“ sowie „Das Lagerfeuer für deine Gefährten“ und
  „Für alle, mit denen du unterwegs bist“ (beide zu lang für diesen Platz). Im Spiel noch nicht
  gesehen.
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

## WoW Forever: was man wissen muss

Das Spiel erschien am 2026-11-04 und ist neuer als das Trainingswissen der meisten Modelle. Nicht
aus dem Gedächtnis über „Classic“ schließen, sondern nachschlagen:

- Blizzards UI-Quellcode: `github.com/Gethe/wow-ui-source`, Branch `forever`
- `warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes` und `…/wiki/Secret_Values`
- Quellcode der Vorbilder: `github.com/smoergi/OneForAll_Forever`, `github.com/malkkav/FlareUI`,
  `github.com/fitzforge/polestar`

Recherchierte Fakten (Stand 2026-11-16, das Spiel wird häufig gepatcht):

- Spielversion 1.60.x, `## Interface: 16001`. Eine einfache `Addon.toc` genügt.
  Addon-Ordner: `World of Warcraft/_forever_/Interface/AddOns/`.
- Es ist die **moderne Retail-API** (Stand 12.x „Midnight“), nicht die Classic-API:
  `C_Container`, `C_AddOns`, `C_Item`, `C_Spell`, `C_GossipInfo`, `C_QuestLog`, `C_Map`,
  `TooltipDataProcessor`, `Settings.*`, `MenuUtil` und `AddonCompartmentFunc` existieren.
- Entfernt: die Globals `GetItemInfo` und `GetSpellInfo` (stattdessen `C_Item.GetItemInfo`,
  `C_Spell.GetSpellInfo`). `ChatFrame_AddMessageEventFilter` existiert im Client entgegen der
  Recherche noch (Selbsttest 2026-11-16), ebenso `ChatFrameUtil.AddMessageEventFilter`; für neuen
  Code die `ChatFrameUtil`-Variante nehmen.
- **Addon-Beschränkungen wie in Midnight:**
  - „Secret Values“: Solche Werte dürfen nicht verglichen, auf wahr/falsch geprüft, als
    Tabellenschlüssel benutzt oder verrechnet werden. Weiterreichen und `string.format` sind
    erlaubt. Prüfen mit `issecretvalue(v)`; im Addon über `ns.IsSecret`.
  - `COMBAT_LOG_EVENT_UNFILTERED` ist für Addons unbrauchbar.
  - `CopyToClipboard` ist geschützt. Chat-Nachrichten können im Kampf „secret“ sein.
- Felder auf Blizzards StaticPopup-Dialoge zu schreiben verursacht Taint („Aktion blockiert“);
  bei Polestar als Fehler gemeldet.
- Spielinhalt: Stufe 60, Vanilla-ähnliche Welt, nur Bodenreittiere, vier Taschen plus
  Reagenzientasche.
- Schon in der Standard-UI enthalten, also nicht nachbauen: automatisches Plündern,
  Taschen sortieren, Edit Mode, Abklingzeit-Zahlen, Schadensanzeige, sofortiger Questtext.
  Laut UI-Quellcode außerdem (2026-11-23, im Spiel ungeprüft): ein Kalender mit Einladungen (der
  Uhr-Knopf an der Minikarte, `Blizzard_Minimap/Camelot/GameTimeFrame.lua`) und eine Gruppensuche
  im Vanilla-Stil (`Blizzard_GroupFinder_VanillaStyle`, `AllowLoadGameType: classic, camelot`).
  Forever heißt im UI-Quellcode `camelot`. „Zuletzt zusammen gespielt“ (`Blizzard_RecentAllies`)
  lädt nur in Retail (`mainline`), fehlt in Forever also.

## Was aus den Vorbildern gelernt wurde

| Schwachstelle der Vorbilder | Regel in Famulus |
|---|---|
| Events dauerhaft registriert, Option erst im Handler geprüft (OneForAll: ~38 Events) | Ein Feature registriert Events erst in `OnEnable` |
| Ungedrosselte `OnUpdate`-Handler | Im Leerlauf läuft nichts pro Frame |
| Umschalten braucht `/reload` (FlareUI-Module, OneForAll-Sprache und -Profil) | Alles wirkt sofort |
| Hooks bleiben nach dem Abschalten aktiv | Hooks nur über `feature:HookFunction`/`HookScript` oder `feature:Once` plus `feature:Guard`; sie wirken nur bei eingeschaltetem Feature |
| Megabytes an Code und Daten bei jedem Login (Polestar: 70–250 MB laut Issues) | Fenster wird erst beim ersten Öffnen gebaut; keine Bibliotheken |
| Ersetzte Blizzard-Funktionen, überschriebene Methoden fremder Addons | Nur `hooksecurefunc`; nichts ersetzen, nichts in fremde Tabellen schreiben |
| ~90 Optionen, uneinheitliche Standardwerte, Chat-Meldung je Aktion | Wenige Funktionen, eine Regel für Standardwerte, eine Sammelzeile je Aktion |
| FlareUI ohne Deutsch; Polestar-Sprachen als Zusatz-Addons | enUS und deDE eingebaut und per Test auf Gleichstand geprüft |

## Das Fenster

**Neugestaltung 2026-11-18** auf Wunsch des Auftraggebers: Mit den Aliasen kam die erste größere
Funktion; das Fenster soll mit weiteren Hauptfunktionen übersichtlich bleiben. Vorgaben: Hauptfunktionen
in der Seitenleiste mit eigenem Aufbau je Funktion, modern und
schlicht wie Polestar, helles und dunkles Design (das helle ist seit 2026-11-19 wieder entfernt,
siehe „Farben“), runde Ecken, eigene Schrift. Er hat freie Hand
gelassen; Aufbau, Farben und Schrift sind Entscheidungen des Assistenten und noch nicht bestätigt.

- **Aufbau (seit 2026-11-23, Wunsch des Auftraggebers nach dem Vorbild von OneForAll, an einem
  HTML-Mockup bestätigt):** Die Funktionen stehen oben, ihre Unterbereiche links.
  - **Neuer Aufbau (2026-11-24, Wunsch des Auftraggebers nach dem ersten Blick auf die Weggefährten
    ohne Seitenleiste):** Die Navigation steht wieder in der Seitenleiste, auf allen Seiten gleich.
    Dazwischen gab es am selben Tag kurz einen Kopf mit Reitern, Suche und Symbolen und eine Seite
    ohne Seitenleiste (`page.sidebar = false`); beides ist wieder entfernt.
  - **Kopf** (76 hoch, über die ganze Breite, dunkler Grund wie die Seitenleiste): links Logo, Name
    und Untertitel; daneben Name und Beschreibung der gewählten Seite (`window.area`, während der
    Suche „Suche“ und die Zahl der Treffer); rechts nur Schließen.
  - **Seitenleiste:** oben die Suche, darunter die Hauptfunktionen als Einträge mit Symbol
    (`navButtons`; eine abgeschaltete ausgegraut mit „AUS“; gewählter Eintrag: auslaufender Verlauf, leuchtender
    Balken), unten nach einer Linie „Einstellungen“ und „Über“. Die frühere Zeile „x von y aktiv“
    ist entfernt, ebenso die Zeile „Aktiv“ unter „Über“ (Entscheidung des Auftraggebers,
    2026-11-24: stammt aus der Zeit der vielen QoL-Funktionen). Auch die Zähler aktiv/gesamt an den
    Einträgen sind entfernt.
  - **Inhalt:** ganz oben die Unterbereiche der Seite als Tabs (`window.tabs`, 48 hoch, Strich mit
    Verlauf unter dem gewählten), „Zurücksetzen“ rechts daneben. Eine Seite mit nur einem
    Unterbereich („Über“) zeigt keine Tabs; während der Suche gibt es keine. Titel und
    Beschreibung des Unterbereichs stehen nicht mehr über dem Inhalt (`ui_tab_*_desc` wird
    derzeit nicht angezeigt). Der Grund von Kopf und Seitenleiste liegt auf dem Fenster selbst
    (`Ground` in `UI/Options.lua`), damit die Körnung als ein Band darüber läuft.
    Entscheidungen des Assistenten im Einzelnen, im Spiel noch nicht gesehen.
  - Im Code heißen die Bereiche weiter „Seiten“ (`pages`, Knöpfe `navButtons`) und die
    Unterbereiche „Reiter“ (`page.tabs`, `window.tabs`, Texte `ui_tab_<id>`); wo diese Datei
    „Reiter“ eines Bereichs sagt, sind die Einträge der Seitenleiste gemeint. Die Reiterzeile im
    Inhalt (`UI.Tabs`) mit gleitender Markierung und die Überschrift „Funktionen“ sind entfallen.
  - Fenster 1180 × 730 wie das Einstellungsfenster von FlareUI (Wunsch des Auftraggebers,
    2026-11-23; vorher 880 × 590).
  - Vom Auftraggeber im Spiel gesehen und bestätigt (2026-11-23, „sieht super aus“), samt der
    Entscheidungen des Assistenten: „Über“ als eigener Reiter, Kopf und Seitenleiste auf demselben
    Grund. Der Hauptschalter in der Seitenleiste ist seit 2026-11-24 in die Einstellungen gewandert.
- **Bereiche (`ns.areas`, `Core/Features.lua`):** Jede Kategorie gehört zu genau einem Bereich (der
  Test prüft das). Reihenfolge seit 2026-11-24: Chronik, Weggefährten, Aliase (siehe „Vorgaben“);
  `ns.categories` folgt ihr, damit die Hauptschalter in derselben Reihenfolge stehen. Jeder Bereich hat einen eigenen Aufbau (`layouts.<bereich>` in
  `UI/Options.lua`). `aliases`: Reiter „Namen“ mit Karte „Neuer Alias“ und Karte
  „Deine Aliase“ (Avatar mit Anfangsbuchstabe), Reiter „Einstellungen“ (bis 2026-11-23 „Anzeige“) mit den Alias-Features.
  `chronicle`: siehe „Chronik“. `fellows`: siehe „Weggefährten“. Die Einstellungen haben die Reiter „Allgemein“ (Sprache,
  Rückmeldung im Chat, Minikartensymbol, Charakterprofil) und „Darstellung“ (Farbwelt, Funken,
  Fenstergröße). Die erste Seite beim Öffnen ist die erste der Seitenleiste, seit 2026-11-24 also
  die Chronik (vorher die Aliase).
- **Hauptschalter** (seit 2026-11-24, Entscheidung des Auftraggebers: „Nur die Hauptschalter“):
  die drei Kategorien als erste Karte „Funktionen“ unter Einstellungen › Allgemein
  (`CategoryItem`, Texte `area_<id>` und `area_<id>_desc`). Die Schalter der einzelnen Features
  bleiben auf ihren Reitern. Ist eine Kategorie aus, ist ihr Eintrag in der Seitenleiste ausgegraut und trägt
  „AUS“, ihre Tabs sind ausgegraut, und ihre Seite zeigt statt des Inhalts
  einen Hinweis mit dem Knopf „In den Einstellungen einschalten“ (`window.offNotice`), der
  Einstellungen › Allgemein öffnet.
- **Zurücksetzen** wirkt auf den Reiter (Features ganzer Abschnitt, Addon-Optionen nur ihr
  Schlüssel; auf Einstellungen › Allgemein auch die drei Hauptschalter). Erster Klick fragt
  („Wirklich zurücksetzen?“, rot), zweiter innerhalb von vier Sekunden führt aus; auf
  Standardwerten ausgegraut; ohne Einstellungen (Liste der Aliase, „Über“) und auf einer
  abgeschalteten Seite nicht vorhanden.
- **Suche:** im Kopf, über alle Seiten und Reiter, Treffer gruppiert je Reiter in Karten („Aliase ·
  Einstellungen“); keine Reiter in der Ergebnisansicht. Den Inhalt einer abgeschalteten Funktion
  lässt sie aus, ihren Hauptschalter findet sie. Auf einer Seite ohne Seitenleiste nehmen die
  Treffer die ganze Breite.
- **Farben (überarbeitet 2026-11-18, Abend):** Der Auftraggeber fand den ersten Stand (neutrale
  Grautöne, Akzent nur als Fläche) zu beliebig. Vorbilder für Farbkonzept, Akzente und Effekte:
  Polestar Guide und Mastercraft, ohne sie zu kopieren. An einem HTML-Mockup hat er das Konzept
  **„Zitrone“** gewählt: Petrol-Flächen, Akzent Zitronengelb. Eine Farbwelt (`general.accent`,
  Liste `UI.accents`) ist seitdem ein ganzes Konzept und nicht mehr nur eine Akzentfarbe: Sie tönt
  alle Flächen mit ihrem Farbton (`hue`, `saturation`; die Helligkeitsleiter `ladder`) und bringt
  einen Akzent als Farbpaar (`accent` → `accent2`) für Verläufe. Vorhanden: `lemon` (Standard),
  `mint`, `rose`, `lilac`, `amber`. Vom Auftraggeber im Spiel gesehen und bestätigt ist `lemon`;
  die anderen vier stammen aus dem Mockup.
- **Kein heller Modus (Entscheidung des Auftraggebers, 2026-11-19):** Das Fenster ist immer dunkel.
  Entfernt sind die helle Palette, die Option `general.theme`, der Knopf oben rechts, die Symbole
  Sonne und Mond und das nur dafür gebaute Umschaltfeld (`UI.Segmented`, Zeilentyp `segment`).
  Nicht wieder einbauen, ohne zu fragen. Das Signal heißt weiter `THEME_CHANGED` und feuert beim
  Wechsel der Farbwelt.
- **Akzente und Effekte:** Akzent, Verlauf und Glühen stehen nur für „aktiv / hier“: Schalter an
  (Verlauf, Schein), gewählter Reiter (Strich mit Verlauf und Schein), gewählter Bereich in der
  Seitenleiste (auslaufender Verlauf, leuchtender Balken, Zähler auf Akzent-Plakette), Karte eines
  laufenden Features (feiner Akzentrand, Marke links), Feld mit Fokus (Ring), Logo. Dazu als
  Signatur ein weicher Schein in Akzentfarbe hinter dem Logo. Tiefe über eine Lichtkante oben an
  Fenster und Karten und vertiefte Options-Zeilen. Hover blendet ein und aus (`Shape:Fade`).
  Entscheidungen des Auftraggebers am Mockup: **eine** Linie zwischen Seitenleiste und Inhalt, der
  Fensterrand läuft einheitlich um alles; die Linie über einer Options-Zeile geht von Kartenrand zu
  Kartenrand; Options-Zeilen tragen einen Punkt, keinen Winkel und keine Führungslinie; der
  Hauptknopf („Speichern“) hat einen waagerechten Verlauf, einen dunkleren Rand, eine helle Linie
  innen und einen Schatten, aber keinen Verlauf von oben nach unten (wirkte „plastisch“).
- **Hintergrund (2026-11-19, Wunsch des Auftraggebers):** Eine feine Körnung (`grain.tga`, reines
  Rauschen, ein Texel je Bildschirmpixel über `SetTexCoord`, `UI.Grain`) liegt als Band über die
  ganze Fensterbreite, Seitenleiste und Inhalt gleich, so hoch wie der Kopf (`GRAIN_BAND`), und
  läuft unter den Reitern aus. Entscheidungen des Auftraggebers nach Blicken ins Spiel: eine erste
  Fassung mit wolkiger Schicht sah fleckig aus; überall gleich war die Körnung zu viel; aus fünf
  umschaltbaren Varianten wählte er „Seitenleiste und Kopf“, aber als ein durchgehendes Band in
  Kopfhöhe. Die Auswahl im Fenster ist wieder entfernt. Der Inhalt wird nach unten etwas dunkler.
  Dazu steigen kleine Funken auf (`UI.Embers`): Texturen mit Animationen des Clients
  (`AnimationGroup`, `Alpha` und `Translation`), also ohne `OnUpdate` und ohne Lua pro Frame.
  Sie laufen nur bei offenem Fenster und liegen hinter Karten und Einträgen. Abschaltbar unter
  Einstellungen › Darstellung (`general.embers`, Standard an). Im Spiel bestätigt: Körnung und
  Funken laufen. Noch nicht gesehen: das Band in der Seitenleiste und sein Auslaufen.
- **Karten:** In Kategorie-Reitern hat jedes Feature eine eigene Karte, zusammen mit seinen
  Optionen (`FeatureBlocks`, Abstand `CARD_GAP`). Die Suche gruppiert weiter je Reiter.
- **Technik dazu:** `UI.Shade(texture, richtung, von, nach)` für Verläufe (`SetGradient`, folgt dem
  Thema wie `UI.Paint`); `Shape:SetGradient` verteilt einen Verlauf auf die Teile einer runden Form
  und braucht deren Größe. Schein und Glühen kommen ohne neue Textur aus: `UI.Shadow` mit einem
  Akzent-Farbnamen statt `shadow`, `UI.Halo` und der Schein hinter dem Logo nutzen `shadow.tga`.
  Alles nur gegen den Mock geprüft; im Spiel offen sind vor allem `SetGradient` auf Bild-Texturen
  (runde Ecken von Schalter, Knopf, Logo), waagerechte Verläufe und die Stärke der Glüheffekte.
- **Form:** runde Ecken aus Viertelkreisen von `circle.tga` plus drei Rechtecken (`UI.Round`,
  `UI.Card` mit Haarlinien-Rand); Fenster 12, Karten 10, Bedienelemente 6–8. Weicher Schatten um
  Fenster und Menüs (`UI.Shadow`, `shadow.tga`). Der frühere Verlaufsrahmen (`UI.GradientFrame`) ist
  entfallen.
- **Schrift:** Inter (SIL Open Font License 1.1) in Regular, Medium und SemiBold, mit
  `tools/make_fonts.py` auf Latein, Griechisch, Kyrillisch und Satzzeichen gekürzt (je ~100 KB).
  Auf koKR/zhCN/zhTW-Clients bleibt die Spielschrift.
  **Wie der Client Schriften lädt (geklärt 2026-11-25, aus dem Quellcode von FlareUI, Kommentar
  über `ns.FontRedraw` in `Core.lua`; dort aus Fehlerberichten von Spielern gelernt):** Eine
  Schriftdatei lädt erst, wenn ein **sichtbarer** FontString **mit Text** sie verlangt. Bis dahin
  liefert `SetFont` falsch und der String behält seine alte Schrift (ein neuer hat keine,
  `SetText` wirft dann); ist die Datei da, wechselt er von selbst. Ein versteckter oder leerer
  String lädt nichts. Text, der vor dem Laden gezeichnet wurde, kann leer bleiben; dieselbe
  Schrift noch einmal setzen hilft nicht, Größe ändern und zurück zeichnet ihn neu. Folgen:
  - Die Warnungen `font …` im Selbsttest (2026-11-19 und 2026-11-24) waren Fehlalarme: Er prüfte
    an einem versteckten, leeren String. Auch das Anfragen beim Login (verstecktes Frame, ohne
    Text) lud nichts und ist entfernt. Belegt durch den Screenshot im Kopf der Website (Windows,
    2026-11-24): Das Fenster zeigt Inter in zwei Schnitten, nicht Friz Quadrata.
  - Inter erschien trotz des alten Rückfalls auf die Spielschrift, weil der Client die erste
    Anfrage behält und den String später umstellt, ohne ihn neu zu zeichnen. Das erklärt
    vermutlich den leeren Reiter „Chronik“ und den fehlenden Zähler vom 2026-11-24 (Name des
    Reiters blieb über Seitenwechsel leer, Breite und Zähler stimmten; nach `/reload` war alles
    da).
  - Seit 2026-11-25 (`ApplyFont` in `UI/Widgets.lua`, wie `SetFontRaw` bei FlareUI): Liefert
    `SetFont` falsch, bekommt der String die Spielschrift, fragt erneut nach Inter und steht in
    einer Liste; ein Ticker (0,5 s, nur solange jemand wartet, höchstens eine Minute, beim Öffnen
    des Fensters neu) fragt nach, und sobald der Client ja sagt, wird der String mit Größe+1 und
    zurück neu gezeichnet. Der Selbsttest liest `UI.fontLoaded` und warnt nur, wenn das Fenster
    die Schrift verlangt hat und sie nicht kam; vor dem ersten Öffnen meldet er „not used yet“.
  - Nicht übernommen von FlareUI: alle Strings 2 und 10 s nach jedem Ladebildschirm neu zeichnen
    (dort gegen Strings, die sofort ja sagten und trotzdem leer blieben). Bleibt Text nach einem
    Ladebildschirm leer, ist das der nächste Schritt.
  - **Falls es wieder auftritt (Entscheidung des Auftraggebers, 2026-11-25):** Inter bleibt
    vorerst. Bleibt Text trotz des Ladefixes leer, wechselt das Fenster auf eine Schrift des
    Spiels, die von Anfang an geladen ist, und zwar **Arial Narrow** (`Fonts\ARIALN.TTF`),
    nicht Friz Quadrata. Polestar zeigt in seinem Standard-Look die Spielschrift; Inter ist dort
    nur eine Option, mit demselben schlichten Rückfall wie früher bei uns. Eine eigene
    Schriftfamilie (`CreateFontFamily`, wie bei FlareUI) hilft gegen das Laden nicht: Sie wählt
    je Text die Datei nach dem Alphabet (gegen Kästchen bei koreanischen oder chinesischen
    Namen), aber Inter darin muss genauso erst laden.
  - Im Spiel ungeprüft. Zu sehen wäre: Beim ersten Öffnen nach dem Login höchstens eine halbe
    Sekunde Spielschrift, dann Inter, kein leerer Text; `/fam test` nach dem Öffnen meldet
    `font …` als ok.
  **Ebenfalls 2026-11-24, ungeklärt:** Nach einem Tod (23:44) zeigte die Chronik ihn im Buch, die
  Karte „Diese Woche“ daneben zählte ihn nicht (5 statt 6); das Fenster war beim Tod zu und wurde
  danach geöffnet. Buch und Randspalte entstehen im selben `Render` aus denselben Einträgen.
  Beim nächsten Tod stimmte die Zahl wieder (7), BugGrabber hatte keinen Fehler, und der Mock
  zählt auch mit den gespeicherten Daten des Auftraggebers richtig. Ein Test im Spiel (Beispiele
  bei offenem Fenster einspielen) gab bei `/run local c=FamulusOptionsFrame.rail.cards[1]
  print(c.spec.stats[2].value, c.cells[2].value:GetText())` „11 11“: berechnet und gesetzt (ob
  das Fenster dabei auch 11 zeigte, hat der Auftraggeber nicht eigens gesagt). Tritt es wieder auf, diese Zeile sofort eingeben: Zeigt sie die neue Zahl, das
  Fenster aber die alte, zeichnet der Client den Text nicht neu (wie oben).
- Unverändert aus 2026-11-16: feste Fensterhöhe, längere Seiten scrollen; die Seite für
  Addon-eigene Einstellungen heißt „Einstellungen“ (intern `general`); Untertitel und
  Reiterbeschreibung sagen, was der Spieler dort findet, keine technischen Hinweise; Optionen eines
  Features (`child`) stehen eingerückt unter ihm und sind bei abgeschaltetem
  Feature eingeklappt (schmal, ausgegraut, Wert sichtbar), die Suche zeigt sie vollständig.

## Chronik

Idee des Auftraggebers (2026-11-19): die Reise des Spielers und seiner Gefährten festhalten
(Stufenaufstiege, Tode, Erfolge und mehr), grafisch aufbereitet „wie ein Bilderbuch“, am liebsten
mit Live-Benachrichtigung. Stand: Erfassung, das Teilen zwischen Spielern, die Benachrichtigung
und die Bilderbuch-Optik sind gebaut und nur gegen den Mock geprüft.

- **Aufbau:** Bereich und Kategorie `chronicle`, Daten über `ns.ChronicleService`
  (`Modules/Chronicle/ChronicleService.lua`) in `FamulusDB.chronicle` (accountweit, außerhalb der
  Profile, höchstens 2000 Einträge, Art und Werte statt Text). Reiter „Alle“, „Meine Reise“,
  „Freunde“ (bis 2026-11-24 „Gefährten“, siehe „Chronik und Weggefährten“) und „Einstellungen“
  (bis 2026-11-23 „Aufzeichnung“) (`layouts.chronicle`). In dieser Datei heißen die Personen der
  Chronik aus der Zeit davor oft noch „Gefährten“; im Fenster sind es „Freunde“.
- **Buch mit Randspalte (Entscheidung des Auftraggebers, 2026-11-23, am HTML-Mockup „Famulus
  Chronik“ gewählt: Variante A mit „Wiederholungen bündeln“ und „Kapitelkopf in einer Zeile“):**
  Anlass war der erste Screenshot im 1180er-Fenster: Karten 428 px breit bei etwa 170 px Text,
  vier gleiche Tode untereinander, Kapitelköpfe über 100 px hoch. Verworfen: B, ein breites Buch
  mit Karten bis 360 px und eigenen Stufenaufstiegen als Band über der Linie. Nur gegen den Mock
  geprüft, im Spiel noch nicht gesehen.
  - Auf den drei Erzähl-Reitern ist das Buch 600 px breit (`BOOK_W`, das Maß vor dem Umbau des
    Fensters); rechts daneben, 28 px Abstand, eine Randspalte von 272 px (`UI.Rail`,
    `UI/Rail.lua`; ein Reiter liefert sie über `tab.rail`). Sie scrollt nicht mit dem Buch,
    sondern für sich, falls sie länger als das Fenster ist. Während der Suche und auf
    „Einstellungen“ gibt es sie nicht; Zeilen und Karten nehmen dann die volle Breite (`RowSetItem`
    bekommt die Breite übergeben).
  - „Alle“: Karte „Diese Woche“ (Stufe mit Zahl der Aufstiege, Tode, neu entdeckte Gebiete,
    Berufe und Meilensteine; nur der gespielte Charakter, letzte sieben Tage, Vorname rechts) und
    Karte „Freunde“ (Alias, letztes Ereignis mit Uhrzeit oder Tag, Stufe, online/offline).
    „Meine Reise“: „Diese Woche“ und „Berufe“ mit Punkten und Balken. „Freunde“: je Person
    eine Karte mit ihrer „Bilanz“ (bis 2026-11-24 „Steckbrief“; Stufe, online, die vier geteilten
    Zahlen), ohne geteilte Zahlen „Noch keine Bilanz geteilt.“; diese Karten stehen nicht mehr
    über dem Buch.
  - Gefährten sind alle mit Eintrag oder Steckbrief (`ChronicleService.Companions`), zuletzt
    gehörte zuerst. Stufe: die höhere aus letztem Stufeneintrag und Steckbrief. Online:
    `ChronicleService.OnlineCheck` sieht einmal je Aufbau in Freundesliste und Gildenliste; der
    Stand gilt beim Aufbau des Fensters und wird nicht nachgeführt, wenn jemand online kommt.
  - Ein Klick auf einen Gefährten (Liste oder Bilanz) zeigt im Buch nur seine Ereignisse;
    darüber steht „Nur Ereignisse von …“ mit „Alle zeigen“, ein zweiter Klick hebt es auf. Ein
    anderer Reiter, eine andere Seite oder das Schließen vergisst die Wahl (`chronicleWho`).
    Kennen die Weggefährten die Person (`FellowService.Find`, Name in jeder Schreibweise) und
    sind sie eingeschaltet, steht dort zusätzlich „Eure Geschichte“ und öffnet ihre Geschichte.
  - **Wiederholungen bündeln:** Folgen im Buch direkt aufeinander Tode im selben Gebiet oder
    Stufenaufstiege desselben Gefährten, teilen sie sich eine Karte (`SameRun`, `ChronicleRun` in
    `UI/Options.lua`; Satz aus `ChronicleService.TextRun`): „3-mal gefallen in Dunkelküste“ mit
    der Zahl in der Ecke des Bildes, „Stufe 21 bis 22 erreicht“ mit der höchsten Stufe im Bild.
    Unter der Zeile stehen alle Uhrzeiten als kleine Plaketten (höchstens zehn, die letzte zählt
    den Rest). Eigene Stufenaufstiege bleiben einzeln, sie sind die Meilensteine. Die Zahl der
    Ereignisse im Kapitelkopf zählt weiter jeden Eintrag.
  - **Kapitelkopf in einer Zeile:** links die Zeit (bis 2026-11-24 der Tag), Mitte der Titel in
    der Buchschrift (22 px; bis 2026-11-24 das Gebiet), Stufen und Zahl der Ereignisse rechts,
    außen je eine Linie, die zum Rand hin ausläuft. Etwa 36 px hoch statt über 100, mit der Route
    darunter 30 px mehr. Die Zierde mit dem Funken ist entfallen.
- **Ein Kapitel ist ein Spielabend (Entscheidung des Auftraggebers, 2026-11-24, an der Leinwand
  „Famulus Chronik – Kapitel“, claude.ai-Artifact `Sp9tF6ba6wfgKroNqejVoT`: Variante C):** Anlass:
  Ein Kapitel je Tag hieß nach dem Gebiet, das die meisten Einträge nannten („Heute · Feralas“),
  dabei zieht man beim Spielen durch mehrere Gebiete. Gezählt wurden auch die Gebiete der
  Freunde, und Mitternacht teilte einen Spielabend. Verworfen: A (Tag mit Route), B (Wegmarken
  auf der Linie; „der Ort ist weniger wichtig als die Ereignisse selbst“), D (der wichtigste
  Moment als Titel), E (Stufen als Kapitel). Nur gegen den Mock geprüft, im Spiel nicht gesehen.
  - Ein neues Kapitel beginnt nach einer Pause von zwei Stunden zwischen zwei gezeigten Einträgen
    (`SESSION_GAP` in `UI/Options.lua`). Gezählt wird, was der Reiter zeigt, im gefilterten Buch
    also nur die Einträge der Person. Eine Abfrage von Login und Logout gibt es nicht; eine
    lange Pause teilt den Abend.
  - **Titel** nach der Tageszeit, zu der die Sitzung begann (`SessionTitle`): Morgen ab 5, Mittag
    ab 11, Nachmittag ab 14, Abend ab 18, Nacht ab 23 Uhr. Bis 5 Uhr früh zählt die Nacht zum Tag
    davor (`NIGHT_SHIFT`), damit ein Abend bis 2 Uhr „Gestern Nacht“ bleibt und nicht „Heute
    Nacht“ heißt. „Heute Abend“, „Gestern Nachmittag“; ältere heißen nach dem Wochentag
    („Sonntagnacht“, enUS „Sunday night“) und tragen links das Datum statt der Zeit. Texte
    `c_when_<today|yesterday|day>_<teil>`, `c_weekday_0` bis `_6` (eigene Wochentage, weil
    unklar ist, ob Forever `CALENDAR_WEEKDAY_NAMES` kennt).
  - Links von–bis (`c_ch_span`), bei nur einer Uhrzeit diese allein.
  - **Route** unter dem Kopf: die Gebiete der eigenen Einträge in zeitlicher Reihenfolge, als
    Plaketten mit Pfeilen (`chevron.tga`, gedreht); ein Gebiet steht wieder, wenn man
    zurückkehrt. Gebiete der Freunde zählen nicht. Ist die Zeile breiter als das Buch, weichen die
    ältesten Gebiete einem „…“. Die Route kennt nur Gebiete, in denen etwas festgehalten wurde
    (wer nur durchreitet, taucht nicht auf); jeden Gebietswechsel mitzuschreiben wäre möglich,
    ist aber nicht beauftragt.
  - Im Spiel lief die Route beim ersten Mal auf einen Fehler (`head.width`, siehe „Fehler
    2026-11-24“); behoben, danach lief die Chronik im Spiel („Funktioniert“).
  - Seit 2026-11-25 auch in „Eure Geschichte“ bei den Weggefährten (siehe dort). Kapitelkopf
    (`SessionHead`) und die Einteilung der Weggefährten-Bücher (`SessionChapters`, für „Runden“
    und „Eure Geschichte“) stehen je einmal in `UI/Options.lua`; gezeichnet wird alles von
    `UI.Book`. Offen: Die Website zeigt noch den alten Kapitelkopf.
- **Bilderbuch (2026-11-19):** Der Auftraggeber fand den HTML-Entwurf „schon ganz cool“ und ließ
  ihn so umsetzen. Die drei Erzähl-Reiter zeigen keine Zeilen mehr, sondern ein Buch
  (`UI.Book`, `UI/Book.lua`; ein Reiter liefert es über `tab.book`, `Render` legt es unter die
  Karten): je Tag (seit 2026-11-24 je Spielabend) ein Kapitel mit Überschrift, darunter eine
  Linie in der Mitte, an der die Ereignisse abwechselnd links und rechts als Karten hängen, mit Bild, Punkt auf der Linie und
  Uhrzeit auf der Gegenseite. Entscheidungen des Assistenten, noch nicht im Spiel gesehen:
  - Ein Kapitel hieß nach dem Gebiet, in dem die meisten seiner Ereignisse spielen; seit
    2026-11-24 ist es ein Spielabend mit eigenem Titel (siehe oben). Eine Kapitelnummer wie im
    Entwurf gibt es nicht (gezeigt werden nur die letzten 50 Ereignisse, eine Zählung wäre nicht
    stabil).
  - Bilder sind eigene Symbole (`skull.tga`, `swords.tga`, `peaks.tga`, `star.tga`, 64 px) oder
    bei Stufen die Zahl; Tod und Boss haben feste eigene Farbtöne, der Rest folgt der Farbwelt.
    Der eigene Stufenaufstieg ist der Meilenstein: größere Karte, Akzentrand, Akzentmarke links
    (der Schein ist seit dem Angleichen an die Options-Karten entfallen).
  - Ereignisse von Gefährten und von eigenen anderen Charakteren tragen eine Marke mit
    Anfangsbuchstabe; seit 2026-11-24 das Klassensymbol, sobald die Klasse bekannt ist (siehe
    „Klasse und Name“ unten).
  - Überschriften und Stufenzahl stehen in der Buchschrift des Spiels, gelesen aus dem
    Font-Objekt `QuestTitleFont` (`UI.SetDisplayFont`), damit jede Sprache ihre Datei bekommt;
    fehlt das Objekt, nimmt das Fenster Inter. `QuestTitleFont` gibt es im Forever-Client
    (Screenshot 2026-11-23, deDE: Kapitelüberschriften in der Buchschrift). Kursive Schrift wie
    im Entwurf gibt es nicht.
- **Überarbeitung nach dem ersten Screenshot (2026-11-19, vier Vorschläge des Assistenten, vom
  Auftraggeber alle angenommen):**
  1. **Name im Streifen:** Die Überschrift eines Gefährten-Ereignisses nennt ihn im Buch nicht mehr
     („Schlafsack erhalten“ statt „Mira erhält: Schlafsack“); der Name (oder Alias) steht mit dem
     Anfangsbuchstaben im vertieften Streifen unten. `ChronicleService.Text(entry, true)` liefert
     die Überschrift ohne Namen; die Einblendung hat keinen Streifen und nimmt `story.fullTitle`.
     Seit 2026-11-24 mit Klassensymbol und „Alias (Charaktername)“, siehe „Klasse und Name“.
  2. **Symbole füllen den Rahmen:** Der Rahmen hat nur noch leicht runde Ecken (5 px), das Symbol
     liegt zwei Pixel vom Rand und ist stärker beschnitten (10 % je Seite), damit der schwarze
     Eigenrand der Spielsymbole verschwindet.
  3. **Spalten laufen unabhängig:** Die Karten wechseln weiter die Seite, aber jede Seite läuft für
     sich weiter, sodass die Seiten ineinandergreifen (vorher belegte jedes Ereignis eine eigene
     Zeile). Nur die Punkte auf der Linie halten Abstand (`DOT_GAP`) und bleiben in zeitlicher
     Reihenfolge. Die Linie gehört jetzt zum Kapitel (`book.trails`); die Uhrzeit steht nicht
     mehr frei auf der Gegenseite (siehe unten).
  4. **Zahl auf Symbol:** Stufen und Berufs-Meilensteine zeigen ihre Zahl auf einem abgedunkelten
     Spielsymbol (Stufe: `UI.gameIcons.level`, Beruf: das Berufssymbol) statt auf einer flachen
     Kachel.
  Im Spiel gesehen (zweiter Screenshot): Alle Spielsymbole laden, auch die fest gewählten für
  Stufe, Boss, Gebiet und das Reitsymbol aus dem Zauber. Danach nachgebessert (Entscheidungen des
  Assistenten, noch nicht bestätigt): Die Uhrzeit steht am Ende der Zeile unter der Überschrift
  („in Tanaris  ·  22:07“) statt in der Kartenecke, wo sie der Überschrift Breite nahm; die Punkte
  auf der Linie sind kleiner (22 px) und haben einen kurzen Strich zu ihrer Karte, weil bei
  ineinandergreifenden Spalten sonst unklar ist, welcher Punkt zu welcher Seite gehört; die
  Abdunklung unter einer Zahl ist kräftiger; Beispieleinträge benennen kein Kapitel, das echte
  Einträge hat.
- **Der Bildrahmen ist im Buch bei jedem Ereignis gleich groß** (54 px; Vorgabe des Auftraggebers,
  2026-11-19, ihm gefällt die Größe bei Berufen und Gefährten). Auch ein Meilenstein hat keinen
  größeren Rahmen; nur seine Karte ist etwas höher.
- **Bilder sind Symbole des Spiels (Wunsch des Auftraggebers, 2026-11-19):** Sie sind eckig und es
  gibt sehr viele; die eigenen Zeichnungen (`skull.tga` usw.) stehen nur noch klein auf dem Punkt
  der Zeitlinie und als Rückfall. Reihenfolge (`EntryTexture` in `UI/Options.lua`):
  1. das Symbol, das mit dem Eintrag gespeichert ist (`entry.icon`, eine Datei-ID): bei Berufen
     aus `GetProfessionInfo`, bei Herausforderungen aus `GetAchievementInfo`; es wird mitgeteilt;
  2. das Symbol des Gegenstands (`C_Item.GetItemIconByID`) oder des Zaubers einer Fähigkeit
     (`C_Spell.GetSpellTexture`);
  3. das Symbol der Art aus `UI.gameIcons` (`UI/Theme.lua`): Tod, Boss, Gebiet, Herausforderung,
     Beruf, Fähigkeit, Gegenstand.
  Die Namen in `UI.gameIcons` sind Symbole aus Vanilla und im Forever-Client ungeprüft;
  `/fam test` meldet je Art (Gruppe `media`, „icon …“), ob der Client die Datei hat. Die
  Symbole werden nicht eingefärbt und folgen der Farbwelt nicht; der Rahmen darum schon.
- **`ownJourney`:** `PLAYER_LEVEL_UP`, `PLAYER_DEAD`, `BOSS_KILL`, `ACHIEVEMENT_EARNED` und
  `ZONE_CHANGED_NEW_AREA`. Ein Gebiet hinterlässt je Charakter genau eine „Ankunft“
  (`FamulusCharDB.zones`), und nur, wenn er es neu entdeckt (Wunsch des Auftraggebers, 2026-11-19):
  - Beim Einschalten liest das Feature die Weltkarte und merkt jedes Gebiet mit aufgedecktem Teil
    als bekannt vor (`C_Map.GetMapChildrenInfo` unter der obersten Karte,
    `C_MapExplorationInfo.GetExploredMapTextures`). Gelingt das nicht (etwa in einer Instanz),
    versucht es der nächste Gebietswechsel erneut. Fehlt die API, gilt wie zuvor „zum ersten Mal,
    seit die Chronik läuft“. Ob beide Funktionen im Forever-Client so antworten und ob die
    Kartennamen zu `GetRealZoneText` passen, ist im Spiel ungeprüft.
  - Auf einem Flug (`UnitOnTaxi`) wird nichts geschrieben und nichts als gesehen gemerkt. Nach der
    Landung (`PLAYER_CONTROL_GAINED`, eine Sekunde später) wird der Landeort wie ein Gebietswechsel
    geprüft.
  - **Berufe (Wunsch des Auftraggebers, 2026-11-19):** `SKILL_LINES_CHANGED` mit `GetProfessions`
    und `GetProfessionInfo` (beides im UI-Quellcode des Forever-Clients, Ordner `Camelot`; im Spiel
    ungeprüft). Arten `profession` (Beruf erlernt, Bild: Hammer `hammer.tga`) und `skill`
    (Meilenstein alle 75 Punkte, Bild: die Zahl). Der letzte Stand je Beruf steht in
    `FamulusCharDB.skills`. Ein Beruf, der mit 75 oder mehr Punkten zum ersten Mal auftaucht, war
    schon vor der Chronik da und wird nur gemerkt; beim Einschalten entsteht kein Eintrag. Beide
    Arten werden geteilt (`FIELDS` in `Sharing.lua`); der Berufsname reist in der Sprache des
    Absenders. Dazu zählen die zwei Hauptberufe, Erste Hilfe, Angeln und Kochen.
    Ein Klick auf die Karte öffnet das Berufsfenster (Wunsch des Auftraggebers):
    `C_TradeSkillUI.OpenTradeSkill(skillLine)`, nicht im Kampf (`story.onClick` in `UI/Book.lua`,
    die Karte leuchtet unter der Maus). Bei Gefährten öffnet der Klick ihr Rezeptbuch nach dem
    Muster von Guildy (`Game/TradeSkill.lua`, `OpenBook`): Der Berufslink lässt sich selbst bauen,
    `trade:<guid>:<zauber>:<fertigkeit>`, und `SetItemRef(link, text, "LeftButton")` öffnet
    Blizzards Fenster. Die GUID kommt beim Klick aus Freundesliste oder Gildenliste
    (`ChronicleService.BookLink`), der Zauber je Beruf aus `LINK_SPELL` (Bergbau: Verhüttung;
    Kräuterkunde, Kürschnerei und Angeln haben kein Buch und sind nicht klickbar). Geht nur,
    solange die Person online ist (laut Guildy außerdem nur auf demselben Shard); sonst sagt eine
    Chat-Zeile das. Berufe eigener anderer Charaktere sind nicht klickbar. Die frühere Aussage
    des Assistenten, fremde Berufe ließen sich nur über einen geposteten Link öffnen, war falsch.
    Im Spiel ungeprüft.
  - **Fähigkeiten (Wunsch des Auftraggebers, 2026-11-19):** Was der Charakter lernt und am Zauber
    erkennbar ist, steht in einer Tabelle: `ChronicleService.abilities` mit `id`, `spell`
    (Haupterkennung über `IsPlayerSpell`, Entscheidung des Auftraggebers), optional `skill`
    (`{ line, rank }`, Ersatz über `C_SkillInfo.GetSkillLineInfoByID`), `picture` (Name in
    `UI.media`) und `big` (Meilenstein im Buch). `ownJourney` prüft die Tabelle in einer Schleife
    bei `SPELLS_CHANGED` und `SKILL_LINES_CHANGED` (`CheckAbilities`). Eine Art `ability` für alle:
    Eintrag `{ ability = "<id>", name = <Zaubername>, level }`, Stand in
    `FamulusCharDB.abilities`; was beim Einschalten schon gelernt ist, wird nur gemerkt.
    - **Eine neue Fähigkeit** ist eine Zeile in der Tabelle plus `c_ability_<id>` und
      `c_their_ability_<id>` in beiden Sprachen (der Test prüft Sätze und Bild je Zeile).
    - Bisher: `riding` (Zauber 33388) und `ridingFast` (33391), beide mit Hufeisen
      (`horseshoe.tga`) und als Meilenstein, Ersatz über Fertigkeit 762 ab 75 bzw. 150 Punkten.
      Die IDs stammen aus Retail und Classic; ob Forever sie so führt, ist im Spiel ungeprüft.
    - Kennt eine Version die `id` eines Gefährten nicht (neueres Addon), zeigt sie den
      mitgeschickten Zaubernamen („… erlernt Schwimmen“).
    - **Kein Zauber- und kein Berufe-Service (geprüft 2026-11-19):** Nur `ownJourney` fragt
      Zauber ab (`IsPlayerSpell`). Berufe brauchen keine Tabelle, weil der Client sie selbst
      aufzählt; seit 2026-11-23 liest sie `ChronicleService.Professions` (Name, Symbol, Punkte,
      Höchstwert, Fertigkeit) für `ownJourney` und die Randspalte. Ein `SpellService` oder
      `ProfessionService` lohnt, sobald ein Feature außerhalb der Chronik dieselben Daten braucht
      (etwa Haltbarkeits- oder Berufshelfer); dann die Abfragen dorthin ziehen.
  - **Besondere Gegenstände (Wunsch des Auftraggebers, 2026-11-19):** dasselbe Prinzip über die
    Gegenstands-ID. Tabelle `ChronicleService.items` mit `item` (ID), optional `picture` (Standard:
    Truhe, `chest.tga`) und `big`. `ownJourney` prüft bei `BAG_UPDATE_DELAYED` mit
    `C_Item.GetItemCount(id, true)` (Taschen und Bank) und fragt nur Gegenstände ab, die der
    Charakter noch nie hatte (`FamulusCharDB.items`); hat er alle, kostet das Ereignis nichts.
    Art `item`: `{ item = <ID>, name, level, zone }`. Der Satz nennt den Gegenstand so, wie der
    Client des Lesers ihn nennt (`C_Item.GetItemNameByID`), sonst mit dem mitgeschickten Namen;
    eigene Sätze je Gegenstand gibt es nicht. **Ein neuer Gegenstand ist eine Zeile in der
    Tabelle.** Was beim Einschalten schon in den Taschen liegt, wird nur gemerkt. Bisher: 211527
    (Schlafsack, ID vom Auftraggeber). Im Buch zeigt ein Gegenstand das Symbol, das das Spiel ihm
    gibt (Wunsch des Auftraggebers; `C_Item.GetItemIconByID`, `story.texture` in `UI/Book.lua`):
    in eigenen Farben, also ohne `UI.Tint`, mit beschnittenem Rand im runden Rahmen. Der Punkt auf
    der Zeitlinie bleibt die Truhe; kennt der Client kein Symbol, steht sie auch im Bild. Das ist
    die einzige Stelle, an der das Buch eine Textur des Spiels statt eines eigenen Symbols zeigt.
    Die Maus über dem Bild zeigt den Tooltip des Spiels (Wunsch des Auftraggebers): bei
    Gegenständen `GameTooltip:SetItemByID`, bei Fähigkeiten aus der Tabelle `SetSpellByID`
    (`story.item`, `story.spell`). Nur solche Bilder fangen die Maus; andere nicht. Eine
    Fähigkeit, die diese Version nicht kennt, hat keinen Tooltip (die Zauber-ID reist nicht mit).
    Im Spiel ungeprüft; ein Gegenstand, der beim Erhalt
    sofort verbraucht wird oder nie in die Taschen kommt, wird so nicht erkannt.
  - Zwei Einträge gleicher Art in derselben Sekunde gelten als Dublette, außer sie unterscheiden
    sich in `skill`, `rank`, `ability` oder `item`.
- **Beispieleinträge (2026-11-19):** `/fam chronicle demo` schreibt 21 erfundene Einträge über drei
  Tage (eigene und von zwei erfundenen Gefährten, jede Art mindestens einmal; seit 2026-11-23 dazu
  drei Tode hintereinander und zwei Stufen eines Gefährten, damit das Bündeln zu sehen ist; seit
  2026-11-24 auf Wunsch des Auftraggebers dazu eine dritte Gefährtin, Lysa, und Steckbriefe mit
  Stufe und Statistiken für Mira, Borin und Lysa, damit der Reiter „Gefährten“ etwas zeigt; ein
  echter Steckbrief gleichen Namens wird nicht überschrieben), `/fam chronicle demo clear`
  entfernt sie wieder (`ChronicleService.Demo`, `ClearDemo`). Sie tragen `demo = true` und
  verlassen den Client nie: Weder der Live-Versand noch das Nachreichen noch das Weiterreichen
  schickt sie. Gedacht zum Ansehen des Buchs und für Screenshots.
  **Sprache (2026-11-24, Wunsch des Auftraggebers, für englische Screenshots):** Gebiete, Namen
  und Personen der Beispiele folgen der Sprache von Famulus (`ns:GetLocaleCode()` in
  `Core/Locale.lua`), nicht mehr der des Clients (`GetLocale()`). Die Personen heißen auf Englisch
  Mira Stormfeather, Borin Ironbeard und Lysa Morningdew (Deutsch: Sturmfeder, Eisenbart,
  Morgentau), in beiden Diensten gleich, damit die Verweise zwischen Chronik und Weggefährten
  greifen. Nach einem Sprachwechsel die Beispiele neu schreiben; die alten bleiben in ihrer
  Sprache. Was der Client selbst benennt, bleibt in seiner Sprache: Gegenstände
  (`C_Item.GetItemNameByID`, „Schlafsack“) und Klassen (`LOCALIZED_CLASS_NAMES_MALE`, „Magier“).
  Für ein ganz englisches Bild muss also der Client auf Englisch stehen. Der Test prüft beide
  Sprachen auf einem deutschen Client. Nur gegen den Mock geprüft.
- **`companions`:** vergleicht bei `FRIENDLIST_UPDATE` die Stufen der Freundesliste mit dem zuletzt
  gemerkten Stand (nach GUID). Zeigt Gefährten unter ihrem Alias.
- **`sharing` (Entscheidung des Auftraggebers, 2026-11-19):** Anvisieren und Nähe taugen nicht; die
  Chronik soll unabhängig vom Ort der Freunde sein. Deshalb spricht Famulus mit Famulus
  (`Modules/Chronicle/Sharing.lua`): Addon-Nachrichten mit dem Präfix `Famulus`, geflüstert an
  Freunde der Freundesliste und Gildenmitglieder, die online sind. Angenommen wird nur von Leuten
  auf der Freundesliste oder in der Gilde, nur per WHISPER (Ausnahme: der Gruß `1~P` im
  Gildenkanal), nur bekannte Felder; `|` und Steuerzeichen werden entfernt.
  - **Gilde (2026-11-19):** Wer online kommt, grüßt die Gilde einmal im Gildenkanal (`1~P`), sobald
    die Gildenliste da ist; wer Famulus hat, antwortet per Flüstern mit einem Gruß. Freunde werden
    weiter einzeln gegrüßt. Dass Addon-Nachrichten im Gildenkanal in Forever ankommen, zeigt Guildy
    (sendet dort). Namen: Gildenliste und Absender können `Vorname Nachname-Realm` liefern
    (so liest Guildy sie); der Schlüssel schneidet das ab.
  - **Weiterreichen (Wunsch des Auftraggebers, 2026-11-19):** Neuigkeiten von jemandem, der offline
    ist, kommen über einen verbundenen Gefährten, der sie hat. Auf einen Gruß
    folgen bis zu 20 Angebote `1~O~<wer>~<zeit>` (seit 2026-11-25 nur über Leute, die gerade nicht
    online sind); wer daraus Neues erwartet, fragt mit `1~W~<wer>~<seit>` und bekommt
    bis zu 20 Einträge als `1~R~<wer>~<zeit>~<art>~…`. Regel: Erfragt und angenommen wird nur über
    Gildenmitglieder und über Leute, deren Addon in den letzten 30 Tagen direkt geantwortet hat
    (`FamulusDB.chronicle.links`; eine direkte Antwort kommt nur von jemandem, der den Spieler auf
    der Freundesliste oder in der Gilde hat, das belegt beidseitige Freundschaft). So kommt nichts
    über Fremde an. Je Person wird pro Sitzung nur ein Gefährte gefragt, und `R` wird nur von ihm
    angenommen. Weitergereichte Einträge tragen `via` (angezeigt als „über <Name>“) und verschieben
    den Lesezeiger für den direkten Gruß nicht (`NewestFrom(who)` ohne `withRelayed`), sonst
    entstünde eine bleibende Lücke, wenn der Weiterreichende selbst etwas verpasst hat. Grenzen:
    Ein Gefährte könnte Einträge über andere fälschen, und ein verändertes Addon könnte über jeden
    fragen; der Antwortende prüft das nicht. Für Stufen, Tode und Bosse vertretbar. Streicht jemand
    den Spieler von der Freundesliste, gilt er bis zu 30 Tage weiter als verbunden.
  - Nachrichten, Felder mit `~` getrennt: `1~H~<zeit>` (Gruß: „deine Neuigkeiten habe ich bis
    <zeit>“), `1~E~<zeit>~<art>~k=v;k=v` (ein Eintrag), `1~S~<stufe>~id=n;id=n~<klasse>`
    (Statistiken und seit 2026-11-24 die Klasse, etwa `MAGE`; ältere Versionen schicken sie nicht
    und übergehen das Feld beim Empfang).
  - Ein Gruß geht an jeden Freund, der online kommt. Wer antwortet, gilt für die Sitzung als
    verbunden und bekommt die eigenen Meilensteine live. Auf einen Gruß folgen alle verpassten
    eigenen Einträge (in Runden zu 20, siehe „Warteschlange“) und die Statistiken.
  - **Statistiken nach eigenen Ereignissen (seit 2026-11-25):** Fünf Sekunden nach einem eigenen
    Eintrag, der live rausgeht, gehen auch die Statistiken an alle Verbundenen (`STATS_DELAY`,
    `SendStatisticsSoon` in `Sharing.lua`), einmal für mehrere Ereignisse in diesen fünf
    Sekunden. Anlass (im Spiel bemerkt, 2026-11-24): Ein Freund sah in der Bilanz weiter
    „6 Tode“, obwohl die neuen Tode live bei ihm ankamen. Vorher gingen die Statistiken nur als
    Antwort auf einen Gruß raus, und ein `/reload` des Absenders löst beim Freund keinen Gruß aus
    (er ist dort weiter verbunden); die Bilanz stand also auf dem Stand des letzten Logins
    einer der beiden. Die Verzögerung ist eine Entscheidung des Assistenten: Der Client zählt
    einen Tod vermutlich erst einen Moment nach `PLAYER_DEAD` in die Statistik. Besiegte
    Kreaturen und Quests erzeugen keinen Eintrag; ihre Zahlen werden nur mit einem anderen
    Ereignis oder einem Gruß frisch. Die Gegenseite braucht keine neue Version. Nur gegen den
    Mock geprüft.
  - Geteilte Statistiken (IDs des Spiels): 60 Tode, 107 besiegte Kreaturen, 98 Quests, 932 betretene
    Dungeons. Sie stehen als „Bilanz“ je Person in der Randspalte des Reiters „Freunde“
    (`FamulusDB.chronicle.profiles`; im Code heißen sie weiter `profile`). Die Liste steht seit
    2026-11-25 in `ChronicleService.STATISTICS` (vorher am Feature, das Fenster griff dafür in
    `ns.features.sharing`).
  - **Warteschlange (seit 2026-11-25, Freigabe des Auftraggebers nach der Analyse unten; die
    Umsetzung im Einzelnen hat der Assistent entschieden):** Alles geht über eine Warteschlange
    mit Ticker (alle 0,5 Sekunden, nur solange etwas wartet). Während der Chat-Sperre (Bosskampf,
    gesperrte Karte) bleibt sie stehen. Das Leitungsformat ist unverändert.
    - **Takt wie der Client:** Laut warcraft.wiki.gg (Seite `C_ChatInfo.SendAddonMessage`, Stand
      Forever 1.60.1) darf jeder Präfix 10 Nachrichten auf einmal senden und bekommt eine je
      Sekunde zurück, **außer Flüstern außerhalb von Instanzen**; dazu hat der Server eine eigene
      Grenze und kann bei zu viel Verkehr die Verbindung trennen, und er kann die Werte jederzeit
      ändern. Seit 2026-11-25 (Wunsch des Auftraggebers nach dem Abgleich mit dem Wiki) deshalb
      zwei Budgets in `Flush`: die 10 plus 1 (`ALLOWANCE`, `REFILL`) nur für den Gildenkanal, und
      für alles ein Budget nach Bytes mit den Werten von ChatThrottleLib v32 (`BANDWIDTH` 800 je
      Sekunde, `BURST` 4000, `OVERHEAD` 40 je Nachricht). Nach einem Ladebildschirm
      (`PLAYER_ENTERING_WORLD`) startet das Budget leer und füllt sich fünf Sekunden lang nur mit
      einem Zehntel (`SETTLE`, wie ChatThrottleLib). Lehnt der Client doch ein Flüstern ab, zählen
      Flüstern ab da auch gegen die 10 plus 1 (`whispersCounted`; `devLog` „whisper throttled“):
      So zeigt sich im Spiel, ob Forever Flüstern drosselt. ChatThrottleLib selbst ist bewusst
      nicht eingebunden (Entscheidung des Auftraggebers, 2026-11-25): Sie verwirft Nachrichten bei
      `AddOnMessageLockdown`, kennt `TargetOffline` nicht, kann eingereihte Nachrichten nicht
      ersetzen (Gruß mit spätem Stand, Nachholen in Runden), setzt dauerhafte Hooks und ist eine
      Bibliothek mit globalem Namen. Ihr Vorteil, ein Budget gemeinsam mit anderen Addons, fehlt
      Famulus also. Meldet `SendAddonMessage` trotzdem `AddonMessageThrottle`,
      `ChannelThrottle` oder `AddOnMessageLockdown`, bleibt die Nachricht vorn in der Reihe und
      geht später noch einmal (wie ChatThrottleLib ab v29). Ein schlichtes `false` (Clients vor
      10.2.7; Forever liefert laut UI-Quellcode das Enum) gilt ebenso als abgelehnt, aber nur fünfmal (`MAX_REFUSED`), weil es auch eine
      bleibende Ablehnung sein kann. Bei `TargetOffline` geht an die
      Person nichts mehr (`gone`), bis sie selbst wieder etwas schickt oder die Listen sie als
      offline und wieder online zeigen. Die Werte kommen aus `Enum.SendAddonMessageResult`, sonst
      aus festen Zahlen; `/fam test` prüft, ob es die drei Namen gibt (Gruppe `api`). Im
      Entwicklermodus steht je Sitzung und Art eine Zeile im `devLog` (`SHARE`, „throttled“,
      „whisper throttled“, „lockdown“, „offline“), ohne Namen. So lässt sich im Spiel sehen, ob
      Forever drosselt. Die Zahlen des Enums sind im Branch `forever` von `Gethe/wow-ui-source`
      bestätigt (`ChatConstantsDocumentation.lua`, 0 bis 12, 2026-11-25). Laut Wiki schicken
      Testaccounts seit 1.60.1 keine Addon-Nachrichten; mit welchem Rückgabewert, ist offen.
    - **Zwei Spuren:** vorn die eigenen Einträge (live und nachgeholt, in zeitlicher Folge), Grüße,
      Fragen `W` und die Bilanz nach einem Live-Eintrag; hinten die Bilanz in einer Antwort,
      Angebote und weitergereichte Einträge. Eigene Einträge stehen bewusst vorn und in Reihe:
      Der Stand beim Gefährten („deine Neuigkeiten habe ich bis …“) darf nie über einen Eintrag
      springen, den er nicht hat, sonst bekäme er ihn nie. Ein Live-Eintrag wartet deshalb hinter
      dem Nachholen. Eigene Einträge werden nie abgewiesen. Für den Rest gelten 100 (vorn) und
      200 (hinten) Plätze; Grüße werden nie abgewiesen, sonst bliebe ein erster Kontakt ohne
      Gruß zurück.
    - **Nachholen in Runden (seit 2026-11-25, nach dem Review von PR #13):** Ein Gruß bekommt die
      ältesten 20 eigenen Einträge, die fehlen, und den Rest ihrer letzten Sekunde
      (`ChronicleService.OwnSince`; vorher die neuesten 20, darüber hinaus Verpasstes war für
      immer weg). Ist der letzte einer vollen Runde raus, folgt die nächste (`CatchUp`, Marke
      `more`). Eine Runde nimmt die eigenen Einträge für diesen Gefährten aus der Reihe, die noch
      warten und neuer sind als sein Stand, und reiht sie in zeitlicher Folge neu ein (`skip`).
      So geht ein Live-Eintrag, der vor dem Gruß schon in der Reihe stand, nicht vor den älteren
      raus. Bekannte Grenze (schon vorher so): Der Stand ist eine Sekunde; hat der Gefährte von
      zwei Einträgen derselben Sekunde nur einen, fehlt ihm der andere.
    - **Doppelter Gruß:** Beide Seiten grüßen meist zweimal (beim Online-Kommen und beim ersten
      Kontakt). Der Stand im Gruß wird erst beim Abschicken gelesen, je Person wartet höchstens
      ein Gruß, und ein zweiter Gruß ersetzt die noch wartenden Einträge, statt sie zu verdoppeln.
      Der zweite Gruß kostet so meist nur sich selbst und eine Bilanz.
    - **Angebote** gehen nur über Leute, die gerade nicht online sind (die sagen es selbst), und
      nicht noch einmal, solange frühere an denselben Gefährten warten oder sie weniger als 60
      Sekunden her sind (`OFFER_GAP`; seit Flüstern schneller geht, ist die Antwort auf den ersten
      Gruß meist schon raus, wenn beim ersten Kontakt der zweite kommt). Ein Gruß nach einem
      `/reload` des Gefährten bekommt sie also wieder (vorher einmal je Sitzung; ein Freund grüßt
      nicht per `P` und bekam nach seinem `/reload` keine mehr). Eine Frage `W` gilt erst als
      gestellt, wenn sie in der Reihe steht; geht der Gefragte offline oder meldet der Client
      `TargetOffline`, ist die Person wieder frei und wird beim nächsten Angebot erfragt (`Unask`).
    - **Gruß `P` nach `/reload`:** wird immer beantwortet, auch wenn der Absender noch als verbunden
      gilt (`P` geht einmal je Sitzung raus, der Absender kennt danach niemanden). Vorher blieb ein
      Gildenmitglied nach `/reload` unverbunden, und seine Meilensteine gingen an niemanden.
  - **Kein eigener Service für den Austausch** (Entscheidung des Auftraggebers, 2026-11-25),
    solange nur `sharing` Nachrichten schickt. Kommt ein zweites Feature dazu: Transport
    (Präfix, Warteschlange, Annahmeregeln) und „wer ist da“ (online, verbunden, Gruß an die Gilde)
    in einen Service unter `Core/`, das Chronik-Protokoll bleibt in `Sharing.lua`. Das
    Leitungsformat bleibt dabei gleich (Alphas sind draußen); ein neues Feature bekommt neue
    Buchstaben statt einer neuen Version, alte Versionen übergehen unbekannte Arten.
  - **Viele Nutzer (Analyse 2026-11-25, im Mock simuliert; vor dem Budget nach Bytes, die Zahlen
    für „Nachher“ gehen davon aus, dass auch Flüstern 10 plus 1 zählen):** Ein Client loggt sich ein, N
    Gildenmitglieder mit Famulus sind online, zehn weitere offline, die anderen haben seine
    Neuigkeiten bis gestern; 30 Sekunden nach dem Login steigt er auf. Die Drosselung ist wie im
    Wiki nachgebaut. Die Simulation ist ein Skript außerhalb des Repos; die Gefährten darin
    antworten ohne eigene Drosselung, die Zahlen sind also eher zu günstig.
    - **Vorher:** Famulus schickte zwei Nachrichten je Sekunde und wertete die Rückgabe nicht aus,
      was der Client ablehnte, war weg. Verloren beim Login: bei N = 1 13 von 46 Nachrichten, bei
      3 55 von 128, ab 10 lief die Reihe (200 Plätze) zusätzlich über. Der Aufstieg erreichte bei
      3 zwei, bei 5 zwei, bei 10 acht, bei 20 fünf Gefährten, der letzte nach bis zu 169 Sekunden.
      Angebote machten bei N = 10 zwei Drittel des Verkehrs aus.
    - **Nachher:** Nichts geht durch die Drosselung verloren. Der Aufstieg erreicht alle: bei 5
      nach 7, bei 10 nach 42, bei 20 nach 112, bei 40 nach 252 Sekunden. Ab 20 weist die hintere
      Spur Angebote und doppelte Bilanzen ab (bei 40: 220 und 60).
    - **Grenze des Flüsterns:** Jede Nachricht geht einzeln an jeden, nach dem Wiki mit etwa 7 je
      Sekunde (Budget nach Bytes), falls Forever Flüstern doch drosselt, mit einer. Für
      große Gilden der Weg über den Gildenkanal: Issue #12 (Live-Einträge, Bilanz und Angebote
      einmal an die Gilde; offen sind ältere Versionen und die Reihenfolge). Dort steht auch, dass
      `MAX_ENTRIES` (2000) für eigene und fremde Einträge zusammen gilt.
  - Frische Neuigkeiten erscheinen am Bildschirm über die Live-Einblendung (`liveFeed`, siehe
    unten); die frühere Option `toast` und `UI.Toast` sind entfallen.
  - **Ungeprüft im Spiel:** ob geflüsterte Addon-Nachrichten so ankommen, wie Name und Absender
    geschrieben werden (`Vorname Nachname` gegen `Vorname-Nachname`), ob ein Flüstern an jemanden,
    der gerade offline ging, eine Fehlermeldung im Chat hinterlässt, und ob die Statistik-IDs
    stimmen (aus Guildys Quellcode entnommen). Das lässt sich nur mit zwei Accounts prüfen.
    Ebenso ungeprüft: Gruß und Antwort in der Gilde und das Weiterreichen (dafür braucht es drei
    Charaktere, einer davon offline), und welche Namensform die Gildenliste in Forever liefert.
- **Verworfen:** fremde Statistiken über den Erfolgsvergleich des Spiels zu lesen, wie Guildy es
  tut. Das geht nur für das anvisierte Ziel in Sichtweite und hat bei Guildy zu Verbindungsabbrüchen
  geführt.
- **Live-Einblendung (`liveFeed`, Wunsch des Auftraggebers, 2026-11-19):** Was die Chronik gerade
  festhält, erscheint als Karte im HUD, bleibt eine Weile und blendet aus
  (`Modules/Chronicle/LiveFeed.lua`, Darstellung `UI/Feed.lua`). Im Spiel vom Auftraggeber
  ausprobiert (2026-11-19, „klappt einwandfrei“, nach der Anleitung: Beispielkarte, Verschieben
  mit `/fam feed`, Bearbeitungsmodus, Einstellungen); welche echten Ereignisse dabei ausgelöst
  wurden, ist nicht festgehalten.
  - Das Feature hört auf das interne Signal `CHRONICLE_CHANGED`, nicht auf das Spiel: kein
    Spielereignis, kein eigener Timer. Deshalb ist es **standardmäßig an** (es handelt nicht im
    Namen des Spielers und zeigt ohne Teilen nichts). Gezeigt wird nur, was höchstens 120
    Sekunden alt ist: frische Ereignisse von Gefährten (auf Wunsch auch eigene, siehe unten),
    nichts Nachgereichtes und keine Beispieleinträge.
  - **Gefährten, eigene nur auf Wunsch (Wunsch des Auftraggebers, 2026-11-24):** Die Einblendung
    zeigt von Haus aus nur, was Gefährten erleben. Die Option `own` („Auch eigene Ereignisse“,
    Standard aus) blendet die eigenen dazu ein. Der frühere Schalter `companions` (Ereignisse von
    Gefährten, Standard an) ist dafür entfallen, Entscheidung des Assistenten: Die Gefährten sind
    jetzt der Kern des Features, sie abzuschalten hieße das Feature abzuschalten, und mit beiden
    Schaltern aus wäre das Feature an, zeigte aber nichts. Wer einen der beiden Fälle will (nur
    eigene), kann es nicht mehr; falls das fehlt, nachfragen. Mit Standardwerten erscheint erst
    etwas, wenn „Mit Freunden teilen“ (`sharing`) oder „Freunde begleiten“ (`companions`) läuft.
    Ein gespeicherter Wert des alten Schalters bleibt ungenutzt im Profil, bis „Zurücksetzen“ ihn
    entfernt. Nur gegen den Mock geprüft.
  - Schalter je Ereignisart (`level`, `death`, `boss`, `achievement`, `ability`, `item`,
    `profession`, `skill`, `zone`); nur `zone` ist von Haus aus aus (Vorgabe des Auftraggebers:
    Gebiete eher nicht, Stufenaufstiege schon). Dazu `own` (auch eigene Ereignisse, Standard aus)
    und `duration` (4, 7 oder 12 Sekunden). Eine Art ohne Schalter (neuere Version beim Gefährten)
    bleibt unsichtbar. Eine neue Art braucht einen Eintrag in `KINDS` und ihre zwei Texte.
  - Die Karte nutzt die Bilder des Buchs (`UI.BookPictures`, `UI.ChronicleStory`): Symbol, Zahl
    oder Gegenstandssymbol. Höchstens drei Karten untereinander, die neueste oben; sie fangen die
    Maus nicht.
  - **Form „Wappen auf dem Band“ (vom Auftraggeber am Mockup gewählt, 2026-11-19, Entwurf B1):**
    Das Bild ist ein eckiges Wappen (72 px, Ecken 14, Rand zwei Pixel in der Farbe der Art) und
    steht mittig auf einem Band (56 px hoch), 14 px vom linken Bandende; es ragt oben und unten je
    8 px heraus. Seine Vorgaben: Das Bild ist größer als die Fläche hinter dem Text, links vom
    Wappen bleibt Band sichtbar, und das Band darf gegenüber dem Wappen nicht zu schmal sein.
    Verworfen: Medaillon (rund, Text schiebt sich darunter hervor), Banner (Bild mittig über
    zentriertem Text), ein Wappen, das nur nach oben ragt (B2), und das erste Wappen mit 40 px
    hohem Band ohne Rand links. Das Band ist so breit, wie sein Text braucht (230 bis 460 px);
    die Karten stehen linksbündig übereinander (Vorgabe des Auftraggebers), nicht mittig;
    Meilensteine (`story.big`) tragen Akzentrand und Marke (siehe unten). Das Wappen im Spiel gesehen (Auftraggeber bat danach um linksbündige Karten).
  - **Wappen im Band (Entscheidung des Auftraggebers, 2026-11-19, nach dem Blick ins Spiel):** Das
    Wappen ragt nicht mehr über das Band hinaus, sondern steht darin (Band 64 px hoch, Wappen
    48 px); die Lücke von 14 px links vom Wappen bleibt. Im Spiel gesehen und bestätigt („so ist
    gut“). Die Angaben zum Überstand im Absatz
    darüber sind damit überholt.
  - **Aussehen wie die Options-Karten (Wunsch des Auftraggebers, 2026-11-19):** Die Karte eines
    Ereignisses im Buch und das Band der Einblendung sind gebaut wie die Karte eines Features im
    Fenster (`CreateCard` in `UI/Options.lua`): Grund `card` mit Haarlinie und Lichtkante; was
    heraussticht (dort ein laufendes Feature, hier ein Meilenstein), hat Akzentrand `cardActive`
    und die Akzentmarke links. Der Schein hinter Meilensteinen ist dafür entfallen. Im Buch
    zusätzlich: Überschrift 13 px medium wie die Zeilen, das Leuchten unter der Maus (`hover`)
    bei klickbaren Karten, und „wessen Ereignis“ steht in einem vertieften Streifen unten
    (`sunken`, wie eine Option unter ihrem Feature) statt als Marke im Text. Die Einblendung
    trägt dazu den Grund des Fensters: Körnung, die nach unten ausläuft (`UI.Grain`), und die
    Abdunklung nach unten (`dusk`). Was „an den Options-Boxen orientieren“ genau heißen sollte,
    hat der Assistent so ausgelegt; vom Auftraggeber im Spiel noch nicht gesehen.
  - **Der eigene Stufenaufstieg wird nicht eingeblendet** (Entscheidung des Auftraggebers,
    2026-11-19): Das Spiel zeigt ihn selbst groß an. Er steht weiter in der Chronik; der Schalter
    „Stufenaufstiege“ gilt nur für Gefährten. Das bleibt so, auch wenn `own` an ist.
  - **Offen (2026-11-19):** Beim Aufstieg auf Stufe 20 hat der Auftraggeber keine Karte gesehen
    („glaube ich“). Der Eintrag stand korrekt in den gespeicherten Daten, die Einblendung war an,
    Dauer 4 Sekunden, Platz rechts der Mitte. Ob die Karte nicht kam oder übersehen wurde, ist
    ungeklärt. Seitdem schreibt das Feature im Entwicklermodus je Karte eine Zeile ins `devLog`
    (`FEED`, „shown: <art>“ oder „failed: …“; `ns:DevLog`), ohne Namen oder Text.
  - **Platz:** Standard oben in der Mitte; gespeichert accountweit in `FamulusDB.feed` wie die
    Fensterposition. Verschieben im Bearbeitungsmodus des Spiels oder mit `/fam feed`
    (`/fam feed reset` setzt zurück, `/fam feed test` zeigt eine Beispielkarte): Dann zeigt ein markiertes Feld den Platz und lässt sich
    ziehen. Vorbild ist FlareUI, das dafür eine Abspaltung von LibEditMode mitbringt
    (`Libs/FlareEditMode`). Famulus übernimmt nur den Kern: `HookScript` auf `OnShow`/`OnHide`
    von `EditModeManagerFrame`, über `feature:HookScript`. Nicht übernommen: Einrasten am Raster,
    Einstellungsdialog im Bearbeitungsmodus, Position je Blizzard-Layout; die Bibliothek ruft
    dafür Methoden des Managers auf und vermerkt dabei selbst Taint. Ob der Haken im
    Forever-Client ohne Meldung bleibt, ist im Spiel ungeprüft.
- **Klasse und Name (Wunsch des Auftraggebers, 2026-11-24; nur gegen den Mock geprüft):** Neben
  dem Namen eines Freundes stand ein Kreis mit dem Anfangsbuchstaben; jetzt steht dort das
  Klassensymbol des Spiels (`UI-Classes-Circles`, `UI.ClassIcon`/`UI.SetClass` in
  `UI/Widgets.lua`, die auch das Wappen der Weggefährten nutzt): im Streifen unter einer Karte des
  Buchs und in der Randspalte (Liste „Freunde“, Bilanz-Karten). Ist die Klasse unbekannt, bleibt
  der Buchstabe. Hinter einem Alias steht der Charaktername in Klammern, „Papa (Borin Eisenbart)“
  (`ChronicleService.Label`), überall, wo die Chronik die Person nennt: Streifen, Randspalte,
  Filterzeile „Nur Ereignisse von …“ und die Sätze der Live-Einblendung. Ohne Alias steht nur der
  Name.
  - **Option** „Charaktername hinter dem Alias“ (`general.chronicleNames`, Standard an) als eigene
    Karte „Anzeige“ unter Chronik › Einstellungen, unter den Features. Aus: nur der Alias. Die
    Option gilt nur für die Klammern; das Klassensymbol hat keinen Schalter (vom Auftraggeber
    bestätigt, 2026-11-24).
  - **Der Charaktername steht nicht mehr in der Zeile unter der Überschrift** („Jaina Proudmoore ·
    in Duskwood“ war der frühere Platz unter einem Alias). Entscheidung des Assistenten: Mit der
    Option an stünde er sonst doppelt da, und wer die Option ausschaltet, will ihn nicht sehen.
    Ebenso entfällt er als zweite Zeile der Bilanz-Karten.
  - **Woher die Klasse kommt** (`FamulusDB.chronicle.classes = { [name] = "MAGE" }`, über
    `ChronicleService.Class`): Freunde mit Famulus schicken ihre Klasse mit der Bilanz (`1~S~…`,
    siehe „sharing“); „Freunde begleiten“ merkt sie aus der Freundesliste, wenn es einen Aufstieg
    festhält (`className` in der Sprache des Clients, zurückübersetzt über
    `LOCALIZED_CLASS_NAMES_MALE`/`_FEMALE`, `SocialService.ClassFromName`); die eigenen
    Charaktere tragen ihre Klasse mit jedem eigenen Eintrag und beim Login ein (nur, wenn es die
    Chronik schon gibt). Die Beispieldaten haben Klassen wie bei den Weggefährten (Mira Magierin,
    Borin Krieger, Lysa Priesterin). Gespeichert wird nur für Personen mit Eintrag oder Bilanz; der
    Rest fällt beim Laden heraus. Die Daten der Weggefährten werden bewusst nicht gelesen (siehe
    „Chronik und Weggefährten“: jeder Bereich steht für sich).
  - **Gildenliste und Freundesliste als Quelle (Wunsch des Auftraggebers, 2026-11-24, eigener PR;
    nur gegen den Mock geprüft):** Zeigt das Fenster „Alle“ oder „Freunde“ der Chronik, sieht es
    einmal in Freundesliste und Gildenliste (`SocialService.Classes`, gebaut wie
    `SocialService.Online`) und merkt sich die Klassen der Personen der Chronik
    (`ChronicleService.LearnClasses`). Die Gildenliste nennt die Klasse jedes Mitglieds, auch
    offline, schon in der Form `MAGE` (elfter Wert von `GetGuildRosterInfo`, von
    `SocialService.EachGuildMember` als fünfter Wert weitergegeben); die Freundesliste nur für
    Freunde, die online sind. Online/offline der Randspalte kommt weiter aus
    `ChronicleService.OnlineCheck`; das sind zwei Blicke in die Listen je Aufbau, bewusst nicht
    zusammengelegt, damit `SocialService` bei je einer Frage je Funktion bleibt. Das geschieht im
    Aufbau des Reiters vor Buch und Randspalte, die
    Klasse ist also sofort zu sehen. Kein Spielereignis, kein Timer: Ohne offenes Fenster läuft
    dafür nichts. Gemerkt wird nur für Personen mit Eintrag oder Bilanz, „Meine Reise“ sieht nicht
    nach. Ungeprüft im Spiel: ob der Client die Gildenliste nach dem Login von selbst lädt (sonst
    erst, wenn „Mit Freunden teilen“ sie anfordert oder das Gildenfenster offen war).
  - **Lücken:** Ein Freund mit älterem Famulus, nicht in der Gilde, der weder seit dem Update
    aufgestiegen ist noch bei offenem Fenster online war, zeigt weiter den Buchstaben.
  - Die Website zeigt im Buch der Chronik noch Anfangsbuchstaben.
- **Die drei aufzeichnenden Features sind standardmäßig aus**, weil der Test festschreibt, dass mit Standardwerten
  kein Spielereignis registriert ist. Ob die Chronik von Haus aus mitschreiben soll, ist eine
  offene Entscheidung des Auftraggebers.
- **Was der Client hergibt (recherchiert 2026-11-19 im UI-Quellcode, Branch `forever`, und im Wiki;
  nichts davon im Spiel geprüft):**
  - Ohne Zutun des Freundes sind nur Stufe, Gebiet und Online-Status sichtbar (Freundesliste,
    Battle.net, Gildenliste). Tode, Bosse, Beute und Erfolge anderer nicht.
  - Addon-Nachrichten gibt es (`C_ChatInfo.SendAddonMessage`, 255 Bytes, gedrosselt). Laut den
    Messungen des Addons BFF kommen auf Forever WHISPER und PARTY an, CHANNEL nicht. In
    Bosskämpfen und gesperrten Karten wird nichts gesendet und Empfangenes verworfen; nichts wird
    nachgeliefert, wenn jemand offline war.
  - Das Kampflog ist für Addons gesperrt: Es gibt keine Todesursache.
  - Erfolge heißen in Forever „Legacy-Herausforderungen“; `ACHIEVEMENT_EARNED` und
    `GetAchievementInfo` existieren.
  - Tod eines Gruppenmitglieds über `UnitIsDeadOrGhost`, nicht über `UnitHealth` (geheim).
  - Bilder: Klassen- und Volkssymbole, Gegenstandssymbole, Kartengrafik; Porträt und 3D-Modell
    nur für anwesende Einheiten; keine Screenshots im Fenster.
- **Ähnliche Addons:** „BFF – Best Friends in Forever“ hat bereits einen Freundes-Feed mit
  Stufenaufstiegen und Toden über ein Flüster-Netz zwischen den Addons; „Guild Chronicle“ ein
  Gilden-Todesbuch in Pergament-Optik. Die Daten allein sind also kein Alleinstellungsmerkmal; die
  Chance liegt in der Aufbereitung und in der Verbindung mit den Aliasen.

## Aliase

Eigene Namen für andere Spieler, Vorbild ist das Addon CustomNames
(`github.com/Jods-GH/CustomNames`, unterstützt Forever). Entscheidungen des Assistenten vom
2026-11-16, vom Auftraggeber noch nicht bestätigt:

- **Eigene Kategorie `aliases`** mit Hauptschalter, als eigener Bereich in der Seitenleiste (seit
  2026-11-18, siehe „Das Fenster“). Reiter „Namen“: Eingabezeile (Charaktername, Alias,
  „Speichern“) und je Alias eine Zeile (Klick lädt sie in die Eingabezeile, das Kreuz entfernt
  sie); Reiter „Einstellungen“: die Features. Die Suche findet Aliase und Charakternamen.
- **Daten, keine Einstellung:** `FamulusDB.aliases = { [schlüssel] = { name, alias } }`, accountweit,
  außerhalb der Profile; „Zurücksetzen“ und Profilwechsel lassen die Liste in Ruhe. Zugriff nur
  über `ns.AliasService` (`Modules/Aliases/AliasService.lua`); Änderungen melden sich mit dem Signal
  `ALIASES_CHANGED`.
- **Schlüssel:** voller Charaktername, klein geschrieben, Leerzeichen und Bindestriche zu „-“. Forever
  hat keine Realms, sondern Vor- und Nachname (`UnitName` liefert `name, surname`); der Client
  schreibt denselben Namen je nach Stelle mit Leerzeichen oder Bindestrich. Welche Schreibweise der
  Chat liefert, ist unbestätigt, deshalb die Normalisierung; der Selbsttest (Gruppe `names`) hält
  Trennzeichen und Form von `UnitName("player")` fest, ohne einen Namen zu speichern.
- **Alias ist reiner Text:** `|` wird entfernt (keine Farben, Texturen, Links), höchstens 48 Bytes.
- **`chatAliases`:** `ChatFrameUtil.AddSenderNameFilter` ändert nur den Text in den Klammern; das
  Linkziel bleibt der echte Name. Der Filter lässt sich entfernen (`RemoveSenderNameFilter`), der
  Client überspringt ihn bei secret Namen selbst. Nicht `AddMessageEventFilter` (würde auch das
  Linkziel ändern) und kein Hook auf `AddMessage` (CustomNames ersetzt dort die Methode). Schon
  gedruckte Zeilen ändern sich nicht. Option `style`: „Alias“ oder „Alias (Name)“.
- **`tooltipAliases`:** eigene Zeile über `TooltipDataProcessor` (Typ `Unit`), nur für Spieler; die
  Namenszeile des Spiels wird nicht überschrieben.
- **`aliasMenu`:** `Menu.ModifyMenu` auf die Spieler-Menüs (`aliasMenu.TAGS`), fügt „Alias
  festlegen/ändern/entfernen“ an. „Festlegen“ öffnet das Fenster auf der Seite mit eingetragenem Namen
  (`ns:EditAlias`); kein eigener Dialog und kein Eintrag in `StaticPopupDialogs`. Im Forever-Client
  trägt `contextData` `name` und `surname`, kein `server`.
- **Alle Alias-Features sind standardmäßig an:** Sie handeln nicht im Namen des Spielers und tun ohne Alias
  nichts; sie brauchen keinen Timer und, außer `accountAliases` bei vorhandenem Account-Alias,
  kein Spielereignis.
- **Andere Addons (Entscheidung des Auftraggebers, 2026-11-18):** gezielt unterstützen, keine
  öffentliche Schnittstelle (Famulus ist zu unbekannt, als dass andere sie einbinden würden).
  Je Anbindung ein Feature `Modules/Aliases/<Addon>Aliases.lua` mit `addon = "<Ordnername>"`: Ohne
  das Addon bleibt es aus und fehlt im Fenster; `## OptionalDeps` in der `.toc` lädt das Addon
  zuerst. Nur über dessen offizielle Erweiterungspunkte, nichts ersetzen. Weitere stehen noch nicht
  fest. Eine Automatik für alle Addons gibt es nicht ohne `AddMessageEventFilter` (ändert das
  Linkziel) oder überschriebene Methoden (Taint).
- **`guildyAliases` (2026-11-18, im Spiel bestätigt):** Guildy
  (`github.com/svengabr/Guildy`) baut seinen Chat selbst, der Absenderfilter erreicht ihn nicht, und
  es hatte keinen Erweiterungspunkt. Deshalb ein PR an Guildy (Branch `name-formatter-api` im Fork
  `89pleasure/Guildy`): `GuildyAPI.RegisterNameFormatter(owner, fn)`,
  `UnregisterNameFormatter`, `Refresh`; Guildy fragt den Formatter in `W.ClassName`, Links behalten
  den echten Namen. Das Feature meldet dort einen Formatter an (Option `style` wie im Chat) und ruft
  bei `ALIASES_CHANGED` `Refresh`. Entscheidung des Auftraggebers (2026-11-18): Der PR wird erst
  eingereicht, wenn Famulus veröffentlicht werden soll; bis dahin wird mit dem Fork gearbeitet.
  Das installierte Guildy im Spielordner ist ein Klon des Branches (Remotes `fork` und `upstream`).
  Aktuell halten: dort `git fetch upstream && git rebase upstream/main`, Tests (`luajit
  tests/run.lua`), dann `git push --force-with-lease fork name-formatter-api`. Mit dem normalen
  Guildy fehlt das Feature einfach. Im Spiel bestätigt: Aliase
  erscheinen in Guildy. Ein früherer Test per `/run` mit einem eigenen Formatter zeigte nichts;
  die Ursache wurde nicht geklärt, die Anbindung selbst funktioniert.
- **Alias für einen Battle.net-Account (Wunsch des Auftraggebers, 2026-11-23, nach dem Vorbild von
  CustomNames; nur gegen den Mock geprüft, noch nicht im Spiel):** Ein Alias am BattleTag gilt für
  alle Charaktere des Freundes, man muss nicht je Charakter einen anlegen. Aufbau und Grenzen sind
  Entscheidungen des Assistenten:
  - **Daten:** `FamulusDB.accountAliases = { [battletag klein] = { tag, alias, chars = { [schlüssel]
    = "Vorname Nachname" } } }`, accountweit, außerhalb der Profile. Gespeichert werden nur Accounts
    mit Alias (keine Sammlung aller Battle.net-Freunde). `AliasService.Set` und `GetOwn` nehmen
    Charaktername oder BattleTag (`Name#1234`; ein Charaktername enthält nie „#“).
    `AliasService.Get(name)` liefert den eigenen Alias des Charakters, sonst den seines Accounts:
    **Der Alias am Charakter hat Vorrang** (wie bei CustomNames). Chat, Tooltip, Guildy und Chronik
    brauchen dafür keine Änderung.
  - **Woher die Charaktere kommen:** Der Client verrät nur, mit welchem Charakter ein
    Battle.net-Freund gerade online ist (`C_BattleNet.GetFriendAccountInfo(i).gameAccountInfo`,
    dazu `GetFriendNumGameAccounts`/`GetFriendGameAccountInfo` für weitere Lizenzen; nur
    `wowProjectID == WOW_PROJECT_ID`). `AliasService.ScanFriends` liest die Liste und merkt sich
    die Charaktere dauerhaft. Ein Charakter, mit dem der Freund nie online gesehen wurde, hat
    den Alias also noch nicht. Beim Setzen eines Account-Alias wird einmal sofort gelesen.
  - **Feature `accountAliases`** (`Modules/Aliases/AccountAliases.lua`, Standard an): lauscht auf
    `BN_FRIEND_INFO_CHANGED` (nennt den Platz in der Liste, dann wird nur dieser Freund gelesen),
    `BN_FRIEND_ACCOUNT_ONLINE` und `BN_CONNECTED`, aber **nur, solange mindestens ein Account einen
    Alias hat**. Mit Standardwerten ist deshalb weiter kein Spielereignis registriert; das ist die
    Begründung, warum es trotz Spielereignissen standardmäßig an ist. Abgeschaltet gelten
    Account-Aliase weiter für die schon bekannten Charaktere.
  - **Fenster:** Das Namensfeld nimmt „Charakter oder BattleTag#1234“. Ein Account steht in der
    Liste mit „Battle.net · Tag · seine Charaktere“ (oder „noch kein Charakter gesehen“); die Suche
    findet ihn auch über einen Charakter.
  - **Kontextmenü:** zusätzlich `MENU_UNIT_BN_FRIEND` und `MENU_UNIT_BN_FRIEND_OFFLINE`
    (`contextData.battleTag`, sonst `contextData.accountInfo.battleTag`, so setzt es
    `FriendsFrame_ShowBNDropdown` im Forever-Quellcode). Einträge „Alias für alle Charaktere
    festlegen/ändern/entfernen“. Im Menü eines Charakters erscheinen sie zusätzlich, wenn er zu
    einem Account mit Alias gehört oder ein Battle.net-Freund gerade mit ihm online ist
    (`AliasService.FindBattleTag` geht dafür beim Öffnen des Menüs die Freundesliste durch).
  - **Nicht enthalten:** Charaktere von Hand einem Account zuordnen oder wieder lösen (CustomNames
    kann beides), ein Alias für den eigenen Account, Aliase vor Battle.net-Flüstern (dort steht
    ohnehin der Account-Name). Ein gemerkter Charakter bleibt beim Account, bis dessen Alias
    entfernt wird, auch wenn der Freund ihn löscht.
  - **Im Spiel ungeprüft:** ob `characterName` in Forever Vor- und Nachname enthält und mit
    welchem Trennzeichen (der Schlüssel gleicht Leerzeichen und Bindestrich an), ob
    `wowProjectID` für Forever-Charaktere gleich `WOW_PROJECT_ID` ist, die Argumente der drei
    Ereignisse und die beiden Menü-Tags. `/fam test` meldet dazu (Gruppe `names`, „Battle.net
    friends“), wie viele Freunde auf einem Charakter dieses Spiels sind und wie die Namen
    geschrieben werden, ohne einen Namen zu speichern.
- **Bewusst nicht enthalten:** Aliase auf Blizzards Unitframes, Raidframes und Namensplaketten
  (CustomNames überschreibt dort `SetText` auf Blizzards FontStrings, Taint-Risiko, Namen im Kampf
  secret), Gildenliste, Import/Export, Slash-Befehl zum Eintragen.

## Chronik und Weggefährten

Am 2026-11-24 hat der Auftraggeber gefragt, ob es Sinn ergibt, beide getrennt zu führen. Bewertung
des Assistenten: getrennt lassen, denn sie unterscheiden sich in der Grundlage. Die Chronik lebt
von eigenen Ereignissen und dem, was Freunde mit Famulus schicken (Freundesliste und Gilde,
teilt Daten); die Weggefährten von der Gruppenliste (jeder aus einer Gruppe, auch Fremde, nichts
wird verschickt, bis 500 Personen; seit 2026-11-24 auf Wunsch nur Freunde und Gilde). Sie waren aber an vier Stellen ineinander gewachsen: dasselbe
Wort „Gefährten“ für zwei Personenkreise, zwei „Steckbriefe“, zwei Bücher je Person mit teils
denselben Karten, und die Bossnamen der Weggefährten kamen aus der Chronik. Von drei Varianten
(klare Kante; Weggefährten als einziger Ort für Personen; zusammenlegen) hat der Auftraggeber
**„Klare Kante“** gewählt. Die Regel seitdem:

- **Die Chronik erzählt, was passiert ist; die Weggefährten zeigen, mit wem du spielst und wie
  nah ihr euch seid.** Nichts, was der eine Bereich zeigt, wird im anderen wiederholt; sie
  verweisen aufeinander.
- **Namen:** Die Personen der Chronik heißen im Fenster „Freunde“ (Reiter, Randspalte, Feature
  „Freunde begleiten“, Texte der Live-Einblendung), „Gefährten“ steht nur noch bei den
  Weggefährten („Engste Gefährten“). Die geteilten Zahlen heißen „Bilanz“ (enUS „Stats“), nicht
  mehr „Steckbrief“. Im Code bleiben `companions`, `ui_tab_companions`, `c_profiles` usw.
- **Zwei Bücher je Person mit verschiedenen Fragen:** Chronik › Freunde, gefiltert auf eine
  Person, zeigt ihre eigene Reise; „Eure Geschichte“ bei den Weggefährten nur das Gemeinsame
  (Tage zusammen, gemeinsame Bosse, Verbundenheit, Kennenlernen). Die Einträge „aus <Name>s
  Chronik“ dort sind entfallen. Verweise: „In der Chronik“ auf der Karte der Person,
  „Eure Geschichte“ über dem gefilterten Buch der Chronik; beide nur, wenn der andere Bereich
  eingeschaltet ist und die Person kennt.
- **Jeder Bereich steht für sich:** Die Weggefährten merken sich die Namen gemeinsamer Bosse
  selbst (`k` im Tagesprotokoll) und lesen die Chronik nur noch für den Verweis.
- Umsetzung und Begriffe sind Entscheidungen des Assistenten im Rahmen der Variante („Freunde“,
  „Bilanz“, „Stats“, „In der Chronik“, Bosse nur in Gruppen mit Namen). Nur gegen den Mock
  geprüft, im Spiel noch nicht gesehen. Die Website zeigt noch den alten Stand (Reiter
  „Gefährten“, „Steckbriefe“).
- **Ideen, die nur die Weggefährten können:** Stammgruppen (wer immer wieder gemeinsam in der
  Gruppe ist) stehen seit 2026-11-24 im Reiter „Runden“ (siehe „Weggefährten“); gemeinsame
  Dungeons je Person sind vorgeschlagen, nicht beauftragt. Auch die Runden halten sich an die
  Regel: Sie zeigen,
  wer mit wem wann unterwegs war, nicht, was dabei geschah (keine Tode, keine eigenen Stufen,
  Bosse nur als Zahl).

## Weggefährten

Idee aus einer Ideensammlung des Assistenten (2026-11-23), vom Auftraggeber ausgewählt: Famulus merkt
sich, mit wem der Spieler in einer Gruppe war. Begründung: Forever hat „Zuletzt zusammen gespielt“
nicht (siehe oben), und die Funktion braucht beim anderen kein Famulus.

- **Entscheidungen des Auftraggebers (2026-11-23):** eigener Bereich (nicht als
  Unterbereich von Aliasen oder Chronik; ein Eintrag in der Seitenleiste). Erste Version: die Liste (wer, wann, wo, wie oft, wie lange)
  und Boss-Einträge der Chronik, die nennen, wer dabei war. **Nicht** gewählt: Notizen zu Personen,
  Hinweis im Tooltip, Knopf „Freund hinzufügen“. Nicht einbauen, ohne zu fragen.
- **Aufbau:** Kategorie und Bereich `fellows`, ein Feature `rememberFellows`
  (`Modules/Fellows/RememberFellows.lua`, Standard aus, weil es auf Spielereignisse lauscht), Daten
  über `ns.FellowService` (`Modules/Fellows/FellowService.lua`). Wer gerade in der Gruppe ist, liefert
  `ns.GroupService` (`Core/GroupService.lua`), den auch die Chronik nutzt.
- **Daten:** `FamulusDB.fellows = { [guid] = { name, level, class, first, firstZone, last, zone,
  times, seconds, bosses, tag } }`, accountweit, außerhalb der Profile, nach GUID (ein Name kann sich
  ändern). `tag` ist der BattleTag, wenn die Person in der Gruppe als Battle.net-Freund erkannt
  wurde (seit 2026-11-24, siehe unten). Nichts davon wird verschickt. Höchstens 500 Personen; darüber fällt heraus, wer am
  längsten nicht mehr dabei war (nie jemand aus der aktuellen Gruppe). Dazu seit 2026-11-24 die
  Runden in `FamulusDB.fellowRuns` (siehe „Runden“).
- **Zählen (Entscheidungen des Assistenten):**
  - Ereignisse: `GROUP_ROSTER_UPDATE` und `PLAYER_ENTERING_WORLD` gleichen die Liste mit der Gruppe
    ab, `BOSS_KILL` zählt einen Boss für alle Anwesenden, `PLAYER_LOGOUT` beendet alle Zeiten
    (die gespeicherten Daten werden danach geschrieben, auch bei `/reload`). Kein Timer: Die Zeit
    wird bei jedem Abgleich und beim Ausloggen aufaddiert; nur der Teil seit dem letzten Abgleich
    geht bei einem Absturz verloren.
  - Ein neues „Mal zusammen“ beginnt erst nach 30 Minuten Pause (`MEET_GAP`); ein Verbindungsabbruch
    oder `/reload` zählt nicht doppelt.
  - Nicht gezählt: Mitglieder, die offline sind (`UnitIsConnected`), Namen, die der Client noch nicht
    kennt (`UNKNOWNOBJECT`), Schlachtfelder und Arenen (`IsInInstance` liefert `pvp`/`arena`).
    Schlachtzüge zählen mit; Option `raids` (Standard an) schaltet sie ab.
  - „Wo“ ist das Gebiet des Spielers (`GetRealZoneText`), nicht das des Mitglieds.
- **Nur Freunde und Gilde, Aufräumen (Wunsch des Auftraggebers, 2026-11-24):** Anlass: Die Chronik
  hört nur von Freunden und Gildenmitgliedern, die Weggefährten merkten sich jeden aus einer Gruppe.
  Gewünscht waren eine Option dafür und ein Aufräumen für ehemalige Freunde und Gildenmitglieder.
  Umsetzung und Texte sind Entscheidungen des Assistenten.
  - **Option `friendsOnly`** („Nur Freunde und Gilde“, Standard aus, damit sich am bisherigen
    Verhalten nichts ändert): Aus der Gruppe zählt dann nur, wer auf der Freundesliste steht,
    Battle.net-Freund ist oder in der Gilde ist (`SocialService.Unit`: `C_FriendList.IsFriend(guid)`,
    `C_BattleNet.GetAccountInfoByGUID(guid)`, `UnitIsInMyGuild(unit)`; alle drei laut API-Doku des
    Branches `forever` vorhanden und nicht geheim; die beiden ersten laufen über `pcall`, weil
    `IsFriend` die geladene Freundesliste verlangt). Solange die Option an ist, hört das Feature
    zusätzlich auf `FRIENDLIST_UPDATE`, `PLAYER_GUILD_UPDATE`, `BN_FRIEND_LIST_SIZE_CHANGED` und
    `BN_CONNECTED` (alle vier registriert auch Blizzards Freundesfenster im Forever-Quellcode,
    `Blizzard_FriendsFrame/Camelot`): Wer in der Gruppe zum Freund oder Battle.net-Freund wird,
    zählt ab da, wer es nicht mehr ist, ab da nicht mehr. Wer schon in der Liste steht, bleibt dort.
    Nicht auf `BN_FRIEND_INFO_CHANGED`, das bei jeder Statusänderung eines Freundes kommt. Ohne die
    Option fragt der Abgleich nur den BattleTag ab (`SocialService.BattleTag`), nicht, wer Freund
    ist.
  - **Battle.net-Freunde zählen als Freunde** (Entscheidung des Assistenten): Die Freundesliste des
    Spiels zeigt sie mit, und der Auftraggeber hat Battle.net-Freunde (siehe Account-Aliase). Die
    Chronik kann mit ihnen nicht sprechen, sie flüstert nur Charakternamen an. Als Battle.net-Freund
    gilt nur, wen der Client ausdrücklich so nennt (`isFriend` oder `isBattleTagFriend` wahr; laut
    API-Doku des Branches `forever` sind beide nie nil). Im Zweifel ist jemand kein Freund, und sein
    BattleTag wird nicht gemerkt.
  - **Aufräumen** (Reiter „Einstellungen“, eigene Karte unter dem Feature): entfernt alle, die
    gerade weder auf der Freundesliste noch Battle.net-Freund noch in der Gilde sind, also auch
    Fremde aus der Zeit ohne die Option. Entscheidung des Assistenten: „ehemalig“ lässt sich für
    ältere Einträge nicht feststellen, weil nie gemerkt wurde, wer damals Freund war, und wer nur
    Freunde will, will die Fremden auch nicht. Wer gerade in der Gruppe ist, bleibt, auch ein
    Fremder, den die Option gerade nicht mitzählt (`GroupService.Members`, nicht nur die gezählten);
    die Beispiel-Weggefährten gehen mit (sie sind niemandes Freund). Die Zeile heißt deshalb „Alle
    außer Freunden und Gilde entfernen“ / „Remove everyone but friends and guild“; die erste
    Fassung („Ehemalige Freunde und Gildenmitglieder entfernen“) versprach weniger, als der Knopf
    tut (Review 2026-11-24, vom Auftraggeber zum Beheben freigegeben). Soll das Aufräumen doch nur
    ehemalige Freunde treffen, müsste Famulus sich ab jetzt merken, wer Freund war; nachfragen.
    Die Zeile nennt bis zu fünf Namen
    (Alias, sonst Name) und zählt den Rest; der Knopf „Entfernen“ fragt wie „Zurücksetzen“ erst
    („Wirklich entfernen?“, vier Sekunden). Der erste Klick merkt sich, wen die Zeile gezählt hat;
    der zweite entfernt nur diese, und nur, wenn sie beim frischen Nachsehen noch immer fremd sind.
    Wer dazwischen in die Liste kommt, bleibt. Geht auch bei ausgeschaltetem Feature, weil es nur
    gespeicherte Daten betrifft. Eine Chat-Zeile sagt, wie viele es waren. Die Suche findet die
    Zeile über ihren Namen, nicht über die Namen darin. Die Listen werden erst gelesen, wenn die
    Zeile gezeigt wird, nicht schon beim Aufbau der Reiter (das tut die Suche bei jeder Taste für
    alle Reiter). Technik: Zeilenart `action` in
    `UI/Options.lua` (Knopf rechts; `item.button`, `confirm`, `armed`, `usable`, `click`, dazu
    `item.find` für die Suche), `FellowService.Outsiders` und `RemoveOutsiders`.
  - **Abgleich** (`SocialService.Circle`): ein Blick auf Freundesliste, Gildenliste
    (`GetGuildRosterInfo`, 17. Wert GUID) und Battle.net-Freunde; erkannt wird nach GUID, nach Name
    (jede Schreibweise, ohne Realm) und nach BattleTag. Offline sind Battle.net-Freunde nur am
    BattleTag zu erkennen (der Client nennt ihren Charakter nur, solange sie online sind). Deshalb
    merkt sich die Liste den BattleTag (`tag`), sobald jemand in der Gruppe als Battle.net-Freund
    erkannt wird, unabhängig von der Option. Ein alter `tag` bleibt stehen und passt dann einfach
    nicht mehr. Grenze: Wer seit dieser Version nicht mehr in der Gruppe war, hat keinen `tag`; ist so
    jemand nur Battle.net-Freund und gerade offline, hielte das Aufräumen ihn für fremd. Die Namen in
    der Zeile zeigen das vor dem Klick. Das widerspricht nicht der Regel, keine Battle.net-Freunde zu
    sammeln (siehe Aliase): Gemerkt wird der BattleTag nur bei Personen, die ohnehin in der Liste
    stehen.
  - **Eine Liste fehlt noch** (Review 2026-11-24: vorher wartete das Aufräumen nur auf die
    Gildenliste, eine leere Freundesliste oder ein getrenntes Battle.net hätte alle Freunde zu
    Fremden gemacht): `SocialService.Circle` liefert dann `ready = false` und als dritten Wert,
    worauf es wartet. Das Aufräumen zeigt den Grund statt der Namen, der Knopf ist aus:
    - `friends`: Die Freundesliste ist leer und seit dem Login kam noch kein `FRIENDLIST_UPDATE`
      („Deine Freundesliste wird noch geladen.“). Angefragt mit `C_FriendList.ShowFriends`. Eine
      leere Liste gilt erst als echt, wenn der Client sie geschickt hat; hat sie Einträge, gilt sie
      sofort.
    - `guild`: in einer Gilde, aber `GetNumGuildMembers()` liefert 0 („Deine Gildenliste wird noch
      geladen.“). Angefragt mit `C_GuildInfo.GuildRoster`.
    - `battlenet`: `BNConnected()` liefert falsch; ohne Verbindung kennt der Client keine
      Battle.net-Freunde („Battle.net ist gerade nicht verbunden …“). Gewartet wird auf
      `BN_CONNECTED`, anfragen lässt sich nichts.
    Angefragt wird höchstens alle 15 Sekunden; das Ereignis bleibt angemeldet, bis es kommt, dann
    baut sich das Fenster neu (`SOCIAL_CHANGED`). Der zweite Klick sieht noch einmal frisch nach:
    Fehlt dann eine Liste (etwa Battle.net in der Zwischenzeit weg), geht niemand, und die Zeile
    nennt den Grund.
  - **Im Spiel ungeprüft:** alles. Vor allem, ob die Gildenliste in Forever auch Mitglieder führt,
    die offline sind, und mit GUID (sonst hielte das Aufräumen sie für fremd). Das meldet
    `/fam test` (Gruppe `names`, „guild roster“ und „friends list“, nur Zahlen, keine Namen; dazu
    Gruppe `api`). Außerdem, ob `C_BattleNet.GetAccountInfoByGUID` für Battle.net-Freunde in der
    Gruppe antwortet (sonst zählt mit der Option kein reiner Battle.net-Freund), ob
    `C_FriendList.ShowFriends` auch bei leerer Freundesliste ein `FRIENDLIST_UPDATE` auslöst (sonst
    bliebe das Aufräumen bei „wird noch geladen“) und ob `BNConnected` in Forever antwortet.
- **Secret Values (recherchiert 2026-11-23 in der API-Doku des Branches `forever`):** `UnitName`,
  `UnitGUID` und `UnitClass` sind nur geheim, wenn die Einheit nicht spielergesteuert oder nicht in
  der Gruppe ist (`SecretWhenUnitIdentityRestricted`); für Gruppenmitglieder also auch im Kampf
  lesbar. `UnitLevel` ist nie geheim. Geprüft wird trotzdem jeder Wert. Den eigenen Charakter im
  Schlachtzug erkennt der Dienst an der GUID, nicht an `UnitIsUnit` (dessen Vergleich ist auf
  gesperrten Karten geheim). `C_FriendList.AddFriend` trägt `HasRestrictions = true`; ob ein Addon
  es aufrufen darf, ist ungeprüft.
- **Fenster (Neugestaltung 2026-11-24):** Der Auftraggeber fand die zwei Listen „boring“ neben der
  Chronik. Aus vier Entwürfen (Steckbrief, Album, Begegnungsbuch, Verbundenheit; Canvas
  „Weggefährten – Entwürfe“) hat er eine Mischung gewählt; Beschreibung und Plan:
  `docs/superpowers/specs/2026-11-24-fellows-redesign-design.md` und
  `docs/superpowers/plans/2026-11-24-fellows-redesign.md`. Nur gegen den Mock geprüft.
  - Tabs „Übersicht“, „Runden“ (seit 2026-11-24, siehe „Runden“ unten) und „Einstellungen“.
    Symbol: zwei Figuren (`people.tga`).
  - **Übersicht** (`FellowModel` in `UI/Options.lua`, gezeichnet von `UI.FellowOverview` in
    `UI/Fellows.lua`): links „Engste Gefährten“, die drei mit der meisten gemeinsamen Zeit als
    Kacheln (Rang I–III, Wappen mit Ring, Name in der Buchschrift, Stufe und Klasse, Abzeichen der
    Stufe, Zahlen, Fuß „In deiner Gruppe“ oder „Zuletzt … in …“; unter der Maus leuchten sie wie
    eine klickbare Karte im Buch, seit 2026-11-24 auf Wunsch des Auftraggebers). Darunter „Alle weiteren · N“
    mit Auswahl „Zuletzt gesehen“ / „Meiste gemeinsame Zeit“ (sortiert nur die Liste) und die
    Liste mit Spaltenköpfen, höchstens 60 Zeilen (`FELLOW_ROWS`) plus „N weitere“. Bis drei
    Personen gibt es keine Liste; ohne Personen den Hinweis, wie man anfängt.
  - Ein Klick auf Kachel oder Zeile öffnet die Geschichte der Person (Entscheidung des
    Auftraggebers, 2026-11-24: mit Seitenleiste wäre ein Steckbrief neben der Übersicht zu eng).
    Die Sortierung gilt für die Sitzung.
  - **Eure Geschichte** (`FellowStory`): links fest der **Steckbrief** (320 breit): Wappen, Name,
    Stufe und Klasse, Online-Zeile („In deiner Gruppe“ oder „Zuletzt …“), dann die Leiste der
    Verbundenheit, darunter die Zahlenleiste und „Kennengelernt …“, mit „auf Stufe N“ in einer eigenen
    Zeile darunter, damit der Satz nicht umbricht (die frühere zweite Zeile
    „Zuletzt …“ darunter ist seit 2026-11-24 entfallen, sie wiederholte die Online-Zeile; Wunsch
    des Auftraggebers nach einem Screenshot), Knöpfe „Alias festlegen“ (`ns:EditAlias`) und „Vergessen“
    (das Kreuz an den Zeilen ist entfallen; eine Chat-Zeile sagt es). Rechts daneben scrollt ein
    Buch (`UI.Book`, 560 breit; Wunsch des Auftraggebers nach dem ersten Blick ins Spiel: Person
    links, Buch rechts statt eines breiten Kopfes über einem zu breiten Buch) mit einem Kapitel je
    Spielabend wie in der Chronik (seit 2026-11-25, vorher je Tag mit dem Gebiet als Titel), das
    neueste zuerst: Titel nach der Tageszeit, links von–bis oder das Datum, rechts „N Std.
    zusammen“. Gebaut wird es weiter aus dem Tagesprotokoll: Je Tag eine Karte „Unterwegs in
    <Gebiet>“ (das letzte Gebiet des Tages; ohne Gebiet „Gemeinsam unterwegs“); ein Abend über
    Mitternacht, den das Protokoll auf zwei Tage teilt, ist eine Karte. Grenze: Das Protokoll kennt
    je Tag nur den ersten und letzten Moment, zwei Abende an einem Tag bleiben eine Karte; die
    Runden könnten sie trennen. Ein Boss ohne gezählte Zeit steht um 12 Uhr seines Tages. Unter
    der Karte (von bis; Bosse ohne Namen, etwa aus einem Schlachtzug, als Zahl
    dahinter; die Dauer stand bis 2026-11-24 auch dort, brach um und wiederholte den
    Kapitelkopf, deshalb auf Wunsch des Auftraggebers entfernt), je Boss mit Namen eine Karte („Archaedas bezwungen“, „in Uldaman“), „Ihr seid
    jetzt <Stufe>“ am Tag eines Aufstiegs und „Kennengelernt“ (auf Stufe N). Liegt das Kennenlernen
    vor dem Protokoll, steht es in einem eigenen letzten Kapitel. Seit 2026-11-24 steht dort
    nur Gemeinsames aus dem eigenen Tagesprotokoll, nichts aus der Chronik (siehe „Chronik und
    Weggefährten“). Hat die Chronik Einträge der Person (`ChronicleService.Who`, Name in jeder
    Schreibweise) und ist sie eingeschaltet, trägt die Karte neben „Alias festlegen“ den Knopf
    „In der Chronik“: Er öffnet Chronik › Freunde, gefiltert auf die Person. Statt der Tabs
    steht „Alle Weggefährten“ oben; ein anderer Reiter, eine andere Seite oder Schließen schließt
    die Geschichte.
  - **Aufbau des Steckbriefs (Entscheidung des Auftraggebers, 2026-11-24, an der Leinwand
    „Weggefährten – Personenkarte“, claude.ai-Artifact `EyiMx3kvy6qkrjnkYKV8eX`: Variante B
    „Zahlenleiste“, mit der Leiste der Verbundenheit über den Zahlen statt darunter):** Anlass:
    Die Karte wirkte unordentlich, die Zeit war zu groß (17 px halbfett, breiter als ihre
    Spalte). Verworfen: A (ruhige Liste), C (großer Ring, Zeit als Satz, Weg aus zwei Punkten),
    D (linksbündig mit Abschnitten). Die Leiste der Verbundenheit (`UI.TierBar`, ersetzt die
    Leiter mit vier Punkten) nennt links die Stufe (Akzent ab Vertraut) und rechts die nächste,
    darunter drei Abschnitte für die drei Schritte, gefüllt so weit, wie man gekommen ist, und
    mittig „Noch … gemeinsam“. Die Zahlenleiste ist ein vertiefter Kasten: die Zeit auf der
    halben Breite, Mal und Bosse auf je einem Viertel, getrennt durch Haarlinien; alle Zahlen
    20 px halbfett, bei der Zeit „Std.“ und „Min.“ klein daneben (unter einer Stunde nur
    Minuten, zur vollen Stunde nur Stunden). Im Spiel gesehen (Screenshot vom Auftraggeber,
    2026-11-24, Mira aus den Beispieldaten): Leiste, Abschnitte und Zahlenleiste wie geplant,
    „Std.“ und „Min.“ sitzen auf der Grundlinie. Danach kam die Stufe beim Kennenlernen in eine
    eigene Zeile, weil „…, auf Stufe 29“ den Satz eng umbrach. Die Karte bleibt auf voller Höhe
    (Entscheidung des Auftraggebers, 2026-11-24, statt sie auf ihren Inhalt zu kürzen); dafür
    stehen zwischen Person, Verbundenheit, Zahlen und Kennenlernen je 32 px (`SECTION_GAP`,
    vorher 18 bis 22), sodass auch ein zweizeiliges „Kennengelernt …“ gut über den Knöpfen endet.
    Beides ist im Spiel noch nicht gesehen.
  - Die Suche findet weiter jede Person als einfache Personenzeile (`FellowItem`, `tab.search`).
    Unter einem Alias steht der Name in der zweiten Zeile. Die Klasse kommt aus
    `LOCALIZED_CLASS_NAMES_MALE`, also in der Sprache des Clients.
- **Runden (Entscheidung des Auftraggebers, 2026-11-24, an der Leinwand „Weggefährten – Verlauf“,
  claude.ai-Artifact `L3v3BWqAv717ro24NVyQGF`: Variante B „Runden mit eigenem Protokoll“):**
  **Name (Wahl des Auftraggebers, 2026-11-25):** Der Reiter heißt „Runden“ / „Groups“; der erste
  Name „Verlauf“ / „Timeline“ gefiel ihm nicht („etwas unschön“). Ebenfalls vorgeschlagen:
  „Unterwegs“, „Lagerfeuer“, „Gemeinsam“. Im Code heißt der Reiter weiter `timeline`
  (`ui_tab_timeline`, `TimelineBook`, `TimelineRail`). Frage des Auftraggebers war, ob sich eine Ansicht lohnt, die die Geschichten aller Weggefährten
  zeigt. Empfehlung des Assistenten: nicht alle Einzelgeschichten untereinander (das wäre ein
  zweites Buch der Chronik), sondern wann ihr zusammen gespielt habt und mit wem. Verworfen: A,
  ein Tagebuch aus dem vorhandenen Tagesprotokoll (je Person und Tag eine Karte; wer zusammen in
  einer Gruppe war, ließe sich daraus nur raten, und es gibt keine Gesamtzeit in Gruppen). Nur
  gegen den Mock geprüft, im Spiel noch nicht gesehen. Umsetzung im Einzelnen und die Abweichungen
  von der Leinwand sind Entscheidungen des Assistenten:
  - **Rundenprotokoll** (`FamulusDB.fellowRuns`, accountweit, außerhalb der Profile, nichts wird
    verschickt): je Runde `f`, `l` (von, bis), `z` (die Gebiete in zeitlicher Reihenfolge,
    höchstens sechs), `b` (Bosse) und `who = { [guid] = { f, l } }` (wer von wann bis wann dabei
    war). Im Schlachtzug nur `raid = true` und `n` (die meisten Personen auf einmal), keine Namen,
    dieselbe Regel wie bei den Bossen. Höchstens 30 Tage (wie das Tagesprotokoll) und 400 Runden.
    `FellowService.Sync` schreibt mit; `Runs()` liefert die Runden und die laufende.
  - **Eine Runde** dauert, solange jemand in der Gruppe gezählt wird. Wer später kommt oder früher
    geht, ändert nichts an der Runde, nur an seinem `f`/`l`. Nach einer Pause von weniger als 30
    Minuten (`MEET_GAP`) mit mindestens einem derselben Leute geht die alte Runde weiter
    (`/reload`, Verbindungsabbruch, kurze Pause), sonst beginnt eine neue. Deshalb ist der Abend
    der Leinwand (Uldaman, danach Tanaris mit Mimi) eine Runde „Unterwegs in Uldaman und
    Tanaris“, weil Mimi die ganze Zeit dabei blieb; Borin und Lysa tragen „bis 22:40“.
  - **Gebiete:** `rememberFellows` hört dafür zusätzlich auf `ZONE_CHANGED_NEW_AREA`
    (`FellowService.Move`), nur solange das Feature an ist. Kehrt man zurück, steht das Gebiet im
    Protokoll noch einmal, im Titel der Karte nur einmal.
  - **Buch** (`TimelineBook` in `UI/Options.lua`, Reiter `timeline`): ein Kapitel je Spielabend
    wie in der Chronik (`SESSION_GAP`, `SessionTitle`); Kapitelkopf mit von–bis und „N Std.
    zusammen“. Je Runde eine Karte ohne Bild (`story.noPicture`): Titel „Unterwegs in …“ (im
    Schlachtzug „Schlachtzug in …“), darunter von–bis, Dauer und Bosse als Zahl (im Schlachtzug
    auch die Zahl der Personen), darunter je Person eine Plakette mit Klassensymbol und Namen
    (`story.people`; Alias, sonst Vorname; „bis …“ oder „ab …“, wer mehr als fünf Minuten später
    kam oder früher ging). Kehrt eine Gruppe von mindestens zwei derselben Leute wieder, sagt es
    der Fuß in Akzentfarbe (`story.foot`): „Wieder mit Mira und Borin · 6-mal in 30 Tagen“.
    Abweichung von der Leinwand („Zum 3. Mal mit …“): Gezählt wird nur, was das Protokoll noch
    kennt, also 30 Tage, und das sagt der Satz; Englisch braucht so keine Ordnungszahlen. Gewählt
    wird die Teilgruppe, die am häufigsten zusammen war, bei Gleichstand die größere; die Namen
    stehen nach gemeinsamer Zeit. Dazwischen „Lysa kennengelernt“ (nur wer in einer gezeigten
    Runde kennengelernt wurde) und „Du und Borin seid jetzt vertraut“ (Zeitpunkt aus den Runden,
    ab der Zeit vor ihnen gerechnet wie `Milestones`), beide mit dem Wappen statt eines Bildes
    (`story.crest`); ein Klick öffnet „Eure Geschichte“. Ab Vertraut ist die neue Stufe ein
    Meilenstein (größere Karte), darunter nicht, wie beim Abzeichen. Runden unter einer Minute
    ohne Boss und Runden, von deren Leuten niemand mehr in der Liste steht, erscheinen nicht.
    Höchstens 50 Ereignisse, darunter „Ältere Runden bleiben gespeichert …“.
  - **Randspalte** (`TimelineRail`): „Diese Woche“ (Zeit in Gruppen allein in ihrer Zeile, dafür
    `wide` in `UI/Rail.lua`; Runden, Weggefährten, kennengelernt, neue Verbundenheit), „Häufigste
    Runde“ (die Teilgruppe, die in den letzten sieben Tagen am öftesten zusammen war, ab zweimal;
    Wappen nebeneinander, nicht überlappend wie auf der Leinwand, neue Kartenart `group`) und „Am
    meisten zusammen“ (bis fünf Personen mit ihrer Zeit dieser Woche, ohne online/offline; ein
    Klick öffnet „Eure Geschichte“).
  - Nichts aus der Chronik, siehe „Chronik und Weggefährten“. „Vergessen“ und „Aufräumen“ nehmen
    die Person auch aus den Runden; eine Runde ohne Leute fällt dann weg. Die Suche findet hier
    nichts, die Personen findet sie in der Übersicht. Ohne Runde zeigt der Reiter, wie man anfängt.
  - Wer vor diesem Stand schon Weggefährten hatte, sieht unter „Runden“ erst die Runden ab dem
    Update; Tagesprotokoll und „Eure Geschichte“ bleiben, wie sie sind. Die Website zeigt die
    Runden noch nicht.
- **Verbundenheit (Entscheidung des Auftraggebers am Mockup, 2026-11-24):** Stufen nach gemeinsamer
  Zeit, `FellowService.TIERS`: Begegnung unter 1 Std., Bekannt ab 1, Vertraut ab 10, Unzertrennlich
  ab 40 (enUS: Encounter, Acquainted, Trusted, Inseparable; die englischen Namen hat der Assistent
  gewählt). `FellowService.Tier(sekunden)` liefert Stufe, Fortschritt und Rest. Angezeigt als Ring
  ums Wappen (`UI.Crest`), Abzeichen (`UI.TierBadge`, Akzent ab Vertraut) und Leiste
  (`UI.TierBar`, bis 2026-11-24 die Leiter `UI.TierLadder`). Der Ring ist ein angehaltener `Cooldown`-Swipe mit `ring.tga` (ohne
  `OnUpdate`; die höchste Stufe steht knapp vor dem Ende, weil ein abgelaufener Cooldown nichts
  zeichnet; `noCooldownCount` hält OmniCC und Ähnliche fern); fehlt `Cooldown:Pause`, ein voller
  Ring ohne Fortschritt. Das Klassensymbol kommt
  aus `UI-Classes-Circles` mit `CLASS_ICON_TCOORDS`, sonst der Anfangsbuchstabe. Beides prüft
  `/fam test` (Gruppe `media`).
- **Tagesprotokoll (seit 2026-11-24):** je Person `days = { [JJJJMMTT] = { s, z, b, f, l, k } }`
  (Sekunden, Gebiet zuletzt an dem Tag, Bosse, erster und letzter Moment, die Bosse mit Namen) und
  `firstLevel` (die Stufe des Spielers beim Kennenlernen). `k = { { t, n, z } }` (Zeit, Boss,
  Gebiet) gibt es nur in einer Gruppe, höchstens zwölf je Tag (`MAX_KILLS`); im Schlachtzug zählt
  nur `b`, damit nicht 39 Personen jeden Boss des Abends speichern (dieselbe Regel wie `with` und
  `others` in der Chronik). Höchstens 30 Tage, der älteste fällt zuerst. Eine
  Strecke über Mitternacht zählt für den Tag, an dem sie endet. Aufstiegstage werden beim Aufbau
  berechnet (`FellowService.Milestones`), ab der Zeit vor dem Protokoll (`seconds − Σ s`), damit
  frühere Zeit keine Meilensteine erfindet. Beim Laden fallen kaputte Tage heraus.
- **In der Chronik:** Fällt ein Boss in einer Gruppe, trägt der Eintrag `with` (die Namen, in einer
  Gruppe bis vier) oder `others` (nur die Zahl, im Schlachtzug, damit 39 Namen je Boss die Daten
  nicht aufblähen). Die Zeile darunter lautet „in Uldaman  ·  mit Mira und Tom“ (Alias, sonst
  Vorname) bzw. „mit 12 anderen“. Das gilt, sobald „Meine Reise festhalten“ läuft, unabhängig vom
  Schalter der Weggefährten. Beide Felder fehlen in `FIELDS` von `Sharing.lua` und werden also nicht
  geteilt. Der Beispiel-Boss in `/fam chronicle demo` hat zwei Gefährten. Die Weggefährten lesen
  `with` seit 2026-11-24 nicht mehr; sie merken sich ihre Bosse selbst (`k` im Tagesprotokoll).
- **Beispieldaten (2026-11-24, Wunsch des Auftraggebers):** `/fam fellows demo` trägt sechs
  erfundene Weggefährten ein (Klassen, Stufen, Gebiete; Mira und Borin wie in der Chronik),
  `/fam fellows demo clear` entfernt nur sie (`FellowService.Demo`, `ClearDemo`). Sie tragen
  `demo = true` und GUIDs `Player-0-FAMDEMO..`. Sprache wie bei den Beispielen der Chronik (seit
  2026-11-24 die von Famulus); die drei anderen heißen auf Englisch Kael Thornwood, Tomas
  Greywind und Ena Silverbrook.
  - **Seit den Runden (2026-11-24)** entstehen sie aus elf erfundenen Abenden über drei Wochen
    (`DEMO_RUNS`, Runden mit `demo = true`, die nie mit echten zusammenwachsen); Tage, Zeiten,
    Bosse, Kennenlernen und Zuletzt-Zeile werden daraus berechnet, so wie die Zählung sie
    geschrieben hätte. Vorher waren die Tage ausgedacht und passten zu keiner Runde. Der jüngste
    Abend ist der heutige, sobald 23:20 Uhr vorbei ist, sonst der gestrige. Zeiten jetzt: Mira 32
    Std. 20 Min., Borin 20 Std. 50 Min., Lysa 3 Std. 35 Min., Ena 3 Std. 30 Min., Kael 1 Std. 15
    Min., Tomas 25 Min. (vorher 25 Minuten bis 31 Stunden). Mira und Borin erzählen weiter einen
    Aufstieg (Vertraut), Bosse mit Namen gibt es in Uldaman und den Todesminen, Mira und Borin
    sind die Stammgruppe (sechsmal in drei Wochen).
- **Im Spiel ungeprüft:** alles. Besonders: ob `UnitName` für `party1`… Vor- und Nachname liefert
  wie für `player`, ob `GROUP_ROSTER_UPDATE` nach dem Login von selbst kommt (sonst fängt
  `PLAYER_ENTERING_WORLD` es auf), ob `IsInInstance` in Forever `pvp` meldet und ob `BOSS_KILL` in
  Forever-Dungeons feuert. `/fam test` prüft die benutzten Funktionen (Gruppe `api`).

## Website

Wunsch des Auftraggebers (2026-11-23): eine Website für das Addon, modern, minimalistisch, aber
stylisch, dunkel mit heller Schrift, die Funktionen bestmöglich gezeigt, mit modernen Effekten wie
Parallax; als Hintergrund Artwork von WoW oder generiertes. Der erste Stand (2026-11-24) liegt in
`website/`. Aufbau, Texte und Optik sind Entscheidungen des Assistenten und vom Auftraggeber noch
nicht bestätigt.

- **Technik:** statische Seite ohne Build-Schritt und ohne Bibliotheken: `index.html`,
  `styles.css`, `i18n.js` (Texte), `scene.js` (Landschaft, Parallax), `main.js` (Sprache,
  Demos), `assets/` (Logo als SVG aus den Umrissen von `tools/make_media.py`; Inter aus
  `Famulus/Media/Fonts` kopiert, samt Lizenz). Die Seite fragt keinen fremden Server an (keine
  Webfonts, kein Tracking). Vorschau: `python3 -m http.server 4173 --directory website`
  (als `website` in `.claude/launch.json`). Auf dem Windows-Rechner gibt es kein `python3`; dort
  startet `website-node` in derselben Datei einen kleinen Node-Server ohne Pakete (seit
  2026-11-24).
- **Optik folgt dem Addon:** die Helligkeitsleiter und die Farbwelt „Zitrone“ aus `UI/Theme.lua`
  als CSS-Variablen (`--h`, `--s`, `--accent`, `--accent2`), Akzent und Glühen nur für „aktiv /
  hier“, Körnung, Funken. Alle Farben, auch die der Landschaft, hängen an diesen Variablen. Die
  Seite merkt sich die Sprache im Browser (`localStorage`).
- **„Unter der Haube“ entfernt (2026-11-24, Entscheidung des Auftraggebers: „Erstmal
  unwichtig“):** der Abschnitt mit den Zahlen (0 Spielereignisse, 0 Zeilen pro Frame, 0
  Bibliotheken, 2 Sprachen), den vier Grundsätzen und der Auswahl der fünf Farbwelten, samt
  Eintrag in der Navigation. Mit ihm sind die anderen vier Farbwelten von der Seite
  verschwunden (`:root[data-scheme]` in `styles.css`, `setScheme` in `main.js`); eine Auswahl
  der Farbwelt braucht die Seite nicht (Auftraggeber, 2026-11-24). Zum Nachschlagen:
  Git-Verlauf bis Commit `a750f8d`. Nicht wieder einbauen, ohne zu fragen.
- **Das Artwork ist generiert, nicht von Blizzard** (Entscheidung des Assistenten): `scene.js`
  zeichnet eine Nachtlandschaft aus Bergketten, Wäldern, zwei Monden und einem Lager am Feuer
  (siehe „Lagerfeuer im Kopf“) als SVG-Ebenen, aus festem Zufall, also bei jedem Besuch gleich.
  Gründe: Blizzards Artwork ist urheberrechtlich
  geschützt, und eine eigene Landschaft folgt der Farbwelt. Parallax: Ebenen mit `data-depth`
  folgen Scrollen und Mauszeiger (gezeichnet wird nur bei Änderung und nur, solange der Kopf
  sichtbar ist), Elemente mit `data-parallax` driften beim Scrollen. Die Funken sind
  CSS-Animationen. `prefers-reduced-motion` schaltet alle Bewegung ab.
- **Aufbau (seit 2026-11-24, Aliase zuletzt, siehe „Vorgaben“):** Kopf (Landschaft) → das Fenster
  des Addons als Screenshot, darüber Einblendungen (siehe „Fenster im Kopf“) → 01 Chronik (das
  Bilderbuch mit den Reitern Alle, Meine Reise, Gefährten) →
  02 Weggefährten → 03 Live-Einblendung (auslösbar, Platz verschiebbar) → 04 Aliase (das Fenster
  nachgebaut und bedienbar, darunter Chat und Tooltip „im Spiel“) → 05 Installation → Fuß mit
  Hinweis auf Blizzards Marke. Getönter Grund (`section--tinted`) und Schein wechseln weiter von
  Abschnitt zu Abschnitt. Sprunglink und „Was es kann“ führen zur Chronik (der Pfeil im Kopf ist
  seit dem Fenster im Kopf entfallen).
  Vorher: 01 Aliase, 02 Chronik, 03 Weggefährten, 04 Live-Einblendung. Die Demos zeigen erfundene
  Personen und die Beispiele aus `/fam chronicle demo`, mit den eigenen Zeichnungen statt
  Spielsymbolen. Ein Alias aus der Demo der Aliase erscheint auch im Bilderbuch, in den
  Einblendungen und bei den Weggefährten.
- **Weggefährten (2026-11-24, Wunsch des Auftraggebers; Aufbau, Texte und Daten hat der
  Assistent entschieden, vom Auftraggeber noch nicht gesehen):** Wie die Übersicht im Addon
  (`UI/Fellows.lua`), aber ohne Fensterrahmen, damit der Abschnitt nicht vom nachgebauten
  Fenster abhängt: drei Kacheln „Engste Gefährten“ (Rang, Wappen mit Ring, Name in der
  Buchschrift, Verbundenheit, Zahlen, Fuß), darunter „Alle weiteren“ mit Auswahl der
  Reihenfolge und Liste. Ein Klick öffnet „Eure Geschichte“: links der Steckbrief mit Leiter
  der Verbundenheit, rechts das Buch der gemeinsamen Tage (Gemeinsam unterwegs, Bosse, „Ihr
  seid jetzt …“, Kennengelernt). Stufen und Meilensteine rechnet `main.js` wie
  `FellowService.Tier` und `Milestones`. Das Wappen zeigt den Anfangsbuchstaben in der
  Klassenfarbe statt eines Klassensymbols (keine Grafiken von Blizzard). „Alias festlegen“
  füllt das Fenster der Aliase aus, „In der Chronik“ (nur bei Mira und Borin, die Einträge
  haben) filtert das Buch der Chronik. Die Personen: Mira, Borin, Kaelric (Papa) und Yorick
  von der Seite, dazu Lysa und Ena aus `/fam fellows demo`; Zeiten und Tage passen zur Chronik
  der Seite. Abweichung vom Addon: Die Karte nennt „zuletzt …“ nur einmal (im Addon steht es
  unter dem Namen und noch einmal unten).
- **An den neuen Fensteraufbau angepasst (2026-11-24, Wunsch des Auftraggebers; die Umsetzung im
  Einzelnen hat der Assistent entschieden, vom Auftraggeber noch nicht gesehen):**
  - **Fenster:** wie im Addon Kopf mit Logo, den drei Bereichen als Reiter mit Zähler (Chronik,
    Weggefährten, Aliase; nur Aliase bedienbar), „Einstellungen“ und „Über“ rechts; Seitenleiste
    mit Suche, Name und Beschreibung der Aliase, Hauptschalter, den Unterbereichen „Namen“ und
    „Einstellungen“ und „x von 10 aktiv“; im Inhalt Titel des Unterbereichs und „Zurücksetzen“ mit
    Nachfrage (nur auf „Einstellungen“). Weil der Kopf Breite braucht, steht das Fenster über die
    ganze Seitenbreite und die Spielansicht (Chat links, Tooltip rechts) als Band darunter, nicht
    mehr daneben. Schmaler: unter 1080 px nur Symbole für „Einstellungen“ und „Über“, unter 900 px
    eine Spalte (Seitenleiste als Streifen unter dem Kopf), unter 680 px nur der gewählte Bereich
    mit Namen. Die Grenzen 900 und 680 sind so gewählt, dass der Kopf auf Englisch und Deutsch
    ins Fenster passt (gemessen 2026-11-24).
  - **Das Fenster hinkt dem Addon hinterher (Stand 2026-11-24):** Es zeigt noch den Zwischenstand
    mit Reitern im Kopf, Hauptschalter in der Seitenleiste und „x von 10 aktiv“. Entscheidung des
    Auftraggebers: erst nachziehen, wenn sich das Fenster im Addon gesetzt hat („die Fenster
    werden sich ohnehin noch viel verändern“).
  - **Chronik:** Kapitelkopf in einer Zeile, Wiederholungen gebündelt (die Beispieldaten von
    gestern haben dafür drei Tode in Uldaman und zwei Stufen von Borin), daneben die Randspalte wie
    im Addon (Alle: Woche und Gefährten; Meine Reise: Woche und Berufe; Gefährten: Steckbriefe). Ein
    Klick auf einen Gefährten filtert das Buch. Unter 980 px steht die Randspalte zwischen den
    Reitern und dem Buch. Der Kapitelkopf entsteht wie im Addon (`TitleChapter`) aus den gezeigten
    Ereignissen (`chapterHead` in `main.js`): Gebiet der meisten, Stufen nur aus eigenen.
- **Review 2026-11-24** (Durchsicht im Browser und im Code, vom Auftraggeber zum Abarbeiten
  freigegeben): behoben sind die Kapitelköpfe beim Filtern, zwei Formulierungen für denselben
  Fund, widersprüchliche Beispieldaten (Mira war schon gestern 40; die Stufe in der Einblendung
  hat jetzt Kaelric), der Grundsatz „Fehler bleiben klein“ (nur ein Fehler beim Einschalten
  schaltet eine Funktion ab) und Schritt 2 der Installation (Neustart statt `/reload`, weil ein
  neuer Addon-Ordner sonst womöglich nicht gefunden wird; im Spiel ungeprüft, die README sagt es
  seit 2026-11-24 ebenso). Dazu: Einblendungen und Funken laufen nur, wenn sie zu sehen sind; „weniger
  Bewegung“ wirkt auch, wenn es erst während des Besuchs eingeschaltet wird; Tabs mit
  Pfeiltasten; Fokus bleibt beim Löschen eines Alias und bei „Alle zeigen“; der Platz der
  Einblendung lässt sich mit den Pfeiltasten verschieben; ausgelöste Einblendungen werden
  vorgelesen (`#feed-said`); `color-scheme: dark`. Offen geblieben (Geschmack, nicht geändert):
  336 px Abstand zwischen zwei Abschnitten.
- **Lagerfeuer im Kopf (2026-11-24, Wunsch des Auftraggebers):** Forever hat ein neues
  Spielelement: Man setzt sich gemeinsam ans Lagerfeuer und bekommt Buffs. Das ist jetzt das
  Motiv der Kopfgrafik, im bisherigen Stil (gezeichnet, kein Screenshot). Aus vier Varianten
  („Ferne Glut“, „Am Feuer“, „Vor dem Mond“, „Am See“) hat der Auftraggeber **„Vor dem Mond“**
  gewählt: eine Gruppe auf einer Kuppe als Schattenriss vor einem großen Mond. Die anderen drei
  und die Umschaltleiste sind wieder entfernt (nie committet). Seine Kritik am ersten Stand: zu
  wenig WoW-Charakter, zu wenig Flora und Fauna, die Figuren sahen aus wie Gliederpuppen
  (sie waren aus Gelenken mit gleich dicken Strichen gebaut). Überarbeitet; die Umsetzung im
  Einzelnen hat der Assistent entschieden, der Auftraggeber hat sie gesehen und committen lassen
  (2026-11-24):
  - **Figuren** sind gezeichnete Silhouetten aus Teilen (`FIGURES` in `scene.js`: glatte
    Umrisse, sich verjüngende Glieder, Köpfe im Profil): eine Gruppe von vier mit Haustier,
    erkennbar an der Ausrüstung, nicht am Volk, damit keine Fraktion außen vor bleibt (Horde und
    Allianz spielen in Forever nicht zusammen). Magier (Spitzhut, Bart, Stab mit leuchtendem
    Kristall, steht), Krieger (Hörnerhelm, Schulterplatte mit Dornen, Bart, Krug zum Feuer,
    Axt im Boden), Jägerin (lange Ohren, Haar, Bogen und Köcher auf dem Rücken) mit Wolf,
    Schurke (Kapuze, Umhang). Dazu Zelt mit Licht innen und ein gesatteltes Pferd (Forever hat
    nur Bodenreittiere).
  - **Ebener Lagerplatz (Kritik des Auftraggebers):** Zelt und Pferd standen schräg am Hang, und
    das Pferd sah aus wie ein Esel. Die Kuppe ist jetzt zwischen `plateau.from` und `plateau.to`
    genau eben und rundet sich erst danach ab (`edge`). Alles, was dort steht, muss in diesem
    Bereich bleiben. Das Pferd hat jetzt einen gebogenen Hals, einen langen Kopf, kleine Ohren,
    eine Mähne, einen langen Schweif und einen Zügel, aber keine Satteldecke mehr.
  - **Flora und Fauna:** ein alter Laubbaum neben dem Mond, auf dessen Ast eine Eule mit
    leuchtenden Augen sitzt; Laubbäume zwischen den Kiefern (`trees.broad`), Büsche (`bushes`),
    Grasbüschel (`grass`), ein Hirsch, Fledermäuse, die über den Mond fliegen, Glühwürmchen.
    Zwei Monde, ein großer weißer und ein kleiner blauer, wie bei Azeroth.
  - **Feuer:** die Flamme des Logos, flackert per CSS; Lichtkante der Figuren zum Feuer hin.
    Bewegung nur per CSS (Flamme, Fledermäuse, Glühwürmchen, Funken), `prefers-reduced-motion`
    hält alles an.
  - **Schmale Bildschirme** (eine Spalte, bis 980 px): Die Zeichnung wird kleiner, steht unter
    dem Text (eigener Platz, `padding-bottom` am Kopf) und wird so verschoben, dass das Lager
    mittig ist (`FamulusScene.pan`). Sonst lag es rechts außerhalb und der Mond hinter den Knöpfen.
  - Die Einblendungen standen rechts über dem Mond; seit dem Fenster im Kopf (siehe unten)
    liegen sie über dessen unterer rechter Ecke.
  - Geprüft im eingebauten Browser und mit Chrome ohne Fenster bei 375, 768, 1280, 1440 und
    1920 px Breite, Deutsch und Englisch; keine Meldungen in der Konsole. Nicht geprüft: Safari,
    Firefox, echte Mobilgeräte.
- **Fenster im Kopf (2026-11-24, Wunsch des Auftraggebers nach dem Vorbild von polestar.guide):**
  Unter dem Lagerfeuer steht ein Screenshot des Addon-Fensters (`figure.shot`, erstes Element in
  `<main>`). Er ragt von unten in den Kopf (unter 980 px nur 40 px, weil dort das Lager unter dem
  Text steht), blendet nach unten aus (Maske) und hat per CSS runde Ecken (12 von 1180 × 730).
  - **Höher gezogen (2026-11-24, Wunsch des Auftraggebers):** Der Text des Kopfes steht oben,
    72 px unter der Navigation (`padding-top: 140px`), statt mittig (vorher etwa 65 px bei
    1440 × 900; 36 px waren dem Auftraggeber zu wenig). Das Fenster ragt so weit in den Kopf, wie
    `--lift` sagt (`clamp(150px, 22svh, 240px)`); der Text hält darunter `--lift` plus 40 px
    frei, damit das Fenster ihn nie verdeckt. Den Hintergrund wollte der Auftraggeber nicht
    angefasst haben. Gemessen bei 1440 × 900: Das Fenster beginnt in beiden Sprachen bei 702
    statt 756 px, bei 1920 × 1080 bei 842 statt 912 px. Zum Feuer bleiben 60 bis 95 px.
  - **Der Titel hat in jeder Sprache zwei Zeilen** (Vorgabe des Auftraggebers, 2026-11-24). Der
    Umbruch steht im Text (`<br>` in `hero_title`: „For everyone / you play with.“, „Für alle,
    mit denen / du spielst.“; vor dem `<br>` steht ein Leerzeichen, sonst lesen Screenreader
    „denendu“), und die Schrift schrumpft, bis die längere Zeile in die
    Textspalte passt: `font-size: min(<wie bisher>, var(--title-fit))`, mit `--title-fit` je
    Sprache in Containereinheiten (`cqi`, die Textspalte ist der Container): Englisch 15.5cqi
    (greift nie, die Zeilen passen ohnehin), Deutsch 11.9cqi („Für alle, mit denen“ ist 8,2 em
    breit). Ein neuer Titel oder eine neue Sprache braucht ihren eigenen Wert, etwa 97 geteilt
    durch die Breite der längeren Zeile in em. Vorher brach der deutsche Titel bei 1440 px auf
    drei Zeilen und streckte den Kopf auf 941 px. Geprüft von 320 bis 1920 px Breite in beiden
    Sprachen: zwei Zeilen, nichts läuft über. Deutsch ist dadurch kleiner (76 statt 90 px bei
    1440 × 900, 40 statt 43 px auf dem Telefon).
  - **Screenshot statt Nachbau** (Empfehlung des Assistenten, vom Auftraggeber gewählt): Es ist
    das echte Addon, und ein Bild ist schnell getauscht, solange sich das Fenster noch ändert;
    Polestar zeigt dort ebenfalls Screenshots. Folge: Im Bild sind Spielsymbole und die
    Buchschrift des Spiels zu sehen; bis dahin zeigte die Seite keine Grafiken von Blizzard.
  - **Ein englisches Bild für beide Sprachen** (Entscheidung des Auftraggebers, 2026-11-24:
    „Englisch reicht“), in zwei Breiten: `assets/shots/window-<1180|1770>.webp`. Nur der
    Alternativtext wechselt mit der Sprache (`shot_alt` in `i18n.js`, deutsch mit dem Zusatz
    „englische Fassung“).
  - **Herstellen:** `node tools/make_shot.js <screenshot> <x> <y> <breite> <höhe>
    website/assets/shots/window` schneidet das Fenster ab seiner äußeren Haarlinie aus
    und schreibt WebP in voller Breite und 1180; Chrome ohne Fenster dekodiert, skaliert und
    kodiert, sonst braucht es nur Node. Die Kanten findet man an der Haarlinie (Helligkeit etwa
    48 gegen 10 bis 20 daneben; auf dem Windows-Rechner per PowerShell mit `System.Drawing`
    gemessen). Aufnahme in 4K, dann ist das Fenster etwa 1770 px breit.
  - **Für die Aufnahme:** Client und Famulus auf Englisch (sonst bleiben Gegenstands- und
    Klassennamen deutsch, siehe „Beispieleinträge“), dann `/fam chronicle demo` und
    `/fam fellows demo`.
  - **Stand:** Das Bild ist Chronicle › Everyone, aus dem Screenshot
    `WoWScrnShot_112426_221759.jpg` (Client auf Englisch, Beispieldaten; Fensterkanten bei x 1022,
    y 476, 1770 × 1095). Im Bild zu sehen: der Vorname des eigenen Charakters („Kip“, Karte „This
    week“) und „Level 19“ im Kapitelkopf neben dem Beispiel „Reached level 40“, weil die
    Beispiele sich mit den echten Einträgen eines Charakters auf Stufe 19 mischen. Vom
    Auftraggeber mitgeschickt und noch nicht verwendet: Fellow travellers › Overview
    (`…_221819.jpg`) und die Geschichte von Borin (`…_221836.jpg`).
  - Die Einblendungen des Kopfes liegen über dem unteren Ende der rechten Spalte des Fensters,
    unter dessen Freundesliste, wo das Fenster ausblendet (`.shot__feed`, `top: 70%`), wie
    Polestars zweites Fenster. Bei 50 % verdeckten sie die Freundesliste. Sie stehen dort
    rechtsbündig an der Fensterkante und ragen 44 px darüber hinaus (unter 1400 px innen, unter
    760 px ausgeblendet); linksbündig wie im Spiel lagen sie bei 1024 px über dem Buch.
    Entscheidung des Assistenten. Der Schein des ersten Abschnitts darf nach oben in den
    auslaufenden Fuß des Fensters reichen (`.shot + .section`), sonst stand dort eine harte
    Kante.
  - Geprüft im eingebauten Browser bei 1440, 1024 und 375 px, Deutsch und Englisch; kein
    seitliches Scrollen. Aufbau im Einzelnen: Entscheidungen des Assistenten, vom Auftraggeber
    noch nicht gesehen.
  - Offen: Die Demos der Website nennen auch auf Englisch „Mira Sturmfeder“ und „Borin
    Eisenbart“; die englischen Beispiele im Addon heißen seit 2026-11-24 anders (siehe oben).
- **Sprachen:** Englisch steht im HTML (`data-i18n="schlüssel"`), Deutsch in `i18n.js`; was
  Skripte zusammensetzen, steht dort in beiden Sprachen. Die Sprache folgt dem Browser, ist
  umschaltbar und lässt sich mit `?lang=de` erzwingen. Fehlt einer Sprache ein Schlüssel, warnt
  die Konsole.
- **Hosting (2026-11-24):** Wunsch des Auftraggebers: direkt aus GitHub, ohne eigenen Server und
  ohne Handarbeit, mit eigener Domain. Weil das Repo öffentlich ist, GitHub Pages (kostenlos):
  `.github/workflows/website.yml` veröffentlicht den Ordner `website/` unverändert, sobald ein
  Push auf `main` darin etwas ändert; von Hand über Actions › Website › Run workflow. Einmal je
  Repository: Settings › Pages › Source „GitHub Actions“. Die Domain besorgt der Auftraggeber;
  eingetragen wird sie unter Settings › Pages › Custom domain (eine `CNAME`-Datei braucht es mit
  dem Workflow nicht), beim DNS-Anbieter A- und AAAA-Records auf GitHub für die Domain ohne
  `www`, ein CNAME auf `89pleasure.github.io` für `www`. Ohne Domain liegt die Seite unter
  `89pleasure.github.io/famulus/`; das geht, weil alle Pfade relativ sind. GitHub sieht die
  IP-Adressen der Besucher, das gehört in die Datenschutzerklärung. Auf GitHub noch nie gelaufen.
- **Bewusst noch nicht enthalten:** ein Download (die Veröffentlichung ist offen; der Knopf sagt
  „Download folgt“), Guildy (erst wenn der PR dort angenommen ist), weitere Screenshots aus dem
  Spiel (bisher nur das Fenster im Kopf), Impressum und Datenschutzerklärung (vor dem
  Veröffentlichen nötig), die Domain (besorgt der Auftraggeber), ein Vorschaubild für geteilte
  Links, WOFF2-Schriften (geladen werden die TTF aus dem Addon, je ~100 KB).
- **Geprüft** im eingebauten Browser der App (Chromium): bei 1440 und 375 px Breite alle
  Abschnitte, bei 1024 und 680 px stichprobenartig; Deutsch und Englisch; die Farbwelten Zitrone,
  Minze, Rose und Flieder; die drei Demos bedient; keine Meldungen in der Konsole. Nicht geprüft:
  Safari, Firefox, echte Mobilgeräte, die Einstellung für weniger Bewegung. Nach der Anpassung an
  den neuen Fensteraufbau (2026-11-24) erneut bei 1440, 1024, 768 und 375 px: Fenster und Chronik
  bedient (Unterbereich, Schalter, Zurücksetzen, Hauptschalter aus, Reiter der Chronik, Filter),
  Deutsch und Englisch, keine Meldungen in der Konsole; Farbwelten diesmal nicht. Nach dem
  Review (2026-11-24): Fensterkopf bei 375 bis 1081 px in beiden Sprachen nachgemessen, Tabs per
  Tastatur, Fokus, Vorlesen und Verschieben per Skript geprüft. „Weniger Bewegung“ ließ sich im
  Browser der App nicht einschalten und ist weiter ungeprüft. Die Weggefährten (2026-11-24) bei
  1440, 1024, 768 und 375 px in beiden Sprachen: Kacheln, Liste, Reihenfolge, Geschichte öffnen
  und schließen (Fokus kehrt zurück), „Alias festlegen“, „In der Chronik“; keine Meldungen in der
  Konsole, kein seitliches Scrollen.
- **Bei Änderungen am Addon mitziehen:** der Screenshot im Kopf, sobald sich das Fenster sichtbar
  ändert; Versionsnummer (`fact_version`, `in_rel_d`), die Zähler
  im nachgebauten Fenster (`renderWindow` in `main.js`: 5 Alias-Features, 10 insgesamt; im HTML
  Chronik 1/4 und Weggefährten 0/1), neue Hauptfunktionen als Reiter im Kopf und als eigener
  Abschnitt mit Eintrag in der Navigation; die Stufen der Verbundenheit (`TIERS` in `main.js`)
  wie `FellowService.TIERS`.

## Veröffentlichung auf CurseForge

Wunsch des Auftraggebers (2026-11-24): eine erste Alpha auf CurseForge, mit automatischem Upload.
Eingerichtet am 2026-11-24 nach dem Vorbild von FlareUI und Guildy; der Aufbau im Einzelnen ist eine
Entscheidung des Assistenten. Erste Datei: `v0.1.0-alpha.1` als Alpha, hochgeladen am 2026-11-24
(Workflow grün, CurseForge antwortete „Success!“), danach in der Moderation von CurseForge.

- **Werkzeug:** der BigWigs-Packager (`BigWigsMods/packager@v2`) als GitHub Action in
  `.github/workflows/release.yml`. Er bildet `## Interface: 16001` auf die CurseForge-Spielversion
  „WoW Forever“ ab (laut Quellcode `16???` → `forever`, Versionstyp 88568). `.pkgmeta` hebt den
  Unterordner `Famulus/` per `move-folders` an die Spitze des Zips (CurseForge will genau einen
  Ordner, benannt wie die `.toc`) und lässt den Rest des Repos draußen. Lokal mit dem Packager
  geprüft (`release.sh -d -z`): ein Ordner `Famulus` mit den Dateien des Addons, Version ersetzt.
- **Ausgelöst wird nur durch einen Tag** `v…`, den der Auftraggeber selbst setzt. Pushes und Pull
  Requests laden nie hoch; dort laufen nur die Tests (`.github/workflows/tests.yml`) und, wenn
  sich auf `main` etwas in `website/` ändert, die Veröffentlichung der Website (siehe „Website“).
- **Der Tag bestimmt den Dateityp.** `tools/release_check.sh` lässt nur drei Formen zu: `v1.2.3`
  (Release), `v1.2.3-beta.1` (Beta), `v1.2.3-alpha.1` (Alpha). Grund (Vorgabe des Auftraggebers:
  nichts mit „alpha“ oder „beta“ darf als normaler Release erscheinen): Der Packager lädt jeden Tag
  ohne diese Wörter als Release hoch, `v0.2.0-rc1` wäre sonst bei allen Spielern gelandet. Das
  Skript prüft außerdem, dass `CHANGELOG.md` einen Abschnitt `## <version>` (Tag ohne „v“) mit
  Text hat, dass die `.toc` eine `## X-Curse-Project-ID` trägt und dass das Secret `CF_API_KEY`
  gesetzt ist. Erst danach laufen die Tests, und nur wenn sie grün sind, baut und lädt der Packager.
- **Ablauf eines Release:** Abschnitt in `CHANGELOG.md` schreiben (Englisch, wird der Changelog der
  Datei auf CurseForge), per Pull Request nach `main` bringen, dann auf dem gemergten Stand von
  `main` `git tag v0.1.0` und `git push origin v0.1.0`.
  Prüfen vorab: `bash tools/release_check.sh v0.1.0`. Von Hand gestartet (Actions › Release › Run
  workflow) baut der Workflow das Zip ohne Upload und hängt es eine Woche an den Lauf.
- **Version:** Die `.toc` trägt `@project-version@` in einem `#@non-debug@`-Block, der Packager
  setzt den Tag ein. Die Arbeitskopie (Junction) liest `## Version: dev` aus dem `#@debug@`-Block;
  Fenster und Selbsttest zeigen dann „dev“. `ns.version` lässt das „v“ des Tags weg.
- **Changelog:** Fehlt `.release-notes.md`, baut der Packager einen Changelog aus den Commits (samt
  alter `Co-Authored-By`-Zeilen). Deshalb schreibt der Workflow die Datei immer, beim Probelauf
  als Platzhalter.
- **Regeln von CurseForge** (Support-Seiten, gelesen 2026-11-24): Projekt und jede Datei werden von
  Hand geprüft (täglich 8–15 Uhr MEZ, der Reihe nach; Stunden bis Tage). In der App erscheint ein
  Projekt nur mit mindestens einer Datei vom Typ Release; Alpha und Beta bekommt nur, wer die
  Release-Art für das Addon umstellt. Jede Datei braucht einen Changelog; externe Download-Links
  sind verboten.
- **Lizenz (Entscheidung des Auftraggebers, 2026-11-24): alle Rechte vorbehalten**, nach dem
  Muster von Cell (`LICENSE` im Wurzelordner). Er wollte den Code zeigen, aber keine veröffentlichten
  Forks; die GPL (auch mit Namensschutz nach Abschnitt 7) hat er deshalb verworfen. Erlaubt: Code
  ansehen, für den eigenen Gebrauch ändern, auf GitHub forken nur für Pull Requests. Nur mit
  schriftlicher Erlaubnis: weitergeben, hochladen, als eigenes Projekt veröffentlichen, größere
  Teile verwenden, Name und Logo nutzen. Beiträge darf der Auftraggeber unter beliebigen Bedingungen
  verwenden (damit bleibt ein späterer Lizenzwechsel möglich). Der Wortlaut ist ein Entwurf des
  Assistenten, keine Rechtsberatung; als Urheber steht auf Wunsch des Auftraggebers „89pleasure“. Der
  Packager legt die Datei als `Famulus/LICENSE` ins Zip (lokal geprüft; als ungetrackte Datei
  lässt er sie weg). Auf CurseForge „All Rights Reserved“ wählen. Damals verbreitet: alle Rechte
  vorbehalten bei DBM, Details!, ElvUI, Cell, Masque; GPL bei WeakAuras, Questie, MDT, Guildy,
  OneForAll, Polestar; MIT bei OmniCC und FlareUI. Den Fork-Knopf eines öffentlichen Repos kann keine
  Lizenz abschalten. Vor dem Öffentlichmachen des Repos offen: Die alten Commits enthalten
  `Co-Authored-By: Claude …`-Zeilen (siehe Arbeitsablauf).
- **Logo für das Projekt:** `docs/curseforge/logo.png` (1024 × 1024), gerendert aus
  `docs/curseforge/logo.svg`: die Flamme aus `tools/make_media.py` mit Schein auf dem dunklen Grund
  von `logo-round.tga`, als volles Quadrat, weil CurseForge selbst zuschneidet, rundet und auf
  400 × 400 verkleinert. Flamme und Funken liegen im eingeschriebenen Kreis, ein runder Zuschnitt
  schneidet also nichts ab. Neu rendern (Git Bash, Chrome auf dem Windows-Rechner; im SVG-Kommentar
  darf kein doppelter Bindestrich stehen):
  `"/c/Program Files/Google/Chrome/Application/chrome.exe" --headless=new --disable-gpu
  --hide-scrollbars --force-device-scale-factor=1 --window-size=1024,1024
  --screenshot="<abs. Pfad>\logo.png" "file:///<abs. Pfad>/logo.svg"`.
  Eine Entscheidung des Assistenten, vom Auftraggeber noch nicht gesehen.
- **Projekt angelegt** (vom Auftraggeber, 2026-11-24): CurseForge-Projekt-ID 1828785, steht als
  `## X-Curse-Project-ID` in der `.toc`. Probelauf auf GitHub am 2026-11-24 grün: Spielversion
  1.60.1 (Forever) erkannt, 60 Dateien (Addon plus `LICENSE`), Zip `Famulus-<version>-forever.zip`
  (der Packager hängt „-forever“ an, auch an die Bezeichnung auf CurseForge).
- **Erste Datei als Alpha (Entscheidung des Auftraggebers, 2026-11-24):** Tag `v0.1.0-alpha.1`,
  „damit sie nicht als Release rausgeht, wir sind ja noch nicht so weit“. Verworfen ist damit die
  Empfehlung des Assistenten (`v0.1.0` als Release, damit Famulus in der App erscheint). Folge:
  Solange es keine Release-Datei gibt, steht Famulus nur auf der Website von CurseForge, nicht in
  der App. Der Abschnitt in `CHANGELOG.md` heißt deshalb `## 0.1.0-alpha.1`.
- **Token:** Das Repository-Secret `CF_API_KEY` hat der Auftraggeber selbst hinterlegt
  (2026-11-24); der Token ging nicht durch den Assistenten.
- **Offen:**
  - Projektseite: Summary vom Auftraggeber gewählt („Your companion for playing together: Famulus
    helps you stay close to the friends and fellow adventurers who make your journey so
    special.“); die Beschreibung liegt als Entwurf des Assistenten in
    `docs/curseforge/description.md` (Englisch, Markdown, ohne Guildy, weil dessen Anbindung nur
    mit dem Fork geht). Kategorien: Der Assistent rät von „Companions“ ab (auf CurseForge
    Haustiere und Reittiere) und empfiehlt „Chat & Communication“ mit „Guild“.
  - Nicht eingerichtet: Wago, GitHub-Releases, eine Freigabe-Umgebung für die Secrets.
- Auf GitHub gelaufen (2026-11-24): der Test-Workflow, ein Probelauf ohne Upload und der Upload
  von `v0.1.0-alpha.1` („Uploading Famulus-v0.1.0-alpha.1-forever.zip (1.60.1 alpha) … Success!“).
  Ein Tag ohne Upload (Freigabe, Wago, GitHub-Releases) ist nicht eingerichtet.

## Regeln für neuen Code

Diese Punkte sind Entwurfsentscheidungen; die meisten prüft `tests/run.lua`.

- **Feature-Registry:** Alles Schaltbare ist ein Feature über `ns:NewFeature`, **eine Datei je
  Feature** unter `Modules/<Kategorie>/<Id>.lua` (beides großgeschrieben, z. B.
  `Modules/Aliases/ChatAliases.lua`); der Test prüft das. Was der Selbsttest lesen muss
  (Listen, CVar-Namen), hängt am Feature-Objekt.
- **Lebenszyklus über die Feature-Klasse** (`Core/Features.lua`), die Registry räumt beim
  Abschalten auf: Events über `feature:RegisterEvent`, wiederkehrende Timer über
  `feature:StartTicker`, verzögerte
  Einzelaufrufe über `feature:After` (verfallen beim Abschalten). Hooks lassen sich nicht
  entfernen: `feature:HookFunction` (`hooksecurefunc`) und `feature:HookScript` setzen sie einmal
  und lassen sie nur bei eingeschaltetem Feature wirken; für andere Hook-APIs `feature:Once` plus
  `feature:Guard`.
- **Services für geteilten Code:** Was mehrere Features brauchen, ist ein Service statt kopiertem
  Code. Ein Service heißt **immer** `<Name>Service`: Datei `<Name>Service.lua`, Table
  `ns.<Name>Service`, kein Feature darin (der Test prüft das). So ist an jedem Aufruf erkennbar,
  ob etwas ein Service (`ns.AliasService.Get`), ein Feature (`ns.features.chatAliases`) oder eine
  einfache Hilfsfunktion (`ns.IsSecret` in `Core/Init.lua`) ist. Für alle
  Kategorien liegt ein Service unter `Core/` (`ChatService`: Klartext prüfen, Chat-Sperre prüfen;
  `GroupService`: wer in der Gruppe ist; `SocialService`: wer Freund, Battle.net-Freund oder in der
  Gilde ist, wer davon online ist, welche Klasse die Listen nennen, und Namen aus Listen in einer
  Schreibweise. Wer Freundesliste,
  Gildenliste oder Battle.net-Freunde liest, tut es über `SocialService.EachFriend`,
  `EachGuildMember` und `EachBattleNetFriend` (seit dem Review vom 2026-11-24 auch Chronik,
  Teilen und Account-Aliase); nur der Selbsttest liest den Client absichtlich direkt. Einen Namen
  in jeder Schreibweise vergleicht `SocialService.Key`; `AliasService.Key` bleibt der Schlüssel,
  unter dem Aliase gespeichert sind),
  für eine Kategorie in deren Ordner (`Modules/Aliases/AliasService.lua`,
  `Modules/Chronicle/ChronicleService.lua`). Ein Service hängt sich über
  das interne Signal `FEATURE_STATE` an den Zustand seiner Features, statt dass jedes Feature ihn
  in `OnEnable`/`OnDisable` selbst an- und abmelden muss. In der `.toc` steht ein Service vor den
  Features, die ihn nutzen.
- **Kategorie-Hauptschalter:** Jede Kategorie hat einen Hauptschalter (Option `categories.<id>`,
  Standard an, Schalter unter Einstellungen › Allgemein). Ist er aus, läuft kein Feature der Kategorie, egal wie es
  selbst eingestellt ist: keine Events, keine Timer, Hooks bleiben stumm. Die Einzelauswahl bleibt
  gespeichert. Die Prüfung sitzt in `ns:SyncFeature`; ein Feature muss dafür nichts tun.
- **`requires`:** Jede benötigte Client-API als Pfad angeben (`"C_FriendList.GetNumFriends"`).
  Fehlt sie, bleibt das Feature aus und erscheint als „nicht verfügbar“.
- **Standardwerte:** Was im Namen des Spielers handelt, Nachrichten an andere Spieler schickt
  oder auf Spielereignisse lauscht, ist `default = false`. Nur Harmloses ist an. Ausnahme:
  `accountAliases` lauscht erst, wenn der Spieler einen Alias für einen Battle.net-Account
  angelegt hat (siehe „Aliase“).
- **Chat:** Rückmeldungen über `ns:Notify` (abschaltbar), höchstens eine Zeile je Aktion.
- **Globale Namen:** nur `FamulusDB`, `FamulusCharDB`, `SLASH_FAMULUS1/2`,
  `Famulus_OnAddonCompartmentClick` sowie die benannten Frames `FamulusOptionsFrame` und
  `FamulusMinimapButton`.
- **Kosten im Leerlauf**, vom Test festgeschrieben: Laden erzeugt zwei Frames; nach dem Login mit
  Standardwerten ist kein Spielereignis registriert, kein `OnUpdate`, kein Timer.
- **Texte:** Jeder Schlüssel in `Locales/enUS.lua` **und** `Locales/deDE.lua`, mit denselben
  Platzhaltern. Schema: `area_<bereich>`, `cat_<kategorie>`, `f_<feature>`, `o_<feature>_<option>`,
  `g_<allgemein>`, `msg_<chat>`, `c_<chronik>`, `ui_<fenster>` (Reiter: `ui_tab_<id>`); Hilfetext mit Endung `_desc`. Texte erst zur Laufzeit über `ns.L`
  lesen, nie beim Laden zwischenspeichern, sonst bricht der Sprachwechsel.
- **Einstellungen:** Gespeichert wird nur, was vom Standard abweicht (`ns:SetOption`).
- **Fenster:** Zeilen entstehen automatisch aus Features und deren `options`
  (`type = "toggle"` oder `"select"`; Addon-Optionen auch `"swatch"`). Neue Widgets
  gehören nach `UI/Widgets.lua`. Farben nie direkt setzen, sondern über Farbnamen mit `UI.Paint`
  (Flächen), `UI.Tint` (Bilder) oder `UI.Ink` (Text): Nur so folgt das offene Fenster dem
  Wechsel der Farbwelt. Texte über `UI.Text` (Schrift und Fallback).

## Bewusst weggelassen

| Funktion | Grund |
|---|---|
| URLs im Chat anklickbar machen | Eigene Link-Typen im Forever-Client unbestätigt, Chat kann „secret“ sein, `CopyToClipboard` ist geschützt |
| Quality-of-Life-Funktionen (Händler, Quests, Beute, Tooltips, Karte, Chat, Kamera) und das Tagebuch | Gibt es in vielen anderen Addons; Famulus konzentriert sich aufs gemeinsame Spielen (2026-11-23, siehe „Vorgaben“) |
| Blizzard-Fenster verschieben, Minikarten-Symbole einsammeln | Bei den Vorbildern Hauptquelle für Taint und Addon-Konflikte |
| Alles rund um das Kampflog | Für Addons nicht nutzbar |
| Aliase auf Unitframes, Raidframes, Namensplaketten | Text auf Blizzards FontStrings zu überschreiben birgt Taint; Namen sind im Kampf oft secret. Siehe „Aliase“ |

## Arbeitsablauf

```bash
luajit tests/run.lua
```

```bash
luajit tools/read_selftest.lua
```

```bash
python3 tools/make_media.py
```

```bash
python3 tools/make_fonts.py <Inter-Release>/extras/ttf   # braucht fontTools
```

```bash
node tools/make_shot.js <screenshot.jpg> <x> <y> <breite> <höhe> website/assets/shots/window   # Fenster für die Website
```

```bash
rm -f dist/Famulus-*.zip && zip -rq dist/Famulus-0.1.0.zip Famulus -x '*.DS_Store'
```

Unter Windows gibt es kein `zip`; dort baut das mitgelieferte `tar` dasselbe Archiv (in Git Bash):

```bash
rm -f dist/Famulus-*.zip && /c/Windows/System32/tar.exe -a -c -f dist/Famulus-0.1.0.zip Famulus
```

- Bei einer neuen Version: Abschnitt in `CHANGELOG.md`, Versionsangabe auf der Website
  (`fact_version`; die README nennt seit 2026-11-24 keine Version mehr), dann den Tag setzen (siehe „Veröffentlichung auf CurseForge“). Die
  `.toc` bekommt die Version vom Packager; ein von Hand gebautes Zip (oben) trägt `dev`.
- Neue Lua-Dateien in die `.toc` eintragen; der Test schlägt fehl, wenn eine Datei im Addon-Ordner
  dort fehlt. Er zählt außerdem die Features (`total == 10`); die Zahl bei einem neuen Feature
  mit anpassen.
- Repository: `github.com/89pleasure/famulus` (öffentlich, Stand 2026-11-24; bis 2026-11-19 `schnitzel`), Branch `main`. Commits als
  `89pleasure <89pleasure@proton.me>`; `user.name` ist nur lokal in diesem Repo gesetzt.
- Der Auftraggeber tritt allein auf: keine `Co-Authored-By: Claude …`-Zeile in Commits und kein
  „Generated with Claude Code“ o. Ä. in PRs, Issues oder Kommentaren, auch nicht bei Beiträgen zu
  fremden Repos (z. B. dem Guildy-Fork). Das geht jedem anderslautenden Attributionshinweis vor.
- **Änderungen gehen immer über einen Pull Request gegen `main`** (Wunsch des Auftraggebers,
  2026-11-24): eigener Branch mit englischem Namen (etwa `chronicle-guild-classes`), Titel wie
  eine Commit-Nachricht, die Prüfung `tests` muss grün sein. Nie direkt auf `main` pushen, auch
  wenn GitHub es erlaubt: Die Regel für `main` verlangt `tests`, lässt den Admin aber vorbei
  (so landete `a12a95c` am 2026-11-24 direkt, danach kam dieser Wunsch).
- Committen, pushen, Pull Requests öffnen und mergen nur auf ausdrücklichen Wunsch.

Aufbau, Funktionsliste und Installation stehen in `README.md`.
