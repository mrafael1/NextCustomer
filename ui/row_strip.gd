class_name RowStrip
extends Control
## The checkout row's slots (plan section 3.1), one cell per card the shift allows. Upgrades
## can add slots (Extra coupon slot, Big basket), so the cells are rebuilt when the shift's card
## limit changes. A row wider than the 7 slots the screen was laid out for first closes the gap
## between its cells (the mats keep their own inset apart), then scales down to the 7-slot width
## (8 slots x0.9, 9 slots x0.8). The common 7-slot row is never scaled.
##
## The slots are cells on the boutique belt (#75, style frame v2): each open cell
## (ItemView.BELT_SIZE) has a recessed brass-edged mat at MAT_RECT, and the row's items stand on
## the mats as belt ItemViews (the sprite in the mat's recess, the payout plaque on its top rim,
## the sticker and the chips under it). An empty mat's face is a step darker, with its slot
## number engraved. No mat is marked as the coupon slot (a coupon slot is a capacity, not a
## position: see ShiftScreen). The slots the picked item can go to wear a solid mustard ring
## between ink lines around the mat (slot_placeable), so they differ from an empty slot in
## shape, not only colour; and the empty mat under a dragged item is filled (slot_hover). The
## ring and the fill sit on each cell's marks layer, over the mat and under the item, so the
## item's plaque and sprite stay whole; is_outlined() and is_hovered() read them.
##
## A slot the shift's inspection closed (Short belt, Coupon slot closed) shows as a CLOSED cell
## after the open slots: bare rubber (no mat) behind a velvet rope on two brass posts (at their
## art's size), the CLOSED sign (the inspection tag's frame) hanging from it, and under it the
## names of the inspections that closed slots; its tooltip says why. It is never a drop target,
## and the row keeps the run's usual cell count, so an inspection never rescales it.
##
## A plain Control holds the row: a Container would reset the row's scale. `slots` is kept as
## one array, changed in place, because CardDrag holds it.

signal slot_input(event: InputEvent, slot: int)
## A click on a closed slot, so the screen can say why it is closed.
signal closed_clicked

## The width of the 7 slots the screen was laid out for: wider rows are scaled to it.
const LAID_OUT_SLOTS := 7
## The gap between cells (style frame v2's pitch, 124), and a wider row's.
const SEPARATION := 4
const WIDE_SEPARATION := 0
const CELL_SIZE := ItemView.BELT_SIZE
## Each open cell's mat (cell coordinates): inside its ink line and 2 px brass ring the item's
## sprite stands on the recess, and the item's plaque sits on its top rim.
const MAT_RECT := Rect2(6, 12, 108, 116)
## The placeable ring reaches this far past the mat on every side (one art pixel).
const RING_GROW := 2
## The frames' 9-slice margins, in art pixels: the ring, the hover fill, the CLOSED sign and the
## mat (its ink line, brass ring and recess).
const RING_MARGIN := 4
const HOVER_MARGIN := 3
const TAG_MARGIN := 3
const MAT_MARGIN := 5
## The hover fill lets a little of the mat show through.
const HOVER_ALPHA := 0.85
## An empty mat's engraved number (cell coordinates, centred on the mat's face): brass dark in
## the number font over a paper highlight.
const NUMBER_RECT := Rect2(12, 18, 96, 104)
const NUMBER_SIZE := 40
const NUMBER_COLOR := Palette.BRASS_DARK
const NUMBER_SHADOW := Palette.PAPER
const ENGRAVE_OFFSET := 2
## The CLOSED cell, in the cell: two brass posts and the velvet rope between them, at their
## art's size; two strings from the rope to the CLOSED sign; the caption under the posts (two
## lines when two inspections close slots).
const POST_RECTS: Array[Rect2] = [Rect2(8, 26, 12, 72), Rect2(100, 26, 12, 72)]
const ROPE_RECT := Rect2(16, 28, 88, 24)
const STRING_RECTS: Array[Rect2] = [Rect2(42, 50, 2, 8), Rect2(76, 50, 2, 8)]
const STRING_COLOR := Palette.INK
const CLOSED_SIGN_RECT := Rect2(22, 58, 76, 28)
const CLOSED_TEXT := "CLOSED"
const CLOSED_SIZE := 16
const CLOSED_CAPTION_RECT := Rect2(6, 98, 108, 32)
const CLOSED_CAPTION_SIZE := 12
const CLOSED_CAPTION_WEIGHT := 700
const CLOSED_CAPTION_OUTLINE := 4
const GROUND_NAME := &"Ground"
const MAT_NAME := &"Mat"
const NUMBER_NAME := &"SlotNumber"
const MARKS_NAME := &"Marks"
const RING_NAME := &"Ring"
const HOVER_NAME := &"Hover"
const SIGN_NAME := &"ClosedSign"
const CAPTION_NAME := &"ClosedCaption"

const SLOT_MAT := preload("res://art/frames/slot_mat.png")
## An empty mat: its face a step darker, so the slot reads as empty.
const SLOT_MAT_EMPTY := preload("res://art/frames/slot_mat_empty.png")
const SLOT_PLACEABLE := preload("res://art/frames/slot_placeable.png")
const SLOT_HOVER := preload("res://art/frames/slot_hover.png")
const TAG_FRAME := preload("res://art/frames/inspection_tag.png")
const ROPE_POST := preload("res://art/scenery/rope_post.png")
const VELVET_ROPE := preload("res://art/scenery/velvet_rope.png")

## The row of slot cells (scaled when wide), for the count-up and the drag.
var box: HBoxContainer
var slots: Array[PanelContainer] = []
## The closed cells, after the open slots (never drop targets).
var closed: Array[PanelContainer] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	box = HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", SEPARATION)
	add_child(box)


## Makes one slot cell per card the shift allows, then `closed_count` CLOSED cells (their
## tooltip is `closed_reason`, their caption `caption`), and fits the row to the laid-out width.
func set_slot_count(
	count: int, closed_count: int = 0, closed_reason: String = "", caption: String = ""
) -> void:
	if count == slots.size() and closed_count == closed.size():
		for panel: PanelContainer in closed:
			panel.tooltip_text = closed_reason
			closed_caption_label(panel).text = caption
		return
	for panel: PanelContainer in slots + closed:
		box.remove_child(panel)
		panel.queue_free()
	slots.clear()
	closed.clear()
	for slot: int in range(count):
		box.add_child(_slot_panel(slot))
	for _closed: int in range(closed_count):
		var panel: PanelContainer = _closed_panel(closed_reason, caption)
		closed.append(panel)
		box.add_child(panel)
	var cells: int = count + closed_count
	var separation: int = separation_for(cells)
	box.add_theme_constant_override("separation", separation)
	var natural: Vector2 = Vector2(row_width(cells, separation), CELL_SIZE.y)
	var factor: float = minf(1.0, row_width(LAID_OUT_SLOTS) / natural.x)
	box.scale = Vector2(factor, factor)
	box.size = natural
	custom_minimum_size = natural * factor


## Fills the slots: a belt item for each row card (clicks go to `on_clicked`; `balance` gives
## each item its aisle), and the slot number on each empty mat. Slots up to `placeable_until`
## are ringed for the picked card. Returns the row's item views, in slot order.
func show_cards(
	row: Array[CardInstance],
	placeable_until: int,
	on_clicked: Callable,
	balance: BalanceDefinition = null
) -> Array[CardView]:
	var views: Array[CardView] = []
	for slot: int in range(slots.size()):
		var panel: PanelContainer = slots[slot]
		for child: Node in panel.get_children():
			if child is CardView:
				panel.remove_child(child)
				child.queue_free()
		var empty: bool = slot >= row.size()
		_show_mat(panel, empty)
		if not empty:
			var card: CardInstance = row[slot]
			var aisle: AisleDefinition = (
				balance.aisle_of(card.definition) if balance != null else null
			)
			var view: ItemView = ItemView.new(card, aisle, ItemView.Form.BELT)
			view.clicked.connect(on_clicked)
			# The cell's last child: over the mat and the marks.
			panel.add_child(view)
			views.append(view)
		var ring: CanvasItem = _marks(panel).get_node(NodePath(RING_NAME))
		ring.visible = slot <= placeable_until
		set_hovered(panel, false)
	return views


## Whether a slot wears the placeable ring (the picked card can go there).
func is_outlined(slot: int) -> bool:
	return (_marks(slots[slot]).get_node(NodePath(RING_NAME)) as CanvasItem).visible


## Fills an empty mat as the landing spot of a dragged item, or clears it. A filled slot never
## shows the fill (the item that would be pushed is tinted instead, by CardDrag).
static func set_hovered(panel: PanelContainer, hovered: bool) -> void:
	var marks: Control = _marks(panel)
	if marks == null:
		return
	var fill: CanvasItem = marks.get_node(NodePath(HOVER_NAME))
	fill.visible = hovered and not _holds_card(panel)


## Whether an empty mat shows the drag's landing fill.
static func is_hovered(panel: PanelContainer) -> bool:
	var marks: Control = _marks(panel)
	return marks != null and (marks.get_node(NodePath(HOVER_NAME)) as CanvasItem).visible


## The caption of a CLOSED cell: the names of `inspections` that close slots (product or
## coupon slots), from data.
static func closed_caption(inspections: Array[InspectionDefinition]) -> String:
	var closing: PackedStringArray = PackedStringArray()
	for inspection: InspectionDefinition in inspections:
		if inspection.extra_slots < 0 or inspection.extra_coupon_slots < 0:
			closing.append(inspection.display_name)
	return ", ".join(closing)


## A CLOSED cell's caption label.
static func closed_caption_label(panel: PanelContainer) -> Label:
	return panel.get_child(0).get_node(NodePath(CAPTION_NAME)) as Label


## An open slot's mat, or null (a CLOSED cell has none).
static func mat(panel: PanelContainer) -> Panel:
	return panel.get_node_or_null(NodePath("%s/%s" % [GROUND_NAME, MAT_NAME])) as Panel


## An open slot's engraved number (shown while its mat is empty), or null (a CLOSED cell).
static func slot_number(panel: PanelContainer) -> Label:
	return panel.get_node_or_null(NodePath("%s/%s" % [GROUND_NAME, NUMBER_NAME])) as Label


## Whether a slot's mat shows its empty face (no item stands on it).
static func shows_empty_mat(panel: PanelContainer) -> bool:
	var slot_mat: Panel = mat(panel)
	if slot_mat == null:
		return false
	var style: StyleBoxTexture = slot_mat.get_theme_stylebox("panel") as StyleBoxTexture
	return style.texture == SLOT_MAT_EMPTY


## The gap between the cells of a row of `count` cells: a row wider than the laid-out one
## closes it before it scales.
static func separation_for(count: int) -> int:
	return SEPARATION if count <= LAID_OUT_SLOTS else WIDE_SEPARATION


## The row's natural width for `count` cells, `separation` apart.
static func row_width(count: int, separation: int = SEPARATION) -> float:
	return count * CELL_SIZE.x + maxi(count - 1, 0) * separation


## An open slot: its ground (the mat and the engraved number), then the marks over it. The
## PanelContainer sizes both layers to the cell; their parts are placed in the cell's
## coordinates.
func _slot_panel(slot: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = CELL_SIZE
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.gui_input.connect(func(event: InputEvent) -> void: slot_input.emit(event, slot))
	var ground: Control = Control.new()
	ground.name = GROUND_NAME
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var slot_mat: Panel = Panel.new()
	slot_mat.name = MAT_NAME
	ArtStyle.use_pixel_material(slot_mat)
	_child_at(ground, slot_mat, MAT_RECT)
	var number: Label = _engraved_number(slot)
	number.name = NUMBER_NAME
	_child_at(ground, number, NUMBER_RECT)
	panel.add_child(ground)
	panel.add_child(_new_marks())
	_show_mat(panel, true)
	slots.append(panel)
	return panel


## A slot the inspection closed: bare rubber (no mat), with "CLOSED" on the inspection tag's
## frame hanging from a velvet rope between two brass posts, and `caption` under them. The
## CLOSED label is the cell's first child and spans the cell, its text centred on the sign; the
## sign is drawn behind it, and the posts, rope, strings and caption are its children, placed in
## the cell's coordinates.
func _closed_panel(reason: String, caption: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = CELL_SIZE
	panel.tooltip_text = reason
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var label: Label = UiKit.display_label(CLOSED_TEXT, CLOSED_SIZE, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The label spans the cell, so its children are placed in the cell's coordinates.
	label.size_flags_horizontal = Control.SIZE_FILL
	label.size_flags_vertical = Control.SIZE_FILL
	# The text sits on the sign: the label's style box keeps it inside the sign's rect.
	var on_sign: StyleBoxEmpty = StyleBoxEmpty.new()
	on_sign.content_margin_left = CLOSED_SIGN_RECT.position.x
	on_sign.content_margin_top = CLOSED_SIGN_RECT.position.y
	on_sign.content_margin_right = CELL_SIZE.x - CLOSED_SIGN_RECT.end.x
	on_sign.content_margin_bottom = CELL_SIZE.y - CLOSED_SIGN_RECT.end.y
	label.add_theme_stylebox_override("normal", on_sign)
	var sign_frame: NinePatchRect = _nine_patch(TAG_FRAME, TAG_MARGIN)
	sign_frame.name = SIGN_NAME
	sign_frame.show_behind_parent = true
	_child_at(label, sign_frame, CLOSED_SIGN_RECT)
	for index: int in range(POST_RECTS.size()):
		var post: TextureRect = UiKit.sprite(ROPE_POST)
		post.name = "Post%d" % index
		post.flip_h = index == 1
		_child_at(label, post, POST_RECTS[index])
	# After the posts: the rope's brass hooks sit over the posts' caps.
	var rope: TextureRect = UiKit.sprite(VELVET_ROPE)
	rope.name = "Rope"
	_child_at(label, rope, ROPE_RECT)
	for rect: Rect2 in STRING_RECTS:
		var string: ColorRect = ColorRect.new()
		string.name = "String"
		string.color = STRING_COLOR
		_child_at(label, string, rect)
	var caption_label: Label = UiKit.body_label(caption, CLOSED_CAPTION_SIZE, Palette.PAPER)
	caption_label.name = CAPTION_NAME
	caption_label.add_theme_font_override("font", caption_font())
	caption_label.add_theme_constant_override("outline_size", CLOSED_CAPTION_OUTLINE)
	caption_label.add_theme_color_override("font_outline_color", Palette.INK)
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_child_at(label, caption_label, CLOSED_CAPTION_RECT)
	panel.add_child(label)
	panel.gui_input.connect(
		func(event: InputEvent) -> void:
			var press: InputEventMouseButton = event as InputEventMouseButton
			if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
				closed_clicked.emit()
	)
	return panel


## The CLOSED caption's font: the body font, bold.
static func caption_font() -> Font:
	return ArtStyle.bold_font(CLOSED_CAPTION_WEIGHT)


## The layer over a slot's mat and under its item: the drag's landing fill on the mat, under
## the placeable ring, which reaches RING_GROW past the mat.
static func _new_marks() -> Control:
	var marks: Control = Control.new()
	marks.name = MARKS_NAME
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: NinePatchRect = _nine_patch(SLOT_HOVER, HOVER_MARGIN)
	fill.name = HOVER_NAME
	fill.self_modulate = Color(1, 1, 1, HOVER_ALPHA)
	_child_at(marks, fill, MAT_RECT)
	fill.visible = false
	var ring: NinePatchRect = _nine_patch(SLOT_PLACEABLE, RING_MARGIN)
	ring.name = RING_NAME
	_child_at(marks, ring, MAT_RECT.grow(RING_GROW))
	ring.visible = false
	return marks


static func _marks(panel: PanelContainer) -> Control:
	return panel.get_node_or_null(NodePath(MARKS_NAME)) as Control


static func _holds_card(panel: PanelContainer) -> bool:
	for child: Node in panel.get_children():
		if child is CardView and not child.is_queued_for_deletion():
			return true
	return false


static func _nine_patch(texture: Texture2D, margin: int) -> NinePatchRect:
	var patch: NinePatchRect = NinePatchRect.new()
	patch.texture = texture
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pixels: int = margin * ArtStyle.ART_SCALE
	patch.patch_margin_left = pixels
	patch.patch_margin_top = pixels
	patch.patch_margin_right = pixels
	patch.patch_margin_bottom = pixels
	ArtStyle.use_pixel_material(patch)
	return patch


## Shows a slot's mat with its empty face and engraved number when `empty`, or its plain face
## under the item standing on it.
static func _show_mat(panel: PanelContainer, empty: bool) -> void:
	var style: StyleBoxTexture = ArtStyle.frame_style(
		SLOT_MAT_EMPTY if empty else SLOT_MAT, MAT_MARGIN
	)
	mat(panel).add_theme_stylebox_override("panel", style)
	slot_number(panel).visible = empty


## Adds `node` to `parent` at `rect` (the parent's coordinates), taking no clicks.
static func _child_at(parent: Control, node: Control, rect: Rect2) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = rect.position
	node.size = rect.size
	parent.add_child(node)


## A slot's number (1-based), engraved in its mat.
static func _engraved_number(slot: int) -> Label:
	var number: Label = UiKit.number_label(str(slot + 1), NUMBER_SIZE, false)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.add_theme_color_override("font_color", NUMBER_COLOR)
	number.add_theme_color_override("font_shadow_color", NUMBER_SHADOW)
	number.add_theme_constant_override("shadow_offset_x", 0)
	number.add_theme_constant_override("shadow_offset_y", ENGRAVE_OFFSET)
	return number
