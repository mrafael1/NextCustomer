extends GdUnitTestSuite
## The tutorial's telemetry (RunEvents; docs/PROTOTYPE_PLAN.md section 8, v0.64).

const STARTER := "res://data/decks/starter.tres"
const BALANCE := "res://data/balance/balance.tres"


## The tutorial's events (tutorial plan section 1.5): run_start's guided flag, and the step,
## done, replay, tip, quick step and RESET TIPS builders, JSON-friendly, seconds to a tenth.
func test_tutorial_event_fields() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var run: RunState = RunState.new(78, load(STARTER), balance, RunStock.starting(balance))
	run.guided = true
	assert_bool(RunEvents.run_start(run)["guided"]).is_true()
	assert_dict(RunEvents.tutorial_step(&"G12", 4.26)).is_equal({"id": "G12", "seconds": 4.3})
	assert_dict(RunEvents.tutorial_done(301.04, false)).is_equal(
		{"seconds": 301.0, "replay": false}
	)
	assert_dict(RunEvents.tutorial_replay("title")).is_equal({"from": "title"})
	assert_dict(RunEvents.tip_shown(&"day_event")).is_equal({"id": "day_event"})
	assert_dict(RunEvents.quick_step(TutorialFlags.QUICK_RESTOCK, &"R2", 1.0, true)).is_equal(
		{"tutorial": "restock", "id": "R2", "seconds": 1.0, "backed_out": true}
	)
	assert_bool(RunEvents.quick_step(&"swap", &"SA1", 2.0)["backed_out"]).is_false()
	assert_dict(RunEvents.tips_reset(3)).is_equal({"cleared": 3})
	# A negative time (a clock that went back) logs 0.
	assert_float(RunEvents.tutorial_step(&"G2", -1.0)["seconds"]).is_equal(0.0)
	var text: String = JSON.stringify(RunEvents.quick_step(&"pins", &"P1", 0.5))
	assert_str(text).contains('"tutorial":"pins"')
