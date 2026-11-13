extends GdUnitTestSuite
## The swap window, YOUR REGULARS (SwapWindow, v1.32 swap window; mock-up
## start_regulars_swap.html variant A) on the real screen: its geometry at 1280x720 and 1920x1080
## (inside the stage, the boosters' fans, the basket's slots, the LED and the keys apart, the drop
## targets where the slots are drawn), NEXT's one stop while a swap is unused (DONE then goes on
## to YOUR BUILD), no stop without a swap, the click-then-click path and the drag, a trade, a
## refusal, the undo by dragging out, RESET, the page-1 play-in and the locked window. The page
## runs on its own clock: the tests freeze it and step it.

const SCREEN := preload("res://ui/shift_screen.tscn")
const SEED := 20261103
const STEP := 1.0 / 60.0
const ART := Rect2(0, 0, 640, 360)

var _folder: String


func before_test() -> void:
	_folder = "user://swap_window_test_%d" % Time.get_ticks_usec()
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_event_log().use_folder(_folder)


func after_test() -> void:
	await get_tree().process_frame
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file))
		DirAccess.remove_absolute(_folder)


## At both sizes the window sits on the stage inside the board, its boosters' fans clear of each
## other and of the basket, the basket's slots apart and inside the window, the LED, RESET, the
## hint LED and DONE clear of the slots; every drop target is where its slot is drawn.
func test_the_window_fits_the_stage_at_both_sizes() -> void:
	for size: Vector2 in [Vector2(1280, 720), Vector2(1920, 1080)]:
		var page: BoosterPage = await _page(2)
		var board: StartBoard = _board(page)
		board.set_anchors_preset(Control.PRESET_TOP_LEFT)
		board.size = size
		board._resize()
		_stocked(page)
		assert_bool(page.swap.open_window(false)).is_true()
		for bi: int in page.swap.boosters.size():
			page.swap.open_booster(bi, "key")
		_run(page, 3.0)
		var frame: Rect2 = board.get_global_rect()
		var window: Rect2 = _on_screen(page, SwapWindowDraw.RECT)
		assert_bool(frame.encloses(window)).override_failure_message(str(size)).is_true()
		assert_bool(ART.encloses(SwapWindowDraw.RECT)).is_true()
		var fans: Array[Rect2] = []
		for bi: int in page.swap.boosters.size():
			var first: Vector2 = SwapWindowDraw.fan_centre(bi, 0)
			var last: Vector2 = SwapWindowDraw.fan_centre(bi, 2)
			var fan: Rect2 = Rect2(
				first - Vector2(BoosterArt.CW, BoosterArt.CH) / 2.0,
				last - first + Vector2(BoosterArt.CW, BoosterArt.CH)
			)
			assert_bool(SwapWindowDraw.RECT.encloses(fan)).is_true()
			var pouch: Rect2 = Rect2(
				SwapWindowDraw.pouch_pos(page.swap.boosters[bi].cx),
				Vector2(BoosterArt.BW, BoosterArt.BH)
			)
			assert_bool(SwapWindowDraw.RECT.encloses(pouch)).is_true()
			fans.append(fan)
		assert_bool(fans[0].intersects(fans[1])).is_false()
		var keys: Array[Rect2] = [
			SwapWindowDraw.LED_RECT,
			SwapWindowDraw.RESET_RECT,
			SwapWindowDraw.HINT_RECT,
			SwapWindowDraw.DONE_RECT
		]
		for slot: int in page.run.starter.core_cards.size():
			var target: Rect2 = SwapWindowDraw.slot_rect(slot)
			assert_bool(SwapWindowDraw.RECT.encloses(target)).is_true()
			for fan: Rect2 in fans:
				assert_bool(fan.intersects(target)).is_false()
			for key: Rect2 in keys:
				assert_bool(key.intersects(target)).override_failure_message(str(key)).is_false()
			for other: int in slot:
				assert_bool(SwapWindowDraw.slot_rect(other).intersects(target)).is_false()
			assert_int(SwapWindowDraw.slot_at(target.get_center())).is_equal(slot)
			assert_int(SwapWindowDraw.slot_at(target.position + Vector2.ONE)).is_equal(slot)
			assert_int(SwapWindowDraw.slot_at(target.end - Vector2.ONE * 2)).is_equal(slot)
			assert_bool(target.has_point(SwapWindowDraw.item_centre(slot))).is_true()
		assert_int(SwapWindowDraw.slot_at(fans[0].get_center())).is_equal(-1)
		for entry: Dictionary in page.hits:
			assert_bool(ART.encloses(entry.rect as Rect2)).is_true()
			assert_bool(frame.encloses(_on_screen(page, entry.rect))).is_true()
		# Every resting piece's hit is where it is drawn, and no two fan cards' hits overlap.
		var cards: Array[Rect2] = []
		for entry: Dictionary in page.hits:
			var piece: SwapPiece = entry.get("piece") as SwapPiece
			if piece != null and not piece.item:
				assert_bool((entry.rect as Rect2).has_point(piece.pos)).is_true()
				cards.append(entry.rect)
		assert_int(cards.size()).is_equal(6)
		for k: int in cards.size():
			for other: int in k:
				assert_bool(cards[k].intersects(cards[other])).is_false()


## While a swap is unused, NEXT reads SWAP REGULARS and its first press opens the window (the page
## stays); Esc closes it without going on, and the next NEXT goes to YOUR BUILD. Opened from
## NEXT, DONE goes on to YOUR BUILD after the play-in.
func test_next_stops_once_at_the_swap_window() -> void:
	var page: BoosterPage = await _page(2)
	var board: StartBoard = _board(page)
	_stocked(page)
	assert_array(page.primary_label()).is_equal(["NEXT ›", "SWAP REGULARS", true])
	assert_str(page.hint_line()).is_equal("CLICK YOUR REGULARS TO SWAP")
	board._input(_key(KEY_ENTER))
	assert_bool(page.swap.active).is_true()
	assert_bool(page.swap.from_next).is_true()
	assert_int(board.page).is_equal(1)
	board._input(_key(KEY_ESCAPE))
	assert_bool(page.swap.active).is_false()
	assert_int(board.page).is_equal(1)
	_run(page, 0.5)
	assert_array(page.primary_label()).is_equal(["NEXT ›", "YOUR BUILD", true])
	board._input(_key(KEY_ENTER))
	assert_int(board.page).is_equal(2)
	var again: BoosterPage = await _page(2)
	var other: StartBoard = _board(again)
	_stocked(again)
	other._input(_key(KEY_ENTER))
	assert_bool(again.swap.active).is_true()
	assert_array(SwapWindowDraw.done_label(again)).is_equal(["DONE", "TO YOUR BUILD"])
	other._input(_key(KEY_ENTER))
	assert_bool(again.swap.active).is_false()
	assert_int(other.page).is_equal(1)
	_run(again, again.tuning.swap_next_hold_s + 0.1)
	assert_int(other.page).is_equal(2)


## With no swap unlocked (no completed aisle), NEXT never stops: it goes to YOUR BUILD.
func test_no_stop_without_a_swap() -> void:
	var page: BoosterPage = await _page(0)
	var board: StartBoard = _board(page)
	_stocked(page)
	assert_array(page.primary_label()).is_equal(["NEXT ›", "YOUR BUILD", true])
	assert_str(page.hint_line()).is_equal("THE STORE IS STOCKED")
	board._input(_key(KEY_ENTER))
	assert_bool(page.swap.active).is_false()
	assert_int(board.page).is_equal(2)


## A click on a card, then a click on a slot, swaps it (saved, logged); a card dropped on the
## swapped slot trades with it (no extra swap); a third card on another slot is refused (NO SWAPS
## LEFT) and bounces home; the swapped item dragged out of the basket is undone; the OUT regular
## dragged home puts it back; RESET puts every regular back. DONE plays the swapped regulars into
## page 1's basket.
func test_click_then_click_drag_trade_refuse_undo_and_reset() -> void:
	var page: BoosterPage = await _page(1)
	var board: StartBoard = _board(page)
	_stocked(page)
	var run: RunState = page.run
	_click(page, BoosterChromeDraw.CRATE_RECT.get_center())
	var window: SwapWindow = page.swap
	assert_bool(window.active).is_true()
	assert_bool(window.from_next).is_false()
	_run(page, 1.0)
	board._input(_key(KEY_1))
	board._input(_key(KEY_2))
	_run(page, 3.0)
	assert_array(run.start_setup.swap_opened).has_size(2)
	var cards: Array[SwapPiece] = _fitting(page, 0)
	assert_int(cards.size()).is_greater_equal(2)
	var original: CardDefinition = run.starter.core_cards[0]
	var slot0: Vector2 = SwapWindowDraw.item_centre(0)
	# Click, then click: the card follows the pointer, the second click drops it.
	_click(page, cards[0].pos)
	assert_object(window.held).is_same(cards[0])
	assert_bool(window.sticky).is_true()
	_move(page, slot0)
	_run(page, 0.05)
	assert_int(window.hover_slot).is_equal(0)
	_click(page, slot0)
	assert_object(window.held).is_null()
	assert_object(run.starter.core_cards[0]).is_same(cards[0].card)
	assert_array(_saved_regulars()).contains([String(cards[0].card.id)])
	_run(page, 1.0)
	# The regular it replaced rests OUT where the card was.
	var out: SwapPiece = _regular(window, 0)
	assert_vector(out.pos).is_equal(SwapWindowDraw.fan_centre(cards[0].booster, cards[0].k))
	assert_bool(cards[0].item).is_true()
	# A drag of a second card onto the swapped slot trades.
	_drag(page, cards[1].pos, slot0)
	assert_object(run.starter.core_cards[0]).is_same(cards[1].card)
	assert_int(StartSetupRules.applied_swaps(run)).is_equal(1)
	_run(page, 1.0)
	assert_bool(cards[0].item).is_false()
	# No swap left: a card onto another slot is refused and bounces home.
	var refused: SwapPiece = _any_card(window, cards[1])
	_drag(page, refused.pos, SwapWindowDraw.item_centre(2))
	assert_str(window.err_text).is_equal("NO SWAPS LEFT")
	assert_int(window.err_slot).is_equal(2)
	assert_object(run.starter.core_cards[2]).is_same(run.start_setup.originals[2])
	_run(page, 1.0)
	assert_vector(refused.pos).is_equal(SwapWindowDraw.fan_centre(refused.booster, refused.k))
	# The swapped item dragged out of the basket: undone.
	_drag(page, slot0, Vector2(320, 120))
	assert_object(run.starter.core_cards[0]).is_same(original)
	_run(page, 1.0)
	assert_vector(out.pos).is_equal(SwapWindowDraw.item_centre(0))
	# Swapped again, then the OUT regular dragged home puts it back.
	_drag(page, cards[0].pos, slot0)
	_run(page, 1.0)
	_drag(page, out.pos, SwapWindowDraw.item_centre(1))
	assert_str(window.err_text).is_equal("BACK TO ITS SPOT")
	_run(page, 1.0)
	_drag(page, out.pos, slot0)
	assert_object(run.starter.core_cards[0]).is_same(original)
	_run(page, 1.0)
	# RESET (R) after a swap.
	_drag(page, cards[0].pos, slot0)
	board._input(_key(KEY_R))
	assert_array(run.starter.core_cards).is_equal(run.start_setup.originals)
	_run(page, 1.0)
	_drag(page, cards[0].pos, slot0)
	assert_object(run.starter.core_cards[0]).is_same(cards[0].card)
	_run(page, 1.0)
	var events: Array[Dictionary] = _logged("staple_swap")
	var vias: Array[String] = []
	for event: Dictionary in events:
		vias.append(String(event.get("via", "")))
	assert_array(vias).contains(["click", "drag", "reset"])
	# DONE: back to page 1, the swapped regular plays in (the old one drops away first).
	page.primary("click")
	assert_bool(window.active).is_false()
	assert_int(board.page).is_equal(1)
	assert_bool(page.swap_from.has(0)).is_true()
	assert_object(page.swap_from[0]).is_same(original)
	assert_float(page.swap_t[0]).is_greater(page.now)
	_run(page, 1.0)
	assert_int(board.page).is_equal(1)


## A swapped item clicked, then dropped on its own slot, stays swapped with no rule call (no
## refusal, no flash); Esc while it is held sends it home still swapped; R while it is held still
## resets. The window reopened has fresh reasons (RESTOCK may have changed the cards counted).
func test_own_slot_drop_and_cancel_keep_the_swap() -> void:
	var page: BoosterPage = await _page(1)
	var board: StartBoard = _board(page)
	_stocked(page)
	var run: RunState = page.run
	var window: SwapWindow = page.swap
	assert_bool(window.open_window(false)).is_true()
	_run(page, 1.0)
	board._input(_key(KEY_1))
	board._input(_key(KEY_2))
	_run(page, 3.0)
	var cards: Array[SwapPiece] = _fitting(page, 0)
	var slot0: Vector2 = SwapWindowDraw.item_centre(0)
	_drag(page, cards[0].pos, slot0)
	_run(page, 1.0)
	assert_object(run.starter.core_cards[0]).is_same(cards[0].card)
	var logged: int = _logged("staple_swap").size()
	page.message = ""
	# Click it, then click its own slot: home, still swapped.
	_click(page, slot0)
	assert_object(window.held).is_same(cards[0])
	assert_int(window.slot_of(cards[0])).is_equal(0)
	_click(page, slot0)
	assert_object(window.held).is_null()
	assert_object(run.starter.core_cards[0]).is_same(cards[0].card)
	assert_str(page.message).is_equal("")
	assert_int(window.err_slot).is_equal(-1)
	_run(page, 1.0)
	assert_bool(cards[0].item).is_true()
	# Held, then Esc: home, still swapped.
	_click(page, slot0)
	board._input(_key(KEY_ESCAPE))
	assert_object(window.held).is_null()
	assert_bool(window.active).is_true()
	assert_object(run.starter.core_cards[0]).is_same(cards[0].card)
	assert_int(_logged("staple_swap").size()).is_equal(logged)
	_run(page, 1.0)
	# Held, then R: the reset still goes through.
	_click(page, slot0)
	board._input(_key(KEY_R))
	assert_array(run.starter.core_cards).is_equal(run.start_setup.originals)
	assert_str(page.message).is_not_equal("COULD NOT SAVE. TRY AGAIN")
	_run(page, 1.0)
	# Closed and reopened: the reasons are worked out afresh.
	window.drop_reason(cards[1], 0)
	window.close(false)
	_run(page, 0.5)
	assert_bool(window.open_window(false)).is_true()
	assert_dict(window._reasons).is_empty()


## DONE (opened from NEXT) goes on after the hold, unless the window was opened again in the gap:
## then the go-on is dropped and the board stays on page 1 with the window open.
func test_reopened_in_the_gap_does_not_go_on() -> void:
	var page: BoosterPage = await _page(2)
	var board: StartBoard = _board(page)
	_stocked(page)
	board._input(_key(KEY_ENTER))
	assert_bool(page.swap.from_next).is_true()
	board._input(_key(KEY_ENTER))
	assert_bool(page.swap.active).is_false()
	_run(page, page.tuning.swap_out_s + 0.05)
	assert_bool(page.swap.visible()).is_false()
	_click(page, BoosterChromeDraw.CRATE_RECT.get_center())
	assert_bool(page.swap.active).is_true()
	_run(page, page.tuning.swap_next_hold_s + 0.2)
	assert_int(board.page).is_equal(1)
	assert_bool(page.swap.active).is_true()


## With no swap unlocked the window still opens from the basket: its boosters stay sealed under a
## padlock, no offer is drawn, opening one is refused (SWAPS LOCKED), the LED shows the padlock.
func test_the_locked_window() -> void:
	var page: BoosterPage = await _page(0)
	_stocked(page)
	assert_bool(page.swap.open_window(false)).is_true()
	assert_bool(page.swap.locked).is_true()
	assert_dict(page.run.start_setup.swap_offers).is_empty()
	assert_int(page.swap.boosters.size()).is_equal(2)
	_run(page, 1.0)
	assert_bool(page.swap.open_booster(0, "key")).is_false()
	assert_str(page.swap.err_text).is_equal("SWAPS LOCKED")
	assert_str(page.message).is_equal("SWAPS LOCKED · 1 SWAP PER FINISHED AISLE")
	assert_int(page.swap.boosters[0].state).is_equal(BoosterOpening.State.SEALED)
	_run(page, 2.5)
	assert_str(page.swap.hint_line).is_equal("SWAPS LOCKED · 1 SWAP PER FINISHED AISLE")


## Two card pieces of one swap booster whose cards fit slot `slot` now.
static func _fitting(page: BoosterPage, slot: int) -> Array[SwapPiece]:
	for bi: int in page.swap.boosters.size():
		var found: Array[SwapPiece] = []
		for piece: SwapPiece in page.swap.pieces:
			if piece.regular or piece.booster != bi:
				continue
			if page.swap.drop_reason(piece, slot) == "":
				found.append(piece)
		if found.size() >= 2:
			return found
	return []


static func _any_card(window: SwapWindow, other: SwapPiece) -> SwapPiece:
	for piece: SwapPiece in window.pieces:
		if not piece.regular and piece != other and window.slot_of(piece) < 0:
			if window.drop_reason(piece, 2) == "NO SWAPS LEFT":
				return piece
	return null


static func _regular(window: SwapWindow, slot: int) -> SwapPiece:
	for piece: SwapPiece in window.pieces:
		if piece.regular and piece.slot == slot:
			return piece
	return null


func _saved_regulars() -> Array:
	var save: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string(_folder.path_join(SaveService.RUN_FILE))
	)
	return save["regulars"]


## The logged events of type `type` in this test's session file.
func _logged(type: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for file: String in DirAccess.get_files_at(_folder):
		if not file.ends_with(".jsonl"):
			continue
		for line: String in FileAccess.get_file_as_string(_folder.path_join(file)).split("\n"):
			var event: Variant = JSON.parse_string(line) if line != "" else null
			if event is Dictionary and (event as Dictionary).get("type", "") == type:
				found.append((event as Dictionary).get("data", event))
	return found


## The page (frozen on its clock, reduced motion off) of a new run with `completed` aisles
## complete.
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


## Rolls up, opens every booster and lets STOCKED! come.
static func _stocked(page: BoosterPage) -> void:
	page.openings.roll_up()
	page.openings.end_arrival()
	page.openings.open_all("key")
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


## A click (press and release, no travel) at art point `at` through the page's input.
static func _click(page: BoosterPage, at: Vector2) -> void:
	_move(page, at)
	page._gui_input(_button(at, true))
	page._gui_input(_button(at, false))
	page.advance(0.0)


## A drag from art point `from` to `to` through the page's input.
static func _drag(page: BoosterPage, from: Vector2, to: Vector2) -> void:
	_move(page, from)
	page.advance(0.0)
	page._gui_input(_button(from, true))
	_move(page, (from + to) / 2.0)
	page.advance(STEP)
	_move(page, to)
	page.advance(STEP)
	page._gui_input(_button(to, false))
	page.advance(0.0)


static func _on_screen(page: BoosterPage, rect: Rect2) -> Rect2:
	return page.get_global_transform() * Rect2(rect.position * ArtPen.UNIT, rect.size * ArtPen.UNIT)


static func _key(keycode: Key) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.pressed = true
	key.keycode = keycode
	return key


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")


## A copy-limited card's rule ends above its MAX 2 IN CART tag (Bent lolly's fifth line hid under
## it): every card's rule, fitted to the room the swap window leaves it, fits that room.
func test_rules_fit_above_the_copy_limit_tag() -> void:
	var floor_y: float = BoosterArt.CH - SwapWindowDraw.TAG_RISE - 1
	for file: String in DirAccess.get_files_at("res://data/cards"):
		if not file.ends_with(".tres"):
			continue
		var card: CardDefinition = load("res://data/cards".path_join(file)) as CardDefinition
		if card == null or card.rule_text.strip_edges() == "":
			continue
		var text: Dictionary = BoosterArt.face_text(card, false)
		var win: Rect2i = text.window
		var room: float = minf(text.rule_bottom as float, floor_y) - (text.rule_top as int)
		var fit: Array = BoosterCardDraw.rule_fit(card, win.size.x - 4, room)
		var lines: PackedStringArray = fit[1]
		var block: float = lines.size() * ((fit[0] as float) + 0.9)
		assert_float(block).override_failure_message("%s: %s" % [file, lines]).is_less_equal(room)
