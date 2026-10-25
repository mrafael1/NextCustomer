class_name PerkLevels
extends RefCounted
## Loyalty perk levels (#108, v0.61): an owned perk can be drawn again from the machine's UPGRADE
## chute as its next level, up to LV 3. Each level is its own UpgradeDefinition file, linked by
## `next_level`; a level-up replaces the perk in its own loyalty box, so the box count never
## grows. Pure and static: callers pass the run's upgrades.


## The index of the owned perk of the same family as `perk`, or -1.
static func owned_index(upgrades: Array[UpgradeDefinition], perk: UpgradeDefinition) -> int:
	for index: int in upgrades.size():
		if upgrades[index].same_perk(perk):
			return index
	return -1


## The upgrades after taking `perk`: a level-up replaces its family's box, a new perk is appended.
## A new list; `upgrades` is not changed.
static func with_pick(
	upgrades: Array[UpgradeDefinition], perk: UpgradeDefinition
) -> Array[UpgradeDefinition]:
	var found: Array[UpgradeDefinition] = upgrades.duplicate()
	var index: int = owned_index(found, perk)
	if index != -1 and is_level_up(perk):
		found[index] = perk
	else:
		found.append(perk)
	return found


## Each owned perk's next level (the level-ups the machine can offer), in box order.
static func level_ups(owned: Array[UpgradeDefinition]) -> Array[UpgradeDefinition]:
	var found: Array[UpgradeDefinition] = []
	for upgrade: UpgradeDefinition in owned:
		if upgrade.can_level_up():
			found.append(upgrade.next_level)
	return found


## Whether `perk` is a level above LV 1 (taking it levels up an owned perk).
static func is_level_up(perk: UpgradeDefinition) -> bool:
	return perk != null and perk.level_number() > 1


## Whether the run owns the level just below `perk` (so it can be taken as a level-up).
static func owns_previous(upgrades: Array[UpgradeDefinition], perk: UpgradeDefinition) -> bool:
	return upgrades.any(func(upgrade: UpgradeDefinition) -> bool: return upgrade.next_level == perk)
