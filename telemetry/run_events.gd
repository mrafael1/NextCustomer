class_name RunEvents
extends RefCounted
## Builds the data of the run_start, run_end and redraw events, the card id lists
## (starting_deck, impulse_offer, cards_drawn, final_order) and the upgrade- and
## inspection-related log fields
## (plan section 8), so they are defined and tested in one place. The shift screen logs them.


## The `run_start` event, logged once the impulse rack is picked or skipped: the seed, the
## starting deck (card ids, before the rack), the number of shifts, the run's stock
## (listed_aisles, stock) and the impulse rack (full build plan section 4): the products offered
## in offer order (empty without a rack), the one picked ("" for a skip or no rack) and the deck
## card it replaced at the deck limit ("" for none), plus, like the reward event, the time to
## decide (`impulse_decide_ms`, from the rack appearing to the choice; 0 without a rack or for a
## debug replay) and whether the deck view was opened (`impulse_deck_view_opened`).
static func run_start(
	run: RunState, impulse_decide_ms: int = 0, impulse_deck_view_opened: bool = false
) -> Dictionary:
	var data: Dictionary = {
		"seed": run.run_seed,
		"starting_deck": definition_ids(run.starter.cards),
		"shift_count": run.shift_count(),
		"impulse_offer": definition_ids(run.impulse_offer),
		"impulse_pick": _id_or_empty(run.impulse_pick),
		"impulse_replaced": _id_or_empty(run.impulse_replaced),
		"impulse_decide_ms": impulse_decide_ms,
		"impulse_deck_view_opened": impulse_deck_view_opened,
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


## The `redraw` event: the cards replaced and the cards received (ids).
static func redraw(replaced: Array[CardInstance], received: Array[CardInstance]) -> Dictionary:
	return {"cards_replaced": card_ids(replaced), "cards_received": card_ids(received)}


## Card ids in order, as logged (`cards_drawn`, `final_order`, redraws).
static func card_ids(cards: Array[CardInstance]) -> Array:
	var ids: Array = []
	for card: CardInstance in cards:
		ids.append(String(card.definition.id))
	return ids


## Card definition ids in order (`starting_deck`, `impulse_offer`).
static func definition_ids(cards: Array[CardDefinition]) -> Array:
	var ids: Array = []
	for card: CardDefinition in cards:
		ids.append(String(card.id))
	return ids


static func _id_or_empty(card: CardDefinition) -> String:
	return String(card.id) if card != null else ""


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
