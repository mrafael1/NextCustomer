extends SceneTree
## The balance simulator's command line (plan section 8). Run it with tools/balance_sim.sh,
## which splits the work over several processes and passes the other arguments on:
##   --runs=N          runs per strategy (default 500)
##   --seed=N          run i of each strategy uses seed + i (default 1)
##   --strategy=A,B    greedy, random, skip or favour:id+id (default greedy); see SimPlayer
##   --samples=N       sample hands per greedy pick (default 6)
##   --deck=PATH       starting deck (default the starter deck)
##   --balance=PATH    balance data (default the live balance data)
##   --duel-samples=N  hands for the coupon-slot comparison, 0 to leave it out (default 200)
##   --out=PATH        also write the report as JSON
##   --max-minutes=N   stop after N minutes and report the runs played so far (default 15; 0: no
##                     limit). The time is shared out between the strategies and the coupon
##                     duel (SimTimeLimit), and every process keeps to it, so the report still
##                     covers each of them; its first line says how many runs it got through
##   --cache=DIR       where the search cache is kept between runs, or "none" (default
##                     reports/balance_sim_cache). The file is named by a fingerprint of core/,
##                     the deck, cards, upgrades and inspections in play and the row limits, so a
##                     change to any of them starts a new cache; quotas, pools, inspected
##                     shifts and strategies don't.
## Process modes (set by the wrapper):
##   --shard=I/N --raw=PATH  play only runs and duel samples whose index % N == I, and write
##                           them to PATH (and the cache entries found to PATH.cache) instead
##                           of a report
##   --merge=PATH,PATH       read shard files, add their cache entries to the cache and print
##                           the report
## With neither, one process plays everything and prints the report.

## The options that define the simulation; every shard of one report must agree on them.
const SIMULATION_DEFAULTS: Dictionary[String, String] = {
	"runs": "500",
	"seed": "1",
	"strategy": "greedy",
	"samples": "6",
	"deck": "res://data/decks/starter.tres",
	"balance": "res://data/balance/balance.tres",
	"duel-samples": "200",
}
const PROCESS_DEFAULTS: Dictionary[String, String] = {
	"out": "",
	"shard": "0/1",
	"raw": "",
	"merge": "",
	"cache": "res://reports/balance_sim_cache",
	"max-minutes": "15",
}
const NUMBER_OPTIONS: Array[String] = ["runs", "seed", "samples", "duel-samples", "max-minutes"]

var _options: Dictionary[String, String] = {}
var _starter: DeckDefinition
var _balance: BalanceDefinition
## Per strategy, its runs in run order.
var _records: Dictionary[String, Array] = {}
var _duel: SimCouponDuel
var _rows_scored: int = 0
var _cache_hits: int = 0
## Whether the time limit stopped a process (any shard's, for a merge) before all its runs.
var _timed_out: bool = false


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	var started: int = Time.get_ticks_msec()
	if not _parse_options():
		return 1
	_duel = SimCouponDuel.new(_starter, _balance, int(_options["seed"]))
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
	for strategy: String in _strategies():
		var summary: SimSummary = SimSummary.new(strategy, _balance.quotas)
		for record: SimRunRecord in _records[strategy]:
			summary.add(record)
		summaries.append(summary)
	print("")
	print(_report(summaries, seconds))
	if not _options["out"].is_empty():
		return _write_json(summaries, seconds)
	return 0


func _parse_options() -> bool:
	_options = SIMULATION_DEFAULTS.duplicate()
	_options.merge(PROCESS_DEFAULTS)
	for argument: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = argument.trim_prefix("--").split("=", true, 1)
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
	for strategy: String in _strategies():
		if not SimPlayer.is_known_strategy(strategy):
			push_error("balance_sim: unknown strategy %s" % strategy)
			return false
	_starter = load(_options["deck"]) as DeckDefinition
	_balance = load(_options["balance"]) as BalanceDefinition
	if _starter == null or _balance == null:
		push_error("balance_sim: couldn't load the deck or the balance data")
		return false
	return true


func _strategies() -> PackedStringArray:
	return _options["strategy"].split(",", false)


## Plays this process's share: runs and duel samples whose index % shards == shard.
func _simulate(shard: int, shards: int, search: SimRowSearch) -> void:
	var runs: int = int(_options["runs"])
	var share: int = ceili(float(runs - shard) / shards)
	var duel_samples: int = int(_options["duel-samples"])
	var limit: SimTimeLimit = SimTimeLimit.new(
		int(_options["max-minutes"]),
		_strategies().size() + (1 if duel_samples > 0 else 0),
		Time.get_ticks_msec()
	)
	for strategy: String in _strategies():
		print("Simulating runs with strategy %s (shard %d/%d)..." % [strategy, shard, shards])
		var player: SimPlayer = SimPlayer.new(
			_starter, _balance, search, strategy, int(_options["samples"])
		)
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
		_records[strategy] = records
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
	_timed_out = limit.was_hit()
	_rows_scored = search.rows_scored
	_cache_hits = search.cache_hits


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
	for strategy: String in _records:
		records[strategy] = _records[strategy].map(
			func(record: SimRunRecord) -> Dictionary: return record.to_dictionary()
		)
	var data: Dictionary = {
		"options": _simulation_options(),
		"records": records,
		"duel": _duel.samples_to_array(),
		"rows_scored": _rows_scored,
		"cache_hits": _cache_hits,
		"timed_out": _timed_out,
	}
	return _write_file(_options["raw"], JSON.stringify(data))


func _merge(paths: PackedStringArray, search: SimRowSearch) -> bool:
	var runs: Dictionary[String, Array] = {}
	for strategy: String in _strategies():
		runs[strategy] = []
	for path: String in paths:
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not data is Dictionary or data.get("options") != _simulation_options():
			push_error("balance_sim: %s is missing or is from other simulation options" % path)
			return false
		for strategy: String in _strategies():
			for entry: Dictionary in data["records"][strategy]:
				runs[strategy].append(SimRunRecord.from_dictionary(entry))
		_duel.add_samples(data["duel"])
		if FileAccess.file_exists(path + ".cache"):
			search.load_cache(path + ".cache")
		_rows_scored += int(data["rows_scored"])
		_cache_hits += int(data["cache_hits"])
		_timed_out = _timed_out or bool(data.get("timed_out", false))
	for strategy: String in _strategies():
		var records: Array = runs[strategy]
		records.sort_custom(
			func(a: SimRunRecord, b: SimRunRecord) -> bool: return a.run_seed < b.run_seed
		)
		_records[strategy] = records
	return true


## The cache file for this simulation, or "" with --cache=none. Its name is a fingerprint of
## everything a cached best row depends on: core's scripts, the search script, the files of the
## deck, the cards, upgrades (the deck's starting upgrade too) and inspections in play and the
## row limits.
func _cache_file() -> String:
	if _options["cache"] == "none":
		return ""
	var context: Dictionary = {}
	context["core"] = _files_text("res://core")
	context["search"] = FileAccess.get_file_as_string("res://tools/balance_sim/sim_row_search.gd")
	var cards: Array[CardDefinition] = []
	cards.append_array(_starter.cards)
	cards.append_array(RunStock.starting(_starter, _balance).cards)
	cards.append_array(_balance.first_offer_pool)
	for card: CardDefinition in cards:
		context[card.resource_path] = FileAccess.get_file_as_string(card.resource_path)
	context["deck"] = FileAccess.get_file_as_string(_starter.resource_path)
	var upgrades: Array[UpgradeDefinition] = _balance.upgrade_pool.duplicate()
	if _starter.starting_upgrade != null:
		upgrades.append(_starter.starting_upgrade)
	for upgrade: UpgradeDefinition in upgrades:
		context[upgrade.resource_path] = FileAccess.get_file_as_string(upgrade.resource_path)
	for inspection: InspectionDefinition in _balance.inspection_pool:
		context[inspection.resource_path] = FileAccess.get_file_as_string(inspection.resource_path)
	context["limits"] = [_balance.slot_count, _balance.coupon_slot_count]
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
	var row_text: String = (
		"%d product slots + %d coupon slot" % [_balance.slot_count, _balance.coupon_slot_count]
	)
	report.append(
		(
			"Quotas %s · hand %d · redraw up to %d · %s · seed %s · %s samples per greedy pick"
			% [
				Array(_balance.quotas),
				_balance.hand_size,
				_balance.redraw_limit,
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
	for summary: SimSummary in summaries:
		report.append("")
		report.append(summary.format())
	if summaries.size() > 1:
		report.append("")
		report.append("== Strategies compared ==")
		report.append("Strategy                  Win rate  Mean shifts passed")
		for summary: SimSummary in summaries:
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
	if _duel.sample_count() > 0:
		report.append("")
		report.append(_duel.format())
	report.append("")
	var cost: String = "%d rows scored · %d cache hits" % [_rows_scored, _cache_hits]
	# A merge's own time says nothing about the simulation; the wrapper prints the total.
	if _options["merge"].is_empty():
		cost += " · %.1f s" % seconds
	report.append(cost)
	return "\n".join(report)


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
	var data: Dictionary = {
		"build_label": ProjectSettings.get_setting("next_customer/build_label", ""),
		"options": _simulation_options(),
		"quotas": Array(_balance.quotas),
		"strategies": strategies,
		"coupon_duel": _duel.to_dictionary(),
		"rows_scored": _rows_scored,
		"seconds": seconds,
		"timed_out": _timed_out,
	}
	var status: int = _write_file(_options["out"], JSON.stringify(data, "\t"))
	if status == 0:
		print("Report written to %s" % _options["out"])
	return status


func _write_file(path: String, text: String) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("balance_sim: couldn't write %s" % path)
		return 1
	file.store_string(text)
	file.close()
	return 0
