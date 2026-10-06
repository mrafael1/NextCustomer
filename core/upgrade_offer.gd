class_name UpgradeOffer
extends RefCounted
## Builds the upgrades offered after an upgrade shift (plan section 3.8), using only the RNG
## passed in. The offer holds up to upgrade_offer_size upgrades from upgrade_pool that the run
## doesn't own yet, each of a different type, chosen from the pool shuffled with the run's RNG.
## The rule "at least one fitting the current deck" waits for build tags (full build phase 2).


## Whether the 1-based shift number is an upgrade shift.
static func is_upgrade_shift(balance: BalanceDefinition, shift_number: int) -> bool:
	return balance.upgrade_shifts.has(shift_number)


static func make(
	rng: RandomNumberGenerator, balance: BalanceDefinition, owned: Array[UpgradeDefinition]
) -> Array[UpgradeDefinition]:
	var candidates: Array[UpgradeDefinition] = []
	for upgrade: UpgradeDefinition in balance.upgrade_pool:
		if not owned.has(upgrade) and not candidates.has(upgrade):
			candidates.append(upgrade)
	_shuffle(rng, candidates)
	var offer: Array[UpgradeDefinition] = []
	var types: Dictionary = {}
	for upgrade: UpgradeDefinition in candidates:
		if offer.size() >= balance.upgrade_offer_size:
			break
		if not types.has(upgrade.type):
			types[upgrade.type] = true
			offer.append(upgrade)
	return offer


## Fisher-Yates with the run's RNG. Array.shuffle() would use the global RNG.
static func _shuffle(rng: RandomNumberGenerator, upgrades: Array[UpgradeDefinition]) -> void:
	for index: int in range(upgrades.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var swap: UpgradeDefinition = upgrades[index]
		upgrades[index] = upgrades[other]
		upgrades[other] = swap
