class_name SimChainSummary
extends RefCounted
## The chained profiles' report (SimChain, decided with the user, #41): per strategy, the runs
## each profile took to unlock every capsule item (plan 7.1's target: about 30 unlocks in 25-40
## runs), the coins and wins over all of its runs, and the unlocks along the way.

## Runs at which the median unlock count is reported.
const MILESTONES: Array[int] = [10, 20, 30, 40]


static func format(chains: Dictionary[String, Array], capsules: int) -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("== Chained profiles: runs to unlock all %d capsule items ==" % capsules)
	for strategy: String in chains:
		var data: Dictionary = summary(chains[strategy])
		(
			lines
			. append(
				(
					"%s: %d profiles, %d runs · runs to all unlocks p10 %s, median %s, p90 %s"
					% [
						strategy,
						data["profiles"],
						data["runs"],
						_text(data["runs_to_all_p10"]),
						_text(data["runs_to_all_median"]),
						_text(data["runs_to_all_p90"]),
					]
				)
			)
		)
		var milestones: PackedStringArray = PackedStringArray()
		for index: int in range(MILESTONES.size()):
			milestones.append(
				(
					"%s after %d runs"
					% [_text(data["unlocks_at_milestones"][index]), MILESTONES[index]]
				)
			)
		(
			lines
			. append(
				(
					(
						"  %d not done within the run limit · mean coins %.2f a run · win rate %s"
						+ " · median unlocks: %s"
					)
					% [
						data["unfinished"],
						data["mean_coins"],
						SimSummary.percent_text(data["wins"], data["runs"]),
						", ".join(milestones),
					]
				)
			)
		)
	return "\n".join(lines)


static func to_dictionary(chains: Dictionary[String, Array], capsules: int) -> Dictionary:
	var result: Dictionary = {"capsules": capsules}
	for strategy: String in chains:
		result[strategy] = summary(chains[strategy])
	return result


## One strategy's chains added up. A profile that didn't unlock everything within the run limit
## counts as one run past it in the percentiles, so they never look faster than they were.
static func summary(chains: Array) -> Dictionary:
	var runs_to_all: PackedInt32Array = PackedInt32Array()
	var unfinished: int = 0
	var runs: int = 0
	var wins: int = 0
	var coins: int = 0
	var at_milestones: Array[PackedInt32Array] = []
	for _milestone: int in MILESTONES:
		at_milestones.append(PackedInt32Array())
	for chain: SimChain in chains:
		runs += chain.coins.size()
		for amount: int in chain.coins:
			coins += amount
		for result: bool in chain.won:
			wins += int(result)
		if chain.runs_to_all > 0:
			runs_to_all.append(chain.runs_to_all)
		else:
			unfinished += 1
			runs_to_all.append(chain.coins.size() + 1)
		for index: int in range(MILESTONES.size()):
			var played: int = mini(MILESTONES[index], chain.unlocked_after.size())
			at_milestones[index].append(chain.unlocked_after[played - 1] if played > 0 else 0)
	var milestones: Array[int] = []
	for values: PackedInt32Array in at_milestones:
		milestones.append(SimSummary.nearest_rank(values, 50))
	return {
		"profiles": chains.size(),
		"runs": runs,
		"wins": wins,
		"mean_coins": float(coins) / runs if runs > 0 else 0.0,
		"unfinished": unfinished,
		"runs_to_all_p10": SimSummary.nearest_rank(runs_to_all, 10),
		"runs_to_all_median": SimSummary.nearest_rank(runs_to_all, 50),
		"runs_to_all_p90": SimSummary.nearest_rank(runs_to_all, 90),
		"unlocks_at_milestones": milestones,
	}


static func _text(value: int) -> String:
	return "-" if value < 0 else str(value)
