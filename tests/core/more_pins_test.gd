extends GdUnitTestSuite
## The badge pins of #132 (picked by the user on 2026-11-02; PinPlay and RunPins): Stock list's
## look at the pile, Day off's skipped normal day, Golden basket's kept items, Price gun's relabel
## and Express lane's shorter row with its ends ×2, each with the run save. Uses the live pins,
## starter deck and balance with every quota at 5.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const CHEESE := "res://data/cards/cheese.tres"
const MILK := "res://data/cards/milk.tres"
const STOCK_LIST := "res://data/pins/stock_list.tres"
const DAY_OFF := "res://data/pins/day_off.tres"
const GOLDEN := "res://data/pins/golden_basket.tres"
const PRICE_GUN := "res://data/pins/price_gun.tres"
const EXPRESS := "res://data/pins/express_lane.tres"
const DOUBLE := "res://data/pins/double_checkout.tres"
const SHORT_BELT := "res://data/inspections/short_belt.tres"

var _balance: BalanceDefinition


func before_test() -> void:
	_balance = (load(BALANCE) as BalanceDefinition).duplicate()
	_balance.quotas = PackedInt32Array([5, 5, 5, 5, 5, 5, 5, 5])
	EightShiftLoop.apply(_balance)


## Stock list shows the pile's next 3 items, the next one first: they are what a redraw draws.
func test_stock_list_shows_the_next_items() -> void:
	assert_array(PinPlay.peek(_run(3, []))).is_empty()
	var run: RunState = _run(3, [STOCK_LIST])
	var next: Array[CardInstance] = PinPlay.peek(run)
	assert_int(next.size()).is_equal(3)
	var pile: Array[CardInstance] = run.deck.draw_pile()
	assert_object(next[0]).is_same(pile[-1])
	assert_object(next[2]).is_same(pile[-3])
	var places: Array[int] = run.basket_places(0)
	run.redraw_basket(0)
	assert_object(run.deck.hand()[places[0]]).is_same(next[0])
	assert_object(run.deck.hand()[places[1]]).is_same(next[1])


## A day off passes the shift exactly on its quota with nothing played, then the
## machine opens as after any pass; one a week, never on an inspection day or the last shift.
func test_a_day_off_passes_on_quota_once_a_week() -> void:
	assert_bool(PinPlay.can_take_day_off(_run(4, []))).is_false()
	var run: RunState = _run(4, [DAY_OFF])
	run.inspections = []
	var card: CardInstance = run.hand()[0]
	run.place(card, 0)
	assert_bool(PinPlay.can_take_day_off(run)).is_true()
	var result: ScoreResult = run.checkout(true)
	assert_int(result.total).is_equal(run.quota())
	assert_array(run.row).is_empty()
	assert_bool(run.history[-1].day_off).is_true()
	assert_bool(run.history[-1].passed).is_true()
	assert_array(run.history[-1].played).is_empty()
	assert_int(run.phase).is_not_equal(RunState.Phase.PLANNING)
	assert_int(run.history[-1].total).is_equal(run.history[-1].quota)  # No overtime.
	_next_shift(run)
	run.inspections = []
	# The same week: its day off is taken.
	var week: int = WeekSchedule.week_of(_balance, 1)
	if WeekSchedule.week_of(_balance, run.shift_index + 1) == week:
		assert_int(PinPlay.days_off_left(run)).is_equal(0)
		assert_object(run.checkout(true)).is_null()
		assert_int(run.phase).is_equal(RunState.Phase.PLANNING)


## The user's call of 2026-11-02: any day but a Manager's review (its PREMIUM tickets) can be
## taken off, an inspection day included; never the run's last shift.
func test_a_day_off_skips_any_day_but_a_review() -> void:
	_balance.review_shifts = PackedInt32Array([4])  # EightShiftLoop has none.
	var run: RunState = _run(5, [DAY_OFF])
	run.inspections = [load(SHORT_BELT)]
	assert_bool(PinPlay.can_take_day_off(run)).is_true()
	var review: int = 4
	run.debug_skip_to_shift(review - 1)
	assert_bool(PinPlay.is_skippable_day(run)).is_false()
	assert_bool(PinPlay.can_take_day_off(run)).is_false()
	run.debug_skip_to_shift(run.shift_count() - 1)
	var last: RunState = run
	last.balance = _balance.duplicate()
	last.balance.review_shifts = PackedInt32Array()
	assert_bool(PinPlay.can_take_day_off(last)).is_false()


## Day off's pile on the belt (the user's call of 2026-11-02): the row's cards go back to the
## hand, the row takes none and the preview is the quota; taken back, the shift plays as before.
func test_a_pending_day_off_empties_and_locks_the_row() -> void:
	var run: RunState = _run(7, [DAY_OFF])
	var placed: Array[CardInstance] = _place(run, 2)
	assert_bool(PinPlay.set_day_off(run, true)).is_true()
	assert_array(run.row).is_empty()
	assert_bool(run.hand().has(placed[0])).is_true()
	assert_bool(run.can_place(placed[0])).is_false()
	assert_bool(run.place(placed[0], 0)).is_false()
	assert_int(run.preview().total).is_equal(run.quota())
	assert_bool(PinPlay.set_day_off(run, false)).is_true()
	assert_bool(run.place(placed[0], 0)).is_true()
	assert_int(run.preview().total).is_not_equal(run.quota())
	run.remove(placed[0])
	assert_bool(PinPlay.set_day_off(run, true)).is_true()
	assert_object(run.checkout(true)).is_not_null()
	_next_shift(run)
	assert_bool(run.day_off_pending).is_false()


## Golden basket: after the checkout up to 2 of the row's items are kept (a click again lets one
## go); the next shift deals them into its first basket, the rest drawn as usual.
func test_golden_basket_keeps_two_items_for_the_first_basket() -> void:
	var run: RunState = _run(6, [GOLDEN])
	var placed: Array[CardInstance] = _place(run, 4)
	assert_bool(PinPlay.keep(run, placed[0])).is_false()  # Not before the checkout.
	run.checkout()
	assert_array(PinPlay.keepable(run)).is_equal(placed)
	assert_bool(PinPlay.keep(run, placed[3])).is_true()
	assert_bool(PinPlay.keep(run, placed[1])).is_true()
	assert_bool(PinPlay.keep(run, placed[2])).is_false()  # Two at most.
	assert_bool(PinPlay.keep(run, placed[1])).is_true()  # Let go.
	assert_bool(PinPlay.keep(run, placed[0])).is_true()
	_next_shift(run)
	var hand: Array[CardInstance] = run.deck.hand()
	assert_int(hand[0].instance_id).is_equal(placed[3].instance_id)
	assert_int(hand[1].instance_id).is_equal(placed[0].instance_id)
	assert_int(hand.size()).is_equal(run.limits.hand_size)
	assert_array(run.kept).is_empty()
	for card: CardInstance in run.deck.draw_pile():
		assert_bool(card == hand[0] or card == hand[1]).is_false()


## The run save keeps the kept items between the checkout and the next shift.
func test_the_run_save_keeps_the_kept_items() -> void:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var run: RunState = _run(7, [GOLDEN])
	var placed: Array[CardInstance] = _place(run, 3)
	run.checkout()
	PinPlay.keep(run, placed[2])
	var restored: RunSave = RunSave.from_dictionary(_saved(run), lookup)
	assert_object(restored).is_not_null()
	assert_array(restored.run.kept).is_equal(PackedInt32Array([placed[2].instance_id]))


## Price gun: an item gains a family for the shift (Cheese becomes Breakfast, so Milk after it
## counts it); one item a shift, moved for free, taken back for free, never a family it has.
func test_price_gun_gives_an_item_a_family() -> void:
	var run: RunState = _run(8, [PRICE_GUN])
	var cheese: CardInstance = run.debug_add_to_hand(load(CHEESE))
	var milk: CardInstance = run.debug_add_to_hand(load(MILK))
	var bread: CardInstance = run.debug_add_to_hand(load(BREAD))
	run.place(cheese, 0)
	run.place(milk, 1)
	var bare: int = run.preview().total
	assert_bool(PinPlay.can_relabel(run, cheese, "Dairy")).is_false()  # Its own family.
	assert_bool(PinPlay.can_relabel(run, cheese, "Food")).is_false()  # Not a Price gun family.
	assert_bool(PinPlay.relabel(run, cheese, "Breakfast")).is_true()
	assert_int(run.preview().total).is_equal(bare + 1)
	assert_bool(run.preview().tags[0].has("Breakfast")).is_true()
	assert_bool(PinPlay.can_relabel(run, bread, "Dairy")).is_false()  # One a shift.
	assert_bool(PinPlay.relabel(run, cheese, "Snack")).is_true()  # Moved, for free.
	assert_int(run.preview().total).is_equal(bare)
	assert_bool(PinPlay.relabel(run, cheese, "")).is_true()  # Taken back.
	assert_bool(PinPlay.relabel(run, bread, "Dairy")).is_true()
	var restored: RunSave = RunSave.from_dictionary(_saved(run), ContentLookup.new(_balance))
	assert_object(restored).is_not_null()
	assert_str(PinPlay.relabel_of(restored.run, restored.run.hand()[-1])).is_equal("Dairy")
	_check_out_and_next(run)
	assert_bool(run.relabels.is_empty()).is_true()


## Express lane: 2 slots fewer (before the upgrades and day events, so not closed ones), and the
## row's first and last slots pay ×2: the last open slot, so a row short of it gets only slot 1's
## (the user's call of 2026-11-02); with a Double checkout each row of 4 loses 2.
func test_express_lane_shortens_the_row_and_doubles_its_ends() -> void:
	var plain: RunState = _run(9, [])
	var run: RunState = _run(9, [EXPRESS])
	assert_int(run.limits.slot_count).is_equal(plain.limits.slot_count - 2)
	assert_int(run.limits.closed_slots).is_equal(plain.limits.closed_slots)
	var breads: Array[CardInstance] = []
	var events: Array[InspectionDefinition] = WeekSchedule.shift_events(plain)
	var bread: CardDefinition = load(BREAD)
	for index: int in range(run.limits.slot_count):
		breads.append(run.debug_add_to_hand(bread))
		assert_bool(run.place(breads[index], index)).is_true()
		var bare: int = Scoring.score(breads, [], events).total
		var ends: int = 2 if index == run.limits.slot_count - 1 else 1
		assert_int(run.preview().total).override_failure_message("%d items" % (index + 1)).is_equal(
			bare + ends * bread.base
		)
	var double: RunState = _run(9, [DOUBLE, EXPRESS])
	assert_int(double.limits.slot_count).is_equal(2)


func _run(seed_value: int, pins: Array) -> RunState:
	var run: RunState = RunState.new(
		seed_value, load(STARTER), _balance, RunStock.starting(_balance)
	)
	var worn: Array[PinDefinition] = []
	for path: String in pins:
		worn.append(load(path))
	RunPins.wear(run, worn)
	run.start_shift()
	return run


## Places the first `count` hand cards on the belt.
static func _place(run: RunState, count: int) -> Array[CardInstance]:
	var placed: Array[CardInstance] = []
	for card: CardInstance in run.hand():
		if placed.size() == count:
			break
		if run.place(card, run.row.size()):
			placed.append(card)
	return placed


## Plays the machine's visits (MachineSteps) and starts the next shift.
static func _next_shift(run: RunState) -> void:
	MachineSteps.next_shift(run)


static func _check_out_and_next(run: RunState) -> void:
	run.checkout()
	_next_shift(run)


static func _saved(run: RunState) -> Dictionary:
	return JSON.parse_string(JSON.stringify(RunSave.to_dictionary(run, "id", 0)))
