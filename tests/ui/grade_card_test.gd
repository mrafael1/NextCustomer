extends GdUnitTestSuite
## The difficulty grades on screen (#182): the title's grade card (opened by START RUN once a run
## was won, never before; on the best open grade; its ladder, badge, rules, win line and plates
## inside its sheet and the 1280x720 window; a locked grade can't start; START asks the shift
## screen for the grade), the top bar's staff badge on a graded run (inside the bar, right of
## LOYALTY and left of Cart) and the final receipt's grade stamp and bonus coin line.

const TITLE := "res://ui/title_screen.tscn"
const SHIFT_SCREEN := "res://ui/shift_screen.tscn"
const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
## The play-test switch that opens every grade (off in these tests).
const ALL_OPEN := "next_customer/all_grades_open"

var _folder: String = ""
var _window: Vector2i
var _all_open: Variant = null


func before_test() -> void:
	_folder = "user://test_grades_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window = get_tree().root.size
	get_tree().root.size = Vector2i(1280, 720)
	GradeCard.take_request()
	_all_open = ProjectSettings.get_setting(ALL_OPEN, null)
	ProjectSettings.set_setting(ALL_OPEN, false)


func after_test() -> void:
	get_tree().root.size = _window
	ProjectSettings.set_setting(ALL_OPEN, _all_open)
	GradeCard.take_request()
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Before any win START RUN starts at once: no card (new players see nothing new).
func test_no_card_before_a_win() -> void:
	_save_profile(-1)
	var title: TitleScreen = await _title()
	assert_object(title.grade_card()).is_null()
	title.menu().plate(TitleMenu.Entry.PRIMARY).pressed.emit()
	assert_bool(title._starting).is_true()


## After a win at grade 2, START RUN opens the card on grade 3 (the best open one), laid out
## inside its sheet and the window at 1280x720: the rungs in one row on the rail, the badge, name,
## status chip, rules, win corner and plates inside the panel or the sheet, clear of each other;
## START (GRADE 3 under it) asks for grade 3 and starts the run.
func test_the_card_opens_on_the_best_open_grade() -> void:
	_save_profile(2)
	var title: TitleScreen = await _title()
	title.menu().plate(TitleMenu.Entry.PRIMARY).pressed.emit()
	var card: GradeCard = title.grade_card()
	assert_bool(title._starting).is_false()
	assert_bool(card.is_open()).is_true()
	assert_int(card.picked).is_equal(3)
	await get_tree().create_timer(TitlePopup.OPEN_TIME + 0.3).timeout
	var screen: Rect2 = title.get_viewport_rect()
	var sheet: Rect2 = card.sheet().get_global_rect()
	assert_bool(screen.encloses(sheet)).is_true()
	var parts: Array[Control] = [card.start_plate(), card.back_plate(), card.pointer()]
	for grade: int in range(6):
		parts.append(card.rung(grade))
		parts.append(card.rung(grade).ring())
	for part: Control in parts:
		var rect: Rect2 = part.get_global_rect()
		assert_bool(sheet.encloses(rect)).override_failure_message(str(part)).is_true()
	# The panel holds the badge, the name's chip, the win corner and every rule row.
	var panel: Rect2 = Rect2(sheet.position + GradeCard.PANEL.position, GradeCard.PANEL.size)
	var inside: Array[Control] = [card.badge(), card.status_chip(), card.win_row()]
	inside.append_array(card.rule_rows())
	for part: Control in inside:
		var rect: Rect2 = part.get_global_rect()
		assert_bool(panel.encloses(rect)).override_failure_message(str(part)).is_true()
	var chip: Rect2 = card.status_chip().get_global_rect()
	assert_bool(chip.intersects(card.win_row().get_global_rect())).is_false()
	# The six rungs stand in one row, apart, centred on the sheet (within an art px); the pointer
	# is under the picked one.
	var first: Rect2 = card.rung(0).get_global_rect()
	var last: Rect2 = card.rung(5).get_global_rect()
	var margins: float = (first.position.x - sheet.position.x) - (sheet.end.x - last.end.x)
	assert_float(absf(margins)).is_less_equal(ArtStyle.ART_SCALE)
	for grade: int in range(1, 6):
		var left: Rect2 = card.rung(grade - 1).get_global_rect()
		var right: Rect2 = card.rung(grade).get_global_rect()
		assert_float(right.position.y).is_equal(left.position.y)
		assert_bool(left.intersects(right)).is_false()
	var picked: Rect2 = card.rung(3).get_global_rect()
	var pointer: Rect2 = card.pointer().get_global_rect()
	assert_float(pointer.get_center().x).is_equal_approx(picked.get_center().x, 2.0)
	assert_float(pointer.position.y).is_greater_equal(picked.end.y)
	# The rules stack grades 1 to 3, one row each, the picked grade's own last with the NEW tag
	# right of its text; the plates clear the panel and each other.
	var lines: Array[Label] = card.rule_lines()
	assert_int(lines.size()).is_equal(3)
	var texts: PackedStringArray = card.rule_texts()
	assert_str(texts[0]).is_equal("-1 redraw per shift")
	assert_str(texts[2]).is_equal("Expiry dates: coupons and some new items last 2 weeks")
	# A rule's "-1" (the user's play test of 2026-11-24) is its own tomato label, left of the rest
	# in the normal ink, both centred on the row.
	var lead: Label = card.rule_lead(0)
	assert_object(lead).is_not_null()
	assert_str(lead.text).is_equal("-1")
	assert_str(lines[0].text).is_equal("redraw per shift")
	assert_that(lead.get_theme_color("font_color")).is_equal(Palette.TOMATO)
	assert_that(lines[0].get_theme_color("font_color")).is_equal(Palette.INK)
	assert_float(lead.get_global_rect().end.x).is_less_equal(lines[0].get_global_rect().position.x)
	assert_float(lead.get_global_rect().get_center().y).is_equal_approx(
		lines[0].get_global_rect().get_center().y, 1.0
	)
	assert_object(card.rule_lead(1)).is_null()
	var rows: Array[Control] = card.rule_rows()
	for index: int in range(1, rows.size()):
		var above: Rect2 = rows[index - 1].get_global_rect()
		assert_float(rows[index].get_global_rect().position.y).is_greater_equal(above.end.y)
	var tag: ToyNewTag = card.new_tag()
	assert_object(tag).is_not_null()
	assert_object(tag.get_parent()).is_same(rows[2])
	assert_float(tag.get_global_rect().position.x).is_greater(lines[2].get_global_rect().end.x)
	var start: Rect2 = card.start_plate().get_global_rect()
	assert_float(start.position.y).is_greater_equal(panel.end.y)
	assert_bool(start.intersects(card.back_plate().get_global_rect())).is_false()
	assert_str(card.status_text()).is_equal("NOT BEATEN YET")
	assert_str(card.win_text()).contains("+3 coins")
	assert_str(card.start_plate().sub_line).is_equal("GRADE 3")
	assert_str(card.badge().number_label().text).is_equal("3")
	card.start_plate().pressed.emit()
	assert_bool(title._starting).is_true()
	assert_int(GradeCard.take_request()).is_equal(3)


## Picking a grade lights its rung and every rung under it (their rules stack: gold rings), the
## picked one standing up; the rungs above it stay unlit. A pick down unlights the ones above.
func test_a_pick_lights_every_grade_under_it() -> void:
	_save_profile(4)
	var title: TitleScreen = await _title()
	title.menu().plate(TitleMenu.Entry.PRIMARY).pressed.emit()
	var card: GradeCard = title.grade_card()
	card.pick(4)
	await _frames(2)
	for grade: int in range(6):
		var rung: GradeRung = card.rung(grade)
		var lit: bool = grade <= 4
		assert_bool(rung.is_lit()).override_failure_message(str(grade)).is_equal(lit)
		assert_bool(rung.ring().visible).override_failure_message(str(grade)).is_equal(lit)
		assert_bool(rung.is_picked()).is_equal(grade == 4)
	assert_float(card.rung(4).face().position.y).is_less(card.rung(3).face().position.y)
	assert_int(card.rule_lines().size()).is_equal(4)
	# Grade 5's rule reads as a promo, its cuts' range the row's tomato lead (the play tests of
	# 2026-11-24: 3/4 became a red -25%, then a random cut each shift).
	card.pick(5)
	assert_str(card.rule_lead(4).text).is_equal("-15 to -30%")
	assert_that(card.rule_lead(4).get_theme_color("font_color")).is_equal(Palette.TOMATO)
	assert_str(card.rule_lines()[4].text).is_equal("promo on one family each shift from week 2")
	card.pick(2)
	assert_bool(card.rung(2).is_lit()).is_true()
	assert_bool(card.rung(3).is_lit()).is_false()
	assert_bool(card.rung(4).ring().visible).is_false()
	assert_int(card.rule_lines().size()).is_equal(2)


## Every number and status sits centred in its box (the user's 2026-11-23 polish), each digit 0
## to 5 (the chunky digits differ in width): a rung's number with its shadow on the plate, clear
## of the tick or padlock on its corner; a rule's number in its chip; the status chip's words,
## digits and icon in every variant (THE GAME AS IT IS, BEATEN, NOT BEATEN YET, LOCKED). Each
## within one art px of its box's centre.
func test_numbers_and_status_sit_centred() -> void:
	_save_profile(2)
	var title: TitleScreen = await _title()
	title.menu().plate(TitleMenu.Entry.PRIMARY).pressed.emit()
	var card: GradeCard = title.grade_card()
	var art: float = ArtStyle.ART_SCALE
	for grade: int in range(6):
		var rung: GradeRung = card.rung(grade)
		var drawn: Rect2 = rung.number_rect()
		var off: Vector2 = drawn.get_center() - GradeRung.SIZE / 2.0
		assert_bool(_within(off, art)).override_failure_message(str(grade)).is_true()
		assert_bool(rung.mark() != null).is_equal(grade <= 2 or grade >= 4)
		if rung.mark() != null:
			var mark: Rect2 = Rect2(rung.mark().position, rung.mark().size)
			assert_bool(mark.intersects(drawn)).override_failure_message(str(grade)).is_false()
	card.pick(5)
	var rows: Array[Control] = card.rule_rows()
	assert_int(rows.size()).is_equal(5)
	# The five rules fill the panel's lower part without leaving it (the longest row with its NEW
	# tag inside the panel's right edge).
	var panel: Rect2 = Rect2(
		card.sheet().get_global_rect().position + GradeCard.PANEL.position, GradeCard.PANEL.size
	)
	for row: Control in rows:
		(
			assert_bool(panel.encloses(row.get_global_rect()))
			. override_failure_message(str(row))
			. is_true()
		)
	for row: Control in rows:
		var chip: Control = row.get_child(0) as Control
		var number: PixelWords = chip.get_child(0) as PixelWords
		var ink: Rect2 = Rect2(number.position, number.size + Vector2.ONE * number.cell)
		var off: Vector2 = ink.get_center() - chip.size / 2.0
		assert_bool(_within(off, art)).override_failure_message(number.text).is_true()
	var statuses: Dictionary[int, String] = {
		0: "THE GAME AS IT IS", 1: "BEATEN", 3: "NOT BEATEN YET", 5: "WIN GRADE 4 FIRST"
	}
	for grade: int in statuses:
		card.pick(grade)
		assert_str(card.status_text()).contains(statuses[grade])
		var line: PixelLine = card._chip_line
		var ink: Rect2 = Rect2(line.position + line.ink_rect().position, line.ink_rect().size)
		var chip: Vector2 = card.status_chip().size
		var off: Vector2 = ink.get_center() - chip / 2.0
		assert_bool(_within(off, art)).override_failure_message(str(grade)).is_true()
		assert_bool(ink.size.y > ArtStyle.PIXEL_CAP_HEIGHT * art - 1.0).is_true()


## The staff badge's digit, at the top bar's 2x and the grade card's 3x, for every grade: its
## drawn ink inside the paper window, on the badge's art grid, centred within one art px, and the
## label standing where that ink is drawn.
func test_the_badge_digit_sits_centred() -> void:
	for art_scale: int in [2, 3]:
		var badge: GradeBadge = auto_free(GradeBadge.new(art_scale))
		var window: Rect2 = Rect2(
			GradeBadge.WINDOW.position * art_scale, GradeBadge.WINDOW.size * art_scale
		)
		var ascent: float = ArtStyle.pixel_number_font().get_ascent(ArtStyle.PIXEL_NUMBER_SIZE)
		for grade: int in range(6):
			badge.grade = grade
			var at: String = "%d at %dx" % [grade, art_scale]
			var ink: Rect2 = badge.digit_ink_rect()
			var glyph: Rect2i = PixelLine.glyph_ink(str(grade))
			assert_vector(ink.size).override_failure_message(at).is_equal(
				Vector2(glyph.size) * art_scale
			)
			var label: Label = badge.number_label()
			var drawn: Vector2 = (
				label.position + Vector2(glyph.position.x, ascent + glyph.position.y) * art_scale
			)
			assert_vector(drawn).override_failure_message(at).is_equal(ink.position)
			assert_bool(window.encloses(ink)).override_failure_message(at).is_true()
			assert_float(fmod(ink.position.x, art_scale)).override_failure_message(at).is_zero()
			assert_float(fmod(ink.position.y, art_scale)).override_failure_message(at).is_zero()
			var off: Vector2 = ink.get_center() - window.get_center()
			assert_bool(_within(off, art_scale)).override_failure_message(at).is_true()


## A locked grade shows its rules but can't start; Left and Right walk the ladder; BACK closes
## the card and starts nothing. A grade whose first win unlocks a pin names it.
func test_a_locked_grade_cannot_start() -> void:
	_save_profile(0)
	var title: TitleScreen = await _title()
	title.menu().plate(TitleMenu.Entry.PRIMARY).pressed.emit()
	var card: GradeCard = title.grade_card()
	assert_int(card.picked).is_equal(1)
	title._unhandled_key_input(_key(KEY_RIGHT))
	assert_int(card.picked).is_equal(2)
	assert_bool(card.start_plate().disabled).is_true()
	assert_str(card.win_text()).contains("Express lane")
	assert_str(card.status_text()).contains("WIN GRADE 1 FIRST")
	assert_str(card.start_plate().sub_line).is_equal("LOCKED")
	card.start_plate().pressed.emit()
	assert_bool(card.is_open()).is_true()
	title._unhandled_key_input(_key(KEY_LEFT))
	title._unhandled_key_input(_key(KEY_LEFT))
	assert_int(card.picked).is_equal(0)
	assert_bool(card.start_plate().disabled).is_false()
	card.back_plate().pressed.emit()
	assert_bool(card.is_open()).is_false()
	assert_bool(title._starting).is_false()


## A graded run shows its staff badge on the top bar, inside the bar's row and the window, right
## of LOYALTY and left of Cart; a grade 0 run hides it.
func test_the_top_bar_shows_the_grade() -> void:
	_save_profile(4)
	GradeCard.request(3)
	var runner: GdUnitSceneRunner = scene_runner(SHIFT_SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(4)
	assert_int(screen.run.grade).is_equal(3)
	assert_int(screen.run.balance.base_redraws).is_equal(1)
	var bar: TopBar = screen._top_bar as TopBar
	var badge: GradeBadge = bar.grade_badge
	assert_bool(badge.is_visible_in_tree()).is_true()
	assert_str(badge.number_label().text).is_equal("3")
	var rect: Rect2 = badge.get_global_rect()
	assert_bool(screen.get_viewport_rect().encloses(rect)).is_true()
	assert_float(rect.position.x).is_greater(bar.loyalty_card.get_global_rect().end.x)
	assert_float(rect.end.x).is_less_equal(bar.deck_button.get_global_rect().position.x)
	assert_float(rect.position.y).is_greater_equal(0.0)
	assert_float(rect.end.y).is_less_equal(TopBar.POSITION.y + TopBar.ROW_HEIGHT + 2.0)
	assert_str(TipTarget.tip_of(badge)).contains("-1 redraw per shift")
	assert_bool(bar.picky_sign.visible).is_false()  # Grade 3: no Picky regular.


## A grade 5 run's twists on the shift screen at 1280x720 (v1.49): a shrunk belt item wears its
## "-1€" sticker and a dated basket item its BEST BEFORE tag with the shifts left, each inside the
## window, the basket's clear above its basket's rim (not hidden by the basket's front); the
## Picky regular's day (none in week 1) puts the family's glyph on the calendar's page and hangs
## its sign under the top bar's grade badge (inside the window, clear of LOYALTY, Cart and the
## menu, its tip naming the family); the week-end news shows as the shift's notice.
func test_the_twists_mark_the_shift_screen() -> void:
	_save_profile(4)
	GradeCard.request(5)
	var runner: GdUnitSceneRunner = scene_runner(SHIFT_SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(4)
	var run: RunState = screen.run
	assert_int(run.grade).is_equal(5)
	assert_object(GradeRules.picky(run.balance)).is_not_null()
	var hand: Array[CardInstance] = run.hand()
	var shrunk: CardInstance = null
	var dated: CardInstance = null
	for card: CardInstance in hand:
		if not card.definition.is_product() or card.definition.base <= 1:
			continue
		if shrunk == null:
			shrunk = card
		elif dated == null and card.definition.product_card() != shrunk.definition.product_card():
			dated = card
	assert_object(dated).is_not_null()
	run.place(shrunk, 0)
	run.twists.shrinks[shrunk.definition.product_card().id] = 1
	run.twists.expiry[dated.instance_id] = GradeRules.playing_shift(run) + 2
	run.twists.clear_events()
	screen._refresh()
	await _frames(2)
	var window: Rect2 = screen.get_viewport_rect()
	var belt_tags: GradeTags = screen._row_views[0].get_node(GradeTags.NODE_NAME) as GradeTags
	assert_object(belt_tags.shrink_face()).is_not_null()
	assert_object(belt_tags.date_face()).is_null()
	assert_bool(window.encloses(belt_tags.shrink_face().get_global_rect())).is_true()
	var basket_tags: GradeTags = null
	for item: Control in screen._hand_box.cards():
		var view: CardView = item as CardView
		if view != null and view.card == dated:
			basket_tags = view.get_node_or_null(NodePath(GradeTags.NODE_NAME)) as GradeTags
	assert_object(basket_tags).is_not_null()
	assert_int(basket_tags.shifts_left).is_equal(3)
	var date: Rect2 = basket_tags.date_face().get_global_rect()
	assert_bool(window.encloses(date)).is_true()
	assert_float(date.end.y).is_less_equal(HandBaskets.RIM_BACK_Y)
	# Week 1 has no Picky regular: no event, no sign.
	var bar: TopBar = screen._top_bar as TopBar
	assert_object(GradeRules.picky_event(run)).is_null()
	assert_bool(bar.picky_sign.visible).is_false()
	# Week 2's first shift: its family's glyph on the calendar's page and on the sign.
	run.shift_index = WeekSchedule.length(run.balance)
	run.twists.picky[run.shift_index + 1] = "Dairy"
	run.twists.clear_events()
	screen._refresh()
	await _frames(2)
	var event: InspectionDefinition = GradeRules.picky_event(run)
	assert_object(event).is_not_null()
	assert_bool(WeekFlow.day_events(run).has(event)).is_true()
	assert_object(DayCalendar.twist_glyph(event)).is_not_null()
	var hung_sign: PickySign = bar.picky_sign
	assert_bool(hung_sign.is_visible_in_tree()).is_true()
	assert_str(hung_sign.family).is_equal("Dairy")
	assert_object(hung_sign.glyph_texture()).is_not_null()
	var hung: Rect2 = hung_sign.get_global_rect()
	var badge_rect: Rect2 = bar.grade_badge.get_global_rect()
	assert_bool(window.encloses(hung)).is_true()
	var badge_foot: float = badge_rect.position.y + bar.grade_badge.custom_minimum_size.y
	assert_float(hung.position.y).is_greater_equal(badge_foot)
	assert_float(hung.get_center().x).is_equal_approx(badge_rect.get_center().x, 2.0)
	for neighbour: Control in [bar.loyalty_card, bar.deck_button, bar.menu_button]:
		assert_bool(hung.intersects(neighbour.get_global_rect())).is_false()
	assert_str(TipTarget.tip_of(hung_sign)).contains("Dairy price reduced by 25% today")
	assert_str(event.display_name).is_equal("Promo day")  # The tip's title.
	# A promo sign (the user's play test of 2026-11-24): the glyph at 4x on its face and the day's
	# cut on its band, both on the card, the cut fitting its band.
	assert_float(hung_sign.board_rect().size.x).is_greater_equal(PickySign.GLYPH_ART.x * 4.0)
	assert_float(hung.end.x).is_less_equal(bar.deck_button.get_global_rect().position.x)
	assert_str(hung_sign.cut_label().text).is_equal("-25%")
	assert_bool(hung_sign.board_rect().encloses(hung_sign.glyph_rect())).is_true()
	var band: Label = hung_sign.cut_label()
	assert_float(band.get_minimum_size().x).is_less_equal(band.size.x)
	assert_bool(hung.encloses(band.get_global_rect())).is_true()
	assert_bool(band.get_global_rect().intersects(hung_sign.glyph_rect())).is_false()
	# Another day's cut shows on the sign and in its tip.
	run.twists.promo_cuts[run.shift_index + 1] = 15
	screen._refresh()
	await _frames(1)
	assert_str(hung_sign.cut_label().text).is_equal("-15%")
	assert_str(TipTarget.tip_of(hung_sign)).contains("Dairy price reduced by 15% today")
	# The week-end news as the shift's notice.
	run.twists.news = PackedStringArray(["Shrinkflation: Bread -1€"])
	run.twists.news_shift = run.shift_index + 1
	screen._notice_label.clear_notice()
	MachineFlow.show_shift_notice(screen)
	assert_bool(screen._notice_label.is_showing()).is_true()
	assert_str(screen._notice_label.text).contains("Shrinkflation: Bread -1€")


## The top bar badge's tip (v1.49 play test: one paragraph was hard to read) at 1280x720: the
## grade's name as its title, its number as the tag, then one bulleted line per stacked rule, in
## ladder order, each under the one before, its bullet left of it, all inside the window.
func test_the_grade_tip_lists_its_rules() -> void:
	_save_profile(4)
	GradeCard.request(5)
	var runner: GdUnitSceneRunner = scene_runner(SHIFT_SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(4)
	var bar: TopBar = screen._top_bar as TopBar
	var cover: TipTarget = bar.grade_badge.get_node(NodePath(TipTarget.COVER_NAME)) as TipTarget
	assert_object(cover).is_not_null()
	var tips: GlyphTips = screen._glyph_tips
	tips.point_at(cover.get_global_rect().get_center())
	tips.show_tip(cover)
	if tips._pop != null:
		tips._pop.kill()
	var card: TipCard = tips.tip()
	card.scale = Vector2.ONE
	await _frames(2)
	assert_str(card.title_text().to_upper()).is_equal("MANAGER")
	assert_object(card.body()).is_null()
	var expected: PackedStringArray = GradeApply.rule_lines(screen.run.balance, 5)
	var lines: Array[TipText] = card.list_lines()
	assert_int(lines.size()).is_equal(5)
	var window: Rect2 = screen.get_viewport_rect()
	assert_bool(window.encloses(card.get_global_rect())).is_true()
	for index: int in range(lines.size()):
		var line: Rect2 = lines[index].get_global_rect()
		var bullet: Rect2 = card.bullets()[index].get_global_rect()
		assert_str(lines[index].plain_text()).is_equal(expected[index])
		assert_bool(window.encloses(line)).is_true()
		assert_float(bullet.end.x).is_less(line.position.x)
		assert_float(bullet.position.y).is_greater_equal(line.position.y)
		assert_float(bullet.end.y).is_less_equal(line.position.y + TipText.pitch_for(14))
		if index > 0:
			var above: Rect2 = lines[index - 1].get_global_rect()
			assert_float(line.position.y).is_greater_equal(above.end.y)


## A Cart card stands for its copies (v1.49 play test: a dated copy behind an undated one showed
## no date): at 1280x720 its BEST BEFORE tag shows the soonest date with a "1/2" chip under it
## (the Cart's two rows, v1.49 grade round 3), both on the card and in the window, and its tip
## lists each copy's date; the belt and basket marks explain themselves in the game's hover tip
## and take no clicks.
func test_a_stacked_cart_card_shows_its_dates() -> void:
	_save_profile(4)
	GradeCard.request(3)
	var runner: GdUnitSceneRunner = scene_runner(SHIFT_SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(4)
	var run: RunState = screen.run
	var product: CardDefinition = null
	for card: CardInstance in run.deck.cards:
		if card.definition.is_product():
			product = card.definition
			break
	var copies: Array[CardInstance] = []
	for card: CardInstance in run.deck.cards:
		if card.definition == product:
			copies.append(card)
	if copies.size() < 2:
		copies.append(run.deck.add_card(product))
	var dated: CardInstance = copies[copies.size() - 1]
	run.twists.expiry[dated.instance_id] = GradeRules.playing_shift(run) + 2
	screen._week.skip()
	screen._on_deck_button_pressed()
	await get_tree().create_timer(UiKit.POP_IN_SECONDS + 0.2).timeout
	var view: DeckView = screen._deck_view
	var cell: DeckCell = null
	for shown: DeckCell in view.cells():
		if shown.card == product:
			cell = shown
	assert_object(cell).is_not_null()
	var tags: GradeTags = cell.get_node_or_null(NodePath(GradeTags.NODE_NAME)) as GradeTags
	assert_object(tags).is_not_null()
	assert_int(tags.shifts_left).is_equal(3)
	assert_str(tags.copies_chip().text).is_equal("%d/%d" % [1, copies.size()])
	var window: Rect2 = screen.get_viewport_rect()
	var face: Rect2 = cell.get_global_rect()
	var date: Rect2 = tags.date_face().get_global_rect()
	var chip: Rect2 = tags.copies_chip().get_global_rect()
	for rect: Rect2 in [date, chip]:
		assert_bool(window.encloses(rect)).is_true()
		assert_bool(face.encloses(rect)).is_true()
	assert_float(chip.position.y).is_greater_equal(date.end.y)
	assert_float(chip.position.x).is_equal_approx(date.position.x, 0.5)
	view.hover(cell)
	var said: String = " ".join(view.tip().lines())
	assert_str(said).contains("1 of %d: leaves after 2 more shifts" % copies.size())
	assert_str(said).contains("%d of %d never expire" % [copies.size() - 1, copies.size()])
	# On the belt and in the baskets the marks carry tips and leave the item its clicks.
	view.visible = false
	var basket: CardView = null
	for item: Control in screen._hand_box.cards():
		if item is CardView and (item as CardView).card.definition.is_product():
			basket = item as CardView
			break
	run.twists.expiry[basket.card.instance_id] = GradeRules.playing_shift(run)
	screen._refresh()
	basket = _view_of(screen, basket.card)
	var marks: GradeTags = basket.get_node(NodePath(GradeTags.NODE_NAME)) as GradeTags
	assert_int(marks.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_str(TipTarget.tip_of(marks.date_face())).contains("last shift")
	var found: TipTarget = screen._glyph_tips.glyph_at(
		marks.date_face().get_global_rect().get_center()
	)
	assert_object(found).is_same(
		marks.date_face().get_node(NodePath(TipTarget.COVER_NAME)) as TipTarget
	)


## The shift-opening stamps (GradeMoves): a fresh shrink and date stamp on (big and clear at the
## start, at rest once played), an expired card's ghost drops under the Cart button and frees
## itself; they play once, and a resumed shift (no fresh changes) plays nothing.
func test_the_stamps_play_once() -> void:
	_save_profile(4)
	GradeCard.request(3)
	var runner: GdUnitSceneRunner = scene_runner(SHIFT_SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(4)
	var run: RunState = screen.run
	var basket: ItemView = null
	var copies: Dictionary[StringName, int] = {}
	for view: ItemView in screen.item_views():
		if view.card.definition.is_product():
			var id: StringName = view.card.definition.product_card().id
			copies[id] = copies.get(id, 0) + 1
	# One copy only, so the shrink stamps one view (a shrink is per product).
	for view: ItemView in screen.item_views():
		var definition: CardDefinition = view.card.definition
		if (
			definition.is_product()
			and definition.base > 1
			and copies[definition.product_card().id] == 1
		):
			basket = view
			break
	run.twists.shrinks[basket.card.definition.product_card().id] = 1
	run.twists.expiry[basket.card.instance_id] = GradeRules.playing_shift(run) + 2
	run.twists.clear_events()
	screen._refresh()
	basket = _view_of(screen, basket.card) as ItemView
	var tags: GradeTags = basket.get_node(NodePath(GradeTags.NODE_NAME)) as GradeTags
	var rest: Vector2 = tags.shrink_face().position
	run.twists.fresh_shrunk.append(basket.card.definition.product_card().id)
	run.twists.fresh_dated.append(basket.card.instance_id)
	run.twists.fresh_expired.append(basket.card.definition)
	var tweens: Array[Tween] = screen.play_grade_moves()
	assert_int(tweens.size()).is_equal(3)
	assert_bool(run.twists.has_fresh()).is_false()
	assert_float(tags.shrink_face().scale.x).is_equal_approx(GradeMoves.STAMP_FROM, 0.001)
	assert_float(tags.date_face().modulate.a).is_equal(0.0)
	var ghost: Control = screen._overlay.get_node(NodePath(GradeMoves.GHOST_NAME)) as Control
	assert_object(ghost).is_not_null()
	for tween: Tween in tweens:
		tween.custom_step(2.0)
	assert_vector(tags.shrink_face().scale).is_equal(Vector2.ONE)
	assert_vector(tags.shrink_face().position).is_equal(rest)
	assert_float(tags.date_face().modulate.a).is_equal(1.0)
	await _frames(1)
	assert_bool(is_instance_valid(ghost)).is_false()
	assert_array(screen.play_grade_moves()).is_empty()


## A promo day's red tags at 1280x720 (the user's play test of 2026-11-24: the cut hid under the
## stickers): each item of today's family on the belt and in the baskets wears a "-25%" tag, the
## cut fitting its face, inside the window, clear of the item's planning stickers, sparkles and
## grade marks (a shrink sticker and a BEST BEFORE tag on the same item), with no denial stamp
## over it; another family's item wears none. The tags stamp on once as the shift opens, not
## under reduced motion and not on a resumed shift.
func test_a_promo_tag_stays_clear() -> void:
	_save_profile(4)
	GradeCard.request(5)
	var runner: GdUnitSceneRunner = scene_runner(SHIFT_SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(4)
	var run: RunState = screen.run
	var promo: CardInstance = null
	var family: String = ""
	for card: CardInstance in run.hand():
		if card.definition.is_product() and card.definition.base > 1:
			for printed: String in card.definition.tags:
				if printed != "Food" and FamilyPalette.shared().style(printed) != null:
					family = printed
			if not family.is_empty():
				promo = card
				break
	assert_object(promo).is_not_null()
	run.shift_index = WeekSchedule.length(run.balance)
	run.twists.picky[run.shift_index + 1] = family
	# Its neighbours on the belt give it stickers; it is shrunk and dated too.
	var placed: int = 0
	for card: CardInstance in run.hand():
		if card != promo and placed < 2 and run.place(card, placed):
			placed += 1
	run.place(promo, 1)
	run.twists.shrinks[promo.definition.product_card().id] = 1
	run.twists.expiry[promo.instance_id] = GradeRules.playing_shift(run) + 2
	run.twists.clear_events()
	screen._refresh()
	await _frames(3)
	var window: Rect2 = screen.get_viewport_rect()
	var slot: int = run.row.find(promo)
	var view: CardView = screen._row_views[slot]
	var tag: PromoTag = PromoTag.of(view)
	assert_object(tag).is_not_null()
	assert_str(tag.text).is_equal("-25%")
	var rect: Rect2 = tag.get_global_rect()
	assert_bool(window.encloses(rect)).is_true()
	# Stuck on the item (the user's play test of 2026-11-24: it flew above it): on its art's
	# visible box, riding its sprite.
	var belt_item: ItemView = view as ItemView
	assert_object(tag.get_parent()).is_same(belt_item.sprite())
	assert_bool(rect.intersects(_art_rect(belt_item))).is_true()
	assert_bool(rect.intersects(belt_item.sticker().get_global_rect())).is_false()
	assert_float(tag.label().get_minimum_size().x).is_less_equal(tag.label().size.x)
	var tags: GradeTags = view.get_node(NodePath(GradeTags.NODE_NAME)) as GradeTags
	for face: Control in [tags.shrink_face(), tags.date_face()]:
		assert_object(face).is_not_null()
		assert_bool(rect.intersects(face.get_global_rect())).is_false()
	var layer: PlanningLayer = screen._effects._layer
	assert_object(layer.stamp(slot)).is_null()  # A promo is no denial: no stamp over the art.
	var parts: Array[Control] = []
	for near: int in [slot - 1, slot, slot + 1]:  # A neighbour's WASTED label reaches over too.
		if near >= 0 and near < run.row.size():
			parts.append_array(layer.stack(near))
	parts.append_array(layer.sparkles(slot))
	for part: Control in parts:
		assert_bool(rect.intersects(part.get_global_rect())).is_false()
	# A boost lifts the item toward the stacks' floor: its tag still grips the art, under the floor
	# (a neighbour's WASTED label reached over a boosted item's tag).
	var rings: int = belt_item.boost_rings
	belt_item.boost_rings = 1
	var boosted: Rect2 = tag.get_global_rect()
	assert_bool(boosted.intersects(_art_rect(belt_item))).is_true()
	assert_float(boosted.position.y).is_greater_equal(PlanningLayer.STACK_BOTTOM_Y)
	belt_item.boost_rings = rings
	var preview: ScoreResult = run.preview()
	for other_slot: int in range(screen._row_views.size()):
		var other: CardView = screen._row_views[other_slot]
		var on_promo: bool = GradeRules.promo_slot(run, preview, other_slot, other.card)
		assert_bool(PromoTag.of(other) != null).is_equal(on_promo)
	var baskets: int = 0
	for item: Control in screen._hand_box.cards():
		var basket: CardView = item as CardView
		var basket_tag: PromoTag = PromoTag.of(basket) if basket != null else null
		if basket_tag == null:
			continue
		baskets += 1
		var at: Rect2 = basket_tag.get_global_rect()
		assert_bool(window.encloses(at)).is_true()
		assert_bool(at.intersects(_art_rect(basket as ItemView))).is_true()
		assert_float(at.end.y).is_less_equal(basket.get_global_rect().position.y + 80.0)
		var marks: GradeTags = basket.get_node_or_null(NodePath(GradeTags.NODE_NAME)) as GradeTags
		if marks != null:
			assert_bool(at.intersects(marks.get_global_rect())).is_false()
	# The shift opening stamps the tags on (scaled up, then at rest); reduced motion, and a
	# resumed shift (no fresh changes), show them at rest at once.
	run.twists.fresh_promo = true
	var tweens: Array[Tween] = screen.play_grade_moves()
	assert_int(tweens.size()).is_greater_equal(1 + baskets)
	assert_float(tag.scale.x).is_equal_approx(GradeMoves.STAMP_FROM, 0.001)
	for tween: Tween in tweens:
		tween.custom_step(2.0)
	assert_vector(tag.scale).is_equal(Vector2.ONE)
	assert_array(screen.play_grade_moves()).is_empty()
	run.twists.fresh_promo = true
	var still: Array[Tween] = GradeMoves.play(screen._overlay, run, screen.item_views(), null, true)
	assert_array(still).is_empty()
	assert_vector(tag.scale).is_equal(Vector2.ONE)
	# The count-up's scan lifts the sprite: the tag rides it.
	var rest: Vector2 = tag.global_position
	belt_item.body.position.y -= 20.0
	assert_float(tag.global_position.y).is_equal_approx(rest.y - 20.0, 0.01)
	belt_item.body.position.y += 20.0


## The Price gun's label puts an item in today's family: the score cuts it, so it wears the tag
## (the tag reads the score's tags, not the item's printed families); taking the label back takes
## the tag off.
func test_a_price_gun_label_gets_the_promo_tag() -> void:
	_save_profile(4)
	GradeCard.request(5)
	var runner: GdUnitSceneRunner = scene_runner(SHIFT_SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(4)
	var run: RunState = screen.run
	run.shift_index = WeekSchedule.length(run.balance)
	var today: int = run.shift_index + 1
	run.twists.picky[today] = "Household"
	run.twists.promo_cuts[today] = 20
	var labelled: CardInstance = null
	for card: CardInstance in run.hand():
		var product: bool = card.definition.is_product() and card.definition.base > 1
		if product and not card.definition.tags.has("Household") and labelled == null:
			labelled = card
	assert_object(labelled).is_not_null()
	run.place(labelled, 0)
	run.twists.clear_events()
	screen._refresh()
	await _frames(2)
	var view: CardView = _view_of(screen, labelled)
	assert_object(PromoTag.of(view)).is_null()
	var plain: int = run.preview().payouts[0]
	run.relabels[labelled.instance_id] = "Household"
	screen._refresh()
	await _frames(2)
	view = _view_of(screen, labelled)
	assert_int(run.preview().payouts[0]).is_less(plain)  # The score cuts it...
	var tag: PromoTag = PromoTag.of(view)
	assert_object(tag).is_not_null()  # ...so it wears the tag, at the day's cut.
	assert_str(tag.text).is_equal("-20%")
	run.relabels.erase(labelled.instance_id)
	screen._refresh()
	await _frames(2)
	assert_object(PromoTag.of(_view_of(screen, labelled))).is_null()


## The final receipt: a graded win prints GRADE n BEATEN under the headline and the grade's coins
## before the total; a grade 0 run prints neither.
func test_the_receipt_stamps_the_grade() -> void:
	var balance: BalanceDefinition = GradeApply.balance_for(load(BALANCE), 3)
	var run: RunState = RunState.new(5, load(STARTER), balance, RunStock.starting(balance))
	run.grade = 3
	run.start_shift()
	run.phase = RunState.Phase.WON
	var result: ScoreResult = ScoreResult.new()
	var lines: Array[FinalReceipt.Line] = FinalReceipt.lines(run, result, 10)
	assert_str(lines[1].text).is_equal("GRADE 3 BEATEN")
	assert_int(lines[1].tone).is_equal(FinalReceipt.Tone.GRADE)
	var texts: Array[String] = []
	for line: FinalReceipt.Line in lines:
		texts.append(line.text)
	assert_str(texts[texts.size() - 2]).starts_with("Grade 3 win")
	assert_str(texts[texts.size() - 2]).ends_with("+3")
	run.grade = 0
	var plain: Array[FinalReceipt.Line] = FinalReceipt.lines(run, result, 10)
	assert_int(plain[1].tone).is_equal(FinalReceipt.Tone.RULE)


## A saved profile whose best grade won is `best` (-1: none), past the guided run.
func _save_profile(best: int) -> void:
	var profile: ProfileState = ProfileState.new()
	profile.best_grade_won = best
	profile.run_count = 3
	if best >= 0:
		profile.stats[ProfileState.RUNS_WON] = best + 1
	TutorialFlags.finish_guide(profile)
	assert_bool(SaveService.new(_folder).save_profile(profile)).is_true()


## `item`'s art's visible box (its sprite's opaque pixels), global.
static func _art_rect(item: ItemView) -> Rect2:
	var sprite: TextureRect = item.sprite()
	var art: Rect2i = ContactShadow.opaque_rect(sprite.texture)
	var texel: Vector2 = sprite.size / Vector2(sprite.texture.get_size())
	var box: Rect2 = Rect2(Vector2(art.position) * texel, Vector2(art.size) * texel)
	return sprite.get_global_transform() * box


## The item showing `card` on `screen` now (the views are rebuilt on refresh), or null.
static func _view_of(screen: ShiftScreen, card: CardInstance) -> CardView:
	for view: ItemView in screen.item_views():
		if view.card == card:
			return view
	return null


func _title() -> TitleScreen:
	var runner: GdUnitSceneRunner = scene_runner(TITLE)
	var title: TitleScreen = runner.scene()
	title.changes_scene = false
	title.skip_intro()
	await _frames(4)
	return title


## Whether `off` is at most `limit` px each way (Vector2's <= compares x first, then y).
static func _within(off: Vector2, limit: float) -> bool:
	return absf(off.x) <= limit and absf(off.y) <= limit


func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().process_frame


static func _key(keycode: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	return key


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
