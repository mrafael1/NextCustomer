class_name QuotaMeter
extends HBoxContainer
## The top bar's QUOTA chip contents (#80 step 10, mock-up B2): the QUOTA word, the shift's quota,
## a bar filled in proportion to the amount, the amount in mustard, and a check disc once the
## count-up has met the quota, so meeting it never shows by colour alone. In planning the amount is
## the projected total, which the shift screen hands it from its preview (show_projected): the
## monitor shows its store channel then, not the total (the user's play test of 2026-10-17).
## During the count it mirrors the monitor's LED (follow): the running subtotal, so the bar never
## shows the final total early; once the count meets the quota the check stays until the LED
## leaves the count (blank for the next shift's planning, which shows the projected total again).
## Blank LED alone (the impulse rack): no amount and an empty bar. While an item is dragged over
## a landing slot (#71, decision 4A) it shows the total that drop would give and its change, e.g.
## "› €52 (+6)" (show_hypothetical; the fonts have no →), until the drag ends: the amount in its
## label, the change in the check's slot (the check shows only while counting, the change only in
## planning). Both keep reserved widths, so the bar never moves while a drag crosses the slots.
## Display only: the amounts are the screen's preview and the LED's.

const SEPARATION := 8
## The bar: at least this wide, B2's 14 px tall, with a 2 px ink border; its fill snaps to the
## 2 px art grid.
const BAR_MIN_WIDTH := 80.0
const BAR_HEIGHT := 14.0
const BAR_BORDER := 2.0
## The bar's well: ink at B2's 35% black over the chip.
const WELL_COLOR := Color(0, 0, 0, 0.35)
## The fill's lit top edge (B2's inset 3 px mustard light).
const FILL_LIT := 3.0
const CHECK_SIZE := Vector2(26, 26)
## The amount's reserved digits: its label is at least as wide as this many of the widest digit
## after a drag's "› €", so the bar keeps its width while the subtotal gains digits and a drag
## shows its total.
const AMOUNT_DIGITS := 4
## The change's reserved digits after its sign, in brackets (the check's slot is this wide).
const DELTA_DIGITS := 3
## A drag's would-be total and its change from the projected one (#71), and the two read together
## (shown_text).
const HYPOTHETICAL_AMOUNT := "› €%d"
const HYPOTHETICAL_DELTA := "(%+d)"
const HYPOTHETICAL_TEXT := HYPOTHETICAL_AMOUNT + " " + HYPOTHETICAL_DELTA

const CHECK := preload("res://art/icons/mark_check.png")

var quota_label: Label
var amount_label: Label
## A drag's change, in the check's slot; empty otherwise.
var delta_label: Label
var _bar: Control
## The check's slot, shared with the change.
var _tail: Control
var _check: TextureRect
var _amount: int = 0
var _quota: int = 0
var _blank: bool = true
var _led: LedDisplay


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", SEPARATION)
	add_child(TopBar.key_label("QUOTA"))
	quota_label = TopBar.value_label(Palette.PAPER)
	add_child(quota_label)
	_bar = Control.new()
	_bar.name = "Bar"
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.custom_minimum_size = Vector2(BAR_MIN_WIDTH, BAR_HEIGHT)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar.draw.connect(_draw_bar)
	add_child(_bar)
	amount_label = TopBar.value_label(Palette.MUSTARD_LIGHT)
	amount_label.custom_minimum_size.x = amount_width()
	add_child(amount_label)
	# The check is the belt's mark_check disc (a drawn ✓, which the fonts lack). It keeps its slot
	# while hidden (transparent, not invisible), so the bar does not jump when it appears; a drag's
	# change shares that slot, reserved for its widest text.
	_tail = Control.new()
	_tail.name = "Tail"
	_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tail.custom_minimum_size = Vector2(maxf(CHECK_SIZE.x, delta_width()), CHECK_SIZE.y)
	_tail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_tail)
	_check = UiKit.sprite(CHECK)
	_check.custom_minimum_size = CHECK_SIZE
	_check.size = CHECK_SIZE
	_tail.add_child(_check)
	_show_check(false)
	delta_label = TopBar.value_label(Palette.MUSTARD_LIGHT)
	delta_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	delta_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_tail.add_child(delta_label)


## Mirrors `led`: its readings and its blank mode.
func follow(led: LedDisplay) -> void:
	_led = led
	led.reading_changed.connect(_on_reading)
	led.mode_changed.connect(_on_mode)


## Planning: the preview's projected `amount` against `quota`, without the check.
func show_projected(amount: int, quota: int) -> void:
	_blank = false
	_amount = amount
	_quota = quota
	amount_label.text = "€%d" % amount
	delta_label.text = ""
	_show_check(false)
	_bar.queue_redraw()


## A drag's landing (#71): the total `amount` the drop would give, `delta` more (or less) than the
## projected one, against `quota`, without the check. show_projected puts the projection back.
func show_hypothetical(amount: int, delta: int, quota: int) -> void:
	show_projected(amount, quota)
	amount_label.text = HYPOTHETICAL_AMOUNT % amount
	delta_label.text = HYPOTHETICAL_DELTA % delta


## The amount as it reads: with a drag's change after it ("› €52 (+6)", HYPOTHETICAL_TEXT).
func shown_text() -> String:
	if delta_label.text.is_empty():
		return amount_label.text
	return "%s %s" % [amount_label.text, delta_label.text]


## The bar's fill for `amount` against `quota`, from 0 to 1 (full for a quota of 0). Display
## arithmetic only, as LedDisplay.lit_segments.
static func fill_fraction(amount: int, quota: int) -> float:
	if quota <= 0:
		return 1.0
	return clampf(float(maxi(amount, 0)) / quota, 0.0, 1.0)


## The bar's fill, as a fraction of its inside (for tests).
func fill() -> float:
	return 0.0 if _blank else fill_fraction(_amount, _quota)


## Whether the check shows (the count-up met the quota).
func check_shown() -> bool:
	return _check.modulate.a > 0.0


## The amount label's reserved width: a drag's "› €" and AMOUNT_DIGITS of the widest digit, in
## the value font (measured with the font: the label is not in the tree yet).
static func amount_width() -> float:
	var prefix: String = HYPOTHETICAL_AMOUNT % 0
	return ceilf(_text_width(prefix.left(-1)) + AMOUNT_DIGITS * _digit_width())


## The check's slot's reserved width for a drag's change: the brackets, the wider sign and
## DELTA_DIGITS of the widest digit.
static func delta_width() -> float:
	var brackets: float = _text_width(HYPOTHETICAL_DELTA.replace("%+d", ""))
	var sign_width: float = maxf(_text_width("+"), _text_width("-"))
	return ceilf(brackets + sign_width + DELTA_DIGITS * _digit_width())


func bar() -> Control:
	return _bar


func check() -> TextureRect:
	return _check


func _on_reading(amount: int, quota: int, met: bool) -> void:
	_blank = false
	_amount = amount
	_quota = quota
	amount_label.text = "€%d" % amount
	delta_label.text = ""
	_show_check(met and _led != null and _counting(_led.mode()))
	_bar.queue_redraw()


func _on_mode(mode: LedDisplay.Mode) -> void:
	if mode == LedDisplay.Mode.BLANK:
		_blank = true
		amount_label.text = ""
		delta_label.text = ""
	if not _counting(mode):
		_show_check(false)
	_bar.queue_redraw()


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


func _show_check(shown: bool) -> void:
	_check.modulate.a = 1.0 if shown else 0.0


func _draw_bar() -> void:
	var outer: Rect2 = Rect2(Vector2.ZERO, _bar.size)
	_bar.draw_rect(outer, Palette.INK)
	var inside: Rect2 = outer.grow(-BAR_BORDER)
	_bar.draw_rect(inside, Palette.PANEL)
	_bar.draw_rect(inside, WELL_COLOR)
	var width: float = snappedf(inside.size.x * fill(), 2.0)
	if width <= 0.0:
		return
	var filled: Rect2 = Rect2(inside.position, Vector2(width, inside.size.y))
	_bar.draw_rect(filled, Palette.MUSTARD)
	_bar.draw_rect(Rect2(filled.position, Vector2(width, FILL_LIT)), Palette.MUSTARD_LIGHT)
