class_name TitleScreen
extends Control
## The title screen (plan section 7): a click starts the game, which also lets browsers play
## audio. The Export log button works here too, so testers can send their log at any time. It
## shows the run's length from balance data and the profile's coins (full build plan 7.1).
##
## When a run save can be read (full build plan section 4), the title offers Continue (the
## shift screen resumes the save) and New run instead, and a background click starts nothing.
## Enter or Space continues. New run asks first; on yes the saved run is abandoned (deleted,
## and logged as run_abandon under its run id) and a new run starts. An abandoned run records
## nothing in the profile, like a restart before the end.

const SHIFT_SCREEN := "res://ui/shift_screen.tscn"
const BALANCE := "res://data/balance/balance.tres"
const ABANDON_QUESTION := "Abandon the run in progress? It won't count."

## Tests turn this off so starting doesn't replace the test runner's scene.
var changes_scene: bool = true
var _starting: bool = false
var _subtitle: Label
var _coins: Label
## The run save found at start, or null. Read without reporting or backing up anything: the
## shift screen does that when it loads the save.
var _saved_run: RunSave
var _continue_button: Button
var _new_run_button: Button
## The New run confirmation, over a shade that blocks clicks behind it.
var _confirm_shade: ColorRect
var _confirm: PanelContainer
var _abandon_button: Button
var _keep_button: Button
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
	var balance: BalanceDefinition = load(BALANCE)
	_subtitle = UiKit.label(
		(
			"Scan groceries and coupons in the best order. Meet the quota on all %d shifts."
			% balance.quotas.size()
		),
		22,
		Palette.LIGHT_TEXT
	)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_subtitle)
	var saves: SaveService = SaveService.new(SaveService.default_folder())
	_coins = UiKit.label(coins_text(saves), 22, Palette.MUSTARD)
	_coins.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_coins)
	_saved_run = saves.peek_run(ContentLookup.new(balance))
	if _saved_run == null:
		_add_prompt(column)
	else:
		_add_run_buttons(column)

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
	if _saved_run != null:
		_add_confirmation()


## The coin line: the saved profile's coins, read without reporting or backing anything up (the
## shift screen does that when it loads the profile).
static func coins_text(saves: SaveService) -> String:
	var profile: ProfileState = saves.peek_profile()
	if profile == null:
		return "Coins: ?"
	return "Coins: %d" % profile.coins


## The Continue button's text: the saved run's shift out of the run's shifts.
static func continue_text(saved: RunSave) -> String:
	return "Continue (shift %d / %d)" % [saved.run.shift_index + 1, saved.run.shift_count()]


func _add_prompt(column: VBoxContainer) -> void:
	var prompt: Label = UiKit.label("Click anywhere to start", 30, Palette.CREAM)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(prompt)
	var pulse: Tween = create_tween().set_loops()
	pulse.tween_property(prompt, "modulate:a", 0.35, 0.7)
	pulse.tween_property(prompt, "modulate:a", 1.0, 0.7)


func _add_run_buttons(column: VBoxContainer) -> void:
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 24)
	column.add_child(buttons)
	_continue_button = UiKit.button(buttons, continue_text(_saved_run), _on_continue_pressed, 26)
	_new_run_button = UiKit.button(buttons, "New run", _on_new_run_pressed, 26)
	for button: Button in [_continue_button, _new_run_button]:
		button.custom_minimum_size = Vector2(200, 64)


## The New run question, hidden until New run is pressed. Added last, so it sits above
## everything else.
func _add_confirmation() -> void:
	_confirm_shade = ColorRect.new()
	_confirm_shade.color = Color(0, 0, 0, 0.5)
	_confirm_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_shade.visible = false
	add_child(_confirm_shade)
	_confirm = UiKit.paper_panel()
	_confirm.visible = false
	add_child(_confirm)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	_confirm.add_child(column)
	var question: Label = UiKit.label(ABANDON_QUESTION, 26, Palette.INK)
	question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(question)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	_abandon_button = UiKit.button(buttons, "Yes, start a new run", _on_abandon_confirmed, 20)
	_keep_button = UiKit.button(buttons, "No, keep it", _on_abandon_cancelled, 20)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if not (key and key.pressed and (key.keycode == KEY_ENTER or key.keycode == KEY_SPACE)):
		return
	if _saved_run == null:
		_start()
	elif not _confirm.visible:
		_on_continue_pressed()


## Without a run save, a click anywhere starts. With one, only the buttons do.
func _on_background_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		if _saved_run == null:
			_start()


func _on_export_pressed() -> void:
	_log.export_logs("title")


## The shift screen resumes the save.
func _on_continue_pressed() -> void:
	_start()


func _on_new_run_pressed() -> void:
	if _starting:
		return
	_confirm_shade.visible = true
	UiKit.pop_in(_confirm)


func _on_abandon_cancelled() -> void:
	_confirm_shade.visible = false
	_confirm.visible = false


## Deletes the saved run and starts a new one. If the save can't be deleted (reported), the
## title stays as it is: the shift screen would only resume it.
func _on_abandon_confirmed() -> void:
	if _starting:
		return
	if not SaveService.new(SaveService.default_folder()).delete_run():
		_on_abandon_cancelled()
		return
	_log.resume_run(_saved_run.run_id)
	_log.log_event("run_abandon", RunEvents.run_abandon(_saved_run.run, _saved_run.run_ms))
	_start()


func _start() -> void:
	if _starting:
		return
	_starting = true
	if changes_scene:
		get_tree().change_scene_to_file(SHIFT_SCREEN)
