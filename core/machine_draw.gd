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
## the rest either), uniform among the candidates: never a prize twice, and loyalty perks never
## repeat a type. A rarity with no candidate of the drop's kind steps down to the floor, then up,
## then below the floor (the empty-tier fallback); a kind with no candidate at any rarity takes any
## kind the same way; none at all ends the draw short. Then the guarantee swap: if no drop is in
## the chute's guarantee set, the last drop whose rarity pool holds a member of its own kind not
## drawn yet (for a loyalty perk, of a type the other drops don't have) is swapped for one,
## uniform; if none, the guarantee is skipped. NEW ITEMS then holds the run's newest new arrival
## on its first draw, and finally each product with an upgrade chain rolls its tier (plain, BIG,
## GOLDEN; roll_tiers) from the odds level's tier weights, keeping its plain card's rarity.

## Any kind of prize (a drop with no kind of its own).
const ANY_KIND := -1
const RARITIES: Array[int] = [
	MachinePrize.Rarity.COMMON, MachinePrize.Rarity.RARE, MachinePrize.Rarity.LEGENDARY
]


## The chute's prizes as 3 lists (COMMON, RARE, LEGENDARY), each an Array[MachinePrize] in data
## order. NEW ITEMS: the stocked products, then the coupon candidates
## (MachineContext.coupon_candidates); UPGRADE: the pool's perks whose family isn't owned (none
## once the card is full), then each owned perk's next level at its family's rarity, then each
## chain's product with a copy in the deck, per rarity it can offer as an item upgrade.
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


## The ids a draw must hold one of (empty: no guarantee). NEW ITEMS: the stocked generally useful
## products, preferring in each rarity tier those the deck doesn't hold yet (v0.49; no copy of the
## same product, a tier counting as its plain card): a tier's members are its useful products not
## in the deck, or all its useful products when the deck holds every one, so a tier that could
## swap one in before still can; UPGRADE: the new perks (never a level-up) that fit the deck.
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


## The guarantee swap's alternatives for a finished draw, equally likely: the draw itself when
## it holds a member of `held_ids` (or there is no guarantee, or no drop can swap), else the draw
## with its last swappable drop replaced by each member of that drop's rarity and kind not drawn
## yet.
static func swaps(chute_pools: Array, drawn: Array[MachinePrize], held_ids: Dictionary) -> Array:
	if held_ids.is_empty() or holds(drawn, held_ids):
		return [drawn]
	for index: int in range(drawn.size() - 1, -1, -1):
		var alternatives: Array = []
		var pool: Array[MachinePrize] = chute_pools[drawn[index].rarity]
		for prize: MachinePrize in pool:
			if prize.kind != drawn[index].kind or not held_ids.has(prize.id()):
				continue
			if _has_key(drawn, prize) or _type_taken(drawn, prize, index):
				continue
			var swapped: Array[MachinePrize] = drawn.duplicate()
			swapped[index] = prize
			alternatives.append(swapped)
		if not alternatives.is_empty():
			return alternatives
	return [drawn]


## Whether a drop is in the guarantee set (a BIG or GOLDEN product counts as its plain card).
static func holds(drawn: Array[MachinePrize], held_ids: Dictionary) -> bool:
	return drawn.any(func(prize: MachinePrize) -> bool: return held_ids.has(prize.plain_id()))


## The first NEW ITEMS draw's new-arrival hold (build spec 1.5, Q4): when the context holds a new
## arrival not drawn yet, it replaces the last product drop that isn't the draw's only generally
## useful product, at its own rarity (a coupon drop is never replaced). Any other draw is returned
## as it is.
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
		if drawn[index].kind != MachinePrize.Kind.PRODUCT:
			continue
		if useful_count == 1 and useful.has(drawn[index].id()):
			continue
		var swapped: Array[MachinePrize] = drawn.duplicate()
		var rarity: int = context.machine.product_rarity(context.new_arrival)
		swapped[index] = MachinePrize.new(MachinePrize.Kind.PRODUCT, rarity, context.new_arrival)
		return swapped
	return drawn


## The tier roll (#108): each product drop with an upgrade chain rolls plain, BIG or GOLDEN from
## the odds level's tier weights (MachineOddsLevel.tier_weights, with a PREMIUM visit's tier
## floor) and becomes that tier's card at its plain card's rarity. The RNG is used once per
## product with a chain, never for others.
static func roll_tiers(
	context: MachineContext, level: int, drawn: Array[MachinePrize], rng: RandomNumberGenerator
) -> Array[MachinePrize]:
	var odds: MachineOddsLevel = context.machine.odds_level(level)
	if odds == null:
		return drawn
	var tier_weights: PackedInt32Array = odds.tier_weights(context.min_tier())
	var found: Array[MachinePrize] = drawn.duplicate()
	for index: int in found.size():
		var chain: ItemUpgradeDefinition = chain_of(context.machine, found[index])
		if chain == null:
			continue
		var tier: int = roll(tier_weights, rng)
		var card: CardDefinition = chain.tiers()[tier] if tier > 0 else null
		if card != null:
			found[index] = MachinePrize.new(MachinePrize.Kind.PRODUCT, found[index].rarity, card)
	return found


## A product prize's upgrade chain (its plain card's), or null for any other prize.
static func chain_of(machine: MachineDefinition, prize: MachinePrize) -> ItemUpgradeDefinition:
	if prize.kind != MachinePrize.Kind.PRODUCT:
		return null
	return ItemUpgrades.chain_for(machine.item_upgrades, prize.card)


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
		if found.is_empty():
			break
		drawn.append(found[rng.randi_range(0, found.size() - 1)])
	var alternatives: Array = swaps(chute_pools, drawn, context.guarantee(chute))
	var chosen: Array[MachinePrize] = alternatives[0]
	if alternatives.size() > 1:
		chosen = alternatives[rng.randi_range(0, alternatives.size() - 1)]
	if chute == RewardMachine.Chute.NEW_ITEMS:
		chosen = new_arrival_swap(context, chosen)
		chosen = roll_tiers(context, level, chosen, rng)
	return chosen


## A rarity (or a tier) rolled against integer weights, or -1 when they sum to 0 (no RNG used
## then).
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


## Whether the draw already holds this prize (the same key: kind, card or upgrade, rarity).
static func _has_key(drawn: Array[MachinePrize], prize: MachinePrize) -> bool:
	for other: MachinePrize in drawn:
		if other == prize:
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
