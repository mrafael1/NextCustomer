// #128 variant 'ticket': the batch's tickets are joined into one perforated strip (a bake seam
// across each gap) and every job card wears a job tab clipped to its right edge at line 1.
// Nothing is drawn below the tickets. Stage px; see the host page for the ticket geometry.
window.BATCH_VARIANTS = window.BATCH_VARIANTS || {};
window.BATCH_VARIANTS['ticket'] = {
  label: 'Ticket strip',
  note: 'The batch prints as one strip of tickets: a bake seam with a perforation line joins each pair of neighbours, so where a batch starts and ends reads straight off the tickets. Every job card wears a job tab clipped to its right edge (OPENS, FILLS, GLAZES, CLOSES); a job out of place turns its tab red with a cross, and the tab\'s tooltip gives the same reason as its WASTED step. Bread has no job, so it has no tab: the seam alone says it is in the batch. Hovering BATCH lights the seams, the tabs and a frame round every ticket of the batch. Planning only; nothing below the tickets, the count-up is unchanged.',
  render(ctx) {
    const { layer, row, FACE_X, PITCH, FACE_W, el, showTip, hideTip } = ctx;
    if (!document.getElementById('v-ticket')) {
      const s = document.createElement('style');
      s.id = 'v-ticket';
      s.textContent = `
.vt-seam { position: absolute; z-index: 2; height: 24px; background: var(--bake); border-top: 2px solid var(--ink); border-bottom: 2px solid var(--ink); }
.vt-seam::after { content: ''; position: absolute; left: calc(50% - 1px); top: 3px; bottom: 3px; border-left: 2px dashed var(--ink); }
.vt-seam.lit { background: var(--mustard); }
.vt-seam.lit::after { border-left-color: var(--ink); }
.vt-frame { position: absolute; z-index: 1; border: 3px solid var(--mustard); visibility: hidden; pointer-events: none; }
.vt-frame.lit { visibility: visible; }
.vt-tab { position: absolute; z-index: 2; height: 24px; display: flex; align-items: center; gap: 4px; padding: 0 4px; font: 400 15px/18px var(--display); letter-spacing: .02em; color: var(--ink); background: var(--paper); border: 2px solid var(--ink); border-radius: 2px; box-shadow: 0 2px 0 var(--ink); white-space: nowrap; cursor: help; }
.vt-tab:focus-visible { outline: 3px solid var(--paper); outline-offset: 1px; }
.vt-tab.bad { background: var(--tomato); color: var(--paper); }
.vt-tab.lit { background: var(--mustard); color: var(--ink); }
.vt-tab.bad.lit { background: var(--tomato); color: var(--paper); }
.vt-tab svg { display: block; flex: none; shape-rendering: crispEdges; }
`;
      document.head.appendChild(s);
    }
    const [first, last] = row.batch;
    const faceL = i => FACE_X + PITCH * i;
    // Tabs start just past the longest line-1 text ("BATCH last:") and hang over the right edge.
    const TAB_X = 110;
    // A 2px-pixel cross, paper on the red tab.
    const X_SVG = '<svg width="12" height="12" viewBox="0 0 6 6" aria-hidden="true"><path fill="currentColor" d="M0 0h2v1h-2zM4 0h2v1h-2zM1 1h2v1h-2zM3 1h2v1h-2zM2 2h2v2h-2zM1 4h2v1h-2zM3 4h2v1h-2zM0 5h2v1h-2zM4 5h2v1h-2z"/></svg>';

    // Seams: one across every gap inside the batch, at the text band's height.
    for (let i = first; i < last; i++) {
      const seam = el('div', 'vt-seam', { left: (faceL(i) + FACE_W - 3) + 'px', width: (PITCH - FACE_W + 6) + 'px', top: '757px' });
      layer.appendChild(seam);
      ctx.bracketTargets.push(seam);
    }
    // Frames round each ticket of the batch, seen only while BATCH is hovered.
    for (let i = first; i <= last; i++) {
      const f = el('div', 'vt-frame', { left: (faceL(i) - 4) + 'px', top: '683px', width: (FACE_W + 8) + 'px', height: '100px' });
      layer.appendChild(f);
      ctx.bracketTargets.push(f);
    }
    // Job tabs on line 1, clipped over the ticket's right edge.
    row.items.forEach((it, i) => {
      if (!it.role || it.role === 'IN') return;
      const tab = el('div', 'vt-tab' + (it.bad ? ' bad' : ''), { top: '730px', left: (faceL(i) + TAB_X) + 'px' });
      tab.tabIndex = 0;
      tab.appendChild(document.createTextNode(it.role));
      if (it.bad) tab.insertAdjacentHTML('beforeend', X_SVG);
      tab.setAttribute('aria-label', it.tip[0] + '. ' + it.tip[1]);
      layer.appendChild(tab);
      const on = () => showTip(faceL(i) + FACE_W, 730, it.tip[0], it.tip[1], it.bad);
      tab.addEventListener('mouseenter', on); tab.addEventListener('mouseleave', hideTip);
      tab.addEventListener('focus', on); tab.addEventListener('blur', hideTip);
      ctx.bracketTargets.push(tab);
    });
  },
};
