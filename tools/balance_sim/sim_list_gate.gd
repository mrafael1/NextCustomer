class_name SimListGate
extends RefCounted
## The list gate's verdicts (full build plan section 8): every state SimCollection.gate_states
## makes is held against the fresh profile's runs. A state passes when, for every strategy
## played, its run win rate is within WIN_RATE_POINTS of the fresh profile's; when no main build
## is over the 40% bar in its greedy runs (SimSummary); and, for the full-collection states,
## when each build's key-card offer chance (SimBuilds) is at least KEY_CARD_SHARE of the fresh
## profile's. Passing the gate itself belongs to the balance passes (#42).

const WIN_RATE_POINTS := 5.0
const KEY_CARD_SHARE := 0.85
## The gate group whose states get the key-card check.
const KEY_CARD_GROUP := "full"


## One state's verdict. `summaries` and `fresh` hold the same strategies in the same order;
## `chances` and `fresh_chances` are key-card offer chances by build id.
static func check(
	state: SimCollection,
	summaries: Array[SimSummary],
	fresh: Array[SimSummary],
	chances: Dictionary[String, float],
	fresh_chances: Dictionary[String, float]
) -> Dictionary:
	var deltas: Dictionary[String, float] = {}
	var win_rates: Dictionary[String, float] = {}
	var runs: Dictionary[String, int] = {}
	var failures: Array[String] = []
	var over_bar: Array[String] = []
	for index: int in range(summaries.size()):
		var summary: SimSummary = summaries[index]
		# A strategy the time limit left without runs (here or in the fresh profile) has no win
		# rate to compare: the state can't pass on it.
		if summary.runs == 0 or fresh[index].runs == 0:
			failures.append("%s: no runs to compare (time limit)" % summary.strategy)
			continue
		var points: float = win_rate_points(summary, fresh[index])
		runs[summary.strategy] = summary.runs
		win_rates[summary.strategy] = summary.win_rate()
		deltas[summary.strategy] = points
		if absf(points) > WIN_RATE_POINTS:
			failures.append("%s win rate %+.1f points" % [summary.strategy, points])
		if summary.strategy == SimSummary.BAR_STRATEGY:
			over_bar = summary.builds_over_bar()
	if not over_bar.is_empty():
		failures.append("over the 40%% bar: %s" % ", ".join(over_bar))
	var ratios: Dictionary[String, float] = {}
	if state.group == KEY_CARD_GROUP:
		var short: Array[String] = []
		for build: String in fresh_chances:
			var ratio: float = 1.0
			if fresh_chances[build] > 0.0:
				ratio = chances.get(build, 0.0) / fresh_chances[build]
			ratios[build] = ratio
			if ratio < KEY_CARD_SHARE:
				short.append("%s %.0f%%" % [build, 100.0 * ratio])
		if not short.is_empty():
			failures.append(
				"key cards below %d%%: %s" % [roundi(100 * KEY_CARD_SHARE), ", ".join(short)]
			)
	return {
		"state": state.label,
		"group": state.group,
		"runs": runs,
		"win_rates": win_rates,
		"win_rate_points": deltas,
		"builds_over_bar": over_bar,
		"key_card_ratios": ratios,
		"failures": failures,
		"passed": failures.is_empty(),
	}


## The win-rate difference in points, from the whole-number counts, so an exact 5-point gap is
## exactly 5.0 either way (the gate's ±5 is inclusive). Both summaries need runs.
static func win_rate_points(summary: SimSummary, fresh: SimSummary) -> float:
	var difference: int = summary.wins * fresh.runs - fresh.wins * summary.runs
	return float(100 * difference) / float(summary.runs * fresh.runs)


## The gate's lines for the report, one per verdict, and the overall result.
static func format(verdicts: Array[Dictionary], fresh: Array[SimSummary]) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("== List gate (full build plan section 8) ==")
	var fresh_texts: PackedStringArray = PackedStringArray()
	for summary: SimSummary in fresh:
		fresh_texts.append(
			"%s %s" % [summary.strategy, SimSummary.percent_text(summary.wins, summary.runs)]
		)
	lines.append("Fresh profile win rates: " + ", ".join(fresh_texts))
	if verdicts.is_empty():
		lines.append("No gate states.")
		return "\n".join(lines)
	var failed: int = 0
	for verdict: Dictionary in verdicts:
		var rates: PackedStringArray = PackedStringArray()
		var points: Dictionary = verdict["win_rate_points"]
		for strategy: String in points:
			rates.append(
				(
					"%s %.1f%% (%+.1f, %d runs)"
					% [
						strategy,
						100.0 * verdict["win_rates"][strategy],
						points[strategy],
						verdict["runs"][strategy]
					]
				)
			)
		var result: String = "pass"
		if not verdict["passed"]:
			failed += 1
			result = "FAIL: " + "; ".join(verdict["failures"])
		lines.append("%s · %s · %s" % [verdict["state"], ", ".join(rates), result])
	lines.append(
		(
			"Gate: %s (%d of %d states pass)"
			% ["pass" if failed == 0 else "FAIL", verdicts.size() - failed, verdicts.size()]
		)
	)
	return "\n".join(lines)
