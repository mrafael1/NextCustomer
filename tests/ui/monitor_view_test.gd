extends GdUnitTestSuite
## The hung monitor (#80, step 4; MonitorView). Its geometry on the real screen: hung under the top
## bar, on the stage, clear of the belt, the receipt and the register, every part of its screen
## inside the paper. A scan's text fits the screen for every card in data/cards, in the hand and on
## the belt (with the worst footer, folded into "+N more" on the smallest size); the count-up's
## content fits at the largest punch with the longest digits, gain, names, step lines and to-go
## texts. Its states on the real screen: idle in planning, the scanned item once a hover is held
## (never on a plain hover), idle again when the scan ends, a notice over a scan (in ink, never
## tomato); each count-up beat's item, "n / m", gain and step line (whole), the to-go text from
## core's ShiftMargin, then the TOTAL alone. The gain chip pops in on the count-up's tweens;
## reduced motion leaves its pop out. ScreenShade leaves its hole unshaded. Headless
## runs never move the mouse: the tests set the scanner's pointer and clock. The real saves and
## logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const CARDS := "res://data/cards"
const BALANCE := "res://data/balance/balance.tres"
## Milk, Multipack, Milk x5 = 109: passes the first five quotas.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
## The longest amounts the count layout is expected to show: the digits, a gain, a quota (shift
## 8's 120 with the Big basket's 15%) and the widest to-go texts.
const LONGEST_DIGITS := "€9999"
const LONGEST_GAIN := 999
const WIDEST_QUOTA := 138
## The widest three-digit total in the count's digits font, and the simulator's largest total
## (reports/balance_sim, shift 8's max: 1118): both show at the largest digits size. A wide
## four-digit total takes a smaller one.
const WIDEST_TOTAL := 400
const LARGEST_TOTAL := 1118
const WIDE_FOUR_DIGITS := 1000
## More step lines than any belt item carries, every other one a fizzle whose reason wraps.
const WORST_LINES := 12
const LONG_LINE := "Coupon engine: needs a coupon two slots earlier and finds none there  fizzle"
const SHORT_LINE := "× Multipack  ×3"
const LONG_STEP := "Spot check: the 3rd product pays €0  = 0"

var _folder: String = ""
## Where the tests put the pointer (global), and the scanner's clock (ms).
var _point: Vector2 = Vector2.ZERO
var _clock: int = 0


func before_test() -> void:
	_folder = "user://test_monitor_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_point = Vector2(-100, -100)
	_clock = 1000


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The monitor hangs at MONITOR_RECT under the top bar, everything it draws (rods and shade
## included) on the stage and clear of the belt, the row's cells, the receipt and the register;
## its screen's parts lie inside the paper, the art column apart from the text column and from
## the LED's count place.
func test_the_monitor_hangs_on_the_stage_clear_of_the_rest() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["milk", "bread"])
	var stage: Rect2 = screen._stage.get_global_rect()
	var monitor: MonitorView = screen._monitor
	assert_object(monitor).is_same(screen._stage.monitor)
	assert_object(screen._led.get_parent()).is_same(monitor)
	assert_that(monitor.get_global_rect()).is_equal(_on_stage(screen, ShiftStage.MONITOR_RECT))
	var drawn: Rect2 = _on_stage(screen, MonitorView.DRAWN_RECT)
	var parts: Array[Rect2] = [ShiftStage.MONITOR_RECT, ShiftStage.MONITOR_UNDER_RECT]
	parts.append_array(ShiftStage.ROD_RECTS)
	for part: Rect2 in parts:
		var rect: Rect2 = _on_stage(screen, part)
		assert_bool(drawn.encloses(rect)).override_failure_message(str(rect)).is_true()
	assert_bool(stage.encloses(drawn)).is_true()
	assert_float(drawn.position.y).is_greater_equal(stage.position.y + ShiftStage.TOP_BAR_BOTTOM)
	for child: Node in screen._top_bar.get_children():
		var bar_part: Control = child as Control
		if bar_part.visible and (bar_part is PanelContainer or bar_part is Button):
			assert_bool(drawn.intersects(bar_part.get_global_rect())).is_false()
	var others: Array[Rect2] = [
		_on_stage(screen, ShiftStage.BELT_RECT),
		_on_stage(screen, ShiftStage.REGISTER_RECT),
		screen._receipt.get_global_rect(),
	]
	for slot: PanelContainer in screen._slots:
		others.append(slot.get_global_rect())
	for other: Rect2 in others:
		assert_bool(drawn.intersects(other)).override_failure_message(str(other)).is_false()
	# The screen's parts, on its paper (inside its ink border).
	var paper: Rect2 = _on_stage(screen, ShiftStage.MONITOR_SCREEN_RECT).grow(-MonitorView.OUTLINE)
	var content: Rect2 = _on_stage(screen, MonitorView.CONTENT_RECT)
	assert_bool(paper.encloses(content)).is_true()
	for part: Rect2 in [
		ShiftStage.LED_RECT,
		ShiftStage.NOTICE_RECT,
		MonitorView.LED_COUNT_RECT,
		MonitorView.LED_TOTAL_RECT,
	]:
		var rect: Rect2 = _on_stage(screen, part)
		assert_bool(paper.encloses(rect)).override_failure_message(str(rect)).is_true()
	var art_column: Array[Rect2] = [
		MonitorView.ART_RECT,
		MonitorView.KIND_RECT,
		MonitorView.COUNT_NAME_RECT,
		MonitorView.COUNT_ITEM_RECT,
	]
	for part: Rect2 in art_column:
		(
			assert_bool(MonitorView.CONTENT_RECT.encloses(part))
			. override_failure_message(str(part))
			. is_true()
		)
		assert_bool(part.intersects(MonitorView.TEXT_RECT)).is_false()
		assert_bool(part.intersects(MonitorView.LED_COUNT_RECT)).is_false()
	assert_bool(MonitorView.CONTENT_RECT.encloses(MonitorView.TEXT_RECT)).is_true()
	# The LED sits compact on the screen in planning, and the monitor takes no clicks.
	assert_that(screen._led.get_global_rect()).is_equal(_on_stage(screen, ShiftStage.LED_RECT))
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.IDLE)
	assert_int(monitor.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


## Every card in data/cards, scanned in the hand and on the belt (with a short footer, then the
## worst one): its art at ART_RECT, its kind, name, pays, tag line, rule text and step lines inside
## the screen's content, none overlapping, the name and the rule whole; a short footer shows at
## the largest size, the worst one folds into "+N more" on the smallest.
func test_every_card_scan_fits_the_screen() -> void:
	var monitor: MonitorView = await _monitor()
	var balance: BalanceDefinition = load(BALANCE) as BalanceDefinition
	var worst: PackedStringArray = PackedStringArray()
	var worst_fizzles: Array[bool] = []
	for index: int in range(WORST_LINES):
		worst.append(LONG_LINE if index % 2 == 0 else SHORT_LINE)
		worst_fizzles.append(index % 2 == 0)
	var short: PackedStringArray = PackedStringArray([SHORT_LINE, LONG_LINE])
	var short_fizzles: Array[bool] = [false, true]
	var cards: Array[CardDefinition] = _cards()
	assert_int(cards.size()).is_equal(59)
	var tiers: Dictionary[int, int] = {}
	for definition: CardDefinition in cards:
		var aisle: AisleDefinition = balance.aisle_of(definition)
		var none: Array[bool] = []
		monitor.show_scan(definition, aisle, definition.tags, -1, PackedStringArray(), none)
		await get_tree().process_frame
		_assert_scan_fits(monitor, definition, "%s in the hand" % definition.id)
		assert_object(monitor.scan_footer()).is_null()
		monitor.show_scan(definition, aisle, definition.tags, definition.base, short, short_fizzles)
		await get_tree().process_frame
		_assert_scan_fits(monitor, definition, "%s on the belt" % definition.id)
		var texts: PackedStringArray = monitor.scan_footer().texts()
		assert_bool(texts == short).override_failure_message(str(texts)).is_true()
		var count: int = tiers.get(monitor.scan_tier(), 0)
		tiers[monitor.scan_tier()] = count + 1
		monitor.show_scan(definition, aisle, definition.tags, definition.base, worst, worst_fizzles)
		await get_tree().process_frame
		_assert_scan_fits(monitor, definition, "%s, worst footer" % definition.id)
		assert_int(monitor.scan_tier()).is_equal(MonitorView.TIERS.size() - 1)
		texts = monitor.scan_footer().texts()
		var shown: int = texts.size() - 1
		assert_int(shown).override_failure_message(definition.id).is_greater_equal(1)
		assert_str(texts[shown]).is_equal(ScanFooter.MORE_TEXT % (WORST_LINES - shown))
	prints("#80 monitor scan tiers with a short footer:", tiers)
	var at_largest: int = tiers.get(0, 0)
	assert_int(2 * at_largest).is_greater(cards.size())


## The count layout at its fullest (mock-up B2's count-up screen, on the paper): every realistic
## total up to €999 (the widest three-digit one) and the simulator's largest, €1118, shows at the
## largest digits size, and a wide four-digit total (€1000) and the longest digits take a smaller
## one inside the digits' room; unpunched, the digits' ink (and its shadow) stays clear of the
## caption row, the step line, the gain chip (and its shadow) and the quota row, and at the
## count-up's largest punch inside the monitor's paper, in the count place and in the TOTAL's. The
## widest gain chip, its shadow included, sits in its room right of the digits'; the step line on
## the caption row right of the caption, a long fizzle's reason whole and in dark tomato; the
## widest to-go texts between the bar and the LED's end; the quota chip in its room over "QUOTA
## €N" (the word in the spaced display font, the amount in the number font), clear of the bar;
## the longest name fits the art column, uppercase in B2's caption voice. The colours are B2's:
## ink digits over a mustard-light shadow with no outline or shadow outline (green once met),
## light-ink text, no tomato but the fizzle's. At the TOTAL the LED stands near the paper's centre
## and the beat goes.
func test_the_count_content_fits_at_the_largest_punch() -> void:
	var monitor: MonitorView = await _monitor()
	var led: LedDisplay = monitor.led
	led.start_count(WIDEST_QUOTA)
	led.show_subtotal(9999, false)
	assert_that(led.get_global_rect()).is_equal(MonitorView.LED_COUNT_RECT)
	assert_vector(led.size).is_equal(LedDisplay.COUNT_SIZE)
	assert_int(led.layout()).is_equal(LedDisplay.Layout.COUNT)
	assert_bool(led.clip_contents).is_false()
	var longest: CardDefinition = _longest_named()
	monitor.show_beat(longest, 9, 9, LONGEST_GAIN, LONG_STEP, true)
	await _frames(2)
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.COUNT)
	var paper: Rect2 = ShiftStage.MONITOR_SCREEN_RECT.grow(-MonitorView.OUTLINE)
	var box: Rect2 = led.get_global_rect()
	var digits: Label = led.digits_label()
	var caption: Rect2 = led.caption_label().get_global_rect()
	var row: Rect2 = LedDisplay.COUNT_QUOTA_ROW
	var quota_row: Rect2 = Rect2(box.position + row.position, row.size)
	var beat: LedBeat = led.beat()
	# The gain chip with its shadow (LedBeat.GainFace).
	var gain: Rect2 = beat.gain_label().get_global_rect()
	gain.size += Vector2.ONE * LedBeat.GAIN_SHADOW
	var step: Rect2 = beat.step_label().get_global_rect()
	assert_str(beat.gain_label().text).is_equal("+€%d" % LONGEST_GAIN)
	assert_float(gain.size.x).is_less_equal(LedBeat.GAIN_RECT.size.x)
	assert_bool(beat.gain_label().get_theme_stylebox("normal") is LedBeat.GainFace).is_true()
	var room_end: float = box.position.x + LedDisplay.COUNT_DIGITS_RECT.end.x
	assert_float(gain.position.x).is_greater_equal(room_end)
	for rect: Rect2 in [caption, quota_row, gain, step]:
		assert_bool(box.encloses(rect)).override_failure_message(str(rect)).is_true()
	assert_bool(paper.encloses(box)).is_true()
	# The longest digits shrink into the room; every realistic total keeps the largest size.
	assert_str(digits.text).is_equal(LONGEST_DIGITS)
	assert_int(digits.get_theme_font_size("font_size")).is_less(LedDisplay.COUNT_DIGITS_SIZES[0])
	var tuning: CountUpTuning = load(CountUp.TUNING_PATH)
	var largest: float = maxf(
		CountUp.SUBTOTAL_PUNCH + CountUp.SUBTOTAL_PUNCH_MAX + tuning.passes_best_punch,
		CountUp.TOTAL_PUNCH
	)
	for amount: int in [WIDEST_TOTAL, LARGEST_TOTAL, WIDE_FOUR_DIGITS, 9999]:
		led.show_subtotal(amount, false)
		await _frames(1)
		var text: String = digits.text
		var font_size: int = digits.get_theme_font_size("font_size")
		var at_largest: bool = amount == WIDEST_TOTAL or amount == LARGEST_TOTAL
		var size_message: String = "%s at %d" % [text, font_size]
		(
			assert_bool(font_size == LedDisplay.COUNT_DIGITS_SIZES[0])
			. override_failure_message(size_message)
			. is_equal(at_largest)
		)
		var ink: Rect2 = led.digits_text_rect()
		assert_float(ink.size.x).is_less_equal(LedDisplay.COUNT_DIGITS_RECT.size.x)
		var shadowed: Rect2 = Rect2(ink.position, ink.size + Vector2.ONE * LedDisplay.COUNT_SHADOW)
		assert_bool(box.encloses(shadowed)).override_failure_message(text + str(ink)).is_true()
		for rect: Rect2 in [caption, quota_row, gain, step]:
			var message: String = "%s %s over %s" % [text, shadowed, rect]
			assert_bool(shadowed.intersects(rect)).override_failure_message(message).is_false()
		for place: Rect2 in [MonitorView.LED_COUNT_RECT, MonitorView.LED_TOTAL_RECT]:
			led.position = MonitorView.local(place).position
			digits.scale = Vector2(largest, largest)
			var punched: Rect2 = led.digits_text_rect()
			prints("#80 count digits", text, font_size, "at", largest, ":", punched, "paper", paper)
			var punched_message: String = "%s %s" % [text, punched]
			assert_bool(paper.encloses(punched)).override_failure_message(punched_message).is_true()
			digits.scale = Vector2.ONE
		led.position = MonitorView.local(MonitorView.LED_COUNT_RECT).position
	# The step line: on the caption row's right, in dark tomato for a fizzle, a long reason whole.
	assert_bool(beat.step_label().visible).is_true()
	assert_that(beat.step_label().get_theme_color("font_color")).is_equal(LedBeat.FIZZLE_COLOR)
	assert_that(LedBeat.FIZZLE_COLOR).is_equal(Palette.TOMATO_DARK)
	var caption_end: float = caption.position.x + _text_width(led.caption_label())
	monitor.show_beat(longest, 9, 9, LONGEST_GAIN, SHORT_LINE, false)
	await _frames(1)
	step = beat.step_label().get_global_rect()
	assert_int(beat.step_label().get_line_count()).is_equal(1)
	assert_float(step.end.x - _text_width(beat.step_label())).is_greater(caption_end)
	assert_float(step.get_center().y).is_equal_approx(caption.get_center().y, 1.0)
	assert_that(beat.step_label().get_theme_color("font_color")).is_equal(LedBeat.TEXT_COLOR)
	monitor.show_beat(longest, 9, 9, LONGEST_GAIN, LONG_LINE, true)
	await _frames(1)
	_assert_step_whole(beat.step_label(), LONG_LINE)
	step = beat.step_label().get_global_rect()
	assert_bool(box.encloses(step)).override_failure_message(str(step)).is_true()
	assert_float(step.position.x).is_greater_equal(caption.end.x)
	var step_message: String = str(step)
	(
		assert_bool(led.digits_text_rect().intersects(step))
		. override_failure_message(step_message)
		. is_false()
	)
	# The widest to-go texts between the bar and the LED's end.
	var to_go: Label = beat.to_go_label()
	var bar_end: float = box.position.x + led.segment_rect(LedDisplay.SEGMENTS - 1).end.x
	for amount: int in [WIDEST_QUOTA, 0, -9999]:
		var margin: ShiftMargin = ShiftMargin.of(WIDEST_QUOTA - amount, WIDEST_QUOTA)
		var to_go_text: String = LedBeat.to_go_text(margin)
		to_go.text = to_go_text
		var rect: Rect2 = to_go.get_global_rect()
		assert_float(rect.position.x).override_failure_message(to_go_text).is_greater(bar_end)
		assert_float(rect_end_of(to_go)).override_failure_message(to_go_text).is_less_equal(
			box.end.x
		)
	# The quota chip in its room over "QUOTA €138", clear of the bar.
	var anchor: Rect2 = led.quota_anchor()
	assert_float(anchor.size.x).is_greater_equal(led.quota_text_width())
	var chip: QuotaChip = auto_free(QuotaChip.new())
	get_tree().root.add_child(chip)
	chip.follow_anchor(led.quota_anchor, led.quota_text_width)
	await _frames(1)
	var chip_rect: Rect2 = chip.get_global_rect()
	var bar_start: float = box.position.x + led.segment_rect(0).position.x
	assert_bool(box.encloses(chip_rect)).override_failure_message(str(chip_rect)).is_true()
	assert_float(chip_rect.end.x).is_less(bar_start - LedDisplay.COUNT_BAR_BORDER)
	assert_float(chip_rect.position.x).is_less_equal(anchor.end.x - led.quota_text_width())
	# B2's colours.
	assert_that(digits.get_theme_color("font_color")).is_equal(Palette.INK)
	assert_that(digits.get_theme_color("font_shadow_color")).is_equal(Palette.MUSTARD_LIGHT)
	assert_int(digits.get_theme_constant("outline_size")).is_equal(0)
	assert_int(digits.get_theme_constant("shadow_outline_size")).is_equal(0)
	assert_that(led.caption_label().get_theme_color("font_color")).is_equal(Palette.INK_LIGHT)
	var word: Label = led.quota_word_label()
	for label: Label in [led.quota_label(), word]:
		assert_that(label.get_theme_color("font_color")).is_equal(Palette.INK_LIGHT)
	# The quota row as B2's: the word in the spaced display font, the amount in the number font,
	# QUOTA_WORD_GAP apart.
	assert_str(word.text).is_equal(LedDisplay.QUOTA_WORD)
	assert_bool(word.is_visible_in_tree()).is_true()
	assert_object(word.get_theme_font("font")).is_same(
		ArtStyle.spaced_display_font(LedDisplay.COUNT_QUOTA_WORD_SPACING)
	)
	assert_str(led.quota_label().text).is_equal("€%d" % WIDEST_QUOTA)
	assert_object(led.quota_label().get_theme_font("font")).is_same(ArtStyle.number_font())
	var gap: float = _text_start_right(led.quota_label()) - word.get_global_rect().end.x
	assert_float(gap).is_equal_approx(LedDisplay.QUOTA_WORD_GAP, 0.01)
	led.show_subtotal(WIDEST_QUOTA, true)
	assert_that(digits.get_theme_color("font_color")).is_equal(Palette.GOOD)
	var shown: Array[Label] = [led.caption_label(), digits, led.quota_label(), word, to_go]
	shown.append(beat.gain_label())
	for label: Label in shown:
		var colour: Color = label.get_theme_color("font_color")
		for tomato: Color in [Palette.TOMATO, Palette.TOMATO_DARK, Palette.TOMATO_LIGHT]:
			assert_bool(colour == tomato).override_failure_message(label.text).is_false()
	# The art column: the item's art, the longest name on two lines at most and "9 / 9", in B2's
	# caption voice.
	var name_label: Label = monitor.count_name_label()
	assert_str(name_label.text).is_equal(longest.display_name.to_upper())
	for label: Label in [name_label, monitor.count_item_label()]:
		assert_object(label.get_theme_font("font")).is_same(
			ArtStyle.spaced_display_font(MonitorView.COUNT_NAME_SPACING)
		)
		assert_that(label.get_theme_color("font_color")).is_equal(Palette.INK_LIGHT)
	assert_int(name_label.get_line_count()).is_less_equal(MonitorView.COUNT_NAME_LINES)
	assert_float(name_label.get_minimum_size().y).is_less_equal(MonitorView.COUNT_NAME_RECT.size.y)
	assert_that(name_label.get_global_rect()).is_equal(MonitorView.COUNT_NAME_RECT)
	assert_str(monitor.count_item_label().text).is_equal("9 / 9")
	assert_float(_text_width(monitor.count_item_label())).is_less_equal(
		MonitorView.COUNT_ITEM_RECT.size.x
	)
	assert_that(monitor.count_art().get_global_rect()).is_equal(MonitorView.ART_RECT)
	assert_object(monitor.count_art().texture).is_same(ArtStyle.item_sprite(longest))
	# The TOTAL: alone, near the paper's centre, the beat gone, the to-go kept.
	led.show_total()
	await _frames(1)
	assert_that(led.get_global_rect()).is_equal(MonitorView.LED_TOTAL_RECT)
	var total_centre: float = MonitorView.LED_TOTAL_RECT.get_center().x
	assert_float(total_centre).is_equal_approx(paper.get_center().x, MonitorView.TOTAL_OFF_CENTRE)
	assert_bool(monitor.count_art().is_visible_in_tree()).is_false()
	assert_bool(beat.gain_label().visible).is_false()
	assert_bool(beat.step_label().visible).is_false()
	assert_bool(to_go.visible).is_true()
	assert_bool(word.is_visible_in_tree()).is_true()


## Every card's name in the count's art column (uppercase, B2's caption voice): at 13 px when it
## fits the column on one line, else at the smaller size, on COUNT_NAME_LINES lines at most, every
## word inside the column and the lines inside the name's rect.
func test_every_count_name_fits_the_art_column() -> void:
	var monitor: MonitorView = await _monitor()
	monitor.led.start_count(34)
	var label: Label = monitor.count_name_label()
	var at_largest: int = 0
	for definition: CardDefinition in _cards():
		monitor.show_beat(definition, 1, 9, -1, "", false)
		await _frames(1)
		var text: String = definition.display_name.to_upper()
		assert_str(label.text).is_equal(text)
		var font: Font = label.get_theme_font("font")
		var font_size: int = label.get_theme_font_size("font_size")
		var largest: int = MonitorView.COUNT_NAME_SIZES[0]
		var one_line: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, largest).x
		var expected: int = MonitorView.COUNT_NAME_SIZES[-1]
		if one_line <= MonitorView.COUNT_NAME_RECT.size.x:
			expected = largest
			at_largest += 1
		assert_int(font_size).override_failure_message(text).is_equal(expected)
		var lines: int = label.get_line_count()
		assert_int(lines).override_failure_message(text).is_less_equal(MonitorView.COUNT_NAME_LINES)
		assert_int(label.get_visible_line_count()).override_failure_message(text).is_equal(lines)
		for word: String in text.split(" "):
			var width: float = (
				font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			)
			assert_float(width).override_failure_message(text).is_less_equal(
				MonitorView.COUNT_NAME_RECT.size.x
			)
		assert_float(label.get_minimum_size().y).override_failure_message(text).is_less_equal(
			MonitorView.COUNT_NAME_RECT.size.y
		)
		assert_that(label.get_global_rect()).is_equal(MonitorView.COUNT_NAME_RECT)
	prints("#80 count names at the largest size:", at_largest, "of", _cards().size())
	assert_int(at_largest).is_greater(0)


## On the real screen: idle in planning; a plain hover on a belt item leaves it idle; the held
## hover fills it with the item (its art, name, rule, pays and step lines worded as the receipt
## words them, no popup); a notice takes the screen while it lasts, then the scan comes back;
## leaving the item brings the idle screen back with the projected total. A hand item shows no
## pays or step lines.
func test_a_held_scan_fills_the_monitor_then_it_goes_back_to_idle() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["milk", "bread", "coffee"])
	var monitor: MonitorView = screen._monitor
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.IDLE)
	var view: ItemView = screen._row_views[2] as ItemView
	await _hover(screen, view)
	_clock += screen._scan.hold_ms() - 1
	await _frames(2)
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.IDLE)
	assert_bool(screen._led.visible).is_true()
	_clock += 1
	await _frames(2)
	assert_bool(screen._scan.is_full()).is_true()
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.SCAN)
	assert_bool(screen._scan.popup().visible).is_false()
	assert_bool(screen._led.visible).is_false()
	var definition: CardDefinition = view.card.definition
	assert_str(monitor.scan_name_label().text).is_equal(definition.display_name)
	assert_str(monitor.scan_rule_label().text).is_equal(definition.rule_text)
	assert_object(monitor.scan_art().texture).is_same(ArtStyle.item_sprite(definition))
	var result: ScoreResult = screen.run.preview()
	var expected: PackedStringArray = PackedStringArray()
	for step: ScoreStep in ScanController.footer_steps(result, 2):
		expected.append(ReceiptView.step_line(step, ShiftScreen._names(screen.run.row)))
	var texts: PackedStringArray = monitor.scan_footer().texts()
	assert_bool(texts == expected).override_failure_message(str(texts)).is_true()
	assert_bool(_shown_texts(monitor).has("€%d" % result.payouts[2])).is_true()
	assert_bool(_shown_texts(monitor).has(MonitorView.PAYS_WORD)).is_true()
	# A notice takes the screen while it lasts, in ink (tomato is for fizzles, CHECKOUT and
	# CLOSED); the scan comes back.
	screen._notice_label.show_notice("Row full (9/9 items): take an item out first")
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.IDLE)
	assert_bool(screen._led.visible).is_true()
	assert_bool(screen._notice_label.is_visible_in_tree()).is_true()
	var notice_colour: Color = screen._notice_label.get_theme_color("font_color")
	assert_that(notice_colour).is_equal(MonitorView.NOTICE_COLOR)
	for tomato: Color in [Palette.TOMATO, Palette.TOMATO_DARK, Palette.TOMATO_LIGHT]:
		assert_bool(notice_colour == tomato).is_false()
	screen._notice_label.clear_notice()
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.SCAN)
	# Off the item: idle, with the projected total.
	_point = Vector2(-100, -100)
	view.unhovered.emit(view)
	await _frames(2)
	assert_object(screen._scan.scanned()).is_null()
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.IDLE)
	assert_bool(screen._led.visible).is_true()
	assert_str(screen._led.caption()).is_equal(LedDisplay.PROJECTED_TEXT)
	assert_that(screen._led.get_global_rect()).is_equal(_on_stage(screen, ShiftStage.LED_RECT))
	# A hand item: no pays and no step lines.
	var hand_item: ItemView = screen._hand_box.cards()[0] as ItemView
	await _hover(screen, hand_item)
	_clock += screen._scan.hold_ms()
	await _frames(2)
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.SCAN)
	assert_object(monitor.scan_footer()).is_null()
	assert_bool(_shown_texts(monitor).has(MonitorView.PAYS_WORD)).is_false()
	screen._scan.clear()
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.IDLE)


## On the real screen, every count-up beat shows on the monitor as it starts: its item's art,
## "n / m", the payout's gain on the payout beats (none on the others), its step line as the
## receipt words it, and the to-go text of the subtotal shown (core's ShiftMargin); the LED in its
## count place. At the end the TOTAL stands alone with the total's margin, the quota chip on it.
func test_the_count_up_shows_each_beat_on_the_monitor() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, PASSING_ROW)
	var monitor: MonitorView = screen._monitor
	var led: LedDisplay = screen._led
	var quota: int = screen.run.quota()
	var failures: Array[String] = []
	var beats: Array[int] = []
	var count_place: Rect2 = _on_stage(screen, MonitorView.LED_COUNT_RECT)
	# The last beat's slot and the line it showed: a payout on the same slot keeps that line.
	var last: Array = [-1, ""]
	var kept: Array[int] = [0]
	var record: Callable = func(
		beat: CountUpBeat, step: ScoreStep, line: String, view: CardView, items: int
	) -> void:
		beats.append(beat.slot)
		var shown_line: String = line
		if beat.kind == CountUpBeat.Kind.PAYOUT and beat.slot == int(last[0]):
			shown_line = str(last[1])
			kept[0] += 1
		last[0] = beat.slot
		last[1] = shown_line
		var where: String = "beat on slot %d (%s)" % [beat.slot, CountUpBeat.Kind.keys()[beat.kind]]
		if monitor.mode() != MonitorView.Mode.COUNT:
			failures.append("%s: monitor in mode %d" % [where, monitor.mode()])
		var item: String = "%d / %d" % [beat.slot + 1, items]
		if monitor.count_item_label().text != item:
			failures.append("%s: '%s'" % [where, monitor.count_item_label().text])
		if monitor.count_art().texture != ArtStyle.item_sprite(view.card.definition):
			failures.append("%s: another item's art" % where)
		var gain: Label = led.beat().gain_label()
		var pays: bool = beat.kind in [CountUpBeat.Kind.PAYOUT, CountUpBeat.Kind.MERGED_PLAIN]
		var gain_text: String = "+€%d" % beat.payout if pays else ""
		if gain.text != gain_text or gain.visible != pays:
			failures.append("%s: gain '%s'" % [where, gain.text])
		var step_label: Label = led.beat().step_label()
		if step_label.text != shown_line:
			failures.append("%s: step '%s' != '%s'" % [where, step_label.text, shown_line])
		if not _step_whole(step_label):
			failures.append("%s: step cut ('%s')" % [where, line])
		if line != ReceiptView.step_line(step, ShiftScreen._names(screen.run.row)):
			failures.append("%s: line '%s'" % [where, line])
		var shown: int = int(led.digits_label().text.substr(1))
		var to_go: String = LedBeat.to_go_text(ShiftMargin.of(shown, quota))
		if led.beat().to_go_label().text != to_go:
			failures.append("%s: to go '%s'" % [where, led.beat().to_go_label().text])
		if not led.get_global_rect().is_equal_approx(count_place):
			failures.append("%s: LED at %s" % [where, led.get_global_rect()])
	screen._count_up.beat_started.connect(record)
	screen._on_checkout_pressed()
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.COUNT)
	await _frames(2)
	screen._count_up._tap(Time.get_ticks_msec())
	screen._count_up._tap(Time.get_ticks_msec())
	while screen._counting:
		await get_tree().process_frame
	screen._count_up.beat_started.disconnect(record)
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()
	assert_int(beats.size()).is_equal(screen._count_up.plan.beats.size())
	# Multipack's x3 on the milks: their payouts keep the stamp's line.
	assert_int(kept[0]).is_greater(0)
	for slot: int in range(PASSING_ROW.size()):
		assert_bool(beats.has(slot)).override_failure_message(str(slot)).is_true()
	# The TOTAL alone, centred, with the total's margin and the chip.
	var total: int = screen.run.last_result.total
	assert_str(led.caption()).is_equal(LedDisplay.TOTAL_TEXT)
	assert_that(led.get_global_rect()).is_equal(_on_stage(screen, MonitorView.LED_TOTAL_RECT))
	assert_str(led.beat().to_go_label().text).is_equal(
		LedBeat.to_go_text(ShiftMargin.of(total, quota))
	)
	assert_str(led.beat().to_go_label().text).is_equal(LedBeat.OVER_TEXT % (total - quota))
	assert_bool(monitor.count_art().is_visible_in_tree()).is_false()
	await _frames(2)
	var chip: QuotaChip = screen._count_up._quota_chip
	assert_bool(chip.visible).is_true()
	assert_bool(led.get_global_rect().encloses(chip.get_global_rect())).is_true()
	# The next shift's planning: idle, compact.
	screen._on_reward_skipped()
	await _frames(2)
	assert_int(monitor.mode()).is_equal(MonitorView.Mode.IDLE)
	assert_that(led.get_global_rect()).is_equal(_on_stage(screen, ShiftStage.LED_RECT))
	assert_vector(led.size).is_equal(ShiftStage.LED_RECT.size)


## The to-go text from core's ShiftMargin: short of the quota, on it and past it.
func test_the_to_go_text_follows_the_margin() -> void:
	assert_str(LedBeat.to_go_text(ShiftMargin.of(22, 73))).is_equal("€51 to go")
	assert_str(LedBeat.to_go_text(ShiftMargin.of(73, 73))).is_equal(LedBeat.ON_QUOTA_TEXT)
	assert_str(LedBeat.to_go_text(ShiftMargin.of(85, 73))).is_equal("€12 over")


## Reduced motion: a beat's gain chip shows at its size at once; without it, it pops in. The
## scan and the notices never move on the monitor.
func test_reduced_motion_leaves_the_gain_pop_out() -> void:
	var monitor: MonitorView = await _monitor()
	var milk: CardDefinition = load("%s/milk.tres" % CARDS) as CardDefinition
	var reduced: Array[bool] = [true]
	monitor.reduced_motion = func() -> bool: return reduced[0]
	monitor.led.start_count(34)
	monitor.show_beat(milk, 1, 3, 4, "MILK  2", false)
	var gain: Label = monitor.led.beat().gain_label()
	assert_bool(gain.visible).is_true()
	assert_bool(monitor.led.beat().is_popping()).is_false()
	assert_vector(gain.scale).is_equal(Vector2.ONE)
	reduced[0] = false
	monitor.show_beat(milk, 2, 3, 4, "MILK  2", false)
	assert_bool(monitor.led.beat().is_popping()).is_true()
	assert_float(gain.scale.x).is_greater(1.0)
	await get_tree().create_timer(LedBeat.GAIN_POP_SECONDS + 0.1).timeout
	assert_vector(gain.scale).is_equal(Vector2.ONE)
	assert_bool(monitor.led.beat().is_popping()).is_false()
	# A beat without a gain hides the chip and pops nothing.
	monitor.show_beat(milk, 3, 3, -1, "", false)
	assert_bool(gain.visible).is_false()
	assert_bool(monitor.led.beat().is_popping()).is_false()


## The gain chip's pop runs on the tween LedBeat.make_tween returns (the count-up's on the real
## screen, so it follows taps, holds and hit-stops), one per beat with a gain.
func test_the_gain_pop_runs_on_the_count_ups_tweens() -> void:
	var monitor: MonitorView = await _monitor()
	var milk: CardDefinition = load("%s/milk.tres" % CARDS) as CardDefinition
	var made: Array[Tween] = []
	monitor.led.beat().make_tween = func() -> Tween:
		var tween: Tween = monitor.create_tween().set_speed_scale(CountUp.FAST_FORWARD)
		made.append(tween)
		return tween
	monitor.led.start_count(34)
	monitor.show_beat(milk, 1, 3, 4, "MILK  2", false)
	assert_int(made.size()).is_equal(1)
	assert_bool(monitor.led.beat().is_popping()).is_true()
	monitor.show_beat(milk, 2, 3, -1, "", false)
	assert_int(made.size()).is_equal(1)
	# On the real screen the monitor takes the count-up's.
	var screen: ShiftScreen = await _screen()
	assert_bool(screen._led.beat().make_tween == screen._count_up._tween).is_true()


## The shade dims its rect but its hole: up to four bands around it that cover the rest, none over
## the hole; an empty hole (or one off the shade) shades it all.
func test_the_shade_leaves_its_hole_unshaded() -> void:
	var shade: ScreenShade = auto_free(ScreenShade.new())
	get_tree().root.add_child(shade)
	shade.position = Vector2(0, 64)
	shade.size = Vector2(944, 656)
	var area: Rect2 = shade.get_global_rect()
	assert_array(shade.shaded_rects()).is_equal([area])
	var hole: Rect2 = MonitorView.DRAWN_RECT
	shade.set_hole(hole)
	var cut: Rect2 = area.intersection(hole)
	var shaded: float = 0.0
	for rect: Rect2 in shade.shaded_rects():
		assert_bool(area.encloses(rect)).is_true()
		assert_bool(rect.intersects(cut)).override_failure_message(str(rect)).is_false()
		shaded += rect.get_area()
	assert_float(shaded).is_equal_approx(area.get_area() - cut.get_area(), 0.01)
	shade.set_hole(Rect2(2000, 2000, 10, 10))
	assert_array(shade.shaded_rects()).is_equal([area])
	assert_int(shade.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)


# --- Helpers ---------------------------------------------------------------------------------


## The step line shows `text` whole: all of its lines visible, inside its rect, which stays inside
## LedBeat.STEP_RECT's height.
func _assert_step_whole(label: Label, text: String) -> void:
	assert_str(label.text).is_equal(text)
	assert_bool(label.visible).is_true()
	assert_bool(_step_whole(label)).override_failure_message(text).is_true()


static func _step_whole(label: Label) -> bool:
	var lines: int = label.get_line_count()
	return (
		label.get_visible_line_count() == lines
		and label.get_minimum_size().y <= label.size.y
		and label.position.y + label.size.y <= LedBeat.STEP_RECT.end.y
	)


## The scan inside the screen's content: every text label shown and the art, the scan's own
## parts (its art, kind, name, pays, tag line and rule) apart, the name on one row and the rule
## whole.
func _assert_scan_fits(monitor: MonitorView, definition: CardDefinition, message: String) -> void:
	assert_int(monitor.mode()).override_failure_message(message).is_equal(MonitorView.Mode.SCAN)
	var content: Rect2 = MonitorView.CONTENT_RECT
	var art: TextureRect = monitor.scan_art()
	assert_that(art.get_global_rect()).override_failure_message(message).is_equal(
		MonitorView.ART_RECT
	)
	assert_object(art.texture).is_same(ArtStyle.item_sprite(definition))
	for label: Label in monitor.shown_labels():
		var rect: Rect2 = label.get_global_rect()
		(
			assert_bool(content.encloses(rect))
			. override_failure_message("%s: '%s' %s" % [message, label.text, rect])
			. is_true()
		)
	var own: Array[Control] = [art]
	for child: Node in art.get_parent().get_children():
		if child is Label:
			own.append(child as Control)
	for index: int in range(own.size()):
		for other: int in range(index + 1, own.size()):
			var a: Rect2 = own[index].get_global_rect()
			var b: Rect2 = own[other].get_global_rect()
			(
				assert_bool(a.intersects(b))
				. override_failure_message("%s: %s over %s" % [message, a, b])
				. is_false()
			)
	var name_label: Label = monitor.scan_name_label()
	assert_str(name_label.text).is_equal(definition.display_name)
	assert_float(_text_width(name_label)).override_failure_message(message).is_less_equal(
		name_label.size.x
	)
	var rule: Label = monitor.scan_rule_label()
	assert_str(rule.text).is_equal(definition.rule_text)
	assert_int(rule.get_visible_line_count()).override_failure_message(message).is_equal(
		rule.get_line_count()
	)


## A monitor alone at its stage place, in the tree.
func _monitor() -> MonitorView:
	var holder: Control = auto_free(Control.new())
	get_tree().root.add_child(holder)
	var monitor: MonitorView = MonitorView.new()
	holder.add_child(monitor)
	await _frames(1)
	return monitor


static func _cards() -> Array[CardDefinition]:
	var cards: Array[CardDefinition] = []
	for file_name: String in DirAccess.get_files_at(CARDS):
		if file_name.ends_with(".tres"):
			cards.append(load(CARDS.path_join(file_name)) as CardDefinition)
	return cards


## The card whose name (uppercase) is the widest in the count's name font, at its smallest size.
static func _longest_named() -> CardDefinition:
	var font: Font = ArtStyle.spaced_display_font(MonitorView.COUNT_NAME_SPACING)
	var font_size: int = MonitorView.COUNT_NAME_SIZES[-1]
	var longest: CardDefinition = null
	var widest: float = 0.0
	for definition: CardDefinition in _cards():
		var text: String = definition.display_name.to_upper()
		var width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if width > widest:
			widest = width
			longest = definition
	return longest


## A label's text width, in its own font and size.
static func _text_width(label: Label) -> float:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	return font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x


## Where a label's text ends (global).
static func rect_end_of(label: Label) -> float:
	return label.get_global_rect().position.x + _text_width(label)


## Where a right-aligned label's text starts (global).
static func _text_start_right(label: Label) -> float:
	return label.get_global_rect().end.x - _text_width(label)


static func _shown_texts(monitor: MonitorView) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for label: Label in monitor.shown_labels():
		texts.append(label.text)
	return texts


## The screen past the impulse rack, its scanner following _point on the tests' clock.
func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()
	screen._scan.pointer = func() -> Vector2: return _point
	screen._scan.now_ms = func() -> int: return _clock
	await _frames(3)
	return screen


## Puts copies of cards into the row, in order, and refreshes the screen.
func _place(screen: ShiftScreen, card_ids: Array[String]) -> void:
	var run: RunState = screen.run
	for card_id: String in card_ids:
		var card: CardInstance = run.debug_add_to_hand(load("%s/%s.tres" % [CARDS, card_id]))
		assert_bool(run.place(card, run.row.size())).override_failure_message(card_id).is_true()
	screen._refresh()
	await _frames(2)


## The pointer on `view`'s sprite and its hover sent, its hold starting on the tests' clock.
func _hover(screen: ShiftScreen, view: ItemView) -> void:
	await _frames(1)
	_point = view.sprite().get_global_rect().get_center()
	view.hovered.emit(view)
	await _frames(1)
	assert_object(screen._scan.scanned()).is_same(view)


## `rect` (stage coordinates) on screen.
static func _on_stage(screen: ShiftScreen, rect: Rect2) -> Rect2:
	return Rect2(screen._stage.get_global_rect().position + rect.position, rect.size)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
