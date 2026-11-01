class_name RegisterTotal
extends Control
## The register's customer display while the checkout key is held (Checkout Rhythm v3; the tally
## since v0.84, mock-up docs/art/mockups/register_polish.html, option A). The top bar's gauge
## already shows the total and what is left to the quota, so the display counts what nothing
## else counts: the bonus lines fired (each one CheckoutCrowd cheers: a +N, a × above 1, a copy),
## the bonuses WASTED (fizzles), and the row's items scanned so far ("ITEMS 3/6"). It reads the
## count-up's plan and signals only; scores and quota decisions remain in CountUpPlan.
##
## At the quota it shows a steady SPEND MET plate while the count holds for it (is_celebrating,
## CELEBRATE_S; no blinking), then keeps a gold frame for the rest of the count. Each paid item
## asks the cabinet for its coins (coins_paid: RegisterCabinet flies them into the drawer).

## The quota's kick of the drawer (`wide`: the quota met; the cabinet opens it and lets it shut).
signal drawer_kicked(wide: bool)
## An item paid `gain` euros: its coins fly from `from` (global) into the drawer.
signal coins_paid(from: Vector2, gain: int)

const SIZE := Vector2(292, 76)
## The three counters' columns: their left edge and width, with a rule between them.
const COLUMNS: Array[Vector2] = [Vector2(12, 92), Vector2(112, 92), Vector2(210, 72)]
const CAPTION_Y := 6.0
const CAPTION_SIZE := 11
const VALUE_RECT_Y := 22.0
const VALUE_HEIGHT := 44.0
const VALUE_SIZE := 34
const ITEMS_SIZE := 26
const BONUSES := "BONUSES"
const WASTED := "WASTED"
const ITEMS := "ITEMS"
const ITEMS_VALUE := "%d/%d"
## A counter's punch as it counts (from this scale back to 1 over PUNCH_S).
const PUNCH_SCALE := 1.2
const PUNCH_S := 0.2
const RULE_INSET := 10.0
const MET_TEXT := "SPEND MET"
const CELEBRATE_S := 0.85
const FRAME := 2.0

var _led: LedDisplay
var _count: CountUp
var _bonus_label: Label
var _wasted_label: Label
var _items_label: Label
var _met_label: Label
var _celebration: Tween
var _views: Array[CardView] = []
var _shown: int = 0
var _met: bool = false
var _bonuses: int = 0
var _wasted: int = 0
var _items: int = 0
var _item_count: int = 0
## The scan slots counted so far.
var _scanned: Dictionary[int, bool] = {}
## The plan the tally counts (a new plan resets it; a plan shown at once fills it whole).
var _plan: CountUpPlan


func _init() -> void:
	name = "RegisterTotal"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var captions: Array[String] = [BONUSES, WASTED, ITEMS]
	var inks: Array[Color] = [Palette.TEAL_PALE, Palette.TOMATO_LIGHT, Palette.PAPER]
	var values: Array[Label] = []
	for index: int in range(COLUMNS.size()):
		var column: Vector2 = COLUMNS[index]
		# Bold Atkinson: Pixelify's capitals blur at this size (its B read as a G).
		var caption: Label = UiKit.body_label(captions[index], CAPTION_SIZE, Palette.TEAL_LIGHT)
		caption.add_theme_font_override("font", ArtStyle.bold_font(700))
		caption.position = Vector2(column.x, CAPTION_Y)
		add_child(caption)
		var value: Label = UiKit.body_label("0", VALUE_SIZE, inks[index])
		value.name = captions[index].capitalize()
		value.add_theme_font_override("font", ArtStyle.number_font())
		value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		value.position = Vector2(column.x, VALUE_RECT_Y)
		value.size = Vector2(column.y, VALUE_HEIGHT)
		value.pivot_offset = Vector2(0, VALUE_HEIGHT / 2.0)
		add_child(value)
		values.append(value)
	_bonus_label = values[0]
	_wasted_label = values[1]
	_items_label = values[2]
	_items_label.add_theme_font_size_override("font_size", ITEMS_SIZE)
	_met_label = UiKit.display_label(MET_TEXT, 30, false)
	_met_label.add_theme_color_override("font_color", Palette.GOLD)
	_met_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_met_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_met_label.position = Vector2.ONE * (FRAME + 1.0)
	_met_label.size = SIZE - Vector2.ONE * (2.0 * FRAME + 2.0)
	_met_label.visible = false
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Palette.TEAL_BLACK
	_met_label.add_theme_stylebox_override("normal", background)
	add_child(_met_label)
	_show_tally()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.GOLD if _met else Palette.INK)
	draw_rect(Rect2(Vector2.ONE * FRAME, size - Vector2.ONE * 2.0 * FRAME), Palette.TEAL_BLACK)
	for y: int in range(4, roundi(size.y) - 2, 3):
		draw_rect(Rect2(2, y, size.x - 4.0, 1), Color(Palette.INK, 0.12))
	for index: int in [1, 2]:
		var x: float = COLUMNS[index].x - 6.0
		draw_rect(Rect2(x, RULE_INSET, 2, size.y - 2.0 * RULE_INSET), Palette.SLATE)


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


## "ITEMS 3/6"'s count, the counter that punches as each item reaches the scanner.
func number_label() -> Label:
	return _items_label


func is_met() -> bool:
	return _met


func is_celebrating() -> bool:
	return _celebration != null and _celebration.is_valid() and _celebration.is_running()


func _process(_delta: float) -> void:
	if is_celebrating():
		_celebration.set_speed_scale(_count.press_speed())


func _on_mode(_mode: LedDisplay.Mode) -> void:
	visible = _led.is_counting()
	if not visible or _led.mode() == LedDisplay.Mode.SUBTOTAL:
		if _celebration != null and _celebration.is_valid():
			_celebration.kill()
		_met_label.visible = false
	if not visible:
		_reset(null)
	elif _count != null and _count.plan != null and _count.plan != _plan:
		_fill(_count.plan)  # A count shown at once (an end state): the whole row's tally.
	_on_reading(_led.amount(), _led.quota(), _led.is_met())


func _on_reading(value: int, _quota: int, met: bool) -> void:
	_shown = value
	if met != _met:
		_met = met
		queue_redraw()


func _on_started(views: Array[CardView]) -> void:
	_views = views
	_reset(_count.plan)
	_item_count = views.size()
	_show_tally()


func _reset(plan: CountUpPlan) -> void:
	_plan = plan
	_bonuses = 0
	_wasted = 0
	_items = 0
	_item_count = 0
	_scanned.clear()
	_show_tally()


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
	_item_count = slots.size()
	_show_tally()


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
			_show_tally()
			_punch(_bonus_label)
		elif beat.kind == CountUpBeat.Kind.FIZZLE:
			_wasted += 1
			_show_tally()
			_punch(_wasted_label)
		return


## An item reaches the scanner: its scan group's first beat.
func _on_beat_started(
	beat: CountUpBeat, _step: ScoreStep, _line: String, _view: CardView, _items_count: int
) -> void:
	if beat.scan_slot < 0 or beat.scan_slot in _scanned:
		return
	_scanned[beat.scan_slot] = true
	_items = _scanned.size()
	_show_tally()
	_punch(_items_label)


func _show_tally() -> void:
	_bonus_label.text = str(_bonuses)
	_wasted_label.text = str(_wasted)
	_items_label.text = ITEMS_VALUE % [_items, maxi(_item_count, _items)]


func _punch(label: Label) -> void:
	if _reduced() or _count == null:
		return
	label.scale = Vector2.ONE * PUNCH_SCALE
	var punch: Tween = _count.tween_maker().call() as Tween
	punch.tween_property(label, "scale", Vector2.ONE, PUNCH_S)


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


## The quota met: the drawer's wide kick and, while the count holds, a steady SPEND MET plate.
func _on_met(pop: bool) -> void:
	if not _met:
		_met = true
		queue_redraw()
	if not pop:
		return
	drawer_kicked.emit(true)
	if _celebration != null and _celebration.is_valid():
		_celebration.kill()
	_celebration = create_tween()
	_met_label.visible = true
	_celebration.tween_interval(CELEBRATE_S)
	_celebration.tween_callback(_met_label.hide)
