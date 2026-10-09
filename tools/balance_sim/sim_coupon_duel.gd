class_name SimCouponDuel
extends RefCounted
## Coupons valued against each other for the coupon slot (plan section 8), not against
## skipping. Each sample draws hand_size - 1 cards from the deck; then each coupon in turn
## completes that same hand, and the coupons are compared on its best total.

var coupons: Array[CardDefinition] = []
## Per played sample index: each coupon's best total, and 1 where that total needed the coupon.
var _totals: Dictionary[int, PackedInt32Array] = {}
var _needed: Dictionary[int, PackedInt32Array] = {}
var _deck: Array[CardDefinition] = []
var _balance: BalanceDefinition
var _seed: int = 0


## The coupons are those of the first-offer pool and coupon_pool, in pool order.
func _init(deck: DeckDefinition, balance: BalanceDefinition, duel_seed: int) -> void:
	_deck = deck.cards
	_balance = balance
	_seed = duel_seed
	for card: CardDefinition in balance.first_offer_pool + balance.coupon_pool:
		if card.is_coupon() and not coupons.has(card):
			coupons.append(card)


func sample_count() -> int:
	return _totals.size()


## The played samples, for a simulator process to write: [[index, totals, needed], ...].
func samples_to_array() -> Array:
	var result: Array = []
	for index: int in _totals:
		result.append([index, _totals[index], _needed[index]])
	return result


## Adds samples written by samples_to_array (read back from JSON).
func add_samples(samples: Array) -> void:
	for sample: Array in samples:
		_totals[int(sample[0])] = PackedInt32Array(sample[1])
		_needed[int(sample[0])] = PackedInt32Array(sample[2])


## Plays sample `index` with `search`; each index gives its own hand.
func run_sample(search: SimRowSearch, index: int) -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash("coupon_duel:%d:%d" % [_seed, index])
	var pile: Array[CardInstance] = []
	for card_index: int in range(_deck.size()):
		pile.append(CardInstance.new(_deck[card_index], card_index + 1))
	SimPlayer.shuffle(rng, pile)
	var hand: Array[CardInstance] = pile.slice(0, _balance.hand_size - 1)
	var totals: PackedInt32Array = PackedInt32Array()
	var needed: PackedInt32Array = PackedInt32Array()
	var no_upgrades: Array[UpgradeDefinition] = []
	for coupon: CardDefinition in coupons:
		var with_coupon: Array[CardInstance] = hand.duplicate()
		with_coupon.append(CardInstance.new(coupon, _deck.size() + 1))
		var best: SimHandBest = search.search(with_coupon, no_upgrades)
		# The time limit stopped the search: the sample is dropped.
		if search.stopped:
			return
		totals.append(best.score)
		needed.append(1 if best.is_needed(coupon) else 0)
	_totals[index] = totals
	_needed[index] = needed


func mean(coupon_index: int) -> float:
	var sum: int = 0
	for totals: PackedInt32Array in _totals.values():
		sum += totals[coupon_index]
	return float(sum) / maxf(_totals.size(), 1)


## Share of samples where this coupon gave the highest total (ties count for every coupon).
func top_share(coupon_index: int) -> float:
	var top: int = 0
	for totals: PackedInt32Array in _totals.values():
		var highest: int = totals[0]
		for total: int in totals:
			highest = maxi(highest, total)
		if totals[coupon_index] == highest:
			top += 1
	return float(top) / maxf(_totals.size(), 1)


func needed_share(coupon_index: int) -> float:
	var count: int = 0
	for needed: PackedInt32Array in _needed.values():
		count += needed[coupon_index]
	return float(count) / maxf(_needed.size(), 1)


func format() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("== Coupon slot: coupons against each other ==")
	lines.append(
		(
			"%d starting-deck hands of %d cards, each completed by every coupon in turn"
			% [sample_count(), _balance.hand_size - 1]
		)
	)
	lines.append("Coupon             Mean best  vs average  Top share  Needed")
	var average: float = 0.0
	for index: int in range(coupons.size()):
		average += mean(index) / coupons.size()
	for index: int in range(coupons.size()):
		lines.append(
			(
				"%-17s %10.2f  %+10.2f  %8.1f%%  %5.1f%%"
				% [
					coupons[index].id,
					mean(index),
					mean(index) - average,
					100.0 * top_share(index),
					100.0 * needed_share(index)
				]
			)
		)
	return "\n".join(lines)


func to_dictionary() -> Dictionary:
	var result: Dictionary[String, Dictionary] = {}
	for index: int in range(coupons.size()):
		result[String(coupons[index].id)] = {
			"mean_best": mean(index),
			"top_share": top_share(index),
			"needed_share": needed_share(index),
		}
	return {"samples": sample_count(), "coupons": result}
