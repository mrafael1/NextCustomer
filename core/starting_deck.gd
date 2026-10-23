class_name StartingDeck
extends RefCounted
## Deals a recipe deck (DeckDefinition.is_recipe, full build plan 5.2, v0.49 and v0.51): the
## recipe's core cards (the staples every run starts with), then `random_coupon_count` coupons
## drawn from the run's coupon pool, then `random_count` products drawn from the run's stock, so
## each run starts a little differently. Pure: the caller passes the stream (a derived stream of
## the run seed, EventLogService.STARTING_DECK_STREAM, so the run's own RNG never moves), and the
## same recipe, stock, chains and stream state give the same deck. The coupons are drawn first on
## the stream, then the products.
##
## The drawable coupons are the stock's coupons (its coupon pool, RunStock), in stock order. The
## drawable products are the stock's products that have an item-tier chain (a chain's plain card
## in the balance's MachineDefinition.item_upgrades), so UPGRADES can grow every dealt card. A
## card never goes past the recipe's copy_max, its core copies included. Each draw picks one of
## the cards still below copy_max, equally likely (one randi_range per draw); a draw ends short
## when none is left. The dealt cards follow the core cards: the coupons, then the products, each
## in stock order.


## The dealt deck: a copy of `recipe` whose cards are its core cards plus the drawn coupons and
## products. A fixed deck (not a recipe) is returned as it is.
static func deal(
	recipe: DeckDefinition, stock: RunStock, balance: BalanceDefinition, rng: RandomNumberGenerator
) -> DeckDefinition:
	if not recipe.is_recipe():
		return recipe
	var chains: Array[ItemUpgradeDefinition] = []
	if balance.machine != null:
		chains = balance.machine.item_upgrades
	var copies: Dictionary[CardDefinition, int] = {}
	for core: CardDefinition in recipe.core_cards:
		copies[core] = int(copies.get(core, 0)) + 1
	var cards: Array[CardDefinition] = recipe.core_cards.duplicate()
	var coupons: Array[CardDefinition] = drawable_coupons(stock)
	cards.append_array(_draw(coupons, recipe.random_coupon_count, recipe.copy_max, copies, rng))
	var products: Array[CardDefinition] = drawable(stock, chains)
	cards.append_array(_draw(products, recipe.random_count, recipe.copy_max, copies, rng))
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


## The stock's coupons a recipe can draw (the run's coupon pool), in stock order.
static func drawable_coupons(stock: RunStock) -> Array[CardDefinition]:
	var found: Array[CardDefinition] = []
	for card: CardDefinition in stock.cards:
		if card.is_coupon():
			found.append(card)
	return found


## Whether `recipe` could have dealt `cards` (a run save's starting deck): its core cards first,
## then no more than random_coupon_count coupons, then no more than random_count products, no
## card past copy_max copies. It doesn't check the stock: a resumed run keeps its deal even if the
## data's chains or coupon pool change.
static func could_deal(recipe: DeckDefinition, cards: Array[CardDefinition]) -> bool:
	var core_size: int = recipe.core_cards.size()
	if cards.size() < core_size or cards.slice(0, core_size) != recipe.core_cards:
		return false
	var copies: Dictionary[CardDefinition, int] = {}
	for card: CardDefinition in cards:
		copies[card] = int(copies.get(card, 0)) + 1
		if copies[card] > recipe.copy_max:
			return false
	var coupons: int = 0
	var products: int = 0
	for card: CardDefinition in cards.slice(core_size):
		if card.is_product():
			products += 1
		elif card.is_coupon() and products == 0:
			coupons += 1
		else:
			# A coupon after a product.
			return false
	return coupons <= recipe.random_coupon_count and products <= recipe.random_count


## A dealt copy of `recipe` holding `cards` (a run save restores a dealt deck with it). The
## recipe itself is never changed.
static func with_cards(recipe: DeckDefinition, cards: Array[CardDefinition]) -> DeckDefinition:
	var dealt: DeckDefinition = DeckDefinition.new()
	dealt.id = recipe.id
	dealt.display_name = recipe.display_name
	dealt.description = recipe.description
	dealt.core_cards = recipe.core_cards.duplicate()
	dealt.random_count = recipe.random_count
	dealt.random_coupon_count = recipe.random_coupon_count
	dealt.copy_max = recipe.copy_max
	dealt.starting_upgrade = recipe.starting_upgrade
	dealt.unlock_condition = recipe.unlock_condition
	dealt.cards = cards.duplicate()
	return dealt


## The cards a dealt recipe drew (its picks, v0.51's cart reveal): its cards after the core
## cards, the coupons first. A fixed deck has none.
static func picks(deck: DeckDefinition) -> Array[CardDefinition]:
	if not deck.is_recipe():
		return []
	return deck.cards.slice(deck.core_cards.size())


## Draws up to `count` cards from `pool` (in pool order), none past `copy_max` copies counted in
## `copies` (updated), one randi_range per draw; ends short when no card is left.
static func _draw(
	pool: Array[CardDefinition],
	count: int,
	copy_max: int,
	copies: Dictionary[CardDefinition, int],
	rng: RandomNumberGenerator
) -> Array[CardDefinition]:
	var drawn: Dictionary[CardDefinition, int] = {}
	for _draw_index: int in count:
		var open: Array[CardDefinition] = []
		for option: CardDefinition in pool:
			if int(copies.get(option, 0)) < copy_max:
				open.append(option)
		if open.is_empty():
			break
		var card: CardDefinition = open[rng.randi_range(0, open.size() - 1)]
		copies[card] = int(copies.get(card, 0)) + 1
		drawn[card] = int(drawn.get(card, 0)) + 1
	var cards: Array[CardDefinition] = []
	for card: CardDefinition in pool:
		for _copy: int in int(drawn.get(card, 0)):
			cards.append(card)
	return cards
