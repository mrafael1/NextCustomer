extends GdUnitTestSuite
## The puzzle shifts (#183, full build plan 7.6): the live list's data, every stored solution
## scoring exactly its target on the live rules (so a rule change that breaks a puzzle fails
## here), the puzzle's run (one shift, the hand in order, no redraw, no machine), the verdict, the
## solver on a small puzzle, the packs opening, the profile's solved puzzles (format 10) and the
## badge pins a full pack unlocks (PUZZLE_PACK).

const BALANCE := "res://data/balance/balance.tres"
const LIST := "res://data/puzzles/puzzle_list.tres"
const CATALOGUE := "res://data/catalogue/catalogue.tres"
const BREAD := "res://data/cards/bread.tres"
const SOUP := "res://data/cards/soup.tres"
const POTATOES := "res://data/cards/potatoes.tres"
const PRICE_GUN := "res://data/pins/price_gun.tres"
const LONG_BELT := "res://data/pins/long_belt.tres"
const SPOTLIGHT := "res://data/pins/spotlight.tres"

var _balance: BalanceDefinition
var _list: PuzzleList


func before_test() -> void:
	_balance = load(BALANCE)
	_list = load(LIST)


## 24 puzzles in 3 packs of 8, every one valid, pack 2 opening after 4 solves.
func test_the_list_holds_three_packs_of_eight() -> void:
	assert_array(_list.problems()).is_empty()
	assert_int(_list.puzzles.size()).is_equal(24)
	assert_int(_list.pack_count()).is_equal(3)
	for pack: int in range(1, 4):
		assert_int(_list.pack(pack).size()).is_equal(8)
	assert_int(_list.unlock_solves).is_equal(4)


## Every stored solution scores exactly its target on the live rules.
func test_every_stored_solution_scores_its_target() -> void:
	for puzzle: PuzzleDefinition in _list.puzzles:
		var total: int = PuzzleSolver.total_of(puzzle, _balance, puzzle.solution)
		assert_int(total).override_failure_message(String(puzzle.id)).is_equal(puzzle.target)


## The puzzle's run: one shift, the whole hand in basket order, the target as the quota, its
## slots, no redraw, no week event, no machine; the stored solution checks out EXACT.
func test_a_puzzle_run_is_one_fixed_shift() -> void:
	var puzzle: PuzzleDefinition = _list.find(&"op_breakfast_for_one")
	var run: RunState = PuzzleRun.build(puzzle, _balance)
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_int(run.shift_count()).is_equal(1)
	assert_int(run.quota()).is_equal(puzzle.target)
	assert_int(RowCapacity.card_limit(run.limits)).is_equal(puzzle.slot_count)
	assert_int(run.redraws_allowed).is_equal(0)
	assert_array(run.deck.draw_pile()).is_empty()
	var dealt: Array[StringName] = []
	for card: CardInstance in run.hand():
		dealt.append(card.definition.id)
	assert_array(dealt).is_equal(puzzle.hand_ids())
	assert_array(run.upgrades).is_equal(puzzle.upgrades)
	assert_array(run.pins).is_equal(puzzle.pins)
	assert_array(WeekSchedule.shift_events(run)).is_empty()
	for card: CardInstance in PuzzleRun.row_of(run, puzzle.solution):
		assert_bool(run.place(card, run.row.size())).is_true()
	var result: ScoreResult = run.checkout()
	assert_int(result.total).is_equal(puzzle.target)
	assert_int(PuzzleRun.verdict(result.total, puzzle.target)).is_equal(PuzzleRun.Verdict.EXACT)


## RETRY builds the run again with the checked-out row back on the belt.
func test_retry_puts_the_belt_back() -> void:
	var puzzle: PuzzleDefinition = _list.find(&"op_first_customer")
	var run: RunState = PuzzleRun.retry(puzzle, _balance, PackedStringArray(["soup", "bread"]))
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_int(run.row.size()).is_equal(2)
	assert_str(String(run.row[0].definition.id)).is_equal("soup")
	assert_int(run.hand().size()).is_equal(puzzle.hand.size() - 2)


func test_the_verdict_reads_exact_over_or_short() -> void:
	assert_int(PuzzleRun.verdict(31, 31)).is_equal(PuzzleRun.Verdict.EXACT)
	assert_int(PuzzleRun.verdict(34, 31)).is_equal(PuzzleRun.Verdict.OVER)
	assert_int(PuzzleRun.verdict(27, 31)).is_equal(PuzzleRun.Verdict.SHORT)


## A made-up puzzle of plain items: Bread 5, Soup 5, Potatoes 3 on 2 slots. 8€ is Bread or Soup
## with Potatoes, in either order: 4 rows; a twin swapped is the same row.
func test_the_solver_counts_distinct_rows() -> void:
	var puzzle: PuzzleDefinition = PuzzleDefinition.new()
	puzzle.id = &"made_up"
	puzzle.pack = 1
	puzzle.slot_count = 2
	puzzle.target = 8
	var hand: Array[CardDefinition] = [load(BREAD), load(SOUP), load(POTATOES), load(POTATOES)]
	puzzle.hand = hand
	puzzle.solution = PackedStringArray(["bread", "potatoes"])
	assert_array(puzzle.problems()).is_empty()
	var solver: PuzzleSolver = PuzzleSolver.solve(puzzle, _balance)
	assert_int(solver.count()).is_equal(4)
	# The empty row, 3 single items, then 7 ordered pairs (6 of two items, Potatoes twice once).
	assert_int(solver.rows()).is_equal(1 + 3 + 7)
	assert_int(solver.rows_at(6)).is_equal(1)
	assert_int(PuzzleSolver.total_of(puzzle, _balance, PackedStringArray(["bread"]))).is_equal(5)
	assert_int(PuzzleSolver.total_of(puzzle, _balance, PackedStringArray(["milk"]))).is_equal(-1)


## A puzzle can't wear a pin that changes the hand or the deal, nor list a solution item the
## hand lacks.
func test_a_puzzle_rejects_bad_pins_and_solutions() -> void:
	var puzzle: PuzzleDefinition = _list.find(&"op_first_customer").duplicate()
	puzzle.solution = PackedStringArray(["bread", "bread"])
	assert_array(puzzle.problems()).is_not_empty()
	assert_bool(PuzzleDefinition.is_puzzle_pin(load(PRICE_GUN))).is_false()
	assert_bool(PuzzleDefinition.is_puzzle_pin(load(LONG_BELT))).is_true()


## Pack 1 is open; pack 2 opens on the 4th solve of pack 1, pack 3 on the 4th of pack 2.
func test_packs_open_after_four_solves() -> void:
	var solved: Array[StringName] = []
	assert_bool(_list.is_open(1, solved)).is_true()
	assert_bool(_list.is_open(2, solved)).is_false()
	for puzzle: PuzzleDefinition in _list.pack(1).slice(0, 3):
		solved.append(puzzle.id)
	assert_bool(_list.is_open(2, solved)).is_false()
	solved.append(_list.pack(1)[3].id)
	assert_bool(_list.is_open(2, solved)).is_true()
	assert_bool(_list.is_open(3, solved)).is_false()
	assert_bool(_list.is_open(4, solved)).is_false()


## A full pack unlocks its pin once: Price gun for pack 1, Long belt for pack 2, Spotlight for
## pack 3; solving a puzzle again unlocks nothing.
func test_a_full_pack_unlocks_its_pin() -> void:
	var profile: ProfileState = ProfileState.new()
	var catalogue: CatalogueDefinition = load(CATALOGUE)
	var unlocked: Array[StringName] = []
	for pack: int in range(1, 4):
		for puzzle: PuzzleDefinition in _list.pack(pack):
			unlocked.append_array(ProfilePuzzles.solve(profile, puzzle, _list, catalogue))
	assert_array(unlocked).is_equal([&"price_gun", &"long_belt", &"spotlight"])
	assert_int(profile.solved_puzzles.size()).is_equal(24)
	var again: Array[StringName] = ProfilePuzzles.solve(profile, _list.puzzles[0], _list, catalogue)
	assert_array(again).is_empty()
	assert_int(profile.solved_puzzles.size()).is_equal(24)
	assert_bool(profile.has_pin(load(SPOTLIGHT))).is_true()


## The milestones read as the badge screen states them, and a run's end never meets one.
func test_puzzle_pack_milestones() -> void:
	var gun: PinDefinition = load(PRICE_GUN)
	assert_str(gun.unlock_condition.summary()).is_equal("Solve every puzzle in pack 1")
	assert_array(gun.unlock_condition.problems()).is_empty()
	assert_str((load(LONG_BELT) as PinDefinition).unlock_condition.summary()).is_equal(
		"Solve every puzzle in pack 2"
	)
	var run: RunState = PuzzleRun.build(_list.puzzles[0], _balance)
	assert_bool(UnlockCheck.is_met(gun.unlock_condition, run, {}, 99, 99)).is_false()
	var bad: UnlockCondition = UnlockCondition.new()
	bad.kind = UnlockCondition.Kind.PUZZLE_PACK
	assert_array(bad.problems()).is_not_empty()


## The new pins' rules: Long belt one more slot and one fewer redraw; Spotlight one fewer slot
## and ×2 on the 3rd product.
func test_long_belt_and_spotlight_rules() -> void:
	var puzzle: PuzzleDefinition = _list.find(&"op_first_customer").duplicate()
	var plain: RunState = PuzzleRun.build(puzzle, _balance)
	var pins: Array[PinDefinition] = [load(LONG_BELT)]
	puzzle.pins = pins
	var long: RunState = PuzzleRun.build(puzzle, _balance)
	assert_int(RowCapacity.card_limit(long.limits)).is_equal(
		RowCapacity.card_limit(plain.limits) + 1
	)
	assert_int(ShiftLimits.for_shift(_balance, [], 0, [], 0, -1).redraws).is_equal(
		_balance.base_redraws - 1
	)
	var lit: Array[PinDefinition] = [load(SPOTLIGHT)]
	puzzle.pins = lit
	puzzle.slot_count = 4
	var spot: RunState = PuzzleRun.build(puzzle, _balance)
	assert_int(RowCapacity.card_limit(spot.limits)).is_equal(3)
	for card: CardInstance in PuzzleRun.row_of(
		spot, PackedStringArray(["potatoes", "soup", "bread"])
	):
		spot.place(card, spot.row.size())
	assert_int(spot.preview().total).is_equal(3 + 5 + 10)


## Format 10 on (11 since the difficulty grades): solved puzzles are saved and read back; an older
## profile reads with none.
func test_solved_puzzles_are_saved_in_the_profile() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.solved_puzzles.append(&"op_first_customer")
	var saved: Dictionary = profile.to_dictionary()
	assert_int(saved["format_version"]).is_equal(11)
	var read: ProfileState = ProfileState.from_dictionary(JSON.parse_string(JSON.stringify(saved)))
	assert_array(read.solved_puzzles).is_equal([&"op_first_customer"])
	saved.erase("solved_puzzles")
	saved["format_version"] = 9
	assert_array(ProfileState.from_dictionary(saved).solved_puzzles).is_empty()
	saved["solved_puzzles"] = [3]
	saved["format_version"] = 10
	assert_object(ProfileState.from_dictionary(saved)).is_null()


## The board is offered once a run has ended.
func test_puzzles_are_offered_after_the_first_run() -> void:
	var profile: ProfileState = ProfileState.new()
	assert_bool(ProfilePuzzles.offered(profile)).is_false()
	profile.run_count = 1
	assert_bool(ProfilePuzzles.offered(profile)).is_true()
