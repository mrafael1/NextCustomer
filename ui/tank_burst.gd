class_name TankBurst
extends Control
## The count's gold outside the monitor's glass (the monitor juice, mock-up monitor_juice_v2.html,
## K1 with WIN B, the coin fountain, the user's picks of 2026-10-22; before it #86 v6's jets and
## the monitor bay follow-up's pour): a layer over the whole stage (ShiftStage, just under the scan
## layer, so above the top bar), taking no clicks. It draws on the art grid (ArtStyle.ART_SCALE px
## per art pixel) in Palette's gold, ink and paper:
## - burst() (the quota met, with its pop: the landing that meets it): coins spray up out of the
##   whole number and € (the LED's GoldTank.group_rect) for CountUpTuning.win_fountain_s, outward,
##   most of them to the right (towards the counter), a few to the left over the bay's top. A coin
##   falling back onto the monitor's screen (GLASS_RECT) drops behind the glass and goes, so none
##   covers the number, the scanner bay or the screen's labels; the rest fall past the monitor onto
##   the belt's top face (COIN_REST: they bounce, rest flat, blink and go). With it: sparks round
##   the monitor, gold splashes on its bezel that drip and blink out, and a small shake of the
##   monitor (win_shake_px);
## - spurt() (each payout landing after the quota): a short, lower fountain and a few sparks;
## - surface_drops() (each payout's landing): droplets jump off the gold's surface and sink back;
## - sparkle() (each payout's landing): a spark and a ring of gold and paper dust;
## - shake(): the monitor alone (the number and the € with it) shakes, never the stage.
## Nothing travels from the number into the € any more (the user: no hand-off). The splashes stay
## on the bezel (MONITOR_RECT), cut round the paper (PAPER_RECT, following the shake), and the
## sparks are spawned off it; everything stays on the stage. It all runs in real time (_process,
## advance()), so the count-up's hit-stops (the quota's hold) never freeze it. Reduced motion
## (`reduced_motion`) leaves out the coins, drops, dust, sparks and shakes: the burst leaves
## STILL_SPLASHES on the bezel instead. Decor only.

## What drawn_rects() returns: the free particles (drops, dust, sparks), the coins or the bezel's
## splashes.
enum Layer { PARTICLES, COINS, SPLASHES }
enum Kind { FOUNTAIN, SPLASH, SPARK }

const CELL := ArtStyle.ART_SCALE
## The stage, the monitor's bezel and its paper, in stage px.
const STAGE_RECT := Rect2(Vector2.ZERO, ShiftStage.SIZE)
const BEZEL_RECT := ShiftStage.MONITOR_RECT
const PAPER_RECT := MonitorView.PAPER_RECT
## The screen behind the monitor's glass, in art px from the bezel's top left (the mock-up's): a
## coin falling into it goes.
const GLASS_RECT := Rect2(4, 4, 205, 81)
## Art px per second per second.
const GRAVITY := 320.0
## A drop that falls past DROP_FLOOR (art px, plus up to DROP_FLOOR_SPREAD) goes.
const DROP_FLOOR := 150.0
const DROP_FLOOR_SPREAD := 40.0
## The coins' rest on the belt's top face (art px, y from x to y), their bounces (BOUNCE of the
## speed back up, SLIDE of the sideways speed kept, at most BOUNCES, or until slower than
## SETTLE_SPEED), their spin (frames per second) and their rest: a glint for GLINT_S, blinking at
## BLINK_HZ from BLINK_FROM_S, gone at REST_S.
const COIN_REST := Vector2(190, 198)
const COIN_BOUNCE := 0.38
const COIN_SLIDE := 0.55
const COIN_BOUNCES := 3
const COIN_SETTLE_SPEED := 20.0
const COIN_SPIN := 14.0
const COIN_GLINT_S := 0.2
const COIN_BLINK_FROM_S := 0.45
const COIN_BLINK_HZ := 14.0
const COIN_REST_S := 0.9
const COIN_FRAMES: Array[int] = [0, 1, 2, 3, 2, 1]
## The coins stay over the belt (art px, x from x to y: its ends less a coin's half).
const BELT_SPAN := Vector2(
	ShiftStage.BELT_RECT.position.x / CELL + 4.0, ShiftStage.BELT_RECT.end.x / CELL - 5.0
)
## The fountain's coins leave from FOUNTAIN_LIFT px over the group's ink, FOUNTAIN_INSET px in
## from its ends; their speeds and the share going left are CountUpTuning's (fountain_side,
## fountain_up, fountain_left).
const FOUNTAIN_LIFT := 2.0
const FOUNTAIN_INSET := 6.0
## A landing's droplets: up to DROP_SIDE art px per second sideways either way, DROP_UP.x plus up
## to DROP_UP.y upwards, gone DROP_LIFE s on or once they fall back under where they left;
## DROP_PAPER of them paper, the rest mustard light.
const DROP_SIDE := 20.0
const DROP_UP := Vector2(45, 45)
const DROP_LIFE := 0.7
const DROP_PAPER := 0.4
## A landing's sparkle: a spark for SPARKLE_S and DUST_COUNT dust specks flying out at DUST_SPEED
## (art px per second, across and down), slowing to DUST_KEEP of their speed each 1/60 s, gone at
## DUST_LIFE.
const SPARKLE_S := 0.3
const DUST_COUNT := 10
const DUST_SPEED := Vector2(55, 30)
const DUST_KEEP := 0.9
const DUST_LIFE := 0.25
## The splashes: at most SPLASH_MAX, living SPLASH_LIFE seconds, growing over SPLASH_GROW_S,
## dripping after DRIP_DELAY_S, blinking at SPLASH_BLINK_HZ over their last SPLASH_BLINK_S.
const SPLASH_MAX := 46
const SPLASH_LIFE := Vector2(1.1, 2.0)
const SPLASH_GROW_S := 0.08
const DRIP_DELAY_S := 0.15
const SPLASH_BLINK_S := 0.25
const SPLASH_BLINK_HZ := 16.0
## Reduced motion's splashes on the bezel: (x, y, radius, drip) in art px from the bezel's top left.
const STILL_SPLASHES: Array[Vector4i] = [
	Vector4i(178, 3, 4, 0),
	Vector4i(150, 2, 3, 6),
	Vector4i(209, 30, 3, 18),
	Vector4i(120, 4, 2, 0),
	Vector4i(196, 2, 3, 0),
	Vector4i(60, 2, 2, 5),
	Vector4i(209, 62, 2, 10),
	Vector4i(30, 85, 2, 3),
]
const SPARK_LIFE := Vector2(0.5, 0.9)
const SPARK_BLINK_HZ := 20.0
## The shake's swing rates.
const SHAKE_X_RATE := 91.0
const SHAKE_Y_RATE := 77.0
const SHAKE_Y_SHARE := 0.7
const RANDOM_SEED := 7
const GOLD_LIGHT := Palette.MUSTARD_LIGHT
const GOLD := Palette.MUSTARD
const GOLD_DARK := Palette.MUSTARD_DARK
const GOLD_PALE := Palette.MUSTARD_PALE
const DUST_GOLD := Palette.GOLD
const INK := Palette.INK
const GLINT := Palette.PAPER
const COIN_SHADOW := Palette.CHARCOAL
const COIN_SHADOW_ALPHA := 0.45
## The coin's spin frames, its flat rest and the spark (# ink, y pale or light, M gold, m dark,
## w paper).
const COIN_GLYPHS: Array[Array] = [
	[
		"..####..",
		".#yyyy#.",
		"#yyMMMM#",
		"#yM##Mm#",
		"#yMMMMm#",
		"#yMMMmm#",
		".#mmmm#.",
		"..####.."
	],
	["..###..", ".#yyM#.", "#yMMMm#", "#yM#Mm#", "#yMMMm#", "#yMMmm#", ".#mmm#.", "..###.."],
	[".###.", "#yMm#", "#yMm#", "#y#m#", "#yMm#", "#yMm#", "#yMm#", ".###."],
	[".#.", "#y#", "#M#", "#M#", "#M#", "#m#", "#m#", ".#."],
]
const COIN_FLAT: Array[String] = [".######.", "#yyyyyy#", "#MMMMMm#", ".######."]
const SPARK_GLYPH: Array[String] = ["..y..", "..y..", "yywyy", "..y..", "..y.."]

static var _textures: Dictionary[String, Texture2D] = {}

## Returns whether to reduce motion (the profile's setting); an empty Callable means no.
var reduced_motion: Callable = Callable()

## The LED whose number and € the coins leave from (its GoldTank's group_rect).
var _led: LedDisplay
var _shake_target: Control
var _tuning: CountUpTuning
## The shake target's position at rest, and the shake's offset now (stage px).
var _rest: Vector2 = Vector2.ZERO
var _offset: Vector2 = Vector2.ZERO
## Real seconds since the layer started.
var _time: float = 0.0
var _drops: Array[Drop] = []
var _dust: Array[Drop] = []
var _sparks: Array[Spark] = []
var _coins: Array[Coin] = []
var _splashes: Array[Splash] = []
var _emitters: Array[Emitter] = []
## Each shake: (start, px, seconds).
var _shakes: Array[Vector3] = []
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
## While drawn_rects() runs: the pieces painted, by layer, instead of drawing them.
var _recording: bool = false
var _recorded: Dictionary[Layer, Array] = {}


## A gold drop or a speck of dust (art px): a drop falls under GRAVITY and goes once it falls back
## under its `sink`; dust slows down.
class Drop:
	extends RefCounted
	var at: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var life: float = 0.0
	var colour: Color = Palette.MUSTARD
	var sink: float = INF


class Spark:
	extends RefCounted
	var at: Vector2 = Vector2.ZERO
	var life: float = 0.0
	var span: float = 1.0


class Coin:
	extends RefCounted
	var at: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var phase: float = 0.0
	var rest: float = 0.0
	var bounces: int = 0
	## When it came to rest (the layer's time), or -1 while flying.
	var rest_at: float = -1.0


## A splash on the bezel (art px, stage-wide): a blob that drips; `still` ones (reduced motion)
## never grow, drip, blink or go.
class Splash:
	extends RefCounted
	var at: Vector2 = Vector2.ZERO
	var radius: int = 1
	var born: float = 0.0
	var dies: float = 0.0
	var drip: float = 0.0
	var drip_x: float = 0.0
	var drip_speed: float = 0.0
	var still: bool = false


class Emitter:
	extends RefCounted
	var kind: int = 0
	var start: float = 0.0
	var end: float = 0.0
	var rate: float = 0.0
	var power: float = 1.0
	var due: float = 0.0


func _init() -> void:
	name = "TankBurst"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = ShiftStage.SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_random.seed = RANDOM_SEED


## The LED whose number and € the coins leave from, and the control the shakes move (the monitor).
func bind(led: LedDisplay, shake_target: Control) -> void:
	_led = led
	_shake_target = shake_target


## The tuning (CountUp.TUNING_PATH unless set).
func tuning() -> CountUpTuning:
	if _tuning == null:
		_tuning = load(CountUp.TUNING_PATH) as CountUpTuning
	return _tuning


func set_tuning(value: CountUpTuning) -> void:
	_tuning = value


## The quota met with its pop (see the class comment); under reduced motion STILL_SPLASHES alone.
func burst() -> void:
	if _reduced():
		for still: Vector4i in STILL_SPLASHES:
			var splash: Splash = Splash.new()
			splash.at = _bezel().position + Vector2(still.x, still.y)
			splash.radius = still.z
			splash.drip = still.w
			splash.drip_x = splash.at.x
			splash.still = true
			_splashes.append(splash)
		queue_redraw()
		return
	var tune: CountUpTuning = tuning()
	shake(tune.win_shake_px, tune.win_shake_s)
	_emit(Kind.FOUNTAIN, 0.0, tune.win_fountain_s, tune.win_fountain_rate, 1.0)
	_emit(Kind.SPLASH, tune.win_splash_delay_s, tune.win_splash_s, tune.win_splash_rate, 1.0)
	for _index: int in range(tune.win_sparks):
		_spawn_spark()
	queue_redraw()


## A payout landing past the quota: a short, lower fountain and a few sparks.
func spurt() -> void:
	if _reduced():
		return
	var tune: CountUpTuning = tuning()
	_emit(
		Kind.FOUNTAIN,
		0.0,
		tune.after_fountain_s,
		tune.after_fountain_rate,
		tune.after_fountain_power
	)
	for _index: int in range(tune.after_sparks):
		_spawn_spark()
	queue_redraw()


## A payout's landing: a droplet jumps off the gold's surface at each of `points` (global:
## GoldTank.surface_points) and sinks back.
func surface_drops(points: Array[Vector2]) -> void:
	if _reduced():
		return
	for point: Vector2 in points:
		var drop: Drop = Drop.new()
		drop.at = _art_point(point)
		drop.velocity = Vector2(
			_random.randf_range(-DROP_SIDE, DROP_SIDE), -(DROP_UP.x + _random.randf() * DROP_UP.y)
		)
		drop.life = DROP_LIFE
		drop.colour = GLINT if _random.randf() < DROP_PAPER else GOLD_LIGHT
		drop.sink = drop.at.y + 1.0
		_drops.append(drop)
	queue_redraw()


## A payout's landing on the number: a spark at `point` (global: the digits' middle) and a ring
## of gold and paper dust.
func sparkle(point: Vector2) -> void:
	if _reduced():
		return
	var at: Vector2 = _art_point(point)
	var spark: Spark = Spark.new()
	spark.at = at
	spark.span = SPARKLE_S
	spark.life = SPARKLE_S
	_sparks.append(spark)
	for index: int in range(DUST_COUNT):
		var angle: float = TAU * index / DUST_COUNT
		var speck: Drop = Drop.new()
		speck.at = at
		speck.velocity = Vector2(cos(angle) * DUST_SPEED.x, sin(angle) * DUST_SPEED.y)
		speck.life = DUST_LIFE
		speck.colour = DUST_GOLD if index % 2 == 1 else GLINT
		_dust.append(speck)
	queue_redraw()


## Shakes the monitor `px` px, fading over `seconds` (nothing under reduced motion). Shakes add
## up; the monitor comes back to rest when the last ends.
func shake(px: float, seconds: float) -> void:
	if _reduced() or _shake_target == null or seconds <= 0.0:
		return
	if _shakes.is_empty():
		_rest = _shake_target.position
	_shakes.append(Vector3(_time, px, seconds))


## Everything goes at once (a new count, planning): the monitor back at rest.
func clear() -> void:
	_drops.clear()
	_dust.clear()
	_sparks.clear()
	_coins.clear()
	_splashes.clear()
	_emitters.clear()
	if not _shakes.is_empty() and _shake_target != null:
		_shake_target.position = _rest
	_shakes.clear()
	_offset = Vector2.ZERO
	queue_redraw()


## Moves everything on by `delta` real seconds (_process calls it; tests step it).
func advance(delta: float) -> void:
	_time += delta
	_run_emitters(delta)
	_move_drops(delta)
	_move_dust(delta)
	_move_coins(delta)
	var sparks: Array[Spark] = []
	for spark: Spark in _sparks:
		spark.life -= delta
		if spark.life > 0.0:
			sparks.append(spark)
	_sparks = sparks
	var splashes: Array[Splash] = []
	for splash: Splash in _splashes:
		if splash.still or _time < splash.dies:
			splashes.append(splash)
	_splashes = splashes
	_move_shake()
	queue_redraw()


## Whether anything is moving or showing (a still splash included).
func is_active() -> bool:
	return not _splashes.is_empty() or _is_moving()


## The rects (stage px, the layer's coordinates) that `layer`'s drawing covers now, cut as drawn.
func drawn_rects(layer: Layer) -> Array[Rect2]:
	_recording = true
	_recorded = {Layer.PARTICLES: [], Layer.COINS: [], Layer.SPLASHES: []}
	_paint()
	_recording = false
	var rects: Array[Rect2] = []
	rects.assign(_recorded[layer])
	return rects


## The coins at rest now (stage px: each one's spot on the belt).
func resting_coins() -> Array[Vector2]:
	var spots: Array[Vector2] = []
	for coin: Coin in _coins:
		if coin.rest_at >= 0.0:
			spots.append(coin.at * CELL)
	return spots


## How many coins are out (flying or resting).
func coin_count() -> int:
	return _coins.size()


## The shake's offset of the monitor now (stage px).
func shake_offset() -> Vector2:
	return _offset


func _process(delta: float) -> void:
	if _is_moving():
		advance(delta)


## Whether anything moves (is_active without the still splashes, which are drawn once when they
## come and then need no frames).
func _is_moving() -> bool:
	for splash: Splash in _splashes:
		if not splash.still:
			return true
	return not (
		_drops.is_empty()
		and _dust.is_empty()
		and _sparks.is_empty()
		and _coins.is_empty()
		and _emitters.is_empty()
		and _shakes.is_empty()
	)


func _draw() -> void:
	_paint()


## Draws (or, for drawn_rects, records) everything: the splashes, the drops, the dust, the sparks
## and the coins.
func _paint() -> void:
	for splash: Splash in _splashes:
		_paint_splash(splash)
	for drop: Drop in _drops:
		var tall: int = 2 if drop.velocity.y > 60.0 else 1
		_fill(drop.at, Vector2(1, tall), drop.colour, Layer.PARTICLES)
	for speck: Drop in _dust:
		_fill(speck.at, Vector2.ONE, speck.colour, Layer.PARTICLES)
	for spark: Spark in _sparks:
		var fading: bool = spark.life / spark.span <= 0.25
		if not fading or int(_time * SPARK_BLINK_HZ) % 2 == 1:
			_blit(_texture("spark"), spark.at - Vector2(2, 2), Layer.PARTICLES)
	for coin: Coin in _coins:
		_paint_coin(coin)


func _paint_splash(splash: Splash) -> void:
	var age: float = _time - splash.born
	if not splash.still and splash.dies - _time < SPLASH_BLINK_S:
		if int(_time * SPLASH_BLINK_HZ) % 2 == 1:
			return
	var grown: float = 1.0 if splash.still else clampf(age / SPLASH_GROW_S, 0.0, 1.0)
	var radius: int = maxi(1, roundi(splash.radius * grown))
	var drip: float = splash.drip
	if not splash.still:
		drip = minf(splash.drip, maxf(0.0, age - DRIP_DELAY_S) * splash.drip_speed)
	var length: int = roundi(drip)
	if length > 0:
		var top: Vector2 = Vector2(splash.drip_x, splash.at.y)
		_fill(top, Vector2(1, length), GOLD, Layer.SPLASHES)
		_fill(top + Vector2(1, 0), Vector2(1, length - 1), GOLD_DARK, Layer.SPLASHES)
		_fill(top + Vector2(0, length - 1), Vector2(2, 2), GOLD, Layer.SPLASHES)
		_fill(top + Vector2(0, length - 1), Vector2(1, 1), GOLD_LIGHT, Layer.SPLASHES)
	var blob: Texture2D = _texture("blob%d" % radius)
	_blit(blob, splash.at.round() - Vector2(radius, radius), Layer.SPLASHES)


## A coin spinning in the air, or flat at rest with its shadow (a glint as it lands, a blink
## before it goes).
func _paint_coin(coin: Coin) -> void:
	var at: Vector2 = coin.at.round()
	if coin.rest_at < 0.0:
		var frame: int = COIN_FRAMES[floori(coin.phase) % COIN_FRAMES.size()]
		var texture: Texture2D = _texture("coin%d" % frame)
		_blit(texture, at - Vector2(floorf(texture.get_width() / 2.0), 4), Layer.COINS)
		return
	var resting: float = _time - coin.rest_at
	if resting > COIN_BLINK_FROM_S and int(resting * COIN_BLINK_HZ) % 2 == 1:
		return
	if resting < COIN_GLINT_S:
		_blit(_texture("spark"), at - Vector2(2, 8), Layer.COINS)
	var shadow: Color = Color(COIN_SHADOW, COIN_SHADOW_ALPHA)
	_fill(at + Vector2(-3, 1), Vector2(8, 2), shadow, Layer.COINS)
	_blit(_texture("flat"), at - Vector2(4, 2), Layer.COINS)


## Fills `cells` art px at `at` (art px) in `colour`, cut to `layer`'s bounds.
func _fill(at: Vector2, cells: Vector2, colour: Color, layer: Layer) -> void:
	if cells.x <= 0.0 or cells.y <= 0.0:
		return
	var rect: Rect2 = Rect2(at.round() * CELL, cells.round() * CELL)
	for piece: Rect2 in _pieces(rect, layer):
		if _recording:
			_recorded[layer].append(piece)
		else:
			draw_rect(piece, colour)


## Draws `texture` (one texel per art px) with its top left at `at` (art px), cut to `layer`'s
## bounds.
func _blit(texture: Texture2D, at: Vector2, layer: Layer) -> void:
	var rect: Rect2 = Rect2(at.round() * CELL, texture.get_size() * CELL)
	for piece: Rect2 in _pieces(rect, layer):
		if _recording:
			_recorded[layer].append(piece)
		else:
			var source: Rect2 = Rect2((piece.position - rect.position) / CELL, piece.size / CELL)
			draw_texture_rect_region(texture, piece, source)


## `rect` cut to `layer`'s bounds (the stage; the bezel for splashes, less the paper: up to four
## pieces round it). The particles and the coins cross the paper.
func _pieces(rect: Rect2, layer: Layer) -> Array[Rect2]:
	var bound: Rect2 = STAGE_RECT
	if layer == Layer.SPLASHES:
		bound = Rect2(BEZEL_RECT.position + _offset, BEZEL_RECT.size).intersection(STAGE_RECT)
	var cut: Rect2 = rect.intersection(bound)
	var pieces: Array[Rect2] = []
	if cut.size.x <= 0.0 or cut.size.y <= 0.0:
		return pieces
	var hole: Rect2 = Rect2(PAPER_RECT.position + _offset, PAPER_RECT.size)
	if layer != Layer.SPLASHES or not hole.intersects(cut):
		pieces.append(cut)
		return pieces
	if cut.position.y < hole.position.y:
		pieces.append(Rect2(cut.position, Vector2(cut.size.x, hole.position.y - cut.position.y)))
	if cut.end.y > hole.end.y:
		pieces.append(Rect2(cut.position.x, hole.end.y, cut.size.x, cut.end.y - hole.end.y))
	var top: float = maxf(cut.position.y, hole.position.y)
	var bottom: float = minf(cut.end.y, hole.end.y)
	if bottom > top:
		if cut.position.x < hole.position.x:
			pieces.append(
				Rect2(cut.position.x, top, hole.position.x - cut.position.x, bottom - top)
			)
		if cut.end.x > hole.end.x:
			pieces.append(Rect2(hole.end.x, top, cut.end.x - hole.end.x, bottom - top))
	return pieces


## `kind` spawns at `rate` per second with `power` from `delay` for `seconds`.
func _emit(kind: Kind, delay: float, seconds: float, rate: float, power: float) -> void:
	var emitter: Emitter = Emitter.new()
	emitter.kind = kind
	emitter.start = _time + delay
	emitter.end = _time + delay + seconds
	emitter.rate = rate
	emitter.power = power
	_emitters.append(emitter)


func _run_emitters(delta: float) -> void:
	var running: Array[Emitter] = []
	for emitter: Emitter in _emitters:
		if _time > emitter.end:
			continue
		running.append(emitter)
		if _time < emitter.start:
			continue
		emitter.due += emitter.rate * delta
		while emitter.due >= 1.0:
			emitter.due -= 1.0
			_spawn(emitter.kind, emitter.power)
	_emitters = running


func _spawn(kind: int, power: float) -> void:
	match kind:
		Kind.FOUNTAIN:
			_spawn_fountain_coin(power)
		Kind.SPLASH:
			_spawn_splash(power)
		Kind.SPARK:
			_spawn_spark()


## A fountain coin: out of the number and €'s top, at a random point across them; most go right,
## those from the group's left fountain_left share go left (CountUpTuning's speeds).
func _spawn_fountain_coin(power: float) -> void:
	var group: Rect2 = _group()
	var across: float = _random.randf()
	var from: Vector2 = Vector2(
		group.position.x + FOUNTAIN_INSET + across * maxf(0.0, group.size.x - 2.0 * FOUNTAIN_INSET),
		group.position.y - FOUNTAIN_LIFT
	)
	var coin: Coin = _new_coin(_art_point(from))
	var tune: CountUpTuning = tuning()
	var side: float = -1.0 if across < tune.fountain_left else 1.0
	coin.velocity = Vector2(
		side * (tune.fountain_side.x + _random.randf() * tune.fountain_side.y) * power,
		-(tune.fountain_up.x + _random.randf() * tune.fountain_up.y) * power
	)


## The number and €'s ink (global), or the bezel's middle with no LED.
func _group() -> Rect2:
	if _led != null:
		return _led.gold_tank.group_rect()
	var bezel: Rect2 = Rect2(BEZEL_RECT.position + _offset, BEZEL_RECT.size)
	return Rect2(get_global_transform() * bezel.get_center(), Vector2.ZERO)


func _new_coin(at: Vector2) -> Coin:
	var coin: Coin = Coin.new()
	coin.at = at
	coin.phase = _random.randf() * 4.0
	coin.rest = _random.randf_range(COIN_REST.x, COIN_REST.y)
	_coins.append(coin)
	return coin


## A splash on the bezel: its top band right of the middle, its right side, or (`power` 1) its
## foot; at most SPLASH_MAX.
func _spawn_splash(power: float) -> void:
	var bezel: Rect2 = _bezel()
	var band: float = _random.randf()
	var at: Vector2
	if band < 0.5:
		at = Vector2(120.0 + _random.randf() * 92.0, _random.randf() * 9.0)
	elif band < 0.75 or power < 1.0:
		at = Vector2(203.0 + _random.randf() * 9.0, _random.randf() * 80.0)
	else:
		at = Vector2(60.0 + _random.randf() * 145.0, 83.0 + _random.randf() * 5.0)
	var drip: float = 6.0 + _random.randf() * 26.0 if _random.randf() < 0.55 else 0.0
	_add_splash(bezel.position + at, 1 + roundi(_random.randf() * 3.0), drip)


func _add_splash(at: Vector2, radius: int, drip: float) -> void:
	if _splashes.size() > SPLASH_MAX:
		return
	var splash: Splash = Splash.new()
	splash.at = at
	splash.radius = clampi(radius, 1, 4)
	splash.born = _time
	splash.dies = _time + _random.randf_range(SPLASH_LIFE.x, SPLASH_LIFE.y)
	splash.drip = drip
	splash.drip_x = at.x + roundf((_random.randf() - 0.5) * radius)
	splash.drip_speed = 6.0 + _random.randf() * 10.0
	_splashes.append(splash)


## A spark round the monitor, off its paper (a few tries; none if they all land on it).
func _spawn_spark() -> void:
	var bezel: Rect2 = _bezel()
	var paper: Rect2 = Rect2(PAPER_RECT.position / CELL, PAPER_RECT.size / CELL)
	for _try: int in range(8):
		var at: Vector2 = Vector2(
			bezel.position.x + 20.0 + _random.randf() * (bezel.size.x - 40.0),
			bezel.position.y - 6.0 + _random.randf() * (bezel.size.y + 10.0)
		)
		if paper.grow(2.0).has_point(at):
			continue
		var spark: Spark = Spark.new()
		spark.at = at
		spark.span = _random.randf_range(SPARK_LIFE.x, SPARK_LIFE.y)
		spark.life = spark.span
		_sparks.append(spark)
		return


## Drops fall; a landing's droplet goes once it falls back under where it left; past the floor
## any goes.
func _move_drops(delta: float) -> void:
	var kept: Array[Drop] = []
	for drop: Drop in _drops:
		drop.life -= delta
		if drop.life <= 0.0:
			continue
		drop.at += drop.velocity * delta
		drop.velocity.y += GRAVITY * delta
		if drop.velocity.y > 0.0 and drop.at.y > drop.sink:
			continue
		if drop.at.y > DROP_FLOOR + _random.randf() * DROP_FLOOR_SPREAD:
			continue
		kept.append(drop)
	_drops = kept


## The dust flies out and slows down, gone at DUST_LIFE.
func _move_dust(delta: float) -> void:
	var keep: float = pow(DUST_KEEP, delta * 60.0)
	var kept: Array[Drop] = []
	for speck: Drop in _dust:
		speck.life -= delta
		if speck.life <= 0.0:
			continue
		speck.at += speck.velocity * delta
		speck.velocity *= keep
		kept.append(speck)
	_dust = kept


## Coins fly; one falling back onto the screen goes behind the glass; the others bounce on the
## belt's face and rest there, going REST_S after.
func _move_coins(delta: float) -> void:
	var glass: Rect2 = Rect2(_bezel().position + GLASS_RECT.position, GLASS_RECT.size)
	var kept: Array[Coin] = []
	for coin: Coin in _coins:
		if coin.rest_at < 0.0:
			coin.at += coin.velocity * delta
			coin.velocity.y += GRAVITY * delta
			coin.phase += delta * COIN_SPIN
			if coin.velocity.y > 0.0 and glass.has_point(coin.at):
				continue
			if coin.at.y >= coin.rest and coin.velocity.y > 0.0:
				coin.bounces += 1
				coin.velocity = Vector2(
					coin.velocity.x * COIN_SLIDE, -coin.velocity.y * COIN_BOUNCE
				)
				coin.at.y = coin.rest
				var settled: bool = absf(coin.velocity.y) < COIN_SETTLE_SPEED
				if coin.bounces >= COIN_BOUNCES or settled:
					coin.rest_at = _time
			coin.at.x = clampf(coin.at.x, BELT_SPAN.x, BELT_SPAN.y)
		if coin.rest_at < 0.0 or _time - coin.rest_at < COIN_REST_S:
			kept.append(coin)
	_coins = kept


## The monitor at rest plus every running shake's swing, rounded; back at rest when they end.
func _move_shake() -> void:
	if _shakes.is_empty() or _shake_target == null:
		return
	var swing: Vector2 = Vector2.ZERO
	var running: Array[Vector3] = []
	for shaking: Vector3 in _shakes:
		var age: float = _time - shaking.x
		if age >= shaking.z:
			continue
		running.append(shaking)
		var amplitude: float = shaking.y * (1.0 - age / shaking.z)
		swing.x += sin(_time * SHAKE_X_RATE + shaking.x) * amplitude
		swing.y += cos(_time * SHAKE_Y_RATE + shaking.x * 3.0) * amplitude * SHAKE_Y_SHARE
	_shakes = running
	_offset = swing.round() if not running.is_empty() else Vector2.ZERO
	_shake_target.position = _rest + _offset


## The bezel in art px (following the shake).
func _bezel() -> Rect2:
	return Rect2((BEZEL_RECT.position + _offset) / CELL, BEZEL_RECT.size / CELL)


## `point` (global) in art px of the layer.
func _art_point(point: Vector2) -> Vector2:
	return (get_global_transform().affine_inverse() * point) / CELL


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())


## The glyph textures, built once: "coin0".."coin3", "flat", "spark", "blob1".."blob4".
static func _texture(key: String) -> Texture2D:
	if _textures.is_empty():
		var coin_colours: Dictionary[String, Color] = {
			"#": INK, "y": GOLD_PALE, "M": GOLD, "m": GOLD_DARK
		}
		var flat_colours: Dictionary[String, Color] = {
			"#": INK, "y": GOLD_LIGHT, "M": GOLD, "m": GOLD_DARK
		}
		var spark_colours: Dictionary[String, Color] = {"y": GOLD_LIGHT, "w": GLINT}
		for frame: int in range(COIN_GLYPHS.size()):
			_textures["coin%d" % frame] = _glyph(COIN_GLYPHS[frame], coin_colours)
		_textures["flat"] = _glyph(COIN_FLAT, flat_colours)
		_textures["spark"] = _glyph(SPARK_GLYPH, spark_colours)
		for radius: int in range(1, 5):
			_textures["blob%d" % radius] = _blob(radius)
	return _textures[key]


static func _glyph(rows: Array, colours: Dictionary[String, Color]) -> Texture2D:
	var image: Image = Image.create_empty(rows[0].length(), rows.size(), false, Image.FORMAT_RGBA8)
	for y: int in range(rows.size()):
		for x: int in range(rows[y].length()):
			var key: String = rows[y][x]
			if colours.has(key):
				image.set_pixel(x, y, colours[key])
	return ImageTexture.create_from_image(image)


## A round gold blob of `radius` art px: dark and gold on its lower right edge, light inside, pale
## on its upper left.
static func _blob(radius: int) -> Texture2D:
	var side: int = radius * 2 + 1
	var image: Image = Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	for j: int in range(-radius, radius + 1):
		for i: int in range(-radius, radius + 1):
			var distance: float = Vector2(i, j).length()
			if distance > radius + 0.3:
				continue
			var colour: Color
			if distance > radius - 0.9:
				colour = GOLD_DARK if i + j > 0 else GOLD
			else:
				colour = GOLD_PALE if i + j < -radius * 0.6 else GOLD_LIGHT
			image.set_pixel(i + radius, j + radius, colour)
	return ImageTexture.create_from_image(image)
