class_name BatchFrame
extends Control
## One Bakery batch bound on the price rail while planning (#128, the approved Bound strip
## mock-up, docs/art/mockups/bakery_batch_128.html's 'stripb'): a single frame runs round the
## batch's tickets, the gaps between them included, so where it starts and stops is where the
## batch starts and stops, and two binding bars cross every gap between its tickets. The frame is
## INK_WIDTH of ink, MUSTARD_WIDTH of mustard and INK_WIDTH of ink with stepped corners (two
## STEP px stairs each; its inside square), a light row along the inside of its top band; its
## sides run just outside the end tickets, its top over their top outline, its foot on the
## counter edge at most. It
## runs on behind the price tags: a pinned pay tag draws over it (PlanningLayer), and a cutout (a
## ticket's plain tag, under the layer) is left open along the tag's own rect only, with no cap, so
## the frame reads as passing behind it. Each bar is ink round mustard with the
## same light row, BAR_OVERLAP onto each ticket's outline, clear of the tickets' text.
##
## Where its foot band covers a wrong job's tomato ring (PriceSticker.set_wrong_job: the tickets
## reach under the counter edge's band), it draws that ring's part over itself, so the ring stays
## closed. Lit (set_lit: a BATCH chip of its batch hovered) its mustard turns gold and its light
## rows paper. PlanningLayer owns it: lay_out places it from the tickets' rects in the layer's
## coordinates. Decor only: it takes no clicks and never moves on its own.

## The frame's bands: INK_WIDTH ink, MUSTARD_WIDTH mustard (its top band's first HIGHLIGHT rows
## light), INK_WIDTH ink; RING in all.
const INK_WIDTH := 2.0
const MUSTARD_WIDTH := 4.0
const HIGHLIGHT := 2.0
const RING := INK_WIDTH * 2.0 + MUSTARD_WIDTH
## Each stepped corner's stairs.
const STEP := 2.0
## The frame's top over the tickets' tops (its inner edge on their top outline), and its foot
## under their feet, at most the counter edge.
const TOP_OUT := 6.0
const FOOT_OUT := 2.0
## The binding bars: their tops from the tickets' top on an unscaled ticket (scaled with a
## scaled row's tickets), BAR_HEIGHT tall, reaching BAR_OVERLAP onto each ticket's outline (the
## ticket's text starts PriceSticker.SUMMARY_RECT's x in).
const BAR_TOPS: Array[float] = [34.0, 48.0]
const BAR_HEIGHT := 8.0
const BAR_OVERLAP := 2.0
const CALM_MUSTARD := Palette.MUSTARD
const LIT_MUSTARD := Palette.GOLD
const CALM_LIGHT := Palette.MUSTARD_LIGHT
const LIT_LIGHT := Palette.PAPER

## The slots whose tickets it binds (its batch's run, PlanningModel.runs_of), in slot order.
var slots: PackedInt32Array = PackedInt32Array()
## Its whole batch's slots, in slot order (the run's, or more when a link skips products).
var batch: PackedInt32Array = PackedInt32Array()
var _lit: bool = false
## The last layout, in the layer's coordinates.
var _frame_rect: Rect2 = Rect2()
var _bar_rects: Array[Rect2] = []
var _cutouts: Array[Rect2] = []
var _wrong_rings: Array[Rect2] = []
## The parts to draw (this control's coordinates): ink, mustard and light rects.
var _ink: Array[Rect2] = []
var _mustard: Array[Rect2] = []
var _light: Array[Rect2] = []
## The wrong jobs' tomato ring parts it covers (this control's coordinates), drawn over it.
var _tomato: Array[Rect2] = []


## The frame round the tickets at `run_slots`, a run of the batch at `batch_slots` (none given:
## the run is the whole batch).
func _init(run_slots: PackedInt32Array, batch_slots: PackedInt32Array = PackedInt32Array()) -> void:
	slots = run_slots
	batch = batch_slots if not batch_slots.is_empty() else run_slots
	name = "BatchFrame%d" % (run_slots[0] if not run_slots.is_empty() else -1)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Places the frame round `tickets` (every ticket's rect from the batch's first to its last, in
## slot order, layer coordinates), open at `cutouts` (the plain price tags' rects), its foot at
## most at `foot_limit` (the counter edge); `wrong_rings` are the wrong jobs' tomato ring sides
## (layer coordinates), redrawn where the frame covers them.
func lay_out(
	tickets: Array[Rect2], cutouts: Array[Rect2], foot_limit: float, wrong_rings: Array[Rect2] = []
) -> void:
	_cutouts = cutouts.duplicate()
	_wrong_rings = wrong_rings.duplicate()
	_bar_rects.clear()
	if tickets.is_empty():
		_frame_rect = Rect2()
		visible = false
		return
	var top: float = INF
	var foot: float = -INF
	for ticket: Rect2 in tickets:
		top = minf(top, ticket.position.y)
		foot = maxf(foot, ticket.end.y)
	var left: float = tickets[0].position.x - RING
	var right: float = tickets[-1].end.x + RING
	var frame_top: float = top - TOP_OUT
	var frame_foot: float = minf(foot + FOOT_OUT, foot_limit)
	_frame_rect = Rect2(left, frame_top, right - left, frame_foot - frame_top)
	if minf(_frame_rect.size.x, _frame_rect.size.y) < (RING + STEP * 2.0) * 2.0:
		# Too small to bind anything (tickets not laid out yet).
		_frame_rect = Rect2()
		visible = false
		return
	var row_scale: float = tickets[0].size.y / PriceSticker.SIZE.y
	for index: int in range(tickets.size() - 1):
		var here: Rect2 = tickets[index]
		var next: Rect2 = tickets[index + 1]
		for bar_top: float in BAR_TOPS:
			var y: float = snappedf(here.position.y + bar_top * row_scale, ArtStyle.ART_SCALE)
			var x0: float = here.end.x - BAR_OVERLAP
			var x1: float = next.position.x + BAR_OVERLAP
			# No bar until the row has sorted its tickets apart (a gap at least the bar's ink).
			if x1 - x0 >= INK_WIDTH * 2.0 + BAR_OVERLAP * 2.0:
				_bar_rects.append(Rect2(x0, y, x1 - x0, BAR_HEIGHT))
	position = _frame_rect.position
	size = _frame_rect.size
	visible = true
	_build()


## Lights the frame and its bars (a BATCH chip of its batch hovered), or puts them back.
func set_lit(lit: bool) -> void:
	if _lit == lit:
		return
	_lit = lit
	queue_redraw()


func is_lit() -> bool:
	return _lit


## The frame's outer rect at the last layout, in the layer's coordinates.
func frame_rect() -> Rect2:
	return _frame_rect


## The wrong jobs' tomato ring parts drawn over the frame, in the layer's coordinates.
func tomato_rects() -> Array[Rect2]:
	var drawn: Array[Rect2] = []
	for rect: Rect2 in _tomato:
		drawn.append(Rect2(rect.position + position, rect.size))
	return drawn


## The binding bars' rects at the last layout, in the layer's coordinates.
func bar_rects() -> Array[Rect2]:
	return _bar_rects


## Every rect drawn (ink, mustard and light), in the layer's coordinates.
func drawn_rects() -> Array[Rect2]:
	var drawn: Array[Rect2] = []
	for rect: Rect2 in _ink + _mustard + _light:
		drawn.append(Rect2(rect.position + position, rect.size))
	return drawn


## The rects of a stepped rectangle's ring `width` wide inside `rect`, STEP px stairs at each
## corner (the hole's too when `stepped_hole`, else square), row band by row band.
static func stepped_ring(rect: Rect2, width: float, stepped_hole: bool = true) -> Array[Rect2]:
	var hole: Rect2 = rect.grow(-width)
	var rows: Array[float] = []
	for edge: Rect2 in [rect, hole]:
		for y: float in [
			edge.position.y,
			edge.position.y + STEP,
			edge.position.y + STEP * 2.0,
			edge.end.y - STEP * 2.0,
			edge.end.y - STEP,
			edge.end.y,
		]:
			if not rows.has(y):
				rows.append(y)
	rows.sort()
	var found: Array[Rect2] = []
	for index: int in range(rows.size() - 1):
		var y0: float = rows[index]
		var y1: float = rows[index + 1]
		var middle: float = (y0 + y1) / 2.0
		var outer: Vector2 = _span(rect, middle)
		if outer.y <= outer.x:
			continue
		var inner: Vector2 = Vector2.ZERO
		if hole.has_area():
			inner = _span(hole, middle, STEP if stepped_hole else 0.0)
		if inner.y <= inner.x:
			found.append(Rect2(outer.x, y0, outer.y - outer.x, y1 - y0))
			continue
		if inner.x > outer.x:
			found.append(Rect2(outer.x, y0, inner.x - outer.x, y1 - y0))
		if outer.y > inner.y:
			found.append(Rect2(inner.y, y0, outer.y - inner.y, y1 - y0))
	return found


## `rect` less `cut`: up to four rects.
static func subtract(rect: Rect2, cut: Rect2) -> Array[Rect2]:
	var overlap: Rect2 = rect.intersection(cut)
	if not overlap.has_area():
		return [rect]
	var pieces: Array[Rect2] = []
	if overlap.position.y > rect.position.y:
		pieces.append(
			Rect2(rect.position, Vector2(rect.size.x, overlap.position.y - rect.position.y))
		)
	if overlap.end.y < rect.end.y:
		pieces.append(
			Rect2(rect.position.x, overlap.end.y, rect.size.x, rect.end.y - overlap.end.y)
		)
	if overlap.position.x > rect.position.x:
		pieces.append(
			Rect2(
				rect.position.x,
				overlap.position.y,
				overlap.position.x - rect.position.x,
				overlap.size.y
			)
		)
	if overlap.end.x < rect.end.x:
		pieces.append(
			Rect2(overlap.end.x, overlap.position.y, rect.end.x - overlap.end.x, overlap.size.y)
		)
	return pieces


func _draw() -> void:
	for rect: Rect2 in _ink:
		draw_rect(rect, Palette.INK)
	var mustard: Color = LIT_MUSTARD if _lit else CALM_MUSTARD
	for rect: Rect2 in _mustard:
		draw_rect(rect, mustard)
	var light: Color = LIT_LIGHT if _lit else CALM_LIGHT
	for rect: Rect2 in _light:
		draw_rect(rect, light)
	for rect: Rect2 in _tomato:
		draw_rect(rect, Palette.TOMATO)


## The parts in this control's coordinates: the frame's bands and light row and the bars, all open
## at the cutouts.
func _build() -> void:
	var origin: Vector2 = _frame_rect.position
	var outer: Rect2 = Rect2(Vector2.ZERO, _frame_rect.size)
	var ink: Array[Rect2] = stepped_ring(outer, INK_WIDTH)
	# The inside is square, so the inner corners keep clear of the end tickets' glyphs.
	ink.append_array(stepped_ring(outer.grow(-(INK_WIDTH + MUSTARD_WIDTH)), INK_WIDTH, false))
	var mustard: Array[Rect2] = stepped_ring(outer.grow(-INK_WIDTH), MUSTARD_WIDTH)
	var inset: float = INK_WIDTH + STEP * 2.0
	var light: Array[Rect2] = [Rect2(inset, INK_WIDTH, outer.size.x - inset * 2.0, HIGHLIGHT)]
	for bar: Rect2 in _bar_rects:
		var local: Rect2 = Rect2(bar.position - origin, bar.size)
		ink.append_array(PriceSticker.ring_sides(local, INK_WIDTH))
		var inside: Rect2 = local.grow(-INK_WIDTH)
		mustard.append(inside)
		light.append(Rect2(inside.position, Vector2(inside.size.x, HIGHLIGHT)))
	var cuts: Array[Rect2] = []
	for cutout: Rect2 in _cutouts:
		cuts.append(Rect2(cutout.position - origin, cutout.size))
	_ink = _cut(ink, cuts)
	_mustard = _cut(mustard, cuts)
	_light = _cut(light, cuts)
	_tomato.clear()
	for ring: Rect2 in _wrong_rings:
		var local_ring: Rect2 = Rect2(ring.position - origin, ring.size)
		for part: Rect2 in _ink + _mustard + _light:
			var covered: Rect2 = local_ring.intersection(part)
			if covered.has_area():
				_tomato.append(covered)
	queue_redraw()


## Every rect of `rects` less every cut.
static func _cut(rects: Array[Rect2], cuts: Array[Rect2]) -> Array[Rect2]:
	var kept: Array[Rect2] = rects.duplicate()
	for cut: Rect2 in cuts:
		var next: Array[Rect2] = []
		for rect: Rect2 in kept:
			next.append_array(subtract(rect, cut))
		kept = next
	return kept


## The x-span (from, to) of `rect` with `step` px stairs at its corners (0: square) on the row at
## `y`, or an empty span off it.
static func _span(rect: Rect2, y: float, step: float = STEP) -> Vector2:
	if y < rect.position.y or y > rect.end.y:
		return Vector2.ZERO
	var depth: float = minf(y - rect.position.y, rect.end.y - y)
	var inset: float = 0.0
	if depth < step:
		inset = step * 2.0
	elif depth < step * 2.0:
		inset = step
	return Vector2(rect.position.x + inset, rect.end.x - inset)
