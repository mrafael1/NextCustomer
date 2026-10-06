class_name TitleScreen
extends Control
## The title screen (plan section 7): a click starts the game, which also lets browsers play
## audio. The Export log button works here too, so testers can send their log at any time.

const SHIFT_SCREEN := "res://ui/shift_screen.tscn"

## Tests turn this off so starting doesn't replace the test runner's scene.
var changes_scene: bool = true
var _starting: bool = false
@onready var _log: EventLogService = get_node("/root/EventLog")


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var background: ColorRect = ColorRect.new()
	background.color = Palette.BACKGROUND
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.gui_input.connect(_on_background_input)
	add_child(background)

	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 18)
	add_child(column)
	var title: Label = UiKit.label("NEXT CUSTOMER", 84, Palette.MUSTARD)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_constant_override("outline_size", 14)
	title.add_theme_color_override("font_outline_color", Palette.INK)
	column.add_child(title)
	var subtitle: Label = UiKit.label(
		"Scan groceries and coupons in the best order. Meet the quota every shift.",
		22,
		Palette.LIGHT_TEXT
	)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(subtitle)
	var prompt: Label = UiKit.label("Click anywhere to start", 30, Palette.CREAM)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(prompt)
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(prompt, "modulate:a", 0.35, 0.7)
	pulse.tween_property(prompt, "modulate:a", 1.0, 0.7)

	var corner: HBoxContainer = HBoxContainer.new()
	corner.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	corner.offset_top = -56
	corner.offset_left = 20
	corner.offset_right = -20
	corner.offset_bottom = -16
	add_child(corner)
	UiKit.button(corner, "Export log", _on_export_pressed, 16)
	var build: Label = UiKit.label(
		str(ProjectSettings.get_setting("next_customer/build_label", "")), 14, Palette.LIGHT_TEXT
	)
	build.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	build.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	corner.add_child(build)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key and key.pressed and (key.keycode == KEY_ENTER or key.keycode == KEY_SPACE):
		_start()


func _on_background_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		_start()


func _on_export_pressed() -> void:
	_log.export_logs("title")


func _start() -> void:
	if _starting:
		return
	_starting = true
	if changes_scene:
		get_tree().change_scene_to_file(SHIFT_SCREEN)
