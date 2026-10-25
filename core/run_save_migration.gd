class_name RunSaveMigration
extends RefCounted
## Converts a run save from before v0.61's machine restructure (#108: formats 4 and 5) to format 6,
## so a run saved before the update resumes instead of being refused. Pure: it works on a deep copy
## of the parsed JSON and never prints. RunSave.from_dictionary checks the result like any save.
##
## What changes:
## - Every visit (the history's and the machine's): the chutes are renamed ("coupons" becomes
##   "new_items", "register" and "upgrades" become "upgrade"), "boosted" becomes "premium", and a
##   STAMP DAY visit in the history becomes a ticket visit (its pick stays, so the perk it stamped
##   still counts toward the register cap).
## - The machine: the count of upgrades owned at the checkout becomes the list of those upgrades
##   (the run's first ones), and a queued STAMP DAY is dropped.
## - A STAMP DAY waiting for its pick (always the shift's last visit) is dropped without its free
##   perk: the machine idles and the run waits for the next shift (SCORED).
## - A visit waiting for its pick from an old COUPONS, REGISTER or UPGRADES draw keeps its prizes
##   under the new chute's name, so the player sees the same tickets and the pick works.

## The formats this converts from.
const FROM_VERSIONS: Array[int] = [4, 5]
const TO_VERSION := 6
## Old chute names to new ones.
const CHUTES: Dictionary[String, String] = {
	"new_items": "new_items",
	"coupons": "new_items",
	"register": "upgrade",
	"upgrades": "upgrade",
}
const STAMP_DAY := "stamp_day"


## The save converted to format 6, or {} when its form can't be read (the caller refuses it).
static func to_v6(data: Dictionary) -> Dictionary:
	var found: Dictionary = data.duplicate(true)
	var history: Variant = found.get("history")
	if history is Array:
		for record: Variant in history:
			var visits: Variant = record.get("visits") if record is Dictionary else null
			for visit: Variant in visits if visits is Array else []:
				if visit is Dictionary:
					_convert_visit(visit, true)
	var machine: Variant = found.get("machine")
	if not machine is Dictionary or not _convert_machine(found, machine):
		return {}
	found["format_version"] = TO_VERSION
	return found


## The machine block: played upgrades, queue, current visit. False when it can't be read.
static func _convert_machine(save: Dictionary, machine: Dictionary) -> bool:
	var upgrades: Variant = save.get("upgrades")
	var at_checkout: Variant = machine.get("upgrades_at_checkout")
	if not upgrades is Array or not SaveReader.is_whole(at_checkout):
		return false
	var owned: Array = upgrades
	machine.erase("upgrades_at_checkout")
	machine["played_upgrades"] = owned.slice(0, clampi(int(at_checkout), 0, owned.size()))
	var queue: Variant = machine.get("queue")
	if queue is Array:
		machine["queue"] = (queue as Array).filter(
			func(kind: Variant) -> bool: return kind != STAMP_DAY
		)
	var visit: Variant = machine.get("visit")
	if not visit is Dictionary or (visit as Dictionary).is_empty():
		return true
	if visit.get("kind") == STAMP_DAY:
		machine["visit"] = {}
		machine["stage"] = "idle"
		machine["first_draw"] = false
		machine["queue"] = []
		save["phase"] = "scored"
		return true
	_convert_visit(visit, false)
	return true


## One visit: the chute's new name, "premium" for "boosted" and, in the history, a ticket for a
## STAMP DAY.
static func _convert_visit(visit: Dictionary, in_history: bool) -> void:
	var chute: Variant = visit.get("chute")
	if chute is String and CHUTES.has(chute):
		visit["chute"] = CHUTES[chute]
	if visit.has("boosted"):
		visit["premium"] = visit["boosted"]
		visit.erase("boosted")
	if in_history and visit.get("kind") == STAMP_DAY:
		visit["kind"] = "ticket"
		visit["premium"] = false
