class_name RunPins
extends RefCounted
## A run's badge pins (#122, full build plan 7.4): wearing them when the run starts, their
## starting cards, the repack and the Double checkout. The pins live on the run (RunState.pins),
## so they are saved with it; a repack changes the hand's places, which the run save keeps too,
## and a Double checkout shift's row 1 is saved after its checkout (RunState.first_row).


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
## Whether a worn pin puts the items a redraw replaces back into the draw pile (Recycle).
static func recycles(run: RunState) -> bool:
	for pin: PinDefinition in run.pins:
		if pin.recycle:
			return true
	return false


## The redraws the worn pins add to every shift.
static func extra_redraws(run: RunState) -> int:
	var total: int = 0
	for pin: PinDefinition in run.pins:
		total += pin.extra_redraws
	return total


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


## A worn Double checkout pin's row slots (the first such pin's), or 0 for a shift of one row.
static func row_slots(run: RunState) -> int:
	for pin: PinDefinition in run.pins:
		if pin.row_slots > 0:
			return pin.row_slots
	return 0


## The belt slots before the row being planned: row 1's slot count on a Double checkout shift's
## row 2 (the upgrades' slot numbers count across both rows), else 0.
static func row_offset(run: RunState) -> int:
	return run.limits.slot_count if run.first_result != null else 0


## A Double checkout shift's first checkout (RunState.checkout): scores row 1 on its own (another
## row follows), keeps it as `first_row` and `first_result`, spends its cards and refills their
## hand places from the draw pile (Deck.refill_places: a short pile leaves the hand smaller), and
## empties the row for row 2. The shift stays in PLANNING, its redraws shared. Returns row 1's
## result.
static func check_out_first_row(run: RunState) -> ScoreResult:
	var events: Array[InspectionDefinition] = WeekSchedule.shift_events(run)
	run.first_result = Scoring.score(
		run.row, run.upgrades, events, ScoreCredits.for_run(run), 0, true
	)
	run.row_result = run.first_result
	run.first_row = run.row.duplicate()
	var spent: Array[int] = []
	var hand: Array[CardInstance] = run.deck.hand()
	for card: CardInstance in run.first_row:
		spent.append(hand.find(card))
	spent.sort()
	run.row = []
	run.deck.refill_places(spent)
	return run.first_result


## The shift's whole result at its last checkout: the row's on a shift of one row; on a Double
## checkout shift row 2 scored after row 1's slots (Scoring.score's slot_offset: the row's slot
## count) joined to row 1's (ScoreResult.joined). Sets `row_result` to the row's own result.
## `upgrades`: the ones the shift was played with (the run save's, after a machine pick).
static func score_rows(run: RunState, upgrades: Array[UpgradeDefinition]) -> ScoreResult:
	var events: Array[InspectionDefinition] = WeekSchedule.shift_events(run)
	var credits: ScoreCredits = ScoreCredits.for_run(run)
	if run.first_result == null:
		run.row_result = Scoring.score(run.row, upgrades, events, credits)
		return run.row_result
	run.row_result = Scoring.score(run.row, upgrades, events, credits, row_offset(run))
	return ScoreResult.joined(run.first_result, run.row_result, run.first_row.size())


## A restored Double checkout shift's row 1 result (RunSave), scored again as its checkout did
## with the upgrades the shift was played with; nothing for a shift whose row 1 isn't checked out.
static func restore_first_row(run: RunState, upgrades: Array[UpgradeDefinition]) -> void:
	if run.first_row.is_empty():
		return
	var events: Array[InspectionDefinition] = WeekSchedule.shift_events(run)
	run.first_result = Scoring.score(
		run.first_row, upgrades, events, ScoreCredits.for_run(run), 0, true
	)
	run.row_result = run.first_result
