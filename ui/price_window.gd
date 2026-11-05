class_name PriceWindow
extends TipTarget
## A ticket's price window (tickets v5, V5a of mock-up shift_scene_polish_v5_tickets.html): the
## fixed 28x11 art box in the ticket's top-right corner (TicketFace.WINDOW, at 2x, framed by the
## ticket's face) that shows the item's one payout. Its size never changes, so the icons and the
## rule never move: the digits sit centred in it on the art's grid (digits_at; the PR #138 review:
## a long or small-digit price no longer drifts to the window's foot), and a price too wide for it
## falls back (form_for): the 6x8 digits up to 999€, the 4x7 ones up to 9999€, then "Nk€" (rounded
## down) in 6x8, then in 4x7; the exact amount is in its tip.
##
## Its fill is paper in every state (the user's play test of 2026-11-03: "price bg shouldn't change
## when price increase instead number color should change"); the digits' ink says the pay
## (digit_color), in the classic strength ramp (the PR #138 review: "black for base, yellow/orange
## for semi strong and red for strong"): PRINTED, the base, in ink; BOOSTED by its strength against
## its base (BOOST_INKS, steps from boost_step): semi strong amber (mustard dark), then orange,
## below pay_ink_ratios[1] times the base, strong red from it, each on a darker shadow so it also
## reads by its weight; LOWERED and ZERO in grey (muted ink, the PR #138 round 2: a lowered pay is
## not a warning) with no shadow. COUPON shows the teal
## scissors (a coupon pays nothing itself), WASTED (a coupon that gave nothing) grey scissors
## under a tomato-dark slash. It never draws gold: GOLDEN is the ticket's ring (PriceSticker). Off
## a ticket (a drag's ghost carries its pay) it is `framed`, in an ink edge of its own.
##
## Resting the pointer on it shows its tip (TipTarget: the printed price and the pay, set by its
## ticket). Dimmed (an unrelated item while another is hovered) it fades to `dimmed_alpha` over
## the ticket's paper. Decor only: every number is a payout from the score.

enum State { PRINTED, BOOSTED, LOWERED, ZERO, COUPON, WASTED }

## The window's size (TicketFace.WINDOW at 2x).
const SIZE := Vector2(56, 22)
## The window in art px (SIZE at ART_SCALE).
const ART := Vector2i(28, 11)
## The digits' room (art px from the window's left): from DIGITS_LEFT to DIGITS_RIGHT (inclusive),
## rows down to DIGITS_FOOT, so the shadow, one art px down and right of them, stays inside the
## window (its last row and column). Every form fits it (form_for); the digits sit centred in the
## window (digits_at), and a wasted coupon's slash spans the room.
const DIGITS_LEFT := 0
const DIGITS_RIGHT := 26
const DIGITS_FOOT := 9
const SHADOW_OFFSET := Vector2i(1, 1)
## The one fill of every state.
const FILL := Palette.PAPER
## A boosted pay's digits by boost_step (1 to 3): [ink, shadow]; a transparent shadow draws none.
## Steps 1 and 2 are semi strong (below pay_ink_ratios[1] times the base: amber, then orange from
## pay_ink_ratios[0] times), step 3 strong (red). Step 1's amber is mustard dark, so its ink
## reads on the paper by itself (about 3.1:1; the paler orange light was 1.9:1, the PR #138
## review). None is gold, mustard itself or brass (the GOLDEN ring's) or the grey of a lowered
## pay.
const BOOST_INKS: Array[Array] = [
	[Palette.MUSTARD_DARK, Palette.MUSTARD_DARKEST],
	[Palette.ORANGE, Palette.ORANGE_DARK],
	[Palette.TOMATO, Palette.TOMATO_DARKEST],
]
## The first strong step (BOOST_INKS): the ones before it are semi strong.
const STRONG_STEP := 3
## A lowered or 0€ pay's digits: grey (the PR #138 round 2, the user's answer of 2026-11-04: they
## were tomato dark), about 3.6:1 on the paper, so the bold digits still read.
const NEGATIVE_INK := Palette.MUTED_INK
## The coupon's scissors (art px, its top-left from the window's), and a wasted coupon's slash
## from SLASH_LEFT to the digits' right end, falling SLASH_DROP rows.
const SCISSORS: Array[String] = [
	".##....#", "#..#..#.", ".##..#..", "...##...", ".##..#..", "#..#..#.", ".##....#"
]
const SCISSORS_AT := Vector2i(19, 2)
const SCISSORS_INK := Palette.TEAL_SHADE
const WASTED_SCISSORS_INK := Palette.GREY
## A wasted coupon's slash stays tomato dark (only lowered and 0€ digits went grey, PR #138
## round 2), so "gave nothing" still reads.
const WASTED_SLASH_INK := Palette.TOMATO_DARK
const SLASH_LEFT := 1
const SLASH_DROP := 7
## A framed window's ink edge (one art px round it).
const FRAME := 2.0
## The fallback "Nk€" form.
const THOUSANDS := "%dk€"
const STATE_NAMES: Array[String] = ["printed", "boosted", "lowered", "0€", "coupon", "wasted"]
## The tuning whose pay_ink_ratios set the boost steps.
const TUNING_PATH := "res://data/balance/planning.tres"

static var _ratios: PackedInt32Array = PackedInt32Array()
static var _ratios_read: bool = false

## The alpha a dimmed window fades to (PlanningTuning.dim_ticket_alpha).
var dimmed_alpha: float = 1.0
var _state: State = State.PRINTED
var _amount: int = 0
var _framed: bool = false
var _step: int = 0
var _digits: PixelWords
var _shadow: PixelWords
var _dimmed: bool = false
var _tween: Tween


## A window showing `amount` in `state` (against its item's `base`); `framed` off a ticket.
func _init(
	state: State = State.PRINTED, amount: int = 0, framed: bool = false, base: int = 0
) -> void:
	super()
	name = "PriceWindow"
	_framed = framed
	size = SIZE
	custom_minimum_size = SIZE
	_shadow = PixelWords.new()
	_shadow.name = "Shadow"
	add_child(_shadow)
	_digits = PixelWords.new()
	_digits.name = "Digits"
	add_child(_digits)
	show_pay(state, amount, base)


## Shows `amount` in `state` (a coupon's states show no digits); a boosted amount's ink steps up
## with it against `base`, its item's printed price (boost_step).
func show_pay(state: State, amount: int, base: int = 0) -> void:
	_state = state
	_amount = amount
	_step = boost_step(amount, base) if state == State.BOOSTED else 0
	var coupon: bool = state == State.COUPON or state == State.WASTED
	_digits.visible = not coupon
	var shadow_ink: Color = shadow_color(state, _step)
	_shadow.visible = not coupon and shadow_ink.a > 0.0
	if not coupon:
		var form: Array = form_for(amount)
		var art: Vector2i = PixelWords.font_size_of(form[0], form[1])
		var at: Vector2 = Vector2(digits_at(art)) * _px()
		for words: PixelWords in [_digits, _shadow]:
			words.sheet = form[1]
			words.text = form[0]
			words.cell = ArtStyle.ART_SCALE
			words.position = at
			words.size = Vector2(art) * _px()
		_digits.color = digit_color(state, _step)
		_shadow.color = shadow_ink
		_shadow.position = at + Vector2(SHADOW_OFFSET) * _px()
	queue_redraw()


func pay_state() -> State:
	return _state


func pay_amount() -> int:
	return _amount


## The boosted pay's step (1 to BOOST_INKS.size(); 0 in any other state).
func boost_level() -> int:
	return _step


## The digits (PixelWords: their text, sheet and rect), hidden on a coupon.
func digits() -> PixelWords:
	return _digits


## The digits' shadow (PixelWords), shown on a boosted pay only.
func shadow() -> PixelWords:
	return _shadow


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


## Where digits `art` art px in size sit (their top left, art px from the window's): centred in the
## window, on the art's grid (an odd room leaves the spare art px right of them and under them,
## where the shadow falls), and inside the digits' room. Pure.
static func digits_at(art: Vector2i) -> Vector2i:
	var at: Vector2i = Vector2i(floori((ART.x - art.x) / 2.0), floori((ART.y - art.y) / 2.0))
	at.x = clampi(at.x, DIGITS_LEFT, maxi(DIGITS_RIGHT + 1 - art.x, DIGITS_LEFT))
	at.y = clampi(at.y, 0, maxi(DIGITS_FOOT + 1 - art.y, 0))
	return at


## The boost step of a boosted `amount` against `base` (its printed price, at least 1): 1, then
## one more at each of the tuning's pay_ink_ratios it reaches, at most BOOST_INKS.size().
static func boost_step(amount: int, base: int) -> int:
	var step: int = 1
	for ratio: int in ink_ratios():
		if ratio > 0 and amount >= maxi(base, 1) * ratio:
			step += 1
	return mini(step, BOOST_INKS.size())


## The tuning's pay_ink_ratios (data/balance/planning.tres), read once.
static func ink_ratios() -> PackedInt32Array:
	if not _ratios_read:
		_ratios_read = true
		var tuning: PlanningTuning = load(TUNING_PATH) as PlanningTuning
		if tuning != null:
			_ratios = tuning.pay_ink_ratios
	return _ratios


## The digits' colour in `state` (a boosted pay's at its `step`, 1 to 3).
static func digit_color(state: State, step: int = 1) -> Color:
	match state:
		State.BOOSTED:
			return BOOST_INKS[clampi(step, 1, BOOST_INKS.size()) - 1][0]
		State.LOWERED, State.ZERO:
			return NEGATIVE_INK
	return Palette.INK


## The digits' shadow in `state` (transparent: none).
static func shadow_color(state: State, step: int = 1) -> Color:
	if state != State.BOOSTED:
		return Color.TRANSPARENT
	return BOOST_INKS[clampi(step, 1, BOOST_INKS.size()) - 1][1]


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
	draw_rect(Rect2(Vector2.ZERO, size), FILL)
	if _state == State.COUPON or _state == State.WASTED:
		var ink: Color = SCISSORS_INK if _state == State.COUPON else WASTED_SCISSORS_INK
		for row: int in SCISSORS.size():
			for column: int in SCISSORS[row].length():
				if SCISSORS[row][column] == "#":
					_cell(SCISSORS_AT + Vector2i(column, row), ink, px)
	if _state == State.WASTED:
		var length: int = DIGITS_RIGHT - SLASH_LEFT + 2
		for step: int in length:
			var drop: int = floori(step * SLASH_DROP / float(length - 1))
			_cell(Vector2i(SLASH_LEFT + step, DIGITS_FOOT - drop), WASTED_SLASH_INK, px)


func _cell(at: Vector2i, colour: Color, px: float) -> void:
	draw_rect(Rect2(Vector2(at) * px, Vector2(px, px)), colour)


func _px() -> float:
	return float(ArtStyle.ART_SCALE)
