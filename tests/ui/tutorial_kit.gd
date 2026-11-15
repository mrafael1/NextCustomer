extends RefCounted
## Helpers for the tutorial's UI suites (no class_name: tests/ is not exported; load it with
## preload("res://tests/ui/tutorial_kit.gd")): a guided run started on a real shift screen, the
## opening board driven through its own input and clock, shift 1's moves through the screen's
## handlers (headless runs deliver no mouse events), and the overlay's geometry checks.

const SCREEN := "res://ui/shift_screen.tscn"
const Rush := preload("res://tests/ui/count_up_rush.gd")
const STEP := 1.0 / 60.0
const SIZES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080)]


## A shift screen (its own run started, not guided) added under `parent`, with `reduced` motion
## on its profile.
static func screen(parent: Node, reduced: bool = true) -> ShiftScreen:
	var made: ShiftScreen = (load(SCREEN) as PackedScene).instantiate()
	parent.add_child(made)
	await frames(1)
	made.profile.set_reduced_motion(reduced)
	return made


## Starts the guided first run on `shift` (with the cart reveal, as the title's START RUN does).
static func start_guided(shift: ShiftScreen, seed_value: int) -> StartBoard:
	shift.start_new_run(seed_value, true, true, true)
	var board: StartBoard = shift._cart_reveal.board
	board.store.frozen = true
	board.staff.frozen = true
	return board


## Waits until the director shows step `id` (at most `ms` of real time); whether it did.
static func until_step(shift: ShiftScreen, id: StringName, ms: int = 4000) -> bool:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < ms:
		var director: TutorialDirector = shift.tutorial
		if director.step_id() == id and director.overlay() != null:
			await frames(2)
			return true
		_pump(shift)
		await frames(1)
	return false


## Moves the opening board's frozen clocks on a little (the pages run on their own).
static func _pump(shift: ShiftScreen) -> void:
	var board: StartBoard = shift._cart_reveal.board if shift._cart_reveal.is_open() else null
	if board == null:
		return
	run_page(board.store, 0.25)
	for _step: int in 15:
		board.staff.advance(STEP)
	if board._slide_old != null:
		board._end_slide()


## Presses the shown callout's key (NEXT ›, GOT IT).
static func press(shift: ShiftScreen) -> bool:
	var overlay: TutorialOverlay = shift.tutorial.overlay()
	return overlay != null and overlay.callout().press_button()


static func run_page(page: BoosterPage, seconds: float) -> void:
	var left: float = seconds
	while left > 0.0001:
		page.advance(minf(STEP, left))
		left -= STEP


## A click (press and release) at art point `at` through the page's own input.
static func click_page(page: BoosterPage, at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at * ArtPen.UNIT
	page._gui_input(motion)
	page._gui_input(_button(at, true))
	page._gui_input(_button(at, false))
	page.advance(0.0)


static func _button(at: Vector2, pressed: bool) -> InputEventMouseButton:
	var button: InputEventMouseButton = InputEventMouseButton.new()
	button.button_index = MOUSE_BUTTON_LEFT
	button.pressed = pressed
	button.position = at * ArtPen.UNIT
	return button


## Booster `index`'s pouch centre (art px).
static func pouch(page: BoosterPage, index: int) -> Vector2:
	return BoosterArt.pouch_pos(page.boosters[index].cx) + Vector2(40, 40)


## The hand's item at place `at`.
static func hand_view(shift: ShiftScreen, at: int) -> ItemView:
	return shift._hand_box.view_at(at) as ItemView


## Picks the item at hand place `at` and drops it on slot `slot` (a click, then a slot click).
static func place(shift: ShiftScreen, at: int, slot: int) -> void:
	var view: ItemView = hand_view(shift, at)
	shift._on_hand_card_clicked(view)
	shift._on_slot_input(left_click(), slot)


## Picks the row's item at `from` and drops it on slot `slot`.
static func move(shift: ShiftScreen, from: int, slot: int) -> void:
	shift._on_row_card_clicked(shift._row_views[from])
	shift._on_slot_input(left_click(), slot)


static func left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


## The row's card ids.
static func row_ids(shift: ShiftScreen) -> Array[StringName]:
	var ids: Array[StringName] = []
	for card: CardInstance in shift.run.row:
		ids.append(card.definition.id)
	return ids


## Waits until the machine's keys or prizes take clicks.
static func until_armed(shift: ShiftScreen) -> bool:
	shift._machine.view.fast_forward()
	var start: int = Time.get_ticks_msec()
	while not shift._machine.view.is_armed() and Time.get_ticks_msec() - start < 4000:
		await frames(1)
	return shift._machine.view.is_armed()


## Whether the shown callout lies inside the screen (its overlay's rect) and covers none of its
## rings; "" when it does, else what is wrong.
static func callout_fault(overlay: TutorialOverlay) -> String:
	var card: TutorialCallout = overlay.callout()
	var box: Rect2 = card.get_global_rect()
	var screen_rect: Rect2 = overlay.get_global_rect()
	if not screen_rect.grow(1.0).encloses(box):
		return "callout %s off the screen %s" % [box, screen_rect]
	if box.size.x < 40.0 or box.size.y < 40.0:
		return "callout too small: %s" % box
	for ring: Rect2 in overlay.ring_rects():
		if ring.has_area() and box.grow(-2.0).intersects(ring):
			var nodes: Array = []
			for each: TutorialRing in overlay.rings():
				nodes.append(each.get_global_rect())
			return (
				"callout %s (%s) covers ring %s; rings %s view side %s"
				% [box, overlay.callout_side(), ring, nodes, overlay.view().side]
			)
	return ""


static func frames(count: int) -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	for _frame: int in count:
		await tree.process_frame


static func event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
