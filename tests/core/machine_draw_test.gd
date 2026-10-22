extends GdUnitTestSuite
## The machine's draw steps (#77, build spec 1.5): the pools per chute, the empty-tier fallback,
## short draws, REGISTER's owned and type rules, the guarantee swap inside the drop's tier, the
## first NEW ITEMS draw's new arrival, SHELF UPGRADE's two copies, and seeded determinism.

const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const CARDS_DIR := "res://data/cards"

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
	var chute: int = RewardMachine.Chute.NEW_ITEMS
	assert_array(MachineDraw.land(chute, no_rare, 1, drawn)).is_equal([common])
	drawn.append(common)
	assert_array(MachineDraw.land(chute, no_rare, 1, drawn)).is_equal([legendary])
	assert_array(MachineDraw.land(chute, no_rare, 0, drawn)).is_equal([legendary])
	drawn.append(legendary)
	assert_array(MachineDraw.land(chute, no_rare, 2, drawn)).is_empty()


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
		load("%s/bread.tres" % CARDS_DIR), load("%s/milk.tres" % CARDS_DIR)
	]
	small.products = two
	var drawn: Array[MachinePrize] = MachineDraw.draw(RewardMachine.Chute.NEW_ITEMS, small, 0, rng)
	assert_int(drawn.size()).is_equal(2)


## REGISTER never draws an owned upgrade or two of one type; a prize never drops twice.
func test_register_skips_owned_and_repeats_no_type() -> void:
	var context: MachineContext = _context()
	context.owned = [_balance.upgrade_pool[0]]
	var rng: RandomNumberGenerator = _rng(11)
	for draw: int in 300:
		var drawn: Array[MachinePrize] = MachineDraw.draw(
			RewardMachine.Chute.REGISTER, context, draw % 4, rng
		)
		var types: Dictionary = {}
		for prize: MachinePrize in drawn:
			assert_int(prize.kind).is_equal(MachinePrize.Kind.REGISTER)
			assert_bool(context.owned.has(prize.upgrade)).is_false()
			assert_bool(types.has(prize.upgrade.type)).is_false()
			types[prize.upgrade.type] = true
		_assert_distinct(drawn)


## The fresh stock always holds a generally useful product in every tier that can land, so every
## NEW ITEMS draw holds one; COUPONS' first draw always holds a first-offer coupon.
func test_guarantees_hold_whenever_a_tier_has_one() -> void:
	var context: MachineContext = _context()
	context.first_coupons = true
	var rng: RandomNumberGenerator = _rng(21)
	var held_new: Dictionary = context.guarantee(RewardMachine.Chute.NEW_ITEMS)
	var held_coupons: Dictionary = context.guarantee(RewardMachine.Chute.COUPONS)
	assert_int(held_coupons.size()).is_equal(_balance.first_offer_pool.size())
	for draw: int in 400:
		var level: int = draw % 4
		var products: Array[MachinePrize] = MachineDraw.draw(
			RewardMachine.Chute.NEW_ITEMS, context, level, rng
		)
		assert_bool(MachineDraw.holds(products, held_new)).is_true()
		_assert_distinct(products)
		var coupons: Array[MachinePrize] = MachineDraw.draw(
			RewardMachine.Chute.COUPONS, context, level, rng
		)
		assert_bool(MachineDraw.holds(coupons, held_coupons)).is_true()


## The swap replaces the last drop whose own tier holds a guarantee member, with a member of that
## tier; when no drop's tier holds one, the draw stands.
func test_the_guarantee_swap_stays_inside_the_drop_tier() -> void:
	var common: Array[MachinePrize] = [_product("c1", 0), _product("c2", 0), _product("c3", 0)]
	var plain_rare: MachinePrize = _product("r1", 1)
	var useful_rare: MachinePrize = _product("r2", 1)
	var chute_pools: Array = _pools(common, [plain_rare, useful_rare], [])
	var held_ids: Dictionary = {&"r2": true}
	var chute: int = RewardMachine.Chute.NEW_ITEMS
	var drawn: Array[MachinePrize] = [plain_rare, common[0], common[1]]
	var alternatives: Array = MachineDraw.swaps(chute, chute_pools, drawn, held_ids)
	assert_int(alternatives.size()).is_equal(1)
	assert_array(_keys(alternatives)).is_equal(
		[useful_rare.key(), common[0].key(), common[1].key()]
	)
	var commons_only: Array[MachinePrize] = [common[0], common[1], common[2]]
	alternatives = MachineDraw.swaps(chute, chute_pools, commons_only, held_ids)
	assert_int(alternatives.size()).is_equal(1)
	assert_array(_keys(alternatives)).is_equal(_keys([commons_only]))
	assert_bool(MachineDraw.holds(alternatives[0], held_ids)).is_false()


## REGISTER's swap keeps "3 different types": a fitting upgrade of a type another drop has is
## never swapped in.
func test_the_register_swap_keeps_three_types() -> void:
	var economy: MachinePrize = _register("economy", UpgradeDefinition.Type.ECONOMY)
	var risky: MachinePrize = _register("risky", UpgradeDefinition.Type.RISKY)
	var coupon: MachinePrize = _register("coupon", UpgradeDefinition.Type.COUPON_ENGINE)
	var fitting_risky: MachinePrize = _register("fitting_risky", UpgradeDefinition.Type.RISKY)
	var fitting_slot: MachinePrize = _register("fitting_slot", UpgradeDefinition.Type.SLOT_ENGINE)
	var chute_pools: Array = _pools([economy, risky, coupon, fitting_risky, fitting_slot], [], [])
	var held_ids: Dictionary = {&"fitting_risky": true, &"fitting_slot": true}
	var drawn: Array[MachinePrize] = [economy, risky, coupon]
	var alternatives: Array = MachineDraw.swaps(
		RewardMachine.Chute.REGISTER, chute_pools, drawn, held_ids
	)
	# The last drop (coupon) can take fitting_slot only: fitting_risky would repeat Risky.
	assert_int(alternatives.size()).is_equal(1)
	assert_array(_keys(alternatives)).is_equal([economy.key(), risky.key(), fitting_slot.key()])


## The run's first NEW ITEMS draw holds the newest new arrival at its own rarity: it replaces the
## last drop that isn't the draw's only generally useful product; later draws don't.
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
	var rng: RandomNumberGenerator = _rng(5)
	for draw: int in 50:
		var drawn: Array[MachinePrize] = MachineDraw.draw(
			RewardMachine.Chute.NEW_ITEMS, context, draw % 4, rng
		)
		assert_array(drawn.map(_id)).contains([&"lemon"])
		var useful: Array = drawn.filter(_is_useful)
		assert_array(useful).is_not_empty()
	context.first_new_items = false
	var later: Array[MachinePrize] = [soup, coffee, bread]
	assert_array(MachineDraw.new_arrival_swap(context, later)).is_equal(later)


## UPGRADES offers a product only with a copy in the cart, per rarity it can do: SHELF UPGRADE
## (LEGENDARY) needs 2 copies that can step; GOLDEN copies can't step.
func test_upgrades_pools_and_shelf_upgrade() -> void:
	var context: MachineContext = _context()
	context.deck = Deck.new(null)
	var milk: ItemUpgradeDefinition = load("res://data/item_upgrades/milk.tres")
	var eggs: ItemUpgradeDefinition = load("res://data/item_upgrades/eggs.tres")
	context.deck.add_card(milk.product)
	context.deck.add_card(eggs.golden)
	var pools: Array = MachineDraw.pools(RewardMachine.Chute.UPGRADES, context)
	assert_array(_keys(pools)).is_equal(["upgrade:milk:0", "upgrade:milk:1"])
	context.deck.add_card(milk.big)
	pools = MachineDraw.pools(RewardMachine.Chute.UPGRADES, context)
	assert_array(_keys(pools)).is_equal(["upgrade:milk:0", "upgrade:milk:1", "upgrade:milk:2"])
	var golden_only: MachineContext = _context()
	golden_only.deck = Deck.new(null)
	golden_only.deck.add_card(eggs.golden)
	pools = MachineDraw.pools(RewardMachine.Chute.UPGRADES, golden_only)
	assert_array(_keys(pools)).is_empty()


## The same seed and state draw the same prizes.
func test_the_same_seed_draws_the_same_prizes() -> void:
	var context: MachineContext = _context()
	for chute: int in [RewardMachine.Chute.NEW_ITEMS, RewardMachine.Chute.REGISTER]:
		var first: Array[MachinePrize] = MachineDraw.draw(chute, context, 2, _rng(99))
		var second: Array[MachinePrize] = MachineDraw.draw(chute, context, 2, _rng(99))
		assert_array(_keys([first])).is_equal(_keys([second]))


## MachinePrize keys and its save form.
func test_prize_keys_and_save_form() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var prizes: Array[MachinePrize] = [
		_live_product("milk"),
		MachinePrize.new(MachinePrize.Kind.COUPON, 1, load("%s/repeat.tres" % CARDS_DIR)),
		MachinePrize.new(MachinePrize.Kind.REGISTER, 2, null, _balance.upgrade_pool[3]),
		MachinePrize.new(MachinePrize.Kind.UPGRADE, 2, load("%s/eggs.tres" % CARDS_DIR)),
	]
	assert_str(prizes[0].key()).is_equal("product:milk:1")
	assert_str(prizes[2].key()).is_equal("register:slot_engine:2")
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


func _keys(pools: Array) -> Array[String]:
	var found: Array[String] = []
	for pool: Array in pools:
		for prize: MachinePrize in pool:
			found.append(prize.key())
	return found


func _is_useful(prize: MachinePrize) -> bool:
	return prize.card.generally_useful


func _id(prize: MachinePrize) -> StringName:
	return prize.id()


## The fresh run's snapshot with the live machine.
func _context() -> MachineContext:
	var run: RunState = RunState.new(1, _starter, _balance, RunStock.starting(_starter, _balance))
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


func _live_product(id: String) -> MachinePrize:
	var card: CardDefinition = load("%s/%s.tres" % [CARDS_DIR, id])
	var rarity: int = _balance.machine.product_rarity(card)
	return MachinePrize.new(MachinePrize.Kind.PRODUCT, rarity, card)


func _register(id: String, type: UpgradeDefinition.Type) -> MachinePrize:
	var upgrade: UpgradeDefinition = UpgradeDefinition.new()
	upgrade.id = StringName(id)
	upgrade.type = type
	return MachinePrize.new(MachinePrize.Kind.REGISTER, 0, null, upgrade)
