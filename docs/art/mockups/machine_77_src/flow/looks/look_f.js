// Look F: RESTOCK HATCH (#77 prep, round 2). Look A's teal terminal, but the draw reads as the shop packing your
// order: the receipt you fed in is pinned up as an ORDER slip, three stock bays send their box down a trapdoor one at
// a time (each slip line ticks) onto a runway under the bays, which carries it right into the RESTOCK door; a mini
// checkout belt (the game's rubber belt, slats and steel rails, running left toward the register like the shift
// screen's) brings it out of the strip-curtain hatch below. A box is on screen the whole way (hidden only for the
// 0.08 s it spends inside the hatch). The bay box is the belt box, smaller: same tape and number tag. Bay 1 is the
// one nearest the hatch (its box goes furthest left). Each box stops at its tray's gate; its flaps pop open when its
// reveal starts. No spinning, no chasing lights: one steady belt.
// Round 3 (2026-10-20): the decided look. On a BONUS TICKET (api.visit 1) the page hands the look a second ordinary
// visit: the slip slides out and back in headed BONUS, the bays (restocked after the first pick) drop 3 more boxes.
// Contract: looks/README.md. Every colour is from art/src/palette.txt; art pixels are 2 px.
(function () {
  window.LOOKS = window.LOOKS || {};
  const C = { // art/src/palette.txt
    ink: '#2b2420', inkL: '#4a3f38', greyD: '#5e574d', grey: '#8a8172', greyL: '#c7beab', creamD: '#b39f78', creamS: '#ddcba5', cream: '#f3e9d2', paper: '#fbf7ee',
    tealK: '#172c2b', tealDD: '#1f3b3a', tealD: '#2a4d4b', tealS: '#3a7672', teal: '#4f9a94', tealL: '#86c2b6', tealP: '#c3e0d4',
    tomDD: '#6e2630', tomD: '#a83a3c', tom: '#d9534f', tomL: '#ec8a6e', musDD: '#7a5a1c', musD: '#b38425', mus: '#e2b33c', musL: '#f1d27a', musP: '#faecbc', gold: '#ffcf3f',
    good: '#5fae5a', goodD: '#3d7a45', goodL: '#a5d17e', brDD: '#4a3022', brD: '#7a5232', br: '#a87a4e', brL: '#d2a874', woodP: '#ddb07a',
    brassD: '#8a5d1a', steelH: '#ecebe4', steelL: '#c7c3b8', steelP: '#a9a59b', steel: '#8d8a83', steelS: '#6f6b63', steelD: '#57534c', steelDD: '#45423d',
    rubber: '#3d3a36', rubberD: '#2c2926', char: '#24221f', slate: '#2c3533', slateD: '#222a29',
  };
  const ENTRY = 400;           // a box's left edge when it is still behind the hatch's curtain (machine px)
  const V_MAIN = 320, V_SD = 420; // belt speed in machine px per timeline second (STAMP DAY's belt is quicker: its drops are shorter)
  const LANDS = [.5, .9, 1.3];  // seconds after T.drawEnd at which boxes 1, 2, 3 reach their gates
  // the stockroom window (half-res art px): bay frames, bay floor, the runway under the bays, the RESTOCK door
  const FT = 5, FL = 38, RW = 41, DOOR = 182, BOX_Y = FL - 30;
  const bayX = cell => 60 + 42 * (2 - cell);    // the bay that packs cell `cell`: box 1 sits nearest the hatch
  const ride = cell => DOOR - (bayX(cell) + 8); // runway distance from under the bay into the door
  // [main, STAMP DAY]: fall through the trapdoor (s), runway speed (art px/s), time inside the hatch (s)
  const RUN = [{ fall: .3, vl: 200, hid: .08 }, { fall: .15, vl: 340, hid: .05 }];
  const LINE = { new: 'NEW ITEM', coupons: 'COUPON', register: 'STAMP', upgrades: 'UPGRADE' };
  const GLYPH5 = { // 5 x 7 letters printed on the box
    R: ['XXXX.', 'X...X', 'X...X', 'XXXX.', 'X.X..', 'X..X.', 'X...X'],
    1: ['..X..', '.XX..', '..X..', '..X..', '..X..', '..X..', '.XXX.'],
    2: ['.XXX.', 'X...X', '....X', '...X.', '..X..', '.X...', 'XXXXX'],
    3: ['XXXX.', '....X', '....X', '.XXX.', '....X', '....X', 'XXXX.'],
    S: ['...X...', '...X...', 'XXXXXXX', '.XXXXX.', '..XXX..', '.XX.XX.', '.X...X.'],
  };
  function glyph(g, ch, x, y, col) { GLYPH5[ch].forEach((row, j) => [...row].forEach((c, i) => { if (c === 'X') R(g, x + i, y + j, 1, 1, col); })); }
  const DIGIT = { 1: ['.X.', 'XX.', '.X.', '.X.', 'XXX'], 2: ['XX.', '..X', '.X.', 'X..', 'XXX'], 3: ['XX.', '..X', '.X.', '..X', 'XX.'] };

  // ---------------------------------------------------------------- pixel art, drawn once (art px; shown at 2x)
  function cv(w, h) { const c = document.createElement('canvas'); c.width = w; c.height = h; return c; }
  function R(g, x, y, w, h, col) { g.fillStyle = col; g.fillRect(Math.round(x), Math.round(y), Math.round(w), Math.round(h)); }
  // the big box: 54 x 84, the ticket back (108 x 168 on screen). sd = STAMP DAY's box (tomato tape, mustard logo)
  function drawBox(g, ox, oy, sd, cell) {
    const r = (x, y, w, h, c) => R(g, ox + x, oy + y, w, h, c);
    const tape = sd ? [C.tom, C.tomL, C.tomD] : [C.teal, C.tealL, C.tealS];
    r(0, 0, 54, 84, C.ink);
    r(1, 1, 52, 9, C.woodP); r(26, 1, 2, 9, C.br);                 // the top face and the flaps' seam
    r(1, 10, 52, 1, C.brD);                                          // the top's front edge
    r(1, 11, 52, 72, C.brL); r(1, 11, 1, 68, C.woodP);               // the front, lit from the top left
    r(48, 11, 5, 72, C.br); r(1, 79, 52, 4, C.br); r(48, 79, 5, 4, C.brD);
    r(22, 1, 10, 22, tape[0]); r(22, 1, 2, 22, tape[1]); r(30, 1, 2, 22, tape[2]); // the tape over the seam and down the front
    for (let x = 22; x < 32; x += 2) r(x, 23, 1, 1, tape[x < 30 ? 0 : 2]);        // its torn end
    [[5, 14], [11, 14]].forEach(([x, y]) => { r(x + 1, y, 1, 7, C.brD); r(x, y + 1, 3, 1, C.brD); r(x - 1, y + 2, 1, 1, C.brD); r(x + 3, y + 2, 1, 1, C.brD); }); // THIS WAY UP
    glyph(g, String(cell + 1), ox + 41, oy + 14, C.brD);                            // the box's number (its tray)
    r(7, 27, 40, 39, C.ink); r(8, 28, 38, 37, C.paper); r(8, 63, 38, 2, C.creamS); r(44, 28, 2, 37, C.creamS); // the label
    const lg = sd ? [C.mus, C.musL, C.musD] : [C.teal, C.tealL, C.tealS];
    r(18, 30, 18, 17, C.ink); r(19, 31, 16, 15, lg[0]); r(19, 31, 16, 1, lg[1]); r(19, 31, 1, 15, lg[1]); r(33, 32, 2, 14, lg[2]); r(20, 44, 15, 2, lg[2]); // the RR logo (look A's)
    if (sd) glyph(g, 'S', ox + 23, oy + 35, C.ink); else { glyph(g, 'R', ox + 22, oy + 35, lg[2]); glyph(g, 'R', ox + 28, oy + 35, lg[2]); glyph(g, 'R', ox + 21, oy + 34, C.paper); glyph(g, 'R', ox + 27, oy + 34, C.paper); }
    [1, 2, 1, 1, 3, 1, 2, 1, 1, 2, 3, 1, 1, 2, 1].reduce((x, w, i) => { if (i % 2 === 0) r(x, 55, w, 7, C.ink); return x + w + 1; }, 12); // barcode
    r(19, 69, 16, 4, C.brDD); r(19, 69, 16, 1, C.brD);               // hand hole
  }
  // a stock box in a bay: 22 x 30, the belt box made small (same tape colour, the same number tag at its top right)
  function drawMini(g, x, y, sd, cell) {
    const r = (a, b, w, h, c) => R(g, x + a, y + b, w, h, c);
    const tape = sd ? [C.tom, C.tomL, C.tomD] : [C.teal, C.tealL, C.tealS], lg = sd ? [C.mus, C.musD] : [C.teal, C.tealS];
    r(0, 0, 22, 30, C.ink); r(1, 1, 20, 4, C.woodP); r(10, 1, 2, 4, C.br); r(1, 5, 20, 1, C.brD);
    r(1, 6, 20, 23, C.brL); r(1, 6, 1, 21, C.woodP); r(18, 6, 3, 23, C.br); r(1, 26, 20, 3, C.br);
    r(9, 1, 4, 9, tape[0]); r(9, 1, 1, 9, tape[1]); r(12, 1, 1, 9, tape[2]);
    DIGIT[cell + 1].forEach((row, j) => [...row].forEach((ch, i) => { if (ch === 'X') r(15 + i, 6 + j, 1, 1, C.brD); }));
    r(4, 12, 14, 10, C.ink); r(5, 13, 12, 8, C.paper); r(8, 14, 6, 5, lg[0]); r(13, 14, 1, 5, lg[1]); r(6, 20, 10, 1, C.creamS);
    r(8, 24, 6, 2, C.brDD);
  }
  // the box's lid while it opens: drawn over the box's top, 66 x 100 with the box at (6, 16). f: 0 tape splits, 1 flaps half up, 2 flaps open
  function drawLid(g, f, sd) {
    const ox = 6, oy = 16, tape = sd ? [C.tom, C.tomL, C.tomD] : [C.teal, C.tealL, C.tealS];
    const r = (x, y, w, h, c) => R(g, ox + x, oy + y, w, h, c);
    if (f === 0) { // the tape splits along the seam and the flaps bulge by one pixel
      r(0, -1, 54, 11, C.ink); r(1, 0, 52, 9, C.woodP); r(1, 9, 52, 1, C.brD);
      r(22, 0, 4, 9, tape[0]); r(22, 0, 1, 9, tape[1]); r(28, 0, 4, 9, tape[0]); r(31, 0, 1, 9, tape[2]);
      r(26, -1, 2, 10, C.ink); r(25, 2, 1, 1, C.ink); r(28, 5, 1, 1, C.ink);
      return;
    }
    // the open top: a dark inside with the back wall's edge
    r(1, 1, 52, 9, C.brDD); r(1, 1, 52, 2, C.brD); r(2, 3, 50, 1, C.ink);
    const hgt = f === 1 ? 7 : 15, sl = f === 1 ? 2 : 7;
    const flap = (b0, b1, left) => { // a flap standing on the top's back edge, leaning out
      for (let k = 0; k <= hgt; k++) {
        const p = k / hgt, out = Math.round(sl * p), y = 1 - k;
        const a = left ? b0 - out : b0 + Math.round(out * .3), b = left ? b1 - Math.round(out * .3) : b1 + out;
        r(a, y, b - a + 1, 1, C.ink);
        if (k > 0 && k < hgt) {
          r(a + 1, y, b - a - 1, 1, k > hgt - 3 ? C.woodP : C.brL);
          const tx = left ? b - 4 : a + 1; r(tx, y, 4, 1, k < hgt - 1 ? tape[0] : tape[1]); // the half of the tape on this flap
          r(left ? a + 1 : b - 1, y, 1, 1, C.br);
        }
      }
    };
    flap(0, 26, true); flap(27, 53, false);
  }
  // the hatch's hood at the belt's right end: 24 x 97 art px (the curtain is painted per frame)
  function drawHood(g) {
    R(g, 0, 0, 24, 97, C.ink);
    R(g, 4, 1, 19, 95, C.steelL); R(g, 4, 1, 19, 2, C.steelH); R(g, 4, 1, 1, 94, C.steelH); R(g, 20, 3, 3, 93, C.steelP); R(g, 4, 92, 19, 4, C.steelS);
    R(g, 7, 12, 13, 1, C.steel); R(g, 7, 82, 13, 1, C.steel);
    [[8, 5], [17, 5], [8, 87], [17, 87]].forEach(([x, y]) => { R(g, x, y, 3, 3, C.steelD); R(g, x, y, 1, 1, C.steelH); });
    R(g, 1, 3, 3, 91, C.char); // the mouth, seen edge on
  }
  function dataURL(w, h, fn) { const c = cv(w, h); fn(c.getContext('2d')); return c.toDataURL(); }

  // ---------------------------------------------------------------- timing helpers (all pure functions of t)
  const box0 = cell => ENTRY - CELL(cell);
  function CELL(cell) { return [26, 156, 286][cell]; }
  // a belt run: boxes land at `lands`, belt speed v; returns [{e, L}] (e = the box clears the curtain's back, L = it meets its gate)
  function run(lands, v) { return lands.map((L, i) => ({ e: L - box0(i) / v, L })); }
  // belt travel since 0: a trapezoid speed profile per run (ramps .2 s up before the first box, .15 s down after the last)
  function travel(t, runs) {
    let d = 0;
    runs.forEach(({ a, b, v }) => {
      const ru = .2, rd = .15, A = a - ru, B = b + rd;
      if (t <= A) return;
      const t1 = Math.min(t, a); d += v * (t1 - A) * (t1 - A) / (2 * ru);
      if (t > a) d += v * (Math.min(t, b) - a);
      if (t > b) { const q = Math.min(t, B) - b; d += v * (q - q * q / (2 * rd)); }
    });
    return d;
  }

  LOOKS.f = {
    label: 'F restock hatch', sub: 'restock hatch',
    win: { x: 22, y: 276, w: 376, h: 150, border: 2, half: true },
    drawTime: 1.8, drawMsg: 'PACKING YOUR ORDER…', holdDrawMsg: true, opener: 'flip', exitSlot: false,
    drops(T) { return run(LANDS.map(x => T.drawEnd + x), V_MAIN).map(({ e, L }) => [e, L - e]); },
    ticketBack(api, cell, sd) {
      const A = this.art(); const lid = [0, 1, 2].map(f => `<img class="lid" data-f="${f}" src="${A.lid[sd ? 1 : 0][f]}" alt="">`).join('');
      return `<img class="bx" src="${A.box[sd ? 1 : 0][cell]}" alt="">${lid}`;
    },
    art() { // cached across restarts
      if (this._art) return this._art;
      const box = [false, true].map(sd => [0, 1, 2].map(cell => dataURL(54, 84, g => drawBox(g, 0, 0, sd, cell))));
      const lid = [false, true].map(sd => [0, 1, 2].map(f => dataURL(66, 100, g => drawLid(g, f, sd))));
      const mini = [false, true].map(sd => [0, 1, 2].map(cell => { const c = cv(22, 30); drawMini(c.getContext('2d'), 0, 0, sd, cell); return c; }));
      const hood = dataURL(24, 97, drawHood);
      return (this._art = { box, lid, mini, hood });
    },
    // the visit's beats, from the page's timeline. A box's trip: pick (trapdoor opens) -> fall -> runway -> into the
    // door at `exits` -> inside the hatch for `hid` -> out of the curtain at its belt run's `e` -> its gate at `L`.
    plan(api) {
      const T = api.T, rm = api.rm, n = Math.max(1, api.prizes.length), sdn = api.stampDay ? api.stampDay.length : 0;
      const trip = (runs, k, t0, quick) => { // picks worked back from each box's belt run, so a box never waits off screen
        const q = RUN[k];
        if (!runs) return { picks: [0, 1, 2].map(i => t0 + (rm ? 0 : quick * i)), exits: [-1, -1, -1], fall: 0, vl: q.vl };
        const exits = runs.map(r => r.e - q.hid);
        return { picks: exits.map((x, i) => Math.max(t0, x - ride(i) / q.vl - q.fall)), exits, fall: q.fall, vl: q.vl };
      };
      const main = rm ? null : run(T.drops.map(([a, d]) => a + d), V_MAIN);
      const m = trip(main, 0, T.draw + (rm ? 0 : .05), .05);
      const sdRuns = api.stampDay && !rm ? run(T.sdDrops.map(([a, d]) => a + d), V_SD) : null;
      const sd = api.stampDay ? Object.assign(trip(sdRuns, 1, T.sd + .02, 0), { runs: sdRuns }) : null;
      const restock = [0, 1, 2].map(i => T.punch + .1 + (rm ? 0 : .15 * i));
      const sdRestock = sd ? [0, 1, 2].map(i => T.sdLand + .3 + (rm ? 0 : .15 * i)) : null;
      const belt = [];
      if (main) belt.push({ a: main[0].e, b: main[Math.min(n, 3) - 1].L, v: V_MAIN });
      if (sdRuns) belt.push({ a: sdRuns[0].e, b: sdRuns[Math.min(sdn, 3) - 1].L, v: V_SD });
      return { n, sdn, picks: m.picks, m, main, sd, restock, sdRestock, belt, packed: rm ? T.draw + .2 : m.picks[Math.min(n, 3) - 1] + .3 };
    },

    build(api) {
      const A = this.art(), m = api.machine, el = api.u.el;
      // the ORDER slip: the receipt you fed in, pinned up in the stockroom
      const clip = el('div', 'fSlipClip'); const slip = el('div', 'fSlip');
      slip.innerHTML = `<div class="pin"></div><div class="h">ORDER <b></b></div><div class="sp"></div><div class="ru"></div><div class="ls"></div><div class="pk">PACKED</div>`;
      clip.appendChild(slip); m.appendChild(clip);
      // the window's sign
      m.appendChild(el('div', 'fSign', 'STOCKROOM'));
      // the plate between the window and the belt: chevrons point the belt's way (left, like the shift screen's belt)
      const plate = el('div', 'fPlate'); this.chev = [];
      for (let i = 0; i < 5; i++) { const c = el('i'); plate.appendChild(c); this.chev.push(c); }
      plate.appendChild(el('span', '', 'YOUR ORDER')); m.appendChild(plate); this.plate = plate; this.plateHidden = null;
      // the belt's boxes (behind the hood, in front of the belt), the gates and the hood
      const lane = el('div', 'fLane'); this.boxes = [0, 1, 2].map(() => { const b = new Image(); b.src = A.box[0][0]; b.className = 'fBox'; lane.appendChild(b); return b; });
      m.appendChild(lane); this.lane = lane;
      this.gates = [0, 1, 2].map(i => { const g = el('div', 'fGate'); g.style.left = (CELL(i) - 9) + 'px'; m.appendChild(g); return g; });
      const hood = el('div', 'fHood'); const hi = new Image(); hi.src = A.hood; hood.appendChild(hi);
      const cur = document.createElement('canvas'); cur.width = 4; cur.height = 91; cur.className = 'cur'; hood.appendChild(cur); this.cur = cur;
      const lamp = el('div', 'lamp'); hood.appendChild(lamp); this.lamp = lamp;
      hood.appendChild(el('div', 'lbl', 'RESTOCK')); m.appendChild(hood);
      this.slip = slip; this.slipClip = clip;
      // slip text for this visit
      slip.querySelector('.h b').textContent = `#${api.shift}${['new', 'coupons', 'register', 'upgrades'].indexOf(api.st.chute) + 1}7`;
      slip.querySelector('.sp').textContent = `SPEND €${api.receipt.spend} ✓`;
      this.lines = [0, 1, 2].map(i => { const d = el('div', 'li', `<span class="ck"></span><span class="tx">${i + 1} · ${LINE[api.st.chute]}</span>`); slip.querySelector('.ls').appendChild(d); return d; });
      this.key = null;
    },

    frame(api, t) {
      const T = api.T, rm = api.rm, P = this.plan(api), { seg, sm, eOut } = api.u;
      const inSD = !!(P.sd && t >= T.sd);
      // the shared rarity labels sit over the plate during reveals: hide it then
      const during = (R, end) => !!(R && R.length && end != null && t >= Math.min(...R.map(r => r.t0)) && t < end + .4);
      const hidePlate = during(T.rev, T.bin) || during(T.sdRev, T.sdBin);
      if (this.plateHidden !== hidePlate) { this.plateHidden = hidePlate; this.plate.style.visibility = hidePlate ? 'hidden' : ''; }
      // ---- the slip: slides down out of the intake as the receipt is read; STAMP DAY re-uses it
      const sp = rm ? (t >= T.feedEnd ? 1 : 0) : sm(seg(t, T.flyEnd, T.feedEnd + .35));
      this.slip.style.transform = `translateY(${-Math.round((1 - sp) * 72) * 2}px)`;
      this.slip.style.visibility = sp > 0 ? 'visible' : 'hidden';
      const picks = inSD ? P.sd.picks : P.picks, nn = inSD ? P.sdn : P.n;
      this.slip.querySelector('.h').firstChild.textContent = inSD ? 'STAMP DAY' : api.visit ? 'BONUS ' : 'ORDER ';
      this.slip.querySelector('.h b').style.display = inSD ? 'none' : '';
      // the slip names the chute only once it is confirmed (T.press): before that its lines read "?" (both visits)
      const chosen = inSD || t >= T.press;
      const ord = `#${api.shift}${chosen ? ['new', 'coupons', 'register', 'upgrades'].indexOf(api.st.chute) + 1 : '?'}${api.visit ? 8 : 7}`, hb = this.slip.querySelector('.h b');
      if (hb.textContent !== ord) hb.textContent = ord;
      const spT = api.visit ? 'INSPECTED ✓' : `SPEND €${api.receipt.spend} ✓`, spE = this.slip.querySelector('.sp');
      if (spE.textContent !== spT) spE.textContent = spT;
      this.lines.forEach((d, i) => {
        d.style.display = i < nn ? 'flex' : 'none';
        const tx = `${i + 1} · ${inSD ? 'STAMP' : chosen ? LINE[api.st.chute] : '?'}`, te = d.querySelector('.tx');
        if (te.textContent !== tx) te.textContent = tx;
        d.classList.toggle('on', t >= picks[i] + (rm ? 0 : .15));
      });
      const pkT = inSD ? P.sd.picks[2] + .25 : P.packed, pk = this.slip.querySelector('.pk');
      pk.style.display = t >= pkT ? 'block' : 'none';
      pk.style.transform = `rotate(-8deg) scale(${rm ? 1 : api.u.lerp(1.6, 1, eOut(seg(t, pkT, pkT + .15))).toFixed(2)})`;
      // ---- the belt: the tray's slats scroll with the travel; boxes ride until their gate
      const dist = travel(t, P.belt.filter(b => !rm && b.v));
      api.tray.style.backgroundPosition = `${-(Math.round(dist / 2) * 2 % 20)}px 0`;
      const runs = inSD ? (P.sd.runs || []) : (P.main || []);
      const sdKind = inSD;
      this.boxes.forEach((b, i) => {
        const r = runs[i], on = !rm && r && i < nn && t >= r.e - .05 && t < r.L;
        b.style.display = on ? 'block' : 'none'; if (!on) return;
        const v = inSD ? V_SD : V_MAIN, x = Math.max(CELL(i), ENTRY - Math.max(0, t - r.e) * v);
        b.style.left = (Math.round(x / 2) * 2 - 12) + 'px';
        const want = this.art().box[sdKind ? 1 : 0][i]; if (b.getAttribute('src') !== want) b.src = want;
      });
      // ---- gates: gate i pops up once the box before it has passed (so each box stops in its own tray)
      this.gates.forEach((g, i) => {
        let up = false;
        const r = inSD ? P.sd && P.sd.runs : P.main;
        if (rm) up = t >= T.drawEnd && t < T.punch;
        else if (r && t < (inSD ? T.sdLand + .2 : T.punch)) {
          const v = inSD ? V_SD : V_MAIN, prev = i === 0 ? null : r[i - 1];
          const ready = prev ? prev.e + (ENTRY - (CELL(i) - 9) + 108) / v : r[0].e - .3; // the box before it has cleared this gate
          up = t >= ready && t >= (inSD ? T.sd : T.draw);
        }
        if (inSD && rm) up = t >= T.sd && t < T.sdLand + .2;
        g.classList.toggle('up', up);
      });
      // ---- the hood: the curtain strips swing while a box goes through; the run lamp is lit while the belt moves
      const g = this.cur.getContext('2d'); g.clearRect(0, 0, 4, 91);
      let push = 0;
      this.boxes.forEach((b, i) => { const r = runs[i]; if (!rm && r && t >= r.e - .45 && t < r.e) push = 1; });
      for (let y = 0; y < 91; y++) { const sw = push && y > 20 ? (Math.floor(t * 14 + y / 9) % 2) : 0; R(g, 0, y, 4, 1, (y % 2 ? C.rubber : C.rubberD)); if (sw) R(g, 0, y, 1, 1, C.char); }
      for (let x = 0; x < 4; x += 2) for (let y = 0; y < 91; y += 12) R(g, x, y + (push ? Math.floor(t * 10) % 3 : 0), 1, 8, C.steelDD);
      const moving = P.belt.some(b => !rm && t >= b.a - .2 && t < b.b + .15);
      const rv = api.reveal(t), legend = rv && rv.tier === 2 && rv.p > .3 && rv.p < .9;
      this.lamp.className = 'lamp' + (legend ? (Math.floor(t * 8) % 2 ? ' gold' : '') : moving ? ' on' : '');
      this.chev.forEach((c, i) => c.className = moving ? (rm || Math.floor(t * 4) % 5 !== 4 - i ? 'on' : '') : legend && Math.floor(t * 8) % 2 ? 'gold' : '');
      // ---- the box lids: tape splits, then the flaps pop open as the shared reveal turns the card
      const lidOf = (list, revs) => list.forEach((k, i) => {
        const rev = revs && revs[i]; let f = -1;
        if (rev) {
          const rp = (t - rev.t0) / rev.d, tier = k.p.tier, oa = [0, .2, .35][tier];
          if (rm) f = rp >= 0 ? 2 : -1;
          else if (rp >= 0) f = tier === 0 ? (rp < .08 ? 1 : 2) : rp < oa * .45 ? 0 : rp < oa * .8 ? 1 : 2;
        }
        k.back.querySelectorAll('.lid').forEach(im => { im.style.display = +im.dataset.f === f ? 'block' : 'none'; });
      });
      lidOf(api.tickets, T.rev); if (api.stampTickets) lidOf(api.stampTickets, T.sdRev);
    },

    paint(api, g, t) { // the stockroom (half-res, 186 x 73): pin board on the left, three stock bays, the runway under them
      const T = api.T, rm = api.rm, P = this.plan(api), { seg, sm } = api.u, W = api.win.width, H = api.win.height;
      const px = (x, y, w, h, c) => R(g, x, y, w, h, c), A = this.art();
      px(0, 0, W, H, C.slateD); for (let x = 0; x < W; x += 12) px(x, 0, 1, H, C.slate);   // the back wall, planked
      // the pin board behind the slip
      px(3, 2, 51, 68, C.ink); px(4, 3, 49, 66, C.br); px(4, 3, 49, 1, C.brL); px(51, 3, 2, 66, C.brD);
      for (let y = 7; y < 68; y += 6) for (let x = 7 + (y % 12 ? 3 : 0); x < 50; x += 6) px(x, y, 1, 1, C.brD);
      const inSD = !!(P.sd && t >= T.sd), ph = inSD ? P.sd : P.m, n = inSD ? P.sdn : P.n;
      const onRunway = c => !rm && c < n && ph.exits[c] >= 0 && t >= ph.picks[c] + ph.fall && t < ph.exits[c];
      const rolling = [0, 1, 2].some(onRunway);
      // the runway under the bays: a dark channel with rollers, running right into the RESTOCK door
      px(57, RW - 1, W - 57, H - RW + 1, C.ink); px(58, RW, W - 58, H - RW, C.char);
      const roff = rolling ? Math.floor(t * 30) % 6 : 0;
      for (let x = 58 - roff; x < W; x += 6) if (x >= 58) px(x, H - 2, 3, 1, C.steelP);
      px(58, H - 1, W - 58, 1, C.steelD);
      // the door: lit while a box goes through it
      const doorLit = [0, 1, 2].some(c => c < n && ph.exits[c] >= 0 && t >= ph.exits[c] - .3 && t < ph.exits[c] + .15);
      px(DOOR - 2, RW - 1, W - DOOR + 2, H - RW + 1, C.ink); px(DOOR, RW + 1, W - DOOR, H - RW - 3, doorLit ? C.musD : C.rubberD);
      if (doorLit) px(DOOR, RW + 1, W - DOOR, 2, C.mus);
      for (let c = 0; c < 3; c++) {
        const bx = bayX(c);
        // bay frame + recess
        px(bx - 1, FT - 1, 40, FL - FT + 4, C.ink); px(bx, FT, 38, FL - FT, C.char);
        px(bx, FT, 38, 2, C.rubberD); px(bx + 36, FT, 2, FL - FT, C.rubberD);
        const pk = ph.picks[c], used = c < n, fall = rm ? 0 : ph.fall;
        // the floor, a trapdoor in its middle
        px(bx, FL, 38, 3, C.steel); px(bx, FL, 38, 1, C.steelL);
        if (!rm && used && t >= pk && t < pk + fall + .15) { px(bx + 7, FL, 24, 3, C.char); px(bx + 7, FL + 1, 2, 2, C.steelD); px(bx + 29, FL + 1, 2, 2, C.steelD); }
        // the box in the bay: waits, falls through the trapdoor when picked; a new one drops in on restock
        // (after the main draw the bays are restocked with STAMP DAY's boxes when STAMP DAY follows)
        const rf = inSD ? P.sdRestock[c] : P.restock[c], back = t >= rf, fill = back ? (rm ? 1 : sm(seg(t, rf, rf + .3))) : 0;
        const art = A.mini[inSD ? 1 : 0][c];
        if (back && (!inSD || t >= pk)) { // the refill drops in from the top of the bay
          g.save(); g.beginPath(); g.rect(bx, FT, 38, FL - FT); g.clip();
          g.drawImage(A.mini[P.sd && !inSD ? 1 : 0][c], bx + 8, Math.round(api.u.lerp(-24, BOX_Y, fill))); g.restore();
        } else if (!used || t < pk) g.drawImage(art, bx + 8, BOX_Y);
        else if (!rm && t < pk + fall) { const q = seg(t, pk, pk + fall); g.drawImage(art, bx + 8, Math.round(BOX_Y + (RW - BOX_Y) * q * q)); }
        // the bay lamp (inside, top right): green from its pick until the bay is restocked; the bay's number (top left)
        const lit = used && t >= pk - (rm ? 0 : .1) && !back;
        px(bx + 30, FT + 2, 6, 4, C.ink); px(bx + 31, FT + 3, 4, 2, lit ? C.good : C.greyD);
        DIGIT[c + 1].forEach((row, y) => [...row].forEach((ch, x) => { if (ch === 'X') px(bx + 2 + x, FT + 3 + y, 1, 1, lit ? C.musL : C.greyD); }));
      }
      // boxes riding the runway into the door (clipped at the door's mouth)
      g.save(); g.beginPath(); g.rect(58, RW, DOOR - 58, H - RW); g.clip();
      for (let c = 0; c < 3; c++) if (onRunway(c)) {
        const x = bayX(c) + 8 + (t - ph.picks[c] - ph.fall) * ph.vl;
        g.drawImage(A.mini[inSD ? 1 : 0][c], Math.round(x), RW);
      }
      g.restore();
    },

    sounds(api) {
      const T = api.T, rm = api.rm, P = this.plan(api), ev = [], tone = api.tone, noise = api.noise, N = api.NOTE;
      const pickSnd = (pk, i) => { ev.push([pk - (rm ? 0 : .1), () => tone([N.C5, N.E5, N.G5][i], .07, 'square', .03)]); ev.push([pk + (rm ? 0 : .05), () => tone(150, .09, 'sine', .1)]); ev.push([pk + (rm ? 0 : .15), () => tone(2200, .015, 'square', .02)]); };
      P.picks.slice(0, P.n).forEach(pickSnd);
      ev.push([P.packed, () => { tone(110, .09, 'square', .06); noise(.04, .04); }]);
      const beltSnd = (b, runs, cnt) => {
        if (!b) return;
        ev.push([b.a - .2, () => tone(70, .3, 'sawtooth', .025)]);
        for (let x = b.a; x < b.b; x += .18) ev.push([x, () => tone(260, .012, 'square', .012)]);
        runs.slice(0, cnt).forEach(r => ev.push([r.e - .4, () => noise(.12, .025)]));
      };
      if (!rm && P.main) beltSnd(P.belt[0], P.main, P.n);
      if (P.sd) { P.sd.picks.slice(0, P.sdn).forEach(pickSnd); if (!rm && P.sd.runs) beltSnd(P.belt[P.main ? 1 : 0], P.sd.runs, P.sdn); }
      // the lid: a tape rip as the flaps pop
      const rip = (list, revs) => (list || []).forEach((p, i) => { const r = revs && revs[i]; if (!r) return; const oa = [0, .2, .35][p.tier]; ev.push([r.t0 + r.d * oa * .45, () => noise(.07, .05)]); });
      rip(api.prizes, T.rev); if (api.stampDay) rip(api.stampDay, T.sdRev);
      P.restock.forEach(x => ev.push([x + (rm ? 0 : .25), () => tone(180, .05, 'sine', .05)]));
      return ev;
    },
  };
})();
