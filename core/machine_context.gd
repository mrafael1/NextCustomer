class_name MachineContext
extends RefCounted
## A frozen snapshot of the run that one machine draw reads (#77, build spec 1.5): the stocked
## products, the coupon pool, the owned upgrades, the deck, the first coupon draw's flag and
## whether the visit is PREMIUM (#108). RewardMachine builds one from the run
## (from_run); tests build their own. The pools and guarantees are computed once per context and
## kept on it (never in a static cache), so drawing many times from one state reads them once.

var machine: MachineDefinition
var balance: BalanceDefinition
## The stocked products (plain only), in stock order.
var products: Array[CardDefinition] = []
## The coupons NEW ITEMS draws its coupon drops from.
var coupons: Array[CardDefinition] = []
## The perks UPGRADE draws new loyalty perks from (owned families are left out by the draw).
var upgrade_pool: Array[UpgradeDefinition] = []
## The run's owned upgrades.
var owned: Array[UpgradeDefinition] = []
## A copy of the run's deck list (same instances, own list).
var deck: Deck
## The run's first coupon draw (NEW ITEMS): its coupon drops draw from the first-offer pool only.
var first_coupons: bool = false
## The coupons the run's first coupon draw is restricted to (those also in `coupons`).
var first_offer_pool: Array[CardDefinition] = []
## A PREMIUM visit (#108): MachineDefinition.premium_min_rarity applies.
var premium: bool = false
## The loyalty card is full (register_cap new perks picked): UPGRADE offers only level-ups.
var card_full: bool = false
var _pools: Dictionary = {}
var _guarantees: Dictionary = {}


## The snapshot of a run for its machine. `coupons_first_done` is the machine's flag (the first
## coupon draw is the one before it is spent); `premium_visit`: the visit's.
static func from_run(
	run: RunState,
	machine_definition: MachineDefinition,
	coupons_first_done: bool,
	premium_visit: bool = false
) -> MachineContext:
	var context: MachineContext = MachineContext.new()
	context.machine = machine_definition
	context.balance = run.balance
	for card: CardDefinition in run.stock.cards:
		if card.is_product() and card.tier == CardDefinition.Tier.PLAIN:
			context.products.append(card)
	context.coupons = run.balance.coupon_pool.duplicate()
	context.upgrade_pool = run.balance.upgrade_pool.duplicate()
	context.first_offer_pool = run.balance.first_offer_pool.duplicate()
	context.owned = run.upgrades.duplicate()
	context.deck = Deck.new(null)
	context.deck.cards = run.deck.cards.duplicate()
	context.first_coupons = not coupons_first_done
	context.premium = premium_visit
	context.card_full = RewardMachine.registers_picked(run) >= machine_definition.register_cap
	return context


## The deck's cards as definitions (what a perk's "fits" reads); none without a deck.
func deck_cards() -> Array[CardDefinition]:
	var found: Array[CardDefinition] = []
	if deck == null:
		return found
	for card: CardInstance in deck.cards:
		found.append(card.definition)
	return found


## Whether the machine can offer `upgrade` as a new perk (#108): a family perk needs a stocked
## product or a deck card of its family, a jackpot its product in the stock or the deck.
func stocks(upgrade: UpgradeDefinition) -> bool:
	var cards: Array[CardDefinition] = products + deck_cards()
	if upgrade.needs_card != null:
		return cards.any(upgrade.needs_card.is_same_product)
	if not upgrade.boosts_tag.is_empty():
		return has_family(upgrade.boosts_tag, cards)
	return true


## Whether the machine can offer `coupon` (v1.29): one with a `needs_tag` (Party pack) needs a
## stocked product or a deck card of that family, as a family perk does (stocks).
func offers(coupon: CardDefinition) -> bool:
	if coupon.needs_tag.is_empty():
		return true
	return has_family(coupon.needs_tag, products + deck_cards())


## Whether one of `cards` is a product with `tag`.
static func has_family(tag: String, cards: Array[CardDefinition]) -> bool:
	return cards.any(
		func(card: CardDefinition) -> bool: return card.is_product() and card.tags.has(tag)
	)


## The stocked products NEW ITEMS can draw: those with a draw weight above 0 (v1.25,
## CardDefinition.draw_weight; a product at 0 never comes out of the machine), in stock order.
func drawn_products() -> Array[CardDefinition]:
	var found: Array[CardDefinition] = []
	for card: CardDefinition in products:
		if card.draw_weight > 0:
			found.append(card)
	return found


## The coupons NEW ITEMS' coupon drops draw from: on the run's first coupon draw only those in the
## first-offer pool (#36's first offer), else the coupon pool; either way only those the run can be
## offered (offers, v1.29: Party pack needs a Snack).
func coupon_candidates() -> Array[CardDefinition]:
	var found: Array[CardDefinition] = []
	for card: CardDefinition in first_offer_pool if first_coupons else coupons:
		if (not first_coupons or coupons.has(card)) and offers(card):
			found.append(card)
	return found


## The rarity floor of every drop (MachinePrize.Rarity): PREMIUM's, else 0.
func min_rarity() -> int:
	return machine.premium_min_rarity if premium else 0


## MachineDraw.pools for the chute, computed once.
func pools(chute: int) -> Array:
	if not _pools.has(chute):
		_pools[chute] = MachineDraw.pools(chute, self)
	return _pools[chute]


## MachineDraw.guarantee for the chute, computed once.
func guarantee(chute: int) -> Dictionary:
	if not _guarantees.has(chute):
		_guarantees[chute] = MachineDraw.guarantee(chute, self)
	return _guarantees[chute]
