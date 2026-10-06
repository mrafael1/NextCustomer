class_name UpgradeDefinition
extends Resource
## One register upgrade as designed (plan section 3.8). Upgrades last for the whole run and
## live on the loyalty card. Definitions are shared by reference and never changed at runtime;
## the run's owned upgrades are a list in RunState.
##
## Every exported value defaults to a neutral value, because Godot doesn't write a value that
## equals the default into a .tres file. That is why `type` starts at UNSET: every upgrade file
## must state its type, and a test rejects UNSET.

enum Type { UNSET, RULE_BENDER, SLOT_ENGINE, CATEGORY_ENGINE, COUPON_ENGINE, ECONOMY, RISKY }

@export var id: StringName = &""
@export var display_name: String = ""
@export var type: Type = Type.UNSET
## The ticket's effect line, e.g. "The first coupon in the row pays x2".
@export_multiline var effect_text: String = ""
## The ticket's condition, on its own line. May be empty.
@export_multiline var condition_text: String = ""
## The build this upgrade pushes towards, shown on the ticket.
@export var supported_build: String = ""
## Scoring rules, asked about every slot by the scoring loop (never attached to a card).
@export var rules: Array[UpgradeRule] = []
## Run modifier: redraws added to every shift.
@export var extra_redraws: int = 0


## The type as ticket text, e.g. "Coupon Engine".
func type_label() -> String:
	return String(Type.keys()[type]).capitalize()
