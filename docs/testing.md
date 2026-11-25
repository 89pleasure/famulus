# Checks and tests

Part of the project notes; requirements, rules and the index of all files are in
[AGENTS.md](../AGENTS.md). References of the form "see X" point to a heading or a bold entry;
the index there says which file it is in.

## Tests against the mock

- `luajit tests/run.lua` loads the addon against a simulated client API (`tests/wowmock.lua`)
  and checks every feature, the window and the translations. Must be green before every commit.
- The mock proves our own logic, not the client's behaviour. For that there is the self-test
  in game, see "Testing in game".
- Secret values in the mock: `mock.SECRET` refuses indexing, arithmetic, comparison and
  concatenation. A true/false check (`not x`) cannot be intercepted in Lua; so the test checks in
  the source that `ns.IsSecret(x)` comes before every test of `x`.
- Sizes in the mock: `SetWidth`/`SetHeight`/`SetSize` store their value in `mockWidth`/`mockHeight`,
  not in `width`/`height`. In the client `SetWidth` sets no field on the frame; whoever reads a
  width as a field must set it themselves (`book.width`). Before, the mock hid such a bug
  (see "Bug 2026-11-24"). Tests read the size via `GetWidth()`.

## State of checks in game

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
  in the strip (18 px) and in the rail (30 px) look clean, whether `className` from the
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
