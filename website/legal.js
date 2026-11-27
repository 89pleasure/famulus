// The legal page (legal.html): the language as on the main page (main.js),
// without the demos. Navigation and footer take their texts from i18n/;
// the legal texts stand in the page in every language (data-only) and only
// the chosen one is shown.
(() => {
  'use strict';

  const root = document.documentElement;
  const I18N = window.FAMULUS_I18N;
  const $$ = selector => [...document.querySelectorAll(selector)];
  const attributeKeys = element => element.dataset.i18nAttr.split(';').map(pair => pair.split(':'));
  const store = {
    get(key) {
      try { return localStorage.getItem(key); } catch { return null; }
    },
    set(key, value) {
      try { localStorage.setItem(key, value); } catch { /* private mode */ }
    },
  };

  // English stands in the HTML; collect it once, so that switching back works.
  for (const element of $$('[data-i18n]')) I18N.en[element.dataset.i18n] = element.innerHTML;
  for (const element of $$('[data-i18n-attr]')) {
    for (const [attribute, key] of attributeKeys(element)) I18N.en[key] = element.getAttribute(attribute);
  }
  const description = document.querySelector('meta[name="description"]');
  I18N.en.lg_meta_title = document.title;
  I18N.en.lg_meta_desc = description.content;

  for (const [code, table] of Object.entries(I18N)) {
    const missing = Object.keys(I18N.en).filter(key => table[key] == null);
    if (missing.length) console.warn(`[famulus] ${code} lacks: ${missing.join(', ')}`);
  }

  function setLanguage(next, remember) {
    const lang = I18N[next] ? next : 'en';
    const t = key => (I18N[lang][key] != null ? I18N[lang][key] : I18N.en[key]);
    root.lang = lang;
    for (const element of $$('[data-i18n]')) element.innerHTML = t(element.dataset.i18n);
    for (const element of $$('[data-i18n-attr]')) {
      for (const [attribute, key] of attributeKeys(element)) element.setAttribute(attribute, t(key));
    }
    for (const block of $$('[data-only]')) block.hidden = block.dataset.only !== lang;
    document.title = t('lg_meta_title');
    description.content = t('lg_meta_desc');
    languages.mark(item => item.dataset.lang === lang);
    document.getElementById('langs-current').textContent = lang.toUpperCase();
    const toggle = document.getElementById('langs-toggle');
    toggle.setAttribute('aria-label', `${t('nav_lang')}: ${document.querySelector(`#langs-menu [data-lang="${lang}"]`).lastElementChild.textContent}`);
    toggle.title = toggle.getAttribute('aria-label');
    if (remember) store.set('famulus-lang', lang);
  }

  // A button with the language's code opens the choice (pick.js).
  const languages = window.FamulusPick(document.getElementById('langs'), item => setLanguage(item.dataset.lang, true));

  // As on the main page: ?lang=fr forces a language, one chosen before is
  // remembered, otherwise English.
  const known = code => (code && I18N[code.toLowerCase()] ? code.toLowerCase() : null);
  const asked = known(new URLSearchParams(location.search).get('lang'));
  setLanguage(asked || known(store.get('famulus-lang')) || 'en', false);
})();
