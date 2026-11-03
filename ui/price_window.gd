class_name PriceWindow
extends TipTarget
## A ticket's price window (tickets v5, V5a of mock-up shift_scene_polish_v5_tickets.html): the
## fixed 29x11 art box in the ticket's top-right corner (TicketFace.WINDOW, at 2x) that shows the
## item's one payout. Its size never changes, so the icons and the rule never move: the digits end
## DIGITS_RIGHT art px from its left and sit on DIGITS_FOOT, and a price too wide for it falls back
## (form_for): the 6x8 digits up to 999€, the 4x7 ones up to 9999€, then "Nk€" (rounded down) in
## 6x8, then in 4x7; the exact amount is in its tip.
##
## Its state says what the pay is, each with a texture as well as a fill, so none reads by hue
## alone: PRINTED (paper), BOOSTED (green with a row of up chevrons over the digits), LOWERED
## (pale tomato with down chevrons), ZERO (tomato with paper digits and hatching), COUPON (teal
## with the paper scissors: a coupon pays nothing itself) and WASTED (a coupon that gave nothing:
## grey with a tomato slash). It never draws gold: GOLDEN is the ticket's ring (PriceSticker).
## Off a ticket (a drag's ghost carries its pay) it is `framed`, in an ink edge of its own.
##
## Resting the pointer on it shows its tip (TipTarget: the printed price and the pay, set by its
## ticket). Dimmed (an unrelated item while another is hovered) it fades to `dimmed_alpha` over
## the ticket's paper. Decor only: every number is a payout from the score.

enum State { PRINTED, BOOSTED, LOWERED, ZERO, COUPON, WASTED }

## The window's size (TicketFace.WINDOW at 2x).
const SIZE := Vector2(58, 22)
## The digits' room (art px from the window's left): they end at DIGITS_RIGHT (inclusive) and
## start no further left than DIGITS_LEFT; their foot row is DIGITS_FOOT.
const DIGITS_LEFT := 0
const DIGITS_RIGHT := 26
const DIGITS_FOOT := 9
## The state band: the window's top two rows, a 4-px pattern repeated across BAND_WIDTH art px from
## BAND_LEFT.
const BAND_LEFT := 1
const BAND_WIDTH := 27
const BANDS: Dictionary[State, Array] = {
	State.BOOSTED: [".#..", "#.#."],
	State.LOWERED: ["#.#.", ".#.."],
	State.ZERO: ["##..", ".##."],
}
## The coupon's scissors (art px, its top-left from the window's), and a wasted coupon's slash
## from SLASH_LEFT to the digits' right end, falling SLASH_DROP rows.
const SCISSORS: Array[String] = [
	".##....#", "#..#..#.", ".##..#..", "...##...", ".##..#..", "#..#..#.", ".##....#"
]
const SCISSORS_AT := Vector2i(19, 3)
const SLASH_LEFT := 1
const SLASH_DROP := 7
## A framed window's ink edge (one art px round it).
const FRAME := 2.0
## The fallback "Nk€" form.
const THOUSANDS := "%dk€"
const STATE_NAMES: Array[String] = ["printed", "boosted", "lowered", "0€", "coupon", "wasted"]

## The alpha a dimmed window fades to (PlanningTuning.dim_ticket_alpha).
var dimmed_alpha: float = 1.0
var _state: State = State.PRINTED
var _amount: int = 0
var _framed: bool = false
var _digits: PixelWords
var _dimmed: bool = false
var _tween: Tween


## A window showing `amount` in `state`; `framed` off a ticket.
func _init(state: State = State.PRINTED, amount: int = 0, framed: bool = false) -> void:
	super()
	name = "PriceWindow"
	_framed = framed
	size = SIZE
	custom_minimum_size = SIZE
	_digits = PixelWords.new()
	_digits.name = "Digits"
	add_child(_digits)
	show_pay(state, amount)


## Shows `amount` in `state` (a coupon's states show no digits).
func show_pay(state: State, amount: int) -> void:
	_state = state
	_amount = amount
	var coupon: bool = state == State.COUPON or state == State.WASTED
	_digits.visible = not coupon
	if not coupon:
		var form: Array = form_for(amount)
		_digits.sheet = form[1]
		_digits.text = form[0]
		_digits.cell = ArtStyle.ART_SCALE
		_digits.color = digit_color(state)
		var art: Vector2i = PixelWords.font_size_of(form[0], form[1])
		_digits.position = Vector2(DIGITS_RIGHT + 1 - art.x, DIGITS_FOOT + 1 - art.y) * _px()
		_digits.size = Vector2(art) * _px()
	queue_redraw()


func pay_state() -> State:
	return _state


func pay_amount() -> int:
	return _amount


## The digits (PixelWords: their text, sheet and rect), hidden on a coupon.
func digits() -> PixelWords:
	return _digits


## The digits' rect in the window's coordinates (empty on a coupon).
func digits_rect() -> Rect2:
	if not _digits.visible:
		return Rect2()
	return Rect2(_digits.position, _digits.size)


## The words' state name ("boosted"), for tips and checks.
func state_name() -> String:
	return STATE_NAMES[_state]


## The state of a `pay` (PlanningModel's) on a product's ticket, or a `coupon`'s. Pure.
static func state_for(pay: PlanningModel.Pay, coupon: bool) -> State:
	var zero: bool = pay == PlanningModel.Pay.DENIED or pay == PlanningModel.Pay.ZERO
	if coupon:
		return State.WASTED if zero else State.COUPON
	if zero:
		return State.ZERO
	match pay:
		PlanningModel.Pay.BOOSTED:
			return State.BOOSTED
		PlanningModel.Pay.LOWERED:
			return State.LOWERED
	return State.PRINTED


## How `amount` prints in the window: [text, PixelWords.Sheet], by its size (V5a's ladder, so a
## belt's prices of one size print alike): the 6x8 digits to 999€, the 4x7 ones to 9999€, then
## "12k€" in 6x8, and in 4x7 from 100k€. Each form fits the digits' room (the window test checks
## it). Pure.
static func form_for(amount: int) -> Array:
	if amount <= 999:
		return [MonitorText.euros(amount), PixelWords.Sheet.DIGITS]
	if amount <= 9999:
		return [MonitorText.euros(amount), PixelWords.Sheet.SMALL_DIGITS]
	var short: String = THOUSANDS % floori(amount / 1000.0)
	if amount < 100000:
		return [short, PixelWords.Sheet.DIGITS]
	return [short, PixelWords.Sheet.SMALL_DIGITS]


## The window's fill, its band's colour and its digits' colour in `state`.
static func fill_color(state: State) -> Color:
	match state:
		State.BOOSTED:
			return Palette.GREEN_LIGHT
		State.LOWERED:
			return Palette.TOMATO_PALE
		State.ZERO:
			return Palette.TOMATO
		State.COUPON:
			return Palette.TEAL
		State.WASTED:
			return Palette.GREY_LIGHT
	return Palette.PAPER


static func band_color(state: State) -> Color:
	match state:
		State.BOOSTED:
			return Palette.GREEN_DARK
		State.LOWERED:
			return Palette.TOMATO_LIGHT
		State.ZERO:
			return Palette.TOMATO_DARK
		State.COUPON:
			return Palette.TEAL_SHADE
		State.WASTED:
			return Palette.GREY
	return Palette.CREAM_SHADE


static func digit_color(state: State) -> Color:
	match state:
		State.LOWERED:
			return Palette.TOMATO_DARK
		State.ZERO:
			return Palette.PAPER
	return Palette.INK


## Fades the window to `dimmed_alpha` (`dimmed`) or back to full, over `fade` seconds (0: at once).
func set_dimmed(dimmed: bool, fade: float = 0.0) -> void:
	_dimmed = dimmed
	var alpha: float = dimmed_alpha if dimmed else 1.0
	if _tween != null:
		_tween.kill()
		_tween = null
	if fade > 0.0 and is_inside_tree() and not is_equal_approx(modulate.a, alpha):
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", alpha, fade)
	else:
		modulate.a = alpha


func is_dimmed() -> bool:
	return _dimmed


func _draw() -> void:
	var px: float = _px()
	if _framed:
		draw_rect(Rect2(Vector2.ZERO, size).grow(FRAME), ArtStyle.INK)
	draw_rect(Rect2(Vector2.ZERO, size), fill_color(_state))
	var band: Color = band_color(_state)
	# The lit top row (printed and coupon), or the state's band of chevrons or hatching.
	if BANDS.has(_state):
		var rows: Array = BANDS[_state]
		for row: int in rows.size():
			var pattern: String = rows[row]
			for column: int in BAND_WIDTH:
				if pattern[column % pattern.length()] == "#":
					_cell(Vector2i(BAND_LEFT + column, row), band, px)
	else:
		draw_rect(Rect2(0, 0, size.x - px, px), band)
	if _state == State.COUPON or _state == State.WASTED:
		var ink: Color = Palette.PAPER if _state == State.COUPON else Palette.GREY_DARK
		for row: int in SCISSORS.size():
			for column: int in SCISSORS[row].length():
				if SCISSORS[row][column] == "#":
					_cell(SCISSORS_AT + Vector2i(column, row), ink, px)
	if _state == State.WASTED:
		var length: int = DIGITS_RIGHT - SLASH_LEFT + 2
		for step: int in length:
			var drop: int = floori(step * SLASH_DROP / float(length - 1))
			_cell(Vector2i(SLASH_LEFT + step, DIGITS_FOOT - drop), Palette.TOMATO, px)


func _cell(at: Vector2i, colour: Color, px: float) -> void:
	draw_rect(Rect2(Vector2(at) * px, Vector2(px, px)), colour)


func _px() -> float:
	return float(ArtStyle.ART_SCALE)
