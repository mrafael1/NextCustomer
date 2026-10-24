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
## in the balance's MachineDefinition.item_upgrades), so UPGRADES can grow every dealt card; a
## capsule product only when the recipe's random_capsules is on (v0.52, off in the game's). A
## card never goes past the recipe's copy_max, its core copies included. Each draw picks one of
## the cards still below copy_max, equally likely (one randi_range per draw); a draw ends short
## when none is left. The dealt cards follow the core cards: the coupons, then the products, each
## in stock order.


## How a recipe was dealt (`deal_counted`): the deck kept, how many deals were made (1 when the
## first passed the fair-deal check or there is no check), and the kept deal's passing hands (-1
## without a check).
class Dealt:
	extends RefCounted
	var deck: DeckDefinition
	var deals: int = 1
	var passes: int = -1


## The dealt deck: a copy of `recipe` whose cards are its core cards plus the drawn coupons and
## products, kept by the fair-deal check (`deal_counted`). A fixed deck (not a recipe) is returned
## as it is. `quota` is the check's target; -1: shift 1's quota from `balance` (ShiftLimits, the
## recipe's starting upgrade included).
static func deal(
	recipe: DeckDefinition,
	stock: RunStock,
	balance: BalanceDefinition,
	rng: RandomNumberGenerator,
	quota: int = -1
) -> DeckDefinition:
	return deal_counted(recipe, stock, balance, rng, quota).deck


## Deals `recipe` (see `deal`), then the fair-deal check (v0.54, the recipe's fair_deal_* fields):
## after each deal, up to fair_deal_hands hands of the balance's hand_size are sampled from it on
## the same stream (a partial Fisher-Yates each), and each is climbed by RowClimb (the sensible
## player, fair_deal_changes changes, shift 1's limits and starting upgrade, no inspection, no
## redraw). A deal is kept as soon as fair_deal_passes hands reach the quota; the sampling stops
## early once that can no longer happen. Otherwise the recipe is dealt again on the same stream,
## up to fair_deal_redeals more times, and the deal with the most passing hands (the first on a
## tie) is kept. Everything is drawn on `rng`, so the same stream state gives the same deck.
static func deal_counted(
	recipe: DeckDefinition,
	stock: RunStock,
	balance: BalanceDefinition,
	rng: RandomNumberGenerator,
	quota: int = -1
) -> Dealt:
	var result: Dealt = Dealt.new()
	if not recipe.is_recipe():
		result.deck = recipe
		return result
	result.deck = _deal_once(recipe, stock, balance, rng)
	if recipe.fair_deal_hands <= 0:
		return result
	var upgrades: Array[UpgradeDefinition] = []
	if recipe.starting_upgrade != null:
		upgrades.append(recipe.starting_upgrade)
	var limits: ShiftLimits = ShiftLimits.for_shift(balance, upgrades, 0)
	var target: int = quota if quota >= 0 else limits.quota
	var climber: RowClimb = RowClimb.new(upgrades)
	var dealt: DeckDefinition = result.deck
	for deal_index: int in range(recipe.fair_deal_redeals + 1):
		if deal_index > 0:
			dealt = _deal_once(recipe, stock, balance, rng)
		var passes: int = fair_passes(
			dealt.cards, recipe, balance.hand_size, limits, target, climber, rng
		)
		if passes > result.passes:
			result.deck = dealt
			result.passes = passes
		result.deals = deal_index + 1
		if passes >= recipe.fair_deal_passes:
			result.deck = dealt
			result.passes = passes
			break
	return result


## How many of up to `recipe.fair_deal_hands` hands of `hand_size` sampled from `cards` on `rng`
## reach `target` with `climber` (fair_deal_changes changes under `limits`). It stops sampling once
## fair_deal_passes hands passed or can no longer pass, so the count is exact only below that.
static func fair_passes(
	cards: Array[CardDefinition],
	recipe: DeckDefinition,
	hand_size: int,
	limits: ShiftLimits,
	target: int,
	climber: RowClimb,
	rng: RandomNumberGenerator
) -> int:
	var pile: Array[CardInstance] = []
	for card: CardDefinition in cards:
		pile.append(CardInstance.new(card, pile.size() + 1))
	var drawn: int = mini(hand_size, pile.size())
	var passes: int = 0
	for sample: int in range(recipe.fair_deal_hands):
		if passes >= recipe.fair_deal_passes:
			break
		if passes + recipe.fair_deal_hands - sample < recipe.fair_deal_passes:
			break
		# A partial Fisher-Yates: the hand is the pile's last `drawn` cards.
		for index: int in range(pile.size() - 1, pile.size() - 1 - drawn, -1):
			var other: int = rng.randi_range(0, index)
			var swap: CardInstance = pile[index]
			pile[index] = pile[other]
			pile[other] = swap
		var hand: Array[CardInstance] = pile.slice(pile.size() - drawn)
		if climber.climb_total(hand, limits, recipe.fair_deal_changes) >= target:
			passes += 1
	return passes


## One deal of `recipe`: its core cards, then the drawn coupons and products.
static func _deal_once(
	recipe: DeckDefinition, stock: RunStock, balance: BalanceDefinition, rng: RandomNumberGenerator
) -> DeckDefinition:
	var chains: Array[ItemUpgradeDefinition] = []
	if balance.machine != null:
		chains = balance.machine.item_upgrades
	if not recipe.random_capsules:
		chains = without_capsules(chains, balance)
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


## `chains` without the capsule products' (an aisle's capsule_cards, v0.52), in order: a recipe
## with random_capsules off draws only the fresh-stock products.
static func without_capsules(
	chains: Array[ItemUpgradeDefinition], balance: BalanceDefinition
) -> Array[ItemUpgradeDefinition]:
	var capsules: Array[CardDefinition] = []
	for aisle: AisleDefinition in balance.aisles:
		capsules.append_array(aisle.capsule_cards)
	var kept: Array[ItemUpgradeDefinition] = []
	for chain: ItemUpgradeDefinition in chains:
		if not capsules.has(chain.product):
			kept.append(chain)
	return kept


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
	dealt.random_capsules = recipe.random_capsules
	dealt.fair_deal_hands = recipe.fair_deal_hands
	dealt.fair_deal_passes = recipe.fair_deal_passes
	dealt.fair_deal_changes = recipe.fair_deal_changes
	dealt.fair_deal_redeals = recipe.fair_deal_redeals
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
