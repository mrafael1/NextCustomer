extends GdUnitTestSuite
## The register's LED (#55, LedDisplay): its caption per phase (PROJECTED, SUBTOTAL, TOTAL,
## blank), the digits and their colours (the projected total green once it reaches the quota,
## the subtotal green only when the count-up says the quota is met), the quota line and its
## 10-segment bar, the quota chip's anchor (empty unless the count-up's subtotal or total shows)
## and the chip covering the quota text, the longest digits at the largest punch inside the
## glass, and on the real screen the digits and quota line read from core's ScoreResult and
## RunState. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
## The longest total the LED is expected to show.
const LONGEST_DIGITS := "€9999"

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_led_display_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Blank, then PROJECTED (mustard short of the quota, green at it), SUBTOTAL (mustard until
## `met`, whatever the amount), TOTAL over the shown amount, and blank again.
func test_the_caption_and_colour_follow_the_phase() -> void:
	var led: LedDisplay = await _led()
	assert_int(led.mode()).is_equal(LedDisplay.Mode.BLANK)
	assert_str(led.caption()).is_empty()
	assert_str(led.digits_label().text).is_empty()
	led.show_projected(30, 34)
	assert_str(led.caption()).is_equal(LedDisplay.PROJECTED_TEXT)
	assert_str(led.digits_label().text).is_equal("€30")
	assert_str(led.quota_label().text).is_equal("QUOTA €34")
	assert_that(_colour(led)).is_equal(Palette.MUSTARD)
	assert_int(led.lit()).is_equal(8)
	led.show_projected(34, 34)
	assert_that(_colour(led)).is_equal(Palette.GOOD)
	assert_int(led.lit()).is_equal(10)
	led.start_count(50)
	assert_str(led.caption()).is_equal(LedDisplay.SUBTOTAL_TEXT)
	assert_str(led.quota_label().text).is_equal("QUOTA €50")
	assert_that(_colour(led)).is_equal(Palette.MUSTARD)
	# Past the quota but not yet met (the ding comes at the end of its roll): still mustard.
	led.show_subtotal(60, false)
	assert_that(_colour(led)).is_equal(Palette.MUSTARD)
	assert_int(led.lit()).is_equal(10)
	led.show_subtotal(25, false)
	assert_int(led.lit()).is_equal(5)
	led.show_subtotal(60, true)
	assert_that(_colour(led)).is_equal(Palette.GOOD)
	assert_str(led.caption()).is_equal(LedDisplay.SUBTOTAL_TEXT)
	led.show_total()
	assert_str(led.caption()).is_equal(LedDisplay.TOTAL_TEXT)
	assert_str(led.digits_label().text).is_equal("€60")
	led.reset_colour()
	assert_that(_colour(led)).is_equal(Palette.MUSTARD)
	led.clear()
	assert_int(led.mode()).is_equal(LedDisplay.Mode.BLANK)
	for label: Label in [led.caption_label(), led.digits_label(), led.quota_label()]:
		assert_str(label.text).is_empty()
	assert_int(led.lit()).is_equal(0)


## floor(10 x min(1, shown / quota)): 0, partial, at the quota, past it, a negative amount and a
## quota of 0.
func test_lit_segments() -> void:
	assert_int(LedDisplay.lit_segments(0, 34)).is_equal(0)
	assert_int(LedDisplay.lit_segments(3, 34)).is_equal(0)
	assert_int(LedDisplay.lit_segments(4, 34)).is_equal(1)
	assert_int(LedDisplay.lit_segments(33, 34)).is_equal(9)
	assert_int(LedDisplay.lit_segments(34, 34)).is_equal(10)
	assert_int(LedDisplay.lit_segments(500, 34)).is_equal(10)
	assert_int(LedDisplay.lit_segments(-5, 34)).is_equal(0)
	assert_int(LedDisplay.lit_segments(0, 0)).is_equal(LedDisplay.SEGMENTS)


## The parts sit at ShiftStage's LED rects, the bar's segments on the quota line's left, the
## chip's room on its right, apart from the bar, all on the glass.
func test_the_parts_sit_on_the_glass() -> void:
	var led: LedDisplay = await _led()
	led.start_count(34)
	led.show_subtotal(20, false)
	await _frames(2)
	var origin: Vector2 = led.get_global_rect().position
	var glass: Rect2 = led.interior()
	assert_that(led.get_global_rect().size).is_equal(ShiftStage.LED_RECT.size)
	# The digits' line box is centred on their rect, and their ink lies inside it.
	var digits: Rect2 = Rect2(origin + LedDisplay.DIGITS_RECT.position, LedDisplay.DIGITS_RECT.size)
	assert_vector(led.digits_label().get_global_rect().get_center()).is_equal(digits.get_center())
	assert_vector(led.digits_label().pivot_offset).is_equal(led.digits_label().size / 2.0)
	var ink: Rect2 = led.digits_text_rect()
	assert_bool(digits.encloses(ink)).override_failure_message(str(ink)).is_true()
	assert_that(led.quota_label().get_global_rect()).is_equal(
		Rect2(origin + LedDisplay.QUOTA_RECT.position, LedDisplay.QUOTA_RECT.size)
	)
	var anchor: Rect2 = led.quota_anchor()
	var quota_line: Rect2 = led.quota_label().get_global_rect()
	assert_bool(quota_line.encloses(anchor)).override_failure_message(str(anchor)).is_true()
	assert_bool(led.get_global_rect().encloses(quota_line)).is_true()
	assert_bool(glass.encloses(ink)).is_true()
	assert_bool(ink.intersects(quota_line)).is_false()
	for index: int in range(LedDisplay.SEGMENTS):
		var segment: Rect2 = led.segment_rect(index)
		segment.position += origin
		assert_bool(quota_line.encloses(segment)).is_true()
		assert_bool(segment.intersects(anchor)).is_false()
		# On the 2 px art grid.
		assert_float(fmod(segment.position.x - origin.x, 2.0)).is_equal(0.0)
		assert_float(fmod(segment.position.y - origin.y, 2.0)).is_equal(0.0)
	# The quota text fits its line and the chip room covers it.
	var font: Font = led.quota_label().get_theme_font("font")
	var width: float = (
		font
		. get_string_size(
			"QUOTA €999",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			led.quota_label().get_theme_font_size("font_size")
		)
		. x
	)
	assert_float(width).is_less_equal(anchor.size.x)
	# The caption fits its row, above the digits.
	assert_float(led.caption_label().get_minimum_size().x).is_less_equal(
		LedDisplay.CAPTION_RECT.size.x
	)
	for label: Control in [led.caption_label(), led.digits_label(), led.quota_label()]:
		assert_int(label.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		assert_bool(label.has_meta(ArtStyle.PIXEL_ART_META)).is_false()
	assert_bool(led.clip_contents).is_true()
	assert_int(led.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


## The longest digits at the largest punch the count-up gives (SUBTOTAL_PUNCH plus
## SUBTOTAL_PUNCH_MAX plus the tuning's passes_best_punch, above the TOTAL line's) stay on the
## glass: the measured text, not the label's rect.
func test_the_longest_digits_fit_the_glass_at_the_largest_punch() -> void:
	var led: LedDisplay = await _led()
	var tuning: CountUpTuning = load(CountUp.TUNING_PATH)
	var largest: float = maxf(
		CountUp.SUBTOTAL_PUNCH + CountUp.SUBTOTAL_PUNCH_MAX + tuning.passes_best_punch,
		CountUp.TOTAL_PUNCH
	)
	assert_float(largest).is_equal_approx(1.7, 0.001)
	led.start_count(34)
	led.digits_label().text = LONGEST_DIGITS
	led.digits_label().scale = Vector2(largest, largest)
	await _frames(1)
	var text: Rect2 = led.digits_text_rect()
	prints("#55 LED digits", LONGEST_DIGITS, "at", largest, ":", text, "glass", led.interior())
	assert_bool(led.interior().encloses(text)).override_failure_message(str(text)).is_true()
	led.digits_label().scale = Vector2.ONE


## The chip's anchor is empty while the LED is blank or shows the projected total (planning, the
## rack), and on the quota line while it shows the count-up's subtotal or total; empty again
## when hidden.
func test_the_quota_anchor_follows_the_phase() -> void:
	var led: LedDisplay = await _led()
	assert_bool(led.quota_anchor().has_area()).is_false()
	led.show_projected(40, 34)
	assert_bool(led.quota_anchor().has_area()).is_false()
	led.start_count(34)
	var anchor: Rect2 = led.quota_anchor()
	assert_bool(anchor.has_area()).is_true()
	assert_bool(led.get_global_rect().encloses(anchor)).is_true()
	led.show_total()
	assert_that(led.quota_anchor()).is_equal(anchor)
	led.visible = false
	assert_bool(led.quota_anchor().has_area()).is_false()
	led.visible = true
	led.clear()
	assert_bool(led.quota_anchor().has_area()).is_false()


## The compact chip covers the right-aligned "QUOTA €N" it sits over, for the widest quotas:
## shift 8's 120 (data/balance/balance.tres) and 138 with the Big basket's 15%. It spans the
## text's measured width at the line's centre, inside its anchor and right-aligned in it.
func test_the_chip_covers_the_quota_text() -> void:
	var led: LedDisplay = await _led()
	var chip: QuotaChip = auto_free(QuotaChip.new())
	get_tree().root.add_child(chip)
	chip.follow_anchor(led.quota_anchor, led.quota_text_width)
	for quota: int in [120, 138]:
		led.start_count(quota)
		led.show_subtotal(quota, true)
		await _frames(2)
		assert_bool(chip.visible).is_true()
		var rect: Rect2 = chip.get_global_rect()
		var text: Rect2 = _quota_text_span(led)
		prints("#55 chip over", led.quota_label().text, ":", rect, "text", text)
		assert_bool(led.quota_anchor().encloses(rect)).override_failure_message(str(rect)).is_true()
		# Right-aligned with the text (both end at the anchor's end), from left of its start, and
		# over its centre line. Not Rect2.encloses: the shared right end may differ by rounding.
		assert_float(rect.end.x).is_equal_approx(text.end.x, 0.5)
		(
			assert_float(rect.position.x)
			. override_failure_message(
				"%s: chip %s, text %s" % [led.quota_label().text, rect, text]
			)
			. is_less_equal(text.position.x)
		)
		assert_bool(rect.position.y <= text.position.y and text.position.y <= rect.end.y).is_true()


## On the real screen, planning shows the preview's total (core's ScoreResult) against the run's
## quota as cards are placed, and the compact chip, once a count-up meets the quota, fits the
## quota line inside the glass.
func test_the_screen_shows_core_totals() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()
	await _frames(2)
	var led: LedDisplay = screen._led
	assert_object(led.get_parent()).is_same(screen._stage)
	var run: RunState = screen.run
	for id: String in ["milk", "bread", "milk"]:
		var card: CardInstance = run.debug_add_to_hand(load("res://data/cards/%s.tres" % id))
		assert_bool(run.place(card, run.row.size())).is_true()
		screen._refresh()
		assert_str(led.caption()).is_equal(LedDisplay.PROJECTED_TEXT)
		assert_str(led.digits_label().text).is_equal("€%d" % run.preview().total)
		assert_str(led.quota_label().text).is_equal("QUOTA €%d" % run.quota())
		assert_int(led.lit()).is_equal(LedDisplay.lit_segments(run.preview().total, run.quota()))
	# The end state of a checkout that met the quota: TOTAL, green, the chip on the quota line.
	var result: ScoreResult = run.preview()
	screen._count_up.show_end_state(result, 1, screen.count_up_context())
	await _frames(2)
	assert_str(led.caption()).is_equal(LedDisplay.TOTAL_TEXT)
	assert_str(led.digits_label().text).is_equal("€%d" % result.total)
	assert_that(_colour(led)).is_equal(Palette.GOOD)
	var chip: QuotaChip = screen._count_up._quota_chip
	assert_bool(chip.visible).is_true()
	var rect: Rect2 = chip.get_global_rect()
	assert_bool(led.quota_anchor().encloses(rect)).override_failure_message(str(rect)).is_true()
	assert_bool(led.get_global_rect().encloses(rect)).is_true()
	prints("#55 compact chip", rect.size)


func _led() -> LedDisplay:
	var led: LedDisplay = LedDisplay.new()
	var holder: Control = auto_free(Control.new())
	holder.position = ShiftStage.LED_RECT.position
	get_tree().root.add_child(holder)
	holder.add_child(led)
	await _frames(1)
	return led


## The quota text's measured span (global): from the quota line's right end back by the text's
## width, at the line's centre height.
static func _quota_text_span(led: LedDisplay) -> Rect2:
	var line: Rect2 = led.quota_label().get_global_rect()
	var width: float = led.quota_text_width()
	return Rect2(line.end.x - width, line.get_center().y, width, 0.0)


static func _colour(led: LedDisplay) -> Color:
	return led.digits_label().get_theme_color("font_color")


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
