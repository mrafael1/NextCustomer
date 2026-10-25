class_name MachineDefinition
extends Resource
## The RECEIPT REWARDS machine's rules data (#77, build spec 1.2): one file,
## data/balance/machine.tres, referenced from BalanceDefinition.machine. Every number the machine
## uses lives here: the odds levels and the level each shift's visits draw at, the tier odds, the
## rarity lists, the register cap, the PREMIUM shifts and their floors, the bonus ticket, what each
## chute's draw holds, and the item upgrade chains.
##
## One machine, two chutes (#108, v0.61): NEW ITEMS (new cards for the cart: products, which can
## arrive BIG or GOLDEN, and coupons_per_draw coupons) and UPGRADE (improve what you own: loyalty
## perks, new or a level-up, and item upgrades). The machine is CLASSIC, or PREMIUM after one of
## premium_shifts (and on the BONUS visit that follows it): every drop at least
## premium_min_rarity, every NEW ITEMS product with a chain at least premium_min_tier. Rarity also
## rises with the run's progress: the visits after a shift draw at that shift's odds level
## (shift_odds_levels).
##
## A prize's rarity comes from these lists: a card or upgrade in a rare list is RARE, in a
## legendary list LEGENDARY, any other is COMMON. A perk's level takes its family's rarity.

## Prizes one visit draws (fewer when the pools run out: a short draw).
@export var prizes_per_visit: int = 0
## One entry per odds level, from 0; the highest level is size - 1.
@export var odds_levels: Array[MachineOddsLevel] = []
@export var rare_products: Array[CardDefinition] = []
@export var legendary_products: Array[CardDefinition] = []
@export var rare_coupons: Array[CardDefinition] = []
@export var legendary_coupons: Array[CardDefinition] = []
@export var rare_upgrades: Array[UpgradeDefinition] = []
@export var legendary_upgrades: Array[UpgradeDefinition] = []
## The loyalty card's boxes: once the run picked this many new perks from the machine, UPGRADE
## offers only level-ups of owned perks (a starting deck's starting_upgrade doesn't count, nor
## does a level-up).
@export var register_cap: int = 0
## 1-based shifts after which the machine is PREMIUM: the ticket's visit and the BONUS visit that
## follows it.
@export var premium_shifts: PackedInt32Array = PackedInt32Array()
## A PREMIUM visit's rarity floor (MachinePrize.Rarity) on every drop, and its tier floor
## (CardDefinition.Tier) for NEW ITEMS products with an upgrade chain (others stay plain).
@export var premium_min_rarity: int = 0
@export var premium_min_tier: int = 0
## NEW ITEMS: how many of a draw's drops are coupons (the last drops; products when there is no
## coupon to draw).
@export var coupons_per_draw: int = 0
## UPGRADE: how many of a draw's first drops are loyalty perks, then how many are item upgrades
## (the rest draw from both; each falls back to the other when it has nothing).
@export var loyalty_per_draw: int = 0
@export var item_upgrades_per_draw: int = 0
## The odds level (an index of odds_levels) the visits after each 1-based shift draw at: entry
## i is shift i + 1's; a shift past the end uses the last entry (none: level 0).
@export var shift_odds_levels: PackedInt32Array = PackedInt32Array()
## A passed inspected shift gives a BONUS visit (the bonus ticket).
@export var bonus_after_inspection: bool = false
## 1-based shifts that give a BONUS visit without an inspection (a balance lever; empty: none).
@export var bonus_extra_shifts: PackedInt32Array = PackedInt32Array()
## The run's first NEW ITEMS draw holds the stock's newest new arrival, at its own rarity.
@export var new_arrival_first_visit: bool = false
## SHELF UPGRADE (a LEGENDARY item upgrade) needs this many copies that can step.
@export var shelf_min_copies: int = 0
## The aisle families a family perk can name and the draw counts (#108: Food is left out, so it
## never counts): an UPGRADE draw's guarantee reads the deck's two most common of them
## (UpgradeDefinition.fits).
@export var families: PackedStringArray = PackedStringArray()
## The products the UPGRADE chute can upgrade, one chain each (NEW ITEMS draws their BIG and
## GOLDEN tiers too).
@export var item_upgrades: Array[ItemUpgradeDefinition] = []


## The highest odds level (0 with no odds levels).
func max_level() -> int:
	return maxi(odds_levels.size() - 1, 0)


## The odds level the visits after a 1-based shift draw at (shift_odds_levels), clamped to the
## levels there are.
func odds_level_after(shift_number: int) -> int:
	if shift_odds_levels.is_empty():
		return 0
	var index: int = clampi(shift_number - 1, 0, shift_odds_levels.size() - 1)
	return clampi(shift_odds_levels[index], 0, max_level())


## Whether the visits after a 1-based shift are PREMIUM.
func is_premium_shift(shift_number: int) -> bool:
	return premium_shifts.has(shift_number)


## The odds of an odds level, clamped to the levels there are; null with none.
func odds_level(level: int) -> MachineOddsLevel:
	if odds_levels.is_empty():
		return null
	return odds_levels[clampi(level, 0, odds_levels.size() - 1)]


## A stocked product's rarity (MachinePrize.Rarity).
func product_rarity(card: CardDefinition) -> int:
	return _rarity(legendary_products.has(card), rare_products.has(card))


func coupon_rarity(card: CardDefinition) -> int:
	return _rarity(legendary_coupons.has(card), rare_coupons.has(card))


## A perk's rarity: its family's (a level file takes its LV 1 file's rarity).
func upgrade_rarity(upgrade: UpgradeDefinition) -> int:
	return _rarity(_has_family(legendary_upgrades, upgrade), _has_family(rare_upgrades, upgrade))


static func _has_family(list: Array[UpgradeDefinition], upgrade: UpgradeDefinition) -> bool:
	return list.any(func(listed: UpgradeDefinition) -> bool: return listed.same_perk(upgrade))


static func _rarity(legendary: bool, rare: bool) -> int:
	if legendary:
		return MachinePrize.Rarity.LEGENDARY
	return MachinePrize.Rarity.RARE if rare else MachinePrize.Rarity.COMMON
