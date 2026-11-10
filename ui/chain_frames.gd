class_name ChainFrames
extends BatchFrames
## The planning layer's chain frames (#128 Produce links, the approved Linked frame): one
## ChainFrame for each run of a chain PlanningModel.chains holds (every chain, plain Banana pairs
## too; PlanningModel.chain_runs: a link that skips products splits it), each with its run's
## knots' factors and its chain's FEED and TALLY helpers at their places, all from the model.
## Everything else is BatchFrames': the layout round the belt's tickets (a drag's ghost skipped,
## followed live) and the place over the gap lights. light() lights the chain a hovered CHAIN chip
## names: the chain holding its slot, or the chain its FEED or TALLY helper at its place serves.
## Decor only.
##
## It also carries the MORNING's line and the PAIRs' clasps (KeywordMarks, v1.06, v1.24): the
## other family keywords' marks, shown, laid out and cleared with the chains (marks()), drawn over
## the chains' frames (kept the last child).
##
## follow_binding hides the GOLDEN ring on every ticket a shown frame binds, the chains' or the
## batches' (PriceSticker.set_framed: the frame is its outline then), until it unbinds.

var _marks: KeywordMarks
## The tickets whose GOLDEN ring follow_binding hid, shown again on clear_frames.
var _framed: Array[PriceSticker] = []


func _init() -> void:
	super()
	name = "ChainFrames"
	_marks = KeywordMarks.new()
	add_child(_marks)


## A frame for each run of `model`'s chains (PlanningModel.chain_runs), replacing any shown;
## laid out by follow or lay_out.
func show_chains(model: PlanningModel) -> void:
	clear_frames()
	_marks.show_marks(model)
	for index: int in range(model.chain_runs.size()):
		var run: PackedInt32Array = model.chain_runs[index]
		if run.is_empty():
			continue
		var chain: int = model.run_chain[index]
		var knots: Dictionary[int, int] = {}
		for slot: int in run:
			if model.knot_factors.has(slot):
				knots[slot] = model.knot_factors[slot]
		var feed: int = model.chain_feeds[chain] if chain < model.chain_feeds.size() else -1
		var tally: int = model.chain_tallies[chain] if chain < model.chain_tallies.size() else -1
		_adopt(ChainFrame.new(run, model.chains[chain], knots, feed, tally))
	move_child(_marks, -1)
	_paint()


func clear_frames() -> void:
	super()
	if _marks != null:
		_marks.clear_frames()
	for sticker: PriceSticker in _framed:
		if is_instance_valid(sticker):
			sticker.set_framed(false)
			RowStrip.rehang_marks_over(sticker)
	_framed.clear()


func follow(layer: Control, items: Array[ItemView], ghost: ItemView) -> void:
	_marks.note_rings(layer, items)
	super(layer, items, ghost)


## follow, then the GOLDEN ring hidden on every ticket of `items` a shown frame binds, these
## chains' or `batches`' (laid out first), and shown on every other, `ghost`'s too; the MORNING
## line, whose pins sit on a shown ring's foot, laid out again when a ring changed, and the ticket's
## slot marks hung again (RowStrip.gold_drop: no ring, no drop).
func follow_binding(
	batches: BatchFrames, layer: Control, items: Array[ItemView], ghost: ItemView
) -> void:
	follow(layer, items, ghost)
	var bound: Dictionary[int, bool] = {}
	for box: BatchFrames in [batches, self]:
		for frame: BatchFrame in box.frames():
			if frame.visible and not frame.slots.is_empty():
				for slot: int in range(frame.slots[0], frame.slots[-1] + 1):
					bound[slot] = true
	var changed: bool = false
	for slot: int in range(items.size()):
		var item: ItemView = items[slot]
		if item == null or not is_instance_valid(item) or item.sticker().gold_ring() == null:
			continue
		var framed: bool = item != ghost and bound.has(slot)
		if item.sticker().is_framed() == framed:
			continue
		changed = true
		item.sticker().set_framed(framed)
		RowStrip.rehang_marks_over(item.sticker())
		if framed:
			_framed.append(item.sticker())
		else:
			_framed.erase(item.sticker())
	if changed:
		follow(layer, items, ghost)


func lay_out(
	tickets: Dictionary[int, Rect2], skipped: PackedInt32Array = PackedInt32Array()
) -> void:
	super(tickets, skipped)
	_marks.lay_out(tickets, skipped)


## The MORNING's line and the PAIRs' clasps (KeywordMarks), laid out with the chains.
func marks() -> KeywordMarks:
	return _marks


## The chain frames, in the chains' order (hidden ones included).
func chain_frames() -> Array[ChainFrame]:
	var shown: Array[ChainFrame] = []
	for frame: BatchFrame in frames():
		shown.append(frame as ChainFrame)
	return shown


## Whether `slot`'s CHAIN chip names `frame`'s chain: the chain holds it, or it is the chain's
## FEED or TALLY helper at its place.
func _names(frame: BatchFrame, slot: int) -> bool:
	var chain: ChainFrame = frame as ChainFrame
	return chain.batch.has(slot) or chain.feeder == slot or chain.tally == slot
