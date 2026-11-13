class_name MachineDraw
extends RefCounted
## The RECEIPT REWARDS machine's one draw process (#77, build spec 1.5), a port of the approved
## draw77.js extended for #108's two mixed chutes. Pure and static: the forward draw (draw, with
## the run's RNG) and the exact odds (MachineOdds, which never touches an RNG) share these steps.
##
## Per visit: each drop rolls a rarity from the odds level's weights (drop 1 may have a floor; a
## PREMIUM visit floors every drop) and takes a prize of that rarity and of the drop's kind
## (drop_kind: NEW ITEMS' last coupons_per_draw drops are coupons, the others products; UPGRADE's
## first loyalty_per_draw drops are loyalty perks, the next item_upgrades_per_draw item upgrades,
## the rest either), among the candidates by their draw weights (draw_weight: a product's hidden
## CardDefinition.draw_weight, 1 for any other prize; all 1 is uniform): never a prize twice (nor
## one product at two tiers), and loyalty perks never repeat a type. A rarity with no candidate of
## the drop's kind steps down to the floor, then up, then below the floor (the empty-tier
## fallback); a kind with no candidate at any rarity takes any kind the same way; none at all ends
## the draw short. Then the guarantee swap: if no drop is in the chute's guarantee set, the last
## drop whose rarity pool holds a member of its own kind not drawn yet (for a loyalty perk, of a
## type the other drops don't have) is swapped for one, by their draw weights; if none, the
## guarantee is skipped.
## A product's rarity is its tier (v1.25, decided with the user on 2026-11-08): NEW ITEMS' pools
## hold each stocked product at every tier it has (plain COMMON, BIG RARE, GOLDEN LEGENDARY), so
## the rarity a product drop rolls picks its tier, with no tier roll of its own.

## Any kind of prize (a drop with no kind of its own).
const ANY_KIND := -1
const RARITIES: Array[int] = [
	MachinePrize.Rarity.COMMON, MachinePrize.Rarity.RARE, MachinePrize.Rarity.LEGENDARY
]


## The chute's prizes as 3 lists (COMMON, RARE, LEGENDARY), each an Array[MachinePrize] in data
## order. NEW ITEMS: the stocked products with a draw weight above 0
## (MachineContext.drawn_products), each at every tier it has (product_tiers, a tier at its
## rarity), then the coupon candidates (MachineContext.coupon_candidates); UPGRADE: the pool's
## perks whose family isn't owned (none once the card is full), then each owned perk's next level
## at its family's rarity, then each chain's product with a copy in the deck, per rarity it can
## offer as an item upgrade.
static func pools(chute: int, context: MachineContext) -> Array:
	var common: Array[MachinePrize] = []
	var rare: Array[MachinePrize] = []
	var legendary: Array[MachinePrize] = []
	var found: Array = [common, rare, legendary]
	var machine: MachineDefinition = context.machine
	match chute:
		RewardMachine.Chute.NEW_ITEMS:
			for product: CardDefinition in context.drawn_products():
				for card: CardDefinition in product_tiers(machine, product):
					var rarity: int = MachineDefinition.product_rarity(card)
					_add(found, MachinePrize.new(MachinePrize.Kind.PRODUCT, rarity, card))
			for card: CardDefinition in context.coupon_candidates():
				var rarity: int = machine.coupon_rarity(card)
				_add(found, MachinePrize.new(MachinePrize.Kind.COUPON, rarity, card))
		RewardMachine.Chute.UPGRADE:
			for upgrade: UpgradeDefinition in _new_perks(context):
				var rarity: int = machine.upgrade_rarity(upgrade)
				_add(found, MachinePrize.new(MachinePrize.Kind.REGISTER, rarity, null, upgrade))
			for upgrade: UpgradeDefinition in PerkLevels.level_ups(context.owned):
				var rarity: int = machine.upgrade_rarity(upgrade)
				_add(found, MachinePrize.new(MachinePrize.Kind.REGISTER, rarity, null, upgrade))
			_add_item_upgrades(found, context)
	return found


## The ids a draw must hold one of (empty: no guarantee; a product's are its plain card's, and a
## BIG or GOLDEN drop counts as its plain card). NEW ITEMS: the stocked generally useful products
## it can draw (MachineContext.drawn_products) that the deck doesn't hold yet (v0.49; no copy of
## the same product, a tier counting as its plain card), or all of them when the deck holds every
## one (since v1.25 every product is COMMON plain, so the preference no longer splits by rarity);
## UPGRADE: the new perks (never a level-up) that fit the deck.
static func guarantee(chute: int, context: MachineContext) -> Dictionary:
	var found: Dictionary = {}
	match chute:
		RewardMachine.Chute.NEW_ITEMS:
			var deck_cards: Array[CardDefinition] = context.deck_cards()
			var useful: Array[CardDefinition] = []
			var fresh: Array[CardDefinition] = []
			for card: CardDefinition in context.drawn_products():
				if card.generally_useful:
					useful.append(card)
					if not deck_cards.any(card.is_same_product):
						fresh.append(card)
			for card: CardDefinition in fresh if not fresh.is_empty() else useful:
				found[card.id] = true
		RewardMachine.Chute.UPGRADE:
			var deck_cards: Array[CardDefinition] = context.deck_cards()
			for upgrade: UpgradeDefinition in _new_perks(context):
				if upgrade.fits(deck_cards, context.machine.families):
					found[upgrade.id] = true
	return found


## The kind of prize (MachinePrize.Kind) drop `drop` (0-based) of a chute's draw takes, or
## ANY_KIND. NEW ITEMS: the last coupons_per_draw drops are coupons, the others products; UPGRADE:
## the first loyalty_per_draw drops are loyalty perks, the next item_upgrades_per_draw item
## upgrades, the rest either.
static func drop_kind(chute: int, machine: MachineDefinition, drop: int) -> int:
	match chute:
		RewardMachine.Chute.NEW_ITEMS:
			if drop >= machine.prizes_per_visit - machine.coupons_per_draw:
				return MachinePrize.Kind.COUPON
			return MachinePrize.Kind.PRODUCT
		RewardMachine.Chute.UPGRADE:
			if drop < machine.loyalty_per_draw:
				return MachinePrize.Kind.REGISTER
			if drop < machine.loyalty_per_draw + machine.item_upgrades_per_draw:
				return MachinePrize.Kind.UPGRADE
	return ANY_KIND


## The rarity weights drop `drop_index` rolls with at an odds level, with the rarities below
## `min_rarity` (a PREMIUM visit's floor) zeroed.
static func weights(
	machine: MachineDefinition, level: int, drop_index: int, min_rarity: int = 0
) -> PackedInt32Array:
	var odds: MachineOddsLevel = machine.odds_level(level)
	if odds == null:
		return PackedInt32Array([0, 0, 0])
	return odds.weights(drop_index, min_rarity)


## The rarities the empty-tier fallback tries for a rolled rarity, in order: itself, down to
## `floor_rarity`, then up, then below the floor as a last resort. With floor 0: itself, down, up.
static func fallback_order(rolled: int, floor_rarity: int = 0) -> Array[int]:
	var found: Array[int] = [rolled]
	for rarity: int in range(rolled - 1, floor_rarity - 1, -1):
		found.append(rarity)
	for rarity: int in range(rolled + 1, RARITIES.size()):
		found.append(rarity)
	for rarity: int in range(mini(floor_rarity, rolled) - 1, -1, -1):
		found.append(rarity)
	return found


## The rarity's prizes a drop can still take: of `kind` (ANY_KIND: any), not in the draw yet and,
## for a loyalty perk, of a type no other loyalty drop has.
static func candidates(
	chute_pools: Array, rarity: int, drawn: Array[MachinePrize], kind: int = ANY_KIND
) -> Array[MachinePrize]:
	var found: Array[MachinePrize] = []
	var pool: Array[MachinePrize] = chute_pools[rarity]
	for prize: MachinePrize in pool:
		if kind != ANY_KIND and prize.kind != kind:
			continue
		if not _has_key(drawn, prize) and not _type_taken(drawn, prize, -1):
			found.append(prize)
	return found


## The candidates of the rolled rarity and the drop's kind, else of the rarities in
## fallback_order; a kind with none at any rarity falls back to any kind the same way. Empty when
## there is none: the draw ends short.
static func land(
	chute_pools: Array,
	rarity: int,
	drawn: Array[MachinePrize],
	kind: int = ANY_KIND,
	floor_rarity: int = 0
) -> Array[MachinePrize]:
	for tried: int in fallback_order(rarity, floor_rarity):
		var found: Array[MachinePrize] = candidates(chute_pools, tried, drawn, kind)
		if not found.is_empty():
			return found
	if kind != ANY_KIND:
		return land(chute_pools, rarity, drawn, ANY_KIND, floor_rarity)
	return []


## The guarantee swap's alternatives for a finished draw: the draw itself when it holds a member
## of `held_ids` (or there is no guarantee, or no drop can swap), else the draw with its last
## swappable drop replaced by each member of that drop's rarity and kind not drawn yet (a
## product: not in the draw at any tier). The draw picks one by the swapped-in prize's draw
## weight (swap_weights).
static func swaps(chute_pools: Array, drawn: Array[MachinePrize], held_ids: Dictionary) -> Array:
	if held_ids.is_empty() or holds(drawn, held_ids):
		return [drawn]
	for index: int in range(drawn.size() - 1, -1, -1):
		var alternatives: Array = []
		var pool: Array[MachinePrize] = chute_pools[drawn[index].rarity]
		for prize: MachinePrize in pool:
			if prize.kind != drawn[index].kind or not held_ids.has(prize.plain_id()):
				continue
			if _has_key(drawn, prize) or _type_taken(drawn, prize, index):
				continue
			var swapped: Array[MachinePrize] = drawn.duplicate()
			swapped[index] = prize
			alternatives.append(swapped)
		if not alternatives.is_empty():
			return alternatives
	return [drawn]


## The draw weight of each of swaps' alternatives against the finished draw it came from: the
## weight of the prize swapped in (1 for the draw itself).
static func swap_weights(alternatives: Array, drawn: Array[MachinePrize]) -> PackedInt32Array:
	var found: PackedInt32Array = PackedInt32Array()
	for alternative: Array[MachinePrize] in alternatives:
		var weight: int = 1
		for index: int in alternative.size():
			if alternative[index] != drawn[index]:
				weight = draw_weight(alternative[index])
		found.append(weight)
	return found


## Whether a drop is in the guarantee set (a BIG or GOLDEN product counts as its plain card).
static func holds(drawn: Array[MachinePrize], held_ids: Dictionary) -> bool:
	return drawn.any(func(prize: MachinePrize) -> bool: return held_ids.has(prize.plain_id()))


## A stocked plain product's cards NEW ITEMS can draw, plain first: each tier of its upgrade
## chain (plain, BIG, GOLDEN), or the plain card alone when it has no chain (always COMMON).
static func product_tiers(
	machine: MachineDefinition, product: CardDefinition
) -> Array[CardDefinition]:
	var found: Array[CardDefinition] = [product]
	var chain: ItemUpgradeDefinition = ItemUpgrades.chain_for(machine.item_upgrades, product)
	if chain == null:
		return found
	for card: CardDefinition in chain.tiers():
		if card != null and card != product:
			found.append(card)
	return found


## A prize's draw weight (v1.25): a product's plain card's hidden CardDefinition.draw_weight (a
## tier draws with its product's; below 0 counts as 0), 1 for any other prize.
static func draw_weight(prize: MachinePrize) -> int:
	if prize.kind != MachinePrize.Kind.PRODUCT or prize.card == null:
		return 1
	return maxi(prize.card.product_card().draw_weight, 0)


## One of `found` picked by the draw weights (all 1: uniform, the same RNG use as an index pick),
## or null when they sum to 0 (the draw ends short, as the exact odds do: MachineOdds).
static func pick(found: Array[MachinePrize], rng: RandomNumberGenerator) -> MachinePrize:
	var found_weights: PackedInt32Array = PackedInt32Array()
	for prize: MachinePrize in found:
		found_weights.append(draw_weight(prize))
	var index: int = roll(found_weights, rng)
	return found[index] if index != -1 else null


## The forward draw (draw77 simulate, #108's kinds) with the run's RNG: drops in drop order, 0 to
## prizes_per_visit of them. A zero weight total or no candidate at all ends the draw short.
static func draw(
	chute: int, context: MachineContext, level: int, rng: RandomNumberGenerator
) -> Array[MachinePrize]:
	var chute_pools: Array = context.pools(chute)
	var machine: MachineDefinition = context.machine
	var floor_rarity: int = context.min_rarity()
	var drawn: Array[MachinePrize] = []
	for drop: int in range(machine.prizes_per_visit):
		var rolled: int = roll(
			weights(machine, machine.rarity_level(chute, level), drop, floor_rarity), rng
		)
		if rolled == -1:
			break
		var kind: int = drop_kind(chute, machine, drop)
		var found: Array[MachinePrize] = land(chute_pools, rolled, drawn, kind, floor_rarity)
		var picked: MachinePrize = pick(found, rng) if not found.is_empty() else null
		if picked == null:
			break
		drawn.append(picked)
	var alternatives: Array = swaps(chute_pools, drawn, context.guarantee(chute))
	if alternatives.size() > 1:
		return alternatives[maxi(roll(swap_weights(alternatives, drawn), rng), 0)]
	return alternatives[0]


## An index (a rarity, or a candidate) rolled against integer weights, or -1 when they sum to 0
## (no RNG used then).
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


## The pool's perks the run can take as new ones: none once the card is full, else those whose
## family the run doesn't own and whose aisle family or product the stock or deck holds
## (MachineContext.stocks, #108).
static func _new_perks(context: MachineContext) -> Array[UpgradeDefinition]:
	var found: Array[UpgradeDefinition] = []
	if context.card_full:
		return found
	for upgrade: UpgradeDefinition in context.upgrade_pool:
		if PerkLevels.owned_index(context.owned, upgrade) == -1 and context.stocks(upgrade):
			found.append(upgrade)
	return found


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


## Whether the draw already holds this prize (the same key: kind, card or upgrade, rarity), or,
## for a product, the same product at any tier.
static func _has_key(drawn: Array[MachinePrize], prize: MachinePrize) -> bool:
	for other: MachinePrize in drawn:
		if other == prize:
			return true
		if prize.kind == MachinePrize.Kind.PRODUCT and other.kind == MachinePrize.Kind.PRODUCT:
			if other.card.is_same_product(prize.card):
				return true
		var same_item: bool = other.card == prize.card and other.upgrade == prize.upgrade
		if same_item and other.kind == prize.kind and other.rarity == prize.rarity:
			return true
	return false


## Loyalty perks only: whether a loyalty drop other than `skip` already has the prize's type.
static func _type_taken(drawn: Array[MachinePrize], prize: MachinePrize, skip: int) -> bool:
	if prize.kind != MachinePrize.Kind.REGISTER:
		return false
	for index: int in drawn.size():
		var other: MachinePrize = drawn[index]
		if index == skip or other.kind != MachinePrize.Kind.REGISTER:
			continue
		if other.upgrade.type == prize.upgrade.type:
			return true
	return false
