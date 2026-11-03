extends GdUnitTestSuite
## The #132 badge pins on the real screen (PinFlow): Stock list's coming items on the monitor's
## redraw panel, Day off's SKIP tag on the day chip, its pile of gold on belt slot 1 and CHECKOUT
## skipping the shift to the machine,
## Price gun's labeller on the counter, its family picker and the price tag on the item, and Golden
## basket's gold first basket and keep screen after the count-up. Each part is checked where it
## shows: on its stage area, inside the window. The real saves and logs are never touched.

const Rush := preload("res://tests/ui/count_up_rush.gd")
const SCREEN := "res://ui/shift_screen.tscn"
const STOCK_LIST := "res://data/pins/stock_list.tres"
const DAY_OFF := "res://data/pins/day_off.tres"
const GOLDEN := "res://data/pins/golden_basket.tres"
const PRICE_GUN := "res://data/pins/price_gun.tres"
const EXPRESS_LANE := "res://data/pins/express_lane.tres"
const DOUBLE_CHECKOUT := "res://data/pins/double_checkout.tres"

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


func test_no_pin_shows_nothing() -> void:
	var screen: ShiftScreen = await _screen([])
	assert_bool(screen._pins.gun_shown()).is_false()
	assert_bool(screen._cabinet.keypad.visible).is_true()
	assert_object(screen._stage.baskets.holder(0).get_child(0)).is_not_null()
	assert_bool(_golden(screen, 0)).is_false()


## Stock list: no strip on the drawer; in redraw mode a hovered basket's monitor panel shows the
## items its redraw would bring, the pile's next ones in order; without the pin it shows none.
func test_stock_list_shows_a_baskets_coming_items() -> void:
	var screen: ShiftScreen = await _screen([STOCK_LIST])
	var run: RunState = screen.run
	var basket: int = 0
	while not run.can_redraw_basket(basket):
		basket += 1
	var notice: RedrawNotice = RedrawNotice.of_run(run, basket)
	var next: Array[CardInstance] = PinPlay.peek(run)
	assert_int(notice.coming.size()).is_equal(notice.drawn)
	for index: int in range(notice.coming.size()):
		assert_object(notice.coming[index]).is_same(next[index].definition)
	assert_bool(RedrawNotice.of_run(run, -1).coming.is_empty()).is_true()
	var plain: ShiftScreen = await _screen([])
	assert_bool(RedrawNotice.of_run(plain.run, basket).coming.is_empty()).is_true()
	# What the hover shows is what the redraw brings.
	var places: Array[int] = run.basket_places(basket)
	var coming: Array[CardDefinition] = notice.coming.duplicate()
	run.redraw_basket(basket)
	for index: int in range(coming.size()):
		assert_object(run.hand_places()[places[index]].definition).is_same(coming[index])


## Day off: the day chip wears SKIP (inside the chip, inside the window). SKIP puts the pile of
## gold on belt slot 1 (the belt's items back to the hand, the quota's burst over it, inside the
## window) and the tag reads UNDO; the belt takes no item meanwhile. UNDO takes it back, and so
## does a click on the pile; CHECKOUT with the pile skips the shift (passed on quota, logged,
## saved), leaves no sticker behind, and the machine opens.
func test_day_off_skips_the_shift_to_the_machine() -> void:
	var screen: ShiftScreen = await _screen([DAY_OFF], true)
	var run: RunState = screen.run
	var chip: InspectionTag = screen._inspection_tag
	var tag: Control = chip.skip_tag()
	assert_bool(tag.is_visible_in_tree()).is_true()
	assert_bool(chip.get_global_rect().grow(1.0).encloses(tag.get_global_rect())).is_true()
	assert_bool(screen.get_viewport_rect().encloses(tag.get_global_rect())).is_true()
	assert_bool(screen._pins.gun_shown()).is_false()  # Day off has no gun.
	assert_str(chip._skip_label.text).is_equal(InspectionTag.SKIP_TEXT)
	var placed: CardInstance = run.hand()[0]
	assert_bool(run.place(placed, 0)).is_true()
	screen._refresh()
	await _frames(2)
	var width: float = chip.size.x
	screen._pins.press_day_off()
	await _frames(2)
	assert_str(chip._skip_label.text).is_equal(InspectionTag.SKIP_ARMED_TEXT)
	assert_float(chip.size.x).is_equal_approx(width, 0.5)  # Arming never moves the top bar.
	assert_array(run.row).is_empty()
	assert_bool(run.hand().has(placed)).is_true()
	var pile: DayOffPile = screen._pins.pile()
	assert_object(pile).is_not_null()
	assert_str(pile.tag().text()).is_equal("%d€" % run.quota())
	var landing: float = DayOffPile.DROP_TIME + DayOffPile.TAG_POP_TIME + 0.1
	await get_tree().create_timer(landing).timeout
	var first: Rect2 = RowStrip.footprint(screen._slots[0]).get_global_rect()
	var foot: Vector2 = pile.get_global_rect().end
	assert_float(pile.get_global_rect().get_center().x).is_equal_approx(first.get_center().x, 2.0)
	assert_float(foot.y).is_between(first.position.y, first.end.y + 2.0)
	assert_bool(screen.get_viewport_rect().encloses(pile.get_global_rect())).is_true()
	# The belt is locked: a hand item isn't picked.
	screen._on_hand_card_clicked(screen._hand_box.cards()[0] as CardView)
	assert_object(screen._picked).is_null()
	# UNDO, then the pile's own click.
	screen._pins.press_day_off()
	await _frames(2)
	assert_object(screen._pins.pile()).is_null()
	assert_str(chip._skip_label.text).is_equal(InspectionTag.SKIP_TEXT)
	screen._pins.press_day_off()
	await _frames(2)
	screen._pins.pile().pressed.emit()
	await _frames(2)
	assert_object(screen._pins.pile()).is_null()
	assert_array(run.history).is_empty()
	# Taken by CHECKOUT.
	screen._pins.press_day_off()
	await _frames(2)
	await screen._on_checkout_pressed()
	await _frames(2)
	assert_int(run.history.size()).is_equal(1)
	assert_bool(run.history[0].day_off).is_true()
	assert_int(run.history[0].total).is_equal(run.history[0].quota)
	assert_int(int(_last_event("day_off")["shift"])).is_equal(1)
	assert_bool(RunState.MACHINE_PHASES.has(run.phase)).is_true()
	assert_bool(tag.visible).is_false()
	assert_object(screen._pins.pile()).is_not_null()  # It stays until the next shift.
	assert_array(screen._effects._layer.parts()).is_empty()
	var saved: RunSave = SaveService.new(_folder).load_run(ContentLookup.new(run.balance))
	assert_object(saved).is_not_null()
	assert_bool(saved.run.history[0].day_off).is_true()


## An inspection day can be skipped too; a Manager's review can not.
func test_day_off_skips_an_inspection_day_but_not_a_review() -> void:
	var screen: ShiftScreen = await _screen([DAY_OFF])
	screen.run.inspections = [load("res://data/inspections/short_belt.tres")]
	screen._refresh()
	await _frames(2)
	assert_bool(screen._inspection_tag.skip_tag().is_visible_in_tree()).is_true()
	var balance: BalanceDefinition = screen.run.balance.duplicate()
	balance.review_shifts = PackedInt32Array([1])
	screen.run.balance = balance
	screen._refresh()
	await _frames(2)
	assert_bool(screen._inspection_tag.skip_tag().visible).is_false()


## Price gun: the labeller lies on the counter (clear of the receipt, the keys, the keypad and
## the belt) with "1 left" on its tag; a click picks it up, a second puts it down. Armed, a click on
## a belt product opens the family picker over it, inside the window and clear of the column; a
## family gives the item its price tag (on the item) and the family, logged and saved; the gun's tag
## then reads "0 left" and the gun lies dimmed.
func test_price_gun_gives_an_item_a_family() -> void:
	var screen: ShiftScreen = await _screen([PRICE_GUN])
	var run: RunState = screen.run
	assert_bool(screen._pins.gun_shown()).is_true()
	var gun: PriceGunItem = screen._pins.gun()
	_assert_gun_place(screen, gun)
	assert_bool(screen._cabinet.keypad.is_visible_in_tree()).is_true()  # The keypad stays.
	assert_str(gun.tag_label().text).is_equal(PriceGunItem.LEFT_TEXT % 1)
	assert_str(gun.tooltip_text).is_equal(PriceGunItem.TIP)
	var product: CardInstance = null
	for card: CardInstance in run.hand():
		if card.definition.is_product():
			product = card
			break
	run.place(product, 0)
	screen._refresh()
	await _frames(2)
	assert_bool(screen._pins.take_click(product)).is_false()  # Not armed: an ordinary click.
	assert_bool(gun.is_armed()).is_false()
	# Picked up, then put down, then picked up again.
	gun.pressed.emit()
	await _frames(1)
	assert_bool(gun.is_armed()).is_true()
	assert_bool(gun.body().rotation < 0.0 or gun.body().position.y < 0.0).is_true()
	# The monitor says what to do; the shift's opening notice, playing a moment after the shift
	# starts, waits for it and shows once the gun is put down.
	var notice: NoticeLabel = screen._notice_label
	assert_str(notice.text).is_equal(PinFlow.GUN_ARMED)
	notice.show_next("Opening notice")
	assert_str(notice.text).is_equal(PinFlow.GUN_ARMED)
	gun.pressed.emit()
	await _frames(1)
	assert_bool(gun.is_armed()).is_false()
	assert_str(notice.text).is_equal("Opening notice")
	gun.pressed.emit()
	await _frames(1)
	assert_bool(gun.is_armed()).is_true()
	screen._on_row_card_clicked(screen._row_views[0])
	await _frames(2)
	var picker: PriceGunPicker = screen._pins.picker()
	assert_object(picker).is_not_null()
	_assert_picker_layout(screen, picker, screen._row_views[0])
	assert_object(picker.remove_button()).is_null()  # Not relabelled yet.
	assert_array(run.row).is_equal([product])  # The click didn't take it back.
	var tags: PackedStringArray = screen._pins._picker_tags(product)
	assert_int(picker.chips().size()).is_equal(tags.size())
	var tag: String = tags[0]
	picker.chips()[0].pressed.emit()
	await _frames(2)
	assert_str(PinPlay.relabel_of(run, product)).is_equal(tag)
	assert_object(screen._pins.picker()).is_null()
	assert_bool(gun.is_armed()).is_false()
	assert_str(gun.tag_label().text).is_equal(PriceGunItem.LEFT_TEXT % 0)
	assert_bool(gun.is_spent()).is_true()
	assert_bool(run.preview().tags[0].has(tag)).is_true()
	var view: ItemView = screen._row_views[0]
	var plate: Control = PinFlow.price_tag(view)
	assert_object(plate).is_not_null()
	assert_bool(view.get_global_rect().encloses(plate.get_global_rect())).is_true()
	# The ticket under the belt shows the gained family's glyph last in its glyph row.
	var glyphs: Array[FamilyGlyph] = view._sticker.glyphs()
	assert_str(String(glyphs[-1].name)).is_equal(PriceSticker.GAINED_NAME % tag)
	assert_bool(glyphs[-1].is_visible_in_tree()).is_true()
	var ticket: Rect2 = view._sticker.get_global_rect()
	assert_bool(ticket.grow(1.0).encloses(glyphs[-1].get_global_rect())).is_true()
	assert_str(String(_last_event("price_gun")["family"])).is_equal(tag)
	var saved: RunSave = SaveService.new(_folder).load_run(ContentLookup.new(run.balance))
	assert_str(PinPlay.relabel_of(saved.run, saved.run.row[0])).is_equal(tag)


## A hand product's picker opens over its basket, on the belt (under the monitor, clear of it),
## its notch down at the item.
func test_price_gun_picker_over_a_hand_item() -> void:
	var screen: ShiftScreen = await _screen([PRICE_GUN])
	screen._pins.gun().pressed.emit()
	await _frames(1)
	var view: ItemView = null
	for control: Control in screen._hand_box.cards():
		var item: ItemView = control as ItemView
		if item != null and item.card.definition.is_product():
			view = item
			break
	assert_object(view).is_not_null()
	screen._on_hand_card_clicked(view)
	await _frames(2)
	var picker: PriceGunPicker = screen._pins.picker()
	assert_object(picker).is_not_null()
	_assert_picker_layout(screen, picker, view)
	assert_float(picker.card().get_global_rect().end.y).is_less(view.get_global_rect().position.y)


## The picker on a relabelled item offers Remove tag (it takes the tag back); a click outside the
## card or Escape closes it with nothing changed; in redraw mode the gun is put away.
func test_price_gun_picker_removes_and_closes() -> void:
	var screen: ShiftScreen = await _screen([PRICE_GUN])
	var run: RunState = screen.run
	var gun: PriceGunItem = screen._pins.gun()
	var product: CardInstance = null
	for card: CardInstance in run.hand():
		if card.definition.is_product():
			product = card
			break
	run.place(product, 0)
	var tag: String = screen._pins._picker_tags(product)[0]
	assert_bool(PinPlay.relabel(run, product, tag)).is_true()
	screen._refresh()
	await _frames(2)
	assert_bool(gun.is_spent()).is_true()
	gun.pressed.emit()  # Spent, it still moves the tag.
	await _frames(1)
	assert_bool(gun.is_armed()).is_true()
	screen._on_row_card_clicked(screen._row_views[0])
	await _frames(2)
	var picker: PriceGunPicker = screen._pins.picker()
	assert_object(picker).is_not_null()
	_assert_picker_layout(screen, picker, screen._row_views[0])
	var remove: Button = picker.remove_button()
	assert_object(remove).is_not_null()
	assert_bool(picker.card().get_global_rect().encloses(remove.get_global_rect())).is_true()
	# A click outside the card closes it; the tag stays.
	var outside: InputEventMouseButton = InputEventMouseButton.new()
	outside.button_index = MOUSE_BUTTON_LEFT
	outside.pressed = true
	picker._gui_input(outside)
	await _frames(2)
	assert_object(screen._pins.picker()).is_null()
	assert_str(PinPlay.relabel_of(run, product)).is_equal(tag)
	# Escape closes it too.
	screen._on_row_card_clicked(screen._row_views[0])
	await _frames(2)
	picker = screen._pins.picker()
	assert_object(picker).is_not_null()
	var escape: InputEventAction = InputEventAction.new()
	escape.action = &"ui_cancel"
	escape.pressed = true
	picker._unhandled_key_input(escape)
	await _frames(2)
	assert_object(screen._pins.picker()).is_null()
	# Remove tag takes it back: one left again, the gun no longer dimmed.
	screen._on_row_card_clicked(screen._row_views[0])
	await _frames(2)
	screen._pins.picker().remove_button().pressed.emit()
	await _frames(2)
	assert_str(PinPlay.relabel_of(run, product)).is_empty()
	assert_str(gun.tag_label().text).is_equal(PriceGunItem.LEFT_TEXT % 1)
	assert_bool(gun.is_spent()).is_false()
	# Redraw mode puts the gun away.
	screen._redraw_mode = true
	screen._refresh()
	await _frames(2)
	assert_bool(screen._pins.gun_shown()).is_false()


## The picker's card inside the window, clear of the register column (and the receipt over it)
## and of the monitor, its notch's tip right by the item; its chips one size, in rows of
## PriceGunPicker.CHIP_COLUMNS, all inside the card and apart.
func _assert_picker_layout(screen: ShiftScreen, picker: PriceGunPicker, view: ItemView) -> void:
	var card: Rect2 = picker.card().get_global_rect()
	(
		assert_bool(screen.get_viewport_rect().encloses(card))
		. override_failure_message(str(card))
		. is_true()
	)
	var column: Rect2 = _on_stage(screen, ShiftStage.COLUMN_RECT)
	assert_float(card.position.x).is_greater(column.end.x)
	var receipt: Rect2 = screen._receipt.get_global_rect()
	assert_bool(card.intersects(receipt)).is_false()
	# Never over the monitor (its item and notice stay readable).
	var monitor: Rect2 = screen._stage.monitor.get_global_rect()
	assert_bool(card.intersects(monitor)).override_failure_message(str(card)).is_false()
	# The notch points at the item from under or over it, its tip right by the item.
	var item: Rect2 = view.get_global_rect()
	var tip: Vector2 = picker.notch_tip()
	var near: float = PriceGunPicker.GAP + 0.5
	assert_float(tip.x).is_between(card.position.x, card.end.x)
	if card.position.y >= item.get_center().y:
		assert_float(tip.y).is_between(item.end.y, card.position.y)
		assert_float(tip.y - item.end.y).is_less_equal(near)
	else:
		assert_float(tip.y).is_between(card.end.y, item.position.y)
		assert_float(item.position.y - tip.y).is_less_equal(near)
	var chips: Array[Button] = picker.chips()
	var rows: Dictionary[int, int] = {}
	for index: int in range(chips.size()):
		var rect: Rect2 = chips[index].get_global_rect()
		var message: String = "chip %d at %s on %s" % [index, rect, card]
		assert_bool(card.encloses(rect)).override_failure_message(message).is_true()
		assert_vector(rect.size).is_equal_approx(chips[0].get_global_rect().size, Vector2.ONE)
		var row: int = int(roundf(rect.position.y))
		rows[row] = rows.get(row, 0) + 1
		for other: int in range(index + 1, chips.size()):
			var other_rect: Rect2 = chips[other].get_global_rect()
			assert_bool(rect.intersects(other_rect)).override_failure_message(message).is_false()
	for count: int in rows.values():
		assert_int(count).is_less_equal(PriceGunPicker.CHIP_COLUMNS)
	assert_int(rows.size()).is_equal(ceili(chips.size() / float(PriceGunPicker.CHIP_COLUMNS)))


## Express lane is a run-wide pin, not a daily event: a normal day with it worn reads "Normal
## day" in the plain day's grey, its tooltip and an inspection day's effects leave it out (the
## belt's end marks show it), and the chip stays inside the window.
func test_express_lane_stays_off_the_day_chip() -> void:
	var screen: ShiftScreen = await _screen([EXPRESS_LANE], true)
	var chip: InspectionTag = screen._inspection_tag
	assert_str(chip._label.text).is_equal("Normal day")
	assert_str(chip._tips).not_contains("Express lane")
	var grey: Color = InspectionTag.tint_of(WeekCardModel.Kind.NONE)
	var paper: Color = Palette.PAPER
	var tint: Color = Color(grey.r / paper.r, grey.g / paper.g, grey.b / paper.b)
	assert_bool(chip.self_modulate.is_equal_approx(tint)).is_true()
	assert_bool(chip.is_boon()).is_false()
	screen.run.inspections = [load("res://data/inspections/spot_check.tres")]
	screen._refresh()
	await _frames(2)
	assert_str(chip._effects_text).not_contains("Ends ×2")
	assert_str(chip._effects_text).not_contains("Express lane")
	assert_str(chip._label.text).not_contains("Express lane")
	assert_str(chip._tips).not_contains("Express lane")
	assert_bool(screen.get_viewport_rect().encloses(chip.get_global_rect())).is_true()


## Hovering an item Express lane doubles (the row's first end) rings neither the day chip nor the
## week chip: the pin is run-wide (WeekFlow.day_index is -1 for its event).
func test_express_lane_end_item_rings_no_chip() -> void:
	var screen: ShiftScreen = await _screen([EXPRESS_LANE], true)
	var run: RunState = screen.run
	var event: InspectionDefinition = (load(EXPRESS_LANE) as PinDefinition).events[0]
	var index: int = WeekSchedule.shift_events(run).find(event)
	assert_bool(WeekFlow.is_pin_event(run, index)).is_true()
	assert_int(WeekFlow.day_index(run, index)).is_equal(-1)
	assert_int((await _place(screen, 3)).size()).is_equal(3)
	var caused: bool = false
	for link: EffectLink in screen._effects.committed_model().graph.incoming(0):
		caused = (
			caused
			or (link.cause_kind == ScoreStep.SourceKind.INSPECTION and link.cause_index == index)
		)
	assert_bool(caused).is_true()
	var item: ItemView = screen._row_views[0] as ItemView
	item.hovered.emit(item)
	assert_bool(screen._inspection_tag.has_relation()).is_false()
	assert_bool(screen._stage.top_bar.week_chip.has_relation()).is_false()
	screen._effects.unfocus()


## A day event on an Express lane end still rings the day chip: with Happy hour (the last filled
## slot +3€) and a full row, the last item is caused by both, and the day's event wins over the
## run-wide pin's.
func test_a_day_event_on_an_express_lane_end_still_rings_the_day_chip() -> void:
	var screen: ShiftScreen = await _screen([EXPRESS_LANE], true)
	var run: RunState = screen.run
	run.inspections = [load("res://data/inspections/happy_hour.tres") as InspectionDefinition]
	screen._refresh()
	await _frames(2)
	var slots: int = RowCapacity.card_limit(run.limits)
	assert_int((await _place(screen, slots)).size()).is_equal(slots)
	var events: Array[InspectionDefinition] = WeekSchedule.shift_events(run)
	var pin_event: InspectionDefinition = (load(EXPRESS_LANE) as PinDefinition).events[0]
	var kinds: Dictionary[String, bool] = {}
	var last: int = slots - 1
	for link: EffectLink in screen._effects.committed_model().graph.incoming(last):
		if link.cause_kind == ScoreStep.SourceKind.INSPECTION:
			kinds["pin" if events[link.cause_index] == pin_event else "day"] = true
	assert_dict(kinds).is_equal({"pin": true, "day": true})
	var item: ItemView = screen._row_views[last] as ItemView
	item.hovered.emit(item)
	assert_bool(screen._inspection_tag.has_relation()).is_true()
	assert_bool(screen._stage.top_bar.week_chip.has_relation()).is_false()
	screen._effects.unfocus()


## The count-up's step sources: a worn pin's event maps to no chip (null, so its steps fly from the
## item), the day's to the day chip and the week event to the week chip.
func test_express_lane_steps_have_no_chip_source() -> void:
	var screen: ShiftScreen = await _screen([EXPRESS_LANE])
	var run: RunState = screen.run
	var bar: TopBar = screen._stage.top_bar
	var events: Array[InspectionDefinition] = WeekSchedule.shift_events(run)
	var sources: Array[Control] = bar.event_sources(events, RunPins.pin_events(run).size())
	assert_int(sources.size()).is_equal(events.size())
	var event: InspectionDefinition = (load(EXPRESS_LANE) as PinDefinition).events[0]
	assert_object(sources[events.find(event)]).is_null()
	for at: int in range(events.size()):
		if events[at] == event:
			continue
		var chip: Control = bar.inspection_tag
		if events[at].is_week():
			chip = bar.week_chip
		assert_object(sources[at]).is_same(chip)


## Express lane on the belt: the row's ends wear its express tag ("×N", the rule's factor) and
## are marked themselves (SlotLane: a green plate round the ticket, a lane painted on the slot's
## belt patch), on the ends only: slot 1 and the row's last open slot, which stay put as
## items are placed and taken back (the user's call of 2026-11-02: not the last filled
## slot). Each lies on its own slot, inside the window, clear of the other cells, and covers no
## ticket.
func test_express_lane_marks_the_row_ends() -> void:
	var screen: ShiftScreen = await _screen([EXPRESS_LANE], true)
	var run: RunState = screen.run
	var event: InspectionDefinition = (load(EXPRESS_LANE) as PinDefinition).events[0]
	var rule: EndSlotsMultiplierRule = event.rules[0] as EndSlotsMultiplierRule
	var index: int = WeekSchedule.shift_events(run).find(event)
	assert_int(index).is_greater_equal(0)
	var text: String = SlotMark.TEXT_FORMAT % rule.factor
	var ends: Array[int] = [0, run.limits.slot_count - 1]
	assert_int(ends[1]).is_greater(2)
	_assert_end_marks(screen, index, text, ends)
	# An empty end slot shows its lane alone, no blank mat (2026-11-02); other empty slots keep it.
	assert_bool(RowStrip.shows_empty_mat(screen._slots[ends[1]])).is_false()
	assert_bool(RowStrip.shows_empty_mat(screen._slots[1])).is_true()
	var placed: Array[CardInstance] = []
	for card: CardInstance in run.hand():
		if placed.size() == 3:
			break
		if run.place(card, run.row.size()):
			placed.append(card)
			screen._refresh()
			await _frames(2)
			_assert_end_marks(screen, index, text, ends)
	assert_int(placed.size()).is_equal(3)
	run.remove(placed[-1])
	screen._refresh()
	await _frames(2)
	_assert_end_marks(screen, index, text, ends)


## With Double checkout, each row is marked on its own ends (its first and last open slots): row
## 1's while it is planned, then, once row 1 is counted, row 2's on the emptied belt.
func test_express_lane_marks_each_double_checkout_row() -> void:
	var screen: ShiftScreen = await _screen([EXPRESS_LANE, DOUBLE_CHECKOUT], true)
	var run: RunState = screen.run
	var event: InspectionDefinition = (load(EXPRESS_LANE) as PinDefinition).events[0]
	var index: int = WeekSchedule.shift_events(run).find(event)
	var text: String = SlotMark.TEXT_FORMAT % (event.rules[0] as EndSlotsMultiplierRule).factor
	var ends: Array[int] = [0, run.limits.slot_count - 1]
	_assert_end_marks(screen, index, text, ends)
	var row_one: Array[CardInstance] = await _place(screen, 3)
	assert_int(row_one.size()).is_greater_equal(2)
	_assert_end_marks(screen, index, text, ends)
	await Rush.checkout(screen)
	await _frames(2)
	assert_array(run.row).is_empty()
	assert_int(run.first_row.size()).is_equal(row_one.size())
	_assert_end_marks(screen, index, text, ends)
	var row_two: Array[CardInstance] = await _place(screen, 2)
	assert_int(row_two.size()).is_equal(2)
	_assert_end_marks(screen, index, text, ends)


## The pin event `index`'s marks read `text`, on the slots `ends` and no other, each on its slot:
## the tag under its ticket (covering none of it), the lane's plate round the ticket and its paint
## on the slot's belt patch, inside the cell (the plate reaching at most half the gap past it).
func _assert_end_marks(screen: ShiftScreen, index: int, text: String, ends: Array[int]) -> void:
	var window: Rect2 = screen.get_viewport_rect()
	var belt: Rect2 = _on_stage(screen, ShiftStage.BELT_RECT)
	for slot: int in range(screen._slots.size()):
		var mark: SlotMark = screen._row_strip.inspection_mark(slot, index)
		var lane: SlotLane = screen._row_strip.lane(slot)
		var where: String = "slot %d" % slot
		if slot not in ends:
			assert_object(mark).override_failure_message(where).is_null()
			assert_object(lane).override_failure_message(where).is_null()
			continue
		assert_object(mark).override_failure_message(where).is_not_null()
		assert_object(lane).override_failure_message(where).is_not_null()
		assert_str(mark.text()).is_equal(text)
		assert_bool(mark.ends).is_true()
		assert_bool(mark.is_visible_in_tree()).is_true()
		assert_bool(lane.is_visible_in_tree()).is_true()
		var panel: PanelContainer = screen._slots[slot]
		var to_global: Transform2D = panel.get_global_transform()
		var cell: Rect2 = to_global * Rect2(Vector2.ZERO, panel.size)
		var ticket: Rect2 = to_global * RowStrip.TICKET_RECT
		var rect: Rect2 = mark.get_global_transform() * Rect2(Vector2.ZERO, mark.size)
		var plate: Rect2 = lane.get_global_transform() * SlotLane.plate_rect()
		var paint: Rect2 = lane.get_global_transform() * SlotLane.belt_rect()
		var gap: float = RowStrip.SEPARATION / 2.0 * to_global.get_scale().x
		var message: String = (
			"%s: tag %s plate %s paint %s cell %s" % [where, rect, plate, paint, cell]
		)
		# The tag hangs under the ticket, across its cell's width, covering none of the ticket.
		assert_float(rect.position.x).override_failure_message(message).is_greater_equal(
			cell.position.x
		)
		assert_float(rect.end.x).override_failure_message(message).is_less_equal(cell.end.x + 0.5)
		assert_float(rect.position.y).override_failure_message(message).is_greater_equal(
			ticket.end.y - SlotMark.TUCKED - 0.5
		)
		# The plate frames the ticket; the paint lies on the slot's patch of belt, above the rail.
		assert_bool(plate.encloses(ticket.grow(1.0))).override_failure_message(message).is_true()
		var reach: Rect2 = cell.grow_individual(gap + 0.5, 0.0, gap + 0.5, 0.0)
		assert_float(plate.position.x).override_failure_message(message).is_greater_equal(
			reach.position.x
		)
		assert_float(plate.end.x).override_failure_message(message).is_less_equal(reach.end.x)
		assert_bool(cell.grow(0.5).encloses(paint)).override_failure_message(message).is_true()
		assert_bool(belt.encloses(paint)).override_failure_message(message).is_true()
		assert_float(paint.end.y).override_failure_message(message).is_less_equal(ticket.position.y)
		for part: Rect2 in [rect, plate, paint]:
			assert_bool(window.encloses(part)).override_failure_message(message).is_true()
		for other: int in range(screen._slots.size()):
			if other == slot:
				continue
			var other_panel: PanelContainer = screen._slots[other]
			var other_cell: Rect2 = (
				other_panel.get_global_transform() * Rect2(Vector2.ZERO, other_panel.size)
			)
			for part: Rect2 in [rect, plate, paint]:
				(
					assert_bool(other_cell.intersects(part))
					. override_failure_message(message)
					. is_false()
				)


## Places the first `count` hand items on the belt, as the player would.
func _place(screen: ShiftScreen, count: int) -> Array[CardInstance]:
	var placed: Array[CardInstance] = []
	for card: CardInstance in screen.run.hand():
		if placed.size() == count:
			break
		if screen.run.place(card, screen.run.row.size()):
			placed.append(card)
	screen._refresh()
	await _frames(2)
	return placed


## Golden basket: the first basket is gold; after the count-up the keep screen shows the golden
## basket in the middle and the belt's items under it, all inside the window; an item dropped into
## the basket is kept (dropped back on the list, let go); kept items fill the next shift's first
## basket.
func test_golden_basket_keeps_items_after_the_count() -> void:
	var screen: ShiftScreen = await _screen([GOLDEN])
	var run: RunState = screen.run
	assert_bool(_golden(screen, 0)).is_true()
	assert_bool(_golden(screen, 1)).is_false()
	var placed: Array[CardInstance] = []
	for card: CardInstance in run.hand():
		if placed.size() == 3:
			break
		if run.place(card, run.row.size()):
			placed.append(card)
	screen._refresh()
	await _frames(2)
	var count_up: CountUp = screen._count_up
	(func() -> void: Rush.rush(count_up)).call_deferred()
	screen._on_checkout_pressed()
	var start: int = Time.get_ticks_msec()
	while screen._pins.keep_panel() == null and Time.get_ticks_msec() - start < Rush.MAX_WAIT_MS:
		await _frames(1)
	var keep: KeepScreen = screen._pins.keep_panel()
	assert_object(keep).is_not_null()
	await _frames(1)
	_assert_keep_layout(screen, keep, 3)
	# Into the basket by a real drag: kept, shown in the first place, gone from the list.
	assert_bool(keep.can_drop_in(_drag(placed[1]))).is_true()
	await _drag_to(keep, placed[1], keep.basket().get_global_rect().get_center())
	assert_bool(PinPlay.is_kept(run, placed[1])).is_true()
	assert_int(keep.places()[0].get_child_count()).is_equal(1)
	assert_int(keep.list_cells().size()).is_equal(2)
	assert_bool(keep.can_drop_in(_drag(placed[1]))).is_false()
	# A drop off the basket and the belt keeps nothing: the ghost flies back.
	await _drag_to(keep, placed[0], Vector2(4, 4))
	assert_bool(PinPlay.is_kept(run, placed[0])).is_false()
	assert_bool(keep.keep(placed[0])).is_true()  # A click's.
	assert_bool(keep.can_drop_in(_drag(placed[2]))).is_false()  # Full.
	# Back on the list: let go.
	assert_bool(keep.release(placed[0])).is_true()
	assert_bool(PinPlay.is_kept(run, placed[0])).is_false()
	await _frames(1)
	_assert_keep_layout(screen, keep, 2)
	keep.done_button().pressed.emit()
	await _frames(2)
	assert_object(screen._pins.keep_panel()).is_null()
	var kept: Array = _last_event("golden_basket")["kept"]
	assert_array(kept.map(func(id: float) -> int: return int(id))).is_equal([placed[1].instance_id])
	# A pass opens the machine; a training-week slip has started the next shift already.
	if RunState.MACHINE_PHASES.has(run.phase):
		assert_bool(MachineSteps.next_shift(run)).is_true()
	assert_int(run.shift_index).is_equal(1)
	assert_int(run.deck.hand()[0].instance_id).is_equal(placed[1].instance_id)


## The keep screen's parts: the basket centred and its places inside it, the list's `cells` cells
## under it in one row, DONE under the list, all inside the window.
func _assert_keep_layout(screen: ShiftScreen, keep: KeepScreen, cells: int) -> void:
	var window: Rect2 = screen.get_viewport_rect()
	var basket: Rect2 = keep.basket().get_global_rect()
	assert_bool(window.encloses(basket)).is_true()
	assert_float(basket.get_center().x).is_equal_approx(window.get_center().x, 1.0)
	for place: Control in keep.places():
		assert_bool(basket.grow(1.0).encloses(place.get_global_rect())).is_true()
	var list: Array[Control] = keep.list_cells()
	assert_int(list.size()).is_equal(cells)
	for cell: Control in list:
		var rect: Rect2 = cell.get_global_rect()
		assert_bool(window.encloses(rect)).is_true()
		assert_bool(rect.position.y >= basket.end.y).is_true()
		assert_float(rect.position.y).is_equal_approx(list[0].get_global_rect().position.y, 0.5)
	var done: Rect2 = keep.done_button().get_global_rect()
	assert_bool(window.encloses(done)).is_true()
	assert_bool(done.position.y >= list[0].get_global_rect().end.y).is_true()


## Drags `card`'s list cell on the keep screen to `to` (global) and drops it: the press, a move
## past the threshold (the ghost, lifted and centred on the mouse, its cell faded), the move to
## `to` (over the basket the ghost grows to the basket's size and the basket lights up), then
## the release.
func _drag_to(keep: KeepScreen, card: CardInstance, to: Vector2) -> void:
	var cell: Control = null
	for listed: Control in keep.list_cells():
		if listed.name == "Keep%d" % card.instance_id:
			cell = listed
	assert_object(cell).is_not_null()
	var from: Vector2 = cell.get_global_rect().get_center()
	keep._arm(card, false, from, cell)
	keep._input(_motion(from + Vector2(CardDrag.DRAG_THRESHOLD + 2.0, 0.0)))
	var ghost: ItemView = keep.ghost()
	assert_object(ghost).is_not_null()
	assert_float(cell.modulate.a).is_less(1.0)
	keep._input(_motion(to))
	var centre: Vector2 = ghost.get_global_rect().position + ItemView.SPRITE_SIZE / 2.0
	assert_vector(centre).is_equal_approx(to, Vector2.ONE)
	var over: bool = keep.basket().get_global_rect().has_point(to)
	assert_bool(keep.basket().modulate == KeepScreen.TARGET_LIGHT).is_equal(over)
	await get_tree().create_timer(KeepScreen.GROW_TIME + 0.1).timeout
	var grown: float = ghost.body.scale.x
	assert_float(grown).is_greater(KeepScreen.BASKET_SCALE if over else 0.9)
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = to
	keep._input(release)
	assert_object(keep.ghost()).is_null()
	await get_tree().create_timer(KeepScreen.BACK_TIME + 0.1).timeout


static func _motion(at: Vector2) -> InputEventMouseMotion:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	return motion


static func _drag(card: CardInstance) -> Dictionary:
	return {"kind": KeepScreen.DRAG_KIND, "card": card}


## The screen with `pins` worn on a new shift 1 (as a run start would), on a normal day when
## `normal`.
func _screen(pins: Array, normal: bool = false) -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(3)
	var worn: Array[PinDefinition] = []
	for path: String in pins:
		worn.append(load(path))
	RunPins.wear(screen.run, worn)
	screen.run.start_shift()
	if normal:
		screen.run.inspections = []
	screen._refresh()
	await _frames(2)
	return screen


## The labeller and its tag inside the window, clear of the receipt, CHECKOUT, Redraw, the
## keypad and the belt.
func _assert_gun_place(screen: ShiftScreen, gun: PriceGunItem) -> void:
	var window: Rect2 = screen.get_viewport_rect()
	var keep_clear: Dictionary[String, Rect2] = {
		"receipt": screen._receipt.get_global_rect(),
		"checkout": screen._cabinet.checkout_key.get_global_rect(),
		"redraw": screen._cabinet.redraw_key.get_global_rect(),
		"keypad": screen._cabinet.keypad.get_global_rect(),
		"belt": _on_stage(screen, ShiftStage.BELT_RECT),
	}
	for part: Control in [gun, gun.tag()]:
		var rect: Rect2 = part.get_global_rect()
		assert_bool(window.encloses(rect)).override_failure_message(str(rect)).is_true()
		for part_name: String in keep_clear:
			(
				assert_bool(rect.intersects(keep_clear[part_name]))
				. override_failure_message(
					"%s %s on the %s %s" % [part.name, rect, part_name, keep_clear[part_name]]
				)
				. is_false()
			)
	assert_vector(gun.get_global_rect().position).is_equal_approx(
		_on_stage(screen, PriceGunItem.RECT).position, Vector2.ONE
	)


## Whether basket `index` wears the golden art (both layers).
static func _golden(screen: ShiftScreen, index: int) -> bool:
	var golden: bool = true
	for layer: HandBaskets in [screen._stage.baskets, screen._stage.basket_fronts]:
		var found: bool = false
		for child: Node in layer.holder(index).get_children():
			var art: TextureRect = child as TextureRect
			if art == null:
				continue
			found = (
				found
				or (
					art.texture
					in [
						HandBaskets.FRONT_GOLDEN,
						HandBaskets.BACK_LEFT_GOLDEN,
						HandBaskets.BACK_RIGHT_GOLDEN,
					]
				)
			)
		golden = golden and found
	return golden


static func _on_stage(screen: ShiftScreen, rect: Rect2) -> Rect2:
	return Rect2(screen._stage.get_global_rect().position + rect.position, rect.size)


func _last_event(type: String) -> Dictionary:
	var lines: PackedStringArray = EventLogWriter.join_logs(_folder).split("\n", false)
	for index: int in range(lines.size() - 1, -1, -1):
		var event: Dictionary = JSON.parse_string(lines[index])
		if event["type"] == type:
			return event
	return {}


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
