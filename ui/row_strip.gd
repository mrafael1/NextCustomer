class_name RowStrip
extends Control
## The checkout row's slots (plan section 3.1), one cell per card the shift allows. Upgrades
## can add slots (Big basket), so the cells are rebuilt when the shift's card
## limit changes. A row wider than the 7 slots the screen was laid out for first closes the gap
## between its cells (the tickets keep their own inset apart), then scales down to the 7-slot
## width (8 slots, with Big basket, about x0.95). The common 7-slot row is never scaled.
##
## The slots are cells on the belt (#80, mock-up B2): each open cell (ItemView.BELT_SIZE) stands
## its item on the belt's top face and clips its ticket (the item's sticker) on the price rail,
## over the ticket's shadow. An empty slot shows a dashed footprint on the belt (BeltFootprint, at
## FOOTPRINT_RECT) and a dashed blank ticket on the rail (the "mat", ticket_empty at TICKET_RECT)
## with its slot number. A slot takes clicks and drops in its column (drop_target_rect), from the
## top of where its item's art stands, lifted, down to its ticket's foot, and across half the gap
## to each neighbour, so the pointer on an item, a footprint or the gap between two finds a slot;
## the band above the art (where the count-up's paid chip pops) is the wall's, whose click lets go
## of the picked item. A belt item, the cell's last child, takes its own hover over its art and
## ticket first. Every slot is general (any card fits any slot, see ShiftScreen). The slots the
## picked item can go to wear a solid mustard ring
## between ink lines around the ticket (slot_placeable), so they differ from an empty slot in
## shape, not only colour; and the empty ticket under a dragged item is filled (slot_hover). The
## ring and the fill sit on each cell's marks layer, over the ticket and under the item;
## is_outlined() and is_hovered() read them.
##
## A slot the shift's inspection closed (Short belt) shows as a CLOSED cell
## after the open slots: a velvet rope on two brass stanchions standing on the belt, each post
## two regions of its art so it stands as tall as an item (the only velvet and brass left on the
## belt), with their contact shadows; and on the rail the ink plate (ticket_closed, its tomato
## band the belt's one tomato) reading CLOSED over the names of the inspections that closed
## slots; its tooltip says why. It is never a drop target, and the row keeps the run's usual
## cell count, so an inspection never rescales it.
##
## A slot a loyalty upgrade acts on wears that upgrade's SlotMark (show_slot_marks): the Slot
## engine's talker hangs under the right end of slot 6's ticket (2026-10-24), as an item tier's
## tag hangs under its left end, on the cell's talker layer, its first child: behind the ticket,
## the blank one or the item's, which hides the talker's top. It shows whether the slot is empty
## or filled and rides with its cell in the count (BeltRide fires it).
##
## A plain Control holds the row: a Container would reset the row's scale. `slots` is kept as
## one array, changed in place, because CardDrag holds it.
##
## While the shift is counted the row rides toward the scanner, its first cell (#86 v6, the belt
## ride): ride_out hides the cells up to one, so the cells after it pack left a pitch() each, and
## moves the box right by the width they left, for the ride to slide back. show_cards brings
## every cell back.

signal slot_input(event: InputEvent, slot: int)
## A click on a closed slot, so the screen can say why it is closed.
signal closed_clicked

## The width of the 7 slots the screen was laid out for: wider rows are scaled to it.
const LAID_OUT_SLOTS := 7
## The gap between cells (mock-up B2's pitch, 128), and a wider row's.
const SEPARATION := 12
const WIDE_SEPARATION := 0
const CELL_SIZE := ItemView.BELT_SIZE
## An open cell's ticket on the rail (cell coordinates; the item's sticker covers it) and its
## shadow under a filled ticket; an empty slot's footprint on the belt's top face, its front edge
## 2 px under the item's foot (mock-up B2), and the top of the slot's drop target: the top of a
## belt item's sprite, lifted and boosted (#71), which the tallest art reaches (a boosted
## ItemView.hit_rect's top).
const TICKET_RECT := Rect2(ItemView.BELT_STICKER, PriceSticker.SIZE)
const TICKET_SHADOW_OFFSET := Vector2(2, 2)
const TICKET_SHADOW_ALPHA := 0.38
const FOOTPRINT_RECT := Rect2(8, 84, 100, 42)
const DROP_TOP := ItemView.BELT_SPRITE.y - ItemView.LIFT - ItemView.BOOST_LIFT
## The placeable ring reaches this far past the ticket on every side (one art pixel).
const RING_GROW := 2
## The frames' 9-slice margins, in art pixels: the ring and the hover fill.
const RING_MARGIN := 4
const HOVER_MARGIN := 3
## The hover fill lets a little of the ticket show through.
const HOVER_ALPHA := 0.85
## An empty slot's number, centred on its blank ticket, in the number font.
const NUMBER_RECT := TICKET_RECT
const NUMBER_SIZE := 24
const NUMBER_COLOR := Palette.GREY_DARK
## The CLOSED cell, in the cell: two posts standing on the belt 12 px behind the items' foot,
## each the post art's top region over its foot region (the shaft between them is plain, so the
## seam never shows), their contact shadows a little to the right, and the velvet rope hooked over
## them at its art's size; on the rail the ink plate, over its shadow, with CLOSED clear of its
## tomato band (the sign, mock-up B2's 9 px gap) and the caption ("inspection", B2's) hanging
## right under it, the pair one block on the plate.
const POST_RECTS: Array[Rect2] = [Rect2(9, 8, 12, 104), Rect2(91, 8, 12, 104)]
const POST_TOP_REGION := Rect2(0, 0, 12, 52)
const POST_FOOT_REGION := Rect2(0, 20, 12, 52)
const POST_SHADOW_RECTS: Array[Rect2] = [Rect2(9, 108, 20, 6), Rect2(91, 108, 20, 6)]
const ROPE_RECT := Rect2(12, 10, 88, 24)
const CLOSED_SIGN_RECT := Rect2(4, 176, 108, 24)
const CLOSED_PLATE_RECT := TICKET_RECT
const CLOSED_PLATE_MARGIN := 3
## A SlotMark's top in its cell, tucked behind the ticket's foot, and its right end: the cell's
## (past the ticket's, clear of a tier tag under the ticket's left end).
const SLOT_MARK_TOP := TICKET_RECT.end.y - SlotMark.TUCKED
const SLOT_MARK_RIGHT := CELL_SIZE.x
const CLOSED_TEXT := "CLOSED"
const CLOSED_SIZE := 18
const CLOSED_CAPTION_TEXT := "inspection"
const CLOSED_CAPTION_RECT := Rect2(6, 200, 104, 30)
const CLOSED_CAPTION_SIZE := 12
const CLOSED_CAPTION_WEIGHT := 700
const CLOSED_CAPTION_OUTLINE := 4
## Two caption lines sit tight, as mock-up B2's 13 px line height does.
const CLOSED_CAPTION_LINE_SPACING := -2
const GROUND_NAME := &"Ground"
const MAT_NAME := &"Mat"
const FOOTPRINT_NAME := &"Footprint"
const TICKET_SHADOW_NAME := &"TicketShadow"
const TARGET_NAME := &"Target"
const PLATE_NAME := &"ClosedPlate"
const PLATE_SHADOW_NAME := &"ClosedPlateShadow"
const NUMBER_NAME := &"SlotNumber"
const MARKS_NAME := &"Marks"
const TALKERS_NAME := &"Talkers"
const RING_NAME := &"Ring"
const HOVER_NAME := &"Hover"
const SIGN_NAME := &"ClosedSign"
const CAPTION_NAME := &"ClosedCaption"

const SLOT_PLACEABLE := preload("res://art/frames/slot_placeable.png")
const SLOT_HOVER := preload("res://art/frames/slot_hover.png")
const TICKET_EMPTY := preload("res://art/frames/ticket_empty.png")
const TICKET_CLOSED := preload("res://art/frames/ticket_closed.png")
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
	var cells: int = count + closed_count
	var separation: int = separation_for(cells)
	for slot: int in range(count):
		box.add_child(_slot_panel(slot, separation))
	for _closed: int in range(closed_count):
		var panel: PanelContainer = _closed_panel(closed_reason, caption)
		closed.append(panel)
		box.add_child(panel)
	box.add_theme_constant_override("separation", separation)
	var natural: Vector2 = Vector2(row_width(cells, separation), CELL_SIZE.y)
	var factor: float = minf(1.0, row_width(LAID_OUT_SLOTS) / natural.x)
	box.scale = Vector2(factor, factor)
	box.size = natural
	custom_minimum_size = natural * factor


## Fills the slots: a belt item for each row card (clicks go to `on_clicked`; `balance` gives
## each item its aisle), and the slot number on each empty mat. Slots up to `placeable_until`
## are ringed for the picked card. Every cell a ride hid shows again, the box back at rest.
## Returns the row's item views, in slot order.
func show_cards(
	row: Array[CardInstance],
	placeable_until: int,
	on_clicked: Callable,
	balance: BalanceDefinition = null
) -> Array[CardView]:
	var views: Array[CardView] = []
	for panel: PanelContainer in slots + closed:
		panel.visible = true
	box.position = Vector2.ZERO
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


## Puts `marks` (SlotMark.marks_for the run's upgrades) on their slots, in place of the ones
## shown: each hangs under the right end of its slot's ticket (slot_mark_rect). A mark for a slot
## the row doesn't have is dropped. The same marks as shown (slot, upgrade and factor) leave the
## shown ones as they are, so a refresh never cuts a firing mark.
func show_slot_marks(marks: Array[SlotMark]) -> void:
	var shown: Array[SlotMark] = []
	for panel: PanelContainer in slots:
		for child: Node in _talkers(panel).get_children():
			if child is SlotMark and not child.is_queued_for_deletion():
				shown.append(child as SlotMark)
	if _same_marks(shown, marks):
		for mark: SlotMark in marks:
			mark.free()
		return
	for panel: PanelContainer in slots:
		var layer: Control = _talkers(panel)
		for child: Node in layer.get_children():
			layer.remove_child(child)
			child.queue_free()
	for mark: SlotMark in marks:
		if mark.slot < 0 or mark.slot >= slots.size():
			mark.free()
			continue
		var rect: Rect2 = slot_mark_rect(mark.size.x)
		mark.position = rect.position
		_talkers(slots[mark.slot]).add_child(mark)


## A SlotMark `width` wide in its cell: right-aligned to SLOT_MARK_RIGHT on the art grid, from
## SLOT_MARK_TOP.
static func slot_mark_rect(width: float) -> Rect2:
	var left: float = snappedf(SLOT_MARK_RIGHT - width, ArtStyle.ART_SCALE)
	return Rect2(left, SLOT_MARK_TOP, width, SlotMark.HEIGHT)


## Whether `shown` are the marks `marks` would show: the same slot, upgrade and factor, in order
## (a mark for a slot the row doesn't have shows nowhere).
func _same_marks(shown: Array[SlotMark], marks: Array[SlotMark]) -> bool:
	var placed: Array[SlotMark] = []
	for mark: SlotMark in marks:
		if mark.slot >= 0 and mark.slot < slots.size():
			placed.append(mark)
	if placed.size() != shown.size():
		return false
	placed.sort_custom(func(a: SlotMark, b: SlotMark) -> bool: return a.slot < b.slot)
	for index: int in range(placed.size()):
		var mark: SlotMark = placed[index]
		var old: SlotMark = shown[index]
		if (
			mark.slot != old.slot
			or mark.upgrade_index != old.upgrade_index
			or mark.factor != old.factor
		):
			return false
	return true


## The mark on `slot` of upgrade `upgrade_index` (any upgrade's for -1), or null.
func slot_mark(slot: int, upgrade_index: int = -1) -> SlotMark:
	if slot < 0 or slot >= slots.size():
		return null
	for child: Node in _talkers(slots[slot]).get_children():
		var mark: SlotMark = child as SlotMark
		if mark != null and not mark.is_queued_for_deletion():
			if upgrade_index < 0 or mark.upgrade_index == upgrade_index:
				return mark
	return null


## The distance from one cell's left edge to the next one's as drawn (the cell and its gap,
## scaled with a wide row): how far the cells ride left for each cell that rides out.
func pitch() -> float:
	return (CELL_SIZE.x + box.get_theme_constant("separation")) * box.scale.x


## Hides every cell up to `cell` (in the row's order: the open slots, then the CLOSED cells) that
## still shows, so the cells after it pack left at once, and moves the box right by the width the
## hidden cells left (a pitch() each), so nothing jumps: the caller slides box.position.x back to
## 0. Returns that width (0 when every one of those cells was hidden already).
func ride_out(cell: int) -> float:
	var cells: Array[PanelContainer] = slots + closed
	var gone: int = 0
	for index: int in range(mini(cell + 1, cells.size())):
		if cells[index].visible:
			cells[index].visible = false
			gone += 1
	if gone == 0:
		return 0.0
	# Packs the cells now, not at the frame's end, so their rects are right for the caller.
	box.notification(Container.NOTIFICATION_SORT_CHILDREN)
	var width: float = gone * pitch()
	box.position.x += width
	return width


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


## The caption of a CLOSED cell: CLOSED_CAPTION_TEXT when one of `inspections` closes slots,
## else empty. The cell's hover text names the inspections.
static func closed_caption(inspections: Array[InspectionDefinition]) -> String:
	for inspection: InspectionDefinition in inspections:
		if inspection.extra_slots < 0:
			return CLOSED_CAPTION_TEXT
	return ""


## A CLOSED cell's caption label.
static func closed_caption_label(panel: PanelContainer) -> Label:
	return panel.get_child(0).get_node(NodePath(CAPTION_NAME)) as Label


## An open slot's blank ticket (shown while the slot is empty), or null (a CLOSED cell).
static func mat(panel: PanelContainer) -> TextureRect:
	return panel.get_node_or_null(NodePath("%s/%s" % [GROUND_NAME, MAT_NAME])) as TextureRect


## An open slot's number (shown while it is empty), or null (a CLOSED cell).
static func slot_number(panel: PanelContainer) -> Label:
	return panel.get_node_or_null(NodePath("%s/%s" % [GROUND_NAME, NUMBER_NAME])) as Label


## An open slot's footprint on the belt (shown while it is empty), or null (a CLOSED cell).
static func footprint(panel: PanelContainer) -> BeltFootprint:
	return (
		panel.get_node_or_null(NodePath("%s/%s" % [GROUND_NAME, FOOTPRINT_NAME])) as BeltFootprint
	)


## A filled slot's ticket shadow (hidden while the slot is empty), or null (a CLOSED cell).
static func ticket_shadow(panel: PanelContainer) -> ColorRect:
	return (
		panel.get_node_or_null(NodePath("%s/%s" % [GROUND_NAME, TICKET_SHADOW_NAME])) as ColorRect
	)


## An open slot's drop target: the control over its column (drop_target_rect) that takes its
## clicks; null for a CLOSED cell.
static func drop_target(panel: PanelContainer) -> Control:
	return panel.get_node_or_null(NodePath("%s/%s" % [GROUND_NAME, TARGET_NAME])) as Control


## Where a drag drops into a slot (global): its column, drop_target_rect; an empty rect for a
## CLOSED cell.
static func drop_rect(panel: PanelContainer) -> Rect2:
	var target: Control = drop_target(panel)
	return target.get_global_rect() if target != null else Rect2()


## An open slot's drop target in a row whose cells are `separation` apart (cell coordinates): from
## DROP_TOP down to the ticket's foot, the cell's width and half the gap on each side, so two
## neighbours' targets meet in the gap's middle and never overlap.
static func drop_target_rect(separation: int) -> Rect2:
	var half_gap: float = separation / 2.0
	return Rect2(-half_gap, DROP_TOP, CELL_SIZE.x + separation, TICKET_RECT.end.y - DROP_TOP)


## Whether a slot shows as empty: its footprint and blank ticket (no item stands on it).
static func shows_empty_mat(panel: PanelContainer) -> bool:
	var slot_mat: TextureRect = mat(panel)
	return slot_mat != null and slot_mat.visible


## The gap between the cells of a row of `count` cells: a row wider than the laid-out one
## closes it before it scales.
static func separation_for(count: int) -> int:
	return SEPARATION if count <= LAID_OUT_SLOTS else WIDE_SEPARATION


## The row's natural width for `count` cells, `separation` apart.
static func row_width(count: int, separation: int = SEPARATION) -> float:
	return count * CELL_SIZE.x + maxi(count - 1, 0) * separation


## An open slot in a row whose cells are `separation` apart: its ground (the drop target, the
## footprint, the ticket's shadow, the blank ticket and the number), then the marks over it. The
## PanelContainer sizes both layers to the cell; their parts are placed in the cell's coordinates
## (the drop target reaches half the gap past the cell's sides), after the talker layer for its
## SlotMark (behind the ticket). Only the drop target takes clicks.
func _slot_panel(slot: int, separation: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = CELL_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var ground: Control = Control.new()
	ground.name = GROUND_NAME
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var target: Control = Control.new()
	target.name = TARGET_NAME
	_child_at(ground, target, drop_target_rect(separation))
	target.mouse_filter = Control.MOUSE_FILTER_STOP
	target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	target.gui_input.connect(func(event: InputEvent) -> void: slot_input.emit(event, slot))
	var print_rect: BeltFootprint = BeltFootprint.new()
	print_rect.name = FOOTPRINT_NAME
	_child_at(ground, print_rect, FOOTPRINT_RECT)
	var shadow: ColorRect = ColorRect.new()
	shadow.name = TICKET_SHADOW_NAME
	shadow.color = Color(Palette.INK, TICKET_SHADOW_ALPHA)
	_child_at(ground, shadow, Rect2(TICKET_RECT.position + TICKET_SHADOW_OFFSET, TICKET_RECT.size))
	var slot_mat: TextureRect = UiKit.sprite(TICKET_EMPTY)
	slot_mat.name = MAT_NAME
	_child_at(ground, slot_mat, TICKET_RECT)
	var number: Label = _slot_number_label(slot)
	number.name = NUMBER_NAME
	_child_at(ground, number, NUMBER_RECT)
	# The talkers first: behind the ticket.
	var talkers: Control = Control.new()
	talkers.name = TALKERS_NAME
	talkers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(talkers)
	panel.add_child(ground)
	panel.add_child(_new_marks())
	_show_empty(panel, true)
	slots.append(panel)
	return panel


## A slot the inspection closed: a velvet rope between two stanchions on the belt, and on the
## rail the ink plate with "CLOSED" over `caption`. The CLOSED label is the cell's first child and
## spans the cell, its text centred on the sign under the plate's band; the plate and its shadow are
## drawn behind it, and the shadows, posts, rope and caption are its children, placed in the
## cell's coordinates.
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
	var plate_shadow: ColorRect = ColorRect.new()
	plate_shadow.name = PLATE_SHADOW_NAME
	plate_shadow.color = Color(Palette.INK, TICKET_SHADOW_ALPHA)
	plate_shadow.show_behind_parent = true
	var shadow_at: Vector2 = CLOSED_PLATE_RECT.position + TICKET_SHADOW_OFFSET
	_child_at(label, plate_shadow, Rect2(shadow_at, CLOSED_PLATE_RECT.size))
	var plate: Panel = Panel.new()
	plate.add_theme_stylebox_override(
		"panel", ArtStyle.frame_style(TICKET_CLOSED, CLOSED_PLATE_MARGIN)
	)
	ArtStyle.use_pixel_material(plate)
	plate.name = PLATE_NAME
	plate.show_behind_parent = true
	_child_at(label, plate, CLOSED_PLATE_RECT)
	var sign_area: Control = Control.new()
	sign_area.name = SIGN_NAME
	_child_at(label, sign_area, CLOSED_SIGN_RECT)
	for index: int in range(POST_RECTS.size()):
		var shadow: ContactShadow = ContactShadow.new()
		shadow.name = "PostShadow%d" % index
		_child_at(label, shadow, POST_SHADOW_RECTS[index])
	for index: int in range(POST_RECTS.size()):
		_child_at(label, _stanchion("Post%d" % index, index == 1), POST_RECTS[index])
	# After the posts: the rope's brass hooks sit over the posts' caps.
	var rope: TextureRect = UiKit.sprite(VELVET_ROPE)
	rope.name = "Rope"
	_child_at(label, rope, ROPE_RECT)
	var caption_label: Label = UiKit.body_label(caption, CLOSED_CAPTION_SIZE, Palette.CREAM_SHADE)
	caption_label.name = CAPTION_NAME
	caption_label.add_theme_font_override("font", caption_font())
	caption_label.add_theme_constant_override("outline_size", CLOSED_CAPTION_OUTLINE)
	caption_label.add_theme_constant_override("line_spacing", CLOSED_CAPTION_LINE_SPACING)
	caption_label.add_theme_color_override("font_outline_color", Palette.INK)
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
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


## A stanchion as tall as POST_RECTS, named `post_name`: the post art's top region over its foot
## region, mirrored (`flipped`) for the right-hand post.
static func _stanchion(post_name: String, flipped: bool) -> Control:
	var post: Control = Control.new()
	post.name = post_name
	var height: float = POST_RECTS[0].size.y
	var regions: Array[Rect2] = [POST_TOP_REGION, POST_FOOT_REGION]
	var tops: Array[float] = [0.0, height - POST_FOOT_REGION.size.y]
	for index: int in range(regions.size()):
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = ROPE_POST
		atlas.region = regions[index]
		var part: TextureRect = UiKit.sprite(atlas)
		part.name = "Top" if index == 0 else "Foot"
		part.flip_h = flipped
		_child_at(post, part, Rect2(Vector2(0, tops[index]), regions[index].size))
	return post


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


static func _talkers(panel: PanelContainer) -> Control:
	return panel.get_node(NodePath(TALKERS_NAME)) as Control


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


## Shows a slot's footprint, blank ticket and number when `empty`; an item covers them
## otherwise, its ticket over the ticket's shadow.
static func _show_empty(panel: PanelContainer, empty: bool) -> void:
	footprint(panel).visible = empty
	mat(panel).visible = empty
	slot_number(panel).visible = empty
	ticket_shadow(panel).visible = not empty


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
