extends GdUnitTestSuite
## The week badge's medals (2026-11-06, the "spend" model, mock-up
## docs/art/mockups/week_medals.html): WeekMedals' states from the run (AVAILABLE, PENDING with the
## projection, USED once spent, both back at the next week's start, OFF with the reward off), the
## medal case as drawn (MedalCase, v1.17: a medal back from USED pops in, a PENDING one shimmers, a
## launch empties its socket), the chain from the gauge to the receipt (MedalFlight: the lap lamp
## pops and sends its token to the medal, which flies onto the receipt's target, and the receipt
## turns its metal), planning's projection on the real
## screen (the medals it would spend shimmer and the receipt's edges glow in their metal, quiet
## again when it drops; the PROJECTED number takes the metal) and a medal already spent moving
## nothing at the checkout (the receipt stays plain). Runs play Breads (5€ each) against quotas of
## 10 in weeks of 4 shifts.

const SCREEN := "res://ui/shift_screen.tscn"
const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const Rush := preload("res://tests/ui/count_up_rush.gd")
const X1 := 2
const X2 := 4
const X3 := 6
const AVAILABLE := WeekMedals.State.AVAILABLE
const PENDING := WeekMedals.State.PENDING
const USED := WeekMedals.State.USED
const OFF := WeekMedals.State.OFF

var _balance: BalanceDefinition
var _folder: String = ""


func before_test() -> void:
	_balance = (load(BALANCE) as BalanceDefinition).duplicate()
	_balance.quotas = PackedInt32Array([10, 10, 10, 10, 10, 10, 10, 10])
	_balance.week_length = 4
	_balance.weeks = []
	_balance.inspection_shifts = PackedInt32Array()
	_balance.review_shifts = PackedInt32Array()
	_balance.boon_shifts = PackedInt32Array()
	_balance.write_up_limit = 0
	var machine: MachineDefinition = _balance.machine.duplicate()
	machine.premium_shifts = PackedInt32Array()
	machine.bonus_extra_shifts = PackedInt32Array()
	machine.bonus_after_inspection = false
	_balance.machine = machine
	_folder = "user://test_week_medals_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## A week opens with both medals AVAILABLE; a ×2 checkout spends the SILVER (USED from the
## checkout on, through the week), a ×3 one later the GOLD; the next week's first shift has both
## back; a resumed run shows the spent medals as they were (the shift records, no new save field).
func test_the_medals_are_spent_once_a_week_and_come_back() -> void:
	var run: RunState = _run()
	assert_array(WeekMedals.states(run, false)).is_equal([AVAILABLE, AVAILABLE])
	_check_out(run, X2)
	# During the count the shift's own spend waits for its flight; after it, the socket is empty.
	assert_array(WeekMedals.states(run, true)).is_equal([AVAILABLE, AVAILABLE])
	assert_array(WeekMedals.states(run, false)).is_equal([USED, AVAILABLE])
	_next(run)
	assert_array(WeekMedals.states(run, false)).is_equal([USED, AVAILABLE])
	assert_array(WeekMedals.states(_round_trip(run), false)).is_equal([USED, AVAILABLE])
	_check_out(run, X3)
	assert_bool(run.history[-1].overtime_ticket).is_false()
	assert_bool(run.history[-1].overtime_premium).is_true()
	assert_array(WeekMedals.states(run, false)).is_equal([USED, USED])
	_next(run)
	assert_array(WeekMedals.states(run, false)).is_equal([USED, USED])
	var resumed: RunState = _round_trip(run)
	assert_array(WeekMedals.states(resumed, false)).is_equal([USED, USED])
	for _shift: int in range(2):
		_check_out(run, X1)
		_next(run)
	# Shift 5 opens week 2: both medals back.
	assert_int(run.shift_index).is_equal(4)
	assert_array(WeekMedals.states(run, false)).is_equal([AVAILABLE, AVAILABLE])


## PENDING follows planning's projection: none under ×2, the SILVER from ×2, both from ×3; never a
## spent medal, never outside planning, never on the last shift; the GOLD isn't PENDING when the
## shift's visit is PREMIUM already (it would not spend it). A reward with 0 laps is OFF.
func test_pending_follows_the_projection() -> void:
	var run: RunState = _run()
	var quota: int = run.quota()
	assert_array(WeekMedals.states(run, false, quota)).is_equal([AVAILABLE, AVAILABLE])
	assert_array(WeekMedals.states(run, false, quota * 2 - 1)).is_equal([AVAILABLE, AVAILABLE])
	assert_array(WeekMedals.states(run, false, quota * 2)).is_equal([PENDING, AVAILABLE])
	assert_array(WeekMedals.states(run, false, quota * 3)).is_equal([PENDING, PENDING])
	assert_array(WeekMedals.states(run, true, quota * 3)).is_equal([AVAILABLE, AVAILABLE])
	_check_out(run, X2)
	assert_array(WeekMedals.states(run, false, quota * 3)).is_equal([USED, AVAILABLE])
	_next(run)
	assert_array(WeekMedals.states(run, false, run.quota() * 3)).is_equal([USED, PENDING])
	# A premium shift's visit is PREMIUM already: the GOLD would not be spent.
	run.machine.machine = run.machine.machine.duplicate() as MachineDefinition
	run.machine.machine.premium_shifts = PackedInt32Array([run.shift_index + 1])
	assert_bool(run.machine.premium_if_passed(run)).is_true()
	assert_array(WeekMedals.states(run, false, run.quota() * 3)).is_equal([USED, AVAILABLE])
	run.machine.machine.overtime_ticket_laps = 0
	assert_array(WeekMedals.states(run, false, run.quota() * 3)).is_equal([OFF, AVAILABLE])
	assert_bool(WeekMedals.pending_of(run, false, run.quota() * 3)).is_false()


## On the run's last shift no machine follows: an available medal's tip says it stays unspent.
func test_the_last_shift_tip_says_no_machine_follows() -> void:
	var run: RunState = _run()
	assert_str(WeekMedals.tip_of(run, false, AVAILABLE)).contains(OvertimeWords.STATE_AVAILABLE)
	run.shift_index = run.shift_count() - 1
	assert_str(WeekMedals.tip_of(run, true, AVAILABLE)).contains(OvertimeWords.STATE_LAST)
	assert_str(WeekMedals.tip_of(run, false, USED)).contains(OvertimeWords.STATE_USED)


## The medal case as drawn (v1.17, in place of the week chip's sockets): its states and tooltips,
## a launch leaves the engraved socket and "WON ✓", a PENDING medal shimmers (not under reduced
## motion), a medal back from USED pops in (not under reduced motion), the two medals never
## overlap, both inside the case, and an OFF medal shows nothing.
func test_the_sockets_show_the_states() -> void:
	var sockets: MedalCase = auto_free(MedalCase.new())
	add_child(sockets)
	sockets.size = ShiftStage.DRAWER_RECT.size
	var tips: PackedStringArray = PackedStringArray(["silver", "gold"])
	sockets.show_states([AVAILABLE, PENDING] as Array[int], tips)
	sockets.show_thresholds(20, 30)
	assert_bool(sockets.shimmering(true)).is_true()
	assert_bool(sockets.shimmering(false)).is_false()
	var silver: Rect2 = sockets.medal_rect(false)
	var gold: Rect2 = sockets.medal_rect(true)
	assert_bool(silver.intersects(gold)).is_false()
	assert_float(silver.position.x).is_less(gold.position.x)
	var bounds: Rect2 = Rect2(Vector2.ZERO, sockets.size)
	assert_bool(bounds.encloses(silver) and bounds.encloses(gold)).is_true()
	assert_str(sockets.tip_at(gold.get_center())).is_equal("gold")
	assert_str(sockets.line_text(false)).is_equal("at 20€")
	assert_str(sockets.line_text(true)).is_equal("at 30€")
	sockets.launch(true)
	assert_int(sockets.state_of(true)).is_equal(USED)
	assert_str(sockets.line_text(true)).is_equal("WON ✓")
	sockets.show_states([USED, USED] as Array[int], tips)
	assert_bool(sockets.popping(false)).is_false()
	sockets.show_states([AVAILABLE, AVAILABLE] as Array[int], tips)
	assert_bool(sockets.popping(false) and sockets.popping(true)).is_true()
	sockets.advance(MedalCase.POP_SECONDS + 0.01)
	assert_bool(sockets.popping(false) or sockets.popping(true)).is_false()
	sockets.reduced_motion = true
	sockets.show_states([USED, PENDING] as Array[int], tips)
	assert_bool(sockets.shimmering(true)).is_false()
	sockets.show_states([AVAILABLE, AVAILABLE] as Array[int], tips)
	assert_bool(sockets.popping(false)).is_false()
	sockets.show_states([OFF, OFF] as Array[int], tips)
	(
		assert_bool(sockets.medal_rect(false).has_area() or sockets.medal_rect(true).has_area())
		. is_false()
	)
	assert_str(sockets.tip_at(gold.get_center())).is_empty()


## The chain on the real screen (the user's play test of 2026-11-10: the gauge activates the
## medal, the medal the receipt): the gauge's lap lamp pops and its token flies on its own layer
## from the lamp to the SILVER, still in its case; as the token lands the SILVER leaves its socket
## (USED) and flies onto the receipt's target digits, where `landed` is told which medal landed.
## Reduced motion: nothing flies, it lands at once.
func test_the_lamp_sends_a_medal_to_the_receipt() -> void:
	var screen: ShiftScreen = await _screen()
	var flight: MedalFlight = screen._stage.gold_flow.flight
	var sockets: MedalCase = screen._stage.medal_case
	var meter: QuotaMeter = screen._stage.quota_meter
	var target: ReceiptTarget = screen._stage.receipt.target
	assert_int(sockets.state_of(false)).is_equal(AVAILABLE)
	var landed: Array[bool] = []
	var on_land: Callable = func(gold: bool) -> void: landed.append(gold)
	var lamp: Rect2 = meter.lamp_canvas_rect()
	var medal: Rect2 = sockets.medal_canvas_rect(false)
	assert_bool(lamp.has_area() and medal.has_area()).is_true()
	flight.fly(false, false, on_land)
	assert_bool(flight.is_flying()).is_true()
	await _frames(2)
	# The token first: off the lamp (which popped), the medal still in its case.
	assert_int(flight.flyers().size()).is_equal(1)
	var token: Control = flight.flyers()[0]
	assert_bool(token is MedalFlight.LampToken).is_true()
	assert_vector(token.size).is_equal(lamp.size)
	assert_bool(token.get_global_rect().is_equal_approx(lamp)).is_false()
	assert_float(meter._pop).is_greater(0.0)
	assert_int(sockets.state_of(false)).is_equal(AVAILABLE)
	assert_array(landed).is_empty()
	# Then the medal: out of the case as the token lands, on its way to the receipt's target.
	var flyer: Control = null
	for _frame: int in range(120):
		await get_tree().process_frame
		if not flight.flyers().is_empty() and flight.flyers()[0] is MedalFlyer:
			flyer = flight.flyers()[0]
			break
	assert_object(flyer).is_not_null()
	assert_int(sockets.state_of(false)).is_equal(USED)
	assert_int(flight.flyers().size()).is_equal(1)
	assert_array(landed).is_empty()
	var to: Rect2 = flight._destination(medal.size)
	var digits: Rect2 = target.get_global_transform_with_canvas() * target.digits_rect()
	assert_vector(to.size).is_equal(medal.size)
	assert_vector(to.get_center()).is_equal_approx(digits.get_center(), Vector2.ONE)
	flight.finish()
	assert_bool(flight.is_flying()).is_false()
	assert_array(flight.flyers()).is_empty()
	assert_array(landed).is_equal([false])
	flight.fly(true, true, on_land)
	assert_bool(flight.is_flying()).is_false()
	assert_array(landed).is_equal([false, true])
	assert_int(sockets.state_of(true)).is_equal(USED)


## CHECKOUT's medal prelude (the user's proposition, 2026-11-09) on a row making x3 with both
## medals free: the bell, then the gauge runs its laps x1, x2, x3 before the count; the SILVER
## flies into the lap lamp as x2 is made and the paper turns silver, then the GOLD at x3 and the
## paper turns gold over it; then the gauge slides up, all before the count starts, and the
## count never turns the paper back.
func test_the_medal_prelude_runs_before_the_count() -> void:
	var screen: ShiftScreen = await _screen()
	_place_milks(screen, 7)
	await _frames(2)
	var stage: ShiftStage = screen._stage
	var gold: ReceiptGold = stage.receipt.gold
	var count_up: CountUp = screen._count_up
	var order: Array[String] = []
	var on_step: Callable = func(laps: int) -> void:
		order.append("lap %d%s" % [laps, " counting" if count_up._playing else ""])
	stage.gauge_panel.lap_run_step.connect(on_step)
	var at_count: Callable = func(_views: Array[CardView]) -> void:
		order.append("count up %.2f" % stage.gauge_panel.up_amount())
	count_up.count_started.connect(at_count, CONNECT_ONE_SHOT)
	screen._on_checkout_pressed()
	assert_bool(stage.medal_prelude.is_playing()).is_true()
	assert_bool(stage.medal_prelude.rang_bell).is_true()
	var seen: Dictionary = {}
	for _frame: int in range(600):
		await get_tree().process_frame
		_first(seen, "silver", gold.is_silver(), order)
		_first(seen, "gold", gold.is_gold(), order)
		_first(seen, "flying", stage.gold_flow.flight.is_flying(), order)
		if stage.gauge_panel.is_hidden() and not seen.has("hidden"):
			seen["laps"] = stage.gauge_panel.quota_meter.multiples_made()  # The run's end: x3.
		_first(seen, "hidden", stage.gauge_panel.is_hidden(), order)
		if count_up._playing:
			break
	var expected: Array[String] = [
		"lap 1", "lap 2", "flying", "lap 3", "silver", "gold", "hidden", "count up 1.00"
	]
	assert_array(order).is_equal(expected)
	assert_array(stage.medal_case.states()).is_equal([USED, USED])
	assert_int(int(seen.get("laps", 0))).is_equal(3)
	var lost: Array[bool] = [false]
	for _frame: int in range(30):
		await get_tree().process_frame
		lost[0] = lost[0] or not gold.is_gold()
	assert_bool(lost[0]).is_false()
	await Rush.finish(screen)
	assert_dict(_end_state(screen)).is_equal(_expected_end())


## A long run (the user's play test of 2026-11-10, a ×50+ checkout with both medals earned): the
## gauge steps to the medals' laps, rolls through the rest and lands; the silver and the gold
## still turn the paper in order, the gauge slides up only once its readout reads the final ×N,
## and the count starts about 2.65 s after CHECKOUT whatever the laps.
func test_a_long_prelude_rolls_and_hides_after_its_final_laps() -> void:
	var screen: ShiftScreen = await _screen()
	screen.run.limits.quota = 2
	_place_milks(screen, 7)
	await _frames(2)
	var stage: ShiftStage = screen._stage
	var made: int = QuotaLaps.lap_of(screen.run.preview().total, screen.run.quota())
	assert_int(made).is_greater_equal(50)
	var gold: ReceiptGold = stage.receipt.gold
	var count_up: CountUp = screen._count_up
	var steps: Array[int] = []
	stage.gauge_panel.lap_run_step.connect(func(laps: int) -> void: steps.append(laps))
	var order: Array[String] = []
	var seen: Dictionary = {}
	var started: int = Time.get_ticks_msec()
	screen._on_checkout_pressed()
	assert_bool(stage.medal_prelude.is_playing()).is_true()
	for _frame: int in range(900):
		await get_tree().process_frame
		_first(seen, "silver", gold.is_silver(), order)
		_first(seen, "gold", gold.is_gold(), order)
		if stage.gauge_panel.is_hidden() and not seen.has("hidden"):
			seen["readout"] = stage.gauge_panel.readout.text()
			seen["laps"] = stage.gauge_panel.quota_meter.multiples_made()
			seen["turning"] = stage.gold_flow.is_turning()
		_first(seen, "hidden", stage.gauge_panel.is_hidden(), order)
		if count_up._playing:
			seen["count_s"] = (Time.get_ticks_msec() - started) / 1000.0
			break
	assert_array(order).is_equal(["silver", "gold", "hidden"])
	assert_str(String(seen.get("readout", ""))).is_equal("×%d" % made)
	assert_int(int(seen.get("laps", 0))).is_equal(made)
	assert_bool(bool(seen.get("turning", true))).is_false()
	assert_int(steps.size()).is_equal(made)
	assert_int(steps[-1]).is_equal(made)
	var count_s: float = seen.get("count_s", 0.0)
	assert_float(count_s).override_failure_message("count at %.2f s" % count_s).is_between(2.3, 3.3)
	assert_array(stage.medal_case.states()).is_equal([USED, USED])
	await Rush.finish(screen)
	assert_dict(_end_state(screen)).is_equal(_expected_end())


## A tap during the prelude (the player's own skip, Rush) lands it all at once, to the same end
## state as one played out, and the count starts tapped (skip_used).
func test_a_tap_skips_the_prelude_to_the_same_end() -> void:
	var screen: ShiftScreen = await _screen()
	_place_milks(screen, 7)
	await _frames(2)
	await Rush.checkout(screen)
	assert_bool(screen._stage.medal_prelude.was_skipped()).is_true()
	assert_int(screen._count_up.first_tap_ms).is_greater_equal(0)
	assert_dict(_end_state(screen)).is_equal(_expected_end())


## Under reduced motion the prelude is instant: the medals are spent, the paper is gold and the
## gauge up as the count starts, in the click's own frame; it ends as one played out.
func test_the_prelude_is_instant_under_reduced_motion() -> void:
	var still: ShiftScreen = await _screen()
	still.profile.settings[ProfileState.REDUCED_MOTION_KEY] = true
	_place_milks(still, 7)
	await _frames(2)
	still._on_checkout_pressed()
	assert_bool(still._count_up._playing).is_true()
	assert_bool(still._stage.medal_prelude.is_playing()).is_false()
	assert_bool(still._stage.receipt.gold.is_gold()).is_true()
	assert_bool(still._stage.gold_flow.has_flown(false)).is_true()
	assert_bool(still._stage.gold_flow.has_flown(true)).is_true()
	assert_float(still._stage.gauge_panel.up_amount()).is_equal(1.0)
	await Rush.finish(still)
	assert_dict(_end_state(still)).is_equal(_expected_end())


## A new checkout forgets the last one's flights at its click: a medal flown on an earlier day
## (stale flags) never reads USED through a count that spends none.
func test_a_new_checkout_forgets_the_last_flights() -> void:
	var screen: ShiftScreen = await _screen()
	var flow: ReceiptGoldFlow = screen._stage.gold_flow
	flow._flown = [true, true]
	_place_milks(screen, 1)
	await _frames(2)
	screen._on_checkout_pressed()
	assert_bool(screen._counting).is_true()
	assert_bool(flow.has_flown(false) or flow.has_flown(true)).is_false()
	assert_array(screen._stage.medal_case.states()).is_equal([AVAILABLE, AVAILABLE])
	await Rush.finish(screen)


## A flyer's last frame sits on its landing (the arc's end is the landing's rect).
func test_the_flight_ends_on_its_landing() -> void:
	var from: Rect2 = Rect2(10, 10, 13, 13)
	var to: Rect2 = Rect2(300, 400, 26, 26)
	assert_object(MedalFlight._arc(from, to, 0.0)).is_equal(from)
	var end: Rect2 = MedalFlight._arc(from, to, 1.0)
	assert_vector(end.position).is_equal_approx(to.position, Vector2.ONE * 0.01)
	assert_vector(end.size).is_equal_approx(to.size, Vector2.ONE * 0.01)
	var mid: Rect2 = MedalFlight._arc(from, to, 0.5)
	var line_y: float = lerpf(from.get_center().y, to.get_center().y, 0.5)
	assert_float(mid.get_center().y).is_less(line_y)


## Planning on the real screen: the medals the preview's projection would spend shimmer, the
## receipt's edges glow in their metal and the PROJECTED number takes it (gold over silver), all
## quiet (ink) again when it drops; the count begins with no glow and its TOTAL in ink.
func test_the_projection_lights_the_pending_medals_and_the_receipt() -> void:
	var screen: ShiftScreen = await _screen()
	var sockets: MedalCase = screen._stage.medal_case
	var gold: ReceiptGold = screen._stage.receipt.gold
	var target: ReceiptTarget = screen._stage.receipt.target
	var ink: Array[Color] = [ReceiptTarget.HERO_COLOR, ReceiptTarget.NO_SHADOW]
	var silver: Array[Color] = [ReceiptTarget.SILVER_HERO_COLOR, ReceiptTarget.SILVER_HERO_SHADOW]
	var golden: Array[Color] = [ReceiptTarget.GOLD_HERO_COLOR, ReceiptTarget.GOLD_HERO_SHADOW]
	screen._week.show_pending(0)
	assert_array(sockets.states()).is_equal([AVAILABLE, AVAILABLE])
	assert_int(gold.pending()).is_equal(ReceiptGold.PENDING_NONE)
	assert_array(target.hero_ink()).is_equal(ink)
	var quota: int = screen.run.quota()
	screen._week.show_pending(quota * 2)
	assert_array(sockets.states()).is_equal([PENDING, AVAILABLE])
	assert_int(gold.pending()).is_equal(ReceiptGold.PENDING_SILVER)
	assert_array(target.hero_ink()).is_equal(silver)
	screen._week.show_pending(quota * 3)
	assert_array(sockets.states()).is_equal([PENDING, PENDING])
	assert_int(gold.pending()).is_equal(ReceiptGold.PENDING_GOLD)
	assert_array(target.hero_ink()).is_equal(golden)
	screen._week.show_pending(quota)
	assert_array(sockets.states()).is_equal([AVAILABLE, AVAILABLE])
	assert_int(gold.pending()).is_equal(ReceiptGold.PENDING_NONE)
	assert_array(target.hero_ink()).is_equal(ink)
	# The real preview: a row making ×3 shows both pending.
	_place_milks(screen, 7)
	await _frames(2)
	assert_int(OvertimeTickets.laps(screen.run.preview().total, quota)).is_greater_equal(3)
	assert_array(sockets.states()).is_equal([PENDING, PENDING])
	assert_int(gold.pending()).is_equal(ReceiptGold.PENDING_GOLD)
	assert_array(target.hero_ink()).is_equal(golden)
	await Rush.checkout(screen)
	assert_int(gold.pending()).is_equal(ReceiptGold.PENDING_NONE)
	assert_array(target.hero_ink()).is_equal(ink)


## A medal already spent this week moves nothing at the checkout (a cap of 0 stands for one spent
## earlier): reaching its laps, the PROJECTED number stays ink, no coin flies, the socket stays
## empty and the paper stays plain (the user's play test of 2026-11-09: the metal is the medal won);
## the gauge still makes its laps.
func test_a_spent_medal_flies_nothing() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	run.machine.machine = run.machine.machine.duplicate() as MachineDefinition
	run.machine.machine.overtime_ticket_per_week = 0
	run.machine.machine.overtime_premium_per_week = 0
	screen._week.show_chips()
	var sockets: MedalCase = screen._stage.medal_case
	assert_array(sockets.states()).is_equal([USED, USED])
	_place_milks(screen, 7)
	await _frames(2)
	var quota: int = run.quota()
	assert_int(OvertimeTickets.laps(run.preview().total, quota)).is_greater_equal(3)
	assert_array(sockets.states()).is_equal([USED, USED])
	assert_int(screen._stage.receipt.gold.pending()).is_equal(ReceiptGold.PENDING_NONE)
	var ink: Array[Color] = screen._stage.receipt.target.hero_ink()
	assert_array(ink).is_equal([ReceiptTarget.HERO_COLOR, ReceiptTarget.NO_SHADOW])
	var steps: Array[int] = []
	screen._stage.gauge_panel.lap_run_step.connect(func(laps: int) -> void: steps.append(laps))
	await Rush.checkout(screen)
	assert_array(steps).is_empty()  # No medal prelude: the gauge runs no laps.
	assert_bool(screen._stage.medal_prelude.was_skipped()).is_false()
	var flow: ReceiptGoldFlow = screen._stage.gold_flow
	assert_bool(flow.has_flown(false) or flow.has_flown(true)).is_false()
	assert_bool(flow.flight.is_flying()).is_false()
	var receipt: ReceiptView = screen._stage.receipt
	assert_bool(receipt.gold.is_gold()).is_false()
	assert_bool(receipt.gold.is_silver()).is_false()
	assert_array(sockets.states()).is_equal([USED, USED])
	assert_int(screen._stage.quota_meter.multiples_made()).is_greater_equal(3)


## What a x3 checkout with both medals earned leaves once it ends: both spent, the paper gold all
## the way (the record's metal: gold alone, ReceiptGoldFlow.refresh), nothing in flight, the
## gauge up out of the bar.
static func _expected_end() -> Dictionary:
	return {
		"flown": [true, true],
		"silver": false,
		"silver_amount": 0.0,
		"gold": true,
		"gold_amount": 1.0,
		"flying": false,
		"gauge_up": 1.0,
		"medals": [USED, USED] as Array[int],
	}


static func _end_state(screen: ShiftScreen) -> Dictionary:
	var stage: ShiftStage = screen._stage
	var metal: ReceiptGold = stage.receipt.gold
	return {
		"flown": [stage.gold_flow.has_flown(false), stage.gold_flow.has_flown(true)],
		"silver": metal.is_silver(),
		"silver_amount": metal.silver_amount(),
		"gold": metal.is_gold(),
		"gold_amount": metal.amount(),
		"flying": stage.gold_flow.flight.is_flying(),
		"gauge_up": stage.gauge_panel.up_amount(),
		"medals": stage.medal_case.states(),
	}


## Appends `label` to `order` the first time `now` holds.
static func _first(seen: Dictionary, label: String, now: bool, order: Array[String]) -> void:
	if now and not seen.has(label):
		seen[label] = true
		order.append(label)


func _run() -> RunState:
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(7, deck, _balance, RunStock.starting(_balance))
	run.start_shift()
	return run


## Checks out `breads` Breads (5€ each).
func _check_out(run: RunState, breads: int) -> void:
	for _index: int in range(breads):
		run.place(run.debug_add_to_hand(load(BREAD)), run.row.size())
	run.checkout()


func _next(run: RunState) -> void:
	assert_bool(MachineSteps.next_shift(run)).is_true()


func _round_trip(run: RunState) -> RunState:
	var lookup: ContentLookup = ContentLookup.new(_balance)
	var data: Dictionary = _json(RunSave.to_dictionary(run, "id", 0))
	var save: RunSave = RunSave.from_dictionary(data, lookup)
	assert_object(save).is_not_null()
	return save.run if save != null else null


static func _json(data: Dictionary) -> Dictionary:
	var json: JSON = JSON.new()
	json.parse(JSON.stringify(data))
	return json.data


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()
	await _frames(2)
	return screen


## `count` items on the belt: Milk, Multipack, then Milks (7 make 109€, ×3 the first quota).
func _place_milks(screen: ShiftScreen, count: int) -> void:
	var ids: Array[String] = ["milk", "multipack"]
	for _index: int in range(count - 2):
		ids.append("milk")
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	for child: Node in screen._hand_box.get_children():
		var view: CardView = child as CardView
		if view and view.card == card and not view.is_queued_for_deletion():
			return view
	return null


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
