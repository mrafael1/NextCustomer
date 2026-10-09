class_name SimSummary
extends RefCounted
## The simulated runs of one strategy, added up for the report (plan section 8): win rate,
## per-shift pass rates and best-score percentiles, how often each card is in the best row and
## needed there, the impulse-rack, reward and upgrade picks, the runs by main build (SimBuilds)
## and the coins per run (CoinPayout).

## Percentiles reported per shift.
const PERCENTILES: Array[int] = [10, 25, 50, 75, 90]
## Hands a card must appear in before "never needed" counts as dominated.
const DOMINATED_MIN_HANDS := 30
## The 40% bar (full build plan section 3, decided with the user in #40): no main build may be
## more than this share of the greedy strategy's won runs.
const BUILD_BAR := 0.4
const BAR_STRATEGY := "greedy"
## The capsule unlocks a collection holds (full build plan 7.1): runs to unlock them all.
const UNLOCKS := 30
## The coin percentile reported as "a great run" (decided with the user in #40).
const GREAT_RUN_PERCENTILE := 90

var strategy: String = ""
## What the report calls these runs: the strategy, or "<collection state> · <strategy>".
var title: String = ""
var quotas: PackedInt32Array = PackedInt32Array()
var runs: int = 0
var wins: int = 0
var redraws: int = 0
## Per shift (0-based): runs that played it, and its best totals.
var reached: PackedInt32Array = PackedInt32Array()
var passed: PackedInt32Array = PackedInt32Array()
## Per shift: runs that played it against a raised quota (Big basket). `quotas` are the base.
var raised: PackedInt32Array = PackedInt32Array()
var scores: Array[PackedInt32Array] = []
## Per shift: the exact best totals, and each played total as a share of its best in percent
## (100 when the best is 0). They differ from `scores` only for "@sensible" strategies.
var best_scores: Array[PackedInt32Array] = []
var best_shares: Array[PackedInt32Array] = []
var drawn: Dictionary[String, int] = {}
var in_best: Dictionary[String, int] = {}
var needed: Dictionary[String, int] = {}
## Reward cards taken (by id), and skipped rewards.
var picks: Dictionary[String, int] = {}
var skips: int = 0
## Impulse-rack products taken (by id), and skipped racks.
var impulse_picks: Dictionary[String, int] = {}
var impulse_skips: int = 0
## Upgrades taken, and how many of those runs were won.
var upgrades_taken: Dictionary[String, int] = {}
var upgrade_wins: Dictionary[String, int] = {}
## Runs and won runs by main build.
var build_runs: Dictionary[String, int] = {}
var build_wins: Dictionary[String, int] = {}
## Each run's coins, in the order added.
var coins: PackedInt32Array = PackedInt32Array()
## Runs lost on shift 2 (one shift passed), and how many of them paid the overtime coin from
## shift 1's margin (full build plan 7.1 expects this to be rare).
var lost_on_shift_2: int = 0
var lost_on_shift_2_overtime: int = 0


func _init(strategy_name: String, run_quotas: PackedInt32Array, summary_title: String = "") -> void:
	strategy = strategy_name
	title = summary_title if not summary_title.is_empty() else strategy_name
	quotas = run_quotas
	reached.resize(quotas.size())
	passed.resize(quotas.size())
	raised.resize(quotas.size())
	for _shift: int in range(quotas.size()):
		scores.append(PackedInt32Array())
		best_scores.append(PackedInt32Array())
		best_shares.append(PackedInt32Array())


func add(record: SimRunRecord) -> void:
	runs += 1
	if record.won:
		wins += 1
	redraws += record.redraws
	if not record.impulse_pick.is_empty():
		impulse_picks[record.impulse_pick] = impulse_picks.get(record.impulse_pick, 0) + 1
	elif record.impulse_offered:
		impulse_skips += 1
	for entry: Dictionary in record.shifts:
		var index: int = entry["shift"] - 1
		reached[index] += 1
		scores[index].append(entry["total"])
		var best: int = entry.get("best", entry["total"])
		best_scores[index].append(best)
		best_shares[index].append(100 if best <= 0 else floori(100.0 * entry["total"] / best))
		if entry["passed"]:
			passed[index] += 1
		if int(entry["quota"]) > quotas[index]:
			raised[index] += 1
		var card: String = entry["card_picked"]
		if not card.is_empty():
			picks[card] = picks.get(card, 0) + 1
		if entry["reward_skipped"]:
			skips += 1
		var upgrade: String = entry["upgrade_taken"]
		if not upgrade.is_empty():
			upgrades_taken[upgrade] = upgrades_taken.get(upgrade, 0) + 1
			if record.won:
				upgrade_wins[upgrade] = upgrade_wins.get(upgrade, 0) + 1
	for id: String in record.drawn:
		drawn[id] = drawn.get(id, 0) + record.drawn[id]
	for id: String in record.in_best:
		in_best[id] = in_best.get(id, 0) + record.in_best[id]
	for id: String in record.needed:
		needed[id] = needed.get(id, 0) + record.needed[id]
	build_runs[record.main_build] = build_runs.get(record.main_build, 0) + 1
	if record.won:
		build_wins[record.main_build] = build_wins.get(record.main_build, 0) + 1
	coins.append(record.coins)
	if not record.won and record.shifts.size() == 2:
		lost_on_shift_2 += 1
		if record.overtime_coins > 0:
			lost_on_shift_2_overtime += 1


## A main build's share of the won runs.
func win_share(build: String) -> float:
	return float(build_wins.get(build, 0)) / float(wins) if wins > 0 else 0.0


## The main builds over the 40% bar (only the greedy strategy is held to it). Runs that fit no
## build aren't a build: they count only in the won runs every share is taken of.
func builds_over_bar() -> Array[String]:
	var over: Array[String] = []
	for build: String in _sorted_by_count(build_runs):
		if build != SimBuilds.NO_BUILD and win_share(build) > BUILD_BAR:
			over.append(build)
	return over


func coin_mean() -> float:
	var sum: int = 0
	for amount: int in coins:
		sum += amount
	return float(sum) / float(coins.size()) if not coins.is_empty() else 0.0


## Nearest-rank percentile of the coins per run; -1 with no runs.
func coin_percentile(percent: int) -> int:
	return nearest_rank(coins, percent)


## Runs to unlock the whole collection at this mean (30 ÷ mean coins); -1 when no run paid.
func runs_to_unlock_all() -> float:
	var mean: float = coin_mean()
	return float(UNLOCKS) / mean if mean > 0.0 else -1.0


## Per coin amount (0 to the most paid): how many runs paid it.
func coin_counts() -> PackedInt32Array:
	var most: int = 0
	for amount: int in coins:
		most = maxi(most, amount)
	var counts: PackedInt32Array = PackedInt32Array()
	counts.resize(most + 1 if not coins.is_empty() else 0)
	for amount: int in coins:
		counts[amount] += 1
	return counts


## Nearest-rank percentile of `values`; -1 when there are none.
static func nearest_rank(values: PackedInt32Array, percent: int) -> int:
	var sorted: PackedInt32Array = values.duplicate()
	if sorted.is_empty():
		return -1
	sorted.sort()
	var rank: int = ceili(percent / 100.0 * sorted.size())
	return sorted[clampi(rank - 1, 0, sorted.size() - 1)]


func win_rate() -> float:
	return float(wins) / float(runs) if runs > 0 else 0.0


## Nearest-rank percentile of a shift's best totals; -1 when no run played the shift.
func percentile(shift_index: int, percent: int) -> int:
	return nearest_rank(scores[shift_index], percent)


## Cards seen in at least DOMINATED_MIN_HANDS hands whose removal never lowered a best total.
func dominated() -> Array[String]:
	var result: Array[String] = []
	for id: String in _card_ids():
		if drawn[id] >= DOMINATED_MIN_HANDS and needed.get(id, 0) == 0:
			result.append(id)
	return result


func format() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("== Strategy: %s ==" % title)
	lines.append(
		(
			"Win rate %s (%d/%d) · %.1f redraws per run"
			% [percent_text(wins, runs), wins, runs, float(redraws) / maxf(runs, 1)]
		)
	)
	lines.append("")
	var header: String = "Shift  Quota  Raised  Played  Passed "
	for percent: int in PERCENTILES:
		header += "%5s" % ("p%d" % percent)
	lines.append(header + "   max")
	for index: int in range(quotas.size()):
		var line: String = (
			"%5d  %5d  %6s  %6d  %6s "
			% [
				index + 1,
				quotas[index],
				percent_text(raised[index], reached[index]),
				reached[index],
				percent_text(passed[index], reached[index]),
			]
		)
		for percent: int in PERCENTILES:
			line += "%5s" % _score_text(percentile(index, percent))
		line += "%6s" % _score_text(percentile(index, 100))
		lines.append(line)
	if strategy.ends_with(SimPlayer.SENSIBLE_SUFFIX):
		lines.append("")
		lines.append_array(_best_lines())
	lines.append("")
	lines.append("Card               Hands  In row  Needed")
	for id: String in _card_ids():
		lines.append(
			(
				"%-17s %6d  %6s  %6s"
				% [
					id,
					drawn[id],
					percent_text(in_best.get(id, 0), drawn[id]),
					percent_text(needed.get(id, 0), drawn[id])
				]
			)
		)
	var never: Array[String] = dominated()
	lines.append(
		(
			"Dominated (never needed in %d+ hands): %s"
			% [DOMINATED_MIN_HANDS, ", ".join(never) if not never.is_empty() else "none"]
		)
	)
	lines.append("")
	var impulse_texts: PackedStringArray = PackedStringArray()
	for id: String in _sorted_by_count(impulse_picks):
		impulse_texts.append("%s %d" % [id, impulse_picks[id]])
	impulse_texts.append("skipped %d" % impulse_skips)
	lines.append("Impulse rack picks: " + ", ".join(impulse_texts))
	var pick_texts: PackedStringArray = PackedStringArray()
	for id: String in _sorted_by_count(picks):
		pick_texts.append("%s %d" % [id, picks[id]])
	pick_texts.append("skipped %d" % skips)
	lines.append("Reward picks: " + ", ".join(pick_texts))
	var upgrade_texts: PackedStringArray = PackedStringArray()
	for id: String in _sorted_by_count(upgrades_taken):
		upgrade_texts.append(
			(
				"%s %d (won %s)"
				% [
					id,
					upgrades_taken[id],
					percent_text(upgrade_wins.get(id, 0), upgrades_taken[id])
				]
			)
		)
	lines.append(
		"Upgrades taken: " + (", ".join(upgrade_texts) if not upgrade_texts.is_empty() else "none")
	)
	lines.append("")
	lines.append_array(_build_lines())
	lines.append("")
	lines.append_array(_coin_lines())
	return "\n".join(lines)


## The exact best rows beside the sensible rows played (decided with the user, #41).
func _best_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Exact best rows of the same hands, and the rows played as a share of them")
	var header: String = "Shift  "
	for percent: int in PERCENTILES:
		header += "%5s" % ("p%d" % percent)
	lines.append(header + "   Share p10  p50  mean  At best")
	for index: int in range(quotas.size()):
		var line: String = "%5d  " % (index + 1)
		for percent: int in PERCENTILES:
			line += "%5s" % _score_text(nearest_rank(best_scores[index], percent))
		var shares: PackedInt32Array = best_shares[index]
		var at_best: int = 0
		var sum: int = 0
		for share: int in shares:
			sum += share
			if share >= 100:
				at_best += 1
		line += (
			"   %8s%% %3s%% %5s  %7s"
			% [
				_score_text(nearest_rank(shares, 10)),
				_score_text(nearest_rank(shares, 50)),
				"%.1f" % (float(sum) / shares.size()) if not shares.is_empty() else "-",
				percent_text(at_best, shares.size()),
			]
		)
		lines.append(line)
	return lines


func _build_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("Main build             Runs    Won  Win rate  Share of wins")
	for build: String in _sorted_by_count(build_runs):
		(
			lines
			. append(
				(
					"%-20s %6d %6d  %8s  %13s"
					% [
						build,
						build_runs[build],
						build_wins.get(build, 0),
						percent_text(build_wins.get(build, 0), build_runs[build]),
						percent_text(build_wins.get(build, 0), wins),
					]
				)
			)
		)
	if strategy == BAR_STRATEGY:
		var over: Array[String] = builds_over_bar()
		lines.append(
			(
				"40%% bar (no main build over %d%% of the won runs): %s"
				% [
					roundi(BUILD_BAR * 100),
					"pass" if over.is_empty() else "FAIL (%s)" % ", ".join(over)
				]
			)
		)
	return lines


func _coin_lines() -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	var counts: PackedInt32Array = coin_counts()
	var shares: PackedStringArray = PackedStringArray()
	for amount: int in range(counts.size()):
		shares.append("%d: %s" % [amount, percent_text(counts[amount], coins.size())])
	lines.append(
		(
			"Coins per run: mean %.2f · median %s · p%d %s (a great run) · %s"
			% [
				coin_mean(),
				_score_text(coin_percentile(50)),
				GREAT_RUN_PERCENTILE,
				_score_text(coin_percentile(GREAT_RUN_PERCENTILE)),
				", ".join(shares) if not shares.is_empty() else "no runs"
			]
		)
	)
	var runs_needed: float = runs_to_unlock_all()
	lines.append(
		(
			"Runs to %d unlocks (%d ÷ mean coins): %s"
			% [UNLOCKS, UNLOCKS, "%.1f" % runs_needed if runs_needed >= 0.0 else "-"]
		)
	)
	lines.append(
		(
			"Lost on shift 2: %d runs, %d paid the overtime coin from shift 1"
			% [lost_on_shift_2, lost_on_shift_2_overtime]
		)
	)
	return lines


## Each shift's "best_totals" are the percentiles of the totals played (the name predates the
## sensible rows); "exact_best_totals" are the exact best rows', the same for best rows.
func to_dictionary() -> Dictionary:
	var shifts: Array[Dictionary] = []
	for index: int in range(quotas.size()):
		var percentiles: Dictionary[String, int] = {}
		var best_percentiles: Dictionary[String, int] = {}
		for percent: int in PERCENTILES + [100]:
			percentiles["p%d" % percent] = percentile(index, percent)
			best_percentiles["p%d" % percent] = nearest_rank(best_scores[index], percent)
		(
			shifts
			. append(
				{
					"shift": index + 1,
					"quota": quotas[index],
					"raised_quota": raised[index],
					"played": reached[index],
					"passed": passed[index],
					"best_totals": percentiles,
					"exact_best_totals": best_percentiles,
					"share_of_best_p50": nearest_rank(best_shares[index], 50),
				}
			)
		)
	var cards: Dictionary[String, Dictionary] = {}
	for id: String in _card_ids():
		cards[id] = {
			"hands": drawn[id], "in_best_row": in_best.get(id, 0), "needed": needed.get(id, 0)
		}
	return {
		"strategy": strategy,
		"title": title,
		"runs": runs,
		"wins": wins,
		"win_rate": win_rate(),
		"redraws": redraws,
		"shifts": shifts,
		"cards": cards,
		"dominated": dominated(),
		"impulse_picks": impulse_picks,
		"impulse_skips": impulse_skips,
		"reward_picks": picks,
		"reward_skips": skips,
		"upgrades_taken": upgrades_taken,
		"upgrade_wins": upgrade_wins,
		"main_builds": build_runs,
		"main_build_wins": build_wins,
		"builds_over_bar": builds_over_bar() if strategy == BAR_STRATEGY else [],
		"coins":
		{
			"mean": coin_mean(),
			"median": coin_percentile(50),
			"great_run": coin_percentile(GREAT_RUN_PERCENTILE),
			"runs_by_amount": Array(coin_counts()),
			"runs_to_unlock_all": runs_to_unlock_all(),
			"lost_on_shift_2": lost_on_shift_2,
			"lost_on_shift_2_overtime_coin": lost_on_shift_2_overtime,
		},
	}


func _card_ids() -> Array[String]:
	var ids: Array[String] = []
	ids.assign(drawn.keys())
	ids.sort_custom(func(a: String, b: String) -> bool: return a < b)
	return ids


static func _sorted_by_count(counts: Dictionary[String, int]) -> Array[String]:
	var ids: Array[String] = []
	ids.assign(counts.keys())
	ids.sort_custom(
		func(a: String, b: String) -> bool:
			if counts[a] != counts[b]:
				return counts[a] > counts[b]
			return a < b
	)
	return ids


static func percent_text(part: int, whole: int) -> String:
	if whole == 0:
		return "-"
	return "%.1f%%" % (100.0 * part / whole)


static func _score_text(score: int) -> String:
	return "-" if score < 0 else str(score)
