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

Arbeitsweise: Er schreibt Deutsch und möchte Antworten auf Deutsch. Code, Kommentare und
Commit-Nachrichten sind Englisch, README und diese Datei Deutsch.

## Stand der Prüfung

- `luajit tests/run.lua` lädt das Addon gegen eine nachgestellte Client-API (`tests/wowmock.lua`)
  und prüft jedes Feature, das Fenster und die Übersetzungen. Muss vor jedem Commit grün sein.
- **Im echten Spiel wurde noch nichts getestet.** Auf dem Entwicklungsrechner (Mac) ist WoW nicht
  installiert. Der Mock beweist die eigene Logik, nicht das Verhalten des Clients.
- Stellen, die im Spiel am ehesten abweichen:
  - Die vier TGA-Texturen in `Schnitzel/Media/` (selbst erzeugt, unkomprimiert, 32 Bit). Grüne
    Flächen im Spiel bedeuten: Format oder Pfad stimmt nicht.
  - `cameraZoom`: Der Maximalwert von `cameraDistanceMaxZoomFactor` ist unbestätigt; der Code
    probiert 4,0 und dann 2,6.
  - `easyDelete` und `acceptInvites` greifen auf Blizzards Popups zu (`StaticPopup_FindVisible`,
    `dialog:GetEditBox()`, `StaticPopup_Hide("PARTY_INVITE")`).
  - `mapCoords`: Position und Ebene des Koordinatenfelds auf der Weltkarte.
  - `hideErrors`: Die Liste der Fehlertext-Globals (`BLOCKED_GLOBALS`) ist aus dem Gedächtnis
    zusammengestellt; nicht vorhandene Namen werden übersprungen.

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
  `C_Spell.GetSpellInfo`) sowie `ChatFrame_AddMessageEventFilter` (stattdessen
  `ChatFrameUtil.AddMessageEventFilter`).
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
| Hooks bleiben nach dem Abschalten aktiv | Hooks nur über `feature:Once()`, im Hook `feature.enabled` prüfen |
| Megabytes an Code und Daten bei jedem Login (Polestar: 70–250 MB laut Issues) | Fenster wird erst beim ersten Öffnen gebaut; keine Bibliotheken |
| Ersetzte Blizzard-Funktionen, überschriebene Methoden fremder Addons | Nur `hooksecurefunc`; nichts ersetzen, nichts in fremde Tabellen schreiben |
| ~90 Optionen, uneinheitliche Standardwerte, Chat-Meldung je Aktion | Wenige Funktionen, eine Regel für Standardwerte, eine Sammelzeile je Aktion |
| FlareUI ohne Deutsch; Polestar-Sprachen als Zusatz-Addons | enUS und deDE eingebaut und per Test auf Gleichstand geprüft |

Von Polestar übernommen ist die **Struktur** des Fensters: Seitenleiste mit Wortmarke, Suchfeld und
Navigation, rechts Kopfzeile, ein umrandetes Feld mit Zeilen, Fußzeile; Pillenschalter 30×16;
flache Flächen mit Haarlinien. Farbpalette und Texturen sind eigene (`UI/Theme.lua`), es werden
keine Schriften mitgeliefert.

## Regeln für neuen Code

Diese Punkte sind Entwurfsentscheidungen; die meisten prüft `tests/run.lua`.

- **Feature-Registry:** Alles Schaltbare ist ein Feature über `ns:NewFeature` in `Modules/`.
  Events über `feature:RegisterEvent`, wiederkehrende Timer über `feature:StartTicker`; beides
  räumt die Registry beim Abschalten auf.
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
  Standardwerten ist ein Spielereignis registriert (`LOOT_READY`), kein `OnUpdate`, kein Timer.
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
python3 tools/make_media.py
```

```bash
rm -f dist/Schnitzel-*.zip && zip -rq dist/Schnitzel-0.1.0.zip Schnitzel -x '*.DS_Store'
```

- Bei einer neuen Version: `## Version` in `Schnitzel/Schnitzel.toc`, den Zip-Namen und die
  Versionsangaben in `README.md` anpassen.
- Neue Lua-Dateien in die `.toc` eintragen; der Test zählt die Dateien (`#files == 16`) und die
  Features (`total == 16`), beide Zahlen dann mit anpassen.
- Repository: `github.com/89pleasure/schnitzel` (privat), Branch `main`. Commits als
  `89pleasure <89pleasure@proton.me>`; `user.name` ist nur lokal in diesem Repo gesetzt.
- Committen und pushen nur auf ausdrücklichen Wunsch.

Aufbau, Funktionsliste und Installation stehen in `README.md`.
