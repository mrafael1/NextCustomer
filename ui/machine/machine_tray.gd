class_name MachineTray
extends Control
## The machine's prize tray (v0.50, mock-up premium_machine_v1.html; R1 "drop"): a short steel
## slot under the keys (gold once a PREMIUM visit turns PREMIUM, MachineLook) with a dark mouth, a
## light strip, the PUSH flap and "TAKE YOUR PRIZE". While the draw packs (view.plan's draw ..
## draw_end) the strip and the mouth flicker and the flap rattles; the light runs grey, then teal,
## then gold, up to the best rarity drawn (a hint, never the prize: COMMON stays grey). Once the
## tickets are out it glows softly in that colour until the pick. The prize tickets fly out of it
## (PrizeTicket). Under reduced motion it neither flickers nor rattles.
##
## THE PUSH BAR CONFIRMS (v0.53, decided with the user on 2026-10-23: "confirm button should be
## on the push on the bottom instead of changing the top row"): at the chute wait a pressed key
## offers its chute here (offer_confirm): the flap lights up gold as "PUSH TO CONFIRM", its
## chevrons chase towards the middle, the mouth's light strip and a ring round the tray pulse (on
## view.idle_time), and the line under it reads what the chute gives. The whole tray is the
## button (a pointing hand); hovering it lifts the light. A click (or press_confirm) pushes the
## flap in for MachineTuning.confirm_down_ms with `ui_confirm`, then sends confirm_pressed. The
## display above keeps its own lines.

## The push bar was pressed (after its down state): the pressed key's chute is confirmed.
signal confirm_pressed

const SIZE := Vector2(408, 92)
const MOUTH_RECT := Rect2(16, 12, 376, 52)
const STRIP_RECT := Rect2(18, 14, 372, 4)
const GLOW_RECT := Rect2(18, 18, 372, 44)
const FLAP_RECT := Rect2(24, 20, 360, 24)
const PUSH_MIDDLE := Vector2(204, 32)
const TAKE_MIDDLE := Vector2(204, 78)
const PUSH_TEXT := "PUSH"
const TAKE_TEXT := "TAKE YOUR PRIZE"
## The offered push bar's word on the flap, with the chute's name.
const CONFIRM_TEXT := "PUSH TO CONFIRM · %s"
const PUSH_SIZE := 12
const CONFIRM_SIZE := 14
const TAKE_SIZE := 11
## The offered bar: how far the flap goes in when pushed, its chevrons (CHEVRON_STEP px apart,
## chasing at CHEVRON_RATE steps a second), the pulse of its light and of its ring.
const PUSH_DEPTH := 4.0
const CHEVRONS := 3
const CHEVRON_STEP := 10.0
const CHEVRON_GAP := 10.0
const CHEVRON_RATE := 6.0
const PULSE_RATE := 5.0
const OFFER_GLOW := 0.7
const HOVER_GLOW := 1.0
const RING_GAP := 2.0
const RING_OUTER_ALPHA := 0.4
const BOLD_WEIGHT := 800
const GLOW_ALPHA := 0.22
const REST_GLOW := 0.4
## The packing's flicker and rattle (per second) and the rattle's reach (px).
const FLICKER_RATE := 40.0
const RATTLE_RATE := 60.0
const RATTLE := 2.0
const RARITY_LIGHT: Array[Color] = [Palette.GREY_LIGHT, Palette.TEAL_BRIGHT, Palette.GOLD]

## The machine this part belongs to (setup(), build spec 4.2).
var view: RewardMachineView
var _gold: bool = false
var _glow: float = 0.0
var _light: Color = Palette.GREY_LIGHT
var _rattle: float = 0.0
## The offered confirm (offer_confirm): the chute's name and what it gives (empty: none).
var _offer: PackedStringArray = PackedStringArray()
## The push's down state: when it was pressed (Time ticks, ms; -1: not down).
var _down_at_ms: int = -1
var _hover: bool = false
## The offered bar's pulse now (0 .. 1) and its chevrons' chase step.
var _pulse: float = 0.0
var _chase: int = 0


func _init() -> void:
	name = "MachineTray"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void: _set_hover(true))
	mouse_exited.connect(func() -> void: _set_hover(false))


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## How bright the tray's light is (0 off .. 1) and its colour now.
func light() -> Array:
	return [_glow, _light]


func is_gold() -> bool:
	return _gold


## Offers the pressed key's chute (`chute_name`) on the push bar, `sub` under it (what it gives):
## the bar lights and takes clicks. clear_confirm() takes it back.
func offer_confirm(chute_name: String, sub: String) -> void:
	_offer = PackedStringArray([chute_name, sub])
	_down_at_ms = -1
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


## Takes the offer back: the bar is the plain PUSH flap again and takes no click.
func clear_confirm() -> void:
	_offer = PackedStringArray()
	_down_at_ms = -1
	_hover = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	queue_redraw()


## Whether the push bar offers a chute now.
func confirm_offered() -> bool:
	return not _offer.is_empty()


## The bar's two lines now: on the flap and under it.
func texts() -> PackedStringArray:
	if _offer.is_empty():
		return PackedStringArray([PUSH_TEXT, TAKE_TEXT])
	return PackedStringArray([CONFIRM_TEXT % _offer[0], _offer[1].to_upper()])


## Whether the push is in its down state (pushed, before confirm_pressed).
func confirm_down() -> bool:
	return _down_at_ms >= 0


## The flap's rect now (tray coordinates): pushed in while down.
func flap_rect() -> Rect2:
	var depth: float = PUSH_DEPTH if confirm_down() else 0.0
	return Rect2(FLAP_RECT.position + Vector2(_rattle, depth), FLAP_RECT.size)


## Pushes the bar (a click on it, or a test): down for confirm_down_ms with `ui_confirm`, then
## confirm_pressed. Nothing when no chute is offered or it is already down.
func press_confirm() -> void:
	if _offer.is_empty() or _down_at_ms >= 0:
		return
	_down_at_ms = Time.get_ticks_msec()
	Sfx.play_at(self, "ui_confirm")
	queue_redraw()
	_end_down()


func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		press_confirm()


func _set_hover(hovered: bool) -> void:
	_hover = hovered and not _offer.is_empty()
	queue_redraw()


## The down state ends after confirm_down_ms: confirm_pressed.
func _end_down() -> void:
	if _down_at_ms < 0 or Time.get_ticks_msec() - _down_at_ms < _down_ms():
		return
	_down_at_ms = -1
	confirm_pressed.emit()


func _down_ms() -> int:
	return view.tuning.confirm_down_ms if view != null and view.tuning != null else 0


## The tray's colour on a time `t` of view.plan: packing, then the soft glow until the pick.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	_gold = MachineLook.at(plan, t).tray_gold()
	_glow = 0.0
	_rattle = 0.0
	_end_down()
	_pulse = 0.0
	_chase = 0
	if not _offer.is_empty():
		var idle: float = view.idle_time if view != null else 0.0
		_pulse = 0.5 + 0.5 * sin(idle * PULSE_RATE)
		_chase = int(floorf(idle * CHEVRON_RATE))
		_light = Palette.MUSTARD_PALE
		_glow = HOVER_GLOW if _hover or confirm_down() else OFFER_GLOW + 0.3 * _pulse
	if plan != null and plan.has_draw and plan.n_prizes > 0 and t >= plan.draw:
		var best: int = 0
		for rarity: int in plan.rarities:
			best = maxi(best, rarity)
		var picked: bool = plan.has_landing and t >= plan.press
		if t < plan.draw_end:
			var p: float = MachineArt.seg(t, plan.draw, plan.draw_end)
			_light = RARITY_LIGHT[mini(best, int(floorf(p * 3.0)))]
			_glow = REST_GLOW
			if not plan.reduced_motion:
				_glow = 0.6 + 0.4 * sin(t * FLICKER_RATE)
				_rattle = MachineArt.snap(sin(t * RATTLE_RATE) * RATTLE)
		elif not picked:
			_light = RARITY_LIGHT[best]
			_glow = REST_GLOW
	queue_redraw()


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, SIZE)
	var ink: Color = Palette.BRASS_DARKEST if _gold else Palette.INK
	if _gold:
		MachineArt.bevel(
			self, rect, Palette.MUSTARD_LIGHT, Palette.MUSTARD_PALE, Palette.BRASS, ink
		)
	else:
		MachineArt.bevel(
			self, rect, Palette.STEEL, Palette.STEEL_HIGHLIGHT, Palette.STEEL_DARK, ink
		)
	MachineArt.box(self, MOUTH_RECT, Palette.CHARCOAL, Palette.INK)
	draw_rect(STRIP_RECT, _light if _glow > 0.0 else Palette.STEEL_DARKEST)
	if _glow > 0.0:
		draw_rect(GLOW_RECT, Color(_light, GLOW_ALPHA * _glow))
	if not _offer.is_empty():
		_draw_offer(ink)
		return
	var flap: Rect2 = flap_rect()
	if _gold:
		MachineArt.bevel(self, flap, Palette.GOLD, Palette.MUSTARD_PALE, Palette.BRASS, ink)
	else:
		MachineArt.bevel(self, flap, Palette.CREAM, Palette.PAPER, Palette.CREAM_SHADE, ink)
	var font: Font = ArtStyle.bold_font(BOLD_WEIGHT)
	MachineArt.centred_text(
		self,
		PUSH_TEXT,
		PUSH_MIDDLE + Vector2(_rattle, 0),
		font,
		PUSH_SIZE,
		Palette.BRASS_DARKEST if _gold else Palette.MUSTARD_DARKEST
	)
	MachineArt.centred_text(self, TAKE_TEXT, TAKE_MIDDLE, font, TAKE_SIZE, ink)


## The offered push bar: a ring round the tray, the flap lit gold (pushed in while down) with
## chasing chevrons each side of PUSH TO CONFIRM, and what the chute gives under it.
func _draw_offer(ink: Color) -> void:
	var lit: float = HOVER_GLOW if _hover or confirm_down() else OFFER_GLOW + 0.3 * _pulse
	var ring: Rect2 = Rect2(Vector2.ZERO, SIZE).grow(RING_GAP + MachineArt.PIXEL)
	MachineArt.ring(self, ring, Color(Palette.GOLD, lit))
	MachineArt.ring(self, ring.grow(MachineArt.PIXEL), Color(Palette.GOLD, lit * RING_OUTER_ALPHA))
	var flap: Rect2 = flap_rect()
	var face: Color = Palette.MUSTARD_PALE if _hover and not confirm_down() else Palette.GOLD
	var lo: Color = Palette.BRASS_DARK if confirm_down() else Palette.BRASS
	MachineArt.bevel(self, flap, face, Palette.MUSTARD_PALE, lo, Palette.BRASS_DARKEST)
	var font: Font = ArtStyle.bold_font(BOLD_WEIGHT)
	var lines: PackedStringArray = texts()
	var middle: Vector2 = flap.get_center()
	var size_now: int = _fit_size(lines[0], font, flap.size.x - 2.0 * _chevron_room())
	MachineArt.centred_text(self, lines[0], middle, font, size_now, Palette.BRASS_DARKEST)
	var half: float = MachineArt.text_width(lines[0], font, size_now) / 2.0
	var p: float = MachineArt.PIXEL
	for side: int in [-1, 1]:
		for k: int in range(CHEVRONS):
			# The chevrons chase inwards, the farthest first, towards the words.
			var lit_step: bool = (CHEVRONS - 1 - k + _chase) % CHEVRONS == 0
			var reach: float = half + CHEVRON_GAP + k * CHEVRON_STEP
			var x0: float = middle.x + reach if side > 0 else middle.x - reach - 3.0 * p
			var at: Vector2 = Vector2(MachineArt.snap(x0), MachineArt.snap(middle.y) - 3.0 * p)
			_draw_chevron(at, -side, lit_step)
	MachineArt.centred_text(
		self, lines[1], TAKE_MIDDLE, font, _fit_size(lines[1], font, SIZE.x - 16.0, TAKE_SIZE), ink
	)


## A chevron pointing `towards` (+1 right, -1 left) in the 3x5 art px box whose top left is `at`.
func _draw_chevron(at: Vector2, towards: int, lit_step: bool) -> void:
	var p: float = MachineArt.PIXEL
	var colour: Color = Palette.BRASS_DARKEST if lit_step else Color(Palette.BRASS_DARKEST, 0.35)
	for row: int in range(5):
		var reach: int = 2 - absi(row - 2)
		var column: int = reach if towards > 0 else 2 - reach
		draw_rect(Rect2(at.x + column * p, at.y + row * p, p, p), colour)


## The room the chevrons take each side of the flap's words.
func _chevron_room() -> float:
	return CHEVRON_GAP + CHEVRONS * CHEVRON_STEP


## The largest size from `largest` down to 9 at which `text` fits `room`.
func _fit_size(text: String, font: Font, room: float, largest: int = CONFIRM_SIZE) -> int:
	var font_size: int = largest
	while font_size > 9 and MachineArt.text_width(text, font, font_size) > room:
		font_size -= 1
	return font_size
