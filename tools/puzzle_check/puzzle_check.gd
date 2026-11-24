extends SceneTree
## The puzzle shifts' solver check (#183). Run it with tools/puzzle_check.sh:
##   --puzzle=ID  checks only this puzzle
##   --totals     also lists every reachable total with how many distinct rows score it
## Exits 1 when a puzzle has a data problem, no row hits its target, or its stored solution
## doesn't score exactly its target; a puzzle with more hitting rows than the list's
## max_solutions gets a WARN line only.

const BALANCE := "res://data/balance/balance.tres"
const LIST := "res://data/puzzles/puzzle_list.tres"


func _initialize() -> void:
	quit(_run())


func _run() -> int:
	var only: String = ""
	var totals: bool = false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--puzzle="):
			only = argument.trim_prefix("--puzzle=")
		elif argument == "--totals":
			totals = true
		else:
			push_error("puzzle_check: unknown argument %s (see puzzle_check.gd)" % argument)
			return 1
	var balance: BalanceDefinition = load(BALANCE)
	var list: PuzzleList = load(LIST)
	var failed: int = 0
	var warned: int = 0
	var checked: int = 0
	for problem: String in list.problems():
		print("FAIL list: %s" % problem)
		failed += 1
	for puzzle: PuzzleDefinition in list.puzzles:
		if puzzle == null or (only != "" and String(puzzle.id) != only):
			continue
		checked += 1
		var verdict: int = _check(puzzle, balance, list.max_solutions, totals)
		failed += 1 if verdict == 2 else 0
		warned += 1 if verdict == 1 else 0
	if checked == 0:
		print("FAIL no puzzle checked")
		return 1
	print("")
	print("%d puzzles checked: %d failed, %d warned" % [checked, failed, warned])
	return 1 if failed > 0 else 0


## Prints one puzzle's line; 0 OK, 1 warned, 2 failed.
static func _check(
	puzzle: PuzzleDefinition, balance: BalanceDefinition, most: int, totals: bool
) -> int:
	var name: String = "%s (pack %d, %d€)" % [puzzle.id, puzzle.pack, puzzle.target]
	var problems: PackedStringArray = puzzle.problems()
	if not problems.is_empty():
		print("FAIL %s: %s" % [name, "; ".join(problems)])
		return 2
	var solver: PuzzleSolver = PuzzleSolver.solve(puzzle, balance)
	var stored: int = PuzzleSolver.total_of(puzzle, balance, puzzle.solution)
	var line: String = (
		"%s: %d of %d rows hit, stored solution %s = %d€"
		% [name, solver.count(), solver.rows(), ", ".join(puzzle.solution), stored]
	)
	if totals:
		var parts: PackedStringArray = PackedStringArray()
		for total: int in solver.reachable():
			parts.append("%d:%d" % [total, solver.rows_at(total)])
		line += "\n    totals " + " ".join(parts)
	if solver.count() == 0 or stored != puzzle.target:
		print("FAIL " + line)
		return 2
	if solver.count() > most:
		print("WARN " + line + " (more than %d)" % most)
		return 1
	print("OK   " + line)
	return 0
