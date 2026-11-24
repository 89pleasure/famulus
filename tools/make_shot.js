// Cuts the Famulus window out of a game screenshot and writes it as WebP for
// the website. Headless Chrome decodes, scales and encodes, so nothing needs
// to be installed beyond Node and Chrome.
//
//   node tools/make_shot.js <screenshot.jpg> <x> <y> <width> <height> <out-base> [width ...]
//
// x, y, width and height are screenshot pixels and frame the window from its
// outer hairline. Each output width becomes <out-base>-<width>.webp; without
// any, the full crop and 1180 (the window's own size in the game). Chrome is
// looked up at the usual places; CHROME=<path> overrides that.

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { execFileSync } = require('child_process');

const [source, x, y, width, height, outBase, ...sizes] = process.argv.slice(2);
if (!outBase) {
  console.error('usage: node tools/make_shot.js <screenshot> <x> <y> <width> <height> <out-base> [width ...]');
  process.exit(1);
}
const crop = [x, y, width, height].map(Number);
const widths = (sizes.length ? sizes.map(Number) : [crop[2], 1180]).filter(w => w > 0 && w <= crop[2]);

const chrome = process.env.CHROME || [
  'C:/Program Files/Google/Chrome/Application/chrome.exe',
  'C:/Program Files (x86)/Google/Chrome/Application/chrome.exe',
  '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
  '/usr/bin/google-chrome',
].find(candidate => fs.existsSync(candidate));
if (!chrome) {
  console.error('Chrome not found; set CHROME=<path>');
  process.exit(1);
}

// The screenshot travels inside the page as a data URL, so the canvas stays
// readable (a file:// image would taint it).
const type = /\.png$/i.test(source) ? 'image/png' : 'image/jpeg';
const image = `data:${type};base64,${fs.readFileSync(source).toString('base64')}`;
const page = `<!doctype html><meta charset="utf-8"><body><script>
const crop = ${JSON.stringify(crop)}, widths = ${JSON.stringify(widths)};
const img = new Image();
img.onload = () => {
  for (const w of widths) {
    const h = Math.round(crop[3] * w / crop[2]);
    const canvas = document.createElement('canvas');
    canvas.width = w; canvas.height = h;
    const ctx = canvas.getContext('2d');
    ctx.imageSmoothingQuality = 'high';
    ctx.drawImage(img, crop[0], crop[1], crop[2], crop[3], 0, 0, w, h);
    const out = document.createElement('pre');
    out.dataset.width = w;
    out.textContent = canvas.toDataURL('image/webp', 0.88);
    document.body.append(out);
  }
};
img.src = ${JSON.stringify(image)};
</script>`;

const pageFile = path.join(os.tmpdir(), `famulus-shot-${process.pid}.html`);
fs.writeFileSync(pageFile, page);
let dom;
try {
  dom = execFileSync(chrome, [
    '--headless=new', '--disable-gpu', '--dump-dom', '--virtual-time-budget=20000',
    'file:///' + pageFile.replace(/\\/g, '/'),
  ], { maxBuffer: 512 * 1024 * 1024, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] });
} finally {
  fs.unlinkSync(pageFile);
}

const found = [...dom.matchAll(/<pre data-width="(\d+)">data:image\/webp;base64,([A-Za-z0-9+/=]+)<\/pre>/g)];
if (found.length !== widths.length) {
  console.error(`expected ${widths.length} images, Chrome gave ${found.length}`);
  process.exit(1);
}
for (const [, w, data] of found) {
  const file = `${outBase}-${w}.webp`;
  fs.writeFileSync(file, Buffer.from(data, 'base64'));
  console.log(`${file}  ${w} x ${Math.round(crop[3] * w / crop[2])}  ${(fs.statSync(file).size / 1024).toFixed(0)} KB`);
}
