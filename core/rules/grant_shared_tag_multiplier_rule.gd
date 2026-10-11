class_name GrantSharedTagMultiplierRule
extends Rule
## After scanning, multiplies every later product that shares a tag with the product in the
## slot just before this card, using tags after the context pass (Multipack: ×2). Tags in
## ignored_tags never count (Multipack ignores Food and Breakfast, decided with the user in
## #42). In slot 1, after a coupon, or after a product with only ignored tags, it does nothing.
## Several of these stack.

@export var factor: int = 1
@export var ignored_tags: PackedStringArray = PackedStringArray()


func on_scanned(state: ScoreState, slot: int) -> void:
	var before: int = slot - 1
	if factor == 1 or not state.is_product(before):
		return
	var shared: PackedStringArray = _shared_tags(state, before)
	if shared.is_empty() and not ignored_tags.is_empty():
		return
	var card: CardDefinition = state.definition(slot)
	state.add_effect(SharedTagMultiplierEffect.new(slot, text_for(card), shared, factor))


func wasted_reason(state: ScoreState, slot: int) -> String:
	if factor == 1:
		return ""
	if not state.is_product(slot - 1):
		return "no product just before it"
	if not ignored_tags.is_empty() and _shared_tags(state, slot - 1).is_empty():
		return "the product just before it has no tag but %s" % " or ".join(ignored_tags)
	return ""


## The tags of the product in `before` that count, after the context pass.
func _shared_tags(state: ScoreState, before: int) -> PackedStringArray:
	var shared: PackedStringArray = PackedStringArray()
	for tag: String in state.tags[before]:
		if not ignored_tags.has(tag):
			shared.append(tag)
	return shared
