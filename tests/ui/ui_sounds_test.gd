extends GdUnitTestSuite
## The interface sounds (#62, Q7) on a recording Sfx: UiKit buttons click (or play the sound
## they name), panels pop in with ui_open; on the shift screen a card picked up, placed and let
## go plays card_pickup, card_place and card_return, a drag over the slots plays a slot_tick at
## most once per CardDrag.SLOT_TICK_MS, a refusal plays a soft denied, CHECKOUT its key and the
## redraw its fan, shuffle and deal; the deck view fans out and switches tabs; the final
## receipt's coins clink one by one; and the title has its own Sfx for its start click. Nothing
## is played on hover. Mouse motion and releases go to the screen's CardDrag, because headless
## runs don't deliver input events.

const RecordingSfx := preload("res://tests/presentation/recording_sfx.gd")
const SCREEN := "res://ui/shift_screen.tscn"
const TITLE := "res://ui/title_screen.tscn"

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	_event_log().opens_export_folder = true
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	_remove_folder(_folder)


## A UiKit button plays ui_click (its takes in turn) before its action; one naming a sound plays
## that one instead, and one naming "" none. Hovering plays nothing.
func test_a_button_press_plays_ui_click() -> void:
	var scene: Control = auto_free(Control.new())
	add_child(scene)
	var sfx: RecordingSfx = RecordingSfx.new()
	scene.add_child(sfx)
	var heard_first: Array[bool] = []
	var action: Callable = func() -> void: heard_first.append(sfx.sounds.size() > 0)
	var button: Button = UiKit.button(scene, "OK", action, 16)
	var back: Button = UiKit.button(scene, "Skip", func() -> void: pass, 16, "ui_back")
	var silent: Button = UiKit.button(scene, "Go", func() -> void: pass, 16, "")
	button.mouse_entered.emit()
	assert_int(sfx.sounds.size()).is_equal(0)
	for press: int in range(4):
		button.pressed.emit()
	assert_array(heard_first).is_equal([true, true, true, true])
	back.pressed.emit()
	silent.pressed.emit()
	assert_array(sfx.sound_names()).is_equal(
		["ui_click", "ui_click", "ui_click", "ui_click", "ui_back"]
	)
	var takes: Array[String] = []
	for entry: Dictionary in sfx.sounds.slice(0, 4):
		takes.append(String(entry["take"]))
	assert_array(takes).is_equal(["ui_click_1", "ui_click_2", "ui_click_3", "ui_click_1"])


## A panel popping in plays ui_open.
func test_a_panel_pops_in_with_ui_open() -> void:
	var scene: Control = auto_free(Control.new())
	add_child(scene)
	var sfx: RecordingSfx = RecordingSfx.new()
	scene.add_child(sfx)
	var panel: PanelContainer = UiKit.paper_panel()
	scene.add_child(panel)
	UiKit.pop_in(panel)
	assert_array(sfx.sound_names()).is_equal(["ui_open"])


## Click to place: a hand card picked up (card_pickup), placed (card_place), taken back out of
## the row (card_pickup) and let go into the hand (card_return).
func test_placing_picking_up_and_returning_a_card() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: RecordingSfx = _recording_sfx(screen)
	var card: CardInstance = _add(screen, "bread")
	screen._on_hand_card_clicked(_view_for(screen, card))
	_release(screen, screen._drag._press_position)
	screen._on_slot_input(_left_click(), 0)
	assert_array(screen.run.row).is_equal([card])
	screen._on_row_card_clicked(screen._row_views[0])
	_release(screen, screen._drag._press_position)
	screen._on_background_input(_left_click())
	assert_array(screen.run.row).is_empty()
	assert_object(screen._picked).is_null()
	assert_array(sfx.sound_names()).is_equal(
		["card_pickup", "card_place", "card_pickup", "card_return"]
	)
	assert_int(sfx.notes.size()).is_equal(0)


## A drag: the pick-up sounds at the press, a slot_tick each time the landing slot changes but
## never twice within SLOT_TICK_MS, and the drop places. A drag of a card already picked up
## sounds its pick-up as the drag starts; dropping it on the hand returns it.
func test_a_drag_ticks_over_the_slots() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: RecordingSfx = _recording_sfx(screen)
	for id: String in ["milk", "milk", "milk"]:
		_add(screen, id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	var card: CardInstance = _add(screen, "bread")
	sfx.clear()
	await _wall_ms(CardDrag.SLOT_TICK_MS + 10)
	screen._on_hand_card_clicked(_view_for(screen, card))
	# Over slots 0, 1, 2 and 3 at once: one tick. Within a slot: none.
	for slot: int in range(4):
		_move(screen, _slot_center(screen, slot))
	_move(screen, _slot_center(screen, 3) + Vector2(4, 4))
	assert_array(sfx.sound_names()).is_equal(["card_pickup", "slot_tick"])
	await _wall_ms(CardDrag.SLOT_TICK_MS + 10)
	_move(screen, _slot_center(screen, 1))
	_move(screen, _slot_center(screen, 2))
	assert_int(sfx.count("slot_tick")).is_equal(2)
	# Off the row, nothing ticks.
	await _wall_ms(CardDrag.SLOT_TICK_MS + 10)
	_move(screen, screen._hand_box.get_global_rect().get_center())
	assert_int(sfx.count("slot_tick")).is_equal(2)
	_move(screen, _slot_center(screen, 1))
	_release(screen, _slot_center(screen, 1))
	assert_object(screen.run.row[1]).is_same(card)
	assert_str(sfx.sound_names()[-1]).is_equal("card_place")

	# Picked by a click, then pressed again and dragged: its pick-up sounds at the drag.
	var other: CardInstance = _add(screen, "bread")
	screen._on_hand_card_clicked(_view_for(screen, other))
	_release(screen, screen._drag._press_position)
	sfx.clear()
	screen._on_hand_card_clicked(_view_for(screen, other))
	assert_int(sfx.sounds.size()).is_equal(0)
	var hand_point: Vector2 = screen._hand_box.get_global_rect().get_center()
	_move(screen, hand_point)
	_release(screen, hand_point)
	assert_array(sfx.sound_names()).is_equal(["card_pickup", "card_return"])
	assert_object(screen._picked).is_null()


## A card that fits nowhere plays a soft denied with its notice; so does a closed slot.
func test_a_refusal_plays_a_soft_denied() -> void:
	var screen: ShiftScreen = await _screen()
	for _index: int in range(6):
		_add(screen, "bread")
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	var sfx: RecordingSfx = _recording_sfx(screen)
	screen._on_hand_card_clicked(_view_for(screen, _add(screen, "bread")))
	assert_array(sfx.sound_names()).is_equal(["card_pickup", "denied"])
	assert_float(float(sfx.sounds[1]["volume_db"])).is_equal(ShiftScreen.REFUSED_DB)
	screen._on_closed_slot_clicked()
	assert_array(sfx.sound_names()).is_equal(["card_pickup", "denied", "denied"])


## The Redraw key arms redraw mode with a fan; Cancel (or the key again) backs out. Clicking a
## basket (plan section 3.8) shuffles at once, then one card_place per new item as it pops up
## (RedrawTuning.pop_start); hovering a basket makes no sound (no hover sounds, #62).
func test_the_redraw_fans_shuffles_and_deals() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: RecordingSfx = _recording_sfx(screen)
	screen._redraw_button.pressed.emit()
	screen._cancel_button.pressed.emit()
	assert_array(sfx.sound_names()).is_equal(["fan", "ui_back"])
	sfx.clear()
	screen._redraw_button.pressed.emit()
	screen._redraw_button.pressed.emit()
	assert_array(sfx.sound_names()).is_equal(["fan", "ui_back"])
	sfx.clear()
	screen._redraw_button.pressed.emit()
	screen._basket_tags.hovered_changed.emit(0)
	var hand: Array[CardInstance] = screen.run.hand()
	screen._on_hand_card_clicked(_view_for(screen, hand[0]))
	assert_array(sfx.sound_names()).is_equal(["fan"])
	sfx.clear()
	# Timed from before the click: the frame after it steps the sounds' tween by the whole frame.
	await get_tree().process_frame
	var start: int = Time.get_ticks_msec()
	screen._on_basket_clicked(0)
	assert_int(screen.run.redraws_used).is_equal(1)
	assert_array(sfx.sound_names()).is_equal(["shuffle"])
	while sfx.count("card_place") < 2 and Time.get_ticks_msec() - start < 3000:
		await get_tree().process_frame
	var heard_ms: int = Time.get_ticks_msec() - start
	await _frames(10)
	assert_array(sfx.sound_names()).is_equal(["shuffle", "card_place", "card_place"])
	# The second card_place comes with the second pop, not at the click.
	var tuning: RedrawTuning = screen._basket_redraw.tuning
	assert_int(heard_ms).is_greater_equal(int(tuning.pop_start(1, false) * 1000.0) - 100)


## CHECKOUT plays its key (not a click) as the count-up starts.
func test_checkout_plays_its_key() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: RecordingSfx = _recording_sfx(screen)
	_add(screen, "milk")
	screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
	screen._on_slot_input(_left_click(), 0)
	sfx.clear()
	screen._checkout_button.pressed.emit()
	assert_array(sfx.sound_names()).is_equal(["checkout"])
	while screen._counting:
		await get_tree().process_frame
	assert_int(sfx.count("ui_click")).is_equal(0)
	assert_int(sfx.count("checkout")).is_equal(1)


## The deck view fans out as it pops in, its tabs switch with ui_switch and Close plays ui_close;
## the RECEIPT REWARDS machine (#77) refuses a padlocked chute with denied and prints its draw.
func test_the_deck_view_and_machine_sounds() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: RecordingSfx = _recording_sfx(screen)
	screen._deck_button.pressed.emit()
	assert_array(sfx.sound_names()).is_equal(["fan", "ui_open"])
	screen._deck_view._info_tab.pressed.emit()
	screen._deck_view._deck_tab.pressed.emit()
	for button: Button in screen._deck_view.find_children("*", "Button", true, false):
		if button is FramedButton and (button as FramedButton).caption == "Close":
			button.pressed.emit()
	assert_array(sfx.sound_names()).is_equal(
		["fan", "ui_open", "ui_switch", "ui_switch", "ui_close"]
	)
	for id: String in ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]:
		screen._on_hand_card_clicked(_view_for(screen, _add(screen, id)))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	await screen._on_checkout_pressed()
	assert_bool(screen._machine.is_open()).is_true()
	var view: RewardMachineView = screen._machine.view
	var start: int = Time.get_ticks_msec()
	while not view.is_armed() and Time.get_ticks_msec() - start < 8000:
		await get_tree().process_frame
	sfx.clear()
	# UPGRADES is padlocked after shift 1.
	view.press_key(RewardMachine.Chute.UPGRADES)
	assert_bool(screen._machine._choose(RewardMachine.Chute.NEW_ITEMS)).is_true()
	assert_array(sfx.sound_names()).is_equal(["denied", "print"])


## The final receipt clinks one coin sound per coin, MAX_COIN_SOUNDS at most, and none for no
## coins (their timing: tests/ui/results_panel_test.gd).
func test_the_coins_clink_one_by_one() -> void:
	for coins: int in [7, 0, 40]:
		var expected: int = mini(coins, FinalReceipt.MAX_COIN_SOUNDS)
		assert_int(FinalReceipt.coin_sounds(coins)).is_equal(expected)
	assert_int(FinalReceipt.coin_sounds(-3)).is_equal(0)


## The title has its own Sfx (its scene's): the start click and the log export sound on it.
func test_the_title_has_its_own_sfx() -> void:
	var runner: GdUnitSceneRunner = scene_runner(TITLE)
	var title: TitleScreen = runner.scene()
	title.changes_scene = false
	await _frames(2)
	assert_object(Sfx.find(title)).is_same(title._sfx)
	assert_object(title._sfx.get_parent()).is_same(title)
	var sfx: RecordingSfx = RecordingSfx.new()
	title.add_child(sfx)
	title._sfx = sfx
	var logs: String = _folder.path_join("logs")
	_event_log().use_folder(logs)
	_event_log().opens_export_folder = false
	for button: Button in title.find_children("*", "Button", true, false):
		if button.text == "Export log":
			button.pressed.emit()
	title._on_background_input(_left_click())
	title._on_background_input(_left_click())
	assert_bool(title._starting).is_true()
	assert_array(sfx.sound_names()).is_equal(["ui_confirm", "ui_click"])
	_remove_folder(logs)


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(2)
	return screen


## A recording Sfx in place of the screen's (its buttons and panels find it, so does the
## count-up).
func _recording_sfx(screen: ShiftScreen) -> RecordingSfx:
	var sfx: RecordingSfx = RecordingSfx.new()
	screen.add_child(sfx)
	screen._sfx = sfx
	screen._count_up._sfx = sfx
	return sfx


## Adds a card to the hand through the debug panel's handler.
func _add(screen: ShiftScreen, id: String) -> CardInstance:
	screen._debug.add_card(id)
	return screen.run.hand()[-1]


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
	for frame: int in range(count):
		await get_tree().process_frame


func _wall_ms(ms: int) -> void:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < ms:
		await get_tree().process_frame


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


static func _remove_folder(folder: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	for sub: String in DirAccess.get_directories_at(folder):
		_remove_folder(folder.path_join(sub))
	for file_name: String in DirAccess.get_files_at(folder):
		DirAccess.remove_absolute(folder.path_join(file_name))
	DirAccess.remove_absolute(folder)


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
