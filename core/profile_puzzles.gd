class_name ProfilePuzzles
extends RefCounted
## The puzzle shifts a profile solved (#183, ProfileState.solved_puzzles) and the badge pins a
## full pack unlocks (UnlockCondition.Kind.PUZZLE_PACK). Pure: the caller saves the profile.


## Whether the board offers puzzles: once the profile has finished a run (the title's PUZZLES).
static func offered(profile: ProfileState) -> bool:
	return profile != null and profile.run_count > 0


static func is_solved(profile: ProfileState, puzzle: PuzzleDefinition) -> bool:
	return profile.solved_puzzles.has(puzzle.id)


## Whether `puzzle`'s pack is open on the profile (PuzzleList.is_open).
static func is_open(profile: ProfileState, list: PuzzleList, puzzle: PuzzleDefinition) -> bool:
	return list.is_open(puzzle.pack, profile.solved_puzzles)


## Records `puzzle` solved (once) and unlocks every locked pin of the catalogue whose PUZZLE_PACK
## pack is now complete. Returns the pins unlocked now, in catalogue order; a puzzle solved
## before unlocks nothing new.
static func solve(
	profile: ProfileState,
	puzzle: PuzzleDefinition,
	list: PuzzleList,
	catalogue: CatalogueDefinition
) -> Array[StringName]:
	var unlocked_now: Array[StringName] = []
	if not profile.solved_puzzles.has(puzzle.id):
		profile.solved_puzzles.append(puzzle.id)
	for pin: PinDefinition in catalogue.pins:
		if not profile.has_pin(pin) and is_met(pin.unlock_condition, profile, list):
			profile.unlocked_pins.append(pin.id)
			unlocked_now.append(pin.id)
	return unlocked_now


## Whether a PUZZLE_PACK condition is met by the profile's solved puzzles (false for any other).
static func is_met(condition: UnlockCondition, profile: ProfileState, list: PuzzleList) -> bool:
	if condition == null or condition.kind != UnlockCondition.Kind.PUZZLE_PACK:
		return false
	return list.is_complete(condition.amount, profile.solved_puzzles)
