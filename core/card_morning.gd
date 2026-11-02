class_name CardMorning
extends RefCounted
## The MORNING (#128, Breakfast's identity, the user's call of 2026-11-02): the row's opening run
## of products with the tag (Breakfast), from its first product until one without it. Coupons
## neither join nor end it (the Breakfast sticker's tag counts, ScoreState.has_tag). Read after
## the context pass; it depends only on the row, so every rule sees the same morning.


## The MORNING products' slots, in row order (empty when the first product lacks `tag`).
static func slots(state: ScoreState, tag: String) -> PackedInt32Array:
	var found: PackedInt32Array = PackedInt32Array()
	if tag.is_empty():
		return found
	for slot: int in range(state.size()):
		if not state.is_product(slot):
			continue
		if not state.has_tag(slot, tag):
			break
		found.append(slot)
	return found
