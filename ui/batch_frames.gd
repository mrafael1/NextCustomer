class_name BatchFrames
extends Control
## The planning layer's batch frames (#128, the approved Bound strip): one BatchFrame for each run
## of a batch PlanningModel.batches frames (one holding a Bakery job card; PlanningModel.runs: a
## link that skips products splits it), laid out round its tickets from the belt's ticket rects,
## passing behind their price tags, its foot at most on the counter edge (FOOT_Y). A drag's ghost
## has no ticket on the belt: a frame binds its other tickets, the ghost landing among or beside
## them, and follows every move of the drag. A frame with a slot that has no ticket otherwise (none,
## or hidden) hides. A wrong job's tomato ring (PriceSticker.set_wrong_job) stays closed over a
## frame's foot. light() lights the frames a hovered BATCH chip names. PlanningLayer owns it as its
## z-ordered box over the rail strips' gap lights and under the strips, rings and pay tags, so a
## pinned pay tag covers the frame where it hangs over it; a ticket's plain tag (the sticker's,
## under the layer) is left open in the frame along its own outline, so the frame still reads as
## passing behind it. Decor only: it takes no clicks.
##
## ChainFrames (#128 Produce links) is this box for the chains' frames: it makes ChainFrames
## instead (show_chains) and lights the chain a CHAIN chip names (_names); the layout is shared.

## The frames' foot at most: the counter edge, where the price rail ends.
const FOOT_Y := ShiftStage.BELT_RECT.position.y + BeltPanel.RAIL.end.y

var _frames: Array[BatchFrame] = []
## The slot whose BATCH chip lights its batch's frame (-1: none).
var _lit_slot: int = -1


func _init() -> void:
	name = "BatchFrames"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## A frame for each of `runs` (each in slot order), the run at an index a run of the batch at that
## index of `batches` (none given: each run is its batch), replacing any shown; laid out by
## lay_out.
func show_batches(runs: Array[PackedInt32Array], batches: Array[PackedInt32Array] = []) -> void:
	clear_frames()
	for index: int in range(runs.size()):
		if runs[index].is_empty():
			continue
		var batch: PackedInt32Array = batches[index] if index < batches.size() else runs[index]
		_adopt(BatchFrame.new(runs[index], batch))
	_paint()


## Takes every frame off (the count, or the next model).
func clear_frames() -> void:
	for frame: BatchFrame in _frames:
		if is_instance_valid(frame):
			remove_child(frame)
			frame.queue_free()
	_frames.clear()


## Lays the frames out round the tickets of `items` (the view showing each slot, null for none)
## in `layer`'s coordinates: every slot's with a shown belt view (`ghost`'s slot skipped), open at
## its plain tag when no pay tag is pinned on it in `pays` (slot: its tag, a child of `layer`'s,
## drawn over the frame), and with every wrong job's tomato ring.
func follow(
	layer: Control, items: Array[ItemView], ghost: ItemView, pays: Dictionary[int, PayTag]
) -> void:
	var tickets: Dictionary[int, Rect2] = {}
	var cutouts: Dictionary[int, Rect2] = {}
	var skipped: PackedInt32Array = PackedInt32Array()
	var rings: Array[Rect2] = []
	var to_layer: Transform2D = layer.get_global_transform().affine_inverse()
	for slot: int in range(items.size()):
		var item: ItemView = items[slot]
		if item == null or not is_instance_valid(item):
			continue
		if item == ghost:
			skipped.append(slot)
			continue
		if not item.is_visible_in_tree():
			continue
		var sticker: PriceSticker = item.sticker()
		var to_ticket: Transform2D = to_layer * sticker.get_global_transform()
		tickets[slot] = to_ticket * Rect2(Vector2.ZERO, PriceSticker.SIZE)
		var plain: PayTag = sticker.plain_tag()
		if not pays.has(slot) and plain != null and plain.visible:
			cutouts[slot] = to_ticket * sticker.plain_tag_rect()
		if not sticker.summary().keyword_wasted().is_empty():
			for side: Rect2 in PriceSticker.wrong_ring_sides():
				rings.append(to_ticket * side)
	lay_out(tickets, cutouts, skipped, rings)


## Places each frame round `tickets` (slot: its ticket's rect on the belt, layer coordinates),
## open at `cutouts` (slot: its plain price tag's rect), over `rings` (the wrong jobs' tomato ring
## sides); a `skipped` slot (the drag's ghost) has no ticket to bind, and a frame missing any
## other slot's ticket hides.
func lay_out(
	tickets: Dictionary[int, Rect2],
	cutouts: Dictionary[int, Rect2],
	skipped: PackedInt32Array = PackedInt32Array(),
	rings: Array[Rect2] = []
) -> void:
	for frame: BatchFrame in frames():
		var rects: Array[Rect2] = []
		var shown: PackedInt32Array = PackedInt32Array()
		var cuts: Array[Rect2] = []
		for slot: int in range(frame.slots[0], frame.slots[-1] + 1):
			if skipped.has(slot):
				continue
			if not tickets.has(slot):
				rects.clear()
				shown.clear()
				break
			rects.append(tickets[slot])
			shown.append(slot)
			if cutouts.has(slot):
				cuts.append(cutouts[slot])
		frame.lay_out(rects, cuts, FOOT_Y, rings, shown, skipped)


## Lights the frame of every batch `slot`'s BATCH chip names (the batch holding it, or for a card
## that names the batch after it, Birthday candles, the batch starting just after it); -1: none.
func light(slot: int) -> void:
	_lit_slot = slot
	_paint()


## The frames, in the batches' order (hidden ones included).
func frames() -> Array[BatchFrame]:
	var shown: Array[BatchFrame] = []
	for frame: BatchFrame in _frames:
		if is_instance_valid(frame) and not frame.is_queued_for_deletion():
			shown.append(frame)
	return shown


## Adds `frame` to the frames shown.
func _adopt(frame: BatchFrame) -> void:
	add_child(frame)
	_frames.append(frame)


## Lights each frame a chip of `_lit_slot` names (_names), puts the others back.
func _paint() -> void:
	for frame: BatchFrame in frames():
		frame.set_lit(_lit_slot >= 0 and _names(frame, _lit_slot))


## Whether `slot`'s BATCH chip names `frame`'s batch: the batch holds it, or (a card that names the
## batch after it, Birthday candles) the batch starts just after it.
func _names(frame: BatchFrame, slot: int) -> bool:
	return frame.batch.has(slot) or frame.batch[0] == slot + 1
