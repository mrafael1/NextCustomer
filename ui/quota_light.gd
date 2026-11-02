class_name QuotaLight
extends Control
## The conveyor's quota light (shift scene polish v2, section 1, the user's pick of 2026-11-02:
## fill only, no shine; docs/art/mockups/shift_scene_polish_v2.html): while the shift is counted,
## the belt's apron band (BeltPanel.APRON, the strip RailLight and BonusLights light) fills from
## the scanner end toward the belt's far end in proportion to the running total against the quota,
## so it reaches the far end exactly when the quota is met and stays full past it. It follows the
## register's reading (LedDisplay, follow), as the top bar's gauge does: the running total, never
## the final one early. Display arithmetic only (QuotaMeter.fill_fraction); it never scores.
##
## Its colours are the gauge's statuses: tomato while short, mustard from QuotaMeter.NEAR_SHARE of
## the quota, gold once full. A band of SHADE rows under the lip, a HIGHLIGHT row under them, then
## the body (as RailLight's light), the belt's bolts and chevrons drawn back over it; a paper head
## marks the front, and the far end's steel cap with its unlit mustard mark stands for the goal
## until the band is full. No flash, sweep or glow. The level eases to each reading (EASE_RATE, the
## gauge's); under reduced motion it jumps. It is dark in planning (the LED blank or projected):
## it clears when the next shift's planning starts. A shorter belt (belt_cut, #122) is filled to
## its own end. Stage coordinates (the layer covers the stage); in the fore under BonusLights (whose
## chase draws over it, on_fill) and RailLight (whose giver runs draw over it). Decor only.

const RAIL_Y := RailLight.RAIL_Y
const RAIL_HEIGHT := RailLight.RAIL_HEIGHT
const LEFT := RailLight.RAIL_LEFT
const WIDTH := BeltPanel.APRON.size.x
const SHADE := RailLight.SHADE
const HIGHLIGHT := RailLight.HIGHLIGHT
const HEAD_WIDTH := 4.0
## The far end's cap (CAP_WIDTH px of steel) and its unlit mark (CAP_MARK, inside it).
const CAP_WIDTH := 6.0
const CAP_MARK := Rect2(2, 2, 2, 4)
const GRID := 2.0
const NEAR_SHARE := QuotaMeter.NEAR_SHARE
const EASE_RATE := QuotaMeter.EASE_RATE
## The shown level snaps to the reading once this close (a fraction of the band).
const SNAP := 0.002
## The band's rows by status: [highlight, body, shade].
const SHORT_RAMP: Array[Color] = [Palette.TOMATO_PALE, Palette.TOMATO_LIGHT, Palette.TOMATO]
const NEAR_RAMP: Array[Color] = [Palette.MUSTARD_PALE, Palette.MUSTARD_LIGHT, Palette.MUSTARD]
const FULL_RAMP: Array[Color] = [Palette.MUSTARD_PALE, Palette.GOLD, Palette.MUSTARD]
const HEAD_COLOR := Palette.PAPER
const CAP_COLOR := Palette.STEEL_DARK
const CAP_MARK_COLOR := Palette.MUSTARD_DARK

## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()

## How far in (px) the belt's right end is (BeltPanel.cut, #122): the band ends with it.
var belt_cut: float = 0.0:
	set(value):
		belt_cut = value
		queue_redraw()

var _led: LedDisplay
## Lit (counting) or dark (planning).
var _on: bool = false
## The reading's level and the level drawn, as fractions of the band.
var _target: float = 0.0
var _shown: float = 0.0


func _init() -> void:
	name = "QuotaLight"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process(false)


## Follows `led`'s counting readings; dark while it is blank or shows the projection.
func follow(led: LedDisplay) -> void:
	_led = led
	led.reading_changed.connect(_on_reading)
	led.mode_changed.connect(_on_mode)


## Dark at once.
func clear() -> void:
	_on = false
	_target = 0.0
	_shown = 0.0
	set_process(false)
	queue_redraw()


func is_lit() -> bool:
	return _on


## The level drawn and the reading's, as fractions of the band (0 to 1).
func fill() -> float:
	return _shown if _on else 0.0


func target_fill() -> float:
	return _target if _on else 0.0


## Whether the band is full (the quota met) and drawn gold.
func is_full() -> bool:
	return _on and _shown >= 1.0


## The band's full length on this belt and its lit part, in stage coordinates.
func band_rect() -> Rect2:
	return Rect2(LEFT, RAIL_Y, WIDTH - belt_cut, RAIL_HEIGHT)


func lit_rect() -> Rect2:
	var band: Rect2 = band_rect()
	band.size.x = _lit_width()
	return band


## The rows' colours drawn now ([highlight, body, shade]).
func ramp() -> Array[Color]:
	if _shown >= 1.0:
		return FULL_RAMP
	return NEAR_RAMP if _shown >= NEAR_SHARE else SHORT_RAMP


func _on_reading(amount: int, quota: int, _met: bool) -> void:
	if _led == null or not _led.is_counting():
		return
	var level: float = QuotaMeter.fill_fraction(amount, quota)
	if not _on or level < _shown or _reduced():
		_shown = level
	_on = true
	_target = level
	set_process(not is_equal_approx(_shown, _target))
	queue_redraw()


func _on_mode(mode: LedDisplay.Mode) -> void:
	if mode == LedDisplay.Mode.BLANK or mode == LedDisplay.Mode.PROJECTED:
		clear()


func _process(delta: float) -> void:
	# Godot turns processing on when the node is ready: off until a reading eases.
	if not _on or _reduced() or absf(_target - _shown) <= SNAP:
		_shown = _target
		set_process(false)
	else:
		_shown = lerpf(_shown, _target, 1.0 - exp(-EASE_RATE * delta))
	queue_redraw()


func _draw() -> void:
	if not _on:
		return
	var band: Rect2 = band_rect()
	var full: bool = _shown >= 1.0
	if not full:
		var cap := Rect2(band.end.x - CAP_WIDTH, RAIL_Y, CAP_WIDTH, RAIL_HEIGHT)
		draw_rect(cap, CAP_COLOR)
		draw_rect(Rect2(cap.position + CAP_MARK.position, CAP_MARK.size), CAP_MARK_COLOR)
	var width: float = _lit_width()
	if width <= 0.0:
		return
	var rows: Array[Color] = ramp()
	draw_rect(Rect2(LEFT, RAIL_Y, width, RAIL_HEIGHT), rows[1])
	draw_rect(Rect2(LEFT, RAIL_Y, width, SHADE), rows[2])
	draw_rect(Rect2(LEFT, RAIL_Y + SHADE, width, HIGHLIGHT), rows[0])
	RailLight.draw_hardware(self, LEFT, LEFT + width, 1.0)
	if not full:
		var head_x: float = LEFT + maxf(0.0, width - HEAD_WIDTH)
		draw_rect(Rect2(head_x, RAIL_Y, minf(HEAD_WIDTH, width), RAIL_HEIGHT), HEAD_COLOR)


## The lit width on the art grid: the whole band once full.
func _lit_width() -> float:
	if not _on:
		return 0.0
	var length: float = WIDTH - belt_cut
	if _shown >= 1.0:
		return length
	return minf(length, snappedf(length * _shown, GRID))


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
