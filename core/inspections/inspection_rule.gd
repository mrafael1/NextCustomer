class_name InspectionRule
extends Resource
## Base class for inspection rules (plan section 3.9). A rule overrides only the hooks it needs.
## The hooks have the same names as Rule's, but inspection rules are never attached to a card:
## the scoring loop asks every rule of the shift's inspections about every slot.
##
## Rules are shared resources and must stay stateless. Every exported number defaults to a
## neutral value (0, or 1 for names ending in "factor"), because Godot doesn't write values
## equal to the default into .tres files. A test enforces this.

## Text for this rule's receipt lines. Empty means the inspection's name.
@export var receipt_text: String = ""


## Value pass, last step, after the card's own payout overrides: the final payout. Return
## `payout` unchanged to keep it.
func final_payout(_state: ScoreState, _slot: int, payout: int) -> int:
	return payout


func text_for(inspection: InspectionDefinition) -> String:
	return receipt_text if not receipt_text.is_empty() else inspection.display_name
