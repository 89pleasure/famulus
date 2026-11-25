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
  - **Sidebar:** search at the top, below it the main features as entries with an icon
    (`navButtons`; a switched-off one greyed out with "OFF"; selected entry: fading gradient, glowing
    bar), at the bottom after a line "Settings" and "About". The former line "x of y active"
    is removed, as is the line "Active" under "About" (the owner's decision,
    2026-11-24: it dates from the time of the many QoL features). The active/total counters on the
    entries are removed too.
  - **Content:** at the very top the page's sub-areas as tabs (`window.tabs`, 48 high, stroke with
    gradient under the selected one), "Reset" to the right of them. A page with only one
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
  tabs "General" (language, feedback in chat, minimap icon, character profile) and "Appearance"
  (colour scheme, embers, window size). The first page on opening is the first in the sidebar,
  so since 2026-11-24 the chronicle (before that the aliases).
- **Master switch** (since 2026-11-24, the owner's decision: "Only the master switches"):
  the three categories as the first entries, under the heading "Features", in Settings › General
  (`CategoryItem`, texts `area_<id>` and `area_<id>_desc`). The switches of the individual features
  stay on their tabs. If a category is off, its entry in the sidebar is greyed out and carries
  "OFF", its tabs are greyed out, and instead of the content its page shows
  a notice with the button "Switch on in settings" (`window.offNotice`), which
  opens Settings › General.
- **Reset** acts on the tab (features of the whole section, addon options only their
  key; on Settings › General also the three master switches). The first click asks
  ("Really reset?", red), a second within four seconds carries it out; greyed out on
  default values; not present without settings (list of aliases, "About") and on a
  switched-off page.
- **Search:** in the header, across all pages and tabs, hits grouped per tab in cards ("Aliases ·
  Settings"); no tabs in the results view. It leaves out the content of a switched-off feature,
  but finds its master switch. On a page without a sidebar the
  hits take the full width.
- **Colours (reworked 2026-11-18, evening):** The owner found the first version (neutral
  greys, accent only as a fill) too arbitrary. Role models for colour concept, accents and effects:
  Polestar Guide and Mastercraft, without copying them. On an HTML mockup the owner chose the concept
  **"Lemon"**: petrol surfaces, lemon-yellow accent. Since then a colour scheme (`general.accent`,
  list `UI.accents`) is a whole concept and no longer just an accent colour: it tints
  all surfaces with its hue (`hue`, `saturation`; the brightness ladder `ladder`) and brings
  an accent as a colour pair (`accent` → `accent2`) for gradients. Available: `lemon` (default),
  `mint`, `rose`, `lilac`, `amber`. Seen and confirmed in game by the owner is `lemon`;
  the other four come from the mockup.
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
  General and Appearance) shows, instead of cards of rows (`Render` → `RenderSplit`):
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
    kinds of events form a group ("kinds"; the icons of the chronicle's cards, except flag for
    level-ups and horseshoe for abilities, so that they differ; reactions show `cheer`).
  - **Options of a switched-off feature** stay in full but greyed out, with "Switch on "…" to
    change its options." The folding of option rows (`compact`), their dot and recessed ground,
    `FeatureBlocks` and the accent mark on feature cards are gone.
  - **Pictures (`UI/Previews.lua`, since 2026-11-25 as a trial):** no screenshots but small
    scenes drawn live, so that a change to the addon needs no new picture. A feature names its
    scene (`preview = "feed"`); the detail shows it above the name on a stage of 536 × 196 px
    inside the padding (`UI.Previews.Stage`, clips its scenes). A scene is built the first time it
    is shown and kept; it uses the addon's own building blocks and the chronicle's sample people
    (`ChronicleService.SamplePeople`, `ChronicleService.Sample(kind)`), so it follows switches,
    options, colour scheme and language. Pointing at a chip focuses it on that option
    (`UI.Previews.Focus`, the option's key). What moves does so by the client's animations,
    stopped while the scene is hidden. Without a scene the detail starts with the page's name.
    - `feed`: the live feed's own cards (`UI.Feed.Card`, `UI.Feed.Fill`; never on screen) with
      Mira's level and Borin's boss over the night sky, their running-out line (see "Live feed"
      in `docs/chronicle.md`) looping over the chosen duration, below them "Visible for 7
      seconds". Pointed at a kind, a card of that kind (reactions via
      `liveFeed.ReactionStory`), faint while the kind or the feature is off.
    - `chat`: four lines in the game's chat font (`UI.SetChatFont`, `ChatFontNormal`) and its
      default colours (tokens `chatGuild`, `chatParty`, `chatSystem`); Borin under the alias
      "Dad"/"Papa" as `AliasService.Format` writes it with the chosen style, framed in the
      accent, also in the online notice. Switched off: his name.
    - The night sky (`World`), after the website's (`website/scene.js`, `styles.css`): a rounded
      gradient (`skyTop` into `skyLow`, a dusk with a little accent), 46 seeded stars of which
      about a fifth twinkle (alpha animations), and Azeroth's two moons: a large one at the right
      (rim `moonRim`, brighter towards the top left `moonMid`, `moonCore`, glow `moonHalo`,
      `moonGlow`) and a small blue one at the top left (`moonBlue`). All from `circle.tga` and
      `shadow.tga`; the tokens follow the colour scheme, as on the website. Stars and glows stay
      clear of the rounded corners (the stage clips square).
    - The chat's three texts of a line meet top to top: anchored by their middles, an empty text in
      front (the online notice starts with the name) pulled the name into the line above.
    - The mockup has scenes for every entry (tooltip, context menu, Guildy, Battle.net, minimap,
      book cards, fellow traveller, colour schemes, embers, window size and more); not built.
  - **Icons of the entries** (added on 2026-11-25 after the owner's first look in game: "the
    icons are missing"): a feature names its own (`icon` in `ns:NewFeature`, a name from
    `UI.media`; the test checks that every feature has one the window knows), the addon's own
    settings theirs in `GENERAL_ICONS` (`UI/Options.lua`), the master switches the area's icon,
    tidying up `trash`. Thirteen new line icons, drawn like the others in `tools/make_media.py`
    (`ICONS` there): share, bell, chat, shield (Guildy), tooltip, menu, link (Battle.net), trash,
    globe (language), compass (minimap), person (character profile), drop (colour scheme), resize.
    The Windows machine has no Python; the TGAs were written by a temporary port of the drawing to
    LuaJIT (not in the repo), which redraws `tag`, `people` and `reset` byte for byte as the
    Python script wrote them. Shapes and choice of icons: the assistant's decisions.
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
  All checked against the mock only; open in game are above all `SetGradient` on image textures
  (round corners of switch, button, logo), horizontal gradients and the strength of the glow effects.
- **Shape:** round corners from quarter circles of `circle.tga` plus three rectangles (`UI.Round`,
  `UI.Card` with a hairline border); window 12, cards 10, controls 6–8. Soft shadow around
  window and menus (`UI.Shadow`, `shadow.tga`). The former gradient frame (`UI.GradientFrame`) is
  gone.
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
