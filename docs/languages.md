# Languages

Part of the project notes; requirements, rules and the index of all files are in
[AGENTS.md](../AGENTS.md). References of the form "see X" point to a heading or a bold entry;
the index there says which file it is in.

- **Languages (since 2026-11-26, the owner's request):** English (`enUS`, the reference and the
  fallback for a missing key), German (`deDE`), Spanish (`esES`), French (`frFR`), Italian
  (`itIT`), Polish (`plPL`) and Ukrainian (`ukUA`). Ukrainian was asked for as the hard test:
  Cyrillic, three plural forms, cases. The five new translations were written by the assistant
  and have not been read by a native speaker. Checked against the mock only, not seen in game.
- **Which language speaks:** the option "Language" (`general.language`, default "auto" = the
  client's `GetLocale()`). `enGB` speaks English, `esMX` Spanish (`SAME_AS` in
  `Core/Locale.lua`). WoW has no Polish or Ukrainian client: those players use another one
  (mostly English) and choose the language in the option. What the client names itself stays in
  the client's language (zones, bosses, items, classes), so a Polish text gets English zone
  names; the texts are written so that such a name fits (see "Writing the texts").
- **A new language** is its file in `Locales/`, its line in the `.toc` (with `## Notes-<code>` if
  the game has such a client), its rows of samples (see "Samples") and the list of languages the
  test expects. The dropdown and the picture `lang` take the name from the file (`lang_name`, the
  language's own name: "Українська").
- **Numbers:** `ns.Plural(key, n)` returns the text for n, still to be formatted:
  `<key>_one`, `<key>_few` or `<key>`, after the language's rule (CLDR). English, German,
  Spanish, Italian: one = 1. French: one = 0 and 1. Polish: one = 1, few = 2–4, 22–24 … (not
  12–14). Ukrainian: one = 1, 21, 31 … (not 11), few as in Polish. `<key>` holds the form most
  numbers take (English "other", Polish and Ukrainian "many"); a language adds `_one`/`_few`
  only where its grammar needs them, so the one-form keeps the number ("%d event": in Ukrainian
  it is also 21). Only keys the code passes to `ns.Plural` may have such forms (the test finds
  them in the source). A text with a number that does not go through `ns.Plural` is written so
  that any number fits ("OK: %d, błędy: %d").
- **Upper and lower case:** `string.upper` and `string.lower` change only A–Z.
  `ns.Upper`, `ns.Lower` and `ns.Capital` (`Core/Locale.lua`) also change the letters of
  Latin-1, Latin Extended-A and Cyrillic. Used for the column heads of the fellow travellers,
  initials, the bond tiers inside a sentence, lines that begin with a sentence fragment and the
  search, which so ignores case in every language.
- **Fonts:** the Inter of the addon has Latin, Greek and Cyrillic (`tools/make_fonts.py`). The
  test reads the character maps of the three font files and fails for every letter of any
  language they lack. Not in them: U+02BC, the Ukrainian apostrophe as a letter; write ’. The
  game's fonts (the pictures of chat, tooltip and menu) are font families with Cyrillic.
- **Writing the texts** (the rules the translations follow):
  - The placeholders of enUS, in the same order. No `%1$s`: the client knows it, the mock's Lua
    does not.
  - No gendered forms for the player or other people: friends' events in the present tense
    ("%s osiąga poziom %d"), one's own as a noun or impersonal ("Osiągnięto poziom %d",
    "Décès : %s"). Ukrainian addresses the player with "ви" (its past tense has no gender),
    French with "vous", Spanish, Italian and Polish informally.
  - Names and zones are inserted as they are (nominative): phrase so that they fit (subject,
    colon, a preposition before a foreign name).
  - Game terms as the client of that language names them (French, Spanish, Italian); in Polish
    and Ukrainian the words players use, the Edit Mode with its English menu name in brackets.
  - Labels short: the window has fixed widths, and French, Polish and Ukrainian run about a
    third longer than English.
  - The bond tiers (`ui_bond_<n>`) are also inserted in lower case into `ui_fellow_tier_up` and
    `ui_run_tier`; tiers and sentences are chosen so that both read well.
  - Dates and times: `c_date` is the language's order and must be one of `ns.DATE_FORMATS`
    (French, Spanish, Italian `{d}/{m}/{y}`, Polish, Ukrainian `{d}.{m}.{y}`); the picture names
    the orders in the language's letters (`ui_preview_date_y/m/d`: "AAAA", "RRRR", "РРРР" …). The
    12-hour clock writes AM/PM, in Spanish "a. m."/"p. m.", in Ukrainian "дп"/"пп".
  - The game texts in the pictures (`ui_preview_chat_*`, the tooltip line, the menu) as the client
    of that language shows them; in Polish and Ukrainian translated, so that a picture reads in
    one language.
- **Samples:** `DEMO_ZONES`, `DEMO_NAMES`, `DEMO_PEOPLE` (`ChronicleService`) and `DEMO_ZONES`,
  `DEMO_BOSSES`, `DEMO_PEOPLE` (`FellowService`) have a row per language: zones, professions and
  bosses as the client of that language names them, Polish and Ukrainian with the English names.
  The people keep their first names and get surnames in the language (Ukrainian in Cyrillic).
- **Checks** (`tests/run.lua`): every language has every key of enUS and no other, with the same
  placeholders; plural forms only for keys passed to `ns.Plural`; the rules of English, German,
  French, Polish and Ukrainian with a test key; `esMX` speaks Spanish; every letter in all three
  fonts; upper and lower case; every page and the picture of every settings entry drawn in every
  language; samples in every language; the picture `lang` with all seven names and Ukrainian
  chosen by hand. The mock measures text by letters, not bytes (a Cyrillic letter is two bytes).
- **Open:** a native speaker's reading of the five new languages. In game: whether the longer
  texts fit (labels, tabs, column heads, pills), whether Cyrillic shows in Inter and in the
  game's fonts on an English client.
