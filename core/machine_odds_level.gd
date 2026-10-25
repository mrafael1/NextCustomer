class_name MachineOddsLevel
extends Resource
## One odds level of the RECEIPT REWARDS machine (#77): the weights each drop rolls its
## rarity with (integers; the odds card shows them as percentages), an optional floor for the
## first drop, and the tier weights a NEW ITEMS product with an upgrade chain arrives at (#108,
## v0.61: plain, BIG or GOLDEN). Data in data/balance/machine.tres (MachineDefinition.odds_levels).

@export var common_weight: int = 0
@export var rare_weight: int = 0
@export var legendary_weight: int = 0
## 0: none. 1: drop 1 rolls RARE or LEGENDARY only, renormalised ("1 of 3 at least RARE").
## 2: drop 1 rolls LEGENDARY only.
@export var first_drop_min_rarity: int = 0
## The tier a NEW ITEMS product with an upgrade chain arrives at (#108): plain, BIG, GOLDEN.
## All three 0 (the neutral default): always plain.
@export var plain_weight: int = 0
@export var big_weight: int = 0
@export var golden_weight: int = 0


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


## The tier weights (plain, BIG, GOLDEN) with the tiers below `min_tier` zeroed; [1, 0, 0] (always
## plain) when nothing is left.
func tier_weights(min_tier: int = 0) -> PackedInt32Array:
	var found: PackedInt32Array = PackedInt32Array([plain_weight, big_weight, golden_weight])
	for tier: int in range(mini(min_tier, found.size())):
		found[tier] = 0
	var total: int = 0
	for weight: int in found:
		total += maxi(weight, 0)
	if total <= 0:
		return PackedInt32Array([1, 0, 0])
	return found
