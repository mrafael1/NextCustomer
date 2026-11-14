class_name BeatenStamp
extends Control
## The receipt's QUOTA MET stamp (was BEATEN! until v1.33; main scene v2, the user's pick H2 of
## 2026-11-08: mock-up docs/art/mockups/main_scene_v2.html, its stamp()): at the quota crossing it
## slams onto the header's MEET THE QUOTA words, unrotated and on the art's grid. A green-dark frame
## one font cell thick, paper inside, WORD in the chunky capitals two cells from its top; at least
## MIN_WIDTH wide (the header's words), 8 cells wider than its word. It slams in at SLAM_CELL (twice
## its size) for SLAM_MS, settles DROP px lower until DROP_MS, then rests at CELL; four paper
## sparkles step out from its corners every SPARKLE_STEP_MS until SPARKLE_END_MS. Under reduced
## motion it shows settled at once. Placed by ReceiptTarget (`centre`, head coordinates). Display
## only.

const WORD := "QUOTA MET"
const CELL := 2.0
const SLAM_CELL := 4.0
## The frame is this many cells wider than the word, and this many cells taller than a glyph.
const WIDTH_CELLS := 8.0
const HEIGHT_CELLS := 12.0
const WORD_TOP_CELLS := 2.0
const MIN_WIDTH := 216.0
const INK := Palette.GREEN_DARK
const FACE := Palette.PAPER
const SLAM_MS := 70
const DROP_MS := 140
const DROP := 2.0
const SPARKLE_END_MS := 300
const SPARKLE_STEP_MS := 60
const SPARKLE_SIZE := 4.0
## Each sparkle step moves them this far out, past the frame's corners (SPARKLE_GAP).
const SPARKLE_STEP := Vector2(6, 4)
const SPARKLE_GAP := Vector2(4, 2)

## Where its middle stands (its parent's coordinates).
var centre: Vector2 = Vector2.ZERO
## The cell it is drawn at now, and the slam's drop.
var cell: float = CELL
var drop: float = 0.0
## The sparkles' step (-1: none).
var sparkle: int = -1
var word: PixelWords
var _tween: Tween


func _init() -> void:
	name = "Beaten"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	word = PixelWords.new(WORD, PixelWords.Sheet.CHUNKY_CAPS, CELL, INK)
	word.name = "Word"
	add_child(word)


## Shows it: slamming in (`pop`, unless `still`), else settled at once.
func stamp(pop: bool, still: bool) -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	visible = true
	if not pop or still or not is_inside_tree():
		_set_state(CELL, 0.0, -1)
		return
	_set_state(SLAM_CELL, 0.0, -1)
	_tween = create_tween()
	_tween.tween_interval(SLAM_MS / 1000.0)
	_tween.tween_callback(_set_state.bind(CELL, DROP, 0))
	var at: int = SLAM_MS
	for step: int in range(1, ceili(float(SPARKLE_END_MS - SLAM_MS) / SPARKLE_STEP_MS)):
		var next: int = SLAM_MS + step * SPARKLE_STEP_MS
		_tween.tween_interval((next - at) / 1000.0)
		_tween.tween_callback(_set_state.bind(CELL, DROP if next < DROP_MS else 0.0, step))
		at = next
	_tween.tween_interval((SPARKLE_END_MS - at) / 1000.0)
	_tween.tween_callback(_set_state.bind(CELL, 0.0, -1))


## Takes it off (a new shift's planning).
func clear() -> void:
	if _tween != null:
		_tween.kill()
		_tween = null
	visible = false
	_set_state(CELL, 0.0, -1)


## Whether it is at rest (settled, no sparkles).
func settled() -> bool:
	return visible and cell == CELL and drop == 0.0 and sparkle < 0


## The frame's size at `at_cell`.
static func frame_size(at_cell: float) -> Vector2:
	var words: Vector2 = PixelWords.text_size(WORD, PixelWords.Sheet.CHUNKY_CAPS, at_cell)
	var width: float = maxf(words.x + WIDTH_CELLS * at_cell, MIN_WIDTH + (at_cell - CELL) * 8.0)
	return Vector2(_even(width), HEIGHT_CELLS * at_cell)


func _set_state(at_cell: float, at_drop: float, at_sparkle: int) -> void:
	cell = at_cell
	drop = at_drop
	sparkle = at_sparkle
	var frame: Vector2 = frame_size(cell)
	size = frame
	position = Vector2(_even(centre.x - frame.x / 2.0), _even(centre.y - frame.y / 2.0) + drop)
	word.cell = cell
	word.size = word.get_combined_minimum_size()
	word.position = Vector2(_even((frame.x - word.size.x) / 2.0), WORD_TOP_CELLS * cell)
	queue_redraw()


func _draw() -> void:
	var frame: Vector2 = frame_size(cell)
	draw_rect(Rect2(Vector2.ZERO, frame), INK)
	draw_rect(Rect2(Vector2(cell, cell), frame - Vector2(cell, cell) * 2.0), FACE)
	if sparkle < 0:
		return
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var out: Vector2 = SPARKLE_GAP + SPARKLE_STEP * sparkle
		var middle: Vector2 = frame / 2.0 + corner * (frame / 2.0 + out)
		var square: Vector2 = Vector2.ONE * SPARKLE_SIZE
		draw_rect(Rect2((middle - square / 2.0).round(), square), FACE)


static func _even(x: float) -> float:
	return roundf(x / 2.0) * 2.0
