class_name CaptureTutorial
extends RefCounted
## The screen capture's guided first run (the tutorial, WP-8): `--tutorial=<step id>[,<option>]`
## starts the guided run on a fresh profile (the title's START RUN), plays it through the real
## calls (the boards' own clocks stepped, shift 1's moves through the screen's handlers, the
## machine's chute and SKIP) up to that step (a guided step's id, or a free planning moment: HINT,
## the first hint's bubble; RETRY and ANSWER, the lines after one and two missed rehearsals;
## GHOSTS, the answer's ghosts with two items laid), and captures it once it has settled. The
## week 1 strip's moments (v1.40): PLAN1 (shift 1's free planning, three items laid), COUNT1
## (shift 1's count as its TOTAL lands), MACHINE1 (the first visit, its keys armed) and WEEK2
## (the guided part played through, then shift 5's planning).
## Options: rm (reduced motion: no pulse, no fade), t=<seconds> (wait that long once the
## step shows; default SETTLE_S). The file name gets tutorial_<id>_[rm_]. Kept out of
## ScreenCapture so it stays under gdlint's file length; it drives game-side public parts and
## debug hooks only.

const ARGUMENT := "--tutorial="
const SEED := 20261115
## The page clocks' step, and how far one frame moves them while waiting.
const STEP_S := 1.0 / 60.0
const PUMP_S := 0.1
## How long a step may take to show (real time), and how long the capture waits once it shows.
const STEP_LIMIT_MS := 20000
const SETTLE_S := 0.6
## The free planning's moments reached in one move, and what _until_shown returns when the
## free planning takes input.
const FREE_TARGETS: Array[StringName] = [&"HINT", &"PLAN1", &"COUNT1"]
const FREE := &"FREE"
## The week 1 strip's moments past the free planning, and WEEK2's shift (its index).
const MACHINE1 := &"MACHINE1"
const WEEK2 := &"WEEK2"
const WEEK2_SHIFT := 4
## Frames the armed machine (or the opening board, its page done) waits with no line before its
## own move is made.
const QUIET_FRAMES := 30
## Hand places (TutorialScript.hand): a missing row (Eggs last, 29€) and the answer.
const WRONG: Array[int] = [0, 4, 1, 2, 5, 7, 3]
const ANSWER: Array[int] = [0, 4, 1, 3, 2, 5, 7]


## Plays the guided run up to the step `spec` names; returns the file name part ("" when the step
## never showed: the capture shows where it stopped).
static func play(screen: ShiftScreen, spec: String) -> String:
	var parts: PackedStringArray = spec.split(",", false)
	if parts.is_empty():
		return ""
	var target: StringName = StringName(parts[0])
	var reduced: bool = parts.has("rm")
	var settle: float = SETTLE_S
	for part: String in parts:
		if part.begins_with("t="):
			settle = part.trim_prefix("t=").to_float()
	screen.profile.set_reduced_motion(reduced)
	screen.start_new_run(SEED, true, true, true)
	var board: StartBoard = screen._cart_reveal.board
	board.store.frozen = true
	board.staff.frozen = true
	var reached: bool = false
	for _guard: int in 40:
		var shown: StringName = await _until_shown(screen)
		if shown == &"":
			reached = target == WEEK2 and _week_two(screen)
			break
		var choosing: bool = screen.run.phase == RunState.Phase.MACHINE_CHOOSE
		if shown == target or (target == MACHINE1 and choosing and screen._machine.is_open()):
			reached = true
			break
		if shown == FREE:
			reached = await _free(screen, target)
			if reached or FREE_TARGETS.has(target):
				break
			continue
		await _act(screen, shown)
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < settle * 1000.0:
		_pump(screen)
		await screen.get_tree().process_frame
	if not reached:
		return "tutorial_%s_missed_" % target
	return "tutorial_%s_%s" % [target, "rm_" if reduced else ""]


## Waits until the director shows a step; its id (&"": none showed in time).
static func _until_shown(screen: ShiftScreen) -> StringName:
	var start: int = Time.get_ticks_msec()
	var quiet: int = 0
	while Time.get_ticks_msec() - start < STEP_LIMIT_MS:
		var director: TutorialDirector = screen.tutorial
		if not director.is_active():
			return &""
		if director.overlay() != null:
			for _frame: int in 3:
				await screen.get_tree().process_frame
			return director.line_id()
		var waits: StringName = _own_move(screen)
		quiet = quiet + 1 if not waits.is_empty() else 0
		if quiet > QUIET_FRAMES:  # No line here (the machine, a board page done): its own move.
			return waits
		var input: bool = not screen._busy() and not screen._redraw_busy
		var planning: bool = screen.run.phase == RunState.Phase.PLANNING and input
		var step: TutorialStep = TutorialScript.guided().step(director.step_id())
		var lined: bool = director.line_id() != director.step_id()  # A retry line is due.
		if planning and step != null and step.is_free() and not lined:
			for _frame: int in 3:
				await screen.get_tree().process_frame
			return FREE
		_pump(screen)
		await screen.get_tree().process_frame
	return &""


## The move a screen with no line waits for (&"": none): the armed machine's phase's, the opening
## board's NEXT once its boosters are open and OPEN STORE once a pack is picked.
static func _own_move(screen: ShiftScreen) -> StringName:
	var machine: MachineFlow = screen._machine
	if machine.is_open() and machine.view.is_armed():
		var choosing: bool = screen.run.phase == RunState.Phase.MACHINE_CHOOSE
		return TutorialEvents.CHUTE_CHOSEN if choosing else TutorialEvents.MACHINE_RETURNED
	var board: StartBoard = screen._cart_reveal.board if screen._cart_reveal.is_open() else null
	if board == null or board.tips_blocked():
		return &""
	if board.page == 1 and board.store.page_done():
		return TutorialEvents.PAGE_SHOWN
	if board.page == 2 and board.selected() >= 0:
		return TutorialEvents.STORE_OPENED
	return &""


## The player's move on step `id`: the one its `advance_on` waits for (a machine phase's own when
## no line shows there), else its key.
static func _act(screen: ShiftScreen, id: StringName) -> void:
	var board: StartBoard = screen._cart_reveal.board if screen._cart_reveal.is_open() else null
	var step: TutorialStep = TutorialScript.guided().step(id)
	var waits: StringName = step.advance_on if step != null else id
	match waits:
		TutorialEvents.BOOSTERS_ALL_OPEN:
			var sealed: bool = board.store.boosters[0].state == BoosterOpening.State.SEALED
			_click_booster(board.store, 0 if sealed else 1)
		TutorialEvents.PAGE_SHOWN:
			board.store.primary()
		TutorialEvents.PACK_PICKED:
			board.pick(0)
		TutorialEvents.STORE_OPENED:
			board.staff.primary()
		TutorialEvents.CHUTE_CHOSEN:
			screen._machine._choose(RewardMachine.Chute.NEW_ITEMS)
			screen._machine.view.fast_forward()
		TutorialEvents.MACHINE_RETURNED:
			await _skip_prizes(screen)
		_:
			_press(screen)
	await screen.get_tree().process_frame


## The free planning's move toward `target`: whether the target now shows. HINT: the answer's
## first five laid (a rule works); GHOSTS: two answer items laid (the ANSWER line read);
## before RETRY, ANSWER or GHOSTS a missing row checked out; after them, the answer checked out
## (the run goes on).
static func _free(screen: ShiftScreen, target: StringName) -> bool:
	match target:
		&"HINT":
			_lay(screen, ANSWER.slice(0, 5))
			return true
		&"PLAN1":
			_lay(screen, ANSWER.slice(0, 3))
			return true
		&"COUNT1":
			_lay(screen, ANSWER)
			await _count_to_total(screen)
			return true
	var misses: int = screen.tutorial.misses()
	if target == &"GHOSTS" and misses >= TutorialScript.ANSWER_AFTER:
		_lay(screen, ANSWER.slice(0, 2))
		return true
	var wants_miss: bool = (
		(target == &"RETRY" and misses < 1)
		or (target in [&"ANSWER", &"GHOSTS"] and misses < TutorialScript.ANSWER_AFTER)
	)
	_lay(screen, WRONG if wants_miss else ANSWER)
	await _checkout(screen)
	return false


## CHECKOUT, the count played at its own pace until its TOTAL line lands.
static func _count_to_total(screen: ShiftScreen) -> void:
	var landed: Array[bool] = [false]
	screen._count_up.total_landed.connect(func() -> void: landed[0] = true, CONNECT_ONE_SHOT)
	screen._on_checkout_pressed()
	var start: int = Time.get_ticks_msec()
	while not landed[0] and Time.get_ticks_msec() - start < 3 * STEP_LIMIT_MS:
		await screen.get_tree().process_frame


## WEEK2: the guided part is over; the run jumps to week 2's first planning (no time card).
static func _week_two(screen: ShiftScreen) -> bool:
	if screen.run.phase != RunState.Phase.PLANNING:
		return false
	screen.run.debug_skip_to_shift(WEEK2_SHIFT)
	screen.debug_show_shift()
	screen._week.skip()
	return true


## Empties the row, then lays hand places `places` left to right.
static func _lay(screen: ShiftScreen, places: Array) -> void:
	while not screen.run.row.is_empty():
		screen._on_row_card_clicked(screen._row_views[0])
		screen._on_background_input(_left_click())
	for slot: int in places.size():
		_place(screen, int(places[slot]), slot)


static func _press(screen: ShiftScreen) -> void:
	var overlay: TutorialOverlay = screen.tutorial.overlay()
	if overlay != null:
		overlay.callout().press_button()


static func _click_booster(page: BoosterPage, index: int) -> void:
	var at: Vector2 = BoosterArt.pouch_pos(page.boosters[index].cx) + Vector2(40, 40)
	page.click(at)


static func _place(screen: ShiftScreen, place: int, slot: int) -> void:
	screen._on_hand_card_clicked(screen._hand_box.view_at(place) as ItemView)
	screen._on_slot_input(_left_click(), slot)


static func _left_click() -> InputEventMouseButton:
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	return click


## CHECKOUT, the count-up tapped through (the player's own skip) to its end.
static func _checkout(screen: ShiftScreen) -> void:
	var count_up: CountUp = screen._count_up
	var tap: Callable = func() -> void:
		if count_up._playing and not count_up._tapped:
			count_up._tap(Time.get_ticks_msec())
	screen._on_checkout_pressed()
	var start: int = Time.get_ticks_msec()
	while screen._counting and Time.get_ticks_msec() - start < STEP_LIMIT_MS:
		tap.call()
		await screen.get_tree().process_frame
	screen._machine.view.fast_forward()


## SKIP: the prizes binned, the landing played, the glide back over (shift 2's planning).
static func _skip_prizes(screen: ShiftScreen) -> void:
	screen._machine.view.skip_bin.pressed.emit()
	screen._machine.view.fast_forward()
	for _frame: int in 3:
		await screen.get_tree().process_frame
	screen._machine._end_return()


## Moves the opening board's frozen clocks on (the pages run on their own), ends a page slide,
## and plays the machine's waits through.
static func _pump(screen: ShiftScreen) -> void:
	if screen._machine.is_open() and not screen._machine.view.is_armed():
		screen._machine.view.fast_forward()
	var board: StartBoard = screen._cart_reveal.board if screen._cart_reveal.is_open() else null
	if board == null:
		return
	var left: float = PUMP_S
	while left > 0.0001:
		board.store.advance(minf(STEP_S, left))
		board.staff.advance(minf(STEP_S, left))
		left -= STEP_S
	if board._slide_old != null:
		board._end_slide()
