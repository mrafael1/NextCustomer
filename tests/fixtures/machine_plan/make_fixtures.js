// #77: writes the page timelines tests/presentation/machine_plan_test.gd checks MachinePlan against.
// It runs the approved page's own timeline code, buildTimeline() and bonusTimeline() from
// docs/art/mockups/machine_77_src/flow/flow_template.html, with look F's plan() from
// flow/looks/look_f.js (the page's `?tl` output, without a browser), for fixed draws: the page's
// cursor demo is still in these numbers; the test takes it out at the wait points.
// Run from the repo root: node tests/fixtures/machine_plan/make_fixtures.js
'use strict';
const fs = require('fs');
const path = require('path');
const vm = require('vm');

const FLOW = path.join(__dirname, '../../../docs/art/mockups/machine_77_src/flow');
const page = fs.readFileSync(path.join(FLOW, 'flow_template.html'), 'utf8');
const look = fs.readFileSync(path.join(FLOW, 'looks/look_f.js'), 'utf8');

// the source of `function name(...) { ... }` in the page, by brace matching
function source(name) {
  const start = page.indexOf(`function ${name}(`);
  if (start < 0) throw new Error(`no ${name} in the page`);
  let depth = 0;
  for (let i = page.indexOf('{', start); i < page.length; i++) {
    if (page[i] === '{') depth++;
    else if (page[i] === '}' && --depth === 0) return page.slice(start, i + 1);
  }
  throw new Error(`unbalanced ${name}`);
}

const sandbox = { Math, Object, console };
sandbox.window = sandbox;
vm.createContext(sandbox);
vm.runInContext(look, sandbox);
vm.runInContext(`${source('buildTimeline')}\n${source('bonusTimeline')}`, sandbox);

// drawer: 'new' (a card added), 'up' (UPGRADES, `copies` targets), or '' (a register stamp)
const ticket = (drawer, copies) => ({ inf: drawer === 'up' ? { drawer, targets: new Array(copies).fill(0) } : drawer ? { drawer } : {} });
const tiers = list => list.map(tier => ({ tier }));

// name: [rm, tiers, drawer, copies, stamp day tiers or null, bonus {tiers, drawer, copies} or null]
const SCENARIOS = {
  ticket_new: [false, [0, 0, 1], 'new', 1, null, null],
  ticket_new_rm: [true, [0, 0, 1], 'new', 1, null, null],
  ticket_register: [false, [0, 1, 2], '', 1, null, null],
  ticket_register_rm: [true, [0, 1, 2], '', 1, null, null],
  ticket_shelf: [false, [0, 0, 1], 'up', 3, null, null],
  ticket_shelf_rm: [true, [0, 0, 1], 'up', 3, null, null],
  ticket_one: [false, [1], 'new', 1, null, null],
  ticket_two: [false, [0, 2], 'new', 1, null, null],
  stamp_day: [false, [0, 0, 1], 'new', 1, [0, 1, 1], null],
  stamp_day_rm: [true, [0, 0, 1], 'new', 1, [0, 1, 1], null],
  bonus_new: [false, [0, 0, 1], 'new', 1, null, { tiers: [0, 0, 1], drawer: 'new', copies: 1 }],
  bonus_new_rm: [true, [0, 0, 1], 'new', 1, null, { tiers: [0, 0, 1], drawer: 'new', copies: 1 }],
  bonus_shelf: [false, [0, 0, 1], 'new', 1, null, { tiers: [0, 1, 2], drawer: 'up', copies: 2 }],
  bonus_shelf_rm: [true, [0, 0, 1], 'new', 1, null, { tiers: [0, 1, 2], drawer: 'up', copies: 2 }],
  bonus_register: [false, [0, 0, 1], 'new', 1, null, { tiers: [0, 0, 1], drawer: '', copies: 1 }],
};

const out = {};
for (const [name, [rm, main, drawer, copies, sd, bonus]] of Object.entries(SCENARIOS)) {
  sandbox.CFG = { rm, speed: 1 };
  sandbox.LOOK = sandbox.LOOKS.f;
  sandbox.DRAW = tiers(main);
  sandbox.S = { pick: main.length - 1 };
  sandbox.TK = main.map(() => ticket(drawer, copies));
  sandbox.SD = sd ? tiers(sd) : null;
  sandbox.B = bonus ? { draw: tiers(bonus.tiers), pick: bonus.tiers.length - 1, tk: bonus.tiers.map(() => ticket(bonus.drawer, bonus.copies)) } : null;
  sandbox.TL = {};
  vm.runInContext('buildTimeline()', sandbox);
  const T = JSON.parse(JSON.stringify(sandbox.TL));
  const plan = sandbox.LOOKS.f.plan({ T: sandbox.TL, rm, prizes: sandbox.DRAW, stampDay: sandbox.SD });
  const entry = { rm, tiers: main, drawer, copies, stamp_day: sd, T, plan: JSON.parse(JSON.stringify(plan)) };
  if (bonus) {
    const BT = sandbox.B.T;
    entry.bonus = { tiers: bonus.tiers, drawer: bonus.drawer, copies: bonus.copies, T: JSON.parse(JSON.stringify(BT)),
      plan: JSON.parse(JSON.stringify(sandbox.LOOKS.f.plan({ T: BT, rm, prizes: sandbox.B.draw, stampDay: null }))) };
  }
  out[name] = entry;
}
const file = path.join(__dirname, 'page_timelines.json');
fs.writeFileSync(file, JSON.stringify(out, null, 1) + '\n');
console.log(`wrote ${Object.keys(out).length} timelines to ${path.relative(process.cwd(), file)}`);
