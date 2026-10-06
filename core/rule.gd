class_name Rule
extends Resource
## Base class for card rules. A rule overrides only the hooks it needs.
##
## Rules are shared resources and must stay stateless: anything that changes during a score
## lives in the ScoreState passed to each hook.
##
## Every exported number defaults to a neutral value (0, or 1 for names ending in "factor"),
## every enum to its first value (meaning "no effect"), and every bool to false. Godot doesn't
## write values equal to the default into .tres files, so a non-neutral default would let a
## script edit silently change card data. A test enforces this.

## Text for this rule's receipt lines. Empty means the card's name.
@export var receipt_text: String = ""


## Context pass: change tags or adjacency in the row.
func modify_context(_state: ScoreState, _slot: int) -> void:
	pass


## Value pass: a flat bonus this card gives itself.
func flat_bonus(_state: ScoreState, _slot: int) -> int:
	return 0


## Value pass: a multiplier this card gives itself.
func multiplier(_state: ScoreState, _slot: int) -> int:
	return 1


## Value pass, after multipliers: the slot whose final payout this card copies (Repeat), or
## -1 for none. The copy is never multiplied again and triggers nothing.
func copied_from(_state: ScoreState, _slot: int) -> int:
	return -1


## Value pass, last step: the final payout. Return `payout` unchanged to keep it.
func final_payout(_state: ScoreState, _slot: int, payout: int) -> int:
	return payout


## After this card's payout and its armed effects: why this rule did nothing in this slot, or
## "" if it worked. A non-empty reason becomes a WASTED step, a "fizzle" moment for the receipt
## and count-up.
func wasted_reason(_state: ScoreState, _slot: int) -> String:
	return ""


## After this card's payout: start effects for later cards through ScoreState.add_effect,
## which records an EFFECT_ARMED step for each one.
func on_scanned(_state: ScoreState, _slot: int) -> void:
	pass


func text_for(card: CardDefinition) -> String:
	return receipt_text if not receipt_text.is_empty() else card.display_name
