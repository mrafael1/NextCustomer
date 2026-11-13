class_name BookEntry
extends RefCounted
## One card of the FIGURINE BOOK (v1.30, BookOrder): an item (a product of the balance, starters
## included) in its main family (CardFamilies.main_family: the family its card shows), or a coupon
## (round 3) in the book's COUPON_FAMILY; whether the player owns it (a starter always; a capsule
## item once drawn; a coupon once played in a run that has ended, ProfileState.coupon_uses) and when
## it was collected (its place in the profile's draw order; 0 for a played coupon, as the save keeps
## no coupon play order; -1 for a starter or a card not collected yet). Round 4 (the user: "food
## filter should show every item that is food"): an item also keeps its printed tags (its plain
## card's tags, the ones the scoring reads; never a relabel's), and a family's tab (round 7: its
## FAMILY option) shows every card carrying that tag (has_family), not only the cards whose main
## family it is. Round 6 (the user: "if a family has less than 3 member it will go in other food"):
## the card's `group` is where the FAMILY sort files it under ALL, its main family unless
## BookOrder.regroup moved it (a Food-main card, or one whose main family is too small for an option
## of its own, to OTHER_FOOD); `other_food` is whether the OTHER FOOD option shows it. The card
## keeps its main family's look either way.
##
## Round 10 (v1.30, decided with the user 2026-11-12): a loyalty perk of the machine's live pool
## (balance.upgrade_pool) is a card too (for_perk), one per perk whatever its level, in the
## book's PERK_FAMILY: owned once picked in a run that has ended (ProfileState.perk_levels, the
## highest level reached, `level`, out of its chain's `levels`). A family perk (its boosts_tag)
## also shows under that family's option (`tags` holds it, for has_family only; scoring never
## reads a book entry). A perk is never Food and never OTHER FOOD.

## The coupons' family in the book (data/families/coupon.tres's id): their FAMILY option and their
## pages.
const COUPON_FAMILY := "Coupon"
## The broad Food family (data/families/food.tres's id): the FIGURINE BOOK's FOOD and NON-FOOD
## sorts (round 5) split the book by it.
const FOOD_TAG := "Food"
## The book's OTHER FOOD group and FAMILY option (round 6): no family's id, a name for the book
## only.
const OTHER_FOOD := "OtherFood"
## The book's PERKS group and FAMILY option (round 10): no family's id (a data/families file
## would turn the word into a glyph in sticker text), a name for the book only.
const PERK_FAMILY := "Perk"

## The item or coupon; null for a perk.
var card: CardDefinition
## The perk at LV 1 (round 10), or null for an item or coupon.
var perk: UpgradeDefinition
var family: String = ""
## Where the FAMILY sort files the card under ALL (round 6): its main family, OTHER_FOOD, or ""
## (the unfamilied last pages), set by BookOrder.regroup.
var group: String = ""
## Whether the OTHER FOOD option shows the card (round 6, BookOrder.regroup).
var other_food: bool = false
## The item's printed tags (its plain card's); empty for a coupon; a family perk's boosts_tag.
var tags: PackedStringArray = PackedStringArray()
var owned: bool = false
var starter: bool = false
var coupon: bool = false
## The item's place in ProfileState.unlocked_items' order (the draw order): higher is newer.
## A played coupon has 0 (coupon_uses keeps no order once saved).
var collected_at: int = -1
## A perk's highest level picked (0: not picked yet; at most `levels`) and its chain's level
## count (1 for a perk that never levels up).
var level: int = 0
var levels: int = 1


## `item` may be null only for a perk's card (for_perk).
func _init(
	item: CardDefinition, main_family: String, is_starter: bool, draw_index: int = -1
) -> void:
	card = item
	family = main_family
	group = main_family
	starter = is_starter
	if item == null:
		return
	coupon = item.is_coupon()
	collected_at = draw_index
	owned = is_starter or draw_index >= 0
	if not coupon:
		tags = item.product_card().tags.duplicate()


## The card of the loyalty perk `definition` (LV 1), picked up to level `picked` (0: never).
static func for_perk(definition: UpgradeDefinition, picked: int) -> BookEntry:
	var entry: BookEntry = BookEntry.new(null, PERK_FAMILY, false)
	entry.perk = definition
	entry.levels = PerkLevels.chain_length(definition)
	entry.level = clampi(picked, 0, entry.levels)
	entry.owned = entry.level > 0
	entry.collected_at = 0 if entry.owned else -1
	if not definition.boosts_tag.is_empty():
		entry.tags = PackedStringArray([definition.boosts_tag])
	return entry


func is_perk() -> bool:
	return perk != null


## The card's id, or the perk's.
func key() -> StringName:
	return perk.id if perk != null else card.id


## The card's or perk's name as players read it.
func display_name() -> String:
	return perk.display_name if perk != null else card.display_name


## Whether the card shows under the FAMILY pick `pick`: a coupon under COUPON_FAMILY only, an
## item under its main family and every family it carries as a printed tag, and under OTHER_FOOD
## when `other_food` (round 6); a perk under PERK_FAMILY and the family it boosts (round 10).
func has_family(pick: String) -> bool:
	if perk != null:
		return pick == PERK_FAMILY or (not pick.is_empty() and tags.has(pick))
	if coupon:
		return pick == COUPON_FAMILY
	if pick == OTHER_FOOD:
		return other_food
	return not pick.is_empty() and (pick == family or tags.has(pick))


## Whether the card is printed Food (FOOD_TAG); a coupon or a perk never is.
func is_food() -> bool:
	return not coupon and perk == null and tags.has(FOOD_TAG)
