class_name PuzzleRun
extends RefCounted
## A puzzle shift as a run (#183): one shift of the puzzle's hand, perks, day events and pins,
## built on a copy of the game's balance with the puzzle's target as its only quota, no redraw,
## no week nor day-event draw, no write-up and no machine. The hand comes in the puzzle's basket
## order. Scoring, the preview and the checkout are the run's own, so the shift screen plays it
## as any shift and the solver (PuzzleSolver) scores exactly what the player would. Pure.

## How a checkout's total stands against the target: on it exactly, past it, or under it.
enum Verdict { EXACT, OVER, SHORT }

## The run seed of every puzzle run: nothing in a puzzle draws (its hand is dealt in order).
const SEED := 1


## The run of `puzzle`, its shift started (PLANNING) with the whole hand dealt in basket order.
static func build(puzzle: PuzzleDefinition, balance: BalanceDefinition) -> RunState:
	var deck: DeckDefinition = DeckDefinition.new()
	deck.id = puzzle.id
	deck.cards = puzzle.hand.duplicate()
	var run: RunState = RunState.new(SEED, deck, shift_balance(puzzle, balance), null)
	run.upgrades = puzzle.upgrades.duplicate()
	run.inspections = puzzle.inspections.duplicate()
	run.pins = puzzle.pins.duplicate()
	run.start_shift()
	# The deal shuffled the deck: the hand goes back to the puzzle's order, nothing left to draw.
	var cards: Array[CardInstance] = run.deck.cards.duplicate()
	run.deck.restore(cards, cards, [], run.deck.next_instance_id())
	return run


## A copy of `balance` for the puzzle's one shift: its quota is the target, its slots the
## puzzle's, its hand the whole puzzle hand, with no redraw, no week, no drawn day event, no
## write-up, no coins and no machine.
static func shift_balance(
	puzzle: PuzzleDefinition, balance: BalanceDefinition
) -> BalanceDefinition:
	var copy: BalanceDefinition = balance.duplicate(false)
	copy.quotas = PackedInt32Array([puzzle.target])
	copy.slot_count = puzzle.slot_count
	copy.hand_size = puzzle.hand.size()
	copy.base_redraws = 0
	copy.inspection_shifts = PackedInt32Array()
	copy.review_shifts = PackedInt32Array()
	copy.boon_shifts = PackedInt32Array()
	copy.week_length = 0
	var no_weeks: Array[WeekEventDefinition] = []
	copy.weeks = no_weeks
	copy.write_up_limit = 0
	copy.write_up_last_shift = 0
	copy.coins_by_shifts_passed = PackedInt32Array()
	copy.machine = null
	return copy


## How `total` stands against `target`.
static func verdict(total: int, target: int) -> Verdict:
	if total == target:
		return Verdict.EXACT
	return Verdict.OVER if total > target else Verdict.SHORT


## The hand cards of `run` in the order of `ids` (a stored solution), each hand card used once;
## empty when an id isn't in the hand.
static func row_of(run: RunState, ids: PackedStringArray) -> Array[CardInstance]:
	var left: Array[CardInstance] = run.deck.hand()
	var row: Array[CardInstance] = []
	for card_id: String in ids:
		var found: CardInstance = null
		for card: CardInstance in left:
			if String(card.definition.id) == card_id:
				found = card
				break
		if found == null:
			return []
		left.erase(found)
		row.append(found)
	return row


## RETRY: the puzzle's run built again, with the belt as it was checked out (`ids`, its card ids
## in belt order) placed back on it, so one move can change the row.
static func retry(
	puzzle: PuzzleDefinition, balance: BalanceDefinition, ids: PackedStringArray
) -> RunState:
	var run: RunState = build(puzzle, balance)
	for card: CardInstance in row_of(run, ids):
		run.place(card, run.row.size())
	return run
