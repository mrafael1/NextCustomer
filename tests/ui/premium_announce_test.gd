extends GdUnitTestSuite
## The PREMIUM NEXT announce on the real shift screen (v0.50, PremiumAnnounce, mock-up
## premium_machine_v1.html scene 1), on shift 3 of the real schedule: inspected (its pass earns
## the bonus ticket) and the shift before the first PREMIUM visit. The gold receipt prints inside
## the hung monitor's screen over its sunburst, never over the belt; the bonus notice waits until
## the receipt has flown up, so the brief's PASS IT plate never pulses hidden under it; the hung
## tag sits on the monitor's top bezel, clear of the top bar and of every brief text. Layout
## asserts on-screen geometry (memory: UI tests check layout).

const SCREEN := "res://ui/shift_screen.tscn"
const SPOT_CHECK := "res://data/inspections/spot_check.tres"
const STEP := 0.1

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
	screen.run.balance = balance
	screen._debug.skip_to_shift(3)
	if screen.run.inspections.is_empty():
		screen._debug.set_inspection("spot_check")
	var run: RunState = screen.run
	assert_int(run.shift_index).is_equal(2)
	assert_bool(run.machine.premium_if_passed(run)).is_true()
	assert_bool(run.machine.bonus_if_passed(run)).is_true()
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


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
