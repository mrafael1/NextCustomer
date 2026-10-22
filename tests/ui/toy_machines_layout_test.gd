extends GdUnitTestSuite
## The TOY MACHINES' layout (#63, look A; memory: UI tests check on-screen geometry): with six
## machines every machine is inside the 1280x720 window and none overlaps another, each sign's
## glyph and name fit its 144 px board, each floor label is inside the screen under its machine,
## and the chips, the board, the hint or notice and both buttons are inside and clear of the
## machines; three machines centre in 0..1000. Every state shows by more than colour: OK (price,
## pointing hand), EMPTY (the ALL COLLECTED rosette, no price, no click), BROKE (0 coins: dimmed,
## arrow cursor, the notice), OFF (OUT OF ORDER paper, COINS ?, the notice); the full collection's
## banner and hint; a fresh profile. No player-facing text says "gacha". Saves and logs go to a
## temporary folder.

const Kit := preload("res://tests/ui/toy_test_kit.gd")

var _folder: String = ""
var _window_size: Vector2i


func before_test() -> void:
	_folder = "user://test_toys_layout_%d" % Time.get_ticks_usec()
	Kit.event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(Kit.SCREEN_RECT.size)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	Kit.remove(_folder)


func test_six_machines_fit_the_screen_without_overlaps() -> void:
	var profile: ProfileState = Kit.profile(
		2, 4, {&"cold_cases": 1, &"pantry": 2, &"household": 1, &"fruit_and_veg": 3}
	)
	var screen: ToyMachinesScreen = await _open(profile)
	var machines: Array[ToyMachineView] = screen.machines()
	assert_int(machines.size()).is_equal(6)
	var rects: Array[Rect2] = []
	for machine: ToyMachineView in machines:
		var rect: Rect2 = Rect2(machine.global_position, ToyMachineView.SIZE)
		assert_bool(Kit.SCREEN_RECT.encloses(rect)).override_failure_message(str(rect)).is_true()
		for other: Rect2 in rects:
			assert_bool(rect.intersects(other)).is_false()
		rects.append(rect)
		# The glyph and the name fit the board, inside its band.
		var sign_rect: Rect2 = machine.sign_rect()
		var name_rect: Rect2 = Kit.rect(machine.sign_label())
		(
			assert_bool(sign_rect.grow(0.5).encloses(name_rect))
			. override_failure_message(
				"%s %s in %s" % [machine.sign_label().text, name_rect, sign_rect]
			)
			. is_true()
		)
		var text_width: float = machine.sign_label().get_minimum_size().x
		(
			assert_float(text_width + ToyMachineView.GLYPH_SIZE.x + ToyMachineView.SIGN_GAP)
			. is_less_equal(ToyMachineView.SIZE.x - 2.0 * ToyMachineView.SIGN_PADDING)
		)
	# Floor labels: inside the screen, under their machine, centred on it.
	var floor_labels: Array[Label] = screen.floor_labels()
	for index: int in range(machines.size()):
		var label_rect: Rect2 = (floor_labels[index].get_parent() as Control).get_global_rect()
		assert_bool(Kit.SCREEN_RECT.encloses(label_rect)).is_true()
		assert_float(label_rect.position.y).is_greater_equal(rects[index].end.y)
		assert_float(absf(label_rect.get_center().x - rects[index].get_center().x)).is_less(1.5)
		for other: Rect2 in rects:
			assert_bool(label_rect.intersects(other)).is_false()
	assert_str(floor_labels[0].text).is_equal("1 of 2 left")
	assert_str(floor_labels[1].text).is_equal("All 2 collected")
	assert_str(floor_labels[3].text).is_equal("5 of 8 left")
	# Chips, board, hint and buttons: inside, clear of the machines.
	var parts: Array[Rect2] = [
		screen.coins_chip().get_global_rect(),
		(screen.figurines_label().get_parent().get_parent() as Control).get_global_rect(),
		Kit.rect(screen.hint_label()),
		Kit.rect(screen.shelf_button()),
		Kit.rect(screen.done_button()),
	]
	assert_bool(screen.hint_label().visible).is_true()
	assert_bool(screen.notice_panel().visible).is_false()
	assert_str(screen.hint_label().text).is_equal("Pick a machine: 1 coin a capsule.")
	for part: Rect2 in parts:
		assert_bool(Kit.SCREEN_RECT.encloses(part)).override_failure_message(str(part)).is_true()
		for machine: Rect2 in rects:
			assert_bool(part.intersects(machine)).override_failure_message(str(part)).is_false()
	assert_bool(parts[3].intersects(parts[4])).is_false()
	assert_bool(parts[0].intersects(parts[1])).is_false()
	assert_str(screen.coins_label().text).is_equal("2")
	assert_str(screen.figurines_label().text).is_equal("7 / 30")
	# The machines stand left of the doors.
	assert_float(rects[-1].end.x).is_less_equal(1006.0)


## The FIGURINES chip counts the capsule items held; the globe holds one capsule per item left,
## eight at most.
func test_the_globe_shows_the_capsules_left() -> void:
	var screen: ToyMachinesScreen = await _open(Kit.profile(1, 1, {&"bakery": 1}))
	var by_id: Dictionary = {}
	for machine: ToyMachineView in screen.machines():
		by_id[machine.aisle().id] = machine.capsule_count()
	assert_int(by_id[&"cold_cases"]).is_equal(2)
	assert_int(by_id[&"bakery"]).is_equal(7)
	assert_int(by_id[&"fruit_and_veg"]).is_equal(8)


func test_three_machines_centre_left_of_the_doors() -> void:
	var balance: BalanceDefinition = Kit.balance_with_aisles(3)
	var screen: ToyMachinesScreen = await _open(Kit.profile(1, 1), balance)
	var machines: Array[ToyMachineView] = screen.machines()
	assert_int(machines.size()).is_equal(3)
	var left: float = machines[0].global_position.x
	var right: float = machines[2].global_position.x + ToyMachineView.SIZE.x
	assert_float((left + right) / 2.0).is_equal_approx(500.0, 1.0)
	assert_float(machines[1].global_position.x - left).is_equal(ToyMachinesScreen.MACHINE_PITCH)
	assert_str(screen.figurines_label().text).is_equal("0 / 7")


func test_ok_and_empty_machines() -> void:
	var screen: ToyMachinesScreen = await _open(Kit.profile(3, 2, {&"pantry": 2}))
	var ok: ToyMachineView = _machine(screen, &"cold_cases")
	assert_int(ok.state()).is_equal(CapsuleCounter.State.OK)
	assert_bool(ok.price_label().visible).is_true()
	assert_int(ok.mouse_default_cursor_shape).is_equal(Control.CURSOR_POINTING_HAND)
	(
		assert_bool(
			Rect2(ok.global_position, ToyMachineView.SIZE).encloses(
				ok.price_label().get_global_rect()
			)
		)
		. is_true()
	)
	var empty: ToyMachineView = _machine(screen, &"pantry")
	assert_int(empty.state()).is_equal(CapsuleCounter.State.EMPTY)
	assert_bool(empty.rosette().visible).is_true()
	assert_bool(empty.price_label().visible).is_false()
	assert_int(empty.capsule_count()).is_equal(0)
	assert_int(empty.mouse_default_cursor_shape).is_equal(Control.CURSOR_ARROW)
	var picks: Array[int] = [0]
	empty.picked.connect(func(_aisle: AisleDefinition) -> void: picks[0] += 1)
	empty._gui_input(Kit.left_click())
	assert_int(picks[0]).is_equal(0)
	assert_int(screen.counter().profile.coins).is_equal(3)
	# Hover lifts an OK machine only.
	ok._on_hover(true)
	assert_bool(ok.is_lifted()).is_true()
	empty._on_hover(true)
	assert_bool(empty.is_lifted()).is_false()


func test_zero_coins_dims_the_machines_and_shows_the_notice() -> void:
	var screen: ToyMachinesScreen = await _open(Kit.profile(0, 3, {&"snacks": 1}))
	for machine: ToyMachineView in screen.machines():
		assert_int(machine.state()).is_equal(CapsuleCounter.State.BROKE)
		assert_int(machine.mouse_default_cursor_shape).is_equal(Control.CURSOR_ARROW)
		assert_float(machine._art.modulate.r).is_less(1.0)
		assert_bool(machine.price_label().visible).is_true()
	assert_bool(screen.notice_panel().visible).is_true()
	assert_str(screen.notice_label().text).is_equal(ToyMachinesScreen.BROKE_NOTICE)
	assert_bool(screen.hint_label().visible).is_false()
	_assert_notice_on_screen(screen)


func test_cant_save_switches_every_machine_off() -> void:
	var profile: ProfileState = Kit.profile(4, 3, {&"cold_cases": 2})
	var counter: CapsuleCounter = CapsuleCounter.new(
		profile, SaveService.new(_folder), Kit.balance(), Kit.event_log(), false, false
	)
	var screen: ToyMachinesScreen = await _open_counter(counter, Kit.balance())
	for machine: ToyMachineView in screen.machines():
		assert_int(machine.state()).is_equal(CapsuleCounter.State.OFF)
		assert_bool(machine.paper().visible).is_true()
		assert_bool(machine.price_label().visible).is_false()
		(
			assert_bool(
				Rect2(machine.global_position, ToyMachineView.SIZE).encloses(
					machine.paper().get_child(0).get_global_rect()
				)
			)
			. is_true()
		)
	assert_str(screen.coins_label().text).is_equal("?")
	assert_str(screen.notice_label().text).is_equal(ToyMachinesScreen.OFF_NOTICE)
	assert_str(screen.figurines_label().text).is_equal("2 / 30")
	_assert_notice_on_screen(screen)


func test_the_full_collection() -> void:
	var screen: ToyMachinesScreen = await _open(Kit.profile(5, 9, Kit.full_counts()))
	for machine: ToyMachineView in screen.machines():
		assert_int(machine.state()).is_equal(CapsuleCounter.State.EMPTY)
		assert_bool(machine.rosette().visible).is_true()
	assert_str(screen.banner_label().text).is_equal(ToyMachinesScreen.FULL_BANNER)
	assert_bool(Kit.SCREEN_RECT.encloses(Kit.rect(screen.banner_label()))).is_true()
	assert_float(screen.banner_label().get_minimum_size().x).is_less_equal(
		ToyMachinesScreen.BANNER_RECT.size.x
	)
	assert_str(screen.hint_label().text).is_equal(ToyMachinesScreen.FULL_HINT)
	assert_bool(screen.notice_panel().visible).is_false()
	assert_str(screen.figurines_label().text).is_equal("30 / 30")
	assert_str(screen.floor_labels()[3].text).is_equal("All 8 collected")
	assert_bool(screen.shelf_button().visible).is_true()
	assert_bool(screen.done_button().visible).is_true()


func test_a_fresh_profile() -> void:
	var screen: ToyMachinesScreen = await _open(Kit.profile(1, 1))
	for machine: ToyMachineView in screen.machines():
		assert_int(machine.state()).is_equal(CapsuleCounter.State.OK)
	assert_str(screen.figurines_label().text).is_equal("0 / 30")
	assert_str(screen.banner_label().text).is_empty()


## No player-facing text says "gacha", in the copy or in any label in any state.
func test_no_gacha_anywhere() -> void:
	for text: String in ToyMachinesScreen.copy():
		assert_bool(text.to_lower().contains("gacha")).override_failure_message(text).is_false()
	var counts: Array[Dictionary] = [{}, {&"pantry": 2}, Kit.full_counts()]
	for coins: int in [0, 2]:
		for collected: Dictionary in counts:
			var screen: ToyMachinesScreen = await _open(Kit.profile(coins, 2, collected))
			screen._open_shelf()
			for label: Label in Kit.labels(screen):
				assert_bool(label.text.to_lower().contains("gacha")).is_false()


func _assert_notice_on_screen(screen: ToyMachinesScreen) -> void:
	var notice: Rect2 = screen.notice_panel().get_global_rect()
	assert_bool(Kit.SCREEN_RECT.encloses(notice)).is_true()
	for machine: ToyMachineView in screen.machines():
		(
			assert_bool(notice.intersects(Rect2(machine.global_position, ToyMachineView.SIZE)))
			. is_false()
		)
	assert_bool(notice.intersects(Kit.rect(screen.shelf_button()))).is_false()
	assert_bool(notice.intersects(Kit.rect(screen.done_button()))).is_false()


func _machine(screen: ToyMachinesScreen, id: StringName) -> ToyMachineView:
	for machine: ToyMachineView in screen.machines():
		if machine.aisle().id == id:
			return machine
	return null


func _open(profile: ProfileState, balance: BalanceDefinition = null) -> ToyMachinesScreen:
	var used: BalanceDefinition = balance if balance != null else Kit.balance()
	var counter: CapsuleCounter = CapsuleCounter.new(
		profile, SaveService.new(_folder), used, Kit.event_log(), false, true
	)
	return await _open_counter(counter, used)


func _open_counter(counter: CapsuleCounter, balance: BalanceDefinition) -> ToyMachinesScreen:
	var screen: ToyMachinesScreen = ToyMachinesScreen.new()
	add_child(screen)
	auto_free(screen)
	screen.open(counter, balance)
	for frame: int in range(3):
		await await_idle_frame()
	return screen
