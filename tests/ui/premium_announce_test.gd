extends GdUnitTestSuite
## The PREMIUM NEXT announce on the real shift screen (v0.50, PremiumAnnounce, mock-up
## premium_machine_v1.html scene 1), on shift 4 of the real schedule, the first Manager's review:
## with a machine copy whose inspected passes earn a bonus ticket (before v0.68's Payday), and with
## the live machine, where it is a payday (two PREMIUM tickets, one PAYDAY announce, no bonus
## notice or pill). The gold receipt prints inside
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
	# The tag's text fits it.
	var bold: Font = ArtStyle.bold_font(PremiumAnnounce.BOLD_WEIGHT)
	var width: float = MachineArt.text_width(
		announce.tag_text(), bold, PremiumAnnounce.TAG_FONT_SIZE
	)
	assert_float(width + 34.0).is_less_equal(PremiumAnnounce.TAG_SIZE.x)
	# The receipt's boost lines (v0.61, #108: PREMIUM is the rarity boost) fit inside its brass
	# rules, the first with its RARE diamond (5 cells of 2 px) on each side.
	var inner: float = PremiumAnnounce.RECEIPT_SIZE.x - 48.0
	for index: int in range(PremiumAnnounce.BOOST_TEXTS.size()):
		var line: String = PremiumAnnounce.BOOST_TEXTS[index]
		var reach: float = MachineArt.text_width(line, bold, PremiumAnnounce.BOOST_SIZES[index])
		if index == 0:
			reach += 2.0 * (PremiumAnnounce.DIAMOND_GAP + 5.0)
		assert_float(reach).override_failure_message(line).is_less_equal(inner)


## The live machine: shift 4's pass is a payday. The announce prints PAYDAY's texts and hangs the
## "PAYDAY NEXT" tag on the monitor's bezel, inside the view and clear of the brief; the bonus
## notice never pulses and the inspection chip shows no bonus pill; every receipt line fits.
func test_a_payday_announce_replaces_the_bonus_notice() -> void:
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
	assert_str(announce.tag_text()).is_equal(Payday.TAG)
	assert_array(Array(announce.receipt_texts())).contains([Payday.ANNOUNCE_TITLE])
	assert_int(screen._inspection_tag.bonus_state()).is_equal(InspectionTag.Bonus.NONE)
	var elapsed: float = 0.0
	while elapsed < 6.0:
		announce._process(STEP)
		flow._process(STEP)
		elapsed += STEP
		assert_bool(flow.notice.is_playing()).is_false()
	assert_bool(announce.tag_hangs()).is_true()
	var tag: Rect2 = announce.tag_rect()
	var screen_rect: Rect2 = announce.monitor_screen()
	assert_bool(screen.get_global_rect().encloses(tag)).is_true()
	assert_float(tag.end.y).is_less_equal(screen_rect.position.y + PremiumAnnounce.TAG_INTO)
	assert_float(tag.end.x).is_less_equal(screen_rect.end.x)
	var bold: Font = ArtStyle.bold_font(PremiumAnnounce.BOLD_WEIGHT)
	var tag_width: float = MachineArt.text_width(
		announce.tag_text(), bold, PremiumAnnounce.TAG_FONT_SIZE
	)
	assert_float(tag_width + 34.0).is_less_equal(PremiumAnnounce.TAG_SIZE.x)
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
	assert_int(screen._inspection_tag.bonus_state()).is_equal(InspectionTag.Bonus.NONE)
	assert_bool(screen._inspection_tag.pill().visible).is_false()


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
