class_name ChainFrame
extends BatchFrame
## One Produce chain linked on the price rail while planning (#128 Produce links, the approved
## Linked frame: docs/art/mockups/produce_chain_128.html's 'rings'): the Bakery's Bound-strip frame
## (BatchFrame: the same closed ring round the chain's tickets, running on behind every pinned pay
## tag, open along a plain tag's own rect, its foot on the counter edge at most) in Produce green,
## with the chain's parts in place of the binding bars. Every gap between two of its tickets is
## crossed by two interlocked pixel rings (LINK_SIZE, ink, face and ink, the face's top row light;
## each ring's band in the other's hole, an open hole either side), the left ring over the right one
## on top and under it at the bottom (a scaled 8-slot row's narrow gap: one jump ring bridging it);
## the gaps beside a Lemon knot are lemon yellow, and the knot's ticket has a small "×2" plate (its
## factor, from the score: ×3 for a GOLDEN Lemon, in PLATE_GLYPHS' pixel cells) on the frame's
## bottom band. A FEED helper at its place (Strawberries just before the chain) hangs one clasp ring
## through the frame's left side, a TALLY helper at its place (Wonky carrot just after it) one
## through its right side: the ring's top runs under the side and its bottom over it, so the side
## passes through the ring. Lit (a CHAIN chip naming the chain hovered) every green and lemon part
## turns gold and its light rows paper. While a drag's ghost (no ticket on the belt) is in the run,
## the gap across it has no rings, and a helper or a chain end that is the ghost hangs no clasp.
## ChainFrames owns it; decor only.

## The palette has no lime or lemon (the mock-up's #a9dd45 and #f5d93a): green light for the
## frame's face, gold for a knot's parts (the mock-up's lemon is next to its lit gold).
const CALM_GREEN := Palette.GREEN_LIGHT
const CALM_GREEN_LIGHT := Palette.MUSTARD_PALE
const CALM_LEMON := Palette.GOLD
const CALM_LEMON_LIGHT := Palette.MUSTARD_PALE
## A link's ring: LINK_SIZE outer, its band LINK_INK ink, LINK_FACE face and LINK_INK ink with
## stepped corners outside and a square hole, LINK_TOP down a ticket (scaled with a scaled row's
## tickets): on the middle of the tickets' text block.
const LINK_SIZE := Vector2(22, 20)
const LINK_INK := 2.0
const LINK_FACE := 2.0
const LINK_BAND := LINK_INK * 2.0 + LINK_FACE
const LINK_TOP := 36.0
## A pair's two rings overlap by two bands, each band inside the other ring's hole (interlocked),
## so LINK_SIZE.x less three bands of each hole stays open.
const LINK_OVERLAP := LINK_BAND * 2.0
const PAIR_WIDTH := LINK_SIZE.x * 2.0 - LINK_OVERLAP
## The most a pair or a clasp reaches onto a ticket's outline (its text starts
## PriceSticker.SUMMARY_RECT's x in). A gap narrower than PAIR_WIDTH less twice this (a scaled
## 8-slot row's) gets one jump ring bridging it instead, LINK_REACH onto each ticket, at least
## JUMP_WIDTH wide; a gap narrower than JUMP_GAP (tickets not sorted apart yet) gets none.
const LINK_REACH := 6.0
const JUMP_WIDTH := LINK_BAND * 2.0 + 4.0
const JUMP_GAP := LINK_INK * 2.0
## A clasp's ring: CLASP_WIDTH wide (LINK_SIZE tall), its far band through the frame's side,
## reaching CLASP_INSIDE past the side's inner edge onto the end ticket's outline.
const CLASP_WIDTH := 28.0
const CLASP_INSIDE := 2.0
## The knot's plate: an ink box (its corner cells cut) round a lemon face, its text ("×2") in
## PLATE_GLYPHS' pixel cells, PLATE_CELL each (the art grid, so it stays crisp), a cell apart,
## PLATE_PAD inside the box's PLATE_BORDER; PLATE_X from the knot ticket's left (scaled), its foot
## on the frame's.
const PLATE_X := 70.0
const PLATE_TEXT := "×%d"
const PLATE_CELL := float(ArtStyle.ART_SCALE)
const PLATE_BORDER := 2.0
const PLATE_PAD := 2.0
## Each plate character's cells, PLATE_GLYPH wide and tall ('#' ink).
const PLATE_GLYPH := Vector2i(3, 5)
const PLATE_GLYPHS: Dictionary[String, Array] = {
	"×": ["...", "#.#", ".#.", "#.#", "..."],
	"0": ["###", "#.#", "#.#", "#.#", "###"],
	"1": [".#.", "##.", ".#.", ".#.", "###"],
	"2": ["###", "..#", "###", "#..", "###"],
	"3": ["###", "..#", "###", "..#", "###"],
	"4": ["#.#", "#.#", "###", "..#", "..#"],
	"5": ["###", "#..", "###", "..#", "###"],
	"6": ["###", "#..", "###", "#.#", "###"],
	"7": ["###", "..#", ".#.", ".#.", ".#."],
	"8": ["###", "#.#", "###", "#.#", "###"],
	"9": ["###", "#.#", "###", "..#", "###"],
}

## The chain's FEED helper at its place (the slot just before it) and its TALLY helper (just after
## it), or -1: each hangs a clasp on its frame's end when this run holds that end of the chain.
var feeder: int = -1
var tally: int = -1
## This run's knots (slot: its factor, from the score).
var knots: Dictionary[int, int] = {}
## The last layout, in the layer's coordinates: every link ring (a pair's left then right ring,
## or a jump ring), and for each linked gap whether it holds a pair (else a jump ring) and whether
## it is beside a knot; the clasps' rings; the plates with their text.
var _link_rects: Array[Rect2] = []
var _pairs: Array[bool] = []
var _knot_links: Array[bool] = []
var _clasp_rects: Array[Rect2] = []
var _plate_rects: Array[Rect2] = []
var _plate_texts: PackedStringArray = PackedStringArray()


## The frame round the tickets at `run_slots`, a run of the chain at `chain_slots` (BatchFrame's
## `batch`; none given: the run), with the run's `run_knots` (slot: factor) and the chain's `feed`
## and `tally_slot` helpers at their places (-1: none).
func _init(
	run_slots: PackedInt32Array,
	chain_slots: PackedInt32Array = PackedInt32Array(),
	run_knots: Dictionary[int, int] = {},
	feed: int = -1,
	tally_slot: int = -1
) -> void:
	super(run_slots, chain_slots)
	name = "ChainFrame%d" % (run_slots[0] if not run_slots.is_empty() else -1)
	knots = run_knots
	feeder = feed
	tally = tally_slot


## Whether a clasp hangs on its left side (its tickets start the chain, a FEED helper at its
## place; neither the drag's ghost).
func is_fed() -> bool:
	return (
		feeder >= 0
		and not _skipped.has(feeder)
		and not _ticket_slots.is_empty()
		and _ticket_slots[0] == batch[0]
	)


## Whether a clasp hangs on its right side (its tickets end the chain, a TALLY helper at its
## place; neither the drag's ghost).
func is_tallied() -> bool:
	return (
		tally >= 0
		and not _skipped.has(tally)
		and not _ticket_slots.is_empty()
		and _ticket_slots[-1] == batch[-1]
	)


## The link rings at the last layout (layer coordinates), gap by gap: a pair's left ring then its
## right one, or a narrow gap's jump ring.
func link_rects() -> Array[Rect2]:
	return _link_rects


## Whether each linked gap (in order) holds a pair (else a jump ring).
func pairs() -> Array[bool]:
	return _pairs


## Whether each linked gap (in order) is beside a knot (lemon yellow).
func knot_links() -> Array[bool]:
	return _knot_links


## The clasps' rings at the last layout (layer coordinates), the left side's first.
func clasp_rects() -> Array[Rect2]:
	return _clasp_rects


## The knot plates at the last layout (layer coordinates) and their text, in slot order.
func plate_rects() -> Array[Rect2]:
	return _plate_rects


func plate_texts() -> PackedStringArray:
	return _plate_texts


## The chain's colours: Produce green (a knot's parts lemon), gold and paper when lit.
func paint_color(paint: Paint) -> Color:
	match paint:
		Paint.FACE:
			return LIT_MUSTARD if is_lit() else CALM_GREEN
		Paint.LIGHT:
			return LIT_LIGHT if is_lit() else CALM_GREEN_LIGHT
		Paint.KNOT_FACE:
			return LIT_MUSTARD if is_lit() else CALM_LEMON
		Paint.KNOT_LIGHT:
			return LIT_LIGHT if is_lit() else CALM_LEMON_LIGHT
	return super(paint)


## The pairs in the gaps between the tickets, the clasps by the frame's sides and the knots'
## plates on its foot.
func _place_parts(tickets: Array[Rect2]) -> void:
	_link_rects.clear()
	_pairs.clear()
	_knot_links.clear()
	_clasp_rects.clear()
	_plate_rects.clear()
	_plate_texts.clear()
	var row_scale: float = row_scale_of(tickets)
	var link_y: float = snappedf(tickets[0].position.y + LINK_TOP * row_scale, ArtStyle.ART_SCALE)
	for index: int in range(tickets.size() - 1):
		if _ticket_slots[index + 1] != _ticket_slots[index] + 1:
			continue  # The drag's ghost is between them: nothing to link yet.
		var here: Rect2 = tickets[index]
		var next: Rect2 = tickets[index + 1]
		var room: float = next.position.x - here.end.x
		var middle: float = (here.end.x + next.position.x) / 2.0
		if room < JUMP_GAP:
			continue
		if room >= PAIR_WIDTH - LINK_REACH * 2.0:
			var left: float = snappedf(middle - PAIR_WIDTH / 2.0, ArtStyle.ART_SCALE)
			_link_rects.append(Rect2(Vector2(left, link_y), LINK_SIZE))
			var right: float = left + LINK_SIZE.x - LINK_OVERLAP
			_link_rects.append(Rect2(Vector2(right, link_y), LINK_SIZE))
			_pairs.append(true)
		else:
			# On the art grid, LINK_REACH onto each ticket at most (JUMP_WIDTH at least).
			var from: float = ceilf((here.end.x - LINK_REACH) / ArtStyle.ART_SCALE)
			var to: float = floorf((next.position.x + LINK_REACH) / ArtStyle.ART_SCALE)
			var width: float = (to - from) * ArtStyle.ART_SCALE
			var jump: float = from * ArtStyle.ART_SCALE
			if width < JUMP_WIDTH:
				width = JUMP_WIDTH
				jump = snappedf(middle - width / 2.0, ArtStyle.ART_SCALE)
			_link_rects.append(Rect2(jump, link_y, width, LINK_SIZE.y))
			_pairs.append(false)
		_knot_links.append(_is_knot_at(index) or _is_knot_at(index + 1))
	var clasp: Vector2 = Vector2(CLASP_WIDTH, LINK_SIZE.y)
	if is_fed():
		var x: float = _frame_rect.position.x + RING + CLASP_INSIDE - CLASP_WIDTH
		_clasp_rects.append(Rect2(Vector2(x, link_y), clasp))
	if is_tallied():
		var x: float = _frame_rect.end.x - RING - CLASP_INSIDE
		_clasp_rects.append(Rect2(Vector2(x, link_y), clasp))
	for index: int in range(tickets.size()):
		if not _is_knot_at(index):
			continue
		var text: String = PLATE_TEXT % knots[_ticket_slots[index]]
		var plate: Vector2 = plate_size(text)
		var x: float = snappedf(tickets[index].position.x + PLATE_X * row_scale, ArtStyle.ART_SCALE)
		_plate_rects.append(Rect2(Vector2(x, _frame_rect.end.y - plate.y), plate))
		_plate_texts.append(text)


## The clasps' rings whole, under the frame (its sides cover their top's crossing).
func _add_under(origin: Vector2) -> void:
	for clasp: Rect2 in _clasp_rects:
		_add_ring(Rect2(clasp.position - origin, clasp.size), false)


## Each pair interlocked (the right ring, the left one over it, then the right ring's bottom over
## the left one's band) or jump ring, each clasp's bottom over the frame's side, and the knots'
## plates.
func _add_parts(origin: Vector2) -> void:
	var at: int = 0
	for gap: int in range(_pairs.size()):
		var knot: bool = _knot_links[gap]
		var left: Rect2 = Rect2(_link_rects[at].position - origin, _link_rects[at].size)
		at += 1
		if not _pairs[gap]:
			_add_ring(left, knot)
			continue
		var right: Rect2 = Rect2(_link_rects[at].position - origin, LINK_SIZE)
		at += 1
		_add_ring(right, knot)
		_add_ring(left, knot)
		var bottom: Rect2 = Rect2(
			right.position.x, right.end.y - LINK_BAND, right.size.x - LINK_BAND, LINK_BAND
		)
		_add_ring(right, knot, bottom)
	for clasp: Rect2 in _clasp_rects:
		var local: Rect2 = Rect2(clasp.position - origin, clasp.size)
		var side: float = 0.0 if local.position.x < 0.0 else _frame_rect.size.x - RING
		var crossing: Rect2 = Rect2(side, local.end.y - LINK_BAND, RING, LINK_BAND)
		_add_ring(local, false, crossing)
	for index: int in range(_plate_rects.size()):
		var local: Rect2 = Rect2(_plate_rects[index].position - origin, _plate_rects[index].size)
		# The ink box with its corner cells cut, the lemon face inside, the text's ink cells.
		var cut: float = PLATE_CELL
		var box: Array[Rect2] = [
			Rect2(local.position.x + cut, local.position.y, local.size.x - cut * 2.0, local.size.y),
			Rect2(local.position.x, local.position.y + cut, local.size.x, local.size.y - cut * 2.0),
		]
		_add(box, Paint.INK)
		_add([local.grow(-PLATE_BORDER)], Paint.KNOT_FACE)
		var text_at: Vector2 = local.position + Vector2.ONE * (PLATE_BORDER + PLATE_PAD)
		_add(_glyph_cells(_plate_texts[index], text_at), Paint.INK)


## Adds a ring at `rect` (a knot's when `knot`), only its part inside `clip` when given.
func _add_ring(rect: Rect2, knot: bool, clip: Rect2 = Rect2()) -> void:
	_add_band_ring(
		rect,
		LINK_INK,
		LINK_FACE,
		Paint.KNOT_FACE if knot else Paint.FACE,
		Paint.KNOT_LIGHT if knot else Paint.LIGHT,
		clip
	)


## Whether the ticket at `index` of the last layout's is a knot's.
func _is_knot_at(index: int) -> bool:
	return index < _ticket_slots.size() and knots.has(_ticket_slots[index])


## A plate's size for `text`: PLATE_GLYPHS' cells, a cell apart, in its padded box.
static func plate_size(text: String) -> Vector2:
	var cells: int = maxi(text.length() * (PLATE_GLYPH.x + 1) - 1, 0)
	var inside: float = (PLATE_BORDER + PLATE_PAD) * 2.0
	return Vector2(cells * PLATE_CELL + inside, PLATE_GLYPH.y * PLATE_CELL + inside)


## The ink cells of `text` (PLATE_GLYPHS; a character without cells is left blank) from `at`, each
## character a cell after the last.
static func _glyph_cells(text: String, at: Vector2) -> Array[Rect2]:
	var cells: Array[Rect2] = []
	for index: int in range(text.length()):
		var rows: Array = PLATE_GLYPHS.get(text[index], [])
		var left: float = at.x + index * (PLATE_GLYPH.x + 1) * PLATE_CELL
		for row: int in range(rows.size()):
			var line: String = rows[row]
			for column: int in range(line.length()):
				if line[column] == "#":
					var cell: Vector2 = Vector2(left + column * PLATE_CELL, at.y + row * PLATE_CELL)
					cells.append(Rect2(cell, Vector2.ONE * PLATE_CELL))
	return cells
