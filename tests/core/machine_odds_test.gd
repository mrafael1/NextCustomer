extends GdUnitTestSuite
## The machine's exact odds (#77, build spec 1.5 and 9; #108's two chutes): MachineOdds against
## the approved draw process (tables generated from draw77.js, tests/fixtures/machine_odds/, whose
## one-kind states a mixed chute draws the same way), against a prize-by-prize enumeration of
## MachineDraw's own steps on random small mixed pools (drop kinds, PREMIUM floors, tiers,
## level-ups), and (issue #77's list, item 3) against the frequencies of many seeded forward draws.

const FIXTURES := "res://tests/fixtures/machine_odds"
const FIXTURE_FILES: Array[String] = [
	"new_items.json", "coupons.json", "register.json", "upgrades.json"
]
## The chute each draw77 fixture's one-kind state is drawn from since #108.
const FIXTURE_CHUTES: Dictionary[String, int] = {
	"new_items": RewardMachine.Chute.NEW_ITEMS,
	"coupons": RewardMachine.Chute.NEW_ITEMS,
	"register": RewardMachine.Chute.UPGRADE,
	"upgrades": RewardMachine.Chute.UPGRADE,
}
const TYPES := {
	"Economy": UpgradeDefinition.Type.ECONOMY,
	"Risky": UpgradeDefinition.Type.RISKY,
	"Coupon engine": UpgradeDefinition.Type.COUPON_ENGINE,
	"Category engine": UpgradeDefinition.Type.CATEGORY_ENGINE,
	"Slot engine": UpgradeDefinition.Type.SLOT_ENGINE,
}
const EXACT := 1e-9
const CARDS_DIR := "res://data/cards"
const CHAINS: Array[String] = ["banana", "milk", "eggs", "coffee"]
const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"

var _balance: BalanceDefinition
var _starter: DeckDefinition


func before() -> void:
	_balance = load(BALANCE)
	_starter = load(STARTER)


## Every fixture state, extensions off: the class enumeration equals draw77's tree to 1e-9. A
## one-kind state draws the same from its mixed chute: a drop whose kind has nothing takes any
## kind. The first COUPONS draw's states are left out: since #108 the first coupon draw draws from
## the first-offer pool only, where draw77 guaranteed one of it.
func test_odds_equal_the_approved_draw() -> void:
	var checked: int = 0
	for file: String in FIXTURE_FILES:
		var fixture: Dictionary = JSON.parse_string(
			FileAccess.get_file_as_string("%s/%s" % [FIXTURES, file])
		)
		for state: Dictionary in fixture["states"]:
			if state["chute"] == "coupons" and state["input"]["first"]:
				continue
			var context: MachineContext = _fixture_context(fixture["odds"], state)
			var chute: int = FIXTURE_CHUTES[state["chute"]]
			var odds: MachineOddsCard = MachineOdds.card(chute, context, int(state["level"]))
			_assert_matches_fixture(odds, state["expected"], state["name"])
			checked += 1
	assert_int(checked).is_equal(44)


## 60 seeded random small mixed pools with every extension on (perk fits, level-ups, a full card,
## the new arrival held, the first coupon draw, chains with tiers, a PREMIUM floor), random weights,
## floors and drop kinds: the class enumeration equals a prize-by-prize enumeration of MachineDraw's
## own steps (drop_kind, land, swaps, new_arrival_swap, the tier roll).
func test_classes_equal_a_prize_by_prize_enumeration() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 108
	for case: int in 60:
		var chute: int = RewardMachine.CHUTES[case % 2]
		var context: MachineContext = _random_context(chute, rng)
		var level: int = rng.randi_range(0, context.machine.max_level())
		var odds: MachineOddsCard = MachineOdds.card(chute, context, level)
		var brute: Dictionary = _brute_force(chute, context, level)
		var label: String = "case %d chute %d level %d" % [case, chute, level]
		_assert_matches(odds, brute, label)


## Exact shares add up to 100% per drop on both chutes; drops 2 to n can be empty when no draw
## reaches drop 2. The tier shares add up too. The machine's odds cards, at every level, leave its
## RNG untouched.
func test_odds_add_up_and_use_no_rng() -> void:
	var run: RunState = _fresh_run()
	var machine: MachineDefinition = _balance.machine
	var checked: int = 0
	for premium: bool in [false, true]:
		var context: MachineContext = MachineContext.from_run(run, machine, false, false, premium)
		for chute: int in RewardMachine.CHUTES:
			for level: int in range(machine.max_level() + 1):
				var odds: MachineOddsCard = MachineOdds.card(chute, context, level)
				if odds.in_draw.is_empty():
					continue
				checked += 1
				for shares: PackedFloat64Array in [
					odds.all_share, odds.first_share, odds.rarity_share, odds.tier_share
				]:
					assert_float(shares[0] + shares[1] + shares[2]).is_equal_approx(1.0, EXACT)
				var rest: float = odds.rest_share[0] + odds.rest_share[1] + odds.rest_share[2]
				assert_bool(is_equal_approx(rest, 1.0) or is_zero_approx(rest)).is_true()
				assert_bool(odds.premium).is_equal(premium)
	assert_int(checked).is_equal(2 * RewardMachine.CHUTES.size() * (machine.max_level() + 1))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 67
	var state_before: int = rng.state
	for shift_number: int in range(1, run.shift_count()):
		run.history = [ShiftRecord.new(shift_number, 10, 20)]
		var reward_machine: RewardMachine = RewardMachine.new(machine, rng)
		for chute: int in RewardMachine.CHUTES:
			var odds: MachineOddsCard = reward_machine.chute_info(run, chute).odds
			assert_int(odds.level).is_equal(machine.odds_level_after(shift_number))
	assert_int(rng.state).is_equal(state_before)


## At a level with a first-drop floor, item upgrades alone (no perk to draw) with no plain copy in
## the cart (only BIG and GOLDEN ones): drop 1 can't reach the floor, so the card notes the fall;
## with a single copy to step (a one-prize draw) the printed shares are over every drop.
func test_item_upgrades_without_plain_copies_note_the_floor_falling() -> void:
	var machine: MachineDefinition = _balance.machine
	var top: int = machine.max_level()
	assert_int(machine.odds_level(top).first_drop_min_rarity).is_equal(1)
	var no_plain: RunState = _fresh_run()
	no_plain.deck = _deck([["banana", 1], ["milk", 1], ["eggs", 2]])
	var context: MachineContext = _without_perks(no_plain)
	var odds: MachineOddsCard = _assert_frequencies(
		RewardMachine.Chute.UPGRADE, context, top, 5000, "no plain copies"
	)
	assert_float(odds.first_share[MachinePrize.Rarity.COMMON]).is_greater(0.0)
	assert_array(odds.notes).contains([MachineOddsCard.NOTE_FLOOR_FALLS])
	var single: RunState = _fresh_run()
	single.deck = _deck([["banana", 1]])
	var one_copy: MachineContext = _without_perks(single)
	var single_odds: MachineOddsCard = MachineOdds.card(RewardMachine.Chute.UPGRADE, one_copy, top)
	assert_float(single_odds.p_short).is_equal_approx(1.0, EXACT)
	assert_array(Array(single_odds.rarity_share)).is_equal(Array(single_odds.all_share))
	var printed: PackedFloat64Array = single_odds.rarity_share
	assert_float(printed[0] + printed[1] + printed[2]).is_equal_approx(1.0, EXACT)
	assert_array(single_odds.notes).contains([MachineOddsCard.NOTE_FLOOR_FALLS])
	# A fresh NEW ITEMS draw meets its floor: no note.
	var fresh: MachineContext = MachineContext.from_run(_fresh_run(), machine, false, true)
	var met: MachineOddsCard = MachineOdds.card(RewardMachine.Chute.NEW_ITEMS, fresh, top)
	assert_array(met.notes).not_contains([MachineOddsCard.NOTE_FLOOR_FALLS])


## Issue #77 item 3: over many seeded draws, rarity, prize and tier frequencies match the card, at
## odds levels 0 to 3 (20,000 draws each), on the fresh stock's first coupon draw under R3b: no
## Legendary product and only first-offer coupons (none LEGENDARY), so every LEGENDARY roll falls
## (the card says so).
func test_fresh_new_items_frequencies_match_the_card() -> void:
	var run: RunState = _fresh_run()
	var context: MachineContext = MachineContext.from_run(run, _balance.machine, false, true)
	for level: int in range(4):
		var odds: MachineOddsCard = _assert_frequencies(
			RewardMachine.Chute.NEW_ITEMS, context, level, 20000, "fresh NEW ITEMS %d" % level
		)
		assert_array(odds.notes).contains([MachineOddsCard.NOTE_LEGENDARY_NONE_IN_STOCK])
		assert_float(odds.p_legendary).is_equal(0.0)
		assert_float(odds.p_guarantee_held).is_equal_approx(1.0, EXACT)
		var weights: PackedInt32Array = _balance.machine.odds_level(level).tier_weights()
		var total: float = weights[0] + weights[1] + weights[2]
		for tier: int in 3:
			assert_float(odds.tier_share[tier]).is_equal_approx(weights[tier] / total, EXACT)
		if level == 3:
			assert_float(odds.first_share[MachinePrize.Rarity.COMMON]).is_equal(0.0)
			assert_int(odds.first_drop_min_rarity).is_equal(1)
			assert_array(Array(odds.rarity_share)).is_equal(Array(odds.rest_share))


## The other NEW ITEMS states (5,000 draws each): a two-aisle stock without Legendaries, the first
## NEW ITEMS draw with a Legendary new arrival (held, in one of its tiers), the first coupon draw
## and a later one (one coupon a draw), and a PREMIUM draw (RARE or better, BIG or better).
func test_other_new_items_frequencies_match_the_card() -> void:
	var machine: MachineDefinition = _balance.machine
	var run: RunState = _fresh_run()
	# Two aisles without a Legendary product.
	var two_aisles: RunState = _fresh_run()
	two_aisles.stock = _stock_with_aisles([&"cold_cases", &"snacks"])
	var no_legendary: MachineContext = MachineContext.from_run(two_aisles, machine, false, true)
	var products: Array[MachinePrize] = no_legendary.pools(RewardMachine.Chute.NEW_ITEMS)[2]
	assert_array(products).is_empty()
	for level: int in [0, 3]:
		_assert_frequencies(RewardMachine.Chute.NEW_ITEMS, no_legendary, level, 5000, "two aisles")
	# The first NEW ITEMS draw holds a Legendary new arrival.
	var arrival: RunState = _fresh_run()
	var lemon: CardDefinition = load("%s/lemon.tres" % CARDS_DIR)
	var cards: Array[CardDefinition] = arrival.stock.cards.duplicate()
	cards.append(lemon)
	var arrivals: Array[CardDefinition] = [lemon]
	arrival.stock = RunStock.from_saved(cards, arrival.stock.aisle_ids, true, arrivals)
	var held: MachineContext = MachineContext.from_run(arrival, machine, false, false)
	for level: int in [0, 3]:
		var odds: MachineOddsCard = _assert_frequencies(
			RewardMachine.Chute.NEW_ITEMS, held, level, 5000, "new arrival"
		)
		var lemon_chance: float = 0.0
		for id: String in ["lemon", "lemon_big", "lemon_golden"]:
			lemon_chance += odds.in_draw.get("product:%s:2" % id, 0.0)
		assert_float(lemon_chance).is_equal_approx(1.0, EXACT)
		assert_array(odds.notes).contains([MachineOddsCard.NOTE_NEW_ARRIVAL_HELD])
	# The first coupon draw and a later one: one coupon a draw, first-offer ones first.
	for first_done: bool in [false, true]:
		var coupons: MachineContext = MachineContext.from_run(run, machine, first_done, true)
		for level: int in [0, 2]:
			var odds: MachineOddsCard = _assert_frequencies(
				RewardMachine.Chute.NEW_ITEMS, coupons, level, 5000, "coupons"
			)
			var coupon_chance: float = 0.0
			for card: CardDefinition in _balance.coupon_pool:
				for rarity: int in 3:
					var chance: float = odds.in_draw.get("coupon:%s:%d" % [card.id, rarity], 0.0)
					coupon_chance += chance
					if chance > 0.0 and not first_done:
						assert_bool(_balance.first_offer_pool.has(card)).is_true()
			assert_float(coupon_chance).is_equal_approx(1.0, EXACT)
	# PREMIUM: every drop RARE or better, products BIG or better.
	var premium: MachineContext = MachineContext.from_run(run, machine, true, true, true)
	for level: int in [0, 3]:
		var odds: MachineOddsCard = _assert_frequencies(
			RewardMachine.Chute.NEW_ITEMS, premium, level, 5000, "premium"
		)
		assert_bool(odds.premium).is_true()
		assert_int(odds.min_rarity).is_equal(1)
		assert_float(odds.all_share[MachinePrize.Rarity.COMMON]).is_equal(0.0)
		assert_float(odds.tier_share[CardDefinition.Tier.PLAIN]).is_equal(0.0)
		assert_array(odds.notes).not_contains([MachineOddsCard.NOTE_FLOOR_FALLS])


## The UPGRADE states (5,000 draws each): 0 / 1 / 2 perks owned (their level-ups drawn too), a full
## card (level-ups and item upgrades only), exactly one new perk that fits, one perk left and
## nothing to improve (short draws), item upgrades with no shelf candidate, and PREMIUM.
func test_upgrade_frequencies_match_the_card() -> void:
	var started: int = Time.get_ticks_msec()
	var machine: MachineDefinition = _balance.machine
	var owned: Array[UpgradeDefinition] = []
	for index: int in 3:
		var perks: RunState = _fresh_run()
		perks.upgrades = owned.duplicate()
		var context: MachineContext = MachineContext.from_run(perks, machine, false, false)
		_assert_frequencies(RewardMachine.Chute.UPGRADE, context, 1, 5000, "perks %d" % index)
		owned.append(_balance.upgrade_pool[index])
	# A full card: no new perk, the owned perks' level-ups.
	var full: RunState = _fresh_run()
	full.upgrades = owned.duplicate()
	var full_card: MachineContext = MachineContext.from_run(full, machine, false, false)
	full_card.card_full = true
	var full_odds: MachineOddsCard = _assert_frequencies(
		RewardMachine.Chute.UPGRADE, full_card, 2, 5000, "full card"
	)
	for key: String in full_odds.in_draw:
		if key.begins_with("register:"):
			assert_str(key).contains("_lv2:")
	# Exactly one new perk fits the cart.
	var fits_one: RunState = _fresh_run()
	fits_one.deck.add_card(load("%s/repeat.tres" % CARDS_DIR))
	var deck_cards: Array[CardDefinition] = []
	for card: CardInstance in fits_one.deck.cards:
		deck_cards.append(card.definition)
	var fitting: Array[UpgradeDefinition] = []
	# The five perks from before #108's family perks (whose fit reads the deck's families).
	var classic_pool: Array[UpgradeDefinition] = _upgrades(
		["coupon_engine", "category_engine", "extra_redraw", "slot_engine", "big_basket"]
	)
	for upgrade: UpgradeDefinition in classic_pool:
		if upgrade.fits(deck_cards):
			fitting.append(upgrade)
	assert_array(fitting).is_not_empty()
	fits_one.upgrades = fitting.slice(1)
	var one_fits: MachineContext = MachineContext.from_run(fits_one, machine, false, false)
	one_fits.upgrade_pool = classic_pool
	assert_int(one_fits.guarantee(RewardMachine.Chute.UPGRADE).size()).is_equal(1)
	_assert_frequencies(RewardMachine.Chute.UPGRADE, one_fits, 0, 5000, "one fits")
	# One new perk left, every owned one at its top level, nothing to improve: short draws.
	var one_left: RunState = _fresh_run()
	one_left.deck = _deck([["eggs", 2]])
	one_left.upgrades = _upgrades(
		["coupon_engine_lv3", "category_engine_lv3", "extra_redraw_lv3", "slot_engine_lv3"]
	)
	var short: MachineContext = MachineContext.from_run(one_left, machine, false, false)
	short.upgrade_pool = classic_pool
	var short_odds: MachineOddsCard = _assert_frequencies(
		RewardMachine.Chute.UPGRADE, short, 2, 5000, "one perk left"
	)
	assert_float(short_odds.p_short).is_equal_approx(1.0, EXACT)
	assert_float(short_odds.in_draw["register:big_basket:0"]).is_equal_approx(1.0, EXACT)
	assert_array(short_odds.notes).contains([MachineOddsCard.NOTE_SHORT_DRAW])
	# Item upgrades with a cart that has no shelf candidate (no perk to draw).
	var no_shelf: RunState = _fresh_run()
	no_shelf.deck = _deck([["milk", 1], ["milk", 2], ["eggs", 0], ["coffee", 2], ["bread", 0]])
	var items: MachineContext = _without_perks(no_shelf)
	assert_array(items.pools(RewardMachine.Chute.UPGRADE)[2]).is_empty()
	for level: int in [0, 3]:
		var odds: MachineOddsCard = _assert_frequencies(
			RewardMachine.Chute.UPGRADE, items, level, 5000, "no shelf"
		)
		assert_array(odds.notes).contains([MachineOddsCard.NOTE_LEGENDARY_EMPTY])
	# PREMIUM.
	var premium: MachineContext = MachineContext.from_run(_fresh_run(), machine, false, false, true)
	var premium_odds: MachineOddsCard = _assert_frequencies(
		RewardMachine.Chute.UPGRADE, premium, 1, 5000, "premium"
	)
	assert_float(premium_odds.all_share[MachinePrize.Rarity.COMMON]).is_equal(0.0)
	print("machine odds: UPGRADE states took %d ms" % (Time.get_ticks_msec() - started))


## Forward draws from one prebuilt context, compared value by value with the card:
## 4·sqrt(p(1−p)/N) + 0.002 each. Forward draws already hold their tier, so they aren't split.
func _assert_frequencies(
	chute: int, context: MachineContext, level: int, draws: int, label: String
) -> MachineOddsCard:
	var odds: MachineOddsCard = MachineOdds.card(chute, context, level)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([label, level])
	var seen: Dictionary = _empty_stats()
	var held_ids: Dictionary = context.guarantee(chute)
	for _draw: int in draws:
		var drawn: Array[MachinePrize] = MachineDraw.draw(chute, context, level, rng)
		_add_draw(seen, drawn, 1.0, MachineDraw.holds(drawn, held_ids), context)
	var found: Dictionary = _finished(seen, 1.0 / draws)
	var where: String = "%s level %d" % [label, level]
	for key: String in ["p_rare_plus", "p_legendary", "p_short", "p_held"]:
		_assert_close(found[key], _card_value(odds, key), draws, "%s %s" % [where, key])
	for rarity: int in 3:
		_assert_close(found["share"][rarity], odds.all_share[rarity], draws, where + " share")
		_assert_close(found["first"][rarity], odds.first_share[rarity], draws, where + " first")
		_assert_close(found["rest"][rarity], odds.rest_share[rarity], draws, where + " rest")
	var keys: Dictionary = found["in_draw"].duplicate()
	keys.merge(odds.in_draw)
	for key: String in keys:
		_assert_close(found["in_draw"].get(key, 0.0), odds.in_draw.get(key, 0.0), draws, key)
	return odds


func _assert_close(seen: float, expected: float, draws: int, what: String) -> void:
	var tolerance: float = 4.0 * sqrt(expected * (1.0 - expected) / draws) + 0.002
	(
		assert_float(seen)
		. override_failure_message("%s: seen %f, card %f" % [what, seen, expected])
		. is_equal_approx(expected, tolerance)
	)


func _card_value(odds: MachineOddsCard, key: String) -> float:
	match key:
		"p_rare_plus":
			return odds.p_rare_plus
		"p_legendary":
			return odds.p_legendary
		"p_short":
			return odds.p_short
	return odds.p_guarantee_held


func _assert_matches_fixture(odds: MachineOddsCard, expected: Dictionary, label: String) -> void:
	var as_found: Dictionary = {
		"share": expected["share"],
		"first": expected["first"],
		"rest": expected["rest"],
		"p_rare_plus": expected["p_rare_plus"],
		"p_legendary": expected["p_legendary"],
		"p_short": expected["p_short"],
		"p_held": expected["p_held"],
		"in_draw": expected["in_draw"],
	}
	_assert_matches(odds, as_found, label)
	assert_bool(odds.guarded).override_failure_message(label).is_equal(expected["guarded"])


func _assert_matches(odds: MachineOddsCard, expected: Dictionary, label: String) -> void:
	for rarity: int in 3:
		_assert_exact(odds.all_share[rarity], expected["share"][rarity], label + " share")
		_assert_exact(odds.first_share[rarity], expected["first"][rarity], label + " first")
		_assert_exact(odds.rest_share[rarity], expected["rest"][rarity], label + " rest")
	_assert_exact(odds.p_rare_plus, expected["p_rare_plus"], label + " rare+")
	_assert_exact(odds.p_legendary, expected["p_legendary"], label + " legendary")
	_assert_exact(odds.p_short, expected["p_short"], label + " short")
	_assert_exact(odds.p_guarantee_held, expected["p_held"], label + " held")
	var expected_draw: Dictionary = expected["in_draw"]
	for key: String in expected_draw:
		_assert_exact(odds.in_draw.get(key, 0.0), expected_draw[key], "%s %s" % [label, key])
	for key: String in odds.in_draw:
		_assert_exact(odds.in_draw[key], expected_draw.get(key, 0.0), "%s %s" % [label, key])


func _assert_exact(found: float, expected: float, what: String) -> void:
	(
		assert_float(found)
		. override_failure_message("%s: %.12f, expected %.12f" % [what, found, expected])
		. is_equal_approx(expected, EXACT)
	)


## The prize-by-prize tree (draw77 tree) on MachineDraw's own steps.
func _brute_force(chute: int, context: MachineContext, level: int) -> Dictionary:
	var stats: Dictionary = _empty_stats()
	var drawn: Array[MachinePrize] = []
	_brute_step(chute, context, level, drawn, 1.0, stats)
	return _finished(stats, 1.0)


func _brute_step(
	chute: int,
	context: MachineContext,
	level: int,
	drawn: Array[MachinePrize],
	chance: float,
	stats: Dictionary
) -> void:
	var drop: int = drawn.size()
	var floor_rarity: int = context.min_rarity()
	var drop_weights: PackedInt32Array = MachineDraw.weights(
		context.machine, level, drop, floor_rarity
	)
	var total: int = drop_weights[0] + drop_weights[1] + drop_weights[2]
	if drop >= context.machine.prizes_per_visit or total <= 0:
		_brute_finish(chute, context, level, drawn, chance, stats)
		return
	var chute_pools: Array = context.pools(chute)
	var kind: int = MachineDraw.drop_kind(chute, context.machine, drop)
	for rarity: int in 3:
		if drop_weights[rarity] <= 0:
			continue
		var rolled: float = chance * drop_weights[rarity] / total
		var found: Array[MachinePrize] = MachineDraw.land(
			chute_pools, rarity, drawn, kind, floor_rarity
		)
		if found.is_empty():
			_brute_finish(chute, context, level, drawn, rolled, stats)
			continue
		for prize: MachinePrize in found:
			var next: Array[MachinePrize] = drawn.duplicate()
			next.append(prize)
			_brute_step(chute, context, level, next, rolled / found.size(), stats)


func _brute_finish(
	chute: int,
	context: MachineContext,
	level: int,
	drawn: Array[MachinePrize],
	chance: float,
	stats: Dictionary
) -> void:
	var held_ids: Dictionary = context.guarantee(chute)
	var alternatives: Array = MachineDraw.swaps(context.pools(chute), drawn, held_ids)
	for alternative: Array[MachinePrize] in alternatives:
		var final: Array[MachinePrize] = alternative
		if chute == RewardMachine.Chute.NEW_ITEMS:
			final = MachineDraw.new_arrival_swap(context, alternative)
		var weight: float = chance / alternatives.size()
		var holds: bool = MachineDraw.holds(final, held_ids)
		if chute != RewardMachine.Chute.NEW_ITEMS:
			_add_draw(stats, final, weight, holds, context)
			continue
		var tiers: PackedInt32Array = context.machine.odds_level(level).tier_weights(
			context.min_tier()
		)
		_add_tiered(stats, final, weight, holds, context, tiers)


## Adds one finished NEW ITEMS draw as every tier combination of its products with a chain (from
## drop `start` on), each with its chance from the tier weights (the forward draw's roll_tiers,
## enumerated).
func _add_tiered(
	stats: Dictionary,
	drawn: Array[MachinePrize],
	chance: float,
	held: bool,
	context: MachineContext,
	tiers: PackedInt32Array,
	start: int = 0
) -> void:
	var total: int = tiers[0] + tiers[1] + tiers[2]
	for index: int in range(start, drawn.size()):
		var chain: ItemUpgradeDefinition = MachineDraw.chain_of(context.machine, drawn[index])
		if chain == null:
			continue
		for tier: int in 3:
			if tiers[tier] <= 0 or chain.tiers()[tier] == null:
				continue
			var tiered: Array[MachinePrize] = drawn.duplicate()
			tiered[index] = MachinePrize.new(
				MachinePrize.Kind.PRODUCT, drawn[index].rarity, chain.tiers()[tier]
			)
			var tier_chance: float = chance * tiers[tier] / total
			_add_tiered(stats, tiered, tier_chance, held, context, tiers, index + 1)
		return
	_add_draw(stats, drawn, chance, held, context)


func _empty_stats() -> Dictionary:
	return {
		"share": [0.0, 0.0, 0.0],
		"first": [0.0, 0.0, 0.0],
		"rest": [0.0, 0.0, 0.0],
		"p_rare_plus": 0.0,
		"p_legendary": 0.0,
		"p_short": 0.0,
		"p_held": 0.0,
		"in_draw": {},
	}


## Adds one draw to the sums the way draw77's stats does.
func _add_draw(
	stats: Dictionary,
	drawn: Array[MachinePrize],
	chance: float,
	held: bool,
	context: MachineContext
) -> void:
	var count: int = drawn.size()
	if count < context.machine.prizes_per_visit:
		stats["p_short"] += chance
	if held:
		stats["p_held"] += chance
	if drawn.any(func(prize: MachinePrize) -> bool: return prize.rarity >= 1):
		stats["p_rare_plus"] += chance
	if drawn.any(func(prize: MachinePrize) -> bool: return prize.rarity == 2):
		stats["p_legendary"] += chance
	for index: int in count:
		var prize: MachinePrize = drawn[index]
		stats["share"][prize.rarity] += chance / count
		if index == 0:
			stats["first"][prize.rarity] += chance
		else:
			stats["rest"][prize.rarity] += chance / (count - 1)
		stats["in_draw"][prize.key()] = stats["in_draw"].get(prize.key(), 0.0) + chance


## The sums scaled by `scale`, the shares normalised.
func _finished(stats: Dictionary, scale: float) -> Dictionary:
	var found: Dictionary = stats.duplicate(true)
	for key: String in ["share", "first", "rest"]:
		var shares: Array = found[key]
		var total: float = shares[0] + shares[1] + shares[2]
		if total > 0.0:
			found[key] = shares.map(func(share: float) -> float: return share / total)
	for key: String in ["p_rare_plus", "p_legendary", "p_short", "p_held"]:
		found[key] = found[key] * scale
	var in_draw: Dictionary = found["in_draw"]
	for key: String in in_draw:
		in_draw[key] = in_draw[key] * scale
	return found


func _fixture_context(odds: Array, state: Dictionary) -> MachineContext:
	var context: MachineContext = MachineContext.new()
	context.machine = _odds_machine(odds)
	context.deck = Deck.new(null)
	var input: Dictionary = state["input"]
	match state["chute"]:
		"new_items":
			for entry: Dictionary in input["stock"]:
				var card: CardDefinition = _card(entry["id"], CardDefinition.Kind.PRODUCT)
				card.generally_useful = entry["gu"]
				context.products.append(card)
				_rank(
					context.machine.rare_products, context.machine.legendary_products, card, entry
				)
		"coupons":
			context.first_coupons = input["first"]
			for entry: Dictionary in input["coupons"]:
				var card: CardDefinition = _card(entry["id"], CardDefinition.Kind.COUPON)
				context.coupons.append(card)
				if entry["first_offer"]:
					context.first_offer_pool.append(card)
				_rank(context.machine.rare_coupons, context.machine.legendary_coupons, card, entry)
		"register":
			for entry: Dictionary in input["upgrades"]:
				var upgrade: UpgradeDefinition = UpgradeDefinition.new()
				upgrade.id = StringName(entry["id"])
				upgrade.type = TYPES[entry["type"]] as UpgradeDefinition.Type
				context.upgrade_pool.append(upgrade)
				if input["owned"].has(entry["id"]):
					context.owned.append(upgrade)
				_rank(
					context.machine.rare_upgrades,
					context.machine.legendary_upgrades,
					upgrade,
					entry
				)
		"upgrades":
			context.machine.item_upgrades = _chains()
			var cart: Array = []
			for entry: Dictionary in input["cart"]:
				cart.append([entry["id"], int(entry["tier"])])
			context.deck = _deck(cart)
	return context


func _rank(rare: Array, legendary: Array, item: Resource, entry: Dictionary) -> void:
	match int(entry["rarity"]):
		1:
			rare.append(item)
		2:
			legendary.append(item)


## A machine with these odds (draw77 ODDS: the top level's drop 1 rolls RARE or better), the live
## drop kinds and no tier roll (its chains, if any, are plain only).
func _odds_machine(odds: Array) -> MachineDefinition:
	var machine: MachineDefinition = MachineDefinition.new()
	machine.prizes_per_visit = 3
	machine.shelf_min_copies = 2
	machine.new_arrival_first_visit = true
	machine.coupons_per_draw = 1
	machine.loyalty_per_draw = 1
	machine.item_upgrades_per_draw = 1
	for index: int in odds.size():
		var level: MachineOddsLevel = MachineOddsLevel.new()
		level.common_weight = int(odds[index][0])
		level.rare_weight = int(odds[index][1])
		level.legendary_weight = int(odds[index][2])
		level.first_drop_min_rarity = 1 if index == odds.size() - 1 else 0
		machine.odds_levels.append(level)
	return machine


## A random small mixed pool for the chute, with random weights (some zero), floors, drop kinds,
## tier weights and a PREMIUM visit now and then.
func _random_context(chute: int, rng: RandomNumberGenerator) -> MachineContext:
	var context: MachineContext = MachineContext.new()
	var machine: MachineDefinition = MachineDefinition.new()
	machine.prizes_per_visit = rng.randi_range(2, 3)
	machine.shelf_min_copies = 2
	machine.new_arrival_first_visit = true
	machine.coupons_per_draw = rng.randi_range(0, 2)
	machine.loyalty_per_draw = rng.randi_range(0, 2)
	machine.item_upgrades_per_draw = rng.randi_range(0, 1)
	machine.premium_min_rarity = rng.randi_range(0, 2)
	machine.premium_min_tier = rng.randi_range(0, 2)
	machine.item_upgrades = _chains()
	for index: int in rng.randi_range(1, 4):
		var level: MachineOddsLevel = MachineOddsLevel.new()
		level.common_weight = rng.randi_range(0, 9)
		level.rare_weight = rng.randi_range(0, 9)
		level.legendary_weight = rng.randi_range(1, 9)
		level.first_drop_min_rarity = rng.randi_range(0, 2) if rng.randf() < 0.4 else 0
		level.plain_weight = rng.randi_range(0, 9)
		level.big_weight = rng.randi_range(0, 9)
		level.golden_weight = rng.randi_range(0, 3)
		machine.odds_levels.append(level)
	context.machine = machine
	context.premium = rng.randf() < 0.3
	context.deck = Deck.new(null)
	match chute:
		RewardMachine.Chute.NEW_ITEMS:
			_random_new_items(context, rng)
		RewardMachine.Chute.UPGRADE:
			_random_upgrade(context, rng)
	return context


## Products (made-up ones and live ones with a chain) and coupons, the first coupon draw and the
## new arrival held now and then.
func _random_new_items(context: MachineContext, rng: RandomNumberGenerator) -> void:
	var machine: MachineDefinition = context.machine
	for index: int in rng.randi_range(0, 4):
		var card: CardDefinition = _card("p%d" % index, CardDefinition.Kind.PRODUCT)
		card.generally_useful = rng.randf() < 0.4
		context.products.append(card)
		_rank(machine.rare_products, machine.legendary_products, card, _rarity(rng))
	for product: String in CHAINS:
		if rng.randf() < 0.4:
			var card: CardDefinition = load("%s/%s.tres" % [CARDS_DIR, product])
			context.products.append(card)
			_rank(machine.rare_products, machine.legendary_products, card, _rarity(rng))
	context.first_coupons = rng.randf() < 0.5
	for index: int in rng.randi_range(0, 3):
		var card: CardDefinition = _card("c%d" % index, CardDefinition.Kind.COUPON)
		context.coupons.append(card)
		if rng.randf() < 0.5:
			context.first_offer_pool.append(card)
		_rank(machine.rare_coupons, machine.legendary_coupons, card, _rarity(rng))
	if context.products.is_empty():
		context.products.append(_card("p_only", CardDefinition.Kind.PRODUCT))
	context.first_new_items = rng.randf() < 0.7
	context.new_arrival = context.products[rng.randi_range(0, context.products.size() - 1)]


## New perks (some fitting, some owned, an owned one with a next level now and then), a full card
## now and then, and a cart of chain copies to step.
func _random_upgrade(context: MachineContext, rng: RandomNumberGenerator) -> void:
	var machine: MachineDefinition = context.machine
	var types: Array[UpgradeDefinition.Type] = [
		UpgradeDefinition.Type.ECONOMY,
		UpgradeDefinition.Type.RISKY,
		UpgradeDefinition.Type.SLOT_ENGINE
	]
	for index: int in rng.randi_range(0, 5):
		var upgrade: FitUpgrade = FitUpgrade.new()
		upgrade.id = StringName("u%d" % index)
		upgrade.type = types[rng.randi_range(0, 2)]
		upgrade.fit = rng.randf() < 0.3
		context.upgrade_pool.append(upgrade)
		_rank(machine.rare_upgrades, machine.legendary_upgrades, upgrade, _rarity(rng))
		if rng.randf() < 0.25:
			context.owned.append(upgrade)
			if rng.randf() < 0.6:
				var next: FitUpgrade = FitUpgrade.new()
				next.id = StringName("u%d_lv2" % index)
				next.family_id = upgrade.id
				next.level = 2
				next.type = upgrade.type
				upgrade.next_level = next
	context.card_full = rng.randf() < 0.2
	var cart: Array = []
	for index: int in rng.randi_range(0, 4):
		cart.append([CHAINS[rng.randi_range(0, 3)], rng.randi_range(0, 2)])
	context.deck = _deck(cart)


func _rarity(rng: RandomNumberGenerator) -> Dictionary:
	return {"rarity": rng.randi_range(0, 2)}


func _card(id: String, kind: CardDefinition.Kind) -> CardDefinition:
	var card: CardDefinition = CardDefinition.new()
	card.id = StringName(id)
	card.kind = kind
	return card


func _chains() -> Array[ItemUpgradeDefinition]:
	var found: Array[ItemUpgradeDefinition] = []
	for product: String in CHAINS:
		found.append(load("res://data/item_upgrades/%s.tres" % product))
	return found


## A deck of live cards from [id, tier] pairs (tier 0 plain, 1 BIG, 2 GOLDEN).
func _deck(cart: Array) -> Deck:
	var deck: Deck = Deck.new(null)
	for entry: Array in cart:
		var card: CardDefinition = load("%s/%s.tres" % [CARDS_DIR, entry[0]])
		if CHAINS.has(entry[0]):
			var chain: ItemUpgradeDefinition = load("res://data/item_upgrades/%s.tres" % entry[0])
			card = chain.tiers()[int(entry[1])]
		deck.add_card(card)
	return deck


func _upgrades(ids: Array[String]) -> Array[UpgradeDefinition]:
	var found: Array[UpgradeDefinition] = []
	for id: String in ids:
		found.append(load("res://data/upgrades/%s.tres" % id))
	return found


func _fresh_run() -> RunState:
	return RunState.new(5, _starter, _balance, RunStock.starting(_balance))


## The run's machine context with no perk to draw (item upgrades only).
func _without_perks(run: RunState) -> MachineContext:
	var context: MachineContext = MachineContext.from_run(run, _balance.machine, false, false)
	var none: Array[UpgradeDefinition] = []
	context.upgrade_pool = none
	return context


## A stock of the staples and every product of the listed aisles (all capsules unlocked).
func _stock_with_aisles(aisle_ids: Array[StringName]) -> RunStock:
	var cards: Array[CardDefinition] = RunStock.staples(_balance)
	for aisle: AisleDefinition in _balance.aisles:
		if aisle_ids.has(aisle.id):
			for card: CardDefinition in aisle.base_cards + aisle.capsule_cards:
				if not cards.has(card):
					cards.append(card)
	cards.append_array(_balance.coupon_pool)
	var arrivals: Array[CardDefinition] = []
	return RunStock.from_saved(cards, aisle_ids, false, arrivals)


## An upgrade whose fit is set by the test.
class FitUpgrade:
	extends UpgradeDefinition

	var fit: bool = false

	func fits(
		_deck: Array[CardDefinition], _families: PackedStringArray = PackedStringArray()
	) -> bool:
		return fit
