class_name CardDefinition
extends Resource
## One card as designed. Definitions are shared by reference and never changed at runtime:
## per-run state lives in CardInstance, per-score state in ScoreState.
##
## Every exported value defaults to a neutral value, because Godot doesn't write a value that
## equals the default into a .tres file. That is why `kind` starts at UNSET: every card file
## must state its kind, and a test rejects UNSET.

enum Kind { UNSET, PRODUCT, COUPON }
## An item tier (#77): an upgraded copy of a product is a variant of its plain card (BIG, then
## GOLDEN), so it counts as that card everywhere ("same product"). PLAIN is every other card.
enum Tier { PLAIN, BIG, GOLDEN }

@export var id: StringName = &""
@export var display_name: String = ""
@export var kind: Kind = Kind.UNSET
## Marks coupons that bridge adjacency instead of breaking it (Bundle).
@export var is_connector: bool = false
@export var tags: PackedStringArray = PackedStringArray()
@export var base: int = 0
@export var rules: Array[Rule] = []
## Rule text shown on the placeholder card.
@export_multiline var rule_text: String = ""
## The price sticker's summary template (#75): at most 2 short lines, digit-free, its numbers and
## names written as keys the card's data fills in, e.g. "+{bonus} beside {match_value}". Empty
## for a card with no rule (the sticker shows only the price) and for a variant that keeps its
## base card's. The keys are CardText.STICKER_KEYS; sticker_summary() formats it.
@export var sticker_text: String = ""
## Reward offers include at least one card with this flag (plan section 5).
@export var generally_useful: bool = false
@export var art_ref: String = ""
## The giver-badge mini (sticker minis, art/minis/): the hand-drawn 7x7 product a planning sticker's
## badge shows for this product, and its GOLDEN copy with the gold outline. Set on the plain card
## only; a BIG or GOLDEN tier leaves them empty and uses its plain card's (badge_mini_ref).
## Empty for a product with no sprite yet (its badge keeps the initials) and for a coupon.
@export var mini_art_ref: String = ""
@export var mini_golden_art_ref: String = ""
## A card variant (full build plan section 7.3): the card it is a variant of, e.g. Organic
## Banana of Banana. None for a card that is not a variant.
@export var variant_of: CardDefinition
## What unlocks this variant; none means it is available from the start.
@export var unlock_condition: UnlockCondition
## The item tier (#77). A BIG or GOLDEN card is a variant of its plain card, listed in an
## ItemUpgradeDefinition chain; tiers are run upgrades from the machine, never stocked or
## unlocked.
@export var tier: Tier = Tier.PLAIN


func is_product() -> bool:
	return kind == Kind.PRODUCT


func is_coupon() -> bool:
	return kind == Kind.COUPON


## The product this card counts as for "same product" (plan section 3): a variant counts as
## its base card, everywhere (2 for 1, duplicates, and rules that name a card).
func product_card() -> CardDefinition:
	return variant_of if variant_of != null else self


## The giver-badge mini this card shows: its plain card's mini_golden_art_ref for a GOLDEN card,
## else its plain card's mini_art_ref (a BIG card looks like the plain one). Empty when none.
func badge_mini_ref() -> String:
	var plain: CardDefinition = product_card()
	if tier == Tier.GOLDEN:
		return plain.mini_golden_art_ref
	return plain.mini_art_ref


func is_same_product(other: CardDefinition) -> bool:
	return other != null and product_card().id == other.product_card().id


## The price sticker's summary: `sticker_text` (or a variant's base card's) with its numbers
## and names filled in from this card's data (CardText).
func sticker_summary() -> String:
	return CardText.sticker_summary(self)


## Why this card can't be a variant as data, or an empty list (checked by a data test): a
## variant is a variant of another card that is not itself a variant, of the same kind.
func variant_problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	if variant_of == null:
		return found
	if variant_of == self:
		found.append("variant_of is itself")
	elif variant_of.variant_of != null:
		found.append("variant_of is a variant")
	if variant_of.kind != kind:
		found.append("variant_of has a different kind")
	return found
