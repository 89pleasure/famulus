# Aliases

Part of the project notes; requirements, rules and the index of all files are in
[AGENTS.md](../AGENTS.md). References of the form "see X" point to a heading or a bold entry;
the index there says which file it is in.

Custom names for other players, modelled on the addon CustomNames
(`github.com/Jods-GH/CustomNames`, supports Forever). The assistant's decisions of
2026-11-16, not yet confirmed by the owner:

- **Category of its own, `aliases`,** with a master switch, as an area of its own in the sidebar (since
  2026-11-18, see "The window"). Tab "Names": input row (character name, alias,
  "Save") and one row per alias (a click loads it into the input row, the cross removes
  it); tab "Settings": the features. The search finds aliases and character names.
- **Data, not a setting:** `FamulusDB.aliases = { [key] = { name, alias } }`, account-wide,
  outside the profiles; "Reset" and switching profiles leave the list alone. Access only
  via `ns.AliasService` (`Modules/Aliases/AliasService.lua`); changes announce themselves with the
  signal `ALIASES_CHANGED`.
- **Key:** full character name, lower case, spaces and hyphens turned into "-". Forever
  has no realms but first and last names (`UnitName` returns `name, surname`); the client
  writes the same name with a space or a hyphen depending on the place. Which spelling the
  chat delivers is unconfirmed, hence the normalisation; the self-test (group `names`) records
  the separator and the form of `UnitName("player")` without storing a name.
- **An alias is plain text:** `|` is removed (no colours, textures, links), at most 48 bytes.
- **`chatAliases`:** `ChatFrameUtil.AddSenderNameFilter` changes only the text in the brackets; the
  link target stays the real name. The filter can be removed (`RemoveSenderNameFilter`), the
  client skips it by itself for secret names. Not `AddMessageEventFilter` (would also change the
  link target) and no hook on `AddMessage` (CustomNames replaces the method there). Lines already
  printed do not change. Option `style`: "Alias" or "Alias (name)".
  - **Online and offline notices (the owner's report, 2026-11-25: whispers, guild chat and
    tooltips showed the alias, "X has come online" did not; checked against the mock only, not
    yet in game):** these are `CHAT_MSG_SYSTEM` lines without a sender, so the sender filter never
    sees them. The same feature therefore also sets `ChatFrameUtil.AddMessageEventFilter` on
    `CHAT_MSG_SYSTEM` (removed again when switched off). In a player link
    (`ERR_FRIEND_ONLINE_SS`, "|Hplayer:%s|h[%s]|h has come online."; in retail also for guild members, unconfirmed in
    Forever) it
    changes only the text between the brackets, a class colour around it stays; the link target
    keeps the real name. That holds for every player link in a system line, not only the online
    notice. The offline notice (`ERR_FRIEND_OFFLINE_S`, "%s has gone offline.") has no link; the
    filter turns the game's text into a pattern and builds the line anew with the alias. Here
    `AddMessageEventFilter` is safe because only the text of the line changes, not `arg2`.
    Decisions of the assistant: part of `chatAliases` (no feature and switch of its own),
    `style` applies as in the chat. Details from the Forever source
    (`Blizzard_ChatFrameBase/Mainline/ChatFrameOverrides.lua`): filters run per chat frame and
    only on lines that are not secret; a whisper window of its own (`privateMessageList`) picks
    its partner's online/offline lines by comparing them with the game's text, so the filter
    leaves the line alone there. `/fam test` (group `names`, "online notices") checks that the
    online text has a player link and the offline text one `%s`.
  - **Not included:** the Battle.net notice "[Account] (Character) has come online"
    (`CHAT_MSG_BN_INLINE_TOAST_ALERT`): the chat frame builds it itself from `arg2` and
    `C_BattleNet`; `arg2` is also the target of the link (whispering by click), so a filter would
    have to change the target.
- **`tooltipAliases`:** a line of its own via `TooltipDataProcessor` (type `Unit`), only for
  players; the game's name line is not overwritten.
- **`aliasMenu`:** `Menu.ModifyMenu` on the player menus (`aliasMenu.TAGS`), appends "Set/Change/
  Remove alias". "Set" opens the window on the page with the name filled in
  (`ns:EditAlias`); no dialog of its own and no entry in `StaticPopupDialogs`. In the Forever client
  `contextData` carries `name` and `surname`, no `server`.
- **All alias features are on by default:** they do not act on the player's behalf and do nothing
  without an alias; they need no timer and, except `accountAliases` when an account alias exists,
  no game event.
- **Other addons (the owner's decision, 2026-11-18):** support them specifically, no
  public interface (Famulus is too unknown for others to integrate it).
  One feature per integration, `Modules/Aliases/<Addon>Aliases.lua` with `addon = "<folder name>"`:
  without the addon it stays off and is missing from the window; `## OptionalDeps` in the `.toc`
  loads the addon first. Only via its official extension points, replace nothing. Further ones are
  not settled yet. An automatic mechanism for all addons is not possible without
  `AddMessageEventFilter` (changes the link target) or overwritten methods (taint).
- **`guildyAliases` (2026-11-18, confirmed in game):** Guildy
  (`github.com/svengabr/Guildy`) builds its chat itself, the sender filter does not reach it, and
  it had no extension point. Hence a PR to Guildy (branch `name-formatter-api` in the fork
  `89pleasure/Guildy`): `GuildyAPI.RegisterNameFormatter(owner, fn)`,
  `UnregisterNameFormatter`, `Refresh`; Guildy asks the formatter in `W.ClassName`, links keep
  the real name. The feature registers a formatter there (option `style` as in the chat) and calls
  `Refresh` on `ALIASES_CHANGED`. At first the PR was to wait until Famulus is published
  (the owner's decision, 2026-11-18). Submitted on 2026-11-25 at the owner's request as
  `svengabr/Guildy#2`, after a rebase onto Guildy 1.16.0 (tests 858/0).
  **Merged on 2026-11-27 and released in Guildy 1.18.0** (`Core/API.lua` there, names and
  signatures unchanged, plus `GuildyAPI.version = 1`). Since then the regular Guildy from
  CurseForge is enough; the fork and a clone in the game folder are no longer needed. Guildy drops
  a formatter that raises an error (reported once) and strips `|` from what it returns. With a
  Guildy older than 1.18.0 the feature is simply missing; since 2026-11-26 the self-test counts
  that as ok ("addon Guildy lacks …; the feature is not offered") instead of a failure, and the
  bug report says "Guildy without the API it needs". Not yet seen in game with the released
  Guildy (only with the fork). Confirmed in game with the fork: aliases
  appear in Guildy. An earlier test via `/run` with a formatter of its own showed nothing;
  the cause was not cleared up, the integration itself works.
- **Alias for a Battle.net account (the owner's request, 2026-11-23, modelled on
  CustomNames; checked against the mock only, not yet in game):** An alias on the BattleTag applies
  to all of the friend's characters; you do not have to create one per character. Structure and
  limits are the assistant's decisions:
  - **Data:** `FamulusDB.accountAliases = { [battletag lower case] = { tag, alias, chars = { [key]
    = "First Last" } } }`, account-wide, outside the profiles. Only accounts with an alias are
    stored (no collection of all Battle.net friends). `AliasService.Set` and `GetOwn` take
    a character name or a BattleTag (`Name#1234`; a character name never contains "#").
    `AliasService.Get(name)` returns the character's own alias, otherwise that of its account:
    **The alias on the character takes precedence** (as with CustomNames). Chat, tooltip, Guildy and
    chronicle need no change for this.
  - **Where the characters come from:** The client only reveals which character a
    Battle.net friend is online with right now (`C_BattleNet.GetFriendAccountInfo(i).gameAccountInfo`,
    plus `GetFriendNumGameAccounts`/`GetFriendGameAccountInfo` for further licences; only
    `wowProjectID == WOW_PROJECT_ID`). `AliasService.ScanFriends` reads the list and remembers
    the characters permanently. A character the friend was never seen online with therefore
    does not have the alias yet. When an account alias is set, the list is read once right away.
  - **Feature `accountAliases`** (`Modules/Aliases/AccountAliases.lua`, on by default): listens to
    `BN_FRIEND_INFO_CHANGED` (names the slot in the list, then only that friend is read),
    `BN_FRIEND_ACCOUNT_ONLINE` and `BN_CONNECTED`, but **only as long as at least one account has an
    alias**. With default values, therefore, still no game event is registered; that is the
    reasoning for why it is on by default despite game events. Switched off, account
    aliases still apply to the characters already known.
  - **Window:** The name field takes "Character or BattleTag#1234". An account stands in the
    list with "Battle.net · tag · their characters" (or "no character seen yet"); the search
    also finds it via a character.
  - **Context menu:** additionally `MENU_UNIT_BN_FRIEND` and `MENU_UNIT_BN_FRIEND_OFFLINE`
    (`contextData.battleTag`, otherwise `contextData.accountInfo.battleTag`, that is how
    `FriendsFrame_ShowBNDropdown` sets it in the Forever source). Entries "Set/Change/Remove alias
    for all characters". They also appear in a character's menu if it belongs to
    an account with an alias or a Battle.net friend is online with it right now
    (`AliasService.FindBattleTag` goes through the friends list for this when the menu opens).
  - **Not included:** assigning characters to an account by hand or detaching them again (CustomNames
    can do both), an alias for one's own account, aliases in front of Battle.net whispers (the
    account name stands there anyway). A remembered character stays with the account until its
    alias is removed, even if the friend deletes it.
  - **Not checked in game:** whether `characterName` in Forever contains first and last name and with
    which separator (the key evens out space and hyphen), whether
    `wowProjectID` for Forever characters equals `WOW_PROJECT_ID`, the arguments of the three
    events and the two menu tags. `/fam test` reports on this (group `names`, "Battle.net
    friends") how many friends are on a character of this game and how the names are
    written, without storing a name.
- **Left out on purpose:** aliases on Blizzard's unit frames, raid frames and nameplates
  (CustomNames overwrites `SetText` on Blizzard's FontStrings there, taint risk, names secret in
  combat), guild roster, import/export, slash command for adding entries.
