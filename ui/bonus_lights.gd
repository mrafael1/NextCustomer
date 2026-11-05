class_name BonusLights
extends Control
## The quota crossing's bonus lights (D, docs/art/mockups/quota_crossing.html, approved by the
## user on 2026-10-31): once the count meets the quota, the price rail's top strip (RailLight's
## band) lights in chasing gold for the rest of the count: everything past it is
## extra. The bulbs switch on from the scanner end outward over ON_SECONDS, then chase back toward
## the scanner and the register, one in CHASE_PERIOD lit, a step every CHASE_STEP_SECONDS. They
## fade out over FADE_SECONDS when the count ends (the printer feed or its end). Reduced motion
## shows every other bulb lit at once, with no chase. Real time (the ding's hit-stop does not
## freeze them). Stage coordinates (the layer covers the stage). Decor only.
## Over the quota light (on_fill, QuotaLight: the band full and gold once the quota is met; shift
## scene polish v2, section 1) they draw no dark base of their own: the gold band is the base, and
## the bulbs are paper when lit and mustard when not (FILL_LIT_COLOR, FILL_UNLIT_COLOR).

const RAIL_Y := RailLight.RAIL_Y
const RAIL_HEIGHT := RailLight.RAIL_HEIGHT
## The strip: the belt's price rail, inside its ends.
const LEFT := ShiftStage.BELT_RECT.position.x + 4.0
const WIDTH := ShiftStage.BELT_RECT.size.x - 8.0
const BULBS := 38
## The strip's top SHADE rows a darker gold under the lip (RailLight.SHADE), the bolts and chevrons
## drawn back over it. A bulb: BULB_SIZE px, on the strip's lower rows.
const SHADE := RailLight.SHADE
const BULB_SIZE := Vector2(10, 4)
const BASE_COLOR := Palette.MUSTARD_DARKEST
const LIT_COLOR := Palette.GOLD
const UNLIT_COLOR := Palette.MUSTARD_DARK
const FILL_LIT_COLOR := Palette.PAPER
const FILL_UNLIT_COLOR := Palette.MUSTARD
const ON_SECONDS := 0.5
const CHASE_STEP_SECONDS := 0.09
const CHASE_PERIOD := 4
const FADE_SECONDS := 0.3
const GRID := 2.0

## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()

## How far in (px) the belt's right end is (BeltPanel.cut, #122: a shorter belt's strip ends
## with it).
var belt_cut: float = 0.0:
	set(value):
		belt_cut = value
		queue_redraw()

## Returns true while the quota light's band under them is full and gold (QuotaLight.is_full):
## then no base, paper and mustard bulbs. None means their own base.
var on_fill: Callable = Callable()

## Seconds since the lights came on, -1 while off.
var _since: float = -1.0
## Seconds left of the fade out, -1 while not fading.
var _fade_left: float = -1.0


func _init() -> void:
	name = "BonusLights"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## The quota is met: the lights switch on.
func light() -> void:
	_since = 0.0
	_fade_left = -1.0
	set_process(true)
	queue_redraw()


## The count ends: the lights fade out (at once when off).
func fade() -> void:
	if _since < 0.0 or _fade_left >= 0.0:
		return
	_fade_left = FADE_SECONDS


## Off at once (a new count).
func clear() -> void:
	_since = -1.0
	_fade_left = -1.0
	set_process(false)
	queue_redraw()


func is_lit() -> bool:
	return _since >= 0.0


## Whether they draw over the quota light's full band now (on_fill).
func is_on_fill() -> bool:
	return on_fill.is_valid() and bool(on_fill.call())


## The bulbs drawn now (stage coordinates) and whether each is lit, for checks: [rect, lit].
func bulbs() -> Array[Array]:
	var shown: Array[Array] = []
	if _since < 0.0:
		return shown
	var reduced: bool = reduced_motion.is_valid() and bool(reduced_motion.call())
	var width: float = WIDTH - belt_cut
	var count: int = roundi(BULBS * width / WIDTH)
	var step: float = width / count
	var phase: int = 0 if reduced else floori(_since / CHASE_STEP_SECONDS)
	for index: int in range(count):
		if not reduced and float(index) / count > _since / ON_SECONDS:
			continue
		var lit: bool = (index % 2 == 0) if reduced else posmod(index + phase, CHASE_PERIOD) == 0
		var x: float = snappedf(LEFT + index * step + (step - BULB_SIZE.x) / 2.0, GRID)
		shown.append([Rect2(x, RAIL_Y + RAIL_HEIGHT - BULB_SIZE.y, BULB_SIZE.x, BULB_SIZE.y), lit])
	return shown


func _process(delta: float) -> void:
	# Godot turns processing on when the node is ready: off until light().
	if _since < 0.0:
		set_process(false)
		return
	_since += delta
	if _fade_left >= 0.0:
		_fade_left -= delta
		if _fade_left <= 0.0:
			clear()
			return
	queue_redraw()


func _draw() -> void:
	if _since < 0.0:
		return
	var alpha: float = 1.0 if _fade_left < 0.0 else _fade_left / FADE_SECONDS
	var reduced: bool = reduced_motion.is_valid() and bool(reduced_motion.call())
	var on: float = 1.0 if reduced else minf(1.0, _since / (ON_SECONDS * 0.8))
	var width: float = WIDTH - belt_cut
	var over_fill: bool = is_on_fill()
	if not over_fill:
		draw_rect(Rect2(LEFT, RAIL_Y, width, RAIL_HEIGHT), Color(BASE_COLOR, 0.9 * on * alpha))
		draw_rect(Rect2(LEFT, RAIL_Y, width, SHADE), Color(Palette.INK, 0.5 * on * alpha))
	var lit_color: Color = FILL_LIT_COLOR if over_fill else LIT_COLOR
	var unlit_color: Color = FILL_UNLIT_COLOR if over_fill else UNLIT_COLOR
	for bulb: Array in bulbs():
		draw_rect(bulb[0] as Rect2, Color(lit_color if bulb[1] else unlit_color, alpha))
	RailLight.draw_hardware(self, LEFT, LEFT + width, on * alpha)
