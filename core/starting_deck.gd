class_name StartingDeck
extends RefCounted
## Deals a recipe deck (DeckDefinition.is_recipe, full build plan 5.2, v0.49): the recipe's core
## cards, then `random_count` products drawn from the run's stock, so each run starts a little
## differently with no pre-run screen. Pure: the caller passes the stream (a derived stream of
## the run seed, EventLogService.STARTING_DECK_STREAM, so the run's own RNG never moves), and the
## same recipe, stock, chains and stream state give the same deck.
##
## The drawable products are the stock's products that have an item-tier chain (a chain's plain
## card in the balance's MachineDefinition.item_upgrades), so UPGRADES can grow every dealt card. A
## product never goes past the recipe's copy_max, its core copies included. Each draw picks one of
## the products still below copy_max, equally likely (one randi_range per draw); the deal ends
## short when none is left. The dealt cards follow the core cards, in stock order.


## The dealt deck: a copy of `recipe` whose cards are its core cards plus the drawn products. A
## fixed deck (not a recipe) is returned as it is.
static func deal(
	recipe: DeckDefinition, stock: RunStock, balance: BalanceDefinition, rng: RandomNumberGenerator
) -> DeckDefinition:
	if not recipe.is_recipe():
		return recipe
	var chains: Array[ItemUpgradeDefinition] = []
	if balance.machine != null:
		chains = balance.machine.item_upgrades
	var pool: Array[CardDefinition] = drawable(stock, chains)
	var copies: Dictionary[CardDefinition, int] = {}
	for core: CardDefinition in recipe.core_cards:
		copies[core] = int(copies.get(core, 0)) + 1
	var drawn: Dictionary[CardDefinition, int] = {}
	for _draw: int in recipe.random_count:
		var open: Array[CardDefinition] = []
		for option: CardDefinition in pool:
			if int(copies.get(option, 0)) < recipe.copy_max:
				open.append(option)
		if open.is_empty():
			break
		var card: CardDefinition = open[rng.randi_range(0, open.size() - 1)]
		copies[card] = int(copies.get(card, 0)) + 1
		drawn[card] = int(drawn.get(card, 0)) + 1
	var cards: Array[CardDefinition] = recipe.core_cards.duplicate()
	for product: CardDefinition in pool:
		for _copy: int in int(drawn.get(product, 0)):
			cards.append(product)
	return with_cards(recipe, cards)


## The stock's products a recipe can draw: those with an item-tier chain, in stock order.
static func drawable(
	stock: RunStock, chains: Array[ItemUpgradeDefinition]
) -> Array[CardDefinition]:
	var found: Array[CardDefinition] = []
	for card: CardDefinition in stock.cards:
		if (
			card.is_product()
			and chains.any(func(chain: ItemUpgradeDefinition) -> bool: return chain.product == card)
		):
			found.append(card)
	return found


## A dealt copy of `recipe` holding `cards` (a run save restores a dealt deck with it). The
## recipe itself is never changed.
static func with_cards(recipe: DeckDefinition, cards: Array[CardDefinition]) -> DeckDefinition:
	var dealt: DeckDefinition = DeckDefinition.new()
	dealt.id = recipe.id
	dealt.display_name = recipe.display_name
	dealt.description = recipe.description
	dealt.core_cards = recipe.core_cards.duplicate()
	dealt.random_count = recipe.random_count
	dealt.copy_max = recipe.copy_max
	dealt.starting_upgrade = recipe.starting_upgrade
	dealt.unlock_condition = recipe.unlock_condition
	dealt.cards = cards.duplicate()
	return dealt
