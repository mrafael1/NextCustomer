extends GdUnitTestSuite
## CountUpPlan (#60, D1 to D9): beats, notes, armed targets, intensity, the quota ding,
## hit-stops and the long-row fit, and (#86 v6) the scan groups and their ride gaps, on rows
## scored with the real Scoring.score() and on hand-built steps for the edge cases. The plan is
## pure data: no saves, no event log, no Node.

const TUNING := "res://data/balance/count_up.tres"
const CARDS := "res://data/cards"
const FIXTURE_DIR := "res://tests/fixtures/cards_v0_4"
## The full reference row of the #60 decisions: Eggs and Multipack arm effects, the Spot check
## zeroes the 3rd product, Coupon engine fizzles on Multipack, Slot engine stamps slot 6 (the
## 2nd Milk after Multipack; since 2026-10-24, until then the 6th product, the last Milk).
const FULL_ROW := "eggs,bread,milk,multipack,milk,milk,milk"
## The golden rows of plan section 3.7 (tests/core/golden_rows_test.gd), on the frozen fixture.
const GOLDEN_ROWS := [
	"eggs,bread,cheese,banana,banana,repeat",
	"banana,repeat,bread,eggs,banana,cheese",
	"eggs,banana,banana",
	"banana,bundle,banana",
	"banana,repeat,banana",
	"bread,bundle,cheese",
	"eggs,bread,multipack,bread",
	"milk,multipack,cheese",
	"coffee,coffee,bread",
	"breakfast_sticker,banana,milk",
	"eggs,eggs,bread,bread,bread",
	"repeat,repeat",
	"soup,frozen_peas",
	"bread,final_markdown",
	"final_markdown,bread",
	"eggs,bread,repeat,bread",
	"bread,multipack,bread,repeat",
	"multipack,bread,bread",
	"bread,repeat,multipack,bread",
	"breakfast_sticker,repeat,banana,milk",
	"frozen_peas,frozen_peas",
	"soup,bundle,frozen_peas",
	"soup,repeat,frozen_peas",
	"eggs,coffee,bread,bread",
	"coffee,banana,bread",
	"coffee,bread,milk",
	"coffee,repeat,bread",
	"coffee,multipack,banana,bread",
	"bread,multipack,bread,multipack,bread",
	"breakfast_sticker,banana,multipack,coffee,bread",
	"banana,bundle,bundle,banana",
	"bread,bundle,repeat",
	"coffee,breakfast_sticker,soup,frozen_peas,bread",
	"eggs,soup,frozen_peas,bread",
	"banana,bundle,multipack,banana",
	"bundle,banana,banana,bundle",
	"bread,coffee",
	"breakfast_sticker,bread,milk",
	"bread,repeat,repeat",
	"coffee,breakfast_sticker,banana",
	"coffee,multipack,breakfast_sticker,banana",
]


func test_every_step_is_in_one_beat_and_only_plain_cards_merge() -> void:
	var rows: Array[Array] = [_full_steps()]
	for row: String in GOLDEN_ROWS:
		rows.append(_golden_steps(row))
	for steps: Array in rows:
		var typed: Array[ScoreStep] = []
		typed.assign(steps)
		var plan: CountUpPlan = _plan(typed)
		assert_int(plan.step_count).is_equal(typed.size())
		var seen: PackedInt32Array = PackedInt32Array()
		for beat: CountUpBeat in plan.beats:
			seen.append_array(beat.steps)
			var first: ScoreStep = typed[beat.steps[0]]
			if beat.kind == CountUpBeat.Kind.MERGED_PLAIN:
				assert_int(beat.steps.size()).is_equal(2)
				var second: ScoreStep = typed[beat.steps[1]]
				assert_int(first.step_type).is_equal(ScoreStep.StepType.BASE)
				assert_int(second.step_type).is_equal(ScoreStep.StepType.PAYOUT)
				assert_int(second.slot).is_equal(first.slot)
				assert_int(beat.payout).is_equal(second.value)
				continue
			assert_int(beat.steps.size()).is_equal(1)
			if first.step_type == ScoreStep.StepType.BASE:
				# A BASE beat of its own is never followed at once by its slot's PAYOUT.
				var next: ScoreStep = typed[beat.steps[0] + 1]
				var plain: bool = (
					next.step_type == ScoreStep.StepType.PAYOUT and next.slot == first.slot
				)
				assert_bool(plain).is_false()
		# Every step once, in step order.
		assert_array(Array(seen)).is_equal(range(typed.size()))


func test_full_row_beats_follow_the_decided_shape() -> void:
	var plan: CountUpPlan = _plan(_full_steps())
	var kinds: PackedStringArray = PackedStringArray()
	for beat: CountUpBeat in plan.beats:
		kinds.append(CountUpBeat.Kind.keys()[beat.kind])
	# One line per slot.
	var expected: String = (
		" "
		. join(
			[
				"MERGED_PLAIN ARMED",
				"BASE STAMP PAYOUT",
				"BASE BONUS DENIED PAYOUT",
				"MERGED_PLAIN ARMED FIZZLE",
				"BASE BONUS STAMP PAYOUT",
				"BASE BONUS STAMP STAMP PAYOUT",
				"BASE BONUS STAMP PAYOUT",
			]
		)
	)
	assert_str(" ".join(kinds)).is_equal(expected)
	assert_int(plan.step_count).is_equal(27)
	assert_int(plan.total).is_equal(107)
	# Multipack pays 0 before its armed beat: merged, but not a gain.
	assert_int(plan.beats[9].payout).is_equal(0)
	assert_int(plan.beats[9].note).is_equal(-1)


func test_gain_notes_climb_one_step_at_a_time_on_short_rows() -> void:
	var plan: CountUpPlan = _plan(_full_steps())
	var gains: PackedInt32Array = _gain_notes(plan)
	assert_int(plan.gain_count).is_equal(gains.size())
	# Eggs, the Eggs stamp, Milk's flat, then three Milks with a flat and a stamp, and Slot
	# engine: 10 gains, so every gain is its own note.
	assert_int(gains.size()).is_equal(10)
	for index: int in range(gains.size()):
		assert_int(gains[index]).is_equal(index)
	for beat: CountUpBeat in plan.beats:
		if not CountUpPlan.is_gain_beat(beat) and beat.kind != CountUpBeat.Kind.ARMED:
			assert_int(beat.note).is_equal(-1)
			assert_bool(beat.note_quiet).is_false()


func test_long_rows_fit_the_ladder_and_never_drop() -> void:
	var tuning: CountUpTuning = load(TUNING)
	for gains: int in [11, 12, 20, 37]:
		var plan: CountUpPlan = _plan(_flat_steps(gains))
		var notes: PackedInt32Array = _gain_notes(plan)
		assert_int(notes.size()).is_equal(gains)
		assert_int(notes[0]).is_equal(0)
		assert_int(notes[notes.size() - 1]).is_equal(tuning.note_count - 1)
		for index: int in range(1, notes.size()):
			assert_int(notes[index]).is_greater_equal(notes[index - 1])
			assert_int(notes[index]).is_less_equal(notes[index - 1] + 1)
		for note: int in notes:
			assert_int(note).is_between(0, tuning.note_count - 1)
	# 21 gains: note(i) = floor(i x 10 / 20).
	var spread: PackedInt32Array = _gain_notes(_plan(_flat_steps(21)))
	for index: int in range(21):
		assert_int(spread[index]).is_equal(floori(index / 2.0))


func test_armed_beats_replay_the_current_note_quietly() -> void:
	var plan: CountUpPlan = _plan(_full_steps())
	var eggs_armed: CountUpBeat = plan.beats[1]
	assert_int(eggs_armed.kind).is_equal(CountUpBeat.Kind.ARMED)
	assert_int(eggs_armed.note).is_equal(plan.beats[0].note)
	assert_bool(eggs_armed.note_quiet).is_true()
	var multipack_armed: CountUpBeat = plan.beats[10]
	assert_int(multipack_armed.kind).is_equal(CountUpBeat.Kind.ARMED)
	# The last gain before it is Milk's flat (beat 6), the 3rd gain.
	assert_int(multipack_armed.note).is_equal(plan.beats[6].note)
	assert_int(multipack_armed.note).is_equal(2)
	assert_bool(multipack_armed.note_quiet).is_true()
	# The next gain steps on from there: the armed beat did not step.
	assert_int(plan.beats[13].note).is_equal(3)
	# Two gains, then a zero payout (no note): the armed beat replays the 2nd note.
	var steps: Array[ScoreStep] = [
		_step(ScoreStep.StepType.BASE, 0, 0, 0, 0, "Coupon"),
		_step(ScoreStep.StepType.FLAT, 0, 0, 1, 0, "own"),
		_step(ScoreStep.StepType.FLAT, 0, 0, 1, 0, "own"),
		_step(ScoreStep.StepType.PAYOUT, 0, 0, 0, 0, "Coupon"),
		_step(ScoreStep.StepType.EFFECT_ARMED, 0, 0, 2, 0, "X ×2"),
	]
	var early: CountUpPlan = _plan(steps)
	assert_int(early.beats[3].note).is_equal(-1)
	assert_int(early.beats[4].note).is_equal(1)
	assert_bool(early.beats[4].note_quiet).is_true()
	# An armed beat before any gain plays note 0.
	steps = [_step(ScoreStep.StepType.EFFECT_ARMED, 0, 0, 2, 0, "X ×2")]
	assert_int(_plan(steps).beats[0].note).is_equal(0)
	assert_bool(_plan(steps).beats[0].note_quiet).is_true()


func test_each_armed_beat_targets_its_landings() -> void:
	var plan: CountUpPlan = _plan(_full_steps())
	assert_array(Array(plan.beats[1].targets)).is_equal([3])
	assert_array(Array(plan.beats[10].targets)).is_equal([14, 18, 23])
	for index: int in range(plan.beats.size()):
		var beat: CountUpBeat = plan.beats[index]
		var expected_from: int = -1
		if index == 3:
			expected_from = 1
		elif index in [14, 18, 23]:
			expected_from = 10
		assert_int(beat.armed_from).override_failure_message(str(index)).is_equal(expected_from)
	# Slot engine's stamp (an upgrade) and Milk's own flats are no landings.
	assert_int(plan.beats[19].armed_from).is_equal(-1)
	assert_int(plan.beats[13].armed_from).is_equal(-1)
	# A later arming of the same effect takes over the landings after it.
	var steps: Array[ScoreStep] = [
		_step(ScoreStep.StepType.EFFECT_ARMED, 0, 0, 2, 0, "Eggs ×2"),
		_step(ScoreStep.StepType.BASE, 1, 1, 5, 0, "Bread"),
		_step(ScoreStep.StepType.MULTIPLIER, 1, 0, 2, 0, "Eggs ×2"),
		_step(ScoreStep.StepType.PAYOUT, 1, 1, 10, 10, "Bread"),
		_step(ScoreStep.StepType.EFFECT_ARMED, 2, 0, 2, 10, "Eggs ×2"),
		_step(ScoreStep.StepType.BASE, 3, 3, 5, 10, "Bread"),
		_step(ScoreStep.StepType.MULTIPLIER, 3, 0, 2, 10, "Eggs ×2"),
		_step(ScoreStep.StepType.FLAT, 3, 0, 3, 10, "Eggs ×2"),
		_step(ScoreStep.StepType.COPY, 3, 0, 3, 10, "Eggs ×2"),
		_step(ScoreStep.StepType.MULTIPLIER, 3, 2, 2, 10, "Eggs ×2"),
		_step(ScoreStep.StepType.PAYOUT, 3, 3, 26, 36, "Bread"),
	]
	var again: CountUpPlan = _plan(steps)
	assert_array(Array(again.beats[0].targets)).is_equal([2])
	# The COPY and the stamp from another slot are not this effect's landings.
	assert_array(Array(again.beats[4].targets)).is_equal([6, 7])
	assert_int(again.beats[6].armed_from).is_equal(4)
	assert_int(again.beats[8].armed_from).is_equal(-1)
	assert_int(again.beats[9].armed_from).is_equal(-1)


## D5 (#105 piece 2): the quota dings at the first landing after which the shown total stays at
## or over it, unless that is the row's last landing (the quota is then met with the TOTAL).
func test_payout_rolls_and_rattles_follow_the_best_so_far() -> void:
	# Shift 1, best 45 (the floor): printer speed 1.13. Unfitted.
	var unfitted: CountUpTuning = (load(TUNING) as CountUpTuning).duplicate()
	unfitted.fit_target_ms = 100000
	var plan: CountUpPlan = CountUpPlan.build(_full_steps(), 40, CountUpContext.new(1, 0), unfitted)
	assert_int(plan.fit_stage).is_equal(0)
	assert_int(plan.best).is_equal(45)
	var bread: CountUpBeat = plan.beats[4]
	assert_int(bread.payout).is_equal(10)
	# No roll (#105 piece 2): the total counted in at the item's landings.
	assert_int(bread.roll_ms).is_equal(120)
	# €10 is at least max(€10, 0.2 x 45 = €9), so it rattles: 3 + 6 x 10 / 45.
	assert_float(bread.rattle_px).is_equal_approx(3.0 + 60.0 / 45.0, 0.0001)
	var eggs: CountUpBeat = plan.beats[0]
	assert_float(eggs.rattle_px).is_equal(0.0)
	# The subtotal first passes 45 in slot 6 (80): +2 px from there on.
	assert_int(plan.passes_best_beat).is_equal(20)
	assert_float(plan.beats[20].rattle_px).is_equal_approx(3.0 + 6.0 * 48 / 45.0 + 2.0, 0.0001)
	# The last Milk's €27 in slot 7: 3 + 6 x 27 / 45, plus 2.
	assert_float(plan.beats[24].rattle_px).is_equal_approx(8.6, 0.0001)
	# The amplitude is capped at 12 before the +2.
	assert_float(_plan(_flat_steps(1, 100)).beats[2].rattle_px).is_equal_approx(14.0, 0.0001)
	# A higher best: no step-up, and smaller rattles.
	var rich: CountUpPlan = _plan(_full_steps(), 40, CountUpContext.new(1, 200))
	assert_int(rich.passes_best_beat).is_equal(-1)
	assert_float(rich.beats[4].rattle_px).is_equal(0.0)
	assert_float(rich.beats[20].rattle_px).is_equal_approx(3.0 + 6.0 * 48 / 200.0, 0.0001)
	# €27 is under max(€10, 0.2 x 200 = €40): no rattle.
	assert_float(rich.beats[24].rattle_px).is_equal(0.0)


func test_reduced_motion_removes_every_rattle_but_keeps_the_hit_stops() -> void:
	var normal: CountUpPlan = _plan(_full_steps(), 40, CountUpContext.new(1, 0))
	var calm: CountUpPlan = _plan(_full_steps(), 40, CountUpContext.new(1, 0, 1.0, true))
	assert_bool(calm.reduced_motion).is_true()
	assert_float(normal.final_rattle_px).is_greater(0.0)
	assert_float(calm.final_rattle_px).is_equal(0.0)
	var rattled: int = 0
	for index: int in range(calm.beats.size()):
		assert_float(calm.beats[index].rattle_px).is_equal(0.0)
		if normal.beats[index].rattle_px > 0.0:
			rattled += 1
		assert_int(calm.beats[index].hit_stop_ms).is_equal(normal.beats[index].hit_stop_ms)
	assert_int(rattled).is_greater(0)
	assert_int(calm.planned_ms).is_equal(normal.planned_ms)


func test_the_total_size_sets_rattle_without_adding_a_pause() -> void:
	# best 45: large from max(50, 56.25), huge from 90.
	assert_int(_plan(_flat_steps(1, 56)).size).is_equal(CountUpPlan.Size.NORMAL)
	assert_int(_plan(_flat_steps(1, 56)).pause_ms).is_equal(0)
	assert_float(_plan(_flat_steps(1, 56)).final_rattle_px).is_equal(0.0)
	assert_int(_plan(_flat_steps(1, 57)).size).is_equal(CountUpPlan.Size.LARGE)
	assert_int(_plan(_flat_steps(1, 57)).pause_ms).is_equal(0)
	assert_float(_plan(_flat_steps(1, 57)).final_rattle_px).is_equal(8.0)
	assert_int(_plan(_flat_steps(1, 89)).size).is_equal(CountUpPlan.Size.LARGE)
	assert_int(_plan(_flat_steps(1, 90)).size).is_equal(CountUpPlan.Size.HUGE)
	assert_int(_plan(_flat_steps(1, 90)).pause_ms).is_equal(0)
	assert_float(_plan(_flat_steps(1, 90)).final_rattle_px).is_equal(12.0)
	# A higher best raises both: large from 1.25 x 100, huge from 2 x 100.
	var context: CountUpContext = CountUpContext.new(4, 100)
	assert_int(_plan(_flat_steps(1, 124), 1, context).size).is_equal(CountUpPlan.Size.NORMAL)
	assert_int(_plan(_flat_steps(1, 125), 1, context).size).is_equal(CountUpPlan.Size.LARGE)
	assert_int(_plan(_flat_steps(1, 200), 1, context).size).is_equal(CountUpPlan.Size.HUGE)


func test_the_quota_dings_at_the_first_paid_crossing_even_on_the_last_item() -> void:
	for quota: int in [1, 40, 107]:
		var plan: CountUpPlan = _plan(_full_steps(), quota)
		assert_bool(plan.quota_reached).is_true()
		assert_bool(plan.chip_at_total).is_false()
		assert_int(_ding_count(plan)).is_equal(1)
		var ding: CountUpBeat = plan.beats[plan.ding_beat]
		assert_bool(CountUpPlan.is_payout_beat(ding)).is_true()
		assert_int(ding.shown_from).is_less(quota)
		assert_int(ding.shown_to).is_greater_equal(quota)
	var missed: CountUpPlan = _plan(_full_steps(), 108)
	assert_bool(missed.quota_reached).is_false()
	assert_int(missed.ding_beat).is_equal(-1)


func test_another_quota_changes_only_the_celebration() -> void:
	var low: CountUpPlan = _plan(_full_steps(), 40)
	var high: CountUpPlan = _plan(_full_steps(), 500)
	assert_int(low.size).is_equal(high.size)
	assert_float(low.count_speed).is_equal(high.count_speed)
	assert_int(low.beats.size()).is_equal(high.beats.size())
	for index: int in range(low.beats.size()):
		assert_int(low.beats[index].duration_ms).is_equal(high.beats[index].duration_ms)
		assert_int(low.beats[index].note).is_equal(high.beats[index].note)
	assert_int(low.planned_ms - high.planned_ms).is_equal(850)


func test_the_speed_setting_scales_the_beats_but_not_the_quota_hold() -> void:
	var normal: CountUpPlan = _plan(_full_steps(), 500, CountUpContext.new(1, 0))
	var later: CountUpPlan = _plan(_full_steps(), 500, CountUpContext.new(8, 0))
	var fast: CountUpPlan = _plan(_full_steps(), 500, CountUpContext.new(1, 0, 2.0))
	assert_float(normal.count_speed).is_equal(1.0)
	assert_float(later.count_speed).is_equal(1.0)
	assert_float(fast.count_speed).is_equal(2.0)
	assert_int(absi(fast.planned_ms * 2 - normal.planned_ms)).is_less_equal(1)


func test_a_long_row_still_fits_without_dropping_steps_or_shortening_rides() -> void:
	var tuning: CountUpTuning = (load(TUNING) as CountUpTuning).duplicate()
	tuning.fit_target_ms = 2000
	var steps: Array[ScoreStep] = _long_steps()
	var plan: CountUpPlan = CountUpPlan.build(steps, 100000, CountUpContext.new(), tuning)
	assert_int(plan.fit_stage).is_equal(CountUpPlan.LAST_STAGE)
	var seen: Array[int] = []
	for beat: CountUpBeat in plan.beats:
		for index: int in beat.steps:
			seen.append(index)
		assert_int(beat.duration_ms).is_greater(0)
		if beat.ride_ms > 0:
			assert_int(beat.ride_ms).is_equal(tuning.ride_ms)
	assert_array(seen).is_equal(range(steps.size()))


func test_an_empty_row_has_only_the_pre_roll() -> void:
	var plan: CountUpPlan = _plan([], 10)
	assert_int(plan.beats.size()).is_equal(0)
	assert_int(plan.planned_ms).is_equal(120)
	assert_bool(plan.quota_reached).is_false()


static func _total() -> CountTotalTuning:
	return load(CountUpPlan.TOTAL_TUNING_PATH) as CountTotalTuning


static func _plan(
	steps: Array[ScoreStep], quota: int = 40, context: CountUpContext = null
) -> CountUpPlan:
	var used: CountUpContext = context if context != null else CountUpContext.new()
	return CountUpPlan.build(steps, quota, used, load(TUNING))


## The full reference row on the live data, with Coupon engine, Slot engine and a Spot check.
static func _full_steps() -> Array[ScoreStep]:
	return _data_steps(FULL_ROW)


## A row of live cards with Coupon engine, Slot engine and a Spot check.
static func _data_steps(ids: String) -> Array[ScoreStep]:
	var upgrades: Array[UpgradeDefinition] = [
		load("res://data/upgrades/coupon_engine.tres"),
		load("res://data/upgrades/slot_engine.tres"),
	]
	var inspections: Array[InspectionDefinition] = [load("res://data/inspections/spot_check.tres")]
	return Scoring.score(_row(ids, CARDS), upgrades, inspections).steps


static func _golden_steps(ids: String) -> Array[ScoreStep]:
	return Scoring.score(_row(ids, FIXTURE_DIR)).steps


static func _row(ids: String, folder: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for card_id: String in ids.split(","):
		var definition: CardDefinition = load("%s/%s.tres" % [folder, card_id])
		row.append(CardInstance.new(definition, row.size() + 1))
	return row


static func _step(
	type: ScoreStep.StepType,
	slot: int,
	source_slot: int,
	value: int,
	subtotal: int,
	text: String,
	source_kind: ScoreStep.SourceKind = ScoreStep.SourceKind.CARD
) -> ScoreStep:
	var step: ScoreStep = ScoreStep.new()
	step.step_type = type
	step.slot = slot
	step.source_slot = source_slot
	step.value = value
	step.subtotal = subtotal
	step.text = text
	step.source_kind = source_kind
	return step


## One card with `gains` own flat bonuses, paying `payout` (default: one per bonus).
static func _flat_steps(gains: int, payout: int = -1) -> Array[ScoreStep]:
	var paid: int = payout if payout >= 0 else gains
	var steps: Array[ScoreStep] = [_step(ScoreStep.StepType.BASE, 0, 0, 0, 0, "Card")]
	for _index: int in range(gains):
		steps.append(_step(ScoreStep.StepType.FLAT, 0, 0, 1, 0, "own"))
	steps.append(_step(ScoreStep.StepType.PAYOUT, 0, 0, paid, paid, "Card"))
	return steps


## A worst-case row: a context-pass tag and link, an armed ×3 landing on seven products that
## each have an own flat, a bonus from another card and an upgrade stamp (the 2nd product also
## a later stamp of its own), and a reset fizzle.
static func _long_steps() -> Array[ScoreStep]:
	var steps: Array[ScoreStep] = [
		_step(ScoreStep.StepType.TAG_ADDED, 1, 0, 0, 0, "Sticker"),
		_step(ScoreStep.StepType.LINKED, 1, 0, 0, 0, "Bundle"),
		_step(ScoreStep.StepType.BASE, 0, 0, 1, 0, "Multipack"),
		_step(ScoreStep.StepType.PAYOUT, 0, 0, 1, 1, "Multipack"),
		_step(ScoreStep.StepType.EFFECT_ARMED, 0, 0, 3, 1, "Multipack ×3"),
	]
	var subtotal: int = 1
	for slot: int in range(1, 8):
		subtotal += 30
		steps.append(_step(ScoreStep.StepType.BASE, slot, slot, 4, subtotal - 30, "Milk"))
		steps.append(
			_step(ScoreStep.StepType.FLAT, slot, slot, 1, subtotal - 30, "Milk: earlier Breakfast")
		)
		steps.append(_step(ScoreStep.StepType.FLAT, slot, 0, 2, subtotal - 30, "Coffee +2"))
		steps.append(
			_step(ScoreStep.StepType.MULTIPLIER, slot, 0, 3, subtotal - 30, "Multipack ×3")
		)
		if slot == 2:
			# A later stamp of the card's own: a card stamp that is not its first.
			steps.append(
				_step(ScoreStep.StepType.MULTIPLIER, slot, slot, 2, subtotal - 30, "Milk ×2")
			)
		steps.append(
			_step(
				ScoreStep.StepType.MULTIPLIER,
				slot,
				slot,
				2,
				subtotal - 30,
				"Slot engine ×2",
				ScoreStep.SourceKind.UPGRADE
			)
		)
		steps.append(_step(ScoreStep.StepType.PAYOUT, slot, slot, 30, subtotal, "Milk"))
	steps.append(_step(ScoreStep.StepType.WASTED, 7, 3, 0, subtotal, "Eggs ×2"))
	return steps


## A shortenable beat's length after fit stages 1 to 4 on _long_steps(), worked out from the
## D7 table and the beat's first step; 0 for the beats stage 5 never shortens (merged, ding,
## first card stamp, echo) and for the armed and fizzle beats, which this does not check.
static func _gain_notes(plan: CountUpPlan) -> PackedInt32Array:
	var notes: PackedInt32Array = PackedInt32Array()
	for beat: CountUpBeat in plan.beats:
		if CountUpPlan.is_gain_beat(beat):
			notes.append(beat.note)
	return notes


static func _ding_count(plan: CountUpPlan) -> int:
	var count: int = 0
	for beat: CountUpBeat in plan.beats:
		if beat.ding:
			count += 1
	return count


## The hit-stop that plays for beat `index`: its own, or the one of the earlier beat it merged
## into (the latest beat with a hit-stop at or before it).
static func _hit_stop_at(plan: CountUpPlan, index: int) -> int:
	for earlier: int in range(index, -1, -1):
		if plan.beats[earlier].hit_stop_ms > 0:
			return plan.beats[earlier].hit_stop_ms
	return 0
