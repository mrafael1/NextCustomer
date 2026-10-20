// #77 prep, round 2: machine look E, CLICK & COLLECT LOCKERS.
// Look A's terminal (teal cabinet, mustard head, cream chute keys, punch tickets, receipt slot), with A's prize drum
// replaced by the shop filling the order: the window is an order screen, and the tray is a bank of 3 pickup lockers.
// Draw: every locker's LED goes red; one locker after another goes amber (PACKING, its bar fills) then green
// (READY), its door unlatches and swings open on its left hinge, and a paper shopping bag slides forward out of the
// lit locker. The bag is the ticket's back, so the shared flip opens it into the prize inside the open locker.
// Nothing spins and nothing chases. After the pick the doors close in turn. STAMP DAY runs the same cycle again.
// All art is drawn in code in the game's palette (art/src/palette.txt) at 2 px art pixels.
window.LOOKS = window.LOOKS || {};
(function () {
  const C = {
    ink: '#2b2420', inkL: '#4a3f38', greyD: '#5e574d', grey: '#8a8172', greyL: '#c7beab',
    creamD: '#b39f78', creamS: '#ddcba5', cream: '#f3e9d2', paper: '#fbf7ee',
    tealK: '#172c2b', tealDD: '#1f3b3a', tealD: '#2a4d4b', tealS: '#3a7672', teal: '#4f9a94', tealL: '#86c2b6', tealP: '#c3e0d4',
    tomD: '#a83a3c', tom: '#d9534f', tomL: '#ec8a6e', musDD: '#7a5a1c', musD: '#b38425', mus: '#e2b33c', musL: '#f1d27a', musP: '#faecbc',
    gold: '#ffcf3f', goodD: '#3d7a45', good: '#5fae5a', goodL: '#a5d17e',
    brE: '#4a3022', brD: '#7a5232', br: '#a87a4e', brL: '#d2a874', woodP: '#ddb07a',
    stH: '#ecebe4', stL: '#c7c3b8', stP: '#a9a59b', st: '#8d8a83', stS: '#6f6b63', stD: '#57534c', stDD: '#45423d',
    char: '#24221f', glow: '#e4f6f3',
  };
  const DIGIT = { 1: ['.X.', 'XX.', '.X.', '.X.', 'XXX'], 2: ['XX.', '..X', '.X.', 'X..', 'XXX'], 3: ['XX.', '..X', '.X.', '..X', 'XX.'] };
  const NAME = { new: 'NEW ITEMS', coupons: 'COUPONS', register: 'REGISTER', upgrades: 'UPGRADES' };
  // the locker bank canvas covers the tray's inside: machine x 12..408, y 446..622, at half resolution
  const BANK = { x: 12, y: 446, w: 396, h: 176 };
  const DW = 58, DH = 85; // a door, art px
  const canvas = (w, h) => { const c = document.createElement('canvas'); c.width = w; c.height = h; const g = c.getContext('2d'); g.imageSmoothingEnabled = false; return [c, g]; };
  const R = (g, x, y, w, h, col) => { g.fillStyle = col; g.fillRect(Math.round(x), Math.round(y), Math.round(w), Math.round(h)); };
  const glyph = (g, n, x, y, s, col) => DIGIT[n].forEach((row, j) => [...row].forEach((ch, i) => { if (ch === 'X') R(g, x + i * s, y + j * s, s, s, col); }));

  // ---- sprites (built once per restart)
  function doorSprite(n) { // the locker door's front, 58 x 85
    const [c, g] = canvas(DW, DH);
    R(g, 0, 0, DW, DH, C.ink); R(g, 1, 1, DW - 2, DH - 2, C.cream);
    R(g, 1, 1, DW - 2, 1, C.paper); R(g, 1, 1, 1, DH - 2, C.paper); R(g, DW - 2, 2, 1, DH - 3, C.creamS); R(g, 2, DH - 2, DW - 3, 1, C.creamS);
    // number plate
    R(g, 6, 6, 15, 16, C.ink); R(g, 7, 7, 13, 14, C.mus); R(g, 7, 7, 13, 1, C.musL); R(g, 7, 20, 13, 1, C.musD); glyph(g, n, 10, 9, 2, C.ink);
    // keypad lock
    R(g, 41, 6, 11, 14, C.ink); R(g, 42, 7, 9, 12, C.stDD);
    for (let j = 0; j < 3; j++) for (let i = 0; i < 2; i++) R(g, 43 + i * 4, 8 + j * 4, 3, 3, C.stL);
    // handle
    R(g, 46, 34, 6, 22, C.ink); R(g, 47, 35, 4, 20, C.stL); R(g, 47, 35, 1, 20, C.stH); R(g, 50, 36, 1, 19, C.st);
    // vents
    for (let j = 0; j < 4; j++) { R(g, 10, 64 + j * 4, 34, 1, C.creamD); R(g, 10, 65 + j * 4, 34, 1, C.paper); }
    return c;
  }
  function doorBack() { // the inside of the door, seen edge-on when open
    const [c, g] = canvas(DW, DH);
    R(g, 0, 0, DW, DH, C.ink); R(g, 1, 1, DW - 2, DH - 2, C.creamD); R(g, DW - 3, 1, 2, DH - 2, C.creamS);
    return c;
  }
  function bagSprite(n, stampDay) { // the ticket's back: a paper shopping bag with its order slip, 54 x 84
    const [c, g] = canvas(54, 84);
    // twisted paper handle
    R(g, 15, 2, 25, 16, C.ink); R(g, 16, 3, 23, 14, C.brL); R(g, 16, 3, 23, 1, C.woodP);
    R(g, 18, 5, 19, 12, C.ink); g.clearRect(19, 6, 17, 11);
    // body
    R(g, 3, 15, 48, 69, C.ink); R(g, 4, 16, 46, 67, C.brL);
    R(g, 4, 16, 1, 67, C.woodP); R(g, 41, 16, 9, 67, C.br); R(g, 41, 16, 1, 67, C.brD); // left light, right gusset
    R(g, 4, 75, 46, 1, C.brD); R(g, 4, 76, 46, 7, C.br); R(g, 41, 76, 9, 7, C.brD); // folded bottom
    // folded-over top
    R(g, 4, 16, 46, 7, C.br); R(g, 4, 23, 46, 1, C.ink); for (let x = 5; x < 50; x += 4) R(g, x, 22, 2, 1, C.brD);
    // stapled order slip
    const band = stampDay ? C.tom : C.teal, bandS = stampDay ? C.tomD : C.tealS;
    R(g, 11, 19, 30, 37, C.ink); R(g, 12, 20, 28, 35, C.paper); R(g, 39, 21, 1, 34, C.cream); R(g, 12, 54, 28, 1, C.creamS);
    R(g, 12, 20, 28, 7, band); R(g, 12, 26, 28, 1, bandS);
    R(g, 23, 21, 6, 2, C.stL); R(g, 23, 22, 6, 1, C.st); // staple
    glyph(g, n, 21, 30, 3, C.ink);
    for (let i = 0; i < 12; i++) R(g, 15 + i * 2 + (i % 3 === 0 ? 0 : 0), 47, i % 3 === 1 ? 2 : 1, 5, C.ink); // barcode
    return c;
  }

  // ---- the schedule: one cycle for the draw, one for STAMP DAY; times per locker
  function cycles(api) {
    const T = api.T, rm = api.rm, out = [];
    const mk = (drops, red, closeAt, sd) => ({ sd, red, lk: drops.map(([s, d], i) => {
      const green = rm ? s : s - (sd ? .03 : .05);
      return { amber: rm ? red : Math.max(red, green - (sd ? .35 : .4)), green, s, d, c: closeAt + (rm ? 0 : i * .1), cd: rm ? 0 : .3 };
    }) });
    out.push(mk(T.drops, T.draw, T.fly2 + .35, false));
    if (api.stampDay && T.sdDrops) out.push(mk(T.sdDrops, T.sd, T.sdFly + .35, true));
    return out;
  }
  function cycleAt(api, t) { const cs = cycles(api); let cur = null; cs.forEach(c => { if (t >= c.red) cur = c; }); return cur; }
  function lockerAt(api, cy, i, t) { // LED, door opening (0..1), bag scale, packing progress
    const { seg, sm, eOut, lerp } = api.u, rm = api.rm, L = cy.lk[i];
    const led = t < cy.red ? 'off' : t < L.amber ? 'red' : t < L.green ? 'amber' : t < L.c + L.cd * .5 ? 'green' : 'off';
    let open = rm ? (t >= L.s ? 1 : 0) : seg(t, L.s + .06, L.s + L.d * .55);
    if (t >= L.c) open *= 1 - (rm ? 1 : seg(t, L.c, L.c + L.cd));
    if (!rm) open = Math.round(sm(open) * 10) / 10; // a mechanism: 10 even steps
    const jig = !rm && t >= L.s && t < L.s + .06 ? 1 : 0;
    const bag = t >= L.s && t < L.s + L.d ? (rm ? 1 : lerp(.6, 1, eOut(seg(t, L.s + L.d * .3, L.s + L.d)))) : 0;
    const pack = rm ? (t >= L.green ? 1 : 0) : seg(t, L.amber, L.green);
    return { led, open, jig, bag, pack, L };
  }
  function revealedTier(api, cy, i, t) { // the tier once this locker's prize has been revealed, else -1
    const T = api.T, rv = cy.sd ? T.sdRev : T.rev, list = cy.sd ? api.stampDay : api.prizes;
    if (!rv || !rv[i] || !list || !list[i]) return -1;
    return t >= rv[i].t0 + rv[i].d * .55 ? list[i].tier : -1;
  }

  LOOKS.e = {
    label: 'E click &amp; collect', sub: 'click &amp; collect lockers',
    win: { x: 30, y: 274, w: 360, h: 150, border: 4, half: false }, exitSlot: false,
    drawTime: 1.6, drawMsg: 'PREPARING YOUR ORDER', opener: 'flip',
    // locker i opens as soon as its LED is green: 0.45 s apart, each 0.75 s from unlatch to the bag at the front
    drops: T => [0, 1, 2].map(i => [T.draw + .75 + i * .45, .75]),
    ticketBack(api, cell, isStampDay) {
      const src = (isStampDay ? this.bagsSD : this.bags)[cell];
      return `<img class="bag" src="${src}" alt="">`;
    },
    build(api) {
      this.doors = [1, 2, 3].map(doorSprite); this.doorB = doorBack();
      this.bags = [1, 2, 3].map(n => bagSprite(n, false).toDataURL());
      this.bagsSD = [1, 2, 3].map(n => bagSprite(n, true).toDataURL());
      this.bagC = [false, true].map(sd => [1, 2, 3].map(n => bagSprite(n, sd))); // drawn straight from canvases (stills render before images load)
      // the locker bank (half resolution)
      const [c, g] = canvas(BANK.w / 2, BANK.h / 2); c.className = 'ebank';
      c.style.cssText = `position:absolute;left:${BANK.x}px;top:${BANK.y}px;width:${BANK.w}px;height:${BANK.h}px;z-index:11`;
      api.machine.appendChild(c); this.bank = c; this.bg = g;
      // the LED rail between the order screen and the lockers
      const rail = api.u.el('div', 'erail'); this.leds = [];
      [0, 1, 2].forEach(i => {
        const x = api.CELL_X[i] + 54 - 12;
        const n = api.u.el('div', 'en', 'LOCKER ' + (i + 1)); n.style.left = x - 62 + 'px'; rail.appendChild(n);
        const l = api.u.el('div', 'eled'); l.style.left = x - 5 + 'px'; rail.appendChild(l); this.leds.push(l);
      });
      api.machine.appendChild(rail); this.rail = rail; this.railHidden = null;
    },
    frame(api, t) {
      const cy = cycleAt(api, t);
      const st = [0, 1, 2].map(i => cy ? lockerAt(api, cy, i, t) : { led: 'off', open: 0, jig: 0, bag: 0, pack: 0 });
      st.forEach((s, i) => { const l = this.leds[i]; if (l.dataset.s !== s.led) { l.className = 'eled ' + s.led; l.dataset.s = s.led; } });
      // the shared rarity labels sit over the rail during reveals: hide the LOCKER n names then (the doors carry the numbers)
      const T = api.T, during = (R, end) => !!(R && R.length && end != null && t >= Math.min(...R.map(r => r.t0)) && t < end + .4);
      const hideNames = during(T.rev, T.bin) || during(T.sdRev, T.sdBin);
      if (this.railHidden !== hideNames) { this.railHidden = hideNames; this.rail.querySelectorAll('.en').forEach(n => { n.style.visibility = hideNames ? 'hidden' : ''; }); }
      // ---- the locker bank
      const g = this.bg, W = BANK.w / 2, H = BANK.h / 2, rv = api.reveal(t);
      g.clearRect(0, 0, W, H);
      R(g, 0, 0, W, H, C.tealD); R(g, 0, 0, W, 1, C.tealS); R(g, 0, H - 1, W, 1, C.tealDD);
      for (let i = 0; i < 3; i++) {
        const cx = (api.CELL_X[i] - BANK.x) / 2, x0 = cx - 3, y0 = 1, s = st[i];
        // the compartment, lit from its ceiling
        R(g, x0, y0, 60, 87, C.ink);
        R(g, x0 + 1, y0 + 1, 58, 85, C.stS);
        const tier = cy && s.open > 0 ? revealedTier(api, cy, i, t) : -1;
        const backCol = tier === 2 ? C.musP : tier === 1 ? C.tealP : C.stL;
        R(g, x0 + 1, y0 + 6, 5, 74, C.st); R(g, x0 + 54, y0 + 6, 5, 74, C.stP);
        R(g, x0 + 6, y0 + 6, 48, 74, backCol); R(g, x0 + 6, y0 + 6, 48, 1, C.stS);
        R(g, x0 + 1, y0 + 80, 58, 6, C.stD); R(g, x0 + 6, y0 + 80, 48, 1, C.stDD);
        const legNow = rv && !api.rm && rv.tier === 2 && rv.i === i && !!rv.stampDay === !!(cy && cy.sd) && rv.p > .35 && rv.p < .8;
        const lamp = s.open <= 0 ? C.stDD : legNow && Math.floor(t * 8) % 2 ? C.gold : tier === 2 ? C.gold : tier === 1 ? C.tealL : C.glow;
        R(g, x0 + 14, y0 + 2, 32, 2, lamp);
        // the bag sliding forward (it becomes the ticket when it reaches the front)
        if (s.bag > 0 && cy) {
          const im = this.bagC[cy.sd ? 1 : 0][i], bw = Math.round(54 * s.bag), bh = Math.round(84 * s.bag);
          const bx = cx + Math.round((54 - bw) / 2), by = 3 + 84 - bh;
          R(g, bx + 2, by + bh - 1, bw - 4, 1, C.stDD);
          g.drawImage(im, bx, by, bw, bh);
        }
        // the door, column by column around its left hinge
        const hx = x0 + 1 + s.jig, a = s.open * 96 * Math.PI / 180, co = Math.cos(a), e = 2 * Math.sin(a);
        const w = Math.round(DW * Math.abs(co)), src = co >= 0 ? this.doors[i] : this.doorB;
        if (w < 1) R(g, hx - 1, y0 + 1 - e, 1, DH + 2 * e, C.ink);
        for (let k = 0; k < w; k++) {
          const u = (k + .5) / w, sx = Math.min(DW - 1, Math.floor(u * DW)), top = Math.round(y0 + 1 - e * u), bot = Math.round(y0 + 1 + DH + e * u);
          const x = co >= 0 ? hx + k : hx - 1 - k;
          g.drawImage(src, sx, 0, 1, DH, x, top, 1, bot - top);
        }
      }
    },
    paint(api, g, t) { // the order screen (full resolution, 2 px blocks)
      const T = api.T, W = api.win.width, H = api.win.height, { seg } = api.u;
      R(g, 0, 0, W, H, C.char); for (let y = 0; y < H; y += 4) R(g, 0, y, W, 2, '#272522');
      const txt = (s, x, y, font, col, al = 'left') => { g.font = font; g.fillStyle = col; g.textAlign = al; g.fillText(s, x, y); };
      const PX = n => `${n}px Pixelify`, AT = n => `700 ${n}px Atkinson`;
      const chute = NAME[api.st.chute] || '';
      const cy = cycleAt(api, t);
      if (!cy) { // before the draw
        if (t < T.fly) {
          txt('CLICK & COLLECT', W / 2, 52, PX(26), C.musL, 'center');
          txt('Feed in your receipt.', W / 2, 84, AT(13), C.greyL, 'center');
          txt('We pack 3 prizes into the lockers. You keep 1.', W / 2, 104, AT(13), C.greyL, 'center');
        } else if (t < T.readEnd) {
          const ok = t >= T.feedEnd;
          txt(ok ? 'RECEIPT OK ✓' : 'READING RECEIPT…', W / 2, 58, PX(22), ok ? C.goodL : C.musL, 'center');
          if (ok) txt(`SPEND €${api.receipt.spend} · QUOTA €${api.receipt.quota} MET`, W / 2, 90, AT(13), C.greyL, 'center');
          else { const n = Math.floor(seg(t, T.fly, T.feedEnd) * 6); for (let i = 0; i < 6; i++) R(g, W / 2 - 66 + i * 22, 80, 16, 8, i < n ? C.musL : C.greyD); }
        } else if (t < T.hover) {
          txt('WHAT SHALL WE PACK?', W / 2, 58, PX(22), C.musL, 'center');
          txt('Pick a prize type above.', W / 2, 90, AT(13), C.greyL, 'center');
        } else {
          txt(`ORDER: 3 × ${chute}`, W / 2, 58, PX(22), C.musL, 'center');
          txt('You keep 1. Confirm and we start packing.', W / 2, 90, AT(13), C.greyL, 'center');
        }
        return;
      }
      const list = cy.sd ? api.stampDay : api.prizes, press = cy.sd ? T.sdPress : T.pickPress, pick = list.length - 1;
      const done = t >= (cy.sd ? T.sdLand : T.land);
      txt(cy.sd ? 'STAMP DAY · FREE ORDER' : `ORDER No. 04${api.shift}7`, 12, 24, PX(17), cy.sd ? C.tomL : C.musL);
      txt(done ? 'COLLECTED ✓' : `3 × ${cy.sd ? 'REGISTER' : chute}`, W - 12, 24, AT(12), done ? C.goodL : C.greyL, 'right');
      for (let x = 12; x < W - 12; x += 8) R(g, x, 32, 4, 2, C.greyD);
      for (let i = 0; i < 3; i++) {
        const y = 42 + i * 32, s = lockerAt(api, cy, i, t), tier = revealedTier(api, cy, i, t);
        // locker number box with its LED colour
        const ledCol = { off: C.greyD, red: C.tom, amber: C.gold, green: C.good }[s.led];
        R(g, 12, y, 24, 24, C.ink); R(g, 14, y + 2, 20, 20, C.cream); glyph(g, i + 1, 21, y + 7, 2, C.ink); R(g, 30, y + 4, 4, 4, ledCol);
        // name: the locker, then the prize once revealed
        if (tier >= 0) { let n = api.info(list[i]).name; g.font = PX(15); while (g.measureText(n).width > 112 && n.length > 3) n = n.slice(0, -2) + '…'; txt(n, 46, y + 17, PX(15), C.paper); }
        else txt('Locker ' + (i + 1), 46, y + 17, AT(13), C.greyL);
        // packing bar: 8 blocks
        const nb = Math.floor(s.pack * 8 + 1e-6), full = t >= s.L.green;
        for (let b = 0; b < 8; b++) R(g, 166 + b * 10, y + 6, 8, 12, b < nb ? (full ? C.good : C.mus) : C.inkL);
        // status
        let word = 'WAITING', col = C.tomL;
        if (t >= press) { word = i === pick ? 'YOURS ✓' : 'NOT TAKEN'; col = i === pick ? C.gold : C.grey; }
        else if (tier >= 0) { word = ['COMMON', 'RARE!', 'LEGENDARY!!'][tier]; col = [C.greyL, C.tealL, C.gold][tier]; }
        else if (t >= s.L.s + s.L.d) { word = 'IN LOCKER'; col = C.paper; }
        else if (t >= s.L.s) { word = 'OPENING'; col = C.goodL; }
        else if (t >= s.L.green) { word = 'READY'; col = C.goodL; }
        else if (t >= s.L.amber) { word = 'PACKING'; col = C.musL; }
        txt(word, W - 12, y + 17, PX(13), col, 'right');
      }
    },
    sounds(api) {
      const ev = [], rm = api.rm, T = api.T;
      cycles(api).forEach(cy => cy.lk.forEach(L => {
        if (!rm) { ev.push([L.amber, () => api.tone(1200, .02, 'square', .025)]); for (let b = 2; b <= 8; b += 2) ev.push([L.amber + (L.green - L.amber) * b / 8 - .01, () => api.tone(1600, .012, 'square', .015)]); }
        ev.push([L.green, () => { api.tone(api.NOTE.C6, .07, 'sine', .05); api.tone(api.NOTE.E6, .1, 'sine', .05, .07); }]);
        ev.push([L.s, () => { api.noise(.04, .06); api.tone(150, .07, 'square', .04); }]); // the latch
        if (!rm) ev.push([L.s + L.d * .35, () => api.noise(.14, .025)]); // the bag slides
        ev.push([L.c, () => { api.tone(110, .06, 'square', .035, rm ? 0 : L.cd * .8); api.noise(.03, .04, rm ? 0 : L.cd * .8); }]); // the door shuts
      }));
      ev.push([T.draw, () => api.tone(api.NOTE.G5, .05, 'square', .03)]);
      return ev;
    },
  };
})();
