class_name QuotaMeter
extends HBoxContainer
## The top bar's quota chip contents (#80 step 10, mock-up B2; #86 gauge TA of mock-up
## count_up_86_v4_live.html): the word SPEND and the shift's quota as "€N+" (#86: players read
## the quota as an amount to spend; code and data keep "quota"), a liquid gauge, the amount in
## mustard and a tag saying how far the quota is ("€N to go" on paper, "Spot on" or "+€N" on
## mustard; LedBeat.to_go_text). In planning the amount is the projected total, which the shift
## screen hands it from its preview (show_projected): the monitor shows its store channel then,
## not the total (the user's play test of 2026-10-17). During the count it mirrors the monitor's
## LED (follow): the running subtotal, so the gauge never shows the final total early. Blank LED
## alone (the impulse rack): no amount, no tag and an empty gauge.
##
## The gauge (#86, TA) is a liquid coloured by status (red, orange, green, gold: SHORT_RAMP). While
## short of the quota it is full exactly at the quota. Once the amount meets it (the count-up's
## ding, or a projected total reaching it) a flag (QuotaFlag, with a drawn ✓) is planted at the
## quota, and the gauge re-scales to the amount, so the flag slides back and the gold carries on
## past it. Each gain sloshes its front and sprays droplets; bubbles drift and a shine sweeps
## through the liquid; meeting the quota flashes it. The chip glows from NEAR_SHARE of the quota
## while short, and the amount punches on each gain. Reduced motion (`reduced_motion`) keeps the
## level, the flag and the glow (steady) and drops the slosh, the spray, the bubbles, the shine, the
## flag's planting and flapping and the punch.
##
## While an item is dragged over a landing slot (#71, decision 4A) it shows the total that drop
## would give and its change, e.g. "› €52 (+6)" (show_hypothetical; the fonts have no →), until
## the drag ends: the amount in its label, the change in the tag's slot; the gauge previews the
## new stretch (paler green for a gain, a dark stretch for a loss). Both keep reserved widths, so
## the gauge never moves while a drag crosses the slots. Display only: the amounts are the
## screen's preview and the LED's.

const SEPARATION := 8
## The gauge: at least this wide, 9 art pixels tall, with a 1 art pixel ink border; it draws in art
## pixels (ArtStyle.ART_SCALE screen pixels each).
const BAR_MIN_WIDTH := 80.0
const BAR_HEIGHT := 18.0
const BAR_BORDER := 2.0
## The quota's word and amount ("SPEND", "€73+").
const QUOTA_WORD := LedDisplay.QUOTA_WORD
const QUOTA_AMOUNT := LedDisplay.QUOTA_AMOUNT
## The chip glows from this share of the quota while short (and the LED's tag bobs).
const NEAR_SHARE := 0.8
## The glow: a mustard-light ring GLOW_WIDTH px round the chip, pulsing every GLOW_SECONDS.
const GLOW_WIDTH := 3.0
const GLOW_SECONDS := 0.7
## The amount's reserved digits: its label is at least as wide as this many of the widest digit
## after a drag's "› €", so the gauge keeps its width while the subtotal gains digits and a drag
## shows its total.
const AMOUNT_DIGITS := 4
## The change's reserved digits after its sign, in brackets (in the tag's slot).
const DELTA_DIGITS := 3
## The tag's reserved digits (its widest text is "€N to go" with this many).
const TAG_DIGITS := 3
## A drag's would-be total and its change from the projected one (#71), and the two read together
## (shown_text).
const HYPOTHETICAL_AMOUNT := "› €%d"
const HYPOTHETICAL_DELTA := "(%+d)"
const HYPOTHETICAL_TEXT := HYPOTHETICAL_AMOUNT + " " + HYPOTHETICAL_DELTA
## The tag (mock-up TA's): its text in bold at TAG_FONT_SIZE, an ink border, TAG_PADDING in.
const TAG_FONT_SIZE := 13
const TAG_WEIGHT := 750
const TAG_BORDER := 2
const TAG_PADDING := 4
## The amount punches from AMOUNT_PUNCH back to 1 over AMOUNT_PUNCH_SECONDS on each gain.
const AMOUNT_PUNCH := 1.22
const AMOUNT_PUNCH_SECONDS := 0.28
## The shown level eases to the amount at this rate (per second).
const EASE_RATE := 7.0
## The front's slosh: a gain of N adds SLOSH_KICK + N / SLOSH_PER_EURO art pixels, up to SLOSH_MAX,
## settling at SLOSH_DECAY per second; a small ripple always runs (RIPPLE).
const SLOSH_KICK := 1.5
const SLOSH_PER_EURO := 10.0
const SLOSH_MAX := 5.0
const SLOSH_DECAY := 3.5
const RIPPLE := 0.6
## The spray: SPRAY_DROPS + N / SPRAY_PER_EURO droplets (up to SPRAY_MAX) off the front for a gain
## of N, each for SPRAY_LIFE seconds, falling at SPRAY_GRAVITY art pixels per second squared,
## drawn inside the gauge (on its top edge while higher, as the mock-up's canvas clips them).
const SPRAY_DROPS := 6
const SPRAY_PER_EURO := 4.0
const SPRAY_MAX := 24
const SPRAY_LIFE := 0.8
const SPRAY_GRAVITY := 90.0
const BUBBLES := 9
const SHINE_SPEED := 70.0
const SHINE_LEAN := 0.6
## The flash at the quota fades over FLASH_SECONDS, at most FLASH_ALPHA.
const FLASH_SECONDS := 0.5
const FLASH_ALPHA := 0.8
const RANDOM_SEED := 73
## The well, and the liquid's rows (lit on top, mid, dark at the bottom) by status, the user's idea
## from their play test of 2026-10-19: red (tomato) while short, orange from NEAR_SHARE of the
## quota, money green once it is met, and gold past the flag. The colour eases to a new status
## over about 1 / STATUS_EASE_RATE seconds (at once under reduced motion). The tag and the flag say
## the same, so the status never shows by colour alone.
const WELL_COLOR := Palette.CHARCOAL
const SHORT_RAMP: Array[Color] = [Palette.TOMATO_LIGHT, Palette.TOMATO, Palette.TOMATO_DARK]
const NEAR_RAMP: Array[Color] = [Palette.MUSTARD, Palette.BRASS, Palette.BRASS_DARK]
const MET_RAMP: Array[Color] = [Palette.GREEN_LIGHT, Palette.GOOD, Palette.GREEN_DARK]
const PAST_RAMP: Array[Color] = [Palette.MUSTARD_PALE, Palette.MUSTARD_LIGHT, Palette.MUSTARD]
const STATUS_EASE_RATE := 6.0
const BUBBLE_COLOR := Palette.PAPER
## A drag's preview: the stretch a drop would add (the ramp's top, see-through) and the one it
## would lose (its bottom).
const GAIN_PREVIEW_ALPHA := 0.55
const LOSS_PREVIEW_ALPHA := 0.8

## Returns whether to reduce motion (the profile's setting); an empty Callable means no.
var reduced_motion: Callable = Callable()

var quota_label: Label
var amount_label: Label
## How far the quota is (LedBeat.to_go_text); hidden while a drag shows its change.
var tag_label: Label
## A drag's change, in the tag's slot; empty otherwise.
var delta_label: Label
var _bar: Control
## The tag's slot, shared with the change.
var _tail: Control
var _tag_style: StyleBoxFlat
var _flag: QuotaFlag
var _amount: int = 0
var _quota: int = 0
## A drag's would-be total, -1 when no drag shows.
var _hypothetical: int = -1
var _blank: bool = true
## The quota is met: the count-up's ding while counting, the projected total reaching it in
## planning.
var _met: bool = false
var _led: LedDisplay
## The amount drawn, eased (EASE_RATE).
var _shown: float = 0.0
var _slosh: float = 0.0
var _flash: float = 0.0
var _time: float = 0.0
var _bubbles: Array[Vector3] = []
var _drops: Array[Dictionary] = []
var _punch: Tween
## The liquid's rows as drawn: eased to the status's ramp (_status_ramp).
var _ramp: Array[Color] = SHORT_RAMP.duplicate()
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", SEPARATION)
	add_child(TopBar.key_label(QUOTA_WORD))
	quota_label = TopBar.value_label(Palette.PAPER)
	add_child(quota_label)
	_bar = Control.new()
	_bar.name = "Bar"
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.custom_minimum_size = Vector2(BAR_MIN_WIDTH, BAR_HEIGHT)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ArtStyle.use_pixel_material(_bar)
	_bar.draw.connect(_draw_bar)
	add_child(_bar)
	_flag = QuotaFlag.new()
	_flag.reduced_motion = _reduced
	_bar.add_child(_flag)
	amount_label = TopBar.value_label(Palette.MUSTARD_LIGHT)
	amount_label.custom_minimum_size.x = amount_width()
	add_child(amount_label)
	# The tag's slot is reserved for its widest text and a drag's change, so the gauge does not
	# jump when either shows.
	_tail = Control.new()
	_tail.name = "Tail"
	_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tail.custom_minimum_size = Vector2(maxf(tag_width(), delta_width()), TopBar.ROW_SIZE.y / 2.0)
	_tail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_tail)
	tag_label = UiKit.body_label("", TAG_FONT_SIZE, LedBeat.FIZZLE_COLOR)
	tag_label.add_theme_font_override("font", ArtStyle.bold_font(TAG_WEIGHT))
	tag_label.add_theme_constant_override("outline_size", 0)
	tag_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tag_style = StyleBoxFlat.new()
	_tag_style.bg_color = Palette.PAPER
	_tag_style.border_color = Palette.INK
	_tag_style.set_border_width_all(TAG_BORDER)
	_tag_style.content_margin_left = TAG_PADDING + TAG_BORDER
	_tag_style.content_margin_right = TAG_PADDING + TAG_BORDER
	tag_label.add_theme_stylebox_override("normal", _tag_style)
	tag_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_tail.add_child(tag_label)
	delta_label = TopBar.value_label(Palette.MUSTARD_LIGHT)
	delta_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	delta_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_tail.add_child(delta_label)
	_random.seed = RANDOM_SEED
	for _index: int in range(BUBBLES):
		_bubbles.append(Vector3(_random.randf(), _random.randf(), _random.randf_range(6.0, 16.0)))


## Mirrors `led`: its readings and its blank mode.
func follow(led: LedDisplay) -> void:
	_led = led
	led.reading_changed.connect(_on_reading)
	led.mode_changed.connect(_on_mode)


## Planning: the preview's projected `amount` against `quota`; the flag is planted once it reaches
## the quota.
func show_projected(amount: int, quota: int) -> void:
	_hypothetical = -1
	_show(amount, quota, quota > 0 and amount >= quota)


## A drag's landing (#71): the total `amount` the drop would give, `delta` more (or less) than the
## projected one, against `quota`; the gauge previews the stretch. show_projected puts the
## projection back.
func show_hypothetical(amount: int, delta: int, quota: int) -> void:
	_show(amount - delta, quota, quota > 0 and amount - delta >= quota)
	_hypothetical = amount
	amount_label.text = HYPOTHETICAL_AMOUNT % amount
	delta_label.text = HYPOTHETICAL_DELTA % delta
	tag_label.visible = false
	_bar.queue_redraw()


## The amount as it reads: with a drag's change after it ("› €52 (+6)", HYPOTHETICAL_TEXT).
func shown_text() -> String:
	if delta_label.text.is_empty():
		return amount_label.text
	return "%s %s" % [amount_label.text, delta_label.text]


## The gauge's fill for `amount` against `quota`, from 0 to 1 (full for a quota of 0): full at the
## quota and past it, since past it the gauge re-scales to the amount. Display arithmetic only, as
## LedDisplay.lit_segments.
static func fill_fraction(amount: int, quota: int) -> float:
	if quota <= 0:
		return 1.0
	return clampf(float(maxi(amount, 0)) / quota, 0.0, 1.0)


## Where the flag stands for `amount` against `quota`, as a fraction of the gauge's inside: at the
## end until the amount passes the quota, then at quota / amount. Display arithmetic only.
static func flag_fraction(amount: int, quota: int) -> float:
	if quota <= 0:
		return 1.0
	return float(quota) / maxi(quota, amount)


## The gauge's fill, as a fraction of its inside (for tests).
func fill() -> float:
	return 0.0 if _blank else fill_fraction(_amount, _quota)


## Whether the flag stands at the quota (the quota met).
func flag_shown() -> bool:
	return _flag.visible


## The chip glows (short of the quota, from NEAR_SHARE of it).
func is_near() -> bool:
	return not _blank and not _met and _quota > 0 and _amount >= _quota * NEAR_SHARE


## The amount label's reserved width: a drag's "› €" and AMOUNT_DIGITS of the widest digit, in
## the value font (measured with the font: the label is not in the tree yet).
static func amount_width() -> float:
	var prefix: String = HYPOTHETICAL_AMOUNT % 0
	return ceilf(_text_width(prefix.left(-1)) + AMOUNT_DIGITS * _digit_width())


## The tag slot's reserved width for a drag's change: the brackets, the wider sign and
## DELTA_DIGITS of the widest digit.
static func delta_width() -> float:
	var brackets: float = _text_width(HYPOTHETICAL_DELTA.replace("%+d", ""))
	var sign_width: float = maxf(_text_width("+"), _text_width("-"))
	return ceilf(brackets + sign_width + DELTA_DIGITS * _digit_width())


## The tag's reserved width: "€N to go" with TAG_DIGITS of the widest digit, its padding and
## border.
static func tag_width() -> float:
	var font: Font = ArtStyle.bold_font(TAG_WEIGHT)
	var text: String = LedBeat.TO_GO_TEXT % 0
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT_SIZE).x
	var digit: float = font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, TAG_FONT_SIZE).x
	return ceilf(width + (TAG_DIGITS - 1) * digit + 2.0 * (TAG_PADDING + TAG_BORDER))


func bar() -> Control:
	return _bar


func flag() -> QuotaFlag:
	return _flag


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_flash = maxf(0.0, _flash - delta / FLASH_SECONDS)
	var target: Array[Color] = _status_ramp()
	for index: int in range(_ramp.size()):
		var weight: float = 1.0 if _reduced() else minf(1.0, delta * STATUS_EASE_RATE)
		_ramp[index] = _ramp[index].lerp(target[index], weight)
	if _reduced():
		_shown = float(_amount)
		_slosh = 0.0
		_drops.clear()
	else:
		_shown += (_amount - _shown) * minf(1.0, delta * EASE_RATE)
		if absf(_amount - _shown) < 0.3:
			_shown = float(_amount)
		_slosh *= exp(-delta * SLOSH_DECAY)
		_move_drops(delta)
	_place_flag()
	_bar.queue_redraw()
	queue_redraw()


func _draw() -> void:
	if not is_near():
		return
	var chip: Control = get_parent() as Control
	if chip == null:
		return
	var alpha: float = 1.0
	if not _reduced():
		alpha = 0.5 - 0.5 * cos(TAU * fmod(_time, GLOW_SECONDS) / GLOW_SECONDS)
	var rect: Rect2 = Rect2(-position, chip.size).grow(GLOW_WIDTH / 2.0)
	draw_rect(rect, Color(Palette.MUSTARD_LIGHT, alpha), false, GLOW_WIDTH)


## Shows `amount` against `quota`, `met` or not: a gain sloshes and sprays, meeting the quota
## plants the flag and flashes, a lower amount (a new count) empties the gauge at once.
func _show(amount: int, quota: int, met: bool) -> void:
	var gain: int = amount - _amount
	if _blank or gain < 0:
		_shown = float(amount)
		_drops.clear()
	elif gain > 0 and not _reduced():
		_slosh = minf(SLOSH_MAX, _slosh + SLOSH_KICK + gain / SLOSH_PER_EURO)
		_spray(mini(SPRAY_MAX, SPRAY_DROPS + roundi(gain / SPRAY_PER_EURO)))
		_punch_amount()
	_blank = false
	_amount = amount
	_quota = quota
	if met and not _met:
		_flash = 1.0
		_flag.plant()
	elif not met:
		_flag.visible = false
	_met = met
	amount_label.text = "€%d" % amount
	delta_label.text = ""
	_show_tag(amount, quota)
	if _reduced():
		_shown = float(amount)
	_place_flag()
	_bar.queue_redraw()
	queue_redraw()


func _show_tag(amount: int, quota: int) -> void:
	var margin: ShiftMargin = ShiftMargin.of(amount, quota)
	tag_label.text = LedBeat.to_go_text(margin)
	tag_label.visible = true
	var short: bool = margin.kind() == ShiftMargin.Kind.SHORT
	_tag_style.bg_color = Palette.PAPER if short else Palette.MUSTARD
	var colour: Color = LedBeat.FIZZLE_COLOR if short and not is_near() else Palette.INK
	tag_label.add_theme_color_override("font_color", colour)


func _on_reading(amount: int, quota: int, met: bool) -> void:
	_hypothetical = -1
	_show(amount, quota, met and _led != null and _counting(_led.mode()))


func _on_mode(mode: LedDisplay.Mode) -> void:
	if mode == LedDisplay.Mode.BLANK:
		_blank = true
		_hypothetical = -1
		amount_label.text = ""
		delta_label.text = ""
		tag_label.text = ""
		tag_label.visible = false
		_met = false
		_flag.visible = false
		_drops.clear()
	_bar.queue_redraw()
	queue_redraw()


func _punch_amount() -> void:
	if not is_inside_tree():
		return
	if _punch != null:
		_punch.kill()
	amount_label.pivot_offset = Vector2(0.0, amount_label.size.y / 2.0)
	amount_label.scale = Vector2.ONE * AMOUNT_PUNCH
	_punch = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_punch.tween_property(amount_label, "scale", Vector2.ONE, AMOUNT_PUNCH_SECONDS)


## The liquid's ramp for the status now (up to the flag): SHORT_RAMP, NEAR_RAMP from NEAR_SHARE
## of the quota, MET_RAMP once met (PAST_RAMP past the flag is drawn apart).
func _status_ramp() -> Array[Color]:
	if _met:
		return MET_RAMP
	if is_near() or (_quota > 0 and _amount >= _quota):
		return NEAR_RAMP
	return SHORT_RAMP


## The liquid's ramp as drawn now (for tests).
func ramp() -> Array[Color]:
	return _ramp


## The gauge's scale now: the quota while short, the larger of it and what shows once met.
func _scale() -> float:
	var top: float = float(_quota)
	if _met:
		top = maxf(top, _shown)
		if _hypothetical >= 0:
			top = maxf(top, float(_hypothetical))
	return maxf(top, 1.0)


## The gauge's size in art pixels.
func _art_size() -> Vector2i:
	return Vector2i((_bar.size / ArtStyle.ART_SCALE).floor())


func _place_flag() -> void:
	if not _flag.visible:
		return
	var inner: float = _art_size().x - 2.0
	var x: float = 1.0 + inner * minf(1.0, _quota / _scale())
	_flag.position = Vector2(roundf(x) * ArtStyle.ART_SCALE, 0.0)
	_flag.set_pole(_bar.size.y)


func _spray(count: int) -> void:
	var height: float = _art_size().y
	for _index: int in range(count):
		(
			_drops
			. append(
				{
					"at": Vector2(-1.0, height / 2.0 + _random.randf_range(-0.3, 0.3) * height),
					"velocity":
					Vector2(_random.randf_range(10.0, 40.0), _random.randf_range(-50.0, -20.0)),
					"life": SPRAY_LIFE,
				}
			)
		)


func _move_drops(delta: float) -> void:
	var kept: Array[Dictionary] = []
	var front: float = _front()
	for drop: Dictionary in _drops:
		var life: float = drop["life"]
		life -= delta
		if life <= 0.0:
			continue
		var at: Vector2 = drop["at"]
		if at.x < 0.0:
			at.x = front
		var velocity: Vector2 = drop["velocity"]
		drop["at"] = at + velocity * delta
		drop["velocity"] = velocity + Vector2(0.0, SPRAY_GRAVITY * delta)
		drop["life"] = life
		kept.append(drop)
	_drops = kept


## The liquid's front, in art pixels from the gauge's left.
func _front() -> float:
	var inner: float = _art_size().x - 2.0
	return 1.0 + inner * minf(_shown, _scale()) / _scale()


func _draw_bar() -> void:
	var art: Vector2i = _art_size()
	if art.x < 3 or art.y < 3:
		return
	_cell(0, 0, art.x, art.y, Palette.INK)
	_cell(1, 1, art.x - 2, art.y - 2, WELL_COLOR)
	if _blank:
		return
	var reduced: bool = _reduced()
	var inner: float = art.x - 2.0
	var front: float = _front()
	var flag_x: float = 1.0 + inner * minf(1.0, _quota / _scale()) if _met else INF
	var preview_x: float = -1.0
	if _hypothetical >= 0:
		preview_x = 1.0 + inner * minf(float(_hypothetical), _scale()) / _scale()
	for y: int in range(1, art.y - 1):
		var wobble: float = 0.0
		if not reduced:
			wobble = _slosh * sin(y * 0.9 + _time * 14.0) + RIPPLE * sin(y * 0.5 - _time * 6.0)
		var end: float = clampf(front + wobble, 1.0, art.x - 1.0)
		var row: int = 0 if y < 3 else (2 if y >= art.y - 3 else 1)
		_span(1.0, minf(end, flag_x), y, _ramp[row])
		if end > flag_x:
			_span(flag_x, end, y, PAST_RAMP[row])
		if preview_x > front:
			_span(front, preview_x, y, Color(_ramp[0], GAIN_PREVIEW_ALPHA))
		elif preview_x >= 0.0 and preview_x < front:
			_span(preview_x, front, y, Color(_ramp[2], LOSS_PREVIEW_ALPHA))
	if reduced:
		_draw_flash(art)
		return
	# The shine sweeps the liquid; bubbles drift right and up in it; the spray flies off the front.
	var shine: float = fmod(_time * SHINE_SPEED, art.x + 40.0) - 20.0
	for y: int in range(1, art.y - 1):
		var x: float = shine + (art.y - y) * SHINE_LEAN
		if x > 1.0 and x < front - 2.0:
			_cell(floori(x), y, 1, 1, Palette.PAPER)
	for bubble: Vector3 in _bubbles:
		var x: float = 1.0 + fmod(bubble.x * inner + _time * bubble.z, maxf(1.0, front - 4.0))
		var y: float = art.y - 2.0 - fmod(bubble.y * art.y + _time * 3.0, art.y - 3.0)
		if x < front - 3.0:
			_cell(floori(x), floori(y), 1, 1, BUBBLE_COLOR)
	for drop: Dictionary in _drops:
		var at: Vector2 = drop["at"]
		var life: float = drop["life"]
		if at.x < 0.0 or at.x >= art.x - 1 or at.y >= art.y - 1:
			continue
		var y: float = maxf(at.y, 0.0)
		_cell(floori(at.x), floori(y), 1, 1, _ramp[0] if life > SPRAY_LIFE / 2.0 else _ramp[1])
	_draw_flash(art)


func _draw_flash(art: Vector2i) -> void:
	if _flash > 0.0:
		_cell(1, 1, art.x - 2, art.y - 2, Color(Palette.PAPER, _flash * FLASH_ALPHA))


## A row's span from art column `from` to `to` (rounded to whole art pixels).
func _span(from: float, to: float, y: int, colour: Color) -> void:
	var left: int = roundi(from)
	var right: int = roundi(to)
	if right > left:
		_cell(left, y, right - left, 1, colour)


func _cell(x: int, y: int, width: int, height: int, colour: Color) -> void:
	var cell: float = ArtStyle.ART_SCALE
	_bar.draw_rect(Rect2(x * cell, y * cell, width * cell, height * cell), colour)


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())


static func _text_width(text: String) -> float:
	var font: Font = ArtStyle.number_font()
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, TopBar.VALUE_FONT_SIZE).x


static func _digit_width() -> float:
	var digit: float = 0.0
	for value: int in range(10):
		digit = maxf(digit, _text_width(str(value)))
	return digit


## The LED shows the count-up's SUBTOTAL or TOTAL.
static func _counting(mode: LedDisplay.Mode) -> bool:
	return mode == LedDisplay.Mode.SUBTOTAL or mode == LedDisplay.Mode.TOTAL
