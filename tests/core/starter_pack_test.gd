extends GdUnitTestSuite
## The starter pack choice's core (#107, full build plan 7.2, v0.63; mock-up
## starter_choice_107.html, decided with the user on 2026-10-26: Q1 C, Q2 A, Q3 B, Q4 A): the six
## packs and the recipe, the offer's deal (the good first pick, the shared products, the copy rule,
## the fair-deal check), the run waiting for its pick, the run save and the profile's first win.

const RECIPE := "res://data/decks/pack_starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const CATALOGUE := "res://data/catalogue/catalogue.tres"
const PACKS := [
	"breakfast_run", "bargain_bin", "banana_bunch", "coupon_clipper", "deli_counter", "big_shop"
]

var _balance: BalanceDefinition
var _recipe: DeckDefinition
var _stock: RunStock


func before_test() -> void:
	_balance = load(BALANCE)
	_recipe = load(RECIPE)
	_stock = RunStock.starting(_balance)


## The recipe: the 4 staples, 6 products from today's stock and no dealt coupon, an offer of 3 of
## the 6 packs, Breakfast run as the good first pick. Each pack is 3 cards with exactly one RARE
## and no LEGENDARY (the machine's rarities), and none holds Soup. The catalogue lists the recipe.
func test_the_recipe_and_its_packs() -> void:
	assert_int(_recipe.random_count).is_equal(6)
	assert_int(_recipe.random_coupon_count).is_equal(0)
	assert_int(_recipe.packs_offered).is_equal(3)
	assert_int(_recipe.core_cards.size() + 3 + _recipe.random_count).is_equal(13)
	assert_str(String(_recipe.first_pick_pack.id)).is_equal("breakfast_run")
	var ids: Array = _recipe.starter_packs.map(
		func(pack: StarterPackDefinition) -> String: return String(pack.id)
	)
	assert_array(ids).is_equal(PACKS)
	var machine: MachineDefinition = _balance.machine
	for pack: StarterPackDefinition in _recipe.starter_packs:
		var message: String = String(pack.id)
		assert_int(pack.cards.size()).override_failure_message(message).is_equal(3)
		assert_str(pack.hint_text).override_failure_message(message).is_not_empty()
		var family: String = "res://data/families/%s.tres" % pack.family.to_lower()
		assert_bool(ResourceLoader.exists(family)).override_failure_message(message).is_true()
		var rare: int = 0
		for card: CardDefinition in pack.cards:
			var rarity: int = (
				machine.coupon_rarity(card) if card.is_coupon() else machine.product_rarity(card)
			)
			assert_int(rarity).override_failure_message(message).is_less(
				MachinePrize.Rarity.LEGENDARY
			)
			rare += 1 if rarity == MachinePrize.Rarity.RARE else 0
			assert_str(String(card.id)).override_failure_message(message).is_not_equal("soup")
		assert_int(rare).override_failure_message(message).is_equal(1)
	var catalogue: CatalogueDefinition = load(CATALOGUE)
	assert_bool(catalogue.decks.has(_recipe)).is_true()


## The offer: 3 different packs and 6 shared products (no coupon), the same for the same stream
## state. A profile that has never won always gets Breakfast run, raised for it and in the middle
## place; one that has won gets no first pick, and some offers leave Breakfast run out.
func test_the_offer_and_the_good_first_pick() -> void:
	var without_breakfast: int = 0
	for seed_value: int in 24:
		var first: StartOffer = _offer(seed_value, true)
		assert_int(first.packs.size()).is_equal(3)
		assert_object(first.first_pick).is_same(_recipe.first_pick_pack)
		assert_object(first.packs[1]).is_same(_recipe.first_pick_pack)
		assert_object(first.default_pack()).is_same(_recipe.first_pick_pack)
		var again: StartOffer = _offer(seed_value, true)
		assert_array(again.packs).is_equal(first.packs)
		assert_array(again.shared).is_equal(first.shared)
		var won: StartOffer = _offer(seed_value, false)
		assert_object(won.first_pick).is_null()
		assert_object(won.default_pack()).is_same(won.packs[0])
		if not won.packs.has(_recipe.first_pick_pack):
			without_breakfast += 1
		for offer: StartOffer in [first, won]:
			var unique: Dictionary = {}
			for pack: StarterPackDefinition in offer.packs:
				unique[pack] = true
			assert_int(unique.size()).is_equal(3)
			assert_int(offer.shared.size()).is_equal(_recipe.random_count)
			for card: CardDefinition in offer.shared:
				assert_bool(card.is_product()).is_true()
	assert_int(without_breakfast).is_greater(0)


## The copy rule holds for every offered pack's cart, and the Banana bunch's 4 Bananas aren't
## blocked (Q4 A, "should feel fun, not blocked"): a hand-made pack may pass copy_max, its cart
## is a deal the recipe could give, and the shared products add no 5th Banana.
func test_the_copy_rule_and_the_banana_bunch() -> void:
	var bunch: StarterPackDefinition = _pack("banana_bunch")
	var seen_bunch: int = 0
	for seed_value: int in 40:
		var offer: StartOffer = _offer(seed_value, seed_value % 2 == 0)
		for pack: StarterPackDefinition in offer.packs:
			assert_bool(StartingDeck.fits_copies(_recipe, pack.cards, offer.shared)).is_true()
			var cart: DeckDefinition = StartingDeck.with_pack(_recipe, pack, offer.shared)
			assert_bool(StartingDeck.could_deal(_recipe, cart.cards, pack)).is_true()
		if offer.packs.has(bunch):
			seen_bunch += 1
			var cart: DeckDefinition = StartingDeck.with_pack(_recipe, bunch, offer.shared)
			var bananas: int = (
				cart
				. cards
				. filter(func(card: CardDefinition) -> bool: return card.id == &"banana")
				. size()
			)
			assert_int(bananas).is_equal(4)
	assert_int(seen_bunch).is_greater(0)


## The fair-deal check: every offered cart reaches shift 1's quota in at least one sampled hand,
## swapping a failing pack or dealing the shared products again when it must.
func test_every_offered_cart_passes_the_fair_deal_check() -> void:
	var limits: ShiftLimits = ShiftLimits.for_shift(_balance, [], 0)
	var climber: RowClimb = RowClimb.new([])
	for seed_value: int in 12:
		var offer: StartOffer = _offer(seed_value, true)
		assert_int(offer.deals).is_between(1, _recipe.fair_deal_redeals + 1)
		var check: RandomNumberGenerator = RandomNumberGenerator.new()
		check.seed = seed_value
		for pack: StarterPackDefinition in offer.packs:
			var cards: Array[CardDefinition] = _recipe.core_cards + pack.cards + offer.shared
			var passes: int = StartingDeck.fair_passes(
				cards, _recipe, _balance.hand_size, limits, limits.quota, climber, check
			)
			assert_int(passes).override_failure_message(String(pack.id)).is_greater_equal(1)


## A run with an offer waits for its pick (CHOOSE_START, no hand); only an offered pack is taken,
## and taking it makes the deck (staples, the pack, the shared products) for shift 1.
func test_the_run_waits_for_its_pick() -> void:
	var offer: StartOffer = _offer(5, true)
	var run: RunState = _choice_run(5, offer)
	assert_int(run.phase).is_equal(RunState.Phase.CHOOSE_START)
	assert_array(run.hand()).is_empty()
	assert_int(run.deck.size()).is_equal(_recipe.core_cards.size() + _recipe.random_count)
	var outside: StarterPackDefinition = null
	for pack: StarterPackDefinition in _recipe.starter_packs:
		if not offer.packs.has(pack):
			outside = pack
	assert_bool(run.take_pack(outside)).is_false()
	var taken: StarterPackDefinition = offer.packs[2]
	assert_bool(run.take_pack(taken)).is_true()
	assert_bool(run.take_pack(taken)).is_false()
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_object(run.starter.starter_pack).is_same(taken)
	assert_array(run.starter.cards).is_equal(_recipe.core_cards + taken.cards + offer.shared)
	assert_array(StartingDeck.picks(run.starter)).is_equal(taken.cards + offer.shared)
	run.start_shift()
	assert_int(run.deck.size()).is_equal(13)
	assert_int(run.hand().size()).is_equal(_balance.hand_size)


## The run save keeps the offer: saved while it waits (choose_start), it resumes on the same packs,
## shared products and first pick; after the pick it keeps the pack taken. A pack the offer
## doesn't hold, or an offer naming an unknown pack, can't be resumed.
func test_the_run_save_keeps_the_offer_and_the_pick() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var offer: StartOffer = _offer(9, true)
	var run: RunState = _choice_run(9, offer)
	var waiting: Dictionary = _json(RunSave.to_dictionary(run, "id", 0))
	assert_str(waiting["phase"]).is_equal("choose_start")
	assert_str(waiting["start_pack"]).is_empty()
	var restored: RunSave = RunSave.from_dictionary(waiting, lookup)
	assert_object(restored).is_not_null()
	assert_int(restored.run.phase).is_equal(RunState.Phase.CHOOSE_START)
	assert_array(restored.run.start_offer.packs).is_equal(offer.packs)
	assert_array(restored.run.start_offer.shared).is_equal(offer.shared)
	assert_object(restored.run.start_offer.first_pick).is_same(offer.first_pick)
	assert_bool(restored.run.take_pack(offer.packs[0])).is_true()
	run.take_pack(offer.packs[0])
	run.start_shift()
	var playing: Dictionary = _json(RunSave.to_dictionary(run, "id", 0))
	assert_str(playing["start_pack"]).is_equal(String(offer.packs[0].id))
	var resumed: RunSave = RunSave.from_dictionary(playing, lookup)
	assert_object(resumed).is_not_null()
	assert_object(resumed.run.starter.starter_pack).is_same(offer.packs[0])
	assert_array(resumed.run.starter.cards).is_equal(run.starter.cards)
	var outside: Dictionary = playing.duplicate(true)
	for pack: StarterPackDefinition in _recipe.starter_packs:
		if not offer.packs.has(pack):
			outside["start_pack"] = String(pack.id)
	assert_object(RunSave.from_dictionary(outside, lookup)).is_null()
	var unknown: Dictionary = waiting.duplicate(true)
	unknown["start_offer"]["packs"][0] = "no_such_pack"
	assert_object(RunSave.from_dictionary(unknown, lookup)).is_null()
	var picked_early: Dictionary = waiting.duplicate(true)
	picked_early["start_pack"] = String(offer.packs[0].id)
	assert_object(RunSave.from_dictionary(picked_early, lookup)).is_null()


## The good first pick lasts until the profile's first win (Q3 B): a won run counts in the
## profile's stats, a lost one doesn't, and the count is saved.
func test_the_profile_counts_its_wins() -> void:
	var catalogue: CatalogueDefinition = load(CATALOGUE)
	var profile: ProfileState = ProfileState.new()
	assert_bool(profile.has_won()).is_false()
	var run: RunState = _choice_run(3, _offer(3, true))
	run.phase = RunState.Phase.LOST
	profile.record_run(run, catalogue)
	assert_bool(profile.has_won()).is_false()
	run.phase = RunState.Phase.WON
	profile.record_run(run, catalogue)
	assert_bool(profile.has_won()).is_true()
	var saved: ProfileState = ProfileState.from_dictionary(_json(profile.to_dictionary()))
	assert_bool(saved.has_won()).is_true()


## The start_choice event (#107, v0.63): the offer's packs, today's shared products, the good
## first pick, the pack taken, whether the player chose it (decide_ms -1 when not) and the deal's
## swaps and deals.
func test_start_choice_logs_the_offer_and_the_pick() -> void:
	var stream: RandomNumberGenerator = EventLogService.derived_stream(
		7, EventLogService.STARTING_DECK_STREAM
	)
	var offer: StartOffer = StartingDeck.deal_offer(_recipe, _stock, _balance, stream, true)
	var run: RunState = RunState.new(
		7, StartingDeck.before_pick(_recipe, offer), _balance, _stock, offer
	)
	var pack: StarterPackDefinition = offer.packs[0]
	run.take_pack(pack)
	var data: Dictionary = RunEvents.start_choice(run, 1234)
	assert_array(data["offered"]).is_equal(
		offer.packs.map(func(offered: StarterPackDefinition) -> String: return String(offered.id))
	)
	assert_array(data["shared"]).is_equal(RunEvents.definition_ids(offer.shared))
	assert_str(data["first_pick"]).is_equal("breakfast_run")
	assert_str(data["pick"]).is_equal(String(pack.id))
	assert_bool(data["chosen"]).is_true()
	assert_int(data["decide_ms"]).is_equal(1234)
	assert_int(data["swaps"]).is_equal(offer.swaps)
	assert_int(data["deals"]).is_equal(offer.deals)
	var taken_for: Dictionary = RunEvents.start_choice(run, -1)
	assert_bool(taken_for["chosen"]).is_false()


func _offer(seed_value: int, first_pick: bool) -> StartOffer:
	var stream: RandomNumberGenerator = EventLogService.derived_stream(
		seed_value, EventLogService.STARTING_DECK_STREAM
	)
	return StartingDeck.deal_offer(_recipe, _stock, _balance, stream, first_pick)


func _choice_run(seed_value: int, offer: StartOffer) -> RunState:
	var deck: DeckDefinition = StartingDeck.before_pick(_recipe, offer)
	return RunState.new(seed_value, deck, _balance, _stock, offer)


func _pack(id: String) -> StarterPackDefinition:
	for pack: StarterPackDefinition in _recipe.starter_packs:
		if pack.id == StringName(id):
			return pack
	return null


## As the save file holds it: through JSON (numbers come back as floats).
static func _json(data: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(data))
