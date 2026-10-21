class_name ItemUpgrades
extends RefCounted
## Item upgrades (#77, the machine's UPGRADES chute): which copies of a product a prize steps up,
## and to which tier. Pure and static: callers pass the chains (`MachineDefinition.item_upgrades`)
## and the deck, and apply the result with Deck.upgrade. A prize's rarity sets its step:
## COMMON one step on the most advanced copy that can step, RARE a plain copy straight to
## GOLDEN, LEGENDARY (SHELF UPGRADE) one step on every copy below GOLDEN. Never adds a copy.

## The prize rarities, the values of MachinePrize.Rarity.
const COMMON := 0
const RARE := 1
const LEGENDARY := 2


## The chain whose plain, BIG or GOLDEN card is this very card, or null. A same-product card that
## isn't one of the chain's own (another variant) never joins it.
static func chain_for(
	table: Array[ItemUpgradeDefinition], card: CardDefinition
) -> ItemUpgradeDefinition:
	for chain: ItemUpgradeDefinition in table:
		if chain.holds(card):
			return chain
	return null


## The card `steps` tiers above this one in its chain, or null past GOLDEN or outside a chain.
static func tier_step(
	table: Array[ItemUpgradeDefinition], card: CardDefinition, steps: int
) -> CardDefinition:
	var chain: ItemUpgradeDefinition = chain_for(table, card)
	if chain == null or steps < 0:
		return null
	var tiers: Array[CardDefinition] = chain.tiers()
	var index: int = tiers.find(card) + steps
	return tiers[index] if index < tiers.size() else null


## How many tiers a prize of this rarity steps each target up.
static func step_count(rarity: int) -> int:
	return 2 if rarity == RARE else 1


## The deck copies a prize of this rarity upgrades, for the product's chain (its plain or BIG
## copies only), in deck order. COMMON: the one copy with the highest tier below GOLDEN (BIG
## before plain, ties to the lowest deck index); RARE: the first plain copy; LEGENDARY: every
## copy below GOLDEN. Empty when the prize can't be offered.
static func targets(
	table: Array[ItemUpgradeDefinition], deck: Deck, product: CardDefinition, rarity: int
) -> Array[CardInstance]:
	var found: Array[CardInstance] = []
	var chain: ItemUpgradeDefinition = chain_for(table, product)
	if chain == null:
		return found
	var steppable: Array[CardInstance] = []
	for card: CardInstance in deck.cards:
		if card.definition == chain.product or card.definition == chain.big:
			steppable.append(card)
	match rarity:
		COMMON:
			for card: CardInstance in steppable:
				if found.is_empty() or card.definition.tier > found[0].definition.tier:
					found = [card]
		RARE:
			for card: CardInstance in steppable:
				if card.definition == chain.product:
					found.append(card)
					break
		LEGENDARY:
			found = steppable
	return found


## Whether a prize of this rarity has something to upgrade: COMMON a copy below GOLDEN, RARE a
## plain copy, LEGENDARY (SHELF UPGRADE) at least `min_copies` copies below GOLDEN.
static func can_offer(
	table: Array[ItemUpgradeDefinition],
	min_copies: int,
	deck: Deck,
	product: CardDefinition,
	rarity: int
) -> bool:
	var found: int = targets(table, deck, product, rarity).size()
	return found >= maxi(min_copies, 1) if rarity == LEGENDARY else found > 0
