extends GdUnitTestSuite
## The machine in the store and the store's camera on the real shift screen (#77 machine v2,
## Q1 = A; build spec A1-A2, A6; memory: UI tests check layout, on-screen geometry). In planning
## the machine stands on the back wall at ShiftStage.MACHINE_WALL_RECT, half size, right of the
## monitor and under the top bar, dimmed, and takes no click (a click on it reaches the wall). A
## visit glides the StoreCamera to 2x: the machine then fills ShiftStage.MACHINE_RECT exactly, at a
## net scale of 1, inside the viewport and under the top bar, which never moves; the world covers
## the viewport at 2x (1280x720 and 1920x1080); the fore (belt, baskets, hand, receipt) drops out
## of frame while the monitor stays. Mid-glide the zoom and the receipt's copy are on their way.
## After the shift's last visit the camera glides back while planning waits (a hand click is
## ignored), then the machine is dim on the wall again; the basket redraw waits for the whole
## settle, then works with its tags on the baskets. Reduced motion cuts behind a charcoal fade
## (rm_fade_alpha at its peak) and the fore never moves. A visit resumed at its wait point opens
## at the machine, with no glide. Clicks are sent to the handlers (to the control a
## hit test finds); the real saves and logs are never touched.

const Rush := preload("res://tests/ui/count_up_rush.gd")
const SCREEN := "res://ui/shift_screen.tscn"
## Milk, Multipack, Milk x5 = 109: passes the first quotas.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
const WINDOWS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080)]
const MAX_VISITS := 6
## The geometry's tolerance (px).
const PX := 1.0

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_store_camera_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_the_idle_machine_stands_on_the_back_wall_at_half_size() -> void:
	var screen: ShiftScreen = await _screen()
	var view: RewardMachineView = screen._machine.view
	var xform: Transform2D = screen._stage.get_global_transform()
	assert_float(screen._camera.progress()).is_equal(0.0)
	assert_bool(view.is_visible_in_tree()).is_true()
	assert_bool(view.is_open()).is_false()
	var rect: Rect2 = view.get_global_rect()
	_assert_rect(rect, xform * ShiftStage.MACHINE_WALL_RECT, "wall rect")
	var on_stage: Rect2 = xform.affine_inverse() * rect
	assert_float(on_stage.position.y).is_greater_equal(ShiftStage.TOP_BAR_BOTTOM)
	assert_float(on_stage.position.x).is_greater_equal(ShiftStage.MONITOR_RECT.end.x)
	assert_vector(view.get_global_transform().get_scale()).is_equal_approx(
		Vector2(0.5, 0.5), Vector2(0.001, 0.001)
	)
	# Dim: darker and greyer.
	assert_float(view.lit_level()).is_equal(0.0)
	assert_float(view.modulate.r).is_less(1.0)
	assert_bool(view.veil.visible).is_true()
	# It takes no click: one at its centre reaches the wall and lets go of a picked card.
	assert_int(view.mouse_behavior_recursive).is_equal(Control.MOUSE_BEHAVIOR_DISABLED)
	screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[0]))
	assert_object(screen._picked).is_not_null()
	# Headless runs move no real pointer, so the press goes where the GUI would send it.
	var hit: Control = _topmost_at(screen, rect.get_center())
	assert_object(hit).is_same(screen._wall)
	hit.gui_input.emit(_left_click())
	await _frames(1)
	assert_object(screen._picked).is_null()


func test_the_camera_glides_to_2x_and_the_machine_fills_the_view() -> void:
	var screen: ShiftScreen = await _screen()
	var top_bar: Rect2 = screen._stage.top_bar.get_global_rect()
	await _pass(screen)
	var view: RewardMachineView = screen._machine.view
	assert_bool(view.is_open()).is_true()
	view.fast_forward()
	await _frames(3)
	var xform: Transform2D = screen._stage.get_global_transform()
	assert_float(screen._camera.progress()).is_equal(1.0)
	var rect: Rect2 = view.get_global_rect()
	assert_that(rect).is_equal(xform * ShiftStage.MACHINE_RECT)
	assert_vector(view.get_global_transform().get_scale()).is_equal(Vector2.ONE)
	var viewport: Rect2 = screen.get_viewport_rect()
	assert_bool(viewport.encloses(rect)).is_true()
	assert_float(rect.position.y).is_greater_equal(top_bar.end.y)
	assert_that(screen._stage.top_bar.get_global_rect()).is_equal(top_bar)
	assert_float(view.lit_level()).is_equal(1.0)
	assert_bool(view.veil.visible).is_false()
	# The top bar stays reachable: Cart and the menu, on the unzoomed hud.
	for button: Control in [screen._deck_button, screen._stage.top_bar.menu_button]:
		assert_bool(button.is_visible_in_tree()).is_true()
		assert_bool(top_bar.encloses(button.get_global_rect())).is_true()
	var keys: Rect2 = view.keys[0].get_global_rect().merge(view.keys[-1].get_global_rect())
	assert_bool(viewport.encloses(keys)).is_true()


## The world's bands at 2x cover the whole viewport (no clear colour at its corners or edges), in
## a 1280x720 and a 1920x1080 window.
func test_the_world_covers_the_viewport_at_2x() -> void:
	for window_size: Vector2 in WINDOWS:
		var window: Control = auto_free(Control.new())
		window.size = window_size
		add_child(window)
		var camera: StoreCamera = StoreCamera.new()
		window.add_child(camera)
		var wall: ColorRect = StoreBackdrop.screen_parts(camera.content)
		var stage: ShiftStage = ShiftStage.new(7)
		window.add_child(stage)
		camera.adopt(stage.world)
		await _frames(2)
		camera.set_view(1.0)
		var bounds: Rect2 = window.get_global_rect()
		var tag: String = str(window_size)
		assert_bool(wall.get_global_rect().encloses(bounds)).override_failure_message(tag).is_true()
		for band_name: String in ["Counter", "Floor"]:
			var band: Rect2 = (camera.content.get_node(band_name) as Control).get_global_rect()
			assert_float(band.position.x).override_failure_message(tag).is_less_equal(0.0)
			assert_float(band.end.x).override_failure_message(tag).is_greater_equal(bounds.end.x)
		var samples: Array[Vector2] = [
			bounds.position,
			Vector2(bounds.end.x - 1.0, bounds.position.y),
			Vector2(bounds.position.x, bounds.end.y - 1.0),
			bounds.end - Vector2.ONE,
			Vector2(bounds.get_center().x, bounds.position.y),
			Vector2(bounds.end.x - 1.0, bounds.get_center().y),
			Vector2(bounds.get_center().x, bounds.end.y - 1.0),
			Vector2(bounds.position.x, bounds.get_center().y),
		]
		for sample: Vector2 in samples:
			(
				assert_bool(_covered(camera.content, sample))
				. override_failure_message("%s at %s" % [tag, sample])
				. is_true()
			)
		window.queue_free()


## At the machine the fore (the belt, the bag, the baskets, the hand, the receipt and the printer)
## has dropped out of frame or faded away; the monitor stays.
func test_the_belt_and_baskets_drop_out_of_frame() -> void:
	var screen: ShiftScreen = await _passed_screen()
	var view: RewardMachineView = screen._machine.view
	view.fast_forward()
	await _frames(3)
	var stage: ShiftStage = screen._stage
	var bottom: float = screen.get_viewport_rect().end.y
	var faded: bool = stage.fore.modulate.a <= 0.1 + 0.001
	for part: Node in stage.fore.get_children():
		var control: Control = part as Control
		if control == null or not control.visible:
			continue
		var gone: bool = control.get_global_rect().position.y >= bottom
		assert_bool(gone or faded).override_failure_message(str(control.name)).is_true()
	assert_float(stage.fore.position.y).is_greater(0.0)
	assert_bool(stage.monitor.is_visible_in_tree()).is_true()
	assert_float(stage.monitor.modulate.a).is_equal(1.0)
	assert_object(stage.monitor.get_parent()).is_same(stage.world)


## Mid-glide the zoom is about 1.5 and the receipt's copy is between its rest and the slot.
func test_mid_glide_states() -> void:
	var screen: ShiftScreen = await _passed_screen()
	var view: RewardMachineView = screen._machine.view
	await _frames(2)
	var plan: MachinePlan = view.plan
	var feed: ReceiptFeed = view.receipt_feed
	view.show_at(0.0)
	var rest: Rect2 = feed.paper.get_global_rect()
	view.show_at(plan.fly_end)
	var slot: Rect2 = feed.paper.get_global_rect()
	var mid: float = (plan.glide + plan.glide_end) / 2.0
	view.show_at(mid)
	assert_float(screen._camera.progress()).is_equal_approx(0.5, 0.001)
	assert_float(screen._camera.zoom()).is_equal_approx(1.5, 0.01)
	assert_float(screen._stage.fore.position.y).is_between(1.0, view.tuning.fore_drop_px - 1.0)
	var at: Rect2 = feed.paper.get_global_rect()
	assert_float(at.position.x).is_between(
		minf(rest.position.x, slot.position.x), maxf(rest.position.x, slot.position.x)
	)
	# Up to the tear's lift and tilt above its path (v0.50: the slot sits lower than the
	# receipt's top), both at the camera's zoom.
	var tuning: MachineTuning = view.tuning
	var tilt: float = rest.size.x / 2.0 * sin(deg_to_rad(tuning.tear_tilt_deg))
	var lift: float = (tuning.tear_lift_px + tilt) * screen._camera.zoom()
	assert_float(at.position.y).is_between(
		minf(rest.position.y, slot.position.y) - lift, maxf(rest.position.y, slot.position.y)
	)
	assert_float(at.position.x).is_not_equal(rest.position.x)
	assert_float(at.position.y).is_not_equal(rest.position.y)


## After the shift's last visit the next shift's planning starts at once (saved), the camera
## glides back to 1x while a hand click is ignored, and at its end the machine is dim on the wall
## again and planning takes clicks.
func test_the_return_glide_restores_planning() -> void:
	var screen: ShiftScreen = await _passed_screen()
	var flow: MachineFlow = screen._machine
	for _visit: int in range(MAX_VISITS):
		if not RunState.MACHINE_PHASES.has(screen.run.phase):
			break
		_end_visit(screen)
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(flow.is_gliding()).is_true()
	assert_float(screen._camera.progress()).is_equal(1.0)
	screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[0]))
	assert_object(screen._picked).is_null()
	var length: float = MachinePlan.return_length(flow.view.tuning, false)
	flow._process(MachineTuning.sec(flow.view.tuning.return_glide_ms) / 2.0)
	assert_float(screen._camera.progress()).is_between(0.01, 0.99)
	flow._process(length)
	assert_bool(flow.is_gliding()).is_false()
	assert_float(screen._camera.progress()).is_equal(0.0)
	var view: RewardMachineView = flow.view
	var xform: Transform2D = screen._stage.get_global_transform()
	_assert_rect(view.get_global_rect(), xform * ShiftStage.MACHINE_WALL_RECT, "back on the wall")
	assert_float(view.lit_level()).is_equal(0.0)
	assert_float(screen._stage.fore.position.y).is_equal(0.0)
	assert_float(screen._stage.fore.modulate.a).is_equal(1.0)
	await _frames(2)
	screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[0]))
	assert_object(screen._picked).is_not_null()


## The basket redraw after the shift's last visit (#77 machine v2 with plan section 3.8): while the
## machine settles (the glide back, then the upgrade swap's wait) the Redraw key is ignored; once
## settled the fore is back at rest, Redraw arms, each tag sits inside its basket's front, the pop
## layer is at the stage's origin, and a basket click redraws it. The tags and the pop layer ride
## the fore; the redraw layer, whose flights go into the Cart, does not.
func test_the_redraw_waits_for_the_machine_to_settle() -> void:
	var screen: ShiftScreen = await _passed_screen()
	var flow: MachineFlow = screen._machine
	for _visit: int in range(MAX_VISITS):
		if not RunState.MACHINE_PHASES.has(screen.run.phase):
			break
		_end_visit(screen)
	var run: RunState = screen.run
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(flow.is_settling()).is_true()
	screen._on_redraw_pressed()
	assert_bool(screen._redraw_mode).is_false()
	assert_bool(screen._basket_tags.is_shown()).is_false()
	for _step: int in range(100):
		if not flow.is_settling():
			break
		flow._process(0.05)
	assert_bool(flow.is_settling()).is_false()
	await _frames(2)
	var stage: ShiftStage = screen._stage
	assert_float(stage.fore.position.y).is_equal(0.0)
	assert_int(run.redraws_used).is_less(run.redraws_allowed)
	screen._on_redraw_pressed()
	await _frames(2)
	assert_bool(screen._redraw_mode).is_true()
	var tags: BasketTags = screen._basket_tags
	assert_bool(tags.is_shown()).is_true()
	var xform: Transform2D = stage.get_global_transform()
	var picked: int = -1
	for basket: int in range(stage.baskets.basket_lefts().size()):
		if not run.can_redraw_basket(basket):
			continue
		if picked < 0:
			picked = basket
		var rect: Rect2 = tags.tag(basket).get_global_rect()
		var front: Rect2 = xform * stage.baskets.basket_rect(basket)
		assert_bool(tags.tag(basket).visible).override_failure_message(str(basket)).is_true()
		assert_bool(front.encloses(rect)).override_failure_message(str(rect)).is_true()
	assert_int(picked).is_greater_equal(0)
	_assert_rect(
		stage.pop_layer.get_global_rect(),
		xform * Rect2(Vector2.ZERO, stage.pop_layer.size),
		"pop layer at the stage's origin"
	)
	assert_bool(stage.fore.is_ancestor_of(tags)).is_true()
	assert_bool(stage.fore.is_ancestor_of(stage.pop_layer)).is_true()
	assert_bool(stage.fore.is_ancestor_of(stage.redraw_layer)).is_false()
	var used: int = run.redraws_used
	screen._on_basket_clicked(picked)
	assert_int(run.redraws_used).is_equal(used + 1)
	assert_bool(screen._redraw_busy).is_true()
	var start: int = Time.get_ticks_msec()
	while screen._redraw_busy and Time.get_ticks_msec() - start < 3000:
		await get_tree().process_frame
	assert_bool(screen._redraw_busy).is_false()


## Reduced motion: the camera cuts at glide + rm_cut_ms behind the charcoal fade, which peaks at
## rm_fade_alpha; the fore only fades (it never moves).
func test_reduced_motion_cuts_behind_a_fade() -> void:
	var screen: ShiftScreen = await _screen()
	screen._machine.view.reduced_motion = func() -> bool: return true
	await _pass(screen)
	var view: RewardMachineView = screen._machine.view
	var plan: MachinePlan = view.plan
	assert_bool(plan.reduced_motion).is_true()
	var tuning: MachineTuning = view.tuning
	var cut: float = plan.glide + MachineTuning.sec(tuning.rm_cut_ms)
	view.show_at(cut - 0.01)
	assert_float(screen._camera.progress()).is_equal(0.0)
	assert_float(screen._stage.fore.position.y).is_equal(0.0)
	view.show_at(plan.glide + MachineTuning.sec(tuning.rm_fade_ms) / 2.0)
	assert_bool(screen._camera.fade.visible).is_true()
	assert_float(screen._camera.fade.modulate.a).is_equal_approx(tuning.rm_fade_alpha, 0.01)
	view.show_at(cut)
	assert_float(screen._camera.progress()).is_equal(1.0)
	assert_float(screen._stage.fore.position.y).is_equal(0.0)
	assert_float(screen._stage.fore.modulate.a).is_less_equal(0.1 + 0.001)
	view.show_at(plan.choose_at)
	assert_float(screen._camera.fade.modulate.a).is_equal(0.0)


## A run saved at MACHINE_CHOOSE resumes at the machine: the camera at 2x at once, no glide.
func test_a_resume_opens_zoomed() -> void:
	await _passed_screen()
	var resumed: ShiftScreen = await _screen()
	var view: RewardMachineView = resumed._machine.view
	assert_bool(view.plan.resumed).is_true()
	await _frames(2)
	assert_float(resumed._camera.progress()).is_equal(1.0)
	assert_bool(resumed._machine.is_gliding()).is_false()
	var xform: Transform2D = resumed._stage.get_global_transform()
	assert_that(view.get_global_rect()).is_equal(xform * ShiftStage.MACHINE_RECT)


# --- helpers ---------------------------------------------------------------------------------


## Whether a visible ColorRect under `root` covers `point` (screen coordinates).
static func _covered(root: Node, point: Vector2) -> bool:
	for node: Node in root.find_children("*", "ColorRect", true, false):
		var band: ColorRect = node as ColorRect
		if band.is_visible_in_tree() and band.color.a >= 1.0:
			if band.get_global_rect().has_point(point):
				return true
	return false


func _assert_rect(actual: Rect2, expected: Rect2, what: String) -> void:
	var tolerance: Vector2 = Vector2(PX, PX)
	assert_vector(actual.position).override_failure_message(what).is_equal_approx(
		expected.position, tolerance
	)
	assert_vector(actual.size).override_failure_message(what).is_equal_approx(
		expected.size, tolerance
	)


## The control a click at `point` reaches, picked as the GUI does: the last drawn visible
## control under the point that doesn't ignore the mouse (children over their parent, later
## siblings over earlier ones, none under a control whose mouse is disabled), or null.
static func _topmost_at(node: Node, point: Vector2) -> Control:
	for index: int in range(node.get_child_count() - 1, -1, -1):
		var child: Node = node.get_child(index)
		var item: CanvasItem = child as CanvasItem
		if item != null and not item.visible:
			continue
		var disabled: Control = child as Control
		if (
			disabled != null
			and disabled.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED
		):
			continue
		var found: Control = _topmost_at(child, point)
		if found != null:
			return found
	var control: Control = node as Control
	if (
		control != null
		and control.mouse_filter != Control.MOUSE_FILTER_IGNORE
		and control.get_global_rect().has_point(point)
	):
		return control
	return null


func _end_visit(screen: ShiftScreen) -> void:
	var run: RunState = screen.run
	screen._machine.view.fast_forward()
	if run.phase == RunState.Phase.MACHINE_CHOOSE:
		var chute: int = MachineSteps.first_lit(run, RewardMachine.Chute.NEW_ITEMS)
		assert_bool(screen._machine._choose(chute)).is_true()
	if run.machine.can_bin():
		screen._machine._on_binned()
	else:
		screen._machine._take(0, run.deck.cards[0] if run.deck_is_full() else null)
	screen._machine.view.fast_forward()


func _passed_screen() -> ShiftScreen:
	var screen: ShiftScreen = await _screen()
	await _pass(screen)
	return screen


func _screen() -> ShiftScreen:
	var scene: PackedScene = load(SCREEN)
	var screen: ShiftScreen = auto_free(scene.instantiate())
	scene_runner(screen)
	screen._week.skip()  # The time card (v0.70) stays out of the way.
	await _frames(4)
	return screen


func _pass(screen: ShiftScreen) -> void:
	for id: String in PASSING_ROW:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	await Rush.checkout(screen)
	assert_int(screen.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)


func _frames(count: int) -> void:
	for i: int in range(count):
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


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
