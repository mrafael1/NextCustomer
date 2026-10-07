class_name RewardOffer
extends RefCounted
## Builds the cards offered after a passed shift (plan section 5) and the impulse rack's offer
## before shift 1, from the run's stock (full build plan 7.2), using only the RNG passed in.
##
## The run's first offer always includes a combination coupon (a stocked one: every run stocks
## coupon_pool, which holds the first-offer pool, a data test). Every later offer has at least
## one coupon and at least one generally useful card. An offer never shows a card twice.
##
## The impulse rack shows impulse_rack_size stocked products; the newest new arrival, if the
## run has one, always takes one of its slots.


static func make(
	rng: RandomNumberGenerator,
	balance: BalanceDefinition,
	stock: Array[CardDefinition],
	first_offer: bool
) -> Array[CardDefinition]:
	var offer: Array[CardDefinition] = []
	if first_offer:
		_add_one_of(rng, _stocked(balance.first_offer_pool, stock), offer)
	else:
		_add_one_of(rng, _coupons(stock), offer)
		_add_one_of(rng, _generally_useful(stock), offer)
	while offer.size() < balance.offer_size:
		if not _add_one_of(rng, stock, offer):
			break
	_shuffle(rng, offer)
	return offer


## The impulse rack's offer (full build plan 7.2). `rng` is the rack's derived stream, never
## the run's RNG, so the rack doesn't change the run's draws and offers.
static func make_impulse(
	rng: RandomNumberGenerator, balance: BalanceDefinition, stock: RunStock
) -> Array[CardDefinition]:
	var offer: Array[CardDefinition] = []
	if balance.impulse_rack_size <= 0:
		return offer
	if not stock.new_arrivals.is_empty():
		offer.append(stock.new_arrivals[0])
	var products: Array[CardDefinition] = _products(stock.cards)
	while offer.size() < balance.impulse_rack_size:
		if not _add_one_of(rng, products, offer):
			break
	_shuffle(rng, offer)
	return offer


## Adds a random card from `pool` that isn't in the offer yet. False if there is none.
static func _add_one_of(
	rng: RandomNumberGenerator, pool: Array[CardDefinition], offer: Array[CardDefinition]
) -> bool:
	var candidates: Array[CardDefinition] = []
	for card: CardDefinition in pool:
		if not offer.has(card):
			candidates.append(card)
	if candidates.is_empty():
		return false
	offer.append(candidates[rng.randi_range(0, candidates.size() - 1)])
	return true


## The cards of `pool` that are in the stock, in pool order.
static func _stocked(
	pool: Array[CardDefinition], stock: Array[CardDefinition]
) -> Array[CardDefinition]:
	var found: Array[CardDefinition] = []
	for card: CardDefinition in pool:
		if stock.has(card):
			found.append(card)
	return found


static func _products(pool: Array[CardDefinition]) -> Array[CardDefinition]:
	var products: Array[CardDefinition] = []
	for card: CardDefinition in pool:
		if card.is_product():
			products.append(card)
	return products


static func _coupons(pool: Array[CardDefinition]) -> Array[CardDefinition]:
	var coupons: Array[CardDefinition] = []
	for card: CardDefinition in pool:
		if card.is_coupon():
			coupons.append(card)
	return coupons


static func _generally_useful(pool: Array[CardDefinition]) -> Array[CardDefinition]:
	var useful: Array[CardDefinition] = []
	for card: CardDefinition in pool:
		if card.generally_useful:
			useful.append(card)
	return useful


## Fisher-Yates with the run's RNG, so the guaranteed card isn't always first.
static func _shuffle(rng: RandomNumberGenerator, offer: Array[CardDefinition]) -> void:
	for index: int in range(offer.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var swap: CardDefinition = offer[index]
		offer[index] = offer[other]
		offer[other] = swap
