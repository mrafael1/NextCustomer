class_name KeywordMarks
extends BatchFrames
## The planning layer's PAIR marks (v1.06, the keywords handbook: "MORNING and PAIR miss a visual
## on the ticket", where a BATCH has its mustard frame and a CHAIN its green one).
##
## PAIR (PlanningModel.pairs): a Dairy teal clasp (art/icons/pair_clasp.png, CLASP_SIZE at 2x)
## across each gap between a PAIR item's ticket and its partner's (a coupon a link skips between
## them gets a clasp in each gap). A row's scaled tickets scale the clasps.
## A clasp sits CLASP_TOPS[0] down the tickets, or the next of CLASP_TOPS when a frame's part
## would meet it there (a batch's binding bar, a chain's link, clasp or knot plate); it draws over
## the frames (ChainFrames keeps this layer last), so a batch or chain frame's side in its gap
## runs under it.
##
## MORNING has no mark here since the MORNING ZONE (2026-11-18, in place of v1.24's pins, chain
## and post): the zone is printed on the belt's first slots (MorningBand, on the RowStrip's
## cells). light_morning (a MORNING chip's tooltip shows on a ticket) passes on to
## `morning_light`, which the stage points at that print.
##
## The layout is BatchFrames': follow reads the belt's ticket rects (a drag's ghost skipped) and
## calls lay_out; a mark missing a ticket hides. Decor only: it takes no clicks.

const CLASP := preload("res://art/icons/pair_clasp.png")
const CLASP_SIZE := Vector2(24, 14)
## The clasp's top under the ticket's top on an unscaled ticket, in order of preference: over the
## batch bars' and chain links' band, else under it.
const CLASP_TOPS: Array[float] = [30.0, 56.0]
const TICKET_HEIGHT := PriceSticker.SIZE.y
## Its path under a planning layer (or a handbook clip).
const PATH := ^"ChainFrames/KeywordMarks"

## Called with whether the MORNING ZONE's print lights (light_morning): the stage's, or a
## handbook clip's (MorningBand.light on their row). None: nothing.
var morning_light: Callable = Callable()
## Each clasp's gap (the slots on its left and right), as shown.
var _clasp_gaps: Array[Vector2i] = []
var _clasps: Array[TextureRect] = []


func _init() -> void:
	super()
	name = "KeywordMarks"


## The marks of the planning layer (or handbook clip) `layer`, or null.
static func of(layer: Node) -> KeywordMarks:
	return layer.get_node_or_null(PATH) as KeywordMarks


## The marks of `model` (its PAIRs' gaps), replacing any shown; laid out by follow or lay_out.
func show_marks(model: PlanningModel) -> void:
	clear_frames()
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
	visible = not _clasps.is_empty()


func clear_frames() -> void:
	super()
	for clasp: TextureRect in _clasps:
		if is_instance_valid(clasp):
			remove_child(clasp)
			clasp.queue_free()
	_clasps.clear()
	_clasp_gaps.clear()
	visible = false


## Places each clasp across its gap, from `tickets` (slot: its ticket's rect, layer coordinates);
## a clasp missing a ticket hides.
func lay_out(
	tickets: Dictionary[int, Rect2], _skipped: PackedInt32Array = PackedInt32Array()
) -> void:
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


## A MORNING chip's tooltip shows on a ticket (or went): the zone's print on the belt lights.
func light_morning(lit: bool) -> void:
	if morning_light.is_valid():
		morning_light.call(lit)


## The clasps shown (hidden ones included), in the gaps' order.
func clasps() -> Array[TextureRect]:
	return _clasps.duplicate()


## The gap each clasp crosses (its left and right slots), in clasps()' order.
func clasp_gaps() -> Array[Vector2i]:
	return _clasp_gaps.duplicate()


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
