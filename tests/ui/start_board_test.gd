extends GdUnitTestSuite
## The opening board's page 1 YOUR STORE (full build plan 7.2; the aisle board of v1.44, mock-up
## start_roulette.html variant A) on the real screen: the light running along the bays and landing
## on today's aisles, the shutters, the boosters thrown and opening by themselves (saved at once),
## the skip, the guided first run's fixed pair, locked aisles, RESTOCK, a veteran's two bays,
## the compact fan cards and their hover, resume, reduced motion, and the page's geometry at
## 1280x720 and 1920x1080. The page runs on its own clock: the tests freeze it and step it.

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


## A new run of a played profile: the board waits, then the light runs along the open bays only,
## lands on today's two aisles, the other bays roll their shutters down, and each open bay throws
## its booster, which waits sealed on the counter until its click (round 2 of the 2026-11-19 play
## test), saved as it opens. NEXT is then armed.
func test_the_light_lands_on_todays_aisles_and_the_boosters_wait_for_their_clicks() -> void:
	var page: BoosterPage = await _page(2)
	var roulette: AisleRoulette = page.roulette
	assert_int(roulette.count).is_equal(page.run.balance.aisles.size())
	assert_int(roulette.phase).is_equal(AisleRoulette.Phase.WAIT)
	assert_bool(roulette.land_t.is_empty()).is_true()
	assert_str(String(page.primary_label()[0])).is_equal("SKIP ›")
	_run(page, page.tuning.spin_delay_s + 0.3)
	assert_int(roulette.phase).is_equal(AisleRoulette.Phase.SPIN)
	assert_bool(roulette.hops.is_empty()).is_false()
	var seen: Dictionary[int, bool] = {}
	for step: int in 60:
		_run(page, 0.05)
		if roulette.chase_bay() >= 0:
			seen[roulette.chase_bay()] = true
	assert_int(seen.size()).is_greater(2)
	_run(page, 12.0)
	# Landed and sealed: nothing opens by itself, the primary key says OPEN, the pointer is the hand.
	assert_bool(roulette.busy()).is_false()
	assert_str(String(page.primary_label()[0])).is_equal("OPEN ›")
	for b: BoosterOpening in page.boosters:
		assert_int(b.state).is_equal(BoosterOpening.State.SEALED)
		assert_bool(page.run.start_setup.boosters[b.index].opened).is_false()
	_assert_pouches_beside_rows(page)
	_run(page, 6.0)
	assert_bool(page.page_done()).is_false()
	for b: BoosterOpening in page.shown_boosters():
		var pouch: Vector2 = b.pouch_pos() + Vector2(BoosterArt.BW, BoosterArt.BH) / 2
		page.mouse = pouch
		page.advance(0.0)
		assert_str(page.hover_id).is_equal("booster%d" % b.index)
		assert_int(page.mouse_default_cursor_shape).is_equal(Control.CURSOR_POINTING_HAND)
		_click_art(page, pouch)
		assert_int(b.state).is_equal(BoosterOpening.State.OPENING)
	_run(page, 12.0)
	var today: Array[int] = []
	for b: BoosterOpening in page.boosters:
		today.append(b.bay)
		assert_int(b.bay).is_equal(roulette.bay_of(b.aisle))
		assert_int(b.state).is_equal(BoosterOpening.State.OPEN)
		assert_bool(page.run.start_setup.boosters[b.index].opened).is_true()
	assert_int(today.size()).is_equal(2)
	for bay: int in roulette.count:
		assert_bool(roulette.land_t.has(bay)).is_equal(today.has(bay))
		assert_float(roulette.shut_frac(bay)).is_equal(0.0 if today.has(bay) else 1.0)
		assert_bool(AisleBoardDraw.bay_lit(page, bay)).is_equal(today.has(bay))
	# The light only played the dealt result: the last hop of each run is one of today's bays.
	assert_bool(today.has(int(roulette.hops[roulette.hops.size() - 1].bay))).is_true()
	assert_bool(page.page_done()).is_true()
	assert_str(String(page.primary_label()[0])).is_equal("NEXT ›")
	assert_int(page.cart_shown).is_equal(
		page.run.starter.core_cards.size() + page.run.start_setup.shared().size()
	)
	var saved: Array = _save()["start_setup"]["boosters"]
	for entry: Dictionary in saved:
		assert_bool(entry["opened"]).is_true()


## The light slows: each hop waits longer than the one before, and the hops fill their time.
func test_the_light_slows_into_its_landing() -> void:
	var gaps: Array[float] = AisleRoulette.hop_gaps(12, 1.75, 0.04)
	assert_int(gaps.size()).is_equal(12)
	var total: float = 0.0
	for k: int in gaps.size():
		total += gaps[k]
		if k > 0:
			assert_float(gaps[k]).is_greater(gaps[k - 1])
	assert_float(total).is_equal_approx(1.75, 0.01)


## A click skips the light: the bays land at once and the shutters are down; further clicks speed
## the throws and the openings up; nothing else is pressed by them.
func test_a_click_skips_the_light() -> void:
	var page: BoosterPage = await _page(_restock_count())
	_click_art(page, Vector2(320, 150))
	assert_int(page.roulette.phase).is_not_equal(AisleRoulette.Phase.SPIN)
	assert_int(page.roulette.phase).is_not_equal(AisleRoulette.Phase.WAIT)
	for b: BoosterOpening in page.boosters:
		assert_bool(page.roulette.land_t.has(b.bay)).is_true()
	assert_float(page.roulette.chase_end).is_less_equal(page.now)
	assert_int(page.roulette.chase_bay()).is_equal(-1)
	# The boosters land at once, sealed: a click on the board opens none of them.
	for b: BoosterOpening in page.boosters:
		assert_bool(page.roulette.landed(b)).is_true()
	_click_art(page, Vector2(320, 150))
	_run(page, 2.0)
	for b: BoosterOpening in page.boosters:
		assert_int(b.state).is_equal(BoosterOpening.State.SEALED)
	_open_landed(page)
	for step: int in 40:
		_click_art(page, Vector2(320, 150))
		_run(page, 0.1)
	assert_bool(page.page_done()).is_true()
	assert_bool(page.restock_armed).is_false()
	assert_bool(page.swap.visible()).is_false()
	# Enter skips as a click does; then each press opens the next sealed booster, left to right.
	var other: BoosterPage = await _page(2)
	_board(other)._input(_key(KEY_ENTER))
	assert_int(other.roulette.phase).is_equal(AisleRoulette.Phase.DEAL)
	var shown: Array[BoosterOpening] = other.shown_boosters()
	_board(other)._input(_key(KEY_ENTER))
	assert_int(shown[0].state).is_equal(BoosterOpening.State.OPENING)
	assert_int(shown[1].state).is_equal(BoosterOpening.State.SEALED)
	_board(other)._input(_key(KEY_ENTER))
	assert_int(shown[1].state).is_equal(BoosterOpening.State.OPENING)
	# A number key opens its own booster too.
	var keyed: BoosterPage = await _page(2)
	keyed.roulette.skip()
	_board(keyed)._input(_key(KEY_2))
	assert_int(keyed.shown_boosters()[1].state).is_equal(BoosterOpening.State.OPENING)
	assert_int(keyed.shown_boosters()[0].state).is_equal(BoosterOpening.State.SEALED)


## The first run of a new profile (the guided run): no light, the tutorial's fixed pair (Dairy and
## Pantry) open from the first frame, the four other bays shut, and the boosters come out and
## wait sealed for their clicks.
func test_the_first_run_shows_its_fixed_pair_without_a_spin() -> void:
	var page: BoosterPage = await _page(0, false, true)
	assert_bool(page.run.guided).is_true()
	var roulette: AisleRoulette = page.roulette
	assert_int(roulette.phase).is_equal(AisleRoulette.Phase.DEAL)
	assert_bool(roulette.hops.is_empty()).is_true()
	var open_bays: Array[String] = []
	for bay: int in roulette.count:
		var aisle: AisleDefinition = page.run.balance.aisles[bay]
		if roulette.shut_frac(bay) == 0.0:
			open_bays.append(String(aisle.id))
			assert_bool(AisleBoardDraw.bay_lit(page, bay)).is_true()
		else:
			assert_float(roulette.shut_frac(bay)).is_equal(1.0)
	assert_array(open_bays).is_equal(["dairy", "pantry"])
	for step: int in 200:
		_run(page, 0.05)
		assert_int(roulette.chase_bay()).is_equal(-1)
	assert_bool(page.page_done()).is_false()
	for b: BoosterOpening in page.boosters:
		assert_int(b.state).is_equal(BoosterOpening.State.SEALED)
	_play(page)
	assert_bool(page.page_done()).is_true()
	for b: BoosterOpening in page.boosters:
		assert_int(b.state).is_equal(BoosterOpening.State.OPEN)


## An aisle the profile has not unlocked is shut behind its padlock from the start: the light
## never runs over it and never lands on it.
func test_locked_aisles_stay_shut_and_the_light_skips_them() -> void:
	var page: BoosterPage = await _page(0)
	var roulette: AisleRoulette = page.roulette
	var locked: Array[int] = []
	for bay: int in roulette.count:
		var aisle: AisleDefinition = page.run.balance.aisles[bay]
		var listable: bool = RunStock.is_listable(
			aisle, page.run.balance, page.profile.unlocked_items
		)
		assert_bool(roulette.locked[bay]).is_equal(not listable)
		if roulette.locked[bay]:
			locked.append(bay)
			assert_float(roulette.shut_frac(bay)).is_equal(1.0)
	assert_int(locked.size()).is_equal(3)
	assert_array(roulette.ring()).not_contains(locked)
	for step: int in 240:
		_run(page, 0.05)
		assert_bool(locked.has(roulette.chase_bay())).is_false()
		for bay: int in locked:
			assert_bool(AisleBoardDraw.bay_lit(page, bay)).is_false()
	for hop: Dictionary in roulette.hops:
		assert_bool(locked.has(int(hop.bay))).is_false()
	for bay: int in locked:
		assert_bool(roulette.land_t.has(bay)).is_false()
	_play(page)
	assert_bool(page.page_done()).is_true()


## Each pouch lands in front of its own bay: in bay order, right under its bay whenever both fit,
## else pushed only as far as the stage and its neighbour ask. Its compact cards open into rows
## (play test 2026-11-19): the left bay's on top, the right bay's below, each row starting at its
## aisle's tab; the rows, the tabs and a hovered card's full card stay on the stage, apart and
## clear of the counter and the keys, at both sizes (no counter plates since round 3).
func test_the_fans_stand_under_their_own_bays_at_both_sizes() -> void:
	for seed_value: int in [SEED, 7, 3, 11]:
		var page: BoosterPage = await _page(_restock_count(), false, false, seed_value)
		_play(page)
		_assert_fans(page)
		page.counter.arm_restock()
		assert_bool(page.restock_armed).is_true()
		var bays: Array[int] = [page.boosters[0].bay, page.boosters[1].bay]
		assert_bool(page.counter.restock(0)).is_true()
		_run(page, 6.0)
		_play(page)
		assert_array([page.boosters[0].bay, page.boosters[1].bay]).is_equal(bays)
		_assert_fans(page)
		_board(page).get_parent().get_parent().queue_free()
		await get_tree().process_frame


## Round 3 of the 2026-11-19 play test: each sealed booster waits at its own row's start, right
## beside that row's aisle tab (the 1st aisle's by the top row, the 2nd's by the bottom one),
## level with its row, clear of the other pouch, the hung signs' words and the keys; on screen at
## both sizes.
func _assert_pouches_beside_rows(page: BoosterPage) -> void:
	var shown: Array[BoosterOpening] = page.shown_boosters()
	assert_int(shown.size()).is_equal(2)
	var keys: Array[Rect2] = [
		Rect2(BoosterArt.TITLE_RECT),
		Rect2(BoosterArt.PRIMARY_RECT),
		BoosterChromeDraw.key_rect(),
		BoosterChromeDraw.tab_rect(0),
		BoosterChromeDraw.tab_rect(1),
		Rect2(BoosterChromeDraw.CART_LED),
	]
	var pouches: Array[Rect2] = []
	for k: int in shown.size():
		var b: BoosterOpening = shown[k]
		assert_int(b.row).is_equal(k)
		var at: Vector2 = b.pouch_pos()
		var pouch: Rect2 = Rect2(at, Vector2(BoosterArt.BW, BoosterArt.BH))
		# What shows of it: down to its clip (the bottom one's foot stands behind the counter).
		var seen: Rect2 = Rect2(at, Vector2(BoosterArt.BW, b.pouch_clip() - at.y))
		pouches.append(seen)
		var tab: Rect2 = AisleBoardArt.row_tab_rect(b.row)
		var row: Rect2 = Rect2(
			AisleBoardArt.ROW_X,
			AisleBoardArt.row_foot(b.row) - AisleBoardArt.MH,
			BoosterArt.CW,
			AisleBoardArt.MH
		)
		assert_that(at).is_equal(at.floor())
		assert_float(at.x).is_equal(float(AisleBoardArt.ROW_X))
		assert_float(at.x - tab.end.x).is_between(0.0, 4.0)
		assert_float(pouch.get_center().y).is_between(row.position.y, row.end.y)
		assert_bool(pouch.intersects(tab)).is_false()
		assert_float(seen.size.y).is_greater(BoosterArt.BH * 0.8)
		assert_bool(ART.encloses(seen)).is_true()
		for key: Rect2 in keys:
			assert_bool(seen.intersects(key)).override_failure_message(str(key)).is_false()
		for bay: int in page.roulette.count:
			var sign_at: Rect2 = AisleBoardArt.sign_rect(bay, page.roulette.count)
			# The sign's words (its 3 px rim aside) stay clear.
			assert_bool(seen.intersects(sign_at.grow(-3))).is_false()
	assert_bool(pouches[0].intersects(pouches[1])).is_false()
	var board: StartBoard = _board(page)
	board.set_anchors_preset(Control.PRESET_TOP_LEFT)
	for board_size: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		board.size = board_size
		board._resize()
		var frame: Rect2 = Rect2(Vector2.ZERO, board_size).grow(0.5)
		for seen: Rect2 in pouches:
			assert_bool(frame.encloses(_on_screen(page, seen))).is_true()


func _assert_fans(page: BoosterPage) -> void:
	var count: int = page.roulette.count
	var shown: Array[BoosterOpening] = page.shown_boosters()
	assert_int(shown.size()).is_equal(2)
	var keys: Array[Rect2] = [
		Rect2(BoosterArt.TITLE_RECT),
		Rect2(BoosterArt.PRIMARY_RECT),
		BoosterChromeDraw.key_rect(),
		BoosterChromeDraw.message_rect(page),
		BoosterChromeDraw.tab_rect(0),
		BoosterChromeDraw.tab_rect(1),
		Rect2(BoosterChromeDraw.CART_LED),
	]
	var fans: Array[Rect2] = []
	for b: BoosterOpening in shown:
		assert_int(b.state).is_equal(BoosterOpening.State.OPEN)
		var fan: Rect2 = b.fan_rect()
		var sign_at: Rect2 = AisleBoardArt.sign_rect(b.bay, count)
		fans.append(fan)
		assert_bool(ART.encloses(fan)).override_failure_message(str(fan)).is_true()
		# Its row: every card on the row's foot, starting at ROW_X; above the counter's line and
		# below the hung signs.
		assert_bool(b.in_row()).is_true()
		assert_float(fan.position.x).is_equal(float(AisleBoardArt.ROW_X))
		assert_float(fan.end.y).is_equal(AisleBoardArt.row_foot(b.row))
		assert_float(fan.end.y).is_less_equal(float(AisleBoardArt.STAND))
		assert_float(fan.position.y).is_greater(sign_at.end.y)
		# The row's aisle tab: at its left end, the row's height (one px short of its foot), clear
		# of its cards; its glyph tile dead centre in it on whole pixels (round 3 of the play test).
		var tab: Rect2 = AisleBoardArt.row_tab_rect(b.row)
		assert_bool(ART.encloses(tab)).is_true()
		assert_float(tab.position.y).is_equal(fan.position.y)
		assert_float(tab.end.y).is_equal(fan.end.y - 1)
		assert_float(tab.end.x).is_less(fan.position.x)
		var tile: Rect2 = AisleBoardArt.row_tile_rect(b.row)
		assert_bool(tab.encloses(tile)).is_true()
		assert_that(tile.get_center()).is_equal(tab.get_center())
		assert_that(tile.position).is_equal(tile.position.floor())
		for k: int in b.cards.size():
			var full: Rect2 = AisleBoardDraw.hover_rect(b, k)
			assert_bool(ART.encloses(full)).override_failure_message(str(full)).is_true()
			for key: Rect2 in keys:
				assert_bool(full.intersects(key)).override_failure_message(str(key)).is_false()
		for key: Rect2 in keys:
			assert_bool(fan.intersects(key)).override_failure_message(str(key)).is_false()
			assert_bool(tab.intersects(key)).override_failure_message(str(key)).is_false()
		for k: int in b.cards.size() - 1:
			assert_float(b.card_rect(k + 1).position.x).is_greater_equal(b.card_rect(k).end.x)
	assert_int(shown[0].bay).is_less(shown[1].bay)
	# The 1st aisle (the left bay) holds the top row, the 2nd the bottom one, apart.
	assert_int(shown[0].row).is_equal(0)
	assert_int(shown[1].row).is_equal(1)
	assert_float(fans[0].end.y).is_less(fans[1].position.y)
	# Right under their bays when there is room; else as near as the stage and the pair allow.
	var want: Array[float] = AisleBoardArt.fan_centres([shown[0].bay, shown[1].bay], count)
	var apart: float = AisleBoardArt.FAN_HALF * 2 + AisleBoardArt.FAN_GAP
	for k: int in 2:
		var centre: float = AisleBoardArt.bay_centre(shown[k].bay, count)
		assert_float(shown[k].cx).is_equal_approx(want[k], 0.5)
		var edge: float = AisleBoardArt.FAN_HALF + AisleBoardArt.FAN_EDGE
		var fits: bool = true
		for other: int in 2:
			var at: float = AisleBoardArt.bay_centre(shown[other].bay, count)
			fits = fits and at >= edge and at <= ART.size.x - edge
		var far: bool = (
			(
				AisleBoardArt.bay_centre(shown[1].bay, count)
				- AisleBoardArt.bay_centre(shown[0].bay, count)
			)
			>= apart
		)
		if fits and far:
			assert_float(shown[k].cx).is_equal_approx(centre, 0.5)
	var board: StartBoard = _board(page)
	board.set_anchors_preset(Control.PRESET_TOP_LEFT)
	for board_size: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		board.size = board_size
		board._resize()
		var frame: Rect2 = Rect2(Vector2.ZERO, board_size).grow(0.5)
		for fan: Rect2 in fans:
			assert_bool(frame.encloses(_on_screen(page, fan))).is_true()
		_assert_rows_on_screen(page, shown, frame, keys)
		for bay: int in count:
			var sign_at: Rect2 = _on_screen(page, AisleBoardArt.sign_rect(bay, count))
			assert_bool(frame.encloses(sign_at)).is_true()
			(
				assert_bool(frame.encloses(_on_screen(page, AisleBoardArt.bay_rect(bay, count))))
				. is_true()
			)


## On screen: every card of the 1st aisle's booster in one row above every card of the 2nd's, each
## inside the viewport `frame` and clear of the counter and the keys; a hovered card's full card
## clear of the other cards.
func _assert_rows_on_screen(
	page: BoosterPage, shown: Array[BoosterOpening], frame: Rect2, keys: Array[Rect2]
) -> void:
	var rows: Array = [[], []]
	for row: int in 2:
		for k: int in shown[row].cards.size():
			(rows[row] as Array).append(_on_screen(page, shown[row].card_rect(k)))
	var stand: float = AisleBoardArt.STAND
	var counter: Rect2 = _on_screen(page, Rect2(0, stand, ART.size.x, ART.size.y - stand))
	for row: int in 2:
		var first: Rect2 = rows[row][0]
		for r: Rect2 in rows[row]:
			assert_bool(frame.encloses(r)).override_failure_message(str(r)).is_true()
			assert_float(r.position.y).is_equal_approx(first.position.y, 0.01)
			assert_bool(r.intersects(counter)).is_false()
			for key: Rect2 in keys:
				assert_bool(r.intersects(_on_screen(page, key))).is_false()
	for upper: Rect2 in rows[0]:
		for lower: Rect2 in rows[1]:
			assert_float(upper.end.y).is_less(lower.position.y)
	# A hovered card's full card (with its shadow) never covers a card of the other row, nor
	# another card of its own (round 2 of the 2026-11-19 play test), and stays clear of the keys.
	for row: int in 2:
		for k: int in shown[row].cards.size():
			var drawn: Rect2 = _on_screen(page, AisleBoardDraw.hover_drawn_rect(shown[row], k))
			var where: String = "row %d card %d %s" % [row, k, drawn]
			assert_bool(frame.encloses(drawn)).override_failure_message(where).is_true()
			for other: Rect2 in rows[1 - row]:
				assert_bool(drawn.intersects(other)).override_failure_message(where).is_false()
			for j: int in (rows[row] as Array).size():
				if j != k:
					var same: Rect2 = rows[row][j]
					assert_bool(drawn.intersects(same)).override_failure_message(where).is_false()
			for key: Rect2 in keys:
				assert_bool(drawn.intersects(_on_screen(page, key))).is_false()


## The bays tile the wall: six bays apart, each under its own sign, above the counter.
func test_the_bays_and_signs_tile_the_wall() -> void:
	var count: int = 6
	for k: int in count:
		var bay: Rect2 = AisleBoardArt.bay_rect(k, count)
		var sign_at: Rect2 = AisleBoardArt.sign_rect(k, count)
		assert_bool(ART.encloses(bay)).is_true()
		assert_bool(ART.encloses(sign_at)).is_true()
		assert_float(sign_at.end.y).is_less_equal(bay.position.y)
		assert_float(sign_at.position.y).is_greater_equal(28.0)
		assert_float(bay.end.y).is_less_equal(float(BoosterArt.COUNTER_Y))
		assert_float(sign_at.position.x).is_greater_equal(bay.position.x)
		assert_float(sign_at.end.x).is_less_equal(bay.end.x)
		if k > 0:
			assert_float(bay.position.x).is_greater(AisleBoardArt.bay_rect(k - 1, count).end.x)
	var page: BoosterPage = await _page(2)
	for aisle: AisleDefinition in page.run.balance.aisles:
		var words: float = (
			ArtPen.word_texture(BoosterArt.short_name(aisle), Palette.INK, true).get_width()
		)
		assert_float(words).override_failure_message(String(aisle.id)).is_less_equal(
			AisleBoardArt.SIGN_W - 6.0
		)
		assert_object(AisleBoardArt.bay(aisle, 100, true)).is_not_null()


## RESTOCK keeps its rule (the same aisle, a new booster) and its staging is the bay's: the cards
## leave the CART count at once and fly back into their bay, which throws a fresh booster that
## waits sealed for its click.
func test_restock_sends_the_cards_back_to_their_bay_for_a_new_booster() -> void:
	var page: BoosterPage = await _page(_restock_count())
	var board: StartBoard = _board(page)
	board._input(_key(KEY_R))
	assert_bool(page.restock_armed).is_false()
	_play(page)
	var first: BoosterOpening = page.shown_boosters()[0]
	var aisle: StringName = first.aisle
	var bay: int = first.bay
	var cx: float = first.cx
	var old: Array[CardDefinition] = first.cards.duplicate()
	board._input(_key(KEY_R))
	assert_bool(page.restock_armed).is_true()
	# v1.36: CANCEL is RESTOCK's own key (and Esc); the primary key says what comes next, unlit,
	# and refuses with the message.
	var label: Array = page.primary_label()
	assert_str(String(label[0])).is_equal("PICK 1")
	assert_str(String(label[1])).is_equal("TO RETURN")
	assert_bool(label[2]).is_false()
	assert_bool(page.primary("key")).is_false()
	assert_bool(page.restock_armed).is_true()
	assert_str(page.hint_line()).is_equal(BoosterPage.RESTOCK_NEXT_HINT)
	assert_bool(_hit_ids(page).has("rcards%d" % first.index)).is_true()
	var full: int = page.cart_target()
	board._input(_key(KEY_1))
	assert_int(page.run.start_setup.restock_booster()).is_equal(first.index)
	assert_int(first.state).is_equal(BoosterOpening.State.SEALED)
	assert_bool(first.restocked).is_true()
	assert_str(String(first.aisle)).is_equal(String(aisle))
	assert_int(first.bay).is_equal(bay)
	assert_float(first.cx).is_equal(cx)
	assert_array(first.old_cards).is_equal(old)
	assert_float(first.return_t).is_equal(page.now)
	assert_int(page.cart_n).is_equal(full - old.size())
	assert_bool(page.page_done()).is_false()
	assert_bool(page.roulette.landed(first)).is_false()
	# The cards fly toward the bay; then the bay throws the booster, which waits for its click.
	assert_float(first.fly_from.x).is_equal_approx(
		AisleBoardArt.bay_centre(bay, page.roulette.count), 1.0
	)
	_run(page, 8.0)
	assert_int(first.state).is_equal(BoosterOpening.State.SEALED)
	assert_bool(page.page_done()).is_false()
	_play(page)
	assert_int(first.state).is_equal(BoosterOpening.State.OPEN)
	assert_bool(page.run.start_setup.boosters[first.index].opened).is_true()
	assert_bool(page.page_done()).is_true()
	assert_int(page.cart_shown).is_equal(full)
	assert_float(first.cx).is_equal(cx)
	board._input(_key(KEY_R))
	assert_bool(page.restock_armed).is_false()
	assert_str(page.hint_line()).is_equal("RESTOCK USED")


## At 6 completed aisles the light still lands on today's two bays only (PICK 2 OF 3 was
## removed in v1.46): the other bays shut, and the two boosters are thrown and wait for clicks.
func test_a_veteran_gets_two_bays_and_no_pick() -> void:
	var page: BoosterPage = await _page(6)
	var roulette: AisleRoulette = page.roulette
	assert_int(page.boosters.size()).is_equal(2)
	_run(page, 14.0)
	assert_int(roulette.land_t.size()).is_equal(2)
	assert_int(roulette.phase).is_equal(AisleRoulette.Phase.DEAL)
	_run(page, 10.0)
	_play(page)
	for b: BoosterOpening in page.boosters:
		assert_int(b.state).is_equal(BoosterOpening.State.OPEN)
		assert_float(roulette.shut_frac(b.bay)).is_equal(0.0)
	assert_bool(page.page_done()).is_true()
	_assert_fans(page)


## The fan shows compact cards (the picture, the price, the family glyph, the name); a hovered
## card pops its full card with its rule. One switch in the data (compact_fan_cards) shows the
## full cards in the fan instead, with their hover tips.
func test_the_fan_cards_are_compact_and_the_rule_pops_on_hover() -> void:
	var page: BoosterPage = await _page(2)
	assert_bool(page.tuning.compact_fan_cards).is_true()
	_play(page)
	var b: BoosterOpening = page.shown_boosters()[0]
	assert_bool(b.compact).is_true()
	assert_float(float(b.card_h())).is_equal(float(AisleBoardArt.MH))
	assert_float(b.card_rect(0).size.y).is_less(float(BoosterArt.CH))
	assert_object(AisleBoardArt.compact_face(b.cards[0], b.rares[0])).is_not_null()
	assert_bool(AisleBoardDraw.hovered(page).is_empty()).is_true()
	assert_bool(BoosterChromeDraw.tip_entries(page).is_empty()).is_true()
	page.mouse = b.card_rect(1).get_center()
	page.advance(0.0)
	page.advance(0.0)
	assert_str(page.hover_id).is_equal("card%d_1" % b.index)
	var found: Dictionary = AisleBoardDraw.hovered(page)
	assert_object(found.b).is_same(b)
	assert_int(found.k).is_equal(1)
	var full: Rect2 = AisleBoardDraw.hover_rect(b, 1)
	assert_that(full.size).is_equal(Vector2(BoosterArt.CW, BoosterArt.CH))
	assert_float(full.position.x).is_equal(b.card_rect(1).position.x)
	# The switch: full cards in the fan, their tips back, no popup.
	b.compact = false
	assert_float(float(b.card_h())).is_equal(float(BoosterArt.CH))
	assert_float(b.fan_rect().end.y).is_equal(float(AisleBoardArt.STAND))
	assert_bool(ART.encloses(b.fan_rect())).is_true()
	assert_bool(AisleBoardDraw.hovered(page).is_empty()).is_true()
	assert_bool(BoosterChromeDraw.tip_entries(page).is_empty()).is_false()


## Page 1 no longer shows the clock, the aisle counter, the YOUR STORE board, STOCKED!, a hint
## line, the regulars' crate or the COMMON / RARE tabs: none of their words is drawn, no hit of
## theirs exists, and the hint line is empty until a refused action flashes its message.
func test_the_page_shows_only_the_board() -> void:
	var page: BoosterPage = await _page(_restock_count())
	ArtPen._words.clear()
	for step: int in 400:
		_run(page, 0.05)
		if step == 300:
			_open_landed(page)
		if step % 20 == 0:
			await get_tree().process_frame
	assert_bool(page.page_done()).is_true()
	await get_tree().process_frame
	await get_tree().process_frame
	var drew_store: bool = false
	for key: String in ArtPen._words:
		var word: String = key.get_slice("|", 0)
		drew_store = drew_store or word == "YOUR BUILD"
		for gone: String in [
			"AISLES", "STOCKED", "OPENING", "COMMON", "RARE", "REGULARS", "RUN-ONLY"
		]:
			assert_bool(word.contains(gone)).override_failure_message(key).is_false()
		(
			assert_bool(word.contains(":00") or word.contains(":30"))
			. override_failure_message(key)
			. is_false()
		)
	assert_bool(drew_store).override_failure_message(str(ArtPen._words.keys())).is_true()
	assert_str(page.hint_line()).is_equal("")
	for b: BoosterOpening in page.boosters:
		assert_bool(b.tabs).is_false()
	var ids: Array[String] = _hit_ids(page)
	for gone: String in ["crate", "rollup", "tab1"]:
		assert_bool(ids.has(gone)).is_false()
	for id: String in ids:
		assert_bool(id.begins_with("hit")).is_false()
	assert_array(ids).contains(["tab2", "restock", "title", "primary"])
	for entry: Dictionary in page.hits:
		(
			assert_bool(ART.encloses(entry.rect as Rect2))
			. override_failure_message(str(entry.id))
			. is_true()
		)
	# The regulars are in the cart from the start: the CART count holds them before any booster.
	var fresh: BoosterPage = await _page(2)
	assert_int(fresh.cart_shown).is_equal(fresh.run.starter.core_cards.size())
	assert_int(fresh.run.starter.core_cards.size()).is_greater(0)
	assert_int(page.run.start_setup.stock_aisles.size()).is_equal(2)
	assert_array(page.run.stock.aisle_ids).is_equal(page.run.start_setup.stock_aisles)


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


## A resume keeps what was opened and plays no light: the open bays stand lit, the others shut,
## the fans open under their bays.
func test_a_resume_shows_the_opened_boosters_without_a_spin() -> void:
	var page: BoosterPage = await _page(2)
	_play(page)
	var bays: Array[int] = [page.boosters[0].bay, page.boosters[1].bay]
	var resumed: ShiftScreen = auto_free(SCREEN.instantiate())
	add_child(resumed)
	await get_tree().process_frame
	var again: BoosterPage = resumed._cart_reveal.board.store
	again.frozen = true
	assert_bool(again.roulette.hops.is_empty()).is_true()
	assert_int(again.roulette.phase).is_equal(AisleRoulette.Phase.DEAL)
	for b: BoosterOpening in again.boosters:
		assert_int(b.state).is_equal(BoosterOpening.State.OPEN)
		assert_bool(bays.has(b.bay)).is_true()
		assert_float(again.roulette.shut_frac(b.bay)).is_equal(0.0)
	again.advance(0.0)
	assert_bool(again.page_done()).is_true()
	_assert_fans(again)


## A RESTOCK after page 2 was opened leaves a sealed booster at stage BUILD: a resume opens on
## page 1, where the bay throws the fresh booster again and it opens by itself; the clock-in is
## refused until then.
func test_a_resume_with_a_sealed_restock_opens_on_page_one() -> void:
	var page: BoosterPage = await _page(_restock_count())
	_play(page)
	var board: StartBoard = _board(page)
	board._choice.mark_build.call()
	assert_int(page.run.start_setup.stage).is_equal(StartSetup.Stage.BUILD)
	board._input(_key(KEY_R))
	board._input(_key(KEY_1))
	var index: int = page.run.start_setup.restock_booster()
	assert_int(index).is_greater_equal(0)
	assert_bool(page.run.start_setup.all_open()).is_false()
	assert_int(page.run.start_setup.stage).is_equal(StartSetup.Stage.BUILD)
	var resumed: ShiftScreen = auto_free(SCREEN.instantiate())
	add_child(resumed)
	await get_tree().process_frame
	var again: StartBoard = resumed._cart_reveal.board
	again.store.frozen = true
	assert_int(again.run.start_setup.stage).is_equal(StartSetup.Stage.BUILD)
	assert_int(again.page).is_equal(1)
	assert_bool(again.store.visible).is_true()
	assert_bool(again.clock_in()).is_false()
	assert_int(again.store.boosters[index].state).is_equal(BoosterOpening.State.SEALED)
	assert_bool(again.store.roulette.hops.is_empty()).is_true()
	# Thrown again, it waits sealed for its click (the other booster stands open as saved).
	_run(again.store, 8.0)
	assert_int(again.store.boosters[index].state).is_equal(BoosterOpening.State.SEALED)
	assert_int(again.store.boosters[1 - index].state).is_equal(BoosterOpening.State.OPEN)
	assert_bool(again.store.page_done()).is_false()
	_play(again.store)
	assert_int(again.store.boosters[index].state).is_equal(BoosterOpening.State.OPEN)
	assert_bool(again.store.page_done()).is_true()


## Reduced motion shows each end state at once: no light, the bays open and shut as dealt, the
## boosters sealed on the counter at once; opened, they fade open within a second or two.
func test_reduced_motion_shows_the_end_states() -> void:
	var page: BoosterPage = await _page(2, true)
	assert_bool(page.roulette.hops.is_empty()).is_true()
	for bay: int in page.roulette.count:
		assert_float(page.roulette.shut_frac(bay)).is_equal(
			0.0 if page.roulette.booster_at(bay) != null else 1.0
		)
	for b: BoosterOpening in page.boosters:
		assert_bool(page.roulette.landed(b)).is_true()
		assert_int(b.state).is_equal(BoosterOpening.State.SEALED)
	_open_landed(page)
	_run(page, 3.0)
	assert_bool(page.page_done()).is_true()
	assert_bool(BoosterChromeDraw.primary_lift(page) == 0).is_true()


## The RESTOCK key (v1.32 feedback) stands on the floor row just left of the primary key, as tall,
## apart from the title key and a flashed message; a profile without RESTOCK never sees it.
func test_the_restock_key_stands_left_of_the_primary_key() -> void:
	var locked: BoosterPage = await _page(maxi(0, _restock_count() - 1))
	_play(locked)
	assert_bool(_hit_ids(locked).has("restock")).is_false()
	_board(locked)._input(_key(KEY_R))
	assert_bool(locked.restock_armed).is_false()
	assert_str(locked.hint_line()).is_equal("")
	var page: BoosterPage = await _page(_restock_count())
	_play(page)
	var key: Rect2 = BoosterChromeDraw.key_rect()
	var primary: Rect2 = Rect2(BoosterArt.PRIMARY_RECT)
	var title: Rect2 = Rect2(BoosterArt.TITLE_RECT)
	assert_float(key.end.x).is_equal(primary.position.x - BoosterArt.KEY_GAP)
	assert_float(key.position.y).is_equal(primary.position.y)
	assert_float(key.size.y).is_equal(primary.size.y)
	page.flash("COULD NOT SAVE. TRY AGAIN")
	var message: Rect2 = BoosterChromeDraw.message_rect(page)
	assert_float(ArtPen.pix_width(page.hint_line())).is_less(message.size.x - 8)
	for other: Rect2 in [primary, title, message]:
		assert_bool(key.intersects(other)).override_failure_message(str(other)).is_false()
	assert_bool(message.intersects(title)).is_false()
	assert_bool(message.intersects(primary)).is_false()
	assert_bool(_hit_rect(page, "restock") == key).is_true()


## v1.32 feedback (the user's pick C "press-bob"): once NEXT is armed the primary key hops (1, 2, 1,
## 0 art px), then its face bobs up only 0 or 1 art px; it rests while hovered and under reduced
## motion; no bulb rim on either page; its hit rect stays put.
func test_the_armed_primary_key_press_bobs_without_bulbs() -> void:
	assert_bool(BuildPageDraw.new().has_method("_armed_rim")).is_false()
	assert_bool(BoosterPageDraw.new().has_method("key_grow")).is_false()
	var page: BoosterPage = await _page(2)
	_play(page)
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
	_open_landed(still)
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


## The page (frozen on its clock) of a new run with `completed` aisles complete (`guided`: the
## guided first run).
func _page(
	completed: int, reduced: bool = false, guided: bool = false, seed_value: int = SEED
) -> BoosterPage:
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
	screen.start_new_run(seed_value, true, true, guided)
	var page: BoosterPage = screen._cart_reveal.board.store
	page.frozen = true
	return page


static func _board(page: BoosterPage) -> StartBoard:
	var node: Node = page.get_parent()
	while node != null and not node is StartBoard:
		node = node.get_parent()
	return node as StartBoard


## Plays the page to its end: the light skipped, every booster opened.
static func _play(page: BoosterPage) -> void:
	page.roulette.skip()
	for step: int in 900:
		if page.page_done():
			return
		_open_landed(page)
		page.advance(STEP)


## Opens every booster waiting sealed on the counter (their clicks, round 2 of the 2026-11-19 play
## test: no booster opens by itself).
static func _open_landed(page: BoosterPage) -> void:
	var next: BoosterOpening = page.openings.next_sealed()
	while next != null and page.openings.open_booster(next.index, "click"):
		next = page.openings.next_sealed()


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


func _save() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(_folder.path_join(SaveService.RUN_FILE)))


static func _key(keycode: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.pressed = true
	key.keycode = keycode
	return key


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
