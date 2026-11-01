class_name CashDrawer
extends Control
## The register's cash drawer (v0.84, mock-up docs/art/mockups/register_polish.html, option A):
## the drawer art, slightly ajar so its coin tray shows, that takes each paid item's coins. 1 to
## COIN_MAX big coins by the payout (one per COIN_EUROS) arc in from the item, each with a short
## trail; the drawer kicks open with an overshoot as the first one flies, showing its dark tray;
## each coin lands with a squash and sparks and bumps it; it slams shut SHUT_AFTER_S after the
## last one, its € and handle flashing gold. The quota's kick (kick) opens it too, in real time,
## for MET_HOLD_S. Nothing moves under reduced motion. Decor only: it never scores.
##
## RegisterCabinet places it at ShiftStage.DRAWER_RECT and gives it the layer the coins fly on
## (above the register's keys and display) and the count-up whose tweens time the coins.

const DRAWER := preload("res://art/scenery/cash_drawer.png")
const COIN := preload("res://art/icons/coin.png")
## The coins: COIN_SCALE times the art, one per COIN_EUROS of the payout (at least one, at most
## COIN_MAX), COIN_GAP_S apart, each flying COIN_FLY_S on an arc COIN_ARC px high, COIN_SPREAD px
## apart where they land, with TRAIL ghosts TRAIL_LAG of the flight behind it.
const COIN_SCALE := 2.0
const COIN_EUROS := 8
const COIN_MAX := 5
const COIN_GAP_S := 0.07
const COIN_FLY_S := 0.34
const COIN_ARC := 90.0
const COIN_SPREAD := 22.0
const TRAIL := 3
const TRAIL_LAG := 0.06
const TRAIL_ALPHA := 0.18
## A landing: its squash (y scale), how long it lasts and how far it drops, its sparks (count,
## reach in px, time), and the bump it gives the open drawer (px).
const SQUASH := 0.6
const SQUASH_S := 0.12
const SQUASH_DROP := 10.0
const SPARKS := 6
const SPARK_REACH := 18.0
const SPARK_S := 0.25
const BUMP_PX := 2.0
## The drawer: how far it opens (with an overshoot, over KICK_S), the quota's open hold, how long
## after the last coin it shuts and how fast, and its flash (over the € glyph and the handle, in
## the art's px) fading over FLASH_S.
const KICK_PX := 16.0
const KICK_S := 0.14
const MET_HOLD_S := 0.45
const SHUT_AFTER_S := 0.12
const SHUT_S := 0.07
const FLASH_S := 0.26
const FLASH_RECTS: Array[Rect2] = [Rect2(282, 33, 12, 17), Rect2(100, 36, 112, 6)]
## The tray's dark mouth the open drawer shows. Its dividers continue the art's tray dividers
## (art/src/scenery/cash_drawer.txt: 2 px steel shade, the first at MOUTH_DIVIDER_FIRST px, then
## every MOUTH_DIVIDER_STEP px), and its sides are the art's MOUTH_SIDE px ink outline.
const MOUTH_HEIGHT := 22.0
const MOUTH_DIVIDER_FIRST := 22.0
const MOUTH_DIVIDER_STEP := 54.0
const MOUTH_DIVIDER_WIDTH := 2.0
const MOUTH_SIDE := 2.0

## Where the coins fly (a layer over the register; this drawer when unset).
var coin_layer: Control
var _count: CountUp
var _front: TextureRect
var _flash: Control
var _motion: Tween
## Coins still flying, and whether the quota's kick holds the drawer open.
var _in_flight: int = 0
var _met_hold: bool = false


func _init() -> void:
	name = "Drawer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = DRAWER.get_size()
	add_child(_mouth(size.x))
	_front = UiKit.sprite(DRAWER)
	_front.name = "Front"
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_front.size = size
	add_child(_front)
	_flash = _flash_layer()
	_front.add_child(_flash)


func follow(count_up: CountUp) -> void:
	_count = count_up


## The number of coins a payout of `gain` euros throws.
static func coins_for(gain: int) -> int:
	return clampi(ceili(float(gain) / COIN_EUROS), 1, COIN_MAX)


## How far the drawer is open now (px; 0 shut).
func opening() -> float:
	return _front.position.y


func coins_in_flight() -> int:
	return _in_flight


## The quota's kick: the drawer opens in real time (the quota's hit-stop doesn't freeze it) and
## stays open MET_HOLD_S, or until the last coin lands.
func kick() -> void:
	if _still():
		return
	_met_hold = true
	_open(create_tween())
	var hold: Tween = create_tween()
	hold.tween_interval(MET_HOLD_S)
	hold.tween_callback(_end_hold)


## Flies a payout of `gain` euros from `from` (global) into the drawer.
func throw_coins(from: Vector2, gain: int) -> void:
	if _still():
		return
	var layer: Control = _layer()
	var to_layer: Transform2D = layer.get_global_transform().affine_inverse()
	var start: Vector2 = to_layer * from
	var mouth: Vector2 = to_layer * (get_global_rect().get_center())
	mouth.y = (to_layer * get_global_position()).y + 6.0
	_open(_tween())
	var count: int = coins_for(gain)
	for index: int in range(count):
		var offset: float = (index - (count - 1) / 2.0) * COIN_SPREAD
		_in_flight += 1
		_fly(
			layer, start + Vector2(offset * 0.3, 0), mouth + Vector2(offset, 0), index * COIN_GAP_S
		)


func _still() -> bool:
	return _count == null or _count.plan == null or _count.plan.reduced_motion


func _tween() -> Tween:
	return _count.tween_maker().call() as Tween


func _layer() -> Control:
	return coin_layer if coin_layer != null else self


func _end_hold() -> void:
	_met_hold = false
	_shut()


func _fly(layer: Control, start: Vector2, end: Vector2, delay: float) -> void:
	var coin: TextureRect = _coin(layer, 1.0)
	var ghosts: Array[TextureRect] = []
	for index: int in range(TRAIL):
		ghosts.append(_coin(layer, TRAIL_ALPHA * (TRAIL - index)))
	var flight: Tween = _tween()
	flight.tween_interval(delay)
	flight.tween_method(_coin_at.bind(coin, ghosts, start, end), 0.0, 1.0, COIN_FLY_S)
	flight.tween_callback(_land.bind(layer, coin, ghosts, end))


static func _coin(layer: Control, alpha: float) -> TextureRect:
	var sprite: TextureRect = UiKit.sprite(COIN)
	sprite.name = "Coin"
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sprite.size = COIN.get_size() * COIN_SCALE
	sprite.pivot_offset = sprite.size / 2.0
	sprite.modulate.a = alpha
	sprite.visible = false
	layer.add_child(sprite)
	return sprite


static func _arc(t: float, start: Vector2, end: Vector2) -> Vector2:
	return start.lerp(end, t) - Vector2(0, sin(t * PI) * COIN_ARC)


static func _coin_at(
	t: float, coin: TextureRect, ghosts: Array[TextureRect], start: Vector2, end: Vector2
) -> void:
	if not is_instance_valid(coin):
		return
	coin.visible = true
	coin.position = (_arc(t, start, end) - coin.size / 2.0).round()
	for index: int in range(ghosts.size()):
		var lag: float = t - TRAIL_LAG * (index + 1)
		ghosts[index].visible = lag > 0.0
		ghosts[index].position = (_arc(maxf(lag, 0.0), start, end) - coin.size / 2.0).round()


func _land(layer: Control, coin: TextureRect, ghosts: Array[TextureRect], end: Vector2) -> void:
	for ghost: TextureRect in ghosts:
		ghost.queue_free()
	_in_flight = maxi(0, _in_flight - 1)
	if _motion == null or not _motion.is_running():
		_front.position.y = KICK_PX + BUMP_PX
		_motion = _tween()
		_motion.tween_property(_front, "position:y", KICK_PX, SQUASH_S)
	_sparks(layer, end)
	var squash: Tween = _tween()
	squash.tween_property(coin, "scale", Vector2(2.0 - SQUASH, SQUASH), SQUASH_S / 2.0)
	squash.parallel().tween_property(coin, "position:y", coin.position.y + SQUASH_DROP, SQUASH_S)
	squash.tween_property(coin, "modulate:a", 0.0, SQUASH_S / 2.0)
	squash.tween_callback(coin.queue_free)
	if _in_flight == 0:
		var wait: Tween = _tween()
		wait.tween_interval(SHUT_AFTER_S)
		wait.tween_callback(_shut)


func _sparks(layer: Control, at: Vector2) -> void:
	for index: int in range(SPARKS):
		var spark: ColorRect = ColorRect.new()
		spark.name = "Spark"
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.color = Palette.GOLD if index % 2 == 0 else Palette.PAPER
		spark.size = Vector2(3, 3)
		spark.position = at - Vector2(1.5, 7.5)
		layer.add_child(spark)
		var angle: float = TAU * index / SPARKS - PI / 2.0
		var to: Vector2 = spark.position + Vector2(cos(angle), sin(angle) * 0.6) * SPARK_REACH
		var burst: Tween = _tween()
		burst.tween_property(spark, "position", to, SPARK_S).set_ease(Tween.EASE_OUT)
		burst.parallel().tween_property(spark, "modulate:a", 0.0, SPARK_S)
		burst.tween_callback(spark.queue_free)


## Kicks the drawer open (an overshoot past KICK_PX) on `motion`, unless it is open already.
func _open(motion: Tween) -> void:
	if _front.position.y >= KICK_PX - 0.5:
		motion.kill()
		return
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = motion
	(
		motion
		. tween_property(_front, "position:y", KICK_PX, KICK_S)
		. set_trans(Tween.TRANS_BACK)
		. set_ease(Tween.EASE_OUT)
	)


## Slams the drawer shut and flashes its € and handle, once no coin flies and the quota's hold is
## over.
func _shut() -> void:
	if _in_flight > 0 or _met_hold or _still() or _front.position.y <= 0.0:
		return
	if _motion != null and _motion.is_valid():
		_motion.kill()
	_motion = _tween()
	_motion.tween_property(_front, "position:y", 0.0, SHUT_S).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_IN
	)
	_motion.tween_callback(_flash.set.bind("modulate:a", 1.0))
	_motion.tween_property(_flash, "modulate:a", 0.0, FLASH_S)


## The dark tray mouth the open drawer shows: charcoal in ink sides, with the tray's dividers.
static func _mouth(width: float) -> Control:
	var mouth: ColorRect = ColorRect.new()
	mouth.name = "Mouth"
	mouth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouth.color = Palette.CHARCOAL
	mouth.size = Vector2(width, MOUTH_HEIGHT)
	for side_x: float in [0.0, width - MOUTH_SIDE]:
		_mouth_bar(mouth, side_x, MOUTH_SIDE, ArtStyle.INK)
	var x: float = MOUTH_DIVIDER_FIRST
	while x + MOUTH_DIVIDER_WIDTH <= width - MOUTH_SIDE:
		_mouth_bar(mouth, x, MOUTH_DIVIDER_WIDTH, Palette.STEEL_SHADE)
		x += MOUTH_DIVIDER_STEP
	return mouth


static func _mouth_bar(mouth: ColorRect, x: float, width: float, colour: Color) -> void:
	var bar: ColorRect = ColorRect.new()
	bar.color = colour
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.position = Vector2(x, 0)
	bar.size = Vector2(width, MOUTH_HEIGHT)
	mouth.add_child(bar)


## The gold flash over the €  and the handle (FLASH_RECTS), clear until the drawer slams shut.
static func _flash_layer() -> Control:
	var layer: Control = Control.new()
	layer.name = "Flash"
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.modulate.a = 0.0
	for rect: Rect2 in FLASH_RECTS:
		var glow: ColorRect = ColorRect.new()
		glow.color = Palette.GOLD
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.position = rect.position
		glow.size = rect.size
		layer.add_child(glow)
	return layer
