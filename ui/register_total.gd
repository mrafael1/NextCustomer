class_name RegisterTotal
extends Control
## The register's count follower (Checkout Rhythm v3; v0.84's tally, mock-up
## docs/art/mockups/register_polish.html, option A). Its customer display (BONUSES, WASTED,
## ITEMS and the SPEND MET plate over the held CHECKOUT key) was removed on 2026-11-01 (the
## user: more info for nothing; the top bar's gauge, the monitor and the belt already show the
## count), so it draws nothing and is never shown. It still counts the tally (the bonus lines
## fired, the bonuses WASTED, the row's items scanned), holds the count CELEBRATE_S at the
## quota (is_celebrating, the crossing's beat) and asks the cabinet for each paid item's coins
## (coins_paid) and the quota's drawer kick. It reads the count-up's plan and signals only;
## scores and quota decisions remain in CountUpPlan.

## The quota's kick of the drawer (`wide`: the quota met; the cabinet opens it and lets it shut).
signal drawer_kicked(wide: bool)
## An item paid `gain` euros: its coins fly from `from` (global) into the drawer.
signal coins_paid(from: Vector2, gain: int)

## The count's hold at the quota.
const CELEBRATE_S := 0.85

var _led: LedDisplay
var _count: CountUp
var _celebration: Tween
var _views: Array[CardView] = []
var _shown: int = 0
var _met: bool = false
var _bonuses: int = 0
var _wasted: int = 0
var _items: int = 0
## Whether the reading counts a row now.
var _counting: bool = false
## The scan slots counted so far.
var _scanned: Dictionary[int, bool] = {}
## The plan the tally counts (a new plan resets it; a plan shown at once fills it whole).
var _plan: CountUpPlan


func _init() -> void:
	name = "RegisterTotal"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


func follow(count_up: CountUp, reading: LedDisplay) -> void:
	_count = count_up
	_led = reading
	reading.mode_changed.connect(_on_mode)
	reading.reading_changed.connect(_on_reading)
	count_up.count_started.connect(_on_started)
	count_up.step_landed.connect(_on_step_landed)
	count_up.beat_started.connect(_on_beat_started)
	count_up.landing.connect(_on_landing)
	count_up.quota_met.connect(_on_met)
	_on_mode(reading.mode())


## The reading the display follows (the count's subtotal; the gauge shows it).
func amount() -> int:
	return _shown


## The tally's three values: bonus lines fired, bonuses wasted, items scanned.
func tally() -> Vector3i:
	return Vector3i(_bonuses, _wasted, _items)


## Whether the reading counts a row now (the display showed then).
func is_counting() -> bool:
	return _counting


func is_met() -> bool:
	return _met


func is_celebrating() -> bool:
	return _celebration != null and _celebration.is_valid() and _celebration.is_running()


func _process(_delta: float) -> void:
	if is_celebrating():
		_celebration.set_speed_scale(_count.press_speed())


func _on_mode(_mode: LedDisplay.Mode) -> void:
	_counting = _led.is_counting()
	if not _counting or _led.mode() == LedDisplay.Mode.SUBTOTAL:
		if _celebration != null and _celebration.is_valid():
			_celebration.kill()
	if not _counting:
		_reset(null)
	elif _count != null and _count.plan != null and _count.plan != _plan:
		_fill(_count.plan)  # A count shown at once (an end state): the whole row's tally.
	_on_reading(_led.amount(), _led.quota(), _led.is_met())


func _on_reading(value: int, _quota: int, met: bool) -> void:
	_shown = value
	_met = met


func _on_started(views: Array[CardView]) -> void:
	_views = views
	_reset(_count.plan)


func _reset(plan: CountUpPlan) -> void:
	_plan = plan
	_bonuses = 0
	_wasted = 0
	_items = 0
	_scanned.clear()


## The whole row's tally at once, from `plan`.
func _fill(plan: CountUpPlan) -> void:
	_reset(plan)
	var slots: Dictionary[int, bool] = {}
	for beat: CountUpBeat in plan.beats:
		if _is_bonus(beat):
			_bonuses += 1
		elif beat.kind == CountUpBeat.Kind.FIZZLE:
			_wasted += 1
		if beat.scan_slot >= 0:
			slots[beat.scan_slot] = true
	_items = slots.size()


## A bonus line: a beat that is not a payout and has lines to cheer (CheckoutCrowd's rule).
static func _is_bonus(beat: CountUpBeat) -> bool:
	return not CountUpPlan.is_payout_beat(beat) and beat.cheer_count > 0


func _on_step_landed(index: int) -> void:
	if _plan == null:
		return
	for beat: CountUpBeat in _plan.beats:
		if beat.steps.is_empty() or beat.steps[0] != index:
			continue
		if _is_bonus(beat):
			_bonuses += 1
		elif beat.kind == CountUpBeat.Kind.FIZZLE:
			_wasted += 1
		return


## An item reaches the scanner: its scan group's first beat.
func _on_beat_started(
	beat: CountUpBeat, _step: ScoreStep, _line: String, _view: CardView, _items_count: int
) -> void:
	if beat.scan_slot < 0 or beat.scan_slot in _scanned:
		return
	_scanned[beat.scan_slot] = true
	_items = _scanned.size()


func _reduced() -> bool:
	return _count != null and _count.plan != null and _count.plan.reduced_motion


## A paid item's coins fly from it into the drawer (RegisterCabinet).
func _on_landing(beat: CountUpBeat) -> void:
	if not CountUpPlan.is_payout_beat(beat) or beat.gain <= 0:
		return
	if _reduced() or beat.slot < 0 or beat.slot >= _views.size():
		return
	var from: Vector2 = _views[beat.slot].center()
	if _count.source_rect.is_valid():
		var source: Rect2 = _count.source_rect.call(beat.slot)
		from = source.get_center()
	coins_paid.emit(from, beat.gain)


## The quota met: the drawer's wide kick and, while the count holds, the crossing's beat.
func _on_met(pop: bool) -> void:
	_met = true
	if not pop:
		return
	drawer_kicked.emit(true)
	if _celebration != null and _celebration.is_valid():
		_celebration.kill()
	_celebration = create_tween()
	_celebration.tween_interval(CELEBRATE_S)
