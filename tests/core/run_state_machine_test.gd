extends GdUnitTestSuite
## RunState's phases around the RECEIPT REWARDS machine (#77): MACHINE_CHOOSE and MACHINE_PICK
## follow the machine's stage, SCORED ends the shift's visits, and a debug jump clears them.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"


## #77: a passed shift's phase follows the machine: MACHINE_CHOOSE, MACHINE_PICK once a chute is
## drawn, SCORED after the shift's last visit; a balance without a machine goes straight to SCORED.
## A debug jump from a visit clears it.
func test_the_machine_phases_follow_the_visits() -> void:
	var run: RunState = _run(13)
	_pass_with_milks(run)
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	assert_bool(run.machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_PICK)
	assert_bool(run.machine.bin(run)).is_true()
	assert_int(run.phase).is_equal(RunState.Phase.SCORED)
	assert_int(run.history[-1].visits.size()).is_equal(1)
	var bare: BalanceDefinition = (load(BALANCE) as BalanceDefinition).duplicate()
	bare.machine = null
	var deck: DeckDefinition = load(STARTER)
	var plain: RunState = RunState.new(13, deck, bare, RunStock.starting(deck, bare))
	plain.start_shift()
	_pass_with_milks(plain)
	assert_int(plain.phase).is_equal(RunState.Phase.SCORED)
	assert_bool(plain.next_shift()).is_true()
	# A debug jump from a visit clears the visits and plays the target shift.
	for chosen: bool in [false, true]:
		var jumped: RunState = _run(14)
		_pass_with_milks(jumped)
		if chosen:
			jumped.machine.choose(jumped, RewardMachine.Chute.NEW_ITEMS)
		jumped.debug_skip_to_shift(3)
		assert_int(jumped.phase).is_equal(RunState.Phase.PLANNING)
		assert_int(jumped.machine.stage).is_equal(RewardMachine.Stage.IDLE)
		assert_object(jumped.machine.current_visit()).is_null()
		assert_int(jumped.shift_index).is_equal(3)


static func _run(seed_value: int) -> RunState:
	var balance: BalanceDefinition = load(BALANCE)
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(deck, balance))
	run.start_shift()
	return run


## Milk, Multipack, then five Milks (109): passes shift 1.
static func _pass_with_milks(run: RunState) -> void:
	for id: String in ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]:
		run.place(run.debug_add_to_hand(load("res://data/cards/%s.tres" % id)), run.row.size())
	run.checkout()
