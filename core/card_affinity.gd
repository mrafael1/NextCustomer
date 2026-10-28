class_name CardAffinity
extends RefCounted
## Which cards a card works with, read from its rules' own fields (#105 piece 3, the mix
## highlight, mock-up readability v3 section 4): a rule names another card when that card is what
## it counts, boosts, pairs with or is zeroed beside. A family rule (Milk's "+1 per earlier
## Breakfast", Coffee's "+3 to the next Breakfast", Eggs' "×2 next Food", Frozen peas' "+3 beside
## Frozen") names every product with that tag, but a broad family (Food, which nearly every product
## has: FamilyPalette.quiet_families, passed in) names it only WEAKly; a product rule (Cereal
## beside Milk) names that product, its tiers included; a pair rule (Banana) names its own product;
## a penalty (Soup's €0 beside Frozen) names the tag's products as a PENALTY; coupon counting
## (Scissors) names every coupon; a tag grant (Breakfast sticker, Clearance tag) names every card
## whose rule counts, boosts or pairs with the tag it grants (WEAKly for a broad one), and a card
## zeroed beside it as a PENALTY. The rules in NAMES_NONE name no other card (slot rules, links,
## copies, 2 for 1, the shared multiplier, the connector).
##
## Presentation only, like CardFamilies: no rule reads it and it never scores. Which pairs pay in
## the current order is the score's (EffectGraph), not this.

## How strongly one card names another, weakest first (a stronger one wins).
enum Match { NONE, WEAK, YES, PENALTY }

## The rule classes that name no other card (a guard test checks every rule in the data is either
## read here or listed).
const NAMES_NONE: Array[String] = [
	"TwoForOneRule",
	"ConnectorBridgeRule",
	"FirstProductLinkRule",
	"CopyPreviousPayoutRule",
	"FirstSlotMultiplierRule",
	"LastSlotBonusRule",
	"GrantSharedTagMultiplierRule",
]


## How strongly card `a` (its tags `a_tags`) and card `b` (`b_tags`) work together: the strongest
## of a's rules naming b and b's rules naming a. `broad` are the broad families (WEAK matches).
static func between(
	a: CardDefinition,
	a_tags: PackedStringArray,
	b: CardDefinition,
	b_tags: PackedStringArray,
	broad: PackedStringArray
) -> Match:
	var best: Match = Match.NONE
	for rule: Rule in a.rules:
		best = maxi(best, rule_names(rule, a, b, b_tags, broad)) as Match
	for rule: Rule in b.rules:
		best = maxi(best, rule_names(rule, b, a, a_tags, broad)) as Match
	return best


## How strongly `rule` (of `owner`) names `other` (its tags `tags`).
static func rule_names(
	rule: Rule,
	owner: CardDefinition,
	other: CardDefinition,
	tags: PackedStringArray,
	broad: PackedStringArray
) -> Match:
	if rule is CountEarlierCouponBonusRule:
		return Match.YES if other.is_coupon() else Match.NONE
	if rule is GrantTagToNextSlotRule:
		return uses_tag(other, (rule as GrantTagToNextSlotRule).tag, broad)
	if not other.is_product():
		return Match.NONE
	var found: Match = Match.NONE
	var adjacent: AdjacentMatchBonusRule = rule as AdjacentMatchBonusRule
	if adjacent != null:
		match adjacent.match_by:
			AdjacentMatchBonusRule.Match.TAG:
				found = _tag_match(adjacent.match_value, tags, broad)
			AdjacentMatchBonusRule.Match.CARD_ID:
				if String(other.product_card().id) == adjacent.match_value:
					found = Match.YES
			AdjacentMatchBonusRule.Match.SAME_CARD:
				if other.is_same_product(owner):
					found = Match.YES
	elif rule is ZeroPayoutBesideTagRule:
		if _tag_match((rule as ZeroPayoutBesideTagRule).tag, tags, broad) != Match.NONE:
			found = Match.PENALTY
	else:
		found = _tag_match(family_of(rule), tags, broad)
	return found


## The family a family rule counts or boosts (its `tag` field), or "" for any other rule.
static func family_of(rule: Rule) -> String:
	if rule is CountEarlierTagBonusRule:
		return (rule as CountEarlierTagBonusRule).tag
	if rule is GrantNextTagBonusRule:
		return (rule as GrantNextTagBonusRule).tag
	if rule is GrantChargedMultiplierRule:
		return (rule as GrantChargedMultiplierRule).tag
	return ""


## How strongly `card`'s rules use `tag` (a tag grant's: what the granted tag feeds): YES when one
## counts, boosts or pairs with it (WEAK for a broad family, `broad`), PENALTY when one zeroes
## `card` beside it, else NONE.
static func uses_tag(card: CardDefinition, tag: String, broad: PackedStringArray) -> Match:
	var best: Match = Match.NONE
	var tags: PackedStringArray = PackedStringArray([tag])
	for rule: Rule in card.rules:
		var found: Match = _tag_match(family_of(rule), tags, broad)
		var adjacent: AdjacentMatchBonusRule = rule as AdjacentMatchBonusRule
		if adjacent != null and adjacent.match_by == AdjacentMatchBonusRule.Match.TAG:
			found = _tag_match(adjacent.match_value, tags, broad)
		elif rule is ZeroPayoutBesideTagRule and (rule as ZeroPayoutBesideTagRule).tag == tag:
			found = Match.PENALTY
		best = maxi(best, found) as Match
	return best


## Whether this reads `rule`: it names cards here, or it is one of NAMES_NONE.
static func reads(rule: Rule) -> bool:
	if NAMES_NONE.has(String(rule.get_script().get_global_name())):
		return true
	return (
		rule is CountEarlierCouponBonusRule
		or rule is GrantTagToNextSlotRule
		or rule is AdjacentMatchBonusRule
		or rule is ZeroPayoutBesideTagRule
		or not family_of(rule).is_empty()
	)


## Whether a card with `tags` is in `family`.
static func in_family(tags: PackedStringArray, family: String) -> bool:
	return not family.is_empty() and tags.has(family)


## YES when `tags` has `tag` (WEAK for a broad family), else NONE.
static func _tag_match(tag: String, tags: PackedStringArray, broad: PackedStringArray) -> Match:
	if not in_family(tags, tag):
		return Match.NONE
	return Match.WEAK if broad.has(tag) else Match.YES
