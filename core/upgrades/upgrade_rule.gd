class_name UpgradeRule
extends Resource
## Base class for register upgrade rules (plan section 3.8). A rule overrides only the hooks it
## needs. The hooks have the same names as Rule's, but upgrade rules are never attached to a
## card: the scoring loop asks every rule of every owned upgrade about every slot. Upgrades
## never receive or arm card effects.
##
## Rules are shared resources and must stay stateless. Every exported number defaults to a
## neutral value (0, or 1 for names ending in "factor"), because Godot doesn't write values
## equal to the default into .tres files. A test enforces this.

## Text for this rule's receipt lines. Empty means the upgrade's name.
@export var receipt_text: String = ""


## Context pass, after every card's own context changes: change adjacency in the row (Rule
## bender), through ScoreState.link_products. Scoring marks the steps added here as this
## upgrade's (source_kind UPGRADE) and gives them the upgrade's receipt text, so a rule passes
## its own slot as the source and an empty text.
func modify_context(_state: ScoreState, _slot: int) -> void:
	pass


## Value pass, after the card's own and effect flat bonuses: a flat bonus for this slot.
func flat_bonus(_state: ScoreState, _slot: int) -> int:
	return 0


## Value pass, after the card's own and effect multipliers and after a copy: a multiplier for
## this slot. A factor aimed at a value of 0 has nothing to multiply: the engine then records a
## WASTED step with wasted_reason() instead of a MULTIPLIER step.
func multiplier(_state: ScoreState, _slot: int) -> int:
	return 1


## Why this rule's multiplier did nothing at this slot (the value was 0). Asked only then.
func wasted_reason(_state: ScoreState, _slot: int) -> String:
	return ""


func text_for(upgrade: UpgradeDefinition) -> String:
	return receipt_text if not receipt_text.is_empty() else upgrade.display_name
