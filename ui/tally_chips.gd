class_name TallyChips
extends Control
## The bay's gold chips (#86 round 7, mock-up count_up_86_v7_bay.html's TALLY): a layer over the
## monitor (MonitorView's top layer, under the bay's tag), taking no clicks. Each payout sends one
## "+€N" chip (ReceiptFly.amount_text: the payout's own amount) from the tag into the number: it
## slides out from behind the tag's right end (START_RIGHT), flies on a smoothstep path with an ARC
## px hump, turning from TILT_FROM to level and shrinking from SCALE_FROM to SCALE_TO, on
## make_tween's tweens (the count-up's, so it follows the taps, holds and hit-stops). It lands
## (landed) with a SPARK_GLYPH spark and a ring of DUST gold and paper specks, which run in real
## time. Drawn in code: a gold box with a BORDER px ink border and a mustard-dark shadow. The
## monitor sends no chip under reduced motion. Display only.

## A chip (fly()'s id) landed with `amount`.
signal landed(amount: int, chip: int)

const HEIGHT := 22.0
const PAD_X := 5.0
const BORDER := 2.0
const SHADOW := Vector2(2, 2)
const FONT_SIZE := 14
const WEIGHT := 800
## The chip's right edge starts this far right of where it is sent from.
const START_RIGHT := 8.0
const ARC := 22.0
const TILT_FROM := -8.0
const SCALE_FROM := 1.15
const SCALE_TO := 0.75
## The landing: the spark for SPARK_S (blinking at SPARK_BLINK_HZ over its last quarter), and DUST
## specks of DUST_SIZE px flying out at DUST_SPEED px per second (slowed by DUST_DRAG per second)
## for DUST_S.
const SPARK_S := 0.3
const SPARK_BLINK_FROM := 0.75
const SPARK_BLINK_HZ := 16.0
const SPARK_GLYPH: Array[String] = ["..y..", "..y..", "yywyy", "..y..", "..y.."]
const DUST := 10
const DUST_SPEED := Vector2(110, 60)
const DUST_DRAG := 6.3
const DUST_S := 0.25
const DUST_SIZE := 2.0
const FACE_COLOR := Palette.GOLD
const INK_COLOR := Palette.INK
const SHADOW_COLOR := Palette.MUSTARD_DARK
const SPARK_COLOR := Palette.MUSTARD_LIGHT
const SPARK_GLINT := Palette.PAPER
const DUST_COLOURS: Array[Color] = [Palette.PAPER, Palette.GOLD]

## Returns a new tween on the count-up's clock; none means the layer's own.
var make_tween: Callable = Callable()

var _chips: Array[Chip] = []
var _specks: Array[Speck] = []
## The landing sparks: where (local) and how old (s).
var _sparks: Array[Vector3] = []
var _next_id: int = 0


## A chip in flight (local coordinates).
class Chip:
	extends RefCounted
	var id: int = 0
	var amount: int = 0
	var text: String = ""
	var width: float = 0.0
	var start: Vector2 = Vector2.ZERO
	var to: Vector2 = Vector2.ZERO
	var progress: float = 0.0
	var tween: Tween


## A speck of the landing's dust.
class Speck:
	extends RefCounted
	var at: Vector2 = Vector2.ZERO
	var velocity: Vector2 = Vector2.ZERO
	var age: float = 0.0
	var colour: Color = Color()


func _init() -> void:
	name = "TallyChips"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if _specks.is_empty() and _sparks.is_empty():
		return
	var specks: Array[Speck] = []
	for speck: Speck in _specks:
		speck.age += delta
		speck.at += speck.velocity * delta
		speck.velocity *= exp(-DUST_DRAG * delta)
		if speck.age < DUST_S:
			specks.append(speck)
	_specks = specks
	var sparks: Array[Vector3] = []
	for spark: Vector3 in _sparks:
		if spark.z + delta < SPARK_S:
			sparks.append(Vector3(spark.x, spark.y, spark.z + delta))
	_sparks = sparks
	queue_redraw()


func _draw() -> void:
	for speck: Speck in _specks:
		draw_rect(Rect2(speck.at.round() - Vector2.ONE, Vector2.ONE * DUST_SIZE), speck.colour)
	for spark: Vector3 in _sparks:
		var blinking: bool = spark.z > SPARK_S * SPARK_BLINK_FROM
		if blinking and int(spark.z * SPARK_BLINK_HZ * 2.0) % 2 == 1:
			continue
		_draw_spark(Vector2(spark.x, spark.y))
	var font: Font = ArtStyle.bold_font(WEIGHT)
	for chip: Chip in _chips:
		_draw_chip(chip, font)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Sends a "+€`amount`" chip from `from` (global: its right edge START_RIGHT px right of it) into
## `to` (global: its centre) over `seconds` on the count's clock. Returns its id (landed's).
func fly(amount: int, from: Vector2, to: Vector2, seconds: float) -> int:
	var chip: Chip = Chip.new()
	_next_id += 1
	chip.id = _next_id
	chip.amount = amount
	chip.text = ReceiptFly.amount_text(amount)
	chip.width = chip_width(chip.text)
	var to_local: Transform2D = get_global_transform().affine_inverse()
	chip.start = to_local * from + Vector2(START_RIGHT - chip.width / 2.0, 0.0)
	chip.to = to_local * to
	_chips.append(chip)
	if not is_inside_tree():
		_land(chip)
		return chip.id
	chip.tween = _new_tween()
	chip.tween.tween_method(_move.bind(chip), 0.0, 1.0, maxf(seconds, 0.001))
	chip.tween.tween_callback(_land.bind(chip))
	queue_redraw()
	return chip.id


## Everything goes at once, no chip landing (a new count, planning, a resumed end state).
func clear() -> void:
	for chip: Chip in _chips:
		if chip.tween != null:
			chip.tween.kill()
	_chips.clear()
	_specks.clear()
	_sparks.clear()
	queue_redraw()


## The chips in flight: each one's box (global, its turn aside) at its scale now.
func chip_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var to_global: Transform2D = get_global_transform()
	for chip: Chip in _chips:
		var chip_size: Vector2 = Vector2(chip.width, HEIGHT) * _scale_at(chip.progress)
		var centre: Vector2 = to_global * chip_centre(chip.start, chip.to, chip.progress)
		rects.append(Rect2(centre - chip_size / 2.0, chip_size))
	return rects


## Whether the landing's dust or spark shows.
func has_dust() -> bool:
	return not _specks.is_empty() or not _sparks.is_empty()


## A chip's centre `progress` of the way from `start` to `to`: smoothstep across and down, ARC px
## up at its middle. Pure.
static func chip_centre(start: Vector2, to: Vector2, progress: float) -> Vector2:
	var along: float = clampf(progress, 0.0, 1.0)
	var eased: float = along * along * (3.0 - 2.0 * along)
	return start.lerp(to, eased) - Vector2(0.0, sin(along * PI) * ARC)


## A chip's width for `text`: the text, PAD_X and the border either side.
static func chip_width(text: String) -> float:
	var font: Font = ArtStyle.bold_font(WEIGHT)
	var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	return ceilf(width) + 2.0 * (PAD_X + BORDER)


static func _scale_at(progress: float) -> float:
	return lerpf(SCALE_FROM, SCALE_TO, clampf(progress, 0.0, 1.0))


func _move(progress: float, chip: Chip) -> void:
	chip.progress = progress
	queue_redraw()


## A chip lands: it goes, the spark and the dust start at its end, landed.
func _land(chip: Chip) -> void:
	_chips.erase(chip)
	_sparks.append(Vector3(chip.to.x, chip.to.y, 0.0))
	for index: int in range(DUST):
		var angle: float = TAU * index / DUST
		var speck: Speck = Speck.new()
		speck.at = chip.to
		speck.velocity = Vector2(cos(angle) * DUST_SPEED.x, sin(angle) * DUST_SPEED.y)
		speck.colour = DUST_COLOURS[index % DUST_COLOURS.size()]
		_specks.append(speck)
	queue_redraw()
	landed.emit(chip.amount, chip.id)


## A chip at its place now: shadow, ink, gold and its text, turned and scaled about its centre.
func _draw_chip(chip: Chip, font: Font) -> void:
	var centre: Vector2 = chip_centre(chip.start, chip.to, chip.progress).round()
	var tilt: float = deg_to_rad(lerpf(TILT_FROM, 0.0, clampf(chip.progress, 0.0, 1.0)))
	draw_set_transform(centre, tilt, Vector2.ONE * _scale_at(chip.progress))
	var box: Rect2 = Rect2(Vector2(-chip.width, -HEIGHT) / 2.0, Vector2(chip.width, HEIGHT))
	draw_rect(Rect2(box.position + SHADOW, box.size), SHADOW_COLOR)
	draw_rect(box, INK_COLOR)
	draw_rect(box.grow(-BORDER), FACE_COLOR)
	var ascent: float = font.get_ascent(FONT_SIZE)
	var line: float = ascent + font.get_descent(FONT_SIZE)
	var baseline: float = box.position.y + roundf((HEIGHT - line) / 2.0 + ascent)
	var left: float = box.position.x + BORDER + PAD_X
	draw_string(
		font,
		Vector2(left, baseline),
		chip.text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		FONT_SIZE,
		INK_COLOR
	)


## The landing spark: SPARK_GLYPH at 2x, centred on `at`.
func _draw_spark(at: Vector2) -> void:
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var cell: float = ArtStyle.ART_SCALE
	var origin: Vector2 = at.round() - Vector2.ONE * cell * SPARK_GLYPH.size() / 2.0
	for row: int in range(SPARK_GLYPH.size()):
		for column: int in range(SPARK_GLYPH[row].length()):
			var mark: String = SPARK_GLYPH[row][column]
			if mark == ".":
				continue
			var colour: Color = SPARK_GLINT if mark == "w" else SPARK_COLOR
			draw_rect(Rect2(origin + Vector2(column, row) * cell, Vector2.ONE * cell), colour)


func _new_tween() -> Tween:
	return make_tween.call() as Tween if make_tween.is_valid() else create_tween()
