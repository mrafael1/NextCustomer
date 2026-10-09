class_name InspectionDefinition
extends Resource
## One inspection as designed (plan section 3.9): a visible restriction on one shift, announced
## on the previous shift's receipt. Inspections never go on the loyalty card. Definitions are
## shared by reference and never changed at runtime; the shift's inspections are a list in
## RunState.

@export var id: StringName = &""
@export var display_name: String = ""
## The announcement, printed in red under the previous shift's total and shown during the
## inspected shift, e.g. "The 3rd product pays €0".
@export_multiline var notice_text: String = ""
## Scoring rules, asked about every slot by the scoring loop (never attached to a card).
@export var rules: Array[InspectionRule] = []
## Shift modifiers (ShiftLimits), added to the run's: product slots and coupon-only slots, negative
## to close slots for this shift (Short belt: -1 product slot; Coupon slot closed: -1 coupon slot).
@export var extra_slots: int = 0
@export var extra_coupon_slots: int = 0
