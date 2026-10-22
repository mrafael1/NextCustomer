class_name MetStamp
extends Control
## The SPEND MET stamp (#86 v6 scan count-up, mock-up count_up_86_v6_scan.html): at the quota it
## replaces the line under the count's digits (LedBeat, its host). "SPEND MET" in the display font
## with a drawn check (the fonts have no ✓), dark green on paper inside a BORDER-wide dark green
## border and a RING-wide ring RING_GAP outside it, turned TILT_DEG about its centre. slam() drops
## it from SLAM_FROM through SLAM_UNDER to its size with a small puff of dust at the impact
## (`landed`, for the monitor's shake); it runs on its own real-time tween, as the count-up's
## quota hold freezes the count's. show_static() shows it at once (reduced motion, a resumed
## checkout). Decor only: it takes no clicks.

## The slam lands (its scale through SLAM_UNDER): the dust puffs.
signal landed
## It shows (slam, show_static) or hides (hide_stamp).
signal showing_changed(showing: bool)

const TEXT := "SPEND MET"
## Its rect's size (the border included; the ring and the dust are drawn outside it).
const SIZE := Vector2(156, 30)
const BORDER := 3
const RING := 2
const RING_GAP := 2
const FONT_SIZE := 17
const SPACING := 1
const TILT_DEG := -4.0
const INK_COLOR := Palette.GREEN_DARK
const FACE_COLOR := Palette.PAPER
## The check after the text: EffectSticker's cells, CHECK_CELL px each, CHECK_GAP px after the
## text.
const CHECK_CELL := 2.0
const CHECK_GAP := 6.0
const CHECK_SIZE := Vector2(16, 14)
## The slam: from SLAM_FROM (turned SLAM_TILT_FROM, fading in) to SLAM_UNDER over SLAM_IN_S, then
## to 1 over SLAM_SETTLE_S.
const SLAM_FROM := 3.0
const SLAM_UNDER := 0.92
const SLAM_TILT_FROM := -12.0
const SLAM_IN_S := 0.1
const SLAM_SETTLE_S := 0.12
## The dust: DUST specks on an ellipse DUST_RING round the stamp's centre, flying out at up to
## DUST_SPEED px per second and slowing at DUST_DRAG per second, each living DUST_LIFE seconds;
## DUST_SPECK px square.
const DUST := 18
const DUST_RING := Vector2(80, 16)
const DUST_SPEED := Vector2(80, 36)
const DUST_DRAG := 6.0
const DUST_LIFE := Vector2(0.3, 0.5)
const DUST_SPECK := 2.0
const DUST_COLORS: Array[Color] = [Palette.PAPER, Palette.GREEN_LIGHT]
const RANDOM_SEED := 86

var _face: Control
var _label: Label
var _showing: bool = false
var _slam: Tween
## Dust specks: position, velocity, life left and colour.
var _dust: Array[Dictionary] = []
var _random: RandomNumberGenerator = RandomNumberGenerator.new()


func _init() -> void:
	name = "MetStamp"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	visible = false
	_random.seed = RANDOM_SEED
	_face = Control.new()
	_face.name = "Face"
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.size = SIZE
	_face.pivot_offset = SIZE / 2.0
	_face.rotation_degrees = TILT_DEG
	_face.draw.connect(_draw_face)
	add_child(_face)
	_label = UiKit.display_label(TEXT, FONT_SIZE, false)
	_label.add_theme_font_override("font", ArtStyle.spaced_display_font(SPACING))
	_label.add_theme_color_override("font_color", INK_COLOR)
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_face.add_child(_label)
	_lay_out()


func _ready() -> void:
	_lay_out()


## Slams the stamp down (see the class comment), on its own real-time tween; under
## `reduced_motion` (or out of the tree) it shows at once (show_static).
func slam(reduced_motion: bool) -> void:
	if reduced_motion or not is_inside_tree():
		show_static()
		return
	_stop()
	_set_showing(true)
	_face.scale = Vector2.ONE * SLAM_FROM
	_face.rotation_degrees = SLAM_TILT_FROM
	_face.modulate.a = 0.0
	_slam = create_tween()
	_slam.set_parallel(true)
	_slam.tween_property(_face, "scale", Vector2.ONE * SLAM_UNDER, SLAM_IN_S)
	_slam.tween_property(_face, "rotation_degrees", TILT_DEG, SLAM_IN_S)
	_slam.tween_property(_face, "modulate:a", 1.0, SLAM_IN_S)
	_slam.chain().tween_callback(_impact)
	_slam.chain().tween_property(_face, "scale", Vector2.ONE, SLAM_SETTLE_S)


## Shows the stamp at rest at once, with no dust.
func show_static() -> void:
	_stop()
	_set_showing(true)


## Takes the stamp off (a new count).
func hide_stamp() -> void:
	_stop()
	_set_showing(false)


func is_showing() -> bool:
	return _showing


## Whether the slam is still moving.
func is_slamming() -> bool:
	return _slam != null and _slam.is_valid() and _slam.is_running()


## Whether dust is in the air.
func has_dust() -> bool:
	return not _dust.is_empty()


## Where the stamp is drawn at rest (global): its rect grown by its ring, turned TILT_DEG about
## its centre, as the axis-aligned rect round it.
func drawn_rect() -> Rect2:
	var outer: Rect2 = Rect2(Vector2.ZERO, SIZE).grow(RING_GAP + RING)
	var centre: Vector2 = SIZE / 2.0
	var corners: Array[Vector2] = [
		outer.position,
		Vector2(outer.end.x, outer.position.y),
		outer.end,
		Vector2(outer.position.x, outer.end.y),
	]
	var bounds: Rect2 = Rect2(centre, Vector2.ZERO)
	for corner: Vector2 in corners:
		bounds = bounds.expand(centre + (corner - centre).rotated(deg_to_rad(TILT_DEG)))
	var to_global: Transform2D = get_global_transform()
	return Rect2(to_global * bounds.position, bounds.size * to_global.get_scale())


## The text's label (for tests).
func label() -> Label:
	return _label


func _process(delta: float) -> void:
	if _dust.is_empty():
		return
	var kept: Array[Dictionary] = []
	for speck: Dictionary in _dust:
		var life: float = speck["life"]
		life -= delta
		if life <= 0.0:
			continue
		var velocity: Vector2 = speck["velocity"]
		var at: Vector2 = speck["at"]
		speck["at"] = at + velocity * delta
		speck["velocity"] = velocity * exp(-DUST_DRAG * delta)
		speck["life"] = life
		kept.append(speck)
	_dust = kept
	queue_redraw()


func _draw() -> void:
	for speck: Dictionary in _dust:
		var at: Vector2 = speck["at"]
		var colour: Color = speck["colour"]
		var cell: Vector2 = (at / DUST_SPECK).floor() * DUST_SPECK
		draw_rect(Rect2(cell, Vector2.ONE * DUST_SPECK), colour)


## The face: the ring, the border and the paper inside, and the check after the text.
func _draw_face() -> void:
	var rect: Rect2 = Rect2(Vector2.ZERO, SIZE)
	var outer: Rect2 = rect.grow(RING_GAP + RING)
	var inner: Rect2 = rect.grow(RING_GAP)
	_face.draw_rect(Rect2(outer.position, Vector2(outer.size.x, RING)), INK_COLOR)
	_face.draw_rect(Rect2(outer.position.x, inner.end.y, outer.size.x, RING), INK_COLOR)
	_face.draw_rect(Rect2(outer.position.x, inner.position.y, RING, inner.size.y), INK_COLOR)
	_face.draw_rect(Rect2(inner.end.x, inner.position.y, RING, inner.size.y), INK_COLOR)
	_face.draw_rect(rect, INK_COLOR)
	_face.draw_rect(rect.grow(-BORDER), FACE_COLOR)
	var origin: Vector2 = _check_origin()
	for at: Vector2i in EffectSticker.CHECK_CELLS:
		var cell: Rect2 = Rect2(origin + Vector2(at) * CHECK_CELL, Vector2.ONE * CHECK_CELL)
		_face.draw_rect(cell, INK_COLOR)


## The check's top left: after the text, the two centred together on the face.
func _check_origin() -> Vector2:
	var text_end: float = _label.position.x + _text_width()
	return Vector2(text_end + CHECK_GAP, roundf((SIZE.y - CHECK_SIZE.y) / 2.0))


## The text and the check centred on the face (measured in the tree: out of it a label measures
## with the default font size).
func _lay_out() -> void:
	var width: float = _text_width() + CHECK_GAP + CHECK_SIZE.x
	_label.position = Vector2(roundf((SIZE.x - width) / 2.0), 0.0)
	_label.size = Vector2(_text_width(), SIZE.y)
	_face.queue_redraw()


func _text_width() -> float:
	var font: Font = _label.get_theme_font("font")
	var font_size: int = _label.get_theme_font_size("font_size")
	return font.get_string_size(TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## The slam's impact: the dust puffs and `landed` says so.
func _impact() -> void:
	var centre: Vector2 = SIZE / 2.0
	for _index: int in range(DUST):
		var angle: float = _random.randf() * TAU
		var direction: Vector2 = Vector2(cos(angle), sin(angle))
		(
			_dust
			. append(
				{
					"at": centre + direction * DUST_RING,
					"velocity": direction * DUST_SPEED,
					"life": _random.randf_range(DUST_LIFE.x, DUST_LIFE.y),
					"colour": DUST_COLORS[_random.randi_range(0, DUST_COLORS.size() - 1)],
				}
			)
		)
	queue_redraw()
	landed.emit()


## Stops the slam and the dust, the face at rest.
func _stop() -> void:
	if _slam != null:
		_slam.kill()
		_slam = null
	_dust.clear()
	_face.scale = Vector2.ONE
	_face.rotation_degrees = TILT_DEG
	_face.modulate.a = 1.0
	queue_redraw()


func _set_showing(showing: bool) -> void:
	visible = showing
	if showing == _showing:
		return
	_showing = showing
	showing_changed.emit(showing)
