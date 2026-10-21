class_name ItemUpgradeDefinition
extends Resource
## One product's upgrade chain (#77): its plain card, then BIG, then GOLDEN. One file per
## product in data/item_upgrades/; the machine's UPGRADES chute can only upgrade the products
## listed this way. Both tiers are variants of the plain card (one level), so each counts as it.

@export var product: CardDefinition
@export var big: CardDefinition
@export var golden: CardDefinition


## The chain from plain to GOLDEN.
func tiers() -> Array[CardDefinition]:
	return [product, big, golden]


## Whether the card is one of this chain's own three cards (not just the same product).
func holds(card: CardDefinition) -> bool:
	return card != null and (card == product or card == big or card == golden)
