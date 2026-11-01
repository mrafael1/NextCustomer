// Prints the page's ordering study as JSON (120 seeded hands per item, fresh and expanded pools).
'use strict';
const {study, REDESIGNED, FRESH, EXPANDED} = require('./scorer.js');
const FAMILY = {fruit_salad: 'Produce', strawberries: 'Produce', wonky_carrot: 'Produce', baguette: 'Bakery', odd_socks: 'Household', pick_n_mix: 'Snack', dusty_toffees: 'Clearance'};
const out = {};
[['fresh', FRESH], ['expanded', EXPANDED]].forEach(([k, pool]) => {
  out[k] = {};
  REDESIGNED.forEach(id => {
    const r = study(id, {family: FAMILY[id], hands: 120, pool: pool.filter(x => x !== id)});
    const trim = q => ({wantsLast: q.wantsLast, wantsElse: q.wantsElse, anywhere: q.anywhere, own: q.own, itemPay: q.itemPay, bestTotal: q.bestTotal, stake: q.stake, fizzle: q.fizzle});
    out[k][id] = {now: trim(r.now), next: trim(r.next)};
  });
});
process.stdout.write(JSON.stringify(out));
