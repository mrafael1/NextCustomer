class_name RegisterTotal
extends Control
## Checkout Rhythm v3: the register's customer display while the checkout key is held.
## Reads the shared LED model; scores and quota decisions remain in CountUpPlan.

signal drawer_kicked(wide: bool)

const SIZE := Vector2(292, 76)
const COIN := preload("res://art/icons/coin.png")
const NUMBER_RECT := Rect2(12, 13, 268, 43)
const STATUS_RECT := Rect2(12, 55, 268, 17)
const CELEBRATE_S := 0.85

var _led: LedDisplay
var _count: CountUp
var _number: Label
var _status: Label
var _met_label: Label
var _celebration: Tween
var _views: Array[CardView] = []
var _shown: int = 0


func _init() -> void:
	name = "RegisterTotal"
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	var heading: Label = UiKit.display_label("TOTAL", 12, false)
	heading.add_theme_color_override("font_color", Palette.TEAL_LIGHT)
	heading.position = Vector2(12, 2)
	add_child(heading)
	_number = UiKit.body_label("€0", 42, Palette.TEAL_PALE)
	_number.name = "Number"
	_number.add_theme_font_override("font", ArtStyle.number_font())
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number.position = NUMBER_RECT.position
	_number.size = NUMBER_RECT.size
	add_child(_number)
	_status = UiKit.body_label("", 12, Palette.TEAL_PALE)
	_status.position = STATUS_RECT.position
	_status.size = STATUS_RECT.size
	add_child(_status)
	_met_label = UiKit.display_label("SPEND MET", 30, false)
	_met_label.add_theme_color_override("font_color", Palette.TEAL_PALE)
	_met_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_met_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_met_label.position = Vector2(2, 2)
	_met_label.size = SIZE - Vector2.ONE * 4.0
	_met_label.visible = false
	var background: StyleBoxFlat = StyleBoxFlat.new()
	background.bg_color = Palette.TEAL_BLACK
	_met_label.add_theme_stylebox_override("normal", background)
	add_child(_met_label)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Palette.INK)
	draw_rect(Rect2(Vector2.ONE * 2.0, size - Vector2.ONE * 4.0), Palette.TEAL_BLACK)
	for y: int in range(4, roundi(size.y) - 2, 3):
		draw_rect(Rect2(2, y, size.x - 4.0, 1), Color(Palette.INK, 0.12))


func follow(count_up: CountUp, reading: LedDisplay) -> void:
	_count = count_up
	_led = reading
	reading.mode_changed.connect(_on_mode)
	reading.reading_changed.connect(_on_reading)
	count_up.count_started.connect(_on_started)
	count_up.landing.connect(_on_landing)
	count_up.quota_met.connect(_on_met)
	_on_mode(reading.mode())


func amount() -> int:
	return _shown


func status_text() -> String:
	return _status.text


func number_label() -> Label:
	return _number


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
	_on_reading(_led.amount(), _led.quota(), _led.is_met())


func _on_reading(value: int, quota: int, met: bool) -> void:
	_shown = value
	_number.text = "€%d" % value
	for font_size: int in [42, 36, 30, 24, 18]:
		_number.add_theme_font_size_override("font_size", font_size)
		if (
			(
				ArtStyle
				. number_font()
				. get_string_size(_number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
				. x
			)
			<= NUMBER_RECT.size.x
		):
			break
	_status.text = (
		"SPEND €%d · %s"
		% [quota, "+€%d OVER" % (value - quota) if met else "€%d TO GO" % maxi(0, quota - value)]
	)
	_status.add_theme_color_override(
		"font_color", Palette.TEAL_PALE if met else Palette.TOMATO_LIGHT
	)


func _on_started(views: Array[CardView]) -> void:
	_views = views


func _reduced() -> bool:
	return _count != null and _count.plan != null and _count.plan.reduced_motion


func _on_landing(beat: CountUpBeat) -> void:
	if not CountUpPlan.is_payout_beat(beat) or beat.gain <= 0:
		return
	drawer_kicked.emit(false)
	if _reduced() or beat.slot < 0 or beat.slot >= _views.size():
		return
	_number.pivot_offset = Vector2(_number.size.x, _number.size.y / 2.0)
	_number.scale = Vector2.ONE * 1.12
	var punch: Tween = _count.tween_maker().call() as Tween
	punch.tween_property(_number, "scale", Vector2.ONE, 0.2)
	var from: Vector2 = _views[beat.slot].center()
	if _count.source_rect.is_valid():
		var source: Rect2 = _count.source_rect.call(beat.slot)
		from = source.get_center()
	var inverse: Transform2D = get_global_transform().affine_inverse()
	var start: Vector2 = inverse * from
	var end: Vector2 = inverse * (ShiftStage.DRAWER_RECT.get_center())
	for index: int in range(5):
		var coin: TextureRect = UiKit.sprite(COIN)
		coin.size = Vector2(10, 10)
		coin.position = start
		add_child(coin)
		var flight: Tween = _count.tween_maker().call() as Tween
		flight.tween_method(_coin_at.bind(coin, start, end, index), 0.0, 1.0, 0.3)
		flight.tween_callback(coin.queue_free)


static func _coin_at(t: float, coin: TextureRect, start: Vector2, end: Vector2, index: int) -> void:
	if not is_instance_valid(coin):
		return
	coin.position = start.lerp(end, t) - Vector2(0, sin(t * PI) * (30.0 + index * 6.0))


func _on_met(pop: bool) -> void:
	if not pop:
		return
	drawer_kicked.emit(true)
	if _celebration != null and _celebration.is_valid():
		_celebration.kill()
	_celebration = create_tween()
	_met_label.visible = true
	if _reduced():
		_celebration.tween_interval(CELEBRATE_S)
	else:
		for index: int in range(3):
			_celebration.tween_callback(_met_label.show)
			_celebration.tween_interval(0.17)
			_celebration.tween_callback(_met_label.hide)
			_celebration.tween_interval(0.11)
	_celebration.tween_callback(_met_label.hide)
