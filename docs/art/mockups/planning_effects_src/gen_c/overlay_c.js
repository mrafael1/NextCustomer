// ================= planning effects, direction C "Arcs" (display coordinates, after the mirror pass) =================
// Cross-item effects are chunky pixel rails over the belt: a riser leaves the giver, runs under the monitor, and drops an
// arrow into each receiver; the factor rides on the rail in a token right above each receiver. What an item ends up with
// sits in a speech bubble at its feet, its tail pointing up into the item: the tokens it received, then what it pays.
// Calm: rails 2 px core, small tokens. Hovered giver: rails 6 px core with a hard shadow, big tokens with a stepped halo,
// a stepped light pool under each receiver, everything unrelated dimmed.
// Motion (not in this still): calm planning has no loop. On hover the giver's rail draws out from the giver to its receivers
// in about 0.15 s, each token pops 1.0 -> 1.2 -> 1.0 in 2 px steps as the rail reaches it, and the receivers' bubbles tick from
// the ticket price up to the result; on leave everything settles back to the thin calm rails.
// In Godot: one EffectArcs node (a Line2D-free custom _draw on the 2 px grid, or 9-sliced rail pieces), token and bubble
// as NinePatchRect + Label scenes.
const SLOT = d => 296 + 128 * d;                 // item centre x of display slot d
const TOP = { 1: 300, 2: 336, 3: 298, 4: HOVER ? 300 : 316, 5: 298, 6: 298, 7: 298 };   // visible top of each item
const RAIL = 264;
const GL = {   // the loyalty glyphs, 7 x 7 (same as the stamps)
  coupon: ['.......', 'CCCCCCC', 'C.CCCCC', '.CCCCC.', 'C.CCCCC', 'CCCCCCC', '.......'],
  slot: ['CCCCCCC', 'C.....C', 'C.CCC.C', 'C.CCC.C', 'C.CCC.C', 'C.....C', 'CCCCCCC'],
  tag: ['..CCCCC', '.CCCCCC', 'CC.CCCC', 'CCCCCCC', '.CCCCCC', '..CCCCC', '.......'] };

function ovCanvas(z) { const c = document.createElement('canvas'); c.width = 640; c.height = 360; c.className = 'px';
  Object.assign(c.style, { position: 'absolute', left: 0, top: 0, width: '1280px', height: '720px', zIndex: z, pointerEvents: 'none' });
  stage.appendChild(c); return c.getContext('2d'); }
const under = ovCanvas(2);   // light pools on the belt, under the items
const ov = ovCanvas(7);      // rails, tokens, bubbles, stamps: over the items and tickets

// paint a shape given as a predicate on stage px (texel centres), with: fill, lit (top edge), shade (bottom edge), ink ring,
// hard shadow (1 texel down-right), and stepped halo rings [colour, width in texels]...
function paint(g, inside, box, o) {
  const P = 8, i0 = Math.floor(box[0] / 2) - P, j0 = Math.floor(box[1] / 2) - P, W = Math.ceil(box[2] / 2) + P - i0, H = Math.ceil(box[3] / 2) + P - j0;
  const m = new Uint8Array(W * H), at = (i, j) => i >= 0 && j >= 0 && i < W && j < H && m[j * W + i] === 1;
  for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) if (inside((i0 + i) * 2 + 1, (j0 + j) * 2 + 1)) m[j * W + i] = 1;
  const K = 1 + (o.halo || []).reduce((a, h) => a + h[1], 0) + 1;
  const dist = new Uint8Array(W * H).fill(99);
  for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) {
    if (at(i, j)) { dist[j * W + i] = 0; continue; }
    let d = 99;
    for (let dj = -K; dj <= K; dj++) for (let di = -K; di <= K; di++) if (at(i + di, j + dj)) {
      // ink ring: 4-neighbours only (rounder pixel corners); rings beyond use the chebyshev distance
      const c = Math.max(Math.abs(di), Math.abs(dj)), e = (c === 1 && di !== 0 && dj !== 0) ? 2 : c; if (e < d) d = e; }
    dist[j * W + i] = d;
  }
  const D = (i, j) => i >= 0 && j >= 0 && i < W && j < H ? dist[j * W + i] : 99;
  for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) {
    const d = D(i, j); let col = null;
    if (d === 0) {
      col = o.fill;
      if (o.lit && !at(i, j - 1) && at(i, j + 1)) col = o.lit;
      if (o.shade && !at(i, j + 1) && at(i, j - 1)) col = o.shade;
      if (o.pattern) col = o.pattern(i0 + i, j0 + j, col);
    } else if (d === 1 && o.ink) col = o.ink;
    else if (o.shadow && (D(i - 1, j - 1) <= 1 || (o.shadowW > 1 && D(i - 2, j - 2) <= 1))) col = o.shadow;
    else if (o.halo) { let r = 1; for (const [hc, hw] of o.halo) { if (d > r && d <= r + hw) { col = hc; break; } r += hw; } }
    if (col) { g.fillStyle = col; g.fillRect(i0 + i, j0 + j, 1, 1); }
  }
}
// geometry helpers (stage px)
function segDist(x, y, a, b) { const dx = b[0] - a[0], dy = b[1] - a[1], L = dx * dx + dy * dy;
  const t = L ? Math.max(0, Math.min(1, ((x - a[0]) * dx + (y - a[1]) * dy) / L)) : 0; return Math.hypot(x - a[0] - t * dx, y - a[1] - t * dy); }
function rounded(pts, R) {   // corners replaced by sampled quarter arcs
  const out = [pts[0]];
  for (let k = 1; k < pts.length - 1; k++) { const [a, b, c] = [pts[k - 1], pts[k], pts[k + 1]];
    const u = [(a[0] - b[0]), (a[1] - b[1])], v = [(c[0] - b[0]), (c[1] - b[1])], lu = Math.hypot(...u), lv = Math.hypot(...v);
    const p0 = [b[0] + u[0] / lu * R, b[1] + u[1] / lu * R], p1 = [b[0] + v[0] / lv * R, b[1] + v[1] / lv * R];
    for (let s = 0; s <= 8; s++) { const t = s / 8; out.push([(1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * b[0] + t * t * p1[0], (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * b[1] + t * t * p1[1]]); } }
  out.push(pts[pts.length - 1]); return out;
}
const onPath = (paths, hw) => (x, y) => paths.some(p => { for (let k = 0; k < p.length - 1; k++) if (segDist(x, y, p[k], p[k + 1]) <= hw) return true; return false; });
const arrowAt = (tx, tip, hw, h) => (x, y) => y <= tip && y >= tip - h && Math.abs(x - tx) <= hw * (tip - y) / h + .01;
const plate = (cx, cy, w, h, cut = 2) => (x, y) => { const l = cx - w / 2, t = cy - h / 2, r = l + w, b = t + h;
  if (x < l || x >= r || y < t || y >= b) return false; return !((x < l + cut || x >= r - cut) && (y < t + cut || y >= b - cut)); };
function fx(cls, left, top, html, style) { const d = el('fx ' + cls, Object.assign({ left: left + 'px', top: top + 'px' }, style || {}), html); return d; }
function miniGlyph(c, name, col) { const g = c.getContext('2d'); g.fillStyle = col; GL[name].forEach((r, j) => [...r].forEach((ch, i) => { if (ch === 'C') g.fillRect(i, j, 1, 1); })); }

// ---- the effects of this row ----
const ARCS = [
  { from: 1, to: [2], f: '×2', name: 'Eggs' },
  { from: 4, to: [5, 6, 7], f: '×3', name: 'Multipack' },
];
const ACTIVE = HOVER ? 4 : 0;       // the hovered giver
const RELATED = HOVER ? [4, 5, 6, 7] : [1, 2, 3, 4, 5, 6, 7];
const C = { gold: '#e2b33c', goldLit: '#f1d27a', goldDark: '#b88a1e', ink: '#2b2420', shadow: 'rgba(20,12,6,.5)',
  halo1: 'rgba(250,236,188,.85)', halo2: 'rgba(241,210,122,.42)', quiet: '#a9a59b', quietLit: '#c7c3b8' };

// light pools under the hovered giver's receivers (stepped ellipses on the belt, two flat steps)
function pool(cx, cy, w, h) {
  const tw = w / 2, th = h / 2, i0 = Math.round((cx - w / 2) / 2), j0 = Math.round((cy - h / 2) / 2);
  for (let j = 0; j < th; j++) for (let i = 0; i < tw; i++) {
    const e = ((i + .5 - tw / 2) / (tw / 2)) ** 2 + ((j + .5 - th / 2) / (th / 2)) ** 2;
    if (e <= 1) { under.fillStyle = e < .45 ? 'rgba(250,236,188,.8)' : 'rgba(241,210,122,.6)'; under.fillRect(i0 + i, j0 + j, 1, 1); } }
}
if (HOVER) ARCS.find(a => a.from === ACTIVE).to.forEach(d => document.getElementById('it' + d).classList.add('lit'));

ARCS.forEach(a => {
  const bold = a.from === ACTIVE, quiet = HOVER && !bold;
  const hw = bold ? 3 : 1, R = bold ? 12 : 10;
  const sx = SLOT(a.from), last = SLOT(a.to[a.to.length - 1]);
  const tokH = bold ? 28 : 20, tokW = bold ? 44 : 32;
  // the riser leaves the giver from a socket just over its top; the last drop turns down with a rounded corner
  const main = rounded([[sx, TOP[a.from] - 6], [sx, RAIL], [last, RAIL], [last, TOP[a.to[a.to.length - 1]] - 14]], R);
  const drops = a.to.slice(0, -1).map(d => [[SLOT(d), RAIL], [SLOT(d), TOP[d] - 14]]);
  const aw = bold ? 10 : 7, ah = bold ? 10 : 8;
  const heads = a.to.map(d => arrowAt(SLOT(d), TOP[d] - 2, aw, ah));
  const socket = (x, y) => Math.hypot(x - sx, y - (TOP[a.from] - 8)) <= (bold ? 8 : 6);
  const inside = (x, y) => onPath([main, ...drops], hw)(x, y) || heads.some(h => h(x, y)) || socket(x, y);
  const box = [sx - 20, RAIL - 20, last + 20, Math.max(...a.to.map(d => TOP[d])) + 4];
  paint(ov, inside, box, quiet ? { fill: C.quiet, ink: 'rgba(43,36,32,.7)' }
    : bold ? { fill: C.gold, lit: C.goldLit, shade: C.goldDark, ink: C.ink, shadow: C.shadow }
    : { fill: C.gold, ink: C.ink, shadow: 'rgba(20,12,6,.3)' });
  // the factor token on the rail, right over each receiver
  a.to.forEach(d => {
    const cx = SLOT(d), cy = RAIL;
    paint(ov, plate(cx, cy, tokW, tokH, 2), [cx - tokW, cy - tokH, cx + tokW, cy + tokH],
      quiet ? { fill: '#d8d4ca', ink: 'rgba(43,36,32,.7)' }
      : bold ? { fill: C.gold, lit: C.goldLit, shade: C.goldDark, ink: C.ink, shadow: C.shadow, shadowW: 2, halo: [[C.halo1, 1], [C.halo2, 1]] }
      : { fill: C.gold, lit: C.goldLit, ink: C.ink, shadow: 'rgba(20,12,6,.35)' });
    fx('tok', cx - tokW / 2, cy - tokH / 2, a.f, { width: tokW + 'px', height: tokH + 'px', fontSize: (bold ? 19 : 14) + 'px', paddingTop: bold ? '1px' : '0', opacity: quiet ? .55 : 1 });
  });
});

// ---- loyalty upgrades are givers too: a teal rail from the two stamps that act on Milk 7, out of the top bar ----
{
  const r = id => document.getElementById(id).getBoundingClientRect();
  const sS = r('stSlot'), sT = r('stTag'), xs = Math.round((sS.left + sS.width / 2) / 2) * 2, xt = Math.round((sT.left + sT.width / 2) / 2) * 2;
  const quiet = HOVER, bold = false, hw = 1, LY = 212, tx = SLOT(7) + 26, xm = Math.round((xs + xt) / 4) * 2;
  const xr = xt + 10;
  const comb = [[[xs, sS.bottom + 2], [xs, 58], [xr, 58]], [[xt, sT.bottom + 2], [xt, 58]]];
  const main = rounded([[xr, 58], [xr, LY], [tx, LY], [tx, TOP[7] + 4]], 10);
  const inside = (x, y) => onPath([...comb, main], hw)(x, y) || arrowAt(tx, TOP[7] + 6, 7, 8)(x, y);
  paint(ov, inside, [xs - 20, 40, tx + 20, TOP[7] + 10], quiet ? { fill: C.quiet, ink: 'rgba(43,36,32,.7)' } : { fill: '#4f9a94', ink: C.ink, shadow: 'rgba(20,12,6,.3)' });
  [[1062, 'slot', '+12'], [1136, 'tag', '×2']].forEach(([cx, g, t]) => {
    const w = 48, h = 20;
    paint(ov, plate(cx, LY, w, h, 2), [cx - w, LY - h, cx + w, LY + h], quiet ? { fill: '#d8d4ca', ink: 'rgba(43,36,32,.7)' } : { fill: '#2a4d4b', lit: '#3d6a67', ink: C.ink, shadow: 'rgba(20,12,6,.35)' });
    const n = fx('tok', cx - w / 2, LY - h / 2, `<canvas class="px mst" data-g="${g}" width="7" height="7"></canvas><span style="margin-left:3px">${t}</span>`,
      { width: w + 'px', height: h + 'px', fontSize: '14px', color: quiet ? '#2b2420' : '#faecbc', opacity: quiet ? .55 : 1 });
    miniGlyph(n.querySelector('canvas'), g, quiet ? '#2b2420' : '#faecbc');
  });
}

// ---- result bubbles at the items' feet: the item's own bonus (cream), then what it pays, up-arrow when boosted ----
const UP = '<canvas class="px upg" width="9" height="9" style="width:18px;height:18px;display:block;margin:0 1px 0 2px"></canvas>';
const FZ = '<canvas class="px fzg" width="7" height="7" style="width:14px;height:14px;display:block;margin-right:3px"></canvas>';
const BUB = {
  2: { res: '€10', up: true },
  3: { fz: true, res: '€0' },
  4: { fz: true, res: '€0' },
  5: { own: '+3', res: '€21', up: true },
  6: { own: '+4', res: '€24', up: true },
  7: { own: '+5', res: '€126', up: true },
};
const BT = 392, BH = 28, TAIL = 8;
Object.entries(BUB).forEach(([d, b]) => {
  d = +d;
  const dim = HOVER && !RELATED.includes(d);
  const hot = HOVER && d !== ACTIVE && RELATED.includes(d);
  const html = (b.own ? `<i class="tk own">${b.own}</i>` : '') + (b.fz ? FZ : '') + (b.up ? UP : '') +
    `<span class="res${b.fz ? ' zero' : ''}">${b.res}</span>`;
  const n = fx('bub' + (dim ? ' dim' : '') + (b.fz ? ' zero' : ''), 0, BT, html);
  n.querySelectorAll('canvas.upg').forEach(c => { const g = c.getContext('2d'), A7 = ['...C...', '..CCC..', '.CCCCC.', 'CCCCCCC', '..CCC..', '..CCC..', '..CCC..'];
    const on = (i, j) => j >= 0 && j < 7 && i >= 0 && i < 7 && A7[j][i] === 'C';
    for (let j = -1; j < 8; j++) for (let i = -1; i < 8; i++) { let col = null;
      if (on(i, j)) col = (j < 3 && !on(i - 1, j)) || !on(i, j - 1) ? '#f1d27a' : '#e2b33c';
      else if (on(i - 1, j) || on(i + 1, j) || on(i, j - 1) || on(i, j + 1)) col = '#2b2420';
      if (col) { g.fillStyle = col; g.fillRect(i + 1, j + 1, 1, 1); } } });
  n.querySelectorAll('canvas.fzg').forEach(c => { const g = c.getContext('2d'); g.fillStyle = '#fbf7ee'; FIZZLE7.forEach((row, j) => [...row].forEach((ch, i) => { if (ch === 'C') g.fillRect(i, j, 1, 1); })); });
  const w = Math.ceil(n.offsetWidth / 2) * 2 + 2;
  const cx = SLOT(d);
  const left = Math.min(1272 - w, Math.round((cx - w / 2) / 2) * 2);
  n.style.left = left + 'px'; n.style.width = w + 'px';
  const body = plate(left + w / 2, BT + BH / 2, w, BH, 2);
  const tail = (x, y) => y >= BT - TAIL && y < BT + 2 && Math.abs(x - cx) <= (y - (BT - TAIL)) * .8 + 1;
  paint(ov, (x, y) => body(x, y) || tail(x, y), [left, BT - TAIL, left + w, BT + BH],
    dim ? { fill: '#ddd6c6', ink: 'rgba(43,36,32,.55)' }
    : { fill: b.fz ? '#d9534f' : hot ? '#faecbc' : '#fbf7ee', lit: b.fz ? '#ec7d75' : '#ffffff', shade: b.fz ? '#a83a3c' : null, ink: C.ink, shadow: 'rgba(20,12,6,.45)', shadowW: 2,
        halo: hot ? [[C.halo1, 1], [C.halo2, 1]] : null });
});

// ---- denied: Milk 3 greyed with a tomato stamp across it; the coupon's own pay fizzled: a fizzle disc on its corner ----
function stamp(cx, cy, w, h, html, fs, alpha) {
  paint(ov, plate(cx, cy, w, h, 2), [cx - w, cy - h, cx + w, cy + h], { fill: '#d9534f', lit: '#ec7d75', shade: '#a83a3c', ink: C.ink, shadow: C.shadow, shadowW: 2 });
  fx('stampd', cx - w / 2, cy - h / 2, html, { width: w + 'px', height: h + 'px', lineHeight: h + 'px', fontSize: fs + 'px', opacity: alpha || 1 });
}
stamp(SLOT(3), 344, 76, 22, 'DENIED', 15);
{ const m = mark('fz', 850 - 22, TOP[4] - 14); }
if (HOVER) stamp(SLOT(4) + 2, 368, 80, 20, 'PAYS €0', 13);

// ---- hover: dim the unrelated items and tickets, ring the stamp that fizzled the coupon ----
if (HOVER) {
  [1, 2, 3].forEach(d => document.getElementById('it' + d).classList.add('dim'));
  document.querySelectorAll('.label').forEach(l => { const d = Math.round((l.offsetLeft - 240) / 128); if (!RELATED.includes(d)) l.classList.add('dim'); });
  const s = document.getElementById('stCoupon'); s.style.outline = '2px solid #d9534f'; s.style.outlineOffset = '2px'; s.style.borderRadius = '50%';
}
// the monitor legend's mini glyph
document.querySelectorAll('canvas.mst[data-glyph]').forEach(c => miniGlyph(c, c.dataset.glyph, '#faecbc'));
