extends GdUnitTestSuite
## The run save after the machine restructure (#108, v0.61, format 6): a level-up keeps the perks
## played at the checkout; saves from before it (formats 4 and 5) still resume, converted by
## RunSaveMigration: the old chute names, "boosted" and the upgrade count
## at the checkout read as the new ones; a STAMP DAY waiting for its pick or queued is dropped; a
## save whose machine can't be read is refused. Nothing is printed.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"
const COUPON_ENGINE := "res://data/upgrades/coupon_engine.tres"

var _balance: BalanceDefinition
var _lookup: ContentLookup


func before_test() -> void:
	# Quotas of 1: every row with a product passes.
	_balance = (load(BALANCE) as BalanceDefinition).duplicate()
	_balance.quotas = PackedInt32Array([1, 1, 1, 1, 1, 1, 1, 1])
	_lookup = ContentLookup.new(_balance)


## #108: a level-up taken from UPGRADE replaces its perk in the same loyalty box. The save keeps
## the perks played at the checkout (LV 1), so the restored receipt scores the same, and the next
## shift plays with LV 2. (No new perk in the pool, so the loyalty drop is the level-up.)
func test_a_level_up_round_trips_with_the_perks_played() -> void:
	var no_perks: Array[UpgradeDefinition] = []
	_balance.upgrade_pool = no_perks
	_lookup = ContentLookup.new(_balance)
	var engine: UpgradeDefinition = load(COUPON_ENGINE)
	var run: RunState = _planning_run(31)
	run.upgrades.append(engine)
	_fill(run)
	run.checkout()
	assert_bool(MachineSteps.choose(run, RewardMachine.Chute.UPGRADE)).is_true()
	var at_pick: RunState = _round_trip(run)
	var index: int = MachineSteps.register_index(at_pick, engine.next_level)
	assert_int(index).is_not_equal(-1)
	assert_object(at_pick.machine.prizes()[index].upgrade).is_same(engine.next_level)
	var landing: MachineLanding = MachineSteps.take(at_pick, index)
	assert_bool(landing.level_up).is_true()
	assert_array(at_pick.upgrades).is_equal([engine.next_level])
	var restored: RunState = _round_trip(at_pick)
	assert_array(restored.machine.played_upgrades).is_equal([engine])
	assert_int(restored.last_result.total).is_equal(run.last_result.total)
	assert_int(RewardMachine.registers_picked(restored)).is_equal(0)
	assert_bool(MachineSteps.next_shift(restored)).is_true()
	assert_array(restored.upgrades).is_equal([engine.next_level])
	# Two levels of one perk are never owned together.
	var data: Dictionary = _json(_save(restored))
	data["upgrades"] = ["coupon_engine", "coupon_engine_lv2"]
	assert_object(RunSave.from_dictionary(data, _lookup)).is_null()


## #108: a format 5 save resumes as format 6 at every save point: the old chute names, "boosted"
## and the upgrade count at the checkout read as the new ones, and the run plays on the same.
func test_a_format_five_save_resumes_at_every_save_point() -> void:
	var run: RunState = _planning_run(32)
	_fill(run)
	run.checkout()
	var choose: Dictionary = _json(_save(run))
	MachineSteps.choose(run, RewardMachine.Chute.UPGRADE)
	var pick: Dictionary = _json(_save(run))
	run.machine.bin(run)
	MachineSteps.pass_visits(run)
	var scored: Dictionary = _json(_save(run))
	for data: Dictionary in [_json(_save(_planning_run(32))), choose, pick, scored]:
		for chute_name: String in ["register", "upgrades"]:
			var old: Dictionary = LegacySave.as_format(data, 5, chute_name)
			var save: RunSave = RunSave.from_dictionary(old, _lookup)
			assert_object(save).override_failure_message(str(data["phase"])).is_not_null()
			var again: Dictionary = _json(_save(save.run))
			assert_str(JSON.stringify(again)).is_equal(JSON.stringify(data))
	# The chute a STAMP DAY or COUPONS draw left in the history reads as the new one.
	var history: Dictionary = LegacySave.as_format(scored, 5)
	history["history"][0]["visits"][0]["chute"] = "coupons"
	history["history"][0]["visits"][0]["kind"] = "stamp_day"
	var resumed: RunSave = RunSave.from_dictionary(history, _lookup)
	assert_object(resumed).is_not_null()
	var visit: MachineVisit = resumed.run.history[0].visits[0]
	assert_int(visit.kind).is_equal(MachineVisit.Kind.TICKET)
	assert_int(visit.chute).is_equal(RewardMachine.Chute.NEW_ITEMS)


## #108: a format 5 save waiting on STAMP DAY's pick resumes at SCORED without its free perk, and
## a queued STAMP DAY is dropped; a format 5 save whose machine can't be read is refused.
func test_a_format_five_stamp_day_is_dropped() -> void:
	var run: RunState = _planning_run(33)
	_fill(run)
	run.checkout()
	MachineSteps.choose(run, RewardMachine.Chute.UPGRADE)
	var stamp_day: Dictionary = LegacySave.as_format(_json(_save(run)), 5)
	stamp_day["machine"]["visit"]["kind"] = "stamp_day"
	run.machine.bin(run)
	MachineSteps.pass_visits(run)
	var scored: Dictionary = _json(_save(run))
	var save: RunSave = RunSave.from_dictionary(stamp_day, _lookup)
	assert_object(save).is_not_null()
	assert_int(save.run.phase).is_equal(RunState.Phase.SCORED)
	assert_object(save.run.machine.current_visit()).is_null()
	assert_int(save.run.machine.stage).is_equal(RewardMachine.Stage.IDLE)
	assert_array(save.run.upgrades).is_empty()
	assert_bool(save.run.next_shift()).is_true()
	var queued: Dictionary = LegacySave.as_format(scored, 5)
	queued["machine"]["queue"] = ["stamp_day"]
	save = RunSave.from_dictionary(queued, _lookup)
	assert_object(save).is_not_null()
	assert_array(save.run.machine.pending_kinds()).is_empty()
	var unreadable: Dictionary = LegacySave.as_format(scored, 5)
	(unreadable["machine"] as Dictionary).erase("upgrades_at_checkout")
	assert_object(RunSave.from_dictionary(unreadable, _lookup)).is_null()
	unreadable = LegacySave.as_format(scored, 4)
	unreadable.erase("machine")
	assert_object(RunSave.from_dictionary(unreadable, _lookup)).is_null()


## The converted form alone: a deep copy (the parsed save is left as it was), format 6.
func test_the_conversion_leaves_the_parsed_save_alone() -> void:
	var run: RunState = _planning_run(34)
	_fill(run)
	run.checkout()
	MachineSteps.choose(run, RewardMachine.Chute.UPGRADE)
	var old: Dictionary = LegacySave.as_format(_json(_save(run)), 5, "upgrades")
	var parsed_text: String = JSON.stringify(old)
	var converted: Dictionary = RunSaveMigration.to_v6(old)
	assert_str(JSON.stringify(old)).is_equal(parsed_text)
	assert_int(int(converted["format_version"])).is_equal(RunSaveMigration.TO_VERSION)
	assert_str(converted["machine"]["visit"]["chute"]).is_equal("upgrade")
	assert_bool(converted["machine"]["visit"].has("boosted")).is_false()
	assert_array(converted["machine"]["played_upgrades"]).is_empty()
	assert_dict(RunSaveMigration.to_v6({"format_version": 5})).is_empty()


## Saves, reads back through JSON text, checks the saved form is unchanged, and returns the
## restored run.
func _round_trip(run: RunState) -> RunState:
	var data: Dictionary = _json(_save(run))
	var save: RunSave = RunSave.from_dictionary(data, _lookup)
	assert_object(save).is_not_null()
	assert_str(JSON.stringify(_json(_save(save.run)))).is_equal(JSON.stringify(data))
	return save.run


## Shift 1, planning.
func _planning_run(seed_value: int) -> RunState:
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(seed_value, deck, _balance, RunStock.starting(_balance))
	run.start_shift()
	return run


func _fill(run: RunState) -> void:
	for card: CardInstance in run.hand():
		run.place(card, run.row.size())


func _save(run: RunState) -> Dictionary:
	return RunSave.to_dictionary(run, "run-1", 10)


## Through JSON text and back, as a file would be read: every number becomes a float.
static func _json(data: Dictionary) -> Dictionary:
	var json: JSON = JSON.new()
	json.parse(JSON.stringify(data))
	return json.data
