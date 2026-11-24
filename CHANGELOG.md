# Changelog

Every release has a section `## <version>` (the tag without the `v`, for example `## 0.2.0-beta.1`).
That section becomes the changelog of the file on CurseForge.

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
