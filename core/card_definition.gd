class_name CardDefinition
extends Resource
## One card as designed. Definitions are shared by reference and never changed at runtime:
## per-run state lives in CardInstance, per-score state in ScoreState.
##
## Every exported value defaults to a neutral value, because Godot doesn't write a value that
## equals the default into a .tres file. That is why `kind` starts at UNSET: every card file
## must state its kind, and a test rejects UNSET.

enum Kind { UNSET, PRODUCT, COUPON }

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.UNSET
## Marks coupons that bridge adjacency instead of breaking it (Bundle).
@export var is_connector: bool = false
@export var tags: PackedStringArray = PackedStringArray()
@export var base: int = 0
@export var rules: Array[Rule] = []
## Rule text shown on the placeholder card.
@export_multiline var rule_text: String = ""
## Reward offers include at least one card with this flag (plan section 5).
@export var generally_useful: bool = false
@export var art_ref: String = ""


func is_product() -> bool:
	return kind == Kind.PRODUCT


func is_coupon() -> bool:
	return kind == Kind.COUPON
