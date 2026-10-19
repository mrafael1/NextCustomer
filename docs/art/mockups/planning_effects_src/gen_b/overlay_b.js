// ================= planning effects, direction B: "on the ticket" (drawn after the mirror pass, display coordinates) =================
// Three readings, top to bottom, all grounded on the slot rail:
//  1. the connector lane (y 396-428, over the belt's steel lip and apron, under the items' feet): one gold bar per item that
//     gives something to other items, from a plug over the source ticket to an arrow dropping onto each target's price, with the
//     source's name on the bar and the factor in a badge at each drop. The rail's steel between the tickets it spans is lit too.
//  2. the ticket: the base price stays where it is; when the pay changes it is struck and the real pay sits beside it on a
//     sticker: a gold starburst (boosted) or a punched tomato tag with the fizzle glyph (denied). The rule text is never covered.
//  3. the slip: a paper wobbler clipped under the ticket, one line per contribution the ticket gets from itself, a stamp or the
//     inspection, in words. Cross-item gifts are read on the connector (and are added to the slip only while hovered).
// The items only get a quiet state: a stepped two-ring gold rim when boosted, greyed when denied.
// Motion notes (not in the still): in planning the stickers pop in with one 2-frame squash when the row changes, the connector bar's
// chevrons slide one texel step toward the targets once (no loop); on hover the hovered item's bar brightens and the others dim.
(() => {
const SL = k => 368 + (k - 1) * 128, TW = 112, TT = 428, G = 388;
const GOLD = '#e2b33c', GOLD_L = '#f1d27a', GOLD_D = '#b8892a', GOLD_DD = '#8e6a1a';
const S = document.createElementNS(NS, 'svg'); S.setAttribute('class', 'layer'); S.setAttribute('viewBox', '0 0 1280 720');
S.setAttribute('shape-rendering', 'crispEdges'); S.style.zIndex = 5; stage.appendChild(S);
const grp = (dim) => { const g = document.createElementNS(NS, 'g'); if (dim) g.setAttribute('opacity', '.35'); S.appendChild(g); return g; };

// ---------- items ----------
const HALO = [GOLD_L, GOLD].map(c => ['2px 0', '-2px 0', '0 2px', '0 -2px'].map(o => `drop-shadow(${o} 0 ${c})`).join(' ')).join(' ');
function itemD(k, src, o = {}) {
  const x = SL(k) + 8, lift = o.lift || 0, sw = lift ? 52 : 74;
  pxShadow(x + 48 - sw / 2 + 6, G - (lift ? 8 : 10), sw, lift ? 12 : 14, 3, lift ? .25 : .5);
  const d = el('item', { left: x + 'px', top: (G - 96 - lift + (o.base || 0)) + 'px', zIndex: 3 });
  if (o.canvas) d.appendChild(o.canvas); else d.innerHTML = `<img class="px" src="${src}">` + (o.icon ? `<img class="px slipicon" src="${o.icon}">` : '');
  if (o.state === 'boost') d.style.filter = HALO;
  if (o.state === 'deny') { d.style.filter = 'grayscale(1) brightness(.9) contrast(.75)'; d.style.opacity = .72; }
  return d;
}
// a placeholder loaf (48 x 48 texels at 2x, ink outline, lit upper left), until Bread has its sprite
function breadCanvas() {
  const c = document.createElement('canvas'); c.width = 48; c.height = 48; c.className = 'px';
  c.style.cssText = 'position:absolute;left:0;top:0;width:96px;height:96px';
  const g = c.getContext('2d'), dot = (i, j, col) => { g.fillStyle = col; g.fillRect(i, j, 1, 1); };
  const inside = (i, j) => {
    if (j < 16 || j > 43 || i < 4 || i > 43) return false;
    if (j < 32) return ((i - 23.5) / 20.5) ** 2 + ((j - 32) / 16) ** 2 <= 1;
    if (j >= 41) return i >= 4 + (j - 40) && i <= 43 - (j - 40);
    return true;
  };
  for (let j = 0; j < 48; j++) for (let i = 0; i < 48; i++) {
    if (inside(i, j)) {
      let col = j > 38 ? '#a8703a' : '#c98c4e';
      if (!inside(i - 1, j) || !inside(i, j - 1) || !inside(i, j - 2)) col = '#e3b27a';
      if (!inside(i + 1, j) || !inside(i, j + 1)) col = '#6e4524';
      dot(i, j, col);
    } else if (inside(i - 1, j) || inside(i + 1, j) || inside(i, j - 1) || inside(i, j + 1)) dot(i, j, INK);
  }
  for (let s = 0; s < 3; s++) for (let t = 0; t < 6; t++) { dot(13 + s * 9 + t, 27 - t, '#f3e9d2'); dot(13 + s * 9 + t, 28 - t, '#8a5a2e'); }
  return c;
}
// a 4-point pixel sparkle (5 x 5 texels) beside a boosted item
function sparkle(x, y) {
  const c = document.createElement('canvas'); c.width = 5; c.height = 5; c.className = 'px';
  Object.assign(c.style, { position: 'absolute', left: x + 'px', top: y + 'px', width: '10px', height: '10px', zIndex: 4 });
  const g = c.getContext('2d'); g.fillStyle = GOLD_L; [[2, 0], [2, 1], [0, 2], [1, 2], [3, 2], [4, 2], [2, 3], [2, 4]].forEach(([i, j]) => g.fillRect(i, j, 1, 1));
  g.fillStyle = '#fbf7ee'; g.fillRect(2, 2, 1, 1); stage.appendChild(c);
}

// ---------- tickets, stickers, slips ----------
function ticket(k, o) {
  const cls = 'label tk' + (o.got ? ' got' : '') + (o.cp ? ' cp' : '') + (o.sel ? ' sel' : '') + (o.dim ? ' dim' : '');
  const price = `<span class="${o.strike ? 'strk' : ''}">${o.cp ? 'COUPON' : o.price}</span>`;
  return el(cls, { left: SL(k) + 'px', top: TT + 'px', zIndex: 4, background: o.got ? '#f6dd8f' : '' },
    `<div class="p">${price}${o.aisle ? `<img class="ai2 px" src="${A}icons/aisle_${o.aisle}.png">` : ''}</div>` + (o.rule ? `<div class="r">${o.rule}</div>` : ''));
}
const snap = v => Math.round(v / 2) * 2;
function svgIn(parent, w, h) { const s = document.createElementNS(NS, 'svg'); s.setAttribute('width', w + 6); s.setAttribute('height', h + 6);
  s.setAttribute('viewBox', `0 0 ${w + 6} ${h + 6}`); s.setAttribute('shape-rendering', 'crispEdges'); parent.appendChild(s); return s; }
// a gold starburst sticker on the ticket's right, over the price line only (it pokes 6 px above the ticket, never down into the rule)
function burst(k, text, o = {}) {
  const w = o.w || 58, h = o.h || 30, x = SL(k) + TW - w + 10, y = TT - (o.up || 6);
  const d = el('stk' + (o.dim ? ' dimg' : ''), { left: x + 'px', top: y + 'px', width: w + 'px', height: h + 'px' });
  const s = svgIn(d, w, h), N = Math.round(w / 5), cx = w / 2, cy = h / 2;
  const pts = (rx, ry, dr) => Array.from({ length: N * 2 }, (_, i) => { const a = Math.PI * i / N - Math.PI / 2, r = i % 2 ? 1 - dr : 1;
    return [snap(cx + Math.cos(a) * rx * r), snap(cy + Math.sin(a) * ry * r)]; });
  const P = (p, fill, extra, dx = 0) => poly(s, p.map(([a, b]) => [a + dx, b + dx]), fill, extra);
  P(pts(w / 2, h / 2, .2), 'rgba(30,18,10,.42)', {}, 3);
  P(pts(w / 2, h / 2, .2), GOLD, { stroke: INK, 'stroke-width': 2, 'stroke-linejoin': 'miter' });
  P(pts(w / 2 - 7, h / 2 - 6, .08), GOLD_L);
  el('t', { top: (h / 2 - 11) + 'px', fontSize: (o.fs || 19) + 'px', lineHeight: '22px', left: '2px' }, text, d);
}
// a punched tomato tag: notched corners, the fizzle glyph in paper, "€0"
function deny(k, text) {
  const w = 52, h = 26, x = SL(k) + TW - w + 6, y = TT - 4;
  const d = el('stk z', { left: x + 'px', top: y + 'px', width: w + 'px', height: h + 'px' });
  const s = svgIn(d, w, h), n = 4, sh = [[n, 0], [w - n, 0], [w, n], [w, h - n], [w - n, h], [n, h], [0, h - n], [0, n]];
  poly(s, sh.map(([a, b]) => [a + 3, b + 3]), 'rgba(30,18,10,.42)');
  poly(s, sh, '#d9534f', { stroke: INK, 'stroke-width': 2 });
  rect(s, 2, 2, w - 4, 2, '#ec7d75'); rect(s, 2, h - 4, w - 4, 2, '#a83a3c');
  FIZZLE7.forEach((r, j) => [...r].forEach((ch, i) => { if (ch === 'C') rect(s, 7 + i * 2, 6 + j * 2, 2, 2, '#fbf7ee'); }));
  el('t', { top: '1px', left: '18px', fontSize: '17px', lineHeight: '24px' }, text, d);
}
function slip(k, lines, o = {}) {
  const w = 124, x = SL(k) - 6;
  const d = el('slip' + (o.dim ? ' dim' : ''), { left: x + 'px', top: '494px', width: w + 'px' },
    lines.map(([kind, badge, text, hl]) => kind === 'n' ? `<div class="sl why">${badge}<span>${text}</span></div>`
      : `<div class="sl${hl ? ' hl' : ''}"><b class="bd ${kind}">${badge}</b><span>${text}</span></div>`).join(''));
  [x + 18, x + w - 30].forEach(cx => el('sclip', { left: cx + 'px', top: '484px', opacity: o.dim ? .45 : 1 }));
  return d;
}

// ---------- connectors: a gold bar in the lane over the lip, plug on the source, an arrow and a factor badge on each target ----------
function connector(src, targets, factor, name, o = {}) {
  const g = grp(o.dim), last = targets[targets.length - 1];
  const x0 = SL(src) + 8, x1 = SL(last) + 52, y0 = 400, H = 18;
  // the rail lights up between the tickets the effect spans: the steel gaps glow gold (lit band at the top, shade at the bottom)
  for (let k = src; k < last; k++) { const gx = SL(k) + TW + 2;
    rect(g, gx, 424, 12, 64, GOLD); rect(g, gx, 424, 12, 4, GOLD_L); rect(g, gx, 482, 12, 6, GOLD_D);
    rect(g, gx + 4, 436, 4, 4, GOLD_L); rect(g, gx + 4, 452, 4, 4, GOLD_L); rect(g, gx + 4, 468, 4, 4, GOLD_L); }
  // hovered: a stepped two-ring halo around the bar (ink, then light gold), no blur
  if (o.glow) { rect(g, x0 - 6, y0 - 6, x1 - x0 + 12, H + 12, INK); rect(g, x0 - 4, y0 - 4, x1 - x0 + 8, H + 8, '#faecbc'); }
  // the bar: hard shadow, gold fill, lit top band, shaded bottom band, ink outline
  rect(g, x0 + 3, y0 + 3, x1 - x0, H, 'rgba(20,12,8,.45)');
  rect(g, x0, y0, x1 - x0, H, GOLD); rect(g, x0, y0, x1 - x0, 4, GOLD_L); rect(g, x0, y0 + H - 4, x1 - x0, 4, GOLD_D);
  rect(g, x0, y0, x1 - x0, H, 'none', { stroke: INK, 'stroke-width': 2 });
  // the plug over the source ticket: an ink block with a gold pip, and a stem down onto the ticket's top
  rect(g, x0 - 2, y0 - 2, 14, H + 4, INK); rect(g, x0 + 2, y0 + 4, 6, 10, GOLD_L);
  rect(g, x0 + 2, y0 + H + 2, 6, 428 - y0 - H - 2, INK);
  // chevrons pointing right (later slots) along the bar, between the name and the badges
  const badgeX = targets.map(t => SL(t) + 24);
  const chev = (cx) => [[0, 0], [2, 2], [4, 4], [2, 6], [0, 8]].forEach(([dx, dy]) => rect(g, cx + dx, y0 + 5 + dy - 1, 2, 2, GOLD_DD));
  const nameEnd = x0 + 18 + name.length * 9;
  for (let cx = snap(nameEnd + 8); cx < x1 - 10; cx += 18) if (badgeX.every(b => Math.abs(cx - b) > 30)) chev(cx);
  const nm = el('cname' + (o.dim ? ' dimg' : ''), { left: (x0 + 16) + 'px', top: (y0 + 2) + 'px' }, name);
  if (o.glow) targets.forEach((t, i) => o.amts && el('fb amt', { left: (SL(t) + 50) + 'px', top: '398px' }, o.amts[i]));
  // each target: an arrow from the bar down onto the price, and the factor badge riding the bar
  targets.forEach((t, i) => {
    const cx = badgeX[i];
    poly(g, [[cx - 8, 420], [cx + 8, 420], [cx + 1, 428], [cx - 1, 428]], INK);
    poly(g, [[cx - 4, 420], [cx + 4, 420], [cx, 424]], GOLD_L);
    const b = el('fb' + (o.glow ? ' big' : '') + (o.dim ? ' dimg' : ''), { left: (cx - 22) + 'px', top: '394px', width: '44px' }, factor);
  });
}

// ================= the row =================
const NAME = { 1: 'Eggs', 2: 'Bread', 3: 'Milk', 4: 'Multipack', 5: 'Milk', 6: 'Milk', 7: 'Milk' };
itemD(1, `${A}items_v2/eggs.png`);
itemD(2, null, { canvas: breadCanvas(), base: 8, state: 'boost' });
itemD(3, `${A}items_v2/milk.png`, { state: 'deny' });
const cp = itemD(4, `${A}items_v2/coupon_slip.png`, { base: 16, lift: HOVER ? 16 : 0, icon: `${A}icons/coupon_multipack_v2.png` });
[5, 6, 7].forEach(k => itemD(k, `${A}items_v2/milk.png`, { state: 'boost' }));
// a fizzle disc on each denied item's top right (same rule as the belt's marks)
mark('fz', SL(3) + 8 + 39 * 2 - 18, G - 96 + 3 * 2 - 10);
if (!HOVER) mark('fz', SL(4) + 8 + 45 * 2 - 22, G - 96 + 12 * 2 - 14 + 16 - 16);
[2, 5, 6, 7].forEach(k => { sparkle(SL(k) + 8 + 80, G - 96 + 4); sparkle(SL(k) + 8 + 4, G - 96 + 30); });

// tickets
ticket(1, { price: '€1', rule: '×2 next Food' });
ticket(2, { price: '€5', rule: 'Food · Breakfast', aisle: 'bakery', strike: true });
ticket(3, { price: '€4', rule: '+1 per earlier Breakfast', strike: true });
ticket(4, { cp: true, rule: '×3 later with prior’s tag', sel: HOVER });
[5, 6, 7].forEach(k => ticket(k, { price: '€4', rule: '+1 per earlier Breakfast', strike: true, got: HOVER }));

// connectors (cross-item gifts)
connector(1, [2], '×2', 'EGGS', { dim: HOVER });
connector(4, [5, 6, 7], '×3', 'MULTIPACK', { glow: HOVER, amts: ['+€14', '+€16', '+€84'] });

// stickers: what each item really pays
burst(2, '€10', { dim: HOVER, w: 54, h: 28, fs: 17, up: 4 });
deny(3, '€0');
deny(4, '€0');
burst(5, '€21', { w: 60, h: 32 }); burst(6, '€24', { w: 60, h: 32 }); burst(7, '€126', { w: 80, h: 36, fs: 22, up: 10 });

// slips: own, stamp and inspection contributions, in words
const FZI = `<img class="px fzi" src="${A}icons/fizzle.png">`, MST = g => `<i class="mst" data-g="${g}"></i>`;
slip(3, [['n', FZI, 'Spot check: 3rd']], { dim: HOVER });
slip(4, [['n', MST('coupon'), 'Coupon engine']].concat(HOVER ? [['x', '×3', 'gives <span class="amt">+€114</span>', 1]] : []));
slip(5, [['p', '+3', 'Breakfasts']].concat(HOVER ? [['x', '×3', 'Multipack', 1]] : []));
slip(6, [['p', '+4', 'Breakfasts']].concat(HOVER ? [['x', '×3', 'Multipack', 1]] : []));
slip(7, [['p', '+5', 'Breakfasts'], ['x', '+12 ×2', 'Slot engine']].concat(HOVER ? [['x', '×3', 'Multipack', 1]] : []));

// the mini loyalty stamps inside the slips: the top bar's 13 x 13 texel stamp at 1x
{ const GL = { coupon: ['.......', 'CCCCCCC', 'C.CCCCC', '.CCCCC.', 'C.CCCCC', 'CCCCCCC', '.......'],
    slot: ['CCCCCCC', 'C.....C', 'C.CCC.C', 'C.CCC.C', 'C.CCC.C', 'C.....C', 'CCCCCCC'] };
  document.querySelectorAll('i.mst').forEach(n => { const c = document.createElement('canvas'); c.width = 13; c.height = 13; c.className = 'px';
    pxDisc(c, { ring: '#2b2420', inner: '#e2b33c', fill: '#2a4d4b', glyph: GL[n.dataset.g], ink: '#faecbc' }); n.appendChild(c); }); }
if (HOVER) {
  // the hovered coupon: lifted with the selection brackets (as in B2)
  const x = SL(4) + 8;
  [['l', 't'], ['r', 't'], ['l', 'b'], ['r', 'b']].forEach(([h, v]) => {
    el('abs brk', { left: (h === 'l' ? x - 16 : x + 96) + 'px', top: (v === 't' ? G - 100 : G - 4) + 'px',
      borderLeftWidth: h === 'l' ? '4px' : 0, borderRightWidth: h === 'r' ? '4px' : 0, borderTopWidth: v === 't' ? '4px' : 0, borderBottomWidth: v === 'b' ? '4px' : 0 });
  });
  mark('fz', SL(4) + 8 + 45 * 2 - 28, G - 96 + 12 * 2 - 14);
  // why these targets: the prior product's tag, a teal chip in the lane over Milk 3's ticket
  el('tagchip', { left: (SL(3) + 30) + 'px', top: '402px' }, 'tag: Cold case ›');
  // what the Multipack receives: the Coupon engine stamp in the top bar is marked with the fizzle
  const st = document.querySelector('.stamp[title="Coupon engine"]'), r = st.getBoundingClientRect();
  mark('fz', r.left + 12, r.top + 8).style.zIndex = 9;
}
})();
