const IX = i => 376 + 128 * i, TX = i => 368 + 128 * i;   // item box and ticket left of display slot i (0..6)
const PAL = {
  gold:   { fill: '#e2b33c', lit: '#f1d27a', shade: '#b8892a' },
  cream:  { fill: '#fbf7ee', lit: '#ffffff', shade: '#ddcba5' },
  teal:   { fill: '#2a4d4b', lit: '#4f9a94', shade: '#1f3b3a' },
  tomato: { fill: '#d9534f', lit: '#ec7d75', shade: '#a83a3c' },
  grey:   { fill: '#c2beb4', lit: '#dcd8ce', shade: '#9a968d' },
  pale:   { fill: '#f1d27a', lit: '#faecbc', shade: '#e2b33c' },
};
// paints a shape into a texel canvas: 1-texel ink outline, lit inner edge at the upper left, shaded at the lower right,
// and a hard 1-texel drop shadow to the lower right
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
function fxBox(cls, x, y, tw, th, html) {
  const d = el('fx ' + cls, { left: Math.round(x / 2) * 2 + 'px', top: Math.round(y / 2) * 2 + 'px', width: tw * 2 + 'px', height: th * 2 + 'px' });
  const c = tcanvas(tw, th); d.appendChild(c);
  const t = document.createElement('div'); t.className = 't'; t.innerHTML = html || ''; d.appendChild(t);
  return { d, c, t };
}
function glyphCanvas(rows, cols) {   // a mini badge from character rows; '.' is clear
  const c = tcanvas(rows[0].length, rows.length), g = c.getContext('2d');
  rows.forEach((r, j) => [...r].forEach((ch, i) => { if (cols[ch]) { g.fillStyle = cols[ch]; g.fillRect(i, j, 1, 1); } }));
  return c;
}
// mini source badges (2 px texels): who gave the effect
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
// a received effect: '+' is a cream price-gun label, 'x' a gold starburst; tilt in degrees, drawn on the texel grid
function sticker(x, y, kind, text, badge, tilt) {
  const mul = kind === 'mul', tw = mul ? 31 : (text.length > 2 ? 27 : 23), th = mul ? 17 : 14;
  const { d, t, c } = fxBox('stk ' + kind, x, y, tw, th);
  const a = (tw - 1) / 2, b = (th - 1) / 2, r = (tilt || 0) * Math.PI / 180, co = Math.cos(r), si = Math.sin(r);
  pxPaint(c, (i, j) => {
    const u0 = i + .5 - a, v0 = j + .5 - b, u = u0 * co + v0 * si, v = -u0 * si + v0 * co;
    if (mul) { const nu = u / a, nv = v / b, th2 = Math.atan2(nv, nu), k = (th2 / (2 * Math.PI) * 18 + 18) % 1;
      return Math.hypot(nu, nv) <= .84 + .16 * Math.abs(k - .5) * 2; }
    return (Math.abs(u) / (a * .96)) ** 5 + (Math.abs(v) / (b * .9)) ** 5 <= 1;
  }, mul ? PAL.gold : kind === 'fz' ? PAL.grey : PAL.cream);
  if (badge) { const b = BADGE[badge](); Object.assign(b.style, { position: 'absolute', left: (mul ? -8 : -14) + 'px', top: Math.round((th * 2 - parseInt(b.style.height)) / 4) * 2 + 'px', zIndex: 2 }); d.appendChild(b); }
  const s = document.createElement('span'); s.textContent = text; t.appendChild(s);
  return d;
}
// a denied item's rubber stamp, tilted on the texel grid (tomato: a fizzle-like outcome)
function stamp(x, y) {
  const tw = 48, th = 34, { d, c } = fxBox('stamp71', x, y, tw, th,
    '<span class="big">€0</span><span class="sm">SPOT CHECK</span>');
  const g = c.getContext('2d'), a = (tw - 1) / 2, b = (th - 1) / 2, r = -9 * Math.PI / 180, co = Math.cos(r), si = Math.sin(r);
  for (let j = 0; j < th; j++) for (let i = 0; i < tw; i++) {
    const u0 = i + .5 - a, v0 = j + .5 - b, u = Math.abs(u0 * co + v0 * si), v = Math.abs(-u0 * si + v0 * co);
    const A = a - 2, B = b - 4;
    if (u > A || v > B) continue;
    const ring = u > A - 1 || v > B - 1, ring2 = !ring && (u > A - 3 && u <= A - 2);
    g.fillStyle = ring || ring2 ? '#a83a3c' : 'rgba(251,247,238,.88)'; g.fillRect(i, j, 1, 1);
  }
  return d;
}
function sparkle(x, y) { const c = glyphCanvas(['..C..', '..C..', 'CCWCC', '..C..', '..C..'], { C: '#f1d27a', W: '#ffffff' });
  Object.assign(c.style, { position: 'absolute', left: x + 'px', top: y + 'px', zIndex: 8 }); stage.appendChild(c); return c; }
// an item in display coordinates; its contact shadow sits a little right (light from the upper left)
function itemD(i, src, o = {}) {
  const x = IX(i), lift = o.lift || 0, base = o.base || 0, w = o.shadowW || 74, sw = lift ? Math.round(w * .82) : w;
  pxShadow(x + 48 - sw / 2 + 6, ground - (lift ? 9 : 10), sw, lift ? 12 : 14, 3, lift ? .32 : .5);
  const d = el('item ' + (o.cls || ''), { left: x + 'px', top: (ground - 96 - lift + base) + 'px', zIndex: 3 });
  if (o.canvas) d.appendChild(o.canvas); else d.innerHTML = `<img class="px" src="${src}">`;
  if (o.icon) d.insertAdjacentHTML('beforeend', `<img class="px slipicon" src="${o.icon}">`);
  return d;
}
// Bread has no sprite yet: a 48 x 48 texel tin loaf placeholder in the item palette
function breadCanvas() {
  const c = document.createElement('canvas'); c.width = 48; c.height = 48; c.className = 'px'; c.style.width = '96px'; c.style.height = '96px';
  const inside = (i, j) => (i >= 7 && i <= 40 && j >= 28 && j <= 46) || (j <= 29 && ((i + .5 - 24) / 18) ** 2 + ((j + .5 - 29) / 13) ** 2 <= 1);
  const g = pxPaint(c, inside, { fill: '#c98c4e', lit: '#e2b07a', shade: '#8a5a2e' }, null);
  g.fillStyle = '#e2b07a'; for (let j = 18; j < 27; j++) for (let i = 10; i < 22; i++) if (inside(i, j) && inside(i - 2, j - 2) && (i + j) % 7 < 3 && i + j < 40) g.fillRect(i, j, 1, 1);
  g.fillStyle = '#a8703a'; for (let i = 8; i < 40; i++) { g.fillRect(i, 43, 1, 1); g.fillRect(i, 44, 1, 1); g.fillRect(i, 45, 1, 1); }
  [[13, 19], [21, 17], [29, 19]].forEach(([x, y]) => { for (let t = 0; t < 5; t++) { g.fillStyle = '#8a5a2e'; g.fillRect(x + t, y + t, 1, 1); g.fillStyle = '#f0d29c'; g.fillRect(x + t + 1, y + t, 1, 1); } });
  return c;
}

