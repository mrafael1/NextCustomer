class_name MonitorClimax
extends Control
## SPEND MET's climax on the monitor (#105 piece 2, mock-up readability_v3.html, #86's WIN B
## kept): when the count's total first meets the quota it takes the whole paper for about a second
## (CountTotalTuning's Climax group): the paper, a big gold sunburst turning behind (110 x 70 art
## pixels at 4x), a fountain of climax_coins coins erupting from under the number, the number
## itself ("N€", climax_number_size px, following the reading as it ticks on) growing from
## climax_from past climax_over and settling, the shine over it, the SPEND MET stamp from
## climax_stamp_at and the "+N€" tab from climax_tab_at; from climax_hold_s it shrinks over
## climax_out_s toward the checkout column's number (`target`) while the paper fades, and goes.
##
## It runs in real time sped up only by a tap or a hold (`speed`, CountUp.press_speed), never held
## by the count's hit-stops. Under reduced motion it cuts in and out with nothing moving: the
## paper, the still sunburst, the number at its size, the stamp and the tab for climax_hold_s, no
## coins, no shine, no grow or shrink. Decor only: every number is the reading's.

const PAPER_SIZE := Vector2(402, 154)
const CENTRE := Vector2(201, 77)
const NUMBER_TOP := 22.0
const SUN_ART := Vector2(110, 70)
const SUN_PIXEL := 4.0
const SUN_AT := Vector2(-19, -63)
const STAMP_AT := Vector2(106, 106)
const STAMP_WIDTH := 158.0
const STAMP_SIZE := 22
const STAMP_TILT := -5.0
const TAB_AT := Vector2(272, 110)
const TAB_SIZE := 18
const TAB_LINE := 24.0
const TAB_PADDING := 6.0
## The coins: from COIN_FROM (paper coordinates), each COIN_DELAY_S after the one before in a wave
## of COIN_WAVE, out at ((37 i mod 13) - 6) x COIN_SPREAD px/s, up at COIN_RISE + (53 i mod
## COIN_RISE_SPREAD) px/s, falling at COIN_GRAVITY px/s² (the mock-up's 620 q²), for COIN_LIFE_S.
const COIN := preload("res://art/icons/coin.png")
const COIN_SIZE := Vector2(24, 24)
const COIN_FROM := Vector2(201, 160)
const COIN_START_S := 0.08
const COIN_DELAY_S := 0.035
const COIN_WAVE := 7
const COIN_SPREAD := 34.0
const COIN_RISE := 330.0
const COIN_RISE_SPREAD := 120
const COIN_GRAVITY := 1240.0
const COIN_LIFE_S := 0.95
const COIN_FLIP := 18.0

## Returns how much faster than real time the climax runs now (CountUp.press_speed); none: 1.
var speed: Callable = Callable()
## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()

var _tuning: CountTotalTuning
var _back: Control
var _sun: PixelSunburst
var _coins: Control
var _front: Control
var _number: TotalNumber
var _stamp: Label
var _tab: Label
var _q: float = -1.0
var _target: Vector2 = CENTRE
var _quota: int = 0
## This climax cuts in and out with nothing moving (reduced motion when it started).
var _still: bool = false


func _init(tuning: CountTotalTuning = null) -> void:
	name = "Climax"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = PAPER_SIZE
	clip_contents = true
	_tuning = tuning if tuning != null else load(CountUpPlan.TOTAL_TUNING_PATH) as CountTotalTuning
	_back = Control.new()
	_back.name = "Back"
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back.size = PAPER_SIZE
	add_child(_back)
	var paper: ColorRect = ColorRect.new()
	paper.name = "Paper"
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paper.color = Palette.PAPER
	paper.size = PAPER_SIZE
	_back.add_child(paper)
	_sun = PixelSunburst.new(SUN_ART, SUN_PIXEL)
	_sun.position = SUN_AT
	_back.add_child(_sun)
	_coins = Control.new()
	_coins.name = "Coins"
	_coins.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coins.size = PAPER_SIZE
	_coins.draw.connect(_draw_coins)
	_back.add_child(_coins)
	_front = Control.new()
	_front.name = "Front"
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.size = PAPER_SIZE
	_front.pivot_offset = CENTRE
	add_child(_front)
	_number = TotalNumber.new(_tuning)
	_number.configure(_tuning.climax_number_size, roundf(_tuning.climax_number_size * 0.8))
	_number.centre_x = CENTRE.x
	_number.top = NUMBER_TOP
	_front.add_child(_number)
	_stamp = MonitorKit.stamp(STAMP_WIDTH, STAMP_SIZE, STAMP_TILT)
	_stamp.position = STAMP_AT
	_front.add_child(_stamp)
	_tab = MonitorKit.gold_box("", TAB_SIZE, TAB_LINE, TAB_PADDING)
	_tab.name = "OverTab"
	_tab.position = TAB_AT
	_front.add_child(_tab)
	visible = false


func _process(delta: float) -> void:
	if _q < 0.0:
		return
	var rate: float = 1.0
	if speed.is_valid():
		rate = maxf(1.0, float(speed.call()))
	_q += delta * rate
	_pose()


## The total `amount` met `quota` (the count's ding): the climax starts, shrinking at its end
## toward `target` (the column number's middle, global); still under reduced motion.
func start(amount: int, quota: int, target: Vector2) -> void:
	if not is_inside_tree():
		stop()
		return
	_still = _reduced()
	_quota = quota
	_target = get_global_transform().affine_inverse() * target
	_number.set_value(amount, false)
	_set_tab(amount)
	_q = 0.0
	visible = true
	_pose()


## The reading moves on during the climax: the number and the tab follow it.
func set_reading(amount: int) -> void:
	if _q < 0.0:
		return
	_number.set_value(amount, not _still)
	_set_tab(amount)


## The climax goes at once (a new count, the end state).
func stop() -> void:
	_q = -1.0
	visible = false


func is_running() -> bool:
	return _q >= 0.0


## Its parts, for checks: the number, the stamp, the tab and the sunburst, and how far in it is.
func number() -> TotalNumber:
	return _number


func stamp() -> Label:
	return _stamp


func tab() -> Label:
	return _tab


func sunburst() -> PixelSunburst:
	return _sun


func progress() -> float:
	return _q


## Whether this climax is the reduced-motion one, nothing moving.
func is_still() -> bool:
	return _still


## The climax at _q seconds in (see the class comment and the mock-up's monitorB).
func _pose() -> void:
	var t: CountTotalTuning = _tuning
	var total_s: float = t.climax_hold_s + (0.0 if _still else t.climax_out_s)
	if _q >= total_s:
		stop()
		return
	if _still:
		_pose_still()
		return
	var out: float = 0.0
	if _q > t.climax_hold_s:
		out = _ease((_q - t.climax_hold_s) / maxf(0.01, t.climax_out_s))
	var grow: float = 1.0
	if _q < t.climax_in_s:
		grow = (
			t.climax_from + (t.climax_over - t.climax_from) * _ease(_q / maxf(0.01, t.climax_in_s))
		)
	elif _q < t.climax_settle_s:
		var settle: float = (_q - t.climax_in_s) / maxf(0.01, t.climax_settle_s - t.climax_in_s)
		grow = t.climax_over - (t.climax_over - 1.0) * _ease(settle)
	var shrink: float = 1.0 - (1.0 - t.climax_end_scale) * out
	_front.scale = Vector2.ONE * grow * shrink
	_front.position = (_target - CENTRE) * out
	_back.modulate.a = 1.0 - out
	_sun.set_angle(deg_to_rad(t.climax_spin * _q))
	_stamp.visible = _q > t.climax_stamp_at
	_tab.visible = _q > t.climax_tab_at
	var shining: bool = _q > t.climax_shine.x and _q < t.climax_shine.y
	var shine: float = (_q - t.climax_shine.x) / maxf(0.01, t.climax_shine.y - t.climax_shine.x)
	_number.set_shine(shine if shining else -1.0)
	_coins.queue_redraw()


## The reduced-motion climax: everything at rest, the stamp and the tab in, no coins.
func _pose_still() -> void:
	_front.scale = Vector2.ONE
	_front.position = Vector2.ZERO
	_back.modulate.a = 1.0
	_sun.set_angle(0.0)
	_stamp.visible = true
	_tab.visible = true
	_number.set_shine(-1.0)
	_coins.queue_redraw()


func _set_tab(amount: int) -> void:
	_tab.text = MonitorText.over_tab(amount, _quota)
	_tab.size = Vector2(_tab.get_minimum_size().x, TAB_LINE)


func _draw_coins() -> void:
	if _still:
		return
	for index: int in range(_tuning.climax_coins):
		var age: float = _q - COIN_START_S - (index % COIN_WAVE) * COIN_DELAY_S
		if age < 0.0 or age > COIN_LIFE_S:
			continue
		var out_x: float = (((index * 37) % 13) - 6) * COIN_SPREAD
		var up: float = -COIN_RISE - ((index * 53) % COIN_RISE_SPREAD)
		var at: Vector2 = (
			COIN_FROM + Vector2(out_x * age, up * age + 0.5 * COIN_GRAVITY * age * age)
		)
		var flip: float = absf(cos(age * COIN_FLIP + index))
		var width: float = maxf(2.0, snappedf(COIN_SIZE.x * flip, 2.0))
		var rect: Rect2 = Rect2(
			snappedf(at.x - width / 2.0, 2.0),
			snappedf(at.y - COIN_SIZE.y / 2.0, 2.0),
			width,
			COIN_SIZE.y
		)
		_coins.draw_texture_rect(COIN, rect, false)


static func _ease(value: float) -> float:
	var x: float = clampf(value, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())
