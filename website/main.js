// What moves and answers on the page: language, navigation, and the demos
// (chronicle, fellow travellers, live feed, aliases). The demos rebuild
// what the addon shows, with made-up people; nothing is sent anywhere.
(() => {
  'use strict';

  const root = document.documentElement;
  const I18N = window.FAMULUS_I18N;
  const Scene = window.FamulusScene;
  // Read whenever it matters: the setting can change while the page is open.
  const motion = matchMedia('(prefers-reduced-motion: reduce)');
  const SVG = 'http://www.w3.org/2000/svg';

  const $ = (selector, scope = document) => scope.querySelector(selector);
  const $$ = (selector, scope = document) => [...scope.querySelectorAll(selector)];
  const clamp = (value, low, high) => Math.max(low, Math.min(high, value));

  function make(tag, className, text) {
    const element = document.createElement(tag);
    if (className) element.className = className;
    if (text != null) element.textContent = text;
    return element;
  }

  function icon(name, size = 16) {
    const svg = document.createElementNS(SVG, 'svg');
    svg.setAttribute('class', 'icon');
    svg.setAttribute('width', size);
    svg.setAttribute('height', size);
    svg.setAttribute('aria-hidden', 'true');
    const use = document.createElementNS(SVG, 'use');
    use.setAttribute('href', `#i-${name}`);
    svg.append(use);
    return svg;
  }

  // Tabs: arrow keys, Home and End move between the tabs of a list and choose
  // the one they land on; only the chosen tab is in the Tab order.
  function tablist(list) {
    const tabs = $$('[role="tab"]', list);
    const STEP = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 };
    list.addEventListener('keydown', event => {
      const index = tabs.indexOf(event.target);
      if (index < 0) return;
      const step = STEP[event.key];
      const to = step ? (index + step + tabs.length) % tabs.length
        : event.key === 'Home' ? 0 : event.key === 'End' ? tabs.length - 1 : -1;
      if (to < 0) return;
      event.preventDefault();
      tabs[to].focus();
      tabs[to].click();
    });
  }
  function chooseTab(tab, chosen) {
    tab.setAttribute('aria-selected', String(chosen));
    tab.tabIndex = chosen ? 0 : -1;
  }

  // Remembering a choice is a convenience; the page works without it.
  const store = {
    get(key) {
      try { return localStorage.getItem(key); } catch { return null; }
    },
    set(key, value) {
      try { localStorage.setItem(key, value); } catch { /* private mode */ }
    },
  };

  // -------------------------------------------------------------------------
  // Language. English stands in the HTML; collect it once, so that switching
  // back works. Scripts that put text together register a renderer.
  // -------------------------------------------------------------------------

  let lang = 'en';
  const renderers = [];
  const attributeKeys = element => element.dataset.i18nAttr.split(';').map(pair => pair.split(':'));

  for (const element of $$('[data-i18n]')) I18N.en[element.dataset.i18n] = element.innerHTML;
  for (const element of $$('[data-i18n-attr]')) {
    for (const [attribute, key] of attributeKeys(element)) I18N.en[key] = element.getAttribute(attribute);
  }
  I18N.en.meta_title = document.title;
  I18N.en.meta_desc = $('meta[name="description"]').content;

  // Every language must know every key, as in the addon.
  for (const [code, table] of Object.entries(I18N)) {
    const missing = Object.keys(I18N.en).filter(key => table[key] == null);
    if (missing.length) console.warn(`[famulus] ${code} lacks: ${missing.join(', ')}`);
  }

  function t(key, ...values) {
    const table = I18N[lang];
    const text = table && table[key] != null ? table[key] : I18N.en[key];
    if (text == null) return key;
    let index = 0;
    return text.replace(/%[sd]/g, () => values[index++]);
  }

  function setLanguage(next, remember) {
    lang = I18N[next] ? next : 'en';
    root.lang = lang;
    for (const element of $$('[data-i18n]')) element.innerHTML = t(element.dataset.i18n);
    for (const element of $$('[data-i18n-attr]')) {
      for (const [attribute, key] of attributeKeys(element)) element.setAttribute(attribute, t(key));
    }
    document.title = t('meta_title');
    $('meta[name="description"]').content = t('meta_desc');
    for (const button of $$('.lang button')) button.setAttribute('aria-pressed', String(button.dataset.lang === lang));
    if (remember) store.set('famulus-lang', lang);
    for (const render of renderers) render();
  }

  for (const button of $$('.lang button')) {
    button.addEventListener('click', () => setLanguage(button.dataset.lang, true));
  }

  // -------------------------------------------------------------------------
  // Coming in on scroll, drifting with it, and the navigation's state.
  // -------------------------------------------------------------------------

  const revealer = new IntersectionObserver(entries => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      entry.target.classList.add('is-in');
      revealer.unobserve(entry.target);
    }
  }, { rootMargin: '0px 0px -7% 0px', threshold: 0.06 });

  function watch(scope) {
    for (const element of $$('.reveal:not(.is-in)', scope)) revealer.observe(element);
  }

  // data-parallax="0.1": the element drifts by that share of its parent's
  // distance from the middle of the screen.
  const drifting = $$('[data-parallax]').map(element => ({
    element,
    anchor: element.parentElement,
    speed: parseFloat(element.dataset.parallax),
    near: false,
  }));
  const nearby = new IntersectionObserver(entries => {
    for (const entry of entries) {
      for (const item of drifting) if (item.anchor === entry.target) item.near = entry.isIntersecting;
    }
    drift();
  }, { rootMargin: '30% 0px' });
  for (const item of drifting) nearby.observe(item.anchor);

  function drift() {
    const middle = innerHeight / 2;
    for (const item of drifting) {
      if (motion.matches) {
        item.element.style.transform = '';
        continue;
      }
      if (!item.near) continue;
      const box = item.anchor.getBoundingClientRect();
      const offset = (box.top + box.height / 2 - middle) * item.speed;
      item.element.style.transform = `translate3d(0,${offset.toFixed(1)}px,0)`;
    }
  }

  const nav = $('#nav');
  let ticking = false;
  function onScroll() {
    if (ticking) return;
    ticking = true;
    requestAnimationFrame(() => {
      ticking = false;
      nav.classList.toggle('is-stuck', scrollY > 24);
      drift();
    });
  }
  addEventListener('scroll', onScroll, { passive: true });
  addEventListener('resize', onScroll);
  motion.addEventListener('change', drift);

  // Which section the middle of the screen is in.
  const links = $$('.nav__links a');
  const spy = new IntersectionObserver(entries => {
    for (const entry of entries) {
      if (!entry.isIntersecting) continue;
      for (const link of links) link.classList.toggle('is-here', link.getAttribute('href') === `#${entry.target.id}`);
    }
  }, { rootMargin: '-45% 0px -50% 0px' });
  for (const section of $$('#top, main > section')) spy.observe(section);

  // -------------------------------------------------------------------------
  // The people of the demos. All of them are made up.
  // -------------------------------------------------------------------------

  const MIRA = 'Mira Sturmfeder';
  const BORIN = 'Borin Eisenbart';
  const KAELRIC = 'Kaelric Dornwald';
  const THESSA = 'Thessa Dornwald';
  const YORICK = 'Yorick Talwind';
  const LYSA = 'Lysa Morgentau';
  const ENA = 'Ena Silberquell';

  const PEOPLE = {
    [LYSA]: { level: 39, cls: 'priest', colour: '#ffffff' },
    [ENA]: { level: 37, cls: 'druid', colour: '#ff7c0a' },
    [MIRA]: { level: 40, cls: 'mage', colour: '#3fc7eb' },
    [BORIN]: { level: 31, cls: 'warrior', colour: '#c69b6d' },
    [KAELRIC]: { level: 39, cls: 'paladin', colour: '#f48cba' },
    [THESSA]: { level: 12, cls: 'hunter', colour: '#aad372' },
    [YORICK]: { level: 40, cls: 'rogue', colour: '#fff468' },
  };

  // An alias belongs to a character (name) or to a Battle.net account (tag),
  // which then covers all of that friend's characters.
  const aliases = [
    { name: MIRA, alias: 'Lena' },
    { name: BORIN, alias: 'Jonas' },
    { tag: 'Nachtfalke#2817', alias: 'Papa', chars: [KAELRIC, THESSA] },
  ];

  // As in the addon: lower case, spaces and hyphens alike.
  const keyOf = name => name.trim().toLowerCase().replace(/[\s-]+/g, '-');
  const initial = name => ([...name.trim()][0] || '?').toUpperCase();

  // The character's own alias wins over the one of its account.
  function aliasOf(name) {
    const key = keyOf(name);
    const own = aliases.find(entry => entry.name && keyOf(entry.name) === key);
    if (own) return own.alias;
    const account = aliases.find(entry => entry.chars && entry.chars.some(char => keyOf(char) === key));
    return account ? account.alias : null;
  }
  const nameOf = name => aliasOf(name) || name;

  // -------------------------------------------------------------------------
  // 01 Aliases: the window on the left works, the game on the right follows.
  // -------------------------------------------------------------------------

  const demo = $('#alias-demo');
  const form = $('#alias-form');
  const nameField = $('#alias-name');
  const aliasField = $('#alias-alias');
  const state = { master: true, chat: true, tooltip: true, menu: true, style: 'alias', tab: 'names', editing: null, tip: MIRA };

  const CHAT = [
    { channel: 'guild', who: MIRA, text: 'chat_1' },
    { channel: 'party', who: BORIN, text: 'chat_2' },
    { channel: 'guild', who: KAELRIC, text: 'chat_3' },
    { channel: 'whisper', who: THESSA, text: 'chat_4' },
    { channel: 'guild', who: YORICK, text: 'chat_5' },
    { channel: 'party', who: MIRA, text: 'chat_6' },
  ];
  const lastShown = []; // what each line showed last, to mark what changed

  function chatName(name) {
    const alias = state.master && state.chat ? aliasOf(name) : null;
    if (!alias) return name;
    return state.style === 'both' ? `${alias} (${name})` : alias;
  }

  function renderChat(mark) {
    const box = $('#chat');
    box.textContent = '';
    CHAT.forEach((line, index) => {
      const row = make('p', `chat__line chat__line--${line.channel}`);
      const shown = chatName(line.who);
      const name = make('button', 'chat__name', shown);
      name.type = 'button';
      name.setAttribute('aria-describedby', 'tip'); // the tooltip it brings up
      if (mark && lastShown[index] != null && lastShown[index] !== shown) name.classList.add('is-changed');
      lastShown[index] = shown;
      const point = () => {
        state.tip = line.who;
        renderTip();
      };
      name.addEventListener('pointerenter', point);
      name.addEventListener('focus', point);
      name.addEventListener('click', point); // a tap, where there is no hover
      if (line.channel === 'whisper') row.append('[', name, `] ${t('chat_whispers')}: ${t(line.text)}`);
      else row.append(`[${t(`chat_${line.channel}`)}] [`, name, `]: ${t(line.text)}`);
      box.append(row);
    });
  }

  // The game's tooltip of a player, with the line Famulus adds.
  function renderTip() {
    const tip = $('#tip');
    const person = PEOPLE[state.tip];
    tip.textContent = '';
    const name = make('strong', '', state.tip);
    name.style.color = person.colour;
    tip.append(name, make('span', '', t('tip_level', person.level, t(`cls_${person.cls}`))));
    const alias = state.master && state.tooltip ? aliasOf(state.tip) : null;
    if (alias) {
      const line = make('span', 'tip__alias');
      line.append(make('span', '', t('tt_alias')), make('b', '', alias));
      tip.append(line);
    }
  }

  function renderAliases() {
    const list = $('#alias-list');
    list.textContent = '';
    if (!aliases.length) {
      const empty = make('li', 'aliaslist__empty');
      empty.append(make('strong', '', t('w_list_empty')), make('span', '', t('w_list_empty_d')));
      list.append(empty);
      return;
    }
    for (const entry of aliases) {
      const item = make('li', `aliasrow${entry === state.editing ? ' is-editing' : ''}`);
      const open = make('button', 'aliasrow__open');
      open.type = 'button';
      const text = make('span', 'aliasrow__text');
      const detail = entry.tag
        ? `${t('w_account', entry.tag)}  ·  ${entry.chars.length ? entry.chars.join(', ') : t('w_account_none')}`
        : entry.name;
      text.append(make('strong', '', entry.alias), make('span', '', detail));
      open.append(make('span', 'avatar', initial(entry.alias)), text);
      open.addEventListener('click', () => {
        state.editing = entry;
        nameField.value = entry.tag || entry.name;
        aliasField.value = entry.alias;
        renderAliases();
        aliasField.focus({ preventScroll: true });
        aliasField.select();
      });
      const remove = make('button', 'aliasrow__remove');
      remove.type = 'button';
      remove.setAttribute('aria-label', t('w_remove', entry.tag || entry.name));
      remove.append(icon('close', 12));
      remove.addEventListener('click', () => {
        const at = aliases.indexOf(entry);
        aliases.splice(at, 1);
        if (state.editing === entry) {
          state.editing = null;
          form.reset();
        }
        refresh(true);
        // The focus goes on to the row that took its place, not to the page's top.
        const rows = $$('.aliasrow__remove', $('#alias-list'));
        (rows[Math.min(at, rows.length - 1)] || nameField).focus({ preventScroll: true });
      });
      item.append(open, remove);
      list.append(item);
    }
  }

  // Reset works on the settings section only, like in the addon: the
  // features there and the master switch. The first click asks; a second
  // one within four seconds resets.
  const DEFAULTS = { master: true, chat: true, tooltip: true, menu: true, style: 'alias' };
  const resetButton = $('#alias-reset');
  let asking = 0;
  const atDefaults = () => Object.entries(DEFAULTS).every(([key, value]) => state[key] === value);

  function stopAsking() {
    clearTimeout(asking);
    asking = 0;
  }

  function renderReset() {
    const idle = atDefaults();
    if (idle) stopAsking();
    resetButton.hidden = state.tab !== 'display';
    resetButton.disabled = idle;
    resetButton.classList.toggle('is-asking', asking !== 0);
    resetButton.textContent = t(asking ? 'w_reset_confirm' : 'w_reset');
  }

  resetButton.addEventListener('click', () => {
    if (atDefaults()) return;
    if (!asking) {
      asking = setTimeout(() => {
        asking = 0;
        renderReset();
      }, 4000);
      renderReset();
      return;
    }
    stopAsking();
    Object.assign(state, DEFAULTS);
    $('#alias-style').value = state.style;
    refresh(true);
  });

  function renderWindow() {
    for (const button of $$('[data-switch]', demo)) {
      const on = state[button.dataset.switch];
      button.setAttribute('aria-checked', String(on));
      const label = $('.switch__label', button);
      if (label) label.textContent = t(on ? 'on' : 'off');
    }
    for (const card of $$('[data-feature]', demo)) {
      card.classList.toggle('is-on', state.master && state[card.dataset.feature]);
    }
    demo.classList.toggle('is-off', !state.master);
    for (const tab of $$('[data-tab]', demo)) chooseTab(tab, tab.dataset.tab === state.tab);
    for (const pane of $$('[data-pane]', demo)) pane.hidden = pane.dataset.pane !== state.tab;
    $('#alias-tabtitle').textContent = t(`w_tab_${state.tab}`);
    $('#alias-tabdesc').textContent = t(`w_tabdesc_${state.tab}`);
    renderReset();

    // The counters: three alias features to switch here and two more the
    // demo leaves on; in all, the five of the aliases, four of the chronicle
    // (the live feed is on) and one of the fellow travellers.
    const running = state.master ? ['chat', 'tooltip', 'menu'].filter(key => state[key]).length + 2 : 0;
    $('#alias-count').textContent = state.master ? `${running}/5` : t('off');
    $('#active-count').textContent = t('w_active', running + 1, 10);
  }

  function refresh(mark) {
    renderAliases();
    renderWindow();
    renderChat(mark);
    renderTip();
    renderBook(); // companions appear under their alias there too
    renderFellows(); // and among the fellow travellers
  }

  for (const button of $$('[data-switch]', demo)) {
    button.addEventListener('click', () => {
      state[button.dataset.switch] = !state[button.dataset.switch];
      refresh(true);
    });
  }
  for (const tab of $$('[data-tab]', demo)) {
    tab.addEventListener('click', () => {
      state.tab = tab.dataset.tab;
      stopAsking();
      renderWindow();
    });
  }
  tablist($('.fwin__tabs', demo));
  $('#alias-style').addEventListener('change', event => {
    state.style = event.target.value;
    renderReset();
    renderChat(true);
  });

  form.addEventListener('submit', event => {
    event.preventDefault();
    const name = nameField.value.trim().replace(/\s+/g, ' ');
    const alias = aliasField.value.replace(/\|/g, '').trim(); // plain text only, as in the addon
    if (!name || !alias) {
      (name ? aliasField : nameField).focus({ preventScroll: true });
      return;
    }
    const isTag = name.includes('#'); // a character name never contains "#"
    const known = aliases.find(entry => (isTag
      ? entry.tag && entry.tag.toLowerCase() === name.toLowerCase()
      : entry.name && keyOf(entry.name) === keyOf(name)));
    if (known) {
      known.alias = alias;
    } else if (isTag) {
      aliases.unshift({ tag: name, alias, chars: [] });
    } else {
      const spelled = Object.keys(PEOPLE).find(person => keyOf(person) === keyOf(name));
      aliases.unshift({ name: spelled || name, alias });
    }
    state.editing = null;
    form.reset();
    refresh(true);
  });

  // -------------------------------------------------------------------------
  // 02 Chronicle: the picture book. The entries are the addon's own samples
  // (/fam chronicle demo), told the way the book tells them.
  // -------------------------------------------------------------------------

  // Per kind: the picture's icon (none: the number), its tone, and the icon
  // on the line. As PICTURES in Famulus/UI/Book.lua.
  const PICTURES = {
    level: { tone: 'accent', mark: 'sparkle' },
    achievement: { icon: 'star', tone: 'accent' },
    zone: { icon: 'peaks', tone: 'plain' },
    skill: { tone: 'accent', mark: 'hammer' },
    item: { icon: 'chest', tone: 'accent' },
    ability: { icon: 'horseshoe', tone: 'accent' },
    death: { icon: 'skull', tone: 'death' },
    boss: { icon: 'swords', tone: 'boss' },
    // The story of a fellow traveller: time together, and the bond's milestones.
    fellow: { icon: 'people', tone: 'plain' },
    bond: { icon: 'people', tone: 'accent' },
  };

  // Newest first. Yesterday holds three deaths in a row and two levels of a
  // companion, so the book shows how it bundles them. A chapter's head is
  // worked out from the events it shows (chapterHead).
  const CHAPTERS = [
    {
      day: 'c_today',
      events: [
        { time: '21:42', kind: 'item', who: MIRA, zone: 'Feralas' },
        { time: '21:10', kind: 'boss', who: BORIN, zone: 'Uldaman' },
        { time: '20:36', kind: 'item', zone: 'Tanaris' },
        { time: '20:05', kind: 'ability', level: 40, big: true },
        { time: '19:48', kind: 'level', number: 40, zone: 'Tanaris', big: true },
        { time: '19:02', kind: 'zone', zone: 'Tanaris', level: 39 },
      ],
    },
    {
      day: 'c_yesterday',
      events: [
        { time: '23:15', kind: 'ability', who: MIRA, level: 40 },
        { time: '22:58', kind: 'level', who: BORIN, number: 31, zone: 'Feralas' },
        { time: '22:31', kind: 'level', who: BORIN, number: 30, zone: 'Feralas' },
        { time: '22:20', kind: 'skill', number: 75, zone: 'Uldaman' },
        { time: '21:52', kind: 'death', zone: 'Uldaman', level: 39 },
        { time: '21:47', kind: 'death', zone: 'Uldaman', level: 39 },
        { time: '21:44', kind: 'death', zone: 'Uldaman', level: 39 },
        { time: '21:40', kind: 'death', who: BORIN, zone: 'Feralas', level: 29 },
        { time: '21:05', kind: 'level', number: 39, zone: 'Uldaman', big: true },
        { time: '20:30', kind: 'boss', zone: 'Uldaman' },
        { time: '19:10', kind: 'achievement', zone: 'Desolace' },
      ],
    },
  ];

  // What the companions shared: online or not, and their profile (deaths,
  // creatures defeated, quests, dungeons; the game's statistics).
  const COMPANIONS = {
    [MIRA]: { online: true, profile: [212, 4810, 388, 41] },
    [BORIN]: { online: false, profile: [340, 3102, 251, 27] },
  };
  const CRAFTS = [
    { name: 'n_tailoring', value: 92, max: 150 },
    { name: 'n_cooking', value: 38, max: 75 },
  ];

  // The headline and the line below it. `named`: say whose event it is (the
  // live feed does; the book has the name in the strip below the card).
  function tell(event, named) {
    const who = named && event.who ? nameOf(event.who) : null;
    const place = event.zone ? t('c_in', event.zone) : null;
    const level = event.level ? t('c_at_level', event.level) : null;
    switch (event.kind) {
      case 'level':
        return { title: who ? t('c_their_level', who, event.number) : t('c_level', event.number), detail: place };
      case 'death':
        return { title: who ? t('c_their_death', who, event.zone) : t('c_death', event.zone), detail: level };
      case 'boss':
        return { title: who ? t('c_their_boss', who, 'Archaedas') : t('c_boss', 'Archaedas'), detail: place };
      case 'zone':
        return { title: t('c_zone', event.zone), detail: level };
      case 'ability':
        return { title: who ? t('c_their_ability_riding', who) : t('c_ability_riding'), detail: level };
      case 'item':
        return { title: who ? t('c_their_item', who, t('n_bag')) : t('c_item', t('n_bag')), detail: place };
      case 'skill':
        return {
          title: who ? t('c_their_skill', who, t('n_tailoring'), event.number) : t('c_skill', t('n_tailoring'), event.number),
          detail: place,
        };
      default:
        return { title: t('c_achievement', t('n_challenge')), detail: place };
    }
  }

  // `count`: how many events a bundled card stands for, in the corner of a
  // picture that has no number of its own.
  function picture(event, count) {
    const look = PICTURES[event.kind];
    const frame = make('span', `pic pic--${look.tone}`);
    frame.append(look.icon ? icon(look.icon, 28) : make('b', '', event.number));
    if (count > 1 && look.icon) frame.append(make('i', 'pic__count', count));
    return frame;
  }

  // Events that follow each other share a card: deaths in the same zone, and
  // levels of the same companion. Your own levels stay single; they are the
  // milestones. As SameRun in Famulus/UI/Options.lua.
  const sameRun = (a, b) => a.kind === b.kind && a.who === b.who
    && ((a.kind === 'death' && a.zone === b.zone) || (a.kind === 'level' && a.who != null));

  function runsOf(events) {
    const runs = [];
    for (const event of events) {
      const run = runs[runs.length - 1];
      if (run && sameRun(run[0], event)) run.push(event);
      else runs.push([event]);
    }
    return runs;
  }

  // Headline and line below for a bundle (newest first).
  function tellRun(run) {
    const newest = run[0];
    const levels = run.map(event => (event.kind === 'level' ? event.number : event.level)).filter(Boolean);
    const low = Math.min(...levels);
    const high = Math.max(...levels);
    if (newest.kind === 'death') {
      return { title: t('c_deaths', run.length, newest.zone), detail: low === high ? t('c_at_level', low) : t('c_at_levels', low, high) };
    }
    const oneZone = run.every(event => event.zone === newest.zone);
    return { title: t('c_levels', low, high), detail: oneZone ? t('c_in', newest.zone) : null };
  }

  let bookTab = 'all';
  let bookWho = null; // a companion picked in the rail: the book shows only them

  const wanted = event => (bookTab === 'all' || (bookTab === 'mine') === !event.who)
    && (!bookWho || event.who === bookWho);

  // As TitleChapter in Famulus/UI/Options.lua, from the events shown: the
  // zone most of them happened in (the first to get ahead wins a tie, the
  // newest first), else the day; the levels you reached, from your own
  // events only; and how many events there are.
  function chapterHead(chapter, events) {
    const counts = {};
    let zone = null;
    let low = Infinity;
    let high = -Infinity;
    for (const event of events) {
      if (event.zone) {
        counts[event.zone] = (counts[event.zone] || 0) + 1;
        if (!zone || counts[event.zone] > counts[zone]) zone = event.zone;
      }
      const level = event.who ? null : (event.kind === 'level' ? event.number : event.level);
      if (level) {
        low = Math.min(low, level);
        high = Math.max(high, level);
      }
    }
    const parts = [];
    if (low < Infinity) parts.push(low === high ? t('c_ch_level', low) : t('c_ch_levels', low, high));
    parts.push(events.length === 1 ? t('c_ch_event') : t('c_ch_events', events.length));
    return { title: zone || t(chapter.day), day: zone ? t(chapter.day) : '', sub: parts.join('  ·  ') };
  }

  function renderBook() {
    const book = $('#book');
    book.textContent = '';
    for (const chapter of CHAPTERS) {
      const events = chapter.events.filter(wanted);
      if (!events.length) continue;

      // The head in one line: the day, the zone in the book's type, levels
      // and the number of events; a line on each side running out.
      const head = make('header', 'chapter__head reveal');
      const told = chapterHead(chapter, events);
      const before = make('div', 'chapter__side');
      before.append(make('i'), make('p', 'chapter__day', told.day));
      const after = make('div', 'chapter__side');
      after.append(make('p', 'chapter__sub', told.sub), make('i'));
      head.append(before, make('h3', '', told.title), after);

      const trail = make('div', 'chapter__events');
      for (const run of runsOf(events)) {
        const event = run[0];
        const many = run.length > 1;
        const look = PICTURES[event.kind];
        const told = many ? tellRun(run) : tell(event, false);
        const story = make('article', `story story--${look.tone} reveal${event.big ? ' is-big' : ''}`);
        const dot = make('span', 'story__dot');
        dot.append(icon(look.mark || look.icon, 12));
        const text = make('div', 'story__text');
        text.append(make('h4', '', told.title));
        const line = many ? told.detail : [told.detail, event.time].filter(Boolean).join('  ·  ');
        if (line) text.append(make('p', '', line));
        if (many) {
          // Every time of the bundle, the oldest first.
          const times = make('div', 'story__times');
          for (const each of [...run].reverse()) times.append(make('span', '', each.time));
          text.append(times);
        }
        // A companion's levels show the highest one in the picture.
        const shown = many && event.kind === 'level' ? { ...event, number: Math.max(...run.map(each => each.number)) } : event;
        const body = make('div', 'story__body');
        body.append(picture(shown, run.length), text);
        const card = make('div', 'story__card');
        card.append(body);
        if (event.who) {
          // Whose event it is: in the sunken strip, under the alias if there is one.
          const name = nameOf(event.who);
          const foot = make('div', 'story__foot');
          foot.append(make('span', 'avatar avatar--small', initial(name)), make('span', '', name));
          card.append(foot);
        }
        story.append(dot, card);
        trail.append(story);
      }

      const section = make('section', 'chapter');
      section.append(head, trail);
      book.append(section);
    }
    renderFilter();
    renderRail();
    spaceDots();
    watch(book);
  }

  // -------------------------------------------------------------------------
  // The rail beside the book, as Famulus/UI/Rail.lua: Everyone shows the week
  // and the companions, My journey the week and the professions, Companions
  // one profile per companion.
  // -------------------------------------------------------------------------

  const ownEvents = () => CHAPTERS.flatMap(chapter => chapter.events).filter(event => !event.who);
  const number = value => value.toLocaleString(lang === 'de' ? 'de-DE' : 'en-US');

  // Everyone with an event in the book, the one heard from last first.
  function companions() {
    const list = [];
    for (const chapter of CHAPTERS) {
      for (const event of chapter.events) {
        if (event.who && !list.some(item => item.who === event.who)) list.push({ who: event.who, event, day: chapter.day });
      }
    }
    return list;
  }

  function railCard(title, note) {
    const card = make('section', 'rcard');
    const head = make('header', 'rcard__head');
    head.append(make('h4', '', title));
    if (note != null) head.append(make('span', '', note));
    card.append(head);
    return card;
  }

  function statGrid(stats) {
    const grid = make('div', 'rcard__stats');
    for (const [label, value, plus] of stats) {
      const cell = make('div', 'rstat');
      const figure = make('p');
      figure.append(make('b', '', value));
      if (plus) figure.append(make('em', '', plus));
      cell.append(figure, make('span', '', label));
      grid.append(cell);
    }
    return grid;
  }

  let focusWho = null; // keep the focus on a person's row when the rail is drawn again

  function personButton(who, line) {
    const name = nameOf(who);
    const online = COMPANIONS[who].online;
    const button = make('button', 'person');
    button.type = 'button';
    button.dataset.who = who;
    button.setAttribute('aria-pressed', String(bookWho === who));
    const text = make('span', 'person__text');
    text.append(make('strong', '', name));
    if (line) text.append(make('span', '', line));
    const end = make('span', 'person__end');
    end.append(
      make('span', '', t('c_p_level', PEOPLE[who].level)),
      make('span', `person__state${online ? ' is-online' : ''}`, t(online ? 'c_online' : 'c_offline')),
    );
    button.append(make('span', 'avatar', initial(name)), text, end);
    button.addEventListener('click', () => {
      bookWho = bookWho === who ? null : who;
      focusWho = who;
      renderBook();
    });
    return button;
  }

  function weekCard() {
    const own = ownEvents();
    const counted = (...kinds) => String(own.filter(event => kinds.includes(event.kind)).length);
    const levels = own.filter(event => event.kind === 'level').map(event => event.number);
    const card = railCard(t('c_week'));
    card.append(statGrid([
      [t('c_week_level'), String(Math.max(...levels)), `+${levels.length}`],
      [t('c_week_deaths'), counted('death')],
      [t('c_week_zones'), counted('zone')],
      [t('c_week_crafts'), counted('skill', 'profession')],
    ]));
    return card;
  }

  function companionsCard() {
    const list = companions();
    const card = railCard(t('c_companions'), String(list.length));
    for (const { who, event, day } of list) {
      const when = day === 'c_today' ? event.time : t(day);
      card.append(personButton(who, `${tell(event, false).title}  ·  ${when}`));
    }
    card.append(make('p', 'rcard__hint', t('c_rail_filter')));
    return card;
  }

  function craftsCard() {
    const card = railCard(t('c_crafts'));
    for (const craft of CRAFTS) {
      const bar = make('div', 'rbar');
      const label = make('p');
      label.append(make('span', '', t(craft.name)), make('span', '', `${craft.value} / ${craft.max}`));
      const track = make('span', 'rbar__track');
      const fill = make('i');
      fill.style.width = `${(craft.value / craft.max) * 100}%`;
      track.append(fill);
      bar.append(label, track);
      card.append(bar);
    }
    return card;
  }

  function briefCard(who) {
    const card = make('section', `rcard rcard--brief${bookWho === who ? ' is-picked' : ''}`);
    card.append(personButton(who, aliasOf(who) ? who : null));
    const [deaths, creatures, quests, dungeons] = COMPANIONS[who].profile;
    card.append(statGrid([
      [t('c_stat_60'), number(deaths)],
      [t('c_stat_107'), number(creatures)],
      [t('c_stat_98'), number(quests)],
      [t('c_stat_932'), number(dungeons)],
    ]));
    return card;
  }

  function renderRail() {
    const rail = $('#rail');
    rail.textContent = '';
    if (bookTab === 'all') rail.append(weekCard(), companionsCard());
    else if (bookTab === 'mine') rail.append(weekCard(), craftsCard());
    else for (const { who } of companions()) rail.append(briefCard(who));
    if (focusWho) {
      const row = $$('.person', rail).find(button => button.dataset.who === focusWho)
        || $('#book-tabs [aria-selected="true"]');
      row.focus({ preventScroll: true });
      focusWho = null;
    }
  }

  // Above the book while a companion is picked.
  function renderFilter() {
    $('#book-filter').hidden = !bookWho;
    if (bookWho) $('#book-filter-text').textContent = t('c_only_who', nameOf(bookWho));
  }

  $('#book-filter-clear').addEventListener('click', () => {
    focusWho = bookWho; // the button goes away; the focus goes back to the person
    bookWho = null;
    renderBook();
  });

  // Each column runs on by itself, so two events can start at almost the
  // same height. Their dots on the line keep a distance, as in the addon.
  const DOT_GAP = 36;
  const oneColumn = matchMedia('(max-width: 760px)');

  function spaceDots() {
    for (const trail of $$('.chapter__events')) {
      let last = -Infinity;
      for (const story of trail.children) {
        story.style.marginTop = '';
        if (oneColumn.matches) continue;
        const short = DOT_GAP - (story.offsetTop - last);
        if (short > 0) story.style.marginTop = `${parseFloat(getComputedStyle(story).marginTop) + short}px`;
        last = story.offsetTop;
      }
    }
  }

  for (const tab of $$('#book-tabs button')) {
    tab.addEventListener('click', () => {
      bookTab = tab.dataset.book;
      bookWho = null; // another tab forgets the pick, as in the addon
      for (const other of $$('#book-tabs button')) chooseTab(other, other === tab);
      $('#book').setAttribute('aria-labelledby', tab.id);
      renderBook();
    });
  }
  tablist($('#book-tabs'));

  // -------------------------------------------------------------------------
  // 03 Fellow travellers: who you were in a group with, as in
  // Famulus/UI/Fellows.lua. The people are the addon's samples
  // (/fam fellows demo), with the faces this page already knows.
  // -------------------------------------------------------------------------

  // Bond by time together, in minutes: FellowService.TIERS (0, 1, 10, 40 h).
  const TIERS = [0, 60, 600, 2400];

  // The tier (1 to 4), the way to the next (0 to 1; 1 at the top) and the
  // minutes still to go. As FellowService.Tier.
  function tierOf(minutes) {
    let tier = 1;
    while (tier < TIERS.length && minutes >= TIERS[tier]) tier++;
    if (tier === TIERS.length) return { tier, progress: 1, left: 0 };
    const from = TIERS[tier - 1];
    const to = TIERS[tier];
    return { tier, progress: (minutes - from) / (to - from), left: to - minutes };
  }

  // Per person: how often, how many bosses, minutes in all, and when you met
  // (`ago` in days, your level then). The day log, newest first: zone, the
  // first moment, minutes together, bosses by name with their time, and
  // bosses without a name (`more`, as in a raid). What the log does not
  // cover came before it, as in the addon, which keeps 30 days.
  const UL = (...times) => ['Revelosh', 'Ironaya', 'Archaedas'].map((name, index) => [name, times[index]]);
  const FELLOWS = [
    {
      who: MIRA, now: true, times: 14, bosses: 9, minutes: 1880,
      met: { ago: 9, zone: 'Westfall', level: 34, at: '18:12' },
      days: [
        { ago: 0, zone: 'Tanaris', from: '19:05', minutes: 160 },
        { ago: 2, zone: 'Feralas', from: '18:30', minutes: 205, more: 2 },
        { ago: 4, zone: 'Uldaman', from: '19:10', minutes: 185, kills: UL('19:40', '20:25', '21:50') },
        { ago: 7, zone: 'Desolace', from: '17:45', minutes: 235 },
      ],
    },
    {
      who: BORIN, times: 6, bosses: 7, minutes: 665,
      met: { ago: 6, zone: 'Desolace', level: 36, at: '20:00' },
      days: [
        { ago: 1, zone: 'Uldaman', from: '18:50', minutes: 145, kills: UL('19:20', '19:55', '20:30') },
        { ago: 3, zone: 'Feralas', from: '19:30', minutes: 130, more: 1 },
        { ago: 6, zone: 'Desolace', from: '20:00', minutes: 150 },
      ],
    },
    {
      who: ENA, times: 3, bosses: 5, minutes: 295,
      met: { ago: 12, zone: 'Westfall', level: 33, at: '17:30' },
      days: [
        { ago: 8, zone: 'Desolace', from: '18:00', minutes: 125, more: 2 },
        { ago: 10, zone: 'Uldaman', from: '19:15', minutes: 95, kills: UL('19:45', '20:20', '20:45') },
        { ago: 12, zone: 'Westfall', from: '17:30', minutes: 75 },
      ],
    },
    {
      who: LYSA, times: 1, bosses: 3, minutes: 160,
      met: { ago: 1, zone: 'Uldaman', level: 38, at: '18:50' },
      days: [{ ago: 1, zone: 'Uldaman', from: '18:50', minutes: 160, kills: UL('19:20', '19:55', '20:30') }],
    },
    {
      who: KAELRIC, times: 2, bosses: 0, minutes: 75,
      met: { ago: 4, zone: 'Desolace', level: 37, at: '20:20' },
      days: [
        { ago: 3, zone: 'Desolace', from: '21:00', minutes: 40 },
        { ago: 4, zone: 'Desolace', from: '20:20', minutes: 35 },
      ],
    },
    {
      who: YORICK, times: 1, bosses: 1, minutes: 25,
      met: { ago: 2, zone: 'Feralas', level: 38, at: '22:05' },
      days: [{ ago: 2, zone: 'Feralas', from: '22:05', minutes: 25, more: 1 }],
    },
  ];

  let fellowSort = 'last'; // the list's order: 'last' or 'time'
  let fellowOpen = null; // whose story is open

  // "2 h 10 min", "25 min".
  const duration = minutes => (minutes < 60 ? t('fw_minutes', minutes) : t('fw_hours', Math.floor(minutes / 60), minutes % 60));
  const capital = text => text.charAt(0).toUpperCase() + text.slice(1);
  const clock = minutes => `${String(Math.floor(minutes / 60) % 24).padStart(2, '0')}:${String(minutes % 60).padStart(2, '0')}`;
  const minutesOf = time => Number(time.slice(0, 2)) * 60 + Number(time.slice(3));
  // A day some days back, the way the reader's language writes a date.
  const dateOf = ago => new Date(Date.now() - ago * 86400000)
    .toLocaleDateString(lang === 'de' ? 'de-DE' : 'en-GB', { day: 'numeric', month: 'short' });
  const when = ago => (ago === 0 ? t('fw_today') : ago === 1 ? t('fw_yesterday') : t('fw_on', dateOf(ago)));
  const dayTitle = ago => (ago === 0 ? t('c_today') : ago === 1 ? t('c_yesterday') : dateOf(ago));
  const tierName = tier => t(`fw_bond_${tier}`);
  const bossesText = count => (count === 1 ? t('fw_boss') : t('fw_bosses', count));

  // What the overview, the list and the card show of a person.
  function fellowOf(fellow) {
    const alias = aliasOf(fellow.who);
    const person = PEOPLE[fellow.who];
    const bond = tierOf(fellow.minutes);
    const last = fellow.days[0];
    const stats = [duration(fellow.minutes), t('fw_times_short', fellow.times)];
    if (fellow.bosses) stats.push(bossesText(fellow.bosses));
    return {
      ...fellow,
      ...bond,
      name: alias || fellow.who,
      realName: alias ? fellow.who : null,
      colour: person.colour,
      levelClass: t('tip_level', person.level, t(`cls_${person.cls}`)),
      lastAgo: last.ago,
      lastText: capital(fellow.now ? t('fw_now') : t('fw_last', when(last.ago), last.zone)),
      lastShort: fellow.now ? t('fw_now_short') : capital(last.ago < 2 ? when(last.ago) : dateOf(last.ago)),
      statsText: stats.join('  ·  '),
      nextText: bond.tier < TIERS.length ? t('fw_bond_next', duration(Math.ceil(bond.left)), tierName(bond.tier + 1)) : '',
      firstText: capital(t('fw_first', when(fellow.met.ago), fellow.met.zone)),
    };
  }

  // The crest with the bond's ring: how far it is to the next tier.
  function crest(shown, size) {
    const ring = make('span', `crest crest--${size}`);
    ring.style.setProperty('--p', shown.progress.toFixed(3));
    const letter = make('b', '', initial(shown.name));
    letter.style.color = shown.colour;
    ring.append(letter);
    ring.setAttribute('aria-hidden', 'true');
    return ring;
  }

  // The tier's badge: in the accent from Trusted on.
  const badge = tier => make('span', `badge${tier >= 3 ? ' is-high' : ''}`, tierName(tier));

  function tile(shown, rank) {
    const button = make('button', `ftile${shown.now ? ' is-now' : ''}`);
    button.type = 'button';
    button.dataset.who = shown.who;
    button.append(
      make('span', 'ftile__rank', ['I', 'II', 'III'][rank]),
      crest(shown, 'big'),
      make('strong', 'ftile__name', shown.name),
      make('span', 'ftile__sub', shown.levelClass),
      badge(shown.tier),
      make('span', 'ftile__stats', shown.statsText),
      make('span', 'ftile__foot', shown.lastText),
    );
    button.addEventListener('click', () => openStory(shown.who));
    return button;
  }

  function row(shown) {
    const button = make('button', `frow${shown.now ? ' is-now' : ''}`);
    button.type = 'button';
    button.dataset.who = shown.who;
    const name = make('span', 'frow__name');
    name.append(make('strong', '', shown.name), make('span', '', [shown.realName, shown.levelClass].filter(Boolean).join('  ·  ')));
    button.append(crest(shown, 'small'), name, badge(shown.tier), make('span', 'frow__time', duration(shown.minutes)), make('span', 'frow__last', shown.lastShort));
    button.addEventListener('click', () => openStory(shown.who));
    return button;
  }

  function overview(host) {
    const people = FELLOWS.map(fellowOf).sort((a, b) => b.minutes - a.minutes);
    const top = people.slice(0, 3);
    const rest = people.slice(3).sort(fellowSort === 'time'
      ? (a, b) => b.minutes - a.minutes
      : (a, b) => (a.now ? -1 : b.now ? 1 : a.lastAgo - b.lastAgo));

    const tiles = make('div', 'ftiles');
    top.forEach((shown, rank) => tiles.append(tile(shown, rank)));

    const bar = make('div', 'fellows__bar');
    const sort = make('select', 'fsort');
    sort.setAttribute('aria-label', t('fw_sort'));
    for (const value of ['last', 'time']) {
      const option = make('option', '', t(`fw_sort_${value}`));
      option.value = value;
      option.selected = value === fellowSort;
      sort.append(option);
    }
    sort.addEventListener('change', () => {
      fellowSort = sort.value;
      renderFellows();
      $('#fellows-demo .fsort').focus({ preventScroll: true });
    });
    bar.append(make('h3', 'fellows__title', t('fw_others', rest.length)), sort);

    const list = make('div', 'flist');
    const heads = make('div', 'flist__heads');
    heads.setAttribute('aria-hidden', 'true');
    for (const key of ['name', 'bond', 'time', 'last']) heads.append(make('span', `flist__${key}`, t(`fw_col_${key}`)));
    list.append(heads, ...rest.map(row));

    host.append(make('h3', 'fellows__title', t('fw_closest')), tiles, bar, list);
  }

  // The bond's four steps, the current one glowing.
  function ladder(tier) {
    const steps = make('ol', 'ladder');
    for (let step = 1; step <= TIERS.length; step++) {
      steps.append(make('li', step < tier ? 'is-done' : step === tier ? 'is-here' : '', tierName(step)));
    }
    return steps;
  }

  function profile(shown) {
    const card = make('aside', 'fprofile');
    card.append(
      crest(shown, 'huge'),
      make('h3', 'fprofile__name', shown.name),
      make('p', 'fprofile__sub', [shown.realName, shown.levelClass].filter(Boolean).join('  ·  ')),
      make('p', `fprofile__status${shown.now ? ' is-now' : ''}`, shown.lastText),
      ladder(shown.tier),
    );
    if (shown.nextText) card.append(make('p', 'fprofile__next', shown.nextText));
    const cells = make('div', 'fprofile__cells');
    for (const [value, label] of [[duration(shown.minutes), t('fw_col_time')], [String(shown.times), t('fw_stat_times')], [String(shown.bosses), t('fw_stat_bosses')]]) {
      const cell = make('div');
      cell.append(make('b', '', value), make('span', '', label));
      cells.append(cell);
    }
    // When you last met stands above already, under the name.
    card.append(cells, make('p', 'fprofile__first', shown.firstText));

    // As in the addon: set an alias, and their own events in the chronicle.
    const buttons = make('div', 'fprofile__buttons');
    const alias = make('button', 'btn btn--small btn--ghost', t('fw_alias'));
    alias.type = 'button';
    alias.addEventListener('click', () => editAlias(shown.who));
    buttons.append(alias);
    if (COMPANIONS[shown.who]) {
      const chronicle = make('button', 'btn btn--small btn--ghost', t('fw_chronicle'));
      chronicle.type = 'button';
      chronicle.addEventListener('click', () => showChronicleOf(shown.who));
      buttons.append(chronicle);
    }
    card.append(buttons);
    return card;
  }

  // One chapter per day together, the newest first, as FellowStory in
  // Famulus/UI/Options.lua: the time together, the bosses that fell, the day
  // the bond reached a new tier, and the day you met.
  function storyChapters(fellow) {
    // The days a new tier was reached (FellowService.Milestones): the walk
    // starts from the time before the log.
    const reached = {};
    let running = Math.max(0, fellow.minutes - fellow.days.reduce((sum, day) => sum + day.minutes, 0));
    let tier = tierOf(running).tier;
    for (const day of [...fellow.days].reverse()) {
      running += day.minutes;
      const now = tierOf(running).tier;
      if (now > tier) reached[day.ago] = tier = now;
    }

    const met = { kind: 'bond', big: true, title: t('fw_met'), detail: t('c_at_level', fellow.met.level), time: fellow.met.at, order: -1 };
    let metShown = false;
    const chapters = fellow.days.map(day => {
      const start = minutesOf(day.from);
      const end = clock(start + day.minutes);
      const span = t('fw_span', day.from, end, duration(day.minutes));
      const events = [{ kind: 'fellow', title: t('fw_together'), detail: day.more ? `${span}  ·  ${bossesText(day.more)}` : span, sort: day.from }];
      for (const [name, time] of day.kills || []) {
        events.push({ kind: 'boss', title: t('c_boss', name), detail: t('c_in', day.zone), time, sort: time });
      }
      if (reached[day.ago]) {
        events.push({ kind: 'bond', big: true, title: t('fw_tier_up', tierName(reached[day.ago]).toLowerCase()), sort: end });
      }
      if (day.ago === fellow.met.ago) {
        events.push({ ...met, sort: fellow.met.at });
        metShown = true;
      }
      // Newest first; the meeting is the oldest of its day.
      events.sort((a, b) => (b.sort > a.sort ? 1 : b.sort < a.sort ? -1 : (b.order || 0) - (a.order || 0)));
      return { day: dayTitle(day.ago), title: day.zone, sub: t('fw_day_time', duration(day.minutes)), events };
    });
    // Met before the day log: a chapter of its own.
    if (!metShown) chapters.push({ day: dayTitle(fellow.met.ago), title: fellow.met.zone, sub: '', events: [met] });
    return chapters;
  }

  function storyCard(event) {
    const look = PICTURES[event.kind];
    const story = make('article', `story story--${look.tone}${event.big ? ' is-big' : ''}`);
    const dot = make('span', 'story__dot');
    dot.append(icon(look.mark || look.icon, 12));
    const text = make('div', 'story__text');
    text.append(make('h4', '', event.title));
    const line = [event.detail, event.time].filter(Boolean).join('  ·  ');
    if (line) text.append(make('p', '', line));
    const body = make('div', 'story__body');
    body.append(picture(event), text);
    const card = make('div', 'story__card');
    card.append(body);
    story.append(dot, card);
    return story;
  }

  function story(host, who) {
    const fellow = FELLOWS.find(each => each.who === who);
    const shown = fellowOf(fellow);
    const back = make('button', 'fellows__back');
    back.type = 'button';
    back.append(icon('chevron', 14), make('span', '', t('fw_back')));
    back.addEventListener('click', () => {
      fellowOpen = null;
      renderFellows();
      const again = $$('#fellows-demo [data-who]').find(button => button.dataset.who === who);
      if (again) again.focus({ preventScroll: true });
    });

    const book = make('div', 'book fstory__book');
    book.setAttribute('aria-label', t('fw_story_with', shown.name));
    for (const chapter of storyChapters(fellow)) {
      const head = make('header', 'chapter__head');
      const before = make('div', 'chapter__side');
      before.append(make('i'), make('p', 'chapter__day', chapter.day));
      const after = make('div', 'chapter__side');
      after.append(make('p', 'chapter__sub', chapter.sub), make('i'));
      head.append(before, make('h3', '', chapter.title), after);
      const trail = make('div', 'chapter__events');
      trail.append(...chapter.events.map(storyCard));
      const section = make('section', 'chapter');
      section.append(head, trail);
      book.append(section);
    }
    const grid = make('div', 'fstory');
    grid.append(profile(shown), book);
    host.append(back, grid);
    return back;
  }

  function renderFellows() {
    const host = $('#fellows-demo');
    host.textContent = '';
    host.classList.toggle('is-story', fellowOpen != null);
    if (fellowOpen) story(host, fellowOpen);
    else overview(host);
    spaceDots();
  }

  function openStory(who) {
    fellowOpen = who;
    renderFellows();
    $('#fellows-demo .fellows__back').focus({ preventScroll: true });
    // The story starts where the overview did, also on a phone.
    const top = $('#fellows-demo').getBoundingClientRect().top;
    if (top < 0) scrollBy({ top: top - 90, behavior: motion.matches ? 'auto' : 'smooth' });
  }

  // "Set alias": the window further down, with the name filled in (ns:EditAlias).
  function editAlias(who) {
    state.tab = 'names';
    state.editing = aliases.find(entry => entry.name && keyOf(entry.name) === keyOf(who)) || null;
    nameField.value = who;
    aliasField.value = aliasOf(who) || '';
    renderWindow();
    renderAliases();
    demo.scrollIntoView({ behavior: motion.matches ? 'auto' : 'smooth', block: 'center' });
    aliasField.focus({ preventScroll: true });
    aliasField.select();
  }

  // "In the chronicle": their own events, on the chronicle's Companions tab.
  function showChronicleOf(who) {
    bookTab = 'theirs';
    bookWho = who;
    focusWho = who;
    for (const tab of $$('#book-tabs button')) chooseTab(tab, tab.dataset.book === 'theirs');
    $('#book').setAttribute('aria-labelledby', 'book-tab-theirs');
    renderBook();
    $('.journal').scrollIntoView({ behavior: motion.matches ? 'auto' : 'smooth', block: 'start' });
  }

  // -------------------------------------------------------------------------
  // 04 Live feed: cards that appear for a few seconds. At most three, the
  // newest on top, as in Famulus/UI/Feed.lua.
  // -------------------------------------------------------------------------

  const MAX_CARDS = 3;

  // Things that happen now, so they fit what the book and the rail say:
  // Mira was 40 already yesterday, Borin is 31.
  const FEED = {
    level: { kind: 'level', number: 39, who: KAELRIC, zone: 'Desolace' },
    boss: { kind: 'boss', who: BORIN, zone: 'Uldaman' },
    death: { kind: 'death', who: BORIN, zone: 'Feralas', level: 31 },
    ability: { kind: 'ability', level: 40, big: true },
    skill: { kind: 'skill', number: 150, who: MIRA, zone: 'Tanaris' },
    item: { kind: 'item', who: KAELRIC, zone: 'Desolace' },
  };

  function leave(card) {
    if (card.classList.contains('is-leaving')) return;
    clearTimeout(card.timer);
    card.classList.add('is-leaving');
    card.classList.remove('is-in');
    setTimeout(() => card.remove(), 520);
  }

  function showCard(host, event, seconds) {
    const told = tell(event, true);
    const card = make('div', `toast toast--${PICTURES[event.kind].tone}${event.big ? ' is-big' : ''}`);
    const text = make('div', 'toast__text');
    text.append(make('strong', '', told.title));
    if (told.detail) text.append(make('span', '', told.detail));
    card.append(picture(event), text);
    host.prepend(card);

    const cards = $$('.toast:not(.is-leaving)', host);
    cards.forEach((other, slot) => other.style.setProperty('--slot', slot));
    cards.slice(MAX_CARDS).forEach(leave);
    requestAnimationFrame(() => requestAnimationFrame(() => card.classList.add('is-in')));
    if (Number.isFinite(seconds)) card.timer = setTimeout(() => leave(card), seconds * 1000);
  }

  // Shows the events in turn while `anchor` is on screen; nothing runs while
  // it is not (also not while it is hidden by the layout), or while the tab
  // is in the background. Whoever asks for less motion gets a still picture
  // instead: two cards that stay. Returns a function that starts over, for
  // when the language changes.
  function play(host, anchor, order, every, seconds) {
    let index = 0;
    let timer = 0;
    let first = 0;
    let onScreen = false;
    const next = () => showCard(host, FEED[order[index++ % order.length]], seconds);
    const still = () => {
      host.textContent = '';
      showCard(host, FEED[order[1]], Infinity);
      showCard(host, FEED[order[0]], Infinity);
    };
    const sync = () => {
      const run = onScreen && !document.hidden && !motion.matches;
      if (run && !timer) {
        if (!host.childElementCount) first = setTimeout(next, 900);
        timer = setInterval(next, every);
      } else if (!run && timer) {
        clearTimeout(first);
        clearInterval(timer);
        timer = 0;
      }
    };
    const start = () => {
      if (motion.matches) still();
      else host.textContent = ''; // the next card comes in the new language
      sync();
    };
    new IntersectionObserver(entries => {
      onScreen = entries[entries.length - 1].isIntersecting;
      sync();
    }, { threshold: 0.3 }).observe(anchor);
    document.addEventListener('visibilitychange', sync);
    motion.addEventListener('change', start);
    if (motion.matches) still();
    return start;
  }

  // What a chip set off, for screen readers: the cards themselves are a
  // picture of the game and stay out of their way.
  const feedCards = $('#feed-toasts');
  const feedSaid = $('#feed-said');
  for (const chip of $$('[data-feed]')) {
    chip.addEventListener('click', () => {
      const event = FEED[chip.dataset.feed];
      showCard(feedCards, event, 7);
      const told = tell(event, true);
      feedSaid.textContent = [told.title, told.detail].filter(Boolean).join(', ');
    });
  }

  // "Move the spot": like /fam feed, a marked field that can be dragged.
  const feedView = $('#feed-view');
  const spot = $('#feed-spot');
  const mover = $('#feed-mover');
  const moveButton = $('#feed-move');

  moveButton.addEventListener('click', () => {
    const on = moveButton.getAttribute('aria-pressed') !== 'true';
    moveButton.setAttribute('aria-pressed', String(on));
    mover.hidden = !on;
    if (on) mover.focus({ preventScroll: true });
  });

  // Puts the spot at `left`, `top` inside the view, leaving room below the
  // field for the card that hangs under it.
  function placeSpot(left, top) {
    const room = mover.hidden ? 0 : mover.offsetHeight;
    spot.style.left = `${clamp(left, 0, Math.max(0, feedView.clientWidth - spot.offsetWidth))}px`;
    spot.style.top = `${clamp(top, 0, Math.max(0, feedView.clientHeight - room - 84))}px`;
    spot.style.transform = 'none';
  }
  const moved = () => spot.style.transform === 'none';

  mover.addEventListener('pointerdown', down => {
    if (down.button !== 0) return; // only the main button drags
    const view = feedView.getBoundingClientRect();
    const box = spot.getBoundingClientRect();
    const grip = { x: down.clientX - box.left, y: down.clientY - box.top };
    mover.setPointerCapture(down.pointerId);
    const move = event => placeSpot(event.clientX - view.left - grip.x, event.clientY - view.top - grip.y);
    const up = () => {
      mover.removeEventListener('pointermove', move);
      mover.removeEventListener('pointerup', up);
      mover.removeEventListener('pointercancel', up);
    };
    mover.addEventListener('pointermove', move);
    mover.addEventListener('pointerup', up);
    mover.addEventListener('pointercancel', up);
  });

  // The arrow keys move it too; with Shift in bigger steps.
  const STEPS = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] };
  mover.addEventListener('keydown', event => {
    const step = STEPS[event.key];
    if (!step) return;
    event.preventDefault();
    const size = event.shiftKey ? 40 : 10;
    // Where it stands now, also while it is still centred by a transform.
    const view = feedView.getBoundingClientRect();
    const box = spot.getBoundingClientRect();
    const left = box.left - view.left - feedView.clientLeft;
    const top = box.top - view.top - feedView.clientTop;
    placeSpot(left + step[0] * size, top + step[1] * size);
  });

  // A narrower view keeps a moved spot inside.
  const keepSpot = () => {
    if (moved()) placeSpot(spot.offsetLeft, spot.offsetTop);
  };

  // -------------------------------------------------------------------------
  // The landscapes. Ridges from far to near; see scene.js for the fields.
  // -------------------------------------------------------------------------

  // The hero: friends at a fire on a hill, dark against the large moon, an
  // old tree with an owl beside them, forest all round. See scene.js for
  // the figures.
  const MOON = {
    x: 1150, y: 540, r: 165, depth: 0.1,
    small: { x: 1440, y: 150, r: 17 },
    bats: [[1035, 420, 0.9], [1072, 398, 0.7], [1010, 392, 0.6]],
  };

  const CAMP = {
    fire: 1150,
    size: 1,
    // A group of four with the hunter's wolf; the tent, the tree and the
    // horse stand farther back.
    cast: [
      { figure: 'oak', at: 18.5, back: true, facing: 1, rim: false },
      { figure: 'horse', at: 25, back: true, facing: 1, rim: false, scale: 1.15 },
      { figure: 'tent', at: -22, back: true },
      { figure: 'mage', at: -15.5 },
      { figure: 'wolf', at: -11.2, scale: 0.9 },
      { figure: 'warrior', at: -6.4 },
      { figure: 'rogue', at: 11.5 },
      { figure: 'hunter', at: 6 },
    ],
  };

  const HERO = [
    { seed: 11, base: 650, amp: 330, scale: 520, sharp: true, tone: 1, depth: 0.16, haze: 50, valley: { at: 0.72, width: 0.2, depth: 1 } },
    { seed: 23, base: 725, amp: 290, scale: 400, sharp: true, tone: 2, depth: 0.3, haze: 50, valley: { at: 0.72, width: 0.2, depth: 1 } },
    { seed: 37, base: 750, amp: 110, scale: 520, octaves: 3, tone: 3, depth: 0.48, valley: { at: 0.72, width: 0.12, depth: 0.9 }, trees: { gap: [9, 24], height: [12, 34], clump: 140, broad: 0.45, clear: [930, 1420] } },
    { seed: 43, base: 770, amp: 70, scale: 420, octaves: 3, tone: 4, depth: 0.7, plateau: { from: 890, to: 1475, y: 640, edge: 170 }, grass: { gap: [5, 14], height: [4, 11] }, bushes: [[905, 20], [1530, 22]], cast: [{ figure: 'deer', x: 1482, scale: 0.55, facing: -1 }], camp: CAMP, flies: { from: 860, to: 1540, count: 14, seed: 3 } },
    { seed: 59, base: 886, amp: 40, scale: 380, octaves: 2, tone: 5, depth: 1, grass: { gap: [6, 18], height: [6, 20] }, trees: { gap: [22, 60], height: [30, 330], frame: [0.35, 1], broad: 0.35, bushes: 0.15, clear: [900, 1400] }, flies: { from: 1250, to: 1600, count: 6, seed: 9, height: 120 } },
  ];

  const glimpse = seed => [
    { seed: seed + 1, base: 580, amp: 300, scale: 460, sharp: true, tone: 1, haze: 50 },
    { seed: seed + 2, base: 680, amp: 250, scale: 380, sharp: true, tone: 2, haze: 50 },
    { seed: seed + 3, base: 760, amp: 130, scale: 420, octaves: 3, tone: 3, trees: { gap: [10, 24], height: [14, 34], clump: 150 } },
    { seed: seed + 4, base: 850, amp: 110, scale: 400, octaves: 3, tone: 4, trees: { gap: [10, 24], height: [26, 60] } },
  ];

  const FOOT = [
    { seed: 71, base: 640, amp: 330, scale: 480, sharp: true, tone: 2, haze: 60 },
    { seed: 73, base: 760, amp: 170, scale: 460, octaves: 3, tone: 3, trees: { gap: [10, 24], height: [14, 36], clump: 150 } },
    { seed: 83, base: 800, amp: 120, scale: 420, octaves: 3, tone: 4, trees: { gap: [9, 22], height: [24, 60] } },
    { seed: 79, base: 862, amp: 70, scale: 380, octaves: 2, tone: 5, fire: 800, trees: { gap: [22, 60], height: [30, 300], frame: [0.3, 1] } },
  ];

  const hero = $('#top');
  const heroScene = $('#scene');
  Scene.moon(heroScene, MOON);
  const heroLayers = Scene.build(heroScene, HERO);
  const heroCamp = heroLayers.find(layer => layer.camp);
  Scene.stars($('.scene__stars', heroScene), 170, 5);
  Scene.build($('#scene-alias'), glimpse(100));
  Scene.build($('#scene-feed'), glimpse(200));
  const footScene = $('#scene-foot');
  const footLayers = Scene.build(footScene, FOOT);

  // In one column the camp stands below the text, and the drawing pans so
  // that it is in view, from the tent to the horse (the CSS makes it smaller).
  const heroInColumn = matchMedia('(max-width: 980px)');
  const CAMP_MIDDLE = 1200;

  // Sparks rise from the fires; where they are depends on how the drawing
  // is cut to the window, so it is found again after a resize. (Whoever
  // asks for less motion does not see them; the CSS hides them.)
  function kindle() {
    if (heroInColumn.matches) Scene.pan(heroScene, CAMP_MIDDLE);
    else for (const name of ['--pan-left', '--pan-width']) heroScene.style.removeProperty(name);
    const few = innerWidth < 760;
    const fires = [[heroScene, heroCamp, heroCamp.camp.x, few ? 16 : 34], [footScene, footLayers[footLayers.length - 1], 800, few ? 10 : 20]];
    for (const [scene, ground, x, count] of fires) {
      const host = $('.scene__embers', scene);
      Scene.embers(host, count, Scene.place(ground.svg, x, Scene.heightAt(ground.points, x), host));
    }
  }
  // Only a new width calls for new sparks. On phones the address bar comes
  // and goes while scrolling and changes only the height.
  let resizing = 0;
  let kindledAt = innerWidth;
  addEventListener('resize', () => {
    clearTimeout(resizing);
    resizing = setTimeout(() => {
      if (innerWidth !== kindledAt) {
        kindledAt = innerWidth;
        kindle();
      }
      spaceDots();
      keepSpot();
    }, 200);
  });

  // The sparks of the foot rest while it is out of sight, as the hero's do
  // (scene.js).
  new IntersectionObserver(entries => {
    footScene.classList.toggle('is-away', !entries[entries.length - 1].isIntersecting);
  }).observe(footScene);

  // -------------------------------------------------------------------------
  // Start.
  // -------------------------------------------------------------------------

  renderers.push(() => refresh(false));

  // ?lang=de forces a language; anything unknown there is passed over.
  const known = code => (code && I18N[code.toLowerCase()] ? code.toLowerCase() : null);
  const asked = known(new URLSearchParams(location.search).get('lang'));
  const fromBrowser = (navigator.language || '').toLowerCase().startsWith('de') ? 'de' : 'en';
  setLanguage(asked || known(store.get('famulus-lang')) || fromBrowser, false);

  kindle();
  Scene.parallax(hero);
  watch(document);
  onScroll();
  // The book's cards change height once Inter has loaded; the dots follow.
  if (document.fonts) document.fonts.ready.then(spaceDots);

  renderers.push(
    play($('#hero-toasts'), $('.hero__feed'), ['level', 'boss', 'ability', 'item', 'death', 'skill'], 4400, 9.5),
    play(feedCards, feedView, ['boss', 'level', 'item', 'ability', 'skill', 'death'], 5200, 8),
  );
})();
