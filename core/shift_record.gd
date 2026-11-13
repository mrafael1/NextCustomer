class_name ShiftRecord
extends RefCounted
## One entry of the run history (plan section 3.8): a played shift, its result, the inspection
## it was played under (section 3.9) and the RECEIPT REWARDS machine's visits after it (#77).
## Created at checkout and completed by the visits that follow it. to_dictionary is the form the
## event log and the run save (RunSave) use; from_dictionary reads it back.

## 1-based shift number.
var shift: int = 0
var quota: int = 0
var total: int = 0
var passed: bool = false
## The day events this shift was played under (several inspections on a Manager's review, v0.65;
## a boon day's boon, v0.69): inspections first, then boons.
var inspections: Array[InspectionDefinition] = []
## The first inspection (a MALUS: a boon is never one) this shift was played under, or null:
## setting it makes that one the shift's only event (null: none).
var inspection: InspectionDefinition:
	get:
		var found: Array[InspectionDefinition] = InspectionDefinition.maluses(inspections)
		return found[0] if not found.is_empty() else null
	set(value):
		inspections = []
		if value != null:
			inspections.append(value)
## The cards checked out, in row order (coupon uses for unlocks, full build plan 7.3).
var played: Array[CardDefinition] = []
## The RECEIPT REWARDS machine's visits after this shift (#77), in order: the ticket, the bonus
## ticket, the OVERTIME ticket. Empty after a missed (a write-up, v0.65) or the last shift.
var visits: Array[MachineVisit] = []
## A Day off pin's skipped shift (#132): passed on its quota with nothing played.
var day_off: bool = false
## The over-quota rewards it earned at its checkout (2026-11-05, OvertimeTickets.grant): an
## OVERTIME visit after it, and its ticket's visit turned PREMIUM. Each uses its week's.
var overtime_ticket: bool = false
var overtime_premium: bool = false
## The checkout's best item and longest combo (v1.37, the final receipt's BEST line:
## RunHighlight.record_best): the biggest single payout and its card (0 and null: none), and the
## longest CHAIN, BATCH or MORNING, its keyword, length and pay ("" and 0: none). A record saved
## before v1.37 has none of them.
var best_payout: int = 0
var best_card: CardDefinition
var best_combo_keyword: String = ""
var best_combo_length: int = 0
var best_combo_pay: int = 0


func _init(shift_number: int, shift_quota: int, shift_total: int) -> void:
	shift = shift_number
	quota = shift_quota
	total = shift_total
	passed = shift_total >= shift_quota


## Every loyalty perk taken from the machine after this shift (new perks and level-ups; before
## v0.61 also STAMP DAY's), in order.
func registers_taken() -> Array[UpgradeDefinition]:
	var found: Array[UpgradeDefinition] = []
	for visit: MachineVisit in visits:
		var prize: MachinePrize = visit.picked_prize()
		if prize != null and prize.kind == MachinePrize.Kind.REGISTER:
			found.append(prize.upgrade)
	return found


## The new perks taken after this shift (each stamped a loyalty box; LV 1 only), in order.
func perks_added() -> Array[UpgradeDefinition]:
	var found: Array[UpgradeDefinition] = []
	for upgrade: UpgradeDefinition in registers_taken():
		if not PerkLevels.is_level_up(upgrade):
			found.append(upgrade)
	return found


## The level-ups taken after this shift (#108), in order.
func level_ups() -> Array[UpgradeDefinition]:
	var found: Array[UpgradeDefinition] = []
	for upgrade: UpgradeDefinition in registers_taken():
		if PerkLevels.is_level_up(upgrade):
			found.append(upgrade)
	return found


## Every card the machine added to the cart after this shift (products and coupons), in order.
func cards_added() -> Array[CardDefinition]:
	var found: Array[CardDefinition] = []
	for visit: MachineVisit in visits:
		var prize: MachinePrize = visit.picked_prize()
		if prize != null and prize.adds_card():
			found.append(prize.card)
	return found


func to_dictionary() -> Dictionary:
	var data: Dictionary = {
		"shift": shift,
		"quota": quota,
		"total": total,
		"passed": passed,
		"inspection": String(inspection.id) if inspection != null else "",
		"inspections":
		inspections.map(func(each: InspectionDefinition) -> String: return String(each.id)),
		"played": played.map(func(card: CardDefinition) -> String: return String(card.id)),
		"visits": visits.map(func(visit: MachineVisit) -> Dictionary: return visit.to_dictionary()),
	}
	if day_off:
		data["day_off"] = true
	# Written only when earned (a save or log from before them has neither: none earned).
	if overtime_ticket:
		data["overtime_ticket"] = true
	if overtime_premium:
		data["overtime_premium"] = true
	# Written only when set (v1.37; a save or log from before has neither: RunHighlight skips it).
	if best_card != null:
		data["best_payout"] = best_payout
		data["best_card"] = String(best_card.id)
	if not best_combo_keyword.is_empty():
		data["best_combo"] = {
			"keyword": best_combo_keyword,
			"length": best_combo_length,
			"pay": best_combo_pay,
		}
	return data


## Reads to_dictionary's form (as parsed from JSON), resolving ids through `lookup`. Returns
## null when a field is missing or of the wrong type, an id doesn't resolve, or `passed`
## doesn't match the total and quota.
static func from_dictionary(data: Dictionary, lookup: ContentLookup) -> ShiftRecord:
	var reader: SaveReader = SaveReader.new(data, lookup)
	var record: ShiftRecord = ShiftRecord.new(
		reader.whole("shift", 1),
		reader.whole("quota"),
		reader.whole("total", -SaveReader.MAX_EXACT)
	)
	var saved_passed: bool = reader.flag("passed")
	# Saves and logs before v0.65 name one inspection only.
	if data.has("inspections"):
		record.inspections = reader.inspections("inspections")
	else:
		record.inspection = reader.inspection("inspection")
	record.played = reader.cards("played")
	record.day_off = data.has("day_off") and reader.flag("day_off")
	record.overtime_ticket = data.has("overtime_ticket") and reader.flag("overtime_ticket")
	record.overtime_premium = data.has("overtime_premium") and reader.flag("overtime_premium")
	if data.has("best_card"):
		record.best_card = reader.card("best_card")
		record.best_payout = reader.whole("best_payout", 1)
	if data.has("best_combo"):
		if not data["best_combo"] is Dictionary:
			return null
		var combo: SaveReader = SaveReader.new(data["best_combo"], lookup)
		record.best_combo_keyword = combo.text("keyword")
		record.best_combo_length = combo.whole("length", RunHighlight.MIN_COMBO)
		record.best_combo_pay = combo.whole("pay", -SaveReader.MAX_EXACT)
		if not combo.ok or not RunHighlight.COMBO_WORDS.has(record.best_combo_keyword):
			return null
	for visit_data: Dictionary in reader.dictionaries("visits"):
		var visit: MachineVisit = MachineVisit.from_dictionary(visit_data, lookup)
		if visit == null:
			return null
		record.visits.append(visit)
	if not reader.ok or saved_passed != record.passed:
		return null
	return record
