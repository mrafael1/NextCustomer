class_name StoreShelves
extends Control
## The back of the store (#80, mock-up B2, step 11): the store sections on the wall between the
## top bar and the counter, B2's 0.5x depth layer, mirrored with the stage (#83). Right to left:
## the cold cases (a steel cabinet with two glass doors, their cool glow spilling onto the wall,
## cheese, milk, eggs, yoghurt pots and juice behind the glass), the bakery shelf (a wood panel
## with two boards, croissants in wicker baskets, round and tin loaves, a bin of baguettes, the
## clock above it; it runs on behind the monitor), the calm wall under the monitor, the fruit &
## veg crate stand with its sign hung on two wires by the cashier, and a painted pillar at the
## left. Only the layout is mirrored: each fixture and sprite keeps its art, lit from the upper
## left. The aisle signs are boards in their aisle's
## sign colour (AisleDefinition.sign_color) with its glyph on a paper tile.
##
## The fixtures are drawn at B2's 1 px texels (plan 6.1.2's changelog: the back layer reads as
## distance), the 48 px item sprites at 1:1; the lights on the wall (the cases' glow spill and the
## warm pool, see wall_light) step on the art's 2 px grid, as B2's do. It is placed like the stage
## (centred in the window, at WALL_RECT), clipped to the wall, and StoreBackdrop lays the warm
## pool and the window-wide wall bands under it and the haze, the cool wall shade, the cashier and
## the lamp over it. Decor only: no part takes a click, so a click on the wall still reaches the
## background.
##
## Positions are the mirrored B2's wall coordinates (stage y - TOP_BAR_BOTTOM; x' = 1280 - x - w
## of B2's), so they read against its mock-up line by line.

## The wall band on the stage: under the top bar, down to the belt's back.
const WALL_RECT := Rect2(
	0, ShiftStage.TOP_BAR_BOTTOM, 1280, ShiftStage.COUNTER_TOP - ShiftStage.TOP_BAR_BOTTOM
)
## The aisles whose signs hang on the wall, by AisleDefinition.id.
const COLD_CASES := &"cold_cases"
const BAKERY := &"bakery"
const FRUIT_AND_VEG := &"fruit_and_veg"
## The signs' boards (wall coordinates), and the x their glyph tile is centred on.
const SIGN_RECTS: Dictionary[StringName, Rect2] = {
	COLD_CASES: Rect2(1044, 22, 232, 38),
	BAKERY: Rect2(848, 58, 190, 36),
	FRUIT_AND_VEG: Rect2(353, 70, 114, 36),
}
const SIGN_ICON_X: Dictionary[StringName, float] = {
	COLD_CASES: 1160.0, BAKERY: 971.0, FRUIT_AND_VEG: 410.0
}
## A sign's lit top and shaded foot: paper and ink over its colour.
const SIGN_LIT := Color(Palette.PAPER, 0.3)
const SIGN_DARK := Color(Palette.INK, 0.3)
## The glyph's paper tile (32 px), the glyph at ICON_SCALE inside it.
const TILE_SIZE := 32.0
const ICON_SCALE := 3.0
const ICON_INSET := 3.0
const ICONS: Dictionary[StringName, Texture2D] = {
	COLD_CASES: preload("res://art/icons/aisle_cold_cases.png"),
	BAKERY: preload("res://art/icons/aisle_bakery.png"),
	FRUIT_AND_VEG: preload("res://art/icons/aisle_fruit_and_veg.png"),
}
## A sign's colour when the run's balance has no such aisle.
const FALLBACK_SIGN := Palette.TEAL

## The cold cases: the cabinet, its two doors (x ranges) and their shelves (y).
const CABINET_RECT := Rect2(1044, 22, 232, 254)
const DOORS: Array[Vector2] = [Vector2(1052, 1158), Vector2(1162, 1268)]
const DOOR_TOP := 64.0
const DOOR_HEIGHT := 214.0
const SHELF_YS: Array[float] = [118.0, 178.0, 238.0]
## The glow behind the glass: three bands, top to bottom (B2's hard-stop gradient).
const GLOW_COLOURS: Array[Color] = [Palette.GLASS_GLOW, Palette.GLASS, Palette.TEAL_LIGHT]
const GLASS_TINT := Color(Palette.GLASS, 0.3)
const GLARE := Color(Palette.PAPER, 0.16)
## The cases' glow on the wall left of them: a stepped ellipse, two alphas.
const SPILL_CENTRE := Vector2(1044, 160)
const SPILL_RADII := Vector2(70, 120)
const SPILL_STEPS: Array[Vector2] = [Vector2(0.9, 0.18), Vector2(0.5, 0.4)]
## The warm light pool under the upper-left light, on the wall plane (wall_light, outside the
## layer's DEPTH_TINT, as B2's pool sits outside its filter): two steps on the 2 px grid, both
## ending above the dado rail, the cornice (POOL_TOP) left clear.
const POOL_CENTRE := Vector2(210, 0)
const POOL_RADII := Vector2(180, 120)
const POOL_STEPS: Array[Vector2] = [Vector2(0.72, 0.21), Vector2(0.44, 0.42)]
const POOL_TOP := 8.0
## The bakery shelf: its panel (x B0..B1), the two boards (y) and the price tickets' pitch.
const BAKERY_LEFT := 852.0
const BAKERY_RIGHT := 1034.0
const BAKERY_TOP := 74.0
const BAKERY_HEIGHT := 200.0
const BOARD_YS: Array[float] = [150.0, 232.0]
const TICKET_PITCH := 28.0
const PANEL_SEAM_PITCH := 34.0
## The fruit & veg stand (x S0..S1), its skirt and the one crate's front.
const STAND_LEFT := 368.0
const STAND_RIGHT := 452.0
const CRATE_RECT := Rect2(374, 186, 72, 24)
## The sign's two wires, from the ceiling to the sign's top.
const WIRE_XS: Array[float] = [381.0, 439.0]
## The painted pillar at the left edge.
const PILLAR_RECT := Rect2(0, 8, 34, 262)

## The sprites, by name, at their wall positions (each drawn 1:1, its top-left here).
const ITEMS := "res://art/items_v2/%s.png"
const SCENERY := "res://art/scenery/%s.png"
## The stock behind the glass and on the stand and the boards, the 48 px items at 1 texel.
const STOCK: Array[Array] = [
	["cheese", Vector2(1215, 70)],
	["milk", Vector2(1167, 70)],
	["eggs", Vector2(1215, 130)],
	["eggs", Vector2(1167, 130)],
	["milk", Vector2(1215, 190)],
	["cheese", Vector2(1167, 190)],
	["milk", Vector2(1105, 70)],
	["cheese", Vector2(1057, 70)],
	["eggs", Vector2(1105, 190)],
	["croissant", Vector2(973, 87)],
	["croissant", Vector2(929, 169)],
	["banana", Vector2(400, 152)],
	["strawberries", Vector2(372, 154)],
]
## The drawn stock (art/src/scenery), behind the front fixtures.
const BACK_SCENERY: Array[Array] = [
	["bread_boule", Vector2(935, 131)],
	["bread_boule", Vector2(901, 131)],
	["bread_tin", Vector2(891, 209)],
	["bread_tin", Vector2(857, 209)],
	["yoghurt_pots", Vector2(1060, 141)],
	["juice_bottles", Vector2(1058, 199)],
]
## Over the front fixtures: the baguette bin, the baskets' fronts and the clock.
const FRONT_SCENERY: Array[Array] = [
	["baguette_bin", Vector2(985, 169)],
	["wicker_basket", Vector2(970, 127)],
	["wicker_basket", Vector2(926, 209)],
	["wall_clock", Vector2(949, 10)],
]

## The cashier (art/src/scenery/cashier.txt) and the lamp, on the stage: StoreBackdrop puts them
## over the haze, the cashier by the receipt behind the counter.
const CASHIER := preload("res://art/scenery/cashier.png")
const CASHIER_RECT := Rect2(290, 182, 76, 144)
const LAMP := preload("res://art/scenery/ceiling_lamp.png")
const LAMP_RECT := Rect2(173, 56, 74, 20)

## The layer's modulate, a multiplier rather than a drawn colour (so a Vector3, not a Color):
## with StoreBackdrop's haze it stands in for B2's filter on the back layer (saturate 0.62,
## brightness 0.94, contrast 0.86), which flat bands can't do without a shader. Fitted to B2's
## render: it greys the warm wood and plaster most and the cool glass least. StoreBackdrop's
## wall bands take it too (depth_modulate), as they sit inside B2's filtered layer.
const DEPTH_TINT := Vector3(0.86, 0.9, 0.95)

## The sign colour of each aisle on the wall (the run's balance, else FALLBACK_SIGN).
var _sign_colours: Dictionary[StringName, Color] = {}


## The wall's sections, their signs in the colours of `aisles` (the run's balance).
func _init(aisles: Array[AisleDefinition] = []) -> void:
	name = "StoreShelves"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	modulate = depth_modulate()
	place(self, WALL_RECT)
	for id: StringName in SIGN_RECTS:
		_sign_colours[id] = FALLBACK_SIGN
	for aisle: AisleDefinition in aisles:
		if aisle != null and _sign_colours.has(aisle.id):
			_sign_colours[aisle.id] = aisle.sign_color
	var back: Control = _layer("Back")
	back.draw.connect(_draw_back.bind(back))
	add_child(_sign(COLD_CASES))
	for entry: Array in STOCK:
		add_child(_sprite(load(ITEMS % entry[0]) as Texture2D, entry[1], entry[0]))
	for entry: Array in BACK_SCENERY:
		add_child(_sprite(load(SCENERY % entry[0]) as Texture2D, entry[1], entry[0]))
	var front: Control = _layer("Front")
	front.draw.connect(_draw_front.bind(front))
	add_child(_sign(BAKERY))
	add_child(_sign(FRUIT_AND_VEG))
	for entry: Array in FRONT_SCENERY:
		add_child(_sprite(load(SCENERY % entry[0]) as Texture2D, entry[1], entry[0]))


## `control` at `rect` (stage coordinates), centred in its parent as the stage is.
static func place(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_CENTER)
	control.offset_left = rect.position.x - ShiftStage.SIZE.x / 2.0
	control.offset_top = rect.position.y - ShiftStage.SIZE.y / 2.0
	control.offset_right = rect.end.x - ShiftStage.SIZE.x / 2.0
	control.offset_bottom = rect.end.y - ShiftStage.SIZE.y / 2.0


## The modulate of the back layer and of the wall bands inside it (DEPTH_TINT).
static func depth_modulate() -> Color:
	return Color(DEPTH_TINT.x, DEPTH_TINT.y, DEPTH_TINT.z)


## The warm light pool on the bare wall plane, untinted: a layer at WALL_RECT, centred in the
## window with the stage, that StoreBackdrop puts under the wall bands and the sections.
static func wall_light() -> Control:
	var light: Control = Control.new()
	light.name = "WallLight"
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light.clip_contents = true
	place(light, WALL_RECT)
	light.draw.connect(
		func() -> void:
			_stepped_ellipse(
				light, POOL_CENTRE, POOL_RADII, POOL_STEPS, Palette.MUSTARD_PALE, POOL_TOP
			)
	)
	return light


## A stage sprite (the cashier or the lamp) at `rect`, centred in the window with the stage.
static func stage_sprite(texture: Texture2D, rect: Rect2, sprite_name: String) -> TextureRect:
	var sprite: TextureRect = UiKit.sprite(texture)
	sprite.name = sprite_name
	place(sprite, rect)
	return sprite


## The colour the sign of aisle `id` is painted in.
func sign_colour(id: StringName) -> Color:
	if _sign_colours.has(id):
		return _sign_colours[id]
	return FALLBACK_SIGN


func _layer(layer_name: String) -> Control:
	var layer: Control = Control.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.size = WALL_RECT.size
	add_child(layer)
	return layer


func _sprite(texture: Texture2D, at: Vector2, sprite_name: String) -> TextureRect:
	var sprite: TextureRect = UiKit.sprite(texture)
	sprite.name = sprite_name.to_pascal_case()
	sprite.position = at
	sprite.size = Vector2(texture.get_size())
	return sprite


## An aisle sign: a board in the aisle's colour in ink, lit along its top and shaded along its
## foot, its glyph on a paper tile in ink.
func _sign(id: StringName) -> Control:
	var board: Rect2 = SIGN_RECTS[id]
	var sign_node: Control = Control.new()
	sign_node.name = "Sign" + String(id).to_pascal_case()
	sign_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sign_node.position = board.position
	sign_node.size = board.size
	var local: Rect2 = Rect2(Vector2.ZERO, board.size)
	_box_nodes(sign_node, local, sign_colour(id), "Board")
	_rect_node(sign_node, Rect2(1, 1, board.size.x - 2, 2), SIGN_LIT, "Lit")
	_rect_node(sign_node, Rect2(1, board.size.y - 4, board.size.x - 2, 3), SIGN_DARK, "Shade")
	var tile: Rect2 = Rect2(
		SIGN_ICON_X[id] - board.position.x - TILE_SIZE / 2.0,
		roundf((board.size.y - TILE_SIZE) / 2.0),
		TILE_SIZE,
		TILE_SIZE
	)
	_box_nodes(sign_node, tile, Palette.PAPER, "Tile")
	var icon: TextureRect = UiKit.sprite(ICONS[id])
	icon.name = "Glyph"
	icon.position = tile.position + Vector2.ONE * ICON_INSET
	icon.size = Vector2(ICONS[id].get_size()) * ICON_SCALE
	sign_node.add_child(icon)
	return sign_node


## B2's stroked rect: `rect` in `fill` with a 2 px ink stroke on its edge (1 px out, 1 px in).
static func _box_nodes(parent: Control, rect: Rect2, fill: Color, part: String) -> void:
	_rect_node(parent, rect.grow(1), Palette.INK, part + "Ink")
	_rect_node(parent, rect.grow(-1), fill, part)


static func _rect_node(parent: Control, rect: Rect2, colour: Color, part: String) -> void:
	var band: ColorRect = ColorRect.new()
	band.name = part
	band.color = colour
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.position = rect.position
	band.size = rect.size
	parent.add_child(band)


## The fixtures' backs: the cases' glow spill on the wall, the cold-case cabinet with its doors'
## glow and shelves, the bakery panel, the fruit & veg stand and the pillar.
func _draw_back(canvas: Control) -> void:
	_stepped_ellipse(canvas, SPILL_CENTRE, SPILL_RADII, SPILL_STEPS, Palette.GLASS, 0.0)
	_box(canvas, CABINET_RECT, Palette.STEEL_PALE)
	for door: Vector2 in DOORS:
		var width: float = door.y - door.x
		_box(canvas, Rect2(door.x, DOOR_TOP, width, DOOR_HEIGHT), Palette.STEEL)
		var glass: Rect2 = Rect2(door.x + 5, DOOR_TOP + 5, width - 10, DOOR_HEIGHT - 5)
		var band_height: float = roundf(glass.size.y * 0.34)
		for index: int in GLOW_COLOURS.size():
			var top: float = glass.position.y + band_height * index
			var bottom: float = (
				glass.end.y if index == GLOW_COLOURS.size() - 1 else top + band_height
			)
			canvas.draw_rect(
				Rect2(glass.position.x, top, glass.size.x, bottom - top), GLOW_COLOURS[index]
			)
		canvas.draw_rect(Rect2(glass.position, Vector2(glass.size.x, 4)), Palette.PAPER)
		for shelf: float in SHELF_YS:
			canvas.draw_rect(Rect2(glass.position.x, shelf, glass.size.x, 2), Palette.PAPER)
			canvas.draw_rect(
				Rect2(glass.position.x, shelf + 2, glass.size.x, 2), Palette.TEAL_LIGHT
			)
	var panel: Rect2 = Rect2(BAKERY_LEFT, BAKERY_TOP, BAKERY_RIGHT - BAKERY_LEFT, BAKERY_HEIGHT)
	canvas.draw_rect(panel, Palette.WOOD)
	var seam: float = BAKERY_LEFT + PANEL_SEAM_PITCH
	while seam < BAKERY_RIGHT:
		canvas.draw_rect(Rect2(seam, BAKERY_TOP, 2, BAKERY_HEIGHT), Color(Palette.INK, 0.15))
		seam += PANEL_SEAM_PITCH
	canvas.draw_rect(Rect2(panel.position, Vector2(panel.size.x, 6)), Color(Palette.INK, 0.25))
	var stand_width: float = STAND_RIGHT - STAND_LEFT
	_box(canvas, Rect2(STAND_LEFT + 2, 162, stand_width - 4, 110), Palette.WOOD_DARK)
	_box(canvas, Rect2(STAND_LEFT + 4, 210, stand_width - 8, 62), Palette.GREEN_DARK)
	canvas.draw_rect(Rect2(STAND_LEFT + 5, 211, stand_width - 10, 2), Palette.GOOD)
	canvas.draw_rect(Rect2(STAND_LEFT + 4, 210, stand_width - 8, 4), Color(Palette.INK, 0.35))
	var slat: float = STAND_LEFT + 26
	while slat < STAND_RIGHT - 10:
		canvas.draw_rect(Rect2(slat, 216, 2, 56), Color(Palette.INK, 0.25))
		slat += 22
	canvas.draw_rect(PILLAR_RECT, Palette.CREAM_SHADE)
	canvas.draw_rect(
		Rect2(PILLAR_RECT.position, Vector2(3, PILLAR_RECT.size.y)), Palette.PLASTER_LIGHT
	)
	canvas.draw_rect(
		Rect2(PILLAR_RECT.position, Vector2(1, PILLAR_RECT.size.y)), Palette.PLASTER_DARK
	)


## The fixtures' fronts: the cases' glass (a cool tint, a glare streak and a handle per door),
## the bakery's uprights and boards with their price strips, the fruit & veg sign's wires and
## the crate's front with its price card.
func _draw_front(canvas: Control) -> void:
	for door: Vector2 in DOORS:
		var x0: float = door.x
		canvas.draw_rect(
			Rect2(x0 + 5, DOOR_TOP + 5, door.y - door.x - 10, DOOR_HEIGHT - 5), GLASS_TINT
		)
		var glare: PackedVector2Array = [
			Vector2(x0 + 26, 73),
			Vector2(x0 + 40, 73),
			Vector2(x0 + 18, 168),
			Vector2(x0 + 5, 168),
			Vector2(x0 + 5, 160),
		]
		canvas.draw_colored_polygon(glare, GLARE)
		_box(canvas, Rect2(x0 + 8, 120, 4, 76), Palette.STEEL_HIGHLIGHT)
	_box(canvas, Rect2(BAKERY_LEFT, BAKERY_TOP, 6, BAKERY_HEIGHT), Palette.WOOD_DARK)
	_box(canvas, Rect2(BAKERY_RIGHT - 6, BAKERY_TOP, 6, BAKERY_HEIGHT), Palette.WOOD_DARK)
	var board_width: float = BAKERY_RIGHT - BAKERY_LEFT - 12
	for board: float in BOARD_YS:
		canvas.draw_rect(Rect2(BAKERY_LEFT + 6, board - 3, board_width, 3), Palette.WOOD_PALE)
		_box(canvas, Rect2(BAKERY_LEFT + 6, board, board_width, 10), Palette.WOOD)
		canvas.draw_rect(Rect2(BAKERY_LEFT + 7, board + 2, board_width - 2, 6), Palette.CREAM)
		var ticket: float = BAKERY_LEFT + 14
		while ticket < BAKERY_RIGHT - 14:
			canvas.draw_rect(Rect2(ticket, board + 2, 12, 6), Palette.PAPER)
			canvas.draw_rect(Rect2(ticket, board + 2, 12, 1), Palette.TOMATO)
			ticket += TICKET_PITCH
	var sign_top: float = SIGN_RECTS[FRUIT_AND_VEG].position.y
	for wire: float in WIRE_XS:
		canvas.draw_rect(Rect2(wire - 1, 8, 2, sign_top - 8), Palette.STEEL_DARK)
	var crate: Rect2 = CRATE_RECT
	_box(canvas, crate, Palette.WOOD_LIGHT)
	var inner: float = crate.size.x - 2
	canvas.draw_rect(Rect2(crate.position.x + 1, crate.position.y + 1, inner, 2), Palette.WOOD_PALE)
	for row: float in [8.0, 16.0]:
		canvas.draw_rect(
			Rect2(crate.position.x + 1, crate.position.y + row, inner, 2), Palette.BROWN_DARK
		)
	canvas.draw_rect(Rect2(crate.position + Vector2(1, 1), Vector2(5, 22)), Palette.WOOD)
	canvas.draw_rect(Rect2(crate.end.x - 6, crate.position.y + 1, 5, 22), Palette.WOOD)
	var card: Rect2 = Rect2(
		crate.position.x + (crate.size.x - 18) / 2.0, crate.position.y + 7, 18, 11
	)
	canvas.draw_rect(card, Palette.INK)
	canvas.draw_rect(card.grow(-1), Palette.PAPER)
	canvas.draw_rect(Rect2(card.position + Vector2(1, 1), Vector2(16, 2)), Palette.TOMATO)


## B2's stroked rect on `canvas`: `rect` in `fill` with a 2 px ink stroke on its edge.
static func _box(canvas: CanvasItem, rect: Rect2, fill: Color) -> void:
	canvas.draw_rect(rect.grow(1), Palette.INK)
	canvas.draw_rect(rect.grow(-1), fill)


## A light on the wall: an ellipse at `centre` with `radii`, drawn in 2 px texel rows of
## `colour` from `top` down. Each step is a ring (x the fraction of the radii it reaches, y its
## alpha), outermost first; a texel takes the alpha of the innermost step it lies in, never two.
static func _stepped_ellipse(
	canvas: CanvasItem,
	centre: Vector2,
	radii: Vector2,
	steps: Array[Vector2],
	colour: Color,
	top: float
) -> void:
	var texel: float = ArtStyle.ART_SCALE
	var row: float = maxf(floorf((centre.y - radii.y) / texel) * texel, top)
	while row < minf(centre.y + radii.y, WALL_RECT.size.y):
		var height: float = (row + texel / 2.0 - centre.y) / radii.y
		var spans: Array[Vector2] = []
		for step: Vector2 in steps:
			spans.append(_span(centre.x, radii.x, height, step.x, texel))
		for index: int in steps.size():
			var span: Vector2 = spans[index]
			var hole: Vector2 = spans[index + 1] if index + 1 < spans.size() else Vector2.ZERO
			var tint: Color = Color(colour, steps[index].y)
			if hole.y <= hole.x:
				_row(canvas, span.x, span.y, row, texel, tint)
			else:
				_row(canvas, span.x, hole.x, row, texel, tint)
				_row(canvas, hole.y, span.y, row, texel, tint)
		row += texel


## The texels (left and right edges) of a row at `height` (a fraction of the radius from the
## centre) that lie inside an ellipse ring reaching `fraction` of its radii: an empty span when
## none do.
static func _span(
	centre_x: float, radius_x: float, height: float, fraction: float, texel: float
) -> Vector2:
	var reach: float = height / fraction
	if absf(reach) >= 1.0:
		return Vector2.ZERO
	var half: float = radius_x * fraction * sqrt(1.0 - reach * reach)
	return Vector2(
		roundf((centre_x - half) / texel) * texel, roundf((centre_x + half) / texel) * texel
	)


static func _row(
	canvas: CanvasItem, left: float, right: float, row: float, texel: float, tint: Color
) -> void:
	if right > left:
		canvas.draw_rect(Rect2(left, row, right - left, texel), tint)
