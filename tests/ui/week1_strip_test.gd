extends GdUnitTestSuite
## The week 1 strip on the real shift screen (Week1Strip, v1.40; play tests of 2026-11-16 and
## 2026-11-18: "a lot of information, maybe even too much"), at 1280x720 and 1920x1080: a new
## profile's shift 1 shows only what the shift needs (the quota gauge, the receipt, the row, the
## baskets, CHECKOUT, the menu), with the keypad where the week glass will be and nothing moved;
## an experienced profile's shift 1 shows everything, where it always was; a trigger pops its
## element in at its usual place and it stays; a reveal is saved with the run; week 2 shows
## everything.

const Kit := preload("res://tests/ui/tutorial_kit.gd")
const SEED := 20261115
## What shows on every shift 1 (TutorialAnchors ids).
const ALWAYS: Array[StringName] = [
	TutorialAnchors.GAUGE,
	TutorialAnchors.QUOTA,
	TutorialAnchors.RECEIPT,
	TutorialAnchors.CHECKOUT,
	TutorialAnchors.MENU,
	TutorialAnchors.MONITOR,
	TutorialAnchors.TICKETS,
	TutorialAnchors.BASKETS,
]

var _folder: String = ""
var _window_size: Vector2i
var _screens: Array[Node] = []


func before_test() -> void:
	_window_size = get_tree().root.size
	_folder = "user://week1_strip_%d" % Time.get_ticks_usec()
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	Kit.event_log().use_folder(_folder)


func after_test() -> void:
	await get_tree().process_frame
	for screen: Node in _screens:
		if is_instance_valid(screen):
			screen.queue_free()
	_screens = []
	await get_tree().process_frame
	CartReveal._request = false
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## A new profile's shift 1 against an experienced profile's, at both sizes: the six stripped
## elements are off the new profile's screen and on the experienced one's; what always shows is
## on screen at the same place on both, so hiding moved nothing.
func test_shift_one_new_profile_against_experienced() -> void:
	for size: Vector2i in Kit.SIZES:
		get_tree().root.size = size
		var fresh: ShiftScreen = await _screen()
		assert_bool(await Kit.to_free(fresh, SEED)).is_true()
		var strip: Week1Strip = fresh.tutorial.strip
		assert_array(strip.hidden()).is_equal(RevealList.ELEMENTS)
		for control: Control in _stripped_controls(fresh):
			(
				assert_bool(control.is_visible_in_tree())
				. override_failure_message(control.name)
				. is_false()
			)
		for id: StringName in RevealList.ELEMENTS:
			assert_bool(fresh.anchor_rect(id).has_area()).override_failure_message(id).is_false()
		# The keypad stands where the week glass will be.
		var keypad: Control = fresh._stage.cabinet.keypad
		assert_bool(keypad.is_visible_in_tree()).is_true()
		assert_bool(_on_screen(fresh, keypad.get_global_rect())).is_true()
		var always: Dictionary[StringName, Rect2] = _always_rects(fresh)
		var keypad_rect: Rect2 = keypad.get_global_rect()
		fresh.queue_free()
		await Kit.frames(2)
		_wipe_run()
		var veteran: ShiftScreen = await _veteran()
		assert_bool(RevealList.stripped(veteran.run)).is_false()
		assert_array(veteran.tutorial.strip.hidden()).is_empty()
		for control: Control in _stripped_controls(veteran):
			var why: String = "%s at %s" % [control.name, size]
			assert_bool(control.is_visible_in_tree()).override_failure_message(why).is_true()
			var rect: Rect2 = control.get_global_rect()
			assert_bool(_on_screen(veteran, rect)).override_failure_message(why).is_true()
		# The week glass covers the keypad's place, which the new profile saw bare.
		assert_bool(veteran._stage.cabinet.keypad.is_visible_in_tree()).is_false()
		var glass: Rect2 = veteran._stage.week_glass.get_global_rect()
		assert_bool(keypad_rect.grow(2.0).intersects(glass)).is_true()
		var there: Dictionary[StringName, Rect2] = _always_rects(veteran)
		for id: StringName in ALWAYS:
			var moved: String = "%s at %s: %s, was %s" % [id, size, there[id], always[id]]
			assert_bool(_same(there[id], always[id])).override_failure_message(moved).is_true()
		veteran.queue_free()
		await Kit.frames(2)
		_wipe_run()


## A trigger pops its element in where it always is, for the rest of the run: the Cart button at
## the first machine visit, the medal case when the row reaches the first medal, REDRAW when a
## callout rings it. A reveal goes out once (`revealed`), is kept on the run and saved with it.
func test_a_trigger_reveals_its_element_in_place() -> void:
	get_tree().root.size = Kit.SIZES[1]
	var shift: ShiftScreen = await _screen()
	assert_bool(await Kit.to_free(shift, SEED)).is_true()
	var strip: Week1Strip = shift.tutorial.strip
	var heard: Array[StringName] = []
	strip.revealed.connect(func(element: StringName) -> void: heard.append(element))
	var stage: ShiftStage = shift._stage
	# A hook no rule names changes nothing.
	shift.guide.emit(TutorialEvents.SCAN_HELD)
	await Kit.frames(2)
	assert_array(strip.hidden()).is_equal(RevealList.ELEMENTS)
	shift.guide.emit(TutorialEvents.MACHINE_ARMED)
	await Kit.frames(2)
	assert_array(heard).is_equal([RevealList.CART])
	assert_bool(stage.deck_button.is_visible_in_tree()).is_true()
	assert_bool(_on_screen(shift, stage.deck_button.get_global_rect())).is_true()
	assert_bool(shift.anchor_rect(TutorialAnchors.CART).has_area()).is_true()
	# The row's projected total at the first medal's: the medal case.
	var quota: int = shift.run.quota()
	var medal: int = RevealList.medal_total(shift.run, quota)
	shift.guide.emit(
		TutorialEvents.PROJECTED, {TutorialEvents.ARG_TOTAL: quota, TutorialEvents.ARG_QUOTA: quota}
	)
	assert_bool(strip.shows(RevealList.MEDALS)).is_false()  # The quota alone: shift 1's goal.
	shift.guide.emit(
		TutorialEvents.PROJECTED, {TutorialEvents.ARG_TOTAL: medal, TutorialEvents.ARG_QUOTA: quota}
	)
	await Kit.frames(2)
	assert_bool(stage.medal_case.is_visible_in_tree()).is_true()
	assert_bool(_on_screen(shift, stage.medal_case.get_global_rect())).is_true()
	# A callout's rings (a guided step's, a tip's) show what they point at; a second time is none.
	strip.reveal_rings([TutorialAnchors.REDRAW, TutorialAnchors.BASKETS, TutorialAnchors.CART])
	assert_bool(stage.redraw_button.is_visible_in_tree()).is_true()
	assert_bool(_on_screen(shift, stage.redraw_button.get_global_rect())).is_true()
	assert_bool(strip.reveal(RevealList.REDRAW)).is_false()
	assert_array(heard).is_equal([RevealList.CART, RevealList.MEDALS, RevealList.REDRAW])
	# Reduced motion (the kit's profile): shown at once, at its own size.
	assert_vector(stage.redraw_button.scale).is_equal(Vector2.ONE)
	assert_float(stage.redraw_button.modulate.a).is_equal(1.0)
	assert_array(strip.hidden()).is_equal(
		[RevealList.LOYALTY, RevealList.WEEK, RevealList.CALENDAR]
	)
	# Saved with the run: a resume shows the same, with no pop and no signal.
	shift._save_run()
	shift.queue_free()
	await Kit.frames(2)
	var again: ShiftScreen = await _screen()
	assert_bool(await Kit.until_free(again)).is_true()
	assert_array(again.run.guide_reveals).contains_exactly_in_any_order(
		[RevealList.CART, RevealList.MEDALS, RevealList.REDRAW]
	)
	assert_bool(again._stage.deck_button.is_visible_in_tree()).is_true()
	assert_bool(again._stage.redraw_button.is_visible_in_tree()).is_true()
	assert_bool(again._stage.week_glass.is_visible_in_tree()).is_false()
	assert_bool(again._stage.day_calendar.is_visible_in_tree()).is_false()
	assert_bool(again._stage.loyalty_card.is_visible_in_tree()).is_false()


## With motion on, a revealed control pops in: it starts larger and clear, and settles at its own
## size, alpha and pivot.
func test_a_reveal_pops_in_and_settles() -> void:
	get_tree().root.size = Kit.SIZES[0]
	var shift: ShiftScreen = await _screen()
	assert_bool(await Kit.to_free(shift, SEED)).is_true()
	shift.profile.set_reduced_motion(false)
	var button: Control = shift._stage.deck_button
	var pivot: Vector2 = button.pivot_offset
	assert_bool(shift.tutorial.strip.reveal(RevealList.CART)).is_true()
	assert_bool(button.visible).is_true()
	assert_float(button.scale.x).is_greater(1.0)
	assert_float(button.modulate.a).is_less(1.0)
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < Week1Strip.POP_S * 1000.0 + 300.0:
		await Kit.frames(1)  # The pop overshoots under its size on the way: wait it out.
	assert_vector(button.scale).is_equal_approx(Vector2.ONE, Vector2(0.001, 0.001))
	assert_float(button.modulate.a).is_equal_approx(1.0, 0.001)
	assert_vector(button.pivot_offset).is_equal(pivot)


## From week 2 on the guided run shows everything, whatever was revealed; the strip is the first
## week's only.
func test_week_two_shows_everything() -> void:
	get_tree().root.size = Kit.SIZES[0]
	var shift: ShiftScreen = await _screen()
	assert_bool(await Kit.to_free(shift, SEED)).is_true()
	var strip: Week1Strip = shift.tutorial.strip
	assert_array(strip.hidden()).is_equal(RevealList.ELEMENTS)
	shift.run.guide_step = TutorialDirector.DONE
	shift.run.debug_skip_to_shift(WeekSchedule.length(shift._balance))
	shift.debug_show_shift()
	shift._week.skip()
	await Kit.frames(4)
	assert_bool(RevealList.stripped(shift.run)).is_false()
	assert_array(strip.hidden()).is_empty()
	for control: Control in _stripped_controls(shift):
		assert_bool(control.is_visible_in_tree()).override_failure_message(control.name).is_true()
		var rect: Rect2 = control.get_global_rect()
		assert_bool(_on_screen(shift, rect)).override_failure_message(control.name).is_true()
	assert_bool(shift.run.guide_reveals.is_empty()).is_true()  # Shown by the week, not revealed.


# --- Helpers ------------------------------------------------------------------------------


func _screen() -> ShiftScreen:
	var made: ShiftScreen = await Kit.screen(self)
	_screens.append(made)
	return made


## An experienced profile's screen (the guided run done) on a new run's shift 1 planning.
func _veteran() -> ShiftScreen:
	var made: ShiftScreen = await _screen()
	TutorialFlags.finish_guide(made.profile)
	made.save_profile()
	made.start_new_run(SEED, true)
	made._week.skip()
	await Kit.frames(4)
	return made


## The run save removed, so the next screen starts from the profile alone.
func _wipe_run() -> void:
	var path: String = _folder.path_join(SaveService.RUN_FILE)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## The controls the strip hides: the LOYALTY chip, the Cart button, REDRAW, the week glass, the
## desk calendar and the medal case.
static func _stripped_controls(shift: ShiftScreen) -> Array[Control]:
	var stage: ShiftStage = shift._stage
	return [
		stage.loyalty_card,
		stage.deck_button,
		stage.redraw_button,
		stage.week_glass,
		stage.day_calendar,
		stage.medal_case,
	]


## Where each ALWAYS anchor is on `shift`, each asserted on screen.
func _always_rects(shift: ShiftScreen) -> Dictionary[StringName, Rect2]:
	var found: Dictionary[StringName, Rect2] = {}
	for id: StringName in ALWAYS:
		var rect: Rect2 = shift.anchor_rect(id)
		var why: String = "%s at %s: %s" % [id, get_tree().root.size, rect]
		assert_bool(rect.has_area()).override_failure_message(why).is_true()
		assert_bool(_on_screen(shift, rect)).override_failure_message(why).is_true()
		found[id] = rect
	return found


static func _on_screen(shift: ShiftScreen, rect: Rect2) -> bool:
	return rect.has_area() and shift.get_global_rect().grow(1.0).encloses(rect)


static func _same(a: Rect2, b: Rect2) -> bool:
	return a.position.distance_to(b.position) < 1.0 and (a.size - b.size).length() < 1.0
