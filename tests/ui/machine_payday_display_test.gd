extends GdUnitTestSuite
## The machine's display on a payday and on a BONUS visit after a Manager's review (v0.68): a
## payday reads as one reward (REVIEW PASSED, PREMIUM TICKET, the 2nd premium ticket's lines and
## keys), and a BONUS visit after two inspections names both. Visits are stepped on the view's
## clock (show_at), headless.

const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const SPOT_CHECK := "res://data/inspections/spot_check.tres"
const SHORT_BELT := "res://data/inspections/short_belt.tres"
## Milk, Multipack, Milk x5 = 109: passes the first quotas.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
const EPSILON := 0.001

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_machine_payday_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## A payday (v0.68): the ticket's read says REVIEW PASSED; the BONUS visit is the 2nd PREMIUM
## ticket: PREMIUM TICKET with the ticket icon and "2nd premium ticket · feeding in", then "· pick a
## chute" at the wait, its keys' title "premium 2/2", PACKING… from the 2nd premium ticket, and its
## end "2 premium prizes this shift".
func test_a_payday_reads_as_one_reward() -> void:
	var run: RunState = _passed_run(26, _payday_after_shift_one)
	var review: Array[InspectionDefinition] = [load(SPOT_CHECK), load(SHORT_BELT)]
	run.history[-1].inspections = review
	assert_bool(run.machine.is_payday(run)).is_true()
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	add_child(view)
	view.open_visit(run, null, null, false)
	view.show_at(view.plan.read_end - EPSILON)
	assert_str(view.display.texts()[1]).ends_with(Payday.READ)
	view.close()
	remove_child(view)
	MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)
	MachineSteps.take(run, 0)
	assert_int(run.machine.current_visit().kind).is_equal(MachineVisit.Kind.BONUS)
	assert_bool(run.machine.is_payday(run)).is_true()
	var bonus: RewardMachineView = auto_free(RewardMachineView.new())
	add_child(bonus)
	bonus.open_visit(run, null, null, false)
	var plan: MachinePlan = bonus.plan
	bonus.show_at(0.1)
	assert_array(Array(bonus.display.texts())).is_equal([Payday.TICKET_TITLE, Payday.FEED_SUB])
	assert_bool(bonus.display.ticket_icon().visible).is_true()
	bonus.show_at(plan.choose_at)
	assert_array(Array(bonus.display.texts())).is_equal([Payday.TICKET_TITLE, Payday.CHUTE_SUB])
	for chute: int in RewardMachine.CHUTES:
		assert_str(bonus.title_sub(chute)).contains(Payday.KEY_LEAD)
	assert_bool(run.machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	bonus.show_draw(run)
	plan = bonus.plan
	bonus.show_at(plan.choose_at + EPSILON)
	assert_array(Array(bonus.display.texts())).is_equal(
		[MachineDisplay.PACKING, "2nd premium ticket"]
	)
	bonus.land(MachineSteps.take(run, 0))
	plan = bonus.plan
	bonus.show_at(plan.end_at - EPSILON)
	assert_array(Array(bonus.display.texts())).is_equal([MachineDisplay.SEE_YOU, Payday.END_SUB])
	bonus.close()
	remove_child(bonus)
	await _frames(2)  # Let the parts' queued frees run (no orphans).


## A BONUS visit (not a payday) after a shift with two inspections names both: in the ticket's
## read and in the BONUS visit's end line.
func test_a_bonus_visit_names_both_inspections() -> void:
	var run: RunState = _bonus_run(27)
	var review: Array[InspectionDefinition] = [load(SPOT_CHECK), load(SHORT_BELT)]
	run.history[-1].inspections = review
	assert_bool(run.machine.is_payday(run)).is_false()
	var passed: String = "%s passed" % ", ".join(InspectionTag.names(review))
	assert_str(passed).contains(review[0].display_name).contains(review[1].display_name)
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	add_child(view)
	view.open_visit(run, null, null, false)
	assert_bool(run.machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	view.show_draw(run)
	view.land(MachineSteps.take(run, 0))
	view.show_at(view.plan.end_at - EPSILON)
	assert_array(Array(view.display.texts())).is_equal(
		[MachineDisplay.SEE_YOU, "2 prizes this shift · %s" % passed]
	)
	view.close()
	remove_child(view)
	# The ticket's read on a classic shift with two inspections names both.
	var classic: RunState = _passed_run(28)
	classic.history[-1].inspections = review
	var ticket: RewardMachineView = auto_free(RewardMachineView.new())
	add_child(ticket)
	ticket.open_visit(classic, null, null, false)
	ticket.show_at(ticket.plan.read_end - EPSILON)
	assert_str(ticket.display.texts()[1]).ends_with(" · %s" % passed)
	ticket.close()
	remove_child(ticket)
	await _frames(2)  # Let the parts' queued frees run (no orphans).


## A run that passed shift 1 (`prepare`, when given, edits it first: its machine).
static func _passed_run(seed_value: int, prepare: Callable = Callable()) -> RunState:
	var balance: BalanceDefinition = load(BALANCE)
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(balance))
	if prepare.is_valid():
		prepare.call(run)
	run.start_shift()
	for id: String in PASSING_ROW:
		run.place(run.debug_add_to_hand(load("res://data/cards/%s.tres" % id)), run.row.size())
	run.checkout()
	return run


## A run waiting at a BONUS visit after shift 1's ticket took its first NEW ITEMS prize, earned
## by a passed Spot check (the machine before v0.68's Payday).
static func _bonus_run(seed_value: int) -> RunState:
	var run: RunState = _passed_run(seed_value)
	run.history[-1].inspection = load(SPOT_CHECK)
	MachineSteps.bonus_after_inspection(run)
	run.machine.begin_after_checkout(run)
	MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)
	MachineSteps.take(run, 0)
	return run


## The run's machine makes shift 1 a payday (v0.68): PREMIUM, with a BONUS visit (the data's are 4
## and 8).
static func _payday_after_shift_one(run: RunState) -> void:
	MachineSteps.premium_run(run, [1])
	run.machine.machine.bonus_extra_shifts = PackedInt32Array([1])


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
