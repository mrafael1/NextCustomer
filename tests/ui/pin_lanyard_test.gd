extends GdUnitTestSuite
## The run's badge pins on the name badge's lanyard (PinLanyard, mock-up shift_scene_polish_v2
## section 3, variant C) on the real shift screen: hidden with no pin worn; one or two pins laid
## out on the badge inside the window, clear of the monitor's screen, the receipt and the top bar
## (at 1280x720 and at a larger window, where the stage is centred); a hovered pin's card (name,
## rule, charges left) inside the window and off the monitor's screen; a click keeps it open, a
## click elsewhere closes it; the card pops in, at once under reduced motion. The real saves and
## logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const PRICE_GUN := "res://data/pins/price_gun.tres"
const EXPRESS_LANE := "res://data/pins/express_lane.tres"
const DAY_OFF := "res://data/pins/day_off.tres"
## The window sizes the layout is checked at.
const WINDOWS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 1000)]

var _folder: String = ""
var _window_size: Vector2i = Vector2i.ZERO
var _runner: GdUnitSceneRunner


func before_test() -> void:
	_folder = "user://test_pin_lanyard_%d" % Time.get_ticks_usec()
	_window_size = get_tree().root.size
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_no_pin_hides_the_badge() -> void:
	var screen: ShiftScreen = await _screen([])
	var lanyard: PinLanyard = screen._stage.pin_lanyard
	assert_bool(lanyard.visible).is_false()
	assert_array(lanyard.faces()).is_empty()
	assert_bool(lanyard.card().visible).is_false()


## One pin sits centred on the badge, two side by side; the badge, its pins and its hook stay
## inside the window, the badge clear of the monitor's screen, the receipt and the top bar, and the
## hook on the monitor's bezel, at each window size.
func test_one_and_two_pins_are_laid_out_clear() -> void:
	for window: Vector2i in WINDOWS:
		get_tree().root.size = window
		for pins: Array in [[PRICE_GUN], [PRICE_GUN, EXPRESS_LANE]]:
			var screen: ShiftScreen = await _screen(pins)
			var lanyard: PinLanyard = screen._stage.pin_lanyard
			var where: String = "%s, %d pins" % [window, pins.size()]
			assert_bool(lanyard.is_visible_in_tree()).override_failure_message(where).is_true()
			assert_int(lanyard.faces().size()).is_equal(pins.size())
			var view: Rect2 = screen.get_viewport_rect()
			var badge: Rect2 = _global(lanyard, lanyard.badge_rect())
			var shadowed: Rect2 = badge.grow_individual(0, 0, 4, 4)
			(
				assert_bool(view.encloses(lanyard.get_global_rect()))
				. override_failure_message(where)
				. is_true()
			)
			var monitor_screen: Rect2 = _on_stage(screen, ShiftStage.MONITOR_SCREEN_RECT)
			(
				assert_bool(shadowed.intersects(monitor_screen))
				. override_failure_message(where)
				. is_false()
			)
			assert_bool(lanyard.get_global_rect().intersects(monitor_screen)).is_false()
			assert_bool(shadowed.intersects(screen._receipt.get_global_rect())).is_false()
			(
				assert_bool(
					lanyard.get_global_rect().intersects(screen._stage.top_bar.get_global_rect())
				)
				. override_failure_message(where)
				. is_false()
			)
			assert_bool(shadowed.intersects(_on_stage(screen, ShiftStage.BAG_RECT))).is_false()
			var hook: Rect2 = _global(lanyard, PinLanyard.HOOK)
			assert_bool(hook.intersects(_on_stage(screen, ShiftStage.MONITOR_RECT))).is_true()
			var faces: Array[PinFace] = lanyard.faces()
			for index: int in faces.size():
				var face: Rect2 = faces[index].get_global_rect()
				assert_bool(badge.encloses(face)).override_failure_message(where).is_true()
				assert_bool(view.encloses(face)).is_true()
				assert_bool(lanyard.hits()[index].get_global_rect() == face).is_true()
				assert_str(faces[index].letters()).is_equal(
					(load(pins[index]) as PinDefinition).face_text
				)
			if faces.size() == 1:
				var middle: float = faces[0].get_global_rect().get_center().x
				assert_float(middle).is_equal_approx(badge.get_center().x, 1.0)
			else:
				var left: Rect2 = faces[0].get_global_rect()
				var right: Rect2 = faces[1].get_global_rect()
				assert_bool(left.intersects(right)).is_false()
				assert_float(left.position.y).is_equal(right.position.y)


## Hovering each pin (the real pointer) shows its card: its name, its rule and its charges left,
## inside the window and off the monitor's screen, its tail at the pin; leaving closes it.
func test_hovering_a_pin_shows_its_card() -> void:
	await _check_hover(WINDOWS[0])


## The same at a larger window (the stage centred in it).
func test_hovering_a_pin_shows_its_card_in_a_larger_window() -> void:
	await _check_hover(WINDOWS[1])


func _check_hover(window: Vector2i) -> void:
	if true:
		get_tree().root.size = window
		var screen: ShiftScreen = await _screen([PRICE_GUN, DAY_OFF], true)
		var lanyard: PinLanyard = screen._stage.pin_lanyard
		var view: Rect2 = screen.get_viewport_rect()
		var monitor_screen: Rect2 = _on_stage(screen, ShiftStage.MONITOR_SCREEN_RECT)
		for index: int in 2:
			var face: Rect2 = lanyard.faces()[index].get_global_rect()
			_move_to(face.get_center())
			await _frames(3)
			assert_object(screen.get_viewport().gui_get_hovered_control()).is_same(
				lanyard.hits()[index]
			)
			var card: PinTip = lanyard.card()
			assert_int(lanyard.shown_pin()).is_equal(index)
			assert_bool(card.is_visible_in_tree()).is_true()
			var pin: PinDefinition = screen.run.pins[index]
			assert_str(card.pin_name()).is_equal(pin.display_name.to_upper())
			assert_str(card.rule_text()).is_equal(pin.rule_text)
			assert_str(card.foot_text()).is_equal(PinTip.FOOT_HINT)
			await get_tree().create_timer(PinLanyard.POP_S + 0.05).timeout
			var box: Rect2 = card.get_global_rect()
			assert_bool(view.encloses(box)).override_failure_message(str(window)).is_true()
			assert_bool(box.intersects(monitor_screen)).is_false()
			assert_float(box.position.y).is_greater(face.end.y)
			assert_bool(card.face().get_global_rect().intersects(box)).is_true()
			var tail: Rect2 = card.get_node("Tail").get_global_rect()
			assert_float(tail.get_center().x).is_equal_approx(face.get_center().x, 2.0)
			for label: String in ["Rule", "Charges", "Foot"]:
				var text: Label = card.get_node(label) as Label
				if text.visible:
					assert_bool(box.encloses(text.get_global_rect())).is_true()
		assert_str(lanyard.card().charges_text()).is_equal("1 day off left this week")
		var gun: PinDefinition = screen.run.pins[0]
		assert_str(PinLanyard.charges_for(gun, screen.run)).is_equal("1 relabel left this shift")
		screen.run.relabels[screen.run.hand()[0].instance_id] = "Snack"
		assert_str(PinLanyard.charges_for(gun, screen.run)).is_equal("0 relabels left this shift")
		screen.run.relabels.clear()
		_move_to(view.position + Vector2(4, view.size.y - 4))
		await _frames(3)
		assert_int(lanyard.shown_pin()).is_equal(-1)
		assert_bool(lanyard.card().visible).is_false()


## A click on a pin keeps its card open after the pointer leaves; a click elsewhere closes it, and
## so does a second click on the same pin. A pin without charges shows none.
func test_a_click_keeps_the_card_open() -> void:
	var screen: ShiftScreen = await _screen([EXPRESS_LANE, PRICE_GUN])
	var lanyard: PinLanyard = screen._stage.pin_lanyard
	var face: Rect2 = lanyard.faces()[0].get_global_rect()
	_move_to(face.get_center())
	await _frames(3)
	_runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await _frames(3)
	assert_int(lanyard.kept_pin()).is_equal(0)
	assert_str(lanyard.card().foot_text()).is_equal(PinTip.FOOT_KEPT)
	assert_str(lanyard.card().charges_text()).is_empty()
	var away: Vector2 = screen._receipt.get_global_rect().get_center()
	_move_to(away)
	await _frames(3)
	assert_int(lanyard.shown_pin()).is_equal(0)
	# Hovering the other pin keeps the kept one's card.
	lanyard.hover_pin(1, true)
	assert_int(lanyard.shown_pin()).is_equal(0)
	lanyard.hover_pin(1, false)
	_runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await _frames(3)
	assert_int(lanyard.kept_pin()).is_equal(-1)
	assert_bool(lanyard.card().visible).is_false()
	# The same pin twice: open, then closed.
	lanyard.press_pin(1)
	assert_int(lanyard.shown_pin()).is_equal(1)
	lanyard.press_pin(1)
	assert_int(lanyard.shown_pin()).is_equal(-1)


## The card pops in about its tail; under reduced motion it shows at full size at once. The badge
## itself never moves.
func test_the_card_respects_reduced_motion() -> void:
	var screen: ShiftScreen = await _screen([PRICE_GUN])
	var lanyard: PinLanyard = screen._stage.pin_lanyard
	var at: Vector2 = lanyard.position
	lanyard.hover_pin(0, true)
	assert_float(lanyard.card().scale.x).is_less(1.0)
	lanyard.hover_pin(0, false)
	screen.profile.set_reduced_motion(true)
	lanyard.hover_pin(0, true)
	assert_float(lanyard.card().scale.x).is_equal(1.0)
	assert_vector(lanyard.position).is_equal(at)
	assert_vector(lanyard.position).is_equal(PinLanyard.RECT.position)


## A pin's icon (PinDefinition.icon) takes the letters' place on its face.
func test_an_icon_replaces_the_letters() -> void:
	var pin: PinDefinition = (load(PRICE_GUN) as PinDefinition).duplicate()
	var face: PinFace = auto_free(PinFace.new(PinLanyard.PIN_SIZE))
	face.show_pin(pin, 0)
	assert_str(face.letters()).is_equal(pin.face_text)
	assert_object(face.icon()).is_null()
	pin.icon = PlaceholderTexture2D.new()
	(pin.icon as PlaceholderTexture2D).size = Vector2(14, 14)
	face.show_pin(pin, 0)
	assert_str(face.letters()).is_empty()
	assert_object(face.icon()).is_same(pin.icon)
	var icon: Control = face.get_node("Icon") as Control
	assert_bool(Rect2(Vector2.ZERO, face.size).encloses(Rect2(icon.position, icon.size))).is_true()


## The pins worn on a new shift show again after the run's shift starts (the screen's refresh).
func test_the_badge_follows_the_run() -> void:
	var screen: ShiftScreen = await _screen([PRICE_GUN])
	var lanyard: PinLanyard = screen._stage.pin_lanyard
	assert_bool(lanyard.visible).is_true()
	screen.run.pins = []
	screen._refresh()
	assert_bool(lanyard.visible).is_false()
	screen.run.pins = [load(PRICE_GUN) as PinDefinition, load(DAY_OFF) as PinDefinition]
	screen._refresh()
	assert_bool(lanyard.visible).is_true()
	assert_int(lanyard.faces().size()).is_equal(2)


func _screen(pins: Array, normal: bool = false) -> ShiftScreen:
	_runner = scene_runner(SCREEN)
	var screen: ShiftScreen = _runner.scene()
	await _frames(3)
	var worn: Array[PinDefinition] = []
	for path: String in pins:
		worn.append(load(path))
	RunPins.wear(screen.run, worn)
	screen.run.start_shift()
	if normal:
		screen.run.inspections = []
	screen.profile.set_reduced_motion(false)
	screen._refresh()
	screen._week.skip()  # The time card opens over a new shift's start.
	await _frames(2)
	return screen


## Moves the pointer to `at` (canvas coordinates: the window's stretch scales them).
func _move_to(at: Vector2) -> void:
	_runner.simulate_mouse_move(get_tree().root.get_final_transform() * at)


static func _on_stage(screen: ShiftScreen, rect: Rect2) -> Rect2:
	return Rect2(screen._stage.get_global_rect().position + rect.position, rect.size)


static func _global(control: Control, rect: Rect2) -> Rect2:
	return Rect2(control.get_global_rect().position + rect.position, rect.size)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
