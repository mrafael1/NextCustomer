extends GdUnitTestSuite
## The desk calendar (left column v2, the user's pick of 2026-11-09: mock-up
## docs/art/mockups/left_column_v2.html; DayCalendar painting DeskCalendarArt): a small flip
## calendar standing on the register's top, at the column's right, in place of v1.17's top-bar
## pad. On the real shift screen at 1280x720 and 1920x1080 it stands on the register's top inside
## the stage and the window, its right edge at DESK_CALENDAR_RECT's, right of the service bell;
## its rect is the same on every kind of day (a normal day with no sign, an inspection, a boon
## day, a review), for each of the pool's events alone, from week to week, with a hovered item's
## named cause and with a worn Day off's SKIP tag (over the pad). DAY, the number and the kind's
## sign stay inside the page and apart, with no kind word (the band's colour, the sign and the
## tooltip say it); one paper edge per day left in the week under the page. Every word the
## tooltip's chips may print has its glyphs. The day change flips the old page up over the rings
## in whole art pixels, or snaps under reduced motion and on a resume. LOYALTY keeps its place.

const SCREEN := "res://ui/shift_screen.tscn"
const INSPECTIONS := "res://data/inspections/"
const DAY_OFF := "res://data/pins/day_off.tres"
const BALANCE := "res://data/balance/balance.tres"
## Week 2's days (0-based shift indexes 4 to 7: D5 to D8).
const WEEK_TWO := 4

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## A normal day, an inspection, a boon day and a review in one week, then each of the pool's
## events alone: the calendar shows the day's number and kind (its band and sign), never an effect
## (the tooltip keeps it), and keeps its rect; LOYALTY, Cart and the menu keep theirs. One paper
## edge per day left in the week.
func test_every_kind_of_day_keeps_the_calendar_still() -> void:
	for window: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		var screen: ShiftScreen = await _screen(window)
		var calendar: DayCalendar = screen._stage.day_calendar
		var days: Array[Array] = [
			[[], DayCalendar.NORMAL_WORD, DayCalendarArt.Look.NORMAL, 0],
			[["spot_check"], InspectionTag.CAPTION, DayCalendarArt.Look.INSPECTION, 1],
			[["fresh_delivery"], "Fresh delivery", DayCalendarArt.Look.BOON, 1],
			[
				["spot_check", "small_baskets"],
				InspectionTag.REVIEW_CAPTION,
				DayCalendarArt.Look.REVIEW,
				1
			],
		]
		var first: Array[Rect2] = []
		for index: int in range(days.size()):
			var ids: Array = days[index][0]
			await _show_day(screen, WEEK_TWO + index, ids)
			var message: String = "D%d at %s" % [WEEK_TWO + index + 1, window]
			assert_int(calendar.day()).is_equal(WEEK_TWO + index + 1)
			assert_str(calendar.text()).override_failure_message(message).is_equal(days[index][1])
			assert_int(calendar.look()).override_failure_message(message).is_equal(days[index][2])
			var parts: Dictionary = calendar.part_rects()
			var signs: Array = parts["signs"]
			# A payday's page (the week's last day here) reads PAYDAY on its band, in place of
			# DAY and the sign (2026-11-10); any other day has neither word nor band.
			var payday: bool = ReceiptGoldFlow.payday(screen.run)
			assert_bool(payday).override_failure_message(message).is_equal(index == 3)
			var expected_signs: int = 0 if payday else days[index][3]
			assert_int(signs.size()).override_failure_message(message).is_equal(expected_signs)
			_assert_payday_page(parts, payday, message)
			var edges: int = mini(3 - index, DeskCalendarArt.EDGES_MAX)
			assert_int(parts["edges"]).override_failure_message(message).is_equal(edges)
			var pips: Array = parts["pips"]
			assert_int(pips.size()).override_failure_message(message).is_equal(4)
			var today: int = calendar.pips().find(WeekCardModel.Pip.NOW)
			assert_int(today).override_failure_message(message).is_equal(index)
			var pad: Rect2 = parts["pad"]
			for pip: Rect2 in pips:
				assert_bool(pad.encloses(pip)).override_failure_message(message).is_true()
				assert_float(pip.position.y).is_greater_equal((parts["number"] as Rect2).end.y)
			var said: String = _slip_text(screen)
			for id: String in ids:
				var event: InspectionDefinition = load(INSPECTIONS + id + ".tres")
				assert_str(said).override_failure_message(message).contains(event.notice_text)
			_assert_fits(screen, message)
			var rects: Array[Rect2] = _rects(screen)
			if first.is_empty():
				first = rects
			assert_array(rects).override_failure_message(message).is_equal(first)
		# Every pool event alone on the same day: its kind, the same rects.
		var pool: Array[InspectionDefinition] = WeekFlow.event_pool(screen.run)
		assert_int(pool.size()).is_greater(4)
		for event: InspectionDefinition in pool:
			await _show_day(screen, WEEK_TWO + 1, [event.resource_path.get_file().get_basename()])
			var message: String = "%s at %s" % [event.display_name, window]
			var kind: String = event.display_name if event.is_boon() else InspectionTag.CAPTION
			assert_str(calendar.text()).override_failure_message(message).is_equal(kind)
			_assert_fits(screen, message)
			assert_array(_rects(screen)).override_failure_message(message).is_equal(first)


## A new week keeps the calendar's rect (D4, D5, D9, D12 a review, D13, D16 the final review; two
## digit days too), at both sizes.
func test_a_new_week_keeps_the_calendar_still() -> void:
	for window: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		var screen: ShiftScreen = await _screen(window)
		var review: Array = ["spot_check", "small_baskets"]
		var days: Array[Array] = [[3, []], [4, []], [8, []], [11, review], [12, []], [15, review]]
		var first: Array[Rect2] = []
		for day: Array in days:
			await _show_day(screen, day[0] as int, day[1] as Array)
			var message: String = "D%d at %s" % [(day[0] as int) + 1, window]
			_assert_fits(screen, message)
			var rects: Array[Rect2] = _rects(screen)
			if first.is_empty():
				first = rects
			assert_array(rects).override_failure_message(message).is_equal(first)


## Hovering an item an inspection touches names that inspection (#71: the ring, its sign), in the
## same rect; the ring off, the calendar reads "Review" again.
func test_a_named_cause_keeps_the_rect() -> void:
	for window: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		var screen: ShiftScreen = await _screen(window)
		var calendar: DayCalendar = screen._stage.day_calendar
		await _show_day(screen, WEEK_TWO + 3, ["spot_check", "small_baskets"])
		var rects: Array[Rect2] = _rects(screen)
		for cause: int in range(2):
			calendar.set_relation(true, cause)
			await _frames(1)
			assert_bool(calendar.has_relation()).is_true()
			assert_str(calendar.text()).is_equal(screen.run.inspections[cause].display_name)
			# The day is a payday: its PAYDAY band stands where the sign would (2026-11-10).
			assert_bool(ReceiptGoldFlow.payday(screen.run)).is_true()
			assert_int((calendar.part_rects()["signs"] as Array).size()).is_equal(0)
			assert_bool((calendar.part_rects()["payday"] as Rect2).has_area()).is_true()
			_assert_fits(screen, "cause %d at %s" % [cause, window])
			assert_array(_rects(screen)).is_equal(rects)
		calendar.set_relation(false)
		await _frames(1)
		assert_str(calendar.text()).is_equal(InspectionTag.REVIEW_CAPTION)


## A worn Day off (#132): its SKIP tag shows over the pad on a day that can be taken off, not on a
## review, and the calendar keeps its rect either way.
func test_a_worn_day_off_keeps_the_rect() -> void:
	for window: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		var screen: ShiftScreen = await _screen(window)
		RunPins.wear(screen.run, [load(DAY_OFF) as PinDefinition])
		var calendar: DayCalendar = screen._stage.day_calendar
		await _show_day(screen, WEEK_TWO, [])
		var skip_tag: Control = calendar.tags.skip_tag()
		assert_bool(skip_tag.is_visible_in_tree()).is_true()
		_assert_fits(screen, "skip at %s" % window)
		var rects: Array[Rect2] = _rects(screen)
		var skip: Rect2 = skip_tag.get_global_rect()
		var pad: Rect2 = calendar.get_global_rect()
		assert_float(skip.end.y).is_less_equal(pad.position.y)
		assert_float(skip.end.x).is_less_equal(pad.end.x + 0.5)
		await _show_day(screen, WEEK_TWO + 3, ["spot_check", "small_baskets"])
		assert_bool(skip_tag.visible).is_false()
		_assert_fits(screen, "review at %s" % window)
		assert_array(_rects(screen)).is_equal(rects)


## Every word the calendar's tags and tooltip may print (each kind, EARNED's, every event's name in
## the run's pools and the inspections folder) and its own DAY have a glyph for each of their
## letters in the chunky capitals, so no name prints a blank.
func test_every_page_word_has_its_glyphs() -> void:
	var balance: BalanceDefinition = load(BALANCE)
	var words: Array[String] = [
		DayCalendar.NORMAL_WORD,
		DayCalendar.EARNED_WORD,
		InspectionTag.CAPTION,
		InspectionTag.REVIEW_CAPTION,
		DeskCalendarArt.PAGE_WORD
	]
	for event: InspectionDefinition in balance.inspection_pool + balance.boon_pool:
		words.append(event.display_name)
	for file_name: String in DirAccess.get_files_at(INSPECTIONS):
		if file_name.ends_with(".tres"):
			words.append((load(INSPECTIONS + file_name) as InspectionDefinition).display_name)
	var blank: Array = PixelWords.glyph_of(" ", PixelWords.Sheet.CHUNKY_CAPS)
	for word: String in words:
		for character: String in word.to_upper():
			if character == " ":
				continue
			var glyph: Array = PixelWords.glyph_of(character, PixelWords.Sheet.CHUNKY_CAPS)
			(
				assert_bool(glyph != blank)
				. override_failure_message("'%s' in %s" % [character, word])
				. is_true()
			)


## The desk's art: 46 art px square under FLIP_ROOM rows for the flip; the band in the day kind's
## colour (DayCalendarArt.band) under two steel rings; DAY, the sign and the number (DIGITS at
## NUMBER_CELL) inside the page and apart; one cream edge per day left (EDGES_MAX at most); nothing
## above the rings at rest. Palette colours only.
func test_the_desk_art() -> void:
	var image: Image = Image.create(
		DeskCalendarArt.SIZE,
		DeskCalendarArt.SIZE + DeskCalendarArt.FLIP_ROOM,
		false,
		Image.FORMAT_RGBA8
	)
	var top: int = DeskCalendarArt.FLIP_ROOM
	for look: DayCalendarArt.Look in DayCalendarArt.Look.values():
		var page: DayCalendarArt.Page = DayCalendarArt.Page.new()
		page.day = 12
		page.look = look
		page.mark = DayCalendarArt.Sign.WARNING
		DeskCalendarArt.paint_desk(image, page, 2)
		var band: Color = image.get_pixel(
			floori(DeskCalendarArt.SIZE / 2.0), top + DeskCalendarArt.BAND_Y + 2
		)
		assert_that(band).is_equal(DayCalendarArt.band(look)[0])
		for x: int in DeskCalendarArt.RINGS:
			assert_that(image.get_pixel(x + 1, top + 1)).is_equal(Palette.STEEL_LIGHT)
		for y: int in range(top):
			for x: int in range(DeskCalendarArt.SIZE):
				assert_float(image.get_pixel(x, y).a).is_equal(0.0)
		var number: Rect2i = DeskCalendarArt.number_rect(page)
		var day: Rect2i = DeskCalendarArt.day_rect()
		var mark: Rect2i = DeskCalendarArt.sign_rect(page)
		var paper: Rect2i = Rect2i(
			1, 0, DeskCalendarArt.SIZE - 2, DeskCalendarArt.PAGE_FOOT - DeskCalendarArt.PAGE_Y
		)
		for rect: Rect2i in [number, day, mark]:
			assert_bool(paper.encloses(rect)).override_failure_message(str(rect)).is_true()
		# The week's pips: one square per day, in a row under the number, inside the paper, apart.
		for count: int in [3, 4, 5, 8]:
			var pips: Array[Rect2i] = DeskCalendarArt.pip_rects(count)
			assert_int(pips.size()).is_equal(count)
			for index: int in range(count):
				assert_bool(paper.encloses(pips[index])).is_true()
				assert_int(pips[index].position.y).is_greater(number.end.y)
				if index > 0:
					assert_int(pips[index].position.x).is_greater(pips[index - 1].end.x)
			var margins: int = (pips[0].position.x - 1) - (paper.end.x - pips[-1].end.x)
			assert_int(absi(margins)).is_less_equal(1)
		assert_bool(number.intersects(day)).is_false()
		assert_bool(number.intersects(mark)).is_false()
		assert_bool(day.intersects(mark)).is_false()
		var digits: Vector2i = PixelWords.font_size_of("12", PixelWords.Sheet.DIGITS)
		assert_that(number.size).is_equal(digits * DeskCalendarArt.NUMBER_CELL)
		# At least one paper row between the number's bottom and the page's ink foot.
		var foot: int = DeskCalendarArt.PAGE_FOOT - DeskCalendarArt.PAGE_Y
		assert_int(foot - number.end.y).is_greater_equal(1)
		var under: int = top + DeskCalendarArt.PAGE_Y + foot - 1
		var centre: int = floori(DeskCalendarArt.SIZE / 2.0)
		assert_that(image.get_pixel(centre, under)).is_equal(Palette.PAPER)
	# The edges: one row per day left, cream and cream shade by turns, then the dark board.
	var plain: DayCalendarArt.Page = DayCalendarArt.Page.new()
	plain.day = 5
	for edges: int in range(5):
		DeskCalendarArt.paint_desk(image, plain, edges)
		var shown: int = 0
		for row: int in range(DeskCalendarArt.STAND_Y - DeskCalendarArt.EDGES_Y):
			var colour: Color = image.get_pixel(10, top + DeskCalendarArt.EDGES_Y + row)
			if colour == Palette.CREAM or colour == Palette.CREAM_SHADE:
				shown += 1
		assert_int(shown).is_equal(mini(edges, DeskCalendarArt.EDGES_MAX))
	# A normal day: no sign.
	assert_bool(DeskCalendarArt.sign_rect(plain).has_area()).is_false()
	# A week's pips as painted: passed green, today gold in ink, to come hollow, the last day's
	# frame in the review's mustard.
	plain.pips = [
		DayCalendarArt.PipLook.PAID,
		DayCalendarArt.PipLook.SLIP,
		DayCalendarArt.PipLook.TODAY,
		DayCalendarArt.PipLook.TODO,
		DayCalendarArt.PipLook.TODO,
	]
	DeskCalendarArt.paint_desk(image, plain, 2)
	var inside: Array[Color] = [
		Palette.GOOD, Palette.TOMATO, Palette.MUSTARD, Palette.PAPER, Palette.PAPER
	]
	var frames: Array[Color] = [
		Palette.GREEN_DARK,
		Palette.TOMATO_DARK,
		Palette.INK,
		Palette.STEEL_LIGHT,
		Palette.MUSTARD_DARK,
	]
	var squares: Array[Rect2i] = DeskCalendarArt.pip_rects(5)
	for index: int in range(5):
		var at: Vector2i = squares[index].position + Vector2i(0, top + DeskCalendarArt.PAGE_Y)
		assert_that(image.get_pixel(at.x + 1, at.y + 1)).is_equal(inside[index])
		assert_that(image.get_pixel(at.x, at.y)).is_equal(frames[index])


## The day change (left column v2): the next day's page waits until planning shows it, then the
## old page flips up over the rings: its first half squashes the old page in whole rows, its
## second shows its back above the rings (in the image's FLIP_ROOM), the new page under it all
## along; the flip's rect is whole art px from the pad's corner; it ends. Under reduced motion the
## new page shows at once, and a jump of days (a resume) never plays a change.
func test_the_page_flips_in_whole_art_pixels() -> void:
	var host: Control = auto_free(Control.new())
	add_child(host)
	host.size = Vector2(1280, 720)
	var calendar: DayCalendar = DayCalendar.new()
	host.add_child(calendar)
	calendar.position = ShiftStage.DESK_CALENDAR_RECT.position
	var none: Array[InspectionDefinition] = []
	var spot: Array[InspectionDefinition] = [load(INSPECTIONS + "spot_check.tres")]
	calendar.show_inspections(none, 5, [], 16)
	assert_bool(calendar.is_changing()).is_false()
	var rect: Rect2 = calendar.get_global_rect()
	calendar.show_inspections(spot, 6, [], 16)
	assert_bool(calendar.is_changing()).is_true()
	assert_that(calendar.get_global_rect()).is_equal(rect)
	calendar.play_change(true)
	var cell: float = DayCalendarArt.CELL
	var corner: Vector2 = rect.position
	var poses: int = 0
	var time: float = 0.0
	while calendar.is_changing() and time < 5.0:
		calendar.advance(1.0 / 60.0)
		time += 1.0 / 60.0
		var flip: Rect2 = calendar.part_rects()["flip"]
		if not flip.has_area():
			continue
		poses += 1
		var off: Vector2 = (flip.position - corner) / cell
		var cells: Vector2 = flip.size / cell
		var whole: bool = off == off.round() and cells == cells.round()
		assert_bool(whole).override_failure_message("%.2f s: %s" % [time, flip]).is_true()
	assert_int(poses).is_greater(5)
	assert_float(time).is_less(DayCalendar.FLIP_SECONDS + 0.1)
	assert_bool(calendar.is_changing()).is_false()
	assert_int(calendar.day()).is_equal(6)
	assert_str(calendar.text()).is_equal(InspectionTag.CAPTION)
	assert_that(calendar.get_global_rect()).is_equal(rect)
	# Reduced motion: the next day at once.
	calendar.reduced_motion = true
	calendar.show_inspections(none, 7, [], 16)
	assert_bool(calendar.is_changing()).is_true()
	calendar.play_change(true)
	assert_bool(calendar.is_changing()).is_false()
	assert_bool((calendar.part_rects()["flip"] as Rect2).has_area()).is_false()
	# A jump (a resume, the debug panel): no change waits.
	calendar.reduced_motion = false
	calendar.show_inspections(none, 11, [], 16)
	assert_bool(calendar.is_changing()).is_false()


## The flip's art: late in the flip the old page's back stands above the rings (rows in the
## image's FLIP_ROOM), early on nothing does; the new page's band shows all along.
func test_the_flip_lifts_the_page_over_the_rings() -> void:
	var size: Vector2i = Vector2i(
		DeskCalendarArt.SIZE, DeskCalendarArt.SIZE + DeskCalendarArt.FLIP_ROOM
	)
	var image: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var old: DayCalendarArt.Page = DayCalendarArt.Page.new()
	old.day = 5
	var page: DayCalendarArt.Page = DayCalendarArt.Page.new()
	page.day = 6
	page.look = DayCalendarArt.Look.INSPECTION
	var band_y: int = DeskCalendarArt.FLIP_ROOM + DeskCalendarArt.BAND_Y + 2
	for k: float in [0.1, 0.4, 0.9, 1.0]:
		DeskCalendarArt.paint_flip(image, old, page, 2, k)
		var above: int = 0
		for y: int in range(DeskCalendarArt.FLIP_ROOM):
			for x: int in range(size.x):
				if image.get_pixel(x, y).a > 0.0:
					above += 1
		if k < 0.5:
			assert_int(above).override_failure_message(str(k)).is_equal(0)
		else:
			assert_int(above).override_failure_message(str(k)).is_greater(0)
		var band: Color = image.get_pixel(floori(size.x / 2.0), band_y)
		assert_that(band).is_equal(DayCalendarArt.band(page.look)[0])


## On the real screen the next day's page waits for planning, then flips (WeekFlow) and ends; the
## page that flips is the one last seen, and today's pip stands one day on.
func test_the_next_day_flips_once_planning_shows() -> void:
	var screen: ShiftScreen = await _screen(Vector2(1280, 720))
	var calendar: DayCalendar = screen._stage.day_calendar
	assert_int(calendar.day()).is_equal(1)
	var today: int = calendar.pips().find(WeekCardModel.Pip.NOW)
	screen._week._quiet = false  # _screen() skipped the card, which quiets the flow.
	screen.run.debug_skip_to_shift(1)
	screen._week.show_chips()
	assert_int(calendar.day()).is_equal(2)
	assert_bool(calendar.is_changing()).is_true()
	assert_int(calendar._old.day).is_equal(1)
	var start: int = Time.get_ticks_msec()
	while calendar.is_changing() and Time.get_ticks_msec() - start < 3000:
		await _frames(1)
	assert_bool(calendar.is_changing()).is_false()
	assert_int(calendar.pips().find(WeekCardModel.Pip.NOW)).is_equal(today + 1)


## On a week's first day the time card plays first: the page waits under it, then flips once the
## card has gone (2026-11-08 review).
func test_the_page_waits_for_the_time_card() -> void:
	var screen: ShiftScreen = await _screen(Vector2(1280, 720))
	var calendar: DayCalendar = screen._stage.day_calendar
	screen.run.debug_skip_to_shift(3)
	screen._week.show_chips()
	calendar.play_change(false)
	screen._week._quiet = false
	screen.run.debug_skip_to_shift(4)
	screen._week.shift_started()
	screen._week.show_chips()
	assert_bool(calendar.is_changing()).is_true()
	await _frames(3)
	assert_bool(screen._week.card.is_open()).is_true()
	assert_bool(calendar.is_changing()).is_true()
	assert_bool((calendar.part_rects()["flip"] as Rect2).has_area()).is_false()
	screen._week.card.clear()
	var start: int = Time.get_ticks_msec()
	while calendar.is_changing() and Time.get_ticks_msec() - start < 3000:
		await _frames(1)
	assert_bool(calendar.is_changing()).is_false()


## The bonus pill stands over the pad, outside its rect: hovering it hovers the calendar (no
## native tooltip any more: today's slip reads the pill's whole line, which the "+1" short form
## keeps there), leaving it unhovers, and a tap on it drops today's slip as the pad's does.
func test_the_bonus_pill_hovers_and_taps_as_the_pad() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(1280, 720)
	screen._week.skip()
	await _frames(3)
	await _show_day(screen, WEEK_TWO + 1, ["spot_check"])
	var calendar: DayCalendar = screen._stage.day_calendar
	calendar.show_bonus(InspectionTag.Bonus.PROMISED)
	await _frames(2)
	var pill: Control = calendar.tags.pill()
	assert_bool(pill.is_visible_in_tree()).is_true()
	assert_str(pill.tooltip_text).is_empty()
	assert_str(calendar.tooltip_text).is_empty()
	assert_str(_slip_text(screen)).contains(DayCalendar.PILL_TIP)
	var seen: Array[String] = []
	calendar.hovered.connect(func() -> void: seen.append("in"))
	calendar.unhovered.connect(func() -> void: seen.append("out"))
	calendar.pressed.connect(func() -> void: seen.append("tap"))
	var to_window: Transform2D = get_tree().root.get_final_transform()
	runner.simulate_mouse_move(to_window * pill.get_global_rect().get_center())
	await _frames(3)
	assert_array(seen).is_equal(["in"])
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await _frames(3)
	assert_array(seen).is_equal(["in", "tap"])
	runner.simulate_mouse_move(to_window * screen._stage.belt.get_global_rect().get_center())
	await _frames(3)
	assert_array(seen).is_equal(["in", "tap", "out"])


func _screen(window: Vector2) -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	screen.size = window
	screen._week.skip()
	await _frames(3)
	return screen


## Shift `shift_index` (0-based) under the day events `ids` (data/inspections), in planning, its
## page shown at once.
func _show_day(screen: ShiftScreen, shift_index: int, ids: Array) -> void:
	var run: RunState = screen.run
	run.debug_skip_to_shift(shift_index)
	var events: Array[InspectionDefinition] = []
	for id: String in ids:
		events.append(load(INSPECTIONS + id + ".tres") as InspectionDefinition)
	run.inspections = events
	screen._on_shift_started()
	screen._week.drop()
	screen._machine.notice.stop()
	screen._stage.day_calendar.play_change(false)
	await _frames(3)


## The calendar's pad and the top bar's LOYALTY, Cart and menu, rounded to the pixel.
static func _rects(screen: ShiftScreen) -> Array[Rect2]:
	var bar: TopBar = screen._stage.top_bar
	var pad: Rect2 = screen._stage.day_calendar.get_global_rect()
	var rects: Array[Rect2] = [Rect2(pad.position.round(), pad.size.round())]
	for control: Control in [bar.loyalty_card, bar.deck_button, bar.menu_button]:
		var rect: Rect2 = control.get_global_rect()
		rects.append(Rect2(rect.position.round(), rect.size.round()))
	return rects


## The pad and its tags inside the stage and the window; the pad on the register's top, its right
## edge at DESK_CALENDAR_RECT's, right of the bell, inside the column's width; its number, DAY
## and sign inside it and apart; LOYALTY at TopBar.LOYALTY_X; never shortened.
func _assert_fits(screen: ShiftScreen, message: String) -> void:
	var bar: TopBar = screen._stage.top_bar
	var stage: Rect2 = screen._stage.get_global_rect()
	var to_stage: Transform2D = screen._stage.get_global_transform()
	var window: Rect2 = Rect2(Vector2.ZERO, screen.size)
	var calendar: DayCalendar = screen._stage.day_calendar
	var parts: Dictionary = calendar.part_rects()
	var pad: Rect2 = parts["pad"]
	var shown: Array[Rect2] = [pad]
	var tags: Rect2 = parts["tags"]
	if tags.has_area():
		shown.append(tags)
	var column: Rect2 = to_stage * ShiftStage.TOWER_RECT
	var desk: Rect2 = to_stage * ShiftStage.DESK_CALENDAR_RECT
	var bell: Rect2 = screen._stage.bell.get_global_rect()
	var loyalty: Rect2 = bar.loyalty_card.get_global_rect()
	var expected_x: float = (to_stage * Vector2(TopBar.LOYALTY_X, 0.0)).x
	assert_float(loyalty.position.x).override_failure_message(message).is_equal_approx(
		expected_x, 0.5
	)
	assert_float(pad.end.y).override_failure_message(message).is_equal_approx(desk.end.y, 0.01)
	assert_float(pad.end.x).override_failure_message(message).is_equal_approx(desk.end.x, 0.01)
	assert_float(pad.position.x).override_failure_message(message).is_greater_equal(bell.end.x)
	for rect: Rect2 in shown:
		assert_bool(stage.encloses(rect)).override_failure_message(message).is_true()
		assert_bool(window.encloses(rect)).override_failure_message(message).is_true()
		assert_float(rect.position.x).override_failure_message(message).is_greater_equal(
			column.position.x
		)
		assert_float(rect.end.x).override_failure_message(message).is_less_equal(column.end.x)
	var word: Rect2 = parts["payday"] if (parts["payday"] as Rect2).has_area() else parts["day"]
	var inside: Array[Rect2] = [parts["number"], word]
	for sign_rect: Rect2 in parts["signs"]:
		inside.append(sign_rect)
	for index: int in range(inside.size()):
		assert_bool(pad.encloses(inside[index])).override_failure_message(message).is_true()
		for other: int in range(index + 1, inside.size()):
			var apart: bool = not inside[index].intersects(inside[other])
			assert_bool(apart).override_failure_message(message).is_true()
	assert_bool(calendar.is_shortened()).override_failure_message(message).is_false()


## A payday's page carries PAYDAY on its mustard band, inside the pad and over the number; any
## other day's page has DAY and no band.
func _assert_payday_page(parts: Dictionary, payday: bool, message: String) -> void:
	var word: Rect2 = parts["payday"]
	var band: Rect2 = parts["payday_band"]
	var day: Rect2 = parts["day"]
	assert_bool(word.has_area()).override_failure_message(message).is_equal(payday)
	assert_bool(band.has_area()).override_failure_message(message).is_equal(payday)
	assert_bool(day.has_area()).override_failure_message(message).is_equal(not payday)
	if not payday:
		return
	var pad: Rect2 = parts["pad"]
	var number: Rect2 = parts["number"]
	assert_bool(pad.encloses(band)).override_failure_message(message).is_true()
	(
		assert_bool(band.grow(-DayCalendarArt.CELL).encloses(word))
		. override_failure_message(message)
		. is_true()
	)
	assert_float(band.end.y).override_failure_message(message).is_less_equal(number.position.y)
	assert_float(absf(band.get_center().x - word.get_center().x)).is_less_equal(DayCalendarArt.CELL)


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")


## Today's slip's words (play test 2026-11-09: the slip in place of the calendar's tooltip), opened
## as a tap on the calendar opens it, then closed.
static func _slip_text(screen: ShiftScreen) -> String:
	screen._week.toggle_slip()
	var text: String = screen._week.slip.slip_text()
	screen._week.slip.clear()
	return text
