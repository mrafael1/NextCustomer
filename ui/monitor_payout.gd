class_name MonitorPayout
extends Control
## The item column's payout (PR #138 monitor, mock-up monitor_codex.png): the zone under the
## column's separator, the same size and place for every item so it never moves, holding only the
## result, right-aligned: "=" in bold ink, then the payout in the 6x8 pixel digits at CELL px a
## font px (PixelWords DIGITS), in the ticket's payout ink for its state (PriceWindow.digit_color,
## its boost step against the base, on a one-cell PriceWindow.shadow_color shadow). A price too
## wide for the zone falls back to PriceWindow.form_for's shorter forms. A 0€ payout shows its
## reason's sign left of "=" (the fizzle icon for an unused effect, the warning sign for a denial,
## as the ticket's 0€ tag). A coupon pays nothing itself: one whose "gives" rows added to other
## items shows what it `given` (PR #138 round 7, a friend's suggestion the user passed on): "+72€",
## its "+" where the "=" sits (GIVEN_SIGN, GIVEN_GAP from the digits) and its digits in the
## coupon's ink (GIVEN_INK), unshadowed; one that adds nothing shown (COUPON with nothing given,
## or WASTED) leaves its zone empty (v1.00, the user's play test of 2026-11-05: the scissors
## window there read as a weird empty box), its rows saying what it did.
## Display only: the amount and its state are the caller's (the score's).

const CELL := 3.0
const EQUALS := "="
const EQUALS_SIZE := 24
const EQUALS_WEIGHT := 800
const EQUALS_GAP := 6.0
const GLYPH_GAP := 6.0
const GIVEN_SIGN := "+"
const GIVEN_GAP := 2.0
const GIVEN_INK := Palette.TEAL_DARK
const FIZZLE_ICON := preload("res://art/icons/fizzle.png")
const WARNING_ICON := preload("res://art/icons/warning.png")

var _state: PriceWindow.State = PriceWindow.State.PRINTED
var _amount: int = 0
var _step: int = 0
var _given: int = 0
## Every part sits in this group, which a punch scales from its right edge.
var _group: Control
var _equals: Label
var _digits: PixelWords
var _shadow: PixelWords
var _glyph: TextureRect


func _init(zone: Vector2 = Vector2(258, 27)) -> void:
	name = "Payout"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = zone
	_group = Control.new()
	_group.name = "Group"
	_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_group.size = zone
	_group.pivot_offset = Vector2(zone.x, zone.y / 2.0)
	add_child(_group)
	_equals = MonitorKit.bold(EQUALS, EQUALS_SIZE, EQUALS_WEIGHT, Palette.INK, zone.y)
	_equals.name = "Equals"
	_group.add_child(_equals)
	_shadow = PixelWords.new("", PixelWords.Sheet.DIGITS, CELL)
	_shadow.name = "Shadow"
	_group.add_child(_shadow)
	_digits = PixelWords.new("", PixelWords.Sheet.DIGITS, CELL)
	_digits.name = "Digits"
	_group.add_child(_digits)
	_glyph = UiKit.sprite(null)
	_glyph.name = "Glyph"
	_group.add_child(_glyph)


## Shows `amount` in `state` (against its item's `base`: a boost's ink step), with `glyph` (the
## reason's sign) left of a 0€; a COUPON that `given` more than 0 to other items shows "+given€",
## and any other coupon (COUPON or WASTED) shows nothing.
func show_pay(
	state: PriceWindow.State,
	amount: int,
	base: int,
	glyph: PlanningModel.Glyph = PlanningModel.Glyph.NONE,
	given: int = 0
) -> void:
	_state = state
	_amount = amount
	_step = PriceWindow.boost_step(amount, base) if state == PriceWindow.State.BOOSTED else 0
	_given = given if state == PriceWindow.State.COUPON and given > 0 else 0
	var coupon: bool = (
		(state == PriceWindow.State.COUPON or state == PriceWindow.State.WASTED) and _given == 0
	)
	_digits.visible = not coupon
	_equals.visible = not coupon
	_shadow.visible = false
	_glyph.visible = false
	if coupon:
		return
	var right: float = size.x
	var form: Array = _form(_given if _given > 0 else amount)
	var text: String = form[0]
	var sheet: PixelWords.Sheet = form[1]
	var shown: Vector2 = PixelWords.text_size(text, sheet, CELL)
	var shadow_ink: Color = PriceWindow.shadow_color(state, _step)
	# The digits' foot over the shadow's cell, both inside the zone.
	var at: Vector2 = Vector2(right - shown.x - CELL, floorf((size.y - shown.y - CELL) / 2.0))
	for words: PixelWords in [_digits, _shadow]:
		words.sheet = sheet
		words.text = text
		words.size = shown
		words.position = at
	_digits.color = GIVEN_INK if _given > 0 else PriceWindow.digit_color(state, maxi(_step, 1))
	_shadow.color = shadow_ink
	_shadow.position = at + Vector2(CELL, CELL)
	_shadow.visible = shadow_ink.a > 0.0 and _given == 0
	_equals.text = GIVEN_SIGN if _given > 0 else EQUALS
	_equals.add_theme_color_override("font_color", GIVEN_INK if _given > 0 else Palette.INK)
	var equals_width: float = ceilf(_equals.get_combined_minimum_size().x)
	_equals.size = Vector2(equals_width, shown.y)
	var gap: float = GIVEN_GAP if _given > 0 else EQUALS_GAP
	_equals.position = Vector2(at.x - gap - equals_width, at.y)
	var left: float = _equals.position.x
	var texture: Texture2D = null
	if glyph == PlanningModel.Glyph.FIZZLE:
		texture = FIZZLE_ICON
	elif glyph == PlanningModel.Glyph.WARNING:
		texture = WARNING_ICON
	_glyph.texture = texture
	_glyph.visible = texture != null
	if texture != null:
		_glyph.size = Vector2(texture.get_size()) * ArtStyle.ART_SCALE
		_glyph.position = Vector2(
			left - GLYPH_GAP - _glyph.size.x, roundf((size.y - _glyph.size.y) / 2.0)
		)


## The payout's state (the ticket's price window's, PriceWindow.state_for) for `value` against
## `base`; `fizzled`: an effect of it went unused; a `coupon`'s scissors. Pure.
static func state_of(value: int, base: int, fizzled: bool, coupon: bool) -> PriceWindow.State:
	var pay: PlanningModel.Pay = PlanningModel.Pay.PLAIN
	if value <= 0 and (base > 0 or (coupon and fizzled)):
		pay = PlanningModel.Pay.ZERO
	elif value > base:
		pay = PlanningModel.Pay.BOOSTED
	elif value < base:
		pay = PlanningModel.Pay.LOWERED
	return PriceWindow.state_for(pay, coupon)


## The text and sheet `amount` prints in: the 6x8 digits when they fit the zone, else the 4x7
## ones, else PriceWindow.form_for's shorter forms.
func _form(amount: int) -> Array:
	var text: String = MonitorText.euros(amount)
	var room: float = size.x - needed_width(0, false) + digits_width(0)
	for sheet: PixelWords.Sheet in [PixelWords.Sheet.DIGITS, PixelWords.Sheet.SMALL_DIGITS]:
		if PixelWords.text_size(text, sheet, CELL).x <= room:
			return [text, sheet]
	return PriceWindow.form_for(amount)


## The 6x8 digits' width for `amount` (with their shadow's cell).
static func digits_width(amount: int) -> float:
	return PixelWords.text_size(MonitorText.euros(amount), PixelWords.Sheet.DIGITS, CELL).x + CELL


## The width "= N€" takes at the 6x8 digits for `amount`, with the zero's sign when `glyph`.
static func needed_width(amount: int, glyph: bool) -> float:
	var font: Font = ArtStyle.bold_font(EQUALS_WEIGHT)
	var sign_width: float = ceilf(
		font.get_string_size(EQUALS, HORIZONTAL_ALIGNMENT_LEFT, -1, EQUALS_SIZE).x
	)
	var width: float = digits_width(amount) + EQUALS_GAP + sign_width
	if glyph:
		width += GLYPH_GAP + WARNING_ICON.get_width() * ArtStyle.ART_SCALE
	return width


func pay_state() -> PriceWindow.State:
	return _state


func pay_amount() -> int:
	return _amount


## What a coupon's "gives" rows added that the zone shows ("+N€"), or 0.
func given_amount() -> int:
	return _given


## The boost step of a boosted payout (0 in any other state).
func boost_level() -> int:
	return _step


## The parts, for checks and the count's punch.
func group() -> Control:
	return _group


func digit_words() -> PixelWords:
	return _digits


func shadow() -> PixelWords:
	return _shadow


func equals() -> Label:
	return _equals


func zero_glyph() -> TextureRect:
	return _glyph


## Whether the zone shows anything: false for a coupon that adds nothing shown (see show_pay).
func shows_pay() -> bool:
	return _digits.visible


## What shows the payout (global, at rest): the digits; with nothing shown, the zone's right
## edge (an empty rect at its middle height).
func shown_rect() -> Rect2:
	var transform: Transform2D = get_global_transform()
	if not shows_pay():
		return Rect2(transform * Vector2(size.x, size.y / 2.0), Vector2.ZERO)
	return Rect2(transform * (_group.position + _digits.position), _digits.size)


## Every part shown (global, at rest), for layout checks.
func part_rects() -> Dictionary[String, Rect2]:
	var rects: Dictionary[String, Rect2] = {}
	var transform: Transform2D = get_global_transform()
	for part: Control in [_equals, _digits, _shadow, _glyph]:
		if part.visible:
			rects[String(part.name)] = Rect2(transform * part.position, part.size)
	return rects
