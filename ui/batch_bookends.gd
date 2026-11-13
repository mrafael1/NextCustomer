class_name BatchBookends
extends Control
## A Bakery batch frame's bookends (2026-11-12, the approved batch_positions mock-up's option A,
## docs/art/mockups/batch_positions.html, with option D's icing drip): the two places a job card
## reads exactly get an end cap on the frame (BatchFrame), a FIRST cap on its left side when the
## frame's first ticket is the batch's first, a LAST cap on its right side when its last ticket is
## the batch's last, each with its word on a plate (a tab) across the frame's foot (the mock-up
## had them on its top band, where the planning rail strips run, so they moved down). A cap is
## INK round a mustard face shaded dark at its sides, a light row near its top and a dark row near
## its foot; it reaches CAP_OUT outside the frame's side and CAP_RISE over its top, down to its
## foot. A glaze on the batch's last item (the Iced bun's ×2, from the score: PlanningModel.glazes)
## pours the icing drip (art/effects/icing_drip.png) over the LAST cap.
##
## Planning (focus: a job card's item hovered): the cap its role reads lights gold with its tab
## (a role WASTED at its place: tomato), a small note beside the tabs under its ticket says why
## ("NOT FIRST", "2 EARLIER", "×2 LAST"); a Baguette's earlier items fill the frame's foot band in
## gold up to its ticket; an Iced bun draws a gold dashed line under the frame's foot from its
## ticket to the LAST cap, and its drip runs
## down again. The frame lit by a BATCH chip turns the caps' faces gold too.
##
## The count (fire, a job card's step landing; BeltRide and the handbook clip call it): an opener
## armed slams the FIRST cap and sends a gold spark (art/effects/batch_spark.png) along the frame to
## the LAST cap, which slams as it lands; a Baguette's bonus fills the foot band to its ticket and
## counts its earlier items in numbered pops; a closer's bonus sends the spark along, counts the
## batch's items and slams the LAST cap; an Iced bun armed draws its dashed line to the LAST cap,
## and its ×2 landing on the last item slams the LAST cap, pops "×2" and runs the drip down again;
## a job card WASTED slams its cap in tomato. A batch split over several frames (a link that skips
## products) plays each beat once: the spark and a cap's slam on the frame showing that cap, the
## dashed line only on the frame showing LAST, the fill and the bagged items' counter on the frame
## holding the job card. A counted item still on the belt pops over its ticket; the bagged ones
## (gone off the frame's left end) tick in one counter at the frame's left end, each number
## replacing the last with a small punch. Every number is the score's. Timings are the mock-up's
## at the count's speed (its tweens: hit-stops and taps move them); reduced motion lights and
## puts back at once, with no slam, spark, fill run or pop. Decor only: it takes no clicks.

enum Look { CALM, LIT, BAD }
enum Cap { FIRST, LAST }

## A cap: CAP_WIDTH wide (CAP_INK ink each side), CAP_OUT outside the frame's side, CAP_RISE over
## its top, down to its foot; its face's columns (CELL wide each) dark (0) or face (1) from the
## left; a CELL light row CAP_ROW_AT under its face's top and a dark row CAP_ROW_AT over its foot,
## CAP_ROW_INSET in from the face's sides.
const CAP_WIDTH := 18.0
const CAP_OUT := 8.0
const CAP_RISE := 6.0
const CAP_INK := 2.0
const CAP_COLUMNS: Array[int] = [0, 1, 1, 1, 1, 0, 0]
const CAP_ROW_AT := 8.0
const CAP_ROW_INSET := 4.0
const CELL := 2.0
## A lit or WASTED cap's glow: rings CELL wide round it, these alphas outwards.
const GLOW_ALPHAS: Array[float] = [0.55, 0.3, 0.12]
## The tabs: plates (ChainFrame.plate_size: PLATE_GLYPH cells, CELL each) from TAB_SINK over the
## frame's foot, TAB_OVERLAP onto their cap; TAB_LIT_SCALE bigger when their cap lights.
const TAB_SINK := 4.0
const TAB_OVERLAP := 4.0
const TAB_LIT_SCALE := 1.2
const FIRST_WORD := "FIRST"
const LAST_WORD := "LAST"
## The plates' letters (PLATE_GLYPH cells, '#' ink); digits and "×" are ChainFrame.PLATE_GLYPHS'.
const LETTERS: Dictionary[String, Array] = {
	"A": [".#.", "#.#", "###", "#.#", "#.#"],
	"E": ["###", "#..", "##.", "#..", "###"],
	"F": ["###", "#..", "##.", "#..", "#.."],
	"I": ["###", ".#.", ".#.", ".#.", "###"],
	"L": ["#..", "#..", "#..", "#..", "###"],
	"N": ["#.#", "###", "###", "#.#", "#.#"],
	"O": ["###", "#.#", "#.#", "#.#", "###"],
	"R": ["##.", "#.#", "##.", "#.#", "#.#"],
	"S": [".##", "#..", ".#.", "..#", "##."],
	"T": ["###", ".#.", ".#.", ".#.", ".#."],
	" ": ["...", "...", "...", "...", "..."],
}
## The planning notes under a job card's ticket, beside the tabs, NOTE_GAP clear of them;
## the count's pops NOTE_GAP over the frame's top (the rail strips are gone in the count).
const NOTE_GAP := 2.0
## A note's top under the frame's foot: clear of the hovered ticket's ring (3 bands of 2 px).
const NOTE_DROP := 6.0
const NOT_FIRST := "NOT FIRST"
const NOT_LAST := "NOT LAST"
const EARLIER := "%d EARLIER"
const GLAZE_LAST := "×%d LAST"
const GLAZE_SELF := "IS LAST"
## The Baguette's fill: on the frame's mustard band, its glow GLOW_ALPHAS[0] a CELL round it.
const FILL_LEFT := BatchFrame.INK_WIDTH
const FILL_UP := BatchFrame.INK_WIDTH + BatchFrame.MUSTARD_WIDTH
const FILL_HEIGHT := BatchFrame.MUSTARD_WIDTH
## The glaze's dashed line DASH_DROP under the frame's foot, DASH_HEIGHT tall, DASH_LENGTH dashes
## DASH_GAP apart.
const DASH_DROP := 2.0
const DASH_HEIGHT := 4.0
const DASH_LENGTH := 6.0
const DASH_GAP := 4.0
## The spark's centre on the frame's top band.
const SPARK_Y := BatchFrame.INK_WIDTH + BatchFrame.MUSTARD_WIDTH / 2.0
## The mock-up's timings at speed 1 (s): a look's fade, a cap's slam, the planning fill's run and
## the count's, the drip's run, the spark's run (it lands SPARK_LAND after its start), how long a
## lit cap holds, the LAST cap's after a spark, a pop's life and the gaps between counted pops.
const LOOK_S := 0.2
const SLAM_S := 0.5
## A slam's widening against its stretch (the mock-up's 1.4 wide at 1.18 tall).
const SLAM_WIDEN := 2.2
const PLAN_FILL_S := 0.6
const COUNT_FILL_S := 0.5
const FILL_HOLD_S := 0.9
const DRIP_S := 0.5
const SPARK_S := 0.7
const SPARK_LAND := 0.76
const HOLD_S := 0.7
const LAST_HOLD_S := 0.4
const POP_S := 1.3
const BODY_POP_GAP := 0.16
const CLOSER_POP_GAP := 0.12
## A pop: from POP_FROM under its place, POP_DRIFT over it as it fades.
const POP_FROM := 10.0
const POP_DRIFT := 16.0
## The bagged items' counter: each tick punches it POP_PUNCH bigger, back over PUNCH_S.
const POP_PUNCH := 0.3
const PUNCH_S := 0.12

## The icing drip's reach over the LAST cap's left side.
const DRIP_IN := CELL
const DRIP := preload("res://art/effects/icing_drip.png")
const SPARK := preload("res://art/effects/batch_spark.png")

## The frame's batch (its slots in order) and the planning model it reads (null: none).
var batch: PackedInt32Array = PackedInt32Array()
var model: PlanningModel
## Under the player's reduced motion: no slam, spark, run or pop.
var reduced_motion: bool = false
## Which caps show (set by lay_out), and their looks.
var _shows: Array[bool] = [false, false]
var _looks: Array[Look] = [Look.CALM, Look.CALM]
var _glows: Array[float] = [0.0, 0.0]
var _slams: Array[float] = [1.0, 1.0]
var _tab_scales: Array[float] = [1.0, 1.0]
## The frame's lit look (a BATCH chip hovered).
var _frame_lit: bool = false
## The frame's size and its place in the layer, each laid out ticket's centre x (slot: local x).
var _size: Vector2 = Vector2.ZERO
var _origin: Vector2 = Vector2.ZERO
var _centers: Dictionary[int, float] = {}
## The slots with a ticket on the belt in any frame (lay_out; the batch's others are bagged).
var _on_belt: PackedInt32Array = PackedInt32Array()
## The fill's right end (local x; 0: none), the dashed line's start (local x; NAN: none), the
## drip's share shown (0 to 1) and the spark's x (NAN: none).
var _fill: float = 0.0
var _dash_from: float = NAN
var _drip_share: float = 1.0
var _spark: float = NAN
## The notes shown (text, centre x, bad) and the pops (text, centre x, life 0 to 1 or -1 while
## waiting on its delay, factor, punch 0 to 1).
var _note_texts: PackedStringArray = PackedStringArray()
var _note_xs: PackedFloat32Array = PackedFloat32Array()
var _note_bad: Array[bool] = []
var _pop_texts: PackedStringArray = PackedStringArray()
var _pop_xs: PackedFloat32Array = PackedFloat32Array()
var _pop_lives: PackedFloat32Array = PackedFloat32Array()
var _pop_factors: Array[bool] = []
var _pop_punches: PackedFloat32Array = PackedFloat32Array()
var _tweens: Array[Tween] = []
var _focus_tween: Tween
## The slot focus() last lit (-1: none), so a repeated hover replays nothing.
var _focused: int = -1


func _init(batch_slots: PackedInt32Array) -> void:
	name = "Bookends"
	batch = batch_slots
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Places the bookends on a frame of `frame_size` at `origin` (layer coordinates) round the tickets
## whose centres are `centers` (slot: x in the frame's coordinates): the FIRST cap when `first`,
## the LAST cap when `last`; `on_belt` the slots with a ticket on the belt in any frame (none
## given: this frame's).
func lay_out(
	frame_size: Vector2,
	origin: Vector2,
	centers: Dictionary[int, float],
	first: bool,
	last: bool,
	on_belt: PackedInt32Array = PackedInt32Array()
) -> void:
	_size = frame_size
	_origin = origin
	_centers = centers
	_on_belt = on_belt if not on_belt.is_empty() else PackedInt32Array(centers.keys())
	_shows = [first, last]
	size = frame_size
	queue_redraw()


## Whether the `cap` shows.
func shows(cap: Cap) -> bool:
	return _shows[cap]


## The `cap`'s look now.
func look(cap: Cap) -> Look:
	return _looks[cap]


## The `cap`'s rect (layer coordinates), empty when it does not show.
func cap_rect(cap: Cap) -> Rect2:
	if not _shows[cap]:
		return Rect2()
	return Rect2(_cap_local(cap).position + _origin, _cap_local(cap).size)


## The `cap`'s tab rect (layer coordinates, unscaled), empty when its cap does not show.
func tab_rect(cap: Cap) -> Rect2:
	if not _shows[cap]:
		return Rect2()
	var local: Rect2 = _tab_local(cap)
	return Rect2(local.position + _origin, local.size)


## The icing drip's whole rect (layer coordinates), empty without a glaze on the LAST cap.
func drip_rect() -> Rect2:
	if not has_drip():
		return Rect2()
	var local: Rect2 = _drip_local()
	return Rect2(local.position + _origin, local.size)


## Whether the icing drip pours over the LAST cap: it shows and the score glazes the batch's last.
func has_drip() -> bool:
	return (
		_shows[Cap.LAST] and model != null and not batch.is_empty() and model.glazes.has(batch[-1])
	)


## The Baguette's fill (layer coordinates), empty when none runs.
func fill_rect() -> Rect2:
	if _fill <= FILL_LEFT:
		return Rect2()
	return Rect2(_fill_local().position + _origin, _fill_local().size)


## The glaze's dashed line's span (layer coordinates), empty when none shows.
func dash_rect() -> Rect2:
	if is_nan(_dash_from):
		return Rect2()
	var local: Rect2 = Rect2(_dash_from, _size.y + DASH_DROP, _size.x - _dash_from, DASH_HEIGHT)
	return Rect2(local.position + _origin, local.size)


## The planning notes shown, in order.
func note_texts() -> PackedStringArray:
	return _note_texts.duplicate()


## The frame was lit or put back (BatchFrame.set_lit).
func set_frame_lit(lit: bool) -> void:
	_frame_lit = lit
	queue_redraw()


## Planning's hover: lights what the job card at `slot` reads (none: puts everything back).
func focus(slot: int) -> void:
	if slot == _focused:
		return
	_focused = slot
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	_focus_tween = null
	# A drip re-run cut short pours whole again.
	_drip_share = 1.0
	_note_texts.clear()
	_note_xs.clear()
	_note_bad.clear()
	_fill = 0.0
	_dash_from = NAN
	var lights: Array[Look] = [Look.CALM, Look.CALM]
	var role: int = _role(slot)
	var wasted: bool = role != BatchRoleRule.Role.NONE and _wasted(slot)
	var fill_to: float = 0.0
	var drip_again: bool = false
	match role:
		BatchRoleRule.Role.OPENER:
			lights[Cap.FIRST] = Look.BAD if wasted else Look.LIT
			if wasted:
				_note(NOT_FIRST, slot, true)
		BatchRoleRule.Role.CLOSER:
			lights[Cap.LAST] = Look.BAD if wasted else Look.LIT
			if wasted:
				_note(NOT_LAST, slot, true)
		BatchRoleRule.Role.BODY:
			if wasted:
				lights[Cap.FIRST] = Look.BAD
				_note(EARLIER % 0, slot, true)
			elif _centers.has(slot):
				fill_to = _centers[slot]
				_note(EARLIER % model.batch_counts.get(slot, 0), slot, false)
		BatchRoleRule.Role.GLAZE:
			lights[Cap.LAST] = Look.BAD if wasted else Look.LIT
			if wasted:
				_note(GLAZE_SELF, slot, true)
			else:
				# Only on the frame showing LAST: from the bun's ticket, else its left end.
				if _shows[Cap.LAST]:
					_dash_from = _centers.get(slot, 0.0)
				_note(GLAZE_LAST % model.glazes.get(batch[-1], 2), batch[-1], false)
				drip_again = true
	for cap: int in [Cap.FIRST, Cap.LAST]:
		if not _shows[cap]:
			lights[cap] = Look.CALM
	_set_looks(lights)
	if reduced_motion or not is_inside_tree():
		for cap: int in [Cap.FIRST, Cap.LAST]:
			var lit_now: bool = _looks[cap] != Look.CALM
			_glows[cap] = 1.0 if lit_now else 0.0
			_tab_scales[cap] = TAB_LIT_SCALE if lit_now else 1.0
		_fill = fill_to
		queue_redraw()
		return
	_focus_tween = create_tween().set_parallel()
	for cap: int in [Cap.FIRST, Cap.LAST]:
		var lit: bool = _looks[cap] != Look.CALM
		_focus_tween.tween_method(_set_glow.bind(cap), _glows[cap], 1.0 if lit else 0.0, LOOK_S)
		var scale_to: float = TAB_LIT_SCALE if lit else 1.0
		_focus_tween.tween_method(_set_tab_scale.bind(cap), _tab_scales[cap], scale_to, LOOK_S)
	if fill_to > 0.0:
		(
			_focus_tween
			. tween_method(_set_fill, 0.0, fill_to, PLAN_FILL_S)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_OUT)
		)
	if drip_again and has_drip():
		_run_drip(_focus_tween)


## The count: step `step` landed (a job card of this batch: its armed effect, its own bonus, the
## glaze's ×N on the last item or its WASTED step) plays its beat on `make_tween`'s tweens (an
## invalid Callable: this control's own); a split batch's frames each play only their part.
func fire(step: ScoreStep, make_tween: Callable = Callable()) -> void:
	if step == null or step.source_kind != ScoreStep.SourceKind.CARD or batch.is_empty():
		return
	var giver: int = step.source_slot
	var role: int = _role(giver)
	if role == BatchRoleRule.Role.NONE:
		return
	var home: bool = _centers.has(giver)
	match step.step_type:
		ScoreStep.StepType.WASTED:
			if step.slot == giver:
				var cap: Cap = (
					Cap.FIRST
					if role in [BatchRoleRule.Role.OPENER, BatchRoleRule.Role.BODY]
					else Cap.LAST
				)
				_slam(cap, Look.BAD, HOLD_S, 0.0, make_tween)
		ScoreStep.StepType.EFFECT_ARMED:
			if role == BatchRoleRule.Role.OPENER:
				if _shows[Cap.FIRST]:
					_slam(Cap.FIRST, Look.LIT, SPARK_LAND, 0.0, make_tween)
					_run_spark(make_tween)
				_slam(Cap.LAST, Look.LIT, LAST_HOLD_S, SPARK_LAND, make_tween)
			elif role == BatchRoleRule.Role.GLAZE and _shows[Cap.LAST]:
				_show_dash(_centers.get(giver, 0.0), make_tween)
		ScoreStep.StepType.FLAT:
			if step.slot != giver:
				return
			if role == BatchRoleRule.Role.BODY:
				if home:
					_run_fill(giver, make_tween)
				_count_pops(model.batch_counts.get(giver, 0), BODY_POP_GAP, home, make_tween)
			elif role == BatchRoleRule.Role.CLOSER:
				if _shows[Cap.LAST]:
					_run_spark(make_tween)
					_slam(Cap.LAST, Look.LIT, HOLD_S, SPARK_LAND, make_tween)
				_count_pops(batch.size(), CLOSER_POP_GAP, home, make_tween)
		ScoreStep.StepType.MULTIPLIER:
			if role == BatchRoleRule.Role.GLAZE and step.slot == batch[-1] and _shows[Cap.LAST]:
				_slam(Cap.LAST, Look.LIT, HOLD_S, 0.0, make_tween)
				_pop(
					ChainFrame.PLATE_TEXT % step.value,
					_cap_local(Cap.LAST).get_center().x,
					true,
					0.0,
					make_tween
				)
				if has_drip():
					_run_drip(_tween(make_tween))


## The ink cells of `text` (LETTERS, then ChainFrame.PLATE_GLYPHS; a character without cells is
## left blank) from `at`, each character a cell after the last.
static func glyph_cells(text: String, at: Vector2) -> Array[Rect2]:
	var cells: Array[Rect2] = []
	var glyph: Vector2i = ChainFrame.PLATE_GLYPH
	for index: int in range(text.length()):
		var rows: Array = LETTERS.get(text[index], ChainFrame.PLATE_GLYPHS.get(text[index], []))
		var left: float = at.x + index * (glyph.x + 1) * CELL
		for row: int in range(rows.size()):
			var line: String = rows[row]
			for column: int in range(line.length()):
				if line[column] == "#":
					cells.append(Rect2(left + column * CELL, at.y + row * CELL, CELL, CELL))
	return cells


func _exit_tree() -> void:
	for tween: Tween in _tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_tweens.clear()
	if _focus_tween != null and _focus_tween.is_valid():
		_focus_tween.kill()
	_focus_tween = null


func _draw() -> void:
	if _size == Vector2.ZERO:
		return
	if _fill > FILL_LEFT:
		var fill: Rect2 = _fill_local()
		_draw_rings(fill, Palette.GOLD, 1)
		draw_rect(fill, Palette.GOLD)
	if not is_nan(_dash_from):
		var x: float = _dash_from
		while x < _size.x:
			var length: float = minf(DASH_LENGTH, _size.x - x)
			draw_rect(Rect2(x, _size.y + DASH_DROP, length, DASH_HEIGHT), Palette.GOLD)
			x += DASH_LENGTH + DASH_GAP
	for cap: int in [Cap.FIRST, Cap.LAST]:
		if _shows[cap]:
			_draw_cap(cap)
	if has_drip() and _drip_share > 0.0:
		var drip: Rect2 = _drip_local()
		var shown: float = snappedf(drip.size.y * _drip_share, CELL)
		var region: Rect2 = Rect2(Vector2.ZERO, Vector2(DRIP.get_width(), shown / CELL))
		draw_texture_rect_region(DRIP, Rect2(drip.position, Vector2(drip.size.x, shown)), region)
	for cap: int in [Cap.FIRST, Cap.LAST]:
		if _shows[cap]:
			_draw_tab(cap)
	if not is_nan(_spark):
		var spark_size: Vector2 = Vector2(SPARK.get_width(), SPARK.get_height()) * CELL
		var at: Vector2 = (Vector2(_spark, SPARK_Y) - spark_size / 2.0).snappedf(CELL)
		draw_texture_rect(SPARK, Rect2(at, spark_size), false)
	for index: int in range(_note_texts.size()):
		_draw_note(_note_texts[index], _note_xs[index], _note_bad[index])
	for index: int in range(_pop_texts.size()):
		_draw_pop(index)


func _draw_cap(cap: int) -> void:
	var rect: Rect2 = _cap_local(cap)
	var look_now: Look = _looks[cap]
	var colours: Array[Color] = _cap_colours(look_now)
	var glow: Color = Palette.TOMATO if look_now == Look.BAD else Palette.GOLD
	var slam: float = _slams[cap]
	_scaled(
		rect.get_center(), Vector2(1.0 + (slam - 1.0) * SLAM_WIDEN if slam > 1.0 else slam, slam)
	)
	if _glows[cap] > 0.0:
		_draw_rings(rect, glow, GLOW_ALPHAS.size(), _glows[cap])
	# The ink with its corner cells cut, the face's columns, its light and dark rows.
	draw_rect(
		Rect2(rect.position.x + CELL, rect.position.y, rect.size.x - CELL * 2.0, rect.size.y),
		Palette.INK
	)
	draw_rect(
		Rect2(rect.position.x, rect.position.y + CELL, rect.size.x, rect.size.y - CELL * 2.0),
		Palette.INK
	)
	var face: Rect2 = rect.grow(-CAP_INK)
	for column: int in range(CAP_COLUMNS.size()):
		var x: float = face.position.x + column * CELL
		var width: float = minf(CELL, face.end.x - x)
		if width > 0.0:
			draw_rect(Rect2(x, face.position.y, width, face.size.y), colours[CAP_COLUMNS[column]])
	var row_width: float = face.size.x - CAP_ROW_INSET * 2.0
	var row_x: float = face.position.x + CAP_ROW_INSET
	draw_rect(Rect2(row_x, face.position.y + CAP_ROW_AT, row_width, CELL), colours[2])
	draw_rect(Rect2(row_x, face.end.y - CAP_ROW_AT - CELL, row_width, CELL), colours[3])
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_tab(cap: int) -> void:
	var rect: Rect2 = _tab_local(cap)
	var look_now: Look = _looks[cap]
	var face: Color = Palette.GOLD if look_now == Look.LIT or _frame_lit else Palette.MUSTARD
	var ink: Color = Palette.INK
	if look_now == Look.BAD:
		face = Palette.TOMATO
		ink = Palette.PAPER
	_scaled(rect.get_center(), Vector2.ONE * _tab_scales[cap])
	if _glows[cap] > 0.0 and look_now == Look.LIT:
		_draw_rings(rect, Palette.GOLD, 2, _glows[cap])
	_draw_plate(rect, Palette.INK, face, ink, FIRST_WORD if cap == Cap.FIRST else LAST_WORD)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_note(text: String, x: float, bad: bool) -> void:
	var plate: Vector2 = ChainFrame.plate_size(text)
	var at: Vector2 = Vector2(x - plate.x / 2.0, _size.y + NOTE_DROP)
	# Along the tabs' row, clear of the tabs.
	for cap: int in [Cap.FIRST, Cap.LAST]:
		var tab: Rect2 = _tab_local(cap)
		if _shows[cap] and Rect2(at, plate).intersects(tab):
			at.x = tab.end.x + NOTE_GAP if cap == Cap.FIRST else tab.position.x - NOTE_GAP - plate.x
	at = at.snappedf(CELL)
	var border: Color = Palette.TOMATO if bad else Palette.GOLD
	var ink: Color = Palette.PAPER if bad else Palette.GOLD
	_draw_plate(Rect2(at, plate), border, Palette.INK, ink, text)


## Pop `index` at its life: in from POP_FROM under its place growing to 1.15, settling to 1 at
## 30%, fading out over its last 20% POP_DRIFT up.
func _draw_pop(index: int) -> void:
	var life: float = _pop_lives[index]
	if life <= 0.0 or life >= 1.0:
		return
	var text: String = _pop_texts[index]
	var plate: Vector2 = ChainFrame.plate_size(text)
	var rise: float = 0.0
	var grow: float = 1.0 + POP_PUNCH * _pop_punches[index]
	var alpha: float = 1.0
	if life < 0.15:
		var share: float = life / 0.15
		rise = POP_FROM * (1.0 - share)
		grow *= lerpf(0.6, 1.15, share)
		alpha = share
	elif life < 0.3:
		grow *= lerpf(1.15, 1.0, (life - 0.15) / 0.15)
	elif life > 0.8:
		var share: float = (life - 0.8) / 0.2
		rise = -POP_DRIFT * share
		alpha = 1.0 - share
	var bottom: float = -NOTE_GAP + rise
	var rect: Rect2 = Rect2(Vector2(_pop_xs[index] - plate.x / 2.0, bottom - plate.y), plate)
	rect.position = rect.position.snappedf(CELL)
	_scaled(rect.get_center(), Vector2.ONE * grow)
	var factor: bool = _pop_factors[index]
	var face: Color = Palette.ORANGE_LIGHT if factor else Palette.INK
	var border: Color = Palette.INK if factor else Palette.GOLD
	var ink: Color = Palette.INK if factor else Palette.GOLD
	_draw_plate(rect, border, face, ink, text, alpha)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## A plate at `rect`: a `border` box with its corner cells cut round a `face`, `text` in `ink`.
func _draw_plate(
	rect: Rect2, border: Color, face: Color, ink: Color, text: String, alpha: float = 1.0
) -> void:
	var cut: float = CELL
	var fade: Color = Color(1, 1, 1, alpha)
	draw_rect(
		Rect2(rect.position.x + cut, rect.position.y, rect.size.x - cut * 2.0, rect.size.y),
		border * fade
	)
	draw_rect(
		Rect2(rect.position.x, rect.position.y + cut, rect.size.x, rect.size.y - cut * 2.0),
		border * fade
	)
	draw_rect(rect.grow(-ChainFrame.PLATE_BORDER), face * fade)
	var text_at: Vector2 = (
		rect.position + Vector2.ONE * (ChainFrame.PLATE_BORDER + ChainFrame.PLATE_PAD)
	)
	for cell: Rect2 in glyph_cells(text, text_at):
		draw_rect(cell, ink * fade)


## Rings CELL wide round `rect` in `colour`, `count` of them at GLOW_ALPHAS' alphas times `share`.
func _draw_rings(rect: Rect2, colour: Color, count: int, share: float = 1.0) -> void:
	for ring: int in range(mini(count, GLOW_ALPHAS.size())):
		var tint: Color = Color(colour, GLOW_ALPHAS[ring] * share)
		for side: Rect2 in PriceSticker.ring_sides(rect.grow(CELL * (ring + 1)), CELL):
			draw_rect(side, tint)


## Draws what follows scaled by `amount` about `center` (until the transform is reset).
func _scaled(center: Vector2, amount: Vector2) -> void:
	draw_set_transform_matrix(Transform2D(0.0, amount, 0.0, center - center * amount))


## A cap's colours by `look_now`: its sides' dark, its face, its light row and its dark row (the
## face gold when lit, or when the frame is).
func _cap_colours(look_now: Look) -> Array[Color]:
	if look_now == Look.BAD:
		return [Palette.TOMATO_DARK, Palette.TOMATO, Palette.TOMATO_LIGHT, Palette.TOMATO_DARKEST]
	if look_now == Look.LIT or _frame_lit:
		return [Palette.MUSTARD, Palette.GOLD, Palette.MUSTARD_LIGHT, Palette.MUSTARD_DARKEST]
	return [Palette.MUSTARD_DARK, Palette.MUSTARD, Palette.MUSTARD_LIGHT, Palette.MUSTARD_DARKEST]


func _cap_local(cap: int) -> Rect2:
	var height: float = _size.y + CAP_RISE
	if cap == Cap.FIRST:
		return Rect2(-CAP_OUT, -CAP_RISE, CAP_WIDTH, height)
	return Rect2(_size.x + CAP_OUT - CAP_WIDTH, -CAP_RISE, CAP_WIDTH, height)


func _tab_local(cap: int) -> Rect2:
	var plate: Vector2 = ChainFrame.plate_size(FIRST_WORD if cap == Cap.FIRST else LAST_WORD)
	var beside: Rect2 = _cap_local(cap)
	var x: float = beside.end.x - TAB_OVERLAP
	if cap == Cap.LAST:
		x = beside.position.x + TAB_OVERLAP - plate.x
	return Rect2(Vector2(x, _size.y - TAB_SINK), plate)


## The Baguette's fill (local): along the frame's foot band from its left side to `_fill`.
func _fill_local() -> Rect2:
	return Rect2(FILL_LEFT, _size.y - FILL_UP, _fill - FILL_LEFT, FILL_HEIGHT)


## The drip's rect (local): its art at CELL a pixel from the LAST cap's top, DRIP_IN over its left
## side (centred, it covered the last ticket's price window; further right, the next ticket).
func _drip_local() -> Rect2:
	var drip: Vector2 = Vector2(DRIP.get_width(), DRIP.get_height()) * CELL
	return Rect2(_cap_local(Cap.LAST).position - Vector2(DRIP_IN, 0.0), drip)


## The role of the job card at `slot` in this batch (BatchRoleRule.Role.NONE: none).
func _role(slot: int) -> int:
	if model == null or not batch.has(slot):
		return BatchRoleRule.Role.NONE
	return model.batch_roles.get(slot, BatchRoleRule.Role.NONE)


func _wasted(slot: int) -> bool:
	return slot < model.slots.size() and not model.slots[slot].wrong_job.is_empty()


func _note(text: String, slot: int, bad: bool) -> void:
	if not _centers.has(slot):
		return
	_note_texts.append(text)
	_note_xs.append(_centers[slot])
	_note_bad.append(bad)


func _set_looks(looks: Array[Look]) -> void:
	_looks = looks
	queue_redraw()


func _set_glow(share: float, cap: int) -> void:
	_glows[cap] = share
	queue_redraw()


func _set_tab_scale(amount: float, cap: int) -> void:
	_tab_scales[cap] = amount
	queue_redraw()


func _set_slam(amount: float, cap: int) -> void:
	_slams[cap] = amount
	queue_redraw()


func _set_fill(to: float) -> void:
	_fill = to
	queue_redraw()


func _set_drip(share: float) -> void:
	_drip_share = share
	queue_redraw()


func _set_spark(x: float) -> void:
	_spark = x
	queue_redraw()


func _set_pop(life: float, index: int) -> void:
	if index < _pop_lives.size():
		_pop_lives[index] = life
	queue_redraw()


func _set_punch(amount: float, index: int) -> void:
	if index < _pop_punches.size():
		_pop_punches[index] = amount
	queue_redraw()


## The counter pop at `index` ticks to `text` with a punch.
func _tick(text: String, index: int) -> void:
	if index < _pop_texts.size():
		_pop_texts[index] = text
	_set_punch(1.0, index)


func _set_dash(from: float) -> void:
	_dash_from = from
	queue_redraw()


## A tween from `make_tween` (else this control's own), kept to be killed when it leaves.
func _tween(make_tween: Callable) -> Tween:
	var tween: Tween = make_tween.call() as Tween if make_tween.is_valid() else create_tween()
	_tweens.append(tween)
	return tween


## `cap` turns `look_to` after `delay` with a slam (none under reduced motion), holds `hold` and
## goes back to calm.
func _slam(cap: Cap, look_to: Look, hold: float, delay: float, make_tween: Callable) -> void:
	if not _shows[cap] or not is_inside_tree():
		return
	var tween: Tween = _tween(make_tween)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_callback(_light.bind(cap, look_to))
	if not reduced_motion:
		# The mock-up's slam: wide at 25%, a dip at 60%, at rest by the end (scale's y; x more).
		tween.tween_method(_set_slam.bind(cap), 1.0, 1.18, SLAM_S * 0.25)
		tween.tween_method(_set_slam.bind(cap), 1.18, 0.95, SLAM_S * 0.35)
		tween.tween_method(_set_slam.bind(cap), 0.95, 1.0, SLAM_S * 0.4)
		tween.tween_interval(maxf(hold - SLAM_S, 0.0))
	else:
		tween.tween_interval(hold)
	tween.tween_callback(_light.bind(cap, Look.CALM))


func _light(cap: Cap, look_to: Look) -> void:
	_looks[cap] = look_to
	_glows[cap] = 0.0 if look_to == Look.CALM else 1.0
	queue_redraw()


## The spark runs along the frame from its left to its right over SPARK_S (none under reduced
## motion).
func _run_spark(make_tween: Callable) -> void:
	if reduced_motion or not is_inside_tree():
		return
	var tween: Tween = _tween(make_tween)
	tween.tween_method(_set_spark, 0.0, _size.x, SPARK_S)
	tween.tween_interval(maxf(SPARK_LAND - SPARK_S, 0.0))
	tween.tween_callback(_set_spark.bind(NAN))


## The Baguette at `slot`: the fill runs to its ticket, holds and goes.
func _run_fill(slot: int, make_tween: Callable) -> void:
	if not _centers.has(slot) or not is_inside_tree():
		return
	var tween: Tween = _tween(make_tween)
	if reduced_motion:
		tween.tween_callback(_set_fill.bind(_centers[slot]))
	else:
		(
			tween
			. tween_method(_set_fill, 0.0, _centers[slot], COUNT_FILL_S)
			. set_trans(Tween.TRANS_QUAD)
			. set_ease(Tween.EASE_OUT)
		)
	tween.tween_interval(maxf(FILL_HOLD_S - COUNT_FILL_S, 0.0))
	tween.tween_callback(_set_fill.bind(0.0))


## The glaze draws its dashed line from local x `from` to the LAST cap, which lights, for HOLD_S.
func _show_dash(from: float, make_tween: Callable) -> void:
	if not is_inside_tree():
		return
	_set_dash(from)
	_slam(Cap.LAST, Look.LIT, HOLD_S, 0.0, make_tween)
	var tween: Tween = _tween(make_tween)
	tween.tween_interval(HOLD_S)
	tween.tween_callback(_set_dash.bind(NAN))


## The drip runs down again on `tween` (at once under reduced motion).
func _run_drip(tween: Tween) -> void:
	if reduced_motion:
		_set_drip(1.0)
		return
	tween.tween_method(_set_drip, 0.0, 1.0, DRIP_S).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)


## Numbered pops 1 to `count`, `gap` apart: each over its batch item's ticket when this frame
## holds it; on the `home` frame (holding the job card) the bagged ones (no ticket on the belt)
## tick in one counter at the frame's left end. An item on another frame's ticket pops there.
func _count_pops(count: int, gap: float, home: bool, make_tween: Callable) -> void:
	if reduced_motion or not is_inside_tree():
		return
	var ticks: PackedStringArray = PackedStringArray()
	var tick_delays: PackedFloat32Array = PackedFloat32Array()
	for number: int in range(1, mini(count, batch.size()) + 1):
		var slot: int = batch[number - 1]
		if _centers.has(slot):
			_pop(str(number), _centers[slot], false, gap * (number - 1), make_tween)
		elif home and not _on_belt.has(slot):
			ticks.append(str(number))
			tick_delays.append(gap * (number - 1))
	if ticks.is_empty():
		return
	var widest: Vector2 = ChainFrame.plate_size(ticks[-1])
	var span: float = tick_delays[-1] - tick_delays[0] + POP_S
	var index: int = _pop(ticks[0], widest.x / 2.0, false, tick_delays[0], make_tween, span)
	for tick: int in range(1, ticks.size()):
		var tween: Tween = _tween(make_tween)
		tween.tween_interval(tick_delays[tick])
		tween.tween_callback(_tick.bind(ticks[tick], index))
		tween.tween_method(_set_punch.bind(index), 1.0, 0.0, PUNCH_S)


## A pop of `text` over local x `x` (a factor's in orange) after `delay`, living `life` (none under
## reduced motion); returns its index (-1: none).
func _pop(
	text: String, x: float, factor: bool, delay: float, make_tween: Callable, life: float = POP_S
) -> int:
	if reduced_motion or not is_inside_tree():
		return -1
	# The pops start afresh once every earlier one is over (none still waiting on its delay).
	var all_done: bool = true
	for life_now: float in _pop_lives:
		if life_now < 1.0:
			all_done = false
	if all_done:
		_pop_texts.clear()
		_pop_xs.clear()
		_pop_lives.clear()
		_pop_factors.clear()
		_pop_punches.clear()
	_pop_texts.append(text)
	_pop_xs.append(x)
	_pop_lives.append(-1.0)
	_pop_factors.append(factor)
	_pop_punches.append(0.0)
	var index: int = _pop_lives.size() - 1
	var tween: Tween = _tween(make_tween)
	if delay > 0.0:
		tween.tween_interval(delay)
	tween.tween_method(_set_pop.bind(index), 0.0, 1.0, life)
	return index
