extends GdUnitTestSuite
## The back of the store (#80, mock-up B2, step 11): the wall's bands, the store sections
## (StoreShelves), the haze, the cashier, the cool wall shade and the lamp. The wall and its
## bands cover the window at every size, the sections, the cashier and the lamp sit at their
## stage rects with the stage, every part sits behind the stage (so never over the belt, the
## monitor, the receipt, the top bar or the keys) and takes no click, a click on the bare wall
## still reaches the background handler, the sprites are drawn at 1 texel (B2's 0.5x depth) and
## the signs are painted in their aisles' colours. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const BALANCE := "res://data/balance/balance.tres"
const WINDOWS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080), Vector2(1600, 720)]
## The backdrop's parts, back to front (the top band is StoreBackdrop.top_parts', over the camera
## since #77 machine v2).
const ORDER: Array[String] = [
	"Wall",
	"WallLight",
	"Cornice",
	"CorniceEdge",
	"LowerWall",
	"DadoRail",
	"DadoLight",
	"LowerShade",
	"StoreShelves",
	"Haze",
	"Cashier",
	"WallShade",
	"Lamp",
]
## The window-wide wall bands and their spans (B2's wall coordinates).
const BANDS: Dictionary[String, Vector2] = {
	"Cornice": StoreBackdrop.CORNICE,
	"CorniceEdge": StoreBackdrop.CORNICE_EDGE,
	"LowerWall": StoreBackdrop.LOWER_WALL,
	"DadoRail": StoreBackdrop.DADO_RAIL,
	"DadoLight": StoreBackdrop.DADO_LIGHT,
	"LowerShade": StoreBackdrop.LOWER_SHADE,
	"Haze": Vector2(0, 270),
	"WallShade": Vector2(0, 270),
}
## Points on the stage over decor only: the cold cases, the idle machine on the back wall (#77
## machine v2: it takes no click between visits), the fruit & veg stand, the cashier, the lamp,
## the pillar and the bare wall under the monitor (above the slots' drop targets, which reach up
## over a standing item's art).
const DECOR_POINTS: Array[Vector2] = [
	Vector2(1220, 200),
	Vector2(1060, 200),
	Vector2(410, 270),
	Vector2(328, 250),
	Vector2(210, 64),
	Vector2(18, 200),
	Vector2(700, 274),
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
## wall covers the window; the wall's bands, the haze and the shade span its width at their
## heights on the stage; the store sections and the warm pool fill the wall band of the centred
## stage, the pool untinted and the wall's bands in the sections' depth tint (as in B2's filtered
## back layer), and the cashier and the lamp stand at their stage rects; the parts are in order.
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
		# The wall runs past the window's right edge, for the camera at the machine (#77 v2).
		var wall_rect: Rect2 = wall.get_global_rect()
		assert_vector(wall_rect.position).is_equal(bounds.position)
		assert_vector(wall_rect.size).is_equal(bounds.size + Vector2(StoreBackdrop.WORLD_EXTRA, 0))
		for part_name: String in BANDS:
			var band: Rect2 = (window.get_node(part_name) as Control).get_global_rect()
			var span: Vector2 = BANDS[part_name] + Vector2.ONE * ShiftStage.TOP_BAR_BOTTOM
			assert_float(band.position.x).is_less_equal(bounds.position.x)
			assert_float(band.end.x).is_greater_equal(bounds.end.x)
			assert_float(band.position.y).is_equal(origin.y + span.x)
			assert_float(band.end.y).is_equal(origin.y + span.y)
		var shelves: StoreShelves = window.get_node("StoreShelves") as StoreShelves
		assert_that(shelves.get_global_rect()).is_equal(
			Rect2(origin + StoreShelves.WALL_RECT.position, StoreShelves.WALL_RECT.size)
		)
		assert_bool(shelves.clip_contents).is_true()
		var light: Control = window.get_node("WallLight") as Control
		assert_that(light.get_global_rect()).is_equal(shelves.get_global_rect())
		assert_that(light.modulate).is_equal(Color.WHITE)
		for part_name: String in BANDS:
			var tint: Color = (window.get_node(part_name) as Control).modulate
			var tinted: bool = part_name != "Haze" and part_name != "WallShade"
			var expected: Color = StoreShelves.depth_modulate() if tinted else Color.WHITE
			assert_that(tint).override_failure_message(part_name).is_equal(expected)
		for part_name: String in ["Cashier", "Lamp"]:
			var sprite: TextureRect = window.get_node(part_name) as TextureRect
			var rect: Rect2 = (
				StoreShelves.CASHIER_RECT if part_name == "Cashier" else StoreShelves.LAMP_RECT
			)
			assert_that(sprite.get_global_rect()).is_equal(Rect2(origin + rect.position, rect.size))
			assert_that(Vector2(sprite.texture.get_size())).is_equal(rect.size)
		for index: int in ORDER.size():
			assert_int(window.get_node(ORDER[index]).get_index()).is_equal(index)
		window.queue_free()


## Every part of the backdrop, its sections' every node too, takes no click, apart from the wall;
## the parts are all behind the stage, and the stage draws the monitor, the receipt, the belt,
## the register and the top bar. On decor (the cases, the idle machine, the stand, the cashier,
## the lamp, the pillar, the bare wall) a click reaches the wall, and a press there lets go of a
## picked item (the background handler). Since #77 machine v2 the backdrop is in the store's
## camera, behind the stage's world; the top band is over the camera, under the stage's hud.
func test_decor_takes_no_clicks_and_sits_behind_the_stage() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
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
	for part_name: String in ["StoreShelves", "Cashier", "Lamp", "Haze", "WallShade"]:
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


## The sections' parts at their wall positions: the item sprites and the drawn stock at 1 texel
## (each as big as its texture, inside the wall), and the three signs at their boards, each in
## its aisle's sign colour with the aisle's glyph at ICON_SCALE on a paper tile inside the board.
## The cashier stands by the receipt, clear of it and of the monitor, her foot behind the belt.
func test_the_parts_at_their_rects() -> void:
	var aisles: Array[AisleDefinition] = _aisles()
	var shelves: StoreShelves = auto_free(StoreShelves.new(aisles))
	var wall: Rect2 = Rect2(Vector2.ZERO, StoreShelves.WALL_RECT.size)
	var entries: Array[Array] = []
	entries.append_array(StoreShelves.STOCK)
	entries.append_array(StoreShelves.BACK_SCENERY)
	entries.append_array(StoreShelves.FRONT_SCENERY)
	var sprites: Array[TextureRect] = []
	for child: Node in shelves.get_children():
		if child is TextureRect:
			sprites.append(child as TextureRect)
	assert_int(sprites.size()).is_equal(entries.size())
	for index: int in entries.size():
		var sprite: TextureRect = sprites[index]
		var texture: Texture2D = sprite.texture
		assert_str(texture.resource_path.get_file().get_basename()).is_equal(entries[index][0])
		assert_that(sprite.position).is_equal(entries[index][1])
		assert_that(sprite.size).is_equal(Vector2(texture.get_size()))
		assert_bool(wall.encloses(sprite.get_rect())).override_failure_message(str(index)).is_true()
	for aisle: AisleDefinition in aisles:
		if not StoreShelves.SIGN_RECTS.has(aisle.id):
			continue
		var board: Rect2 = StoreShelves.SIGN_RECTS[aisle.id]
		var sign_node: Control = shelves.get_node("Sign" + String(aisle.id).to_pascal_case())
		assert_that(sign_node.get_rect()).is_equal(board)
		assert_that((sign_node.get_node("Board") as ColorRect).color).is_equal(aisle.sign_color)
		assert_that((sign_node.get_node("BoardInk") as ColorRect).color).is_equal(Palette.INK)
		var tile: ColorRect = sign_node.get_node("Tile") as ColorRect
		assert_that(tile.color).is_equal(Palette.PAPER)
		var glyph: TextureRect = sign_node.get_node("Glyph") as TextureRect
		assert_object(glyph.texture).is_same(StoreShelves.ICONS[aisle.id])
		var glyph_size: Vector2 = Vector2(glyph.texture.get_size()) * StoreShelves.ICON_SCALE
		assert_that(glyph.size).is_equal(glyph_size)
		assert_bool(tile.get_rect().grow(1).encloses(glyph.get_rect())).is_true()
		assert_bool(Rect2(Vector2.ZERO, board.size).encloses(tile.get_rect())).is_true()
	var cashier: Rect2 = StoreShelves.CASHIER_RECT
	assert_float(cashier.position.x).is_greater_equal(
		ShiftStage.RECEIPT_X + ShiftStage.RECEIPT_WIDTH
	)
	assert_bool(cashier.intersects(ShiftStage.MONITOR_RECT)).is_false()
	assert_float(cashier.end.y).is_greater_equal(ShiftStage.BELT_RECT.position.y)
	assert_float(StoreShelves.LAMP_RECT.position.y).is_equal(ShiftStage.TOP_BAR_BOTTOM)


## Without the run's aisles the signs keep a palette colour.
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
