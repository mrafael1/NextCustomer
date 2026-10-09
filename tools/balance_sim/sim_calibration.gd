class_name SimCalibration
extends RefCounted
## Checks the simulator's sensible row player (SimHillClimb) against real players (decided with
## the user, #41): it replays the checkouts in playtest logs (docs/PROTOTYPE_PLAN.md section 8)
## and compares, for each logged hand, the player's own row, the exact best row (SimRowSearch)
## and the rows each climb variant plays. Everything is scored with today's rules and data, so
## a row logged under older rules is judged as if played now; the logged score is kept to show
## how many changed.
##
## A checkout counts when a player placed its cards (`placements` > 0; debug rows place none)
## and its hand can be rebuilt: the shift's `shift_start` cards, then each `redraw`, must hold
## every card of `final_order`. The upgrades are the run's `upgrade` picks before the shift, the
## inspections the shift's `inspections`. Events are grouped by run and read in time order, so
## a run resumed in a later session still counts.

## The climb variants compared, as [label, max_changes]; the simulator's sensible player is
## SimHillClimb.SENSIBLE_CHANGES.
const VARIANTS: Array[Array] = [
	["climb, 1 change", 1],
	["climb, 2 changes", 2],
	["climb, 3 changes", 3],
	["climb, 5 changes", 5],
	["climb, uncapped", SimHillClimb.UNCAPPED],
]
const PERCENTILES: Array[int] = [10, 25, 50, 75, 90]

## Checkouts read, and checkouts left out (by reason).
var checkouts: Array[Checkout] = []
var skipped: Dictionary[String, int] = {}


## One logged checkout, rebuilt.
class Checkout:
	extends RefCounted
	var build: String = ""
	var run_id: String = ""
	var shift: int = 0
	## The hand at checkout, in draw order (redrawn cards take the replaced cards' places).
	var hand: Array[CardDefinition] = []
	## The player's row.
	var row: Array[CardDefinition] = []
	var upgrades: Array[UpgradeDefinition] = []
	var inspections: Array[InspectionDefinition] = []
	var logged_score: int = 0


## Reads the checkouts from log lines (JSON objects, one per line, any order).
func read(lines: PackedStringArray, lookup: ContentLookup) -> void:
	var runs: Dictionary[String, Array] = {}
	for line: String in lines:
		if line.strip_edges().is_empty():
			continue
		var event: Variant = JSON.parse_string(line)
		if not event is Dictionary or not event.has("run_id"):
			continue
		var run_id: String = String(event["run_id"])
		if not runs.has(run_id):
			runs[run_id] = []
		runs[run_id].append(event)
	var run_ids: Array[String] = []
	run_ids.assign(runs.keys())
	run_ids.sort()
	for run_id: String in run_ids:
		var events: Array = runs[run_id]
		events.sort_custom(_earlier)
		_read_run(events, lookup)


## Scores every checkout: [human, best, one total per variant] for each.
func evaluate(balance: BalanceDefinition, search: SimRowSearch) -> Array[PackedInt32Array]:
	var results: Array[PackedInt32Array] = []
	for checkout: Checkout in checkouts:
		var hand: Array[CardInstance] = []
		for index: int in range(checkout.hand.size()):
			hand.append(CardInstance.new(checkout.hand[index], index + 1))
		var limits: ShiftLimits = ShiftLimits.for_shift(
			balance, checkout.upgrades, 0, checkout.inspections
		)
		var totals: PackedInt32Array = PackedInt32Array()
		totals.append(
			(
				Scoring
				. score(_row_from(hand, checkout.row), checkout.upgrades, checkout.inspections)
				. total
			)
		)
		totals.append(search.search(hand, checkout.upgrades, checkout.inspections).score)
		for variant: Array in VARIANTS:
			var climber: SimHillClimb = SimHillClimb.new()
			climber.max_changes = variant[1]
			totals.append(
				climber.climb(hand, limits, checkout.upgrades, checkout.inspections).score
			)
		results.append(totals)
	return results


## The report: per player (the logged rows) and per variant, how close to the exact best.
func report(results: Array[PackedInt32Array]) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var skipped_texts: PackedStringArray = PackedStringArray()
	for reason: String in skipped:
		skipped_texts.append("%s %d" % [reason, skipped[reason]])
	lines.append(
		(
			"Row calibration: %d logged checkouts (left out: %s)"
			% [checkouts.size(), ", ".join(skipped_texts) if not skipped.is_empty() else "none"]
		)
	)
	var changed: int = 0
	for index: int in range(checkouts.size()):
		if results[index][0] != checkouts[index].logged_score:
			changed += 1
	lines.append("Rows that score differently under today's rules: %d" % changed)
	lines.append("")
	var header: String = "%-26s %8s" % ["Rows (share of exact best)", "at best"]
	for percent: int in PERCENTILES:
		header += "%6s" % ("p%d" % percent)
	lines.append(header + "    mean")
	var labels: Array[String] = ["logged players"]
	for variant: Array in VARIANTS:
		labels.append(String(variant[0]))
	for column: int in range(labels.size()):
		var column_index: int = 0 if column == 0 else column + 1
		lines.append(_ratio_line(labels[column], results, column_index))
	lines.append("")
	lines.append("By build (logged players): " + _by_build(results))
	return "\n".join(lines)


## A row's totals as shares of the exact best, in percent (100 when the best is 0).
static func shares(results: Array[PackedInt32Array], column: int) -> PackedInt32Array:
	var values: PackedInt32Array = PackedInt32Array()
	for totals: PackedInt32Array in results:
		values.append(100 if totals[1] <= 0 else floori(100.0 * totals[column] / totals[1]))
	return values


func _ratio_line(label: String, results: Array[PackedInt32Array], column: int) -> String:
	var values: PackedInt32Array = shares(results, column)
	var at_best: int = 0
	var sum: int = 0
	for value: int in values:
		sum += value
		if value >= 100:
			at_best += 1
	var line: String = "%-26s %8s" % [label, SimSummary.percent_text(at_best, values.size())]
	for percent: int in PERCENTILES:
		line += "%5d%%" % SimSummary.nearest_rank(values, percent)
	var mean: float = float(sum) / values.size() if not values.is_empty() else 0.0
	return line + "  %5.1f%%" % mean


func _by_build(results: Array[PackedInt32Array]) -> String:
	var groups: Dictionary[String, Array] = {}
	for index: int in range(checkouts.size()):
		var build: String = checkouts[index].build
		if not groups.has(build):
			groups[build] = []
		groups[build].append(results[index])
	var texts: PackedStringArray = PackedStringArray()
	for build: String in groups:
		var group: Array[PackedInt32Array] = []
		group.assign(groups[build])
		texts.append(
			(
				"%s %d checkouts, median %d%%"
				% [build, group.size(), SimSummary.nearest_rank(shares(group, 0), 50)]
			)
		)
	return ", ".join(texts)


func _read_run(events: Array, lookup: ContentLookup) -> void:
	var upgrades: Array[UpgradeDefinition] = []
	var hand: Array[CardDefinition] = []
	var inspections: Array[InspectionDefinition] = []
	var shift: int = 0
	for event: Dictionary in events:
		match String(event.get("type", "")):
			"shift_start":
				shift = int(event.get("shift", 0))
				hand = _cards(event.get("cards_drawn", []), lookup)
				inspections = []
				for id: Variant in event.get("inspections", []):
					var inspection: InspectionDefinition = lookup.inspection(String(id))
					if inspection != null:
						inspections.append(inspection)
			"redraw":
				_redraw(hand, event, lookup)
			"upgrade":
				var upgrade: UpgradeDefinition = lookup.upgrade(String(event.get("picked", "")))
				if upgrade != null:
					upgrades.append(upgrade)
			"checkout":
				_read_checkout(event, hand, upgrades, inspections, shift, lookup)


func _read_checkout(
	event: Dictionary,
	hand: Array[CardDefinition],
	upgrades: Array[UpgradeDefinition],
	inspections: Array[InspectionDefinition],
	shift: int,
	lookup: ContentLookup
) -> void:
	if int(event.get("placements", 0)) <= 0:
		_skip("no placements")
		return
	if int(event.get("shift", -1)) != shift or hand.is_empty():
		_skip("hand not logged")
		return
	var row: Array[CardDefinition] = _cards(event.get("final_order", []), lookup)
	if row.size() != Array(event.get("final_order", [])).size() or hand.has(null):
		_skip("unknown card")
		return
	var left: Array[CardDefinition] = hand.duplicate()
	for card: CardDefinition in row:
		if not left.has(card):
			_skip("row not in hand")
			return
		left.erase(card)
	var checkout: Checkout = Checkout.new()
	checkout.build = String(event.get("build", ""))
	checkout.run_id = String(event.get("run_id", ""))
	checkout.shift = shift
	checkout.hand = hand.duplicate()
	checkout.row = row
	checkout.upgrades = upgrades.duplicate()
	checkout.inspections = inspections.duplicate()
	checkout.logged_score = int(event.get("score", 0))
	checkouts.append(checkout)


## A redraw puts the received cards where the replaced cards were. The log lists the replaced
## cards in the order they were picked but the received cards in hand order, so the received
## cards fill the replaced positions in ascending order. Of copies of one card, the earliest
## ones in the hand are taken as the replaced ones.
static func _redraw(hand: Array[CardDefinition], event: Dictionary, lookup: ContentLookup) -> void:
	var replaced: Array = event.get("cards_replaced", [])
	var received: Array = event.get("cards_received", [])
	var positions: Array[int] = []
	for id: Variant in replaced:
		for position: int in range(hand.size()):
			if (
				not positions.has(position)
				and hand[position] != null
				and String(hand[position].id) == String(id)
			):
				positions.append(position)
				break
	positions.sort()
	for index: int in range(mini(positions.size(), received.size())):
		hand[positions[index]] = lookup.card(String(received[index]))


## Every id's card, null for an unknown one.
static func _cards(ids: Variant, lookup: ContentLookup) -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	if ids is Array:
		for id: Variant in ids:
			cards.append(lookup.card(String(id)))
	return cards


func _skip(reason: String) -> void:
	skipped[reason] = skipped.get(reason, 0) + 1


static func _row_from(hand: Array[CardInstance], row: Array[CardDefinition]) -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for definition: CardDefinition in row:
		for card: CardInstance in hand:
			if card.definition == definition and not cards.has(card):
				cards.append(card)
				break
	return cards


static func _earlier(a: Dictionary, b: Dictionary) -> bool:
	var a_time: String = String(a.get("time", ""))
	var b_time: String = String(b.get("time", ""))
	if a_time != b_time:
		return a_time < b_time
	return int(a.get("seq", 0)) < int(b.get("seq", 0))
