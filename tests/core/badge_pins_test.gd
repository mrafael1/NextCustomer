extends GdUnitTestSuite
## Badge pins (#122, full build plan 7.4): the WIN_RUNS milestone, owning, wearing and buying
## pins on the profile (ProfilePins), and a run wearing them (RunPins): the starting cards, the
## repack and the run save. Uses the live pins, starter deck and balance with
## every quota at 5 (the run before v0.65's loop rework).

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const RECIPE := "res://data/decks/pack_starter.tres"
const BREAD := "res://data/cards/bread.tres"
const TWO_FOR_ONE := "res://data/cards/two_for_one.tres"
const PAIR := "res://data/pins/two_for_one_pair.tres"
const REPACK := "res://data/pins/repack.tres"

var _balance: BalanceDefinition


func before_test() -> void:
	_balance = (load(BALANCE) as BalanceDefinition).duplicate()
	_balance.quotas = PackedInt32Array([5, 5, 5, 5, 5, 5, 5, 5])
	EightShiftLoop.apply(_balance)


func test_win_runs_counts_the_earlier_wins_and_this_one() -> void:
	var condition: UnlockCondition = UnlockCondition.new()
	condition.kind = UnlockCondition.Kind.WIN_RUNS
	condition.amount = 3
	assert_str(condition.summary()).is_equal("Win 3 runs")
	assert_array(condition.problems()).is_empty()
	var won: RunState = _won_run(1)
	assert_bool(UnlockCheck.is_met(condition, won, {}, 1)).is_false()
	assert_bool(UnlockCheck.is_met(condition, won, {}, 2)).is_true()
	var lost: RunState = _run(2)
	_check_out(lost, [])
	assert_bool(UnlockCheck.is_met(condition, lost, {}, 5)).is_false()
	condition.amount = 1
	assert_str(condition.summary()).is_equal("Win a run")
	condition.amount = 0
	assert_array(condition.problems()).is_not_empty()


## A pin without a condition is owned from the start; the repack unlocks on the first win
## and is listed after the decks and variants.
func test_a_pin_unlocks_on_its_milestone() -> void:
	var profile: ProfileState = ProfileState.new()
	var catalogue: CatalogueDefinition = _catalogue()
	var pair: PinDefinition = load(PAIR)
	var full: PinDefinition = load(REPACK)
	assert_bool(profile.has_pin(pair)).is_true()
	assert_bool(profile.has_pin(full)).is_false()
	var lost: RunState = _run(3)
	_check_out(lost, [])
	assert_array(profile.record_run(lost, catalogue)).is_empty()
	assert_array(profile.record_run(_won_run(4), catalogue)).is_equal([&"repack"])
	assert_bool(profile.has_pin(full)).is_true()
	assert_array(profile.record_run(_won_run(5), catalogue)).is_empty()
	assert_array(profile.unlocked_pins).is_equal([&"repack"])


## One slot: wearing another pin swaps them. A pin not owned, already worn or with no slot isn't
## worn; worn() skips an id the profile no longer owns.
func test_wearing_and_taking_off_pins() -> void:
	var profile: ProfileState = ProfileState.new()
	var catalogue: CatalogueDefinition = _catalogue()
	var pair: PinDefinition = load(PAIR)
	var full: PinDefinition = load(REPACK)
	assert_bool(ProfilePins.wear(profile, full, 1)).is_false()
	assert_bool(ProfilePins.wear(profile, pair, 0)).is_false()
	assert_bool(ProfilePins.wear(profile, pair, 1)).is_true()
	assert_bool(ProfilePins.wear(profile, pair, 1)).is_false()
	profile.unlocked_pins.append(&"repack")
	assert_bool(ProfilePins.wear(profile, full, 1)).is_true()
	assert_array(profile.worn_pins).is_equal([&"repack"])
	assert_array(ProfilePins.worn(profile, catalogue)).is_equal([full])
	profile.unlocked_pins.clear()
	assert_array(ProfilePins.worn(profile, catalogue)).is_empty()
	assert_bool(ProfilePins.take_off(profile, full)).is_true()
	assert_bool(ProfilePins.take_off(profile, full)).is_false()
	assert_array(profile.worn_pins).is_empty()


## The coin fallback: a locked pin bought at random spends the price and counts the purchase;
## too few coins, or no pin left locked, buys nothing and changes nothing.
func test_buying_a_random_locked_pin() -> void:
	var profile: ProfileState = ProfileState.new()
	var catalogue: CatalogueDefinition = _catalogue()
	profile.coins = 11
	assert_bool(ProfilePins.can_buy(profile, catalogue, 12)).is_false()
	assert_object(ProfilePins.buy_random(profile, catalogue, 12, _stream(0))).is_null()
	profile.coins = 30
	var bought: PinDefinition = ProfilePins.buy_random(profile, catalogue, 12, _stream(0))
	assert_object(bought).is_same(load(REPACK))
	assert_int(profile.coins).is_equal(18)
	assert_int(profile.pins_bought).is_equal(1)
	assert_array(profile.unlocked_pins).is_equal([&"repack"])
	assert_bool(ProfilePins.can_buy(profile, catalogue, 12)).is_false()
	assert_object(ProfilePins.buy_random(profile, catalogue, 12, _stream(1))).is_null()
	assert_int(profile.coins).is_equal(18)
	assert_bool(ProfilePins.can_buy(profile, catalogue, 0)).is_false()


## A worn pin's starting cards join the deck: at once, or after the starter pack is taken.
func test_a_pin_adds_its_starting_cards() -> void:
	var pair: PinDefinition = load(PAIR)
	var run: RunState = RunState.new(6, load(STARTER), _balance, RunStock.starting(_balance))
	var size: int = run.deck.size()
	RunPins.wear(run, [pair])
	assert_array(run.pins).is_equal([pair])
	assert_int(run.deck.size()).is_equal(size + 2)
	assert_int(_copies(run, TWO_FOR_ONE)).is_equal(2)
	var recipe: DeckDefinition = load(RECIPE)
	var stock: RunStock = RunStock.starting(_balance)
	var offer: StartOffer = StartingDeck.deal_offer(
		recipe, stock, _balance, EventLogService.derived_stream(7, "deck"), true
	)
	var choosing: RunState = RunState.new(
		7, StartingDeck.before_pick(recipe, offer), _balance, stock, offer
	)
	RunPins.wear(choosing, [pair])
	var added_from: int = _copies(choosing, TWO_FOR_ONE)
	assert_bool(choosing.take_pack(offer.packs[0])).is_true()
	assert_int(_copies(choosing, TWO_FOR_ONE) - added_from).is_greater_equal(2)
	assert_int(choosing.deck.size()).is_equal(choosing.starter.cards.size() + 2)


## The repack: only with its pin and while planning, a hand card moves to another basket's place,
## swapping with the hand card there or taking a row card's empty place (whose card comes home to
## the place it left), for free and as often as liked; never within a basket or from the belt.
func test_the_repack_moves_items_between_baskets() -> void:
	var plain: RunState = _run(8)
	assert_bool(RunPins.can_repack(plain, 1, 2)).is_false()
	assert_bool(RunPins.repack(plain, 1, 2)).is_false()
	var run: RunState = RunState.new(8, load(STARTER), _balance, RunStock.starting(_balance))
	RunPins.wear(run, [load(REPACK)])
	run.start_shift()
	var hand: Array[CardInstance] = run.hand()
	# Places 0 and 2 go on the belt: places 1 and 3 hold lone items in baskets 0 and 1.
	run.place(hand[0], 0)
	run.place(hand[2], 1)
	assert_bool(RunPins.can_repack(run, 1, 0)).is_false()  # The same basket.
	assert_bool(RunPins.can_repack(run, 0, 3)).is_false()  # A belt card's place.
	assert_bool(RunPins.can_repack(run, 1, hand.size())).is_false()  # Outside the hand.
	# The lone item at place 3 moves into basket 0's empty place.
	assert_bool(RunPins.repack(run, 3, 0)).is_true()
	var by_place: Array[CardInstance] = run.hand_places()
	assert_object(by_place[0]).is_same(hand[3])
	assert_object(by_place[1]).is_same(hand[1])
	assert_object(by_place[3]).is_null()  # The belt card's place is now 3.
	assert_array(run.basket_places(0)).is_equal([0, 1])
	assert_array(run.basket_places(1)).is_empty()
	assert_array(run.row).is_equal([hand[0], hand[2]])
	run.remove(hand[0])
	assert_object(run.hand_places()[3]).is_same(hand[0])
	# Two hand cards swap, at no cost.
	assert_bool(RunPins.repack(run, 1, 5)).is_true()
	assert_object(run.hand_places()[1]).is_same(hand[5])
	assert_object(run.hand_places()[5]).is_same(hand[1])
	assert_int(run.redraws_used).is_equal(0)
	run.checkout()
	assert_bool(RunPins.can_repack(run, 1, 5)).is_false()  # Planning only.


## The run save keeps the worn pins and the repacked places; a save from before #122 reads with
## none.
func test_the_run_save_keeps_the_pins() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var run: RunState = RunState.new(9, load(STARTER), _balance, RunStock.starting(_balance))
	RunPins.wear(run, [load(REPACK)])
	run.start_shift()
	var hand: Array[CardInstance] = run.hand()
	RunPins.repack(run, 0, 3)
	var data: Dictionary = JSON.parse_string(JSON.stringify(RunSave.to_dictionary(run, "id", 0)))
	var restored: RunSave = RunSave.from_dictionary(data, lookup)
	assert_object(restored).is_not_null()
	assert_array(restored.run.pins).is_equal([load(REPACK)])
	assert_int(restored.run.hand()[0].instance_id).is_equal(hand[3].instance_id)
	assert_int(restored.run.hand()[3].instance_id).is_equal(hand[0].instance_id)
	data.erase("pins")
	var older: RunSave = RunSave.from_dictionary(data, lookup)
	assert_object(older).is_not_null()
	assert_array(older.run.pins).is_empty()


func _run(seed_value: int) -> RunState:
	var run: RunState = RunState.new(
		seed_value, load(STARTER), _balance, RunStock.starting(_balance)
	)
	run.start_shift()
	return run


func _won_run(seed_value: int) -> RunState:
	var run: RunState = _run(seed_value)
	run.debug_skip_to_shift(run.shift_count() - 1)
	_check_out(run, [BREAD, BREAD])
	return run


static func _check_out(run: RunState, paths: Array) -> void:
	for path: String in paths:
		run.place(run.debug_add_to_hand(load(path)), run.row.size())
	run.checkout()


static func _catalogue() -> CatalogueDefinition:
	var catalogue: CatalogueDefinition = CatalogueDefinition.new()
	catalogue.pins.assign([load(PAIR), load(REPACK)])
	return catalogue


static func _copies(run: RunState, path: String) -> int:
	var count: int = 0
	for card: CardInstance in run.deck.cards:
		if card.definition == load(path):
			count += 1
	return count


static func _stream(index: int) -> RandomNumberGenerator:
	return EventLogService.derived_stream(5, ProfileState.PIN_STREAM % index)
