class_name GrantTagToNextSlotRule
extends Rule
## Context pass: the product in the next slot gains a tag (Breakfast sticker). If that slot is
## a coupon or empty, or the product already has the tag, the sticker is wasted.

@export var tag: String = ""


func modify_context(state: ScoreState, slot: int) -> void:
	if tag.is_empty():
		return
	var next_slot: int = slot + 1
	var text: String = text_for(state.definition(slot))
	if not state.is_product(next_slot):
		state.add_waste(slot, text, "no product in the next slot")
	elif state.has_tag(next_slot, tag):
		state.add_waste(slot, text, "already %s" % tag)
	else:
		state.add_tag(next_slot, tag, slot, text)
