extends GdUnitTestSuite
## The top bar's quota gauge as a whole (GaugePanel, relooked after the user's play test of
## 2026-11-09): its pour and lap notes on a planning gain (never a drag's preview, a loss or a
## hidden gauge), its ×N readout growing with the laps (LapReadout), and run_laps, the lap run
## CHECKOUT's medal prelude plays. The meter itself: quota_meter_test; its place on the screen:
## register_tower_test.

const RecordingSfx := preload("res://tests/presentation/recording_sfx.gd")


## The top bar gauge's sound (the user's play test of 2026-11-09): a planning gain pours
## (GaugePanel.POUR_SOUND, POUR_DELAY later, its pitch rising with the glass's fill, highest on a
## full lap); a gain that makes a lap also rings its ladder note (the quota, ×2, ×3 rising). A
## first projection, a drag's preview, a loss and a hidden gauge make none.
func test_a_planning_gain_pours_and_a_lap_rings() -> void:
	var gauge: Array = await _gauge()
	var panel: GaugePanel = gauge[0]
	var sfx: RecordingSfx = gauge[1]
	var meter: QuotaMeter = panel.quota_meter
	meter.show_projected(10, 40)
	await _seconds(0.3)
	assert_int(sfx.sounds.size()).is_equal(0)
	meter.show_projected(30, 40)
	assert_int(sfx.sounds.size()).is_equal(0)  # After the card's own sound.
	await _seconds(0.3)
	assert_array(sfx.sound_names()).is_equal([GaugePanel.POUR_SOUND])
	assert_float(float(sfx.sounds[0]["pitch"])).is_equal_approx(
		GaugePanel.POUR_PITCH_LOW + GaugePanel.POUR_PITCH_RISE * 0.75, 0.001
	)
	assert_int(sfx.notes.size()).is_equal(0)
	sfx.clear()
	meter.show_hypothetical(70, 40, 40)
	meter.show_projected(30, 40)
	meter.show_projected(20, 40)
	await _seconds(0.3)
	assert_int(sfx.sounds.size()).is_equal(0)
	for amount: int in [40, 80, 120, 130]:
		meter.show_projected(amount, 40)
		await _seconds(0.3)
	assert_array(sfx.sound_names()).is_equal(["pour", "pour", "pour", "pour"])
	assert_array(sfx.note_indices()).is_equal([5, 7, 8])
	for entry: Dictionary in sfx.notes:
		assert_float(float(entry["volume_db"])).is_equal(GaugePanel.LAP_NOTE_DB)
	var top: float = GaugePanel.POUR_PITCH_LOW + GaugePanel.POUR_PITCH_RISE
	assert_float(float(sfx.sounds[0]["pitch"])).is_equal_approx(top, 0.001)
	assert_float(float(sfx.sounds[3]["pitch"])).is_less(top)
	assert_float(GaugePanel.pour_pitch(130, 40)).is_less(GaugePanel.pour_pitch(150, 40))
	assert_int(GaugePanel.lap_note(9)).is_equal(GaugePanel.LAP_NOTES[-1])
	sfx.clear()
	panel.hide_gauge(false)
	meter.show_projected(170, 40)
	await _seconds(0.3)
	assert_int(sfx.sounds.size() + sfx.notes.size()).is_equal(0)


## A pour or lap note still waiting when the gauge goes up (CHECKOUT pressed right after a lap)
## or a run is skipped (finish_laps) never sounds: the hidden gauge is quiet.
func test_waiting_sounds_go_with_the_gauge() -> void:
	var gauge: Array = await _gauge()
	var panel: GaugePanel = gauge[0]
	var sfx: RecordingSfx = gauge[1]
	var meter: QuotaMeter = panel.quota_meter
	meter.show_projected(30, 40)
	meter.show_projected(50, 40)
	panel.hide_gauge(false)
	await _seconds(0.4)
	assert_int(sfx.sounds.size() + sfx.notes.size()).is_equal(0)
	panel.show_gauge(false)
	meter.show_projected(90, 40)
	panel.finish_laps()
	await _seconds(0.4)
	assert_int(sfx.sounds.size() + sfx.notes.size()).is_equal(0)


## The ×N readout beside the glass (LapReadout): hidden short of ×2, then chunky pixel digits at
## cell 2 for ×2 and cell 4 from ×3 (LapReadout.CELLS), on the art grid, popping (lifted one art px
## in the ramp's lit colour) as a planning gain makes the lap, never under reduced motion; the
## lamp keeps its check (names_laps off) while the meter's laps stay "×N".
func test_the_readout_grows_with_each_lap() -> void:
	var gauge: Array = await _gauge(false)
	var panel: GaugePanel = gauge[0]
	var meter: QuotaMeter = panel.quota_meter
	var readout: LapReadout = panel.readout
	assert_bool(meter.names_laps).is_false()
	meter.show_projected(10, 40)
	meter.show_projected(70, 40)
	await _seconds(0.6)
	assert_bool(readout.visible).is_false()
	var sizes: Array[int] = []
	for laps: int in range(2, 8):
		meter.show_projected(40 * laps + 5, 40)
		var popped: bool = false
		var lifted: bool = false
		var rest: Color = QuotaLaps.backdrop_ramp(laps + 1)[1]
		var lit: Color = QuotaLaps.backdrop_ramp(laps + 1)[0]
		for _frame: int in range(60):
			await _frames(1)
			popped = popped or readout.popping()
			if readout.lifted():
				lifted = true
				assert_float(readout.words.position.y).is_equal(0.0)
				assert_bool(readout.words.color == lit).is_true()
		assert_bool(popped).override_failure_message("×%d" % laps).is_true()
		assert_bool(lifted).override_failure_message("×%d lift" % laps).is_true()
		await _seconds(LapReadout.POP_SECONDS + 0.1)
		assert_bool(readout.popping()).is_false()
		assert_float(readout.words.position.y).is_equal(float(LapReadout.LIFT))
		assert_bool(readout.words.color == rest).is_true()
		assert_int(readout.words.sheet).is_equal(PixelWords.Sheet.CHUNKY)
		assert_float(readout.words.cell).is_equal(float(readout.cell()))
		assert_bool(readout.words.shadow == Palette.INK).is_true()
		for value: float in [readout.position.x, readout.position.y]:
			assert_float(fmod(value, ArtStyle.ART_SCALE)).is_equal(0.0)
		assert_bool(readout.visible).is_true()
		assert_str(readout.text()).is_equal("×%d" % laps)
		assert_str(meter.badge_text()).is_equal("×%d" % laps)
		sizes.append(readout.cell())
	assert_array(sizes).is_equal([2, 3, 3, 4, 4, 4])
	assert_float(readout.size.y).is_less_equal(panel.size.y)
	meter.show_projected(50, 40)
	await _seconds(0.6)
	assert_bool(readout.visible).is_false()
	meter.reduced_motion = func() -> bool: return true
	meter.show_projected(100, 40)
	await _frames(2)
	assert_bool(readout.visible).is_true()
	assert_bool(readout.popping()).is_false()


## run_laps (CHECKOUT's medal prelude): the glass empties and runs up lap by lap to the total
## with the planning's pour and lap notes and the readout's ramp, emitting lap_run_step per lap
## and never the meter's lap_reached (the quota crossing's); at once under reduced motion.
func test_run_laps_steps_each_lap() -> void:
	var gauge: Array = await _gauge(false)
	var panel: GaugePanel = gauge[0]
	var sfx: RecordingSfx = gauge[1]
	var meter: QuotaMeter = panel.quota_meter
	meter.show_projected(130, 40)
	await _seconds(0.3)
	sfx.clear()
	var steps: Array[int] = []
	var crossed: Array[int] = []
	panel.lap_run_step.connect(func(laps: int) -> void: steps.append(laps))
	meter.lap_reached.connect(func(multiple: int) -> void: crossed.append(multiple))
	await panel.run_laps(130, 40)
	await _seconds(0.6)
	assert_array(steps).is_equal([1, 2, 3])
	assert_array(crossed).is_empty()
	assert_int(meter.amount()).is_equal(130)
	assert_int(sfx.count(GaugePanel.POUR_SOUND)).is_equal(4)
	assert_array(sfx.note_indices()).is_equal([5, 7, 8])
	assert_str(panel.readout.text()).is_equal("×3")
	steps.clear()
	meter.reduced_motion = func() -> bool: return true
	var started: int = Time.get_ticks_msec()
	await panel.run_laps(90, 40)
	assert_int(Time.get_ticks_msec() - started).is_less(100)
	assert_array(steps).is_equal([1, 2])
	assert_int(meter.amount()).is_equal(90)
	assert_array(crossed).is_empty()


## A GaugePanel at the bar's size in a scene with a recording Sfx: [panel, sfx].
func _gauge(reduced: bool = true) -> Array:
	var scene: Control = auto_free(Control.new())
	add_child(scene)
	var sfx: RecordingSfx = RecordingSfx.new()
	scene.add_child(sfx)
	var panel: GaugePanel = GaugePanel.new()
	if reduced:
		panel.quota_meter.reduced_motion = func() -> bool: return true
	scene.add_child(panel)
	panel.place(Vector2.ZERO, ShiftStage.GAUGE_PANEL_RECT.size)
	await _frames(2)
	return [panel, sfx]


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## The readout never shrinks as it reaches two digits (the user's play test of 2026-11-10: ×45
## was drawn smaller than ×7): every "×N" up to ×99 keeps the big cell within the gauge's room.
func test_two_digit_laps_keep_the_big_digits() -> void:
	var readout: LapReadout = auto_free(LapReadout.new())
	readout.room = GaugePanel.READOUT_ROOM
	add_child(readout)
	var big: int = LapReadout.CELLS[-1]
	for laps: int in [5, 7, 9, 10, 45, 88, 99]:
		readout.show_laps(laps, false)
		assert_int(readout.cell()).override_failure_message("×%d" % laps).is_equal(big)
		assert_float(readout.box_size().x).override_failure_message("×%d" % laps).is_less_equal(
			GaugePanel.READOUT_ROOM
		)


## A long run (the user's play test of 2026-11-10: the gauge's fill felt long at ×50 and up): it
## steps its lead laps on the beat (their pours and notes), rolls through the rest in a fixed
## time whatever the lap count, and lands on the exact total: every lap stepped, the readout
## reading the final ×N as it returns, one landing note, and a bounded handful of pours.
func test_a_long_run_rolls_to_its_final_laps_in_a_fixed_time() -> void:
	var gauge: Array = await _gauge(false)
	var panel: GaugePanel = gauge[0]
	var sfx: RecordingSfx = gauge[1]
	var meter: QuotaMeter = panel.quota_meter
	var steps: Array[int] = []
	var crossed: Array[int] = []
	panel.lap_run_step.connect(func(laps: int) -> void: steps.append(laps))
	meter.lap_reached.connect(func(multiple: int) -> void: crossed.append(multiple))
	var lead: int = 3
	var planned: float = (
		lead * GaugePanel.RUN_STEP_SECONDS
		+ GaugePanel.RUN_ROLL_SECONDS
		+ GaugePanel.RUN_LAND_SECONDS
	)
	for laps: int in [50, 200]:
		var total: int = 40 * laps + 13
		meter.show_projected(total, 40)
		await _seconds(0.3)
		sfx.clear()
		steps.clear()
		var started: int = Time.get_ticks_msec()
		await panel.run_laps(total, 40, lead)
		var took: float = (Time.get_ticks_msec() - started) / 1000.0
		var label: String = "×%d took %.2f s" % [laps, took]
		assert_float(took).override_failure_message(label).is_between(planned - 0.1, planned + 0.4)
		assert_array(steps).is_equal(Array(range(1, laps + 1), TYPE_INT, &"", null))
		assert_int(meter.amount()).is_equal(total)
		assert_str(panel.readout.text()).is_equal("×%d" % laps)
		assert_int(panel.readout.shown_laps()).is_equal(laps)
		assert_array(crossed).is_empty()
		await _seconds(0.3)
		# The lead laps' notes (the quota, ×2, ×3), then the landing's alone (the ladder's top).
		assert_array(sfx.note_indices()).is_equal([5, 7, 8, GaugePanel.LAP_NOTES[-1]])
		var roll_pours: int = ceili(GaugePanel.RUN_ROLL_SECONDS / GaugePanel.RUN_ROLL_POUR_SECONDS)
		assert_int(sfx.count(GaugePanel.POUR_SOUND)).is_between(lead + 2, lead + roll_pours + 2)
		assert_int(sfx.sounds.size()).is_equal(sfx.count(GaugePanel.POUR_SOUND))


## A run of up to RUN_PLAIN_STEPS steps stays stepped, one beat each (×5 and its remainder).
func test_a_short_run_keeps_its_steps() -> void:
	var gauge: Array = await _gauge(false)
	var panel: GaugePanel = gauge[0]
	var sfx: RecordingSfx = gauge[1]
	panel.quota_meter.show_projected(210, 40)
	await _seconds(0.3)
	sfx.clear()
	var started: int = Time.get_ticks_msec()
	await panel.run_laps(210, 40, 3)
	var took: float = (Time.get_ticks_msec() - started) / 1000.0
	var planned: float = GaugePanel.RUN_PLAIN_STEPS * GaugePanel.RUN_STEP_SECONDS
	assert_float(took).is_between(planned - 0.1, planned + 0.5)
	await _seconds(0.3)
	assert_int(sfx.count(GaugePanel.POUR_SOUND)).is_equal(GaugePanel.RUN_PLAIN_STEPS)
	assert_array(sfx.note_indices()).is_equal([5, 7, 8, 9, 10])


## A long run skipped (finish_laps: a tap on the prelude) or under reduced motion jumps to its
## end: every lap left stepped at once, the readout on the final ×N, no sound after the skip.
func test_a_long_run_skips_and_stills_to_its_end() -> void:
	var gauge: Array = await _gauge(false)
	var panel: GaugePanel = gauge[0]
	var sfx: RecordingSfx = gauge[1]
	var meter: QuotaMeter = panel.quota_meter
	var steps: Array[int] = []
	panel.lap_run_step.connect(func(laps: int) -> void: steps.append(laps))
	var done: Array[bool] = [false]
	var total: int = 40 * 200 + 5
	var run: Callable = func() -> void:
		await panel.run_laps(total, 40, 3)
		done[0] = true
	run.call()
	await _seconds(0.2)
	assert_bool(done[0]).is_false()
	assert_array(steps).is_equal([1])
	panel.finish_laps()
	sfx.clear()
	await _frames(3)
	assert_bool(done[0]).is_true()
	assert_int(steps.size()).is_equal(200)
	assert_int(steps[-1]).is_equal(200)
	assert_int(meter.amount()).is_equal(total)
	assert_str(panel.readout.text()).is_equal("×200")
	await _seconds(0.3)
	assert_int(sfx.sounds.size() + sfx.notes.size()).is_equal(0)
	steps.clear()
	meter.reduced_motion = func() -> bool: return true
	var started: int = Time.get_ticks_msec()
	await panel.run_laps(40 * 500, 40, 3)
	assert_int(Time.get_ticks_msec() - started).is_less(100)
	assert_int(steps.size()).is_equal(500)
	assert_int(meter.amount()).is_equal(40 * 500)
	assert_str(panel.readout.text()).is_equal("×500")
	await _seconds(0.3)
	assert_int(sfx.sounds.size() + sfx.notes.size()).is_equal(0)
