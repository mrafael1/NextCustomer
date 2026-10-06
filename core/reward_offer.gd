class_name RewardOffer
extends RefCounted
## Builds the cards offered after a passed shift (plan section 5), using only the RNG passed in.
##
## The run's first offer always includes a combination coupon. Every later offer has at least
## one coupon and at least one generally useful card. An offer never shows a card twice.


static func make(
	rng: RandomNumberGenerator, balance: BalanceDefinition, first_offer: bool
) -> Array[CardDefinition]:
	var offer: Array[CardDefinition] = []
	if first_offer:
		_add_one_of(rng, balance.first_offer_pool, offer)
	else:
		_add_one_of(rng, _coupons(balance.reward_pool), offer)
		_add_one_of(rng, _generally_useful(balance.reward_pool), offer)
	while offer.size() < balance.offer_size:
		if not _add_one_of(rng, balance.reward_pool, offer):
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
