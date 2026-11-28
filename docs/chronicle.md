# Chronicle

Part of the project notes; requirements, rules and the index of all files are in
[AGENTS.md](../AGENTS.md). References of the form "see X" point to a heading or a bold entry;
the index there says which file it is in.

The owner's idea (2026-11-19): record the journey of the player and their companions
(level-ups, deaths, achievements and more), presented graphically "like a picture book", ideally
with live notifications. Status: recording, sharing between players, the notification and the
picture-book look are built and checked against the mock only.

- **Structure:** area and category `chronicle`, data via `ns.ChronicleService`
  (`Modules/Chronicle/ChronicleService.lua`) in `FamulusDB.chronicle` (account-wide, outside the
  profiles, at most 2000 entries, kind and values instead of text; see "Limit" below). Tabs "Everyone", "My journey",
  "Friends" (until 2026-11-24 "Companions", see "Chronicle and fellow travellers") and "Settings"
  (until 2026-11-23 "Recording") (`layouts.chronicle`). In the project notes from before then, the
  chronicle's people are often still called "companions"; in the window they are "Friends".
- **Limit (since 2026-11-25, the owner's go-ahead after closing issue #12):** at most 2000
  entries (`MAX_ENTRIES`), of them at most 1000 of others (`MAX_OTHERS`, entries with `who`),
  in `Trim` in `ChronicleService.lua`, on every new entry and on loading. Beyond 1000 of others
  their oldest goes; beyond 2000 in all the oldest entry of anyone. Before, the oldest entry
  went whoever it was from, and in a guild with many Famulus users the news of others would
  have pushed the player's own journey out within days (estimate: 40 members with about 10
  entries a day each). A pure "others go first" was rejected: with 2000 own entries no news of
  others would have been kept at all. The half is the assistant's decision. An existing file
  with more than 1000 entries of others loses their oldest on the next login. Checked against
  the mock only.
- **Book with rail (the owner's decision, 2026-11-23, chosen on the HTML mockup "Famulus
  Chronicle": variant A with "Bundle repeats" and "Chapter head on one line"):**
  The trigger was the first screenshot in the 1180 window: cards 428 px wide with about 170 px of
  text, four identical deaths one below the other, chapter heads over 100 px tall. Rejected: B, a
  wide book with cards up to 360 px and the player's own level-ups as a banner above the line.
  Checked against the mock only, not yet seen in game.
  - On the three story tabs the book is 600 px wide (`BOOK_W`, the size before the window was
    rebuilt); to its right, 28 px apart, a rail of 272 px (`UI.Rail`, `UI/Rail.lua`; a tab
    provides it via `tab.rail`). It does not scroll with the book but on its own, in case it is
    taller than the window. During a search there is no rail; rows and cards then take the full
    width (`RowSetItem` is passed the width). "Settings" shows entries and the chosen one instead
    (see "Settings tabs" in `docs/window.md`).
  - "Everyone": card "This week" (level with number of level-ups, deaths, newly discovered zones,
    professions and milestones; only the character being played, last seven days, first name on
    the right) and card "Friends" (alias, last event with time or day, level, online/offline).
    "My journey": "This week" and "Professions" with points and bars. "Friends": one card per
    person with their "Stats" (until 2026-11-24 "Profile"; level, online, the four shared
    numbers), without shared numbers "No stats shared yet."; these cards no longer stand above
    the book.
  - Companions are everyone with an entry or a profile (`ChronicleService.Companions`), most
    recently heard from first. Level: the higher of the last level entry and the profile. Online:
    `ChronicleService.OnlineCheck` looks into the friends list and guild roster once per build;
    the state applies when the window is built and is not updated when someone comes online.
  - A click on a companion (list or stats) shows only their events in the book; above it stands
    "Only events of …" with "Show all", a second click lifts the filter. Another tab, another page
    or closing the window forgets the choice (`chronicleWho`). If the fellow travellers know the
    person (`FellowService.Find`, name in any spelling) and are switched on, "Your story" also
    stands there and opens their story.
  - **Bundle repeats:** If deaths in the same zone or level-ups of the same companion follow
    each other directly in the book, they share one card (`SameRun`, `ChronicleRun` in
    `UI/Options.lua`; sentence from `ChronicleService.TextRun`): "Fallen 3 times in Darkshore" with
    the number in the corner of the picture, "Reached levels 21 to 22" with the highest level in
    the picture. Until 2026-11-25 all times stood below the line as small badges; since then the
    card names the first and the last ("20:02 – 21:14", in its strip since 2026-11-27, see
    "Weighting").
    The player's own level-ups stay single. The number of
    events in the chapter head still counts every entry.
  - **Chapter head on one line:** the time on the left (until 2026-11-24 the day), in the middle
    the title in the book font (22 px; until 2026-11-24 the zone), levels and number of events on
    the right, on the outside a line on each side that fades out towards the edge. About 36 px
    tall instead of over 100, with the route below it 30 px more. The ornament with the ember is
    gone.
- **A chapter is a play session (the owner's decision, 2026-11-24, on the canvas
  "Famulus Chronicle – Chapters", claude.ai artifact `Sp9tF6ba6wfgKroNqejVoT`: variant C):**
  Trigger: a chapter per day was named after the zone most of its entries named ("Today ·
  Feralas"), yet while playing you pass through several zones. The friends' zones were counted
  too, and midnight split a play session. Rejected: A (day with route), B (waypoints on the line;
  "the place matters less than the events themselves"), D (the most important moment as the
  title), E (levels as chapters). Checked against the mock only, not seen in game.
  - A new chapter begins after a break of two hours between two shown entries (`SESSION_GAP` in
    `UI/Options.lua`). What counts is what the tab shows, so in the filtered book only the
    person's entries. There is no query of login and logout; a long break splits the
    session.
  - **Title** by the time of day the session began (`SessionTitle`): morning from 5, midday
    from 11, afternoon from 14, evening from 18, night from 23 o'clock. Until 5 in the morning the
    night counts towards the day before (`NIGHT_SHIFT`), so that a session until 2 o'clock stays
    "Last night" and is not called "Tonight". "This evening", "Yesterday afternoon"; older ones
    are named after the weekday ("Sunday night", the German "Sonntagnacht") and carry the date on
    the left instead of the time. Texts `c_when_<today|yesterday|day>_<part>`, `c_weekday_0` to
    `_6` (own weekday names, because it is unclear whether Forever knows
    `CALENDAR_WEEKDAY_NAMES`).
  - On the left from–to (`c_ch_span`), with only one time just that one.
  - **Route** below the head: the zones of the player's own entries in chronological order, as
    badges with arrows (`chevron.tga`, rotated); a zone appears again when you return to it.
    Friends' zones do not count. If the row is wider than the book, the oldest zones give way to
    a "…". The route only knows zones in which something was recorded (whoever only rides
    through does not appear); recording every zone change would be possible but has not been
    asked for.
  - In game the route hit a bug the first time (`head.width`, see "Bug 2026-11-24"); fixed,
    after that the chronicle ran in game ("Works").
  - Since 2026-11-25 also in "Your story" with the fellow travellers (see there). The chapter
    head (`SessionHead`) and the division of the fellow travellers' books (`SessionChapters`, for
    "Groups" and "Your story") each exist once in `UI/Options.lua`; everything is drawn by
    `UI.Book`. The website shows it too since 2026-11-27 (see "Demos" in docs/website.md).
- **Picture book (2026-11-19):** The owner found the HTML draft "pretty cool already" and had it
  built that way. The three story tabs no longer show rows but a book
  (`UI.Book`, `UI/Book.lua`; a tab provides it via `tab.book`, `Render` places it below the
  cards): per day (since 2026-11-24 per play session) a chapter with a heading, below it a
  line in the middle on which the events hang alternately left and right as cards, with a
  picture, a dot on the line and the time on the opposite side. The assistant's decisions, not
  yet seen in game:
  - A chapter was named after the zone in which most of its events take place; since
    2026-11-24 it is a play session with its own title (see above). There is no chapter number
    as in the draft (only the last 50 events are shown, so a count would not be
    stable).
  - Pictures are own icons (`skull.tga`, `swords.tga`, `peaks.tga`, `star.tga`, 64 px) or, for
    levels, the number; death and boss have fixed hues of their own, the rest follows the colour
    scheme. The player's own level-up is the milestone: larger card, accent border, accent mark
    on the left (the glow has been gone since the alignment with the options cards).
  - Every card names whose event it is in its strip, by name alone (see "Strip with name and
    time" below; until 2026-11-27 with the class icon, see "Class and name").
  - Headings and the level number are in the game's book font, read from the font object
    `QuestTitleFont` (`UI.SetDisplayFont`), so that every language gets its file; if the object
    is missing, the window uses Inter. `QuestTitleFont` exists in the Forever client
    (screenshot 2026-11-23, deDE: chapter headings in the book font). Italic type as in the
    draft does not exist.
- **Rework after the first screenshot (2026-11-19, four proposals by the assistant, all accepted
  by the owner):**
  1. **Name in the strip:** The heading of a companion event no longer names them in the book
     ("Received: Schlafsack" instead of "Mira receives: Schlafsack"); the name (or alias) stands
     with the initial in the sunken strip at the bottom (since 2026-11-25 in the card's head, see
     "Weighting"). `ChronicleService.Text(entry, true)` returns
     the heading without the name; since 2026-11-27 the live feed too names the person in a
     head row of its own (see "Three rows" under "Live feed"); `story.fullTitle` is gone.
     Since 2026-11-24 as "Alias (character name)", see "Class and name".
  2. **Icons fill the frame:** The frame now has only slightly rounded corners (5 px), the icon
     sits two pixels from the edge and is cropped more (10 % per side), so that the black
     built-in border of the game icons disappears.
  3. **Columns run independently:** The cards still alternate sides, but each side continues on
     its own, so that the sides interlock (before, each event took a row of its own). Only the
     dots on the line keep a distance (`DOT_GAP`) and stay in chronological order. The line now
     belongs to the chapter (`book.trails`); the time no longer stands freely on the opposite
     side (see below).
  4. **Number on icon:** Levels and profession milestones show their number on a darkened
     game icon (level: `UI.gameIcons.level`, profession: the profession icon) instead of on a
     flat tile.
  Seen in game (second screenshot): all game icons load, including the fixed ones for
  level, boss, zone and the riding icon from the spell. Improved afterwards (the assistant's
  decisions, not yet confirmed): the time stands at the end of the line below the heading
  ("in Tanaris  ·  22:07") instead of in the card's corner, where it took width from the heading;
  the dots on the line are smaller (22 px) and have a short stroke to their card, because with
  interlocking columns it is otherwise unclear which dot belongs to which side; the
  darkening under a number is stronger; sample entries do not name a chapter that has real
  entries.
- **The picture frame in the book was the same size for every event** (54 px; the owner's
  requirement, 2026-11-19). Since 2026-11-25 it has its own size per weight in the chronicle's
  book (40, 48, 56 px), see "Weighting"; the fellow travellers keep 54 px.
- **Weighting and structure of the cards (the owner's request, 2026-11-25; checked against the
  mock only, not yet seen in game):** Applies only to the chronicle's book. Every event there
  has a weight (`story.weight`, table `WEIGHT` in `UI/Options.lua`, sizes in `WEIGHTS` in
  `UI/ChronicleCard.lua`):
  - **Light** (`low`): deaths, arrivals in new zones. Picture 40 px, heading 12 px.
  - **Medium** (`medium`): profession milestones and everything the owner has not classified
    (challenges, items, abilities, profession learned; the assistant's decision). Picture 48 px,
    heading 13 px.
  - **Heavy** (`high`): bosses and level-ups, plus whatever the tables mark with `big`
    (riding). Picture 56 px. The previous milestone look: accent border, accent mark on the left,
    heading 15 px semibold. Implemented literally by kind: level-ups and bosses of friends
    are heavy too (before, only the player's own level-up).
  - **Structure next to the picture:** head, content, foot. The head names the person
    (`ChronicleService.Label`). Since 2026-11-25 (the owner's request) it is a row of its own
    above picture and text, flush with the picture, no longer above the text to the right of the
    picture; the row is a sunken strip across the full card width like the name at the bottom
    used to be (`sunken`, rounded at the top, a fine line at the bottom, 28 px tall).
  - **Strip with name and time, dots without icon:** The strip stands on every card of the
    chronicle, for the player's own events with the name of their own character
    (`ChronicleService.Character`; set in `ChronicleRun`). The name starts at the card's inner
    edge, above the picture's left edge, in `textDim`, a step brighter than the time in
    `textMuted`; `story.chip` is `{ text }` alone.
    Right-aligned in it the time (`story.when`), for a bundle the first and the last
    ("20:02 – 21:14"). The name runs up to the time and is cut off there; it is anchored to the
    time instead of given a measured width, so it follows when the font loads late (see "Font"
    in docs/window.md). **No icon of the kind (since 2026-11-27):** until then a 13 px icon of
    the kind stood there in the accent (before 2026-11-25 on the dot on the line). It told
    nothing that picture, heading and weight do not already say, and the time took the foot's
    room from the place: a light card is 222 px wide, which left about 106 px beside the
    reaction button for "21:18 · Rotkammgebirge" (seen cut off in game). With a bundle's span
    the name gets less room; the alias stays readable, the brackets go first.
    **No class icon (since 2026-11-27):** first the circle with the initial went (2026-11-25),
    then the class icon (18 px) that stood left of the name: in game it was hardly more than a
    dark speck and pushed the name off the picture's edge. Tried and dropped the same day: the
    name in the accent. It became the loudest thing on every card, louder than the headline,
    took the accent's meaning ("active / here": the milestones' border, a given reaction) and
    did not tell people apart, every name being the same yellow. The rail keeps its class
    icons. The dots on the line are glowing dots in accent colour like the former
    "x of y active" display (`UI.GlowDot`, glow three times the size of the dot), in
    all books, so also with the fellow travellers (book design). The book sets the size by
    weight (`DOTS`: light 5, medium 7, heavy 9 px; without weight medium, with `big`
    heavy; the owner's request, the assistant chose the sizes).
    The foot names only the place (`story.place`, "Darkshore"); a card without a place and
    without a reaction button has no foot.
  - **Height by content, equal edges (the owner's request after the first screenshot,
    2026-11-25):** The first version kept the head row free even without a name and always kept
    two lines of text free, and tied padding and picture size to the weight; in game that looked
    hollow and restless (empty areas, picture and text in a different place per weight). Since
    then the card is as tall as picture or text plus padding at top and bottom. At the sides all
    cards have the same padding (`SIDE`), the picture is left-aligned, and the text always keeps
    the same distance from the picture (`TEXT_GAP`; three sizes 40/48/56, left-aligned and fixed
    distance at the owner's request, 2026-11-25; a picture column as wide as the largest picture
    left too much space on light cards). So the text edge moves with the picture size. Picture
    and text start at the same height, the foot ends with the picture if the picture is taller
    (the owner's request, 2026-11-25; before, both were centred on each other and had
    different distances from the top edge).
  - **Width by weight, set by the book (the owner's request, 2026-11-25):** The
    feature only passes `story.weight`; `UI.Book` turns it into the card's width (`WIDTHS`
    in `UI/Book.lua`: light 80 %, medium 90 %, heavy 100 % of its book page; the shares are
    the assistant's decision). A narrower card hangs on the line, so that the
    stroke from the dot reaches it. Without weight (fellow travellers) the card is as wide as
    before. The content is passed the width and adapts to it. The weight only affects picture
    size, padding at top and bottom, heading and accent. Since 2026-11-25 (the owner's request
    after a screenshot: with HIGH the distance to the name bar was larger than with MEDIUM and
    LOW) the book sets the inner padding, `UI.BookPad` (14 px), the same on all sides, for every
    weight and below the name bar. Measured from the outer edge; because the hairline and the
    highlight edge at the top inside each take about one pixel and the name bar's line lies
    inside the bar, the top gets one pixel more (`UI.BookPadTop`) and below the name bar
    one less. Re-measured on the screenshot of 2026-11-25 (visible before: below the
    bar 32, at the sides 30, at the top 27 screen pixels); the weight now only affects width,
    picture size, heading and accent. A light card with two lines of text can therefore be taller
    than a medium one with one. The fellow travellers have kept their own padding (12, for
    milestones 15 px). The assistant's decisions in detail; not yet seen
    in game. The sunken strip with the name below the card
    is gone; the fellow travellers keep their strip (`story.foot`).
  - **The place never stands in the text:** The book reads the sentences with the zone hidden
    (`Placeless` in `UI/Options.lua`): "Fallen" instead of "Fallen in Darkshore", "Discovered a
    new zone" (`c_zone_nowhere`) instead of "Arrived in Feralas", "in Uldaman" drops out of the
    line below a boss, "with Mira and Tom" stays. Since 2026-11-27 the live feed reads them
    the same way and names the place first in its line below (see "Three rows").
  - **The book sets the design, each feature the content of its cards** (the owner's
    requirement, 2026-11-25, after the first version had also rebuilt the boss cards in "Your
    story": "that way each feature can decide for itself what the card's content is, but we
    always have the same book design"). `UI.Book` only knows
    chapters, line, dots and the card's style (background, hairline, highlight edge, glow under
    the mouse, accent via `story.big`, click). The content is built by `story.content(part, story,
    width)` into a frame of its own in the card and returns its height; the card grows with it.
    Per builder function each card has its own frame, which is reused (hence
    the same function for all cards of a kind, no new closure per story). Contents:
    `UI.ChronicleCard` (`UI/ChronicleCard.lua`, set in `ChronicleRun`) and `UI.FellowCard`
    (`UI/Fellows.lua`, set in `SessionChapters`; look as before, in the mock card by card
    the same height as on `main`). Shared building block: the picture frame (`UI.BookPicture`,
    `UI.SetBookPicture` in `UI/Book.lua`: game icon, own icon, number, count badge,
    tooltip). `ChronicleEvent` still only supplies the data, also for the live feed, which is
    unchanged.

- **Pictures are game icons (the owner's request, 2026-11-19):** They are square and there are
  very many; the own drawings (`skull.tga` etc.) now only appear as a fallback and on the chips
  of the live feed's kinds in its settings (until 2026-11-27 also small in the card's strip).
  Order (`EntryTexture` in `UI/Options.lua`):
  1. the icon stored with the entry (`entry.icon`, a file ID): for professions
     from `GetProfessionInfo`, for challenges from `GetAchievementInfo`; it is shared;
  2. the icon of the item (`C_Item.GetItemIconByID`) or of the spell of an ability
     (`C_Spell.GetSpellTexture`);
  3. the icon of the kind from `UI.gameIcons` (`UI/Theme.lua`): death, boss, zone, challenge,
     profession, ability, item.
  The names in `UI.gameIcons` are icons from Vanilla and not checked in game in the Forever
  client; `/fam test` reports per kind (group `media`, "icon …") whether the client has the file.
  The icons are not tinted and do not follow the colour scheme; the frame around them does.
- **`ownJourney`:** `PLAYER_LEVEL_UP`, `PLAYER_DEAD`, `BOSS_KILL`, `ACHIEVEMENT_EARNED` and
  `ZONE_CHANGED_NEW_AREA`. A zone leaves exactly one "arrival" per character
  (`FamulusCharDB.zones`), and only when the character newly discovers it (the owner's request,
  2026-11-19):
  - When switched on, the feature reads the world map and pre-marks every zone with an explored
    part as known (`C_Map.GetMapChildrenInfo` below the top map,
    `C_MapExplorationInfo.GetExploredMapTextures`). If that fails (for example in an instance),
    the next zone change tries again. If the API is missing, "for the first time since the
    chronicle has been running" applies as before. Whether both functions answer like this in
    the Forever client and whether the map names match `GetRealZoneText` is not checked in game.
  - On a flight (`UnitOnTaxi`) nothing is written and nothing is marked as seen. After
    landing (`PLAYER_CONTROL_GAINED`, one second later) the landing place is checked like a zone
    change.
  - **Professions (the owner's request, 2026-11-19):** `SKILL_LINES_CHANGED` with
    `GetProfessions` and `GetProfessionInfo` (both in the Forever client's UI source code, folder
    `Camelot`; not checked in game). Kinds `profession` (profession learned, picture: hammer
    `hammer.tga`) and `skill` (milestone every 75 points, picture: the number). The last state per
    profession is in `FamulusCharDB.skills`. A profession that shows up for the first time with
    75 or more points already existed before the chronicle and is only remembered; switching on
    creates no entry. Both kinds are shared (`FIELDS` in `Sharing.lua`); the profession name
    travels in the sender's language. This includes the two main professions, First Aid, Fishing
    and Cooking.
    A click on the card opens the profession window (the owner's request):
    `C_TradeSkillUI.OpenTradeSkill(skillLine)`, not in combat (`story.onClick` in `UI/Book.lua`,
    the card glows under the mouse). For companions the click opens their recipe book following
    Guildy's pattern (`Game/TradeSkill.lua`, `OpenBook`): the profession link can be built
    directly, `trade:<guid>:<spell>:<skill>`, and `SetItemRef(link, text, "LeftButton")` opens
    Blizzard's window. The GUID comes from the friends list or guild roster at the time of the
    click (`ChronicleService.BookLink`), the spell per profession from `LINK_SPELL` (Mining:
    Smelting; Herbalism, Skinning and Fishing have no book and are not clickable). Only works
    while the person is online (according to Guildy also only on the same shard); otherwise a
    chat line says so. Professions of the player's own other characters are not clickable. The
    assistant's earlier statement that other players' professions could only be opened via a
    posted link was wrong.
    Not checked in game.
  - **Abilities (the owner's request, 2026-11-19):** What the character learns and can be
    recognised by its spell is in a table: `ChronicleService.abilities` with `id`, `spell`
    (main detection via `IsPlayerSpell`, the owner's decision), optionally `skill`
    (`{ line, rank }`, fallback via `C_SkillInfo.GetSkillLineInfoByID`), `also` (other spells
    that count as the same ability, another race's version), `class` (only this class asks for
    it), `sentences`, `picture` (name in `UI.media`) and `big` (milestone in the book).
    `ownJourney` checks the table in a loop on `SPELLS_CHANGED` and `SKILL_LINES_CHANGED`
    (`CheckAbilities`), only rows of the character's class (`UnitClass`) it has not learned yet.
    One kind `ability` for all: entry `{ ability = "<id>", name = <spell name>, level }`, state
    in `FamulusCharDB.abilities`; what is already learned when switching on is only remembered.
    - **A new ability is one row in the table.** The sentence names the spell as the reader's
      client names it (`C_Spell.GetSpellName` of `spell`; "Learned Bear Form", the texts
      `c_profession`/`c_their_profession`), otherwise with the name sent along. Only a row with
      `sentences` (riding) has its own `c_ability_<id>` and `c_their_ability_<id>` in every
      language; the test checks that the others have none. The book shows the spell's icon and
      tooltip; if the client has no icon, the picture is `picture`, without one the sparkle.
    - `riding` (spell 33388) and `ridingFast` (33391), both with horseshoe (`horseshoe.tga`) and
      as a milestone, fallback via skill 762 from 75 or 150 points.
    - **Class abilities (since 2026-11-27):** what a class quest teaches, for every class; the
      table names the level per row. The class mounts (paladin, warlock) are milestones with the
      horseshoe like riding. The Forsaken paladin's steeds are `also` of `warhorse` and
      `charger`; the sentence then names the main spell. The shaman's totems are items (see
      "Special items"). Moonkin is a talent, not a quest; a talent reset and relearning it
      writes nothing again. Poisons fall back on skill line 40.
      - The IDs come from Wowhead (Classic and Forever) and warcraft.wiki.gg, researched by the
        assistant; none checked in game. `/fam test` names every spell and item the client does
        not know (group `chronicle`, `CheckChronicleIds` in `Core/SelfTest.lua`); such a row
        is never recorded. Doubtful: `elunesGrace` (2651, reworked in Forever), `feedback`,
        `senseUndead`, `summonIncubus`.
      - Missing for want of IDs: the priests' Forever racials Divine Grace (human, 10),
        Confounding Flash (gnome, 10), Contingency Plan (gnome, 20); class quests of the
        Skyborne; Teleport: Moonglade (unclear whether quest or trainer). Left out on purpose:
        the mage's Study (Forever, for library books), the hunter's further pet spells and the
        totem spells (one entry per quest), level-60 quest weapons.
    - If a version does not know a companion's `id` (newer addon), it shows the
      spell name sent along ("… learns Swimming").
    - **No spell service and no profession service (checked 2026-11-19):** Only `ownJourney`
      queries spells (`IsPlayerSpell`). Professions need no table, because the client lists them
      itself; since 2026-11-23 `ChronicleService.Professions` reads them (name, icon, points,
      maximum, skill line) for `ownJourney` and the rail. A `SpellService` or
      `ProfessionService` pays off as soon as a feature outside the chronicle needs the same data
      (for example durability or profession helpers); then move the queries there.
  - **Special items (the owner's request, 2026-11-19):** the same principle via the
    item ID. Table `ChronicleService.items` with `item` (ID), optionally `class`, `picture`
    (default: chest, `chest.tga`) and `big`. `ownJourney` checks on `BAG_UPDATE_DELAYED` with
    `C_Item.GetItemCount(id, true)` (bags and bank) and only queries items the
    character has never had (`FamulusCharDB.items`); once they have all of them, the event costs
    nothing. Kind `item`: `{ item = <ID>, name, level, zone }`. The sentence names the item the
    way the reader's client names it (`C_Item.GetItemNameByID`), otherwise with the name sent
    along; there are no sentences of their own per item. **A new item is one row in the
    table.** What is already in the bags when switching on is only remembered. So far: 211527
    (the German "Schlafsack", a sleeping bag; ID from the owner) and the shaman's four totems
    from their class quests (5175 to 5178, `class = "SHAMAN"`). In the book an item shows the
    icon the game gives it (the owner's request; `C_Item.GetItemIconByID`, `story.texture` in
    `UI/Book.lua`): in its own colours, so without `UI.Tint`, with a cropped edge in the round
    frame. If the client knows no icon, the chest stands in the picture. This is
    the only place where the book shows a game texture instead of an own icon.
    The mouse over the picture shows the game's tooltip (the owner's request): for
    items `GameTooltip:SetItemByID`, for abilities from the table `SetSpellByID`
    (`story.item`, `story.spell`). Only such pictures catch the mouse; others do not. An
    ability this version does not know has no tooltip (the spell ID does not travel along).
    Not checked in game; an item that is used up immediately on receipt
    or never reaches the bags is not detected this way.
  - **First victory and instance cleared (the owner's request, 2026-11-28):** A boss the
    character defeats for the first time carries `first = 1` ("Archaedas defeated for the first
    time"); known bosses are in `FamulusCharDB.bosses` by encounter ID. The first call takes the
    character's boss entries already in the chronicle as known, so a kill from before the
    chronicle counts as a first. The last boss of an instance (`ChronicleService.finalBosses`,
    one row per wing) makes the entry "Uldaman cleared" instead: `instance` carries the
    instance's name (`GetRealZoneText` inside it), on every clear, not only the first. Both
    fields are shared; older versions drop them and show the plain boss. Still `BOSS_KILL`, not
    `ENCOUNTER_END`: `BOSS_KILL` already delivers the ID and the name, and whether
    `ENCOUNTER_END` fires in Forever's dungeons is not known. The encounter IDs come from the
    research in this pull request, none checked in game.
  - Two entries of the same kind in the same second count as a duplicate, unless they differ
    in `skill`, `rank`, `ability` or `item`.
- **Sample entries (2026-11-19):** `/fam chronicle demo` writes 21 made-up entries over three
  days (own ones and from two made-up companions, every kind at least once; since 2026-11-23 also
  three deaths in a row and two levels of a companion, so that the bundling can be seen; since
  2026-11-24 at the owner's request also a third companion, Lysa, and profiles with
  level and statistics for Mira, Borin and Lysa, so that the "Companions" tab shows something; a
  real profile of the same name is not overwritten), `/fam chronicle demo clear`
  removes them again (`ChronicleService.Demo`, `ClearDemo`). They carry `demo = true` and
  never leave the client: neither the live sending nor the catch-up nor the relaying
  sends them. Meant for looking at the book and for screenshots.
  `ChronicleService.Sample(kind, own)` gives one entry of a kind with the same people, zones and
  names, never stored, for the pictures of the settings (see "Settings tabs" in
  `docs/window.md`); `SampleClass(name)` their class, and a sample may carry `sampleAlias`, the
  alias the chronicle then names the person by.
  **Language (2026-11-24, the owner's request, for English screenshots):** Zones, names
  and people of the samples follow Famulus's language (`ns:GetLocaleCode()` in
  `Core/Locale.lua`), no longer that of the client (`GetLocale()`). In English the people are
  called Mira Stormfeather, Borin Ironbeard and Lysa Morningdew (German: Sturmfeder, Eisenbart,
  Morgentau), the same in both services, so that the references between chronicle and fellow
  travellers work. After a language change, write the samples again; the old ones stay in their
  language. What the client names itself stays in its language: items
  (`C_Item.GetItemNameByID`, "Schlafsack") and classes (`LOCALIZED_CLASS_NAMES_MALE`, "Magier").
  So for a fully English picture the client must be set to English. The test checks every
  language on a German client (see "Samples" in docs/languages.md). Checked against the mock only.
- **`companions`:** on `FRIENDLIST_UPDATE` compares the levels in the friends list with the last
  remembered state (by GUID). Shows companions under their alias.
- **`sharing` (the owner's decision, 2026-11-19):** Famulus talks to Famulus via
  whispered addon messages to friends and guild; protocol, relaying, statistics and
  queue are in [sharing.md](sharing.md).
- **Reactions (the owner's request, 2026-11-25: "celebrate the achievements of other players
  like on social media"; checked against the mock only, not yet seen in game):** A click on the
  reaction button of a friend's card in the book reacts to their event, a second click takes it
  back (since 2026-11-27 only the button, see "On the card"). The message
  and when it goes are under "Reactions" in [sharing.md](sharing.md); an option of `sharing`
  (`reactions`, default on), no feature of its own, so no service for the exchange is needed
  yet (see "No service of its own" there).
  - **One default reaction per kind (the owner's decision):** death 😢 `sad`, boss 💪 `strong`,
    level-up 🎉 `cheer`, profession milestone 👏 `clap`, special events (abilities such as riding,
    special items) 🎉 `cheer` (`ChronicleService.REACTIONS`, the first of each set). The assistant
    added: challenges 🎉, a profession learned 👏, arriving in a zone none (it happens all the
    time). A level seen on the friends list (`friendLevel`) has none: its time is the reader's, the
    friend's own entry has another one, so the two could not be matched.
  - **A set per kind (the owner's request, 2026-11-27: the fixed icons stay the defaults, holding
    the button brings a choice; a death gets no laughter or applause, rather something
    encouraging or sad; tried in game with one account, 2026-11-27, the owner: "Funktioniert";
    the exchange between two accounts not yet seen):**
    `ChronicleService.REACTION_SETS`, the default first: level `cheer clap strong`; challenge,
    ability, item `cheer clap fire`; boss `strong cheer clap fire`; death `sad strong heart`;
    profession and its milestones `clap cheer`. Two new icons, `heart` and `fire`, Phosphor Icons in the
    Bold weight like the other four (`heart-bold`, `fire-bold` in `tools/phosphor/`, from
    `@phosphor-icons/core` 2.1.1; the TGAs written by a temporary port of `phosphor()` to Node that
    redraws the other four byte for byte). Sets, the two icons, their names (`c_reaction_<id>`) and texts on the
    live feed (`c_reacted_heart`, `c_reacted_fire`) are the assistant's decisions, at most four a
    set so the bar stays short.
    - **The bar (`UI.ReactionPicker` in `UI/Widgets.lua`):** holding a reaction's button for 0.35 s
      (`HOLD`) or a right-click on it fades in a bar at its left with the kind's set (buttons as
      large as the one held, the one given lit, each naming itself in the game's tooltip). A click
      on one gives it; letting go of the held button over one does as well; the one given, picked
      again, takes it back (in the book). The click that ends a hold or the right-click does
      nothing else (`Picker.Consumed`); a plain click reacts and closes a bar still open. The bar goes once picked, once the mouse has been away from
      bar and button for 0.5 s (`LEAVE`), or with its button. Always at the left: the button sits
      at the right of the book's foot and of the feed's band, so the bar stays on its own card.
      One bar for all, built on first use, strata `FULLSCREEN_DIALOG`, no catcher over the screen
      (the feed lies over the game world); nothing runs while it is closed. Long-press is unusual
      with a mouse, so the right-click does the same and the book's tooltip says so
      (`c_react_more`).
    - **Given:** `entry.mine` holds the chosen reaction; another one replaces it
      (`ChronicleService.React(entry, reaction)`, `true` for the default). The friend's button
      shows the one given.
    - **Received:** `r = { [name] = reaction }` already held it; no migration. The player's own
      card shows the two given most (`ChronicleService.ReactionGroups`, each person once in a
      bundle): the first in front, the second 10 px further right half behind it, on a disc of the
      button's ground so the line icons do not cross (`button:Set(icon, lit, count, second)`), and
      the count of all. Its tooltip has a line per reaction, its icon then the names. Older
      versions take a reaction they do not know, or one of another kind's set, as the kind's
      default, so nothing breaks.
    - The website's demos still give only the default (`website/main.js`).
  - **Look (the owner's requirement):** one colour, following the colour scheme. The emojis are
    white icons (`sad.tga`, `cheer.tga`, `strong.tga`, `clap.tga`) tinted via `UI.Tint`, so they
    change with the colour scheme like everything else. The client cannot draw Unicode emojis.
    Shown at 18 px (in the book's reaction button at 16 px).
    **From Phosphor Icons since 2026-11-27 (the owner's choice):** our own line drawings read
    badly at that size (the clapping hands like a rune, even with a stronger line), so the four
    are Phosphor Icons in the Bold weight (MIT): `smiley-sad`, `confetti` (a party popper),
    `hand-fist` (Phosphor has no flexed arm) and `hands-clapping`. The SVGs and the licence are in
    `tools/phosphor/`; `tools/make_media.py` fills their paths (its own small SVG path reader, no
    library) into 64 px TGAs. The licence goes into the zip as `Famulus/Media/Phosphor-LICENSE.txt`
    (MIT wants it with every copy) and is named in `LICENSE` and on the website's legal page.
    Lucide and Tabler were looked at: neither has clapping hands. Not yet seen in game.
  - **On the card (`CardReaction` in `UI/Options.lua`, `UI/ChronicleCard.lua`):** a button at
    the right of the foot, on the line of the place: the same button as on the live feed's
    cards (`UI.ReactionButton` in `UI/Widgets.lua`; here 26 px with a 16 px icon, as the foot is
    only 14 px tall; on the feed 32 and 18), a rounded square with the reaction's icon. Since
    2026-11-27 (the owner's request, "the same as on the feed cards") only the
    button reacts; until then a click anywhere on a friend's card did, and the card carried the
    tooltip. A friend's card: the button muted until the player reacted, then in the accent on
    `accentDeep`; it glows under the mouse and its tooltip says "Click to react", "You
    reacted. Click again to take it back." and, while the friend has not been told yet, "… will
    see it as soon as you are both online.". The player's own card: the button in the accent,
    wider with the number of people who reacted, their names (with alias) in its tooltip, a
    click does nothing; no reaction to oneself. A bundled card reacts to its newest entry; a click on a
    bundle with a reaction anywhere in it takes them all back; on the player's own bundle the
    people who reacted to any entry count once.
  - **Professions:** a click on a friend's profession card opens the recipe book, as on the
    player's own card. From 2026-11-25 to 2026-11-27 the click on the card reacted and the book
    opened from the picture (`story.onPicture`, gone since the button reacts).
  - **Live feed:** a friend's reaction to one of the player's events appears as a card ("Mira
    celebrates with you", below it the event), with the reaction as the picture (kind
    `reaction` in `UI.BookPictures`). Its own switch `reaction` (default on), signal
    `CHRONICLE_REACTION`. Not limited to fresh events: a reaction that waited for the next
    greeting is still news. Once per person and entry (the owner's request, 2026-11-27): a
    reaction changed to another, or taken back and given again, keeps the book up to date but
    brings no second card; another friend's first reaction to the same entry does. Kept in
    `heard` on the entry (saved, so a `/reload` does not show it again).
  - **Reacting from the live feed:** a friend's card in the feed carries a button at the band's
    right end (32 px, the kind's reaction icon; `story.reaction` in `UI/Feed.lua`, built by
    `Reaction` in `LiveFeed.lua`; the look is `UI.ReactionButton`, shared with the book). A click
    gives the reaction as the button in the book does (`ChronicleService.React`, sent by
    `Sharing.lua` as before): the button lights up
    (accent icon on `accentDeep`), and the card closes a second later (`CLOSE`), whether the
    mouse is still on it or not; while the last three stay, it stays with the button lit. The feed only gives: a reaction is taken back in the
    chronicle, so a lit button does nothing more. No tooltip: the click and the lit button say
    enough (an earlier version had one; it was too much text). Only while reactions are on
    (`ChronicleService.ReactionsOn`, shared with the book); no button on the player's own
    cards, on reaction cards or on `friendLevel`. `/fam feed test` shows the button on its
    sample cards too; there it only lights up and closes the card and sends nothing, so the look
    can be checked with one account.
  - **Data:** on a friend's entry `mine` (the player's reaction) and `told` (what the friend was
    last told); on an own entry `r = { [<name>] = <reaction> }` and `heard = { [<name>] = true }`
    (whose reaction the live feed showed). Never sent with the entry
    (`FIELDS` in `Sharing.lua` leaves them out); they go with the entry when `Trim` drops it.
    Sample entries (`/fam chronicle demo`) bring a few: three friends cheered the level 40, Borin
    mourned a death, the player reacted to Borin's boss.
  - **Open:** who else sees reactions (see "Who sees what" in sharing.md). The website shows
    them since 2026-11-27. The clapping hands still look odd in game after the rework (the owner,
    2026-11-25: "later; the function matters first"); the other three icons are fine for now.
- **Rejected:** reading other players' statistics via the game's achievement comparison, as
  Guildy does. That only works for the targeted unit within sight and has led to disconnects
  with Guildy.
- **Live feed (`liveFeed`, the owner's request, 2026-11-19):** What the chronicle is recording
  right now appears as a card in the HUD, stays for a while and fades out
  (`Modules/Chronicle/LiveFeed.lua`, display `UI/Feed.lua`). Tried out in game by the owner
  (2026-11-19, "works perfectly", following the instructions: sample card, moving
  with `/fam feed`, Edit Mode, settings); which real events were triggered in the process is
  not recorded.
  - The feature listens to the internal signal `CHRONICLE_CHANGED`, not to the game: no
    game event, no timer of its own. That is why it is **on by default** (it does not act on
    the player's behalf and shows nothing without sharing). Only what is at most 120
    seconds old is shown: fresh events of companions (on request also own ones, see below),
    nothing caught up and no sample entries.
  - **Companions, own events only on request (the owner's request, 2026-11-24):** By default the
    feed only shows what companions experience. The option `own` ("My own events too",
    default off) adds the player's own. The former switch `companions` (events of
    companions, default on) was dropped for it, the assistant's decision: the companions are
    now the core of the feature, switching them off would mean switching the feature off, and
    with both switches off the feature would be on but show nothing. Whoever wants one of the two
    cases (own events only) can no longer have it; if that is missed, ask. With default values
    something only appears once "Share with friends" (`sharing`) or "Follow my friends"
    (`companions`) is running. A stored value of the old switch stays unused in the profile until
    "Reset" removes it. Checked against the mock only.
  - Switches per event kind (`level`, `death`, `boss`, `achievement`, `ability`, `item`,
    `profession`, `skill`, `zone`); only `zone` is off by default (the owner's requirement:
    zones rather not, level-ups yes). Plus `own` (own events too, default off),
    `sound` (see below), `duration` (4, 7 or 12 seconds) and `keep` (the last three stay, see
    "Sliding in, waiting its turn, keeping the last three"). A kind without a switch (newer
    version at the companion's end) stays invisible. A new kind needs an entry in `KINDS` and its
    two texts.
  - **Sound (the owner's request, 2026-11-25: "a simple 2-click sound"):** A card comes with a
    soft double click, `Media/click.ogg` (`UI.Feed.Chime` in `UI/Feed.lua`, which the fellow
    travellers' cards use too; `feed:Chime` in `LiveFeed.lua` plays it if the option is on, also for
    `/fam feed test`). The owner chose a file of Famulus's own over the game's click played twice
    (the assistant's advice: a menu click as a notice sounds like "I clicked something", and the
    `SOUNDKIT` IDs are unchecked in Forever). Option `sound` ("Play a sound", default on, because
    it only plays with a card that comes anyway). The assistant's decisions, except for the
    timbre:
    - **Timbre (the owner's choice, 2026-11-25):** a soft, round "tock-tock". The first version
      (two bright clicks at 1650 and 1852 Hz, 85 ms apart) did not please; of four tries
      (mechanical, soft, bright, both clicks at one pitch) the owner liked "soft" best, "maybe a
      little lower". Since then: two clicks 110 ms apart at 800 and 898 Hz (the second a whole
      tone higher), a faint wood-block overtone, little noise at the attack, 260 ms in all, peak
      about -6 dB, mono Ogg Vorbis, 5.9 KB. The owner chose 800 Hz over the same at 670 Hz
      ("800 Hz fits"), having heard both outside the game.
    - Written by `tools/make_sound.js` (the settings in `SOUND` at the top; other tries via
      `make({ ...SOUND, pitch: 670 }, 'try.ogg')`): Node draws the wave, ffmpeg (`libvorbis`) encodes it;
      the game plays only `.ogg` and `.mp3` from an addon folder. The noise is seeded and the
      encoder leaves out its version, so the script writes the same file again. ffmpeg was
      installed on the Windows machine via `winget install Gyan.FFmpeg` for this (2026-11-25).
    - Played with `PlaySoundFile(path, "SFX")`: it follows the game's sound effects volume and
      mute, like the game's own notices.
    - One sound for cards that come together: none within two seconds of the last (`QUIET`), a
      time stamp, no timer.
    - The game only finds a file that was in the addon folder at login or the last `/reload`.
    Checked against the mock only, not yet heard in game.
  - The card uses the book's pictures (`UI.BookPictures`, `UI.FeedStory`): icon, number
    or item icon. At most three cards one below the other, the newest on top. The cards do not
    catch the mouse, so clicks go through to the world; only the reaction button does (see
    "Reacting from the live feed"). While the mouse is on it the card stays past its time, a
    card already fading (or resting, see below) comes back, and once the mouse has left it goes
    1.5 seconds later (`LINGER`). After a reaction the card goes anyway (see there), unless the
    last three stay.
  - **Sliding in, waiting its turn, keeping the last three (since 2026-11-27, variant B
    "Groß, dann Zeile" on the page "Live-Feed: die letzten drei", claude.ai artifact
    `NG2VrKDsUdstcMhxs4orDQ`):** checked against the mock only, not yet seen in game.
    - **Only the newest card is large.** A new card comes in at the top from a little above
      (`ENTER_FROM`); the one before it shrinks to a slim row (`card.slim`, 34 px: a 24 px crest,
      then whose it is, a dot, what happened, on one line; no line below, no glowing dot, no
      bundle badge; the reaction button 24 px), the others glide down (`SLIDE`, `UI.Tween` with
      keys of their own per card, `card.slide` and `card.resize` for the band's size), and a
      fourth sinks a little and fades at the bottom (`Drop`). Before, the fourth vanished at
      once and the rest jumped. `Arrange` lays a card out for its form; `Layout` decides the
      form (`index > 1` or resting). In a row the name takes at most half of the room. People
      ("Who is nearby") show the people icon in a row instead of their crests.
    - **Every card is seen:** the newest stays on top for a moment before the next comes
      (`STEP` 1.2 s; with three waiting 0.9), so each is on screen for at least
      three of them. What comes sooner waits (`Feed.Waiting()`) as a stack behind the top
      card: up to two edges looking out above it and an accent badge "+4" at its top right
      (`Deck`, `PaintDeck`; they hang on the top card and move with it). Before, ten cards in
      one second showed only the last three; the other seven flashed by. A timer runs only
      while something waits (`Pump`; a sooner one takes over when more join, the older one
      then does nothing). This applies with the option off as well. The sound still comes
      when the news arrives, once for a burst, not when a waiting card comes in.
    - **Option `keep`** ("Keep the last three", off from the start): past its time a card
      rests instead of fading out, until newer cards push it out; the newest too becomes a row
      then, so at rest three rows stand there (about 115 px). `duration` says how long a card
      counts as new. **Resting fades only the content** (`card.body`, alpha `REST` 0.6; its
      line gone), never the card: a translucent band takes on the colour of what lies behind
      it. The first version faded the whole card to 0.72, and the owner found it took on too
      much of the accent (most likely the Edit Mode mark's, which the kept cards lie on).
      Pointing at
      the button of a resting card brings it up while the mouse is there. After a reaction the
      card stays with its button lit. Switched off, the resting cards fade at once
      (`Feed.SetKeep`, set by `LiveFeed.lua` on enabling and in `OnOptionChanged`). The cards of
      "Who is nearby" stay too while the option is on, as they are cards of the same feed;
      with the live feed off, nothing stays. After `/reload` or login the feed starts empty;
      showing the last three from the chronicle again was rejected (reactions and "Who is
      nearby" are not in the chronicle and could not come back).
    - **Bundles:** the same event of several friends within six seconds (`BUNDLE`) shares a
      card: a boss by its ID (else its name), deaths in one zone (a wipe), a challenge by its
      ID. `LiveFeed.lua` gives the story `bundle` (the key), `join` and `names`; the feed joins
      a story that waits or one on screen (not one fading), fills that card again and starts
      its time anew. The head names them ("Jaina, Thrall and 3 more": alias, else first name,
      three at most, `c_feed_others`), the crest's corner counts them like a bundle in the book
      (`card.badge`), the line below names only the place (who was with whom belongs to one of
      them), and a bundle has no reaction button. The player's own events never join.
    - **Edit Mode:** while the last three stay, the mark is as tall as one card and two rows
      with its label at the top (`Mark`, `MARK_HEAD`), and the cards lie in it instead of below
      it. The anchor itself (and so the clamping to the screen) keeps the size of one card.
    - Rejected: A (three large cards, about 250 px for good; built first, then the owner
      preferred B) and C (no waiting; the feed grows to seven for a burst and shrinks back).
    - **Sample burst (`/fam feed test`, `feed.Test` in `LiveFeed.lua`):** so that waiting,
      rows and bundles can be seen with one account, the command shows a burst instead of one
      card: first the player's own level with all three rows (the player's name and zone), then
      at the same moment four of the chronicle's samples (`ChronicleService.Sample`): Borin's
      boss and the same boss of Mira (one card for both), Borin's death and Mira's item. They
      wait as a stack, come in one after another and shrink to rows; with "keep" they stay.
      The cards are built as real ones are (`Story` in `LiveFeed.lua`, shared with
      `OnChronicleChanged`), only their buttons light up and send nothing (`SampleReaction`).
      The kinds' switches do not apply; nothing is stored or sent; one sound. A bundle needs
      friends, so only the sample shows one with one account.
  - **Three rows (the owner's choice, 2026-11-27, variant A on the canvas "Famulus
    Live-Feed-Karten", claude.ai artifact `Nc3TTNw84YyQTuXhekkBNQ`):** The text stood on one
    line as a whole sentence ("Papa (Borin Ironbeard) defeats Edwin VanCleef"), so the band grew
    up to 460 px and long sentences were cut off. Since then the card orders its text like a card
    of the book: a head row with a glowing dot in the accent and whose it is, small (11 px
    semibold, `textDim`; `story.chip`, as in the book); the dot is the one on the book's line
    (6 px, `UI.GlowDot`), in place of the class icon of the first version, which
    at 14 px was only a speck of colour in game (the owner's idea, 2026-11-27); the event without name and place (14 px
    medium); below it the place first, then what else the line says (12 px, `textMuted`). With
    all three rows the band is 76 px tall, else 64; it is 230 to 340 px wide and cuts off what is
    longer. `UI.FeedStory` in `UI/Options.lua` reads an entry that way (`Placeless`, as the book).
    A friend's reaction: the friend in the head, "Celebrates with you" (`c_reacted_<reaction>`,
    without the name since then), the event below. "Who is nearby": the names in the head,
    "Also in Tanaris" or "Now in Tanaris too"
    (`ui_near_here`, `ui_near_came`, the zone only), levels below. The player's own events have
    no head. `/fam feed test` shows all three rows with the player's own name and zone (see
    "Sample burst").
    Rejected: B (the name as the title), C (the event as the title, the name below), D (the
    sentence wrapping onto two lines), E (the name as a tag on the band's top edge). Checked
    against the mock only, not yet seen in game.
  - **Running-out line (since 2026-11-25):** along the card's foot (2 px, 10 px in from its
    ends, accent gradient) a line shrinks to the left over the duration plus the fade-out, so it
    is gone when the card is (`card.bar`, a `Scale` animation of the client; hidden when it ends,
    stopped when the card goes). A card the mouse holds on its reaction button stays past
    its line. The picture of the feed in its settings loops it. With it the accent mark at a
    milestone's left is gone; a milestone keeps the accent border (`cardActive`). Checked against
    the mock only, not yet seen in game.
  - **Shape "crest on the banner" (chosen by the owner on the mockup, 2026-11-19, draft B1):**
    The picture is a square crest (72 px, corners 14, border two pixels in the colour of the kind)
    and sits centred on a banner (56 px tall), 14 px from the left end of the banner; it sticks
    out 8 px at the top and bottom. The owner's requirements: the picture is larger than the area behind
    the text, banner remains visible to the left of the crest, and the banner must not be too
    narrow compared with the crest. Rejected: medallion (round, text slides out from under it),
    banner (picture centred above centred text), a crest that only sticks out upwards (B2), and
    the first crest with a 40 px tall banner without margin on the left. The banner is as wide as
    its text needs (230 to 460 px, since 2026-11-27 to 340 px, see "Three rows"); the cards stand left-aligned one above the other (the owner's
    requirement), not centred; milestones (`story.big`) carry an accent border (see
    below). The crest was seen in game (the owner then asked for left-aligned cards).
  - **Crest in the banner (the owner's decision, 2026-11-19, after looking in game):** The
    crest no longer sticks out beyond the banner but sits inside it (banner 64 px tall, crest
    48 px); the gap of 14 px to the left of the crest stays. Seen and confirmed in game ("that's
    good like this"). The details on the overhang in the paragraph
    above are therefore outdated.
  - **Look like the options cards (the owner's request, 2026-11-19):** The card of an
    event in the book and the banner of the feed are built like the card of a feature in the
    window (`CreateCard` in `UI/Options.lua`): background `card` with hairline and highlight
    edge; what stands out (there a running feature, here a milestone) has the accent border
    `cardActive` and the accent mark on the left (the feed's banner no longer has the mark, see
    "Running-out line"). The glow behind milestones was dropped for it.
    In the book additionally: heading 13 px medium like the rows, the glow under the mouse
    (`hover`) on clickable cards, and "whose event" stands in a sunken strip at the bottom
    (`sunken`, like an option below its feature) instead of as a mark in the text. The feed
    also carries the window's background: grain that fades out towards the bottom (`UI.Grain`),
    and the darkening towards the bottom (`dusk`). What "take cues from the options boxes" was
    meant to mean exactly was interpreted this way by the assistant; not yet seen in game by the
    owner.
  - **The player's own level-up is not shown in the feed** (the owner's decision,
    2026-11-19): the game shows it large itself. It still stands in the chronicle; the switch
    "Level-ups" only applies to companions. That stays so, even when `own` is on.
  - **Open (2026-11-19):** On reaching level 20 the owner did not see a card
    ("I think"). The entry was correctly in the saved data, the feed was on,
    duration 4 seconds, position right of centre. Whether the card did not come or was overlooked
    is unresolved. Since then the feature writes one line per card into the `devLog` in developer
    mode (`FEED`, "shown: <kind>", since 2026-11-27 also "waiting: <kind>" and "joined: <kind>",
    or "failed: …"; `ns:DevLog`), without names or text.
  - **Position:** default top centre; saved account-wide in `FamulusDB.feed` like the
    window position. Moving in the game's Edit Mode or with `/fam feed`
    (`/fam feed reset` resets it, `/fam feed test` shows a sample card): then a highlighted area
    shows the position and can be dragged. The role model is FlareUI, which brings a fork of
    LibEditMode for this (`Libs/FlareEditMode`). Famulus only adopts the core: `HookScript` on
    `OnShow`/`OnHide` of `EditModeManagerFrame`, via `feature:HookScript`. Not adopted: snapping
    to the grid, settings dialog in Edit Mode, position per Blizzard layout; for those the library
    calls methods of the manager and notes taint itself in the process. Whether the hook stays
    without a warning in the Forever client is not checked in game.
- **Class and name (the owner's request, 2026-11-24; checked against the mock only):** Next to
  a friend's name stood a circle with the initial; now the game's class icon stands there
  (`UI-Classes-Circles`, `UI.ClassIcon`/`UI.SetClass` in `UI/Widgets.lua`, which the fellow
  travellers' crest also uses) in the rail (list "Friends", stats cards); if the class is
  unknown, the rail keeps the letter. In the head of a card in the book it stood too until
  2026-11-27; since then the name stands alone there (see "Strip with name and time"). The
  player's own characters' classes are still read by the settings' picture of sharing (the
  player's crest). After an alias the character name stands in brackets,
  "Papa (Borin Eisenbart)" (`ChronicleService.Label`), everywhere the chronicle names the
  person: strip, rail, filter line "Only events of …" and the sentences of the live feed. Without
  an alias only the name stands there.
  - **Option** "Character name behind the alias" (`general.chronicleNames`, default on) as its
    own entry under the heading "Display" in Chronicle › Settings, below the features (until
    2026-11-25 a card of its own, see "Settings tabs" in `docs/window.md`). Off: only the alias. The
    option only applies to the brackets; the class icon has no switch (confirmed by the owner,
    2026-11-24).
  - **The character name no longer stands in the line below the heading** ("Jaina Proudmoore ·
    in Duskwood" was the former place below an alias). The assistant's decision: with the
    option on it would otherwise appear twice, and whoever switches the option off does not want
    to see it. It is likewise dropped as the second line of the stats cards.
  - **Where the class comes from** (`FamulusDB.chronicle.classes = { [name] = "MAGE" }`, via
    `ChronicleService.Class`): friends with Famulus send their class with the stats (`1~S~…`,
    see "sharing"); "Follow my friends" picks it up from the friends list when it records a
    level-up (`className` in the client's language, translated back via
    `LOCALIZED_CLASS_NAMES_MALE`/`_FEMALE`, `SocialService.ClassFromName`); the player's own
    characters enter their class with every own entry and at login (only if the
    chronicle already exists). The sample data have classes as with the fellow travellers (Mira
    mage, Borin warrior, Lysa priest). Only stored for people with an entry or stats; the
    rest drops out on loading. The fellow travellers' data are deliberately not read (see
    "Chronicle and fellow travellers": each area stands on its own).
  - **Guild roster and friends list as a source (the owner's request, 2026-11-24, separate PR;
    checked against the mock only):** When the window shows the chronicle's "Everyone" or
    "Friends", it looks once into the friends list and guild roster (`SocialService.Classes`,
    built like `SocialService.Online`) and remembers the classes of the chronicle's people
    (`ChronicleService.LearnClasses`). The guild roster names the class of every member, even
    offline, already in the form `MAGE` (eleventh value of `GetGuildRosterInfo`, passed on by
    `SocialService.EachGuildMember` as the fifth value); the friends list only for
    friends who are online. Online/offline in the rail still comes from
    `ChronicleService.OnlineCheck`; that is two looks into the lists per build, deliberately not
    merged, so that `SocialService` stays at one question per function. This happens while
    building the tab, before the rail, so the
    class is visible right away. No game event, no timer: without an open window nothing
    runs for it. Only remembered for people with an entry or stats; "My journey" does not
    look. Not checked in game: whether the client loads the guild roster by itself after login
    (otherwise only once "Share with friends" requests it or the guild window was open).
  - **Gaps:** A friend with an older Famulus, not in the guild, who has neither levelled up
    since the update nor been online while the window was open, still shows the letter.
  - The website's book names people by name alone, as the addon since #69; its rail keeps
    initials in the class colour (no graphics from Blizzard on the page).
- **The three recording features are off by default**, because the test fixes that with default
  values no game event is registered. Whether the chronicle should record by default is an
  open decision for the owner.
- **What the client provides (researched 2026-11-19 in the UI source code, branch `forever`, and
  in the wiki; none of it checked in game):**
  - Without the friend's involvement only level, zone and online status are visible (friends
    list, Battle.net, guild roster). Other players' deaths, bosses, loot and achievements are not.
  - Addon messages exist (`C_ChatInfo.SendAddonMessage`, 255 bytes, throttled). According to
    the measurements of the addon BFF, WHISPER and PARTY arrive on Forever, CHANNEL does not. In
    boss fights and locked maps nothing is sent and anything received is discarded; nothing is
    delivered later if someone was offline.
  - The combat log is locked for addons: there is no cause of death.
  - Achievements are called "Legacy Challenges" in Forever; `ACHIEVEMENT_EARNED` and
    `GetAchievementInfo` exist.
  - Death of a group member via `UnitIsDeadOrGhost`, not via `UnitHealth` (secret).
  - Pictures: class and race icons, item icons, map art; portrait and 3D model
    only for units present; no screenshots in the window.
- **Similar addons:** "BFF – Best Friends in Forever" already has a friends feed with
  level-ups and deaths via a whisper network between the addons; "Guild Chronicle" a
  guild death book with a parchment look. So the data alone are not a unique selling point; the
  opportunity lies in the presentation and in the connection with the aliases.
