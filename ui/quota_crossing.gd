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
## - E, laps: from twice the quota on, each multiple reached (QuotaMeter.lap_reached) rings the
##   ka-ching while the tube's lap lamp names the lap. Since v1.13 (the user's review of
##   2026-11-05: the multiplier pop on the right of the receipt still popped at checkout) nothing
##   pops beside the receipt: the gold "×N" stamp and its sparkles are gone.
## - F, over-quota rewards: since 2026-11-06 the week's medals fly at the checkout
##   (MedalFlight, from ReceiptGoldFlow): the ×2 / ×3 reward rows beside the tube are gone.
##
## Left column v2 (2026-11-09): the gauge slides up out of the top bar at CHECKOUT, so the streak
## and its ring land on `aim` when it gives a rect (ShiftStage.receipt_target_rect: the receipt's
## target, where BEATEN! slams), and on the gauge's target line only when it does not.
##
## Real time (the ding's hit-stop freezes the count, not these). Reduced motion keeps the sound
## and the lights, with no dip, flash, streak, ring or sparkles. Stage coordinates (the layer
## covers the stage), over the fore, under the scan layer.

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
const GRID := 2.0

## Where the streak lands (returns a global Rect2; empty or unset: the gauge's target line).
var aim: Callable = Callable()
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
## Seconds since the crossing (-1: none).
var _since: float = -1.0
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
	# Its shapes are hard pixel cells, drawn 2x and up (untextured).
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


## The count reached a lap (twice the quota or more): E's ka-ching, and nothing drawn.
func ring_lap() -> void:
	_play_kaching()


## Whether the crossing's show (B: the streak and its ring) runs now.
func crossing_shown() -> bool:
	return _since >= 0.0 and _since < CROSS_SECONDS


## Where the crossing's streak flies from (the item that met the quota), in this layer.
func launch_point() -> Vector2:
	return _launch


## Whether anything of the crossing is drawn now: only B's streak and ring (a lap draws nothing).
func drawing() -> bool:
	return _since >= 0.0


func _process(delta: float) -> void:
	# Godot turns processing on when the node is ready: off until cross().
	if _since < 0.0:
		set_process(false)
		return
	_since += delta
	_move_dip()
	if _since >= CROSS_SECONDS:
		_since = -1.0
		_stop_dip()
		set_process(false)
	queue_redraw()


func _draw() -> void:
	if _since >= 0.0:
		_draw_streak()
		_draw_ring()


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


func _on_lap_reached(_lap: int) -> void:
	if _counting:
		ring_lap()


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


## The streak's target's rect in this layer: `aim`'s (the receipt's target), else the gauge's, else
## a stand-in at the gauge chip's place.
func _gauge_rect() -> Rect2:
	var aimed: Rect2 = _aimed()
	if aimed.has_area():
		return _local_rect(aimed)
	if meter == null or not meter.is_inside_tree():
		return ShiftStage.GAUGE_PANEL_RECT
	return _local_rect(meter.bar().get_global_rect())


## Where the streak ends, in this layer: `aim`'s middle, else the quota on the gauge.
func _quota_mark() -> Vector2:
	if _aimed().has_area():
		return _gauge.get_center()
	if meter == null or not meter.is_inside_tree():
		return Vector2(_gauge.end.x, _gauge.get_center().y)
	return get_global_transform().affine_inverse() * meter.quota_mark()


## `aim`'s rect (global), empty without one.
func _aimed() -> Rect2:
	if not aim.is_valid():
		return Rect2()
	return aim.call() as Rect2


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
