class_name TipTriggers
extends RefCounted
## What makes the one-time tips due (TipDefinition's triggers; TipScheduler asks), read from the
## run alone: the planning's day event, PAYDAY, week 2, a coupon or a BATCH card in the baskets, a
## belt card whose rule names a family other than Food, the projected total reaching SILVER; and
## T14's fix after a lost run, from the run's WASTED tally (wasted). Static and pure.

## The rules whose card should sit right before (or early against) the family it names: T14's
## "put {card} EARLIER than your best {family} ITEM" fits only these.
const GIVERS: Array[String] = [
	"GrantNextTagBonusRule", "GrantChargedMultiplierRule", "GrantTagToNextSlotRule"
]


## Whether planning trigger `trigger` (TipDefinition's) holds on the planning now: always for
## PLANNING; false for a trigger that isn't a planning one.
static func planning_due(trigger: StringName, run: RunState) -> bool:
	var due: bool = false
	match trigger:
		TipDefinition.PLANNING:
			due = true
		TipDefinition.DAY_EVENT:
			due = day_event(run)
		TipDefinition.PAYDAY:
			due = payday(run)
		TipDefinition.WEEK_TWO:
			due = week_two(run)
		TipDefinition.COUPON_IN_HAND:
			due = coupon_place(run) >= 0
		TipDefinition.FAMILY_RULE:
			due = family_rule_slot(run) >= 0
		TipDefinition.BATCH_IN_HAND:
			due = batch_in_hand(run)
		TipDefinition.MEDAL_REACH:
			due = medal_reached(run)
	return due


## Whether the planning's shift has a day event (GOOD DAY or INSPECTION; never the week's own).
static func day_event(run: RunState) -> bool:
	return not run.inspections.is_empty()


## Whether the planning's shift is PAYDAY (premium draws if passed).
static func payday(run: RunState) -> bool:
	return Payday.if_passed(run)


## Whether the planning's shift is in week 2 or later (the training week is over).
static func week_two(run: RunState) -> bool:
	return WeekSchedule.week_of(run.balance, run.shift_index + 1) >= 1


## The hand place of the first coupon in the baskets, or -1.
static func coupon_place(run: RunState) -> int:
	var places: Array[CardInstance] = run.hand_places()
	for place: int in places.size():
		var card: CardInstance = places[place]
		if card != null and card.definition.is_coupon():
			return place
	return -1


## Whether a BATCH card is in the baskets.
static func batch_in_hand(run: RunState) -> bool:
	for card: CardInstance in run.hand_places():
		if card != null and CardText.names_batch(card.definition):
			return true
	return false


## The belt slot of the first card whose rule names a family other than the quiet ones (Food), or
## -1.
static func family_rule_slot(run: RunState) -> int:
	for slot: int in run.row.size():
		if not rule_family(run.row[slot].definition).is_empty():
			return slot
	return -1


## The family `definition`'s rule names, when it isn't a quiet one (Food); "" for none.
static func rule_family(definition: CardDefinition) -> String:
	var palette: FamilyPalette = FamilyPalette.shared()
	var product: CardDefinition = definition.product_card()
	if product == null:
		return ""
	for rule: Rule in product.rules:
		var family: String = CardFamilies.rule_family(
			rule, product, palette.main_family_order, FamilyPalette.data_card
		)
		if not family.is_empty() and not palette.quiet_families.has(family):
			return family
	return ""


## The names of the row's items in `slots`.
static func names_at(run: RunState, slots: PackedInt32Array) -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for slot: int in slots:
		if slot < run.row.size():
			names.append(run.row[slot].definition.display_name)
	return names


## Whether the row's projected total reaches the SILVER medal (the machine's laps of the quota).
static func medal_reached(run: RunState) -> bool:
	var machine: MachineDefinition = run.balance.machine
	if machine == null or machine.overtime_ticket_laps <= 0:
		return false
	return run.preview().total >= run.quota() * machine.overtime_ticket_laps


## The cards WASTED in a checkout scored `result`, its row `played` (slot order).
static func wasted(result: ScoreResult, played: Array[CardDefinition]) -> Array[CardDefinition]:
	var found: Array[CardDefinition] = []
	if result == null:
		return found
	for slot: int in played.size():
		if PlanHint.wasted_at(result, slot):
			found.append(played[slot])
	return found


## T14's fix from the run's WASTED tally (card id -> times): the most wasted card whose rule gives
## to a family (GIVERS), as [its name, that family]; empty when none fits (the fallback line).
static func lost_fix(tally: Dictionary, lookup: ContentLookup) -> PackedStringArray:
	var best: CardDefinition = null
	var most: int = 0
	for card_id: Variant in tally:
		var card: CardDefinition = lookup.card(String(card_id))
		if card == null or int(tally[card_id]) <= most or _giver_family(card).is_empty():
			continue
		best = card
		most = int(tally[card_id])
	if best == null:
		return PackedStringArray()
	return PackedStringArray([best.display_name, _giver_family(best)])


static func _giver_family(card: CardDefinition) -> String:
	var product: CardDefinition = card.product_card()
	if product == null:
		return ""
	var palette: FamilyPalette = FamilyPalette.shared()
	for rule: Rule in product.rules:
		var script: Script = rule.get_script() as Script
		if script == null or not GIVERS.has(String(script.get_global_name())):
			continue
		var family: String = CardFamilies.rule_family(
			rule, product, palette.main_family_order, FamilyPalette.data_card
		)
		if not family.is_empty():
			return family
	return ""
