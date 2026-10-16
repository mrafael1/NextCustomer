class_name BeltView
extends Control
## The conveyor belt of style frame v2 (#75; round 2, delta section 3): a grey rubber belt with
## horizontal treads between brass rails and rollers, and each cell's ground. Every open cell
## gets a mat (a recessed brass-framed mat, or the coupon slot's gold perforated one), an empty
## mat shows its engraved slot number, and a CLOSED cell shows bare rubber behind a velvet rope
## with the CLOSED sign and the closing inspection's name. The items stand on the mats (the
## scene adds them over the belt). mat_kinds() says which mat goes where, following core.
## Nothing here scores.

## What stands in a belt cell: a product mat, the coupon-only mat, or a slot an inspection closed
## (a product slot, or a coupon slot).
enum MatKind { PRODUCT, COUPON, CLOSED, CLOSED_COUPON }

## The frame's rails (top and bottom) and rollers (left and right), in art pixels.
const MARGIN_H := 8
const MARGIN_V := 4
const INTERIOR := Rect2(32, 76, 864, 238)
## The rubber's horizontal treads (stage y): a groove, then a lit lip under it (the first lip is
## the sheen, the light coming from the top). The last lip ends at 312, above the bottom rail.
const TREAD_FIRST := 80.0
const TREAD_EVERY := 12.0
const TREAD_COUNT := 20
const TREAD_GROOVE := 2.0
const TREAD_LIP := 2.0
## The end rollers' turned rings (stage coordinates): a brass-darkest groove every 8 art rows
## across each roller, code-drawn so the rhythm holds at any belt height (a stretched 9-slice
## middle turned the source's rings into thick bars).
const ROLLER_XS: Array[float] = [18.0, 898.0]
const ROLLER_WIDTH := 12.0
const RING_FIRST := 82.0
const RING_EVERY := 16.0
const RING_HEIGHT := 2.0
## The slot mats' 9-slice margin, in art pixels: the ink line, the 2 px brass ring and the 2 px
## recess (the coupon mat's ring and perforation take 3).
const MAT_MARGIN := 5
const COUPON_MAT_MARGIN := 3
## An empty mat's engraved slot number (on a product mat, centred on the face; on a coupon mat,
## above COUPON), in the cell.
const SLOT_NUMBER_SIZE := 40
const SLOT_NUMBER_RECT := Rect2(12, 18, 96, 104)
const COUPON_NUMBER_RECT := Rect2(12, 28, 96, 40)
const COUPON_WORD_RECT := Rect2(12, 78, 96, 18)
const COUPON_WORD_SIZE := 13
const COUPON_WORD := "COUPON"
const ENGRAVE_OFFSET := 2
## A closed coupon slot's mat shows through under the rope.
const CLOSED_MAT_ALPHA := 0.6
## The CLOSED cell, in the cell: a velvet rope on two brass posts, the CLOSED sign hanging from
## it on two strings and the closing inspection's name under it.
const POST_RECTS: Array[Rect2] = [Rect2(8, 26, 12, 72), Rect2(100, 26, 12, 72)]
const ROPE_RECT := Rect2(16, 28, 88, 24)
const STRING_RECTS: Array[Rect2] = [Rect2(42, 50, 2, 8), Rect2(76, 50, 2, 8)]
const CLOSED_SIGN_RECT := Rect2(22, 58, 76, 28)
const CLOSED_SIGN_MARGIN := 3
const CLOSED_SIGN_PADDING := Vector4(4, 2, 4, 4)
const CLOSED_CAPTION_RECT := Rect2(6, 98, 108, 16)
const CLOSED_TEXT := "CLOSED"
const CLOSED_SIZE := 16
const CLOSED_CAPTION_SIZE := 12
const CLOSED_CAPTION_WEIGHT := 700
const CLOSED_CAPTION_OUTLINE := 4

const FRAME := preload("res://art/frames/belt_v3.png")
const SLOT_MAT := preload("res://art/frames/slot_mat.png")
## An empty open slot's mat: its face a step darker, so the slot reads as empty.
const SLOT_MAT_EMPTY := preload("res://art/frames/slot_mat_empty.png")
const SLOT_MAT_COUPON := preload("res://art/frames/slot_mat_coupon.png")
const ROPE_POST := preload("res://art/scenery/rope_post.png")
const VELVET_ROPE := preload("res://art/scenery/velvet_rope.png")
const TAG_FRAME := preload("res://art/frames/inspection_tag.png")

var _mats: Array[Panel] = []
var _closed_cells: Array[Control] = []
var _frame_style: StyleBoxTexture


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ArtStyle.use_pixel_material(self)
	_frame_style = ArtStyle.frame_style(FRAME, MARGIN_V)
	_frame_style.texture_margin_left = MARGIN_H * ArtStyle.ART_SCALE
	_frame_style.texture_margin_right = MARGIN_H * ArtStyle.ART_SCALE


func _draw() -> void:
	draw_style_box(_frame_style, Rect2(Vector2.ZERO, size))
	var treads: Array[Rect2] = tread_rects()
	for tread: int in range(treads.size()):
		var groove: Rect2 = treads[tread]
		groove.position -= position
		groove.size.y = TREAD_GROOVE
		draw_rect(groove, StyleFrameV2.INK_LIGHT)
		var lip: Rect2 = Rect2(
			groove.position + Vector2(0, TREAD_GROOVE), Vector2(groove.size.x, TREAD_LIP)
		)
		draw_rect(lip, StyleFrameV2.GREY_LIGHT if tread == 0 else StyleFrameV2.GREY)
	for ring: Rect2 in ring_rects():
		draw_rect(Rect2(ring.position - position, ring.size), StyleFrameV2.BRASS_DARKEST)


## The belt frame's 9-slice: its rails and rollers' margins around the plain rubber middle.
func frame_style() -> StyleBoxTexture:
	return _frame_style


## The rubber's treads (each a groove and its lip), in stage coordinates.
static func tread_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for tread: int in range(TREAD_COUNT):
		var y: float = TREAD_FIRST + tread * TREAD_EVERY
		rects.append(Rect2(INTERIOR.position.x, y, INTERIOR.size.x, TREAD_GROOVE + TREAD_LIP))
	return rects


## The end rollers' rings, in stage coordinates: every RING_EVERY down each roller, inside the
## rubber's height.
static func ring_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var y: float = RING_FIRST
	while y + RING_HEIGHT <= INTERIOR.end.y:
		for x: float in ROLLER_XS:
			rects.append(Rect2(x, y, ROLLER_WIDTH, RING_HEIGHT))
		y += RING_EVERY
	return rects


## What stands in each belt cell, left to right, following core, where a coupon slot is a
## capacity count and not a position: the row's cards first (the first coupon_slots_used coupons
## on COUPON mats, every other card on a PRODUCT mat), then the free product mats, the free
## coupon mats, the product slots an inspection closed and the closed coupon slots.
static func mat_kinds(limits: ShiftLimits, row: Array[CardInstance]) -> Array[int]:
	var kinds: Array[int] = []
	var coupon_room: int = RowCapacity.coupon_slots_used(limits, row)
	var coupons: int = 0
	for card: CardInstance in row:
		if card.definition.is_coupon() and coupons < coupon_room:
			kinds.append(MatKind.COUPON)
			coupons += 1
		else:
			kinds.append(MatKind.PRODUCT)
	# The row's cards outside the coupon room use product slots.
	var free_products: int = maxi(limits.slot_count - (row.size() - coupon_room), 0)
	for _slot: int in range(free_products):
		kinds.append(MatKind.PRODUCT)
	for _slot: int in range(maxi(limits.coupon_slot_count - coupon_room, 0)):
		kinds.append(MatKind.COUPON)
	for _slot: int in range(limits.closed_slots):
		kinds.append(MatKind.CLOSED)
	for _slot: int in range(limits.closed_coupon_slots):
		kinds.append(MatKind.CLOSED_COUPON)
	return kinds


## Lays out the cells of `kinds` (mat_kinds()): the first `occupied` cells' mats (their items
## stand on them), then the empty mats with their engraved numbers and the CLOSED cells, captioned
## with `closing_name` (a closed product slot) or `closing_coupon_name` (a closed coupon slot).
## Returns each cell's ground: its mat, or the CLOSED cell.
func lay_out(
	kinds: Array[int], occupied: int, closing_name: String, closing_coupon_name: String
) -> Array[Control]:
	var grounds: Array[Control] = []
	for cell: int in range(kinds.size()):
		var kind: int = kinds[cell]
		var empty: bool = cell >= occupied
		var mat: Panel = null if kind == MatKind.CLOSED else _add_mat(kind, cell, empty)
		_mats.append(mat)
		if kind == MatKind.CLOSED or kind == MatKind.CLOSED_COUPON:
			var coupon: bool = kind == MatKind.CLOSED_COUPON
			grounds.append(_add_closed_cell(cell, closing_coupon_name if coupon else closing_name))
			continue
		if cell >= occupied:
			_engrave(mat, kind, cell)
		grounds.append(mat)
	return grounds


## Each cell's mat, left to right (null for a CLOSED product slot, which shows bare rubber).
func mats() -> Array[Panel]:
	return _mats


## The CLOSED cells (rope, posts, sign and caption), left to right.
func closed_cells() -> Array[Control]:
	return _closed_cells


## Cell `cell`'s origin in this belt's coordinates.
func cell_origin(cell: int) -> Vector2:
	return StyleFrameV2.CELL_ORIGIN - position + Vector2(cell * StyleFrameV2.CELL_PITCH, 0)


## A mat's texture (slot_mat, slot_mat_empty or slot_mat_coupon).
static func mat_texture(mat: Panel) -> Texture2D:
	return (mat.get_theme_stylebox("panel") as StyleBoxTexture).texture


## A slot's mat in cell `cell`, under everything in it: a recessed brass-framed mat (its face a
## step darker when `empty`), or the coupon slot's gold perforated one (it tiles, so the
## perforation keeps its rhythm). A closed coupon slot's mat shows through faintly under the rope.
func _add_mat(kind: int, cell: int, empty: bool) -> Panel:
	var coupon: bool = kind == MatKind.COUPON or kind == MatKind.CLOSED_COUPON
	var texture: Texture2D = SLOT_MAT_EMPTY if empty else SLOT_MAT
	var style: StyleBoxTexture = ArtStyle.frame_style(
		SLOT_MAT_COUPON if coupon else texture, COUPON_MAT_MARGIN if coupon else MAT_MARGIN
	)
	if coupon:
		style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	var mat: Panel = Panel.new()
	mat.name = "CouponMat" if coupon else "Mat"
	mat.add_theme_stylebox_override("panel", style)
	ArtStyle.use_pixel_material(mat)
	var rect: Rect2 = ItemView.BELT_MAT
	_child_at(self, mat, Rect2(cell_origin(cell) + rect.position, rect.size))
	if kind == MatKind.CLOSED_COUPON:
		mat.modulate.a = CLOSED_MAT_ALPHA
	return mat


## An empty mat's slot number (1-based), engraved: brass dark in the number font over a paper
## highlight. A coupon mat also says COUPON (its shape tells it apart, not colour alone).
func _engrave(mat: Panel, kind: int, cell: int) -> void:
	var number: Label = UiKit.number_label(str(cell + 1), SLOT_NUMBER_SIZE, false)
	number.name = "SlotNumber"
	number.add_theme_color_override("font_color", StyleFrameV2.BRASS_DARK)
	number.add_theme_color_override("font_shadow_color", StyleFrameV2.PAPER)
	number.add_theme_constant_override("shadow_offset_x", 0)
	number.add_theme_constant_override("shadow_offset_y", ENGRAVE_OFFSET)
	var rect: Rect2 = SLOT_NUMBER_RECT if kind == MatKind.PRODUCT else COUPON_NUMBER_RECT
	_add_centred(mat, number, _in_mat(rect))
	if kind != MatKind.COUPON:
		return
	var word: Label = UiKit.display_label(COUPON_WORD, COUPON_WORD_SIZE, false)
	word.name = "CouponWord"
	word.add_theme_color_override("font_color", StyleFrameV2.VELVET)
	_add_centred(mat, word, _in_mat(COUPON_WORD_RECT))


## A CLOSED cell: no mat for a product slot, so the bare rubber reads as "nothing goes here"; a
## velvet rope on two brass posts, the CLOSED sign (the inspection tag's tomato, the warning
## signal, with its word) hanging from it on two strings, and `caption` (the closing
## inspection's name) under it.
func _add_closed_cell(cell: int, caption_text: String) -> Control:
	var closed: Control = Control.new()
	closed.name = "ClosedCell"
	_child_at(self, closed, Rect2(cell_origin(cell), ItemView.BELT_SIZE))
	for index: int in range(POST_RECTS.size()):
		var post: TextureRect = UiKit.sprite(ROPE_POST)
		post.name = "Post%d" % index
		post.flip_h = index == 1
		_child_at(closed, post, POST_RECTS[index])
	# After the posts: the rope's brass hooks overlap the post caps.
	_child_at(closed, UiKit.sprite(VELVET_ROPE), ROPE_RECT).name = "Rope"
	for rect: Rect2 in STRING_RECTS:
		var string: ColorRect = ColorRect.new()
		string.color = StyleFrameV2.INK
		_child_at(closed, string, rect).name = "String"
	var sign_panel: PanelContainer = UiKit.frame_panel(
		TAG_FRAME, CLOSED_SIGN_MARGIN, CLOSED_SIGN_PADDING
	)
	_child_at(closed, sign_panel, CLOSED_SIGN_RECT).name = "ClosedSign"
	var label: Label = UiKit.display_label(CLOSED_TEXT, CLOSED_SIZE, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	sign_panel.add_child(label)
	var caption: Label = UiKit.body_label(caption_text, CLOSED_CAPTION_SIZE, StyleFrameV2.PAPER)
	caption.name = "ClosedCaption"
	caption.add_theme_font_override("font", PriceSticker.bold_font(CLOSED_CAPTION_WEIGHT))
	caption.add_theme_constant_override("outline_size", CLOSED_CAPTION_OUTLINE)
	caption.add_theme_color_override("font_outline_color", StyleFrameV2.INK)
	_add_centred(closed, caption, CLOSED_CAPTION_RECT)
	_closed_cells.append(closed)
	return closed


## A cell-relative `rect` in the mat's coordinates.
static func _in_mat(rect: Rect2) -> Rect2:
	return Rect2(rect.position - ItemView.BELT_MAT.position, rect.size)


## Adds `label` to `parent` at `rect`, its text centred both ways.
static func _add_centred(parent: Control, label: Label, rect: Rect2) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_child_at(parent, label, rect)


## Adds `node` to `parent` at `rect` (the parent's coordinates) and returns it.
static func _child_at(parent: Control, node: Control, rect: Rect2) -> Control:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = rect.position
	node.size = rect.size
	parent.add_child(node)
	return node
