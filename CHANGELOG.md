# Changelog

Every release has a section `## <version>` (the tag without the `v`, for example `## 0.2.0-beta.1`).
That section becomes the changelog of the file on CurseForge.

## 0.1.0

The first beta, and the first version of Famulus you can find in the CurseForge app. If you are
new: welcome! Below is what Famulus does today, then what changed since the last alpha. Famulus
also has a website now, famulus.camp, with screenshots, demos to try in the browser and answers
to common questions. Things will still move, and sharing gets better with everyone who tells me
what they see: type `/fam report` and paste the text into a comment on CurseForge or an issue on
GitHub.

### What Famulus does
- **Chronicle:** your journey as a picture book, one chapter per play session: levels, deaths,
  bosses, challenges, new zones, professions, abilities like riding and special items. Share it
  with friends and guild members who use Famulus too, react to their moments, and see their news
  as cards on screen.
- **Fellow travellers:** everyone you grouped with, when and where you met, the bosses you beat
  together and how close you are. "Nearby" shows who of your friends and guild is in your zone
  right now.
- **Aliases:** your own names for other players, in chat, tooltips and the online notices.
- **Welcome page:** one click switches on the main features. Nothing that listens to the game or
  sends anything to others runs before you choose it.
- English, German, French, Spanish and Italian.

### New since 0.1.0-alpha.6

#### Chronicle
- The abilities class quests teach now go into the chronicle and reach your friends, like riding:
  stances, forms, pets, totems, Poisons and the class mounts.
- A card names the person and the time in the strip at its top, and the place at its foot.
- Reacting to a friend's event works through the button at the foot of their card, the same as on
  the live feed; a click on the card itself no longer reacts.
- New reaction icons from Phosphor Icons that read better at their small size: a sad face, a party
  popper, a fist and clapping hands.
- More reactions to choose from: hold the button or right-click it, and a bar offers the ones that
  suit the event. A click still gives the usual one. A death gets comfort or courage (a heart, a
  fist), never cheering or applause; bosses and special moments can also get a flame. Your
  own cards show the two reactions given most, and the tooltip who gave which.
- Live feed cards tell whose event it is, what happened and where in three rows, so long events
  are no longer cut off.
- Only the newest live feed card is large; the two before it move down as slim rows.
  When many come at once, each gets its moment on top while the rest wait in a stack behind it,
  with their number.
- When several friends beat the same boss, fall in the same zone or complete the same challenge
  within a few seconds, they share one card with their names.
- New under "Show events on screen": "Keep the last three" lets the cards stay as rows instead of
  fading out.
- `/fam feed test` shows a burst of sample cards, so you can see the stack and the rows. Nothing is
  stored or sent.
- Guild members with Famulus are no longer taken for strangers when the game briefly reports an
  empty guild roster.

#### Fellowship
- The fellow travellers are now called the fellowship.
- Whisper someone right from the overview, a list row or their card. The card's buttons are now
  icons in one row.
- Nearby: Battle.net friends in another mode (Normal, PvP, RP, RP-PvP) or of the other faction
  can't play with you, so they no longer get a card or appear under "Here in …". They stand last
  under "Out of reach", with the mode and the faction as the reason. A Battle.net friend's
  whisper goes by Battle.net, so it reaches them in any mode.
- Classes and factions are named in their colours, softened so they don't outshine the rest.

#### Window
- The chronicle, the fellowship and the aliases are cards in the sidebar, each with its count.
- The settings of the chronicle, the fellowship and the aliases are a gear at the right end
  of their tabs.
- `/fam report` or "About" > "Copy bug report" shows a text to copy with Ctrl+C and paste into a
  report. It holds no names.
- The window needs noticeably less memory once it has been opened.

## 0.1.0-alpha.6

### Welcome
- The first time you open the window, a welcome page shows what Famulus does. One button switches
  on recording your journey, following and sharing with your friends, remembering your fellow
  travellers and "Who is nearby"; "What exactly?" lists them and what goes to friends and guild.
  "Choose myself" opens the chronicle's settings, "Later" just closes the page. If you already use
  any of these, you won't see it; "About" > "Welcome" shows it again.

### Chronicle
- React to a friend's event right from the live feed: a button on their card gives the reaction
  and closes the card a second later. Take a reaction back in the chronicle.
- The live feed's cards show a line along their foot that runs out while they stay.
- An empty chronicle that is already recording says so instead of asking you to switch it on.

### Fellow travellers
- "Who is nearby" (off by default): a card when you arrive where friends or guild members are, or
  when one of them arrives in your zone or comes online there. None in instances or in flight, and
  in cities and inns only if you want. A new tab "Nearby" shows who is here, who is of a similar
  level and everyone else online, with level, zone, bond and a button to whisper. It reads your
  friends list, Battle.net friends and guild roster; nothing is sent, and the others need no
  Famulus.

### Window
- Famulus now speaks French, Spanish and Italian, next to English and German. Spanish also on
  Mexican Spanish clients.
- Settings has a new tab "Language & time" with the language, the time format (24-hour or 12-hour
  clock with AM and PM) and the date format (the language's order or one of four fixed orders).
  Resetting "General" no longer resets the language.
- Every entry of the settings shows a live picture of what it does, in your colour scheme and
  language.
- English no longer says "1 bosses" or "with 1 others".

## 0.1.0-alpha.5

### Chronicle
- React to your friends' events: a click on a friend's card in the chronicle celebrates a level-up
  or a boss with them, applauds a profession or mourns a death; a second click takes it back. Your
  own cards show who reacted. A reaction reaches your friend at once while you are both online,
  otherwise as soon as you are; your friends need this version to see it. It can be switched off
  under "Share with friends" > "Reactions".
- On a friend's profession card, the recipe book now opens from a click on the picture.
- The live feed also shows when a friend reacts to one of your events, with its own switch.
- The live feed plays a soft double click with each card, once when several come together, at the
  game's sound effects volume. "Play a sound" under "Show events on screen" switches it off.

### Aliases
- Aliases now also appear in the notices that someone came online or went offline. Clicking the
  name still whispers the character. Not in a whisper window of its own, nor in the notices for
  Battle.net friends.

### Window
- Settings are a list of entries with icons on the left and the chosen entry in full on the right:
  its switch, its default, its whole description and its options. The live feed's kinds of events
  are chips you switch on and off.
- Lines and borders are a little darker than the ground they run over and no longer look too
  bright.

## 0.1.0-alpha.4

### Chronicle
- Developer mode (`/fam dev`) now also records every step of sharing: what was sent to and
  received from friends and the guild, and why a message was ignored. This is to find out why a
  friend who switches sharing on sometimes only appears after a `/reload`. People appear as short
  tags, never by name; switching developer mode off deletes the record.

## 0.1.0-alpha.3

### Chronicle
- Every event has a weight: boss kills and level-ups get a large card, deaths and new zones a
  small one. Each card shows whose event it is at the top and time and place at the bottom.
- Your friends' stats now update right after their deaths and level-ups, not only when you log in.
- Sharing keeps to the game's limit for addon messages, so nothing gets lost when many friends or
  guild members with Famulus are online. Your own entries always reach them in order.
- Guild members are linked again after a `/reload`.
- When the chronicle is full, your friends' news makes room before your own journey does.

### Fellow travellers
- A new tab, Groups: when you played together and with whom, the zones and bosses of each group,
  and who you play with most often. It starts with this version.
- "Your story" is told by sessions of play, like the chronicle, with the zone on each card.

### Window
- Text no longer stays blank until a `/reload` while the window's font is still loading.

## 0.1.0-alpha.2

### Chronicle
- A chapter is now a session of play instead of a day: a pause of two hours begins the next one.
  It is named after the part of the day it began in ("This evening", "Last night"), older ones
  after the weekday ("Sunday night"), and shows from when to when.
- Below a chapter's heading, your route through the zones in the order you visited them.
- Friends show their class icon instead of their initial once their class is known, from their
  stats, your friends list or your guild roster.
- Behind an alias the character name stands in brackets, "Dad (Borin Ironbeard)". A new switch
  under Chronicle > Settings shows the alias alone.

### Fellow travellers
- Optionally only friends (Battle.net friends too) and guild members, like the chronicle.
- Tidy up removes everyone from the list who is neither on your friends list nor in your guild.
  It names them first, asks before it removes, and waits while your friends list or guild roster
  is still loading or Battle.net is not connected.

### Window
- The aliases come last, after the chronicle and the fellow travellers; the window now opens on
  the chronicle.
- `/fam chronicle demo` and `/fam fellows demo` write their sample data in the addon's language.

## 0.1.0-alpha.1

The first public alpha. Famulus is young: much of it has only been tested against a mock of the game
client so far, so expect rough edges, and please tell us on CurseForge what you run into.

### Aliases
- Give other players names of your own that only you see: in chat (optionally as "Alias (Name)"),
  in the player tooltip and in the Guildy addon.
- Set them from the right-click menu of players and Battle.net friends, or in the window.
- One alias for a Battle.net friend covers all of their characters.

### Chronicle
- Records your journey as a picture book: levels, deaths, bosses, challenges, newly discovered
  zones, professions, abilities and special items.
- Shares it with friends and guild members who use Famulus, even through mutual companions while
  someone is offline.
- Shows your companions' news live as a card on screen.
- A side column shows your week in numbers, your professions and your companions.

### Fellow travellers
- Remembers who you grouped with: when, where, how often, for how long, and which bosses you beat
  together. This stays on your computer and is never sent anywhere.

### Window
- `/fam` opens it: search across everything, five colour themes, English and German.

Anything that listens to the game or sends messages to other players starts switched off.
