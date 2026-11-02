// #128 variant 'stripb': the batch's tickets are bound into one booklet. A single thick mustard
// frame (2px ink, 4px mustard, 2px ink, stepped pixel corners) runs round the whole batch, gaps
// included, and tucks behind each price badge; two solid binding bars cross every gap inside the
// batch. No job words anywhere. A job out of place turns its BATCH chip tomato with a pixel cross
// and gets a tomato inner outline on its ticket; hovering that chip gives its WASTED reason.
// Stage px; see the host page for the ticket geometry. Nothing below y 786 (the counter edge).
window.BATCH_VARIANTS = window.BATCH_VARIANTS || {};
window.BATCH_VARIANTS['stripb'] = {
  label: 'Bound strip',
  note: 'The batch is bound into one booklet of tickets: one thick mustard frame runs round the whole batch, gaps included, and tucks behind the price badges; two solid binding bars cross every gap inside it. Where the frame starts and stops is where the batch starts and stops. There are no job words: the sticker lines already say each job. A job out of place turns its BATCH chip tomato with a cross and outlines its ticket in tomato; hovering that chip gives the same reason as its WASTED step. Hovering any BATCH chip lights the frame and the bars. Planning only; nothing goes below the tickets, the count-up is unchanged.',
  render(ctx) {
    const { layer, row, FACE_X, PITCH, FACE_W, el, showTip, hideTip } = ctx;
    if (!document.getElementById('v-stripb')) {
      const s = document.createElement('style');
      s.id = 'v-stripb';
      s.textContent = `
.sb-svg { position: absolute; left: 0; top: 0; z-index: 2; pointer-events: none; overflow: visible; shape-rendering: crispEdges; }
.sb-svg .sb-ink { fill: var(--ink); }
.sb-svg .sb-mus { fill: var(--mustard); }
.sb-svg .sb-hi { fill: #f0cf6a; }
.sb-svg .sb-bad { fill: var(--tomato); }
.sb-svg.lit .sb-mus { fill: #ffdb5c; }
.sb-svg.lit .sb-hi { fill: var(--paper); }
.kw.sb-badkw, .kw.sb-badkw:hover, .kw.sb-badkw.lit { background: var(--tomato); color: var(--paper); }
.kw.sb-badkw svg { display: inline-block; vertical-align: -1px; margin-left: 4px; shape-rendering: crispEdges; }
@media (prefers-reduced-motion: reduce) { .sb-svg * { transition: none; } }
`;
      document.head.appendChild(s);
    }
    const NS = 'http://www.w3.org/2000/svg';
    const [first, last] = row.batch;
    const faceL = i => FACE_X + PITCH * i;
    const faceR = i => faceL(i) + FACE_W;
    // Ticket body (stage px, measured): top edge ~688, bottom ~777; the counter band starts at 786.
    const TOP = 682, BOT = 786;
    // Each price badge covers face x +73..+175 down to y ~729: the frame passes behind it.
    const BADGE_L = 71, BADGE_R = 177, BADGE_B = 731;

    const svg = document.createElementNS(NS, 'svg');
    svg.setAttribute('class', 'sb-svg');
    svg.setAttribute('width', '1920');
    svg.setAttribute('height', '1080');
    svg.setAttribute('viewBox', '0 0 1920 1080');
    svg.setAttribute('aria-hidden', 'true');
    const add = (parent, tag, attrs) => {
      const n = document.createElementNS(NS, tag);
      for (const k in attrs) n.setAttribute(k, attrs[k]);
      parent.appendChild(n);
      return n;
    };
    const rect = (parent, cls, x, y, w, h) => add(parent, 'rect', { class: cls, x, y, width: w, height: h });

    // Stepped-corner rectangle as a polygon (two 2px stairs per corner).
    const stepPoly = (x, y, w, h, s) => {
      const p = [
        [x + 2 * s, y], [x + w - 2 * s, y], [x + w - 2 * s, y + s], [x + w - s, y + s], [x + w - s, y + 2 * s], [x + w, y + 2 * s],
        [x + w, y + h - 2 * s], [x + w - s, y + h - 2 * s], [x + w - s, y + h - s], [x + w - 2 * s, y + h - s], [x + w - 2 * s, y + h],
        [x + 2 * s, y + h], [x + 2 * s, y + h - s], [x + s, y + h - s], [x + s, y + h - 2 * s], [x, y + h - 2 * s],
        [x, y + 2 * s], [x + s, y + 2 * s], [x + s, y + s], [x + 2 * s, y + s],
      ];
      return 'M' + p.map(q => q.join(' ')).join('L') + 'Z';
    };
    // A ring: outer stepped rect minus the rect inset by t (even-odd).
    const ring = (parent, cls, x, y, w, h, t) => add(parent, 'path', {
      class: cls, 'fill-rule': 'evenodd',
      d: stepPoly(x, y, w, h, 2) + stepPoly(x + t, y + t, w - 2 * t, h - 2 * t, 2),
    });

    // Mask: the frame hides behind every price badge of the batch.
    const maskId = 'sb-mask-' + Math.random().toString(36).slice(2, 8);
    const mask = add(add(svg, 'defs', {}), 'mask', { id: maskId, maskUnits: 'userSpaceOnUse', x: 0, y: 0, width: 1920, height: 1080 });
    rect(mask, '', 0, 0, 1920, 1080).setAttribute('fill', '#fff');
    const holes = [];
    for (let i = first; i <= last; i++) {
      const hl = faceL(i) + BADGE_L, hr = faceL(i) + BADGE_R;
      holes.push([hl, hr]);
      rect(mask, '', hl, 0, hr - hl, BADGE_B).setAttribute('fill', '#000');
    }

    const X0 = faceL(first) - 8, X1 = faceR(last) + 8;
    const frame = add(svg, 'g', { mask: `url(#${maskId})` });
    ring(frame, 'sb-ink', X0, TOP, X1 - X0, BOT - TOP, 8);
    ring(frame, 'sb-mus', X0 + 2, TOP + 2, X1 - X0 - 4, BOT - TOP - 4, 4);
    // A 2px light line along the inside of the top band, a printed-edge highlight.
    rect(frame, 'sb-hi', X0 + 6, TOP + 2, X1 - X0 - 12, 2);
    // Ink caps where the frame meets a badge, so it reads as passing behind it.
    for (const [hl, hr] of holes) {
      if (hl > X0 && hl < X1) rect(svg, 'sb-ink', hl - 2, TOP, 2, 8);
      if (hr > X0 && hr < X1) rect(svg, 'sb-ink', hr, TOP, 2, 8);
      // The last badge also covers the frame's right side down to BADGE_B.
      if (hr >= X1) rect(svg, 'sb-ink', X1 - 8, BADGE_B, 8, 2);
    }

    // Binding bars: two solid bars across each gap inside the batch, 2px onto each ticket's
    // outline (the ticket text starts 6px in).
    const BARS = [[738, 12], [758, 12]];
    for (let i = first; i < last; i++) {
      const bx = faceR(i) - 2, bw = faceL(i + 1) - faceR(i) + 4;
      for (const [by, bh] of BARS) {
        rect(svg, 'sb-ink', bx, by, bw, bh);
        rect(svg, 'sb-mus', bx + 2, by + 2, bw - 4, bh - 4);
        rect(svg, 'sb-hi', bx + 2, by + 2, bw - 4, 2);
      }
    }

    // A job out of place: tomato inner outline on its ticket (behind its badge), and its BATCH
    // chip turns tomato with a pixel cross; the chip's tooltip gives the WASTED reason.
    const CROSS = '<svg width="12" height="12" viewBox="0 0 6 6" aria-hidden="true"><path fill="currentColor" d="M0 0h2v1h-2zM4 0h2v1h-2zM1 1h2v1h-2zM3 1h2v1h-2zM2 2h2v2h-2zM1 4h2v1h-2zM3 4h2v1h-2zM0 5h2v1h-2zM4 5h2v1h-2z"/></svg>';
    row.items.forEach((it, i) => {
      if (!it.bad) return;
      const l = faceL(i), r = faceR(i);
      const g = add(svg, 'g', { mask: `url(#${maskId})` });
      // 3px tomato inside the ticket's own outline, with a 1px ink line inside it.
      const ox = l + 2, oy = 690, ow = r - l - 4, oh = 776 - 690;
      add(g, 'path', { class: 'sb-bad', 'fill-rule': 'evenodd', d: `M${ox} ${oy}h${ow}v${oh}h${-ow}Z M${ox + 3} ${oy + 3}v${oh - 6}h${ow - 6}v${-(oh - 6)}Z` });
      // The host marks this ticket's chip (class 'bad', data-index) and its hover already lights
      // the frame and tells the WASTED reason; restyle it only.
      const kw = layer.querySelector(`.kw.bad[data-index="${i}"]`);
      if (!kw) return;
      kw.classList.add('sb-badkw');
      kw.insertAdjacentHTML('beforeend', CROSS);
    });

    layer.appendChild(svg);
    ctx.bracketTargets.push(svg);
  },
};
