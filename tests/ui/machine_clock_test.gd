extends GdUnitTestSuite
## The RECEIPT REWARDS machine's clock on the real shift screen (#77, build spec 4.2-4.4, U0):
## a visit's MachinePlan runs from the dessert's printer feed and holds at its wait points (the
## chute keys, the revealed prizes) until the player acts, arming only there; its beats fire once
## each, in order, as the clock passes them (a fast-forward fires the rest with `skipping` set);
## the landing runs to END, then `finished` opens the next shift; a tap fast-forwards and is
## logged as presentation_skipped (during the landing, as machine_landing_skipped); reduced
## motion reaches the plan; a resumed visit (a TICKET or BONUS at its chute wait, a TICKET or
## STAMP DAY at its pick wait) starts at its wait point with nothing replayed; every part is hooked
## (setup) and framed; show_at holds at the wait point and still finishes at END; the landing and
## the free-running idle time reach the parts. Clicks are sent to the handlers, because headless
## runs don't deliver input events.

const SCREEN := "res://ui/shift_screen.tscn"
const Rush := preload("res://tests/ui/count_up_rush.gd")
## The most visits a shift has (the ticket, a bonus ticket, STAMP DAY), with room to spare.
const MAX_VISITS := 6
## Milk, Multipack, Milk x5 = 109: passes the first five quotas.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]

var _folder: String = ""
## The beats seen: [name, plan time, skipping].
var _beats: Array = []


func before_test() -> void:
	_folder = "user://test_machine_clock_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_beats = []


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The ticket's visit: a TICKET plan from 0 that holds at the chute keys, arms only there, and
## fires feed, glide (the camera to the machine, #77 machine v2), read and lights once each, in
## order, before it.
func test_the_intro_runs_to_the_chute_wait_and_arms_there() -> void:
	var screen: ShiftScreen = await _passed_screen()
	var view: RewardMachineView = screen._machine.view
	assert_object(view.plan).is_not_null()
	assert_int(view.plan.kind).is_equal(MachineVisit.Kind.TICKET)
	assert_bool(view.plan.resumed).is_false()
	assert_bool(view.is_armed()).is_false()
	await _until(func() -> bool: return view.is_armed(), 8000)
	assert_bool(view.is_armed()).is_true()
	assert_float(view.clock).is_equal(view.plan.choose_at)
	assert_array(_names()).is_equal([&"feed", &"glide", &"read", &"lights", &"armed"])
	for seen: Array in _beats:
		assert_bool(seen[2]).is_false()
	# Held: the clock stays at the wait point.
	await _frames(5)
	assert_float(view.clock).is_equal(view.plan.choose_at)


## The whole visit with fast-forwards: the draw holds at the revealed prizes, the landing runs to
## END and `finished` starts the next shift once; every beat fires once, in time order, with
## `skipping` set on the way.
func test_a_visit_fires_every_beat_once_and_finishes_once() -> void:
	var screen: ShiftScreen = await _passed_screen()
	var view: RewardMachineView = screen._machine.view
	var finished: Array[int] = []
	view.finished.connect(func() -> void: finished.append(1))
	view.fast_forward()
	assert_float(view.clock).is_equal(view.plan.choose_at)
	assert_bool(_beats.all(func(seen: Array) -> bool: return seen[2])).is_true()
	await _frames(2)
	assert_bool(view.is_armed()).is_true()
	assert_bool(screen._machine._choose(RewardMachine.Chute.NEW_ITEMS)).is_true()
	assert_bool(view.is_armed()).is_false()
	view.fast_forward()
	assert_float(view.clock).is_equal(view.plan.pick_at)
	await _frames(2)
	assert_bool(view.is_armed()).is_true()
	var plan: MachinePlan = view.plan
	view.pick(0)
	screen._machine.on_deck_added()
	assert_int(screen.run.phase).is_equal(RunState.Phase.SCORED)
	assert_bool(view.is_armed()).is_false()
	assert_array(finished).is_empty()
	view.fast_forward()
	assert_array(finished).is_equal([1])
	assert_int(screen.run.shift_index).is_equal(1)
	assert_bool(screen._machine.is_open()).is_false()
	var expected: Array[StringName] = plan.beat_names()
	expected.insert(expected.find(&"draw"), &"armed")
	expected.insert(expected.find(&"pick"), &"armed")
	assert_array(_names()).is_equal(expected)
	assert_bool(expected.has(&"punch")).is_false()  # v0.47: no Regular meter to punch.
	var times: Array = _beats.filter(func(seen: Array) -> bool: return seen[0] != &"armed")
	for index: int in range(1, times.size()):
		assert_float(times[index][1]).is_greater_equal(times[index - 1][1])


## Left alone, the clock plays the visit in game time: the draw reaches the prizes, the landing
## reaches END, and the next shift starts with nothing fast-forwarded.
func test_the_clock_plays_a_visit_to_its_end() -> void:
	var screen: ShiftScreen = await _passed_screen()
	var view: RewardMachineView = screen._machine.view
	await _until(func() -> bool: return view.is_armed(), 5000)
	assert_bool(screen._machine._choose(RewardMachine.Chute.NEW_ITEMS)).is_true()
	await _until(func() -> bool: return view.is_armed(), 15000)
	assert_float(view.clock).is_equal(view.plan.pick_at)
	view._on_bin_pressed()
	await _until(func() -> bool: return screen.run.shift_index == 1, 15000)
	assert_int(screen.run.shift_index).is_equal(1)
	assert_bool(_beats.any(func(seen: Array) -> bool: return seen[2])).is_false()
	assert_bool(_names().has(&"land")).is_false()  # A bin has no landing.
	assert_bool(_names().has(&"pick")).is_true()
	assert_bool(_last_event("machine_visit")["presentation_skipped"]).is_false()


## A tap during a non-interactive beat fast-forwards to the wait point and is logged as the
## visit's presentation_skipped; a tap at a wait point does nothing.
func test_a_tap_fast_forwards_and_is_logged() -> void:
	var screen: ShiftScreen = await _passed_screen()
	var view: RewardMachineView = screen._machine.view
	var skips: Array[int] = []
	view.skipped.connect(func() -> void: skips.append(1))
	view._on_tapped(0)
	assert_array(skips).has_size(1)
	assert_float(view.clock).is_equal(view.plan.choose_at)
	view._on_tapped(0)
	assert_array(skips).has_size(1)
	assert_bool(screen._machine._choose(RewardMachine.Chute.NEW_ITEMS)).is_true()
	await _until(func() -> bool: return view.is_armed(), 15000)
	view.pick(0)
	screen._machine.on_deck_added()
	view.fast_forward()
	assert_bool(_last_event("machine_visit")["presentation_skipped"]).is_true()


## Reduced motion reaches the visit's plan (read when the visit opens).
func test_reduced_motion_reaches_the_plan() -> void:
	var screen: ShiftScreen = await _screen()
	screen.profile.set_reduced_motion(true)
	await _pass(screen)
	var view: RewardMachineView = screen._machine.view
	assert_bool(view.plan.reduced_motion).is_true()
	# The camera cuts to the machine behind the charcoal fade (#77 machine v2), no glide.
	var cut: float = view.plan.glide + MachineTuning.sec(view.tuning.rm_cut_ms)
	assert_float(view.plan.camera_at(cut - 0.01)).is_equal(0.0)
	assert_float(view.plan.camera_at(cut)).is_equal(1.0)
	assert_float(view.plan.fade_at(cut)).is_greater(0.0)
	screen.profile.set_reduced_motion(false)


## A run resumed at MACHINE_PICK starts at the pick wait with its prizes shown: armed at once,
## no beat before it fires; at MACHINE_CHOOSE it starts at the chute wait. The beats are
## recorded from the screen's first frame, so a replayed intro or draw would show.
func test_a_resumed_visit_starts_at_its_wait_point() -> void:
	var first: ShiftScreen = await _passed_screen()
	_beats = []
	var resumed: ShiftScreen = await _screen()
	var view: RewardMachineView = resumed._machine.view
	assert_int(view.plan.kind).is_equal(MachineVisit.Kind.TICKET)
	await _assert_resumed_at(view, view.plan.choose_at)
	assert_bool(first._machine._choose(RewardMachine.Chute.NEW_ITEMS)).is_true()
	_beats = []
	var again: ShiftScreen = await _screen()
	view = again._machine.view
	assert_int(view.tickets.size()).is_equal(again.run.machine.prizes().size())
	await _assert_resumed_at(view, view.plan.pick_at)


## The bonus ticket's visit resumed at its chute wait, and a PREMIUM ticket visit's at its pick
## wait (build spec 4.3's resume table): each starts there, armed, with nothing before it
## replayed (the PREMIUM transform included: the keys are gold at once).
func test_bonus_and_premium_resume_at_their_wait_points() -> void:
	var first: ShiftScreen = await _screen()
	first.start_new_run(5)
	var bonus: bool = false
	var premium: bool = false
	for _shift: int in range(first.run.shift_count() - 1):
		await _pass(first, true)
		for _visit: int in range(MAX_VISITS):
			var run: RunState = first.run
			if not RunState.MACHINE_PHASES.has(run.phase):
				break
			var kind: int = run.machine.current_visit().kind
			if kind == MachineVisit.Kind.BONUS and not bonus:
				bonus = true
				assert_int(run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
				var resumed: ShiftScreen = await _screen()
				var view: RewardMachineView = resumed._machine.view
				assert_int(view.plan.kind).is_equal(MachineVisit.Kind.BONUS)
				await _assert_resumed_at(view, view.plan.choose_at)
			elif kind == MachineVisit.Kind.TICKET and run.machine.is_premium() and not premium:
				premium = true
				var chute: int = MachineSteps.first_lit(run, RewardMachine.Chute.UPGRADE)
				assert_bool(first._machine._choose(chute)).is_true()
				first._machine.view.fast_forward()
				assert_int(run.phase).is_equal(RunState.Phase.MACHINE_PICK)
				var resumed: ShiftScreen = await _screen()
				var view: RewardMachineView = resumed._machine.view
				assert_int(view.plan.kind).is_equal(MachineVisit.Kind.TICKET)
				assert_bool(view.plan.premium).is_true()
				await _assert_resumed_at(view, view.plan.pick_at)
				for key: ChuteKey in view.keys:
					assert_bool(key.gold).is_true()
			_end_visit(first)
		if bonus and premium:
			break
	assert_bool(bonus).override_failure_message("no bonus visit").is_true()
	assert_bool(premium).override_failure_message("no PREMIUM visit").is_true()


## A tap during the landing (here the prize's flight) fast-forwards it to END and, the visit
## being logged at its pick, is logged as machine_landing_skipped; the visit itself was not
## skipped. The landing (cart counts) reaches the parts while it plays.
func test_a_tap_during_the_landing_is_logged() -> void:
	var screen: ShiftScreen = await _passed_screen()
	var view: RewardMachineView = screen._machine.view
	view.fast_forward()
	await _frames(2)
	assert_bool(screen._machine._choose(RewardMachine.Chute.NEW_ITEMS)).is_true()
	view.fast_forward()
	await _until(func() -> bool: return view.is_armed(), 5000)
	view.pick(0)
	screen._machine.on_deck_added()
	assert_object(view.landing).is_not_null()
	assert_int(view.landing.cart_after).is_equal(view.landing.cart_before + 1)
	var plan: MachinePlan = view.plan
	await _until(func() -> bool: return view.clock > plan.fly_out, 5000)
	assert_float(view.clock).is_less(plan.land)
	view._on_tapped(0)
	assert_int(screen.run.shift_index).is_equal(1)  # Finished: the next shift started.
	assert_object(view.landing).is_null()
	var skip: Dictionary = _last_event("machine_landing_skipped")
	assert_int(int(skip["shift"])).is_equal(1)
	assert_int(int(skip["visit_index"])).is_equal(0)
	assert_str(skip["kind"]).is_equal("ticket")
	assert_int(int(skip["at_ms"])).is_between(
		roundi(plan.fly_out * 1000.0), roundi(plan.land * 1000.0)
	)
	assert_bool(_last_event("machine_visit")["presentation_skipped"]).is_false()


## Every part is hooked to the machine (setup) and the stage layer holds the screen-level parts;
## show_at renders a time without firing beats.
func test_every_part_is_hooked_and_show_at_fires_nothing() -> void:
	var screen: ShiftScreen = await _passed_screen()
	var view: RewardMachineView = screen._machine.view
	var parts: Array[Control] = [
		view.head,
		view.slot_plate,
		view.display,
		view.cabinet,
		view.stock,
		view.tray,
		view.prize_row,
		view.receipt_feed,
		view.cart_drawer,
		view.flyer
	]
	for key: ChuteKey in view.keys:
		parts.append(key)
	for part: Control in parts:
		assert_object(part.get(&"view")).override_failure_message(part.name).is_same(view)
	# The feed and the drawer on the hud under the top bar; the flight and the prize row's veil
	# over everything; the tickets and KEEP ONE over that (v0.50).
	for part: Control in [view.receipt_feed, view.cart_drawer]:
		assert_object(part.get_parent()).is_same(view.feed_layer)
	assert_object(view.feed_layer.get_parent()).is_same(screen._stage)
	assert_bool(view.feed_layer.top_level).is_false()
	assert_int(view.feed_layer.get_index()).is_less(screen._stage.top_bar.get_index())
	assert_object(view.flyer.get_parent()).is_same(view.stage_layer)
	assert_bool(view.stage_layer.top_level).is_true()
	assert_object(view.prize_row.get_parent()).is_same(view.stage_layer)
	assert_object(view.prize_row.keep_label().get_parent()).is_same(view.card_layer)
	assert_bool(view.card_layer.top_level).is_true()
	assert_int(view.card_layer.get_index()).is_greater(view.stage_layer.get_index())
	assert_object(view.loyalty_card).is_same(screen._loyalty_card)
	assert_object(view.receipt).is_same(screen._receipt)
	var seen: int = _beats.size()
	view.show_at(view.plan.choose_at)
	assert_int(_beats.size()).is_equal(seen)


## show_at never passes the wait point the clock runs to: past the chute wait it holds there,
## and past END during a landing it finishes the visit (the next shift starts).
func test_show_at_holds_at_the_wait_point_and_finishes_at_end() -> void:
	var screen: ShiftScreen = await _passed_screen()
	var view: RewardMachineView = screen._machine.view
	var seen: int = _beats.size()
	view.show_at(view.plan.choose_at + 20.0)
	assert_float(view.clock).is_equal(view.plan.choose_at)
	assert_int(_beats.size()).is_equal(seen)
	await _frames(2)
	assert_bool(view.is_armed()).is_true()
	assert_bool(screen._machine._choose(RewardMachine.Chute.NEW_ITEMS)).is_true()
	view.fast_forward()
	await _frames(2)
	assert_bool(view.is_armed()).is_true()
	var finished: Array[int] = []
	view.finished.connect(func() -> void: finished.append(1))
	view.pick(0)
	screen._machine.on_deck_added()
	view.show_at(view.plan.end_at + 20.0)
	assert_array(finished).is_equal([1])
	assert_int(screen.run.shift_index).is_equal(1)
	assert_bool(screen._machine.is_open()).is_false()


## idle_time goes on while the clock holds at a wait point (the parts' effects there), and stays
## put under reduced motion.
func test_idle_time_runs_at_the_wait_points() -> void:
	var screen: ShiftScreen = await _passed_screen()
	var view: RewardMachineView = screen._machine.view
	view.fast_forward()
	await _frames(3)
	var held: float = view.clock
	var idle: float = view.idle_time
	await _frames(5)
	assert_float(view.clock).is_equal(held)
	assert_float(view.idle_time).is_greater(idle)
	view.plan.reduced_motion = true
	idle = view.idle_time
	await _frames(3)
	assert_float(view.idle_time).is_equal(idle)


func _passed_screen() -> ShiftScreen:
	var screen: ShiftScreen = await _screen()
	await _pass(screen)
	return screen


## The screen, its machine's beats recorded from before its first frame (the machine is built in
## _ready, as scene_runner adds the screen; a resumed visit opens there and runs from _process).
func _screen() -> ShiftScreen:
	var scene: PackedScene = load(SCREEN)
	var screen: ShiftScreen = auto_free(scene.instantiate())
	scene_runner(screen)
	var view: RewardMachineView = screen._machine.view
	view.beat.connect(
		func(beat_name: StringName, t0: float) -> void:
			_beats.append([beat_name, t0, view.skipping, view])
	)
	await _frames(4)
	return screen


## Ends the screen's waiting visit as the player could: a chute (NEW ITEMS, else the first lit),
## then a bin, or (no bin: STAMP DAY) the first prize; the landing fast-forwarded.
func _end_visit(screen: ShiftScreen) -> void:
	var run: RunState = screen.run
	if run.phase == RunState.Phase.MACHINE_CHOOSE:
		var chute: int = MachineSteps.first_lit(run, RewardMachine.Chute.NEW_ITEMS)
		assert_bool(screen._machine._choose(chute)).is_true()
	if run.machine.can_bin():
		screen._machine._on_binned()
	else:
		screen._machine._take(0, run.deck.cards[0] if run.deck_is_full() else null)
	screen._machine.view.fast_forward()
	screen._machine._end_return()  # The glide back after the shift's last visit (#77 v2).


## Passes the shift (`rushed`: the count-up tapped once, Rush.checkout).
func _pass(screen: ShiftScreen, rushed: bool = false) -> void:
	for id: String in PASSING_ROW:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	if rushed:
		await Rush.checkout(screen)
	else:
		await screen._on_checkout_pressed()
	assert_int(screen.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)


## A resumed visit: at `wait` on its plan (resumed, started there), armed, and no beat of its view
## but the arming fired since its screen was built.
func _assert_resumed_at(view: RewardMachineView, wait: float) -> void:
	assert_bool(view.plan.resumed).is_true()
	assert_float(view.clock).is_equal(wait)
	assert_float(view.plan.start).is_equal(wait)
	await _frames(2)
	assert_bool(view.is_armed()).is_true()
	var names: Array[StringName] = []
	for seen: Array in _beats:
		if seen[3] == view:
			names.append(seen[0])
	assert_array(names).is_equal([&"armed"])


func _names() -> Array[StringName]:
	var names: Array[StringName] = []
	for seen: Array in _beats:
		names.append(seen[0])
	return names


## Waits until `condition` holds, at most `limit_ms` (real time).
func _until(condition: Callable, limit_ms: int) -> void:
	var start: int = Time.get_ticks_msec()
	while not condition.call() and Time.get_ticks_msec() - start < limit_ms:
		await get_tree().process_frame


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


func _last_event(type: String) -> Dictionary:
	var events: Array = []
	for line: String in EventLogWriter.join_logs(_folder).split("\n", false):
		events.append(JSON.parse_string(line))
	for index: int in range(events.size() - 1, -1, -1):
		if events[index]["type"] == type:
			return events[index]
	return {}


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
