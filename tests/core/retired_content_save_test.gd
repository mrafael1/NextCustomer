extends GdUnitTestSuite
## Run saves made before plan v0.46 (#106: every slot is general) still resume: the removed
## register (Extra coupon slot) and inspection (Coupon slot closed) read as inert stand-ins
## (ContentLookup.RETIRED_UPGRADES and RETIRED_INSPECTIONS). A retired register is dropped from
## the run's registers (its pick no longer counts toward the cap, and a waiting pick no longer
## offers it); a retired inspection stays with no effect. Format 4 saves, scored before the Banana
## chain, skip the checked-out row's total check. Nothing is printed.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"

var _balance: BalanceDefinition
var _lookup: ContentLookup


func before_test() -> void:
	# Quotas of 1: every row with a product passes.
	_balance = (load(BALANCE) as BalanceDefinition).duplicate()
	_balance.quotas = PackedInt32Array([1, 1, 1, 1, 1, 1, 1, 1])
	_lookup = ContentLookup.new(_balance)


## The retired ids resolve to stand-ins with their names and no effect; other missing ids don't
## resolve, and live ids still load their files.
func test_retired_ids_resolve_to_inert_stand_ins() -> void:
	var register: UpgradeDefinition = _lookup.upgrade("extra_coupon_slot")
	assert_str(register.display_name).is_equal("Extra coupon slot")
	assert_bool(ContentLookup.is_retired(register)).is_true()
	assert_int(register.extra_slots).is_equal(0)
	assert_int(register.extra_redraws).is_equal(0)
	assert_array(register.rules).is_empty()
	assert_object(_lookup.upgrade("extra_coupon_slot")).is_same(register)
	var inspection: InspectionDefinition = _lookup.inspection("coupon_slot_closed")
	assert_str(inspection.display_name).is_equal("Coupon slot closed")
	assert_bool(ContentLookup.is_retired(inspection)).is_true()
	assert_int(inspection.extra_slots).is_equal(0)
	assert_array(inspection.rules).is_empty()
	assert_object(_lookup.upgrade("coupon_slot_closed")).is_null()
	assert_object(_lookup.upgrade("never_existed")).is_null()
	assert_bool(ContentLookup.is_retired(_lookup.upgrade("big_basket"))).is_false()


## A planning save with Extra coupon slot owned and its eighth card in the row resumes: the
## register is dropped and the row's last card goes back to the hand.
func test_a_planning_save_with_a_retired_register_resumes_without_it() -> void:
	var run: RunState = _planning_run(27)
	var data: Dictionary = _json(_save(run))
	data["upgrades"] = ["extra_coupon_slot"]
	data["row"] = (data["hand"] as Array).map(_first)
	var save: RunSave = RunSave.from_dictionary(data, _lookup)
	assert_object(save).is_not_null()
	assert_array(save.run.upgrades).is_empty()
	assert_int(save.run.row.size()).is_equal(_balance.slot_count)
	assert_int(save.run.hand().size()).is_equal(_balance.hand_size - _balance.slot_count)
	assert_int(save.run.limits.slot_count).is_equal(_balance.slot_count)
	# Without a retired register, a row over the limit is still refused.
	data["upgrades"] = []
	assert_object(RunSave.from_dictionary(data, _lookup)).is_null()


## After the checkout, a retired register owned at the checkout is dropped from the registers and
## from the ones played then; a retired inspection (the next shift's, and a played shift's) stays
## as an inert stand-in, so the shift keeps its bonus ticket. Saved again, it reads back.
func test_a_machine_save_with_retired_content_resumes() -> void:
	var run: RunState = _run_at_shift_two_checkout(28)
	var data: Dictionary = _json(_save(run))
	data["upgrades"] = ["extra_coupon_slot"]
	data["machine"]["played_upgrades"] = ["extra_coupon_slot"]
	data["next_inspection"] = "coupon_slot_closed"
	data["history"][0]["inspection"] = "coupon_slot_closed"
	var save: RunSave = RunSave.from_dictionary(data, _lookup)
	assert_object(save).is_not_null()
	assert_array(save.run.upgrades).is_empty()
	assert_array(save.run.machine.played_upgrades).is_empty()
	assert_bool(ContentLookup.is_retired(save.run.next_inspection)).is_true()
	assert_bool(ContentLookup.is_retired(save.run.history[0].inspection)).is_true()
	assert_object(RunSave.from_dictionary(_json(_save(save.run)), _lookup)).is_not_null()


## A pick saved with Extra coupon slot among the drawn perks resumes without it: the other
## prizes stay, in their drop order, and the retired one can't be taken.
func test_a_pick_save_no_longer_offers_a_retired_register() -> void:
	var run: RunState = _planning_run(29)
	_fill(run)
	run.checkout()
	assert_bool(MachineSteps.choose(run, RewardMachine.Chute.UPGRADE)).is_true()
	var data: Dictionary = _json(_save(run))
	var prizes: Array = data["machine"]["visit"]["prizes"]
	assert_int(prizes.size()).is_greater(1)
	var perk: int = prizes.find_custom(
		func(prize: Dictionary) -> bool: return prize["kind"] == "register"
	)
	assert_int(perk).is_not_equal(-1)
	var kept: Array = []
	for index: int in prizes.size():
		if index != perk:
			kept.append(prizes[index]["id"])
	prizes[perk]["id"] = "extra_coupon_slot"
	var save: RunSave = RunSave.from_dictionary(data, _lookup)
	assert_object(save).is_not_null()
	var restored: Array[MachinePrize] = save.run.machine.prizes()
	var ids: Array = restored.map(func(prize: MachinePrize) -> String: return String(prize.id()))
	assert_array(ids).is_equal(kept)
	var visit: MachineVisit = save.run.machine.current_visit()
	assert_int(visit.in_drop_order().size()).is_equal(restored.size())


## A retired register picked on an earlier shift no longer counts toward the register cap: its
## loyalty box is free again, as the card shows it.
func test_a_retired_pick_frees_its_loyalty_box() -> void:
	# A register that doesn't score (Extra redraw), so the row checked out with it totals the
	# same once the stand-in is dropped.
	var redraw: UpgradeDefinition = _lookup.upgrade("extra_redraw")
	var run: RunState = null
	for seed_value: int in range(30, 90):
		run = _planning_run(seed_value)
		_fill(run)
		run.checkout()
		if MachineSteps.take_register(run, redraw) == redraw:
			break
	assert_array(run.upgrades).contains([redraw])
	assert_bool(MachineSteps.next_shift(run)).is_true()
	_fill(run)
	run.checkout()
	assert_int(RewardMachine.registers_picked(run)).is_equal(1)
	var data: Dictionary = _json(_save(run))
	var visit: Dictionary = data["history"][0]["visits"][0]
	visit["prizes"][int(visit["picked"])]["id"] = "extra_coupon_slot"
	data["upgrades"] = ["extra_coupon_slot"]
	data["machine"]["played_upgrades"] = ["extra_coupon_slot"]
	var save: RunSave = RunSave.from_dictionary(data, _lookup)
	assert_object(save).is_not_null()
	assert_array(save.run.upgrades).is_empty()
	assert_int(RewardMachine.registers_picked(save.run)).is_equal(0)


## A save from before the Banana chain (format 4) whose checked-out row now totals otherwise
## still resumes (as format 6, #108): the record's total stands. Format 5 is still checked by its
## total.
func test_a_save_from_before_the_banana_chain_skips_the_total_check() -> void:
	var run: RunState = _run_at_shift_two_checkout(31)
	var data: Dictionary = _json(_save(run))
	data["history"][-1]["total"] = int(data["history"][-1]["total"]) + 1
	assert_object(RunSave.from_dictionary(data, _lookup)).is_null()
	data = LegacySave.as_format(data, RunSave.BEFORE_BANANA_CHAIN_VERSION)
	var save: RunSave = RunSave.from_dictionary(data, _lookup)
	assert_object(save).is_not_null()
	assert_int(save.run.history[-1].total).is_equal(run.last_result.total + 1)
	assert_int(save.run.last_result.total).is_equal(run.last_result.total)
	var again: Dictionary = _json(_save(save.run))
	assert_int(int(again["format_version"])).is_equal(RunSave.FORMAT_VERSION)


## Shift 1, planning.
func _planning_run(seed_value: int) -> RunState:
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(seed_value, deck, _balance, RunStock.starting(_balance))
	run.start_shift()
	return run


## Shift 2's checkout, after shift 1's NEW ITEMS pick.
func _run_at_shift_two_checkout(seed_value: int) -> RunState:
	var run: RunState = _planning_run(seed_value)
	_fill(run)
	run.checkout()
	MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)
	MachineSteps.take(run, 0)
	run.next_shift()
	_fill(run)
	run.checkout()
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	return run


static func _fill(run: RunState) -> void:
	for card: CardInstance in run.hand():
		run.place(card, run.row.size())


static func _save(run: RunState) -> Dictionary:
	return RunSave.to_dictionary(run, "run-1", 10)


## Through JSON text and back, as a file would be read: every number becomes a float.
static func _json(data: Dictionary) -> Dictionary:
	var json: JSON = JSON.new()
	json.parse(JSON.stringify(data))
	return json.data


static func _first(pair: Array) -> Variant:
	return pair[0]
