class_name RunPins
extends RefCounted
## A run's badge pins (#122, full build plan 7.4): wearing them when the run starts, their
## starting cards and the repack. The pins live on the run (RunState.pins), so they are saved
## with it; a repack changes the hand's places, which the run save keeps too.


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


## Whether a worn pin gives the repack.
static func has_repack(run: RunState) -> bool:
	for pin: PinDefinition in run.pins:
		if pin.repack:
			return true
	return false


## A repack needs a repack pin, planning, a hand card (not a row card) at `from` and a place `to`
## in another basket of the hand. The place may hold a hand card (the two swap) or be empty, its
## card on the belt (the item moves there, and that row card's place becomes `from`).
static func can_repack(run: RunState, from: int, to: int) -> bool:
	if not has_repack(run) or run.phase != RunState.Phase.PLANNING:
		return false
	var by_place: Array[CardInstance] = run.hand_places()
	if from < 0 or from >= by_place.size() or to < 0 or to >= by_place.size():
		return false
	if by_place[from] == null:
		return false
	return basket_of(run, from) != basket_of(run, to)


## Moves the hand card at `from` to place `to` in another basket, swapping the two places' cards
## (a hand card or a row card's empty place), for free and as often as planning likes, so lone
## items can share a basket and go in one redraw. False, changing nothing, when not allowed.
static func repack(run: RunState, from: int, to: int) -> bool:
	if not can_repack(run, from, to):
		return false
	return run.deck.swap_places(from, to)


## The basket of hand place `place` (balance.basket_size places each, from place 0).
static func basket_of(run: RunState, place: int) -> int:
	return floori(float(place) / maxi(run.balance.basket_size, 1))
