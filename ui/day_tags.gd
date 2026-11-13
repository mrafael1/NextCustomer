class_name DayTags
extends HBoxContainer
## The day calendar's tags (v1.17; the day chip's since #77 machine v2 and #132), right of the pad:
## the bonus ticket's mustard pill (PROMISED: "PASS ›", the ticket icon, "+1 BONUS TICKET", bold
## Atkinson PILL_SIZE in a 2 px ink border; EARNED keeps the icon and "+1 BONUS TICKET") and a
## Day off pin's teal "SKIP ›" tag ("UNDO ‹" armed, mustard), which a tap says `skip_pressed`.
## While the run wears a Day off the SKIP tag's room is kept on every day (show_skip's
## `reserved`), so the tag coming and going never moves the bar. When the bar is short of room
## (fit) the pill gives up its "PASS ›", then its words down to "+1"; today's slip keeps the line
## (WeekFlow.bonus_line; DayCalendar gives the pill its hover).

## The SKIP tag was tapped (PinFlow arms, then takes the day off).
signal skip_pressed

const PASS_WORD := "QUOTA MET ›"
const PILL_TEXT := "+1 EXTRA DRAW"
## The pill's text when the top bar has no room for it whole.
const PILL_SHORT := "+1"
const SKIP_TEXT := "SKIP ›"
const SKIP_ARMED_TEXT := "UNDO ‹"
const PILL_SIZE := 12
const PILL_WEIGHT := 800
const PILL_PAD := Vector2(6, 1)
const PILL_GAP := 4
## The tags' gap.
const SEPARATION := 8
const TICKET := preload("res://art/icons/bonus_ticket.png")

var _pill: PanelContainer
var _pass_word: Label
var _pill_label: Label
var _skip: PanelContainer
var _skip_label: Label
var _skip_reserved: bool = false
var _promised: bool = false
var _pass_hidden: bool = false


func _init() -> void:
	name = "DayTags"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", SEPARATION)
	_pill = _make_pill()
	add_child(_pill)
	_skip = _make_skip()
	add_child(_skip)


## The pill for the bonus `state` (InspectionTag.Bonus): hidden for NONE, "PASS ›" only while
## PROMISED (and the bar has room).
func show_bonus(state: InspectionTag.Bonus) -> void:
	_promised = state == InspectionTag.Bonus.PROMISED
	_pill.visible = state != InspectionTag.Bonus.NONE
	_pass_word.visible = _promised and not _pass_hidden


## Shows the SKIP tag, "UNDO ‹" while `armed`, or hides it; `reserved` keeps its room hidden.
## Returns whether the tags' width changed.
func show_skip(shown: bool, armed: bool = false, reserved: bool = false) -> bool:
	var before: float = width()
	_skip.visible = shown
	_skip_reserved = reserved or shown
	_skip_label.text = SKIP_ARMED_TEXT if armed else SKIP_TEXT
	var style: StyleBoxFlat = _skip.get_theme_stylebox("panel") as StyleBoxFlat
	style.bg_color = Palette.MUSTARD if armed else Palette.TEAL_LIGHT
	return not is_equal_approx(before, width())


## Fits the tags within `room` px: whole when they fit, else the pill gives up "PASS ›", then its
## words down to "+1". Returns whether they fit.
func fit(room: float) -> bool:
	_pass_hidden = false
	_pill_label.text = PILL_TEXT
	_pass_word.visible = _promised and _pill.visible
	if width() > room and _pass_word.visible:
		_pass_hidden = true
		_pass_word.visible = false
	if width() > room and _pill.visible:
		_pill_label.text = PILL_SHORT
	return width() <= room


## The room the tags keep: the SKIP tag's while the run wears a Day off, the pill's while it
## shows, SEPARATION apart.
func width() -> float:
	var shown: Array[float] = []
	if _skip_reserved:
		shown.append(TopBar.fresh_width(_skip))
	if _pill.visible:
		shown.append(TopBar.fresh_width(_pill))
	var total: float = 0.0
	for part: float in shown:
		total += part
	return ceilf(total + SEPARATION * maxi(shown.size() - 1, 0))


## The pill's words as shown ("PASS › +1 BONUS TICKET"), or "" while hidden.
func pill_text() -> String:
	if not _pill.visible:
		return ""
	return (_pass_word.text + " " if _pass_word.visible else "") + _pill_label.text


## The SKIP tag and the pill (for layout tests and the pulse).
func skip_tag() -> Control:
	return _skip


func pill() -> Control:
	return _pill


## The mustard pill: "PASS ›", the ticket icon at 2x, "+1 BONUS TICKET".
func _make_pill() -> PanelContainer:
	var panel: PanelContainer = _panel("BonusPill", Palette.MUSTARD)
	# PASS: it shares the calendar's hover, and a tap passes up to the pad.
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", PILL_GAP)
	panel.add_child(row)
	_pass_word = _text_label(PASS_WORD)
	row.add_child(_pass_word)
	var ticket: TextureRect = UiKit.sprite(TICKET)
	ticket.custom_minimum_size = TICKET.get_size() * 2.0
	ticket.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ticket)
	_pill_label = _text_label(PILL_TEXT)
	row.add_child(_pill_label)
	return panel


## The SKIP tag: teal light (mustard armed), as wide as "UNDO ‹" from the start, so arming it
## never moves the bar; a tap on it says skip_pressed.
func _make_skip() -> PanelContainer:
	var panel: PanelContainer = _panel("SkipTag", Palette.TEAL_LIGHT)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	panel.gui_input.connect(_on_skip_input)
	_skip_label = _text_label(SKIP_ARMED_TEXT)
	_skip_label.custom_minimum_size.x = _skip_label.get_minimum_size().x
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skip_label.text = SKIP_TEXT
	panel.add_child(_skip_label)
	return panel


func _on_skip_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		_skip.accept_event()
		skip_pressed.emit()


## A tag's panel in `fill`, a 2 px ink border, hidden.
static func _panel(panel_name: String, fill: Color) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = panel_name
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = Palette.INK
	style.set_border_width_all(2)
	style.content_margin_left = PILL_PAD.x
	style.content_margin_right = PILL_PAD.x
	style.content_margin_top = PILL_PAD.y
	style.content_margin_bottom = PILL_PAD.y
	panel.add_theme_stylebox_override("panel", style)
	panel.visible = false
	return panel


static func _text_label(caption: String) -> Label:
	var line: Label = UiKit.body_label(caption, PILL_SIZE, Palette.INK)
	line.add_theme_font_override("font", ArtStyle.bold_font(PILL_WEIGHT))
	line.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return line
