class_name CardFamilies
extends RefCounted
## The families a card's ticket is coloured by (#105, full build plan section 6.1): the family
## the card works with. A rule that names a family gives it (Milk's "+1 per earlier Breakfast"
## is Breakfast, Eggs' "×2 next Food" Food, the Breakfast sticker's grant Breakfast); a rule that
## names a product gives that product's main family (Cereal beside Milk is Dairy, Yogurt beside
## Banana Produce); a rule that pairs the card with itself gives its own main family (Banana).
## Rules that name no family (a penalty such as Soup's, slot rules, coupon counting, links,
## copies, 2 for 1, the shared multiplier, the connector) are skipped. A product whose rules name
## none is its own main family; a coupon whose rules name none is the plain coupon ([]). The
## first two distinct families are kept: two make a split ticket.
##
## A card's `ticket_families` overrides all of this when its rules don't say it right (Final
## markdown is Clearance). An item tier (BIG, GOLDEN) is coloured as its plain card.
##
## Presentation only: no rule reads it. The order that picks a card's main family and the
## families left off the glyph row are data (data/families/family_palette.tres), passed in.

## Why a ticket has its colour (colour_reason; its tooltip and the scan popup say it): its
## override, a family its rule works with, a family its rule gives (a tag grant), a product its
## rule names, another copy of itself, its own main family (a rule naming none), or nothing (the
## plain coupon).
enum Reason { NONE, OVERRIDE, FAMILY, GIVES, CARD, SAME, OWN }

## The most families a ticket shows (a split ticket).
const MAX_FAMILIES := 2


## A ticket's colour reason: the Reason and what it names (a family id for FAMILY and GIVES, the
## named product's display name for CARD and SAME, else "").
class Why:
	extends RefCounted

	var reason: CardFamilies.Reason = CardFamilies.Reason.NONE
	var subject: String = ""

	func _init(why_reason: CardFamilies.Reason, why_subject: String = "") -> void:
		reason = why_reason
		subject = why_subject


## The families `definition`'s ticket is coloured by: its override, else its rules' families,
## else its own main family (a product) or none (a coupon: the plain coupon ticket).
## `main_order` ranks the families for main_family; `find_card` resolves a card id to its
## CardDefinition, or null (a rule naming an unknown card falls back to the owner's family).
static func ticket_families(
	definition: CardDefinition, main_order: PackedStringArray, find_card: Callable
) -> PackedStringArray:
	if not definition.ticket_families.is_empty():
		return _first(definition.ticket_families)
	var card: CardDefinition = definition.product_card()
	if not card.ticket_families.is_empty():
		return _first(card.ticket_families)
	var found: PackedStringArray = PackedStringArray()
	for rule: Rule in card.rules:
		var family: String = rule_family(rule, card, main_order, find_card)
		if not family.is_empty() and not found.has(family):
			found.append(family)
		if found.size() == MAX_FAMILIES:
			break
	if found.is_empty() and card.is_product():
		var own: String = main_family(card, main_order)
		if not own.is_empty():
			found.append(own)
	return found


## The family one rule works with, or "" when it names none (see the class comment).
static func rule_family(
	rule: Rule, owner: CardDefinition, main_order: PackedStringArray, find_card: Callable
) -> String:
	if rule is CountEarlierTagBonusRule:
		return (rule as CountEarlierTagBonusRule).tag
	if rule is GrantNextTagBonusRule:
		return (rule as GrantNextTagBonusRule).tag
	if rule is GrantChargedMultiplierRule:
		return (rule as GrantChargedMultiplierRule).tag
	if rule is GrantTagToNextSlotRule:
		return (rule as GrantTagToNextSlotRule).tag
	var adjacent: AdjacentMatchBonusRule = rule as AdjacentMatchBonusRule
	if adjacent == null:
		return ""
	match adjacent.match_by:
		AdjacentMatchBonusRule.Match.TAG:
			return adjacent.match_value
		AdjacentMatchBonusRule.Match.CARD_ID:
			var target: CardDefinition = null
			if find_card.is_valid():
				target = find_card.call(adjacent.match_value) as CardDefinition
			return main_family(target if target != null else owner, main_order)
		AdjacentMatchBonusRule.Match.SAME_CARD:
			return main_family(owner, main_order)
	return ""


## Why `definition`'s ticket has its (first) colour, as ticket_families decides it: its override,
## else its first rule that names a family, else its own family (a product) or none (a coupon).
## `main_order` and `find_card` as for ticket_families.
static func colour_reason(
	definition: CardDefinition, main_order: PackedStringArray, find_card: Callable
) -> Why:
	var card: CardDefinition = definition.product_card()
	if not definition.ticket_families.is_empty() or not card.ticket_families.is_empty():
		return Why.new(Reason.OVERRIDE)
	for rule: Rule in card.rules:
		if not rule_family(rule, card, main_order, find_card).is_empty():
			return rule_reason(rule, card, find_card)
	return Why.new(Reason.OWN if card.is_product() else Reason.NONE)


## Why one rule colours its owner's ticket (as rule_family): the family it works with or gives,
## the product it names (an unknown one: the owner's own family), itself, or NONE.
static func rule_reason(rule: Rule, owner: CardDefinition, find_card: Callable) -> Why:
	if rule is CountEarlierTagBonusRule:
		return Why.new(Reason.FAMILY, (rule as CountEarlierTagBonusRule).tag)
	if rule is GrantNextTagBonusRule:
		return Why.new(Reason.FAMILY, (rule as GrantNextTagBonusRule).tag)
	if rule is GrantChargedMultiplierRule:
		return Why.new(Reason.FAMILY, (rule as GrantChargedMultiplierRule).tag)
	if rule is GrantTagToNextSlotRule:
		return Why.new(Reason.GIVES, (rule as GrantTagToNextSlotRule).tag)
	var adjacent: AdjacentMatchBonusRule = rule as AdjacentMatchBonusRule
	if adjacent == null:
		return Why.new(Reason.NONE)
	match adjacent.match_by:
		AdjacentMatchBonusRule.Match.TAG:
			return Why.new(Reason.FAMILY, adjacent.match_value)
		AdjacentMatchBonusRule.Match.CARD_ID:
			var target: CardDefinition = null
			if find_card.is_valid():
				target = find_card.call(adjacent.match_value) as CardDefinition
			if target == null:
				return Why.new(Reason.OWN)
			return Why.new(Reason.CARD, target.product_card().display_name)
		AdjacentMatchBonusRule.Match.SAME_CARD:
			return Why.new(Reason.SAME, owner.display_name)
	return Why.new(Reason.NONE)


## The card's main family: the first family of `main_order` among its plain card's tags, or ""
## when it has none of them.
static func main_family(definition: CardDefinition, main_order: PackedStringArray) -> String:
	var tags: PackedStringArray = definition.product_card().tags
	for family: String in main_order:
		if tags.has(family):
			return family
	return ""


## The families a ticket's glyph row shows: the tags without the `quiet` ones (Food, which
## nearly every product has), or only the first tag when the quiet ones are all it has.
static func shelf_families(tags: PackedStringArray, quiet: PackedStringArray) -> PackedStringArray:
	var shown: PackedStringArray = PackedStringArray()
	for tag: String in tags:
		if not quiet.has(tag) and not shown.has(tag):
			shown.append(tag)
	if shown.is_empty() and not tags.is_empty():
		shown.append(tags[0])
	return shown


static func _first(families: PackedStringArray) -> PackedStringArray:
	return families.slice(0, MAX_FAMILIES)
