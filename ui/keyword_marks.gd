class_name KeywordMarks
extends BatchFrames
## The planning layer's MORNING and PAIR marks (v1.06, the keywords handbook: "MORNING and PAIR
## miss a visual on the ticket", where a BATCH has its mustard frame and a CHAIN its green one).
##
## MORNING (PlanningModel.mornings: the row's opening Breakfast run, shown when a card in the row
## reads it): a ribbon (MorningRibbon) hung under the run's tickets, from the first one's left to
## the last one's right, tucked RIBBON_TUCK under their feet (under a GOLDEN ticket's gold ring
## when one is in the run), with the rising sun (art/icons/morning_sun.png) and the MORNING chip
## on its left end. The marks that hang in the same band cut it, so it never covers them: a slot's
## SlotMark (`obstacles`: the row's, from RowStrip.mark_rects) and a chain's knot plate.
## PAIR (PlanningModel.pairs): a Dairy teal clasp (art/icons/pair_clasp.png, CLASP_SIZE at 2x)
## across each gap between a PAIR item's ticket and its partner's (a coupon a link skips between
## them gets a clasp in each gap). A row's scaled tickets scale the clasps. A clasp sits
## CLASP_TOPS[0] down the tickets, or the next of CLASP_TOPS when a frame's part would meet it
## there (a batch's binding bar, a chain's link, clasp or knot plate); it draws over the frames
## (ChainFrames keeps this layer last), so a batch or chain frame's side in its gap runs under it.
##
## The layout is BatchFrames': follow reads the belt's ticket rects (a drag's ghost skipped) and
## calls lay_out; a mark missing a ticket hides. Decor only: it takes no clicks (the ribbon's chip
## shows its tooltip through GlyphTips, as a ticket's does).

const CLASP := preload("res://art/icons/pair_clasp.png")
const CLASP_SIZE := Vector2(24, 14)
## The clasp's top under the ticket's top on an unscaled ticket, in order of preference: over the
## batch bars' and chain links' band, else under it.
const CLASP_TOPS: Array[float] = [30.0, 56.0]
const TICKET_HEIGHT := PriceSticker.SIZE.y
## The ribbon's top this far over the tickets' feet (under their bottom outline).
const RIBBON_TUCK := 2.0
## Its path under a planning layer (or a handbook clip).
const PATH := ^"ChainFrames/KeywordMarks"

## Returns the global rects of the marks hanging under the row's tickets (RowStrip.mark_rects),
## which cut the ribbon. None: no such marks.
var obstacles: Callable = Callable()
## The MORNING's slots, and each clasp's gap (the slots on its left and right), as shown.
var _morning: PackedInt32Array = PackedInt32Array()
var _clasp_gaps: Array[Vector2i] = []
var _ribbon: MorningRibbon
var _clasps: Array[TextureRect] = []
## Each GOLDEN ticket's gold ring at the last follow (slot: its rect, layer coordinates).
var _rings: Dictionary[int, Rect2] = {}


func _init() -> void:
	super()
	name = "KeywordMarks"
	_ribbon = MorningRibbon.new()
	_ribbon.visible = false
	add_child(_ribbon)


## The marks of the planning layer (or handbook clip) `layer`, or null.
static func of(layer: Node) -> KeywordMarks:
	return layer.get_node_or_null(PATH) as KeywordMarks


## The marks of `model` (its MORNING's tickets and its PAIRs' gaps), replacing any shown; laid out
## by follow or lay_out.
func show_marks(model: PlanningModel) -> void:
	clear_frames()
	_morning = model.mornings.duplicate()
	for pair: Vector2i in model.pairs:
		for left: int in range(pair.x, pair.y):
			var gap: Vector2i = Vector2i(left, left + 1)
			if _clasp_gaps.has(gap):
				continue
			_clasp_gaps.append(gap)
			var clasp: TextureRect = UiKit.sprite(CLASP)
			clasp.name = "PairClasp%d" % left
			add_child(clasp)
			_clasps.append(clasp)
	# Hidden with no mark, so the layer's parts() never counts the empty box.
	visible = not _morning.is_empty() or not _clasps.is_empty()


func clear_frames() -> void:
	super()
	for clasp: TextureRect in _clasps:
		if is_instance_valid(clasp):
			remove_child(clasp)
			clasp.queue_free()
	_clasps.clear()
	_clasp_gaps.clear()
	_morning.clear()
	if _ribbon != null:
		_ribbon.visible = false
	visible = false


## Hangs the ribbon under the MORNING's tickets and places each clasp across its gap, from
## `tickets` (slot: its ticket's rect, layer coordinates); a mark missing a ticket (or on
## `skipped`'s ghost) hides.
func lay_out(
	tickets: Dictionary[int, Rect2], skipped: PackedInt32Array = PackedInt32Array()
) -> void:
	_lay_out_ribbon(tickets, skipped)
	var parts: Array[Rect2] = _frame_parts(false)
	for index: int in range(_clasps.size()):
		var gap: Vector2i = _clasp_gaps[index]
		var clasp: TextureRect = _clasps[index]
		clasp.visible = tickets.has(gap.x) and tickets.has(gap.y)
		if clasp.visible:
			var left: Rect2 = tickets[gap.x]
			var right: Rect2 = tickets[gap.y]
			var by: float = left.size.y / TICKET_HEIGHT
			clasp.size = (CLASP_SIZE * by).round()
			var middle: float = (left.end.x + right.position.x) / 2.0
			for top: float in CLASP_TOPS:
				var at: Vector2 = Vector2(middle - clasp.size.x / 2.0, left.position.y + top * by)
				clasp.position = at.round()
				if not _meets(Rect2(clasp.position, clasp.size), parts):
					break


## Notes each GOLDEN ticket's gold ring among `items` (in `layer`'s coordinates): the ribbon hangs
## under a ring in its run (ChainFrames.follow calls it before laying out).
func note_rings(layer: Control, items: Array[ItemView]) -> void:
	_rings.clear()
	var to_layer: Transform2D = layer.get_global_transform().affine_inverse()
	for slot: int in range(items.size()):
		var item: ItemView = items[slot]
		if item == null or not is_instance_valid(item) or not item.is_visible_in_tree():
			continue
		var ring: TextureRect = item.sticker().gold_ring()
		if ring != null and ring.is_visible_in_tree():
			_rings[slot] = to_layer * ring.get_global_rect()


## The MORNING's ribbon (hidden with no MORNING shown).
func ribbon() -> MorningRibbon:
	return _ribbon


## The ribbon's pieces at the last layout (layer coordinates), left to right; none when hidden.
func ribbon_rects() -> Array[Rect2]:
	var shown: Array[Rect2] = []
	if _ribbon.visible:
		for piece: Rect2 in _ribbon.pieces():
			shown.append(Rect2(piece.position + _ribbon.position, piece.size))
	return shown


## The MORNING's slots the ribbon hangs under.
func morning_slots() -> PackedInt32Array:
	return _morning.duplicate()


## The clasps shown (hidden ones included), in the gaps' order.
func clasps() -> Array[TextureRect]:
	return _clasps.duplicate()


## The gap each clasp crosses (its left and right slots), in clasps()' order.
func clasp_gaps() -> Array[Vector2i]:
	return _clasp_gaps.duplicate()


func _lay_out_ribbon(tickets: Dictionary[int, Rect2], skipped: PackedInt32Array) -> void:
	var shown: PackedInt32Array = PackedInt32Array()
	for slot: int in _morning:
		if skipped.has(slot):
			continue
		if not tickets.has(slot):
			shown.clear()
			break
		shown.append(slot)
	_ribbon.visible = not shown.is_empty()
	if not _ribbon.visible:
		return
	# From the first ticket's left to the last's right, under the lowest foot (a gold ring's).
	var left: float = tickets[shown[0]].position.x
	var right: float = tickets[shown[-1]].end.x
	var foot: float = -INF
	for slot: int in shown:
		foot = maxf(foot, tickets[slot].end.y)
		if _rings.has(slot):
			foot = maxf(foot, _rings[slot].end.y)
	var band: Rect2 = Rect2(
		Vector2(left, foot - RIBBON_TUCK).round(),
		Vector2(roundf(right - left), MorningRibbon.HEIGHT)
	)
	var cuts: Array[Vector2] = []
	for part: Rect2 in _hanging_marks():
		if part.intersects(band):
			cuts.append(Vector2(part.position.x - band.position.x, part.end.x - band.position.x))
	_ribbon.position = band.position
	_ribbon.set_width(band.size.x, cuts)


## The marks hanging under the tickets (layer coordinates): the row's slot marks (`obstacles`)
## and the chains' knot plates.
func _hanging_marks() -> Array[Rect2]:
	var marks: Array[Rect2] = _frame_parts(true)
	if obstacles.is_valid():
		var to_layer: Transform2D = get_global_transform().affine_inverse()
		for rect: Rect2 in obstacles.call():
			marks.append(to_layer * rect)
	return marks


## The parts of the frames on this layer (every BatchFrames box beside this one's parent, each
## laid out before it): the knot plates only when `plates_only`, else every binding bar, chain
## link, chain clasp and knot plate (a clasp keeps clear of them).
func _frame_parts(plates_only: bool) -> Array[Rect2]:
	var parts: Array[Rect2] = []
	var box: Node = get_parent()
	if box == null or box.get_parent() == null:
		return parts
	for node: Node in box.get_parent().get_children():
		var frames_box: BatchFrames = node as BatchFrames
		if frames_box == null:
			continue
		for frame: BatchFrame in frames_box.frames():
			if not frame.visible:
				continue
			var chain: ChainFrame = frame as ChainFrame
			if chain != null:
				parts.append_array(chain.plate_rects())
				if not plates_only:
					parts.append_array(chain.link_rects())
					parts.append_array(chain.clasp_rects())
			elif not plates_only:
				parts.append_array(frame.bar_rects())
	return parts


static func _meets(rect: Rect2, parts: Array[Rect2]) -> bool:
	for part: Rect2 in parts:
		if rect.intersects(part):
			return true
	return false
