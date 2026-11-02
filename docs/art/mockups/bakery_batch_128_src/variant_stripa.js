// #128 variant 'stripa': the batch's tickets sit on one bake-coloured backing strip. The strip
// fills every gap inside the batch top to bottom, wraps the batch's two ends and shows as a lip
// in the dark counter band under the tickets, with a perforation in each gap. No job words: a job
// out of place turns its BATCH chip tomato with a pixel cross and tears a notch in the lip.
// Stage px; see the host page for the ticket geometry.
window.BATCH_VARIANTS = window.BATCH_VARIANTS || {};
window.BATCH_VARIANTS['stripa'] = {
  label: 'Bakery strip',
  note: 'The batch prints on one strip: a cardboard backing that fills the gaps between its tickets, wraps its two ends and runs as a lip along the counter under them, with a perforation in each gap. Outside the batch the gaps stay grey. The arms posts stand on the strip. No job words: a job out of place turns its BATCH chip tomato with a cross and tears a notch in the strip under its ticket; hovering that chip gives the same reason as its WASTED step. Hovering any other BATCH chip lights the strip. Planning only; the lip stays inside the counter band.',
  render(ctx) {
    const { layer, row, el, showTip } = ctx;
    if (!document.getElementById('v-stripa')) {
      const s = document.createElement('style');
      s.id = 'v-stripa';
      s.textContent = `
.vsa-bk { position: absolute; z-index: 1; background: var(--bake-shade); pointer-events: none; }
.vsa-bk.lit { background: var(--mustard); }
.vsa-lip { border: 2px solid var(--ink); border-top: 0; }
.vsa-cap { border-top: 2px solid var(--ink); }
.vsa-cap.l { border-left: 2px solid var(--ink); }
.vsa-cap.r { border-right: 2px solid var(--ink); }
.vsa-hole { position: absolute; z-index: 2; width: 4px; height: 5px; background: var(--ink); pointer-events: none; }
.vsa-post { position: absolute; z-index: 2; background-size: 1920px 1080px; image-rendering: pixelated; pointer-events: none; }
.vsa-tear { position: absolute; z-index: 3; pointer-events: none; shape-rendering: crispEdges; }
.kw.vsa-bad, .kw.vsa-bad:hover, .kw.vsa-bad.lit { background: var(--tomato); color: var(--paper); }
.kw.vsa-bad svg { display: inline-block; margin-left: 4px; vertical-align: -1px; shape-rendering: crispEdges; }
`;
      document.head.appendChild(s);
    }
    // Ticket i's outer box, ink outline included, measured on the captures: x 552+192i .. 713+192i,
    // y 684 .. 785. The gap after it runs x 714+192i .. 743+192i, y 687 .. 785.
    const OUT_L = i => 552 + 192 * i, OUT_R = i => 713 + 192 * i;
    const TOP = 684, GAP_TOP = 687, BAND = 786, LIP_H = 15, CAP = 6;
    // The gold arms posts the captures show in batch gaps (gap i follows ticket i). They sit at
    // x +6 .. +23 of the gap and are copied back over the strip, so they stand on it.
    const POSTS = { 'row_bread_first.png': [3], 'row_croissant_first.png': [0, 1, 2, 3] };
    const shotName = row.shot.split('/').pop();
    const posts = POSTS[shotName] || [];
    const [first, last] = row.batch;
    const L = OUT_L(first) - CAP, R = OUT_R(last) + 1 + CAP;
    const piece = (cls, x, y, w, h) => {
      const d = el('div', 'vsa-bk ' + cls, { left: x + 'px', top: y + 'px', width: w + 'px', height: h + 'px' });
      layer.appendChild(d);
      ctx.bracketTargets.push(d);
      return d;
    };
    // Ends, wrapping the outer tickets; the lip under the whole batch; a fill in every inner gap.
    piece('vsa-cap l', L, TOP, CAP, BAND - TOP);
    piece('vsa-cap r', R - CAP, TOP, CAP, BAND - TOP);
    piece('vsa-lip', L, BAND, R - L, LIP_H);
    for (let i = first; i < last; i++) {
      const gx = OUT_R(i) + 1;
      piece('', gx, GAP_TOP, 30, BAND - GAP_TOP);
      // Perforation: down the gap's middle (behind a post, if one stands there) and through the lip.
      const post = posts.includes(i);
      const py = post ? BAND + 2 : GAP_TOP + 4;
      for (let y = py; y + 5 <= BAND + LIP_H - 3; y += 9) layer.appendChild(el('div', 'vsa-hole', { left: (gx + 13) + 'px', top: y + 'px' }));
      if (post) {
        const px = gx + 6, ph = BAND - GAP_TOP;
        layer.appendChild(el('div', 'vsa-post', { left: px + 'px', top: GAP_TOP + 'px', width: '18px', height: ph + 'px',
          backgroundImage: `url("${row.shot}")`, backgroundPosition: `-${px}px -${GAP_TOP}px` }));
      }
    }

    // A wrong job: its BATCH chip (drawn by the host before this runs) turns tomato with a cross,
    // its hover gives the WASTED reason, and the lip under its ticket is torn.
    const X_SVG = '<svg width="10" height="10" viewBox="0 0 5 5" aria-hidden="true"><path fill="currentColor" d="M0 0h1v1h-1zM4 0h1v1h-1zM1 1h1v1h-1zM3 1h1v1h-1zM2 2h1v1h-1zM1 3h1v1h-1zM3 3h1v1h-1zM0 4h1v1h-1zM4 4h1v1h-1z"/></svg>';
    // The host marks that chip with class 'bad' and data-index, and its hover already tells the
    // item's WASTED reason; this variant only restyles it.
    row.items.forEach((it, i) => {
      const kw = layer.querySelector(`.kw.bad[data-index="${i}"]`);
      if (!it.bad || !kw) return;
      kw.classList.add('vsa-bad');
      kw.insertAdjacentHTML('beforeend', X_SVG);
      // Tear: a stepped notch bitten out of the lip under the ticket's left end, ink-edged.
      const W = 40, H = LIP_H + 2;
      const cut = [12, 8, 10, 4, 2, 6, 3, 8, 11, 13];
      const step = W / cut.length;
      const col = x => cut[Math.min(cut.length - 1, Math.floor(x / step))];
      let ink = '', dark = '';
      for (let x = 0; x < W; x += 2) {
        const top = col(x), edge = Math.min(col(x - 2 < 0 ? 0 : x - 2), col(x + 2 >= W ? W - 1 : x + 2), top) - 2;
        ink += `M${x} ${Math.max(0, edge)}h2v${H}h-2z`;
        dark += `M${x} ${top}h2v${H}h-2z`;
      }
      const tear = el('div', 'vsa-tear', { left: (OUT_L(i) + 8) + 'px', top: BAND + 'px', width: W + 'px', height: H + 'px' });
      tear.innerHTML = `<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" aria-hidden="true"><path fill="#2b2420" d="${ink}"/><path fill="#2c2724" d="${dark}"/></svg>`;
      layer.appendChild(tear);
    });
  },
};
