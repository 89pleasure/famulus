# Famulus

An addon for **World of Warcraft: Forever** (interface 16001) about playing together: a chronicle of
the journey you share with your friends, the fellow travellers you grouped with, and aliases for
other players. English, German, French, Spanish and Italian; no libraries, no dependencies.

> **Alpha.** Much of Famulus has only been tested against a mock of the game client so far.

## Installation

1. Get Famulus from CurseForge, or copy the `Famulus/` folder of this repository to
   `World of Warcraft/_forever_/Interface/AddOns/`.
2. Restart the game (a `/reload` may not pick up a new addon folder).
3. `/fam` or `/famulus` opens the window, as do the minimap button and the addon menu at the minimap.

## Features

- **Chronicle:** tells what happened as a picture book, one chapter per session of play: level-ups,
  deaths, bosses, challenges, discovered zones, professions, abilities and special items. It can
  share this with friends and guild members who use Famulus too, and shows their news live as a
  card on screen. A click on a friend's card celebrates it with them, or mourns a death.
- **Fellow travellers:** remembers who you grouped with: when, where, how often, for how long, and
  which bosses you beat together. Your closest companions and your bond with them, from Encounter to
  Inseparable. Optionally friends and guild only. Shows who of your friends and guild is in your
  zone or at your level, with a card when you meet up in a zone. Nothing of this is sent anywhere.
- **Aliases:** names of your own for other players that only you see, in chat, in the tooltip and in
  the Guildy addon, set from the right-click menu. One alias for a Battle.net friend covers all of
  their characters. Whispers, invites and links keep using the real name.

| Area | Feature | Default |
|---|---|---|
| Chronicle | Record my journey | off |
| Chronicle | Follow my friends (level-ups on your friends list) | off |
| Chronicle | Share with friends (addon messages between Famulus users) | off |
| Chronicle | Show events on screen | **on** |
| Fellow travellers | Remember my fellow travellers | off |
| Fellow travellers | Who is nearby (friends and guild in your zone) | off |
| Aliases | In chat, in the tooltip, in the context menu | **on** |
| Aliases | Characters of Battle.net friends | **on** |
| Aliases | In Guildy (only when Guildy is loaded) | **on** |

Anything that listens to game events or sends messages to other players starts switched off. Each
area also has a main switch under Settings › General.

More commands: `/fam feed` moves the live cards (or use the game's Edit Mode; `reset` and `test`
after it), `/fam chronicle demo` and `/fam fellows demo` add sample data (`clear` after it removes
it).

## Development

```bash
luajit tests/run.lua
```

Loads the addon against a mock of the client API and checks every feature, the window and the
translations. It must pass before every commit. The mock proves Famulus's own logic, not the
client's: `/fam test` checks the addon's assumptions in the running game, and `/fam dev` runs that
check after every login and logs blocked actions. After a `/reload`, `luajit tools/read_selftest.lua`
prints the report.

```
Famulus/          the addon; Famulus.toc lists every file
  Core/           namespace, settings, feature registry, shared services, self-test
  Locales/        enUS.lua (reference) and one file per other language
  Modules/<Area>/ one file per feature; shared code is <Name>Service.lua
  UI/             window, chronicle book, fellow overview, live cards, minimap button
  Media/          textures (tools/make_media.py), the feed's sound (tools/make_sound.js) and
                  Inter (tools/make_fonts.py, SIL OFL 1.1)
tests/            mocked client API and test run
tools/            media and font generators, self-test reader, release check
website/          static website, no build step: python3 -m http.server 4173 --directory website
```

A new feature is a file `Modules/<Area>/<Id>.lua`, listed in the `.toc`:

```lua
local _, ns = ...

local feature = ns:NewFeature({
    id = "myFeature", category = "chronicle", default = false,
    requires = { "C_Something.Function" },   -- if the API is missing, the feature stays off
})
function feature:OnEnable() self:RegisterEvent("SOME_EVENT") end
function feature:SOME_EVENT(event, ...) end
```

It needs `L.f_myFeature` and `L.f_myFeature_desc` in both locale files, and the feature count in
`tests/run.lua` goes up by one; the window builds its row by itself. The full rules for new code are
in `AGENTS.md` (German).

## Releasing

A tag builds the addon on GitHub and uploads it to CurseForge: `v1.2.3` as a release,
`v1.2.3-beta.1` as a beta, `v1.2.3-alpha.1` as an alpha. Other tags stop before the build; pushes
and pull requests only run the tests. `CHANGELOG.md` needs a section `## 1.2.3` first.

```bash
bash tools/release_check.sh v1.2.3
git tag v1.2.3 && git push origin v1.2.3
```

## License

All rights reserved, see `LICENSE`. You may read the code, change the addon for your own use and
fork the repository on GitHub to propose pull requests. Redistributing it, uploading it elsewhere,
publishing it as your own project or using the name "Famulus" needs written permission. The Inter
font is licensed under the SIL Open Font License 1.1.
