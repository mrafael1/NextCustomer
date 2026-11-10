class_name KeywordMarks
extends BatchFrames
## The planning layer's MORNING and PAIR marks (v1.06, the keywords handbook: "MORNING and PAIR
## miss a visual on the ticket", where a BATCH has its mustard frame and a CHAIN its green one).
##
## MORNING (PlanningModel.mornings: the row's opening Breakfast run, shown when a card in the row
## reads it; v1.24, the user's picks of 2026-11-10: the mock-up morning_mark.html's pins, then
## "continuity, like banana" and "having the item on the 1st slot", in place of v1.06's ribbon):
## one line of the Breakfast's colours along the tickets' feet. A pin (MorningPin: the MORNING
## chip's Breakfast dot at 2x) on the foot of each ticket of the run, the first one's too,
## PIN_LEFT in from its left and PIN_OVER over its foot (a GOLDEN ticket's gold ring's foot while
## the ring shows: its pin sits that much lower). A chain (MorningLink: the CHAIN's language at the
## pins' size: a cord along the tickets' feet, a pair of interlocked rings across each gap
## between two tickets) runs level through the pins' middles, under them, from an anchor post
## (MorningPin.post) POST_OUT before the row's first ticket, in the belt's margin at the row's
## start, to the run's last pin: the run is one connected line, and it starts at the first slot
## (coupons before the run's first item, which don't break it, are crossed too). The marks that
## hang in the same band keep theirs (a slot's SlotMark, `obstacles`: the row's, from
## RowStrip.mark_rects; a chain's knot plate): a pin that would meet one steps aside along its
## ticket's foot, PIN_GAP clear of it, to the nearest free place, and hides with no room left; the
## chain is cut PIN_GAP short of each such mark and goes on after it, as if it ran on behind
## it, so it stays continuous however the pins step aside or hide (it runs to the run's last
## ticket's pin place even when that pin hides). Every pin, the post and each stretch
## of chain is the MORNING's tip target on the belt (MorningMark: its tooltip, and a right-click
## opens the handbook at MORNING); lit (light_morning: a MORNING tooltip shows, a ticket's chip's
## or the line's own) the whole line turns gold.
## PAIR (PlanningModel.pairs): a Dairy teal clasp (art/icons/pair_clasp.png, CLASP_SIZE at 2x)
## across each gap between a PAIR item's ticket and its partner's (a coupon a link skips between
## them gets a clasp in each gap). A row's scaled tickets scale the MORNING's line and the clasps.
## A clasp sits CLASP_TOPS[0] down the tickets, or the next of CLASP_TOPS when a frame's part
## would meet it there (a batch's binding bar, a chain's link, clasp or knot plate); it draws over
## the frames (ChainFrames keeps this layer last), so a batch or chain frame's side in its gap
## runs under it, as a frame's foot runs under the pins on it.
##
## The layout is BatchFrames': follow reads the belt's ticket rects (a drag's ghost skipped) and
## calls lay_out; a mark missing a ticket hides. Decor only: it takes no clicks (the MORNING's pins,
## post and chain show MORNING's tooltip through GlyphTips, as a ticket's chips do).

const CLASP := preload("res://art/icons/pair_clasp.png")
const CLASP_SIZE := Vector2(24, 14)
## The clasp's top under the ticket's top on an unscaled ticket, in order of preference: over the
## batch bars' and chain links' band, else under it.
const CLASP_TOPS: Array[float] = [30.0, 56.0]
const TICKET_HEIGHT := PriceSticker.SIZE.y
## A pin's left in from its ticket's and its top over the ticket's foot, on an unscaled ticket
## (the mock-up's 5 and 3 art px).
const PIN_LEFT := 10.0
const PIN_OVER := 6.0
## The room a pin or the chain keeps from a hanging mark, and a pin from its ticket's ends.
const PIN_GAP := 2.0
const PIN_INSET := 2.0
## How far under the tickets' feet the MORNING's marks reach at most on an unscaled row (a pin's
## shadow); v1.06's ribbon reached 20.
const PIN_REACH := MorningPin.SIDE + MorningPin.SHADOW.y - PIN_OVER
## The anchor post's left this far before the row's first ticket's (unscaled): in the belt's
## margin before the first slot.
const POST_OUT := 10.0
## The shortest stretch of chain drawn between two cuts.
const MIN_LINK := 4.0
## Its path under a planning layer (or a handbook clip).
const PATH := ^"ChainFrames/KeywordMarks"

## Returns the global rects of the marks hanging under the row's tickets (RowStrip.mark_rects),
## which the MORNING's pins and chain keep clear of. None: no such marks.
var obstacles: Callable = Callable()
## The MORNING's slots, and each clasp's gap (the slots on its left and right), as shown.
var _morning: PackedInt32Array = PackedInt32Array()
var _clasp_gaps: Array[Vector2i] = []
## A pin for each of the MORNING's slots, in their order; the anchor post at the row's start; the
## chain's stretches (a pool: the ones past the last layout's hidden).
var _pins: Array[MorningPin] = []
var _post: MorningPin
var _links: Array[MorningLink] = []
var _lit: bool = false
var _clasps: Array[TextureRect] = []
## Each GOLDEN ticket's gold ring at the last follow (slot: its rect, layer coordinates).
var _rings: Dictionary[int, Rect2] = {}


func _init() -> void:
	super()
	name = "KeywordMarks"
	_post = MorningPin.new(true)
	_post.name = "MorningPost"
	_post.visible = false
	_post.on_tip = light_morning
	add_child(_post)


## The marks of the planning layer (or handbook clip) `layer`, or null.
static func of(layer: Node) -> KeywordMarks:
	return layer.get_node_or_null(PATH) as KeywordMarks


## The marks of `model` (its MORNING's tickets and its PAIRs' gaps), replacing any shown; laid out
## by follow or lay_out.
func show_marks(model: PlanningModel) -> void:
	clear_frames()
	_morning = model.mornings.duplicate()
	for slot: int in _morning:
		var pin: MorningPin = MorningPin.new()
		pin.name = "MorningPin%d" % slot
		pin.visible = false
		pin.set_lit(_lit)
		pin.on_tip = light_morning
		add_child(pin)
		_pins.append(pin)
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
	for pin: MorningPin in _pins:
		if is_instance_valid(pin):
			remove_child(pin)
			pin.queue_free()
	_pins.clear()
	_morning.clear()
	if _post != null:
		_post.visible = false
	for link: MorningLink in _links:
		link.visible = false
	visible = false


## Lays the MORNING's line (its post, chain and pins) along its tickets and places each clasp
## across its gap, from `tickets` (slot: its ticket's rect, layer coordinates); a mark missing a
## ticket (or on `skipped`'s ghost) hides.
func lay_out(
	tickets: Dictionary[int, Rect2], skipped: PackedInt32Array = PackedInt32Array()
) -> void:
	_lay_out_pins(tickets, skipped)
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


## Notes each GOLDEN ticket's gold ring among `items` (in `layer`'s coordinates): a pin sits on
## the foot of its ticket's ring (ChainFrames.follow calls it before laying out).
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


## The anchor post at the row's start (hidden with no MORNING shown).
func post() -> MorningPin:
	return _post


## The chain's stretches shown at the last layout, left to right.
func links() -> Array[MorningLink]:
	var shown: Array[MorningLink] = []
	for link: MorningLink in _links:
		if link.visible:
			shown.append(link)
	return shown


## The pins, one for each of morning_slots() in their order, hidden ones included (one with no
## room on its ticket's foot).
func pins() -> Array[MorningPin]:
	return _pins.duplicate()


## The MORNING's slots the pins mark.
func morning_slots() -> PackedInt32Array:
	return _morning.duplicate()


## Lights the MORNING's line, its pins, post and chain (a MORNING tooltip shows), or puts it back.
func light_morning(lit: bool) -> void:
	_lit = lit
	for mark: MorningMark in _morning_parts():
		mark.set_lit(lit)


## Every part of the MORNING's line, shown or not: the pins, the post and the chain's stretches.
func _morning_parts() -> Array[MorningMark]:
	var parts: Array[MorningMark] = []
	parts.append_array(_pins)
	if _post != null:
		parts.append(_post)
	parts.append_array(_links)
	return parts


## The clasps shown (hidden ones included), in the gaps' order.
func clasps() -> Array[TextureRect]:
	return _clasps.duplicate()


## The gap each clasp crosses (its left and right slots), in clasps()' order.
func clasp_gaps() -> Array[Vector2i]:
	return _clasp_gaps.duplicate()


func _lay_out_pins(tickets: Dictionary[int, Rect2], skipped: PackedInt32Array) -> void:
	var shown: PackedInt32Array = PackedInt32Array()
	for slot: int in _morning:
		if skipped.has(slot):
			continue
		if not tickets.has(slot):
			shown.clear()
			break
		shown.append(slot)
	for mark: MorningMark in _morning_parts():
		mark.visible = false
	if shown.is_empty():
		return
	# Scaled with the row's tickets; the line level on the run's plain feet.
	var by: float = tickets[shown[0]].size.y / TICKET_HEIGHT
	var marks: Array[Rect2] = _hanging_marks()
	var foot: float = -INF
	var row_left: float = INF
	for slot: int in tickets:
		row_left = minf(row_left, tickets[slot].position.x)
	for slot: int in shown:
		foot = maxf(foot, tickets[slot].end.y)
	var line_top: float = roundf(foot - PIN_OVER * by)
	var line_end: float = NAN
	for slot: int in shown:
		var pin: MorningPin = _pins[_morning.find(slot)]
		var top: float = _pin_top(tickets[slot], slot, by)
		var pin_room: Rect2 = Rect2(Vector2(0, top), MorningPin.footprint() * by)
		var x: float = _free_x(tickets[slot], pin_room, by, marks)
		pin.visible = not is_nan(x)
		if pin.visible:
			pin.scale = Vector2(by, by)
			pin.position = Vector2(x, top)
			line_end = x + MorningPin.SIDE * by / 2.0
		else:
			line_end = roundf(tickets[slot].position.x + (PIN_LEFT + MorningPin.SIDE / 2.0) * by)
	_post.visible = true
	_post.scale = Vector2(by, by)
	_post.position = Vector2(roundf(row_left - POST_OUT * by), line_top)
	var line_start: float = _post.position.x + MorningPin.POST_WIDTH * by / 2.0
	_lay_out_chain(line_start, line_end, line_top, by, marks, _gap_middles(tickets))


## The middles of the gaps between `tickets` side by side (layer x), left to right.
static func _gap_middles(tickets: Dictionary[int, Rect2]) -> PackedFloat32Array:
	var rects: Array[Rect2] = tickets.values()
	rects.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	var middles: PackedFloat32Array = PackedFloat32Array()
	for index: int in range(rects.size() - 1):
		middles.append((rects[index].end.x + rects[index + 1].position.x) / 2.0)
	return middles


## The chain from `start` to `end` (layer x), its middle on a pin's middle at `top`, scaled `by`,
## crossing the tickets' gaps at `gaps` (layer x) with its ring pairs, cut round each of `marks` it
## would meet: a stretch (MorningLink) between the cuts.
func _lay_out_chain(
	start: float, end: float, top: float, by: float, marks: Array[Rect2], gaps: PackedFloat32Array
) -> void:
	var link_top: float = top + roundf((MorningPin.SIDE - MorningLink.RING.y) * by / 2.0)
	var band: Rect2 = Rect2(start, link_top, end - start, MorningLink.RING.y * by)
	var cuts: Array[Vector2] = []
	for mark: Rect2 in marks:
		if mark.intersects(band):
			cuts.append(Vector2(mark.position.x - PIN_GAP, mark.end.x + PIN_GAP))
	cuts.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var stretches: Array[Vector2] = []
	var from: float = start
	for gap: Vector2 in cuts:
		if gap.x - from >= MIN_LINK:
			stretches.append(Vector2(from, minf(floorf(gap.x), end)))
		from = maxf(from, ceilf(gap.y))
		if from >= end:
			break
	if end - from >= MIN_LINK:
		stretches.append(Vector2(from, end))
	for index: int in range(stretches.size()):
		if index >= _links.size():
			var made: MorningLink = MorningLink.new()
			made.name = "MorningLink%d" % index
			made.set_lit(_lit)
			made.on_tip = light_morning
			add_child(made)
			# Under the pins and the post.
			move_child(made, 0)
			_links.append(made)
		var link: MorningLink = _links[index]
		var stretch: Vector2 = stretches[index]
		if stretch.y <= stretch.x:
			continue
		link.visible = true
		link.scale = Vector2(by, by)
		link.position = Vector2(stretch.x, link_top)
		var crossed: PackedFloat32Array = PackedFloat32Array()
		for middle: float in gaps:
			if middle > stretch.x and middle < stretch.y:
				crossed.append((middle - stretch.x) / by)
		link.set_stretch((stretch.y - stretch.x) / by, crossed)


## A pin's top on `slot`'s `ticket`: PIN_OVER (scaled `by`) over its foot, its gold ring's foot
## while one shows (note_rings).
func _pin_top(ticket: Rect2, slot: int, by: float) -> float:
	var foot: float = ticket.end.y
	if _rings.has(slot):
		foot = maxf(foot, _rings[slot].end.y)
	return roundf(foot - PIN_OVER * by)


## Where a part (`room`: its top and its size; a pin's with its shadow) goes on
## `ticket`'s foot, its left: PIN_LEFT in from the ticket's (scaled `by`), or the nearest place to
## it along the ticket (PIN_INSET in from its ends) that keeps PIN_GAP clear of every one of
## `marks`; NAN when the ticket has no such place.
static func _free_x(ticket: Rect2, room: Rect2, by: float, marks: Array[Rect2]) -> float:
	var from: float = ceilf(ticket.position.x + PIN_INSET * by)
	var to: float = floorf(ticket.end.x - PIN_INSET * by) - room.size.x
	var want: float = roundf(ticket.position.x + PIN_LEFT * by)
	var blocks: Array[Vector2] = []
	var places: Array[float] = [want]
	for mark: Rect2 in marks:
		if mark.end.y <= room.position.y or mark.position.y >= room.end.y:
			continue
		if mark.end.x <= ticket.position.x or mark.position.x >= ticket.end.x:
			continue
		var block: Vector2 = Vector2(mark.position.x - PIN_GAP, mark.end.x + PIN_GAP)
		blocks.append(block)
		places.append(floorf(block.x - room.size.x))
		places.append(ceilf(block.y))
	var found: float = NAN
	for place: float in places:
		if place < from or place > to:
			continue
		var free: bool = true
		for block: Vector2 in blocks:
			free = free and (place + room.size.x <= block.x or place >= block.y)
		if free and (is_nan(found) or absf(place - want) < absf(found - want)):
			found = place
	return found


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
