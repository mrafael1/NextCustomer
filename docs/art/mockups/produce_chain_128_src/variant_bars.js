// #128 Produce CHAIN, variant B 'bars': the same green frame with Bakery's straight binding bars
// (two per gap, as variant_stripb.js). The knot and the clasps are not drawn: only the CHAIN chips
// on the Lemon, the Strawberries and the Wonky carrot say they belong to the chain.
window.CHAIN_VARIANTS = window.CHAIN_VARIANTS || {};
window.CHAIN_VARIANTS.bars = {
  label: 'Bound frame',
  note: 'Bakery\'s Bound strip, recoloured: the green frame with two straight binding bars across every gap. Nothing marks the Lemon knot or the helpers on the belt; their CHAIN chips do, and hovering one lights the chain it works on. Closest to Bakery, so the two families look like one system, but a chain and a batch then differ only by colour.',
  render(ctx) {
    const K = window.ChainKit, kit = K.make(ctx.layer);
    ctx.row.chains.forEach((ch, k) => {
      const g = K.add(kit.svg, 'g', {});
      K.frame(kit, g, K.chainSlots(ctx.row, ch), K.GREEN);
      for (let i = ch.first; i < ch.last; i++) K.bars(kit, g, i, K.GREEN);
      ctx.addTargets(k, [g]);
    });
    ctx.row.items.forEach((it, i) => { if (it.bad) K.badOutline(kit, i, it.badge); });
  },
};
