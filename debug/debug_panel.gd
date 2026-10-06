extends PanelContainer
## Debug panel (development builds only; plan section 2): set the seed, add any card to the
## hand, give an upgrade, skip to a shift. F1 shows or hides it. Playtest exports leave out
## debug/, and other scripts never name this class: the shift screen loads the scene by path
## and connects to these signals by name.

signal seed_requested(seed_value: int)
signal card_requested(card_id: String)
signal upgrade_requested(upgrade_id: String)
signal shift_requested(shift_number: int)

const CARDS_FOLDER := "res://data/cards"
const UPGRADES_FOLDER := "res://data/upgrades"

var _seed_input: SpinBox
var _card_choice: OptionButton
var _upgrade_choice: OptionButton
var _shift_input: SpinBox


func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	position = Vector2(-20, 60)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.85)
	style.set_content_margin_all(12)
	style.set_corner_radius_all(6)
	add_theme_stylebox_override("panel", style)
	var column: VBoxContainer = VBoxContainer.new()
	add_child(column)
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

	# The run length comes from balance data: set_shift_count() sets the maximum.
	_shift_input = _spin(column, 1, 1)
	_button(column, "Skip to shift", _on_shift_pressed)
	visible = false


## Called by the shift screen with the number of shifts in a run.
func set_shift_count(count: int) -> void:
	_shift_input.max_value = count


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


func _on_shift_pressed() -> void:
	shift_requested.emit(int(_shift_input.value))


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


func _button(parent: Control, text: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
