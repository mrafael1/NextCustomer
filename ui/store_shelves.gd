class_name StoreShelves
extends Control
## The back of the store (#123, mock-up docs/art/mockups/scene_123.html, direction A; it replaces
## #80's B2 wall): the painted store (StoreArt: the ceiling, the far wall, the storefront glass
## with the evening outside and the run of shelving, lit in pools under the pendant lamps), the
## pendant lamps hung on their cords over it, and two aisle signs hung from the ceiling on the
## right, where the scene is open. The store has no ink outlines and sits a value step under the
## UI, so the items, the stickers and the tickets come forward on their own; the cashier, the
## produce stand, the cold cases and the RECEIPT REWARDS machine are gone from the planning view
## (the machine has its own camera stop, ShiftStage.MACHINE_WALL_RECT).
##
## The signs are boards in their aisle's sign colour (AisleDefinition.sign_color) with its glyph
## on a paper tile. It is placed like the stage (centred in the window) at WALL_RECT, which runs
## from left of the stage (a letterbox band shows more store) to as far right as the camera at the
## machine shows (ShiftStage.WORLD_RIGHT). Decor only: no part takes a click, so a click on the
## store still reaches the background.

## The store band on the stage: StoreArt's columns, under the top bar, down to the belt's back.
const WALL_RECT := Rect2(
	StoreArt.LEFT * ArtStyle.ART_SCALE,
	ShiftStage.TOP_BAR_BOTTOM,
	(StoreArt.RIGHT - StoreArt.LEFT) * ArtStyle.ART_SCALE,
	ShiftStage.COUNTER_TOP - ShiftStage.TOP_BAR_BOTTOM
)
## The aisles whose signs hang over the store, by AisleDefinition.id.
const COLD_CASES := &"cold_cases"
const FRUIT_AND_VEG := &"fruit_and_veg"
## The signs' boards (stage coordinates), hung on two cords from the ceiling.
const SIGN_RECTS: Dictionary[StringName, Rect2] = {
	FRUIT_AND_VEG: Rect2(1064, 84, 60, 24),
	COLD_CASES: Rect2(1224, 84, 60, 24),
}
## A board's cords: from the top bar's foot down to its top, this far in from each end.
const CORD_INSET := 12.0
const CORD_WIDTH := 2.0
## A sign's lit top and shaded foot: paper and ink over its colour.
const SIGN_LIT := Color(Palette.PAPER, 0.3)
const SIGN_DARK := Color(Palette.INK, 0.3)
## The glyph's paper tile, centred on the board, the glyph at ICON_SCALE inside it.
const TILE_SIZE := 20.0
const ICON_SCALE := 2.0
const ICON_INSET := 1.0
const ICONS: Dictionary[StringName, Texture2D] = {
	COLD_CASES: preload("res://art/icons/aisle_cold_cases.png"),
	FRUIT_AND_VEG: preload("res://art/icons/aisle_fruit_and_veg.png"),
}
## A sign's colour when the run's balance has no such aisle.
const FALLBACK_SIGN := Palette.TEAL
## The pendant lamps (art/src/scenery/ceiling_lamp.txt) over StoreArt's cones, each hung on a cord
## from the top bar's foot down to LAMP_TOP.
const LAMP := preload("res://art/scenery/ceiling_lamp.png")
const LAMP_TOP := 70.0
const LAMP_CORD := Color(Palette.STEEL_DARKEST)

## The sign colour of each aisle (the run's balance, else FALLBACK_SIGN).
var _sign_colours: Dictionary[StringName, Color] = {}


## The store, its signs in the colours of `aisles` (the run's balance).
func _init(aisles: Array[AisleDefinition] = []) -> void:
	name = "StoreShelves"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	place(self, WALL_RECT)
	for id: StringName in SIGN_RECTS:
		_sign_colours[id] = FALLBACK_SIGN
	for aisle: AisleDefinition in aisles:
		if aisle != null and _sign_colours.has(aisle.id):
			_sign_colours[aisle.id] = aisle.sign_color
	var art: TextureRect = UiKit.sprite(StoreArt.texture())
	art.name = "Store"
	art.size = WALL_RECT.size
	add_child(art)
	for rect: Rect2 in lamp_rects():
		var cord_x: float = rect.get_center().x - CORD_WIDTH / 2.0
		var cord_top: float = ShiftStage.TOP_BAR_BOTTOM
		var cord: Rect2 = Rect2(cord_x, cord_top, CORD_WIDTH, LAMP_TOP - cord_top)
		_rect_node(self, _local(cord), LAMP_CORD, "Cord")
		var lamp: TextureRect = UiKit.sprite(LAMP)
		lamp.name = "Lamp"
		lamp.position = _local(rect).position
		lamp.size = rect.size
		add_child(lamp)
	for id: StringName in SIGN_RECTS:
		add_child(_sign(id))


## `control` at `rect` (stage coordinates), centred in its parent as the stage is.
static func place(control: Control, rect: Rect2) -> void:
	control.set_anchors_preset(Control.PRESET_CENTER)
	control.offset_left = rect.position.x - ShiftStage.SIZE.x / 2.0
	control.offset_top = rect.position.y - ShiftStage.SIZE.y / 2.0
	control.offset_right = rect.end.x - ShiftStage.SIZE.x / 2.0
	control.offset_bottom = rect.end.y - ShiftStage.SIZE.y / 2.0


## The pendant lamps' rects (stage coordinates): one over each of StoreArt's cones, its foot
## at the cone's top.
static func lamp_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var lamp_size: Vector2 = Vector2(LAMP.get_size())
	for cone_x: int in StoreArt.LAMP_XS:
		var centre: float = cone_x * ArtStyle.ART_SCALE
		rects.append(Rect2(Vector2(centre - lamp_size.x / 2.0, LAMP_TOP), lamp_size))
	return rects


## The colour the sign of aisle `id` is painted in.
func sign_colour(id: StringName) -> Color:
	if _sign_colours.has(id):
		return _sign_colours[id]
	return FALLBACK_SIGN


## A stage rect in the store's own coordinates.
static func _local(rect: Rect2) -> Rect2:
	return Rect2(rect.position - WALL_RECT.position, rect.size)


func _sign(id: StringName) -> Control:
	var board: Rect2 = SIGN_RECTS[id]
	var sign_node: Control = Control.new()
	sign_node.name = "Sign" + String(id).to_pascal_case()
	sign_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hung: Rect2 = Rect2(
		board.position.x,
		ShiftStage.TOP_BAR_BOTTOM,
		board.size.x,
		board.end.y - ShiftStage.TOP_BAR_BOTTOM
	)
	sign_node.position = _local(hung).position
	sign_node.size = hung.size
	var top: float = board.position.y - hung.position.y
	for cord_x: float in [CORD_INSET, board.size.x - CORD_INSET - CORD_WIDTH]:
		_rect_node(sign_node, Rect2(cord_x, 0, CORD_WIDTH, top), LAMP_CORD, "Cord")
	var local: Rect2 = Rect2(Vector2(0, top), board.size)
	_rect_node(sign_node, local, sign_colour(id), "Board")
	_rect_node(sign_node, Rect2(0, top, board.size.x, 2), SIGN_LIT, "Lit")
	_rect_node(sign_node, Rect2(0, local.end.y - 2, board.size.x, 2), SIGN_DARK, "Shade")
	var tile: Rect2 = Rect2(
		roundf((board.size.x - TILE_SIZE) / 2.0),
		top + roundf((board.size.y - TILE_SIZE) / 2.0),
		TILE_SIZE,
		TILE_SIZE
	)
	_rect_node(sign_node, tile, Palette.PAPER, "Tile")
	var icon: TextureRect = UiKit.sprite(ICONS[id])
	icon.name = "Glyph"
	icon.position = tile.position + Vector2.ONE * ICON_INSET
	icon.size = Vector2(ICONS[id].get_size()) * ICON_SCALE
	sign_node.add_child(icon)
	return sign_node


static func _rect_node(parent: Control, rect: Rect2, colour: Color, part: String) -> void:
	var band: ColorRect = ColorRect.new()
	band.name = part
	band.color = colour
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.position = rect.position
	band.size = rect.size
	parent.add_child(band, true)
