# Machine looks for the #77 flow page

`machine_77_flow.html` plays one whole machine visit: receipt feed, chute choice, odds card, draw, 3 drops,
rarity reveals, pick, landing, REGULAR punch, STAMP DAY. A **look** changes only what the machine looks like and
how it draws. Everything else is shared and stays the same in every look: the timeline outside the draw, the odds
card, the rarity reveals, the cart drawer, the punch ticket, the cursor and the sounds of the shared steps.

Add a look without touching the template:

1. Write `look_<key>.js`, and optionally `look_<key>.css`, in this folder. `<key>` is a short lowercase id
   (`d`, `e`, `wheel`...). It must not be `a`, `b` or `c`, which are built in, and it must not be another
   agent's key.
2. Run `python ../gen_flow.py`. It inlines every `look_*.js` in its own `<script>` (so one broken look can't
   stop the page) and every `look_*.css` at the end of the page's `<style>`, sorted by file name.
3. Open `machine_77_flow.html?look=<key>`. The MACHINE LOOK buttons list the chosen look F first ("chosen", decided in round 3), then the other looks: D, E, A, B, C, then any other key. Without `?look=` the page opens on F.

Never edit `flow_template.html`, `draw77.js` or another look's files. The reference implementations are the
built-in looks `LOOKS.a` (prize drum), `LOOKS.b` (scratch & win) and `LOOKS.c` (price drop) in
`flow_template.html`; search for `LOOKS.a = {`.

## The contract

A look file registers one object:

```js
window.LOOKS = window.LOOKS || {};
LOOKS.d = {
  // ---- required
  label: 'D ticket wheel',      // the MACHINE LOOK button (HTML allowed: &amp;)
  sub: 'ticket wheel',          // the small line under RECEIPT REWARDS on the machine's head
  win: { x: 90, y: 272, w: 240, h: 150, border: 2, half: true },
                                // the draw window in machine px (see Layout). half: true = the canvas is
                                // (w - 2*border)/2 x (h - 2*border)/2 and shown at 2x, so 1 canvas px = 1 art px.
                                // half: false = full resolution (use it for text, like look B's screen)
  paint(api, g, t) {},          // paint the window every frame. g = api.win's 2d context. Must be a pure
                                // function of t: the page scrubs, jumps (?at=) and replays.

  // ---- optional
  drawTime: 1.8,                // seconds of draw at 1x (default 1.8). Reduced motion forces 0.3.
  drops(T) { return [[T.drawEnd, .5], [T.drawEnd + .3, .5], [T.drawEnd + .6, .5]]; },
                                // the 3 drops as [start, duration] in timeline seconds (default: A's, shown
                                // here). A drop may start during the draw (look C). Not called under reduced
                                // motion: the page then uses [drawEnd + i*0.1, 0.05].
  drawMsg: 'GOOD LUCK!',        // the display text during the draw
  holdDrawMsg: false,           // true: keep drawMsg on the display until the last drop lands (for looks whose
                                // drops run past T.drawEnd, D and F), so '3 PRIZES FROM …' never runs ahead
  opener: 'flip',               // 'flip' (the card turns over, A and C) or 'scratch' (a coin wipes the back
                                // away left to right, B). The reveal after it is shared and fixed.
  exitSlot: true,               // the dark slot above the tray (default true)
  ticketBack(api, cell, isStampDay) { return '<div class="bt">RECEIPT REWARDS</div>'; },
                                // inner HTML of a ticket back (.back, 108 x 168). Style it as `.look-d .back`.
  tokenPos(api, cell, p) { return { x, y, h }; },
                                // where the falling token is during a drop: p goes 0 to 1 (linear; ease it
                                // yourself). x = token centre, y = token top, machine px; h (optional) sets its
                                // height. Omit tokenPos and no token shows: tickets appear when they land.
  tokenW: 26,                   // the token's width, used to centre it (style it as `.look-d .token`)
  build(api) {},                // add your own DOM into api.machine (bulbs, a wheel, signage). Runs on every
                                // restart, after the shared parts exist. `this` is your look object.
  frame(api, t) {},             // update your own DOM every frame (pure function of t)
  sounds(api) { return [[api.T.draw + .2, () => api.tone(880, .05, 'square', .04)]]; },
                                // sound events at timeline seconds; the page fires them when the clock passes
                                // them, only while SOUND is on
};
```

### Round 3: the BONUS TICKET (a second visit in one shift)

With `?inspection=` on (the default at shifts 3, 5 and 7), a second visit follows the first pick: the head stamps
BONUS TICKET, a stub feeds in, and the player chooses a chute, sees the odds, draws, reveals, picks and lands again.
A look needs nothing new for it. From `T.bonus.start` on, the page sets the api to the second visit around every
`paint`, `frame` and `sounds` call: `api.T` is that visit's timeline (the same field names, all absolute seconds:
`start tear fly flyEnd feedEnd readEnd lights hover press draw drawEnd drops rev curPick pickPress bin fly2 land xf
xfEnd punch punchEnd end`), `api.prizes`, `api.tickets`, `api.st` and `api.odds()` are that visit's, and
`api.stampDay` is `null`. `api.visit` is 0 or 1, and `api.bonus` is `{name, rule, key}` of the inspection passed, or
`null`. `build` runs once, with visit 0, so text written in `build` that depends on the chute must be refreshed in
`frame` (look F's ORDER slip does this). The second draw lasts `bonusDrawTime` (optional, default
`min(1.2, drawTime)`), and `drops(T)` is called again with the second timeline. `api.phase(t)` returns `bonus` while
the stub feeds.

### Timing rules

- All times are **timeline seconds at 1x**. The page's clock runs at the SPEED setting (0.75x / 1x / 1.25x), so
  a look never reads the speed to scale its own motion. `api.speed` exists for display only.
- 1x is the decided tempo. Keep the draw at 2.0 s or less, and the last drop landing at most 1.5 s after
  `T.drawEnd` (round 1's looks: A 1.8 s + 1.1 s, B 1.8 s + 1.6 s, C 0.5 s with drops running from `T.draw + 0.3`).
- Reduced motion (`api.rm`): the draw lasts 0.3 s and drops are instant. `paint` and `frame` must still show a
  sensible still: no spinning, no chasing lights, the end state of the draw.

### What the look must animate

1. **Idle / feed** (`t < T.readEnd`): the window at rest. It may react to the receipt (B shows a barcode scan).
2. **Chute choice and odds** (`T.readEnd` to `T.draw`): the window at rest, lights may idle.
3. **The draw** (`T.draw` to `T.drawEnd`): the look's signature motion (A: the drum spins and bulbs chase).
4. **The drops** (`T.drops`): 3 prizes leave the machine into the tray cells. The page shows each ticket, face
   down, at the end of its drop (`start + duration`) with a small bounce. Use `tokenPos` and/or `paint` for the
   travel.
5. Nothing after that is the look's: the page opens the tickets (`opener`), plays the rarity reveals, the pick,
   the cart drawer and the punch. A look may still react in `frame` (for example, flash lights during a
   LEGENDARY reveal, using `api.reveal(t)`).

### Layout (machine px; the machine sits at stage x 760, y 70 and is 420 x 630)

| Part | Where | Notes |
|---|---|---|
| head `.head` | x -10..430, y -8..46 | `.t` RECEIPT REWARDS, `.s` your `sub`, `.sd` the STAMP DAY stamp |
| receipt slot `.slotPlate` | x 14..406, y 54..96 | `.mouth` at x 144..248; `.lamp`; `.scanbar` (hidden) |
| display `.disp` | x 14..406, y 100..152 | the page writes the messages; style its colours only |
| chute keys `.chute` | y 160..234, x 14 / 114 / 214 / 314, 92 wide | states `.lit` `.dim` `.hov` `.sunk`, `.lock`, `.full` |
| punch tickets `.reg` | y 240..270 | decided look (Q4 A); recolour only |
| free for the window | y 272..440 | A uses x 90..330 with bulbs at its sides; B x 30..390; C x 40..380, y 270..438 |
| exit slot `.exitSlot` | x 150..270, y 426..438 | turn it off with `exitSlot: false` |
| tray `.tray` | x 10..410, y 444..624 | ticket cells at `api.CELL_X` = 26 / 156 / 286, `api.CELL_Y` = 452, 108 x 168 |

The shared parts have no colours of their own, so a look styles them all (start from look A's `.look-a …` rules
in `flow_template.html`). Scope the CSS to your look: `#machine` gets the class `look-<key>`, so write
`.look-d .cab`, `.look-d .head`, `.look-d .slotPlate`, `.look-d .disp`, `.look-d .chute`, `.look-d .chute.lit`,
`.look-d .win`, `.look-d .tray`, `.look-d .back`, `.look-d .token`. Use the page's palette variables (`--ink`,
`--paper`, `--cream`, `--teal…`, `--mus…`, `--gold`, `--brass…`, `--tom…`, `--steel…`, `--wood…`, `--velvet…`).
Pixel rules: 2 px art pixels, a 2 px ink outline (`--ink`), no gradients except stepped stripes, no blur.

### The api object

| Member | What it gives |
|---|---|
| `api.T` | the timeline: `tear fly flyEnd feedEnd readEnd lights hover press draw drawEnd drops rev fly2 land punch punchEnd end`, and with STAMP DAY `sd sdDrops sdRev sdLand` (`rev` / `sdRev`: `[{t0, d}]` per ticket) |
| `api.rm`, `api.speed`, `api.shift` | reduced motion, speed (display only), the shift just passed |
| `api.st` | the visit's state: `chute` (`new` `coupons` `register` `upgrades`), `lvl` (REGULAR 0..3), `owned`, `levels`, `stock`, `cart`, `upOpen`, `full` |
| `api.prizes` | the 3 prizes in tray order (rarest last): `{kind, id, tier}`, tier 0 COMMON, 1 RARE, 2 LEGENDARY |
| `api.stampDay` | STAMP DAY's 3 register prizes, or `null` |
| `api.tickets`, `api.stampTickets` | per ticket `{p, cell, el, tokPos}`; `tokPos` = `[x, y]` while its token falls, else `null` |
| `api.info(p)` | a prize's texts and art: `name`, `line`, `spr()` (a 48 x 48 canvas), `home` |
| `api.receipt` | `{spend, quota, inspect}` of the passed shift |
| `api.odds()` | the exact odds of this draw: `share[t]` (per drop), `first`, `rest`, `pR` (at least one RARE+), `pL`, `inDraw[key]` |
| `api.oddsTable` | the odds per REGULAR level, `[[75, 22, 3], …]` |
| `api.reveal(t)` | the reveal playing at `t`: `{i, tier, p, stampDay}` (`p` 0..1), or `null` |
| `api.phase(t)` | `feed` `choose` `odds` `draw` `drop` `reveal` `pick` `land` `punch` `stampday` `end` |
| `api.machine`, `api.win`, `api.W`, `api.display`, `api.chutes`, `api.tray` | the machine root, the window canvas and its rect (your `win`), the display, the 4 chute keys by id, the tray |
| `api.CELL_X`, `api.CELL_Y`, `api.MX`, `api.MY`, `api.TIER` | tray cells; the machine's stage offset; tier names |
| `api.u` | helpers: `seg(t, a, b)` (0..1), `sm`, `eOut`, `eInOut3`, `lerp`, `cl`, `el(tag, cls, html)`, `img(name, scale)`, `gridCanvas(rows, pal, scale)`, `mulberry(seed)`, `PAL` |
| `api.ASSET`, `api.IMG` | the inlined sprites (data URIs, loaded images): `cart`, `stamp_ring`, `sparkle`, `coupon_slip`, the item sprites… |
| `api.tone(f, d, type, vol, at)`, `api.noise(d, vol, at)`, `api.NOTE` | placeholder WebAudio sounds (#62's CC0 set replaces them in the game) |

## A tiny example look

`look_z.js`:

```js
window.LOOKS = window.LOOKS || {};
LOOKS.z = {
  label: 'Z test card', sub: 'test card',
  win: { x: 90, y: 272, w: 240, h: 150, border: 2, half: true },
  drawTime: 1.2, drawMsg: 'SHUFFLING…',
  ticketBack: () => '<div class="bt">TEST CARD</div>',
  tokenW: 26,
  tokenPos(api, cell, p) { // straight down out of the window, then across to the cell
    const cx = api.CELL_X[cell] + 54, q = api.u.sm(p);
    return { x: api.u.lerp(210, cx, q), y: api.u.lerp(420, api.CELL_Y + 70, q) };
  },
  paint(api, g, t) { // three bars that flicker during the draw
    const W = api.win.width, H = api.win.height, T = api.T;
    g.fillStyle = '#24221f'; g.fillRect(0, 0, W, H);
    const busy = !api.rm && t >= T.draw && t < T.drawEnd;
    ['#d9534f', '#e2b33c', '#4f9a94'].forEach((c, i) => {
      g.fillStyle = busy && Math.floor(t * 12 + i) % 2 ? '#fbf7ee' : c;
      g.fillRect(10 + i * 38, 14, 30, H - 28);
    });
  },
  sounds(api) { return [[api.T.draw, () => api.tone(api.NOTE.C5, .2, 'square', .04)]]; },
};
```

`look_z.css`:

```css
.look-z .cab { background: var(--slate); }
.look-z .head { background: var(--paper); color: var(--ink); }
.look-z .slotPlate { background: var(--cream); color: var(--inkL); }
.look-z .chute { background: var(--cream); color: var(--ink); box-shadow: inset 0 -5px 0 var(--creamS), 0 4px 0 var(--ink); }
.look-z .chute.lit { background: var(--paper); }
.look-z .win { background: var(--char); }
.look-z .tray { background: var(--slateD); }
.look-z .back { background: var(--cream); border: 2px solid var(--ink); }
.look-z .token { width: 26px; height: 34px; background: var(--paper); }
```

## Checklist before handing a look over

- `python ../gen_flow.py`, then open the page with `?look=<key>` at shifts 2, 3 and 7 and every chute. Check
  0.75x, 1x and 1.25x, and REDUCED MOTION.
- Stills: `?look=<key>&at=<s>` freezes the page at `s` seconds (add `&tl=1` to print the timeline under the
  page). Capture the draw, the drops and a LEGENDARY reveal.
- Open the browser console: no errors. A look file that throws while loading never registers, so `?look=<key>`
  falls back to the default look (D, or A if D is missing). An error inside `paint` or `frame` is logged once and that part stops drawing.
- Your files only: `look_<key>.js`, `look_<key>.css`. Nothing else in `flow/`.
