# Teilen zwischen Spielern (`sharing`)

Teil des Projektwissens; Vorgaben, Regeln und die Übersicht aller Dateien stehen in
[AGENTS.md](../AGENTS.md). Verweise der Form „siehe X“ meinen eine Überschrift oder einen fett
gesetzten Eintrag; in welcher Datei er steht, sagt die Übersicht dort.

**`sharing` (Entscheidung des Auftraggebers, 2026-11-19):** Anvisieren und Nähe taugen nicht; die
Chronik soll unabhängig vom Ort der Freunde sein. Deshalb spricht Famulus mit Famulus
(`Modules/Chronicle/Sharing.lua`): Addon-Nachrichten mit dem Präfix `Famulus`, geflüstert an
Freunde der Freundesliste und Gildenmitglieder, die online sind. Angenommen wird nur von Leuten
auf der Freundesliste oder in der Gilde, nur per WHISPER (Ausnahme: der Gruß `1~P` im
Gildenkanal), nur bekannte Felder; `|` und Steuerzeichen werden entfernt.

- **Gilde (2026-11-19):** Wer online kommt, grüßt die Gilde einmal im Gildenkanal (`1~P`), sobald
  die Gildenliste da ist; wer Famulus hat, antwortet per Flüstern mit einem Gruß. Freunde werden
  weiter einzeln gegrüßt. Dass Addon-Nachrichten im Gildenkanal in Forever ankommen, zeigt Guildy
  (sendet dort). Namen: Gildenliste und Absender können `Vorname Nachname-Realm` liefern
  (so liest Guildy sie); der Schlüssel schneidet das ab.
- **Weiterreichen (Wunsch des Auftraggebers, 2026-11-19):** Neuigkeiten von jemandem, der offline
  ist, kommen über einen verbundenen Gefährten, der sie hat. Auf einen Gruß
  folgen bis zu 20 Angebote `1~O~<wer>~<zeit>` (seit 2026-11-25 nur über Leute, die gerade nicht
  online sind); wer daraus Neues erwartet, fragt mit `1~W~<wer>~<seit>` und bekommt
  bis zu 20 Einträge als `1~R~<wer>~<zeit>~<art>~…`. Regel: Erfragt und angenommen wird nur über
  Gildenmitglieder und über Leute, deren Addon in den letzten 30 Tagen direkt geantwortet hat
  (`FamulusDB.chronicle.links`; eine direkte Antwort kommt nur von jemandem, der den Spieler auf
  der Freundesliste oder in der Gilde hat, das belegt beidseitige Freundschaft). So kommt nichts
  über Fremde an. Je Person wird pro Sitzung nur ein Gefährte gefragt, und `R` wird nur von ihm
  angenommen. Weitergereichte Einträge tragen `via` (angezeigt als „über <Name>“) und verschieben
  den Lesezeiger für den direkten Gruß nicht (`NewestFrom(who)` ohne `withRelayed`), sonst
  entstünde eine bleibende Lücke, wenn der Weiterreichende selbst etwas verpasst hat. Grenzen:
  Ein Gefährte könnte Einträge über andere fälschen, und ein verändertes Addon könnte über jeden
  fragen; der Antwortende prüft das nicht. Für Stufen, Tode und Bosse vertretbar. Streicht jemand
  den Spieler von der Freundesliste, gilt er bis zu 30 Tage weiter als verbunden.
- Nachrichten, Felder mit `~` getrennt: `1~H~<zeit>` (Gruß: „deine Neuigkeiten habe ich bis
  <zeit>“), `1~E~<zeit>~<art>~k=v;k=v` (ein Eintrag), `1~S~<stufe>~id=n;id=n~<klasse>`
  (Statistiken und seit 2026-11-24 die Klasse, etwa `MAGE`; ältere Versionen schicken sie nicht
  und übergehen das Feld beim Empfang).
- Ein Gruß geht an jeden Freund, der online kommt. Wer antwortet, gilt für die Sitzung als
  verbunden und bekommt die eigenen Meilensteine live. Auf einen Gruß folgen alle verpassten
  eigenen Einträge (in Runden zu 20, siehe „Warteschlange“) und die Statistiken.
- **Statistiken nach eigenen Ereignissen (seit 2026-11-25):** Fünf Sekunden nach einem eigenen
  Eintrag, der live rausgeht, gehen auch die Statistiken an alle Verbundenen (`STATS_DELAY`,
  `SendStatisticsSoon` in `Sharing.lua`), einmal für mehrere Ereignisse in diesen fünf
  Sekunden. Anlass (im Spiel bemerkt, 2026-11-24): Ein Freund sah in der Bilanz weiter
  „6 Tode“, obwohl die neuen Tode live bei ihm ankamen. Vorher gingen die Statistiken nur als
  Antwort auf einen Gruß raus, und ein `/reload` des Absenders löst beim Freund keinen Gruß aus
  (er ist dort weiter verbunden); die Bilanz stand also auf dem Stand des letzten Logins
  einer der beiden. Die Verzögerung ist eine Entscheidung des Assistenten: Der Client zählt
  einen Tod vermutlich erst einen Moment nach `PLAYER_DEAD` in die Statistik. Besiegte
  Kreaturen und Quests erzeugen keinen Eintrag; ihre Zahlen werden nur mit einem anderen
  Ereignis oder einem Gruß frisch. Die Gegenseite braucht keine neue Version. Nur gegen den
  Mock geprüft.
- Geteilte Statistiken (IDs des Spiels): 60 Tode, 107 besiegte Kreaturen, 98 Quests, 932 betretene
  Dungeons. Sie stehen als „Bilanz“ je Person in der Randspalte des Reiters „Freunde“
  (`FamulusDB.chronicle.profiles`; im Code heißen sie weiter `profile`). Die Liste steht seit
  2026-11-25 in `ChronicleService.STATISTICS` (vorher am Feature, das Fenster griff dafür in
  `ns.features.sharing`).
- **Warteschlange (seit 2026-11-25, Freigabe des Auftraggebers nach der Analyse unten; die
  Umsetzung im Einzelnen hat der Assistent entschieden):** Alles geht über eine Warteschlange
  mit Ticker (alle 0,5 Sekunden, nur solange etwas wartet). Während der Chat-Sperre (Bosskampf,
  gesperrte Karte) bleibt sie stehen. Das Leitungsformat ist unverändert.
  - **Takt wie der Client:** Laut warcraft.wiki.gg (Seite `C_ChatInfo.SendAddonMessage`, Stand
    Forever 1.60.1) darf jeder Präfix 10 Nachrichten auf einmal senden und bekommt eine je
    Sekunde zurück, **außer Flüstern außerhalb von Instanzen**; dazu hat der Server eine eigene
    Grenze und kann bei zu viel Verkehr die Verbindung trennen, und er kann die Werte jederzeit
    ändern. Seit 2026-11-25 (Wunsch des Auftraggebers nach dem Abgleich mit dem Wiki) deshalb
    zwei Budgets in `Flush`: die 10 plus 1 (`ALLOWANCE`, `REFILL`) nur für den Gildenkanal, und
    für alles ein Budget nach Bytes mit den Werten von ChatThrottleLib v32 (`BANDWIDTH` 800 je
    Sekunde, `BURST` 4000, `OVERHEAD` 40 je Nachricht). Nach einem Ladebildschirm
    (`PLAYER_ENTERING_WORLD`) startet das Budget leer und füllt sich fünf Sekunden lang nur mit
    einem Zehntel (`SETTLE`, wie ChatThrottleLib). Lehnt der Client doch ein Flüstern ab, zählen
    Flüstern ab da auch gegen die 10 plus 1 (`whispersCounted`; `devLog` „whisper throttled“):
    So zeigt sich im Spiel, ob Forever Flüstern drosselt. ChatThrottleLib selbst ist bewusst
    nicht eingebunden (Entscheidung des Auftraggebers, 2026-11-25): Sie verwirft Nachrichten bei
    `AddOnMessageLockdown`, kennt `TargetOffline` nicht, kann eingereihte Nachrichten nicht
    ersetzen (Gruß mit spätem Stand, Nachholen in Runden), setzt dauerhafte Hooks und ist eine
    Bibliothek mit globalem Namen. Ihr Vorteil, ein Budget gemeinsam mit anderen Addons, fehlt
    Famulus also. Meldet `SendAddonMessage` trotzdem `AddonMessageThrottle`,
    `ChannelThrottle` oder `AddOnMessageLockdown`, bleibt die Nachricht vorn in der Reihe und
    geht später noch einmal (wie ChatThrottleLib ab v29). Ein schlichtes `false` (Clients vor
    10.2.7; Forever liefert laut UI-Quellcode das Enum) gilt ebenso als abgelehnt, aber nur fünfmal (`MAX_REFUSED`), weil es auch eine
    bleibende Ablehnung sein kann. Bei `TargetOffline` geht an die
    Person nichts mehr (`gone`), bis sie selbst wieder etwas schickt oder die Listen sie als
    offline und wieder online zeigen. Die Werte kommen aus `Enum.SendAddonMessageResult`, sonst
    aus festen Zahlen; `/fam test` prüft, ob es die drei Namen gibt (Gruppe `api`). Im
    Entwicklermodus steht je Sitzung und Art eine Zeile im `devLog` (`SHARE`, „throttled“,
    „whisper throttled“, „lockdown“, „offline“), ohne Namen. So lässt sich im Spiel sehen, ob
    Forever drosselt. Die Zahlen des Enums sind im Branch `forever` von `Gethe/wow-ui-source`
    bestätigt (`ChatConstantsDocumentation.lua`, 0 bis 12, 2026-11-25). Laut Wiki schicken
    Testaccounts seit 1.60.1 keine Addon-Nachrichten; mit welchem Rückgabewert, ist offen.
  - **Zwei Spuren:** vorn die eigenen Einträge (live und nachgeholt, in zeitlicher Folge), Grüße,
    Fragen `W` und die Bilanz nach einem Live-Eintrag; hinten die Bilanz in einer Antwort,
    Angebote und weitergereichte Einträge. Eigene Einträge stehen bewusst vorn und in Reihe:
    Der Stand beim Gefährten („deine Neuigkeiten habe ich bis …“) darf nie über einen Eintrag
    springen, den er nicht hat, sonst bekäme er ihn nie. Ein Live-Eintrag wartet deshalb hinter
    dem Nachholen. Eigene Einträge werden nie abgewiesen. Für den Rest gelten 100 (vorn) und
    200 (hinten) Plätze; Grüße werden nie abgewiesen, sonst bliebe ein erster Kontakt ohne
    Gruß zurück.
  - **Nachholen in Runden (seit 2026-11-25, nach dem Review von PR #13):** Ein Gruß bekommt die
    ältesten 20 eigenen Einträge, die fehlen, und den Rest ihrer letzten Sekunde
    (`ChronicleService.OwnSince`; vorher die neuesten 20, darüber hinaus Verpasstes war für
    immer weg). Ist der letzte einer vollen Runde raus, folgt die nächste (`CatchUp`, Marke
    `more`). Eine Runde nimmt die eigenen Einträge für diesen Gefährten aus der Reihe, die noch
    warten und neuer sind als sein Stand, und reiht sie in zeitlicher Folge neu ein (`skip`).
    So geht ein Live-Eintrag, der vor dem Gruß schon in der Reihe stand, nicht vor den älteren
    raus. Bekannte Grenze (schon vorher so): Der Stand ist eine Sekunde; hat der Gefährte von
    zwei Einträgen derselben Sekunde nur einen, fehlt ihm der andere.
  - **Doppelter Gruß:** Beide Seiten grüßen meist zweimal (beim Online-Kommen und beim ersten
    Kontakt). Der Stand im Gruß wird erst beim Abschicken gelesen, je Person wartet höchstens
    ein Gruß, und ein zweiter Gruß ersetzt die noch wartenden Einträge, statt sie zu verdoppeln.
    Der zweite Gruß kostet so meist nur sich selbst und eine Bilanz.
  - **Angebote** gehen nur über Leute, die gerade nicht online sind (die sagen es selbst), und
    nicht noch einmal, solange frühere an denselben Gefährten warten oder sie weniger als 60
    Sekunden her sind (`OFFER_GAP`; seit Flüstern schneller geht, ist die Antwort auf den ersten
    Gruß meist schon raus, wenn beim ersten Kontakt der zweite kommt). Ein Gruß nach einem
    `/reload` des Gefährten bekommt sie also wieder (vorher einmal je Sitzung; ein Freund grüßt
    nicht per `P` und bekam nach seinem `/reload` keine mehr). Eine Frage `W` gilt erst als
    gestellt, wenn sie in der Reihe steht; geht der Gefragte offline oder meldet der Client
    `TargetOffline`, ist die Person wieder frei und wird beim nächsten Angebot erfragt (`Unask`).
  - **Gruß `P` nach `/reload`:** wird immer beantwortet, auch wenn der Absender noch als verbunden
    gilt (`P` geht einmal je Sitzung raus, der Absender kennt danach niemanden). Vorher blieb ein
    Gildenmitglied nach `/reload` unverbunden, und seine Meilensteine gingen an niemanden.
- **Kein eigener Service für den Austausch** (Entscheidung des Auftraggebers, 2026-11-25),
  solange nur `sharing` Nachrichten schickt. Kommt ein zweites Feature dazu: Transport
  (Präfix, Warteschlange, Annahmeregeln) und „wer ist da“ (online, verbunden, Gruß an die Gilde)
  in einen Service unter `Core/`, das Chronik-Protokoll bleibt in `Sharing.lua`. Das
  Leitungsformat bleibt dabei gleich (Alphas sind draußen); ein neues Feature bekommt neue
  Buchstaben statt einer neuen Version, alte Versionen übergehen unbekannte Arten.
- **Viele Nutzer (Analyse 2026-11-25, im Mock simuliert; vor dem Budget nach Bytes, die Zahlen
  für „Nachher“ gehen davon aus, dass auch Flüstern 10 plus 1 zählen):** Ein Client loggt sich ein, N
  Gildenmitglieder mit Famulus sind online, zehn weitere offline, die anderen haben seine
  Neuigkeiten bis gestern; 30 Sekunden nach dem Login steigt er auf. Die Drosselung ist wie im
  Wiki nachgebaut. Die Simulation ist ein Skript außerhalb des Repos; die Gefährten darin
  antworten ohne eigene Drosselung, die Zahlen sind also eher zu günstig.
  - **Vorher:** Famulus schickte zwei Nachrichten je Sekunde und wertete die Rückgabe nicht aus,
    was der Client ablehnte, war weg. Verloren beim Login: bei N = 1 13 von 46 Nachrichten, bei
    3 55 von 128, ab 10 lief die Reihe (200 Plätze) zusätzlich über. Der Aufstieg erreichte bei
    3 zwei, bei 5 zwei, bei 10 acht, bei 20 fünf Gefährten, der letzte nach bis zu 169 Sekunden.
    Angebote machten bei N = 10 zwei Drittel des Verkehrs aus.
  - **Nachher:** Nichts geht durch die Drosselung verloren. Der Aufstieg erreicht alle: bei 5
    nach 7, bei 10 nach 42, bei 20 nach 112, bei 40 nach 252 Sekunden. Ab 20 weist die hintere
    Spur Angebote und doppelte Bilanzen ab (bei 40: 220 und 60).
  - **Grenze des Flüsterns:** Jede Nachricht geht einzeln an jeden, nach dem Wiki mit etwa 7 je
    Sekunde (Budget nach Bytes), falls Forever Flüstern doch drosselt, mit einer. Für
    große Gilden der Weg über den Gildenkanal: Issue #12 (Live-Einträge, Bilanz und Angebote
    einmal an die Gilde; offen sind ältere Versionen und die Reihenfolge). Dort steht auch, dass
    `MAX_ENTRIES` (2000) für eigene und fremde Einträge zusammen gilt.
- Frische Neuigkeiten erscheinen am Bildschirm über die Live-Einblendung (`liveFeed`, siehe
  unten); die frühere Option `toast` und `UI.Toast` sind entfallen.
- **Ungeprüft im Spiel:** ob geflüsterte Addon-Nachrichten so ankommen, wie Name und Absender
  geschrieben werden (`Vorname Nachname` gegen `Vorname-Nachname`), ob ein Flüstern an jemanden,
  der gerade offline ging, eine Fehlermeldung im Chat hinterlässt, und ob die Statistik-IDs
  stimmen (aus Guildys Quellcode entnommen). Das lässt sich nur mit zwei Accounts prüfen.
  Ebenso ungeprüft: Gruß und Antwort in der Gilde und das Weiterreichen (dafür braucht es drei
  Charaktere, einer davon offline), und welche Namensform die Gildenliste in Forever liefert.
