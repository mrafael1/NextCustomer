# Run by build_pages.py (names HERE, MOCK, img, tier_js are given): builds machine_77_upgrades_bay.html from the approved
# planning-effects page (planning_effects_h1.html, mirrored B2, #71) with the belt row swapped for upgraded items.
import json

src = (MOCK / "planning_effects_h1.html").read_text(encoding="utf-8")


def sub(text, old, new, count=1):
    assert text.count(old) >= 1, old[:80]
    return text.replace(old, new, count)


s = src
s = sub(s, "<title>Planning effects h1</title>", """<title>Upgrades in the bay</title>
<!--
  #77 PREP, ITEM UPGRADES IN THE BAY (2026-10-20). Built by machine_77_src/upgrades/build_pages.py + bay_patch.py from
  planning_effects_h1.html (the approved #71 planning look on the mirrored B2 screen); only the row, the top bar, the monitor,
  the receipt change. Shift 4/8 is the first shift after an UPGRADES visit (it opens after shifts 3, 5, 7), so the
  state is one a run can reach (BRIEF 2.1-2.2): after shift 1 NEW ITEMS rolled a Rare (a 3rd Eggs that arrives BIG; cart
  13 -> 14), after shift 2 REGISTER (1 LOYALTY stamp, Coupon engine), after shift 3 UPGRADES rolled a Rare (one Milk,
  plain -> GOLDEN). Two upgraded copies, the other copies plain.
  Row (slot 1 next to the register): Eggs BIG, Milk GOLDEN, Coffee, Milk, Banana, Banana, an empty coupon slot.
  Pays are worked by hand from today's rules with the brief's placeholder tier numbers (BIG: price +2; GOLDEN Milk +2 per
  earlier Breakfast): 3 + 16 + 2 + 10 + 2 + 4 = EUR 37 against EUR 61. Hovering a row item steps a shine across it.
  The tier tag hangs under the ticket's left end: the top left is the rail strip's badge, the top right the pay starburst. Query: ?grey=1, ?still=1.
-->""")
# the tier helpers and the sprites, before the scene script
s = sub(s, "<script>\nconst A = 'assets/art/';",
        "<script>\n" + tier_js + "\nconst U = " + json.dumps(img) + ";\n"
        "{ const q = new URLSearchParams(location.search); if (q.get('grey') === '1') document.documentElement.style.filter = 'grayscale(1)';"
        " if (q.get('still') === '1') document.addEventListener('DOMContentLoaded', () => document.body.classList.add('still')); }\n"
        "{ const st = document.createElement('style'); st.textContent = TIER_CSS; document.head.appendChild(st); }\n"
        "</script>\n<script>\nconst A = 'assets/art/';")
# top bar: shift 4/8, quota EUR 61, projected EUR 47; no inspection on shift 4; one register stamp (after shift 2)
s = sub(s, '<span class="k">SHIFT</span><span class="v">5/8</span>', '<span class="k">SHIFT</span><span class="v">4/8</span>')
s = sub(s, '<span class="v">€73</span><span class="bar"><i style="width:100%"></i></span><span class="v" style="color:var(--mustard-light)">€182</span>',
        '<span class="v">€61</span><span class="bar"><i style="width:61%"></i></span><span class="v" style="color:var(--mustard-light)">€37</span>')
a = s.index('  <div class="chip warn">')
b = s.index('</div>', s.index('Inspection · 3rd product pays €0')) + len('</div>')
s = s[:a] + s[b + 1:]
s = sub(s, '<span class="stamp" title="Slot engine"><canvas class="px" data-glyph="slot" width="13" height="13"></canvas></span><span class="stamp" title="Category engine"><canvas class="px" data-glyph="tag" width="13" height="13"></canvas></span>',
        '<span class="stamp"><canvas class="px" data-glyph="empty" width="13" height="13"></canvas></span>')
# monitor: the calm brief, with a key to the tier tags instead of the inspection
s = sub(s, """    <div class="bt"><span>SHIFT 5/8</span><span>QUOTA €73</span></div>
    <div class="bk">INSPECTION</div>
    <div class="bn">Spot check</div>
    <div class="bd2">The 3rd product pays €0</div>""", """    <div class="bt"><span>SHIFT 4/8</span><span>QUOTA €61</span></div>
    <div class="bk">NO INSPECTION · HOW THIS CART GOT ITS UPGRADES</div>
    <div class="bd2" style="margin-top:6px;font-size:12px">After 1 · NEW ITEMS (Rare): a 3rd Eggs, already BIG</div>
    <div class="bd2" style="font-size:12px">After 2 · REGISTER · After 3 · UPGRADES (Rare): Milk GOLDEN</div>""")
s = sub(s, 'Cart <span class="num" style="margin-left:6px">13/15</span>', 'Cart <span class="num" style="margin-left:6px">14/15</span>')
# receipt
a = s.index('    <div class="ln"><span class="nm">Eggs</span>')
b = s.index('    <div class="sum" style="margin-top:3px">')
b = s.index('</div>', b) + len('</div>\n')
ok = '<span class="pl" style="color:var(--good);font-weight:700">✓</span>'
lines = [("Eggs BIG", "€3.00", ""), ("Milk GOLDEN", "€16.00", ok), ("Coffee", "€2.00", ""), ("Milk", "€10.00", ok),
         ("Banana", "€2.00", ""), ("Banana", "€4.00", ok)]
rec = "".join(f'    <div class="ln"><span class="nm">{n}</span><span>{v}</span>{p or "<span class=pl></span>"}</div>\n' for n, v, p in lines)
rec += """    <div class="dash"></div>
    <div class="ln"><span class="nm" style="font-family:Pixelify;font-size:15px">PROJECTED</span><span class="num" style="font-size:18px">€37.00</span><span class="pl"></span></div>
    <div class="sum" style="margin-top:3px;color:var(--ink-light)">€24 to quota<span class="hint"> · hover an item</span></div>
"""
s = s[:a] + rec + s[b:]
s = sub(s, '<div class="h">SHIFT <span class="num">5/8</span> · <span class="num">7</span> ITEMS</div>',
        '<div class="h">SHIFT <span class="num">4/8</span> · <span class="num">6</span> ITEMS</div>')
# the hand stays as in h1 (plain cards only)
s = sub(s, "  item(`${A}items_v2/${n}.png`, HXI(7 - i),", "  item(U[n] || `${A}items_v2/${n}.png`, HXI(7 - i),")

# the row: everything from the h1 row on is replaced
a = s.index("// ================= the row (slot 1 next to the register) =================")
b = s.index("})();\n\n</script>\n</body>")
row = r"""// ================= the row (slot 1 next to the register): #77 upgrades =================
const other = [], dimItems = [];
const UPB = t => `<span class="up">${t}</span>`;
// a ticket with its tier: GOLDEN gets the double rim, BIG/GOLDEN get the price rise boxed (as on the grid page) and the tag
function tierTicket(k, tier, o) {
  const t = ticket(k, o); if (tier === 2) t.classList.add('t2');
  if (tier) t.querySelector('.p').firstElementChild.insertAdjacentHTML('afterend', `<span class="priceup" style="margin-left:2px">+${o.up}</span>`);
  const tag = tierTag(tier); if (tag) { Object.assign(tag.style, { left: (SL(k) - 6) + 'px', top: (TT + 58) + 'px' }); stage.appendChild(tag); }
  return t;
}
const glint = (d, src) => tierGlint(d, src);
// 1 Eggs BIG (from NEW ITEMS after shift 1): pays its base 3, doubles the next Food (Milk GOLDEN)
glint(itemD(1, U.eggs_big), U.eggs_big);
// 2 Milk GOLDEN (from UPGRADES after shift 3): base 6, +2 per earlier Breakfast (Eggs) = +2, x2 from Eggs = EUR 16
glint(itemD(2, U.milk_golden, { lift: L, cls: 'h1' }), U.milk_golden);
stack(2, [['add', '+2', null], ['mul', '×2', 'eggs']]);
tierSparkles(stage, [[SL(2) + 12, G - 96 - L + 14], [SL(2) + 84, G - 96 - L + 44]]);
// 3 Coffee: pays its base, gives +3 to the next Breakfast (Milk)
glint(itemD(3, U.coffee), U.coffee);
// 4 Milk: base 4, +1 per earlier Breakfast (Eggs, Milk, Coffee) = +3, +3 from Coffee = EUR 10
glint(itemD(4, U.milk, { lift: L, cls: 'h1' }), U.milk);
stack(4, [['add', '+3', null], ['add', '+3', null]]);
// 5 Banana: base 2, no Banana before it (Milk) = EUR 2
glint(itemD(5, U.banana), U.banana);
// 6 Banana: base 2, +2 right after a Banana = EUR 4
glint(itemD(6, U.banana, { lift: L, cls: 'h1' }), U.banana);
stack(6, [['add', '+2', null]]);
// 7: the coupon slot, empty
el('label empty', { left: SL(7) + 'px', top: TT + 'px', zIndex: 4 }, '');

tierTicket(1, 1, { price: '€3', up: 2, rule: '×2 next Food' });
tierTicket(2, 2, { price: '€6', up: 2, rule: `${UPB('+2')} per earlier Breakfast`, strike: true });
tierTicket(3, 0, { price: '€2', rule: '+3 next Breakfast' });
tierTicket(4, 0, { price: '€4', rule: '+1 per earlier Breakfast', strike: true });
tierTicket(5, 0, { price: '€2', rule: '+2 after Banana' });
tierTicket(6, 0, { price: '€2', rule: '+2 after Banana', strike: true });
burst(2, '€16', { w: 60, h: 32 });
burst(4, '€10', { w: 56, h: 30, fs: 18 });
burst(6, '€4', { w: 50, h: 28, fs: 17, up: 4 });

strip(1, [2], '×2', 'EGGS');
strip(3, [4], '+3', 'COFFEE');

// calm monitor: a key to the tier tags
const lg = document.getElementById('legend');
if (lg) {
  const add = (tier, text) => { const w = el('lg', { position: 'relative' }, '', lg);
    const tg = tierTag(tier); tg.style.position = 'relative'; w.appendChild(tg);
    w.insertAdjacentHTML('beforeend', `<span>${text}</span>`); };
  add(1, 'bigger pack: price +2');
  add(2, 'a stronger effect');
}
"""
s = s[:a] + row + s[b:]
(MOCK / "machine_77_upgrades_bay.html").write_text(s, encoding="utf-8")
print("wrote machine_77_upgrades_bay.html", len(s))
