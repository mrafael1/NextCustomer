class_name RowClimb
extends RefCounted
## A sensible row player (decided with the user, #41; full build plan section 8): a stand-in for
## a player who orders the row with the live preview instead of trying every order. It starts
## from a row (by default the hand's cards in hand order, skipping a card that doesn't fit), then
## makes up to `max_changes` changes, each time the single change that raises the preview most:
## move a row card to another slot, swap a row card for a hand card, add a hand card at any slot,
## or remove a row card. It stops early when no change raises the total. Only a strictly higher
## total counts, and ties go to the first change in that order, so the result depends only on the
## hand, its order and the start. No RNG. Every row it scores fits the shift's limits
## (RowCapacity), and it scores with Scoring, so checkout gives the same total.
##
## The balance simulator's SimHillClimb plays the same climb with memos of its own; both use
## `neighbours` and `fits`. The starting deck's fair-deal check (StartingDeck, v0.54) climbs here.

## Row key (definition ids in row order) -> total, for one climber's climbs.
var _totals: Dictionary[String, int] = {}
var _upgrades: Array[UpgradeDefinition] = []
var _inspections: Array[InspectionDefinition] = []


## A climber for one context: the totals it scores are remembered for its later climbs (they
## depend only on the row's definitions, the upgrades and the inspections).
func _init(
	upgrades: Array[UpgradeDefinition] = [], inspections: Array[InspectionDefinition] = []
) -> void:
	_upgrades = upgrades
	_inspections = inspections


## The total of the row this player checks out with `hand` under `limits`, climbing up to
## `max_changes` changes from the hand's cards in hand order.
func climb_total(hand: Array[CardInstance], limits: ShiftLimits, max_changes: int) -> int:
	var row: Array[CardInstance] = []
	for card: CardInstance in hand:
		if RowCapacity.fits(limits, row):
			row.append(card)
	var total: int = _score(row)
	for _change: int in range(max_changes):
		var best_row: Array[CardInstance] = []
		var best_total: int = total
		for candidate: Array[CardInstance] in neighbours(row, hand, limits):
			var candidate_total: int = _score(candidate)
			if candidate_total > best_total:
				best_total = candidate_total
				best_row = candidate
		if best_row.is_empty():
			break
		row = best_row
		total = best_total
	return total


## Every row one change away from `row` that fits the limits, in the order ties are broken:
## moves, swaps, additions, removals. Spare cards with the same definition give the same rows,
## so only the first of them is tried.
static func neighbours(
	row: Array[CardInstance], hand: Array[CardInstance], limits: ShiftLimits
) -> Array[Array]:
	var spare: Array[CardInstance] = []
	var spare_kinds: Array[CardDefinition] = []
	for card: CardInstance in hand:
		if not row.has(card) and not spare_kinds.has(card.definition):
			spare.append(card)
			spare_kinds.append(card.definition)
	var rows: Array[Array] = []
	for from: int in range(row.size()):
		for to: int in range(row.size()):
			if to != from and row[to].definition != row[from].definition:
				var moved: Array[CardInstance] = row.duplicate()
				var card: CardInstance = moved.pop_at(from)
				moved.insert(to, card)
				rows.append(moved)
	for index: int in range(row.size()):
		for card: CardInstance in spare:
			if card.definition == row[index].definition:
				continue
			var swapped: Array[CardInstance] = row.duplicate()
			swapped[index] = card
			if fits(limits, swapped):
				rows.append(swapped)
	for card: CardInstance in spare:
		if not RowCapacity.fits(limits, row):
			continue
		for at: int in range(row.size() + 1):
			var added: Array[CardInstance] = row.duplicate()
			added.insert(at, card)
			rows.append(added)
	for index: int in range(row.size()):
		var removed: Array[CardInstance] = row.duplicate()
		removed.remove_at(index)
		rows.append(removed)
	return rows


## Whether a whole row fits the shift's limits (plan section 3.1).
static func fits(limits: ShiftLimits, row: Array[CardInstance]) -> bool:
	return RowCapacity.row_fits(limits, row)


func _score(row: Array[CardInstance]) -> int:
	var key: String = ""
	for card: CardInstance in row:
		key += "%d," % card.definition.get_instance_id()
	if _totals.has(key):
		return _totals[key]
	var total: int = Scoring.total(row, _upgrades, _inspections)
	_totals[key] = total
	return total
