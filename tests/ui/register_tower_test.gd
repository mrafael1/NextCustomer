extends GdUnitTestSuite
## The register's tower on the real shift screen (the shift scene polish, mock-up
## docs/art/mockups/shift_scene_polish_v2.html section 2, A2, and v4's A1; RegisterTower), in the
## stage's window and larger ones (1920x1080 first; more of the store shows under the expand
## stretch): the rubber column from the stage's top down to the counter, inside the window; in its
## left margin the gauge's steel housing (GaugeHousing) holding the quota tube (no number in it)
## left of the receipt and clear of it and of CHECKOUT, never a flag on it, its lap lamp over the
## housing inside the column and clear of the receipt, the brass plate under the housing with a
## Double checkout's pips on it, clear of the receipt and of the printer; the receipt in its well,
## opening with TODAY'S TARGET (the quota inside the paper); and the top bar right of the column,
## every chip clear of it. The real saves and logs are never touched.

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


func test_the_tower_in_the_stages_window() -> void:
	await _assert_the_tower_in(Vector2i(1280, 720))


func test_the_tower_in_a_larger_window() -> void:
	await _assert_the_tower_in(Vector2i(1600, 1000))


## The game's first target (the user's feedback of 2026-11-03).
func test_the_tower_at_1920x1080() -> void:
	await _assert_the_tower_in(Vector2i(1920, 1080))


func test_a_lap_at_1920x1080() -> void:
	await _assert_a_lap_clear_of_the_receipt(Vector2i(1920, 1080))


## A count at twice the quota laps the tube: its lamp reads "×2" over the housing, inside the
## window and clear of the receipt at its full height (RECEIPT_TOP, the usual state by then) and
## of its TODAY'S TARGET (the quota crossing's "×N" stamp beside the receipt is gone, v1.13).
func test_a_lap_keeps_its_badge_clear_of_the_receipt() -> void:
	await _assert_a_lap_clear_of_the_receipt(Vector2i(1280, 720))


func _assert_a_lap_clear_of_the_receipt(window: Vector2i) -> void:
	get_tree().root.size = window
	var screen: ShiftScreen = await _screen()
	screen.profile.set_reduced_motion(true)
	var meter: QuotaMeter = screen._stage.quota_meter
	var quota: int = screen.run.quota()
	meter._show(quota * 2, quota, true, true)
	await _frames(3)
	assert_int(meter.shown_lap()).is_equal(3)
	var visible_rect: Rect2 = get_tree().root.get_visible_rect()
	var receipt: Rect2 = _on_stage(
		screen,
		Rect2(
			ShiftStage.RECEIPT_X,
			ShiftStage.RECEIPT_TOP,
			ShiftStage.RECEIPT_WIDTH,
			ShiftStage.RECEIPT_BOTTOM - ShiftStage.RECEIPT_TOP
		)
	)
	var target: Rect2 = screen._receipt.target.get_global_rect()
	assert_str(meter.badge_text()).is_equal("×2")
	assert_int(meter.get_child_count()).is_equal(0)
	var badge: Rect2 = meter.get_global_transform() * meter.badge_rect()
	var column: Rect2 = screen._stage.tower.get_global_rect()
	assert_bool(visible_rect.encloses(badge)).override_failure_message(str(badge)).is_true()
	assert_bool(column.encloses(badge)).override_failure_message(str(badge)).is_true()
	assert_bool(badge.intersects(receipt)).override_failure_message(str(badge)).is_false()
	assert_bool(badge.intersects(target)).is_false()
	var well: Rect2 = _on_stage(screen, ShiftStage.RECEIPT_WELL_RECT)
	assert_bool(badge.intersects(well)).override_failure_message(str(badge)).is_false()
	assert_float(badge.position.x).is_greater(screen._stage.get_global_rect().position.x)
	var tube: Rect2 = meter.get_global_rect()
	assert_bool(column.encloses(tube)).is_true()
	assert_bool(tube.intersects(receipt)).is_false()


## The tower's faces and the gauge take no click: the belt and the hand keep theirs.
func test_the_tower_takes_no_clicks() -> void:
	var screen: ShiftScreen = await _screen()
	var tower: RegisterTower = screen._stage.tower
	var parts: Array[Node] = tower.find_children("*", "Control", true, false)
	parts.append(tower)
	for part: Node in parts:
		(
			assert_int((part as Control).mouse_filter)
			. override_failure_message(str(part.get_path()))
			. is_equal(Control.MOUSE_FILTER_IGNORE)
		)


func _assert_the_tower_in(window: Vector2i) -> void:
	get_tree().root.size = window
	var screen: ShiftScreen = await _screen()
	screen.profile.set_reduced_motion(true)
	var tower: RegisterTower = screen._stage.tower
	tower.row_pips.show_rows(1, 2)
	var quota: int = screen.run.quota()
	screen._stage.quota_meter.show_projected(quota, quota)
	await _frames(3)
	var visible_rect: Rect2 = get_tree().root.get_visible_rect()
	var stage: Rect2 = screen._stage.get_global_rect()
	var column: Rect2 = tower.get_global_rect()
	assert_that(column).is_equal(_on_stage(screen, ShiftStage.TOWER_RECT))
	assert_float(column.position.y).is_equal(stage.position.y)
	assert_float(column.position.x).is_equal(stage.position.x)
	assert_bool(visible_rect.encloses(column)).override_failure_message(str(column)).is_true()
	assert_float(column.end.y).is_greater_equal(screen._register.get_global_rect().position.y)
	# The tube, in the column's left margin, prints no number, left of the receipt.
	var meter: QuotaMeter = screen._stage.quota_meter
	var tube: Rect2 = meter.get_global_rect()
	assert_that(tube).is_equal(_on_stage(screen, ShiftStage.TUBE_RECT))
	assert_bool(column.encloses(tube)).is_true()
	assert_array(meter.find_children("*", "Label", true, false)).is_empty()
	var receipt: Rect2 = screen._receipt.get_global_rect()
	assert_float(tube.end.x).is_less_equal(receipt.position.x)
	# The receipt rises in its well (its foot goes on into the printer's slot under it).
	var well: Rect2 = _on_stage(screen, ShiftStage.RECEIPT_WELL_RECT)
	assert_bool(column.encloses(well)).is_true()
	assert_float(receipt.position.x).is_greater_equal(well.position.x)
	assert_float(receipt.end.x).is_less_equal(well.end.x)
	assert_float(receipt.position.y).is_greater_equal(well.position.y)
	# The housing (v4's A1, its 57 px at 1080p) holds the glass, in the column's margin, clear of
	# the receipt and of CHECKOUT.
	var housing: GaugeHousing = tower.housing
	var case: Rect2 = _on_stage(screen, ShiftStage.HOUSING_RECT)
	var plate: Rect2 = _on_stage(screen, ShiftStage.PLATE_RECT)
	var checkout: Rect2 = _on_stage(screen, ShiftStage.CHECKOUT_RECT)
	var printer: Rect2 = _on_stage(screen, ShiftStage.PRINTER_RECT)
	var art: float = ArtStyle.ART_SCALE
	assert_that(Vector2(housing.case_rect().size) * art).is_equal(ShiftStage.HOUSING_RECT.size)
	assert_bool(column.encloses(case)).override_failure_message(str(case)).is_true()
	assert_bool(case.encloses(tube)).override_failure_message(str(tube)).is_true()
	assert_float(case.end.x).is_less_equal(receipt.position.x)
	# Its glass is 13 art px wide inside its ink (10 before A1: +30%); its right ink edge is the
	# well's.
	assert_float(tube.size.x / art - 2.0).is_equal(13.0)
	assert_float(case.end.x).is_equal(well.position.x + art)
	for part: Rect2 in [case, plate, tube]:
		assert_bool(part.intersects(receipt)).override_failure_message(str(part)).is_false()
		assert_bool(part.intersects(checkout)).override_failure_message(str(part)).is_false()
		assert_bool(part.intersects(printer)).override_failure_message(str(part)).is_false()
	for part: Rect2 in [plate, tube]:
		assert_bool(part.intersects(well)).override_failure_message(str(part)).is_false()
	assert_float(plate.position.y).is_greater_equal(case.end.y)
	assert_bool(column.encloses(plate)).override_failure_message(str(plate)).is_true()
	# At the quota: no flag; the lamp lit with its check over the housing, inside the column,
	# clear of the receipt.
	assert_int(meter.get_child_count()).is_equal(0)
	assert_str(meter.badge_text()).is_equal(LapLamp.CHECK_TEXT)
	var badge: Rect2 = meter.get_global_transform() * meter.badge_rect()
	assert_bool(column.encloses(badge)).override_failure_message(str(badge)).is_true()
	assert_bool(badge.intersects(receipt)).is_false()
	assert_float(badge.end.x).is_less_equal(stage.position.x + ShiftStage.RECEIPT_X)
	assert_float(badge.end.y).is_less_equal(case.position.y)
	# In the column's margin: clear of the receipt's well, a gutter from the stage's left edge.
	assert_bool(badge.intersects(well)).override_failure_message(str(badge)).is_false()
	assert_float(badge.position.x).is_greater(stage.position.x)
	assert_float(badge.end.x).is_less_equal(tube.end.x + 0.01)
	# A Double checkout's pips on the plate, in place of its €.
	var pips: Rect2 = tower.row_pips.get_global_rect()
	assert_bool(tower.row_pips.visible).is_true()
	assert_float(pips.position.y).is_greater_equal(tube.end.y)
	assert_bool(plate.encloses(pips)).override_failure_message(str(pips)).is_true()
	assert_bool(pips.intersects(receipt)).is_false()
	assert_bool(housing.shows_euro()).is_false()
	tower.row_pips.show_rows(0, 1)
	assert_bool(housing.shows_euro()).is_true()
	# TODAY'S TARGET opens the paper with the quota.
	var target: ReceiptTarget = screen._receipt.target
	assert_bool(target.visible).is_true()
	assert_int(target.shown_quota()).is_equal(quota)
	assert_str(target.amount.text).is_equal("%d€" % quota)
	var block: Rect2 = target.get_global_rect()
	assert_bool(receipt.encloses(block)).override_failure_message(str(block)).is_true()
	var digits: Rect2 = target.digits_rect()
	digits.position += target.global_position
	assert_bool(block.encloses(digits)).override_failure_message(str(digits)).is_true()
	# The top bar starts right of the column.
	var bar: TopBar = screen._stage.top_bar
	assert_float(bar.get_global_rect().position.x).is_greater_equal(column.end.x)
	for part: Control in [bar.week_chip, bar.loyalty_card, bar.deck_button, bar.menu_button]:
		if not part.is_visible_in_tree():
			continue
		var rect: Rect2 = part.get_global_rect()
		assert_float(rect.position.x).is_greater_equal(column.end.x)
		assert_bool(visible_rect.encloses(rect)).override_failure_message(str(rect)).is_true()


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
