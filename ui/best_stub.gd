class_name BestStub
extends Control
## The results' BEST stub (direction B of docs/art/mockups/receipt_highlight.html, built beside
## direction A's BEST line on 2026-11-15): once the final receipt has printed its coins, a gold
## stub slides out from behind the receipt's left edge and is taped to the shutter, tilted like
## the mock-up's: "BEST MOMENT" over a dashed rule, the moment's art at full size on a pixel
## sunburst (the item's 48x48 sprite at 2x; for a moment with no item the BEST line's icon,
## ReceiptHighlight.icon_of, drawn big: the quota target for Over quota and Closest call, the
## combo diamond with a "×N" tag for a combo), the kind, the name, the value in big gold chunky
## digits and the shift and its week. It sits left of the receipt, below the CLOSED sign, so the
## badge pins' unlock cards keep the right side.
##
## Its words and numbers are RunHighlight's (parts, ratio_text, margin_of): a payout's or a
## combo's euros, Over quota's ratio, Closest call's margin ("+1€") and GOLD! for First GOLDEN. The
## receipt (ResultsPanel) puts it in its parent between the closed store and itself, so the receipt
## covers it; it clips at the receipt's left edge, so the stub comes out from under the paper.
## Presentation only.
##
## play: DELAY_MS after the coins it slides in from under the receipt over SLIDE_MS in SLIDE_STEPS
## steps (turning to its tilt, overshooting OVERSHOOT_PX, the print sound as it starts and the tag
## sound as it lands), the art pops (POP_AT_MS); finish shows it in place at once (a tap, Return to
## menu, reduced motion). It shows only once the shutter is down (hold) and when it fits the room
## left of the receipt (at a scale of MIN_SCALE or more).

## The stub's width and its border, padding and content's gaps, in px (the mock-up's at 1280x720).
const WIDTH := 204.0
const BORDER := 4
const PADDING := Vector2i(10, 10)
const SEPARATION := 2
## Its hard shadow and its tilt (degrees).
const SHADOW_OFFSET := Vector2(6, 6)
const SHADOW_ALPHA := 0.35
const TILT := -3.0
## The header and the dashed rule under it (dash, gap and thickness, in px).
const HEADER_TEXT := "BEST MOMENT"
const HEADER_SIZE := 16
const DASH := Vector3(6, 4, 2)
## The art's box: its height, the sunburst behind (art px, px each, degrees per second), the
## item's scale and the icons' (the quota target, the combo diamond).
const ART_HEIGHT := 112.0
const SUN_ART := Vector2(56, 56)
const SUN_PIXEL := 2.0
const SUN_SPIN := 12.0
const ITEM_SCALE := 2.0
const TARGET_SCALE := 6.0
const COMBO_SCALE := 16.0
## A combo's "×N" tag on the art's bottom right: its digits' cell, padding and border, in px.
const TAG_CELL := 2.0
const TAG_PAD := Vector2(4, 3)
const TAG_INSET := Vector2(18, 4)
## The words under the art, in px.
const KIND_SIZE := 14
const NAME_SIZE := 16
## A long name wraps at word breaks onto at most NAME_LINES lines (as the mock-up's block does).
const NAME_LINES := 2
const WHEN_SIZE := 13
const WHEN_TEXT := "shift %d · week %d"
## The value's chunky digits: the biggest cell that fits the stub's inner width, its € a size
## smaller; First GOLDEN's value word.
const VALUE_CELLS: Array[float] = [6.0, 4.0, 2.0]
const EURO := "€"
const GOLDEN_VALUE := "GOLD!"
## The two strips of tape over its top edge: size, inset from the sides, rise over the edge, tilts.
const TAPE_SIZE := Vector2(46, 20)
const TAPE_INSET := 16.0
const TAPE_RISE := 14.0
const TAPE_TILTS: Array[float] = [-8.0, 7.0]
const TAPE_ALPHA := 0.8
const TAPE_EDGE_ALPHA := 0.25
## The torn foot's scallops: radius and spacing, in px.
const PERF_RADIUS := 4.0
const PERF_STEP := 12.0
## Its place: EDGE px inside the window, GAP px left of the receipt, SIGN_GAP px below the CLOSED
## sign, DROP px below the receipt's top when there is room; a scale in SCALE_STEP steps when the
## room is smaller, hidden under MIN_SCALE.
const EDGE := 12.0
const GAP := 8.0
const SIGN_GAP := 8.0
const DROP := 100.0
const SCALE_STEP := 0.25
const MIN_SCALE := 0.5
## The slide (ms) and its beats: steps, the overshoot past its place and when (share of the
## slide); the art's pop (from POP_FROM to POP_PEAK, then 1) in POP_STEPS steps.
const DELAY_MS := 200
const SLIDE_MS := 500
const SLIDE_STEPS := 10
const OVERSHOOT_PX := 6.0
const OVERSHOOT_AT := 0.7
const POP_AT_MS := 450
const POP_MS := 240
const POP_STEPS := 6
const POP_FROM := 0.4
const POP_PEAK := 1.12
const POP_PEAK_AT := 0.7
const START_SOUND := "print"
const LAND_SOUND := "tag"

## Returns true when the player asked for reduced motion (the sunburst's spin). None: false.
var reduced_motion: Callable = Callable()
var _stub: Control
var _card: PanelContainer
var _shadow: ColorRect
var _perf: Control
var _sun: PixelSunburst
var _art: TextureRect
var _tag: PanelContainer
var _header: Label
var _kind: Label
var _name: Label
var _value: HBoxContainer
var _when: Label
var _tapes: Array[Panel] = []
## A moment is set; it is shown (played or finished); the shutter is not down yet; it fits.
var _has: bool = false
var _shown: bool = false
var _held: bool = false
var _fits: bool = true
var _tween: Tween
## Its place once landed (in its own coordinates), the slide's start offset and the fit scale.
var _final: Vector2 = Vector2.ZERO
var _from_x: float = 0.0
var _scale: float = 1.0
## The slide's progress, 0 to 1 (1: in place).
var _slide: float = 1.0
var _placed_for: Array = []


func _init() -> void:
	name = "BestStub"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_stub = Control.new()
	_stub.name = "Stub"
	_stub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stub.visible = false
	add_child(_stub)
	_shadow = ColorRect.new()
	_shadow.color = Color(Palette.CHARCOAL, SHADOW_ALPHA)
	_shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stub.add_child(_shadow)
	_card = PanelContainer.new()
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var paper: StyleBoxFlat = StyleBoxFlat.new()
	paper.bg_color = Palette.MUSTARD_PALE
	paper.border_color = Palette.INK
	paper.set_border_width_all(BORDER)
	paper.content_margin_left = BORDER + PADDING.x
	paper.content_margin_right = BORDER + PADDING.x
	paper.content_margin_top = BORDER + PADDING.y
	paper.content_margin_bottom = BORDER + PADDING.y + PERF_RADIUS
	_card.add_theme_stylebox_override("panel", paper)
	_stub.add_child(_card)
	_perf = Control.new()
	_perf.name = "Perforation"
	_perf.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_perf.draw.connect(_draw_perforation)
	_stub.add_child(_perf)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", SEPARATION)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(column)
	_header = _words(HEADER_TEXT, HEADER_SIZE, Palette.MUSTARD_DARKEST, ArtStyle.DISPLAY_FONT)
	column.add_child(_header)
	var rule: Control = Control.new()
	rule.custom_minimum_size = Vector2(0, DASH.z + 2.0 * SEPARATION)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.draw.connect(func() -> void: _draw_dashes(rule))
	column.add_child(rule)
	column.add_child(_build_art())
	_kind = _words("", KIND_SIZE, Palette.TEAL_SHADE, ArtStyle.DISPLAY_FONT)
	column.add_child(_kind)
	_name = _words("", NAME_SIZE, Palette.INK, ReceiptView.MONO_FONT)
	# No trimming: a trimmed autowrap label asks for a single pixel's height.
	_name.clip_text = false
	_name.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.max_lines_visible = NAME_LINES
	_name.custom_minimum_size.x = _inner_width()
	column.add_child(_name)
	_value = HBoxContainer.new()
	_value.alignment = BoxContainer.ALIGNMENT_CENTER
	_value.add_theme_constant_override("separation", 2)
	_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_value)
	_when = _words("", WHEN_SIZE, Palette.GREY, ReceiptView.MONO_FONT)
	column.add_child(_when)
	for index: int in range(TAPE_TILTS.size()):
		var tape: Panel = Panel.new()
		tape.name = "Tape%d" % index
		tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var strip: StyleBoxFlat = StyleBoxFlat.new()
		strip.bg_color = Color(Palette.CREAM, TAPE_ALPHA)
		strip.border_color = Color(Palette.INK, TAPE_EDGE_ALPHA)
		strip.set_border_width_all(1)
		tape.add_theme_stylebox_override("panel", strip)
		tape.size = TAPE_SIZE
		tape.pivot_offset = TAPE_SIZE / 2.0
		tape.rotation = deg_to_rad(TAPE_TILTS[index])
		_stub.add_child(tape)
		_tapes.append(tape)


## The stub of `moment` (null: none) with `definition`'s words, its shift in week `week` (1-based).
## It stays hidden until play or finish.
func set_moment(moment: RunHighlight.Moment, definition: HighlightDefinition, week: int) -> void:
	_kill()
	_shown = false
	_has = moment != null and definition != null
	_placed_for = []
	_stub.visible = false
	if not _has:
		return
	var parts: PackedStringArray = RunHighlight.parts(moment, definition)
	_kind.text = parts[0].to_upper()
	_name.text = parts[1]
	var value: String = parts[2] if parts.size() > 2 else ""
	match moment.kind:
		RunHighlight.Kind.OVER_QUOTA:
			_name.text = "%d€ / %d€" % [moment.total, moment.quota]
		RunHighlight.Kind.FIRST_GOLDEN:
			value = GOLDEN_VALUE
		RunHighlight.Kind.CLOSEST_CALL:
			_name.text = parts[2]
			value = "+%d€" % RunHighlight.margin_of(moment)
	_when.text = WHEN_TEXT % [moment.shift, week]
	# Its wrap (and so the card's height) is measured at the column's width.
	_name.size = Vector2(_inner_width(), 0.0)
	_set_value(value)
	_set_art(moment)
	_size_card()


## Slides it in (see the class doc), or shows it at once with `reduced`.
func play(reduced: bool) -> void:
	if not _has:
		return
	if reduced:
		finish()
		return
	_kill()
	_shown = true
	_set_progress(0.0)
	_refresh_visible()
	_tween = create_tween()
	_tween.tween_interval(DELAY_MS / 1000.0)
	_tween.tween_callback(func() -> void: _play_sound(START_SOUND))
	var total_ms: int = maxi(SLIDE_MS, POP_AT_MS + POP_MS)
	_tween.tween_method(_set_progress, 0.0, float(total_ms), total_ms / 1000.0)
	_tween.tween_callback(func() -> void: _play_sound(LAND_SOUND))


## Shows it in place at once (the art at full size).
func finish() -> void:
	if not _has:
		return
	_kill()
	_shown = true
	_set_progress(float(maxi(SLIDE_MS, POP_AT_MS + POP_MS)))
	_refresh_visible()


## A tap or Return to menu while it slides: in place at once (nothing when not playing).
func finish_playing() -> void:
	if is_playing():
		finish()


## While `held` (the shutter still rolling down), it waits out of view.
func hold(held: bool) -> void:
	if _held == held:
		return
	_held = held
	_refresh_visible()


## Places it left of `receipt` (global), below `sign_rect` (the CLOSED sign's settled rect,
## global), inside `window` (global); clips at the receipt's left edge. Cheap when nothing moved.
func place(receipt: Rect2, sign_rect: Rect2, window: Rect2) -> void:
	var key: Array = [receipt, sign_rect, window]
	if key == _placed_for or not _has:
		return
	_placed_for = key
	var origin: Vector2 = Vector2.ZERO
	if get_parent_control() != null:
		origin = get_parent_control().get_global_rect().position
	position = window.position - origin
	size = Vector2(maxf(receipt.position.x + BORDER - window.position.x, 0.0), window.size.y)
	var top: float = maxf(window.position.y + EDGE, sign_rect.end.y + SIGN_GAP)
	var room: Rect2 = Rect2(
		window.position.x + EDGE,
		top,
		receipt.position.x - GAP - window.position.x - EDGE,
		window.end.y - EDGE - top
	)
	var natural: Rect2 = _bounds_at(1.0, deg_to_rad(TILT))
	_scale = 1.0
	if natural.size.x > room.size.x or natural.size.y > room.size.y:
		var fit: float = minf(room.size.x / natural.size.x, room.size.y / natural.size.y)
		_scale = floorf(fit / SCALE_STEP) * SCALE_STEP
	_fits = _scale >= MIN_SCALE - 0.001
	_stub.scale = Vector2.ONE * _scale
	var bounds: Rect2 = _bounds_at(_scale, deg_to_rad(TILT))
	var at: Vector2 = Vector2(
		room.position.x + (room.size.x - bounds.size.x) / 2.0,
		clampf(receipt.position.y + DROP, room.position.y, room.end.y - bounds.size.y)
	)
	# Its control's position puts its tilted bounds' top left at `at` (window coordinates).
	_final = (at - window.position - bounds.position).round()
	# The slide starts with the whole stub under the receipt.
	_from_x = size.x - (at.x - window.position.x) + OVERSHOOT_PX
	_apply()
	_refresh_visible()


## Whether its slide is still playing (for tests and the receipt's tap).
func is_playing() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


## Whether it was played or finished and shows (a moment, the shutter down, room enough).
func is_showing() -> bool:
	return is_visible_in_tree() and _stub.visible


## Its tilted bounds, the tape and the shadow with it, in global coordinates (for tests).
func stub_rect() -> Rect2:
	var local: Rect2 = _extents()
	return _stub.get_global_transform() * local


## The value's digits, the art and its tag (global, unturned bounds; for tests).
func value_rect() -> Rect2:
	return _turned(_value)


func art_rect() -> Rect2:
	return _turned(_art)


## Its words: the header, the kind, the name, the value and the shift line (for tests).
func texts() -> PackedStringArray:
	var value: String = ""
	for words: Node in _value.get_children():
		value += (words as PixelWords).text
	return PackedStringArray([_header.text, _kind.text, _name.text, value, _when.text])


## The name's shown lines (for tests).
func name_lines() -> int:
	return _name.get_visible_line_count()


## The name's and the value's rects in the card's column, untilted and unscaled (for tests).
func name_box() -> Rect2:
	return Rect2(_name.position, _name.size)


func value_box() -> Rect2:
	return Rect2(_value.position, _value.size)


## The art's texture, the value's cell and the fit scale (for tests).
func art_texture() -> Texture2D:
	return _art.texture


func value_cell() -> float:
	if _value.get_child_count() == 0:
		return 0.0
	return (_value.get_child(0) as PixelWords).cell


func fit_scale() -> float:
	return _scale


## The combo's "×N" tag shows (for tests).
func has_tag() -> bool:
	return _tag.visible


func _build_art() -> Control:
	var box: Control = Control.new()
	box.name = "Art"
	box.custom_minimum_size = Vector2(0, ART_HEIGHT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sun = PixelSunburst.new(SUN_ART, SUN_PIXEL)
	_sun.spin = SUN_SPIN
	_sun.reduced_motion = func() -> bool: return _reduced()
	box.add_child(_sun)
	_art = UiKit.sprite(null)
	_art.name = "Item"
	box.add_child(_art)
	_tag = PanelContainer.new()
	_tag.name = "Tag"
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tag_box: StyleBoxFlat = StyleBoxFlat.new()
	tag_box.bg_color = Palette.GOLD
	tag_box.border_color = Palette.INK
	tag_box.set_border_width_all(2)
	tag_box.content_margin_left = TAG_PAD.x
	tag_box.content_margin_right = TAG_PAD.x
	tag_box.content_margin_top = TAG_PAD.y
	tag_box.content_margin_bottom = TAG_PAD.y
	_tag.add_theme_stylebox_override("panel", tag_box)
	_tag.add_child(PixelWords.new("", PixelWords.Sheet.CHUNKY, TAG_CELL, Palette.INK))
	box.add_child(_tag)
	return box


func _set_art(moment: RunHighlight.Moment) -> void:
	var inner: float = _inner_width()
	var texture: Texture2D = ReceiptHighlight.icon_of(moment)
	var art_scale: float = TARGET_SCALE
	if moment.card != null:
		texture = ArtStyle.item_sprite(moment.card)
		art_scale = ITEM_SCALE
	elif moment.kind == RunHighlight.Kind.LONGEST_COMBO:
		art_scale = COMBO_SCALE
	_art.texture = texture
	_art.size = texture.get_size() * art_scale
	_art.position = (Vector2(inner, ART_HEIGHT) - _art.size) / 2.0
	_art.pivot_offset = _art.size / 2.0
	_sun.position = ((Vector2(inner, ART_HEIGHT) - _sun.size) / 2.0).round()
	_tag.visible = moment.kind == RunHighlight.Kind.LONGEST_COMBO
	(_tag.get_child(0) as PixelWords).text = "×%d" % moment.length
	var tag_size: Vector2 = _tag.get_combined_minimum_size()
	_tag.size = tag_size
	_tag.position = Vector2(inner, ART_HEIGHT) - tag_size - TAG_INSET


## The value in chunky digits (chunky capitals for a word), its € a cell smaller, at the biggest
## cell that fits the inner width.
func _set_value(value: String) -> void:
	for child: Node in _value.get_children():
		_value.remove_child(child)
		child.queue_free()
	var number: String = value.trim_suffix(EURO)
	var euro: bool = number != value
	var sheet: PixelWords.Sheet = PixelWords.Sheet.CHUNKY
	if value == GOLDEN_VALUE:
		sheet = PixelWords.Sheet.CHUNKY_CAPS
	var cell: float = VALUE_CELLS[-1]
	for each: float in VALUE_CELLS:
		var width: float = PixelWords.text_size(number, sheet, each).x
		if euro:
			width += PixelWords.text_size(EURO, sheet, maxf(each - 2.0, 2.0)).x + 2.0
		if width <= _inner_width():
			cell = each
			break
	var words: PixelWords = PixelWords.new(number, sheet, cell, Palette.MUSTARD_DARKEST)
	words.shadow = Palette.GOLD
	words.size_flags_vertical = Control.SIZE_SHRINK_END
	# The shadow's cell below and right of the words is room too.
	words.custom_minimum_size = PixelWords.text_size(number, sheet, cell) + Vector2.ONE * cell
	_value.add_child(words)
	if euro:
		var small: float = maxf(cell - 2.0, 2.0)
		var mark: PixelWords = PixelWords.new(EURO, sheet, small, Palette.MUSTARD_DARKEST)
		mark.size_flags_vertical = Control.SIZE_SHRINK_END
		mark.custom_minimum_size = PixelWords.text_size(EURO, sheet, small) + Vector2(0, cell)
		_value.add_child(mark)


## Sizes the card, its shadow and tapes, and the stub around them.
func _size_card() -> void:
	_card.reset_size()
	var card_size: Vector2 = Vector2(WIDTH, _card.get_combined_minimum_size().y)
	_card.size = card_size
	_stub.size = card_size
	_stub.pivot_offset = card_size / 2.0
	_shadow.position = SHADOW_OFFSET
	_shadow.size = card_size
	_tapes[0].position = Vector2(TAPE_INSET, -TAPE_RISE)
	_tapes[1].position = Vector2(card_size.x - TAPE_INSET - TAPE_SIZE.x, -TAPE_RISE)
	_perf.size = card_size
	_perf.queue_redraw()


func _inner_width() -> float:
	return WIDTH - 2.0 * (BORDER + PADDING.x)


## The stub's extents in its own coordinates: the card, the tape above, the shadow and the
## scallops below.
func _extents() -> Rect2:
	var rise: float = TAPE_RISE + TAPE_SIZE.y * 0.15
	var below: float = maxf(SHADOW_OFFSET.y, PERF_RADIUS)
	return Rect2(Vector2(0.0, -rise), _stub.size + Vector2(SHADOW_OFFSET.x, rise + below))


## Its extents' bounds at `scale_factor` and `turn` (radians), relative to its control's position.
func _bounds_at(scale_factor: float, turn: float) -> Rect2:
	var pivot: Vector2 = _stub.size / 2.0
	var transform: Transform2D = (
		Transform2D(0.0, pivot)
		* Transform2D(turn, Vector2.ONE * scale_factor, 0.0, Vector2.ZERO)
		* Transform2D(0.0, -pivot)
	)
	return transform * _extents()


## `part`'s bounds, global.
func _turned(part: Control) -> Rect2:
	return part.get_global_transform() * Rect2(Vector2.ZERO, part.size)


## The slide at `elapsed_ms` from its start: stepped, turning to the tilt, overshooting, then
## the art's pop.
func _set_progress(elapsed_ms: float) -> void:
	var slide: float = clampf(elapsed_ms / SLIDE_MS, 0.0, 1.0)
	_slide = floorf(slide * SLIDE_STEPS) / SLIDE_STEPS
	var pop: float = clampf((elapsed_ms - POP_AT_MS) / POP_MS, 0.0, 1.0)
	pop = floorf(pop * POP_STEPS) / POP_STEPS
	var art_scale: float = 1.0
	if pop < POP_PEAK_AT:
		art_scale = lerpf(POP_FROM, POP_PEAK, pop / POP_PEAK_AT)
	elif pop < 1.0:
		art_scale = lerpf(POP_PEAK, 1.0, (pop - POP_PEAK_AT) / (1.0 - POP_PEAK_AT))
	_art.scale = Vector2.ONE * art_scale
	_apply()


## Puts the stub at its slide's place and turn.
func _apply() -> void:
	var offset: float = 0.0
	var turn: float = TILT
	if _slide < OVERSHOOT_AT:
		var reach: float = _slide / OVERSHOOT_AT
		offset = lerpf(_from_x, -OVERSHOOT_PX, reach)
		turn = lerpf(0.0, TILT, reach)
	elif _slide < 1.0:
		offset = lerpf(-OVERSHOOT_PX, 0.0, (_slide - OVERSHOOT_AT) / (1.0 - OVERSHOOT_AT))
	_stub.position = _final + Vector2(roundf(offset), 0.0)
	_stub.rotation = deg_to_rad(turn)


func _refresh_visible() -> void:
	_stub.visible = _has and _shown and not _held and _fits


func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())


func _play_sound(sound: String) -> void:
	var sfx: Sfx = Sfx.find(self)
	if sfx != null and _stub.visible:
		sfx.play(sound)


## The torn foot: paper scallops over the card's bottom border.
func _draw_perforation() -> void:
	var y: float = _perf.size.y - BORDER / 2.0
	var x: float = PERF_STEP / 2.0
	while x < _perf.size.x:
		_perf.draw_circle(Vector2(x, y), PERF_RADIUS, Palette.MUSTARD_PALE, true, -1.0, false)
		x += PERF_STEP


func _draw_dashes(rule: Control) -> void:
	var x: float = 0.0
	var y: float = SEPARATION
	while x < rule.size.x:
		var length: float = minf(DASH.x, rule.size.x - x)
		rule.draw_rect(Rect2(x, y, length, DASH.z), Palette.MUSTARD_DARK)
		x += DASH.x + DASH.y


static func _words(text: String, font_size: int, colour: Color, font: Font) -> Label:
	var label: Label = UiKit.label(text, font_size, colour)
	label.add_theme_font_override("font", font)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label
