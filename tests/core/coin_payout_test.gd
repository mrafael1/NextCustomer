extends GdUnitTestSuite
## Coins at the end of a run (full build plan 7.1, decided with the user): a table by shifts
## passed (the overtime coin went in v1.03: OvertimeTickets). Runs use the live starter deck with
## every quota at 5; the coin numbers are set per test, except in the live-data test.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"


func test_a_run_that_has_not_ended_pays_nothing() -> void:
	var run: RunState = _run(_balance([0, 1, 2]), 1)
	_check_out(run, [BREAD, BREAD])
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	var payout: CoinPayout = CoinPayout.for_run(run)
	assert_int(payout.total()).is_equal(0)
	assert_int(payout.shifts_passed).is_equal(0)


func test_coins_follow_the_shifts_passed() -> void:
	var balance: BalanceDefinition = _balance([0, 0, 1, 1, 1, 1, 1, 1, 2])
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


## A won run pays the table's last entry, whatever its slips (v0.68): a run with a slip on shift
## 2 that wins passes 7 shifts but is paid as a win, more than a run lost after 7 passes.
func test_a_won_run_with_a_slip_pays_the_last_entry() -> void:
	var balance: BalanceDefinition = _balance([0, 0, 1, 1, 1, 1, 1, 2, 3])
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


## The overtime coin is gone (v1.03): a run far over its quotas pays only its shifts' coins.
func test_overtime_pays_no_coin() -> void:
	var run: RunState = _run(_balance([0, 0, 1]), 4)
	_pass_and_continue(run, [BREAD, BREAD, BREAD, BREAD, BREAD, BREAD])
	_pass_and_continue(run, [BREAD, BREAD, BREAD, BREAD, BREAD, BREAD])
	_check_out(run, [])
	assert_int(run.phase).is_equal(RunState.Phase.LOST)
	var payout: CoinPayout = CoinPayout.for_run(run)
	assert_int(payout.shift_coins).is_equal(1)
	assert_int(payout.total()).is_equal(1)


func test_a_short_table_uses_its_last_entry_and_an_empty_one_pays_nothing() -> void:
	var short: RunState = _won_run(_balance([0, 3]))
	assert_int(CoinPayout.for_run(short).shift_coins).is_equal(3)
	var empty: RunState = _won_run(_balance([]))
	assert_int(CoinPayout.for_run(empty).total()).is_equal(0)


func test_an_ended_run_adds_its_coins_to_the_profile() -> void:
	var profile: ProfileState = ProfileState.new()
	profile.coins = 4
	var catalogue: CatalogueDefinition = CatalogueDefinition.new()
	var run: RunState = _run(_balance([0, 1, 2]), 2)
	_pass_and_continue(run, [BREAD, BREAD])
	_check_out(run, [])
	profile.record_run(run, catalogue)
	assert_int(profile.coins).is_equal(5)
	# Recording an unended run adds nothing.
	var unended: RunState = _run(_balance([5]), 3)
	profile.record_run(unended, catalogue)
	assert_int(profile.coins).is_equal(5)


## The amounts fitted with the balance simulator (plan v0.28, issue #41; stretched to 12 shifts
## in v0.65, refit for 16 in v0.96): one entry per number of shifts passed, never decreasing,
## nothing for a run lost with fewer than 8 shifts passed (1 from 8), and a won run pays 2.
func test_live_coin_amounts() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var table: PackedInt32Array = balance.coins_by_shifts_passed
	assert_int(table.size()).is_equal(balance.quotas.size() + 1)
	assert_array(Array(table)).is_equal([0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 2])
	for index: int in range(1, table.size()):
		assert_int(table[index]).is_greater_equal(table[index - 1])
	# The overtime coin's balance fields are gone (v1.03).
	assert_bool("overtime_coin_euros" in balance).is_false()


static func _balance(table: Array) -> BalanceDefinition:
	var balance: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
	balance.quotas = PackedInt32Array([5, 5, 5, 5, 5, 5, 5, 5])
	balance.coins_by_shifts_passed = PackedInt32Array(table)
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


## All 8 shifts passed with two Breads each.
static func _won_run(balance: BalanceDefinition) -> RunState:
	var run: RunState = _run(balance, 9)
	for shift: int in range(7):
		_pass_and_continue(run, [BREAD, BREAD])
	_check_out(run, [BREAD, BREAD])
	return run
