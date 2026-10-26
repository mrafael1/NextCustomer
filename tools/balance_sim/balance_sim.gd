class_name BalanceSim
extends SceneTree
## The balance simulator's command line (plan section 8). Run it with tools/balance_sim.sh,
## which splits the work over several processes and passes the other arguments on:
##   --runs=N          runs per strategy (per collection state and strategy with --list-gate)
##                     (default 500)
##   --seed=N          run i of each strategy uses seed + i (default 1)
##   --strategy=A,B    greedy, random, skip, favour:id+id or build:id (default greedy), each
##                     playing the best rows, or with "@sensible" (e.g. greedy@sensible) the
##                     rows of a sensible but not optimal player (SimHillClimb); see SimPlayer
##   --quotas=A,B,...  the quotas instead of the balance data's: one per shift, or one for every
##                     shift. --quotas=0 never loses a shift; no simulator choice reads the
##                     quota, so these runs are the runs of any quota curve, each cut at its
##                     first failed shift (tools/quota_fit.py fits curves to their --records)
##   --samples=N       sample hands per greedy pick (default 6)
##   --deck=PATH       starting deck (default the starter deck, data/decks/starter.tres); a
##                     recipe deck (DeckDefinition.is_recipe) is dealt for each run from its
##                     stock and seed, as the game deals it (StartingDeck, v0.49; its coupon
##                     from the coupon pool since v0.51)
##   --random-start    start each run from the game's recipe deck (RANDOM_START_DECK) instead
##                     of the fixed starter deck; not with --deck
##   --balance=PATH    balance data (default the live balance data)
##   --builds=DIR      the build files (default res://data/builds); see SimBuilds
##   --profile=PATH    stock the runs from this profile save (its unlocked items, run count and
##                     last list), as the game would for its next run (default a new profile)
##   --collection=full stock the runs from the full collection: every capsule item unlocked,
##                     no new arrivals (SimCollection); not with --profile
##   --list=A+B        the shopping list (aisle ids) when the stock needs one; with --profile it
##                     replaces the profile's last list
##   --list-gate       the list gate (full build plan section 8): play the fresh profile and
##                     every state SimCollection.gate_states makes, and report each one's win
##                     rate against the fresh profile's, the 40% bar and the key-card offer
##                     chance; not with --profile, --collection or --list, and it needs the
##                     greedy or greedy@sensible strategy (the 40% bar, a warning since #42,
##                     is a share of its won runs)
##   --offer-samples=N unused since #77 (the key-card offer chance is read from the machine's
##                     exact odds); kept so older command lines still run (default 1000)
##   --orphan-samples=N hands per capsule item for the orphan check (full build plan 7.2), 0 to
##                     leave it out (default 30)
##   --duel-samples=N  hands for the coupon comparison, 0 to leave it out (default 200)
##   --chains=N        also play N chained profiles per strategy (SimChain, decided with the user
##                     in #41): each starts fresh and plays run after run, its coins buying
##                     capsules, to measure the runs to 30 unlocks (default 0: none)
##   --chain-runs=N    the most runs a chain plays (default 60)
##   --out=PATH        also write the report as JSON
##   --records=PATH    also write every run record (per scenario key) as JSON, with the quota
##                     and coin data a curve fit needs (tools/quota_fit.py)
##   --max-minutes=N   stop after N minutes and report the runs played so far (default 15; 0: no
##                     limit). The time is shared out between the phases (each collection
##                     state's runs with each strategy, the coupon duel, the orphan check;
##                     SimTimeLimit), and every process keeps to it, so the report still covers
##                     each of them; its first line says how many runs it got through. A list
##                     gate plays many states: give it more time
##   --cache=DIR       where the search cache is kept between runs, or "none" (default
##                     reports/balance_sim_cache). The file is named by a fingerprint of core/,
##                     the deck, cards (every card any stock or the orphan check can hold),
##                     upgrades and inspections in play and the row limits, so a change to any
##                     of them starts a new cache; quotas, pools, inspected shifts, lists and
##                     strategies don't. Hands are cached by card ids, and the fingerprint covers
##                     every card file those ids can name, so different card sets never share
##                     an entry. The row limits a shift's upgrades and inspections set
##                     (ShiftLimits) are part of each hand's key.
## Every report also has, per strategy, the runs by main build with the 40% bar (SimBuilds,
## SimSummary) and the coins per run (CoinPayout), the key-card offer chance per build and the
## orphan check (SimOrphans). With --list-gate, only the fresh profile's runs get the full
## tables; each gate state gets one line (SimListGate), and --out has all of them.
## Process modes (set by the wrapper):
##   --shard=I/N --raw=PATH  play only runs, duel samples and orphan samples whose index % N ==
##                           I, and write them to PATH (and the cache entries found to
##                           PATH.cache) instead of a report
##   --merge=PATH,PATH       read shard files, add their cache entries to the cache and print
##                           the report
##   --cache-name            print the cache file this simulation reads ("cache-file=" and its
##                           absolute path, or nothing after "=" with --cache=none) and quit
##   --cache-file=PATH       read the cache from PATH instead of fingerprinting the source (the
##                           wrapper's template runners: an exported pack holds no source text)
## The wrapper runs the shards on one of Godot's export templates with an exported pack
## (BalanceSim is the pack's main loop): the debug template by default, the release template
## with --runner=release (faster, but with no GDScript runtime errors), or the editor binary
## with --runner=editor. All give the same records.
## With neither, one process plays everything and prints the report.

## The options that define the simulation; every shard of one report must agree on them.
const SIMULATION_DEFAULTS: Dictionary[String, String] = {
	"runs": "500",
	"seed": "1",
	"strategy": "greedy",
	"samples": "6",
	"deck": "res://data/decks/starter.tres",
	"balance": "res://data/balance/balance.tres",
	"builds": "res://data/builds",
	"profile": "",
	"collection": "",
	"list": "",
	"list-gate": "false",
	"random-start": "false",
	"offer-samples": "1000",
	"orphan-samples": "30",
	"duel-samples": "200",
	"quotas": "",
	"chains": "0",
	"chain-runs": "60",
}
const PROCESS_DEFAULTS: Dictionary[String, String] = {
	"out": "",
	"records": "",
	"shard": "0/1",
	"raw": "",
	"merge": "",
	"cache": "res://reports/balance_sim_cache",
	"max-minutes": "15",
	"cache-file": "",
	"cache-name": "false",
}
const NUMBER_OPTIONS: Array[String] = [
	"runs",
	"seed",
	"samples",
	"duel-samples",
	"max-minutes",
	"offer-samples",
	"orphan-samples",
	"chains",
	"chain-runs",
]
## Chain i's run j uses seed + CHAIN_SEED_STEP * (i + 1) + j, apart from the single runs' seeds.
const CHAIN_SEED_STEP := 100000
## Options given without a value (--list-gate): they read "true".
const FLAG_OPTIONS: Array[String] = ["list-gate", "cache-name", "random-start"]
## The game's starting deck (a recipe, v0.49; since v0.63 the one with starter packs, #107),
## played with --random-start.
const RANDOM_START_DECK := "res://data/decks/pack_starter.tres"

var _options: Dictionary[String, String] = {}
var _starter: DeckDefinition
var _balance: BalanceDefinition
var _builds: SimBuilds
## The fair-deal check's quota (StartingDeck, v0.54): the balance data's shift 1 quota, kept
## when --quotas plays others, so every run is dealt as the game deals it.
var _deal_quota: int = -1
## The collection states played: the given one, or the fresh profile then the gate's states.
var _states: Array[SimCollection] = []
## Per scenario key (Scenario), its runs in run order.
var _records: Dictionary[String, Array] = {}
## Per strategy, its chains (SimChain) in chain order.
var _chains: Dictionary[String, Array] = {}
var _duel: SimCouponDuel
var _orphans: SimOrphans
var _rows_scored: int = 0
## Rows the sensible players scored (SimHillClimb), counted in _rows_scored.
var _rows_climbed: int = 0
var _cache_hits: int = 0
## Whether the time limit stopped a process (any shard's, for a merge) before all its runs.
var _timed_out: bool = false


## One collection state played with one strategy.
class Scenario:
	extends RefCounted
	var key: String = ""
	var strategy: String = ""
	var state: SimCollection


func _initialize() -> void:
	quit(_print_cache_name() if OS.get_cmdline_user_args().has("--cache-name") else _run())


## --cache-name: prints the cache file (absolute) the options give, for the wrapper.
func _print_cache_name() -> int:
	if not _parse_options():
		return 1
	print("cache-file=" + ProjectSettings.globalize_path(_cache_file()))
	return 0


## The deck the coupon duel plays: the starting deck, or for a recipe the
## deal of the first run's seed from a new profile's stock.
## A recipe with starter packs (#107): its first offer's first pack.
func _reference_deck() -> DeckDefinition:
	var stock: RunStock = RunStock.starting(_balance)
	var stream: RandomNumberGenerator = EventLogService.derived_stream(
		int(_options["seed"]), EventLogService.STARTING_DECK_STREAM
	)
	if _starter.starter_packs.is_empty():
		return StartingDeck.deal(_starter, stock, _balance, stream, _deal_quota)
	var offer: StartOffer = StartingDeck.deal_offer(
		_starter, stock, _balance, stream, false, _deal_quota
	)
	return StartingDeck.with_pack(_starter, offer.default_pack(), offer.shared)


func _run() -> int:
	var started: int = Time.get_ticks_msec()
	if not _parse_options():
		return 1
	_duel = SimCouponDuel.new(_reference_deck(), _balance, int(_options["seed"]))
	_orphans = SimOrphans.new(_balance, int(_options["orphan-samples"]), int(_options["seed"]))
	var search: SimRowSearch = SimRowSearch.new(_balance)
	var cache_file: String = _cache_file()
	if not cache_file.is_empty() and FileAccess.file_exists(cache_file):
		search.load_cache(cache_file)
	if not _options["merge"].is_empty():
		if not _merge(_options["merge"].split(",", false), search):
			return 1
	else:
		var shard: PackedStringArray = _options["shard"].split("/")
		_simulate(int(shard[0]), int(shard[1]), search)
		if not _options["raw"].is_empty():
			if not cache_file.is_empty():
				search.save_cache(_options["raw"] + ".cache", true)
			return _write_raw()
	if not cache_file.is_empty():
		_save_cache(search, cache_file)
	var seconds: float = (Time.get_ticks_msec() - started) / 1000.0
	var summaries: Array[SimSummary] = []
	for scenario: Scenario in _scenarios():
		var summary: SimSummary = SimSummary.new(scenario.strategy, _balance.quotas, scenario.key)
		for record: SimRunRecord in _records[scenario.key]:
			summary.add(record)
		summaries.append(summary)
	print("")
	print(_report(summaries, seconds))
	if not _options["records"].is_empty() and _write_records() != 0:
		return 1
	if not _options["out"].is_empty():
		return _write_json(summaries, seconds)
	return 0


func _parse_options() -> bool:
	_options = SIMULATION_DEFAULTS.duplicate()
	_options.merge(PROCESS_DEFAULTS)
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
		if parts.size() == 1 and FLAG_OPTIONS.has(parts[0]):
			parts.append("true")
		if not argument.begins_with("--") or parts.size() != 2 or not _options.has(parts[0]):
			push_error("balance_sim: unknown argument %s (see balance_sim.gd)" % argument)
			return false
		_options[parts[0]] = parts[1]
	for key: String in NUMBER_OPTIONS:
		if not _options[key].is_valid_int() or int(_options[key]) < 0:
			push_error("balance_sim: --%s needs a whole number, got %s" % [key, _options[key]])
			return false
	var shard: PackedStringArray = _options["shard"].split("/")
	if (
		shard.size() != 2
		or not shard[0].is_valid_int()
		or not shard[1].is_valid_int()
		or int(shard[0]) < 0
		or int(shard[0]) >= int(shard[1])
	):
		push_error("balance_sim: --shard needs I/N with 0 <= I < N, got %s" % _options["shard"])
		return false
	if not _load_data():
		return false
	_builds = SimBuilds.new(SimBuilds.load_folder(_options["builds"]))
	for strategy: String in _strategies():
		var base: String = strategy.trim_suffix(SimPlayer.SENSIBLE_SUFFIX)
		var unknown_build: bool = (
			base.begins_with("build:") and _builds.find(base.trim_prefix("build:")) == null
		)
		if not SimPlayer.is_known_strategy(strategy) or unknown_build:
			push_error("balance_sim: unknown strategy %s" % strategy)
			return false
	return _override_quotas(_options["quotas"]) and _make_states()


## Plays with these quotas (--quotas) instead of the balance data's, on a copy of the balance
## (none given: the balance data's).
func _override_quotas(text: String) -> bool:
	if text.is_empty():
		return true
	var quotas: PackedInt32Array = PackedInt32Array()
	for part: String in text.split(",", false):
		if not part.is_valid_int() or int(part) < 0:
			push_error("balance_sim: --quotas needs whole numbers, got %s" % text)
			return false
		quotas.append(int(part))
	if quotas.size() == 1:
		var value: int = quotas[0]
		quotas.resize(_balance.quotas.size())
		quotas.fill(value)
	if quotas.size() != _balance.quotas.size():
		push_error(
			"balance_sim: --quotas needs 1 or %d values, got %s" % [_balance.quotas.size(), text]
		)
		return false
	var starting: Array[UpgradeDefinition] = []
	if _starter.starting_upgrade != null:
		starting.append(_starter.starting_upgrade)
	_deal_quota = ShiftLimits.for_shift(_balance, starting, 0).quota
	_balance = _balance.duplicate()
	_balance.quotas = quotas
	return true


## The collection states to play (SimCollection): the list gate's, or the one the options give.
func _make_states() -> bool:
	var problem: String = _collection_option_problem()
	if not problem.is_empty():
		push_error("balance_sim: " + problem)
		return false
	var state: SimCollection = SimCollection.fresh()
	if _is_gate():
		_states = [state]
		_states.append_array(SimCollection.gate_states(_balance))
		return true
	var list: Array[StringName] = []
	for id: String in _options["list"].split("+", false):
		list.append(StringName(id))
	if _options["collection"] == "full":
		state = SimCollection.full(_balance, list)
	elif not _options["profile"].is_empty():
		var profile: ProfileState = _load_profile(_options["profile"])
		if profile == null:
			push_error(
				"balance_sim: %s is not a profile save this version reads" % _options["profile"]
			)
			return false
		state = SimCollection.from_profile(profile, _balance, list)
	else:
		state.listed = list
	problem = state.problem(_balance)
	if not problem.is_empty():
		push_error("balance_sim: " + problem)
		return false
	_states = [state]
	return true


## Loads the starting deck (--deck, or the game's recipe deck with --random-start) and the
## balance data; false, with an error, when an option is wrong or a file doesn't load.
func _load_data() -> bool:
	var problem: String = random_start_problem(_options)
	if problem.is_empty():
		var random_start: bool = _options["random-start"] == "true"
		_starter = load(RANDOM_START_DECK if random_start else _options["deck"]) as DeckDefinition
		_balance = load(_options["balance"]) as BalanceDefinition
		if _starter == null or _balance == null:
			problem = "couldn't load the deck or the balance data"
	if not problem.is_empty():
		push_error("balance_sim: " + problem)
		return false
	return true


## What is wrong with --random-start in `options` (the parsed options), or "": it takes no
## value, and it plays the game's recipe deck, so it refuses a --deck.
static func random_start_problem(options: Dictionary[String, String]) -> String:
	if not options["random-start"] in ["true", "false"]:
		return "--random-start takes no value"
	if options["random-start"] == "true" and options["deck"] != SIMULATION_DEFAULTS["deck"]:
		return "--random-start plays the game's recipe deck: no --deck"
	return ""


## What is wrong with the collection options, or "".
func _collection_option_problem() -> String:
	if not _options["list-gate"] in ["true", "false"]:
		return "--list-gate takes no value"
	var given: String = _options["profile"] + _options["collection"] + _options["list"]
	if _is_gate() and not given.is_empty():
		return "--list-gate makes its own states: no --profile, --collection, --list"
	if _is_gate() and not Array(_strategies()).any(SimSummary.is_bar_strategy):
		return (
			"--list-gate needs the %s or %s%s strategy (the 40%% bar is a share of its won runs)"
			% [SimSummary.BAR_STRATEGY, SimSummary.BAR_STRATEGY, SimPlayer.SENSIBLE_SUFFIX]
		)
	if not _options["collection"] in ["", "full"]:
		return "--collection takes full, got %s" % _options["collection"]
	if not _options["profile"].is_empty() and not _options["collection"].is_empty():
		return "give --profile or --collection, not both"
	return ""


static func _load_profile(path: String) -> ProfileState:
	if not FileAccess.file_exists(path):
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return ProfileState.from_dictionary(data) if data is Dictionary else null


func _strategies() -> PackedStringArray:
	return _options["strategy"].split(",", false)


## Every (collection state, strategy) played, states first. Outside the list gate a scenario's
## key is its strategy, as before; in the gate it is "<state> · <strategy>".
func _scenarios() -> Array[Scenario]:
	var scenarios: Array[Scenario] = []
	for state: SimCollection in _states:
		for strategy: String in _strategies():
			var scenario: Scenario = Scenario.new()
			scenario.state = state
			scenario.strategy = strategy
			scenario.key = strategy if _states.size() == 1 else "%s · %s" % [state.label, strategy]
			scenarios.append(scenario)
	return scenarios


## Plays this process's share: runs, duel samples and orphan samples whose index % shards ==
## shard.
func _simulate(shard: int, shards: int, search: SimRowSearch) -> void:
	var runs: int = int(_options["runs"])
	var share: int = ceili(float(runs - shard) / shards)
	var duel_samples: int = int(_options["duel-samples"])
	var orphan_samples: int = _orphans.sample_total()
	var scenarios: Array[Scenario] = _scenarios()
	var chains: int = int(_options["chains"])
	var limit: SimTimeLimit = SimTimeLimit.new(
		int(_options["max-minutes"]),
		(
			scenarios.size()
			+ (_strategies().size() if chains > 0 else 0)
			+ (1 if duel_samples > 0 else 0)
			+ (1 if orphan_samples > 0 else 0)
		),
		Time.get_ticks_msec()
	)
	var stocks: Dictionary[SimCollection, RunStock] = {}
	for scenario: Scenario in scenarios:
		print("Simulating runs: %s (shard %d/%d)..." % [scenario.key, shard, shards])
		if not stocks.has(scenario.state):
			stocks[scenario.state] = scenario.state.stock(_balance)
		var player: SimPlayer = SimPlayer.new(
			_starter,
			_balance,
			search,
			scenario.strategy,
			int(_options["samples"]),
			stocks[scenario.state],
			_builds
		)
		player.deal_quota = _deal_quota
		var records: Array[SimRunRecord] = []
		_begin_phase(limit, search)
		for index: int in range(shard, runs, shards):
			var record: SimRunRecord = null
			if not limit.is_phase_over(Time.get_ticks_msec()):
				record = player.play(int(_options["seed"]) + index)
			if record == null:
				limit.hit()
				print("  time limit: stopped at %d/%d runs" % [records.size(), share])
				break
			records.append(record)
			_print_progress(records.size(), share)
		_records[scenario.key] = records
		_rows_climbed += player.rows_climbed()
	for strategy: String in _strategies() if chains > 0 else PackedStringArray():
		print("Playing chained profiles: %s (shard %d/%d)..." % [strategy, shard, shards])
		_begin_phase(limit, search)
		_chains[strategy] = _play_chains(strategy, shard, shards, search, limit)
	if duel_samples > 0:
		print("Comparing coupons (shard %d/%d)..." % [shard, shards])
		_begin_phase(limit, search)
		for index: int in range(shard, duel_samples, shards):
			if limit.is_phase_over(Time.get_ticks_msec()):
				break
			_duel.run_sample(search, index)
			if search.stopped:
				limit.hit()
				break
	if orphan_samples > 0:
		print("Checking capsule items for orphans (shard %d/%d)..." % [shard, shards])
		_begin_phase(limit, search)
		for index: int in range(shard, orphan_samples, shards):
			if limit.is_phase_over(Time.get_ticks_msec()):
				break
			_orphans.run_sample(search, index)
			if search.stopped:
				limit.hit()
				break
	_timed_out = limit.was_hit()
	_rows_scored = search.rows_scored + _rows_climbed
	_cache_hits = search.cache_hits


## This process's share of a strategy's chains (index % shards == shard), each from a fresh
## profile; a chain the time limit stops is dropped.
func _play_chains(
	strategy: String, shard: int, shards: int, search: SimRowSearch, limit: SimTimeLimit
) -> Array[SimChain]:
	var played: Array[SimChain] = []
	var make_player: Callable = func(stock: RunStock) -> SimPlayer:
		var player: SimPlayer = SimPlayer.new(
			_starter, _balance, search, strategy, int(_options["samples"]), stock, _builds
		)
		player.deal_quota = _deal_quota
		return player
	for index: int in range(shard, int(_options["chains"]), shards):
		if limit.is_phase_over(Time.get_ticks_msec()):
			limit.hit()
			break
		var chain_seed: int = int(_options["seed"]) + CHAIN_SEED_STEP * (index + 1)
		var chain: SimChain = SimChain.new(_balance, make_player, chain_seed)
		chain.play(chain_seed, int(_options["chain-runs"]))
		if chain.stopped:
			limit.hit()
			break
		played.append(chain)
		print("  chain %d: %d runs" % [index, chain.coins.size()])
	return played


## Starts a phase of the time limit: the search stops at its end.
static func _begin_phase(limit: SimTimeLimit, search: SimRowSearch) -> void:
	limit.begin_phase(Time.get_ticks_msec())
	search.stop_at_msec = limit.phase_end_msec()
	search.stopped = false


func _print_progress(done: int, total: int) -> void:
	var step: int = maxi(floori(total / 10.0), 1)
	if done % step == 0 or done == total:
		print("  %d/%d runs" % [done, total])


func _write_raw() -> int:
	var records: Dictionary[String, Array] = {}
	for key: String in _records:
		records[key] = _records[key].map(
			func(record: SimRunRecord) -> Dictionary: return record.to_dictionary()
		)
	var chains: Dictionary[String, Array] = {}
	for strategy: String in _chains:
		chains[strategy] = _chains[strategy].map(
			func(chain: SimChain) -> Dictionary: return chain.to_dictionary()
		)
	var data: Dictionary = {
		"options": _simulation_options(),
		"records": records,
		"chains": chains,
		"duel": _duel.samples_to_array(),
		"orphans": _orphans.samples_to_array(),
		"rows_scored": _rows_scored,
		"cache_hits": _cache_hits,
		"timed_out": _timed_out,
	}
	return _write_file(_options["raw"], JSON.stringify(data))


func _merge(paths: PackedStringArray, search: SimRowSearch) -> bool:
	var runs: Dictionary[String, Array] = {}
	var scenarios: Array[Scenario] = _scenarios()
	for scenario: Scenario in scenarios:
		runs[scenario.key] = []
	for path: String in paths:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary or data.get("options") != _simulation_options():
			push_error("balance_sim: %s is missing or is from other simulation options" % path)
			return false
		for scenario: Scenario in scenarios:
			for entry: Dictionary in data["records"][scenario.key]:
				runs[scenario.key].append(SimRunRecord.from_dictionary(entry))
		for strategy: String in data.get("chains", {}):
			if not _chains.has(strategy):
				_chains[strategy] = []
			for entry: Dictionary in data["chains"][strategy]:
				_chains[strategy].append(SimChain.from_dictionary(entry))
		_duel.add_samples(data["duel"])
		_orphans.add_samples(data["orphans"])
		if FileAccess.file_exists(path + ".cache"):
			search.load_cache(path + ".cache")
		_rows_scored += int(data["rows_scored"])
		_cache_hits += int(data["cache_hits"])
		_timed_out = _timed_out or bool(data.get("timed_out", false))
	for scenario: Scenario in scenarios:
		var records: Array = runs[scenario.key]
		records.sort_custom(
			func(a: SimRunRecord, b: SimRunRecord) -> bool: return a.run_seed < b.run_seed
		)
		_records[scenario.key] = records
	return true


## The cache file for this simulation, or "" with --cache=none. Its name is a fingerprint of
## everything a cached best row depends on: core's scripts, the search script, the files of the
## deck, the cards (every card a stock or the orphan check can hold: the deck's, every aisle's
## base and capsule cards, the coupon pools and the machine's item upgrade chains with their BIG
## and GOLDEN cards), upgrades (the deck's starting upgrade too) and inspections in play and the
## row limits.
func _cache_file() -> String:
	if _options["cache"] == "none":
		return ""
	if not _options["cache-file"].is_empty():
		return _options["cache-file"]
	var context: Dictionary = {}
	context["core"] = _files_text("res://core")
	context["search"] = FileAccess.get_file_as_string("res://tools/balance_sim/sim_row_search.gd")
	var cards: Array[CardDefinition] = []
	cards.append_array(_starter.cards + _starter.core_cards + _balance.staples)
	for aisle: AisleDefinition in _balance.aisles:
		cards.append_array(aisle.base_cards + aisle.capsule_cards)
	cards.append_array(_balance.coupon_pool)
	cards.append_array(_balance.first_offer_pool)
	# The machine's item upgrades (#77): their BIG and GOLDEN cards can be in a hand. The rest of
	# machine.tres (odds, rarity lists, shifts) never changes a best row, so it isn't hashed.
	if _balance.machine != null:
		for chain: ItemUpgradeDefinition in _balance.machine.item_upgrades:
			context[chain.resource_path] = FileAccess.get_file_as_string(chain.resource_path)
			cards.append_array(chain.tiers())
	for card: CardDefinition in cards:
		context[card.resource_path] = FileAccess.get_file_as_string(card.resource_path)
	context["deck"] = FileAccess.get_file_as_string(_starter.resource_path)
	var upgrades: Array[UpgradeDefinition] = _balance.upgrade_pool.duplicate()
	if _starter.starting_upgrade != null:
		upgrades.append(_starter.starting_upgrade)
	for upgrade: UpgradeDefinition in upgrades:
		# Every level above it too (#108: the machine offers level-ups).
		var level: UpgradeDefinition = upgrade
		while level != null:
			context[level.resource_path] = FileAccess.get_file_as_string(level.resource_path)
			level = level.next_level
	for inspection: InspectionDefinition in _balance.inspection_pool:
		context[inspection.resource_path] = FileAccess.get_file_as_string(inspection.resource_path)
	context["limits"] = [_balance.slot_count]
	var keys: Array = context.keys()
	keys.sort()
	var text: String = ""
	for key: Variant in keys:
		text += "%s\n%s\n" % [key, context[key]]
	return "%s/%s.cache" % [_options["cache"], text.sha256_text().left(16)]


## The text of every script under `folder`, in path order.
static func _files_text(folder: String) -> String:
	var text: String = ""
	var files: PackedStringArray = DirAccess.get_files_at(folder)
	files.sort()
	for file: String in files:
		if file.ends_with(".gd"):
			text += file + "\n" + FileAccess.get_file_as_string(folder.path_join(file))
	var folders: PackedStringArray = DirAccess.get_directories_at(folder)
	folders.sort()
	for subfolder: String in folders:
		text += _files_text(folder.path_join(subfolder))
	return text


## Writes the whole cache and removes caches of other fingerprints (stale data).
func _save_cache(search: SimRowSearch, cache_file: String) -> void:
	var folder: String = cache_file.get_base_dir()
	DirAccess.make_dir_recursive_absolute(folder)
	for file: String in DirAccess.get_files_at(folder):
		if file.ends_with(".cache") and folder.path_join(file) != cache_file:
			DirAccess.remove_absolute(folder.path_join(file))
	if not search.save_cache(cache_file, false):
		push_error("balance_sim: couldn't write the cache %s" % cache_file)


func _simulation_options() -> Dictionary:
	var result: Dictionary = {}
	for key: String in SIMULATION_DEFAULTS:
		result[key] = _options[key]
	return result


func _report(summaries: Array[SimSummary], seconds: float) -> String:
	var report: PackedStringArray = PackedStringArray()
	var build_label: String = ProjectSettings.get_setting("next_customer/build_label", "?")
	report.append(
		(
			"Next Customer balance simulator · build %s · deck %s · %s"
			% [build_label, _starter.id, _runs_text(summaries)]
		)
	)
	var row_text: String = "%d slots" % _balance.slot_count
	var redraw_text: String = (
		"%d redraws of a basket (%d items)" % [_balance.base_redraws, _balance.basket_size]
	)
	report.append(
		(
			"Quotas %s · hand %d · %s · %s · seed %s · %s samples per greedy pick"
			% [
				Array(_balance.quotas),
				_balance.hand_size,
				redraw_text,
				row_text,
				_options["seed"],
				_options["samples"]
			]
		)
	)
	var inspection_ids: Array = RunEvents.inspection_ids(_balance.inspection_pool)
	report.append(
		(
			"Inspections on shifts %s, drawn from %s"
			% [Array(_balance.inspection_shifts), inspection_ids]
		)
	)
	var gate: bool = _is_gate()
	if gate:
		report.append(
			(
				"List gate: the fresh profile and %d gate state%s (SimCollection.gate_states)"
				% [_states.size() - 1, "" if _states.size() == 2 else "s"]
			)
		)
	else:
		report.append(_stock_text(_states[0]))
	# In the gate, only the fresh profile's runs get the full tables; the states get a line each.
	var shown: Array[SimSummary] = summaries.slice(0, _strategies().size()) if gate else summaries
	for summary: SimSummary in shown:
		report.append("")
		report.append(summary.format())
	var chances: Array[Dictionary] = _key_offer_chances()
	if gate:
		report.append("")
		report.append(SimListGate.format(_gate_verdicts(summaries, chances), shown))
	report.append("")
	report.append(_key_offer_text(chances))
	if shown.size() > 1 and not gate:
		report.append("")
		report.append("== Strategies compared ==")
		report.append("Strategy                  Win rate  Mean shifts passed")
		for summary: SimSummary in shown:
			var shifts_passed: int = 0
			for count: int in summary.passed:
				shifts_passed += count
			report.append(
				(
					"%-25s %7.1f%%  %18.2f"
					% [
						summary.strategy,
						100.0 * summary.win_rate(),
						float(shifts_passed) / maxi(summary.runs, 1)
					]
				)
			)
	if not _chains.is_empty():
		report.append("")
		report.append(SimChainSummary.format(_chains, SimChain.capsule_count(_balance)))
	if _duel.sample_count() > 0:
		report.append("")
		report.append(_duel.format())
	if int(_options["orphan-samples"]) > 0:
		report.append("")
		report.append(_orphans.format())
	report.append("")
	var cost: String = "%d rows scored · %d cache hits" % [_rows_scored, _cache_hits]
	# A merge's own time says nothing about the simulation; the wrapper prints the total.
	if _options["merge"].is_empty():
		cost += " · %.1f s" % seconds
	report.append(cost)
	return "\n".join(report)


func _is_gate() -> bool:
	return _options["list-gate"] == "true"


func _stock_text(state: SimCollection) -> String:
	var stock: RunStock = state.stock(_balance)
	var arrivals: Array = stock.new_arrivals.map(
		func(card: CardDefinition) -> String: return String(card.id)
	)
	return (
		"Stock: %s · %d cards · aisles %s · new arrivals %s"
		% [
			state.label,
			stock.cards.size(),
			", ".join(stock.aisle_ids.map(func(id: StringName) -> String: return String(id))),
			", ".join(arrivals) if not arrivals.is_empty() else "none"
		]
	)


## The key-card offer chance (SimBuilds) of each state played, and of the fresh profile when it
## isn't one of them: [{"state": label, "chances": {build: chance}}, ...], the fresh profile
## first.
func _key_offer_chances() -> Array[Dictionary]:
	var states: Array[SimCollection] = _states.duplicate()
	if states[0].label != SimCollection.fresh().label:
		states.push_front(SimCollection.fresh())
	var result: Array[Dictionary] = []
	for state: SimCollection in states:
		var chances: Dictionary[String, float] = _builds.key_offer_chance(
			_balance, state.stock(_balance), int(_options["offer-samples"]), int(_options["seed"])
		)
		result.append({"state": state.label, "chances": chances})
	return result


func _key_offer_text(chances: Array[Dictionary]) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("== Key-card offer chance (later machine draws showing a build's key card) ==")
	if _builds.builds.is_empty():
		lines.append("No builds.")
		return "\n".join(lines)
	var header: String = "%-34s" % "Stock"
	for id: String in _builds.ids():
		header += " %19s" % id
	lines.append(header)
	# In the gate, the fresh profile and the full-collection states (the ones it checks).
	for index: int in range(chances.size()):
		if _is_gate() and index > 0 and _states[index].group != SimListGate.KEY_CARD_GROUP:
			continue
		var line: String = "%-34s" % chances[index]["state"]
		for id: String in _builds.ids():
			line += " %18.1f%%" % (100.0 * chances[index]["chances"][id])
		lines.append(line)
	lines.append("Exact odds: a later NEW ITEMS draw (its products and its coupon) at odds level 0")
	return "\n".join(lines)


## The gate's verdict for every state but the fresh profile (state 0).
func _gate_verdicts(summaries: Array[SimSummary], chances: Array[Dictionary]) -> Array[Dictionary]:
	var count: int = _strategies().size()
	var fresh: Array[SimSummary] = summaries.slice(0, count)
	var verdicts: Array[Dictionary] = []
	for index: int in range(1, _states.size()):
		var state_summaries: Array[SimSummary] = summaries.slice(index * count, (index + 1) * count)
		var state_chances: Dictionary[String, float] = chances[index]["chances"]
		var fresh_chances: Dictionary[String, float] = chances[0]["chances"]
		verdicts.append(
			SimListGate.check(_states[index], state_summaries, fresh, state_chances, fresh_chances)
		)
	return verdicts


## The runs per strategy: --runs, or, when the time limit stopped them, how many were played of it.
func _runs_text(summaries: Array[SimSummary]) -> String:
	if not _timed_out:
		return "%s runs per strategy" % _options["runs"]
	var played: int = int(_options["runs"])
	for summary: SimSummary in summaries:
		played = mini(played, summary.runs)
	return (
		"%d of %s runs per strategy (time limit of %s min reached)"
		% [played, _options["runs"], _options["max-minutes"]]
	)


func _write_json(summaries: Array[SimSummary], seconds: float) -> int:
	var strategies: Array = summaries.map(
		func(summary: SimSummary) -> Dictionary: return summary.to_dictionary()
	)
	var chances: Array[Dictionary] = _key_offer_chances()
	var data: Dictionary = {
		"build_label": ProjectSettings.get_setting("next_customer/build_label", ""),
		"options": _simulation_options(),
		"quotas": Array(_balance.quotas),
		"stock": _states[0].stock(_balance).to_dictionary(),
		"stock_label": _states[0].label,
		"strategies": strategies,
		"key_card_chances": chances,
		"list_gate": _gate_verdicts(summaries, chances) if _is_gate() else [],
		"chains": SimChainSummary.to_dictionary(_chains, SimChain.capsule_count(_balance)),
		"coupon_duel": _duel.to_dictionary(),
		"orphans": _orphans.to_dictionary(),
		"rows_scored": _rows_scored,
		"seconds": seconds,
		"timed_out": _timed_out,
	}
	var status: int = _write_file(_options["out"], JSON.stringify(data, "\t"))
	if status == 0:
		print("Report written to %s" % _options["out"])
	return status


## Every run record by scenario key, with the quota and coin data tools/quota_fit.py needs to
## replay the runs under another quota curve: the quotas played and the coin amounts
## (CoinPayout).
func _write_records() -> int:
	var scenarios: Dictionary[String, Array] = {}
	for key: String in _records:
		scenarios[key] = _records[key].map(
			func(record: SimRunRecord) -> Dictionary: return record.to_dictionary()
		)
	var data: Dictionary = {
		"build_label": ProjectSettings.get_setting("next_customer/build_label", ""),
		"options": _simulation_options(),
		"quotas": Array(_balance.quotas),
		"coins_by_shifts_passed": Array(_balance.coins_by_shifts_passed),
		"overtime_coin_euros": _balance.overtime_coin_euros,
		"overtime_coin_max": _balance.overtime_coin_max,
		"scenarios": scenarios,
	}
	var status: int = _write_file(_options["records"], JSON.stringify(data))
	if status == 0:
		print("Run records written to %s" % _options["records"])
	return status


func _write_file(path: String, text: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("balance_sim: couldn't write %s" % path)
		return 1
	file.store_string(text)
	file.close()
	return 0
