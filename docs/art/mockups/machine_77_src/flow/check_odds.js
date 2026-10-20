// #77 prep, rounds 2-3: checks that the flow page's odds cards are exact (round 3 adds the BONUS TICKET's states).
// The card numbers come from DRAW77.stats() (every possible draw, enumerated with its probability). This script runs
// the forward process DRAW77.simulate() (what the game would run) 100,000 times per state with a seeded RNG and
// compares every number the card prints: tier % per drop (and drop 1 / the other drops at REGULAR 3), each prize's %
// to be among the 3, "at least one RARE or better", "a LEGENDARY", the guarantee's hold rate and short draws.
// Usage: node check_odds.js [rolls=100000]. Writes check_odds_result.json (gen_flow.py prints its summary on the page).
'use strict';
const fs = require('fs');
const path = require('path');
const { create } = require('./draw77.js');

const N = parseInt(process.argv[2] || '100000', 10);
const data = JSON.parse(fs.readFileSync(path.join(__dirname, 'flow_data.json'), 'utf8'));
const D = create(data);

function mulberry(seed) { return () => { seed |= 0; seed = seed + 0x6D2B79F5 | 0; let t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }

const OWN_ORDER = ['extra_coupon_slot', 'coupon_engine', 'big_basket'];
const states = [];
const add = (name, chute, st) => [0, 1, 2, 3].forEach(lvl => states.push({ name: `${name} · REGULAR ${lvl}`, chute, st: Object.assign({ lvl, ownedIds: [], firstCoupons: false, stock: [], cart: [] }, st) }));
['fresh', 'pantry+bakery', 'cold_cases+snacks'].forEach(s => add(`NEW ITEMS · ${s}`, 'new', { stock: D.stockFor(s) }));
add('COUPONS · first visit', 'coupons', { firstCoupons: true });
add('COUPONS · later visit', 'coupons', {});
[0, 1, 2].forEach(o => add(`REGISTER · ${o} owned`, 'register', { ownedIds: OWN_ORDER.slice(0, o) }));
add('UPGRADES · cart after shift 3', 'upgrades', { cart: D.cartAt(3) });
add('UPGRADES · cart after shift 7', 'upgrades', { cart: D.cartAt(7) });
const odd = D.cartAt(7).map(c => c.id === 'coffee' ? { id: c.id, tier: 2 } : c.id === 'eggs' ? { id: c.id, tier: 1 } : c);
add('UPGRADES · all Coffee GOLDEN, all Eggs BIG', 'upgrades', { cart: odd });
const one = D.cartAt(7).map(c => c.id === 'banana' || c.id === 'eggs' ? { id: c.id, tier: 2 } : c.id === 'coffee' ? { id: c.id, tier: 2 } : c.id === 'milk' ? { id: c.id, tier: c.tier ? 2 : 1 } : c);
add('UPGRADES · only Milk can step, 2 BIG + 1 GOLDEN (short draws)', 'upgrades', { cart: one });

// round 3: the BONUS TICKET's states (a passed inspection at shift 3, 5 or 7 gives a second visit). The page's own
// rules: the run state at shift s as the page derives it (auto settings, STAMP DAY on), then D.afterPick for EVERY prize
// the first visit can give, then every chute the second visit can open. States already listed above are skipped.
const seen = new Set(states.map(S => [S.chute, S.st.lvl, S.st.ownedIds.join(','), !!S.st.firstCoupons, S.st.stock.join(','), S.st.cart.map(c => c.id + c.tier).join(',')].join('|')));
const CH = ['new', 'coupons', 'register', 'upgrades'], H = D.HISTORY, bonusStart = states.length;
[3, 5, 7].forEach(s => {
  let owned = 0; for (let k = 1; k < s; k++) { if (H[k] === 'register' && owned < 3) owned++; if ([2, 4, 6].includes(k) && owned < k / 2) owned++; }
  const levels = {}; CH.forEach(c => { let n = 0; for (let k = 1; k < s; k++) if (H[k] === c) n++; levels[c] = Math.min(3, n); });
  const base = { levels, ownedIds: OWN_ORDER.slice(0, owned), stock: D.stockFor('fresh'), cart: D.cartAt(s), firstCoupons: ![...Array(s - 1).keys()].some(i => H[i + 1] === 'coupons') };
  CH.forEach(c1 => {
    if (c1 === 'register' && owned >= 3) return;
    const st1 = Object.assign({}, base, { chute: c1, lvl: levels[c1] });
    const rises = st1.lvl < 3 && !(c1 === 'register' && owned >= 2); // shift 7 too: the bonus ticket is a later visit
    const prizes = Object.keys(D.stats(c1, st1).inDraw).map(k => { const [kind, id, tier] = k.split(':'); return { kind, id, tier: +tier }; });
    prizes.forEach(p => {
      const st2 = D.afterPick(st1, p, rises);
      CH.forEach(c2 => {
        if (c2 === 'register' && st2.full) return;
        const st = Object.assign({}, st2, { lvl: st2.levels[c2] });
        const key = [c2, st.lvl, st.ownedIds.join(','), !!st.firstCoupons, st.stock.join(','), st.cart.map(c => c.id + c.tier).join(',')].join('|');
        if (seen.has(key)) return; seen.add(key);
        states.push({ name: `BONUS s${s} ${c1}>${p.id}${['', '+', '++'][p.tier]} then ${c2} · REGULAR ${st.lvl}`, chute: c2, st });
      });
    });
  });
});
console.log(`bonus-ticket states added: ${states.length - bonusStart}`);

let worst = { dev: 0, where: '' }, total = 0, zmax = { z: 0, where: '' };
let bworst = { dev: 0, where: '' }, bz = { z: 0, where: '' };
const lines = [];
states.forEach((S, si) => {
  const X = D.stats(S.chute, S.st), tree = D.tree(S.chute, S.st);
  const sum = tree.reduce((a, l) => a + l.pr, 0);
  if (Math.abs(sum - 1) > 1e-9) throw new Error(`${S.name}: tree sums to ${sum}`);
  const rng = mulberry(1000 + si * 7919);
  const Y = { pR: 0, pL: 0, share: [0, 0, 0], first: [0, 0, 0], rest: [0, 0, 0], inDraw: {}, held: 0, short: 0 };
  for (let n = 0; n < N; n++) {
    const { seq, held } = D.simulate(S.chute, S.st, rng);
    if (seq.some(p => p.tier >= 1)) Y.pR++; if (seq.some(p => p.tier === 2)) Y.pL++; if (seq.length < 3) Y.short++; if (held) Y.held++;
    seq.forEach((p, i) => { Y.share[p.tier] += 1 / seq.length; if (i === 0) Y.first[p.tier]++; else Y.rest[p.tier] += 1 / (seq.length - 1); const k = D.pkey(p); Y.inDraw[k] = (Y.inDraw[k] || 0) + 1; });
  }
  const nz = a => { const tot = a[0] + a[1] + a[2]; if (tot > 0) for (let t = 0; t < 3; t++) a[t] = a[t] / tot * N; };
  nz(Y.share); nz(Y.first); nz(Y.rest);
  const pairs = [['RARE+', X.pR, Y.pR / N], ['LEGENDARY', X.pL, Y.pL / N], ['short', X.short, Y.short / N], ['guarantee held', X.held, Y.held / N]];
  [0, 1, 2].forEach(t => { pairs.push([`tier ${t} per drop`, X.share[t], Y.share[t] / N], [`tier ${t} drop 1`, X.first[t], Y.first[t] / N], [`tier ${t} drops 2-3`, X.rest[t], Y.rest[t] / N]); });
  new Set([...Object.keys(X.inDraw), ...Object.keys(Y.inDraw)]).forEach(k => pairs.push([k, X.inDraw[k] || 0, (Y.inDraw[k] || 0) / N]));
  let m = { dev: 0, what: '' };
  pairs.forEach(([what, a, b]) => { const d = Math.abs(a - b) * 100; if (d > m.dev) m = { dev: d, what };
    const sd = Math.sqrt(Math.max(a * (1 - a), 1e-12) / N), z = Math.abs(a - b) / sd; if (a > 0 && a < 1 && z > zmax.z) zmax = { z, where: `${S.name}, ${what}` };
    if (si >= bonusStart && a > 0 && a < 1 && z > bz.z) bz = { z, where: `${S.name}, ${what}` }; });
  total++;
  if (m.dev > worst.dev) worst = { dev: m.dev, where: `${S.name}, ${m.what}` };
  if (si >= bonusStart && m.dev > bworst.dev) bworst = { dev: m.dev, where: `${S.name}, ${m.what}` };
  lines.push(`${S.name.padEnd(58)} leaves ${String(tree.length).padStart(6)}  RARE+ ${(X.pR * 100).toFixed(2).padStart(6)}%  LEG ${(X.pL * 100).toFixed(2).padStart(6)}%  held ${(X.held * 100).toFixed(3).padStart(7)}%  max gap ${m.dev.toFixed(3)} pts (${m.what})`);
});
lines.forEach(l => console.log(l));
console.log(`\n${total} states x ${N} rolls: largest gap between the card and the rolls ${worst.dev.toFixed(3)} points (${worst.where})`);
console.log(`largest gap in standard errors (binomial, per number): ${zmax.z.toFixed(2)} (${zmax.where})`);
console.log(`bonus-ticket states only (${states.length - bonusStart}): largest gap ${bworst.dev.toFixed(3)} points (${bworst.where}); ${bz.z.toFixed(2)} standard errors (${bz.where})`);
fs.writeFileSync(path.join(__dirname, 'check_odds_result.json'), JSON.stringify({ date: new Date().toISOString().slice(0, 10), states: total, rolls: N, max_dev_points: +worst.dev.toFixed(3), max_dev_where: worst.where, max_z: +zmax.z.toFixed(2), max_z_where: zmax.where, bonus_states: states.length - bonusStart, bonus_max_dev_points: +bworst.dev.toFixed(3), bonus_max_dev_where: bworst.where, bonus_max_z: +bz.z.toFixed(2), lines }, null, 1) + '\n');
