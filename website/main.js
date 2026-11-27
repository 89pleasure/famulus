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

  // Parts joined by "  ·  " into an element: strings, nodes or lists of them.
  function joined(element, parts) {
    parts.filter(Boolean).forEach((part, index) => {
      if (index) element.append('  ·  ');
      element.append(...[].concat(part));
    });
    return element;
  }

  // A class named in a line, in its muted colour (UI.Colored in the addon).
  function classWord(cls) {
    return make('span', `cls cls--${cls}`, t(`cls_${cls}`));
  }

  // "Level 40 Mage" with the class in its colour, as fresh nodes.
  function levelClass(level, cls) {
    const [before, after] = t('tip_level', level, '\u0001').split('\u0001');
    return [before, classWord(cls), after];
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
    remove(key) {
      try { localStorage.removeItem(key); } catch { /* private mode */ }
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
    languages.mark(item => item.dataset.lang === lang);
    $('#langs-current').textContent = lang.toUpperCase();
    const toggle = $('#langs-toggle');
    toggle.setAttribute('aria-label', `${t('nav_lang')}: ${$(`#langs-menu [data-lang="${lang}"]`).lastElementChild.textContent}`);
    toggle.title = toggle.getAttribute('aria-label');
    if (remember) store.set('famulus-lang', lang);
    for (const render of renderers) render();
  }

  // The language beside the scene: a button with its code opens the choice.
  const languages = window.FamulusPick($('#langs'), item => setLanguage(item.dataset.lang, true));

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

  const MIRA = 'Mira Stormfeather';
  const BORIN = 'Borin Ironbeard';
  const KAELRIC = 'Kaelric Dornwald';
  const THESSA = 'Thessa Dornwald';
  const YORICK = 'Yorick Talwind';
  const LYSA = 'Lysa Morningdew';
  const ENA = 'Ena Silverbrook';
  const ME = 'Tamsin Ashgrove'; // the player's own character
  const GARRICK = 'Garrick Stonehand'; // a guild member you never grouped with

  const PEOPLE = {
    [LYSA]: { level: 39, cls: 'priest', colour: '#ffffff' },
    [ENA]: { level: 37, cls: 'druid', colour: '#ff7c0a' },
    [MIRA]: { level: 40, cls: 'mage', colour: '#3fc7eb' },
    [BORIN]: { level: 31, cls: 'warrior', colour: '#c69b6d' },
    [KAELRIC]: { level: 39, cls: 'paladin', colour: '#f48cba' },
    [THESSA]: { level: 12, cls: 'hunter', colour: '#aad372' },
    [YORICK]: { level: 40, cls: 'rogue', colour: '#fff468' },
    [GARRICK]: { level: 22, cls: 'warrior', colour: '#c69b6d' },
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
  // master stays on: since 2026-11-24 the addon has it under Settings › General,
  // which the demo does not show. entry: the feature chosen in Settings.
  const state = { master: true, chat: true, tooltip: true, menu: true, account: true, guildy: true, style: 'alias', tab: 'names', entry: 'chat', editing: null, tip: MIRA };

  // The aliases' features in Settings, as their entries in the addon (Guildy's
  // as if Guildy were loaded).
  const ALIAS_FEATURES = [
    { key: 'chat', icon: 'chat', name: 'f_chat', desc: 'f_chat_d', options: 1 },
    { key: 'tooltip', icon: 'tooltip', name: 'f_tooltip', desc: 'f_tooltip_d' },
    { key: 'menu', icon: 'menu', name: 'f_menu', desc: 'f_menu_d' },
    { key: 'account', icon: 'link', name: 'f_account', desc: 'f_account_d' },
    { key: 'guildy', icon: 'shield', name: 'f_guildy', desc: 'f_guildy_d' },
  ];

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
      if (line.channel === 'whisper') row.append('[', name, `] ${t('chat_whispers', t(line.text))}`);
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
  // features there. The first click asks; a second one within four seconds
  // resets.
  const DEFAULTS = { chat: true, tooltip: true, menu: true, account: true, guildy: true, style: 'alias' };
  const resetButton = $('#alias-reset');
  // Reset stands outside the tablist, left of the settings tab, whose width
  // follows its name in the chosen language.
  const gearTab = $('#alias-tab-display');
  if (gearTab && 'ResizeObserver' in window) {
    new ResizeObserver(() => {
      resetButton.parentElement.style.setProperty('--gear-w', `${gearTab.offsetWidth}px`);
    }).observe(gearTab);
  }
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
    refresh(true);
  });

  function switchButton(key, label) {
    const button = make('button', 'switch');
    button.type = 'button';
    button.setAttribute('role', 'switch');
    button.setAttribute('aria-checked', String(state[key]));
    button.setAttribute('aria-label', label);
    button.dataset.switch = key;
    const track = make('span', 'switch__track');
    track.append(make('span', 'switch__knob'));
    button.append(track);
    return button;
  }

  // Settings: an entry per feature (its icon, name, state and options, and
  // its switch), and the chosen one in full: its area, name and switch,
  // whether it is on and its default, its description and its options.
  function renderSettings() {
    // Drawn anew on every change; the focus stays on what had it.
    const had = document.activeElement;
    const keep = had && demo.contains(had) && (had.dataset.switch || had.dataset.entry || had.id)
      ? { switch: had.dataset.switch, entry: had.dataset.entry, id: had.id, inDetail: !!had.closest('#alias-detail') }
      : null;

    const list = $('#alias-entries');
    list.textContent = '';
    for (const feature of ALIAS_FEATURES) {
      const on = state[feature.key];
      const chosen = state.entry === feature.key;
      const row = make('div', `fentry${chosen ? ' is-chosen' : ''}${on ? ' is-on' : ''}`);
      const pick = make('button', 'fentry__pick');
      pick.type = 'button';
      pick.dataset.entry = feature.key;
      pick.setAttribute('aria-pressed', String(chosen));
      const mark = make('span', 'fentry__icon');
      mark.append(icon(feature.icon, 16));
      const text = make('span', 'fentry__text');
      const said = t(on ? 'on' : 'off');
      text.append(make('strong', '', t(feature.name)), make('span', '', feature.options ? t('w_entry_option', said, feature.options) : said));
      pick.append(mark, text);
      row.append(pick, switchButton(feature.key, t(feature.name)));
      list.append(row);
    }

    const feature = ALIAS_FEATURES.find(each => each.key === state.entry);
    const on = state[feature.key];
    const detail = $('#alias-detail');
    detail.textContent = '';
    const head = make('div', 'fdetail__head');
    head.append(make('h4', '', t(feature.name)), switchButton(feature.key, t(feature.name)));
    const pills = make('div', 'fdetail__pills');
    pills.append(make('span', `pill${on ? ' is-on' : ''}`, t(on ? 'on' : 'off')), make('span', 'pill', t('w_default_on')));
    detail.append(make('p', 'fdetail__area', t('w_aliases')), head, pills, make('p', 'fdetail__desc', t(feature.desc)));
    if (feature.key === 'chat') {
      const option = make('div', `fopt${on ? '' : ' is-off'}`);
      const words = make('label', 'fopt__text');
      words.htmlFor = 'alias-style';
      words.append(make('strong', '', t('o_style')), make('span', '', t('o_style_d')));
      const select = make('select');
      select.id = 'alias-style';
      select.disabled = !on;
      for (const value of ['alias', 'both']) {
        const choice = make('option', '', t(`o_style_${value}`));
        choice.value = value;
        choice.selected = state.style === value;
        select.append(choice);
      }
      option.append(words, select);
      detail.append(make('p', 'fdetail__options', t('w_options')), option);
    }

    if (keep) {
      const scope = keep.inDetail ? detail : list;
      const again = keep.id ? $(`#${keep.id}`, demo)
        : keep.switch ? $(`[data-switch="${keep.switch}"]`, scope)
          : $(`[data-entry="${keep.entry}"]`, list);
      if (again) again.focus({ preventScroll: true });
    }
  }

  function renderWindow() {
    for (const tab of $$('[data-tab]', demo)) chooseTab(tab, tab.dataset.tab === state.tab);
    for (const pane of $$('[data-pane]', demo)) pane.hidden = pane.dataset.pane !== state.tab;
    renderSettings();
    renderReset();
  }

  function refresh(mark) {
    renderAliases();
    renderWindow();
    renderChat(mark);
    renderTip();
    renderBook(); // companions appear under their alias there too
    renderFellows(); // and among the fellow travellers
  }

  // The switches and entries are drawn anew, so the window listens for them.
  demo.addEventListener('click', event => {
    const toggle = event.target.closest('[data-switch]');
    const entry = event.target.closest('[data-entry]');
    if (toggle) {
      state[toggle.dataset.switch] = !state[toggle.dataset.switch];
      refresh(true);
    } else if (entry) {
      state.entry = entry.dataset.entry;
      renderSettings();
    }
  });
  for (const tab of $$('[data-tab]', demo)) {
    tab.addEventListener('click', () => {
      state.tab = tab.dataset.tab;
      stopAsking();
      renderWindow();
    });
  }
  tablist($('.fwin__tabs', demo));
  demo.addEventListener('change', event => {
    if (event.target.id !== 'alias-style') return;
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

  // The section's title names a friend by example: the character's name in
  // its class colour, the alias in the accent behind it. Both fade out, the
  // next name fades in and its alias follows a moment later, so the naming
  // reads as a second step. It only moves while it is on screen; with
  // reduced motion the first example stands. The first two are the lead's
  // tank and the demo's Papa, then one for fun.
  const TITLE_EXAMPLES = [
    { name: 'Grimtusk', cls: 'warrior', alias: 'Tom' },
    { name: KAELRIC.split(' ')[0], cls: PEOPLE[KAELRIC].cls, alias: 'Papa' },
    { name: 'Balduk', cls: 'hunter', alias: 'BigBossDaddy' },
    { name: 'Dârkñêss', cls: 'warlock', alias: 'Ben' },
    { name: MIRA.split(' ')[0], cls: PEOPLE[MIRA].cls, alias: 'Lena' },
  ];
  const HOLD = 3200; // a complete example stands this long
  const FADE_OUT = 420; // the alias first, the name FADE_STAGGER later
  const FADE_STAGGER = 120;
  const NAME_IN = 650;
  const ALIAS_AFTER = 600; // the alias starts fading in this long after the name
  const ALIAS_IN = 800;
  const SOFT = 'cubic-bezier(0.22, 0.61, 0.36, 1)';
  const FADED = { opacity: 0, filter: 'blur(6px)' };
  const CLEAR = { opacity: 1, transform: 'none', filter: 'blur(0)' };
  const titleEl = $('#alias-title');
  const title = { at: 0, phase: 'out', timer: 0, seen: false, live: null, leaving: [] };

  // One line of the title: the language's sentence around name and alias.
  function titleLine(example) {
    const [before, between, after] = t('al_title', '\u0001', '\u0001').split('\u0001');
    const name = make('span', `aka__name cls cls--${example.cls}`, example.name);
    const word = make('span', 'aka__alias', example.alias);
    const line = make('span');
    line.append(before, name, between, word, after);
    return { line, name, word };
  }

  // The title stays on one line wherever its longest example fits the page's
  // content (on a desktop it does, past the 780 px of the head); on a phone
  // it wraps. Decided for all examples at once, so it does not change from
  // one to the next.
  function fitTitle() {
    titleEl.classList.remove('is-wrapping');
    const room = titleEl.closest('.wrap').clientWidth;
    const widest = Math.max(...$$('.aka__ghost', titleEl).map(ghost => ghost.getBoundingClientRect().width));
    titleEl.classList.toggle('is-wrapping', widest > room);
  }

  // Every example stands invisible in the same grid cell as the one that
  // moves, so the title keeps the height of its longest example and the
  // text below does not jump.
  // The example on screen is drawn complete; a fade that was under way when
  // the language changes starts over with the example it left.
  function drawTitle() {
    for (const fade of title.leaving) fade.cancel();
    title.leaving = [];
    title.phase = 'out';
    clearTimeout(title.timer);
    title.timer = 0;
    const first = TITLE_EXAMPLES[0];
    const said = make('span', 'sr-only', t('al_title', first.name, first.alias));
    const stage = make('span', 'aka__stage');
    stage.setAttribute('aria-hidden', 'true');
    for (const example of TITLE_EXAMPLES) {
      const ghost = titleLine(example).line;
      ghost.className = 'aka__ghost';
      stage.append(ghost);
    }
    title.live = titleLine(TITLE_EXAMPLES[title.at]);
    title.live.line.className = 'aka__live';
    stage.append(title.live.line);
    titleEl.textContent = '';
    titleEl.append(said, stage);
    fitTitle();
    scheduleTitle();
  }

  function titleLater(ms) {
    title.timer = setTimeout(titleStep, ms);
  }

  function titleStep() {
    title.timer = 0;
    const live = title.live;
    if (title.phase === 'out') {
      const gone = { ...FADED, transform: 'translateY(-0.12em)' };
      title.leaving = [
        live.word.animate([CLEAR, gone], { duration: FADE_OUT, easing: 'ease-in', fill: 'forwards' }),
        live.name.animate([CLEAR, gone], { duration: FADE_OUT, delay: FADE_STAGGER, easing: 'ease-in', fill: 'forwards' }),
      ];
      title.phase = 'in';
      return titleLater(FADE_OUT + FADE_STAGGER);
    }
    for (const fade of title.leaving) fade.cancel();
    title.leaving = [];
    title.at = (title.at + 1) % TITLE_EXAMPLES.length;
    const example = TITLE_EXAMPLES[title.at];
    live.name.textContent = example.name;
    live.name.className = `aka__name cls cls--${example.cls}`;
    live.word.textContent = example.alias;
    const coming = { ...FADED, transform: 'translateY(0.18em)' };
    live.name.animate([coming, CLEAR], { duration: NAME_IN, easing: SOFT });
    // "backwards" keeps the alias invisible while it waits for the name.
    live.word.animate([coming, CLEAR], { duration: ALIAS_IN, delay: ALIAS_AFTER, easing: SOFT, fill: 'backwards' });
    title.phase = 'out';
    return titleLater(ALIAS_AFTER + ALIAS_IN + HOLD);
  }

  function scheduleTitle() {
    const run = title.seen && !document.hidden && !motion.matches;
    if (!run) {
      clearTimeout(title.timer);
      title.timer = 0;
    } else if (!title.timer) {
      // A complete example stands a while first; a half-finished change goes on.
      titleLater(title.phase === 'out' ? HOLD : 0);
    }
  }

  new IntersectionObserver(entries => {
    title.seen = entries[entries.length - 1].isIntersecting;
    scheduleTitle();
  }, { threshold: 0.5 }).observe(titleEl);
  document.addEventListener('visibilitychange', scheduleTitle);
  motion.addEventListener('change', drawTitle);
  // The width changes with the window, and once Inter has loaded.
  let fitting = 0;
  addEventListener('resize', () => {
    cancelAnimationFrame(fitting);
    fitting = requestAnimationFrame(fitTitle);
  });
  if (document.fonts) document.fonts.ready.then(fitTitle);
  renderers.push(drawTitle);
  drawTitle();

  // -------------------------------------------------------------------------
  // 02 Chronicle: the picture book. The entries are the addon's own samples
  // (/fam chronicle demo), told the way the book tells them.
  // -------------------------------------------------------------------------

  // Per kind: the picture's icon (none: the number) and its tone. As
  // PICTURES in Famulus/UI/Book.lua.
  const PICTURES = {
    level: { tone: 'accent' },
    achievement: { icon: 'star', tone: 'accent' },
    zone: { icon: 'peaks', tone: 'plain' },
    skill: { tone: 'accent' },
    item: { icon: 'chest', tone: 'accent' },
    ability: { icon: 'horseshoe', tone: 'accent' },
    death: { icon: 'skull', tone: 'death' },
    boss: { icon: 'swords', tone: 'boss' },
    // The story of a fellow traveller: time together, and the bond's milestones.
    fellow: { icon: 'people', tone: 'plain' },
    bond: { icon: 'people', tone: 'accent' },
  };

  // How much an event weighs, as WEIGHT in Famulus/UI/Options.lua: light
  // cards for deaths and new zones, heavy ones (milestones) for bosses and
  // levels, medium for the rest. The weight sets the picture, the headline,
  // the card's width and its dot on the line.
  const WEIGHT = { death: 'low', zone: 'low', boss: 'high', level: 'high' };
  const weightOf = event => (event.big ? 'high' : WEIGHT[event.kind] || 'medium');

  // One reaction per kind, as ChronicleService.REACTIONS; a new zone has none.
  const REACTIONS = { death: 'sad', boss: 'strong', level: 'cheer', skill: 'clap', ability: 'cheer', item: 'cheer', achievement: 'cheer' };

  // Newest first. Yesterday holds three deaths in a row and two levels of a
  // friend, so the book shows how it bundles them. A chapter is a session of
  // play; its head is worked out from the events it shows (chapterHead).
  // `from`: friends who reacted to one of your events; `mine`: you reacted
  // to a friend's.
  const CHAPTERS = [
    {
      day: 'c_today',
      ago: 0,
      events: [
        { time: '21:42', kind: 'item', who: MIRA, zone: 'Feralas' },
        { time: '21:10', kind: 'boss', who: BORIN, zone: 'Uldaman', mine: true },
        { time: '20:36', kind: 'item', zone: 'Tanaris' },
        { time: '20:05', kind: 'ability', level: 40, big: true },
        { time: '19:48', kind: 'level', number: 40, zone: 'Tanaris', from: [MIRA, BORIN, KAELRIC] },
        { time: '19:02', kind: 'zone', zone: 'Tanaris', level: 39 },
        { time: '18:40', kind: 'death', zone: 'Feralas', level: 39 },
      ],
    },
    {
      day: 'c_yesterday',
      ago: 1,
      events: [
        { time: '23:15', kind: 'ability', who: MIRA, level: 40 },
        { time: '22:58', kind: 'level', who: BORIN, number: 31, zone: 'Feralas' },
        { time: '22:31', kind: 'level', who: BORIN, number: 30, zone: 'Feralas' },
        { time: '22:20', kind: 'skill', number: 75, zone: 'Uldaman' },
        { time: '21:52', kind: 'death', zone: 'Uldaman', level: 39, from: [BORIN] },
        { time: '21:47', kind: 'death', zone: 'Uldaman', level: 39 },
        { time: '21:44', kind: 'death', zone: 'Uldaman', level: 39 },
        { time: '21:40', kind: 'death', who: BORIN, zone: 'Feralas', level: 29 },
        { time: '21:05', kind: 'level', number: 39, zone: 'Uldaman' },
        { time: '20:30', kind: 'boss', zone: 'Uldaman' },
        { time: '19:10', kind: 'achievement', zone: 'Desolace' },
      ],
    },
  ];

  // What the friends shared: online or not, and their stats (deaths,
  // creatures defeated, quests, dungeons; the game's statistics).
  const COMPANIONS = {
    [MIRA]: { online: true, profile: [212, 4810, 388, 41] },
    [BORIN]: { online: false, profile: [340, 3102, 251, 27] },
  };
  const CRAFTS = [
    { name: 'n_tailoring', value: 92, max: 150 },
    { name: 'n_cooking', value: 38, max: 75 },
  ];

  // The headline and the line below it, without the place: the book has it
  // in the card's foot, the live feed on the card's last row (Placeless in
  // Famulus/UI/Options.lua). Whose event it is stands above, in both.
  function tell(event) {
    const level = event.level ? t('c_at_level', event.level) : null;
    switch (event.kind) {
      case 'level': return { title: t('c_level', event.number) };
      case 'death': return { title: t('c_death_nowhere'), detail: level };
      case 'boss': return { title: t('c_boss', 'Archaedas') };
      case 'zone': return { title: t('c_zone_nowhere'), detail: level };
      case 'ability': return { title: t('c_ability_riding'), detail: level };
      case 'item': return { title: t('c_item', t('n_bag')) };
      case 'skill': return { title: t('c_skill', t('n_tailoring'), event.number) };
      default: return { title: t('c_achievement', t('n_challenge')) };
    }
  }

  // "Alias (Character Name)", as ChronicleService.Label; without an alias the name.
  const labelOf = name => (aliasOf(name) ? `${aliasOf(name)} (${name})` : name);

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
  // levels of the same friend. Your own levels stay single; they are the
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
    if (run[0].kind === 'death') {
      const levels = run.map(event => event.level);
      const low = Math.min(...levels);
      const high = Math.max(...levels);
      return { title: t('c_deaths_nowhere', run.length), detail: low === high ? t('c_at_level', low) : t('c_at_levels', low, high) };
    }
    const numbers = run.map(event => event.number);
    return { title: t('c_levels', Math.min(...numbers), Math.max(...numbers)) };
  }

  // The reaction at a card's foot, as UI.ReactionButton. On a friend's card a
  // click reacts to their newest event, and takes it back; a bundle with a
  // reaction anywhere in it takes them all back. Your own card shows how many
  // reacted, and who on the mouse; there is no reaction to yourself.
  function reaction(run, size = 16) {
    const event = run[0];
    const kind = REACTIONS[event.kind];
    if (!kind) return null;
    if (!event.who) {
      const from = [...new Set(run.flatMap(each => each.from || []))];
      if (!from.length) return null;
      const badge = make('span', 'react is-lit');
      badge.append(icon(kind, size), make('span', '', from.length));
      badge.title = `${t('c_reactions_from')}: ${from.map(nameOf).join(', ')}`;
      badge.setAttribute('role', 'img');
      badge.setAttribute('aria-label', badge.title);
      return badge;
    }
    const button = make('button', 'react');
    button.type = 'button';
    button.append(icon(kind, size));
    const paint = () => {
      const lit = run.some(each => each.mine);
      button.classList.toggle('is-lit', lit);
      button.setAttribute('aria-pressed', String(lit));
      button.title = t(lit ? 'c_react_given' : 'c_react');
      button.setAttribute('aria-label', button.title);
    };
    button.addEventListener('click', () => {
      const lit = run.some(each => each.mine);
      for (const each of run) each.mine = false;
      if (!lit) event.mine = true;
      paint();
    });
    paint();
    return button;
  }

  let bookTab = 'all';
  let bookWho = null; // a friend picked in the rail: the book shows only them

  const wanted = event => (bookTab === 'all' || (bookTab === 'mine') === !event.who)
    && (!bookWho || event.who === bookWho);

  // A day some days back, the way the reader's language writes a date.
  const dateOf = ago => new Date(Date.now() - ago * 86400000)
    .toLocaleDateString(lang === 'en' ? 'en-GB' : lang, { day: 'numeric', month: 'short' });

  // As SessionTitle in Famulus/UI/Options.lua: a session of play is named
  // by the part of the day it began in ("This evening", "Yesterday
  // afternoon"); an older one after its weekday ("Sunday evening"), and then
  // its date stands on the left instead of the times. `ago`: days back.
  function sessionTitle(ago, from) {
    const hour = Number(from.slice(0, 2));
    const part = hour < 5 ? 'night' : hour < 11 ? 'morning' : hour < 14 ? 'midday' : hour < 18 ? 'afternoon' : hour < 23 ? 'evening' : 'night';
    const day = hour < 5 ? ago + 1 : ago; // until five in the morning it is the night before
    if (day === 0) return { title: t(`c_when_today_${part}`) };
    if (day === 1) return { title: t(`c_when_yesterday_${part}`) };
    const weekday = new Date(Date.now() - day * 86400000).getDay();
    return { title: t(`c_when_day_${part}`, t(`c_weekday_${weekday}`)), date: dateOf(day) };
  }

  // As SessionHead in Famulus/UI/Options.lua, from the events shown: from
  // when to when, the session's name by the time it began, the levels you
  // reached (your own events only) and how many events there are; below it
  // the route, the zones of your own events in the order you visited them.
  function chapterHead(chapter, events) {
    let low = Infinity;
    let high = -Infinity;
    for (const event of events) {
      const level = event.who ? null : (event.kind === 'level' ? event.number : event.level);
      if (level) {
        low = Math.min(low, level);
        high = Math.max(high, level);
      }
    }
    const parts = [];
    if (low < Infinity) parts.push(low === high ? t('c_ch_level', low) : t('c_ch_levels', low, high));
    parts.push(events.length === 1 ? t('c_ch_event') : t('c_ch_events', events.length));
    const first = events[events.length - 1].time;
    const last = events[0].time;
    const route = [];
    for (const event of [...events].reverse()) {
      if (!event.who && event.zone && route[route.length - 1] !== event.zone) route.push(event.zone);
    }
    return { title: sessionTitle(chapter.ago, first).title, span: first === last ? first : `${first} – ${last}`, sub: parts.join('  ·  '), route };
  }

  function renderBook() {
    const book = $('#book');
    book.textContent = '';
    for (const chapter of CHAPTERS) {
      const events = chapter.events.filter(wanted);
      if (!events.length) continue;

      // The head in one line: from when to when, the session in the book's
      // type, levels and the number of events; a line on each side running
      // out. Below it the route.
      const head = make('header', 'chapter__head reveal');
      const told = chapterHead(chapter, events);
      const before = make('div', 'chapter__side');
      before.append(make('i'), make('p', 'chapter__day', told.span));
      const after = make('div', 'chapter__side');
      after.append(make('p', 'chapter__sub', told.sub), make('i'));
      head.append(before, make('h3', '', told.title), after);
      const section = make('section', 'chapter');
      section.append(head);
      if (told.route.length) {
        const route = make('ol', 'chapter__route reveal');
        told.route.forEach((zone, index) => {
          const stop = make('li');
          if (index) stop.append(icon('chevron', 10));
          stop.append(make('span', '', zone));
          route.append(stop);
        });
        section.append(route);
      }

      const trail = make('div', 'chapter__events');
      for (const run of runsOf(events)) {
        const event = run[0];
        const many = run.length > 1;
        const weight = weightOf(event);
        const told = many ? tellRun(run) : tell(event);
        const story = make('article', `story story--${PICTURES[event.kind].tone} story--${weight} reveal${weight === 'high' ? ' is-big' : ''}`);

        // The sunken strip: whose event it is (your own character's too), and
        // when; a bundle names its first and its last time.
        const strip = make('header', 'story__strip');
        const oldest = run[run.length - 1].time;
        strip.append(make('span', '', labelOf(event.who || ME)), make('time', '', many ? `${oldest} – ${event.time}` : event.time));

        const text = make('div', 'story__text');
        text.append(make('h4', '', told.title));
        if (told.detail) text.append(make('p', '', told.detail));
        // The foot: the place, and the reaction at its right.
        const place = run.every(each => each.zone === event.zone) ? event.zone : null;
        const react = reaction(run);
        if (place || react) {
          const foot = make('div', 'story__place');
          foot.append(make('span', '', place || ''));
          if (react) foot.append(react);
          text.append(foot);
        }
        // A friend's levels show the highest one in the picture.
        const shown = many && event.kind === 'level' ? { ...event, number: Math.max(...run.map(each => each.number)) } : event;
        const body = make('div', 'story__body');
        body.append(picture(shown, run.length), text);
        const card = make('div', 'story__card');
        card.append(strip, body);
        story.append(make('span', 'story__dot'), card);
        trail.append(story);
      }

      section.append(trail);
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
  const number = value => value.toLocaleString(lang === 'en' ? 'en-US' : lang);

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
      card.append(personButton(who, `${tell(event).title}  ·  ${when}`));
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
  const when = ago => (ago === 0 ? t('fw_today') : ago === 1 ? t('fw_yesterday') : t('fw_on', dateOf(ago)));
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
      levelClass: () => levelClass(person.level, person.cls),
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

  // The speech bubble that opens a whisper (ChatService.Whisper). Nothing is
  // sent until you write; here the hint below the demo says what would happen.
  function whisperButton(who, big) {
    const button = make('button', `whisper${big ? ' whisper--big' : ''}`);
    button.type = 'button';
    button.title = t('fw_whisper_to', nameOf(who));
    button.setAttribute('aria-label', button.title);
    button.append(icon('chat', big ? 20 : 16));
    button.addEventListener('click', () => {
      $('#fw-said').textContent = t('fw_whisper_said', who);
    });
    return button;
  }

  // A button with a whisper beside it, in one box: a button cannot hold another.
  function withWhisper(button, who, className) {
    const box = make('div', className);
    box.append(button, whisperButton(who));
    return box;
  }

  function tile(shown, rank) {
    const button = make('button', `ftile${shown.now ? ' is-now' : ''}`);
    button.type = 'button';
    button.dataset.who = shown.who;
    button.append(
      make('span', 'ftile__rank', ['I', 'II', 'III'][rank]),
      crest(shown, 'big'),
      make('strong', 'ftile__name', shown.name),
      joined(make('span', 'ftile__sub'), [shown.levelClass()]),
      badge(shown.tier),
      make('span', 'ftile__stats', shown.statsText),
      make('span', 'ftile__foot', shown.lastText),
    );
    button.addEventListener('click', () => openStory(shown.who));
    return withWhisper(button, shown.who, 'ftile-box');
  }

  function row(shown) {
    const button = make('button', `frow${shown.now ? ' is-now' : ''}`);
    button.type = 'button';
    button.dataset.who = shown.who;
    const name = make('span', 'frow__name');
    name.append(make('strong', '', shown.name), joined(make('span'), [shown.realName, shown.levelClass()]));
    button.append(crest(shown, 'small'), name, badge(shown.tier), make('span', 'frow__time', duration(shown.minutes)), make('span', 'frow__last', shown.lastShort));
    button.addEventListener('click', () => openStory(shown.who));
    return withWhisper(button, shown.who, 'frow-box');
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
      joined(make('p', 'fprofile__sub'), [shown.realName, shown.levelClass()]),
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

    // As in the addon: square icons in one row, named on the mouse. The
    // whisper in the middle, set an alias to its left, and their own events
    // in the chronicle left of that, if there are any.
    const buttons = make('div', 'fprofile__buttons');
    const square = (name, label, action) => {
      const button = make('button', 'iconbtn');
      button.type = 'button';
      button.title = label;
      button.setAttribute('aria-label', label);
      button.append(icon(name, 16));
      button.addEventListener('click', action);
      return button;
    };
    if (COMPANIONS[shown.who]) buttons.append(square('flag', t('fw_chronicle'), () => showChronicleOf(shown.who)));
    buttons.append(square('tag', t('fw_alias'), () => editAlias(shown.who)), whisperButton(shown.who, true));
    card.append(buttons);
    return card;
  }

  // One chapter per session of play, the newest first, as FellowStory in
  // Famulus/UI/Options.lua: named like the chronicle's, from when to when on
  // the left (an older one its date), the time together on the right. Inside:
  // where you were on the road, the bosses that fell, the day the bond
  // reached a new tier, and the day you met. The day log knows one stretch a
  // day, so a day is one session here, as in the addon.
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
      const span = t('fw_span', day.from, end);
      const events = [{ kind: 'fellow', title: t('fw_run', day.zone), detail: day.more ? `${span}  ·  ${bossesText(day.more)}` : span, sort: day.from }];
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
      const from = day.ago === fellow.met.ago && fellow.met.at < day.from ? fellow.met.at : day.from;
      const head = sessionTitle(day.ago, from);
      return { day: head.date || `${from} – ${end}`, title: head.title, sub: t('fw_day_time', duration(day.minutes)), events };
    });
    // Met before the day log: a chapter of its own.
    if (!metShown) {
      const head = sessionTitle(fellow.met.ago, fellow.met.at);
      chapters.push({ day: head.date || fellow.met.at, title: head.title, sub: '', events: [met] });
    }
    return chapters;
  }

  function storyCard(event) {
    const look = PICTURES[event.kind];
    const story = make('article', `story story--${look.tone}${event.big ? ' is-big' : ''}`);
    const dot = make('span', 'story__dot');
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

  // "Nearby": who of your friends and guild is online right now and where,
  // as NearbyService reads the friends list, Battle.net and the guild
  // roster. Nothing is sent, and they need no Famulus. You are level 40 in
  // Tanaris, as the chronicle says.
  const HERE = { zone: 'Tanaris', level: 40 };
  const SIMILAR = 5; // levels apart, as in the addon
  const ONLINE = [
    { who: MIRA, zone: 'Tanaris', from: 'friend' },
    { who: LYSA, zone: 'Tanaris', from: 'guild' },
    { who: YORICK, zone: 'Feralas', from: 'friend' },
    { who: ENA, zone: 'Desolace', from: 'bnet' },
    { who: GARRICK, zone: 'Westfall', from: 'guild' },
  ];
  const apart = person => Math.abs(PEOPLE[person.who].level - HERE.level);

  // A row as UI.NearbyList: crest with the bond's ring, alias or name, below
  // it the name, class and where you know them from; level and how far from
  // yours; the zone, yours in the accent; the bond; the whisper. A fellow
  // traveller's row opens your story.
  function nearRow(person) {
    const fellow = FELLOWS.find(each => each.who === person.who);
    const shown = fellow ? fellowOf(fellow) : null;
    const alias = aliasOf(person.who);
    const { level, cls, colour } = PEOPLE[person.who];
    const row = make(shown ? 'button' : 'div', 'frow nrow');
    const name = make('span', 'frow__name');
    name.append(make('strong', '', alias || person.who), joined(make('span'), [alias && person.who, classWord(cls), t(`fw_from_${person.from}`)]));
    const gap = level - HERE.level;
    const levelCell = make('span', 'nrow__level', t('c_p_level', level));
    levelCell.append(make('em', '', gap === 0 ? '\u00b10' : gap > 0 ? `+${gap}` : `\u2212${-gap}`));
    row.append(
      crest(shown || { progress: 0, name: alias || person.who, colour }, 'small'),
      name,
      levelCell,
      make('span', `nrow__zone${person.zone === HERE.zone ? ' is-here' : ''}`, person.zone),
      shown ? badge(shown.tier) : make('span'),
    );
    if (shown) {
      row.type = 'button';
      row.dataset.who = person.who;
      row.title = t('fw_near_story');
      row.addEventListener('click', () => openStory(person.who));
    }
    return withWhisper(row, person.who, 'frow-box');
  }

  function nearbyView(host) {
    const here = ONLINE.filter(person => person.zone === HERE.zone);
    const rest = ONLINE.filter(person => person.zone !== HERE.zone).sort((a, b) => apart(a) - apart(b));
    const similar = rest.filter(person => apart(person) <= SIMILAR);
    const others = rest.filter(person => apart(person) > SIMILAR);
    for (const [title, note, people] of [
      [t('fw_near_here', HERE.zone), null, here],
      [t('fw_near_similar'), t('fw_near_similar_note', SIMILAR), similar],
      [t('fw_near_others'), null, others],
    ]) {
      if (!people.length) continue;
      const bar = make('div', 'fellows__bar');
      const heading = make('h3', 'fellows__title', title);
      if (note) heading.append(make('span', 'fellows__note', note));
      bar.append(heading);
      const list = make('div', 'flist');
      list.append(...people.map(nearRow));
      host.append(bar, list);
    }
  }

  let fellowView = 'overview'; // the tab: 'overview' or 'nearby'

  function renderFellows() {
    const host = $('#fellows-demo');
    host.textContent = '';
    host.classList.toggle('is-story', fellowOpen != null);
    if (fellowOpen) story(host, fellowOpen);
    else if (fellowView === 'nearby') nearbyView(host);
    else overview(host);
    spaceDots();
  }

  for (const tab of $$('#fellows-tabs button')) {
    tab.addEventListener('click', () => {
      fellowView = tab.dataset.view;
      fellowOpen = null; // another tab closes a story, as in the addon
      for (const other of $$('#fellows-tabs button')) chooseTab(other, other === tab);
      $('#fellows-demo').setAttribute('aria-labelledby', tab.id);
      renderFellows();
    });
  }
  tablist($('#fellows-tabs'));

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
    const host = card.parentElement;
    setTimeout(() => card.remove(), 520);
    if (host) arrange(host); // the others move up
  }

  // The last row of a card: the place first, then what else there is to say.
  const feedLine = event => [event.zone, tell(event).detail].filter(Boolean).join('  ·  ');

  // As Famulus/UI/Feed.lua since #75: only the newest card is large, the
  // ones before it are slim rows below it (a small crest, whose it is and
  // what happened on one line), and a fourth is pushed out. A new card
  // stays on top for a moment (STEP) before the next comes; those that wait
  // are counted on the top card.
  const STEP = 1200;
  const TALL = 76;
  const LARGE = 64;
  const SLIM = 34;
  const GAP = 10; // below the large card
  const SLIM_GAP = 6; // below a row

  // Stacks the cards: the newest on top, the rows below it.
  function arrange(host) {
    const cards = $$('.toast:not(.is-leaving)', host);
    let y = 0;
    cards.forEach((card, index) => {
      card.classList.toggle('is-slim', index > 0);
      card.style.setProperty('--y', `${y}px`);
      y += index ? SLIM + SLIM_GAP : (card.classList.contains('is-tall') ? TALL : LARGE) + GAP;
    });
    cards.slice(MAX_CARDS).forEach(leave);
    for (const count of $$('.toast__count', host)) count.remove();
    const waiting = (host.waiting || []).length;
    if (waiting && cards[0]) cards[0].append(make('span', 'toast__count', `+${waiting}`));
  }

  // Cards that come faster than STEP wait their turn.
  function showCard(host, event, seconds) {
    host.waiting = host.waiting || [];
    const due = (host.last || 0) + STEP - Date.now();
    if (due <= 0 && !host.waiting.length) {
      enter(host, event, seconds);
      return;
    }
    host.waiting.push([event, seconds]);
    arrange(host);
    if (!host.pump) {
      const pump = () => {
        const [next, time] = host.waiting.shift();
        enter(host, next, time);
        host.pump = host.waiting.length ? setTimeout(pump, STEP) : 0;
      };
      host.pump = setTimeout(pump, Math.max(due, 0));
    }
  }

  // A card in three rows: whose it is (none for your own), what happened,
  // where; as a row, whose it is and what happened. A friend's card has the
  // reaction at its right end: a click gives it and the card goes a second
  // later. A line along the foot runs out while the card stays; the mouse on
  // the card holds it.
  function enter(host, event, seconds) {
    host.last = Date.now();
    const card = make('div', `toast toast--${PICTURES[event.kind].tone}${event.big ? ' is-big' : ''}`);
    const text = make('div', 'toast__text');
    if (event.who) text.append(make('p', 'toast__who', labelOf(event.who)));
    text.append(make('strong', '', tell(event).title));
    const line = feedLine(event);
    if (line) text.append(make('span', '', line));
    card.classList.toggle('is-tall', text.childElementCount === 3);
    const row = make('p', 'toast__line');
    row.append(make('b', '', labelOf(event.who || ME)), `  ·  ${tell(event).title}`);
    card.append(picture(event), text, row);
    const kind = REACTIONS[event.kind];
    if (event.who && kind) {
      const button = make('button', 'react react--feed');
      button.type = 'button';
      button.title = t('c_react');
      button.setAttribute('aria-label', button.title);
      button.append(icon(kind, 18));
      button.addEventListener('click', () => {
        if (button.classList.contains('is-lit')) return; // the feed only gives
        button.classList.add('is-lit');
        clearTimeout(card.timer);
        card.timer = setTimeout(() => leave(card), 1000);
        card.given = true;
      });
      card.append(button);
    }
    if (Number.isFinite(seconds)) {
      const bar = make('i', 'toast__bar');
      bar.style.animationDuration = `${seconds}s`;
      card.append(bar);
      card.addEventListener('mouseenter', () => {
        if (!card.given) clearTimeout(card.timer);
      });
      card.addEventListener('mouseleave', () => {
        if (!card.given && !card.classList.contains('is-leaving')) card.timer = setTimeout(() => leave(card), 1500);
      });
    }
    host.prepend(card);
    arrange(host);
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
      feedSaid.textContent = [event.who && labelOf(event.who), tell(event).title, feedLine(event)].filter(Boolean).join(', ');
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
  // 05 Screenshots: one screenshot at a time. It moves on by itself every
  // EVERY ms, but not with reduced motion, not while paused, not while the
  // mouse or the focus is on the slider, not while it is off screen or the
  // tab is in the background. Arrows, dots, the arrow keys and a swipe move it.
  // -------------------------------------------------------------------------

  const slider = $('#shots-slider');
  const track = $('#shots-track');
  const slides = $$('.slide', track);
  const dots = $('#shots-dots');
  const pauseButton = $('#shots-pause');
  const EVERY = 6000;
  let shown = 0;
  let paused = false; // by the button
  let held = false; // by the mouse or the focus
  let seen = false; // on screen
  let turn = 0;

  function drawSlides() {
    track.style.transform = `translateX(${-100 * shown}%)`;
    slides.forEach((slide, index) => {
      slide.setAttribute('aria-label', t('sh_goto', index + 1, slides.length));
      slide.setAttribute('aria-hidden', String(index !== shown));
      slide.inert = index !== shown;
    });
    dots.textContent = '';
    slides.forEach((_, index) => {
      const dot = make('button', `slider__dot${index === shown ? ' is-shown' : ''}`);
      dot.type = 'button';
      dot.setAttribute('aria-label', t('sh_goto', index + 1, slides.length));
      dot.setAttribute('aria-current', String(index === shown));
      dot.append(make('i'));
      dot.addEventListener('click', () => show(index, true));
      dots.append(dot);
    });
    const running = !paused && !motion.matches;
    slider.classList.toggle('is-running', running && !held && seen && !document.hidden);
    pauseButton.setAttribute('aria-pressed', String(paused));
    pauseButton.hidden = motion.matches;
  }

  function schedule() {
    clearTimeout(turn);
    const run = !paused && !held && seen && !document.hidden && !motion.matches;
    slider.classList.toggle('is-running', run);
    if (run) turn = setTimeout(() => show(shown + 1, false), EVERY);
  }

  // by: true when the reader chose it, so the new slide is read out.
  function show(index, by) {
    shown = (index + slides.length) % slides.length;
    track.setAttribute('aria-live', by ? 'polite' : 'off');
    drawSlides();
    // The dot's fill starts over with the slide.
    const dot = $('.slider__dot.is-shown', dots);
    if (dot) {
      dot.classList.remove('is-shown');
      void dot.offsetWidth;
      dot.classList.add('is-shown');
    }
    schedule();
  }

  $('#shots-prev').addEventListener('click', () => show(shown - 1, true));
  $('#shots-next').addEventListener('click', () => show(shown + 1, true));
  pauseButton.addEventListener('click', () => {
    paused = !paused;
    drawSlides();
    schedule();
  });
  slider.addEventListener('keydown', event => {
    if (event.key === 'ArrowLeft') show(shown - 1, true);
    else if (event.key === 'ArrowRight') show(shown + 1, true);
  });
  slider.addEventListener('pointerenter', () => { held = true; schedule(); });
  slider.addEventListener('pointerleave', () => { held = slider.contains(document.activeElement); schedule(); });
  slider.addEventListener('focusin', () => { held = true; schedule(); });
  slider.addEventListener('focusout', event => {
    held = slider.contains(event.relatedTarget) || slider.matches(':hover');
    schedule();
  });
  // A swipe: far enough sideways, and more sideways than down.
  let from = null;
  track.addEventListener('pointerdown', event => { from = { x: event.clientX, y: event.clientY }; });
  track.addEventListener('pointerup', event => {
    if (!from) return;
    const dx = event.clientX - from.x;
    const dy = event.clientY - from.y;
    from = null;
    if (Math.abs(dx) > 40 && Math.abs(dx) > Math.abs(dy)) show(shown + (dx < 0 ? 1 : -1), true);
  });
  new IntersectionObserver(entries => {
    seen = entries[entries.length - 1].isIntersecting;
    schedule();
  }, { threshold: 0.4 }).observe(slider);
  document.addEventListener('visibilitychange', schedule);
  motion.addEventListener('change', () => { drawSlides(); schedule(); });
  renderers.push(drawSlides);
  drawSlides();

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
    // A group of four with the hunter's wolf; the old tree stands farther
    // back.
    cast: [
      { figure: 'oak', at: 18.5, back: true, facing: 1, rim: false },
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
    { seed: 43, base: 770, amp: 70, scale: 420, octaves: 3, tone: 4, depth: 0.7, plateau: { from: 890, to: 1475, y: 640, edge: 170 }, grass: { gap: [5, 14], height: [4, 11] }, bushes: [[905, 20], [1530, 22]], camp: CAMP, flies: { from: 860, to: 1540, count: 14, seed: 3 } },
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

  // The worlds of the hero: the moonlit night and four more. Each keeps the
  // camp against the large moon (or a setting sun) and changes the world
  // around it; their colours are #scene[data-world] in styles.css.
  //   moon      see FamulusScene.moon (also bats and a dragon)
  //   aurora    northern lights, see FamulusScene.aurora
  //   clouds    clouds lit from below, see FamulusScene.clouds
  //   snowfall  how many snowflakes (half as many on phones)
  //   layers    the ridges, far to near, as HERO
  const [FAR, MID, WOODS, HILL, GROUND] = HERO;
  const WORLDS = {
    night: { moon: MOON, layers: HERO },

    // A wizard's tower on a crag beside the moon, islands of rock floating in
    // a violet sky, the sky shimmering with arcane light.
    arcane: {
      moon: MOON,
      aurora: {
        depth: 0.05,
        bands: [
          { y: 250, amp: 46, height: 180, seed: 4, color: 'var(--magic)', from: 760, to: 1760, blur: 2.6 },
          { y: 150, amp: 30, height: 100, seed: 9, color: 'var(--magic3)', from: -100, to: 1000, blur: 2.2 },
        ],
      },
      layers: [
        { ...FAR, float: [{ figure: 'isle', x: 1395, y: 262, scale: 0.86, facing: -1, tone: 2 }, { figure: 'rock', x: 1560, y: 170, scale: 0.8, tone: 2 }] },
        { ...MID, cast: [{ figure: 'tower', x: 912, scale: 0.68, facing: -1, sink: 24 }] },
        { ...WOODS, mist: { y: 690, height: 90, opacity: 0.22 } },
        HILL,
        GROUND,
      ],
    },

    // A castle on the heights at sunset, a waterfall far off, long clouds lit
    // from beneath, a dragon gliding across the sky.
    dusk: {
      moon: { ...MOON, small: null, bats: [], dragons: [[1500, 300, 0.95]] },
      clouds: {
        depth: 0.06,
        clouds: [[1240, 130, 480, 40, 8], [1250, 452, 560, 20, 3], [250, 480, 560, 26, 12], [560, 96, 380, 24, 21]],
      },
      layers: [
        { ...FAR, cast: [{ figure: 'cascade', x: 150, scale: 0.9, sink: 6 }] },
        { ...MID, cast: [{ figure: 'keep', x: 850, scale: 0.76, facing: -1, sink: 46 }] },
        { ...WOODS, mist: { y: 700, height: 110, opacity: 0.3, puffs: [[150, 660, 140, 40], [560, 700, 200, 40], [760, 712, 260, 36]] } },
        { ...HILL, flies: { ...HILL.flies, count: 8 } },
        GROUND,
      ],
    },

    // A world tree on the horizon, its crown over half the sky, an old forest
    // below it, a moonwell at its edge, glowing mushrooms and wisps on the
    // hill, mist in the valleys.
    forest: {
      moon: MOON,
      layers: [
        { seed: 11, base: 610, amp: 90, scale: 520, octaves: 3, tone: 1, depth: 0.16, haze: 60, valley: { at: 0.72, width: 0.2, depth: 1 }, trees: { gap: [7, 15], height: [14, 26], bushes: 0.5, giants: [[400, 480, 'world']] } },
        { seed: 23, base: 690, amp: 100, scale: 400, octaves: 3, tone: 2, depth: 0.3, haze: 60, valley: { at: 0.72, width: 0.2, depth: 1 }, mist: { y: 600, height: 140, opacity: 0.3, puffs: [[400, 590, 260, 50]] }, trees: { gap: [8, 18], height: [18, 40], bushes: 0.3 } },
        { ...WOODS, mist: { y: 720, height: 110, opacity: 0.3, puffs: [[800, 690, 200, 40]] }, trees: { ...WOODS.trees, broad: 0.2, clear: [770, 1420] }, cast: [{ figure: 'well', x: 810, scale: 0.95, sink: 4 }] },
        { ...HILL, cast: [{ figure: 'shrooms', x: 882, scale: 1.7, sink: 2 }, { figure: 'shrooms', x: 1510, scale: 1.3, facing: -1, sink: 2 }], flies: { ...HILL.flies, count: 22 } },
        { ...GROUND, trees: { ...GROUND.trees, broad: 0.2 } },
      ],
    },

    // Snow on the peaks, northern lights over them, a hold of the mountain
    // folk with braziers burning at the foot of the mountains, snow falling.
    frost: {
      moon: MOON,
      aurora: {
        depth: 0.05,
        bands: [
          { y: 210, amp: 60, height: 200, seed: 21, color: 'var(--magic)', from: 300, to: 1750, blur: 2.6 },
          { y: 130, amp: 30, height: 110, seed: 33, color: 'var(--magic3)', from: -100, to: 900, blur: 2.2 },
        ],
      },
      snowfall: 70,
      layers: [
        { ...FAR, amp: 380, snow: { line: 450, depth: 60 } },
        { ...MID, amp: 320, snow: { line: 530, depth: 50 }, cast: [{ figure: 'hold', x: 868, scale: 0.7, sink: 40 }] },
        { ...WOODS, mist: { y: 700, height: 80, opacity: 0.2 }, trees: { ...WOODS.trees, broad: 0 } },
        { ...HILL, flies: null },
        { ...GROUND, trees: { ...GROUND.trees, broad: 0, bushes: 0 }, flies: null },
      ],
    },
  };

  const hero = $('#top');
  const heroScene = $('#scene');
  let heroCamp;
  // Draws a world into the hero, in place of the one before. Its key on the
  // root brings its colours to the whole page (styles.css).
  function drawHero(name) {
    const spec = WORLDS[name];
    for (const old of $$(':scope > .ridge, :scope > .world', heroScene)) old.remove();
    root.dataset.world = name;
    Scene.moon(heroScene, spec.moon);
    if (spec.aurora) Scene.aurora(heroScene, spec.aurora);
    if (spec.clouds) Scene.clouds(heroScene, spec.clouds);
    heroCamp = Scene.build(heroScene, spec.layers).find(layer => layer.camp);
    if (spec.snowfall) Scene.snow(heroScene, innerWidth < 760 ? spec.snowfall / 2 : spec.snowfall);
  }
  // The world was settled before the first paint (the script in the head of
  // index.html): the one asked for with ?world=, the one the reader chose
  // before (remembered like the language), or one by chance. Only a choice in
  // the menu is remembered, not ?world=.
  const worldKeys = Object.keys(WORLDS);
  const isWorld = key => Object.hasOwn(WORLDS, key || '');
  const byChance = (not = null) => {
    const keys = worldKeys.filter(key => key !== not);
    return keys[Math.floor(Math.random() * keys.length)];
  };
  let chosenWorld = isWorld(store.get('famulus-scene')) ? store.get('famulus-scene') : null;
  let world = isWorld(root.dataset.world) ? root.dataset.world : chosenWorld || byChance();
  drawHero(world);
  Scene.stars($('.scene__stars', heroScene), 170, 5);
  Scene.build($('#scene-alias'), glimpse(100));
  Scene.build($('#scene-feed'), glimpse(200));
  const footScene = $('#scene-foot');
  const footLayers = Scene.build(footScene, FOOT);

  // In one column the camp stands below the text, and the drawing pans so
  // that it is in view, from the mage to the old tree (the CSS makes it smaller).
  const heroInColumn = matchMedia('(max-width: 980px)');
  const CAMP_MIDDLE = 1170;

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

  // English unless the reader chose otherwise: ?lang=fr forces a language,
  // a language switched to before is remembered. The browser's language is
  // not consulted. Anything unknown is passed over.
  const known = code => (code && I18N[code.toLowerCase()] ? code.toLowerCase() : null);
  const asked = known(new URLSearchParams(location.search).get('lang'));
  setLanguage(asked || known(store.get('famulus-lang')) || 'en', false);

  kindle();
  const depth = Scene.parallax(hero);
  watch(document);

  // The scene beside the languages: a button with the shown world's small
  // picture opens a menu of all of them (pick.js). A world picked there is
  // remembered (famulus-scene); "Random" forgets it and shows another one.
  // The world fades out, is drawn anew and fades in.
  let fading = 0;
  function markWorld() {
    scenes.mark(item => item.dataset.world === (chosenWorld || 'random'));
    $('#scenes-current').className = `worlds__dot worlds__dot--${world}`;
    const toggle = $('#scenes-toggle');
    toggle.setAttribute('aria-label', `${t('world_pick')}: ${t(`world_${world}`)}`);
    toggle.title = toggle.getAttribute('aria-label');
  }
  // The window below the header in the world's colour scheme (--shot, as the
  // script behind the picture in index.html picks it at first): the new
  // picture is loaded and decoded before it takes the old one's place.
  function showShot() {
    const img = $('#shot-window');
    const shot = getComputedStyle(root).getPropertyValue('--shot').trim() || 'lemon';
    const srcset = `assets/shots/window-${shot}-1180.webp 1180w, assets/shots/window-${shot}-1770.webp 1770w`;
    if (img.getAttribute('srcset') === srcset) return;
    const next = new Image();
    next.sizes = img.sizes;
    next.srcset = srcset;
    next.src = `assets/shots/window-${shot}-1180.webp`;
    next.decode().catch(() => {}).then(() => {
      if (getComputedStyle(root).getPropertyValue('--shot').trim() !== shot) return; // switched on meanwhile
      img.srcset = srcset;
      img.src = next.src;
    });
  }
  function switchWorld(next) {
    if (next === world) return;
    world = next;
    markWorld();
    const swap = () => {
      drawHero(world);
      kindle();
      depth.refresh();
      showShot();
      heroScene.classList.remove('is-fading');
    };
    clearTimeout(fading);
    if (motion.matches) return swap();
    heroScene.classList.add('is-fading');
    fading = setTimeout(swap, 300);
  }
  const scenes = window.FamulusPick($('#scenes'), item => {
    const key = item.dataset.world;
    chosenWorld = isWorld(key) ? key : null;
    if (chosenWorld) store.set('famulus-scene', chosenWorld);
    else store.remove('famulus-scene');
    switchWorld(chosenWorld || byChance(world));
    markWorld();
  });
  renderers.push(markWorld);
  markWorld();
  onScroll();
  // The book's cards change height once Inter has loaded; the dots follow.
  if (document.fonts) document.fonts.ready.then(spaceDots);

  renderers.push(
    play($('#hero-toasts'), $('.hero__feed'), ['level', 'boss', 'ability', 'item', 'death', 'skill'], 4400, 9.5),
    play(feedCards, feedView, ['boss', 'level', 'item', 'ability', 'skill', 'death'], 5200, 8),
  );
})();
