# Chronik

Teil des Projektwissens; Vorgaben, Regeln und die Übersicht aller Dateien stehen in
[AGENTS.md](../AGENTS.md). Verweise der Form „siehe X“ meinen eine Überschrift oder einen fett
gesetzten Eintrag; in welcher Datei er steht, sagt die Übersicht dort.

Idee des Auftraggebers (2026-11-19): die Reise des Spielers und seiner Gefährten festhalten
(Stufenaufstiege, Tode, Erfolge und mehr), grafisch aufbereitet „wie ein Bilderbuch“, am liebsten
mit Live-Benachrichtigung. Stand: Erfassung, das Teilen zwischen Spielern, die Benachrichtigung
und die Bilderbuch-Optik sind gebaut und nur gegen den Mock geprüft.

- **Aufbau:** Bereich und Kategorie `chronicle`, Daten über `ns.ChronicleService`
  (`Modules/Chronicle/ChronicleService.lua`) in `FamulusDB.chronicle` (accountweit, außerhalb der
  Profile, höchstens 2000 Einträge, Art und Werte statt Text). Reiter „Alle“, „Meine Reise“,
  „Freunde“ (bis 2026-11-24 „Gefährten“, siehe „Chronik und Weggefährten“) und „Einstellungen“
  (bis 2026-11-23 „Aufzeichnung“) (`layouts.chronicle`). In den Projektnotizen heißen die Personen der
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
    Bis 2026-11-25 standen unter der Zeile alle Uhrzeiten als kleine Plaketten; seitdem nennt der
    Fuß der Karte die erste und die letzte („20:02 – 21:14 · Dunkelküste“, siehe „Gewichtung“).
    Eigene Stufenaufstiege bleiben einzeln. Die Zahl der
    Ereignisse im Kapitelkopf zählt weiter jeden Eintrag.
  - **Kapitelkopf in einer Zeile:** links die Zeit (bis 2026-11-24 der Tag), Mitte der Titel in
    der Buchschrift (22 px; bis 2026-11-24 das Gebiet), Stufen und Zahl der Ereignisse rechts,
    außen je eine Linie, die zum Rand hin ausläuft. Etwa 36 px hoch statt über 100, mit der Route
    darunter 30 px mehr. Die Zierde mit dem Funken ist entfallen.
- **Ein Kapitel ist ein Spielabend (Entscheidung des Auftraggebers, 2026-11-24, an der Leinwand
  „Famulus Chronik – Kapitel“, claude.ai-Artifact `Sp9tF6ba6wfgKroNqejVoT`: Variante C):** Anlass:
  Ein Kapitel je Tag hieß nach dem Gebiet, das die meisten Einträge nannten („Heute · Feralas“),
  dabei zieht man beim Spielen durch mehrere Gebiete. Gezählt wurden auch die Gebiete der
  Freunde, und Mitternacht teilte einen Spielabend. Verworfen: A (Tag mit Route), B (Wegmarken
  auf der Linie; „der Ort ist weniger wichtig als die Ereignisse selbst“), D (der wichtigste
  Moment als Titel), E (Stufen als Kapitel). Nur gegen den Mock geprüft, im Spiel nicht gesehen.
  - Ein neues Kapitel beginnt nach einer Pause von zwei Stunden zwischen zwei gezeigten Einträgen
    (`SESSION_GAP` in `UI/Options.lua`). Gezählt wird, was der Reiter zeigt, im gefilterten Buch
    also nur die Einträge der Person. Eine Abfrage von Login und Logout gibt es nicht; eine
    lange Pause teilt den Abend.
  - **Titel** nach der Tageszeit, zu der die Sitzung begann (`SessionTitle`): Morgen ab 5, Mittag
    ab 11, Nachmittag ab 14, Abend ab 18, Nacht ab 23 Uhr. Bis 5 Uhr früh zählt die Nacht zum Tag
    davor (`NIGHT_SHIFT`), damit ein Abend bis 2 Uhr „Gestern Nacht“ bleibt und nicht „Heute
    Nacht“ heißt. „Heute Abend“, „Gestern Nachmittag“; ältere heißen nach dem Wochentag
    („Sonntagnacht“, enUS „Sunday night“) und tragen links das Datum statt der Zeit. Texte
    `c_when_<today|yesterday|day>_<teil>`, `c_weekday_0` bis `_6` (eigene Wochentage, weil
    unklar ist, ob Forever `CALENDAR_WEEKDAY_NAMES` kennt).
  - Links von–bis (`c_ch_span`), bei nur einer Uhrzeit diese allein.
  - **Route** unter dem Kopf: die Gebiete der eigenen Einträge in zeitlicher Reihenfolge, als
    Plaketten mit Pfeilen (`chevron.tga`, gedreht); ein Gebiet steht wieder, wenn man
    zurückkehrt. Gebiete der Freunde zählen nicht. Ist die Zeile breiter als das Buch, weichen die
    ältesten Gebiete einem „…“. Die Route kennt nur Gebiete, in denen etwas festgehalten wurde
    (wer nur durchreitet, taucht nicht auf); jeden Gebietswechsel mitzuschreiben wäre möglich,
    ist aber nicht beauftragt.
  - Im Spiel lief die Route beim ersten Mal auf einen Fehler (`head.width`, siehe „Fehler
    2026-11-24“); behoben, danach lief die Chronik im Spiel („Funktioniert“).
  - Seit 2026-11-25 auch in „Eure Geschichte“ bei den Weggefährten (siehe dort). Kapitelkopf
    (`SessionHead`) und die Einteilung der Weggefährten-Bücher (`SessionChapters`, für „Runden“
    und „Eure Geschichte“) stehen je einmal in `UI/Options.lua`; gezeichnet wird alles von
    `UI.Book`. Offen: Die Website zeigt noch den alten Kapitelkopf.
- **Bilderbuch (2026-11-19):** Der Auftraggeber fand den HTML-Entwurf „schon ganz cool“ und ließ
  ihn so umsetzen. Die drei Erzähl-Reiter zeigen keine Zeilen mehr, sondern ein Buch
  (`UI.Book`, `UI/Book.lua`; ein Reiter liefert es über `tab.book`, `Render` legt es unter die
  Karten): je Tag (seit 2026-11-24 je Spielabend) ein Kapitel mit Überschrift, darunter eine
  Linie in der Mitte, an der die Ereignisse abwechselnd links und rechts als Karten hängen, mit Bild, Punkt auf der Linie und
  Uhrzeit auf der Gegenseite. Entscheidungen des Assistenten, noch nicht im Spiel gesehen:
  - Ein Kapitel hieß nach dem Gebiet, in dem die meisten seiner Ereignisse spielen; seit
    2026-11-24 ist es ein Spielabend mit eigenem Titel (siehe oben). Eine Kapitelnummer wie im
    Entwurf gibt es nicht (gezeigt werden nur die letzten 50 Ereignisse, eine Zählung wäre nicht
    stabil).
  - Bilder sind eigene Symbole (`skull.tga`, `swords.tga`, `peaks.tga`, `star.tga`, 64 px) oder
    bei Stufen die Zahl; Tod und Boss haben feste eigene Farbtöne, der Rest folgt der Farbwelt.
    Der eigene Stufenaufstieg ist der Meilenstein: größere Karte, Akzentrand, Akzentmarke links
    (der Schein ist seit dem Angleichen an die Options-Karten entfallen).
  - Ereignisse von Gefährten und von eigenen anderen Charakteren tragen eine Marke mit
    Anfangsbuchstabe; seit 2026-11-24 das Klassensymbol, sobald die Klasse bekannt ist (siehe
    „Klasse und Name“ unten).
  - Überschriften und Stufenzahl stehen in der Buchschrift des Spiels, gelesen aus dem
    Font-Objekt `QuestTitleFont` (`UI.SetDisplayFont`), damit jede Sprache ihre Datei bekommt;
    fehlt das Objekt, nimmt das Fenster Inter. `QuestTitleFont` gibt es im Forever-Client
    (Screenshot 2026-11-23, deDE: Kapitelüberschriften in der Buchschrift). Kursive Schrift wie
    im Entwurf gibt es nicht.
- **Überarbeitung nach dem ersten Screenshot (2026-11-19, vier Vorschläge des Assistenten, vom
  Auftraggeber alle angenommen):**
  1. **Name im Streifen:** Die Überschrift eines Gefährten-Ereignisses nennt ihn im Buch nicht mehr
     („Schlafsack erhalten“ statt „Mira erhält: Schlafsack“); der Name (oder Alias) steht mit dem
     Anfangsbuchstaben im vertieften Streifen unten (seit 2026-11-25 im Kopf der Karte, siehe
     „Gewichtung“). `ChronicleService.Text(entry, true)` liefert
     die Überschrift ohne Namen; die Einblendung hat keinen Streifen und nimmt `story.fullTitle`.
     Seit 2026-11-24 mit Klassensymbol und „Alias (Charaktername)“, siehe „Klasse und Name“.
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
- **Der Bildrahmen war im Buch bei jedem Ereignis gleich groß** (54 px; Vorgabe des Auftraggebers,
  2026-11-19). Seit 2026-11-25 hat er im Buch der Chronik je Gewicht eine eigene Größe (40, 48,
  56 px), siehe „Gewichtung“; die Weggefährten behalten 54 px.
- **Gewichtung und Aufbau der Karten (Wunsch des Auftraggebers, 2026-11-25; nur gegen den Mock
  geprüft, im Spiel noch nicht gesehen):** Gilt nur für das Buch der Chronik. Jedes Ereignis dort
  hat ein Gewicht (`story.weight`, Tabelle `WEIGHT` in `UI/Options.lua`, Maße in `WEIGHTS` in
  `UI/ChronicleCard.lua`):
  - **Leicht** (`low`): Tode, Ankünfte in neuen Gebieten. Bild 40 px, Überschrift 12 px.
  - **Mittel** (`medium`): Berufs-Meilensteine und alles, was der Auftraggeber nicht eingeordnet
    hat (Herausforderungen, Gegenstände, Fähigkeiten, Beruf erlernt; Entscheidung des
    Assistenten). Bild 48 px, Überschrift 13 px.
  - **Schwer** (`high`): Bosse und Stufenaufstiege, dazu was die Tabellen mit `big` markieren
    (Reiten). Bild 56 px. Das bisherige Meilenstein-Aussehen: Akzentrand, Akzentmarke links, Überschrift
    15 px halbfett. Wörtlich nach Art umgesetzt: Auch Stufen und Bosse von Freunden
    sind schwer (vorher nur der eigene Aufstieg).
  - **Aufbau neben dem Bild:** Kopf, Inhalt, Fuß. Der Kopf nennt die Person (Klassensymbol, sonst
    Anfangsbuchstabe, und `ChronicleService.Label`); bei eigenen Ereignissen gibt es ihn nicht.
    Seit 2026-11-25 (Wunsch des Auftraggebers) steht er als eigene Reihe über Bild und Text,
    bündig mit dem Bild, nicht mehr über dem Text rechts vom Bild; die Reihe ist ein vertiefter
    Streifen über die ganze Kartenbreite wie früher der Name unten (`sunken`, oben rund, unten
    eine feine Linie, 28 px hoch, Klassensymbol 18 px).
  - **Streifen mit Typ-Icon, Punkte ohne Symbol (Wunsch des Auftraggebers, 2026-11-25):** Der
    Streifen steht seitdem auf jeder Karte der Chronik, bei eigenen Ereignissen mit dem Namen
    des eigenen Charakters (`ChronicleService.Character`, Klasse aus `ChronicleService.Class`;
    gesetzt in `ChronicleRun`). Rechtsbündig darin das Symbol der Art (`mark` aus
    `UI.BookPictures`, oder `story.icon` wie das Hufeisen), 13 px in Akzentfarbe; vorher stand es
    auf dem Punkt der Linie. Der Kreis mit dem Anfangsbuchstaben links vom Namen ist entfallen:
    links steht das Klassensymbol, wo die Klasse bekannt ist, sonst beginnt der Name am Rand
    (Entscheidung des Assistenten: wörtlich „das Initial-Icon kann weg“, das Klassensymbol
    bleibt). Die Punkte auf der Linie sind leuchtende Punkte in Akzentfarbe wie früher die
    Anzeige „x von y aktiv“ (`UI.Halo` mit `accentGlow`, dreimal so groß wie der Punkt), in
    allen Büchern, also auch bei den Weggefährten (Book-Design). Die Größe legt das Book nach
    Gewicht fest (`DOTS`: leicht 5, mittel 7, schwer 9 px; ohne Gewicht mittel, mit `big`
    schwer; Wunsch des Auftraggebers, die Größen hat der Assistent gewählt).
    Der Fuß nennt immer Uhrzeit und Ort („21:14 · Dunkelküste“, ohne Ort nur die Uhrzeit).
  - **Höhe nach Inhalt, gleiche Kanten (Wunsch des Auftraggebers nach dem ersten Screenshot,
    2026-11-25):** Die erste Fassung hielt die Kopfzeile auch ohne Namen und immer zwei Zeilen
    Text frei und hängte Rand und Bildgröße ans Gewicht; im Spiel sah das hohl und unruhig aus
    (leere Flächen, Bild und Text je Gewicht an anderer Stelle). Seitdem ist die Karte so hoch
    wie Bild oder Text plus Rand oben und unten. Seitlich haben alle Karten denselben Rand
    (`SIDE`), das Bild steht linksbündig, und der Text hält immer denselben Abstand zum Bild
    (`TEXT_GAP`; drei Größen 40/48/56, linksbündig und fester Abstand auf Wunsch des
    Auftraggebers, 2026-11-25; eine Bildspalte in der Breite des größten Bildes ließ bei
    leichten Karten zu viel Platz). Die Textkante wandert also mit der Bildgröße. Bild und Text
    beginnen auf derselben Höhe, der Fuß endet mit dem Bild, falls das Bild höher ist (Wunsch
    des Auftraggebers, 2026-11-25; vorher standen beide mittig zueinander und hatten
    verschiedene Abstände zum oberen Rand).
  - **Breite nach Gewicht, vom Book festgelegt (Wunsch des Auftraggebers, 2026-11-25):** Das
    Feature gibt nur `story.weight` mit; `UI.Book` macht daraus die Breite der Karte (`WIDTHS`
    in `UI/Book.lua`: leicht 80 %, mittel 90 %, schwer 100 % ihrer Buchseite; die Anteile sind
    eine Entscheidung des Assistenten). Eine schmalere Karte hängt an der Linie, damit der
    Strich vom Punkt sie erreicht. Ohne Gewicht (Weggefährten) ist die Karte so breit wie
    bisher. Der Inhalt bekommt die Breite übergeben und richtet sich danach. Das Gewicht wirkt nur auf Bildgröße, Rand
    oben und unten, Überschrift und Akzent. Seit 2026-11-25 (Wunsch des Auftraggebers nach einem
    Screenshot: bei HIGH war der Abstand zur Namensleiste größer als bei MEDIUM und LOW) legt
    das Book den Innenabstand fest, `UI.BookPad` (14 px), gleich an allen Seiten, für jedes
    Gewicht und unter der Namensleiste. Gemessen vom äußeren Rand; weil Haarlinie und
    Lichtkante oben innen je etwa einen Pixel nehmen und die Linie der Namensleiste in der
    Leiste liegt, bekommt oben einen Pixel mehr (`UI.BookPadTop`) und unter der Namensleiste
    einen weniger. Nachgemessen am Screenshot vom 2026-11-25 (vorher sichtbar: unter der
    Leiste 32, seitlich 30, oben 27 Bildschirmpixel); das Gewicht wirkt nur noch auf Breite, Bildgröße,
    Überschrift und Akzent. Eine leichte Karte mit zwei Zeilen Text kann deshalb höher sein
    als eine mittlere mit einer. Die Weggefährten haben ihren eigenen Rand behalten (12, bei
    Meilensteinen 15 px). Entscheidungen des Assistenten im Einzelnen; im
    Spiel noch nicht gesehen. Der vertiefte Streifen mit dem Namen unter der Karte
    ist entfallen; die Weggefährten behalten ihren Streifen (`story.foot`).
  - **Der Ort steht nie im Text:** Das Buch liest die Sätze mit ausgeblendetem Gebiet
    (`Placeless` in `UI/Options.lua`): „Gefallen“ statt „Gefallen in Dunkelküste“, „Neues Gebiet
    entdeckt“ (`c_zone_nowhere`) statt „Ankunft in Feralas“, „in Uldaman“ fällt aus der Zeile
    unter einem Boss weg, „mit Mira und Tom“ bleibt. Die Live-Einblendung hat keinen Fuß und
    nennt den Ort weiter.
  - **Das Buch gibt das Design vor, jedes Feature den Inhalt seiner Karten** (Vorgabe des
    Auftraggebers, 2026-11-25, nachdem die erste Fassung auch die Boss-Karten in „Eure
    Geschichte“ umgebaut hatte: „so können wir in jedem Feature selbst entscheiden, wie der
    Inhalt der Karte ist, haben aber immer das gleiche Design des Books“). `UI.Book` kennt nur
    Kapitel, Linie, Punkte und den Stil der Karte (Grund, Haarlinie, Lichtkante, Leuchten unter
    der Maus, Akzent über `story.big`, Klick). Den Inhalt baut `story.content(part, story,
    width)` in einen eigenen Rahmen der Karte und gibt seine Höhe zurück; die Karte wächst mit.
    Je Builder-Funktion hat jede Karte ihren eigenen Rahmen, der wiederverwendet wird (deshalb
    dieselbe Funktion für alle Karten einer Art, keine neue Closure je Story). Inhalte:
    `UI.ChronicleCard` (`UI/ChronicleCard.lua`, gesetzt in `ChronicleRun`) und `UI.FellowCard`
    (`UI/Fellows.lua`, gesetzt in `SessionChapters`; aussehen wie vorher, im Mock Karte für Karte
    gleich hoch wie auf `main`). Gemeinsamer Baustein: der Bildrahmen (`UI.BookPicture`,
    `UI.SetBookPicture` in `UI/Book.lua`: Spielsymbol, eigenes Symbol, Zahl, Zähl-Plakette,
    Tooltip). `ChronicleEvent` liefert weiter nur die Daten, auch für die Live-Einblendung, die
    unverändert ist.

- **Bilder sind Symbole des Spiels (Wunsch des Auftraggebers, 2026-11-19):** Sie sind eckig und es
  gibt sehr viele; die eigenen Zeichnungen (`skull.tga` usw.) stehen nur noch klein im Streifen
  der Karte (bis 2026-11-25 auf dem Punkt der Zeitlinie) und als Rückfall. Reihenfolge (`EntryTexture` in `UI/Options.lua`):
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
    in eigenen Farben, also ohne `UI.Tint`, mit beschnittenem Rand im runden Rahmen. Das kleine
    Symbol (im Streifen, früher auf dem Punkt der Zeitlinie) bleibt die Truhe; kennt der Client kein Symbol, steht sie auch im Bild. Das ist
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
  **Sprache (2026-11-24, Wunsch des Auftraggebers, für englische Screenshots):** Gebiete, Namen
  und Personen der Beispiele folgen der Sprache von Famulus (`ns:GetLocaleCode()` in
  `Core/Locale.lua`), nicht mehr der des Clients (`GetLocale()`). Die Personen heißen auf Englisch
  Mira Stormfeather, Borin Ironbeard und Lysa Morningdew (Deutsch: Sturmfeder, Eisenbart,
  Morgentau), in beiden Diensten gleich, damit die Verweise zwischen Chronik und Weggefährten
  greifen. Nach einem Sprachwechsel die Beispiele neu schreiben; die alten bleiben in ihrer
  Sprache. Was der Client selbst benennt, bleibt in seiner Sprache: Gegenstände
  (`C_Item.GetItemNameByID`, „Schlafsack“) und Klassen (`LOCALIZED_CLASS_NAMES_MALE`, „Magier“).
  Für ein ganz englisches Bild muss also der Client auf Englisch stehen. Der Test prüft beide
  Sprachen auf einem deutschen Client. Nur gegen den Mock geprüft.
- **`companions`:** vergleicht bei `FRIENDLIST_UPDATE` die Stufen der Freundesliste mit dem zuletzt
  gemerkten Stand (nach GUID). Zeigt Gefährten unter ihrem Alias.
- **`sharing` (Entscheidung des Auftraggebers, 2026-11-19):** Famulus spricht mit Famulus über
  geflüsterte Addon-Nachrichten an Freunde und Gilde; Protokoll, Weiterreichen, Statistiken und
  Warteschlange stehen in [sharing.md](sharing.md).
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
- **Klasse und Name (Wunsch des Auftraggebers, 2026-11-24; nur gegen den Mock geprüft):** Neben
  dem Namen eines Freundes stand ein Kreis mit dem Anfangsbuchstaben; jetzt steht dort das
  Klassensymbol des Spiels (`UI-Classes-Circles`, `UI.ClassIcon`/`UI.SetClass` in
  `UI/Widgets.lua`, die auch das Wappen der Weggefährten nutzt): im Kopf einer Karte des
  Buchs und in der Randspalte (Liste „Freunde“, Bilanz-Karten). Ist die Klasse unbekannt, bleibt
  in der Randspalte der Buchstabe; im Buch steht seit 2026-11-25 dann nur der Name. Hinter einem Alias steht der Charaktername in Klammern, „Papa (Borin Eisenbart)“
  (`ChronicleService.Label`), überall, wo die Chronik die Person nennt: Streifen, Randspalte,
  Filterzeile „Nur Ereignisse von …“ und die Sätze der Live-Einblendung. Ohne Alias steht nur der
  Name.
  - **Option** „Charaktername hinter dem Alias“ (`general.chronicleNames`, Standard an) als eigene
    Karte „Anzeige“ unter Chronik › Einstellungen, unter den Features. Aus: nur der Alias. Die
    Option gilt nur für die Klammern; das Klassensymbol hat keinen Schalter (vom Auftraggeber
    bestätigt, 2026-11-24).
  - **Der Charaktername steht nicht mehr in der Zeile unter der Überschrift** („Jaina Proudmoore ·
    in Duskwood“ war der frühere Platz unter einem Alias). Entscheidung des Assistenten: Mit der
    Option an stünde er sonst doppelt da, und wer die Option ausschaltet, will ihn nicht sehen.
    Ebenso entfällt er als zweite Zeile der Bilanz-Karten.
  - **Woher die Klasse kommt** (`FamulusDB.chronicle.classes = { [name] = "MAGE" }`, über
    `ChronicleService.Class`): Freunde mit Famulus schicken ihre Klasse mit der Bilanz (`1~S~…`,
    siehe „sharing“); „Freunde begleiten“ merkt sie aus der Freundesliste, wenn es einen Aufstieg
    festhält (`className` in der Sprache des Clients, zurückübersetzt über
    `LOCALIZED_CLASS_NAMES_MALE`/`_FEMALE`, `SocialService.ClassFromName`); die eigenen
    Charaktere tragen ihre Klasse mit jedem eigenen Eintrag und beim Login ein (nur, wenn es die
    Chronik schon gibt). Die Beispieldaten haben Klassen wie bei den Weggefährten (Mira Magierin,
    Borin Krieger, Lysa Priesterin). Gespeichert wird nur für Personen mit Eintrag oder Bilanz; der
    Rest fällt beim Laden heraus. Die Daten der Weggefährten werden bewusst nicht gelesen (siehe
    „Chronik und Weggefährten“: jeder Bereich steht für sich).
  - **Gildenliste und Freundesliste als Quelle (Wunsch des Auftraggebers, 2026-11-24, eigener PR;
    nur gegen den Mock geprüft):** Zeigt das Fenster „Alle“ oder „Freunde“ der Chronik, sieht es
    einmal in Freundesliste und Gildenliste (`SocialService.Classes`, gebaut wie
    `SocialService.Online`) und merkt sich die Klassen der Personen der Chronik
    (`ChronicleService.LearnClasses`). Die Gildenliste nennt die Klasse jedes Mitglieds, auch
    offline, schon in der Form `MAGE` (elfter Wert von `GetGuildRosterInfo`, von
    `SocialService.EachGuildMember` als fünfter Wert weitergegeben); die Freundesliste nur für
    Freunde, die online sind. Online/offline der Randspalte kommt weiter aus
    `ChronicleService.OnlineCheck`; das sind zwei Blicke in die Listen je Aufbau, bewusst nicht
    zusammengelegt, damit `SocialService` bei je einer Frage je Funktion bleibt. Das geschieht im
    Aufbau des Reiters vor Buch und Randspalte, die
    Klasse ist also sofort zu sehen. Kein Spielereignis, kein Timer: Ohne offenes Fenster läuft
    dafür nichts. Gemerkt wird nur für Personen mit Eintrag oder Bilanz, „Meine Reise“ sieht nicht
    nach. Ungeprüft im Spiel: ob der Client die Gildenliste nach dem Login von selbst lädt (sonst
    erst, wenn „Mit Freunden teilen“ sie anfordert oder das Gildenfenster offen war).
  - **Lücken:** Ein Freund mit älterem Famulus, nicht in der Gilde, der weder seit dem Update
    aufgestiegen ist noch bei offenem Fenster online war, zeigt weiter den Buchstaben.
  - Die Website zeigt im Buch der Chronik noch Anfangsbuchstaben.
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
