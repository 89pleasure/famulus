# Famulus – Projektwissen für KI-Assistenten

Famulus ist ein Addon für **World of Warcraft: Forever**, das das gemeinsame Spielen unter Freunden
und in der Community verbessert, erleichtert und erweitert. Diese Datei hält fest, was der
Auftraggeber will, welche Regeln für jede Arbeit gelten und was man über den Forever-Client wissen
muss. Das Wissen zu den einzelnen Bereichen steht unter `docs/` (siehe „Wissen unter `docs/`“).
Stand: 2026-11-25, Version 0.1.0.

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
Commit-Nachrichten sind Englisch, diese Datei und `docs/*.md` Deutsch. Die README ist seit 2026-11-24 auf Wunsch
des Auftraggebers Englisch und knapp gehalten (vorher Deutsch und ausführlich); Einzelheiten
gehören hierher, nicht dorthin. Was Famulus von OneForAll, FlareUI und Polestar gelernt hat, steht
nicht mehr darin („da wir uns nun ganz woanders bewegen thematisch“); die Tabelle unten bleibt.

## Wissen unter `docs/`

Diese Datei enthält nur, was für fast jede Arbeit gilt. Das Wissen zu einzelnen Bereichen steht
unter `docs/`; lies die passende Datei, bevor du in dem Bereich arbeitest, und nur dann.

| Datei | Inhalt | Lesen, wenn … |
|---|---|---|
| [docs/window.md](docs/window.md) | Das Fenster: Aufbau (Kopf, Seitenleiste, Tabs), Bereiche, Hauptschalter, Zurücksetzen, Suche, Farben und Farbwelten, kein heller Modus, Akzente und Effekte, Hintergrund (Körnung, Funken), Karten, Form, Schrift (wie der Client Inter lädt) | du am Fenster, an Widgets, Farben, Effekten oder Schriften arbeitest |
| [docs/chronicle.md](docs/chronicle.md) | Chronik: Buch mit Randspalte, Kapitel als Spielabend (Route), Bilderbuch, Gewichtung und Aufbau der Karten, Bilder, `ownJourney` (Gebiete, Berufe, Fähigkeiten, besondere Gegenstände), Beispieleinträge, `companions`, Live-Einblendung (`liveFeed`), Klasse und Name, was der Client hergibt | du an Chronik, Buch (`UI.Book`) oder Live-Einblendung arbeitest |
| [docs/sharing.md](docs/sharing.md) | Teilen zwischen Spielern: Protokoll, Gilde, Weiterreichen, Statistiken, Warteschlange und Drosselung, Nachholen in Runden, Analyse „Viele Nutzer“ | du an Addon-Nachrichten oder `Sharing.lua` arbeitest |
| [docs/fellows.md](docs/fellows.md) | Weggefährten: Daten, Zählen, Nur Freunde und Gilde, Aufräumen, Secret Values, Fenster (Übersicht, Eure Geschichte, Steckbrief), Runden, Verbundenheit, Tagesprotokoll, Beispieldaten | du an den Weggefährten arbeitest |
| [docs/aliases.md](docs/aliases.md) | Aliase: Daten, Schlüssel, `chatAliases`, `tooltipAliases`, `aliasMenu`, andere Addons und `guildyAliases`, Alias für einen Battle.net-Account | du an den Aliasen oder an Anbindungen anderer Addons arbeitest |
| [docs/testing.md](docs/testing.md) | Tests gegen den Mock, Stand der Prüfung im Spiel (Selbsttests, Fehler 2026-11-24), Test im Spiel (Pfade, `/fam test`, `/fam dev`, Lua-Fehler, BugSack) | du im Spiel testest, einen Fehler aus dem Spiel suchst, am Mock arbeitest oder wissen willst, was schon im Spiel bestätigt ist |
| [docs/branding.md](docs/branding.md) | Name, Logo, Untertitel, verworfene Namen und Logos | du an Name, Logo oder Untertitel arbeitest |
| [docs/website.md](docs/website.md) | Website: Technik, Aufbau, Demos, Lagerfeuer im Kopf, Fenster im Kopf (Screenshot), Sprachen, Hosting, was bei Änderungen am Addon mitzuziehen ist | du an `website/` arbeitest oder sich das Fenster sichtbar ändert |
| [docs/release.md](docs/release.md) | Veröffentlichung auf CurseForge: Packager, Tags und Dateitypen, Ablauf eines Release, Version, Lizenz, Projektlogo, Projekt-ID, Offenes | du ein Release vorbereitest oder an Workflows, `.pkgmeta`, `LICENSE` arbeitest |
| `docs/curseforge/` | Beschreibung und Logo der CurseForge-Projektseite | die Projektseite geändert wird |
| `docs/superpowers/` | Spezifikationen und Pläne einzelner Vorhaben (Stand ihres Datums) | die Herkunft einer Entscheidung unklar ist |

- **Automatisch geladen:** Eine `CLAUDE.md` in einem Unterordner importiert die passende Datei
  (`@…/docs/<datei>.md`); Claude Code lädt sie, sobald dort eine Datei gelesen wird:
  `Famulus/Modules/Chronicle/` (chronicle, sharing), `Famulus/Modules/Fellows/`,
  `Famulus/Modules/Aliases/`, `Famulus/UI/` (window; nennt dazu, welche UI-Dateien zur Chronik
  und zu den Weggefährten gehören), `tests/` (testing), `website/`, `.github/` (release). Wer
  außerhalb dieser Ordner arbeitet (etwa `Core/`, `tools/`), liest selbst nach. Eine neue
  `CLAUDE.md` unter `Famulus/` hält `.pkgmeta` aus dem Zip, `website/CLAUDE.md` entfernt der
  Workflow vor dem Veröffentlichen; anderswo prüfen, ob sie veröffentlicht würde.
- **Neues Wissen gehört in die passende Datei unter `docs/`, nicht hierher.** Hierher nur, was für
  fast jede Arbeit gilt (Vorgaben, Regeln, Arbeitsablauf). Eine neue Datei bekommt eine Zeile in
  der Tabelle.
- Verweise der Form „siehe X“ meinen eine Überschrift oder einen fett gesetzten Eintrag; die
  Tabelle sagt, in welcher Datei er steht.
- Was „nur gegen den Mock geprüft“ und was im Spiel bestätigt ist, steht beim jeweiligen Eintrag;
  eine Übersicht hat `docs/testing.md`.

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

- `luajit tests/run.lua` lädt das Addon gegen eine nachgestellte Client-API (`tests/wowmock.lua`)
  und prüft jedes Feature, das Fenster und die Übersetzungen. **Muss vor jedem Commit grün
  sein.** Was der Mock nachstellt und was nicht, steht in `docs/testing.md`.
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
