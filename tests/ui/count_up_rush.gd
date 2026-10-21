extends RefCounted
## Gets the UI suites through count-ups they don't test the count of, fast: ONE tap
## (CountUp._tap, the player's own skip) before the verdict runs the count and the pause at the
## tap's skip speed, and after the verdict the dessert, the printer feed and the print-out's lift
## play exactly as untouched (at the speed setting, in real time). A second tap would skip the
## dessert, so rush() never taps twice or after the verdict. A rushed count-up logs skip_used and
## first_tap_ms: never rush a test that asserts on them, on dessert_skipped, or on the count
## itself (its length, its tempo, the untouched path). Load it with
## preload("res://tests/ui/count_up_rush.gd") (no class_name: tests/ is not exported).

## The longest finish() and played() wait (real time) before they fail the test instead of
## hanging until GdUnit's test timeout: a rushed count with its dessert takes a few seconds.
const MAX_WAIT_MS := 60000


## Taps `count_up` once if it is counting, untapped, before its verdict.
static func rush(count_up: CountUp) -> void:
	if count_up._playing and not count_up._tapped and not count_up._verdict_shown:
		count_up._tap(Time.get_ticks_msec())


## `await screen._on_checkout_pressed()`, rushed: it still returns in the very frame the
## checkout ends (the count_up event logged, the reward or results just shown). The tap is
## deferred so it lands once the count-up has started playing (CountUp.play resets the taps).
static func checkout(screen: ShiftScreen) -> void:
	var count_up: CountUp = screen._count_up
	(func() -> void: rush(count_up)).call_deferred()
	await screen._on_checkout_pressed()


## Rushes the screen's running checkout and waits until it has ended (the rest of
## _on_checkout_pressed runs in the frame _counting turns false).
static func finish(screen: ShiftScreen) -> void:
	rush(screen._count_up)
	var start: int = Time.get_ticks_msec()
	while screen._counting and Time.get_ticks_msec() - start < MAX_WAIT_MS:
		await _tree().process_frame
	var failure: String = "The checkout still counted after %d ms." % MAX_WAIT_MS
	GdUnitTestSuite.assert_bool(screen._counting).override_failure_message(failure).is_false()


## Rushes a count-up played directly (CountUp.play) and waits until play() has returned.
static func played(count_up: CountUp) -> void:
	rush(count_up)
	var start: int = Time.get_ticks_msec()
	while count_up._playing and Time.get_ticks_msec() - start < MAX_WAIT_MS:
		await _tree().process_frame
	var failure: String = "The count-up still played after %d ms." % MAX_WAIT_MS
	GdUnitTestSuite.assert_bool(count_up._playing).override_failure_message(failure).is_false()


## Scales game time by `factor` (GdUnit caps it at 9) for a test that must stay free of input.
## Creating a scene runner resets it to 1, so call it after every scene_runner(); real-time
## clocks (Time.get_ticks_*: hit-stops, the pause, the press windows, arming) don't scale.
static func speed_up(runner: GdUnitSceneRunner, factor: float) -> void:
	runner.set_time_factor(factor)


## Puts game time back to 1x (time scale and physics ticks, as the scene runner does when freed):
## call it in after_test of every suite that calls speed_up, so a failed test can't leave the
## next one sped up.
static func restore() -> void:
	Engine.time_scale = 1.0
	Engine.physics_ticks_per_second = ProjectSettings.get_setting(
		"physics/common/physics_ticks_per_second"
	)


static func _tree() -> SceneTree:
	return Engine.get_main_loop() as SceneTree
