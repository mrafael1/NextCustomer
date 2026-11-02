// #128 Produce CHAIN, variant A 'rings' (the spec's): a Produce-green Bound-strip frame round each
// chain (the Bakery frame's geometry: 2 ink, 4 colour, 2 ink, stepped corners, behind the price
// badges); every gap inside the chain is crossed by two interlocked pixel rings; the gaps beside a
// Lemon knot get lemon-yellow rings and the Lemon a small "×2" plate on the frame; a Strawberries
// placed right gets one ring hooked through the frame's left side, a Wonky carrot one through its
// right side. No job words, no arrows.
window.CHAIN_VARIANTS = window.CHAIN_VARIANTS || {};
window.CHAIN_VARIANTS.rings = {
  label: 'Linked frame',
  note: 'The spec\'s take. Each chain is one green frame, Bakery\'s Bound strip in Produce green, and every gap inside it is crossed by two interlocked rings: the chain reads as links. The gaps beside a Lemon knot are lemon-yellow with a small ×2 on the frame. A Strawberries placed right hangs on the frame\'s left side by one ring, a Wonky carrot on its right side. Hovering a CHAIN chip lights that chain, rings and clasps included.',
  render(ctx) {
    const K = window.ChainKit, kit = K.make(ctx.layer);
    ctx.row.chains.forEach((ch, k) => {
      const g = K.add(kit.svg, 'g', {});
      const slots = K.chainSlots(ctx.row, ch);
      const x0 = K.faceL(ch.first) - 8, x1 = K.faceR(ch.last) + 8;
      if (ch.feeder != null) K.claspUnder(kit, g, 'left', x0, x1, K.GREEN);
      if (ch.tally != null) K.claspUnder(kit, g, 'right', x0, x1, K.GREEN);
      K.frame(kit, g, slots, K.GREEN);
      if (ch.feeder != null) K.claspTop(kit, g, 'left', x0, x1, K.GREEN);
      if (ch.tally != null) K.claspTop(kit, g, 'right', x0, x1, K.GREEN);
      for (let i = ch.first; i < ch.last; i++) K.linkPair(kit, g, K.gapCentre(i), K.knotGap(ch, i) ? K.LEMON : K.GREEN);
      const lit = [g];
      for (const s of ch.knots || []) lit.push(K.knotPlate(kit, s, ch.knotText || '×2'));
      ctx.addTargets(k, lit);
    });
    ctx.row.items.forEach((it, i) => { if (it.bad) K.badOutline(kit, i, it.badge); });
  },
};
