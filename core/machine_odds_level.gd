class_name MachineOddsLevel
extends Resource
## One Regular level of the RECEIPT REWARDS machine (#77): the weights each drop rolls its
## rarity with (integers; the odds card shows them as percentages), and an optional floor for the
## first drop. Data in data/balance/machine.tres (MachineDefinition.odds_levels).

@export var common_weight: int = 0
@export var rare_weight: int = 0
@export var legendary_weight: int = 0
## 0: none. 1: drop 1 rolls RARE or LEGENDARY only, renormalised ("1 of 3 at least RARE").
## 2: drop 1 rolls LEGENDARY only.
@export var first_drop_min_rarity: int = 0


## The weights (COMMON, RARE, LEGENDARY) drop `drop_index` (0-based) rolls with: drop 0 has the
## weights below first_drop_min_rarity zeroed.
func weights(drop_index: int) -> PackedInt32Array:
	var found: PackedInt32Array = PackedInt32Array([common_weight, rare_weight, legendary_weight])
	if drop_index == 0:
		for rarity: int in range(mini(first_drop_min_rarity, found.size())):
			found[rarity] = 0
	return found
