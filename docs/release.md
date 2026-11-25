# Veröffentlichung auf CurseForge

Teil des Projektwissens; Vorgaben, Regeln und die Übersicht aller Dateien stehen in
[AGENTS.md](../AGENTS.md). Verweise der Form „siehe X“ meinen eine Überschrift oder einen fett
gesetzten Eintrag; in welcher Datei er steht, sagt die Übersicht dort.

Wunsch des Auftraggebers (2026-11-24): eine erste Alpha auf CurseForge, mit automatischem Upload.
Eingerichtet am 2026-11-24 nach dem Vorbild von FlareUI und Guildy; der Aufbau im Einzelnen ist eine
Entscheidung des Assistenten. Erste Datei: `v0.1.0-alpha.1` als Alpha, hochgeladen am 2026-11-24
(Workflow grün, CurseForge antwortete „Success!“), danach in der Moderation von CurseForge.

- **Werkzeug:** der BigWigs-Packager (`BigWigsMods/packager@v2`) als GitHub Action in
  `.github/workflows/release.yml`. Er bildet `## Interface: 16001` auf die CurseForge-Spielversion
  „WoW Forever“ ab (laut Quellcode `16???` → `forever`, Versionstyp 88568). `.pkgmeta` hebt den
  Unterordner `Famulus/` per `move-folders` an die Spitze des Zips (CurseForge will genau einen
  Ordner, benannt wie die `.toc`) und lässt den Rest des Repos draußen. Lokal mit dem Packager
  geprüft (`release.sh -d -z`): ein Ordner `Famulus` mit den Dateien des Addons, Version ersetzt.
- **Ausgelöst wird nur durch einen Tag** `v…`, den der Auftraggeber selbst setzt. Pushes und Pull
  Requests laden nie hoch; dort laufen nur die Tests (`.github/workflows/tests.yml`) und, wenn
  sich auf `main` etwas in `website/` ändert, die Veröffentlichung der Website (siehe „Website“).
- **Der Tag bestimmt den Dateityp.** `tools/release_check.sh` lässt nur drei Formen zu: `v1.2.3`
  (Release), `v1.2.3-beta.1` (Beta), `v1.2.3-alpha.1` (Alpha). Grund (Vorgabe des Auftraggebers:
  nichts mit „alpha“ oder „beta“ darf als normaler Release erscheinen): Der Packager lädt jeden Tag
  ohne diese Wörter als Release hoch, `v0.2.0-rc1` wäre sonst bei allen Spielern gelandet. Das
  Skript prüft außerdem, dass `CHANGELOG.md` einen Abschnitt `## <version>` (Tag ohne „v“) mit
  Text hat, dass die `.toc` eine `## X-Curse-Project-ID` trägt und dass das Secret `CF_API_KEY`
  gesetzt ist. Erst danach laufen die Tests, und nur wenn sie grün sind, baut und lädt der Packager.
- **Ablauf eines Release:** Abschnitt in `CHANGELOG.md` schreiben (Englisch, wird der Changelog der
  Datei auf CurseForge), per Pull Request nach `main` bringen, dann auf dem gemergten Stand von
  `main` `git tag v0.1.0` und `git push origin v0.1.0`.
  Prüfen vorab: `bash tools/release_check.sh v0.1.0`. Von Hand gestartet (Actions › Release › Run
  workflow) baut der Workflow das Zip ohne Upload und hängt es eine Woche an den Lauf.
- **Version:** Die `.toc` trägt `@project-version@` in einem `#@non-debug@`-Block, der Packager
  setzt den Tag ein. Die Arbeitskopie (Junction) liest `## Version: dev` aus dem `#@debug@`-Block;
  Fenster und Selbsttest zeigen dann „dev“. `ns.version` lässt das „v“ des Tags weg.
- **Changelog:** Fehlt `.release-notes.md`, baut der Packager einen Changelog aus den Commits (samt
  alter `Co-Authored-By`-Zeilen). Deshalb schreibt der Workflow die Datei immer, beim Probelauf
  als Platzhalter.
- **Regeln von CurseForge** (Support-Seiten, gelesen 2026-11-24): Projekt und jede Datei werden von
  Hand geprüft (täglich 8–15 Uhr MEZ, der Reihe nach; Stunden bis Tage). In der App erscheint ein
  Projekt nur mit mindestens einer Datei vom Typ Release; Alpha und Beta bekommt nur, wer die
  Release-Art für das Addon umstellt. Jede Datei braucht einen Changelog; externe Download-Links
  sind verboten.
- **Lizenz (Entscheidung des Auftraggebers, 2026-11-24): alle Rechte vorbehalten**, nach dem
  Muster von Cell (`LICENSE` im Wurzelordner). Er wollte den Code zeigen, aber keine veröffentlichten
  Forks; die GPL (auch mit Namensschutz nach Abschnitt 7) hat er deshalb verworfen. Erlaubt: Code
  ansehen, für den eigenen Gebrauch ändern, auf GitHub forken nur für Pull Requests. Nur mit
  schriftlicher Erlaubnis: weitergeben, hochladen, als eigenes Projekt veröffentlichen, größere
  Teile verwenden, Name und Logo nutzen. Beiträge darf der Auftraggeber unter beliebigen Bedingungen
  verwenden (damit bleibt ein späterer Lizenzwechsel möglich). Der Wortlaut ist ein Entwurf des
  Assistenten, keine Rechtsberatung; als Urheber steht auf Wunsch des Auftraggebers „89pleasure“. Der
  Packager legt die Datei als `Famulus/LICENSE` ins Zip (lokal geprüft; als ungetrackte Datei
  lässt er sie weg). Auf CurseForge „All Rights Reserved“ wählen. Damals verbreitet: alle Rechte
  vorbehalten bei DBM, Details!, ElvUI, Cell, Masque; GPL bei WeakAuras, Questie, MDT, Guildy,
  OneForAll, Polestar; MIT bei OmniCC und FlareUI. Den Fork-Knopf eines öffentlichen Repos kann keine
  Lizenz abschalten. Vor dem Öffentlichmachen des Repos offen: Die alten Commits enthalten
  `Co-Authored-By: Claude …`-Zeilen (siehe Arbeitsablauf).
- **Logo für das Projekt:** `docs/curseforge/logo.png` (1024 × 1024), gerendert aus
  `docs/curseforge/logo.svg`: die Flamme aus `tools/make_media.py` mit Schein auf dem dunklen Grund
  von `logo-round.tga`, als volles Quadrat, weil CurseForge selbst zuschneidet, rundet und auf
  400 × 400 verkleinert. Flamme und Funken liegen im eingeschriebenen Kreis, ein runder Zuschnitt
  schneidet also nichts ab. Neu rendern (Git Bash, Chrome auf dem Windows-Rechner; im SVG-Kommentar
  darf kein doppelter Bindestrich stehen):
  `"/c/Program Files/Google/Chrome/Application/chrome.exe" --headless=new --disable-gpu
  --hide-scrollbars --force-device-scale-factor=1 --window-size=1024,1024
  --screenshot="<abs. Pfad>\logo.png" "file:///<abs. Pfad>/logo.svg"`.
  Eine Entscheidung des Assistenten, vom Auftraggeber noch nicht gesehen.
- **Projekt angelegt** (vom Auftraggeber, 2026-11-24): CurseForge-Projekt-ID 1828785, steht als
  `## X-Curse-Project-ID` in der `.toc`. Probelauf auf GitHub am 2026-11-24 grün: Spielversion
  1.60.1 (Forever) erkannt, 60 Dateien (Addon plus `LICENSE`), Zip `Famulus-<version>-forever.zip`
  (der Packager hängt „-forever“ an, auch an die Bezeichnung auf CurseForge).
- **Erste Datei als Alpha (Entscheidung des Auftraggebers, 2026-11-24):** Tag `v0.1.0-alpha.1`,
  „damit sie nicht als Release rausgeht, wir sind ja noch nicht so weit“. Verworfen ist damit die
  Empfehlung des Assistenten (`v0.1.0` als Release, damit Famulus in der App erscheint). Folge:
  Solange es keine Release-Datei gibt, steht Famulus nur auf der Website von CurseForge, nicht in
  der App. Der Abschnitt in `CHANGELOG.md` heißt deshalb `## 0.1.0-alpha.1`.
- **Token:** Das Repository-Secret `CF_API_KEY` hat der Auftraggeber selbst hinterlegt
  (2026-11-24); der Token ging nicht durch den Assistenten.
- **Offen:**
  - Projektseite: Summary vom Auftraggeber gewählt („Your companion for playing together: Famulus
    helps you stay close to the friends and fellow adventurers who make your journey so
    special.“); die Beschreibung liegt als Entwurf des Assistenten in
    `docs/curseforge/description.md` (Englisch, Markdown, ohne Guildy, weil dessen Anbindung nur
    mit dem Fork geht). Kategorien: Der Assistent rät von „Companions“ ab (auf CurseForge
    Haustiere und Reittiere) und empfiehlt „Chat & Communication“ mit „Guild“.
  - Nicht eingerichtet: Wago, GitHub-Releases, eine Freigabe-Umgebung für die Secrets.
- Auf GitHub gelaufen (2026-11-24): der Test-Workflow, ein Probelauf ohne Upload und der Upload
  von `v0.1.0-alpha.1` („Uploading Famulus-v0.1.0-alpha.1-forever.zip (1.60.1 alpha) … Success!“).
  Ein Tag ohne Upload (Freigabe, Wago, GitHub-Releases) ist nicht eingerichtet.
