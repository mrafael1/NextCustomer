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
## Speed (#77 S1): a climber remembers what it worked out, since a total depends only on the
## cards' definitions in row order, the upgrades and the inspections (Scoring is pure), and a
## climb only on the hand's definitions in hand order, the start's positions in the hand, the
## limits and `max_changes`. So a row is scored once (`_totals`) and a climb is made once
## (`_climbs`) per climber; a repeat returns the same row (as positions in the hand) and total,
## exactly as climbing again would. Each memo keeps two generations: when the newer one holds
## MEMO_LIMIT entries it becomes the older one (the older is dropped), and an entry found in the
## older one moves to the newer one, so the memos keep what the current run keeps asking for
## (a memo that stopped growing when full lost most of its hits after a few runs).
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
## Entries in each generation of each memo.
const MEMO_LIMIT := 200000

## Rows scored (memo hits not counted), for the summary.
var rows_scored: int = 0
var max_changes: int = SENSIBLE_CHANGES
## Row key (context key + definition ids in row order) -> total, and the older generation.
var _totals: Dictionary[String, int] = {}
var _old_totals: Dictionary[String, int] = {}
## Climb key -> [total, row as positions in the hand (PackedInt32Array)], and the older
## generation.
var _climbs: Dictionary[String, Array] = {}
var _old_climbs: Dictionary[String, Array] = {}


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
	var context: String = context_key(upgrades, inspections)
	var climb_key: String = _climb_key(context, hand, limits, start)
	var known: Array = _known_climb(climb_key)
	if not known.is_empty():
		var remembered: SimHandBest = SimHandBest.new()
		remembered.score = known[0]
		for position: int in known[1]:
			remembered.row.append(hand[position])
		return remembered
	var row: Array[CardInstance] = []
	if start.is_empty():
		for card: CardInstance in hand:
			if RowCapacity.fits(limits, row, card.definition):
				row.append(card)
	else:
		row = start.duplicate()
	var total: int = _score(row, upgrades, inspections, context)
	for _change: int in range(max_changes):
		var best_row: Array[CardInstance] = []
		var best_total: int = total
		for candidate: Array[CardInstance] in _neighbours(row, hand, limits):
			var candidate_total: int = _score(candidate, upgrades, inspections, context)
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
	if not climb_key.is_empty():
		var positions: PackedInt32Array = PackedInt32Array()
		for card: CardInstance in row:
			positions.append(hand.find(card))
		_remember_climb(climb_key, [total, positions])
	return result


## What a total depends on besides the row (Scoring reads nothing else of them): the upgrades
## and the inspections that have rules, in order (by resource, so two resources never share a
## key), and the product slots they all add or close (ScoreState.product_slot_change, which a
## rule can read). So a register without rules (Extra redraw, Extra coupon slot) shares the
## totals of the rows it doesn't change.
static func context_key(
	upgrades: Array[UpgradeDefinition], inspections: Array[InspectionDefinition]
) -> String:
	var key: String = "u"
	var slot_change: int = 0
	for upgrade: UpgradeDefinition in upgrades:
		slot_change += upgrade.extra_slots
		if not upgrade.rules.is_empty():
			key += ",%d" % upgrade.get_instance_id()
	key += "i"
	for inspection: InspectionDefinition in inspections:
		slot_change += inspection.extra_slots
		if not inspection.rules.is_empty():
			key += ",%d" % inspection.get_instance_id()
	return key + "s%d" % slot_change


## A row's definitions in order, by resource.
static func row_key(row: Array[CardInstance]) -> String:
	var key: String = ""
	for card: CardInstance in row:
		key += "%d," % card.definition.get_instance_id()
	return key


## Everything a climb depends on, or "" when a start card isn't in the hand (never remembered).
func _climb_key(
	context: String, hand: Array[CardInstance], limits: ShiftLimits, start: Array[CardInstance]
) -> String:
	var key: String = (
		"%s/%d/%d/%d/%s/"
		% [context, limits.slot_count, limits.coupon_slot_count, max_changes, row_key(hand)]
	)
	for card: CardInstance in start:
		var position: int = hand.find(card)
		if position < 0:
			return ""
		key += "%d," % position
	return key


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
	inspections: Array[InspectionDefinition],
	context: String
) -> int:
	var key: String = context + "/" + row_key(row)
	if _totals.has(key):
		return _totals[key]
	var total: int = 0
	if _old_totals.has(key):
		total = _old_totals[key]
	else:
		rows_scored += 1
		total = Scoring.total(row, upgrades, inspections)
	if _totals.size() >= MEMO_LIMIT:
		_old_totals = _totals
		_totals = {}
	_totals[key] = total
	return total


## The remembered climb of this key ([total, positions]), or [] (also for the key "").
func _known_climb(climb_key: String) -> Array:
	if climb_key.is_empty():
		return []
	if _climbs.has(climb_key):
		return _climbs[climb_key]
	var known: Array = _old_climbs.get(climb_key, [])
	if not known.is_empty():
		_remember_climb(climb_key, known)
	return known


func _remember_climb(climb_key: String, entry: Array) -> void:
	if _climbs.size() >= MEMO_LIMIT:
		_old_climbs = _climbs
		_climbs = {}
	_climbs[climb_key] = entry
