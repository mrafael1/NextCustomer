class_name SimSummary
extends RefCounted
## The simulated runs of one strategy, added up for the report (plan section 8): win rate,
## per-shift pass rates and best-score percentiles, how often each card is in the best row and
## needed there, and the impulse-rack, reward and upgrade picks.

## Percentiles reported per shift.
const PERCENTILES: Array[int] = [10, 25, 50, 75, 90]
## Hands a card must appear in before "never needed" counts as dominated.
const DOMINATED_MIN_HANDS := 30

var strategy: String = ""
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


func _init(strategy_name: String, run_quotas: PackedInt32Array) -> void:
	strategy = strategy_name
	quotas = run_quotas
	reached.resize(quotas.size())
	passed.resize(quotas.size())
	raised.resize(quotas.size())
	for _shift: int in range(quotas.size()):
		scores.append(PackedInt32Array())


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


func win_rate() -> float:
	return float(wins) / float(runs) if runs > 0 else 0.0


## Nearest-rank percentile of a shift's best totals; -1 when no run played the shift.
func percentile(shift_index: int, percent: int) -> int:
	var sorted: PackedInt32Array = scores[shift_index].duplicate()
	if sorted.is_empty():
		return -1
	sorted.sort()
	var rank: int = ceili(percent / 100.0 * sorted.size())
	return sorted[clampi(rank - 1, 0, sorted.size() - 1)]


## Cards seen in at least DOMINATED_MIN_HANDS hands whose removal never lowered a best total.
func dominated() -> Array[String]:
	var result: Array[String] = []
	for id: String in _card_ids():
		if drawn[id] >= DOMINATED_MIN_HANDS and needed.get(id, 0) == 0:
			result.append(id)
	return result


func format() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("== Strategy: %s ==" % strategy)
	lines.append(
		(
			"Win rate %s (%d/%d) · %.1f redraws per run"
			% [_percent(wins, runs), wins, runs, float(redraws) / maxf(runs, 1)]
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
				_percent(raised[index], reached[index]),
				reached[index],
				_percent(passed[index], reached[index]),
			]
		)
		for percent: int in PERCENTILES:
			line += "%5s" % _score_text(percentile(index, percent))
		line += "%6s" % _score_text(percentile(index, 100))
		lines.append(line)
	lines.append("")
	lines.append("Card               Hands  In best row  Needed")
	for id: String in _card_ids():
		lines.append(
			(
				"%-17s %6d  %11s  %6s"
				% [
					id,
					drawn[id],
					_percent(in_best.get(id, 0), drawn[id]),
					_percent(needed.get(id, 0), drawn[id])
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
				% [id, upgrades_taken[id], _percent(upgrade_wins.get(id, 0), upgrades_taken[id])]
			)
		)
	lines.append(
		"Upgrades taken: " + (", ".join(upgrade_texts) if not upgrade_texts.is_empty() else "none")
	)
	return "\n".join(lines)


func to_dictionary() -> Dictionary:
	var shifts: Array[Dictionary] = []
	for index: int in range(quotas.size()):
		var percentiles: Dictionary[String, int] = {}
		for percent: int in PERCENTILES + [100]:
			percentiles["p%d" % percent] = percentile(index, percent)
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


static func _percent(part: int, whole: int) -> String:
	if whole == 0:
		return "-"
	return "%.1f%%" % (100.0 * part / whole)


static func _score_text(score: int) -> String:
	return "-" if score < 0 else str(score)
