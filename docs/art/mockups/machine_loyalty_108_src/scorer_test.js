// node scorer_test.js: prints every example row, scored, and each perk's delta per row
const {ROWS108, PERKS, score108, delta108, QUOTA5} = require('./scorer.js');
for (const [k, r] of Object.entries(ROWS108)) {
  const s = score108(r.ids, []);
  console.log(k, r.name, 'total', s.total, s.slots.map(x => x.name + ' ' + x.pay).join(' | '));
}
const show = (rk, pk) => { const s = score108(ROWS108[rk].ids, [pk]); console.log(' ', pk, rk, s.total, s.slots.map(x => x.name + ' ' + x.pay + '[' + x.steps.map(t => t.k === 'mult' ? '×' + t.f : (t.k === 'wasted' ? 'W' : '+' + t.amt) + (t.perk ? '*' : '')).join(' ') + ']').join(' | '), s.extra.map(e => e.txt + ' ' + e.amt).join(','), s.wasted.map(w => 'WASTED ' + w.txt).join(',')); };
console.log('perk  ' + Object.keys(ROWS108).join('   '));
for (const pk of Object.keys(PERKS)) console.log(pk.padEnd(5), Object.keys(ROWS108).map(rk => String(delta108(rk, pk)).padStart(4)).join(' '));
for (const a of process.argv.slice(2)) { const [rk, pk] = a.split(':'); show(rk, pk); }
