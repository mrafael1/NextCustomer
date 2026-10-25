// #108 mock-up scorer: a small copy of the game's scoring order (PROTOTYPE_PLAN section 3.2) for the cards in the
// example rows only, plus every loyalty perk on the page. Card numbers are NC-rules' data/cards (v0.57). Not the
// game's code: a check of the hand-scored rows, so the page and its stills agree. node scorer_test.js runs it.
//
// Order per card (core/scoring.gd _scan): base, + its own flat bonus, + effects waiting for it (Coffee's +3...),
// + perk flat bonuses, = the price a Banana chain reads; x effect multipliers (Eggs, Lemon...), Repeat's copy,
// x perk multipliers = the payout. Then its own effects arm. Coupons have base 0 and take no effects aimed at products.
// opt.payoutOnly (Q1 B): "perks change the payout, not the price": the price is set before the perk flat bonuses
// (one line in _scan), so a chain never carries a perk's bonus to its next link.
// Families (one definition, data/families/family_palette.tres): the 8 aisle families below. Food is quiet: no perk
// names it and no perk counts it. Family perks read raw tags and raw adjacency here; the game would read
// state.has_tag and products_before, so Breakfast sticker, Clearance tag, Bundle, 2 for 1 and Shelf swap feed them.

const C108 = {
  banana:          {name:'Banana', base:2, tags:['Food','Produce'], rule:{t:'chain', f:1}, eff:'+ the price of the Banana before it'},
  strawberries:    {name:'Strawberries', base:2, tags:['Food','Produce'], rule:{t:'beside', tag:'Produce', n:3}, eff:'+3 beside {Produce}'},
  lemon:           {name:'Lemon', base:1, tags:['Food','Produce'], rule:{t:'armMult', tag:'Produce', f:2, ch:1}, eff:'×2 next {Produce}'},
  fruit_salad:     {name:'Fruit salad', base:2, tags:['Food','Produce'], rule:{t:'perEarlier', tag:'Produce', n:2}, eff:'+2 per earlier {Produce}'},
  milk:            {name:'Milk', base:4, tags:['Food','Breakfast','Dairy'], rule:{t:'perEarlier', tag:'Breakfast', n:1}, eff:'+1 per earlier {Breakfast}'},
  coffee:          {name:'Coffee', base:2, tags:['Breakfast'], rule:{t:'armFlat', tag:'Breakfast', n:3, ch:1}, eff:'+3 next {Breakfast}'},
  tea_bags:        {name:'Tea bags', base:1, tags:['Breakfast'], rule:{t:'armMult', tag:'Breakfast', f:4, ch:1}, eff:'×4 next {Breakfast}'},
  eggs:            {name:'Eggs', base:1, tags:['Food','Breakfast'], rule:{t:'armMult', tag:'Food', f:2, ch:1}, eff:'×2 next {Food}'},
  bread:           {name:'Bread', base:5, tags:['Food','Breakfast','Bakery'], rule:{t:'none'}, eff:'No rule'},
  cheese:          {name:'Cheese', base:3, tags:['Food','Dairy'], rule:{t:'afterId', id:'bread', n:4}, eff:'+4 after Bread'},
  flickering_bulb: {name:'Flickering bulb', base:1, tags:['Household','Clearance'], rule:{t:'armFlat', tag:'Clearance', n:3, ch:1}, eff:'+3 next {Clearance}'},
  dented_can:      {name:'Dented can', base:2, tags:['Food','Clearance'], rule:{t:'perEarlier', tag:'Clearance', n:2}, eff:'+2 per earlier {Clearance}'},
  reduced_yogurt:  {name:'Reduced yogurt', base:2, tags:['Food','Dairy','Clearance'], rule:{t:'beside', tag:'Clearance', n:3}, eff:'+3 beside {Clearance}'},
  squashed_cake:   {name:'Squashed cake', base:2, tags:['Food','Bakery','Clearance'], rule:{t:'armMult', tag:'Clearance', f:2, ch:1}, eff:'×2 next {Clearance}'},
  day_old_buns:    {name:'Day-old buns', base:2, tags:['Food','Bakery','Clearance'], rule:{t:'after', tag:'Clearance', n:3}, eff:'+3 after {Clearance}'},
  scissors:        {name:'Scissors', base:1, tags:['Household'], rule:{t:'perEarlierCoupon', n:2}, eff:'+2 per earlier {Coupon}'},
  opening_deal:    {name:'Opening deal', base:0, tags:[], coupon:true, rule:{t:'opening', f:5}, eff:'1st slot: next ×5'},
  repeat:          {name:'Repeat', base:0, tags:[], coupon:true, rule:{t:'repeat'}, eff:'Copy prior payout'},
  final_markdown:  {name:'Final markdown', base:0, tags:[], coupon:true, rule:{t:'last', n:4}, eff:'+4 in last slot'},
  banana_golden:   {name:'Golden Banana', base:4, tags:['Food','Produce'], prod:'banana', rule:{t:'chain', f:2}, eff:'+ the price of the Banana before it, twice'},
};

const ROWS108 = {
  R1: {name:'Produce + Banana chain', ids:['lemon','banana','banana','banana','strawberries','fruit_salad','milk']},
  R2: {name:'Breakfast', ids:['coffee','milk','tea_bags','milk','eggs','bread','cheese']},
  R3: {name:'Coupons', ids:['opening_deal','milk','repeat','banana','banana','scissors','final_markdown']},
  R4: {name:'Clearance', ids:['flickering_bulb','dented_can','reduced_yogurt','squashed_cake','dented_can','day_old_buns','final_markdown']},
  R5: {name:'Six Bananas', ids:['banana','banana','banana','banana','banana','banana']},
};
// a reference row for the ceiling table only (not in the row picker): what the item tiers allow today
const REF108 = {G6: {name:'Six Golden Bananas', ids:['banana_golden','banana_golden','banana_golden','banana_golden','banana_golden','banana_golden']}};
const QUOTA5 = 73, QUOTA8 = 120;   // shift 5's and shift 8's quotas (data/balance/balance.tres)

const has = (c, tag) => c.tags.includes(tag);
const FAMILIES = ['Bakery','Produce','Dairy','Frozen','Snack','Household','Breakfast','Clearance'];
const famsOf = c => c.tags.filter(t => FAMILIES.includes(t));
const NON_FOOD = FAMILIES;
const sameProduct = (a, b) => (C108[a].prod || a) === (C108[b].prod || b);

// ---------- the perks: hooks flat(S, i, v), mult(S, i, v), mod(rule, card), post(S), rowWasted(S) ----------
function regulars(fam, n) {
  return {flat:(S, i) => {
    if (fam === 'Coupon') return S.isC(i) ? n * S.countBefore(i, j => S.isC(j)) : 0;
    return S.isP(i) && has(S.row[i], fam) ? n * S.countBefore(i, j => S.isP(j) && has(S.row[j], fam)) : 0;
  }, rowWasted:S => (fam === 'Coupon' ? S.count(j => S.isC(j)) : S.count(j => S.isP(j) && has(S.row[j], fam))) < 2 ? `fewer than two ${fam}` : ''};
}
function aisleRun(fam, len, f) {
  const inFam = (S, j) => S.isP(j) && has(S.row[j], fam);
  return {mult:(S, i) => {
    if (!inFam(S, i) || inFam(S, i + 1)) return 1;
    let k = 0; for (let j = i; inFam(S, j); j--) k++;
    return k >= len ? f : 1;
  }, rowWasted:S => {
    for (let i = 0; i < S.n; i++) { let k = 0; for (let j = i; inFam(S, j); j--) k++; if (k >= len) return ''; }
    return `no run of ${len} ${fam}`;
  }};
}
// Mixed basket (reworked): +n on each product that brings a family no earlier product had (Food is quiet)
function mixedBasket(n) {
  return {flat:(S, i) => {
    if (!S.isP(i)) return 0;
    const seen = new Set(); for (let j = 0; j < i; j++) if (S.isP(j)) famsOf(S.row[j]).forEach(t => seen.add(t));
    return famsOf(S.row[i]).some(t => !seen.has(t)) ? n : 0;
  }};
}
function distinctTags(S) { const t = new Set(); S.row.forEach((c, j) => { if (S.isP(j)) c.tags.forEach(x => t.add(x)); }); return t.size; }
const categoryEngine = {flat:(S, i) => i === S.lastP ? 3 * distinctTags(S) : 0};

const PERKS = {
  // today (NC-rules data/upgrades, v0.57)
  T_ER: {name:'Extra redraw', tier:'C', fam:null, code:'ExR', eff:'+1 redraw each shift', icon:'icons/redraw_arrow.png'},
  T_BB: {name:'Big basket', tier:'C', fam:null, code:'BiB', eff:'+1 slot', icon:'icons/plus_slot.png'},
  T_CO: {name:'Coupon engine', tier:'R', fam:'Coupon', code:'CoE', eff:'The first {Coupon} pays ×2', icon:'icons/perk_coupon_engine.png',
    mult:(S, i) => i === S.firstC ? 2 : 1, wasted:'the first coupon paid nothing', rowWasted:S => S.firstC < 0 ? 'no coupon' : ''},
  T_CA: Object.assign({name:'Category engine', tier:'R', fam:'Mixed', code:'CaE', eff:'+3 per different tag, on the last product', icon:'icons/combo_diamond.png'}, categoryEngine),
  T_SL: {name:'Slot engine', tier:'L', fam:null, code:'SlE', eff:'Slot 6 pays ×2', icon:'icons/perk_slot_engine.png',
    mult:(S, i) => i === 5 ? 2 : 1, wasted:'slot 6 paid nothing', rowWasted:S => S.n < 6 ? 'fewer than 6 cards' : ''},
  T_RB: {name:'Rule bender', tier:'-', fam:'Coupon', code:'RuB', eff:'{Coupon} don\'t break adjacency', out:true},

  // A · family loyalty: two rule shapes for every family, family jackpots, and three family-neutral perks
  A_RP: Object.assign({short:'Regulars', name:'Produce regulars', tier:'C', fam:'Produce', code:'PRD', eff:'Each {Produce} +1 per {Produce} before it', lv:['+1', '+2', '+3']}, regulars('Produce', 1)),
  A_RB: Object.assign({short:'Regulars', name:'Breakfast regulars', tier:'C', fam:'Breakfast', code:'BRK', eff:'Each {Breakfast} +1 per {Breakfast} before it', lv:['+1', '+2', '+3']}, regulars('Breakfast', 1)),
  A_RC: Object.assign({short:'Regulars', name:'Clearance regulars', tier:'C', fam:'Clearance', code:'CLR', eff:'Each {Clearance} +1 per {Clearance} before it', lv:['+1', '+2', '+3']}, regulars('Clearance', 1)),
  A_NP: Object.assign({short:'Aisle run', name:'Produce aisle run', tier:'R', fam:'Produce', code:'PRD', eff:'3+ {Produce} in a row: the last ×3', lv:['×3', '×4', '×5']}, aisleRun('Produce', 3, 3)),
  A_NB: Object.assign({short:'Aisle run', name:'Breakfast aisle run', tier:'R', fam:'Breakfast', code:'BRK', eff:'3+ {Breakfast} in a row: the last ×3', lv:['×3', '×4', '×5']}, aisleRun('Breakfast', 3, 3)),
  A_NC: Object.assign({short:'Aisle run', name:'Clearance aisle run', tier:'R', fam:'Clearance', code:'CLR', eff:'3+ {Clearance} in a row: the last ×3', lv:['×3', '×4', '×5']}, aisleRun('Clearance', 3, 3)),
  A_MX: Object.assign({short:'Mixed basket', name:'Mixed basket', tier:'R', fam:'Mixed', code:'MIX', eff:'Each product that brings a new family to the row +3', lv:['+3', '+4', '+5']}, mixedBasket(3)),
  A_BS: {name:'Banana stand', tier:'L', fam:'Produce', code:'BnS', item:'banana', eff:'Every {Produce} chains like a Banana: + the price of the {Produce} before it',
    chainTag:'Produce', rowWasted:S => S.ids.some((id, j) => S.isP(j) && S.isP(j + 1) && has(S.row[j], 'Produce') && has(S.row[j + 1], 'Produce')) ? '' : 'no two Produce side by side'},
  A_FS: {name:'Fire sale', tier:'L', fam:'Clearance', code:'FiS', item:'squashed_cake', eff:'Squashed cake\'s ×2 reaches every later {Clearance}',
    mod:(r, c, id) => id === 'squashed_cake' ? Object.assign({}, r, {ch:99}) : r, rowWasted:S => S.ids.includes('squashed_cake') ? '' : 'no Squashed cake'},

  // B · position and sequence: the five engines reworked so each one fires
  B_RC: {name:'Rain check', tier:'C', fam:null, code:'RnC', eff:'+1 redraw. Each redraw left pays +4 on the last product',
    flat:(S, i) => i === S.lastP ? 4 * S.redrawsLeft : 0, rowWasted:S => S.redrawsLeft ? '' : 'no redraw left'},
  B_BB: {name:'Big basket', tier:'C', fam:null, code:'BiB', eff:'+1 slot. The last product +1 per card before it',
    flat:(S, i) => i === S.lastP ? i : 0},
  B_BE: {name:'Bookends', tier:'C', fam:null, code:'BkE', eff:'First and last product share a family: +4 each',
    flat:(S, i) => (i === S.firstP || i === S.lastP) && S.bookends() ? 4 : 0, rowWasted:S => S.bookends() ? '' : 'first and last share no family'},
  B_PA: {name:'Pairs', tier:'R', fam:null, code:'PaI', eff:'A product beside a copy of itself ×2',
    mult:(S, i) => S.isP(i) && ((S.isP(i - 1) && S.ids[i - 1] === S.ids[i]) || (S.isP(i + 1) && S.ids[i + 1] === S.ids[i])) ? 2 : 1,
    rowWasted:S => S.ids.some((id, j) => S.isP(j) && S.isP(j + 1) && S.ids[j + 1] === id) ? '' : 'no copies side by side'},
  B_CO: {name:'Coupon engine', tier:'R', fam:'Coupon', code:'CoE', eff:'The product right after each {Coupon} ×2',
    mult:(S, i) => S.isP(i) && S.isC(i - 1) ? 2 : 1, rowWasted:S => S.ids.some((id, j) => S.isC(j) && S.isP(j + 1)) ? '' : 'no product after a coupon'},
  B_SL: {name:'Slot engine', tier:'R', fam:null, code:'SlE', eff:'Slot 6 pays ×2',
    mult:(S, i) => i === 5 ? 2 : 1, wasted:'slot 6 paid nothing', rowWasted:S => S.n < 6 ? 'fewer than 6 cards' : ''},
  B_EN: {name:'Encore', tier:'L', fam:null, code:'EnC', eff:'Your best payout pays again at the end',
    post:S => { let b = 0; S.pays.forEach((p, j) => { if (p > S.pays[b]) b = j; }); return [{slot:S.n - 1, amt:S.pays[b], txt:'Encore: ' + S.row[b].name}]; }},

  // C · build-around jackpots: each one bends one product's rule (the Golden Banana's spirit)
  C_MR: {name:'Milk round', tier:'C', fam:'Breakfast', code:'MkR', eff:'Milk counts every {Breakfast} in the row, after it too', item:'milk',
    mod:(r, c, id) => id === 'milk' ? Object.assign({}, r, {t:'perAll'}) : r},
  C_FR: {name:'Free range', tier:'C', fam:'Food', code:'FrR', eff:'Eggs\' ×2 reaches the next 3 {Food}', item:'eggs',
    mod:(r, c, id) => id === 'eggs' ? Object.assign({}, r, {ch:3}) : r},
  C_LC: {name:'Last chance', tier:'C', fam:'Clearance', code:'LsC', eff:'Final markdown +2 per {Clearance} in the row', item:'final_markdown',
    flat:(S, i) => S.ids[i] === 'final_markdown' ? 2 * S.count(j => S.isP(j) && has(S.row[j], 'Clearance')) : 0,
    rowWasted:S => S.ids.includes('final_markdown') ? '' : 'no Final markdown'},
  C_BD: {name:'Bulk deal', tier:'R', fam:null, code:'BuD', eff:'Each product +3 per copy of it before it',
    flat:(S, i) => S.isP(i) ? 3 * S.countBefore(i, j => S.isP(j) && S.ids[j] === S.ids[i]) : 0},
  C_BC: {name:'Breakfast club', tier:'R', fam:'Breakfast', code:'BrC', eff:'Coffee\'s +3 goes to every later {Breakfast}', item:'coffee',
    mod:(r, c, id) => id === 'coffee' ? Object.assign({}, r, {ch:99}) : r},
  C_LS: {name:'Lemon squeezer', tier:'L', fam:'Produce', code:'LmS', eff:'Lemon\'s ×2 reaches every later {Produce}', item:'lemon',
    mod:(r, c, id) => id === 'lemon' ? Object.assign({}, r, {ch:99}) : r, rowWasted:S => S.ids.includes('lemon') ? '' : 'no Lemon'},
  C_BS: {name:'Banana stand', tier:'L', fam:'Produce', code:'BnS', eff:'Bananas chain across the whole row, each link twice', item:'banana',
    mod:(r, c, id) => id === 'banana' ? Object.assign({}, r, {f:2, across:true}) : r},
  C_CK: {name:'Coupon king', tier:'L', fam:'Coupon', code:'CpK', eff:'Every {Coupon} also pays the product before it',
    flat:(S, i) => { if (!S.isC(i)) return 0; const j = S.prevAnyP(i); return j < 0 ? 0 : S.pays[j]; }},
};
Object.keys(PERKS).forEach(k => { PERKS[k].id = k; });

// one level-up rule (Q4 B): each level steps the perk's number once, as printed on its ticket (lv), up to LV 3.
// Regulars +1/+2/+3, Aisle run x3/x4/x5, Mixed basket +3/+4/+5. Jackpots and neutral perks don't level.
function levelled(id, lv) {
  const key = id + '_L' + lv;
  if (PERKS[key]) return key;
  const pk = PERKS[id], fam = pk.fam;
  let rule = null;
  if (pk.short === 'Regulars') rule = regulars(fam, lv);
  else if (pk.short === 'Aisle run') rule = aisleRun(fam, 3, 2 + lv);
  else if (pk.short === 'Mixed basket') rule = mixedBasket(2 + lv);
  if (!rule) return id;
  PERKS[key] = Object.assign({}, pk, rule, {id:key, level:lv, eff:pk.eff.replace(pk.lv[0], pk.lv[lv - 1])});
  return key;
}

function score108(ids, perkIds, opt) {
  opt = opt || {};
  const perks = (perkIds || []).map(k => PERKS[k]);
  const row = ids.map(id => C108[id]), n = ids.length;
  const S = {ids, row, n, prices:[], pays:[], chained:[], effects:[], redrawsLeft:opt.redrawsLeft === undefined ? 1 : opt.redrawsLeft};
  S.isP = j => j >= 0 && j < n && !row[j].coupon;
  S.isC = j => j >= 0 && j < n && !!row[j].coupon;
  S.count = pred => ids.reduce((s, _, j) => s + (pred(j) ? 1 : 0), 0);
  S.countBefore = (i, pred) => { let s = 0; for (let j = 0; j < i; j++) if (pred(j)) s++; return s; };
  S.prevAnyP = i => { for (let j = i - 1; j >= 0; j--) if (S.isP(j)) return j; return -1; };
  S.firstP = ids.findIndex((_, j) => S.isP(j));
  S.lastP = (() => { for (let j = n - 1; j >= 0; j--) if (S.isP(j)) return j; return -1; })();
  S.firstC = ids.findIndex((_, j) => S.isC(j));
  S.bookends = () => S.firstP >= 0 && S.lastP > S.firstP && NON_FOOD.some(t => has(row[S.firstP], t) && has(row[S.lastP], t));
  const ruleOf = j => perks.reduce((r, p) => p.mod ? p.mod(r, row[j], ids[j]) : r, row[j].rule);
  const slots = [];
  for (let i = 0; i < n; i++) {
    const c = row[i], r = ruleOf(i), steps = [{k:'base', amt:c.base}];
    const itemPerk = (perks.find(pk => pk.item === ids[i] && pk.mod) || {}).id || null;
    let v = c.base;
    const add = (amt, txt, perk) => { if (!amt) return; v += amt; steps.push({k:'flat', amt, txt, perk}); };
    // own flat bonus
    if (!c.coupon) {
      const p = i - 1;
      // Banana stand: every Produce gains the chain, matching any Produce just before it (a Banana's own chain widens)
      const stand = perks.find(pk => pk.chainTag && has(c, pk.chainTag));
      if (r.t === 'chain' || stand) {
        const f = r.t === 'chain' ? r.f : 1;
        let prev = -1;
        if (r.across) { for (let j = i - 1; j >= 0; j--) if (S.isP(j) && sameProduct(ids[j], ids[i])) { prev = j; break; } }
        else if (S.isP(p) && (stand ? has(row[p], stand.chainTag) : sameProduct(ids[p], ids[i]))) prev = p;
        if (prev >= 0) {
          S.chained[i] = true;
          const own = r.t === 'chain' && sameProduct(ids[prev], ids[i]);
          add((S.chained[prev] ? S.prices[prev] : S.pays[prev]) * f, own ? (f > 1 ? 'Banana chain ×' + f : 'Banana chain') : 'Produce chain',
            own ? (r.f !== c.rule.f || r.across ? itemPerk : null) : stand.id);
        }
      }
      if (r.t === 'chain') {
        // done above
      } else if (r.t === 'beside') {
        if ([i - 1, i + 1].some(j => S.isP(j) && has(row[j], r.tag))) add(r.n, c.name, r.golden || null);
      } else if (r.t === 'after') {
        if (S.isP(p) && has(row[p], r.tag)) add(r.n, c.name, r.golden || null);
      } else if (r.t === 'afterId') {
        if (S.isP(p) && ids[p] === r.id) add(r.n, c.name, r.golden || null);
      } else if (r.t === 'perEarlier') {
        add(r.n * S.countBefore(i, j => S.isP(j) && has(row[j], r.tag)), c.name, r.golden || null);
      } else if (r.t === 'perAll') {
        add(r.n * S.countBefore(i, j => S.isP(j) && has(row[j], r.tag)), c.name);
        add(r.n * S.count(j => j > i && S.isP(j) && has(row[j], r.tag)), c.name + ' (later)', itemPerk);
      } else if (r.t === 'perEarlierCoupon') {
        add(r.n * S.countBefore(i, j => S.isC(j)), c.name);
      }
      // effects waiting for a product
      S.effects.forEach(e => { if (e.kind === 'flat' && e.left > 0 && (e.tag === '*' || has(c, e.tag))) { e.left--; e.used++; add(e.n, e.txt, e.gold || (e.used > e.orig ? e.perk : null)); } });
    } else if (r.t === 'last' && i === n - 1) add(r.n, c.name);
    // perk flat bonuses: in the price (today's order), or after it (opt.payoutOnly)
    if (opt.payoutOnly) S.prices[i] = v;
    perks.forEach(pk => { if (pk.flat) add(pk.flat(S, i, v), pk.short || pk.name, pk.id); });
    if (!opt.payoutOnly) S.prices[i] = v;
    // multipliers: effects, Repeat's copy, then perks
    if (!c.coupon) {
      S.effects.forEach(e => { if (e.kind === 'mult' && e.left > 0 && (e.tag === '*' || has(c, e.tag))) { e.left--; e.used++; v *= e.f; steps.push({k:'mult', f:e.f, txt:e.txt, perk:e.used > e.orig ? e.perk : null}); } });
    }
    if (r.t === 'repeat') { const j = S.prevAnyP(i); if (j >= 0) { v += S.pays[j]; steps.push({k:'copy', amt:S.pays[j], txt:'Repeat: ' + row[j].name}); } }
    perks.forEach(pk => {
      if (!pk.mult) return; const f = pk.mult(S, i, v); if (f === 1) return;
      if (v === 0) steps.push({k:'wasted', txt:pk.wasted || 'nothing to multiply', perk:pk.id});
      else { v *= f; steps.push({k:'mult', f, txt:pk.short || pk.name, perk:pk.id}); }
    });
    S.pays[i] = v;
    // arm effects for later cards
    // a perk that lengthens an effect (more charges) owns only the uses past the card's own; a Golden one owns all
    const src = r.golden || itemPerk, orig = c.rule.ch || 1;
    if (r.t === 'armFlat') S.effects.push({kind:'flat', tag:r.tag, n:r.n, left:r.ch, txt:c.name, perk:src, gold:r.golden || null, orig, used:0});
    if (r.t === 'armMult') { S.effects = S.effects.filter(e => e.from !== ids[i]); S.effects.push({kind:'mult', tag:r.tag, f:r.f, left:r.ch, txt:c.name, from:ids[i], perk:src, orig, used:0}); }
    if (r.t === 'opening' && i === 0) S.effects.push({kind:'mult', tag:'*', f:r.f, left:1, txt:c.name, orig:1, used:0});
    slots.push({id:ids[i], name:c.name, steps, price:S.prices[i], pay:v});
  }
  const extra = [];
  perks.forEach(pk => { if (pk.post) pk.post(S).forEach(x => extra.push(Object.assign({perk:pk.id}, x))); });
  const wasted = [];
  perks.forEach(pk => {
    const why = pk.rowWasted ? pk.rowWasted(S) : '';
    if (why) wasted.push({perk:pk.id, txt:why});
    else if (pk.mult && !slots.some(s => s.steps.some(st => st.perk === pk.id && st.k === 'mult'))) {
      const w = slots.some(s => s.steps.some(st => st.perk === pk.id && st.k === 'wasted'));
      wasted.push({perk:pk.id, txt:w ? pk.wasted || 'nothing to multiply' : 'never fired'});
    }
  });
  const total = slots.reduce((s, x) => s + x.pay, 0) + extra.reduce((s, x) => s + x.amt, 0);
  return {slots, extra, wasted, total};
}
// what a perk adds to a row (its delta over the row without it)
function delta108(rowKey, perkId, opt) { const ids = ROWS108[rowKey].ids; return score108(ids, [perkId], opt).total - score108(ids, [], opt).total; }

if (typeof module !== 'undefined') module.exports = {C108, ROWS108, REF108, PERKS, score108, delta108, levelled, QUOTA5, QUOTA8};
