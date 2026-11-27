# Publishing on CurseForge

Part of the project notes; requirements, rules and the index of all files are in
[AGENTS.md](../AGENTS.md). References of the form "see X" point to a heading or a bold entry;
the index there says which file it is in.

The owner's request (2026-11-24): a first alpha on CurseForge, with automatic upload.
Set up on 2026-11-24 following the example of FlareUI and Guildy; the setup in detail is the
assistant's decision. First file: `v0.1.0-alpha.1` as alpha, uploaded on 2026-11-24
(workflow green, CurseForge answered "Success!"), then in CurseForge's moderation.

- **Tool:** the BigWigs packager (`BigWigsMods/packager@v2`) as a GitHub Action in
  `.github/workflows/release.yml`. It maps `## Interface: 16001` to the CurseForge game version
  "WoW Forever" (according to the source `16???` → `forever`, version type 88568). `.pkgmeta` lifts the
  subfolder `Famulus/` to the top of the zip via `move-folders` (CurseForge wants exactly one
  folder, named like the `.toc`) and leaves the rest of the repo out. Checked locally with the
  packager (`release.sh -d -z`): one folder `Famulus` with the addon's files, version replaced.
- **Only a tag triggers it:** `v…`, which the owner sets. Pushes and pull
  requests never upload; they only run the tests (`.github/workflows/tests.yml`) and, when
  something in `website/` changes on `main`, the publishing of the website (see "Website").
- **The tag determines the file type.** `tools/release_check.sh` only allows three forms: `v1.2.3`
  (release), `v1.2.3-beta.1` (beta), `v1.2.3-alpha.1` (alpha). Reason (the owner's requirement:
  nothing with "alpha" or "beta" may appear as a normal release): the packager uploads every tag
  without these words as a release, `v0.2.0-rc1` would otherwise have reached all players. The
  script also checks that `CHANGELOG.md` has a section `## <version>` (tag without "v") with
  text, that the `.toc` carries a `## X-Curse-Project-ID` and that the secret `CF_API_KEY`
  is set. Only then do the tests run, and only if they are green does the packager build and upload.
- **Course of a release:** write a section in `CHANGELOG.md` (English, becomes the changelog of the
  file on CurseForge), bring it to `main` via pull request, then on the merged state of
  `main` (`git switch main`, `git pull`) `git tag v0.1.0` and `git push origin v0.1.0`.
  Check beforehand: `bash tools/release_check.sh v0.1.0`.
  Pull requests are squash-merged, so the branch's own commit never reaches `main`.
  `v0.1.0-alpha.4` (2026-11-25) was set on it anyway: uploaded correctly (same files as the
  merge), but the website still showed alpha.3 (see "Version on the page"). The tag was left
  there, because pushing it again would have uploaded the file a second time. Since then the job
  `check` of the Release workflow stops before tests and upload if the tagged commit is not on
  `main` (`git merge-base --is-ancestor`, with the full history), and says how to remove the tag. Started by hand (Actions › Release › Run
  workflow) the workflow builds the zip without upload and attaches it to the run for a week.
- **Version:** The `.toc` carries `@project-version@` in a `#@non-debug@` block, the packager
  inserts the tag. The working copy (junction) reads `## Version: dev` from the `#@debug@` block;
  window and self-test then show "dev". `ns.version` drops the "v" of the tag.
- **Changelog:** If `.release-notes.md` is missing, the packager builds a changelog from the commits
  (including old `Co-Authored-By` lines). That is why the workflow always writes the file, on a
  trial run as a placeholder.
- **CurseForge's rules** (support pages, read 2026-11-24): the project and every file are reviewed
  by hand (daily 8–15 CET, in order; hours to days). In the app a project only appears with at
  least one file of type release; alpha and beta are only received by those who change the
  release type for the addon. Every file needs a changelog; external download links
  are forbidden.
- **Licence (the owner's decision, 2026-11-24): all rights reserved**, following the
  pattern of Cell (`LICENSE` in the root folder). The owner wanted to show the code, but no published
  forks; the owner therefore rejected the GPL (even with name protection under section 7). Allowed: viewing
  the code, changing it for one's own use, forking on GitHub only for pull requests. Only with
  written permission: redistributing, uploading, publishing as one's own project, using larger
  parts, using the name and logo. The owner may use contributions under any terms
  (so a later licence change remains possible). The wording is a draft by the
  assistant, not legal advice; at the owner's request the author is "89pleasure". The
  packager puts the file into the zip as `Famulus/LICENSE` (checked locally; as an untracked file
  it leaves it out). On CurseForge choose "All Rights Reserved". Common at the time: all rights
  reserved for DBM, Details!, ElvUI, Cell, Masque; GPL for WeakAuras, Questie, MDT, Guildy,
  OneForAll, Polestar; MIT for OmniCC and FlareUI. No licence can switch off the fork button of a
  public repo. Open before making the repo public: the old commits contain
  `Co-Authored-By: Claude …` lines (see "Workflow").
- **Logo for the project:** `docs/curseforge/logo.png` (1024 × 1024), rendered from
  `docs/curseforge/logo.svg`: the flame from `tools/make_media.py` with glow on the dark background
  of `logo-round.tga`, as a full square, because CurseForge crops, rounds and scales it down to
  400 × 400 itself. Flame and embers lie within the inscribed circle, so a round crop
  cuts nothing off. Render again (Git Bash, Chrome on the Windows machine; the SVG comment
  must not contain a double hyphen):
  `"/c/Program Files/Google/Chrome/Application/chrome.exe" --headless=new --disable-gpu
  --hide-scrollbars --force-device-scale-factor=1 --window-size=1024,1024
  --screenshot="<abs. path>\logo.png" "file:///<abs. path>/logo.svg"`.
  The assistant's decision, not yet seen by the owner.
- **Project created** (by the owner, 2026-11-24): CurseForge project ID 1828785, stored as
  `## X-Curse-Project-ID` in the `.toc`. Trial run on GitHub on 2026-11-24 green: game version
  1.60.1 (Forever) detected, 60 files (addon plus `LICENSE`), zip `Famulus-<version>-forever.zip`
  (the packager appends "-forever", also to the label on CurseForge).
- **First file as alpha (the owner's decision, 2026-11-24):** tag `v0.1.0-alpha.1`,
  "so it doesn't go out as a release, we're not that far yet". This rejects the
  assistant's recommendation (`v0.1.0` as release, so that Famulus appears in the app). Consequence:
  as long as there is no release file, Famulus is only on CurseForge's website, not in
  the app. The section in `CHANGELOG.md` is therefore called `## 0.1.0-alpha.1`.
- **0.1.0 as a release, described as a beta (the owner's decision, 2026-11-26, issue #49):**
  after `v0.1.0-alpha.6` the next file is the tag `v0.1.0`, uploaded as type release, so that
  Famulus appears in the CurseForge app and real players can test sharing. That it is a beta is
  said in the text, not in the file type: the note at the top of `docs/curseforge/description.html`
  and the introduction of the section `## 0.1.0` in `CHANGELOG.md`. Because most players see
  Famulus for the first time with it, that section first says what Famulus does and then what
  changed since the last alpha (the assistant's proposal). The rule of `tools/release_check.sh`
  stays: a tag with "beta" in it still uploads as type beta. Uploaded on 2026-11-27 (workflow
  green, "Uploading Famulus-v0.1.0-forever.zip (1.60.1 release) … Success!"), then in
  CurseForge's moderation.
- **Token:** The owner stored the repository secret `CF_API_KEY` personally
  (2026-11-24); the token did not pass through the assistant.
- **Project page** (set by hand in the project's settings; the workflow uploads only files):
  - Summary (set by the owner, 2026-11-27): the website's hero lead, "Famulus captures what WoW
    Forever is all about: spending time in Azeroth together. It makes the MMORPG we all love even
    better and more open to everyone." (before: "Your companion for playing together: …"). It is
    also the page's meta description. The description is the assistant's text in
    `docs/curseforge/description.html` (English; Guildy is named since 2026-11-27, when its
    integration began to work with the regular Guildy 1.18.0). It links the website (famulus.camp, its FAQ and privacy policy) and
    GitHub; CurseForge forbids only external download links. Categories: the assistant advises against "Companions" (on CurseForge
    pets and mounts) and recommends "Chat & Communication" with "Guild".
  - **Description with pictures (since 2026-11-27, the owner's request: "smarter, with graphics,
    the accent colour and pictures"; look and texts the assistant's decisions):** HTML instead of
    Markdown (until then `description.md`), because only HTML carries colours: a banner (the
    website's campfire scene with logo, name and tagline), a head per area like the website's
    section heads (number, name, title, the area's icon in the accent), six framed screenshots,
    the areas' names and a few words in Lemon's accent (`#f2d640`), the smaller headings with an
    accent dot. Read on curseforge.com the same day (Plater, Details!, Bagnon and others): the
    page is dark (`#0d0d0d`, text `#999`, 836 px wide), inline `color` and `font-size` styles
    survive, pictures from other hosts (imgur, raw.githubusercontent.com, own sites) load
    directly. The pictures are drawn by `node tools/make_curseforge_art.js` from the website
    itself (Headless Chrome via the DevTools protocol; 1672 px wide, twice the column) into
    `website/assets/curseforge/`, so the description loads them from famulus.camp once the
    website with them is published. Redraw them when the website's screenshots or the areas'
    titles change, and paste the description again when its text changes.
  - **State of the live page (read 2026-11-27, evening):** the HTML description with all ten
    pictures and the accent colours, a gallery of seven pictures with the texts of
    `docs/curseforge/gallery.md`, an "Issues" tab leading to GitHub, categories "Chat &
    Communication" and "Guild". Still "Unlisted" then; `v0.1.0`, the first release file, was
    uploaded the same night, and the project appears in the app once CurseForge has approved it. CurseForge caches the
    page: right after a change a plain reload may still show the old summary.
- **Open:** Wago, GitHub releases, an approval environment for the secrets (none set up).
- Run on GitHub (2026-11-24): the test workflow, a trial run without upload and the upload
  of `v0.1.0-alpha.1` ("Uploading Famulus-v0.1.0-alpha.1-forever.zip (1.60.1 alpha) … Success!").
  A tag without upload (approval, Wago, GitHub releases) is not set up.
