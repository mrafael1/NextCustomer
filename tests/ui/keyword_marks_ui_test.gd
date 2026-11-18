extends GdUnitTestSuite
## The belt's PAIR marks (v1.06, the keywords handbook: "PAIR misses a visual on the
## ticket"). The score records every PAIR (ScoreResult.pairs), the planning model passes them
## on, and on the real shift
## screen KeywordMarks puts a teal clasp across each PAIR's gap, inside the screen, clear of the
## tickets' text.
## The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const CARDS := "res://data/cards/%s.tres"
const SCREEN_RECT := Rect2(0, 0, 1280, 720)
## Tea bags and Coffee, then Butter beside Bread.
const ROW: Array[String] = ["tea_bags", "bread", "milk", "potatoes", "coffee", "butter", "bread"]

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
	_runner = null
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The score's PAIRs (each paired product with its partner, once), passed on by the model.
func test_the_score_records_the_pairs(
	row: String,
	pairs: Array,
	_test_parameters := [
		["bread,milk,eggs", []],
		["butter,bread,cheese", [Vector2i(0, 1), Vector2i(1, 2)]],
		["cheese,potatoes,bread", []],
		["cereal,milk,coffee", [Vector2i(0, 1)]],
	]
) -> void:
	var model: PlanningModel = _model(row)
	assert_array(model.pairs).is_equal(pairs)


## A Double checkout's joined result moves row 2's marks past row 1's slots.
func test_a_joined_result_moves_the_second_rows_marks() -> void:
	var first: ScoreResult = Scoring.score(_row("coffee,milk"))
	var second: ScoreResult = Scoring.score(_row("butter,bread"))
	var joined: ScoreResult = ScoreResult.joined(first, second, 2)
	assert_array(joined.pairs).is_equal([Vector2i(2, 3)])
	assert_array(ScoreResult.continued(second, 10).pairs).is_equal([Vector2i(0, 1)])


## A clasp crosses the Butter and Bread gap at the tickets' middle, clear of both tickets' text.
func test_the_marks_sit_on_the_belt() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ROW)
	var marks: KeywordMarks = _marks(screen)
	assert_array(marks.clasp_gaps()).is_equal([Vector2i(5, 6)])
	var clasp: Rect2 = marks.clasps()[0].get_global_rect()
	var butter: Rect2 = _ticket(screen, 5)
	var bread: Rect2 = _ticket(screen, 6)
	assert_bool(marks.clasps()[0].is_visible_in_tree()).is_true()
	assert_float(clasp.position.x).is_less(butter.end.x)
	assert_float(clasp.end.x).is_greater(bread.position.x)
	assert_float(clasp.position.x).is_greater_equal(butter.end.x - 4.0)
	assert_float(clasp.end.x).is_less_equal(bread.position.x + 4.0)
	assert_float(clasp.position.y).is_greater(butter.position.y)
	assert_float(clasp.end.y).is_less(butter.end.y)
	for slot: int in [5, 6]:
		var sticker: PriceSticker = _item(screen, slot).sticker()
		var text: Rect2 = sticker.get_global_transform() * sticker.summary_text_rect()
		assert_bool(clasp.intersects(text)).override_failure_message(str(slot)).is_false()


## A PAIR clasp in a gap a batch or chain frame's side runs through draws over the frame, and it
## keeps clear of the frames' parts: the batch bars, the chain links, the chain's own clasps (a
## FEED's or TALLY's) and its knot plates; it still crosses its gap, clear of the tickets' text.
func test_a_pair_clasp_beside_a_frame_keeps_clear_of_its_parts(
	row: String,
	gap: Vector2i,
	_test_parameters := [
		["croissant,bread,butter", Vector2i(1, 2)],
		["yogurt,banana,banana", Vector2i(0, 1)],
		["strawberries,banana,banana,yogurt", Vector2i(2, 3)],
		["yogurt,banana,banana,strawberries", Vector2i(0, 1)],
		["yogurt,banana,banana,wonky_carrot", Vector2i(0, 1)],
	]
) -> void:
	var screen: ShiftScreen = await _screen()
	var ids: Array[String] = []
	ids.assign(row.split(","))
	await _place(screen, ids)
	var marks: KeywordMarks = _marks(screen)
	var index: int = marks.clasp_gaps().find(gap)
	assert_int(index).override_failure_message(str(marks.clasp_gaps())).is_not_equal(-1)
	if index < 0:
		return
	var clasp: TextureRect = marks.clasps()[index]
	assert_bool(clasp.is_visible_in_tree()).is_true()
	var rect: Rect2 = clasp.get_global_rect()
	var layer: PlanningLayer = _layer(screen)
	var to_global: Transform2D = layer.get_global_transform()
	var parts: Array[Rect2] = []
	var framed: bool = false
	for chains: bool in [false, true]:
		for frame: BatchFrame in layer.frames(chains):
			if not frame.visible:
				continue
			framed = framed or (to_global * frame.frame_rect()).intersects(rect)
			var shown: Array[Rect2] = frame.bar_rects().duplicate()
			var chain: ChainFrame = frame as ChainFrame
			if chain != null:
				shown.append_array(chain.link_rects())
				shown.append_array(chain.clasp_rects())
				shown.append_array(chain.plate_rects())
			for part: Rect2 in shown:
				parts.append(to_global * part)
	assert_bool(framed).override_failure_message("no frame beside the clasp").is_true()
	for part: Rect2 in parts:
		var met: String = "%s meets %s" % [rect, part]
		assert_bool(rect.intersects(part)).override_failure_message(met).is_false()
	# Over the frames: the batch box comes before the chains' box, the marks last in theirs.
	var chain_box: Node = marks.get_parent()
	assert_int(marks.get_index()).is_equal(chain_box.get_child_count() - 1)
	var batch_box: Node = layer.find_child("BatchFrames", false, false)
	assert_int(batch_box.get_index()).is_less(chain_box.get_index())
	var left: Rect2 = _ticket(screen, gap.x)
	var right: Rect2 = _ticket(screen, gap.y)
	assert_float(rect.position.x).is_less(left.end.x)
	assert_float(rect.end.x).is_greater(right.position.x)
	assert_float(rect.position.y).is_greater(left.position.y)
	assert_float(rect.end.y).is_less(left.end.y)
	for slot: int in [gap.x, gap.y]:
		var sticker: PriceSticker = _item(screen, slot).sticker()
		var text: Rect2 = sticker.get_global_transform() * sticker.summary_text_rect()
		assert_bool(rect.intersects(text)).override_failure_message(str(slot)).is_false()


## A row with no PAIR shows no clasp, and the marks' box hides.
func test_a_plain_row_shows_no_marks() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["bread", "milk", "potatoes"])
	var marks: KeywordMarks = _marks(screen)
	assert_array(marks.clasps()).is_empty()
	assert_bool(marks.visible).is_false()


static func _marks(screen: ShiftScreen) -> KeywordMarks:
	return KeywordMarks.of(_layer(screen))


static func _layer(screen: ShiftScreen) -> PlanningLayer:
	return screen._stage.planning_layer


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for id: String in ids.split(","):
		row.append(CardInstance.new(load(CARDS % id) as CardDefinition, row.size() + 1))
	return row


func _model(ids: String) -> PlanningModel:
	var row: Array[CardInstance] = _row(ids)
	var cards: Array[CardDefinition] = []
	for card: CardInstance in row:
		cards.append(card.definition)
	var none_upgrades: Array[UpgradeDefinition] = []
	var none_events: Array[InspectionDefinition] = []
	return PlanningModel.build(Scoring.score(row), cards, none_upgrades, none_events, null)


## `slot`'s ticket's global rect.
static func _ticket(screen: ShiftScreen, slot: int) -> Rect2:
	var sticker: PriceSticker = _item(screen, slot).sticker()
	return sticker.get_global_transform() * Rect2(Vector2.ZERO, sticker.size)


static func _item(screen: ShiftScreen, slot: int) -> ItemView:
	return screen._row_views[slot] as ItemView


func _screen() -> ShiftScreen:
	if FileAccess.file_exists(_folder.path_join(SaveService.RUN_FILE)):
		DirAccess.remove_absolute(_folder.path_join(SaveService.RUN_FILE))
	_runner = scene_runner(SCREEN)
	var screen: ShiftScreen = _runner.scene()
	await _frames(2)
	return screen


func _place(screen: ShiftScreen, ids: Array[String]) -> void:
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(ids.size())
	await _frames(3)


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
