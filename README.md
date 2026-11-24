# Famulus

Addon für das gemeinsame Spielen unter Freunden in **World of Warcraft: Forever** (Interface 16001):
eine Chronik eurer gemeinsamen Reise, deine Weggefährten, also alle, mit denen du in einer Gruppe
warst, und Aliase für andere Spieler. Englisch und Deutsch, keine Bibliotheken, keine Abhängigkeiten.

## Installation

1. Den Ordner `Famulus/` (oder den Inhalt von `dist/Famulus-0.1.0.zip`) nach
   `World of Warcraft/_forever_/Interface/AddOns/` kopieren.
2. Spiel starten bzw. `/reload`.
3. `/fam` öffnet die Einstellungen (alternativ `/famulus`, das Minikartensymbol oder der
   Eintrag im Addon-Menü der Minikarte).

## Funktionen (Version 0.1.0)

| Seite | Funktion | Standard |
|---|---|---|
| Chronik | Eigene Reise aufzeichnen (Stufen, Tode, Bosse, Herausforderungen, Gebiete, Berufe, Fähigkeiten, Gegenstände) | aus |
| Chronik | Stufenaufstiege der Freundesliste festhalten | aus |
| Chronik | Mit Freunden und Gilde teilen (Addon-Nachrichten zwischen Famulus-Nutzern) | aus |
| Chronik | Ereignisse von Freunden live als Karte am Bildschirm einblenden, auf Wunsch auch eigene | **an** |
| Weggefährten | Merken, mit wem du in einer Gruppe warst: wann, wo, wie oft, wie lange, gemeinsame Bosse (wahlweise ohne Schlachtzüge) | aus |
| Aliase | Alias statt Charaktername im Chat (wahlweise „Alias (Name)“) | **an** |
| Aliase | Alias als Zeile im Tooltip eines Spielers | **an** |
| Aliase | „Alias festlegen“ im Kontextmenü von Spielern und Battle.net-Freunden | **an** |
| Aliase | Charaktere von Battle.net-Freunden mit Alias merken (lauscht nur, solange es einen solchen Alias gibt) | **an** |
| Aliase | Alias statt Charaktername im Addon Guildy (nur sichtbar, wenn Guildy geladen ist) | **an** |

**Das Fenster** (`/fam`): Links die Suche, darunter die Hauptfunktionen **Chronik**, **Weggefährten**
und **Aliase**, unten **Einstellungen** und **Über**; die Unterbereiche der gewählten Funktion
stehen als Tabs oben im Inhalt.
Die **Chronik erzählt, was passiert ist**, die **Weggefährten zeigen, mit wem du spielst**.
Die Chronik erzählt die Reise deiner Charaktere und deiner Freunde als Bilderbuch und tauscht sie
auf Wunsch mit Freunden und Gildenmitgliedern aus, die Famulus ebenfalls nutzen, auch über
gemeinsame Freunde, wenn jemand offline ist. Besiegt ihr einen Boss als Gruppe, nennt die Chronik,
wer dabei war. Neben dem Buch zeigt eine Spalte deine Woche in Zahlen, deine Berufe und deine
Freunde mit Stufe, Online-Stand und ihrer Bilanz; ein Klick auf eine Person zeigt nur ihre
Ereignisse. Die Weggefährten zeigen deine drei engsten Gefährten als Kacheln und alle weiteren in
einer Liste (nach dem letzten Mal oder nach der gemeinsamen Zeit), jeweils mit ihrer **Verbundenheit**: Begegnung,
Bekannt (ab 1 Std.), Vertraut (ab 10 Std.), Unzertrennlich (ab 40 Std.). Ein Klick zeigt die Person
und „Eure Geschichte“: eure gemeinsamen Tage und Bosse als Bilderbuch. Kennt auch die Chronik die
Person, führt ein Knopf zu ihren Ereignissen dort, und von dort zurück. Diese Daten bleiben auf
deinem Rechner, nichts davon wird verschickt. Die Aliase haben ihre Namensliste und einen
Unterbereich „Einstellungen“. Fünf Farbwelten, die Funken im Hintergrund und die Fenstergröße stehen unter
Einstellungen › Darstellung. Die Suche oben findet Einstellungen, Aliase und Weggefährten auf allen
Seiten.

Jede Hauptfunktion hat einen **Hauptschalter** unter Einstellungen › Allgemein. Ist er aus, läuft dort
nichts und nichts lauscht auf das Spiel; die Auswahl der einzelnen Funktionen bleibt erhalten.

**Aliase** sind eigene Namen für andere Spieler, die nur du siehst. Du trägst sie auf der Seite
„Aliase“ ein (Charaktername, Alias) oder per Rechtsklick auf einen Spieler. Die Liste gilt für den
ganzen Account und bleibt von Profilen und „Zurücksetzen“ unberührt. Flüstern, Einladen und
Links benutzen weiter den echten Namen.

Für einen **Battle.net-Freund** genügt ein Alias für alle seine Charaktere: Trage statt des
Charakternamens seinen BattleTag ein (`Name#1234`) oder wähle im Kontextmenü „Alias für alle
Charaktere festlegen“. Famulus merkt sich jeden Charakter, mit dem der Freund online ist; ein
Charakter, den du noch nie online gesehen hast, bekommt den Alias erst dann. Ein Alias, den du
einem einzelnen Charakter gibst, hat Vorrang.

Grundregel für die Standardwerte: Was auf Spielereignisse lauscht oder Nachrichten an andere
Spieler schickt, ist anfangs aus.

## Was von OneForAll, FlareUI und Polestar gelernt wurde

| Beobachtung bei den Vorbildern | Umsetzung in Famulus |
|---|---|
| OneForAll registriert ~38 Events dauerhaft und prüft die Option erst im Handler; FlareUI-Untermodule ebenso | Ein Feature registriert Events erst beim Einschalten. Nach dem Login mit Standardwerten lauscht das Addon auf **kein** Spielereignis |
| Ungedrosselte `OnUpdate`-Handler (Tooltip-Anker, Minikarten-Drag, Proximity-Scan) | Kein `OnUpdate` im Leerlauf; Animationen laufen nur, solange sie dauern |
| FlareUI: Modul umschalten = `/reload`; OneForAll: Sprache/Profil = Reload | Jede Option, die Sprache und das Charakterprofil wirken sofort |
| Hooks bleiben nach dem Abschalten aktiv | Hooks werden erst beim ersten Einschalten gesetzt und prüfen danach den Zustand; nie genutzte Features hooken nichts |
| Mehrere MB Daten und UI-Code bei jedem Login (Polestar-Issues: 70–250 MB RAM) | ~200 KB gesamt; das Einstellungsfenster wird erst beim ersten Öffnen gebaut |
| Taint durch Überschreiben fremder Funktionen und Schreiben in Blizzard-Tabellen | Nur `hooksecurefunc`, keine ersetzten Globals, keine Felder auf Blizzard-Frames |
| ~90 Optionen, uneinheitliche Standardwerte, Chat-Meldung pro Aktion | 10 Features in drei Bereichen, eine klare Regel für Standardwerte, höchstens eine Chat-Zeile pro Aktion (abschaltbar) |
| FlareUI ohne Deutsch; Polestar-Sprachen als 18 Zusatz-Addons | enUS und deDE eingebaut, per Test auf Vollständigkeit geprüft |
| Fehler in einem Teil reißen andere mit | Fehler beim Einschalten schalten nur das betroffene Feature ab; fehlt eine Client-API, wird das Feature als „nicht verfügbar“ angezeigt |
| Polestars Layout (Seitenleiste, Suche, Zeilen mit Pillenschaltern) | Als Vorbild übernommen und weitergedacht: Hauptfunktionen in der Seitenleiste, ihre Unterbereiche als Tabs im Inhalt, eigene Farbwelten, runde Ecken, eigene Schrift (Inter) |

## Aufbau

```
Famulus/
  Famulus.toc
  Core/Init.lua        Namespace, Event-Verteiler, Hilfsfunktionen
  Core/Locale.lua      Sprachumschaltung zur Laufzeit
  Core/Database.lua    Einstellungen (nur Abweichungen vom Standard werden gespeichert)
  Core/Features.lua    Feature-Registry und Feature-Klasse, Slash-Befehle
  Core/ChatService.lua   Service für Klartext-Prüfung und Chat-Sperre
  Core/GroupService.lua  Service: wer gerade in deiner Gruppe ist
  Core/SelfTest.lua    Selbsttest gegen den echten Client (/fam test, /fam dev)
  Locales/             enUS.lua (Referenz), deDE.lua
  Modules/<Kategorie>/ eine Datei je Feature, z. B. Aliases/ChatAliases.lua;
                       geteilter Code heißt <Name>Service.lua, z. B. Aliases/AliasService.lua
  UI/                  Theme, Widgets, Fenster, Chronik-Buch, Weggefährten-Übersicht, Live-Einblendung, Minikartensymbol
  Media/               kleine TGA-Texturen und Symbole (aus tools/make_media.py)
  Media/Fonts/         Inter in drei Schnitten, auf Latein/Griechisch/Kyrillisch gekürzt
                       (aus tools/make_fonts.py, Lizenz: SIL OFL 1.1, LICENSE.txt daneben)
tests/                 nachgestellte WoW-API + Testlauf
tools/                 Texturen und Schriften erzeugen, Selbsttest-Bericht lesen, Release-Tag prüfen
.github/workflows/     Tests bei jedem Push, Upload auf CurseForge bei einem Tag
.pkgmeta               was der Packager ins Zip packt
CHANGELOG.md           ein Abschnitt je Version, wird der Changelog auf CurseForge
LICENSE                alle Rechte vorbehalten (kommt mit ins Zip)
```

### Ein Feature hinzufügen

Neue Datei `Modules/Chronicle/MeinFeature.lua` anlegen und in der `.toc` eintragen:

```lua
local feature = ns:NewFeature({
    id = "meinFeature", category = "chronicle", default = false,
    requires = { "C_Irgendwas.Funktion" },   -- fehlt die API, bleibt das Feature aus
})
function feature:OnEnable() self:RegisterEvent("SOME_EVENT") end
function feature:SOME_EVENT(event, ...) end
```

Dazu `L.f_meinFeature` und `L.f_meinFeature_desc` in **beiden** Locale-Dateien. Die Zeile im
Einstellungsfenster entsteht von selbst.

### Eine Hauptfunktion hinzufügen

Größere Funktionen bekommen einen eigenen Eintrag in der Seitenleiste: Kategorie in
`ns.categories` und einen Bereich in `ns.areas` (`Core/Features.lua`) eintragen, dazu
`L.area_<id>` und `L.area_<id>_desc`. Der Aufbau der Seite ist eine Funktion in `layouts`
(`UI/Options.lua`), die die Unterbereiche (Tabs oben im Inhalt) liefert, wie bei Chronik und Aliasen. Das Symbol steht in
`AREA_ICONS`.

### Eine Sprache hinzufügen

`Locales/xxXX.lua` nach dem Muster von `deDE.lua` anlegen, in der `.toc` eintragen und den
Anzeigenamen in `LANGUAGE_NAMES` (`UI/Options.lua`) ergänzen.

## Website

Unter `website/` liegt die Seite zum Addon: statisch, ohne Build-Schritt und ohne Bibliotheken,
Deutsch und Englisch. Die Landschaft im Hintergrund zeichnet `scene.js` selbst; die Demos bauen
Fenster, Bilderbuch und Einblendung nach. Ansehen:

```bash
python3 -m http.server 4173 --directory website
```

Danach `http://localhost:4173` öffnen.

## Veröffentlichen

Ein Tag baut das Addon auf GitHub und lädt es auf CurseForge hoch: `v1.2.3` als Release,
`v1.2.3-beta.1` als Beta, `v1.2.3-alpha.1` als Alpha. Andere Tags brechen vor dem Bauen ab.
Pushes und Pull Requests führen nur die Tests aus. Vorher braucht `CHANGELOG.md` einen Abschnitt
`## 1.2.3`:

```bash
bash tools/release_check.sh v1.2.3
git tag v1.2.3 && git push origin v1.2.3
```

Einzelheiten in `AGENTS.md` unter „Veröffentlichung auf CurseForge“.

## Tests

```bash
luajit tests/run.lua
```

Lädt das Addon gegen eine nachgestellte Client-API und prüft jedes Feature, das
Einstellungsfenster und die Vollständigkeit der Übersetzungen. Das ersetzt keinen Test im
Spiel: Ob der echte Client jede API genauso liefert, zeigt nur das Spiel selbst.

### Im Spiel

`/fam test` prüft im laufenden Spiel, ob der Client alles bereitstellt, was Famulus annimmt, und
meldet Auffälligkeiten im Chat. Nach `/reload` steht der Bericht in den gespeicherten Variablen:

```bash
luajit tools/read_selftest.lua
```

`/fam dev` schaltet den Entwicklermodus um: Der Selbsttest läuft dann nach jedem Login von selbst,
und blockierte Aktionen des Addons werden mitgeschrieben.

## Lizenz

Alle Rechte vorbehalten, siehe `LICENSE`. Erlaubt sind: den Code ansehen, das Addon für den
eigenen Gebrauch ändern und das Repository auf GitHub forken, um Änderungen als Pull Request
vorzuschlagen. Weitergeben, auf andere Seiten hochladen, als eigenes Projekt veröffentlichen oder
den Namen „Famulus“ verwenden nur mit schriftlicher Erlaubnis. Die Schrift Inter steht unter der
SIL Open Font License 1.1.
