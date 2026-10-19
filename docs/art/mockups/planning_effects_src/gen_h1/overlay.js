// ================= #71 planning effects, hybrid h1 (drawn after the mirror pass, display coordinates) =================
// Reading order for a new player, top to bottom on one slot: the stickers on the item (what it receives, in apply order, each
// with the giver's badge), the ticket (base struck, the real pay on a starburst), and along the belt lip the rail strip that
// says who gives what to whom (giver's name at its start, a factor badge dropping onto each target).
// Motion notes (not in the still): stickers slap on with a 2-frame squash when the row changes; the halo steps out one ring per
// 80 ms; the strip's chevrons step one texel toward the targets once; nothing loops while planning. On hover the hovered item's
// strip brightens and gains its ring, the gains drop onto the strip, and everything unrelated fades to a third.
(() => {
const SL = k => 368 + (k - 1) * 128, TW = 112, TT = 428, G = 388, L = 6;
const GOLD = '#e2b33c', GOLD_L = '#f1d27a', GOLD_P = '#faecbc', GOLD_D = '#b8892a', GOLD_DD = '#8e6a1a';
const snap = v => Math.round(v / 2) * 2;
const S = document.createElementNS(NS, 'svg'); S.setAttribute('class', 'layer'); S.setAttribute('viewBox', '0 0 1280 720');
S.setAttribute('shape-rendering', 'crispEdges'); S.style.zIndex = 5; stage.appendChild(S);
const grp = (dim) => { const g = document.createElementNS(NS, 'g'); if (dim) g.setAttribute('opacity', '.3'); S.appendChild(g); return g; };
const PAL = {
  gold:  { fill: GOLD, lit: GOLD_L, shade: GOLD_D },
  cream: { fill: '#fbf7ee', lit: '#ffffff', shade: '#ddcba5' },
  grey:  { fill: '#c2beb4', lit: '#dcd8ce', shade: '#9a968d' },
};

// ---------- pixel painting (from direction A) ----------
function pxPaint(c, inside, p, shadow = 'rgba(20,14,10,.5)') {
  const g = c.getContext('2d'), W = c.width, H = c.height;
  const ins = (i, j) => i >= 0 && j >= 0 && i < W && j < H && inside(i, j);
  const edge = (i, j) => ins(i, j) && !(ins(i - 1, j) && ins(i + 1, j) && ins(i, j - 1) && ins(i, j + 1));
  const dot = (i, j, col) => { g.fillStyle = col; g.fillRect(i, j, 1, 1); };
  for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) {
    if (!ins(i, j)) { if (shadow && ins(i - 1, j - 1)) dot(i, j, shadow); continue; }
    if (edge(i, j)) dot(i, j, INK);
    else if (edge(i - 1, j) || edge(i, j - 1)) dot(i, j, p.lit);
    else if (edge(i + 1, j) || edge(i, j + 1)) dot(i, j, p.shade);
    else dot(i, j, p.fill);
  }
  return g;
}
function tcanvas(tw, th) { const c = document.createElement('canvas'); c.width = tw; c.height = th; c.className = 'px';
  c.style.width = tw * 2 + 'px'; c.style.height = th * 2 + 'px'; return c; }
function fxBox(cls, x, y, tw, th, html, parent) {
  const d = el('fx ' + cls, parent ? { width: tw * 2 + 'px', height: th * 2 + 'px', flex: 'none' }
    : { left: snap(x) + 'px', top: snap(y) + 'px', width: tw * 2 + 'px', height: th * 2 + 'px' }, '', parent);
  const c = tcanvas(tw, th); d.appendChild(c);
  const t = document.createElement('div'); t.className = 't'; t.innerHTML = html || ''; d.appendChild(t);
  return { d, c, t };
}
function glyphCanvas(rows, cols) {
  const c = tcanvas(rows[0].length, rows.length), g = c.getContext('2d');
  rows.forEach((r, j) => [...r].forEach((ch, i) => { if (cols[ch]) { g.fillStyle = cols[ch]; g.fillRect(i, j, 1, 1); } }));
  return c;
}
// mini giver badges (2 px texels): an item's own little icon, or a loyalty stamp's disc
const BADGE = {
  eggs: () => glyphCanvas(['..CCC..', '.CWLWC.', 'CWLWWWC', 'CWWWWWC', 'CWWWWSC', 'CWWWSSC', '.CSSSC.', '..CCC..'], { C: INK, W: '#f3e9d2', L: '#ffffff', S: '#c9b48a' }),
  pack: () => glyphCanvas(['CCCCCCCCCC', 'CLLCLLCLLC', 'CTTCTTCTTC', 'CYYCYYCYYC', 'CTTCTTCTTC', 'CSSCSSCSSC', 'CCCCCCCCCC'],
    { C: INK, L: '#c7c3b8', T: '#4f9a94', Y: '#e2b33c', S: '#1f3b3a' }),
  slot: () => glyphCanvas(['..RRRRR..', '.RPPPPPR.', 'RPGGGGGPR', 'RPGPPPGPR', 'RPGPGPGPR', 'RPGPPPGPR', 'RPGGGGGPR', '.RPPPPPR.', '..RRRRR..'],
    { R: INK, P: '#2a4d4b', G: '#faecbc' }),
  tag: () => glyphCanvas(['..RRRRR..', '.RPPPPPR.', 'RPPGGGGPR', 'RPGPGGGPR', 'RPGGGGGPR', 'RPPGGGGPR', 'RPPPPPPPR', '.RPPPPPR.', '..RRRRR..'],
    { R: INK, P: '#2a4d4b', G: '#faecbc' }),
  coupon: () => glyphCanvas(['..RRRRR..', '.RPPPPPR.', 'RPPPPPPPR', 'RGGGGGGGR', 'RPGGGGGPR', 'RGGGGGGGR', 'RPPPPPPPR', '.RPPPPPR.', '..RRRRR..'],
    { R: INK, P: '#2a4d4b', G: '#faecbc' }),
};
// a received effect: '+' a cream price-gun label, 'x' a gold starburst, 'fz' a grey "pfff" label; tilt in degrees on the texel grid
function sticker(x, y, kind, text, badge, tilt, parent) {
  const mul = kind === 'mul', tw = mul ? 31 : kind === 'fz' ? 30 : (text.length > 2 ? 27 : 23), th = mul ? 17 : 14;
  const { d, t, c } = fxBox('stk ' + (kind === 'fz' ? 'fzs' : kind), x, y, tw, th, '', parent);
  const a = (tw - 1) / 2, b = (th - 1) / 2, r = (tilt || 0) * Math.PI / 180, co = Math.cos(r), si = Math.sin(r);
  pxPaint(c, (i, j) => {
    const u0 = i + .5 - a, v0 = j + .5 - b, u = u0 * co + v0 * si, v = -u0 * si + v0 * co;
    if (mul) { const nu = u / a, nv = v / b, th2 = Math.atan2(nv, nu), k = (th2 / (2 * Math.PI) * 18 + 18) % 1;
      return Math.hypot(nu, nv) <= .84 + .16 * Math.abs(k - .5) * 2; }
    return (Math.abs(u) / (a * .96)) ** 5 + (Math.abs(v) / (b * .9)) ** 5 <= 1;
  }, mul ? PAL.gold : kind === 'fz' ? PAL.grey : PAL.cream);
  if (badge) { const bc = BADGE[badge](); Object.assign(bc.style, { position: 'absolute', left: (mul ? -8 : -14) + 'px',
    top: Math.round((th * 2 - parseInt(bc.style.height)) / 4) * 2 + 'px', zIndex: 2 }); d.appendChild(bc); }
  const s = document.createElement('span'); s.textContent = text; t.appendChild(s);
  return d;
}
// a stack of received effects on an item, in apply order top to bottom, bottom-anchored just above the belt lip and growing
// upward (over the item, then the back wall); each overlaps the one above by 6 px, alternately nudged, like slapped stickers
function stack(k, list, o = {}) {
  const out = []; let y = o.bottom || (G - L - 2); const tilts = [-4, 3, -3, 4, -2];
  [...list].reverse().forEach(([kd, txt, b], n) => {
    const idx = list.length - 1 - n, hgt = kd === 'mul' ? 34 : 28;
    y -= hgt;
    const d = sticker(SL(k) + 8 + (o.dx || 60) + (idx % 2 ? 4 : 0), y, kd, txt, b, tilts[idx % 5]);
    d.style.zIndex = 7 + idx; out.push({ d, b, kd });
    y += 6;
  });
  return out;
}
// the denied item's rubber stamp, tilted on the texel grid
function stamp(x, y) {
  const tw = 48, th = 34, { d, c } = fxBox('stamp71', x, y, tw, th, '<span class="big">€0</span><span class="sm">SPOT CHECK</span>');
  const g = c.getContext('2d'), a = (tw - 1) / 2, b = (th - 1) / 2, r = -9 * Math.PI / 180, co = Math.cos(r), si = Math.sin(r);
  for (let j = 0; j < th; j++) for (let i = 0; i < tw; i++) {
    const u0 = i + .5 - a, v0 = j + .5 - b, u = Math.abs(u0 * co + v0 * si), v = Math.abs(-u0 * si + v0 * co), A2 = a - 2, B2 = b - 4;
    if (u > A2 || v > B2) continue;
    const ring = u > A2 - 1 || v > B2 - 1, ring2 = !ring && (u > A2 - 3 && u <= A2 - 2);
    g.fillStyle = ring || ring2 ? '#a83a3c' : 'rgba(251,247,238,.88)'; g.fillRect(i, j, 1, 1);
  }
  return d;
}
function sparkle(x, y) { const c = glyphCanvas(['..C..', '..C..', 'CCWCC', '..C..', '..C..'], { C: GOLD_L, W: '#ffffff' });
  Object.assign(c.style, { position: 'absolute', left: x + 'px', top: y + 'px', zIndex: 4 }); stage.appendChild(c); return c; }
function itemD(k, src, o = {}) {
  const x = SL(k) + 8, lift = o.lift || 0, w = 74, sw = lift ? Math.round(w * .82) : w;
  const sh = pxShadow(x + 48 - sw / 2 + 6, G - (lift ? 9 : 10), sw, lift ? 12 : 14, 3, lift ? .32 : .5);
  const d = el('item ' + (o.cls || ''), { left: x + 'px', top: (G - 96 - lift + (o.base || 0)) + 'px', zIndex: 3 });
  if (o.canvas) d.appendChild(o.canvas); else d.innerHTML = `<img class="px" src="${src}">`;
  if (o.icon) d.insertAdjacentHTML('beforeend', `<img class="px slipicon" src="${o.icon}">`);
  d._sh = sh; return d;
}
function breadCanvas() {
  const c = document.createElement('canvas'); c.width = 48; c.height = 48; c.className = 'px'; c.style.width = '96px'; c.style.height = '96px';
  const inside = (i, j) => (i >= 7 && i <= 40 && j >= 28 && j <= 46) || (j <= 29 && ((i + .5 - 24) / 18) ** 2 + ((j + .5 - 29) / 13) ** 2 <= 1);
  const g = pxPaint(c, inside, { fill: '#c98c4e', lit: '#e2b07a', shade: '#8a5a2e' }, null);
  g.fillStyle = '#a8703a'; for (let i = 8; i < 40; i++) { g.fillRect(i, 43, 1, 1); g.fillRect(i, 44, 1, 1); g.fillRect(i, 45, 1, 1); }
  [[13, 19], [21, 17], [29, 19]].forEach(([x, y]) => { for (let t = 0; t < 5; t++) { g.fillStyle = '#8a5a2e'; g.fillRect(x + t, y + t, 1, 1); g.fillStyle = '#f0d29c'; g.fillRect(x + t + 1, y + t, 1, 1); } });
  return c;
}

// ---------- tickets and their pay (from direction B) ----------
function ticket(k, o) {
  const cls = 'label tk' + (o.got ? ' got' : '') + (o.cp ? ' cp' : '') + (o.sel ? ' sel' : '') + (o.dim ? ' dim' : '');
  const price = `<span class="${o.strike ? 'strk' : ''}">${o.cp ? 'COUPON' : o.price}</span>`;
  return el(cls, { left: SL(k) + 'px', top: TT + 'px', zIndex: 4 },
    `<div class="p">${price}${o.aisle ? `<img class="ai2 px" src="${A}icons/aisle_${o.aisle}.png">` : ''}</div>` + (o.rule ? `<div class="r">${o.rule}</div>` : ''));
}
function svgIn(parent, w, h) { const s = document.createElementNS(NS, 'svg'); s.setAttribute('width', w + 6); s.setAttribute('height', h + 6);
  s.setAttribute('viewBox', `0 0 ${w + 6} ${h + 6}`); s.setAttribute('shape-rendering', 'crispEdges'); parent.appendChild(s); return s; }
// the real pay on a gold starburst at the ticket's top right, over the price line only (pokes a little above the ticket)
function burst(k, text, o = {}) {
  const w = o.w || 58, h = o.h || 30, x = SL(k) + TW - w + 10, y = TT - (o.up || 6);
  const d = el('pb' + (o.dim ? ' dimg' : ''), { left: x + 'px', top: y + 'px', width: w + 'px', height: h + 'px' });
  const s = svgIn(d, w, h), N = Math.round(w / 5), cx = w / 2, cy = h / 2;
  const pts = (rx, ry, dr) => Array.from({ length: N * 2 }, (_, i) => { const a = Math.PI * i / N - Math.PI / 2, r = i % 2 ? 1 - dr : 1;
    return [snap(cx + Math.cos(a) * rx * r), snap(cy + Math.sin(a) * ry * r)]; });
  const P = (p, fill, extra, dx = 0) => poly(s, p.map(([a, b]) => [a + dx, b + dx]), fill, extra);
  P(pts(w / 2, h / 2, .2), 'rgba(30,18,10,.42)', {}, 3);
  P(pts(w / 2, h / 2, .2), GOLD, { stroke: INK, 'stroke-width': 2, 'stroke-linejoin': 'miter' });
  P(pts(w / 2 - 7, h / 2 - 6, .08), GOLD_L);
  el('t', { top: (h / 2 - 11) + 'px', fontSize: (o.fs || 19) + 'px', lineHeight: '22px', left: '2px' }, text, d);
  return d;
}
// a punched tomato tag with the fizzle glyph: the item pays nothing
function deny(k, text, o = {}) {
  const w = 52, h = 26, x = SL(k) + TW - w + 6, y = TT - 4;
  const d = el('pb z' + (o.dim ? ' dimg' : ''), { left: x + 'px', top: y + 'px', width: w + 'px', height: h + 'px' });
  const s = svgIn(d, w, h), n = 4, sh = [[n, 0], [w - n, 0], [w, n], [w, h - n], [w - n, h], [n, h], [0, h - n], [0, n]];
  poly(s, sh.map(([a, b]) => [a + 3, b + 3]), 'rgba(30,18,10,.42)');
  poly(s, sh, '#d9534f', { stroke: INK, 'stroke-width': 2 });
  rect(s, 2, 2, w - 4, 2, '#ec7d75'); rect(s, 2, h - 4, w - 4, 2, '#a83a3c');
  FIZZLE7.forEach((r, j) => [...r].forEach((ch, i) => { if (ch === 'C') rect(s, 7 + i * 2, 6 + j * 2, 2, 2, '#fbf7ee'); }));
  el('t', { top: '1px', left: '18px', fontSize: '17px', lineHeight: '24px' }, text, d);
  return d;
}

// ---------- the rail strip: who gives what to whom ----------
// A brass strip on the belt lip (y 396..412, between the items' feet and the tickets' tops): a plug over the giver's ticket, the
// giver's name, chevrons toward the targets, and at each target a factor badge with a notch dropping onto its ticket. The rail
// gaps between the tickets it spans are lit too, so the run reads as one piece of the register. Calm: brass. Hot: gold + ring.
function strip(src, targets, factor, name, o = {}) {
  const g = grp(o.dim), hot = !!o.hot, last = targets[targets.length - 1];
  const fill = hot ? GOLD : GOLD_D, lit = hot ? GOLD_P : GOLD, shade = hot ? GOLD_D : GOLD_DD, chevC = hot ? GOLD_D : '#6e5214';
  const y0 = 396, H = 16, x0 = SL(src) + 6, bx = targets.map(t => SL(t) + 26), x1 = bx[bx.length - 1] + 28;
  for (let k = src; k < last; k++) { const gx = SL(k) + TW + 2;   // the steel gaps of the rail between the spanned tickets
    rect(g, gx, 424, 12, 64, hot ? GOLD : GOLD_D); rect(g, gx, 424, 12, 4, lit); rect(g, gx, 482, 12, 6, shade);
    if (hot) [436, 452, 468].forEach(yy => rect(g, gx + 4, yy, 4, 4, GOLD_P)); }
  if (hot) { rect(g, x0 - 6, y0 - 6, x1 - x0 + 12, H + 12, INK); rect(g, x0 - 4, y0 - 4, x1 - x0 + 8, H + 8, GOLD_P); }
  rect(g, x0 + 2, y0 + 2, x1 - x0, H, 'rgba(20,12,8,.5)');
  rect(g, x0, y0, x1 - x0, H, fill); rect(g, x0, y0, x1 - x0, 2, lit); rect(g, x0, y0 + H - 4, x1 - x0, 2, shade);
  rect(g, x0, y0, x1 - x0, H, 'none', { stroke: INK, 'stroke-width': 2 });
  // the end: a pointed cap, so the strip reads as going right (scanned later)
  poly(g, [[x1, y0 - 1], [x1 + 8, y0 + H / 2], [x1, y0 + H + 1]], INK); poly(g, [[x1 - 1, y0 + 3], [x1 + 4, y0 + H / 2], [x1 - 1, y0 + H - 3]], fill);
  // the plug: an ink block on the strip's start with a lit pip, and a stem down onto the giver's ticket
  rect(g, x0 - 2, y0 - 2, 12, H + 4, INK); rect(g, x0 + 2, y0 + 3, 4, 8, hot ? GOLD_P : GOLD_L);
  rect(g, x0 + 1, y0 + H + 2, 6, TT - y0 - H - 2, INK); rect(g, x0 + 3, y0 + H + 2, 2, TT - y0 - H - 2, fill);
  // the giver's name, printed in pale gold on an ink plate at the strip's start (the plug grows into it)
  const nm = el('cname' + (o.dim ? ' dimg' : ''), { left: (x0 + 14) + 'px', top: (y0 + 1) + 'px', color: hot ? '#fbf7ee' : GOLD_P }, name);
  const nameEnd = snap(x0 + 14 + nm.offsetWidth + 6);
  rect(g, x0, y0, nameEnd - x0, H, INK); rect(g, nameEnd, y0, 2, H, hot ? GOLD_P : GOLD_L);
  for (let cx = snap(nameEnd + 8); cx < x1 - 12; cx += 16) if (bx.every(b => cx < b - 30 || cx > b + 26)) {
    [[0, 0], [2, 2], [4, 4], [2, 6], [0, 8]].forEach(([dx, dy]) => rect(g, cx + dx, y0 + 3 + dy, 2, 2, chevC)); }
  bx.forEach((cx, i) => {
    poly(g, [[cx - 8, y0 + H + 2], [cx + 8, y0 + H + 2], [cx + 1, TT], [cx - 1, TT]], INK);
    poly(g, [[cx - 4, y0 + H + 2], [cx + 4, y0 + H + 2], [cx, y0 + H + 6]], hot ? GOLD_P : GOLD_L);
    el('fb' + (hot ? ' big' : '') + (o.dim ? ' dimg' : ''), { left: (cx - 20) + 'px', top: (hot ? y0 - 6 : y0 - 4) + 'px', width: '40px' }, factor);
    if (hot && o.amts) el('fb amt', { left: (cx + 26) + 'px', top: (y0 - 3) + 'px' }, o.amts[i]);
  });
}

// ================= the row (slot 1 next to the register) =================
const other = [], dimItems = [];
// 1 Eggs: a giver, pays its base
dimItems.push(itemD(1, `${A}items_v2/eggs.png`));
// 2 Bread: x2 from Eggs -> EUR 10
dimItems.push(itemD(2, null, { canvas: breadCanvas(), lift: L, cls: 'h1' }));
stack(2, [['mul', '×2', 'eggs']], { dx: 54 }).forEach(s => other.push(s.d));
// 3 Milk: denied by Spot check
dimItems.push(itemD(3, `${A}items_v2/milk.png`, { cls: 'denied' }));
other.push(stamp(SL(3) + 8, 318));
// 4 Multipack: the Coupon engine made it pay nothing; gives x3 to the 3 Milks
const cpLift = HOVER ? 16 : 0;
itemD(4, `${A}items_v2/coupon_slip.png`, { lift: cpLift, base: 16, icon: `${A}icons/coupon_multipack_v2.png` });
const fzs = sticker(SL(4) + 8 + 66, 312 - cpLift, 'fz', 'pfff', 'coupon', -5);
// 5-7 Milk: own "+1 per earlier Breakfast", the Multipack's x3, and on slot 7 two loyalty stamps (Slot engine +12, Category engine x2)
const milks = [
  [5, 'h2', [['add', '+3', null], ['mul', '×3', 'pack']]],
  [6, 'h2', [['add', '+4', null], ['mul', '×3', 'pack']]],
  [7, 'h3', [['add', '+5', null], ['add', '+12', 'slot']].concat(location.search.includes('stress') ? [['add', '+2', 'eggs']] : []).concat([['mul', '×3', 'pack'], ['mul', '×2', 'tag']])],
];
milks.forEach(([k, h, sts]) => {
  itemD(k, `${A}items_v2/milk.png`, { lift: L, cls: h });
  stack(k, sts).forEach(s => { if (s.b !== 'pack') other.push(s.d); });
});
sparkle(SL(7) + 12, 300); sparkle(SL(7) + 86, 262); sparkle(SL(2) + 8, 330);

// tickets
ticket(1, { price: '€1', rule: '×2 next Food', dim: HOVER });
ticket(2, { price: '€5', rule: 'Food · Breakfast', aisle: 'bakery', strike: true, dim: HOVER });
ticket(3, { price: '€4', rule: '+1 per earlier Breakfast', strike: true, dim: HOVER });
ticket(4, { cp: true, rule: '×3 later with prior’s tag', sel: HOVER });
[5, 6, 7].forEach(k => ticket(k, { price: '€4', rule: '+1 per earlier Breakfast', strike: true, got: HOVER }));
burst(2, '€10', { w: 54, h: 28, fs: 17, up: 4, dim: HOVER });   // pays step back with their ticket
deny(3, '€0', { dim: HOVER });
deny(4, '€0');
burst(5, '€21', { w: 60, h: 32 }); burst(6, '€24', { w: 60, h: 32 }); burst(7, '€126', { w: 80, h: 36, fs: 22, up: 10 });

// rail strips (cross-item gifts)
strip(1, [2], '×2', 'EGGS', { dim: HOVER });
strip(4, [5, 6, 7], '×3', 'MULTIPACK', { hot: HOVER, amts: ['+€14', '+€16', '+€84'] });

// calm monitor: a one-line key to the stickers
const lg = document.getElementById('legend');
if (lg) {
  const add = (fn, text) => { const w = el('lg', {}, '', lg); fn(w); w.insertAdjacentHTML('beforeend', `<span>${text}</span>`); };
  add(w => sticker(0, 0, 'add', '+3', null, 0, w), 'own rule');
  add(w => { const d = sticker(0, 0, 'mul', '×3', 'pack', 0, w); d.style.marginLeft = '8px'; }, 'from an item');
  add(w => { const d = sticker(0, 0, 'add', '+12', 'slot', 0, w); d.style.marginLeft = '14px'; }, 'loyalty');
}

if (HOVER) {
  other.forEach(d => d.classList.add('dim'));
  dimItems.forEach(d => { d.classList.add('away'); d._sh.style.opacity = .4; });
  const x = SL(4) + 8;
  [['l', 't'], ['r', 't'], ['l', 'b'], ['r', 'b']].forEach(([h, v]) => {
    el('abs brk', { left: (h === 'l' ? x - 16 : x + 96) + 'px', top: (v === 't' ? G - 112 : G - 22) + 'px',
      borderLeftWidth: h === 'l' ? '4px' : 0, borderRightWidth: h === 'r' ? '4px' : 0, borderTopWidth: v === 't' ? '4px' : 0, borderBottomWidth: v === 'b' ? '4px' : 0 });
  });
  // why these targets: the prior product's tag, a teal chip on the lip under Milk 3
  el('tagchip', { left: (SL(3) + 18) + 'px', top: '398px' }, 'tag: Cold case ›');
}
})();
