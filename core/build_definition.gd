class_name BuildDefinition
extends Resource
## One build a deck can lean towards (full build plan sections 3 and 5.2), measured from the
## deck's cards, so a new card counts without authoring anything on it. Upgrades list the
## builds they push towards; the machine's REGISTER chute guarantees one prize that fits the deck
## (MachineDraw). Definitions are shared by reference and never changed at runtime.
##
## Every exported value defaults to a neutral value, because Godot doesn't write a value that
## equals the default into a .tres file. That is why `measure` starts at UNSET: every build file
## must state its measure, and a test rejects UNSET.

## TAG: cards printing `tag`, and copies of any of `cards` (Clearance collector lists Clearance
## tag, the coupon that gives the tag; plan v0.27). COUPONS: coupons. COPIES: copies of the
## deck's most repeated product (a variant counts as its base card). DISTINCT_TAGS: different
## tags among its products. CARDS: copies of any of `cards`.
enum Measure { UNSET, TAG, COUPONS, COPIES, DISTINCT_TAGS, CARDS }

@export var id: StringName = &""
@export var display_name: String = ""
@export var measure: Measure = Measure.UNSET
@export var tag: String = ""
@export var cards: Array[CardDefinition] = []
## The deck fits once its measure reaches this.
@export var min_count: int = 0
## A measure-only build (v1.28: Pair up, Snack lover, Household goods, Salvage) is measured by the
## balance simulator only: no upgrade lists it, it is never a run's main build and it is not one
## of the builds held to the viability gate (full build plan section 4).
@export var measure_only: bool = false
## The loyalty perks a measure-only build wants, by their LV 1 id (v1.28: Pair up's Perfect pair,
## Salvage's Salvage desk, Snack lover's Grab bag, Household goods' Home goods): the balance
## simulator's build player takes them as perks listing the build (its `build:<id>` strategy).
## Their tickets keep their family's "decks" line: the build lists them, not they the build. Ids,
## not files: an upgrade file already names its builds, and the two scripts must not name each
## other (Godot keeps such a pair loaded at exit).
@export var perk_ids: Array[StringName] = []


## Whether a perk's family (its LV 1 id: UpgradeDefinition.family()) is one of `perk_ids`.
func wants(perk_family: StringName) -> bool:
	return perk_ids.has(perk_family)


func fits(deck: Array[CardDefinition]) -> bool:
	return measure != Measure.UNSET and count(deck) >= min_count


## The deck's measure for this build.
func count(deck: Array[CardDefinition]) -> int:
	match measure:
		Measure.TAG:
			return deck.filter(_is_tagged_or_listed).size()
		Measure.COUPONS:
			return deck.filter(func(card: CardDefinition) -> bool: return card.is_coupon()).size()
		Measure.COPIES:
			return _most_copies(deck)
		Measure.DISTINCT_TAGS:
			return _distinct_tags(deck)
		Measure.CARDS:
			return deck.filter(_is_listed).size()
	return 0


func _is_tagged_or_listed(card: CardDefinition) -> bool:
	return card.tags.has(tag) or _is_listed(card)


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
