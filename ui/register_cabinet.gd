class_name RegisterCabinet
extends Control
## The shift screen's cash register (#80, mock-up B2; greybox, step 3): the printer box on the
## counter top that the receipt rises from, and under it the register column's wooden front with
## the keypad and the cash drawer. CHECKOUT and Redraw (and Cancel) are the stage's buttons, over
## the column. Flat palette fills for now; the register art lands in a later step. It stands at
## ShiftStage.REGISTER_RECT and is the count-up's rattle target; its parts are placed in its own
## coordinates (the stage rects less its position). Display only: it takes no clicks.

## The parts' ink outline, in canvas pixels.
const OUTLINE := 2.0

## Whether the shift is being counted (CHECKOUT held down). Its look comes with the register
## art; for now it is only kept.
var _total_down: bool = false


func _init() -> void:
	name = "Register"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = ShiftStage.REGISTER_RECT.position
	size = ShiftStage.REGISTER_RECT.size
	_add(_panel(Palette.WOOD_DARK), local_rect(ShiftStage.COLUMN_RECT)).name = "Column"
	_add(_panel(Palette.STEEL_PALE), local_rect(ShiftStage.PRINTER_RECT)).name = "Printer"
	_add(_panel(Palette.CHARCOAL), local_rect(ShiftStage.PRINTER_SLOT_RECT)).name = "PrinterSlot"
	_add(_panel(Palette.STEEL), local_rect(ShiftStage.KEYPAD_RECT)).name = "Keypad"
	_add(_panel(Palette.RUBBER), local_rect(ShiftStage.DRAWER_RECT)).name = "Drawer"
	_add(_panel(Palette.STEEL_PALE), local_rect(ShiftStage.DRAWER_PULL_RECT)).name = "Pull"


## Puts CHECKOUT down (the shift is being counted) or up.
func set_total_down(down: bool) -> void:
	_total_down = down


## Whether CHECKOUT is down (the shift is being counted).
func is_total_down() -> bool:
	return _total_down


## A stage rect in the cabinet's own coordinates.
static func local_rect(stage_rect: Rect2) -> Rect2:
	return Rect2(stage_rect.position - ShiftStage.REGISTER_RECT.position, stage_rect.size)


## A flat `color` panel with an ink outline.
static func _panel(color: Color) -> Panel:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Palette.INK
	style.set_border_width_all(int(OUTLINE))
	var panel: Panel = Panel.new()
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _add(node: Control, rect: Rect2) -> Control:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = rect.position
	node.size = rect.size
	add_child(node)
	return node
