// #128 Produce chains: the pixel pieces the three CHAIN variants share. Everything is drawn in
// stage px (the 1920x1080 capture) on a 2 px grid with crisp edges. Geometry comes from the host
// page (ticket i's face spans x 555+192i .. 709+192i; the ticket body y 684..785; the counter band
// starts at 786, and nothing is drawn below it).
//
// Pieces:
//  frame(g, x0, x1, pal)        the Bound-strip frame (2 ink, 4 colour, 2 ink, stepped corners),
//                               approved for Bakery as variant_stripb.js, in a chain palette
//  linkPair(g, xc, pal)         two interlocked rings crossing a gap centred on xc
//  clasp(g, side, x0, x1, pal)  one ring hooked through the frame's left or right side
//  jumpRing(g, xc, pal)         one ring bridging a gap (the no-frame take's clasp)
//  bars(g, i, pal)              Bakery's two straight binding bars across the gap after ticket i
//  badOutline(g, i)             the tomato inner outline of a ticket out of place
// Each palette is { face, hi } class names; 'ink' is shared.
window.ChainKit = (function () {
  const NS = 'http://www.w3.org/2000/svg';
  const FACE_X = 555, PITCH = 192, FACE_W = 154;
  const faceL = i => FACE_X + PITCH * i;
  const faceR = i => faceL(i) + FACE_W;
  const TOP = 682, BOT = 786;
  // Badge footprints (x relative to the face, bottom y): the frame tucks behind them.
  const HOLES = { gold: [71, 177, 731], plain: [86, 165, 721] };
  // The rings: outer 30x24 (a 14x8 hole), centred on the ticket text block.
  const RING_W = 30, RING_H = 24, RING_Y = 742, OVERLAP = 16;

  function style() {
    if (document.getElementById('chain-kit-style')) return;
    const s = document.createElement('style');
    s.id = 'chain-kit-style';
    s.textContent = `
.ck-svg { position: absolute; left: 0; top: 0; z-index: 2; pointer-events: none; overflow: visible; shape-rendering: crispEdges; }
.ck-svg .ink { fill: #2b2420; }
.ck-svg .grn { fill: #a9dd45; }
.ck-svg .grn-hi { fill: #e3f8a6; }
.ck-svg .lem { fill: #f5d93a; }
.ck-svg .lem-hi { fill: #fff6b0; }
.ck-svg .bad { fill: #d9534f; }
.ck-svg g.lit .grn, .ck-svg g.lit .lem { fill: #ffdb5c; }
.ck-svg g.lit .grn-hi, .ck-svg g.lit .lem-hi { fill: #fbf7ee; }
.ck-x2 { position: absolute; z-index: 3; height: 22px; padding: 0 6px; background: #f5d93a; color: #2b2420; border: 2px solid #2b2420; font: 400 19px/18px Pixelify, monospace; letter-spacing: .04em; pointer-events: none; }
.ck-x2.lit { background: #ffdb5c; }
`;
    document.head.appendChild(s);
  }

  function make(layer) {
    style();
    const svg = document.createElementNS(NS, 'svg');
    svg.setAttribute('class', 'ck-svg');
    svg.setAttribute('width', '1920');
    svg.setAttribute('height', '1080');
    svg.setAttribute('viewBox', '0 0 1920 1080');
    svg.setAttribute('aria-hidden', 'true');
    layer.appendChild(svg);
    const defs = add(svg, 'defs', {});
    return { svg, defs, layer };
  }
  function add(parent, tag, attrs) {
    const n = document.createElementNS(NS, tag);
    for (const k in attrs) n.setAttribute(k, attrs[k]);
    parent.appendChild(n);
    return n;
  }
  const rect = (parent, cls, x, y, w, h) => add(parent, 'rect', { class: cls, x, y, width: w, height: h });
  // Stepped-corner rectangle: two s-px stairs per corner.
  function stepPoly(x, y, w, h, s) {
    const p = [
      [x + 2 * s, y], [x + w - 2 * s, y], [x + w - 2 * s, y + s], [x + w - s, y + s], [x + w - s, y + 2 * s], [x + w, y + 2 * s],
      [x + w, y + h - 2 * s], [x + w - s, y + h - 2 * s], [x + w - s, y + h - s], [x + w - 2 * s, y + h - s], [x + w - 2 * s, y + h],
      [x + 2 * s, y + h], [x + 2 * s, y + h - s], [x + s, y + h - s], [x + s, y + h - 2 * s], [x, y + h - 2 * s],
      [x, y + 2 * s], [x + s, y + 2 * s], [x + s, y + s], [x + 2 * s, y + s],
    ];
    return 'M' + p.map(q => q.join(' ')).join('L') + 'Z';
  }
  const ringPath = (parent, cls, x, y, w, h, t, s) => add(parent, 'path', {
    class: cls, 'fill-rule': 'evenodd', d: stepPoly(x, y, w, h, s) + stepPoly(x + t, y + t, w - 2 * t, h - 2 * t, s),
  });
  let uid = 0;
  const id = p => `${p}-${++uid}-${Math.random().toString(36).slice(2, 6)}`;

  // A group masked so it passes behind the badges of the given slots ({slot, badge}).
  function maskedGroup(kit, parent, slots) {
    const mid = id('ck-mask');
    const mask = add(kit.defs, 'mask', { id: mid, maskUnits: 'userSpaceOnUse', x: 0, y: 0, width: 1920, height: 1080 });
    rect(mask, '', 0, 0, 1920, 1080).setAttribute('fill', '#fff');
    for (const { slot, badge } of slots) {
      const h = HOLES[badge];
      if (!h) continue;
      rect(mask, '', faceL(slot) + h[0], 0, h[1] - h[0], h[2]).setAttribute('fill', '#000');
    }
    return add(parent, 'g', { mask: `url(#${mid})` });
  }

  // The frame round slots first..last (x0, x1 its outer edges), masked behind their badges, with
  // ink caps where it meets a badge so it reads as passing behind it.
  function frame(kit, g, slots, pal) {
    const first = slots[0].slot, last = slots[slots.length - 1].slot;
    const x0 = faceL(first) - 8, x1 = faceR(last) + 8;
    const m = maskedGroup(kit, g, slots);
    ringPath(m, 'ink', x0, TOP, x1 - x0, BOT - TOP, 8, 2);
    ringPath(m, pal.face, x0 + 2, TOP + 2, x1 - x0 - 4, BOT - TOP - 4, 4, 2);
    rect(m, pal.hi, x0 + 6, TOP + 2, x1 - x0 - 12, 2);
    for (const { slot, badge } of slots) {
      const h = HOLES[badge];
      if (!h) continue;
      const hl = faceL(slot) + h[0], hr = faceL(slot) + h[1];
      if (hl > x0 && hl < x1) rect(g, 'ink', hl - 2, TOP, 2, 8);
      if (hr > x0 && hr < x1) rect(g, 'ink', hr, TOP, 2, 8);
      if (hr >= x1) rect(g, 'ink', x1 - 8, h[2], 8, 2);
    }
    return { x0, x1 };
  }

  // One ring: ink outer band (8 px), colour inside it (4 px), a 2 px highlight on its top inside.
  function ring(parent, x, y, w, h, pal) {
    const r = add(parent, 'g', {});
    ringPath(r, 'ink', x, y, w, h, 8, 2);
    ringPath(r, pal.face, x + 2, y + 2, w - 4, h - 4, 4, 2);
    rect(r, pal.hi, x + 6, y + 2, w - 12, 2);
    return r;
  }
  // Redraws the part of a ring inside the clip rect over whatever was drawn after it.
  function over(kit, parent, x, y, w, h, pal, cx, cy, cw, ch) {
    const cid = id('ck-clip');
    const cp = add(kit.defs, 'clipPath', { id: cid });
    rect(cp, '', cx, cy, cw, ch);
    ring(add(parent, 'g', { 'clip-path': `url(#${cid})` }), x, y, w, h, pal);
  }

  // Two rings crossing a gap, interlocked: the left ring runs over the right one on top and under
  // it at the bottom.
  function linkPair(kit, g, xc, pal) {
    const lx = xc - (2 * RING_W - OVERLAP) / 2, rx = lx + RING_W - OVERLAP;
    ring(g, rx, RING_Y, RING_W, RING_H, pal);
    ring(g, lx, RING_Y, RING_W, RING_H, pal);
    over(kit, g, rx, RING_Y, RING_W, RING_H, pal, rx, RING_Y + RING_H - 8, RING_W - 8, 8);
  }
  const gapCentre = i => (faceR(i) + faceL(i + 1)) / 2;

  // A clasp: one wider ring whose far band hooks through the frame's side. Drawn in two passes:
  // under() before the frame (the side hides the ring's band), top() after it (the ring's bottom
  // band crosses over the side).
  const CLASP_W = 38;
  function claspBox(side, x0, x1) {
    return side === 'left' ? { x: x0 - 28, w: CLASP_W } : { x: x1 - 10, w: CLASP_W };
  }
  function claspUnder(kit, g, side, x0, x1, pal) {
    const b = claspBox(side, x0, x1);
    ring(g, b.x, RING_Y, b.w, RING_H, pal);
  }
  function claspTop(kit, g, side, x0, x1, pal) {
    const b = claspBox(side, x0, x1);
    const sx = side === 'left' ? x0 : x1 - 8;
    over(kit, g, b.x, RING_Y, b.w, RING_H, pal, sx, RING_Y + RING_H - 8, 8, 8);
  }
  // The no-frame clasp: one ring bridging the gap after ticket i, onto both tickets' outlines.
  function jumpRing(kit, g, i, pal) {
    const xc = gapCentre(i);
    ring(g, xc - CLASP_W / 2, RING_Y, CLASP_W, RING_H, pal);
  }
  // Bakery's straight binding bars across the gap after ticket i (variant_stripb.js).
  function bars(kit, g, i, pal) {
    const bx = faceR(i) - 2, bw = faceL(i + 1) - faceR(i) + 4;
    for (const [by, bh] of [[738, 12], [758, 12]]) {
      rect(g, 'ink', bx, by, bw, bh);
      rect(g, pal.face, bx + 2, by + 2, bw - 4, bh - 4);
      rect(g, pal.hi, bx + 2, by + 2, bw - 4, 2);
    }
  }
  // The tomato inner outline of ticket i (3 px inside its own outline, behind its badge).
  function badOutline(kit, i, badge) {
    const g = maskedGroup(kit, kit.svg, [{ slot: i, badge }]);
    const ox = faceL(i) + 2, oy = 690, ow = FACE_W - 4, oh = 776 - 690;
    add(g, 'path', { class: 'bad', 'fill-rule': 'evenodd', d: `M${ox} ${oy}h${ow}v${oh}h${-ow}Z M${ox + 3} ${oy + 3}v${oh - 6}h${ow - 6}v${-(oh - 6)}Z` });
  }
  // The knot's small "×2" plate, on the frame's bottom band under the right of the Lemon's ticket.
  function knotPlate(kit, slot, text) {
    const d = document.createElement('div');
    d.className = 'ck-x2';
    d.textContent = text;
    Object.assign(d.style, { left: (faceL(slot) + 104) + 'px', top: '764px' });
    kit.layer.appendChild(d);
    return d;
  }
  const GREEN = { face: 'grn', hi: 'grn-hi' }, LEMON = { face: 'lem', hi: 'lem-hi' };
  return {
    make, add, rect, frame, linkPair, gapCentre, claspUnder, claspTop, jumpRing, bars, badOutline, knotPlate,
    faceL, faceR, GREEN, LEMON,
    // The chain's slots with their badges, for frame() and the masks.
    chainSlots: (row, ch) => { const s = []; for (let i = ch.first; i <= ch.last; i++) s.push({ slot: i, badge: row.items[i].badge }); return s; },
    // The gap after slot i is a knot gap when either side is a Lemon knot.
    knotGap: (ch, i) => (ch.knots || []).includes(i) || (ch.knots || []).includes(i + 1),
  };
})();
