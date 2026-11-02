class_name PriceGunPicker
extends Control
## Price gun's family picker (#132; polished after the 2026-11-02 play review): a paper card cut
## like a price tag (its left end chamfered to a point round a punched hole), its notch pointing
## at the clicked item. A header with the gun's art and "Give <item> a family", a perforation, then
## the families as uniform chips in rows of CHIP_COLUMNS, each in its family's colours and glyph
## (FamilyPalette), lighter on hover; "Remove tag" as a quiet link at the header's right end when
## the item already has one (so the card stays short enough to open under a belt item). It opens
## beside the item, never over the monitor (the 2026-11-02 review: it hid the monitor's item and
## notice): under a belt item, over the baskets, or over a hand item, on the belt (open_at). It
## pops in (at once under reduced motion). It covers the window to catch a click outside the
## card, which closes it, as Escape does.

## Sent with the family chosen ("" for Remove tag).
signal chosen(tag: String)
## Sent when it is dismissed (a click outside the card, Escape).
signal dismissed

const TITLE := "Give %s a family"
const REMOVE_TEXT := "Remove tag"
const GUN_ART := preload("res://art/scenery/price_gun.png")
const TITLE_FONT_SIZE := 18
const CHIP_FONT_SIZE := 14
const REMOVE_FONT_SIZE := 13
const CHIP_COLUMNS := 4
const CHIP_SIZE := Vector2(116, 34)
const CHIP_GAP := 8
## A chip's glyph and name start this far in.
const CHIP_PADDING := 8.0
## The tag's pointed end: its chamfer (px) and the punched hole's centre from the left, its
## radius (the paper behind shows through) and its ring's width; the content starts LEFT_MARGIN
## in, clear of the hole.
const CHAMFER := 18.0
const HOLE_X := 15.0
const HOLE_RADIUS := 3.0
const HOLE_RING := 2.0
const LEFT_MARGIN := 34
const MARGIN := 14
const BORDER := 2.0
## The notch: half its base, its depth; it keeps NOTCH_INSET px from the card's ends.
const NOTCH_HALF := 10.0
const NOTCH_DEPTH := 11.0
const NOTCH_INSET := 30.0
## The card's hard shadow, down and right, ink at SHADOW_ALPHA.
const SHADOW_OFFSET := Vector2(5, 5)
const SHADOW_ALPHA := 0.35
## How far it keeps from the window's edges and the item.
const EDGE := 8.0
const GAP := 4.0
const POP_SECONDS := 0.14
const POP_FROM := 0.85

var _card: PanelContainer
var _chips: Array[Button] = []
var _remove: Button
## The notch's tip in the card's coordinates, and whether it points down (the card above).
var _tip: Vector2 = Vector2.ZERO
var _down: bool = true


## A picker for the item `item_name` offering the families `families` (FamilyPalette's styles);
## with `removable`, Remove tag too.
func _init(item_name: String, families: Array[FamilyStyle], removable: bool) -> void:
	name = "PriceGunPicker"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_card = PanelContainer.new()
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_STOP
	var empty: StyleBoxEmpty = StyleBoxEmpty.new()
	empty.content_margin_left = LEFT_MARGIN
	empty.content_margin_right = MARGIN
	empty.content_margin_top = MARGIN - 4
	empty.content_margin_bottom = MARGIN
	_card.add_theme_stylebox_override("panel", empty)
	_card.draw.connect(_draw_card)
	add_child(_card)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", CHIP_GAP)
	_card.add_child(column)
	var header: HBoxContainer = _header(item_name)
	column.add_child(header)
	var grid: GridContainer = GridContainer.new()
	grid.name = "Chips"
	grid.columns = CHIP_COLUMNS
	grid.add_theme_constant_override("h_separation", CHIP_GAP)
	grid.add_theme_constant_override("v_separation", CHIP_GAP)
	column.add_child(grid)
	for family: FamilyStyle in families:
		_chips.append(_chip(grid, family))
	if removable:
		var take_back: Callable = chosen.emit.bind("")
		_remove = UiKit.button(header, REMOVE_TEXT, take_back, REMOVE_FONT_SIZE, "ui_back")
		_remove.name = "Remove"
		_remove.add_theme_stylebox_override("normal", _remove_box(Palette.PAPER))
		_remove.add_theme_stylebox_override("hover", _remove_box(Palette.CREAM))
		_remove.add_theme_stylebox_override("pressed", _remove_box(Palette.CREAM))
		_remove.add_theme_stylebox_override("hover_pressed", _remove_box(Palette.CREAM))
		_remove.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		_remove.size_flags_horizontal = Control.SIZE_SHRINK_END
		_remove.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_remove.add_theme_font_override("font", ArtStyle.bold_font(600))
		_remove.add_theme_color_override("font_color", Palette.GREY_DARK)
		_remove.add_theme_color_override("font_hover_color", Palette.INK)
		_remove.add_theme_color_override("font_pressed_color", Palette.INK)
		_remove.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Covers `window` and places the card by the item at `target` (screen rects): under it with the
## notch up (a belt item: over the baskets), or, with no room there, over it with the notch down
## (a hand item: on the belt); inside `area` (the stage right of the register column, under the
## top bar) and clear of `avoid` (the monitor) when either side allows it; then pops it in (at
## once when `reduced`).
func open_at(target: Rect2, area: Rect2, window: Rect2, avoid: Rect2, reduced: bool) -> void:
	position = window.position
	size = window.size
	_card.reset_size()
	var card_size: Vector2 = _card.size
	var top: float = area.position.y
	var x: float = clampf(
		target.get_center().x - card_size.x / 2.0,
		area.position.x + EDGE,
		area.end.x - card_size.x - EDGE
	)
	var below: Vector2 = Vector2(x, target.end.y + GAP + NOTCH_DEPTH)
	var above: Vector2 = Vector2(x, target.position.y - GAP - NOTCH_DEPTH - card_size.y)
	var bottom: float = area.end.y - EDGE
	var fits_below: bool = below.y + card_size.y <= bottom
	var fits_above: bool = above.y >= top
	var clear_below: bool = fits_below and not Rect2(below, card_size).intersects(avoid)
	var clear_above: bool = fits_above and not Rect2(above, card_size).intersects(avoid)
	# Neither side clear: under the item, pushed up onto it, rather than over the monitor.
	_down = not clear_below and clear_above
	var at: Vector2 = above if _down else below
	at.y = clampf(at.y, top, bottom - card_size.y)
	_card.position = at
	var tip_x: float = clampf(target.get_center().x - at.x, NOTCH_INSET, card_size.x - NOTCH_INSET)
	_tip = Vector2(tip_x, card_size.y + NOTCH_DEPTH if _down else -NOTCH_DEPTH)
	_card.queue_redraw()
	Sfx.play_at(self, UiKit.OPEN_SOUND)
	if reduced:
		return
	_card.pivot_offset = _tip
	_card.scale = Vector2.ONE * POP_FROM
	_card.modulate.a = 0.0
	var tween: Tween = _card.create_tween().set_parallel()
	(
		tween
		. tween_property(_card, "scale", Vector2.ONE, POP_SECONDS)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)
	tween.tween_property(_card, "modulate:a", 1.0, POP_SECONDS * 0.6)


## The card (the price tag, without its notch).
func card() -> Control:
	return _card


## The family chips, in the offered order.
func chips() -> Array[Button]:
	return _chips


## Remove tag, or null when the item has no tag.
func remove_button() -> Button:
	return _remove


## The notch's tip in screen coordinates.
func notch_tip() -> Vector2:
	return _card.get_global_transform() * _tip


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed:
		accept_event()
		dismissed.emit()


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		dismissed.emit()


func _header(item_name: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Header"
	row.add_theme_constant_override("separation", 10)
	var gun: TextureRect = UiKit.sprite(GUN_ART)
	gun.name = "Gun"
	gun.custom_minimum_size = _gun_size()
	gun.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(gun)
	var title: Label = UiKit.display_label(TITLE % item_name, TITLE_FONT_SIZE, false)
	title.name = "Title"
	title.add_theme_color_override("font_color", Palette.INK)
	title.add_theme_constant_override("outline_size", 0)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_vertical = Control.SIZE_FILL
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title)
	return row


## The header's gun at the art scale, like the rest of the art.
static func _gun_size() -> Vector2:
	return GUN_ART.get_size() * ArtStyle.ART_SCALE


## Remove tag's frame: a thin grey outline on `face`, so it reads as a button beside the title.
static func _remove_box(face: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = face
	box.border_color = Palette.GREY_DARK
	box.set_border_width_all(2)
	box.set_corner_radius_all(3)
	box.content_margin_left = 8.0
	box.content_margin_right = 8.0
	box.content_margin_top = 2.0
	box.content_margin_bottom = 2.0
	return box


## A family's chip: its face colour, a lighter face on hover and its shade pressed, its rimmed
## glyph (as on a ticket) and its name in its text colour.
func _chip(parent: Control, style: FamilyStyle) -> Button:
	var tag: String = style.id
	var chip: Button = UiKit.button(parent, "", chosen.emit.bind(tag), CHIP_FONT_SIZE)
	chip.name = "Chip%s" % tag
	chip.custom_minimum_size = CHIP_SIZE
	chip.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	chip.tooltip_text = style.display_name
	var text: Color = Palette.PAPER if style.paper_text else Palette.INK
	chip.add_theme_stylebox_override("normal", _chip_box(style.face))
	chip.add_theme_stylebox_override("hover", _chip_box(style.light))
	chip.add_theme_stylebox_override("pressed", _chip_box(style.shade))
	chip.add_theme_stylebox_override("hover_pressed", _chip_box(style.shade))
	chip.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = CHIP_PADDING
	row.offset_right = -CHIP_PADDING
	chip.add_child(row)
	if style.glyph != null:
		var glyph: FamilyGlyph = FamilyGlyph.new(style, true)
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(glyph)
	var label: Label = UiKit.body_label(tag, CHIP_FONT_SIZE, text)
	label.name = "Name"
	label.add_theme_font_override("font", ArtStyle.bold_font(700))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_vertical = Control.SIZE_FILL
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return chip


static func _chip_box(colour: Color) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = colour
	box.border_color = Palette.INK
	box.set_border_width_all(2)
	box.set_corner_radius_all(4)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	box.shadow_color = Color(Palette.INK, SHADOW_ALPHA)
	box.shadow_offset = Vector2(0, 2)
	return box


## The price tag: its shadow, the paper with its ink outline (the notch part of it), the punched
## hole and the header's perforation.
func _draw_card() -> void:
	var outline: PackedVector2Array = _outline(_card.size)
	var shadow: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in outline:
		shadow.append(point + SHADOW_OFFSET)
	_card.draw_colored_polygon(shadow, Color(Palette.INK, SHADOW_ALPHA))
	_card.draw_colored_polygon(outline, Palette.PAPER)
	var closed: PackedVector2Array = outline.duplicate()
	closed.append(outline[0])
	_card.draw_polyline(closed, Palette.INK, BORDER * 2.0)
	# The punched hole: an ink ring with the cream behind the tag showing through.
	var hole: Vector2 = Vector2(HOLE_X, _card.size.y / 2.0)
	_card.draw_circle(hole, HOLE_RADIUS + HOLE_RING, Palette.INK)
	_card.draw_circle(hole, HOLE_RADIUS, Palette.CREAM_SHADE)
	var perforation: float = MARGIN - 4 + _gun_size().y + CHIP_GAP / 2.0
	var x: float = float(LEFT_MARGIN)
	while x < _card.size.x - MARGIN:
		_card.draw_rect(Rect2(x, perforation - 1.0, 6.0, 2.0), Palette.CREAM_SHADE)
		x += 10.0


## The tag's outline, clockwise from the top of its chamfer, with the notch on its bottom (or top).
func _outline(card_size: Vector2) -> PackedVector2Array:
	var w: float = card_size.x
	var h: float = card_size.y
	var points: PackedVector2Array = PackedVector2Array([Vector2(CHAMFER, 0.0)])
	if not _down and _tip != Vector2.ZERO:
		(
			points
			. append_array(
				[
					Vector2(_tip.x - NOTCH_HALF, 0.0),
					_tip,
					Vector2(_tip.x + NOTCH_HALF, 0.0),
				]
			)
		)
	points.append_array([Vector2(w, 0.0), Vector2(w, h)])
	if _down and _tip != Vector2.ZERO:
		(
			points
			. append_array(
				[
					Vector2(_tip.x + NOTCH_HALF, h),
					_tip,
					Vector2(_tip.x - NOTCH_HALF, h),
				]
			)
		)
	points.append_array([Vector2(CHAMFER, h), Vector2(0.0, h - CHAMFER), Vector2(0.0, CHAMFER)])
	return points
