class_name LegacySave
extends RefCounted
## Test helper (#108): turns a run's saved form (format 6, as parsed from JSON) back into the form
## an older format wrote, before the machine restructure (formats 4 and 5): the upgrade count at
## the checkout instead of the played upgrades, the old chute names and "boosted" for "premium".
## RunSaveMigration must read it back.


## `data` as format `version` saved it. A visit from the UPGRADE chute reads as `upgrade_chute`
## ("register" or "upgrades"); NEW ITEMS kept its name.
static func as_format(
	data: Dictionary, version: int, upgrade_chute: String = "register"
) -> Dictionary:
	var old: Dictionary = data.duplicate(true)
	old["format_version"] = version
	var machine: Dictionary = old["machine"]
	machine["upgrades_at_checkout"] = (machine["played_upgrades"] as Array).size()
	machine.erase("played_upgrades")
	for record: Dictionary in old["history"]:
		for visit: Dictionary in record["visits"]:
			_old_visit(visit, upgrade_chute)
	if not (machine["visit"] as Dictionary).is_empty():
		_old_visit(machine["visit"], upgrade_chute)
	return old


static func _old_visit(visit: Dictionary, upgrade_chute: String) -> void:
	if visit["chute"] == "upgrade":
		visit["chute"] = upgrade_chute
	visit["boosted"] = visit["premium"]
	visit.erase("premium")
