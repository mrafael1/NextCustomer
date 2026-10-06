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
## Cards that reward offers draw from (plan section 5).
@export var reward_pool: Array[CardDefinition] = []
## The run's first offer always includes one of these (the combination coupons).
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
