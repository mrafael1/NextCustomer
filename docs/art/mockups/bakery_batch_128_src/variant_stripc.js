// #128 variant 'stripc': a stapled strip. Every gap inside the batch holds a chunky bake clip
// joining the neighbouring tickets, with a steel staple across the join, and the tickets' bases
// run on as one spine; the batch's outer edges get bake end caps. No job words anywhere. A job out
// of place turns its BATCH chip tomato with a pixel cross (hover: the same reason as its WASTED
// step), and the clip on its left is drawn torn in two. Stage px on the captures' 3 px art grid:
// ticket i's outer edge (ink) spans x 552+192i..713+192i, y 684..785; the grey post between two
// tickets is x 714..743 (+192i); the counter band starts at y 786.
window.BATCH_VARIANTS = window.BATCH_VARIANTS || {};
window.BATCH_VARIANTS['stripc'] = {
  label: 'Stapled strip',
  note: 'The batch is stapled into one strip: a chunky bake clip with a steel staple joins each pair of neighbouring tickets, their bases run on as one spine, and bake end caps close the strip at its first and last ticket. No job words: the tickets\' own text says what each does. A job out of place turns its BATCH chip tomato with a pixel cross and its clip is drawn torn; hovering the chip or the torn clip gives the same reason as its WASTED step. Hovering any BATCH chip lights the whole strip. Planning only; nothing below the tickets, the count-up is unchanged.',
  render(ctx) {
    const { layer, row, FACE_X, PITCH, FACE_W, el, showTip, hideTip } = ctx;
    if (!document.getElementById('v-stripc')) {
      const s = document.createElement('style');
      s.id = 'v-stripc';
      s.textContent = `
.sc-part { position: absolute; z-index: 2; pointer-events: none; }
.sc-part svg { display: block; shape-rendering: crispEdges; overflow: visible; }
.sc-part .i { fill: var(--ink); }
.sc-part .f { fill: var(--bake); }
.sc-part .h { fill: var(--bake-light); }
.sc-part .d { fill: var(--bake-shade); }
.sc-part .st { fill: #e6e9e4; }
.sc-part .sd { fill: #8f9893; }
.sc-part.lit .f { fill: var(--mustard); }
.sc-part.lit .h { fill: #ffcf3f; }
.sc-part.lit .d { fill: var(--mustard-dark); }
.sc-part.torn { pointer-events: auto; cursor: help; }
.sc-part.torn .f, .sc-part.torn.lit .f { fill: var(--tomato); }
.sc-part.torn .h, .sc-part.torn.lit .h { fill: #ec8a80; }
.sc-part.torn .d, .sc-part.torn.lit .d { fill: #a63a36; }
.kw.sc-bad, .kw.sc-bad:hover, .kw.sc-bad.lit { background: var(--tomato); color: var(--paper); }
.kw.sc-bad svg { display: inline-block; vertical-align: -1px; margin-left: 4px; shape-rendering: crispEdges; }
`;
      document.head.appendChild(s);
    }
    const [first, last] = row.batch;
    const NS = 'http://www.w3.org/2000/svg';
    const X_SVG = '<svg width="12" height="12" viewBox="0 0 6 6" aria-hidden="true"><path fill="currentColor" d="M0 0h2v1h-2zM4 0h2v1h-2zM1 1h2v1h-2zM3 1h2v1h-2zM2 2h2v2h-2zM1 4h2v1h-2zM3 4h2v1h-2zM0 5h2v1h-2zM4 5h2v1h-2z"/></svg>';
    const R = (c, x, y, w, h) => `<rect class="${c}" x="${x}" y="${y}" width="${w}" height="${h}"/>`;
    const part = (x, y, w, h, svg, cls) => {
      const d = el('div', 'sc-part' + (cls ? ' ' + cls : ''), { left: x + 'px', top: y + 'px', width: w + 'px', height: h + 'px' });
      d.innerHTML = `<svg xmlns="${NS}" width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" aria-hidden="true">${svg}</svg>`;
      layer.appendChild(d);
      ctx.bracketTargets.push(d);
      return d;
    };
    const OUT_L = i => FACE_X - 3 + PITCH * i;          // ticket's outer left (ink), 552+192i
    const OUT_R = i => FACE_X + FACE_W + 5 + PITCH * i; // ticket's outer right (ink), 713+192i (incl.)

    // Spine: the tickets' bases run on across each gap (bake, shade, ink, as a ticket's own base),
    // so the batch stands on one strip. y 770..785, above the counter band.
    const SP_Y = 770, SP_H = 16;
    const spineSvg = w => R('f', 0, 0, w, 7) + R('d', 0, 7, w, 3) + R('i', 0, 10, w, 6) + R('i', 0, 0, w, 3);

    // Clip in each gap, local px (3 px grid): a body over the post and both tickets' ink edges,
    // a steel staple across the join, its right end biting 3 px into the next face (the left
    // end stops at the ticket's edge, clear of an old price struck through there).
    const C_X = gap => OUT_R(gap) - 5, C_W = 42, C_Y = 717, C_H = 54; // x 708..749, y 717..770
    const clipSvg = () =>
      R('i', 0, 0, C_W, C_H) +
      R('f', 3, 3, C_W - 6, C_H - 6) + R('h', 3, 3, C_W - 6, 3) + R('d', 3, C_H - 6, C_W - 6, 3) +
      // Staple: steel, ink outlined, across the clip; its legs drop into the ticket faces.
      R('i', 0, 18, C_W + 3, 12) + R('st', 3, 21, C_W - 3, 3) + R('sd', 3, 24, C_W - 3, 3) +
      R('i', 0, 18, 6, 18) + R('i', C_W - 3, 18, 6, 18);

    const badIndex = row.items.findIndex(it => it.bad);
    // The host's tip for a job out of place is already its WASTED reason, with no job words.
    const wastedTitle = it => it.tip[0];
    for (let g = first; g < last; g++) {
      const sx = OUT_R(g) - 2, sw = OUT_L(g + 1) - sx + 3;
      part(sx, SP_Y, sw, SP_H, spineSvg(sw));
      if (g + 1 !== badIndex) { part(C_X(g), C_Y, C_W, C_H, clipSvg()); continue; }
      // Torn clip: split down a stepped tear, the halves 6 px apart (the left one pulled back, the right
      // one sagging but kept clear of the BATCH chip),
      // with a tomato gap showing between them.
      const T = 21, uid = 'sc-tear-' + g;
      const tear = [[T, -6], [T, 9], [T - 6, 9], [T - 6, 21], [T, 21], [T, 33], [T - 6, 33], [T - 6, 45], [T, 45], [T, C_H + 6]];
      const pts = a => a.map(p => p.join(',')).join(' ');
      const leftPoly = pts([[-6, -6], ...tear, [-6, C_H + 6]]);
      const rightTear = tear.map(([x, y]) => [x + 3, y]);
      const rightPoly = pts([...rightTear, [C_W + 6, C_H + 6], [C_W + 6, -6]]);
      // Ink edge along each side of the tear, drawn as 3 px steps.
      const edge = (line, dx) => line.slice(0, -1).map(([x0, y0], k) => {
        const [x1, y1] = line[k + 1];
        return x0 === x1 ? R('i', x0 + dx, Math.max(0, y0), 3, Math.min(C_H, y1 + 3) - Math.max(0, y0))
          : R('i', Math.min(x0, x1) + dx, y0, Math.abs(x1 - x0) + 3, 3);
      }).join('');
      const svg =
        `<defs><clipPath id="${uid}-l"><polygon points="${leftPoly}"/></clipPath>` +
        `<clipPath id="${uid}-r"><polygon points="${rightPoly}"/></clipPath></defs>` +
        `<g transform="translate(-3 0)"><g clip-path="url(#${uid}-l)">${clipSvg()}${edge(tear, -3)}</g></g>` +
        `<g transform="translate(0 6)"><g clip-path="url(#${uid}-r)">${clipSvg()}${edge(rightTear, 0)}</g></g>`;
      const it = row.items[badIndex];
      const torn = part(C_X(g), C_Y, C_W, C_H + 6, svg, 'torn');
      torn.tabIndex = 0;
      torn.setAttribute('aria-label', wastedTitle(it) + '. ' + it.tip[1]);
      const on = () => showTip(OUT_L(badIndex), C_Y, wastedTitle(it), it.tip[1], true);
      torn.addEventListener('mouseenter', on); torn.addEventListener('mouseleave', hideTip);
      torn.addEventListener('focus', on); torn.addEventListener('blur', hideTip);
    }

    // End caps: a bake tab with a stepped outer corner on each outer edge of the strip, set on the
    // tickets' ink edge so it covers no text; its notch echoes the staple.
    const K_W = 15, K_Y = 729, K_H = 36;
    const capSvg = flip => {
      const g = R('i', 3, 0, K_W - 3, K_H) + R('i', 0, 3, K_W, K_H - 6) +
        R('f', 3, 3, K_W - 3, K_H - 6) + R('h', 3, 3, K_W - 3, 3) + R('d', 3, K_H - 6, K_W - 3, 3) +
        R('i', 6, 12, 3, 12);
      return flip ? `<g transform="translate(${K_W} 0) scale(-1 1)">${g}</g>` : g;
    };
    part(OUT_L(first) - K_W + 6, K_Y, K_W, K_H, capSvg(false));
    part(OUT_R(last) - 5, K_Y, K_W, K_H, capSvg(true));

    // The wrong job's BATCH chip: tomato with a pixel cross; its hover tells the WASTED reason.
    // The host marks that chip (class 'bad', data-index) and its hover already lights the strip
    // and tells the WASTED reason; restyle it only.
    const kw = badIndex >= 0 && layer.querySelector(`.kw.bad[data-index="${badIndex}"]`);
    if (kw) {
      kw.classList.add('sc-bad');
      kw.insertAdjacentHTML('beforeend', X_SVG);
    }
  },
};
