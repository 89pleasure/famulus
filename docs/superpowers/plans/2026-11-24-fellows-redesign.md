# Fellow Travellers Redesign and New Window Frame Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every page one head (tabs, search, settings/about icons), let a page go without
sidebar, move the three master switches into Settings › General, and rebuild the fellow
travellers page as an overview (top three tiles, list, profile card) with bond tiers and a
per-person story.

**Architecture:** Data first (`FellowService`: day log, tiers, milestones), then the frame in
`UI/Options.lua` (head, master switches, sidebar-less pages), then new widgets in
`UI/Widgets.lua` (crest with ring, tier badge, tier ladder), then the fellows layout built from
them, and the story view on top of the existing `UI.Book`. Every task keeps
`luajit tests/run.lua` green.

**Tech Stack:** Lua 5.1 (WoW Forever client 1.60, interface 16001), tests with LuaJIT against
`tests/wowmock.lua`, media drawn by `tools/make_media.py` (Python 3, standard library).

**Spec:** `docs/superpowers/specs/2026-11-24-fellows-redesign-design.md`

## Global Constraints

- Code, comments, log/exception text: English. Locale keys in **both** `Famulus/Locales/enUS.lua`
  and `deDE.lua`, same placeholders; read texts at run time through `ns.L`, never cache at load.
- Colours only via `UI.Paint` / `UI.Tint` / `UI.Ink` / `UI.Shade` with colour tokens; text via `UI.Text`.
- New widgets go into `Famulus/UI/Widgets.lua`; new Lua files into `Famulus/Famulus.toc`.
- No `OnUpdate`, no ticker, no frame creation at load time (the test counts two frames after load).
- Nothing about fellows leaves the client. `FamulusDB.fellows` stays capped at 500 people.
- Bond tiers by total time together: Begegnung < 1 h, Bekannt ≥ 1 h, Vertraut ≥ 10 h,
  Unzertrennlich ≥ 40 h (enUS: Encounter, Acquainted, Trusted, Inseparable).
- Day log: at most 30 days per person, oldest dropped first.
- Only the three category master switches move; per-feature switches stay on their tabs.
- Commits only when the client asks; no `Co-Authored-By` or "Generated with" lines. Commit
  author is the repo's local `89pleasure`.
- `luajit tests/run.lua` must end with `0 failed` after every task.

## Review Focus

1. A person saved before this change (no `days`, no `firstLevel`) opens without errors: overview
   shows them, the story shows only "Kennengelernt"; no false tier milestones (Task 1, Task 7).
2. A hand-edited or corrupt `days` table (string keys that are not dates, non-table values,
   negative seconds) is dropped by the `DATABASE_READY` clean-up, not crashing the view (Task 1).
3. Exactly 0, 1, 3 and 4 people: no list below three, list starts at the fourth, empty state at
   zero (Task 6).
4. A switched-off main feature: head shows OFF, its page shows the notice with the button, search
   leaves its content out, its switch is still found in Settings (Task 3).
5. A class the client has no icon for (nil `class`, unknown file name): the crest shows the
   initial (Task 5).

---

### Task 1: Fellow data: day log, first level, tiers, milestones

**Files:**
- Modify: `Famulus/Modules/Fellows/FellowService.lua`
- Modify: `Famulus/Modules/Fellows/RememberFellows.lua` (pass the player's level)
- Test: `tests/run.lua` (fellows section, around the existing `Fellows.Sync` checks)

**Interfaces:**
- Produces:
  - `FellowService.TIERS = { 0, 3600, 36000, 144000 }` (seconds at which tier 1..4 starts)
  - `FellowService.Tier(seconds) -> tier (1..4), progress (0..1), toNext (seconds or nil at top)`
  - `FellowService.DayKey(timestamp) -> number` (YYYYMMDD in local time, via `date("*t")`)
  - `FellowService.Days(person) -> list` of `{ key, s, z, b, f, l }`, newest first
  - `FellowService.Milestones(guid, person, now) -> map dayKey -> tier` (tier reached that day,
    counting from `Seconds − Σ days.s`)
  - `FellowService.Sync(members, now, zone, level)` (new 4th arg: the player's level, stored as
    `firstLevel` when a person is first met)
  - person fields: `days = { [YYYYMMDD] = { s, z, b, f, l } }`, `firstLevel`

- [ ] **Step 1: Write failing tests** in the fellows section of `tests/run.lua`:

```lua
check(Fellows.Tier(0) == 1 and select(2, Fellows.Tier(1800)) == 0.5, "under an hour: encounter, halfway at 30 min")
check(Fellows.Tier(3600) == 2 and Fellows.Tier(36000) == 3 and Fellows.Tier(144000) == 4, "tiers start at 1, 10 and 40 hours")
check(select(2, Fellows.Tier(200000)) == 1 and select(3, Fellows.Tier(200000)) == nil, "the top tier is full and has no next step")
-- after the existing stretch of Mira (3600 s on one day, zone "Westfall", one boss):
local day = FamulusDB.fellows["Player-1-MIRA"].days[Fellows.DayKey(clock)]
check(day and day.s == 3600 and day.z == "Westfall" and day.b == 1 and day.f and day.l and day.l >= day.f, "a day records time, zone, bosses, first and last moment")
check(FamulusDB.fellows["Player-1-MIRA"].firstLevel == 20, "the player's level when you met is kept")
-- 31 days of one minute each: the oldest goes
-- old person without days, 40 h before the log, then 1 h logged: no milestone
check(next(Fellows.Milestones("Player-1-OLD", oldPerson, clock)) == nil, "time from before the log does not invent milestones")
-- 9 h before the log, then 2 h on one day: that day reaches Trusted
check(Fellows.Milestones("Player-1-NEW", newPerson, clock)[Fellows.DayKey(clock)] == 3, "crossing 10 h marks the day")
-- clean-up
FamulusDB.fellows["Player-1-BAD"] = { name = "Bad", last = clock, times = 1, days = { x = 5, [20261124] = "y", [20261123] = { s = -1 } } }
ns:Fire("DATABASE_READY")
check(next(FamulusDB.fellows["Player-1-BAD"].days) == nil, "broken days are dropped")
```

- [ ] **Step 2: Run** `luajit tests/run.lua` — expect FAILs for the new checks.
- [ ] **Step 3: Implement** in `FellowService.lua`: `TIERS`, `Tier`, `DayKey`, `Days`, `Milestones`;
  `Tally` adds `now − since` to the day of `now` (set `f` on first add, `l = now`, `z = zone`),
  `Boss` increments today's `b`; prune `days` to 30 keys after each add; `Sync` stores
  `firstLevel = level` for new people; `RememberFellows:Scan` passes `UnitLevel("player")`;
  `DATABASE_READY` keeps only numeric keys 19000101..29991231 with table values whose `s` is a
  non-negative number. `Demo()` gives each sample `firstLevel` and 3–6 `days` spread over the
  sample's span (sum of `s` ≤ `seconds`).
- [ ] **Step 4: Run** `luajit tests/run.lua` — expect `0 failed`.
- [ ] **Step 5: Commit** (only when asked) `Record a day log per fellow traveller and their bond tier`.

---

### Task 2: One head for every page: search and icon buttons

**Files:**
- Modify: `Famulus/UI/Options.lua` (`BuildSidebar`, `BuildHead`, `CreateNavButton`, `RefreshHead`, `RefreshSidebar`)
- Test: `tests/run.lua` (window section)

**Interfaces:**
- Produces: `window.search` now a child of the head (same object API as today);
  pages with `bottom = true` are drawn as icon-only nav buttons (`button.compact = true`; the
  label keeps its text for tests and tooltip, hidden); tooltip on hover via `GameTooltip`.

- [ ] **Step 1: Failing tests:**

```lua
check(window.search:GetParent() ~= window.sidebar, "the search sits in the head")
check(navButton("Settings").compact and not navButton("Settings").label:IsShown(), "settings is an icon in the head")
check(navButton("About").compact, "so is about")
mock.Click(navButton("Settings"))
check(navButton("Settings").bar:IsShown(), "the chosen icon carries the accent stroke")
```

- [ ] **Step 2: Run** — expect FAIL.
- [ ] **Step 3: Implement.** Search box anchored in the head right of the main tabs, 230 px wide,
  `TOPRIGHT` left of the icon buttons; icon buttons 32×32 using `UI.media.gear` / `UI.media.info`,
  a 1 px divider before the close button; `RefreshHead` lays out trailing compact buttons with
  width 32. Sidebar content moves up by the old search height (area block starts at `HEAD + 18`).
- [ ] **Step 4: Run** — `0 failed` (adjust existing checks that assumed the sidebar search, e.g. anchors only; behaviour checks stay).
- [ ] **Step 5: Commit** `Put the search and the addon's own pages into the head`.

---

### Task 3: Master switches in Settings › General; notice for a switched-off feature

**Files:**
- Modify: `Famulus/UI/Options.lua` (`SettingsTabs`, `RefreshMaster` removed, `BuildSidebar` master removed, `Render`, `SearchBlocks`)
- Modify: `Famulus/Locales/enUS.lua`, `deDE.lua`
- Test: `tests/run.lua`

**Interfaces:**
- Produces: `CategoryItem(category)` (kind `toggle`, `section = "categories"`, `key = category`,
  label `L["cat_" .. category]`, desc `L["cat_" .. category .. "_desc"]`), listed first on
  Settings › General under block title `L.ui_features` ("Funktionen" / "Features");
  `window.offNotice` (frame with `text` and `button`), shown instead of the content when
  `CurrentTab().category` is off.
- New keys: `ui_features`, `ui_off_notice` ("%s ist ausgeschaltet." / "%s is switched off."),
  `ui_off_enable` ("In den Einstellungen einschalten" / "Switch on in settings").

- [ ] **Step 1: Failing tests** (replace the `window.master` checks):

```lua
check(window.master == nil, "the pages carry no master switch any more")
mock.Click(navButton("Settings"))
local switches = visibleRows()
check(switches[1].item.section == "categories" and switches[1].item.key == "aliases" and #switches >= 3, "settings › general starts with the three main features")
mock.Click(switches[1])
check(not ns:IsCategoryEnabled("aliases") and navButton("Aliases").count:GetText() == "OFF", "switching one off greys it in the head")
mock.Click(navButton("Aliases"))
check(window.offNotice:IsShown() and #visibleRows() == 0, "its page shows only the notice")
window.search.edit:SetText("kontextm")
check(#visibleRows() == 0, "search leaves a switched-off feature out")
window.search.edit:SetText("aliases")
check(visibleRows()[1] and visibleRows()[1].item.section == "categories", "but finds its switch")
window.search.edit:SetText("")
mock.Click(window.offNotice.button)
check(window.title:GetText() == ns.L.ui_tab_general, "the notice's button opens settings › general")
```

- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement.** Remove `window.master`; `TabDiffersFromDefaults` no longer checks the
  category; Settings › General reset resets `categories.*` through the item's `section/key`.
  `SearchBlocks` skips tabs whose `category` is off. In `Render`, when the tab's category is off,
  hide cards, rows, book and rail and show `window.offNotice` centred in the content.
- [ ] **Step 4: Run** — `0 failed`.
- [ ] **Step 5: Commit** `Move the main features' switches into the settings`.

---

### Task 4: Pages without sidebar

**Files:**
- Modify: `Famulus/UI/Options.lua` (`BuildPages`, new `BuildPageBar`, `Render`, `RefreshSidebar`, scroll anchors)
- Test: `tests/run.lua`

**Interfaces:**
- Produces: `page.sidebar` (default true; `fellows` sets false); `window.pageBar` (48 px below the
  head: `name`, `desc`, `tabs` – buttons with `label`, `selected`, `bar` – and `reset`), shown only
  for sidebar-less pages; `ContentLeft()` returns `SIDEBAR + PAD` or `PAD`; `ContentWidth()`
  returns `CONTENT_W` or `WIDTH − 2·PAD`. The content header (`window.title/subtitle`) is hidden
  on sidebar-less pages; the page bar replaces it.
- Test helper: `pageTab(text)` like `tabButton`, over `window.pageBar.tabs`.

- [ ] **Step 1: Failing tests:**

```lua
mock.Click(navButton("Fellow travellers"))
check(not window.sidebar:IsShown() and window.pageBar:IsShown(), "fellow travellers have no sidebar, a page bar instead")
check(window.pageBar.name:GetText() == "Fellow travellers" and pageTab("Overview") and pageTab("Settings"), "the bar names the page and its tabs")
mock.Click(navButton("Chronicle"))
check(window.sidebar:IsShown() and not window.pageBar:IsShown(), "the chronicle keeps its sidebar")
```

- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement.** `layouts.fellows` returns tabs `overview` (temporarily the old recent
  list) and `record` (label `ui_tab_settings`). New keys `ui_tab_overview` /
  `ui_tab_overview_desc`. Re-anchor `window.scroll` and the rail per page in `Render`; the head's
  logo keeps the sidebar width on every page.
- [ ] **Step 4: Run** — `0 failed` (update the fellows-page checks that used `window.area` and `tabButton`).
- [ ] **Step 5: Commit** `Let a page go without the sidebar; fellow travellers do`.

---

### Task 5: Widgets: crest with ring, tier badge, tier ladder

**Files:**
- Modify: `tools/make_media.py` (new `ring.tga`, 128 px annulus, inner radius 0.82 of outer), run it
- Create: `Famulus/Media/ring.tga`
- Modify: `Famulus/UI/Theme.lua` (`UI.media.ring`), `Famulus/UI/Widgets.lua`, `Famulus/Core/SelfTest.lua`
- Modify: `tests/wowmock.lua` (frame type `Cooldown`: `SetSwipeTexture`, `SetSwipeColor`, `SetDrawEdge`,
  `SetDrawBling`, `SetHideCountdownNumbers`, `SetCooldown`, `Pause`, `Clear`)
- Test: `tests/run.lua` (new section "Widgets: crest")

**Interfaces:**
- Produces:
  - `UI.Crest(parent, size) -> crest` with `crest:SetPerson(name, classFile)` (class icon from
    `Interface\\TargetingFrame\\UI-Classes-Circles` + `CLASS_ICON_TCOORDS[classFile]`, else the
    initial via the existing `Initial()` moved to `UI.Initial`), `crest:SetProgress(p)` (0..1; a
    paused `Cooldown` swipe with `ring.tga` in `accent` over a `ring.tga` track in `track`; if
    `Cooldown.Pause` is missing, a full ring in `accentLine` and no progress), `crest.ringShown`.
  - `UI.TierBadge(parent) -> badge` with `badge:SetTier(tier)` (text `L["ui_bond_" .. tier]`,
    accent style for tier ≥ 3, muted below).
  - `UI.TierLadder(parent, width) -> ladder` with `ladder:SetTier(tier, progress)` (four dots,
    names below, filled line up to the position).
- New keys: `ui_bond_1..4` (Begegnung, Bekannt, Vertraut, Unzertrennlich / Encounter, Acquainted,
  Trusted, Inseparable), `ui_bond_next` ("Noch %s gemeinsam bis %s" / "%s together to %s").
- Self-test (group `media`): `class icons` (texture loads and `CLASS_ICON_TCOORDS` exists),
  `ring` (`ring.tga` loads, `Cooldown` has `Pause` and `SetSwipeTexture`).

- [ ] **Step 1: Failing tests:**

```lua
local crest = ns.UI.Crest(UIParent, 40)
crest:SetPerson("Mira", "MAGE")
check(crest.icon:IsShown() and not crest.initial:IsShown(), "a known class shows its icon")
crest:SetPerson("Mira", nil)
check(crest.initial:GetText() == "M" and crest.initial:IsShown(), "without a class, the initial")
crest:SetProgress(0.7)
check(crest.swipe.paused and crest.swipe.progress == 0.7, "the ring stands still at the progress")
local badge = ns.UI.TierBadge(UIParent); badge:SetTier(3)
check(badge.text:GetText() == "Trusted", "the badge names the tier")
```

- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement** the widgets; `SetProgress` uses
  `swipe:SetCooldown(GetTime() − p·100, 100); swipe:Pause()`; record `swipe.progress = p` for tests.
- [ ] **Step 4: Run** — `0 failed`; run `python3 tools/make_media.py` and check `ring.tga` exists.
- [ ] **Step 5: Commit** `Add a crest with a progress ring, a tier badge and a tier ladder`.

---

### Task 6: The fellows overview

**Files:**
- Modify: `Famulus/UI/Options.lua` (replace `FellowTab`/`FellowItem` with `FellowOverview`), possibly
  `Create: Famulus/UI/Fellows.lua` for the overview's frames if `Options.lua` grows past ~2600 lines
  (add to `.toc` after `UI/Rail.lua`)
- Modify: locales
- Test: `tests/run.lua` (fellows page checks)

**Interfaces:**
- Consumes: Task 1 (`Tier`, `Seconds`, `List`, `IsTogether`, `Forget`), Task 4 (sidebar-less page,
  `ContentWidth()`), Task 5 (`UI.Crest`, `UI.TierBadge`, `UI.TierLadder`).
- Produces: `tab.overview = function() return model end` on the `overview` tab, rendered by
  `window.fellows` (`UI.FellowOverview(parent)` with `:SetModel(model)`), where
  `model = { top = {person...}, rest = {person...}, sort = "last"|"time", chosen = guid,
  more = n }` and each `person = { guid, name, alias, level, class, tier, progress, seconds,
  times, bosses, together, lastText, firstText }`.
  Frames for tests: `window.fellows.tiles[i]` (`guid`, `rank`), `window.fellows.rows[i]`
  (`guid`), `window.fellows.sort` (dropdown), `window.fellows.card` (`name`, `story`, `alias`,
  `forget`).
- Session state: `fellowSort` ("last" default), `fellowChosen` (guid or nil → rank I).
- New keys: `ui_fellow_closest` ("Engste Gefährten"), `ui_fellow_others` ("Alle weiteren · %d"),
  `ui_fellow_sort_last` ("Zuletzt gesehen"), `ui_fellow_sort_time` ("Meiste gemeinsame Zeit"),
  `ui_fellow_story` ("Eure Geschichte"), `ui_fellow_alias` ("Alias festlegen"),
  `ui_fellow_forget` ("Vergessen"), column heads `ui_fellow_col_*`.

- [ ] **Step 1: Failing tests** (replace the old recent/most-often checks):

```lua
-- four people: Mira 2 h, Tom 1 h 10, A 30 min, B 10 min
check(#window.fellows.tiles == 3 and window.fellows.tiles[1].guid == "Player-1-MIRA", "the three with the most time are tiles, the closest first")
check(#window.fellows.rows == 1 and window.fellows.rows[1].guid == "Player-1-B", "everyone from the fourth on is in the list")
mock.Click(window.fellows.rows[1])
check(window.fellows.card.name:GetText() == "B", "a click chooses the person for the card")
check(window.fellows.tiles[1].guid == "Player-1-MIRA", "sorting the list never moves the tiles")
mock.Click(window.fellows.card.forget)
check(FamulusDB.fellows["Player-1-B"] == nil and lastChat():find("removed", 1, true), "forget removes the person and says so")
-- three people: no list; zero people: the empty item
-- 70 people: 60 rows and "N more"; search finds person 70 once (keep the existing check)
mock.Click(window.fellows.card.alias)
check(tabButton("Names").selected, "the alias button opens the alias input")
```

- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement** per spec › Overview: left column scrolls (`window.scroll`), the card is a
  fixed column right (370 px) like the rail; tiles in a row of three; list rows with crest 38 px,
  name/level, badge, time, last seen; the dropdown uses `UI.Dropdown` + `UI.OpenMenu`. Search keeps
  using the old person items (`tab.search`).
- [ ] **Step 4: Run** — `0 failed`.
- [ ] **Step 5: Commit** `Show fellow travellers as the closest three, a list and a profile card`.

---

### Task 7: The story of one fellow traveller

**Files:**
- Modify: `Famulus/UI/Options.lua` (story mode of the fellows page)
- Modify: locales
- Test: `tests/run.lua`

**Interfaces:**
- Consumes: Task 1 (`Days`, `Milestones`, `Tier`), Task 6 (`window.fellows.card.story`), `UI.Book`,
  `ns.ChronicleService.Entries()` (boss entries with `with`, entries with `who`).
- Produces: session state `fellowStory` (guid or nil). While set, the overview tab renders
  `window.fellowHead` (crest, name, numbers, ladder) and the book; the page bar shows
  `window.pageBar.back` ("Alle Weggefährten") instead of its tabs.
- Book model: one chapter per `Days(person)` entry: `small` = day title (`DayTitle`), `title` =
  `z`, `sub` = duration; events: `{ kind = "fellow", title = L.ui_fellow_together, detail =
  "<f> – <l>  ·  <duration>" }`, bosses of that day whose `with` contains `person.name`
  (`kind = "boss"`, detail "mit <others>"), the person's own entries that day (`who == name`,
  via `ChronicleEvent`, chip `L.ui_fellow_from:format(name)`), milestone `{ big = true, title =
  L.ui_fellow_tier_up:format(tier name) }` on days from `Milestones`; a last chapter
  "Kennengelernt" from `first`/`firstZone`/`firstLevel` (`big = true`).
- New keys: `ui_fellow_together`, `ui_fellow_from` ("aus %ss Chronik"), `ui_fellow_tier_up`
  ("Ihr seid jetzt %s"), `ui_fellow_met`, `ui_fellow_met_detail` ("auf Stufe %d"), `ui_fellow_back`.
- `UI/Book.lua`: add picture kind `fellow` (icon `people`, muted colours).

- [ ] **Step 1: Failing tests:**

```lua
mock.Click(window.fellows.card.story)
check(window.fellowHead:IsShown() and window.pageBar.back:IsShown(), "the story opens with the person on top and a way back")
local chapters = bookFrames("chapter")
check(#chapters >= 2, "a chapter per day together and one for the first meeting")
-- a person with only first/firstZone: exactly one chapter "Met"
mock.Click(window.pageBar.back)
check(window.fellows:IsShown() and not window.fellowHead:IsShown(), "back leads to the overview")
mock.Click(navButton("Aliases")); mock.Click(navButton("Fellow travellers"))
check(not window.fellowHead:IsShown(), "leaving the page closes the story")
```

- [ ] **Step 2: Run** — FAIL.
- [ ] **Step 3: Implement** per the interface above; `SelectPage` and `SelectTab` reset `fellowStory`.
- [ ] **Step 4: Run** — `0 failed`.
- [ ] **Step 5: Commit** `Tell the story of each fellow traveller`.

---

### Task 8: Documentation and a look in the game

**Files:**
- Modify: `AGENTS.md` ("Das Fenster": head, sidebar per page, master switches; "Weggefährten": overview,
  story, tiers, day log, demo; "Regeln für neuen Code": page flag), `README.md` (feature list)

- [ ] **Step 1:** Update both documents (German), mark everything as "nur gegen den Mock geprüft".
- [ ] **Step 2: Run** `luajit tests/run.lua` — `0 failed`.
- [ ] **Step 3:** Ask the client for a round in the game: `/reload`, `/fam fellows demo`, open the
  page, open a story, `/fam test`; read the report with `luajit tools/read_selftest.lua`
  (expect `class icons` and `ring` ok).
- [ ] **Step 4: Commit** (when asked) `Document the new frame and the fellow travellers page`.
