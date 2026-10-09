class_name SimHillClimb
extends RefCounted
## The balance simulator's "sensible" row player (decided with the user, #41): a stand-in for a
## player who orders the row with the live preview instead of trying every order, so quotas can
## be set where "a sensible but not optimal order passes" (full build plan section 8).
##
## It starts from a row (by default the hand's cards in hand order, skipping a card that doesn't
## fit), then makes up to `max_changes` changes, each time the single change that raises the
## preview most: move a row card to another slot, swap a row card for a hand card, add a hand
## card at any slot, or remove a row card. It stops early when no change raises the total. Only
## a strictly higher total counts, and ties go to the first change in that order, so the result
## never depends on anything but the hand, its order and the start. No RNG. Every row it scores
## fits the shift's limits (RowCapacity), and it scores with core's Scoring, so checkout gives
## the same total. SimPlayer climbs again from the kept row after each redraw, with another
## `max_changes` changes (decided with the user, #41).
##
## Decided with the user (#41): 3 changes. Without a cap the climb reached the exact best row in
## 78% of the logged hands (98% of the best on average, practically optimal); with 3 it reaches
## it in 45% (94% on average, 82% at p10), a player who sets up the obvious combos and misses
## some deeper orders. The logged players can't calibrate it: they played against quotas of
## about 10 and scored 44% of the best at the median (tools/row_calibration.sh).

const SENSIBLE_CHANGES := 3
## The cap that means "until no change helps": a climb needs far fewer (each change raises the
## total).
const UNCAPPED := 64

## Rows scored, for the summary.
var rows_scored: int = 0
var max_changes: int = SENSIBLE_CHANGES


## The row this player checks out with `hand`, and its total. `start` (hand cards, in row
## order) is the row it climbs from, e.g. the row kept through a redraw; empty means the hand's
## cards in hand order. The result's best_without is empty: only the exact search knows it.
func climb(
	hand: Array[CardInstance],
	limits: ShiftLimits,
	upgrades: Array[UpgradeDefinition],
	inspections: Array[InspectionDefinition],
	start: Array[CardInstance] = []
) -> SimHandBest:
	var row: Array[CardInstance] = []
	if start.is_empty():
		for card: CardInstance in hand:
			if RowCapacity.fits(limits, row, card.definition):
				row.append(card)
	else:
		row = start.duplicate()
	var total: int = _score(row, upgrades, inspections)
	for _change: int in range(max_changes):
		var best_row: Array[CardInstance] = []
		var best_total: int = total
		for candidate: Array[CardInstance] in _neighbours(row, hand, limits):
			var candidate_total: int = _score(candidate, upgrades, inspections)
			if candidate_total > best_total:
				best_total = candidate_total
				best_row = candidate
		if best_row.is_empty():
			break
		row = best_row
		total = best_total
	var result: SimHandBest = SimHandBest.new()
	result.score = total
	result.row = row
	return result


## Every row one change away from `row` that fits the limits, in the order ties are broken:
## moves, swaps, additions, removals. Spare cards with the same definition give the same rows,
## so only the first of them is tried.
static func _neighbours(
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
		if not RowCapacity.fits(limits, row, card.definition):
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
	return row.size() <= limits.card_limit() and RowCapacity.product_count(row) <= limits.slot_count


func _score(
	row: Array[CardInstance],
	upgrades: Array[UpgradeDefinition],
	inspections: Array[InspectionDefinition]
) -> int:
	rows_scored += 1
	return Scoring.score(row, upgrades, inspections).total
