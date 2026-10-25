class_name MachinePrize
extends RefCounted
## One prize the RECEIPT REWARDS machine drew (#77, build spec 1.5), with its rarity: from NEW
## ITEMS a product (PRODUCT, possibly a BIG or GOLDEN tier card since #108, at its plain card's
## rarity) or a coupon (COUPON); from UPGRADE a loyalty perk (REGISTER: a new perk, or a level-up
## of an owned one, #108) or an item upgrade (UPGRADE). An UPGRADE prize names the plain product;
## its rarity sets its step (ItemUpgrades: COMMON one step, RARE straight to GOLDEN, LEGENDARY
## SHELF UPGRADE). The kind names stay as saved and logged since #77 ("register" is the player's
## LOYALTY).

enum Kind { PRODUCT, COUPON, REGISTER, UPGRADE }
## The values ItemUpgrades.COMMON / RARE / LEGENDARY use too.
enum Rarity { COMMON, RARE, LEGENDARY }

## Kind names, as in the key and the save.
const KIND_NAMES: Array[String] = ["product", "coupon", "register", "upgrade"]

var kind: Kind = Kind.PRODUCT
var rarity: int = Rarity.COMMON
## The product (any tier) or coupon; for UPGRADE the plain product. Null for REGISTER.
var card: CardDefinition
## The loyalty perk, at its level (REGISTER only).
var upgrade: UpgradeDefinition


func _init(
	prize_kind: Kind,
	prize_rarity: int,
	prize_card: CardDefinition = null,
	prize_upgrade: UpgradeDefinition = null
) -> void:
	kind = prize_kind
	rarity = prize_rarity
	card = prize_card
	upgrade = prize_upgrade


## The card's or upgrade's id.
func id() -> StringName:
	if kind == Kind.REGISTER:
		return upgrade.id if upgrade != null else &""
	return card.id if card != null else &""


## The id the guarantee reads: a BIG or GOLDEN product's plain card's id, else id().
func plain_id() -> StringName:
	if kind == Kind.PRODUCT and card != null and card.tier != CardDefinition.Tier.PLAIN:
		if card.variant_of != null:
			return card.variant_of.id
	return id()


## "kind:id:rarity", the same key as the approved draw (draw77 pkey). A prize is never drawn
## twice in one visit by this key.
func key() -> String:
	return "%s:%s:%d" % [KIND_NAMES[kind], id(), rarity]


## Whether picking it adds a card to the cart (a product or a coupon).
func adds_card() -> bool:
	return kind == Kind.PRODUCT or kind == Kind.COUPON


## The saved and logged form. A loyalty perk adds its level (#108; read back from its id).
func to_dictionary() -> Dictionary:
	var data: Dictionary = {"kind": KIND_NAMES[kind], "id": String(id()), "rarity": rarity}
	if kind == Kind.REGISTER and upgrade != null:
		data["level"] = upgrade.level_number()
	return data


## Reads to_dictionary's form (as parsed from JSON), resolving the id through `lookup`. Null when
## a field is missing or wrong, or the id doesn't resolve to the kind's content.
static func from_dictionary(data: Dictionary, lookup: ContentLookup) -> MachinePrize:
	var reader: SaveReader = SaveReader.new(data, lookup)
	var kind_index: int = KIND_NAMES.find(reader.text("kind"))
	var prize_rarity: int = reader.whole("rarity")
	var prize_id: String = reader.text("id")
	if not reader.ok or kind_index == -1 or prize_rarity > Rarity.LEGENDARY:
		return null
	if kind_index == Kind.REGISTER:
		var found: UpgradeDefinition = lookup.upgrade(prize_id)
		return (
			MachinePrize.new(kind_index as Kind, prize_rarity, null, found)
			if found != null
			else null
		)
	var found_card: CardDefinition = lookup.card(prize_id)
	if found_card == null or (kind_index == Kind.COUPON) != found_card.is_coupon():
		return null
	return MachinePrize.new(kind_index as Kind, prize_rarity, found_card)
