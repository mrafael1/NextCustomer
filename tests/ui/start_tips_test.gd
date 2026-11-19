extends GdUnitTestSuite
## The start screen's hover tips (v1.33, hover tips B; StartTips over the canvas pages, shown by
## StartBoard's GlyphTips) on the real screen in a viewport of 1280x720 and of 1920x1080: page 1's
## regulars (CLICK SWAP opens the swap window; locked, their live line says so), an opened booster
## card and its family chip, the swap window's cards and basket, page 2's spread pack card; each
## tip opens over its target and stays inside the viewport. No tip while a card is dragged in the
## swap window or while a booster opens. The pages run on their own clocks: the tests freeze them.

const SCREEN := preload("res://ui/shift_screen.tscn")
const SEED := 20261103
const STEP := 1.0 / 60.0
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]

var _folder: String


func before_test() -> void:
	_folder = "user://start_tips_test_%d" % Time.get_ticks_usec()
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_event_log().use_folder(_folder)


func after_test() -> void:
	await get_tree().process_frame
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file))
		DirAccess.remove_absolute(_folder)


## Page 1 at both sizes. Compact fan cards (the default) have no hover tip: the full card pops up
## instead. With compact_fan_cards off, each opened booster card and a family chip open their tip
## over them, inside the viewport (with its boxes); a family chip's is that family's.
func test_page_one_tips_open_inside_the_viewport() -> void:
	for size: Vector2i in SIZES:
		var page: BoosterPage = await _page(size, 1)
		_stocked(page)
		var tips: GlyphTips = _board(page).tips
		page.advance(0.0)
		assert_array(page.tips.shown_targets()).is_empty()
		for b: BoosterOpening in page.boosters:
			b.compact = false
		page.advance(0.0)
		var chips: int = 0
		for b: BoosterOpening in page.boosters:
			for k: int in b.cards.size():
				var key: String = "card%d_%d|" % [b.index, k]
				var card: TipTarget = page.tips.target_for(key)
				assert_object(card).override_failure_message(key).is_not_null()
				_assert_opens(tips, card, size)
				assert_str(tips.tip().spec.title).is_equal(b.cards[k].display_name.to_upper())
				var chip: TipTarget = _chip(page.tips, key)
				if chip != null:
					chips += 1
					assert_bool(card.get_global_rect().encloses(chip.get_global_rect())).is_true()
					_assert_opens(tips, chip, size)
					assert_int(tips.tip().spec.kind).is_equal(TipSpec.Kind.FAMILY)
		assert_int(chips).is_greater(0)


## The swap window at both sizes: its fan cards (a card the copy limit keeps out says so in its live
## line) and the basket's items open their tips inside the viewport.
func test_swap_window_tips_open_inside_the_viewport() -> void:
	for size: Vector2i in SIZES:
		var page: BoosterPage = await _page(size, 1)
		_stocked(page)
		assert_bool(page.swap.open_window(false)).is_true()
		_run(page, 1.0)
		for bi: int in page.swap.boosters.size():
			page.swap.open_booster(bi, "key")
		_copy_limit_one(page)
		_run(page, 3.0)
		var tips: GlyphTips = _board(page).tips
		var shown: int = 0
		var blocked: int = 0
		for n: int in page.swap.pieces.size():
			var piece: SwapPiece = page.swap.pieces[n]
			if piece.regular:
				continue
			var target: TipTarget = page.tips.target_for("piece%d|" % n)
			assert_object(target).override_failure_message("piece%d" % n).is_not_null()
			_assert_opens(tips, target, size)
			shown += 1
			var spec: TipSpec = tips.tip().spec
			if page.swap.blocked(piece):
				blocked += 1
				assert_str(spec.live).is_equal(
					StartTips.COPY_LIMIT_LIVE % page.run.starter.copy_max
				)
				assert_int(spec.live_kind).is_equal(TipSpec.Live.BAD)
		assert_int(shown).is_greater(0)
		assert_int(blocked).override_failure_message("no copy-limited card seen").is_greater(0)
		for slot: int in page.run.starter.core_cards.size():
			var basket: TipTarget = page.tips.target_for("slot%d|" % slot)
			assert_object(basket).override_failure_message("slot%d" % slot).is_not_null()
			_assert_opens(tips, basket, size)
			assert_str(tips.tip().spec.tag).is_equal(StartTips.REGULAR_TAG)


## No tip while a card is held in the swap window (a shown tip closes), nor while a booster opens.
func test_no_tip_while_dragging_or_opening() -> void:
	var page: BoosterPage = await _page(SIZES[0], 1)
	var tips: GlyphTips = _board(page).tips
	for b: BoosterOpening in page.boosters:
		b.compact = false
	_run(page, 0.5)
	assert_bool(page.roulette.busy()).is_true()
	assert_bool(_board(page).tips_blocked()).is_true()
	assert_array(page.tips.shown_targets()).is_empty()
	page.roulette.skip()
	# The boosters wait sealed for their clicks (round 2 of the 2026-11-19 play test).
	for sealed: BoosterOpening in page.shown_boosters():
		page.openings.open_booster(sealed.index, "click")
	_run(page, 0.3)
	assert_bool(page.openings.opening_now()).is_true()
	assert_bool(_board(page).tips_blocked()).is_true()
	assert_array(page.tips.shown_targets()).is_empty()
	var fan: Rect2 = page.boosters[0].card_rect(0)
	tips.point_at(_global(page, fan.get_center()))
	tips._process(GlyphTips.SHOW_DELAY_S + 0.05)
	assert_object(tips.shown_glyph()).is_null()
	# The swap window: a tip shows, then a card is grabbed and dragged.
	_stocked(page)
	assert_bool(page.swap.open_window(false)).is_true()
	_run(page, 1.0)
	for bi: int in page.swap.boosters.size():
		page.swap.open_booster(bi, "key")
	_run(page, 3.0)
	var piece: SwapPiece = null
	for candidate: SwapPiece in page.swap.pieces:
		if not candidate.regular:
			piece = candidate
			break
	var n: int = page.swap.pieces.find(piece)
	var target: TipTarget = page.tips.target_for("piece%d|" % n)
	_assert_opens(tips, target, SIZES[0])
	page.mouse = piece.pos
	page.swap.press(piece.pos)
	page.mouse = piece.pos + Vector2(20, 30)
	page.advance(STEP)
	assert_object(page.swap.held).is_same(piece)
	assert_bool(_board(page).tips_blocked()).is_true()
	assert_array(page.tips.shown_targets()).is_empty()
	tips._process(STEP)
	assert_object(tips.shown_glyph()).is_null()
	tips.point_at(_global(page, SwapWindowDraw.item_centre(0)))
	tips._process(GlyphTips.SHOW_DELAY_S + 0.05)
	assert_object(tips.shown_glyph()).is_null()


## Points the board's tips at `target`, waits out the delay and checks its tip shows, inside the
## viewport of `size`, its boxes too.
func _assert_opens(tips: GlyphTips, target: TipTarget, size: Vector2i) -> void:
	var where: String = "%s %s" % [size, target.get_meta(StartTips.KEY_META, "")]
	tips.hide_tip()
	tips.point_at(Vector2(-50, -50))
	tips._process(STEP)
	tips.point_at(target.get_global_rect().get_center())
	tips._process(GlyphTips.SHOW_DELAY_S + 0.05)
	assert_object(tips.shown_glyph()).override_failure_message(where).is_same(target)
	tips.tip().scale = Vector2.ONE
	var screen: Rect2 = Rect2(Vector2.ZERO, Vector2(size))
	var card: Rect2 = tips.tip().get_global_rect()
	assert_bool(screen.encloses(card)).override_failure_message("%s %s" % [where, card]).is_true()
	for box: TipCard in tips.boxes():
		box.scale = Vector2.ONE
		var rect: Rect2 = box.get_global_rect()
		(
			assert_bool(screen.encloses(rect))
			. override_failure_message("%s %s" % [where, rect])
			. is_true()
		)


static func _chip(tips: StartTips, key: String) -> TipTarget:
	for target: TipTarget in tips.shown_targets():
		var shown: String = target.get_meta(StartTips.KEY_META, "")
		if shown.begins_with(key) and shown.contains("|fam"):
			return target
	return null


## Art point `at` on the page, in its viewport's coordinates.
static func _global(page: BoosterPage, at: Vector2) -> Vector2:
	return page.get_global_transform() * (at * ArtPen.UNIT)


## The page (frozen on its clock, reduced motion off) of a new run with `completed` aisles
## complete, on a screen in a viewport of `size`.
func _page(size: Vector2i, completed: int) -> BoosterPage:
	var sub: SubViewport = auto_free(SubViewport.new())
	sub.size = size
	add_child(sub)
	var screen: ShiftScreen = SCREEN.instantiate()
	sub.add_child(screen)
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
	await get_tree().process_frame
	var page: BoosterPage = screen._cart_reveal.board.store
	page.frozen = true
	return page


static func _board(page: BoosterPage) -> StartBoard:
	var node: Node = page.get_parent()
	while node != null and not node is StartBoard:
		node = node.get_parent()
	return node as StartBoard


## Rolls up, opens every booster and lets STOCKED! come.
## Makes the copy limit keep one fan card out: its card fills the first copy_max regular slots
## (as their originals too, so they read as regulars, not swaps).
static func _copy_limit_one(page: BoosterPage) -> void:
	for piece: SwapPiece in page.swap.pieces:
		if piece.regular:
			continue
		for slot: int in page.run.starter.copy_max:
			page.run.starter.core_cards[slot] = piece.card
			page.run.start_setup.originals[slot] = piece.card
		return


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


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
