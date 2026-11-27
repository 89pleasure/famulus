# The window

Part of the project notes; requirements, rules and the index of all files are in
[AGENTS.md](../AGENTS.md). References of the form "see X" point to a heading or a bold entry;
the index there says which file it is in.

**Redesign 2026-11-18** at the owner's request: the aliases brought the first larger feature; the
window should stay clear as more main features are added. Requirements: main features
in the sidebar with a layout of their own per feature, modern and
plain like Polestar, light and dark design (the light one has been removed again since 2026-11-19,
see "Colours"), round corners, a font of its own. The owner left a free hand;
layout, colours and font are the assistant's decisions and not yet confirmed.

- **Layout (since 2026-11-23, the owner's request following the example of OneForAll, confirmed
  on an HTML mockup):** The features are at the top, their sub-areas on the left.
  - **New layout (2026-11-24, the owner's request after the first look at the fellow travellers
    without a sidebar):** Navigation is back in the sidebar, the same on all pages.
    In between, on the same day, there was briefly a header with tabs, search and icons and a page
    without a sidebar (`page.sidebar = false`); both are removed again.
  - **Header** (76 high, across the full width, dark ground like the sidebar): on the left logo, name
    and tagline; next to them name and description of the selected page (`window.area`, during a
    search "Search" and the number of hits); on the right only Close.
  - **Sidebar:** search at the top, below it the main features as cards (`navButtons`, 64 high,
    since 2026-11-27 at the owner's request: with three entries the rows left the sidebar
    empty): the icon on a tile, the name (wraps to a second line if long), and at the right a
    small live number without a label (12 px, semibold, `textMuted`) (`page.count`: the chronicle's entries, the fellow
    travellers, the aliases), redrawn with the window's refresh on `CHRONICLE_CHANGED`,
    `FELLOWS_CHANGED` and `ALIASES_CHANGED`. The owner first chose a live count as a subtitle
    below the name, then after a look in game the bare number at the right instead, at first larger, then as muted as the subtitle had been. A
    switched-off one is greyed out with an "OFF" pill in place of the number; the selected one
    has the fading gradient and the glowing bar. At the bottom after a line "Settings" and
    "About" as plain rows. Seen in game and confirmed by the owner (2026-11-27: "good like this");
    the former line "x of y active" and the line "Active"
    under "About" are removed (the owner's decision, 2026-11-24).
  - **Content:** at the very top the page's sub-areas as tabs (`window.tabs`, 48 high, stroke with
    gradient under the selected one), "Reset" to the right of them. The views of an area stand
    by name at the left; its settings tab (`CategoryTab`, `tab.icon = "gear"`) stands at the right
    end as a gear followed by "Settings" (`ui_tab_display`, the same name in every area; since
    2026-11-27, the owner's request: the gear alone got lost), with "Reset" to its left.
    The tabs of the Settings page keep their names. No other tab has an icon: the views have no
    pictures of their own, and theirs would repeat the sidebar's (2026-11-27; checked against
    the mock only, not yet seen in game). A page with only one
    sub-area ("About") shows no tabs; during a search there are none. Title and
    description of the sub-area are no longer shown above the content (`ui_tab_*_desc` is
    currently not displayed). The ground of header and sidebar lies on the window itself
    (`Ground` in `UI/Options.lua`), so that the grain runs over it as one band.
    The assistant's decisions in detail, not yet seen in game.
  - In the code the areas are still called "pages" (`pages`, buttons `navButtons`) and the
    sub-areas "tabs" (`page.tabs`, `window.tabs`, texts `ui_tab_<id>`); where the project notes
    say "tabs" of an area, they mean the entries of the sidebar. The tab row in the
    content (`UI.Tabs`) with a sliding marker and the heading "Features" are gone.
  - Window 1180 × 730 like the settings window of FlareUI (the owner's request,
    2026-11-23; before that 880 × 590).
  - Seen and confirmed in game by the owner (2026-11-23, "looks great"), together with the
    assistant's decisions: "About" as a tab of its own, header and sidebar on the same
    ground. The master switch in the sidebar has moved into the settings since 2026-11-24.
- **Areas (`ns.areas`, `Core/Features.lua`):** Every category belongs to exactly one area (the
  test checks this). Order since 2026-11-24: Chronicle, Fellow travellers, Aliases (see
  "Requirements"); `ns.categories` follows it, so that the master switches are in the same order.
  Each area has a layout of its own (`layouts.<area>` in
  `UI/Options.lua`). `aliases`: tab "Names" with the card "New alias" and the card
  "Your aliases" (avatar with initial), tab "Settings" (until 2026-11-23 "Display") with the alias
  features. `chronicle`: see "Chronicle". `fellows`: see "Fellow travellers". The settings have the
  tabs "General" (master switches, feedback in chat, minimap icon, character profile),
  "Appearance" (colour scheme, embers, window size) and "Language & time" (German "Sprache &
  Zeit": language, time format, date format; see "Time and date format"; tab id `language`).
  The first page on opening is the first in the sidebar,
  so since 2026-11-24 the chronicle (before that the aliases).
- **Master switch** (since 2026-11-24, the owner's decision: "Only the master switches"):
  the three categories as the first entries, under the heading "Features", in Settings › General
  (`CategoryItem`, texts `area_<id>` and `area_<id>_desc`). The switches of the individual features
  stay on their tabs. If a category is off, its entry in the sidebar is greyed out and carries
  "OFF", its tabs are greyed out, and instead of the content its page shows
  a notice with the button "Switch on in settings" (`window.offNotice`), which
  opens Settings › General.
- **Welcome page (`UI/Welcome.lua`, since 2026-11-26, issue #46; set up step by step since
  2026-11-27, the owner's request, chosen on the mockup "Famulus-Einrichtung in Schritten", claude.ai
  artifact `BhZh9kh6ZaBWSaaX84Rxxi`):** With the defaults a new player sees only the journey
  (`ownJourney`, on from the start since 2026-11-27, the owner's decision: it is the core), so the
  window opens on a page that says what Famulus does, in the website's words, and walks through
  the four main features that stay off by default. The rule for defaults stays as it is.
  - **When:** until the player chooses (`FamulusDB.welcome`, account-wide) and only while none of
    the four in `Welcome.FEATURES` (companions, sharing, rememberFellows, nearbyFriends) is on;
    whoever switched one on never gets it. Closing (X, Escape) is no choice and starts it again
    from the beginning; "Later", "Switch everything on" and the end are. An alias asked for from a
    player's menu (`ns:EditAlias`) opens the aliases page instead, without choosing. Again from
    "About" (row "Welcome", button "Show welcome page").
  - **Look:** an opaque page of its own below the head (frame level +100) that covers sidebar and
    content; the head keeps logo, name, tagline and close, the page's name is hidden
    (`window.area`). It draws the window's ground itself (grain, dusk, sparks of its own; while it
    is shown only they move). Three views:
    - **Start:** logo with glow, "Welcome to Famulus", the website's hero ("For everyone you play
      with." and its lead), the website's four parts as tiles (chronicle, fellow travellers, live
      feed, aliases; "Already on" on what runs), "Set up now" (the owner's wording), "Switch
      everything on", a note that each step shows an example and that sharing reaches only
      friends and guild with Famulus, "Later".
    - **A step** per feature in `Welcome.STEPS` the client can run, five: the four and, after
      sharing, the live feed with the reactions (the owner's request after the first look in game,
      2026-11-27). "Step 2 of 5" with a bar per step, the area, the
      feature's name (since 2026-11-27 in the owner's wording "Record my fellowship", German
      "Gemeinschaft aufzeichnen", and "Nearby", German "In der Nähe"), "Only for you" or, for
      sharing, "Goes to friends and guild members who use Famulus" (`shareInk`), a lead and two points (`ui_welcome_<id>_lede`, `_p1_t`, `_p1`,
      `_p2_t`, `_p2`), and the one option worth deciding at once (`option` in `Welcome.STEPS`,
      `owner` if it belongs to another feature: the reactions are sharing's, with a shorter text
      of their own here, `desc`; friends and guild
      only, include the guild) as a row with its switch, which works
      at once; pointing at it focuses the picture. On the right the feature's picture from the
      settings (`feature.preview`, `UI.Previews`) on a larger stage (340 high), lit
      (`stage.lit`): it shows the feature as if it were on. At the foot "Back", "Skip" and "Switch
      on and continue" (on the last "Switch on and finish"). A step that is on already says
      "Continue" and "Switch off and continue" instead (the owner found no way to skip sharing
      when it was on): skipping always leaves the feature off.
    - **End:** "All done.", what runs now in two columns (the journey "From the start", the steps,
      skipped ones marked, the aliases "Already running"), "Open the chronicle", "Back".
  - **Switching:** a step switches its feature and the master switch of its area on at once
    (`Welcome.Enable`); "Switch everything on" switches on the four the client can run
    (`Welcome.SwitchOn`). Either way one chat line (`msg_welcome_on`) says how many, and the end
    opens Chronicle › Everyone. An empty book says "Your chronicle is running" (`c_empty_on`).
  - Rejected on the first mockup ("Famulus-Willkommensseite", claude.ai artifact
    `4QWBiRsCVYusMxfEbDAmn8`): the three areas as cards with every switch, and one question "with
    friends / only for me / decide myself". Replaced on 2026-11-27: the one big button with a list
    "What exactly?" and "Choose myself".
  - Checked against the mock only, not yet seen in game. Open in game: how the pictures look on the
    larger stage (the book and the tiles are made smaller to fit only when needed, the sharing
    scene centres itself in the height), whether the text column fits in French (the mock says the
    tallest step ends at 480 of 568), whether dragging the page moves the window. The screenshot
    `welcome` on the website and on CurseForge still shows the old page; take it again in game.
- **Bug report (`UI/Report.lua`, since 2026-11-26, issue #47):** a small window of its own above
  the main one (640 × 500, strata `DIALOG`, the window's card, shadow and scale), from
  `/fam report` or About › "Copy bug report". What it shows and why: see "Bug report" in
  docs/testing.md.
- **Reset** acts on the tab (features of the whole section, addon options only their
  key; on Settings › General also the three master switches). The first click asks
  ("Really reset?", red), a second within four seconds carries it out; greyed out on
  default values; not present without settings (list of aliases, "About") and on a
  switched-off page.
- **Search:** in the header, across all pages and tabs, hits grouped per tab in cards ("Aliases ·
  Settings"); no tabs in the results view. It leaves out the content of a switched-off feature,
  but finds its master switch. On a page without a sidebar the
  hits take the full width.
- **Time and date format (since 2026-11-26):** Settings › Language & time, below the language.
  The three have a tab of their own, so that General keeps the master switches and how the addon
  behaves, and resetting General no longer resets the language.
  `general.timeFormat`: `"24h"` (default, 21:40) or `"12h"` (9:40 PM; midnight 12 AM, noon
  12 PM; `g_timeFormat_am`/`_pm`). `general.dateFormat`: `"auto"` (default, the language's order,
  `c_date`: enUS 2026-11-19, deDE 19.11.2026) or one of `ns.DATE_FORMATS` (`{y}-{m}-{d}`,
  `{d}.{m}.{y}`, `{m}/{d}/{y}`, `{d}/{m}/{y}`); an unknown saved value falls back to the language.
  The dropdowns name each choice by an example (today at 21:40, today's date). Every time and
  date the window writes (chronicle, fellow travellers) goes through `ns.FormatTime(t)` and
  `ns.FormatDate(year, month, day)` in `Core/Locale.lua`; never `date("%H:%M")` in the UI. Only the
  logs keep ISO with seconds (self-test, `devLog`, the sharing trace). A change redraws the open
  window (`RequestRefresh("layout")`). Why the clock has no "automatic": the game's clock has a
  24-hour switch (CVar `timeMgrUseMilitaryTime`, read by `GameTime_GetFormattedTime` in
  `Blizzard_FrameXMLUtil/GameTimeUtil.lua` on the `forever` branch), but its default in Forever is
  unknown; following it could switch players who never touched it to 12 hours. Checked against the
  mock only, not yet in game; open: how much of a long name "7:05 PM – 9:40 PM" leaves in the
  strip of a bundled card in the chronicle (the name is cut off with "...", the time never; the
  chapter's lines make room by themselves).
- **Colours (reworked 2026-11-18, evening):** The owner found the first version (neutral
  greys, accent only as a fill) too arbitrary. Role models for colour concept, accents and effects:
  Polestar Guide and Mastercraft, without copying them. On an HTML mockup the owner chose the concept
  **"Lemon"**: petrol surfaces, lemon-yellow accent. Since then a colour scheme (`general.accent`,
  list `UI.accents`) is a whole concept and no longer just an accent colour: it tints
  all surfaces with its hue (`hue`, `saturation`; the brightness ladder `ladder`) and brings
  an accent as a colour pair (`accent` → `accent2`) for gradients. Available: `lemon` (default),
  `mint`, `rose`, `lilac`, `amber`. Seen and confirmed in game by the owner is `lemon`;
  the other four come from the mockup.
- **Classes and factions in colour (2026-11-27, the owner's request):** A class or faction named
  in a line stands in its colour, muted so that none outshines the accent: the game's colours at
  about half their saturation and of like lightness (tokens `class<FILE>` for all nine classes,
  `factionHorde`, `factionAlliance` in `UI/Theme.lua`; the priest's white would be the text's,
  so ivory). Of two palettes on a canvas in the chat the owner chose A, "gedeckt" (B kept more of
  the saturation). Only the word is coloured, not the line or the name: `UI.Colored(token,
  text)` wraps it in the game's colour code, so it suits words within a line but does not
  follow a change of scheme (these tokens are the same in every scheme). Where: the fellow
  travellers' tiles and list ("Level 41 Mage"), the rows of "Nearby" and its cards, the faction
  of someone out of reach. Not in what the search reads (`FellowDesc`), which would find the
  colour code. Names stay white. The pictures of the settings show the game and keep its own
  colours (`gameClass<FILE>`). Seen in game by the owner ("Passt", 2026-11-27). The website's
  demos follow (see "Demos" in docs/website.md).
- **Lines darker than the ground (2026-11-25, the owner's request: the lines were "too
  bright", try a colour darker than the background so they look softer):** Rule: a line is
  a little darker than the darker of the two grounds it parts, never lighter. Before, all
  line tones lay above the grounds (`cardBorder` 0.185, `controlBorder` 0.230, `divider`
  0.160). A first try put them all near black (0.045–0.072); in game the owner found it "a
  bit too dark, it should only differ slightly". Since then, with the scheme's full
  saturation:

  | Token | Lightness | Where | Ground below it |
  |---|---|---|---|
  | `windowBorder` (new) | 0.054 | window outline, line below the head, sidebar edge, line above "Settings" | sidebar/head 0.070 |
  | `cardBorder` | 0.074 | card borders, menus, line below the tabs | window 0.092 |
  | `controlBorder` | 0.105 | secondary buttons, dropdowns, pictures in the book, crests in the feed | card 0.125 |
  | `fieldBorder` (new) | 0.045 | text fields, search, the plates in book and fellow travellers | field 0.055 |
  | `divider` | 0.090 | lines inside a card (option rows, lists, also in the rail since then) | card 0.125, option row ~0.105 |

  Unchanged: the light top edge (`sheen`, `sheenSoft`), the accent border of an active card
  (`cardActive`), `track`. The values are the assistant's choice; the owner confirmed the
  second try in game ("Passt so", 2026-11-25). The website (`--card-border`,
  `--control-border`, `--divider` in `website/styles.css`) still has the light lines; whether it
  follows is open.
- **No light mode (the owner's decision, 2026-11-19):** The window is always dark.
  Removed are the light palette, the option `general.theme`, the button at the top right, the icons
  sun and moon, and the toggle control built only for it (`UI.Segmented`, row type `segment`).
  Do not build it back in without asking. The signal is still called `THEME_CHANGED` and fires on
  a change of colour scheme.
- **Accents and effects:** Accent, gradient and glow stand only for "active / here": switch on
  (gradient, glow), selected tab (stroke with gradient and glow), selected area in the
  sidebar (fading gradient, glowing bar, counter on an accent badge), the chosen entry of a
  settings tab (card, mark on the left; until 2026-11-25 the card of a running feature with a
  fine accent border), a lit chip, the pill "On", field with focus (ring), logo. In addition,
  as a signature, a soft glow in the accent colour behind the logo. Depth via a highlight edge at the
  top of window and cards and recessed containers (the options in a settings tab). Hover fades in
  and out (`Shape:Fade`).
  The owner's decisions on the mockup: **one** line between sidebar and content, the
  window border runs uniformly around everything; the
  main button ("Save") has a horizontal gradient, a darker border, a light line
  inside and a shadow, but no top-to-bottom gradient (it looked "plasticky"). Also decided then
  and gone with the settings tabs (2026-11-25): option rows below their feature with a dot and a
  line from card edge to card edge.
- **Background (2026-11-19, the owner's request):** A fine grain (`grain.tga`, pure
  noise, one texel per screen pixel via `SetTexCoord`, `UI.Grain`) lies as a band across the
  full window width, sidebar and content alike, as high as the header (`GRAIN_BAND`), and
  fades out below the tabs. The owner's decisions after looks in game: a first
  version with a cloudy layer looked blotchy; the same everywhere, the grain was too much; from five
  switchable variants the owner chose "sidebar and header", but as one continuous band at
  header height. The selection in the window is removed again. The content gets slightly darker
  towards the bottom. In addition, small embers rise (`UI.Embers`): textures with the client's
  animations (`AnimationGroup`, `Alpha` and `Translation`), so without `OnUpdate` and without Lua
  per frame. They run only while the window is open and lie behind cards and entries. Can be
  switched off under Settings › Appearance (`general.embers`, default on). Confirmed in game: grain
  and embers run. Not yet seen: the band in the sidebar and its fade-out.
- **Settings tabs (since 2026-11-25, the owner's decision, chosen on the HTML mockup
  "Famulus-Einstellungen", claude.ai artifact `LFwDhswccJYQ5APKWMd3bA`: variant B "Feature +
  detail"):** Trigger: the owner found the settings a plain list and wanted them clearer, with
  room for pictures of what an option does later. The owner's own idea was a narrow list with a
  fixed panel that follows the mouse (variant A, the assistant's recommendation); also rejected:
  C (tiles, options in a drawer) and D (a list that unfolds, explanations as tooltips). Every tab
  with settings (`tab.split`: Chronicle, Fellow travellers and Aliases › Settings, Settings ›
  General, Appearance and Language & time) shows, instead of cards of rows (`Render` → `RenderSplit`):
  - **On the left the entries** (`LIST_W` 296 px, scrolls on its own): one per item that is no
    option of another (features, master switches, the addon's own options, tidying up), 56 px
    tall: its icon on a small tile (30 px, lit in the accent while a switch is on), the name,
    below it "On · 11 options" for a switch, what it does for the other kinds, or why it cannot
    run; at the right the switch (with a hit area of its own), the chosen value of a select or the
    colour scheme's dot. A block's title ("Features", "Display", "Tidy up") stands as
    a heading above its entries. The chosen entry lies on a card with the accent mark at its left;
    a click on another one chooses it. The choice is kept per tab (`chosenEntries`), at first the
    first entry.
  - **On the right the chosen entry in full** (a card of 584 px, scrolls on its own): its
    picture if it has one, above the name the page's name ("Chronicle"; added on 2026-11-25 after
    the owner's first look in game, as in the mockup), the name with its control at the right
    (switch, dropdown, swatches or
    button), pills with the state ("On" in the accent) and the default ("Default: on",
    `UI.Pill`), the whole text, then its options: plain ones as rows with their help text in a
    recessed card below "Options"; the options of a group (`option.group`) as chips (`UI.Chip`,
    three per line, an icon in front, `option.icon`, lit while on) below the group's heading
    (`o_<feature>_<group>`) with "8 of 9 on"; pointing at a chip explains it in the line below
    them (`o_<feature>_<group>_desc` while nothing is pointed at). So far only the live feed's
    kinds of events form a group ("kinds"; the kinds' own drawings, `ICONS` in `LiveFeed.lua`:
    skull, swords, star, chest and so on, flag for level-ups and horseshoe for abilities, so that
    they differ; reactions show `cheer`).
  - **Options of a switched-off feature** stay in full but greyed out, with "Switch on "…" to
    change its options." The folding of option rows (`compact`), their dot and recessed ground,
    `FeatureBlocks` and the accent mark on feature cards are gone.
  - **Pictures (`UI/Previews.lua`, since 2026-11-25):** no screenshots but small scenes
    drawn live, so that a change to the addon needs no new picture. Every entry names its scene
    (`preview = "feed"` on a feature, `GENERAL_PREVIEWS` for the addon's own settings,
    `"areas"` for the master switches, `"tidy"`); the detail shows it above the name on a stage
    of 536 × 196 px inside the padding (`UI.Previews.Stage`, clips its scenes). A scene is built
    the first time it is shown and kept, and drawn again whenever the detail refreshes (a setting
    changed, `UI.Previews.Refresh`). It uses the addon's own building blocks and the samples'
    people, so it follows switches, options, colour scheme and language. Pointing at a chip or an
    option row focuses it on that option (`UI.Previews.Focus`, the option's key,
    `item.optionKey`). What moves does so by the client's animations (or `UI.Embers`), stopped
    while the scene is hidden. What is switched off is drawn faint (0.38).
    - **Samples:** `ChronicleService.SamplePeople`, `Sample(kind, own)` (one unsaved entry of the
      chronicle's samples), `SampleClass(name)` and `entry.sampleAlias` (a sample shows under that
      alias); `FellowService.SamplePerson(index)` (a stored person as the samples would have
      written them). The scenes' own words are `ui_preview_*`.
    - **Two grounds:** scenes of the game stand on the website's night sky (`World`, after
      `website/scene.js` and `styles.css`: a rounded gradient `skyTop` into `skyLow`, a dusk with a
      little accent; 46 seeded stars, about a fifth twinkling; Azeroth's two moons, a large one at
      the right with rim, brighter top left and glow, a small blue one at the top left; tokens
      `sky*`, `star`, `moon*` follow the colour scheme). Scenes of the window stand on its ground
      (`window` into `sidebar` with its hairline). Stars and glows stay clear of the rounded
      corners (the stage clips square). The game's places are drawn in its fonts
      (`UI.SetGameFont` with `ChatFontNormal`, `GameTooltipText`, `GameFontNormal` ...) and default
      colours (tokens `chat*`, `tooltip*`, `menuTitle`, `bnet*`, `guildy*`, `minimap*`,
      `class<FILE>`). What a setting changes is framed in the accent (`Outline`).
    - **Chronicle:** `book` (Record my journey), `friends` (Follow my friends) and `names`
      (character name behind the alias) are the chronicle's own book (`UI.Book` with
      `UI.ChronicleChapter`, which builds the cards as the chronicle does, without click, tooltip
      and route), made smaller to fit (`Fit`). `share`: the player's crest and Mira's, news
      travelling both ways between them. `feed`: the live feed's own cards (`UI.Feed.Card`,
      `UI.Feed.Fill`; never on screen), their running-out line looping over the duration, a
      friend's card with its button to react while reactions are on (it catches no mouse there); pointed
      at a kind, a card of that kind (reactions via `liveFeed.ReactionStory`), at "own" one of the
      player's. The older card is a slim row, as on screen (`UI.Feed.Fill(card, story, true)`);
      while the last three stay (`keep`), it rests (`card.body` at `UI.Feed.REST`) and the
      caption says how long a card is new (`ui_preview_feed_keep`).
    - **Fellow travellers:** `fellows`: the overview's tiles (`UI.FellowTile`,
      `UI.FillFellowTile`, the person from `UI.FellowSample`); pointed at "raids" a list of which
      groups count, at "friendsOnly" whom it remembers. `tidy`: who stays, who goes (struck out).
      `nearby` (Who is nearby): the feature's own cards on the feed's place
      (`nearbyFriends.Story`, the same layout as `feed`): friends and guild where the player
      arrives, and one who came; pointed at "guild" with or without the guild, at "cities" a
      card in a city, faint while it would not come.
    - **Aliases:** `chat` (four lines of chat, Borin under the alias as `AliasService.Format`
      writes it, also in the online notice), `tooltip` (the line `TooltipAliases` adds), `menu`
      (the entry `AliasMenu` adds), `bnet` (a Battle.net friend under the alias, with three
      characters), `guildy` (Guildy's list). Switched off, the alias is missing.
    - **Settings:** `areas` (the sidebar's three entries, a switched-off one with "OFF"), `lang`
      (every language by its own name, the one shown chosen, and the tagline in it), `time` (both clocks on an evening of
      play, 19:05 to 21:40, the chosen one in the accent), `date` (the four orders with today's
      date, each named in the language's letters, "YYYY-MM-DD" or "TT.MM.JJJJ"; while it follows
      the language, the language's order says so), `chatfam` (the addon's own chat line
      among others), `minimap` (the button at the saved angle, drawn as `UI/MinimapButton.lua`
      draws it), `profile` (all characters or this one), `accent` (every scheme as a small window;
      tokens `scheme*_<id>` for all schemes at once), `embers` (`UI.Embers`), `scale` (the window
      at a few sizes).
    - The chat's three texts of a line meet top to top: anchored by their middles, an empty text
      in front (the online notice starts with the name) pulled the name into the line above.
    - Open in game: whether the book, the tiles and the game's fonts read well made smaller,
      whether the moving parts run.
  - **Icons of the entries** (added on 2026-11-25 after the owner's first look in game: "the
    icons are missing"): a feature names its own (`icon` in `ns:NewFeature`, a name from
    `UI.media`; the test checks that every feature has one the window knows), the addon's own
    settings theirs in `GENERAL_ICONS` (`UI/Options.lua`), the master switches the area's icon,
    tidying up `trash`. Thirteen new line icons, drawn like the others in `tools/make_media.py`
    (`ICONS` there): share, bell, chat, shield (Guildy), tooltip, menu, link (Battle.net), trash,
    globe (language), compass (minimap), person (character profile), drop (colour scheme), resize.
    The Windows machine has no Python; the TGAs were written by a temporary port of the drawing to
    LuaJIT (not in the repo), which redraws `tag`, `people` and `reset` byte for byte as the
    Python script wrote them. Shapes and choice of icons: the assistant's decisions. Since
    2026-11-26 also clock (time format) and calendar (date format), written by a temporary port
    to Node of `stroke` and `write_tga` that redraws `globe` and `compass` byte for byte.
  - Unchanged: the search (rows in cards, grouped per tab), reset per tab, the notice of a
    switched-off area, the tabs without settings.
  - The assistant's decisions within variant B: sizes, the wording of pills and of the line below
    an entry, that Settings › General and Appearance are shown the same way (as in the mockup),
    the chips' icons. Checked against the mock only, not yet seen in game. The website's rebuilt
    window still shows the old list (see "Window" in `docs/website.md`).
- **Cards:** Tabs without settings (the alias list, "About", empty books) and the search show
  cards of rows; the search groups them per tab.
- **Technique for this:** `UI.Shade(texture, direction, from, to)` for gradients (`SetGradient`,
  follows the theme like `UI.Paint`); `Shape:SetGradient` spreads a gradient over the parts of a
  round shape and needs its size. Glow needs no new texture: `UI.Shadow` with an
  accent colour name instead of `shadow`, `UI.Halo` and the glow behind the logo use `shadow.tga`.
  The glowing dot in the accent (the book's line, the head of a live feed card) is a widget since
  2026-11-27, the owner's request: `UI.GlowDot(parent, size, layer)` gives the dot with its glow
  (`accentGlow`, three times as large, a layer below), `UI.SetDot(dot, size, shown)` changes
  size or visibility of both. Use it wherever such a dot is wanted. The same for the button of a
  reaction (live feed and the chronicle's book, since 2026-11-27): `UI.ReactionButton(parent,
  size, iconSize)` draws a rounded square with the icon, muted or lit (`accentDeep`, accent icon),
  `button:Set(icon, lit, count, second)` (with a count it widens; a second icon stands half behind the first), `button.over` and `button:Paint()` for
  the hover tint; the scripts stay with its owner. A button that shows only its icon names
  itself in the game's tooltip under the mouse (since 2026-11-27): `UI.Button(...,
  variant, icon)` plus `button:SetIconOnly(size, iconSize)` before `SetLabel` (a square; the label becomes
  the tooltip, `button.tip`), or `UI.IconButton` with `button.tip` set by its owner. The tooltip
  goes when the mouse leaves or the button hides.
  All checked against the mock only; open in game are above all `SetGradient` on image textures
  (round corners of switch, button, logo), horizontal gradients and the strength of the glow effects.
- **Shape:** round corners from quarter circles of `circle.tga` plus three rectangles (`UI.Round`,
  `UI.Card` with a hairline border); window 12, cards 10, controls 6–8. Soft shadow around
  window and menus (`UI.Shadow`, `shadow.tga`). The former gradient frame (`UI.GradientFrame`) is
  gone.
- **Memory (measured 2026-11-27 against the mock, with the owner's saved data; the client figures
  are estimates for Lua 5.1, about ±30 %):** Before the window opens Famulus holds about 1.8 MB
  (code ~0.9, the seven languages ~0.5, features and data). The window is the rest, and it only
  grows: frames and textures cannot be freed in WoW, so every pool stays at the largest content it
  ever showed until `/reload` (no leak: showing the same pages again costs nothing). Most of it
  is textures: a rounded shape (`UI.Round`) is 7, a card (`UI.Card`) 14, a card of the chronicle's
  book about 57; with 80 entries the first page of the chronicle draws 50 such cards. Each texture
  costs its own Lua table, and whatever the addon keeps per texture multiplies by thousands.
  Hence, since 2026-11-27: `UI.Paint`/`Tint`/`Ink`/`Swipe` keep one shared record per mode, token
  and alpha (a region points to it; a fading level is kept apart, only while it is not 1) instead
  of a table per region, and the spans `Shape:SetGradient` needs are shared by every `UI.Round` of
  the same inset and radius instead of a table per texture. With the owner's data that took the
  window with every page and picture from about 9.2 to 5.3 MB (first page alone 4.4 to 3.1). Keep
  it that way: nothing per texture that can be shared. Building every page makes about 3 MB of
  garbage, every picture of the settings another 4.7; the game's memory figure counts it until
  the collector runs. The tab "Groups" makes most per click (about 3.5 MB at 100 groups, 10 MB at
  400), because `TimelineData` runs twice per drawing and builds every subset of a group's people as
  a table. Further levers, not done: one texture per rounded shape (`SetTextureSliceMargins`;
  unchecked in Forever), building the rarely seen parts of a book card only when needed.
- **Font:** Inter (SIL Open Font License 1.1) in Regular, Medium and SemiBold, cut down with
  `tools/make_fonts.py` to Latin, Greek, Cyrillic and punctuation (~100 KB each).
  On koKR/zhCN/zhTW clients the game font stays.
  **How the client loads fonts (cleared up 2026-11-25, from FlareUI's source code, comment
  above `ns.FontRedraw` in `Core.lua`; learned there from players' bug reports):** A
  font file only loads once a **visible** FontString **with text** asks for it. Until then
  `SetFont` returns false and the string keeps its old font (a new one has none, and
  `SetText` then throws); once the file is there, it switches by itself. A hidden or empty
  string loads nothing. Text drawn before the load can stay empty; setting the same
  font again does not help, changing the size and back redraws it. Consequences:
  - The `font …` warnings in the self-test (2026-11-19 and 2026-11-24) were false alarms: it checked
    on a hidden, empty string. The request at login (hidden frame, without
    text) also loaded nothing and is removed. Proven by the screenshot in the website's header
    (Windows, 2026-11-24): the window shows Inter in two weights, not Friz Quadrata.
  - Inter appeared despite the old fallback to the game font because the client keeps the first
    request and switches the string later without redrawing it. That probably explains
    the empty tab "Chronicle" and the missing counter of 2026-11-24 (the tab's name
    stayed empty across page changes, width and counter were right; after `/reload` everything was
    there).
  - Since 2026-11-25 (`ApplyFont` in `UI/Widgets.lua`, like `SetFontRaw` in FlareUI): if
    `SetFont` returns false, the string gets the game font, asks for Inter again and goes on
    a list; a ticker (0.5 s, only while someone is waiting, at most one minute, restarted on opening
    the window) asks again, and as soon as the client says yes, the string is redrawn with size+1
    and back. The self-test reads `UI.fontLoaded` and only warns if the window
    asked for the font and it did not come; before the first opening it reports "not used yet".
  - Not taken over from FlareUI: redrawing all strings 2 and 10 s after every loading screen
    (there against strings that said yes right away and still stayed empty). If text stays empty
    after a loading screen, that is the next step.
  - **If it happens again (the owner's decision, 2026-11-25):** Inter stays
    for now. If text stays empty despite the loading fix, the window switches to a font of the
    game that is loaded from the start, namely **Arial Narrow** (`Fonts\ARIALN.TTF`),
    not Friz Quadrata. Polestar shows the game font in its default look; Inter is there
    only an option, with the same plain fallback we used to have. A font family of its own
    (`CreateFontFamily`, as in FlareUI) does not help against the loading: it picks
    the file per text by alphabet (against boxes for Korean or Chinese
    names), but Inter in it has to load just the same.
  - Not checked in game. What you would see: on the first opening after login at most half a
    second of game font, then Inter, no empty text; `/fam test` after opening reports
    `font …` as ok.
  **Also 2026-11-24, unexplained:** After a death (23:44) the chronicle showed it in the book, the
  card "This week" next to it did not count it (5 instead of 6); the window was closed at the death
  and opened afterwards. Book and rail are created in the same `Render` from the same entries.
  At the next death the number was right again (7), BugGrabber had no error, and the mock
  also counts correctly with the owner's saved data. A test in game (loading the samples
  while the window is open) gave "11 11" for `/run local c=FamulusOptionsFrame.rail.cards[1]
  print(c.spec.stats[2].value, c.cells[2].value:GetText())`: computed and set (whether
  the window also showed 11 at the time, the owner did not say explicitly). If it happens again,
  enter this line right away: if it shows the new number but the window the old one, the client
  is not redrawing the text (as above).
- Unchanged since 2026-11-16: fixed window height, longer pages scroll; the page for the
  addon's own settings is called "Settings" (internally `general`); tagline and
  tab description say what the player finds there, no technical notes. Options of a feature
  (`child`) sat indented below it and folded while the feature was off; since 2026-11-25 they
  belong to its entry in a settings tab (see "Settings tabs"); the search shows them in full.
