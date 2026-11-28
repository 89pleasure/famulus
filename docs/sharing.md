# Sharing between players (`sharing`)

Part of the project notes; requirements, rules and the index of all files are in
[AGENTS.md](../AGENTS.md). References of the form "see X" point to a heading or a bold entry;
the index there says which file it is in.

**`sharing` (the owner's decision, 2026-11-19):** Targeting and proximity are no good; the
chronicle should not depend on where the friends are. That is why Famulus talks to Famulus
(`Modules/Chronicle/Sharing.lua`): addon messages with the prefix `Famulus`, whispered to
friends on the friends list and guild members who are online. Accepted only from people
on the friends list or in the guild, only via WHISPER (exception: the greeting `1~P` in the
guild channel), only known fields; `|` and control characters are removed.

- **Numbers and times that come in (since 2026-11-28; checked against the mock only):**
  - A number is plain digits, ten at most (`Int` in `Sharing.lua`). `tonumber` alone also reads
    `1e999` (infinite), `nan` and `0x10`; a time that is no number sat unsorted among the entries,
    and `OwnSince` stopped at it, so own entries before it went to nobody. An entry whose time is
    no such number is not taken, a field that is none is left out.
  - An entry keeps the time its sender wrote, however old (`ChronicleService.Add`). The time is
    what tells the same entry apart when it arrives again, and the mark in a hello is in the
    sender's clock. Until then a time older than 90 days or more than five minutes ahead was
    replaced by "now": a new friend's old history appeared as just happened, one card on screen
    each, and what shared a second was dropped as a duplicate.
  - An entry more than five minutes ahead of this clock (`CLOCK_SLACK`) is not taken. The mark
    does not move, so it comes again with a later hello, once its time has come. Known limit: a
    friend whose clock runs that far ahead is not heard live, only at the next hello after their
    time has passed. Written under "now" instead, the entry came again with every hello and was
    written anew each time.
- **A lost entry is asked for again (since 2026-11-28; checked against the mock only):** an own
  entry (`1~E~…`) carries among its values `p=<time of the sender's own entry before it>`
  (`ChronicleService.OwnBefore`; left out where the message would pass 255 bytes; older
  versions drop it as a value they do not know). If that time is newer than the receiver's mark
  for the sender, something got lost on the way: the client drops what arrives during a boss
  fight, and a queue ends with a `/reload`. The entry is then not taken (`handlers.E`), or the
  mark in the next hello would pass over the gap for good; a hello goes out instead and the
  sender catches up from the mark, this entry included. Asked twice per mark at most
  (`gapAsked`), the second time a minute later (`GAP_AGAIN`: the first hello may have reached
  the sender during a boss fight): if what comes does not move the mark (a kind this version
  does not know, an entry from the future), entries are taken as they come, so two clients
  never ask each other in a circle. An entry that was passed on first (`via`) and then arrives
  from the companion themselves counts as theirs from then on (`ToldAgain` in
  `ChronicleService.lua` drops the `via`): the mark moves with it. Before, it stayed behind
  every passed-on entry, so each hello brought them all again, and the gap check asked for them
  once more on top.
- **Who is not heard, and how much at once (since 2026-11-28; checked against the mock only):**
  - Nothing is taken from someone on the player's ignore list (`SocialService.Ignored`,
    `C_FriendList.IsIgnored`): a guild member the player ignores would otherwise still put cards
    on screen. Not checked in game whether the function exists in Forever and which spelling of
    a name it wants; it is asked for the sender as the message names them and as the lists do.
  - Of fresh entries (at most `ChronicleService.FRESH`, 120 seconds, old: the ones the live
    feed announces) only eight are taken from one sender within a minute (`MAX_FRESH`,
    `FRESH_SPAN`). A person brings forth a few a minute at most; a changed addon could send any
    number, each a card with a sound. An entry left out is a gap the sender's next entry
    names, so it is asked for again and taken once the minute is over; of ten and more within
    one minute, which nobody's play brings forth, some may be lost for good. Old entries are
    not counted: catching up brings hundreds.

- **Guild (2026-11-19):** Whoever comes online greets the guild once in the guild channel (`1~P`),
  as soon as the guild roster is there; whoever has Famulus answers by whisper with a greeting.
  Friends are still greeted one by one. That addon messages in the guild channel arrive in Forever
  is shown by Guildy (it sends there). Names: guild roster and sender can deliver
  `Firstname Lastname-Realm` (that is how Guildy reads them); the key cuts that off.
- **Relaying (the owner's request, 2026-11-19):** News from someone who is offline
  comes through a connected companion who has it. A greeting is followed
  by up to 20 offers `1~O~<who>~<time>` (since 2026-11-25 only about people who are currently not
  online); whoever expects something new from them asks with `1~W~<who>~<since>` and gets
  up to 20 entries as `1~R~<who>~<time>~<kind>~…`. Rule: asked about and accepted only for
  guild members and for people whose addon has answered directly in the last 30 days
  (`FamulusDB.chronicle.links`; a direct answer only comes from someone who has the player on
  the friends list or in the guild, which proves friendship on both sides). So nothing arrives
  about strangers. Per person only one companion is asked per session, and `R` is only
  accepted from them. Relayed entries carry `via` (shown as "via <Name>") and do not move
  the read pointer for the direct greeting (`NewestFrom(who)` without `withRelayed`), otherwise
  a lasting gap would appear if the relayer had missed something themselves. Limits:
  a companion could fake entries about others, and a modified addon could ask about anyone;
  the answering side does not check this. Acceptable for levels, deaths and bosses. If someone
  removes the player from the friends list, they still count as connected for up to 30 days.
- Messages, fields separated by `~`: `1~H~<time>` (greeting: "I have your news up to
  <time>"), `1~E~<time>~<kind>~k=v;k=v` (an entry), `1~S~<level>~id=n;id=n~<class>`
  (statistics and, since 2026-11-24, the class, e.g. `MAGE`; older versions do not send it
  and skip the field on receipt), `1~X~<time>~<kind>~<reaction>~k=v` (a reaction, see
  "Reactions" below).
- **Reactions (the owner's request, 2026-11-25; checked against the mock only, not yet in
  game):** A click on a friend's card in the chronicle, or on the button of their card in the
  live feed, reacts to it (see "Reactions" under "Chronicle"). The message `1~X~<time>~<kind>~<reaction>~k=v` goes by whisper to the person
  whose entry it is; `<reaction>` is one of the kind's set (`cheer`, `strong`, `sad`, `clap`, since 2026-11-27 also `heart` and `fire`; see "A set per kind" under "Chronicle"), empty when taken back.
  The entry is found by time and kind; `k=v` carries `skill`, `rank`, `ability` and `item`
  where the entry has them (`ChronicleService.MARKS`), the same fields that tell two entries
  of one second apart in `Add`. No new version: older versions ignore the unknown letter.
  - **When it goes:** two seconds after the click (`REACT_DELAY`), so that on and off again
    sends nothing; then at once if the person is linked (first lane), otherwise at their next
    greeting `H` (`TellReactions`, the owner's requirement: "if both are online, it should go
    out at once"). Only what went out counts as told (`told` on the entry; the queue calls
    `item.done(sent)` when a message leaves it), so a reaction to someone who went offline
    in the meantime waits for the next greeting. Several clicks to one entry while a message
    waits send the newest state afterwards.
  - **Received:** only from friends and guild members online (as every message), only to the
    playing character's own entries, only for kinds with a reaction. A reaction this version
    does not know (a newer one's), or one not of the kind's set, counts as the kind's own.
    Option `reactions` of `sharing` (default on, because nothing goes out without a click);
    off: nothing is sent or taken, the cards show no reactions. Sample entries never send.
  - **Who sees what (stage 1, the owner was unsure, 2026-11-25):** the person whose entry it is
    sees who reacted; the one who reacted sees their own reaction. Others see nothing.
    Proposed for later (stage 2, not commissioned): the person whose entry it is sends the
    count to everyone linked, others see the number without names (they often do not know the
    people who reacted). The message `X` stays the same for it.
- A greeting goes to every friend who comes online. Whoever answers counts as connected for the
  session and gets one's own milestones live. A greeting is followed by all missed
  own entries (in rounds of 20, see "Queue") and the statistics.
- **Statistics after one's own events (since 2026-11-25):** Five seconds after an own
  entry that goes out live, the statistics also go to everyone connected (`STATS_DELAY`,
  `SendStatisticsSoon` in `Sharing.lua`), once for several events within those five
  seconds. Occasion (noticed in game, 2026-11-24): a friend still saw "6 deaths" in the stats
  although the new deaths reached them live. Before that the statistics only went out as an
  answer to a greeting, and a `/reload` by the sender does not trigger a greeting on the friend's
  side (they are still connected there); so the stats stood at the state of the last login
  of one of the two. The delay is the assistant's decision: the client probably only counts
  a death into the statistics a moment after `PLAYER_DEAD`. Defeated
  creatures and quests create no entry; their numbers are only refreshed with another
  event or a greeting. The other side needs no new version. Checked against the
  mock only.
- Shared statistics (game IDs): 60 deaths, 107 creatures killed, 98 quests, 932 dungeons
  entered. They appear as "Stats" per person in the rail of the tab "Friends"
  (`FamulusDB.chronicle.profiles`; in the code they are still called `profile`). Since
  2026-11-25 the list is in `ChronicleService.STATISTICS` (before that on the feature, and the
  window reached into `ns.features.sharing` for it).
- **Queue (since 2026-11-25, the owner's go-ahead after the analysis below; the
  assistant decided the implementation in detail):** Everything goes through a queue
  with a ticker (every 0.5 seconds, only while something is waiting). During the chat lockdown (boss
  fight, locked map) it stands still. The wire format is unchanged.
  - **Pace like the client:** According to warcraft.wiki.gg (page `C_ChatInfo.SendAddonMessage`,
    as of Forever 1.60.1) each prefix may send 10 messages at once and gets one back per
    second, **except whispers outside instances**; in addition the server has a limit of its own
    and can drop the connection on too much traffic, and it can change the values at any
    time. Since 2026-11-25 (the owner's request after comparing with the wiki) therefore
    two budgets in `Flush`: the 10 plus 1 (`ALLOWANCE`, `REFILL`) only for the guild channel, and
    for everything a budget by bytes with the values of ChatThrottleLib v32 (`BANDWIDTH` 800 per
    second, `BURST` 4000, `OVERHEAD` 40 per message). After a loading screen
    (`PLAYER_ENTERING_WORLD`) the budget starts empty and for five seconds fills only at
    a tenth (`SETTLE`, like ChatThrottleLib). If the client does refuse a whisper, from then on
    whispers also count against the 10 plus 1 (`whispersCounted`; `devLog` "whisper throttled"):
    that way it shows in game whether Forever throttles whispers. ChatThrottleLib itself is on purpose
    not included (the owner's decision, 2026-11-25): it drops messages on
    `AddOnMessageLockdown`, does not know `TargetOffline`, cannot replace queued messages
    (greeting with a late state, catching up in rounds), sets permanent hooks and is a
    library with a global name. Its advantage, a budget shared with other addons, is therefore
    missing in Famulus. If `SendAddonMessage` still reports `AddonMessageThrottle`,
    `ChannelThrottle` or `AddOnMessageLockdown`, the message stays at the front of the queue and
    goes again later (like ChatThrottleLib from v29). A plain `false` (clients before
    10.2.7; according to the UI source code Forever returns the enum) also counts as refused, but
    only five times (`MAX_REFUSED`), because it can also be a
    permanent refusal. On `TargetOffline` nothing more goes to the
    person (`gone`) until they send something themselves again or the lists show them as
    offline and online again. The values come from `Enum.SendAddonMessageResult`, otherwise
    from fixed numbers; `/fam test` checks whether the three names exist (group `api`). In
    developer mode there is one line per session and kind in the `devLog` (`SHARE`, "throttled",
    "whisper throttled", "lockdown", "offline"), without names. That way you can see in game
    whether Forever throttles. The enum's numbers are confirmed in the `forever` branch of
    `Gethe/wow-ui-source` (`ChatConstantsDocumentation.lua`, 0 to 12, 2026-11-25). According to the
    wiki, test accounts send no addon messages since 1.60.1; with which return value is open.
  - **Two lanes:** at the front one's own entries (live and caught up, in chronological order),
    greetings, questions `W` and the stats after a live entry; at the back the stats in an answer,
    offers and relayed entries. One's own entries are at the front and in order on purpose:
    the state at the companion's end ("I have your news up to …") must never
    skip an entry they do not have, otherwise they would never get it. A live entry therefore
    waits behind the catching up. One's own entries are never turned away. For the rest there are
    100 (front) and 200 (back) slots; greetings are never turned away, otherwise a first contact
    would be left without a greeting.
  - **Catching up in rounds (since 2026-11-25, after the review of PR #13):** A greeting gets the
    oldest 20 own entries that are missing, plus the rest of their last second
    (`ChronicleService.OwnSince`; before that the newest 20, and anything missed beyond that was
    gone for good). Once the last of a full round is out, the next follows (`CatchUp`, marker
    `more`). A round takes one's own entries for this companion out of the queue that are still
    waiting and newer than their state, and queues them again in chronological order (`skip`).
    That way a live entry that was already in the queue before the greeting does not go out before
    the older ones. Known limit (already so before): the state is a second; if the companion has
    only one of two entries from the same second, they miss the other.
  - **Double greeting:** Both sides usually greet twice (on coming online and on first
    contact). The state in the greeting is only read when it is sent, at most one greeting waits
    per person, and a second greeting replaces the entries still waiting instead of doubling them.
    So the second greeting usually costs only itself and one stats message.
  - **Offers** are only about people who are currently not online (who say so themselves), and
    not again while earlier ones to the same companion are waiting or they are less than 60
    seconds ago (`OFFER_GAP`; since whispers go faster, the answer to the first
    greeting is usually already out when the second comes on first contact). A greeting after a
    `/reload` by the companion therefore gets them again (before: once per session; a friend does
    not greet via `P` and got none after their `/reload`). A question `W` only counts as
    asked once it is in the queue; if the person asked goes offline or the client reports
    `TargetOffline`, the person is free again and is asked about at the next offer (`Unask`).
  - **Greeting `P` after `/reload`:** is always answered, even if the sender still counts as
    connected (`P` goes out once per session, after that the sender knows nobody). Before, a
    guild member stayed unconnected after `/reload`, and their milestones went to nobody.
- **No service of its own for the exchange** (the owner's decision, 2026-11-25),
  as long as only `sharing` sends messages. If a second feature joins: transport
  (prefix, queue, acceptance rules) and "who is there" (online, connected, greeting to the guild)
  into a service under `Core/`, the chronicle protocol stays in `Sharing.lua`. The
  wire format stays the same (alphas are out); a new feature gets new
  letters instead of a new version, old versions skip unknown kinds.
- **Many users (analysis 2026-11-25, simulated in the mock; before the budget by bytes, the
  numbers for "After" assume that whispers also count 10 plus 1):** A client logs in, N
  guild members with Famulus are online, ten more offline, the others have their
  news up to yesterday; 30 seconds after login they level up. Throttling is rebuilt as in the
  wiki. The simulation is a script outside the repo; the companions in it
  answer without throttling of their own, so the numbers are rather too favourable.
  - **Before:** Famulus sent two messages per second and did not evaluate the return value;
    whatever the client refused was gone. Lost at login: at N = 1 13 of 46 messages, at
    3 55 of 128, from 10 the queue (200 slots) also overflowed. The level-up reached two at
    3, two at 5, eight at 10, five companions at 20, the last after up to 169 seconds.
    Offers made up two thirds of the traffic at N = 10.
  - **After:** Nothing is lost through throttling. The level-up reaches everyone: at 5
    after 7, at 10 after 42, at 20 after 112, at 40 after 252 seconds. From 20 the back
    lane turns away offers and duplicate stats (at 40: 220 and 60).
  - **Limit of whispering:** Each message goes to each person separately, per the wiki at about 7
    per second (budget by bytes), and if Forever does throttle whispers after all, at one. For
    large guilds the route via the guild channel: issue #12 (live entries, stats and offers
    once to the guild; open are older versions and the order). Closed as "not planned" on
    2026-11-25 (the owner's decision after the assistant's check): its numbers assumed that
    whispers count 10 plus 1; with the budget by bytes a live entry to 40 members takes about
    four seconds, the wait at login is the catching up, which goes to each companion
    separately anyway, and offers to the guild would reach every member on every login over
    the slower channel. Worth reopening if the `devLog` in game shows "whisper throttled".
    The limit for others' entries the issue also raised is in place (see "Limit" under
    "Chronicle").
- Fresh news appears on screen through the live feed (`liveFeed`, see
  below); the former option `toast` and `UI.Toast` are gone.
- **Trace (since 2026-11-25, the owner's request after "Mel not linked" below: without a log
  neither the owner nor the assistant can follow such errors):** In developer mode (`/fam dev`)
  `Sharing.lua` writes every step of the exchange into the trace (`ns:DevTrace` in
  `Core/SelfTest.lua`, `FamulusDB.devTrace`, at most 500 lines, cleared when developer mode is
  switched off; each session begins with a line `SESSION`):
  - switched on and off; the guild roster and the friends list whenever their counts change
    (`guild roster: 42 members, 7 online`, an empty roster while in a guild is marked, a kept
    one says `guild roster came empty, keeping the last one: …`);
  - the guild greeting from the queue to its echo (`guild greeting queued`, `sent P to guild`,
    `own guild greeting came back from the guild channel`);
  - every message sent (`sent H to AW-799`), refused, dropped (not online, the client said
    offline) or turned away (queue full), with the client's answer by name;
  - every message received with the decision: `got S from AW-799`, or `ignored … :` neither a
    friend online nor in the guild, came by another channel, another version, a kind this
    version does not know, sender or text unreadable (secret);
  - hellos queued with the reason (a friend online, their guild greeting, first contact), first
    contact, catching up (from when, how many), offers and passed-on entries not taken and why,
    an own entry and to how many linked it goes, loading screens, chat lockdown.
  The same line again within two seconds counts up the last one (`sent E to AW-799`, 20 times).
  A person is a tag (`Tag`): initials and three hex digits from the name key, the same on every
  client and in every session, so the traces of two players can be laid side by side. Names are
  not stored (the rule of `ns:DevLog`). `tools/read_selftest.lua` prints the trace after the
  report and the `devLog`. Outside developer mode the trace costs one check per step. The lines
  and their wording are the assistant's decisions. Checked against the mock only.
- **Open (2026-11-25): Mel not linked until the owner's `/reload`.** Mel (Battle.net friend of
  the owner and in the same guild, not on the character friends list; Ori is the same) switched
  on sharing during the session while the owner's client was running with sharing on. She did not
  appear under "Friends" until the owner's `/reload`, then at once. The owner's saved data from
  just before that reload had no `link` for her: before it, not a single message from her was
  accepted. Between the two only the guild greeting `P` works (Battle.net friends do not count
  for sharing). After the reload the owner's `P` reached her and she answered; in the other
  direction her single `P` (or the owner's answer to it) was lost. The code is the same in both
  directions and the mock connects them. Candidates, none proven: the game delivers an empty
  guild roster for a moment (Guildy saw that in Forever on 2026-11-09 and keeps the last roster;
  Famulus then empties its guild list, sends no `P` on switching on and takes a `P` it receives
  as from a stranger), a loading screen or chat lockdown on the receiving side, names that are
  secret in instances. `P` goes only once per session, nothing repeats it. Next time: `/fam dev`
  before, `/reload` afterwards, then read the trace (if possible on both sides). The empty roster
  is handled since 2026-11-26 (see "Empty guild roster" below). Proposed, not commissioned:
  count Battle.net friends who play Forever as friends (issue #52; then a hello goes by whisper
  and the guild greeting is no longer the only way).
- **Empty guild roster (since 2026-11-26, issue #51; checked against the mock only, not yet
  in game):** If the client hands over a guild roster that is empty or names
  nobody (every name secret) while the player is in a guild, `SocialService.EachGuildMember`
  visits the last roster of this session that named anyone instead, as Guildy does, and returns
  `true` (`keeping`). A guild always has at least the player, so such a roster is never true. The
  next roster that names anyone takes over; out of a guild nothing is kept. Kept in memory only,
  not saved; two tables of columns filled in place, so reading the roster leaves no garbage.
  Everyone who reads the roster benefits: sharing (a `P` received then is answered, not taken
  as from a stranger; the trace says `guild roster came empty, keeping the last one: …`),
  `SocialService.Circle` (no waiting, so the fellow travellers' cleanup does not stop at "still
  loading"), `Online`, `Classes` and "Who is nearby". The kept roster's online states and zones
  are those of when it came. Whether this was the cause of "Mel not linked" is not proven.
- **Not checked in game:** whether whispered addon messages arrive the way name and sender
  are written (`Firstname Lastname` versus `Firstname-Lastname`), whether a whisper to someone
  who just went offline leaves an error message in the chat, and whether the statistic IDs
  are right (taken from Guildy's source code). That can only be checked with two accounts.
  Also not checked: greeting and answer in the guild and the relaying (that needs three
  characters, one of them offline), and which name form the guild roster delivers in Forever.
