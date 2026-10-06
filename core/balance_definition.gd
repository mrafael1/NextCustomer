class_name BalanceDefinition
extends Resource
## Run numbers that are tuned between playtest rounds (plan section 2). They live in
## data/balance/ so they can change without code changes.

## One quota per shift; the run has as many shifts as quotas.
@export var quotas: PackedInt32Array = PackedInt32Array()
@export var hand_size: int = 0
## How many cards one redraw can replace. A shift has one redraw.
@export var redraw_limit: int = 0
@export var slot_count: int = 0
@export var deck_limit: int = 0
