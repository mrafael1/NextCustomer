extends GdUnitTestSuite
## Start v4 B page 2, the staff room (full build plan 7.2, reworked 2026-11-05): the pack-line
## highlight on the order sheet (the cart overview: the trolley is gone), the waiting state before
## a pick, the sign naming the pick, NEW PACKS, the crates (items, name and family only, v1.01),
## the time clock's lines and parts, and the pins card.

const SCREEN := preload("res://ui/shift_screen.tscn")
const SEED := 20261103

var _folder: String


func before_test() -> void:
	_folder = "user://start_build_page_test_%d" % Time.get_ticks_usec()
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_event_log().use_folder(_folder)


func after_test() -> void:
	await get_tree().process_frame
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file))
		DirAccess.remove_absolute(_folder)


## Page 2's pack highlight (agreed rule): with no pick, red "pick a crate" lines and the
## PICK A PACK FIRST clock; a pick tints its lines solid, a preview dashed. The sign names the
## pick. No trolley is left on the page.
func test_pack_lines_are_highlighted_on_the_sheet() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	board.show_page(2)
	assert_object(board.staff.find_child("*Trolley*", true, false)).is_null()
	var order: OrderSheet = board.staff.order
	var sheet: Rect2 = order.get_global_rect()
	var packed: int = screen.run.start_offer.first_pick.cards.size()
	board.selected = -1
	board.refresh()
	assert_object(order.pack_rows).is_null()
	assert_str(order.waiting_note.text).contains("+%d when you pick a crate" % packed)
	assert_bool(sheet.encloses(order.waiting_note.get_global_rect())).is_true()
	(
		assert_bool(
			order.equation.get_global_rect().intersects(order.waiting_note.get_global_rect())
		)
		. is_false()
	)
	var press: Control = order.find_child("PressTag", true, false)
	assert_object(press).is_not_null()
	assert_bool(sheet.encloses(press.get_global_rect())).is_true()
	assert_bool(board.staff.open_key.disabled).is_true()
	assert_str(board.staff.open_line.text).is_equal("Pick a crate, or press 1, 2 or 3")
	assert_str(board.staff._answer.text).is_equal("Pick a crate to open the store")
	assert_str(board.staff._notice_title.text).is_equal("PICK  A  STARTER  PACK")
	(
		assert_bool(
			board.staff.open_key.get_global_rect().encloses(board.staff.open_line.get_global_rect())
		)
		. is_true()
	)
	board.pick(1)
	var pick: StarterPackDefinition = screen.run.start_offer.packs[1]
	assert_str(board.staff._answer.text).is_equal(
		"%s rides in your cart" % pick.display_name.to_upper()
	)
	assert_str(board.staff._notice_title.text).is_equal("YOUR  STARTER  PACK")
	assert_object(order.waiting_note).is_null()
	assert_str(order.equation.text).contains("%d %s" % [packed, pick.display_name])
	assert_str(board.staff.open_line.text).contains(pick.display_name)
	assert_object(order.pack_rows).is_not_null()
	assert_bool(order.pack_rows.dashed).is_false()
	assert_bool(order.pack_rows.bar).is_true()
	assert_bool(order.pack_rows.fill.a > 0.0).is_true()
	assert_bool(sheet.encloses(order.pack_rows.get_global_rect())).is_true()
	# The tint covers exactly the pack's lines.
	var row: float = OrderSheet.ROW * order.get_global_transform().get_scale().y
	assert_float(order.pack_rows.get_global_rect().size.y).is_equal_approx(packed * row, 0.5)
	board._preview(2)
	assert_bool(order.pack_rows.dashed).is_true()
	board._preview(-1)
	assert_bool(order.pack_rows.dashed).is_false()
	for index: int in board.staff.crates.size():
		var crate: PackCrate = board.staff.crates[index]
		assert_bool(crate.modulate == Color.WHITE).is_equal(index == 1)


## NEW PACKS (once a run, key N): three other crates (the good first pick kept in the middle on a
## new profile), the baskets and regulars unchanged, saved; then disabled with its reason as the
## tip. The pick is cleared: OPEN STORE waits for a new pick.
func test_new_packs_redraws_the_crates_once_and_clears_the_pick() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	board.show_page(2)
	var key: Button = board.staff.new_packs_key
	assert_bool(key.disabled).is_false()
	assert_bool(_stage_rect(board).encloses(key.get_global_rect())).is_true()
	board.pick(0)
	var old_packs: Array[StarterPackDefinition] = screen.run.start_offer.packs.duplicate()
	var shared: Array[CardDefinition] = screen.run.start_offer.shared.duplicate()
	var core: Array[CardDefinition] = screen.run.starter.core_cards.duplicate()
	var key_n: InputEventKey = InputEventKey.new()
	key_n.pressed = true
	key_n.keycode = KEY_N
	board._input(key_n)
	var new_offer: Array[StarterPackDefinition] = screen.run.start_offer.packs
	assert_array(new_offer).is_not_equal(old_packs)
	assert_object(new_offer[1]).is_same(old_packs[1])
	assert_array(screen.run.start_offer.shared).is_equal(shared)
	assert_array(screen.run.starter.core_cards).is_equal(core)
	assert_int(board.selected).is_equal(-1)
	assert_str(String(screen.run.start_setup.picked)).is_empty()
	assert_bool(board.staff.open_key.disabled).is_true()
	assert_str(board.staff._notice_title.text).is_equal("PICK  A  STARTER  PACK")
	for index: int in board.staff.crates.size():
		assert_object(board.staff.crates[index].pack).is_same(new_offer[index])
	assert_bool(key.disabled).is_true()
	assert_str(key.tooltip_text).is_equal("New packs used this run")
	assert_bool(board.new_packs()).is_false()
	var saved: RunSave = RunSave.from_dictionary(_save(), ContentLookup.new(screen.run.balance))
	assert_object(saved).is_not_null()
	assert_bool(saved.run.start_setup.packs_redrawn).is_true()
	assert_array(saved.run.start_offer.packs).is_equal(new_offer)


## The crates (v1.01): each shows its three items, name, key and family only (no strategy line,
## prices, coupon icons or example row, and no strategy tooltip). They stand on the stage side by
## side, clear of each other, the sign, NEW PACKS, the order sheet, the footer's ‹ STORE key and
## the hints, the items (at their sprites' size) above the label and the label inside the crate.
## A picked crate's PICKED tag sits inside it, clear of the label. NEW PACKS is mustard with ink
## words. Both at 1280x720 and 1920x1080.
func test_crates_show_items_name_and_family_only() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	board.show_page(2)
	var staff: StaffBuildPage = board.staff
	var key: Button = staff.new_packs_key
	var normal: StyleBoxFlat = key.get_theme_stylebox("normal") as StyleBoxFlat
	assert_object(normal.bg_color).is_equal(Palette.MUSTARD)
	assert_object(StartBoardKit.key_caption(key).get_theme_color("font_color")).is_equal(
		Palette.INK
	)
	board.pick(0)
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		await _resize(board, extent)
		var stage: Rect2 = _stage_rect(board)
		var keep_clear: Array[Rect2] = [
			(staff.get_node("Hints") as Control).get_global_rect(),
			board._back.get_global_rect(),
			staff.order.get_global_rect(),
			staff._notice.get_global_rect(),
			key.get_global_rect(),
		]
		assert_bool(stage.encloses(key.get_global_rect())).is_true()
		assert_bool(key.get_global_rect().intersects(staff._notice.get_global_rect())).is_false()
		var placed: Array[Rect2] = []
		for crate: PackCrate in staff.crates:
			var rect: Rect2 = crate.get_global_rect()
			assert_bool(stage.encloses(rect)).is_true()
			assert_str(crate.tooltip_text).is_empty()
			assert_object(crate.find_child("Example", true, false)).is_null()
			assert_object(crate.find_child("Hint", true, false)).is_null()
			for label: Node in crate.find_children("*", "Label", true, false):
				var text: String = (label as Label).text
				assert_bool(text.contains("€") or text.contains("✂")).is_false()
			var items: int = 0
			for child: Node in crate.get_children():
				if child.has_meta("card"):
					items += 1
					var item: Rect2 = (child as Control).get_global_rect()
					assert_bool(rect.encloses(item)).is_true()
					assert_bool(item.intersects(crate.label.get_global_rect())).is_false()
					assert_float((child as Control).size.x).is_equal(ItemView.SPRITE_SIZE.x)
			assert_int(items).is_equal(crate.pack.cards.size())
			assert_bool(rect.encloses(crate.label.get_global_rect())).is_true()
			var face: Rect2 = crate.label.get_global_rect()
			for part: String in ["Name", "Family"]:
				assert_bool(face.encloses(_caps(crate.label.get_node(part)))).is_true()
			var key_rect: Rect2 = (crate.label.get_node("Key") as Control).get_global_rect()
			assert_bool(face.encloses(key_rect)).is_true()
			assert_bool(_caps(crate.label.get_node("Name")).intersects(key_rect)).is_false()
			var tag: Control = crate.picked_tag()
			assert_bool(tag.visible).is_equal(crate.selected)
			assert_bool(rect.encloses(tag.get_global_rect())).is_true()
			assert_bool(tag.get_global_rect().intersects(face)).is_false()
			for other: Rect2 in keep_clear + placed:
				assert_bool(rect.intersects(other)).is_false()
			var first_sign: Control = crate.first_pick_sign()
			if first_sign != null:
				assert_bool(stage.encloses(first_sign.get_global_rect())).is_true()
				for other: Rect2 in keep_clear:
					assert_bool(first_sign.get_global_rect().intersects(other)).is_false()
			placed.append(rect)


## The time clock (v1.01): the IN card stands inside its slot with its IN word on its head, the
## slot and OPEN STORE apart and inside the clock, the clock on the stage. A punch lifts the card
## and puts it back where it was. Both at 1280x720 and 1920x1080.
func test_time_clock_parts_fit() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	board.show_page(2)
	var staff: StaffBuildPage = board.staff
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		await _resize(board, extent)
		var clock: Rect2 = staff._clock.get_global_rect()
		var slot: Rect2 = (staff._clock.get_node("CardSlot") as Control).get_global_rect()
		var card: Rect2 = staff._time_card.get_global_rect()
		var word: Rect2 = _caps(staff._time_card.get_node("In"))
		assert_bool(_stage_rect(board).encloses(clock)).is_true()
		assert_bool(clock.encloses(slot)).is_true()
		assert_bool(clock.encloses(staff.open_key.get_global_rect())).is_true()
		assert_bool(slot.intersects(staff.open_key.get_global_rect())).is_false()
		assert_bool(slot.encloses(card)).is_true()
		assert_bool(card.encloses(word)).is_true()
		assert_bool(clock.intersects(staff.order.get_global_rect())).is_false()
	var rest: float = staff._time_card.position.y
	var tween: Tween = staff.punch()
	tween.custom_step(1.0)
	assert_float(staff._time_card.position.y).is_equal(rest)


## The right column (feedback 2026-11-05, "elements not centred"): the order sheet and the time
## clock share the column's centre and width, COLUMN_MARGIN px from its sides, from each other and
## from the stage's foot. On the sheet the clip and paper are centred, and the count box, the
## ticks and the family cells end PAD px in from the paper's right side as the lines start PAD px
## in from its left. In the clock the header and the row (slot, OPEN STORE) keep equal insets,
## the title and the dial equal pads, the card is centred in its slot and the key's lines in the
## key. Both at 1280x720 and 1920x1080, picked and not.
func test_right_column_is_centred_and_aligned() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	board.show_page(2)
	var staff: StaffBuildPage = board.staff
	for selected: int in [-1, 1]:
		board.selected = selected
		board.refresh()
		for extent: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
			await _resize(board, extent)
			var stage: Rect2 = _stage_rect(board)
			var k: float = board._stage.scale.x
			var margin: float = StaffBuildPage.COLUMN_MARGIN * k
			var left: float = stage.position.x + StaffBuildPage.COLUMN_LEFT * k
			var sheet: Rect2 = staff.order.get_global_rect()
			var clock: Rect2 = staff._clock.get_global_rect()
			for rect: Rect2 in [sheet, clock]:
				assert_float(rect.position.x - left).is_equal_approx(margin, 0.5)
				assert_float(stage.end.x - rect.end.x).is_equal_approx(margin, 0.5)
			assert_float(clock.position.y - sheet.end.y).is_equal_approx(margin, 0.5)
			assert_float(stage.end.y - clock.end.y).is_equal_approx(margin, 0.5)
			_assert_sheet_aligned(staff.order, k)
			_assert_clock_aligned(staff, k)


## A lifted (picked) crate's dithered halo stays under the badge pins board (it spilled onto the
## board's frame).
func test_pick_halo_clears_the_pins_board() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	board.show_page(2)
	board.pick(0)
	var crate: PackCrate = board.staff.crates[0]
	var halo_top: float = crate.position.y + PackCrate.HALO_CENTRE_Y - PackCrate.HALO_RADIUS_Y
	var pins_bottom: float = 2.0 * StaffRoomArt.PIN_BOARD.end.y
	assert_float(halo_top).is_greater_equal(pins_bottom)


func _assert_sheet_aligned(order: OrderSheet, k: float) -> void:
	var sheet: Rect2 = order.get_global_rect()
	var paper: Rect2 = (order.get_node("Paper") as Control).get_global_rect()
	var clip: Rect2 = (order.get_node("Clip") as Control).get_global_rect()
	assert_float(clip.get_center().x).is_equal_approx(sheet.get_center().x, 0.5)
	assert_float(paper.get_center().x).is_equal_approx(sheet.get_center().x, 0.5)
	var pad: float = OrderSheet.PAD * k
	var right: float = paper.end.x - pad
	var count_box: Rect2 = (order.find_child("CountBox", true, false) as Control).get_global_rect()
	assert_float(count_box.end.x).is_equal_approx(right, 0.5)
	assert_float(order.equation.get_global_rect().position.x).is_equal_approx(
		paper.position.x + pad, 0.5
	)
	var ticks: int = 0
	for tick: Node in order.find_children("Tick*", "", true, false):
		ticks += 1
		assert_float((tick as Control).get_global_rect().end.x).is_equal_approx(right, 0.5)
	assert_int(ticks).is_greater(0)
	var cells: Array[Node] = order.find_children("Family*", "", true, false)
	assert_int(cells.size()).is_equal(3)
	var first: Rect2 = (cells[0] as Control).get_global_rect()
	var last: Rect2 = (cells[2] as Control).get_global_rect()
	assert_float(first.position.x).is_equal_approx(paper.position.x + pad, 0.5)
	assert_float(last.end.x).is_equal_approx(right, 0.5)
	assert_float(paper.end.y - last.end.y).is_equal_approx(pad, 0.5)
	_assert_sheet_header(order, k)
	if order.pack_rows != null:
		# The pack's highlight runs as far past the lines on the right as on the left.
		var rows: Rect2 = order.pack_rows.get_global_rect()
		assert_float(rows.end.x - right).is_equal_approx(
			paper.position.x + pad - rows.position.x, 0.5
		)
	# Each line's number, name, source and price share one centre line.
	var lines: int = 0
	while order.find_child("RowNumber%d" % lines, true, false) != null:
		var number: Control = order.find_child("RowNumber%d" % lines, true, false)
		var centre: float = number.get_global_rect().get_center().y
		for column: String in ["RowName", "RowSource", "RowPrice"]:
			var part: Control = order.find_child("%s%d" % [column, lines], true, false)
			if part != null:
				assert_float(part.get_global_rect().get_center().y).is_equal_approx(centre, 1.0)
		lines += 1
	assert_int(lines).is_greater(order.shown_cards.size())


## The count box clears the brass clip (they touched), and the title, the cart icon and the count
## share the box's centre line.
func _assert_sheet_header(order: OrderSheet, k: float) -> void:
	var clip: Rect2 = (order.get_node("Clip") as Control).get_global_rect()
	var box: Rect2 = (order.find_child("CountBox", true, false) as Control).get_global_rect()
	assert_float(box.position.y - clip.end.y).is_greater_equal(2.0 * k)
	var icon: Rect2 = (order.find_child("CountIcon", true, false) as Control).get_global_rect()
	var count: Rect2 = (order.find_child("Count", true, false) as Control).get_global_rect()
	assert_bool(box.encloses(icon)).is_true()
	assert_float(icon.get_center().y).is_equal_approx(box.get_center().y, 0.5)
	assert_float(absf(count.get_center().y - box.get_center().y)).is_less_equal(k)


func _assert_clock_aligned(staff: StaffBuildPage, k: float) -> void:
	var clock: Rect2 = staff._clock.get_global_rect()
	var header: Rect2 = (staff._clock.get_node("ClockHeader") as Control).get_global_rect()
	var inset: float = StaffBuildPage.HEADER_INSET * k
	var pad: float = StaffBuildPage.CLOCK_PAD * k
	assert_float(header.position.x - clock.position.x).is_equal_approx(inset, 0.5)
	assert_float(clock.end.x - header.end.x).is_equal_approx(inset, 0.5)
	assert_float(header.position.y - clock.position.y).is_equal_approx(inset, 0.5)
	var title: Rect2 = _caps(staff._clock.get_node("ClockTitle"))
	var dial: Rect2 = (staff._clock.get_node("Dial") as Control).get_global_rect()
	assert_float(title.position.x - header.position.x).is_equal_approx(pad, 0.5)
	assert_float(header.end.x - dial.end.x).is_equal_approx(pad, 0.5)
	assert_float(dial.get_center().y).is_equal_approx(header.get_center().y, 0.5)
	assert_float(absf(title.get_center().y - header.get_center().y)).is_less_equal(2.0 * k)
	var slot: Rect2 = (staff._clock.get_node("CardSlot") as Control).get_global_rect()
	var key: Rect2 = staff.open_key.get_global_rect()
	assert_float(slot.position.x - clock.position.x).is_equal_approx(inset + pad, 0.5)
	assert_float(clock.end.x - key.end.x).is_equal_approx(inset + pad, 0.5)
	assert_float(key.position.x - slot.end.x).is_equal_approx(pad, 0.5)
	for part: Rect2 in [slot, key]:
		assert_float(part.position.y - header.end.y).is_equal_approx(pad, 0.5)
		assert_float(clock.end.y - part.end.y).is_equal_approx(inset + pad, 0.5)
	var card: Rect2 = staff._time_card.get_global_rect()
	assert_float(card.get_center().x).is_equal_approx(slot.get_center().x, 0.5)
	assert_float(card.get_center().y).is_equal_approx(slot.get_center().y, 0.5)
	var caption: Rect2 = _caps(StartBoardKit.key_caption(staff.open_key))
	assert_float(absf(caption.get_center().x - key.get_center().x)).is_less_equal(2.0 * k)
	var line: Rect2 = staff.open_line.get_global_rect()
	assert_float(line.get_center().x).is_equal_approx(key.get_center().x, 0.5)
	assert_bool(key.encloses(caption)).is_true()
	assert_bool(key.encloses(line)).is_true()
	assert_bool(caption.intersects(line)).is_false()


## The pins card on the corkboard (mock-up v4 B_s2): an empty slot shows "+", the note says how
## many slots are free; a worn pin shows its face and rule, all inside the note and the badge.
func test_pins_card_shows_free_slots_and_the_worn_pin_rule() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	board.show_page(2)
	var staff: StaffBuildPage = board.staff
	assert_bool(screen.run.pins.is_empty()).is_true()
	var free: int = screen.run.balance.pin_slots
	assert_str(staff.pin_note.text).is_equal(
		"%d slot%s free · click to change" % [free, "" if free == 1 else "s"]
	)
	assert_bool(staff.pin_rule.visible).is_false()
	for face: PinFace in staff.pin_faces:
		assert_bool(face.is_empty()).is_true()
		assert_object(face.get_node_or_null("Plus")).is_not_null()
	var pin: PinDefinition = screen._catalogue.pins.back()
	board.open_pins()
	assert_bool(board._pins.toggle(pin)).is_true()
	board.back()
	assert_bool(staff.pin_faces[0].is_empty()).is_false()
	assert_str(staff.pin_rule.text).is_equal(pin.rule_text)
	assert_bool(staff.pin_rule.visible).is_true()
	var note: Control = staff._pins.get_node("Note")
	var badge: Control = staff._pins.get_node("Badge")
	for part: Control in [staff.pin_rule, staff.pin_note]:
		assert_bool(note.get_global_rect().encloses(part.get_global_rect())).is_true()
	(
		assert_bool(staff.pin_rule.get_global_rect().intersects(staff.pin_note.get_global_rect()))
		. is_false()
	)
	for face: PinFace in staff.pin_faces:
		assert_bool(badge.get_global_rect().encloses(face.get_global_rect())).is_true()
	assert_bool(note.get_global_rect().intersects(badge.get_global_rect())).is_false()


## #122 (moved from the title on 2026-11-05: the pins are chosen here only): the pins card opens
## the badge screen on the profile. Pressing an owned pin wears it and saves; a locked one says
## no; UNLOCK A RANDOM PIN spends the price and unlocks one locked pin (saved, with a capsule
## seed made for it); the card follows. Every page's rows fit the sheet without overlapping.
func test_badge_pins_wear_and_buy_from_the_pins_card() -> void:
	var screen: ShiftScreen = await _screen()
	var profile: ProfileState = screen.profile
	profile.coins = 14
	profile.unlocked_pins.append(&"recycle")  # Its milestone: the first run finished.
	assert_bool(screen.save_profile()).is_true()
	var board: StartBoard = screen._cart_reveal.board
	board.show_page(2)
	board.open_pins()
	var badge: BadgeScreen = board._pins
	assert_bool(badge.is_open()).is_true()
	var catalogue: CatalogueDefinition = screen._catalogue
	var count: int = catalogue.pins.size()
	var rows: Array[PinRow] = badge.rows()
	assert_int(rows.size()).is_equal(count)
	assert_int(rows[0].state()).is_equal(PinRow.State.OWNED)
	assert_int(rows[1].state()).is_equal(PinRow.State.LOCKED)
	var sheet: Rect2 = badge.sheet().get_global_rect()
	assert_bool(_stage_rect(board).encloses(sheet)).is_true()
	# #132: the rows show BadgeScreen.PAGE_ROWS at a time; every page's rows fit the sheet.
	assert_int(badge.page_count()).is_equal(ceili(float(count) / BadgeScreen.PAGE_ROWS))
	for page: int in range(badge.page_count()):
		badge.show_page(page)
		var shown: Array[Control] = [badge.badge(), badge.buy_plate()]
		for child: Node in badge.sheet().find_children("*PrevPage*", "", true, false):
			shown.append(child as Control)
		for row: PinRow in rows:
			if row.visible:
				shown.append(row)
		assert_int(shown.size()).is_between(3, 3 + BadgeScreen.PAGE_ROWS)
		for control: Control in shown:
			assert_bool(sheet.encloses(control.get_global_rect())).is_true()
		for index: int in range(1, shown.size()):
			for other: int in range(index):
				var rect: Rect2 = shown[other].get_global_rect()
				assert_bool(rect.intersects(shown[index].get_global_rect())).is_false()
	badge.show_page(0)
	rows[1].pressed.emit()
	assert_array(SaveService.new(_folder).load_profile().worn_pins).is_empty()
	rows[0].pressed.emit()
	assert_int(rows[0].state()).is_equal(PinRow.State.WORN)
	assert_array(SaveService.new(_folder).load_profile().worn_pins).is_equal([rows[0].pin.id])
	assert_array(screen.run.pins).is_equal([rows[0].pin])
	assert_str(board.staff.pin_faces[0].letters()).is_equal(rows[0].pin.face_text)
	badge.buy_plate().pressed.emit()
	var saved: ProfileState = SaveService.new(_folder).load_profile()
	assert_int(saved.coins).is_equal(14 - screen._balance.pin_coin_price)
	assert_int(saved.unlocked_pins.size()).is_equal(2)
	assert_bool(saved.has_capsule_seed).is_true()
	for row: PinRow in rows:
		if row.pin.id == saved.unlocked_pins[1]:
			assert_int(row.state()).is_equal(PinRow.State.OWNED)
	assert_bool(badge.buy_plate().disabled).is_true()  # Under the price now.
	badge.back_plate().pressed.emit()
	assert_bool(badge.is_open()).is_false()
	assert_int(board.page).is_equal(2)


## The capitals of pixel words (their label's box also holds the font's empty ascent), in global px.
func _caps(pixel: Label) -> Rect2:
	var font: Font = ArtStyle.pixel_display_font()
	var cap_top: float = font.get_ascent(ArtStyle.PIXEL_TEXT_SIZE) - ArtStyle.PIXEL_CAP_HEIGHT
	var factor: Vector2 = pixel.get_global_transform().get_scale()
	var local: Vector2 = Vector2(StartBoardKit.text_width(pixel.text, 1), ArtStyle.PIXEL_CAP_HEIGHT)
	return Rect2(pixel.global_position + Vector2(0, cap_top) * factor, local * factor)


func _resize(board: StartBoard, extent: Vector2) -> void:
	board.set_anchors_preset(Control.PRESET_TOP_LEFT)
	board.size = extent
	board._resize()
	await get_tree().process_frame


func _stage_rect(board: StartBoard) -> Rect2:
	return Rect2(board._stage.global_position, ShiftStage.SIZE * board._stage.scale)


func _screen() -> ShiftScreen:
	var screen: ShiftScreen = auto_free(SCREEN.instantiate())
	add_child(screen)
	await get_tree().process_frame
	screen.profile.set_reduced_motion(true)
	screen.save_profile()
	screen.start_new_run(SEED, true, true)
	assert_bool(screen._cart_reveal.board.lock_in()).is_true()
	return screen


func _save() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(_folder.path_join(SaveService.RUN_FILE)))


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
