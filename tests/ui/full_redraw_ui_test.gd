extends GdUnitTestSuite
## The full redraw on the real screen (#122, a badge pin: RunPins, FullRedrawFlow): with the pin
## worn, redraw mode shows a REDRAW ALL tag centred over the baskets, under the belt and above
## the baskets' tags; hovered, it names how many items go and the monitor explains; clicking it
## swaps every hand item for one redraw (logged as redraw_all, saved), and the baskets play the
## redraw's motion one after another, every click blocked until the last ends. Once used, the
## shift shows no REDRAW ALL tag again; without the pin there is none. The real saves and logs
## are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const FULL_REDRAW := "res://data/pins/full_redraw.tres"

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_no_pin_no_redraw_all_tag() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_redraw_pressed()
	await _frames(2)
	assert_bool(screen._basket_tags.is_shown()).is_true()
	assert_object(screen._basket_tags.all_tag()).is_null()


## The tag sits centred over the four baskets, on the stage, under the belt's slots, above the
## baskets' own tags and apart from them; its word fits inside it.
func test_the_redraw_all_tag_sits_between_the_belt_and_the_baskets() -> void:
	var screen: ShiftScreen = await _screen()
	RunPins.wear(screen.run, [load(FULL_REDRAW)])
	screen._on_redraw_pressed()
	await _frames(2)
	var tags: BasketTags = screen._basket_tags
	var all: RedrawTag = tags.all_tag()
	assert_object(all).is_not_null()
	assert_str(all.text()).is_equal(BasketTags.ALL_WORD)
	var rect: Rect2 = all.get_global_rect()
	var stage: Rect2 = screen._stage.get_global_rect()
	assert_bool(stage.encloses(rect)).is_true()
	var first: Rect2 = _on_stage(screen, screen._stage.baskets.basket_rect(0))
	var last: Rect2 = _on_stage(screen, screen._stage.baskets.basket_rect(3))
	var centre: float = (first.position.x + last.end.x) / 2.0
	assert_float(rect.get_center().x).is_equal_approx(centre, 1.0)
	var belt: Rect2 = screen._stage.belt.get_global_rect()
	assert_float(rect.position.y).is_greater_equal(belt.end.y)
	assert_bool(rect.encloses(all.word_label().get_global_rect())).is_true()
	for basket: int in range(4):
		var tag: Rect2 = tags.tag(basket).get_global_rect()
		assert_float(rect.end.y).is_less(tag.position.y)
		assert_bool(rect.intersects(tag)).is_false()
	tags._on_all_hover(true)
	# A short draw pile swaps the left items only.
	var run: RunState = screen.run
	var count: int = mini(RunPins.hand_places(run).size(), run.deck.draw_pile().size())
	assert_str(all.text()).is_equal("%s %d" % [BasketTags.ALL_WORD, count])
	var panel: RedrawPanel = screen._monitor.get_node("RedrawPanel") as RedrawPanel
	assert_bool(panel.visible).is_true()


## A click swaps every hand item for one redraw, logged and saved; the baskets play one after
## another (clicks blocked), then redraw mode can be armed again without the tag.
func test_redraw_all_swaps_every_basket_once_a_shift() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	RunPins.wear(run, [load(FULL_REDRAW)])
	var drawn: Array[CardInstance] = run.hand()
	screen._on_redraw_pressed()
	await _frames(2)
	screen._basket_tags.all_clicked.emit()
	var swapped: Array[int] = []
	for place: int in run.hand().size():
		if run.hand()[place] != drawn[place]:
			swapped.append(place)
	assert_int(swapped.size()).is_equal(mini(drawn.size(), 5))
	assert_int(run.redraws_used).is_equal(1)
	assert_bool(run.full_redraw_used).is_true()
	assert_bool(screen._redraw_busy).is_true()
	var event: Dictionary = _last_event("redraw_all")
	var logged: Array = (event["places"] as Array).map(func(p: Variant) -> int: return int(p))
	assert_array(logged).is_equal(Array(swapped))
	var saved: RunSave = SaveService.new(_folder).load_run(ContentLookup.new(run.balance))
	assert_bool(saved.run.full_redraw_used).is_true()
	var tuning: RedrawTuning = screen._basket_redraw.tuning
	var baskets: int = ceili(swapped.size() / 2.0)
	await get_tree().create_timer(tuning.duration(false) * (baskets - 1) + 0.2).timeout
	assert_bool(screen._redraw_busy).is_true()
	await get_tree().create_timer(tuning.duration(false) + 0.2).timeout
	assert_bool(screen._redraw_busy).is_false()
	screen._on_redraw_pressed()
	await _frames(2)
	assert_bool(screen._basket_tags.is_shown()).is_true()
	assert_object(screen._basket_tags.all_tag()).is_null()


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(3)
	return screen


static func _on_stage(screen: ShiftScreen, rect: Rect2) -> Rect2:
	return Rect2(screen._stage.get_global_rect().position + rect.position, rect.size)


func _last_event(type: String) -> Dictionary:
	var lines: PackedStringArray = EventLogWriter.join_logs(_folder).split("\n", false)
	for index: int in range(lines.size() - 1, -1, -1):
		var event: Dictionary = JSON.parse_string(lines[index])
		if event["type"] == type:
			return event
	return {}


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
