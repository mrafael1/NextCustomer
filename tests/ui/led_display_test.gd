extends GdUnitTestSuite
## The register's LED (#55, LedDisplay): its caption per phase (PROJECTED, SUBTOTAL, TOTAL,
## blank), the digits and their colours (on the glass mustard, the projected total green once it
## reaches the quota; in the count layout, #86 v6's number column, the bare number in gold with an
## ink outline over a mustard-dark shadow, gold met or not), the quota line and its 10-segment bar
## on the glass, its two layouts (#80: compact on the glass in planning and blank, the count-up's
## on the monitor's paper for SUBTOTAL and TOTAL, caption and quota line hidden), the to-go line
## under the count's digits and the SPEND MET stamp that replaces it (LedBeat, MetStamp), the
## longest digits at the largest punch inside the glass (compact) or the monitor's paper (count),
## and on the real screen (on the hung monitor) blank in planning and the total read from core's
## ScoreResult. The real saves and logs are never touched.

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


## Blank, then PROJECTED (mustard short of the quota, green at it, "SPEND €N+"), SUBTOTAL (the
## bare number in gold, met or not; caption and quota line hidden), TOTAL over the shown amount,
## and blank again (mustard), PROJECTED's look whole again.
func test_the_caption_and_colour_follow_the_phase() -> void:
	var led: LedDisplay = await _led()
	assert_int(led.mode()).is_equal(LedDisplay.Mode.BLANK)
	assert_str(led.caption_label().text).is_empty()
	assert_str(led.digits_label().text).is_empty()
	led.show_projected(30, 34)
	assert_str(led.caption_label().text).is_equal(LedDisplay.PROJECTED_TEXT)
	assert_str(led.digits_label().text).is_equal("€30")
	assert_str(led.quota_label().text).is_equal("SPEND €34+")
	assert_that(_colour(led)).is_equal(Palette.MUSTARD)
	assert_int(led.lit()).is_equal(8)
	led.show_projected(34, 34)
	assert_that(_colour(led)).is_equal(Palette.GOOD)
	assert_int(led.lit()).is_equal(10)
	led.start_count(50)
	assert_str(led.caption_label().text).is_equal(LedDisplay.SUBTOTAL_TEXT)
	assert_str(led.quota_label().text).is_equal("SPEND €50+")
	assert_bool(led.caption_label().visible).is_false()
	assert_bool(led.quota_label().visible).is_false()
	assert_that(_colour(led)).is_equal(LedDisplay.COUNT_DIGITS_COLOR)
	assert_that(LedDisplay.COUNT_DIGITS_COLOR).is_equal(Palette.GOLD)
	led.show_subtotal(25, false)
	assert_str(led.digits_label().text).is_equal("25")
	assert_int(led.lit()).is_equal(5)
	led.show_subtotal(60, false)
	assert_that(_colour(led)).is_equal(Palette.GOLD)
	led.show_subtotal(60, true)
	assert_that(_colour(led)).is_equal(Palette.GOLD)
	led.show_total()
	assert_str(led.caption_label().text).is_equal(LedDisplay.TOTAL_TEXT)
	assert_str(led.digits_label().text).is_equal("60")
	assert_int(led.layout()).is_equal(LedDisplay.Layout.COUNT)
	led.reset_colour()
	assert_that(_colour(led)).is_equal(Palette.GOLD)
	led.clear()
	assert_that(_colour(led)).is_equal(Palette.MUSTARD)
	assert_int(led.mode()).is_equal(LedDisplay.Mode.BLANK)
	for label: Label in [led.caption_label(), led.digits_label(), led.quota_label()]:
		assert_str(label.text).is_empty()
	assert_int(led.lit()).is_equal(0)
	led.show_projected(30, 34)
	assert_str(led.digits_label().text).is_equal("€30")
	assert_bool(led.caption_label().visible).is_true()
	assert_bool(led.quota_label().visible).is_true()


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


## The compact layout (planning, blank) at ShiftStage's LED rects: the caption, the digits centred
## on their rect, the quota line with the bar's segments on it, all inside the glass, which clips.
func test_the_compact_parts_sit_on_the_glass() -> void:
	var led: LedDisplay = await _led()
	assert_vector(led.size).is_equal(ShiftStage.LED_RECT.size)
	led.show_projected(20, 34)
	await _frames(2)
	assert_vector(led.size).is_equal(ShiftStage.LED_RECT.size)
	assert_int(led.layout()).is_equal(LedDisplay.Layout.COMPACT)
	var origin: Vector2 = led.get_global_rect().position
	var glass: Rect2 = led.interior()
	var digits: Rect2 = _shifted(LedDisplay.DIGITS_RECT, origin)
	var digits_box: Rect2 = led.digits_label().get_global_rect()
	assert_float(digits_box.get_center().y).is_equal(digits.get_center().y)
	assert_float(digits_box.get_center().x).is_equal(digits.get_center().x)
	var ink: Rect2 = led.digits_text_rect()
	assert_bool(digits.encloses(ink)).override_failure_message(str(ink)).is_true()
	assert_bool(glass.encloses(ink)).is_true()
	var quota_line: Rect2 = led.quota_label().get_global_rect()
	assert_that(quota_line).is_equal(_shifted(LedDisplay.QUOTA_RECT, origin))
	assert_bool(led.get_global_rect().encloses(quota_line)).is_true()
	assert_bool(ink.intersects(quota_line)).is_false()
	for index: int in range(LedDisplay.SEGMENTS):
		var segment: Rect2 = _shifted(led.segment_rect(index), origin)
		assert_bool(quota_line.encloses(segment)).is_true()
		# On the 2 px art grid.
		assert_float(fmod(segment.position.x - origin.x, 2.0)).is_equal(0.0)
		assert_float(fmod(segment.position.y - origin.y, 2.0)).is_equal(0.0)
	assert_float(_width(led.quota_label(), "SPEND €999+")).is_less_equal(quota_line.size.x)
	var caption: Rect2 = LedDisplay.CAPTION_RECT
	assert_float(led.caption_label().get_minimum_size().x).is_less_equal(caption.size.x)
	assert_bool(led.beat().is_visible_in_tree()).is_false()
	for label: Control in [led.caption_label(), led.digits_label(), led.quota_label()]:
		assert_int(label.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		assert_bool(label.has_meta(ArtStyle.PIXEL_ART_META)).is_false()
	assert_bool(led.clip_contents).is_true()
	assert_int(led.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


## The count layout (SUBTOTAL and TOTAL), at the monitor's LED_COUNT_RECT: the digits' label as wide
## as their text, the group of the digits, EURO_GAP and the € (the monitor bay follow-up) centred in
## COUNT_DIGITS_RECT (the line box centred on the rect's height; the punch pivot at the digits'
## bottom right corner, on their baseline: the monitor juice's punch keeps the € still), their ink
## inside it; the to-go line at COUNT_TO_GO_RECT under it (stage TO_GO_RECT),
## apart from the ink; caption and quota line hidden; nothing clipped. Back to compact when blank.
func test_the_count_parts_sit_on_the_paper() -> void:
	var led: LedDisplay = await _led()
	led.position = MonitorView.LED_COUNT_RECT.position - ShiftStage.LED_RECT.position
	led.start_count(34)
	led.show_subtotal(20, false)
	await _frames(2)
	assert_int(led.layout()).is_equal(LedDisplay.Layout.COUNT)
	assert_vector(led.size).is_equal(LedDisplay.COUNT_SIZE)
	assert_that(led.get_global_rect()).is_equal(MonitorView.LED_COUNT_RECT)
	assert_that(led.interior()).is_equal(led.get_global_rect())
	var origin: Vector2 = led.get_global_rect().position
	var digits: Rect2 = _shifted(LedDisplay.COUNT_DIGITS_RECT, origin)
	var digits_box: Rect2 = led.digits_label().get_global_rect()
	assert_float(digits_box.get_center().y).is_equal(digits.get_center().y)
	assert_float(digits_box.size.x).is_equal_approx(led.digits_text_rect().size.x, 0.5)
	var euro: Rect2 = led.euro_label().get_global_rect()
	var group: Rect2 = digits_box.merge(euro)
	assert_float(euro.position.x - digits_box.end.x).is_equal_approx(LedDisplay.EURO_GAP, 0.001)
	assert_float(absf(group.get_center().x - digits.get_center().x)).is_less_equal(1.0)
	var pivot: Vector2 = led.digits_label().pivot_offset
	assert_float(pivot.x).is_equal_approx(led.digits_label().size.x, 0.01)
	assert_float(led.digits_label().global_position.y + pivot.y).is_equal_approx(
		led.digits_text_rect().end.y, 1.0
	)
	var ink: Rect2 = led.digits_text_rect().merge(led.euro_text_rect())
	assert_bool(digits.encloses(ink)).override_failure_message(str(ink)).is_true()
	var beat: LedBeat = led.beat()
	assert_bool(beat.is_visible_in_tree()).is_true()
	assert_that(beat.get_global_rect()).is_equal(MonitorView.TO_GO_RECT)
	assert_that(beat.get_global_rect()).is_equal(_shifted(LedDisplay.COUNT_TO_GO_RECT, origin))
	assert_that(beat.to_go_label().get_global_rect()).is_equal(MonitorView.TO_GO_RECT)
	assert_bool(beat.to_go_label().is_visible_in_tree()).is_true()
	assert_bool(ink.intersects(beat.get_global_rect())).is_false()
	assert_bool(MonitorView.PAPER_RECT.encloses(led.get_global_rect())).is_true()
	assert_bool(MonitorView.PAPER_RECT.encloses(beat.get_global_rect())).is_true()
	assert_bool(led.caption_label().visible).is_false()
	assert_bool(led.quota_label().visible).is_false()
	assert_bool(led.clip_contents).is_false()
	led.show_total()
	assert_vector(led.size).is_equal(LedDisplay.COUNT_SIZE)
	led.clear()
	assert_vector(led.size).is_equal(ShiftStage.LED_RECT.size)
	assert_int(led.layout()).is_equal(LedDisplay.Layout.COMPACT)
	assert_bool(beat.is_visible_in_tree()).is_false()


## The count's digits: gold, an ink outline COUNT_OUTLINE px wide, a mustard-dark shadow
## COUNT_SHADOW px down and right that carries the outline; on the glass the mustard glow and no
## shadow.
func test_the_count_digits_look() -> void:
	var led: LedDisplay = await _led()
	var digits: Label = led.digits_label()
	led.show_projected(20, 34)
	assert_int(digits.get_theme_constant("outline_size")).is_equal(LedDisplay.GLOW_SIZE)
	assert_float(digits.get_theme_color("font_shadow_color").a).is_equal(0.0)
	led.start_count(34)
	led.show_subtotal(20, false)
	assert_that(digits.get_theme_color("font_color")).is_equal(Palette.GOLD)
	assert_that(digits.get_theme_color("font_outline_color")).is_equal(Palette.INK)
	assert_int(digits.get_theme_constant("outline_size")).is_equal(LedDisplay.COUNT_OUTLINE)
	assert_int(LedDisplay.COUNT_OUTLINE).is_equal(2)
	assert_that(digits.get_theme_color("font_shadow_color")).is_equal(Palette.MUSTARD_DARK)
	assert_int(digits.get_theme_constant("shadow_offset_x")).is_equal(LedDisplay.COUNT_SHADOW)
	assert_int(digits.get_theme_constant("shadow_offset_y")).is_equal(LedDisplay.COUNT_SHADOW)
	assert_int(LedDisplay.COUNT_SHADOW).is_equal(5)
	assert_int(digits.get_theme_constant("shadow_outline_size")).is_equal(LedDisplay.COUNT_OUTLINE)
	assert_int(digits.get_theme_font_size("font_size")).is_equal(LedDisplay.COUNT_DIGITS_SIZES[0])
	assert_int(LedDisplay.COUNT_DIGITS_SIZES[0]).is_equal(80)
	assert_str(digits.text).is_equal("20")
	led.clear()
	assert_int(digits.get_theme_constant("outline_size")).is_equal(LedDisplay.GLOW_SIZE)
	assert_float(digits.get_theme_color("font_shadow_color").a).is_equal(0.0)


## The longest digits at the largest punch the count-up gives (SUBTOTAL_PUNCH plus
## SUBTOTAL_PUNCH_MAX plus the tuning's passes_best_punch, above the TOTAL line's) stay on the
## glass in the compact layout, and on the monitor's paper in the count layout (at
## LED_COUNT_RECT; there the gold tank punches the digits at most to digits_punch_max, within
## punch_room), where every total up to the longest digits (9999) keeps the largest digits size
## with its € beside it (the room is the paper right of the bay since the monitor bay follow-up),
## inside COUNT_DIGITS_RECT's width at rest: the measured text, not the label's rect.
func test_the_longest_digits_fit_at_the_largest_punch() -> void:
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
	# The count layout, at the monitor's place (the holder stands at the LED's compact place).
	led.start_count(34)
	led.position = MonitorView.LED_COUNT_RECT.position - ShiftStage.LED_RECT.position
	var paper: Rect2 = MonitorView.PAPER_RECT
	for amount: int in [999, LONGEST_REALISTIC, WIDE_FOUR_DIGITS, 9999]:
		led.show_subtotal(amount, false)
		await _frames(1)
		var font_size: int = led.digits_label().get_theme_font_size("font_size")
		assert_int(font_size).is_equal(LedDisplay.COUNT_DIGITS_SIZES[0])
		var width: float = led.digits_text_rect().merge(led.euro_text_rect()).size.x
		assert_float(width).is_less_equal(LedDisplay.COUNT_DIGITS_RECT.size.x)
		var peak: float = minf(tuning.digits_punch_max, led.punch_room())
		led.digits_label().scale = Vector2(peak, peak)
		text = led.digits_text_rect()
		var shown: String = led.digits_label().text
		prints("#86 LED count digits", shown, font_size, "at", peak, ":", text, "paper", paper)
		assert_bool(paper.encloses(text)).override_failure_message(shown + str(text)).is_true()
		led.digits_label().scale = Vector2.ONE


## The to-go line: "€N to go" in dark tomato short of the quota, in ink from NEAR_SHARE of it,
## its text "Spot on" or "+€N" past it but hidden there; the longest fits its row. The SPEND MET
## stamp (at stage STAMP_RECT, on the paper) replaces it while it shows, and a new count
## (start_count) or the LED going blank takes it off.
func test_the_to_go_line_and_the_stamp() -> void:
	var led: LedDisplay = await _led()
	led.position = MonitorView.LED_COUNT_RECT.position - ShiftStage.LED_RECT.position
	var beat: LedBeat = led.beat()
	var line: Label = beat.to_go_label()
	var stamp: MetStamp = beat.stamp()
	led.start_count(100)
	led.show_subtotal(10, false)
	await _frames(1)
	assert_str(line.text).is_equal("€90 to go")
	assert_that(line.get_theme_color("font_color")).is_equal(Palette.TOMATO_DARK)
	assert_int(line.get_theme_font_size("font_size")).is_equal(LedBeat.TO_GO_FONT_SIZE)
	assert_bool(beat.is_near()).is_false()
	assert_bool(line.is_visible_in_tree()).is_true()
	assert_bool(stamp.is_visible_in_tree()).is_false()
	led.show_subtotal(80, false)
	assert_str(line.text).is_equal("€20 to go")
	assert_bool(beat.is_near()).is_true()
	assert_that(line.get_theme_color("font_color")).is_equal(Palette.INK)
	# On or past the quota the line is hidden even before the count is met (a last payout crossing
	# it, met with the TOTAL): the stamp's place, the "+€N" is the tank's tab.
	led.show_subtotal(100, false)
	assert_str(line.text).is_equal(LedBeat.ON_QUOTA_TEXT)
	assert_bool(line.visible).is_false()
	led.show_subtotal(117, false)
	assert_str(line.text).is_equal("+€17")
	assert_that(line.get_theme_color("font_color")).is_equal(Palette.INK)
	assert_bool(line.visible).is_false()
	led.show_subtotal(117, true)
	assert_bool(line.visible).is_false()
	# Back under it (a new count), it shows again.
	led.show_subtotal(99, false)
	assert_bool(line.visible).is_true()
	led.show_subtotal(117, true)
	var room: float = LedDisplay.COUNT_TO_GO_RECT.size.x
	assert_float(_width(line, LedBeat.TO_GO_TEXT % 999)).is_less_equal(room)
	# The stamp replaces the line.
	stamp.show_static()
	await _frames(1)
	assert_bool(stamp.is_visible_in_tree()).is_true()
	assert_bool(line.visible).is_false()
	assert_that(stamp.get_global_rect()).is_equal(MonitorView.STAMP_RECT)
	var drawn: Rect2 = stamp.drawn_rect()
	var on_paper: bool = MonitorView.PAPER_RECT.encloses(drawn)
	assert_bool(on_paper).override_failure_message(str(drawn)).is_true()
	var text: float = _width(stamp.label(), MetStamp.TEXT) + MetStamp.CHECK_GAP
	text += MetStamp.CHECK_SIZE.x
	assert_float(text).is_less_equal(MetStamp.SIZE.x - 2.0 * MetStamp.BORDER)
	led.show_subtotal(120, true)
	assert_bool(line.visible).is_false()
	# A new count takes it off.
	led.start_count(90)
	led.show_subtotal(0, false)
	assert_bool(stamp.is_showing()).is_false()
	assert_bool(line.visible).is_true()
	stamp.show_static()
	led.clear()
	assert_bool(stamp.is_showing()).is_false()


## The slam drops the stamp from SLAM_FROM on its own real-time tween, puffs dust and says
## `landed` at the impact; under reduced motion it shows at rest at once with no dust.
func test_the_stamp_slams_in_real_time() -> void:
	var led: LedDisplay = await _led()
	led.start_count(50)
	led.show_subtotal(60, true)
	var stamp: MetStamp = led.beat().stamp()
	var landings: Array[bool] = []
	stamp.landed.connect(func() -> void: landings.append(true))
	stamp.slam(true)
	assert_bool(stamp.is_showing()).is_true()
	assert_bool(stamp.is_slamming()).is_false()
	assert_bool(stamp.has_dust()).is_false()
	assert_array(landings).is_empty()
	stamp.hide_stamp()
	stamp.slam(false)
	assert_bool(stamp.is_showing()).is_true()
	assert_bool(stamp.is_slamming()).is_true()
	await get_tree().create_timer(MetStamp.SLAM_IN_S + 0.05).timeout
	# The tree runs its timers before its tweens: one more frame lets the slam's tween catch up
	# with a long frame that fired the timer.
	await get_tree().process_frame
	assert_array(landings).is_equal([true])
	assert_bool(stamp.has_dust()).is_true()
	await get_tree().create_timer(MetStamp.SLAM_SETTLE_S + MetStamp.DUST_LIFE.y + 0.1).timeout
	assert_bool(stamp.is_slamming()).is_false()
	assert_bool(stamp.has_dust()).is_false()
	assert_bool(led.beat().to_go_label().visible).is_false()


## On the real screen the LED stays blank in planning as cards are placed (the monitor's store
## channel has the screen; the top bar's quota chip carries the preview's total,
## monitor_channel_test), and a checkout's end state shows core's total, met (#86 v6: the
## count-up's quota_met, without a pop), in the count's gold.
func test_the_screen_shows_core_totals() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
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
	# The end state of a checkout that met the quota: TOTAL, met at once.
	var result: ScoreResult = run.preview()
	var pops: Array[bool] = []
	screen._count_up.quota_met.connect(func(pop: bool) -> void: pops.append(pop))
	screen._count_up.show_end_state(result, 1, screen.count_up_context())
	await _frames(2)
	assert_str(led.caption_label().text).is_equal(LedDisplay.TOTAL_TEXT)
	assert_str(led.digits_label().text).is_equal("%d" % result.total)
	assert_that(_colour(led)).is_equal(LedDisplay.COUNT_DIGITS_COLOR)
	assert_array(pops).is_equal([false])


func _led() -> LedDisplay:
	var led: LedDisplay = LedDisplay.new()
	var holder: Control = auto_free(Control.new())
	holder.position = ShiftStage.LED_RECT.position
	get_tree().root.add_child(holder)
	holder.add_child(led)
	await _frames(1)
	return led


static func _shifted(rect: Rect2, origin: Vector2) -> Rect2:
	return Rect2(origin + rect.position, rect.size)


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
