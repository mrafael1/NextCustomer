// #63 capsule machine decide prep (2026-10-21): shared data, pixel painter and draw engine for the capsule_63_* pages.
// Mock-up only. Nothing here is game code; the draw rule mimics #63's core rule (key item first, then random among
// those left, no duplicates) with a fixed choice so stills are repeatable.
// URL parameters (all optional):
//   state=fresh|early|partial|full   collection (default partial: 9 of 30; early: 3 of 30, one key item in 3 aisles)
//   coins=N                    coins owned (defaults: fresh 1, partial 2, full 3)
//   nosave=1                   the profile can't be saved: machines switched off, "Coins ?"
//   draw=I&t=S                 freeze a draw from machine I (0-5, data order) at S seconds (stills)
//   rm=1                       reduced motion (the reveal fades in place)
//   words=capsule              "CAPSULE MACHINES" instead of "TOY MACHINES" (Q4; not chosen, TOY MACHINES decided)
//   locked=spaces|hidden       locked items as "?" recesses or not shown. Look C (not chosen) defaults to spaces; the
//                              shelf page defaults to hidden (decided 2026-10-21) and keeps spaces as a not-chosen view
//   cap=1                      hide the mock-up note (captures)
'use strict';
const CAP = (() => {
  const Q = new URLSearchParams(location.search);
  const P = {
    state: Q.get('state') || 'partial',
    coins: Q.has('coins') ? parseInt(Q.get('coins'), 10) : null,
    nosave: Q.get('nosave') === '1',
    draw: Q.has('draw') ? parseInt(Q.get('draw'), 10) : null,
    t: Q.has('t') ? parseFloat(Q.get('t')) : null,
    land: Q.has('land') ? parseFloat(Q.get('land')) : null,
    rm: Q.get('rm') === '1',
    words: Q.get('words') || 'toy',
    cap: Q.get('cap') === '1',
    locked: Q.get('locked') || 'spaces',
    labels: Q.get('labels') === '1',
    hover: Q.get('hover'),
  };
  const ART = 'assets/art/';
  // data/aisles/*.tres, in BalanceDefinition.aisles order; capsule_cards with the key item first
  const AISLES = [
    { id: 'cold_cases', name: 'Cold cases', ramp: ['#2a4d4b', '#4f9a94', '#86c2b6'], items: ['Cream', 'Ham ends'] },
    { id: 'pantry', name: 'Pantry', ramp: ['#b38425', '#e2b33c', '#f1d27a'], items: ['Sugar cubes', 'Mixed herbs'] },
    { id: 'household', name: 'Household', ramp: ['#5e574d', '#8a8172', '#c7beab'], items: ['Egg timer', 'Chipped mug', 'Odd socks'] },
    { id: 'fruit_and_veg', name: 'Fruit & veg', ramp: ['#1f3b3a', '#3d7a45', '#5fae5a'],
      items: ['Fruit salad', 'Strawberries', 'Grapefruit', 'Wonky carrot', 'Lemon', 'Bruised apples', 'Soft tomatoes', 'Potatoes'] },
    { id: 'bakery', name: 'Bakery', ramp: ['#a87a4e', '#d2a874', '#ddcba5'],
      items: ['Baguette', 'Scone', 'Croissant', 'Broken biscuit', 'Iced bun', 'Birthday candles', 'Squashed cake', 'Stale doughnut'] },
    { id: 'snacks', name: 'Snacks', ramp: ['#4a3022', '#7a5232', '#a87a4e'],
      items: ['Crisps', 'Cereal bar', 'Bent lolly', "Pick 'n' mix", 'Stale popcorn', 'Breadsticks', 'Dusty toffees'] },
  ];
  const SPRITES = { Strawberries: 'strawberries', Croissant: 'croissant', Crisps: 'crisps' };
  const TOTAL = AISLES.reduce((n, a) => n + a.items.length, 0);
  const PARTIAL = { cold_cases: ['Cream'], pantry: ['Sugar cubes', 'Mixed herbs'], household: ['Egg timer'],
    fruit_and_veg: ['Fruit salad', 'Strawberries', 'Lemon'], bakery: ['Baguette', 'Croissant'], snacks: [] };
  // early: each aisle's key item (first in data order) in 3 aisles
  const EARLY = { cold_cases: 1, fruit_and_veg: 1, snacks: 1 };
  const COIN_SVG = '<svg viewBox="0 0 12 12" shape-rendering="crispEdges"><path fill="#2b2420" d="M3 0h6v1h2v2h1v6h-1v2h-2v1H3v-1H1V9H0V3h1V1h2z"/><path fill="#e2b33c" d="M3 1h6v1h1v1h1v6h-1v1H9v1H3v-1H2V9H1V3h1V2h1z"/><path fill="#ffcf3f" d="M3 2h5v1H3v5H2V3h1z"/><path fill="#b38425" d="M9 4h1v5H9v1H4V9h5z"/><path fill="#7a5a1c" d="M5 4h2v4H5z"/></svg>';
  const WORDS = P.words === 'capsule'
    ? { title: 'CAPSULE MACHINES', one: 'capsule machine' } : { title: 'TOY MACHINES', one: 'toy machine' };

  function initialState() {
    const drawn = {};
    for (const a of AISLES) {
      drawn[a.id] = P.state === 'full' ? a.items.slice() : P.state === 'fresh' ? [] : P.state === 'early' ? a.items.slice(0, EARLY[a.id] || 0) : (PARTIAL[a.id] || []).slice();
    }
    const coins = P.coins !== null ? P.coins : P.state === 'fresh' || P.state === 'early' ? 1 : P.state === 'full' ? 3 : 2;
    return { drawn, coins, nosave: P.nosave };
  }

  // ---- pixel painter (1 art px = 2 canvas px through CSS) ----
  function canvas(w, h, cls) {
    const c = document.createElement('canvas');
    c.width = w; c.height = h; c.style.width = w * 2 + 'px'; c.style.height = h * 2 + 'px';
    if (cls) c.className = cls;
    return c;
  }
  function R(g, x, y, w, h, col) { g.fillStyle = col; g.fillRect(Math.round(x), Math.round(y), Math.round(w), Math.round(h)); }
  function disc(g, cx, cy, r, col, part) {
    g.fillStyle = col;
    for (let dy = -r; dy <= r; dy++) {
      if (part === 'top' && dy > 0) continue;
      if (part === 'bottom' && dy <= 0) continue;
      const hw = Math.floor(Math.sqrt(r * r - dy * dy) + 0.4);
      g.fillRect(cx - hw, cy + dy, hw * 2 + 1, 1);
    }
  }
  // outlined box: ink edge then fill
  function box(g, x, y, w, h, fill, ink = '#2b2420') { R(g, x, y, w, h, ink); R(g, x + 1, y + 1, w - 2, h - 2, fill); }
  // capsule: aisle-coloured top half, clear bottom half, ink outline, seam
  function capsule(g, cx, cy, r, ramp, part) {
    if (part !== 'bottom') {
      disc(g, cx, cy, r, '#2b2420', 'top');
      disc(g, cx, cy, r - 1, ramp[1], 'top');
      R(g, cx - Math.floor(r / 2), cy - r + 2, Math.max(1, Math.floor(r / 3)), 1, ramp[2]);
      R(g, cx - r + 1, cy, r * 2 - 1, 1, '#2b2420');
    }
    if (part !== 'top') {
      disc(g, cx, cy, r, '#2b2420', 'bottom');
      disc(g, cx, cy, r - 1, '#e4f6f3', 'bottom');
      R(g, cx + 1, cy + 2, Math.max(1, r - 3), 1, '#bfe2dd');
      if (part === 'bottom') R(g, cx - r + 1, cy, r * 2 - 1, 1, '#2b2420');
    }
  }
  // crank or dial handle: 4 frames (0 horizontal, 1 diag, 2 vertical, 3 other diag)
  function handle(g, cx, cy, len, frame, col, knob) {
    const dirs = [[1, 0], [1, 1], [0, 1], [-1, 1]];
    const [dx, dy] = dirs[frame % 4];
    for (let k = -len; k <= len; k++) { R(g, cx + dx * k - 1, cy + dy * k - 1, 2, 2, '#2b2420'); }
    for (let k = -len + 1; k <= len - 1; k++) { R(g, cx + dx * k, cy + dy * k, 1, 1, col); }
    R(g, cx + dx * len - 2, cy + dy * len - 2, 4, 4, '#2b2420');
    R(g, cx + dx * len - 1, cy + dy * len - 1, 2, 2, knob);
  }
  // pile of capsules inside a window or globe; slots = [[x,y],...], n shown; jiggle shifts alternate ones
  function pile(g, slots, n, ramp, r, jig) {
    for (let k = 0; k < Math.min(n, slots.length); k++) {
      const [x, y] = slots[k];
      const j = jig ? (k % 2 ? jig : -jig) : 0;
      capsule(g, x + j, y - Math.abs(j), r, ramp);
    }
  }

  function el(tag, cls, parent, html) {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (html !== undefined) e.innerHTML = html;
    if (parent) parent.appendChild(e);
    return e;
  }
  function glyph(a) { return `<img src="${ART}icons/aisle_${a.id}.png" alt="">`; }
  // the figurine: the item's plain sprite, or the art-pending box with its name (until #57/#58)
  function figure(name, small) {
    if (SPRITES[name]) return `<img src="${ART}items_v2/${SPRITES[name]}.png" alt="${name}">`;
    return `<div class="pend${small ? ' s' : ''}">${name}</div>`;
  }
  function coinChip(parent, x, y, coins, nosave) {
    const c = el('div', 'coins', parent);
    c.style.left = x + 'px'; c.style.top = y + 'px';
    c.innerHTML = `${COIN_SVG}<span class="lab">COINS</span><span class="n">${nosave ? '?' : coins}</span>`;
    return c;
  }
  function note(html) {
    if (P.cap) return;
    el('div', 'mk', document.body, html + ' · <a href="capsule_63_index.html">index</a>');
  }

  // ---- the draw timeline (short version; #64 owns the real timings) ----
  const T = { coin: [0, 0.42], crank: [0.42, 1.0], drop: [1.0, 1.32], hop: [1.32, 1.78], shake: [1.78, 2.06],
    pop: [2.06, 2.26], rise: [2.26, 2.62], end: 2.62 };
  const RM_END = 0.3;
  const seg = (t, [a, b]) => Math.max(0, Math.min(1, (t - a) / (b - a)));
  const lerp = (a, b, k) => a + (b - a) * k;
  const outQuad = k => 1 - (1 - k) * (1 - k);
  const inQuad = k => k * k;
  const outBack = k => { const c = 1.9; return 1 + (c + 1) * Math.pow(k - 1, 3) + c * Math.pow(k - 1, 2); };
  const snap = v => Math.round(v / 2) * 2;

  function nextItem(S, a) {
    const d = S.drawn[a.id];
    const left = a.items.filter(n => !d.includes(n));
    if (!left.length) return null;
    if (!d.length) return left[0];
    return left[(d.length * 7 + a.id.length * 3) % left.length];
  }

  // look = { stage, machines (count 6), slot(i), chute(i), center:{x,y}, coinEl(), update(view), afterOk(i, item, k)?, landTime? }
  function engine(look) {
    const S = initialState();
    const stage = look.stage;
    const fx = el('div', 'fx', stage);
    const shade = el('div', 'shade', fx);
    const coin = el('div', 'flycoin', fx, COIN_SVG); coin.style.display = 'none';
    const capWhole = canvas(16, 16, 'cap'); const capTop = canvas(16, 16, 'cap'); const capBot = canvas(16, 16, 'cap');
    for (const c of [capWhole, capTop, capBot]) { c.style.display = 'none'; fx.appendChild(c); }
    const flash = el('div', 'flash', fx);
    const rv = el('div', 'reveal', fx);
    let D = null; // current draw: { i, item, t0, frozenT, okAt }
    let lastCoins = null;

    function paintCaps(a) {
      for (const [c, part] of [[capWhole], [capTop, 'top'], [capBot, 'bottom']]) {
        const g = c.getContext('2d'); g.clearRect(0, 0, 16, 16); capsule(g, 8, 8, 7, a.ramp, part);
      }
    }
    function buildReveal(a, item) {
      const C = look.center;
      rv.innerHTML = '';
      const rays = el('div', 'rays', rv); rays.style.left = C.x - 180 + 'px'; rays.style.top = C.y - 70 - 180 + 'px';
      const med = canvas(56, 56, 'med'); rv.appendChild(med); med.style.position = 'absolute';
      med.style.left = C.x - 56 + 'px'; med.style.top = C.y - 70 - 56 + 'px';
      { const g = med.getContext('2d'); disc(g, 28, 28, 27, '#2b2420'); disc(g, 28, 28, 26, '#b38425'); disc(g, 28, 28, 24, '#f1d27a'); disc(g, 27, 27, 21, '#faecbc'); R(g, 12, 18, 2, 6, '#fbf7ee'); R(g, 14, 14, 3, 2, '#fbf7ee'); }
      const fig = el('div', 'fig', rv, figure(item)); fig.style.left = C.x - 48 + 'px'; fig.style.top = C.y - 70 - 48 + 'px';
      const newb = el('div', 'newb', rv, 'NEW!'); newb.style.left = C.x + 34 + 'px'; newb.style.top = C.y - 150 + 'px';
      const name = el('div', 'name', rv, item);
      const aisle = el('div', 'aisle ol2', rv, `${glyph(a)}<span>${a.name}</span>`);
      const stock = el('div', 'stock', rv, 'In stock from your next run');
      const ok = el('div', 'fbtn primary ok', rv, 'OK');
      const tip = el('div', 'tip', rv, 'Click anywhere');
      // centre the text rows once fonts have laid out
      const place = () => {
        name.style.left = C.x - name.offsetWidth / 2 + 'px'; name.style.top = C.y + 2 + 'px';
        aisle.style.left = C.x - aisle.offsetWidth / 2 + 'px'; aisle.style.top = C.y + 64 + 'px';
        stock.style.left = C.x - stock.offsetWidth / 2 + 'px'; stock.style.top = C.y + 96 + 'px';
        ok.style.left = C.x - 75 + 'px'; ok.style.top = C.y + 148 + 'px';
        tip.style.left = C.x - tip.offsetWidth / 2 + 'px'; tip.style.top = C.y + 206 + 'px';
      };
      place(); document.fonts && document.fonts.ready.then(place);
      ok.addEventListener('click', e => { e.stopPropagation(); closeReveal(); });
      return { rays, med, fig, newb, name, aisle, stock, ok, tip };
    }
    let RV = null;

    function start(i, frozen) {
      if (D || S.nosave || S.coins <= 0) return;
      const a = AISLES[i];
      const item = nextItem(S, a);
      if (!item) return;
      // the draw is made and saved before any animation: coin spent, item recorded
      S.coins -= 1; S.drawn[a.id].push(item);
      D = { i, item, t0: performance.now(), frozenT: frozen, okAt: null };
      paintCaps(a);
      RV = buildReveal(a, item);
    }
    function closeReveal() {
      if (!D) return;
      if (look.afterOk && D.okAt === null) { D.okAt = performance.now(); return; }
      D = null; rv.style.opacity = 0; rv.innerHTML = ''; shade.style.opacity = 0;
    }
    function tNow() { return D.frozenT !== null && D.frozenT !== undefined ? D.frozenT : (performance.now() - D.t0) / 1000; }

    stage.addEventListener('click', () => {
      if (!D) return;
      const t = tNow();
      const end = P.rm ? RM_END : T.end;
      if (D.frozenT === null || D.frozenT === undefined) {
        if (t < T.pop[0] && !P.rm) { D.t0 = performance.now() - T.pop[0] * 1000; return; } // a tap jumps to the reveal
        if (t >= end) closeReveal();
      }
    });

    function view() {
      const v = { S, coins: S.coins, left: {}, crank: {}, jig: {}, flap: {}, drawing: D ? D.i : null, item: D ? D.item : null, rm: P.rm };
      for (const a of AISLES) v.left[a.id] = a.items.length - S.drawn[a.id].length;
      v.owned = AISLES.reduce((n, a) => n + S.drawn[a.id].length, 0);
      if (!D) return v;
      const a = AISLES[D.i];
      const t = tNow();
      if (!P.rm) {
        if (t < T.coin[1]) v.coins += 1;
        if (t < T.drop[0]) v.left[a.id] += 1;
        if (t < T.pop[0]) v.owned -= 1; // FIGURINES n / 30 counts at the pop (a #64 beat)
        const kc = seg(t, T.crank);
        v.crank[D.i] = kc > 0 && kc < 1 ? Math.floor(kc * 8) % 4 : 0;
        v.jig[D.i] = kc > 0 && kc < 1 ? (Math.floor(kc * 12) % 2 ? 1 : 0) : 0;
        v.flap[D.i] = t >= T.drop[0] && t < T.hop[0] + 0.1;
      }
      v.t = t;
      return v;
    }

    function frame() {
      const v = view();
      look.update(v);
      // coin chip pop when the shown number drops
      const ce = look.coinEl && look.coinEl();
      if (ce) {
        const n = ce.querySelector('.n');
        const txt = S.nosave ? '?' : String(v.coins);
        if (n && n.textContent !== txt) { n.textContent = txt; if (lastCoins !== null && !(D && D.frozenT != null)) { ce.classList.remove('pop'); void ce.offsetWidth; ce.classList.add('pop'); } }
        lastCoins = v.coins;
      }
      if (!D) { coin.style.display = 'none'; capWhole.style.display = capTop.style.display = capBot.style.display = 'none'; flash.style.opacity = 0; return; }
      const t = v.t;
      const C = look.center;
      if (P.rm) {
        const k = seg(t, [0, RM_END]);
        shade.style.opacity = 0.68 * k; rv.style.opacity = k;
        coin.style.display = 'none'; capWhole.style.display = capTop.style.display = capBot.style.display = 'none';
        RV.rays.style.display = 'none';
        for (const e of [RV.med, RV.fig, RV.name, RV.aisle, RV.stock, RV.newb, RV.ok, RV.tip]) { e.style.transform = 'none'; e.style.opacity = 1; }
        RV.ok.style.visibility = 'visible';
        landing(t);
        return;
      }
      // 1. coin flies from the coin chip to the slot
      const kc = seg(t, T.coin);
      if (kc > 0 && kc < 1 && look.coinEl) {
        const r = look.coinEl().getBoundingClientRect(); const sr = stage.getBoundingClientRect();
        const from = { x: r.left - sr.left + 16, y: r.top - sr.top + 8 }; const to = look.slot(D.i);
        coin.style.display = 'block';
        const x = lerp(from.x, to.x, kc), y = lerp(from.y, to.y, kc) - Math.sin(kc * Math.PI) * 110;
        coin.style.left = snap(x - 14) + 'px'; coin.style.top = snap(y - 14) + 'px';
        coin.style.transform = `scale(${kc > 0.85 ? 1 - (kc - 0.85) * 4 : 1})`;
      } else coin.style.display = 'none';
      // 2-5. capsule: drop at the chute, hop to the centre, shake, pop
      const ch = look.chute(D.i);
      capWhole.style.display = 'none'; capTop.style.display = 'none'; capBot.style.display = 'none';
      shade.style.opacity = 0.68 * seg(t, T.hop);
      if (t >= T.drop[0] && t < T.pop[0]) {
        capWhole.style.display = 'block';
        let x = ch.x, y = ch.y, s = 1, rot = 0;
        if (t < T.hop[0]) {
          const k = seg(t, T.drop);
          y = ch.y - 26 + 26 * (k < 0.6 ? inQuad(k / 0.6) : 1) - (k >= 0.6 ? Math.sin((k - 0.6) / 0.4 * Math.PI) * 8 : 0);
        } else if (t < T.shake[0]) {
          const k = outQuad(seg(t, T.hop));
          x = lerp(ch.x, C.x, k); y = lerp(ch.y, C.y - 70, k) - Math.sin(k * Math.PI) * 90; s = lerp(1, 3, k);
          rot = k * 360;
        } else {
          x = C.x; y = C.y - 70; s = 3;
          const k = seg(t, T.shake);
          rot = (Math.floor(k * 10) % 2 ? 1 : -1) * (6 + k * 8);
          x += (Math.floor(k * 10) % 2 ? 2 : -2);
        }
        capWhole.style.left = snap(x - 16) + 'px'; capWhole.style.top = snap(y - 16) + 'px';
        capWhole.style.transform = `scale(${s}) rotate(${Math.round(rot / 15) * 15}deg)`;
      }
      if (t >= T.pop[0] && t < T.rise[1] + 0.2) {
        const k = seg(t, [T.pop[0], T.rise[1] + 0.2]);
        capTop.style.display = capBot.style.display = 'block';
        capTop.style.left = C.x - 16 + 'px'; capTop.style.top = snap(C.y - 70 - 16 - 80 * outQuad(k)) + 'px';
        capTop.style.transform = `scale(3) rotate(${-Math.round(k * 4) * 15}deg)`; capTop.style.opacity = 1 - k;
        capBot.style.left = C.x - 16 + 'px'; capBot.style.top = snap(C.y - 70 - 16 + 70 * outQuad(k)) + 'px';
        capBot.style.transform = `scale(3) rotate(${Math.round(k * 3) * 15}deg)`; capBot.style.opacity = 1 - k;
      }
      const kf = seg(t, [T.pop[0], T.pop[1] + 0.12]);
      flash.style.left = C.x - 60 + 'px'; flash.style.top = C.y - 70 - 60 + 'px';
      flash.style.opacity = kf > 0 && kf < 1 ? 1 - kf : 0; flash.style.transform = `scale(${0.4 + kf * 1.4})`;
      // 6. reveal: figurine rises, name label slaps, aisle and stock line, NEW burst
      rv.style.opacity = t >= T.pop[0] ? 1 : 0;
      const kr = seg(t, T.rise);
      RV.fig.style.transform = `scale(${t < T.pop[0] ? 0 : Math.max(0.3, outBack(seg(t, [T.pop[0] + 0.05, T.rise[1]])))})`;
      RV.rays.style.opacity = seg(t, [T.pop[0], T.rise[1]]);
      RV.med.style.transform = RV.fig.style.transform;
      RV.rays.style.transform = `rotate(${Math.round(Math.max(0, t - T.pop[0]) * 24 / 3) * 3}deg)`;
      const slap = (e, a0) => { const k = seg(t, [a0, a0 + 0.12]); e.style.opacity = k > 0 ? 1 : 0; e.style.transform = `scale(${k > 0 ? lerp(1.45, 1, outQuad(k)) : 1})`; };
      slap(RV.name, T.rise[0] + 0.06);
      slap(RV.newb, T.rise[0] + 0.2);
      RV.newb.style.transform += ' rotate(10deg)';
      const ka = seg(t, [T.rise[0] + 0.14, T.rise[1]]);
      RV.aisle.style.opacity = ka; RV.stock.style.opacity = ka; RV.aisle.style.transform = RV.stock.style.transform = `translateY(${snap((1 - ka) * 10)}px)`;
      RV.stock.style.transform += ' rotate(-2deg)';
      RV.ok.style.opacity = t >= T.end ? 1 : 0; RV.tip.style.opacity = t >= T.end ? 1 : 0;
      landing(t);
    }
    // look C: after OK the figurine flies into its cubby
    function landing() {
      if (!look.afterOk || !D) return;
      let k = null;
      if (P.land !== null && D.frozenT != null) k = P.land;
      else if (D.okAt !== null) k = (performance.now() - D.okAt) / 1000;
      if (k === null) return;
      const done = look.afterOk(D.i, D.item, P.rm ? 1 : Math.min(1, k / 0.5), RV, shade);
      if (done && D.frozenT == null) { D = null; rv.style.opacity = 0; rv.innerHTML = ''; shade.style.opacity = 0; }
    }
    function loop() { frame(); requestAnimationFrame(loop); }

    if (P.draw !== null && P.t !== null) start(P.draw, P.t);
    frame();
    if (!(P.draw !== null && P.t !== null)) requestAnimationFrame(loop);
    return { S, start, isBusy: () => !!D, view };
  }

  // shared hover tooltip for figurines
  function tooltip(stage) {
    const tip = el('div', 'tooltip', stage); tip.style.display = 'none';
    return {
      show(name, a, x, y) { tip.innerHTML = `${name}<small>${glyph(a)}${a.name}</small>`; tip.style.display = 'block'; tip.style.left = x + 'px'; tip.style.top = y + 'px'; },
      hide() { tip.style.display = 'none'; },
    };
  }

  return { P, AISLES, TOTAL, SPRITES, COIN_SVG, WORDS, T, canvas, R, disc, box, capsule, handle, pile, el, glyph, figure, coinChip, note, engine, nextItem, tooltip, initialState, snap };
})();
