class_name BatchFrames
extends Control
## The planning layer's batch frames (#128, the approved Bound strip): one BatchFrame for each run
## of a batch PlanningModel.batches frames (one holding a Bakery job card; PlanningModel.runs: a
## link that skips products splits it), laid out round its tickets from the belt's ticket rects, its
## foot at most on the counter edge (FOOT_Y). A drag's ghost has no ticket on the belt: a frame
## binds its other tickets, the ghost landing among or beside them, and follows every move of the
## drag. A frame with a slot that has no ticket otherwise (none, or hidden) hides. light() lights
## the frames a hovered BATCH chip names. PlanningLayer owns it as its z-ordered box over the rail
## strips' gap lights and under the strips and rings (tickets v5: a ticket's price is in its own
## window, so nothing hangs over a frame). Decor only: it takes no clicks.
##
## The bookends (BatchBookends, 2026-11-12): each frame reads the model's job cards; focus lights
## what a hovered job card reads, and in the count (count: the frames stay, BeltRide's fire plays
## each job card's step on them) a frame binds its batch's tickets still on the belt, the bagged
## ones dropping off its left end.
##
## ChainFrames (#128 Produce links) is this box for the chains' frames: it makes ChainFrames
## instead (show_chains) and lights the chain a CHAIN chip names (_names); the layout is shared.

## The frames' foot at most: the counter edge, where the price rail ends.
const FOOT_Y := ShiftStage.BELT_RECT.position.y + BeltPanel.RAIL.end.y

## Whether the frames move under the player's reduced motion.
var reduced_motion: bool = false
var _frames: Array[BatchFrame] = []
## In the count (count): a frame binds the tickets still shown.
var _counting: bool = false
## The slot whose BATCH chip lights its batch's frame (-1: none).
var _lit_slot: int = -1


func _init() -> void:
	name = "BatchFrames"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## A frame for each of `runs` (each in slot order), the run at an index a run of the batch at that
## index of `batches` (none given: each run is its batch), replacing any shown, its bookends
## reading `readers`' job cards; laid out by lay_out.
func show_batches(
	runs: Array[PackedInt32Array],
	batches: Array[PackedInt32Array] = [],
	readers: PlanningModel = null
) -> void:
	clear_frames()
	for index: int in range(runs.size()):
		if runs[index].is_empty():
			continue
		var batch: PackedInt32Array = batches[index] if index < batches.size() else runs[index]
		var frame: BatchFrame = BatchFrame.new(runs[index], batch)
		frame.readers = readers
		frame.reduced_motion = reduced_motion
		_adopt(frame)
	_paint()


## The count's look: the frames stay, unfocused, each round its tickets still on the belt.
func count() -> void:
	_counting = true
	focus(-1)


## Planning's hover: every frame's bookends light what the job card at `slot` reads (-1: none).
func focus(slot: int) -> void:
	for frame: BatchFrame in frames():
		frame.focus(slot)


## The count: step `step` landed; every frame's bookends play its beat (BatchBookends.fire).
func fire(step: ScoreStep, make_tween: Callable = Callable()) -> void:
	for frame: BatchFrame in frames():
		frame.fire(step, make_tween)


## Takes every frame off (the count, or the next model).
func clear_frames() -> void:
	_counting = false
	for frame: BatchFrame in _frames:
		if is_instance_valid(frame):
			remove_child(frame)
			frame.queue_free()
	_frames.clear()


## Lays the frames out round the tickets of `items` (the view showing each slot, null for none)
## in `layer`'s coordinates: every slot's with a shown belt view (`ghost`'s slot skipped).
func follow(layer: Control, items: Array[ItemView], ghost: ItemView) -> void:
	var tickets: Dictionary[int, Rect2] = {}
	var skipped: PackedInt32Array = PackedInt32Array()
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
		tickets[slot] = to_ticket * Rect2(Vector2.ZERO, sticker.size)
	lay_out(tickets, skipped)


## Places each frame round `tickets` (slot: its ticket's rect on the belt, layer coordinates);
## a `skipped` slot (the drag's ghost) has no ticket to bind, and a frame missing any other slot's
## ticket hides.
func lay_out(
	tickets: Dictionary[int, Rect2], skipped: PackedInt32Array = PackedInt32Array()
) -> void:
	for frame: BatchFrame in frames():
		var rects: Array[Rect2] = []
		var shown: PackedInt32Array = PackedInt32Array()
		for slot: int in range(frame.slots[0], frame.slots[-1] + 1):
			if skipped.has(slot) or _counting and not tickets.has(slot):
				continue
			if not tickets.has(slot):
				rects.clear()
				shown.clear()
				break
			rects.append(tickets[slot])
			shown.append(slot)
		frame.lay_out(rects, FOOT_Y, shown, skipped, PackedInt32Array(tickets.keys()))


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
