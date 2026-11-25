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
  and skip the field on receipt).
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
    once to the guild; open are older versions and the order). It also notes that
    `MAX_ENTRIES` (2000) applies to own and others' entries together.
- Fresh news appears on screen through the live feed (`liveFeed`, see
  below); the former option `toast` and `UI.Toast` are gone.
- **Not checked in game:** whether whispered addon messages arrive the way name and sender
  are written (`Firstname Lastname` versus `Firstname-Lastname`), whether a whisper to someone
  who just went offline leaves an error message in the chat, and whether the statistic IDs
  are right (taken from Guildy's source code). That can only be checked with two accounts.
  Also not checked: greeting and answer in the guild and the relaying (that needs three
  characters, one of them offline), and which name form the guild roster delivers in Forever.
