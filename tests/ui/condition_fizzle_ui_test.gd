extends GdUnitTestSuite
## Condition fizzles on the real shift screen (#45): a conditional card whose condition fails
## plays the same fizzle as an effect's in the count-up (a FIZZLE beat, a "pfff…" puff over its
## item) and prints its reason as a fizzle line on the receipt, on screen. The real saves and logs
## are never touched: both go to a temporary folder.

const SCREEN := "res://ui/shift_screen.tscn"
const Rush := preload("res://tests/ui/count_up_rush.gd")
const SCREEN_RECT := Rect2(0, 0, 1280, 720)

var _folder: String = ""
var _window_size: Vector2i
var _runner: GdUnitSceneRunner


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(SCREEN_RECT.size)


func after_test() -> void:
	Rush.restore()
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## A conditional card whose condition fails fizzles like an effect (#45): Cheese with no Bread
## just before it gets a FIZZLE beat, puffs "pfff…" over its own item and prints its reason as a
## fizzle line on the receipt, on screen inside the receipt; the total is its plain payouts.
func test_a_failed_condition_fizzles_in_the_count_up_and_on_the_receipt() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["cheese", "bread"])
	var count_up: CountUp = screen._count_up
	var rect_of: Callable = func(slot: int) -> Rect2:
		return Rect2(Vector2(300.0 + 40.0 * slot, 200.0), Vector2(40, 40))
	count_up.source_rect = rect_of
	var puffs: Array[Vector2] = []
	var record: Callable = func(node: Control) -> void:
		if node is Label and (node as Label).text == "pfff…":
			puffs.append(node.get_global_rect().get_center())
	var on_added: Callable = func(node: Node) -> void:
		if node is Control:
			record.call_deferred(node)
	screen._overlay.child_entered_tree.connect(on_added)
	var result: ScoreResult = screen.run.preview()
	var cheese: CardDefinition = screen.run.row[0].definition
	var bread: CardDefinition = screen.run.row[1].definition
	assert_int(result.total).is_equal(cheese.base + bread.base)
	_play_tapped(screen, result, 500)
	await _played(screen)
	screen._overlay.child_entered_tree.disconnect(on_added)
	count_up.source_rect = Callable()
	var fizzle_beats: Array[int] = []
	for beat: CountUpBeat in count_up.plan.beats:
		if beat.kind == CountUpBeat.Kind.FIZZLE:
			fizzle_beats.append(beat.slot)
	assert_array(fizzle_beats).is_equal([0])
	assert_int(puffs.size()).is_equal(1)
	var over_cheese: Vector2 = (rect_of.call(0) as Rect2).get_center() + Vector2(0, -30)
	assert_float(puffs[0].distance_to(over_cheese)).is_less(1.0)
	await _assert_receipt_of(screen, result, 500)
	var wanted: String = "Cheese after Bread: no Bread just before it"
	var found: Control = null
	for line: Node in screen._receipt._lines.get_children():
		if line is HSeparator:
			continue
		var label: Label = line.get_child(0) as Label
		if label != null and label.text.strip_edges() == wanted:
			found = line as Control
	assert_object(found).override_failure_message(str(_lines(screen._receipt))).is_not_null()
	if found == null:
		return
	var receipt_rect: Rect2 = screen._receipt.get_global_rect()
	assert_bool(receipt_rect.grow(1.0).encloses(found.get_global_rect())).is_true()
	assert_bool(screen.get_viewport_rect().encloses(found.get_global_rect())).is_true()


## In planning a failed condition wears the effects' grey "pfff" sticker on its own item, on
## screen; once the condition is met (Bread just before Cheese) the fizzle goes and the bonus shows.
func test_a_failed_condition_shows_a_pfff_sticker_in_planning() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["cheese"])
	var fizzle: EffectSticker = _sticker(screen, 0, "pfff")
	assert_object(fizzle).is_not_null()
	if fizzle == null:
		return
	assert_bool(SCREEN_RECT.encloses(fizzle.get_global_rect())).is_true()
	# Cheese taken back out, then Bread and Cheese placed in that order: the condition is met.
	screen._on_row_card_clicked(screen._row_views[0])
	screen._let_go()
	await _frames(2)
	await _place(screen, ["bread", "cheese"])
	assert_object(_sticker(screen, 1, "pfff")).is_null()
	assert_object(_sticker(screen, 1, "+4")).is_not_null()


## Plays `result` on the screen's row against `quota`, tapped twice (the count and the dessert
## at skip speed), as a shift-1 count-up under the screen's receipt header.
func _play_tapped(screen: ShiftScreen, result: ScoreResult, quota: int) -> void:
	var count_up: CountUp = screen._count_up
	count_up.play(
		result,
		screen._row_views,
		ShiftScreen._names(screen.run.row),
		quota,
		CountUpContext.new(1, 0, 1.0, false, screen.receipt_header()),
		screen._loyalty_card.stamped_boxes(),
		LoyaltyCard.names(screen.run.upgrades),
		screen._inspection_tag.sources(screen.run.inspections),
		InspectionTag.names(screen.run.inspections)
	)
	count_up._tap(Time.get_ticks_msec())
	count_up._tap(Time.get_ticks_msec())


func _played(screen: ShiftScreen) -> void:
	await Rush.played(screen._count_up)


## The count-up's receipt is `result`'s, line for line, under the shift's header, ended by the
## dessert against `quota`, every line fully shown.
func _assert_receipt_of(screen: ShiftScreen, result: ScoreResult, quota: int) -> void:
	await _lines_shown(screen._receipt)
	var run: RunState = screen.run
	var expected: ReceiptView = auto_free(ReceiptView.new())
	expected.show_result(
		result,
		ShiftScreen._names(run.row),
		LoyaltyCard.names(run.upgrades),
		InspectionTag.names(run.inspections),
		screen.receipt_header()
	)
	expected.show_shift_end(result.total, quota, "")
	assert_array(_lines(screen._receipt)).is_equal(_lines(expected))
	for line: Node in screen._receipt._lines.get_children():
		assert_float((line as CanvasItem).modulate.a).is_equal(1.0)


## Waits until every receipt line has faded in, or half a second.
func _lines_shown(receipt: ReceiptView) -> void:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 500:
		var fading: bool = false
		for line: Node in receipt._lines.get_children():
			fading = fading or (line as CanvasItem).modulate.a < 1.0
		if not fading:
			return
		await get_tree().process_frame


## A receipt's lines as text ("left | right"; "---" for the rule above the total).
static func _lines(receipt: ReceiptView) -> Array[String]:
	var lines: Array[String] = []
	for line: Node in receipt._lines.get_children():
		if line is HSeparator:
			lines.append("---")
			continue
		var texts: PackedStringArray = PackedStringArray()
		for label: Node in line.get_children():
			texts.append((label as Label).text)
		lines.append(" | ".join(texts))
	return lines


func _screen() -> ShiftScreen:
	_runner = scene_runner(SCREEN)
	var screen: ShiftScreen = _runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	await _frames(2)
	return screen


## The planning sticker on `slot`'s item that reads `text`, or null.
static func _sticker(screen: ShiftScreen, slot: int, text: String) -> EffectSticker:
	for sticker: EffectSticker in screen._stage.planning_layer.stack(slot):
		if sticker.text() == text:
			return sticker
	return null


func _place(screen: ShiftScreen, ids: Array[String]) -> void:
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(ids.size())
	await _frames(3)


func _frames(count: int) -> void:
	for frame: int in range(count):
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
