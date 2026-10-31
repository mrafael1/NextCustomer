extends GdUnitTestSuite
## The back of the store (#123, mock-up docs/art/mockups/scene_123.html, direction A; it replaced
## #80's B2 wall): the far wall, the store (StoreShelves: StoreArt's painted store, the pendant
## lamps and the aisle signs), the counter and the floor. The wall covers the window at every size,
## the store sits at its stage rect with the stage, every part sits behind the stage (so never over
## the belt, the monitor, the receipt, the top bar or the keys) and takes no click, a click on the
## store still reaches the background handler, the painted store keeps to the palette and is lit
## only under the lamps, and the signs are painted in their aisles' colours. The real saves and
## logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const BALANCE := "res://data/balance/balance.tres"
const PALETTE_FILE := "res://art/src/palette.txt"
const WINDOWS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080), Vector2(1600, 720)]
## The backdrop's parts, back to front (the top band is StoreBackdrop.top_parts', over the camera
## since #77 machine v2).
const ORDER: Array[String] = ["Wall", "StoreShelves", "Counter", "Floor"]
## Points on the stage over decor only: the storefront glass, the shelving under the hung sign, a
## pendant lamp, the shelving between the receipt and the monitor, the ceiling over the receipt
## and the store under the monitor (above the slots' drop targets, which reach up over a standing
## item's art).
const DECOR_POINTS: Array[Vector2] = [
	Vector2(1180, 150),
	Vector2(1100, 230),
	Vector2(990, 76),
	Vector2(440, 220),
	Vector2(160, 62),
	Vector2(700, 262),
]

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_store_shelves_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## In each window (the stage's size, a bigger one and a wider one, with letterbox bands): the
## wall covers the window and runs on past its right edge for the camera at the machine; the store
## fills its band of the centred stage, from left of the stage to ShiftStage.WORLD_RIGHT; the
## counter's laminate starts at the belt's back and the floor at the ledge's foot, both spanning
## the window; the parts are in order.
func test_the_wall_covers_the_window_at_every_size() -> void:
	for window_size: Vector2 in WINDOWS:
		var window: Control = auto_free(Control.new())
		window.size = window_size
		add_child(window)
		var wall: ColorRect = StoreBackdrop.screen_parts(window, _aisles())
		var stage: ShiftStage = ShiftStage.new(7)
		window.add_child(stage)
		await _frames(2)
		var bounds: Rect2 = window.get_global_rect()
		var origin: Vector2 = stage.get_global_rect().position
		var wall_rect: Rect2 = wall.get_global_rect()
		assert_vector(wall_rect.position).is_equal(bounds.position)
		assert_vector(wall_rect.size).is_equal(bounds.size + Vector2(StoreBackdrop.WORLD_EXTRA, 0))
		var shelves: StoreShelves = window.get_node("StoreShelves") as StoreShelves
		assert_that(shelves.get_global_rect()).is_equal(
			Rect2(origin + StoreShelves.WALL_RECT.position, StoreShelves.WALL_RECT.size)
		)
		assert_bool(shelves.clip_contents).is_true()
		assert_float(StoreShelves.WALL_RECT.end.x).is_equal(ShiftStage.WORLD_RIGHT)
		assert_float(StoreShelves.WALL_RECT.end.y).is_equal(ShiftStage.COUNTER_TOP)
		for band_name: String in ["Counter", "Floor"]:
			var band: Rect2 = (window.get_node(band_name) as Control).get_global_rect()
			var top: float = (
				ShiftStage.COUNTER_TOP if band_name == "Counter" else ShiftStage.FLOOR_TOP
			)
			assert_float(band.position.x).is_less_equal(bounds.position.x)
			assert_float(band.end.x).is_greater_equal(bounds.end.x)
			assert_float(band.position.y).is_equal(origin.y + top)
			assert_float(band.end.y).is_equal(bounds.end.y)
		for index: int in ORDER.size():
			assert_int(window.get_node(ORDER[index]).get_index()).is_equal(index)
		window.queue_free()


## Every part of the backdrop, the store's every node too, takes no click, apart from the wall;
## the parts are all behind the stage, and the stage draws the monitor, the receipt, the belt,
## the register and the top bar. On decor (the glass, the shelving, a lamp, the ceiling, the store
## under the monitor) a click reaches the wall, and a press there lets go of a picked item (the
## background handler). Since #77 machine v2 the backdrop is in the store's
## camera, behind the stage's world; the top band is over the camera, under the stage's hud.
func test_decor_takes_no_clicks_and_sits_behind_the_stage() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()  # The time card (v0.70) stays out of the way.
	await _frames(3)
	var stage: ShiftStage = screen._stage
	var wall: Control = screen._wall
	assert_str(String(wall.name)).is_equal("Wall")
	var content: Control = screen._camera.content
	for part: Node in content.get_children():
		if part != wall and part != stage.world:
			_assert_ignores_clicks(part)
	for index: int in range(0, stage.get_index()):
		var over: Control = screen.get_child(index) as Control
		assert_int(over.mouse_filter).override_failure_message(str(over.name)).is_equal(
			Control.MOUSE_FILTER_IGNORE
		)
	for part_name: String in ["StoreShelves", "Counter", "Floor"]:
		assert_int(content.get_node(part_name).get_index()).is_less(stage.world.get_index())
	# The monitor, the receipt, the belt and the register are in the stage's world (zoomed with
	# the camera, #77 machine v2), the top bar on its hud.
	for front: Control in [stage.monitor, stage.receipt, stage.belt, stage.cabinet]:
		(
			assert_bool(stage.world.is_ancestor_of(front))
			. override_failure_message(str(front.name))
			. is_true()
		)
	assert_bool(stage.is_ancestor_of(stage.top_bar)).is_true()
	var origin: Vector2 = stage.get_global_rect().position
	for point: Vector2 in DECOR_POINTS:
		var hit: Control = _topmost_at(screen, origin + point)
		assert_object(hit).override_failure_message(str(point)).is_same(wall)
	var card: CardInstance = screen.run.hand()[0]
	screen._pick(card, false)
	assert_object(screen._picked).is_same(card)
	# Headless runs move no real pointer, so the press goes where the GUI would send it.
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = origin + DECOR_POINTS[0]
	_topmost_at(screen, press.position).gui_input.emit(press)
	await _frames(1)
	assert_object(screen._picked).is_null()


## The store's parts at their rects: the painted store fills the band at 2x (StoreArt's art px
## at ArtStyle.ART_SCALE), a pendant lamp hangs over each of its cones on a cord from the top bar's
## foot, and the two signs hang at their boards, each in its aisle's sign colour with the aisle's
## glyph at ICON_SCALE on a paper tile inside the board, clear of the monitor.
func test_the_parts_at_their_rects() -> void:
	var aisles: Array[AisleDefinition] = _aisles()
	var shelves: StoreShelves = auto_free(StoreShelves.new(aisles))
	var store: TextureRect = shelves.get_node("Store") as TextureRect
	assert_that(store.get_rect()).is_equal(Rect2(Vector2.ZERO, StoreShelves.WALL_RECT.size))
	assert_that(Vector2(store.texture.get_size()) * ArtStyle.ART_SCALE).is_equal(
		StoreShelves.WALL_RECT.size
	)
	var lamps: Array[TextureRect] = []
	for child: Node in shelves.get_children():
		if child is TextureRect and child != store:
			lamps.append(child as TextureRect)
	var rects: Array[Rect2] = StoreShelves.lamp_rects()
	assert_int(lamps.size()).is_equal(rects.size())
	for index: int in rects.size():
		var expected: Rect2 = rects[index]
		expected.position -= StoreShelves.WALL_RECT.position
		assert_that(lamps[index].get_rect()).is_equal(expected)
		assert_float(rects[index].position.y).is_equal(StoreShelves.LAMP_TOP)
	for aisle: AisleDefinition in aisles:
		if not StoreShelves.SIGN_RECTS.has(aisle.id):
			continue
		var board: Rect2 = StoreShelves.SIGN_RECTS[aisle.id]
		assert_bool(board.intersects(ShiftStage.MONITOR_RECT)).is_false()
		var sign_node: Control = shelves.get_node("Sign" + String(aisle.id).to_pascal_case())
		var top: float = board.position.y - ShiftStage.TOP_BAR_BOTTOM
		var face: ColorRect = sign_node.get_node("Board") as ColorRect
		assert_that(face.get_rect()).is_equal(Rect2(Vector2(0, top), board.size))
		assert_that(face.color).is_equal(aisle.sign_color)
		var tile: ColorRect = sign_node.get_node("Tile") as ColorRect
		assert_that(tile.color).is_equal(Palette.PAPER)
		var glyph: TextureRect = sign_node.get_node("Glyph") as TextureRect
		assert_object(glyph.texture).is_same(StoreShelves.ICONS[aisle.id])
		var glyph_size: Vector2 = Vector2(glyph.texture.get_size()) * StoreShelves.ICON_SCALE
		assert_that(glyph.size).is_equal(glyph_size)
		assert_bool(tile.get_rect().encloses(glyph.get_rect())).is_true()
		assert_bool(face.get_rect().encloses(tile.get_rect())).is_true()


## The painted store keeps to the palette, and its lit colours show only under a lamp: a pixel
## outside every cone is unlit (the far wall's teal darkest), one at a cone's heart is lit.
func test_the_store_is_palette_coloured_and_lit_under_the_lamps() -> void:
	var palette: Dictionary[String, bool] = {}
	for line: String in FileAccess.get_file_as_string(PALETTE_FILE).split("\n"):
		var fields: PackedStringArray = line.split(" ", false)
		if fields.size() >= 2 and not line.begins_with(";") and fields[1].length() == 6:
			palette[fields[1]] = true
	var image: Image = StoreArt.paint()
	var seen: Dictionary[String, bool] = {}
	for y: int in image.get_height():
		for x: int in image.get_width():
			seen[image.get_pixel(x, y).to_html(false)] = true
	for colour: String in seen:
		assert_bool(palette.has(colour)).override_failure_message(colour).is_true()
	# The far wall between the glass's sill and the shelving's top, away from every lamp...
	var dark_at: Vector2i = Vector2i(0 - StoreArt.LEFT, StoreArt.GLASS_TOP - 4 - StoreArt.TOP)
	assert_float(StoreArt.light_at(0, StoreArt.GLASS_TOP - 4)).is_equal(0.0)
	assert_that(image.get_pixelv(dark_at)).is_equal(Palette.BACKGROUND)
	# ...and right under a lamp, where the wall takes its lit teal.
	var lamp_x: int = StoreArt.LAMP_XS[0]
	assert_float(StoreArt.light_at(lamp_x, StoreArt.CEILING_FOOT + 2)).is_greater(1.0)
	var lit_at: Vector2i = Vector2i(
		lamp_x - StoreArt.LEFT, StoreArt.CEILING_FOOT + 2 - StoreArt.TOP
	)
	assert_that(image.get_pixelv(lit_at)).is_equal(Palette.PANEL)


func test_a_sign_without_its_aisle_keeps_a_palette_colour() -> void:
	var shelves: StoreShelves = auto_free(StoreShelves.new())
	for id: StringName in StoreShelves.SIGN_RECTS:
		assert_that(shelves.sign_colour(id)).is_equal(StoreShelves.FALLBACK_SIGN)


## `node` and everything under it take no click.
func _assert_ignores_clicks(node: Node) -> void:
	var control: Control = node as Control
	if control != null:
		assert_int(control.mouse_filter).override_failure_message(str(control.get_path())).is_equal(
			Control.MOUSE_FILTER_IGNORE
		)
	for child: Node in node.get_children():
		_assert_ignores_clicks(child)


static func _aisles() -> Array[AisleDefinition]:
	return (load(BALANCE) as BalanceDefinition).aisles


## The control a click at `point` reaches, picked as the GUI does: the last drawn visible
## control under the point that doesn't ignore the mouse (children over their parent, later
## siblings over earlier ones), or null.
static func _topmost_at(node: Node, point: Vector2) -> Control:
	for index: int in range(node.get_child_count() - 1, -1, -1):
		var child: Node = node.get_child(index)
		var item: CanvasItem = child as CanvasItem
		if item != null and not item.visible:
			continue
		var disabled: Control = child as Control
		if (
			disabled != null
			and disabled.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED
		):
			continue
		var found: Control = _topmost_at(child, point)
		if found != null:
			return found
	var control: Control = node as Control
	if (
		control != null
		and control.mouse_filter != Control.MOUSE_FILTER_IGNORE
		and control.get_global_rect().has_point(point)
	):
		return control
	return null


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
