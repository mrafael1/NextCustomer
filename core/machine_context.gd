class_name MachineContext
extends RefCounted
## A frozen snapshot of the run that one machine draw reads (#77, build spec 1.5): the stocked
## products, the coupon pool, the owned upgrades, the deck, the first-draw flags and the newest
## new arrival. RewardMachine builds one from the run (from_run); tests build their own. The
## pools and guarantees are computed once per context and kept on it (never in a static cache),
## so drawing many times from one state reads them once.

var machine: MachineDefinition
var balance: BalanceDefinition
## The stocked products (plain only), in stock order.
var products: Array[CardDefinition] = []
## The coupons the COUPONS chute draws from.
var coupons: Array[CardDefinition] = []
## The upgrades the REGISTER chute draws from (owned ones are left out by the draw).
var upgrade_pool: Array[UpgradeDefinition] = []
## The run's owned upgrades.
var owned: Array[UpgradeDefinition] = []
## A copy of the run's deck list (same instances, own list).
var deck: Deck
## The run's first COUPONS draw: it holds one first_offer_pool coupon.
var first_coupons: bool = false
## The run's first NEW ITEMS draw: it holds `new_arrival` (when the machine says so).
var first_new_items: bool = false
## The stock's newest new arrival, or null.
var new_arrival: CardDefinition
## The guarantee set: coupons in the first-offer pool on the first COUPONS draw.
var first_offer_pool: Array[CardDefinition] = []
var _pools: Dictionary = {}
var _guarantees: Dictionary = {}


## The snapshot of a run for its machine. `coupons_first_done` / `new_items_first_done` are the
## machine's flags (a first draw is one whose flag isn't spent yet).
static func from_run(
	run: RunState,
	machine_definition: MachineDefinition,
	coupons_first_done: bool,
	new_items_first_done: bool
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
	context.first_new_items = not new_items_first_done
	if not run.stock.new_arrivals.is_empty():
		context.new_arrival = run.stock.new_arrivals[0]
	return context


## The deck's cards as definitions (what REGISTER's "fits" reads).
func deck_cards() -> Array[CardDefinition]:
	var found: Array[CardDefinition] = []
	for card: CardInstance in deck.cards:
		found.append(card.definition)
	return found


## Whether this context's NEW ITEMS draw holds the new arrival (build spec 1.5, Q4).
func holds_new_arrival() -> bool:
	return (
		machine.new_arrival_first_visit
		and first_new_items
		and new_arrival != null
		and products.has(new_arrival)
	)


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
