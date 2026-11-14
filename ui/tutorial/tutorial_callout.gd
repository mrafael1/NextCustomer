class_name TutorialCallout
extends TipCard
## A tutorial step's callout (mock-up docs/art/mockups/tutorial.html, .tip): the game's hover tip
## card (TipCard, the approved paper card B: pin_card's 9-slice, its hard ink shadow and its tail
## pointing at the ringed target), grown to hold a step (StepView):
##
## - the header band, mustard (a guided step, a one-time tip) or teal light (a quick tutorial),
##   its words in the chunky capitals (TipTitle: "YOUR MOVE" / "TIP" / "NEW · TITLE") and its count
##   on the right ("3/26", "ONCE", "1/4"), a shade lighter;
## - the body (TipText: chips, money, terms) at CALLOUT_BODY_SIZE times the TEXT SIZE
##   (UiKit.text_size), the card as much wider;
## - the footer: the MORE › link (teal shade, underlined; tips and quick tutorials only) on the
##   left, and on the right the teal key (NEXT › or GOT IT) or the cream CLICK THE RING hint.
##
## It takes the clicks on it (they never reach the shade). The key and the link say so through
## button_pressed and more_pressed; press_button() is the key's Enter and Space. shake() is the
## refused move's soft shake (a flash of the band under reduced motion).

signal button_pressed
signal more_pressed(page: StringName)

const CALLOUT_BODY_SIZE := 16
const CALLOUT_WEIGHT := 600
const BODY_GAP := 8.0
const FOOTER_GAP := 10.0
const KEY_SIZE := 16
const KEY_FRAME := preload("res://art/frames/button_teal.png")
## The count's ink, lighter than the title's (the page's .n at 75%).
const COUNT_ALPHA := 0.75
## The CLICK THE RING hint's padding and the link's underline.
const HINT_PAD := Vector2(6, 4)
const UNDERLINE := 2.0
const UNDERLINE_GAP := 2.0
const SHAKE_PX := 6.0
const SHAKE_S := 0.32
const FLASH := Color(1.25, 1.25, 1.25)

var view: StepView
var _key: FramedButton
var _link: Button
var _hint: Control
var _count: TipTitle
var _shaking: Tween
var _home: Vector2 = Vector2.ZERO


func _init() -> void:
	super()
	name = "TutorialCallout"
	mouse_filter = Control.MOUSE_FILTER_STOP


## Builds the card for `step`, at most `room` px wide (the screen less its margins); its size
## follows.
func show_view(step: StepView, room: float = INF) -> void:
	view = step
	spec = null
	for part: Node in _parts:
		remove_child(part)
		part.queue_free()
	_parts.clear()
	_title = null
	_body = null
	_cond = null
	_live = null
	_key = null
	_link = null
	_hint = null
	_count = null
	_keys = [] as Array[String]
	_foot_top = -1.0
	_live_dot = Rect2()
	var base: float = step.width if step.width > 0.0 else StepView.DEFAULT_WIDTH
	width_override = minf(roundf(base * UiKit.reading_scale / PX) * PX, floorf(room / PX) * PX)
	var width: float = card_width()
	_band_colour = Palette.TEAL_LIGHT if step.kind == StepView.Kind.QUICK else Palette.MUSTARD
	_band_ink = Palette.INK
	var y: float = _build_header(step, width)
	var left: float = BORDER + PAD_X
	var inner: float = width - left * 2.0
	y += BODY_GAP
	if not step.body.is_empty():
		_body = TipText.new(
			step.body, UiKit.text_size(CALLOUT_BODY_SIZE), CALLOUT_WEIGHT, Palette.INK, inner
		)
		_body.name = "Body"
		_body.position = Vector2(left, y)
		_add(_body)
		y += _body.size.y
	y = _build_footer(step, left, inner, y + FOOTER_GAP)
	y += BOTTOM + BORDER
	size = Vector2(width, ceilf(y / PX) * PX)
	_shadow.size = size
	_frame.size = size
	_band.position = Vector2(BORDER, BORDER)
	_band.size = Vector2(width - BORDER * 2.0, _head_height)
	_band.color = _band_colour
	_marks.size = size
	_marks.queue_redraw()


## Puts the card at `at` (its parent's coordinates), its tail on side `on` pointing at `target`
## (hidden when there is none).
func put(at: Vector2, on: Opens, target: Rect2) -> void:
	_stop_shake()
	position = at
	_home = at
	if target.has_area():
		point_tail(on, target)
		tail().visible = true
	else:
		tail().visible = false


## Presses the key (Enter, Space): true when there is one.
func press_button() -> bool:
	if _key == null:
		return false
	button_pressed.emit()
	return true


## The refused move's shake (reduced motion: the band flashes instead, nothing moves).
func shake(reduced: bool) -> void:
	_stop_shake()
	if not is_inside_tree():
		return
	_shaking = create_tween()
	if reduced:
		_band.modulate = FLASH
		_shaking.tween_property(_band, "modulate", Color.WHITE, SHAKE_S)
		return
	var beat: float = SHAKE_S / 5.0
	for offset: float in [SHAKE_PX, -SHAKE_PX, SHAKE_PX / 2.0, -SHAKE_PX / 2.0, 0.0]:
		_shaking.tween_property(self, "position:x", _home.x + offset, beat)


func is_shaking() -> bool:
	return _shaking != null and _shaking.is_running()


func key() -> FramedButton:
	return _key


func link() -> Button:
	return _link


func hint() -> Control:
	return _hint


func header_title() -> TipTitle:
	return _title


func count_title() -> TipTitle:
	return _count


## The callout's words (header, count, body, footer), for checks.
func callout_text() -> String:
	if view == null:
		return ""
	var words: PackedStringArray = [view.header, view.count, TipMarkup.plain(view.body)]
	for part: String in [view.more_text(), view.button_caption(), view.hint()]:
		if not part.is_empty():
			words.append(part)
	return " ".join(words)


func _build_header(step: StepView, width: float) -> float:
	var x: float = BORDER + PAD_X
	var y: float = BORDER + HEAD_PAD
	var right: float = width - BORDER - PAD_X
	var count_width: float = 0.0
	if not step.count.is_empty():
		_count = TipTitle.new(step.count, _band_ink, right - x, 2.0)
		_count.name = "Count"
		_count.modulate = Color(1, 1, 1, COUNT_ALPHA)
		count_width = _count.size.x + HEAD_GAP
	_title = TipTitle.new(step.header, _band_ink, maxf(right - x - count_width, 40.0), 2.0)
	_title.name = "Header"
	var row: float = _title.size.y
	if _count != null:
		row = maxf(row, _count.size.y)
	_title.position = Vector2(x, y)
	_add(_title)
	if _count != null:
		_count.position = Vector2(right - _count.size.x, y)
		_add(_count)
	_head_height = ceilf((HEAD_PAD * 2.0 + row) / PX) * PX
	return BORDER + _head_height + RULE_LINE


## The footer from `y`: the link on the left, the key or the hint on the right (the link takes a
## row of its own over them when both don't fit). Returns its bottom.
func _build_footer(step: StepView, left: float, inner: float, y: float) -> float:
	var right_part: Control = null
	if not step.button_caption().is_empty():
		_key = UiKit.framed_button(
			null, step.button_caption(), button_pressed.emit, KEY_SIZE, KEY_FRAME
		)
		_key.name = "Key"
		_key.size = _key.get_combined_minimum_size()
		right_part = _key
	elif not step.hint().is_empty():
		_hint = _build_hint(step.hint())
		right_part = _hint
	if not step.more_text().is_empty():
		_link = _build_link(step.more_text(), step.more_page)
	if right_part == null and _link == null:
		return y - FOOTER_GAP
	var row: float = 0.0
	if _link != null:
		var beside: bool = (
			right_part == null or _link.size.x + HEAD_GAP + right_part.size.x <= inner
		)
		if not beside:
			_link.position = Vector2(left, y)
			_add(_link)
			y += _link.size.y + LINE_GAP
		else:
			row = _link.size.y
	if right_part != null:
		row = maxf(row, right_part.size.y)
		right_part.position = Vector2(left + inner - right_part.size.x, y)
		_add(right_part)
	if _link != null and _link.get_parent() == null:
		_link.position = Vector2(left, y + roundf((row - _link.size.y) / PX / 2.0) * PX)
		_add(_link)
	return y + row


func _build_hint(words: String) -> Control:
	var hint_box: ColorRect = ColorRect.new()
	hint_box.name = "Hint"
	hint_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_box.color = Palette.CREAM
	var label: Label = UiKit.pixel_label(words, 2, Palette.INK_LIGHT)
	label.name = "HintWords"
	var words_size: Vector2 = caps_size(words) * 2.0
	hint_box.size = ((words_size + HINT_PAD * 2.0) / PX).ceil() * PX
	hint_box.add_child(label)
	UiKit.place_pixel_label(
		label, Rect2(Vector2(HINT_PAD.x, 0), Vector2(words_size.x + 2.0, hint_box.size.y)), true
	)
	return hint_box


func _build_link(words: String, page: StringName) -> Button:
	var button: Button = Button.new()
	button.name = "More"
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.accessibility_name = words
	button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	button.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	var label: Label = UiKit.pixel_label(words, 2, Palette.TEAL_SHADE)
	label.name = "MoreWords"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var words_size: Vector2 = caps_size(words) * 2.0
	button.size = Vector2(words_size.x + 2.0, words_size.y + UNDERLINE_GAP + UNDERLINE + 4.0)
	button.custom_minimum_size = button.size
	button.add_child(label)
	UiKit.place_pixel_label(label, Rect2(Vector2.ZERO, Vector2(words_size.x + 2.0, 0)))
	label.position.y = 2.0 - (_cap_top() * 2.0)
	var line: ColorRect = ColorRect.new()
	line.name = "Underline"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.color = Palette.TEAL_SHADE
	line.position = Vector2(0, 2.0 + words_size.y + UNDERLINE_GAP)
	line.size = Vector2(words_size.x, UNDERLINE)
	button.add_child(line)
	button.pressed.connect(func() -> void: more_pressed.emit(page))
	return button


## The pixel font's room above its capitals, in font px.
static func _cap_top() -> float:
	var font: Font = ArtStyle.pixel_display_font()
	return font.get_ascent(ArtStyle.PIXEL_TEXT_SIZE) - ArtStyle.PIXEL_CAP_HEIGHT


func _stop_shake() -> void:
	if _shaking != null:
		_shaking.kill()
		_shaking = null
		position = _home
		_band.modulate = Color.WHITE
