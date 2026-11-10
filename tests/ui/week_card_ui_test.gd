extends GdUnitTestSuite
## The time card, the day calendar and the week glass on the real shift screen (v0.70, mock-up
## docs/art/mockups/rota_card_v1.html, layout C; v1.17's calendar and glass): the card plays as a
## week's first shift opens, lies inside the screen with its banner and 4 day rows apart, punches
## the days played and today, lists a review's maluses and reward, and flies into the week glass;
## the calendar lies in the top bar before LOYALTY and the glass on the register, with their texts
## and pips; tapping the glass reopens the card and tapping the card closes it; a resume mid-week
## never replays the card; and Bakery festival's +2€ plays in the count-up from the week glass;
## after each verdict the card stamps the day PAID or SLIP (v0.72). Clicks are sent to the
## handlers, because headless runs don't deliver input events.

const SCREEN := "res://ui/shift_screen.tscn"
const Rush := preload("res://tests/ui/count_up_rush.gd")
const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const INSPECTIONS := "res://data/inspections"
## A full loyalty card's perks (the review-day caption test).
const FULL_CARD: Array[String] = ["coupon_engine", "bulk_deal", "category_engine", "big_basket"]
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
## the week glass and closes, and planning's notices wait for it until then.
func test_the_card_plays_at_the_week_start_and_flies_into_the_glass() -> void:
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
	# The reward reads on two lines (v0.72): "REVIEW PASSED", "2 PREMIUM DRAWS" (2026-11-06).
	for part: String in Payday.BANNER_LINE.split(" · "):
		assert_str(review).contains(part)
	for event: InspectionDefinition in screen.run.week.day(4):
		assert_str(review).contains(event.display_name)
	assert_str(_texts(card.banner())).contains("TRAINING WEEK")
	# The misses stand on a red tag after "THIS WEEK ALLOWS" (v0.84).
	assert_str(_texts(card.banner())).contains(WeekCardModel.ALLOWS_LEAD)
	var misses: Label = card.banner().find_child("MissesTag", true, false) as Label
	assert_str(misses.text).is_equal("2 MISSES")
	var tag_box: StyleBoxFlat = misses.get_theme_stylebox("normal") as StyleBoxFlat
	assert_that(tag_box.bg_color).is_equal(Palette.TOMATO)
	card.advance(WeekCard.HOLD + 0.01)
	assert_bool(card.is_shrinking()).is_true()
	card.advance(WeekCard.SHRINK)
	assert_bool(card.is_open()).is_false()
	assert_bool(screen._week.holds_planning()).is_false()


## The week glass ("WEEK", "1", "/4") on the register and the day calendar (day 1,
## "Normal day", 4 pips) in the top bar before LOYALTY (v1.17), inside the stage, their parts
## inside them; on shift 6 they read week 2 with one pip played and day 6.
func test_the_calendar_and_glass_lay_out() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()
	await _frames(3)
	var glass: WeekGlass = screen._stage.week_glass
	var calendar: DayCalendar = screen._stage.day_calendar
	assert_bool(glass.visible and calendar.visible).is_true()
	assert_str(glass.week_label.text).is_equal(WeekGlass.WEEK_WORD)
	assert_str(glass.number_label.text).is_equal("1")
	assert_str(glass.count_label.text).is_equal("/4")
	var expected: Array[WeekCardModel.Pip] = [
		WeekCardModel.Pip.NOW,
		WeekCardModel.Pip.TODO,
		WeekCardModel.Pip.TODO,
		WeekCardModel.Pip.TODO
	]
	assert_array(calendar.pips()).is_equal(expected)
	assert_int(calendar.day()).is_equal(1)
	assert_str(calendar.text()).is_equal(DayCalendar.NORMAL_WORD)
	_assert_week_parts_fit(screen)
	screen.run.debug_skip_to_shift(5)
	screen.debug_show_shift()
	screen._week.skip()
	await _frames(3)
	assert_str(glass.number_label.text).is_equal("2")
	expected = [
		WeekCardModel.Pip.DONE,
		WeekCardModel.Pip.NOW,
		WeekCardModel.Pip.TODO,
		WeekCardModel.Pip.TODO
	]
	assert_array(calendar.pips()).is_equal(expected)
	assert_int(calendar.day()).is_equal(6)
	_assert_week_parts_fit(screen)


## The day calendar keeps one width beside every single day event (v1.17; the week chip's name
## gave way since 2026-11-03, the calendar has room for every name): each inspection's page, with
## the bonus ticket's pill where the inspection promises one, never shortened, the medal case
## showing, everything inside the stage. A review's two maluses keep the pips.
func test_the_calendar_keeps_one_width_for_every_day_event() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()
	MachineSteps.bonus_after_inspection(screen.run)
	await _frames(3)
	var calendar: DayCalendar = screen._stage.day_calendar
	var promised: int = 0
	var widths: Array[float] = []
	for file_name: String in DirAccess.get_files_at(INSPECTIONS):
		if not file_name.ends_with(".tres"):
			continue
		screen._debug.set_inspection(file_name.get_basename())
		await _frames(3)
		assert_str(screen.run.inspections[0].resource_path.get_file()).is_equal(file_name)
		if calendar.bonus_state() == InspectionTag.Bonus.PROMISED:
			promised += 1
		var medals: MedalCase = screen._stage.medal_case
		assert_bool(medals.is_visible_in_tree()).override_failure_message(file_name).is_true()
		assert_bool(calendar.is_shortened()).override_failure_message(file_name).is_false()
		widths.append(calendar.size.x)
		# The bonus pulse scales the pad a moment past its slot (BonusNotice): its rest size.
		screen._machine.notice.stop()
		_assert_week_parts_fit(screen)
	assert_int(promised).is_greater(0)
	assert_float(float(widths.max()) - float(widths.min())).is_less_equal(0.01)
	var run: RunState = screen.run
	run.inspections = [
		load(INSPECTIONS + "/spot_check.tres"), load(INSPECTIONS + "/late_delivery.tres")
	]
	run.debug_skip_to_shift(run.shift_index)
	screen._on_shift_started()
	screen._week.drop()
	await _frames(3)
	assert_int(calendar.pips().size()).is_equal(4)
	assert_bool(calendar.is_shortened()).is_false()
	screen._machine.notice.stop()
	_assert_week_parts_fit(screen)


## Tapping the week glass reopens the whole card in planning (open until tapped); tapping the card
## flies it back into the glass. The day calendar drops today's slip instead (DaySlip,
## day_slip_test).
func test_a_glass_tap_reopens_the_card_and_a_tap_closes_it() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()
	await _frames(2)
	var card: WeekCard = screen._week.card
	screen._stage.day_calendar.call("_gui_input", _left_click())
	assert_bool(card.is_open()).override_failure_message("the day calendar").is_false()
	screen._week.slip.clear()
	for chip: Control in [screen._stage.week_glass]:
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
	screen.run.debug_skip_to_shift(screen.run.shift_count() - 1)
	screen.debug_show_shift()
	screen._week.skip()
	screen._week.reopen()
	var card: WeekCard = screen._week.card
	assert_bool(card.is_open()).is_true()
	var last: String = _texts(card.rows()[3])
	assert_str(last).contains("FINAL REVIEW · 2 MALUSES")
	assert_str(last).contains(WeekCardModel.FINAL_REWARD)
	# Week 4 (v0.96): Clearance week, its banner in its own colour (orange dark).
	assert_str(_texts(card.banner())).contains("CLEARANCE WEEK")
	# Its effect's gain green and its quota red, outlined in paper on the banner (v1.02).
	var effect: RichTextLabel = card.banner().find_child("Effect", true, false) as RichTextLabel
	assert_bool(effect.visible).is_true()
	assert_str(effect.get_parsed_text()).is_equal("Clearance items +2€, quota +15%")
	assert_bool(effect.get_theme_color("default_color") == Palette.PAPER).is_true()
	var outline: String = (
		"[outline_size=%d][outline_color=#%s]"
		% [WeekCard.PAPER_OUTLINE, Palette.PAPER.to_html(false)]
	)
	assert_str(effect.text).contains(
		outline + "[color=#%s]+2€[/color]" % Palette.GREEN_DARK.to_html(false)
	)
	assert_str(effect.text).contains(
		outline + "[color=#%s]+15%%[/color]" % Palette.TOMATO_DARK.to_html(false)
	)
	assert_bool(WeekCard.colour_of(4) == Palette.ORANGE_DARK).is_true()
	var colours: Array[Color] = []
	for week: int in range(1, 5):
		assert_bool(colours.has(WeekCard.colour_of(week))).is_false()
		colours.append(WeekCard.colour_of(week))
	var punched: Array[bool] = []
	for punch: Label in card.punches():
		punched.append(punch.modulate.a > 0.5)
	assert_array(punched).is_equal([true, true, true, true])


## A run resumed in planning mid-week shows its glass and calendar (no page falls) and never
## replays the card; one resumed on a week's first shift plays it.
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
	assert_str(screen._stage.week_glass.number_label.text).is_equal("2")
	assert_int(screen._stage.day_calendar.day()).is_equal(6)
	assert_bool(screen._stage.day_calendar.is_changing()).is_false()
	screen.run.debug_skip_to_shift(4)
	var start: RunSave = RunSave.from_dictionary(_json(_saved(screen.run)), lookup)
	screen._resume_run(start)
	await _frames(3)
	assert_bool(screen._week.card.is_open()).is_true()


## Bakery festival's +2€ on a Bakery product is a step of its own: the count-up plays it from the
## week glass, and the receipt names the week event.
func test_the_week_bonus_plays_in_the_count_up_from_the_glass() -> void:
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
	assert_object(source).is_same(screen._stage.week_glass)
	# The anchored receipt pays planning's rows in place: the bonus plays on the monitor, not as a
	# printed line (2026-11-05).
	assert_str(_receipt_text(screen)).not_contains("Bakery festival")


## Holiday rush raises the machine's odds a level (v0.70): after shift 9 the stock window's lit
## columns show the raised level's shares and a gold "ODDS +1 · WEEK" tag inside the window (under
## its odds plates since v0.99), clear of every odds label; after shift 8 (Bakery festival) there
## is none.
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
		var line: MachineLine = view.stock.week_odds_label()
		if shift == 8:
			assert_bool(line.visible).is_false()
		else:
			assert_bool(line.visible).is_true()
			assert_str(line.text()).is_equal("ODDS +1 · WEEK")
			var window: Rect2 = view.stock.get_global_rect()
			var rect: Rect2 = line.get_global_rect()
			assert_bool(window.encloses(rect)).override_failure_message(str(rect)).is_true()
			for other: MachineLine in view.stock.lines():
				if other.is_visible_in_tree():
					assert_bool(rect.intersects(other.get_global_rect())).is_false()
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
	# Skip the slide-in so the rect is settled however long the frames took (a busy batch run).
	screen._week.card.finish()
	await _frames(1)
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


## Every icon on the card (a day event's, the review's tickets) is centred on its row's height
## (v0.83), not hung at its top.
func test_the_row_icons_are_centred() -> void:
	var host: Control = _card_host()
	var card: WeekCard = WeekCard.new()
	host.add_child(card)
	card.size = host.size
	var run: RunState = _started_run()
	run.debug_skip_to_shift(4)
	card.reopen(WeekCardModel.of(run), null, true)
	await _frames(3)
	# The card's only sprites are its rows' icons.
	var icons: Array[Node] = card.find_children("*", "TextureRect", true, false)
	var rewards: int = 0
	for node: Node in icons:
		var icon: TextureRect = node as TextureRect
		var row: Control = icon.get_parent() as Control
		var centre: float = icon.get_global_rect().get_center().y
		(
			assert_float(centre)
			. override_failure_message("%s: %.1f" % [icon.get_path(), centre])
			. is_equal_approx(row.get_global_rect().get_center().y, 1.0)
		)
		assert_bool(row.get_global_rect().encloses(icon.get_global_rect())).is_true()
		if row.get_parent() is WeekCard.ShadowPanel:
			rewards += 1
	assert_int(icons.size()).is_greater(rewards)
	assert_int(rewards).is_greater(0)


## The desk calendar (left column v2) lies on whole pixels of the screen at 1280x720 and at
## 1920x1080's 1.5x stretch, its number, DAY and sign inside the pad and apart; it shows one paper
## edge per day left in the week after today and keeps each day's result for the week.
func test_the_desk_calendar_is_whole_and_counts_the_days_left() -> void:
	var host: Control = _card_host()
	var calendar: DayCalendar = DayCalendar.new()
	host.add_child(calendar)
	calendar.position = Vector2(100.0, 6.0)
	var run: RunState = _started_run()
	var quota: int = run.quota()
	run.history.append(ShiftRecord.new(1, quota, quota))
	run.history.append(ShiftRecord.new(2, quota, quota - 1))
	run.debug_skip_to_shift(2)
	var empty: Array[InspectionDefinition] = []
	calendar.show_inspections(empty, 3, empty, run.shift_count())
	calendar.show_week(WeekCardModel.of(run))
	for scale: float in [1.0, 1.5]:
		calendar.scale = Vector2(scale, scale)
		await _frames(2)
		var parts: Dictionary = calendar.part_rects()
		var pad: Rect2 = parts["pad"]
		var message: String = "%sx: %s" % [scale, pad]
		assert_vector(pad.position).override_failure_message(message).is_equal(pad.position.round())
		var inside: Array[Rect2] = [parts["number"], parts["day"]]
		for sign_rect: Rect2 in parts["signs"]:
			inside.append(sign_rect)
		for index: int in range(inside.size()):
			var rect: Rect2 = inside[index]
			assert_vector(rect.position).override_failure_message(message).is_equal(
				rect.position.round()
			)
			assert_bool(pad.encloses(rect)).override_failure_message(message).is_true()
			for other: int in range(index + 1, inside.size()):
				assert_bool(rect.intersects(inside[other])).is_false()
		assert_int(parts["edges"]).is_equal(1)
	var expected: Array[WeekCardModel.Pip] = [
		WeekCardModel.Pip.PAID,
		WeekCardModel.Pip.SLIP,
		WeekCardModel.Pip.NOW,
		WeekCardModel.Pip.TODO
	]
	assert_array(calendar.pips()).is_equal(expected)


## A played day's pip shows its result (#119), today's too once checked out; flash() lights today's
## with PAID's sound (a SLIP's denied), the pip popping and the pad ringed while it lasts, then
## ends; with reduced motion only the sound plays.
func test_the_calendar_lights_the_day_result() -> void:
	for passed: bool in [true, false]:
		var host: Control = _card_host()
		var sfx: RecordingSfx = RecordingSfx.new()
		host.add_child(sfx)
		var calendar: DayCalendar = DayCalendar.new()
		host.add_child(calendar)
		var run: RunState = _started_run()
		var quota: int = run.quota()
		run.history.append(ShiftRecord.new(1, quota, quota if passed else quota - 1))
		var empty: Array[InspectionDefinition] = []
		calendar.show_inspections(empty, 1, empty, run.shift_count())
		calendar.show_week(WeekCardModel.of(run))
		var lit: WeekCardModel.Pip = WeekCardModel.Pip.PAID if passed else WeekCardModel.Pip.SLIP
		assert_int(calendar.pips()[0]).is_equal(lit)
		assert_int(calendar.pips()[1]).is_equal(WeekCardModel.Pip.TODO)
		calendar.flash(false)
		assert_bool(calendar.is_flashing()).is_true()
		assert_array(_sounds(sfx)).contains(["stamp_paid" if passed else "denied"])
		calendar.advance(DayCalendar.FLASH)
		assert_bool(calendar.is_flashing()).is_false()
		calendar.flash(true)
		assert_bool(calendar.is_flashing()).is_false()
		# While a shift is counted today's result waits (hold_result).
		calendar.hold_result = true
		calendar.show_week(WeekCardModel.of(run))
		assert_int(calendar.pips()[0]).is_equal(WeekCardModel.Pip.NOW)


## On the real screen the light comes between the verdict and what follows: during the count-up
## today's pip stays today's (v0.78); when the count-up ends the calendar lights today's check, no
## time card opens, and the machine waits; once the light ends, the shift goes on.
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
	var calendar: DayCalendar = screen._stage.day_calendar
	await _frames(2)
	assert_bool(screen._counting).is_true()
	# The check waits for the light.
	assert_int(calendar.pips()[0]).is_equal(WeekCardModel.Pip.NOW)
	var start: int = Time.get_ticks_msec()
	while screen._counting and Time.get_ticks_msec() - start < Rush.MAX_WAIT_MS:
		await _frames(1)
	await _frames(2)
	assert_bool(calendar.is_flashing()).is_true()
	assert_int(calendar.pips()[0]).is_equal(WeekCardModel.Pip.PAID)
	assert_bool(screen._week.card.is_open()).is_false()
	assert_bool(screen._machine.is_open()).is_false()
	calendar.advance(DayCalendar.FLASH)
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


## The desk calendar (left column v2) on the register's top inside the stage, its tags inside the
## stage, its parts inside the pad and apart; the top bar fits the stage; the glass inside the
## register's key deck, its words inside its glass and apart, clear of the deck's other keys.
func _assert_week_parts_fit(screen: ShiftScreen) -> void:
	var stage: Rect2 = screen._stage.get_global_rect()
	var bar: TopBar = screen._stage.top_bar
	var calendar: DayCalendar = screen._stage.day_calendar
	var parts: Dictionary = calendar.part_rects()
	var pad: Rect2 = parts["pad"]
	assert_float(bar.get_combined_minimum_size().x).is_less_equal(stage.size.x - 40)
	assert_bool(stage.encloses(pad)).override_failure_message(str(pad)).is_true()
	var desk: Rect2 = screen._stage.get_global_transform() * ShiftStage.DESK_CALENDAR_RECT
	assert_bool(desk.grow(1.0).encloses(pad)).override_failure_message(str(pad)).is_true()
	var tags: Rect2 = parts["tags"]
	if tags.has_area():
		assert_bool(stage.encloses(tags)).override_failure_message(str(tags)).is_true()
	# A payday's page reads PAYDAY on its band in place of DAY and the sign (v1.22).
	var word: Rect2 = parts["payday"] if (parts["payday"] as Rect2).has_area() else parts["day"]
	var inside: Array[Rect2] = [parts["number"], word]
	for sign_rect: Rect2 in parts["signs"]:
		inside.append(sign_rect)
	for index: int in range(inside.size()):
		assert_bool(pad.encloses(inside[index])).override_failure_message(str(index)).is_true()
		for other: int in range(index + 1, inside.size()):
			var apart: bool = not inside[index].intersects(inside[other])
			assert_bool(apart).override_failure_message("%d, %d" % [index, other]).is_true()
	var glass: WeekGlass = screen._stage.week_glass
	if not glass.visible:
		return
	var box: Rect2 = glass.get_global_rect()
	var words: Array[Control] = [glass.week_label, glass.number_label]
	if not glass.count_label.text.is_empty():
		words.append(glass.count_label)
	var inner: Rect2 = glass.get_global_transform() * WeekGlass.INSIDE_RECT
	for index: int in range(words.size()):
		var rect: Rect2 = words[index].get_global_rect()
		assert_bool(inner.encloses(rect)).override_failure_message(words[index].name).is_true()
		for other: int in range(index + 1, words.size()):
			assert_bool(rect.intersects(words[other].get_global_rect())).is_false()
	var deck: Rect2 = screen._stage.get_global_transform() * ShiftStage.DECK_RECT
	assert_bool(deck.encloses(box)).override_failure_message(str(box)).is_true()


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


## The run's weeks at a glance (v1.02, the user's review of 2026-11-05; v1.17 on the week glass):
## on every shift of the run, at 1280x720 and 1920x1080, the glass reads WEEK, the week's number in
## the glass's glow and "/<week count>" (from the balance), and no days-left line (v1.18); the
## calendar shows one pip per day of the current week only and the day's
## number, and both keep inside the stage and apart: on the review days too, where the calendar
## reads "Review" between its two signs (v1.16), never shortened.
func test_the_glass_reads_the_week_out_of_the_run() -> void:
	for window: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		var runner: GdUnitSceneRunner = scene_runner(SCREEN)
		var screen: ShiftScreen = runner.scene()
		screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		screen.size = window
		screen._week.skip()
		await _frames(3)
		var run: RunState = screen.run
		var weeks: int = WeekSchedule.week_count(run.balance)
		assert_int(weeks).is_greater(1)
		var glass: WeekGlass = screen._stage.week_glass
		var calendar: DayCalendar = screen._stage.day_calendar
		var reviews: int = 0
		for shift_index: int in range(run.shift_count()):
			run.debug_skip_to_shift(shift_index)
			screen.debug_show_shift()
			screen._week.skip()
			await _frames(3)
			var model: WeekCardModel = WeekCardModel.of(run)
			var message: String = "shift %d at %s" % [shift_index + 1, window]
			assert_str(glass.week_label.text).is_equal(WeekGlass.WEEK_WORD)
			assert_str(glass.number_label.text).is_equal(str(model.week_number))
			assert_str(glass.count_label.text).is_equal("/%d" % weeks)
			assert_int(calendar.pips().size()).override_failure_message(message).is_equal(
				model.days.size()
			)
			assert_int(calendar.day()).is_equal(shift_index + 1)
			_assert_week_parts_fit(screen)
			var viewport: Rect2 = Rect2(Vector2.ZERO, window)
			assert_bool(viewport.encloses(glass.get_global_rect())).is_true()
			assert_bool(viewport.encloses(calendar.get_global_rect())).is_true()
			if InspectionSchedule.is_review_shift(run.balance, shift_index + 1):
				reviews += 1
				assert_bool(calendar.is_shortened()).override_failure_message(message).is_false()
				assert_str(calendar.text()).override_failure_message(message).is_equal(
					InspectionTag.REVIEW_CAPTION
				)
				assert_int(calendar.look()).is_equal(DayCalendarArt.Look.REVIEW)
				var signs: int = 0 if ReceiptGoldFlow.payday(run) else 1
				assert_int((calendar.part_rects()["signs"] as Array).size()).is_equal(signs)
		assert_int(reviews).is_greater(0)
	await _assert_every_review_day_reads_review()


## A review day reads "Review" (v1.16, the user's play-test note of 2026-11-07: no effects on the
## day's page): on every week's review shift, at 1280x720 and 1920x1080, beside a 4-box loyalty
## card, any two of the pool's inspections leave the calendar at the same fixed width, unshortened,
## its sign beside the word (a payday's page: PAYDAY on its band, no sign), with the day's pips.
func _assert_every_review_day_reads_review() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var pool: Array[InspectionDefinition] = balance.inspection_pool
	for window: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		var runner: GdUnitSceneRunner = scene_runner(SCREEN)
		var screen: ShiftScreen = runner.scene()
		screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		screen.size = window
		screen._week.skip()
		await _frames(3)
		var run: RunState = screen.run
		# The widest loyalty card: a starting upgrade's box and the register cap's, all stamped.
		run.upgrades.clear()
		for id: String in FULL_CARD:
			run.upgrades.append(load("res://data/upgrades/%s.tres" % id) as UpgradeDefinition)
		assert_int(run.upgrades.size()).is_equal(run.balance.machine.register_cap + 1)
		var widths: Array[float] = []
		var calendar: DayCalendar = screen._stage.day_calendar
		for shift_index: int in range(run.shift_count()):
			if not InspectionSchedule.is_review_shift(run.balance, shift_index + 1):
				continue
			for first: int in range(pool.size()):
				for second: int in range(first + 1, pool.size()):
					run.debug_skip_to_shift(shift_index)
					run.inspections = [pool[first], pool[second]]
					screen._on_shift_started()
					screen._week.drop()
					await _frames(2)
					var message: String = (
						"shift %d, %s at %s" % [shift_index + 1, calendar.text(), window]
					)
					assert_str(calendar.text()).override_failure_message(message).is_equal(
						InspectionTag.REVIEW_CAPTION
					)
					(
						assert_bool(calendar.is_shortened())
						. override_failure_message(message)
						. is_false()
					)
					var parts: Dictionary = calendar.part_rects()
					# A payday's page wears the PAYDAY band in place of the sign (v1.22).
					var signs: Array = parts["signs"]
					assert_int(signs.size()).is_equal(0 if ReceiptGoldFlow.payday(run) else 1)
					assert_int(calendar.pips().size()).is_equal(4)
					widths.append(calendar.size.x)
					_assert_week_parts_fit(screen)
		assert_float(float(widths.max()) - float(widths.min())).is_less_equal(0.01)
