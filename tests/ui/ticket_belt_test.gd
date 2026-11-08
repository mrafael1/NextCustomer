extends GdUnitTestSuite
## The v5 tickets on a full belt of the real shift screen (tickets v5, V5a), at 1280x720 and at
## 1920x1080 (the stage's 1.5x stretch), for 7 slots, 6 (Short belt) and 9 (Big basket and Extra
## till): every ticket lies on the screen, clear of its neighbours; its price window, glyphs and
## text stay apart inside it; a GOLDEN ring stays on the screen; a gained family's ticket (the
## Price gun) keeps its height, clear of the hand. On an unscaled row at 1920x1080
## every ticket lands on whole screen pixels, so its pixel art stays sharp. The real saves and
## logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const STAGE := Rect2(0, 0, 1280, 720)
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]
## A row of the widest and tallest faces: two-glyph and GOLDEN tickets, a three-line rule, a
## coupon, a split ticket and a card with no rule.
const ROW: Array[String] = [
	"milk_golden",
	"tea_bags_golden",
	"croissant_golden",
	"multipack",
	"cereal",
	"bread",
	"batteries",
	"soup_golden",
	"eggs",
]
## 2026-11-05: a relabelled Banana (one printed family and the gained one) and a Milk with two
## printed families and a gained one (the wide label), their prices and rules still inside them.
const RELABEL_ROW: Array[String] = [
	"banana", "milk", "croissant_golden", "multipack", "eggs", "bread", "cereal"
]
const RELABELS: Dictionary[int, String] = {0: "Snack", 1: "Household"}
const TOLERANCE := 0.01

var _folder: String = ""
var _window_size: Vector2i


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_a_full_belt_of_7() -> void:
	for resolution: Vector2i in RESOLUTIONS:
		await _assert_belt(resolution, [], "", 7)


func test_a_full_belt_of_6() -> void:
	for resolution: Vector2i in RESOLUTIONS:
		await _assert_belt(resolution, [], "short_belt", 6)


func test_a_full_belt_of_9() -> void:
	for resolution: Vector2i in RESOLUTIONS:
		await _assert_belt(resolution, ["big_basket"], "extra_till", 9)


func test_a_relabelled_banana_and_milk_fit() -> void:
	for resolution: Vector2i in RESOLUTIONS:
		await _assert_belt(resolution, [], "", 7, RELABEL_ROW, RELABELS)


func _assert_belt(
	resolution: Vector2i,
	upgrades: Array[String],
	inspection: String,
	slots: int,
	row: Array[String] = ROW,
	relabels: Dictionary[int, String] = {0: "Household"}
) -> void:
	get_tree().root.size = resolution
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(2)
	for upgrade: String in upgrades:
		screen._debug.give_upgrade(upgrade)
	screen._debug.set_inspection(inspection)
	await _frames(2)
	var case: String = "%d slots at %s" % [slots, resolution]
	for id: String in row.slice(0, slots):
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).override_failure_message(case).is_equal(slots)
	await _frames(3)
	# The Price gun's relabels (each glyph joins its label's row).
	for index: int in relabels:
		(screen._row_views[index] as ItemView).sticker().show_gained(relabels[index])
	var first: PriceSticker = (screen._row_views[0] as ItemView).sticker()
	await _frames(2)
	var tickets: Array[Rect2] = []
	var problems: PackedStringArray = PackedStringArray()
	for view: CardView in screen._row_views:
		var ticket: PriceSticker = (view as ItemView).sticker()
		var rect: Rect2 = ticket.get_global_rect()
		var label: String = "%s, %s" % [case, ticket.summary().text]
		if not STAGE.encloses(rect):
			problems.append("%s: ticket %s off the screen" % [label, rect])
		for other: Rect2 in tickets:
			if other.grow(-TOLERANCE).intersects(rect):
				problems.append("%s: ticket %s over %s" % [label, rect, other])
		tickets.append(rect)
		problems.append_array(_inside_problems(ticket, label))
		if ticket.gold_ring() != null and not STAGE.encloses(ticket.gold_ring().get_global_rect()):
			problems.append("%s: gold ring off the screen" % label)
		# Every ticket ends over the hand, a relabelled one too (2026-11-05: one height).
		var foot: float = ShiftStage.HAND_RECT.position.y
		if rect.end.y > foot:
			problems.append("%s: ticket foot %f under %f" % [label, rect.end.y, foot])
	assert_object(first.gained()).is_not_null()
	for index: int in relabels:
		var sticker: PriceSticker = (screen._row_views[index] as ItemView).sticker()
		assert_vector(sticker.size).is_equal(PriceSticker.SIZE)
		var three: bool = sticker.glyphs().size() > PriceSticker.ICONS_PER_ROW
		assert_bool(sticker.is_wide()).override_failure_message(case).is_equal(three)
	if row == RELABEL_ROW:
		assert_bool((screen._row_views[1] as ItemView).sticker().is_wide()).is_true()
	assert_vector(first.size).is_equal(PriceSticker.SIZE)
	if slots <= 7 and resolution != RESOLUTIONS[0]:
		problems.append_array(_grid_problems(screen, case))
	assert_array(problems).override_failure_message("\n".join(problems)).is_empty()


## `ticket`'s zones, global: the window inside the ticket, apart from every glyph and the text.
static func _inside_problems(ticket: PriceSticker, label: String) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var to_global: Transform2D = ticket.get_global_transform()
	var rect: Rect2 = ticket.get_global_rect()
	var window: Rect2 = ticket.window().get_global_rect()
	var text: Rect2 = to_global * ticket.summary_text_rect()
	if not rect.grow(TOLERANCE).encloses(window):
		problems.append("%s: window %s outside %s" % [label, window, rect])
	if not rect.grow(TOLERANCE).encloses(text):
		problems.append("%s: text %s outside %s" % [label, text, rect])
	if window.intersects(text):
		problems.append("%s: window over the text" % label)
	var digits: Rect2 = (
		to_global
		* Rect2(
			ticket.window().position + ticket.window().digits_rect().position,
			ticket.window().digits_rect().size
		)
	)
	if ticket.window().digits_rect().has_area() and not window.grow(TOLERANCE).encloses(digits):
		problems.append("%s: price %s outside its window %s" % [label, digits, window])
	for glyph: FamilyGlyph in ticket.glyphs():
		var rim: Rect2 = to_global * glyph.rim_rect()
		if rim.intersects(window) or rim.intersects(text) or not rect.encloses(rim):
			problems.append("%s: glyph %s out of its label" % [label, glyph.family])
	return problems


## Each ticket's corner on whole screen pixels (the viewport's stretch applied).
func _grid_problems(screen: ShiftScreen, case: String) -> PackedStringArray:
	var problems: PackedStringArray = PackedStringArray()
	var to_screen: Transform2D = get_tree().root.get_final_transform()
	for view: CardView in screen._row_views:
		var ticket: PriceSticker = (view as ItemView).sticker()
		var corner: Vector2 = to_screen * ticket.get_global_position()
		if not corner.is_equal_approx(corner.round()):
			problems.append("%s: ticket at %s off the pixel grid" % [case, corner])
	return problems


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
