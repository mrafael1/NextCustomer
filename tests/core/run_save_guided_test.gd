extends GdUnitTestSuite
## The run save's guided first run fields (format 17, the tutorial; tutorial plan section 1.5):
## `guided` and `guide_step`, written only for a guided run, round-trip at every save point; a
## normal run's save has neither, and a version 16 save reads as a run that isn't guided.

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"

var _balance: BalanceDefinition
var _lookup: ContentLookup


func before_test() -> void:
	_balance = (load(BALANCE) as BalanceDefinition).duplicate()
	_balance.quotas = PackedInt32Array([1, 1, 1, 1, 1, 1, 1, 1])
	EightShiftLoop.apply(_balance)
	_lookup = ContentLookup.new(_balance)


## Version 17 (the tutorial): a guided run saves `guided` and its step, at every save point, and
## reads back guided on the same step; a normal run's save has neither field and reads as not
## guided.
func test_a_guided_run_keeps_its_step_and_a_normal_run_saves_no_guided_fields() -> void:
	var normal: Dictionary = _json(_saved(_planning_run(41)))
	assert_bool(normal.has("guided")).is_false()
	assert_bool(normal.has("guide_step")).is_false()
	assert_bool(normal.has("guide_hints")).is_false()
	assert_bool(normal.has("guide_reveals")).is_false()
	var read: RunSave = RunSave.from_dictionary(normal, _lookup)
	assert_bool(read.run.guided).is_false()
	assert_str(String(read.run.guide_step)).is_empty()
	var run: RunState = _planning_run(42)
	run.guided = true
	run.guide_step = &"G12"
	run.guide_hints = [&"eggs_placed", &"silver"]
	run.guide_reveals = [&"calendar", &"cart"]
	var planning: RunState = _round_trip(run)
	assert_array(planning.guide_reveals).is_equal([&"calendar", &"cart"])
	assert_bool(planning.guided).is_true()
	assert_str(String(planning.guide_step)).is_equal("G12")
	assert_array(planning.guide_hints).is_equal([&"eggs_placed", &"silver"])
	_fill(run)
	run.checkout()
	run.guide_step = &"G23"
	var machine: RunState = _round_trip(run)
	assert_int(machine.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	assert_bool(machine.guided).is_true()
	assert_str(String(machine.guide_step)).is_equal("G23")
	# A guided run with no step yet.
	var fresh: RunState = _planning_run(43)
	fresh.guided = true
	var data: Dictionary = _json(_saved(fresh))
	assert_bool(data["guided"]).is_true()
	assert_str(data["guide_step"]).is_equal("")
	assert_bool(RunSave.from_dictionary(data, _lookup).run.guided).is_true()
	# A guided save from before the hints (2026-11-15) reads with none shown.
	data.erase("guide_hints")
	assert_array(RunSave.from_dictionary(data, _lookup).run.guide_hints).is_empty()
	# One from before the week 1 strip (v1.40) reads with nothing revealed.
	data.erase("guide_reveals")
	assert_array(RunSave.from_dictionary(data, _lookup).run.guide_reveals).is_empty()


## A version 16 save (before the guided fields) still reads, as a run that isn't guided.
func test_a_version_16_save_reads_as_not_guided() -> void:
	assert_int(RunSave.BEFORE_GUIDED_VERSION).is_equal(16)
	assert_bool(RunSave.READ_VERSIONS.has(RunSave.BEFORE_GUIDED_VERSION)).is_true()
	var run: RunState = _planning_run(44)
	var old: Dictionary = _json(_saved(run))
	old["format_version"] = RunSave.BEFORE_GUIDED_VERSION
	var read: RunSave = RunSave.from_dictionary(old, _lookup)
	assert_object(read).is_not_null()
	assert_bool(read.run.guided).is_false()
	assert_array(_instance_ids(read.run.hand())).is_equal(_instance_ids(run.hand()))
	var again: Dictionary = _json(_saved(read.run))
	assert_int(int(again["format_version"])).is_equal(RunSave.FORMAT_VERSION)


## Saves, reads back through JSON text, checks the saved form is unchanged, and returns the
## restored run.
func _round_trip(run: RunState) -> RunState:
	var data: Dictionary = _saved(run)
	assert_dict(data).is_not_empty()
	var save: RunSave = RunSave.from_dictionary(_json(data), _lookup)
	assert_object(save).is_not_null()
	var again: Dictionary = _saved(save.run)
	assert_str(JSON.stringify(again)).is_equal(JSON.stringify(data))
	return save.run


func _planning_run(seed_value: int) -> RunState:
	var run: RunState = RunState.new(
		seed_value, load(STARTER), _balance, RunStock.starting(_balance)
	)
	run.start_shift()
	return run


func _fill(run: RunState) -> void:
	for card: CardInstance in run.hand():
		run.place(card, run.row.size())


static func _saved(run: RunState) -> Dictionary:
	return RunSave.to_dictionary(run, "run-1", 10)


## Through JSON text and back, as a file would be read: every number becomes a float.
static func _json(data: Dictionary) -> Dictionary:
	var json: JSON = JSON.new()
	json.parse(JSON.stringify(data))
	return json.data


static func _instance_ids(cards: Array[CardInstance]) -> Array:
	return cards.map(func(card: CardInstance) -> int: return card.instance_id)
