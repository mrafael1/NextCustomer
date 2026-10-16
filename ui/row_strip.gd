class_name RowStrip
extends Control
## The checkout row's slots (plan section 3.1), one cell per card the shift allows. Upgrades
## can add slots (Extra coupon slot, Big basket), so the cells are rebuilt when the shift's card
## limit changes. A row wider than the 7 slots the screen was laid out for first closes the gap
## between its cells (the tickets keep their own inset apart), then scales down to the 7-slot
## width (8 slots about x0.95, 9 slots about x0.85). The common 7-slot row is never scaled.
##
## The slots are cells on the belt (#80, mock-up B2; greybox): each open cell
## (ItemView.BELT_SIZE) stands its item on the belt's top face and clips its ticket (the item's
## sticker) on the price rail. An empty slot shows a footprint on the belt (FOOTPRINT_RECT) and a
## blank ticket on the rail (the "mat", at TICKET_RECT) with its slot number. No slot is marked
## as the coupon slot (a coupon slot is a capacity, not a position: see ShiftScreen). The slots
## the picked item can go to wear a solid mustard ring between ink lines around the ticket
## (slot_placeable), so they differ from an empty slot in shape, not only colour; and the empty
## ticket under a dragged item is filled (slot_hover). The ring and the fill sit on each cell's
## marks layer, over the ticket and under the item; is_outlined() and is_hovered() read them.
##
## A slot the shift's inspection closed (Short belt, Coupon slot closed) shows as a CLOSED cell
## after the open slots: a velvet rope on two posts on the belt (at their art's size), and on the
## rail a dark ink plate reading CLOSED over the names of the inspections that closed slots; its
## tooltip says why. It is never a drop target, and the row keeps the run's usual cell count, so
## an inspection never rescales it.
##
## A plain Control holds the row: a Container would reset the row's scale. `slots` is kept as
## one array, changed in place, because CardDrag holds it.

signal slot_input(event: InputEvent, slot: int)
## A click on a closed slot, so the screen can say why it is closed.
signal closed_clicked

## The width of the 7 slots the screen was laid out for: wider rows are scaled to it.
const LAID_OUT_SLOTS := 7
## The gap between cells (mock-up B2's pitch, 128), and a wider row's.
const SEPARATION := 12
const WIDE_SEPARATION := 0
const CELL_SIZE := ItemView.BELT_SIZE
## An open cell's ticket on the rail (cell coordinates; the item's sticker covers it), and an
## empty slot's footprint on the belt's top face.
const TICKET_RECT := Rect2(ItemView.BELT_STICKER, PriceSticker.SIZE)
const FOOTPRINT_RECT := Rect2(8, 100, 100, 32)
const FOOTPRINT_COLOR := Palette.RUBBER_DARK
const TICKET_EMPTY_COLOR := Palette.STEEL_LIGHT
const OUTLINE := 2
## The placeable ring reaches this far past the ticket on every side (one art pixel).
const RING_GROW := 2
## The frames' 9-slice margins, in art pixels: the ring and the hover fill.
const RING_MARGIN := 4
const HOVER_MARGIN := 3
## The hover fill lets a little of the ticket show through.
const HOVER_ALPHA := 0.85
## An empty slot's number, centred on its blank ticket, in the number font.
const NUMBER_RECT := TICKET_RECT
const NUMBER_SIZE := 32
const NUMBER_COLOR := Palette.GREY_DARK
## The CLOSED cell, in the cell: two posts on the belt and the velvet rope between them, at their
## art's size; on the rail the ink plate with CLOSED on its top (the sign) and the caption under
## it (two lines when two inspections close slots).
const POST_RECTS: Array[Rect2] = [Rect2(11, 54, 12, 72), Rect2(93, 54, 12, 72)]
const ROPE_RECT := Rect2(14, 56, 88, 24)
const CLOSED_SIGN_RECT := Rect2(4, 166, 108, 26)
const CLOSED_PLATE_RECT := TICKET_RECT
const CLOSED_TEXT := "CLOSED"
const CLOSED_SIZE := 16
const CLOSED_CAPTION_RECT := Rect2(6, 192, 104, 34)
const CLOSED_CAPTION_SIZE := 12
const CLOSED_CAPTION_WEIGHT := 700
const CLOSED_CAPTION_OUTLINE := 4
const GROUND_NAME := &"Ground"
const MAT_NAME := &"Mat"
const FOOTPRINT_NAME := &"Footprint"
const PLATE_NAME := &"ClosedPlate"
const NUMBER_NAME := &"SlotNumber"
const MARKS_NAME := &"Marks"
const RING_NAME := &"Ring"
const HOVER_NAME := &"Hover"
const SIGN_NAME := &"ClosedSign"
const CAPTION_NAME := &"ClosedCaption"

const SLOT_PLACEABLE := preload("res://art/frames/slot_placeable.png")
const SLOT_HOVER := preload("res://art/frames/slot_hover.png")
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
		_show_empty(panel, empty)
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


## Fills an empty ticket as the landing spot of a dragged item, or clears it. A filled slot never
## shows the fill (the item that would be pushed is tinted instead, by CardDrag).
static func set_hovered(panel: PanelContainer, hovered: bool) -> void:
	var marks: Control = _marks(panel)
	if marks == null:
		return
	var fill: CanvasItem = marks.get_node(NodePath(HOVER_NAME))
	fill.visible = hovered and not _holds_card(panel)


## Whether an empty ticket shows the drag's landing fill.
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


## An open slot's blank ticket (shown while the slot is empty), or null (a CLOSED cell).
static func mat(panel: PanelContainer) -> Panel:
	return panel.get_node_or_null(NodePath("%s/%s" % [GROUND_NAME, MAT_NAME])) as Panel


## An open slot's number (shown while it is empty), or null (a CLOSED cell).
static func slot_number(panel: PanelContainer) -> Label:
	return panel.get_node_or_null(NodePath("%s/%s" % [GROUND_NAME, NUMBER_NAME])) as Label


## An open slot's footprint on the belt (shown while it is empty), or null (a CLOSED cell).
static func footprint(panel: PanelContainer) -> Panel:
	return panel.get_node_or_null(NodePath("%s/%s" % [GROUND_NAME, FOOTPRINT_NAME])) as Panel


## Whether a slot shows as empty: its footprint and blank ticket (no item stands on it).
static func shows_empty_mat(panel: PanelContainer) -> bool:
	var slot_mat: Panel = mat(panel)
	return slot_mat != null and slot_mat.visible


## The gap between the cells of a row of `count` cells: a row wider than the laid-out one
## closes it before it scales.
static func separation_for(count: int) -> int:
	return SEPARATION if count <= LAID_OUT_SLOTS else WIDE_SEPARATION


## The row's natural width for `count` cells, `separation` apart.
static func row_width(count: int, separation: int = SEPARATION) -> float:
	return count * CELL_SIZE.x + maxi(count - 1, 0) * separation


## An open slot: its ground (the footprint, the blank ticket and the number), then the marks
## over it. The
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
	var print_rect: Panel = _flat(FOOTPRINT_COLOR)
	print_rect.name = FOOTPRINT_NAME
	_child_at(ground, print_rect, FOOTPRINT_RECT)
	var slot_mat: Panel = _flat(TICKET_EMPTY_COLOR)
	slot_mat.name = MAT_NAME
	_child_at(ground, slot_mat, TICKET_RECT)
	var number: Label = _slot_number_label(slot)
	number.name = NUMBER_NAME
	_child_at(ground, number, NUMBER_RECT)
	panel.add_child(ground)
	panel.add_child(_new_marks())
	_show_empty(panel, true)
	slots.append(panel)
	return panel


## A slot the inspection closed: a velvet rope between two posts on the belt, and on the rail the
## ink plate with "CLOSED" over `caption`. The CLOSED label is the cell's first child and spans
## the cell, its text centred on the plate's top (the sign); the plate is drawn behind it, and the
## posts, rope and caption are its children, placed in the cell's coordinates.
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
	label.add_theme_color_override("font_color", Palette.TOMATO_LIGHT)
	var plate: Panel = _flat(Palette.INK)
	plate.name = PLATE_NAME
	plate.show_behind_parent = true
	_child_at(label, plate, CLOSED_PLATE_RECT)
	var sign_area: Control = Control.new()
	sign_area.name = SIGN_NAME
	_child_at(label, sign_area, CLOSED_SIGN_RECT)
	for index: int in range(POST_RECTS.size()):
		var post: TextureRect = UiKit.sprite(ROPE_POST)
		post.name = "Post%d" % index
		post.flip_h = index == 1
		_child_at(label, post, POST_RECTS[index])
	# After the posts: the rope's brass hooks sit over the posts' caps.
	var rope: TextureRect = UiKit.sprite(VELVET_ROPE)
	rope.name = "Rope"
	_child_at(label, rope, ROPE_RECT)
	var caption_label: Label = UiKit.body_label(caption, CLOSED_CAPTION_SIZE, Palette.CREAM_SHADE)
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


## The layer over a slot's ticket and under its item: the drag's landing fill on the ticket,
## under the placeable ring, which reaches RING_GROW past the ticket.
static func _new_marks() -> Control:
	var marks: Control = Control.new()
	marks.name = MARKS_NAME
	marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill: NinePatchRect = _nine_patch(SLOT_HOVER, HOVER_MARGIN)
	fill.name = HOVER_NAME
	fill.self_modulate = Color(1, 1, 1, HOVER_ALPHA)
	_child_at(marks, fill, TICKET_RECT)
	fill.visible = false
	var ring: NinePatchRect = _nine_patch(SLOT_PLACEABLE, RING_MARGIN)
	ring.name = RING_NAME
	_child_at(marks, ring, TICKET_RECT.grow(RING_GROW))
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


## Shows a slot's footprint, blank ticket and number when `empty`; an item covers them otherwise.
static func _show_empty(panel: PanelContainer, empty: bool) -> void:
	footprint(panel).visible = empty
	mat(panel).visible = empty
	slot_number(panel).visible = empty


## A flat `color` panel with an ink outline.
static func _flat(color: Color) -> Panel:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Palette.INK
	style.set_border_width_all(OUTLINE)
	var panel: Panel = Panel.new()
	panel.add_theme_stylebox_override("panel", style)
	return panel


## Adds `node` to `parent` at `rect` (the parent's coordinates), taking no clicks.
static func _child_at(parent: Control, node: Control, rect: Rect2) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = rect.position
	node.size = rect.size
	parent.add_child(node)


## A slot's number (1-based), on its blank ticket.
static func _slot_number_label(slot: int) -> Label:
	var number: Label = UiKit.number_label(str(slot + 1), NUMBER_SIZE, false)
	number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	number.add_theme_color_override("font_color", NUMBER_COLOR)
	return number
