extends GdUnitTestSuite
## Drag-and-drop on the real shift screen (full build plan section 3, phase 1), on top of
## click-to-place. A press picks the card up through the click handlers; mouse motion and the
## release are sent to the screen's CardDrag, because headless runs don't deliver input events.
## Drops place, move and take out cards exactly as clicks do, and the checkout measures count
## them the same way, with input_method "click", "drag" or "both" (plan section 8).

const Rush := preload("res://tests/ui/count_up_rush.gd")
const SCREEN := "res://ui/shift_screen.tscn"

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The profile save goes there too, never to the real user:// profile.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_dragging_a_hand_card_onto_a_slot_places_it() -> void:
	var screen: ShiftScreen = await _screen()
	var card: CardInstance = _add(screen, "bread")
	_press_hand_card(screen, card)
	_move(screen, _slot_center(screen, 3))
	# The ghost (the item's sprite) follows the mouse, centred on it, the slot where the item
	# would land lights up (the row is compacted: slot 3 of an empty row means slot 0) and the
	# item's own sprite fades in the hand, its sticker still readable.
	assert_bool(screen._drag.is_dragging()).is_true()
	var ghost: ItemView = screen._drag._ghost
	assert_object(ghost).is_not_null()
	assert_int(ghost.form).is_equal(ItemView.Form.GHOST)
	var ghost_center: Vector2 = ghost.position + ItemView.SPRITE_SIZE / 2.0
	assert_vector(ghost_center).is_equal_approx(_slot_center(screen, 3), Vector2(1, 1))
	assert_float(ghost.body.modulate.a).is_equal_approx(0.92, 0.001)
	assert_int(screen._drag.hovered_slot()).is_equal(0)
	assert_bool(RowStrip.is_hovered(screen._slots[0])).is_true()
	assert_bool(RowStrip.is_hovered(screen._slots[3])).is_false()
	var source: ItemView = _view_for(screen, card) as ItemView
	assert_object(source).is_not_null()
	assert_float(source.body.modulate.a).is_less(0.5)
	assert_float(source.sticker().modulate.a).is_equal(1.0)
	_release(screen, _slot_center(screen, 3))
	# The row is compacted: a drop past the end places the card at the end, like a click.
	assert_array(screen.run.row).is_equal([card])
	assert_object(screen._picked).is_null()
	assert_bool(screen._drag.is_dragging()).is_false()
	assert_bool(RowStrip.is_hovered(screen._slots[0])).is_false()
	await _frames(1)
	assert_bool(is_instance_valid(ghost)).is_false()
	assert_int(screen.tracker.placements).is_equal(1)
	assert_str(screen.tracker.input_method).is_equal("drag")


func test_dropping_on_a_filled_slot_pushes_the_cards_right() -> void:
	var screen: ShiftScreen = await _screen()
	var first: CardInstance = _add(screen, "bread")
	var second: CardInstance = _add(screen, "milk")
	_drag_hand_card(screen, first, 0)
	_drag_hand_card(screen, second, 0)
	assert_array(screen.run.row).is_equal([second, first])


func test_dragging_a_row_card_moves_it() -> void:
	var screen: ShiftScreen = await _screen()
	var cards: Array[CardInstance] = []
	for id: String in ["bread", "milk", "eggs"]:
		cards.append(_add(screen, id))
		_drag_hand_card(screen, cards[-1], 6)
	# Bread, Milk, Eggs: take Bread out of slot 0 and drop it on slot 2 (the row has
	# compacted to Milk, Eggs by then, so slot 2 is the end).
	screen._on_row_card_clicked(screen._row_views[0])
	assert_object(screen._picked).is_same(cards[0])
	await _frames(1)
	_move(screen, _slot_center(screen, 2))
	_release(screen, _slot_center(screen, 2))
	assert_array(screen.run.row).is_equal([cards[1], cards[2], cards[0]])
	# A move is 1 placement and no removal, as with clicks.
	assert_int(screen.tracker.placements).is_equal(4)
	assert_int(screen.tracker.removals).is_equal(0)


func test_dragging_a_row_card_to_the_hand_takes_it_out() -> void:
	var screen: ShiftScreen = await _screen()
	var card: CardInstance = _add(screen, "bread")
	_drag_hand_card(screen, card, 0)
	screen._on_row_card_clicked(screen._row_views[0])
	await _frames(1)
	var hand_point: Vector2 = screen._hand_box.get_global_rect().get_center()
	_move(screen, hand_point)
	_release(screen, hand_point)
	assert_array(screen.run.row).is_empty()
	assert_bool(screen.run.hand().has(card)).is_true()
	assert_object(screen._picked).is_null()
	assert_int(screen.tracker.removals).is_equal(1)
	assert_str(screen.tracker.input_method).is_equal("drag")


func test_a_press_without_moving_stays_a_click() -> void:
	var screen: ShiftScreen = await _screen()
	var card: CardInstance = _add(screen, "bread")
	_press_hand_card(screen, card)
	var press: Vector2 = screen._drag._press_position
	_move(screen, press + Vector2(3, 3))
	assert_bool(screen._drag.is_dragging()).is_false()
	_release(screen, press + Vector2(3, 3))
	# Still picked up, waiting for a slot click, exactly as before drag-and-drop.
	assert_object(screen._picked).is_same(card)
	screen._on_slot_input(_left_click(), 0)
	assert_array(screen.run.row).is_equal([card])
	assert_str(screen.tracker.input_method).is_equal("click")


func test_a_refused_drop_explains_and_lets_go() -> void:
	var screen: ShiftScreen = await _screen()
	for _index: int in range(6):
		_drag_hand_card(screen, _add(screen, "bread"), 6)
	var seventh: CardInstance = _add(screen, "bread")
	_press_hand_card(screen, seventh)
	screen._notice_label.text = ""
	_move(screen, _slot_center(screen, 6))
	_release(screen, _slot_center(screen, 6))
	assert_int(screen.run.row.size()).is_equal(6)
	assert_bool(screen.run.row.has(seventh)).is_false()
	assert_str(screen._notice_label.text).contains("6/6 products")
	assert_object(screen._picked).is_null()


func test_releasing_the_button_elsewhere_cancels_without_a_drop() -> void:
	var screen: ShiftScreen = await _screen()
	var card: CardInstance = _add(screen, "bread")
	_press_hand_card(screen, card)
	_move(screen, _slot_center(screen, 1))
	# A motion with the button already up (the release happened outside the window).
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = _slot_center(screen, 2)
	screen._drag._input(motion)
	assert_bool(screen._drag.is_dragging()).is_false()
	assert_array(screen.run.row).is_empty()
	assert_object(screen._picked).is_same(card)
	# The carried card looks normal again.
	assert_float(_view_for(screen, card).body.modulate.a).is_equal(1.0)
	assert_int(screen._drag.hovered_slot()).is_equal(-1)


## While a card is dragged over a slot, the quota chip shows the total the drop would give and its
## change from the projected total (#71, decision 4A), from the run's preview with the card placed
## there, never placing it; a release with the button already up puts the projected total back.
## The top bar never moves meanwhile: the bar and every chip keep their place at each landing.
func test_the_quota_chip_shows_the_drops_total() -> void:
	var screen: ShiftScreen = await _screen()
	_drag_hand_card(screen, _add(screen, "bread"), 0)
	await _frames(2)
	var projected: int = screen.run.preview().total
	assert_str(screen._quota_meter.shown_text()).is_equal("€%d" % projected)
	var layout: Array[Rect2] = _top_bar_rects(screen)
	var eggs: CardInstance = _add(screen, "eggs")
	_press_hand_card(screen, eggs)
	for slot: int in [0, 1]:
		_move(screen, _slot_center(screen, slot))
		await _frames(2)
		var total: int = screen.run.preview(eggs, slot).total
		assert_str(screen._quota_meter.shown_text()).is_equal(
			QuotaMeter.HYPOTHETICAL_TEXT % [total, total - projected]
		)
		assert_array(_top_bar_rects(screen)).override_failure_message(str(slot)).is_equal(layout)
		assert_int(screen.run.row.size()).is_equal(1)
	# Eggs before Bread lands its ×2: the drop gains more than its own price.
	var before_bread: int = screen.run.preview(eggs, 0).total
	assert_int(before_bread).is_greater(screen.run.preview(eggs, 1).total)
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = _slot_center(screen, 2)
	screen._drag._input(motion)
	assert_bool(screen._drag.is_dragging()).is_false()
	assert_str(screen._quota_meter.shown_text()).is_equal("€%d" % projected)
	await _frames(2)
	assert_array(_top_bar_rects(screen)).is_equal(layout)


## The top bar's chips and the QUOTA bar, as they stand on screen.
static func _top_bar_rects(screen: ShiftScreen) -> Array[Rect2]:
	var rects: Array[Rect2] = [screen._quota_meter.bar().get_global_rect()]
	for child: Node in screen._top_bar.get_children():
		var control: Control = child as Control
		if control != null and control.visible:
			rects.append(control.get_global_rect())
	return rects


## The drop target is the slot's column (#80 play test, 2026-10-17): from the top of where its
## item's art stands down to its ticket, over the footprint, and half the gap to each neighbour.
## Over an empty slot's art area, a filled slot's item or either half of the gap between two cells
## that slot lights up and a drop there places the card as a click would (on a filled slot it
## goes in its place, pushing the others right); over the band above the art (the paid chip's,
## the wall's) no slot lights up, and a drop there lets go of the card.
func test_the_drop_target_is_the_slot_column() -> void:
	var screen: ShiftScreen = await _screen()
	var bread: CardInstance = _add(screen, "bread")
	_drag_hand_card(screen, bread, 0)
	var milk: CardInstance = _add(screen, "milk")
	_drag_hand_card(screen, milk, 1)
	assert_array(screen.run.row).is_equal([bread, milk])
	await _frames(1)
	var cells: Array[Rect2] = []
	for panel: PanelContainer in screen._slots:
		cells.append(panel.get_global_rect())
	var drop: Rect2 = RowStrip.drop_rect(screen._slots[2])
	var footprint: Rect2 = RowStrip.footprint(screen._slots[2]).get_global_rect()
	var art_area: Vector2 = Vector2(cells[2].get_center().x, footprint.position.y - 30.0)
	var item: ItemView = screen._row_views[0] as ItemView
	var on_item: Vector2 = item.sprite().get_global_rect().get_center()
	var gap_left: Vector2 = Vector2(cells[0].end.x + 3.0, art_area.y)
	var gap_right: Vector2 = Vector2(cells[1].position.x - 3.0, art_area.y)
	var above: Vector2 = Vector2(cells[2].get_center().x, drop.position.y - 2.0)
	assert_bool(cells[2].has_point(above)).is_true()
	var expected: Dictionary[Vector2, int] = {
		art_area: 2, on_item: 0, gap_left: 0, gap_right: 1, above: -1
	}
	for point: Vector2 in expected:
		assert_int(screen._drag._slot_at(point)).override_failure_message(str(point)).is_equal(
			expected[point]
		)
	var eggs: CardInstance = _add(screen, "eggs")
	_press_hand_card(screen, eggs)
	_move(screen, above)
	assert_bool(screen._drag.is_dragging()).is_true()
	assert_int(screen._drag.hovered_slot()).is_equal(-1)
	_release(screen, above)
	assert_array(screen.run.row).is_equal([bread, milk])
	assert_object(screen._picked).is_null()
	_press_hand_card(screen, eggs)
	_move(screen, art_area)
	assert_int(screen._drag.hovered_slot()).is_equal(2)
	_move(screen, on_item)
	assert_int(screen._drag.hovered_slot()).is_equal(0)
	_release(screen, on_item)
	assert_array(screen.run.row).is_equal([eggs, bread, milk])


## A card already picked up (by a click) can still be dragged; a plain click on it lets go on
## the release, as before.
func test_a_picked_card_can_be_dragged_and_a_click_lets_go() -> void:
	var screen: ShiftScreen = await _screen()
	var card: CardInstance = _add(screen, "bread")
	_press_hand_card(screen, card)
	_release(screen, screen._drag._press_position)
	assert_object(screen._picked).is_same(card)
	# Press it again and drag it to a slot.
	screen._on_hand_card_clicked(_view_for(screen, card))
	assert_object(screen._picked).is_same(card)
	_move(screen, _slot_center(screen, 0))
	_release(screen, _slot_center(screen, 0))
	assert_array(screen.run.row).is_equal([card])
	# A click on a picked card (press and release in place) still lets go of it.
	var other: CardInstance = _add(screen, "milk")
	_press_hand_card(screen, other)
	_release(screen, screen._drag._press_position)
	screen._on_hand_card_clicked(_view_for(screen, other))
	assert_object(screen._picked).is_same(other)
	_release(screen, screen._drag._press_position)
	assert_object(screen._picked).is_null()
	assert_str(screen.tracker.input_method).is_equal("drag")


## A row card taken out by a click, then dragged back in: 1 placement and no removal, as a
## click move.
func test_a_row_card_picked_by_click_can_be_dragged_back() -> void:
	var screen: ShiftScreen = await _screen()
	var first: CardInstance = _add(screen, "bread")
	_drag_hand_card(screen, first, 0)
	var second: CardInstance = _add(screen, "milk")
	_drag_hand_card(screen, second, 1)
	screen._on_row_card_clicked(screen._row_views[0])
	_release(screen, screen._drag._press_position)
	assert_object(screen._picked).is_same(first)
	await _frames(1)
	screen._on_hand_card_clicked(_view_for(screen, first))
	_move(screen, _slot_center(screen, 1))
	_release(screen, _slot_center(screen, 1))
	assert_array(screen.run.row).is_equal([second, first])
	assert_int(screen.tracker.placements).is_equal(3)
	assert_int(screen.tracker.removals).is_equal(0)


## The highlight shows where the card would land: the card that would be pushed right, the
## end of the row for a slot past it, and nothing where the card can't go.
func test_the_highlight_shows_the_landing_slot() -> void:
	var screen: ShiftScreen = await _screen()
	for _index: int in range(2):
		_drag_hand_card(screen, _add(screen, "bread"), 6)
	var card: CardInstance = _add(screen, "milk")
	_press_hand_card(screen, card)
	_move(screen, _slot_center(screen, 1))
	assert_int(screen._drag.hovered_slot()).is_equal(1)
	# The belt item's sprite takes the tint: its `body` draws nothing, so tinting that would
	# show nothing.
	var pushed: ItemView = screen._row_views[1] as ItemView
	assert_object(pushed).is_not_null()
	assert_bool(pushed.sprite().self_modulate == CardDrag.PUSH_TINT).is_true()
	_move(screen, _slot_center(screen, 5))
	assert_int(screen._drag.hovered_slot()).is_equal(2)
	assert_bool(pushed.sprite().self_modulate == Color.WHITE).is_true()
	assert_bool(RowStrip.is_hovered(screen._slots[2])).is_true()
	_release(screen, _slot_center(screen, 5))
	assert_object(screen.run.row[2]).is_same(card)
	# A 7th product fits nowhere: no slot lights up.
	for _index: int in range(3):
		_drag_hand_card(screen, _add(screen, "bread"), 6)
	var seventh: CardInstance = _add(screen, "bread")
	_press_hand_card(screen, seventh)
	_move(screen, _slot_center(screen, 6))
	assert_int(screen._drag.hovered_slot()).is_equal(-1)
	_release(screen, _slot_center(screen, 6))


func test_mixed_methods_log_both() -> void:
	var screen: ShiftScreen = await _screen()
	var dragged: CardInstance = _add(screen, "bread")
	_drag_hand_card(screen, dragged, 0)
	var clicked: CardInstance = _add(screen, "bread")
	screen._on_hand_card_clicked(_view_for(screen, clicked))
	screen._on_slot_input(_left_click(), 1)
	await Rush.checkout(screen)
	var checkout: Dictionary = _last_event("checkout")
	assert_str(checkout["input_method"]).is_equal("both")
	assert_int(int(checkout["placements"])).is_equal(2)


func test_no_drag_while_redrawing() -> void:
	var screen: ShiftScreen = await _screen()
	screen._on_redraw_pressed()
	var card: CardInstance = screen.run.hand()[0]
	screen._on_hand_card_clicked(_view_for(screen, card))
	_move(screen, _slot_center(screen, 0))
	assert_bool(screen._drag.is_dragging()).is_false()
	_release(screen, _slot_center(screen, 0))
	assert_array(screen.run.row).is_empty()


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	await _frames(2)
	return screen


## Adds a card to the hand through the debug panel's handler.
func _add(screen: ShiftScreen, id: String) -> CardInstance:
	screen._debug.add_card(id)
	return screen.run.hand()[-1]


## A press on a hand card: the click handler picks it up and arms the drag.
func _press_hand_card(screen: ShiftScreen, card: CardInstance) -> void:
	screen._on_hand_card_clicked(_view_for(screen, card))
	assert_object(screen._picked).is_same(card)


func _drag_hand_card(screen: ShiftScreen, card: CardInstance, slot: int) -> void:
	_press_hand_card(screen, card)
	_move(screen, _slot_center(screen, slot))
	_release(screen, _slot_center(screen, slot))


func _move(screen: ShiftScreen, point: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	screen._drag._input(motion)


func _release(screen: ShiftScreen, point: Vector2) -> void:
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	release.position = point
	screen._drag._input(release)


static func _slot_center(screen: ShiftScreen, slot: int) -> Vector2:
	return screen._slots[slot].get_global_rect().get_center()


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


func _last_event(type: String) -> Dictionary:
	var events: Array = []
	for line: String in EventLogWriter.join_logs(_folder).split("\n", false):
		events.append(JSON.parse_string(line))
	for index: int in range(events.size() - 1, -1, -1):
		if events[index]["type"] == type:
			return events[index]
	return {}


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	for child: Node in screen._hand_box.get_children():
		var view: CardView = child as CardView
		if view and view.card == card and not view.is_queued_for_deletion():
			return view
	return null


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
