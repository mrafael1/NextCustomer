// Direction B (#76): the wallet on the counter and its face-like budget tag. Needs PURSE (the sprite data gen_b.py writes).
// Every colour is a key of art/src/palette.txt; shadows are ink at an alpha (a modulate in Godot), as in the base page.
const PB = (() => {
const P = PURSE.pal;
// a text grid as a canvas: t css px per texel (2 on the stage, like the 48 x 48 items)
function grid(rows, t = 2) {
  const c = document.createElement('canvas'); c.width = rows[0].length; c.height = rows.length; c.className = 'px';
  c.style.width = c.width * t + 'px'; c.style.height = c.height * t + 'px';
  const g = c.getContext('2d');
  rows.forEach((r, j) => [...r].forEach((k, i) => { if (P[k]) { g.fillStyle = P[k]; g.fillRect(i, j, 1, 1); } }));
  return c;
}
const GLYPH = {
  sweat: ['..#..', '.#6#.', '#665#', '#655#', '.###.'],
  spark: ['..y..', '..y..', 'yywyy', '..y..', '..y..'],
  sparkS: ['.y.', 'ywy', '.y.'],
  gleam: ['....w', '...w.', '..w..', '.w...'],
  tickL: ['##.', '..#'], tickR: ['.##', '#..'],
  pop: ['#...#', '.....', '..#..', '.....', '#...#'],
  flutter: ['######', '#zzGg#', '#gGGg#', '######'],
  flutter2: ['#####', '#zGg#', '#GGg#', '#gGg#', '#####'],
  coin: ['.###.', '#yMM#', '#MMm#', '.###.'],
};
// a stepped contact shadow (the base page's pxShadow), on the 2 px grid
function shadow(parent, left, top, w, h, alpha, z) {
  const c = document.createElement('canvas'), tw = Math.round(w / 2), th = Math.round(h / 2); c.width = tw; c.height = th; c.className = 'px';
  Object.assign(c.style, { position: 'absolute', left: left + 'px', top: top + 'px', width: tw * 2 + 'px', height: th * 2 + 'px', zIndex: z || 0 });
  const g = c.getContext('2d'); g.fillStyle = `rgba(20,14,10,${alpha})`;
  for (let j = 0; j < th; j++) for (let i = 0; i < tw; i++)
    if (((i + .5 - tw / 2) / (tw / 2)) ** 2 + ((j + .5 - th / 2) / (th / 2)) ** 2 <= 1) g.fillRect(i, j, 1, 1);
  parent.appendChild(c); return c;
}
function put(parent, name, x, y, t = 2, z = 8) {
  const c = grid(GLYPH[name], t); Object.assign(c.style, { position: 'absolute', left: x + 'px', top: y + 'px', zIndex: z }); parent.appendChild(c); return c;
}
// the wallet: state s0..s4 / hop / slump / over / on / short; x, y = the canvas's top left (26 x 52 texels); o.fx adds the
// state's stickers (the loops: sweat, sparkle, gleam; reduced motion leaves them out), o.lift raises it off its shadow (hop)
function wallet(parent, state, x, y, o = {}) {
  const t = o.t || 2, lift = o.lift || 0, z = o.z || 4;
  const box = document.createElement('div');
  Object.assign(box.style, { position: 'absolute', left: x + 'px', top: y + 'px', width: 26 * t + 'px', height: 52 * t + 'px', zIndex: z });
  parent.appendChild(box);
  const sw = lift ? 18 : 22, so = state === 's4' ? 2 : 0;
  shadow(box, (14 - sw / 2 - so) * t, 48.5 * t, (sw + 2 * so) * t, 4 * t, lift ? .28 : .45, 0);
  const c = grid(PURSE.wallet[state], t); Object.assign(c.style, { position: 'absolute', left: 0, top: -lift + 'px', zIndex: 1 }); box.appendChild(c);
  const fx = o.fx === undefined ? true : o.fx, k = t / 2, at = (n, gx, gy, zz) => put(box, n, gx * k, gy * k - lift, t, zz || 2);
  if (fx) {
    if (state === 's2') { at('tickL', -8, 64); at('tickR', 50, 64); }
    if (state === 's3') { at('gleam', 34, 30); at('spark', 40, 20); at('sparkS', -2, 40); }
    if (state === 's4') { at('sweat', -8, 48); at('sweat', -10, 66); at('sweat', 40, 6); at('spark', 30, -4); at('spark', -4, 16); at('sparkS', 18, 4); at('gleam', 26, 22); }
    if (state === 'hop') { at('tickL', -6, 86); at('tickR', 48, 86); }
    if (state === 'over') { at('flutter', -14, 36); at('flutter2', -24, 64); at('flutter', 2, 18); }
    if (state === 'on') { at('pop', 18, 64); }
  }
  return box;
}
// the face-like budget tag: a cream hang-tag (punched hole at the left), a face, the minimum spend, and a stitched pocket
// that fills with notes as the shown total rises; at the budget a mustard rubber stamp lands on it, past it notes spill
// out of the pocket. o: w (css px), state, fill 0..1, met, over, line1, line2, string
function tag(parent, o) {
  const T = 2, W = Math.floor(o.w / T), H = 17;
  const d = document.createElement('div'); d.className = 'btag'; d.style.width = W * T + 'px'; parent.appendChild(d);
  const c = document.createElement('canvas'); c.width = W; c.height = H; c.className = 'px tagc';
  c.style.width = W * T + 'px'; c.style.height = H * T + 'px'; d.appendChild(c);
  const g = c.getContext('2d'), dot = (i, j, k) => { if (P[k]) { g.fillStyle = P[k]; g.fillRect(i, j, 1, 1); } };
  const inside = (i, j) => i >= 0 && j >= 0 && i < W && j < H && !(i < 4 && (j < 4 - i || j > H - 1 - (4 - i))) && !((i === W - 1) && (j === 0 || j === H - 1));
  const edge = (i, j) => inside(i, j) && !(inside(i - 1, j) && inside(i + 1, j) && inside(i, j - 1) && inside(i, j + 1));
  for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) {
    if (!inside(i, j)) continue;
    dot(i, j, edge(i, j) ? '#' : (edge(i - 1, j) || edge(i, j - 1)) ? 'w' : (edge(i + 1, j) || edge(i, j + 1)) ? 'b' : 'c');
  }
  // the punched hole and its reinforcing ring
  [[3, 7], [4, 7], [3, 9], [4, 9], [2, 8], [5, 8]].forEach(([i, j]) => dot(i, j, 'a'));
  dot(3, 8, '2'); dot(4, 8, '2');
  // the face: a smiley disc printed on the tag (mustard pale, ink ring, shaded lower right), its features by state
  for (let j = 1; j <= 15; j++) for (let i = 5; i <= 19; i++) {
    const r = Math.hypot(i - 12, j - 8);
    if (r > 7.3) continue;
    dot(i, j, r > 6.3 ? '#' : (i + j > 21 && r > 5.2) ? 'y' : 'Y');
  }
  (PURSE.face[o.state] || PURSE.face.s0).forEach((r, j) => [...r].forEach((k, i) => dot(7 + i, 3 + j, k)));
  // the words
  const tt = document.createElement('div'); tt.className = 'tt'; tt.style.left = '44px';
  tt.innerHTML = `<span class="k2">${o.line1 || 'BUDGET'}</span><span class="q">${o.line2 || 'at least €73'}</span>`; d.appendChild(tt);
  const tw = Math.ceil(tt.offsetWidth / T);
  // the pocket: a stitched slot in the tag, dark leather inside, notes filling it from the left
  if (o.fill !== null && o.fill !== undefined && W - 4 - (22 + tw + 3) >= 14) {
    const x0 = 22 + tw + 3, x1 = o.met ? W - 12 : W - 4, y0 = 6, y1 = 12, inner = x1 - x0 - 1, n = Math.round(Math.min(o.fill, 1) * inner);
    if (o.over) [[x1 - 34, 2], [x1 - 27, 1], [x1 - 20, 3]].filter(([nx]) => nx > x0).forEach(([nx, ny]) => {   // notes spilling out of the full pocket
      for (let j = ny; j <= y0; j++) for (let i = nx; i < nx + 6; i++) dot(i, j, (i === nx || i === nx + 5 || j === ny) ? '#' : j === ny + 1 ? 'z' : 'G');
    });
    for (let i = x0; i <= x1; i++) { dot(i, y0, '#'); dot(i, y1, '#'); }
    for (let j = y0; j <= y1; j++) { dot(x0, j, '#'); dot(x1, j, '#'); }
    for (let i = x0 + 1; i < x1; i++) for (let j = y0 + 1; j < y1; j++) {
      const f = i - x0 - 1 < n, edgeN = (i - x0 - 1) % 7 === 6;
      dot(i, j, f ? (j === y0 + 1 ? 'z' : edgeN || j === y1 - 1 ? 'g' : 'G') : (j === y0 + 1 ? 'f' : 'e'));
    }
    for (let i = x0 + 1; i < x1; i += 2) { dot(i, y0 - 1, 'a'); dot(i, y1 + 1, 'a'); }   // stitching around the pocket
    if (!o.met) { dot(x1 - 1, y0 + 1, 'M'); dot(x1 - 1, y1 - 1, 'M'); }                 // the budget mark at its end
    if (o.met) {   // review fix: a solid mustard check disc (the quota chip's own mark), not a dark worn ring that
                   // read as mud over the green notes and vanished in greyscale; it lands just past the pocket's end
      const cx = W - 8, cy = 8;
      for (let j = 0; j < H; j++) for (let i = cx - 8; i <= cx + 8; i++) {
        const r = Math.hypot(i - cx, j - cy);
        if (r > 7.2) continue;
        dot(i, j, r > 6.2 ? '#' : (i + j < cx + cy - 3 && r > 4.6) ? 'y' : (i + j > cx + cy + 3 && r > 4.6) ? 'm' : 'M');
      }
      [[-3, 0], [-2, 1], [-1, 2], [0, 1], [1, 0], [2, -1], [3, -2], [-3, 1], [-2, 2], [-1, 3], [0, 2], [1, 1], [2, 0], [3, -1]].forEach(([a, b]) => dot(cx + a, cy + b, '#'));
    }
  }
  return d;
}
return { grid, put, shadow, wallet, tag, GLYPH };
})();
