extends GdUnitTestSuite
## The Slot engine's mark on the belt (2026-10-24, #106 follow-up: the upgrade always acts on slot
## 6, and slot 6 shows it): on the real shift screen, a run that owns Slot engine shows one
## SlotMark, a loyalty talker hanging under the right end of slot 6's ticket, whatever the row's
## slots (6 on a Short belt shift, 7, 8 with Big basket), empty or filled; a run without it shows
## none. Every rect is checked on screen (headless runs use a 1280x1280 window): the talker stays in
## slot 6's column, its top tucked behind the ticket, clear of the next tickets and the
## baskets (above their rims, #123), and on screen. In the count it fires (a punch and a swing about
## its hook) when the upgrade's ×2 lands on slot 6. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const SLOT_6 := 5
## The reference row (count_up_test) under Coupon engine, Slot engine and the Spot check: the
## Milk in slot 6 gets Slot engine's ×2.
const FULL_ROW: Array[String] = ["eggs", "bread", "milk", "multipack", "milk", "milk", "milk"]

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_slot_mark_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Slot engine's talker hangs on slot 6 with 6, 7 and 8 slots (Short belt, none, Big basket, and
## both), in its column, tucked behind its ticket and on screen; it stays when slot 6 fills.
func test_slot_engine_marks_slot_6_with_any_slot_count(
	upgrade_ids: Array,
	inspection_id: String,
	slots: int,
	_test_parameters := [
		[["slot_engine"], "", 7],
		[["slot_engine"], "short_belt", 6],
		[["slot_engine", "big_basket"], "", 8],
		[["big_basket", "slot_engine"], "short_belt", 7],
	]
) -> void:
	var screen: ShiftScreen = await _screen()
	await _set_run(screen, upgrade_ids, inspection_id)
	var strip: RowStrip = screen._row_strip
	assert_int(strip.slots.size()).is_equal(slots)
	var marks: Array[SlotMark] = _marks(screen)
	assert_int(marks.size()).is_equal(1)
	var mark: SlotMark = strip.slot_mark(SLOT_6)
	assert_object(mark).is_same(marks[0])
	assert_int(mark.slot).is_equal(SLOT_6)
	assert_int(mark.upgrade_index).is_equal(upgrade_ids.find("slot_engine"))
	assert_int(mark.factor).is_equal(2)
	assert_str(mark.text()).is_equal("×2")
	var icon: TextureRect = mark.icon() as TextureRect
	assert_object(icon).is_not_null()
	assert_str(icon.texture.resource_path).is_equal(_upgrade("slot_engine").icon_ref)
	assert_bool(strip.slots[SLOT_6].is_ancestor_of(mark)).is_true()
	assert_int(mark.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	# Empty: under the blank ticket.
	assert_bool(RowStrip.shows_empty_mat(strip.slots[SLOT_6])).is_true()
	_assert_mark_in_place(screen, RowStrip.mat(strip.slots[SLOT_6]).get_global_rect())
	# Filled up to slot 6: under the item's ticket, at the same place.
	var at_rest: Rect2 = mark.get_global_rect()
	var ids: Array[String] = ["bread", "eggs", "milk", "bread", "cheese", "milk"]
	await _place(screen, ids)
	assert_object(strip.slot_mark(SLOT_6)).is_same(mark)
	assert_int(_marks(screen).size()).is_equal(1)
	assert_that(mark.get_global_rect()).is_equal(at_rest)
	var item: ItemView = screen._row_views[SLOT_6] as ItemView
	_assert_mark_in_place(screen, item.sticker().get_global_rect())


## No Slot engine, no mark: neither a plain run nor one with other upgrades and Short belt.
func test_no_mark_without_slot_engine() -> void:
	var screen: ShiftScreen = await _screen()
	assert_array(_marks(screen)).is_empty()
	await _set_run(screen, ["coupon_engine", "big_basket", "category_engine"], "short_belt")
	assert_array(_marks(screen)).is_empty()
	assert_object(screen._row_strip.slot_mark(SLOT_6)).is_null()


## A fire punches the talker and swings it about its hook (its top's middle), then it settles
## back at rest; under reduced motion it stays at rest.
func test_a_fire_punches_and_swings_the_mark() -> void:
	var screen: ShiftScreen = await _screen()
	await _set_run(screen, ["slot_engine"], "")
	var mark: SlotMark = screen._row_strip.slot_mark(SLOT_6)
	var inner: Control = mark.inner()
	assert_vector(inner.pivot_offset).is_equal(Vector2(mark.size.x / 2.0, 0.0))
	mark.fire(false)
	assert_int(mark.fired_count()).is_equal(1)
	assert_bool(mark.is_firing()).is_true()
	var punched: bool = false
	var swung: bool = false
	while mark.is_firing():
		await get_tree().process_frame
		punched = punched or inner.scale.x > 1.05
		swung = swung or absf(inner.rotation_degrees) > 1.0
	assert_bool(punched).is_true()
	assert_bool(swung).is_true()
	assert_vector(inner.scale).is_equal(Vector2.ONE)
	assert_float(inner.rotation_degrees).is_equal_approx(0.0, 0.001)
	assert_that(inner.modulate).is_equal(Color.WHITE)
	mark.fire(true)
	assert_int(mark.fired_count()).is_equal(2)
	assert_bool(mark.is_firing()).is_false()
	assert_vector(inner.scale).is_equal(Vector2.ONE)


## A real checkout of the reference row: the talker fires once, when Slot engine's ×2 lands on
## the Milk in slot 6, and rides with its cell (in its column while it shows).
func test_a_checkout_fires_the_mark_when_the_x2_lands() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.give_upgrade("coupon_engine")
	screen._debug.give_upgrade("slot_engine")
	screen._debug.set_inspection("spot_check")
	await _place(screen, FULL_ROW)
	var mark: SlotMark = screen._row_strip.slot_mark(SLOT_6)
	var cell: PanelContainer = screen._row_strip.slots[SLOT_6]
	var failures: Array[String] = []
	var fired_at: Array[int] = []
	screen._on_checkout_pressed()
	while screen._counting:
		await get_tree().process_frame
		if mark.fired_count() > fired_at.size():
			fired_at.append(screen._ride.scanning())
		if mark.is_visible_in_tree():
			var column: Rect2 = cell.get_global_rect()
			var rect: Rect2 = mark.get_global_rect()
			if rect.position.x < column.position.x - 0.5 or rect.end.x > column.end.x + 0.5:
				failures.append("the mark at %s off its column %s" % [rect, column])
	assert_array(failures.slice(0, 5)).override_failure_message(str(failures)).is_empty()
	assert_array(fired_at).is_equal([SLOT_6])


## The mark under a ticket at `ticket` (global): in slot 6's column, its top TUCKED (scaled) behind
## the ticket's foot, the rest under it, clear of the other slots' tickets, above the baskets' rims,
## and on screen.
func _assert_mark_in_place(screen: ShiftScreen, ticket: Rect2) -> void:
	var strip: RowStrip = screen._row_strip
	var mark: SlotMark = strip.slot_mark(SLOT_6)
	assert_bool(mark.is_visible_in_tree()).is_true()
	var rect: Rect2 = mark.get_global_rect()
	var scale: float = strip.box.scale.x
	assert_vector(rect.size).is_equal_approx(mark.size * scale, Vector2(0.01, 0.01))
	var column: Rect2 = strip.slots[SLOT_6].get_global_rect()
	assert_float(rect.position.x).is_greater_equal(column.position.x - 0.01)
	assert_float(rect.end.x).is_less_equal(column.end.x + 0.01)
	assert_float(rect.position.x).is_greater_equal(ticket.get_center().x)
	assert_float(rect.position.y).is_equal_approx(ticket.end.y - SlotMark.TUCKED * scale, 0.01)
	assert_float(rect.end.y).is_greater(ticket.end.y)
	for slot: int in range(strip.slots.size()):
		if slot != SLOT_6:
			var other: Rect2 = RowStrip.mat(strip.slots[slot]).get_global_rect()
			assert_bool(rect.intersects(other)).override_failure_message(str(slot)).is_false()
	# Over the counter face, above the baskets' rims (#123: the belt sits on the baskets).
	var rims: float = screen._stage.get_global_rect().position.y + HandBaskets.RIM_BACK_Y
	assert_float(rect.end.y).is_less_equal(rims)
	assert_bool(screen.get_viewport_rect().encloses(rect)).is_true()
	assert_bool(screen._stage.get_global_rect().encloses(rect)).is_true()


static func _marks(screen: ShiftScreen) -> Array[SlotMark]:
	var marks: Array[SlotMark] = []
	for node: Node in screen._row_strip.find_children("*", "SlotMark", true, false):
		if not node.is_queued_for_deletion():
			marks.append(node as SlotMark)
	return marks


## Shift 1 under `upgrade_ids` and the inspection `inspection_id` (none for "").
func _set_run(screen: ShiftScreen, upgrade_ids: Array, inspection_id: String) -> void:
	var run: RunState = screen.run
	var upgrades: Array[UpgradeDefinition] = []
	for upgrade_id: Variant in upgrade_ids:
		upgrades.append(_upgrade(str(upgrade_id)))
	run.upgrades = upgrades
	var inspections: Array[InspectionDefinition] = []
	if not inspection_id.is_empty():
		inspections.append(load("res://data/inspections/%s.tres" % inspection_id))
	run.inspections = inspections
	run.debug_skip_to_shift(run.shift_index)
	screen._on_shift_started()
	await _frames(3)


static func _upgrade(upgrade_id: String) -> UpgradeDefinition:
	return load("res://data/upgrades/%s.tres" % upgrade_id) as UpgradeDefinition


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(3)
	return screen


## Places each card at the row's end as the player does: picked from the hand, then its slot
## clicked.
func _place(screen: ShiftScreen, ids: Array[String]) -> void:
	var placed: int = screen.run.row.size()
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(placed + ids.size())
	await _frames(3)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	for view: Control in screen._hand_box.cards():
		if (view as CardView).card == card:
			return view as CardView
	return null


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
