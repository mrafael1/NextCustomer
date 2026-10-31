class_name RunPins
extends RefCounted
## A run's badge pins (#122, full build plan 7.4): wearing them when the run starts, their
## starting cards and the full redraw. The pins and the full redraw's use live on the run
## (RunState.pins, full_redraw_used), so they are saved with it.


## Wears the badge pins for a new run: kept in `run.pins`, their starting cards added to the deck
## now, or after the starter pack (RunState.take_pack) when the run waits for its pick. Call it
## once, right after the run is made.
static func wear(run: RunState, worn: Array[PinDefinition]) -> void:
	run.pins = worn.duplicate()
	if run.phase != RunState.Phase.CHOOSE_START:
		add_cards(run)


## Adds the worn pins' starting cards to the run's deck.
static func add_cards(run: RunState) -> void:
	for pin: PinDefinition in run.pins:
		for card: CardDefinition in pin.starting_cards:
			run.deck.add_card(card)


## Whether a worn pin gives the full redraw.
static func has_full_redraw(run: RunState) -> bool:
	for pin: PinDefinition in run.pins:
		if pin.full_redraw:
			return true
	return false


## The full redraw needs a full-redraw pin, planning, a redraw left, this shift's full redraw
## unused, a hand card and a card to draw.
static func can_redraw_all(run: RunState) -> bool:
	if not has_full_redraw(run) or run.full_redraw_used:
		return false
	if run.phase != RunState.Phase.PLANNING or run.redraws_used >= run.redraws_allowed:
		return false
	return not hand_places(run).is_empty() and not run.deck.draw_pile().is_empty()


## Redraws every basket's hand cards at once, as one redraw (RunState.redraw_basket's rules for
## each card: row cards stay, a short draw pile swaps the left ones), once per shift. Returns the
## places swapped (empty when it isn't allowed).
static func redraw_all(run: RunState) -> Array[int]:
	var swapped: Array[int] = []
	if not can_redraw_all(run):
		return swapped
	swapped = run.deck.redraw_places(hand_places(run))
	if run.redraws_used >= run.limits.own_redraws:
		var by_place: Array[CardInstance] = run.deck.hand()
		for spot: int in swapped:
			run.redrawn_in.append(by_place[spot].instance_id)
	run.redraws_used += 1
	run.full_redraw_used = true
	return swapped


## The places of the hand that hold hand cards (not row cards), ascending.
static func hand_places(run: RunState) -> Array[int]:
	var places: Array[int] = []
	var by_place: Array[CardInstance] = run.hand_places()
	for index: int in by_place.size():
		if by_place[index] != null:
			places.append(index)
	return places
