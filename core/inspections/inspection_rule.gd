class_name InspectionRule
extends Resource
## Base class for day event rules (plan section 3.9; inspections, and boons since v0.69). A rule
## overrides only the hooks it needs. The hooks have the same names as Rule's, but these rules are
## never attached to a card: the scoring loop asks every rule of the shift's day events about
## every slot. Every value they change is a step of their own (source_kind INSPECTION), so the
## count-up shows it coming from the event's chip.
##
## Rules are shared resources and must stay stateless. Every exported number defaults to a
## neutral value (0, or 1 for names ending in "factor"), because Godot doesn't write values
## equal to the default into .tres files. A test enforces this.

## Text for this rule's receipt lines. Empty means the event's name.
@export var receipt_text: String = ""


## Value pass, after the card's own, effect and upgrade flat bonuses: a flat bonus for this slot
## (negative for a malus: Late delivery's -€2), given the slot's value so far (`value`), so a
## malus never takes it below 0.
func flat_bonus(_state: ScoreState, _slot: int, _value: int) -> int:
	return 0


## Value pass, after the upgrades' multipliers: a multiplier for this slot (Free samples' ×2). A
## factor aimed at a value of 0 has nothing to multiply: the engine then records a WASTED step
## with wasted_reason() instead of a MULTIPLIER step.
func multiplier(_state: ScoreState, _slot: int) -> int:
	return 1


## Why this rule's multiplier did nothing at this slot (the value was 0). Asked only then.
func wasted_reason(_state: ScoreState, _slot: int) -> String:
	return ""


## After the whole row's value pass: why this rule never found its target in the row (a boon with
## nothing to boost: Free samples with no product), or "" when it did or has no target. A
## non-empty reason becomes one WASTED step, the event's, on the row's last slot.
func row_wasted_reason(_state: ScoreState) -> String:
	return ""


## Value pass, last step, after the card's own payout overrides: the final payout. Return
## `payout` unchanged to keep it.
func final_payout(_state: ScoreState, _slot: int, payout: int) -> int:
	return payout


func text_for(inspection: InspectionDefinition) -> String:
	return receipt_text if not receipt_text.is_empty() else inspection.display_name
