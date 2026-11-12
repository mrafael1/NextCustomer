class_name GrantTagToNextSlotRule
extends Rule
## Context pass: the product in the next slot gains a tag (Breakfast sticker). If that slot is
## a coupon or empty, or the product already has the tag, the sticker is wasted.
##
## With `choices` (v1.28, the Family sticker) the tag is not fixed: each copy gives the family the
## player picked for it on the belt (or its pack's preset, else the row's pre-fill; FamilySticker),
## one of `choices`. Its fizzle step names that family too (ScoreStep.tag), so the belt shows it.

@export var tag: String = ""
## The families a Family sticker may give (v1.28), in its picker's order; empty: the fixed `tag`.
@export var choices: PackedStringArray = PackedStringArray()


func modify_context(state: ScoreState, slot: int) -> void:
	var given: String = tag
	if not choices.is_empty():
		given = FamilySticker.family_for(state, slot, choices)
	if given.is_empty():
		return
	var next_slot: int = slot + 1
	var text: String = text_for(state.definition(slot))
	if not state.is_product(next_slot):
		state.add_waste(slot, text, "no item in the next slot")
	elif state.has_tag(next_slot, given):
		state.add_waste(slot, text, "already %s" % given)
	else:
		state.add_tag(next_slot, given, slot, text)
		return
	if not choices.is_empty() and state.explain:
		state.steps[-1].tag = given
