extends GdUnitTestSuite
## The final receipt's BEST line (v1.37, RunHighlight, the approved direction A of
## docs/art/mockups/receipt_highlight.html): each checkout's record keeps its best item and its
## longest combo; the pick finds each kind's best case (Biggest payout, Over quota, Longest combo,
## First GOLDEN, Closest call), scores it against the live bars and picks the highest, the kind
## listed first on a tie, Biggest payout as the fallback; within a kind the bigger value wins,
## then the later shift. A Day off and a missed shift are skipped where they don't count. The
## bests are saved in the run save (format 16) and an older record without them reads as none.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const MILK := "res://data/cards/milk.tres"
const MILK_GOLDEN := "res://data/cards/milk_golden.tres"
const EGGS := "res://data/cards/eggs.tres"
const BREAD := "res://data/cards/bread.tres"
const BANANA := "res://data/cards/banana.tres"
const TEA_BAGS := "res://data/cards/tea_bags.tres"
const DOUBLE := "res://data/pins/double_checkout.tres"

var _balance: BalanceDefinition
var _definition: HighlightDefinition
var _lookup: ContentLookup


func before_test() -> void:
	_balance = load(BALANCE)
	_definition = _balance.highlight
	_lookup = ContentLookup.new(_balance)


## The live data: the kinds in the mock-up's order and its bars.
func test_the_live_bars_and_kinds() -> void:
	assert_object(_definition).is_not_null()
	assert_array(Array(_definition.kind_order)).is_equal(Array(RunHighlight.KIND_IDS))
	assert_float(_definition.payout_quota_share).is_equal(0.5)
	assert_float(_definition.over_quota_ratio).is_equal(2.0)
	assert_int(_definition.combo_length).is_equal(5)
	assert_int(_definition.close_margin).is_equal(1)
	assert_int(_definition.min_combo).is_equal(2)
	assert_float(_definition.close_miss_factor).is_equal(0.5)


## A checkout's record keeps the biggest single payout (the earlier slot on a tie) and the longest
## combo (then the bigger pay; a longer MORNING beats a CHAIN).
func test_record_best_keeps_the_biggest_payout_and_the_longest_combo() -> void:
	var record: ShiftRecord = ShiftRecord.new(3, 40, 60)
	record.played.assign([load(EGGS), load(MILK), load(BREAD), load(BANANA), load(MILK)])
	var result: ScoreResult = ScoreResult.new()
	result.total = 60
	result.payouts = PackedInt32Array([5, 20, 20, 3, 12])
	result.chains = [PackedInt32Array([0, 1, 2])]
	result.batches = [PackedInt32Array([2, 3, 4])]
	RunHighlight.record_best(record, result, _definition)
	assert_int(record.best_payout).is_equal(20)
	assert_object(record.best_card).is_same(load(MILK))
	# Same length: the bigger pay (45 against 35).
	assert_str(record.best_combo_keyword).is_equal(CardText.CHAIN_WORD)
	assert_int(record.best_combo_length).is_equal(3)
	assert_int(record.best_combo_pay).is_equal(45)
	result.batches = [PackedInt32Array([1, 2, 3, 4])]
	result.mornings = PackedInt32Array([0, 1, 2, 3, 4])
	RunHighlight.record_best(record, result, _definition)
	assert_str(record.best_combo_keyword).is_equal(CardText.MORNING_WORD)
	assert_int(record.best_combo_length).is_equal(5)
	assert_int(record.best_combo_pay).is_equal(60)


## Nothing for a Day off, a row that paid nothing, or a lone batch item.
func test_record_best_keeps_nothing_without_a_payout_or_a_combo() -> void:
	var record: ShiftRecord = ShiftRecord.new(1, 30, 0)
	record.played.assign([load(BREAD)])
	var result: ScoreResult = ScoreResult.new()
	result.payouts = PackedInt32Array([0])
	result.batches = [PackedInt32Array([0])]
	RunHighlight.record_best(record, result, _definition)
	assert_object(record.best_card).is_null()
	assert_int(record.best_payout).is_equal(0)
	assert_str(record.best_combo_keyword).is_empty()
	var day_off: ShiftRecord = ShiftRecord.new(2, 30, 30)
	day_off.day_off = true
	day_off.played.assign([load(MILK)])
	result.payouts = PackedInt32Array([9])
	RunHighlight.record_best(day_off, result, _definition)
	assert_object(day_off.best_card).is_null()


## RunState.checkout fills the record from its result.
func test_a_checkout_records_its_best() -> void:
	var run: RunState = RunState.new(7, load(STARTER), _balance, RunStock.starting(_balance))
	run.start_shift()
	for path: String in [BANANA, BANANA, BANANA, MILK]:
		run.place(run.debug_add_to_hand(load(path)), run.row.size())
	var result: ScoreResult = run.checkout()
	var record: ShiftRecord = run.history[-1]
	var best: int = 0
	for payout: int in result.payouts:
		best = maxi(best, payout)
	assert_int(best).is_greater(0)
	assert_int(record.best_payout).is_equal(best)
	var slot: int = Array(result.payouts).find(best)
	assert_object(record.best_card).is_same(record.played[slot])
	# Three Bananas in a row: a CHAIN of 3.
	assert_str(record.best_combo_keyword).is_equal(CardText.CHAIN_WORD)
	assert_int(record.best_combo_length).is_equal(3)


## A Double checkout shift (#122) records from both rows' joined result, but each row has its own
## MORNING: two 4-item MORNINGs are two combos of 4, never one of 8.
func test_a_double_checkout_keeps_each_rows_morning() -> void:
	var run: RunState = RunState.new(7, load(STARTER), _balance, RunStock.starting(_balance))
	RunPins.wear(run, [load(DOUBLE)])
	run.start_shift()
	var row_slots: int = RunPins.row_slots(run)
	for _row: int in range(2):
		for index: int in range(row_slots):
			var path: String = TEA_BAGS if index == 0 else EGGS
			run.place(run.debug_add_to_hand(load(path)), run.row.size())
		run.checkout()
	var whole: ScoreResult = run.last_result
	assert_int(whole.mornings.size()).is_equal(2 * row_slots)
	var record: ShiftRecord = run.history[-1]
	assert_int(record.played.size()).is_equal(2 * row_slots)
	assert_str(record.best_combo_keyword).is_equal(CardText.MORNING_WORD)
	assert_int(record.best_combo_length).is_equal(row_slots)
	# The payout is the biggest over both rows.
	var best: int = 0
	for payout: int in whole.payouts:
		best = maxi(best, payout)
	assert_int(record.best_payout).is_equal(best)


## A weak run reaches no bar: Biggest payout prints anyway, as the fallback.
func test_a_weak_run_falls_back_to_the_biggest_payout() -> void:
	var history: Array[ShiftRecord] = [
		_record(1, 30, 25, MILK, 9), _record(2, 35, 41, EGGS, 12), _record(3, 36, 31, MILK, 10)
	]
	var moment: RunHighlight.Moment = RunHighlight.pick(history, _definition)
	assert_int(moment.kind).is_equal(RunHighlight.Kind.BIGGEST_PAYOUT)
	assert_bool(moment.fallback).is_true()
	assert_int(moment.shift).is_equal(2)
	assert_str(RunHighlight.text(moment, _definition)).is_equal("Biggest payout · Eggs · 12€")


## Each kind wins when it alone reaches its bar, and prints its line.
func test_each_kind_wins_at_its_bar() -> void:
	var payout: Array[ShiftRecord] = [_record(1, 100, 110, MILK_GOLDEN, 60)]
	_assert_pick(payout, RunHighlight.Kind.BIGGEST_PAYOUT, "Biggest payout · Golden milk · 60€")
	var over: Array[ShiftRecord] = [_record(1, 100, 230, MILK, 20)]
	_assert_pick(over, RunHighlight.Kind.OVER_QUOTA, "Over quota · Shift 1 · ×2.3")
	var combo: Array[ShiftRecord] = [_record(1, 100, 150, MILK, 20)]
	_combo(combo[0], CardText.CHAIN_WORD, 6, 70)
	_assert_pick(combo, RunHighlight.Kind.LONGEST_COMBO, "Longest CHAIN · 6 items · 70€")
	var golden: Array[ShiftRecord] = [_record(1, 100, 150, MILK, 20), _record(2, 100, 140, EGGS, 8)]
	golden[1].played.assign([load(EGGS), load(MILK_GOLDEN), load(MILK_GOLDEN)])
	_assert_pick(golden, RunHighlight.Kind.FIRST_GOLDEN, "First GOLDEN · Golden milk")
	var close: Array[ShiftRecord] = [_record(1, 101, 102, MILK, 20), _record(2, 100, 150, EGGS, 8)]
	_assert_pick(close, RunHighlight.Kind.CLOSEST_CALL, "Closest call · Shift 1 · 102€ / 101€")


## The highest score wins (Over quota ×3 beats a payout at its bar); on equal scores the kind
## listed first (a payout exactly at its bar beats First GOLDEN, which beats a Closest call).
func test_the_highest_score_wins_then_the_kind_order() -> void:
	var history: Array[ShiftRecord] = [_record(1, 100, 300, MILK, 60)]
	_assert_pick(history, RunHighlight.Kind.OVER_QUOTA, "Over quota · Shift 1 · ×3.0")
	history = [_record(1, 100, 150, MILK_GOLDEN, 50)]
	_assert_pick(history, RunHighlight.Kind.BIGGEST_PAYOUT, "Biggest payout · Golden milk · 50€")
	history = [_record(1, 100, 101, MILK_GOLDEN, 20)]
	_assert_pick(history, RunHighlight.Kind.FIRST_GOLDEN, "First GOLDEN · Golden milk")
	# A kind left out of kind_order never takes part.
	var without: HighlightDefinition = _definition.duplicate()
	without.kind_order = PackedStringArray(["biggest_payout", "closest_call"])
	var moment: RunHighlight.Moment = RunHighlight.pick(history, without)
	assert_int(moment.kind).is_equal(RunHighlight.Kind.CLOSEST_CALL)


## Within a kind the bigger value wins, then the later shift.
func test_within_a_kind_the_bigger_value_then_the_later_shift() -> void:
	var payouts: Array[ShiftRecord] = [
		_record(1, 30, 40, MILK, 12), _record(2, 30, 40, EGGS, 12), _record(3, 30, 40, BREAD, 9)
	]
	var moments: Array[RunHighlight.Moment] = RunHighlight.moments(payouts, _definition)
	assert_int(moments[0].shift).is_equal(2)
	assert_object(moments[0].card).is_same(load(EGGS))
	# Over quota and Closest call: the same ratio or margin, the later shift.
	var over: RunHighlight.Moment = _kind(payouts, RunHighlight.Kind.OVER_QUOTA)
	assert_int(over.shift).is_equal(3)
	var close: RunHighlight.Moment = _kind(payouts, RunHighlight.Kind.CLOSEST_CALL)
	assert_int(close.shift).is_equal(3)
	# Combos: the longer, then the bigger pay, then the later shift.
	_combo(payouts[0], CardText.CHAIN_WORD, 4, 30)
	_combo(payouts[1], CardText.BATCH_WORD, 4, 50)
	_combo(payouts[2], CardText.MORNING_WORD, 3, 90)
	var combo: RunHighlight.Moment = _kind(payouts, RunHighlight.Kind.LONGEST_COMBO)
	assert_int(combo.shift).is_equal(2)
	_combo(payouts[2], CardText.MORNING_WORD, 4, 50)
	combo = _kind(payouts, RunHighlight.Kind.LONGEST_COMBO)
	assert_int(combo.shift).is_equal(3)
	assert_str(combo.keyword).is_equal(CardText.MORNING_WORD)
	# The bigger ratio wins over the later shift.
	payouts[0].total = 50
	over = _kind(payouts, RunHighlight.Kind.OVER_QUOTA)
	assert_int(over.shift).is_equal(1)


## A Day off (passed on its quota, nothing played) is no Closest call, nor any other moment; a
## missed shift is no Over quota nor Closest call, but its payout counts (a lost run's last shift).
func test_a_day_off_and_a_miss_are_skipped_where_they_dont_count() -> void:
	var day_off: ShiftRecord = _record(2, 40, 40, MILK_GOLDEN, 90)
	day_off.day_off = true
	var miss: ShiftRecord = _record(3, 40, 39, EGGS, 15)
	var history: Array[ShiftRecord] = [_record(1, 30, 45, MILK, 10), day_off, miss]
	var close: RunHighlight.Moment = _kind(history, RunHighlight.Kind.CLOSEST_CALL)
	assert_int(close.shift).is_equal(1)
	assert_int(_kind(history, RunHighlight.Kind.OVER_QUOTA).shift).is_equal(1)
	assert_object(_kind(history, RunHighlight.Kind.FIRST_GOLDEN)).is_null()
	var payout: RunHighlight.Moment = _kind(history, RunHighlight.Kind.BIGGEST_PAYOUT)
	assert_int(payout.shift).is_equal(3)
	assert_int(payout.amount).is_equal(15)


## No definition, or nothing at its bar and no payout recorded (a run saved before v1.37), gives
## no line; the same run with one moment at its bar still gets it.
func test_no_line_without_a_definition_or_anything_to_show() -> void:
	var history: Array[ShiftRecord] = [_record(1, 30, 40, MILK, 12)]
	assert_object(RunHighlight.pick(history, null)).is_null()
	var old: Array[ShiftRecord] = [ShiftRecord.new(1, 30, 40), ShiftRecord.new(2, 35, 50)]
	assert_object(RunHighlight.pick(old, _definition)).is_null()
	old.append(ShiftRecord.new(3, 36, 37))
	_assert_pick(old, RunHighlight.Kind.CLOSEST_CALL, "Closest call · Shift 3 · 37€ / 36€")
	var empty: Array[ShiftRecord] = []
	assert_object(RunHighlight.pick(empty, _definition)).is_null()


## The run_end event's highlight: kind, shift, value, the item and the fallback flag.
func test_log_fields() -> void:
	var history: Array[ShiftRecord] = [_record(4, 100, 110, MILK_GOLDEN, 64)]
	var fields: Dictionary = RunHighlight.log_fields(RunHighlight.pick(history, _definition))
	(
		assert_dict(fields)
		. is_equal(
			{
				"kind": "biggest_payout",
				"shift": 4,
				"value": 64,
				"fallback": false,
				"card": "milk_golden",
			}
		)
	)
	history = [_record(1, 100, 230, MILK, 20)]
	_combo(history[0], CardText.CHAIN_WORD, 3, 40)
	fields = RunHighlight.log_fields(_kind(history, RunHighlight.Kind.LONGEST_COMBO))
	assert_str(fields["keyword"]).is_equal("CHAIN")
	assert_int(fields["length"]).is_equal(3)
	assert_int(fields["value"]).is_equal(40)
	fields = RunHighlight.log_fields(RunHighlight.pick(history, _definition))
	assert_str(fields["kind"]).is_equal("over_quota")
	assert_float(fields["value"]).is_equal_approx(2.3, 0.0001)
	assert_dict(RunHighlight.log_fields(null)).is_empty()


## The bests go through the record's saved form (as JSON text reads it back); a record without
## them (a save or log from before v1.37) reads as none; a combo with an unknown keyword or a
## card that doesn't resolve is refused.
func test_the_bests_round_trip_and_an_old_record_has_none() -> void:
	var record: ShiftRecord = _record(5, 59, 73, MILK_GOLDEN, 22)
	_combo(record, CardText.BATCH_WORD, 3, 25)
	var data: Dictionary = _json(record.to_dictionary())
	assert_int(int(data["best_payout"])).is_equal(22)
	assert_str(data["best_card"]).is_equal("milk_golden")
	var read: ShiftRecord = ShiftRecord.from_dictionary(data, _lookup)
	assert_object(read).is_not_null()
	assert_int(read.best_payout).is_equal(22)
	assert_object(read.best_card).is_same(load(MILK_GOLDEN))
	assert_str(read.best_combo_keyword).is_equal("BATCH")
	assert_int(read.best_combo_length).is_equal(3)
	assert_int(read.best_combo_pay).is_equal(25)
	assert_dict(_json(read.to_dictionary())).is_equal(data)
	var none: ShiftRecord = ShiftRecord.new(1, 30, 40)
	var plain: Dictionary = _json(none.to_dictionary())
	assert_bool(plain.has("best_card") or plain.has("best_combo")).is_false()
	var old: ShiftRecord = ShiftRecord.from_dictionary(plain, _lookup)
	assert_object(old.best_card).is_null()
	assert_str(old.best_combo_keyword).is_empty()
	var bad: Dictionary = data.duplicate(true)
	(bad["best_combo"] as Dictionary)["keyword"] = "PAIR"
	assert_object(ShiftRecord.from_dictionary(bad, _lookup)).is_null()
	bad = data.duplicate(true)
	bad["best_card"] = "no_such_card"
	assert_object(ShiftRecord.from_dictionary(bad, _lookup)).is_null()


## A run saved after a checkout keeps its records' bests (format 16); a version 15 save (records
## without them) still resumes, its highlight falling back on what it has.
func test_a_run_save_keeps_the_bests_and_a_version_15_save_reads() -> void:
	var run: RunState = RunState.new(7, load(STARTER), _balance, RunStock.starting(_balance))
	run.start_shift()
	for path: String in [BANANA, BANANA, BANANA, MILK]:
		run.place(run.debug_add_to_hand(load(path)), run.row.size())
	run.checkout()
	assert_bool(RunSave.is_save_point(run.phase)).is_true()
	var data: Dictionary = _json(RunSave.to_dictionary(run, "id", 0))
	assert_int(int(data["format_version"])).is_equal(16)
	var save: RunSave = RunSave.from_dictionary(data, _lookup)
	assert_object(save).is_not_null()
	var record: ShiftRecord = save.run.history[-1]
	assert_int(record.best_payout).is_equal(run.history[-1].best_payout)
	assert_object(record.best_card).is_same(run.history[-1].best_card)
	assert_int(record.best_combo_length).is_equal(3)
	var old: Dictionary = data.duplicate(true)
	old["format_version"] = RunSave.BEFORE_HIGHLIGHT_VERSION
	assert_int(RunSave.BEFORE_HIGHLIGHT_VERSION).is_equal(15)
	for saved: Dictionary in old["history"]:
		saved.erase("best_payout")
		saved.erase("best_card")
		saved.erase("best_combo")
	var older: RunSave = RunSave.from_dictionary(old, _lookup)
	assert_object(older).is_not_null()
	assert_object(older.run.history[-1].best_card).is_null()
	var again: Dictionary = RunSave.to_dictionary(older.run, "id", 0)
	assert_int(int(again["format_version"])).is_equal(RunSave.FORMAT_VERSION)


## v1.37 (the final receipt's BEST line): the checkout's best item (`best_payout`, `best_card`)
## from its record, and run_end's `highlight` (RunHighlight.log_fields): a run lost on shift 1
## after a Milk and Eggs checkout prints its Biggest payout as the fallback.
func test_the_best_fields_and_the_highlight() -> void:
	var deck: DeckDefinition = load(STARTER)
	var balance: BalanceDefinition = load(BALANCE)
	var run: RunState = RunState.new(77, deck, balance, RunStock.starting(balance))
	run.start_shift()
	assert_dict(RunEvents.best_fields(run)).is_equal({"best_payout": 0, "best_card": ""})
	for id: String in ["milk", "eggs"]:
		var card: CardInstance = run.debug_add_to_hand(load("res://data/cards/%s.tres" % id))
		run.place(card, run.row.size())
	var result: ScoreResult = run.checkout()
	var record: ShiftRecord = run.history[-1]
	var best: int = maxi(result.payouts[0], result.payouts[1])
	assert_dict(RunEvents.best_fields(run)).is_equal(
		{"best_payout": best, "best_card": String(record.best_card.id)}
	)
	run.phase = RunState.Phase.LOST
	var highlight: Dictionary = RunEvents.run_end(run, 10)["highlight"]
	assert_str(highlight["kind"]).is_equal("biggest_payout")
	assert_int(highlight["value"]).is_equal(best)
	assert_int(highlight["shift"]).is_equal(1)
	assert_bool(highlight["fallback"]).is_true()
	assert_str(JSON.stringify(highlight)).contains('"card":"%s"' % record.best_card.id)


## A record of a shift `shift` (`total` against `quota`) whose best item is `card_path`, paying
## `payout`; it played that card only.
func _record(shift: int, quota: int, total: int, card_path: String, payout: int) -> ShiftRecord:
	var record: ShiftRecord = ShiftRecord.new(shift, quota, total)
	record.played.assign([load(card_path)])
	record.best_card = load(card_path)
	record.best_payout = payout
	return record


static func _combo(record: ShiftRecord, keyword: String, length: int, pay: int) -> void:
	record.best_combo_keyword = keyword
	record.best_combo_length = length
	record.best_combo_pay = pay


func _kind(history: Array[ShiftRecord], kind: RunHighlight.Kind) -> RunHighlight.Moment:
	for moment: RunHighlight.Moment in RunHighlight.moments(history, _definition):
		if moment.kind == kind:
			return moment
	return null


func _assert_pick(history: Array[ShiftRecord], kind: RunHighlight.Kind, line: String) -> void:
	var moment: RunHighlight.Moment = RunHighlight.pick(history, _definition)
	assert_object(moment).override_failure_message("no highlight for " + line).is_not_null()
	if moment == null:
		return
	assert_str(RunHighlight.text(moment, _definition)).is_equal(line)
	assert_int(moment.kind).is_equal(kind)
	assert_bool(moment.fallback).is_false()


## Through JSON text and back, as a file would be read: every number becomes a float.
static func _json(data: Dictionary) -> Dictionary:
	var json: JSON = JSON.new()
	json.parse(JSON.stringify(data))
	return json.data
