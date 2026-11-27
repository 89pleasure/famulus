# Website

Part of the project notes; requirements, rules and the index of all files are in
[AGENTS.md](../AGENTS.md). References of the form "see X" point to a heading or a bold entry;
the index there says which file it is in.

The owner's request (2026-11-23): a website for the addon, modern, minimalist but stylish, dark
with light text, showing the features as well as possible, with modern effects such as parallax;
as background, artwork from WoW or generated artwork. The first version (2026-11-24) is in
`website/`. Structure, texts and look are the assistant's decisions and not yet confirmed by the
owner.

- **Technology:** a static page without a build step and without libraries: `index.html`,
  `styles.css`, `i18n.js` (texts), `scene.js` (landscape, parallax), `main.js` (language,
  demos), `assets/` (logo as SVG from the outlines in `tools/make_media.py`; Inter copied from
  `Famulus/Media/Fonts`, including its licence). The page makes no requests to third-party
  servers (no web fonts, no tracking). Preview: `python3 -m http.server 4173 --directory website`
  (as `website` in `.claude/launch.json`). The Windows machine has no `python3`; there
  `website-node` in the same file starts a small Node server without packages (since
  2026-11-24).
- **The look follows the addon:** the brightness ladder and the colour scheme "Lemon" from
  `UI/Theme.lua` as CSS variables (`--h`, `--s`, `--accent`, `--accent2`), accent and glow only for
  "active / here", grain, embers. All colours, including those of the landscape, hang on these
  variables. The page remembers the language in the browser (`localStorage`).
- **"Under the hood" removed (2026-11-24, the owner's decision: "Not important for now"):** the
  section with the numbers (0 game events, 0 lines per frame, 0 libraries, 2 languages), the four
  principles and the choice of the five colour schemes, together with its entry in the
  navigation. With it, the other four colour schemes have disappeared from the page
  (`:root[data-scheme]` in `styles.css`, `setScheme` in `main.js`); the page does not need a
  colour scheme choice (owner, 2026-11-24). For reference: Git history up to commit `a750f8d`.
  Do not build it back in without asking.
- **The artwork is generated, not from Blizzard** (the assistant's decision): `scene.js`
  draws a night landscape of mountain ranges, forests, two moons and a camp by the fire
  (see "Campfire in the header") as SVG layers, from a fixed seed, so it is the same on every
  visit. Reasons: Blizzard's artwork is protected by
  copyright, and a landscape of our own follows the colour scheme. Parallax: layers with
  `data-depth` follow scrolling and the mouse pointer (drawing happens only on change and only
  while the header is visible), elements with `data-parallax` drift while scrolling. The embers
  are CSS animations. `prefers-reduced-motion` switches off all motion.
- **Structure (since 2026-11-24, aliases last, see "Requirements"):** header (landscape, live
  feed cards beside the title) → the addon's window as a screenshot (see "Window in the header") →
  01 Chronicle (the picture book with the tabs Everyone, My journey, Companions) →
  02 Fellow travellers → 03 Live feed (can be triggered, position can be moved) → 04 Aliases (the
  window rebuilt and usable, below it chat and tooltip "in game") → 05 Screenshots ("What Famulus
  looks like in the game", since 2026-11-27, see "Gallery") → 06 Installation → 07 Help (see
  "Help") → footer with a note on Blizzard's trademark. Tinted background (`section--tinted`) and
  glow still alternate from section to section; the campfire of the foot (`section--last`,
  `#scene-foot`) stands behind the last section, since 2026-11-27 the help instead of the
  installation. The skip link and "What it does" lead to the chronicle (the arrow in the
  header has been gone since the window in the header).
  Before: 01 Aliases, 02 Chronicle, 03 Fellow travellers, 04 Live feed. The demos show invented
  people and the samples from `/fam chronicle demo`, with our own drawings instead of
  game icons. An alias from the aliases demo also appears in the picture book, in the
  live feed banners and in the fellow travellers.
- **Fellow travellers (2026-11-24, the owner's request; structure, texts and data decided by the
  assistant, not yet seen by the owner):** Like the overview in the addon
  (`UI/Fellows.lua`), but without a window frame, so that the section does not depend on the
  rebuilt window: three tiles "Closest companions" (rank, crest with ring, name in the
  book font, bond, numbers, footer), below them "Everyone else" with a choice of
  sort order and a list. A click opens "Your story": on the left the profile card with the ladder
  of the bond, on the right the book of the days together ("Together on the road", bosses, "You
  are now …", "Met"). `main.js` computes tiers and milestones like
  `FellowService.Tier` and `Milestones`. The crest shows the initial in the
  class colour instead of a class icon (no graphics from Blizzard). "Set alias"
  fills in the aliases window, "In the chronicle" (only for Mira and Borin, who have entries)
  filters the chronicle's book. The people: Mira, Borin, Kaelric (Papa) and Yorick
  from the page, plus Lysa and Ena from `/fam fellows demo`; times and days match the page's
  chronicle. Difference from the addon: the card says "last …" only once (in the addon it is
  under the name and once more at the bottom).
- **Adapted to the new window structure (2026-11-24, the owner's request; the details of the
  implementation were decided by the assistant, not yet seen by the owner):**
  - **Window:** as in the addon, a header with the logo, the three areas as tabs with a counter
    (Chronicle, Fellow travellers, Aliases; only Aliases usable), "Settings" and "About" on the
    right; sidebar with search, name and description of the aliases, master switch, the
    sub-areas "Names" and "Settings" and "x of 10 active"; in the content the title of the
    sub-area and "Reset" with a confirmation (only on "Settings"). Because the header needs width,
    the window spans the full page width and the game view (chat on the left, tooltip on the
    right) sits as a strip below it, no longer beside it. Narrower: below 1080 px only icons for
    "Settings" and "About", below 900 px one column (sidebar as a strip below the header), below
    680 px only the selected area with its name. The limits 900 and 680 are chosen so that the
    header fits into the window in English and German (measured 2026-11-24).
  - **The window lagged behind the addon (2026-11-24 to 2026-11-27):** it showed the
    intermediate state with tabs in the header, master switch in the sidebar and "x of 10
    active"; the owner's decision then: only catch up once the window in the addon has settled.
    Caught up on 2026-11-27 (the owner: go on with the steps of #50), see "Aliases window"
    below.
  - **Chronicle:** chapter head on one line, repetitions bundled (for that, yesterday's sample
    data has three deaths in Uldaman and two levels for Borin), beside it the rail as in the
    addon (Everyone: week and companions; My journey: week and professions; Companions:
    profiles). A click on a companion filters the book. Below 980 px the rail sits between the
    tabs and the book. The chapter head is built as in the addon (`TitleChapter`) from the shown
    events (`chapterHead` in `main.js`): zone of the most events, levels only from your own.
- **Review 2026-11-24** (a pass in the browser and in the code, released by the owner to be
  worked through): fixed are the chapter heads when filtering, two wordings for the same
  find, contradictory sample data (Mira was already 40 yesterday; the level in the live feed
  banner now belongs to Kaelric), the principle "Errors stay small" (only an error while
  enabling switches a feature off) and step 2 of the installation (restart instead of `/reload`,
  because a new addon folder might otherwise not be found; not checked in game, the README has
  said the same since 2026-11-24). Also: live feed banners and embers only run while they are
  visible; "reduced motion" also takes effect when it is switched on only during the visit; tabs
  with arrow keys; focus stays when deleting an alias and on "Show all"; the position of the
  live feed banner can be moved with the arrow keys; triggered banners are read
  aloud (`#feed-said`); `color-scheme: dark`. Left open (taste, not changed):
  336 px spacing between two sections.
- **Campfire in the header (2026-11-24, the owner's request):** Forever has a new
  game element: players sit down together at a campfire and get buffs. That is now the
  motif of the header image, in the previous style (drawn, not a screenshot). Out of four variants
  ("Distant embers", "By the fire", "Against the moon", "By the lake") the owner chose
  **"Against the moon"**: a group on a hilltop as a silhouette against a large moon. The other
  three and the switcher bar were removed again (never committed). The owner's criticism of the first
  version: too little WoW character, too little flora and fauna, the figures looked like
  jointed mannequins (they were built from joints with strokes of equal thickness). Reworked; the
  details of the implementation were decided by the assistant, the owner has seen them and had
  them committed (2026-11-24):
  - **Figures** are drawn silhouettes made of parts (`FIGURES` in `scene.js`: smooth
    outlines, tapering limbs, heads in profile): a group of four with a pet,
    recognisable by their gear, not by their race, so that no faction is left out (Horde and
    Alliance do not play together in Forever). Mage (pointed hat, beard, staff with a glowing
    crystal, standing), warrior (horned helmet, spiked pauldron, beard, tankard towards the fire,
    axe in the ground), huntress (long ears, hair, bow and quiver on her back) with a wolf,
    rogue (hood, cloak). Plus a tent with light inside and a saddled horse (Forever only has
    ground mounts).
  - **Level campsite (the owner's criticism):** Tent and horse stood tilted on the slope, and
    the horse looked like a donkey. The hilltop is now exactly level between `plateau.from` and
    `plateau.to` and only rounds off after that (`edge`). Everything that stands there must stay
    within this range. The horse now has a curved neck, a long head, small ears,
    a mane, a long tail and a rein, but no saddle blanket any more.
  - **Flora and fauna:** an old broadleaf tree next to the moon, with an owl with glowing eyes
    sitting on its branch. **The owl blinks** (the owner's request, 2026-11-25: both eyes, not a
    wink with one; the rhythm is the assistant's decision): both eyes shut to a slit of light for
    about a third of a second, in a 12-second cycle once and, about 6 seconds later, twice in a
    row (`.blink` in `styles.css`; in `scene.js` a `glow` can carry a class as its fifth field).
    The first blink comes about 2.5 seconds after loading; it pauses with the other motion while
    the header is out of sight. Checked in headless Chrome at 1440 and 375 px (open, single blink,
    both blinks of the double; off with reduced motion).
    Broadleaf trees between the pines (`trees.broad`), bushes (`bushes`),
    tufts of grass (`grass`), a stag, bats flying across the moon, fireflies.
    Two moons, a large white one and a small blue one, as on Azeroth.
  - **Fire:** the logo's flame, flickering via CSS; highlight edge on the figures towards the fire.
    Motion only via CSS (flame, bats, fireflies, embers), `prefers-reduced-motion`
    stops everything.
  - **Narrow screens** (one column, up to 980 px): The drawing becomes smaller, sits below
    the text (its own space, `padding-bottom` on the header) and is shifted so that the camp is
    centred (`FamulusScene.pan`). Otherwise it lay off to the right and the moon behind the
    buttons.
  - **Live feed cards above the moon (since 2026-11-27, the owner's request):** in the hero's
    second column (`.hero__feed`), top-aligned with the title, the cards left-aligned as in the
    game (centred they looked wrong to the owner) in a box of 340 px (the widest card) in the
    middle of the column; the stack grows down towards the moon. The column's middle lies about
    over the moon's
    (measured at 1440 × 900: 1058 against 1063 px; three cards end at about 346, the moon
    starts at 375; at 1280 × 720 the third card touches the moon's top). Hidden in one column
    (up to 980 px). From 2026-11-24 to 2026-11-27 they lay over the window's screenshot, where
    they looked out of place.
  - Checked in the built-in browser and with headless Chrome at 375, 768, 1280, 1440 and
    1920 px width, German and English; no messages in the console. Not checked: Safari,
    Firefox, real mobile devices.
- **Window in the header (2026-11-24, the owner's request, modelled on polestar.guide):**
  Below the campfire there is a screenshot of the addon window (`figure.shot`, first element in
  `<main>`). It reaches up into the header from below (below 980 px only 40 px, because there the
  camp sits below the text), fades out towards the bottom (mask) and has rounded corners via CSS
  (12 of 1180 × 730).
  - **Pulled higher (2026-11-24, the owner's request):** The header text sits at the top,
    72 px below the navigation (`padding-top: 140px`), instead of centred (before about 65 px at
    1440 × 900; 36 px was too little for the owner). The window reaches as far into the header as
    `--lift` says (`clamp(150px, 22svh, 240px)`); the text keeps `--lift` plus 40 px
    free below it, so that the window never covers it. The owner did not want the background
    touched. Measured at 1440 × 900: in both languages the window starts at 702
    instead of 756 px, at 1920 × 1080 at 842 instead of 912 px. 60 to 95 px remain to the fire.
  - **The title has two lines in every language** (the owner's requirement, 2026-11-24). The
    line break is in the text (`<br>` in `hero_title`: "For everyone / you play with.", German
    "Für alle, mit denen / du spielst."; before the `<br>` there is a space, otherwise screen
    readers read "denendu"), and the font shrinks until the longer line fits into the
    text column: `font-size: min(<as before>, var(--title-fit))`, with `--title-fit` per
    language in container units (`cqi`, the text column is the container): English 15.5cqi
    (never applies, the lines fit anyway), German 11.9cqi ("Für alle, mit denen" is 8.2 em
    wide). A new title or a new language needs its own value, about 97 divided
    by the width of the longer line in em. Before, the German title broke onto
    three lines at 1440 px and stretched the header to 941 px. Checked from 320 to 1920 px width
    in both languages: two lines, nothing overflows. German is smaller as a result (76 instead of
    90 px at 1440 × 900, 40 instead of 43 px on a phone).
  - **Screenshot instead of a rebuild** (the assistant's recommendation, chosen by the owner): It
    is the real addon, and an image is quickly swapped while the window is still changing;
    Polestar shows screenshots there too. Consequence: game icons and the game's book font
    are visible in the image; until then the page showed no graphics from Blizzard.
  - **One English image for both languages** (the owner's decision, 2026-11-24:
    "English is enough"), in two widths: `assets/shots/window-<1180|1770>.webp`. Only the
    alt text changes with the language (`shot_alt` in `i18n.js`, the German one with the addition
    "englische Fassung" ("English version")).
  - **Producing it:** `node tools/make_shot.js <screenshot> <x> <y> <width> <height>
    website/assets/shots/window` cuts out the window from its outer hairline
    and writes WebP at full width and at 1180; headless Chrome decodes, scales and
    encodes, otherwise only Node is needed. The edges can be found at the hairline (brightness
    about 48 against 10 to 20 next to it; on the Windows machine measured via PowerShell with
    `System.Drawing`). Capture in 4K, then the window is about 1770 px wide.
  - **For the capture:** client and Famulus in English (otherwise item and class names stay
    German, see "Sample entries"), then `/fam chronicle demo` and
    `/fam fellows demo`.
  - **State (since 2026-11-27, the owner's choice of three):** Chronicle › Everyone, from a
    screenshot on the Mac (`Bildschirmfoto 2026-11-27 um 15.35.00.png`, 5120 × 2880, client and
    Famulus in English, sample data). The window is 2832 × 1752 at x 1170, y 410 (2.4 times its
    1180 × 730; edges found on enlarged crops of the corners with `sips`), written at 1180 and
    1770 as before. Visible in it: the owner's character "Kip Blütensturm" (strips, "This week";
    the owner: fine) and the route "Gasthaus Seenhain › Lakeshire Inn", the same inn in German and
    English, because entries from a German client mix with English ones. Before: the screenshot
    `WoWScrnShot_112426_221759.jpg` of 2026-11-24.
  - **Taking screenshots on the Mac:** the game's own key writes nothing there
    (`_forever_/Screenshots` does not exist); the owner uses macOS's own (Cmd+Shift+3), which
    lands on the desktop as `Bildschirmfoto <date> um <time>.png`. The window stood at the same
    place in every shot of 2026-11-27, so one frame fits them all.
  - Nothing lies over the window (the live feed cards stand above the moon, see "Campfire in the
    header"). The glow of the first section may reach up into the window's fading foot
    (`.shot + .section`), otherwise there was a hard edge there.
  - Checked in the built-in browser at 1440, 1024 and 375 px, German and English; no
    horizontal scrolling. Structure in detail: the assistant's decisions, not yet seen by the
    owner.
  - The demos' people have the English names of the addon's samples in both languages since
    2026-11-27 (Mira Stormfeather, Borin Ironbeard, Lysa Morningdew, Ena Silverbrook), so they match
    the English screenshot; Kaelric, Thessa and Yorick exist only on the page.
- **Gallery "Screenshots" (2026-11-27, the owner's request: "header and gallery"; layout and
  captions the assistant's decisions, not yet seen by the owner):** section 05 between the
  aliases and the installation, two columns (one below 760 px), each picture a link to its
  large version in a new tab, a caption below (`sh_<name>`) and its own alt text
  (`sh_<name>_alt`). Pictures (`assets/shots/<name>-<width>.webp`, cut with
  `tools/make_shot.js` from the same screenshots): `fellows` (Overview, 15.35.04), `story`
  (Mira, 15.35.17), `groups` (15.36.03), `feed` (`/fam feed test` over the game world, 15.44.25,
  2233 × 1380 at x 1418, y 60, the window's shape and about the same scale as the window shots;
  the first crop, 1110 × 687 at x 1980, y 230, was blown up past its size in the slider and the
  cards looked too large, the owner noticed), `welcome`
  (expanded, 15.37.59), `aliases` (Aliases › Settings with the chat picture, 15.38.29); all at
  1180 and 1770, about 40 to 100 KB each, loaded lazily. Not used:
  "Nearby" and Chronicle › Friends filtered to one person, because they show real Battle.net
  friends; the game world around the window, because it shows other players' names. No entry in
  the navigation. Checked at 1056 and 375 px, English and German: all six load, no horizontal
  scrolling, no console messages (a `figure` keeps the browser's margin of 40 px unless set to
  0; it did at first).
  - **A slider instead of the grid (2026-11-27, the owner's request: "one screen and an
    auto-scroll slider, then the picture can be larger"; details the assistant's decisions):**
    one screenshot at a time at the full width of the page (up to 1180 px, the 1770 version on
    sharp screens), its caption below it inside the frame. It moves on by itself every six
    seconds (`EVERY` in `main.js`); the shown dot fills up over that time. It stands still with
    reduced motion (and the pause button is hidden then), while paused by the button, while the
    mouse or the focus is on the slider, while it is less than 40 % on screen and while the tab
    is in the background. Two large arrows left and right of the picture, outside the content's
    width in the page's margin (the owner's request after two versions: small ones below, then
    on the picture's edges), level with the picture's middle through container units on
    `.slider` (`30.9cqw`); below 1400 px, where the margin is too small, they sit on the
    picture's edges. The dots and pause below, the arrow keys and a sideways swipe move it too;
    a slide
    chosen by the reader is read out (`aria-live` polite), one that moves on by itself is not.
    The other slides are `inert`. No link to the large picture any more (the picture is large
    now, and a link would fight the swipe). Checked at 1440 and 375 px, English and German:
    moves on after six seconds, arrows, dots and pause, no horizontal scrolling, no console
    messages.
- **Help (07, since 2026-11-27):** "Questions around the campfire": on the left ten questions
  as an accordion (`details`, keys `hp_q_*`/`hp_a_*`), grouped under Getting started, Friends &
  privacy and In the game; on the right a panel that stays in view while they scroll past
  (`position: sticky`; below 980 px it follows the questions): three steps to `/fam report`, the
  main button to a new issue with the template `bug_report.yml` (no hint on `/fam dev` below it:
  the page does not advertise developer mode), and links to an idea, a question (new issue with the label `enhancement` or
  `question`) and the open issues. No number of open issues: the page asks no other server.
  **Open:** GitHub only sets a label from the link for people who may label issues, so a
  stranger's idea or question arrives without one; templates of their own (like
  `bug_report.yml`) would fix that. The answers come from the code and the docs, not from the
  game; what they name (commands, languages, what is sent, the game version) has to follow the
  addon. They name no commands for sample data (`/fam … demo`, `/fam feed test`), and the
  answer on friends says that Famulus is at its best when friends use it too, with the live
  feed as the reason. Not in the navigation. Links inside running text get a line (`.release p a`, `.faq__a a`); the
  page's links are bare otherwise, so the issue link in the release box looked like plain text
  until then. Built from three variants (accordion with cards below; this one; topics as tabs
  with the links in a larger footer). Checked at 1440, 820 and 375 px in English and German: no
  horizontal scrolling, no console messages, every key in both languages.
- **Languages:** English is in the HTML (`data-i18n="key"`), German in `i18n.js`; what
  scripts put together is there in both languages. **English is the default** (the owner's
  request, 2026-11-25; before that the page followed the browser's language, so a German
  browser got German). German only comes up when the reader switches to it (remembered in
  `localStorage`) or with `?lang=de`. If a language lacks a key, the console warns.
- **Hosting (2026-11-24):** The owner's request: straight from GitHub, without a server of our own
  and without manual work, with a custom domain. Because the repo is public, GitHub Pages (free):
  `.github/workflows/website.yml` publishes the folder `website/` unchanged as soon as a
  push to `main` changes something in it; manually via Actions › Website › Run workflow. Once per
  repository: Settings › Pages › Source "GitHub Actions". The owner gets the domain;
  it is entered under Settings › Pages › Custom domain (with the workflow no `CNAME` file is
  needed), and at the DNS provider A and AAAA records pointing to GitHub for the domain without
  `www`, a CNAME to `89pleasure.github.io` for `www`. Without a domain the page is at
  `89pleasure.github.io/famulus/`; that works because all paths are relative. GitHub sees the
  visitors' IP addresses, that belongs in the privacy policy. Since 2026-11-25 two jobs, build
  and deploy, as in GitHub's own Pages workflow: in one job `deploy-pages` twice looked for the
  artifact before GitHub listed it ("Found 0 artifact(s)"), and re-running the failed job uploaded
  a second one ("Multiple artifacts"). If a run fails, re-run the whole workflow or start it by
  hand, not only the failed job.
- **Version on the page (2026-11-25, the owner's request: "should show the current release
  version"):** `fact_version` and `in_rel_d` say "Version <x>" in both languages. When
  publishing, `website.yml` replaces every "Version <x.y.z[-alpha|beta.n]>" in `index.html` and
  `i18n.js` with the newest release tag by version, wherever it sits (`git tag --sort=-v:refname`
  with `versionsort.suffix=-`, so alpha and beta come before their release; without the "v"),
  and fails if a file then does not name it. Until 2026-11-25 it took the newest tag on `main`
  (`git describe --tags`); `v0.1.0-alpha.4` was set on the branch of its pull request instead of
  the squash merge, so the page went on showing alpha.3 after the release (since then the Release
  workflow also refuses a tag that is not on `main`, see "Publishing on CurseForge"). The workflow
  also runs after every release that succeeded and uploaded (`workflow_run` of "Release", event
  `push`; dry runs by hand do not count) and then
  publishes `main`. Until 2026-11-25 it ran on the tag itself; that would have failed, because the
  environment `github-pages` lets only the branch `main` deploy (read from the repo settings).
  In the repo the texts carry the last release by hand
  (`0.1.0-alpha.6` since 2026-11-27), only so that the local preview is right. A new text with the version must
  keep the form "Version <x>". The assistant's decision; the replacement ran on GitHub on
  2026-11-25 ("Version 0.1.0-alpha.2"), a run after a release has not happened yet.
- **Download (2026-11-25, the owner's request):** The buttons in the navigation and the header
  say "Download" instead of "Install"/"Installation" and scroll down to the section
  "Installation" (the owner's request, 2026-11-25; before that they led straight to CurseForge).
  Only the button in the release box there leads to `www.curseforge.com/wow/addons/famulus`, in a
  new tab (project verified on CurseForge, not yet listed publicly as of 2026-11-25). The project page,
  not a direct file link (the assistant's recommendation, the owner agreed): it always shows the
  newest file, offers the CurseForge app as well as the zip, and a file link would change with
  every upload.
- **Head and link previews (2026-11-25, the owner's request to check the metadata; details the
  assistant's decisions):** The description is at most about 155 characters in both languages
  (Google cuts longer ones). Open Graph and `twitter:card` (`summary`) tags make a card in
  Discord, Reddit and messengers; their crawlers run no scripts, so these tags stay English while
  title and description switch with the language. `favicon.ico` (32 px, for browsers without SVG
  icons) and `apple-touch-icon.png` (180 px) lie at the root of `website/`, scaled with `sips`
  from `docs/curseforge/logo.png`; the SVG logo stays the main icon. `<meta name="color-scheme">`
  keeps the page dark before the CSS loads. **Once the domain exists:** add
  `<link rel="canonical">`, `og:url`, `og:image` (needs an absolute URL and a preview image,
  1200 × 630) and `hreflang` alternates for `?lang=de`; until then search engines see only the
  English page.
- **Deliberately not included yet:** Guildy (only once the PR there is accepted), legal notice and privacy policy (needed before
  publishing), the domain (the owner gets it), a preview image for shared
  links (see "Head and link previews"), WOFF2 fonts (the TTFs from the addon are loaded, ~100 KB
  each).
- **Checked** in the app's built-in browser (Chromium): at 1440 and 375 px width all
  sections, at 1024 and 680 px by spot checks; German and English; the colour schemes Lemon,
  Mint, Rose and Lilac; the three demos used; no messages in the console. Not checked:
  Safari, Firefox, real mobile devices, the reduced motion setting. After the adaptation to
  the new window structure (2026-11-24) again at 1440, 1024, 768 and 375 px: window and chronicle
  used (sub-area, switches, Reset, master switch off, chronicle tabs, filter),
  German and English, no messages in the console; colour schemes not this time. After the
  review (2026-11-24): window header re-measured at 375 to 1081 px in both languages, tabs via
  keyboard, focus, reading aloud and moving checked by script. "Reduced motion" could not be
  switched on in the app's browser and is still unchecked. The fellow travellers (2026-11-24) at
  1440, 1024, 768 and 375 px in both languages: tiles, list, sort order, opening
  and closing the story (focus returns), "Set alias", "In the chronicle"; no messages in the
  console, no horizontal scrolling.
- **Texts brought up to date (2026-11-27, issue #50, first step; the owner chose "texts first"):**
  the chronicle's people are "Friends" (tab, rail, texts), a chapter is a play session, reactions
  in the chronicle and the live feed, "Who is nearby" and whispering in the fellow travellers' lead,
  the welcome page in step 3 of the installation. The release box no longer says "alpha" or "beta"
  (the owner's choice: a wording true before and after `v0.1.0`, because the page goes live with
  every merge) and points to `/fam report` and the GitHub issues. Still behind the addon then:
  the demos (since caught up, see "Demos" below, except the aliases window) and the screenshot in
  the header (the owner sends a new one). Installation names
  the CurseForge app since the copy review the same day (see below).
- **Copy review (2026-11-27, the owner's request: a review "as an experienced marketing guru"
  by a subagent; the owner had everything applied):** the hero lead tells what Famulus does in
  concrete terms; the fact chips say "Addon in five languages" (the page itself has only EN/DE)
  and "Friends & guild only" instead of "No libraries" (shortened so the chips stay on one row
  at 1440 px); chronicle point 1 "Shared with your friends" instead of "Famulus talks to
  Famulus", with friends without Famulus showing up via "Follow my friends"; point 2 says that a
  mutual friend's Famulus passes on news of a friend who is offline (as `docs/sharing.md`); point 3
  ends on privacy instead of aliases; the fellow travellers' second point is "Who is nearby"
  (the old "Your story together" repeated the lead); the aliases open with a scene ("Grimtusk"
  is Tom); "Famulus adds to Blizzard's interface without replacing anything" instead of
  "Blizzard's interface stays untouched"; installation names the CurseForge app first (the
  owner: fine before `v0.1.0`, nobody knows the page yet); German nav "Live-Einblendung" like the
  section; meta descriptions 150 (EN, also `og:description`) and 148 (DE) characters. The
  CurseForge description got the same pass. Not taken: the search label in the window demo
  stays "Search settings" / "Suchen", as in the addon. Checked at 1440 and 375 px in both
  languages: no horizontal scrolling, no console messages; on a phone the chips wrap to two rows
  as before.
- **Demos (2026-11-27, issue #50, second step; the owner: "go on with the demos"; details the
  assistant's decisions, not yet seen by the owner):**
  - **Chronicle:** a chapter is a play session: on the left from when to when, the title by the
    time of day (`sessionTitle`, as `SessionTitle`: all `c_when_*` and `c_weekday_*` keys of the
    addon; an older session is named after its weekday, its date on the left), on
    the right levels and events, below it the route of your own zones as badges with chevrons
    (`chapterHead`). The cards as `UI/ChronicleCard.lua`: a sunken strip with whose event it
    is ("Alias (Name)", `labelOf`; your own character is "Tamsin Ashgrove", `ME`) and the time
    (a bundle its first and last), picture and text, the place in the foot with the reaction at
    its right. Weights as `WEIGHT` in `UI/Options.lua` (`weightOf`): light 80 %, medium 90 %,
    heavy 100 % of the column, a narrower card hangs on the line; picture 40/48/56 px; glowing
    dots of 5/7/9 px instead of icons on the line (in the fellow travellers' book too). The
    sentences have no place (`c_death_nowhere`, `c_zone_nowhere`, `c_deaths_nowhere`).
  - **Reactions:** the icons `i-sad`, `i-cheer`, `i-strong`, `i-clap` are the drawings of
    `tools/make_media.py`, ported to SVG with the same points. A friend's card has the button
    (muted, lit after a click, a second click takes it back; a bundle reacts to its newest);
    your own card shows the number and, on the mouse, who (`from` on an entry; the level 40 has
    three, a death yesterday one). Today's sample data gained your own death in Feralas at
    18:40, so the route has two stops.
  - **Live feed:** cards in three rows as `UI/Feed.lua` since #64: whose (with a glowing dot,
    none for your own), what (without place), where and the rest; 64 or 76 px tall, 230 to
    340 px wide, slots 84 px apart; a friend's card has the reaction button at its right end
    (a click lights it and the card goes a second later); a line along the foot runs out over
    the card's time; the mouse on the card holds it, leaving lets it go 1.5 s later.
    **Rows as since #75 (2026-11-27, the next step after the gallery):** only the newest card is
    large; the ones before it are slim rows below it (34 px, a 24 px crest, "whose · what" on one
    line, your own under your character's name, the reaction at 24 px), the newest on top, a
    fourth pushed out (`arrange` in `main.js`). Cards that come faster than 1.2 s apart (`STEP`,
    as in `UI/Feed.lua`) wait, and the top card counts them in an accent badge ("+2"). Not
    built: the edges of the waiting cards behind the top one, keeping the last three
    (`SetKeep`), and the faster pace with three waiting. The feed's room is 170 px (a tall card
    and two rows). Checked at 1056 px: four chips in a row count +3, +2, +1 and stack
    the rows; the header's cards play on their own.
  - **Fellow travellers:** tabs "Overview" and "Nearby" above the demo (`#fellows-tabs`). Nearby
    as `UI.NearbyList`: "Here in Tanaris", "Similar level" (up to 5 apart) and "Also online",
    rows with crest, name and below it name, class and where from, level with the difference to
    yours (40), zone (yours in the accent), bond, whisper; a fellow traveller's row opens the
    story. A new person only there: Garrick Stonehand, guild, level 22 in Westfall. Speech
    bubbles (`i-chat`, from `tools/make_media.py`) on the tiles, the rows and the person's card;
    on the page a click says in the hint below the demo what the game would do (`#fw-said`).
    The card's buttons are square icons in a row: in the chronicle (flag), set alias (tag),
    whisper (40 px, accent). "Your story" by sessions like the chronicle (the owner noticed it
    in the preview): title by time of day, on the left from–to or the date, on the right the
    time together; the stretch card is "On the road in <zone>" with "18:50 to 21:15" (no
    duration, as in the addon). A day of the log is one session, as in the addon. Not built:
    "Forget", the card of Nearby, "Where your people are", the tab "Groups".
  - **Class colours (2026-11-27, the owner's request after the addon's #83):** a class named in
    the fellow travellers' tiles, list, the person's card and the rows of Nearby stands in the
    addon's muted colour (`.cls--<class>` in `styles.css`, the values of `class<FILE>` in
    `UI/Theme.lua`; `classWord`, `levelClass` and `joined` in `main.js` build the line as nodes).
    The game's tooltip below the aliases window keeps the game's look. The page has nobody out of
    reach, so no faction colours. Checked at 1440 and 375 px, English and German: colours, the
    rows still cut with "…", no horizontal scrolling, no console messages.
  - **Still behind then:** the aliases window and the screenshot; both caught up the same day.
  - Checked in the built-in browser at 1440 and 375 px, English and German: book (positions of
    cards and dots measured), live feed (three cards), Nearby, the story's buttons, whisper;
    no horizontal scrolling, no console messages.
- **Aliases window (2026-11-27, issue #50; built after the owner's screenshot of Aliases ›
  Settings, details the assistant's decisions, not yet seen by the owner):** as the window in
  the addon since 2026-11-24 (see "Layout" in docs/window.md): a head across the top (logo and
  name, then the area "Aliases" with its line, close), a sidebar that is the same on every page
  (search, Chronicle, Fellow travellers, Aliases with the glowing bar, below a line Settings and
  About; only Aliases works), and in the content the tabs "Names" and "Settings" with a line
  under the chosen one and "Reset" (on Settings only, asks first). Settings is a gear at the
  right end with its name as `aria-label` and `title`, Reset to the left of it (placed absolutely,
  as it stands outside the tablist), as in the addon since 2026-11-27. The master
  switch, the counters ("5/5", "6 of 10 active") and the tab's title and description are gone,
  as in the addon (`state.master` stays on). Settings is a list of the features (`ALIAS_FEATURES`
  in `main.js`: chat, tooltip, menu, Battle.net characters; Guildy left out as everywhere on the
  page), each with its icon (`i-chat`, `i-tooltip`, `i-menu`, `i-link`, from
  `tools/make_media.py`), name, "On · 1 option" and its switch, and beside it the chosen one in
  full: area, name, switch, "On" and "Default: on", description and, for chat, the option
  "Display". No live picture: the game view below the window shows the effect. "Characters of
  Battle.net friends" switches nothing else in the demo (in the addon it only stops learning new
  characters). Below 900 px one column with the areas as a row (search, Settings and About
  hidden), below 680 px only the active area keeps its name and the settings stack. Checked at
  1440, 1024 and 375 px, English and German: switches in the list and in the detail change the
  chat and the tooltip, "Display" too, Reset asks and resets, no horizontal scrolling, no
  console messages.
- **Keep in step with changes to the addon:** the screenshot in the header as soon as the window
  visibly changes; the aliases' features in Settings (`ALIAS_FEATURES` in `main.js`), new main
  features as entries in the window's sidebar and as their own section with an entry in the
  navigation; the bond tiers (`TIERS` in `main.js`) like `FellowService.TIERS`; the answers of
  the help (`hp_a_*`) when a command, a language or what Famulus sends changes.
