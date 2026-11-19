extends GdUnitTestSuite
## Polish audit batch 2, group "type" (2026-11-14), at 1280x720 and 1920x1080 where the layout
## differs: the display font's closed capital B; the figurine book's consistency (a group's
## header once, then CONT.; FIGURINES on the count LED; Bent lolly's rule at the first tier; the
## no-rule line at the rules' line pitch); the title's and the pause's sub-lines in hard pixel
## capitals on their plates; the swap window's ghost (full size, above the pointer), the drop
## box's name and price and the aisle plates over the offers; Esc on the start screen opening the
## options with BACK TO TITLE. The real saves and logs are never touched.

const SCREEN := preload("res://ui/shift_screen.tscn")
const TITLE := "res://ui/title_screen.tscn"
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]
const SEED := 20261114
const STEP := 1.0 / 60.0
const Kit := preload("res://tests/ui/toy_test_kit.gd")

var _folder: String = ""
var _window: Vector2i


func before_test() -> void:
	_folder = "user://polish_batch_two_type_test_%d" % Time.get_ticks_usec()
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_event_log().use_folder(_folder)
	_window = get_tree().root.size


func after_test() -> void:
	get_tree().paused = false
	get_tree().root.size = _window
	await get_tree().process_frame
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file))
		DirAccess.remove_absolute(_folder)


## b-glyph: Pixelify's B is closed (fonts/PixelifySans-CHANGES.txt): its outline and two
## counters are three contours (the stock B was an outline and one open counter, so it read as
## G), with square left corners, in the hard pixel font and the MSDF display font alike.
func test_the_display_font_closes_its_b() -> void:
	var server: TextServer = TextServerManager.get_primary_interface()
	for font: Font in [ArtStyle.pixel_display_font(), ArtStyle.DISPLAY_FONT] as Array[Font]:
		var rid: RID = font.get_rids()[0]
		var size: int = ArtStyle.PIXEL_TEXT_SIZE
		var glyph: int = server.font_get_glyph_index(rid, size, "B".unicode_at(0), 0)
		var outline: Dictionary = server.font_get_glyph_contours(rid, size, glyph)
		assert_int((outline["contours"] as PackedInt32Array).size()).is_equal(3)
		# Square left corners: the outline's leftmost points reach its top and its bottom.
		var points: PackedVector3Array = outline["points"]
		var low: Vector2 = Vector2(INF, INF)
		var high: Vector2 = Vector2(-INF, -INF)
		for point: Vector3 in points:
			low = low.min(Vector2(point.x, point.y))
			high = high.max(Vector2(point.x, point.y))
		var corners: Array[Vector2] = []
		for point: Vector3 in points:
			if is_equal_approx(point.x, low.x):
				corners.append(Vector2(point.x, point.y))
		(
			assert_bool(corners.any(func(c: Vector2) -> bool: return is_equal_approx(c.y, low.y)))
			. is_true()
		)
		(
			assert_bool(corners.any(func(c: Vector2) -> bool: return is_equal_approx(c.y, high.y)))
			. is_true()
		)


## book: on the first spread BAKERY's header shows once with its count, its next page reads
## BAKERY CONT.; the count LED says FIGURINES (the toy screen's noun); Bread's no-rule line is
## laid out at the rules' line pitch; Bent lolly's rule keeps the first tier. Every header and
## the LED sit inside the book at both sizes.
func test_the_figurine_book_reads_consistently() -> void:
	for window: Vector2i in SIZES:
		get_tree().root.size = window
		var profile: ProfileState = Kit.profile(0, 0)
		var book: FigurineBook = await _book(profile)
		var first: PixelLine = book.header(0)
		var second: PixelLine = book.header(1)
		assert_str(first.text()).starts_with("BAKERY ")
		assert_str(first.text()).is_not_equal("BAKERY " + FigurineBook.CONT_TEXT)
		assert_str(second.text()).is_equal("BAKERY " + FigurineBook.CONT_TEXT)
		assert_str(book.leds()[0].text()).ends_with(" " + FigurineBook.FIGURINES_TEXT)
		var screen: Rect2 = book.get_viewport().get_visible_rect()
		for line: Control in [first, second, book.leds()[0]] as Array[Control]:
			assert_bool(screen.encloses(line.get_global_rect())).is_true()
		var plain: GlyphLabel = null
		var ruled: GlyphLabel = null
		for card: BookCard in book.cards():
			var label: GlyphLabel = card.description() as GlyphLabel
			assert_object(label).override_failure_message(str(card.entry().card.id)).is_not_null()
			if card.entry().card.id == &"bread":
				plain = label
			elif ruled == null and card.entry().card.id == &"crackers":
				ruled = label
		assert_object(plain).is_not_null()
		assert_str(plain.text).is_equal(BookCard.PLAIN_TEXT)
		assert_float(plain.pitch()).is_equal(ruled.pitch())
		assert_float(plain.pitch()).is_equal(float(BookCard.TEXT_TIERS[0].y))
		assert_object(plain.color()).is_equal(Palette.MUTED_INK)
	var lolly: CardDefinition = load("res://data/cards/bent_lolly.tres")
	var turned: int = 0
	var book_now: FigurineBook = await _book(Kit.profile(0, 0))
	while BookCard.tier_of(lolly) < 0 and turned < book_now.spread_count():
		book_now.turn(1)
		book_now.page_turn().finish()
		await _frames(1)
		turned += 1
	assert_int(BookCard.tier_of(lolly)).is_equal(0)


## body-font: the primary plate's sub-line is hard pixel capitals and digits (a PixelLine, its
## cap top at SUB_AT), inside the plate's face for every line the title and the pause print (the
## longest pause phase too), paper when lit, pale tomato when not.
func test_the_sub_lines_are_pixel_capitals_on_their_plates() -> void:
	var balance: BalanceDefinition = load("res://data/balance/balance.tres")
	var lines: Array[String] = [
		TitleMenu.length_line(balance),
		"SHIFT 16/16",
		"SHIFT 16/16 · PRIZE PICK",
		"SHIFT 16/16 · COUNT-UP",
		"SHIFT 16/16 · PLANNING",
	]
	for window: Vector2i in SIZES:
		get_tree().root.size = window
		var title: TitleScreen = await _title()
		var primary: MenuPlate = title.menu().plate(TitleMenu.Entry.PRIMARY)
		await _check_sub_lines(primary, lines, str(window))
		var screen: ShiftScreen = await _shift()
		var pause: PauseMenu = screen._pause.pause
		pause.still = true
		screen._pause.open()
		await _frames(2)
		await _check_sub_lines(pause.plate(PauseMenu.Entry.RESUME), lines, "pause %s" % window)
		screen._pause.close()


func _check_sub_lines(plate: MenuPlate, lines: Array[String], case: String) -> void:
	var line: PixelLine = plate.sub_line_node()
	for sentence: String in lines:
		plate.sub_line = sentence
		await _frames(1)
		assert_bool(line.visible).is_true()
		assert_str(line.text()).is_equal(sentence)
		assert_vector(line.position).is_equal(MenuPlate.SUB_AT)
		var face: Rect2 = plate.face().get_global_rect()
		var rect: Rect2 = line.get_global_rect()
		(
			assert_bool(face.encloses(rect))
			. override_failure_message("%s %s" % [case, sentence])
			. is_true()
		)
		# Under the caption's band.
		assert_float(line.position.y).is_greater_equal(MenuPlate.PRIMARY_CAPTION_RECT.end.y)
	plate.marked = true
	plate.sub_line = lines[0]
	assert_object(_ink_of(line)).is_equal(Palette.PAPER)
	plate.marked = false
	plate.sub_line = lines[0]
	assert_object(_ink_of(line)).is_equal(Palette.TOMATO_PALE)


## swap: a card held over the basket stays full size (an integer scale), centred on the pointer
## and standing above it, its foot above the items, inside the window; the drop box under it
## names the regular it would replace and its price on its gold foot band; each open swap
## booster has its aisle plate over its fan, clear of the cards' tabs, the title tab and the close
## key. At both sizes, every piece stays inside the board on screen.
func test_the_swap_window_ghost_box_and_plates() -> void:
	for window: Vector2i in SIZES:
		var page: BoosterPage = await _page(2)
		var board: StartBoard = _board(page)
		board.set_anchors_preset(Control.PRESET_TOP_LEFT)
		board.size = Vector2(window)
		board._resize()
		_stocked(page)
		var swap: SwapWindow = page.swap
		assert_bool(swap.open_window(false)).is_true()
		for bi: int in swap.boosters.size():
			swap.open_booster(bi, "key")
		_run(page, 3.0)
		var frame: Rect2 = board.get_global_rect()
		var plates: Array[Rect2] = []
		for b: BoosterOpening in swap.boosters:
			var plate: Rect2 = SwapWindowDraw.aisle_plate_rect(page, b)
			assert_float(plate.size.x).is_greater(0.0)
			assert_bool(SwapWindowDraw.RECT.encloses(plate)).is_true()
			assert_bool(frame.encloses(_on_screen(page, plate))).is_true()
			var middle: Vector2 = SwapWindowDraw.fan_centre(b.index - SwapWindow.INDEX0, 1)
			var tab_top: float = middle.y - BoosterArt.CH / 2.0 - 6.0
			assert_float(plate.end.y).is_less_equal(tab_top)
			assert_bool(plate.intersects(SwapWindowDraw.CLOSE_RECT)).is_false()
			assert_bool(plate.intersects(_title_tab())).is_false()
			plates.append(plate)
		assert_bool(plates[0].intersects(plates[1])).is_false()
		var piece: SwapPiece = _first_card(swap)
		var slot: int = 1
		var target: Vector2 = SwapWindowDraw.item_centre(slot)
		_move(page, piece.pos)
		page.advance(0.0)
		page._gui_input(_button(piece.pos, true))
		_move(page, (piece.pos + target) / 2.0)
		page.advance(STEP)
		_move(page, target)
		page.advance(STEP)
		assert_object(swap.held).is_same(piece)
		assert_int(swap.hover_slot).is_equal(slot)
		var pose: Dictionary = swap.pose(piece)
		assert_float(pose.sc as float).is_equal(1.0)
		var at: Vector2 = pose.pos
		var card: Rect2 = Rect2(
			at - Vector2(BoosterArt.CW, BoosterArt.CH) / 2.0, Vector2(BoosterArt.CW, BoosterArt.CH)
		)
		assert_float(at.x).is_equal(roundf(page.mouse.x))
		assert_float(card.end.y).is_less_equal(SwapWindowDraw.ITEM_TOP - 2.0)
		assert_float(card.end.y).is_less(page.mouse.y)
		assert_bool(SwapWindowDraw.RECT.encloses(card)).is_true()
		var band: Rect2 = SwapWindowDraw.target_band_rect(slot)
		assert_bool(SwapWindowDraw.slot_rect(slot).encloses(band)).is_true()
		assert_bool(card.intersects(band)).is_false()
		assert_bool(frame.encloses(_on_screen(page, band))).is_true()
		for regular: CardDefinition in page.run.starter.core_cards:
			var words: float = ArtPen.pix_width(regular.display_name.to_upper())
			assert_float(words).is_less_equal(band.size.x - 8.0)
		page._gui_input(_button(target, false))
		page.advance(0.0)


## keys: Esc on the start screen's page 1 opens the options (the board paused under them) with
## BACK TO TITLE on the sheet, right of DONE and ESC, the sheet inside the screen; Up from no
## marker marks BACK TO TITLE and shows its hint; Esc closes them and the board takes its keys
## again (1 rolls the shutter up); Enter on BACK TO TITLE leaves for the title.
func test_escape_on_the_start_screen_opens_the_options_with_back_to_title() -> void:
	for window: Vector2i in SIZES:
		get_tree().root.size = window
		var screen: ShiftScreen = await _screen()
		screen._start_choice.changes_scene = false
		var board: StartBoard = screen._cart_reveal.board
		var options: OptionsCard = screen._pause.options
		var left: Array[int] = [0]
		board.back_to_title.connect(func() -> void: left[0] += 1)
		get_tree().root.push_input(_key(KEY_ESCAPE), true)
		await _frames(2)
		assert_bool(options.is_open()).is_true()
		assert_bool(get_tree().paused).is_true()
		var leave: MenuPlate = options.leave_plate()
		assert_str(leave.caption).is_equal(OptionsCard.LEAVE_CAPTION)
		var sheet: Rect2 = options.sheet().get_global_rect()
		var case: String = str(window)
		(
			assert_bool(options.get_viewport_rect().encloses(sheet))
			. override_failure_message(case)
			. is_true()
		)
		(
			assert_bool(sheet.encloses(leave.get_global_rect()))
			. override_failure_message(case)
			. is_true()
		)
		(
			assert_bool(leave.get_global_rect().intersects(options.done_plate().get_global_rect()))
			. is_false()
		)
		(
			assert_bool(leave.get_global_rect().intersects(options.esc_label().get_global_rect()))
			. is_false()
		)
		get_tree().root.push_input(_key(KEY_UP), true)
		assert_object(options.marked()).is_same(leave)
		assert_str(options.hint_label().text).is_equal(OptionsCard.LEAVE_HINT)
		get_tree().root.push_input(_key(KEY_ESCAPE), true)
		assert_bool(options.is_open()).is_false()
		assert_bool(get_tree().paused).is_false()
		assert_int(left[0]).is_equal(0)
		assert_object(screen._cart_reveal.board).is_same(board)
		get_tree().root.push_input(_key(KEY_ENTER), true)
		assert_int(board.store.roulette.phase).is_equal(AisleRoulette.Phase.DEAL)
		get_tree().root.push_input(_key(KEY_ESCAPE), true)
		assert_bool(options.is_open()).is_true()
		get_tree().root.push_input(_key(KEY_UP), true)
		get_tree().root.push_input(_key(KEY_ENTER), true)
		assert_bool(options.is_open()).is_false()
		assert_bool(get_tree().paused).is_false()
		assert_int(left[0]).is_equal(1)
		assert_object(screen._cart_reveal.board).is_null()
		# The pause's own OPTIONS show no BACK TO TITLE.
		screen._pause.options.leave_caption = ""
		assert_str(options.leave_caption).is_equal("")


func _ink_of(line: PixelLine) -> Color:
	for child: Node in line.get_children():
		var label: Label = child as Label
		if label != null:
			return label.get_theme_color("font_color")
	return Color.TRANSPARENT


func _title_tab() -> Rect2:
	var tw: float = ArtPen.word_texture("YOUR REGULARS", Palette.INK, true).get_width() + 20
	var at: Vector2 = SwapWindowDraw.RECT.position
	return Rect2(at.x + 10, at.y - 9, tw, 17)


static func _first_card(window: SwapWindow) -> SwapPiece:
	for piece: SwapPiece in window.pieces:
		if not piece.regular and window.drop_reason(piece, 1) == "":
			return piece
	return null


func _book(profile: ProfileState) -> FigurineBook:
	var book: FigurineBook = FigurineBook.new()
	add_child(book)
	auto_free(book)
	var fresh: Array[StringName] = []
	book.show_collection(
		Kit.balance(), profile.unlocked_items, profile.coupon_uses, fresh, true, profile.perk_levels
	)
	book.visible = true
	await _frames(3)
	return book


func _title() -> TitleScreen:
	var runner: GdUnitSceneRunner = scene_runner(TITLE)
	var title: TitleScreen = runner.scene()
	title.changes_scene = false
	title.skip_intro()
	await _frames(4)
	return title


func _shift() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN.resource_path)
	var screen: ShiftScreen = runner.scene()
	await _frames(2)
	return screen


## A new run's start board (reduced motion on) with no aisle completed.
func _screen() -> ShiftScreen:
	var screen: ShiftScreen = auto_free(SCREEN.instantiate())
	add_child(screen)
	await get_tree().process_frame
	screen.profile.set_reduced_motion(true)
	screen.save_profile()
	screen.start_new_run(SEED, true, true)
	await _frames(2)
	return screen


## The page (frozen on its clock, reduced motion off) of a new run with `completed` aisles
## complete (swap_window_test's).
func _page(completed: int) -> BoosterPage:
	var screen: ShiftScreen = auto_free(SCREEN.instantiate())
	add_child(screen)
	await get_tree().process_frame
	screen.profile.set_reduced_motion(false)
	for index: int in screen._balance.aisles.size():
		var aisle: AisleDefinition = screen._balance.aisles[index]
		var count: int = (
			aisle.capsule_cards.size()
			if index < completed
			else (
				mini(4, aisle.capsule_cards.size())
				if aisle.base_cards.is_empty() and completed > 0
				else 0
			)
		)
		for card: CardDefinition in aisle.capsule_cards.slice(0, count):
			screen.profile.unlocked_items[card.id] = 0
	screen.save_profile()
	screen.start_new_run(SEED, true, true)
	var page: BoosterPage = screen._cart_reveal.board.store
	page.frozen = true
	return page


static func _board(page: BoosterPage) -> StartBoard:
	var node: Node = page.get_parent()
	while node != null and not node is StartBoard:
		node = node.get_parent()
	return node as StartBoard


static func _stocked(page: BoosterPage) -> void:
	page.roulette.skip()
	# The boosters wait sealed for their clicks (round 2 of the 2026-11-19 play test).
	for sealed: BoosterOpening in page.shown_boosters():
		page.openings.open_booster(sealed.index, "click")
	_run(page, 8.0)


static func _run(page: BoosterPage, seconds: float) -> void:
	var left: float = seconds
	while left > 0.0001:
		page.advance(minf(STEP, left))
		left -= STEP


static func _button(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var button: InputEventMouseButton = InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	button.position = at * ArtPen.UNIT
	return button


static func _move(page: BoosterPage, at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at * ArtPen.UNIT
	page._gui_input(motion)


static func _on_screen(page: BoosterPage, rect: Rect2) -> Rect2:
	return page.get_global_transform() * Rect2(rect.position * ArtPen.UNIT, rect.size * ArtPen.UNIT)


static func _key(keycode: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.pressed = true
	key.keycode = keycode
	return key


func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
