extends GdUnitTestSuite
## The over-quota rewards' cues (v1.03): the gauge's chip (OvertimeChip, popped by QuotaCrossing as
## the count's laps reach ×2 and ×3) shows each reward earned or used this week, only while
## counting; on the real shift screen its rows sit beside the gauge's top, inside the screen and
## clear of the register tower (the receipt) and the monitor. OvertimeCue dresses the count's
## context from the run (the OVERTIME ticket's stub only when no BONUS visit comes first), and the
## OVERTIME ticket takes its own title. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const BREAD := "res://data/cards/bread.tres"
const EARNED := OvertimeTickets.State.EARNED
const USED := OvertimeTickets.State.USED
const NONE := OvertimeTickets.State.NONE

var _folder: String = ""
var _runner: GdUnitSceneRunner


func before_test() -> void:
	_folder = "user://test_overtime_chip_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_the_chip_shows_each_reward_once() -> void:
	var chip: OvertimeChip = auto_free(OvertimeChip.new())
	chip.reduced_motion = true
	add_child(chip)
	chip.show_reward(false, NONE, "×2")
	assert_array(Array(chip.texts())).is_empty()
	assert_bool(chip.visible).is_false()
	chip.show_reward(true, EARNED, "×3")
	chip.show_reward(false, EARNED, "×2")
	chip.show_reward(false, EARNED, "×2")
	# The extra ticket's row stays on top.
	assert_array(Array(chip.texts())).is_equal(["×2 +1 TICKET", "×3 PREMIUM TICKET"])
	assert_bool(chip.visible).is_true()
	chip.clear()
	await get_tree().process_frame
	assert_array(Array(chip.texts())).is_empty()
	chip.show_reward(false, USED, "×2")
	assert_array(Array(chip.texts())).is_equal(["×2 · USED THIS WEEK"])


## A USED row (no ticket picture) is as tall as an earned one, so either covers the ceiling lamp's
## shade beside the gauge's top (v1.13 review).
func test_used_rows_are_as_tall_as_earned_rows() -> void:
	var chip: OvertimeChip = auto_free(OvertimeChip.new())
	chip.reduced_motion = true
	add_child(chip)
	chip.show_reward(false, EARNED, "×2")
	chip.show_reward(true, EARNED, "×3")
	await get_tree().process_frame
	var earned: Array[Rect2] = chip.row_rects()
	chip.clear()
	await get_tree().process_frame
	chip.show_reward(false, USED, "×2")
	chip.show_reward(true, USED, "×3")
	await get_tree().process_frame
	var used: Array[Rect2] = chip.row_rects()
	assert_int(used.size()).is_equal(2)
	for row: int in 2:
		assert_float(used[row].size.y).is_equal(earned[row].size.y)
		assert_float(used[row].position.y).is_equal(earned[row].position.y)


## Alone: the laps pop the rows the count's context states, only while counting; a jump past both
## laps shows both; the count's end holds them, then fades them out; the next count clears them.
func test_the_crossing_pops_the_rows_the_laps_reach() -> void:
	var meter: QuotaMeter = auto_free(QuotaMeter.new())
	meter.size = ShiftStage.TUBE_RECT.size
	add_child(meter)
	var lights: BonusLights = auto_free(BonusLights.new())
	add_child(lights)
	var crossing: QuotaCrossing = auto_free(QuotaCrossing.new())
	add_child(crossing)
	var count_up: CountUp = auto_free(CountUp.new())
	add_child(count_up)
	crossing.follow(count_up, meter, lights)
	count_up.run_context = _context(EARNED, USED)
	meter.lap_reached.emit(2)
	assert_array(Array(crossing.chip.texts())).is_empty()
	crossing.begin()
	meter.lap_reached.emit(2)
	assert_array(Array(crossing.chip.texts())).is_equal(["×2 +1 TICKET"])
	meter.lap_reached.emit(3)
	assert_array(Array(crossing.chip.texts())).is_equal(["×2 +1 TICKET", "×3 · USED THIS WEEK"])
	crossing.end()
	await get_tree().process_frame
	assert_int(crossing.chip.texts().size()).is_equal(2)
	assert_bool(crossing.chip.fading()).is_true()
	crossing.begin()
	assert_array(Array(crossing.chip.texts())).is_empty()
	assert_bool(crossing.chip.fading()).is_false()
	assert_float(crossing.chip.modulate.a).is_equal(1.0)
	meter.lap_reached.emit(4)
	assert_int(crossing.chip.texts().size()).is_equal(2)
	# A PREMIUM ticket left as it was (NONE) shows no row.
	crossing.begin()
	count_up.run_context = _context(EARNED, NONE)
	meter.lap_reached.emit(3)
	assert_array(Array(crossing.chip.texts())).is_equal(["×2 +1 TICKET"])
	# No context (no count played yet): nothing.
	crossing.begin()
	count_up.run_context = null
	meter.lap_reached.emit(3)
	assert_array(Array(crossing.chip.texts())).is_empty()


## The fade ends with the rows gone and the chip hidden, its alpha back.
func test_the_chip_fades_out_after_its_hold() -> void:
	var chip: OvertimeChip = auto_free(OvertimeChip.new())
	chip.reduced_motion = true
	add_child(chip)
	chip.fade_out()
	assert_bool(chip.fading()).is_false()  # Nothing to fade.
	chip.show_reward(false, EARNED, "×2")
	chip.fade_out()
	var start: int = Time.get_ticks_msec()
	var limit_ms: int = int((OvertimeChip.HOLD_SECONDS + OvertimeChip.FADE_SECONDS) * 1000.0) + 2000
	while chip.fading() and Time.get_ticks_msec() - start < limit_ms:
		await get_tree().process_frame
	await get_tree().process_frame
	assert_array(Array(chip.texts())).is_empty()
	assert_bool(chip.visible).is_false()
	assert_float(chip.modulate.a).is_equal(1.0)


## As the total lands, the rows of every reward the total's laps reach show, even with no lap's
## pop during the count (a skip's jump, a Double checkout's row 2 counting on past ×2).
func test_the_total_landing_shows_the_rewards_its_laps_reach() -> void:
	var meter: QuotaMeter = auto_free(QuotaMeter.new())
	meter.size = ShiftStage.TUBE_RECT.size
	add_child(meter)
	var lights: BonusLights = auto_free(BonusLights.new())
	add_child(lights)
	var crossing: QuotaCrossing = auto_free(QuotaCrossing.new())
	add_child(crossing)
	var count_up: CountUp = auto_free(CountUp.new())
	add_child(count_up)
	crossing.follow(count_up, meter, lights)
	count_up.run_context = _context(EARNED, EARNED)
	crossing.begin()
	meter.show_projected(95, 30)  # Not counting: no lap pops.
	assert_array(Array(crossing.chip.texts())).is_empty()
	assert_int(meter.multiples_made()).is_equal(3)
	count_up.total_landed.emit()
	assert_array(Array(crossing.chip.texts())).is_equal(["×2 +1 TICKET", "×3 PREMIUM TICKET"])
	# Short of ×2: nothing.
	crossing.begin()
	meter.show_projected(50, 30)
	count_up.total_landed.emit()
	assert_array(Array(crossing.chip.texts())).is_empty()
	crossing.end()


## A Double checkout's row 1 (#122) is counted while the run still plans the shift, the last
## record an earlier shift's: the cue states no reward (row 2's count states the shift's own).
func test_the_cue_states_nothing_for_a_double_checkouts_row_one() -> void:
	var run: RunState = _x3_run()
	run.checkout()
	var earned: CountUpContext = CountUpContext.new()
	OvertimeCue.dress(run, earned)
	assert_int(earned.overtime_ticket).is_equal(EARNED)
	MachineSteps.next_shift(run)
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	var row_one: CountUpContext = CountUpContext.new()
	OvertimeCue.dress(run, row_one)
	assert_int(row_one.overtime_ticket).is_equal(NONE)
	assert_int(row_one.overtime_premium).is_equal(NONE)
	assert_int(row_one.overtime_ticket_laps).is_equal(0)
	assert_int(row_one.overtime_premium_laps).is_equal(0)
	assert_str(row_one.overtime_stub).is_empty()


## On the real screen both rows sit under the top bar (where the "×N" stamp was until v1.13),
## inside the viewport, clear of the register tower (the receipt) and of the monitor, and apart.
func test_the_rows_sit_beside_the_gauge_clear_of_the_receipt_and_monitor() -> void:
	_runner = scene_runner(SCREEN)
	var screen: ShiftScreen = _runner.scene()
	await _frames(2)
	var crossing: QuotaCrossing = screen._stage.quota_crossing
	screen._count_up.run_context = _context(EARNED, EARNED)
	crossing.begin()
	crossing.reduced_motion = true
	crossing.chip.reduced_motion = true
	crossing.show_rewards(3)
	await _frames(3)
	var rows: Array[Rect2] = crossing.chip.row_rects()
	assert_int(rows.size()).is_equal(2)
	var to_global: Transform2D = crossing.get_global_transform()
	var tower: Rect2 = to_global * ShiftStage.TOWER_RECT
	var monitor: Rect2 = to_global * ShiftStage.MONITOR_RECT
	var top_bar_foot: float = (to_global * Vector2(0, ShiftStage.TOP_BAR_BOTTOM)).y
	var screen_rect: Rect2 = Rect2(Vector2.ZERO, screen.get_viewport_rect().size)
	for row: Rect2 in rows:
		assert_bool(row.has_area()).is_true()
		assert_bool(screen_rect.encloses(row)).override_failure_message(str(row)).is_true()
		assert_bool(row.intersects(tower)).override_failure_message(str(row)).is_false()
		assert_bool(row.intersects(monitor)).override_failure_message(str(row)).is_false()
		assert_float(row.position.y).is_greater_equal(top_bar_foot)
		assert_float(row.size.x).is_less_equal(OvertimeChip.MAX_WIDTH * to_global.get_scale().x)
	assert_bool(rows[0].intersects(rows[1])).is_false()
	assert_float(rows[1].position.y).is_greater(rows[0].end.y)
	crossing.end()


## OvertimeCue reads the run after its checkout: the states and laps, the OVERTIME stub when it is
## the first extra visit, and the checkout event's fields.
func test_the_cue_dresses_the_count_from_the_run() -> void:
	var run: RunState = _x3_run()
	var machine: MachineDefinition = run.balance.machine
	run.checkout()
	var context: CountUpContext = CountUpContext.new()
	OvertimeCue.dress(run, context)
	assert_int(context.overtime_ticket).is_equal(EARNED)
	assert_int(context.overtime_premium).is_equal(EARNED)
	assert_int(context.overtime_ticket_laps).is_equal(2)
	assert_int(context.overtime_premium_laps).is_equal(3)
	assert_bool(context.bonus_ticket).is_false()
	assert_str(context.overtime_stub).is_equal("×2 over quota · keep me")
	assert_str(BonusTicket.title_for(context.overtime_stub)).is_equal("OVERTIME TICKET")
	assert_str(BonusTicket.title_for(BonusTicket.INSPECTED_SUB)).is_equal(BonusTicket.TITLE)
	assert_dict(OvertimeCue.checkout_fields(run)).is_equal(
		{"overtime_ticket": true, "overtime_premium": true}
	)
	# With a BONUS visit first, the stub is the bonus ticket's.
	machine.bonus_extra_shifts = PackedInt32Array([2])
	MachineSteps.next_shift(run)
	for _index: int in range(4):
		run.place(run.debug_add_to_hand(load(BREAD)), run.row.size())
	run.checkout()
	var second: CountUpContext = CountUpContext.new()
	OvertimeCue.dress(run, second)
	assert_bool(second.bonus_ticket).is_true()
	assert_int(second.overtime_ticket).is_equal(USED)
	assert_str(second.overtime_stub).is_empty()


## A run on shift 1 (quota 10; no inspections, PREMIUM or BONUS shifts) whose six Bread make ×3,
## not yet checked out.
func _x3_run() -> RunState:
	var balance: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
	balance.quotas = PackedInt32Array([10, 10, 10, 10, 10, 10, 10, 10])
	balance.inspection_shifts = PackedInt32Array()
	balance.review_shifts = PackedInt32Array()
	balance.boon_shifts = PackedInt32Array()
	balance.weeks = []
	balance.week_length = 4
	balance.write_up_limit = 0
	var machine: MachineDefinition = balance.machine.duplicate()
	machine.premium_shifts = PackedInt32Array()
	machine.bonus_extra_shifts = PackedInt32Array()
	machine.bonus_after_inspection = false
	balance.machine = machine
	var run: RunState = RunState.new(5, load(STARTER), balance, RunStock.starting(balance))
	run.start_shift()
	for _index: int in range(6):
		run.place(run.debug_add_to_hand(load(BREAD)), run.row.size())
	return run


static func _context(ticket: int, premium: int) -> CountUpContext:
	var context: CountUpContext = CountUpContext.new()
	context.overtime_ticket = ticket
	context.overtime_premium = premium
	context.overtime_ticket_laps = 2
	context.overtime_premium_laps = 3
	return context


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


func _event_log() -> EventLog:
	return get_tree().root.get_node("EventLog") as EventLog
