extends GdUnitTestSuite
## The staff handbook (v1.06, mock-up keywords_guide.html, variant A). The binder fits the
## 1280x720 screen with its four tabs side by side, CLOSE, index and entry column apart and inside
## it; every entry opens (its example clip on the real score; a family's page and the coupon intro
## end at their rule, which fits its rect, its terms in their colours); the tabs and index rows
## pick entries; Esc and a right-click outside close it. On the shift screen the menu's Guide
## opens it and a right-click while a keyword's or a family's tooltip shows opens that entry (the
## deep link), except while a right-click belongs to something else. The real saves and logs are
## never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const SCREEN_RECT := Rect2(0, 0, 1280, 720)

var _folder: String = ""
var _window_size: Vector2i
var _runner: GdUnitSceneRunner


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(SCREEN_RECT.size)


func after_test() -> void:
	_runner = null
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The binder, its tabs, CLOSE, index rows and entry column: inside the screen, none overlapping,
## each tab's name inside its tab; the example clip inside the entry column.
func test_the_binder_fits_the_screen() -> void:
	var page: HandbookPage = await _page()
	page.open_at(&"morning")
	await _frames(3)
	var binder: Rect2 = page.binder_rect()
	assert_bool(SCREEN_RECT.encloses(binder.grow(HandbookPage.SHADOW))).is_true()
	var tops: Array[Rect2] = []
	for group_id: StringName in page._book.group_ids:
		var tab: HandbookButton = page.tab(group_id)
		var rect: Rect2 = tab.get_global_rect()
		assert_bool(SCREEN_RECT.encloses(rect)).override_failure_message(group_id).is_true()
		var text: Label = tab.get_node("Text") as Label
		assert_float(UiKit.pixel_text_size(text).x).override_failure_message(group_id).is_less(
			rect.size.x
		)
		tops.append(rect)
	assert_int(tops.size()).is_equal(4)
	# The tabs stand side by side, TAB_GAP apart, with no hole where a removed tab was.
	for index: int in range(1, tops.size()):
		assert_float(tops[index].position.x - tops[index - 1].end.x).is_equal_approx(
			HandbookPage.TAB_GAP, 0.5
		)
	tops.append(page.close_button().get_global_rect())
	_assert_apart(tops)
	assert_bool(SCREEN_RECT.encloses(page.close_button().get_global_rect())).is_true()
	var rows: Array[Rect2] = []
	for row: HandbookButton in page.index_rows():
		assert_bool(binder.encloses(row.get_global_rect())).is_true()
		rows.append(row.get_global_rect())
	assert_int(rows.size()).is_equal(5)
	_assert_apart(rows)
	var column: Rect2 = page.entry_scroll().get_global_rect()
	assert_bool(binder.encloses(column)).is_true()
	for row: Rect2 in rows:
		assert_bool(row.intersects(column)).is_false()
	var clip: Rect2 = page.entry_view().clip().get_global_rect()
	assert_float(clip.position.x).is_greater_equal(column.position.x)
	assert_float(clip.end.x).is_less_equal(column.end.x)
	# The clip's tickets and total sit inside it.
	for ticket: PriceSticker in page.entry_view().clip().tickets():
		assert_bool(clip.encloses(ticket.get_global_rect())).is_true()
	assert_bool(clip.encloses(page.entry_view().clip().total_label().get_global_rect())).is_true()


## Every example's window onto the counter (the guide polish, 2026-11-11) sits inside its clip,
## which sits inside the entry column, and shows the whole planning state: every ticket, sticker,
## stamp and hung slot mark inside the window, the LED (and a quota's receipt) inside the clip
## under it. Each index row's title starts after its mark (MORNING's wide chip included), and the
## sign, the rows and the hint card keep inside the contents page, apart.
func test_every_clip_and_index_row_fits() -> void:
	var page: HandbookPage = await _page()
	page.open_at()
	for entry: HandbookEntry in page._book.entries:
		page.show_entry(entry.id)
		await _frames(3)
		var view: HandbookEntryView = page.entry_view()
		var column: Rect2 = page.entry_scroll().get_global_rect()
		_assert_index_fits(page, entry)
		var clip: HandbookClip = view.clip()
		if clip == null:
			continue
		var what: String = String(entry.id)
		var whole: Rect2 = clip.get_global_rect()
		assert_float(whole.size.x).override_failure_message(what).is_less_equal(column.size.x)
		var window: Rect2 = clip.window_rect()
		assert_bool(whole.encloses(window)).override_failure_message(what).is_true()
		assert_bool(whole.encloses(clip.led().get_global_rect())).is_true()
		assert_bool(window.intersects(clip.led().get_global_rect())).is_false()
		var shown: Array[Rect2] = []
		for ticket: PriceSticker in clip.tickets():
			shown.append(ticket.get_global_rect())
		for slot: int in range(clip.items().size()):
			for sticker: EffectSticker in clip.planning_layer().stack(slot):
				shown.append(sticker.get_global_rect())
			if clip.planning_layer().stamp(slot) != null:
				shown.append(clip.planning_layer().stamp(slot).get_global_rect())
		shown.append_array(clip.row_strip().mark_rects())
		for rect: Rect2 in shown:
			(
				assert_bool(window.encloses(rect))
				. override_failure_message("%s %s" % [what, rect])
				. is_true()
			)
		if entry.example_quota > 0:
			var receipt: Rect2 = clip.receipt_target().get_global_rect()
			assert_bool(whole.encloses(receipt)).override_failure_message(what).is_true()
			assert_bool(window.intersects(receipt)).is_false()
			assert_bool(receipt.intersects(clip.led().get_global_rect())).is_false()
		else:
			assert_object(clip.receipt_target()).is_null()


func _assert_index_fits(page: HandbookPage, entry: HandbookEntry) -> void:
	var paper: Rect2 = Rect2(
		page.binder_rect().position + HandbookPage.INDEX_PAGE.position, HandbookPage.INDEX_PAGE.size
	)
	var parts: Array[Rect2] = [
		(page._binder.get_node("Sign") as Control).get_global_rect(),
		(page._binder.get_node("HintCard") as Control).get_global_rect(),
	]
	for row: HandbookButton in page.index_rows():
		var text: Label = row.get_node("Text") as Label
		for child: Node in row.get_children():
			var mark: Control = child as Control
			if mark != null and mark != text and mark != row.tick():
				var mark_end: float = mark.get_global_rect().position.x + mark.custom_minimum_size.x
				(
					assert_float(text.get_global_rect().position.x)
					. override_failure_message(String(entry.id))
					. is_greater_equal(mark_end)
				)
		parts.append(row.get_global_rect())
	for part: Rect2 in parts:
		assert_bool(paper.encloses(part)).override_failure_message(str(part)).is_true()
	_assert_apart(parts)


## Every entry opens in its tab, its rule shown and its clip's total the example's.
func test_every_entry_opens() -> void:
	var page: HandbookPage = await _page()
	page.open_at()
	assert_object(page.shown_entry()).is_same(page._book.entry(page._book.first_entry))
	for entry: HandbookEntry in page._book.entries:
		page.show_entry(entry.id)
		await _frames(1)
		var view: HandbookEntryView = page.entry_view()
		assert_object(view.entry()).is_same(entry)
		assert_str(page.shown_group()).is_equal(entry.group)
		var tip: String = HandbookMarkup.plain(entry.tip_rule())
		assert_str(_words(view.rule_label())).is_equal(_words_of(tip))
		if entry.page_notes().is_empty():
			assert_object(view.notes_label()).is_null()
		else:
			var notes: String = HandbookMarkup.plain(entry.page_notes())
			assert_str(_words(view.notes_label())).is_equal(_words_of(notes))
		assert_object(view.find_child("UsedBy", true, false)).is_null()
		if entry.has_example():
			view.clip().stop()
			var total: String = MonitorText.euros(entry.example_total)
			assert_str(view.clip().total_text()).override_failure_message(entry.id).is_equal(total)
			assert_str(view.equation_text()).ends_with(total)
		else:
			assert_object(view.clip()).is_null()
		var picked: Array[String] = []
		for row: HandbookButton in page.index_rows():
			if row.picked:
				picked.append(row.caption())
		assert_array(picked).is_equal([entry.title])


## A tab opens its first entry; an index row its entry; the clip plays, and stops on its final
## state when the handbook closes.
func test_tabs_and_rows_pick_entries() -> void:
	var page: HandbookPage = await _page()
	page.still = false
	page.open_at(&"chain")
	await _frames(2)
	assert_bool(page.entry_view().clip().is_playing()).is_true()
	page.tab(&"families").pressed.emit()
	assert_str(page.shown_entry().id).is_equal("fam_food")
	assert_bool(page.tab(&"families").picked).is_true()
	assert_bool(page.tab(&"keywords").picked).is_false()
	page.index_rows()[4].pressed.emit()
	assert_str(page.shown_entry().id).is_equal("fam_dairy")
	page.tab(&"coupons").pressed.emit()
	assert_str(page.shown_entry().id).is_equal("coupon")
	page.close()
	assert_bool(page.is_open()).is_false()
	page.open_at()
	assert_str(page.shown_entry().id).is_equal("coupon")
	await _frames(1)  # The rebuilt marks' old parts are freed.


## The player's reduced motion is read on every opening (a mid-run toggle holds the clips still).
func test_reduced_motion_is_read_on_each_opening() -> void:
	var page: HandbookPage = await _page()
	var reduced: Array[bool] = [false]
	page.reduced_motion = func() -> bool: return reduced[0]
	page.open_at(&"pair")
	assert_bool(page.still).is_false()
	page.close()
	reduced[0] = true
	page.open_at(&"pair")
	assert_bool(page.still).is_true()
	assert_bool(page.entry_view().clip().still).is_true()
	await _frames(1)  # The rebuilt marks' old parts are freed.


## Esc closes it; a right-click outside the binder closes it, one inside does not.
func test_esc_and_a_right_click_outside_close_it() -> void:
	var page: HandbookPage = await _page()
	var closes: Array[bool] = []
	page.closed.connect(func() -> void: closes.append(true))
	page.open_at(&"pair")
	page._input(_key(KEY_ESCAPE))
	assert_bool(page.is_open()).is_false()
	page.open_at(&"pair")
	page._input(_right_click(page.binder_rect().get_center()))
	assert_bool(page.is_open()).is_true()
	page._input(_right_click(Vector2(20, 700)))
	assert_bool(page.is_open()).is_false()
	assert_int(closes.size()).is_equal(2)
	await _frames(1)  # The rebuilt marks' old parts are freed.


## The shift's menu has Guide, which opens the handbook; a right-click while a ticket's MORNING
## chip shows its tooltip opens MORNING, and on a family glyph that family; a ticket colour's tip
## opens its family. A right-click a day slip would take does nothing new.
func test_the_shift_opens_it_from_the_menu_and_a_tooltip() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["coffee", "milk"])
	var page: HandbookPage = screen.find_child("HandbookPage", false, false) as HandbookPage
	assert_object(page).is_not_null()
	var top_bar: TopBar = screen._top_bar as TopBar
	assert_str(top_bar.guide_button.caption).is_equal("Guide")
	top_bar.guide_button.pressed.emit()
	assert_bool(page.is_open()).is_true()
	page.close()
	var tips: GlyphTips = screen._glyph_tips
	var sticker: PriceSticker = (screen._row_views[0] as ItemView).sticker()
	var chip: KeywordChip = sticker.summary().keywords()[0]
	assert_str(chip.keyword).is_equal(CardText.MORNING_WORD)
	tips.show_tip(chip)
	tips._input(_right_click(chip.get_global_rect().get_center()))
	assert_bool(page.is_open()).is_true()
	assert_str(page.shown_entry().id).is_equal("morning")
	assert_object(tips.shown_glyph()).is_null()
	page.close()
	var glyph: FamilyGlyph = sticker.glyphs()[0]
	tips.show_tip(glyph)
	tips._input(_right_click(glyph.get_global_rect().get_center()))
	assert_str(page.shown_entry().id).is_equal("fam_breakfast")
	page.close()
	var spot: TipTarget = sticker.get_node(PriceSticker.COLOUR_SPOT_NAME) as TipTarget
	assert_str(page.entry_for_target(spot).id).is_equal("fam_breakfast")
	# A left click hides the tip and opens nothing.
	tips.show_tip(chip)
	var left: InputEventMouseButton = _right_click(Vector2.ZERO)
	left.button_index = MOUSE_BUTTON_LEFT
	tips._input(left)
	assert_bool(page.is_open()).is_false()
	# A right-click that belongs to something else opens nothing.
	page.deep_link_blocked = func() -> bool: return true
	tips.show_tip(chip)
	tips._input(_right_click(chip.get_global_rect().get_center()))
	assert_bool(page.is_open()).is_false()


## A coupon's ticket (its colour, its glyph, its price) opens that coupon's own entry, its keyword
## chips their keywords'; a monitor line that opens with an entry's title (an inspection's, a
## coupon's) opens that entry. A tip that opens an entry says so on its footer; one that opens
## none (a plain price) has none.
func test_a_coupon_ticket_and_a_titled_line_open_their_entries() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["milk", "two_for_one", "milk"])
	var page: HandbookPage = screen.find_child("HandbookPage", false, false) as HandbookPage
	var tips: GlyphTips = screen._glyph_tips
	var sticker: PriceSticker = (screen._row_views[1] as ItemView).sticker()
	assert_bool(sticker.card().is_coupon()).is_true()
	var spot: TipTarget = sticker.get_node(PriceSticker.COLOUR_SPOT_NAME) as TipTarget
	assert_str(page.entry_for_target(spot).id).is_equal("two_for_one")
	for glyph: FamilyGlyph in sticker.glyphs():
		assert_str(page.entry_for_target(glyph).id).is_equal("two_for_one")
	tips.show_tip(spot)
	assert_bool(tips.tip().hint().visible).is_true()
	tips._input(_right_click(spot.get_global_rect().get_center()))
	assert_bool(page.is_open()).is_true()
	assert_str(page.shown_entry().id).is_equal("two_for_one")
	page.close()
	var line: TipTarget = auto_free(TipTarget.new())
	for case: Array in [
		["Opening deal: ×5 on the first item", "opening_deal"],
		["2 for 1 copies the next item", "two_for_one"],
	]:
		line.tip_text = case[0]
		var found: HandbookEntry = page.entry_for_target(line)
		assert_object(found).override_failure_message(case[0]).is_not_null()
		if found != null:
			assert_str(String(found.id)).is_equal(case[1])
	# The removed SHIFT tab's pages and PLACES' BESIDE no longer open from a line, so its tip has
	# no footer.
	for removed: String in [
		"Spot check · slot 3 pays 0€", "Today's target is 65€", "Beside Milk: +3", "BESIDE"
	]:
		line.tip_text = removed
		assert_object(page.entry_for_target(line)).override_failure_message(removed).is_null()
		assert_bool(page.has_entry_for(line)).is_false()
	line.tip_text = "Printed price 5€"
	assert_object(page.entry_for_target(line)).is_null()
	assert_bool(page.has_entry_for(line)).is_false()
	# A plain item's price window opens nothing, so its tip has no footer.
	var plain: PriceSticker = (screen._row_views[0] as ItemView).sticker()
	var window: PriceWindow = plain.get_node(PriceSticker.WINDOW_NAME) as PriceWindow
	assert_object(page.entry_for_target(window)).is_null()
	tips.show_tip(window)
	assert_bool(tips.tip().hint().visible).is_false()


## Every entry's rule fits its rect: inside the entry column, as wide as it and tall enough for all
## its lines (nothing cut or scrolled). A family's page and the coupon intro end at the rule: no
## clip, no slip, no empty strip under it.
func test_every_rule_fits_and_plain_pages_end_at_it() -> void:
	var page: HandbookPage = await _page()
	page.open_at()
	for entry: HandbookEntry in page._book.entries:
		page.show_entry(entry.id)
		await _frames(2)
		var what: String = String(entry.id)
		var view: HandbookEntryView = page.entry_view()
		var rule: RichTextLabel = view.rule_label()
		var rect: Rect2 = rule.get_global_rect()
		var column: Rect2 = page.entry_scroll().get_global_rect()
		assert_float(rect.position.x).override_failure_message(what).is_greater_equal(
			column.position.x
		)
		assert_float(rect.end.x).override_failure_message(what).is_less_equal(column.end.x)
		assert_float(rect.size.y).override_failure_message(what).is_greater(0.0)
		assert_float(float(rule.get_content_height())).override_failure_message(what).is_less_equal(
			rect.size.y + 0.5
		)
		assert_bool(rule.is_scroll_active()).is_false()
		assert_int(rule.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
		if entry.has_example():
			continue
		assert_object(view.clip()).override_failure_message(what).is_null()
		assert_object(view.find_child("Slip", true, false)).override_failure_message(what).is_null()
		assert_object(view.get_child(view.get_child_count() - 1)).is_same(rule)
		assert_float(view.get_global_rect().end.y).override_failure_message(what).is_equal_approx(
			rect.end.y, 0.5
		)


## The rule's terms show in their own colours (HandbookText): a keyword in its chip's family shade
## (one palette step darker when too light to read; WASTED in its tomato), an item in the item
## violet after its mini, a coupon and a family on their ticket's face after their icon, the
## coupon mark as a coupon, a family with no ticket colours plainly; an unknown token shows
## plainly. An item's mini stands about as tall as a family's glyph.
func test_terms_show_in_their_colours() -> void:
	var palette: FamilyPalette = FamilyPalette.shared()
	var runs: Array[HandbookMarkup.Run] = (
		HandbookMarkup
		. runs(
			(
				"{kw:CHAIN} {kw:MORNING} {kw:WASTED} {item:banana} {coupon:repeat} {fam:Dairy} {kw:NOPE}"
				+ " {fam:Coupon} {kw:BATCH}"
			)
		)
	)
	var terms: Array[HandbookMarkup.Run] = []
	for run: HandbookMarkup.Run in runs:
		if run.kind != HandbookMarkup.Kind.TEXT:
			terms.append(run)
	assert_int(terms.size()).is_equal(9)
	assert_that(HandbookText.ink_for(terms[0])).is_equal(palette.style("Produce").shade)
	assert_that(HandbookText.ink_for(terms[1])).is_equal(Palette.MUSTARD_DARKEST)
	assert_that(HandbookText.ink_for(terms[2])).is_equal(KeywordChip.WASTED_FACE)
	assert_that(HandbookText.ink_for(terms[3])).is_equal(HandbookText.ITEM_INK)
	assert_object(HandbookText.icon_for(terms[3])).is_not_null()
	assert_that(HandbookText.face_for(terms[4])).is_equal(HandbookText.COUPON_FACE)
	assert_object(HandbookText.icon_for(terms[4])).is_not_null()
	assert_that(HandbookText.face_for(terms[5])).is_equal(palette.style("Dairy").face)
	assert_object(HandbookText.icon_for(terms[5])).is_not_null()
	assert_int(terms[6].kind).is_equal(HandbookMarkup.Kind.UNKNOWN)
	assert_that(HandbookText.face_for(terms[7])).is_equal(HandbookText.COUPON_FACE)
	assert_that(HandbookText.ink_for(terms[7])).is_equal(HandbookText.COUPON_INK)
	assert_that(HandbookText.ink_for(terms[8])).is_equal(Palette.BROWN_DARK)
	var faceless: HandbookMarkup.Run = HandbookMarkup.Run.new(
		HandbookMarkup.Kind.FAMILY, "Nope", "Nope"
	)
	assert_that(HandbookText.face_for(faceless)).is_equal(Color.TRANSPARENT)
	assert_that(HandbookText.ink_for(faceless)).is_equal(Palette.INK)
	var mini_height: float = HandbookText.icon_for(terms[3]).get_size().y
	var glyph_height: float = HandbookText.icon_for(terms[5]).get_size().y
	assert_float(mini_height).is_greater_equal(HandbookText.ICON_HEIGHT)
	assert_float(absf(mini_height - glyph_height)).is_less_equal(HandbookText.ICON_HEIGHT / 3.0)


## The label writes every run: its words and spaces as written, one icon before each item, coupon
## and family, a term's own spaces unbreakable (a name never wraps), and a faced term padded inside
## its face (so the next word's comma sits outside).
func test_the_label_writes_every_run() -> void:
	var label: RichTextLabel = auto_free(
		HandbookText.label(
			"A {kw:NOPE} and {item:sugar_cubes}, {kw:CHAIN}; {fam:Dairy}, {coupon:repeat}.",
			18,
			Palette.INK,
			400.0,
			700
		)
	)
	# An inline image reads as a space.
	var icon: String = " "
	var pad: String = HandbookText.FACE_PAD
	var expected: String = (
		"A NOPE and %sSugar%scubes, CHAIN; %s%sDairy%s, %s%sRepeat%s."
		% [icon, HandbookText.NO_BREAK, icon, pad, pad, icon, pad, pad]
	)
	assert_str(label.get_parsed_text()).is_equal(expected)


## The index's pin card shows the right-click hint as art, no words (the guide feedback of
## 2026-11-11, round 3): the tooltip-and-mouse icon at whole HINT_SCALE, centred on the card's paper
## face, inside the card.
func test_the_pin_card_shows_the_right_click_icon() -> void:
	var page: HandbookPage = await _page()
	page.open_at()
	await _frames(2)
	var card: Rect2 = (page._binder.get_node("HintCard") as Control).get_global_rect()
	var hint: TextureRect = page._binder.get_node("Hint") as TextureRect
	assert_object(hint).is_not_null()
	assert_object(hint.texture).is_same(HandbookPage.HINT_ICON)
	assert_that(hint.size).is_equal(HandbookPage.HINT_ICON.get_size() * HandbookPage.HINT_SCALE)
	var rect: Rect2 = hint.get_global_rect()
	assert_bool(card.encloses(rect)).override_failure_message(str(rect)).is_true()
	var face: Rect2 = card.grow_individual(0, 0, 0, -HandbookPage.HINT_FOOT)
	assert_float(absf(rect.get_center().x - face.get_center().x)).is_less_equal(1.0)
	assert_float(absf(rect.get_center().y - face.get_center().y)).is_less_equal(1.0)
	for child: Node in page._binder.get_children():
		assert_bool(child is Label and (child as Label).text.contains("RIGHT-CLICK")).is_false()


## Resting the pointer on the pin card's icon shows the game's own hover tip (round 4: "hovering it
## should show your textbox"): HINT_TIP, no right-click footer (it opens no page), on screen, just
## above the icon without covering it. The icon takes no clicks, so the entry keeps its wheel.
func test_the_pin_card_icon_shows_its_tip() -> void:
	var host: Control = auto_free(Control.new())
	host.size = SCREEN_RECT.size
	add_child(host)
	var page: HandbookPage = HandbookPage.mount(host, null)
	page.still = true
	page.size = SCREEN_RECT.size
	page.open_at()
	await _frames(2)
	var tips: GlyphTips = page.find_child("GlyphTips", false, false) as GlyphTips
	var hint: TipTarget = page._binder.get_node("Hint") as TipTarget
	assert_object(hint).is_not_null()
	assert_int(hint.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	var icon: Rect2 = hint.get_global_rect()
	tips.point_at(icon.get_center())
	assert_object(tips.glyph_at(icon.get_center())).is_same(hint)
	await get_tree().create_timer(GlyphTips.SHOW_DELAY_S + 0.1).timeout
	await _frames(2)
	assert_object(tips.shown_glyph()).is_same(hint)
	var tip: GlyphTip = tips.tip()
	assert_str(tip.tip_text()).is_equal(HandbookPage.HINT_TIP)
	assert_bool(tip.hint().visible).is_false()
	var box: Rect2 = tip.get_global_rect()
	assert_bool(SCREEN_RECT.encloses(box)).override_failure_message(str(box)).is_true()
	assert_bool(box.intersects(icon)).override_failure_message("%s %s" % [box, icon]).is_false()
	assert_float(icon.position.y - box.end.y).is_between(0.0, 48.0)
	assert_bool(box.end.x > icon.position.x and box.position.x < icon.end.x).is_true()
	# Right-clicking it opens nothing and the page stays on its entry.
	var shown: StringName = page.shown_entry().id
	tips._input(_right_click(icon.get_center()))
	assert_bool(page.is_open()).is_true()
	assert_str(String(page.shown_entry().id)).is_equal(String(shown))


## The slip paints each card's name (an item in the rule's item violet, a coupon in the coupon
## teal), each changed payout and the total in orange, and keeps every equation that fits one line
## on one line (the longest, MORNING's, among them).
func test_the_slip_paints_names_and_stays_one_line() -> void:
	var page: HandbookPage = await _page()
	page.open_at()
	var coupons: int = 0
	for entry: HandbookEntry in page._book.entries:
		if not entry.has_example():
			continue
		page.show_entry(entry.id)
		await _frames(2)
		var what: String = String(entry.id)
		var example: HandbookExample = HandbookExample.of(entry)
		var label: RichTextLabel = (
			page.entry_view().find_child("Equation", true, false) as RichTextLabel
		)
		for card: CardDefinition in example.cards:
			var ink: Color = HandbookText.COUPON_FACE if card.is_coupon() else HandbookText.ITEM_INK
			if card.is_coupon():
				coupons += 1
			var painted: String = "[color=#%s]%s[/color]" % [ink.to_html(false), card.display_name]
			assert_str(label.text).override_failure_message(what).contains(painted)
		var total: String = MonitorText.euros(entry.example_total)
		assert_str(label.text).contains(
			"[color=#%s]%s[/color]" % [HandbookEntryView.MARKED_INK.to_html(false), total]
		)
		assert_str(label.get_parsed_text()).is_equal(example.equation())
		var font: Font = ArtStyle.number_font()
		var wide: float = (
			font
			. get_string_size(
				example.equation(), HORIZONTAL_ALIGNMENT_LEFT, -1, HandbookEntryView.EQUATION_SIZE
			)
			. x
		)
		if wide <= label.size.x:
			assert_int(label.get_line_count()).override_failure_message(what).is_equal(1)
		if entry.id == &"morning":
			assert_int(label.get_line_count()).is_equal(1)
	assert_int(coupons).is_greater(0)
	var paints: Array[HandbookExample.Paint] = [
		HandbookExample.Paint.PLAIN,
		HandbookExample.Paint.MARKED,
		HandbookExample.Paint.ITEM,
		HandbookExample.Paint.COUPON,
	]
	var inks: Array[Color] = [
		Palette.INK, HandbookEntryView.MARKED_INK, HandbookText.ITEM_INK, HandbookText.COUPON_FACE
	]
	for index: int in range(paints.size()):
		assert_that(HandbookEntryView.equation_ink(paints[index])).is_equal(inks[index])


## Every keyword's tooltip (its handbook rule's words) fits its tip: no wider than MAX_WIDTH, a
## few lines tall, its wrapped words inside its box, and above a chip at the screen's edges it
## stays inside the screen.
func test_every_keyword_tooltip_fits_its_tip() -> void:
	for word: String in GlyphText.KEYWORD_TIPS:
		var text: String = GlyphText.keyword_tip(word)
		var tip_size: Vector2 = GlyphTip.size_with(text, true)
		assert_float(tip_size.x).override_failure_message(word).is_less_equal(GlyphTip.MAX_WIDTH)
		assert_float(tip_size.y).override_failure_message(word).is_less_equal(120.0)
		for x: float in [20.0, 640.0, 1260.0]:
			var chip: Rect2 = Rect2(x - 20.0, 300.0, 40.0, 16.0)
			var box: Rect2 = GlyphTip.place(chip, chip, false, tip_size, SCREEN_RECT)
			assert_bool(SCREEN_RECT.encloses(box)).override_failure_message(word).is_true()
		var tip: GlyphTip = auto_free(GlyphTip.new())
		add_child(tip)
		# One placing must give the label its wrapped height at the tip's width (a fresh tip).
		tip.show_for(text, Rect2(600, 300, 40, 16), Rect2(600, 300, 40, 16), false, SCREEN_RECT)
		assert_bool(Rect2(Vector2.ZERO, tip.size).encloses(tip.label().get_rect())).is_true()
		await _frames(1)
		var shown: Label = tip.label()
		var room: float = float(shown.get_line_count()) * shown.get_line_height()
		assert_float(room).override_failure_message(word).is_less_equal(shown.size.y + 1.0)
		assert_bool(Rect2(Vector2.ZERO, tip.size).encloses(shown.get_rect())).is_true()


func _page() -> HandbookPage:
	var page: HandbookPage = auto_free(HandbookPage.new())
	page.still = true
	add_child(page)
	page.size = SCREEN_RECT.size
	await _frames(1)
	return page


static func _assert_apart(rects: Array[Rect2]) -> void:
	for a: int in range(rects.size()):
		for b: int in range(a + 1, rects.size()):
			(
				assert_bool(rects[a].intersects(rects[b]))
				. override_failure_message("%s %s" % [rects[a], rects[b]])
				. is_false()
			)


## A rich label's words without spacing (an inline icon, a face's pad and a term's no-break
## spaces read as spaces), to compare with plain text.
static func _words(label: RichTextLabel) -> String:
	return _words_of(label.get_parsed_text())


static func _words_of(text: String) -> String:
	var kept: String = ""
	for character: String in text:
		var code: int = character.unicode_at(0)
		var spacing: Array[String] = [HandbookText.FACE_PAD, HandbookText.NO_BREAK]
		if code > 32 and code != 0xFFFC and not character in spacing:
			kept += character
	return kept


static func _key(keycode: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.keycode = keycode
	key.pressed = true
	return key


static func _right_click(at: Vector2) -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = at
	click.global_position = at
	return click


func _screen() -> ShiftScreen:
	if FileAccess.file_exists(_folder.path_join(SaveService.RUN_FILE)):
		DirAccess.remove_absolute(_folder.path_join(SaveService.RUN_FILE))
	_runner = scene_runner(SCREEN)
	var screen: ShiftScreen = _runner.scene()
	await _frames(2)
	return screen


func _place(screen: ShiftScreen, ids: Array[String]) -> void:
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	await _frames(3)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


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


## BATCH's page (2026-11-12, "guide need update"): its rule's first paragraph over the clip (the
## chip's tooltip), the paragraphs on the frame's caps after the slip, under a dashed rule, inside
## the entry column and tall enough for all their lines; the clip's frame wears both caps, their
## FIRST and LAST tabs inside the clip's window (its foot lowered under them).
func test_the_batch_page_shows_the_caps_after_its_example() -> void:
	var page: HandbookPage = await _page()
	page.open_at(&"batch")
	await _frames(2)
	var view: HandbookEntryView = page.entry_view()
	var notes: RichTextLabel = view.notes_label()
	assert_object(notes).is_not_null()
	assert_str(_words(view.rule_label())).is_equal(
		_words_of(GlyphText.keyword_tip(CardText.BATCH_WORD))
	)
	var slip: Control = view.find_child("Slip", true, false) as Control
	assert_int(notes.get_index()).is_equal(view.get_child_count() - 1)
	assert_object(view.get_child(notes.get_index() - 1)).is_instanceof(HandbookEntryView.DashedRule)
	assert_int(slip.get_index()).is_equal(notes.get_index() - 2)
	assert_str(notes.get_parsed_text()).contains("FIRST on its left end")
	assert_str(notes.get_parsed_text()).contains("LAST on its right end")
	var rect: Rect2 = notes.get_global_rect()
	var column: Rect2 = page.entry_scroll().get_global_rect()
	assert_float(rect.position.x).is_greater_equal(column.position.x)
	assert_float(rect.end.x).is_less_equal(column.end.x)
	assert_float(float(notes.get_content_height())).is_less_equal(rect.size.y + 0.5)
	assert_float(rect.position.y).is_greater(slip.get_global_rect().end.y)
	var clip: HandbookClip = view.clip()
	var frames: Array[BatchFrame] = clip._layer.frames()
	assert_int(frames.size()).is_equal(1)
	var ends: BatchBookends = frames[0].bookends()
	var window: Rect2 = clip._window.get_global_rect()
	for cap: BatchBookends.Cap in [BatchBookends.Cap.FIRST, BatchBookends.Cap.LAST]:
		assert_bool(ends.shows(cap)).is_true()
		var tab: Rect2 = ends.tab_rect(cap)
		tab.position -= frames[0].frame_rect().position
		assert_bool(window.encloses(ends.get_global_transform() * tab)).is_true()
