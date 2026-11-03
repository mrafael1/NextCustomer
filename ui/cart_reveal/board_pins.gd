class_name BoardPins
extends Control
## The start screen's BADGE PINS (#107's clock-in board, mock-up start_screen.html layout A, part
## 4; 2026-11-03): the badge pins the run wears (RunState.pins, copied from the profile when the run
## was dealt), on the cashier's NameBadge at 2/3 (one art pixel is two screen pixels at 1920x1080),
## each free slot a dashed ring, and beside it each worn pin's name and rule, or "No pin worn" and
## the free slots. Pins change in REWARDS › BADGE PINS, as the foot says: this screen only shows
## them (the 2026-11-03 default, kept until the user answers the mock-up's Q1). Display only.

const RECT := Rect2(846, 440, 392, 176)
const NUMBER_CHIP := Rect2(4, 0, 22, 22)
const TITLE_RECT := Rect2(36, 0, 300, 22)
const TITLE_TEXT := "BADGE PINS"
const BADGE_AT := Vector2(4, 36)
const BADGE_SCALE := 2.0 / 3.0
const TEXT_X := 180.0
const TEXT_TOP := 34.0
const NAME_HEIGHT := 18.0
const RULE_SIZE := 12
const RULE_GAP := 4.0
const PIN_GAP := 8.0
const NONE_TEXT := "No pin worn"
const FREE_TEXT := "%d %s free. Pins give new ways to play, never a bigger payout."
const FOOT_TEXT := "Change pins in REWARDS › BADGE PINS"
const FOOT_SIZE := 12
const FOOT_TOP := 150.0

var pins: Array[PinDefinition] = []
var slots: int = 1
var badge: NameBadge
var _names: Array[Label] = []
var _rules: Array[Label] = []
var _foot: Label


## The block for `worn` pins in `slot_count` badge slots.
func _init(worn: Array[PinDefinition], slot_count: int) -> void:
	name = "BoardPins"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = RECT.position
	size = RECT.size
	pins = worn.duplicate()
	slots = maxi(slot_count, 1)
	var chip: RevealChip = RevealChip.new(
		Palette.MUSTARD, NUMBER_CHIP.size, null, "4", 15, Palette.INK
	)
	chip.position = NUMBER_CHIP.position
	add_child(chip)
	var title: Label = UiKit.pixel_label(TITLE_TEXT, 2, Palette.MUSTARD_LIGHT)
	add_child(title)
	UiKit.place_pixel_label(title, TITLE_RECT, true)
	badge = NameBadge.new()
	badge.position = BADGE_AT
	badge.scale = Vector2.ONE * BADGE_SCALE
	add_child(badge)
	var indexes: Array[int] = []
	for index: int in pins.size():
		indexes.append(index)
	badge.show_pins(pins, slots, indexes)
	var y: float = TEXT_TOP
	var width: float = RECT.size.x - TEXT_X
	if pins.is_empty():
		y = _add_pin_text(NONE_TEXT, _free_text(), y, width)
	for pin: PinDefinition in pins:
		y = _add_pin_text(pin.display_name, pin.rule_text, y, width) + PIN_GAP
	if not pins.is_empty() and pins.size() < slots:
		var free: Label = _rule(_free_text(), width)
		free.position = Vector2(TEXT_X, y)
		add_child(free)
		_rules.append(free)
	_foot = UiKit.body_label(FOOT_TEXT, FOOT_SIZE, Palette.TEAL_LIGHT)
	_foot.add_theme_font_override("font", CartReveal.font(800))
	_foot.position = Vector2(BADGE_AT.x, FOOT_TOP)
	_foot.size = Vector2(RECT.size.x - BADGE_AT.x, 18)
	add_child(_foot)


## The pins' name labels and rule labels (for tests).
func name_labels() -> Array[Label]:
	return _names


func rule_labels() -> Array[Label]:
	return _rules


## The foot pointing to REWARDS (for tests).
func foot() -> Label:
	return _foot


func _free_text() -> String:
	var free: int = slots - pins.size()
	return FREE_TEXT % [free, "slot" if free == 1 else "slots"]


## A pin's name (pixel words) and rule at `y`; returns the y under the rule.
func _add_pin_text(title: String, rule: String, y: float, width: float) -> float:
	var label: Label = UiKit.pixel_label(title, 2, Palette.PAPER)
	add_child(label)
	UiKit.place_pixel_label(label, Rect2(TEXT_X, y, width, NAME_HEIGHT), true)
	_names.append(label)
	var text: Label = _rule(rule, width)
	text.position = Vector2(TEXT_X, y + NAME_HEIGHT + RULE_GAP)
	add_child(text)
	_rules.append(text)
	return text.position.y + text.get_line_count() * text.get_line_height()


func _rule(text: String, width: float) -> Label:
	var label: Label = UiKit.body_label(text, RULE_SIZE, Palette.TEAL_PALE)
	label.add_theme_font_override("font", CartReveal.font(700))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size = Vector2(width, 0)
	return label
