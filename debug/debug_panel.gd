extends PanelContainer
## Debug panel (development builds only; plan section 2): set the seed, add any card to the hand,
## give an upgrade, set the shift's inspection, skip to a shift, (temporarily) the count-up's
## speed and reduced motion settings, and the Profile tools (#63: give coins, draw from a TOY
## MACHINE, unlock or reset the collection). F1 shows or hides it. Its column scrolls when it is
## taller than the window allows. Playtest exports leave out debug/, and
## other scripts never name this class: the shift screen loads the scene by path and connects to
## these signals by name.

signal seed_requested(seed_value: int)
signal card_requested(card_id: String)
signal upgrade_requested(upgrade_id: String)
## An empty id clears the shift's inspection.
signal inspection_requested(inspection_id: String)
signal shift_requested(shift_number: int)
## TEMPORARY (#60): the count-up speed setting, Fast or Normal. Phase 4's settings screen
## replaces it.
signal count_up_speed_requested(fast: bool)
## TEMPORARY (#60): the reduced motion setting. Phase 4's settings screen replaces it.
signal reduced_motion_requested(on: bool)
## Profile tools (#63): coins given to the profile.
signal coins_requested(amount: int)
## Profile tools (#63): a capsule from this aisle's TOY MACHINE (the real draw, no coin spent).
signal capsule_requested(aisle_id: String)
## Profile tools (#63): every capsule item unlocked.
signal unlock_all_requested
## Profile tools (#63): every capsule item locked again.
signal reset_collection_requested

const CARDS_FOLDER := "res://data/cards"
const AISLES_FOLDER := "res://data/aisles"
## The column's most height before it scrolls: the panel (60 px from the top, 12 px margins)
## stays inside a 720 px window.
const MAX_COLUMN_HEIGHT := 620.0
const UPGRADES_FOLDER := "res://data/upgrades"
const INSPECTIONS_FOLDER := "res://data/inspections"
const NO_INSPECTION := "(no inspection)"

var _seed_input: SpinBox
var _card_choice: OptionButton
var _upgrade_choice: OptionButton
var _inspection_choice: OptionButton
var _shift_input: SpinBox
var _fast_count_up: CheckBox
var _reduced_motion: CheckBox
var _aisle_choice: OptionButton
var _scroll: ScrollContainer
var _column: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	# 20 px from the right edge and 60 from the top, from offsets: a position set here would
	# depend on the screen's size at this moment (in a test, the panel ended off screen).
	offset_left = -20
	offset_right = -20
	offset_top = 60
	offset_bottom = 60
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.set_content_margin_all(12)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	var column: VBoxContainer = VBoxContainer.new()
	_column = column
	_scroll.add_child(column)
	column.minimum_size_changed.connect(_fit_scroll)
	var title: Label = Label.new()
	title.text = "DEBUG (F1)"
	column.add_child(title)

	# Run seeds come from RandomNumberGenerator.randi(): 0 to 2^32 - 1.
	_seed_input = _spin(column, 0, 4294967295)
	_button(column, "New run with this seed", _on_seed_pressed)

	_card_choice = _file_choice(column, CARDS_FOLDER)
	_button(column, "Add card to hand", _on_card_pressed)

	_upgrade_choice = _file_choice(column, UPGRADES_FOLDER)
	_button(column, "Give upgrade (restarts the shift)", _on_upgrade_pressed)

	_inspection_choice = _file_choice(column, INSPECTIONS_FOLDER)
	_inspection_choice.add_item(NO_INSPECTION)
	_button(column, "Set inspection (restarts the shift)", _on_inspection_pressed)

	# The run length comes from balance data: set_shift_count() sets the maximum.
	_shift_input = _spin(column, 1, 1)
	_button(column, "Skip to shift", _on_shift_pressed)

	# TEMPORARY (#60): the count-up settings until phase 4's settings screen replaces them.
	_fast_count_up = _check(column, "Count-up speed: Fast", count_up_speed_requested.emit)
	_reduced_motion = _check(column, "Reduced motion", reduced_motion_requested.emit)

	# Profile tools (#63): they change the saved profile, so the stock changes from the next run.
	var profile_title: Label = Label.new()
	profile_title.text = "Profile (stock changes next run)"
	column.add_child(profile_title)
	_button(column, "Give 1 coin", coins_requested.emit.bind(1))
	_button(column, "Give 5 coins", coins_requested.emit.bind(5))
	_aisle_choice = _file_choice(column, AISLES_FOLDER)
	_button(column, "Draw from machine", _on_capsule_pressed)
	_button(column, "Unlock all capsules", unlock_all_requested.emit)
	_button(column, "Reset collection", reset_collection_requested.emit)
	_fit_scroll()
	visible = false


## Called by the shift screen with the number of shifts in a run.
func set_shift_count(count: int) -> void:
	_shift_input.max_value = count


## TEMPORARY (#60): called by the shift screen with the profile's count-up settings. Doesn't
## emit the settings' signals.
func set_count_up_settings(fast: bool, reduced_motion: bool) -> void:
	_fast_count_up.set_pressed_no_signal(fast)
	_reduced_motion.set_pressed_no_signal(reduced_motion)


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key and key.pressed and not key.echo and key.keycode == KEY_F1:
		visible = not visible
		get_viewport().set_input_as_handled()


func _on_seed_pressed() -> void:
	seed_requested.emit(int(_seed_input.value))


func _on_card_pressed() -> void:
	if _card_choice.selected >= 0:
		card_requested.emit(_card_choice.get_item_text(_card_choice.selected))


func _on_upgrade_pressed() -> void:
	if _upgrade_choice.selected >= 0:
		upgrade_requested.emit(_upgrade_choice.get_item_text(_upgrade_choice.selected))


func _on_inspection_pressed() -> void:
	if _inspection_choice.selected < 0:
		return
	var choice: String = _inspection_choice.get_item_text(_inspection_choice.selected)
	inspection_requested.emit("" if choice == NO_INSPECTION else choice)


func _on_shift_pressed() -> void:
	shift_requested.emit(int(_shift_input.value))


func _on_capsule_pressed() -> void:
	if _aisle_choice.selected >= 0:
		capsule_requested.emit(_aisle_choice.get_item_text(_aisle_choice.selected))


## The scroll area is as tall as the column, up to MAX_COLUMN_HEIGHT.
func _fit_scroll() -> void:
	var height: float = minf(_column.get_combined_minimum_size().y, MAX_COLUMN_HEIGHT)
	_scroll.custom_minimum_size = Vector2(0, height)


## A list of the resource files in a data folder, by file name (the id).
func _file_choice(parent: Control, folder: String) -> OptionButton:
	var choice: OptionButton = OptionButton.new()
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".tres"):
			choice.add_item(file.get_basename())
	parent.add_child(choice)
	return choice


func _spin(parent: Control, min_value: int, max_value: int) -> SpinBox:
	var spin: SpinBox = SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.rounded = true
	parent.add_child(spin)
	return spin


func _check(parent: Control, text: String, action: Callable) -> CheckBox:
	var check: CheckBox = CheckBox.new()
	check.text = text
	check.toggled.connect(action)
	parent.add_child(check)
	return check


func _button(parent: Control, text: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
