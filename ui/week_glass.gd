class_name WeekGlass
extends Control
## The register's week glass (v1.17, the user's pick of 2026-11-08: mock-up
## docs/art/mockups/main_scene_v2.html, drawRegA's glass with no pips, option "7a"), in the
## keypad's place on the key deck and in place of the top bar's week chip: a small dark teal LCD
## glass with a lit top row and a bevel, reading WEEK, the week's number big in the chunky digits
## with "/4" after it (the run's weeks), the pair centred on the glass (the days-left line under
## them went on the user's 2026-11-08 feedback: it took room and told nothing the day calendar
## does not). The day pips live on the day calendar only (DayCalendar).
## Tapping it reopens the time card (`pressed`, WeekFlow.reopen); hovering shows the week's name
## and effect; the planning effects ring it in gold when the hovered item's effect is the week
## event's (set_relation); the count-up plays the week event's steps from it, and the time card
## flies into it as it closes. Hidden for a run without weeks (the keypad shows) and while Cancel
## stands in its place (covered). Words drawn in whole stage px (PixelWords), crisp at 1.5x.

signal pressed

const TIP := "%s\nClick to open the time card"
const TIP_CLICK := "TIME CARD"
const NO_EVENT := "No event this week."
const CLOCK := preload("res://art/icons/clock.png")
const TIP_EVENT := "%s · %s · %s"
const WEEK_WORD := "WEEK"
## The glass in its rect (ShiftStage.WEEK_GLASS_RECT, local px): the steel backdrop, the ink
## frame, the teal black inside, its lit top rows and its bevel column. The frame reaches the
## rect's right edge (the key deck's border), so the words have a margin past the bevel.
const FRAME_RECT := Rect2(4, 2, 90, 88)
const INSIDE_RECT := Rect2(6, 4, 86, 84)
const TOP_ROWS := 2
const BEVEL := 2
## The keypad's seam from the function keys (art/src/scenery/register_keypad.txt's first two
## columns, rubber then steel dark, 2 stage px each) left of the frame, where the keypad drew it.
const SEAM_RECT := Rect2(0, 2, 4, 86)
## The words: the gap from WEEK's foot to the number's top (the pair centred on the inside, the
## count's foot on the number's); the number's and the words' font px.
const WORDS_GAP := 4.0
const NUMBER_CELL := 4.0
const WORD_CELL := 2.0
const COUNT_GAP := 4.0
const RING_WIDTH := 2.0

## Whether the run has weeks (show_week): the glass shows unless covered.
var has_week: bool = false
## Cancel stands in its place (RegisterCabinet): hidden.
var covered: bool = false:
	set(value):
		covered = value
		_refresh_visible()
var week_label: PixelWords
var number_label: PixelWords
var count_label: PixelWords
var _ringed: bool = false


func _init() -> void:
	name = "WeekGlass"
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	week_label = _words(WEEK_WORD, PixelWords.Sheet.CAPS, WORD_CELL, Palette.TEAL_LIGHT)
	number_label = _words("", PixelWords.Sheet.CHUNKY, NUMBER_CELL, Palette.GLASS_GLOW)
	count_label = _words("", PixelWords.Sheet.CHUNKY, WORD_CELL, Palette.TEAL_LIGHT)
	visible = false


## Shows `model`'s week: its number and count, and its tooltip. `weeks`: whether
## the run has weeks (WeekFlow.has_weeks, the time card's gate); hidden without them.
func show_week(model: WeekCardModel, weeks: bool) -> void:
	has_week = weeks
	number_label.text = str(model.week_number)
	count_label.text = model.count_text() if model.week_count > 1 else ""
	var head: String = model.head()
	if model.event != null:
		head = TIP_EVENT % [head, model.title(), model.effect()]
	var made: TipSpec = TipSpec.make(TipSpec.Kind.STATUS, model.head(), "")
	made.icon = CLOCK
	made.click = TIP_CLICK
	made.source = TIP % head
	if model.event != null:
		made.tag = model.title()
		var notice: String = model.event.notice_text
		if notice.is_empty():
			# Its effect as a sentence: a capital first letter only (not String.capitalize).
			notice = model.effect().left(1).to_upper() + model.effect().substr(1)
		made.body = TipMarkup.auto(notice)
		if model.event.forgives_slips:
			made.live = model.misses_left_text()
	else:
		made.body = NO_EVENT
	TipTarget.cover_control(self, made)
	_layout()
	_refresh_visible()


## Rings the glass in gold while the hovered item's effect is the week event's (#71's rings).
func set_relation(related: bool) -> void:
	_ringed = related
	queue_redraw()


func has_relation() -> bool:
	return _ringed


func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.STEEL_DARKEST)
	var seam: Vector2 = Vector2(SEAM_RECT.size.x / 2.0, SEAM_RECT.size.y)
	draw_rect(Rect2(SEAM_RECT.position, seam), Palette.RUBBER)
	draw_rect(Rect2(SEAM_RECT.position + Vector2(seam.x, 0), seam), Palette.STEEL_DARK)
	draw_rect(FRAME_RECT, Palette.INK)
	draw_rect(INSIDE_RECT, Palette.TEAL_BLACK)
	var top: Vector2 = INSIDE_RECT.position
	draw_rect(Rect2(top, Vector2(INSIDE_RECT.size.x, TOP_ROWS)), Palette.TEAL_SHADE)
	draw_rect(
		Rect2(top + Vector2(0, TOP_ROWS), Vector2(INSIDE_RECT.size.x, TOP_ROWS)), Palette.TEAL_DARK
	)
	var column: Rect2 = Rect2(
		top + Vector2(0, TOP_ROWS * 2), Vector2(BEVEL, INSIDE_RECT.size.y - TOP_ROWS * 2)
	)
	draw_rect(column, Palette.TEAL_DARK)
	if _ringed:
		draw_rect(
			Rect2(Vector2.ZERO, size).grow(-RING_WIDTH / 2.0), Palette.GOLD, false, RING_WIDTH
		)


## The words centred on the inside past the bevel, on even px (the art's grid): WEEK over the
## number with its count (their feet level), the pair centred top to bottom.
func _layout() -> void:
	var middle: float = (INSIDE_RECT.position.x + BEVEL + INSIDE_RECT.end.x) / 2.0
	var number: Vector2 = number_label.get_combined_minimum_size()
	var word: Vector2 = week_label.get_combined_minimum_size()
	var top: float = _even(INSIDE_RECT.get_center().y - (word.y + WORDS_GAP + number.y) / 2.0)
	_centre(week_label, middle, top)
	var number_top: float = top + word.y + WORDS_GAP
	var count: Vector2 = count_label.get_combined_minimum_size()
	var group: float = number.x + (COUNT_GAP + count.x if count.x > 0.0 else 0.0)
	var left: float = _even(middle - group / 2.0)
	number_label.position = Vector2(left, number_top)
	number_label.size = number
	count_label.position = Vector2(left + number.x + COUNT_GAP, number_top + number.y - count.y)
	count_label.size = count


func _refresh_visible() -> void:
	visible = has_week and not covered


func _words(words: String, sheet: PixelWords.Sheet, cell: float, ink: Color) -> PixelWords:
	var label: PixelWords = PixelWords.new(words, sheet, cell, ink)
	add_child(label)
	return label


static func _centre(label: PixelWords, middle: float, top: float) -> void:
	var shown: Vector2 = label.get_combined_minimum_size()
	label.position = Vector2(_even(middle - shown.x / 2.0), top)
	label.size = shown


static func _even(x: float) -> float:
	return roundf(x / 2.0) * 2.0
