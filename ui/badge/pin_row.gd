class_name PinRow
extends Button
## One badge pin on the badge screen (#122): a paper card with an ink border (a gold ring when
## marked or under the mouse), the pin's face (PinFace), its name and rule, and its state on the
## right: WORN (teal), WEAR (owned, not worn) or LOCKED with its milestone in place of the rule.
## Pressing it is the screen's to answer (BadgeScreen wears, takes off or refuses).

enum State { LOCKED, OWNED, WORN }

const SIZE := Vector2(360, 72)
const BORDER := 2.0
const RING := 2.0
const FACE_AT := Vector2(12, 12)
const FACE_SIZE := 48.0
const NAME_AT := Vector2(72, 8)
const RULE_RECT := Rect2(72, 30, 196, 40)
const RULE_SIZE := 13
const STATE_RIGHT := 12.0
const STATE_TOP := 24.0
const STATE_HEIGHT := 24.0
const STATE_WORDS: Array[String] = ["LOCKED", "WEAR", "WORN"]

## The keyboard marker is on this row (the screen sets it): it looks hot, as under the mouse.
var marked: bool = false:
	set(value):
		marked = value
		queue_redraw()
var pin: PinDefinition

var _state: State = State.LOCKED
var _face: PinFace
var _name: Label
var _rule: Label
var _state_label: Label
## The state chip, right-aligned in the row.
var _chip: Rect2


## The row of `row_pin`, the `index`-th pin of the catalogue.
func _init(row_pin: PinDefinition, index: int) -> void:
	pin = row_pin
	name = "Pin_%s" % row_pin.id
	flat = true
	focus_mode = Control.FOCUS_NONE
	size = SIZE
	custom_minimum_size = SIZE
	mouse_default_cursor_shape = CURSOR_POINTING_HAND
	accessibility_name = row_pin.display_name
	_face = PinFace.new(FACE_SIZE)
	_face.position = FACE_AT
	add_child(_face)
	_name = UiKit.pixel_label(row_pin.display_name.to_upper(), 2, Palette.INK)
	_name.position = NAME_AT
	add_child(_name)
	_rule = UiKit.body_label("", RULE_SIZE, Palette.INK_LIGHT)
	_rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rule.position = RULE_RECT.position
	_rule.size = RULE_RECT.size
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rule)
	_state_label = UiKit.pixel_label("", 2, Palette.PAPER)
	add_child(_state_label)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	show_state(State.LOCKED, index)


## Shows the pin `shown` (its catalogue place `index` gives its colour).
func show_state(shown: State, index: int) -> void:
	_state = shown
	var locked: bool = shown == State.LOCKED
	_face.show_pin(pin, index, locked)
	var condition: UnlockCondition = pin.unlock_condition
	_rule.text = (
		"Unlock: %s" % condition.summary() if locked and condition != null else pin.rule_text
	)
	_state_label.text = STATE_WORDS[shown]
	var width: float = UiKit.pixel_text_size(_state_label).x + 12.0
	_chip = Rect2(SIZE.x - STATE_RIGHT - width, STATE_TOP, width, STATE_HEIGHT)
	UiKit.place_pixel_label(_state_label, _chip, true)
	_state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	queue_redraw()


func state() -> State:
	return _state


func face() -> PinFace:
	return _face


func rule_label() -> Label:
	return _rule


func state_label() -> Label:
	return _state_label


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, SIZE)
	if marked or is_hovered():
		draw_rect(rect.grow(RING), Palette.GOLD)
	draw_rect(rect, Palette.INK)
	var paper: Color = Palette.CREAM if _state == State.LOCKED else Palette.PAPER
	draw_rect(rect.grow(-BORDER), paper)
	var colours: Array[Color] = [Palette.GREY, Palette.INK_LIGHT, Palette.TEAL]
	draw_rect(_chip.grow(BORDER), Palette.INK)
	draw_rect(_chip, colours[_state])
