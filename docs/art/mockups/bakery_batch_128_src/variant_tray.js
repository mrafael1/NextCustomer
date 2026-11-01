// Variant 'tray': the batch is a sheet pan on the belt. Its front lip runs under the batch's
// items, in the strip of belt between their bases and the arms rails, with a short end wall at
// each side; each job is a stamp on the lip in front of its item. Nothing under the tickets.
window.BATCH_VARIANTS = window.BATCH_VARIANTS || {};
window.BATCH_VARIANTS['tray'] = {
  label: 'Baking tray',
  note: 'The batch is a baking tray on the belt: a bake-coloured sheet pan whose front lip runs under the batch\'s items, with a short end wall at each side, so the batch is seen where the items sit. Each item\'s job is stamped on the lip in front of it (OPENS, FILLS, GLAZES, CLOSES; plain Bakery reads IN). A job out of place is stamped red with an X, and its tooltip gives the same reason as its WASTED step. Hovering BATCH on a ticket lights the tray. Planning only; the tickets keep just the BATCH chip.',
  render(ctx) {
    if (!document.getElementById('v-tray')) {
      const s = document.createElement('style');
      s.id = 'v-tray';
      s.textContent = `
.vt-lip, .vt-end, .vt-ear { position: absolute; background: var(--bake); border: 2px solid var(--ink); }
/* Lip: dark inner wall along the top (the pan's inside), a light rolled edge, a shaded foot. */
.vt-lip { box-shadow: inset 0 4px 0 var(--bake-shade), inset 0 6px 0 var(--bake-light), inset 0 -3px 0 var(--bake-shade), 0 3px 0 rgba(0,0,0,.45); }
.vt-end { box-shadow: inset 3px 0 0 var(--bake-light), inset -3px 0 0 var(--bake-shade), 0 3px 0 rgba(0,0,0,.45); }
.vt-ear { box-shadow: inset 0 3px 0 var(--bake-light), inset 0 -3px 0 var(--bake-shade); }
.vt-lip.lit, .vt-end.lit, .vt-ear.lit { background: var(--mustard); }
.vt-lip.lit { box-shadow: inset 0 4px 0 var(--mustard-dark), inset 0 6px 0 #f6d77a, inset 0 -3px 0 var(--mustard-dark), 0 3px 0 rgba(0,0,0,.45); }
.vt-end.lit { box-shadow: inset 3px 0 0 #f6d77a, inset -3px 0 0 var(--mustard-dark), 0 3px 0 rgba(0,0,0,.45); }
.vt-ear.lit { box-shadow: inset 0 3px 0 #f6d77a, inset 0 -3px 0 var(--mustard-dark); }
.vt-stamp { position: absolute; transform: translateX(-50%); height: 26px; padding: 0 7px;
  font: 400 21px/22px var(--display); letter-spacing: .06em; color: var(--ink); white-space: nowrap;
  background: var(--cream); border: 2px solid var(--ink); border-radius: 2px; cursor: help; }
.vt-stamp.in { background: transparent; border-color: transparent; opacity: .8; }
.vt-stamp.bad { background: var(--tomato); color: var(--paper); }
.vt-stamp:hover, .vt-stamp:focus-visible { outline: 2px solid var(--paper); outline-offset: 0; }
.vt-stamp.bad:hover, .vt-stamp.bad:focus-visible { outline-color: var(--ink); }
.vt-lip.lit ~ .vt-stamp.in { opacity: 1; }
@media (prefers-reduced-motion: reduce) { .vt-lip, .vt-end, .vt-ear { transition: none; } }
`;
      document.head.appendChild(s);
    }
    const { layer, row, FACE_X, PITCH, FACE_W, center, el, showTip, hideTip } = ctx;
    const [first, last] = row.batch;
    // Pan spans the batch's ticket faces plus a little, between the item bases and the rails.
    const left = FACE_X + PITCH * first - 14, right = FACE_X + PITCH * last + FACE_W + 17;
    const lipTop = 601, lipBottom = 629, endTop = 576;
    const box = (cls, x, y, w, h) => el('div', cls, { left: x + 'px', top: y + 'px', width: w + 'px', height: h + 'px' });
    // Ears: the pan's rolled handles, poking out past each end wall.
    const earL = box('vt-ear', left - 10, lipTop + 4, 14, 12), earR = box('vt-ear', right - 4, lipTop + 4, 14, 12);
    const endL = box('vt-end', left, endTop, 12, lipBottom - endTop), endR = box('vt-end', right - 12, endTop, 12, lipBottom - endTop);
    const lip = box('vt-lip', left, lipTop, right - left, lipBottom - lipTop);
    [earL, earR, endL, endR, lip].forEach(d => layer.appendChild(d));
    ctx.bracketTargets.push(lip, endL, endR, earL, earR);
    row.items.forEach((it, i) => {
      if (i < first || i > last) return;
      const cls = 'vt-stamp' + (it.bad ? ' bad' : it.role === 'IN' ? ' in' : ' job');
      const st = el('div', cls, { left: center(i) + 'px', top: (lipTop + 1) + 'px' });
      st.textContent = it.role + (it.bad ? ' ✗' : '');
      st.tabIndex = 0;
      st.setAttribute('aria-label', it.tip[0] + '. ' + it.tip[1]);
      const on = () => showTip(center(i), lipTop - 4, it.tip[0], it.tip[1], it.bad);
      st.addEventListener('mouseenter', on); st.addEventListener('mouseleave', hideTip);
      st.addEventListener('focus', on); st.addEventListener('blur', hideTip);
      layer.appendChild(st);
    });
  },
};
