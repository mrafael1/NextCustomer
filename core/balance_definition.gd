class_name BalanceDefinition
extends Resource
## Run numbers that are tuned between playtest rounds (plan section 2). They live in
## data/balance/ so they can change without code changes.

## One quota per shift; the run has as many shifts as quotas.
@export var quotas: PackedInt32Array = PackedInt32Array()
@export var hand_size: int = 0
## How many cards one redraw can replace. A shift has one redraw.
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
