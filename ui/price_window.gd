class_name PriceWindow
extends TipTarget
## A ticket's price window (tickets v5, V5a of mock-up shift_scene_polish_v5_tickets.html): the
## fixed 28x11 art box in the ticket's top-right corner (TicketFace.WINDOW, at 2x, framed by the
## ticket's face) that shows the item's one payout. Its size never changes, so the icons and the
## rule never move: the digits sit centred in it on the art's grid (digits_at; the PR #138 review:
## a long or small-digit price no longer drifts to the window's foot). A price whose 6x8 digits
## fit its room prints in them, in the window ("1111€" too, its digits being narrow). The exact
## amount is in its tip.
##
## A price too wide for the window is not shrunk first (price leak, the user's pick of
## 2026-11-10): it prints in the same 6x8 digits on a yellow paper label stuck over the ticket's
## top-right corner (PriceLabel, its first child: `label()`), which leaks past the ticket's right
## edge and its top, never to the left, by at most PriceLabel.cap() art px. Past the cap
## (PriceLabel.print_for): "Nk€" (rounded down) in 6x8, in the window when it fits, else on a
## label; and last the 4x7 digits on a label. Digits are never drawn without paper under them.
##
## Its fill is paper in every state (the user's play test of 2026-11-03: "price bg shouldn't change
## when price increase instead number color should change"); the digits' ink says the pay
## (digit_color), in the classic strength ramp (the PR #138 review: "black for base, yellow/orange
## for semi strong and red for strong"): PRINTED, the base, in ink; BOOSTED by its strength against
## its base (BOOST_INKS, steps from boost_step): semi strong amber (mustard dark), then orange,
## below pay_ink_ratios[1] times the base, strong red from it, each on a darker shadow so it also
## reads by its weight; LOWERED and ZERO in grey (muted ink, the PR #138 round 2: a lowered pay is
## not a warning) with no shadow. On the yellow label the two semi strong steps print one shade
## darker (PriceLabel.BOOST_INKS), so each still reads there. COUPON shows the teal
## scissors (a coupon pays nothing itself), WASTED (a coupon that gave nothing) grey scissors
## under a tomato-dark slash. It never draws gold: GOLDEN is the ticket's ring (PriceSticker). Off
## a ticket (a drag's ghost carries its pay) it is `framed`, in an ink edge of its own.
##
## On the belt the row's PriceLabelLayer draws the label and the digits on it, over the next cell
## and the frames (set_label_cover): the window then draws neither itself, so the label shows
## once, and it tells the layer when it moves, hides or changes (a tween moves it after the
## layer's own frame), so the layer never trails it.
##
## Resting the pointer on it shows its tip (TipTarget: the printed price and the pay, set by its
## ticket), anywhere on its label too (hover_rect). Dimmed (an unrelated item while another is
## hovered) it fades to `dimmed_alpha` over the ticket's paper; with a label only its digits
## fade, on the label's paper (the belt, not paper, lies under the leak). Decor only: every
## number is a payout from the score.
##
## Beside a wide icon label (a gained family's third icon, 2026-11-05, TicketFace.WINDOW_WIDE) it
## is narrower (set_art_width): there "21€" and every three-digit price print on a label, within
## the cap.

enum State { PRINTED, BOOSTED, LOWERED, ZERO, COUPON, WASTED }

## The window's size (TicketFace.WINDOW at 2x).
const SIZE := Vector2(56, 22)
## The window in art px (SIZE at ART_SCALE).
const ART := Vector2i(28, 11)
## The digits' room (art px from the window's left): from DIGITS_LEFT to DIGITS_RIGHT (inclusive),
## rows down to DIGITS_FOOT, so the shadow, one art px down and right of them, stays inside the
## window (its last row and column). A price in the window fits it (PriceLabel.print_for); the
## digits sit centred in the window (digits_at), and a wasted coupon's slash spans the room.
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
var _base: int = 0
var _framed: bool = false
var _step: int = 0
var _label: PriceLabel
var _digits: PixelWords
var _shadow: PixelWords
var _dimmed: bool = false
var _tween: Tween
## The digits' (or scissors') alpha: 1, or the dimmed one (set_dimmed).
var _fade: float = 1.0
## Its width in art px (ART.x, or a narrower window's: set_art_width).
var _art_width: int = ART.x


## A window showing `amount` in `state` (against its item's `base`); `framed` off a ticket.
func _init(
	state: State = State.PRINTED, amount: int = 0, framed: bool = false, base: int = 0
) -> void:
	super()
	name = "PriceWindow"
	_framed = framed
	size = SIZE
	custom_minimum_size = SIZE
	# The label first: under the digits.
	_label = PriceLabel.new()
	_label.left_edge = framed
	add_child(_label)
	_shadow = PixelWords.new()
	_shadow.name = "Shadow"
	add_child(_shadow)
	_digits = PixelWords.new()
	_digits.name = "Digits"
	add_child(_digits)
	# A layer that draws its label follows its moves (_notification).
	set_notify_transform(true)
	show_pay(state, amount, base)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_TRANSFORM_CHANGED, NOTIFICATION_VISIBILITY_CHANGED:
			_tell_cover()


## Shows `amount` in `state` (a coupon's states show no digits); a boosted amount's ink steps up
## with it against `base`, its item's printed price (boost_step). A price too wide for the window
## goes on its label (PriceLabel.print_for).
func show_pay(state: State, amount: int, base: int = 0) -> void:
	_state = state
	_amount = amount
	_base = base
	_step = boost_step(amount, base) if state == State.BOOSTED else 0
	var coupon: bool = state == State.COUPON or state == State.WASTED
	var leak: int = 0
	_digits.visible = not coupon
	if not coupon:
		var form: Array = PriceLabel.print_for(amount, _art_width)
		leak = form[2]
		var art: Vector2i = PixelWords.font_size_of(form[0], form[1])
		var place: Vector2i = digits_at(art, _art_width)
		if leak > 0:
			place = Vector2i(PriceLabel.DIGITS_LEFT, place.y - PriceLabel.UP)
		var at: Vector2 = Vector2(place) * _px()
		for words: PixelWords in [_digits, _shadow]:
			words.sheet = form[1]
			words.text = form[0]
			words.cell = ArtStyle.ART_SCALE
			words.position = at
			words.size = Vector2(art) * _px()
		_shadow.position = at + Vector2(SHADOW_OFFSET) * _px()
	_label.show_leak(_art_width, leak)
	var shadow_ink: Color = shadow_color(state, _step, leak > 0)
	_shadow.visible = not coupon and shadow_ink.a > 0.0
	_digits.color = digit_color(state, _step, leak > 0)
	_shadow.color = shadow_ink
	_show_fade()
	queue_redraw()
	# A label that came, changed or went: the row's layer takes it, or lets it go, at once.
	_tell_cover()


## Narrows (or widens back) the window to `art_width` art px, its height kept, and lays its digits
## out again.
func set_art_width(art_width: int) -> void:
	_art_width = art_width
	# The minimum first: a size under the old minimum would not take.
	custom_minimum_size = Vector2(art_width, ART.y) * _px()
	size = custom_minimum_size
	show_pay(_state, _amount, _base)


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


## Its stuck label (PriceLabel), shown while the price is too wide for the window: its rect is
## everything the label draws, its leak() how far it passes the ticket's right edge.
func label() -> PriceLabel:
	return _label


## Hands the label's drawing to `cover` (a PriceLabelLayer, which draws it and its digits over
## the row; it is the tip's cover too, TipTarget.tip_cover), or takes it back (null).
func set_label_cover(cover: Control) -> void:
	tip_cover = cover
	_show_fade()


## Where its tip shows (TipTarget): the window, and its label's whole rect.
func hover_rect() -> Rect2:
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	if _label.visible:
		rect = rect.merge(Rect2(_label.position, _label.size))
	return get_global_transform() * rect


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


## A price's short forms by its size, for a readout with no label (MonitorPayout's fallback):
## [text, PixelWords.Sheet]: the 6x8 digits to 999€, the 4x7 ones to 9999€, then "12k€" in
## 6x8, and in 4x7 from 100k€. Each fits the full window's room (the window test checks it). The
## window itself prints by PriceLabel.print_for. Pure.
static func form_for(amount: int) -> Array:
	if amount <= 999:
		return [MonitorText.euros(amount), PixelWords.Sheet.DIGITS]
	if amount <= 9999:
		return [MonitorText.euros(amount), PixelWords.Sheet.SMALL_DIGITS]
	var short: String = THOUSANDS % floori(amount / 1000.0)
	if amount < 100000:
		return [short, PixelWords.Sheet.DIGITS]
	return [short, PixelWords.Sheet.SMALL_DIGITS]


## Where digits `art` art px in size sit (their top left, art px from the window's, `width` art px
## wide): centred in the window, on the art's grid (an odd room leaves the spare art px right of
## them and under them, where the shadow falls), and inside the digits' room. Pure.
static func digits_at(art: Vector2i, width: int = ART.x) -> Vector2i:
	var right: int = DIGITS_RIGHT - (ART.x - width)
	var at: Vector2i = Vector2i(floori((width - art.x) / 2.0), floori((ART.y - art.y) / 2.0))
	at.x = clampi(at.x, DIGITS_LEFT, maxi(right + 1 - art.x, DIGITS_LEFT))
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


## The digits' colour in `state` (a boosted pay's at its `step`, 1 to 3); `on_label`: on the
## yellow label (PriceLabel.BOOST_INKS).
static func digit_color(state: State, step: int = 1, on_label: bool = false) -> Color:
	var inks: Array[Array] = PriceLabel.BOOST_INKS if on_label else BOOST_INKS
	match state:
		State.BOOSTED:
			return inks[clampi(step, 1, inks.size()) - 1][0]
		State.LOWERED, State.ZERO:
			return NEGATIVE_INK
	return Palette.INK


## The digits' shadow in `state` (transparent: none), on the window's paper or `on_label`.
static func shadow_color(state: State, step: int = 1, on_label: bool = false) -> Color:
	if state != State.BOOSTED:
		return Color.TRANSPARENT
	var inks: Array[Array] = PriceLabel.BOOST_INKS if on_label else BOOST_INKS
	return inks[clampi(step, 1, inks.size()) - 1][1]


## Fades the window to `dimmed_alpha` (`dimmed`) or back to full, over `fade` seconds (0: at
## once). With a label only the digits fade (_show_fade).
func set_dimmed(dimmed: bool, fade: float = 0.0) -> void:
	_dimmed = dimmed
	var alpha: float = dimmed_alpha if dimmed else 1.0
	if _tween != null:
		_tween.kill()
		_tween = null
	if fade > 0.0 and is_inside_tree() and not is_equal_approx(_fade, alpha):
		_tween = create_tween()
		_tween.tween_method(_set_fade, _fade, alpha, fade)
	else:
		_set_fade(alpha)


func is_dimmed() -> bool:
	return _dimmed


func _set_fade(alpha: float) -> void:
	_fade = alpha
	_show_fade()


## Shows the fade: on the whole window (its digits or scissors fade to the ticket's paper under
## it), or with a label on the digits alone (the label keeps its paper). A label a layer draws
## (set_label_cover) and the digits on it are not drawn here.
func _show_fade() -> void:
	var on_label: bool = _label.visible
	modulate.a = 1.0 if on_label else _fade
	_digits.modulate.a = _fade if on_label else 1.0
	_shadow.modulate.a = _fade if on_label else 1.0
	var covered: bool = on_label and is_instance_valid(tip_cover)
	_label.covered = covered
	_digits.self_modulate.a = 0.0 if covered else 1.0
	_shadow.self_modulate.a = 0.0 if covered else 1.0


## Tells the layer that draws its label that it moved, hid or showed; with a label no layer
## draws yet (a shown or new one), every layer, for its row's to take it.
func _tell_cover() -> void:
	if not is_inside_tree():
		return
	var layer: PriceLabelLayer = tip_cover as PriceLabelLayer
	if is_instance_valid(layer) and layer.is_inside_tree():
		layer.refresh()
	elif _label != null and _label.visible:
		get_tree().call_group(PriceLabelLayer.GROUP, &"refresh")


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
