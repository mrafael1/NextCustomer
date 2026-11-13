extends GdUnitTestSuite
## The opening board's page 1 YOUR STORE (full build plan 7.2, v1.32 boosters, mock-up
## start_boosters_v3.html) on the real screen: the store at dawn rolling up, the aisle boosters
## opening (saved at once) with their hit card's tap, OPEN ALL and the held Space, STOCKED!, the
## swap window's gate, RESTOCK, PICK 2 OF 3, resume, reduced motion, and the page's geometry
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
## is armed: Enter stops once at the swap window (a swap is unused), then goes to page 2.
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
	# A swap is unused: NEXT stops once at the swap window; Esc, then NEXT goes on.
	board._input(_key(KEY_ENTER))
	assert_bool(page.swap.active).is_true()
	assert_int(board.page).is_equal(1)
	board._input(_key(KEY_ESCAPE))
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


## Swaps wait for every booster to open: before, the basket's window refuses to open (OPEN THE
## BOOSTERS FIRST) and NEXT has no stop; once every booster is open the window opens from the
## basket (the plate's button) and Esc closes it. The window itself: swap_window_test.gd.
func test_the_swap_window_waits_for_the_boosters() -> void:
	var page: BoosterPage = await _page(2)
	_arrive(page)
	assert_bool(page.swap.is_live()).is_false()
	assert_bool(page.swap.open_window(false)).is_false()
	assert_str(page.message).is_equal("OPEN THE BOOSTERS FIRST")
	assert_bool(page.swap.active).is_false()
	assert_dict(page.run.start_setup.swap_offers).is_empty()
	page.openings.open_all("key")
	_run(page, 8.0)
	assert_bool(page.swap.is_live()).is_true()
	assert_bool(page.swap.wants_stop()).is_true()
	var crate: Array[String] = []
	for entry: Dictionary in page.hits:
		if entry.id == "crate":
			crate.append(entry.id)
			assert_bool(ART.encloses(entry.rect as Rect2)).is_true()
	assert_bool(crate.is_empty()).is_false()
	_click_art(page, BoosterChromeDraw.CRATE_RECT.get_center())
	assert_bool(page.swap.active).is_true()
	assert_int(page.run.start_setup.swap_offers.size()).is_equal(2)
	_board(page)._input(_key(KEY_ESCAPE))
	assert_bool(page.swap.active).is_false()


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
	# The counter keeps its PICK 2 OF 3 dress (no RESTOCK key or board) while the
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
## grid; the tote's bay stays clear of the floor row, whose plates and keys (RESTOCK's too) stay
## apart.
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
		Rect2(BoosterArt.TITLE_RECT),
		BoosterChromeDraw.hint_rect(page),
		key,
		Rect2(BoosterArt.PRIMARY_RECT),
	]
	for k: int in floor_row.size():
		assert_bool(ART.encloses(floor_row[k])).is_true()
		assert_bool(floor_row[k].intersects(bay)).is_false()
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


## v1.32 feedback: RESTOCK's key stands on the floor row just left of the primary key, as tall,
## clear of the hint LED (its right end cut HINT_MARGIN short of the key) and of the primary key
## at both window sizes; it arms, a second click on it cancels, and it stays (USED) after the
## run's RESTOCK. Below restock_min_completed it is hidden and the hint LED keeps its full width.
func test_the_restock_key_stands_left_of_the_primary_key() -> void:
	var locked: BoosterPage = await _page(maxi(0, _restock_count() - 1))
	_arrive(locked)
	assert_bool(_hit_ids(locked).has("restock")).is_false()
	assert_that(BoosterChromeDraw.hint_rect(locked)).is_equal(Rect2(BoosterArt.HINT_RECT))
	# R does not reach the hidden key: no "RESTOCK AT n AISLES" flash.
	_board(locked)._input(_key(KEY_R))
	assert_bool(locked.restock_armed).is_false()
	assert_bool(locked.hint_line().contains("RESTOCK AT")).is_false()
	var page: BoosterPage = await _page(_restock_count())
	_arrive(page)
	page.openings.open_all("key")
	_run(page, 8.0)
	var key: Rect2 = BoosterChromeDraw.key_rect()
	var primary: Rect2 = Rect2(BoosterArt.PRIMARY_RECT)
	var hint: Rect2 = BoosterChromeDraw.hint_rect(page)
	var title: Rect2 = Rect2(BoosterArt.TITLE_RECT)
	assert_float(key.end.x).is_equal(primary.position.x - BoosterArt.KEY_GAP)
	assert_float(key.position.y).is_equal(primary.position.y)
	assert_float(key.size.y).is_equal(primary.size.y)
	assert_float(key.size.y).is_greater_equal(title.size.y)
	assert_float(hint.position.x).is_equal(float(BoosterArt.HINT_RECT.position.x))
	assert_float(key.position.x - hint.end.x).is_equal(float(BoosterArt.HINT_MARGIN))
	assert_float(hint.size.x).is_less(float(BoosterArt.HINT_RECT.size.x))
	for other: Rect2 in [primary, hint, title, BoosterChromeDraw.bay_rect()]:
		assert_bool(key.intersects(other)).override_failure_message(str(other)).is_false()
	assert_bool(_hit_rect(page, "restock") == key).is_true()
	var board: StartBoard = _board(page)
	board.set_anchors_preset(Control.PRESET_TOP_LEFT)
	for board_size: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		board.size = board_size
		board._resize()
		var stage: Rect2 = board.get_global_rect()
		var shown: Rect2 = _on_screen(page, key)
		assert_bool(stage.grow(0.5).encloses(shown)).is_true()
		assert_bool(shown.intersects(_on_screen(page, primary))).is_false()
		assert_bool(shown.intersects(_on_screen(page, hint))).is_false()
		assert_float(shown.end.x).is_less(_on_screen(page, primary).position.x)
		assert_float(shown.position.y).is_greater(stage.position.y + stage.size.y * 0.85)
	_click_art(page, key.get_center())
	assert_bool(page.restock_armed).is_true()
	_click_art(page, key.get_center())
	assert_bool(page.restock_armed).is_false()
	_click_art(page, key.get_center())
	board._input(_key(KEY_1))
	assert_int(page.run.start_setup.restock_booster()).is_equal(0)
	_run(page, 3.0)
	assert_bool(_hit_ids(page).has("restock")).is_true()
	_click_art(page, key.get_center())
	assert_bool(page.restock_armed).is_false()
	assert_str(page.hint_line()).is_equal("RESTOCK USED")


## v1.32 feedback: no RUN-ONLY sign: the run stocks only its two boosters' aisles, and drawing
## page 1 never paints the RUN-ONLY words.
func test_no_run_only_sign_is_drawn() -> void:
	var page: BoosterPage = await _page(_restock_count())
	_arrive(page)
	page.openings.open_all("key")
	_run(page, 8.0)
	assert_int(page.run.start_setup.stock_aisles.size()).is_equal(2)
	assert_array(page.run.stock.aisle_ids).is_equal(page.run.start_setup.stock_aisles)
	ArtPen._words.clear()
	page.advance(0.0)
	await get_tree().process_frame
	await get_tree().process_frame
	var drew_store: bool = false
	for key: String in ArtPen._words:
		drew_store = drew_store or key.begins_with("YOUR STORE|")
		assert_bool(key.begins_with("RUN-ONLY")).override_failure_message(key).is_false()
	assert_bool(drew_store).override_failure_message(str(ArtPen._words.keys())).is_true()


## v1.32 feedback (the user's pick C "press-bob"): once NEXT is armed the primary key hops (1, 2, 1,
## 0 art px), then its face bobs up only 0 or 1 art px; it rests while hovered and under reduced
## motion; no bulb rim on either page; its hit rect stays put.
func test_the_armed_primary_key_press_bobs_without_bulbs() -> void:
	assert_bool(BuildPageDraw.new().has_method("_armed_rim")).is_false()
	assert_bool(BoosterPageDraw.new().has_method("key_grow")).is_false()
	var page: BoosterPage = await _page(2)
	_arrive(page)
	page.openings.open_all("key")
	_run(page, 8.0)
	assert_bool(page.page_done()).is_true()
	var tuning: StartBoostersTuning = page.tuning
	var base: Rect2 = Rect2(BoosterArt.PRIMARY_RECT)
	var armed_t: float = page.complete_t + 0.3
	var hop_end: float = tuning.next_hop_ends_s[tuning.next_hop_ends_s.size() - 1]
	var hop: Array[int] = []
	var up: int = 0
	var down: int = 0
	for step: int in 600:
		var t: float = armed_t + step * 0.01
		var lift: int = BoosterPageDraw.key_lift(t, armed_t, tuning, false, false)
		if t - armed_t < hop_end:
			if hop.is_empty() or hop[hop.size() - 1] != lift:
				hop.append(lift)
			continue
		assert_int(lift).is_between(0, 1)
		if lift == 1:
			up += 1
		else:
			down += 1
		assert_int(BoosterPageDraw.key_lift(t, armed_t, tuning, false, true)).is_equal(0)
		assert_int(BoosterPageDraw.key_lift(t, armed_t, tuning, true, false)).is_equal(0)
	assert_that(hop).is_equal([1, 2, 1, 0])
	assert_int(up).is_greater(0)
	assert_int(down).is_greater(up)
	# The hop plays even under the pointer, never under reduced motion; nothing before arming.
	assert_int(BoosterPageDraw.key_lift(armed_t + 0.1, armed_t, tuning, false, true)).is_equal(2)
	assert_int(BoosterPageDraw.key_lift(armed_t + 0.1, armed_t, tuning, true, false)).is_equal(0)
	assert_int(BoosterPageDraw.key_lift(armed_t - 0.1, armed_t, tuning, false, false)).is_equal(0)
	_run(page, 0.1)
	assert_bool(_hit_rect(page, "primary") == base).is_true()
	assert_int(BoosterChromeDraw.primary_lift(page)).is_between(0, 1)
	page.hover_id = "primary"
	assert_int(BoosterChromeDraw.primary_lift(page)).is_equal(0)
	page.hover_id = ""
	var still: BoosterPage = await _page(2, true)
	still.openings.open_all("key")
	for step: int in 30:
		_run(still, 0.1)
		assert_int(BoosterChromeDraw.primary_lift(still)).is_equal(0)
	assert_bool(still.page_done()).is_true()
	assert_bool(_hit_rect(still, "primary") == base).is_true()


## The press-bob never resizes the key: at rest it is one 9-slice on its rect; lifted 1 art px the
## 9-slice moves up 1 px (same size), its ledge row (frame row 8) doubles under the face and the
## bottom outline (row 9) stays on the rect's bottom row, so the drawn span is the rect plus the
## face's one row above it.
func test_the_lifted_key_never_changes_size() -> void:
	var rect: Rect2 = Rect2(BoosterArt.PRIMARY_RECT)
	var x: float = rect.position.x
	var y: float = rect.position.y
	var w: float = rect.size.x
	var h: float = rect.size.y
	var rest: _PenRecorder = _PenRecorder.new()
	BoosterPageDraw.lifted_key(rest, BoosterArt.BUTTON, x, y, w, h, 0)
	assert_that(rest.nines).is_equal([rect])
	assert_int(rest.parts.size()).is_equal(0)
	var lifted: _PenRecorder = _PenRecorder.new()
	BoosterPageDraw.lifted_key(lifted, BoosterArt.BUTTON, x, y, w, h, 1)
	assert_that(lifted.nines).is_equal([Rect2(x, y - 1, w, h)])
	var t: float = BoosterArt.BUTTON.get_width() / 10.0
	var span: Rect2 = lifted.nines[0]
	var ledge_w: float = 0.0
	var outline_w: float = 0.0
	for part: Array in lifted.parts:
		var region: Rect2 = part[0]
		var drawn: Rect2 = part[1]
		span = span.merge(drawn)
		if is_equal_approx(region.position.y, 8 * t):
			assert_float(drawn.position.y).is_equal(y + h - 3)
			assert_float(drawn.size.y).is_equal(2.0)
			ledge_w += drawn.size.x
		else:
			assert_float(region.position.y).is_equal(9 * t)
			assert_float(drawn.position.y).is_equal(y + h - 1)
			assert_float(drawn.size.y).is_equal(1.0)
			outline_w += drawn.size.x
	assert_float(ledge_w).is_equal(w)
	assert_float(outline_w).is_equal(w)
	assert_that(span).is_equal(Rect2(x, y - 1, w, h + 1))


## An ArtPen that records its nine-slices and texture parts instead of drawing.
class _PenRecorder:
	extends ArtPen
	var nines: Array[Rect2] = []
	var parts: Array[Array] = []

	func _init() -> void:
		super(null)

	func nine(
		_frame: Texture2D,
		x: float,
		y: float,
		w: float,
		h: float,
		_margins: Vector4i,
		_modulate: Color = Color.WHITE
	) -> void:
		nines.append(Rect2(x, y, w, h))

	func tex_part(
		_texture: Texture2D,
		region: Rect2,
		x: float,
		y: float,
		w: float,
		h: float,
		_modulate: Color = Color.WHITE
	) -> void:
		parts.append([region, Rect2(x, y, w, h)])


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


static func _hit_rect(page: BoosterPage, id: String) -> Rect2:
	for entry: Dictionary in BoosterPageDraw.hits(page):
		if String(entry.id) == id:
			return entry.rect
	return Rect2()


## Art rect `rect` on screen (global px).
static func _on_screen(page: BoosterPage, rect: Rect2) -> Rect2:
	return page.get_global_transform() * Rect2(rect.position * ArtPen.UNIT, rect.size * ArtPen.UNIT)


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
