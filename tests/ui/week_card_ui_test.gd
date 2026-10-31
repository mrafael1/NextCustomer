extends GdUnitTestSuite
## The time card and the week and day chips on the real shift screen (v0.70, mock-up
## docs/art/mockups/rota_card_v1.html, layout C): the card plays as a week's first shift opens,
## lies inside the screen with its banner and 4 day rows apart, punches the days played and today,
## lists a review's maluses and reward, and flies into the week chip; the chips lie in the top bar
## between the QUOTA and LOYALTY chips, apart, with their texts and pips; tapping a chip reopens
## the card and tapping the card closes it; a resume mid-week never replays the card; and Bakery
## festival's +€2 plays in the count-up from the week chip; after each verdict the card stamps the
## day PAID or SLIP (v0.72). Clicks are sent to the handlers,
## because headless runs don't deliver input events.

const SCREEN := "res://ui/shift_screen.tscn"
const Rush := preload("res://tests/ui/count_up_rush.gd")
const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const RecordingSfx := preload("res://tests/presentation/recording_sfx.gd")

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Shift 1 opens week 1's card: inside the screen, its banner and 4 rows inside it and apart, day
## 1 punched IN, the review day's 2 maluses and its PREMIUM reward; the card holds, then flies into
## the week chip and closes, and planning's notices wait for it until then.
func test_the_card_plays_at_the_week_start_and_flies_into_the_chip() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(3)
	var card: WeekCard = screen._week.card
	assert_bool(card.is_open()).is_true()
	assert_bool(screen._week.holds_planning()).is_true()
	assert_bool(screen._scan_blocked()).is_true()
	card.finish()
	await _frames(2)
	var screen_rect: Rect2 = screen.get_global_rect()
	var body: Rect2 = card.card().get_global_rect()
	assert_bool(screen_rect.encloses(body)).override_failure_message(str(body)).is_true()
	assert_bool(body.encloses(card.banner().get_global_rect())).is_true()
	var rows: Array[Control] = card.rows()
	assert_int(rows.size()).is_equal(4)
	var previous: Rect2 = card.banner().get_global_rect()
	for row: Control in rows:
		var rect: Rect2 = row.get_global_rect()
		assert_bool(body.encloses(rect)).override_failure_message(row.name).is_true()
		assert_float(rect.position.y).is_greater_equal(previous.end.y)
		previous = rect
	var punched: Array[bool] = []
	for punch: Label in card.punches():
		punched.append(punch.modulate.a > 0.5)
	assert_array(punched).is_equal([true, false, false, false])
	var review: String = _texts(rows[3])
	assert_str(review).contains("MANAGER'S REVIEW · 2 MALUSES")
	# The reward reads on two lines (v0.72): "REVIEW PASSED", "2 PREMIUM TICKETS".
	for part: String in Payday.BANNER_LINE.split(" · "):
		assert_str(review).contains(part)
	for event: InspectionDefinition in screen.run.week.day(4):
		assert_str(review).contains(event.display_name)
	assert_str(_texts(card.banner())).contains("TRAINING WEEK")
	assert_str(_texts(card.banner())).contains("2 SLIPS")
	card.advance(WeekCard.HOLD + 0.01)
	assert_bool(card.is_shrinking()).is_true()
	card.advance(WeekCard.SHRINK)
	assert_bool(card.is_open()).is_false()
	assert_bool(screen._week.holds_planning()).is_false()


## The week chip ("W1", "TRAINING", 4 pips) and the day chip ("D1", grey "Normal day") lie in the
## top bar between the QUOTA and LOYALTY chips, apart, inside the stage above the panel line, their
## parts inside them; on shift 6 they read W2 with one pip played and D6.
func test_the_chips_lay_out_in_the_top_bar() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()
	await _frames(3)
	var chip: WeekChip = screen._stage.top_bar.week_chip
	var tag: InspectionTag = screen._inspection_tag
	assert_bool(chip.visible and tag.visible).is_true()
	assert_str(chip.number_label().text).is_equal("W1")
	assert_str(chip.name_label().text).is_equal("TRAINING")
	var pips: Array[WeekCardModel.Pip] = chip.pips()
	var expected: Array[WeekCardModel.Pip] = [
		WeekCardModel.Pip.NOW,
		WeekCardModel.Pip.TODO,
		WeekCardModel.Pip.TODO,
		WeekCardModel.Pip.TODO
	]
	assert_array(pips).is_equal(expected)
	assert_str(tag.day_label().text).is_equal("D1")
	assert_str(tag.text()).is_equal(WeekCardModel.NO_EVENT)
	_assert_chips_fit(screen)
	screen.run.debug_skip_to_shift(5)
	screen.debug_show_shift()
	screen._week.skip()
	await _frames(3)
	assert_str(chip.number_label().text).is_equal("W2")
	expected = [
		WeekCardModel.Pip.DONE,
		WeekCardModel.Pip.NOW,
		WeekCardModel.Pip.TODO,
		WeekCardModel.Pip.TODO
	]
	assert_array(chip.pips()).is_equal(expected)
	assert_str(tag.day_label().text).is_equal("D6")
	_assert_chips_fit(screen)


## Tapping the week chip, or the day chip, reopens the whole card in planning (open until
## tapped); tapping the card flies it back into the chip.
func test_a_chip_tap_reopens_the_card_and_a_tap_closes_it() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()
	await _frames(2)
	var card: WeekCard = screen._week.card
	var bar: TopBar = screen._stage.top_bar
	for chip: Control in [bar.week_chip, bar.inspection_tag]:
		assert_bool(card.is_open()).is_false()
		chip.call("_gui_input", _left_click())
		assert_bool(card.is_open()).override_failure_message(chip.name).is_true()
		assert_int(card.rows().size()).is_equal(4)
		card.advance(10.0)  # Open until tapped.
		assert_bool(card.is_open()).is_true()
		assert_bool(card.is_shrinking()).is_false()
		await _frames(2)
		assert_bool(screen.get_global_rect().encloses(card.card().get_global_rect())).is_true()
		card.call("_gui_input", _left_click())
		assert_bool(card.is_shrinking()).is_true()
		card.advance(WeekCard.SHRINK)
		assert_bool(card.is_open()).is_false()


## The final week's card: day 12 is the FINAL REVIEW, won by passing it; days 9-11 punched.
func test_the_final_review_reads_pass_to_win() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()
	screen.run.debug_skip_to_shift(11)
	screen.debug_show_shift()
	screen._week.skip()
	screen._week.reopen()
	var card: WeekCard = screen._week.card
	assert_bool(card.is_open()).is_true()
	var last: String = _texts(card.rows()[3])
	assert_str(last).contains("FINAL REVIEW · 2 MALUSES")
	assert_str(last).contains(WeekCardModel.FINAL_REWARD)
	assert_str(_texts(card.banner())).contains("HOLIDAY RUSH")
	var punched: Array[bool] = []
	for punch: Label in card.punches():
		punched.append(punch.modulate.a > 0.5)
	assert_array(punched).is_equal([true, true, true, true])


## A run resumed in planning mid-week shows its chips and never replays the card; one resumed on
## a week's first shift plays it.
func test_a_mid_week_resume_does_not_replay_the_card() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()
	var lookup: ContentLookup = ContentLookup.new(screen.run.balance)
	screen.run.debug_skip_to_shift(5)
	var mid: RunSave = RunSave.from_dictionary(_json(_saved(screen.run)), lookup)
	assert_object(mid).is_not_null()
	screen._resume_run(mid)
	await _frames(3)
	assert_bool(screen._week.card.is_open()).is_false()
	assert_bool(screen._week.holds_planning()).is_false()
	assert_str(screen._stage.top_bar.week_chip.number_label().text).is_equal("W2")
	assert_str(screen._inspection_tag.day_label().text).is_equal("D6")
	screen.run.debug_skip_to_shift(4)
	var start: RunSave = RunSave.from_dictionary(_json(_saved(screen.run)), lookup)
	screen._resume_run(start)
	await _frames(3)
	assert_bool(screen._week.card.is_open()).is_true()


## Bakery festival's +€2 on a Bakery product is a step of its own: the count-up plays it from the
## week chip, and the receipt names the week event.
func test_the_week_bonus_plays_in_the_count_up_from_the_week_chip() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()
	screen._debug.skip_to_shift(5)
	screen._debug.set_inspection("")  # Shift 5's own boon is not what this checks.
	_place_ids(screen, ["bread", "milk", "multipack", "milk", "milk", "milk", "milk"])
	var week_steps: Array = screen.run.preview().steps.filter(
		func(each: ScoreStep) -> bool: return each.source_kind == ScoreStep.SourceKind.INSPECTION
	)
	assert_int(week_steps.size()).is_equal(1)
	var week_step: ScoreStep = week_steps[0]
	assert_int(week_step.value).is_equal(2)
	await Rush.checkout(screen)
	var kinds: Array = []
	for beat: CountUpBeat in screen._count_up.plan.beats:
		for index: int in beat.steps:
			var counted: ScoreStep = screen.run.last_result.steps[index]
			if counted.source_kind == ScoreStep.SourceKind.INSPECTION:
				kinds.append(beat.kind)
	assert_array(kinds).is_equal([CountUpBeat.Kind.BONUS])
	var source: Control = screen._count_up._beats._source_control(week_step)
	assert_object(source).is_same(screen._stage.top_bar.week_chip)
	assert_str(_receipt_text(screen)).contains("Bakery festival")


## Holiday rush raises the machine's odds a level (v0.70): after shift 9 the stock window's lit
## columns show the raised level's shares and a gold "WEEK ODDS +1" line inside the window, clear
## of every odds label; after shift 8 (Bakery festival) there is none.
func test_the_stock_window_shows_the_week_odds() -> void:
	for shift: int in [8, 9]:
		var balance: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
		var quotas: PackedInt32Array = PackedInt32Array()
		for _index: int in range(balance.quotas.size()):
			quotas.append(1)
		balance.quotas = quotas
		var run: RunState = RunState.new(41, load(STARTER), balance, RunStock.starting(balance))
		run.start_shift()
		run.debug_skip_to_shift(shift - 1)
		run.place(run.debug_add_to_hand(load("res://data/cards/milk.tres")), 0)
		run.checkout()
		assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
		var view: RewardMachineView = auto_free(RewardMachineView.new())
		add_child(view)
		view.position = ShiftStage.MACHINE_RECT.position
		view.open_visit(run, null, null, false)
		view.fast_forward()
		await _frames(2)
		var line: Label = view.stock.week_odds_label()
		if shift == 8:
			assert_bool(line.visible).is_false()
		else:
			assert_bool(line.visible).is_true()
			assert_str(line.text).is_equal("WEEK ODDS +1")
			var window: Rect2 = view.stock.get_global_rect()
			var rect: Rect2 = line.get_global_rect()
			assert_bool(window.encloses(rect)).override_failure_message(str(rect)).is_true()
			for label: Label in view.stock.labels():
				if label.visible and label != line:
					assert_bool(rect.intersects(label.get_global_rect())).is_false()
			var level: int = run.machine.machine.odds_level_after(shift) + 1
			assert_int(run.machine.odds_level(run)).is_equal(level)
			var shares: Array[float] = []
			var chute: int = RewardMachine.Chute.UPGRADE
			shares.assign(Array(run.machine.chute_info(run, chute).odds.rarity_share))
			assert_array(Array(view.stock.odds_texts(chute))).is_equal(
				Array(StockWindow.percent_texts(shares))
			)
		view.close()
		remove_child(view)
		await _frames(2)


## The card's intro sounds: the print as it arrives, the banner's stamp, a tick per day row and
## today's punch a stamp; a tap closes it with the close sound.
func test_the_card_punches_with_sounds() -> void:
	var host: Control = _card_host()
	var sfx: RecordingSfx = RecordingSfx.new()
	host.add_child(sfx)
	var card: WeekCard = WeekCard.new()
	host.add_child(card)
	card.size = host.size
	card.play(WeekCardModel.of(_started_run()), host, false)
	for _step: int in range(40):
		card.advance(0.1)
	var heard: Array[String] = _sounds(sfx)
	assert_array(heard).contains(["print", "stamp_notice", "stamp_1", "tick"])
	assert_int(heard.find("print")).is_less(heard.find("stamp_notice"))
	assert_int(heard.count("stamp_1") + heard.count("tick")).is_equal(4)
	if card.is_open():
		card.call("_gui_input", _left_click())
		assert_array(_sounds(sfx)).contains(["ui_close"])
	card.advance(WeekCard.SHRINK)
	assert_bool(card.is_open()).is_false()


## Under reduced motion the whole card shows at once and stays open, at full size inside the
## screen, until tapped; a tap closes it at once.
func test_reduced_motion_keeps_the_card_until_tapped() -> void:
	var host: Control = _card_host()
	var card: WeekCard = WeekCard.new()
	host.add_child(card)
	card.size = host.size
	card.play(WeekCardModel.of(_started_run()), host, true)
	card.advance(card._intro_end() + WeekCard.HOLD + WeekCard.SHRINK + 1.0)
	await _frames(2)
	assert_bool(card.is_open()).is_true()
	assert_bool(card.is_shrinking()).is_false()
	var body: Rect2 = card.card().get_global_rect()
	assert_bool(host.get_global_rect().encloses(body)).override_failure_message(str(body)).is_true()
	assert_vector(card.card().scale).is_equal(Vector2.ONE)
	assert_float(card.card().modulate.a).is_equal(1.0)
	card.call("_gui_input", _left_click())
	assert_bool(card.is_open()).is_false()


## A week's first shift after a machine visit that upgraded a copy: the time card waits until the
## item upgrade swap has played (it would cover it), then plays.
func test_the_card_waits_for_the_upgrade_swap() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()
	await _frames(2)
	var machine: MachineFlow = screen._machine
	var copy: CardInstance = screen.run.hand()[0]
	machine.shown_swaps = [[CardInstance.new(copy.definition, 9999), copy]]
	assert_int(machine.play_swaps()).is_equal(1)
	screen._week.shift_started()
	await _frames(3)
	assert_bool(machine.is_swapping()).is_true()
	assert_bool(screen._week.card.is_open()).is_false()
	assert_bool(screen._week.holds_planning()).is_true()
	machine.swap.show_at(machine.swap.length())
	assert_bool(machine.is_swapping()).is_false()
	await _frames(3)
	assert_bool(screen._week.card.is_open()).is_true()
	(
		assert_bool(screen.get_global_rect().encloses(screen._week.card.card().get_global_rect()))
		. is_true()
	)


## Played days carry their result (v0.72) from the run's history: a passed shift PAID, a missed one
## SLIP with the misses so far over the training week's limit; a day not played none.
func test_played_days_carry_their_stamps() -> void:
	var run: RunState = _started_run()
	var quota: int = run.quota()
	run.history.append(ShiftRecord.new(1, quota, quota))
	run.history.append(ShiftRecord.new(2, quota, quota - 1))
	var days: Array[WeekCardModel.WeekDay] = WeekCardModel.of(run).days
	assert_int(days[0].result).is_equal(WeekCardModel.Result.PAID)
	assert_str(days[0].stamp()).is_equal("PAID")
	assert_int(days[1].result).is_equal(WeekCardModel.Result.SLIP)
	assert_str(days[1].stamp()).is_equal("SLIP 1/%d" % run.balance.write_up_limit)
	assert_int(days[2].result).is_equal(WeekCardModel.Result.NONE)
	assert_str(days[2].stamp()).is_empty()


## The rows read by time (#119): today's is ringed with a TODAY tab inside its row, right of the
## punch column; a played day fades under its whole stamp (no TODAY tab once today is played);
## the days to come are dimmed.
func test_the_rows_tell_today_past_and_upcoming() -> void:
	var host: Control = _card_host()
	var card: WeekCard = WeekCard.new()
	host.add_child(card)
	card.size = host.size
	var run: RunState = _started_run()
	run.debug_skip_to_shift(1)
	var quota: int = run.quota()
	run.history.append(ShiftRecord.new(1, quota, quota))
	card.reopen(WeekCardModel.of(run), null, true)
	await _frames(3)
	var rows: Array[Control] = card.rows()
	var tab: Label = card.today_tab()
	assert_object(tab).is_not_null()
	assert_str(tab.text).is_equal(WeekCardModel.TODAY_TAB)
	var rect: Rect2 = tab.get_global_rect()
	(
		assert_bool(rows[1].get_global_rect().encloses(rect))
		. override_failure_message(str(rect))
		. is_true()
	)
	assert_float(rect.position.x).is_greater(card.punches()[1].get_global_rect().end.x)
	assert_object(rows[1].find_child("TodayRing", false, false)).is_null()
	assert_float((rows[1].get_child(0) as Control).modulate.a).is_equal(1.0)
	var past: Control = rows[0].get_child(0) as Control
	assert_float(past.modulate.a).is_equal_approx(WeekCard.PAST_ALPHA, 0.01)
	assert_float(card.stamps()[0].modulate.a).is_equal(1.0)
	assert_float((rows[2].get_child(0) as Control).modulate.a).is_equal_approx(
		WeekCard.UPCOMING_ALPHA, 0.01
	)
	assert_float((rows[1].get_child(0) as Control).modulate.a).is_equal(1.0)
	run.history.append(ShiftRecord.new(2, quota, quota))
	card.reopen(WeekCardModel.of(run), null, true)
	await _frames(2)
	assert_object(card.today_tab()).is_null()


## A played day's pip shows its result (#119), today's too once checked out; flash() lights today's
## with PAID's sound (a SLIP's denied), rings the chip while it lasts, then ends; with reduced
## motion only the sound plays.
func test_the_chip_lights_the_day_result() -> void:
	for passed: bool in [true, false]:
		var host: Control = _card_host()
		var sfx: RecordingSfx = RecordingSfx.new()
		host.add_child(sfx)
		var chip: WeekChip = WeekChip.new()
		host.add_child(chip)
		var run: RunState = _started_run()
		var quota: int = run.quota()
		run.history.append(ShiftRecord.new(1, quota, quota if passed else quota - 1))
		chip.show_week(WeekCardModel.of(run))
		var lit: WeekCardModel.Pip = WeekCardModel.Pip.PAID if passed else WeekCardModel.Pip.SLIP
		assert_int(chip.pips()[0]).is_equal(lit)
		assert_int(chip.pips()[1]).is_equal(WeekCardModel.Pip.TODO)
		chip.flash(false)
		assert_bool(chip.is_flashing()).is_true()
		assert_array(_sounds(sfx)).contains(["stamp_paid" if passed else "denied"])
		chip.advance(WeekChip.FLASH)
		assert_bool(chip.is_flashing()).is_false()
		chip.flash(true)
		assert_bool(chip.is_flashing()).is_false()


## On the real screen the light comes between the verdict and what follows: during the count-up
## today's pip stays gold (v0.78); when the count-up ends the chip lights today's check, no time
## card opens, and the machine waits; once the light ends, the shift goes on.
func test_the_verdict_lights_the_day_before_the_machine() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(3)
	screen._week.card.finish()
	screen._week.card.advance(WeekCard.HOLD)
	screen._week.card.advance(WeekCard.SHRINK)
	await _frames(2)
	assert_bool(screen._week.is_open()).is_false()
	_place_ids(screen, ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"])
	assert_bool(screen.run.preview().total >= screen.run.quota()).is_true()
	Rush.checkout(screen)
	var chip: WeekChip = screen._stage.top_bar.week_chip
	await _frames(2)
	assert_bool(screen._counting).is_true()
	# The check waits for the light.
	assert_int(chip.pips()[0]).is_equal(WeekCardModel.Pip.NOW)
	var start: int = Time.get_ticks_msec()
	while screen._counting and Time.get_ticks_msec() - start < Rush.MAX_WAIT_MS:
		await _frames(1)
	await _frames(2)
	assert_bool(chip.is_flashing()).is_true()
	assert_int(chip.pips()[0]).is_equal(WeekCardModel.Pip.PAID)
	assert_bool(screen._week.card.is_open()).is_false()
	assert_bool(screen._machine.is_open()).is_false()
	chip.finish_flash()
	await _frames(3)
	assert_bool(screen._machine.is_open() or screen.run.phase == RunState.Phase.PLANNING).is_true()


func _card_host() -> Control:
	var host: Control = auto_free(Control.new())
	add_child(host)
	host.position = Vector2.ZERO
	host.size = Vector2(1280, 720)
	return host


func _started_run() -> RunState:
	var balance: BalanceDefinition = load(BALANCE)
	var run: RunState = RunState.new(43, load(STARTER), balance, RunStock.starting(balance))
	run.start_shift()
	return run


static func _sounds(sfx: RecordingSfx) -> Array[String]:
	var heard: Array[String] = []
	for entry: Dictionary in sfx.sounds:
		heard.append(String(entry["sound"]))
	return heard


func _assert_chips_fit(screen: ShiftScreen) -> void:
	var stage: Rect2 = screen._stage.get_global_rect()
	var bar: TopBar = screen._stage.top_bar
	var week: Rect2 = bar.week_chip.get_global_rect()
	var day: Rect2 = bar.inspection_tag.get_global_rect()
	assert_float(bar.get_combined_minimum_size().x).is_less_equal(stage.size.x - 40)
	for rect: Rect2 in [week, day]:
		assert_bool(stage.encloses(rect)).override_failure_message(str(rect)).is_true()
		assert_float(rect.end.y).is_less_equal(stage.position.y + ShiftStage.PANEL_TOP)
	var quota_chip: Rect2 = (bar.get_child(1) as Control).get_global_rect()
	assert_float(week.position.x).is_greater_equal(quota_chip.end.x)
	assert_float(day.position.x).is_greater_equal(week.end.x)
	assert_float(day.end.x).is_less_equal(screen._loyalty_card.get_global_rect().position.x)
	var parts: Array[Control] = [bar.week_chip.number_label()]
	if bar.week_chip.pips_shown():
		parts.append(bar.week_chip.pips_view())
	if bar.week_chip.name_shown():
		parts.append(bar.week_chip.name_label())
	var previous_end: float = week.position.x
	for part: Control in parts:
		var rect: Rect2 = part.get_global_rect()
		assert_bool(week.encloses(rect)).override_failure_message(part.name).is_true()
	for index: int in range(1, parts.size()):
		var a: Rect2 = parts[index - 1].get_global_rect()
		var b: Rect2 = parts[index].get_global_rect()
		assert_bool(a.intersects(b)).override_failure_message(parts[index].name).is_false()
	assert_float(previous_end).is_less_equal(week.end.x)
	var day_label: Rect2 = bar.inspection_tag.day_label().get_global_rect()
	var text: Rect2 = bar.inspection_tag.label().get_global_rect()
	assert_bool(day.encloses(day_label) and day.encloses(text)).is_true()
	assert_bool(day_label.intersects(text)).is_false()


func _place_ids(screen: ShiftScreen, ids: Array[String]) -> void:
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())


static func _saved(run: RunState) -> Dictionary:
	return RunSave.to_dictionary(run, "run-1", 10)


static func _json(data: Dictionary) -> Dictionary:
	var json: JSON = JSON.new()
	json.parse(JSON.stringify(data))
	return json.data


static func _texts(root: Node) -> String:
	var texts: PackedStringArray = PackedStringArray()
	for label: Node in root.find_children("*", "Label", true, false):
		texts.append((label as Label).text)
	return "\n".join(texts)


static func _receipt_text(screen: ShiftScreen) -> String:
	var texts: PackedStringArray = PackedStringArray()
	for label: Node in screen._receipt.find_children("*", "Label", true, false):
		if not label.is_queued_for_deletion() and not label.get_parent().is_queued_for_deletion():
			texts.append((label as Label).text)
	return "\n".join(texts)


func _frames(count: int) -> void:
	for i: int in range(count):
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
