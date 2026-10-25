extends GdUnitTestSuite
## The family glyphs' tooltips (#105, mock-up readability v3, tipBox and tipHTML; GlyphTip and
## GlyphTips). place() opens a tip below a ticket (its top BELOW_GAP under the ticket's foot, its
## right end BELOW_RIGHT past the glyph's middle, its tail up) or above a glyph (centred on it,
## ABOVE_GAP over its top, its tail down), flips above at the screen's foot and stays SCREEN_MARGIN
## inside its sides; it is as wide as its text plus TEXT_ROOM, rounded up to even. Mounted, a tip
## shows after SHOW_DELAY_S for the glyph under the pointer, inside the screen: below a ticket's
## glyphs (its row's and its text's), above the popup's and the monitor's. On the real shift
## screen the pointer on a belt ticket's glyph keeps the item hovered (the glyph takes no pointer,
## so a press still reaches the item for its drag), a press hides the tip, and no tip shows while
## the shift is counted. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const CARDS := "res://data/cards"
const STAGE := Rect2(0, 0, 1280, 720)
## A glyph on a ticket (its row's first, (4, 5) on a ticket at (96, 195)).
const GLYPH := Rect2(100, 200, 18, 18)
const TICKET := Rect2(96, 195, 108, 64)

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_a_tip_opens_below_a_ticket_or_above_a_glyph() -> void:
	var tip_size: Vector2 = Vector2(60, GlyphTip.HEIGHT)
	# Below: x = 109 + 14 - 60, y = 259 + 12.
	var below: Rect2 = GlyphTip.place(GLYPH, TICKET, true, tip_size, STAGE)
	assert_that(below).is_equal(Rect2(63, 271, 60, 26))
	assert_bool(GlyphTip.is_below(below, GLYPH)).is_true()
	# Above: x = 109 - 30, y = 200 - 36.
	var above: Rect2 = GlyphTip.place(GLYPH, TICKET, false, tip_size, STAGE)
	assert_that(above).is_equal(Rect2(79, 164, 60, 26))
	assert_bool(GlyphTip.is_below(above, GLYPH)).is_false()
	# The tail points at the glyph's middle.
	assert_float(GlyphTip.tail_x(below, GLYPH)).is_equal(109.0 - 63.0 - 7.0)
	assert_float(GlyphTip.tail_x(above, GLYPH)).is_equal(109.0 - 79.0 - 7.0)


func test_a_tip_stays_on_the_screen() -> void:
	var tip_size: Vector2 = Vector2(80, GlyphTip.HEIGHT)
	# A ticket at the screen's foot: the tip opens above its glyph instead.
	var low_ticket: Rect2 = Rect2(400, 650, 108, 64)
	var low_glyph: Rect2 = Rect2(404, 655, 18, 18)
	var flipped: Rect2 = GlyphTip.place(low_glyph, low_ticket, true, tip_size, STAGE)
	assert_bool(GlyphTip.is_below(flipped, low_glyph)).is_false()
	assert_float(flipped.position.y).is_equal(655 - GlyphTip.ABOVE_GAP)
	# At the sides: SCREEN_MARGIN inside.
	var left: Rect2 = GlyphTip.place(Rect2(2, 300, 18, 18), TICKET, false, tip_size, STAGE)
	assert_float(left.position.x).is_equal(GlyphTip.SCREEN_MARGIN)
	var right: Rect2 = GlyphTip.place(Rect2(1270, 300, 18, 18), TICKET, false, tip_size, STAGE)
	assert_float(right.end.x).is_equal(STAGE.end.x - GlyphTip.SCREEN_MARGIN)
	for box: Rect2 in [flipped, left, right]:
		assert_bool(STAGE.encloses(box)).override_failure_message(str(box)).is_true()
	# The tail stays inside the box when the box is pushed off its glyph.
	var tail: float = GlyphTip.tail_x(left, Rect2(2, 300, 18, 18))
	assert_float(tail).is_equal(GlyphTip.TAIL_INSET)


func test_a_tip_is_as_wide_as_its_text() -> void:
	var font: Font = ArtStyle.bold_font(ArtStyle.TIP_TEXT_WEIGHT)
	for text: String in ["Dairy", "Breakfast", "Fruit & veg", "Household"]:
		var width: float = GlyphTip.width_for(text)
		var text_width: float = (
			font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ArtStyle.TIP_TEXT_SIZE).x
		)
		assert_float(fmod(width, 2.0)).override_failure_message(text).is_equal(0.0)
		assert_float(width).override_failure_message(text).is_between(
			text_width + GlyphTip.TEXT_ROOM, text_width + GlyphTip.TEXT_ROOM + 2.0
		)


## show_for: below, the tail flipped at TAIL_BELOW_Y and the pop's pivot at its top; above, the
## tail at TAIL_ABOVE_Y and the pivot at the foot; the text in paper, inside the box.
func test_a_shown_tip_points_its_tail_at_the_glyph() -> void:
	var tip: GlyphTip = auto_free(GlyphTip.new())
	add_child(tip)
	tip.show_for("Dairy", GLYPH, TICKET, true, STAGE)
	assert_bool(tip.below).is_true()
	assert_str(tip.tip_text()).is_equal("Dairy")
	assert_bool(tip.tail().flip_v).is_true()
	assert_float(tip.tail().position.y).is_equal(GlyphTip.TAIL_BELOW_Y)
	assert_float(tip.pivot_offset.y).is_equal(0.0)
	assert_object(tip.label().get_theme_color("font_color")).is_equal(Palette.PAPER)
	assert_int(tip.label().get_theme_font_size("font_size")).is_equal(ArtStyle.TIP_TEXT_SIZE)
	tip.show_for("Dairy", GLYPH, TICKET, false, STAGE)
	assert_bool(tip.below).is_false()
	assert_bool(tip.tail().flip_v).is_false()
	assert_float(tip.tail().position.y).is_equal(GlyphTip.TAIL_ABOVE_Y)
	assert_float(tip.pivot_offset.y).is_equal(GlyphTip.HEIGHT)
	var box: Rect2 = Rect2(Vector2.ZERO, tip.size)
	assert_bool(box.encloses(Rect2(tip.label().position, tip.label().size))).is_true()


## Mounted over a ticket and a popup (standing for the offers' popup, which stays while the
## pointer is on it): the ticket's glyphs (its row's and its text's) tip below the ticket after
## SHOW_DELAY_S, the popup's above their glyph; inside the screen; off the glyph, or `blocked`, no
## tip.
func test_mounted_tips_show_for_the_glyph_under_the_pointer() -> void:
	var holder: Control = auto_free(Control.new())
	holder.size = STAGE.size
	get_tree().root.add_child(holder)
	var scissors: PriceSticker = PriceSticker.new(_card("scissors"))
	scissors.position = Vector2(300, 400)
	holder.add_child(scissors)
	var popup: ScanPopup = ScanPopup.new()
	holder.add_child(popup)
	var milk: CardDefinition = _card("milk")
	popup.show_card(milk, milk.tags)
	popup.position = Vector2(700, 300)
	var tips: GlyphTips = GlyphTips.new()
	var blocked: Array[bool] = [false]
	tips.blocked = func() -> bool: return blocked[0]
	holder.add_child(tips)
	await _frames(2)
	var glyphs: Array[FamilyGlyph] = scissors.glyphs() + scissors.summary().glyphs()
	assert_int(glyphs.size()).is_greater_equal(2)
	var ticket: Rect2 = scissors.get_global_rect()
	for glyph: FamilyGlyph in glyphs:
		var shown: GlyphTip = await _tip_for(tips, glyph)
		var box: Rect2 = shown.get_global_rect()
		var message: String = "%s: %s" % [glyph.family, box]
		assert_str(shown.tip_text()).is_equal(glyph.tip_text)
		assert_bool(shown.below).override_failure_message(message).is_true()
		assert_float(box.position.y).override_failure_message(message).is_equal(
			ticket.end.y + GlyphTip.BELOW_GAP
		)
		assert_bool(STAGE.encloses(box)).override_failure_message(message).is_true()
		assert_bool(box.intersects(ticket)).override_failure_message(message).is_false()
	assert_int(popup.glyphs().size()).is_greater_equal(1)
	for glyph: FamilyGlyph in popup.glyphs():
		var shown: GlyphTip = await _tip_for(tips, glyph)
		var box: Rect2 = shown.get_global_rect()
		var message: String = "%s: %s" % [glyph.family, box]
		assert_bool(shown.below).override_failure_message(message).is_false()
		assert_float(box.end.y).override_failure_message(message).is_less_equal(
			glyph.get_global_rect().position.y
		)
		assert_bool(box.intersects(glyph.get_global_rect())).is_false()
		assert_bool(STAGE.encloses(box)).override_failure_message(message).is_true()
	# Off every glyph: none.
	tips.point_at(Vector2(5, 5))
	await _frames(2)
	assert_object(tips.shown_glyph()).is_null()
	# Blocked (a drag, the count-up): none, even resting on a glyph.
	blocked[0] = true
	tips.point_at(glyphs[0].get_global_rect().get_center())
	await _seconds(GlyphTips.SHOW_DELAY_S * 2.0)
	assert_object(tips.shown_glyph()).is_null()


## A ticket's colour (#105): resting the pointer on the ticket off its glyphs says what the colour
## means, below the ticket; on a glyph the glyph's tip wins. A ticket clipped by its parent (a
## scrolled shelf) shows nothing where it is cut off, its glyphs included.
func test_a_tickets_colour_tips_below_it_and_a_clipped_ticket_shows_none() -> void:
	var holder: Control = auto_free(Control.new())
	holder.size = STAGE.size
	get_tree().root.add_child(holder)
	var milk: PriceSticker = PriceSticker.new(_card("milk"))
	milk.position = Vector2(300, 400)
	holder.add_child(milk)
	var clip: Control = Control.new()
	clip.clip_contents = true
	clip.position = Vector2(600, 400)
	clip.size = Vector2(PriceSticker.SIZE.x, 30)
	holder.add_child(clip)
	var cut: PriceSticker = PriceSticker.new(_card("cereal"))
	# Scrolled up: only its lower half shows, its glyph row is cut off.
	cut.position = Vector2(0, -34)
	clip.add_child(cut)
	var tips: GlyphTips = GlyphTips.new()
	holder.add_child(tips)
	await _frames(2)
	var spot: PriceSticker.ColourSpot = _spot(milk)
	var shown: GlyphTip = await _tip_for(
		tips, spot, milk.get_global_rect().position + Vector2(4, 60)
	)
	assert_str(shown.tip_text()).is_equal("Breakfast colour · works with Breakfast")
	assert_bool(shown.below).is_true()
	var box: Rect2 = shown.get_global_rect()
	assert_float(box.position.y).is_equal(milk.get_global_rect().end.y + GlyphTip.BELOW_GAP)
	assert_bool(STAGE.encloses(box)).override_failure_message(str(box)).is_true()
	# On a glyph, the glyph's tip.
	var glyph: FamilyGlyph = milk.glyphs()[0]
	await _tip_for(tips, glyph, glyph.get_global_rect().get_center())
	# The clipped ticket: its cut-off glyph and colour show nothing, its shown part its colour.
	var hidden: FamilyGlyph = cut.glyphs()[0]
	assert_bool(clip.get_global_rect().intersects(hidden.get_global_rect())).is_false()
	tips.hide_tip()
	tips.point_at(hidden.get_global_rect().get_center())
	await _seconds(GlyphTips.SHOW_DELAY_S + 0.1)
	assert_object(tips.shown_glyph()).is_null()
	assert_bool(GlyphTips.is_clipped(hidden, hidden.get_global_rect().get_center())).is_true()
	await _tip_for(tips, _spot(cut), clip.get_global_rect().get_center())


## On the real shift screen: the pointer on a belt ticket's glyph keeps its item hovered (a press
## there reaches the item, which drags), the glyph's tip opens below the ticket inside the screen,
## a press hides it, and none shows while the shift is counted.
func test_a_belt_glyph_tips_and_keeps_its_item() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(3)
	var run: RunState = screen.run
	var milk: CardInstance = run.debug_add_to_hand(_card("milk"))
	assert_bool(run.place(milk, run.row.size())).is_true()
	screen._refresh()
	await _frames(3)
	var view: ItemView = screen._row_views[run.row.find(milk)] as ItemView
	var sticker: PriceSticker = view.sticker()
	var glyph: FamilyGlyph = sticker.glyphs()[0]
	assert_int(glyph.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	var at: Vector2 = glyph.get_global_rect().get_center()
	_move(at)
	await _seconds(GlyphTips.SHOW_DELAY_S + 0.1)
	var hovered: Control = screen.get_viewport().gui_get_hovered_control()
	assert_object(hovered).is_not_null()
	(
		assert_bool(hovered == view or view.is_ancestor_of(hovered))
		. override_failure_message(str(hovered))
		. is_true()
	)
	var tips: GlyphTips = screen._glyph_tips
	assert_object(tips.shown_glyph()).is_same(glyph)
	var tip: GlyphTip = tips.tip()
	var box: Rect2 = tip.get_global_rect()
	assert_bool(tip.below).is_true()
	assert_str(tip.tip_text()).is_equal(glyph.tip_text)
	assert_float(box.position.y).is_equal(sticker.get_global_rect().end.y + GlyphTip.BELOW_GAP)
	assert_bool(screen.get_global_rect().encloses(box)).override_failure_message(str(box)).is_true()
	# A press hides it (the item takes the press).
	var press: InputEventMouseButton = InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = at
	press.global_position = at
	tips._input(press)
	assert_object(tips.shown_glyph()).is_null()
	# While counting: none.
	screen._counting = true
	_move(at + Vector2(1, 0))
	await _seconds(GlyphTips.SHOW_DELAY_S * 2.0)
	assert_object(tips.shown_glyph()).is_null()
	screen._counting = false


## shown_changed says which tip shows, once per change (#105 piece 3: the mix highlight follows
## it): the glyph when its tip shows, null when it hides, nothing for a repeat.
func test_the_shown_tip_is_signalled_once_per_change() -> void:
	var holder: Control = auto_free(Control.new())
	holder.size = STAGE.size
	add_child(holder)
	var palette: FamilyPalette = FamilyPalette.shared()
	var breakfast: FamilyGlyph = FamilyGlyph.new(palette.style("Breakfast"))
	var dairy: FamilyGlyph = FamilyGlyph.new(palette.style("Dairy"))
	breakfast.position = Vector2(100, 200)
	dairy.position = Vector2(300, 200)
	holder.add_child(breakfast)
	holder.add_child(dairy)
	var tips: GlyphTips = GlyphTips.new()
	holder.add_child(tips)
	var seen: Array[TipTarget] = []
	tips.shown_changed.connect(func(target: TipTarget) -> void: seen.append(target))
	tips.show_tip(breakfast)
	tips.show_tip(breakfast)
	tips.show_tip(dairy)
	tips.hide_tip()
	tips.hide_tip()
	assert_array(seen).is_equal([breakfast, dairy, null])
	assert_str((seen[0] as FamilyGlyph).family).is_equal("Breakfast")


## Rests the pointer on `glyph` (at `at`, else its middle) for the wait, returning the shown tip.
func _tip_for(tips: GlyphTips, glyph: TipTarget, at: Vector2 = Vector2.INF) -> GlyphTip:
	tips.hide_tip()
	tips.point_at(Vector2(-50, -50))
	tips.point_at(glyph.get_global_rect().get_center() if at == Vector2.INF else at)
	await _seconds(GlyphTips.SHOW_DELAY_S + 0.1)
	assert_object(tips.shown_glyph()).override_failure_message(glyph.tip_text).is_same(glyph)
	return tips.tip()


## The pointer moves to `at` (the viewport's coordinates), as a real mouse motion.
func _move(at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	# In the viewport's own coordinates (no window stretch applied).
	get_tree().root.push_input(motion, true)


func _seconds(seconds: float) -> void:
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < seconds * 1000.0:
		await get_tree().process_frame


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _spot(sticker: PriceSticker) -> PriceSticker.ColourSpot:
	return sticker.get_node(PriceSticker.COLOUR_SPOT_NAME) as PriceSticker.ColourSpot


static func _card(card_id: String) -> CardDefinition:
	return load("%s/%s.tres" % [CARDS, card_id]) as CardDefinition


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
