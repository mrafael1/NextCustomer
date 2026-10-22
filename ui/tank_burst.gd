class_name TankBurst
extends Control
## The count's gold outside the monitor (#86 v6 scan count-up, mock-up count_up_86_v6_scan.html's
## particles, coins, splashes, pour and spurts; since the monitor bay follow-up, mock-up
## monitor_bay_v1.html, they leave from the plain € after the number, LedDisplay.euro_label, which
## replaced the € tank): a layer over the whole stage (ShiftStage, just under the scan layer, so
## above the top bar), taking no clicks. It draws on the art grid (ArtStyle.ART_SCALE px per art
## pixel) in Palette's gold, ink and paper:
## - burst() (the quota met, with its pop): two gold jets out of the €'s top that rise past the top
##   bar (cut at the stage's top), geyser drops flying up and to both sides, coins that arc out of
##   the € (the monitor's right edge turns them back while they are beside it, COIN_EDGE) and rain
##   from the monitor's foot
##   onto the belt's top face (COIN_REST: they bounce, rest flat, blink and go), sparks round the
##   monitor, gold splashes on its bezel that drip and blink out, and a shake of the monitor
##   (BURST_SHAKE);
## - pour() (each payout as its chip lands in the number, #86 round 7): POUR_MIN to POUR_MAX small
##   gold drops hop from the gap before the € (pour_point) into the € over POUR_S;
## - spurt() (each payout once the quota is met, as its gold reaches the €): a smaller jet, drops,
##   coins and splashes;
## - shake(): the monitor alone (the number and the € with it) shakes, never the stage.
## The €'s own gold crosses the monitor's paper as it leaves the € (as in the mock-up): the pour,
## the jets, the geyser drops and the arcing coins (a falling drop goes on reaching the paper: it
## lands on the screen). The splashes stay on the bezel (MONITOR_RECT), cut round the paper
## (PAPER_RECT, following the shake), and the sparks are spawned off it; everything stays on the
## stage. It all runs in real time (_process, advance()), so the count-up's hit-stops (the quota's
## hold) never freeze it. Reduced motion (`reduced_motion`) leaves out the jets, drops, coins,
## pour, spurts and shakes: the burst leaves STILL_SPLASHES on the bezel instead. Decor only.

## What drawn_rects() returns: the free particles (jets, drops, coins, sparks), the bezel's
## splashes or the pour.
enum Layer { PARTICLES, SPLASHES, POUR }
enum Kind { GEYSER, SPLASH, COIN_ARC, COIN_RAIN, SPARK }

const CELL := ArtStyle.ART_SCALE
## The stage, the monitor's bezel and its paper, in stage px.
const STAGE_RECT := Rect2(Vector2.ZERO, ShiftStage.SIZE)
const BEZEL_RECT := ShiftStage.MONITOR_RECT
const PAPER_RECT := MonitorView.PAPER_RECT
## Art px per second per second.
const GRAVITY := 320.0
## A falling drop on the bezel splashes at LAND_RATE per second; one that falls past
## DROP_FLOOR (art px, plus up to DROP_FLOOR_SPREAD) goes.
const LAND_RATE := 4.5
const DROP_FLOOR := 150.0
const DROP_FLOOR_SPREAD := 40.0
## The coins' rest on the belt's top face (art px, y from x to y: stage 384 to 392), their
## bounces (BOUNCE of the speed back up, SLIDE of the sideways speed kept, at most BOUNCES, or
## until slower than SETTLE_SPEED), their spin (frames per second) and their rest: a glint for
## GLINT_S, blinking at BLINK_HZ from BLINK_FROM_S, gone at REST_S.
const COIN_REST := Vector2(192, 196)
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
## A jet's width at its foot (art px; it narrows by 2 each quarter of its height) and its crown.
const JET_WIDTH := 10
const JET_CROWN := 7
## The burst's jets (height in art px, seconds, delay) and the spurt's (height JET_SPURT plus a
## euro per JET_SPURT_PER_EURO).
const BURST_JETS: Array[Vector3] = [Vector3(78, 0.7, 0.0), Vector3(52, 0.55, 0.5)]
const JET_SPURT := 24.0
const JET_SPURT_PER_EURO := 4.0
const JET_SPURT_S := 0.4
## A spurt's SPURT_SPARKS sparks, over its first SPURT_SPARK_S.
const SPURT_SPARKS := 6.0
const SPURT_SPARK_S := 0.05
## The pour: POUR_MIN drops plus one per POUR_PER_EURO, up to POUR_MAX, POUR_STAGGER apart, each
## over POUR_S on an arc of POUR_ARC art px, leaving up to POUR_FROM_SPREAD art px either side of
## the pour point and landing up to POUR_TO_SPREAD either side of the €'s middle. A payout past the
## quota spurts (and punches the "+€N" tab) as its pour lands, POUR_S after its chip.
const POUR_MIN := 5
const POUR_MAX := 8
const POUR_PER_EURO := 3.0
const POUR_STAGGER := 0.012
const POUR_S := 0.2
const POUR_ARC := Vector2(7, 10)
const POUR_FROM_SPREAD := 0.5
const POUR_TO_SPREAD := 1.5
## A flying coin past COIN_EDGE art px inside the bezel's right edge, while within the bezel's
## height, turns back, keeping COIN_EDGE_BOUNCE of its speed (the € sits near the paper's right
## edge); above or below the monitor there is nothing to turn it.
const COIN_EDGE := 8.0
const COIN_EDGE_BOUNCE := 0.6
## The pour leaves POUR_LIFT px over the digits' ink, in the gap before the € (pour_point); it
## lands EURO_SURFACE px (scaled with a punch) under the €'s top (euro_surface).
const POUR_LIFT := 4.0
const EURO_SURFACE := 12.0
const SPARK_LIFE := Vector2(0.5, 0.9)
const SPARK_BLINK_HZ := 20.0
## The burst's shake of the monitor (px, seconds), and the shake's swing rates.
const BURST_SHAKE := 6.0
const BURST_SHAKE_S := 0.5
const SHAKE_X_RATE := 91.0
const SHAKE_Y_RATE := 77.0
const SHAKE_Y_SHARE := 0.7
const RANDOM_SEED := 7
const GOLD_LIGHT := Palette.MUSTARD_LIGHT
const GOLD := Palette.MUSTARD
const GOLD_DARK := Palette.MUSTARD_DARK
const GOLD_PALE := Palette.MUSTARD_PALE
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

## The LED whose € the gold leaves from (euro_top, euro_surface).
var _euro: LedDisplay
var _shake_target: Control
## The shake target's position at rest, and the shake's offset now (stage px).
var _rest: Vector2 = Vector2.ZERO
var _offset: Vector2 = Vector2.ZERO
## Real seconds since the layer started.
var _time: float = 0.0
var _drops: Array[Drop] = []
var _sparks: Array[Spark] = []
var _coins: Array[Coin] = []
var _splashes: Array[Splash] = []
var _jets: Array[Jet] = []
var _pours: Array[Pour] = []
var _emitters: Array[Emitter] = []
## Each shake: (start, px, seconds).
var _shakes: Array[Vector3] = []
var _random: RandomNumberGenerator = RandomNumberGenerator.new()
## While drawn_rects() runs: the pieces painted, by layer, instead of drawing them.
var _recording: bool = false
var _recorded: Dictionary[Layer, Array] = {}


## A gold drop (art px): falls under GRAVITY; `lands` drops splash on the bezel.
class Drop:
	extends RefCounted
	var at: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var life: float = 0.0
	var colour: Color = Palette.MUSTARD
	var cells: int = 1


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


class Jet:
	extends RefCounted
	var start: float = 0.0
	var seconds: float = 0.0
	var height: float = 0.0


class Pour:
	extends RefCounted
	var start: float = 0.0
	var from: Vector2 = Vector2.ZERO
	var arc: float = 0.0
	var spread: float = 0.0


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


## The LED whose € the gold comes out of, and the control the shakes move (the monitor).
func bind(led: LedDisplay, shake_target: Control) -> void:
	_euro = led
	_shake_target = shake_target


## Where `led`'s pour leaves (global): in the gap before its €, POUR_LIFT px over its digits' ink.
static func pour_point(led: LedDisplay) -> Vector2:
	var digits: Rect2 = led.digits_text_rect()
	var euro: Rect2 = led.euro_text_rect()
	return Vector2((digits.end.x + euro.position.x) / 2.0, digits.position.y - POUR_LIFT)


## The top centre of `led`'s € (global), where the burst's jets, drops and coins leave.
static func euro_top(led: LedDisplay) -> Vector2:
	var euro: Rect2 = led.euro_text_rect()
	return Vector2(euro.get_center().x, euro.position.y)


## Where the pour lands (global): EURO_SURFACE px (scaled with a punch) under `led`'s €'s top.
static func euro_surface(led: LedDisplay) -> Vector2:
	var scale_y: float = led.euro_label().get_global_transform().get_scale().y
	return euro_top(led) + Vector2(0.0, EURO_SURFACE * scale_y)


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
	shake(BURST_SHAKE, BURST_SHAKE_S)
	for jet: Vector3 in BURST_JETS:
		_add_jet(jet.x, jet.y, jet.z)
	_emit(Kind.GEYSER, 0.0, 0.55, 300.0, 1.05)
	_emit(Kind.GEYSER, 0.5, 0.45, 220.0, 0.85)
	_emit(Kind.SPLASH, 0.1, 0.5, 56.0, 1.0)
	_emit(Kind.COIN_ARC, 0.0, 0.35, 50.0, 1.0)
	_emit(Kind.COIN_RAIN, 0.15, 0.9, 30.0, 1.0)
	for _index: int in range(14):
		_spawn(Kind.SPARK, 1.0)
	queue_redraw()


## A payout past the quota (`amount` euros), `delay` s from now: a smaller jet, drops, coins,
## splashes and sparks.
func spurt(amount: int, delay: float = 0.0) -> void:
	if _reduced():
		return
	_add_jet(JET_SPURT + amount / JET_SPURT_PER_EURO, JET_SPURT_S, delay)
	_emit(Kind.GEYSER, delay, 0.25, 90.0, 0.7)
	_emit(Kind.COIN_ARC, delay, 0.2, 20.0, 0.75)
	_emit(Kind.SPLASH, delay + 0.1, 0.2, 25.0, 1.0)
	_emit(Kind.SPARK, delay, SPURT_SPARK_S, SPURT_SPARKS / SPURT_SPARK_S, 1.0)
	queue_redraw()


## A payout of `amount` euros pours from `from` (global: the gap before the €,
## pour_point) into the €, the drops landing where it is as they arrive.
func pour(from: Vector2, amount: int) -> void:
	if _reduced() or _euro == null:
		return
	var start: Vector2 = _art_point(from)
	var drops: int = mini(POUR_MAX, POUR_MIN + roundi(amount / POUR_PER_EURO))
	for index: int in range(drops):
		var drop: Pour = Pour.new()
		drop.start = _time + index * POUR_STAGGER
		drop.from = start + Vector2(_random.randf_range(-POUR_FROM_SPREAD, POUR_FROM_SPREAD), 0.0)
		drop.arc = _random.randf_range(POUR_ARC.x, POUR_ARC.y)
		drop.spread = _random.randf_range(-POUR_TO_SPREAD, POUR_TO_SPREAD)
		_pours.append(drop)
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
	_sparks.clear()
	_coins.clear()
	_splashes.clear()
	_jets.clear()
	_pours.clear()
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
	var jets: Array[Jet] = []
	for jet: Jet in _jets:
		if _time - jet.start < jet.seconds:
			jets.append(jet)
	_jets = jets
	var pours: Array[Pour] = []
	for drop: Pour in _pours:
		if _time - drop.start < POUR_S:
			pours.append(drop)
	_pours = pours
	_move_shake()
	queue_redraw()


## Whether anything is moving or showing (a still splash included).
func is_active() -> bool:
	return not (
		_drops.is_empty()
		and _sparks.is_empty()
		and _coins.is_empty()
		and _splashes.is_empty()
		and _jets.is_empty()
		and _pours.is_empty()
		and _emitters.is_empty()
		and _shakes.is_empty()
	)


## The rects (stage px, the layer's coordinates) that `layer`'s drawing covers now, cut as drawn.
func drawn_rects(layer: Layer) -> Array[Rect2]:
	_recording = true
	_recorded = {Layer.PARTICLES: [], Layer.SPLASHES: [], Layer.POUR: []}
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
		and _sparks.is_empty()
		and _coins.is_empty()
		and _jets.is_empty()
		and _pours.is_empty()
		and _emitters.is_empty()
		and _shakes.is_empty()
	)


func _draw() -> void:
	_paint()


## Draws (or, for drawn_rects, records) everything: the splashes, the drops and sparks, the jets,
## the pour and the coins.
func _paint() -> void:
	for splash: Splash in _splashes:
		_paint_splash(splash)
	for drop: Drop in _drops:
		var tall: int = drop.cells + (1 if drop.velocity.y > 60.0 else 0)
		_fill(drop.at, Vector2(drop.cells, tall), drop.colour, Layer.PARTICLES)
	for spark: Spark in _sparks:
		var fading: bool = spark.life / spark.span <= 0.25
		if not fading or int(_time * SPARK_BLINK_HZ) % 2 == 1:
			_blit(_texture("spark"), spark.at - Vector2(2, 2), Layer.PARTICLES)
	for jet: Jet in _jets:
		_paint_jet(jet)
	for drop: Pour in _pours:
		_paint_pour(drop)
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


## A jet out of the €'s top: it rises fast, holds, then sinks; ink-edged gold rows with a light
## stripe and paper glints, a crown of blobs on top.
func _paint_jet(jet: Jet) -> void:
	if _euro == null:
		return
	var progress: float = (_time - jet.start) / jet.seconds
	if progress < 0.0:
		return
	var rise: float = sin(minf(1.0, progress * 2.6) * PI / 2.0)
	var sink: float = 1.0 if progress < 0.55 else 1.0 - (progress - 0.55) / 0.45
	var tall: float = jet.height * rise * sink
	var top: Vector2 = _art_point(euro_top(_euro))
	var quarter: float = maxf(1.0, jet.height / 4.0)
	for row: int in range(ceili(tall)):
		var y: float = top.y + 3.0 - row
		var wobble: int = roundi(sin(row * 0.35 - _time * 30.0) * 1.2)
		var width: int = JET_WIDTH - mini(5, floori(row / quarter) * 2)
		var x: float = roundf(top.x - width / 2.0) + wobble
		_fill(Vector2(x - 1, y), Vector2(width + 2, 1), INK, Layer.PARTICLES)
		_fill(Vector2(x, y), Vector2(width, 1), GOLD, Layer.PARTICLES)
		_fill(Vector2(x + 1, y), Vector2(maxi(1, width - 4), 1), GOLD_LIGHT, Layer.PARTICLES)
		_fill(Vector2(x + width - 2, y), Vector2(1, 1), GOLD_DARK, Layer.PARTICLES)
		if (row + floori(_time * 40.0)) % 6 == 0:
			_fill(Vector2(x + 2, y), Vector2(1, 2), GLINT, Layer.PARTICLES)
	var crown: float = top.y + 3.0 - tall
	for index: int in range(JET_CROWN):
		var radius: int = 3 if index < 3 else 2
		var at: Vector2 = Vector2(
			roundf(top.x + sin(index * 2.3 + _time * 20.0) * 6.0),
			roundf(crown + cos(index * 1.7 + _time * 17.0) * 3.0)
		)
		_blit(_texture("blob%d" % radius), at - Vector2(radius, radius), Layer.PARTICLES)


## A pour drop on its arc from the gap before the € into the € (where it is now).
func _paint_pour(drop: Pour) -> void:
	var along: float = (_time - drop.start) / POUR_S
	if along < 0.0 or _euro == null:
		return
	var top: Vector2 = _art_point(euro_top(_euro))
	var to: Vector2 = Vector2(top.x + drop.spread, _art_point(euro_surface(_euro)).y)
	var at: Vector2 = drop.from.lerp(to, along) - Vector2(0.0, sin(along * PI) * drop.arc)
	at = at.round()
	_fill(at + Vector2(-2, -1), Vector2(4, 4), INK, Layer.POUR)
	_fill(at + Vector2(-1, -2), Vector2(2, 6), INK, Layer.POUR)
	_fill(at + Vector2(-1, 0), Vector2(2, 2), GOLD, Layer.POUR)
	_fill(at + Vector2(-1, -1), Vector2(2, 1), GOLD_LIGHT, Layer.POUR)
	_fill(at + Vector2(0, 1), Vector2(1, 1), GOLD_DARK, Layer.POUR)


## A coin spinning in the air, or flat at rest with its shadow (a glint as it lands, a blink
## before it goes).
func _paint_coin(coin: Coin) -> void:
	var at: Vector2 = coin.at.round()
	if coin.rest_at < 0.0:
		var frame: int = COIN_FRAMES[floori(coin.phase) % COIN_FRAMES.size()]
		var texture: Texture2D = _texture("coin%d" % frame)
		_blit(texture, at - Vector2(floorf(texture.get_width() / 2.0), 4), Layer.PARTICLES)
		return
	var resting: float = _time - coin.rest_at
	if resting > COIN_BLINK_FROM_S and int(resting * COIN_BLINK_HZ) % 2 == 1:
		return
	if resting < COIN_GLINT_S:
		_blit(_texture("spark"), at - Vector2(2, 8), Layer.PARTICLES)
	var shadow: Color = Color(COIN_SHADOW, COIN_SHADOW_ALPHA)
	_fill(at + Vector2(-3, 1), Vector2(8, 2), shadow, Layer.PARTICLES)
	_blit(_texture("flat"), at - Vector2(4, 2), Layer.PARTICLES)


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
## pieces round it). The particles and the pour cross the paper.
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


func _add_jet(height: float, seconds: float, delay: float) -> void:
	var jet: Jet = Jet.new()
	jet.start = _time + delay
	jet.seconds = seconds
	jet.height = height
	_jets.append(jet)


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
	var top: Vector2 = _art_point(euro_top(_euro)) if _euro != null else _bezel().get_center()
	match kind:
		Kind.GEYSER:
			var drop: Drop = Drop.new()
			drop.at = top + Vector2(_random.randf_range(-5.0, 5.0), 2.0)
			# Up and to both sides (the € sits near the monitor's right edge).
			var sideways: float = (
				(_random.randf() - 0.55) * 40.0
				if power < 0.9
				else (_random.randf() - 0.6) * 90.0 * power
			)
			drop.velocity = Vector2(sideways, -(95.0 + _random.randf() * 110.0) * power)
			drop.life = 3.0
			var pick: float = _random.randf()
			drop.colour = GLINT if pick < 0.3 else (GOLD_LIGHT if pick < 0.6 else GOLD)
			drop.cells = 2 if _random.randf() < 0.4 else 1
			_drops.append(drop)
		Kind.SPLASH:
			_spawn_splash(power)
		Kind.COIN_ARC:
			var arc: Coin = _new_coin(top + Vector2(_random.randf_range(-4.0, 4.0), 0.0))
			arc.velocity = Vector2(
				(_random.randf() - 0.6) * 60.0 if power < 0.9 else (_random.randf() - 0.58) * 150.0,
				-(110.0 + _random.randf() * 80.0) * power
			)
		Kind.COIN_RAIN:
			var bezel: Rect2 = _bezel()
			var from: Vector2 = Vector2(
				bezel.position.x + 10.0 + _random.randf() * (bezel.size.x - 20.0), bezel.end.y - 2.0
			)
			var rain: Coin = _new_coin(from)
			rain.velocity = Vector2(_random.randf_range(-18.0, 12.0), 10.0 + _random.randf() * 50.0)
		Kind.SPARK:
			_spawn_spark()


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


## Drops fall; a falling one goes on reaching the paper (it lands on the screen), splashes on the
## bezel at LAND_RATE, and goes past the floor.
func _move_drops(delta: float) -> void:
	var bezel: Rect2 = _bezel()
	var paper: Rect2 = Rect2(PAPER_RECT.position / CELL, PAPER_RECT.size / CELL)
	var kept: Array[Drop] = []
	for drop: Drop in _drops:
		drop.life -= delta
		if drop.life <= 0.0:
			continue
		drop.at += drop.velocity * delta
		drop.velocity.y += GRAVITY * delta
		if drop.velocity.y > 0.0:
			if paper.has_point(drop.at):
				continue
			var chance: float = 1.0 - exp(-delta * LAND_RATE)
			if bezel.has_point(drop.at) and _random.randf() < chance:
				var radius: int = (
					2 + roundi(_random.randf() * 2.0)
					if drop.cells > 1
					else 1 + roundi(_random.randf())
				)
				var drip: float = 4.0 + _random.randf() * 14.0 if _random.randf() < 0.5 else 0.0
				_add_splash(drop.at, radius, drip)
				continue
		if drop.at.y > DROP_FLOOR + _random.randf() * DROP_FLOOR_SPREAD:
			continue
		kept.append(drop)
	_drops = kept


## Coins fly (the monitor's right edge turning them back beside it), bounce on the belt's face
## and rest there, going REST_S after.
func _move_coins(delta: float) -> void:
	var bezel: Rect2 = _bezel()
	var edge: float = bezel.end.x - COIN_EDGE
	var kept: Array[Coin] = []
	for coin: Coin in _coins:
		if coin.rest_at < 0.0:
			coin.at += coin.velocity * delta
			coin.velocity.y += GRAVITY * delta
			coin.phase += delta * COIN_SPIN
			var beside: bool = coin.at.y >= bezel.position.y and coin.at.y <= bezel.end.y
			if beside and coin.at.x > edge and coin.velocity.x > 0.0:
				coin.velocity.x = -coin.velocity.x * COIN_EDGE_BOUNCE
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
