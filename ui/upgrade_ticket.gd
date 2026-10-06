class_name UpgradeTicket
extends PanelContainer
## One prize ticket in the upgrade panel (full build plan 5.2). Every ticket shows the same
## fields in the same order: name, type, effect, condition (its own line), supported build.

signal clicked(ticket: UpgradeTicket)

const TICKET_WIDTH := 230.0

var upgrade: UpgradeDefinition
## Whether a click picks it: the panel arms its tickets once the mouse has been released.
## Arming re-applies the hover, so a ticket already under the cursor lights up.
var armed: bool = false:
	set(value):
		armed = value
		_apply_hover()
var _style: StyleBoxFlat
var _hovered: bool = false
var _fields: Array[Label] = []


func _init(ticket_upgrade: UpgradeDefinition) -> void:
	upgrade = ticket_upgrade
	custom_minimum_size = Vector2(TICKET_WIDTH, 230)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_style = StyleBoxFlat.new()
	_style.bg_color = Palette.CREAM
	_style.border_color = Palette.INK
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(8)
	_style.set_content_margin_all(12)
	add_theme_stylebox_override("panel", _style)
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A fixed width from the start, so wrapped lines are measured at the ticket's width.
	column.custom_minimum_size = Vector2(TICKET_WIDTH - 24.0, 0)
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var condition: String = upgrade.condition_text
	_add_field(column, upgrade.display_name, 22, Palette.INK)
	_add_field(column, upgrade.type_label().to_upper(), 12, Palette.TEAL)
	_add_field(column, upgrade.effect_text, 16, Palette.INK)
	# The condition always has its own line; "No condition" keeps the fields in place.
	_add_field(
		column,
		condition if not condition.is_empty() else "No condition",
		14,
		Palette.TOMATO if not condition.is_empty() else Palette.MUTED_INK
	)
	var build: Label = _add_field(
		column, "Supports: %s" % upgrade.supported_build, 13, Palette.MUTED_INK
	)
	build.size_flags_vertical = Control.SIZE_EXPAND_FILL
	build.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM


## The fields' text in display order: name, type, effect, condition, supported build.
func field_texts() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for field: Label in _fields:
		texts.append(field.text)
	return texts


func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
		accept_event()


func _set_hover(hovered: bool) -> void:
	_hovered = hovered
	_apply_hover()


func _apply_hover() -> void:
	if _style == null:
		return
	var lit: bool = _hovered and armed
	_style.border_color = Palette.TOMATO if lit else Palette.INK
	_style.set_border_width_all(4 if lit else 2)


func _add_field(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var label: Label = UiKit.label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	_fields.append(label)
	return label
