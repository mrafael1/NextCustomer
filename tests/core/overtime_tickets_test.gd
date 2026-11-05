extends GdUnitTestSuite
## The over-quota rewards (v1.03, OvertimeTickets, decided with the user on 2026-11-05): a passed
## shift making ×2 its quota gives an extra CLASSIC machine ticket (an OVERTIME visit), one making
## ×3 turns its ticket's visit PREMIUM; each at most once a week, with caps of their own. A ×3
## shift also takes the week's ×2 ticket when it is unused; a ticket already PREMIUM uses no
## transform; the last shift has no visit and uses nothing. Runs play Breads (5€ each) against
## quotas of 10 (2 Breads ×1, 4 ×2, 6 ×3) in weeks of 4 shifts, with no day or week events and no
## premium or bonus shifts unless a test sets them.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const BREAD := "res://data/cards/bread.tres"
const X1 := 2
const X2 := 4
const X3 := 6

var _balance: BalanceDefinition
var _lookup: ContentLookup


func before_test() -> void:
	_balance = (load(BALANCE) as BalanceDefinition).duplicate()
	_balance.quotas = PackedInt32Array([10, 10, 10, 10, 10, 10, 10, 10])
	_balance.week_length = 4
	_balance.weeks = []
	_balance.inspection_shifts = PackedInt32Array()
	_balance.review_shifts = PackedInt32Array()
	_balance.boon_shifts = PackedInt32Array()
	_balance.write_up_limit = 0
	var machine: MachineDefinition = _balance.machine.duplicate()
	machine.premium_shifts = PackedInt32Array()
	machine.bonus_extra_shifts = PackedInt32Array()
	machine.bonus_after_inspection = false
	_balance.machine = machine
	_lookup = ContentLookup.new(_balance)


## The live thresholds and caps are machine data: ×2 and ×3, once a week each.
func test_live_thresholds_and_caps() -> void:
	var machine: MachineDefinition = (load(BALANCE) as BalanceDefinition).machine
	assert_int(machine.overtime_ticket_laps).is_equal(2)
	assert_int(machine.overtime_ticket_per_week).is_equal(1)
	assert_int(machine.overtime_premium_laps).is_equal(3)
	assert_int(machine.overtime_premium_per_week).is_equal(1)


## Laps are whole multiples of the quota, as the gauge's lamp counts them.
func test_laps_count_whole_multiples() -> void:
	assert_int(OvertimeTickets.laps(19, 10)).is_equal(1)
	assert_int(OvertimeTickets.laps(20, 10)).is_equal(2)
	assert_int(OvertimeTickets.laps(29, 10)).is_equal(2)
	assert_int(OvertimeTickets.laps(30, 10)).is_equal(3)
	assert_int(OvertimeTickets.laps(-5, 10)).is_equal(0)
	assert_int(OvertimeTickets.laps(30, 0)).is_equal(0)


func test_a_shift_under_x2_earns_nothing() -> void:
	var run: RunState = _run()
	_check_out(run, X1 + 1)  # 15€: ×1.
	assert_bool(run.history[-1].overtime_ticket).is_false()
	assert_bool(run.history[-1].overtime_premium).is_false()
	assert_array(run.machine.pending_kinds()).is_empty()
	assert_bool(run.machine.current_visit().premium).is_false()
	assert_int(OvertimeTickets.state(run, run.history[-1], false)).is_equal(
		OvertimeTickets.State.NONE
	)


## ×2 queues an OVERTIME visit after the ticket's, CLASSIC, and the run plays both.
func test_x2_gives_one_extra_classic_ticket() -> void:
	var run: RunState = _run()
	_check_out(run, X2)
	var record: ShiftRecord = run.history[-1]
	assert_int(record.total).is_equal(20)
	assert_bool(record.overtime_ticket).is_true()
	assert_bool(record.overtime_premium).is_false()
	assert_int(run.machine.current_visit().kind).is_equal(MachineVisit.Kind.TICKET)
	assert_bool(run.machine.current_visit().premium).is_false()
	assert_array(run.machine.pending_kinds()).is_equal([MachineVisit.Kind.OVERTIME])
	_bin_visit(run)
	var overtime: MachineVisit = run.machine.current_visit()
	assert_int(overtime.kind).is_equal(MachineVisit.Kind.OVERTIME)
	assert_bool(overtime.premium).is_false()
	assert_str(overtime.why).is_empty()
	_bin_visit(run)
	assert_int(run.phase).is_equal(RunState.Phase.SCORED)
	(
		assert_array(record.visits.map(func(visit: MachineVisit) -> int: return visit.kind))
		. is_equal([MachineVisit.Kind.TICKET, MachineVisit.Kind.OVERTIME])
	)
	assert_int(OvertimeTickets.state(run, record, false)).is_equal(OvertimeTickets.State.EARNED)


## Once a week: a second ×2 shift that week gets none (USED), the next week's first gets it again.
func test_the_x2_ticket_is_once_a_week() -> void:
	var run: RunState = _run()
	_check_out(run, X2)
	_next(run)
	assert_bool(OvertimeTickets.available(run, false)).is_false()
	_check_out(run, X2)
	assert_bool(run.history[-1].overtime_ticket).is_false()
	assert_array(run.machine.pending_kinds()).is_empty()
	assert_int(OvertimeTickets.state(run, run.history[-1], false)).is_equal(
		OvertimeTickets.State.USED
	)
	_next(run)
	_check_out(run, X1)
	_next(run)
	_check_out(run, X1)
	_next(run)
	# Shift 5 opens week 2.
	assert_bool(OvertimeTickets.available(run, false)).is_true()
	_check_out(run, X2)
	assert_bool(run.history[-1].overtime_ticket).is_true()
	assert_array(run.machine.pending_kinds()).is_equal([MachineVisit.Kind.OVERTIME])


## ×3 turns the ticket's visit PREMIUM and, reaching ×2 too, also takes the week's extra ticket,
## which stays CLASSIC.
func test_x3_makes_the_ticket_premium_and_takes_the_extra_ticket() -> void:
	var run: RunState = _run()
	_check_out(run, X3)
	var record: ShiftRecord = run.history[-1]
	assert_int(record.total).is_equal(30)
	assert_bool(record.overtime_premium).is_true()
	assert_bool(record.overtime_ticket).is_true()
	assert_int(run.machine.current_visit().kind).is_equal(MachineVisit.Kind.TICKET)
	assert_bool(run.machine.current_visit().premium).is_true()
	assert_bool(run.machine.is_premium()).is_true()
	assert_bool(OvertimeTickets.is_premium_visit(run)).is_true()
	assert_array(run.machine.pending_kinds()).is_equal([MachineVisit.Kind.OVERTIME])
	_bin_visit(run)
	assert_bool(run.machine.current_visit().premium).is_false()
	assert_bool(OvertimeTickets.is_premium_visit(run)).is_false()
	assert_int(OvertimeTickets.state(run, record, true)).is_equal(OvertimeTickets.State.EARNED)


## The caps are separate: a ×2 shift uses the ticket only, so a later ×3 shift that week still
## turns PREMIUM (with no extra ticket); a second ×3 that week gets neither.
func test_the_weekly_caps_are_separate() -> void:
	var run: RunState = _run()
	_check_out(run, X2)
	_next(run)
	assert_bool(OvertimeTickets.available(run, true)).is_true()
	_check_out(run, X3)
	assert_bool(run.history[-1].overtime_premium).is_true()
	assert_bool(run.history[-1].overtime_ticket).is_false()
	assert_bool(run.machine.current_visit().premium).is_true()
	assert_array(run.machine.pending_kinds()).is_empty()
	_next(run)
	assert_bool(OvertimeTickets.available(run, true)).is_false()
	_check_out(run, X3)
	assert_bool(run.history[-1].overtime_premium).is_false()
	assert_bool(run.history[-1].overtime_ticket).is_false()
	assert_bool(run.machine.current_visit().premium).is_false()
	assert_int(OvertimeTickets.state(run, run.history[-1], true)).is_equal(
		OvertimeTickets.State.USED
	)


## A ticket already PREMIUM (a premium shift's) is not transformed and uses nothing: the week's
## transform stays for a later ×3 shift. Its BONUS visit is unchanged, the extra ticket CLASSIC.
func test_an_already_premium_ticket_keeps_the_transform() -> void:
	_balance.machine.premium_shifts = PackedInt32Array([2])
	_balance.machine.bonus_extra_shifts = PackedInt32Array([2])
	var run: RunState = _run()
	_check_out(run, X1)
	_next(run)
	_check_out(run, X3)
	var record: ShiftRecord = run.history[-1]
	assert_bool(record.overtime_premium).is_false()
	assert_bool(record.overtime_ticket).is_true()
	assert_bool(run.machine.current_visit().premium).is_true()
	assert_bool(OvertimeTickets.is_premium_visit(run)).is_false()
	assert_int(OvertimeTickets.state(run, record, true)).is_equal(OvertimeTickets.State.NONE)
	assert_array(run.machine.pending_kinds()).is_equal(
		[MachineVisit.Kind.BONUS, MachineVisit.Kind.OVERTIME]
	)
	_bin_visit(run)
	assert_bool(run.machine.current_visit().premium).is_true()  # The premium shift's BONUS.
	_bin_visit(run)
	assert_int(run.machine.current_visit().kind).is_equal(MachineVisit.Kind.OVERTIME)
	assert_bool(run.machine.current_visit().premium).is_false()
	_next(run)
	assert_bool(OvertimeTickets.available(run, true)).is_true()
	_check_out(run, X3)
	assert_bool(run.history[-1].overtime_premium).is_true()
	assert_bool(run.machine.current_visit().premium).is_true()


## The last shift has no machine visit: a ×3 win uses nothing.
func test_the_last_shift_uses_nothing() -> void:
	_balance.quotas = PackedInt32Array([10, 10])
	var run: RunState = _run()
	_check_out(run, X1)
	_next(run)
	assert_bool(OvertimeTickets.available(run, false)).is_false()
	assert_bool(OvertimeTickets.available(run, true)).is_false()
	_check_out(run, X3)
	assert_int(run.phase).is_equal(RunState.Phase.WON)
	assert_bool(run.history[-1].overtime_ticket).is_false()
	assert_bool(run.history[-1].overtime_premium).is_false()
	assert_int(OvertimeTickets.state(run, run.history[-1], false)).is_equal(
		OvertimeTickets.State.NONE
	)


## 0 laps turns a reward off.
func test_zero_laps_turns_a_reward_off() -> void:
	_balance.machine.overtime_ticket_laps = 0
	var run: RunState = _run()
	assert_bool(OvertimeTickets.available(run, false)).is_false()
	assert_bool(OvertimeTickets.available(run, true)).is_true()
	_check_out(run, X3)
	assert_bool(run.history[-1].overtime_ticket).is_false()
	assert_bool(run.history[-1].overtime_premium).is_true()
	assert_array(run.machine.pending_kinds()).is_empty()


## The thresholds are data: with the ticket at ×3, a ×2 shift earns nothing.
func test_the_thresholds_are_data() -> void:
	_balance.machine.overtime_ticket_laps = 3
	var run: RunState = _run()
	_check_out(run, X2)
	assert_bool(run.history[-1].overtime_ticket).is_false()
	_next(run)
	_check_out(run, X3)
	assert_bool(run.history[-1].overtime_ticket).is_true()


## Saved at the PREMIUM ticket's chute (the OVERTIME visit queued) and at the OVERTIME visit's,
## the run reads back with its flags, its queue and its visits, and plays on the same.
func test_the_rewards_round_trip_through_the_save() -> void:
	var run: RunState = _run()
	_check_out(run, X3)
	var restored: RunState = _round_trip(run)
	assert_int(restored.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	assert_bool(restored.history[-1].overtime_ticket).is_true()
	assert_bool(restored.history[-1].overtime_premium).is_true()
	assert_bool(restored.machine.current_visit().premium).is_true()
	assert_array(restored.machine.pending_kinds()).is_equal([MachineVisit.Kind.OVERTIME])
	_bin_visit(run)
	_bin_visit(restored)
	var again: RunState = _round_trip(restored)
	assert_int(again.machine.current_visit().kind).is_equal(MachineVisit.Kind.OVERTIME)
	assert_bool(again.machine.current_visit().premium).is_false()
	MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)
	MachineSteps.choose(again, RewardMachine.Chute.NEW_ITEMS)
	assert_array(_prize_keys(again)).is_equal(_prize_keys(run))
	_bin_visit(again)
	_next(again)
	assert_bool(OvertimeTickets.available(again, false)).is_false()
	assert_bool(OvertimeTickets.available(again, true)).is_false()
	var planning: RunState = _round_trip(again)
	assert_bool(OvertimeTickets.available(planning, false)).is_false()
	assert_bool(planning.history[0].overtime_premium).is_true()


## A save whose flags or visits don't fit is refused: an OVERTIME visit the record didn't earn,
## a PREMIUM ticket the record didn't make.
func test_a_save_with_an_unearned_reward_is_refused() -> void:
	var run: RunState = _run()
	_check_out(run, X3)
	var data: Dictionary = _json(RunSave.to_dictionary(run, "id", 0))
	var history: Array = data["history"]
	(history[-1] as Dictionary).erase("overtime_premium")
	assert_object(RunSave.from_dictionary(data, _lookup)).is_null()
	data = _json(RunSave.to_dictionary(run, "id", 0))
	history = data["history"]
	(history[-1] as Dictionary).erase("overtime_ticket")
	assert_object(RunSave.from_dictionary(data, _lookup)).is_null()


## A version 10 save (before v1.03: no flags, no OVERTIME kind) reads as it is, its week's rewards
## unused, and is saved again as version 11.
func test_a_version_10_save_reads_with_its_rewards_unused() -> void:
	var run: RunState = _run()
	_check_out(run, X1)
	_next(run)
	var data: Dictionary = _json(RunSave.to_dictionary(run, "id", 0))
	data["format_version"] = RunSave.BEFORE_OVERTIME_VERSION
	assert_int(RunSave.BEFORE_OVERTIME_VERSION).is_equal(10)
	var save: RunSave = RunSave.from_dictionary(data, _lookup)
	assert_object(save).is_not_null()
	assert_bool(OvertimeTickets.available(save.run, false)).is_true()
	assert_bool(OvertimeTickets.available(save.run, true)).is_true()
	var again: Dictionary = RunSave.to_dictionary(save.run, "id", 0)
	assert_int(int(again["format_version"])).is_equal(11)
	assert_int(RunSave.FORMAT_VERSION).is_equal(11)
	# A record in the old form (no flags) reads as none earned.
	var record: ShiftRecord = ShiftRecord.from_dictionary(
		{
			"shift": 1,
			"quota": 10,
			"total": 30,
			"passed": true,
			"inspections": [],
			"played": [],
			"visits": []
		},
		_lookup
	)
	assert_bool(record.overtime_ticket or record.overtime_premium).is_false()


## The event log's and save's record form writes the flags only when earned.
func test_the_record_writes_its_flags_only_when_earned() -> void:
	var record: ShiftRecord = ShiftRecord.new(1, 10, 30)
	assert_bool(record.to_dictionary().has("overtime_ticket")).is_false()
	record.overtime_ticket = true
	record.overtime_premium = true
	var data: Dictionary = record.to_dictionary()
	assert_bool(data["overtime_ticket"]).is_true()
	assert_bool(data["overtime_premium"]).is_true()
	var read: ShiftRecord = ShiftRecord.from_dictionary(_json(data), _lookup)
	assert_bool(read.overtime_ticket and read.overtime_premium).is_true()
	var visit: MachineVisit = MachineVisit.new(MachineVisit.Kind.OVERTIME)
	assert_str(visit.to_dictionary()["kind"]).is_equal("overtime")
	assert_int(MachineVisit.from_dictionary(visit.to_dictionary(), _lookup).kind).is_equal(
		MachineVisit.Kind.OVERTIME
	)


func _run() -> RunState:
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(7, deck, _balance, RunStock.starting(_balance))
	run.start_shift()
	return run


## Checks out `breads` Breads (5€ each).
func _check_out(run: RunState, breads: int) -> void:
	for _index: int in range(breads):
		run.place(run.debug_add_to_hand(load(BREAD)), run.row.size())
	run.checkout()


func _next(run: RunState) -> void:
	assert_bool(MachineSteps.next_shift(run)).is_true()


## Chooses NEW ITEMS (else the open chute) on the waiting visit and bins it.
func _bin_visit(run: RunState) -> void:
	if run.phase == RunState.Phase.MACHINE_CHOOSE:
		MachineSteps.choose(run, MachineSteps.first_lit(run, RewardMachine.Chute.NEW_ITEMS))
	assert_bool(run.machine.bin(run)).is_true()


func _round_trip(run: RunState) -> RunState:
	var save: RunSave = RunSave.from_dictionary(_json(RunSave.to_dictionary(run, "id", 0)), _lookup)
	assert_object(save).is_not_null()
	return save.run if save != null else null


func _prize_keys(run: RunState) -> Array[String]:
	var keys: Array[String] = []
	for prize: MachinePrize in run.machine.prizes():
		keys.append(prize.key())
	return keys


static func _json(data: Dictionary) -> Dictionary:
	var json: JSON = JSON.new()
	json.parse(JSON.stringify(data))
	return json.data
