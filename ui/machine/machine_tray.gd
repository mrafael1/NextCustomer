class_name MachineTray
extends Control
## The machine's prize tray (v0.50, mock-up premium_machine_v1.html; R1 "drop"): a short steel
## slot under the keys (gold once a BOOSTED visit turns PREMIUM, MachineLook) with a dark mouth, a
## light strip, the PUSH flap and "TAKE YOUR PRIZE". While the draw packs (view.plan's draw ..
## draw_end) the strip and the mouth flicker and the flap rattles; the light runs grey, then teal,
## then gold, up to the best rarity drawn (a hint, never the prize: COMMON stays grey). Once the
## tickets are out it glows softly in that colour until the pick. The prize tickets fly out of it
## (PrizeTicket). Under reduced motion it neither flickers nor rattles.

const SIZE := Vector2(408, 92)
const MOUTH_RECT := Rect2(16, 12, 376, 52)
const STRIP_RECT := Rect2(18, 14, 372, 4)
const GLOW_RECT := Rect2(18, 18, 372, 44)
const FLAP_RECT := Rect2(24, 20, 360, 24)
const PUSH_MIDDLE := Vector2(204, 32)
const TAKE_MIDDLE := Vector2(204, 78)
const PUSH_TEXT := "PUSH"
const TAKE_TEXT := "TAKE YOUR PRIZE"
const PUSH_SIZE := 12
const TAKE_SIZE := 11
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


func _init() -> void:
	name = "MachineTray"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Hooks this part to the machine: RewardMachineView calls it once, when it builds the part
## (build spec 4.2).
func setup(machine: RewardMachineView) -> void:
	view = machine


## How bright the tray's light is (0 off .. 1) and its colour now.
func light() -> Array:
	return [_glow, _light]


func is_gold() -> bool:
	return _gold


## The tray's colour on a time `t` of view.plan: packing, then the soft glow until the pick.
func frame(t: float) -> void:
	var plan: MachinePlan = view.plan if view != null else null
	_gold = MachineLook.at(plan, t).tray_gold()
	_glow = 0.0
	_rattle = 0.0
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
	var flap: Rect2 = Rect2(FLAP_RECT.position + Vector2(_rattle, 0), FLAP_RECT.size)
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
