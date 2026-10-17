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
## Blank LED alone (the impulse rack): no amount and an empty bar. Display only: the amounts are
## the screen's preview and the LED's.

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
## after the euro sign, so the bar keeps its width while the subtotal gains digits.
const AMOUNT_DIGITS := 4

const CHECK := preload("res://art/icons/mark_check.png")

var quota_label: Label
var amount_label: Label
var _bar: Control
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
	# while hidden (transparent, not invisible), so the bar does not jump when it appears.
	_check = UiKit.sprite(CHECK)
	_check.custom_minimum_size = CHECK_SIZE
	_check.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_check)
	_show_check(false)


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
	_show_check(false)
	_bar.queue_redraw()


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


## The amount label's reserved width: the euro sign and AMOUNT_DIGITS of the widest digit, in the
## value font (measured with the font: the label is not in the tree yet).
static func amount_width() -> float:
	var font: Font = ArtStyle.number_font()
	var font_size: int = TopBar.VALUE_FONT_SIZE
	var align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT
	var digit: float = 0.0
	for value: int in range(10):
		digit = maxf(digit, font.get_string_size(str(value), align, -1, font_size).x)
	return ceilf(font.get_string_size("€", align, -1, font_size).x + AMOUNT_DIGITS * digit)


func bar() -> Control:
	return _bar


func check() -> TextureRect:
	return _check


func _on_reading(amount: int, quota: int, met: bool) -> void:
	_blank = false
	_amount = amount
	_quota = quota
	amount_label.text = "€%d" % amount
	_show_check(met and _led != null and _counting(_led.mode()))
	_bar.queue_redraw()


func _on_mode(mode: LedDisplay.Mode) -> void:
	if mode == LedDisplay.Mode.BLANK:
		_blank = true
		amount_label.text = ""
	if not _counting(mode):
		_show_check(false)
	_bar.queue_redraw()


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
