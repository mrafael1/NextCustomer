// #77 prep: the item tier markers, shared by machine_77_upgrades.html and machine_77_upgrades_bay.html.
// Never colour alone: plain has no tag; BIG a square cream price-gun label with one chevron; GOLDEN a gold ribbon with
// notched (swallowtail) ends and two chevrons, a double rim on its ticket and a 2-frame sparkle. The tag hangs under the
// ticket's left end (the top left is the rail strip's badge, the top right the pay starburst). Hovering an item steps a
// diagonal shine across its sprite (tierGlint). Everything is drawn on the 2 px texel grid (canvas at 1 texel per pixel,
// shown at 2x, image-rendering: pixelated).
const T_INK = '#2b2420';
function tCanvas(tw, th) { const c = document.createElement('canvas'); c.width = tw; c.height = th; c.className = 'px';
  c.style.width = tw * 2 + 'px'; c.style.height = th * 2 + 'px'; return c; }
function tGlyph(rows, cols) { const c = tCanvas(rows[0].length, rows.length), g = c.getContext('2d');
  rows.forEach((r, j) => [...r].forEach((ch, i) => { if (cols[ch]) { g.fillStyle = cols[ch]; g.fillRect(i, j, 1, 1); } })); return c; }
// a filled shape with an ink outline, a lit top-left inner edge, a shaded bottom-right inner edge and a 1-texel hard shadow
function tPaint(c, inside, p, shadow = 'rgba(20,14,10,.5)') {
  const g = c.getContext('2d'), W = c.width, H = c.height;
  const ins = (i, j) => i >= 0 && j >= 0 && i < W && j < H && inside(i, j);
  const edge = (i, j) => ins(i, j) && !(ins(i - 1, j) && ins(i + 1, j) && ins(i, j - 1) && ins(i, j + 1));
  const dot = (i, j, col) => { g.fillStyle = col; g.fillRect(i, j, 1, 1); };
  for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) {
    if (!ins(i, j)) { if (shadow && ins(i - 1, j - 1)) dot(i, j, shadow); continue; }
    if (edge(i, j)) dot(i, j, T_INK);
    else if (edge(i - 1, j) || edge(i, j - 1)) dot(i, j, p.lit);
    else if (edge(i + 1, j) || edge(i, j + 1)) dot(i, j, p.shade);
    else dot(i, j, p.fill);
  }
}
const T_CHEV = ['..C..', '.CWC.', 'CW.WC', 'C...C'];
// the tier tag (the caller places it under the ticket's left end); null for plain.
// BIG: a cream price-gun label (rounded box) with one chevron. GOLDEN: a gold ribbon with swallowtail ends and two chevrons.
function tierTag(tier) {
  if (tier === 0) return null;
  const d = document.createElement('div'), big = tier === 1;
  d.className = 'ttag ' + (big ? 'big' : 'gold');
  const tw = big ? 28 : 40, th = 11, c = tCanvas(tw + 1, th + 1);
  if (big) tPaint(c, (i, j) => i < tw && j < th && !((i === 0 || i === tw - 1) && (j === 0 || j === th - 1)),
    { fill: '#fbf7ee', lit: '#ffffff', shade: '#ddcba5' });
  else tPaint(c, (i, j) => { if (i >= tw || j >= th) return false; const m = Math.abs(j - (th - 1) / 2), n = 3 - Math.round(m * 3 / ((th - 1) / 2));
      return i >= n && i < tw - n; }, { fill: '#ffcf3f', lit: '#faecbc', shade: '#c8932b' });
  d.appendChild(c);
  const t = document.createElement('div'); t.className = 't';
  t.appendChild(tGlyph(big ? T_CHEV : T_CHEV.map(r => r + '.' + r), { C: T_INK, W: T_INK }));
  t.insertAdjacentHTML('beforeend', `<span>${big ? 'BIG' : 'GOLD'}</span>`); d.appendChild(t);
  return d;
}
// a 2-frame sparkle (the game's art/effects/sparkle.png cross, 5x5 texels at 2x) that swaps between two spots
function tierSparkles(parent, spots) {
  spots.forEach(([x, y], i) => { const c = tGlyph(['..y..', '..y..', 'yywyy', '..y..', '..y..'], { y: '#f1d27a', w: '#ffffff' });
    c.classList.add('spk', i % 2 ? 'fb' : 'fa'); Object.assign(c.style, { left: x + 'px', top: y + 'px' }); parent.appendChild(c); });
}
// the hover glint: a paper-white diagonal band, masked to the sprite's own pixels, stepped across it in 6 steps (about
// 2 texels a step at belt size) once per hover. `host` is the positioned item box, `src` the sprite's URL (a data URI, so
// the mask loads from a file:// page too).
function tierGlint(host, src) {
  const g = document.createElement('div'); g.className = 'glint';
  g.style.webkitMaskImage = g.style.maskImage = `url("${src}")`;
  host.classList.add('glinthost'); host.appendChild(g); return g;
}
const TIER_CSS = `
.ttag { position: absolute; z-index: 8; }
.ttag > canvas { position: absolute; left: 0; top: 0; }
.ttag .t { position: absolute; left: 0; top: 0; right: 0; bottom: 0; display: flex; align-items: center; justify-content: center; gap: 4px; }
.ttag .t span { font-family: Pixelify; color: #2b2420; letter-spacing: 1px; }
.ttag.big { width: 58px; height: 24px; } .ttag.gold { width: 82px; height: 24px; }
.ttag .t { padding: 0 2px 2px 0; } .ttag .t span { font-size: 14px; line-height: 16px; }
.label.t2 { box-shadow: 0 0 0 2px #ffcf3f, 0 0 0 4px #2b2420, 5px 5px 0 2px rgba(30,18,10,.38); }
.label.t2::before { background: repeating-linear-gradient(90deg, #ffcf3f 0 6px, #c8932b 6px 8px); }
.priceup { font-family: Pixelify; font-size: 11px; font-weight: 400; color: #2b2420; background: #fbf7ee; border: 2px solid #2b2420; padding: 0 3px; line-height: 12px; margin-left: 4px; vertical-align: 3px; }
.up { display: inline-block; padding: 0 3px; margin: 0 -1px; background: #ffcf3f; border: 2px solid #2b2420; line-height: 11px; color: #2b2420; }
.spk { position: absolute; z-index: 9; animation: spkA 1.2s steps(1) infinite; }
.spk.fb { animation-name: spkB; }
@keyframes spkA { 0% { opacity: 1; } 50% { opacity: 0; } }
@keyframes spkB { 0% { opacity: 0; } 50% { opacity: 1; } }
body.still .spk { animation: none; } body.still .spk.fb { opacity: 0; }
.glint { position: absolute; left: 0; top: 0; width: 96px; height: 96px; pointer-events: none; z-index: 2;
  -webkit-mask-size: 96px 96px; mask-size: 96px 96px; -webkit-mask-repeat: no-repeat; mask-repeat: no-repeat;
  background: linear-gradient(135deg, transparent 0 46%, rgba(255,255,255,.8) 46% 50%, rgba(255,255,255,.45) 50% 53%, transparent 53%);
  background-size: 300% 300%; background-position: 100% 100%; }
.glinthost { pointer-events: auto; }
.glinthost:hover .glint { animation: glint .42s steps(6) 1 both; }
@keyframes glint { from { background-position: 100% 100%; } to { background-position: 0% 0%; } }
body.still .glint.demo { animation: none; background-position: 50% 50%; }
`;
