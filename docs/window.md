# Das Fenster

Teil des Projektwissens; Vorgaben, Regeln und die Übersicht aller Dateien stehen in
[AGENTS.md](../AGENTS.md). Verweise der Form „siehe X“ meinen eine Überschrift oder einen fett
gesetzten Eintrag; in welcher Datei er steht, sagt die Übersicht dort.

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
    Unterbereiche „Reiter“ (`page.tabs`, `window.tabs`, Texte `ui_tab_<id>`); wo die Projektnotizen
    „Reiter“ eines Bereichs sagen, sind die Einträge der Seitenleiste gemeint. Die Reiterzeile im
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
