// #77: writes the exact-odds reference tables for tests/core/machine_odds_test.gd from the approved
// draw process, docs/art/mockups/machine_77_src/flow/draw77.js (DRAW77.stats: every possible draw
// enumerated with its probability). The GDScript MachineOdds must match them to 1e-9, with the two
// build extensions off (REGISTER's "one fits your cart" and the first NEW ITEMS draw's new arrival:
// draw77 has neither). Run from the repo root: node tests/fixtures/machine_odds/make_fixtures.js
'use strict';
const fs = require('fs');
const path = require('path');
const { create } = require('../../../docs/art/mockups/machine_77_src/flow/draw77.js');

const TIERS = ['common', 'rare', 'legendary'];

// NEW ITEMS: small stocks (product id, rarity, generally useful). Each exercises the guarantee swap.
const NEW_STOCKS = {
  'GU in every tier': [
    ['banana', 0, true], ['bread', 0, true], ['coffee', 0, false], ['soup', 0, false],
    ['milk', 1, true], ['tea_bags', 1, false], ['lemon', 2, false],
  ],
  'GU only Rare and Legendary': [
    ['coffee', 0, false], ['soup', 0, false], ['cheese', 0, false],
    ['milk', 1, true], ['tea_bags', 1, false], ['lemon', 2, false], ['carrier_bag', 2, true],
  ],
  'no Legendary, two Rare': [
    ['banana', 0, true], ['coffee', 0, false], ['soup', 0, false], ['eggs', 1, false], ['milk', 1, true],
  ],
};
// REGISTER: owned upgrades (the last leaves 2 types: short draws).
const REGISTER_OWNED = {
  'none owned': [],
  'Extra coupon slot owned': ['extra_coupon_slot'],
  'two owned': ['extra_coupon_slot', 'coupon_engine'],
  'two types left': ['coupon_engine', 'category_engine', 'extra_redraw', 'extra_coupon_slot'],
};
// UPGRADES: carts as [id, tier] (tier 0 plain, 1 BIG, 2 GOLDEN).
const STARTER = ['banana', 'banana', 'banana', 'bread', 'bread', 'milk', 'milk', 'eggs', 'eggs', 'coffee', 'coffee', 'soup', 'final_markdown'];
const UPGRADE_CARTS = {
  'starter cart': STARTER.map(id => [id, 0]),
  'Milk BIG + plain, Eggs GOLDEN + BIG, one Coffee': [['milk', 1], ['milk', 0], ['eggs', 2], ['eggs', 1], ['coffee', 0], ['bread', 0]],
  'only Milk can step, no shelf': [['milk', 1], ['milk', 2], ['banana', 2], ['coffee', 2], ['bread', 0]],
};

function stockData(stock) {
  const tiers = { common: [], rare: [], legendary: [] };
  stock.forEach(([id, t]) => tiers[TIERS[t]].push(id));
  return { rarity: { tiers, generally_useful: stock.filter(s => s[2]).map(s => s[0]) }, aisles: {} };
}

function expected(D, chute, st) {
  const X = D.stats(chute, st);
  const sum = D.tree(chute, st).reduce((a, l) => a + l.pr, 0);
  if (Math.abs(sum - 1) > 1e-12) throw new Error(`tree sums to ${sum}`);
  return { share: X.share, first: X.first, rest: X.rest, p_rare_plus: X.pR, p_legendary: X.pL,
    p_short: X.short, p_held: X.held, guarded: X.guarded, in_draw: X.inDraw };
}

function write(file, about, odds, states) {
  const out = { about, generated_by: 'tests/fixtures/machine_odds/make_fixtures.js', odds, states };
  fs.writeFileSync(path.join(__dirname, file), JSON.stringify(out, null, 1) + '\n');
  console.log(`${file}: ${states.length} states`);
}

const blank = { ownedIds: [], firstCoupons: false, stock: [], cart: [] };
const levels = [0, 1, 2, 3];

// NEW ITEMS
{
  const states = [];
  Object.entries(NEW_STOCKS).forEach(([name, stock]) => {
    const D = create(stockData(stock));
    levels.forEach(lvl => {
      const st = Object.assign({}, blank, { lvl, stock: stock.map(s => s[0]) });
      states.push({ name: `${name} · REGULAR ${lvl}`, chute: 'new_items', level: lvl,
        input: { stock: stock.map(([id, rarity, gu]) => ({ id, rarity, gu })) }, expected: expected(D, 'new', st) });
    });
  });
  write('new_items.json', 'NEW ITEMS on small stocks, guarantee swap on', create(stockData([])).ODDS, states);
}
// COUPONS (draw77's own coupon tiers and first_offer_pool)
{
  const D = create(stockData([]));
  const coupons = Object.keys(D.COUP_TIER).map(id => ({ id, rarity: D.COUP_TIER[id], first_offer: D.FOP.includes(id) }));
  const states = [];
  [true, false].forEach(first => levels.forEach(lvl => {
    const st = Object.assign({}, blank, { lvl, firstCoupons: first });
    states.push({ name: `COUPONS ${first ? 'first' : 'later'} draw · REGULAR ${lvl}`, chute: 'coupons', level: lvl,
      input: { coupons, first }, expected: expected(D, 'coupons', st) });
  }));
  write('coupons.json', 'COUPONS, the first draw with the first_offer_pool guarantee and a later draw', D.ODDS, states);
}
// REGISTER (draw77's own register tiers and types; nothing fits, so the build's fits extension is off)
{
  const D = create(stockData([]));
  const upgrades = Object.keys(D.REG_TIER).map(id => ({ id, rarity: D.REG_TIER[id], type: D.REG_TYPE[id] }));
  const states = [];
  Object.entries(REGISTER_OWNED).forEach(([name, owned]) => levels.forEach(lvl => {
    const st = Object.assign({}, blank, { lvl, ownedIds: owned });
    states.push({ name: `REGISTER ${name} · REGULAR ${lvl}`, chute: 'register', level: lvl,
      input: { upgrades, owned }, expected: expected(D, 'register', st) });
  }));
  write('register.json', 'REGISTER, owned removed and 3 different types', D.ODDS, states);
}
// UPGRADES (the live chains: Banana, Milk, Eggs, Coffee)
{
  const D = create(stockData([]));
  const states = [];
  Object.entries(UPGRADE_CARTS).forEach(([name, cart]) => levels.forEach(lvl => {
    const st = Object.assign({}, blank, { lvl, cart: cart.map(([id, tier]) => ({ id, tier })) });
    states.push({ name: `UPGRADES ${name} · REGULAR ${lvl}`, chute: 'upgrades', level: lvl,
      input: { cart: cart.map(([id, tier]) => ({ id, tier })) }, expected: expected(D, 'upgrades', st) });
  }));
  write('upgrades.json', 'UPGRADES on carts of the live chains, SHELF UPGRADE needs 2 copies', D.ODDS, states);
}
