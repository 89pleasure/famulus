# Famulus – project knowledge for AI assistants

Famulus is an addon for **World of Warcraft: Forever** that improves, eases and extends playing
together among friends and in the community. This file records what the owner wants, which rules
hold for all work and what you need to know about the Forever client. The knowledge about the
individual areas is in `docs/` (see "Knowledge in `docs/`").
As of: 2026-11-26, version 0.1.0.

## Requirements from the owner

The owner plays WoW Forever and has tried three collection addons and likes them: **OneForAll**,
**FlareUI** and **Polestar**. Famulus is to take its cue from them and to focus on, and limit
itself to, the following:

1. **Modern, clear layout.** Polestar is the owner's favourite so far.
2. **Playing together at the centre (the owner's decision, 2026-11-23).** Famulus is to improve,
   ease or extend playing among friends and in the community. The features are the
   **chronicle**, the **fellow travellers** and the **aliases** (since 2026-11-23). No unit frames,
   action bars, guides, damage meters or the like.
   - **Order (the owner's decision, 2026-11-24):** The aliases come last of the three everywhere,
     in the addon (sidebar, master switches) as on the website (navigation, sections, texts) and
     in the README and the project description. Before, they came first everywhere. The reason
     given in the code ("they serve the other two") is the assistant's interpretation.
   - **Quality of life removed (2026-11-23):** "Countless other addons already do that."
     Removed are the 16 QoL features (vendor, quests, loot, social, tooltips, interface), the
     journal (it only kept track of these automations), the pause key, the building block
     `mirror` (`Core/GameOptions.lua`), `PopupService`, `QuestService` and their self-test checks.
     If you want to see how they were built: git history up to commit `66f68ec`.
     Do not build them back in without asking.
3. **Analyse the weaknesses of the three role models and learn from them.**
4. **Optimised for performance.**
5. **Multilingual.** English, German, French, Spanish and Italian (since 2026-11-26; before,
   English and German). Polish and Ukrainian are translated but not offered until the game's
   fonts show their letters (see docs/languages.md).

**Publishing:** Since 2026-11-24 a first alpha is to appear on CurseForge, with automatic upload
(the owner's decision, see "Publishing on CurseForge"; before that, as of 2026-11-16: later, time
and platform open). The feature set and design are still not finished and take priority over
release work. So make decisions that work for players you do not know: clean versioning, no
assumptions about your own addon collection, behaviour next to other addons in mind.

Way of working: The owner writes German and wants replies in German. **Everything that lives in
the repo is English** (the owner's requirement, 2026-11-25): code, comments, commit messages, pull
requests, the README, this file and `docs/` (until 2026-11-25 this file and `docs/` were German).
Other languages stay only where they are content: the strings in `Locales/`, the German website
texts. The README has
been English and kept short since 2026-11-24 at the owner's request (before that German and
detailed); details belong here or in `docs/`, not there. What Famulus learned from OneForAll,
FlareUI and Polestar is no longer in it ("since we are now in a quite different place
thematically"); the table below stays.

## Knowledge in `docs/`

This file contains only what holds for almost any work. The knowledge about individual areas is
in `docs/`; read the matching file before you work in that area, and only then.

| File | Content | Read when … |
|---|---|---|
| [docs/window.md](docs/window.md) | The window: layout (header, sidebar, tabs), areas, master switches, reset, search, colours and colour schemes, no light mode, accents and effects, background (grain, embers), cards, shape, font (how the client loads Inter) | you work on the window, widgets, colours, effects or fonts |
| [docs/chronicle.md](docs/chronicle.md) | Chronicle: book with rail, chapter as a play session (route), picture book, weighting and layout of the cards, pictures, `ownJourney` (zones, professions, abilities, special items), sample entries, `companions`, live feed (`liveFeed`), class and name, what the client offers | you work on the chronicle, the book (`UI.Book`) or the live feed |
| [docs/sharing.md](docs/sharing.md) | Sharing between players: protocol, guild, relaying, statistics, queue and throttling, catching up in rounds, analysis "Many users" | you work on addon messages or `Sharing.lua` |
| [docs/fellows.md](docs/fellows.md) | Fellow travellers: data, counting, friends and guild only, cleanup, secret values, window (overview, "Your story", profile card), groups, bond, daily log, sample data, nearby (friends and guild in your zone) | you work on the fellow travellers |
| [docs/languages.md](docs/languages.md) | Languages: which ones and how they are chosen, clients without a language of their own, plural forms (`ns.Plural`), upper and lower case, fonts, how the translations are written, samples per language | you add or change texts, add a language or work on `Core/Locale.lua` |
| [docs/aliases.md](docs/aliases.md) | Aliases: data, key, `chatAliases`, `tooltipAliases`, `aliasMenu`, other addons and `guildyAliases`, alias for a Battle.net account | you work on the aliases or on support for other addons |
| [docs/testing.md](docs/testing.md) | Tests against the mock, state of checks in game (self-tests, bug 2026-11-24), testing in game (paths, `/fam test`, `/fam dev`, Lua errors, BugSack) | you test in game, hunt a bug from the game, work on the mock or want to know what is already confirmed in game |
| [docs/branding.md](docs/branding.md) | Name, logo, tagline, rejected names and logos | you work on the name, logo or tagline |
| [docs/website.md](docs/website.md) | Website: technology, layout, demos, campfire in the header, window in the header (screenshot), languages, hosting, what to update when the addon changes | you work on `website/` or the window changes visibly |
| [docs/release.md](docs/release.md) | Publishing on CurseForge: packager, tags and file types, release steps, version, licence, project logo, project ID, open items | you prepare a release or work on workflows, `.pkgmeta`, `LICENSE` |
| `docs/curseforge/` | Description and logo of the CurseForge project page | the project page changes |
| `docs/superpowers/` | Specs and plans of single projects (as of their date) | the origin of a decision is unclear |

- **Loaded automatically:** A `CLAUDE.md` in a subfolder imports the matching file
  (`@…/docs/<file>.md`); Claude Code loads it as soon as a file there is read:
  `Famulus/Modules/Chronicle/` (chronicle, sharing), `Famulus/Modules/Fellows/`,
  `Famulus/Modules/Aliases/`, `Famulus/Locales/` (languages), `Famulus/UI/` (window; it also names which UI files belong to the
  chronicle and to the fellow travellers), `tests/` (testing), `website/`, `.github/` (release).
  If you work outside these folders (for example `Core/`, `tools/`), read up yourself. A new
  `CLAUDE.md` under `Famulus/` is kept out of the zip by `.pkgmeta`, `website/CLAUDE.md` is removed
  by the workflow before publishing; anywhere else, check whether it would be published.
- **New knowledge goes into the matching file in `docs/`, not here.** Only what holds for almost
  any work belongs here (requirements, rules, workflow). A new file gets a row in the table.
- References of the form "see X" point to a heading or a bold entry; the table says which file it
  is in.
- What is "checked against the mock only" and what is confirmed in game is noted with each
  entry; `docs/testing.md` has an overview.

## WoW Forever: what you need to know

The game came out on 2026-11-04 and is newer than the training knowledge of most models. Do not
reason from memory about "Classic"; look things up:

- Blizzard's UI source: `github.com/Gethe/wow-ui-source`, branch `forever`
- `warcraft.wiki.gg/wiki/Patch_1.60.1/API_changes` and `…/wiki/Secret_Values`
- Source of the role models: `github.com/smoergi/OneForAll_Forever`, `github.com/malkkav/FlareUI`,
  `github.com/fitzforge/polestar`

Researched facts (as of 2026-11-16, the game is patched often):

- Game version 1.60.x, `## Interface: 16001`. A plain `Addon.toc` is enough.
  Addon folder: `World of Warcraft/_forever_/Interface/AddOns/`.
- It is the **modern retail API** (as of 12.x "Midnight"), not the Classic API:
  `C_Container`, `C_AddOns`, `C_Item`, `C_Spell`, `C_GossipInfo`, `C_QuestLog`, `C_Map`,
  `TooltipDataProcessor`, `Settings.*`, `MenuUtil` and `AddonCompartmentFunc` exist.
- Removed: the globals `GetItemInfo` and `GetSpellInfo` (use `C_Item.GetItemInfo`,
  `C_Spell.GetSpellInfo` instead). Contrary to the research, `ChatFrame_AddMessageEventFilter`
  still exists in the client (self-test 2026-11-16), as does `ChatFrameUtil.AddMessageEventFilter`;
  use the `ChatFrameUtil` variant for new code.
- **Addon restrictions as in Midnight:**
  - "Secret values": such values must not be compared, tested for true/false, used as table keys
    or used in arithmetic. Passing them on and `string.format` are allowed. Check with
    `issecretvalue(v)`; in the addon via `ns.IsSecret`.
  - `COMBAT_LOG_EVENT_UNFILTERED` is useless for addons.
  - `CopyToClipboard` is protected. Chat messages can be "secret" in combat.
- Writing fields onto Blizzard's StaticPopup dialogs causes taint ("action blocked"); reported
  as a bug for Polestar.
- Game content: level 60, Vanilla-like world, ground mounts only, four bags plus a reagent bag.
- Already part of the standard UI, so do not rebuild: auto loot, bag sorting, Edit Mode,
  cooldown numbers, damage meter, instant quest text. According to the UI source also
  (2026-11-23, not checked in game): a calendar with invites (the clock button on the minimap,
  `Blizzard_Minimap/Camelot/GameTimeFrame.lua`) and a Vanilla-style group finder
  (`Blizzard_GroupFinder_VanillaStyle`, `AllowLoadGameType: classic, camelot`).
  In the UI source Forever is called `camelot`. "Recently played with" (`Blizzard_RecentAllies`)
  only loads in retail (`mainline`), so it is missing in Forever.

## What was learned from the role models

| Weakness of the role models | Rule in Famulus |
|---|---|
| Events registered permanently, option checked only in the handler (OneForAll: ~38 events) | A feature registers events only in `OnEnable` |
| Unthrottled `OnUpdate` handlers | Nothing runs per frame while idle |
| Switching needs `/reload` (FlareUI modules, OneForAll language and profile) | Everything takes effect at once |
| Hooks stay active after switching off | Hooks only via `feature:HookFunction`/`HookScript` or `feature:Once` plus `feature:Guard`; they only act while the feature is on |
| Megabytes of code and data at every login (Polestar: 70–250 MB according to issues) | The window is built on first opening; no libraries |
| Replaced Blizzard functions, overwritten methods of other addons | Only `hooksecurefunc`; replace nothing, write nothing into other tables |
| ~90 options, inconsistent defaults, a chat message per action | Few features, one rule for defaults, one summary line per action |
| FlareUI without German; Polestar languages as extra addons | All languages built in and checked for parity by the test |

## Chronicle and fellow travellers

On 2026-11-24 the owner asked whether it makes sense to keep the two apart. The assistant's
assessment: keep them apart, because they differ in their basis. The chronicle lives on your own
events and on what friends with Famulus send (friends list and guild, shares data); the fellow
travellers on the group roster (anyone from a group, strangers too, nothing is sent, up to 500
people; since 2026-11-24 on request friends and guild only). But they had grown into each other in
four places: the same word "companions" for two circles of people, two "profiles", two books per
person with partly the same cards, and the fellow travellers' boss names came from the chronicle.
Of three variants (clear line; fellow travellers as the only place for people; merge), the owner
chose **"clear line"**. The rule since then:

- **The chronicle tells what happened; the fellow travellers show who you play with and how close
  you are.** Nothing one area shows is repeated in the other; they refer to each other.
- **Names:** The people of the chronicle are called "Friends" in the window (tab, rail, feature
  "Follow my friends", texts of the live feed); "companions" now appears only with the fellow
  travellers ("Closest companions"). The shared numbers are called "Stats" (German "Bilanz"), no
  longer "profile". In the code `companions`, `ui_tab_companions`, `c_profiles` etc. stay.
- **Two books per person with different questions:** Chronicle › Friends, filtered to one person,
  shows their own journey; "Your story" with the fellow travellers only what you share (days
  together, shared bosses, bond, first meeting). The entries "from <name>'s chronicle" there are
  gone. References: "In the chronicle" on the person's card, "Your story" above the filtered book
  of the chronicle; both only if the other area is switched on and knows the person.
- **Each area stands on its own:** The fellow travellers remember the names of shared bosses
  themselves (`k` in the daily log) and read the chronicle only for the reference.
- Implementation and terms are the assistant's decisions within the variant ("Friends", "Bilanz",
  "Stats", "In the chronicle", bosses with names only in groups). Checked against the mock only,
  not yet seen in game. The website still shows the old state (tab "Companions", "Profiles").
- **Ideas only the fellow travellers can do:** Regular groups (who is in a group together again
  and again) are in the tab "Groups" since 2026-11-24 (see "Fellow travellers"); shared dungeons
  per person are proposed, not commissioned. The groups keep to the rule as well: they show who
  was out with whom and when, not what happened (no deaths, no own levels, bosses only as a
  number). Since 2026-11-25 the fellow travellers also show who of the friends and guild is
  nearby (tab "Nearby", see "Nearby" in docs/fellows.md): who you could play with right now,
  read from the friends list, Battle.net and the guild roster, nothing sent.

## Rules for new code

These points are design decisions; `tests/run.lua` checks most of them.

- **Feature registry:** Everything that can be switched is a feature via `ns:NewFeature`, **one
  file per feature** under `Modules/<Category>/<Id>.lua` (both capitalised, e.g.
  `Modules/Aliases/ChatAliases.lua`); the test checks this. What the self-test needs to read
  (lists, CVar names) hangs on the feature object.
- **Life cycle via the feature class** (`Core/Features.lua`); the registry cleans up when a
  feature is switched off: events via `feature:RegisterEvent`, recurring timers via
  `feature:StartTicker`, delayed single calls via `feature:After` (they lapse when switched off).
  Hooks cannot be removed: `feature:HookFunction` (`hooksecurefunc`) and `feature:HookScript` set
  them once and let them act only while the feature is on; for other hook APIs `feature:Once`
  plus `feature:Guard`.
- **Services for shared code:** What several features need is a service instead of copied code.
  A service is **always** called `<Name>Service`: file `<Name>Service.lua`, table
  `ns.<Name>Service`, no feature in it (the test checks this). That way every call shows whether
  something is a service (`ns.AliasService.Get`), a feature (`ns.features.chatAliases`) or a plain
  helper (`ns.IsSecret` in `Core/Init.lua`). Services for all categories live under `Core/`
  (`ChatService`: check plain text, check the chat lockdown; `GroupService`: who is in the group;
  `SocialService`: who is a friend, a Battle.net friend or in the guild, who of them is online,
  which class the lists name, and names from lists in one spelling. Whoever reads the friends
  list, guild roster or Battle.net friends does it via `SocialService.EachFriend`,
  `EachGuildMember` and `EachBattleNetFriend` (since the review of 2026-11-24 also chronicle,
  sharing and account aliases); only the self-test reads the client directly on purpose. A name in
  any spelling is compared by `SocialService.Key`; `AliasService.Key` stays the key aliases are
  stored under), services for one category in its folder (`Modules/Aliases/AliasService.lua`,
  `Modules/Chronicle/ChronicleService.lua`). A service follows the state of its features via the
  internal signal `FEATURE_STATE` instead of every feature registering and unregistering it in
  `OnEnable`/`OnDisable`. In the `.toc` a service comes before the features that use it.
- **Category master switch:** Every category has a master switch (option `categories.<id>`,
  default on, switch under Settings › General). If it is off, no feature of the category runs,
  however it is set itself: no events, no timers, hooks stay silent. The individual choice stays
  saved. The check sits in `ns:SyncFeature`; a feature needs to do nothing for it.
- **`requires`:** Give every client API needed as a path (`"C_FriendList.GetNumFriends"`). If it
  is missing, the feature stays off and shows as "not available".
- **Defaults:** Anything that acts on the player's behalf, sends messages to other players or
  listens to game events is `default = false`. Only harmless things are on. Exception:
  `accountAliases` listens only once the player has created an alias for a Battle.net account
  (see "Aliases").
- **Chat:** Feedback via `ns:Notify` (can be switched off), at most one line per action.
- **Global names:** only `FamulusDB`, `FamulusCharDB`, `SLASH_FAMULUS1/2`,
  `Famulus_OnAddonCompartmentClick` and the named frames `FamulusOptionsFrame` and
  `FamulusMinimapButton`.
- **Cost while idle**, fixed by the test: loading creates two frames; after login with defaults
  no game event is registered, no `OnUpdate`, no timer.
- **Texts:** Every key of `Locales/enUS.lua` in **every** other locale file, with the same
  placeholders in the same order. Scheme: `area_<area>`, `cat_<category>`, `f_<feature>`, `o_<feature>_<option>`,
  `g_<general>`, `msg_<chat>`, `c_<chronicle>`, `ui_<window>` (tabs: `ui_tab_<id>`); help text
  ends in `_desc`. Read texts only at run time via `ns.L`, never cache them at load time, or
  switching the language breaks. A text with a number goes through `ns.Plural(key, n)` (Polish and
  Ukrainian have three forms); upper and lower case only via `ns.Upper`, `ns.Lower`, `ns.Capital`
  (`string.upper` changes only A–Z). See `docs/languages.md`.
- **Settings:** Only what differs from the default is saved (`ns:SetOption`).
- **Window:** Rows are built automatically from features and their `options`
  (`type = "toggle"` or `"select"`; addon options also `"swatch"`); in a settings tab each feature
  is an entry with the icon it names (`icon`, a name from `UI.media`). New widgets belong in
  `UI/Widgets.lua`. Never set colours directly; use colour names with `UI.Paint` (surfaces),
  `UI.Tint` (images) or `UI.Ink` (text): only then does the open window follow a change of colour
  scheme. Texts via `UI.Text` (font and fallback).

## Left out on purpose

| Feature | Reason |
|---|---|
| Make URLs in chat clickable | Own link types unconfirmed in the Forever client, chat can be "secret", `CopyToClipboard` is protected |
| Quality-of-life features (vendor, quests, loot, tooltips, map, chat, camera) and the journal | Many other addons have them; Famulus concentrates on playing together (2026-11-23, see "Requirements") |
| Moving Blizzard frames, collecting minimap icons | The role models' main source of taint and addon conflicts |
| Anything around the combat log | Not usable for addons |
| Aliases on unit frames, raid frames, nameplates | Overwriting text on Blizzard's FontStrings risks taint; names are often secret in combat. See "Aliases" |

## Workflow

```bash
luajit tests/run.lua
```

```bash
luajit tools/read_selftest.lua
```

```bash
python3 tools/make_media.py
```

```bash
python3 tools/make_fonts.py <Inter-release>/extras/ttf   # needs fontTools
```

```bash
node tools/make_shot.js <screenshot.jpg> <x> <y> <width> <height> website/assets/shots/window   # window for the website
```

```bash
node tools/make_sound.js   # the live feed's sound; needs ffmpeg (FFMPEG=<path> if not on the PATH)
```

```bash
rm -f dist/Famulus-*.zip && zip -rq dist/Famulus-0.1.0.zip Famulus -x '*.DS_Store'
```

Windows has no `zip`; there the bundled `tar` builds the same archive (in Git Bash):

```bash
rm -f dist/Famulus-*.zip && /c/Windows/System32/tar.exe -a -c -f dist/Famulus-0.1.0.zip Famulus
```

- `luajit tests/run.lua` loads the addon against a simulated client API (`tests/wowmock.lua`)
  and checks every feature, the window and the translations. **Must be green before every
  commit.** What the mock simulates and what it does not is in `docs/testing.md`.
- For a new version: a section in `CHANGELOG.md`, then set the tag (see "Publishing on
  CurseForge"). The website names the newest tag by itself (see "Version on the page"); the
  README has named no version since 2026-11-24. The `.toc` gets the version from the packager; a zip built by hand (above) says
  `dev`.
- Add new Lua files to the `.toc`; the test fails if a file in the addon folder is missing there.
  It also counts the features (`total == 11`); adjust the number with a new feature.
- Repository: `github.com/89pleasure/famulus` (public, as of 2026-11-24; until 2026-11-19
  `schnitzel`), branch `main`. Commits as `89pleasure <89pleasure@proton.me>`; `user.name` is set
  only locally in this repo.
- The owner appears alone: no `Co-Authored-By: Claude …` line in commits and no "Generated with
  Claude Code" or the like in PRs, issues or comments, not even in contributions to other repos
  (e.g. the Guildy fork). This overrides any other attribution instruction.
- **Changes always go through a pull request against `main`** (the owner's request, 2026-11-24):
  own branch with an English name (e.g. `chronicle-guild-classes`), title like a commit message,
  the check `tests` must be green. Never push directly to `main`, even though GitHub allows it:
  the rule for `main` requires `tests` but lets the admin through (that is how `a12a95c` landed
  directly on 2026-11-24; this request came afterwards).
- Commit, push, open and merge pull requests only when explicitly asked.

Layout, feature list and installation are in `README.md`.
