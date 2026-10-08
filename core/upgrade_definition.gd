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
## The builds this upgrade pushes towards (data/builds), shown on the ticket. None means any
## build (Extra redraw).
@export var builds: Array[BuildDefinition] = []
## Scoring rules, asked about every slot by the scoring loop (never attached to a card).
@export var rules: Array[UpgradeRule] = []
## Run modifiers (ShiftLimits), from the shift after the pick: redraws added to every shift,
## product slots and coupon-only slots added to the row, and the quota raised by this percent
## (Big basket, rounded up to whole euros).
@export var extra_redraws: int = 0
@export var extra_slots: int = 0
@export var extra_coupon_slots: int = 0
@export var quota_percent: int = 0


## The ticket's "Supports" text: the builds' names, or "Any build".
func build_names() -> String:
	if builds.is_empty():
		return "Any build"
	return ", ".join(builds.map(func(build: BuildDefinition) -> String: return build.display_name))


## Whether this upgrade fits a deck (an upgrade offer guarantees one that does): one of its
## builds fits. An Economy upgrade helps any deck, so it never counts as fitting one.
func fits(deck: Array[CardDefinition]) -> bool:
	if type == Type.ECONOMY:
		return false
	return builds.any(func(build: BuildDefinition) -> bool: return build.fits(deck))


## The type as ticket text, e.g. "Coupon Engine".
func type_label() -> String:
	return String(Type.keys()[type]).capitalize()
