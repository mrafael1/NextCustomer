extends GdUnitTestSuite
## The Run info page's pixel art is crisp at 1280x720 and 1920x1080 (the user, 2026-11-13: "icon
## for family inside run info are blurry at 1920*1080p"). The game lays the page out at 1280x720
## and the window scales it by 1 or 1.5 (canvas_items stretch), so on the real shift screen every
## glyph, sprite and pixel mark of the page (the hero's family and aisle glyphs, the MACHINE STOCK
## header plates' glyphs, the stock's sprites, the in-cart badges' and the RARE coupon word's
## pixel marks, the legend's badges) and of a stock icon's tip header: samples its texture sharply
## (the sharp-pixel material, or nearest filtering) with no mipmaps, stands on whole screen pixels
## at both scales (an even layout position), and draws each art pixel as a whole number of screen
## pixels at both scales (2, 4 ... layout px), except the 48 px item sprites, drawn at 1 layout px
## a pixel game-wide (the sharp-pixel material keeps their 1.5 px pixels even at 1080p).

const Cart := preload("res://tests/ui/deck_view_ui_test.gd")
const SCREEN := "res://ui/shift_screen.tscn"
const LAYOUT := Vector2(1280, 720)
## The window's scales: 1280x720 and 1920x1080.
const SCALES: Array[float] = [1.0, 1.5]
const EPSILON := 0.001

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


## Every texture and pixel mark of the Run info page (a full cart with a BIG and a GOLDEN copy,
## so badges carry both marks; the stock with RARE coupons) and of a stock icon's tip header is
## sharp, whole-pixel and whole-scale at both window scales.
func test_run_info_pixel_art_is_crisp_at_both_sizes() -> void:
	var screen: ShiftScreen = await _screen()
	screen.start_new_run(20261014, false)
	screen._week.skip()
	Cart._fill_distinct(screen.run)
	screen._on_deck_button_pressed()
	var view: DeckView = screen._deck_view
	view.show_page(true)
	# The view's opening pop settles.
	await get_tree().create_timer(0.6).timeout
	await _frames(2)
	var grid: StockGrid = view.stock_grid()
	var problems: PackedStringArray = PackedStringArray()
	var seen: Dictionary[String, int] = {}
	_check_textures(view._info_page, problems, seen)
	# The header plates' glyphs, the badges' marks, the RARE word's diamonds.
	assert_int(grid.headers().size()).is_greater_equal(3)
	for header: Control in grid.headers():
		var glyph: TextureRect = (header as StockGrid.Plate).glyph()
		assert_object(glyph).override_failure_message(header.name).is_not_null()
	var badges: int = 0
	var diamonds: int = 0
	var marked: int = 0
	for badge: StockIcon.Badge in _all_of(grid, StockIcon.Badge):
		badges += 1
		var rects: Array[Rect2] = badge.mark_rects()
		marked += 1 if not rects.is_empty() else 0
		_check_rects(badge, rects, "badge %s" % badge.text(), problems)
	for icon: StockIcon in grid.icons():
		var diamond: Array[Rect2] = icon.diamond_pixels()
		diamonds += 1 if not diamond.is_empty() else 0
		_check_rects(icon, diamond, "%s diamond" % icon.name, problems)
	assert_int(badges).is_greater_equal(4)
	assert_int(marked).is_greater_equal(2)
	assert_int(diamonds).override_failure_message("no RARE coupon in the stock").is_greater(0)
	# A stock icon's tip: its header icon.
	view.hover_stock(grid.icons()[0])
	await _frames(2)
	var tip: CardTip = view.tip()
	assert_bool(tip.visible).is_true()
	var tip_icon: TextureRect = tip.find_child("Icon", true, false)
	assert_object(tip_icon).is_not_null()
	# Its item sprite is shrunk into the header's 24 px box (half scale, not a whole one):
	# only its sampling and its place are checked.
	_check_texture(tip_icon, problems, seen, tip_icon.texture.get_size().x <= 24.0)
	assert_int(seen.get("glyph", 0)).is_greater_equal(6)
	assert_int(seen.get("sprite", 0)).is_greater_equal(10)
	assert_array(Array(problems)).override_failure_message("\n".join(problems)).is_empty()


## Each visible TextureRect under `root` (the glyphs, the sprites).
func _check_textures(
	root: Node, problems: PackedStringArray, seen: Dictionary[String, int]
) -> void:
	var item: CanvasItem = root as CanvasItem
	if item != null and not item.is_visible_in_tree():
		return
	if root is TextureRect and (root as TextureRect).texture != null:
		_check_texture(root as TextureRect, problems, seen)
	for child: Node in root.get_children():
		_check_textures(child, problems, seen)


func _check_texture(
	rect: TextureRect,
	problems: PackedStringArray,
	seen: Dictionary[String, int],
	whole_scale: bool = true
) -> void:
	var where: String = str(rect.get_path()).get_slice("DeckView/", 1)
	var texture: Texture2D = rect.texture
	var sharp: bool = (
		rect.material == ArtStyle.pixel_material()
		or rect.has_meta(ArtStyle.LOOK_META)
		or rect.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST
	)
	if not sharp:
		problems.append("%s: not sharp-sampled" % where)
	var image: Image = texture.get_image()
	if image != null and image.has_mipmaps():
		problems.append("%s: mipmaps" % where)
	var to_layout: Transform2D = rect.get_global_transform_with_canvas()
	var texel: Vector2 = rect.size / texture.get_size() * to_layout.get_scale()
	var item: bool = texture.get_size() == Vector2(48, 48)
	seen["sprite" if item else "glyph"] = seen.get("sprite" if item else "glyph", 0) + 1
	for scale: float in SCALES:
		var origin: Vector2 = to_layout.origin * scale
		if not origin.is_equal_approx(origin.round()):
			problems.append("%s: at %s screen px (x%s)" % [where, origin, scale])
		var pixel: Vector2 = texel * scale
		if whole_scale and (scale == 1.0 or not item) and not _whole_size(pixel):
			problems.append("%s: %s screen px a pixel (x%s)" % [where, pixel, scale])


## `rects` (pixel cells in `holder`'s coordinates) on whole screen pixels at both scales.
func _check_rects(
	holder: CanvasItem, rects: Array[Rect2], where: String, problems: PackedStringArray
) -> void:
	var to_layout: Transform2D = holder.get_global_transform_with_canvas()
	for rect: Rect2 in rects:
		for scale: float in SCALES:
			var shown: Rect2 = Transform2D.IDENTITY.scaled(Vector2.ONE * scale) * to_layout * rect
			if not (
				shown.position.is_equal_approx(shown.position.round()) and _whole_size(shown.size)
			):
				problems.append("%s: cell %s at %s (x%s)" % [where, rect, shown, scale])
				return


## A whole number (one at least) of screen px across and down.
static func _whole_size(value: Vector2) -> bool:
	return value.is_equal_approx(value.round()) and minf(value.x, value.y) >= 1.0 - EPSILON


func _all_of(root: Node, type: Variant) -> Array[Node]:
	var found: Array[Node] = []
	for child: Node in root.get_children():
		if is_instance_of(child, type) and (child as CanvasItem).is_visible_in_tree():
			found.append(child)
		found.append_array(_all_of(child, type))
	return found


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(2)
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	screen.size = LAYOUT
	await _frames(3)
	return screen


func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return Engine.get_main_loop().root.get_node("/root/EventLog")
