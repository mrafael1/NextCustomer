// Look D: COUPON PRINTER (#77 prep, round 2). Look A's terminal (teal cab, mustard head, cream keys, dark screen)
// without the drum. The machine checks YOUR receipt on its screen while it feeds in (before you pick a chute: the
// receipt only proves the quota was met), then prints 3 reward slips out of a slot, line by line like the game's
// receipt; each slip tears off, drops straight down the gap between the two screens and slides along the tray to
// its cell. Every slip prints the same lines (shift, quota, spend): nothing on a slip says why it got its prize,
// because the prize is a plain roll at the odds card's odds. Its last line (PRIZE) prints during its rarity reveal.
// Contract: README.md.
window.LOOKS = window.LOOKS || {};
(function () {
  // the receipt's lines, as the page's buildReceipt() writes them (the api gives only spend/quota: see the report)
  const NAMES = ['Eggs', 'Coffee', 'Milk', 'Milk ×3', 'Bread', 'Banana pair'], WTS = [1, 10, 21, 24, 10, 8];
  const basket = sp => { const sw = WTS.reduce((a, b) => a + b, 0); let acc = 0;
    return WTS.map((x, i) => { const v = i === WTS.length - 1 ? sp - acc : Math.max(1, Math.round(x * sp / sw)); acc += v; return [NAMES[i], v]; }); };
  // timing at 1x (timeline seconds)
  const READ = .4, GAP = .65, DUR = .9;         // the draw before the first slip, gap between slips, one slip (print + tear + drop)
  const SLOT = [0, 2, 1];                       // print order per tray cell: left, right, then the middle (straight down),
                                                // so a slip never slides over a slip already in the tray
  const P_END = .5, TEAR_END = .6;              // fractions of a slip's drop: printing ends, the tear ends
  // the slip's rows: the paper grows to each bottom in turn while printing (machine px, slip is 108 x 168)
  const STEPS = [20, 32, 38, 50, 64, 76, 84, 110, 122, 128, 162, 168];
  const SLOT_Y = 286, SLIP_X = 156;             // where a slip leaves the printer (its top edge)
  const PIP_END = [.25, .3, .4];                // the PRIZE line prints over this part of a reveal (back still showing)
  const GLYPH = ['●', '◆', '★'];

  function slipHtml(api, cell, sd) { // the same lines on all 3 slips: only the PRIZE line differs
    const sp = api.receipt.spend;
    const r1 = sd ? 'STAMP DAY' : 'YOUR REWARD';  // no slip number: slips print left, right, middle
    const r3 = sd ? 'YOUR CARD IS BEHIND' : 'RECEIPT OK';
    const r4 = sd ? `<span>Free stamp</span><span>✓</span>` : `<span>SHIFT ${api.shift}</span><span>QUOTA ✓</span>`;
    const r5 = sd ? `<span>Shift ${api.shift}</span><span>✓</span>` : `<span>SPEND</span><span>€${sp} ✓</span>`;
    return `<div class="sl"><div class="h">RECEIPT REWARDS</div><div class="r1">${r1}</div><div class="ru" style="top:34px"></div>
      <div class="r3">${r3}</div><div class="ln" style="top:51px">${r4}</div><div class="ln" style="top:64px">${r5}</div>
      <div class="ru" style="top:79px"></div><div class="bc"></div><div class="no">No. ${api.shift}-0${47 + cell}-${sd ? 'S' : 'R'}</div>
      <div class="ru" style="top:124px"></div><div class="pzb"><span class="pl">PRIZE</span><span class="pz">· · ·</span></div></div>`;
  }
  // a slip's printed height at f (0..1 of its printing): one row after another, each row a quick push
  function printedH(f) {
    if (f <= 0) return 0; if (f >= 1) return STEPS[STEPS.length - 1];
    const x = f * STEPS.length, k = Math.floor(x), u = Math.min(1, (x - k) / .6), a = k ? STEPS[k - 1] : 0;
    return Math.round(a + (STEPS[k] - a) * (1 - (1 - u) * (1 - u)));
  }
  // every slip run: the main draw prints slowly; STAMP DAY's drops are quick
  function runs(api) {
    const T = api.T, out = [];
    api.tickets.forEach((k, i) => out.push({ k, i, drop: T.drops[i], rev: T.rev[i], sd: false }));
    (api.stampTickets || []).forEach((k, i) => out.push({ k, i, drop: T.sdDrops[i], rev: T.sdRev[i], sd: true }));
    return out;
  }

  LOOKS.d = {
    label: 'D coupon printer', sub: 'coupon printer',
    win: { x: 16, y: 274, w: 118, h: 150, border: 2, half: false },  // the receipt screen, left of the printer
    drawTime: 1.5, drawMsg: 'PRINTING 3 REWARDS…', holdDrawMsg: true, opener: 'flip', exitSlot: false,
    drops: T => [0, 1, 2].map(i => [T.draw + READ + SLOT[i] * GAP, DUR]),   // last slip lands 1.1 s after drawEnd
    ticketBack: (api, cell, sd) => slipHtml(api, cell, sd),

    build(api) {
      const m = api.machine, el = api.u.el;
      // the paper hanging out of the printer (one per ticket; reused for STAMP DAY)
      this.bayLab = el('div', 'dBayLab', 'YOUR REWARDS<br>PRINT HERE ▼'); m.appendChild(this.bayLab);
      // build() runs before the page makes this visit's tickets, so the pool is fixed: 3 slips + 3 for STAMP DAY
      this.slips = [0, 1, 2, 0, 1, 2].map((c, j) => { const s = el('div', 'dSlip back', slipHtml(api, c, j > 2)); s.style.display = 'none'; m.appendChild(s); return s; });
      // the printer head with its slot, tear bar and LED (above the paper)
      this.head = el('div', 'dHead', '<div class="slot"></div><div class="tear"></div><div class="led"></div><div class="nm">PRINTER</div>'); m.appendChild(this.head);
      // the roll window: paper feeds from the roll into the printer; three slip lamps count the rewards
      this.pan = el('div', 'dPan', '<div class="lab">3 REWARDS</div>'); m.appendChild(this.pan);
      const cv = document.createElement('canvas'); cv.width = 57; cv.height = 64; cv.className = 'cv'; this.pan.appendChild(cv); this.pcv = cv;
    },

    frame(api, t) {
      const T = api.T, rm = api.rm, { seg, cl, lerp, eOut } = api.u, R = runs(api);
      let printing = false, turn = 0, done = 0, filled = [];
      R.forEach(r => {
        const s = this.slips[r.i + (r.sd ? 3 : 0)]; if (!s) return;
        const [a, d] = r.drop, f = d > 0 ? (t - a) / d : 1, show = !rm && t >= a && f < 1;
        const pf = cl(f / P_END);
        if (!r.sd) { filled[r.i] = t >= a + d * P_END || (rm && t >= a); turn += pf; if (f >= P_END) done++; }
        if (!show) { s.style.display = 'none'; return; }
        s.style.display = 'block';
        if (f < P_END) { printing = true; s.style.height = printedH(pf) + 'px'; s.style.left = SLIP_X + 'px'; s.style.top = SLOT_Y + 'px'; s.style.transform = ''; s.classList.remove('torn'); return; }
        s.style.height = '168px'; s.classList.add('torn');
        if (f < TEAR_END) { const jolt = Math.floor(seg(f, P_END, TEAR_END) * 4) % 2 ? 2 : 0; s.style.left = SLIP_X + 'px'; s.style.top = SLOT_Y + jolt + 'px'; s.style.transform = ''; return; }
        // straight down the gap between the screens (x 156..264), then along the tray floor to the cell
        const q = seg(f, TEAR_END, 1), cx = api.CELL_X[r.i], fe = cx === SLIP_X ? 1 : .6;
        const qf = cl(q / fe), qs = fe < 1 ? seg(q, fe, 1) : 0;
        const x = lerp(SLIP_X, cx, eOut(qs)), y = lerp(SLOT_Y + 2, api.CELL_Y, qf * qf);
        s.style.left = Math.round(x) + 'px'; s.style.top = Math.round(y) + 'px';
        s.style.transform = qs > 0 && qs < 1 ? `rotate(${Math.sign(cx - SLIP_X) * (qs < .5 ? 2 : 1)}deg)` : '';
      });
      // the PRIZE line prints on the slip in the tray during its reveal (the back shows until the flip)
      R.forEach(r => {
        const pz = r.k.el.querySelector('.pz'); if (!pz || !r.rev) return;
        const n = r.k.p.tier + 1, rp = (t - r.rev.t0) / r.rev.d;
        const m = rp < 0 ? 0 : rm ? n : Math.min(n, Math.ceil(rp / PIP_END[r.k.p.tier] * n + 1e-6));
        const txt = m ? GLYPH[r.k.p.tier].repeat(m) : '· · ·';
        if (pz.textContent !== txt) { pz.textContent = txt; pz.className = 'pz' + (m ? ' t' + r.k.p.tier : ''); }
      });
      // head LED and the bay label
      this.head.querySelector('.led').classList.toggle('on', printing && Math.floor(t * 12) % 2 === 0);
      this.head.querySelector('.slot').classList.toggle('on', printing);
      // the roll panel (half-res): 3 slip lamps, then the roll turning while it prints
      const g = this.pcv.getContext('2d'), px = (x, y, w, h, c) => { g.fillStyle = c; g.fillRect(x, y, w, h); };
      px(0, 0, 57, 64, '#24221f');
      for (let i = 0; i < 3; i++) {
        const x = 5 + i * 17, y = 2, k = api.tickets[i], rv = T.rev[i], shownTier = k && rv && t >= rv.t0 + rv.d * .6 ? k.p.tier : -1;
        if (!filled[i]) { for (let yy = 0; yy < 18; yy += 2) { px(x, y + yy, 1, 1, '#5e574d'); px(x + 12, y + yy, 1, 1, '#5e574d'); } for (let xx = 0; xx < 13; xx += 2) { px(x + xx, y, 1, 1, '#5e574d'); px(x + xx, y + 17, 1, 1, '#5e574d'); } continue; }
        px(x, y, 13, 18, '#2b2420'); px(x + 1, y + 1, 11, 16, '#fbf7ee'); px(x + 1, y + 1, 11, 3, '#e2b33c');
        px(x + 3, y + 6, 7, 1, '#b39f78'); px(x + 3, y + 8, 5, 1, '#b39f78'); px(x + 3, y + 10, 7, 1, '#b39f78');
        if (shownTier >= 0) px(x + 4, y + 13, 5, 3, ['#8a8172', '#4f9a94', '#ffcf3f'][shownTier]);
      }
      // the roll: shrinks a little per printed slip; its spokes turn while printing
      const cx = 28, cy = 44, r0 = 15 - done * 1.5, ang = (rm ? 0 : turn * Math.PI * 2.5) + .5;
      for (let y = -17; y <= 17; y++) for (let x = -17; x <= 17; x++) {
        const d = Math.hypot(x + .5, y + .5); if (d > r0 + 1) continue;
        px(cx + x, cy + y, 1, 1, d > r0 ? '#2b2420' : d < 4 ? '#2b2420' : d < 5 ? '#8a8172' : (Math.floor(d) % 3 === 0 ? '#ddcba5' : '#f3e9d2'));
      }
      for (let s = 0; s < 3; s++) { const a = ang + s * Math.PI * 2 / 3; for (let rr = 6; rr < r0 - 1; rr += 1) px(Math.round(cx + Math.cos(a) * rr), Math.round(cy + Math.sin(a) * rr), 1, 1, '#b39f78'); }
      // paper leaves the top of the roll to the left, into the printer; dashes travel while printing
      const ty = Math.round(cy - r0) - 1; px(0, ty, cx, 2, '#f3e9d2'); px(0, ty - 1, cx, 1, '#2b2420'); px(0, ty + 2, cx, 1, '#2b2420');
      const off = rm ? 0 : Math.floor(turn * 40) % 4; for (let x = cx - 2 - off; x > 0; x -= 4) px(x, ty, 1, 2, '#b39f78');
    },

    paint(api, g, t) { // the basket screen (full res, drawn on a 2 px grid; text as on look B's screen)
      const T = api.T, rm = api.rm, W = api.win.width, H = api.win.height, { seg, cl } = api.u;
      const px = (x, y, w, h, c) => { g.fillStyle = c; g.fillRect(Math.round(x), Math.round(y), Math.round(w), Math.round(h)); };
      px(0, 0, W, H, '#24221f'); for (let y = 0; y < H; y += 4) px(0, y, W, 1, '#2b2420');
      px(0, 0, W, 16, '#2a4d4b'); px(0, 16, W, 2, '#1f3b3a');
      g.textBaseline = 'alphabetic'; g.textAlign = 'center'; g.font = '12px Pixelify'; g.fillStyle = '#f1d27a'; g.fillText('YOUR RECEIPT', W / 2, 13);
      const L = basket(api.receipt.spend), rows = L.length + 1, y0 = 22, pitch = 13;
      // feed: lines arrive with the receipt, then each line gets its check, then SPEND; all before the chute choice
      const shown = t < T.flyEnd ? 0 : rm ? rows : Math.ceil(seg(t, T.flyEnd, T.feedEnd) * rows);
      const readEnd = T.readEnd, ticked = t < T.feedEnd ? 0 : rm || t >= readEnd ? rows : Math.floor(seg(t, T.feedEnd, readEnd) * rows);
      if (!shown) {
        g.font = '700 10px Atkinson'; g.fillStyle = '#7a5a1c'; g.fillText(t < T.fly ? 'waiting for' : 'receipt', W / 2, 62); g.fillText(t < T.fly ? 'your receipt' : 'coming in…', W / 2, 75);
        if (Math.floor(t * 2) % 2 === 0) px(W / 2 - 4, 84, 8, 10, '#b38425');
      }
      g.font = '10px JBMono';
      for (let i = 0; i < Math.min(shown, rows); i++) {
        const last = i === rows - 1, y = y0 + i * pitch + (last ? 4 : 0), ok = i < ticked, cur = !rm && i === ticked && t >= T.feedEnd && t < readEnd;
        if (last) px(4, y - 2, W - 8, 2, '#5e574d');
        if (cur) px(2, y, W - 4, pitch - 1, '#3a7672');
        const [nm, v] = last ? ['SPEND', api.receipt.spend] : L[i];
        g.textAlign = 'left'; g.fillStyle = ok ? '#f1d27a' : cur ? '#fbf7ee' : '#b38425'; g.fillText(nm, 6, y + 10);
        g.textAlign = 'right'; g.fillText('€' + v, W - 18, y + 10);
        if (ok) { const cx = W - 12, cy = y + 6; px(cx - 3, cy, 2, 2, '#5fae5a'); px(cx - 1, cy + 2, 2, 2, '#5fae5a'); px(cx + 1, cy - 2, 2, 4, '#5fae5a'); px(cx + 3, cy - 4, 2, 2, '#5fae5a'); }
      }
      // the footer: what the machine is doing
      const fy = H - 20; px(0, fy, W, 20, '#1f3b3a'); px(0, fy, W, 2, '#2b2420');
      let foot = '', col = '#f1d27a';
      const landed = api.tickets.filter((k, i) => t >= T.drops[i][0] + T.drops[i][1]).length;
      const printingNo = T.drops.findIndex(([a, d]) => t >= a && t < a + d * P_END);
      if (t < T.feedEnd) foot = '';
      else if (t < readEnd) foot = Math.floor(t * 6) % 2 ? 'CHECKING…' : 'CHECKING';
      else if (t < T.draw) foot = 'RECEIPT OK ✓';
      else if (printingNo >= 0) foot = `PRINTING ${SLOT[printingNo] + 1}/3`;
      else if (landed === 0 && !T.drops.some(([a]) => t >= a)) foot = rm ? 'DRAWING…' : Math.floor(t * 6) % 2 ? 'DRAWING…' : 'DRAWING';
      else if (landed < api.tickets.length) foot = rm ? 'PRINTING…' : 'TEAR OFF ▼';
      else { foot = 'THANK YOU!'; const rv = api.reveal(t); if (rv && rv.tier === 2 && !rm && Math.floor(t * 8) % 2) col = '#ffcf3f'; else if (rv && rv.tier === 2) col = '#fbf7ee'; }
      g.textAlign = 'center'; g.font = '12px Pixelify'; g.fillStyle = col; g.fillText(foot, W / 2, fy + 15);
    },

    sounds(api) {
      const T = api.T, rm = api.rm, ev = [];
      // receipt check (before the chute choice): one scanner beep per line
      const n = 7, readEnd = T.readEnd;
      if (rm) ev.push([T.feedEnd, () => api.tone(1800, .05, 'square', .03)]);
      else for (let i = 0; i < n; i++) ev.push([T.feedEnd + (i + .5) * (readEnd - T.feedEnd) / n, () => api.tone(i === n - 1 ? 2200 : 1800, .03, 'square', .03)]);
      // each slip: a print tick per row, then the tear
      const slip = ([a, d]) => {
        if (rm) { ev.push([a, () => api.noise(.06, .05)]); return; }
        STEPS.forEach((_, j) => ev.push([a + d * P_END * j / STEPS.length, () => api.noise(.015, .03)]));
        ev.push([a + d * P_END, () => { api.noise(.06, .07); api.tone(260, .04, 'square', .03); }]);
      };
      T.drops.forEach(slip); (T.sdDrops || []).forEach(slip);
      // the PRIZE line prints during each reveal: one tick per glyph
      const pr = (list, R) => (list || []).forEach((k, i) => { const r = R && R[i]; if (!r) return; const m = k.p.tier + 1;
        for (let j = 0; j < m; j++) ev.push([r.t0 + (rm ? 0 : r.d * PIP_END[k.p.tier] * j / m), () => api.noise(.02, .04)]); });
      pr(api.tickets, T.rev); pr(api.stampTickets, T.sdRev);
      return ev;
    },
  };
})();
