class_name BalanceDefinition
extends Resource
## Run numbers that are tuned between playtest rounds (plan section 2). They live in
## data/balance/ so they can change without code changes.

## One quota per shift; the run has as many shifts as quotas.
@export var quotas: PackedInt32Array = PackedInt32Array()
@export var hand_size: int = 0
## How many cards one redraw can replace. A shift has one redraw, plus each owned upgrade's
## extra_redraws (plan section 3.8).
@export var redraw_limit: int = 0
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
## The run's first offer always includes one of these (the combination coupons), when stocked.
@export var first_offer_pool: Array[CardDefinition] = []
@export var offer_size: int = 0
## 1-based shift numbers after which an upgrade is offered, once the reward is picked or
## skipped (plan section 3.8). Each is a shift of the run and never the last one.
@export var upgrade_shifts: PackedInt32Array = PackedInt32Array()
## Upgrades that upgrade offers draw from.
@export var upgrade_pool: Array[UpgradeDefinition] = []
## The most upgrades one offer shows.
@export var upgrade_offer_size: int = 0
## 1-based shift numbers played under an inspection (plan section 3.9). Each is announced on
## the previous shift's receipt, so each is a shift of the run and never shift 1.
@export var inspection_shifts: PackedInt32Array = PackedInt32Array()
## Inspections that an inspected shift draws from.
@export var inspection_pool: Array[InspectionDefinition] = []
