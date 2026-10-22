class_name MachineDefinition
extends Resource
## The RECEIPT REWARDS machine's rules data (#77, build spec 1.2): one file,
## data/balance/machine.tres, referenced from BalanceDefinition.machine. Every number the machine
## uses lives here: the odds per Regular level, the rarity lists, the register cap, the shifts
## that open UPGRADES, STAMP DAY and the bonus ticket, and the item upgrade chains.
##
## A prize's rarity comes from these lists: a card or upgrade in a rare list is RARE, in a
## legendary list LEGENDARY, any other is COMMON.

## Prizes one visit draws (fewer when the pools run out: a short draw).
@export var prizes_per_visit: int = 0
## One entry per Regular level, from 0; the highest level is size - 1.
@export var odds_levels: Array[MachineOddsLevel] = []
@export var rare_products: Array[CardDefinition] = []
@export var legendary_products: Array[CardDefinition] = []
@export var rare_coupons: Array[CardDefinition] = []
@export var legendary_coupons: Array[CardDefinition] = []
@export var rare_upgrades: Array[UpgradeDefinition] = []
@export var legendary_upgrades: Array[UpgradeDefinition] = []
## REGISTER shows CARD FULL once the run picked this many registers from the machine (a starting
## deck's starting_upgrade doesn't count).
@export var register_cap: int = 0
## 1-based shifts after which the UPGRADES chute is lit.
@export var upgrades_open_shifts: PackedInt32Array = PackedInt32Array()
## 1-based shifts after which a STAMP DAY visit follows when the run picked fewer registers than
## the same index of stamp_day_floor.
@export var stamp_day_shifts: PackedInt32Array = PackedInt32Array()
@export var stamp_day_floor: PackedInt32Array = PackedInt32Array()
## A passed inspected shift gives a BONUS visit (the bonus ticket).
@export var bonus_after_inspection: bool = false
## 1-based shifts that give a BONUS visit without an inspection (a balance lever; empty: none).
@export var bonus_extra_shifts: PackedInt32Array = PackedInt32Array()
## The run's first NEW ITEMS draw holds the stock's newest new arrival, at its own rarity.
@export var new_arrival_first_visit: bool = false
## SHELF UPGRADE (a LEGENDARY UPGRADES prize) needs this many copies that can step.
@export var shelf_min_copies: int = 0
## The products the UPGRADES chute can upgrade, one chain each.
@export var item_upgrades: Array[ItemUpgradeDefinition] = []


## The highest Regular level (0 with no odds levels).
func max_level() -> int:
	return maxi(odds_levels.size() - 1, 0)


## The odds of a Regular level, clamped to the levels there are; null with none.
func odds_level(level: int) -> MachineOddsLevel:
	if odds_levels.is_empty():
		return null
	return odds_levels[clampi(level, 0, odds_levels.size() - 1)]


## A stocked product's rarity (MachinePrize.Rarity).
func product_rarity(card: CardDefinition) -> int:
	return _rarity(legendary_products.has(card), rare_products.has(card))


func coupon_rarity(card: CardDefinition) -> int:
	return _rarity(legendary_coupons.has(card), rare_coupons.has(card))


func upgrade_rarity(upgrade: UpgradeDefinition) -> int:
	return _rarity(legendary_upgrades.has(upgrade), rare_upgrades.has(upgrade))


## The STAMP DAY floor after a 1-based shift: the registers the run should hold by then, or 0
## when the shift has no STAMP DAY.
func stamp_floor(shift_number: int) -> int:
	var index: int = stamp_day_shifts.find(shift_number)
	if index == -1 or index >= stamp_day_floor.size():
		return 0
	return stamp_day_floor[index]


static func _rarity(legendary: bool, rare: bool) -> int:
	if legendary:
		return MachinePrize.Rarity.LEGENDARY
	return MachinePrize.Rarity.RARE if rare else MachinePrize.Rarity.COMMON
