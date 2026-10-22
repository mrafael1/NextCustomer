// Purse A (#76 decide prep): a fat brown-leather frame purse drawn on a 48 x 60 texel grid (1 texel = 2 screen px in the
// scene). Every object is painted ink-first (its shape grown by one texel) and then filled, so each note, card and coin keeps
// its own 1-texel ink outline. Colours: art/src/palette.txt keys only (brown leather e f F h, mustard clasp u m M y Y, gold n
// for sparkles, green cash g G z, teal card 2 4 5 6). Contact shadows are drawn in code (a flat dark alpha), like the game.
// purseCanvas(step, opts) -> a <canvas> 48 x 60. step 0..4 (calm, peek, bulge, strain, burst).
// opts: still (reduced motion: nothing in the air, no sweat, no sparkle), verdict ('over' | 'on' | 'short'), drag ('+' | '-').
const PURSE_W = 48, PURSE_H = 60, PURSE_CX = 24, PURSE_GB = 55;
const PURSE_PAL = { '#': '#2b2420', e: '#4a3022', f: '#7a5232', F: '#a87a4e', h: '#d2a874', u: '#7a5a1c', m: '#b38425', M: '#e2b33c',
  y: '#f1d27a', Y: '#faecbc', n: '#ffcf3f', g: '#3d7a45', G: '#5fae5a', z: '#a5d17e', w: '#fbf7ee', 2: '#2a4d4b', 3: '#3a7672',
  4: '#4f9a94', 5: '#86c2b6', 6: '#c3e0d4' };
// a kiss-lock frame purse: half width at the frame (top), half width at the belly, body height, mouth gap (rows of open
// mouth), frame bow (texels); the body puffs out under the narrower frame and rounds off at the bottom
const PURSE_POSE = [
  { top: 8, belly: 10, ht: 13, gap: 0, bow: 0 },
  { top: 8, belly: 11, ht: 14, gap: 2, bow: 0 },
  { top: 9, belly: 12, ht: 15, gap: 3, bow: 0 },
  { top: 9, belly: 13, ht: 16, gap: 3, bow: 1 },
  { top: 10, belly: 12, ht: 15, gap: 6, bow: 0 },
];

function purseCanvas(step, opts = {}) {
  const G = Array.from({ length: PURSE_H }, () => Array(PURSE_W).fill(null));
  const set = (x, y, k) => { if (x >= 0 && y >= 0 && x < PURSE_W && y < PURSE_H) G[y][x] = k; };
  const obj = () => { const m = new Map(); return { m, put: (x, y, k) => m.set(x + ',' + y, [x, y, k]) }; };
  const paint = (o, ink = true) => {
    if (ink) o.m.forEach(([x, y]) => [[1, 0], [-1, 0], [0, 1], [0, -1]].forEach(([dx, dy]) => { if (!o.m.has((x + dx) + ',' + (y + dy))) set(x + dx, y + dy, '#'); }));
    o.m.forEach(([x, y, k]) => set(x, y, k));
  };
  const rows = (x, y, pat) => { const o = obj(); pat.forEach((r, j) => [...r].forEach((k, i) => { if (k !== '.') o.put(x + i, y + j, k); })); return o; };

  let P = { ...PURSE_POSE[step] };
  const v = opts.verdict, still = !!opts.still;
  if (v === 'on') P = { top: 8, belly: 11, ht: 14, gap: 0, bow: 0 };
  if (v === 'over') P = { top: 8, belly: 10, ht: 13, gap: 4, bow: 0 };
  if (v === 'short') P = { top: 8, belly: 12, ht: 12, gap: 2, bow: 0, sag: true };
  if (opts.drag === '-') P = { ...P, ht: P.ht - 2, top: P.top + 1, belly: P.belly + 1 };
  const lift = opts.drag === '+' ? 2 : 0;
  const cx = PURSE_CX, GB = PURSE_GB - lift, yT = GB - P.ht + 1;
  const mouthTop = yT - 1 - P.gap, backTop = yT - 3 - P.gap;
  const fx0 = cx - P.top - 1, fx1 = cx + P.top;   // frame bar ends

  // contact shadow: a stepped flat ellipse, falling 2 texels to the right (smaller while hopping)
  const shadow = [];
  const sw = P.belly + 1 - lift;
  for (let x = -sw; x <= sw; x++) { const e = Math.abs(x) > sw - 2 ? 1 : 2; shadow.push([cx + 2 + x, PURSE_GB + 1, e]); }

  // ---- handle: a leather arch between the frame ends (on the back bar when open). Once cash stands in the mouth the
  // handle flops forward over the body instead (drawn with the front), so the silhouette still says purse, never pot ----
  const flop = (step >= 2 && !v) || v === 'over' || v === 'short';
  if (!flop) { const o = obj(), ay = (P.gap ? backTop : yT - 1) - 1, a0 = cx - P.top + 2, a1 = cx + P.top - 3, H = 6;
    let py = null;
    for (let x = a0; x <= a1; x++) {
      const u = (x - a0) / (a1 - a0), y = ay - Math.round(H * Math.sqrt(Math.max(0, 1 - (2 * u - 1) ** 2)));
      const top = py === null ? y : Math.min(y, py), bot = py === null ? y : Math.max(y, py);
      for (let yy = top; yy <= bot; yy++) o.put(x, yy, yy === y && x > a0 + 1 && x < a1 - 1 ? 'F' : 'f');
      py = y;
    }
    o.put(a0, ay, 'm'); o.put(a0 + 1, ay, 'm'); o.put(a1, ay, 'm'); o.put(a1 - 1, ay, 'm');
    paint(o); }

  // ---- back of the mouth: the far frame bar and the dark inside ----
  if (P.gap) {
    const o = obj();
    for (let x = fx0; x <= fx1; x++) { o.put(x, backTop, 'M'); o.put(x, backTop + 1, 'm'); }
    for (let y = mouthTop; y <= yT - 2; y++) for (let x = fx0 + 1; x <= fx1 - 1; x++) {
      if (y === mouthTop && (x === fx0 + 1 || x === fx1 - 1)) continue;
      o.put(x, y, y === mouthTop ? 'f' : 'e');
    }
    // the far knob of the kiss lock, flipped back
    const kb = step === 4 ? cx + 2 : cx;
    if (!(v === 'on')) { o.put(kb, backTop - 2, 'y'); o.put(kb + 1, backTop - 2, 'M'); o.put(kb, backTop - 1, 'M'); o.put(kb + 1, backTop - 1, 'm'); }
    paint(o);
  }

  // ---- contents: banknotes and the card, rising from the mouth ----
  // A note is a wide rectangle with a lit top and left edge, a shaded right and bottom edge and a round mark near its top
  // (a "(€)" at this size); notes stand nearly straight (|skew| <= .35) and wads carry a paper band, so the cash never reads
  // as leaves in a pot.
  const note = (x, top, w, h, skew = 0, band = false) => {
    const o = obj(), mi = Math.floor(w / 2);
    // the euro mark (3 x 5) on notes tall enough to show it; small flying notes get a short bar instead
    const EURO = ['.gg', 'ggg', 'g..', 'ggg', '.gg'], big = h >= 8 && w >= 9, ey = 2, bandY = big ? 8 : 2;
    for (let j = 0; j < h; j++) {
      const off = Math.round((h - 1 - j) * skew);
      for (let i = 0; i < w; i++) {
        let k = j === h - 1 || i === w - 1 ? 'g' : (j === 1 || i === 1 || i === w - 2) ? 'z' : 'G';
        if (j === 0 || i === 0) k = 'G';
        if (big && j >= ey && j < ey + 5 && i >= mi - 1 && i <= mi + 1 && EURO[j - ey][i - mi + 1] === 'g') k = 'g';
        if (!big && j === Math.min(2, h - 2) && i >= mi - 1 && i <= mi + 1) k = 'g';
        if (band && j >= bandY && j <= bandY + 1) k = j === bandY ? 'Y' : 'M';
        o.put(x + i + off, top + j, k);
      }
    }
    paint(o);
  };
  const card = (x, top, w, h, skew = 0) => {
    const o = obj();
    for (let j = 0; j < h; j++) { const off = Math.round((h - 1 - j) * skew);
      for (let i = 0; i < w; i++) o.put(x + i + off, top + j, j === 0 ? '6' : j === 2 ? '2' : i === w - 1 ? '3' : '4'); }
    o.put(x + 1 + Math.round((h - 2) * skew), top + 1, 'M'); o.put(x + 2 + Math.round((h - 2) * skew), top + 1, 'M');
    paint(o);
  };
  const coin = (x, y, edge) => paint(edge ? rows(x, y, ['yMMm', 'mmmu']) : rows(x, y, ['.yM.', 'yMMm', 'MMmm', '.mu.']));
  const sparkle = (x, y) => paint(rows(x, y, ['..y..', '..y..', 'yynyy', '..y..', '..y..']), false);
  const bottom = yT;   // contents run down behind the front bar
  const up = (top) => bottom - top + 1;

  if (step === 4 && !v && !still) {
    // stepped rays from the mouth: the pop frame of the burst, in mustard pale with no ink
    const o = obj();
    [[0, -1], [1, -1], [-1, -1], [1, 0], [-1, 0], [2, -1], [-2, -1], [1, -2], [-1, -2]].forEach(([dx, dy]) => {
      const L = Math.hypot(dx, dy);
      for (let r = 9; r <= 17; r++) { if (r % 4 === 0) continue; const x = cx + Math.round(dx / L * r), y = mouthTop - 2 + Math.round(dy / L * r); o.put(x, y, 'Y'); o.put(x + 1, y, 'Y'); }
    });
    paint(o, false);
  }
  if (v === 'over') {
    note(cx - 6, mouthTop - 2, 12, up(mouthTop - 2), -0.2);
  } else if (v === 'short') {
    card(cx - 1, mouthTop - 2, 8, up(mouthTop - 2), 0.9);
  } else if (v === 'on') {
    // snapped shut: nothing shows
  } else if (step === 1) {
    card(cx + 1, mouthTop - 2, 8, up(mouthTop - 2));
  } else if (step === 2) {
    note(cx - 9, mouthTop - 4, 12, up(mouthTop - 4), -0.2);
    card(cx + 3, mouthTop - 3, 8, up(mouthTop - 3));
    note(cx - 5, mouthTop - 5, 12, up(mouthTop - 5), 0.1);
  } else if (step === 3) {
    // the wad is too big: a banded stack stands up, notes squeeze out sideways at both frame corners
    note(fx0 - 4, yT - 3, 9, 5, 0); note(fx1 - 4, yT - 3, 9, 5, 0);
    note(cx - 9, mouthTop - 5, 12, up(mouthTop - 5), -0.25);
    card(cx + 3, mouthTop - 5, 8, up(mouthTop - 5), 0.2);
    note(cx - 6, mouthTop - 7, 13, up(mouthTop - 7), 0, true);
  } else if (step === 4) {
    note(cx - 11, mouthTop - 6, 12, up(mouthTop - 6), -0.35);
    note(cx, mouthTop - 7, 11, up(mouthTop - 7), 0.25);
    card(cx - 3, mouthTop - 4, 8, up(mouthTop - 4), -0.15);
    note(cx - 6, mouthTop - 11, 13, up(mouthTop - 11), 0, true);
  }

  // ---- front: the leather body, its stitching, the front frame bar and the near knob ----
  { const o = obj();
    for (let y = yT; y <= GB; y++) {
      const t = (y - yT) / Math.max(1, GB - yT);
      const prof = P.sag ? t : Math.sin(Math.PI / 2 * Math.min(1, t / 0.55));
      let hw = Math.round(P.top + (P.belly - P.top) * prof);
      hw -= y === GB ? 3 : y === GB - 1 ? 2 : y === GB - 2 ? 1 : 0;
      const x0 = cx - hw, x1 = cx + hw - 1;
      const ry = y - yT, lit = Math.max(2, Math.round((P.belly - 6) * 1.2)), under = t > 0.68;
      for (let x = x0; x <= x1; x++) {
        // base mid-dark leather, so the light green cash and the light counter both separate from it in greyscale
        let k = 'f';
        // lit lobe: a stepped highlight in the upper-left half of the belly (brown, then brown light at its core)
        const lx = x - x0 - 1, edge = lit + 3 - Math.max(0, ry - 2 - lit);
        if (ry >= 1 && ry <= 2 + lit + 3 && lx >= 0 && lx <= edge) k = lx <= edge - 3 && ry >= 2 && ry <= 2 + lit ? 'h' : 'F';
        if (under) k = x <= x0 + 1 ? 'f' : 'e';
        if (x >= x1 - 1) k = 'e';
        if (y >= GB - 1) k = 'e';
        o.put(x, y, k);
      }
      // stitched seam three rows under the frame, and the belly gleam on a full purse
      if (y === yT + 3) for (let x = x0 + 3; x <= x1 - 3; x += 2) o.put(x, y, x < cx - 2 ? 'h' : 'F');   // stitches, lit on the dark leather
      if (ry === 4 || ry === 5) { o.put(x0 + 2, y, 'Y'); }   // a pale specular pair at the top of the lit lobe
      // the crease of a sagging purse
      if (P.sag && y === GB - 3) for (let x = x0 + 4; x <= x1 - 4; x++) o.put(x, y, 'f');
    }
    // front frame bar (bowed upward in the middle when straining) and its hinge rivets
    for (let x = fx0; x <= fx1; x++) {
      const mid = P.bow && x > fx0 + (fx1 - fx0) / 4 && x < fx1 - (fx1 - fx0) / 4 ? P.bow : 0;
      o.put(x, yT - 1 - mid, x <= fx0 + 1 ? 'Y' : 'y');
      o.put(x, yT - mid, x >= fx1 - 1 ? 'm' : 'M');
      if (mid) o.put(x, yT, 'M');
    }
    o.put(fx0, yT + 1, 'm'); o.put(fx0, yT + 2, 'u'); o.put(fx1, yT + 1, 'm'); o.put(fx1, yT + 2, 'u');
    // near knob; closed: the two knobs kiss on top of the bar
    const ky = yT - 3 - (P.bow || 0);
    o.put(cx - 2, ky, 'y'); o.put(cx - 1, ky, 'M'); o.put(cx - 2, ky + 1, 'M'); o.put(cx - 1, ky + 1, 'm');
    if (!P.gap) { o.put(cx, ky, 'y'); o.put(cx + 1, ky, 'M'); o.put(cx, ky + 1, 'M'); o.put(cx + 1, ky + 1, 'm'); }
    if (P.bow) { o.put(cx - 3, ky + 1, 'M'); }   // the near knob is pulled off-centre by the strain
    paint(o); }
  if (flop) { const o = obj(), a0 = fx0 + 2, a1 = fx1 - 2, D = Math.max(4, Math.round(P.ht * 0.42)), y0 = yT + 2;
    let py = null;
    for (let x = a0; x <= a1; x++) {
      const u = (x - a0) / (a1 - a0), y = y0 + Math.round(D * Math.sqrt(Math.max(0, 1 - (2 * u - 1) ** 2)));
      const t0 = py === null ? y : Math.min(y, py), t1 = py === null ? y : Math.max(y, py);
      for (let yy = t0; yy <= t1 + 1; yy++) o.put(x, yy, yy <= t1 ? 'e' : 'h');
      py = y;
    }
    o.put(a0, y0, 'M'); o.put(a0, y0 + 1, 'm'); o.put(a1, y0, 'M'); o.put(a1, y0 + 1, 'm');
    paint(o, false); }   // a thin strap: a dark line with a lit lower edge, no extra ink

  // ---- what is in the air or on the counter ----
  if (step === 3 && !v) {
    // strain marks (ink ticks) at the belly and the frame ends, and a sweat drop (loop: off under reduced motion)
    const bx0 = cx - P.belly - 2, bx1 = cx + P.belly + 1;
    [[bx0, yT + 6], [bx0 - 1, yT + 5], [bx0, yT + 10], [bx0 - 1, yT + 11], [bx1, yT + 6], [bx1 + 1, yT + 5], [bx1, yT + 10], [bx1 + 1, yT + 11],
     [fx0 - 2, yT - 3], [fx0 - 3, yT - 4], [fx1 + 2, yT - 3], [fx1 + 3, yT - 4]].forEach(([x, y]) => set(x, y, '#'));
    if (!still) paint(rows(fx1 + 3, yT - 12, ['.5.', '.5.', '565', '555', '.5.']));
  }
  if (step === 4 && !v) {
    coin(cx - P.belly - 5, GB - 3); coin(cx - P.belly - 8, GB - 1, true); coin(cx - P.belly - 9, GB - 3, true);
    if (!still) {
      note(cx - 12, mouthTop - 18, 11, 5, -0.5); note(cx + 2, mouthTop - 23, 11, 5, 0.5);
      coin(cx - 12, mouthTop - 6); coin(cx + 12, mouthTop - 10); coin(cx - 3, mouthTop - 21); coin(cx + 14, mouthTop - 2, true);
      coin(cx - 12, mouthTop + 3, true);
      sparkle(cx - 10, mouthTop - 26); sparkle(cx + 15, mouthTop - 17); sparkle(cx + 1, mouthTop - 30);
    }
  }
  if (v === 'over') {
    // emptying happily toward the cash drawer (bottom left): notes and coins tumble out to the left
    note(cx - 23, yT - 6, 11, 5, -0.5); note(cx - 22, yT + 3, 11, 5, 0.5);
    coin(cx - 16, yT - 7); coin(cx - 19, yT + 11, true); coin(cx - 14, GB - 3);
    sparkle(cx + 9, yT - 14);
  }
  if (v === 'on') { [[cx - 4, yT - 6], [cx - 5, yT - 7], [cx + 3, yT - 6], [cx + 4, yT - 7], [cx - 1, yT - 8], [cx - 1, yT - 9]].forEach(([x, y]) => set(x, y, '#')); }
  if (v === 'short') { note(cx - 12, mouthTop, 10, 4, 0.5); }
  if (opts.drag === '+') { [[cx - 6, PURSE_GB + 2], [cx - 5, PURSE_GB + 2], [cx + 4, PURSE_GB + 2], [cx + 5, PURSE_GB + 2]].forEach(([x, y]) => set(x, y, '#')); }

  const c = document.createElement('canvas'); c.width = PURSE_W; c.height = PURSE_H; c.className = 'px';
  const g = c.getContext('2d');
  shadow.forEach(([x, y, e]) => { g.fillStyle = 'rgba(30,18,10,.38)'; g.fillRect(x, y, 1, e); });
  for (let y = 0; y < PURSE_H; y++) for (let x = 0; x < PURSE_W; x++) { const k = G[y][x]; if (k) { g.fillStyle = PURSE_PAL[k]; g.fillRect(x, y, 1, 1); } }
  return c;
}
