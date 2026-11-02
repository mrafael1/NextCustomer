// Variant 'band': the batch is a recessed channel cut into the dark counter band under the
// tickets (stage y 786..824), with each item's job printed inside it, centred under its ticket.
// Nothing floats over the baskets and nothing leaves the band.
window.BATCH_VARIANTS = window.BATCH_VARIANTS || {};
window.BATCH_VARIANTS['band'] = {
  label: 'Counter channel',
  note: 'The batch is cut into the counter: a recessed channel in the dark band under the tickets, as wide as the batch, with each item\'s job printed in it under its ticket (OPENS, FILLS, GLAZES and CLOSES in mustard, IN in muted bake). A job out of place prints in tomato with an X on a red-tinted cell, and its tooltip gives the same reason as its WASTED step. Hovering a BATCH chip lights the channel\'s rim. It stays inside the band, so the baskets and the counter edge are untouched; planning only.',
  render(ctx) {
    const { layer, row, center, FACE_X, PITCH, FACE_W, el, showTip, hideTip } = ctx;
    if (!document.getElementById('v-band')) {
      const s = document.createElement('style');
      s.id = 'v-band';
      s.textContent = `
        .vb-chan { position: absolute; top: 790px; height: 30px; background: #1d1916;
          box-shadow: inset 0 3px 0 #120f0d, inset 0 -2px 0 #4a423b, 0 0 0 2px #2b2420; }
        .vb-chan.lit { box-shadow: inset 0 3px 0 #120f0d, inset 0 -2px 0 #4a423b, 0 0 0 2px #e2b33c; }
        .vb-chan.lit .vb-cell:not(.bad) { color: #ffcf3f; }
        .vb-chan.lit .vb-cell.in { color: #f3e9d2; }
        .vb-cell { position: absolute; top: 0; height: 30px; display: flex; align-items: center;
          justify-content: center; font: 400 24px/1 var(--display); letter-spacing: .08em;
          color: #e2b33c; cursor: help; padding-top: 2px; }
        .vb-cell.in { color: #c2a57e; }
        .vb-cell.bad { color: #ff6f69; background: #4a1f1c; box-shadow: inset 0 3px 0 #241010, inset 0 -2px 0 #d9534f; }
        .vb-cell:hover, .vb-cell:focus-visible { outline: 2px solid #f3e9d2; outline-offset: -2px; }
        .vb-x { display: inline-block; width: 12px; height: 12px; margin-left: 8px; position: relative; top: -1px; }
        .vb-x svg { display: block; shape-rendering: crispEdges; }
        .vb-tick { position: absolute; top: 9px; width: 2px; height: 12px; background: #3a332e; }
        @media (prefers-reduced-motion: reduce) { .vb-chan { transition: none; } }
      `;
      document.head.appendChild(s);
    }
    const [first, last] = row.batch;
    const left = FACE_X + PITCH * first - 4;
    const right = FACE_X + PITCH * last + FACE_W + 4;
    const chan = el('div', 'vb-chan', { left: left + 'px', width: (right - left) + 'px' });
    layer.appendChild(chan);
    for (let i = first; i <= last; i++) {
      const it = row.items[i];
      // Each cell runs from gap centre to gap centre, clipped to the channel.
      const cl = Math.max(left, center(i) - PITCH / 2), cr = Math.min(right, center(i) + PITCH / 2);
      const cell = el('div', 'vb-cell' + (it.bad ? ' bad' : it.role === 'IN' ? ' in' : ''),
        { left: (cl - left) + 'px', width: (cr - cl) + 'px' });
      cell.textContent = it.role;
      if (it.bad) {
        // A pixel cross (the Strip variant's), not rotated bars: it stays sharp at any scale.
        const x = el('span', 'vb-x');
        x.innerHTML = '<svg width="12" height="12" viewBox="0 0 6 6" aria-hidden="true"><path fill="currentColor" d="M0 0h2v1h-2zM4 0h2v1h-2zM1 1h2v1h-2zM3 1h2v1h-2zM2 2h2v2h-2zM1 4h2v1h-2zM3 4h2v1h-2zM0 5h2v1h-2zM4 5h2v1h-2z"/></svg>';
        cell.appendChild(x);
      }
      cell.tabIndex = 0;
      cell.setAttribute('aria-label', it.tip[0] + '. ' + it.tip[1]);
      const on = () => showTip(center(i), 788, it.tip[0], it.tip[1], it.bad);
      cell.addEventListener('mouseenter', on); cell.addEventListener('mouseleave', hideTip);
      cell.addEventListener('focus', on); cell.addEventListener('blur', hideTip);
      chan.appendChild(cell);
      if (i < last) chan.appendChild(el('div', 'vb-tick', { left: (cr - left - 1) + 'px' }));
    }
    ctx.bracketTargets.push(chan);
  },
};
