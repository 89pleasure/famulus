# Changelog

Every release has a section `## <version>` (the tag without the `v`, for example `## 0.2.0-beta.1`).
That section becomes the changelog of the file on CurseForge.

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
