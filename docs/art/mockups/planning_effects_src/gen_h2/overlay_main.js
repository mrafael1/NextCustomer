// ================= #71 planning effects, hybrid H2 "stickers + pipes" (display coordinates, after the mirror pass) =================
// Motion hints for the game (not in this still): stickers slap on with a 2-frame squash when the row changes (bottom first, so
// the stack builds in apply order), the halo steps out one ring per 80 ms, the price burst pops last; nothing loops while planning.
// On hover the giver's pipe swells from 2 px to 6 px core in two steps, flowing from the knob out to each drop.
// In Godot: one EffectPipes node drawing on the 2 px grid (or 9-sliced pipe pieces), factor plates as NinePatchRect + Label,
// stickers as a VBox of small sticker scenes anchored to the item's right side, bottom up.

// ---------- pixel painter for pipes and plates (stage px predicates -> 2 px texels on a full-stage canvas) ----------
function ovCanvas(z) { const c = document.createElement('canvas'); c.width = 640; c.height = 360; c.className = 'px';
  Object.assign(c.style, { position: 'absolute', left: 0, top: 0, width: '1280px', height: '720px', zIndex: z, pointerEvents: 'none' });
  stage.appendChild(c); return c.getContext('2d'); }
function paint(g, inside, box, o) {
  const PD = 6, i0 = Math.floor(box[0] / 2) - PD, j0 = Math.floor(box[1] / 2) - PD, W = Math.ceil(box[2] / 2) + PD - i0, H = Math.ceil(box[3] / 2) + PD - j0;
  const m = new Uint8Array(W * H), at = (i, j) => i >= 0 && j >= 0 && i < W && j < H && m[j * W + i] === 1;
  for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) if (inside((i0 + i) * 2 + 1, (j0 + j) * 2 + 1)) m[j * W + i] = 1;
  const ring = (i, j) => !at(i, j) && (at(i - 1, j) || at(i + 1, j) || at(i, j - 1) || at(i, j + 1));
  for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) {
    let col = null;
    if (at(i, j)) {
      col = o.fill;
      if (o.lit && (!at(i, j - 1) || !at(i - 1, j))) col = o.lit;
      if (o.shade && (!at(i, j + 1) || !at(i + 1, j))) col = o.shade;
      if (o.core && o.core(i0 + i, j0 + j)) col = o.core(i0 + i, j0 + j);
    } else if (ring(i, j)) col = o.ink;
    else if (o.shadow && (at(i - 1, j - 1) || ring(i - 1, j - 1))) col = o.shadow;
    if (col) { g.fillStyle = col; g.fillRect(i0 + i, j0 + j, 1, 1); }
  }
}
function segDist(x, y, a, b) { const dx = b[0] - a[0], dy = b[1] - a[1], LL = dx * dx + dy * dy;
  const t = LL ? Math.max(0, Math.min(1, ((x - a[0]) * dx + (y - a[1]) * dy) / LL)) : 0; return Math.hypot(x - a[0] - t * dx, y - a[1] - t * dy); }
function rounded(pts, R) {
  const out = [pts[0]];
  for (let k = 1; k < pts.length - 1; k++) { const [a, b, c] = [pts[k - 1], pts[k], pts[k + 1]];
    const u = [a[0] - b[0], a[1] - b[1]], v = [c[0] - b[0], c[1] - b[1]], lu = Math.hypot(...u), lv = Math.hypot(...v);
    const p0 = [b[0] + u[0] / lu * R, b[1] + u[1] / lu * R], p1 = [b[0] + v[0] / lv * R, b[1] + v[1] / lv * R];
    for (let s = 0; s <= 8; s++) { const t = s / 8; out.push([(1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * b[0] + t * t * p1[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * b[1] + t * t * p1[1]]); } }
  out.push(pts[pts.length - 1]); return out;
}
// a pipe is a square-section rod: distance along the axis-aligned runs (chebyshev box), so the edges stay straight pixels
const onPath = (paths, hw) => (x, y) => paths.some(p => { for (let k = 0; k < p.length - 1; k++) if (segDist(x, y, p[k], p[k + 1]) <= hw) return true; return false; });
const arrowAt = (tx, tip, hw, h) => (x, y) => y <= tip && y >= tip - h && Math.abs(x - tx) <= hw * (tip - y) / h + .01;
const plate = (cx, cy, w, h, cut = 2) => (x, y) => { const l = cx - w / 2, t = cy - h / 2, r = l + w, b = t + h;
  if (x < l || x >= r || y < t || y >= b) return false; return !((x < l + cut || x >= r - cut) && (y < t + cut || y >= b - cut)); };
const disc = (cx, cy, r) => (x, y) => Math.hypot(x - cx, y - cy) <= r;

// ---------- ticket price (from B): base struck, final pay on a gold starburst or a punched tomato tag ----------
const snap = v => Math.round(v / 2) * 2;
function svgIn(parent, w, h) { const s = document.createElementNS(NS, 'svg'); s.setAttribute('width', w + 6); s.setAttribute('height', h + 6);
  s.setAttribute('viewBox', `0 0 ${w + 6} ${h + 6}`); s.setAttribute('shape-rendering', 'crispEdges'); parent.appendChild(s); return s; }
function burst(i, text, o = {}) {
  const w = o.w || 58, h = o.h || 30, x = TX(i) + 112 - w + 10, y = 428 - (o.up || 6);
  const d = el('pstk', { left: x + 'px', top: y + 'px', width: w + 'px', height: h + 'px' });
  const s = svgIn(d, w, h), N = Math.round(w / 5), cx = w / 2, cy = h / 2;
  const pts = (rx, ry, dr) => Array.from({ length: N * 2 }, (_, k) => { const a = Math.PI * k / N - Math.PI / 2, r = k % 2 ? 1 - dr : 1;
    return [snap(cx + Math.cos(a) * rx * r), snap(cy + Math.sin(a) * ry * r)]; });
  const Pp = (p, fill, extra, dx = 0) => poly(s, p.map(([a, b]) => [a + dx, b + dx]), fill, extra);
  Pp(pts(w / 2, h / 2, .2), 'rgba(30,18,10,.42)', {}, 3);
  Pp(pts(w / 2, h / 2, .2), '#e2b33c', { stroke: INK, 'stroke-width': 2, 'stroke-linejoin': 'miter' });
  Pp(pts(w / 2 - 7, h / 2 - 6, .08), '#f1d27a');
  el('t', { top: (h / 2 - 11) + 'px', fontSize: (o.fs || 19) + 'px', lineHeight: '22px', left: '2px' }, text, d);
  return d;
}
const TRI7 = ['...C...', '..CCC..', '..C.C..', '.CC.CC.', '.C...C.', 'CC...CC', 'CCCCCCC'];
function deny(i, text, glyph) {
  const w = 52, h = 26, x = TX(i) + 112 - w + 6, y = 428 - 4;
  const d = el('pstk z', { left: x + 'px', top: y + 'px', width: w + 'px', height: h + 'px' });
  const s = svgIn(d, w, h), n = 4, sh = [[n, 0], [w - n, 0], [w, n], [w, h - n], [w - n, h], [n, h], [0, h - n], [0, n]];
  poly(s, sh.map(([a, b]) => [a + 3, b + 3]), 'rgba(30,18,10,.42)');
  poly(s, sh, '#d9534f', { stroke: INK, 'stroke-width': 2 });
  rect(s, 2, 2, w - 4, 2, '#ec7d75'); rect(s, 2, h - 4, w - 4, 2, '#a83a3c');
  glyph.forEach((r, j) => [...r].forEach((ch, k) => { if (ch === 'C') rect(s, 7 + k * 2, 6 + j * 2, 2, 2, '#fbf7ee'); }));
  el('t', { top: '1px', left: '18px', fontSize: '17px', lineHeight: '24px' }, text, d);
  return d;
}
const strk = p => `<span class="strk">${p}</span>`;

// ---------- the row: slot 0 next to the register ----------
const LIFT = 6;
const tk = [];
tk[0] = label('label', TX(0), 428, '€1', '×2 next Food');
tk[1] = label('label', TX(1), 428, strk('€5'), 'Food · Breakfast');
tk[2] = label('label', TX(2), 428, strk('€4'), '+1 per earlier Breakfast');
tk[3] = label('label cp' + (HOVER ? ' sel' : ''), TX(3), 428, 'COUPON', '×3 later with prior’s tag');
[4, 5, 6].forEach(i => { tk[i] = label('label', TX(i), 428, strk('€4'), '+1 per earlier Breakfast'); });

const dimmed = [];           // steps back on hover (unrelated to the Multipack)
const soft = [];             // the targets' other stickers: half back on hover
const hot = [];              // the Multipack's stickers on its targets
// 0 Eggs: a giver (its pipe says so); pays its ticket
const eggs = itemD(0, `${A}items_v2/eggs.png`);
// 1 Bread: x2 from Eggs -> EUR 10
const bread = itemD(1, null, { canvas: breadCanvas(), lift: LIFT, cls: 'h1' });
dimmed.push(sticker(IX(1) + 64, 330, 'mul', '×2', 'eggs', -7));
dimmed.push(burst(1, '€10', { w: 54, h: 28, fs: 17, up: 4 }));
// 2 Milk: denied by Spot check -> EUR 0
const milk3 = itemD(2, `${A}items_v2/milk.png`, { cls: 'denied' });
dimmed.push(stamp(IX(2) + 0, 322));
dimmed.push(deny(2, '€0', TRI7));
// 3 Multipack: gives x3; its own pay fizzled (Coupon engine): a grey "pfff" sticker with the loyalty disc
const cpLift = HOVER ? 16 : 0;
itemD(3, `${A}items_v2/coupon_slip.png`, { lift: cpLift, base: 16, icon: `${A}icons/coupon_multipack_v2.png` });
{ const f = sticker(IX(3) + 72, 318 - cpLift, 'fz', 'pfff', 'coupon', 5); f.classList.add('fzs'); }
deny(3, '€0', FIZZLE7);
if (HOVER) [['l', 't'], ['r', 't'], ['l', 'b'], ['r', 'b']].forEach(([h, v]) => {
  const x = IX(3);
  el('abs brk', { left: (h === 'l' ? x - 16 : x + 96) + 'px', top: (v === 't' ? ground - 112 : ground - 4) + 'px',
    borderLeftWidth: h === 'l' ? '4px' : 0, borderRightWidth: h === 'r' ? '4px' : 0, borderTopWidth: v === 't' ? '4px' : 0, borderBottomWidth: v === 'b' ? '4px' : 0 });
});
// 4-6 Milk: own "+1 per earlier Breakfast", the Multipack's x3, and on slot 6 two upgrades (Slot engine +12, Category engine x2)
const milks = [
  [4, 'h2', [['add', '+3', null], ['mul', '×3', 'pack']], '€21', { w: 60, h: 32 }],
  [5, 'h2', [['add', '+4', null], ['mul', '×3', 'pack']], '€24', { w: 60, h: 32 }],
  [6, 'h3', [['add', '+5', null], ['add', '+12', 'slot'], ['mul', '×3', 'pack'], ['mul', '×2', 'tag']], '€126', { w: 80, h: 36, fs: 22, up: 10 }],
];
milks.forEach(([i, h, sts, pay, bo]) => {
  itemD(i, `${A}items_v2/milk.png`, { lift: LIFT, cls: h });
  // the column hugs the carton's right side, bottom-anchored on the belt, each sticker overlapping the one under it by 8 px
  // like stickers slapped on a box; the first applied is on top, so the column reads top to bottom as the sum
  let y = ground - 2; const tilts = [-4, 3, -3, 4, -2];
  [...sts].reverse().forEach(([k, txt, b], n) => {
    const hgt = k === 'mul' ? 34 : 28; y -= hgt; const yy = y; y += 8;
    const idx = sts.length - 1 - n;
    const d = sticker(IX(i) + 62 + (idx % 2 ? 4 : 0), yy, k, txt, b, tilts[idx]);
    d.style.zIndex = 14 - idx;   // the upper sticker overlaps the lower one, so every number stays whole
    (b === 'pack' ? hot : soft).push(d);
  });
  burst(i, pay, bo);
});
sparkle(IX(6) + 4, 304); sparkle(IX(6) + 120, 262); sparkle(IX(6) - 8, 352);

// ---------- pipes: giver knob -> run under the monitor -> drop onto each target, the factor riding above each drop ----------
const pipes = ovCanvas(6);
const RAIL = 264;
const CX = i => IX(i) + 48;
const TOPY = { 0: 300, 1: 314, 3: 330 - cpLift, 4: 292, 5: 292, 6: 292 };   // visible top of each item (after its lift)
const GIVERS = [
  { from: 0, to: [1], f: '×2', gain: ['+€5'] },
  { from: 3, to: [4, 5, 6], f: '×3', gain: ['+€14', '+€16', '+€84'] },
];
const COL = { gold: '#e2b33c', lit: '#f1d27a', dark: '#b8892a', quiet: '#b9b5ab', quietLit: '#cfcbc1' };
GIVERS.forEach(g => {
  const bold = HOVER && g.from === 3, quiet = HOVER && !bold;
  const hw = bold ? 3 : 1, sx = CX(g.from), last = CX(g.to[g.to.length - 1]);
  const knobY = TOPY[g.from] - (bold ? 8 : 6), kr = bold ? 9 : 7;
  const main = rounded([[sx, knobY], [sx, RAIL], [last, RAIL], [last, TOPY[g.to[g.to.length - 1]] - 10]], bold ? 12 : 10);
  const drops = g.to.slice(0, -1).map(d => [[CX(d), RAIL], [CX(d), TOPY[d] - 10]]);
  const aw = bold ? 9 : 6, ah = bold ? 9 : 7;
  const heads = g.to.map(d => arrowAt(CX(d), TOPY[d] - 1, aw, ah));
  const knob = disc(sx, knobY, kr);
  const inside = (x, y) => onPath([main, ...drops], hw)(x, y) || heads.some(h => h(x, y)) || knob(x, y);
  const box = [sx - 24, RAIL - 24, last + 24, Math.max(...g.to.map(d => TOPY[d]), knobY + kr) + 4];
  paint(pipes, inside, box, quiet ? { fill: COL.quiet, ink: 'rgba(43,36,32,.55)' }
    : bold ? { fill: COL.gold, lit: COL.lit, shade: COL.dark, ink: INK, shadow: 'rgba(20,12,6,.5)' }
    : { fill: COL.gold, ink: INK, shadow: 'rgba(20,12,6,.3)' });
  // the knob's mouth: a dark socket where the pipe plugs into the giver
  paint(pipes, disc(sx, knobY, bold ? 4 : 3), [sx - 8, knobY - 8, sx + 8, knobY + 8], { fill: quiet ? '#8d897f' : '#7a5a10', ink: quiet ? 'rgba(43,36,32,.55)' : INK });
  // the factor plate riding the pipe over each drop; hovered: a paper chip beside it says what that drop adds
  g.to.forEach((d, n) => {
    const cx = CX(d), w = bold ? 44 : 30, h = bold ? 28 : 20;
    paint(pipes, plate(cx, RAIL, w, h, 2), [cx - w, RAIL - h, cx + w, RAIL + h],
      quiet ? { fill: '#d8d4ca', ink: 'rgba(43,36,32,.55)' }
      : bold ? { fill: COL.gold, lit: COL.lit, shade: COL.dark, ink: INK, shadow: 'rgba(20,12,6,.5)' }
      : { fill: '#f1d27a', lit: '#faecbc', ink: INK, shadow: 'rgba(20,12,6,.35)' });
    el('ptok', { left: (cx - w / 2) + 'px', top: (RAIL - h / 2) + 'px', width: w + 'px', height: h + 'px', fontSize: (bold ? 19 : 14) + 'px',
      opacity: quiet ? .5 : 1 }, g.f);
    if (bold) el('pgain', { left: (cx + w / 2 + 4) + 'px', top: (RAIL - 10) + 'px' }, g.gain[n]);
  });
});

if (HOVER) {
  [eggs, bread, milk3].forEach(d => d.classList.add('dimi'));
  [0, 1, 2].forEach(i => tk[i].classList.add('dimt'));
  dimmed.forEach(d => d.classList.add('dim'));
  hot.forEach(d => d.classList.add('hot'));
}
