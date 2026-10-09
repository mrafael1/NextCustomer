class_name SimChain
extends RefCounted
## Chained runs for the balance simulator (decided with the user, #41; full build plan 7.1 and
## 8): one profile played run after run from a fresh one, its stock growing as its coins buy
## capsules, until the collection is complete or `max_runs` runs are played. It measures what
## the pacing target is about: about 30 unlocks in 25-40 runs.
##
## The profile is kept as the game keeps it: the unlocked items with the run index each came out
## at (so the end-cap's new arrivals ride the next runs, RunStock), the run count and the last
## list. The simulated player:
## - spends every coin at the end of each run, one capsule per coin. It picks a machine with
##   items left at random (players choose; a random pick stands for a mix of them), and the
##   draw inside is random without duplicates, the aisle's key item first (plan 7.1);
## - keeps its last list when the stock needs one. An aisle that just became listable joins the
##   list, in place of the listed aisle with the fewest items, and a list short of
##   run_aisle_picks aisles takes the listable aisles with the most items (ties by data order).
##   The first list is the plan's pre-fill: the newly listable aisle if there is one, otherwise
##   the base aisles with the most unlocked items.
## Its randomness comes from its own stream, seeded from the chain's index, so the run seeds and
## every run's own RNG stay as in a single run.

## Runs played, in order: coins paid, whether it was won, and the unlocks after it.
var coins: PackedInt32Array = PackedInt32Array()
var won: Array[bool] = []
var unlocked_after: PackedInt32Array = PackedInt32Array()
## The run (1-based) after which every capsule item was unlocked, or -1 within max_runs.
var runs_to_all: int = -1
## True when the time limit stopped a run partway (the chain is then dropped).
var stopped: bool = false

var _starter: DeckDefinition
var _balance: BalanceDefinition
var _make_player: Callable
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _unlocked: Dictionary[StringName, int] = {}
var _last_list: Array[StringName] = []
var _listable_before: Array[StringName] = []


## `make_player` makes the run's SimPlayer from its RunStock: func(stock: RunStock) -> SimPlayer.
func _init(
	starter: DeckDefinition, balance: BalanceDefinition, make_player: Callable, chain_seed: int
) -> void:
	_starter = starter
	_balance = balance
	_make_player = make_player
	_rng.seed = hash("balance_sim_chain:%d" % chain_seed)


## Plays the chain's runs, run seed `first_seed` + the run index.
func play(first_seed: int, max_runs: int) -> void:
	var capsules: int = capsule_count(_balance)
	for run_index: int in range(max_runs):
		var stock: RunStock = RunStock.build(_starter, _balance, _list(), _unlocked, run_index)
		var player: SimPlayer = _make_player.call(stock)
		var record: SimRunRecord = player.play(first_seed + run_index)
		if record == null:
			stopped = true
			return
		coins.append(record.coins)
		won.append(record.won)
		for _coin: int in range(record.coins):
			_draw_capsule(run_index)
		unlocked_after.append(_unlocked.size())
		if _unlocked.size() >= capsules:
			runs_to_all = run_index + 1
			return


static func capsule_count(balance: BalanceDefinition) -> int:
	var count: int = 0
	for aisle: AisleDefinition in balance.aisles:
		count += aisle.capsule_cards.size()
	return count


func to_dictionary() -> Dictionary:
	return {
		"coins": Array(coins),
		"won": won,
		"unlocked_after": Array(unlocked_after),
		"runs_to_all": runs_to_all,
	}


static func from_dictionary(data: Dictionary) -> SimChain:
	var chain: SimChain = SimChain.new(null, null, Callable(), 0)
	for amount: Variant in data["coins"]:
		chain.coins.append(int(amount))
	for result: Variant in data["won"]:
		chain.won.append(bool(result))
	for count: Variant in data["unlocked_after"]:
		chain.unlocked_after.append(int(count))
	chain.runs_to_all = int(data["runs_to_all"])
	return chain


## The list this run stocks ([] when the stock needs none).
func _list() -> Array[StringName]:
	var listable: Array[AisleDefinition] = RunStock.listable_aisles(_balance, _unlocked)
	var newly: Array[AisleDefinition] = listable.filter(
		func(aisle: AisleDefinition) -> bool: return not _listable_before.has(aisle.id)
	)
	_listable_before.assign(
		listable.map(func(aisle: AisleDefinition) -> StringName: return aisle.id)
	)
	if not RunStock.needs_list(_balance, _unlocked):
		return []
	var picks: int = _balance.run_aisle_picks
	var list: Array[AisleDefinition] = listable.filter(
		func(aisle: AisleDefinition) -> bool: return _last_list.has(aisle.id)
	)
	if _last_list.is_empty():
		# The plan's first pre-fill: base aisles only fill in after a newly listable one.
		newly = newly.filter(
			func(aisle: AisleDefinition) -> bool: return aisle.base_cards.is_empty()
		)
	for aisle: AisleDefinition in newly:
		if list.has(aisle):
			continue
		if list.size() >= picks:
			list.erase(_fewest_items(list))
		list.append(aisle)
	while list.size() < picks:
		var best: AisleDefinition = null
		for aisle: AisleDefinition in listable:
			if not list.has(aisle) and (best == null or _held(aisle) > _held(best)):
				best = aisle
		if best == null:
			break
		list.append(best)
	# In data order, as the stock lists aisles.
	_last_list.clear()
	for aisle: AisleDefinition in listable:
		if list.has(aisle):
			_last_list.append(aisle.id)
	return _last_list.duplicate()


## The listed aisle with the fewest items; ties go to the later one in data order.
func _fewest_items(list: Array[AisleDefinition]) -> AisleDefinition:
	var fewest: AisleDefinition = null
	for aisle: AisleDefinition in _balance.aisles:
		if list.has(aisle) and (fewest == null or _held(aisle) <= _held(fewest)):
			fewest = aisle
	return fewest


func _held(aisle: AisleDefinition) -> int:
	return RunStock.items(aisle, _unlocked).size()


## One capsule from a machine with items left: the key item first, then at random.
func _draw_capsule(run_index: int) -> void:
	var machines: Array[AisleDefinition] = []
	for aisle: AisleDefinition in _balance.aisles:
		if aisle.capsule_cards.any(
			func(item: CardDefinition) -> bool: return not _unlocked.has(item.id)
		):
			machines.append(aisle)
	if machines.is_empty():
		return
	var machine: AisleDefinition = machines[_rng.randi_range(0, machines.size() - 1)]
	var left: Array[CardDefinition] = machine.capsule_cards.filter(
		func(item: CardDefinition) -> bool: return not _unlocked.has(item.id)
	)
	var card: CardDefinition = left[0]
	if left.size() < machine.capsule_cards.size():
		card = left[_rng.randi_range(0, left.size() - 1)]
	_unlocked[card.id] = run_index
