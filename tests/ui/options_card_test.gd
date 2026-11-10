extends GdUnitTestSuite
## The OPTIONS popup (mock-up options_pause.html): its layout at 1280x720 at every TEXT SIZE, its
## keys and the settings it applies (the window and bus setters recorded).

const WINDOW := Vector2(1280, 720)

var _window_modes: Array[DisplayServer.WindowMode] = []
var _bus_calls: Array[Array] = []


func before_test() -> void:
	_window_modes.clear()
	_bus_calls.clear()


func after_test() -> void:
	UiKit.reading_scale = 1.0


func _settings() -> GameSettings:
	var settings: GameSettings = GameSettings.new()
	settings.set_window_mode = func(mode: DisplayServer.WindowMode) -> void:
		_window_modes.append(mode)
	settings.set_bus_level = func(bus: StringName, db: float, muted: bool) -> void:
		_bus_calls.append([bus, db, muted])
	return settings


func _open(profile: ProfileState) -> OptionsCard:
	var host: Control = auto_free(Control.new())
	host.size = WINDOW
	add_child(host)
	var card: OptionsCard = OptionsCard.new()
	card.still = true
	host.add_child(card)
	card.open(profile, _settings(), null)
	return card


func _key(keycode: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	return key


## Every visible control under `node`, deepest last.
func _controls(node: Node, into: Array[Control]) -> Array[Control]:
	for child: Node in node.get_children():
		var control: Control = child as Control
		if control != null and control.is_visible_in_tree():
			into.append(control)
		_controls(child, into)
	return into


func test_the_sheet_fits_720p_and_nothing_clips_at_every_text_size() -> void:
	for size_index: int in ProfileState.TEXT_SIZES.size():
		var profile: ProfileState = ProfileState.new()
		ProfileSettings.set_text_size(profile, size_index)
		GameSettings.apply_text_size(profile)
		var card: OptionsCard = _open(profile)
		await get_tree().process_frame
		var sheet: Rect2 = card.sheet().get_global_rect()
		assert_bool(Rect2(Vector2.ZERO, WINDOW).encloses(sheet)).is_true()
		assert_float(sheet.size.x).is_equal(704.0)
		# Inside the frame's 4 art px border, every row, widget and text sits on the sheet.
		var inner: Rect2 = sheet.grow(-4.0)
		for control: Control in _controls(card.sheet(), []):
			if control is PanelContainer and control.get_parent() == card.sheet():
				continue  # The frame itself.
			if control.size == Vector2.ZERO:
				continue  # A holder, such as the rows' layer.
			var rect: Rect2 = control.get_global_rect()
			if control is Label and control.scale != Vector2.ONE:
				rect.size = UiKit.pixel_text_size(control as Label)
			(
				assert_bool(inner.grow(0.5).encloses(rect))
				. override_failure_message(
					"%s %s outside the sheet %s at size %d" % [control, rect, inner, size_index]
				)
				. is_true()
			)
			var text: Label = control as Label
			if text != null and text.autowrap_mode != TextServer.AUTOWRAP_OFF:
				assert_float(text.get_minimum_size().y).is_less_equal(text.size.y + 0.5)
		# The hint never runs into DONE, whatever row is marked.
		var done: Rect2 = card.done_plate().get_global_rect()
		for row: int in OptionsCard.Row.size():
			card.handle_key(_key(KEY_DOWN))
			var hint: Label = card.hint_label()
			var bottom: float = hint.global_position.y + hint.get_minimum_size().y
			assert_float(bottom).is_less_equal(done.position.y)
		# The rows don't overlap.
		for row: int in OptionsCard.Row.DONE:
			var here: Rect2 = card.row_entry(row as OptionsCard.Row).get_global_rect()
			var next: Rect2 = card.row_entry((row + 1) as OptionsCard.Row).get_global_rect()
			assert_float(next.position.y).is_greater_equal(here.end.y - 0.5)
		card.close()
	# Larger text makes a taller sheet.
	assert_int(UiKit.text_size(13)).is_equal(18)


func test_keys_walk_the_rows_and_change_the_marked_one() -> void:
	var profile: ProfileState = ProfileState.new()
	var card: OptionsCard = _open(profile)
	card.handle_key(_key(KEY_DOWN))
	assert_int(card.marked_row()).is_equal(OptionsCard.Row.DISPLAY)
	card.handle_key(_key(KEY_RIGHT))
	assert_str(ProfileSettings.display(profile)).is_equal(ProfileState.DISPLAY_FULLSCREEN)
	assert_array(_window_modes).is_equal([DisplayServer.WINDOW_MODE_FULLSCREEN])
	assert_bool((card.chips(OptionsCard.Row.DISPLAY)[1] as OptionChip).chosen).is_true()
	card.handle_key(_key(KEY_DOWN))
	card.handle_key(_key(KEY_LEFT))
	assert_int(ProfileSettings.music_volume(profile)).is_equal(7)
	assert_int(card.volume(OptionsCard.Row.MUSIC).value).is_equal(7)
	card.handle_key(_key(KEY_DOWN))
	for i: int in 9:
		card.handle_key(_key(KEY_LEFT))
	assert_int(ProfileSettings.sound_volume(profile)).is_equal(0)
	assert_array(_bus_calls[-1]).is_equal([GameSettings.SFX_BUS, 0.0, true])
	card.handle_key(_key(KEY_DOWN))
	card.handle_key(_key(KEY_ENTER))
	assert_int(ProfileSettings.text_size(profile)).is_equal(1)
	assert_float(UiKit.reading_scale).is_equal(1.2)
	assert_int(card.marked_row()).is_equal(OptionsCard.Row.TEXT)
	card.handle_key(_key(KEY_DOWN))
	card.handle_key(_key(KEY_ENTER))
	assert_bool(profile.reduced_motion()).is_true()
	assert_bool(card.motion_key().held).is_true()
	card.handle_key(_key(KEY_DOWN))
	card.handle_key(_key(KEY_RIGHT))
	assert_float(profile.count_up_speed()).is_equal(ProfileState.COUNT_UP_FAST)
	var keys: Array = card.changes().map(func(change: Dictionary) -> String: return change["key"])
	(
		assert_array(keys)
		. is_equal(
			[
				ProfileState.DISPLAY_KEY,
				ProfileState.MUSIC_VOLUME_KEY,
				ProfileState.SOUND_VOLUME_KEY,
				ProfileState.TEXT_SIZE_KEY,
				ProfileState.REDUCED_MOTION_KEY,
				ProfileState.COUNT_UP_SPEED_KEY,
			]
		)
	)
	var closed: Array[bool] = []
	card.closed.connect(func() -> void: closed.append(true))
	card.handle_key(_key(KEY_ESCAPE))
	assert_array(closed).is_equal([true])
	assert_bool(card.is_open()).is_false()
	# The TEXT SIZE change rebuilt the rows: the old ones are freed at the frame's end.
	await await_idle_frame()


func test_volumes_and_the_display_apply_through_the_setters() -> void:
	var settings: GameSettings = _settings()
	var profile: ProfileState = ProfileState.new()
	ProfileSettings.set_sound_volume(profile, 5)
	settings.apply(profile, null, true)
	# At boot a windowed display is left alone.
	assert_array(_window_modes).is_empty()
	assert_array(_bus_calls).is_equal([[GameSettings.SFX_BUS, linear_to_db(0.5), false]])
	ProfileSettings.set_display(profile, ProfileState.DISPLAY_FULLSCREEN)
	settings.is_web = true
	settings.apply(profile, null, true)
	assert_array(_window_modes).is_empty()  # The web build never goes fullscreen at boot.
	settings.is_web = false
	settings.apply(profile, null, true)
	assert_array(_window_modes).is_equal([DisplayServer.WINDOW_MODE_FULLSCREEN])
	var alt_enter: InputEventKey = _key(KEY_ENTER)
	alt_enter.alt_pressed = true
	assert_bool(settings.toggle_on_key(alt_enter, profile)).is_true()
	assert_str(ProfileSettings.display(profile)).is_equal(ProfileState.DISPLAY_WINDOWED)
	assert_array(_window_modes).is_equal(
		[DisplayServer.WINDOW_MODE_FULLSCREEN, DisplayServer.WINDOW_MODE_WINDOWED]
	)
	assert_bool(settings.toggle_on_key(_key(KEY_ENTER), profile)).is_false()


func test_the_music_level_moves_its_base_and_ducking_stays_relative() -> void:
	var bus: int = AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, "OptionsTestMusic")
	AudioServer.set_bus_volume_db(bus, -15.0)
	var music: MusicService = MusicService.new()
	music.bus_name = &"OptionsTestMusic"
	add_child(music)
	music.set_level(GameSettings.volume_db(5), false)
	assert_float(music.base_db()).is_equal_approx(-15.0 + linear_to_db(0.5), 0.001)
	music.duck(-6.0, 0.0)
	assert_float(AudioServer.get_bus_volume_db(bus)).is_equal_approx(music.base_db() - 6.0, 0.001)
	music.set_level(0.0, true)
	assert_bool(AudioServer.is_bus_mute(bus)).is_true()
	music.free()
	AudioServer.remove_bus(bus)
