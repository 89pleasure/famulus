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
- **Structure (since 2026-11-24, aliases last, see "Requirements"):** header (landscape) → the
  addon's window as a screenshot, with live feed banners over it (see "Window in the header") →
  01 Chronicle (the picture book with the tabs Everyone, My journey, Companions) →
  02 Fellow travellers → 03 Live feed (can be triggered, position can be moved) → 04 Aliases (the
  window rebuilt and usable, below it chat and tooltip "in game") → 05 Installation → footer with
  a note on Blizzard's trademark. Tinted background (`section--tinted`) and glow still alternate
  from section to section. The skip link and "What it does" lead to the chronicle (the arrow in the
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
  - **The window lags behind the addon (as of 2026-11-24):** It still shows the intermediate
    state with tabs in the header, master switch in the sidebar and "x of 10 active". The owner's
    decision: only catch up once the window in the addon has settled ("the windows will change a
    lot anyway").
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
    sitting on its branch; broadleaf trees between the pines (`trees.broad`), bushes (`bushes`),
    tufts of grass (`grass`), a stag, bats flying across the moon, fireflies.
    Two moons, a large white one and a small blue one, as on Azeroth.
  - **Fire:** the logo's flame, flickering via CSS; highlight edge on the figures towards the fire.
    Motion only via CSS (flame, bats, fireflies, embers), `prefers-reduced-motion`
    stops everything.
  - **Narrow screens** (one column, up to 980 px): The drawing becomes smaller, sits below
    the text (its own space, `padding-bottom` on the header) and is shifted so that the camp is
    centred (`FamulusScene.pan`). Otherwise it lay off to the right and the moon behind the
    buttons.
  - The live feed banners stood on the right above the moon; since the window in the header (see
    below) they lie over its lower right corner.
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
  - **State:** The image is Chronicle › Everyone, from the screenshot
    `WoWScrnShot_112426_221759.jpg` (client in English, sample data; window edges at x 1022,
    y 476, 1770 × 1095). Visible in the image: the first name of your own character ("Kip", card
    "This week") and "Level 19" in the chapter head next to the sample "Reached level 40", because
    the samples mix with the real entries of a character at level 19. Sent along by the owner and
    not yet used: Fellow travellers › Overview (`…_221819.jpg`) and Borin's story
    (`…_221836.jpg`).
  - The header's live feed banners lie over the lower end of the window's right column,
    below its friends list, where the window fades out (`.shot__feed`, `top: 70%`), like
    Polestar's second window. At 50 % they covered the friends list. There they are
    right-aligned at the window edge and reach 44 px beyond it (below 1400 px inside, below
    760 px hidden); left-aligned as in the game, they lay over the book at 1024 px.
    The assistant's decision. The glow of the first section may reach up into the window's
    fading foot (`.shot + .section`), otherwise there was a hard edge there.
  - Checked in the built-in browser at 1440, 1024 and 375 px, German and English; no
    horizontal scrolling. Structure in detail: the assistant's decisions, not yet seen by the
    owner.
  - Open: The website's demos say "Mira Sturmfeder" and "Borin Eisenbart" (German names) in
    English too; the addon's English samples have had different names since 2026-11-24 (see
    above).
- **Languages:** English is in the HTML (`data-i18n="key"`), German in `i18n.js`; what
  scripts put together is there in both languages. The language follows the browser, can be
  switched and can be forced with `?lang=de`. If a language lacks a key, the console
  warns.
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
  `i18n.js` with the newest tag on `main` (`git describe --tags`, without the "v") and fails if a
  file then does not name it. The workflow also runs after every release that succeeded and
  uploaded (`workflow_run` of "Release", event `push`; dry runs by hand do not count) and then
  publishes `main`. Until 2026-11-25 it ran on the tag itself; that would have failed, because the
  environment `github-pages` lets only the branch `main` deploy (read from the repo settings).
  In the repo the texts carry the last release by hand
  (`0.1.0-alpha.2`), only so that the local preview is right. A new text with the version must
  keep the form "Version <x>". The assistant's decision; the replacement ran on GitHub on
  2026-11-25 ("Version 0.1.0-alpha.2"), a run after a release has not happened yet.
- **Download (2026-11-25, the owner's request):** The buttons in the navigation and the header
  say "Download" instead of "Install"/"Installation" and, like the button in the release box,
  lead straight to `www.curseforge.com/wow/addons/famulus` (project verified on CurseForge, not
  yet listed publicly as of 2026-11-25). The section "Installation" stays. The project page,
  not a direct file link (the assistant's recommendation, the owner agreed): it always shows the
  newest file, offers the CurseForge app as well as the zip, and a file link would change with
  every upload.
- **Deliberately not included yet:** Guildy (only once the PR there is accepted), more screenshots from the
  game (so far only the window in the header), legal notice and privacy policy (needed before
  publishing), the domain (the owner gets it), a preview image for shared
  links, WOFF2 fonts (the TTFs from the addon are loaded, ~100 KB each).
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
- **Keep in step with changes to the addon:** the screenshot in the header as soon as the window
  visibly changes; the counters
  in the rebuilt window (`renderWindow` in `main.js`: 5 alias features, 10 in total; in the HTML
  Chronicle 1/4 and Fellow travellers 0/1), new main features as tabs in the header and as their
  own section with an entry in the navigation; the bond tiers (`TIERS` in `main.js`)
  like `FellowService.TIERS`.
