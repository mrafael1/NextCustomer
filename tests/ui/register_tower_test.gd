extends GdUnitTestSuite
## The register's left column on the real shift screen (left column v2, the user's pick of
## 2026-11-09: mock-up docs/art/mockups/left_column_v2.html), in the stage's window and larger
## ones (1920x1080 first): the rubber column from the stage's top down to the counter, inside the
## window, its whole width the receipt's (no gauge in its margin any more); the overhead printer
## at its top (OverheadPrinter) with the receipt hanging from its slot, TODAY'S TARGET opening the
## paper; the service bell and the desk calendar standing on the register's top, the bell left of
## the calendar, both inside the column; and the quota gauge lying in the top bar (GaugePanel)
## right of the column and left of LOYALTY (no chip since the play test of 2026-11-09), its lap
## lamp at its left, its ×N readout growing with the laps clear of the bar's other parts, a Double
## checkout's pips at its right end (the glass giving them room). At CHECKOUT the gauge slides up
## out of the bar and comes back down. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"

var _folder: String = ""
var _window_size: Vector2i = Vector2i.ZERO


func before_test() -> void:
	_window_size = get_tree().root.size
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_the_column_in_the_stages_window() -> void:
	await _assert_the_column_in(Vector2i(1280, 720))


func test_the_column_in_a_larger_window() -> void:
	await _assert_the_column_in(Vector2i(1600, 1000))


## The game's first target (the user's feedback of 2026-11-03).
func test_the_column_at_1920x1080() -> void:
	await _assert_the_column_in(Vector2i(1920, 1080))


## A count at twice the quota laps the gauge: its lamp reads "×2" inside the gauge's chip, in the
## top bar, right of the column.
func test_a_lap_keeps_its_badge_in_the_chip() -> void:
	get_tree().root.size = Vector2i(1920, 1080)
	var screen: ShiftScreen = await _screen()
	screen.profile.set_reduced_motion(true)
	var meter: QuotaMeter = screen._stage.quota_meter
	var quota: int = screen.run.quota()
	meter._show(quota * 2, quota, true, true)
	await _frames(3)
	assert_int(meter.shown_lap()).is_equal(3)
	assert_str(meter.badge_text()).is_equal("×2")
	assert_int(meter.get_child_count()).is_equal(0)
	var chip: Rect2 = screen._stage.gauge_panel.get_global_rect()
	var badge: Rect2 = meter.get_global_transform() * meter.badge_rect()
	assert_bool(chip.encloses(badge)).override_failure_message(str(badge)).is_true()
	assert_float(badge.end.x).is_less_equal(meter.get_global_rect().position.x)
	assert_float(chip.position.x).is_greater_equal(screen._stage.tower.get_global_rect().end.x)


## The gauge's ×N readout (LapReadout, the user's play test of 2026-11-09) at 1920x1080.
func test_the_lap_readout_at_1920x1080() -> void:
	await _assert_the_readout_in(Vector2i(1920, 1080))


## The same in the stage's own window, 1280x720.
func test_the_lap_readout_at_1280x720() -> void:
	await _assert_the_readout_in(Vector2i(1280, 720))


## The tower's faces, the printer, the bell and the gauge take no click: the belt and the hand
## keep theirs.
func test_the_column_takes_no_clicks() -> void:
	var screen: ShiftScreen = await _screen()
	var stage: ShiftStage = screen._stage
	var parts: Array[Node] = stage.tower.find_children("*", "Control", true, false)
	parts.append_array([stage.tower, stage.printer, stage.bell, stage.receipt_slot])
	parts.append(stage.gauge_panel)
	parts.append_array(stage.gauge_panel.find_children("*", "Control", true, false))
	for part: Node in parts:
		(
			assert_int((part as Control).mouse_filter)
			. override_failure_message(str(part.get_path()))
			. is_equal(Control.MOUSE_FILTER_IGNORE)
		)


## CHECKOUT slides the gauge up out of the top bar (its room clips it: nothing of it shows), and
## the next day's stub brings it back to its rest; at once with `animate` false; animated, in
## whole art px.
func test_the_gauge_slides_up_and_back() -> void:
	get_tree().root.size = Vector2i(1920, 1080)
	var screen: ShiftScreen = await _screen()
	var panel: GaugePanel = screen._stage.gauge_panel
	var rest: Rect2 = panel.get_global_rect()
	var rest_y: float = panel.position.y
	var room: Control = panel.get_parent() as Control
	assert_bool(room.clip_contents).is_true()
	panel.hide_gauge(false)
	assert_bool(panel.is_hidden()).is_true()
	assert_float(panel.get_global_rect().end.y).is_less(room.get_global_rect().position.y)
	panel.show_gauge(false)
	assert_bool(panel.is_hidden()).is_false()
	assert_that(panel.get_global_rect()).is_equal(rest)
	panel.hide_gauge(true)
	var cell: float = ArtStyle.ART_SCALE
	for _step: int in range(4):
		await get_tree().process_frame
		var moved: float = rest_y - panel.position.y
		assert_float(fposmod(moved, cell)).is_equal_approx(0.0, 0.001)
	await get_tree().create_timer(GaugePanel.SLIDE_SECONDS + 0.1).timeout
	assert_float(panel.up_amount()).is_equal(1.0)
	panel.show_gauge(false)


func _assert_the_column_in(window: Vector2i) -> void:
	get_tree().root.size = window
	var screen: ShiftScreen = await _screen()
	screen.profile.set_reduced_motion(true)
	var stage_node: ShiftStage = screen._stage
	var tower: RegisterTower = stage_node.tower
	var quota: int = screen.run.quota()
	stage_node.quota_meter.show_projected(quota, quota)
	await _frames(3)
	var visible_rect: Rect2 = get_tree().root.get_visible_rect()
	var stage: Rect2 = stage_node.get_global_rect()
	var column: Rect2 = tower.get_global_rect()
	assert_that(column).is_equal(_on_stage(screen, ShiftStage.TOWER_RECT))
	assert_float(column.position.y).is_equal(stage.position.y)
	assert_float(column.position.x).is_equal(stage.position.x)
	assert_bool(visible_rect.encloses(column)).override_failure_message(str(column)).is_true()
	assert_float(column.end.y).is_greater_equal(screen._register.get_global_rect().position.y)
	# The printer at the column's top, over the receipt; the receipt hangs from its slot, in the
	# well, the column's whole width less its rims.
	var printer: Rect2 = stage_node.printer.get_global_rect()
	assert_that(printer).is_equal(_on_stage(screen, ShiftStage.PRINTER_RECT))
	assert_bool(column.encloses(printer)).is_true()
	var receipt: Rect2 = screen._receipt.get_global_rect()
	var well: Rect2 = _on_stage(screen, ShiftStage.RECEIPT_WELL_RECT)
	assert_bool(column.encloses(well)).is_true()
	assert_float(receipt.position.x).is_equal(stage.position.x + ShiftStage.RECEIPT_X)
	assert_float(receipt.size.x).is_equal(ShiftStage.RECEIPT_WIDTH)
	assert_float(receipt.end.x).is_less_equal(well.end.x)
	assert_float(receipt.position.y).is_equal(stage.position.y + ShiftStage.RECEIPT_TOP)
	assert_float(receipt.position.y).is_less_equal(printer.end.y)
	assert_float(receipt.end.y).is_less_equal(stage.position.y + ShiftStage.RECEIPT_BOTTOM)
	assert_bool(_drawn_over(stage_node.printer, screen._receipt)).is_true()
	# The bell and the desk calendar stand on the register's top, inside the column, the bell left
	# of the calendar, under the planning stub, within the column's width.
	var top: float = stage.position.y + ShiftStage.REGISTER_TOP
	var bell: Rect2 = stage_node.bell.get_global_rect()
	var pad: Rect2 = stage_node.day_calendar.part_rects()["pad"]
	assert_that(bell).is_equal(_on_stage(screen, ShiftStage.BELL_RECT))
	assert_float(bell.end.y).is_equal(top)
	assert_float(pad.end.y).is_equal(top)
	# Their ink foot rows lie on the key deck's ink outline, over its steel lip.
	assert_float(bell.end.y).is_equal(_on_stage(screen, ShiftStage.DECK_RECT).position.y + 2.0)
	assert_float(bell.end.x).is_less_equal(pad.position.x)
	assert_float(pad.end.x).is_equal(stage.position.x + ShiftStage.DESK_CALENDAR_RECT.end.x)
	for part: Rect2 in [bell, pad]:
		assert_float(part.position.x).is_greater_equal(column.position.x)
		assert_float(part.end.x).is_less_equal(column.end.x)
		assert_bool(part.intersects(receipt)).override_failure_message(str(receipt)).is_false()
	# The gauge in the top bar: right of the column, left of LOYALTY, its glass and lamp in its
	# chip; no number in it; at the quota, the lamp's check.
	var bar: TopBar = stage_node.top_bar
	var panel: GaugePanel = stage_node.gauge_panel
	var chip: Rect2 = panel.get_global_rect()
	var meter: QuotaMeter = stage_node.quota_meter
	var glass: Rect2 = meter.get_global_rect()
	assert_bool(bar.is_ancestor_of(panel)).is_true()
	assert_that(chip).is_equal(_on_stage(screen, ShiftStage.GAUGE_PANEL_RECT))
	assert_float(chip.position.x).is_greater_equal(column.end.x)
	assert_float(chip.end.x).is_less_equal(bar.loyalty_card.get_global_rect().position.x)
	assert_bool(chip.encloses(glass)).override_failure_message(str(glass)).is_true()
	assert_float(glass.size.x).is_greater(glass.size.y * 10.0)
	assert_array(meter.find_children("*", "Label", true, false)).is_empty()
	assert_str(meter.badge_text()).is_equal(LapLamp.CHECK_TEXT)
	var badge: Rect2 = meter.get_global_transform() * meter.badge_rect()
	assert_bool(chip.encloses(badge)).override_failure_message(str(badge)).is_true()
	assert_float(badge.end.x).is_less_equal(glass.position.x)
	# The target's red line at the glass's right end.
	var mark: Vector2 = meter.quota_mark()
	assert_float(mark.x).is_equal_approx(glass.end.x, ArtStyle.ART_SCALE * 3.0)
	# A Double checkout's pips at the chip's right end; the glass gives them room.
	var full: float = glass.size.x
	stage_node.row_pips.show_rows(1, 2)
	await _frames(2)
	var pips: Rect2 = stage_node.row_pips.get_global_rect()
	glass = meter.get_global_rect()
	assert_bool(stage_node.row_pips.visible).is_true()
	assert_bool(chip.encloses(pips)).override_failure_message(str(pips)).is_true()
	assert_float(glass.size.x).is_less(full)
	assert_float(pips.position.x).is_greater_equal(glass.end.x)
	stage_node.row_pips.show_rows(0, 1)
	# TODAY'S TARGET opens the paper with the quota.
	var target: ReceiptTarget = screen._receipt.target
	assert_bool(target.visible).is_true()
	assert_int(target.shown_quota()).is_equal(quota)
	assert_str(target.amount.text).is_equal("%d€" % quota)
	var block: Rect2 = target.get_global_rect()
	assert_bool(receipt.encloses(block)).override_failure_message(str(block)).is_true()
	# The top bar starts right of the column; every chip inside the window.
	assert_float(bar.get_global_rect().position.x).is_greater_equal(column.end.x)
	for part: Control in [panel, bar.loyalty_card, bar.deck_button, bar.menu_button]:
		if not part.is_visible_in_tree():
			continue
		var rect: Rect2 = part.get_global_rect()
		assert_float(rect.position.x).is_greater_equal(column.end.x)
		assert_bool(visible_rect.encloses(rect)).override_failure_message(str(rect)).is_true()


## The ×N readout in `window`: hidden short of ×2, then "×N" in chunky pixel digits at cell 2 for
## ×2 and cell 4 from ×3 (cell 2 again once it would not fit its room); the lamp's own text
## unchanged; at every cell (its box holds the pop's lift and the shadow) inside the gauge, its
## room and the bar's row, right of the glass's bezel and left of LOYALTY, clear of the lamp, the
## other parts of the bar and a Double checkout's pips, its digits within the glass's bezel.
func _assert_the_readout_in(window: Vector2i) -> void:
	get_tree().root.size = window
	var screen: ShiftScreen = await _screen()
	screen.profile.set_reduced_motion(true)
	var stage: ShiftStage = screen._stage
	var panel: GaugePanel = stage.gauge_panel
	var meter: QuotaMeter = stage.quota_meter
	var readout: LapReadout = panel.readout
	var bar: TopBar = stage.top_bar
	var quota: int = screen.run.quota()
	meter.show_projected(quota, quota)
	await _frames(2)
	assert_bool(readout.visible).is_false()
	var room: Rect2 = (panel.get_parent() as Control).get_global_rect()
	var row_bottom: float = stage.get_global_rect().position.y + ShiftStage.TOP_BAR_BOTTOM
	var others: Array[Control] = [bar.loyalty_card, bar.deck_button, bar.menu_button]
	for pips: bool in [false, true]:
		if pips:
			stage.row_pips.show_rows(1, 2)
		for laps: int in [2, 3, 4, 5, 6, 7, 12, 99]:
			meter.show_projected(quota * laps, quota)
			await _frames(2)
			var message: String = "%s ×%d pips %s" % [window, laps, pips]
			assert_bool(readout.visible).override_failure_message(message).is_true()
			assert_str(readout.text()).is_equal("×%d" % laps)
			assert_str(meter.badge_text()).is_equal(LapLamp.text_for(laps))
			# Three even steps (×2, ×3, ×5), and two digits keep the biggest (2026-11-10).
			var step: int = 0 if laps < 3 else (1 if laps < 5 else 2)
			var expected: int = LapReadout.CELLS[step]
			assert_int(readout.cell()).override_failure_message(message).is_equal(expected)
			var rect: Rect2 = readout.get_global_rect()
			var ring: Rect2 = panel.get_global_transform() * panel.bezel_rect()
			var digits: Rect2 = readout.words.get_global_rect()
			var tolerance: float = 1.0
			assert_float(digits.position.y).override_failure_message(message).is_greater_equal(
				ring.position.y - tolerance
			)
			assert_float(digits.end.y).override_failure_message(message).is_less_equal(
				ring.end.y + tolerance
			)
			for inside: Rect2 in [panel.get_global_rect(), room]:
				assert_bool(inside.encloses(rect)).override_failure_message(message).is_true()
			assert_float(rect.end.y).is_less_equal(row_bottom)
			var bezel: Rect2 = panel.get_global_transform() * panel.bezel_rect()
			assert_float(rect.position.x).override_failure_message(message).is_greater(bezel.end.x)
			var lamp: Rect2 = meter.get_global_transform() * meter.badge_rect()
			assert_bool(rect.intersects(lamp)).is_false()
			for other: Control in others:
				var part: Rect2 = other.get_global_rect()
				assert_bool(rect.intersects(part)).override_failure_message(message).is_false()
			assert_float(rect.end.x).is_less(bar.loyalty_card.get_global_rect().position.x)
			if pips:
				var pip_rect: Rect2 = stage.row_pips.get_global_rect()
				assert_bool(rect.intersects(pip_rect)).override_failure_message(message).is_false()
	stage.row_pips.show_rows(0, 1)


## Whether `over` draws after `under` (it, or one of its ancestors, a later sibling of one of
## `under`'s).
static func _drawn_over(over: Node, under: Node) -> bool:
	var common: Node = over
	while common != null and not common.is_ancestor_of(under):
		common = common.get_parent()
	if common == null:
		return false
	var a: Node = over
	while a.get_parent() != common:
		a = a.get_parent()
	var b: Node = under
	while b.get_parent() != common:
		b = b.get_parent()
	return a.get_index() > b.get_index()


## The screen on shift 1, laid out.
func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()  # The time card (v0.70) stays out of the way.
	await _frames(3)
	return screen


## `rect` (stage coordinates) on screen.
static func _on_stage(screen: ShiftScreen, rect: Rect2) -> Rect2:
	return Rect2(screen._stage.get_global_rect().position + rect.position, rect.size)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
