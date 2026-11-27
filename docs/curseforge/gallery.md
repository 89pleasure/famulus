# Gallery of the CurseForge project page

The pictures are the website's screenshots (`website/assets/shots/<name>-1770.webp`, see
"Window in the header" and "Gallery" in docs/website.md), turned into JPG because the upload
form of CurseForge may not take WebP. Make them in Git Bash (ffmpeg, see "Sound" in
docs/chronicle.md), in the order of the table:

```bash
mkdir -p dist/gallery && i=1 && for n in window-lemon fellows story groups feed welcome aliases; do ffmpeg -loglevel error -y -i "website/assets/shots/$n-1770.webp" -q:v 2 "dist/gallery/$(printf %02d $i)-$n.jpg"; i=$((i+1)); done
```

`dist/gallery/` is in `.gitignore`. When a screenshot on the website changes, upload it here again.
The first picture shows real friends' names (the owner allowed them on the website, 2026-11-27).

| File | Title | Description |
|---|---|---|
| `01-window-lemon.jpg` | The chronicle | Your journey and your friends' as a picture book, one chapter per play session, with your week and your friends beside it. |
| `02-fellows.jpg` | Fellowship | Your closest companions and everyone you grouped with. |
| `03-story.jpg` | Your story | Your bond with Mira, your numbers and every session together. |
| `04-groups.jpg` | Groups | Who was out with whom, and who you play with most often. |
| `05-feed.jpg` | Live feed | The newest card on top, older ones as rows. |
| `06-welcome.jpg` | Welcome | One click switches on the main features. |
| `07-aliases.jpg` | Aliases | The aliases' settings, with a live picture of the chat. |
