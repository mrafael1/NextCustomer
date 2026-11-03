class_name QuotaCrossing
extends Control
## The quota crossing (mock-up docs/art/mockups/quota_crossing.html, approved by the user on
## 2026-10-31): with one checkout a shift, the moment the count meets the quota must land.
## Decor only: it follows the count-up (quota_met with a pop) and the quota gauge (QuotaMeter, the
## tube beside the receipt since the shift scene polish: lap_reached), and never scores.
##
## At the crossing, on top of the count-up's ding and its hit-stop (the ding's hold) and the
## monitor's SPEND MET (A, the flag planted on the item, is gone since the user's feedback of
## 2026-11-03: the gauge's laps say it):
## - B, hit-stop + streak: the picture dips (DIP) under a warm flash, and a gold spark flies from
##   the item that met the quota to the quota on the gauge (the target line on the tube's top),
##   which pulses with a ring as it lands (CROSS_SECONDS in all).
## - C, ka-ching: the register's drawer and bell (Sfx "kaching"), one-off, apart from the ladder.
## - D, bonus lights: BonusLights light the belt's rail for the rest of the count.
## - E, laps: from twice the quota on, each multiple reached (QuotaMeter.lap_reached) slams a ×N
##   stamp over the belt's start, beside the tube's top and clear of the receipt, with sparkles
##   and the ka-ching, shrinking away as the tube's badge names the next lap.
##
## Real time (the ding's hit-stop freezes the count, not these). Reduced motion keeps the sound,
## the lights and the stamp standing still for its time, with no dip, flash, streak, ring or
## sparkles. Stage coordinates (the layer covers the stage), over the fore, under the
## scan layer.

## B: the dip's offsets (px, one per DIP_STEP_SECONDS), the flash, the streak's flight (from
## STREAK_START_SECONDS, STREAK_SECONDS long) and the gauge's ring.
const DIP: Array[Vector2] = [Vector2(0, 4), Vector2(-2, 2), Vector2.ZERO]
const DIP_STEP_SECONDS := 0.07
const FLASH_SECONDS := 0.38
const FLASH_ALPHA := 0.9
const STREAK_START_SECONDS := 0.04
const STREAK_SECONDS := 0.26
const STREAK_TRAIL := 7
const STREAK_BEND := Vector2(-100, 0)
const RING_SECONDS := 0.4
const RING_GROW_PX := 10.0
## The crossing's show (B) lasts this long: the streak's flight, then its ring.
const CROSS_SECONDS := STREAK_START_SECONDS + STREAK_SECONDS + RING_SECONDS
## The sparkles: BURST_DOTS dots out to BURST_RADIUS px over BURST_SECONDS.
const BURST_DOTS := 10
const BURST_RADIUS := 26.0
const BURST_SECONDS := 0.35
## C: the ka-ching's volume.
const KACHING_DB := 0.0
## E: the stamp over the belt's start, beside the tube's top: STAMP_DOWN_PX under the tube's top
## and STAMP_BESIDE_PX right of the register tower (ShiftStage.TOWER_RECT, which holds the
## receipt) even at its slam's full scale, so it never covers the receipt's TODAY'S TARGET
## (STAMP_SIZE at scale 1); slammed from STAMP_SLAM_SCALE over STAMP_SLAM_SECONDS, settling, then
## fading over its last STAMP_FADE_SECONDS.
const STAMP_SIZE := Vector2(70, 40)
const STAMP_BESIDE_PX := 12.0
const STAMP_DOWN_PX := 8.0
const STAMP_SLAM_SCALE := 2.6
const STAMP_SLAM_SECONDS := 0.15
const STAMP_SECONDS := 0.75
const STAMP_FADE_SECONDS := 0.2
const STAMP_TEXT := "×%d"
const GRID := 2.0
const ART := ArtStyle.ART_SCALE

## Returns where item `slot` is now (a global Rect2, CountUp.source_rect), set by follow().
var item_rect: Callable = Callable()
var meter: QuotaMeter
var lights: BonusLights
var reduced_motion: bool = false

var _count_up: CountUp
## A count is running (from count_started to the printer feed or its end): only then do the
## crossing and the laps pop (a resumed end state shows them met, not crossed).
var _counting: bool = false
## The slot of the latest beat's item (the one paying when the quota is met).
var _slot: int = -1
## Seconds since the crossing (-1: none) and since the last lap's stamp (-1: none), and that lap.
var _since: float = -1.0
var _lap_since: float = -1.0
var _lap: int = 0
## The streak's ends, in this layer's coordinates, taken at the crossing: the item that met the
## quota, and the quota mark on the gauge.
var _launch: Vector2 = Vector2.ZERO
var _mark: Vector2 = Vector2.ZERO
var _gauge: Rect2 = Rect2()
## B's dip: the viewport's canvas transform before it, while dipping.
var _dip_base: Transform2D = Transform2D.IDENTITY
var _dipping: bool = false
var _flash: TextureRect


func _init() -> void:
	name = "QuotaCrossing"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Its SPEND MET and ×N are hard pixel text, drawn 2x and up (its shapes are untextured).
	ArtStyle.use_pixel_text_material(self)
	_flash = TextureRect.new()
	_flash.name = "Flash"
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.stretch_mode = TextureRect.STRETCH_SCALE
	_flash.modulate.a = 0.0
	_flash.show_behind_parent = true
	add_child(_flash)
	set_process(false)


## Follows `count_up`'s checkouts and `quota_meter`'s laps, lighting `bonus_lights`.
func follow(count_up: CountUp, quota_meter: QuotaMeter, bonus_lights: BonusLights) -> void:
	_count_up = count_up
	meter = quota_meter
	lights = bonus_lights
	item_rect = func(slot: int) -> Rect2: return _source_rect(slot)
	count_up.count_started.connect(func(_views: Array[CardView]) -> void: begin())
	count_up.beat_started.connect(_on_beat_started)
	count_up.quota_met.connect(_on_quota_met)
	count_up.printer_feed.connect(end)
	count_up.finished.connect(end)
	quota_meter.lap_reached.connect(_on_lap_reached)


## A new count: everything off.
func begin() -> void:
	_stop_dip()
	_counting = true
	_slot = -1
	_since = -1.0
	_lap_since = -1.0
	_lap = 0
	if _count_up != null and _count_up.plan != null:
		reduced_motion = _count_up.plan.reduced_motion
	if lights != null:
		lights.reduced_motion = func() -> bool: return reduced_motion
		lights.clear()
	_flash.modulate.a = 0.0
	set_process(false)
	queue_redraw()


## The count ends: the lights fade; nothing else pops until the next count.
func end() -> void:
	_counting = false
	if lights != null:
		lights.fade()


## The quota is met with a pop: B, C and D start.
func cross() -> void:
	_since = 0.0
	var rect: Rect2 = _local_rect(_item())
	_launch = _snap(rect.get_center())
	_gauge = _gauge_rect()
	_mark = _quota_mark()
	_play_kaching()
	if lights != null:
		lights.light()
	if not reduced_motion:
		_start_flash(rect.get_center())
		_start_dip()
	set_process(true)
	queue_redraw()


## The count reached lap `lap` (twice the quota or more): E's stamp and the ka-ching.
func stamp_lap(lap: int) -> void:
	_lap = lap
	_lap_since = 0.0
	_gauge = _gauge_rect()
	_play_kaching()
	set_process(true)
	queue_redraw()


## Whether the crossing's show (B: the streak and its ring) runs now.
func crossing_shown() -> bool:
	return _since >= 0.0 and _since < CROSS_SECONDS


## Where the crossing's streak flies from (the item that met the quota), in this layer.
func launch_point() -> Vector2:
	return _launch


## Whether a lap's stamp (E) shows now.
func stamp_shown() -> bool:
	return _lap_since >= 0.0 and _lap_since < STAMP_SECONDS


## The lap stamp's centre in this layer (stage coordinates): over the belt's start, clear of the
## tower at the slam's full scale, its top STAMP_DOWN_PX under the tube's top.
func stamp_centre() -> Vector2:
	var reach: float = STAMP_SIZE.x * STAMP_SLAM_SCALE / 2.0
	return Vector2(
		ShiftStage.TOWER_RECT.end.x + STAMP_BESIDE_PX + reach,
		_gauge_rect().position.y + STAMP_DOWN_PX + STAMP_SIZE.y / 2.0
	)


## The lap stamp's rect at `scale_now` (1: at rest), in this layer.
func stamp_rect(scale_now: float = 1.0) -> Rect2:
	var box: Vector2 = (STAMP_SIZE * scale_now / GRID).round() * GRID
	return Rect2(_snap(stamp_centre() - box / 2.0), box)


func _process(delta: float) -> void:
	# Godot turns processing on when the node is ready: off until cross() or stamp_lap().
	if _since < 0.0 and _lap_since < 0.0:
		set_process(false)
		return
	if _since >= 0.0:
		_since += delta
		_move_dip()
		if _since >= CROSS_SECONDS:
			_since = -1.0
	if _lap_since >= 0.0:
		_lap_since += delta
		if _lap_since >= STAMP_SECONDS:
			_lap_since = -1.0
	if _since < 0.0 and _lap_since < 0.0:
		_stop_dip()
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _since >= 0.0:
		_draw_streak()
		_draw_ring()
	if _lap_since >= 0.0:
		_draw_stamp()


## B: the spark flies from the item to the quota mark, its trail behind it; then it bursts.
func _draw_streak() -> void:
	if reduced_motion:
		return
	var from: Vector2 = _launch
	var bend: Vector2 = (from + _mark) / 2.0 + STREAK_BEND
	var k: float = _ease((_since - STREAK_START_SECONDS) / STREAK_SECONDS)
	if _since < STREAK_START_SECONDS:
		return
	if k < 1.0:
		for index: int in range(STREAK_TRAIL, 0, -1):
			var at: Vector2 = _bezier(from, bend, _mark, maxf(0.0, k - index * 0.05))
			var side: float = 8.0 - index
			_cell(at - Vector2.ONE * side / 2.0, Vector2.ONE * side, _trail_colour(index))
		var head: Vector2 = _bezier(from, bend, _mark, k)
		_cell(head - Vector2(6, 6), Vector2(12, 12), Palette.INK)
		_cell(head - Vector2(4, 4), Vector2(8, 8), Palette.GOLD)
		_cell(head - Vector2(2, 4), Vector2(4, 2), Palette.PAPER)
		return
	var landed: float = _since - STREAK_START_SECONDS - STREAK_SECONDS
	_burst(_mark, landed / BURST_SECONDS)


## B: the gauge's ring as the spark lands.
func _draw_ring() -> void:
	if reduced_motion:
		return
	var landed: float = _since - STREAK_START_SECONDS - STREAK_SECONDS
	if landed < 0.0 or landed >= RING_SECONDS:
		return
	var a: float = 1.0 - landed / RING_SECONDS
	var ring: Rect2 = _gauge.grow(6.0 + (1.0 - a) * RING_GROW_PX)
	draw_rect(ring, Color(Palette.GOLD, a), false, 4.0)


## E: the ×N stamp slams over the belt's start, settles and fades, with sparkles.
func _draw_stamp() -> void:
	var t: float = _lap_since
	var scale_now: float = 1.0
	if not reduced_motion:
		if t < STAMP_SLAM_SECONDS:
			scale_now = lerpf(STAMP_SLAM_SCALE, 1.2, _ease(t / STAMP_SLAM_SECONDS))
		else:
			scale_now = lerpf(1.2, 1.0, _ease((t - STAMP_SLAM_SECONDS) / 0.3))
	var alpha: float = 1.0
	var fade_from: float = STAMP_SECONDS - STAMP_FADE_SECONDS
	if t > fade_from:
		alpha = 1.0 - _ease((t - fade_from) / STAMP_FADE_SECONDS)
	var centre: Vector2 = stamp_centre()
	var rect: Rect2 = stamp_rect(scale_now)
	draw_rect(rect.grow(3.0), Color(Palette.INK, alpha))
	draw_rect(rect, Color(Palette.GOLD, alpha))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 4.0)), Color(Palette.PAPER, alpha))
	var text: String = STAMP_TEXT % _lap
	var font: Font = ArtStyle.pixel_number_font()
	var size_px: int = ArtStyle.PIXEL_NUMBER_SIZE
	var text_scale: float = ART * scale_now
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x
	var ascent: float = font.get_ascent(size_px)
	var descent: float = font.get_descent(size_px)
	var origin: Vector2 = centre - Vector2(width, ascent - descent) * text_scale / 2.0
	draw_set_transform(origin.round(), 0.0, Vector2.ONE * text_scale)
	for offset: Vector2 in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
		draw_string(
			font,
			Vector2(0, ascent) + offset,
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			size_px,
			Color(Palette.INK, alpha)
		)
	draw_string(
		font,
		Vector2(0, ascent),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		size_px,
		Color(Palette.PAPER, alpha)
	)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if not reduced_motion:
		_burst(centre, t / (STAMP_SECONDS * 0.7))
		_burst(Vector2(_gauge.get_center().x, _gauge.position.y), (t - 0.1) / 0.4)


## BURST_DOTS sparkles round `at`, `k` from 0 to 1 (none outside).
func _burst(at: Vector2, k: float) -> void:
	if k < 0.0 or k > 1.0:
		return
	for index: int in range(BURST_DOTS):
		var angle: float = TAU * index / BURST_DOTS
		var radius: float = 6.0 + _ease(k) * BURST_RADIUS
		var side: float = 6.0 * (1.0 - k) + 2.0
		var dot: Vector2 = at + Vector2(cos(angle), sin(angle)) * radius - Vector2.ONE * side / 2.0
		_cell(dot, Vector2.ONE * side, Palette.GOLD if index % 2 else Palette.PAPER)


func _on_beat_started(
	_beat: CountUpBeat, step: ScoreStep, _line: String, _view: CardView, _items: int
) -> void:
	_slot = step.slot


func _on_quota_met(with_pop: bool) -> void:
	if with_pop and _counting:
		cross()


func _on_lap_reached(lap: int) -> void:
	if _counting:
		stamp_lap(lap)


## The flash: a warm glow round `centre` fading over FLASH_SECONDS.
func _start_flash(centre: Vector2) -> void:
	if _flash.texture == null:
		var gradient: Gradient = Gradient.new()
		gradient.set_color(0, Color(Palette.GOLD, 0.55))
		gradient.set_color(1, Color(Palette.GOLD, 0.0))
		var texture: GradientTexture2D = GradientTexture2D.new()
		texture.gradient = gradient
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5, 0.5)
		texture.fill_to = Vector2(1.0, 0.5)
		texture.width = 256
		texture.height = 256
		_flash.texture = texture
	var side: float = size.x * 1.2
	_flash.size = Vector2(side, side)
	_flash.position = centre - _flash.size / 2.0
	_flash.modulate.a = FLASH_ALPHA
	var tween: Tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(_flash, "modulate:a", 0.0, FLASH_SECONDS)


## The dip moves the picture, not the nodes: the viewport's canvas transform, like a camera, so
## no control's rect changes under it.
func _start_dip() -> void:
	if not is_inside_tree():
		return
	_stop_dip()
	_dip_base = get_viewport().canvas_transform
	_dipping = true
	_move_dip()


func _move_dip() -> void:
	if not _dipping:
		return
	var step: int = floori(_since / DIP_STEP_SECONDS)
	if step >= DIP.size():
		_stop_dip()
		return
	get_viewport().canvas_transform = _dip_base.translated(DIP[step])


func _stop_dip() -> void:
	if not _dipping:
		return
	_dipping = false
	if is_inside_tree():
		get_viewport().canvas_transform = _dip_base


func _exit_tree() -> void:
	_stop_dip()


func _play_kaching() -> void:
	var sfx: Sfx = Sfx.find(self)
	if sfx != null:
		sfx.play("kaching", 1.0, KACHING_DB)


## The paying item's rect now (global), or the scanner's when unknown.
func _item() -> Rect2:
	if _slot >= 0 and item_rect.is_valid():
		var rect: Rect2 = item_rect.call(_slot) as Rect2
		if rect.has_area():
			return rect
	var belt: Rect2 = Rect2(
		ShiftStage.BELT_RECT.position + BeltPanel.SCANNER_RECT.position, BeltPanel.SCANNER_RECT.size
	)
	return get_global_transform() * belt


func _source_rect(slot: int) -> Rect2:
	if _count_up == null or not _count_up.source_rect.is_valid():
		return Rect2()
	return _count_up.source_rect.call(slot) as Rect2


## The gauge's rect in this layer, or a stand-in at the tube's place.
func _gauge_rect() -> Rect2:
	if meter == null or not meter.is_inside_tree():
		return ShiftStage.TUBE_RECT
	return _local_rect(meter.bar().get_global_rect())


## Where the quota stands on the gauge, in this layer (the streak's end).
func _quota_mark() -> Vector2:
	if meter == null or not meter.is_inside_tree():
		return Vector2(_gauge.get_center().x, _gauge.position.y)
	return get_global_transform().affine_inverse() * meter.quota_mark()


func _local_rect(rect: Rect2) -> Rect2:
	return get_global_transform().affine_inverse() * rect


func _cell(at: Vector2, extent: Vector2, colour: Color) -> void:
	draw_rect(Rect2(_snap(at), (extent / GRID).round() * GRID), colour)


static func _snap(at: Vector2) -> Vector2:
	return (at / GRID).round() * GRID


static func _trail_colour(index: int) -> Color:
	return Palette.GOLD if index < 3 else Palette.MUSTARD_LIGHT


static func _bezier(from: Vector2, bend: Vector2, to: Vector2, k: float) -> Vector2:
	return from.lerp(bend, k).lerp(bend.lerp(to, k), k)


static func _ease(x: float) -> float:
	return 1.0 - pow(1.0 - clampf(x, 0.0, 1.0), 3.0)
