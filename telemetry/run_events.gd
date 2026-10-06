class_name RunEvents
extends RefCounted
## Builds the data of the run_start and run_end events and the upgrade- and inspection-related
## log fields (plan section 8), so they are defined and tested in one place. The shift screen
## logs them.


## The `run_start` event: the seed, the starting deck (card ids), the number of shifts and the
## run's stock (listed_aisles, stock; full build plan section 4).
static func run_start(run: RunState) -> Dictionary:
	var ids: Array = []
	for card: CardInstance in run.deck.cards:
		ids.append(String(card.definition.id))
	var data: Dictionary = {
		"seed": run.run_seed,
		"starting_deck": ids,
		"shift_count": run.shift_count(),
	}
	return data.merged(run.stock.to_dictionary())


## The `run_end` event of a won or lost run: the result, the shift reached, the last checkout's
## total, the run's length and the upgrades owned.
static func run_end(run: RunState, run_ms: int) -> Dictionary:
	return {
		"result": "win" if run.phase == RunState.Phase.WON else "loss",
		"shift_reached": run.shift_index + 1,
		"last_score": run.last_result.total if run.last_result != null else 0,
		"run_ms": run_ms,
		"upgrades": upgrade_ids(run.upgrades),
	}


## The `upgrade` event: the shift (1-based), the upgrades offered (ids, in offer order), the
## one picked, and decide_ms (from the panel appearing to the pick, like the reward event).
static func upgrade_pick(
	shift: int, offered: Array[UpgradeDefinition], picked: UpgradeDefinition, decide_ms: int
) -> Dictionary:
	return {
		"shift": shift,
		"offered": upgrade_ids(offered),
		"picked": String(picked.id),
		"decide_ms": decide_ms,
	}


## Upgrade ids in order, as logged (`offered` in `upgrade`, `upgrades` in `run_end`).
static func upgrade_ids(upgrades: Array[UpgradeDefinition]) -> Array:
	var ids: Array = []
	for upgrade: UpgradeDefinition in upgrades:
		ids.append(String(upgrade.id))
	return ids


## Inspection ids in order, as logged (`inspections` in `shift_start`).
static func inspection_ids(inspections: Array[InspectionDefinition]) -> Array:
	var ids: Array = []
	for inspection: InspectionDefinition in inspections:
		ids.append(String(inspection.id))
	return ids


## One inspection's id, or "" for none (`next_inspection` in `checkout`).
static func inspection_id(inspection: InspectionDefinition) -> String:
	return String(inspection.id) if inspection != null else ""
