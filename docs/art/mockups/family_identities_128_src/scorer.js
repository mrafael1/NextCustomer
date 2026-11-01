// #128 mock-up scorer: a small copy of the game's scoring order (PROTOTYPE_PLAN section 3.2, as in
// machine_loyalty_108_src/scorer.js) for products only (no coupons, no perks). The cards are the 20 products
// a fresh profile stocks plus the capsule unlocks the page names, with today's rules (data/cards) and, for
// the redesign candidates, the candidate rule (`next`). Not the game's code; `node scorer_test.js` checks it.
//
// Order per card: base, + its own flat bonus, + flat effects waiting for it (Coffee's +3...) = its price (what
// a chain reads); x multiplier effects waiting for it (Eggs, Tea bags...) = its payout. Then its effects arm.
'use strict';

const CARDS = {
  // ---- the fresh stock: 6 staples and 14 base aisle items
  bread:          {name: 'Bread', base: 5, tags: ['Food', 'Breakfast', 'Bakery'], rule: {t: 'none'}, text: 'No rule'},
  banana:         {name: 'Banana', base: 2, tags: ['Food', 'Produce'], rule: {t: 'chain'}, text: '+ the price of the Banana just before it'},
  milk:           {name: 'Milk', base: 4, tags: ['Food', 'Breakfast', 'Dairy'], rule: {t: 'perEarlier', tag: 'Breakfast', n: 1}, text: '+1 per earlier Breakfast'},
  eggs:           {name: 'Eggs', base: 1, tags: ['Food', 'Breakfast'], rule: {t: 'armMult', tag: 'Food', f: 2}, text: '×2 next Food'},
  coffee:         {name: 'Coffee', base: 2, tags: ['Breakfast'], rule: {t: 'armFlat', tag: 'Breakfast', n: 3}, text: '+3 to the next Breakfast'},
  soup:           {name: 'Soup', base: 5, tags: ['Food'], rule: {t: 'zeroBeside', tag: 'Frozen'}, text: 'Pays 0 beside a Frozen product'},
  cheese:         {name: 'Cheese', base: 3, tags: ['Food', 'Dairy'], rule: {t: 'afterId', id: 'bread', n: 4}, text: '+4 just after Bread'},
  cereal:         {name: 'Cereal', base: 2, tags: ['Food', 'Breakfast'], rule: {t: 'besideId', id: 'milk', n: 3}, text: '+3 beside Milk'},
  tea_bags:       {name: 'Tea bags', base: 1, tags: ['Breakfast'], rule: {t: 'armMult', tag: 'Breakfast', f: 4}, text: '×4 next Breakfast'},
  carrier_bag:    {name: 'Carrier bag', base: 1, tags: ['Household'], rule: {t: 'perEarlier', tag: 'Food', n: 5}, text: '+5 per earlier Food'},
  frozen_peas:    {name: 'Frozen peas', base: 3, tags: ['Food', 'Frozen', 'Produce'], rule: {t: 'beside', tag: 'Frozen', n: 3}, text: '+3 beside another Frozen'},
  butter:         {name: 'Butter', base: 2, tags: ['Food', 'Dairy'], rule: {t: 'beside', tag: 'Bakery', n: 3}, text: '+3 beside Bakery'},
  yogurt:         {name: 'Yogurt', base: 2, tags: ['Food', 'Dairy', 'Breakfast'], rule: {t: 'afterId', id: 'banana', n: 3}, text: '+3 just after Banana'},
  reduced_yogurt: {name: 'Reduced yogurt', base: 2, tags: ['Food', 'Dairy', 'Clearance'], rule: {t: 'beside', tag: 'Clearance', n: 3}, text: '+3 beside Clearance'},
  crackers:       {name: 'Crackers', base: 2, tags: ['Food', 'Bakery'], rule: {t: 'besideId', id: 'soup', n: 3}, text: '+3 beside Soup'},
  dented_can:     {name: 'Dented can', base: 2, tags: ['Food', 'Clearance'], rule: {t: 'perEarlier', tag: 'Clearance', n: 2}, text: '+2 per earlier Clearance'},
  day_old_buns:   {name: 'Day-old buns', base: 2, tags: ['Food', 'Bakery', 'Clearance'], rule: {t: 'after', tag: 'Clearance', n: 3}, text: '+3 just after Clearance'},
  scissors:       {name: 'Scissors', base: 1, tags: ['Household'], rule: {t: 'perEarlierCoupon', n: 2}, text: '+2 per earlier coupon'},
  flickering_bulb:{name: 'Flickering bulb', base: 1, tags: ['Household', 'Clearance'], rule: {t: 'armFlat', tag: 'Clearance', n: 3}, text: '+3 to the next Clearance'},
  batteries:      {name: 'Batteries', base: 1, tags: ['Household'], rule: {t: 'last', n: 4}, text: '+4 in the last slot'},

  // ---- capsule unlocks the page uses (today's rules; `next` is the #128 candidate)
  fruit_salad:    {name: 'Fruit salad', base: 2, tags: ['Food', 'Produce'], unlock: 'fruit_and_veg',
    rule: {t: 'perEarlier', tag: 'Produce', n: 2}, text: '+2 per earlier Produce',
    next: {rule: {t: 'perDistinct', tag: 'Produce', n: 3}, text: '+3 per different Produce before it', verb: 'variety'}},
  strawberries:   {name: 'Strawberries', base: 2, tags: ['Food', 'Produce'], unlock: 'fruit_and_veg',
    rule: {t: 'beside', tag: 'Produce', n: 3}, text: '+3 beside Produce',
    next: {rule: {t: 'mixedChain', tag: 'Produce'}, text: '+ the price of a different Produce just before it', verb: 'chain into a new fruit'}},
  wonky_carrot:   {name: 'Wonky carrot', base: 2, tags: ['Food', 'Produce', 'Clearance'], unlock: 'fruit_and_veg',
    rule: {t: 'after', tag: 'Produce', n: 3}, text: '+3 just after Produce',
    next: {rule: {t: 'passThrough'}, text: 'Chains pass through it: the next Produce chains from the one before', verb: 'keep a chain alive'}},
  grapefruit:     {name: 'Grapefruit', base: 2, tags: ['Food', 'Produce', 'Breakfast'], unlock: 'fruit_and_veg', rule: {t: 'armFlat', tag: 'Produce', n: 3}, text: '+3 to the next Produce'},
  lemon:          {name: 'Lemon', base: 1, tags: ['Food', 'Produce'], unlock: 'fruit_and_veg', rule: {t: 'armMult', tag: 'Produce', f: 2}, text: '×2 next Produce'},
  baguette:       {name: 'Baguette', base: 2, tags: ['Food', 'Bakery'], unlock: 'bakery',
    rule: {t: 'perEarlier', tag: 'Bakery', n: 2}, text: '+2 per earlier Bakery',
    next: {rule: {t: 'batchEnd', tag: 'Bakery', n: 3}, text: '+3 per Bakery in the unbroken run just before it', verb: 'end a batch'}},
  croissant:      {name: 'Croissant', base: 2, tags: ['Food', 'Bakery', 'Breakfast'], unlock: 'bakery', rule: {t: 'beside', tag: 'Bakery', n: 2}, text: '+2 beside Bakery'},
  odd_socks:      {name: 'Odd socks', base: 1, tags: ['Household'], unlock: 'household',
    rule: {t: 'perEarlier', tag: 'Household', n: 2}, text: '+2 per earlier Household',
    next: {rule: {t: 'pair', tag: 'Household', n: 6}, text: '+6 with exactly one Household beside it (a pair, not a run)', verb: 'make a pair'}},
  chipped_mug:    {name: 'Chipped mug', base: 1, tags: ['Household', 'Clearance'], unlock: 'household', rule: {t: 'besideId', id: 'coffee', n: 3}, text: '+3 beside Coffee'},
  egg_timer:      {name: 'Egg timer', base: 1, tags: ['Household', 'Breakfast'], unlock: 'household', rule: {t: 'afterId', id: 'eggs', n: 4}, text: '+4 just after Eggs'},
  pick_n_mix:     {name: "Pick 'n' mix", base: 1, tags: ['Food', 'Snack'], unlock: 'snacks',
    rule: {t: 'perEarlier', tag: 'Snack', n: 2}, text: '+2 per earlier Snack',
    next: {rule: {t: 'spaced', tag: 'Snack', n: 3}, text: '+3 per Snack in the row with no Snack beside it (itself too)', verb: 'spread the Snacks'}},
  crisps:         {name: 'Crisps', base: 2, tags: ['Food', 'Snack'], unlock: 'snacks', rule: {t: 'besideId', id: 'bread', n: 3}, text: '+3 beside Bread'},
  breadsticks:    {name: 'Breadsticks', base: 2, tags: ['Food', 'Snack'], unlock: 'snacks', rule: {t: 'afterId', id: 'soup', n: 2}, text: '+2 just after Soup'},
  dusty_toffees:  {name: 'Dusty toffees', base: 1, tags: ['Food', 'Snack', 'Clearance'], unlock: 'snacks',
    rule: {t: 'perEarlier', tag: 'Clearance', n: 2}, text: '+2 per earlier Clearance',
    next: {rule: {t: 'salvage', n: 3, max: 3}, text: '+3 per earlier product whose rule paid nothing (up to 3)', verb: 'salvage misses'}},
};
Object.keys(CARDS).forEach(id => { CARDS[id].id = id; });

const FRESH = ['bread', 'banana', 'milk', 'eggs', 'coffee', 'soup', 'cheese', 'cereal', 'tea_bags', 'carrier_bag', 'frozen_peas',
  'butter', 'yogurt', 'reduced_yogurt', 'crackers', 'dented_can', 'day_old_buns', 'scissors', 'flickering_bulb', 'batteries'];
const EXPANDED = FRESH.concat(Object.keys(CARDS).filter(id => CARDS[id].unlock));
const REDESIGNED = ['fruit_salad', 'strawberries', 'wonky_carrot', 'baguette', 'odd_socks', 'pick_n_mix', 'dusty_toffees'];
// own conditions: a product with one of these whose own bonus came to 0 "paid nothing" (Dusty toffees' salvage)
const CONDITIONAL = new Set(['chain', 'beside', 'besideId', 'after', 'afterId', 'perEarlier', 'perEarlierCoupon', 'last',
  'perDistinct', 'mixedChain', 'batchEnd', 'spaced', 'pair']);

const has = (c, tag) => c.tags.includes(tag);
// which rule a card plays with: today's, or the candidate when `next` is on for it
function ruleOf(id, mode) {
  const c = CARDS[id];
  if (c.next && (mode === 'next' || (mode instanceof Set && mode.has(id)))) return {rule: c.next.rule, text: c.next.text};
  return {rule: c.rule, text: c.text};
}

// score(ids, mode): mode 'now' (today's rules), 'next' (every candidate on), or a Set of ids whose candidate is on
function score(ids, mode) {
  const n = ids.length, row = ids.map(id => CARDS[id]);
  const rules = ids.map(id => ruleOf(id, mode).rule);
  const prices = [], pays = [], fizzled = [], steps = [], owns = [];
  let effects = [];
  const prevThrough = i => {   // the product a chain reads: just before, or through one pass-through card
    let j = i - 1;
    if (j >= 0 && rules[j].t === 'passThrough') j--;
    return j;
  };
  for (let i = 0; i < n; i++) {
    const c = row[i], r = rules[i], st = [];
    let v = c.base, own = 0;
    const add = (amt, txt) => { if (!amt) return; v += amt; own += amt; st.push({amt, txt}); };
    switch (r.t) {
      case 'chain': { const j = prevThrough(i); if (j >= 0 && ids[j] === ids[i]) add(prices[j], 'chain'); break; }
      case 'mixedChain': { const j = prevThrough(i); if (j >= 0 && has(row[j], r.tag) && ids[j] !== ids[i]) add(prices[j], 'chain from ' + row[j].name); break; }
      case 'beside': if ([i - 1, i + 1].some(j => j >= 0 && j < n && has(row[j], r.tag))) add(r.n, 'beside ' + r.tag); break;
      case 'besideId': if ([i - 1, i + 1].some(j => j >= 0 && j < n && ids[j] === r.id)) add(r.n, 'beside ' + CARDS[r.id].name); break;
      case 'after': if (i > 0 && has(row[i - 1], r.tag)) add(r.n, 'after ' + r.tag); break;
      case 'afterId': if (i > 0 && ids[i - 1] === r.id) add(r.n, 'after ' + CARDS[r.id].name); break;
      case 'perEarlier': { let k = 0; for (let j = 0; j < i; j++) if (has(row[j], r.tag)) k++; add(r.n * k, k + ' earlier ' + r.tag); break; }
      case 'perDistinct': { const s = new Set(); for (let j = 0; j < i; j++) if (has(row[j], r.tag)) s.add(ids[j]); add(r.n * s.size, s.size + ' different ' + r.tag); break; }
      case 'batchEnd': { let k = 0; for (let j = i - 1; j >= 0 && has(row[j], r.tag); j--) k++; add(r.n * k, 'batch of ' + k); break; }
      case 'pair': { const k = [i - 1, i + 1].filter(j => j >= 0 && j < n && has(row[j], r.tag)).length; if (k === 1) add(r.n, 'a pair'); break; }
      case 'spaced': {
        let k = 0;
        for (let j = 0; j < n; j++) if (has(row[j], r.tag) && !(j > 0 && has(row[j - 1], r.tag)) && !(j < n - 1 && has(row[j + 1], r.tag))) k++;
        add(r.n * k, k + ' spread Snack' + (k === 1 ? '' : 's'));
        break;
      }
      case 'salvage': { let k = 0; for (let j = 0; j < i; j++) if (fizzled[j]) k++; k = Math.min(k, r.max); add(r.n * k, k + ' miss' + (k === 1 ? '' : 'es')); break; }
      case 'last': if (i === n - 1) add(r.n, 'last slot'); break;
      default: break;
    }
    // flat effects waiting for this product
    effects.forEach(e => { if (e.kind === 'flat' && e.left > 0 && has(c, e.tag)) { e.left--; v += e.n; st.push({amt: e.n, txt: 'from ' + e.from}); } });
    prices[i] = v;
    effects.forEach(e => { if (e.kind === 'mult' && e.left > 0 && has(c, e.tag)) { e.left--; v *= e.f; st.push({f: e.f, txt: 'from ' + e.from}); } });
    if (r.t === 'zeroBeside' && [i - 1, i + 1].some(j => j >= 0 && j < n && has(row[j], r.tag))) { v = 0; st.push({zero: true, txt: 'beside Frozen'}); }
    pays[i] = v;
    fizzled[i] = CONDITIONAL.has(r.t) && own === 0;
    owns[i] = own;
    if (r.t === 'armFlat') effects.push({kind: 'flat', tag: r.tag, n: r.n, left: 1, from: c.name});
    if (r.t === 'armMult') { effects = effects.filter(e => e.fromId !== ids[i]); effects.push({kind: 'mult', tag: r.tag, f: r.f, left: 1, from: c.name, fromId: ids[i]}); }
    steps.push(st);
  }
  return {pays, prices, fizzled, steps, owns, total: pays.reduce((a, b) => a + b, 0)};
}

// every ordering of a hand (Heap's algorithm), deduplicated for repeated products
function orderings(ids) {
  const a = ids.slice(), out = [], seen = new Set(), c = new Array(a.length).fill(0);
  const push = () => { const k = a.join(','); if (!seen.has(k)) { seen.add(k); out.push(a.slice()); } };
  push();
  let i = 0;
  while (i < a.length) {
    if (c[i] < i) { const j = i % 2 ? c[i] : 0; [a[j], a[i]] = [a[i], a[j]]; push(); c[i]++; i = 0; } else { c[i] = 0; i++; }
  }
  return out;
}
function best(ids, mode) {
  let top = -1, rows = [];
  orderings(ids).forEach(o => { const t = score(o, mode).total; if (t > top) { top = t; rows = [o]; } else if (t === top) rows.push(o); });
  return {total: top, rows};
}

// a small seeded RNG (mulberry32)
function rng(seed) { return () => { seed |= 0; seed = seed + 0x6D2B79F5 | 0; let t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }

// The ordering study: for `item`, `hands` hands of 6 (the item + 5 drawn from `pool` with replacement, products
// of the item's family `lean` times as likely). For each hand and each rule (today's, the candidate's), every
// ordering is scored: where the item sits in the best rows, what it pays there, and how much the best order
// beats the average order (the stake of ordering).
function study(item, opt) {
  opt = opt || {};
  const hands = opt.hands || 120, pool = opt.pool || FRESH, lean = opt.lean || 3, fam = opt.family;
  const R = rng(opt.seed || 128);
  const weights = pool.map(id => (fam && has(CARDS[id], fam) ? lean : 1));
  const wsum = weights.reduce((a, b) => a + b, 0);
  const draw = () => { let x = R() * wsum; for (let i = 0; i < pool.length; i++) { x -= weights[i]; if (x < 0) return pool[i]; } return pool[pool.length - 1]; };
  const res = {};
  ['now', 'next'].forEach(m => { res[m] = {slots: [0, 0, 0, 0, 0, 0], itemPay: 0, bestTotal: 0, stake: 0, fizzle: 0, wantsLast: 0, wantsElse: 0, anywhere: 0, own: 0}; });
  const mode = {now: 'now', next: new Set([item])};
  for (let h = 0; h < hands; h++) {
    const hand = [item]; for (let k = 0; k < 5; k++) hand.push(draw());
    const all = orderings(hand);
    ['now', 'next'].forEach(m => {
      let top = -1, rows = [], sum = 0;
      // the item's own bonus (its rule only, not what others give it): its best anywhere, and whether
      // every ordering that puts it last reaches that best ("just put it last" is the whole plan)
      let ownMax = -1, ownMin = 1e9, lastMin = 1e9;
      all.forEach(o => {
        const s = score(o, mode[m]); sum += s.total;
        const k = o.indexOf(item), ow = s.owns[k];
        ownMax = Math.max(ownMax, ow); ownMin = Math.min(ownMin, ow);
        if (k === 5) lastMin = Math.min(lastMin, ow);
        if (s.total > top) { top = s.total; rows = [{o, s}]; } else if (s.total === top) rows.push({o, s});
      });
      const r = res[m];
      if (ownMax === ownMin) r.anywhere++; else if (lastMin === ownMax) r.wantsLast++; else r.wantsElse++;
      r.own += ownMax;
      // the item's slots across the best rows, each hand weighing 1
      const slotSet = new Set(rows.map(x => x.o.indexOf(item)));
      slotSet.forEach(k => { r.slots[k] += 1 / slotSet.size; });
      r.itemPay += rows.reduce((a, x) => a + x.s.pays[x.o.indexOf(item)], 0) / rows.length;
      r.bestTotal += top;
      r.stake += top - sum / all.length;
      r.fizzle += rows.some(x => x.s.fizzled[x.o.indexOf(item)]) ? 1 : 0;
    });
  }
  ['now', 'next'].forEach(m => {
    const r = res[m];
    r.wantsLast /= hands; r.wantsElse /= hands; r.anywhere /= hands; r.own /= hands;
    r.slots = r.slots.map(v => v / hands); r.itemPay /= hands; r.bestTotal /= hands; r.stake /= hands; r.fizzle /= hands;
  });
  res.hands = hands;
  return res;
}

if (typeof module !== 'undefined') module.exports = {CARDS, FRESH, EXPANDED, REDESIGNED, score, orderings, best, study, ruleOf};
