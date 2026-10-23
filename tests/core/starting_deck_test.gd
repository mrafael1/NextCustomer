extends GdUnitTestSuite
## The random starting deck (v0.49 and v0.51, full build plan 5.2): the recipe's 4 core cards
## (the staples Banana x2, Milk, Eggs), 1 coupon drawn from the run's coupon pool and 8 products
## drawn from the run's stock, only products with an item-tier chain, at most 2 copies of a card,
## on the run seed's own derived stream, so the run's RNG and a new profile's stock are unchanged.

const RECIPE := "res://data/decks/random_starter.tres"
const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const SEEDS := 40
## The seeds the build-fit rates are measured on.
const FIT_SEEDS := 200

var _balance: BalanceDefinition
var _recipe: DeckDefinition
var _stock: RunStock


func before_test() -> void:
	_balance = load(BALANCE)
	_recipe = load(RECIPE)
	_stock = RunStock.starting(_balance)


func test_the_recipe_is_four_staples_a_coupon_and_eight_at_most_two_copies() -> void:
	assert_bool(_recipe.is_recipe()).is_true()
	assert_bool((load(STARTER) as DeckDefinition).is_recipe()).is_false()
	assert_array(_ids(_recipe.core_cards)).is_equal(["banana", "banana", "milk", "eggs"])
	assert_array(_recipe.cards).is_empty()
	assert_int(_recipe.random_coupon_count).is_equal(1)
	assert_int(_recipe.random_count).is_equal(8)
	assert_int(_recipe.copy_max).is_equal(2)


func test_a_deal_is_the_core_cards_then_a_coupon_then_eight_products() -> void:
	for seed_value: int in SEEDS:
		var dealt: DeckDefinition = _deal(seed_value)
		var where: String = "seed %d" % seed_value
		assert_int(dealt.cards.size()).override_failure_message(where).is_equal(13)
		assert_array(dealt.cards.slice(0, 4)).override_failure_message(where).is_equal(
			_recipe.core_cards
		)
		var coupon: CardDefinition = dealt.cards[4]
		assert_bool(coupon.is_coupon()).override_failure_message(where).is_true()
		assert_bool(_balance.coupon_pool.has(coupon)).override_failure_message(where).is_true()
		for card: CardDefinition in dealt.cards.slice(5):
			assert_bool(card.is_product()).override_failure_message(where).is_true()
		assert_array(StartingDeck.picks(dealt)).is_equal(dealt.cards.slice(4))
		assert_str(String(dealt.id)).is_equal("random_starter")
		assert_bool(dealt.is_recipe()).is_true()
	# The recipe itself is never changed.
	assert_array(_recipe.cards).is_empty()
	assert_array(StartingDeck.picks(load(STARTER))).is_empty()


## v0.51: the coupon is drawn from the whole coupon pool, equally likely, on the deal's stream
## before the products: over 200 seeds every pool coupon shows up, and the stream's first draw
## picks it.
func test_the_coupon_is_random_from_the_coupon_pool() -> void:
	assert_array(StartingDeck.drawable_coupons(_stock)).is_equal(_balance.coupon_pool)
	var seen: Dictionary[CardDefinition, int] = {}
	for seed_value: int in FIT_SEEDS:
		var coupon: CardDefinition = _deal(seed_value).cards[4]
		seen[coupon] = int(seen.get(coupon, 0)) + 1
		var stream: RandomNumberGenerator = _stream(seed_value)
		var first: int = stream.randi_range(0, _balance.coupon_pool.size() - 1)
		assert_object(coupon).is_same(_balance.coupon_pool[first])
	assert_array(seen.keys()).contains_exactly_in_any_order(_balance.coupon_pool)


func test_no_product_passes_two_copies() -> void:
	for seed_value: int in SEEDS:
		var counts: Dictionary[CardDefinition, int] = {}
		for card: CardDefinition in _deal(seed_value).cards:
			counts[card] = int(counts.get(card, 0)) + 1
		for card: CardDefinition in counts:
			(
				assert_int(counts[card])
				. override_failure_message("seed %d: %s" % [seed_value, card.id])
				. is_less_equal(2)
			)


## The drawn cards are stocked products that UPGRADES can step (a chain's plain card), never a
## coupon, a tier or a capsule product with no chain.
func test_only_stocked_products_with_a_chain_are_drawn() -> void:
	var chained: Array[CardDefinition] = []
	for chain: ItemUpgradeDefinition in _balance.machine.item_upgrades:
		chained.append(chain.product)
	var drawable: Array[CardDefinition] = StartingDeck.drawable(
		_stock, _balance.machine.item_upgrades
	)
	assert_int(drawable.size()).is_equal(20)
	var seen: Dictionary[CardDefinition, bool] = {}
	for seed_value: int in SEEDS:
		for card: CardDefinition in _deal(seed_value).cards.slice(5):
			seen[card] = true
			assert_bool(_stock.cards.has(card)).override_failure_message(String(card.id)).is_true()
			assert_bool(chained.has(card)).override_failure_message(String(card.id)).is_true()
			assert_bool(card.is_product()).is_true()
			assert_int(card.tier).is_equal(CardDefinition.Tier.PLAIN)
	# Over 40 deals the draw reaches well past the core's products.
	assert_int(seen.size()).is_greater(10)


## A stock with few chained products ends the deal short at the copy limit.
func test_a_small_pool_ends_the_deal_short() -> void:
	var milk: CardDefinition = load("res://data/cards/milk.tres")
	var bread: CardDefinition = load("res://data/cards/bread.tres")
	var cheese_capsule: CardDefinition = _balance.aisles[0].capsule_cards[0]
	var markdown: CardDefinition = load("res://data/cards/final_markdown.tres")
	var cards: Array[CardDefinition] = [milk, bread, cheese_capsule, markdown]
	var none: Array[CardDefinition] = []
	var small: RunStock = RunStock.from_saved(cards, [], true, none)
	var dealt: DeckDefinition = StartingDeck.deal(_recipe, small, _balance, _stream(3))
	# Milk has 1 core copy, so 1 more; Bread 2; the capsule product has no chain.
	assert_array(_ids(dealt.cards)).is_equal(
		["banana", "banana", "milk", "eggs", "final_markdown", "milk", "bread", "bread"]
	)
	# A stock with no coupon deals none.
	cards.erase(markdown)
	small = RunStock.from_saved(cards, [], true, none)
	dealt = StartingDeck.deal(_recipe, small, _balance, _stream(3))
	assert_array(_ids(dealt.cards)).is_equal(
		["banana", "banana", "milk", "eggs", "milk", "bread", "bread"]
	)


func test_the_same_seed_deals_the_same_deck_and_seeds_differ() -> void:
	var decks: Dictionary[String, bool] = {}
	for seed_value: int in SEEDS:
		var first: Array = _ids(_deal(seed_value).cards)
		assert_array(_ids(_deal(seed_value).cards)).is_equal(first)
		decks[",".join(first)] = true
	assert_int(decks.size()).is_greater(20)


## The deal draws on its own derived stream: the run's RNG starts where a fixed deck's run
## starts, so the run's own draws (hands, machine prizes, inspections) are as before.
func test_the_deal_leaves_the_run_rng_unchanged() -> void:
	for seed_value: int in [1, 7, 99]:
		var dealt: RunState = RunState.new(seed_value, _deal(seed_value), _balance, _stock)
		var fixed: RunState = RunState.new(seed_value, load(STARTER), _balance, _stock)
		var fresh: RandomNumberGenerator = RandomNumberGenerator.new()
		fresh.seed = seed_value
		assert_int(dealt.rng_state).is_equal(fresh.state)
		assert_int(dealt.rng_state).is_equal(fixed.rng_state)
	assert_str(EventLogService.STARTING_DECK_STREAM).is_equal("starting_deck")
	assert_str(EventLogService.STARTING_DECK_STREAM).is_not_equal(
		EventLogService.SURPRISE_LIST_STREAM
	)


func test_a_fixed_deck_is_dealt_as_it_is() -> void:
	var starter: DeckDefinition = load(STARTER)
	assert_object(StartingDeck.deal(starter, _stock, _balance, _stream(1))).is_same(starter)


func test_with_cards_copies_the_recipe() -> void:
	var cards: Array[CardDefinition] = [load("res://data/cards/soup.tres")]
	var dealt: DeckDefinition = StartingDeck.with_cards(_recipe, cards)
	assert_str(String(dealt.id)).is_equal(String(_recipe.id))
	assert_array(_ids(dealt.cards)).is_equal(["soup"])
	assert_array(dealt.core_cards).is_equal(_recipe.core_cards)
	assert_int(dealt.copy_max).is_equal(_recipe.copy_max)


## v0.49: the staples are the balance's own list, no longer the starting deck's products, and a
## new profile's stock is unchanged by it: the starter deck's products (the old staples, in deck
## order), every base aisle's products, then the coupon pool.
func test_a_new_profiles_live_stock_is_unchanged_by_the_staples_list() -> void:
	var balance: BalanceDefinition = load("res://data/balance/balance.tres")
	var starter: DeckDefinition = load("res://data/decks/starter.tres")
	var expected: Array[CardDefinition] = []
	for card: CardDefinition in starter.cards:
		if card.is_product() and not expected.has(card):
			expected.append(card)
	assert_array(RunStock.staples(balance)).is_equal(expected)
	for aisle: AisleDefinition in balance.aisles:
		expected.append_array(aisle.base_cards)
	expected.append_array(balance.coupon_pool)
	assert_array(RunStock.starting(balance).cards).is_equal(expected)


## v0.49: a run dealt from the recipe deck saves its dealt cards and resumes with the same
## starting deck (the recipe's id, its dealt cards), deck and later draws.
func test_a_random_start_round_trips() -> void:
	var recipe: DeckDefinition = _recipe
	var stock: RunStock = RunStock.starting(_balance)
	var deck: DeckDefinition = StartingDeck.deal(
		recipe,
		stock,
		_balance,
		EventLogService.derived_stream(21, EventLogService.STARTING_DECK_STREAM)
	)
	var run: RunState = RunState.new(21, deck, _balance, stock)
	run.start_shift()
	var data: Dictionary = RunSave.to_dictionary(run, "run-1", 0)
	assert_array(data["starting_deck"]).is_equal(_ids(deck.cards))
	assert_str(data["starter"]).is_equal("random_starter")
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var save: RunSave = RunSave.from_dictionary(_json(data), lookup)
	assert_object(save).is_not_null()
	var again: Dictionary = RunSave.to_dictionary(save.run, save.run_id, save.run_ms)
	assert_str(JSON.stringify(again)).is_equal(JSON.stringify(data))
	var restored: RunState = save.run
	assert_array(_instance_ids(restored.deck.hand())).is_equal(_instance_ids(run.deck.hand()))
	assert_int(restored.rng_state).is_equal(run.rng_state)
	assert_bool(restored.starter.is_recipe()).is_true()
	assert_array(_ids(restored.starter.cards)).is_equal(_ids(deck.cards))
	assert_int(restored.deck.size()).is_equal(13)
	# A dealt deck's save that lost its dealt cards is refused.
	data.erase("starting_deck")
	assert_object(RunSave.from_dictionary(_json(data), lookup)).is_null()


## A save whose starting deck the recipe couldn't deal (lost, cut short of the core, past the
## copy limit, too long, two coupons, or a coupon out of its place) is refused.
func test_a_save_with_a_deal_the_recipe_cant_give_is_refused() -> void:
	var stock: RunStock = RunStock.starting(_balance)
	var deck: DeckDefinition = StartingDeck.deal(_recipe, stock, _balance, _stream(5))
	var run: RunState = RunState.new(5, deck, _balance, stock)
	run.start_shift()
	var data: Dictionary = RunSave.to_dictionary(run, "run-1", 0)
	var lookup: ContentLookup = ContentLookup.new(_balance)
	assert_object(RunSave.from_dictionary(_json(data), lookup)).is_not_null()
	var dealt: Array = _ids(deck.cards)
	var bad_deals: Array[Array] = [
		[],
		dealt.slice(1),
		dealt + ["banana"],
		dealt + ["soup"],
		dealt.slice(0, 5) + ["final_markdown"],
		dealt.slice(0, 5) + ["two_for_one"],
		dealt.slice(0, 4) + dealt.slice(5) + [dealt[4]],
		["banana", "banana", "milk", "final_markdown", "eggs"],
	]
	for bad: Array in bad_deals:
		data["starting_deck"] = bad
		(
			assert_object(RunSave.from_dictionary(_json(data), lookup))
			. override_failure_message(",".join(bad))
			. is_null()
		)
	# A deal ended short (a small pool) is one the recipe can give, with or without its coupon.
	for short: Array in [dealt.slice(0, 8), dealt.slice(0, 4) + dealt.slice(5)]:
		data["starting_deck"] = short
		(
			assert_object(RunSave.from_dictionary(_json(data), lookup))
			. override_failure_message(",".join(short))
			. is_not_null()
		)


## Every list a later profile can make (every pair of aisles, all capsule items unlocked) deals
## the full 13 cards. A list of two machine-opened aisles (no chained products) leaves only the
## staples, whose room under copy_max is exactly random_count, so its products are forced: every
## seed gets the same products, only the coupon differs (v0.51; plan 7.2). This pins it, so a
## change to the staples, copy_max or the chains shows here.
func test_every_two_aisle_list_deals_thirteen_cards() -> void:
	var unlocked: Dictionary[StringName, int] = {}
	for aisle: AisleDefinition in _balance.aisles:
		for card: CardDefinition in aisle.capsule_cards:
			unlocked[card.id] = 0
	var aisles: Array[AisleDefinition] = RunStock.listable_aisles(_balance, unlocked)
	assert_int(aisles.size()).is_equal(_balance.aisles.size())
	for first: int in aisles.size():
		for second: int in range(first + 1, aisles.size()):
			var listed: Array[StringName] = [aisles[first].id, aisles[second].id]
			var stock: RunStock = RunStock.build(_balance, listed, unlocked, 1)
			assert_array(stock.aisle_ids).is_equal(listed)
			var where: String = "%s+%s" % listed
			var decks: Dictionary[String, bool] = {}
			for seed_value: int in 10:
				var dealt: DeckDefinition = StartingDeck.deal(
					_recipe, stock, _balance, _stream(seed_value)
				)
				assert_int(dealt.cards.size()).override_failure_message(where).is_equal(13)
				# The products only: the coupon is drawn from the whole pool on every list.
				decks[",".join(_ids(dealt.cards.slice(5)))] = true
			var capsule_only: bool = (
				aisles[first].base_cards.is_empty() and aisles[second].base_cards.is_empty()
			)
			if capsule_only:
				assert_int(decks.size()).override_failure_message(where).is_equal(1)
			else:
				assert_int(decks.size()).override_failure_message(where).is_greater(1)


## The capsule products have chains since v0.52 (#89), but the game's recipe keeps them out of
## the draw (random_capsules off, the user decides: plan 7.2), so the deal is as before them; a
## recipe with random_capsules on draws them too.
func test_capsule_products_join_the_draw_only_when_the_recipe_says_so() -> void:
	assert_bool(_recipe.random_capsules).is_false()
	var unlocked: Dictionary[StringName, int] = {}
	var capsules: Array[CardDefinition] = []
	for aisle: AisleDefinition in _balance.aisles:
		for card: CardDefinition in aisle.capsule_cards:
			unlocked[card.id] = 0
			capsules.append(card)
	var listed: Array[StringName] = [&"bakery", &"snacks"]
	var stock: RunStock = RunStock.build(_balance, listed, unlocked, 1)
	var chains: Array[ItemUpgradeDefinition] = _balance.machine.item_upgrades
	var kept: Array[ItemUpgradeDefinition] = StartingDeck.without_capsules(chains, _balance)
	assert_int(kept.size()).is_equal(chains.size() - capsules.size())
	var open: DeckDefinition = _recipe.duplicate()
	open.random_capsules = true
	var drew_capsule: bool = false
	for seed_value: int in SEEDS:
		var dealt: DeckDefinition = StartingDeck.deal(_recipe, stock, _balance, _stream(seed_value))
		for card: CardDefinition in dealt.cards.slice(5):
			assert_bool(capsules.has(card)).override_failure_message(String(card.id)).is_false()
		var wide: DeckDefinition = StartingDeck.deal(open, stock, _balance, _stream(seed_value))
		assert_bool(wide.random_capsules).is_true()
		for card: CardDefinition in wide.cards.slice(5):
			drew_capsule = drew_capsule or capsules.has(card)
	assert_bool(drew_capsule).is_true()


## Data: the staples alone fill the deal (their room under copy_max, the core copies counted, is
## at least random_count), so a stock with no other chained product still deals 13 cards.
func test_the_staples_alone_fill_the_deal() -> void:
	var room: int = 0
	for staple: CardDefinition in RunStock.staples(_balance):
		var chained: bool = _balance.machine.item_upgrades.any(
			func(chain: ItemUpgradeDefinition) -> bool: return chain.product == staple
		)
		assert_bool(chained).override_failure_message(String(staple.id)).is_true()
		room += maxi(0, _recipe.copy_max - _recipe.core_cards.count(staple))
	assert_int(room).is_greater_equal(_recipe.random_count)


## How often a dealt deck already fits each build at the start of a run (fresh profile, seeds
## 0 to 199), pinned in bands so a threshold or recipe change shows here. The fixed starter
## fits none, but most dealt decks fit Mixed basket (6 different tags) and about half fit
## Clearance collector, so REGISTER's "one fits your cart" is usually met from the first visit
## (PROTOTYPE_PLAN 3.8; TODO(S2): the user decides on the thresholds in the balance pass).
func test_how_often_a_dealt_deck_fits_each_build_at_the_start() -> void:
	var builds: Dictionary[StringName, BuildDefinition] = {}
	for file: String in DirAccess.get_files_at("res://data/builds"):
		if file.ends_with(".tres"):
			var build: BuildDefinition = load("res://data/builds/" + file)
			builds[build.id] = build
	var starter: DeckDefinition = load(STARTER)
	for build: BuildDefinition in builds.values():
		assert_bool(build.fits(starter.cards)).override_failure_message(String(build.id)).is_false()
	var fits: Dictionary[StringName, int] = {}
	for seed_value: int in FIT_SEEDS:
		var cards: Array[CardDefinition] = _deal(seed_value).cards
		for build: BuildDefinition in builds.values():
			if build.fits(cards):
				fits[build.id] = int(fits.get(build.id, 0)) + 1
	var rates: String = str(fits)
	var bands: Dictionary[StringName, Vector2i] = {
		&"mixed_basket": Vector2i(180, 200),
		&"clearance_collector": Vector2i(80, 140),
		&"breakfast_special": Vector2i(0, 200),
		&"bulk_buyer": Vector2i(0, 0),
		&"coupon_specialist": Vector2i(0, 0),
	}
	assert_array(builds.keys()).contains_exactly_in_any_order(bands.keys())
	for id: StringName in bands:
		var count: int = int(fits.get(id, 0))
		var where: String = "%s: %d of %d (%s)" % [id, count, FIT_SEEDS, rates]
		assert_int(count).override_failure_message(where).is_between(bands[id].x, bands[id].y)


static func _json(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))


static func _instance_ids(cards: Array[CardInstance]) -> Array[int]:
	var ids: Array[int] = []
	for card: CardInstance in cards:
		ids.append(card.instance_id)
	return ids


func _deal(seed_value: int) -> DeckDefinition:
	return StartingDeck.deal(_recipe, _stock, _balance, _stream(seed_value))


func _stream(seed_value: int) -> RandomNumberGenerator:
	return EventLogService.derived_stream(seed_value, EventLogService.STARTING_DECK_STREAM)


static func _ids(cards: Array) -> Array:
	return cards.map(func(card: CardDefinition) -> String: return String(card.id))
