// #128 Produce CHAIN, variant C 'links': no frame. Only the interlocked ring pairs in each gap
// inside the chain (lemon-yellow beside a knot, with the "×2" plate), and a single ring bridging
// the gap to a Strawberries placed right before the chain or a Wonky carrot right after it.
window.CHAIN_VARIANTS = window.CHAIN_VARIANTS || {};
window.CHAIN_VARIANTS.links = {
  label: 'Links only',
  note: 'The lightest take: no frame. The tickets of a chain are joined by interlocked ring pairs, lemon-yellow beside a Lemon knot with its ×2 plate, and a helper placed right is hooked on by one single ring. The belt stays quieter, but where a chain starts and stops is read from the gaps alone.',
  render(ctx) {
    const K = window.ChainKit, kit = K.make(ctx.layer);
    ctx.row.chains.forEach((ch, k) => {
      const g = K.add(kit.svg, 'g', {});
      for (let i = ch.first; i < ch.last; i++) K.linkPair(kit, g, K.gapCentre(i), K.knotGap(ch, i) ? K.LEMON : K.GREEN);
      if (ch.feeder != null) K.jumpRing(kit, g, ch.feeder, K.GREEN);
      if (ch.tally != null) K.jumpRing(kit, g, ch.last, K.GREEN);
      const lit = [g];
      for (const s of ch.knots || []) lit.push(K.knotPlate(kit, s, ch.knotText || '×2'));
      ctx.addTargets(k, lit);
    });
    ctx.row.items.forEach((it, i) => { if (it.bad) K.badOutline(kit, i, it.badge); });
  },
};
