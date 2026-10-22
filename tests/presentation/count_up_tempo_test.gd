extends GdUnitTestSuite
## The count's tempo (CountUpTuning.count_tempo, 2026-10-20): the user found the count a bit too
## fast, so it plays 1.25x slower, evenly.

const PLAN := preload("res://tests/presentation/count_up_plan_test.gd")


## 2026-10-20: the count's tempo slows every beat, ride and roll evenly. The plan keeps its
## lengths at speed 1; only planned_ms changes, its beats, rides and pre-roll by 1 / count_tempo,
## its hit-stops and pause not at all. 0 counts as tempo 1.
func test_the_count_tempo_slows_the_row_evenly_but_not_its_stops() -> void:
	var live: CountUpTuning = load(PLAN.TUNING)
	var normal: CountUpTuning = live.duplicate()
	normal.count_tempo = 1.0
	var slow: CountUpTuning = live.duplicate()
	var neutral: CountUpTuning = live.duplicate()
	neutral.count_tempo = 0.0
	for tuning: CountUpTuning in [normal, slow, neutral]:
		# No fit, so both tempos keep every beat's length.
		tuning.fit_target_ms = 100000
	for shift: int in [1, 3]:
		for speed: float in [1.0, 1.5]:
			var context: CountUpContext = CountUpContext.new(shift, 0, speed)
			var steps: Array[ScoreStep] = PLAN._full_steps()
			var at_1: CountUpPlan = CountUpPlan.build(steps, 40, context, normal)
			var at_tempo: CountUpPlan = CountUpPlan.build(steps, 40, context, slow)
			var where: String = "shift %d speed %s" % [shift, speed]
			assert_float(at_tempo.base_speed).override_failure_message(where).is_equal(
				at_1.base_speed
			)
			assert_float(at_tempo.count_speed).override_failure_message(where).is_equal_approx(
				at_1.count_speed * live.count_tempo, 0.0001
			)
			var stops: int = 0
			for index: int in range(at_1.beats.size()):
				assert_int(at_tempo.beats[index].duration_ms).is_equal(
					at_1.beats[index].duration_ms
				)
				assert_int(at_tempo.beats[index].hit_stop_ms).is_equal(
					at_1.beats[index].hit_stop_ms
				)
				stops += at_1.beats[index].hit_stop_ms
			assert_int(at_tempo.pause_ms).is_equal(at_1.pause_ms)
			var counted_1: int = at_1.planned_ms - stops - at_1.pause_ms
			var counted: int = at_tempo.planned_ms - stops - at_tempo.pause_ms
			assert_int(counted).override_failure_message(where).is_between(
				floori(counted_1 / live.count_tempo) - 1, ceili(counted_1 / live.count_tempo) + 1
			)
			var zero: CountUpPlan = CountUpPlan.build(steps, 40, context, neutral)
			assert_int(zero.planned_ms).override_failure_message(where).is_equal(at_1.planned_ms)
