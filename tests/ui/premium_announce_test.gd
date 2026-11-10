extends GdUnitTestSuite
## The PREMIUM NEXT announce on the real shift screen (v0.50, PremiumAnnounce, mock-up
## premium_machine_v1.html scene 1), on shift 4 of the real schedule, the first Manager's review:
## with a machine copy whose inspected passes earn a bonus ticket (before v0.68's Payday), and with
## the live machine, where it is a payday (two PREMIUM tickets, one PAYDAY announce that leaves no
## tag, no bonus notice or pill). The gold receipt prints inside
## the hung monitor's screen over its sunburst, never over the belt; the bonus notice waits until
## the receipt has flown up, so the brief's PASS IT plate never pulses hidden under it; the hung
## tag sits on the monitor's top bezel, clear of the top bar and of every brief text. Layout
## asserts on-screen geometry (memory: UI tests check layout).

const SCREEN := "res://ui/shift_screen.tscn"
const SPOT_CHECK := "res://data/inspections/spot_check.tres"
const STEP := 0.1
const MILK := "res://data/cards/milk.tres"
const Rush := preload("res://tests/ui/count_up_rush.gd")

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_premium_announce_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_the_announce_prints_in_the_monitor_before_the_bonus_notice() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var balance: BalanceDefinition = screen.run.balance.duplicate()
	var pool: Array[InspectionDefinition] = [load(SPOT_CHECK)]
	balance.inspection_pool = pool
	# A bonus ticket after an inspected pass, not a payday (the machine before v0.68).
	balance.machine = balance.machine.duplicate()
	balance.machine.bonus_after_inspection = true
	balance.machine.bonus_extra_shifts = PackedInt32Array()
	screen.run.balance = balance
	screen.run.machine.machine = balance.machine
	# Shift 4, the first Manager's review, is the first one a PREMIUM visit follows (v0.65).
	screen._debug.skip_to_shift(4)
	if screen.run.inspections.is_empty():
		screen._debug.set_inspection("spot_check")
	var run: RunState = screen.run
	assert_int(run.shift_index).is_equal(3)
	assert_bool(run.machine.premium_if_passed(run)).is_true()
	assert_bool(run.machine.bonus_if_passed(run)).is_true()
	assert_bool(Payday.if_passed(run)).is_false()
	await _frames(3)
	var flow: MachineFlow = screen._machine
	var announce: PremiumAnnounce = flow.announce
	var notice: BonusNotice = flow.notice
	assert_bool(announce.is_shown()).is_true()
	assert_bool(announce.tag_hangs()).is_false()
	# The receipt prints inside the monitor's screen, over nothing below the monitor.
	var screen_rect: Rect2 = announce.monitor_screen()
	var receipt: Rect2 = announce.receipt_rect()
	(
		assert_bool(screen_rect.encloses(receipt))
		. override_failure_message("%s in %s" % [receipt, screen_rect])
		. is_true()
	)
	var stage: Rect2 = screen._stage.get_global_rect()
	assert_float(receipt.end.y).is_less_equal(stage.position.y + ShiftStage.MONITOR_RECT.end.y)
	# The notice waits for the print: its plate never pulses while the receipt covers the brief.
	var played_at: float = -1.0
	var elapsed: float = 0.0
	while elapsed < 6.0:
		announce._process(STEP)
		flow._process(STEP)
		elapsed += STEP
		if announce.burst_shown():
			assert_bool(announce.tag_hangs()).is_false()
		if notice.is_playing() and played_at < 0.0:
			played_at = elapsed
			# Within a step: the flow and the announce tick in either order each frame.
			assert_float(announce.print_left()).is_less_equal(STEP)
			assert_bool(announce.tag_hangs()).is_true()
	assert_float(played_at).override_failure_message("the notice never played").is_greater(0.0)
	assert_float(played_at).is_greater_equal(
		PremiumAnnounce.FLY_TO + PremiumAnnounce.RING_LENGTH - 2.0 * STEP
	)
	# The hung tag: on the monitor's top bezel, under the top bar, inside the view, clear of every
	# brief text on the monitor.
	var tag: Rect2 = announce.tag_rect()
	var view: Rect2 = screen.get_global_rect()
	assert_bool(view.encloses(tag)).is_true()
	assert_float(tag.position.y).is_greater_equal(stage.position.y + ShiftStage.TOP_BAR_BOTTOM)
	assert_float(tag.end.y).is_less_equal(screen_rect.position.y + PremiumAnnounce.TAG_INTO)
	assert_float(tag.end.x).is_less_equal(screen_rect.end.x)
	for label: Label in screen._monitor.find_children("*", "Label", true, false):
		if label.is_visible_in_tree() and not label.text.strip_edges().is_empty():
			var box: Rect2 = label.get_global_rect()
			(
				assert_bool(box.intersects(tag))
				. override_failure_message("'%s' %s under the tag %s" % [label.text, box, tag])
				. is_false()
			)
	_assert_string_clear(screen, announce)
	# The tag's text fits it.
	var bold: Font = ArtStyle.bold_font(PremiumAnnounce.BOLD_WEIGHT)
	var width: float = MachineArt.text_width(
		PremiumAnnounce.TAG_TEXT, PremiumAnnounce.tag_font(), PremiumAnnounce.TAG_FONT_SIZE
	)
	assert_float(width + PremiumAnnounce.TAG_TEXT_X).is_less_equal(announce.tag_rect().size.x)
	# PREMIUM NEXT keeps its tag through the count (CHECKOUT's key held), whole.
	assert_bool(announce.payday).is_false()
	assert_float(announce.self_modulate.a).is_equal(1.0)
	screen._on_checkout_pressed()
	await _frames(1)
	assert_bool(screen._counting).is_true()
	assert_bool(announce.tag_hangs()).is_true()
	await Rush.finish(screen)
	# The receipt's boost lines (v0.61, #108: PREMIUM is the rarity boost) fit inside its brass
	# rules, the first with its RARE diamond (5 cells of 2 px) on each side.
	var inner: float = PremiumAnnounce.RECEIPT_SIZE.x - 48.0
	for index: int in range(PremiumAnnounce.BOOST_TEXTS.size()):
		var line: String = PremiumAnnounce.BOOST_TEXTS[index]
		var reach: float = MachineArt.text_width(line, bold, PremiumAnnounce.BOOST_SIZES[index])
		if index == 0:
			reach += 2.0 * (PremiumAnnounce.DIAMOND_GAP + 5.0)
		assert_float(reach).override_failure_message(line).is_less_equal(inner)


## The live machine: shift 4's pass is a payday. The announce prints PAYDAY's texts in the monitor
## and leaves no tag (the user's call of 2026-11-10: "you can remove the golden payday on top of
## checkout"): its receipt flies to the calendar's PAYDAY band, fading out, never over the
## CHECKOUT key, and the announce is then over, in planning and through the count; the bonus
## notice never pulses and the inspection chip shows no bonus pill; every receipt line fits.
func test_a_payday_announce_leaves_no_tag() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._debug.skip_to_shift(4)
	var run: RunState = screen.run
	assert_bool(Payday.if_passed(run)).is_true()
	await _frames(3)
	var flow: MachineFlow = screen._machine
	var announce: PremiumAnnounce = flow.announce
	assert_bool(announce.is_shown()).is_true()
	assert_bool(announce.payday).is_true()
	assert_array(Array(announce.receipt_texts())).contains([Payday.ANNOUNCE_TITLE])
	assert_int(screen._calendar.bonus_state()).is_equal(InspectionTag.Bonus.NONE)
	var key: RegisterKey = screen._stage.checkout_button
	var key_rect: Rect2 = key.get_global_rect()
	var band: Rect2 = screen._calendar.part_rects()["payday_band"]
	assert_bool(band.has_area()).is_true()
	var faded: bool = false
	var over_at: float = -1.0
	var last: Rect2 = announce.receipt_rect()
	var elapsed: float = 0.0
	while elapsed < 6.0:
		announce._process(STEP)
		flow._process(STEP)
		elapsed += STEP
		assert_bool(flow.notice.is_playing()).is_false()
		assert_bool(announce.tag_hangs()).is_false()
		if not announce.is_shown():
			if over_at < 0.0:
				over_at = elapsed
			assert_float(announce.print_left()).is_equal(0.0)
			assert_bool(announce.burst_shown()).is_false()
			continue
		# The receipt, wherever it is on its way, never covers the CHECKOUT key.
		last = announce.flying_rect()
		(
			assert_bool(last.intersects(key_rect))
			. override_failure_message("the receipt %s over the key %s" % [last, key_rect])
			. is_false()
		)
		faded = faded or announce.self_modulate.a < 1.0
	# It ended with the flight (no landing ring to wait for), shrunk, faded, toward the band.
	assert_float(over_at).is_equal_approx(PremiumAnnounce.FLY_TO, 3.0 * STEP)
	assert_bool(faded).is_true()
	assert_float(last.size.x).is_less(announce.receipt_rect().size.x)
	var start: Vector2 = announce.receipt_rect().get_center()
	assert_float(last.get_center().distance_to(band.get_center())).is_less(
		start.distance_to(band.get_center())
	)
	assert_that(announce.payday_target()).is_equal(band.get_center())
	# Planning after it: nothing of the announce is up, the key is its own brass face.
	await _frames(2)
	assert_bool(announce.is_shown()).is_false()
	assert_bool(announce.burst_shown()).is_false()
	assert_that(key.get_global_rect()).is_equal(key_rect)
	assert_int(key.key_kind()).is_equal(RegisterKey.Kind.PAYDAY)
	# The count: still nothing (the announce is `active` there, as PREMIUM NEXT's tag needs).
	screen._on_checkout_pressed()
	await _frames(1)
	assert_bool(screen._counting).is_true()
	assert_bool(bool(announce.active.call())).is_true()
	assert_bool(announce.is_shown()).is_false()
	assert_bool(announce.tag_hangs()).is_false()
	await Rush.finish(screen)
	var bold: Font = ArtStyle.bold_font(PremiumAnnounce.BOLD_WEIGHT)
	var texts: PackedStringArray = announce.receipt_texts()
	var inner: float = PremiumAnnounce.RECEIPT_SIZE.x - 48.0
	var title: float = MachineArt.text_width(texts[1], bold, PremiumAnnounce.TITLE_SIZE)
	assert_float(title + 2.0 * 23.0).is_less_equal(inner)
	for index: int in range(2):
		var line: String = texts[2 + index]
		var reach: float = MachineArt.text_width(line, bold, PremiumAnnounce.BOOST_SIZES[index])
		if index == 0:
			reach += 2.0 * (PremiumAnnounce.DIAMOND_GAP + 5.0)
		assert_float(reach).override_failure_message(line).is_less_equal(inner)
	var mono: float = MachineArt.text_width(texts[0], ArtStyle.MONO_FONT, PremiumAnnounce.MONO_SIZE)
	assert_float(mono).is_less_equal(inner)


## A payday's announce under reduced motion: its receipt shows still (no sunburst, no flight, no
## fade) and goes at once when the flight would start, leaving no tag. A resumed payday (no
## print) shows nothing at all.
func test_a_payday_announce_ends_at_once_under_reduced_motion() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._debug.skip_to_shift(4)
	await _frames(3)
	var announce: PremiumAnnounce = screen._machine.announce
	var reduced: Array[bool] = [true]
	announce.reduced_motion = func() -> bool: return reduced[0]
	announce.show_tag(true, true)
	assert_bool(announce.is_shown()).is_true()
	assert_float(announce.print_left()).is_equal(PremiumAnnounce.FLY_FROM)
	assert_that(announce.flying_rect()).is_equal(announce.receipt_rect())
	var elapsed: float = 0.0
	while elapsed < PremiumAnnounce.FLY_FROM - 2.0 * STEP:
		announce._process(STEP)
		elapsed += STEP
		assert_bool(announce.is_shown()).is_true()
		assert_bool(announce.burst_shown()).is_false()
		assert_float(announce.self_modulate.a).is_equal(1.0)
	for _step: int in range(4):
		announce._process(STEP)
	assert_bool(announce.is_shown()).is_false()
	assert_bool(announce.tag_hangs()).is_false()
	assert_float(announce.print_left()).is_equal(0.0)
	# A resume: nothing, with or without reduced motion.
	for motion: bool in [true, false]:
		reduced[0] = motion
		announce.show_tag(false, true)
		assert_bool(announce.is_shown()).is_false()
		assert_float(announce.print_left()).is_equal(0.0)
		announce._process(STEP)
		assert_bool(announce.burst_shown()).is_false()
	# PREMIUM NEXT under reduced motion, and resumed: its tag at once.
	reduced[0] = true
	announce.show_tag(true, false)
	assert_bool(announce.tag_hangs()).is_true()
	reduced[0] = false
	announce.show_tag(false, false)
	assert_bool(announce.tag_hangs()).is_true()


## The live machine at a payday's visit (shift 4 passed): the pass earns the BONUS visit, but the
## inspection chip shows no "+1 BONUS TICKET" pill (one banner, v0.68).
func test_a_payday_visit_shows_no_bonus_pill() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	# Low quotas on a copy (the loaded balance is shared), so a few Milks pass the review.
	var balance: BalanceDefinition = screen.run.balance.duplicate()
	var quotas: PackedInt32Array = PackedInt32Array()
	quotas.resize(balance.quotas.size())
	quotas.fill(5)
	balance.quotas = quotas
	screen.run.balance = balance
	screen._debug.skip_to_shift(4)
	await _frames(2)
	var run: RunState = screen.run
	for _card: int in range(8):
		if run.preview().total >= run.quota():
			break
		run.place(run.debug_add_to_hand(load(MILK)), run.row.size())
	screen._refresh()
	assert_int(run.preview().total).is_greater_equal(run.quota())
	await Rush.checkout(screen)
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	assert_bool(screen._counting).is_false()
	assert_bool(run.machine.bonus_earned(run)).is_true()
	assert_bool(run.machine.is_payday(run)).is_true()
	assert_int(screen._calendar.bonus_state()).is_equal(InspectionTag.Bonus.NONE)
	assert_bool(screen._calendar.tags.pill().visible).is_false()


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


## The hung tag's string drops straight down from the top bar's foot to the tag's eyelet, never
## across the receipt (at its full height, ShiftStage.RECEIPT_TOP) or the register tower holding
## it, nor the receipt as it stands now.
func _assert_string_clear(screen: ShiftScreen, announce: PremiumAnnounce) -> void:
	var ends: PackedVector2Array = announce.string_ends()
	var eyelet: Vector2 = announce.tag_rect().position + Vector2(9, 9)
	assert_that(ends[1]).is_equal(eyelet)
	assert_float(ends[0].x).is_equal(ends[1].x)
	var foot: float = screen._stage.top_bar.get_global_rect().end.y
	assert_float(ends[0].y).is_equal_approx(minf(foot, eyelet.y), 0.5)
	var cord: Rect2 = Rect2(ends[0], Vector2.ZERO).expand(ends[1]).grow(2.0)
	var stage: Vector2 = screen._stage.get_global_rect().position
	var receipt: Rect2 = Rect2(
		stage + Vector2(ShiftStage.RECEIPT_X, ShiftStage.RECEIPT_TOP),
		Vector2(ShiftStage.RECEIPT_WIDTH, ShiftStage.RECEIPT_BOTTOM - ShiftStage.RECEIPT_TOP)
	)
	var tower: Rect2 = Rect2(stage + ShiftStage.TOWER_RECT.position, ShiftStage.TOWER_RECT.size)
	for area: Rect2 in [receipt, tower, screen._receipt.get_global_rect()]:
		(
			assert_bool(cord.intersects(area))
			. override_failure_message("the string %s crosses %s" % [cord, area])
			. is_false()
		)


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
