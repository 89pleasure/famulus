# Fellow travellers redesign and a new window frame

Date: 2026-11-24. Status: agreed with the client in conversation; mockups on the canvas
"Weggefährten – Entwürfe" (claude.ai artifact 8c8YkEpYskeTFAjxBUiBir), pages "Zusammengeführt"
and "Neuer Rahmen". The mockups are HTML; the addon draws the same with its own widgets.

## Why

The fellow travellers page (`layouts.fellows` in `Famulus/UI/Options.lua`) is two plain lists of
person rows. Next to the chronicle's picture book it looks bare ("boring"). The client wants it to
feel as rich as the chronicle, and to turn the numbers Famulus already keeps (time together,
times met, bosses) into something personal: a ranking of the closest companions, a level of
"bond", and a story per companion.

To give the new page room, the window frame changes for every page: the head carries search and
the addon's own pages, and a page may go without the sidebar.

## Goals

1. A new window frame, the same head on every page; each page decides whether it has a sidebar.
2. The master switches of the main features (categories `aliases`, `chronicle`, `fellows`) move
   to the global settings.
3. A fellow travellers overview: the three closest companions as large tiles, everyone else in a
   sortable list, the chosen person as a large profile card on the right.
4. "Bond" (Verbundenheit): four tiers from time together, shown as a ring around each crest and
   a tier badge, in the overview and in the detail view.
5. A detail view per companion, "Eure Geschichte": the profile at the top, below it a picture
   book (the chronicle's `UI.Book`) of the days you spent together.

## Non-goals

- Notes on people, a hint in the unit tooltip, an "add friend" button (explicitly not chosen on
  2026-11-23; do not add without asking).
- A sidebar-less layout for Aliases or Chronicle. Both keep their sidebar.
- Changing the website (`website/`), which rebuilds the window in HTML. It can follow later.
- Moving the per-feature switches (e.g. "rememberFellows", "raids", the chronicle's recorders,
  the live feed). Only the three master switches move.

## Anti-goals (would make it a failure even if it works)

- Anything that runs per frame or keeps a timer while idle. The ring and the tiles are drawn once
  per render, like the rest of the window.
- Data that grows without bound in `FamulusDB` (the store already caps people at 500).
- Sending fellow data to anyone. It stays local, as today.
- A layout that jumps unpredictably: elements that exist on every page (head, search, page
  buttons) stay in the same place on every page.

## Constraints

- All rules of AGENTS.md › "Regeln für neuen Code" hold: colours only through `UI.Paint/Tint/Ink`,
  texts through `ns.L` at run time, both locales with the same placeholders, new widgets in
  `UI/Widgets.lua`, new Lua files in the `.toc`, `luajit tests/run.lua` green.
- The window is built on first open; the frame changes must not create frames at load time
  (the test counts them).
- WoW has no CSS: no conic gradients, no `color-mix`. Effects must be built from textures
  (`circle.tga`, `shadow.tga`, gradients via `UI.Shade`).
- The mockups use the letter of the name on the crest and Cinzel as display font. In the addon:
  the crest shows the game's class icon where the client has one, else the initial; headings use
  `UI.SetDisplayFont` (the game's book font).

## Approaches considered

For the fellows page, four directions were drawn (page "Erste Entwürfe"): A profile ("Steckbrief",
list plus large card), B album (tiles, top three ranked), C encounter book (the chronicle's book,
by date of meeting), D bond (ranked list with tiers). The client picked a combination: A's
overview (list plus large card), B's tiles for the top three, C as the detail view of one person,
D's tiers in both. For the overview, "list plus card" (1) beat "wall of tiles" (1b); the final
form (3) puts the top three as tiles above the list, without sidebar.

For the frame, the alternative was to keep the sidebar everywhere and squeeze the overview into
~900 px; the client chose a per-page sidebar and a global head instead. For "settings" and
"about" in the head, icon buttons beat a gear menu (one more click, no menus elsewhere) and
"about behind the logo" (undiscoverable).

## Decisions

### Frame (all pages)

- **Head** (76 px, as today): logo and wordmark on the left, the main features as tabs (icon,
  name, counter plate) as today; on the right a **search field** (about 230 px; moved from the
  sidebar), then **icon buttons** for Settings (gear) and About (info) with a tooltip naming them,
  a thin divider, the close button. Settings and About are pages as today; when one is shown, its
  icon button carries the same accent stroke as a selected tab.
- **Pages with sidebar** (Aliases, Chronicle; Settings and About as today): the sidebar starts
  directly with the page's name and description (no search, no master switch), then its tabs,
  at the bottom "x von y aktiv".
- **Pages without sidebar** (Fellow travellers): below the head a slim bar (about 48 px) with the
  page's name and description on the left and its tabs on the right, as small tabs with an accent
  stroke. "x von y aktiv" is not shown there. The content uses the full width.
- A page declares this with a flag (e.g. `page.sidebar = false`); everything else in `Render`,
  search, reset and refresh works for both.
- Search keeps working over all pages; results show in the content area as today. On a page
  without sidebar the results use the full width. *(Builder check, our call:)* the content of a
  switched-off feature is left out of the search; its master switch in Settings › General is
  still found.
- The reset button stays where tabs have settings. On a sidebar-less page it sits in the slim bar,
  left of the tabs.

### Master switches

- Settings › General gets a first section **"Funktionen"** with one toggle per category
  (`categories.aliases`, `categories.chronicle`, `categories.fellows`), each with one sentence of
  description (reuse `cat_<id>_desc` or new `g_` keys).
- The switch disappears from the sidebar (`window.master`) and from the slim bar.
- A switched-off feature stays in the head, greyed with "AUS"/"OFF" as today. Its page shows,
  instead of its content, a short notice and a button "In den Einstellungen einschalten" that
  opens Settings › General.
- "Reset" on Settings › General also resets the three switches to on.

### Bond (Verbundenheit)

- Tiers by total time together (`FellowService.Seconds`): **Begegnung** below 1 h, **Bekannt**
  from 1 h, **Vertraut** from 10 h, **Unzertrennlich** from 40 h. Thresholds live in one table in
  `FellowService` (e.g. `FellowService.TIERS`), with a function returning tier and progress
  (0..1 towards the next tier; 1 at the top tier).
- English names: Encounter, Acquainted, Trusted, Inseparable (adjust if better words come up;
  both locales via `L`).
- Shown as: a ring around the crest whose filled part is the progress to the next tier, in the
  accent; a badge with the tier's name (accent on Vertraut and above, muted below); in the profile
  card and detail header a four-step ladder with the current step glowing and the line "Noch
  9 Std. gemeinsam bis Unzertrennlich".

### Overview (tab "Übersicht")

- Left (about 700 px): "Engste Gefährten" – the three people with the most time together as
  tiles side by side (crest with ring, rank I–III, name in display font, level and class, tier
  badge, "31 Std. · 14× · 9 Bosse", a foot strip "gerade in deiner Gruppe" or "zuletzt <wann> in
  <wo>"). Below: "Alle weiteren · N" with a select "Zuletzt gesehen" / "Meiste gemeinsame Zeit"
  (default: last seen) and a list (card with column heads: crest with ring, name and level/class,
  bond, time, last seen). The tiles do not follow the select; it sorts only the list. With three or
  fewer people there is no list; with none, the existing empty item explains how to start.
- Right (about 370 px), *(builder check, our call:)* fixed beside the scrolling left column, like
  the chronicle's rail: the chosen person as a large card: crest with ring, name, level and class,
  "gerade in deiner Gruppe", the tier ladder, three numbers (time, times, bosses), "Kennengelernt
  am … in …", "zuletzt …", buttons **"Eure Geschichte"** (primary) and **"Alias festlegen"**
  (opens the alias input as today, `ns:EditAlias`). A click on a tile or row chooses the person;
  the first person (rank I) is chosen when nothing is.
- *(Our call; the mockups have no cross.)* Forgetting a person (today the cross on a row) moves to the profile card (a small ghost button
  "Vergessen"); the list rows have no cross.
- The list shows at most `FELLOW_ROWS` (60) as today, plus "N weitere"; search finds all.
- An alias replaces the name everywhere, with the real name below it, as today.

### Detail view ("Eure Geschichte")

- Opened from the profile card; not a tab of its own. The slim bar shows a back link
  "Alle Weggefährten"; the head tab stays on Fellow travellers.
- Top: a card with crest and ring, name, level and class, online line, the three numbers and
  "seit <Datum>", and the tier ladder on the right.
- Below: `UI.Book` with one chapter per day you were together, newest first. Chapter heading: the
  zone where you spent the most time that day; beside it the day and "N Std. zusammen". Events
  in a chapter:
  - **Gemeinsam unterwegs**: from the first to the last moment together that day, and the
    duration ("10:40 bis 12:50 · 2 Std. 10 Min."). *(Builder check, our call:)* no "mit <others>"
    on this event: that would mean storing names per day. Who else was there shows only on boss
    events, from the chronicle's `with`;
  - **bosses** you defeated together that day, taken from the chronicle's boss entries whose
    `with` contains the person's name (only exists while "Meine Reise festhalten" records);
  - the companion's **own chronicle entries** of that day, if they share them (entries with
    `who` = the person), marked "aus <Name>s Chronik";
  - milestones (`big`): **"Ihr seid jetzt <Stufe>"** on the day the running total crossed a
    threshold, and **"Kennengelernt"** on the first day ("auf Stufe N" = the player's level then).
- Only days in the new per-person log appear (see Data); older history before this change shows
  just the "Kennengelernt" chapter from `first`/`firstZone`.

### Data

- New per person in `FamulusDB.fellows[guid]`: `days = { [YYYYMMDD] = { s = seconds, z = zone,
  b = bosses, f = first time, l = last time } }` and `firstLevel` (the player's level when you met). `Tally` adds to today's
  day; `Boss` increments today's `b`. "Zone of the day" is the zone of the longest share; keep it
  simple: the zone where the most seconds were counted that day (store per zone seconds only if
  needed; otherwise the last zone of the day is acceptable – builder's call).
- At most 30 days per person; older days drop (oldest first). The 500-person cap stays.
- Tier-up days are computed when the view is built, not stored. *(Builder check, our call:)* the
  walk starts from the time before the log, `seconds − sum(days[*].s)`, then adds each day oldest
  first; a milestone shows only where that running total crosses a threshold. Summing from zero
  would invent milestones for people with time from before this change or with more than 30 days.
- `/fam fellows demo` fills `days` and `firstLevel` for the sample people so the book has content.
- The `DATABASE_READY` clean-up drops malformed `days` entries.

## Left to the builder

- How the ring is drawn in WoW (options: a paused `Cooldown` swipe with a custom texture; or a
  ring of small segment textures lit up to the progress; or two half-circle textures). Whatever is
  chosen must run without `OnUpdate` and degrade to a plain border if an API is missing; add a
  self-test check if it relies on a client API.
- The class icon source (e.g. `Interface\\TargetingFrame\\UI-Classes-Circles` with
  `CLASS_ICON_TCOORDS`, or an atlas) with a self-test check and the initial as fallback.
- Exact sizes and spacing; follow the mockups and the existing card styles (`CreateCard`, book
  cards).
- Splitting the work into steps; updating `tests/run.lua` (window tests reference the sidebar,
  search box and master switch) and AGENTS.md (sections "Das Fenster" and "Weggefährten").
- Locale keys for all new texts in enUS and deDE.
