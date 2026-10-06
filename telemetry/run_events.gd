class_name RunEvents
extends RefCounted
## Builds the data of the upgrade-related log events (plan section 8), so their fields are
## defined and tested in one place. The shift screen logs them.


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


## Upgrade ids in order, as logged (`offered` in `upgrade`, `upgrades` in `run_end`).
static func upgrade_ids(upgrades: Array[UpgradeDefinition]) -> Array:
	var ids: Array = []
	for upgrade: UpgradeDefinition in upgrades:
		ids.append(String(upgrade.id))
	return ids
