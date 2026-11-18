extends GdUnitTestSuite
## The quick tutorials (QuickTutorials; reworked after play test 1, 2026-11-15): on a run's opening
## board, the first time SWAP, RESTOCK or BADGE PINS is due, one NEW callout shows (its flag set
## and saved as it shows), closes on GOT IT or the ringed move, and the tutorial's hint (SWAP's
## one, since v1.40) pops in a bubble the first time its moment comes. Once per profile; one at
## a time, SWAP first; never on the guided run's board. The pages run frozen on their own
## clock: the tests step them.

const SCREEN := preload("res://ui/shift_screen.tscn")
const SEED := 20261103
const STEP := 1.0 / 60.0

var _folder: String


func before_test() -> void:
	_folder = "user://tutorial_quick_test_%d" % Time.get_ticks_usec()
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_event_log().use_folder(_folder)


func after_test() -> void:
	await get_tree().process_frame
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file))
		DirAccess.remove_absolute(_folder)


## SWAP (2 aisles complete): its callout once the page is stocked, ringing the crate; opening the
## swap window closes it and pops its first hint; a booster and a swap pop the next two; the
## flag is saved; the next run's board shows no callout.
func test_swap_shows_once_then_its_hints() -> void:
	var screen: ShiftScreen = await _screen(2)
	var page: BoosterPage = screen._cart_reveal.board.store
	var quick: QuickTutorials = screen.tutorial.quick
	assert_object(quick.showing()).is_null()
	_stocked(page)
	assert_bool(await _until_shown(quick, &"swap")).is_true()
	assert_bool(TutorialFlags.quick_seen(screen.profile, TutorialFlags.QUICK_SWAP)).is_true()
	var saved: ProfileState = SaveService.new(_folder).load_profile()
	assert_bool(TutorialFlags.quick_seen(saved, TutorialFlags.QUICK_SWAP)).is_true()
	assert_array(quick.overlay().view().rings.map(_mark_id)).contains([TutorialAnchors.CRATE])
	assert_int(quick.overlay().ring_rects().size()).is_equal(1)
	assert_bool(quick.overlay().ring_rects()[0].has_area()).is_true()
	assert_bool(page.swap.open_window(false)).is_true()
	await _frames(2)
	assert_object(quick.showing()).is_null()
	assert_array(_logged("tutorial_hint")).is_empty()  # The window says nothing by itself.
	_run(page, 2.0)
	page.swap.open_booster(0, "key")
	await _frames(2)
	assert_bool(quick.bubble().is_showing()).is_true()  # Its one hint: drag a card on a regular.
	_run(page, 3.0)
	page.swap._apply(_card_piece(page), 1, "drag")
	await _frames(2)
	assert_array(_logged("tutorial_hint")).is_equal(["swap_drag"])
	assert_array(_logged("quick_step")).is_equal(["SA1"])
	page.swap.close(true)
	_run(page, 2.0)
	# The next run's board: SWAP was seen, nothing shows.
	screen.start_new_run(SEED + 1, true, true)
	var next: BoosterPage = screen._cart_reveal.board.store
	next.frozen = true
	_stocked(next)
	await _frames(4)
	assert_object(quick.showing()).is_null()


## RESTOCK (3 aisles complete): it waits behind SWAP, shows once SWAP's GOT IT closes it, rings
## the key; arming closes it, and nothing more is said (its hints went in v1.40).
func test_restock_follows_swap() -> void:
	var screen: ShiftScreen = await _screen(3)
	var page: BoosterPage = screen._cart_reveal.board.store
	var quick: QuickTutorials = screen.tutorial.quick
	_stocked(page)
	assert_bool(await _until_shown(quick, &"swap")).is_true()
	assert_bool(TutorialFlags.quick_seen(screen.profile, TutorialFlags.QUICK_RESTOCK)).is_false()
	quick.overlay().button_pressed.emit()  # GOT IT.
	assert_bool(await _until_shown(quick, &"restock")).is_true()
	assert_array(quick.overlay().view().rings.map(_mark_id)).contains([TutorialAnchors.RESTOCK])
	assert_bool(quick.overlay().ring_rects()[0].has_area()).is_true()
	assert_bool(page.counter.arm_restock()).is_true()
	await _frames(2)
	assert_object(quick.showing()).is_null()
	assert_bool(page.counter.restock(0)).is_true()
	await _frames(2)
	assert_array(_logged("tutorial_hint")).is_empty()
	assert_array(_logged("quick_step")).is_equal(["SA1", "R1"])


## BADGE PINS (a pin earned): page 2's held packs bring its callout; wearing a pin closes it,
## and nothing more is said (its hints went in v1.40).
func test_pins_show_on_page_two() -> void:
	var screen: ShiftScreen = await _screen(0, true)
	var board: StartBoard = screen._cart_reveal.board
	var page: BoosterPage = board.store
	var quick: QuickTutorials = screen.tutorial.quick
	_stocked(page)
	await _frames(3)
	assert_object(quick.showing()).is_null()
	board.show_page(2, "tab")
	board._end_slide()
	var staff: BuildPage = board.staff
	staff.frozen = true
	for _step: int in 240:
		staff.advance(STEP)
	assert_bool(staff.packs_held()).is_true()
	assert_bool(await _until_shown(quick, &"pins")).is_true()
	var pin: PinDefinition = staff.pins.owned()[0]
	staff.pins.open(0.0)
	staff.pins.toggle(pin)
	await _frames(2)
	assert_object(quick.showing()).is_null()
	staff.pins.toggle(pin)  # Taken off: no hint.
	staff.pins.toggle(pin)
	assert_bool(staff.pins.confirm()).is_true()
	await _frames(2)
	assert_array(_logged("tutorial_hint")).is_empty()
	assert_array(_logged("quick_step")).is_equal(["P1"])


## The guided run's board (its director holds it) never shows a quick tutorial.
func test_the_guided_board_shows_none() -> void:
	var screen: ShiftScreen = auto_free(SCREEN.instantiate())
	add_child(screen)
	await get_tree().process_frame
	screen.start_new_run(SEED, true, true, true)
	assert_bool(screen.tutorial.is_active()).is_true()
	await _frames(6)
	assert_object(screen.tutorial.quick.showing()).is_null()


## A screen whose profile has `completed` aisles complete (and a pin earned with `pin`), its new
## run's board opened (frozen on its clock).
func _screen(completed: int, pin: bool = false) -> ShiftScreen:
	var screen: ShiftScreen = auto_free(SCREEN.instantiate())
	add_child(screen)
	await get_tree().process_frame
	screen.profile.set_reduced_motion(true)
	TutorialFlags.mark_seen(screen.profile, TutorialFlags.GUIDE_DONE)
	for index: int in screen._balance.aisles.size():
		var aisle: AisleDefinition = screen._balance.aisles[index]
		var count: int = (
			aisle.capsule_cards.size()
			if index < completed
			else (
				mini(4, aisle.capsule_cards.size())
				if aisle.base_cards.is_empty() and completed > 0
				else 0
			)
		)
		for card: CardDefinition in aisle.capsule_cards.slice(0, count):
			screen.profile.unlocked_items[card.id] = 0
	if pin:
		var earned: PinDefinition = load("res://data/pins/double_checkout.tres") as PinDefinition
		screen.profile.unlocked_pins.append(earned.id)
	screen.save_profile()
	screen.start_new_run(SEED, true, true)
	screen._cart_reveal.board.store.frozen = true
	return screen


## Waits (real frames, at most 3 s) until `quick` shows tutorial `id`'s callout; whether it did.
func _until_shown(quick: QuickTutorials, id: StringName) -> bool:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < 3000:
		await get_tree().process_frame
		var shown: QuickTutorial = quick.showing()
		if shown != null and shown.id == id and quick.overlay().is_showing():
			await _frames(2)
			return true
	return false


static func _mark_id(mark: StepView.Mark) -> StringName:
	return mark.id


static func _card_piece(page: BoosterPage) -> SwapPiece:
	for piece: SwapPiece in page.swap.pieces:
		if not piece.regular and page.swap.drop_reason(piece, 1) == "":
			return piece
	return null


## Rolls up, opens every booster and lets STOCKED! come.
static func _stocked(page: BoosterPage) -> void:
	page.openings.roll_up()
	page.openings.end_arrival()
	page.openings.open_all("key")
	_run(page, 8.0)


static func _run(page: BoosterPage, seconds: float) -> void:
	var left: float = seconds
	while left > 0.0001:
		page.advance(minf(STEP, left))
		left -= STEP


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
