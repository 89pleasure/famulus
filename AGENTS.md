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
   Die Funktionen sind die **Aliase**, die **Chronik** und die **Weggefährten** (seit 2026-11-23).
   Keine Unitframes, Aktionsleisten, Guides, Schadensanzeigen oder Ähnliches.
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
Commit-Nachrichten sind Englisch, README und diese Datei Deutsch.

## Stand der Prüfung

- `luajit tests/run.lua` lädt das Addon gegen eine nachgestellte Client-API (`tests/wowmock.lua`)
  und prüft jedes Feature, das Fenster und die Übersetzungen. Muss vor jedem Commit grün sein.
- Der Mock beweist die eigene Logik, nicht das Verhalten des Clients. Dafür gibt es den Selbsttest
  im Spiel, siehe „Test im Spiel“.
- Secret Values im Mock: `mock.SECRET` verweigert Index, Rechnen, Vergleich und Verketten.
  Eine Wahr/Falsch-Prüfung (`not x`) lässt sich in Lua nicht abfangen; deshalb prüft der Test im
  Quelltext, dass `ns.IsSecret(x)` vor jedem Test von `x` steht.
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
  Fenster“ unten. Offen im Spiel: ob die Inter-Schriften laden (`/fam test`, Gruppe `media`, Prüfungen
  `font …`), ob runde Ecken, Schatten und Haarlinien sauber aussehen, das Umschalten
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
- **Noch nicht im Spiel geprüft:** die übrigen Aliase (Kontextmenü, Tooltip, Eingabezeile im Fenster),
  im Fenster das Dropdown, die Suche und das Scrollen, Verhalten im Kampf (Secret Values, Taint).
- **Selbsttest 2026-11-19** (Client 1.60.1, Build 70959, deDE): 80 ok, 3 Warnungen, 0 fehlgeschlagen;
  629 KB bei 8 aktiven Features und 4 Spielereignissen.
  - Die drei Inter-Schriften laden nicht (`SetFont` liefert falsch); das Fenster nimmt die
    Spielschrift. Ursache (per `/run` geprüft): Der Client lädt eine Schriftdatei beim ersten
    `SetFont` im Hintergrund; dieser erste Aufruf liefert falsch, ein späterer wahr. Symlink und
    das Kürzen der Dateien sind es nicht (Polestars ungekürztes Inter verhielt sich gleich).
    Jetzt fragt `UI/Theme.lua` die Schriften schon beim Login an; im Spiel noch nicht bestätigt
    (der Selbsttest nach dem Login muss die Prüfungen `font …` als ok melden). Dieselben Dateien
    in einem Probe-Ordner ohne `.toc` blieben auch beim zweiten Aufruf falsch, vermutlich wegen
    der fehlenden `.toc`.
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
  Test prüft das). Jeder Bereich hat einen eigenen Aufbau (`layouts.<bereich>` in
  `UI/Options.lua`). `aliases`: Reiter „Namen“ mit Karte „Neuer Alias“ und Karte
  „Deine Aliase“ (Avatar mit Anfangsbuchstabe), Reiter „Einstellungen“ (bis 2026-11-23 „Anzeige“) mit den Alias-Features.
  `chronicle`: siehe „Chronik“. `fellows`: siehe „Weggefährten“. Die Einstellungen haben die Reiter „Allgemein“ (Sprache,
  Rückmeldung im Chat, Minikartensymbol, Charakterprofil) und „Darstellung“ (Farbwelt, Funken,
  Fenstergröße). Die erste Seite beim Öffnen ist die Aliase.
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
  `tools/make_fonts.py` auf Latein, Griechisch, Kyrillisch und Satzzeichen gekürzt (je ~100 KB,
  beim Login angefragt, weil der Client sie im Hintergrund lädt und der erste `SetFont` falsch
  liefert). Auf koKR/zhCN/zhTW-Clients bleibt die Spielschrift. Lädt eine Datei nicht, nimmt
  `UI.SetFont` die Spielschrift.
  **Beobachtet 2026-11-24, ungeklärt:** Der Name des Reiters „Chronik“ im Kopf blieb leer,
  über mehrere Seitenwechsel hinweg; Breite und Zähler stimmten, der Client kannte den Text also.
  Einmal fehlte auch der Zähler und erschien erst, als sich seine Zahl änderte. Nach `/reload`
  war alles da. Vermutung (unbestätigt): Der Text wurde gesetzt, bevor die Schrift fertig geladen
  war, und weil er sich nicht ändert, zeichnet der Client ihn nicht neu. Tritt es wieder auf,
  festhalten, wie lange nach dem Login das Fenster zum ersten Mal offen war.
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
  - **Kapitelkopf in einer Zeile:** Tag links, Gebiet in der Buchschrift (22 px) in der Mitte,
    Stufen und Zahl der Ereignisse rechts, außen je eine Linie, die zum Rand hin ausläuft. Etwa
    36 px hoch statt über 100. Die Zierde mit dem Funken ist entfallen.
- **Bilderbuch (2026-11-19):** Der Auftraggeber fand den HTML-Entwurf „schon ganz cool“ und ließ
  ihn so umsetzen. Die drei Erzähl-Reiter zeigen keine Zeilen mehr, sondern ein Buch
  (`UI.Book`, `UI/Book.lua`; ein Reiter liefert es über `tab.book`, `Render` legt es unter die
  Karten): je Tag ein Kapitel mit Überschrift, darunter eine Linie in der Mitte, an der die
  Ereignisse abwechselnd links und rechts als Karten hängen, mit Bild, Punkt auf der Linie und
  Uhrzeit auf der Gegenseite. Entscheidungen des Assistenten, noch nicht im Spiel gesehen:
  - Ein Kapitel heißt nach dem Gebiet, in dem die meisten seiner Ereignisse spielen; daneben der
    Tag und die erreichten Stufen mit der Zahl der Ereignisse (seit 2026-11-23 in einer Zeile,
    siehe oben; vorher darüber und darunter). Ohne Gebiet heißt es nach dem
    Tag. Eine Kapitelnummer wie im Entwurf gibt es nicht (gezeigt werden nur die letzten 50
    Ereignisse, eine Zählung wäre nicht stabil).
  - Bilder sind eigene Symbole (`skull.tga`, `swords.tga`, `peaks.tga`, `star.tga`, 64 px) oder
    bei Stufen die Zahl; Tod und Boss haben feste eigene Farbtöne, der Rest folgt der Farbwelt.
    Der eigene Stufenaufstieg ist der Meilenstein: größere Karte, Akzentrand, Akzentmarke links
    (der Schein ist seit dem Angleichen an die Options-Karten entfallen).
  - Ereignisse von Gefährten und von eigenen anderen Charakteren tragen eine Marke mit
    Anfangsbuchstabe.
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
    ist, kommen über einen verbundenen Gefährten, der sie hat. Auf einen Gruß folgen bis zu 20
    Angebote `1~O~<wer>~<zeit>`; wer daraus Neues erwartet, fragt mit `1~W~<wer>~<seit>` und bekommt
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
    <zeit>“), `1~E~<zeit>~<art>~k=v;k=v` (ein Eintrag), `1~S~<stufe>~id=n;id=n` (Statistiken).
  - Ein Gruß geht an jeden Freund, der online kommt. Wer antwortet, gilt für die Sitzung als
    verbunden und bekommt die eigenen Meilensteine live. Auf einen Gruß folgen bis zu 20 verpasste
    Einträge und die Statistiken.
  - Geteilte Statistiken (IDs des Spiels): 60 Tode, 107 besiegte Kreaturen, 98 Quests, 932 betretene
    Dungeons. Sie stehen als „Bilanz“ je Person in der Randspalte des Reiters „Freunde“
    (`FamulusDB.chronicle.profiles`; im Code heißen sie weiter `profile`).
  - Alles läuft über eine Warteschlange mit Ticker (eine Nachricht je halbe Sekunde, nur solange
    etwas wartet). Während der Chat-Sperre (Bosskampf, gesperrte Karte) bleibt sie stehen.
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
wird verschickt, bis 500 Personen). Sie waren aber an vier Stellen ineinander gewachsen: dasselbe
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
- **Ideen, die nur die Weggefährten können** (vorgeschlagen, nicht beauftragt): Stammgruppen
  (wer immer wieder gemeinsam in der Gruppe ist) und gemeinsame Dungeons je Person.

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
  times, seconds, bosses } }`, accountweit, außerhalb der Profile, nach GUID (ein Name kann sich
  ändern). Nichts davon wird verschickt. Höchstens 500 Personen; darüber fällt heraus, wer am
  längsten nicht mehr dabei war (nie jemand aus der aktuellen Gruppe).
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
  - Tabs „Übersicht“ und „Einstellungen“. Symbol: zwei Figuren (`people.tga`).
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
    links, Buch rechts statt eines breiten Kopfes über einem zu breiten Buch) mit einem Kapitel je Tag im
    Tagesprotokoll, das neueste zuerst: Gebiet des Tages, „N Std. zusammen“; Ereignisse
    „Gemeinsam unterwegs“ (von bis; Bosse ohne Namen, etwa aus einem Schlachtzug, als Zahl
    dahinter; die Dauer stand bis 2026-11-24 auch dort, brach um und wiederholte den
    Kapitelkopf, deshalb auf Wunsch des Auftraggebers entfernt), je Boss mit Namen eine Karte („Archaedas bezwungen“, „in Uldaman“), „Ihr seid
    jetzt <Stufe>“ am Tag eines Aufstiegs und „Kennengelernt“ (auf Stufe N). Fehlt der erste Tag
    im Protokoll, bekommt das Kennenlernen ein eigenes letztes Kapitel. Seit 2026-11-24 steht dort
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
  erfundene Weggefährten ein (Klassen, Stufen, Gebiete, Zeiten von 25 Minuten bis 31 Stunden; Mira
  und Borin wie in der Chronik), `/fam fellows demo clear` entfernt nur sie
  (`FellowService.Demo`, `ClearDemo`). Sie tragen `demo = true` und GUIDs `Player-0-FAMDEMO..`;
  seit 2026-11-24 auch Tage und `firstLevel`, sodass Mira und Borin einen Aufstieg erzählen, und
  an Tagen in Uldaman oder den Todesminen Bosse mit Namen (je Person reihum, damit derselbe Boss
  nicht an jedem Tag fällt).
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
- **Aufbau:** Kopf (Landschaft, rechts laufen Einblendungen mit) → 01 Aliase (das Fenster
  nachgebaut und bedienbar, darunter Chat und Tooltip „im Spiel“) → 02 Chronik (das Bilderbuch mit
  den Reitern Alle, Meine Reise, Gefährten) → 03 Weggefährten (seit 2026-11-24) → 04
  Live-Einblendung (auslösbar, Platz verschiebbar) → 05 Installation → Fuß mit Hinweis auf
  Blizzards Marke. Die Demos zeigen erfundene
  Personen und die Beispiele aus `/fam chronicle demo`, mit den eigenen Zeichnungen statt
  Spielsymbolen. Ein Alias aus der ersten Demo erscheint auch im Bilderbuch, in den
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
  - **Fenster:** wie im Addon Kopf mit Logo, den drei Bereichen als Reiter mit Zähler (Aliase,
    Chronik, Weggefährten; nur Aliase bedienbar), „Einstellungen“ und „Über“ rechts; Seitenleiste
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
  neuer Addon-Ordner sonst womöglich nicht gefunden wird; im Spiel ungeprüft, die README sagt
  weiter `/reload`). Dazu: Einblendungen und Funken laufen nur, wenn sie zu sehen sind; „weniger
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
  - Die Einblendungen rechts stehen höher (`margin-top: -26vh`), über dem Mond. Bei 1280 × 720
    ragt die zweite noch etwas in die Baumkrone.
  - Geprüft im eingebauten Browser und mit Chrome ohne Fenster bei 375, 768, 1280, 1440 und
    1920 px Breite, Deutsch und Englisch; keine Meldungen in der Konsole. Nicht geprüft: Safari,
    Firefox, echte Mobilgeräte.
- **Sprachen:** Englisch steht im HTML (`data-i18n="schlüssel"`), Deutsch in `i18n.js`; was
  Skripte zusammensetzen, steht dort in beiden Sprachen. Die Sprache folgt dem Browser, ist
  umschaltbar und lässt sich mit `?lang=de` erzwingen. Fehlt einer Sprache ein Schlüssel, warnt
  die Konsole.
- **Bewusst noch nicht enthalten:** ein Download (die Veröffentlichung ist offen; der Knopf sagt
  „Download folgt“), Guildy (erst wenn der PR dort angenommen ist), Screenshots aus dem Spiel, Impressum und Datenschutzerklärung (vor dem
  Veröffentlichen nötig), Hosting und Domain (offen), ein Vorschaubild für geteilte Links,
  WOFF2-Schriften (geladen werden die TTF aus dem Addon, je ~100 KB).
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
- **Bei Änderungen am Addon mitziehen:** Versionsnummer (`fact_version`, `in_rel_d`), die Zähler
  im nachgebauten Fenster (`renderWindow` in `main.js`: 5 Alias-Features, 10 insgesamt; im HTML
  Chronik 1/4 und Weggefährten 0/1), neue Hauptfunktionen als Reiter im Kopf und als eigener
  Abschnitt mit Eintrag in der Navigation; die Stufen der Verbundenheit (`TIERS` in `main.js`)
  wie `FellowService.TIERS`.

## Veröffentlichung auf CurseForge

Wunsch des Auftraggebers (2026-11-24): eine erste Alpha auf CurseForge, mit automatischem Upload.
Eingerichtet am 2026-11-24 nach dem Vorbild von FlareUI und Guildy; der Aufbau im Einzelnen ist eine
Entscheidung des Assistenten. Hochgeladen ist noch nichts.

- **Werkzeug:** der BigWigs-Packager (`BigWigsMods/packager@v2`) als GitHub Action in
  `.github/workflows/release.yml`. Er bildet `## Interface: 16001` auf die CurseForge-Spielversion
  „WoW Forever“ ab (laut Quellcode `16???` → `forever`, Versionstyp 88568). `.pkgmeta` hebt den
  Unterordner `Famulus/` per `move-folders` an die Spitze des Zips (CurseForge will genau einen
  Ordner, benannt wie die `.toc`) und lässt den Rest des Repos draußen. Lokal mit dem Packager
  geprüft (`release.sh -d -z`): ein Ordner `Famulus` mit den Dateien des Addons, Version ersetzt.
- **Ausgelöst wird nur durch einen Tag** `v…`, den der Auftraggeber selbst setzt. Pushes und Pull
  Requests laden nie hoch; dort laufen nur die Tests (`.github/workflows/tests.yml`).
- **Der Tag bestimmt den Dateityp.** `tools/release_check.sh` lässt nur drei Formen zu: `v1.2.3`
  (Release), `v1.2.3-beta.1` (Beta), `v1.2.3-alpha.1` (Alpha). Grund (Vorgabe des Auftraggebers:
  nichts mit „alpha“ oder „beta“ darf als normaler Release erscheinen): Der Packager lädt jeden Tag
  ohne diese Wörter als Release hoch, `v0.2.0-rc1` wäre sonst bei allen Spielern gelandet. Das
  Skript prüft außerdem, dass `CHANGELOG.md` einen Abschnitt `## <version>` (Tag ohne „v“) mit
  Text hat, dass die `.toc` eine `## X-Curse-Project-ID` trägt und dass das Secret `CF_API_KEY`
  gesetzt ist. Erst danach laufen die Tests, und nur wenn sie grün sind, baut und lädt der Packager.
- **Ablauf eines Release:** Abschnitt in `CHANGELOG.md` schreiben (Englisch, wird der Changelog der
  Datei auf CurseForge), committen, pushen, dann `git tag v0.1.0` und `git push origin v0.1.0`.
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
  `## X-Curse-Project-ID` in der `.toc`.
- **Offen:**
  - API-Token als Repository-Secret `CF_API_KEY`; setzt der Auftraggeber selbst, der Token geht
    nicht durch den Assistenten.
  - Dateityp der ersten Datei. Empfehlung des Assistenten: `v0.1.0` als Release mit „Alpha“ in
    Beschreibung und Changelog, damit Famulus in der App erscheint.
  - Projektseite: Summary vom Auftraggeber gewählt („Your companion for playing together: Famulus
    helps you stay close to the friends and fellow adventurers who make your journey so
    special.“); die Beschreibung liegt als Entwurf des Assistenten in
    `docs/curseforge/description.md` (Englisch, Markdown, ohne Guildy, weil dessen Anbindung nur
    mit dem Fork geht). Kategorien: Der Assistent rät von „Companions“ ab (auf CurseForge
    Haustiere und Reittiere) und empfiehlt „Chat & Communication“ mit „Guild“.
  - Nicht eingerichtet: Wago, GitHub-Releases, eine Freigabe-Umgebung für die Secrets.
- Auf GitHub ist der Workflow noch nie gelaufen; geprüft sind nur der lokale Probelauf des
  Packagers und `release_check.sh` mit gültigen und ungültigen Tags.

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
  Kategorien liegt ein Service unter `Core/` (`ChatService`: Klartext prüfen, Chat-Sperre prüfen),
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
rm -f dist/Famulus-*.zip && zip -rq dist/Famulus-0.1.0.zip Famulus -x '*.DS_Store'
```

Unter Windows gibt es kein `zip`; dort baut das mitgelieferte `tar` dasselbe Archiv (in Git Bash):

```bash
rm -f dist/Famulus-*.zip && /c/Windows/System32/tar.exe -a -c -f dist/Famulus-0.1.0.zip Famulus
```

- Bei einer neuen Version: Abschnitt in `CHANGELOG.md`, Versionsangaben in `README.md` und auf
  der Website (`fact_version`), dann den Tag setzen (siehe „Veröffentlichung auf CurseForge“). Die
  `.toc` bekommt die Version vom Packager; ein von Hand gebautes Zip (oben) trägt `dev`.
- Neue Lua-Dateien in die `.toc` eintragen; der Test schlägt fehl, wenn eine Datei im Addon-Ordner
  dort fehlt. Er zählt außerdem die Features (`total == 10`); die Zahl bei einem neuen Feature
  mit anpassen.
- Repository: `github.com/89pleasure/famulus` (privat; bis 2026-11-19 `schnitzel`), Branch `main`. Commits als
  `89pleasure <89pleasure@proton.me>`; `user.name` ist nur lokal in diesem Repo gesetzt.
- Der Auftraggeber tritt allein auf: keine `Co-Authored-By: Claude …`-Zeile in Commits und kein
  „Generated with Claude Code“ o. Ä. in PRs, Issues oder Kommentaren, auch nicht bei Beiträgen zu
  fremden Repos (z. B. dem Guildy-Fork). Das geht jedem anderslautenden Attributionshinweis vor.
- Committen und pushen nur auf ausdrücklichen Wunsch.

Aufbau, Funktionsliste und Installation stehen in `README.md`.
