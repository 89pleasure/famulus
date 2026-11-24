// What moves and answers on the page: language, colour scheme, navigation,
// and the three demos (aliases, chronicle, live feed). The demos rebuild
// what the addon shows, with made-up people; nothing is sent anywhere.
(() => {
  'use strict';

  const root = document.documentElement;
  const I18N = window.FAMULUS_I18N;
  const Scene = window.FamulusScene;
  const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;
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
  // Colour schemes: the same five as in the addon. The page follows.
  // -------------------------------------------------------------------------

  const SCHEMES = ['lemon', 'mint', 'rose', 'lilac', 'amber'];

  function setScheme(name, remember) {
    if (!SCHEMES.includes(name)) name = SCHEMES[0];
    if (name === SCHEMES[0]) delete root.dataset.scheme;
    else root.dataset.scheme = name;
    for (const button of $$('#schemes button')) button.setAttribute('aria-pressed', String(button.dataset.scheme === name));
    if (remember) store.set('famulus-scheme', name);
  }

  for (const button of $$('#schemes button')) {
    button.addEventListener('click', () => setScheme(button.dataset.scheme, true));
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
  const drifting = reduced ? [] : $$('[data-parallax]').map(element => ({
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

  const PEOPLE = {
    [MIRA]: { level: 40, cls: 'mage', colour: '#3fc7eb' },
    [BORIN]: { level: 31, cls: 'warrior', colour: '#c69b6d' },
    [KAELRIC]: { level: 38, cls: 'paladin', colour: '#f48cba' },
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
      if (mark && lastShown[index] != null && lastShown[index] !== shown) name.classList.add('is-changed');
      lastShown[index] = shown;
      const point = () => {
        state.tip = line.who;
        renderTip();
      };
      name.addEventListener('pointerenter', point);
      name.addEventListener('focus', point);
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
        aliases.splice(aliases.indexOf(entry), 1);
        if (state.editing === entry) {
          state.editing = null;
          form.reset();
        }
        refresh(true);
      });
      item.append(open, remove);
      list.append(item);
    }
  }

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
    for (const tab of $$('[data-tab]', demo)) tab.setAttribute('aria-selected', String(tab.dataset.tab === state.tab));
    for (const pane of $$('[data-pane]', demo)) pane.hidden = pane.dataset.pane !== state.tab;
    $('#alias-tabdesc').textContent = t(`w_tabdesc_${state.tab}`);

    // The counters in the sidebar: three features to switch here, two more
    // that the demo leaves on, and the live feed of the chronicle.
    const running = state.master ? ['chat', 'tooltip', 'menu'].filter(key => state[key]).length + 2 : 0;
    $('#alias-count').textContent = state.master ? `${running}/5` : t('off');
    $('#active-count').textContent = t('w_active', running + 1, 9);
  }

  function refresh(mark) {
    renderAliases();
    renderWindow();
    renderChat(mark);
    renderTip();
    renderBook(); // companions appear under their alias there too
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
      renderWindow();
    });
  }
  $('#alias-style').addEventListener('change', event => {
    state.style = event.target.value;
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
  };

  const CHAPTERS = [
    {
      day: 'c_today', title: 'Tanaris', levels: [39, 40],
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
      day: 'c_yesterday', title: 'Uldaman', levels: [39, 39],
      events: [
        { time: '23:15', kind: 'ability', who: MIRA, level: 40 },
        { time: '22:20', kind: 'skill', number: 75, zone: 'Uldaman' },
        { time: '21:40', kind: 'death', who: BORIN, zone: 'Feralas', level: 31 },
        { time: '21:05', kind: 'level', number: 39, zone: 'Uldaman', big: true },
        { time: '20:30', kind: 'boss', zone: 'Uldaman' },
        { time: '19:10', kind: 'achievement', zone: 'Desolace' },
      ],
    },
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
        if (who) return { title: t('c_their_item', who, t('n_bag')), detail: place };
        return { title: t(event.who ? 'c_item_theirs' : 'c_item', t('n_bag')), detail: place };
      case 'skill':
        return {
          title: who ? t('c_their_skill', who, t('n_tailoring'), event.number) : t('c_skill', t('n_tailoring'), event.number),
          detail: place,
        };
      default:
        return { title: t('c_achievement', t('n_challenge')), detail: place };
    }
  }

  function picture(event) {
    const look = PICTURES[event.kind];
    const frame = make('span', `pic pic--${look.tone}`);
    frame.append(look.icon ? icon(look.icon, 28) : make('b', '', event.number));
    return frame;
  }

  let bookTab = 'all';

  function renderBook() {
    const book = $('#book');
    book.textContent = '';
    for (const chapter of CHAPTERS) {
      const events = chapter.events.filter(event => bookTab === 'all' || (bookTab === 'mine') === !event.who);
      if (!events.length) continue;

      const head = make('header', 'chapter__head reveal');
      const mark = make('div', 'chapter__mark');
      mark.append(make('i'), icon('sparkle', 11), make('i'));
      const [from, to] = chapter.levels;
      const levels = from === to ? t('c_ch_level', from) : t('c_ch_levels', from, to);
      const count = events.length === 1 ? t('c_ch_event') : t('c_ch_events', events.length);
      head.append(
        make('p', 'chapter__day', t(chapter.day)),
        make('h3', '', chapter.title),
        mark,
        make('p', 'chapter__sub', `${levels}  ·  ${count}`),
      );

      const trail = make('div', 'chapter__events');
      for (const event of events) {
        const look = PICTURES[event.kind];
        const told = tell(event, false);
        const story = make('article', `story story--${look.tone} reveal${event.big ? ' is-big' : ''}`);
        const dot = make('span', 'story__dot');
        dot.append(icon(look.mark || look.icon, 12));
        const text = make('div', 'story__text');
        text.append(make('h4', '', told.title), make('p', '', [told.detail, event.time].filter(Boolean).join('  ·  ')));
        const body = make('div', 'story__body');
        body.append(picture(event), text);
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
    spaceDots();
    watch(book);
  }

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
      for (const other of $$('#book-tabs button')) other.setAttribute('aria-selected', String(other === tab));
      renderBook();
    });
  }

  // -------------------------------------------------------------------------
  // 03 Live feed: cards that appear for a few seconds. At most three, the
  // newest on top, as in Famulus/UI/Feed.lua.
  // -------------------------------------------------------------------------

  const MAX_CARDS = 3;

  const FEED = {
    level: { kind: 'level', number: 40, who: MIRA, zone: 'Tanaris' },
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
  // it is not, or while the tab is in the background. Returns a function
  // that starts over, for when the language changes.
  function play(host, anchor, order, every, seconds) {
    if (reduced) {
      // A still picture instead: two cards that stay.
      const still = () => {
        host.textContent = '';
        showCard(host, FEED[order[1]], Infinity);
        showCard(host, FEED[order[0]], Infinity);
      };
      still();
      return still;
    }
    let index = 0;
    let timer = 0;
    let onScreen = false;
    const next = () => showCard(host, FEED[order[index++ % order.length]], seconds);
    const sync = () => {
      const run = onScreen && !document.hidden;
      if (run && !timer) {
        if (!host.childElementCount) setTimeout(next, 900);
        timer = setInterval(next, every);
      } else if (!run && timer) {
        clearInterval(timer);
        timer = 0;
      }
    };
    new IntersectionObserver(entries => {
      onScreen = entries[0].isIntersecting;
      sync();
    }, { threshold: 0.3 }).observe(anchor);
    document.addEventListener('visibilitychange', sync);
    return () => {
      host.textContent = ''; // the next card comes in the new language
    };
  }

  const feedCards = $('#feed-toasts');
  for (const chip of $$('[data-feed]')) {
    chip.addEventListener('click', () => showCard(feedCards, FEED[chip.dataset.feed], 7));
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
  });

  mover.addEventListener('pointerdown', down => {
    const view = feedView.getBoundingClientRect();
    const box = spot.getBoundingClientRect();
    const grip = { x: down.clientX - box.left, y: down.clientY - box.top };
    mover.setPointerCapture(down.pointerId);
    const move = event => {
      const left = clamp(event.clientX - view.left - grip.x, 0, view.width - box.width);
      // Leave room below the field for the card that hangs under it.
      const top = clamp(event.clientY - view.top - grip.y, 0, view.height - mover.offsetHeight - 84);
      spot.style.left = `${left}px`;
      spot.style.top = `${top}px`;
      spot.style.transform = 'none';
    };
    const up = () => {
      mover.removeEventListener('pointermove', move);
      mover.removeEventListener('pointerup', up);
      mover.removeEventListener('pointercancel', up);
    };
    mover.addEventListener('pointermove', move);
    mover.addEventListener('pointerup', up);
    mover.addEventListener('pointercancel', up);
  });

  // -------------------------------------------------------------------------
  // The landscapes. Ridges from far to near; see scene.js for the fields.
  // -------------------------------------------------------------------------

  const FIRE = 900; // where the glow sits on the ground of the hero

  const HERO = [
    { seed: 11, base: 650, amp: 330, scale: 520, sharp: true, tone: 1, depth: 0.16, haze: 50, valley: { at: 0.62, width: 0.2, depth: 0.5 } },
    { seed: 23, base: 725, amp: 290, scale: 400, sharp: true, tone: 2, depth: 0.3, haze: 50, valley: { at: 0.58, width: 0.22, depth: 0.55 } },
    { seed: 37, base: 775, amp: 150, scale: 520, octaves: 3, tone: 3, depth: 0.48, trees: { gap: [10, 26], height: [10, 26], clump: 140 } },
    { seed: 41, base: 835, amp: 120, scale: 440, octaves: 3, tone: 4, depth: 0.7, trees: { gap: [9, 22], height: [22, 54] } },
    { seed: 59, base: 878, amp: 56, scale: 380, octaves: 2, tone: 5, depth: 1, fire: FIRE, trees: { gap: [22, 60], height: [30, 330], frame: [0.3, 1] } },
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
  const heroLayers = Scene.build(heroScene, HERO);
  Scene.stars($('.scene__stars', heroScene), 170, 5);
  Scene.build($('#scene-alias'), glimpse(100));
  Scene.build($('#scene-feed'), glimpse(200));
  const footScene = $('#scene-foot');
  const footLayers = Scene.build(footScene, FOOT);

  // Sparks rise from where the glow is; that place depends on how the
  // drawing is cut to the window, so it is found again after a resize.
  function kindle() {
    if (reduced) return;
    const few = innerWidth < 760;
    for (const [scene, layers, x, count] of [[heroScene, heroLayers, FIRE, few ? 16 : 34], [footScene, footLayers, 800, few ? 10 : 20]]) {
      const ground = layers[layers.length - 1];
      const focus = Scene.place(ground.svg, x, Scene.heightAt(ground.points, x));
      Scene.embers($('.scene__embers', scene), count, focus);
    }
  }
  let resizing = 0;
  addEventListener('resize', () => {
    clearTimeout(resizing);
    resizing = setTimeout(() => {
      kindle();
      spaceDots();
    }, 200);
  });

  // -------------------------------------------------------------------------
  // Start.
  // -------------------------------------------------------------------------

  renderers.push(() => refresh(false));

  const asked = new URLSearchParams(location.search).get('lang');
  const fromBrowser = (navigator.language || '').toLowerCase().startsWith('de') ? 'de' : 'en';
  setLanguage(asked || store.get('famulus-lang') || fromBrowser, false);
  setScheme(store.get('famulus-scheme') || SCHEMES[0], false);

  kindle();
  Scene.parallax(hero);
  watch(document);
  onScroll();

  renderers.push(
    play($('#hero-toasts'), hero, ['level', 'boss', 'ability', 'item', 'death', 'skill'], 4400, 9.5),
    play(feedCards, feedView, ['boss', 'level', 'item', 'ability', 'skill', 'death'], 5200, 8),
  );
})();
