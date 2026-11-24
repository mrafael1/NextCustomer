class_name PuzzleList
extends Resource
## The puzzle shifts in board order (#183, data/puzzles/puzzle_list.tres): packs of puzzles, easy
## to hard. Pack 1 is open from the start; each later pack opens once `unlock_solves` puzzles of
## the pack before it are solved. Which puzzles a profile solved is ProfileState.solved_puzzles
## (ProfilePuzzles).
##
## Every exported value defaults to a neutral value, because Godot doesn't write a value that
## equals the default into a .tres file.

## The puzzles, pack by pack, in board order.
@export var puzzles: Array[PuzzleDefinition] = []
## Each pack's name on the board, pack 1 first.
@export var pack_titles: PackedStringArray = PackedStringArray()
## Solves in a pack that open the next one.
@export var unlock_solves: int = 0
## The solver warns (tools/puzzle_check.sh) when more distinct rows than this hit the target.
@export var max_solutions: int = 0


func pack_count() -> int:
	return pack_titles.size()


## The puzzles of the 1-based `pack`, in board order.
func pack(number: int) -> Array[PuzzleDefinition]:
	var found: Array[PuzzleDefinition] = []
	for puzzle: PuzzleDefinition in puzzles:
		if puzzle.pack == number:
			found.append(puzzle)
	return found


## The pack's name, or "" for a pack the list doesn't have.
func pack_title(number: int) -> String:
	return pack_titles[number - 1] if number >= 1 and number <= pack_titles.size() else ""


## The puzzle with `puzzle_id`, or null.
func find(puzzle_id: StringName) -> PuzzleDefinition:
	for puzzle: PuzzleDefinition in puzzles:
		if puzzle.id == puzzle_id:
			return puzzle
	return null


## The puzzle after `puzzle` in board order, or null after the last.
func next_after(puzzle: PuzzleDefinition) -> PuzzleDefinition:
	var index: int = puzzles.find(puzzle)
	return puzzles[index + 1] if index >= 0 and index + 1 < puzzles.size() else null


## How many puzzles of the pack are in `solved`.
func solved_in(number: int, solved: Array[StringName]) -> int:
	var count: int = 0
	for puzzle: PuzzleDefinition in pack(number):
		count += 1 if solved.has(puzzle.id) else 0
	return count


## Whether the pack is open with these puzzles solved: pack 1 always, a later one once the pack
## before it has `unlock_solves` solved.
func is_open(number: int, solved: Array[StringName]) -> bool:
	if number <= 1:
		return number == 1
	return number <= pack_count() and solved_in(number - 1, solved) >= unlock_solves


## Whether every puzzle of the pack is solved (an empty pack never is).
func is_complete(number: int, solved: Array[StringName]) -> bool:
	var size: int = pack(number).size()
	return size > 0 and solved_in(number, solved) == size


## Why the list can't work as data, or an empty list (checked by a data test).
func problems() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var ids: Array[StringName] = []
	for puzzle: PuzzleDefinition in puzzles:
		if puzzle == null:
			found.append("an empty puzzle")
			continue
		if ids.has(puzzle.id):
			found.append("puzzle id %s twice" % puzzle.id)
		ids.append(puzzle.id)
		if puzzle.pack > pack_count():
			found.append("%s is in pack %d, past the packs" % [puzzle.id, puzzle.pack])
		for problem: String in puzzle.problems():
			found.append("%s: %s" % [puzzle.id, problem])
	if unlock_solves <= 0:
		found.append("unlock_solves must be above 0")
	if max_solutions <= 0:
		found.append("max_solutions must be above 0")
	return found
