class_name SimPlayer
extends RefCounted
## Plays runs for the balance simulator (plan section 8) through RunState, as the game does:
## the same seeded draws, redraws, row limits, RECEIPT REWARDS machine visits (#77: the ticket's,
## the bonus ticket's and STAMP DAY's, drawn by RewardMachine with the run's RNG) and
## inspections.
## Only the choices come from the simulator. An inspected shift's best row is searched under its
## inspection; machine picks don't look ahead to the next shift's inspection. Every
## run stocks the stock it is given (a collection state's, SimCollection), by default what a new
## profile stocks (RunStock.starting, full build plan 7.2).
##
## Every shift plays the best row of the hand (SimRowSearch). First it redraws a basket (plan
## section 3.8: one basket's hand cards, swapped in their places), for as long as redraws are
## left, as a player does: the row goes on the belt first, so a redraw swaps only the cards the
## row leaves out and never lowers the kept row. Of the baskets still holding a card, it takes
## the one with the most cards, then the lowest total base value, then the leftmost (one-item
## baskets too). The row is then taken back and played again from the row it kept.
##
## The machine's chute is chosen blind (#77 S1, build spec 7.1): from the odds cards
## (RewardMachine.chute_info) only, never from the prizes the machine would drop. "greedy" values
## each lit chute's draw: every prize its odds card can drop is valued once per visit by the mean
## total of the deck (and registers) it makes (`_sample_value`, all on the visit's sample
## shuffles, played with the sensible player's rows whatever the strategy's row player, as an
## exact search per prize would take hours per run), as a gain over the current deck (NEW
## ITEMS and COUPONS: never below 0, since the prizes can be binned; REGISTER: Big basket
## normalised, as the pick does). The chute's value is
## the expected gain of the best prize drawn, each prize weighted by its chance to be in the draw
## and none of the better ones to be (MachineOddsCard.in_draw, taken as independent: a top-k
## expectation). The highest value wins, ties to the chute order. "random" chooses a random lit
## chute; "skip" NEW ITEMS (else the first lit chute) and bins it. "favour:" chooses the first lit
## chute whose odds card can drop a favoured card, else as greedy. "build:" chooses, while it
## still builds, the card chute with the highest chance to drop a card that raises its measure,
## else REGISTER when its odds card can drop an upgrade listing the build and the run owns none,
## else as greedy. STAMP DAY's register is always picked greedily, by every strategy.
##
## Strategies, for the picks among the prizes shown (NEW ITEMS and COUPONS prizes are "offered
## cards"; binning is the skip):
## - "greedy": the offered card, or skip, with the highest mean best total over sample hands
##   of the deck it makes (redraws included)
## - "random": a random offered card, never a skip
## - "skip": always skips, so the deck stays the starting deck (but for item upgrades and
##   registers, which can't be binned)
## - "favour:id+id": the first offered card in its list, else as greedy (a build-focused player)
## - "build:id": drafts towards a build (SimBuilds, decided with the user, #40; revised in #42):
##   while the deck's measure is under the build's min_count + BUILD_MARGIN, of the offered
##   cards, those that raise the build's measure most, the best of them as greedy judges it
##   (never a skip); when none raises it, or once the measure reaches that, as greedy. At the
##   deck limit it never lets go of a card whose loss lowers the measure while the measure is
##   at most min_count + BUILD_MARGIN. Its upgrade pick is the offered upgrade that lists the
##   build and that greedy values most, if that value is within LISTED_UPGRADE_SHARE of the
##   best offered upgrade's, else as greedy.
## Registers and item upgrades are always picked (there is no skip): at random by "random", else
## greedily (an item upgrade by the mean best total of the deck it makes). At the deck limit, the
## card that leaves is the deck card the run's rows used least.
##
## Row players (decided with the user, #41): a strategy plays the best row (above) unless it
## ends in "@sensible" (e.g. "greedy@sensible"). Then every row, the shift's and the greedy
## valuation's sample hands alike, is the one SimHillClimb plays (a sensible but not optimal
## order), its redraws replace the baskets that row leaves out, and after each redraw it climbs
## again from the row it kept, with another SimHillClimb.SENSIBLE_CHANGES changes (decided with
## the user, #41: a player rearranges once new cards arrive). The shift still searches the
## exact best row to record it beside the played total (the "best" field of each shift). Each
## shift also records its hand at checkout ("hand", card ids), so a card's absence can be
## compared with its presence.

const STRATEGIES: Array[String] = ["greedy", "random", "skip", "favour:", "build:"]
const SENSIBLE_SUFFIX := "@sensible"
## A "build:id" strategy drafts towards its build until the measure is min_count + this.
const BUILD_MARGIN := 2
## A "build:id" strategy picks an upgrade listing its build when greedy values it at least this
## share of the best offered upgrade.
const LISTED_UPGRADE_SHARE := 0.95

var _starter: DeckDefinition
var _balance: BalanceDefinition
var _stock: RunStock
var _search: SimRowSearch
var _strategy: String
## True for an "@sensible" strategy: rows come from _climber instead of the exact search.
var _sensible: bool = false
var _climber: SimHillClimb = SimHillClimb.new()
var _favoured: Array[StringName] = []
var _builds: SimBuilds
## The build a "build:id" strategy drafts towards, else null.
var _target: BuildDefinition
var _samples: int
## The strategy's own randomness (picks, sample hands), seeded from the run seed. The run's
## draws and the machine's keep using the run's RNG, as in the game.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## The sample shuffles' seed of the current machine visit (drawn from _rng when the visit
## starts), so the chute choice and the pick judge every deck on the same hands; and the
## valuations made during the visit (_sample_value), by seed, redraws, registers and deck.
var _visit_seed: int = 0
var _values: Dictionary[String, float] = {}
## True while choosing a chute: the valuations then play the sensible player's rows
## (SimHillClimb) whatever the strategy's row player, since every prize an odds card can drop
## is valued and an exact search for each of them would take hours per run.
var _choosing: bool = false


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
	_sensible = strategy.ends_with(SENSIBLE_SUFFIX)
	_strategy = strategy.trim_suffix(SENSIBLE_SUFFIX)
	_samples = maxi(samples, 1)
	if _strategy.begins_with("favour:"):
		for id: String in _strategy.trim_prefix("favour:").split("+", false):
			_favoured.append(StringName(id))
	if _strategy.begins_with("build:"):
		_target = _builds.find(_strategy.trim_prefix("build:"))


static func is_known_strategy(strategy: String) -> bool:
	strategy = strategy.trim_suffix(SENSIBLE_SUFFIX)
	for prefix: String in ["favour:", "build:"]:
		if strategy.begins_with(prefix):
			return not strategy.trim_prefix(prefix).is_empty()
	return STRATEGIES.has(strategy)


## Plays the run of `run_seed`, or returns null if the search's time limit stopped it partway.
func play(run_seed: int) -> SimRunRecord:
	var run: RunState = RunState.new(run_seed, _starter, _balance, _stock)
	_rng.seed = hash("balance_sim:%d" % run_seed)
	var record: SimRunRecord = SimRunRecord.new()
	record.run_seed = run_seed
	# Per card definition: how many of the run's best rows used it.
	var usage: Dictionary[CardDefinition, int] = {}
	run.start_shift()
	while true:
		_play_shift(run, record, usage)
		if _search.stopped:
			return null
		while RunState.MACHINE_PHASES.has(run.phase):
			if not _visit(run, usage):
				push_error("balance_sim: the machine refused the player's choice")
				return null
			if _search.stopped:
				return null
		if run.phase != RunState.Phase.SCORED:
			break
		run.next_shift()
	record.won = run.phase == RunState.Phase.WON
	for index: int in range(run.history.size()):
		var entry: Dictionary = run.history[index].to_dictionary()
		entry["best"] = record.best_totals[index]
		entry["hand"] = record.hands[index]
		record.shifts.append(entry)
	for card: CardInstance in run.deck.cards:
		var id: String = String(card.definition.id)
		record.final_deck.append(id)
		if card.definition.tier != CardDefinition.Tier.PLAIN:
			record.tier_copies[id] = record.tier_copies.get(id, 0) + 1
	record.registers = run.machine.registers_picked(run)
	record.levels = run.machine.levels.duplicate()
	var final_cards: Array[CardDefinition] = _deck_definitions(run.deck.cards)
	record.main_build = _builds.main_build(final_cards)
	record.fitted_builds = _builds.fitted(final_cards)
	var payout: CoinPayout = CoinPayout.for_run(run)
	record.coins = payout.total()
	record.overtime_coins = payout.overtime_coins
	return record


func _play_shift(
	run: RunState, record: SimRunRecord, usage: Dictionary[CardDefinition, int]
) -> void:
	var no_row: Array[CardInstance] = []
	var played: SimHandBest = _play_row(
		run.hand(), run.upgrades, run.inspections, run.limits, no_row
	)
	while run.redraws_used < run.redraws_allowed and not _search.stopped:
		# As a player does: the row goes on the belt, a basket of the cards left is redrawn
		# (row cards are never swapped), then the row is taken back to be played again.
		for card: CardInstance in played.row:
			run.place(card, run.row.size())
		var basket: int = _basket_pick(run.hand_places())
		var swapped: bool = basket >= 0 and not run.redraw_basket(basket).is_empty()
		for card: CardInstance in played.row:
			run.remove(card)
		if not swapped:
			break
		record.redraws += 1
		played = _play_row(run.hand(), run.upgrades, run.inspections, run.limits, played.row)
	var best: SimHandBest = played
	if _sensible and not _search.stopped:
		best = _search.search(run.hand(), run.upgrades, run.inspections)
	# The time limit stopped the search: the run is dropped, so the shift isn't played.
	if _search.stopped:
		return
	# The hand at checkout: placing the row moves its cards out of run.hand().
	var hand_ids: Array[String] = _ids(run.hand())
	for card: CardInstance in played.row:
		run.place(card, run.row.size())
	var result: ScoreResult = run.checkout()
	if result.total != played.score:
		push_error(
			"balance_sim: the row scored %d, the player said %d" % [result.total, played.score]
		)
	record.count_hand(run.deck.hand(), played, best)
	record.best_totals.append(best.score)
	record.hands.append(hand_ids)
	var counted: Array[CardDefinition] = []
	for card: CardInstance in played.row:
		if not counted.has(card.definition):
			counted.append(card.definition)
			usage[card.definition] = usage.get(card.definition, 0) + 1


## The row this strategy plays with `hand`: the exact best (SimRowSearch), or for "@sensible"
## (or `climb`) the one SimHillClimb climbs to from `start` (the row kept through a redraw;
## empty: the hand).
func _play_row(
	hand: Array[CardInstance],
	upgrades: Array[UpgradeDefinition],
	inspections: Array[InspectionDefinition],
	limits: ShiftLimits,
	start: Array[CardInstance],
	climb: bool = false
) -> SimHandBest:
	if _sensible or climb:
		return _climber.climb(hand, limits, upgrades, inspections, start)
	return _search.search(hand, upgrades, inspections)


## Rows the sensible player scored, for the summary.
func rows_climbed() -> int:
	return _climber.rows_scored


## The basket to redraw (plan section 3.8), by the hand's places with the row on the belt
## (null: a row card's place, or no card): of the baskets still holding a card, the one with the
## most cards, then the lowest total base value, then the leftmost. -1 when none holds a card.
func _basket_pick(hand_by_place: Array[CardInstance]) -> int:
	var size: int = maxi(_balance.basket_size, 1)
	var best: int = -1
	var best_cards: int = 0
	var best_base: int = 0
	for basket: int in range(ceili(float(hand_by_place.size()) / size)):
		var cards: int = 0
		var base: int = 0
		for place: int in range(basket * size, mini((basket + 1) * size, hand_by_place.size())):
			var card: CardInstance = hand_by_place[place]
			if card != null:
				cards += 1
				base += card.definition.base
		if cards == 0:
			continue
		if best < 0 or cards > best_cards or (cards == best_cards and base < best_base):
			best = basket
			best_cards = cards
			best_base = base
	return best


## `hand` by place with `row`'s cards on the belt: null in their places.
static func _off_row(hand: Array[CardInstance], row: Array[CardInstance]) -> Array[CardInstance]:
	var places: Array[CardInstance] = []
	for card: CardInstance in hand:
		places.append(null if row.has(card) else card)
	return places


## Plays the machine's waiting visit: chooses its chute (MACHINE_CHOOSE), then picks or bins.
## False when the machine refused a choice.
func _visit(run: RunState, usage: Dictionary[CardDefinition, int]) -> bool:
	var machine: RewardMachine = run.machine
	_visit_seed = _rng.randi()
	_values.clear()
	if run.phase == RunState.Phase.MACHINE_CHOOSE:
		var chute: int = _choose_chute(run, usage)
		if chute < 0 or not machine.choose(run, chute):
			return false
	var prizes: Array[MachinePrize] = machine.prizes()
	var index: int = -1
	match machine.current_visit().chute:
		RewardMachine.Chute.REGISTER:
			index = _pick_upgrade(run, prizes)
		RewardMachine.Chute.UPGRADES:
			index = _pick_item_upgrade(run, prizes)
		_:
			index = _pick_card(run, usage, prizes)
	if index < 0:
		return machine.bin(run)
	var replaced: CardInstance = null
	if machine.needs_replace(run, index):
		replaced = _least_used(run, usage)
	return machine.pick(run, index, replaced) != null


## The chute this strategy chooses (see the class comment), or -1 when none is lit. It reads the
## odds cards only.
func _choose_chute(run: RunState, usage: Dictionary[CardDefinition, int]) -> int:
	var lit: Array[int] = []
	var odds: Dictionary[int, MachineOddsCard] = {}
	for chute: int in RewardMachine.CHUTES:
		var info: MachineChuteInfo = run.machine.chute_info(run, chute)
		if info.state == RewardMachine.ChuteState.OPEN:
			lit.append(chute)
			odds[chute] = info.odds
	if lit.is_empty():
		return -1
	if _strategy == "random":
		return lit[_rng.randi_range(0, lit.size() - 1)]
	if _strategy == "skip":
		return RewardMachine.Chute.NEW_ITEMS if lit.has(RewardMachine.Chute.NEW_ITEMS) else lit[0]
	for chute: int in lit:
		if _shows_favoured(odds[chute]):
			return chute
	if _target != null:
		var build_chute: int = _build_chute(run, usage, lit, odds)
		if build_chute >= 0:
			return build_chute
	var best: int = lit[0]
	var best_value: float = -INF
	_choosing = true
	for chute: int in lit:
		var value: float = _chute_value(run, usage, chute, odds[chute])
		if value > best_value:
			best_value = value
			best = chute
	_choosing = false
	return best


## For "favour:": whether the odds card gives a favoured card a chance to be drawn.
func _shows_favoured(odds: MachineOddsCard) -> bool:
	for key: String in odds.in_draw:
		if _favoured.has(StringName(key.get_slice(":", 1))) and float(odds.in_draw[key]) > 0.0:
			return true
	return false


## For "build:": while it still builds, the lit card chute most likely to drop a card that raises
## the build's measure; else REGISTER when its odds card can drop an upgrade listing the build
## and the run owns none; else -1 (it chooses as greedy).
func _build_chute(
	run: RunState,
	usage: Dictionary[CardDefinition, int],
	lit: Array[int],
	odds: Dictionary[int, MachineOddsCard]
) -> int:
	var content: Dictionary[String, Resource] = _content(run)
	if still_building(_target, _deck_definitions(run.deck.cards)):
		var kept: Array[CardDefinition] = _kept_deck(run, usage)
		var best: int = -1
		var best_chance: float = 0.0
		for chute: int in lit:
			if chute != RewardMachine.Chute.NEW_ITEMS and chute != RewardMachine.Chute.COUPONS:
				continue
			var chance: float = 0.0
			for key: String in odds[chute].in_draw:
				var card: CardDefinition = content.get(key.get_slice(":", 1)) as CardDefinition
				var one: Array[CardDefinition] = []
				if card != null:
					one.append(card)
				if not raising_cards(_target, kept, one).is_empty():
					chance += float(odds[chute].in_draw[key])
			if chance > best_chance:
				best_chance = chance
				best = chute
		if best >= 0:
			return best
	var owned: Array[UpgradeDefinition] = upgrades_listing(_target, run.upgrades)
	if not lit.has(RewardMachine.Chute.REGISTER) or not owned.is_empty():
		return -1
	for key: String in odds[RewardMachine.Chute.REGISTER].in_draw:
		var upgrade: UpgradeDefinition = content.get(key.get_slice(":", 1)) as UpgradeDefinition
		var one: Array[UpgradeDefinition] = []
		if upgrade != null:
			one.append(upgrade)
		if not upgrades_listing(_target, one).is_empty():
			return RewardMachine.Chute.REGISTER
	return -1


## The expected gain of a chute's draw for greedy (see the class comment): its prizes valued on
## the visit's sample hands, each weighted by its chance to be the best one drawn.
func _chute_value(
	run: RunState, usage: Dictionary[CardDefinition, int], chute: int, odds: MachineOddsCard
) -> float:
	var content: Dictionary[String, Resource] = _content(run)
	var binnable: bool = (
		chute == RewardMachine.Chute.NEW_ITEMS or chute == RewardMachine.Chute.COUPONS
	)
	var gains: Array[float] = []
	var chances: Array[float] = []
	for key: String in odds.in_draw:
		var parts: PackedStringArray = key.split(":")
		var found: Resource = content.get(parts[1])
		if found == null:
			continue
		var gain: float = _prize_gain(run, usage, parts[0], found, int(parts[2]))
		gains.append(maxf(gain, 0.0) if binnable else gain)
		chances.append(clampf(float(odds.in_draw[key]), 0.0, 1.0))
	return expected_best(gains, chances)


## The expected best of prizes drawn independently, each with its chance: the best gain first,
## each weighted by its chance and the chance that no better one is drawn, over the draws that
## hold one at all. 0 with nothing to draw.
static func expected_best(gains: Array[float], chances: Array[float]) -> float:
	var order: Array[int] = []
	for index: int in range(gains.size()):
		order.append(index)
	order.sort_custom(
		func(a: int, b: int) -> bool: return gains[a] > gains[b] or (gains[a] == gains[b] and a < b)
	)
	var none_better: float = 1.0
	var weight_sum: float = 0.0
	var total: float = 0.0
	for index: int in order:
		var weight: float = chances[index] * none_better
		total += weight * gains[index]
		weight_sum += weight
		none_better *= 1.0 - chances[index]
	return total / weight_sum if weight_sum > 0.0 else 0.0


## A prize's gain over the current deck, on the visit's sample hands. `kind` is the odds key's
## (MachinePrize.KIND_NAMES), `found` the prize's card (for "upgrade" the plain product) or
## register.
func _prize_gain(
	run: RunState,
	usage: Dictionary[CardDefinition, int],
	kind: String,
	found: Resource,
	rarity: int
) -> float:
	var current: Array[CardDefinition] = _deck_definitions(run.deck.cards)
	if kind == "register":
		var upgrades: Array[UpgradeDefinition] = run.upgrades.duplicate()
		upgrades.append(found as UpgradeDefinition)
		return _register_value(current, upgrades) - _register_value(current, run.upgrades)
	var redraws: int = _redraws_with(run.upgrades)
	var deck: Array[CardDefinition] = []
	if kind == "upgrade":
		deck = current.duplicate()
		var table: Array[ItemUpgradeDefinition] = run.balance.machine.item_upgrades
		for target: CardInstance in ItemUpgrades.targets(
			table, run.deck, found as CardDefinition, rarity
		):
			deck[run.deck.cards.find(target)] = ItemUpgrades.tier_step(
				table, target.definition, ItemUpgrades.step_count(rarity)
			)
	else:
		deck = _kept_deck(run, usage)
		deck.append(found as CardDefinition)
	return (
		_sample_value(deck, run.upgrades, redraws, _visit_seed)
		- _sample_value(current, run.upgrades, redraws, _visit_seed)
	)


## The machine's prizes by id: the stock's products, the coupon pools, the item upgrade chains'
## products and the register pool.
func _content(run: RunState) -> Dictionary[String, Resource]:
	var content: Dictionary[String, Resource] = {}
	var cards: Array[CardDefinition] = run.stock.cards + run.balance.coupon_pool
	cards.append_array(run.balance.first_offer_pool)
	if run.balance.machine != null:
		for chain: ItemUpgradeDefinition in run.balance.machine.item_upgrades:
			cards.append(chain.product)
	for card: CardDefinition in cards:
		content[String(card.id)] = card
	for upgrade: UpgradeDefinition in run.balance.upgrade_pool:
		content[String(upgrade.id)] = upgrade
	return content


## The index of the NEW ITEMS or COUPONS prize to take, or -1 to bin.
func _pick_card(
	run: RunState, usage: Dictionary[CardDefinition, int], prizes: Array[MachinePrize]
) -> int:
	var offer: Array[CardDefinition] = []
	for prize: MachinePrize in prizes:
		offer.append(prize.card)
	var choice: CardDefinition = null
	if _strategy == "random":
		choice = offer[_rng.randi_range(0, offer.size() - 1)]
	elif _strategy != "skip":
		for id: StringName in _favoured:
			for card: CardDefinition in offer:
				if choice == null and card.id == id:
					choice = card
		if (
			choice == null
			and _target != null
			and still_building(_target, _deck_definitions(run.deck.cards))
		):
			choice = _build_card(run, usage, offer)
		if choice == null:
			choice = _greedy_card(run, usage, offer, true)
	return offer.find(choice) if choice != null else -1


## For "build:id": whether the deck's measure is still under the build's aim (min_count +
## BUILD_MARGIN), so the strategy drafts towards it.
static func still_building(build: BuildDefinition, deck: Array[CardDefinition]) -> bool:
	return build.count(deck) < build.min_count + BUILD_MARGIN


## For "build:id" while the measure is at most min_count + BUILD_MARGIN: the indices of the deck
## cards whose loss would lower the measure, which the strategy keeps at the deck limit. Once
## the measure is over that, none.
static func kept_for_build(build: BuildDefinition, deck: Array[CardDefinition]) -> Array[int]:
	var kept: Array[int] = []
	var measure: int = build.count(deck)
	if measure > build.min_count + BUILD_MARGIN:
		return kept
	for index: int in range(deck.size()):
		var without: Array[CardDefinition] = deck.duplicate()
		without.remove_at(index)
		if build.count(without) < measure:
			kept.append(index)
	return kept


## For "build:id": whether the best offered upgrade listing the build is taken over the best
## offered upgrade, as greedy values them.
static func prefers_listed(listed_value: float, best_value: float) -> bool:
	return listed_value >= best_value * LISTED_UPGRADE_SHARE


## For "build:id": the offered card that raises the build's measure most (the best of those as
## greedy judges them), or null when none raises it.
func _build_card(
	run: RunState, usage: Dictionary[CardDefinition, int], offer: Array[CardDefinition]
) -> CardDefinition:
	var candidates: Array[CardDefinition] = raising_cards(_target, _kept_deck(run, usage), offer)
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
	var sample_seed: int = _visit_seed
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


## The index of the register to take (REGISTER and STAMP DAY; STAMP DAY's always greedily).
func _pick_upgrade(run: RunState, prizes: Array[MachinePrize]) -> int:
	var offer: Array[UpgradeDefinition] = []
	for prize: MachinePrize in prizes:
		offer.append(prize.upgrade)
	var choice: UpgradeDefinition = offer[0]
	var stamp_day: bool = run.machine.current_visit().kind == MachineVisit.Kind.STAMP_DAY
	if _strategy == "random" and not stamp_day:
		choice = offer[_rng.randi_range(0, offer.size() - 1)]
	else:
		var fitting: Array[UpgradeDefinition] = []
		if _target != null:
			fitting = upgrades_listing(_target, offer)
		var deck: Array[CardDefinition] = _deck_definitions(run.deck.cards)
		var best_value: float = -1.0
		var best_fitting: UpgradeDefinition = null
		var best_fitting_value: float = -1.0
		for upgrade: UpgradeDefinition in offer:
			var upgrades: Array[UpgradeDefinition] = run.upgrades.duplicate()
			upgrades.append(upgrade)
			var value: float = _register_value(deck, upgrades)
			if value > best_value:
				best_value = value
				choice = upgrade
			if fitting.has(upgrade) and value > best_fitting_value:
				best_fitting_value = value
				best_fitting = upgrade
		if best_fitting != null and prefers_listed(best_fitting_value, best_value):
			choice = best_fitting
	return offer.find(choice)


## The index of the item upgrade to take: at random by "random", else the one whose upgraded
## deck has the highest mean best total.
func _pick_item_upgrade(run: RunState, prizes: Array[MachinePrize]) -> int:
	if _strategy == "random":
		return _rng.randi_range(0, prizes.size() - 1)
	var sample_seed: int = _visit_seed
	var redraws: int = _redraws_with(run.upgrades)
	var best_index: int = 0
	var best_value: float = -1.0
	for index: int in range(prizes.size()):
		var preview: MachinePreview = run.machine.preview(run, index)
		var deck: Array[CardDefinition] = _deck_definitions(run.deck.cards)
		for step: int in range(preview.targets.size()):
			deck[run.deck.cards.find(preview.targets[step])] = preview.to_cards[step]
		var value: float = _sample_value(deck, run.upgrades, redraws, sample_seed)
		if value > best_value:
			best_value = value
			best_index = index
	return best_index


## A deck's value with these registers, as a register pick judges it: its mean best total on
## the visit's sample hands, with the registers' redraws, against the quota it has to reach
## (Big basket's quota raise costs as much as it adds).
func _register_value(deck: Array[CardDefinition], upgrades: Array[UpgradeDefinition]) -> float:
	var value: float = _sample_value(deck, upgrades, _redraws_with(upgrades), _visit_seed)
	return value * 100.0 / (100.0 + _quota_percent(upgrades))


## Mean total of `_samples` hands drawn from these cards, each played as a shift is (the
## strategy's row player, redraws of the unused baskets included). Kept for the visit
## (`_values`): the same deck, registers, redraws and seed always give the same value.
func _sample_value(
	deck: Array[CardDefinition], upgrades: Array[UpgradeDefinition], redraws: int, sample_seed: int
) -> float:
	var climb: bool = _sensible or _choosing
	var key: String = "%s%d/%d/" % ["c" if climb else "x", sample_seed, redraws]
	# Every register, rules or not: they set the row limits too.
	for upgrade: UpgradeDefinition in upgrades:
		key += "%d," % upgrade.get_instance_id()
	key += "/"
	for card: CardDefinition in deck:
		key += "%d," % card.get_instance_id()
	if _values.has(key):
		return _values[key]
	var value: float = _sampled(deck, upgrades, redraws, sample_seed, climb)
	_values[key] = value
	return value


## `climb`: play the sensible player's rows (SimHillClimb), else the exact best rows.
func _sampled(
	deck: Array[CardDefinition],
	upgrades: Array[UpgradeDefinition],
	redraws: int,
	sample_seed: int,
	climb: bool
) -> float:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = sample_seed
	var cards: Array[CardInstance] = []
	for index: int in range(deck.size()):
		cards.append(CardInstance.new(deck[index], index + 1))
	var limits: ShiftLimits = ShiftLimits.for_shift(_balance, upgrades, 0)
	var no_row: Array[CardInstance] = []
	var no_inspections: Array[InspectionDefinition] = []
	var total: int = 0
	for _sample: int in range(_samples):
		var pile: Array[CardInstance] = cards.duplicate()
		shuffle(rng, pile)
		var hand: Array[CardInstance] = []
		while hand.size() < _balance.hand_size and not pile.is_empty():
			hand.append(pile.pop_back())
		var best: SimHandBest = _play_row(hand, upgrades, no_inspections, limits, no_row, climb)
		var size: int = maxi(_balance.basket_size, 1)
		for _redraw: int in range(redraws):
			var by_place: Array[CardInstance] = _off_row(hand, best.row)
			var basket: int = _basket_pick(by_place)
			if basket < 0 or pile.is_empty():
				break
			for place: int in range(basket * size, mini((basket + 1) * size, hand.size())):
				if by_place[place] != null and not pile.is_empty():
					hand[place] = pile.pop_back()
			best = _play_row(hand, upgrades, no_inspections, limits, best.row, climb)
		total += best.score
	return float(total) / float(_samples)


## The deck card the run's rows used least; ties go to the lower base value, then to the
## card earlier in the deck. A "build:id" strategy keeps the cards whose loss lowers its
## measure while the measure is at most min_count + BUILD_MARGIN (when every card is kept, it
## lets go of the least used of all).
func _least_used(run: RunState, usage: Dictionary[CardDefinition, int]) -> CardInstance:
	var least: CardInstance = _least_used_of(run.deck.cards, usage, _protected(run.deck.cards))
	if least == null:
		var none: Array[CardInstance] = []
		least = _least_used_of(run.deck.cards, usage, none)
	return least


## For "build:id": the deck cards kept_for_build keeps. Otherwise none.
func _protected(cards: Array[CardInstance]) -> Array[CardInstance]:
	var kept: Array[CardInstance] = []
	if _target != null:
		for index: int in kept_for_build(_target, _deck_definitions(cards)):
			kept.append(cards[index])
	return kept


static func _least_used_of(
	cards: Array[CardInstance], usage: Dictionary[CardDefinition, int], kept: Array[CardInstance]
) -> CardInstance:
	var least: CardInstance = null
	for card: CardInstance in cards:
		if kept.has(card):
			continue
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


static func _ids(cards: Array[CardInstance]) -> Array[String]:
	var ids: Array[String] = []
	for card: CardInstance in cards:
		ids.append(String(card.definition.id))
	return ids


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
