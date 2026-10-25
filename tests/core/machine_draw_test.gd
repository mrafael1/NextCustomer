extends GdUnitTestSuite
## The machine's draw steps (#77, build spec 1.5; #108's two chutes): the pools per chute, each
## drop's kind (NEW ITEMS: products then a coupon; UPGRADE: a loyalty perk, an item upgrade, then
## either), the empty-tier fallback (with a PREMIUM floor) and the any-kind fallback, short draws,
## the loyalty perks' owned, level and type rules, the guarantee swap inside the drop's tier and
## kind, the first NEW ITEMS draw's coupon and new arrival, the tier roll, SHELF UPGRADE's two
## copies, and seeded determinism.

const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const CARDS_DIR := "res://data/cards"
const UPGRADES_DIR := "res://data/upgrades"

var _balance: BalanceDefinition
var _starter: DeckDefinition


func before() -> void:
	_balance = load(BALANCE)
	_starter = load(STARTER)


## A rarity with no candidate steps down a tier, then up.
func test_an_empty_tier_steps_down_then_up() -> void:
	var common: MachinePrize = _product("common", 0)
	var legendary: MachinePrize = _product("legendary", 2)
	var no_rare: Array = _pools([common], [], [legendary])
	var drawn: Array[MachinePrize] = []
	assert_array(MachineDraw.land(no_rare, 1, drawn)).is_equal([common])
	drawn.append(common)
	assert_array(MachineDraw.land(no_rare, 1, drawn)).is_equal([legendary])
	assert_array(MachineDraw.land(no_rare, 0, drawn)).is_equal([legendary])
	drawn.append(legendary)
	assert_array(MachineDraw.land(no_rare, 2, drawn)).is_empty()


## With a floor (a PREMIUM visit), the fallback steps down only to the floor, then up, and below
## the floor last.
func test_the_fallback_order_keeps_to_the_floor_first() -> void:
	assert_array(MachineDraw.fallback_order(0)).is_equal([0, 1, 2])
	assert_array(MachineDraw.fallback_order(1)).is_equal([1, 0, 2])
	assert_array(MachineDraw.fallback_order(2)).is_equal([2, 1, 0])
	assert_array(MachineDraw.fallback_order(1, 1)).is_equal([1, 2, 0])
	assert_array(MachineDraw.fallback_order(2, 1)).is_equal([2, 1, 0])
	assert_array(MachineDraw.fallback_order(2, 2)).is_equal([2, 1, 0])
	var common: MachinePrize = _product("common", 0)
	var legendary: MachinePrize = _product("legendary", 2)
	var no_rare: Array = _pools([common], [], [legendary])
	var drawn: Array[MachinePrize] = []
	var any_kind: int = MachineDraw.ANY_KIND
	assert_array(MachineDraw.land(no_rare, 1, drawn, any_kind, 1)).is_equal([legendary])


## A drop takes its own kind at any rarity before another kind; a kind with none at all takes any
## kind.
func test_a_drop_keeps_its_kind_then_takes_any() -> void:
	var coupon: MachinePrize = _coupon("coupon", 0)
	var product: MachinePrize = _product("product", 1)
	var mixed: Array = _pools([coupon], [product], [])
	var drawn: Array[MachinePrize] = []
	var product_kind: int = MachinePrize.Kind.PRODUCT
	var coupon_kind: int = MachinePrize.Kind.COUPON
	assert_array(MachineDraw.land(mixed, 0, drawn, product_kind)).is_equal([product])
	assert_array(MachineDraw.land(mixed, 1, drawn, coupon_kind)).is_equal([coupon])
	var products_only: Array = _pools([], [product], [])
	assert_array(MachineDraw.land(products_only, 0, drawn, coupon_kind)).is_equal([product])


## Each drop's kind: NEW ITEMS' last drop is its coupon; UPGRADE's first is a loyalty perk, its
## second an item upgrade, the third either.
func test_each_drop_has_its_kind() -> void:
	var product: int = MachinePrize.Kind.PRODUCT
	assert_array(_drop_kinds(RewardMachine.Chute.NEW_ITEMS)).is_equal(
		[product, product, MachinePrize.Kind.COUPON]
	)
	assert_array(_drop_kinds(RewardMachine.Chute.UPGRADE)).is_equal(
		[MachinePrize.Kind.REGISTER, MachinePrize.Kind.UPGRADE, MachineDraw.ANY_KIND]
	)


## A zero weight total ends the draw short, with no error and no RNG used; a pool that runs out
## ends it short too.
func test_zero_weights_and_small_pools_end_the_draw_short() -> void:
	var context: MachineContext = _context()
	context.machine = _balance.machine.duplicate()
	var zero: MachineOddsLevel = MachineOddsLevel.new()
	var levels: Array[MachineOddsLevel] = [zero]
	context.machine.odds_levels = levels
	var rng: RandomNumberGenerator = _rng(3)
	var state: int = rng.state
	assert_array(MachineDraw.draw(RewardMachine.Chute.NEW_ITEMS, context, 0, rng)).is_empty()
	assert_int(rng.state).is_equal(state)
	var small: MachineContext = _context()
	var two: Array[CardDefinition] = [
		load("%s/soup.tres" % CARDS_DIR), load("%s/milk.tres" % CARDS_DIR)
	]
	var none: Array[CardDefinition] = []
	small.products = two
	small.coupons = none
	var drawn: Array[MachinePrize] = MachineDraw.draw(RewardMachine.Chute.NEW_ITEMS, small, 0, rng)
	assert_int(drawn.size()).is_equal(2)


## NEW ITEMS draws 2 products and 1 coupon; the run's first coupon draw takes a first-offer
## coupon, later ones any coupon of the pool.
func test_new_items_draws_products_and_one_coupon() -> void:
	var first: MachineContext = _context()
	first.first_coupons = true
	var later: MachineContext = _context()
	var rng: RandomNumberGenerator = _rng(17)
	var later_coupons: Dictionary = {}
	var product: int = MachinePrize.Kind.PRODUCT
	for draw: int in 300:
		for context: MachineContext in [first, later]:
			var drawn: Array[MachinePrize] = MachineDraw.draw(
				RewardMachine.Chute.NEW_ITEMS, context, draw % 4, rng
			)
			var kinds: Array = drawn.map(func(prize: MachinePrize) -> int: return prize.kind)
			assert_array(kinds).is_equal([product, product, MachinePrize.Kind.COUPON])
			_assert_distinct(drawn)
			if context == first:
				assert_bool(_balance.first_offer_pool.has(drawn[2].card)).is_true()
			else:
				later_coupons[drawn[2].card.id] = true
	assert_int(later_coupons.size()).is_greater(_balance.first_offer_pool.size())


## UPGRADE draws a loyalty perk then an item upgrade; a perk never repeats an owned one or a type,
## and an owned perk can come back only as its next level; a prize never drops twice.
func test_upgrade_draws_a_perk_and_an_item_upgrade() -> void:
	var context: MachineContext = _context()
	var engine: UpgradeDefinition = _upgrade("coupon_engine")
	var owned: Array[UpgradeDefinition] = [engine]
	context.owned = owned
	var rng: RandomNumberGenerator = _rng(11)
	var levelled: bool = false
	for draw: int in 300:
		var drawn: Array[MachinePrize] = MachineDraw.draw(
			RewardMachine.Chute.UPGRADE, context, draw % 4, rng
		)
		assert_int(drawn.size()).is_equal(3)
		assert_int(drawn[0].kind).is_equal(MachinePrize.Kind.REGISTER)
		assert_int(drawn[1].kind).is_equal(MachinePrize.Kind.UPGRADE)
		var types: Dictionary = {}
		for prize: MachinePrize in drawn:
			if prize.kind != MachinePrize.Kind.REGISTER:
				continue
			assert_bool(owned.has(prize.upgrade)).is_false()
			if prize.upgrade.same_perk(engine):
				assert_object(prize.upgrade).is_same(engine.next_level)
				levelled = true
			assert_bool(types.has(prize.upgrade.type)).is_false()
			types[prize.upgrade.type] = true
		_assert_distinct(drawn)
	assert_bool(levelled).is_true()


## A full loyalty card (register_cap new perks) offers only level-ups; a perk at LV 3, Big
## basket and Rule bender have none, so their loyalty drop takes an item upgrade.
func test_a_full_card_offers_only_level_ups() -> void:
	var context: MachineContext = _context()
	var owned: Array[UpgradeDefinition] = [
		_upgrade("coupon_engine"), _upgrade("slot_engine_lv2"), _upgrade("big_basket")
	]
	context.owned = owned
	context.card_full = true
	var perks: Array = _perk_ids(MachineDraw.pools(RewardMachine.Chute.UPGRADE, context))
	assert_array(perks).contains_exactly_in_any_order([&"coupon_engine_lv2", &"slot_engine_lv3"])
	var capped: MachineContext = _context()
	var top: Array[UpgradeDefinition] = [
		_upgrade("coupon_engine_lv3"), _upgrade("big_basket"), _upgrade("rule_bender")
	]
	capped.owned = top
	capped.card_full = true
	assert_array(_perk_ids(MachineDraw.pools(RewardMachine.Chute.UPGRADE, capped))).is_empty()
	var rng: RandomNumberGenerator = _rng(8)
	for draw: int in 50:
		var drawn: Array[MachinePrize] = MachineDraw.draw(
			RewardMachine.Chute.UPGRADE, capped, draw % 4, rng
		)
		for prize: MachinePrize in drawn:
			assert_int(prize.kind).is_equal(MachinePrize.Kind.UPGRADE)
	# A card with a free box offers the new perks too, but never a second level of an owned one.
	var open: MachineContext = _context()
	open.owned = owned
	var open_perks: Array = _perk_ids(MachineDraw.pools(RewardMachine.Chute.UPGRADE, open))
	assert_array(open_perks).contains([&"coupon_engine_lv2", &"category_engine", &"extra_redraw"])
	assert_array(open_perks).not_contains([&"coupon_engine", &"slot_engine", &"big_basket"])


## A PREMIUM visit floors every drop at RARE and every NEW ITEMS product with an upgrade chain at
## BIG; a classic visit rolls plain products too.
func test_a_premium_draw_is_rare_or_better_and_big_or_better() -> void:
	var rng: RandomNumberGenerator = _rng(41)
	var plain_seen: bool = false
	for premium: bool in [true, false]:
		var context: MachineContext = _context()
		context.premium = premium
		for draw: int in 300:
			for chute: int in RewardMachine.CHUTES:
				var drawn: Array[MachinePrize] = MachineDraw.draw(chute, context, draw % 4, rng)
				assert_int(drawn.size()).is_equal(3)
				for prize: MachinePrize in drawn:
					var chain: ItemUpgradeDefinition = MachineDraw.chain_of(context.machine, prize)
					var plain: bool = chain != null and prize.card.tier == CardDefinition.Tier.PLAIN
					plain_seen = plain_seen or plain
					if not premium:
						continue
					assert_int(prize.rarity).is_greater_equal(MachinePrize.Rarity.RARE)
					assert_bool(plain).override_failure_message(prize.key()).is_false()
	assert_bool(plain_seen).is_true()


## The odds level's tier weights: classic ones as data, a PREMIUM floor zeroes the plain tier, and
## nothing left is always plain; the rarity floor zeroes the rarities below it.
func test_tier_and_rarity_weights_take_their_floors() -> void:
	var level: MachineOddsLevel = _balance.machine.odds_level(0)
	assert_array(Array(level.tier_weights())).is_equal([85, 13, 2])
	assert_array(Array(level.tier_weights(1))).is_equal([0, 13, 2])
	assert_array(Array(level.tier_weights(3))).is_equal([1, 0, 0])
	assert_array(Array(level.weights(1))).is_equal([75, 22, 3])
	assert_array(Array(level.weights(1, 1))).is_equal([0, 22, 3])
	var top: MachineOddsLevel = _balance.machine.odds_level(3)
	assert_array(Array(top.weights(0))).is_equal([0, 37, 18])
	assert_array(Array(top.weights(0, 2))).is_equal([0, 0, 18])
	assert_array(Array(MachineOddsLevel.new().tier_weights())).is_equal([1, 0, 0])


## The tier roll: each product with a chain becomes its BIG or GOLDEN card by the tier weights, at
## its plain card's rarity; coupons and products without a chain stay; tiers count as the plain
## product for the guarantee.
func test_new_items_products_roll_their_tier() -> void:
	var context: MachineContext = _context()
	var milk: MachinePrize = _live_product("milk")
	var milk_rarity: int = context.machine.product_rarity(milk.card)
	var coupon: MachinePrize = MachinePrize.new(
		MachinePrize.Kind.COUPON, 1, load("%s/repeat.tres" % CARDS_DIR)
	)
	var drawn: Array[MachinePrize] = [milk, milk, coupon]
	var counts: Array[int] = [0, 0, 0]
	var held: Dictionary = {&"milk": true}
	var rng: RandomNumberGenerator = _rng(23)
	for _draw: int in 2000:
		var rolled: Array[MachinePrize] = MachineDraw.roll_tiers(context, 0, drawn, rng)
		assert_object(rolled[2]).is_same(coupon)
		assert_bool(MachineDraw.holds(rolled, held)).is_true()
		for index: int in 2:
			var prize: MachinePrize = rolled[index]
			counts[prize.card.tier] += 1
			assert_int(prize.rarity).is_equal(milk_rarity)
			assert_str(String(prize.plain_id())).is_equal("milk")
	# 85 / 13 / 2 of 4000 rolls, seeded.
	assert_int(counts[0]).is_between(3250, 3550)
	assert_int(counts[1]).is_between(400, 650)
	assert_int(counts[2]).is_between(30, 130)
	var no_chain: CardDefinition = CardDefinition.new()
	no_chain.id = &"no_chain"
	no_chain.kind = CardDefinition.Kind.PRODUCT
	var plain: Array[MachinePrize] = [MachinePrize.new(MachinePrize.Kind.PRODUCT, 0, no_chain)]
	var state: int = rng.state
	assert_array(MachineDraw.roll_tiers(context, 0, plain, rng)).is_equal(plain)
	assert_int(rng.state).is_equal(state)


## The fresh stock always holds a generally useful product in every tier that can land, so every
## NEW ITEMS draw holds one; UPGRADE's guarantee is the new perks that fit the deck (never a
## level-up), and every UPGRADE draw holds one.
func test_guarantees_hold_whenever_a_tier_has_one() -> void:
	var context: MachineContext = _context()
	var owned: Array[UpgradeDefinition] = [_upgrade("coupon_engine")]
	context.owned = owned
	# A cart with every stocked item and coupon, so some new perk fits it.
	for card: CardDefinition in context.products + context.coupons:
		context.deck.add_card(card)
	var rng: RandomNumberGenerator = _rng(21)
	var held_new: Dictionary = context.guarantee(RewardMachine.Chute.NEW_ITEMS)
	var held_perks: Dictionary = context.guarantee(RewardMachine.Chute.UPGRADE)
	assert_dict(held_perks).is_not_empty()
	assert_bool(held_perks.has(&"coupon_engine_lv2")).is_false()
	assert_bool(held_perks.has(&"coupon_engine")).is_false()
	for draw: int in 400:
		var level: int = draw % 4
		var products: Array[MachinePrize] = MachineDraw.draw(
			RewardMachine.Chute.NEW_ITEMS, context, level, rng
		)
		assert_bool(MachineDraw.holds(products, held_new)).is_true()
		_assert_distinct(products)
		var perks: Array[MachinePrize] = MachineDraw.draw(
			RewardMachine.Chute.UPGRADE, context, level, rng
		)
		assert_bool(MachineDraw.holds(perks, held_perks)).is_true()


## v0.49: NEW ITEMS' guarantee prefers, in each rarity tier, the stocked generally useful
## products the deck doesn't hold yet (a tier counts as its plain card); a tier whose useful
## products are all in the deck keeps them all, so every tier that could swap one in still can.
func test_the_new_items_guarantee_prefers_products_not_in_the_deck() -> void:
	var run: RunState = RunState.new(1, _starter, _balance, RunStock.starting(_balance))
	assert_array(_held(run)).contains_exactly_in_any_order(_expected_held(run))
	# The starter holds both COMMON useful products (Banana, Bread): that tier keeps them.
	assert_array(_held(run)).contains([&"banana", &"bread"])
	assert_array(_held(run)).not_contains([&"milk", &"eggs"])
	assert_array(_held(run)).contains([&"butter"])
	# A BIG copy counts as its plain product.
	run.deck.add_card(load("res://data/cards/butter_big.tres"))
	assert_array(_held(run)).not_contains([&"butter"])
	assert_array(_held(run)).contains_exactly_in_any_order(_expected_held(run))


## The swap replaces the last drop whose own tier holds a guarantee member of its own kind, with
## such a member; when no drop's tier holds one, the draw stands.
func test_the_guarantee_swap_stays_inside_the_drop_tier_and_kind() -> void:
	var common: Array[MachinePrize] = [_product("c1", 0), _product("c2", 0), _product("c3", 0)]
	var plain_rare: MachinePrize = _product("r1", 1)
	var useful_rare: MachinePrize = _product("r2", 1)
	var chute_pools: Array = _pools(common, [plain_rare, useful_rare], [])
	var held_ids: Dictionary = {&"r2": true}
	var drawn: Array[MachinePrize] = [plain_rare, common[0], common[1]]
	var alternatives: Array = MachineDraw.swaps(chute_pools, drawn, held_ids)
	assert_int(alternatives.size()).is_equal(1)
	assert_array(_keys(alternatives)).is_equal(
		[useful_rare.key(), common[0].key(), common[1].key()]
	)
	var commons_only: Array[MachinePrize] = [common[0], common[1], common[2]]
	alternatives = MachineDraw.swaps(chute_pools, commons_only, held_ids)
	assert_int(alternatives.size()).is_equal(1)
	assert_array(_keys(alternatives)).is_equal(_keys([commons_only]))
	assert_bool(MachineDraw.holds(alternatives[0], held_ids)).is_false()
	# A coupon drop in the rare tier never takes the useful rare product.
	var coupon: MachinePrize = _coupon("k1", 1)
	var with_coupon: Array = _pools(common, [coupon, useful_rare], [])
	var coupon_last: Array[MachinePrize] = [common[0], common[1], coupon]
	alternatives = MachineDraw.swaps(with_coupon, coupon_last, held_ids)
	assert_array(_keys(alternatives)).is_equal(_keys([coupon_last]))


## A loyalty perk's swap keeps "different types": a fitting perk of a type another loyalty drop
## has is never swapped in.
func test_the_perk_swap_keeps_different_types() -> void:
	var economy: MachinePrize = _register("economy", UpgradeDefinition.Type.ECONOMY)
	var risky: MachinePrize = _register("risky", UpgradeDefinition.Type.RISKY)
	var coupon: MachinePrize = _register("coupon", UpgradeDefinition.Type.COUPON_ENGINE)
	var fitting_risky: MachinePrize = _register("fitting_risky", UpgradeDefinition.Type.RISKY)
	var fitting_slot: MachinePrize = _register("fitting_slot", UpgradeDefinition.Type.SLOT_ENGINE)
	var chute_pools: Array = _pools([economy, risky, coupon, fitting_risky, fitting_slot], [], [])
	var held_ids: Dictionary = {&"fitting_risky": true, &"fitting_slot": true}
	var drawn: Array[MachinePrize] = [economy, risky, coupon]
	var alternatives: Array = MachineDraw.swaps(chute_pools, drawn, held_ids)
	# The last drop (coupon) can take fitting_slot only: fitting_risky would repeat Risky.
	assert_int(alternatives.size()).is_equal(1)
	assert_array(_keys(alternatives)).is_equal([economy.key(), risky.key(), fitting_slot.key()])


## The run's first NEW ITEMS draw holds the newest new arrival at its own rarity: it replaces the
## last product drop that isn't the draw's only generally useful product (never the coupon);
## later draws don't.
func test_the_first_new_items_draw_holds_the_new_arrival() -> void:
	var context: MachineContext = _context()
	var lemon: CardDefinition = load("%s/lemon.tres" % CARDS_DIR)
	context.products.append(lemon)
	context.new_arrival = lemon
	context.first_new_items = true
	var bread: MachinePrize = _live_product("bread")
	var soup: MachinePrize = _live_product("soup")
	var coffee: MachinePrize = _live_product("coffee")
	var one_useful: Array[MachinePrize] = [soup, coffee, bread]
	var swapped: Array[MachinePrize] = MachineDraw.new_arrival_swap(context, one_useful)
	assert_array(swapped.map(_id)).is_equal([&"soup", &"lemon", &"bread"])
	assert_int(swapped[1].rarity).is_equal(MachinePrize.Rarity.LEGENDARY)
	var milk: MachinePrize = _live_product("milk")
	var two_useful: Array[MachinePrize] = [soup, bread, milk]
	swapped = MachineDraw.new_arrival_swap(context, two_useful)
	assert_array(swapped.map(_id)).is_equal([&"soup", &"bread", &"lemon"])
	var coupon: MachinePrize = MachinePrize.new(
		MachinePrize.Kind.COUPON, 1, load("%s/repeat.tres" % CARDS_DIR)
	)
	var coupon_last: Array[MachinePrize] = [soup, bread, coupon]
	swapped = MachineDraw.new_arrival_swap(context, coupon_last)
	assert_array(swapped.map(_id)).is_equal([&"lemon", &"bread", &"repeat"])
	var rng: RandomNumberGenerator = _rng(5)
	for draw: int in 50:
		var drawn: Array[MachinePrize] = MachineDraw.draw(
			RewardMachine.Chute.NEW_ITEMS, context, draw % 4, rng
		)
		assert_array(drawn.map(_plain_id)).contains([&"lemon"])
		var useful: Array = drawn.filter(_is_useful)
		assert_array(useful).is_not_empty()
	context.first_new_items = false
	var later: Array[MachinePrize] = [soup, coffee, bread]
	assert_array(MachineDraw.new_arrival_swap(context, later)).is_equal(later)


## UPGRADE offers an item upgrade only for a product with a copy in the cart, per rarity it can
## do: SHELF UPGRADE (LEGENDARY) needs 2 copies that can step; GOLDEN copies can't step.
func test_item_upgrade_pools_and_shelf_upgrade() -> void:
	var context: MachineContext = _context()
	var no_perks: Array[UpgradeDefinition] = []
	context.upgrade_pool = no_perks
	context.deck = Deck.new(null)
	var milk: ItemUpgradeDefinition = load("res://data/item_upgrades/milk.tres")
	var eggs: ItemUpgradeDefinition = load("res://data/item_upgrades/eggs.tres")
	context.deck.add_card(milk.product)
	context.deck.add_card(eggs.golden)
	var pools: Array = MachineDraw.pools(RewardMachine.Chute.UPGRADE, context)
	assert_array(_keys(pools)).is_equal(["upgrade:milk:0", "upgrade:milk:1"])
	context.deck.add_card(milk.big)
	pools = MachineDraw.pools(RewardMachine.Chute.UPGRADE, context)
	assert_array(_keys(pools)).is_equal(["upgrade:milk:0", "upgrade:milk:1", "upgrade:milk:2"])
	var golden_only: MachineContext = _context()
	golden_only.upgrade_pool = no_perks
	golden_only.deck = Deck.new(null)
	golden_only.deck.add_card(eggs.golden)
	pools = MachineDraw.pools(RewardMachine.Chute.UPGRADE, golden_only)
	assert_array(_keys(pools)).is_empty()


## The same seed and state draw the same prizes.
func test_the_same_seed_draws_the_same_prizes() -> void:
	var context: MachineContext = _context()
	for chute: int in RewardMachine.CHUTES:
		var first: Array[MachinePrize] = MachineDraw.draw(chute, context, 2, _rng(99))
		var second: Array[MachinePrize] = MachineDraw.draw(chute, context, 2, _rng(99))
		assert_array(_keys([first])).is_equal(_keys([second]))


## MachinePrize keys and its save form (a loyalty perk saves its level).
func test_prize_keys_and_save_form() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var prizes: Array[MachinePrize] = [
		_live_product("milk"),
		MachinePrize.new(MachinePrize.Kind.COUPON, 1, load("%s/repeat.tres" % CARDS_DIR)),
		MachinePrize.new(MachinePrize.Kind.REGISTER, 2, null, _balance.upgrade_pool[3]),
		MachinePrize.new(MachinePrize.Kind.UPGRADE, 2, load("%s/eggs.tres" % CARDS_DIR)),
		MachinePrize.new(MachinePrize.Kind.REGISTER, 1, null, _upgrade("coupon_engine_lv3")),
		MachinePrize.new(MachinePrize.Kind.PRODUCT, 1, load("%s/milk_big.tres" % CARDS_DIR)),
	]
	assert_str(prizes[0].key()).is_equal("product:milk:1")
	assert_str(prizes[2].key()).is_equal("register:slot_engine:2")
	assert_int(int(prizes[2].to_dictionary()["level"])).is_equal(1)
	assert_int(int(prizes[4].to_dictionary()["level"])).is_equal(3)
	assert_str(String(prizes[5].plain_id())).is_equal("milk")
	assert_str(String(prizes[5].id())).is_equal("milk_big")
	for prize: MachinePrize in prizes:
		var saved: Dictionary = JSON.parse_string(JSON.stringify(prize.to_dictionary()))
		var read: MachinePrize = MachinePrize.from_dictionary(saved, lookup)
		assert_str(read.key()).is_equal(prize.key())
	var bad: Array[Dictionary] = [
		{"kind": "coupon", "id": "milk", "rarity": 0},
		{"kind": "product", "id": "nothing", "rarity": 0},
		{"kind": "gift", "id": "milk", "rarity": 0},
		{"kind": "product", "id": "milk", "rarity": 3},
		{"kind": "register", "id": "milk", "rarity": 0},
	]
	for data: Dictionary in bad:
		assert_object(MachinePrize.from_dictionary(data, lookup)).is_null()


func _assert_distinct(drawn: Array[MachinePrize]) -> void:
	var keys: Dictionary = {}
	for prize: MachinePrize in drawn:
		assert_bool(keys.has(prize.key())).is_false()
		keys[prize.key()] = true


## Each drop's kind of a chute's draw with the live machine.
func _drop_kinds(chute: int) -> Array:
	var found: Array = []
	for drop: int in _balance.machine.prizes_per_visit:
		found.append(MachineDraw.drop_kind(chute, _balance.machine, drop))
	return found


func _keys(pools: Array) -> Array[String]:
	var found: Array[String] = []
	for pool: Array in pools:
		for prize: MachinePrize in pool:
			found.append(prize.key())
	return found


## The loyalty perks' ids in a chute's pools.
func _perk_ids(pools: Array) -> Array:
	var found: Array = []
	for pool: Array in pools:
		for prize: MachinePrize in pool:
			if prize.kind == MachinePrize.Kind.REGISTER:
				found.append(prize.upgrade.id)
	return found


func _is_useful(prize: MachinePrize) -> bool:
	return prize.card.generally_useful


func _id(prize: MachinePrize) -> StringName:
	return prize.id()


func _plain_id(prize: MachinePrize) -> StringName:
	return prize.plain_id()


## The NEW ITEMS guarantee set of a run's machine context, as ids.
func _held(run: RunState) -> Array:
	var context: MachineContext = MachineContext.from_run(run, _balance.machine, true, true)
	return context.guarantee(RewardMachine.Chute.NEW_ITEMS).keys()


## The stocked useful products per the v0.49 rule, worked out from the deck by hand.
func _expected_held(run: RunState) -> Array:
	var held: Array = []
	var deck_ids: Array = run.deck.cards.map(
		func(card: CardInstance) -> StringName: return card.definition.product_card().id
	)
	for card: CardDefinition in run.stock.cards:
		if not (card.is_product() and card.generally_useful):
			continue
		var rarity: int = _balance.machine.product_rarity(card)
		var tier_fresh: bool = run.stock.cards.any(
			func(other: CardDefinition) -> bool:
				return (
					other.is_product()
					and other.generally_useful
					and _balance.machine.product_rarity(other) == rarity
					and not deck_ids.has(other.id)
				)
		)
		if not tier_fresh or not deck_ids.has(card.id):
			held.append(card.id)
	return held


## The fresh run's snapshot with the live machine (both first draws done).
func _context() -> MachineContext:
	var run: RunState = RunState.new(1, _starter, _balance, RunStock.starting(_balance))
	return MachineContext.from_run(run, _balance.machine, true, true)


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _pools(common: Array, rare: Array, legendary: Array) -> Array:
	var found: Array = []
	for list: Array in [common, rare, legendary]:
		var pool: Array[MachinePrize] = []
		pool.assign(list)
		found.append(pool)
	return found


func _product(id: String, rarity: int) -> MachinePrize:
	var card: CardDefinition = CardDefinition.new()
	card.id = StringName(id)
	card.kind = CardDefinition.Kind.PRODUCT
	return MachinePrize.new(MachinePrize.Kind.PRODUCT, rarity, card)


func _coupon(id: String, rarity: int) -> MachinePrize:
	var card: CardDefinition = CardDefinition.new()
	card.id = StringName(id)
	card.kind = CardDefinition.Kind.COUPON
	return MachinePrize.new(MachinePrize.Kind.COUPON, rarity, card)


func _live_product(id: String) -> MachinePrize:
	var card: CardDefinition = load("%s/%s.tres" % [CARDS_DIR, id])
	var rarity: int = _balance.machine.product_rarity(card)
	return MachinePrize.new(MachinePrize.Kind.PRODUCT, rarity, card)


func _upgrade(id: String) -> UpgradeDefinition:
	return load("%s/%s.tres" % [UPGRADES_DIR, id])


func _register(id: String, type: UpgradeDefinition.Type) -> MachinePrize:
	var upgrade: UpgradeDefinition = UpgradeDefinition.new()
	upgrade.id = StringName(id)
	upgrade.type = type
	return MachinePrize.new(MachinePrize.Kind.REGISTER, 0, null, upgrade)
