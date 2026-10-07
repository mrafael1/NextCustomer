class_name RunEvents
extends RefCounted
## Builds the data of the run_start, run_end, run_resume, run_abandon, reward, upgrade, count_up
## and redraw events, the card id lists (starting_deck, impulse_offer, cards_drawn, final_order)
## and the upgrade- and inspection-related log fields (plan section 8), so they are defined and
## tested in one place. The shift screen logs them (the title screen logs run_abandon).
##
## An offer's times (`timing`) are OfferTimeline.fields(): decide_ms, presented_ms, armed_ms and
## presentation_skipped, each in ms from the offer starting to present (-1 for a moment the
## choice came before).


## The `run_start` event, logged once the impulse rack is picked or skipped: the seed, the
## starting deck (card ids, before the rack), the number of shifts, the run's stock
## (listed_aisles, stock) and the impulse rack (full build plan section 4): the products offered
## in offer order (empty without a rack), the one picked ("" for a skip or no rack) and the deck
## card it replaced at the deck limit ("" for none), plus, like the reward event, the rack's times
## (`impulse_timing`, logged as impulse_decide_ms, impulse_presented_ms, impulse_armed_ms and
## impulse_presentation_skipped; all 0 and false when left out: no rack, or a debug replay) and
## whether the deck view was opened (`impulse_deck_view_opened`).
static func run_start(
	run: RunState, impulse_timing: Dictionary = {}, impulse_deck_view_opened: bool = false
) -> Dictionary:
	var timing: Dictionary = impulse_timing
	if timing.is_empty():
		timing = OfferTimeline.new().fields(0)
	var data: Dictionary = {
		"seed": run.run_seed,
		"starting_deck": definition_ids(run.starter.cards),
		"shift_count": run.shift_count(),
		"impulse_offer": definition_ids(run.impulse_offer),
		"impulse_pick": _id_or_empty(run.impulse_pick),
		"impulse_replaced": _id_or_empty(run.impulse_replaced),
		"impulse_decide_ms": timing["decide_ms"],
		"impulse_presented_ms": timing["presented_ms"],
		"impulse_armed_ms": timing["armed_ms"],
		"impulse_presentation_skipped": timing["presentation_skipped"],
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


## The `run_resume` event, logged under the saved run's id when a saved run continues (full
## build plan section 4): the shift (1-based), the save point it continues from (RunSave's
## phase names: impulse_rack, planning, reward, upgrade) and the played time so far.
static func run_resume(run: RunState, run_ms: int) -> Dictionary:
	return {"shift": run.shift_index + 1, "phase": RunSave.phase_name(run.phase), "run_ms": run_ms}


## The `run_abandon` event, logged under the saved run's id when the title screen's New run
## abandons it: the shift (1-based), the save point it was at and the played time (`run_ms`, up
## to its last save).
static func run_abandon(run: RunState, run_ms: int) -> Dictionary:
	return {"shift": run.shift_index + 1, "phase": RunSave.phase_name(run.phase), "run_ms": run_ms}


## The `reward` event: the shift (1-based), the cards offered (ids, in offer order), the one
## picked ("" for a skip), whether it was skipped, the deck card it replaced at the deck limit (""
## for none), the offer's times (`timing`) and whether the player chose to open the deck view.
static func reward(
	shift: int,
	offered: Array[CardDefinition],
	picked: CardDefinition,
	replaced: CardInstance,
	timing: Dictionary,
	deck_view_opened: bool
) -> Dictionary:
	return {
		"shift": shift,
		"offered": definition_ids(offered),
		"picked": _id_or_empty(picked),
		"skipped": picked == null,
		"replaced": String(replaced.definition.id) if replaced != null else "",
		"decide_ms": timing["decide_ms"],
		"presented_ms": timing["presented_ms"],
		"armed_ms": timing["armed_ms"],
		"presentation_skipped": timing["presentation_skipped"],
		"deck_view_opened": deck_view_opened,
	}


## The `upgrade` event: the shift (1-based), the upgrades offered (ids, in offer order), the
## one picked, and the tickets' times (`timing`, like the reward event's).
static func upgrade_pick(
	shift: int, offered: Array[UpgradeDefinition], picked: UpgradeDefinition, timing: Dictionary
) -> Dictionary:
	return {
		"shift": shift,
		"offered": upgrade_ids(offered),
		"picked": String(picked.id),
		"decide_ms": timing["decide_ms"],
		"presented_ms": timing["presented_ms"],
		"armed_ms": timing["armed_ms"],
		"presentation_skipped": timing["presentation_skipped"],
	}


## The `count_up` event, logged when the count-up ends; every time is Time.get_ticks_msec(). The
## count-up's time runs from the checkout click (`click_ms`) to the final total shown;
## fast_forward_used is a hold past CountUp.HOLD_THRESHOLD_MS that sped it up; a tap (CountUp)
## sets skip_used and skip_at_ms (from the click to the first tap, -1 for none), and
## dessert_skipped is a tap that sped up what follows the total.
static func count_up(
	shift: int,
	click_ms: int,
	total_shown_ms: int,
	fast_forward_used: bool,
	first_tap_ms: int,
	dessert_skipped: bool
) -> Dictionary:
	return {
		"shift": shift,
		"count_up_ms": total_shown_ms - click_ms,
		"fast_forward_used": fast_forward_used,
		"skip_used": first_tap_ms >= 0,
		"skip_at_ms": first_tap_ms - click_ms if first_tap_ms >= 0 else -1,
		"dessert_skipped": dessert_skipped,
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
