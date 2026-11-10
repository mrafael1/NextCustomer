extends GdUnitTestSuite
## The machine's hidden per-product draw weight (v1.25, decided with the user on 2026-11-08;
## CardDefinition.draw_weight, MachineDraw.draw_weight): every live product at 1 until the
## end-of-phase balance pass, a tier drawing with its plain card's weight, weight 3 against 1 and
## weight 0 in the forward draw, the guarantee swap and the context, and the same RNG use as an
## index pick when every weight is 1. The exact odds' weights: machine_odds_test.gd.

const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const CARDS_DIR := "res://data/cards"
const MILK_CHAIN := "res://data/item_upgrades/milk.tres"

var _balance: BalanceDefinition
var _starter: DeckDefinition


func before() -> void:
	_balance = load(BALANCE)
	_starter = load(STARTER)


## The live data leaves every product's hidden draw weight at 1 (tuning waits for the end-of-phase
## balance pass); a tier draws with its plain card's weight, and a coupon or perk with 1.
func test_every_product_draws_with_weight_one() -> void:
	for file: String in DirAccess.get_files_at(CARDS_DIR):
		if not file.ends_with(".tres"):
			continue
		var card: CardDefinition = load("%s/%s" % [CARDS_DIR, file])
		assert_int(card.draw_weight).override_failure_message(file).is_equal(1)
	var milk: ItemUpgradeDefinition = load(MILK_CHAIN)
	var weighted: CardDefinition = milk.product.duplicate()
	weighted.draw_weight = 3
	var big: CardDefinition = milk.big.duplicate()
	big.variant_of = weighted
	(
		assert_int(MachineDraw.draw_weight(MachinePrize.new(MachinePrize.Kind.PRODUCT, 1, big)))
		. is_equal(3)
	)
	var coupon: MachinePrize = MachinePrize.new(
		MachinePrize.Kind.COUPON, 1, load("%s/repeat.tres" % CARDS_DIR)
	)
	assert_int(MachineDraw.draw_weight(coupon)).is_equal(1)


## The draw weight (v1.25): among one rarity's candidates, a product of weight 3 comes out three
## times as often as one of weight 1, one of weight 0 never (it leaves the pools, the guarantee and
## the new-arrival hold); with every weight 1 the pick is uniform and uses the RNG as an index pick
## does.
func test_the_draw_weight_picks_among_one_rarity() -> void:
	var heavy: MachinePrize = _weighted("heavy", 3)
	var light: MachinePrize = _weighted("light", 1)
	var counts: Dictionary = {&"heavy": 0, &"light": 0}
	var rng: RandomNumberGenerator = _rng(31)
	var found: Array[MachinePrize] = [heavy, light]
	for _pick: int in 4000:
		counts[MachineDraw.pick(found, rng).id()] += 1
	# 3 : 1 of 4000 picks, seeded.
	assert_int(counts[&"heavy"]).is_between(2850, 3150)
	assert_int(counts[&"heavy"] + counts[&"light"]).is_equal(4000)
	# Weight 1 everywhere: the same pick and RNG state as an index pick.
	var ones: Array[MachinePrize] = [_weighted("a", 1), _weighted("b", 1), _weighted("c", 1)]
	var picked: RandomNumberGenerator = _rng(7)
	var indexed: RandomNumberGenerator = _rng(7)
	for _pick: int in 50:
		var prize: MachinePrize = MachineDraw.pick(ones, picked)
		assert_object(prize).is_same(ones[indexed.randi_range(0, ones.size() - 1)])
	assert_int(picked.state).is_equal(indexed.state)
	# Every weight 0: no pick, so the forward draw ends short as the exact odds do.
	var zeros: Array[MachinePrize] = [_weighted("x", 0), _weighted("y", 0)]
	assert_object(MachineDraw.pick(zeros, _rng(5))).is_null()
	# Weight 0: never drawn, never guaranteed, never held as the new arrival.
	var context: MachineContext = _context()
	var stocked: Array[CardDefinition] = []
	var off: CardDefinition = null
	for card: CardDefinition in context.products:
		var copy: CardDefinition = card.duplicate()
		if off == null and copy.generally_useful:
			copy.draw_weight = 0
			off = copy
		stocked.append(copy)
	context.products = stocked
	context.new_arrival = off
	context.first_new_items = true
	assert_bool(context.drawn_products().has(off)).is_false()
	assert_bool(context.holds_new_arrival()).is_false()
	assert_bool(context.guarantee(RewardMachine.Chute.NEW_ITEMS).has(off.id)).is_false()
	var weight_rng: RandomNumberGenerator = _rng(13)
	for draw: int in 300:
		var drawn: Array[MachinePrize] = MachineDraw.draw(
			RewardMachine.Chute.NEW_ITEMS, context, draw % 5, weight_rng
		)
		for prize: MachinePrize in drawn:
			assert_bool(prize.plain_id() == off.id).is_false()


## The guarantee swap picks among its alternatives by the swapped-in prize's draw weight.
func test_the_guarantee_swap_follows_the_draw_weight() -> void:
	var plain: MachinePrize = _weighted("plain", 1)
	var heavy: MachinePrize = _weighted("heavy", 3)
	var light: MachinePrize = _weighted("light", 1)
	var chute_pools: Array = _pools([plain, heavy, light], [], [])
	var drawn: Array[MachinePrize] = [plain]
	var held_ids: Dictionary = {&"heavy": true, &"light": true}
	var alternatives: Array = MachineDraw.swaps(chute_pools, drawn, held_ids)
	assert_int(alternatives.size()).is_equal(2)
	assert_array(Array(MachineDraw.swap_weights(alternatives, drawn))).is_equal([3, 1])
	assert_array(Array(MachineDraw.swap_weights([drawn], drawn))).is_equal([1])


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


## A COMMON product prize with its own draw weight.
func _weighted(id: String, weight: int) -> MachinePrize:
	var card: CardDefinition = CardDefinition.new()
	card.id = StringName(id)
	card.kind = CardDefinition.Kind.PRODUCT
	card.draw_weight = weight
	return MachinePrize.new(MachinePrize.Kind.PRODUCT, MachinePrize.Rarity.COMMON, card)
