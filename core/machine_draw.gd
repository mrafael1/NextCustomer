class_name MachineDraw
extends RefCounted
## The RECEIPT REWARDS machine's one draw process (#77, build spec 1.5), a port of the approved
## draw77.js. Pure and static: the forward draw (draw, with the run's RNG) and the exact odds
## (MachineOdds, which never touches an RNG) share these steps.
##
## Per visit: each drop rolls a rarity from the odds level's weights (drop 1 may have a floor)
## and takes a prize of that rarity, uniform among the candidates: never a prize twice, and
## REGISTER never repeats a type. A rarity with no candidate steps down a tier, then up (the
## empty-tier fallback); none at all ends the draw short. Then the guarantee swap: if no drop is
## in the chute's guarantee set, the last drop whose rarity pool holds a member not drawn yet (for
## REGISTER, of a type the other drops don't have) is swapped for one, uniform; if none, the
## guarantee is skipped. Two extensions beyond draw77: REGISTER's guarantee is "one fits your
## cart", and the run's first NEW ITEMS draw holds the newest new arrival at its own rarity.

## Rarity order the empty-tier fallback tries, per rolled rarity: itself, down, then up.
const FALLBACK_ORDER: Array = [[0, 1, 2], [1, 0, 2], [2, 1, 0]]
const RARITIES: Array[int] = [
	MachinePrize.Rarity.COMMON, MachinePrize.Rarity.RARE, MachinePrize.Rarity.LEGENDARY
]


## The chute's prizes as 3 lists (COMMON, RARE, LEGENDARY), each an Array[MachinePrize] in data
## order. NEW ITEMS: the stocked products; COUPONS: the coupon pool; REGISTER: the upgrade pool
## minus owned; UPGRADES: each chain's product with a copy in the deck, per rarity it can offer.
static func pools(chute: int, context: MachineContext) -> Array:
	var common: Array[MachinePrize] = []
	var rare: Array[MachinePrize] = []
	var legendary: Array[MachinePrize] = []
	var found: Array = [common, rare, legendary]
	var machine: MachineDefinition = context.machine
	match chute:
		RewardMachine.Chute.NEW_ITEMS:
			for card: CardDefinition in context.products:
				var rarity: int = machine.product_rarity(card)
				_add(found, MachinePrize.new(MachinePrize.Kind.PRODUCT, rarity, card))
		RewardMachine.Chute.COUPONS:
			for card: CardDefinition in context.coupons:
				var rarity: int = machine.coupon_rarity(card)
				_add(found, MachinePrize.new(MachinePrize.Kind.COUPON, rarity, card))
		RewardMachine.Chute.REGISTER:
			for upgrade: UpgradeDefinition in context.upgrade_pool:
				if not context.owned.has(upgrade):
					var rarity: int = machine.upgrade_rarity(upgrade)
					_add(found, MachinePrize.new(MachinePrize.Kind.REGISTER, rarity, null, upgrade))
		RewardMachine.Chute.UPGRADES:
			_add_item_upgrades(found, context)
	return found


## The ids a draw must hold one of (empty: no guarantee). NEW ITEMS: the stocked generally useful
## products, preferring in each rarity tier those the deck doesn't hold yet (v0.49; no copy of the
## same product, a tier counting as its plain card): a tier's members are its useful products not
## in the deck, or all its useful products when the deck holds every one, so a tier that could
## swap one in before still can; COUPONS on the run's first COUPONS draw: the first-offer pool;
## REGISTER: the unowned upgrades that fit the deck; UPGRADES: none.
static func guarantee(chute: int, context: MachineContext) -> Dictionary:
	var found: Dictionary = {}
	match chute:
		RewardMachine.Chute.NEW_ITEMS:
			var deck_cards: Array[CardDefinition] = context.deck_cards()
			# Per rarity: [its useful products, those of them not in the deck].
			var tiers: Dictionary[int, Array] = {}
			for card: CardDefinition in context.products:
				if card.generally_useful:
					var rarity: int = context.machine.product_rarity(card)
					if not tiers.has(rarity):
						tiers[rarity] = [[], []]
					tiers[rarity][0].append(card)
					if not deck_cards.any(card.is_same_product):
						tiers[rarity][1].append(card)
			for rarity: int in tiers:
				var fresh: Array = tiers[rarity][1]
				for card: CardDefinition in fresh if not fresh.is_empty() else tiers[rarity][0]:
					found[card.id] = true
		RewardMachine.Chute.COUPONS:
			if context.first_coupons:
				for card: CardDefinition in context.first_offer_pool:
					if context.coupons.has(card):
						found[card.id] = true
		RewardMachine.Chute.REGISTER:
			var deck_cards: Array[CardDefinition] = context.deck_cards()
			for upgrade: UpgradeDefinition in context.upgrade_pool:
				if not context.owned.has(upgrade) and upgrade.fits(deck_cards):
					found[upgrade.id] = true
	return found


## The rarity weights drop `drop_index` rolls with at an odds level.
static func weights(machine: MachineDefinition, level: int, drop_index: int) -> PackedInt32Array:
	var odds: MachineOddsLevel = machine.odds_level(level)
	if odds == null:
		return PackedInt32Array([0, 0, 0])
	return odds.weights(drop_index)


## The rarity's prizes a drop can still take: not in the draw yet and, for REGISTER, of a type
## no drop has.
static func candidates(
	chute: int, chute_pools: Array, rarity: int, drawn: Array[MachinePrize]
) -> Array[MachinePrize]:
	var found: Array[MachinePrize] = []
	var pool: Array[MachinePrize] = chute_pools[rarity]
	for prize: MachinePrize in pool:
		if not _has_key(drawn, prize) and not _type_taken(chute, drawn, prize, -1):
			found.append(prize)
	return found


## The candidates of the rolled rarity, else of the rarities below, then above (the empty-tier
## fallback). Empty when there is none: the draw ends short.
static func land(
	chute: int, chute_pools: Array, rarity: int, drawn: Array[MachinePrize]
) -> Array[MachinePrize]:
	for tried: int in FALLBACK_ORDER[rarity]:
		var found: Array[MachinePrize] = candidates(chute, chute_pools, tried, drawn)
		if not found.is_empty():
			return found
	return []


## The guarantee swap's alternatives for a finished draw, equally likely: the draw itself when
## it holds a member of `held_ids` (or there is no guarantee, or no drop can swap), else the draw
## with its last swappable drop replaced by each member of that drop's rarity not drawn yet.
static func swaps(
	chute: int, chute_pools: Array, drawn: Array[MachinePrize], held_ids: Dictionary
) -> Array:
	if held_ids.is_empty() or holds(drawn, held_ids):
		return [drawn]
	for index: int in range(drawn.size() - 1, -1, -1):
		var alternatives: Array = []
		var pool: Array[MachinePrize] = chute_pools[drawn[index].rarity]
		for prize: MachinePrize in pool:
			if not held_ids.has(prize.id()) or _has_key(drawn, prize):
				continue
			if _type_taken(chute, drawn, prize, index):
				continue
			var swapped: Array[MachinePrize] = drawn.duplicate()
			swapped[index] = prize
			alternatives.append(swapped)
		if not alternatives.is_empty():
			return alternatives
	return [drawn]


## Whether a drop is in the guarantee set.
static func holds(drawn: Array[MachinePrize], held_ids: Dictionary) -> bool:
	return drawn.any(func(prize: MachinePrize) -> bool: return held_ids.has(prize.id()))


## The first NEW ITEMS draw's new-arrival hold (build spec 1.5, Q4): when the context holds a new
## arrival not drawn yet, it replaces the last drop that isn't the draw's only generally useful
## product, at its own rarity. Any other draw is returned as it is.
static func new_arrival_swap(
	context: MachineContext, drawn: Array[MachinePrize]
) -> Array[MachinePrize]:
	if not context.holds_new_arrival():
		return drawn
	if drawn.any(func(prize: MachinePrize) -> bool: return prize.card == context.new_arrival):
		return drawn
	var useful: Dictionary = context.guarantee(RewardMachine.Chute.NEW_ITEMS)
	var useful_count: int = (
		drawn.filter(func(prize: MachinePrize) -> bool: return useful.has(prize.id())).size()
	)
	for index: int in range(drawn.size() - 1, -1, -1):
		if useful_count == 1 and useful.has(drawn[index].id()):
			continue
		var swapped: Array[MachinePrize] = drawn.duplicate()
		var rarity: int = context.machine.product_rarity(context.new_arrival)
		swapped[index] = MachinePrize.new(MachinePrize.Kind.PRODUCT, rarity, context.new_arrival)
		return swapped
	return drawn


## The forward draw (draw77 simulate) with the run's RNG: drops in drop order, 0 to
## prizes_per_visit of them. A zero weight total or no candidate at all ends the draw short.
static func draw(
	chute: int, context: MachineContext, level: int, rng: RandomNumberGenerator
) -> Array[MachinePrize]:
	var chute_pools: Array = context.pools(chute)
	var drawn: Array[MachinePrize] = []
	for drop: int in range(context.machine.prizes_per_visit):
		var rolled: int = roll(weights(context.machine, level, drop), rng)
		if rolled == -1:
			break
		var found: Array[MachinePrize] = land(chute, chute_pools, rolled, drawn)
		if found.is_empty():
			break
		drawn.append(found[rng.randi_range(0, found.size() - 1)])
	var alternatives: Array = swaps(chute, chute_pools, drawn, context.guarantee(chute))
	var chosen: Array[MachinePrize] = alternatives[0]
	if alternatives.size() > 1:
		chosen = alternatives[rng.randi_range(0, alternatives.size() - 1)]
	if chute == RewardMachine.Chute.NEW_ITEMS:
		chosen = new_arrival_swap(context, chosen)
	return chosen


## A rarity rolled against integer weights, or -1 when they sum to 0 (no RNG used then).
static func roll(rarity_weights: PackedInt32Array, rng: RandomNumberGenerator) -> int:
	var total: int = 0
	for weight: int in rarity_weights:
		total += maxi(weight, 0)
	if total <= 0:
		return -1
	var left: int = rng.randi_range(0, total - 1)
	var rarity: int = 0
	while rarity < rarity_weights.size() - 1 and left >= maxi(rarity_weights[rarity], 0):
		left -= maxi(rarity_weights[rarity], 0)
		rarity += 1
	return rarity


static func _add(found: Array, prize: MachinePrize) -> void:
	var pool: Array[MachinePrize] = found[prize.rarity]
	pool.append(prize)


static func _add_item_upgrades(found: Array, context: MachineContext) -> void:
	var machine: MachineDefinition = context.machine
	for chain: ItemUpgradeDefinition in machine.item_upgrades:
		var in_deck: bool = context.deck.cards.any(
			func(card: CardInstance) -> bool: return chain.holds(card.definition)
		)
		if not in_deck:
			continue
		for rarity: int in RARITIES:
			if ItemUpgrades.can_offer(
				machine.item_upgrades, machine.shelf_min_copies, context.deck, chain.product, rarity
			):
				_add(found, MachinePrize.new(MachinePrize.Kind.UPGRADE, rarity, chain.product))


## Whether the draw already holds this prize (the same key: kind, card or upgrade, rarity).
static func _has_key(drawn: Array[MachinePrize], prize: MachinePrize) -> bool:
	for other: MachinePrize in drawn:
		if other == prize:
			return true
		var same_item: bool = other.card == prize.card and other.upgrade == prize.upgrade
		if same_item and other.kind == prize.kind and other.rarity == prize.rarity:
			return true
	return false


## REGISTER only: whether a drop other than `skip` already has the prize's upgrade type.
static func _type_taken(
	chute: int, drawn: Array[MachinePrize], prize: MachinePrize, skip: int
) -> bool:
	if chute != RewardMachine.Chute.REGISTER:
		return false
	for index: int in drawn.size():
		if index != skip and drawn[index].upgrade.type == prize.upgrade.type:
			return true
	return false
