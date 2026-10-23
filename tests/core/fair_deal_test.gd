extends GdUnitTestSuite
## The starting deck's fair-deal check (v0.54, full build plan 7.2): a recipe's deal is kept when
## at least fair_deal_passes of fair_deal_hands hands sampled from it on the deal's stream reach
## shift 1's quota with the sensible climb (RowClimb); otherwise it is dealt again on the same
## stream, at most fair_deal_redeals times, keeping the deal with the most passing hands.

const RECIPE := "res://data/decks/random_starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const SEEDS := 200

var _balance: BalanceDefinition
var _recipe: DeckDefinition
var _stock: RunStock


func before_test() -> void:
	_balance = load(BALANCE)
	_recipe = load(RECIPE)
	_stock = RunStock.starting(_balance)


## Data: 8 hands, 1 must pass, 3 changes (the simulator's sensible player), up to 4 re-deals.
func test_the_recipe_checks_its_deal() -> void:
	assert_int(_recipe.fair_deal_hands).is_equal(8)
	assert_int(_recipe.fair_deal_passes).is_equal(1)
	assert_int(_recipe.fair_deal_changes).is_equal(SimHillClimb.SENSIBLE_CHANGES)
	assert_int(_recipe.fair_deal_redeals).is_equal(4)
	var dealt: DeckDefinition = StartingDeck.with_cards(_recipe, [])
	assert_int(dealt.fair_deal_hands).is_equal(_recipe.fair_deal_hands)
	assert_int(dealt.fair_deal_redeals).is_equal(_recipe.fair_deal_redeals)


## The same stream state gives the same deal, its deal count and its passes.
func test_the_check_is_deterministic() -> void:
	for seed_value: int in 30:
		var first: StartingDeck.Dealt = _counted(seed_value)
		var again: StartingDeck.Dealt = _counted(seed_value)
		assert_array(_ids(again.deck.cards)).is_equal(_ids(first.deck.cards))
		assert_int(again.deals).is_equal(first.deals)
		assert_int(again.passes).is_equal(first.passes)


## Every deal is kept within the re-deal limit, and a kept deal passed the check; on the live
## data some seeds are re-dealt (seeds 23 and 25 among the first 30), and a re-dealt deck is not
## the first deal (the recipe dealt with no check, on the same stream).
func test_a_failed_deal_is_dealt_again_within_the_limit() -> void:
	var unchecked: DeckDefinition = _recipe.duplicate()
	unchecked.fair_deal_hands = 0
	var redealt: Array[int] = []
	for seed_value: int in SEEDS:
		var dealt: StartingDeck.Dealt = _counted(seed_value)
		var where: String = "seed %d" % seed_value
		assert_int(dealt.deals).override_failure_message(where).is_between(
			1, _recipe.fair_deal_redeals + 1
		)
		assert_int(dealt.passes).override_failure_message(where).is_greater_equal(
			_recipe.fair_deal_passes
		)
		var first: DeckDefinition = StartingDeck.deal(
			unchecked, _stock, _balance, _stream(seed_value)
		)
		if dealt.deals == 1:
			assert_array(_ids(dealt.deck.cards)).is_equal(_ids(first.cards))
		else:
			redealt.append(seed_value)
			assert_array(_ids(dealt.deck.cards)).is_not_equal(_ids(first.cards))
		assert_bool(StartingDeck.could_deal(_recipe, dealt.deck.cards)).is_true()
	assert_array(redealt).contains([23, 25])


## A deal no hand can make pass (a quota of 1000) is dealt the most times allowed and the deal
## with the most passing hands, here the first, is kept; a quota of 0 passes the first deal.
func test_an_impossible_target_stops_after_the_last_re_deal() -> void:
	var dealt: StartingDeck.Dealt = StartingDeck.deal_counted(
		_recipe, _stock, _balance, _stream(4), 1000
	)
	assert_int(dealt.deals).is_equal(_recipe.fair_deal_redeals + 1)
	assert_int(dealt.passes).is_equal(0)
	var unchecked: DeckDefinition = _recipe.duplicate()
	unchecked.fair_deal_hands = 0
	var first: DeckDefinition = StartingDeck.deal(unchecked, _stock, _balance, _stream(4))
	assert_array(_ids(dealt.deck.cards)).is_equal(_ids(first.cards))
	var easy: StartingDeck.Dealt = StartingDeck.deal_counted(
		_recipe, _stock, _balance, _stream(4), 0
	)
	assert_int(easy.deals).is_equal(1)
	assert_array(_ids(easy.deck.cards)).is_equal(_ids(first.cards))


## A constructed weak deck (Flickering bulb, Dented can and Scissors only) has no hand that
## reaches shift 1's quota, so the check counts 0 passes for it; the starter's own staples do.
func test_the_check_rejects_a_weak_deck() -> void:
	var weak: Array[CardDefinition] = []
	for id: String in ["flickering_bulb", "dented_can", "scissors"]:
		var card: CardDefinition = load("res://data/cards/%s.tres" % id)
		weak.append(card)
		weak.append(card)
	var limits: ShiftLimits = ShiftLimits.for_shift(_balance, [], 0)
	var climber: RowClimb = RowClimb.new()
	var passes: int = StartingDeck.fair_passes(
		weak, _recipe, _balance.hand_size, limits, limits.quota, climber, _stream(1)
	)
	assert_int(passes).is_equal(0)
	assert_int(limits.quota).is_equal(_balance.quotas[0])


## RowClimb is the simulator's sensible player: the same hand climbs to the same total.
func test_row_climb_matches_the_simulators_sensible_player() -> void:
	var limits: ShiftLimits = ShiftLimits.for_shift(_balance, [], 0)
	var climber: RowClimb = RowClimb.new()
	var sim: SimHillClimb = SimHillClimb.new()
	var no_upgrades: Array[UpgradeDefinition] = []
	var no_inspections: Array[InspectionDefinition] = []
	for seed_value: int in 20:
		var deck: Deck = Deck.from_definition(_counted(seed_value).deck, _stream(seed_value))
		var hand: Array[CardInstance] = deck.draw_hand(_balance.hand_size)
		var expected: int = sim.climb(hand, limits, no_upgrades, no_inspections).score
		assert_int(climber.climb_total(hand, limits, SimHillClimb.SENSIBLE_CHANGES)).is_equal(
			expected
		)


## The check draws on the deal's own stream: the run's RNG is untouched, and a re-dealt deck
## round-trips through the run save (StartingDeck.could_deal accepts it).
func test_a_re_dealt_run_saves_and_resumes() -> void:
	var dealt: StartingDeck.Dealt = _counted(23)
	assert_int(dealt.deals).is_greater(1)
	var run: RunState = RunState.new(23, dealt.deck, _balance, _stock)
	var fresh: RandomNumberGenerator = RandomNumberGenerator.new()
	fresh.seed = 23
	assert_int(run.rng_state).is_equal(fresh.state)
	run.start_shift()
	var data: Dictionary = RunSave.to_dictionary(run, "run-1", 0)
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var save: RunSave = RunSave.from_dictionary(JSON.parse_string(JSON.stringify(data)), lookup)
	assert_object(save).is_not_null()
	assert_array(_ids(save.run.starter.cards)).is_equal(_ids(dealt.deck.cards))
	assert_int(save.run.rng_state).is_equal(run.rng_state)


## The check is quick: 50 deals take well under a second together (about 10 ms each in a debug
## build; measured for v0.54).
func test_the_check_is_quick() -> void:
	var started: int = Time.get_ticks_msec()
	for seed_value: int in 50:
		_counted(seed_value)
	assert_int(Time.get_ticks_msec() - started).is_less(5000)


func _counted(seed_value: int) -> StartingDeck.Dealt:
	return StartingDeck.deal_counted(_recipe, _stock, _balance, _stream(seed_value))


func _stream(seed_value: int) -> RandomNumberGenerator:
	return EventLogService.derived_stream(seed_value, EventLogService.STARTING_DECK_STREAM)


static func _ids(cards: Array) -> Array:
	return cards.map(func(card: CardDefinition) -> String: return String(card.id))
