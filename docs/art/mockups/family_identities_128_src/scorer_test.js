// node docs/art/mockups/family_identities_128_src/scorer_test.js: checks the mock-up scorer on hand-scored rows,
// then prints the ordering study the page shows (same seeds), so the page's numbers can be read without a browser.
'use strict';
const assert = require('assert');
const {score, study, CARDS, REDESIGNED, FRESH, EXPANDED} = require('./scorer.js');
const S = (ids, mode) => score(ids, mode || 'now');

// today's rules
assert.deepStrictEqual(S(['banana', 'banana', 'banana', 'banana']).pays, [2, 4, 6, 8]);            // the Banana chain
assert.deepStrictEqual(S(['coffee', 'milk']).pays, [2, 4 + 1 + 3]);                                 // Milk counts Coffee, Coffee's +3 lands
assert.deepStrictEqual(S(['tea_bags', 'milk']).pays, [1, (4 + 1) * 4]);                              // Tea bags ×4 the next Breakfast
assert.deepStrictEqual(S(['eggs', 'bread', 'cheese']).pays, [1, 10, 7]);                            // Eggs ×2 Bread, Cheese after Bread
assert.deepStrictEqual(S(['soup', 'frozen_peas']).pays, [0, 3]);                                     // Soup pays 0 beside Frozen
assert.deepStrictEqual(S(['banana', 'strawberries', 'fruit_salad']).pays, [2, 5, 2 + 4]);           // old: beside, per earlier Produce
// candidates
const N = 'next';
assert.deepStrictEqual(S(['banana', 'banana', 'fruit_salad'], N).pays, [2, 4, 2 + 3]);              // variety: Bananas count once
assert.deepStrictEqual(S(['banana', 'frozen_peas', 'fruit_salad'], N).pays, [2, 3, 2 + 6]);
assert.deepStrictEqual(S(['banana', 'banana', 'strawberries'], N).pays, [2, 4, 2 + 4]);             // chain into a new fruit
assert.deepStrictEqual(S(['banana', 'wonky_carrot', 'banana'], N).pays, [2, 2, 4]);                 // chains pass through the carrot
assert.deepStrictEqual(S(['bread', 'crackers', 'baguette'], N).pays, [5, 2, 2 + 6]);               // a batch of 2
assert.deepStrictEqual(S(['bread', 'milk', 'baguette'], N).pays, [5, 5, 2]);                       // the batch was broken
assert.deepStrictEqual(S(['batteries', 'odd_socks', 'milk'], N).pays, [1, 7, 4]);                  // a pair
assert.deepStrictEqual(S(['batteries', 'odd_socks', 'scissors'], N).pays, [1, 1, 1]);              // a run of three is no pair
assert.deepStrictEqual(S(['pick_n_mix', 'milk', 'crisps'], N).pays, [1 + 6, 4, 2]);                 // two spread Snacks
assert.deepStrictEqual(S(['scissors', 'cereal', 'dusty_toffees'], N).pays, [1, 2, 1 + 6]);          // two misses salvaged
assert.strictEqual(S(['scissors', 'cereal', 'dented_can', 'batteries', 'dusty_toffees'], N).pays[4], 1 + 9);   // capped at 3
console.log('scorer: all rows match');

const FAMILY = {fruit_salad: 'Produce', strawberries: 'Produce', wonky_carrot: 'Produce', baguette: 'Bakery', odd_socks: 'Household', pick_n_mix: 'Snack', dusty_toffees: 'Clearance'};
const pct = a => a.map(v => String(Math.round(v * 100)).padStart(3)).join(' ');
const P = v => String(Math.round(v * 100)).padStart(3) + '%';
[['fresh', FRESH], ['expanded', EXPANDED]].forEach(([label, pool]) => {
  console.log('\n' + label + ' pool: bonus: last is enough / needs a plan / never varies   best bonus   item pay   best row   stake   misses');
  REDESIGNED.forEach(id => {
    const r = study(id, {family: FAMILY[id], hands: +(process.argv[2] || 60), pool: pool.filter(x => x !== id)});
    ['now', 'next'].forEach(m => {
      const q = r[m];
      console.log((m === 'now' ? CARDS[id].name : '').padEnd(14), m.padEnd(4), P(q.wantsLast), P(q.wantsElse), P(q.anywhere), '   ', q.own.toFixed(1).padStart(5), '   ', q.itemPay.toFixed(1).padStart(5), '  ', q.bestTotal.toFixed(1).padStart(5), q.stake.toFixed(1).padStart(6), P(q.fizzle));
    });
  });
});
