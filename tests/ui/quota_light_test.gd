extends GdUnitTestSuite
## The conveyor's quota light (QuotaLight, shift scene polish v2 section 1, fill only): alone on a
## LedDisplay, it is dark in planning, fills the apron band in proportion to the running total
## against the quota (lit width = band length x fraction, on the art grid, inside the band), is
## full and gold at the quota and past it, teal (the gauge tube's short ramp, the PR #138 round 2)
## then mustard from the near share, eases to each
## reading (jumps under reduced motion), fits a short belt and clears when planning comes back. On
## the real shift screen, at 1280x720 and 1600x1000: dark in planning, following the LED through a
## count to full past the quota, the band on the belt's apron inside the window and clear of the
## register and the receipt, the bonus lights drawn over it, dark again at the next planning. At
## the quota crossing the band is full and gold the moment the bonus lights come on (no easing to
## full). The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
## Milk, Multipack, Milk x5 = 109, past a quota of 40.
const ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
const QUOTA := 40
const MAX_WAIT_MS := 60000
const WINDOWS: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1600, 1000)]

var _folder: String = ""
var _window_size: Vector2i
## [amount, quota, target fill] for each counting reading seen on the screen.
var _readings: Array[Array] = []
## [band full, bonus lights lit, bonus lights over the band] at each quota_met on the screen.
var _crossings: Array[Array] = []


func before_test() -> void:
	_folder = "user://test_quota_light_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	_readings.clear()
	_crossings.clear()


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Planning (blank or projected): dark, whatever the projection.
func test_it_is_dark_in_planning() -> void:
	var led: LedDisplay = _led()
	var light: QuotaLight = _light(led, true)
	led.show_projected(80, QUOTA)
	assert_bool(light.is_lit()).is_false()
	assert_float(light.lit_rect().size.x).is_equal(0.0)
	led.clear()
	assert_bool(light.is_lit()).is_false()


## Counting: the lit width is the band's length times total / quota, on the art grid, inside the
## band; teal short (the gauge tube's SHORT_RAMP: no tomato), mustard from the near share, full and
## gold at the quota and past it.
func test_it_fills_the_band_in_proportion_to_the_quota() -> void:
	var led: LedDisplay = _led()
	var light: QuotaLight = _light(led, true)
	var band: Rect2 = light.band_rect()
	var apron := Rect2(
		ShiftStage.BELT_RECT.position + BeltPanel.APRON.position, BeltPanel.APRON.size
	)
	assert_that(band).is_equal(apron)
	led.start_count(QUOTA)
	assert_bool(light.is_lit()).is_true()
	assert_float(light.lit_rect().size.x).is_equal(0.0)
	assert_array(QuotaLight.SHORT_RAMP).is_equal(QuotaMeter.SHORT_RAMP)
	var teal: Array[Color] = [Palette.TEAL_LIGHT, Palette.TEAL, Palette.TEAL_SHADE]
	assert_array(QuotaLight.SHORT_RAMP).is_equal(teal)
	for tomato: Color in [Palette.TOMATO, Palette.TOMATO_LIGHT, Palette.TOMATO_PALE]:
		assert_bool(QuotaLight.SHORT_RAMP.has(tomato)).is_false()
	for amount: int in [10, 20, 31, 36]:
		led.show_subtotal(amount, false)
		var share: float = float(amount) / QUOTA
		var lit: Rect2 = light.lit_rect()
		assert_float(lit.size.x).is_equal_approx(snappedf(band.size.x * share, 2.0), 0.01)
		assert_bool(band.encloses(lit)).is_true()
		assert_float(lit.position.x).is_equal(band.position.x)
		assert_float(fmod(lit.size.x, 2.0)).is_equal(0.0)
		assert_bool(light.is_full()).is_false()
		var near: bool = share >= QuotaMeter.NEAR_SHARE
		assert_array(light.ramp()).is_equal(QuotaLight.NEAR_RAMP if near else QuotaLight.SHORT_RAMP)
		if not near:
			# The body row, behind the head: the tube's teal.
			var body := Vector2(lit.position.x + 1.0, lit.end.y - 1.0)
			assert_that(light.colour_at(body)).is_equal(Palette.TEAL)
	led.show_subtotal(QUOTA, true)
	assert_bool(light.is_full()).is_true()
	assert_that(light.lit_rect()).is_equal(band)
	assert_array(light.ramp()).is_equal(QuotaLight.FULL_RAMP)
	led.show_subtotal(QUOTA * 2 + 9, true)
	led.show_total()
	assert_that(light.lit_rect()).is_equal(band)
	assert_bool(light.is_full()).is_true()


## Without reduced motion the level eases to a reading (never past it); reduced motion jumps.
func test_it_eases_to_each_reading() -> void:
	var led: LedDisplay = _led()
	var light: QuotaLight = _light(led, false)
	led.start_count(QUOTA)
	led.show_subtotal(20, false)
	assert_float(light.target_fill()).is_equal(0.5)
	assert_float(light.fill()).is_less(0.5)
	await _frames(3)
	var midway: float = light.fill()
	assert_float(midway).is_greater(0.0)
	assert_float(midway).is_less_equal(0.5)
	await _seconds(1.0)
	assert_float(light.fill()).is_equal(0.5)
	light.reduced_motion = func() -> bool: return true
	led.show_subtotal(30, false)
	assert_float(light.fill()).is_equal(0.75)


## A short belt (#122): the band ends with it and is full there at the quota.
func test_a_short_belt_fills_to_its_own_end() -> void:
	var led: LedDisplay = _led()
	var light: QuotaLight = _light(led, true)
	light.belt_cut = BeltPanel.cut_of(4)
	led.start_count(QUOTA)
	led.show_subtotal(20, false)
	var band: Rect2 = light.band_rect()
	assert_float(band.size.x).is_equal(BeltPanel.APRON.size.x - BeltPanel.cut_of(4))
	assert_float(light.lit_rect().size.x).is_equal_approx(snappedf(band.size.x / 2.0, 2.0), 0.01)
	led.show_subtotal(QUOTA, true)
	assert_that(light.lit_rect()).is_equal(band)


## The next planning (the LED blank, then projected) clears it; a new count starts from empty.
func test_planning_clears_it_and_a_new_count_starts_empty() -> void:
	var led: LedDisplay = _led()
	var light: QuotaLight = _light(led, false)
	led.start_count(QUOTA)
	led.show_subtotal(QUOTA, true)
	led.show_total()
	await _seconds(1.0)
	assert_bool(light.is_full()).is_true()
	led.clear()
	assert_bool(light.is_lit()).is_false()
	assert_float(light.fill()).is_equal(0.0)
	led.show_projected(QUOTA, QUOTA)
	assert_bool(light.is_lit()).is_false()
	led.start_count(QUOTA)
	assert_float(light.fill()).is_equal(0.0)


## The quota met with easing on: the band is full and gold at once, and bonus lights over it
## draw on the band (no base) only while it is full.
func test_it_is_full_at_once_when_the_quota_is_met() -> void:
	var led: LedDisplay = _led()
	var light: QuotaLight = _light(led, false)
	var bonus: BonusLights = _bonus(light)
	led.start_count(QUOTA)
	led.show_subtotal(34, false)
	await _seconds(1.0)
	assert_bool(bonus.is_on_fill()).is_false()
	led.show_subtotal(QUOTA + 3, true)
	bonus.light()
	assert_bool(light.is_full()).is_true()
	assert_that(light.lit_rect()).is_equal(light.band_rect())
	assert_array(light.ramp()).is_equal(QuotaLight.FULL_RAMP)
	assert_bool(bonus.is_on_fill()).is_true()


## A crossing with easing on: the band is full and gold the moment the bonus lights come on, and
## stays full once they fade.
func test_on_the_shift_screen_the_crossing_is_full_at_once() -> void:
	get_tree().root.size = WINDOWS[0]
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(2)
	_fill_row(screen)
	await _frames(3)
	var stage: ShiftStage = screen._stage
	assert_bool(stage.bonus_lights.on_fill.is_valid()).is_true()
	screen._count_up.quota_met.connect(_on_quota_met.bind(stage))
	screen._count_up.play(
		screen.run.preview(),
		screen._row_views,
		CardInstance.names(screen.run.row),
		QUOTA,
		CountUpContext.new(1, 0, 1.0, false, screen.receipt_header())
	)
	await _until_played(screen)
	assert_int(_crossings.size()).is_equal(1)
	assert_array(_crossings[0]).is_equal([true, true, true])
	var light: QuotaLight = stage.quota_light
	await _seconds(BonusLights.FADE_SECONDS + 0.2)
	assert_bool(stage.bonus_lights.is_lit()).is_false()
	assert_bool(light.is_full()).is_true()


func _check_screen(window: Vector2i) -> void:
	get_tree().root.size = window
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(2)
	_fill_row(screen)
	await _frames(3)
	var stage: ShiftStage = screen._stage
	var light: QuotaLight = stage.quota_light
	assert_bool(light.is_lit()).override_failure_message("Lit in planning.").is_false()
	var fore: Array[Node] = stage.fore.get_children()
	assert_int(fore.find(light)).is_less(fore.find(stage.bonus_lights))
	assert_bool(stage.bonus_lights.is_on_fill()).is_false()
	stage.led.reading_changed.connect(_on_reading.bind(stage))
	screen._count_up.play(
		screen.run.preview(),
		screen._row_views,
		CardInstance.names(screen.run.row),
		QUOTA,
		CountUpContext.new(1, 0, 1.0, true, screen.receipt_header())
	)
	await _until_played(screen)
	assert_int(_readings.size()).is_greater(2)
	for reading: Array in _readings:
		assert_float(reading[2]).is_equal(QuotaMeter.fill_fraction(reading[0], reading[1]))
	assert_bool(light.is_full()).is_true()
	_assert_on_the_apron(stage, light, window)
	screen._refresh_preview()
	assert_bool(light.is_lit()).override_failure_message("Lit at the next planning.").is_false()


func _assert_on_the_apron(stage: ShiftStage, light: QuotaLight, window: Vector2i) -> void:
	var to_screen: Transform2D = light.get_global_transform_with_canvas()
	var band: Rect2 = to_screen * light.lit_rect()
	var belt_to_screen: Transform2D = stage.belt.get_global_transform_with_canvas()
	var apron: Rect2 = belt_to_screen * BeltPanel.APRON
	apron.size.x -= stage.belt.cut()
	var where: String = "%s at %s" % [band, window]
	assert_bool(band.is_equal_approx(apron)).override_failure_message(where).is_true()
	var visible: Rect2 = Rect2(Vector2.ZERO, Vector2(window))
	assert_bool(visible.encloses(band)).override_failure_message(where).is_true()
	var cabinet: Rect2 = (
		stage.cabinet.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, stage.cabinet.size)
	)
	assert_bool(band.intersects(cabinet)).override_failure_message(where).is_false()
	var receipt: Rect2 = (
		stage.receipt.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, stage.receipt.size)
	)
	assert_bool(band.intersects(receipt)).override_failure_message(where).is_false()


func _on_quota_met(_pop: bool, stage: ShiftStage) -> void:
	var full: bool = stage.quota_light.is_full()
	_crossings.append([full, stage.bonus_lights.is_lit(), stage.bonus_lights.is_on_fill()])


func _on_reading(_amount: int, _quota: int, _met: bool, stage: ShiftStage) -> void:
	if stage.led.is_counting():
		_readings.append([_amount, _quota, stage.quota_light.target_fill()])


func _fill_row(screen: ShiftScreen) -> void:
	for id: String in ROW:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(ROW.size())


func _until_played(screen: ShiftScreen) -> void:
	var count_up: CountUp = screen._count_up
	var started: int = Time.get_ticks_msec()
	while count_up._playing and Time.get_ticks_msec() - started < MAX_WAIT_MS:
		await get_tree().process_frame
	assert_bool(count_up._playing).override_failure_message("Still counting.").is_false()


func _led() -> LedDisplay:
	var led: LedDisplay = auto_free(LedDisplay.new())
	add_child(led)
	return led


func _light(led: LedDisplay, reduced: bool) -> QuotaLight:
	var light: QuotaLight = auto_free(QuotaLight.new())
	light.size = ShiftStage.SIZE
	light.reduced_motion = func() -> bool: return reduced
	light.follow(led)
	add_child(light)
	return light


## Bonus lights over `light`, as the stage builds them (over the band only while it is full).
func _bonus(light: QuotaLight) -> BonusLights:
	var bonus: BonusLights = auto_free(BonusLights.new())
	bonus.size = ShiftStage.SIZE
	bonus.reduced_motion = func() -> bool: return true
	bonus.on_fill = light.is_full
	add_child(bonus)
	return bonus


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	for child: Node in screen._hand_box.get_children():
		var view: CardView = child as CardView
		if view and view.card == card and not view.is_queued_for_deletion():
			return view
	return null


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
