# Checks and tests

Part of the project notes; requirements, rules and the index of all files are in
[AGENTS.md](../AGENTS.md). References of the form "see X" point to a heading or a bold entry;
the index there says which file it is in.

## Tests against the mock

- `luajit tests/run.lua` loads the addon against a simulated client API (`tests/wowmock.lua`)
  and checks every feature, the window and the translations. Must be green before every commit.
  What it checks of the languages is in docs/languages.md ("Checks").
- The mock proves our own logic, not the client's behaviour. For that there is the self-test
  in game, see "Testing in game".
- Secret values in the mock: `mock.SECRET` refuses indexing, arithmetic, comparison and
  concatenation. A true/false check (`not x`) cannot be intercepted in Lua; so the test checks in
  the source that `ns.IsSecret(x)` comes before every test of `x`.
- Sizes in the mock: `SetWidth`/`SetHeight`/`SetSize` store their value in `mockWidth`/`mockHeight`,
  not in `width`/`height`. In the client `SetWidth` sets no field on the frame; whoever reads a
  width as a field must set it themselves (`book.width`). Before, the mock hid such a bug
  (see "Bug 2026-11-24"). Tests read the size via `GetWidth()`. The width of a text is its
  letters times 6.5, not its bytes (since 2026-11-26: Cyrillic has two bytes a letter).

## State of checks in game

- **Memory in game (2026-11-27, client 1.60.1 build 71139, deDE, 10 of 11 features, developer
  mode on, `/fam report`):** 2960 KB eight seconds after `/reload` without the window, 9158 KB
  after the window had been opened (on 2026-11-26 9263 KB). The mock with the owner's saved data
  estimates about 1.8 MB held before and 9.2 MB with every page and picture (see "Memory" in
  `docs/window.md`); the figure in game also counts garbage not yet collected, and right after a
  login that is the loading itself and the self-test, so the 2960 are not all held. The shared
  paint records and spans since then are checked against the mock only. To tell held memory from
  garbage in game: `/run collectgarbage("collect") UpdateAddOnMemoryUsage()
  print(GetAddOnMemoryUsage("Famulus"))` (not yet tried; the client may refuse it to addons).
- **Bug 2026-11-24 (found and fixed in game, fix confirmed in game):** The window opened without
  content and with almost no text; after a click on "Fellow travellers" everything came back, a
  click on "Chronicle" left the fellow travellers highlighted and cut them off at 600 px. Cause:
  the chapter head with route (`LayRoute` in `UI/Book.lua`) computed with `head.width`, which only
  the mock knew. The error aborted `Render` after the content area had already been set to book
  width and before the sidebar, header and tabs were labelled. Found via the game's error display
  (see "Testing in game"). After the fix the owner opened the window in game: "Works".
- **First self-test in game on 2026-11-16** (client 1.60.1, build 70938, deDE): 54 checks ok,
  1 warning, 0 failed; no blocked actions, no Lua warnings. Confirmed:
  - The addon loads, the window opens, settings and window position are saved.
  - All 16 features find the API they need.
  - The four TGA textures load (`SetTexture` returns true) and look right in the window
    (screenshot checked).
  - `Texture:SetGradient("VERTICAL", CreateColor(...), CreateColor(...))` works; the
    window frame shows the gradient.
  - Memory: 360 KB with 6 active features and 5 game events.
- **Play session 2026-11-16:** mainly checked the QoL features that have since been removed. What
  holds in general: closing Blizzard's panels from addon code carries a taint risk; the built-in
  history of the chat input (up/down) does not react in Forever; the EventRegistry signal
  `ChatFrame.OnEditBoxFocusLost` fires before Blizzard closes an empty input and resets the
  chat type.
- **Aliases (2026-11-16, checked against the mock only, not yet in game):** category `aliases` with
  three features and the alias list, see "Aliases" below.
- **Aliases in game (2026-11-18):** The alias appears in the normal chat and in Guildy (confirmed).
- **Aliases in online and offline notices (2026-11-25, checked against the mock only, not yet in
  game):** see "Online and offline notices" under "Aliases". Open in game: whether the alias
  shows in "[Name] has come online." for friends and guild members and in "Name has gone
  offline.", and what `/fam test` reports under "online notices".
- **Reactions in the chronicle (2026-11-25, checked against the mock only, not yet in game):**
  see "Reactions" under "Chronicle" and under "Sharing". Seen in game (screenshot from the owner,
  2026-11-25): the reaction at the foot of a friend's card, in the accent; at 15 px the clapping
  hands did not read, reworked since (see "Look" there). Open in game: whether the four icons
  load (`/fam test`, group `media`) and read well at 18 px in the foot of a card, whether the
  game's tooltip on a card looks right, and, with two accounts, whether a reaction arrives at
  once and one to someone offline at their next login. With one account the sample entries
  (`/fam chronicle demo`) show the look: reactions received on the level 40, one given on
  Borin's boss. The button on a friend's card in the live feed: with one account
  `/fam feed test` shows it (it lights up, the card closes, nothing is sent). Tried in game
  (2026-11-25): works. Not yet seen in game: the card closing after a reaction, and clicking it
  in combat.
- **Sound of the live feed (2026-11-25, checked against the mock only, not yet in game):** see
  "Sound" under "Live feed". Open in game: whether `click.ogg` plays after a `/reload`
  (`/fam feed test`), whether it is too loud or too quiet next to the game's sounds.
- **Settings tabs (2026-11-25, checked against the mock only, not yet in game):** see "Settings
  tabs" in `docs/window.md`. Open in game: whether the list and the detail scroll by the mouse
  wheel, whether the switch in an entry and the one beside the name react (each has a hit area of
  its own), how pills and chips look, whether long names are cut off cleanly.
- **Time and date format (2026-11-26, checked against the mock only, not yet in game):** see
  "Time and date format" in `docs/window.md`. Open in game: the 12-hour clock in the strips of the
  chronicle's cards and its chapter headings, the two new icons (`/fam test`, group `media`: `clock`,
  `calendar`).
- **Data version (2026-11-26, checked against the mock only, not yet in game):** `FamulusDB` and
  every `FamulusCharDB` carry `dataVersion` (see "Saved data" in AGENTS.md). In game: after the
  first login with this version both files have `dataVersion = 1` and `FamulusDB.journal` is gone
  (`/dump FamulusDB.dataVersion, FamulusCharDB.dataVersion`).
- **Class abilities in the chronicle (2026-11-27, checked against the mock only, not yet in
  game):** see "Class abilities" under "Chronicle". In game: `/fam test`, group `chronicle`,
  names every spell and item ID the client does not know; a druid, paladin or warlock learning
  one of them shows whether the entry and its name come.
- **Welcome page (2026-11-26, checked against the mock only, not yet in game):** see "Welcome
  page" in `docs/window.md`. To see it again in game: "About" › "Show welcome page"; as a new
  player would, with `/run FamulusDB.welcome = nil` and the five main features off.
- **New window (2026-11-18, checked against the mock only, not yet in game):** see "The
  window" below. The Inter fonts load (see "Font"). Open in game: whether rounded corners, shadows and hairlines look clean, switching
  the colour schemes, the sliding tab marker, gradients and glow effects.
- **Fellow travellers (2026-11-23, checked against the mock only, not yet in game):** its own area,
  see "Fellow travellers" below.
- **Fellow travellers with friends and guild only, cleanup (2026-11-24, checked against the mock
  only, not yet in game):** see "Friends and guild only, cleanup" under "Fellow travellers".
- **New frame and fellow travellers overview (2026-11-24, checked against the mock only, not yet in
  game):** see "The window" and "Fellow travellers". Open in game: ring around the crest (`/fam test`,
  group `media`, check `ring`), class icons (check `class icons`), the page without
  sidebar, the continuous background of header and sidebar. Visible on a screenshot from
  2026-11-24 (sample data): ring with progress and class icon (warrior) on the crest
  in a person's story.
- **Clear line between chronicle and fellow travellers (2026-11-24):** see "Chronicle and
  fellow travellers". Seen in game with the sample data (screenshots from the owner, 2026-11-24):
  tab and rail "Friends", the stats cards, the filter row with "Show all" and "Your
  story" on one line, on the person's card "Set alias" and "In the chronicle"
  side by side, bosses with names as cards of their own, no entries from the chronicle in "Your
  story". Open in game: whether `BOSS_KILL` in a real group delivers the boss name the way
  the cards show it.
- **Class icon and character name in the chronicle (2026-11-24, checked against the mock only, not
  yet in game):** see "Class and name" under "Chronicle". Open in game: whether the class icons
  in the rail (30 px) look clean (in the book's strip they are gone since 2026-11-27: at 18 px
  hardly more than a dark speck), whether `className` from the
  friends list in Forever matches `LOCALIZED_CLASS_NAMES_MALE`/`_FEMALE`.
- **Fellow travellers' groups (2026-11-24, checked against the mock only, not yet in game):**
  see "Groups" under "Fellow travellers". Open in game: whether a group stays together across
  `/reload` and disconnects, whether `ZONE_CHANGED_NEW_AREA` delivers a group's zones
  completely, how crests and name plates look in the book.
- **Not yet checked in game:** the remaining aliases (context menu, tooltip, input row in the window),
  in the window the dropdown, the search and scrolling, behaviour in combat (secret values, taint).
- **Self-test 2026-11-19** (client 1.60.1, build 70959, deDE): 80 ok, 3 warnings, 0 failed;
  629 KB with 8 active features and 4 game events.
  - The three Inter fonts do not load (`SetFont` returns false); the window uses the
    game font. Cause (checked via `/run`): the client loads a font file in the background on the
    first `SetFont`; this first call returns false, a later one true. Symlink and
    trimming the files are not the cause (Polestar's untrimmed Inter behaved the same).
    Requesting them at login did not help (self-test 2026-11-24 still false); the explanation
    has been under "Font" since 2026-11-25: the warning was a false alarm, Inter is drawn.
  - The button under Options › AddOns › Famulus closed Blizzard's settings window with
    `SettingsPanel:Close()` from addon code. The game then reported "Famulus wurde blockiert …"
    (German client). Cause: without an argument, `Close` returns to the game menu via
    `TransitionBackOpeningPanel` and in doing so calls the protected `ToggleGameMenu`. Now
    `SettingsPanel:Close(true)` as in FlareUI (Polestar: `HideUIPanel`); confirmed in game (no
    message, Famulus in front). Leaving it open does not work: Famulus
    then sits behind Blizzard's window (both `HIGH`).
  - `devLog` did record the blocks after all (on first reading it was still empty, probably
    read before saving): at 12:13 and 12:15 one `ADDON_ACTION_FORBIDDEN` each for
    `SpellStopCasting()`, `SpellStopTargeting()` and `UNKNOWN()`, at the time of the tests with the
    old `Close()`. Since `Close(true)` no more entries (report 16:39).

## Testing in game

WoW Forever is installed on the development machine: `/Applications/World of Warcraft/_forever_`.
`Interface/AddOns/Famulus` there is a symlink to this repo's `Famulus/` folder, so every
change is in the game after `/reload`. On the Windows machine (since 2026-11-18) the game is
at `D:\Games\World of Warcraft\_forever_`, the repo at `E:\Develop\wow\famulus`;
`Interface\AddOns\Famulus` there is a directory junction to `Famulus\`.

- `/fam test` checks against the real client: the API each feature needs, the uncertain spots
  named above (textures, camera zoom, popup names, map, error text globals) and the assumptions from
  "WoW Forever: what you need to know". The report ends up in `FamulusDB.selfTest`.
- `/fam dev` toggles developer mode: the self-test then runs three seconds after every
  login, and blocked actions (`ADDON_ACTION_BLOCKED`/`_FORBIDDEN`) as well as the addon's
  `LUA_WARNING` are collected in `FamulusDB.devLog`. Since 2026-11-25 sharing also writes every
  step of the exchange into `FamulusDB.devTrace` (see "Trace" under "Sharing"). Off by default;
  then it costs nothing. Switching it off clears log and trace.
- **Bug report (since 2026-11-26, issue #47; copying confirmed in game on 2026-11-26):**
  `/fam report` or About › "Copy bug report" runs the self-test quietly (`ns:RunSelfTest(true)`)
  and shows `ns:BugReport()` (`Core/SelfTest.lua`) in a small window of its own (`UI/Report.lua`,
  strata `DIALOG`, built on first use, no global name): a multi-line edit box with the text
  selected, so the player copies it with Ctrl+C (`CopyToClipboard` is protected). Typing changes
  nothing, a click selects it all again, Escape closes it. The text, in English for whoever
  reads the issue: version, client, languages, data version, profile, developer mode; which
  features run, are off or cannot run, areas switched off; idle cost; with sharing on its counts
  (`sharing.Status()`: linked, online, waiting messages); the self-test (failures first, at most
  40 checks that are not ok); in developer mode the whole `devLog` and the newest 80 lines of the
  trace. No names (the log and trace hold tags only), and no "|", which an edit box takes as the
  start of a code. Without developer mode the window's hint asks to turn it on and repeat the
  problem. The GitHub issue form `.github/ISSUE_TEMPLATE/bug_report.yml` has a field for the
  text. Open: the sentence on CurseForge and the website (issues #49 and #50). Players without a
  GitHub account can paste it into a comment on CurseForge. In game (2026-11-26, deDE): the
  window opens and Ctrl+C copies the whole text; the owner's first report showed 9263 KB of
  memory and guildyAliases as a failed check, because the regular Guildy had replaced the fork
  (see "guildyAliases" in docs/aliases.md; since then no failure). Not seen yet: how a long text
  (developer mode with a full trace) scrolls.
- At startup the game sets all files in the addon folder to mode 777, and through the symlink
  also in the repo. That is why `git config core.fileMode false` is set locally here; set it again
  after a fresh clone, otherwise all files show up as changed.
- The game only writes the data to disk on `/reload` or on logout. After that
  `luajit tools/read_selftest.lua` reads the report (with `--all` also the passed checks), the
  `devLog` and the trace. On the Windows machine pass the game folder:
  `luajit tools/read_selftest.lua "D:/Games/World of Warcraft/_forever_"`. Until 2026-11-25 the
  tool found nothing on Windows (it ran `ls` and `grep` through `cmd.exe`); now PowerShell finds
  the newest file there and `findstr` the client logs.
- Course of a round: the owner starts the game, logs in and does `/reload`; the
  assistant reads the report. The assistant cannot operate the game itself, and automating input
  into the game is off limits (terms of use).
- Lua errors are written by Blizzard's error handling via `C_Log.LogErrorMessage` to the client logs
  under `_forever_/Logs/`; which file is not yet confirmed. `AddLuaErrorHandler` is only for
  secure code (`assert(issecure())`), we do not replace `seterrorhandler`.
- **Lua errors are only visible in game with `/console scriptErrors 1`** (then `/reload`). On the
  Windows machine the display was off (no `scriptErrors` in `WTF/Config.wtf`), and the bug from
  2026-11-24 was in no file under `Logs/`. If the window looks half built, ask about this
  first; the message with stack and line then appears as a window in game.
- **BugGrabber and BugSack** are installed on the Windows machine (as of 2026-11-24, plus
  `scriptErrors 1` in `WTF/Account/<account>/config-cache.wtf`). They catch Lua errors before
  the game shows them as a window; in game only BugSack then reports. The errors are saved
  after `/reload` in `SavedVariables/!BugGrabber.lua` (`BugGrabberDB.errors`, with stack).
  Look there first before ruling out an error.
- Screenshots of the game are in `_forever_/Screenshots/` and are the basis for
  layout work.
- What the self-test does not cover: whether the chronicle records the right events and whether
  sharing between players arrives. Only playing itself shows that (for sharing, with two
  accounts).
