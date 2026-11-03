class_name MachineOddsLevel
extends Resource
## One odds level of the RECEIPT REWARDS machine (#77): the weights each drop rolls its
## rarity with (integers; the odds card shows them as percentages) and an optional floor for the
## first drop. A NEW ITEMS product's tier is its rarity (v0.93), so these weights pick it too.
## Data in data/balance/machine.tres (MachineDefinition.odds_levels).

@export var common_weight: int = 0
@export var rare_weight: int = 0
@export var legendary_weight: int = 0
## 0: none. 1: drop 1 rolls RARE or LEGENDARY only, renormalised ("1 of 3 at least RARE").
## 2: drop 1 rolls LEGENDARY only.
@export var first_drop_min_rarity: int = 0


## The weights (COMMON, RARE, LEGENDARY) drop `drop_index` (0-based) rolls with: the weights below
## `min_rarity` (a PREMIUM visit's floor) are zeroed, and on drop 0 those below
## first_drop_min_rarity too.
func weights(drop_index: int, min_rarity: int = 0) -> PackedInt32Array:
	var found: PackedInt32Array = PackedInt32Array([common_weight, rare_weight, legendary_weight])
	var floor_rarity: int = min_rarity
	if drop_index == 0:
		floor_rarity = maxi(floor_rarity, first_drop_min_rarity)
	for rarity: int in range(mini(floor_rarity, found.size())):
		found[rarity] = 0
	return found
