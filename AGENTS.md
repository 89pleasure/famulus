# Schnitzel – Projektwissen für KI-Assistenten

Schnitzel ist ein Quality-of-Life-Addon für **World of Warcraft: Forever**. Diese Datei hält fest,
was der Auftraggeber will, was entschieden wurde und was man über den Forever-Client wissen muss.
Stand: 2026-11-16, Version 0.1.0.

## Vorgaben des Auftraggebers

Der Auftraggeber spielt WoW Forever und hat drei Sammel-Addons ausprobiert, die ihm gefallen:
**OneForAll**, **FlareUI** und **Polestar**. Schnitzel soll sich an ihnen orientieren und sich auf
Folgendes konzentrieren und beschränken:

1. **Modernes, übersichtliches Layout.** Polestar gefällt ihm bisher am besten.
2. **Vorerst nur Quality-of-Life-Funktionen.** Keine Unitframes, Aktionsleisten, Guides,
   Schadensanzeigen oder Ähnliches.
3. **Schwachstellen der drei Vorbilder analysieren und daraus lernen.**
4. **Performance-optimiert.**
5. **Mehrsprachig.** Englisch und Deutsch reichen vorerst.

**Veröffentlichung:** Schnitzel soll später veröffentlicht werden (Stand 2026-11-16, Zeitpunkt und
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
    (OneForAll vermerkt dasselbe, FlareUI baut ihn ebenfalls nach). Schnitzel führt deshalb eine
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
    Schnitzels Fenster und Blizzards Spielmenü sich gegenseitig schließen zu lassen, wurde
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
- **Noch nicht im Spiel geprüft:** das Verhalten der Automatiken (reparieren, verkaufen, Quests,
  Beute, Einladungen, Duelle, Zerstören), im Fenster das Dropdown, die Suche und das Scrollen, Verhalten im Kampf (Secret Values,
  Taint).

## Test im Spiel

WoW Forever ist auf dem Entwicklungsrechner installiert: `/Applications/World of Warcraft/_forever_`.
`Interface/AddOns/Schnitzel` ist dort ein Symlink auf den Ordner `Schnitzel/` dieses Repos, jede
Änderung ist also nach `/reload` im Spiel.

- `/sz test` prüft gegen den echten Client: benötigte API je Feature, die oben genannten unsicheren
  Stellen (Texturen, Kamerazoom, Popup-Namen, Karte, Fehlertext-Globals) und die Annahmen aus
  „WoW Forever: was man wissen muss“. Der Bericht landet in `SchnitzelDB.selfTest`.
- `/sz dev` schaltet den Entwicklermodus um: Der Selbsttest läuft dann drei Sekunden nach jedem
  Login, und blockierte Aktionen (`ADDON_ACTION_BLOCKED`/`_FORBIDDEN`) sowie `LUA_WARNING` des Addons
  werden in `SchnitzelDB.devLog` gesammelt. Standard ist aus; dann kostet das nichts.
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

| Schwachstelle der Vorbilder | Regel in Schnitzel |
|---|---|
| Events dauerhaft registriert, Option erst im Handler geprüft (OneForAll: ~38 Events) | Ein Feature registriert Events erst in `OnEnable` |
| Ungedrosselte `OnUpdate`-Handler | Im Leerlauf läuft nichts pro Frame |
| Umschalten braucht `/reload` (FlareUI-Module, OneForAll-Sprache und -Profil) | Alles wirkt sofort |
| Hooks bleiben nach dem Abschalten aktiv | Hooks nur über `feature:HookFunction`/`HookScript` oder `feature:Once` plus `feature:Guard`; sie wirken nur bei eingeschaltetem Feature |
| Megabytes an Code und Daten bei jedem Login (Polestar: 70–250 MB laut Issues) | Fenster wird erst beim ersten Öffnen gebaut; keine Bibliotheken |
| Ersetzte Blizzard-Funktionen, überschriebene Methoden fremder Addons | Nur `hooksecurefunc`; nichts ersetzen, nichts in fremde Tabellen schreiben |
| ~90 Optionen, uneinheitliche Standardwerte, Chat-Meldung je Aktion | Wenige Funktionen, eine Regel für Standardwerte, eine Sammelzeile je Aktion |
| FlareUI ohne Deutsch; Polestar-Sprachen als Zusatz-Addons | enUS und deDE eingebaut und per Test auf Gleichstand geprüft |

Von Polestar übernommen ist die **Struktur** des Fensters: Seitenleiste mit Wortmarke, Suchfeld und
Navigation, rechts Kopfzeile, ein umrandetes Feld mit Zeilen, Fußzeile; Pillenschalter 30×16;
flache Flächen mit Haarlinien. Farbpalette und Texturen sind eigene (`UI/Theme.lua`), es werden
keine Schriften mitgeliefert.

Entscheidungen des Auftraggebers zum Fenster (2026-11-16):

- Feste Fensterhöhe; längere Seiten scrollen. Keine Höhe, die sich dem Inhalt anpasst.
- Deckender Hintergrund, außen ein 3 Einheiten breiter Rahmen mit Verlauf (`UI.GradientFrame`).
- Die Seite für Addon-eigene Einstellungen heißt „Einstellungen“ (intern weiter `general`); dort
  sammelt sich alles, was nur das Addon und nicht das Spiel betrifft.
- Der Hauptschalter einer Kategorie sitzt rechtsbündig im Kopf der Seite, beschriftet nur mit
  „AN“ oder „AUS“. Der Untertitel beschreibt immer, was der Spieler auf der Seite findet; technische
  Hinweise (was im Hintergrund läuft oder nicht) gehören nicht ins Fenster. Eine abgeschaltete
  Kategorie ist in der Seitenleiste ausgegraut und trägt „AUS“ in Großbuchstaben.
- Optionen eines Features (`child`) stehen immer unter ihm. Ist das Feature aus, erscheinen sie
  eingeklappt: schmale Zeile ohne Beschreibung, ausgegraut, nicht klickbar, aber mit sichtbarem
  Wert (Schalterstellung, gewählter Eintrag). Die Suche zeigt sie immer vollständig.
- „Seite zurücksetzen“ fragt beim ersten Klick nach („Wirklich zurücksetzen?“) und führt erst der
  zweite Klick innerhalb von vier Sekunden aus. Steht die Seite auf den Standardwerten, ist der
  Knopf ausgegraut und nicht klickbar.
- Die Fenstergröße ist auf der Seite „Einstellungen“ wählbar (`general.windowScale`, 80 bis 140 %).
- Das Theming ist vorläufig; ein richtiges Theme folgt später.

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
  der Kategorie-Hauptschalter fasst sie nicht an. Nicht für Fälle, in denen das Addon eine
  Spieleinstellung nur vorübergehend ändert und den alten Wert zurückstellen muss (`cameraZoom`).
- **`requires`:** Jede benötigte Client-API als Pfad angeben (`"C_Container.UseContainerItem"`).
  Fehlt sie, bleibt das Feature aus und erscheint als „nicht verfügbar“.
- **Standardwerte:** Was im Namen des Spielers handelt (Gold ausgeben, verkaufen, Quests oder
  Einladungen annehmen, Rückfragen bestätigen), ist `default = false`. Nur Harmloses ist an.
- **Pausentaste:** Jede Automatik fragt zuerst `ns:IsPaused()`.
- **Sicherheitsregeln der Quest-Automatik:** nie eine Belohnung wählen, nie wiederholbare Quests,
  nie Quests, die Gold kosten, nie Quests, die PvP aktivieren.
- **Chat:** Rückmeldungen über `ns:Notify` (abschaltbar), höchstens eine Zeile je Aktion.
- **Globale Namen:** nur `SchnitzelDB`, `SchnitzelCharDB`, `SLASH_SCHNITZEL1/2`,
  `Schnitzel_OnAddonCompartmentClick` sowie die benannten Frames `SchnitzelOptionsFrame` und
  `SchnitzelMinimapButton`.
- **Kosten im Leerlauf**, vom Test festgeschrieben: Laden erzeugt zwei Frames; nach dem Login mit
  Standardwerten ist kein Spielereignis registriert, kein `OnUpdate`, kein Timer.
- **Texte:** Jeder Schlüssel in `Locales/enUS.lua` **und** `Locales/deDE.lua`, mit denselben
  Platzhaltern. Schema: `cat_<seite>`, `f_<feature>`, `o_<feature>_<option>`, `g_<allgemein>`,
  `msg_<chat>`, `ui_<fenster>`; Hilfetext mit Endung `_desc`. Texte erst zur Laufzeit über `ns.L`
  lesen, nie beim Laden zwischenspeichern, sonst bricht der Sprachwechsel.
- **Einstellungen:** Gespeichert wird nur, was vom Standard abweicht (`ns:SetOption`).
- **Fenster:** Zeilen entstehen automatisch aus Features und deren `options`
  (`type = "toggle"` oder `"select"`). Neue Widgets gehören nach `UI/Widgets.lua`.

## Bewusst weggelassen

| Funktion | Grund |
|---|---|
| URLs im Chat anklickbar machen | Eigene Link-Typen im Forever-Client unbestätigt, Chat kann „secret“ sein, `CopyToClipboard` ist geschützt |
| Gossip mit nur einer Option überspringen | Risiko von Fehlauswahlen; erst mit Test im Spiel |
| Blizzard-Fenster verschieben, Minikarten-Symbole einsammeln | Bei den Vorbildern Hauptquelle für Taint und Addon-Konflikte |
| Alles rund um das Kampflog | Für Addons nicht nutzbar |
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
rm -f dist/Schnitzel-*.zip && zip -rq dist/Schnitzel-0.1.0.zip Schnitzel -x '*.DS_Store'
```

- Bei einer neuen Version: `## Version` in `Schnitzel/Schnitzel.toc`, den Zip-Namen und die
  Versionsangaben in `README.md` anpassen.
- Neue Lua-Dateien in die `.toc` eintragen; der Test schlägt fehl, wenn eine Datei im Addon-Ordner
  dort fehlt. Er zählt außerdem die Features (`total == 16`); die Zahl bei einem neuen Feature
  mit anpassen.
- Repository: `github.com/89pleasure/schnitzel` (privat), Branch `main`. Commits als
  `89pleasure <89pleasure@proton.me>`; `user.name` ist nur lokal in diesem Repo gesetzt.
- Committen und pushen nur auf ausdrücklichen Wunsch.

Aufbau, Funktionsliste und Installation stehen in `README.md`.
