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
##
## A Produce chain's frame (ChainFrame, #128 Produce links) is this frame in its own colours
## (paint_color) with its own parts in the gaps and round the frame (_place_parts, _add_under,
## _add_parts) in place of the bars: everything it draws goes through the same cutouts and tomato
## redraw, in draw order.

## What each drawn rect is painted (paint_color): the ink, the frame's face and light rows, a
## chain's knot parts' face and light (ChainFrame), and a wrong job's tomato redrawn over them.
enum Paint { INK, FACE, LIGHT, KNOT_FACE, KNOT_LIGHT, TOMATO }

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
## The last layout, in the layer's coordinates: the frame, its bars, the cutouts and the wrong
## jobs' tomato ring sides; and the slot of each ticket it was laid out round, in order.
var _frame_rect: Rect2 = Rect2()
var _bar_rects: Array[Rect2] = []
var _cutouts: Array[Rect2] = []
var _wrong_rings: Array[Rect2] = []
var _ticket_slots: PackedInt32Array = PackedInt32Array()
## The slots the last layout skipped (a drag's ghost: no ticket on the belt).
var _skipped: PackedInt32Array = PackedInt32Array()
## The rects to draw (this control's coordinates) in draw order, each with its Paint: the
## frame's and its parts', open at the cutouts, then the wrong jobs' tomato ring parts they cover.
var _rects: Array[Rect2] = []
var _paints: PackedInt32Array = PackedInt32Array()


## The frame round the tickets at `run_slots`, a run of the batch at `batch_slots` (none given:
## the run is the whole batch).
func _init(run_slots: PackedInt32Array, batch_slots: PackedInt32Array = PackedInt32Array()) -> void:
	slots = run_slots
	batch = batch_slots if not batch_slots.is_empty() else run_slots
	_ticket_slots = run_slots
	name = "BatchFrame%d" % (run_slots[0] if not run_slots.is_empty() else -1)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Places the frame round `tickets` (every ticket's rect from the batch's first to its last, in
## slot order, layer coordinates; `ticket_slots` their slots, none given: the run's slots), open
## at `cutouts` (the plain price tags' rects), its foot at most at `foot_limit` (the counter
## edge); `wrong_rings` are the wrong jobs' tomato ring sides (layer coordinates), redrawn where
## the frame covers them; `skipped` the slots with no ticket on the belt (a drag's ghost).
func lay_out(
	tickets: Array[Rect2],
	cutouts: Array[Rect2],
	foot_limit: float,
	wrong_rings: Array[Rect2] = [],
	ticket_slots: PackedInt32Array = PackedInt32Array(),
	skipped: PackedInt32Array = PackedInt32Array()
) -> void:
	_cutouts = cutouts.duplicate()
	_wrong_rings = wrong_rings.duplicate()
	_ticket_slots = ticket_slots if not ticket_slots.is_empty() else slots
	_skipped = skipped
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
	_place_parts(tickets)
	position = _frame_rect.position
	size = _frame_rect.size
	visible = true
	_build()


## Lights the frame and its parts (a BATCH chip of its batch hovered), or puts them back.
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
	return _painted(true)


## The binding bars' rects at the last layout, in the layer's coordinates.
func bar_rects() -> Array[Rect2]:
	return _bar_rects


## Every rect drawn (ink, face and light, its parts' too; not the tomato), in the layer's
## coordinates.
func drawn_rects() -> Array[Rect2]:
	return _painted(false)


## The Paint of each of drawn_rects(), in the same (draw) order.
func drawn_paints() -> PackedInt32Array:
	var paints: PackedInt32Array = PackedInt32Array()
	for paint: int in _paints:
		if paint != Paint.TOMATO:
			paints.append(paint)
	return paints


## The colour `paint` is drawn in now (lit or calm): mustard (gold when lit) for the faces,
## mustard light (paper when lit) for the light rows.
func paint_color(paint: Paint) -> Color:
	match paint:
		Paint.FACE, Paint.KNOT_FACE:
			return LIT_MUSTARD if _lit else CALM_MUSTARD
		Paint.LIGHT, Paint.KNOT_LIGHT:
			return LIT_LIGHT if _lit else CALM_LIGHT
		Paint.TOMATO:
			return Palette.TOMATO
	return Palette.INK


## How much a row's tickets are scaled (`tickets`' first against PriceSticker.SIZE).
static func row_scale_of(tickets: Array[Rect2]) -> float:
	return tickets[0].size.y / PriceSticker.SIZE.y


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
	for index: int in range(_rects.size()):
		draw_rect(_rects[index], paint_color(_paints[index] as Paint))


## Places the frame's parts round `tickets` (layer coordinates; the frame's rect is set): the
## binding bars across every gap, BAR_TOPS down a ticket (scaled with a scaled row's tickets).
func _place_parts(tickets: Array[Rect2]) -> void:
	var row_scale: float = row_scale_of(tickets)
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


## Adds the parts drawn before the frame (this control's coordinates; `origin` its place in the
## layer): none here.
func _add_under(_origin: Vector2) -> void:
	pass


## Adds the parts drawn after the frame (this control's coordinates; `origin` its place in the
## layer): the binding bars, ink round mustard with a light row.
func _add_parts(origin: Vector2) -> void:
	for bar: Rect2 in _bar_rects:
		var local: Rect2 = Rect2(bar.position - origin, bar.size)
		_add(PriceSticker.ring_sides(local, INK_WIDTH), Paint.INK)
		var inside: Rect2 = local.grow(-INK_WIDTH)
		_add([inside], Paint.FACE)
		_add([Rect2(inside.position, Vector2(inside.size.x, HIGHLIGHT))], Paint.LIGHT)


## Adds a band ring inside `rect` (this control's coordinates), drawn after every rect added
## before: `ink` of ink, `face` of `face_paint` and `ink` of ink, stepped corners outside and a
## square inside, a HIGHLIGHT row of `light_paint` along the inside of its top band; only its part
## inside `clip` when given. The frame's own ring, and a chain's links (ChainFrame).
func _add_band_ring(
	rect: Rect2,
	ink: float,
	face: float,
	face_paint: Paint = Paint.FACE,
	light_paint: Paint = Paint.LIGHT,
	clip: Rect2 = Rect2()
) -> void:
	var inks: Array[Rect2] = stepped_ring(rect, ink)
	# The inside is square, so the frame's inner corners keep clear of the end tickets' glyphs.
	inks.append_array(stepped_ring(rect.grow(-(ink + face)), ink, false))
	var faces: Array[Rect2] = stepped_ring(rect.grow(-ink), face)
	var inset: float = ink + STEP * 2.0
	var lights: Array[Rect2] = [
		Rect2(rect.position.x + inset, rect.position.y + ink, rect.size.x - inset * 2.0, HIGHLIGHT)
	]
	if clip.has_area():
		inks = _clipped(inks, clip)
		faces = _clipped(faces, clip)
		lights = _clipped(lights, clip)
	_add(inks, Paint.INK)
	_add(faces, face_paint)
	_add(lights, light_paint)


## Adds `rects` (this control's coordinates) painted `paint`, drawn after every rect added before.
func _add(rects: Array[Rect2], paint: Paint) -> void:
	for rect: Rect2 in rects:
		_rects.append(rect)
		_paints.append(paint)


## The rects to draw in this control's coordinates: the parts under the frame, the frame's bands
## and light row, its parts over it, all open at the cutouts; then the wrong jobs' tomato ring
## parts they cover.
func _build() -> void:
	_rects.clear()
	_paints.clear()
	var origin: Vector2 = _frame_rect.position
	var outer: Rect2 = Rect2(Vector2.ZERO, _frame_rect.size)
	_add_under(origin)
	_add_band_ring(outer, INK_WIDTH, MUSTARD_WIDTH)
	_add_parts(origin)
	var cuts: Array[Rect2] = []
	for cutout: Rect2 in _cutouts:
		cuts.append(Rect2(cutout.position - origin, cutout.size))
	var kept: Array[Rect2] = []
	var kept_paints: PackedInt32Array = PackedInt32Array()
	for index: int in range(_rects.size()):
		for piece: Rect2 in _cut([_rects[index]], cuts):
			kept.append(piece)
			kept_paints.append(_paints[index])
	_rects = kept
	_paints = kept_paints
	var tomato: Array[Rect2] = []
	for ring: Rect2 in _wrong_rings:
		var local_ring: Rect2 = Rect2(ring.position - origin, ring.size)
		for part: Rect2 in _rects:
			var covered: Rect2 = local_ring.intersection(part)
			if covered.has_area():
				tomato.append(covered)
	_add(tomato, Paint.TOMATO)
	queue_redraw()


## The drawn rects in the layer's coordinates: the tomato ones (`tomato`), or every other one.
func _painted(tomato: bool) -> Array[Rect2]:
	var drawn: Array[Rect2] = []
	for index: int in range(_rects.size()):
		if (_paints[index] == Paint.TOMATO) == tomato:
			drawn.append(Rect2(_rects[index].position + position, _rects[index].size))
	return drawn


## Each of `rects` cut to `clip` (the empty ones dropped).
static func _clipped(rects: Array[Rect2], clip: Rect2) -> Array[Rect2]:
	var kept: Array[Rect2] = []
	for rect: Rect2 in rects:
		var part: Rect2 = rect.intersection(clip)
		if part.has_area():
			kept.append(part)
	return kept


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
