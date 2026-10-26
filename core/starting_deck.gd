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

## A recipe with starter packs (#107, v0.63) is dealt in two steps instead: deal_offer draws the
## packs offered and today's shared products (with the fair-deal check on each pack's cart), then
## the player's pick makes the deck (with_pack). The shared products follow the copy rule with
## every offered pack counted (copies_for_offer), and a pack's own cards may go past copy_max.


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
	var chains: Array[ItemUpgradeDefinition] = _chains(recipe, balance)
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
## data's chains or coupon pool change. A recipe with starter packs (#107) dealt the core cards,
## then `pack`'s cards (none before the pick: `pack` null), then no more than random_count
## products, no card past copy_max unless its core and pack copies already are.
static func could_deal(
	recipe: DeckDefinition, cards: Array[CardDefinition], pack: StarterPackDefinition = null
) -> bool:
	var core_size: int = recipe.core_cards.size()
	if cards.size() < core_size or cards.slice(0, core_size) != recipe.core_cards:
		return false
	if not recipe.starter_packs.is_empty():
		var pack_cards: Array[CardDefinition] = []
		if pack != null:
			pack_cards = pack.cards
		if pack != null and not recipe.starter_packs.has(pack):
			return false
		var rest: Array[CardDefinition] = cards.slice(core_size)
		if rest.slice(0, pack_cards.size()) != pack_cards:
			return false
		var shared: Array[CardDefinition] = rest.slice(pack_cards.size())
		return (
			shared.size() <= recipe.random_count
			and shared.all(func(card: CardDefinition) -> bool: return card.is_product())
			and fits_copies(recipe, pack_cards, shared)
		)
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


## Deals a starter pack offer for `recipe` (#107, v0.63) on `rng` (the run's starting-deck
## stream): `first_pick` (a profile that has never won) puts the recipe's first_pick_pack in the
## offer, in its middle place. The other packs are drawn one randi_range each from the recipe's
## packs, then the shared products as a recipe deals its products (copies_for_offer). The
## fair-deal check (the recipe's fair_deal_* fields) runs on each pack's cart (core + pack +
## shared): a pack whose cart fails is swapped for the first unoffered pack (recipe order) whose
## cart passes with the same shared products and fits the copy rule; the first pick is never
## swapped. If a pack still fails, the shared products are dealt again (up to fair_deal_redeals
## times, from the packs first drawn) and the deal with the most passing carts is kept. The same
## recipe, stock, flag and stream state give the same offer.
static func deal_offer(
	recipe: DeckDefinition,
	stock: RunStock,
	balance: BalanceDefinition,
	rng: RandomNumberGenerator,
	first_pick: bool,
	quota: int = -1
) -> StartOffer:
	var offer: StartOffer = StartOffer.new()
	var forced: StarterPackDefinition = null
	if first_pick and recipe.starter_packs.has(recipe.first_pick_pack):
		forced = recipe.first_pick_pack
	var drawn: Array[StarterPackDefinition] = []
	var left: Array[StarterPackDefinition] = recipe.starter_packs.duplicate()
	left.erase(forced)
	var count: int = mini(recipe.packs_offered, recipe.starter_packs.size())
	while drawn.size() < count - (1 if forced != null else 0) and not left.is_empty():
		var pick: StarterPackDefinition = left[rng.randi_range(0, left.size() - 1)]
		drawn.append(pick)
		left.erase(pick)
	if forced != null:
		drawn.insert(mini(drawn.size(), floori(count / 2.0)), forced)
	offer.first_pick = forced
	var products: Array[CardDefinition] = drawable(stock, _chains(recipe, balance))
	var upgrades: Array[UpgradeDefinition] = []
	if recipe.starting_upgrade != null:
		upgrades.append(recipe.starting_upgrade)
	var limits: ShiftLimits = ShiftLimits.for_shift(balance, upgrades, 0)
	var target: int = quota if quota >= 0 else limits.quota
	var climber: RowClimb = RowClimb.new(upgrades)
	var best_passing: int = -1
	for deal_index: int in range(maxi(recipe.fair_deal_redeals, 0) + 1):
		var copies: Dictionary[CardDefinition, int] = copies_for_offer(recipe, drawn)
		var shared: Array[CardDefinition] = _draw(
			products, recipe.random_count, recipe.copy_max, copies, rng
		)
		var packs: Array[StarterPackDefinition] = drawn.duplicate()
		var swaps: int = 0
		var passing: int = 0
		if recipe.fair_deal_hands > 0:
			for index: int in range(packs.size()):
				if _cart_passes(
					recipe, packs[index], shared, balance, limits, target, climber, rng
				):
					passing += 1
					continue
				if packs[index] == forced:
					continue
				for candidate: StarterPackDefinition in recipe.starter_packs:
					if packs.has(candidate) or not fits_copies(recipe, candidate.cards, shared):
						continue
					if _cart_passes(
						recipe, candidate, shared, balance, limits, target, climber, rng
					):
						packs[index] = candidate
						swaps += 1
						passing += 1
						break
		else:
			passing = packs.size()
		if passing > best_passing:
			best_passing = passing
			offer.packs = packs
			offer.shared = shared
			offer.swaps = swaps
		offer.deals = deal_index + 1
		if passing >= packs.size():
			break
	return offer


## The copies the shared products start from (#107): the core cards' copies, plus for each card
## the most copies any offered pack holds, so the shared products keep the copy rule whichever
## pack is taken.
static func copies_for_offer(
	recipe: DeckDefinition, packs: Array[StarterPackDefinition]
) -> Dictionary[CardDefinition, int]:
	var copies: Dictionary[CardDefinition, int] = {}
	for core: CardDefinition in recipe.core_cards:
		copies[core] = int(copies.get(core, 0)) + 1
	var most: Dictionary[CardDefinition, int] = {}
	for pack: StarterPackDefinition in packs:
		var held: Dictionary[CardDefinition, int] = {}
		for card: CardDefinition in pack.cards:
			held[card] = int(held.get(card, 0)) + 1
		for card: CardDefinition in held:
			most[card] = maxi(int(most.get(card, 0)), held[card])
	for card: CardDefinition in most:
		copies[card] = int(copies.get(card, 0)) + most[card]
	return copies


## Whether the core cards, `pack_cards` and `shared` keep the copy rule: no card past copy_max,
## unless its core and pack copies alone already are (the Banana bunch) and the shared products
## add none.
static func fits_copies(
	recipe: DeckDefinition, pack_cards: Array[CardDefinition], shared: Array[CardDefinition]
) -> bool:
	var fixed: Dictionary[CardDefinition, int] = {}
	for card: CardDefinition in recipe.core_cards + pack_cards:
		fixed[card] = int(fixed.get(card, 0)) + 1
	var total: Dictionary[CardDefinition, int] = fixed.duplicate()
	for card: CardDefinition in shared:
		total[card] = int(total.get(card, 0)) + 1
	for card: CardDefinition in total:
		if total[card] > maxi(recipe.copy_max, int(fixed.get(card, 0))):
			return false
	return true


## The deck before the pick (#107): `recipe` holding its core cards and the offer's shared
## products, with no pack. A run waiting for its pick (RunState.Phase.CHOOSE_START) holds it.
static func before_pick(recipe: DeckDefinition, offer: StartOffer) -> DeckDefinition:
	var dealt: DeckDefinition = with_cards(recipe, recipe.core_cards + offer.shared)
	dealt.starter_pack = null
	return dealt


## The deck after the pick (#107): `recipe`'s core cards, `pack`'s cards, then `shared`.
static func with_pack(
	recipe: DeckDefinition, pack: StarterPackDefinition, shared: Array[CardDefinition]
) -> DeckDefinition:
	var dealt: DeckDefinition = with_cards(recipe, recipe.core_cards + pack.cards + shared)
	dealt.starter_pack = pack
	return dealt


## The shared products of a deck dealt with packs (#107): its cards after the core cards and the
## pack's.
static func shared_of(deck: DeckDefinition) -> Array[CardDefinition]:
	var skip: int = deck.core_cards.size()
	if deck.starter_pack != null:
		skip += deck.starter_pack.cards.size()
	return deck.cards.slice(skip)


## Whether `pack`'s cart (the core cards, its cards, `shared`) passes the fair-deal check.
static func _cart_passes(
	recipe: DeckDefinition,
	pack: StarterPackDefinition,
	shared: Array[CardDefinition],
	balance: BalanceDefinition,
	limits: ShiftLimits,
	target: int,
	climber: RowClimb,
	rng: RandomNumberGenerator
) -> bool:
	var cards: Array[CardDefinition] = recipe.core_cards + pack.cards + shared
	var passes: int = fair_passes(cards, recipe, balance.hand_size, limits, target, climber, rng)
	return passes >= recipe.fair_deal_passes


## The chains a recipe draws its products from (capsule products only with random_capsules).
static func _chains(
	recipe: DeckDefinition, balance: BalanceDefinition
) -> Array[ItemUpgradeDefinition]:
	var chains: Array[ItemUpgradeDefinition] = []
	if balance.machine != null:
		chains = balance.machine.item_upgrades
	if not recipe.random_capsules:
		chains = without_capsules(chains, balance)
	return chains


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
	dealt.starter_packs = recipe.starter_packs.duplicate()
	dealt.packs_offered = recipe.packs_offered
	dealt.first_pick_pack = recipe.first_pick_pack
	dealt.starter_pack = recipe.starter_pack
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
