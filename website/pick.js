// A button that opens a small menu to pick one of a few things: the scene of
// the header and the language, on index.html and legal.html alike.
//
//   FamulusPick(root, onPick)  root: a .pick holding a .pick__toggle and a
//                              .pick__menu of [role="menuitemradio"] items;
//                              onPick(item) once one is chosen
//   returns { mark(chosen) }   marks the items for which chosen(item) is true
//
// The menu opens on the chosen item. Arrow keys, Home and End move in it,
// Escape closes it and returns to the button, Tab or a click elsewhere
// closes it.
window.FamulusPick = (root, onPick) => {
  'use strict';

  const toggle = root.querySelector('.pick__toggle');
  const menu = root.querySelector('.pick__menu');
  const items = [...menu.querySelectorAll('[role="menuitemradio"]')];

  function open(show, focus) {
    menu.hidden = !show;
    toggle.setAttribute('aria-expanded', String(show));
    if (show) (items.find(item => item.getAttribute('aria-checked') === 'true') || items[0]).focus();
    else if (focus) toggle.focus();
  }

  toggle.addEventListener('click', () => open(menu.hidden));
  toggle.addEventListener('keydown', event => {
    if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp') return;
    event.preventDefault();
    open(true);
  });
  menu.addEventListener('keydown', event => {
    const index = items.indexOf(document.activeElement);
    const to = event.key === 'ArrowDown' ? (index + 1) % items.length
      : event.key === 'ArrowUp' ? (index - 1 + items.length) % items.length
        : event.key === 'Home' ? 0 : event.key === 'End' ? items.length - 1 : -1;
    if (to >= 0) {
      event.preventDefault();
      items[to].focus();
    } else if (event.key === 'Escape') {
      event.preventDefault();
      open(false, true);
    } else if (event.key === 'Tab') {
      open(false);
    }
  });
  document.addEventListener('pointerdown', event => {
    if (!menu.hidden && !root.contains(event.target)) open(false);
  });
  for (const item of items) {
    item.addEventListener('click', () => {
      open(false, true);
      onPick(item);
    });
  }

  return {
    mark(chosen) {
      for (const item of items) item.setAttribute('aria-checked', String(chosen(item)));
    },
  };
};
