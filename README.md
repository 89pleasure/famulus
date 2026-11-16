# Schnitzel

Schlankes Quality-of-Life-Addon für **World of Warcraft: Forever** (Interface 16001) mit
aufgeräumtem Einstellungsfenster. Englisch und Deutsch, keine Bibliotheken, keine Abhängigkeiten.

## Installation

1. Den Ordner `Schnitzel/` (oder den Inhalt von `dist/Schnitzel-0.1.0.zip`) nach
   `World of Warcraft/_forever_/Interface/AddOns/` kopieren.
2. Spiel starten bzw. `/reload`.
3. `/sz` öffnet die Einstellungen (alternativ `/schnitzel`, das Minikartensymbol oder der
   Eintrag im Addon-Menü der Minikarte).

## Funktionen (Version 0.1.0)

| Seite | Funktion | Standard |
|---|---|---|
| Händler | Automatisch reparieren (optional zuerst Gildengold) | aus |
| Händler | Plunder verkaufen | aus |
| Quests | Quests automatisch annehmen (graue Quests optional ignorieren) | aus |
| Quests | Quests automatisch abgeben | aus |
| Beute | Automatisch plündern (spiegelt die Spieloption) | aus |
| Beute | Beim Aufheben gebundene Beute bestätigen (nur solo) | aus |
| Beute | Einfacheres Zerstören (Bestätigungswort eintragen) | aus |
| Soziales | Einladungen von Freunden/Gilde annehmen | aus |
| Soziales | Duelle ablehnen | aus |
| Tooltips | Gegenstands- und Zauber-IDs | aus |
| Tooltips | Tooltip am Mauszeiger | aus |
| Interface | Koordinaten auf der Weltkarte (Klick setzt die eigene Position in den Chat) | **an** |
| Interface | Pfeiltasten im Chat ohne Alt | **an** |
| Interface | Maximale Kameradistanz | aus |
| Interface | Fehlermeldungs-Spam im Kampf ausblenden | aus |
| Interface | Screenshot beim Stufenaufstieg | aus |

Jede Seite hat oben rechts einen **Hauptschalter für die ganze Kategorie**. Ist er aus, läuft auf der
Seite nichts und nichts lauscht auf das Spiel; die Auswahl der einzelnen Funktionen bleibt erhalten.

Grundregel für die Standardwerte: Alles, was in deinem Namen handelt (Gold ausgibt, Gegenstände
verkauft, Quests oder Einladungen annimmt), ist anfangs aus. Die **Pausentaste** (Standard:
Umschalt) überspringt jede Automatik einmalig.

## Was von OneForAll, FlareUI und Polestar gelernt wurde

| Beobachtung bei den Vorbildern | Umsetzung in Schnitzel |
|---|---|
| OneForAll registriert ~38 Events dauerhaft und prüft die Option erst im Handler; FlareUI-Untermodule ebenso | Ein Feature registriert Events erst beim Einschalten. Nach dem Login mit Standardwerten lauscht das Addon auf **kein** Spielereignis |
| Ungedrosselte `OnUpdate`-Handler (Tooltip-Anker, Minikarten-Drag, Proximity-Scan) | Kein `OnUpdate` im Leerlauf. Kartenkoordinaten laufen nur bei offener Karte (10×/s), Animationen nur solange sie dauern |
| FlareUI: Modul umschalten = `/reload`; OneForAll: Sprache/Profil = Reload | Jede Option, die Sprache und das Charakterprofil wirken sofort |
| Hooks bleiben nach dem Abschalten aktiv | Hooks werden erst beim ersten Einschalten gesetzt und prüfen danach den Zustand; nie genutzte Features hooken nichts |
| Mehrere MB Daten und UI-Code bei jedem Login (Polestar-Issues: 70–250 MB RAM) | ~200 KB gesamt; das Einstellungsfenster wird erst beim ersten Öffnen gebaut |
| Taint durch Überschreiben fremder Funktionen und Schreiben in Blizzard-Tabellen | Nur `hooksecurefunc`, keine ersetzten Globals, keine Felder auf Blizzard-Frames |
| ~90 Optionen, uneinheitliche Standardwerte, Chat-Meldung pro Aktion | 16 Features auf 6 Seiten, eine klare Regel für Standardwerte, eine Sammelzeile pro Aktion (abschaltbar) |
| FlareUI ohne Deutsch; Polestar-Sprachen als 18 Zusatz-Addons | enUS und deDE eingebaut, per Test auf Vollständigkeit geprüft |
| Fehler in einem Teil reißen andere mit | Fehler beim Einschalten schalten nur das betroffene Feature ab; fehlt eine Client-API, wird das Feature als „nicht verfügbar“ angezeigt |
| Polestars Layout (Seitenleiste, Suche, Zeilen mit Pillenschaltern) | Als Vorbild übernommen – mit eigener Farbpalette und ohne mitgelieferte Schriften |

## Aufbau

```
Schnitzel/
  Schnitzel.toc
  Core/Init.lua        Namespace, Event-Verteiler, Hilfsfunktionen
  Core/Locale.lua      Sprachumschaltung zur Laufzeit
  Core/Database.lua    Einstellungen (nur Abweichungen vom Standard werden gespeichert)
  Core/Features.lua    Feature-Registry und Feature-Klasse, Slash-Befehle
  Core/GameOptions.lua Schalter, die eine Spieloption spiegeln
  Core/PopupService.lua  Service für Blizzards StaticPopup-Dialoge
  Core/ChatService.lua   Service für die Chat-Eingabe (Text einsetzen, Chat-Sperre)
  Core/SelfTest.lua    Selbsttest gegen den echten Client (/sz test, /sz dev)
  Locales/             enUS.lua (Referenz), deDE.lua
  Modules/<Seite>/     eine Datei je Feature, z. B. Interface/ChatArrowKeys.lua;
                       geteilter Code heißt <Name>Service.lua, z. B. Quests/QuestService.lua
  UI/                  Theme, Widgets, Einstellungsfenster, Minikartensymbol
  Media/               vier kleine TGA-Texturen (aus tools/make_media.py)
tests/                 nachgestellte WoW-API + Testlauf
tools/                 Texturen erzeugen, Selbsttest-Bericht lesen
```

### Ein Feature hinzufügen

Neue Datei `Modules/Interface/MeinFeature.lua` anlegen und in der `.toc` eintragen:

```lua
local feature = ns:NewFeature({
    id = "meinFeature", category = "interface", default = false,
    requires = { "C_Irgendwas.Funktion" },   -- fehlt die API, bleibt das Feature aus
})
function feature:OnEnable() self:RegisterEvent("SOME_EVENT") end
function feature:SOME_EVENT(event, ...) end
```

Dazu `L.f_meinFeature` und `L.f_meinFeature_desc` in **beiden** Locale-Dateien. Die Zeile im
Einstellungsfenster entsteht von selbst.

### Eine Sprache hinzufügen

`Locales/xxXX.lua` nach dem Muster von `deDE.lua` anlegen, in der `.toc` eintragen und den
Anzeigenamen in `LANGUAGE_NAMES` (`UI/Options.lua`) ergänzen.

## Tests

```bash
luajit tests/run.lua
```

Lädt das Addon gegen eine nachgestellte Client-API und prüft jedes Feature, das
Einstellungsfenster und die Vollständigkeit der Übersetzungen. Das ersetzt keinen Test im
Spiel: Ob der echte Client jede API genauso liefert, zeigt nur das Spiel selbst.

### Im Spiel

`/sz test` prüft im laufenden Spiel, ob der Client alles bereitstellt, was Schnitzel annimmt, und
meldet Auffälligkeiten im Chat. Nach `/reload` steht der Bericht in den gespeicherten Variablen:

```bash
luajit tools/read_selftest.lua
```

`/sz dev` schaltet den Entwicklermodus um: Der Selbsttest läuft dann nach jedem Login von selbst,
und blockierte Aktionen des Addons werden mitgeschrieben.
