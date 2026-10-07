class_name DeckSummary
extends RefCounted
## What the deck view shows about a list of cards (plan section 2, extended in full build
## phase 1): the cards grouped by kind, one group per distinct card with its copies, and how
## many copies carry each printed tag. Pure, so the view only displays it.


## One distinct card and its copies, in the order they appear in the list.
class Group:
	extends RefCounted
	var card: CardDefinition
	var copies: Array[CardInstance] = []

	func _init(definition: CardDefinition) -> void:
		card = definition


## One group per distinct card: products first, then coupons, each by name (then id).
static func groups(cards: Array[CardInstance]) -> Array[Group]:
	var by_card: Dictionary[CardDefinition, Group] = {}
	for instance: CardInstance in cards:
		if not by_card.has(instance.definition):
			by_card[instance.definition] = Group.new(instance.definition)
		by_card[instance.definition].copies.append(instance)
	var found: Array[Group] = []
	for card: CardDefinition in in_view_order(by_card.keys()):
		found.append(by_card[card])
	return found


## The cards in view order: products first, then coupons, each by name (then id).
static func in_view_order(cards: Array) -> Array[CardDefinition]:
	var sorted: Array[CardDefinition] = []
	sorted.assign(cards)
	sorted.sort_custom(_before)
	return sorted


## Copies carrying each printed tag (the card's own tags, before any context pass), most
## common first, ties by tag name.
static func tag_counts(cards: Array[CardInstance]) -> Dictionary[String, int]:
	var counts: Dictionary[String, int] = {}
	for instance: CardInstance in cards:
		for tag: String in instance.definition.tags:
			counts[tag] = counts.get(tag, 0) + 1
	var tags: Array[String] = []
	tags.assign(counts.keys())
	tags.sort_custom(
		func(a: String, b: String) -> bool:
			return counts[a] > counts[b] if counts[a] != counts[b] else a < b
	)
	var ordered: Dictionary[String, int] = {}
	for tag: String in tags:
		ordered[tag] = counts[tag]
	return ordered


static func _before(a: CardDefinition, b: CardDefinition) -> bool:
	if a.is_product() != b.is_product():
		return a.is_product()
	if a.display_name != b.display_name:
		return a.display_name < b.display_name
	return String(a.id) < String(b.id)
