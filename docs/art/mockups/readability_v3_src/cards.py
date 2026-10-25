"""Writes cards.js: every stocked card (base tiers) with its short and long text from data/cards and the
ticket colour picked by the v3 defaults (python cards.py; build.py then embeds cards.js in the page).

Colour rule: the rule names a family -> that family; names a product -> that product's main family; names nothing
(or a penalty, or coupons) -> its own main family; coupons with no family -> the plain coupon ticket."""
import glob, json, os, re, pathlib
HERE = pathlib.Path(__file__).resolve().parent
CARDS_DIR = HERE.parents[3] / "data" / "cards"
D = {}
for f in sorted(glob.glob(str(CARDS_DIR / "*.tres"))):
    k = os.path.basename(f)[:-5]
    if k.endswith("_big") or k.endswith("_golden"): continue
    s = open(f, encoding="utf-8").read(); res = s.split("[resource]")[1]
    g = lambda key: (re.search(r"^" + key + r" = (.*)$", res, re.M) or [None, None])[1]
    params = {}
    for sub in re.findall(r"\[sub_resource[^\]]*\]\n(.*?)(?=\n\[|\Z)", s, re.S):
        for a, b in re.findall(r"^(\w+) = (.*)$", sub, re.M):
            if a != "script": params.setdefault(a, b.strip("\"&"))
    st = (g("sticker_text") or "\"\"").strip("\"")
    D[k] = dict(name=(g("display_name") or "").strip("\""), kind=g("kind"), base=g("base"), tags=re.findall(r"\"([^\"]+)\"", g("tags") or ""),
                rule=(g("rule_text") or "").strip("\""), sticker_filled=re.sub(r"\{(\w+)\}", lambda m: params.get(m.group(1), "{" + m.group(1) + "}"), st))

SRC={}
for i in 'banana bread milk eggs coffee soup'.split(): SRC[i]='Staple'
for i in 'cheese frozen_peas butter yogurt reduced_yogurt'.split(): SRC[i]='Cold cases'
for i in 'cream ham_ends'.split(): SRC[i]='Cold cases capsule'
for i in 'cereal tea_bags crackers dented_can day_old_buns'.split(): SRC[i]='Pantry'
for i in 'sugar_cubes mixed_herbs'.split(): SRC[i]='Pantry capsule'
for i in 'carrier_bag scissors batteries flickering_bulb'.split(): SRC[i]='Household'
for i in 'egg_timer chipped_mug odd_socks'.split(): SRC[i]='Household capsule'
for i in 'fruit_salad strawberries grapefruit wonky_carrot lemon bruised_apples soft_tomatoes potatoes'.split(): SRC[i]='Fruit & veg capsule'
for i in 'baguette scone croissant broken_biscuit iced_bun birthday_candles squashed_cake stale_doughnut'.split(): SRC[i]='Bakery capsule'
for i in 'crisps cereal_bar bent_lolly pick_n_mix stale_popcorn breadsticks dusty_toffees'.split(): SRC[i]='Snacks capsule'
for i in 'breakfast_sticker multipack two_for_one'.split(): SRC[i]='Coupon, first offer'
for i in 'clearance_tag shelf_swap repeat opening_deal'.split(): SRC[i]='Coupon'
SRC['final_markdown']='Coupon, starter deck'
TGT=dict(banana='S',bread='-',milk='T:Breakfast',eggs='T:Food',coffee='T:Breakfast',soup='P:Frozen',cheese='C:bread',frozen_peas='T:Frozen',butter='T:Bakery',yogurt='C:banana',reduced_yogurt='T:Clearance',cream='T:Dairy',ham_ends='T:Dairy',cereal='C:milk',tea_bags='T:Breakfast',crackers='C:soup',dented_can='T:Clearance',day_old_buns='T:Clearance',sugar_cubes='C:coffee',mixed_herbs='T:Food',carrier_bag='T:Food',scissors='X:coupon',batteries='-',flickering_bulb='T:Clearance',egg_timer='C:eggs',chipped_mug='C:coffee',odd_socks='T:Household',fruit_salad='T:Produce',strawberries='T:Produce',grapefruit='T:Produce',wonky_carrot='T:Produce',lemon='T:Produce',bruised_apples='T:Clearance',soft_tomatoes='C:soup',potatoes='-',baguette='T:Bakery',scone='T:Dairy',croissant='T:Bakery',broken_biscuit='T:Bakery',iced_bun='T:Bakery',birthday_candles='T:Bakery',squashed_cake='T:Clearance',stale_doughnut='-',crisps='C:bread',cereal_bar='T:Snack',bent_lolly='T:Snack',pick_n_mix='T:Snack',stale_popcorn='T:Snack',breadsticks='C:soup',dusty_toffees='T:Clearance',
 breakfast_sticker='G:Breakfast',clearance_tag='G:Clearance',final_markdown='-',multipack='D',two_for_one='D',shelf_swap='-',repeat='-',opening_deal='-')
MAIN=dict(banana='Produce',bread='Bakery',milk='Dairy',eggs='Breakfast',coffee='Breakfast',soup='Food',batteries='Household',potatoes='Produce',stale_doughnut='Bakery',scissors='Household')
NAME={k:v['name'] for k,v in D.items()}
FLAG=dict(
 bread="Bread is Breakfast and Bakery: it takes Bakery, the more specific one (Cheese and Crisps follow it).",
 milk="Its own main family is Dairy (that is what Cereal follows); the ticket is Breakfast because its rule counts Breakfast.",
 eggs="Food: its rule names Food, which almost every product is.",
 soup="Its rule is a penalty (pays €0 beside Frozen), so it keeps its own family, Food. Following the rule would make it a Frozen ticket, which reads as \"put me with Frozen\".",
 cheese="Names Bread: Bread's main family, Bakery.",
 crisps="Names Bread: Bread's main family, Bakery.",
 cereal="Names Milk: Milk's main family, Dairy. If Milk should count as Breakfast here, Cereal turns Breakfast (or a split, see the split example).",
 crackers="Names Soup: Soup's only family, Food. Other option: its own family (Bakery).",
 soft_tomatoes="Names Soup: Soup's only family, Food. Other option: its own family (Produce).",
 breadsticks="Names Soup: Soup's only family, Food. Other option: its own family (Snack).",
 mixed_herbs="Food: its rule names Food.",
 carrier_bag="Food: its rule names Food (a Household item that wants Food before it).",
 scissors="Names coupons, not a family: its own family, Household. Other option: the plain coupon ticket.",
 stale_doughnut="No target: its aisle's family, Bakery. It is also Clearance (other option).",
 final_markdown="No target: Clearance, for its \"markdown\" theme. Other option: the plain coupon ticket.",
 breakfast_sticker="Gives the Breakfast tag: Breakfast colour, coupon shape.",
 clearance_tag="Gives the Clearance tag: Clearance colour, coupon shape.",
 multipack="Works with whatever tag the product before it has: no one family, so the plain coupon ticket.",
 two_for_one="Works with the same product on both sides: the plain coupon ticket.",
 shelf_swap="A slot rule: the plain coupon ticket.",
 repeat="Copies the payout before it: the plain coupon ticket.",
 opening_deal="A slot rule: the plain coupon ticket.",
)
NOTE=dict(
 ham_ends="Stocked in Cold cases; its colour follows its target (Dairy), not the aisle.",
 butter="Cold cases, but Bakery colour: it wants Bakery beside it.",
 scone="Bakery aisle, but Dairy colour: it wants Dairy beside it.",
 yogurt="Names Banana: Banana's main family, Produce.",
 birthday_candles="A Household item on the Bakery aisle that wants Bakery after it.",
 sugar_cubes="Names Coffee: Coffee's main family, Breakfast.",
 chipped_mug="Names Coffee: Coffee's main family, Breakfast.",
 egg_timer="Names Eggs: Eggs' main family, Breakfast.",
 banana="Names itself (another Banana): Produce.",
 potatoes="No rule: its own family, Produce.",
 batteries="A slot rule, no target: its own family, Household.",
 frozen_peas="Wants another Frozen product beside it.",
)
FAMS='Breakfast Bakery Produce Dairy Frozen Snack Household Clearance Food'.split()
def short(k,v):
    s=v['sticker_filled'] or ''
    if k=='banana': s='+2 after Banana'
    if k=='frozen_peas': s='+3 beside Frozen'
    if not s: return 'No rule'
    s=s.replace('×','×')
    for f in FAMS: s=re.sub(r'\b'+f+r'\b','{'+f+'}',s)
    s=s.replace('earlier coupon','earlier {Coupon}')
    return s
out=[]
for k,v in D.items():
    if k=='bundle': continue
    t=TGT[k]; coupon=v['kind']=='2'
    if t.startswith('T:') or t.startswith('G:'): col=t[2:]; why=('rule names '+t[2:]) if t[0]=='T' else 'gives the '+t[2:]+' tag'
    elif t.startswith('C:'): col=MAIN[t[2:]]; why='rule names '+NAME[t[2:]]+' ('+col+')'
    elif t=='S': col=MAIN[k]; why='rule names Banana ('+col+')'
    elif t=='P:Frozen': col=MAIN[k]; why='penalty rule: own family'
    elif t == 'X:coupon':
        col = MAIN[k]; why = 'names coupons: own family'
    elif coupon:
        col = 'Clearance' if k == 'final_markdown' else 'Coupon'
        why = 'theme: markdown' if k == 'final_markdown' else 'no family: plain coupon'
    else:
        col = MAIN[k]; why = 'no target: own family'
    if t == 'D':
        col = 'Coupon'; why = 'no family: plain coupon'
    base = int(v['base']) if v['base'] not in (None, 'None') else 0
    rec = dict(id=k, name=v['name'], base=base, tags=v['tags'], eff=short(k, v), long=v['rule'], src=SRC[k], tgt=t, col=col, why=why)
    if coupon:
        rec['coupon'] = True
    if k in FLAG:
        rec['flag'] = FLAG[k]
    elif k in NOTE:
        rec['note'] = NOTE[k]
    out.append(rec)
js = 'const CARDS = [\n' + ',\n'.join('  ' + json.dumps(r, ensure_ascii=False) for r in out) + '\n];\n'
open(HERE / 'cards.js', 'w', encoding='utf-8').write(js)
from collections import Counter
print(len(out), Counter(r['col'] for r in out))
print([r['id'] for r in out if 'flag' in r])
