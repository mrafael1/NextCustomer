extends GdUnitTestSuite
## The belt on the real shift screen (#55, #75; style frame v2): the row's cells fill the belt's
## rubber at v2's coordinates, the row's cards stand on their mats as belt items, and 7-slot,
## CLOSED, 8-slot and 9-slot rows stay on the belt with every item's sprite, plaque, sticker and
## chips inside its own cell and on the 1280x720 stage. Every rect is checked on screen (headless
## runs use a 1280x1280 window: the stage is centred, 280 px down). The real saves and logs are
## never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const SHORT_BELT := preload("res://data/inspections/short_belt.tres")
## Style frame v2's first cell and the cells' pitch, on the stage.
const CELL_ORIGIN := Vector2(32, 76)
const CELL_PITCH := 124.0
## The smallest a scaled row's sticker summary may print, in canvas pixels.
const MIN_SUMMARY_PX := 10.0
## Chip texts as long as the real ones (BeltChips adds those to every item that has steps).
const CHIP_TEXTS: Array[String] = ["+15 · Category", "×3 · Multipack", "Coupon engine"]

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The 7 cells stand at style frame v2's places (pitch 124 from (32, 76)) and fill the belt's
## rubber between its rails and rollers; the belt and the register stand on the counter line,
## side by side, with the register from 944 to 1264.
func test_the_cells_fill_the_rubber_as_in_style_frame_v2() -> void:
	var screen: ShiftScreen = await _screen()
	var stage: Rect2 = screen._stage.get_global_rect()
	assert_int(screen._slots.size()).is_equal(7)
	for slot: int in range(7):
		var cell: Rect2 = screen._slots[slot].get_global_rect()
		var expected: Vector2 = CELL_ORIGIN + Vector2(slot * CELL_PITCH, 0)
		assert_that(cell).is_equal(Rect2(stage.position + expected, ItemView.BELT_SIZE))
	var belt: Rect2 = screen._stage.belt.get_global_rect()
	var rubber: Rect2 = screen._stage.belt.interior()
	rubber.position += belt.position
	var row: Rect2 = screen._slots[0].get_global_rect().merge(screen._slots[6].get_global_rect())
	assert_that(row).is_equal(rubber)
	var register: Rect2 = screen._register.get_global_rect()
	assert_float(register.position.x - stage.position.x).is_equal(944.0)
	assert_float(register.end.x - stage.position.x).is_equal(1264.0)
	assert_float(belt.end.y).is_equal(stage.position.y + ShiftStage.COUNTER_TOP)
	assert_float(register.end.y).is_equal(belt.end.y)
	assert_float(belt.end.x).is_less(register.position.x)


## The usual 7-slot row, a CLOSED row (Short belt) and a 9-slot row (Big basket and Extra coupon
## slot, scaled to the 7-slot width) stay on the fixed belt's rubber, apart, clear of the receipt
## and the scanner, resting on ROW_BOTTOM, with each value plaque under the top bar, on its mat's
## top rim and clear of its sprite. Row items are belt items (ItemView.BELT_SIZE, the 7-slot row
## never scaled) whose sprite is the moving body.
func test_the_rows_stay_on_the_belt() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	_place(screen, ["bread", "milk", "eggs"])
	await _frames(2)
	_assert_row_on_belt(screen, 7)
	assert_int(screen._row_views.size()).is_equal(3)
	for view: CardView in screen._row_views:
		assert_bool(view is ItemView).is_true()
		assert_vector(view.get_global_rect().size).is_equal(ItemView.BELT_SIZE)
		assert_vector(view.body.get_global_rect().size).is_equal(ItemView.SPRITE_SIZE)

	run.inspections = [SHORT_BELT]
	run.debug_skip_to_shift(run.shift_index)
	screen._on_shift_started()
	_place(screen, ["bread", "milk"])
	await _frames(2)
	assert_int(screen._row_strip.closed.size()).is_equal(1)
	assert_vector(screen._row_strip.box.scale).is_equal(Vector2.ONE)
	_assert_row_on_belt(screen, 7)

	run.inspections = []
	screen._debug.give_upgrade("big_basket")
	screen._debug.give_upgrade("extra_coupon_slot")
	_place(screen, ["bread", "milk", "eggs", "cheese"])
	await _frames(3)
	assert_int(screen._slots.size()).is_equal(9)
	assert_float(screen._row_strip.box.scale.x).is_less(1.0)
	_assert_row_on_belt(screen, 9)
	# The belt keeps its size; the scaled row rests on its bottom line, the empty band above it.
	var row: Rect2 = screen._slots[0].get_global_rect()
	var stage: Rect2 = screen._stage.get_global_rect()
	assert_float(row.end.y).is_equal_approx(stage.position.y + ShiftStage.ROW_BOTTOM, 0.5)
	assert_float(row.position.y).is_greater(stage.position.y + ShiftStage.ROW_POSITION.y)


## Full 8- and 9-slot rows (a full row of products and coupons, two chips each): every item's
## sprite stays in its mat, its plaque (a four-digit payout), sticker and chips in its own cell,
## so nothing reaches a neighbour, all of it on the stage and on the belt's rubber; the sticker's
## summary prints at least MIN_SUMMARY_PX tall.
func test_full_wide_rows_keep_each_item_in_its_cell() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.give_upgrade("big_basket")
	await _frames(2)
	await _assert_full_row_fits(screen, 8)
	screen._debug.give_upgrade("extra_coupon_slot")
	await _frames(2)
	await _assert_full_row_fits(screen, 9)


func _assert_full_row_fits(screen: ShiftScreen, count: int) -> void:
	assert_int(screen._slots.size()).is_equal(count)
	screen.run.row.clear()
	var ids: Array[String] = ["milk", "repeat", "banana", "two_for_one", "cheese"]
	var cards: Array[String] = []
	for slot: int in range(count):
		cards.append(ids[slot % ids.size()])
	_place(screen, cards)
	await _frames(2)
	assert_int(screen._row_views.size()).is_equal(count)
	var stage: Rect2 = screen._stage.get_global_rect()
	var belt: Rect2 = screen._stage.belt.get_global_rect()
	var rubber: Rect2 = screen._stage.belt.interior()
	rubber = Rect2(belt.position + rubber.position, rubber.size).grow(0.01)
	for slot: int in range(count):
		var item: ItemView = screen._row_views[slot] as ItemView
		item.show_badge(9999, false)
		for text: String in CHIP_TEXTS:
			item.add_chip(text, false)
		var message: String = "%d slots, item %d" % [count, slot]
		var cell: Rect2 = screen._slots[slot].get_global_rect()
		assert_bool(rubber.encloses(cell)).override_failure_message(message).is_true()
		var mat: Rect2 = RowStrip.mat(screen._slots[slot]).get_global_rect()
		var sprite: Rect2 = item.body.get_global_rect()
		assert_bool(mat.encloses(sprite)).override_failure_message(message).is_true()
		var parts: Array[Control] = [(item.badge as PayoutPlaque).face(), item.sticker()]
		parts.append_array(item.chips())
		for part: Control in parts:
			var rect: Rect2 = part.get_global_rect()
			(
				assert_bool(cell.grow(0.01).encloses(rect))
				. override_failure_message("%s: %s at %s" % [message, part.get_class(), rect])
				. is_true()
			)
			assert_bool(stage.encloses(rect)).override_failure_message(message).is_true()
		var summary: Label = item.sticker().summary_label()
		var shown: float = (
			summary.get_theme_font_size("font_size") * summary.get_global_transform().get_scale().y
		)
		assert_float(shown).override_failure_message(message).is_greater_equal(MIN_SUMMARY_PX)


func _assert_row_on_belt(screen: ShiftScreen, panel_count: int) -> void:
	var stage: Rect2 = screen._stage.get_global_rect()
	var bar_bottom: float = stage.position.y + RewardPanel.PRINTOUT_TOP
	var belt: Rect2 = (screen._row_strip.get_parent() as Control).get_global_rect()
	var receipt: Rect2 = screen._receipt.get_global_rect()
	var scanner: Rect2 = screen._stage.scanner.get_global_rect()
	assert_that(belt).is_equal(_on_stage(screen, ShiftStage.BELT_RECT))
	assert_bool(stage.encloses(belt)).is_true()
	# On the rubber, between the belt's rails and rollers.
	var rubber: Rect2 = screen._stage.belt.interior()
	# (Grown by a hair: a scaled row ends on the roller's edge, give or take float rounding.)
	var interior: Rect2 = Rect2(belt.position + rubber.position, rubber.size).grow(0.01)
	var panels: Array[PanelContainer] = screen._slots + screen._row_strip.closed
	assert_int(panels.size()).is_equal(panel_count)
	var previous: Rect2 = Rect2()
	for index: int in range(panels.size()):
		var rect: Rect2 = panels[index].get_global_rect()
		assert_bool(interior.encloses(rect)).override_failure_message(str(rect)).is_true()
		assert_bool(rect.intersects(receipt)).override_failure_message(str(rect)).is_false()
		assert_bool(rect.intersects(scanner)).override_failure_message(str(rect)).is_false()
		# Every row rests on the same line.
		assert_float(rect.end.y).is_equal_approx(stage.position.y + ShiftStage.ROW_BOTTOM, 0.5)
		# (A scaled row's cells touch, give or take float rounding.)
		if index > 0:
			assert_float(rect.position.x).is_greater_equal(previous.end.x - 0.01)
		previous = rect
	for view: CardView in screen._row_views:
		assert_bool(view.badge.visible).is_true()
		var badge: Rect2 = view.badge.get_global_rect()
		var face: Rect2 = (view.badge as PayoutPlaque).face().get_global_rect()
		var mat: Rect2 = RowStrip.mat(view.get_parent() as PanelContainer).get_global_rect()
		assert_float(badge.position.y).is_greater_equal(bar_bottom)
		assert_bool(view.get_global_rect().encloses(face)).is_true()
		assert_float(face.position.y).is_less_equal(mat.position.y)
		assert_float(face.end.y).is_greater(mat.position.y)
		assert_bool(face.intersects(view.body.get_global_rect())).is_false()
		assert_bool(badge.intersects(receipt)).is_false()


## Puts copies of cards into the row, in order, and refreshes the screen.
func _place(screen: ShiftScreen, card_ids: Array[String]) -> void:
	var run: RunState = screen.run
	for card_id: String in card_ids:
		var card: CardInstance = run.debug_add_to_hand(load("res://data/cards/%s.tres" % card_id))
		assert_bool(run.place(card, run.row.size())).is_true()
	screen._refresh()


## The screen past the impulse rack, laid out.
func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()
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
