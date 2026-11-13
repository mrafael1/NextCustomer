extends GdUnitTestSuite
## The opening board's page 1 YOUR STORE (full build plan 7.2, v1.32 boosters, mock-up
## start_boosters_v3.html) on the real screen: the store at dawn rolling up, the aisle boosters
## opening (saved at once) with their hit card's tap, OPEN ALL and the held Space, STOCKED!, the
## swap tray and its gate, RESTOCK, PICK 2 OF 3, resume, reduced motion, and the page's geometry
## at 1280x720 and 1920x1080. The page runs on its own clock: the tests freeze it and step it.

const SCREEN := preload("res://ui/shift_screen.tscn")
const SEED := 20261103
const STEP := 1.0 / 60.0
## The art grid (the stage at 2 stage px per art px).
const ART := Rect2(0, 0, 640, 360)

var _folder: String


func before_test() -> void:
	_folder = "user://start_board_test_%d" % Time.get_ticks_usec()
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_event_log().use_folder(_folder)


func after_test() -> void:
	await get_tree().process_frame
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file))
		DirAccess.remove_absolute(_folder)


## A new run opens on the storefront, shutters down; Enter rolls them up, the view walks in and
## each booster drops under its own lamp, on the counter, inside the stage and clear of the
## floor row.
func test_the_store_rolls_up_and_the_boosters_land_under_their_lamps() -> void:
	var page: BoosterPage = await _page(2)
	assert_int(page.shutter).is_equal(BoosterPage.Shutter.DOWN)
	assert_str(String(page.primary_label()[0])).is_equal("ROLL UP")
	assert_str(page.hint_line()).is_equal("ROLL UP THE SHUTTER")
	var board: StartBoard = _board(page)
	board._input(_key(KEY_ENTER))
	assert_int(page.shutter).is_equal(BoosterPage.Shutter.ROLLING)
	_run(page, 4.0)
	assert_int(page.shutter).is_equal(BoosterPage.Shutter.UP)
	assert_bool(page.openings.arrival_busy()).is_false()
	assert_int(page.boosters.size()).is_equal(2)
	for b: BoosterOpening in page.boosters:
		var pouch: Rect2 = BoosterArt.pouch_rect(b.cx)
		var lamp: Rect2 = BoosterArt.lamp_rect(b.cx)
		assert_float(pouch.get_center().x).is_equal_approx(lamp.get_center().x, 1.0)
		assert_float(pouch.position.y).is_greater(lamp.end.y)
		assert_bool(ART.encloses(pouch)).is_true()
		assert_float(pouch.end.y).is_less_equal(BoosterPageDraw.COUNTER_CLIP)
		assert_float(pouch.end.y).is_less(BoosterArt.HINT_RECT.position.y)
	var left: Rect2 = BoosterArt.pouch_rect(page.boosters[0].cx)
	var right: Rect2 = BoosterArt.pouch_rect(page.boosters[1].cx)
	assert_bool(left.intersects(right)).is_false()
	assert_str(String(page.primary_label()[0])).is_equal("OPEN ALL")


## A click on a booster opens it, saved at once; its commons land on their own and a brass hit
## card waits for its click (FLIP ?), which turns it; the CART count climbs to every landed
## card. The fan's cards stand 3 art px apart, on the stage.
func test_a_booster_opens_on_a_click_and_its_hit_card_waits_for_a_tap() -> void:
	var page: BoosterPage = await _page(2)
	_arrive(page)
	var run: RunState = page.run
	_click_art(page, BoosterArt.pouch_rect(page.boosters[0].cx).get_center())
	assert_bool(run.start_setup.boosters[0].opened).is_true()
	assert_bool((_save()["start_setup"]["boosters"] as Array)[0]["opened"]).is_true()
	var b: BoosterOpening = page.boosters[0]
	assert_int(b.state).is_equal(BoosterOpening.State.OPENING)
	_run(page, 4.0)
	var waiting: int = b.waiting_k()
	if waiting >= 0:
		assert_bool(b.at_rest(page.tuning)).is_true()
		assert_str(String(page.primary_label()[0])).is_equal("FLIP ?")
		assert_str(page.hint_line()).is_equal("CLICK THE ? CARD")
		_click_art(page, BoosterArt.card_rect(b.cx, waiting).get_center())
		_run(page, 3.0)
	assert_int(b.state).is_equal(BoosterOpening.State.OPEN)
	for k: int in b.cards.size():
		assert_bool(b.landed(k, page.tuning)).is_true()
	_run(page, 1.0)
	assert_int(page.cart_shown).is_equal(run.starter.core_cards.size() + b.cards.size())
	for k: int in b.cards.size():
		var card: Rect2 = BoosterArt.card_rect(b.cx, k)
		assert_bool(ART.encloses(card)).is_true()
		if k > 0:
			var prev: Rect2 = BoosterArt.card_rect(b.cx, k - 1)
			assert_float(card.position.x - prev.end.x).is_equal(3.0)


## OPEN ALL (A) opens every booster (saved), the hits flipped for you; both fans fit side by
## side; then the clock steps to 7:00, STOCKED! hangs clear of the lamps and the fans, and NEXT
## is armed: Enter goes to page 2.
func test_open_all_stocks_the_page_and_arms_next() -> void:
	var page: BoosterPage = await _page(2)
	_arrive(page)
	var board: StartBoard = _board(page)
	board._input(_key(KEY_A))
	for booster: StartBooster in page.run.start_setup.boosters:
		assert_bool(booster.opened).is_true()
	_run(page, 8.0)
	assert_bool(page.page_done()).is_true()
	assert_int(page.clock_minutes).is_equal(60)
	var fans: Array[Rect2] = []
	for b: BoosterOpening in page.boosters:
		assert_int(b.state).is_equal(BoosterOpening.State.OPEN)
		fans.append(BoosterArt.fan_rect(b.cx, b.cards.size()))
	assert_bool(fans[0].intersects(fans[1])).is_false()
	var stamp: Rect2 = _stocked_rect()
	assert_bool(ART.encloses(stamp)).is_true()
	for b: BoosterOpening in page.boosters:
		assert_bool(stamp.intersects(BoosterArt.lamp_rect(b.cx))).is_false()
		assert_bool(stamp.intersects(BoosterArt.fan_rect(b.cx, 3))).is_false()
	assert_str(String(page.primary_label()[0])).is_equal("NEXT ›")
	board._input(_key(KEY_ENTER))
	assert_int(board.page).is_equal(2)


## Space held for hold_space_s opens everything; a short tap does not.
func test_holding_space_opens_every_booster() -> void:
	var page: BoosterPage = await _page(2)
	_arrive(page)
	var board: StartBoard = _board(page)
	board._input(_key(KEY_SPACE))
	_run(page, page.tuning.hold_space_s * 0.4)
	var release: InputEventKey = _key(KEY_SPACE)
	release.pressed = false
	board._input(release)
	_run(page, 0.5)
	assert_bool(page.run.start_setup.boosters[1].opened).is_false()
	board._input(_key(KEY_SPACE))
	_run(page, page.tuning.hold_space_s + 0.1)
	for booster: StartBooster in page.run.start_setup.boosters:
		assert_bool(booster.opened).is_true()


## Swaps wait for every booster to open (SWAP AFTER OPENING); then a regular opens its swap tray
## (on the stage, its offers inside it and apart), a pick swaps it at once and a click on it puts
## it back.
func test_the_swap_tray_waits_for_the_boosters_then_swaps_and_undoes() -> void:
	var page: BoosterPage = await _page(2)
	_arrive(page)
	var run: RunState = page.run
	assert_bool(page.counter.click_regular(0)).is_false()
	assert_str(page.hint_line()).is_equal("SWAP AFTER OPENING")
	assert_int(page.tray_slot).is_equal(-1)
	page.openings.open_all("key")
	_run(page, 8.0)
	var original: CardDefinition = run.starter.core_cards[0]
	assert_bool(page.counter.click_regular(0)).is_true()
	assert_int(page.tray_slot).is_equal(0)
	var offer: Array[CardDefinition] = page.counter.tray_offer(0)
	assert_int(offer.size()).is_equal(3)
	page.advance(0.0)
	var tray: Rect2 = Rect2()
	var minis: Array[Rect2] = []
	for entry: Dictionary in page.hits:
		if entry.id == "tray":
			tray = entry.rect
		elif String(entry.id).begins_with("mini"):
			minis.append(entry.rect)
	assert_bool(tray.has_area()).is_true()
	assert_bool(ART.encloses(tray)).is_true()
	assert_bool(minis.is_empty()).is_false()
	for k: int in minis.size():
		assert_bool(tray.encloses(minis[k])).is_true()
		for other: int in k:
			assert_bool(minis[k].intersects(minis[other])).is_false()
	var picked: int = -1
	for k: int in offer.size():
		if picked < 0 and StartSetupRules.swap_block(run, page.profile, 0, offer[k]) == &"":
			picked = k
	assert_int(picked).is_greater_equal(0)
	assert_bool(page.handle_key([KEY_1, KEY_2, KEY_3][picked])).is_true()
	assert_object(run.starter.core_cards[0]).is_same(offer[picked])
	assert_int(page.tray_slot).is_equal(-1)
	assert_int(page.counter.swaps_used()).is_equal(1)
	page.counter.click_regular(0)
	assert_object(run.starter.core_cards[0]).is_same(original)


## RESTOCK unlocks at its completed count: R needs an opened booster; then R arms it, 1 returns
## booster 0 (saved) for a fresh sealed one of the same aisle; it is then used up.
func test_restock_returns_an_opened_booster_for_a_sealed_one() -> void:
	var page: BoosterPage = await _page(_restock_count())
	_arrive(page)
	var board: StartBoard = _board(page)
	board._input(_key(KEY_R))
	assert_bool(page.restock_armed).is_false()
	assert_str(page.hint_line()).is_equal("OPEN A BOOSTER FIRST")
	page.openings.open_all("key")
	_run(page, 8.0)
	var aisle: StringName = page.boosters[0].aisle
	board._input(_key(KEY_R))
	assert_bool(page.restock_armed).is_true()
	assert_str(String(page.primary_label()[0])).is_equal("CANCEL")
	var full: int = page.cart_target()
	assert_int(page.clock_minutes).is_equal(60)
	board._input(_key(KEY_1))
	assert_int(page.run.start_setup.restock_booster()).is_equal(0)
	var b: BoosterOpening = page.boosters[0]
	assert_int(b.state).is_equal(BoosterOpening.State.SEALED)
	# The returned cards leave the CART count at once, and the clock stays at 7:00.
	assert_int(page.cart_n).is_equal(full - page.tote_cards.size())
	assert_int(page.clock_minutes).is_equal(60)
	assert_bool(b.restocked).is_true()
	assert_str(String(b.aisle)).is_equal(String(aisle))
	assert_bool(page.page_done()).is_false()
	_run(page, 3.0)
	assert_bool(page.tote_cards.is_empty()).is_true()
	assert_int(page.cart_shown).is_equal(full - b.cards.size())
	assert_int(page.clock_minutes).is_equal(60)
	board._input(_key(KEY_R))
	assert_bool(page.restock_armed).is_false()
	assert_str(page.hint_line()).is_equal("RESTOCK USED")
	board._input(_key(KEY_A))
	_run(page, 8.0)
	assert_bool(page.page_done()).is_true()


## At 6 completed aisles three boosters stand under three lamps, apart and on the stage: PICK 2
## OF 3. The second pick saves the pair; the third is SOLD OUT and gone, and the pair slides to
## the two zones.
func test_pick_two_of_three_sells_out_the_third() -> void:
	var page: BoosterPage = await _page(6)
	_arrive(page)
	assert_int(page.boosters.size()).is_equal(3)
	assert_bool(page.picking()).is_true()
	for k: int in 3:
		var pouch: Rect2 = BoosterArt.pouch_rect(page.boosters[k].cx)
		assert_float(page.boosters[k].cx).is_equal(float(BoosterArt.PICK_X[k]))
		assert_bool(ART.encloses(pouch)).is_true()
		if k > 0:
			var prev: Rect2 = BoosterArt.pouch_rect(page.boosters[k - 1].cx)
			assert_bool(pouch.intersects(prev)).is_false()
	# All three boosters (each under its own lamp, drawn at the booster's centre) stay inside the
	# board's stage at both window sizes.
	var board: StartBoard = _board(page)
	board.set_anchors_preset(Control.PRESET_TOP_LEFT)
	for board_size: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		board.size = board_size
		board._resize()
		var stage: Rect2 = board.get_global_rect()
		for k: int in 3:
			var pouch: Rect2 = BoosterArt.pouch_rect(page.boosters[k].cx)
			var shown: Rect2 = (
				page.get_global_transform()
				* Rect2(pouch.position * ArtPen.UNIT, pouch.size * ArtPen.UNIT)
			)
			assert_bool(stage.grow(0.5).encloses(shown)).is_true()
	page.handle_key(KEY_1)
	assert_bool(page.picking()).is_true()
	page.handle_key(KEY_3)
	assert_bool(page.picking()).is_false()
	assert_bool(page.run.start_setup.boosters[1].sold_out).is_true()
	# The counter keeps its PICK 2 OF 3 dress (no RESTOCK key, board or RUN-ONLY sign) while the
	# SOLD OUT booster is on show, and changes when the pair slides.
	assert_bool(page.openings.pick_layout()).is_true()
	assert_bool(_hit_ids(page).has("restock")).is_false()
	_run(page, page.tuning.pick_move_at_s * 0.9)
	assert_bool(page.openings.pick_layout()).is_true()
	assert_float(page.boosters[1].cx).is_equal(float(BoosterArt.PICK_X[1]))
	_run(page, page.tuning.pick_move_at_s * 0.2)
	assert_bool(page.openings.pick_layout()).is_false()
	_run(page, 3.0)
	assert_int(page.boosters[1].state).is_equal(BoosterOpening.State.GONE)
	var zones: Array[float] = [page.boosters[0].cx, page.boosters[2].cx]
	zones.sort()
	assert_array(zones).is_equal([float(BoosterArt.ZONE_A), float(BoosterArt.ZONE_B)])


## Every aisle in the balance has its booster pouch and torn strip drawn (none falls back to
## another aisle's art).
func test_every_aisle_has_its_pouch_and_strip() -> void:
	var page: BoosterPage = await _page(2)
	for aisle: AisleDefinition in page.run.balance.aisles:
		(
			assert_bool(BoosterArt.POUCHES.has(aisle.id))
			. override_failure_message(String(aisle.id))
			. is_true()
		)
		(
			assert_bool(BoosterArt.STRIPS.has(aisle.id))
			. override_failure_message(String(aisle.id))
			. is_true()
		)


## A resume keeps what was opened: the opened booster shows open at once, the sealed one sealed,
## the shutter up.
func test_a_resume_keeps_the_opened_booster() -> void:
	var page: BoosterPage = await _page(2)
	_arrive(page)
	page.openings.open_booster(0)
	var resumed: ShiftScreen = auto_free(SCREEN.instantiate())
	add_child(resumed)
	await get_tree().process_frame
	var again: BoosterPage = resumed._cart_reveal.board.store
	assert_int(again.shutter).is_equal(BoosterPage.Shutter.UP)
	assert_int(again.boosters[0].state).is_equal(BoosterOpening.State.OPEN)
	assert_int(again.boosters[1].state).is_equal(BoosterOpening.State.SEALED)


## A RESTOCK after page 2 was opened leaves a sealed booster at stage BUILD: a resume opens on
## page 1 (the fresh booster must be opened first) and the clock-in is refused.
func test_a_resume_with_a_sealed_restock_opens_on_page_one() -> void:
	var page: BoosterPage = await _page(_restock_count())
	_arrive(page)
	page.openings.open_all("key")
	_run(page, 8.0)
	var board: StartBoard = _board(page)
	board._choice.mark_build.call()
	assert_int(page.run.start_setup.stage).is_equal(StartSetup.Stage.BUILD)
	board._input(_key(KEY_R))
	board._input(_key(KEY_1))
	assert_int(page.run.start_setup.restock_booster()).is_equal(0)
	assert_bool(page.run.start_setup.all_open()).is_false()
	assert_int(page.run.start_setup.stage).is_equal(StartSetup.Stage.BUILD)
	var resumed: ShiftScreen = auto_free(SCREEN.instantiate())
	add_child(resumed)
	await get_tree().process_frame
	var again: StartBoard = resumed._cart_reveal.board
	assert_int(again.run.start_setup.stage).is_equal(StartSetup.Stage.BUILD)
	assert_int(again.page).is_equal(1)
	assert_bool(again.store.visible).is_true()
	assert_bool(again.clock_in()).is_false()
	assert_int(again.store.boosters[0].state).is_equal(BoosterOpening.State.SEALED)


## The page fills the board's stage at both sizes; every hit target stays on the 640x360 art
## grid; the RESTOCK key and the tote's bay stay apart, and the floor row's plates stay apart.
func test_the_page_fits_the_stage_at_both_sizes() -> void:
	var page: BoosterPage = await _page(_restock_count())
	_arrive(page)
	page.openings.open_all("key")
	_run(page, 8.0)
	var board: StartBoard = _board(page)
	board.set_anchors_preset(Control.PRESET_TOP_LEFT)
	for board_size: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		board.size = board_size
		board._resize()
		var rect: Rect2 = page.get_global_rect()
		assert_bool(rect.grow(0.5).encloses(board.get_global_rect())).is_true()
	page.advance(0.0)
	assert_bool(page.hits.is_empty()).is_false()
	for entry: Dictionary in page.hits:
		var hit: Rect2 = entry.rect
		assert_bool(ART.encloses(hit)).override_failure_message(String(entry.id)).is_true()
	var key: Rect2 = BoosterChromeDraw.key_rect()
	var bay: Rect2 = BoosterChromeDraw.bay_rect()
	assert_bool(key.intersects(bay)).is_false()
	var floor_row: Array[Rect2] = [
		Rect2(BoosterArt.TITLE_RECT), Rect2(BoosterArt.HINT_RECT), Rect2(BoosterArt.PRIMARY_RECT)
	]
	for k: int in floor_row.size():
		assert_bool(ART.encloses(floor_row[k])).is_true()
		assert_bool(floor_row[k].intersects(key)).is_false()
		for other: int in k:
			assert_bool(floor_row[k].intersects(floor_row[other])).is_false()


## Reduced motion shows each end state at once: the shutter is up, OPEN ALL lands every card
## within a second or two and STOCKED! follows.
func test_reduced_motion_shows_the_end_states() -> void:
	var page: BoosterPage = await _page(2, true)
	assert_int(page.shutter).is_equal(BoosterPage.Shutter.UP)
	page.openings.open_all("key")
	_run(page, 2.0)
	assert_bool(page.page_done()).is_true()
	for b: BoosterOpening in page.boosters:
		assert_int(b.state).is_equal(BoosterOpening.State.OPEN)


func _restock_count() -> int:
	var balance: BalanceDefinition = load("res://data/balance/balance.tres")
	return maxi(1, balance.restock_min_completed)


## The page (frozen on its clock) of a new run with `completed` aisles complete.
func _page(completed: int, reduced: bool = false) -> BoosterPage:
	var screen: ShiftScreen = auto_free(SCREEN.instantiate())
	add_child(screen)
	await get_tree().process_frame
	screen.profile.set_reduced_motion(reduced)
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


## Rolls the shutter up and lets the boosters land.
static func _arrive(page: BoosterPage) -> void:
	if page.shutter == BoosterPage.Shutter.DOWN:
		page.openings.roll_up()
	_run(page, 4.0)


static func _run(page: BoosterPage, seconds: float) -> void:
	var left: float = seconds
	while left > 0.0001:
		page.advance(minf(STEP, left))
		left -= STEP


## A left click at art point `at` through the page's input.
static func _click_art(page: BoosterPage, at: Vector2) -> void:
	var button: InputEventMouseButton = InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = true
	button.position = at * ArtPen.UNIT
	page._gui_input(button)


static func _hit_ids(page: BoosterPage) -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in BoosterPageDraw.hits(page):
		ids.append(String(entry.id))
	return ids


static func _stocked_rect() -> Rect2:
	var size: Vector2 = BoosterArt.STOCKED.get_size()
	return Rect2(Vector2(BoosterArt.STOCKED_CENTRE) - size / 2.0, size)


func _save() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(_folder.path_join(SaveService.RUN_FILE)))


static func _key(keycode: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.pressed = true
	key.keycode = keycode
	return key


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
