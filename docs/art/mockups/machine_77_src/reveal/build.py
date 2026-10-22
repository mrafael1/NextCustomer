"""Builds docs/art/mockups/machine_77_reveals.html from reveal_template.html: embeds the game's
real sprites (art/*.png, read-only) as data URIs so the page is self-contained. #77 prep.
Run: python docs/art/mockups/machine_77_src/reveal/build.py"""
import base64, json, pathlib
HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[4]
SPRITES = {
    'banana': 'art/items_v2/banana.png', 'milk': 'art/items_v2/milk.png', 'eggs': 'art/items_v2/eggs.png',
    'coffee': 'art/items_v2/coffee.png', 'cheese': 'art/items_v2/cheese.png', 'tea_bags': 'art/items_v2/tea_bags.png',
    'croissant': 'art/items_v2/croissant.png', 'strawberries': 'art/items_v2/strawberries.png',
    'crisps': 'art/items_v2/crisps.png', 'batteries': 'art/items_v2/batteries.png',
    'coupon_slip': 'art/items_v2/coupon_slip.png', 'multipack': 'art/icons/coupon_multipack_v2.png',
    'two_for_one': 'art/icons/coupon_two_for_one_v2.png', 'sparkle': 'art/effects/sparkle.png',
    'stamp_ring': 'art/icons/stamp_ring.png', 'loyalty_card': 'art/frames/loyalty_card.png',
}
# BIG and GOLDEN tiers: the upgrades page's generated PNGs (machine_77_src/upgrades/png), so both pages show the same art
UPG = 'docs/art/mockups/machine_77_src/upgrades/png/items_v2/'
for item in ('banana', 'milk', 'eggs', 'coffee'):
    SPRITES[item] = f'{UPG}{item}.png'  # plain too: round 2 redrew Banana and Eggs there (the flow page reads the same files)
    for tier in ('big', 'golden'):
        SPRITES[f'{item}_{tier}'] = f'{UPG}{item}_{tier}.png'
data = {k: 'data:image/png;base64,' + base64.b64encode((ROOT / v).read_bytes()).decode() for k, v in SPRITES.items()}
tpl = (HERE / 'reveal_template.html').read_text(encoding='utf-8')
# DRAW 3 and its odds run the one draw process (flow/draw77.js on flow/flow_data.json; run flow/gen_flow.py first)
FLOW = HERE.parent / 'flow'
out = tpl.replace('/*SPRITES*/{}', json.dumps(data)).replace('/*DRAW77*/', (FLOW / 'draw77.js').read_text(encoding='utf-8'))
out = out.replace('/*DATA*/{}', (FLOW / 'flow_data.json').read_text(encoding='utf-8'))
(ROOT / 'docs/art/mockups/machine_77_reveals.html').write_text(out, encoding='utf-8', newline='\n')
print('wrote machine_77_reveals.html', len(out))
