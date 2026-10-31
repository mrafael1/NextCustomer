extends GdUnitTestSuite
## The TOY MACHINES' layout (#121, mock-up toy_machines_121_v2.html; memory: UI tests check
## on-screen geometry): with six machines every machine, its sign, its figurine and its floor
## plate are inside the 1280x720 window, no machine's click area overlaps another's, every
## plate's text fits its plate, the figurines stand over their signs clear of the board and the
## LEDs, and the LEDs, the board, the LED strip and both buttons are inside and clear of the
## machines; the strip sits between the floor plates and the buttons. A hovered machine's lineup
## is inside the screen, left of the doors, clear of every machine's click area and of the LEDs,
## and takes the board's place. Three machines centre in 0..1000. Saves and logs go to a
## temporary folder.

const Kit := preload("res://tests/ui/toy_test_kit.gd")
## The doors' left edge (ToyExitArt.DOORS_RECT less its frame, in canvas px).
const DOORS_LEFT := 1040.0

var _folder: String = ""
var _window_size: Vector2i


func before_test() -> void:
	_folder = "user://test_toys_layout_%d" % Time.get_ticks_usec()
	Kit.event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(Kit.SCREEN_RECT.size)


func after_test() -> void:
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	Kit.remove(_folder)


func test_six_machines_fit_the_screen_without_overlaps() -> void:
	var screen: ToyMachinesScreen = await _open(Kit.profile(2, 4, _partial()))
	var machines: Array[ToyMachineView] = screen.machines()
	assert_int(machines.size()).is_equal(6)
	var hits: Array[Rect2] = []
	for machine: ToyMachineView in machines:
		var rect: Rect2 = Rect2(machine.global_position, ToyMachineView.SIZE)
		_assert_inside(rect, "machine")
		var hit: Rect2 = machine.hit_rect()
		_assert_inside(hit, "click area")
		for other: Rect2 in hits:
			assert_bool(hit.intersects(other)).is_false()
		hits.append(hit)
		# The sign and the floor plate are inside the click area's column; no figurine on top.
		var sign_rect: Rect2 = machine.sign_rect()
		_assert_inside(sign_rect, "sign")
		_assert_fits(machine.part("sign_text") as PixelLine, machine.part("sign") as ToyPlate)
		assert_float(hit.position.y).is_equal_approx(sign_rect.position.y, 0.5)
		assert_object(machine.part("topper")).is_null()
		var floor_plate: ToyPlate = machine.part("floor") as ToyPlate
		var floor_rect: Rect2 = floor_plate.get_global_rect()
		_assert_inside(floor_rect, "floor plate")
		assert_float(floor_rect.position.y).is_greater_equal(rect.end.y)
		assert_float(absf(floor_rect.get_center().x - rect.get_center().x)).is_less(4.0)
		_assert_fits(machine.part("floor_text") as PixelLine, floor_plate)
		# The board and the LEDs stay clear of the signs.
		for part: Rect2 in [_board_rect(screen), _chip_rects(screen)[0], _chip_rects(screen)[1]]:
			assert_bool(sign_rect.intersects(part)).override_failure_message(str(part)).is_false()
	assert_str(machines[0].floor_text()).is_equal("1 OF 2 LEFT")
	assert_str(machines[1].floor_text()).is_equal(ToyMachineView.SOLD_OUT_TEXT)
	assert_str(machines[3].floor_text()).is_equal("5 OF 8 LEFT")
	assert_str((machines[3].part("sign_text") as PixelLine).text()).is_equal("FRUIT & VEG")
	# LEDs, board, strip and buttons: inside, clear of the machines' click areas.
	var parts: Array[Rect2] = _chip_rects(screen)
	(
		parts
		. append_array(
			[
				_board_rect(screen),
				screen.strip().get_global_rect(),
				Kit.rect(screen.shelf_button()),
				Kit.rect(screen.done_button()),
			]
		)
	)
	for part: Rect2 in parts:
		_assert_inside(part, str(part))
		for hit: Rect2 in hits:
			assert_bool(part.intersects(hit)).override_failure_message(str(part)).is_false()
	assert_bool(parts[0].intersects(parts[1])).is_false()
	assert_bool(parts[4].intersects(parts[5])).is_false()
	assert_str(screen.coins_text()).is_equal("2")
	assert_str(screen.figurines_text()).is_equal("9/30")
	# The machines stand left of the doors.
	assert_float(hits[-1].end.x).is_less_equal(DOORS_LEFT)


## The strip sits between the floor plates and the buttons, inside the screen; its rows fit it.
func test_the_led_strip_sits_between_the_floor_plates_and_the_buttons() -> void:
	var profiles: Array[ProfileState] = [
		Kit.profile(2, 4, _partial()), Kit.profile(0, 4), Kit.profile(5, 9, Kit.full_counts())
	]
	var kinds: Array[ToyMachinesScreen.Strip] = [
		ToyMachinesScreen.Strip.HINT,
		ToyMachinesScreen.Strip.BROKE,
		ToyMachinesScreen.Strip.COMPLETE
	]
	for index: int in profiles.size():
		var screen: ToyMachinesScreen = await _open(profiles[index])
		assert_int(screen.strip_kind()).is_equal(kinds[index])
		var strip: Rect2 = screen.strip().get_global_rect()
		_assert_inside(strip, "strip")
		var floor_bottom: float = 0.0
		for machine: ToyMachineView in screen.machines():
			floor_bottom = maxf(floor_bottom, machine.part("floor").get_global_rect().end.y)
		assert_float(strip.position.y).is_greater_equal(floor_bottom)
		var buttons_top: float = minf(
			Kit.rect(screen.shelf_button()).position.y, Kit.rect(screen.done_button()).position.y
		)
		assert_float(strip.end.y).is_less_equal(buttons_top)
		assert_float(absf(strip.get_center().x - Kit.SCREEN_RECT.size.x / 2.0)).is_less(4.0)
		for row: PixelLine in screen.strip().rows():
			var row_rect: Rect2 = Rect2(row.global_position, row.size)
			assert_bool(strip.encloses(row_rect)).override_failure_message(str(row_rect)).is_true()


## The buttons' captions fit their plates; DONE's chevron stays on the plate.
func test_the_buttons_captions_fit_their_plates() -> void:
	var screen: ToyMachinesScreen = await _open(Kit.profile(1, 1))
	for plate: MenuPlate in [screen.shelf_button(), screen.done_button()] as Array[MenuPlate]:
		var face: Rect2 = Rect2(plate.global_position, plate.face_size())
		var caption: Label = plate.caption_label()
		var text: Rect2 = _caption_ink(caption)
		(
			assert_bool(face.encloses(text))
			. override_failure_message("%s %s in %s" % [caption.text, text, face])
			. is_true()
		)
		for child: Node in caption.get_children():
			var chevron: Control = child as Control
			assert_bool(face.encloses(chevron.get_global_rect())).is_true()
	assert_str(screen.done_button().caption).is_equal(ToyMachinesScreen.DONE_TEXT)


## Hovering a machine puts its lineup in the board's place: inside the screen, left of the doors,
## clear of every machine's click area and the LEDs, its minis on its plate (owned in colour).
## An OUT OF ORDER machine shows none; nor does the reveal.
func test_the_lineup_takes_the_boards_place() -> void:
	var profile: ProfileState = Kit.profile(3, 4, _partial())
	var screen: ToyMachinesScreen = await _open(profile)
	var hits: Array[Rect2] = []
	for machine: ToyMachineView in screen.machines():
		hits.append(machine.hit_rect())
	for machine: ToyMachineView in screen.machines():
		machine._on_hover(true)
		var lineup: ToyLineup = screen.lineup()
		var aisle: AisleDefinition = machine.aisle()
		assert_bool(lineup.visible).is_true()
		assert_bool(screen.board().visible).is_false()
		var strip: Rect2 = lineup.strip_rect()
		_assert_inside(strip, "lineup")
		assert_float(strip.end.x).is_less_equal(DOORS_LEFT)
		for hit: Rect2 in hits:
			assert_bool(strip.intersects(hit)).override_failure_message(str(strip)).is_false()
		for chip: Rect2 in _chip_rects(screen):
			assert_bool(strip.intersects(chip)).is_false()
		var face: Rect2 = Rect2(lineup.global_position, lineup.size)
		# The title on the card's tomato band, the minis under it.
		var band: Rect2 = Rect2(
			face.position + Vector2(1, 1) * ArtStyle.ART_SCALE,
			Vector2(face.size.x - 2 * ArtStyle.ART_SCALE, ToyExitArt.CARD_BAND * ArtStyle.ART_SCALE)
		)
		var title: Rect2 = Rect2(lineup.title_line().global_position, lineup.title_line().size)
		assert_bool(band.encloses(title)).override_failure_message(str(title)).is_true()
		assert_str(lineup.title_line().text()).is_equal(
			ToyLineup.TITLE_TEXT % aisle.display_name.to_upper()
		)
		assert_int(lineup.minis().size()).is_equal(aisle.capsule_cards.size())
		var owned: int = 0
		for index: int in lineup.minis().size():
			assert_bool(face.encloses(lineup.minis()[index].get_global_rect())).is_true()
			owned += 1 if lineup.is_owned(index) else 0
		assert_int(owned).is_equal(_partial().get(aisle.id, 0))
		machine._on_hover(false)
		assert_bool(lineup.visible).is_false()
		assert_bool(screen.board().visible).is_true()
	# The reveal hides it.
	screen.machines()[0]._on_hover(true)
	screen.machines()[0]._gui_input(Kit.left_click())
	assert_bool(screen.reveal().visible).is_true()
	assert_bool(screen.lineup().visible).is_false()
	await await_idle_frame()


## The row holds FULL_ROW machines at most (a seventh would stand on the doors): the live
## balance keeps within it.
func test_the_balance_fits_one_row() -> void:
	assert_int(Kit.balance().aisles.size()).is_less_equal(ToyMachinesScreen.FULL_ROW)
	var last: float = (
		ToyMachinesScreen.row_x0(ToyMachinesScreen.FULL_ROW)
		+ (ToyMachinesScreen.FULL_ROW - 1) * ToyMachinesScreen.MACHINE_PITCH
		+ ToyMachineView.SIZE.x
	)
	assert_float(last).is_less_equal(DOORS_LEFT)


## The buttons' hover tick sits the mock-up's 7 art px left of the plate at rest.
func test_the_buttons_tick_sits_left_of_the_plate() -> void:
	var screen: ToyMachinesScreen = await _open(Kit.profile(1, 1))
	for plate: MenuPlate in [screen.shelf_button(), screen.done_button()] as Array[MenuPlate]:
		plate.marked = true
		await await_idle_frame()
		assert_bool(plate.tick().visible).is_true()
		assert_float(plate.tick().position.x).is_equal(-ToyMachinesScreen.BUTTON_TICK_LEFT)
		assert_float(plate.tick().get_global_rect().position.x).is_greater_equal(0.0)


func test_three_machines_centre_left_of_the_doors() -> void:
	var balance: BalanceDefinition = Kit.balance_with_aisles(3)
	var screen: ToyMachinesScreen = await _open(Kit.profile(1, 1), balance)
	var machines: Array[ToyMachineView] = screen.machines()
	assert_int(machines.size()).is_equal(3)
	var left: float = machines[0].global_position.x
	var right: float = machines[2].global_position.x + ToyMachineView.SIZE.x
	assert_float((left + right) / 2.0).is_equal_approx(500.0, 2.0)
	assert_float(fmod(left, 2.0)).is_equal(0.0)
	assert_float(machines[1].global_position.x - left).is_equal(ToyMachinesScreen.MACHINE_PITCH)
	assert_str(screen.figurines_text()).is_equal("0/7")
	# One lamp over each machine.
	assert_int(screen.lamps().size()).is_equal(3)
	for index: int in machines.size():
		var lamp: Rect2 = screen.lamps()[index].get_global_rect()
		assert_float(lamp.get_center().x).is_equal_approx(
			machines[index].global_position.x + ToyMachineView.SIZE.x / 2.0, 0.5
		)


## No player-facing text says "gacha", in the copy or in any label in any state.
func test_no_gacha_anywhere() -> void:
	for text: String in ToyMachinesScreen.copy():
		assert_bool(text.to_lower().contains("gacha")).override_failure_message(text).is_false()
	var counts: Array[Dictionary] = [{}, {&"pantry": 2}, Kit.full_counts()]
	for coins: int in [0, 2]:
		for collected: Dictionary in counts:
			var screen: ToyMachinesScreen = await _open(Kit.profile(coins, 2, collected))
			screen.machines()[0]._on_hover(true)
			screen._open_shelf()
			for label: Label in Kit.labels(screen):
				assert_bool(label.text.to_lower().contains("gacha")).is_false()


## The mock-up's partial collection: 9 of the 30 figurines.
static func _partial() -> Dictionary:
	return {&"cold_cases": 1, &"pantry": 2, &"household": 1, &"fruit_and_veg": 3, &"bakery": 2}


func _assert_inside(rect: Rect2, what: String) -> void:
	(
		assert_bool(Kit.SCREEN_RECT.encloses(rect))
		. override_failure_message("%s %s" % [what, rect])
		. is_true()
	)


## The line's words lie on the plate's face, above its ledge, inside its outline.
func _assert_fits(line: PixelLine, plate: ToyPlate) -> void:
	var art: float = ArtStyle.ART_SCALE
	var face: Rect2 = plate.get_global_rect()
	face = Rect2(
		face.position + Vector2(2, 1) * art, face.size - Vector2(4, ToyPlate.LEDGE_ROWS + 1) * art
	)
	var text: Rect2 = Rect2(line.global_position, line.size)
	(
		assert_bool(face.encloses(text))
		. override_failure_message("%s %s in %s" % [line.text(), text, face])
		. is_true()
	)


## A pixel caption's capitals on screen: from its ink's left (past Pixelify's left bearing),
## its words' width, from its cap top down the capitals' height.
func _caption_ink(caption: Label) -> Rect2:
	var font: Font = ArtStyle.pixel_display_font()
	var cap_top: float = font.get_ascent(ArtStyle.PIXEL_TEXT_SIZE) - ArtStyle.PIXEL_CAP_HEIGHT
	var text_scale: float = caption.scale.x
	var art: float = ArtStyle.ART_SCALE
	return Rect2(
		caption.global_position + Vector2(PixelLine.LEFT_BEARING, cap_top) * text_scale,
		Vector2(
			PixelLine.word_width(caption.text, roundi(text_scale / art)),
			ArtStyle.PIXEL_CAP_HEIGHT * text_scale
		)
	)


func _board_rect(screen: ToyMachinesScreen) -> Rect2:
	var board: Rect2 = screen.board().get_global_rect()
	var art: float = ArtStyle.ART_SCALE
	var top: float = ToyExitArt.BOARD_RECT.position.y - ToyExitArt.BOARD_LAYER.position.y
	return Rect2(board.position + Vector2(0, top * art), board.size - Vector2(0, top * art))


func _chip_rects(screen: ToyMachinesScreen) -> Array[Rect2]:
	return [screen.coins_chip().get_global_rect(), screen.figurines_chip().get_global_rect()]


func _open(profile: ProfileState, balance: BalanceDefinition = null) -> ToyMachinesScreen:
	var used: BalanceDefinition = balance if balance != null else Kit.balance()
	var counter: CapsuleCounter = CapsuleCounter.new(
		profile, SaveService.new(_folder), used, Kit.event_log(), false, true
	)
	var screen: ToyMachinesScreen = ToyMachinesScreen.new()
	add_child(screen)
	auto_free(screen)
	screen.open(counter, used)
	for frame: int in range(3):
		await await_idle_frame()
	return screen
