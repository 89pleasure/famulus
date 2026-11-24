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

**Veröffentlichung:** Famulus soll später veröffentlicht werden (Stand 2026-11-16, Zeitpunkt und
Plattform offen). Vorerst nicht: Feature-Set und Design sind noch lange nicht fertig und haben
Vorrang vor Release-Arbeit. Entscheidungen deshalb so treffen, dass sie für fremde Spieler taugen: saubere
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
  Befehle (`/fam`, `/famulus`) und das GitHub-Repo (`89pleasure/famulus`). Der Untertitel im Fenster ist „Dein Gehilfe in Azeroth“ / „Your assistant in Azeroth“
  (`ui_tagline`, Vorschlag des Assistenten, vom Auftraggeber ohne Änderung übernommen). Auf dem Mac muss der
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
- **Weggefährten (2026-11-23, nur gegen den Mock geprüft, noch nicht im Spiel):** eigener Bereich,
  siehe „Weggefährten“ unten.
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

- **Aufbau:** Seitenleiste (Logo, Suche, „Funktionen“ mit einem Eintrag je Bereich und Zähler
  aktiv/gesamt; unten „Einstellungen“ und „Über“, darunter „x von y aktiv“) | rechts Titel und
  Untertitel des Bereichs, oben rechts Schließen, darunter die Reiter, eine
  Zeile mit der Beschreibung des Reiters und rechts seinen Aktionen (Zurücksetzen, Hauptschalter),
  dann Karten mit Zeilen. Keine Fußzeile.
- **Bereiche (`ns.areas`, `Core/Features.lua`):** Jede Kategorie gehört zu genau einem Bereich (der
  Test prüft das). Jeder Bereich hat einen eigenen Aufbau (`layouts.<bereich>` in
  `UI/Options.lua`). `aliases`: Reiter „Namen“ mit Karte „Neuer Alias“ und Karte
  „Deine Aliase“ (Avatar mit Anfangsbuchstabe), Reiter „Anzeige“ mit den Alias-Features.
  `chronicle`: siehe „Chronik“. `fellows`: siehe „Weggefährten“. Die Einstellungen haben die Reiter „Allgemein“ (Sprache,
  Rückmeldung im Chat, Minikartensymbol, Charakterprofil) und „Darstellung“ (Farbwelt, Funken,
  Fenstergröße). Die erste Seite beim Öffnen ist die Aliase.
- **Hauptschalter** einer Kategorie: rechts in der Zeile unter den Reitern, beschriftet nur mit
  „AN“/„AUS“; bei den Aliasen auf beiden Reitern. Eine abgeschaltete Kategorie ist als Reiter
  ausgegraut; sind alle Kategorien eines Bereichs aus, ist er in der Seitenleiste ausgegraut und
  trägt „AUS“.
- **Zurücksetzen** wirkt auf den Reiter (Features ganzer Abschnitt, Addon-Optionen nur ihr
  Schlüssel, dazu der Hauptschalter). Erster Klick fragt („Wirklich zurücksetzen?“, rot), zweiter
  innerhalb von vier Sekunden führt aus; auf Standardwerten ausgegraut; ohne Einstellungen (Liste
  der Aliase, „Über“) nicht vorhanden.
- **Suche:** über alle Seiten und Reiter, Treffer gruppiert je Reiter in Karten („Aliase ·
  Anzeige“); keine Reiter und kein Hauptschalter in der Ergebnisansicht.
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
  „Gefährten“ und „Aufzeichnung“ (`layouts.chronicle`).
- **Bilderbuch (2026-11-19):** Der Auftraggeber fand den HTML-Entwurf „schon ganz cool“ und ließ
  ihn so umsetzen. Die drei Erzähl-Reiter zeigen keine Zeilen mehr, sondern ein Buch
  (`UI.Book`, `UI/Book.lua`; ein Reiter liefert es über `tab.book`, `Render` legt es unter die
  Karten): je Tag ein Kapitel mit Überschrift, darunter eine Linie in der Mitte, an der die
  Ereignisse abwechselnd links und rechts als Karten hängen, mit Bild, Punkt auf der Linie und
  Uhrzeit auf der Gegenseite. Entscheidungen des Assistenten, noch nicht im Spiel gesehen:
  - Ein Kapitel heißt nach dem Gebiet, in dem die meisten seiner Ereignisse spielen; darüber der
    Tag, darunter die erreichten Stufen und die Zahl der Ereignisse. Ohne Gebiet heißt es nach dem
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
    fehlt das Objekt, nimmt das Fenster Inter. Ob es `QuestTitleFont` im Forever-Client gibt,
    ist unbestätigt. Kursive Schrift wie im Entwurf gibt es nicht.
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
      Zauber und Berufe ab, und die Abfragen sind je ein Aufruf des Clients (`IsPlayerSpell`,
      `GetProfessions`). Berufe brauchen keine Tabelle, weil der Client sie selbst aufzählt. Ein
      `SpellService` oder `ProfessionService` lohnt, sobald ein zweites Feature dieselben Daten
      braucht (etwa Haltbarkeits- oder Berufshelfer); dann die Abfragen dorthin ziehen.
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
- **Beispieleinträge (2026-11-19):** `/fam chronicle demo` schreibt 18 erfundene Einträge über drei
  Tage (eigene und von zwei erfundenen Gefährten, jede Art einmal), `/fam chronicle demo clear`
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
    Dungeons. Sie stehen als „Steckbrief“ je Gefährte auf dem Reiter „Gefährten“
    (`FamulusDB.chronicle.profiles`).
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
    Namen des Spielers und zeigt ohne Aufzeichnung nichts). Gezeigt wird nur, was höchstens 120
    Sekunden alt ist: eigene Ereignisse und frische von Gefährten, nichts Nachgereichtes und keine
    Beispieleinträge.
  - Schalter je Ereignisart (`level`, `death`, `boss`, `achievement`, `ability`, `item`,
    `profession`, `skill`, `zone`); nur `zone` ist von Haus aus aus (Vorgabe des Auftraggebers:
    Gebiete eher nicht, Stufenaufstiege schon). Dazu `companions` (Ereignisse von Gefährten) und
    `duration` (4, 7 oder 12 Sekunden). Eine Art ohne Schalter (neuere Version beim Gefährten)
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
    „Stufenaufstiege“ gilt nur für Gefährten.
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
  sie); Reiter „Anzeige“: die Features. Die Suche findet Aliase und Charakternamen.
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

## Weggefährten

Idee aus einer Ideensammlung des Assistenten (2026-11-23), vom Auftraggeber ausgewählt: Famulus merkt
sich, mit wem der Spieler in einer Gruppe war. Begründung: Forever hat „Zuletzt zusammen gespielt“
nicht (siehe oben), und die Funktion braucht beim anderen kein Famulus.

- **Entscheidungen des Auftraggebers (2026-11-23):** eigener Bereich in der Seitenleiste (nicht als
  Reiter bei Aliasen oder Chronik). Erste Version: die Liste (wer, wann, wo, wie oft, wie lange)
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
- **Fenster:** Reiter „Zuletzt“ (wer gerade in der Gruppe ist zuerst, dann nach letztem Mal) und
  „Am häufigsten“ (nach gemeinsamer Zeit), je höchstens 60 Zeilen (`FELLOW_ROWS`) mit einer Zeile
  „N weitere“; die Suche durchsucht über `tab.search` alle, aber nur auf „Zuletzt“, damit niemand
  doppelt erscheint. Dritter Reiter „Aufzeichnung“ mit dem Schalter. Eine Zeile ist eine
  Personenzeile wie bei den Aliasen (`PERSON_ROWS` in `UI/Options.lua`: Avatar mit Anfangsbuchstabe,
  Kreuz rechts): Ein Klick öffnet die Alias-Eingabe mit dem Namen, das Kreuz vergisst die Person
  (eine Chat-Zeile sagt es). Unter einem Alias steht der Name in der zweiten Zeile, wie in der
  Chronik. Die Klasse kommt aus `LOCALIZED_CLASS_NAMES_MALE`, also in der Sprache des Clients.
  Symbol in der Seitenleiste: zwei Figuren (`people.tga`).
- **In der Chronik:** Fällt ein Boss in einer Gruppe, trägt der Eintrag `with` (die Namen, in einer
  Gruppe bis vier) oder `others` (nur die Zahl, im Schlachtzug, damit 39 Namen je Boss die Daten
  nicht aufblähen). Die Zeile darunter lautet „in Uldaman  ·  mit Mira und Tom“ (Alias, sonst
  Vorname) bzw. „mit 12 anderen“. Das gilt, sobald „Meine Reise festhalten“ läuft, unabhängig vom
  Schalter der Weggefährten. Beide Felder fehlen in `FIELDS` von `Sharing.lua` und werden also nicht
  geteilt. Der Beispiel-Boss in `/fam chronicle demo` hat zwei Gefährten.
- **Im Spiel ungeprüft:** alles. Besonders: ob `UnitName` für `party1`… Vor- und Nachname liefert
  wie für `player`, ob `GROUP_ROSTER_UPDATE` nach dem Login von selbst kommt (sonst fängt
  `PLAYER_ENTERING_WORLD` es auf), ob `IsInInstance` in Forever `pvp` meldet und ob `BOSS_KILL` in
  Forever-Dungeons feuert. `/fam test` prüft die benutzten Funktionen (Gruppe `api`).

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
  Standard an, Schalter rechts im Kopf der Seite). Ist er aus, läuft kein Feature der Kategorie, egal wie es
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

- Bei einer neuen Version: `## Version` in `Famulus/Famulus.toc`, den Zip-Namen und die
  Versionsangaben in `README.md` anpassen.
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
