extends GdUnitTestSuite
## The one-time tips (TipScheduler, WP-10; 7 tips and one per planning since v1.40): a planning
## shows at most TipScheduler.PER_PLANNING, each once per profile (its flag saved, tip_shown
## logged), on a card that dims and blocks nothing; a tip reveals what it rings on a stripped
## first week; the results show T14 (the most WASTED giver named) then T15; the guided part shows
## none.

const SCREEN := preload("res://ui/shift_screen.tscn")
const SEED := 20261115

var _folder: String


func before_test() -> void:
	_folder = "user://tutorial_tips_test_%d" % Time.get_ticks_usec()
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_event_log().use_folder(_folder)


func after_test() -> void:
	await get_tree().process_frame
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file))
		DirAccess.remove_absolute(_folder)


## A planning with two tips due (a forgiven miss, T9, and a perk taken, T11): the first shows on
## a card with no dim that takes no click, its flag set and saved; GOT IT closes it and no other
## shows on that planning (PER_PLANNING is 1 since v1.40); the next planning shows the second.
func test_a_planning_shows_one_tip() -> void:
	var screen: ShiftScreen = await _screen()
	screen.run.shift_index = 1
	var tips: TipScheduler = screen.tutorial.tips
	assert_int(TipScheduler.PER_PLANNING).is_equal(1)
	assert_bool(await _until_tip(tips, 600)).is_false()  # Nothing to say: no tip.
	tips._add(TipDefinition.PERK_TAKEN)
	tips._add(TipDefinition.FIRST_MISS)
	assert_bool(await _until_tip(tips)).is_true()
	var first: TipDefinition = tips.showing()
	assert_str(String(first.id)).is_equal("T9")  # The lower priority number first.
	var overlay: TutorialOverlay = tips.overlay()
	assert_bool(overlay.view().blocks).is_false()
	assert_bool(overlay.view().dim).is_false()
	assert_int(overlay.shade().mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	var card: Rect2 = overlay.callout().get_global_rect()
	assert_bool(screen.get_global_rect().grow(1.0).encloses(card)).is_true()
	assert_bool(TutorialFlags.tip_seen(screen.profile, first.id)).is_true()
	var saved: ProfileState = SaveService.new(_folder).load_profile()
	assert_bool(TutorialFlags.tip_seen(saved, first.id)).is_true()
	tips.overlay().button_pressed.emit()
	await _frames(2)
	assert_bool(await _until_tip(tips, 600)).is_false()
	assert_array(_logged("tip_shown")).is_equal(["T9"])
	screen.run.shift_index = 2
	assert_bool(await _until_tip(tips)).is_true()
	assert_str(String(tips.showing().id)).is_equal("T11")
	assert_array(_logged("tip_shown")).is_equal(["T9", "T11"])


## A tip shows what it points at (the week 1 strip, v1.40): on a guided run's first week the
## LOYALTY chip is hidden until T11 rings it, then stays.
func test_a_tip_reveals_what_it_rings() -> void:
	var screen: ShiftScreen = await _screen([&"T11"])
	screen.run.guided = true
	screen.run.guide_step = TutorialDirector.DONE
	screen.run.shift_index = 1
	await _frames(3)
	var strip: Week1Strip = screen.tutorial.strip
	var tips: TipScheduler = screen.tutorial.tips
	assert_bool(strip.shows(RevealList.LOYALTY)).is_false()
	assert_bool(screen._stage.loyalty_card.visible).is_false()
	assert_bool(await _until_tip(tips, 600)).is_false()
	tips._add(TipDefinition.PERK_TAKEN)
	assert_bool(await _until_tip(tips)).is_true()
	assert_str(String(tips.showing().id)).is_equal("T11")
	assert_bool(strip.shows(RevealList.LOYALTY)).is_true()
	assert_bool(screen._stage.loyalty_card.visible).is_true()
	assert_array(tips.overlay().ring_rects()).is_not_empty()


## The results of a lost run that paid coins: T14 names the most WASTED giver, then T15.
func test_the_results_show_the_lost_run_tips() -> void:
	var screen: ShiftScreen = await _screen([&"T14", &"T15"])
	var tips: TipScheduler = screen.tutorial.tips
	tips._tally = {&"eggs": 2}
	screen._results.visible = true
	screen.guide.emit(
		TutorialEvents.RESULTS, {TutorialEvents.ARG_WON: false, TutorialEvents.ARG_COINS: 4}
	)
	assert_bool(await _until_tip(tips)).is_true()
	assert_str(String(tips.showing().id)).is_equal("T14")
	var eggs: String = ContentLookup.new(screen._balance).card("eggs").display_name
	assert_str(tips.overlay().view().body).contains(eggs)
	tips.overlay().button_pressed.emit()
	assert_bool(await _until_tip(tips)).is_true()
	assert_str(String(tips.showing().id)).is_equal("T15")
	screen._results.visible = false
	await _frames(2)
	assert_object(tips.showing()).is_null()


## The guided part (its director holds the screen) shows no one-time tip.
func test_the_guided_part_shows_none() -> void:
	var screen: ShiftScreen = auto_free(SCREEN.instantiate())
	add_child(screen)
	await get_tree().process_frame
	screen.start_new_run(SEED, true, true, true)
	assert_bool(screen.tutorial.is_active()).is_true()
	assert_bool(await _until_tip(screen.tutorial.tips, 600)).is_false()


## A screen on a normal run's planning (the guided run done); every tip seen but `left` (empty:
## none seen).
func _screen(left: Array[StringName] = []) -> ShiftScreen:
	var screen: ShiftScreen = auto_free(SCREEN.instantiate())
	add_child(screen)
	await get_tree().process_frame
	screen.profile.set_reduced_motion(true)
	TutorialFlags.mark_seen(screen.profile, TutorialFlags.GUIDE_DONE)
	if not left.is_empty():
		for tip: TipDefinition in TipList.shared().tips:
			if not left.has(tip.id):
				TutorialFlags.mark_tip(screen.profile, tip.id)
	screen.save_profile()
	screen.start_new_run(SEED, true)
	await _frames(2)
	return screen


## Waits (real frames, at most `ms`) until a tip shows; whether one did.
func _until_tip(tips: TipScheduler, ms: int = 3000) -> bool:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < ms:
		await get_tree().process_frame
		if tips.showing() != null and tips.overlay() != null and tips.overlay().is_showing():
			return true
	return false


func _frames(count: int) -> void:
	for _frame: int in count:
		await get_tree().process_frame


## The `id` of every logged event of type `type`, in order.
func _logged(type: String) -> Array[String]:
	var found: Array[String] = []
	for file_name: String in DirAccess.get_files_at(_folder):
		if not file_name.ends_with(".jsonl"):
			continue
		var text: String = FileAccess.get_file_as_string(_folder.path_join(file_name))
		for line: String in text.split("\n", false):
			var parsed: Variant = JSON.parse_string(line)
			if parsed is Dictionary and str((parsed as Dictionary).get("type", "")) == type:
				found.append(str((parsed as Dictionary).get("id", "")))
	return found


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
