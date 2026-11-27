// Draws the pictures of the CurseForge description (docs/curseforge/description.html)
// from the website itself: its scene, fonts, colours, icons and screenshots.
// Headless Chrome loads website/index.html, a script rearranges the page for
// each picture, and the DevTools protocol takes it. Nothing needs to be
// installed beyond Node 22 (for its WebSocket) and Chrome.
//
//   node tools/make_curseforge_art.js [out-dir] [name ...]
//
// The pictures go to website/assets/curseforge/ by default, so the website
// publishes them and the description loads them from famulus.camp. They are
// 1672 px wide, twice the 836 px of CurseForge's description column, and stand
// on CurseForge's page colour, so their edges vanish into it. With names, only
// those pictures are drawn. Chrome is looked up at the usual places;
// CHROME=<path> overrides that; DEBUG=1 prints each step.

'use strict';

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawn } = require('child_process');

const root = path.resolve(__dirname, '..');
const site = path.join(root, 'website');
const [outArg, ...only] = process.argv.slice(2);
const outDir = path.resolve(outArg || path.join(site, 'assets', 'curseforge'));

// CurseForge's description column is 836 px wide (read 2026-11-27); the
// pictures are drawn at twice that.
const COLUMN = 836;
const SCALE = 2;
// The page colour of curseforge.com, read 2026-11-27.
const PAGE = '#0d0d0d';

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

const trace = process.env.DEBUG ? (...args) => console.log('·', ...args) : () => {};
const pageUrl = query => 'file:///' + path.join(site, 'index.html').replace(/\\/g, '/') + query;

// A section's head: its number and name, its title and the area's icon (the
// addon's drawings in the website's sprite). The title is HTML.
const head = (name, num, eyebrow, title, icon) => ({
  name, type: 'jpeg', viewport: [1200, 800],
  script: `
    prepare();
    document.body.insertAdjacentHTML('beforeend', \`
      <section id="cf-target" class="cf-head">
        <div class="cf-head__text">
          <p class="eyebrow"><span class="eyebrow__num">${num}</span><span>${eyebrow}</span></p>
          <h2>${title}</h2>
        </div>
        <div class="cf-head__icon"><svg class="icon" width="56" height="56"><use href="#${icon}"/></svg></div>
      </section>\`);
  `,
});

// One of the website's screenshots in a frame with rounded corners; with a crop
// ([x, y, width, height] in pixels of the 1770 px picture) only that part.
const SHOT_WIDTH = 1770;
const shot = (name, file, crop) => {
  const [x, y, w, h] = crop || [0, 0, SHOT_WIDTH, 0];
  const pct = v => `${(v / w * 100).toFixed(4)}%`;
  const frame = crop
    ? `style="aspect-ratio: ${w} / ${h}"`
    : '';
  const img = crop
    ? `style="width: ${pct(SHOT_WIDTH)}; max-width: none; margin: -${pct(y)} 0 0 -${pct(x)}"`
    : '';
  return {
    name, type: 'jpeg', viewport: [1200, 900],
    script: `
      prepare();
      document.body.insertAdjacentHTML('beforeend', \`
        <figure id="cf-target" class="cf-shot"><div class="cf-shot__frame" ${frame}>
          <img src="assets/shots/${file}-${SHOT_WIDTH}.webp" alt="" ${img}></div></figure>\`);
    `,
  };
};

// Every picture: the viewport the page is laid out in, the script that turns
// the page into the picture (it leaves the part to take as #cf-target) and the
// format. The scripts run in the page and share prepare() from PREPARE.
const PICTURES = [
  {
    name: 'banner', type: 'jpeg', viewport: [1600, 900],
    script: `
      prepare({ keepHero: true });
      const hero = document.querySelector('.hero');
      hero.querySelector('.hero__feed').remove();
      hero.querySelector('.hero__copy').innerHTML = \`
        <p class="eyebrow"><span class="eyebrow__mark"></span><span>An addon for World of Warcraft: Forever</span></p>
        <h1 class="cf-name"><img src="assets/logo.svg" alt="">Famulus</h1>
        <p class="cf-tagline">Together <em>through Azeroth.</em></p>
        <ul class="hero__facts"><li>Chronicle</li><li>Fellow travellers</li><li>Aliases</li><li>Five languages</li></ul>\`;
      hero.id = 'cf-target';
    `,
  },
  head('head-chronicle', '01', 'Chronicle', 'Your journey, told like a picture book.', 'i-flag'),
  head('head-fellows', '02', 'Fellow travellers', 'Remember who was there.', 'i-people'),
  head('head-aliases', '03', 'Aliases',
    'To you, <span class="cls--warrior">Grimtusk</span> is just <em>Tom.</em>', 'i-tag'),
  shot('shot-chronicle', 'window-lemon'),
  // Only the cards and a little of the tavern around them; the whole picture leaves them small.
  shot('shot-feed', 'feed', [384, 150, 1000, 520]),
  shot('shot-fellows', 'fellows'),
  shot('shot-story', 'story'),
  shot('shot-welcome', 'welcome'),
  shot('shot-aliases', 'aliases'),
];

// Shared by every picture's script: hides what a picture never shows, settles
// colours and motion, and styles the parts the pictures add.
const PREPARE = `
  window.prepare = ({ keepHero = false } = {}) => {
    const style = document.createElement('style');
    style.textContent = \`
      :root { --bg: ${PAGE}; }
      html, body { background: ${PAGE} !important; }
      .reveal, .js .reveal { opacity: 1 !important; transform: none !important; }
      body > *:not(#cf-target):not(.sprite) { display: none !important; }
      body > .hero#cf-target { display: flex !important; }

      .hero { min-height: 0 !important; border-radius: 22px; }
      .hero__cta { display: none !important; }
      .hero__inner { padding: 120px 0 120px !important; }
      .cf-name { display: flex; align-items: center; gap: 0.22em; margin: 26px 0 18px !important;
        font-size: 132px !important; line-height: 1 !important; letter-spacing: -0.04em; }
      .cf-name img { width: 0.82em; height: 0.82em; filter: drop-shadow(0 0 24px var(--fire-glow)); }
      .cf-tagline { font-size: 46px; font-weight: 500; letter-spacing: -0.02em; color: var(--text); }
      .cf-tagline em, .cf-head h2 em { font-style: normal; background: linear-gradient(90deg, var(--accent), var(--accent2));
        -webkit-background-clip: text; background-clip: text; color: transparent; padding-right: 0.06em; }
      .hero .eyebrow { font-size: 19px; }
      .hero .hero__facts { margin-top: 40px; font-size: 21px; color: var(--text-dim); }

      .cf-head { position: relative; overflow: hidden; width: 1000px; margin: 40px; box-sizing: border-box;
        display: flex; align-items: center; justify-content: space-between; gap: 40px; padding: 46px 52px;
        border-radius: 24px; border: 1px solid var(--hairline); box-shadow: var(--sheen);
        background: radial-gradient(420px 260px at 88% 50%, color-mix(in srgb, var(--accent) 13%, transparent), transparent 70%),
          linear-gradient(180deg, hsl(var(--h) var(--s) 8%), hsl(var(--h) var(--s) 5.5%)); }
      .cf-head .eyebrow { font-size: 16px; }
      .cf-head h2 { margin: 18px 0 0; font-size: 50px; line-height: 1.06; }
      .cf-head__icon { flex: none; display: grid; place-items: center; width: 118px; height: 118px; border-radius: 50%;
        color: var(--accent); background: var(--accent-soft); border: 1px solid var(--accent-line);
        box-shadow: 0 0 46px -6px var(--accent-glow), inset 0 0 22px -8px var(--accent-glow); }
      .cf-head__icon .icon { stroke-width: 2.2; filter: drop-shadow(0 0 8px var(--accent-glow)); }

      .cf-shot { width: 1000px; margin: 0; padding: 2px; box-sizing: border-box; }
      .cf-shot__frame { overflow: hidden; border-radius: 16px; box-shadow: 0 0 0 1px var(--hairline); }
      .cf-shot img { display: block; width: 100%; height: auto; }
    \`;
    document.head.append(style);
    if (!keepHero) document.querySelector('.hero').remove();
  };
`;

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function devtools() {
  const profile = fs.mkdtempSync(path.join(os.tmpdir(), 'famulus-art-'));
  const proc = spawn(chrome, [
    '--headless=new', '--disable-gpu', '--hide-scrollbars', '--mute-audio',
    '--allow-file-access-from-files', '--remote-debugging-port=0', '--remote-allow-origins=*',
    `--user-data-dir=${profile}`, 'about:blank',
  ], { stdio: 'ignore' });
  const portFile = path.join(profile, 'DevToolsActivePort');
  for (let i = 0; i < 100 && !fs.existsSync(portFile); i++) await sleep(100);
  const port = fs.readFileSync(portFile, 'utf8').split('\n')[0].trim();
  trace('port', port);
  const targets = await (await fetch(`http://127.0.0.1:${port}/json/list`)).json();
  const ws = new WebSocket(targets.find(t => t.type === 'page').webSocketDebuggerUrl);
  await new Promise((resolve, reject) => { ws.onopen = resolve; ws.onerror = reject; });
  trace('connected');

  let next = 0;
  const pending = new Map();
  const waiting = [];
  ws.onmessage = ({ data }) => {
    const msg = JSON.parse(data);
    if (msg.id && pending.has(msg.id)) {
      const { resolve, reject } = pending.get(msg.id);
      pending.delete(msg.id);
      msg.error ? reject(new Error(msg.error.message)) : resolve(msg.result);
    } else if (msg.method) {
      for (const w of waiting.filter(w => w.method === msg.method)) {
        waiting.splice(waiting.indexOf(w), 1);
        w.resolve(msg.params);
      }
    }
  };
  const send = (method, params = {}) => new Promise((resolve, reject) => {
    const id = ++next;
    pending.set(id, { resolve, reject });
    ws.send(JSON.stringify({ id, method, params }));
  });
  const once = method => new Promise(resolve => waiting.push({ method, resolve }));
  const close = () => {
    ws.close();
    proc.kill();
    setTimeout(() => fs.rmSync(profile, { recursive: true, force: true }), 500);
  };
  return { send, once, close };
}

async function draw(cdp, picture) {
  const [width, height] = picture.viewport;
  await cdp.send('Emulation.setDeviceMetricsOverride', { width, height, deviceScaleFactor: SCALE, mobile: false });
  const loaded = cdp.once('Page.loadEventFired');
  await cdp.send('Page.navigate', { url: pageUrl('?world=night&lang=en') });
  await loaded;
  trace('loaded', picture.name);
  // The scene draws itself after loading.
  await sleep(1200);
  const result = await cdp.send('Runtime.evaluate', {
    expression: `(async () => {
      ${PREPARE}
      ${picture.script}
      await document.fonts.ready;
      const target = document.getElementById('cf-target');
      // Only the target's pictures: a lazy one elsewhere never loads, so its decode() never ends.
      await Promise.all([...target.querySelectorAll('img')].map(img => {
        img.loading = 'eager';
        return Promise.race([img.decode().catch(() => {}), new Promise(r => setTimeout(r, 5000))]);
      }));
      const r = target.getBoundingClientRect();
      return JSON.stringify({ x: r.x + scrollX, y: r.y + scrollY, width: r.width, height: r.height });
    })()`,
    awaitPromise: true, returnByValue: true,
  });
  if (result.exceptionDetails) {
    throw new Error(result.exceptionDetails.exception?.description || result.exceptionDetails.text);
  }
  await sleep(600);
  const box = JSON.parse(result.result.value);
  const scale = COLUMN / box.width;
  const shot = await cdp.send('Page.captureScreenshot', {
    format: picture.type, quality: picture.type === 'jpeg' ? 88 : undefined,
    captureBeyondViewport: true, clip: { ...box, scale },
  });
  const file = path.join(outDir, `${picture.name}.${picture.type === 'jpeg' ? 'jpg' : 'png'}`);
  fs.writeFileSync(file, Buffer.from(shot.data, 'base64'));
  const kb = Math.round(fs.statSync(file).size / 1024);
  console.log(`${path.relative(root, file)}  ${Math.round(box.width * scale * SCALE)} x ${Math.round(box.height * scale * SCALE)}  ${kb} KB`);
}

(async () => {
  fs.mkdirSync(outDir, { recursive: true });
  const cdp = await devtools();
  try {
    await cdp.send('Page.enable');
    for (const picture of PICTURES.filter(p => !only.length || only.includes(p.name))) {
      await draw(cdp, picture);
    }
  } finally {
    cdp.close();
  }
})().catch(error => {
  console.error(error);
  process.exit(1);
});
