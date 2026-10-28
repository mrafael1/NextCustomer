extends GdUnitTestSuite
## Coins at the end of a run (full build plan 7.1, decided with the user): a table by shifts
## passed plus overtime coins. Runs use the live starter deck with every quota at 5; the coin
## numbers are set per test, except in the live-data test.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"


func test_a_run_that_has_not_ended_pays_nothing() -> void:
	var run: RunState = _run(_balance([0, 1, 2], 10, 1), 1)
	_check_out(run, [BREAD, BREAD])
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	var payout: CoinPayout = CoinPayout.for_run(run)
	assert_int(payout.total()).is_equal(0)
	assert_int(payout.shifts_passed).is_equal(0)


func test_coins_follow_the_shifts_passed() -> void:
	var balance: BalanceDefinition = _balance([0, 0, 1, 1, 1, 1, 1, 1, 2], 0, 0)
	for passes: int in range(0, 8):
		var run: RunState = _run(balance, passes + 1)
		for shift: int in range(passes):
			_pass_and_continue(run, [BREAD, BREAD])
		_check_out(run, [])
		assert_int(run.phase).is_equal(RunState.Phase.LOST)
		var payout: CoinPayout = CoinPayout.for_run(run)
		assert_int(payout.shifts_passed).is_equal(passes)
		assert_int(payout.total()).override_failure_message("%d passed" % passes).is_equal(
			balance.coins_by_shifts_passed[passes]
		)
	var won: RunState = _won_run(balance)
	assert_int(CoinPayout.for_run(won).shifts_passed).is_equal(8)
	assert_int(CoinPayout.for_run(won).total()).is_equal(2)


## Overtime is the margin over quota on passed shifts only: 2 Breads (10) over 5 is 5, 4 Breads
## (20) over 5 is 15, and the lost shift's total doesn't count.
func test_overtime_sums_the_passed_margins() -> void:
	var run: RunState = _run(_balance([0], 0, 0), 2)
	_pass_and_continue(run, [BREAD, BREAD])
	_pass_and_continue(run, [BREAD, BREAD, BREAD, BREAD])
	_check_out(run, [])
	assert_int(run.phase).is_equal(RunState.Phase.LOST)
	assert_int(CoinPayout.for_run(run).overtime).is_equal(5 + 15)


## A won run pays the table's last entry, whatever its slips (v0.68): a run with a slip on shift
## 2 that wins passes 7 shifts but is paid as a win, more than a run lost after 7 passes.
func test_a_won_run_with_a_slip_pays_the_last_entry() -> void:
	var balance: BalanceDefinition = _balance([0, 0, 1, 1, 1, 1, 1, 2, 3], 0, 0)
	balance.write_up_limit = 2
	balance.write_up_last_shift = 4
	var run: RunState = _run(balance, 10)
	_pass_and_continue(run, [BREAD, BREAD])
	_check_out(run, [])
	assert_int(run.phase).is_equal(RunState.Phase.SCORED)
	run.next_shift()
	for shift: int in range(5):
		_pass_and_continue(run, [BREAD, BREAD])
	_check_out(run, [BREAD, BREAD])
	assert_int(run.phase).is_equal(RunState.Phase.WON)
	var payout: CoinPayout = CoinPayout.for_run(run)
	assert_int(payout.shifts_passed).is_equal(7)
	assert_int(payout.shift_coins).is_equal(3)


func test_overtime_coins_have_a_step_and_a_cap() -> void:
	# Two passes with overtime 5 and 15 = 20.
	assert_int(_overtime_coins(_balance([0], 20, 1))).is_equal(1)
	assert_int(_overtime_coins(_balance([0], 21, 1))).is_equal(0)
	assert_int(_overtime_coins(_balance([0], 10, 1))).is_equal(1)
	assert_int(_overtime_coins(_balance([0], 10, 5))).is_equal(2)
	assert_int(_overtime_coins(_balance([0], 0, 5))).is_equal(0)


func test_a_short_table_uses_its_last_entry_and_an_empty_one_pays_nothing() -> void:
	var short: RunState = _won_run(_balance([0, 3], 0, 0))
	assert_int(CoinPayout.for_run(short).shift_coins).is_equal(3)
	var empty: RunState = _won_run(_balance([], 0, 0))
	assert_int(CoinPayout.for_run(empty).total()).is_equal(0)


func test_an_ended_run_adds_its_coins_to_the_profile() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.coins = 4
	var catalogue: CatalogueDefinition = CatalogueDefinition.new()
	var run: RunState = _run(_balance([0, 1, 2], 0, 0), 2)
	_pass_and_continue(run, [BREAD, BREAD])
	_check_out(run, [])
	profile.record_run(run, catalogue)
	assert_int(profile.coins).is_equal(5)
	# Recording an unended run adds nothing.
	var unended: RunState = _run(_balance([5], 0, 0), 3)
	profile.record_run(unended, catalogue)
	assert_int(profile.coins).is_equal(5)


## The amounts fitted with the balance simulator (plan v0.28, issue #41; stretched to 12 shifts
## in v0.65 as placeholders until the refit): one entry per number of shifts passed, never
## decreasing, nothing for a run lost on shifts 1 to 4.
func test_live_coin_amounts() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var table: PackedInt32Array = balance.coins_by_shifts_passed
	assert_int(table.size()).is_equal(balance.quotas.size() + 1)
	assert_array(Array(table)).is_equal([0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3])
	for index: int in range(1, table.size()):
		assert_int(table[index]).is_greater_equal(table[index - 1])
	assert_int(balance.overtime_coin_euros).is_equal(923)
	assert_int(balance.overtime_coin_max).is_equal(1)


static func _overtime_coins(balance: BalanceDefinition) -> int:
	var run: RunState = _run(balance, 4)
	_pass_and_continue(run, [BREAD, BREAD])
	_pass_and_continue(run, [BREAD, BREAD, BREAD, BREAD])
	_check_out(run, [])
	return CoinPayout.for_run(run).overtime_coins


static func _balance(table: Array, euros: int, cap: int) -> BalanceDefinition:
	var balance: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
	balance.quotas = PackedInt32Array([5, 5, 5, 5, 5, 5, 5, 5])
	balance.coins_by_shifts_passed = PackedInt32Array(table)
	balance.overtime_coin_euros = euros
	balance.overtime_coin_max = cap
	balance.inspection_shifts = PackedInt32Array()
	balance.review_shifts = PackedInt32Array()
	balance.boon_shifts = PackedInt32Array()
	# A miss ends the run (no slips, v0.68): these runs end where the test misses.
	balance.write_up_limit = 0
	return balance


static func _run(balance: BalanceDefinition, seed_value: int) -> RunState:
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(balance))
	run.start_shift()
	return run


static func _check_out(run: RunState, paths: Array) -> void:
	for path: String in paths:
		run.place(run.debug_add_to_hand(load(path)), run.row.size())
	run.checkout()


static func _pass_and_continue(run: RunState, paths: Array) -> void:
	_check_out(run, paths)
	MachineSteps.next_shift(run)


## All 8 shifts passed with two Breads each (overtime 8 x 5 = 40).
static func _won_run(balance: BalanceDefinition) -> RunState:
	var run: RunState = _run(balance, 9)
	for shift: int in range(7):
		_pass_and_continue(run, [BREAD, BREAD])
	_check_out(run, [BREAD, BREAD])
	return run
