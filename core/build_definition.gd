class_name BuildDefinition
extends Resource
## One build a deck can lean towards (full build plan sections 3 and 5.2), measured from the
## deck's cards, so a new card counts without authoring anything on it. Upgrades list the
## builds they push towards; an upgrade offer guarantees one option that fits the deck
## (UpgradeOffer). Definitions are shared by reference and never changed at runtime.
##
## Every exported value defaults to a neutral value, because Godot doesn't write a value that
## equals the default into a .tres file. That is why `measure` starts at UNSET: every build file
## must state its measure, and a test rejects UNSET.

## TAG: cards printing `tag`. COUPONS: coupons. COPIES: copies of the deck's most repeated
## product (a variant counts as its base card). DISTINCT_TAGS: different tags among its
## products. CARDS: copies of any of `cards`.
enum Measure { UNSET, TAG, COUPONS, COPIES, DISTINCT_TAGS, CARDS }

@export var id: StringName = &""
@export var display_name: String = ""
@export var measure: Measure = Measure.UNSET
@export var tag: String = ""
@export var cards: Array[CardDefinition] = []
## The deck fits once its measure reaches this.
@export var min_count: int = 0


func fits(deck: Array[CardDefinition]) -> bool:
	return measure != Measure.UNSET and count(deck) >= min_count


## The deck's measure for this build.
func count(deck: Array[CardDefinition]) -> int:
	match measure:
		Measure.TAG:
			return deck.filter(func(card: CardDefinition) -> bool: return card.tags.has(tag)).size()
		Measure.COUPONS:
			return deck.filter(func(card: CardDefinition) -> bool: return card.is_coupon()).size()
		Measure.COPIES:
			return _most_copies(deck)
		Measure.DISTINCT_TAGS:
			return _distinct_tags(deck)
		Measure.CARDS:
			return deck.filter(_is_listed).size()
	return 0


func _is_listed(card: CardDefinition) -> bool:
	return cards.any(func(listed: CardDefinition) -> bool: return listed.is_same_product(card))


static func _most_copies(deck: Array[CardDefinition]) -> int:
	var copies: Dictionary[StringName, int] = {}
	var most: int = 0
	for card: CardDefinition in deck:
		if not card.is_product():
			continue
		var product: StringName = card.product_card().id
		copies[product] = copies.get(product, 0) + 1
		most = maxi(most, copies[product])
	return most


static func _distinct_tags(deck: Array[CardDefinition]) -> int:
	var tags: Dictionary[String, bool] = {}
	for card: CardDefinition in deck:
		if card.is_product():
			for card_tag: String in card.tags:
				tags[card_tag] = true
	return tags.size()
