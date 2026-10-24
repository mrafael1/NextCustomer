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
## - spends every coin at the end of each run, one capsule per capsule_price coins. It picks a
##   machine with items left at random (players choose; a random pick stands for a mix of
##   them), and the draw inside is the game's (CapsuleDraw: random without duplicates, the
##   aisle's key item first, plan 7.1);
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

var _balance: BalanceDefinition
var _make_player: Callable
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _unlocked: Dictionary[StringName, int] = {}
var _last_list: Array[StringName] = []
var _listable_before: Array[StringName] = []


## `make_player` makes the run's SimPlayer from its RunStock: func(stock: RunStock) -> SimPlayer.
func _init(balance: BalanceDefinition, make_player: Callable, chain_seed: int) -> void:
	_balance = balance
	_make_player = make_player
	_rng.seed = hash("balance_sim_chain:%d" % chain_seed)


## Plays the chain's runs, run seed `first_seed` + the run index.
func play(first_seed: int, max_runs: int) -> void:
	var capsules: int = capsule_count(_balance)
	for run_index: int in range(max_runs):
		var stock: RunStock = RunStock.build(_balance, _list(), _unlocked, run_index)
		var player: SimPlayer = _make_player.call(stock)
		var record: SimRunRecord = player.play(first_seed + run_index)
		if record == null:
			stopped = true
			return
		coins.append(record.coins)
		won.append(record.won)
		var capsules_bought: int = floori(float(record.coins) / maxi(_balance.capsule_price, 1))
		for _capsule: int in range(capsules_bought):
			_draw_capsule(run_index)
		unlocked_after.append(_unlocked.size())
		if _unlocked.size() >= capsules:
			runs_to_all = run_index + 1
			return


static func capsule_count(balance: BalanceDefinition) -> int:
	return CapsuleDraw.capsule_count(balance)


func to_dictionary() -> Dictionary:
	return {
		"coins": Array(coins),
		"won": won,
		"unlocked_after": Array(unlocked_after),
		"runs_to_all": runs_to_all,
	}


static func from_dictionary(data: Dictionary) -> SimChain:
	var chain: SimChain = SimChain.new(null, Callable(), 0)
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
	var newly_ids: Array[StringName] = []
	for aisle: AisleDefinition in newly:
		newly_ids.append(aisle.id)
	# The game's list default (RunStock.prefill_list, #63), with this chain's tracking.
	var list: Array[StringName] = RunStock.prefill_list(_balance, _unlocked, _last_list, newly_ids)
	if list.is_empty():
		return []
	_last_list = list
	return _last_list.duplicate()


## One capsule from a machine with items left, picked at random; the draw inside is the game's
## (CapsuleDraw: the key item first, then at random), on this chain's stream.
func _draw_capsule(run_index: int) -> void:
	var machines: Array[AisleDefinition] = []
	for aisle: AisleDefinition in _balance.aisles:
		if not CapsuleDraw.is_empty(aisle, _unlocked):
			machines.append(aisle)
	if machines.is_empty():
		return
	var machine: AisleDefinition = machines[_rng.randi_range(0, machines.size() - 1)]
	var card: CardDefinition = CapsuleDraw.draw(machine, _unlocked, _rng)
	_unlocked[card.id] = run_index
