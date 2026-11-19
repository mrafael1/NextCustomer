extends GdUnitTestSuite
## The guided first run end to end (tutorial plan WP-8, TutorialDirector, reworked after play
## test 1, 2026-11-15, and cut to six short lines after the play tests of 2026-11-16 and
## 2026-11-18, v1.40): a fresh profile's guided run driven headless through the real calls, from
## the opening board (G3, G5; its NEXT and OPEN STORE with no line) through shift 1's intro (G7,
## G8) and free planning (G10: any move, two reactive hints in a bubble, a missed CHECKOUT is a
## rehearsal that puts planning back, the answer's ghosts after 2 misses), the machine (no line)
## and shift 2's closing line (G15, REDRAW), with each step's callout inside the screen and off
## its rings at 1280x720 and 1920x1080; the done flag saved and the next run not guided; a resume
## in the free planning and at the machine landing on the right step; the steps, retries and
## hints logged. The week 1 strip's reveals along the way are checked too (Week1Strip).

const Kit := preload("res://tests/ui/tutorial_kit.gd")
const SEED := 20261115
## Shift 1's hand places (TutorialScript.hand) and the rows laid from them.
const BANANA_1 := 0
const BANANA_2 := 1
const MILK := 2
const EGGS := 3
const YOGURT := 4
const CEREAL := 5
const CHEESE := 7
## The answer (36€), and the same seven with Eggs last (29€, under the 30€ quota).
const ANSWER: Array[int] = [BANANA_1, YOGURT, BANANA_2, EGGS, MILK, CEREAL, CHEESE]
const WRONG: Array[int] = [BANANA_1, YOGURT, BANANA_2, MILK, CEREAL, CHEESE, EGGS]

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


## The whole guided run on a fresh profile: each step shows where it should, the gates hold, two
## missed rehearsals bring the answer, and the closing step saves the done flag; the next run is
## not guided.
func test_a_fresh_profile_plays_the_whole_guided_run() -> void:
	get_tree().root.size = Kit.SIZES[0]
	var shift: ShiftScreen = await _screen()
	assert_bool(TutorialFlags.guided_due(shift.profile)).is_true()
	var board: StartBoard = Kit.start_guided(shift, SEED)
	assert_bool(shift.run.guided).is_true()
	assert_bool(shift.tutorial.is_active()).is_true()
	# G3: both boosters ringed, waiting sealed on the counter (round 2 of the 2026-11-19 play
	# test); the swap key and RESTOCK locked. The player opens them; the first opened one's ring
	# drops.
	assert_bool(await Kit.until_step(shift, &"G3")).is_true()
	_assert_callout(shift)
	assert_int(shift.run.starter.core_cards.size()).is_equal(4)
	assert_bool(board.store.actions.locked(TutorialAnchors.SWAP_KEY)).is_true()
	for opening: BoosterOpening in board.store.boosters:
		assert_int(opening.state).is_equal(BoosterOpening.State.SEALED)
	assert_int(shift.tutorial.overlay().ring_rects().size()).is_equal(2)
	_open_boosters(board)
	for opening: BoosterOpening in board.store.boosters:
		assert_int(opening.state).is_not_equal(BoosterOpening.State.SEALED)
	# Stocked: no line (the lit NEXT key says it); NEXT goes on.
	assert_bool(await Kit.until_stocked(shift, board)).is_true()
	await Kit.frames(3)
	assert_object(shift.tutorial.overlay()).is_null()
	assert_str(String(shift.tutorial.step_id())).is_equal("G6")
	assert_bool(board.store.primary()).is_true()
	# G6: page 2, KEEP on the regulars' crate (Enter), then OPEN STORE (no starter pack, v1.45).
	assert_bool(await Kit.until_step(shift, &"G6")).is_true()
	_assert_callout(shift)
	assert_bool(board.staff.primary()).is_true()
	assert_bool(board.staff.regulars_pending()).is_false()
	assert_bool(await Kit.open_store(shift, board)).is_true()
	# G7 and G8: the row and the quota, the item read; no move meanwhile.
	assert_bool(await Kit.until_step(shift, &"G7")).is_true()
	_assert_callout(shift)
	assert_array(_hand_ids(shift)).is_equal(TutorialScript.guided().hand)
	assert_bool(shift._checkout_button.disabled).is_true()
	Kit.place(shift, EGGS, 0)
	assert_bool(shift.run.row.is_empty()).is_true()
	shift._on_background_input(Kit.left_click())
	assert_bool(Kit.press(shift)).is_true()
	assert_bool(await Kit.until_step(shift, &"G8")).is_true()
	_assert_callout(shift)
	assert_bool(shift.debug_scan(shift.run.hand_places()[EGGS])).is_true()  # The item read.
	await _play_shift_one(shift)
	await _play_machine_and_shift_two(shift)
	assert_bool(shift.tutorial.is_active()).is_false()
	assert_str(String(shift.run.guide_step)).is_equal(String(TutorialDirector.DONE))
	assert_bool(shift.guide.gate.is_valid()).is_false()
	await _assert_week_hints(shift)
	var saved: ProfileState = SaveService.new(_folder).load_profile()
	assert_bool(TutorialFlags.has_seen(saved, TutorialFlags.GUIDE_DONE)).is_true()
	assert_bool(TutorialFlags.guided_due(saved)).is_false()
	var logged: Array[String] = _logged_types()
	assert_array(logged).contains(["tutorial_step", "tutorial_done", "tutorial_hint"])
	assert_int(logged.count("tutorial_retry")).is_equal(2)
	assert_int(logged.count("tutorial_hint")).is_equal(2)
	assert_int(logged.count("tutorial_step")).is_greater_equal(6)
	# The rehearsals were not checkouts: only the passed one is logged.
	assert_int(logged.count("checkout")).is_equal(1)


## The same run at 1920x1080: every step's callout lies on screen, off its rings, and a hint's
## bubble lies on screen.
func test_the_callouts_fit_at_1080p() -> void:
	get_tree().root.size = Kit.SIZES[1]
	var shift: ShiftScreen = await _screen()
	var board: StartBoard = Kit.start_guided(shift, SEED)
	assert_bool(await Kit.until_step(shift, &"G3")).is_true()
	_assert_callout(shift)
	_open_boosters(board)
	assert_bool(await Kit.until_stocked(shift, board)).is_true()
	board.store.primary()
	assert_bool(await Kit.until_step(shift, &"G6")).is_true()
	_assert_callout(shift)
	assert_bool(await Kit.open_store(shift, board)).is_true()
	for id: StringName in [&"G7", &"G8"]:
		assert_bool(await Kit.until_step(shift, id)).is_true()
		_assert_callout(shift)
		Kit.press(shift)
	assert_bool(await Kit.until_free(shift)).is_true()
	Kit.place(shift, EGGS, 0)
	Kit.place(shift, YOGURT, 1)
	await _assert_bubble(shift, &"combo", 0)
	Kit.lay(shift, ANSWER)
	await Kit.Rush.checkout(shift)
	assert_int(shift.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	await _skip_machine(shift)
	assert_bool(await Kit.until_step(shift, &"G15")).is_true()
	_assert_callout(shift)


## A quit in the free planning resumes on it with the row as placed; a missed rehearsal is not
## saved (a quit after it resumes on planning); a quit at the machine resumes there with no line,
## the closing step waiting and what the strip revealed still shown.
func test_a_resume_lands_on_the_step() -> void:
	get_tree().root.size = Kit.SIZES[0]
	var shift: ShiftScreen = await _to_free()
	Kit.place(shift, BANANA_1, 0)
	Kit.place(shift, YOGURT, 1)
	shift = await _reopen(shift)
	assert_bool(shift.run.guided).is_true()
	assert_bool(await Kit.until_free(shift)).is_true()
	assert_array(Kit.row_ids(shift)).is_equal([&"banana", &"yogurt"] as Array[StringName])
	await Kit.Rush.checkout(shift)  # 12€: a rehearsal.
	assert_bool(await Kit.until_step(shift, &"RETRY")).is_true()
	assert_int(shift.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_int(shift.run.write_ups).is_equal(0)
	assert_array(Kit.row_ids(shift)).is_equal([&"banana", &"yogurt"] as Array[StringName])
	shift = await _reopen(shift)
	assert_bool(await Kit.until_free(shift)).is_true()
	assert_int(shift.run.shift_index).is_equal(0)
	assert_array(Kit.row_ids(shift)).is_equal([&"banana", &"yogurt"] as Array[StringName])
	assert_array(shift.tutorial.strip.hidden()).is_equal(RevealList.ELEMENTS)
	Kit.lay(shift, ANSWER)
	await Kit.Rush.checkout(shift)
	assert_int(shift.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	shift = await _reopen(shift)
	assert_bool(await Kit.until_armed(shift)).is_true()
	await Kit.frames(3)
	assert_str(String(shift.tutorial.step_id())).is_equal("G15")
	assert_object(shift.tutorial.overlay()).is_null()
	assert_bool(shift.tutorial.strip.shows(RevealList.CALENDAR)).is_true()
	assert_bool(shift.tutorial.strip.shows(RevealList.CART)).is_true()
	assert_bool(shift.tutorial.strip.shows(RevealList.REDRAW)).is_false()


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
	assert_array(second.tutorial.strip.hidden()).is_empty()
	second._cart_reveal.close()


## A veteran's replay (PLAY THE GUIDED SHIFT with an aisle completed, so a swap is open): NEXT
## goes on to YOUR BUILD, with no stop at the swap window the guided run keeps LOCKED (it would
## open with no line and DONE refused without a word).
func test_a_replay_with_a_swap_open_skips_the_swap_stop() -> void:
	get_tree().root.size = Kit.SIZES[0]
	var shift: ShiftScreen = await _screen()
	for aisle: AisleDefinition in shift._balance.aisles:
		if not aisle.base_cards.is_empty() and not aisle.capsule_cards.is_empty():
			for card: CardDefinition in aisle.capsule_cards:
				shift.profile.unlocked_items[card.id] = 0
			break
	TutorialFlags.finish_guide(shift.profile)
	TutorialFlags.request_replay(shift.profile)
	shift.save_profile()
	var board: StartBoard = Kit.start_guided(shift, SEED)
	assert_bool(shift.tutorial.is_active()).is_true()
	assert_int(StartSetupRules.swap_limit(shift.run, shift.profile)).is_greater(0)
	assert_bool(await Kit.until_step(shift, &"G3")).is_true()
	_open_boosters(board)
	assert_bool(await Kit.until_stocked(shift, board)).is_true()
	assert_bool(board.store.swap.is_live()).is_true()
	assert_bool(board.store.primary("click")).is_true()
	assert_bool(board.store.swap.active).is_false()
	assert_bool(await Kit.until_step(shift, &"G6")).is_true()
	_assert_callout(shift)
	# The same board with no tutorial has no lock.
	shift.tutorial._set_active(false)
	assert_bool(board.store.actions.locked(TutorialAnchors.SWAP_KEY)).is_false()


## The menu (and the board's ‹ TITLE) take a mouse click through the dim on every guided step,
## still dimmed and with no ring: a mouse player can pause or leave as Esc does.
func test_the_menu_and_title_take_a_click_through_the_dim() -> void:
	get_tree().root.size = Kit.SIZES[0]
	var shift: ShiftScreen = await _screen()
	var board: StartBoard = Kit.start_guided(shift, SEED)
	assert_bool(await Kit.until_step(shift, &"G3")).is_true()
	var title: Rect2 = board.anchor_rect(TutorialAnchors.TITLE)
	assert_bool(title.has_area()).is_true()
	_assert_passes(shift.tutorial.overlay(), title)
	_open_boosters(board)
	assert_bool(await Kit.until_stocked(shift, board)).is_true()
	board.store.primary()
	assert_bool(await Kit.until_step(shift, &"G6")).is_true()
	assert_bool(await Kit.open_store(shift, board)).is_true()
	assert_bool(await Kit.until_step(shift, &"G7")).is_true()
	var menu: Rect2 = shift.anchor_rect(TutorialAnchors.MENU)
	assert_bool(menu.has_area()).is_true()
	_assert_passes(shift.tutorial.overlay(), menu)
	Kit.press(shift)
	assert_bool(await Kit.until_step(shift, &"G8")).is_true()
	_assert_passes(shift.tutorial.overlay(), menu)


# --- Driving ------------------------------------------------------------------------------


## G10, the free planning: nothing of the week 1 strip shows yet; the first rule that works pops
## COMBO; Eggs last in a full row pops WASTED and is a rehearsal that misses (planning back, the
## row kept, no MISS, RETRY); a second miss, after a redraw, brings the ANSWER (the hand back as
## dealt, the redraw undone, the ghosts on the belt); the answer laid over its ghosts passes on
## to the machine.
func _play_shift_one(shift: ShiftScreen) -> void:
	assert_bool(await Kit.until_free(shift)).is_true()
	shift._scan.clear()
	assert_object(shift.tutorial.overlay()).is_null()
	assert_bool(shift._checkout_button.disabled).is_false()
	assert_bool(shift.guide.allows(TutorialActions.REDRAW)).is_true()
	assert_array(shift.tutorial.strip.hidden()).is_equal(RevealList.ELEMENTS)
	var dealt: Array[StringName] = _hand_ids(shift)
	Kit.place(shift, EGGS, 0)
	await Kit.frames(3)
	assert_bool(shift.run.guide_hints.is_empty()).is_true()  # A lone item: nothing to say.
	Kit.place(shift, YOGURT, 1)
	await _assert_bubble(shift, &"combo", 0)
	# The same seven as the answer with Eggs last: WASTED, 29€.
	Kit.lay(shift, WRONG)
	assert_int(shift.run.preview().total).is_less(shift.run.quota())
	await _assert_bubble(shift, &"wasted", 6)
	await Kit.Rush.checkout(shift)
	assert_bool(await Kit.until_step(shift, &"RETRY")).is_true()
	_assert_callout(shift)
	assert_int(shift.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_int(shift.run.shift_index).is_equal(0)
	assert_int(shift.run.write_ups).is_equal(0)
	assert_bool(shift.run.history.is_empty()).is_true()
	assert_array(Kit.row_ids(shift)).is_equal(_ids(WRONG))
	assert_int(shift.tutorial.misses()).is_equal(1)
	assert_array(shift.tutorial.strip.hidden()).is_equal(RevealList.ELEMENTS)  # A miss shows none.
	assert_bool(Kit.press(shift)).is_true()
	assert_bool(await Kit.until_free(shift)).is_true()
	# A redraw of basket 4 (Tea bags, left in it) is allowed though its key is not shown yet.
	shift._on_redraw_pressed()
	shift._on_basket_clicked(3)
	assert_bool(await Kit.until_free(shift)).is_true()
	await Kit.frames(3)
	assert_int(shift.run.redraws_used).is_equal(1)
	await Kit.Rush.checkout(shift)
	assert_bool(await Kit.until_step(shift, &"ANSWER")).is_true()
	_assert_callout(shift)
	assert_bool(shift.run.row.is_empty()).is_true()
	assert_int(shift.run.redraws_used).is_equal(0)
	assert_array(_hand_ids(shift)).is_equal(dealt)
	assert_bool(Kit.press(shift)).is_true()
	assert_bool(await Kit.until_free(shift)).is_true()
	var ghosts: AnswerGhosts = shift.tutorial.ghosts()
	assert_object(ghosts).is_not_null()
	assert_bool(ghosts.visible).is_true()
	assert_bool(ghosts.all_placed()).is_false()
	Kit.lay(shift, ANSWER)
	await Kit.frames(2)
	assert_bool(ghosts.all_placed()).is_true()
	assert_int(shift.run.preview().total).is_greater_equal(shift.run.quota())
	await Kit.Rush.checkout(shift)
	assert_str(String(shift.run.guide_step)).is_equal("G15")


## The machine (no line; the calendar and the Cart button have popped in), then shift 2's closing
## line (G15) on REDRAW, which shows from then on; the time card never opens by itself.
func _play_machine_and_shift_two(shift: ShiftScreen) -> void:
	var strip: Week1Strip = shift.tutorial.strip
	assert_int(shift.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	assert_bool(await Kit.until_armed(shift)).is_true()
	await Kit.frames(3)
	assert_object(shift.tutorial.overlay()).is_null()
	assert_bool(strip.shows(RevealList.CALENDAR)).is_true()
	assert_bool(strip.shows(RevealList.CART)).is_true()
	assert_array(strip.hidden()).is_equal(
		[RevealList.LOYALTY, RevealList.REDRAW, RevealList.WEEK, RevealList.MEDALS]
	)
	await _skip_machine(shift)
	assert_int(shift.run.shift_index).is_equal(1)
	assert_bool(await Kit.until_step(shift, &"G15")).is_true()
	_assert_callout(shift)
	assert_bool(shift._week.is_open()).is_false()
	assert_bool(strip.shows(RevealList.REDRAW)).is_true()
	assert_bool(strip.shows(RevealList.WEEK)).is_true()
	assert_bool(shift._stage.redraw_button.is_visible_in_tree()).is_true()
	assert_bool(shift.anchor_rect(TutorialAnchors.REDRAW).has_area()).is_true()
	assert_bool(Kit.press(shift)).is_true()
	await Kit.frames(4)
	assert_bool(shift._week.is_open()).is_false()


## NEW ITEMS chosen, its prizes skipped, the glide back over (the next shift's planning).
func _skip_machine(shift: ShiftScreen) -> void:
	assert_bool(await Kit.until_armed(shift)).is_true()
	assert_bool(shift._machine._choose(RewardMachine.Chute.NEW_ITEMS)).is_true()
	assert_bool(await Kit.until_armed(shift)).is_true()
	shift._machine.view.skip_bin.pressed.emit()
	shift._machine.view.fast_forward()
	await Kit.frames(2)
	shift._machine._end_return()


## The first week's hints after the guided part (2026-11-15): live on shift 2's planning, the
## ones shown on shift 1 kept with the run (saved, with what the strip revealed); none from week
## 2 on.
func _assert_week_hints(shift: ShiftScreen) -> void:
	assert_bool(shift.tutorial._hinting()).is_true()
	assert_array(shift.run.guide_hints).is_equal([&"combo", &"wasted"])
	var saved: RunSave = SaveService.new(_folder).load_run(ContentLookup.new(shift._balance))
	assert_array(saved.run.guide_hints).is_equal([&"combo", &"wasted"])
	assert_array(saved.run.guide_reveals).contains(
		[RevealList.CALENDAR, RevealList.CART, RevealList.REDRAW, RevealList.WEEK]
	)
	var week: int = WeekSchedule.length(shift._balance)
	shift.run.shift_index = week
	assert_bool(shift.tutorial._hinting()).is_false()
	shift.run.shift_index = 1
	await Kit.frames(2)


## Waits until the step's callout shows with `count` rings (at most 4 s of real time).
func _until_rings(shift: ShiftScreen, count: int) -> bool:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 4000:
		var overlay: TutorialOverlay = shift.tutorial.overlay()
		if overlay != null and overlay.ring_rects().size() == count:
			return true
		Kit._pump(shift)
		await Kit.frames(1)
	return false


## The hint bubble shows `hint_id`'s title over row slot `slot`, inside the screen.
func _assert_bubble(shift: ShiftScreen, hint_id: StringName, slot: int) -> void:
	await Kit.frames(3)
	var bubble: HintBubble = shift.tutorial.bubble()
	assert_object(bubble).is_not_null()
	if bubble == null:
		return
	var hint: PlanHint = null
	for each: PlanHint in TutorialScript.guided().hints:
		if each.id == hint_id:
			hint = each
	assert_bool(bubble.is_showing()).is_true()
	assert_str(bubble.title_text()).is_equal(hint.title)
	var rect: Rect2 = bubble.get_global_rect()
	var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(get_tree().root.size))
	assert_bool(screen.encloses(rect)).override_failure_message(str(rect)).is_true()
	var spot: Rect2 = shift.anchor_rect(StringName(TutorialAnchors.SPOT + str(slot)))
	assert_float(rect.end.y).is_less_equal(spot.position.y + 1.0)
	assert_bool(rect.intersects(spot)).is_false()


static func _ids(places: Array[int]) -> Array[StringName]:
	var hand: Array[StringName] = TutorialScript.guided().hand
	var ids: Array[StringName] = []
	for place: int in places:
		ids.append(hand[place])
	return ids


# --- Helpers ------------------------------------------------------------------------------


func _screen() -> ShiftScreen:
	var made: ShiftScreen = await Kit.screen(self)
	_screens.append(made)
	return made


## A guided run on shift 1's free planning (G10, after G7 and G8).
func _to_free() -> ShiftScreen:
	var shift: ShiftScreen = await _screen()
	assert_bool(await Kit.to_free(shift, SEED)).is_true()
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


## `overlay`'s shade lets a click at `rect`'s centre through (its passes), with no ring hole on
## it (the dim stays).
func _assert_passes(overlay: TutorialOverlay, rect: Rect2) -> void:
	assert_object(overlay).is_not_null()
	if overlay == null:
		return
	var shade: SpotlightShade = overlay.shade()
	var centre: Vector2 = rect.get_center()
	assert_bool(shade.lets_through(centre)).is_true()
	assert_bool(shade.in_hole(centre)).is_false()
	var local: Vector2 = shade.get_global_transform().affine_inverse() * centre
	assert_bool(shade._has_point(local)).is_false()


static func _hand_ids(shift: ShiftScreen) -> Array[StringName]:
	var ids: Array[StringName] = []
	for card: CardInstance in shift.run.hand_places():
		ids.append(card.definition.id if card != null else &"")
	return ids


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


## G3's move: Enter opens each booster waiting sealed on the counter, left to right (a first press
## while the boosters still fly skips their throws).
static func _open_boosters(board: StartBoard) -> void:
	Kit.open_boosters(board)
