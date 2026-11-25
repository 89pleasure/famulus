# Website

Teil des Projektwissens; Vorgaben, Regeln und die Übersicht aller Dateien stehen in
[AGENTS.md](../AGENTS.md). Verweise der Form „siehe X“ meinen eine Überschrift oder einen fett
gesetzten Eintrag; in welcher Datei er steht, sagt die Übersicht dort.

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
