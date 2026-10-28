extends GdUnitTestSuite
## The belt in the count on the real shift screen (#86 v6, BeltRide; mock-up count_up_86_v6_scan
## approved on 2026-10-19). A ride slides the row one cell toward the scanner (the first cell):
## nothing jumps as the cell before hides, the box slides back on the art grid to rest, the slats
## run with it, and the arriving item stands where item 0 stood, marked by the scanner; the item
## scanned before hops into the bag over the ride (a copy of its art, shrinking to 1x art at its
## peek place, its cell hidden at once), and source_rect gives each item's sprite, or the bag's
## mouth once bagged. Reduced motion snaps every move. The last ride empties the belt and clears
## the scanner. A real checkout keeps every shown item on the belt and inside the stage, fires each
## landed step's sticker (punch, then a check on its corner), sends an armed giver's sparks to its
## targets' stickers, and ends with the belt empty and the bag holding the row; a resumed checkout
## shows that end at once, and the next shift's reset brings the row back and empties the bag.
## No printed name goes into the bag, a bagged item's stickers stay hidden, and a folded stack's
## chip counts down only for the steps it folded in. Every rect is checked on screen (headless runs
## use a 1280x1280 window: the stage is centred, 280 px down). The real saves and logs are never
## touched.

const SCREEN := "res://ui/shift_screen.tscn"
const ROW: Array[String] = ["milk", "bread", "eggs", "milk"]
## #60's reference row (count_up_test), with Coupon engine and Slot engine given and the Spot
## check set: Eggs and Multipack arm effects that land on later items.
const FULL_ROW: Array[String] = ["eggs", "bread", "milk", "multipack", "milk", "milk", "milk"]
const RIDE_MS := 200
const BAG_MS := 300

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_belt_ride_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Item 0 is scanned where it stands; a ride slides item 1 in from its own place to item 0's (and
## item 2 to item 1's) without a jump, the box on the 2 px grid and moving left only, the slats
## running; item 0 hops up an arc into the bag and peeks out at 1x at its first place; then the
## scanner marks item 1 and source_rect gives the bag's mouth for item 0 and item 1's sprite.
func test_a_ride_slides_the_next_item_into_the_scanner_and_bags_the_last() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ROW)
	var ride: BeltRide = screen._ride
	var bag: PaperBag = screen._stage.bag
	var rests: Array[Rect2] = _sprites(screen)
	var scanner: Rect2 = screen._row_strip.slots[0].get_global_rect()
	assert_bool(scanner.has_point(rests[0].get_center())).is_true()
	ride.begin(screen.run.preview(), screen._row_views, false)
	screen._count_up.ride.emit(-1, 0, 0)
	_assert_scanner_on(screen, 0)
	_assert_rect(ride.source_rect(0), rests[0])
	screen._count_up.ride.emit(0, 1, RIDE_MS)
	# The cell before hides and the rest pack left, the box moved right as far: nothing jumps.
	assert_bool(screen._row_strip.slots[0].visible).is_false()
	assert_float(screen._row_strip.box.position.x).is_equal_approx(128.0, 0.01)
	assert_float(_sprite(screen, 1).position.x).is_equal_approx(rests[1].position.x, 0.5)
	assert_bool(ride.is_bagged(0)).is_true()
	_assert_rect(ride.source_rect(0), bag.mouth_rect())
	assert_bool(screen._stage.scan_layer.is_posed()).is_false()
	var hop: Control = bag.contents.get_child(0) as Control
	var hop_tops: Array[float] = []
	var lefts: Array[float] = []
	var frames: Dictionary[int, bool] = {}
	var failures: Array[String] = []
	var started: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < RIDE_MS + 150:
		await get_tree().process_frame
		var left: float = screen._row_strip.box.position.x
		if fmod(left, 2.0) != 0.0:
			failures.append("the box at %f, off the art grid" % left)
		if not lefts.is_empty() and left > lefts[-1]:
			failures.append("the box went back right to %f" % left)
		lefts.append(left)
		frames[screen._stage.belt.frame()] = true
		if is_instance_valid(hop):
			hop_tops.append(hop.get_global_rect().position.y)
			if not screen._stage.get_global_rect().encloses(hop.get_global_rect()):
				failures.append("the hop at %s off the stage" % hop.get_global_rect())
	assert_array(failures.slice(0, 5)).override_failure_message(str(failures)).is_empty()
	assert_float(screen._row_strip.box.position.x).is_equal(0.0)
	assert_int(frames.size()).is_greater(1)
	_assert_rect(_sprite(screen, 1), rests[0])
	_assert_rect(_sprite(screen, 2), rests[1])
	# The hop rose over its start before it dropped into the bag.
	assert_float(float(hop_tops.min())).is_less(
		minf(rests[0].position.y, bag.mouth_rect().position.y)
	)
	assert_array(bag.items()).is_equal([hop])
	assert_vector(hop.scale).is_equal(Vector2(PaperBag.ITEM_SCALE, PaperBag.ITEM_SCALE))
	var peek: Rect2 = bag.get_global_transform() * Rect2(PaperBag.PEEKS[0], PaperBag.ITEM_SIZE)
	_assert_rect(hop.get_global_rect(), peek)
	_assert_scanner_on(screen, 1)
	_assert_rect(ride.source_rect(1), _sprite(screen, 1))
	assert_int(ride.scanning()).is_equal(1)


## The hop and the bag carry no text: an art-pending item (Bread with no art_ref; every stocked
## product is drawn since #57) and an icon-less coupon (Bundle), whose belt art prints their names,
## hop in and peek out as their art alone.
func test_a_bagged_item_shows_no_printed_name() -> void:
	var screen: ShiftScreen = await _screen()
	var undrawn: CardDefinition = (
		(load("res://data/cards/bread.tres") as CardDefinition).duplicate()
	)
	undrawn.art_ref = ""
	screen.run.debug_add_to_hand(undrawn)
	screen._refresh()
	screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
	screen._on_slot_input(_left_click(), screen.run.row.size())
	await _place(screen, ["bundle", "milk"])
	var bag: PaperBag = screen._stage.bag
	for slot: int in range(2):
		var item: ItemView = screen._row_views[slot] as ItemView
		assert_object(item.find_child(ItemView.PRINTED_NAME, true, false)).is_not_null()
	screen._ride.begin(screen.run.preview(), screen._row_views, false)
	screen._count_up.ride.emit(-1, 0, 0)
	screen._count_up.ride.emit(0, 1, RIDE_MS)
	screen._count_up.ride.emit(1, 2, RIDE_MS)
	assert_int(bag.contents.get_child_count()).is_equal(2)
	assert_array(bag.find_children("*", "Label", true, false)).is_empty()
	await _seconds(RIDE_MS / 1000.0 + 0.1)
	assert_int(bag.items().size()).is_equal(2)
	assert_array(bag.find_children("*", "Label", true, false)).is_empty()


## A bagged item's stickers stay hidden: its stack is never fitted again where it no longer
## stands, so no rebuilt sticker shows over the belt (a rebuild forced here by a stale fold).
func test_a_bagged_items_stickers_stay_hidden() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	var layer: PlanningLayer = screen._stage.planning_layer
	var slot: int = -1
	for candidate: int in range(screen._row_views.size() - 1):
		if slot < 0 and not layer.stack(candidate).is_empty():
			slot = candidate
	assert_int(slot).is_greater_equal(0)
	screen._ride.begin(screen.run.preview(), screen._row_views, false)
	screen._count_up.ride.emit(-1, 0, 0)
	for scan: int in range(1, slot + 2):
		screen._count_up.ride.emit(scan - 1, scan, RIDE_MS)
	await _seconds(RIDE_MS / 1000.0 + 0.1)
	assert_bool(screen._ride.is_bagged(slot)).is_true()
	var stickers: Array[EffectSticker] = layer.stack(slot)
	for sticker: EffectSticker in stickers:
		assert_bool(sticker.is_visible_in_tree()).is_false()
	layer._folds[slot] = -2
	layer._layout_key.clear()
	layer.follow_views()
	assert_array(layer.stack(slot)).is_equal(stickers)
	for sticker: EffectSticker in layer.stack(slot):
		assert_bool(sticker.is_visible_in_tree()).is_false()


## A folded stack's chip ("+N") fires for the steps it folded in, never for a step on its item with
## no sticker (a denial, a repeated fizzle): it counts down by one for each, never gets a check,
## and goes (alpha 0) after the last (#105 piece 3).
func test_a_fold_fires_only_for_the_steps_it_folded() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	var ride: BeltRide = screen._ride
	var layer: PlanningLayer = screen._stage.planning_layer
	var result: ScoreResult = screen.run.preview()
	ride.begin(result, screen._row_views, false)
	var graph: EffectGraph = EffectGraph.build(result)
	var model: PlanningModel = layer.model()
	# An item with stickers and an incoming step that has none.
	var slot: int = -1
	var bare: int = -1
	for candidate: int in range(mini(model.slots.size(), screen._row_views.size())):
		var indices: PackedInt32Array = PackedInt32Array()
		for spec: StickerSpec in model.slots[candidate].stickers:
			indices.append(spec.step_index)
		for link: EffectLink in graph.incoming(candidate):
			if slot < 0 and not indices.is_empty() and not indices.has(link.step_index):
				slot = candidate
				bare = link.step_index
	assert_int(slot).is_greater_equal(0)
	var specs: Array[StickerSpec] = model.slots[slot].stickers
	var folded: Array[StickerSpec] = [StickerSpec.folded(specs.size())]
	layer._build_stack(slot, folded, layer._stack_box)
	var fold: EffectSticker = layer.stack(slot)[0]
	for spec: StickerSpec in specs:
		assert_object(ride._sticker_of(slot, spec.step_index)).is_same(fold)
	assert_object(ride._sticker_of(slot, bare)).is_null()
	assert_str(fold.text()).is_equal(StickerSpec.MORE_TEXT % specs.size())
	ride._reduced = true
	ride._on_step_landed(bare)
	assert_str(fold.text()).is_equal(StickerSpec.MORE_TEXT % specs.size())
	for index: int in range(specs.size()):
		ride._on_step_landed(specs[index].step_index)
		assert_bool(fold.is_fired()).is_true()
		assert_bool(fold.has_check()).is_false()
		var left: int = specs.size() - 1 - index
		if left > 0:
			assert_str(fold.text()).is_equal(StickerSpec.MORE_TEXT % left)
			assert_float(fold.modulate.a).is_equal(1.0)
	assert_float(fold.modulate.a).is_equal(0.0)


## Every ride, then the last (no item to scan): the belt ends empty with the row at rest, the
## scanner clear and the four items in the bag in order, each peeking at its place; source_rect
## gives the bag's mouth for every item.
func test_the_last_ride_empties_the_belt_into_the_bag() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ROW)
	var ride: BeltRide = screen._ride
	var bag: PaperBag = screen._stage.bag
	ride.begin(screen.run.preview(), screen._row_views, false)
	screen._count_up.ride.emit(-1, 0, 0)
	for slot: int in range(1, ROW.size()):
		screen._count_up.ride.emit(slot - 1, slot, RIDE_MS)
		await _seconds(RIDE_MS / 1000.0 + 0.1)
		_assert_scanner_on(screen, slot)
	screen._count_up.ride.emit(ROW.size() - 1, -1, BAG_MS)
	assert_bool(screen._stage.scan_layer.is_posed()).is_false()
	assert_int(ride.scanning()).is_equal(-1)
	await _seconds(BAG_MS / 1000.0 + 0.1)
	_assert_belt_empty(screen)
	assert_int(bag.items().size()).is_equal(ROW.size())
	for index: int in range(ROW.size()):
		var place: Rect2 = Rect2(PaperBag.PEEKS[index], PaperBag.ITEM_SIZE)
		_assert_rect(bag.items()[index].get_global_rect(), bag.get_global_transform() * place)
		_assert_rect(ride.source_rect(index), bag.mouth_rect())


## Reduced motion: the next item steps into the scanner at once (no slide, no slats), the bagged
## one is in the bag at once, and the scanner marks the item without a sweep.
func test_reduced_motion_snaps_the_ride() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ROW)
	var rests: Array[Rect2] = _sprites(screen)
	var frame: int = screen._stage.belt.frame()
	screen._ride.begin(screen.run.preview(), screen._row_views, true)
	screen._count_up.ride.emit(-1, 0, 0)
	screen._count_up.ride.emit(0, 1, RIDE_MS)
	assert_float(screen._row_strip.box.position.x).is_equal(0.0)
	await _frames(1)
	_assert_rect(_sprite(screen, 1), rests[0])
	assert_int(screen._stage.bag.items().size()).is_equal(1)
	assert_int(screen._stage.belt.frame()).is_equal(frame)
	_assert_scanner_on(screen, 1)
	assert_bool(screen._stage.scan_layer.is_sweeping()).is_false()


## A real checkout of the reference row: every shown item stays on the belt's top face and inside
## the stage, the scanned one at the scanner whenever it is marked; each landed step's sticker
## fires (it punches, and its check settles on its top right corner, on the stage); an armed
## giver's beat sends sparks (inside the stage) to its targets' stickers, which charge; the belt
## ends empty, the bag holding every item, and the count's flights no longer ask the ride.
func test_a_checkout_rides_every_item_into_the_bag_and_fires_the_stickers() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	var ride: BeltRide = screen._ride
	var layer: PlanningLayer = screen._stage.planning_layer
	var belt: Rect2 = screen._stage.belt.get_global_rect()
	var stage: Rect2 = screen._stage.get_global_rect()
	var scanner: Rect2 = screen._row_strip.slots[0].get_global_rect()
	var fired: Array[EffectSticker] = []
	var punched: Array[bool] = [false]
	var charged: Array[bool] = [false]
	var sparks: Array[int] = [0]
	var failures: Array[String] = []
	# The sparks draw over the stickers, under the hover's hot strips and the stack fan.
	assert_object(ride.sparks().get_parent()).is_same(layer)
	assert_int(ride.sparks().get_index()).is_equal(layer.fan().get_index() - 2)
	screen._on_checkout_pressed()
	assert_bool(screen._count_up.source_rect == Callable(ride, "source_rect")).is_true()
	while screen._counting:
		await get_tree().process_frame
		for slot: int in range(screen._row_views.size()):
			var item: ItemView = screen._row_views[slot] as ItemView
			if not item.is_visible_in_tree():
				continue
			var sprite: Rect2 = BeltRide.sprite_rect(item)
			if sprite.position.x < belt.position.x or sprite.end.x > belt.end.x:
				failures.append("slot %d at %s off the belt" % [slot, sprite])
			if not stage.encloses(sprite):
				failures.append("slot %d at %s off the stage" % [slot, sprite])
			if slot == ride.scanning() and screen._stage.scan_layer.is_posed():
				if not scanner.has_point(sprite.get_center()):
					failures.append("slot %d marked off the scanner" % slot)
			for sticker: EffectSticker in layer.stack(slot):
				if sticker.is_fired() and not fired.has(sticker):
					fired.append(sticker)
				if sticker.is_firing():
					punched[0] = punched[0] or (sticker.get_child(0) as Control).scale.x > 1.05
					charged[0] = charged[0] or not sticker.is_fired()
		sparks[0] = maxi(sparks[0], ride.sparks().running())
		for head: Vector2 in ride.sparks().heads():
			if not stage.has_point(ride.sparks().get_global_transform() * head):
				failures.append("a spark at %s off the stage" % head)
		for sticker: EffectSticker in fired:
			if is_instance_valid(sticker) and sticker.has_check() and sticker.is_visible_in_tree():
				var check: Rect2 = sticker.get_global_transform() * sticker.check_rect()
				var corner: Vector2 = sticker.get_global_rect().position
				corner.x += sticker.size.x
				if not check.grow(1.0).has_point(corner) or not stage.encloses(check):
					failures.append("a check at %s off its corner %s" % [check, corner])
	assert_array(failures.slice(0, 5)).override_failure_message(str(failures)).is_empty()
	assert_int(fired.size()).is_greater(3)
	assert_bool(punched[0]).is_true()
	assert_int(sparks[0]).is_greater(0)
	assert_bool(charged[0]).is_true()
	_assert_belt_empty(screen)
	assert_int(screen._stage.bag.items().size()).is_equal(FULL_ROW.size())
	assert_bool(screen._count_up.source_rect.is_valid()).is_false()


## A sticker's fire (EffectSticker.fire): it punches past 1.4 and turns, then settles back at rest
## with its check shown on its top right corner; under reduced motion the check shows at once with
## no punch. A charge punches lightly and shows no check.
func test_a_sticker_fires_with_a_punch_then_a_check() -> void:
	var screen: ShiftScreen = await _screen()
	await _full_row(screen)
	var stickers: Array[EffectSticker] = []
	for slot: int in range(screen._row_views.size()):
		stickers.append_array(screen._stage.planning_layer.stack(slot))
	assert_int(stickers.size()).is_greater(2)
	var sticker: EffectSticker = stickers[0]
	var inner: Control = sticker.get_child(0) as Control
	sticker.fire(false)
	await _frames(1)
	var peak: float = inner.scale.x
	assert_float(peak).is_greater(1.4)
	assert_bool(sticker.has_check()).is_false()
	await _seconds(EffectSticker.CHECK_AT + EffectSticker.CHECK_SETTLE_S + 0.1)
	assert_vector(inner.scale).is_equal(Vector2.ONE)
	assert_float(inner.rotation).is_equal(0.0)
	assert_bool(sticker.has_check()).is_true()
	var check: Rect2 = sticker.check_rect()
	assert_float(check.end.x).is_equal(sticker.size.x + EffectSticker.CHECK_OVERHANG.x)
	assert_float(check.position.y).is_equal(-EffectSticker.CHECK_OVERHANG.y)
	var calm: EffectSticker = stickers[1]
	calm.fire(true)
	assert_bool(calm.has_check()).is_true()
	assert_vector((calm.get_child(0) as Control).scale).is_equal(Vector2.ONE)
	assert_bool(calm.is_firing()).is_false()
	var charged: EffectSticker = stickers[2]
	charged.charge(false)
	await _frames(1)
	var light: float = (charged.get_child(0) as Control).scale.x
	assert_float(light).is_greater(1.0)
	assert_float(light).is_less(peak)
	assert_bool(charged.has_check()).is_false()
	charged.charge(true)
	assert_bool(charged.is_firing()).is_false()


## A resumed checkout shows the count's end at once (show_end_state): the belt empty, the items in
## the bag in row order; the next shift's reset brings every cell back, the row at rest, and
## empties the bag.
func test_the_end_state_and_the_reset() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ROW)
	var rests: Array[Rect2] = _sprites(screen)
	screen._ride.show_end_state(screen._row_views)
	await _frames(1)
	_assert_belt_empty(screen)
	var bagged: Array[Control] = screen._stage.bag.items()
	assert_int(bagged.size()).is_equal(ROW.size())
	for index: int in range(ROW.size()):
		var art: TextureRect = bagged[index] as TextureRect
		var expected: TextureRect = ItemView.item_art(screen.run.row[index].definition)
		assert_object(art.texture).is_same(expected.texture)
		expected.free()
		_assert_rect(screen._ride.source_rect(index), screen._stage.bag.mouth_rect())
	screen._ride.reset()
	await _frames(2)
	for cell: PanelContainer in screen._row_strip.slots + screen._row_strip.closed:
		assert_bool(cell.visible).is_true()
	assert_vector(screen._row_strip.box.position).is_equal(Vector2.ZERO)
	assert_array(screen._stage.bag.items()).is_empty()
	assert_int(screen._stage.bag.contents.get_child_count()).is_equal(0)
	var now: Array[Rect2] = _sprites(screen)
	for index: int in range(ROW.size()):
		_assert_rect(now[index], rests[index])


func _assert_scanner_on(screen: ShiftScreen, slot: int) -> void:
	var overlay: ScanOverlay = screen._stage.scan_layer
	assert_bool(overlay.is_posed()).override_failure_message("slot %d unposed" % slot).is_true()
	var frame: Rect2 = ScanOverlay.scan_frame(screen._row_views[slot] as ItemView)
	var brackets: Rect2 = overlay.get_global_transform() * overlay.brackets()
	_assert_rect(brackets, frame.grow(ScanOverlay.BRACKET_OUTSET))
	assert_bool(overlay.scan_line().has_area()).is_true()
	assert_that(overlay.bracket_color()).is_equal(Palette.GOLD)


func _assert_belt_empty(screen: ShiftScreen) -> void:
	for cell: PanelContainer in screen._row_strip.slots + screen._row_strip.closed:
		assert_bool(cell.visible).is_false()
	assert_vector(screen._row_strip.box.position).is_equal(Vector2.ZERO)
	assert_bool(screen._stage.scan_layer.is_posed()).is_false()
	for slot: int in range(screen._row_views.size()):
		for sticker: EffectSticker in screen._stage.planning_layer.stack(slot):
			assert_bool(sticker.is_visible_in_tree()).is_false()


func _assert_rect(actual: Rect2, expected: Rect2) -> void:
	var message: String = "%s is not %s" % [actual, expected]
	(
		assert_float(actual.position.distance_to(expected.position))
		. override_failure_message(message)
		. is_less(0.6)
	)
	assert_float(actual.size.distance_to(expected.size)).override_failure_message(message).is_less(
		0.6
	)


static func _sprite(screen: ShiftScreen, slot: int) -> Rect2:
	return BeltRide.sprite_rect(screen._row_views[slot] as ItemView)


static func _sprites(screen: ShiftScreen) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for slot: int in range(screen._row_views.size()):
		rects.append(_sprite(screen, slot))
	return rects


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(2)
	return screen


## The reference row on shift 1: Coupon engine and Slot engine given, the Spot check set.
func _full_row(screen: ShiftScreen) -> void:
	screen._debug.give_upgrade("coupon_engine")
	screen._debug.give_upgrade("slot_engine")
	screen._debug.set_inspection("spot_check")
	await _place(screen, FULL_ROW)


## Places each card at the row's end as the player does: picked from the hand, then its slot
## clicked.
func _place(screen: ShiftScreen, ids: Array[String]) -> void:
	var placed: int = screen.run.row.size()
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(placed + ids.size())
	await _frames(3)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	for view: Control in screen._hand_box.cards():
		if (view as CardView).card == card:
			return view as CardView
	return null


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
