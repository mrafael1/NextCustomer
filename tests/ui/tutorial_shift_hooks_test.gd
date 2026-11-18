extends GdUnitTestSuite
## The tutorial's hooks and gates on the real shift screen (tutorial plan WP-5, ShiftGuide): with
## no gate every move works as before and the hooks are still sent (each with exactly its args);
## a gate refuses picks, every drop path (a slot click, a drag's drop, a click on a row card, the
## drag's landing light), the redraw, CHECKOUT (locked across every refresh), the cart, the week
## glass and the day calendar, the machine's keys (click and number key), PUSH (click and Enter),
## a prize and the SKIP bin, with no "denied" sound and a `refused` signal instead; the time card
## waits while the tutorial holds it and plays when queued; planning's notices and the monitor's
## empty-belt hint wait while a step shows; the anchors' rects lie on screen at 1280x720 and
## 1920x1080 and match their controls; the overlay's layer sits under the hover tips and the
## handbook. Clicks go to the handlers, because headless runs don't deliver mouse events.

const SCREEN := "res://ui/shift_screen.tscn"
const Rush := preload("res://tests/ui/count_up_rush.gd")
const RecordingSfx := preload("res://tests/presentation/recording_sfx.gd")
## Milk, Multipack, Milk x5 = 109: passes shift 1.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]

var _folder: String = ""
var _live_machine: MachineDefinition
var _window_size: Vector2i
## Every guide_event sent: {"event": StringName, "args": Dictionary}.
var _events: Array[Dictionary] = []
## Every refusal: the refused action.
var _refused: Array[StringName] = []
## What the test gate allows: action -> a Callable(args) -> bool (an action not in it: allowed).
var _rules: Dictionary[StringName, Callable] = {}
## The screens _screen() made: freed in after_test, once their frame's awaits are over.
var _screens: Array[Node] = []


func before_test() -> void:
	_live_machine = NoOvertime.live_off()
	_window_size = get_tree().root.size
	_folder = "user://tutorial_shift_hooks_%d" % Time.get_ticks_usec()
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_event_log().use_folder(_folder)
	_events = []
	_refused = []
	_rules = {}


func after_test() -> void:
	await get_tree().process_frame
	for screen: Node in _screens:
		screen.queue_free()
	_screens = []
	await get_tree().process_frame
	NoOvertime.live_restore(_live_machine)
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## No gate: picks, places, removals and the redraw work as ever; the hooks still go out, each
## with exactly its contract's args, PLANNING_READY once planning takes input.
func test_without_a_gate_the_hooks_go_out_and_nothing_is_refused() -> void:
	var screen: ShiftScreen = await _screen(true, Callable(), false)
	assert_bool(screen.guide.gate.is_valid()).is_false()
	await _frames(2)
	assert_array(_names()).contains([TutorialEvents.PLANNING_READY])
	assert_int(int(_last(TutorialEvents.PLANNING_READY)[TutorialEvents.ARG_SHIFT])).is_equal(1)
	var bread: CardInstance = _add(screen, "bread")
	screen._on_hand_card_clicked(_view_for(screen, bread))
	screen._on_slot_input(_left_click(), 0)
	assert_object(screen.run.row[0]).is_same(bread)
	var placed: Dictionary = _last(TutorialEvents.CARD_PLACED)
	assert_str(String(placed[TutorialEvents.ARG_CARD])).is_equal("bread")
	assert_int(int(placed[TutorialEvents.ARG_INSTANCE])).is_equal(bread.instance_id)
	assert_int(int(placed[TutorialEvents.ARG_SLOT])).is_equal(0)
	var projected: Dictionary = _last(TutorialEvents.PROJECTED)
	assert_int(int(projected[TutorialEvents.ARG_TOTAL])).is_equal(screen.run.preview().total)
	assert_int(int(projected[TutorialEvents.ARG_QUOTA])).is_equal(screen.run.quota())
	# Picked back up from the row, then let go in the hand: a removal.
	screen._on_row_card_clicked(screen._row_views[0])
	assert_bool(_last(TutorialEvents.CARD_PICKED)[TutorialEvents.ARG_FROM_ROW]).is_true()
	screen._on_background_input(_left_click())
	assert_array(_names()).contains([TutorialEvents.CARD_REMOVED])
	assert_array(screen.run.row).is_empty()
	screen._on_redraw_pressed()
	screen._on_basket_clicked(0)
	screen._basket_redraw.stop()
	assert_int(int(_last(TutorialEvents.REDRAW_DONE)[TutorialEvents.ARG_BASKET])).is_equal(0)
	assert_array(_refused).is_empty()
	_assert_args_valid()


## A refused pick: nothing picked, no drag armed, no sound, a refusal; the allowed card picks.
func test_a_refused_pick_does_nothing_and_plays_no_denied() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: RecordingSfx = _recording_sfx(screen)
	var milk: CardInstance = _add(screen, "milk")
	var bread: CardInstance = _add(screen, "bread")
	_only_card(TutorialActions.PICK_CARD, &"bread")
	screen._on_hand_card_clicked(_view_for(screen, milk))
	assert_object(screen._picked).is_null()
	assert_bool(screen._drag.is_dragging()).is_false()
	assert_array(_refused).is_equal([TutorialActions.PICK_CARD])
	assert_array(sfx.sounds).is_empty()
	screen._on_hand_card_clicked(_view_for(screen, bread))
	assert_object(screen._picked).is_same(bread)
	assert_int(_refused.size()).is_equal(1)
	_assert_args_valid()


## Every drop path asks PLACE_CARD at the compacted index: a slot click, a drag's drop, a click
## on a row card while a card is picked, and the drag's landing light. A refused drop places
## nothing (a dragged one goes back to the hand) and plays no "denied".
func test_every_drop_path_is_gated() -> void:
	var screen: ShiftScreen = await _screen()
	var first: CardInstance = _add(screen, "bread")
	var second: CardInstance = _add(screen, "milk")
	screen._on_hand_card_clicked(_view_for(screen, first))
	screen._on_slot_input(_left_click(), 0)
	var sfx: RecordingSfx = _recording_sfx(screen)
	_only_slot(1)  # Slot 1 only (the compacted index: a drop past the end is slot 1 here).

	# The landing light: only the allowed slot lights (slot 5 compacts to 1, the end).
	assert_int(screen._landing_slot(second, 0)).is_equal(-1)
	assert_int(screen._landing_slot(second, 1)).is_equal(1)
	assert_int(screen._landing_slot(second, 5)).is_equal(1)
	assert_array(_refused).is_empty()  # The light asks quietly.

	# A slot click on a refused slot: nothing placed, the card stays picked.
	screen._on_hand_card_clicked(_view_for(screen, second))
	screen._on_slot_input(_left_click(), 0)
	assert_int(screen.run.row.size()).is_equal(1)
	assert_object(screen._picked).is_same(second)
	assert_array(_refused).is_equal([TutorialActions.PLACE_CARD])

	# A click on the row card (it would insert before it, at slot 0): refused too.
	screen._on_row_card_clicked(screen._row_views[0])
	assert_int(screen.run.row.size()).is_equal(1)
	assert_int(_refused.size()).is_equal(2)

	# A drag dropped on slot 0: refused, the card goes back to its basket.
	screen._on_card_released(second, 0, true)
	assert_int(screen.run.row.size()).is_equal(1)
	assert_object(screen._picked).is_null()
	assert_int(_refused.size()).is_equal(3)

	# The allowed drop: placed at slot 1.
	screen._on_hand_card_clicked(_view_for(screen, second))
	screen._on_card_released(second, 4, true)
	assert_object(screen.run.row[1]).is_same(second)
	assert_bool(sfx.sound_names().has("denied")).is_false()
	_assert_args_valid()


## CHECKOUT stays locked across every refresh while the gate refuses it, and a press checks out
## nothing; REDRAW, a basket and the cart are refused too. Unlocked, CHECKOUT is enabled again.
func test_checkout_redraw_and_the_cart_are_gated() -> void:
	var screen: ShiftScreen = await _screen()
	_refuse([TutorialActions.CHECKOUT, TutorialActions.REDRAW, TutorialActions.OPEN_DECK])
	screen._refresh()
	assert_bool(screen._checkout_button.disabled).is_true()
	_add(screen, "bread")  # The debug panel's add refreshes the screen.
	assert_bool(screen._checkout_button.disabled).is_true()
	await screen._on_checkout_pressed()
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(screen._counting).is_false()
	screen._on_redraw_pressed()
	assert_bool(screen._redraw_mode).is_false()
	screen._on_deck_button_pressed()
	assert_bool(screen._deck_view.visible).is_false()
	assert_array(_refused).is_equal(
		[TutorialActions.CHECKOUT, TutorialActions.REDRAW, TutorialActions.OPEN_DECK]
	)
	# A basket refused while redraw mode is on (armed before the gate came).
	_rules = {}
	screen._on_redraw_pressed()
	_refuse([TutorialActions.BASKET])
	screen._on_basket_clicked(0)
	assert_int(screen.run.redraws_used).is_equal(0)
	assert_str(String(_refused[-1])).is_equal(String(TutorialActions.BASKET))
	_rules = {}
	screen._refresh()
	assert_bool(screen._checkout_button.disabled).is_false()
	assert_array(_names()).not_contains([TutorialEvents.CHECKOUT_STARTED])


## The week glass and the day calendar are gated (OPEN_WEEK, OPEN_CALENDAR); a calendar hover
## asks quietly. Allowed, the glass opens the card (WEEK_CARD_OPENED) and its close is heard.
func test_the_week_glass_and_the_calendar_are_gated() -> void:
	var screen: ShiftScreen = await _screen(false)
	screen._week.drop()  # The week's card was due on shift 1: out of the way.
	await _frames(2)
	_refuse([TutorialActions.OPEN_WEEK, TutorialActions.OPEN_CALENDAR])
	screen._stage.week_glass.pressed.emit()
	assert_bool(screen._week.card.is_open()).is_false()
	screen._stage.day_calendar.pressed.emit()
	assert_bool(screen._week.slip.is_open()).is_false()
	screen._stage.day_calendar.long_hovered.emit()
	assert_bool(screen._week.slip.is_open()).is_false()
	assert_array(_refused).is_equal([TutorialActions.OPEN_WEEK, TutorialActions.OPEN_CALENDAR])
	_rules = {}
	screen._stage.day_calendar.pressed.emit()
	assert_bool(screen._week.slip.is_open()).is_true()
	screen._week.slip.close(true)
	screen._stage.week_glass.pressed.emit()
	assert_bool(screen._week.card.is_open()).is_true()
	assert_array(_names()).contains([TutorialEvents.WEEK_CARD_OPENED])
	screen._week.card.close()
	var start: int = Time.get_ticks_msec()
	while screen._week.card.is_open() and Time.get_ticks_msec() - start < 3000:
		await get_tree().process_frame
	assert_array(_names()).contains([TutorialEvents.WEEK_CARD_CLOSED])
	_assert_args_valid()


## The time card is held during shift 1 while the tutorial holds it (and so are planning's
## notices); let go, it plays. queue_card plays it on a shift that is no week's first.
func test_the_time_card_waits_while_held_and_plays_when_queued() -> void:
	var held: Array[bool] = [true]
	var screen: ShiftScreen = await _screen(false, func() -> bool: return held[0])
	await _frames(4)
	assert_bool(screen._week.card.is_open()).is_false()
	assert_bool(screen._week.holds_planning()).is_true()
	held[0] = false
	await _frames(2)
	assert_bool(screen._week.card.is_open()).is_true()
	assert_array(_names()).contains([TutorialEvents.WEEK_CARD_OPENED])
	screen._week.card.close()
	# Shift 2 (no week's first): no card, until queued.
	held[0] = true
	await _next_shift(screen)
	await _frames(2)
	assert_bool(screen._week.card.is_open()).is_false()
	screen._week.queue_card()
	await _frames(2)
	assert_bool(screen._week.card.is_open()).is_false()  # Still held.
	held[0] = false
	await _frames(2)
	assert_bool(screen._week.card.is_open()).is_true()


## While a step shows: planning's notices wait (WeekFlow.holds_planning) and the monitor's
## empty-belt hint hides; it comes back after.
func test_a_showing_step_holds_the_notices_and_hides_the_empty_belt_hint() -> void:
	var screen: ShiftScreen = await _screen()
	var shows: Array[bool] = [false]
	screen.guide.showing = func() -> bool: return shows[0]
	await _frames(2)
	assert_bool(screen._week.holds_planning()).is_false()
	var hint: Label = screen._monitor.item_column().get_node_or_null("Hint") as Label
	assert_object(hint).is_not_null()
	assert_str(hint.text).is_equal(MonitorText.EMPTY_BELT)
	assert_bool(hint.visible).is_true()
	shows[0] = true
	await _frames(2)
	assert_bool(screen._week.holds_planning()).is_true()
	assert_bool(hint.visible).is_false()
	shows[0] = false
	await _frames(2)
	assert_bool(hint.visible).is_true()
	assert_bool(screen._week.holds_planning()).is_false()


## The machine's keys ask CHUTE (a click and a number key), PUSH asks (a click on the bar and
## Enter): refused ones do nothing. MACHINE_ARMED and CHUTE_CHOSEN go out.
func test_the_machine_keys_and_push_are_gated() -> void:
	get_tree().root.size = SIZES[0]  # The canvas is the window: the click lands on the flap.
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = await _passed(runner)
	var view: RewardMachineView = screen._machine.view
	await _until_armed(screen)
	assert_array(_names()).contains([TutorialEvents.MACHINE_ARMED])
	_rules[TutorialActions.CHUTE] = func(args: Dictionary) -> bool:
		return args[TutorialEvents.ARG_CHUTE] == TutorialEvents.CHUTE_NEW_ITEMS
	_refuse([TutorialActions.PUSH])
	view.keys[RewardMachine.Chute.UPGRADE].pressed.emit(RewardMachine.Chute.UPGRADE)
	assert_int(view.pressed_chute()).is_equal(-1)
	runner.simulate_key_pressed(KEY_2)
	await _frames(2)
	assert_int(view.pressed_chute()).is_equal(-1)
	assert_array(_refused).is_equal([TutorialActions.CHUTE, TutorialActions.CHUTE])
	runner.simulate_key_pressed(KEY_1)
	await _frames(2)
	assert_int(view.pressed_chute()).is_equal(RewardMachine.Chute.NEW_ITEMS)
	assert_bool(view.tray.confirm_offered()).is_true()
	# PUSH refused: Enter, then a click on the bar's flap (the real mouse path).
	runner.simulate_key_pressed(KEY_ENTER)
	await _frames(2)
	assert_bool(view.tray.confirm_down()).is_false()
	var flap: Rect2 = screen.anchor_rect(TutorialAnchors.MACHINE_PUSH)
	assert_bool(flap.has_area()).is_true()
	runner.set_mouse_position(flap.get_center())
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await _frames(2)
	assert_bool(view.tray.confirm_down()).is_false()
	assert_int(screen.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	assert_array(_refused.slice(2)).is_equal([TutorialActions.PUSH, TutorialActions.PUSH])
	_rules.erase(TutorialActions.PUSH)
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await _frames(2)
	assert_bool(view.tray.confirm_down()).is_true()
	view.tray._down_at_ms -= view.tuning.confirm_down_ms + 1
	view.tray.frame(view.clock)
	assert_int(screen.run.phase).is_equal(RunState.Phase.MACHINE_PICK)
	var chosen: Dictionary = _last(TutorialEvents.CHUTE_CHOSEN)
	assert_str(String(chosen[TutorialEvents.ARG_CHUTE])).is_equal("new_items")
	_assert_args_valid()


## A prize is kept only when KEEP allows it, the draw binned only when SKIP does. Kept: PRIZE_KEPT
## with its kind; binned: PRIZE_BINNED; after the glide back, MACHINE_RETURNED.
func test_keep_and_skip_are_gated() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = await _passed(runner)
	var view: RewardMachineView = screen._machine.view
	await _until_armed(screen)
	screen._machine._choose(RewardMachine.Chute.NEW_ITEMS)
	await _until_armed(screen)
	_refuse([TutorialActions.KEEP, TutorialActions.SKIP])
	view.pick(0)
	assert_bool(screen._deck_view.visible).is_false()
	view.skip_bin.pressed.emit()
	assert_int(screen.run.phase).is_equal(RunState.Phase.MACHINE_PICK)
	assert_array(_refused).is_equal([TutorialActions.KEEP, TutorialActions.SKIP])
	_rules = {}
	view.skip_bin.pressed.emit()
	assert_array(_names()).contains([TutorialEvents.PRIZE_BINNED])
	view.fast_forward()  # The landing plays to its end: the next shift, the glide back.
	await _frames(2)
	screen._machine._end_return()
	assert_array(_names()).contains([TutorialEvents.MACHINE_RETURNED])
	# Shift 2's visit: a product kept goes out with its kind.
	await _pass(screen)
	await _until_armed(screen)
	screen._machine._choose(RewardMachine.Chute.NEW_ITEMS)
	await _until_armed(screen)
	var prizes: Array[MachinePrize] = screen.run.machine.prizes()
	var index: int = 0
	while prizes[index].kind != MachinePrize.Kind.PRODUCT:
		index += 1
	var full: bool = screen.run.machine.needs_replace(screen.run, index)
	view.pick(index)
	if full:
		screen._machine.on_deck_card_chosen(screen.run.deck.cards[0])
	else:
		screen._machine.on_deck_added()
	assert_str(String(_last(TutorialEvents.PRIZE_KEPT)[TutorialEvents.ARG_KIND])).is_equal("item")
	_assert_args_valid()


## The count's hooks: CHECKOUT_STARTED at the press, COUNT_FINISHED after the count, MISS on a
## missed quota; SCAN_HELD once a scan's hold ends; RESULTS when the run's results open.
func test_the_count_scan_and_results_hooks() -> void:
	var screen: ShiftScreen = await _screen()
	var bread: CardInstance = _add(screen, "bread")
	screen._on_hand_card_clicked(_view_for(screen, bread))
	screen._on_slot_input(_left_click(), 0)
	await _frames(2)
	assert_bool(screen.debug_scan(bread)).is_true()
	await _frames(2)
	var held: Dictionary = _last(TutorialEvents.SCAN_HELD)
	assert_int(int(held[TutorialEvents.ARG_INSTANCE])).is_equal(bread.instance_id)
	assert_int(_names().count(TutorialEvents.SCAN_HELD)).is_equal(1)
	Rush.no_write_ups(screen)  # The miss ends the run: the results open.
	await Rush.checkout(screen)
	var names: Array[StringName] = _names()
	var started: int = names.find(TutorialEvents.CHECKOUT_STARTED)
	var finished: int = names.find(TutorialEvents.COUNT_FINISHED)
	assert_int(started).is_greater_equal(0)
	assert_int(finished).is_greater(started)
	assert_int(names.find(TutorialEvents.MISS)).is_greater(finished)
	var results: Dictionary = _last(TutorialEvents.RESULTS)
	assert_bool(results[TutorialEvents.ARG_WON]).is_false()
	assert_int(int(results[TutorialEvents.ARG_COINS])).is_equal(
		CoinPayout.for_run(screen.run).total()
	)
	_assert_args_valid()


## At 1280x720 and 1920x1080 every shift anchor shown lies on the screen, and the indexed ones
## sit on their controls: a slot's ticket in its drop column, a hand item on its view, a basket
## around its items; an unknown id has no rect.
func test_the_anchors_lie_on_screen_at_both_sizes() -> void:
	var screen: ShiftScreen = await _screen()
	for size: Vector2i in SIZES:
		get_tree().root.size = size
		await _frames(3)
		var window: Rect2 = screen.get_global_rect()
		for id: StringName in _shift_anchors(screen):
			var rect: Rect2 = screen.anchor_rect(id)
			var where: String = "%s at %s: %s in %s" % [id, size, rect, window]
			assert_bool(rect.has_area()).override_failure_message(where).is_true()
			assert_bool(window.encloses(rect)).override_failure_message(where).is_true()
		var drop: Rect2 = RowStrip.drop_rect(screen._slots[0])
		assert_bool(drop.encloses(screen.anchor_rect(TutorialAnchors.slot(0)))).is_true()
		var view: Control = screen._hand_box.view_at(0)
		var hand: Rect2 = screen.anchor_rect(TutorialAnchors.hand(0))
		assert_bool(hand.intersects(view.get_global_rect())).is_true()
		var basket: Rect2 = screen.anchor_rect(TutorialAnchors.basket(0))
		assert_bool(basket.intersects(screen.anchor_rect(TutorialAnchors.hand(0)))).is_true()
		assert_bool(screen.anchor_rect(TutorialAnchors.BASKETS).encloses(basket)).is_true()
		assert_bool(screen.anchor_rect(&"nothing").has_area()).is_false()
		assert_bool(screen.anchor_rect(TutorialAnchors.MACHINE_KEYS).has_area()).is_false()
		assert_bool(screen.anchor_rect(TutorialAnchors.WEEK_CARD).has_area()).is_false()


## The machine's anchors lie on screen during a visit (under the camera's 2x zoom).
func test_the_machine_anchors_lie_on_screen() -> void:
	get_tree().root.size = SIZES[0]
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = await _passed(runner)
	await _until_armed(screen)
	var window: Rect2 = screen.get_global_rect()
	for id: StringName in [
		TutorialAnchors.MACHINE_KEYS,
		TutorialAnchors.MACHINE_SIGN,
		TutorialAnchors.indexed(TutorialAnchors.MACHINE_KEY, 1),
	]:
		var rect: Rect2 = screen.anchor_rect(id)
		var where: String = "%s: %s in %s" % [id, rect, window]
		(
			assert_bool(rect.has_area() and window.encloses(rect))
			. override_failure_message(where)
			. is_true()
		)
	screen._machine._choose(RewardMachine.Chute.NEW_ITEMS)
	await _until_armed(screen)
	await _frames(3)
	for id: StringName in [TutorialAnchors.MACHINE_PRIZES, TutorialAnchors.MACHINE_SKIP]:
		var rect: Rect2 = screen.anchor_rect(id)
		var where: String = "%s: %s in %s" % [id, rect, window]
		(
			assert_bool(rect.has_area() and window.encloses(rect))
			. override_failure_message(where)
			. is_true()
		)
	var ticket: Rect2 = screen.anchor_rect(TutorialAnchors.indexed(TutorialAnchors.PRIZE, 0))
	assert_bool(screen.anchor_rect(TutorialAnchors.MACHINE_PRIZES).encloses(ticket)).is_true()


## The overlay's layer sits under the hover tips and the handbook, and hides while the cart is
## open; the handbook's opening is heard (HANDBOOK_OPENED).
func test_the_overlay_layer_sits_under_the_tips_and_the_handbook() -> void:
	var screen: ShiftScreen = await _screen()
	var overlay: Control = Control.new()
	screen.guide.mount_overlay(overlay)
	var layer: Control = screen.guide.layer()
	assert_object(overlay.get_parent()).is_same(layer)
	var handbook: HandbookPage = _handbook(screen)
	assert_int(layer.get_index()).is_less(screen._glyph_tips.get_index())
	assert_int(layer.get_index()).is_less(handbook.get_index())
	await _frames(1)
	assert_bool(layer.visible).is_true()
	screen._on_deck_button_pressed()
	await _frames(1)
	assert_bool(layer.visible).is_false()
	screen._deck_view.visible = false
	await _frames(1)
	assert_bool(layer.visible).is_true()
	handbook.open_at(&"chain")
	assert_array(_names()).contains([TutorialEvents.HANDBOOK_OPENED])
	await _frames(1)
	assert_bool(layer.visible).is_false()


# --- Helpers -----------------------------------------------------------------------------------


## The screen on shift 1, its time card out of the way unless `skip_card` is false; a gate (the
## test's rules) and `hold` set before its first frame; every hook and refusal recorded.
func _screen(
	skip_card: bool = true, hold: Callable = Callable(), gated: bool = true
) -> ShiftScreen:
	var scene: PackedScene = load(SCREEN)
	var screen: ShiftScreen = scene.instantiate()
	_screens.append(screen)
	add_child(screen)
	_listen(screen, gated)
	screen._week.hold = hold
	if skip_card:
		screen._week.skip()
	await _frames(1)
	return screen


func _listen(screen: ShiftScreen, gated: bool = true) -> void:
	screen.guide_event.connect(
		func(event: StringName, args: Dictionary) -> void:
			_events.append({"event": event, "args": args})
	)
	screen.guide.refused.connect(
		func(action: StringName, _args: Dictionary) -> void: _refused.append(action)
	)
	if gated:
		screen.guide.gate = _gate


## The test gate: an action with a rule asks it; any other is allowed.
func _gate(action: StringName, args: Dictionary) -> bool:
	assert_bool(TutorialActions.is_action(action)).is_true()
	return not _rules.has(action) or bool(_rules[action].call(args))


func _refuse(actions: Array[StringName]) -> void:
	for action: StringName in actions:
		_rules[action] = func(_args: Dictionary) -> bool: return false


func _only_card(action: StringName, card: StringName) -> void:
	_rules[action] = func(args: Dictionary) -> bool: return args[TutorialEvents.ARG_CARD] == card


func _only_slot(slot: int) -> void:
	_rules[TutorialActions.PLACE_CARD] = func(args: Dictionary) -> bool:
		return int(args[TutorialEvents.ARG_SLOT]) == slot


## The shift screen's fixed anchors that show in planning with a card in a basket.
func _shift_anchors(screen: ShiftScreen) -> Array[StringName]:
	var ids: Array[StringName] = [
		TutorialAnchors.QUOTA,
		TutorialAnchors.PROJ,
		TutorialAnchors.RECEIPT,
		TutorialAnchors.CHECKOUT,
		TutorialAnchors.REDRAW,
		TutorialAnchors.WEEK,
		TutorialAnchors.CAL,
		TutorialAnchors.MEDALS,
		TutorialAnchors.GAUGE,
		TutorialAnchors.LOYALTY,
		TutorialAnchors.CART,
		TutorialAnchors.MENU,
		TutorialAnchors.MONITOR,
		TutorialAnchors.TICKETS,
		TutorialAnchors.BASKETS,
	]
	for slot: int in range(screen._slots.size()):
		ids.append(TutorialAnchors.slot(slot))
	for basket: int in range(screen._stage.baskets.basket_lefts().size()):
		ids.append(TutorialAnchors.basket(basket))
	for place: int in screen._hand_box.places():
		ids.append(TutorialAnchors.hand(place))
	return ids


## The screen on shift 1 with a passing row checked out: the machine waits for its chute.
func _passed(runner: GdUnitSceneRunner) -> ShiftScreen:
	var screen: ShiftScreen = runner.scene()
	_listen(screen)
	screen._week.skip()
	await _pass(screen)
	return screen


func _pass(screen: ShiftScreen) -> void:
	for id: String in PASSING_ROW:
		_add(screen, id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	NoOvertime.on_run(screen.run)  # One visit follows.
	await Rush.checkout(screen)
	assert_int(screen.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)


## Passes the shift and skips its visit: the next shift's planning.
func _next_shift(screen: ShiftScreen) -> void:
	await _pass(screen)
	screen._machine.debug_skip()
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)


func _until_armed(screen: ShiftScreen) -> void:
	screen._machine.view.fast_forward()
	var start: int = Time.get_ticks_msec()
	while not screen._machine.view.is_armed() and Time.get_ticks_msec() - start < 3000:
		await get_tree().process_frame
	assert_bool(screen._machine.view.is_armed()).is_true()


func _handbook(screen: ShiftScreen) -> HandbookPage:
	for child: Node in screen.get_children():
		if child is HandbookPage:
			return child as HandbookPage
	return null


func _recording_sfx(screen: ShiftScreen) -> RecordingSfx:
	var sfx: RecordingSfx = RecordingSfx.new()
	screen.add_child(sfx)
	screen._sfx = sfx
	screen._count_up._sfx = sfx
	return sfx


func _add(screen: ShiftScreen, id: String) -> CardInstance:
	screen._debug.add_card(id)
	return screen.run.hand()[-1]


func _names() -> Array[StringName]:
	var names: Array[StringName] = []
	for entry: Dictionary in _events:
		names.append(entry["event"])
	return names


## The last `event`'s args ({} when none was sent).
func _last(event: StringName) -> Dictionary:
	for index: int in range(_events.size() - 1, -1, -1):
		if _events[index]["event"] == event:
			return _events[index]["args"]
	return {}


func _assert_args_valid() -> void:
	for entry: Dictionary in _events:
		var where: String = "%s %s" % [entry["event"], entry["args"]]
		var valid: bool = TutorialEvents.args_valid(entry["event"], entry["args"])
		assert_bool(valid).override_failure_message(where).is_true()


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


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
