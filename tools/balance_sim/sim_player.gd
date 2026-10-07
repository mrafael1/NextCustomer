class_name SimPlayer
extends RefCounted
## Plays runs for the balance simulator (plan section 8) through RunState, as the game does:
## the same impulse rack, seeded draws, redraws, row limits, reward offers, upgrade offers and
## inspections.
## Only the choices come from the simulator. An inspected shift's best row is searched under its
## inspection; reward and upgrade picks don't look ahead to the next shift's inspection. Every
## run stocks what a new profile does (RunStock.starting, full build plan 7.2).
##
## Every shift plays the best row of the hand (SimRowSearch). First it redraws, for as long as
## redraws are left, the hand cards the best row doesn't use (at most redraw_limit each time,
## lowest base value first). The best row stays in the hand, so such a redraw never lowers the
## best total.
##
## Strategies, for the reward picks and the impulse rack before shift 1 (picked like a reward):
## - "greedy": the offered card, or skip, with the highest mean best total over sample hands
##   of the deck it makes (redraws included)
## - "random": a random offered card, never a skip
## - "skip": always skips, so the deck stays the starting deck
## - "favour:id+id": the first offered card in its list, else as greedy (a build-focused player)
## Upgrades are always picked (there is no skip): at random by "random", else greedily. At the
## deck limit, the card that leaves is the deck card the run's best rows used least.

const STRATEGIES: Array[String] = ["greedy", "random", "skip", "favour:"]

var _starter: DeckDefinition
var _balance: BalanceDefinition
var _stock: RunStock
var _search: SimRowSearch
var _strategy: String
var _favoured: Array[StringName] = []
var _samples: int
## The strategy's own randomness (picks, sample hands), seeded from the run seed. The run's
## draws and offers keep using the run's RNG, as in the game.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(
	starter: DeckDefinition,
	balance: BalanceDefinition,
	search: SimRowSearch,
	strategy: String,
	samples: int
) -> void:
	_starter = starter
	_balance = balance
	_stock = RunStock.starting(starter, balance)
	_search = search
	_strategy = strategy
	_samples = maxi(samples, 1)
	if strategy.begins_with("favour:"):
		for id: String in strategy.trim_prefix("favour:").split("+", false):
			_favoured.append(StringName(id))


static func is_known_strategy(strategy: String) -> bool:
	if strategy.begins_with("favour:"):
		return not strategy.trim_prefix("favour:").is_empty()
	return STRATEGIES.has(strategy)


func play(run_seed: int) -> SimRunRecord:
	var stream: RandomNumberGenerator = EventLogService.derived_stream(
		run_seed, EventLogService.IMPULSE_RACK_STREAM
	)
	var run: RunState = RunState.new(run_seed, _starter, _balance, _stock, stream)
	_rng.seed = hash("balance_sim:%d" % run_seed)
	var record: SimRunRecord = SimRunRecord.new()
	record.run_seed = run_seed
	# Per card definition: how many of the run's best rows used it.
	var usage: Dictionary[CardDefinition, int] = {}
	if run.phase == RunState.Phase.IMPULSE:
		_pick_reward(run, usage)
		record.impulse_offered = true
		record.impulse_pick = String(run.impulse_pick.id) if run.impulse_pick != null else ""
	run.start_shift()
	while true:
		_play_shift(run, record, usage)
		if run.phase != RunState.Phase.REWARD:
			break
		_pick_reward(run, usage)
		if run.phase == RunState.Phase.UPGRADE:
			_pick_upgrade(run)
		run.next_shift()
	record.won = run.phase == RunState.Phase.WON
	for entry: ShiftRecord in run.history:
		record.shifts.append(entry.to_dictionary())
	for card: CardInstance in run.deck.cards:
		record.final_deck.append(String(card.definition.id))
	return record


func _play_shift(
	run: RunState, record: SimRunRecord, usage: Dictionary[CardDefinition, int]
) -> void:
	var best: SimHandBest = _search.search(run.hand(), run.upgrades, run.inspections)
	while run.redraws_used < run.redraws_allowed:
		var replaced: Array[CardInstance] = _redraw_pick(run.hand(), best)
		if replaced.is_empty() or run.redraw(replaced).is_empty():
			break
		record.redraws += 1
		best = _search.search(run.hand(), run.upgrades, run.inspections)
	for card: CardInstance in best.row:
		run.place(card, run.row.size())
	var result: ScoreResult = run.checkout()
	if result.total != best.score:
		push_error(
			"balance_sim: the best row scored %d, the search said %d" % [result.total, best.score]
		)
	record.count_hand(run.deck.hand(), best)
	var counted: Array[CardDefinition] = []
	for card: CardInstance in best.row:
		if not counted.has(card.definition):
			counted.append(card.definition)
			usage[card.definition] = usage.get(card.definition, 0) + 1


## The hand cards the best row doesn't use, lowest base value first, at most redraw_limit.
func _redraw_pick(hand: Array[CardInstance], best: SimHandBest) -> Array[CardInstance]:
	var unused: Array[CardInstance] = []
	for card: CardInstance in hand:
		if not best.row.has(card):
			unused.append(card)
	var order: Array[CardInstance] = unused.duplicate()
	order.sort_custom(
		func(a: CardInstance, b: CardInstance) -> bool:
			if a.definition.base != b.definition.base:
				return a.definition.base < b.definition.base
			return unused.find(a) < unused.find(b)
	)
	return order.slice(0, _balance.redraw_limit)


func _pick_reward(run: RunState, usage: Dictionary[CardDefinition, int]) -> void:
	var choice: CardDefinition = null
	if _strategy == "random":
		choice = run.offer[_rng.randi_range(0, run.offer.size() - 1)]
	elif _strategy != "skip":
		for id: StringName in _favoured:
			for card: CardDefinition in run.offer:
				if choice == null and card.id == id:
					choice = card
		if choice == null:
			choice = _greedy_card(run, usage)
	if choice == null:
		run.skip_reward()
		return
	var replaced: CardInstance = _least_used(run, usage) if run.deck_is_full() else null
	run.take_reward(choice, replaced)


## The offered card with the highest mean best total, or null when skipping does at least as
## well. Every option is judged on the same sample shuffles.
func _greedy_card(run: RunState, usage: Dictionary[CardDefinition, int]) -> CardDefinition:
	var current: Array[CardDefinition] = _deck_definitions(run.deck.cards)
	var kept: Array[CardDefinition] = current.duplicate()
	if run.deck_is_full():
		kept.erase(_least_used(run, usage).definition)
	var redraws: int = _redraws_with(run.upgrades)
	var sample_seed: int = _rng.randi()
	var choice: CardDefinition = null
	var best_value: float = _sample_value(current, run.upgrades, redraws, sample_seed)
	for card: CardDefinition in run.offer:
		var deck: Array[CardDefinition] = kept.duplicate()
		deck.append(card)
		var value: float = _sample_value(deck, run.upgrades, redraws, sample_seed)
		if value > best_value:
			best_value = value
			choice = card
	return choice


func _pick_upgrade(run: RunState) -> void:
	var offer: Array[UpgradeDefinition] = run.upgrade_offer
	var choice: UpgradeDefinition = offer[0]
	if _strategy == "random":
		choice = offer[_rng.randi_range(0, offer.size() - 1)]
	else:
		var deck: Array[CardDefinition] = _deck_definitions(run.deck.cards)
		var sample_seed: int = _rng.randi()
		var best_value: float = -1.0
		for upgrade: UpgradeDefinition in offer:
			var upgrades: Array[UpgradeDefinition] = run.upgrades.duplicate()
			upgrades.append(upgrade)
			var value: float = _sample_value(deck, upgrades, _redraws_with(upgrades), sample_seed)
			if value > best_value:
				best_value = value
				choice = upgrade
	run.pick_upgrade(choice)


## Mean best total of `_samples` hands drawn from these cards, each played as a shift is
## (redraws of the unused cards included).
func _sample_value(
	deck: Array[CardDefinition], upgrades: Array[UpgradeDefinition], redraws: int, sample_seed: int
) -> float:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = sample_seed
	var cards: Array[CardInstance] = []
	for index: int in range(deck.size()):
		cards.append(CardInstance.new(deck[index], index + 1))
	var total: int = 0
	for _sample: int in range(_samples):
		var pile: Array[CardInstance] = cards.duplicate()
		shuffle(rng, pile)
		var hand: Array[CardInstance] = []
		while hand.size() < _balance.hand_size and not pile.is_empty():
			hand.append(pile.pop_back())
		var best: SimHandBest = _search.search(hand, upgrades)
		for _redraw: int in range(redraws):
			var replaced: Array[CardInstance] = _redraw_pick(hand, best)
			if replaced.is_empty() or pile.is_empty():
				break
			for card: CardInstance in replaced:
				if not pile.is_empty():
					hand[hand.find(card)] = pile.pop_back()
			best = _search.search(hand, upgrades)
		total += best.score
	return float(total) / float(_samples)


## The deck card the run's best rows used least; ties go to the lower base value, then to the
## card earlier in the deck.
func _least_used(run: RunState, usage: Dictionary[CardDefinition, int]) -> CardInstance:
	var least: CardInstance = null
	for card: CardInstance in run.deck.cards:
		if least == null:
			least = card
			continue
		var uses: int = usage.get(card.definition, 0)
		var least_uses: int = usage.get(least.definition, 0)
		if (
			uses < least_uses
			or (uses == least_uses and card.definition.base < least.definition.base)
		):
			least = card
	return least


func _redraws_with(upgrades: Array[UpgradeDefinition]) -> int:
	var redraws: int = RunState.BASE_REDRAWS
	for upgrade: UpgradeDefinition in upgrades:
		redraws += upgrade.extra_redraws
	return redraws


static func _deck_definitions(cards: Array[CardInstance]) -> Array[CardDefinition]:
	var definitions: Array[CardDefinition] = []
	for card: CardInstance in cards:
		definitions.append(card.definition)
	return definitions


## Fisher-Yates with the given RNG. Array.shuffle() would use the global RNG.
static func shuffle(rng: RandomNumberGenerator, pile: Array[CardInstance]) -> void:
	for index: int in range(pile.size() - 1, 0, -1):
		var other: int = rng.randi_range(0, index)
		var swap: CardInstance = pile[index]
		pile[index] = pile[other]
		pile[other] = swap
