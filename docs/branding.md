# Name, Logo und Untertitel

Teil des Projektwissens; Vorgaben, Regeln und die Übersicht aller Dateien stehen in
[AGENTS.md](../AGENTS.md). Verweise der Form „siehe X“ meinen eine Überschrift oder einen fett
gesetzten Eintrag; in welcher Datei er steht, sagt die Übersicht dort.

- **Name (2026-11-19):** Das Addon heißt **Famulus** (lateinisch: Gehilfe eines Gelehrten oder
  Magiers); „Schnitzel“ war der Arbeitstitel. Verworfen, weil auf CurseForge schon für WoW Forever
  vergeben: „Wisp“ (ForeverWisp, dazu Wisp-Figuren in Wishwell und Sparky), „Ignis“
  (Rollenspiel-Addon), „Lantern“ (Lantern – QoL Core). Für „Famulus“ fand eine Websuche kein
  gleichnamiges Addon; vor der Veröffentlichung direkt auf CurseForge und Wago prüfen. Umbenannt
  sind Ordner, `.toc`, gespeicherte Variablen (`FamulusDB`, `FamulusCharDB`), Frame-Namen und die
  Befehle (`/fam`, `/famulus`) und das GitHub-Repo (`89pleasure/famulus`). Der Untertitel im Fenster war zuerst „Dein Gehilfe in Azeroth“ / „Your assistant in Azeroth“
  (`ui_tagline`), seit 2026-11-24 „Gemeinsam durch Azeroth“ / „Together through Azeroth“ (siehe
  „Logo“). Auf dem Mac muss der
  Symlink im Addon-Ordner neu angelegt werden (`Famulus` statt `Schnitzel`), und die Einstellungen
  aus `SavedVariables/Schnitzel.lua` gehen nicht von selbst über.
- **Logo (2026-11-19):** eine lodernde Flamme in drei Schichten mit Funken und weichem Schein, frei ohne Kachel
  ("Lodernd"), vom Auftraggeber am Mockup gewählt. Verworfen: abstrakte Zeichen (Monogramm, Kerzen-F,
  Laterne, Feder; "zu abstrakt und minimalistisch"), ein Maskottchen mit Gesicht und Fassungen mit
  Spielwelt-Motiv (Quest-Ausrufezeichen, Fackel, Runenkreis, Zahnrad, Schild, Ruhestein). Blizzards
  eigene Embleme (Allianz, Horde, WoW-Logo) bleiben außen vor. Den Kasten um die Flamme wollte er nach dem
  ersten Blick ins Spiel nicht. `logo.tga` (Flamme allein: Fenster,
  Addon-Liste) und `logo-round.tga` (auf dunkler Scheibe: Minikarte), 128 px, gezeichnet in
  `tools/make_media.py`. Das Logo hat feste Farben und folgt der Farbwelt nicht. Auf dem
  Windows-Rechner ist kein eigenes Python installiert; `make_media.py` braucht nur die
  Standardbibliothek und lief dort mit einem vorhandenen Python 3.12. Im Spiel noch nicht gesehen.
  **Bestätigt nach der Wende zum gemeinsamen Spielen (2026-11-24):** Der Auftraggeber war unsicher,
  ob die Flamme noch passt. Am Mockup „Famulus Logo – Varianten“ sah er zwei Weiterentwicklungen
  (drei Flammenzungen aus einem gemeinsamen Feuer; die Flamme auf gekreuzten Scheiten als
  Lagerfeuer) und behielt die Flamme. Gedeutet wird sie jetzt als Lagerfeuer, an dem sich die
  Gefährten treffen (Vorschlag des Assistenten); das trägt der Text, nicht das Bild.
  **Neuer Untertitel (2026-11-24, Wahl des Auftraggebers):** „Gemeinsam durch Azeroth“ / „Together
  through Azeroth“ statt „Dein Gehilfe in Azeroth“ (klang nach den entfernten QoL-Funktionen), im
  Fensterkopf (`ui_tagline`) und auf der Website (`tagline`). Er muss in eine Zeile passen: Im Kopf
  hat er bei 11 px nur etwa 180 px bis zum Seitennamen (`SIDEBAR + PAD`). Ebenfalls vorgeschlagen
  und nicht gewählt: „Eure Reise, gemeinsam erzählt“ sowie „Das Lagerfeuer für deine Gefährten“ und
  „Für alle, mit denen du unterwegs bist“ (beide zu lang für diesen Platz). Im Spiel noch nicht
  gesehen.
