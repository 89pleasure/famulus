# Weggefährten

Teil des Projektwissens; Vorgaben, Regeln und die Übersicht aller Dateien stehen in
[AGENTS.md](../AGENTS.md). Verweise der Form „siehe X“ meinen eine Überschrift oder einen fett
gesetzten Eintrag; in welcher Datei er steht, sagt die Übersicht dort.

Idee aus einer Ideensammlung des Assistenten (2026-11-23), vom Auftraggeber ausgewählt: Famulus merkt
sich, mit wem der Spieler in einer Gruppe war. Begründung: Forever hat „Zuletzt zusammen gespielt“
nicht (siehe oben), und die Funktion braucht beim anderen kein Famulus.

- **Entscheidungen des Auftraggebers (2026-11-23):** eigener Bereich (nicht als
  Unterbereich von Aliasen oder Chronik; ein Eintrag in der Seitenleiste). Erste Version: die Liste (wer, wann, wo, wie oft, wie lange)
  und Boss-Einträge der Chronik, die nennen, wer dabei war. **Nicht** gewählt: Notizen zu Personen,
  Hinweis im Tooltip, Knopf „Freund hinzufügen“. Nicht einbauen, ohne zu fragen.
- **Aufbau:** Kategorie und Bereich `fellows`, ein Feature `rememberFellows`
  (`Modules/Fellows/RememberFellows.lua`, Standard aus, weil es auf Spielereignisse lauscht), Daten
  über `ns.FellowService` (`Modules/Fellows/FellowService.lua`). Wer gerade in der Gruppe ist, liefert
  `ns.GroupService` (`Core/GroupService.lua`), den auch die Chronik nutzt.
- **Daten:** `FamulusDB.fellows = { [guid] = { name, level, class, first, firstZone, last, zone,
  times, seconds, bosses, tag } }`, accountweit, außerhalb der Profile, nach GUID (ein Name kann sich
  ändern). `tag` ist der BattleTag, wenn die Person in der Gruppe als Battle.net-Freund erkannt
  wurde (seit 2026-11-24, siehe unten). Nichts davon wird verschickt. Höchstens 500 Personen; darüber fällt heraus, wer am
  längsten nicht mehr dabei war (nie jemand aus der aktuellen Gruppe). Dazu seit 2026-11-24 die
  Runden in `FamulusDB.fellowRuns` (siehe „Runden“).
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
- **Nur Freunde und Gilde, Aufräumen (Wunsch des Auftraggebers, 2026-11-24):** Anlass: Die Chronik
  hört nur von Freunden und Gildenmitgliedern, die Weggefährten merkten sich jeden aus einer Gruppe.
  Gewünscht waren eine Option dafür und ein Aufräumen für ehemalige Freunde und Gildenmitglieder.
  Umsetzung und Texte sind Entscheidungen des Assistenten.
  - **Option `friendsOnly`** („Nur Freunde und Gilde“, Standard aus, damit sich am bisherigen
    Verhalten nichts ändert): Aus der Gruppe zählt dann nur, wer auf der Freundesliste steht,
    Battle.net-Freund ist oder in der Gilde ist (`SocialService.Unit`: `C_FriendList.IsFriend(guid)`,
    `C_BattleNet.GetAccountInfoByGUID(guid)`, `UnitIsInMyGuild(unit)`; alle drei laut API-Doku des
    Branches `forever` vorhanden und nicht geheim; die beiden ersten laufen über `pcall`, weil
    `IsFriend` die geladene Freundesliste verlangt). Solange die Option an ist, hört das Feature
    zusätzlich auf `FRIENDLIST_UPDATE`, `PLAYER_GUILD_UPDATE`, `BN_FRIEND_LIST_SIZE_CHANGED` und
    `BN_CONNECTED` (alle vier registriert auch Blizzards Freundesfenster im Forever-Quellcode,
    `Blizzard_FriendsFrame/Camelot`): Wer in der Gruppe zum Freund oder Battle.net-Freund wird,
    zählt ab da, wer es nicht mehr ist, ab da nicht mehr. Wer schon in der Liste steht, bleibt dort.
    Nicht auf `BN_FRIEND_INFO_CHANGED`, das bei jeder Statusänderung eines Freundes kommt. Ohne die
    Option fragt der Abgleich nur den BattleTag ab (`SocialService.BattleTag`), nicht, wer Freund
    ist.
  - **Battle.net-Freunde zählen als Freunde** (Entscheidung des Assistenten): Die Freundesliste des
    Spiels zeigt sie mit, und der Auftraggeber hat Battle.net-Freunde (siehe Account-Aliase). Die
    Chronik kann mit ihnen nicht sprechen, sie flüstert nur Charakternamen an. Als Battle.net-Freund
    gilt nur, wen der Client ausdrücklich so nennt (`isFriend` oder `isBattleTagFriend` wahr; laut
    API-Doku des Branches `forever` sind beide nie nil). Im Zweifel ist jemand kein Freund, und sein
    BattleTag wird nicht gemerkt.
  - **Aufräumen** (Reiter „Einstellungen“, eigene Karte unter dem Feature): entfernt alle, die
    gerade weder auf der Freundesliste noch Battle.net-Freund noch in der Gilde sind, also auch
    Fremde aus der Zeit ohne die Option. Entscheidung des Assistenten: „ehemalig“ lässt sich für
    ältere Einträge nicht feststellen, weil nie gemerkt wurde, wer damals Freund war, und wer nur
    Freunde will, will die Fremden auch nicht. Wer gerade in der Gruppe ist, bleibt, auch ein
    Fremder, den die Option gerade nicht mitzählt (`GroupService.Members`, nicht nur die gezählten);
    die Beispiel-Weggefährten gehen mit (sie sind niemandes Freund). Die Zeile heißt deshalb „Alle
    außer Freunden und Gilde entfernen“ / „Remove everyone but friends and guild“; die erste
    Fassung („Ehemalige Freunde und Gildenmitglieder entfernen“) versprach weniger, als der Knopf
    tut (Review 2026-11-24, vom Auftraggeber zum Beheben freigegeben). Soll das Aufräumen doch nur
    ehemalige Freunde treffen, müsste Famulus sich ab jetzt merken, wer Freund war; nachfragen.
    Die Zeile nennt bis zu fünf Namen
    (Alias, sonst Name) und zählt den Rest; der Knopf „Entfernen“ fragt wie „Zurücksetzen“ erst
    („Wirklich entfernen?“, vier Sekunden). Der erste Klick merkt sich, wen die Zeile gezählt hat;
    der zweite entfernt nur diese, und nur, wenn sie beim frischen Nachsehen noch immer fremd sind.
    Wer dazwischen in die Liste kommt, bleibt. Geht auch bei ausgeschaltetem Feature, weil es nur
    gespeicherte Daten betrifft. Eine Chat-Zeile sagt, wie viele es waren. Die Suche findet die
    Zeile über ihren Namen, nicht über die Namen darin. Die Listen werden erst gelesen, wenn die
    Zeile gezeigt wird, nicht schon beim Aufbau der Reiter (das tut die Suche bei jeder Taste für
    alle Reiter). Technik: Zeilenart `action` in
    `UI/Options.lua` (Knopf rechts; `item.button`, `confirm`, `armed`, `usable`, `click`, dazu
    `item.find` für die Suche), `FellowService.Outsiders` und `RemoveOutsiders`.
  - **Abgleich** (`SocialService.Circle`): ein Blick auf Freundesliste, Gildenliste
    (`GetGuildRosterInfo`, 17. Wert GUID) und Battle.net-Freunde; erkannt wird nach GUID, nach Name
    (jede Schreibweise, ohne Realm) und nach BattleTag. Offline sind Battle.net-Freunde nur am
    BattleTag zu erkennen (der Client nennt ihren Charakter nur, solange sie online sind). Deshalb
    merkt sich die Liste den BattleTag (`tag`), sobald jemand in der Gruppe als Battle.net-Freund
    erkannt wird, unabhängig von der Option. Ein alter `tag` bleibt stehen und passt dann einfach
    nicht mehr. Grenze: Wer seit dieser Version nicht mehr in der Gruppe war, hat keinen `tag`; ist so
    jemand nur Battle.net-Freund und gerade offline, hielte das Aufräumen ihn für fremd. Die Namen in
    der Zeile zeigen das vor dem Klick. Das widerspricht nicht der Regel, keine Battle.net-Freunde zu
    sammeln (siehe Aliase): Gemerkt wird der BattleTag nur bei Personen, die ohnehin in der Liste
    stehen.
  - **Eine Liste fehlt noch** (Review 2026-11-24: vorher wartete das Aufräumen nur auf die
    Gildenliste, eine leere Freundesliste oder ein getrenntes Battle.net hätte alle Freunde zu
    Fremden gemacht): `SocialService.Circle` liefert dann `ready = false` und als dritten Wert,
    worauf es wartet. Das Aufräumen zeigt den Grund statt der Namen, der Knopf ist aus:
    - `friends`: Die Freundesliste ist leer und seit dem Login kam noch kein `FRIENDLIST_UPDATE`
      („Deine Freundesliste wird noch geladen.“). Angefragt mit `C_FriendList.ShowFriends`. Eine
      leere Liste gilt erst als echt, wenn der Client sie geschickt hat; hat sie Einträge, gilt sie
      sofort.
    - `guild`: in einer Gilde, aber `GetNumGuildMembers()` liefert 0 („Deine Gildenliste wird noch
      geladen.“). Angefragt mit `C_GuildInfo.GuildRoster`.
    - `battlenet`: `BNConnected()` liefert falsch; ohne Verbindung kennt der Client keine
      Battle.net-Freunde („Battle.net ist gerade nicht verbunden …“). Gewartet wird auf
      `BN_CONNECTED`, anfragen lässt sich nichts.
    Angefragt wird höchstens alle 15 Sekunden; das Ereignis bleibt angemeldet, bis es kommt, dann
    baut sich das Fenster neu (`SOCIAL_CHANGED`). Der zweite Klick sieht noch einmal frisch nach:
    Fehlt dann eine Liste (etwa Battle.net in der Zwischenzeit weg), geht niemand, und die Zeile
    nennt den Grund.
  - **Im Spiel ungeprüft:** alles. Vor allem, ob die Gildenliste in Forever auch Mitglieder führt,
    die offline sind, und mit GUID (sonst hielte das Aufräumen sie für fremd). Das meldet
    `/fam test` (Gruppe `names`, „guild roster“ und „friends list“, nur Zahlen, keine Namen; dazu
    Gruppe `api`). Außerdem, ob `C_BattleNet.GetAccountInfoByGUID` für Battle.net-Freunde in der
    Gruppe antwortet (sonst zählt mit der Option kein reiner Battle.net-Freund), ob
    `C_FriendList.ShowFriends` auch bei leerer Freundesliste ein `FRIENDLIST_UPDATE` auslöst (sonst
    bliebe das Aufräumen bei „wird noch geladen“) und ob `BNConnected` in Forever antwortet.
- **Secret Values (recherchiert 2026-11-23 in der API-Doku des Branches `forever`):** `UnitName`,
  `UnitGUID` und `UnitClass` sind nur geheim, wenn die Einheit nicht spielergesteuert oder nicht in
  der Gruppe ist (`SecretWhenUnitIdentityRestricted`); für Gruppenmitglieder also auch im Kampf
  lesbar. `UnitLevel` ist nie geheim. Geprüft wird trotzdem jeder Wert. Den eigenen Charakter im
  Schlachtzug erkennt der Dienst an der GUID, nicht an `UnitIsUnit` (dessen Vergleich ist auf
  gesperrten Karten geheim). `C_FriendList.AddFriend` trägt `HasRestrictions = true`; ob ein Addon
  es aufrufen darf, ist ungeprüft.
- **Fenster (Neugestaltung 2026-11-24):** Der Auftraggeber fand die zwei Listen „boring“ neben der
  Chronik. Aus vier Entwürfen (Steckbrief, Album, Begegnungsbuch, Verbundenheit; Canvas
  „Weggefährten – Entwürfe“) hat er eine Mischung gewählt; Beschreibung und Plan:
  `docs/superpowers/specs/2026-11-24-fellows-redesign-design.md` und
  `docs/superpowers/plans/2026-11-24-fellows-redesign.md`. Nur gegen den Mock geprüft.
  - Tabs „Übersicht“, „Runden“ (seit 2026-11-24, siehe „Runden“ unten) und „Einstellungen“.
    Symbol: zwei Figuren (`people.tga`).
  - **Übersicht** (`FellowModel` in `UI/Options.lua`, gezeichnet von `UI.FellowOverview` in
    `UI/Fellows.lua`): links „Engste Gefährten“, die drei mit der meisten gemeinsamen Zeit als
    Kacheln (Rang I–III, Wappen mit Ring, Name in der Buchschrift, Stufe und Klasse, Abzeichen der
    Stufe, Zahlen, Fuß „In deiner Gruppe“ oder „Zuletzt … in …“; unter der Maus leuchten sie wie
    eine klickbare Karte im Buch, seit 2026-11-24 auf Wunsch des Auftraggebers). Darunter „Alle weiteren · N“
    mit Auswahl „Zuletzt gesehen“ / „Meiste gemeinsame Zeit“ (sortiert nur die Liste) und die
    Liste mit Spaltenköpfen, höchstens 60 Zeilen (`FELLOW_ROWS`) plus „N weitere“. Bis drei
    Personen gibt es keine Liste; ohne Personen den Hinweis, wie man anfängt.
  - Ein Klick auf Kachel oder Zeile öffnet die Geschichte der Person (Entscheidung des
    Auftraggebers, 2026-11-24: mit Seitenleiste wäre ein Steckbrief neben der Übersicht zu eng).
    Die Sortierung gilt für die Sitzung.
  - **Eure Geschichte** (`FellowStory`): links fest der **Steckbrief** (320 breit): Wappen, Name,
    Stufe und Klasse, Online-Zeile („In deiner Gruppe“ oder „Zuletzt …“), dann die Leiste der
    Verbundenheit, darunter die Zahlenleiste und „Kennengelernt …“, mit „auf Stufe N“ in einer eigenen
    Zeile darunter, damit der Satz nicht umbricht (die frühere zweite Zeile
    „Zuletzt …“ darunter ist seit 2026-11-24 entfallen, sie wiederholte die Online-Zeile; Wunsch
    des Auftraggebers nach einem Screenshot), Knöpfe „Alias festlegen“ (`ns:EditAlias`) und „Vergessen“
    (das Kreuz an den Zeilen ist entfallen; eine Chat-Zeile sagt es). Rechts daneben scrollt ein
    Buch (`UI.Book`, 560 breit; Wunsch des Auftraggebers nach dem ersten Blick ins Spiel: Person
    links, Buch rechts statt eines breiten Kopfes über einem zu breiten Buch) mit einem Kapitel je
    Spielabend wie in der Chronik (seit 2026-11-25, vorher je Tag mit dem Gebiet als Titel), das
    neueste zuerst: Titel nach der Tageszeit, links von–bis oder das Datum, rechts „N Std.
    zusammen“. Gebaut wird es weiter aus dem Tagesprotokoll: Je Tag eine Karte „Unterwegs in
    <Gebiet>“ (das letzte Gebiet des Tages; ohne Gebiet „Gemeinsam unterwegs“); ein Abend über
    Mitternacht, den das Protokoll auf zwei Tage teilt, ist eine Karte. Grenze: Das Protokoll kennt
    je Tag nur den ersten und letzten Moment, zwei Abende an einem Tag bleiben eine Karte; die
    Runden könnten sie trennen. Ein Boss ohne gezählte Zeit steht um 12 Uhr seines Tages. Unter
    der Karte (von bis; Bosse ohne Namen, etwa aus einem Schlachtzug, als Zahl
    dahinter; die Dauer stand bis 2026-11-24 auch dort, brach um und wiederholte den
    Kapitelkopf, deshalb auf Wunsch des Auftraggebers entfernt), je Boss mit Namen eine Karte („Archaedas bezwungen“, „in Uldaman“), „Ihr seid
    jetzt <Stufe>“ am Tag eines Aufstiegs und „Kennengelernt“ (auf Stufe N). Liegt das Kennenlernen
    vor dem Protokoll, steht es in einem eigenen letzten Kapitel. Seit 2026-11-24 steht dort
    nur Gemeinsames aus dem eigenen Tagesprotokoll, nichts aus der Chronik (siehe „Chronik und
    Weggefährten“). Hat die Chronik Einträge der Person (`ChronicleService.Who`, Name in jeder
    Schreibweise) und ist sie eingeschaltet, trägt die Karte neben „Alias festlegen“ den Knopf
    „In der Chronik“: Er öffnet Chronik › Freunde, gefiltert auf die Person. Statt der Tabs
    steht „Alle Weggefährten“ oben; ein anderer Reiter, eine andere Seite oder Schließen schließt
    die Geschichte.
  - **Aufbau des Steckbriefs (Entscheidung des Auftraggebers, 2026-11-24, an der Leinwand
    „Weggefährten – Personenkarte“, claude.ai-Artifact `EyiMx3kvy6qkrjnkYKV8eX`: Variante B
    „Zahlenleiste“, mit der Leiste der Verbundenheit über den Zahlen statt darunter):** Anlass:
    Die Karte wirkte unordentlich, die Zeit war zu groß (17 px halbfett, breiter als ihre
    Spalte). Verworfen: A (ruhige Liste), C (großer Ring, Zeit als Satz, Weg aus zwei Punkten),
    D (linksbündig mit Abschnitten). Die Leiste der Verbundenheit (`UI.TierBar`, ersetzt die
    Leiter mit vier Punkten) nennt links die Stufe (Akzent ab Vertraut) und rechts die nächste,
    darunter drei Abschnitte für die drei Schritte, gefüllt so weit, wie man gekommen ist, und
    mittig „Noch … gemeinsam“. Die Zahlenleiste ist ein vertiefter Kasten: die Zeit auf der
    halben Breite, Mal und Bosse auf je einem Viertel, getrennt durch Haarlinien; alle Zahlen
    20 px halbfett, bei der Zeit „Std.“ und „Min.“ klein daneben (unter einer Stunde nur
    Minuten, zur vollen Stunde nur Stunden). Im Spiel gesehen (Screenshot vom Auftraggeber,
    2026-11-24, Mira aus den Beispieldaten): Leiste, Abschnitte und Zahlenleiste wie geplant,
    „Std.“ und „Min.“ sitzen auf der Grundlinie. Danach kam die Stufe beim Kennenlernen in eine
    eigene Zeile, weil „…, auf Stufe 29“ den Satz eng umbrach. Die Karte bleibt auf voller Höhe
    (Entscheidung des Auftraggebers, 2026-11-24, statt sie auf ihren Inhalt zu kürzen); dafür
    stehen zwischen Person, Verbundenheit, Zahlen und Kennenlernen je 32 px (`SECTION_GAP`,
    vorher 18 bis 22), sodass auch ein zweizeiliges „Kennengelernt …“ gut über den Knöpfen endet.
    Beides ist im Spiel noch nicht gesehen.
  - Die Suche findet weiter jede Person als einfache Personenzeile (`FellowItem`, `tab.search`).
    Unter einem Alias steht der Name in der zweiten Zeile. Die Klasse kommt aus
    `LOCALIZED_CLASS_NAMES_MALE`, also in der Sprache des Clients.
- **Runden (Entscheidung des Auftraggebers, 2026-11-24, an der Leinwand „Weggefährten – Verlauf“,
  claude.ai-Artifact `L3v3BWqAv717ro24NVyQGF`: Variante B „Runden mit eigenem Protokoll“):**
  **Name (Wahl des Auftraggebers, 2026-11-25):** Der Reiter heißt „Runden“ / „Groups“; der erste
  Name „Verlauf“ / „Timeline“ gefiel ihm nicht („etwas unschön“). Ebenfalls vorgeschlagen:
  „Unterwegs“, „Lagerfeuer“, „Gemeinsam“. Im Code heißt der Reiter weiter `timeline`
  (`ui_tab_timeline`, `TimelineBook`, `TimelineRail`). Frage des Auftraggebers war, ob sich eine Ansicht lohnt, die die Geschichten aller Weggefährten
  zeigt. Empfehlung des Assistenten: nicht alle Einzelgeschichten untereinander (das wäre ein
  zweites Buch der Chronik), sondern wann ihr zusammen gespielt habt und mit wem. Verworfen: A,
  ein Tagebuch aus dem vorhandenen Tagesprotokoll (je Person und Tag eine Karte; wer zusammen in
  einer Gruppe war, ließe sich daraus nur raten, und es gibt keine Gesamtzeit in Gruppen). Nur
  gegen den Mock geprüft, im Spiel noch nicht gesehen. Umsetzung im Einzelnen und die Abweichungen
  von der Leinwand sind Entscheidungen des Assistenten:
  - **Rundenprotokoll** (`FamulusDB.fellowRuns`, accountweit, außerhalb der Profile, nichts wird
    verschickt): je Runde `f`, `l` (von, bis), `z` (die Gebiete in zeitlicher Reihenfolge,
    höchstens sechs), `b` (Bosse) und `who = { [guid] = { f, l } }` (wer von wann bis wann dabei
    war). Im Schlachtzug nur `raid = true` und `n` (die meisten Personen auf einmal), keine Namen,
    dieselbe Regel wie bei den Bossen. Höchstens 30 Tage (wie das Tagesprotokoll) und 400 Runden.
    `FellowService.Sync` schreibt mit; `Runs()` liefert die Runden und die laufende.
  - **Eine Runde** dauert, solange jemand in der Gruppe gezählt wird. Wer später kommt oder früher
    geht, ändert nichts an der Runde, nur an seinem `f`/`l`. Nach einer Pause von weniger als 30
    Minuten (`MEET_GAP`) mit mindestens einem derselben Leute geht die alte Runde weiter
    (`/reload`, Verbindungsabbruch, kurze Pause), sonst beginnt eine neue. Deshalb ist der Abend
    der Leinwand (Uldaman, danach Tanaris mit Mimi) eine Runde „Unterwegs in Uldaman und
    Tanaris“, weil Mimi die ganze Zeit dabei blieb; Borin und Lysa tragen „bis 22:40“.
  - **Gebiete:** `rememberFellows` hört dafür zusätzlich auf `ZONE_CHANGED_NEW_AREA`
    (`FellowService.Move`), nur solange das Feature an ist. Kehrt man zurück, steht das Gebiet im
    Protokoll noch einmal, im Titel der Karte nur einmal.
  - **Buch** (`TimelineBook` in `UI/Options.lua`, Reiter `timeline`): ein Kapitel je Spielabend
    wie in der Chronik (`SESSION_GAP`, `SessionTitle`); Kapitelkopf mit von–bis und „N Std.
    zusammen“. Je Runde eine Karte ohne Bild (`story.noPicture`): Titel „Unterwegs in …“ (im
    Schlachtzug „Schlachtzug in …“), darunter von–bis, Dauer und Bosse als Zahl (im Schlachtzug
    auch die Zahl der Personen), darunter je Person eine Plakette mit Klassensymbol und Namen
    (`story.people`; Alias, sonst Vorname; „bis …“ oder „ab …“, wer mehr als fünf Minuten später
    kam oder früher ging). Kehrt eine Gruppe von mindestens zwei derselben Leute wieder, sagt es
    der Fuß in Akzentfarbe (`story.foot`): „Wieder mit Mira und Borin · 6-mal in 30 Tagen“.
    Abweichung von der Leinwand („Zum 3. Mal mit …“): Gezählt wird nur, was das Protokoll noch
    kennt, also 30 Tage, und das sagt der Satz; Englisch braucht so keine Ordnungszahlen. Gewählt
    wird die Teilgruppe, die am häufigsten zusammen war, bei Gleichstand die größere; die Namen
    stehen nach gemeinsamer Zeit. Dazwischen „Lysa kennengelernt“ (nur wer in einer gezeigten
    Runde kennengelernt wurde) und „Du und Borin seid jetzt vertraut“ (Zeitpunkt aus den Runden,
    ab der Zeit vor ihnen gerechnet wie `Milestones`), beide mit dem Wappen statt eines Bildes
    (`story.crest`); ein Klick öffnet „Eure Geschichte“. Ab Vertraut ist die neue Stufe ein
    Meilenstein (größere Karte), darunter nicht, wie beim Abzeichen. Runden unter einer Minute
    ohne Boss und Runden, von deren Leuten niemand mehr in der Liste steht, erscheinen nicht.
    Höchstens 50 Ereignisse, darunter „Ältere Runden bleiben gespeichert …“.
  - **Randspalte** (`TimelineRail`): „Diese Woche“ (Zeit in Gruppen allein in ihrer Zeile, dafür
    `wide` in `UI/Rail.lua`; Runden, Weggefährten, kennengelernt, neue Verbundenheit), „Häufigste
    Runde“ (die Teilgruppe, die in den letzten sieben Tagen am öftesten zusammen war, ab zweimal;
    Wappen nebeneinander, nicht überlappend wie auf der Leinwand, neue Kartenart `group`) und „Am
    meisten zusammen“ (bis fünf Personen mit ihrer Zeit dieser Woche, ohne online/offline; ein
    Klick öffnet „Eure Geschichte“).
  - Nichts aus der Chronik, siehe „Chronik und Weggefährten“. „Vergessen“ und „Aufräumen“ nehmen
    die Person auch aus den Runden; eine Runde ohne Leute fällt dann weg. Die Suche findet hier
    nichts, die Personen findet sie in der Übersicht. Ohne Runde zeigt der Reiter, wie man anfängt.
  - Wer vor diesem Stand schon Weggefährten hatte, sieht unter „Runden“ erst die Runden ab dem
    Update; Tagesprotokoll und „Eure Geschichte“ bleiben, wie sie sind. Die Website zeigt die
    Runden noch nicht.
- **Verbundenheit (Entscheidung des Auftraggebers am Mockup, 2026-11-24):** Stufen nach gemeinsamer
  Zeit, `FellowService.TIERS`: Begegnung unter 1 Std., Bekannt ab 1, Vertraut ab 10, Unzertrennlich
  ab 40 (enUS: Encounter, Acquainted, Trusted, Inseparable; die englischen Namen hat der Assistent
  gewählt). `FellowService.Tier(sekunden)` liefert Stufe, Fortschritt und Rest. Angezeigt als Ring
  ums Wappen (`UI.Crest`), Abzeichen (`UI.TierBadge`, Akzent ab Vertraut) und Leiste
  (`UI.TierBar`, bis 2026-11-24 die Leiter `UI.TierLadder`). Der Ring ist ein angehaltener `Cooldown`-Swipe mit `ring.tga` (ohne
  `OnUpdate`; die höchste Stufe steht knapp vor dem Ende, weil ein abgelaufener Cooldown nichts
  zeichnet; `noCooldownCount` hält OmniCC und Ähnliche fern); fehlt `Cooldown:Pause`, ein voller
  Ring ohne Fortschritt. Das Klassensymbol kommt
  aus `UI-Classes-Circles` mit `CLASS_ICON_TCOORDS`, sonst der Anfangsbuchstabe. Beides prüft
  `/fam test` (Gruppe `media`).
- **Tagesprotokoll (seit 2026-11-24):** je Person `days = { [JJJJMMTT] = { s, z, b, f, l, k } }`
  (Sekunden, Gebiet zuletzt an dem Tag, Bosse, erster und letzter Moment, die Bosse mit Namen) und
  `firstLevel` (die Stufe des Spielers beim Kennenlernen). `k = { { t, n, z } }` (Zeit, Boss,
  Gebiet) gibt es nur in einer Gruppe, höchstens zwölf je Tag (`MAX_KILLS`); im Schlachtzug zählt
  nur `b`, damit nicht 39 Personen jeden Boss des Abends speichern (dieselbe Regel wie `with` und
  `others` in der Chronik). Höchstens 30 Tage, der älteste fällt zuerst. Eine
  Strecke über Mitternacht zählt für den Tag, an dem sie endet. Aufstiegstage werden beim Aufbau
  berechnet (`FellowService.Milestones`), ab der Zeit vor dem Protokoll (`seconds − Σ s`), damit
  frühere Zeit keine Meilensteine erfindet. Beim Laden fallen kaputte Tage heraus.
- **In der Chronik:** Fällt ein Boss in einer Gruppe, trägt der Eintrag `with` (die Namen, in einer
  Gruppe bis vier) oder `others` (nur die Zahl, im Schlachtzug, damit 39 Namen je Boss die Daten
  nicht aufblähen). Die Zeile darunter lautet „in Uldaman  ·  mit Mira und Tom“ (Alias, sonst
  Vorname) bzw. „mit 12 anderen“. Das gilt, sobald „Meine Reise festhalten“ läuft, unabhängig vom
  Schalter der Weggefährten. Beide Felder fehlen in `FIELDS` von `Sharing.lua` und werden also nicht
  geteilt. Der Beispiel-Boss in `/fam chronicle demo` hat zwei Gefährten. Die Weggefährten lesen
  `with` seit 2026-11-24 nicht mehr; sie merken sich ihre Bosse selbst (`k` im Tagesprotokoll).
- **Beispieldaten (2026-11-24, Wunsch des Auftraggebers):** `/fam fellows demo` trägt sechs
  erfundene Weggefährten ein (Klassen, Stufen, Gebiete; Mira und Borin wie in der Chronik),
  `/fam fellows demo clear` entfernt nur sie (`FellowService.Demo`, `ClearDemo`). Sie tragen
  `demo = true` und GUIDs `Player-0-FAMDEMO..`. Sprache wie bei den Beispielen der Chronik (seit
  2026-11-24 die von Famulus); die drei anderen heißen auf Englisch Kael Thornwood, Tomas
  Greywind und Ena Silverbrook.
  - **Seit den Runden (2026-11-24)** entstehen sie aus elf erfundenen Abenden über drei Wochen
    (`DEMO_RUNS`, Runden mit `demo = true`, die nie mit echten zusammenwachsen); Tage, Zeiten,
    Bosse, Kennenlernen und Zuletzt-Zeile werden daraus berechnet, so wie die Zählung sie
    geschrieben hätte. Vorher waren die Tage ausgedacht und passten zu keiner Runde. Der jüngste
    Abend ist der heutige, sobald 23:20 Uhr vorbei ist, sonst der gestrige. Zeiten jetzt: Mira 32
    Std. 20 Min., Borin 20 Std. 50 Min., Lysa 3 Std. 35 Min., Ena 3 Std. 30 Min., Kael 1 Std. 15
    Min., Tomas 25 Min. (vorher 25 Minuten bis 31 Stunden). Mira und Borin erzählen weiter einen
    Aufstieg (Vertraut), Bosse mit Namen gibt es in Uldaman und den Todesminen, Mira und Borin
    sind die Stammgruppe (sechsmal in drei Wochen).
- **Im Spiel ungeprüft:** alles. Besonders: ob `UnitName` für `party1`… Vor- und Nachname liefert
  wie für `player`, ob `GROUP_ROSTER_UPDATE` nach dem Login von selbst kommt (sonst fängt
  `PLAYER_ENTERING_WORLD` es auf), ob `IsInInstance` in Forever `pvp` meldet und ob `BOSS_KILL` in
  Forever-Dungeons feuert. `/fam test` prüft die benutzten Funktionen (Gruppe `api`).
