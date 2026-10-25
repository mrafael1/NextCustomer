extends GdUnitTestSuite
## The screen capture (debug/screen_capture, #55, #75) sets up its fixed shift on the real shift
## screen: shift 5 under Short belt, a hand of 8 tray items and four belt items, with a product
## from each of the 6 aisles among them. Its scan (--scan) scans a card's item as a hover would:
## the belt's first, else the hand's. The capture keeps its saves and log in a temporary folder;
## the test redirects them too, so the real ones are never touched. Its capture saves one PNG
## (named for the scan after one), reporting a failed save or a card that isn't on the counter
## to its reporter (never to Godot's output); headless runs have no screen to grab, so the test
## passes its own image. Its effects (--effects, #71) set up the planning effects' richer belt and
## hover a card's belt item. Its machine (--machine, #77) opens the RECEIPT REWARDS machine on a
## checked-out shift and plays the visit asked for.

const CAPTURE := "res://debug/screen_capture/screen_capture.tscn"

var _folder: String = ""
var _capture_folder: String = ""
var _errors: PackedStringArray = PackedStringArray()


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_capture_folder = "user://screen_capture_%d" % Time.get_ticks_usec()
	_errors.clear()


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	for folder: String in [_folder, _capture_folder]:
		if DirAccess.dir_exists_absolute(folder):
			for file_name: String in DirAccess.get_files_at(folder):
				DirAccess.remove_absolute(folder.path_join(file_name))
			DirAccess.remove_absolute(folder)


func test_the_capture_sets_up_its_shift() -> void:
	var runner: GdUnitSceneRunner = scene_runner(CAPTURE)
	for _frame: int in range(3):
		await get_tree().process_frame
	var screen: ShiftScreen = runner.scene().call("screen")
	var run: RunState = screen.run
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_int(run.shift_index).is_equal(4)
	assert_int(run.inspections.size()).is_equal(1)
	assert_int(run.hand().size()).is_equal(8)
	assert_int(run.row.size()).is_equal(4)
	assert_int(screen._hand_box.cards().size()).is_equal(8)
	assert_int(screen._row_views.size()).is_equal(4)
	for view: Control in screen._hand_box.cards():
		assert_int((view as ItemView).form).is_equal(ItemView.Form.BASKET)
	for view: CardView in screen._row_views:
		assert_int((view as ItemView).form).is_equal(ItemView.Form.BELT)
	var aisles: Dictionary = {}
	for card: CardInstance in run.hand() + run.row:
		var aisle: AisleDefinition = run.balance.aisle_of(card.definition)
		if aisle != null:
			aisles[aisle] = true
	assert_int(aisles.size()).is_equal(run.balance.aisles.size())


func test_the_capture_saves_one_png() -> void:
	var capture: Control = scene_runner(CAPTURE).scene()
	capture.set("report_error", _record)
	capture.set("grab_image", func() -> Image: return Image.create(8, 8, false, Image.FORMAT_RGB8))
	await capture.call("capture", _capture_folder)
	assert_array(_errors).is_empty()
	var window: Vector2i = capture.get_window().size
	var file_name: String = "shift_screen_%dx%d.png" % [window.x, window.y]
	assert_bool(FileAccess.file_exists(_capture_folder.path_join(file_name))).is_true()
	assert_int(DirAccess.get_files_at(_capture_folder).size()).is_equal(1)


## --scan=multipack scans the belt's Multipack (the hand holds none): its item lifts, the hung
## monitor shows it (#80) and the scan's marks pose over it; the capture is then named for the scan.
## A hand card is scanned in the hand.
func test_the_scan_scans_a_card_on_the_counter() -> void:
	var capture: Control = scene_runner(CAPTURE).scene()
	capture.set("report_error", _record)
	capture.set("grab_image", func() -> Image: return Image.create(8, 8, false, Image.FORMAT_RGB8))
	var screen: ShiftScreen = capture.call("screen")
	await capture.call("scan", "multipack")
	await get_tree().process_frame
	var scanned: ItemView = screen._scan.scanned()
	assert_object(scanned).is_not_null()
	assert_str(scanned.card.definition.id).is_equal("multipack")
	assert_int(scanned.form).is_equal(ItemView.Form.BELT)
	assert_bool(scanned.lifted).is_true()
	assert_int(screen._monitor.mode()).is_equal(MonitorView.Mode.SCAN)
	assert_str(ItemName.text_of(screen._monitor.item_column().name_control())).is_equal(
		scanned.card.definition.display_name
	)
	assert_bool(screen._scan.popup().visible).is_false()
	assert_bool(screen._scan.overlay().is_posed()).is_true()
	await capture.call("capture", _capture_folder)
	assert_array(_errors).is_empty()
	var window: Vector2i = capture.get_window().size
	var file_name: String = "shift_screen_scan_%dx%d.png" % [window.x, window.y]
	assert_array(DirAccess.get_files_at(_capture_folder)).contains_exactly([file_name])
	await capture.call("scan", "eggs")
	await get_tree().process_frame
	assert_int(screen._scan.scanned().form).is_equal(ItemView.Form.BASKET)
	assert_str(screen._scan.scanned().card.definition.id).is_equal("eggs")


## --effects (#71) sets up #60's reference row under the Spot check, every item wearing its
## planning stickers (mock-up h1); --effects=multipack then hovers the belt's Multipack: it is
## focused, the items it lands on stay related, the others dim, its scan finishes (the monitor
## explains it), and the capture is named for the focused effects
## (shift_screen_effects_<w>x<h>.png with no card).
func test_the_effects_show_and_focus_the_planning_effects() -> void:
	var capture: Control = scene_runner(CAPTURE).scene()
	capture.set("report_error", _record)
	capture.set("grab_image", func() -> Image: return Image.create(8, 8, false, Image.FORMAT_RGB8))
	var screen: ShiftScreen = capture.call("screen")
	await capture.call("effects")
	await get_tree().process_frame
	var run: RunState = screen.run
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_str(run.inspections[0].id).is_equal("spot_check")
	assert_int(run.row.size()).is_equal(7)
	assert_int(run.hand().size()).is_equal(8)
	assert_object(screen._effects.focused_card()).is_null()
	var model: PlanningModel = screen._effects.committed_model()
	var layer: PlanningLayer = screen._stage.planning_layer
	assert_int(model.slots.size()).is_equal(run.row.size())
	for slot: int in range(run.row.size()):
		var texts: PackedStringArray = PackedStringArray()
		for sticker: EffectSticker in layer.stack(slot):
			texts.append(sticker.text())
		var expected: PackedStringArray = PackedStringArray()
		for spec: StickerSpec in model.slots[slot].stickers:
			expected.append(spec.text)
		assert_array(texts).override_failure_message(str(slot)).is_equal(expected)
	# The 3rd product (the Milk in slot 2) is stamped by the Spot check.
	assert_object(layer.stamp(2)).is_not_null()
	await capture.call("capture", _capture_folder)
	var window: Vector2i = capture.get_window().size
	var plain: String = "shift_screen_effects_%dx%d.png" % [window.x, window.y]
	assert_array(DirAccess.get_files_at(_capture_folder)).contains_exactly([plain])
	DirAccess.remove_absolute(_capture_folder.path_join(plain))
	await capture.call("effects", "multipack")
	await get_tree().process_frame
	screen = capture.call("screen")
	var focused: CardInstance = screen._effects.focused_card()
	assert_object(focused).is_not_null()
	assert_str(focused.definition.id).is_equal("multipack")
	var multipack: int = screen.run.row.find(focused)
	assert_int((screen._row_views[multipack] as ItemView).relation).is_equal(
		ItemView.Relation.FOCUS
	)
	var targets: int = 0
	for slot: int in range(screen._row_views.size()):
		if (screen._row_views[slot] as ItemView).relation == ItemView.Relation.RELATED:
			targets += 1
	assert_int(targets).is_greater_equal(1)
	# Its scan has finished: the monitor explains it (mock-up h1's hover).
	assert_str(ItemName.text_of(screen._monitor.item_column().name_control())).is_equal(
		focused.definition.display_name
	)
	await capture.call("capture", _capture_folder)
	assert_array(_errors).is_empty()
	var file_name: String = "shift_screen_effects_focus_%dx%d.png" % [window.x, window.y]
	assert_array(DirAccess.get_files_at(_capture_folder)).contains_exactly([file_name])
	await capture.call("effects", "soup")
	assert_array(_errors).contains_exactly(["No soup on the belt to hover"])


## --machine (#77): shift 1's passing row checked out, the machine opens on the screen beside
## the receipt and replays its visit from the printer feed; new_items chooses that chute (the draw
## shows its prizes) and draw=crl relabels them COMMON, RARE, LEGENDARY (rarest last); the capture
## is named for the options and the wait. The bonus ticket's visit (its shift passed a Spot check)
## shows too; a resumed visit holds at its wait point; levelup offers level-ups of the owned
## Coupon engine LV 2 (its box's LV mark); odds hovers a chute's key (its odds in the stock
## window); a full cart is at the deck limit; premium makes the visit PREMIUM (gold keys, RARE or
## better); --announce shows the PREMIUM NEXT announce.
func test_the_machine_shows_its_visits() -> void:
	var capture: Control = scene_runner(CAPTURE).scene()
	capture.set("report_error", _record)
	capture.set("grab_image", func() -> Image: return Image.create(8, 8, false, Image.FORMAT_RGB8))
	await capture.call("machine", "0.1,new_items,draw=crl")
	var screen: ShiftScreen = capture.call("screen")
	var run: RunState = screen.run
	var view: RewardMachineView = screen._machine.view
	assert_bool(screen._machine.is_open()).is_true()
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_PICK)
	assert_int(run.machine.current_visit().chute).is_equal(RewardMachine.Chute.NEW_ITEMS)
	assert_bool(view.plan.resumed).is_false()
	(
		assert_array(view.tickets.map(func(ticket: PrizeTicket) -> int: return ticket.prize.rarity))
		. is_equal(
			[MachinePrize.Rarity.COMMON, MachinePrize.Rarity.RARE, MachinePrize.Rarity.LEGENDARY]
		)
	)
	await capture.call("capture", _capture_folder)
	var window: Vector2i = capture.get_window().size
	var file_name: String = (
		"shift_screen_machine_new_items_drawcrl_1_%dx%d.png" % [window.x, window.y]
	)
	assert_array(DirAccess.get_files_at(_capture_folder)).contains_exactly([file_name])
	await capture.call("machine", "0,bonus,resume")
	run = screen.run
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	assert_int(run.machine.current_visit().kind).is_equal(MachineVisit.Kind.BONUS)
	assert_bool(view.plan.resumed).is_true()
	assert_str(view.head.stamp_texts()[0]).is_equal("BONUS TICKET!")
	await capture.call("machine", "0,levelup,upgrade")
	run = screen.run
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_PICK)
	assert_str((screen._loyalty_card.level_mark(0) as Label).text).is_equal("2")
	var perks: int = 0
	for prize: MachinePrize in run.machine.prizes():
		if prize.kind == MachinePrize.Kind.REGISTER:
			perks += 1
			assert_int(prize.upgrade.level_number()).is_equal(3)
	assert_int(perks).is_greater(0)
	await capture.call("machine", "0,new_items,odds,cartfull")
	run = screen.run
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	assert_bool(run.deck_is_full()).is_true()
	assert_int(view.hovered_chute()).is_equal(RewardMachine.Chute.NEW_ITEMS)
	# premium turns the visit PREMIUM (v0.61: every prize RARE or better, the keys gold);
	# --announce shows the shift before one, its gold receipt on the monitor.
	await capture.call("machine", "0,premium,upgrade")
	run = screen.run
	assert_bool(view.plan.premium).is_true()
	assert_int(run.machine.current_visit().chute).is_equal(RewardMachine.Chute.UPGRADE)
	for key: ChuteKey in view.keys:
		assert_bool(key.gold).is_true()
	for prize: MachinePrize in run.machine.prizes():
		assert_int(prize.rarity).is_greater_equal(MachinePrize.Rarity.RARE)
	await capture.call("announce", 0.2)
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(screen._machine.announce.is_shown()).is_true()
	assert_array(_errors).is_empty()


## A capture holds the real pointer (hold_pointer, from the start of a --capture run): the
## viewport's GUI takes no pointer input, so wherever the OS pointer rests over the window it
## hovers, tooltips and clicks nothing, and a capture records only the hover it asks for
## (effects(), still driven through the screen's API). Leaving the tree gives the pointer back.
## (Headless runs never move the mouse, so the test checks the viewport's switch.)
func test_a_capture_holds_the_real_pointer() -> void:
	var capture: Control = (load(CAPTURE) as PackedScene).instantiate() as Control
	get_tree().root.add_child(capture)
	var viewport: Viewport = capture.get_viewport()
	await _frames(2)
	assert_bool(viewport.gui_disable_input).is_false()
	capture.call("hold_pointer")
	assert_bool(viewport.gui_disable_input).is_true()
	await capture.call("effects", "multipack")
	await _frames(1)
	var screen: ShiftScreen = capture.call("screen")
	assert_str(screen._effects.focused_card().definition.id).is_equal("multipack")
	await _frames(2)
	get_tree().root.remove_child(capture)
	assert_bool(viewport.gui_disable_input).is_false()
	capture.queue_free()
	await _frames(2)


func test_a_card_not_on_the_counter_goes_to_the_reporter() -> void:
	var capture: Control = scene_runner(CAPTURE).scene()
	capture.set("report_error", _record)
	var screen: ShiftScreen = capture.call("screen")
	await capture.call("scan", "soup")
	assert_int(_errors.size()).is_equal(1)
	assert_str(_errors[0]).is_equal("No soup on the counter to scan")
	assert_object(screen._scan.scanned()).is_null()


func test_a_failed_capture_goes_to_the_reporter() -> void:
	var capture: Control = scene_runner(CAPTURE).scene()
	capture.set("report_error", _record)
	capture.set("grab_image", func() -> Image: return null)
	await capture.call("capture", _capture_folder)
	assert_int(_errors.size()).is_equal(1)
	assert_bool(_errors[0].begins_with("Can't save")).is_true()
	assert_int(DirAccess.get_files_at(_capture_folder).size()).is_equal(0)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


func _record(message: String) -> void:
	_errors.append(message)


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
