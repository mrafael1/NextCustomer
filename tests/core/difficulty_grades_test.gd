extends GdUnitTestSuite
## The difficulty grades (#182, full build plan 7.5): the ladder's data, each grade's rule applied
## on a copy of the balance (GradeApply), the profile's ladder (opened by wins only), the grade's
## win bonus (CoinPayout), the WIN_AT_GRADE badge pins (Express lane, Overtime, Last call), the
## run save's grade (and the 7-grade ladder's mapped) and the profile's format 11. Uses the live
## balance, pins and starter deck.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const CATALOGUE := "res://data/catalogue/catalogue.tres"
const BREAD := "res://data/cards/bread.tres"
const EXPRESS := "res://data/pins/express_lane.tres"
const OVERTIME := "res://data/pins/overtime.tres"
const LAST_CALL := "res://data/pins/last_call.tres"
const NAMES: Array[String] = [
	"TRAINEE",
	"CASHIER",
	"SENIOR",
	"SUPERVISOR",
	"SHIFT LEAD",
	"MANAGER",
]
const RULES: Array[String] = [
	"No extra rules",
	"-1 redraw per shift",
	"Shrinkflation: your top item loses 1€ each week",
	"Expiry dates: coupons and some new items last 2 weeks",
	"-1 belt slot",
	"{off} promo on one family each shift from week 2",
]
## Grade 5's rule as the player reads it (the user's play tests of 2026-11-24: a promo, its cut
## random each shift), the range from the twist's cuts.
const PROMO_RULE := "-15 to -30% promo on one family each shift from week 2"

var _base: BalanceDefinition


func before_test() -> void:
	_base = load(BALANCE)


## The ladder: grades 0 to 5 in data/grades, named, each with its rule line and +1 coin a grade.
func test_the_ladder_is_data() -> void:
	assert_int(_base.grades.size()).is_equal(6)
	assert_int(GradeApply.count(_base)).is_equal(6)
	for index: int in range(_base.grades.size()):
		var grade: GradeDefinition = _base.grades[index]
		assert_str(grade.resource_path).is_equal("res://data/grades/grade_%d.tres" % index)
		assert_str(grade.display_name).is_equal(NAMES[index])
		assert_str(grade.rule_text).is_equal(RULES[index])
		assert_int(grade.coin_bonus).is_equal(index)


## Grade 0 is the game as it is: the balance itself, unchanged.
func test_grade_zero_plays_the_balance_itself() -> void:
	assert_object(GradeApply.balance_for(_base, 0)).is_same(_base)
	assert_array(GradeApply.rule_lines(_base, 0)).is_empty()


## Each grade adds its one rule on top of the ones below: 1 less redraw, Shrinkflation, Expiry
## dates, 1 less belt slot, the Picky regular; the quotas, slips, boon days and prizes never move.
func test_each_grade_stacks_its_rule() -> void:
	var g1: BalanceDefinition = GradeApply.balance_for(_base, 1)
	assert_int(g1.base_redraws).is_equal(_base.base_redraws - 1)
	assert_array(g1.twists).is_empty()
	var g2: BalanceDefinition = GradeApply.balance_for(_base, 2)
	assert_int(g2.base_redraws).is_equal(1)
	assert_object(GradeRules.shrinkflation(g2)).is_not_null()
	var g3: BalanceDefinition = GradeApply.balance_for(_base, 3)
	assert_int(g3.twists.size()).is_equal(2)
	assert_object(GradeRules.expiry(g3)).is_not_null()
	var g4: BalanceDefinition = GradeApply.balance_for(_base, 4)
	assert_int(g4.slot_count).is_equal(_base.slot_count - 1)
	assert_int(g4.twists.size()).is_equal(2)
	var g5: BalanceDefinition = GradeApply.balance_for(_base, 5)
	assert_int(g5.slot_count).is_equal(6)
	assert_int(g5.base_redraws).is_equal(1)
	assert_int(g5.twists.size()).is_equal(3)
	assert_object(GradeRules.picky(g5)).is_not_null()
	var read: Array[String] = RULES.slice(1)
	read[4] = PROMO_RULE
	assert_array(Array(GradeApply.rule_lines(_base, 5))).is_equal(read)
	for graded: BalanceDefinition in [g1, g2, g3, g4, g5]:
		assert_array(Array(graded.quotas)).is_equal(Array(_base.quotas))
		assert_int(graded.write_up_limit).is_equal(_base.write_up_limit)
		assert_array(Array(graded.boon_shifts)).is_equal(Array(_base.boon_shifts))
		assert_int(graded.machine.prizes_per_visit).is_equal(_base.machine.prizes_per_visit)
	# The balance data itself never changes.
	assert_int(_base.slot_count).is_equal(7)
	assert_int(_base.base_redraws).is_equal(2)
	assert_array(_base.twists).is_empty()


## A graded run starts with its balance's limits: grade 4 plays 6 slots and 1 redraw, the quota
## as it is.
func test_a_graded_run_plays_its_limits() -> void:
	var run: RunState = _run(GradeApply.balance_for(_base, 4), 6, 4)
	assert_int(run.limits.slot_count).is_equal(6)
	assert_int(run.redraws_allowed).is_equal(1)
	assert_int(run.quota()).is_equal(_base.quotas[0])


## A won run opens the next grade; a lost run opens nothing; the ladder stops at its top.
func test_only_a_win_opens_the_next_grade() -> void:
	var profile: ProfileState = ProfileState.new()
	var catalogue: CatalogueDefinition = load(CATALOGUE)
	assert_int(profile.open_grade(6)).is_equal(0)
	profile.record_run(_ended(0, false), catalogue)
	assert_int(profile.best_grade_won).is_equal(-1)
	assert_int(profile.open_grade(6)).is_equal(0)
	profile.record_run(_ended(0, true), catalogue)
	assert_int(profile.open_grade(6)).is_equal(1)
	profile.record_run(_ended(1, false), catalogue)
	assert_int(profile.open_grade(6)).is_equal(1)
	profile.record_run(_ended(3, true), catalogue)
	assert_int(profile.best_grade_won).is_equal(3)
	profile.record_run(_ended(1, true), catalogue)
	assert_int(profile.best_grade_won).is_equal(3)
	profile.record_run(_ended(5, true), catalogue)
	assert_int(profile.open_grade(6)).is_equal(5)


## A won graded run pays its grade's bonus (+1 a grade) on top of the table; a lost one doesn't.
func test_a_graded_win_pays_its_bonus() -> void:
	var table: PackedInt32Array = _base.coins_by_shifts_passed
	var won: CoinPayout = CoinPayout.for_run(_ended(3, true))
	assert_int(won.grade_coins).is_equal(3)
	assert_int(won.total()).is_equal(table[table.size() - 1] + 3)
	var lost: CoinPayout = CoinPayout.for_run(_ended(3, false))
	assert_int(lost.grade_coins).is_equal(0)
	assert_int(CoinPayout.for_run(_ended(0, true)).grade_coins).is_equal(0)


## Express lane opens on a win at grade 2, Overtime at 4, Last call at 5: a win at a higher
## grade counts, a loss never does.
func test_grade_pins_unlock_on_a_win_at_their_grade() -> void:
	var pins: Dictionary[String, int] = {EXPRESS: 2, OVERTIME: 4, LAST_CALL: 5}
	for path: String in pins:
		var pin: PinDefinition = load(path)
		var condition: UnlockCondition = pin.unlock_condition
		var grade: int = pins[path]
		assert_int(condition.kind).is_equal(UnlockCondition.Kind.WIN_AT_GRADE)
		assert_int(condition.amount).is_equal(grade)
		assert_array(condition.problems()).is_empty()
		assert_str(condition.summary()).is_equal("Win a run at grade %d" % grade)
		assert_bool(UnlockCheck.is_met(condition, _ended(grade - 1, true))).is_false()
		assert_bool(UnlockCheck.is_met(condition, _ended(grade, false))).is_false()
		assert_bool(UnlockCheck.is_met(condition, _ended(grade, true))).is_true()
		assert_bool(UnlockCheck.is_met(condition, _ended(5, true))).is_true()
	var profile: ProfileState = ProfileState.new()
	var unlocked: Array[StringName] = profile.record_run(_ended(4, true), load(CATALOGUE))
	assert_bool(unlocked.has(&"express_lane")).is_true()
	assert_bool(unlocked.has(&"overtime")).is_true()
	assert_bool(unlocked.has(&"last_call")).is_false()


## Overtime: two more redraws a shift, nothing else.
func test_overtime_adds_two_redraws_a_shift() -> void:
	var run: RunState = _run(_base, 2, 0, [OVERTIME])
	assert_int(run.redraws_allowed).is_equal(_base.base_redraws + 2)
	assert_int(run.limits.slot_count).is_equal(_base.slot_count)
	assert_int(run.quota()).is_equal(_base.quotas[0])


## Last call: the row's last card pays +5€ every shift; the others and the quota are unchanged.
func test_last_call_adds_five_to_the_last_card() -> void:
	var run: RunState = _run(_base, 2, 0, [LAST_CALL])
	assert_int(run.quota()).is_equal(_base.quotas[0])
	for index: int in range(3):
		run.place(run.debug_add_to_hand(load(BREAD)), run.row.size())
	var plain: RunState = _run(_base, 2)
	for index: int in range(3):
		plain.place(plain.debug_add_to_hand(load(BREAD)), plain.row.size())
	var with_pin: ScoreResult = run.preview()
	var without: ScoreResult = plain.preview()
	assert_int(with_pin.payouts[2]).is_equal(without.payouts[2] + 5)
	assert_int(with_pin.payouts[0]).is_equal(without.payouts[0])
	assert_int(with_pin.payouts[1]).is_equal(without.payouts[1])


## The run save keeps the grade (written only above 0) and restores the graded balance; a grade
## the balance doesn't list is refused; a save without one reads at grade 0.
func test_the_grade_round_trips_in_the_run_save() -> void:
	var lookup: ContentLookup = ContentLookup.new(_base)
	var run: RunState = _run(GradeApply.balance_for(_base, 4), 4, 4)
	var data: Dictionary = RunSave.to_dictionary(run, "run-1", 10)
	assert_int(int(data["grade"])).is_equal(4)
	assert_int(int(data["format_version"])).is_equal(RunSave.FORMAT_VERSION)
	var save: RunSave = RunSave.from_dictionary(_json(data), lookup)
	assert_object(save).is_not_null()
	assert_int(save.run.grade).is_equal(4)
	assert_int(save.run.balance.base_redraws).is_equal(1)
	assert_int(save.run.limits.slot_count).is_equal(6)
	assert_int(save.run.quota()).is_equal(run.quota())
	var again: Dictionary = RunSave.to_dictionary(save.run, save.run_id, save.run_ms)
	assert_str(JSON.stringify(again)).is_equal(JSON.stringify(data))
	var bad: Dictionary = data.duplicate()
	bad["grade"] = 6
	assert_object(RunSave.from_dictionary(_json(bad), lookup)).is_null()
	# A 7-grade ladder save (v20, v21) reads its grade on the 5-grade one: 7 (all of quotas, slips,
	# redraws, Shrinkflation, Expiry dates, the belt) is 4; 2 (quotas, slips) is 0.
	var mapped: Array[int] = [0, 0, 0, 1, 2, 3, 4, 4]
	for old: int in range(mapped.size()):
		var saved: Dictionary = data.duplicate()
		saved["format_version"] = RunSave.OLD_LADDER_VERSION
		saved["grade"] = old
		var read: RunSave = RunSave.from_dictionary(_json(saved), lookup)
		assert_object(read).override_failure_message(str(old)).is_not_null()
		assert_int(read.run.grade).is_equal(mapped[old])
	var too_high: Dictionary = data.duplicate()
	too_high["format_version"] = RunSave.BEFORE_TWISTS_VERSION
	too_high["grade"] = 8
	assert_object(RunSave.from_dictionary(_json(too_high), lookup)).is_null()
	var plain: Dictionary = RunSave.to_dictionary(_run(_base, 4), "run-2", 10)
	assert_bool(plain.has("grade")).is_false()
	plain["format_version"] = RunSave.BEFORE_GRADES_VERSION
	var older: RunSave = RunSave.from_dictionary(_json(plain), lookup)
	assert_object(older).is_not_null()
	assert_int(older.run.grade).is_equal(0)
	assert_object(older.run.balance).is_same(_base)


## Profile format 11 keeps best_grade_won; an older profile without it (format 10 is the puzzle
## shifts', 9 and older before them) with a run won reads with grade 0 won (grade 1 open), one
## without a win with none. The grades play-test builds' profiles hold best_grade_won and no
## solved_puzzles: a format 10 one (the 7-grade ladder) reads with a best grade above 5 as 5, a
## format 11 one with its best grade, both with no puzzle solved.
func test_the_profile_keeps_its_best_grade() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.best_grade_won = 4
	var data: Dictionary = profile.to_dictionary()
	assert_int(int(data["format_version"])).is_equal(11)
	var read: ProfileState = ProfileState.from_dictionary(_json(data))
	assert_int(read.best_grade_won).is_equal(4)
	var older: Dictionary = ProfileState.new().to_dictionary()
	older.erase("best_grade_won")
	older["format_version"] = ProfileState.BEFORE_GRADES_VERSION
	assert_int(ProfileState.from_dictionary(older).best_grade_won).is_equal(-1)
	older["stats"] = {"runs_won": 2}
	assert_int(ProfileState.from_dictionary(older).best_grade_won).is_equal(0)
	older.erase("solved_puzzles")
	older["format_version"] = 9
	assert_int(ProfileState.from_dictionary(older).best_grade_won).is_equal(0)
	var old_ladder: Dictionary = ProfileState.new().to_dictionary()
	old_ladder.erase("solved_puzzles")
	old_ladder["format_version"] = ProfileState.BEFORE_GRADES_VERSION
	old_ladder["stats"] = {"runs_won": 3}
	old_ladder["best_grade_won"] = 7
	assert_int(ProfileState.from_dictionary(_json(old_ladder)).best_grade_won).is_equal(5)
	old_ladder["best_grade_won"] = 3
	var kept: ProfileState = ProfileState.from_dictionary(_json(old_ladder))
	assert_int(kept.best_grade_won).is_equal(3)
	assert_array(kept.solved_puzzles).is_empty()
	var play_test: Dictionary = old_ladder.duplicate()
	play_test["format_version"] = 11
	play_test["best_grade_won"] = 4
	var five_ladder: ProfileState = ProfileState.from_dictionary(_json(play_test))
	assert_int(five_ladder.best_grade_won).is_equal(4)
	assert_array(five_ladder.solved_puzzles).is_empty()
	var wrong: Dictionary = ProfileState.new().to_dictionary()
	wrong["best_grade_won"] = -2
	assert_object(ProfileState.from_dictionary(wrong)).is_null()


## A run of `balance` at `grade` wearing `pins` (paths), started.
func _run(
	balance: BalanceDefinition, seed_value: int, grade: int = 0, pins: Array = []
) -> RunState:
	var run: RunState = RunState.new(seed_value, load(STARTER), balance, RunStock.starting(balance))
	run.grade = grade
	var worn: Array[PinDefinition] = []
	for path: String in pins:
		worn.append(load(path))
	RunPins.wear(run, worn)
	run.start_shift()
	return run


## A run at `grade` that ended, won or lost (its phase set: these checks read only the phase,
## the grade, the balance and the history).
func _ended(grade: int, won: bool) -> RunState:
	var run: RunState = _run(GradeApply.balance_for(_base, grade), 1, grade)
	run.phase = RunState.Phase.WON if won else RunState.Phase.LOST
	return run


static func _json(data: Dictionary) -> Dictionary:
	var json: JSON = JSON.new()
	json.parse(JSON.stringify(data))
	return json.data
