extends GdUnitTestSuite
## Badge pins (#122, full build plan 7.4): the WIN_RUNS milestone, owning, wearing and buying
## pins on the profile (ProfilePins), and a run wearing them (RunPins): the starting cards, the
## once-a-shift full redraw and the run save. Uses the live pins, starter deck and balance with
## every quota at 5 (the run before v0.65's loop rework).

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const RECIPE := "res://data/decks/pack_starter.tres"
const BREAD := "res://data/cards/bread.tres"
const TWO_FOR_ONE := "res://data/cards/two_for_one.tres"
const PAIR := "res://data/pins/two_for_one_pair.tres"
const FULL_REDRAW := "res://data/pins/full_redraw.tres"

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


## A pin without a condition is owned from the start; the full redraw unlocks on the first win
## and is listed after the decks and variants.
func test_a_pin_unlocks_on_its_milestone() -> void:
	var profile: ProfileState = ProfileState.new()
	var catalogue: CatalogueDefinition = _catalogue()
	var pair: PinDefinition = load(PAIR)
	var full: PinDefinition = load(FULL_REDRAW)
	assert_bool(profile.has_pin(pair)).is_true()
	assert_bool(profile.has_pin(full)).is_false()
	var lost: RunState = _run(3)
	_check_out(lost, [])
	assert_array(profile.record_run(lost, catalogue)).is_empty()
	assert_array(profile.record_run(_won_run(4), catalogue)).is_equal([&"full_redraw"])
	assert_bool(profile.has_pin(full)).is_true()
	assert_array(profile.record_run(_won_run(5), catalogue)).is_empty()
	assert_array(profile.unlocked_pins).is_equal([&"full_redraw"])


## One slot: wearing another pin swaps them. A pin not owned, already worn or with no slot isn't
## worn; worn() skips an id the profile no longer owns.
func test_wearing_and_taking_off_pins() -> void:
	var profile: ProfileState = ProfileState.new()
	var catalogue: CatalogueDefinition = _catalogue()
	var pair: PinDefinition = load(PAIR)
	var full: PinDefinition = load(FULL_REDRAW)
	assert_bool(ProfilePins.wear(profile, full, 1)).is_false()
	assert_bool(ProfilePins.wear(profile, pair, 0)).is_false()
	assert_bool(ProfilePins.wear(profile, pair, 1)).is_true()
	assert_bool(ProfilePins.wear(profile, pair, 1)).is_false()
	profile.unlocked_pins.append(&"full_redraw")
	assert_bool(ProfilePins.wear(profile, full, 1)).is_true()
	assert_array(profile.worn_pins).is_equal([&"full_redraw"])
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
	assert_object(bought).is_same(load(FULL_REDRAW))
	assert_int(profile.coins).is_equal(18)
	assert_int(profile.pins_bought).is_equal(1)
	assert_array(profile.unlocked_pins).is_equal([&"full_redraw"])
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


## The full redraw: only with its pin, once a shift, for one redraw, every hand card swapped and
## row cards kept (a short draw pile swaps the left ones); the next shift has it again.
func test_the_full_redraw_once_a_shift() -> void:
	var plain: RunState = _run(8)
	assert_bool(RunPins.can_redraw_all(plain)).is_false()
	assert_array(RunPins.redraw_all(plain)).is_empty()
	var run: RunState = RunState.new(8, load(STARTER), _balance, RunStock.starting(_balance))
	RunPins.wear(run, [load(FULL_REDRAW)])
	run.start_shift()
	var kept: CardInstance = run.hand()[0]
	run.place(kept, 0)
	# A short draw pile swaps the left hand cards only.
	var swaps: int = mini(run.hand().size() - 1, run.deck.draw_pile().size())
	assert_bool(RunPins.can_redraw_all(run)).is_true()
	var swapped: Array[int] = RunPins.redraw_all(run)
	assert_int(swapped.size()).is_equal(swaps)
	assert_bool(swapped.has(0)).is_false()
	assert_int(run.redraws_used).is_equal(1)
	assert_bool(run.full_redraw_used).is_true()
	assert_array(run.row).is_equal([kept])
	assert_bool(RunPins.can_redraw_all(run)).is_false()
	run.remove(kept)
	_check_out(run, [BREAD, BREAD])
	MachineSteps.next_shift(run)
	assert_bool(run.full_redraw_used).is_false()
	assert_bool(RunPins.can_redraw_all(run)).is_true()


## The run save keeps the worn pins and this shift's full redraw; a save from before #122 reads
## with none.
func test_the_run_save_keeps_the_pins() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var run: RunState = RunState.new(9, load(STARTER), _balance, RunStock.starting(_balance))
	RunPins.wear(run, [load(FULL_REDRAW)])
	run.start_shift()
	RunPins.redraw_all(run)
	var data: Dictionary = JSON.parse_string(JSON.stringify(RunSave.to_dictionary(run, "id", 0)))
	var restored: RunSave = RunSave.from_dictionary(data, lookup)
	assert_object(restored).is_not_null()
	assert_array(restored.run.pins).is_equal([load(FULL_REDRAW)])
	assert_bool(restored.run.full_redraw_used).is_true()
	data.erase("pins")
	data.erase("full_redraw_used")
	var older: RunSave = RunSave.from_dictionary(data, lookup)
	assert_object(older).is_not_null()
	assert_array(older.run.pins).is_empty()
	assert_bool(older.run.full_redraw_used).is_false()


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
	catalogue.pins.assign([load(PAIR), load(FULL_REDRAW)])
	return catalogue


static func _copies(run: RunState, path: String) -> int:
	var count: int = 0
	for card: CardInstance in run.deck.cards:
		if card.definition == load(path):
			count += 1
	return count


static func _stream(index: int) -> RandomNumberGenerator:
	return EventLogService.derived_stream(5, ProfileState.PIN_STREAM % index)
