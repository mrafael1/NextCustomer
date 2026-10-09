class_name SimPlayer
extends RefCounted
## Plays runs for the balance simulator (plan section 8) through RunState, as the game does:
## the same impulse rack, seeded draws, redraws, row limits, reward offers, upgrade offers and
## inspections.
## Only the choices come from the simulator. An inspected shift's best row is searched under its
## inspection; reward and upgrade picks don't look ahead to the next shift's inspection. Every
## run stocks the stock it is given (a collection state's, SimCollection), by default what a new
## profile stocks (RunStock.starting, full build plan 7.2).
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
## - "build:id": drafts towards a build (SimBuilds, decided with the user, #40): of the offered
##   cards, those that raise the build's measure most, the best of them as greedy judges it
##   (never a skip); when none raises it, as greedy. Its upgrade pick is the first offered
##   upgrade that lists the build, else as greedy.
## Upgrades are always picked (there is no skip): at random by "random", else greedily. At the
## deck limit, the card that leaves is the deck card the run's best rows used least.

const STRATEGIES: Array[String] = ["greedy", "random", "skip", "favour:", "build:"]

var _starter: DeckDefinition
var _balance: BalanceDefinition
var _stock: RunStock
var _search: SimRowSearch
var _strategy: String
var _favoured: Array[StringName] = []
var _builds: SimBuilds
## The build a "build:id" strategy drafts towards, else null.
var _target: BuildDefinition
var _samples: int
## The strategy's own randomness (picks, sample hands), seeded from the run seed. The run's
## draws and offers keep using the run's RNG, as in the game.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(
	starter: DeckDefinition,
	balance: BalanceDefinition,
	search: SimRowSearch,
	strategy: String,
	samples: int,
	stock: RunStock = null,
	builds: SimBuilds = null
) -> void:
	_starter = starter
	_balance = balance
	_stock = stock if stock != null else RunStock.starting(starter, balance)
	var no_builds: Array[BuildDefinition] = []
	_builds = builds if builds != null else SimBuilds.new(no_builds)
	_search = search
	_strategy = strategy
	_samples = maxi(samples, 1)
	if strategy.begins_with("favour:"):
		for id: String in strategy.trim_prefix("favour:").split("+", false):
			_favoured.append(StringName(id))
	if strategy.begins_with("build:"):
		_target = _builds.find(strategy.trim_prefix("build:"))


static func is_known_strategy(strategy: String) -> bool:
	for prefix: String in ["favour:", "build:"]:
		if strategy.begins_with(prefix):
			return not strategy.trim_prefix(prefix).is_empty()
	return STRATEGIES.has(strategy)


## Plays the run of `run_seed`, or returns null if the search's time limit stopped it partway.
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
		if _search.stopped:
			return null
		if run.phase != RunState.Phase.REWARD:
			break
		_pick_reward(run, usage)
		if _search.stopped:
			return null
		if run.phase == RunState.Phase.UPGRADE:
			_pick_upgrade(run)
		run.next_shift()
	record.won = run.phase == RunState.Phase.WON
	for entry: ShiftRecord in run.history:
		record.shifts.append(entry.to_dictionary())
	for card: CardInstance in run.deck.cards:
		record.final_deck.append(String(card.definition.id))
	record.main_build = _builds.main_build(_deck_definitions(run.deck.cards))
	var payout: CoinPayout = CoinPayout.for_run(run)
	record.coins = payout.total()
	record.overtime_coins = payout.overtime_coins
	return record


func _play_shift(
	run: RunState, record: SimRunRecord, usage: Dictionary[CardDefinition, int]
) -> void:
	var best: SimHandBest = _search.search(run.hand(), run.upgrades, run.inspections)
	while run.redraws_used < run.redraws_allowed and not _search.stopped:
		var replaced: Array[CardInstance] = _redraw_pick(run.hand(), best)
		if replaced.is_empty() or run.redraw(replaced).is_empty():
			break
		record.redraws += 1
		best = _search.search(run.hand(), run.upgrades, run.inspections)
	# The time limit stopped the search: the run is dropped, so the shift isn't played.
	if _search.stopped:
		return
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
		if choice == null and _target != null:
			choice = _build_card(run, usage)
		if choice == null:
			choice = _greedy_card(run, usage, run.offer, true)
	if choice == null:
		run.skip_reward()
		return
	var replaced: CardInstance = _least_used(run, usage) if run.deck_is_full() else null
	run.take_reward(choice, replaced)


## For "build:id": the offered card that raises the build's measure most (the best of those as
## greedy judges them), or null when none raises it.
func _build_card(run: RunState, usage: Dictionary[CardDefinition, int]) -> CardDefinition:
	var candidates: Array[CardDefinition] = raising_cards(
		_target, _kept_deck(run, usage), run.offer
	)
	if candidates.size() <= 1:
		return null if candidates.is_empty() else candidates[0]
	return _greedy_card(run, usage, candidates, false)


## The offered cards that raise the build's measure most when added to `deck` (none when no
## card raises it), in offer order.
static func raising_cards(
	build: BuildDefinition, deck: Array[CardDefinition], offer: Array[CardDefinition]
) -> Array[CardDefinition]:
	var before: int = build.count(deck)
	var best_gain: int = 0
	var candidates: Array[CardDefinition] = []
	for card: CardDefinition in offer:
		var with_card: Array[CardDefinition] = deck.duplicate()
		with_card.append(card)
		var gain: int = build.count(with_card) - before
		if gain > best_gain:
			best_gain = gain
			candidates.clear()
		if gain > 0 and gain == best_gain:
			candidates.append(card)
	return candidates


## The card of `options` with the highest mean best total; when `can_skip`, null if skipping
## does at least as well. Every option is judged on the same sample shuffles.
func _greedy_card(
	run: RunState,
	usage: Dictionary[CardDefinition, int],
	options: Array[CardDefinition],
	can_skip: bool
) -> CardDefinition:
	var current: Array[CardDefinition] = _deck_definitions(run.deck.cards)
	var kept: Array[CardDefinition] = _kept_deck(run, usage)
	var redraws: int = _redraws_with(run.upgrades)
	var sample_seed: int = _rng.randi()
	var choice: CardDefinition = null
	var best_value: float = -1.0
	if can_skip:
		best_value = _sample_value(current, run.upgrades, redraws, sample_seed)
	for card: CardDefinition in options:
		var deck: Array[CardDefinition] = kept.duplicate()
		deck.append(card)
		var value: float = _sample_value(deck, run.upgrades, redraws, sample_seed)
		if value > best_value:
			best_value = value
			choice = card
	return choice


## The offered upgrades that list the build (compared by id, so a build file loaded apart from
## the upgrades' still matches), in offer order.
static func upgrades_listing(
	build: BuildDefinition, offer: Array[UpgradeDefinition]
) -> Array[UpgradeDefinition]:
	var listing: Array[UpgradeDefinition] = []
	for upgrade: UpgradeDefinition in offer:
		if upgrade.builds.any(func(listed: BuildDefinition) -> bool: return listed.id == build.id):
			listing.append(upgrade)
	return listing


## The deck a reward joins: at the deck limit, without the card that would leave.
func _kept_deck(run: RunState, usage: Dictionary[CardDefinition, int]) -> Array[CardDefinition]:
	var kept: Array[CardDefinition] = _deck_definitions(run.deck.cards)
	if run.deck_is_full():
		kept.erase(_least_used(run, usage).definition)
	return kept


func _pick_upgrade(run: RunState) -> void:
	var offer: Array[UpgradeDefinition] = run.upgrade_offer
	var choice: UpgradeDefinition = offer[0]
	var fitting: Array[UpgradeDefinition] = []
	if _target != null:
		fitting = upgrades_listing(_target, offer)
	if not fitting.is_empty():
		choice = fitting[0]
	elif _strategy == "random":
		choice = offer[_rng.randi_range(0, offer.size() - 1)]
	else:
		var deck: Array[CardDefinition] = _deck_definitions(run.deck.cards)
		var sample_seed: int = _rng.randi()
		var best_value: float = -1.0
		for upgrade: UpgradeDefinition in offer:
			var upgrades: Array[UpgradeDefinition] = run.upgrades.duplicate()
			upgrades.append(upgrade)
			var value: float = _sample_value(deck, upgrades, _redraws_with(upgrades), sample_seed)
			# Big basket's quota raise costs as much as it adds: compare totals against the
			# quota they have to reach, not raw totals.
			value = value * 100.0 / (100.0 + _quota_percent(upgrades))
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


static func _quota_percent(upgrades: Array[UpgradeDefinition]) -> int:
	var percent: int = 0
	for upgrade: UpgradeDefinition in upgrades:
		percent += upgrade.quota_percent
	return percent


func _redraws_with(upgrades: Array[UpgradeDefinition]) -> int:
	return ShiftLimits.for_shift(_balance, upgrades, 0).redraws


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
