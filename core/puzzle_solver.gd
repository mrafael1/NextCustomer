class_name PuzzleSolver
extends RefCounted
## The puzzle shifts' solver (#183, tools/puzzle_check.sh): tries every row the hand can make
## (every subset of the hand, in every order, up to the belt's slots) on the puzzle's own run
## (PuzzleRun.build) and scores each with the run's preview, exactly as the checkout would. Two
## rows of the same card ids in the same order are one row (two Bananas swapped are the same
## row). Pure; a 7-item hand on 5 slots is 3,620 rows.

## The rows that hit the target, each as its card ids in belt order, and every distinct row's
## total by its ids joined with "," (the empty row too).
var solutions: Array[PackedStringArray] = []
var totals: Dictionary[String, int] = {}


## Solves `puzzle` on `balance`.
static func solve(puzzle: PuzzleDefinition, balance: BalanceDefinition) -> PuzzleSolver:
	var solver: PuzzleSolver = PuzzleSolver.new()
	var run: RunState = PuzzleRun.build(puzzle, balance)
	var slots: int = RowCapacity.card_limit(run.limits)
	var hand: Array[CardInstance] = run.deck.hand()
	var row: Array[CardInstance] = []
	solver._walk(run, hand, row, slots, puzzle.target)
	return solver


## The total of the row `ids` (card ids in belt order) on the puzzle's run, or -1 when the row
## can't be made from the hand or doesn't fit the belt.
static func total_of(
	puzzle: PuzzleDefinition, balance: BalanceDefinition, ids: PackedStringArray
) -> int:
	var run: RunState = PuzzleRun.build(puzzle, balance)
	var row: Array[CardInstance] = PuzzleRun.row_of(run, ids)
	if row.size() != ids.size() or row.size() > RowCapacity.card_limit(run.limits):
		return -1
	run.row = row
	return run.preview().total


## How many distinct rows hit the target.
func count() -> int:
	return solutions.size()


## How many distinct rows were scored.
func rows() -> int:
	return totals.size()


## Every reachable total, ascending, each once.
func reachable() -> Array[int]:
	var found: Array[int] = []
	for key: String in totals:
		if not found.has(totals[key]):
			found.append(totals[key])
	found.sort()
	return found


## How many distinct rows score `total`.
func rows_at(total: int) -> int:
	var found: int = 0
	for key: String in totals:
		found += 1 if totals[key] == total else 0
	return found


func _walk(
	run: RunState, left: Array[CardInstance], row: Array[CardInstance], slots: int, target: int
) -> void:
	var ids: PackedStringArray = PackedStringArray()
	for card: CardInstance in row:
		ids.append(String(card.definition.id))
	var key: String = ",".join(ids)
	if totals.has(key):
		return  # The same ids in the same order: one row (a copy swapped for its twin).
	run.row = row
	var total: int = run.preview().total
	totals[key] = total
	if total == target and not row.is_empty():
		solutions.append(ids)
	if row.size() >= slots:
		return
	for index: int in range(left.size()):
		var rest: Array[CardInstance] = left.duplicate()
		rest.remove_at(index)
		var longer: Array[CardInstance] = row.duplicate()
		longer.append(left[index])
		_walk(run, rest, longer, slots, target)
