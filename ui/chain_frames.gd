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
## It also carries the MORNING's ribbon and the PAIRs' clasps (KeywordMarks, v1.06): the other
## family keywords' marks, shown, laid out and cleared with the chains (marks()), drawn over the
## chains' frames (kept the last child).

var _marks: KeywordMarks


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


func follow(layer: Control, items: Array[ItemView], ghost: ItemView) -> void:
	_marks.note_rings(layer, items)
	super(layer, items, ghost)


func lay_out(
	tickets: Dictionary[int, Rect2], skipped: PackedInt32Array = PackedInt32Array()
) -> void:
	super(tickets, skipped)
	_marks.lay_out(tickets, skipped)


## The MORNING's ribbon and the PAIRs' clasps (KeywordMarks), laid out with the chains.
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
