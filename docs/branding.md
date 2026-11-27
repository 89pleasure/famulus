# Name, logo and tagline

Part of the project notes; requirements, rules and the index of all files are in
[AGENTS.md](../AGENTS.md). References of the form "see X" point to a heading or a bold entry;
the index there says which file it is in.

- **Name (2026-11-19):** The addon is called **Famulus** (Latin: assistant to a scholar or
  magician); "Schnitzel" was the working title. Rejected because already taken on CurseForge for
  WoW Forever: "Wisp" (ForeverWisp, plus Wisp figures in Wishwell and Sparky), "Ignis"
  (roleplay addon), "Lantern" (Lantern – QoL Core). For "Famulus" a web search found no addon of
  the same name; check directly on CurseForge and Wago before publishing. Renamed
  are the folder, `.toc`, saved variables (`FamulusDB`, `FamulusCharDB`), frame names and the
  commands (`/fam`, `/famulus`) and the GitHub repo (`89pleasure/famulus`). The window's tagline was first "Dein Gehilfe in Azeroth" / "Your assistant in Azeroth"
  (`ui_tagline`), since 2026-11-24 "Gemeinsam durch Azeroth" / "Together through Azeroth" (see
  "Logo"). On the Mac the
  symlink in the addon folder has to be created again (`Famulus` instead of `Schnitzel`), and the
  settings from `SavedVariables/Schnitzel.lua` do not carry over by themselves.
- **Logo (2026-11-19):** a blazing flame in three layers with embers and a soft glow, free-standing without a tile
  ("Lodernd", German for "blazing"), chosen by the owner from the mockup. Rejected: abstract signs (monogram, candle F,
  lantern, quill; "too abstract and minimalist"), a mascot with a face, and versions with a
  game-world motif (quest exclamation mark, torch, rune circle, cogwheel, shield, hearthstone). Blizzard's
  own emblems (Alliance, Horde, WoW logo) stay out. The owner did not want the box around the flame after the
  first look in game. `logo.tga` (flame alone: window,
  addon list) and `logo-round.tga` (on a dark disc: minimap), 128 px, drawn in
  `tools/make_media.py`. The logo has fixed colours and does not follow the colour scheme. On the
  Windows machine no Python of our own is installed; `make_media.py` needs only the
  standard library and ran there with an existing Python 3.12. Not yet seen in game.
  **Confirmed after the turn to playing together (2026-11-24):** The owner was unsure
  whether the flame still fits. On the mockup "Famulus Logo – Varianten" (German, "variants") the owner
  saw two developments (three tongues of flame from one shared fire; the flame on crossed logs as
  a campfire) and kept the flame. It is now read as a campfire where the
  companions meet (the assistant's suggestion); the text carries that, not the image.
  **New tagline (2026-11-24, the owner's choice):** "Gemeinsam durch Azeroth" / "Together
  through Azeroth" instead of "Dein Gehilfe in Azeroth" (sounded like the removed QoL features), in
  the window header (`ui_tagline`) and on the website (`tagline`); since 2026-11-27 (the owner's
  choice after a copy review) also at the top of the CurseForge description, which said
  "Your companion for playing together.". It must fit on one line: in the
  header it has only about 180 px at 11 px up to the page name (`SIDEBAR + PAD`). Also proposed
  and not chosen (German only): "Eure Reise, gemeinsam erzählt" ("Your journey, told together")
  as well as "Das Lagerfeuer für deine Gefährten" ("The campfire for your companions") and
  "Für alle, mit denen du unterwegs bist" ("For everyone you travel with") (both too long for
  this space). Not yet seen in game.
