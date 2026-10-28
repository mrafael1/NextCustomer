class_name CheckoutColumn
extends Control
## The monitor's checkout column (#105 piece 2, mock-up readability_v3.html, monitor b), right of
## the item column on the paper (MonitorView.CHECKOUT_RECT, its divider at the left), in one €
## style: whole euros with the € after them (#86, the monitor bay decisions). From the top: the
## caption (PLAN in planning, TOTAL in the count), the total (TotalNumber, centred on NUMBER_X, at
## the size its digit count fits NUMBER_ROOM at: 38 px up to 2 digits, as the mock-up's), the
## ladder (one lamp per landing, an octave brighter after each round of LAMPS), the SPEND line
## ("SPEND 26€+") and the status line: "+N€ planned" (or "N€ to go") in planning, "N€ to go" in the
## count (tomato dark, mustard darkest and pulsing from near_share of the quota), "+N€ over" once
## the total reaches it. For gain_box_s after a × lands, the gain box ("×2 → +5€") takes the
## status line's place. Once met a small gold sunburst turns behind the number; at the count's end
## a met quota hides the status for the small SPEND MET stamp and the "+N€" tab. The column clips
## at its rect (the paper's right edge), as the mock-up's screen does: a ×'s punch may overrun it
## for a moment.
##
## It reads only the register's reading (set_reading, which the top bar's gauge follows too, so
## both show the same whole number at every moment), the count's landings (land, waste) and the
## shift's quota; every number is theirs. The motion runs on `make_tween` (the count's clock); the
## pulse and the sunburst's turn in real time. Under `reduced_motion` the number never rolls or
## punches, the gain box and the newest lamp show without a pop, nothing pulses or turns.

## The parts' rects in the column's own coordinates (the column at MonitorView.CHECKOUT_RECT: its
## left 6 px before the mock-up's cx).
const DIVIDER_RECT := Rect2(2, 4, 2, 146)
const CAPTION_RECT := Rect2(6, 2, 88, 15)
const NUMBER_X := 50.0
const NUMBER_TOP := 21.0
const SUN_RECT := Rect2(0, 8, 100, 68)
const LADDER_AT := Vector2(7, 60)
const SPEND_RECT := Rect2(6, 76, 88, 16)
const STATUS_RECT := Rect2(6, 96, 88, 18)
## The status line's font sizes, largest first: the first its text fits STATUS_RECT's width at.
const STATUS_SIZES: Array[int] = [14, 13, 12, 11]
## The gain box's sizes, largest first: the first its text fits the column at (a 3-digit gain).
const GAIN_SIZES: Array[int] = [15, 14, 13, 12, 11]
## The SPEND line's sizes (its word, its amount), largest first: the first it fits SPEND_RECT at.
const SPEND_SIZES: Array[Vector2i] = [Vector2i(12, 16), Vector2i(11, 14), Vector2i(10, 12)]
const GAIN_RECT := Rect2(2, 100, 96, 22)
const STAMP_AT := Vector2(7, 100)
const STAMP_WIDTH := 86.0
const STAMP_SIZE := 14
const STAMP_TILT := -6.0
const TAB_AT := Vector2(32, 130)
## The number's room at rest for its size (TotalNumber.fit_size): centred on NUMBER_X, the drawn
## group stays clear of the divider and inside the paper's edge (2 x 46 px). Punched it may cover
## the divider and run into the column's clip for a moment, as in the mock-up.
const NUMBER_ROOM := 92.0
## The ladder's lamps: their heights on one baseline, LAMP_WIDTH wide at LAMP_PITCH, each in a
## LAMP_RING px ink ring; unlit cream, lit by octave (mustard, gold, mustard pale).
const LAMP_HEIGHTS: Array[int] = [4, 6, 6, 8, 8, 10, 10, 12]
const LAMP_WIDTH := 8.0
const LAMP_PITCH := 11.0
const LAMP_RING := 2.0
const LAMP_UNLIT := Palette.CREAM
const LAMP_OCTAVES: Array[Color] = [Palette.MUSTARD, Palette.GOLD, Palette.MUSTARD_PALE]
const LAMP_FLASH := Palette.PAPER
const LAMP_WASTE := Palette.TOMATO
const DIVIDER_COLOR := Palette.CREAM
const CAPTION_COLOR := Palette.INK_LIGHT
const SHORT_COLOR := Palette.TOMATO_DARK
const NEAR_COLOR := Palette.MUSTARD_DARKEST
const OVER_COLOR := Palette.GREEN_DARK
const GAIN_POP_S := 0.15

## Returns a new Tween on the count's clock; none: the column's own.
var make_tween: Callable = Callable():
	set(value):
		make_tween = value
		_number.make_tween = value
## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable():
	set(value):
		reduced_motion = value
		_number.reduced_motion = value
		_sun.reduced_motion = value

var _tuning: CountTotalTuning
var _caption: Label
var _number: TotalNumber
var _sun: PixelSunburst
var _ladder: Control
var _spend: Control
var _spend_word: Label
var _spend_amount: Label
var _status: Label
var _gain: Label
var _stamp: Label
var _tab: Label
var _counting: bool = false
var _quota: int = 0
var _amount: int = 0
var _ended: bool = false
## The ladder: gain landings so far, the newest flashing, a waste's flicker (the next lamp).
var _lit: int = 0
var _flashing: bool = false
var _flicker_on: bool = false
var _gain_motion: Tween
var _lamp_motion: Tween
var _flicker_motion: Tween


func _init(tuning: CountTotalTuning = null) -> void:
	name = "CheckoutColumn"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tuning = tuning if tuning != null else load(CountUpPlan.TOTAL_TUNING_PATH) as CountTotalTuning
	size = MonitorView.CHECKOUT_RECT.size
	clip_contents = true
	_sun = PixelSunburst.new(SUN_RECT.size / 2.0, 2.0)
	_sun.position = SUN_RECT.position
	_sun.spin = _tuning.met_sun_spin
	_sun.visible = false
	add_child(_sun)
	_caption = MonitorKit.bold(MonitorText.PLAN_CAPTION, 12, 800, CAPTION_COLOR, 15.0)
	_caption.name = "Caption"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_override("font", _spaced(ArtStyle.bold_font(800), 2))
	_put(_caption, CAPTION_RECT)
	_number = TotalNumber.new(_tuning)
	_number.fit_room = NUMBER_ROOM
	_number.centre_x = NUMBER_X
	_number.top = NUMBER_TOP
	add_child(_number)
	_ladder = Control.new()
	_ladder.name = "Ladder"
	_ladder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ladder.position = LADDER_AT - Vector2.ONE * LAMP_RING
	_ladder.size = (
		Vector2((LAMP_HEIGHTS.size() - 1) * LAMP_PITCH + LAMP_WIDTH, LAMP_HEIGHTS.max())
		+ Vector2.ONE * 2.0 * LAMP_RING
	)
	_ladder.draw.connect(_draw_ladder)
	add_child(_ladder)
	_spend = Control.new()
	_spend.name = "Spend"
	_spend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_spend)
	_spend_word = MonitorKit.bold(MonitorText.SPEND_WORD, 12, 800, CAPTION_COLOR, 16.0)
	_spend.add_child(_spend_word)
	_spend_amount = UiKit.number_label("", 16, false)
	_spend_amount.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_spend_amount.add_theme_constant_override("outline_size", 0)
	_spend.add_child(_spend_amount)
	_status = MonitorKit.bold("", 14, 800, SHORT_COLOR, 18.0)
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_put(_status, STATUS_RECT)
	_gain = MonitorKit.gold_box("", 15, 22.0, 5.0)
	_gain.name = "GainBox"
	# Atkinson has no "→": the gain box's font draws it from the mono font behind it.
	_gain.add_theme_font_override("font", MachineDisplay.marked_font(800))
	_gain.visible = false
	add_child(_gain)
	_stamp = MonitorKit.stamp(STAMP_WIDTH, STAMP_SIZE, STAMP_TILT)
	_stamp.position = STAMP_AT
	_stamp.visible = false
	add_child(_stamp)
	_tab = MonitorKit.gold_box("", 14, 18.0, 5.0)
	_tab.name = "OverTab"
	_tab.visible = false
	add_child(_tab)


func _ready() -> void:
	_lay_spend()
	_fit(_status, STATUS_RECT)
	_fit(_caption, CAPTION_RECT)


func _process(_delta: float) -> void:
	_status.scale = Vector2.ONE * _pulse()
	_status.pivot_offset = _status.size / 2.0


## Planning: PLAN over the projected total `projected` (or a drag's would-be total), the SPEND
## line for `quota` and "+N€ planned" (or "N€ to go").
func show_plan(projected: int, quota: int) -> void:
	_counting = false
	_ended = false
	_quota = quota
	_amount = projected
	_caption.text = MonitorText.PLAN_CAPTION
	_number.set_value(projected, false)
	_reset_count_parts()
	_set_spend(quota)
	_set_status(MonitorText.planned(projected, quota))
	_status.add_theme_color_override(
		"font_color", OVER_COLOR if projected >= quota else SHORT_COLOR
	)
	_status.visible = true


## A count starts against `quota`: TOTAL at 0 (no roll from planning's number), the ladder dark.
func start_count(quota: int) -> void:
	_counting = true
	_ended = false
	_quota = quota
	_caption.text = MonitorText.TOTAL_CAPTION
	_number.set_value(0, false)
	_reset_count_parts()
	_set_spend(quota)
	set_reading(0, quota)


## The register's reading (the count's shown total): the number rolls to it and the status follows.
func set_reading(amount: int, quota: int) -> void:
	_amount = amount
	_quota = quota
	if not _counting:
		return
	_number.set_value(amount, true)
	var reached: bool = amount >= quota
	_sun.visible = reached
	_set_status(MonitorText.status(amount, quota))
	var colour: Color = SHORT_COLOR
	if reached:
		colour = OVER_COLOR
	elif _near():
		colour = NEAR_COLOR
	_status.add_theme_color_override("font_color", colour)
	_status.visible = not _ended and not _gain.visible


## A landing `beat` lands on the number: its punch (a DOWN none), its lamp lit (flashing white for
## lamp_flash_s), and for a × the gain box for gain_box_s.
func land(beat: CountUpBeat) -> void:
	_number.punch(beat.land)
	if beat.lamp >= 0:
		_lit = beat.lamp + 1
		_flash_lamp()
	if beat.land == CountUpBeat.Land.DOWN:
		_flicker()
	if beat.land == CountUpBeat.Land.MUL:
		_show_gain(beat)
	_ladder.queue_redraw()


## WASTED drops on the item: the next lamp flickers tomato.
func waste() -> void:
	_flicker()


## The count's end (the TOTAL line): a met quota hides the status for the stamp and the tab.
func finish(met: bool) -> void:
	_ended = met
	_hide_gain()
	if not met:
		return
	_status.visible = false
	_stamp.visible = true
	_tab.text = MonitorText.over_tab(_amount, _quota)
	_fit_tab()
	_tab.visible = true


## A resumed checkout's end: TOTAL at `total` against `quota`, every lamp of `lamps` lit, finished.
func show_end_state(total: int, quota: int, lamps: int) -> void:
	start_count(quota)
	_lit = lamps
	set_reading(total, quota)
	_ladder.queue_redraw()
	finish(total >= quota)


## The number (its punch, its rect, the dessert's slam), and the parts for checks.
func total_number() -> TotalNumber:
	return _number


func caption() -> Label:
	return _caption


func status_label() -> Label:
	return _status


func gain_box() -> Label:
	return _gain


func stamp() -> Label:
	return _stamp


func tab() -> Label:
	return _tab


func sunburst() -> PixelSunburst:
	return _sun


## The ladder (its rect) and the lamps lit now.
func ladder() -> Control:
	return _ladder


func lit_lamps() -> int:
	return _lit


## The SPEND line (its two labels in their parent).
func spend_line() -> Control:
	return _spend


## Where a flying amount lands (global): the number's left edge at rest (its ink outline's), at
## the number's middle; CountChips stops each chip's right edge just short of it.
func landing_point() -> Vector2:
	var left: float = _number.position.x - TotalNumber.OUTLINE
	return global_position + Vector2(left, NUMBER_TOP + _number.size.y / 2.0)


## The number's middle (global, at rest).
func number_centre() -> Vector2:
	return global_position + Vector2(NUMBER_X, NUMBER_TOP + _number.size.y / 2.0)


func _reset_count_parts() -> void:
	_lit = 0
	_flashing = false
	_flicker_on = false
	_stop(_lamp_motion)
	_stop(_flicker_motion)
	_hide_gain()
	_stamp.visible = false
	_tab.visible = false
	_sun.visible = false
	_ladder.queue_redraw()


func _set_spend(quota: int) -> void:
	_spend_amount.text = MonitorText.spend(quota)
	_lay_spend()


## "SPEND" and its amount side by side, centred on SPEND_RECT, on one baseline, at the largest
## of SPEND_SIZES they fit it at.
func _lay_spend() -> void:
	var gap: float = 4.0
	var word: Vector2 = Vector2.ZERO
	var amount: Vector2 = Vector2.ZERO
	var width: float = 0.0
	for sizes: Vector2i in SPEND_SIZES:
		_spend_word.add_theme_font_size_override("font_size", sizes.x)
		_spend_amount.add_theme_font_size_override("font_size", sizes.y)
		word = _spend_word.get_minimum_size()
		amount = _spend_amount.get_minimum_size()
		width = word.x + gap + amount.x
		if width <= SPEND_RECT.size.x:
			break
	var left: float = roundf(SPEND_RECT.get_center().x - width / 2.0)
	_spend.position = Vector2(left, SPEND_RECT.position.y)
	_spend.size = Vector2(width, SPEND_RECT.size.y)
	_spend_word.position = Vector2.ZERO
	_spend_word.size = Vector2(word.x, SPEND_RECT.size.y)
	_spend_amount.position = Vector2(word.x + gap, 0.0)
	_spend_amount.size = Vector2(amount.x, SPEND_RECT.size.y)


func _show_gain(beat: CountUpBeat) -> void:
	_stop(_gain_motion)
	_gain.text = MonitorText.gain_box(beat.factor_text, beat.gain, _arrow())
	var width: float = 0.0
	for size_px: int in GAIN_SIZES:
		_gain.add_theme_font_size_override("font_size", size_px)
		width = _gain.get_minimum_size().x
		if width + 2.0 * MonitorKit.BOX_BORDER <= GAIN_RECT.size.x:
			break
	_gain.size = Vector2(width, GAIN_RECT.size.y)
	_gain.position = Vector2(roundf(GAIN_RECT.get_center().x - width / 2.0), GAIN_RECT.position.y)
	_gain.pivot_offset = _gain.size / 2.0
	_gain.visible = true
	_status.visible = false
	_gain_motion = _new_tween()
	if not _reduced():
		_gain.scale = Vector2.ONE * _tuning.gain_box_pop
		_gain_motion.tween_property(_gain, "scale", Vector2.ONE, GAIN_POP_S)
	_gain_motion.tween_interval(maxf(0.0, _tuning.gain_box_s - GAIN_POP_S))
	_gain_motion.tween_callback(_hide_gain)


func _hide_gain() -> void:
	_stop(_gain_motion)
	_gain.visible = false
	_gain.scale = Vector2.ONE
	if _counting:
		_status.visible = not _ended
	elif not _status.text.is_empty():
		_status.visible = true


func _flash_lamp() -> void:
	_stop(_lamp_motion)
	_flashing = true
	_lamp_motion = _new_tween()
	_lamp_motion.tween_interval(_tuning.lamp_flash_s)
	_lamp_motion.tween_callback(_end_flash)


func _end_flash() -> void:
	_flashing = false
	_ladder.queue_redraw()


## The next lamp flickers tomato every waste_flicker_s for waste_flicker_for_s.
func _flicker() -> void:
	_stop(_flicker_motion)
	_flicker_motion = _new_tween()
	var steps: int = maxi(
		1, roundi(_tuning.waste_flicker_for_s / maxf(0.01, _tuning.waste_flicker_s))
	)
	for step: int in range(steps):
		_flicker_motion.tween_callback(_set_flicker.bind(step % 2 == 0))
		_flicker_motion.tween_interval(_tuning.waste_flicker_s)
	_flicker_motion.tween_callback(_set_flicker.bind(false))


func _set_flicker(on: bool) -> void:
	_flicker_on = on
	_ladder.queue_redraw()


## The lamps (see the class comment): the rounds so far colour the unlit ones, the newest flashes,
## a waste flickers the next.
func _draw_ladder() -> void:
	var octave: int = floori((_lit - 1) / float(LAMP_HEIGHTS.size())) if _lit > 0 else 0
	var newest: int = (_lit - 1) % LAMP_HEIGHTS.size() if _lit > 0 else -1
	var tallest: float = float(LAMP_HEIGHTS.max())
	for index: int in range(LAMP_HEIGHTS.size()):
		var colour: Color = LAMP_UNLIT
		if octave > 0:
			colour = LAMP_OCTAVES[mini(octave - 1, LAMP_OCTAVES.size() - 1)]
		if index <= newest:
			colour = LAMP_OCTAVES[mini(octave, LAMP_OCTAVES.size() - 1)]
		if index == newest and _flashing:
			colour = LAMP_FLASH
		if _flicker_on and index == (newest + 1) % LAMP_HEIGHTS.size():
			colour = LAMP_WASTE
		var height: float = LAMP_HEIGHTS[index]
		var lamp: Rect2 = Rect2(
			LAMP_RING + index * LAMP_PITCH, LAMP_RING + tallest - height, LAMP_WIDTH, height
		)
		_ladder.draw_rect(lamp.grow(LAMP_RING), Palette.INK)
		_ladder.draw_rect(lamp, colour)


## The to-go line's pulse from near_share of the quota (real time); 1 otherwise.
func _pulse() -> float:
	if not _counting or _ended or _reduced() or not _near() or _amount >= _quota:
		return 1.0
	var period: float = maxf(0.01, _tuning.near_pulse_s)
	var seconds: float = Time.get_ticks_msec() / 1000.0
	return 1.0 + _tuning.near_pulse * maxf(0.0, sin(TAU * seconds / period))


func _near() -> bool:
	return _quota > 0 and _amount >= _quota * _tuning.near_share and _amount < _quota


func _fit_tab() -> void:
	var width: float = _tab.get_minimum_size().x
	_tab.position = TAB_AT
	_tab.size = Vector2(width, 18.0)


## The status line reads `text`, at the largest of STATUS_SIZES it fits the column at.
func _set_status(text: String) -> void:
	if _status.text == text:
		return
	_status.text = text
	var font: Font = _status.get_theme_font("font")
	for size_px: int in STATUS_SIZES:
		_status.add_theme_font_size_override("font_size", size_px)
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
		if width <= STATUS_RECT.size.x:
			break
	_fit(_status, STATUS_RECT)


func _put(label: Label, rect: Rect2) -> void:
	add_child(label)
	_fit(label, rect)


static func _fit(label: Label, rect: Rect2) -> void:
	label.position = rect.position
	label.size = rect.size


## The arrow the gain box's font has (→, from its mono fallback), else MonitorText's fallback.
static func _arrow() -> String:
	var font: Font = MachineDisplay.marked_font(800)
	if font.has_char(MonitorText.ARROW.unicode_at(0)):
		return MonitorText.ARROW
	return MonitorText.ARROW_FALLBACK


static func _spaced(font: Font, spacing: int) -> Font:
	var spaced: FontVariation = FontVariation.new()
	spaced.base_font = font
	spaced.spacing_glyph = spacing
	return spaced


func _draw() -> void:
	draw_rect(DIVIDER_RECT, DIVIDER_COLOR)


func _new_tween() -> Tween:
	if make_tween.is_valid():
		var tween: Tween = make_tween.call() as Tween
		if tween != null:
			return tween
	return create_tween()


static func _stop(tween: Tween) -> void:
	if tween != null and tween.is_valid():
		tween.kill()


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
