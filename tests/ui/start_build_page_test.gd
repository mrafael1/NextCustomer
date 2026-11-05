extends GdUnitTestSuite
## Start v4 B page 2, the staff room (full build plan 7.2, reworked 2026-11-05): the pack-line
## highlight on the order sheet (the cart overview: the trolley is gone), the waiting state before
## a pick, the sign naming the pick, NEW PACKS, the crates' strategy line and example slip, the
## time clock's lines and the pins card.

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


## Each crate's strategy line and example slip (pack data) stay inside the crate's label and on
## the stage, the slips apart from each other, from the footer's ‹ STORE key and the hints; the
## slip names the example's total and holds its row's items. Both at 1280x720 and 1920x1080.
func test_crate_strategy_and_example_fit() -> void:
	var screen: ShiftScreen = await _screen()
	var board: StartBoard = screen._cart_reveal.board
	board.show_page(2)
	for extent: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		board.set_anchors_preset(Control.PRESET_TOP_LEFT)
		board.size = extent
		board._resize()
		await get_tree().process_frame
		var stage: Rect2 = _stage_rect(board)
		var hints: Rect2 = (board.staff.get_node("Hints") as Control).get_global_rect()
		var slips: Array[Rect2] = []
		for crate: PackCrate in board.staff.crates:
			assert_str(crate.hint.text).is_equal(crate.pack.hint_text)
			assert_int(crate.hint.get_visible_line_count()).is_equal(crate.hint.get_line_count())
			var label: Rect2 = (crate.hint.get_parent() as Control).get_global_rect()
			assert_bool(label.encloses(crate.hint.get_global_rect())).is_true()
			assert_object(crate.slip).is_not_null()
			var slip: Rect2 = crate.slip.get_global_rect()
			assert_bool(stage.encloses(slip)).is_true()
			assert_str(crate.slip.tooltip_text).is_equal(crate.pack.example_text)
			var total: Label = crate.slip.get_node("Total")
			assert_str(total.text).contains(str(crate.pack.example_total))
			var steps: int = 0
			for child: Node in crate.slip.get_children():
				if child.has_meta("card"):
					steps += 1
					assert_bool(slip.encloses((child as Control).get_global_rect())).is_true()
			assert_int(steps).is_equal(crate.pack.example_cards.size())
			assert_bool(slip.intersects(board._back.get_global_rect())).is_false()
			assert_bool(slip.intersects(hints)).is_false()
			for other: Rect2 in slips:
				assert_bool(slip.intersects(other)).is_false()
			slips.append(slip)


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
