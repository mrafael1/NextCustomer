// #77 prep, round 2: the ONE draw process of the RECEIPT REWARDS machine, DOM-free.
// gen_flow.py inlines this file into machine_77_flow.html; check_odds.js runs it in node against a forward
// simulation. The odds card (tree + stats) and the page's "real roll" (simulate) both come from here.
//
// The process, per visit:
//   1. Each of 3 drops rolls a rarity from ODDS[level] (REGULAR 3: drop 1 rolls RARE or LEGENDARY only).
//   2. The drop takes a prize of that rarity, uniform among the candidates: never a prize twice in one draw, and
//      REGISTER never repeats a type. A rarity with no candidate steps down a tier, then up (empty-tier fallback).
//   3. Guarantee swap (NEW ITEMS: 1 generally useful product; first COUPONS visit: 1 first_offer_pool coupon):
//      if none of the 3 is one, the last drop whose rarity holds one is swapped for one of that same rarity,
//      uniform. If no drop's rarity holds one, the guarantee is skipped for that visit.
// Chutes:
//   new      NEW ITEMS = more items. A stocked product, always plain; its rarity is the product's own
//            (product_rarity.json).
//   coupons  COUPONS: the coupon tiers.
//   register REGISTER: the register tiers, owned ones removed.
//   upgrades UPGRADES = better items. Prize = (item, tier): COMMON one step on one copy, RARE two steps on one
//            plain copy (straight to GOLDEN), LEGENDARY "SHELF UPGRADE" (every copy of the item one step up).
//            An item is a candidate only when a copy can take its steps; for SHELF UPGRADE, at least 2 copies (on one
//            copy it would be the COMMON step), so a cart with no such item steps LEGENDARY down a tier.
// Card numbers: a tier's "% per drop" is over the prizes that actually drop (short draws included), so the 3 rows
// always add up to 100%.
(function (root) {
  'use strict';
  const ODDS = [[75, 22, 3], [65, 28, 7], [55, 33, 12], [45, 37, 18]];
  const TIERS = ['common', 'rare', 'legendary'];
  const COUP_TIER = { final_markdown: 0, breakfast_sticker: 0, clearance_tag: 0, shelf_swap: 0, repeat: 1, two_for_one: 1, multipack: 1, opening_deal: 2 };
  const REG_TIER = { extra_redraw: 0, big_basket: 0, extra_coupon_slot: 0, category_engine: 1, coupon_engine: 1, slot_engine: 2 };
  const REG_TYPE = { extra_redraw: 'Economy', extra_coupon_slot: 'Economy', big_basket: 'Risky', coupon_engine: 'Coupon engine', category_engine: 'Category engine', slot_engine: 'Slot engine' };
  const FOP = ['breakfast_sticker', 'multipack', 'two_for_one']; // first_offer_pool
  const UPGRADABLE = ['banana', 'milk', 'eggs', 'coffee']; // products with a BIG drawing
  const STAPLES = ['banana', 'bread', 'milk', 'eggs', 'coffee', 'soup'];
  const STARTER = ['banana', 'banana', 'banana', 'bread', 'bread', 'milk', 'milk', 'eggs', 'eggs', 'coffee', 'coffee', 'soup', 'final_markdown'];
  // the page's invented run history (visit after shift k) and what each visit took
  const HISTORY = { 1: 'new', 2: 'coupons', 3: 'upgrades', 4: 'register', 5: 'upgrades', 6: 'coupons' };
  const HISTORY_TAKE = { 1: { add: 'milk' }, 2: { bin: true }, 3: { step: 'eggs', n: 1 }, 4: {}, 5: { step: 'milk', n: 2 }, 6: { bin: true } };

  const pkey = p => p.kind + ':' + p.id + ':' + p.tier;

  function create(data) {
    const rarity = {}; // product id -> 0/1/2
    TIERS.forEach((k, t) => data.rarity.tiers[k].forEach(id => { rarity[id] = t; }));
    const GU = new Set(data.rarity.generally_useful);

    // ---- run state helpers (shared by the page and the node check)
    function stockFor(opt) {
      if (opt === 'fresh') return data.rarity.fresh_profile_stock.slice();
      const ais = opt.split('+');
      return STAPLES.concat(...ais.map(a => data.aisles[a].items));
    }
    function cartAt(shift) { // [{id, tier}] the cart before the visit after `shift`
      const cart = STARTER.map(id => ({ id, tier: 0 }));
      for (let k = 1; k < shift; k++) {
        const h = HISTORY_TAKE[k];
        if (h.add) cart.push({ id: h.add, tier: 0 });
        if (h.step) { const c = cart.find(x => x.id === h.step && x.tier === 0); if (c) c.tier = Math.min(2, c.tier + h.n); }
      }
      return cart;
    }

    // ---- pools: [common, rare, legendary] lists of prizes
    function pools(chute, st) {
      if (chute === 'new') return [0, 1, 2].map(t => st.stock.filter(id => rarity[id] === t).map(id => ({ kind: 'product', id, tier: t })));
      if (chute === 'coupons') return [0, 1, 2].map(t => Object.keys(COUP_TIER).filter(id => COUP_TIER[id] === t).map(id => ({ kind: 'coupon', id, tier: t })));
      if (chute === 'register') return [0, 1, 2].map(t => Object.keys(REG_TIER).filter(id => REG_TIER[id] === t && !st.ownedIds.includes(id)).map(id => ({ kind: 'register', id, tier: t })));
      const items = UPGRADABLE.filter(id => st.cart.some(c => c.id === id));
      const can = [id => st.cart.some(c => c.id === id && c.tier < 2), id => st.cart.some(c => c.id === id && c.tier === 0), id => st.cart.filter(c => c.id === id && c.tier < 2).length >= 2];
      return [0, 1, 2].map(t => items.filter(can[t]).map(id => ({ kind: 'upgrade', id, tier: t })));
    }
    function guarantee(chute, st) {
      if (chute === 'new') return new Set(st.stock.filter(id => GU.has(id)));
      if (chute === 'coupons' && st.firstCoupons) return new Set(FOP);
      return null;
    }
    function tierWeights(lvl, i) { const o = ODDS[lvl]; return lvl === 3 && i === 0 ? [0, o[1], o[2]] : o.slice(); }
    function candidates(chute, pl, t, seq) {
      let c = pl[t].filter(p => !seq.some(q => pkey(q) === pkey(p)));
      if (chute === 'register') c = c.filter(p => !seq.some(q => REG_TYPE[q.id] === REG_TYPE[p.id]));
      return c;
    }
    function land(chute, pl, t, seq) { // the empty-tier fallback: down a tier, then up
      const order = [t]; for (let d = t - 1; d >= 0; d--) order.push(d); for (let u = t + 1; u < 3; u++) order.push(u);
      for (const u of order) { const c = candidates(chute, pl, u, seq); if (c.length) return c; }
      return null;
    }
    function swaps(pl, seq, g) { // the guarantee swap: alternatives (equally likely) for a finished draw
      if (!g || seq.some(p => g.has(p.id))) return { held: !!g, alts: [seq] };
      for (let j = seq.length - 1; j >= 0; j--) {
        const c = pl[seq[j].tier].filter(p => g.has(p.id) && !seq.some(q => pkey(q) === pkey(p)));
        if (c.length) return { held: true, alts: c.map(p => { const s = seq.slice(); s[j] = p; return s; }) };
      }
      return { held: false, alts: [seq] };
    }

    // ---- exact: every possible draw with its probability
    const TREES = new Map();
    function stKey(chute, st) { return [chute, st.lvl, (st.ownedIds || []).join(','), !!st.firstCoupons, (st.stock || []).join(','), (st.cart || []).map(c => c.id + c.tier).join(',')].join('|'); }
    function tree(chute, st) {
      const key = stKey(chute, st); if (TREES.has(key)) return TREES.get(key);
      const pl = pools(chute, st), g = guarantee(chute, st), out = [];
      (function step(i, seq, pr) {
        if (i === 3) {
          const s = swaps(pl, seq, g); s.alts.forEach(a => out.push({ seq: a, pr: pr / s.alts.length, held: s.held, guarded: !!g })); return;
        }
        const w = tierWeights(st.lvl, i), tot = w[0] + w[1] + w[2];
        for (let t = 0; t < 3; t++) {
          if (!w[t]) continue; const q = pr * w[t] / tot, c = land(chute, pl, t, seq);
          if (!c) { const s = swaps(pl, seq, g); s.alts.forEach(a => out.push({ seq: a, pr: q / s.alts.length, held: s.held, guarded: !!g })); continue; }
          c.forEach(p => step(i + 1, seq.concat([p]), q / c.length));
        }
      })(0, [], 1);
      TREES.set(key, out); return out;
    }
    function stats(chute, st) {
      const X = { pR: 0, pL: 0, share: [0, 0, 0], first: [0, 0, 0], rest: [0, 0, 0], inDraw: {}, held: 0, short: 0, guarded: false };
      tree(chute, st).forEach(({ seq, pr, held, guarded }) => {
        X.guarded = guarded;
        if (seq.some(p => p.tier >= 1)) X.pR += pr; if (seq.some(p => p.tier === 2)) X.pL += pr; if (seq.length < 3) X.short += pr; if (held) X.held += pr;
        seq.forEach((p, i) => { X.share[p.tier] += pr / seq.length; if (i === 0) X.first[p.tier] += pr; else X.rest[p.tier] += pr / (seq.length - 1); X.inDraw[pkey(p)] = (X.inDraw[pkey(p)] || 0) + pr; });
      });
      // over the drops that land: a short draw still adds up to 100% (rest: drops 2-3, when there are any)
      const nz = a => { const tot = a[0] + a[1] + a[2]; return tot > 0 ? a.map(v => v / tot) : a; };
      X.share = nz(X.share); X.first = nz(X.first); X.rest = nz(X.rest);
      return X;
    }

    // ---- the forward process (what the game would run), seeded
    function simulate(chute, st, rng) {
      const pl = pools(chute, st), g = guarantee(chute, st), seq = [];
      for (let i = 0; i < 3; i++) {
        const w = tierWeights(st.lvl, i), tot = w[0] + w[1] + w[2];
        let r = rng() * tot, t = 0; while (t < 2 && (r >= w[t] || !w[t])) { r -= w[t]; t++; }
        const c = land(chute, pl, t, seq); if (!c) break;
        seq.push(c[Math.floor(rng() * c.length)]);
      }
      const s = swaps(pl, seq, g);
      return { seq: s.alts[Math.floor(rng() * s.alts.length)], held: s.held };
    }

    // ---- what an UPGRADES prize does to the cart: the copies it changes, and their tiers after
    function upgradeTargets(p, cart) {
      const idx = cart.map((c, i) => [c, i]).filter(([c]) => c.id === p.id);
      if (p.tier === 0) { const best = idx.filter(([c]) => c.tier < 2).sort((a, b) => b[0].tier - a[0].tier)[0]; return best ? [{ i: best[1], from: best[0].tier, to: best[0].tier + 1 }] : []; }
      if (p.tier === 1) { const pl = idx.find(([c]) => c.tier === 0); return pl ? [{ i: pl[1], from: 0, to: 2 }] : []; }
      return idx.filter(([c]) => c.tier < 2).map(([c, i]) => ({ i, from: c.tier, to: c.tier + 1 }));
    }

    // ---- round 3 idea, the BONUS TICKET: the run state after a visit's pick, which a second visit in the same shift
    // draws from. `rises`: the visit's REGULAR meter went up. The caller sets the second visit's chute, lvl and rises.
    function afterPick(st, p, rises) {
      const s = Object.assign({}, st, { levels: Object.assign({}, st.levels || {}), cart: st.cart.map(c => ({ id: c.id, tier: c.tier })), ownedIds: (st.ownedIds || []).slice() });
      if (rises) s.levels[st.chute] = Math.min(3, (st.levels ? st.levels[st.chute] : st.lvl) + 1);
      if (p) {
        if (p.kind === 'register') s.ownedIds.push(p.id);
        else if (p.kind === 'upgrade') upgradeTargets(p, st.cart).forEach(x => { s.cart[x.i].tier = x.to; });
        else s.cart.push({ id: p.id, tier: 0 }); // a product (plain) or a coupon joins the cart
      }
      if (st.chute === 'coupons') s.firstCoupons = false;
      s.owned = s.ownedIds.length; s.full = s.owned >= 3; s.cartN = s.cart.length;
      return s;
    }

    return { ODDS, TIERS, COUP_TIER, REG_TIER, REG_TYPE, FOP, UPGRADABLE, STAPLES, HISTORY, HISTORY_TAKE, rarity, GU, pkey,
      stockFor, cartAt, pools, guarantee, tierWeights, land, tree, stats, simulate, upgradeTargets, afterPick };
  }
  const api = { create, pkey };
  if (typeof module !== 'undefined' && module.exports) module.exports = api; else root.DRAW77 = api;
})(typeof window !== 'undefined' ? window : globalThis);
