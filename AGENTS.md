# Famulus – Projektwissen für KI-Assistenten

Famulus ist ein Quality-of-Life-Addon für **World of Warcraft: Forever**. Diese Datei hält fest,
was der Auftraggeber will, was entschieden wurde und was man über den Forever-Client wissen muss.
Stand: 2026-11-18, Version 0.1.0.

## Vorgaben des Auftraggebers

Der Auftraggeber spielt WoW Forever und hat drei Sammel-Addons ausprobiert, die ihm gefallen:
**OneForAll**, **FlareUI** und **Polestar**. Famulus soll sich an ihnen orientieren und sich auf
Folgendes konzentrieren und beschränken:

1. **Modernes, übersichtliches Layout.** Polestar gefällt ihm bisher am besten.
2. **Vorerst nur Quality-of-Life-Funktionen.** Keine Unitframes, Aktionsleisten, Guides,
   Schadensanzeigen oder Ähnliches.
3. **Schwachstellen der drei Vorbilder analysieren und daraus lernen.**
4. **Performance-optimiert.**
5. **Mehrsprachig.** Englisch und Deutsch reichen vorerst.

**Veröffentlichung:** Famulus soll später veröffentlicht werden (Stand 2026-11-16, Zeitpunkt und
Plattform offen). Vorerst nicht: Feature-Set und Design sind noch lange nicht fertig und haben
Vorrang vor Release-Arbeit und der Testrunde der Automatiken. Entscheidungen deshalb so treffen, dass sie für fremde Spieler taugen: saubere
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
  - `cameraZoom`: Der CVar `cameraDistanceMaxZoomFactor` nimmt 4,0 an (Standard 1,0). Ob die Kamera
    dann wirklich weiter herauszoomt als bei 2,6, ist nicht geprüft.
  - Popups: Alle benutzten Namen existieren in `StaticPopupDialogs` (`LOOT_BIND`, `PARTY_INVITE`,
    `DUEL_REQUESTED`, `QUEST_ACCEPT`, `DELETE_GOOD_ITEM`, `DELETE_GOOD_QUEST_ITEM`); der Dialog hat
    `GetEditBox()`.
  - `hideErrors`: Alle 27 Fehlertext-Globals aus `BLOCKED_GLOBALS` existieren.
  - `mapCoords`: `WorldMapFrame.ScrollContainer:GetNormalizedCursorPosition` existiert, die
    Spielerposition ist lesbar.
  - Speicher: 360 KB bei 6 aktiven Features und 5 Spielereignissen.
- **Spielrunde 2026-11-16:**
  - `autoRepair` funktioniert.
  - `chatArrowKeys` wirkte nicht. Blizzards Chat-Eingabefeld (`ChatFrameEditBoxTemplate`) setzt
    `ignoreArrows="true"`, und Blizzards Autovervollständigung (`AutoComplete.lua`) schaltet den
    Alt-Modus beim Ein- und Ausblenden um. Das Feature setzt den Modus deshalb zusätzlich bei jedem
    Fokus neu (`EventRegistry`-Callback `ChatFrame.OnEditBoxFocusGained`); der Selbsttest prüft
    den Modus aller Chatfelder. Danach bewegte sich der Cursor (bestätigt), aber Hoch/Runter holte
    keine gesendeten Nachrichten: Der eingebaute Verlauf des Clients reagiert in Forever nicht
    (OneForAll vermerkt dasselbe, FlareUI baut ihn ebenfalls nach). Famulus führt deshalb eine
    eigene Liste nach FlareUIs Muster: Zeile beim Enter (`OnKeyDown`-Hook) und bei
    `ChatFrame.OnEditBoxPreSendText` merken, mit Ziel als Präfix (`/w Name …`, `/2 …`) statt
    Attribute zu setzen; sichere Befehle (`IsSecureCmd`) nie, weil sie aus Addon-Code blockiert
    werden; Blizzards Liste nach dem Senden leeren; nicht bei offener Namensliste
    (`AutoCompleteBox`) oder Chat-Sperre. Nur im Speicher, 30 Zeilen; Zustand je Feld in lokalen
    Tabellen, nichts auf Blizzards Frames. Im Spiel bestätigt: Cursor und Blättern funktionieren.
  - `fastLoot` brachte in diesem Client nichts: Blizzards automatisches Plündern ist von sich aus
    schnell. Ersetzt durch `autoLoot`. Zuerst stellte es beim Abschalten den vorherigen Wert
    wieder her; das wirkte im Spiel wie ein Fehler (Option blieb an). Auf Wunsch des Auftraggebers
    spiegelt der Schalter jetzt `autoLootDefault` wie bei OneForAll: an setzt „1“, aus setzt „0“,
    und Änderungen in Blizzards Menü übernimmt der Schalter sofort, ohne zu schreiben. Daraus
    wurde der allgemeine Baustein `mirror` (siehe „Gespiegelte Spieloptionen“ unten). Der Kategorie-Hauptschalter lässt die Spieloption unberührt. Die Idee,
    Famuluss Fenster und Blizzards Spielmenü sich gegenseitig schließen zu lassen, wurde
    verworfen: Blizzards Panels aus Addon-Code zu schließen birgt Taint-Risiko, und der Live-Abgleich
    macht es unnötig. Im Spiel bestätigt: Spiegeln in beide Richtungen mit dem `mirror`-Baustein.
  - Klick auf das Koordinatenfeld (`mapCoords.clickToChat`): Bei offener, leerer Chat-Eingabe mit
    `/y` landete die Position als `/s`. Ursache: Der Klick nimmt der Eingabe den Fokus, Blizzards
    `OnEditFocusLost` schließt eine leere Eingabe und setzt dabei den Chat-Typ zurück
    (`ResetChatTypeToSticky`), bevor unser Klick ankommt. Das Signal
    `ChatFrame.OnEditBoxFocusLost` feuert vor dem Zurücksetzen; dort liest das Feature das Ziel
    (`ChatService.TargetPrefix`) und öffnet die Eingabe mit „/y …“ neu. Das Signal wird nur
    abonniert, solange die Maus über dem Feld steht. Im Spiel bestätigt.
  - Koordinatenfeld: Die Breite schwankte mit den Ziffern. Jetzt feste Spalten (Beschriftung,
    Wert); der Wertplatz ist so breit wie „00.0, 00.0“ in der breitesten Ziffer der Schrift,
    neu vermessen nur beim Aufbau und Sprachwechsel. Im Spiel bestätigt.
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
- **Noch nicht im Spiel geprüft:** die übrigen Aliase (Kontextmenü, Tooltip, Eingabezeile im Fenster), das Verhalten der Automatiken (reparieren, verkaufen, Quests,
  Beute, Einladungen, Duelle, Zerstören), im Fenster das Dropdown, die Suche und das Scrollen, Verhalten im Kampf (Secret Values,
  Taint).
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
  - Der Entwicklermodus war an, `devLog` blieb trotzdem leer: Die Blockade kam nicht über
    `ADDON_ACTION_BLOCKED`/`_FORBIDDEN` mit dem Addon-Namen an. Ursache offen; `devLog` ist für
    blockierte Aktionen also kein verlässlicher Beleg.

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
- Was der Selbsttest nicht abdeckt: das Verhalten der Automatiken (verkaufen, reparieren, Quests,
  Einladungen). Das zeigt nur das Spielen selbst.

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
    erlaubt. Prüfen mit `issecretvalue(v)`; im Addon über `ns.IsSecret` und `ns.Label`.
  - `COMBAT_LOG_EVENT_UNFILTERED` ist für Addons unbrauchbar.
  - `CopyToClipboard` ist geschützt. Chat-Nachrichten können im Kampf „secret“ sein.
- Felder auf Blizzards StaticPopup-Dialoge zu schreiben verursacht Taint („Aktion blockiert“);
  bei Polestar als Fehler gemeldet.
- Spielinhalt: Stufe 60, Vanilla-ähnliche Welt, nur Bodenreittiere, vier Taschen plus
  Reagenzientasche.
- Schon in der Standard-UI enthalten, also nicht nachbauen: automatisches Plündern,
  Taschen sortieren, Edit Mode, Abklingzeit-Zahlen, Schadensanzeige, sofortiger Questtext.

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
in der Seitenleiste mit eigenem Aufbau je Funktion, Quality of Life in Reitern, modern und
schlicht wie Polestar, helles und dunkles Design (das helle ist seit 2026-11-19 wieder entfernt,
siehe „Farben“), runde Ecken, eigene Schrift. Er hat freie Hand
gelassen; Aufbau, Farben und Schrift sind Entscheidungen des Assistenten und noch nicht bestätigt.

- **Aufbau:** Seitenleiste (Logo, Suche, „Funktionen“ mit einem Eintrag je Bereich und Zähler
  aktiv/gesamt; unten „Einstellungen“ und „Über“, darunter „x von y aktiv“) | rechts Titel und
  Untertitel des Bereichs, oben rechts Schließen, darunter die Reiter, eine
  Zeile mit der Beschreibung des Reiters und rechts seinen Aktionen (Zurücksetzen, Hauptschalter),
  dann Karten mit Zeilen. Keine Fußzeile.
- **Bereiche (`ns.areas`, `Core/Features.lua`):** Jede Kategorie gehört zu genau einem Bereich (der
  Test prüft das). `qol` zeigt seine sechs Kategorien als Reiter; `aliases` hat einen eigenen
  Aufbau (`layouts.aliases` in `UI/Options.lua`): Reiter „Namen“ mit Karte „Neuer Alias“ und Karte
  „Deine Aliase“ (Avatar mit Anfangsbuchstabe), Reiter „Anzeige“ mit den Alias-Features. Die
  Einstellungen haben die Reiter „Allgemein“ und „Darstellung“ (Farbwelt, Funken,
  Fenstergröße). Ein Bereich ohne eigenen Aufbau bekommt je Kategorie einen Reiter.
- **Hauptschalter** einer Kategorie: rechts in der Zeile unter den Reitern, beschriftet nur mit
  „AN“/„AUS“; bei den Aliasen auf beiden Reitern. Eine abgeschaltete Kategorie ist als Reiter
  ausgegraut; sind alle Kategorien eines Bereichs aus, ist er in der Seitenleiste ausgegraut und
  trägt „AUS“.
- **Zurücksetzen** wirkt auf den Reiter (Features ganzer Abschnitt, Addon-Optionen nur ihr
  Schlüssel, dazu der Hauptschalter). Erster Klick fragt („Wirklich zurücksetzen?“, rot), zweiter
  innerhalb von vier Sekunden führt aus; auf Standardwerten ausgegraut; ohne Einstellungen (Liste
  der Aliase, „Über“) nicht vorhanden.
- **Suche:** über alle Seiten und Reiter, Treffer gruppiert je Reiter in Karten („Quality of Life ·
  Händler“); keine Reiter und kein Hauptschalter in der Ergebnisansicht.
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

## Tagebuch

Seit 2026-11-19, auf Wunsch des Auftraggebers als Alleinstellungsmerkmal: Schalter-Sammlungen
(Leatrix Plus, ForeverPlus, OneForAll), Spielernotizen (Worth Remembering, Zecho, Dossier) und
Gold-Buchhaltungen (GoldLedger, Sesh, Allemano Ledger) gibt es für Forever schon. Famulus soll sich
als Gehilfe abheben, der Rechenschaft ablegt: Es führt Buch über das, was es selbst für den
Spieler getan hat, und über das, was es bewusst gelassen hat. Weitere Ideen in dieser Richtung,
noch nicht beschlossen: Erinnerungen nach Ort und Situation, selbst gebaute Wenn-dann-Regeln.
Nur gegen den Mock geprüft, noch nicht im Spiel.

- **Eine Meldestelle:** Jede Automatik meldet eine Aktion genau einmal über
  `ns.JournalService.Report(art, werte)` (`Core/JournalService.lua`); daraus entstehen die
  Chat-Zeile (nur für Arten mit `chat = true`) und der Eintrag. Neue Automatiken melden dort
  und rufen `ns:Notify` nicht mehr selbst. Die Quest-Features nutzen `QuestService.Report`.
- **Arten:** `repair`, `repairShort` (zu wenig Gold), `junk` (mit bis zu 12 Gegenständen),
  `questAccepted`, `questTurnedIn`, `questSkipped` (Grund `repeatable`, `trivial`, `pvp`, `cost`,
  `choice`), `invite`, `duel`, `loot`. Quests und Beute schreiben nur ins Tagebuch, nicht in den
  Chat. `easyDelete` meldet nichts, weil dort der Spieler selbst klickt.
- **Ausgelassenes** (`skipped`) steht grau im Verlauf, zählt in keiner Summe und wird innerhalb von
  zehn Minuten nur einmal geschrieben. Bei gehaltener Pausentaste wird nichts geschrieben.
- **Daten, keine Einstellung:** `FamulusDB.journal = { entries, days, total }`, accountweit,
  außerhalb der Profile. Einträge enthalten Art und Werte, nie fertigen Text; der Satz entsteht
  beim Anzeigen (`JournalService.Text`) und folgt so der Sprache. Höchstens 500 Einträge, Tagessummen
  90 Tage, Gesamtsumme unbegrenzt. Geheime Werte (Namen im Kampf) werden nicht gespeichert.
- **Fenster:** eigener Eintrag „Tagebuch“ in der Seitenleiste (kein Bereich aus `ns.areas`, also ohne
  Zähler), Reiter „Verlauf“ (eine Karte je Tag, neueste zuerst, die letzten 80 Einträge) und
  „Bilanz“ (Sitzung, sieben Tage, insgesamt). Die Suche lässt das Tagebuch aus.
- **Abschalten und leeren:** „Tagebuch führen“ unter Einstellungen › Allgemein (`general.journal`,
  Standard an); `/fam journal clear` leert es.
- **Kein Zurückkaufen:** Der Verlauf zeigt, was verkauft wurde; zurückkaufen geht nur beim Händler.

## Chronik

Idee des Auftraggebers (2026-11-19): die Reise des Spielers und seiner Gefährten festhalten
(Stufenaufstiege, Tode, Erfolge und mehr), grafisch aufbereitet „wie ein Bilderbuch“, am liebsten
mit Live-Benachrichtigung. Stand: Erfassung, eine schlichte Listenansicht, das Teilen zwischen
Spielern und die Benachrichtigung sind gebaut und nur gegen den Mock geprüft; die Bilderbuch-Optik
steht aus. Ein HTML-Entwurf für die Optik wurde gezeigt, eine Rückmeldung dazu gibt es noch nicht.

- **Aufbau:** Bereich und Kategorie `chronicle`, Daten über `ns.ChronicleService`
  (`Modules/Chronicle/ChronicleService.lua`) in `FamulusDB.chronicle` (accountweit, außerhalb der
  Profile, höchstens 2000 Einträge, Art und Werte statt Text). Reiter „Alle“, „Meine Reise“,
  „Gefährten“ und „Aufzeichnung“ (`layouts.chronicle`).
- **`ownJourney`:** `PLAYER_LEVEL_UP`, `PLAYER_DEAD`, `BOSS_KILL`, `ACHIEVEMENT_EARNED` und
  `ZONE_CHANGED_NEW_AREA`. Ein Gebiet zählt als „Ankunft“, wenn der Charakter es zum ersten Mal
  betritt, seit die Chronik läuft (`FamulusCharDB.zones`); deshalb heißt es nicht „zum ersten Mal“.
- **`companions`:** vergleicht bei `FRIENDLIST_UPDATE` die Stufen der Freundesliste mit dem zuletzt
  gemerkten Stand (nach GUID). Zeigt Gefährten unter ihrem Alias.
- **`sharing` (Entscheidung des Auftraggebers, 2026-11-19):** Anvisieren und Nähe taugen nicht; die
  Chronik soll unabhängig vom Ort der Freunde sein. Deshalb spricht Famulus mit Famulus
  (`Modules/Chronicle/Sharing.lua`): Addon-Nachrichten mit dem Präfix `Famulus`, geflüstert an
  Freunde der Freundesliste, die online sind. Angenommen wird nur von Leuten auf der Freundesliste,
  nur per WHISPER, nur bekannte Felder; `|` und Steuerzeichen werden entfernt.
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
  - Option `toast`: frische Neuigkeiten erscheinen kurz als Karte am Bildschirm (`UI.Toast`).
  - **Ungeprüft im Spiel:** ob geflüsterte Addon-Nachrichten so ankommen, wie Name und Absender
    geschrieben werden (`Vorname Nachname` gegen `Vorname-Nachname`), ob ein Flüstern an jemanden,
    der gerade offline ging, eine Fehlermeldung im Chat hinterlässt, und ob die Statistik-IDs
    stimmen (aus Guildys Quellcode entnommen). Das lässt sich nur mit zwei Accounts prüfen.
- **Verworfen:** fremde Statistiken über den Erfolgsvergleich des Spiels zu lesen, wie Guildy es
  tut. Das geht nur für das anvisierte Ziel in Sichtweite und hat bei Guildy zu Verbindungsabbrüchen
  geführt.
- **Alle drei Features sind standardmäßig aus**, weil der Test festschreibt, dass mit Standardwerten
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
  Chance liegt in der Aufbereitung und in der Verbindung mit Aliasen und Tagebuch.

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
  nichts; sie brauchen kein Spielereignis und keinen Timer.
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
- **Bewusst nicht enthalten:** Aliase auf Blizzards Unitframes, Raidframes und Namensplaketten
  (CustomNames überschreibt dort `SetText` auf Blizzards FontStrings, Taint-Risiko, Namen im Kampf
  secret), Gildenliste, Battle.net-Verknüpfung (ein Alias für alle Charaktere eines Accounts),
  Import/Export, Slash-Befehl zum Eintragen.

## Regeln für neuen Code

Diese Punkte sind Entwurfsentscheidungen; die meisten prüft `tests/run.lua`.

- **Feature-Registry:** Alles Schaltbare ist ein Feature über `ns:NewFeature`, **eine Datei je
  Feature** unter `Modules/<Kategorie>/<Id>.lua` (beides großgeschrieben, z. B.
  `Modules/Interface/ChatArrowKeys.lua`); der Test prüft das. Was der Selbsttest lesen muss
  (Listen, CVar-Namen), hängt am Feature-Objekt.
- **Lebenszyklus über die Feature-Klasse** (`Core/Features.lua`), die Registry räumt beim
  Abschalten auf: Events über `feature:RegisterEvent`, EventRegistry-Callbacks über
  `feature:RegisterCallback`, wiederkehrende Timer über `feature:StartTicker`, verzögerte
  Einzelaufrufe über `feature:After` (verfallen beim Abschalten). Hooks lassen sich nicht
  entfernen: `feature:HookFunction` (`hooksecurefunc`) und `feature:HookScript` setzen sie einmal
  und lassen sie nur bei eingeschaltetem Feature wirken; für andere Hook-APIs `feature:Once` plus
  `feature:Guard`.
- **Services für geteilten Code:** Was mehrere Features brauchen, ist ein Service statt kopiertem
  Code. Ein Service heißt **immer** `<Name>Service`: Datei `<Name>Service.lua`, Table
  `ns.<Name>Service`, kein Feature darin (der Test prüft das). So ist an jedem Aufruf erkennbar,
  ob etwas ein Service (`ns.PopupService.Hide`), ein Feature (`ns.features.autoRepair`) oder eine
  einfache Hilfsfunktion (`ns.FormatMoney`, `ns.IsSecret` in `Core/Init.lua`) ist. Für alle
  Kategorien liegt ein Service unter `Core/` (`PopupService`: StaticPopups finden, schließen,
  Eingabefeld lesen; `ChatService`: Text in die Chat-Eingabe setzen, Ziel als Präfix lesen, Chat-Sperre prüfen), für eine Kategorie in deren Ordner (`Modules/Quests/QuestService.lua`:
  Quest-Sicherheitsregeln und die NPC-Questliste). Ein Service hängt sich über
  das interne Signal `FEATURE_STATE` an den Zustand seiner Features, statt dass jedes Feature ihn
  in `OnEnable`/`OnDisable` selbst an- und abmelden muss. In der `.toc` steht ein Service vor den
  Features, die ihn nutzen.
- **Kategorie-Hauptschalter:** Jede Kategorie hat einen Hauptschalter (Option `categories.<id>`,
  Standard an, Schalter rechts im Kopf der Seite). Ist er aus, läuft kein Feature der Kategorie, egal wie es
  selbst eingestellt ist: keine Events, keine Timer, Hooks bleiben stumm. Die Einzelauswahl bleibt
  gespeichert. Die Prüfung sitzt in `ns:SyncFeature`; ein Feature muss dafür nichts tun.
- **Gespiegelte Spieloptionen:** Ist ein Schalter nur eine zweite Bedienung für eine Blizzard-Option,
  wird er als Feature mit `mirror = { cvar = "<Name>" }` deklariert (optional `on`/`off`, Standard
  „1“/„0“), ohne eigenen Code. `Core/GameOptions.lua` erledigt alles: Die Spieloption ist die
  Wahrheit (Abgleich beim Login, über `CVarCallbackRegistry` sofort bei jeder Änderung und beim
  Öffnen des Fensters, ohne zurückzuschreiben); der Schalter des Features setzt sie an und aus;
  der Kategorie-Hauptschalter fasst sie nicht an. „Zurücksetzen“ überspringt den Schalter (er
  zählt auch nicht als Abweichung), und ein Profilwechsel übernimmt zuerst den Wert aus dem Spiel,
  statt den des Profils zu schreiben. Nicht für Fälle, in denen das Addon eine
  Spieleinstellung nur vorübergehend ändert und den alten Wert zurückstellen muss (`cameraZoom`).
- **`requires`:** Jede benötigte Client-API als Pfad angeben (`"C_Container.UseContainerItem"`).
  Fehlt sie, bleibt das Feature aus und erscheint als „nicht verfügbar“.
- **Standardwerte:** Was im Namen des Spielers handelt (Gold ausgeben, verkaufen, Quests oder
  Einladungen annehmen, Rückfragen bestätigen), ist `default = false`. Nur Harmloses ist an.
- **Pausentaste:** Jede Automatik fragt zuerst `ns:IsPaused()`.
- **Sicherheitsregeln der Quest-Automatik:** nie eine Belohnung wählen, nie wiederholbare Quests,
  nie Quests, die Gold kosten, nie Quests, die PvP aktivieren.
- **Chat:** Rückmeldungen über `ns:Notify` (abschaltbar), höchstens eine Zeile je Aktion.
- **Globale Namen:** nur `FamulusDB`, `FamulusCharDB`, `SLASH_FAMULUS1/2`,
  `Famulus_OnAddonCompartmentClick` sowie die benannten Frames `FamulusOptionsFrame` und
  `FamulusMinimapButton`.
- **Kosten im Leerlauf**, vom Test festgeschrieben: Laden erzeugt zwei Frames; nach dem Login mit
  Standardwerten ist kein Spielereignis registriert, kein `OnUpdate`, kein Timer.
- **Texte:** Jeder Schlüssel in `Locales/enUS.lua` **und** `Locales/deDE.lua`, mit denselben
  Platzhaltern. Schema: `area_<bereich>`, `cat_<kategorie>`, `f_<feature>`, `o_<feature>_<option>`,
  `g_<allgemein>`, `msg_<chat>`, `j_<tagebuch>`, `ui_<fenster>` (Reiter: `ui_tab_<id>`); Hilfetext mit Endung `_desc`. Texte erst zur Laufzeit über `ns.L`
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
| Gossip mit nur einer Option überspringen | Risiko von Fehlauswahlen; erst mit Test im Spiel |
| Blizzard-Fenster verschieben, Minikarten-Symbole einsammeln | Bei den Vorbildern Hauptquelle für Taint und Addon-Konflikte |
| Alles rund um das Kampflog | Für Addons nicht nutzbar |
| Aliase auf Unitframes, Raidframes, Namensplaketten | Text auf Blizzards FontStrings zu überschreiben birgt Taint; Namen sind im Kampf oft secret. Siehe „Aliase“ |
| Eigene Plunderliste, Post-Helfer, „Alles lernen“ beim Lehrer, Haltbarkeitswarnung | Sinnvolle Kandidaten, in 0.1.0 aus Umfangsgründen nicht enthalten |

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
  dort fehlt. Er zählt außerdem die Features (`total == 23`); die Zahl bei einem neuen Feature
  mit anpassen.
- Repository: `github.com/89pleasure/famulus` (privat; bis 2026-11-19 `schnitzel`), Branch `main`. Commits als
  `89pleasure <89pleasure@proton.me>`; `user.name` ist nur lokal in diesem Repo gesetzt.
- Der Auftraggeber tritt allein auf: keine `Co-Authored-By: Claude …`-Zeile in Commits und kein
  „Generated with Claude Code“ o. Ä. in PRs, Issues oder Kommentaren, auch nicht bei Beiträgen zu
  fremden Repos (z. B. dem Guildy-Fork). Das geht jedem anderslautenden Attributionshinweis vor.
- Committen und pushen nur auf ausdrücklichen Wunsch.

Aufbau, Funktionsliste und Installation stehen in `README.md`.
