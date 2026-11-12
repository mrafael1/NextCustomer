extends GdUnitTestSuite
## Write-off on the real shift screen (v1.28, the user's answers of 2026-11-11): the written-off
## item wears a WRITTEN OFF label on the belt while planning (not denied: its caption inside the
## label, at its art's foot, on screen, and its stickers stay lit), the checkout's count plays it
## without a fizzle, and the receipt's row for it keeps the item's whole name with the Write-off's
## mark. Clicks are sent to the screen's handlers, because headless runs don't deliver input
## events.

const SCREEN := "res://ui/shift_screen.tscn"
const Rush := preload("res://tests/ui/count_up_rush.gd")
const SCREEN_RECT := Rect2(0, 0, 1280, 720)

var _folder: String = ""
var _live_machine: MachineDefinition


func before_test() -> void:
	_live_machine = NoOvertime.live_off()
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	NoOvertime.live_restore(_live_machine)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_a_written_off_item_is_stamped_and_printed() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(2)
	# Over shift 1's quota (30), so the checkout's receipt stays up.
	_place_ids(screen, ["write_off", "bread", "repeat", "bread", "bread", "bread"])
	await _frames(3)
	var preview: ScoreResult = screen.run.preview()
	assert_array(Array(preview.payouts)).is_equal([0, 10, 10, 5, 5, 5])
	# The belt: Bread's WRITTEN OFF label at its art's foot, on screen; none elsewhere.
	var layer: PlanningLayer = screen._stage.planning_layer
	var stamp: DenyStamp = layer.stamp(1)
	assert_object(stamp).is_not_null()
	assert_bool(stamp.is_written_off()).is_true()
	assert_str(stamp.caption()).is_equal(PlanningModel.WRITTEN_OFF_CAPTION)
	# Its caption lies inside its paper (one line, whole).
	var face: Rect2 = (stamp.get_node("Face") as Control).get_global_rect()
	var caption: Rect2 = (stamp.get_node("Lines/Caption") as Control).get_global_rect()
	assert_bool(face.grow(2.0).encloses(caption)).override_failure_message(str(caption)).is_true()
	assert_bool(stamp.is_drained()).is_false()
	# Bread's stickers (Write-off's ×2) stay lit: written off is no denial.
	var stickers: Array[EffectSticker] = layer.stack(1)
	assert_bool(stickers.is_empty()).is_false()
	for sticker: EffectSticker in stickers:
		assert_bool(sticker.is_drained()).is_false()
	for slot: int in [0, 2, 3, 4, 5]:
		assert_object(layer.stamp(slot)).override_failure_message(str(slot)).is_null()
	var item: ItemView = screen._row_views[1] as ItemView
	assert_bool(item.denied).is_false()
	var stamp_rect: Rect2 = stamp.get_global_rect()
	var art: Rect2 = item.sprite().get_global_rect()
	assert_bool(stamp_rect.intersects(art)).is_true()
	# At the art's foot: the art's top half stays clear.
	assert_float(stamp_rect.position.y).is_greater(art.get_center().y)
	assert_bool(SCREEN_RECT.encloses(stamp_rect)).is_true()
	# The count: no fizzle on the row; the receipt's Bread row says WRITTEN OFF.
	for slot: int in range(6):
		assert_int(ReceiptView.slot_mark(preview, slot)).is_equal(ReceiptView.Mark.NONE)
	await Rush.checkout(screen)
	assert_int(screen._led.amount()).is_equal(preview.total)
	assert_str(_receipt_text(screen)).not_contains("· WRITTEN")
	var marks: Array[int] = []
	for mark: Node in screen._receipt.find_children("Mark", "TextureRect", true, false):
		if not mark.is_queued_for_deletion():
			marks.append(int(mark.get_meta("mark")))
	assert_array(marks).is_equal([ReceiptView.Mark.WRITTEN_OFF])


func _place_ids(screen: ShiftScreen, ids: Array[String]) -> void:
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())


## Every line of the receipt, joined.
static func _receipt_text(screen: ShiftScreen) -> String:
	var texts: PackedStringArray = PackedStringArray()
	for label: Node in screen._receipt.find_children("*", "Label", true, false):
		if label.is_queued_for_deletion() or label.get_parent().is_queued_for_deletion():
			continue
		texts.append((label as Label).text)
	return "\n".join(texts)


func _frames(count: int) -> void:
	for _frame: int in range(count):
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
