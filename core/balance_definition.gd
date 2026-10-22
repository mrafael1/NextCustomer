class_name BalanceDefinition
extends Resource
## Run numbers that are tuned between playtest rounds (plan section 2). They live in
## data/balance/ so they can change without code changes.

## One quota per shift; the run has as many shifts as quotas.
@export var quotas: PackedInt32Array = PackedInt32Array()
@export var hand_size: int = 0
## Redraws every shift allows before upgrades; a shift adds each owned upgrade's
## extra_redraws (plan section 3.8, ShiftLimits).
@export var base_redraws: int = 0
## Hand cards per basket: hand place p is in basket p / basket_size, and a redraw replaces one
## basket's hand cards (plan section 3.8). The shift screen draws two items to a basket
## (HandRow.ITEMS_PER_BASKET), so only 2 is supported; a test pins the two equal.
@export var basket_size: int = 0
## Product slots: the most products the row holds (plan section 3.1).
@export var slot_count: int = 0
## Coupon-only slots on top of the product slots: the row holds at most slot_count +
## coupon_slot_count cards, and only coupons can use the extra room.
@export var coupon_slot_count: int = 0
@export var deck_limit: int = 0
## The store's aisles in data order (full build plan 7.2). The run's stock (RunStock) holds
## the starting deck's products, the listed aisles, the new arrivals and coupon_pool.
@export var aisles: Array[AisleDefinition] = []
## Coupons every run stocks. Coupons are never in aisles or capsules.
@export var coupon_pool: Array[CardDefinition] = []
## How many aisles the shopping list picks when the listable aisles exceed the budget.
@export var run_aisle_picks: int = 0
## The most products the listable aisles may hold together for all of them to be stocked
## without a list.
@export var aisle_stock_budget: int = 0
## Items a machine-opened aisle (no base cards) must hold to be listable.
@export var aisle_listable_min: int = 0
## The most new arrivals (end-cap items) a run stocks.
@export var end_cap_max: int = 0
## New arrivals are capsule items that came out in this many previous runs.
@export var end_cap_window_runs: int = 0
## The run's first COUPONS draw from the RECEIPT REWARDS machine holds one of these (the
## combination coupons), when stocked.
@export var first_offer_pool: Array[CardDefinition] = []
## Upgrades the machine's REGISTER chute draws from (#77).
@export var upgrade_pool: Array[UpgradeDefinition] = []
## 1-based shift numbers played under an inspection (plan section 3.9). Each is announced on
## the previous shift's receipt, so each is a shift of the run and never shift 1.
@export var inspection_shifts: PackedInt32Array = PackedInt32Array()
## Inspections that an inspected shift draws from.
@export var inspection_pool: Array[InspectionDefinition] = []
## Coins a run pays at its end (full build plan 7.1, CoinPayout), by the number of shifts
## passed: index 0 to the number of shifts (a won run). Shorter tables use their last entry.
@export var coins_by_shifts_passed: PackedInt32Array = PackedInt32Array()
## Overtime coins: one per this many euros over quota, summed over the passed shifts (0: none).
@export var overtime_coin_euros: int = 0
## The most overtime coins one run pays.
@export var overtime_coin_max: int = 0
## The RECEIPT REWARDS machine's rules (#77, data/balance/machine.tres), so a balance copy can
## point at a different machine file.
@export var machine: MachineDefinition


## The aisle a card is stocked from (full build plan 7.2), or null for a staple or a coupon. A
## variant belongs to its base product's aisle ("same product", plan section 3). The cards show
## the aisle's sign colour and glyph.
func aisle_of(card: CardDefinition) -> AisleDefinition:
	if card == null or not card.is_product():
		return null
	for aisle: AisleDefinition in aisles:
		for stocked: CardDefinition in aisle.base_cards + aisle.capsule_cards:
			if stocked.is_same_product(card):
				return aisle
	return null
