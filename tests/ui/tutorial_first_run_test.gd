extends GdUnitTestSuite
## The guided first run end to end (tutorial plan WP-8, TutorialDirector): a fresh profile's
## guided run driven headless through the real calls, from the opening board (G2-G7) through
## shift 1's gated moves (G8-G22, Eggs WASTED on purpose), the machine (G23-G24) and shift 2's
## time card (G25-G26), with each step's callout inside the screen and off its rings at 1280x720
## and 1920x1080; the done flag saved and the next run not guided; a resume mid-shift and at the
## machine landing on the right step; the steps logged.

const Kit := preload("res://tests/ui/tutorial_kit.gd")
const SEED := 20261115

var _folder: String = ""
var _window_size: Vector2i
var _live_machine: MachineDefinition
var _screens: Array[Node] = []


func before_test() -> void:
	_live_machine = NoOvertime.live_off()
	_window_size = get_tree().root.size
	_folder = "user://tutorial_first_run_%d" % Time.get_ticks_usec()
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	Kit.event_log().use_folder(_folder)


func after_test() -> void:
	await get_tree().process_frame
	for screen: Node in _screens:
		if is_instance_valid(screen):
			screen.queue_free()
	_screens = []
	await get_tree().process_frame
	NoOvertime.live_restore(_live_machine)
	CartReveal._request = false
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## G2 to G26 on a fresh profile: each step shows where it should, the gates hold, the row pays
## as the lines say, and G26 saves the done flag; the next run is not guided.
func test_a_fresh_profile_plays_the_whole_guided_run() -> void:
	get_tree().root.size = Kit.SIZES[0]
	var shift: ShiftScreen = await _screen()
	assert_bool(TutorialFlags.guided_due(shift.profile)).is_true()
	var board: StartBoard = Kit.start_guided(shift, SEED)
	assert_bool(shift.run.guided).is_true()
	assert_bool(shift.tutorial.is_active()).is_true()
	# G2: the regulars' crate, NEXT; the swap plate and RESTOCK locked.
	assert_bool(await Kit.until_step(shift, &"G2")).is_true()
	_assert_callout(shift)
	assert_bool(board.store.actions.locked(TutorialAnchors.SWAP_PLATE)).is_true()
	assert_bool(Kit.press(shift)).is_true()
	# G3: a booster's click opens it; NEXT can't skip it.
	assert_bool(await Kit.until_step(shift, &"G3")).is_true()
	_assert_callout(shift)
	assert_bool(Kit.press(shift)).is_false()
	Kit.click_page(board.store, Kit.pouch(board.store, 0))
	assert_int(board.store.boosters[0].state).is_not_equal(BoosterOpening.State.SEALED)
	# G4: the other one; then G5 once stocked.
	assert_bool(await Kit.until_step(shift, &"G4")).is_true()
	_assert_callout(shift)
	assert_int(shift.tutorial.overlay().ring_rects().size()).is_equal(1)
	Kit.click_page(board.store, Kit.pouch(board.store, 1))
	assert_bool(await Kit.until_step(shift, &"G5")).is_true()
	_assert_callout(shift)
	assert_bool(board.store.primary()).is_true()
	# G6: page 2, NEW PACKS locked; a pack picked.
	assert_bool(await Kit.until_step(shift, &"G6")).is_true()
	_assert_callout(shift)
	assert_bool(board.store.actions.locked(TutorialAnchors.NEWPACKS)).is_true()
	assert_bool(board.staff.primary()).is_false()  # OPEN STORE waits for G7.
	board.pick(1)
	assert_bool(await Kit.until_step(shift, &"G7")).is_true()
	_assert_callout(shift)
	assert_bool(board.staff.primary()).is_true()
	# G8..G9: the till, the quota.
	assert_bool(await Kit.until_step(shift, &"G8")).is_true()
	_assert_callout(shift)
	assert_array(_hand_ids(shift)).is_equal(TutorialScript.guided().hand)
	assert_bool(shift._checkout_button.disabled).is_true()
	assert_bool(Kit.press(shift)).is_true()
	assert_bool(await Kit.until_step(shift, &"G9")).is_true()
	_assert_callout(shift)
	assert_bool(Kit.press(shift)).is_true()
	await _play_shift_one(shift)
	await _play_machine_and_week(shift)
	assert_bool(shift.tutorial.is_active()).is_false()
	assert_str(String(shift.run.guide_step)).is_equal(String(TutorialDirector.DONE))
	assert_bool(shift.guide.gate.is_valid()).is_false()
	var saved: ProfileState = SaveService.new(_folder).load_profile()
	assert_bool(TutorialFlags.has_seen(saved, TutorialFlags.GUIDE_DONE)).is_true()
	assert_bool(TutorialFlags.guided_due(saved)).is_false()
	var logged: Array[String] = _logged_types()
	assert_array(logged).contains(["tutorial_step", "tutorial_done"])
	assert_int(logged.count("tutorial_step")).is_greater_equal(24)


## The same run at 1920x1080: the key steps' callouts lie on screen, off their rings.
func test_the_callouts_fit_at_1080p() -> void:
	get_tree().root.size = Kit.SIZES[1]
	var shift: ShiftScreen = await _screen()
	var board: StartBoard = Kit.start_guided(shift, SEED)
	assert_bool(await Kit.until_step(shift, &"G2")).is_true()
	_assert_callout(shift)
	Kit.press(shift)
	assert_bool(await Kit.until_step(shift, &"G3")).is_true()
	_assert_callout(shift)
	board.store.primary()  # OPEN ALL: G4 is skipped, G5 shows once stocked.
	assert_bool(await Kit.until_step(shift, &"G5")).is_true()
	_assert_callout(shift)
	board.store.primary()
	assert_bool(await Kit.until_step(shift, &"G6")).is_true()
	_assert_callout(shift)
	board.pick(0)
	assert_bool(await Kit.until_step(shift, &"G7")).is_true()
	board.staff.primary()
	assert_bool(await Kit.until_step(shift, &"G8")).is_true()
	_assert_callout(shift)
	Kit.press(shift)
	assert_bool(await Kit.until_step(shift, &"G9")).is_true()
	Kit.press(shift)
	await _play_shift_one(shift)


## A quit after G12's step and a quit at the machine both resume on the right step.
func test_a_resume_lands_on_the_step() -> void:
	get_tree().root.size = Kit.SIZES[0]
	var shift: ShiftScreen = await _to_planning()
	Kit.press(shift)
	assert_bool(await Kit.until_step(shift, &"G9")).is_true()
	Kit.press(shift)
	assert_bool(await Kit.until_step(shift, &"G10")).is_true()
	Kit.place(shift, 2, 0)
	assert_bool(await Kit.until_step(shift, &"G11")).is_true()
	Kit.press(shift)
	assert_bool(await Kit.until_step(shift, &"G12")).is_true()
	shift = await _reopen(shift)
	assert_bool(shift.run.guided).is_true()
	assert_bool(await Kit.until_step(shift, &"G12")).is_true()
	assert_array(Kit.row_ids(shift)).is_equal([&"bread"] as Array[StringName])
	Kit.place(shift, 3, 1)
	assert_bool(await Kit.until_step(shift, &"G13")).is_true()
	# A placed card back to its basket re-shows the step that placed it.
	shift._on_row_card_clicked(shift._row_views[1])
	shift._on_background_input(Kit.left_click())
	assert_bool(await Kit.until_step(shift, &"G12")).is_true()
	Kit.place(shift, 3, 1)
	assert_bool(await Kit.until_step(shift, &"G13")).is_true()
	Kit.press(shift)
	assert_bool(await Kit.until_step(shift, &"G14")).is_true()
	await _fill_row(shift)
	assert_bool(await Kit.until_step(shift, &"G22")).is_true()
	await Kit.Rush.checkout(shift)
	assert_int(shift.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	shift = await _reopen(shift)
	assert_bool(await Kit.until_armed(shift)).is_true()
	assert_bool(await Kit.until_step(shift, &"G23")).is_true()


## The second run of a profile that finished the guided run is a normal one.
func test_a_finished_profile_starts_normal_runs() -> void:
	var shift: ShiftScreen = await _screen()
	TutorialFlags.finish_guide(shift.profile)
	shift.save_profile()
	CartReveal.request()
	var second: ShiftScreen = await _screen()
	assert_bool(second.run.guided).is_false()
	assert_bool(second.tutorial.is_active()).is_false()
	assert_bool(second.guide.gate.is_valid()).is_false()
	second._cart_reveal.close()


# --- Driving ------------------------------------------------------------------------------


## G10..G22: Bread, Cheese (a PAIR), Eggs WASTED in slot 3 then moved to slot 1, the scan, both
## Bananas, Milk and Coffee; refused moves do nothing; CHECKOUT unlocks at the quota.
func _play_shift_one(shift: ShiftScreen) -> void:
	assert_bool(await Kit.until_step(shift, &"G10")).is_true()
	_assert_callout(shift)
	# Only Bread, only to slot 1.
	shift._on_hand_card_clicked(Kit.hand_view(shift, 3))
	assert_object(shift._picked).is_null()
	Kit.place(shift, 2, 0)
	assert_array(Kit.row_ids(shift)).is_equal([&"bread"] as Array[StringName])
	assert_bool(await Kit.until_step(shift, &"G11")).is_true()
	_assert_callout(shift)
	assert_int(shift.run.preview().total).is_equal(5)
	Kit.press(shift)
	assert_bool(await Kit.until_step(shift, &"G12")).is_true()
	_assert_callout(shift)
	Kit.place(shift, 3, 0)  # Slot 1: refused (the Cheese stays picked).
	assert_int(shift.run.row.size()).is_equal(1)
	shift._on_slot_input(Kit.left_click(), 1)
	assert_bool(await Kit.until_step(shift, &"G13")).is_true()
	_assert_callout(shift)
	assert_int(shift.run.preview().total).is_equal(13)
	Kit.press(shift)
	assert_bool(await Kit.until_step(shift, &"G14")).is_true()
	_assert_callout(shift)
	Kit.place(shift, 4, 2)
	assert_bool(await Kit.until_step(shift, &"G15")).is_true()
	_assert_callout(shift)
	var preview: ScoreResult = shift.run.preview()
	assert_int(preview.total).is_equal(14)
	assert_bool(_wasted(preview, 2)).is_true()
	Kit.move(shift, 2, 0)
	assert_array(Kit.row_ids(shift)).is_equal([&"eggs", &"bread", &"cheese"] as Array[StringName])
	assert_bool(await Kit.until_step(shift, &"G16")).is_true()
	_assert_callout(shift)
	assert_int(shift.run.preview().total).is_equal(19)
	# A placed card whose leaving strands the row stays put.
	shift._on_row_card_clicked(shift._row_views[2])
	assert_int(shift.run.row.size()).is_equal(3)
	Kit.press(shift)
	assert_bool(await Kit.until_step(shift, &"G17")).is_true()
	_assert_callout(shift)
	assert_bool(shift.debug_scan(shift.run.row[0])).is_true()
	assert_bool(await Kit.until_step(shift, &"G18")).is_true()
	shift._scan.clear()
	await _fill_bananas_and_breakfast(shift)
	assert_bool(await Kit.until_step(shift, &"G22")).is_true()
	_assert_callout(shift)
	await Kit.Rush.checkout(shift)
	assert_str(String(shift.run.guide_step)).is_equal("G23")


## G14 to G21 from a row of Bread and Cheese.
func _fill_row(shift: ShiftScreen) -> void:
	Kit.place(shift, 4, 2)
	assert_bool(await Kit.until_step(shift, &"G15")).is_true()
	Kit.move(shift, 2, 0)
	assert_bool(await Kit.until_step(shift, &"G16")).is_true()
	Kit.press(shift)
	assert_bool(await Kit.until_step(shift, &"G17")).is_true()
	Kit.press(shift)
	await _fill_bananas_and_breakfast(shift)


func _fill_bananas_and_breakfast(shift: ShiftScreen) -> void:
	assert_bool(await Kit.until_step(shift, &"G18")).is_true()
	_assert_callout(shift)
	Kit.place(shift, 0, 3)
	assert_str(String(shift.tutorial.step_id())).is_equal("G18")
	Kit.place(shift, 1, 6)  # Past the end: the compacted slot 5.
	assert_bool(await Kit.until_step(shift, &"G19")).is_true()
	_assert_callout(shift)
	Kit.press(shift)
	assert_bool(await Kit.until_step(shift, &"G20")).is_true()
	_assert_callout(shift)
	assert_bool(shift._checkout_button.disabled).is_true()
	Kit.place(shift, 6, 5)  # Coffee before Milk: refused, the row keeps its order.
	assert_int(shift.run.row.size()).is_equal(5)
	shift._on_background_input(Kit.left_click())
	Kit.place(shift, 5, 5)
	Kit.place(shift, 6, 6)
	assert_bool(await Kit.until_step(shift, &"G21")).is_true()
	_assert_callout(shift)
	assert_int(shift.run.preview().total).is_equal(35)
	assert_bool(shift._checkout_button.disabled).is_false()
	Kit.press(shift)


## G23 (keys), G24 (prizes, SKIP), then shift 2's time card (G25) and the menu (G26).
func _play_machine_and_week(shift: ShiftScreen) -> void:
	assert_int(shift.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	assert_bool(await Kit.until_armed(shift)).is_true()
	assert_bool(await Kit.until_step(shift, &"G23")).is_true()
	_assert_callout(shift)
	assert_bool(shift._machine._choose(RewardMachine.Chute.NEW_ITEMS)).is_true()
	assert_bool(await Kit.until_armed(shift)).is_true()
	assert_bool(await Kit.until_step(shift, &"G24")).is_true()
	_assert_callout(shift)
	shift._machine.view.skip_bin.pressed.emit()
	shift._machine.view.fast_forward()
	await Kit.frames(2)
	shift._machine._end_return()
	assert_int(shift.run.shift_index).is_equal(1)
	assert_bool(await Kit.until_step(shift, &"G25")).is_true()
	_assert_callout(shift)
	assert_bool(shift._week.is_open()).is_true()
	Kit.press(shift)
	assert_bool(await Kit.until_step(shift, &"G26")).is_true()
	_assert_callout(shift)
	assert_bool(Kit.press(shift)).is_true()
	await Kit.frames(2)


# --- Helpers ------------------------------------------------------------------------------


func _screen() -> ShiftScreen:
	var made: ShiftScreen = await Kit.screen(self)
	_screens.append(made)
	return made


## A guided run on shift 1's planning (G8 shown).
func _to_planning() -> ShiftScreen:
	var shift: ShiftScreen = await _screen()
	var board: StartBoard = Kit.start_guided(shift, SEED)
	assert_bool(await Kit.until_step(shift, &"G2")).is_true()
	Kit.press(shift)
	assert_bool(await Kit.until_step(shift, &"G3")).is_true()
	board.store.primary()
	assert_bool(await Kit.until_step(shift, &"G5")).is_true()
	board.store.primary()
	assert_bool(await Kit.until_step(shift, &"G6")).is_true()
	board.pick(0)
	assert_bool(await Kit.until_step(shift, &"G7")).is_true()
	board.staff.primary()
	assert_bool(await Kit.until_step(shift, &"G8")).is_true()
	return shift


## The screen closed (the run saved) and opened again: it resumes.
func _reopen(shift: ShiftScreen) -> ShiftScreen:
	shift.queue_free()
	await Kit.frames(2)
	return await _screen()


func _assert_callout(shift: ShiftScreen) -> void:
	var overlay: TutorialOverlay = shift.tutorial.overlay()
	assert_object(overlay).is_not_null()
	if overlay == null:
		return
	var fault: String = Kit.callout_fault(overlay)
	var where: String = "%s at %s: %s" % [shift.tutorial.step_id(), get_tree().root.size, fault]
	assert_str(fault).override_failure_message(where).is_empty()


static func _hand_ids(shift: ShiftScreen) -> Array[StringName]:
	var ids: Array[StringName] = []
	for card: CardInstance in shift.run.hand_places():
		ids.append(card.definition.id if card != null else &"")
	return ids


static func _wasted(result: ScoreResult, slot: int) -> bool:
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.WASTED and step.slot == slot:
			return true
	return false


func _logged_types() -> Array[String]:
	var types: Array[String] = []
	for file_name: String in DirAccess.get_files_at(_folder):
		if not file_name.ends_with(".jsonl"):
			continue
		var text: String = FileAccess.get_file_as_string(_folder.path_join(file_name))
		for line: String in text.split("\n", false):
			var parsed: Variant = JSON.parse_string(line)
			if parsed is Dictionary:
				types.append(str((parsed as Dictionary).get("type", "")))
	return types
