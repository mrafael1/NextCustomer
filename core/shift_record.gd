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
## ticket. Empty after a missed (a write-up, v0.65) or the last shift.
var visits: Array[MachineVisit] = []


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
	for visit_data: Dictionary in reader.dictionaries("visits"):
		var visit: MachineVisit = MachineVisit.from_dictionary(visit_data, lookup)
		if visit == null:
			return null
		record.visits.append(visit)
	if not reader.ok or saved_passed != record.passed:
		return null
	return record
