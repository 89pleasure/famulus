# Fellow travellers

Part of the project notes; requirements, rules and the index of all files are in
[AGENTS.md](../AGENTS.md). References of the form "see X" point to a heading or a bold entry;
the index there says which file it is in.

**Name (2026-11-27, the owner's choice):** players see the area as "Fellowship" (German
"Gemeinschaft", French "Communauté", Spanish "Comunidad", Italian "Compagnia", Polish
"Drużyna", Ukrainian "Братство"), in the addon, on the website and on CurseForge; the people
in it are "companions" (as in "Closest companions"). Before: "Fellow travellers" /
"Weggefährten" ("Gefährten" / "Companions" was proposed and declined). These notes and the code
keep "fellow travellers" and `fellows`, so no saved data changed. The window's screenshots on
the website still show the old name until the next capture.

Idea from a list of ideas by the assistant (2026-11-23), picked by the owner: Famulus remembers
who the player was in a group with. Reasoning: Forever lacks "Recently played together" (Recent
Allies, see "WoW Forever: what you need to know" in AGENTS.md), and the feature does not need Famulus on the other side.

- **The owner's decisions (2026-11-23):** an area of its own (not a
  sub-area of aliases or chronicle; one entry in the sidebar). First version: the list (who, when, where, how often, how long)
  and chronicle boss entries that name who was there. **Not** chosen: notes on people,
  a hint in the tooltip, an "Add friend" button. Do not build them without asking.
- **Structure:** category and area `fellows`, one feature `rememberFellows`
  (`Modules/Fellows/RememberFellows.lua`, off by default because it listens to game events), data
  via `ns.FellowService` (`Modules/Fellows/FellowService.lua`). Who is in the group right now comes from
  `ns.GroupService` (`Core/GroupService.lua`), which the chronicle uses as well.
- **Data:** `FamulusDB.fellows = { [guid] = { name, level, class, first, firstZone, last, zone,
  times, seconds, bosses, tag } }`, account-wide, outside the profiles, by GUID (a name can
  change). `tag` is the BattleTag if the person was recognised as a Battle.net friend in the group
  (since 2026-11-24, see below). None of it is sent. At most 500 people; beyond that, whoever has
  been absent the longest drops out (never anyone from the current group). In addition, since
  2026-11-24, the groups in `FamulusDB.fellowRuns` (see "Groups").
- **Counting (the assistant's decisions):**
  - Events: `GROUP_ROSTER_UPDATE` and `PLAYER_ENTERING_WORLD` sync the list with the group,
    `BOSS_KILL` counts a boss for everyone present, `PLAYER_LOGOUT` ends all times
    (the saved data is written afterwards, also on `/reload`). No timer: the time
    is added up on every sync and on logout; only the part since the last sync
    is lost in a crash.
  - A new "time together" starts only after a 30-minute break (`MEET_GAP`); a disconnect
    or `/reload` does not count twice.
  - Not counted: members who are offline (`UnitIsConnected`), names the client does not know
    yet (`UNKNOWNOBJECT`), battlegrounds and arenas (`IsInInstance` returns `pvp`/`arena`).
    Raids count too; option `raids` (on by default) switches them off.
  - "Where" is the player's zone (`GetRealZoneText`), not the member's.
- **Friends and guild only, cleanup (the owner's request, 2026-11-24):** Reason: the chronicle
  only hears from friends and guild members, while the fellow travellers remembered everyone from
  a group. Requested were an option for this and a cleanup for former friends and guild members.
  Implementation and texts are the assistant's decisions.
  - **Option `friendsOnly`** ("Only friends and guild", off by default so that nothing changes in
    the previous behaviour): from the group, only those count who are on the friends list,
    are a Battle.net friend or are in the guild (`SocialService.Unit`: `C_FriendList.IsFriend(guid)`,
    `C_BattleNet.GetAccountInfoByGUID(guid)`, `UnitIsInMyGuild(unit)`; all three present and not
    secret according to the API docs of the `forever` branch; the first two run through `pcall`,
    because `IsFriend` requires the friends list to be loaded). While the option is on, the feature
    additionally listens to `FRIENDLIST_UPDATE`, `PLAYER_GUILD_UPDATE`, `BN_FRIEND_LIST_SIZE_CHANGED` and
    `BN_CONNECTED` (Blizzard's friends frame registers all four as well in the Forever source,
    `Blizzard_FriendsFrame/Camelot`): whoever becomes a friend or Battle.net friend while in the
    group counts from then on, whoever stops being one no longer counts from then on. Whoever is
    already on the list stays there. Not on `BN_FRIEND_INFO_CHANGED`, which comes with every status
    change of a friend. Without the option the sync only asks for the BattleTag
    (`SocialService.BattleTag`), not who is a friend.
  - **Battle.net friends count as friends** (the assistant's decision): the game's friends list
    shows them too, and the owner has Battle.net friends (see account aliases). The
    chronicle cannot talk to them; it only whispers character names. Only someone the client
    explicitly calls one counts as a Battle.net friend (`isFriend` or `isBattleTagFriend` true;
    according to the API docs of the `forever` branch both are never nil). When in doubt, someone
    is not a friend, and their BattleTag is not remembered.
  - **Cleanup** ("Settings" tab, its own card below the feature): removes everyone who is
    currently neither on the friends list nor a Battle.net friend nor in the guild, so also
    strangers from the time before the option. The assistant's decision: "former" cannot be
    determined for older entries, because it was never noted who was a friend back then, and
    whoever wants only friends does not want the strangers either. Whoever is in the group right
    now stays, even a stranger the option is not counting at the moment (`GroupService.Members`,
    not only the counted ones); the sample fellow travellers go too (they are nobody's friend).
    That is why the row is called "Alle außer Freunden und Gilde entfernen" / "Remove everyone but
    friends and guild"; the first version ("Remove former friends and guild members") promised
    less than the button does (review 2026-11-24, approved for fixing by the owner). Should the
    cleanup only hit former friends after all, Famulus would have to start remembering who was a
    friend; ask.
    The row names up to five names
    (alias, otherwise name) and counts the rest; the "Remove" button asks first, like "Reset"
    ("Really remove?", four seconds). The first click remembers whom the row counted;
    the second removes only those, and only if a fresh look shows they are still strangers.
    Whoever joins the list in between stays. Works even with the feature switched off, because it
    only touches saved data. A chat line says how many there were. The search finds the
    row by its name, not by the names in it. The lists are only read when the
    row is shown, not already while the tabs are built (the search does that on every key for
    all tabs). Technique: row type `action` in
    `UI/Options.lua` (button on the right; `item.button`, `confirm`, `armed`, `usable`, `click`, plus
    `item.find` for the search), `FellowService.Outsiders` and `RemoveOutsiders`.
  - **Sync** (`SocialService.Circle`): one look at the friends list, guild roster
    (`GetGuildRosterInfo`, 17th value GUID) and Battle.net friends; matching is by GUID, by name
    (any spelling, without realm) and by BattleTag. Offline, Battle.net friends can only be
    recognised by their BattleTag (the client names their character only while they are online).
    That is why the list remembers the BattleTag (`tag`) as soon as someone in the group is
    recognised as a Battle.net friend, regardless of the option. An old `tag` stays and then simply
    no longer matches. Limit: whoever has not been in the group since this version has no `tag`; if
    such a person is only a Battle.net friend and currently offline, the cleanup would take them for
    a stranger. The names in the row show this before the click. This does not contradict the rule
    of not collecting Battle.net friends (see aliases): the BattleTag is only remembered for people
    who are on the list anyway.
  - **A list is still missing** (review 2026-11-24: before, the cleanup only waited for the
    guild roster; an empty friends list or a disconnected Battle.net would have turned all friends
    into strangers): `SocialService.Circle` then returns `ready = false` and, as a third value,
    what it is waiting for. The cleanup shows the reason instead of the names, the button is off:
    - `friends`: the friends list is empty and no `FRIENDLIST_UPDATE` has come since login
      ("Your friends list is still loading."). Requested with `C_FriendList.ShowFriends`. An
      empty list counts as real only once the client has sent it; if it has entries, it counts
      immediately.
    - `guild`: in a guild, but `GetNumGuildMembers()` returns 0 and no roster from earlier in
      the session is kept ("Your guild roster is still loading."). Requested with
      `C_GuildInfo.GuildRoster`. Since 2026-11-26 an empty roster later in the session no longer
      waits: the last one stands in for it (see "Empty guild roster" in docs/sharing.md).
    - `battlenet`: `BNConnected()` returns false; without a connection the client knows no
      Battle.net friends ("Battle.net is not connected right now …"). It waits for
      `BN_CONNECTED`; nothing can be requested.
    Requests go out at most every 15 seconds; the event stays registered until it comes, then
    the window rebuilds (`SOCIAL_CHANGED`). The second click takes a fresh look once more:
    if a list is missing then (say Battle.net went away in the meantime), nobody goes, and the row
    names the reason.
  - **Not checked in game:** everything. Above all, whether the guild roster in Forever also lists
    members who are offline, and with GUID (otherwise the cleanup would take them for strangers).
    `/fam test` reports this (group `names`, "guild roster" and "friends list", numbers only, no
    names; plus group `api`). Also whether `C_BattleNet.GetAccountInfoByGUID` answers for Battle.net
    friends in the group (otherwise, with the option, no pure Battle.net friend counts), whether
    `C_FriendList.ShowFriends` fires a `FRIENDLIST_UPDATE` even with an empty friends list (otherwise
    the cleanup would stay at "is still loading") and whether `BNConnected` answers in Forever.
- **Secret values (researched 2026-11-23 in the API docs of the `forever` branch):** `UnitName`,
  `UnitGUID` and `UnitClass` are only secret if the unit is not player-controlled or not in
  the group (`SecretWhenUnitIdentityRestricted`); so for group members they are readable even in
  combat. `UnitLevel` is never secret. Every value is checked anyway. The service recognises the
  player's own character in a raid by GUID, not by `UnitIsUnit` (its comparison is secret on
  restricted maps). `C_FriendList.AddFriend` carries `HasRestrictions = true`; whether an addon
  may call it is unchecked.
- **Window (redesign 2026-11-24):** The owner found the two lists "boring" next to the
  chronicle. From four drafts (Profile card, Album, Encounter book, Bond; canvas
  "Fellow travellers – drafts") the owner chose a mix; description and plan:
  `docs/superpowers/specs/2026-11-24-fellows-redesign-design.md` and
  `docs/superpowers/plans/2026-11-24-fellows-redesign.md`. Checked against the mock only.
  - Tabs "Overview", "Groups" (since 2026-11-24, see "Groups" below) and "Settings".
    Icon: two figures (`people.tga`).
  - **Overview** (`FellowModel` in `UI/Options.lua`, drawn by `UI.FellowOverview` in
    `UI/Fellows.lua`): on the left "Closest companions", the three with the most time together as
    tiles (rank I–III, crest with ring, name in the book font, level and class, tier
    badge, numbers, foot "in your group now" or "last together … in …"; under the mouse they glow
    like a clickable card in the book, since 2026-11-24 at the owner's request). Below that
    "Everyone else · N" with a choice of "Last seen" / "Most time together" (sorts only the list)
    and the list with column headers, at most 60 rows (`FELLOW_ROWS`) plus "N more". Up to three
    people there is no list; with no people, the hint on how to get started.
  - A click on a tile or row opens the person's story (the owner's decision,
    2026-11-24: with the sidebar, a profile card next to the overview would be too cramped).
    The sorting applies for the session.
  - **Your story** (`FellowStory`): fixed on the left the **profile card** (320 wide): crest, name,
    level and class, online line ("in your group now" or "last together …"), then the bond
    bar, below it the number bar and "met …", with "at level N" in a line of its own
    below it so that the sentence does not wrap (the former second line
    "last together …" below it has been dropped since 2026-11-24, it repeated the online line; the
    owner's request after a screenshot), then at its foot one row of square icon buttons
    (`button:SetIconOnly`, `PlaceButtons` in `UI/Fellows.lua`), each named by the game's tooltip
    under the mouse. "Whisper" (speech bubble, 40 px, in the accent; see "Whisper" below) stands
    on the card's middle axis like everything above it; "Set alias" (tag, `ns:EditAlias`) to its
    left, "Forget" (bin; the cross on the rows has been dropped; a chat line says so) to its
    right, both 34 px and outlined; "In the chronicle" (flag, only if there is one) left of the
    alias, so the row is then one-sided. Without a whisper the rest is centred. With labels they
    needed two rows. To the right of it scrolls a
    book (`UI.Book`, 560 wide; the owner's request after the first look in game: person
    on the left, book on the right instead of a wide header above a book that was too wide) with
    one chapter per play session as in the chronicle (since 2026-11-25, before that per day with
    the zone as title), the newest first: title by time of day, on the left from–to or the date, on
    the right "N h together". It is still built from the daily log: per day one card "On the road
    in <zone>" (the last zone of the day; without a zone "Together on the road"); an evening across
    midnight, which the log splits over two days, is one card. Limit: the log only knows
    the first and last moment per day, two evenings on one day stay one card; the
    groups could separate them. A boss without counted time stands at 12 noon of its day. Below
    the card (from to; bosses without names, for instance from a raid, as a number
    after it; until 2026-11-24 the duration stood there too, wrapped and repeated the
    chapter head, so it was removed at the owner's request), one card per named boss ("Archaedas
    defeated", "in Uldaman"), "You are
    now <tier>" on the day of a tier-up and "Met" (at level N). If meeting lies
    before the log, it stands in a last chapter of its own. Since 2026-11-24 it holds
    only shared things from its own daily log, nothing from the chronicle (see "Chronicle and
    fellow travellers"). If the chronicle has entries for the person (`ChronicleService.Who`, name
    in any spelling) and it is switched on, the card carries the button "In the chronicle"
    (the flag): it opens Chronicle › Friends, filtered to the person. Instead of the tabs,
    "All fellow travellers" stands at the top; another tab, another page or closing closes
    the story.
  - **Layout of the profile card (the owner's decision, 2026-11-24, on the canvas
    "Fellow travellers – person card", claude.ai artifact `EyiMx3kvy6qkrjnkYKV8eX`: variant B
    "Number bar", with the bond bar above the numbers instead of below them):** Reason:
    the card looked untidy, the time was too large (17 px semibold, wider than its
    column). Rejected: A (calm list), C (large ring, time as a sentence, path of two dots),
    D (left-aligned with sections). The bond bar (`UI.TierBar`, replaces the
    ladder with four dots) names the tier on the left (accent from Trusted) and the next on the
    right, below it three segments for the three steps, filled as far as one has come, and
    centred "… more together". The number bar is a recessed box: the time on
    half the width, times and bosses on a quarter each, separated by hairlines; all numbers
    20 px semibold, with the time "h" and "min" small next to it (under an hour only
    minutes, on the full hour only hours). Seen in game (screenshot from the owner,
    2026-11-24, Mira from the sample data): bar, segments and number bar as planned,
    "h" and "min" sit on the baseline. After that the level at meeting moved into a
    line of its own, because "…, at level 29" wrapped the sentence tightly. The card stays at full
    height (the owner's decision, 2026-11-24, instead of shrinking it to its content); in return
    there are 32 px each between person, bond, numbers and meeting (`SECTION_GAP`,
    before 18 to 22), so that even a two-line "met …" ends well above the buttons.
    Neither has been seen in game yet.
  - **Whisper (since 2026-11-27):** a speech bubble on every tile (top right, opposite the
    rank), at the end of every row of the list, and on the card open the chat box with a
    whisper to the person (`ChatService.Whisper`, `ChatFrameUtil.SendTell` as in "Nearby"); a
    tooltip names it. Nothing is sent until the player writes. A click on the bubble does not open the
    story. Fellow travellers may be strangers and offline; the game says so when the whisper is
    sent. Without `ChatFrameUtil.SendTell` neither bubble nor button shows. The name is the stored
    "First Last" without a realm, unlike "Nearby", which whispers the name as the friends list or
    guild roster writes it, realm and all. **Open in game:** whether a whisper to "First Last"
    reaches someone the lists write as "First Last-Realm".
  - The search still finds every person as a simple person row (`FellowItem`, `tab.search`).
    Under an alias the name stands in the second line. The class comes from
    `LOCALIZED_CLASS_NAMES_MALE`, so in the client's language.
- **Groups (the owner's decision, 2026-11-24, on the canvas "Fellow travellers – timeline",
  claude.ai artifact `L3v3BWqAv717ro24NVyQGF`: variant B "Groups with their own log"):**
  **Name (the owner's choice, 2026-11-25):** The tab is called "Runden" / "Groups"; the owner did not like
  the first name "Verlauf" / "Timeline" ("a bit unattractive"). Also proposed:
  "Unterwegs" (on the road), "Lagerfeuer" (campfire), "Gemeinsam" (together). In code the tab is
  still called `timeline` (`ui_tab_timeline`, `TimelineBook`, `TimelineRail`). The owner's
  question was whether a view that shows the stories of all fellow travellers is worth it. The
  assistant's recommendation: not all individual stories one below the other (that would be a
  second book of the chronicle), but when you played together and with whom. Rejected: A,
  a diary from the existing daily log (one card per person and day; who was together in
  a group could only be guessed from it, and there is no total time in groups). Checked
  against the mock only, not yet seen in game. The details of the implementation and the deviations
  from the canvas are the assistant's decisions:
  - **Group log** (`FamulusDB.fellowRuns`, account-wide, outside the profiles, nothing is
    sent): per group `f`, `l` (from, to), `z` (the zones in chronological order,
    at most six), `b` (bosses) and `who = { [guid] = { f, l } }` (who was there from when to
    when). In a raid only `raid = true` and `n` (the most people at once), no names,
    the same rule as for the bosses. At most 30 days (like the daily log) and 400 groups.
    `FellowService.Sync` records them; `Runs()` returns the groups and the current one.
  - **A group** lasts as long as someone in the group is counted. Whoever comes later or leaves
    earlier changes nothing about the group, only their own `f`/`l`. After a break of less than 30
    minutes (`MEET_GAP`) with at least one of the same people the old group continues
    (`/reload`, disconnect, short break), otherwise a new one starts. That is why the evening
    on the canvas (Uldaman, then Tanaris with Mimi) is one group "On the road in Uldaman and
    Tanaris", because Mimi stayed the whole time; Borin and Lysa carry "until 22:40".
  - **Zones:** for this `rememberFellows` additionally listens to `ZONE_CHANGED_NEW_AREA`
    (`FellowService.Move`), only while the feature is on. If you return, the zone appears in the
    log a second time, in the card's title only once.
  - **Book** (`TimelineBook` in `UI/Options.lua`, tab `timeline`): one chapter per play session
    as in the chronicle (`SESSION_GAP`, `SessionTitle`); chapter head with from–to and "N h
    together". Per group one card without a picture (`story.noPicture`): title "On the road in …" (in
    a raid "Raid in …"), below it from–to, duration and bosses as a number (in a raid
    also the number of people), below that per person a plaque with class icon and name
    (`story.people`; alias, otherwise first name; "until …" or "from …" for whoever came more than
    five minutes later or left earlier). If a group of at least two of the same people comes back,
    the foot says so in the accent colour (`story.foot`): "Again with Mira and Borin · 6 times in 30
    days". Deviation from the canvas ("For the 3rd time with …"): only what the log still
    knows is counted, so 30 days, and the sentence says that; that way English needs no ordinals.
    The subgroup chosen is the one that was together most often, on a tie the larger one; the
    names are ordered by time together. In between "Met Lysa" (only whoever was met in a shown
    group) and "You and Borin are now Trusted" (the moment taken from the groups,
    counted from the time before them like `Milestones`), both with the crest instead of a picture
    (`story.crest`); a click opens "Your story". From Trusted on, the new tier is a
    milestone (larger card), below that not, as with the badge. Groups under one minute
    without a boss and groups none of whose people are still on the list do not appear.
    At most 50 events, below them "Older groups are kept …".
  - **Rail** (`TimelineRail`): "This week" (time in groups alone in its row, for that
    `wide` in `UI/Rail.lua`; groups, fellow travellers, met, new bond), "Most frequent
    group" (the subgroup that was together most often in the last seven days, from twice;
    crests side by side, not overlapping as on the canvas, new card type `group`) and "Most
    time together" (up to five people with their time this week, without online/offline; a
    click opens "Your story").
  - Nothing from the chronicle, see "Chronicle and fellow travellers". "Forget" and "Tidy up" also
    take the person out of the groups; a group without people then drops out. The search finds
    nothing here; it finds the people in the overview. Without a group the tab shows how to get
    started.
  - Whoever already had fellow travellers before this state sees under "Groups" only the groups
    from the update on; daily log and "Your story" stay as they are. The website does not show
    the groups yet.
- **Bond (the owner's decision on the mockup, 2026-11-24):** tiers by time
  together, `FellowService.TIERS`: Begegnung under 1 h, Bekannt from 1, Vertraut from 10, Unzertrennlich
  from 40 (German names; enUS: Encounter, Acquainted, Trusted, Inseparable; the assistant chose the
  English names). `FellowService.Tier(seconds)` returns tier, progress and remainder. Shown as a ring
  around the crest (`UI.Crest`), badge (`UI.TierBadge`, accent from Trusted) and bar
  (`UI.TierBar`, until 2026-11-24 the ladder `UI.TierLadder`). The ring is a paused `Cooldown` swipe with `ring.tga` (without
  `OnUpdate`; the highest tier stands just short of the end, because an expired cooldown draws
  nothing; `noCooldownCount` keeps OmniCC and similar away); if `Cooldown:Pause` is missing, a full
  ring without progress. The class icon comes
  from `UI-Classes-Circles` with `CLASS_ICON_TCOORDS`, otherwise the initial letter. `/fam test`
  checks both (group `media`).
- **Daily log (since 2026-11-24):** per person `days = { [YYYYMMDD] = { s, z, b, f, l, k } }`
  (seconds, last zone of that day, bosses, first and last moment, the named bosses) and
  `firstLevel` (the player's level when meeting). `k = { { t, n, z } }` (time, boss,
  zone) exists only in a group, at most twelve per day (`MAX_KILLS`); in a raid only
  `b` counts, so that 39 people do not store every boss of the evening (the same rule as `with` and
  `others` in the chronicle). At most 30 days, the oldest drops first. A
  stretch across midnight counts for the day on which it ends. Tier-up days are computed when
  building (`FellowService.Milestones`), from the time before the log (`seconds − Σ s`), so that
  earlier time does not invent milestones. Broken days drop out on load.
- **In the chronicle:** If a boss falls in a group, the entry carries `with` (the names, in a
  group up to four) or `others` (only the number, in a raid, so that 39 names per boss do not
  bloat the data). The line below reads "in Uldaman  ·  with Mira and Tom" (alias, otherwise
  first name) or "with 12 others". This applies as soon as "Record my journey" runs, regardless of
  the fellow travellers' switch. Both fields are missing from `FIELDS` in `Sharing.lua` and are
  therefore not shared. The sample boss in `/fam chronicle demo` has two companions. The fellow
  travellers no longer read `with` since 2026-11-24; they remember their bosses themselves (`k` in
  the daily log).
- **Sample data (2026-11-24, the owner's request):** `/fam fellows demo` adds six
  made-up fellow travellers (classes, levels, zones; Mira and Borin as in the chronicle),
  `/fam fellows demo clear` removes only them (`FellowService.Demo`, `ClearDemo`;
  `FellowService.SamplePerson(index)` gives one as a stored person, never stored, for the
  pictures of the settings, see "Settings tabs" in `docs/window.md`). They carry
  `demo = true` and GUIDs `Player-0-FAMDEMO..`. Language as with the chronicle's samples (since
  2026-11-24 Famulus's); the three others are called in English Kael Thornwood, Tomas
  Greywind and Ena Silverbrook.
  - **Since the groups (2026-11-24)** they come from eleven made-up evenings over three weeks
    (`DEMO_RUNS`, groups with `demo = true` that never merge with real ones); days, times,
    bosses, meeting and the last-seen line are computed from them, the way counting would have
    written them. Before, the days were invented and matched no group. The most recent
    evening is today's once 23:20 has passed, otherwise yesterday's. Times now: Mira 32
    h 20 min, Borin 20 h 50 min, Lysa 3 h 35 min, Ena 3 h 30 min, Kael 1 h 15
    min, Tomas 25 min (before, 25 minutes to 31 hours). Mira and Borin still tell a
    tier-up (Trusted), named bosses exist in Uldaman and the Deadmines, Mira and Borin
    are the regular group (six times in three weeks).
- **Not checked in game:** everything. In particular: whether `UnitName` returns first and last name
  for `party1`… as for `player`, whether `GROUP_ROSTER_UPDATE` comes by itself after login (otherwise
  `PLAYER_ENTERING_WORLD` catches it), whether `IsInInstance` reports `pvp` in Forever and whether
  `BOSS_KILL` fires in Forever dungeons. `/fam test` checks the functions used (group `api`).

## Nearby (`nearbyFriends`)

Picked by the owner on 2026-11-25 from a list of new ideas by the assistant ("Wer ist in der
Nähe"), because it is of use without Famulus on the other side. Shows who of the player's friends
and guild is in the same zone or at a similar level. It reads the friends list, the Battle.net
friends who play this game and the guild roster; nothing is sent and nothing is stored. The
website shows the tab since 2026-11-27 (see "Demos" in docs/website.md), without the card and
without "Where your people are".

- **The owner's decisions (2026-11-25, on the canvas "In der Nähe – Entwürfe", claude.ai artifact
  `Ste3CibFuPCTWcoBaWXxaY`):** the card in form B, people's crests (class icon, ring of the bond)
  instead of a compass picture like the other live cards; a tab "In der Nähe" / "Nearby" with the
  fellow travellers; guild members count from the start. Everything else was the assistant's
  proposal, accepted without objection: no cards in cities and inns, the whisper button, the rail.
- **Structure:** feature `nearbyFriends` (`Modules/Fellows/NearbyFriends.lua`, category
  `fellows`, off by default because it listens to game events), the reading in
  `ns.NearbyService` (`Modules/Fellows/NearbyService.lua`; the window reads it too). Options
  `guild` (on), `cities` (off: in cities and inns many people are online at once) and `sound` (on).
- **Who:** online friends (`connected`), guild members online and not on the mobile app, Battle.net
  friends whose game is this one (`clientProgram == BNET_CLIENT_WOW`, `wowProjectID ==
  WOW_PROJECT_ID`, as Blizzard's friends frame decides it in `Blizzard_FriendsFrame/Camelot`).
  Not the player, and people in the player's group are left out of cards and list. Someone on
  several lists counts once (by `SocialService.Key`): "from" is the friends list before
  Battle.net before the guild; the zone from the friends list or guild roster beats Battle.net's,
  because Battle.net names it in the friend's language (a friend who plays in English only matches
  where the names are the same). The guild roster gives level and zone since this feature
  (`SocialService.EachGuildMember`, values 4 and 6). A whisper uses the name as the list wrote it,
  realm and all (`ChatFrameUtil.SendTell`, as Blizzard's friends frame does); Battle.net friends
  get a Battle.net whisper (see below).
- **Out of reach (the owner's request, 2026-11-27):** Forever has no servers as in retail, only
  modes (Normal, PvP, RP, RP-PvP), and friends can only play together in the same one. The tab
  showed Battle.net friends in another mode like anyone else, "Here in Tanaris" and cards
  included, because a zone is compared by its name. The owner still wants to see them and their
  progress. Friends list and guild hold only characters of the player's mode, so only Battle.net
  friends can be out of reach: another mode or the other faction (`factionName ~=
  UnitFactionGroup("player")`). The mode is the middle of the game account's `richPresence`
  ("Forever - PvP - Redridge Mountains", `NearbyService.Mode`), the player's own from
  `C_BattleNet.GetGameAccountInfoByGUID(UnitGUID("player"))`; without it only the faction counts.
  - **Why not the realm (in game, 2026-11-27):** `GetRealmID()` says 0, `GetRealmName()` is
    empty, and `realmID`, `realmName` and `realmDisplayName` are empty for every Battle.net
    friend. `C_BattleNet.IsGameAccountOnSameRealm` (which Blizzard's tooltip uses for "cannot
    cooperate") and the server in the GUID (`Player-6855-…`) differ even for a guild member in
    the same mode, and a whisper by character name to a friend in the same mode with another
    server arrives. Modes seem to be made of several connected realms (until 71037 their names
    read like "CAMWOW EU4 Realm 2 PvP"), and those answers name the home realm. A first version
    used them and set friends in the same mode apart. Layers cannot be read for a friend at all:
    Forever has no layer API, only group members (`UnitPhaseReason`), invites and visible players
    tell (VoidLayer's notes).
  - `NearbyService.People` gives `out` (the reasons as the window says them, "Realm PvP" with
    `ui_near_realm`, the faction's name from `FACTION_<NAME>`, joined by "  ·  "), `mode`,
    `faction` and `bnet`, the account name. Someone out of reach gets no card and does not count
    in "Here in …", "Similar level", "Also online" or "Where your people are"; the tab lists them
    last in a section of their own, "Out of reach · N · other realm or faction" (German "Außer
    Reichweite"), drawn faint (0.6), "Realm PvP" and the faction in its colour instead of
    "Battle.net".
  - The owner chose the proposal ("Ja, umsetzen") with the other faction counting as out of reach
    as well, and the tab keeps its name. The assistant's decisions: the name of the section, the
    words, the faint rows, no option to hide them. Checked against the mock only; the data it
    rests on was seen in game. Open in game: whether a friend in another language writes the mode
    the same way (it is compared as written). `/fam test` reports the player's own mode, the
    friends' modes and for how many the faction is named, without names (group `names`,
    "Battle.net modes").
- **Whisper to Battle.net friends (2026-11-27, the owner's request):** whoever was met on
  Battle.net first (not on the friends list or in the guild) gets a Battle.net whisper
  (`ChatFrameUtil.SendBNetTell(accountName)`, as Blizzard's friends frame does), out of reach or
  not: Battle.net reaches them in any mode. Before, only those found out of reach got it, and the
  character's name (Battle.net gives no realm) cannot reach another mode.
- **Cards** (the assistant's rules): one when the player arrives in a zone (`ZONE_CHANGED_NEW_AREA`,
  `PLAYER_ENTERING_WORLD`, switching on) for everyone there (head "Mira and Kael", title "Also in
  Tanaris"; three names at most, then "and 2 more"), three seconds later so the lists can answer; one when
  someone arrives in the player's zone or comes online there (head "Lysa", title "Now in Tanaris
  too"; the card's rows since 2026-11-27, see "Three rows" in docs/chronicle.md). Whoever
  turns up within two seconds shares a card. None in cities and inns (`IsResting`, unless
  `cities`), in instances, in flight; landing (`PLAYER_CONTROL_GAINED` after a look found the player
  on a taxi) is arriving, control back after a stun is not. The same person in the same zone at most
  once in 30 minutes (`REPEAT`). After a `/reload` the first ten seconds are only taken note of
  (`HUSH`). Who was in the player's group is in the last look, so leaving the group brings no card.
  The detail line of one person: level, class, then the bond's tier for a fellow traveller, else
  where the player knows them from ("Friends list", "Guild", "Battle.net"); of several, their
  levels. Crests: the closest bond first; one crest of 48 px or two of 40 side by side
  (`story.people` in `UI/Feed.lua`). Place, duration and "Keep the last three" are the live
  feed's (its cards wait their turn and stay like the live feed's); the sound is the same file
  (`UI.Feed.Chime`), with an option of its own.
- **Fresh lists:** friends list and Battle.net report changes themselves (`FRIENDLIST_UPDATE`,
  `BN_FRIEND_INFO_CHANGED`); the guild roster only comes when asked. While the feature is on, a
  ticker asks for both every 60 seconds (`POLL`; `NearbyService.Ask`, at most every ten seconds),
  and so does arriving and opening the tab. List events within a second lead to one look.
  `NEARBY_CHANGED` redraws the tab while it is open.
- **Tab "Nearby"** (`FellowNearbyTab` in `UI/Options.lua`, list `UI.NearbyList` in
  `UI/Fellows.lua`, rail card `places` in `UI/Rail.lua`): sections "Here in <zone>", "Similar
  level" (up to 5 levels apart), "Also online" (40 rows, the rest counted) and "Out of reach"
  (see above). A row: crest with the
  bond's ring, the alias or name, below it the name under an alias, class and from where; level and
  the difference to the player's; zone (the player's own in the accent); the bond's badge; a button
  that opens a whisper. A click on a fellow traveller's row opens "Your story". Beside it "Where
  your people are": the zones, the player's first, then the fullest, with the levels there.
  Switched off, the tab says how to switch it on. The search finds nothing here.
- **Open in game:** whether `FRIENDLIST_UPDATE` comes when a
  friend changes zones (otherwise the ticker catches it within a minute), whether the guild roster
  is refreshed every minute when asked, whether Battle.net's `areaName`, `characterLevel` and
  `className` are filled for Forever, and whether `PLAYER_CONTROL_GAINED` comes on landing.
  `/fam test` checks the functions used (group `api`).
