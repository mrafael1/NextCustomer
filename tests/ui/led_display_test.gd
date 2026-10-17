extends GdUnitTestSuite
## The register's LED (#55, LedDisplay): its caption per phase (PROJECTED, SUBTOTAL, TOTAL,
## blank), the digits and their colours (on the glass mustard, the projected total green once it
## reaches the quota; in the count layout B2's ink over a mustard-light shadow, green only when the
## count-up says the quota is met), the quota line and its 10-segment bar, its two layouts (#80:
## compact on the glass in planning and blank, the count-up's on the monitor's paper for SUBTOTAL
## and TOTAL), the quota chip's anchor (empty unless the count-up's subtotal or total shows) and
## the chip covering the quota text, the longest digits at the largest punch inside the glass
## (compact) or the monitor's paper (count), and on the real screen (on the hung monitor) blank in
## planning and the total read from core's ScoreResult. The real saves and logs are
## never touched.

const SCREEN := "res://ui/shift_screen.tscn"
## The longest total the LED is expected to show, the longest realistic one (the balance
## simulator's largest, reports/balance_sim: shift 8's max) and a wide four-digit total.
const LONGEST_DIGITS := "€9999"
const LONGEST_REALISTIC := 1118
const WIDE_FOUR_DIGITS := 1000

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


## Blank, then PROJECTED (mustard short of the quota, green at it, "QUOTA €N" on one label),
## SUBTOTAL (ink until `met`, whatever the amount; the quota row's word and amount apart), TOTAL
## over the shown amount, and blank again (mustard), PROJECTED's quota line whole again.
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
	assert_str(led.quota_label().text).is_equal("€50")
	assert_str(led.quota_word_label().text).is_equal(LedDisplay.QUOTA_WORD)
	assert_bool(led.quota_word_label().visible).is_true()
	assert_that(_colour(led)).is_equal(LedDisplay.COUNT_DIGITS_COLOR)
	assert_that(LedDisplay.COUNT_DIGITS_COLOR).is_equal(Palette.INK)
	# Past the quota but not yet met (the ding comes at the end of its roll): still ink.
	led.show_subtotal(60, false)
	assert_that(_colour(led)).is_equal(Palette.INK)
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
	assert_that(_colour(led)).is_equal(Palette.INK)
	led.clear()
	assert_that(_colour(led)).is_equal(Palette.MUSTARD)
	assert_int(led.mode()).is_equal(LedDisplay.Mode.BLANK)
	for label: Label in [led.caption_label(), led.digits_label(), led.quota_label()]:
		assert_str(label.text).is_empty()
	assert_int(led.lit()).is_equal(0)
	assert_bool(led.quota_word_label().visible).is_false()
	led.show_projected(30, 34)
	assert_str(led.quota_label().text).is_equal("QUOTA €34")
	assert_bool(led.quota_word_label().visible).is_false()


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


## In both layouts the parts sit at their rects (the compact one at ShiftStage's LED rects): on
## the glass the bar's segments on the quota line's left and the chip's room on its right; in the
## count layout (no glass, nothing clipped) "QUOTA €N" and the chip's room at the quota row's
## left, then the bar; the room always apart from the bar. The layout follows the mode: compact
## for PROJECTED (and blank), the count-up's for SUBTOTAL and TOTAL.
func test_the_parts_sit_on_the_glass() -> void:
	var led: LedDisplay = await _led()
	assert_int(led.mode()).is_equal(LedDisplay.Mode.BLANK)
	assert_vector(led.size).is_equal(ShiftStage.LED_RECT.size)
	led.show_projected(20, 34)
	await _frames(2)
	assert_vector(led.size).is_equal(ShiftStage.LED_RECT.size)
	_assert_parts(
		led, LedDisplay.DIGITS_RECT, LedDisplay.QUOTA_RECT, LedDisplay.CAPTION_RECT, false
	)
	led.start_count(34)
	led.show_subtotal(20, false)
	await _frames(2)
	assert_vector(led.size).is_equal(LedDisplay.COUNT_SIZE)
	_assert_parts(
		led,
		LedDisplay.COUNT_DIGITS_RECT,
		LedDisplay.COUNT_QUOTA_RECT,
		LedDisplay.COUNT_CAPTION_RECT,
		true
	)
	led.show_total()
	assert_vector(led.size).is_equal(LedDisplay.COUNT_SIZE)
	led.clear()
	assert_vector(led.size).is_equal(ShiftStage.LED_RECT.size)
	assert_int(led.layout()).is_equal(LedDisplay.Layout.COMPACT)


## The parts at the layout's `digits`, `quota` and `caption` rects (LED coordinates), the bar and
## the chip's room on the quota line (the count layout's quota row), inside the LED's glass (its
## whole rect in the count layout); the beat's parts shown with the count layout (`count`) only.
## The digits' line box is centred on their rect's height; on the glass it spans the rect, in the
## count layout it is as wide as their text, at the rect's left.
func _assert_parts(
	led: LedDisplay, digits_rect: Rect2, quota: Rect2, caption: Rect2, count: bool
) -> void:
	var origin: Vector2 = led.get_global_rect().position
	var glass: Rect2 = led.interior()
	# The digits' line box is centred on their rect, and their ink lies inside it.
	var digits: Rect2 = Rect2(origin + digits_rect.position, digits_rect.size)
	var digits_box: Rect2 = led.digits_label().get_global_rect()
	assert_float(digits_box.get_center().y).is_equal(digits.get_center().y)
	if count:
		assert_float(digits_box.position.x).is_equal(digits.position.x)
		assert_float(digits_box.size.x).is_less_equal(digits.size.x)
		assert_float(digits_box.size.x).is_equal_approx(led.digits_text_rect().size.x, 0.5)
	else:
		assert_float(digits_box.get_center().x).is_equal(digits.get_center().x)
	assert_vector(led.digits_label().pivot_offset).is_equal(led.digits_label().size / 2.0)
	var ink: Rect2 = led.digits_text_rect()
	assert_bool(digits.encloses(ink)).override_failure_message(str(ink)).is_true()
	assert_that(led.quota_label().get_global_rect()).is_equal(
		Rect2(origin + quota.position, quota.size)
	)
	assert_bool(led.beat().is_visible_in_tree()).is_equal(count)
	var anchor: Rect2 = led.quota_anchor() if count else _compact_anchor(led)
	var quota_line: Rect2 = led.quota_label().get_global_rect()
	assert_bool(quota_line.encloses(anchor)).override_failure_message(str(anchor)).is_true()
	if count:
		var row: Rect2 = LedDisplay.COUNT_QUOTA_ROW
		quota_line = Rect2(origin + row.position, row.size)
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
	# The quota text fits its line and the chip room covers it: "QUOTA €999" on the glass; in the
	# count layout the word in its font, the gap and "€999" in the amount's.
	var width: float = _width(led.quota_label(), "QUOTA €999")
	if count:
		var word: Label = led.quota_word_label()
		width = _width(word, LedDisplay.QUOTA_WORD) + LedDisplay.QUOTA_WORD_GAP
		width += _width(led.quota_label(), "€999")
		var word_rect: Rect2 = word.get_global_rect()
		(
			assert_bool(quota_line.encloses(word_rect))
			. override_failure_message(str(word_rect))
			. is_true()
		)
		assert_float(led.quota_text_width()).is_equal_approx(
			(
				_width(word, word.text)
				+ LedDisplay.QUOTA_WORD_GAP
				+ _width(led.quota_label(), led.quota_label().text)
			),
			0.01
		)
	assert_float(width).is_less_equal(anchor.size.x)
	# The caption fits its row, above the digits.
	assert_float(led.caption_label().get_minimum_size().x).is_less_equal(caption.size.x)
	for label: Control in [led.caption_label(), led.digits_label(), led.quota_label()]:
		assert_int(label.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		assert_bool(label.has_meta(ArtStyle.PIXEL_ART_META)).is_false()
	assert_bool(led.clip_contents).is_equal(not count)
	assert_int(led.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


## The longest digits at the largest punch the count-up gives (SUBTOTAL_PUNCH plus
## SUBTOTAL_PUNCH_MAX plus the tuning's passes_best_punch, above the TOTAL line's) stay on the
## glass in the compact layout, and on the monitor's paper in the count layout (at its count
## place and its TOTAL place, MonitorView's), where the longest realistic total (the simulator's
## largest, €1118) keeps the largest digits size and a wide four-digit total (€1000) and the
## longest digits take a smaller one: the measured text, not the label's rect.
func test_the_longest_digits_fit_the_glass_at_the_largest_punch() -> void:
	var led: LedDisplay = await _led()
	var tuning: CountUpTuning = load(CountUp.TUNING_PATH)
	var largest: float = maxf(
		CountUp.SUBTOTAL_PUNCH + CountUp.SUBTOTAL_PUNCH_MAX + tuning.passes_best_punch,
		CountUp.TOTAL_PUNCH
	)
	assert_float(largest).is_equal_approx(1.7, 0.001)
	led.show_projected(9999, 34)
	await _frames(1)
	assert_str(led.digits_label().text).is_equal(LONGEST_DIGITS)
	led.digits_label().scale = Vector2(largest, largest)
	var text: Rect2 = led.digits_text_rect()
	prints("#55 LED digits", LONGEST_DIGITS, "at", largest, ":", text, "glass", led.interior())
	assert_bool(led.interior().encloses(text)).override_failure_message(str(text)).is_true()
	led.digits_label().scale = Vector2.ONE
	# The count layout, at the monitor's places (the holder stands at the LED's compact place).
	led.start_count(34)
	var paper: Rect2 = ShiftStage.MONITOR_SCREEN_RECT.grow(-MonitorView.OUTLINE)
	for amount: int in [LONGEST_REALISTIC, WIDE_FOUR_DIGITS, 9999]:
		led.show_subtotal(amount, false)
		await _frames(1)
		var font_size: int = led.digits_label().get_theme_font_size("font_size")
		if amount == LONGEST_REALISTIC:
			assert_int(font_size).is_equal(LedDisplay.COUNT_DIGITS_SIZES[0])
		else:
			assert_int(font_size).is_less(LedDisplay.COUNT_DIGITS_SIZES[0])
		var width: float = led.digits_text_rect().size.x
		assert_float(width).is_less_equal(LedDisplay.COUNT_DIGITS_RECT.size.x)
		for place: Rect2 in [MonitorView.LED_COUNT_RECT, MonitorView.LED_TOTAL_RECT]:
			led.position = place.position - ShiftStage.LED_RECT.position
			led.digits_label().scale = Vector2(largest, largest)
			text = led.digits_text_rect()
			var shown: String = led.digits_label().text
			prints(
				"#80 LED count digits", shown, font_size, "at", largest, ":", text, "paper", paper
			)
			assert_bool(paper.encloses(text)).override_failure_message(shown + str(text)).is_true()
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


## On the real screen the LED stays blank in planning as cards are placed (the monitor's store
## channel has the screen; the top bar's QUOTA chip carries the preview's total,
## monitor_channel_test), and a checkout's end state shows core's total, the chip on the quota
## line.
func test_the_screen_shows_core_totals() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()
	await _frames(2)
	var led: LedDisplay = screen._led
	assert_object(led.get_parent()).is_same(screen._stage.monitor)
	var run: RunState = screen.run
	for id: String in ["milk", "bread", "milk"]:
		var card: CardInstance = run.debug_add_to_hand(load("res://data/cards/%s.tres" % id))
		assert_bool(run.place(card, run.row.size())).is_true()
		screen._refresh()
		assert_int(led.mode()).is_equal(LedDisplay.Mode.BLANK)
		assert_bool(led.visible).is_false()
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


## The compact layout's chip room (global): quota_anchor() is empty outside the count-up, so the
## room is read from CHIP_RECT.
static func _compact_anchor(led: LedDisplay) -> Rect2:
	return Rect2(
		led.get_global_transform() * LedDisplay.CHIP_RECT.position, LedDisplay.CHIP_RECT.size
	)


## The quota text's measured span (global): from the quota line's right end back by the text's
## width, at the line's centre height.
static func _quota_text_span(led: LedDisplay) -> Rect2:
	var line: Rect2 = led.quota_label().get_global_rect()
	var width: float = led.quota_text_width()
	return Rect2(line.end.x - width, line.get_center().y, width, 0.0)


## `text`'s width in `label`'s font and size.
static func _width(label: Label, text: String) -> float:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


static func _colour(led: LedDisplay) -> Color:
	return led.digits_label().get_theme_color("font_color")


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
