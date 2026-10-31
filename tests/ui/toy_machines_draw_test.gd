extends GdUnitTestSuite
## A draw at the TOY MACHINES (#63): a click on an OK machine draws its key item first, saves it,
## the coins drop by the price, the floor label and FIGURINES count it, and the reveal shows the
## figurine (its sprite, or the art-pending box with its name), its name, aisle and stock line
## (the results' and the title's without a saved run: "In stock from your next run"; the title's
## with one: "In stock after your saved run", the saved run's index). The reveal's pieces are
## inside the window and don't overlap; the draw click can't close it (it arms after
## ResultsPanel.ARM_MS); OK closes it; the machines take no clicks while it is up. A failed save
## switches every machine OFF with the notice and shows no reveal. Saves and logs go to a
## temporary folder.

const Kit := preload("res://tests/ui/toy_test_kit.gd")

var _folder: String = ""
var _window_size: Vector2i
var _errors: Array[String] = []


func before_test() -> void:
	_folder = "user://test_toys_draw_%d" % Time.get_ticks_usec()
	_errors.clear()
	Kit.event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(Kit.SCREEN_RECT.size)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	Kit.remove(_folder)


func test_a_click_draws_the_key_item_and_reveals_it() -> void:
	var profile: ProfileState = Kit.profile(2, 3)
	var screen: ToyMachinesScreen = await _open(profile, false)
	var bakery: ToyMachineView = _machine(screen, &"bakery")
	bakery._gui_input(Kit.left_click())
	await _frames(3)
	assert_bool(profile.unlocked_items.has(&"baguette")).is_true()
	assert_int(profile.unlocked_items[&"baguette"]).is_equal(2)
	assert_int(profile.coins).is_equal(1)
	assert_str(screen.coins_text()).is_equal("1")
	assert_str(screen.machines()[4].floor_text()).is_equal("7 OF 8 LEFT")
	assert_str(screen.figurines_text()).is_equal("1/30")
	assert_int(bakery.capsule_count()).is_equal(7)
	# Saved at once.
	var saved: ProfileState = SaveService.new(_folder).load_profile()
	assert_int(saved.unlocked_items[&"baguette"]).is_equal(2)
	assert_int(saved.coins).is_equal(1)
	assert_int(Kit.events(_folder, "capsule").size()).is_equal(1)
	var reveal: ToyReveal = screen.reveal()
	assert_bool(reveal.visible).is_true()
	assert_str(reveal.name_label().text).is_equal("Baguette")
	assert_str(reveal.aisle_label().text).is_equal("Bakery")
	assert_str(reveal.stock_label().text).is_equal(CapsuleCounter.NEXT_RUN_LINE)
	var card: CardDefinition = Kit.aisle(Kit.balance(), &"bakery").capsule_cards[0]
	assert_object(reveal.figurine().texture).is_same(ArtStyle.item_sprite(card))
	if reveal.figurine().texture == ArtStyle.ITEM_PENDING:
		var printed: Label = reveal.figurine().get_node(ItemView.PRINTED_NAME) as Label
		assert_str(printed.text).is_equal("Baguette")
	await _frames(20)
	_assert_reveal_on_screen(reveal)


## After the key item, a draw is random among the items left; the reveal shows the drawn item's
## own art (a sprite such as Strawberries', or the art-pending box).
func test_a_later_draw_shows_the_drawn_items_art() -> void:
	var profile: ProfileState = Kit.profile(1, 1, {&"fruit_and_veg": 1})
	var screen: ToyMachinesScreen = await _open(profile, false)
	_machine(screen, &"fruit_and_veg")._gui_input(Kit.left_click())
	assert_int(profile.unlocked_items.size()).is_equal(2)
	var drawn: CardDefinition = null
	for card: CardDefinition in Kit.aisle(Kit.balance(), &"fruit_and_veg").capsule_cards:
		if card.id != &"fruit_salad" and profile.unlocked_items.has(card.id):
			drawn = card
	assert_object(drawn).is_not_null()
	assert_str(screen.reveal().name_label().text).is_equal(drawn.display_name)
	assert_object(screen.reveal().figurine().texture).is_same(ArtStyle.item_sprite(drawn))


func test_the_reveal_arms_after_the_draw_click_and_ok_closes_it() -> void:
	var profile: ProfileState = Kit.profile(3, 2)
	var screen: ToyMachinesScreen = await _open(profile, false)
	_machine(screen, &"cold_cases")._gui_input(Kit.left_click())
	var reveal: ToyReveal = screen.reveal()
	assert_bool(reveal.visible).is_true()
	assert_bool(reveal.is_armed()).is_false()
	# The draw click (and another one before arming) never closes it.
	reveal._gui_input(Kit.left_click())
	reveal._unhandled_key_input(Kit.key(KEY_ENTER))
	assert_bool(reveal.visible).is_true()
	assert_bool(reveal.ok_button().disabled).is_true()
	# The machines take no clicks while it is up.
	_machine(screen, &"pantry")._gui_input(Kit.left_click())
	assert_int(profile.coins).is_equal(2)
	assert_bool(profile.unlocked_items.has(&"sugar_cubes")).is_false()
	await await_millis(ResultsPanel.ARM_MS + 100)
	await _frames(2)
	assert_bool(reveal.is_armed()).is_true()
	assert_bool(reveal.ok_button().disabled).is_false()
	reveal.ok_button().pressed.emit()
	assert_bool(reveal.visible).is_false()
	# Back at the machines: a click anywhere closes the next reveal too.
	_machine(screen, &"pantry")._gui_input(Kit.left_click())
	assert_int(profile.coins).is_equal(1)
	await await_millis(ResultsPanel.ARM_MS + 100)
	await _frames(2)
	reveal._gui_input(Kit.left_click())
	assert_bool(reveal.visible).is_false()


## A title draw while a run is saved: the saved run's index, the saved-run line.
func test_a_title_draw_with_a_saved_run() -> void:
	var profile: ProfileState = Kit.profile(1, 4)
	var screen: ToyMachinesScreen = await _open(profile, true)
	_machine(screen, &"snacks")._gui_input(Kit.left_click())
	assert_int(profile.unlocked_items[&"crisps"]).is_equal(4)
	assert_str(screen.reveal().stock_label().text).is_equal(CapsuleCounter.AFTER_SAVED_RUN_LINE)
	# The last coin spent: the machines go dim with the notice under them.
	assert_int(_machine(screen, &"cold_cases").state()).is_equal(CapsuleCounter.State.BROKE)
	assert_int(screen.strip_kind()).is_equal(ToyMachinesScreen.Strip.BROKE)


func test_a_failed_save_switches_every_machine_off() -> void:
	var saves: SaveService = SaveService.new(
		_folder, func(message: String) -> void: _errors.append(message)
	)
	DirAccess.make_dir_recursive_absolute(saves.profile_path() + SaveService.TEMP_SUFFIX)
	var profile: ProfileState = Kit.profile(2, 2)
	var before_draw: Dictionary = profile.to_dictionary()
	var counter: CapsuleCounter = CapsuleCounter.new(
		profile, saves, Kit.balance(), Kit.event_log(), false, true
	)
	var screen: ToyMachinesScreen = await _open_counter(counter)
	_machine(screen, &"household")._gui_input(Kit.left_click())
	await _frames(2)
	assert_bool(screen.reveal().visible).is_false()
	assert_dict(profile.to_dictionary()).is_equal(before_draw)
	for machine: ToyMachineView in screen.machines():
		assert_int(machine.state()).is_equal(CapsuleCounter.State.OFF)
		assert_bool(machine.paper().visible).is_true()
	assert_int(screen.strip_kind()).is_equal(ToyMachinesScreen.Strip.OFF)
	assert_str(screen.coins_text()).is_equal("?")
	assert_int(_errors.size()).is_equal(1)
	assert_array(Kit.events(_folder, "capsule")).is_empty()


## The shelf: FIGURINE SHELF hides the machines and shows the drawn figurine; Back returns.
func test_the_shelf_opens_and_comes_back() -> void:
	var profile: ProfileState = Kit.profile(2, 2)
	var screen: ToyMachinesScreen = await _open(profile, false)
	_machine(screen, &"cold_cases")._gui_input(Kit.left_click())
	await await_millis(ResultsPanel.ARM_MS + 100)
	await _frames(2)
	screen.reveal().dismiss()
	screen.shelf_button().pressed.emit()
	assert_bool(screen.shelf().visible).is_true()
	assert_int(screen.shelf().figurines(0).size()).is_equal(1)
	# Machines can't be picked behind the shelf.
	_machine(screen, &"pantry")._gui_input(Kit.left_click())
	assert_int(profile.coins).is_equal(1)
	screen.shelf().back_button().pressed.emit()
	assert_bool(screen.shelf().visible).is_false()
	var closed: Array[int] = [0]
	screen.closed.connect(func() -> void: closed[0] += 1)
	screen.done_button().pressed.emit()
	assert_bool(screen.visible).is_false()
	assert_int(closed[0]).is_equal(1)


## Every piece inside the screen and clear of the others; NEW! alone is stuck over the figurine's
## top-right corner (the mock-up's place): its centre right of and above the figurine.
func _assert_reveal_on_screen(reveal: ToyReveal) -> void:
	var pieces: Array[Control] = reveal.pieces()
	var figure: Rect2 = reveal.figurine().get_global_rect()
	var burst: Vector2 = reveal.new_burst().get_global_rect().get_center()
	assert_float(burst.x).is_greater(figure.get_center().x + figure.size.x / 4.0)
	assert_float(burst.y).is_less(figure.position.y)
	# The rays end above the aisle and stock lines, so those stay readable.
	var rays: Rect2 = reveal.sunburst().get_global_rect()
	assert_float(rays.end.y).is_less_equal(reveal.aisle_label().get_global_rect().position.y)
	for index: int in range(pieces.size()):
		var rect: Rect2 = pieces[index].get_global_rect()
		(
			assert_bool(Kit.SCREEN_RECT.encloses(rect))
			. override_failure_message("%s %s" % [pieces[index], rect])
			. is_true()
		)
		for other: int in range(index):
			if pieces[index] == reveal.new_burst() and pieces[other] == reveal.figurine():
				continue
			(
				assert_bool(rect.intersects(pieces[other].get_global_rect()))
				. override_failure_message("%s overlaps %s" % [pieces[index], pieces[other]])
				. is_false()
			)


func _machine(screen: ToyMachinesScreen, id: StringName) -> ToyMachineView:
	for machine: ToyMachineView in screen.machines():
		if machine.aisle().id == id:
			return machine
	return null


func _open(profile: ProfileState, saved_run: bool) -> ToyMachinesScreen:
	var counter: CapsuleCounter = CapsuleCounter.new(
		profile, SaveService.new(_folder), Kit.balance(), Kit.event_log(), saved_run, true
	)
	return await _open_counter(counter)


func _open_counter(counter: CapsuleCounter) -> ToyMachinesScreen:
	var screen: ToyMachinesScreen = ToyMachinesScreen.new()
	add_child(screen)
	auto_free(screen)
	screen.open(counter, Kit.balance())
	await _frames(3)
	return screen


func _frames(count: int) -> void:
	for frame: int in range(count):
		await await_idle_frame()
