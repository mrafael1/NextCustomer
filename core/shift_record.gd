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
## The inspection this shift was played under, or null.
var inspection: InspectionDefinition
## The cards checked out, in row order (coupon uses for unlocks, full build plan 7.3).
var played: Array[CardDefinition] = []
## The RECEIPT REWARDS machine's visits after this shift (#77), in order: the ticket, the bonus
## ticket, STAMP DAY. Empty after a lost or the last shift.
var visits: Array[MachineVisit] = []


func _init(shift_number: int, shift_quota: int, shift_total: int) -> void:
	shift = shift_number
	quota = shift_quota
	total = shift_total
	passed = shift_total >= shift_quota


## Every register taken from the machine after this shift (REGISTER and STAMP DAY picks), in
## order.
func registers_taken() -> Array[UpgradeDefinition]:
	var found: Array[UpgradeDefinition] = []
	for visit: MachineVisit in visits:
		var prize: MachinePrize = visit.picked_prize()
		if prize != null and prize.kind == MachinePrize.Kind.REGISTER:
			found.append(prize.upgrade)
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
