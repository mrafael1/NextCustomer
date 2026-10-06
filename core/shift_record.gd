class_name ShiftRecord
extends RefCounted
## One entry of the run history (plan section 3.8): a played shift, its result, the reward card
## picked (or skipped), the upgrade taken and the inspection it was played under (section 3.9).
## Created at checkout and completed by the choices that follow it.

## 1-based shift number.
var shift: int = 0
var quota: int = 0
var total: int = 0
var passed: bool = false
## The reward card taken, or null (skipped, or no reward after a lost or last shift).
var card_picked: CardDefinition
## True when a reward was offered and skipped.
var reward_skipped: bool = false
## The upgrade taken after this shift, or null.
var upgrade_taken: UpgradeDefinition
## The inspection this shift was played under, or null.
var inspection: InspectionDefinition


func _init(shift_number: int, shift_quota: int, shift_total: int) -> void:
	shift = shift_number
	quota = shift_quota
	total = shift_total
	passed = shift_total >= shift_quota


func to_dictionary() -> Dictionary:
	return {
		"shift": shift,
		"quota": quota,
		"total": total,
		"passed": passed,
		"card_picked": String(card_picked.id) if card_picked != null else "",
		"reward_skipped": reward_skipped,
		"upgrade_taken": String(upgrade_taken.id) if upgrade_taken != null else "",
		"inspection": String(inspection.id) if inspection != null else "",
	}
