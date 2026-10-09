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
	assert_int(run.phase).is_equal(RunState.Phase.REWARD)
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


## Overtime is the margin over quota on passed shifts only: 2 Breads (6) over 5 is 1, and the
## lost shift's total doesn't count.
func test_overtime_sums_the_passed_margins() -> void:
	var run: RunState = _run(_balance([0], 0, 0), 2)
	_pass_and_continue(run, [BREAD, BREAD])
	_pass_and_continue(run, [BREAD, BREAD, BREAD, BREAD])
	_check_out(run, [BREAD])
	assert_int(run.phase).is_equal(RunState.Phase.LOST)
	assert_int(CoinPayout.for_run(run).overtime).is_equal(1 + 7)


func test_overtime_coins_have_a_step_and_a_cap() -> void:
	# Two passes with overtime 1 and 7 = 8.
	assert_int(_overtime_coins(_balance([0], 8, 1))).is_equal(1)
	assert_int(_overtime_coins(_balance([0], 9, 1))).is_equal(0)
	assert_int(_overtime_coins(_balance([0], 4, 1))).is_equal(1)
	assert_int(_overtime_coins(_balance([0], 4, 5))).is_equal(2)
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


## The amounts fitted with the balance simulator (plan v0.28, issue #41): one entry per number
## of shifts passed, never decreasing, nothing for a run lost on shifts 1 to 4.
func test_live_coin_amounts() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var table: PackedInt32Array = balance.coins_by_shifts_passed
	assert_int(table.size()).is_equal(balance.quotas.size() + 1)
	assert_array(Array(table)).is_equal([0, 0, 0, 0, 1, 1, 1, 1, 2])
	for index: int in range(1, table.size()):
		assert_int(table[index]).is_greater_equal(table[index - 1])
	assert_int(balance.overtime_coin_euros).is_equal(700)
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
	# No upgrade step, so a passed shift goes straight on after the reward.
	balance.upgrade_shifts = PackedInt32Array()
	balance.inspection_shifts = PackedInt32Array()
	return balance


static func _run(balance: BalanceDefinition, seed_value: int) -> RunState:
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(deck, balance))
	run.start_shift()
	return run


static func _check_out(run: RunState, paths: Array) -> void:
	for path: String in paths:
		run.place(run.debug_add_to_hand(load(path)), run.row.size())
	run.checkout()


static func _pass_and_continue(run: RunState, paths: Array) -> void:
	_check_out(run, paths)
	run.skip_reward()
	run.next_shift()


## All 8 shifts passed with two Breads each (overtime 8 x 1 = 8).
static func _won_run(balance: BalanceDefinition) -> RunState:
	var run: RunState = _run(balance, 9)
	for shift: int in range(7):
		_pass_and_continue(run, [BREAD, BREAD])
	_check_out(run, [BREAD, BREAD])
	return run
