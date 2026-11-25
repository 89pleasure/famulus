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
  the three categories as the first card "Features" under Settings › General
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
  sidebar (fading gradient, glowing bar, counter on an accent badge), card of a
  running feature (fine accent border, mark on the left), field with focus (ring), logo. In addition,
  as a signature, a soft glow in the accent colour behind the logo. Depth via a highlight edge at the
  top of window and cards and recessed option rows. Hover fades in and out (`Shape:Fade`).
  The owner's decisions on the mockup: **one** line between sidebar and content, the
  window border runs uniformly around everything; the line above an option row goes from card edge
  to card edge; option rows carry a dot, no angle and no leader line; the
  main button ("Save") has a horizontal gradient, a darker border, a light line
  inside and a shadow, but no top-to-bottom gradient (it looked "plasticky").
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
- **Cards:** In category tabs each feature has a card of its own, together with its
  options (`FeatureBlocks`, spacing `CARD_GAP`). The search still groups per tab.
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
  tab description say what the player finds there, no technical notes; options of a
  feature (`child`) sit indented below it and are collapsed while the
  feature is switched off (narrow, greyed out, value visible); the search shows them in full.
