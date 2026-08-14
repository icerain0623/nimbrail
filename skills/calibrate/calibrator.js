/* ─────────────────────────────────────────────────────────────────────────────
 * calibrator — live CSS custom property tuner
 *
 * Paste into the DevTools Console of the running app, or (recommended, since
 * console snippets die on reload) save it once as a DevTools Snippet:
 *   Sources → Snippets → New snippet → paste → ⌘Enter to run, any time.
 *
 * Discovers every custom property that resolves on :root, builds sliders /
 * color pickers for them, writes changes straight onto documentElement, and
 * persists them per-origin in localStorage so a reload + re-run restores them.
 * "Copy CSS" gives you the changed tokens only — hand that to Claude to apply.
 * ───────────────────────────────────────────────────────────────────────────── */
(() => {
  'use strict';

  const HOST_ID = 'nimbrail-calibrator';
  const LS_KEY = 'nimbrail-calibrator:' + location.origin;
  const root = document.documentElement;

  document.getElementById(HOST_ID)?.remove();

  /* ── persisted overrides ─────────────────────────────────────────────── */

  let overrides = {};
  try { overrides = JSON.parse(localStorage.getItem(LS_KEY) || '{}'); } catch {}
  const save = () => { try { localStorage.setItem(LS_KEY, JSON.stringify(overrides)); } catch {} };

  /* ── token discovery ─────────────────────────────────────────────────── */

  // Names only. Whether a name is actually a root token is decided by whether
  // it resolves on documentElement — that filter drops component-scoped vars
  // (`.btn { --btn-pad }`) for free, without guessing at selectors.
  function declaredNames() {
    const names = new Set();
    const visit = (rules) => {
      for (const rule of rules) {
        const st = rule.style;
        if (st) for (let i = 0; i < st.length; i++) {
          const p = st[i];
          if (p.startsWith('--')) names.add(p);
        }
        if (rule.cssRules) { try { visit(rule.cssRules); } catch {} } // nesting, @media, @layer
      }
    };
    const sheets = [...document.styleSheets, ...(document.adoptedStyleSheets || [])];
    for (const s of sheets) { try { visit(s.cssRules); } catch {} }   // cross-origin sheets throw
    return names;
  }

  // Baselines must be read with overrides lifted, so "reset" has something to
  // go back to. Re-run this after Claude edits the CSS (⟳ button).
  function scan() {
    for (const k of Object.keys(overrides)) root.style.removeProperty(k);
    const cs = getComputedStyle(root);
    const list = [];
    for (const name of declaredNames()) {
      const base = cs.getPropertyValue(name).trim();
      if (base) list.push({ name, base });
    }
    for (const [k, v] of Object.entries(overrides)) root.style.setProperty(k, v);
    return list.sort((a, b) => a.name.localeCompare(b.name));
  }

  /* ── control inference ───────────────────────────────────────────────── */

  const ctx = document.createElement('canvas').getContext('2d');
  // Assigning an unparseable color to fillStyle leaves the previous value, so
  // two different priors agreeing means the value really parsed as a color.
  function toHex(v) {
    try {
      ctx.fillStyle = '#000'; ctx.fillStyle = v; const a = ctx.fillStyle;
      ctx.fillStyle = '#fff'; ctx.fillStyle = v; const b = ctx.fillStyle;
      return a === b && /^#[0-9a-f]{6}$/i.test(a) ? a : null;
    } catch { return null; }
  }

  const UNIT = /^(-?\d*\.?\d+)(px|rem|em|ch|ex|%|vh|vw|vmin|vmax|ms|s|deg|fr)$/;

  function control(v) {
    const m = UNIT.exec(v);
    if (m) return { kind: 'num', num: parseFloat(m[1]), unit: m[2] };
    if (/^-?\d*\.?\d+$/.test(v)) return { kind: 'num', num: parseFloat(v), unit: '' };
    const hex = toHex(v);
    if (hex || CSS.supports('color', v)) return { kind: 'color', hex };
    return { kind: 'text' };
  }

  function range(n, unit) {
    const abs = Math.abs(n);
    let max, step;
    switch (unit) {
      case '%': case 'vh': case 'vw': case 'vmin': case 'vmax': max = 100; step = 1; break;
      case 'deg': max = 360; step = 1; break;
      case 'ms': max = Math.max(300, abs * 3); step = 10; break;
      case 's': max = Math.max(1, abs * 3); step = 0.05; break;
      case 'rem': case 'em': case 'ch': case 'ex': max = Math.max(2, abs * 3); step = 0.05; break;
      case 'fr': max = Math.max(2, abs * 3); step = 0.1; break;
      case 'px': max = Math.max(8, Math.ceil(abs * 3)); step = abs < 8 ? 0.5 : 1; break;
      default: max = Math.max(2, abs * 3); step = abs <= 3 ? 0.01 : 1;
    }
    return { min: n < 0 ? -max : 0, max, step };
  }

  // Framework-internal vars are real root tokens but never worth tuning, so
  // they get grouped and collapsed rather than hidden outright.
  const INTERNAL = /^--(tw|_|radix|reach|chakra|mantine|nextjs)/;
  const groupOf = (name) => (INTERNAL.test(name) ? 'internal' : name.slice(2).split(/[-_]/)[0] || 'root');

  /* ── shadow-DOM shell (app CSS must not reach the panel) ─────────────── */

  const host = document.createElement('div');
  host.id = HOST_ID;
  host.style.cssText = 'position:fixed;right:16px;bottom:16px;z-index:2147483647;';
  const sr = host.attachShadow({ mode: 'open' });
  sr.innerHTML = `<style>
    :host, * { box-sizing: border-box; }
    .panel {
      width: 340px; max-height: 78vh; display: flex; flex-direction: column;
      font: 12px/1.4 ui-sans-serif, -apple-system, "Helvetica Neue", sans-serif;
      color: #e7e9ee; background: #1c1f26; border: 1px solid #333944;
      border-radius: 10px; box-shadow: 0 12px 32px rgba(0,0,0,.45);
      overflow: hidden; resize: both;
    }
    .hd { display: flex; align-items: center; gap: 6px; padding: 8px 10px;
          background: #232733; border-bottom: 1px solid #333944; cursor: grab; user-select: none; }
    .hd.drag { cursor: grabbing; }
    .ttl { font-weight: 600; letter-spacing: .02em; }
    .cnt { color: #8b93a3; font-variant-numeric: tabular-nums; }
    .sp { flex: 1; }
    button { font: inherit; color: #cdd3de; background: #2c313d; border: 1px solid #3b4250;
             border-radius: 6px; padding: 3px 7px; cursor: pointer; }
    button:hover { background: #353b49; color: #fff; }
    button.on { background: #3d5afe; border-color: #3d5afe; color: #fff; }
    .tb { display: flex; gap: 6px; align-items: center; padding: 7px 10px;
          border-bottom: 1px solid #2b3039; }
    .tb input[type=search] { flex: 1; min-width: 0; padding: 4px 7px; color: #e7e9ee;
      background: #14171d; border: 1px solid #3b4250; border-radius: 6px; }
    .seg { display: flex; }
    .seg button { border-radius: 0; border-left-width: 0; padding: 3px 6px; }
    .seg button:first-child { border-radius: 6px 0 0 6px; border-left-width: 1px; }
    .seg button:last-child { border-radius: 0 6px 6px 0; }
    .body { flex: 1; overflow: auto; padding: 4px 0 8px; }
    details { border-bottom: 1px solid #23272f; }
    summary { padding: 6px 10px; cursor: pointer; color: #9aa3b4; text-transform: uppercase;
              letter-spacing: .06em; font-size: 10px; }
    summary::marker { color: #5b6473; }
    .row { display: grid; grid-template-columns: 1fr auto; gap: 2px 6px; padding: 5px 10px 7px; }
    .row.hide { display: none; }
    .row .nm { grid-column: 1; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;
               color: #b9c0cd; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
    .row.chg .nm { color: #7fd1a0; }
    .row.chg .nm::after { content: " ●"; color: #7fd1a0; }
    .rst { grid-column: 2; visibility: hidden; }
    .row.chg .rst { visibility: visible; }
    .ctl { grid-column: 1 / -1; display: flex; align-items: center; gap: 6px; }
    .ctl input[type=range] { flex: 1; min-width: 0; accent-color: #3d5afe; }
    .ctl input[type=number], .ctl input[type=text] {
      width: 74px; padding: 2px 5px; color: #e7e9ee; background: #14171d;
      border: 1px solid #3b4250; border-radius: 5px; font-variant-numeric: tabular-nums; }
    .ctl input[type=text] { flex: 1; width: auto; font-family: ui-monospace, Menlo, monospace; }
    .ctl input[type=color] { width: 30px; height: 24px; padding: 0; background: none;
                             border: 1px solid #3b4250; border-radius: 5px; }
    .u { color: #79828f; width: 22px; }
    .ft { display: flex; gap: 6px; padding: 8px 10px; border-top: 1px solid #333944; background: #232733; }
    .ft button { flex: 1; }
    .empty { padding: 18px 14px; color: #9aa3b4; }
    .empty code { color: #cdd3de; }
  </style>
  <div class="panel">
    <div class="hd"><span class="ttl">Calibrator</span><span class="cnt"></span><span class="sp"></span>
      <button class="rescan" title="Re-scan after a CSS edit / HMR">⟳</button>
      <button class="close" title="Close (keeps values applied)">✕</button></div>
    <div class="tb">
      <input type="search" placeholder="filter…" />
      <button class="only" title="Show changed only">●</button>
      <span class="seg"><button data-t="auto" class="on">A</button><button data-t="light">☀</button><button data-t="dark">☾</button></span>
    </div>
    <div class="body"></div>
    <div class="ft">
      <button class="cssbtn">Copy CSS</button>
      <button class="jsonbtn">Copy JSON</button>
      <button class="resetall">Reset all</button>
    </div>
  </div>`;
  document.body.appendChild(host);

  const $ = (s) => sr.querySelector(s);
  const body = $('.body'), search = $('input[type=search]'), onlyBtn = $('.only');

  /* ── value plumbing ──────────────────────────────────────────────────── */

  const rows = new Map(); // name → { el, setDisplay(value) }

  function set(name, value) {
    overrides[name] = value;
    root.style.setProperty(name, value);
    rows.get(name)?.el.classList.add('chg');
    save();
  }

  function reset(name) {
    delete overrides[name];
    root.style.removeProperty(name);
    const r = rows.get(name);
    if (r) { r.el.classList.remove('chg'); r.setDisplay(r.base); }
    save();
  }

  /* ── rendering ───────────────────────────────────────────────────────── */

  function render() {
    const tokens = scan();
    rows.clear();
    body.innerHTML = '';
    $('.cnt').textContent = tokens.length ? `${tokens.length} tokens` : '';

    if (!tokens.length) {
      body.innerHTML = `<div class="empty">No custom properties resolve on <code>:root</code>.<br><br>
        The values are probably hardcoded across components — that is an extraction
        job for Claude, not a slider job. Ask it to lift them into tokens first,
        then re-scan.</div>`;
      return;
    }

    const groups = new Map();
    for (const t of tokens) {
      const g = groupOf(t.name);
      if (!groups.has(g)) groups.set(g, []);
      groups.get(g).push(t);
    }
    const names = [...groups.keys()].sort((a, b) =>
      (a === 'internal') - (b === 'internal') || a.localeCompare(b));
    const openByDefault = tokens.length <= 24;

    for (const g of names) {
      const items = groups.get(g);
      const det = document.createElement('details');
      det.open = openByDefault && g !== 'internal';
      det.innerHTML = `<summary>${g} <span style="opacity:.6">(${items.length})</span></summary>`;
      for (const t of items) det.appendChild(makeRow(t));
      body.appendChild(det);
    }
    applyFilter();
  }

  function makeRow({ name, base }) {
    const cur = overrides[name] ?? base;
    const el = document.createElement('div');
    el.className = 'row' + (name in overrides ? ' chg' : '');
    el.dataset.name = name;

    const nm = document.createElement('div');
    nm.className = 'nm'; nm.textContent = name; nm.title = `${name}\nbase: ${base}`;
    const rst = document.createElement('button');
    rst.className = 'rst'; rst.textContent = '↺'; rst.title = `Reset to ${base}`;
    rst.onclick = () => reset(name);
    const ctl = document.createElement('div');
    ctl.className = 'ctl';
    el.append(nm, rst, ctl);

    const c = control(cur);
    let setDisplay;

    if (c.kind === 'num') {
      const { min, max, step } = range(c.num, c.unit);
      const rng = document.createElement('input');
      rng.type = 'range'; rng.min = min; rng.max = max; rng.step = step; rng.value = c.num;
      const num = document.createElement('input');
      num.type = 'number'; num.step = step; num.value = c.num;
      const u = document.createElement('span');
      u.className = 'u'; u.textContent = c.unit;

      const push = (v) => set(name, v + c.unit);
      rng.oninput = () => { num.value = rng.value; push(rng.value); };
      num.oninput = () => {
        const v = parseFloat(num.value);
        if (Number.isNaN(v)) return;
        if (v > +rng.max) rng.max = v;          // typing past the slider widens it
        if (v < +rng.min) rng.min = v;
        rng.value = v; push(num.value);
      };
      ctl.append(rng, num, u);
      setDisplay = (v) => { const p = parseFloat(v); rng.value = p; num.value = p; };

    } else if (c.kind === 'color') {
      const txt = document.createElement('input');
      txt.type = 'text'; txt.value = cur;
      const pick = document.createElement('input');
      pick.type = 'color';
      if (c.hex) pick.value = c.hex; else pick.disabled = true;  // e.g. oklch() has no hex form
      pick.oninput = () => { txt.value = pick.value; set(name, pick.value); };
      txt.onchange = () => { const h = toHex(txt.value); if (h) pick.value = h; set(name, txt.value); };
      ctl.append(pick, txt);
      setDisplay = (v) => { txt.value = v; const h = toHex(v); if (h) pick.value = h; };

    } else {
      const txt = document.createElement('input');
      txt.type = 'text'; txt.value = cur;
      txt.onchange = () => set(name, txt.value);
      ctl.append(txt);
      setDisplay = (v) => { txt.value = v; };
    }

    rows.set(name, { el, base, setDisplay });
    return el;
  }

  /* ── filtering ───────────────────────────────────────────────────────── */

  function applyFilter() {
    const q = search.value.trim().toLowerCase();
    const only = onlyBtn.classList.contains('on');
    for (const [name, r] of rows) {
      const hit = (!q || name.toLowerCase().includes(q)) && (!only || name in overrides);
      r.el.classList.toggle('hide', !hit);
    }
    for (const det of sr.querySelectorAll('details')) {
      const any = [...det.querySelectorAll('.row')].some((r) => !r.classList.contains('hide'));
      det.style.display = any ? '' : 'none';
      if ((q || only) && any) det.open = true;
    }
  }
  search.oninput = applyFilter;
  onlyBtn.onclick = () => { onlyBtn.classList.toggle('on'); applyFilter(); };

  /* ── theme, copy, reset, drag ────────────────────────────────────────── */

  const origTheme = root.getAttribute('data-theme');
  const origDark = root.classList.contains('dark');
  for (const b of sr.querySelectorAll('.seg button')) b.onclick = () => {
    for (const o of sr.querySelectorAll('.seg button')) o.classList.remove('on');
    b.classList.add('on');
    const m = b.dataset.t;
    if (m === 'auto') {
      origTheme === null ? root.removeAttribute('data-theme') : root.setAttribute('data-theme', origTheme);
      root.classList.toggle('dark', origDark);
    } else {
      root.setAttribute('data-theme', m);          // covers both common conventions
      root.classList.toggle('dark', m === 'dark');
    }
  };

  function copy(text, btn) {
    const done = () => { const t = btn.textContent; btn.textContent = 'copied'; setTimeout(() => btn.textContent = t, 900); };
    navigator.clipboard.writeText(text).then(done).catch(() => {
      const ta = document.createElement('textarea');
      ta.value = text; document.body.appendChild(ta); ta.select();
      document.execCommand('copy'); ta.remove(); done();
    });
  }
  const sorted = () => Object.entries(overrides).sort(([a], [b]) => a.localeCompare(b));
  $('.cssbtn').onclick = (e) => copy(':root {\n' + sorted().map(([k, v]) => `  ${k}: ${v};`).join('\n') + '\n}', e.target);
  $('.jsonbtn').onclick = (e) => copy(JSON.stringify(Object.fromEntries(sorted()), null, 2), e.target);

  $('.resetall').onclick = () => { for (const k of Object.keys(overrides)) reset(k); };
  $('.rescan').onclick = render;
  $('.close').onclick = () => host.remove();

  const hd = $('.hd');
  hd.addEventListener('pointerdown', (e) => {
    if (e.target.tagName === 'BUTTON') return;
    const r = host.getBoundingClientRect();
    const dx = e.clientX - r.left, dy = e.clientY - r.top;
    hd.classList.add('drag'); hd.setPointerCapture(e.pointerId);
    const move = (ev) => {
      host.style.left = `${ev.clientX - dx}px`; host.style.top = `${ev.clientY - dy}px`;
      host.style.right = 'auto'; host.style.bottom = 'auto';
    };
    const up = () => { hd.classList.remove('drag'); hd.removeEventListener('pointermove', move); hd.removeEventListener('pointerup', up); };
    hd.addEventListener('pointermove', move); hd.addEventListener('pointerup', up);
  });

  /* ── boot ────────────────────────────────────────────────────────────── */

  for (const [k, v] of Object.entries(overrides)) root.style.setProperty(k, v);
  render();
  console.info(`[calibrator] ${rows.size} root tokens, ${Object.keys(overrides).length} restored overrides`);
})();
