class_name RowStrip
extends Control
## The checkout row's slots (plan section 3.1), one panel per card the shift allows. Upgrades
## can add slots (Extra coupon slot, Big basket), so the panels are rebuilt when the shift's
## card limit changes, and a row wider than the 7 slots the screen was laid out for is scaled
## down to that width (8 slots about x0.87, 9 slots about x0.78). The common 7-slot row is
## never scaled.
##
## A slot the shift's inspection closed (Short belt, Coupon slot closed) shows as a CLOSED panel
## after the open slots: text and a red border, its tooltip naming the inspection. It is never a
## drop target, and the row keeps the run's usual panel count, so an inspection never rescales it.
##
## A plain Control holds the row: a Container would reset the row's scale. `slots` is kept as
## one array, changed in place, because CardDrag holds it.

signal slot_input(event: InputEvent, slot: int)
## A click on a closed slot, so the screen can say why it is closed.
signal closed_clicked

## The width of the 7 slots the screen was laid out for: wider rows are scaled to it.
const LAID_OUT_SLOTS := 7
const SEPARATION := 10

## The row of slot panels (scaled when wide), for the count-up and the drag.
var box: HBoxContainer
var slots: Array[PanelContainer] = []
## The closed panels, after the open slots (never drop targets).
var closed: Array[PanelContainer] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	box = HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", SEPARATION)
	add_child(box)


## Makes one slot panel per card the shift allows, then `closed_count` CLOSED panels (their
## tooltip is `closed_reason`), and scales the row to the laid-out width.
func set_slot_count(count: int, closed_count: int = 0, closed_reason: String = "") -> void:
	if count == slots.size() and closed_count == closed.size():
		for panel: PanelContainer in closed:
			panel.tooltip_text = closed_reason
		return
	for panel: PanelContainer in slots + closed:
		box.remove_child(panel)
		panel.queue_free()
	slots.clear()
	closed.clear()
	for slot: int in range(count):
		box.add_child(_slot_panel(slot))
	for _closed: int in range(closed_count):
		var panel: PanelContainer = _closed_panel(closed_reason)
		closed.append(panel)
		box.add_child(panel)
	var natural: Vector2 = Vector2(row_width(count + closed_count), CardView.CARD_SIZE.y)
	var factor: float = minf(1.0, row_width(LAID_OUT_SLOTS) / natural.x)
	box.scale = Vector2(factor, factor)
	box.size = natural
	custom_minimum_size = natural * factor


## Fills the slots: a card view for each row card (clicks go to `on_clicked`), and the slot
## number in each empty slot. Slots up to `placeable_until` are outlined for the picked card.
## Returns the row's card views, in slot order.
func show_cards(
	row: Array[CardInstance], placeable_until: int, on_clicked: Callable
) -> Array[CardView]:
	var views: Array[CardView] = []
	for slot: int in range(slots.size()):
		var panel: PanelContainer = slots[slot]
		for child: Node in panel.get_children():
			panel.remove_child(child)
			child.queue_free()
		if slot < row.size():
			var view: CardView = CardView.new(row[slot])
			view.clicked.connect(on_clicked)
			panel.add_child(view)
			views.append(view)
		else:
			panel.add_child(_empty_slot_hint(slot))
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		style.border_color = Palette.MUSTARD if slot <= placeable_until else Color(1, 1, 1, 0.15)
	return views


## The row's natural width for `count` slots.
static func row_width(count: int) -> float:
	return count * CardView.CARD_SIZE.x + maxi(count - 1, 0) * SEPARATION


func _slot_panel(slot: int) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = CardView.CARD_SIZE
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.PANEL
	style.border_color = Color(1, 1, 1, 0.15)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	# No content margin: a filled slot stays exactly card-sized, so the row never shifts.
	style.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", style)
	panel.gui_input.connect(func(event: InputEvent) -> void: slot_input.emit(event, slot))
	slots.append(panel)
	return panel


## A slot the inspection closed: CLOSED in red on a dark panel with a red border.
func _closed_panel(reason: String) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = CardView.CARD_SIZE
	panel.tooltip_text = reason
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.BACKGROUND
	style.border_color = Palette.TOMATO
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(0)
	panel.add_theme_stylebox_override("panel", style)
	var label: Label = Label.new()
	label.text = "CLOSED"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", Palette.TOMATO)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(label)
	panel.gui_input.connect(
		func(event: InputEvent) -> void:
			var press: InputEventMouseButton = event as InputEventMouseButton
			if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
				closed_clicked.emit()
	)
	return panel


## An empty panel shows its slot number.
static func _empty_slot_hint(slot: int) -> Label:
	var hint: Label = Label.new()
	hint.text = str(slot + 1)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 28)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.18))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return hint
