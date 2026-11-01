// Receipt machine redraw (new DA) mock-up: paints the RECEIPT REWARDS machine on the 640x360 art grid
// (1 art px = 2 screen px at 1280x720), in palette colours only, in front of the #123 store (PR #126's
// StoreArt, ported below). Not game code. Sprites (sealed tickets, items, icons) are the repo's PNGs.

'use strict';

const PAL = {
  '#': '2b2420', '%': '4a3f38', '=': '5e574d', '-': '8a8172', ':': 'c7beab',
  a: 'b39f78', b: 'ddcba5', c: 'f3e9d2', w: 'fbf7ee',
  1: '1f3b3a', 2: '2a4d4b', 3: '3a7672', 4: '4f9a94', 5: '86c2b6', 6: 'c3e0d4',
  q: '6e2630', r: 'a83a3c', R: 'd9534f', o: 'ec8a6e', O: 'f5bfa0',
  u: '7a5a1c', m: 'b38425', M: 'e2b33c', y: 'f1d27a', Y: 'faecbc',
  g: '3d7a45', G: '5fae5a', z: 'a5d17e',
  e: '4a3022', f: '7a5232', F: 'a87a4e', h: 'd2a874',
  k: '4a3010', l: '8a5d1a', L: 'c8932b', n: 'ffcf3f',
  v: '2a0e14', V: '561327', x: '8a1f33', X: 'b23a55',
  A: 'ecebe4', B: 'c7c3b8', C: 'a9a59b', D: '8d8a83', E: '6f6b63', H: '57534c', I: '45423d',
  J: '3d3a36', K: '2c2926', N: '24221f',
  P: 'ddb07a', Q: 'c98c4e', S: 'a8703a', T: '6e4524', U: '3e2614',
  W: 'ece0c6', Z: 'e4d6b9', d: 'cdbb98', i: 'b9a47c',
  j: 'e4f6f3', p: 'bfe2dd', s: '2c3533', t: '222a29', 7: '5fb0a8', 8: '172c2b', 9: 'e2b48c', 0: 'c38f6a',
};
const RGB = {};
Object.keys(PAL).forEach(k => { const h = PAL[k]; RGB[k] = [parseInt(h.slice(0, 2), 16), parseInt(h.slice(2, 4), 16), parseInt(h.slice(4, 6), 16)]; });

const W = 640, H = 360;
const BAYER = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];

// ---------------------------------------------------------------- the pixel buffer
class Buf {
  constructor(w, h) { this.w = w; this.h = h; this.d = new Uint8ClampedArray(w * h * 4); }
  px(x, y, k) {
    x |= 0; y |= 0;
    if (x < 0 || y < 0 || x >= this.w || y >= this.h || k === '.' || k == null) return;
    const c = RGB[k], i = (y * this.w + x) * 4;
    this.d[i] = c[0]; this.d[i + 1] = c[1]; this.d[i + 2] = c[2]; this.d[i + 3] = 255;
  }
  rect(x, y, w, h, k) { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) this.px(x + i, y + j, k); }
  hl(x, y, w, k) { this.rect(x, y, w, 1, k); }
  vl(x, y, h, k) { this.rect(x, y, 1, h, k); }
  frame(x, y, w, h, k) { this.hl(x, y, w, k); this.hl(x, y + h - 1, w, k); this.vl(x, y, h, k); this.vl(x + w - 1, y, h, k); }
  // a 50 % (level 2) or 25 % (level 1) dither of k over a rect
  dither(x, y, w, h, k, level) {
    for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
      const ax = x + i, ay = y + j;
      const on = level === 2 ? (ax + ay) % 2 === 0 : level === 3 ? (ax + ay) % 2 === 0 || (ax % 2 === 0) : (ax % 2 === 0 && ay % 2 === 0);
      if (on) this.px(ax, ay, k);
    }
  }
  // a raised panel: face, light top/left, shade bottom/right, ink outline (cut corners when round)
  panel(x, y, w, h, face, light, shade, ink, round) {
    this.rect(x + 1, y + 1, w - 2, h - 2, face);
    this.hl(x + 1, y + 1, w - 2, light); this.vl(x + 1, y + 1, h - 2, light);
    this.hl(x + 1, y + h - 2, w - 2, shade); this.vl(x + w - 2, y + 1, h - 2, shade);
    if (ink) this.frame(x, y, w, h, ink);
    if (round) { ['.', '.'].forEach(() => 0); this.cut(x, y, w, h); }
  }
  cut(x, y, w, h) {   // clears the four corner px (a 1 px rounded corner)
    [[x, y], [x + w - 1, y], [x, y + h - 1], [x + w - 1, y + h - 1]].forEach(([a, b]) => this.clear(a, b));
  }
  clear(x, y) { if (x < 0 || y < 0 || x >= this.w || y >= this.h) return; const i = (y * this.w + x) * 4; this.d[i + 3] = 0; }
  screw(x, y) { this.rect(x, y, 3, 3, 'C'); this.px(x, y, 'A'); this.px(x + 2, y + 2, 'E'); this.px(x + 1, y + 1, 'H'); }
  blit(b, ox, oy) {
    for (let y = 0; y < b.h; y++) for (let x = 0; x < b.w; x++) {
      const i = (y * b.w + x) * 4; if (!b.d[i + 3]) continue;
      const X = ox + x, Y = oy + y; if (X < 0 || Y < 0 || X >= this.w || Y >= this.h) continue;
      const o = (Y * this.w + X) * 4; this.d[o] = b.d[i]; this.d[o + 1] = b.d[i + 1]; this.d[o + 2] = b.d[i + 2]; this.d[o + 3] = 255;
    }
  }
}

// ---------------------------------------------------------------- lettering
// Words: Pixelify Sans at 11 px rasterised hard (the game's pixel_label: one font px = one art px), or 2x.
// Numbers: a 5x7 digit face (the game prints numbers in its number font, never Pixelify). Small print: 3x5.
const F35 = {
  A: '010101111101101', B: '110101110101110', C: '011100100100011', D: '110101101101110', E: '111100110100111',
  F: '111100110100100', G: '011100101101011', H: '101101111101101', I: '111010010010111', J: '001001001101010',
  K: '101101110101101', L: '100100100100111', M: '101111111101101', N: '110101101101101', O: '010101101101010',
  P: '110101110100100', Q: '010101101110011', R: '110101110101101', S: '011100010001110', T: '111010010010010',
  U: '101101101101111', V: '101101101101010', W: '101101111111101', X: '101101010101101', Y: '101101010010010',
  Z: '111001010100111', 0: '111101101101111', 1: '010110010010111', 2: '110001010100111', 3: '110001010001110',
  4: '101101111001001', 5: '111100110001110', 6: '011100111101111', 7: '111001010010010', 8: '111101111101111',
  9: '111101111001110', '%': '101001010100101', '.': '000000000000010', '·': '000000010000000', '/': '001001010100100',
  '!': '010010010000010', '?': '110001010000010', '-': '000000111000000', '+': '000010111010000', '€': '011100111100011',
  '✓': '000001001101010', '×': '000101010101000', ':': '000010000010000', '(': '010100100100010', ')': '010001001001010',
  '>': '100010001010100', '<': '001010100010001', "'": '010010000000000', '&': '010101010101011', ' ': '000000000000000',
  '…': '000000000000101',
};
const F57 = {
  0: '01110100011001110101110011000101110', 1: '00100011000010000100001000010001110', 2: '01110100010000100010001000100011111',
  3: '11110000010000101110000010000111110', 4: '00010001100101010010111110001000010', 5: '11111100001111000001000011000101110',
  6: '00110010001000011110100011000101110', 7: '11111000010001000100010000100001000', 8: '01110100011000101110100011000101110',
  9: '01110100011000101111000010001001100', '€': '00111010001111001000111100100000111', '%': '11001110100001000100010000101110011',
  '✓': '00000000010000100010101001000000000', '×': '00000100010101000100010101000100000', '.': '00000000000000000000000000110001100',
  '+': '00000001000010011111001000010000000', '-': '00000000000000011111000000000000000', ' ': '00000000000000000000000000000000000',
  '/': '00001000010001000100010001000010000',
};
function small(buf, str, x, y, k, align) {   // 3x5, 4 px advance
  str = String(str).toUpperCase();
  const w = str.length * 4 - 1;
  if (align === 'c') x -= Math.floor(w / 2); else if (align === 'r') x -= w;
  for (const ch of str) {
    const g = F35[ch] || F35['?'];
    for (let j = 0; j < 5; j++) for (let i = 0; i < 3; i++) if (g[j * 3 + i] === '1') buf.px(x + i, y + j, k);
    x += 4;
  }
  return w;
}
function smallWidth(str) { return String(str).length * 4 - 1; }

let PIX = null;   // scratch canvas for Pixelify
const RASTER = {};
// Pixelify draws on a grid of 1/11 em, so at 110 px one font px is 10 canvas px: sample each one's centre
function wordsRaster(str) {
  if (RASTER[str]) return RASTER[str];
  if (!PIX) { PIX = document.createElement('canvas'); PIX.width = 2400; PIX.height = 160; }
  const g = PIX.getContext('2d', {willReadFrequently: true});
  g.clearRect(0, 0, PIX.width, PIX.height);
  g.font = '110px Pixelify';
  g.textBaseline = 'alphabetic';
  g.fillStyle = '#000';
  const base = 110;   // baseline row 11 of the font grid
  g.fillText(str, 20, base);
  const cols = Math.ceil((g.measureText(str).width + 40) / 10);
  const data = g.getImageData(0, 0, PIX.width, PIX.height).data;
  const rows = [];
  for (let k = 0; k < 13; k++) {   // font rows: capitals on rows 4..10 (baseline after row 10)
    const r = [], y = (k + 0) * 10 + 5;
    for (let c = 0; c < cols; c++) r.push(data[(y * PIX.width + c * 10 + 5) * 4 + 3] >= 128 ? 1 : 0);
    rows.push(r);
  }
  let first = cols, last = -1;
  rows.forEach(r => r.forEach((v, x) => { if (v) { first = Math.min(first, x); last = Math.max(last, x); } }));
  return (RASTER[str] = {rows, first, last, w: last >= first ? last - first + 1 : 0, top: 2});
}
// words: top-left of the capitals at (x, y); scale 1 or 2
function words(buf, str, x, y, k, align, scale) {
  scale = scale || 1;
  if (str.indexOf(' ') >= 0) {
    const ws = str.split(' ').filter(Boolean), gap = 4 * scale;
    const total = ws.reduce((a, q) => a + wordsWidth(q, scale), 0) + gap * (ws.length - 1);
    if (align === 'c') x -= Math.floor(total / 2); else if (align === 'r') x -= total;
    ws.forEach(q => { x += words(buf, q, x, y, k, 'l', scale) + gap; });
    return total;
  }
  const r = wordsRaster(str);
  const w = r.w * scale;
  if (align === 'c') x -= Math.floor(w / 2); else if (align === 'r') x -= w;
  r.rows.forEach((row, j) => row.forEach((v, i) => {
    if (!v) return;
    const X = x + (i - r.first) * scale, Y = y + (j + r.top - 6) * scale;
    for (let a = 0; a < scale; a++) for (let b = 0; b < scale; b++) buf.px(X + a, Y + b, k);
  }));
  return w;
}
function wordsWidth(str, scale) {
  scale = scale || 1;
  if (str.indexOf(' ') >= 0) { const ws = str.split(' ').filter(Boolean); return ws.reduce((a, q) => a + wordsWidth(q, scale), 0) + 4 * scale * (ws.length - 1); }
  return wordsRaster(str).w * scale;
}
function digits(buf, str, x, y, k, align) {   // 5x7, 6 px advance
  str = String(str);
  const w = str.length * 6 - 1;
  if (align === 'c') x -= Math.floor(w / 2); else if (align === 'r') x -= w;
  for (const ch of str) {
    const g = F57[ch] || F57[' '];
    for (let j = 0; j < 7; j++) for (let i = 0; i < 5; i++) if (g[j * 5 + i] === '1') buf.px(x + i, y + j, k);
    x += 6;
  }
  return w;
}
// mixed line: letters in Pixelify, digits and money in the 5x7 face, both 7 px tall on one baseline
function line(buf, str, x, y, k, align) {
  const parts = str.match(/[0-9€%✓×.+\-/]+|[^0-9€%✓×.+\-/]+/g) || [];
  const isNum = p => /^[0-9€%✓×.+\-/]+$/.test(p);
  const widthOf = p => isNum(p) ? p.length * 6 - 1 : (p.trim() ? wordsWidth(p.trim()) + (p.startsWith(' ') ? 4 : 0) + (p.endsWith(' ') ? 4 : 0) : 4);
  const total = parts.reduce((s, p, i) => s + widthOf(p) + (i ? 1 : 0), 0);
  if (align === 'c') x -= Math.floor(total / 2); else if (align === 'r') x -= total;
  parts.forEach((p, i) => {
    if (i) x += 1;
    if (isNum(p)) { digits(buf, p, x, y, k); }
    else if (p.trim()) { words(buf, p.trim(), x + (p.startsWith(' ') ? 4 : 0), y, k); }
    x += widthOf(p);
  });
  return total;
}

// neon: the letters' core, a 1 px tube colour around them, a dithered halo beyond (the title's sign)
function neon(buf, str, cx, y, core, tube, halo, scale) {
  const tmp = new Buf(buf.w, buf.h);
  words(tmp, str, cx, y, core, 'c', scale);
  const on = (X, Y) => X >= 0 && Y >= 0 && X < tmp.w && Y < tmp.h && tmp.d[(Y * tmp.w + X) * 4 + 3];
  const w = wordsWidth(str, scale);
  const lx0 = cx - Math.floor(w / 2), lx1 = lx0 + w - 1, ty0 = y, ty1 = y + 7 * scale - 1;
  // the glow is a block round the word (the title's sign): never inside a letter's counters
  for (let Y = ty0 - 3; Y <= ty1 + 3; Y++) for (let X = lx0 - 4; X <= lx1 + 4; X++) {
    const dx = X < lx0 ? lx0 - X : X > lx1 ? X - lx1 : 0, dy = Y < ty0 ? ty0 - Y : Y > ty1 ? Y - ty1 : 0;
    const d = Math.max(dx, dy);
    if (d === 0) { if (!on(X, Y) && on(X - 1, Y - 1)) buf.px(X, Y, tube); continue; }   // the tube's 1 px depth
    if (d <= 3 && X % 2 === 0 && Y % 2 === 0) buf.px(X, Y, halo);   // a 25 % glow round the word
  }
  buf.blit(tmp, 0, 0);
}

// ---------------------------------------------------------------- the store (PR #126 StoreArt, ported)
// World art x = view x + VIEW_X. The machine's stop shows the store's right end; the rows are the stage's:
// the top bar's foot (28) to the counter's top (180), then the charcoal laminate.
const VIEW_X = 560;
const ST = {
  TOP: 28, BOTTOM: 180, CEILING_FOOT: 39, GLASS_LEFT: 150, GLASS_TOP: 46, GLASS_BOTTOM: 100, MULLION_STEP: 70, MULLION_WIDTH: 3,
  SKY_STOPS: [0.5, 0.86, 0.92], SKY: ['2', '3', '4', 'o'],
  ROOF: [9, 13, 7, 15, 11, 6, 12, 17, 8, 10, 14, 7, 11, 16, 9, 12, 6, 13], WINDOW_EVERY: 4,
  REFLECTION_XS: [204, 418, 632, 846, 1060], REFLECTION_STEPS: 14,
  SHELVING_TOP: 100, SHELF_YS: [105, 124], STOCK_FOOT: 15, LIP: 3, STOCK_W: 5, STOCK_GAP: 1, FACING_GAP: 4,
  STOCK: [['2', '3'], ['J', 'E'], ['U', 'f'], ['s', '='], ['q', 'r'], ['2', '3'], ['J', '-'], ['u', 'm']],
  LAMPS: [588, 724, 830, 966, 1100], CONE_TOP: 39, CONE_SLOPE: 0.42, CONE_REACH: 150, CONE_STRENGTH: 1.6, DITHER_BAND: 0.45,
};
function lightAt(ax, ay, lamps) {
  const dy = ay - ST.CONE_TOP; if (dy < 0 || dy > ST.CONE_REACH) return 0;
  const half = 3 + dy * ST.CONE_SLOPE; let best = 0;
  for (const cx of lamps) { const t = Math.abs(ax - cx) / half; if (t < 1) best = Math.max(best, (1 - t * t) * (1 - Math.pow(dy / ST.CONE_REACH, 2)) * ST.CONE_STRENGTH); }
  return best;
}
function paintStore(buf, opt) {
  const dark = new Buf(W, H), lit = new Buf(W, H);
  const R = (x, y, w, h, kd, kl) => { dark.rect(x - VIEW_X, y, w, h, kd); lit.rect(x - VIEW_X, y, w, h, kl); };
  const L = VIEW_X, Rt = VIEW_X + W;
  R(L, 0, W, ST.CEILING_FOOT, '8', '1');
  R(L, ST.CEILING_FOOT, W, 1, 't', 's');
  R(L, ST.CEILING_FOOT + 1, W, ST.BOTTOM, '1', '2');
  // glass
  const gh = ST.GLASS_BOTTOM - ST.GLASS_TOP;
  for (let y = ST.GLASS_TOP; y < ST.GLASS_BOTTOM; y++) {
    const share = (y - ST.GLASS_TOP) / gh; let band = 0;
    while (band < ST.SKY_STOPS.length && share >= ST.SKY_STOPS[band]) band++;
    R(L, y, W, 1, ST.SKY[band], ST.SKY[band]);
  }
  const e1 = ST.GLASS_TOP + Math.floor(gh * ST.SKY_STOPS[0]) - 2, e2 = ST.GLASS_TOP + Math.floor(gh * ST.SKY_STOPS[1]) - 2;
  [dark, lit].forEach(p => { p.dither(0, e1, W, 2, ST.SKY[1], 2); });
  [dark, lit].forEach(p => { for (let y = e2; y < e2 + 2; y++) for (let x = 0; x < W; x++) if ((x + VIEW_X) % 2 === 0 && y % 2 === 0) p.px(x, y, ST.SKY[2]); });
  let x = ST.GLASS_LEFT, n = 0;
  while (x < Rt) {
    const w = 14 + (n * 7) % 12, roof = ST.ROOF[n % ST.ROOF.length];
    if (x + w > L) {
      R(x, ST.GLASS_BOTTOM - roof, w, roof, '1', '1');
      for (let k = 0; k < 2; k++) {
        const wy = ST.GLASS_BOTTOM - roof + 3 + k * 4;
        if ((n + k) % ST.WINDOW_EVERY === 0 && wy < ST.GLASS_BOTTOM - 2) R(x + 3 + (n * 5 + k * 6) % Math.max(1, w - 5), wy, 1, 1, 'y', 'y');
      }
    }
    x += w; n++;
  }
  ST.REFLECTION_XS.forEach(rx => { for (let k = 0; k < ST.REFLECTION_STEPS; k++) R(rx + k, ST.GLASS_TOP + 30 - k * 2, 1, 2, '3', '4'); });
  for (let mx = ST.GLASS_LEFT; mx < Rt; mx += ST.MULLION_STEP) R(mx, ST.GLASS_TOP - 2, ST.MULLION_WIDTH, gh + 4, 's', '3');
  R(L, ST.GLASS_TOP - 3, W, 3, 's', '3');
  R(L, ST.GLASS_BOTTOM, W, 2, 's', '3');
  // shelving
  R(L, ST.SHELVING_TOP, W, ST.BOTTOM - ST.SHELVING_TOP, 't', 's');
  R(L, ST.SHELVING_TOP, W, 2, 's', 'I');
  ST.SHELF_YS.forEach((sy, row) => {
    let sx = -160 - 6 * row, k = row * 3;
    while (sx < Rt) {
      const col = ST.STOCK[(k * 3 + row) % ST.STOCK.length], facings = 4 + (k * 3) % 3, sh = 12 - (k % 2) * 2;
      if (sx + 40 > L) for (let f = 0; f < facings; f++) R(sx + f * (ST.STOCK_W + ST.STOCK_GAP), sy + ST.STOCK_FOOT - sh, ST.STOCK_W, sh, col[0], col[1]);
      sx += facings * (ST.STOCK_W + ST.STOCK_GAP) + ST.FACING_GAP; k++;
    }
    R(L, sy + ST.STOCK_FOOT, W, ST.LIP, 'K', 'H');
    R(L, sy + ST.STOCK_FOOT, W, 1, 'J', 'D');
  });
  const lamps = opt.lamps || ST.LAMPS;
  for (let y = 0; y < ST.BOTTOM; y++) for (let vx = 0; vx < W; vx++) {
    const ax = vx + VIEW_X, th = (BAYER[(y & 3) * 4 + (ax & 3)] + 0.5) / 16;
    const on = lightAt(ax, y, lamps) > 0.5 + (th - 0.5) * ST.DITHER_BAND;
    const src = on ? lit : dark, i = (y * W + vx) * 4;
    if (src.d[i + 3]) { buf.d[i] = src.d[i]; buf.d[i + 1] = src.d[i + 1]; buf.d[i + 2] = src.d[i + 2]; buf.d[i + 3] = 255; }
  }
  // the pendant lamps themselves (shades under the ceiling)
  lamps.forEach(cx => {
    const v = cx - VIEW_X; if (v < -10 || v > W + 10) return;
    buf.vl(v, ST.TOP, 6, 'I');
    buf.rect(v - 6, ST.TOP + 6, 13, 3, 'H'); buf.hl(v - 6, ST.TOP + 6, 13, 'D');
    buf.rect(v - 7, ST.TOP + 9, 15, 1, 'I'); buf.rect(v - 3, ST.TOP + 10, 7, 1, 'y');
  });
  // the counter's charcoal laminate below the store (one laminate for counter, belt surround, register)
  buf.rect(0, ST.BOTTOM, W, H - ST.BOTTOM, 'N');
  buf.hl(0, ST.BOTTOM, W, 'H'); buf.hl(0, ST.BOTTOM + 1, W, 'J'); buf.hl(0, ST.BOTTOM + 2, W, 'K');
  buf.dither(0, ST.BOTTOM + 3, W, 2, 'K', 2);
  for (let sx = 40; sx < W; sx += 120) { buf.vl(sx, ST.BOTTOM + 5, 160, 'K'); buf.vl(sx + 1, ST.BOTTOM + 5, 160, 'J'); }   // laminate seams
  buf.dither(0, 336, W, 10, 'K', 2);
  // floor at the foot: the store's floor seen past the counter end
  buf.rect(0, 346, W, 14, 't'); buf.hl(0, 346, W, 's');
  for (let fx = 0; fx < W; fx += 16) buf.vl(fx, 347, 13, '8');
}

// ---------------------------------------------------------------- the machine
const BODY = {
  cream: {face: 'c', light: 'w', shade: 'b', deep: 'a', trim: '4', trimD: '3', name: 'Cream enamel'},
  teal: {face: '4', light: '5', shade: '3', deep: '2', trim: 'c', trimD: 'b', name: 'Teal enamel'},
  tomato: {face: 'R', light: 'o', shade: 'r', deep: 'q', trim: 'c', trimD: 'b', name: 'Tomato enamel'},
};
// geometry (art px)
const M = {x: 232, w: 176, headY: 34, headH: 46, bodyY: 82, bodyB: 318, baseB: 346};
M.cx = M.x + M.w / 2;
const SLOT = {x: 246, y: 90, w: 148};
const LED = {x: 244, y: 100, w: 152, h: 24};
const WIN = {x: 244, y: 132, w: 152, h: 66};
const KEYS = [{x: 246, y: 208, w: 70, h: 38, id: 'new'}, {x: 324, y: 208, w: 70, h: 38, id: 'up'}];
const TRAY = {x: 244, y: 254, w: 152, h: 60};
const BAYS = [0, 1, 2].map(i => ({x: TRAY.x + 2 + i * 50, y: TRAY.y + 3, w: 48, h: 48}));
const BIN = {x: 418, y: 314, w: 24, h: 32};
const PEDESTAL_XS = [276, 320, 364];

function paintMachine(buf, st, t) {
  const B = BODY[st.body] || BODY.cream, P = st.premium;
  const x = M.x, w = M.w;
  // floor shadow
  buf.dither(x - 6, M.baseB - 1, w + 12, 3, '8', 2);
  // ---- hanging rods and the head sign
  [x + 22, x + w - 23].forEach(rx => { buf.vl(rx, ST.TOP, M.headY - ST.TOP, 'I'); buf.vl(rx + 1, ST.TOP, M.headY - ST.TOP, 'H'); });
  const hy = M.headY, hh = M.headH;
  buf.rect(x + 2, hy, w - 4, hh, P ? 'v' : '8');
  buf.frame(x + 2, hy, w - 4, hh, '#');
  buf.frame(x + 3, hy + 1, w - 6, hh - 2, P ? 'L' : 'D');
  buf.hl(x + 4, hy + 2, w - 8, P ? 'n' : 'B');
  [[x + 5, hy + 3], [x + w - 8, hy + 3], [x + 5, hy + hh - 6], [x + w - 8, hy + hh - 6]].forEach(([a, b]) => buf.screw(a, b));
  if (P) {   // chasing bulbs round the sign
    const phase = Math.floor(t * 8) % 3;
    let k = 0;
    const bulb = (bx, by) => { const on = (k++ % 3) === phase; buf.rect(bx, by, 2, 2, on ? 'n' : 'u'); if (on) buf.px(bx, by, 'Y'); };
    for (let bx = x + 12; bx < x + w - 12; bx += 6) bulb(bx, hy + 4);
    for (let by = hy + 9; by < hy + hh - 10; by += 6) bulb(x + w - 8, by);
    for (let bx = x + w - 14; bx > x + 10; bx -= 6) bulb(bx, hy + hh - 6);
    for (let by = hy + hh - 12; by > hy + 8; by -= 6) bulb(x + 6, by);
  }
  const flick = st.flicker && Math.floor(t * 10) % 37 === 36;   // the neon's rare two-frame blink
  if (P) {
    neon(buf, 'PREMIUM', M.cx, hy + 9, 'Y', 'n', 'L', 2);
    neon(buf, 'REWARDS', M.cx, hy + 27, 'Y', 'n', 'L', 2);
  } else {
    neon(buf, 'RECEIPT', M.cx, hy + 9, flick ? '3' : 'j', flick ? '2' : '5', '3', 2);
    neon(buf, 'REWARDS', M.cx, hy + 27, 'Y', 'M', 'm', 2);
  }
  // ---- the cabinet body
  const by = M.bodyY, bb = M.bodyB;
  buf.rect(x, by, w, bb - by, '#');
  buf.rect(x + 1, by + 1, w - 2, bb - by - 2, B.face);
  buf.hl(x + 1, by + 1, w - 2, B.light); buf.vl(x + 1, by + 1, bb - by - 2, B.light);
  buf.vl(x + w - 2, by + 1, bb - by - 2, B.shade); buf.vl(x + w - 3, by + 1, bb - by - 2, B.shade);
  buf.cut(x, by, w, bb - by);
  // side trim stripes (or the premium's gold trim)
  const trim = P ? 'L' : B.trim, trimD = P ? 'l' : B.trimD;
  buf.vl(x + 4, by + 4, bb - by - 8, trim); buf.vl(x + 5, by + 4, bb - by - 8, trimD);
  buf.vl(x + w - 6, by + 4, bb - by - 8, trim); buf.vl(x + w - 7, by + 4, bb - by - 8, trimD);
  if (P) { buf.hl(x + 4, by + 3, w - 9, 'L'); buf.hl(x + 4, bb - 4, w - 9, 'l'); }

  // ---- recesses: the face is pressed in round the working parts (shade top/left, light bottom/right)
  const recess = (rx, ry, rw, rh) => {
    buf.rect(rx, ry, rw, rh, B.shade); buf.hl(rx, ry, rw, B.deep); buf.vl(rx, ry, rh, B.deep);
    buf.hl(rx, ry + rh - 1, rw, B.light); buf.vl(rx + rw - 1, ry, rh, B.light);
  };
  recess(LED.x - 4, LED.y - 4, LED.w + 8, WIN.y + WIN.h - LED.y + 8);
  recess(KEYS[0].x - 6, KEYS[0].y - 7, KEYS[1].x + KEYS[1].w - KEYS[0].x + 12, KEYS[0].h + 14);
  recess(TRAY.x - 4, TRAY.y - 4, TRAY.w + 8, TRAY.h + 7);
  // a brass badge on the crown and two rivet rows
  for (let rx = x + 12; rx < x + w - 12; rx += 12) { buf.px(rx, by + 4, B.deep); buf.px(rx, bb - 3, B.deep); }
  // ---- receipt slot
  small(buf, 'INSERT RECEIPT', SLOT.x, SLOT.y + 1, B.deep === 'a' ? '%' : 'w');
  const sx = SLOT.x + 64, sw = SLOT.w - 64;
  buf.rect(sx - 2, SLOT.y - 1, sw + 4, 7, P ? 'L' : 'D'); buf.hl(sx - 2, SLOT.y - 1, sw + 4, P ? 'n' : 'B');
  buf.frame(sx - 3, SLOT.y - 2, sw + 6, 9, '#');
  buf.rect(sx, SLOT.y + 2, sw, 2, 'N'); buf.hl(sx, SLOT.y + 4, sw, 'K');
  // the receipt tongue: whole in INSERT, feeding in READING, a gold stub on a premium visit
  const feed = st.stage === 'insert' ? 0 : st.stage === 'reading' ? Math.min(1, (t % 2.4) / 1.6) : 1;
  const tongue = Math.round(9 * (1 - feed));
  if (tongue > 0) {
    const tx = sx + Math.floor(sw / 2) - 14, ty = SLOT.y + 2 - tongue;
    buf.rect(tx, ty, 28, tongue, P ? 'y' : 'w'); buf.vl(tx, ty, tongue, '#'); buf.vl(tx + 27, ty, tongue, '#');
    for (let j = 3; j < tongue - 1; j += 3) buf.hl(tx + 4, ty + j, 14 + (j * 5) % 8, P ? 'm' : ':');
    for (let i = 0; i < 28; i += 2) buf.px(tx + i, ty, (i / 2) % 2 ? '#' : (P ? 'y' : 'w'));   // torn edge
  }

  // ---- the LED housing (steel, a screw in each corner: the toy screen's counters)
  buf.panel(LED.x, LED.y, LED.w, LED.h, 'D', 'B', 'E', '#');
  [[LED.x + 2, LED.y + 2], [LED.x + LED.w - 5, LED.y + 2], [LED.x + 2, LED.y + LED.h - 5], [LED.x + LED.w - 5, LED.y + LED.h - 5]].forEach(([a, b]) => buf.screw(a, b));
  const lx = LED.x + 7, ly = LED.y + 3, lw = LED.w - 14, lh = LED.h - 6;
  buf.rect(lx, ly, lw, lh, 'N'); buf.frame(lx, ly, lw, lh, 'K');
  for (let j = 1; j < lh - 1; j += 2) for (let i = 1; i < lw - 1; i += 2) buf.px(lx + i, ly + j, 'K');   // the unlit LED grid
  paintDisplay(buf, st, t, lx, ly, lw, lh);

  // ---- the stockroom window
  small(buf, 'STOCKROOM', M.cx, WIN.y - 6, B.deep === 'a' ? '%' : 'w', 'c');
  buf.panel(WIN.x, WIN.y, WIN.w, WIN.h, 'D', 'B', 'E', '#');
  const gx = WIN.x + 4, gy = WIN.y + 4, gw = WIN.w - 8, gh = WIN.h - 8;
  buf.rect(gx, gy, gw, gh, '1'); buf.frame(gx - 1, gy - 1, gw + 2, gh + 2, 'I');
  // a lamp in the window's top, its cone dithered like the store's pools
  buf.rect(M.cx - 10, gy, 20, 2, 'H'); buf.hl(M.cx - 8, gy + 2, 16, 'Y');
  for (let j = 3; j < gh - 2; j++) {
    const half = 8 + j * 1.25;
    for (let i = -Math.floor(half); i <= Math.floor(half); i++) {
      const X = M.cx + i, Y = gy + j; if (X <= gx || X >= gx + gw - 1) continue;
      const tt = Math.abs(i) / half, th = (BAYER[(Y & 3) * 4 + (X & 3)] + 0.5) / 16;
      if ((1 - tt * tt) * (1 - j / gh) * 1.7 > 0.5 + (th - 0.5) * 0.6) buf.px(X, Y, '2');
    }
  }
  // the shelf the tickets stand on
  buf.rect(gx, gy + gh - 9, gw, 3, 'E'); buf.hl(gx, gy + gh - 9, gw, 'C'); buf.rect(gx, gy + gh - 6, gw, 6, '8');
  // pedestals
  PEDESTAL_XS.forEach(px => { buf.rect(px - 9, gy + gh - 12, 18, 3, 'D'); buf.hl(px - 9, gy + gh - 12, 18, 'B'); buf.frame(px - 10, gy + gh - 13, 20, 5, '#'); });
  // glass reflections (drawn after the sprites, see drawSprites)

  // ---- the two keys
  KEYS.forEach((k, i) => paintKey(buf, st, t, k, i, B, P));

  // ---- the prize tray: three bays behind a glass flap
  buf.panel(TRAY.x, TRAY.y, TRAY.w, TRAY.h, 'D', 'B', 'E', '#');
  buf.rect(TRAY.x + 2, TRAY.y + 2, TRAY.w - 4, 50, 'K');
  BAYS.forEach((b, i) => {
    const lit = st.stage === 'reveal' || st.stage === 'draw';
    buf.rect(b.x, b.y, b.w, b.h, lit ? (P ? 'k' : '8') : 'N');
    if (lit) { for (let j = 0; j < 14; j++) for (let ii = 0; ii < b.w; ii++) if ((ii + j) % 2 === 0 && j < 14 - Math.abs(ii - 24) / 2) buf.px(b.x + ii, b.y + j, P ? 'l' : '2'); }
    if (i) buf.vl(b.x - 1, TRAY.y + 2, 50, 'E');
  });
  // the flap's lip and its label
  buf.rect(TRAY.x + 1, TRAY.y + 51, TRAY.w - 2, TRAY.h - 52, 'C'); buf.hl(TRAY.x + 1, TRAY.y + 51, TRAY.w - 2, 'A');
  buf.hl(TRAY.x + 1, TRAY.y + TRAY.h - 2, TRAY.w - 2, 'E');
  small(buf, st.stage === 'reveal' ? 'PICK ONE PRIZE' : 'TAKE YOUR PRIZE', M.cx, TRAY.y + 53, 'I', 'c');

  // ---- the plinth (the toy machines' coin base, wider)
  const py = bb;
  buf.rect(x + 6, py, w - 12, M.baseB - py - 4, 'H'); buf.frame(x + 6, py, w - 12, M.baseB - py - 4, '#');
  buf.hl(x + 7, py + 1, w - 14, 'D');
  for (let vx = x + 24; vx < x + w - 24; vx += 8) buf.rect(vx, py + 7, 5, 2, 'K');
  buf.rect(x + 14, M.baseB - 4, 20, 4, 'I'); buf.rect(x + w - 34, M.baseB - 4, 20, 4, 'I');
  buf.frame(x + 14, M.baseB - 4, 20, 4, '#'); buf.frame(x + w - 34, M.baseB - 4, 20, 4, '#');
  small(buf, 'NEXT CUSTOMER · REG 3', M.cx, py + 15, 'C', 'c');

  // ---- the SKIP pedal bin beside the plinth
  paintBin(buf, st, t);
}

function paintKey(buf, st, t, k, i, B, P) {
  const chosen = st.chosen === k.id;
  const lit = st.stage === 'choose' || (chosen && (st.stage === 'draw' || st.stage === 'reveal'));
  const hover = st.hover === k.id && st.stage === 'choose';
  const pressed = chosen && (st.stage === 'draw' || st.stage === 'reveal');
  const dimmed = !lit;
  const faces = k.id === 'new'
    ? {face: 'c', light: 'w', shade: 'b', deep: 'a', ink: '#', sub: '%'}
    : {face: '4', light: '5', shade: '3', deep: '2', ink: 'w', sub: '6'};
  const f = dimmed ? {face: 'D', light: 'C', shade: 'E', deep: 'H', ink: 'H', sub: 'E'} : faces;
  // the key's well
  buf.rect(k.x - 2, k.y - 2, k.w + 4, k.h + 4, '#');
  buf.rect(k.x - 1, k.y - 1, k.w + 2, k.h + 2, 'N');
  // the indicator lamp ring round the well: blinks on a lit key, steady gold on hover, PREMIUM gold
  if (lit) {
    const on = hover || chosen || Math.floor(t * 2.5 + i) % 2 === 0;
    const ring = P ? (on ? 'n' : 'L') : (on ? 'M' : 'm');
    for (let ii = 0; ii < k.w + 4; ii += 4) { buf.rect(k.x - 2 + ii, k.y - 4, 2, 1, ring); buf.rect(k.x - 2 + ii, k.y + k.h + 3, 2, 1, ring); }
  }
  const depth = pressed ? 1 : (hover ? 5 : 4);
  const top = k.y + (4 - depth) + (pressed ? 3 : 0);
  const capH = k.h - 4;
  // the key's side (depth) then its cap
  buf.rect(k.x, top + capH - 2, k.w, depth + 2, f.deep);
  buf.rect(k.x, top, k.w, capH, f.face);
  buf.hl(k.x, top, k.w, f.light); buf.vl(k.x, top, capH, f.light);
  buf.hl(k.x, top + capH - 1, k.w, f.shade); buf.vl(k.x + k.w - 1, top, capH, f.shade);
  buf.frame(k.x - 1, top - 1, k.w + 2, capH + depth + 1, '#');
  // the caption: hard pixel words, small print under
  const label = k.id === 'new' ? 'NEW ITEMS' : 'UPGRADE';
  const subs = k.id === 'new' ? ['ADD TO CART'] : ['IMPROVE WHAT', 'YOU OWN'];
  const cx = k.x + Math.floor(k.w / 2);
  words(buf, label, cx, top + 12, f.ink, 'c');
  subs.forEach((s, j) => small(buf, s, cx, top + 21 + j * 6, f.sub, 'c'));
}

function paintBin(buf, st, t) {
  const b = BIN, open = st.hover === 'bin' && st.stage === 'reveal';
  buf.dither(b.x - 2, b.y + b.h - 1, b.w + 4, 2, '8', 2);
  buf.panel(b.x, b.y + 6, b.w, b.h - 6, 'D', 'B', 'E', '#');
  for (let i = 4; i < b.w - 4; i += 4) buf.vl(b.x + i, b.y + 10, b.h - 16, 'E');
  // the pedal
  buf.rect(b.x + 6, b.y + b.h - 3, 12, 3, open ? 'K' : 'J'); buf.frame(b.x + 6, b.y + b.h - (open ? 2 : 3), 12, open ? 2 : 3, '#');
  // the lid: shut, or tipped open on hover
  if (open) {
    for (let j = 0; j < 10; j++) buf.rect(b.x - 4 + j, b.y - 6 - j + 6, 3, 2, j === 0 ? '#' : 'C');
    buf.rect(b.x + 2, b.y + 6, b.w - 4, 3, 'N');
  } else {
    buf.rect(b.x - 1, b.y + 2, b.w + 2, 5, 'C'); buf.hl(b.x - 1, b.y + 2, b.w + 2, 'A'); buf.frame(b.x - 2, b.y + 1, b.w + 4, 7, '#');
    buf.rect(b.x + 9, b.y - 1, 6, 2, 'E'); buf.frame(b.x + 8, b.y - 2, 8, 4, '#');
  }
  small(buf, 'SKIP', b.x + 12, b.y + 14, st.stage === 'reveal' ? 'K' : 'H', 'c');
}

const ODDS = {new: [65, 28, 7], up: [75, 22, 3]};
const ODDS_PREMIUM = {new: [0, 80, 20], up: [0, 88, 12]};   // PREMIUM: every drop at least RARE (COMMON's share renormalised away)
function paintDisplay(buf, st, t, x, y, w, h) {
  const amber = st.premium ? 'n' : 'M', dim = st.premium ? 'L' : 'm';
  const c = x + Math.floor(w / 2);
  const say = (s, k) => line(buf, s, c, y + 5, k || amber, 'c');
  const blink = Math.floor(t * 2) % 2 === 0;
  switch (st.stage) {
    case 'insert': if (blink) say('INSERT RECEIPT'); else small(buf, 'SPEND €96 · QUOTA €73 MET', c, y + 7, dim, 'c'); break;
    case 'reading': {
      const dots = '.'.repeat(1 + Math.floor(t * 3) % 3);
      line(buf, 'READING', c - 6, y + 5, amber, 'c'); digits(buf, dots, c + 22, y + 5, amber);
      break;
    }
    case 'choose': {
      if (st.hover === 'new' || st.hover === 'up') {
        const o = (st.premium ? ODDS_PREMIUM : ODDS)[st.hover], cols = ['C', '7', 'n'];
        // the rarity bars, their widths the odds, the numbers over them (a 0 % rarity has no bar)
        let bx = x + 4; const bw = w - 8;
        o.forEach((p, i) => {
          if (!p) return;
          const ww = Math.max(16, Math.round(bw * p / 100) - 2);
          const left = Math.min(ww, x + w - 4 - bx);
          buf.rect(bx, y + 12, left, 4, cols[i]);
          digits(buf, p + '%', bx, y + 3, cols[i]);
          bx += left + 2;
        });
      } else {
        say(st.premium ? 'PREMIUM · PICK A KEY' : 'THANK YOU · PICK A KEY');
      }
      break;
    }
    case 'draw': say(st.premium ? 'EVERY DROP RARE+' : 'DRAWING 3 TICKETS'); break;
    case 'reveal': {
      if (st.hover === 'bin') { if (blink) say('BIN ALL 3?', 'R'); else say('BIN ALL 3?', 'r'); }
      else if (st.hover != null && /^p\d$/.test(st.hover)) { const p = PRIZES[+st.hover[1]]; say(p.say); }
      else say('PICK 1 OF 3');
      break;
    }
  }
}

// ---------------------------------------------------------------- sprites (drawn on the scaled canvas)
const PRIZES = [
  {item: 'strawberries', rarity: 'COMMON', tab: ['D', 'B', '#'], ticket: 'common', say: 'STRAWBERRIES · COMMON'},
  {item: 'croissant_big', rarity: 'RARE!', tab: ['4', '5', 'w'], ticket: 'rare', say: 'CROISSANT · BIG · RARE'},
  {item: 'lemon', rarity: 'LEGENDARY!!', tab: ['n', 'Y', '#'], ticket: 'legendary', say: 'LEMON · LEGENDARY!!'},
];
const PREMIUM_PRIZES = [
  {item: 'grapefruit_big', rarity: 'RARE!', tab: ['4', '5', 'w'], ticket: 'rare', say: 'GRAPEFRUIT · BIG · RARE'},
  {item: 'fruit_salad_big', rarity: 'RARE!', tab: ['4', '5', 'w'], ticket: 'rare', say: 'FRUIT SALAD · BIG · RARE'},
  {item: 'banana_golden', rarity: 'LEGENDARY!!', tab: ['n', 'Y', '#'], ticket: 'legendary', say: 'BANANA · GOLDEN!!'},
];

// overlay: after the buffer is put, sprites go on top at integer art px (scale s)
function drawSprites(g, img, st, t, s, buf2) {
  const P = st.premium, prizes = P ? PREMIUM_PRIZES : PRIZES;
  const gx = WIN.x + 4, gy = WIN.y + 4, gh = WIN.h - 8;
  const D = (im, x, y, w, h) => { if (im && im.complete && im.naturalWidth) g.drawImage(im, Math.round(x) * s, Math.round(y) * s, (w || im.naturalWidth) * s, (h || im.naturalHeight) * s); };
  // tickets: on their pedestals, riding down to the tray in DRAW, gone after
  const drawP = st.stage === 'draw' ? Math.min(1, (t % 3) / 1.6) : 0;
  PEDESTAL_XS.forEach((px, i) => {
    const tk = img['ticket_' + (P ? (i === 2 ? 'legendary' : 'rare') : 'common')];
    if (st.stage === 'reveal') return;
    let x0 = px - 12, y0 = gy + gh - 13 - 32;
    if (st.stage === 'draw') {
      const d = Math.max(0, Math.min(1, drawP * 1.4 - i * 0.2));
      const e = d < 0.5 ? 2 * d * d : 1 - Math.pow(-2 * d + 2, 2) / 2;
      x0 += ((BAYS[i].x + 12) - x0) * e; y0 += ((BAYS[i].y + 10) - y0) * e;
    }
    D(tk, x0, y0);
  });
  // window glass reflections over the tickets
  g.fillStyle = '#' + PAL['5']; g.globalAlpha = 0.35;
  for (let k = 0; k < 10; k++) { g.fillRect((gx + 8 + k) * s, (gy + 26 - k * 2) * s, s, 2 * s); g.fillRect((gx + 112 + k) * s, (gy + 40 - k * 2) * s, s, 2 * s); }
  g.globalAlpha = 1;
  // prizes in the tray
  if (st.stage === 'reveal') {
    prizes.forEach((p, i) => {
      const b = BAYS[i];
      const hov = st.hover === 'p' + i, binning = st.hover === 'bin';
      const shake = binning ? ((Math.floor(t * 20) + i) % 2 ? 1 : -1) : 0;
      const lift = hov ? -3 : 0;
      D(img[p.item], b.x + shake, b.y + lift - 2, 48, 48);
      // the rarity tab
      const tb = p.tab;
      const tw = Math.max(26, smallWidth(p.rarity) + 6);
      const tx = b.x + 24 - Math.floor(tw / 2), ty = b.y + 38 + lift;
      buf2.rect(tx, ty, tw, 9, tb[0]); buf2.hl(tx, ty, tw, tb[1]); buf2.frame(tx - 1, ty - 1, tw + 2, 11, '#');
      small(buf2, p.rarity, b.x + 24, ty + 2, tb[2], 'c');
      if (hov) { buf2.frame(b.x - 1, b.y - 1, b.w + 2, b.h + 2, 'n'); buf2.frame(b.x, b.y, b.w, b.h, 'Y'); }
      if (binning) { for (let k = 0; k < 5; k++) buf2.rect(b.x + 6 + k * 8, b.y + 4 + (k % 2) * 3, 4, 2, 'R'); }
    });
  }
  // the keys' icons
  KEYS.forEach(k => {
    const chosen = st.chosen === k.id, lit = st.stage === 'choose' || (chosen && (st.stage === 'draw' || st.stage === 'reveal'));
    const pressed = chosen && (st.stage === 'draw' || st.stage === 'reveal'), hover = st.hover === k.id && st.stage === 'choose';
    const depth = pressed ? 1 : (hover ? 5 : 4), top = k.y + (4 - depth) + (pressed ? 3 : 0);
    const im = k.id === 'new' ? img.cart : img.up;
    g.globalAlpha = lit ? 1 : 0.35;
    D(im, k.x + Math.floor(k.w / 2) - Math.floor(im.naturalWidth / 2), top + 2);
    g.globalAlpha = 1;
  });
}
