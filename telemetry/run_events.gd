class_name RunEvents
extends RefCounted
## Builds the data of the run_start, run_end, run_resume, run_abandon, machine_visit, count_up
## and redraw events, the card id lists (starting_deck, cards_drawn, final_order) and the
## upgrade- and inspection-related log fields (plan section 8), so they are defined and tested
## in one place. The shift screen logs them (the title screen logs run_abandon).
##
## A machine visit's times (`timing`) are OfferTimeline.fields(): decide_ms, presented_ms,
## armed_ms, presentation_skipped and chute_wait_ms, each in ms from the visit starting to
## present (#77: the receipt's flight to the slot, or the bonus ticket's or STAMP DAY's start; -1
## for a moment the choice came before); presented_ms and armed_ms leave out the chute wait (the
## player at the chute keys, from their arming to the CONFIRM), so they are non-interactive time.
##
## Since v0.38 (#77) the `reward` and `upgrade` events and run_start's impulse_* fields are no
## longer logged (the impulse rack, the print-out and the exit kiosk are gone): machine_visit
## replaces them. tools/log_summary.py still reads older logs.


## The `run_start` event, logged when shift 1 starts: the seed, the starting deck (card ids),
## the number of shifts and the run's stock (listed_aisles, stock).
static func run_start(run: RunState) -> Dictionary:
	var data: Dictionary = {
		"seed": run.run_seed,
		"starting_deck": definition_ids(run.starter.cards),
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


## The `run_resume` event, logged under the saved run's id when a saved run continues (full
## build plan section 4): the shift (1-based), the save point it continues from (RunSave's
## phase names: planning, machine, machine_pick, scored) and the played time so far.
static func run_resume(run: RunState, run_ms: int) -> Dictionary:
	return {"shift": run.shift_index + 1, "phase": RunSave.phase_name(run.phase), "run_ms": run_ms}


## The `run_abandon` event, logged under the saved run's id when the title screen's New run
## abandons it: the shift (1-based), the save point it was at and the played time (`run_ms`, up
## to its last save).
static func run_abandon(run: RunState, run_ms: int) -> Dictionary:
	return {"shift": run.shift_index + 1, "phase": RunSave.phase_name(run.phase), "run_ms": run_ms}


## The `machine_visit` event (#77), logged at each pick or bin of a RECEIPT REWARDS visit,
## once RewardMachine.pick or bin has recorded `visit` (the run's last record holds it): the
## shift (1-based), the visit's index in the shift (0: the ticket), its kind (ticket, bonus,
## stamp_day), the inspection that earned a bonus ticket ("" otherwise), the chute, its Regular
## level before and every chute's level after (new_items, coupons, register, upgrades), whether
## the meter rose, the odds shown (`odds`: the chosen chute's card, or STAMP DAY's REGISTER card:
## each rarity's % per drop, P(at least one RARE or better) and P(a LEGENDARY), in %), whether the
## draw held its guarantee, the card's fallback notes, the chutes whose odds card was opened, in
## order, the prizes offered ({kind, id, rarity}, reveal order), the reveal index picked (-1 for
## a bin), whether it was binned, the cart card it replaced, the upgraded copies
## ([instance id, from, to]), the cart size after it, whether the cart was full at the pick, the
## registers owned, whether the visit was resumed from a save, and the visit's times (`timing`).
static func machine_visit(
	run: RunState,
	visit: MachineVisit,
	odds: MachineOddsCard,
	chutes_viewed: Array[int],
	cart_full_at_pick: bool,
	resumed: bool,
	timing: Dictionary
) -> Dictionary:
	var record: ShiftRecord = run.history[-1]
	var data: Dictionary = visit.to_dictionary()
	return {
		"shift": record.shift,
		"visit_index": record.visits.find(visit),
		"kind": data["kind"],
		"inspection": visit.why if visit.kind == MachineVisit.Kind.BONUS else "",
		"chute": data["chute"],
		"level_before": visit.level_before,
		"levels": Array(run.machine.levels),
		"meter_rose": visit.meter_rose,
		"odds_shown": odds_fields(odds),
		"guarantee_held": visit.guarantee_held,
		"fallback":
		(
			Array(odds.notes).map(func(note: StringName) -> String: return String(note))
			if odds != null
			else []
		),
		"chutes_viewed":
		chutes_viewed.map(func(chute: int) -> String: return MachineVisit.CHUTE_NAMES[chute]),
		"offered": data["prizes"],
		"picked": visit.picked,
		"binned": visit.binned,
		"replaced": data["replaced"],
		"upgraded": data["upgraded"],
		"cart_size": run.deck.size(),
		"cart_full_at_pick": cart_full_at_pick,
		"registers_owned": run.upgrades.size(),
		"resumed": resumed,
		"decide_ms": timing["decide_ms"],
		"presented_ms": timing["presented_ms"],
		"armed_ms": timing["armed_ms"],
		"presentation_skipped": timing["presentation_skipped"],
		"chute_wait_ms": timing["chute_wait_ms"],
	}


## An odds card as logged (`odds_shown`): each rarity's % per drop as printed (COMMON, RARE,
## LEGENDARY), P(at least one RARE or better) and P(a LEGENDARY), in %, rounded to 0.1. Empty for
## none.
static func odds_fields(odds: MachineOddsCard) -> Dictionary:
	if odds == null:
		return {}
	return {
		"rarity_pct": Array(odds.rarity_share).map(func(share: float) -> float: return _pct(share)),
		"p_rare_plus": _pct(odds.p_rare_plus),
		"p_legendary": _pct(odds.p_legendary),
	}


## The `count_up` event, logged when the shift's dessert ends (#61: at the printer feed on a
## pass, after the tear on a miss), since dessert_skipped is only known then; every time is
## Time.get_ticks_msec(). The count-up's time runs from the checkout click (`click_ms`) to the
## final total shown (the verdict); fast_forward_used is a hold past PressReader's threshold that
## sped it up; a tap (CountUp) sets skip_used and skip_at_ms (from the click to the first tap, -1
## for none), and dessert_skipped is a tap that sped up the dessert after the total.
##
## The speed it ran at (plan section 8, since v0.30): base_speed is the auto speed-up times the
## speed setting, as used (1.0, 1.25, 1.5 or 1.875); speed_setting is the player's setting (1.0
## Normal, 1.5 Fast); reduced_motion is the player's setting; step_count is the number of score
## steps in the row; planned_ms is the beat plan's fitted estimate of count_up_ms without taps.
## Left out, they log 1.0, 1.0, false, 0 and 0.
static func count_up(
	shift: int,
	click_ms: int,
	total_shown_ms: int,
	fast_forward_used: bool,
	first_tap_ms: int,
	dessert_skipped: bool,
	base_speed: float = 1.0,
	speed_setting: float = 1.0,
	reduced_motion: bool = false,
	step_count: int = 0,
	planned_ms: int = 0
) -> Dictionary:
	return {
		"shift": shift,
		"count_up_ms": total_shown_ms - click_ms,
		"fast_forward_used": fast_forward_used,
		"skip_used": first_tap_ms >= 0,
		"skip_at_ms": first_tap_ms - click_ms if first_tap_ms >= 0 else -1,
		"dessert_skipped": dessert_skipped,
		"base_speed": base_speed,
		"speed_setting": speed_setting,
		"reduced_motion": reduced_motion,
		"step_count": step_count,
		"planned_ms": planned_ms,
	}


## The `count_up` event of `count`, the count-up just played for `shift` from the CHECKOUT click at
## `click_ms` with `context` (count_up's fields, read from the count-up and its plan).
static func count_up_of(
	count: CountUp, shift: int, click_ms: int, context: CountUpContext
) -> Dictionary:
	return count_up(
		shift,
		click_ms,
		count.total_shown_ms,
		count.fast_forward_used,
		count.first_tap_ms,
		count.dessert_skipped,
		count.plan.base_speed,
		context.speed_setting,
		context.reduced_motion,
		count.plan.step_count,
		count.plan.planned_ms
	)


## The `redraw` event (a basket redraw, plan section 3.8): the basket (1-based), the hand places
## swapped (0-based, left first), and the cards replaced and received (ids, in the places'
## order). `basket` and `places` were added with the basket redraw; older logs have only the ids.
static func redraw(
	basket: int, places: Array[int], replaced: Array[CardInstance], received: Array[CardInstance]
) -> Dictionary:
	return {
		"basket": basket + 1,
		"places": Array(places),
		"cards_replaced": card_ids(replaced),
		"cards_received": card_ids(received),
	}


## Card ids in order, as logged (`cards_drawn`, `final_order`, redraws).
static func card_ids(cards: Array[CardInstance]) -> Array:
	var ids: Array = []
	for card: CardInstance in cards:
		ids.append(String(card.definition.id))
	return ids


## Card definition ids in order (`starting_deck`).
static func definition_ids(cards: Array[CardDefinition]) -> Array:
	var ids: Array = []
	for card: CardDefinition in cards:
		ids.append(String(card.id))
	return ids


static func _pct(share: float) -> float:
	return snappedf(share * 100.0, 0.1)


## Upgrade ids in order, as logged (`upgrades` in `run_end`).
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
