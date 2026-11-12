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


## Whether this rule makes the card at `slot` do a job its own rule fizzles at (#128's Lemon
## squeezer: a Lemon outside a CHAIN still doubles the next Produce), so that card reports no
## WASTED step for it, as Banana stand's chained links don't (ScoreState.chained).
func spares_waste(_state: ScoreState, _slot: int) -> bool:
	return false


## Whether this rule reads ScoreState.wasted at a slot (v1.28's Salvage desk: WASTED items pay
## ×2). Scoring then marks each product's own WASTED status before the upgrades' multipliers (and
## on a total-only score too), so the rule sees that product's own fizzle.
func reads_waste() -> bool:
	return false


## When `card` arms an effect: whether this rule reaches it past its own charges (#108's Fire
## sale, and Lemon squeezer until v0.56 / #128: the card's charged multiplier reaches every
## later product with its tag). Those uses are this upgrade's steps; the card's own charges stay
## the card's.
func reaches(_card: CardDefinition) -> bool:
	return false


## After the whole row's value pass: why this rule's condition was never met anywhere in the row
## (#45: no coupon for the Coupon engine, too few cards for the Slot engine), or "" when it
## was, or when the rule has no condition. A non-empty reason becomes one WASTED step, the
## upgrade's, on the row's last slot. A rule with neutral numbers never fizzles.
func row_wasted_reason(_state: ScoreState) -> String:
	return ""


func text_for(upgrade: UpgradeDefinition) -> String:
	return receipt_text if not receipt_text.is_empty() else upgrade.display_name
