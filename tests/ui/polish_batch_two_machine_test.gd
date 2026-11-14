extends GdUnitTestSuite
## Polish audit batch 2, the machine group (2026-11-14): the RECEIPT REWARDS machine's keys (1 and
## 2 press a chute's key, Enter pushes the push bar only once a key is down, 1-3 pick a ticket,
## Esc lets a pressed key up before the pause, never an echo, Alt+Enter or a covered machine); the
## prize tip in the game's one tip style (TipCard) under its ticket, clear of every ticket; the
## odds legend's pips drawn as the tickets draw them and a 0% stand shuttered; the helper lines in
## pixel capitals inside their art; the WELCOME BACK slip clear of the marquee on a resume at the
## machine; the TOY MACHINES' Enter/Space draw and B for the FIGURINE BOOK. Saves and logs go to a
## temporary folder.

const Kit := preload("res://tests/ui/toy_test_kit.gd")
const SCREEN := "res://ui/shift_screen.tscn"
const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
## Milk, Multipack, then five Milks: passes shift 1.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]

var _folder: String = ""
var _live_machine: MachineDefinition
var _window_size: Vector2i


func before_test() -> void:
	_live_machine = NoOvertime.live_off()
	_folder = "user://test_pb2_machine_%d" % Time.get_ticks_usec()
	Kit.event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size


func after_test() -> void:
	get_tree().paused = false
	get_tree().root.size = _window_size
	NoOvertime.live_restore(_live_machine)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	Kit.remove(_folder)


## 1 and 2 press the keys (a press on the other moves it), Esc lets it up, Enter does nothing
## until a key is down (CONFIRM on PUSH), then pushes the bar once; echoes, Alt+Enter and a
## covered machine take nothing.
func test_the_number_keys_and_enter_choose_a_chute() -> void:
	var run: RunState = _passed_run(41)
	var view: RewardMachineView = await _open(run)
	view._armed = true  # Headless: no mouse release arms it.
	var confirmed: Array[int] = []
	view.chute_confirmed.connect(func(chute: int) -> void: confirmed.append(chute))
	assert_bool(view._take_key(_key(KEY_ENTER))).is_false()  # Nothing to push yet.
	assert_bool(view._take_key(_key(KEY_ESCAPE))).is_false()  # The pause's.
	assert_bool(view._take_key(_key(KEY_1))).is_true()
	assert_int(view.pressed_chute()).is_equal(RewardMachine.Chute.NEW_ITEMS)
	assert_bool(view.tray.confirm_offered()).is_true()
	assert_bool(view._take_key(_key(KEY_KP_2))).is_true()
	assert_int(view.pressed_chute()).is_equal(RewardMachine.Chute.UPGRADE)
	assert_bool(view._take_key(_key(KEY_ESCAPE))).is_true()
	assert_int(view.pressed_chute()).is_equal(-1)
	assert_bool(view.tray.confirm_offered()).is_false()
	assert_bool(view._take_key(_key(KEY_1, true))).is_false()  # An echo.
	assert_int(view.pressed_chute()).is_equal(-1)
	view._take_key(_key(KEY_1))
	var alt_enter: InputEventKey = _key(KEY_ENTER)
	alt_enter.alt_pressed = true
	assert_bool(view._take_key(alt_enter)).is_false()
	view.keys_blocked = func() -> bool: return true
	assert_bool(view._take_key(_key(KEY_ENTER))).is_false()
	view.keys_blocked = func() -> bool: return false
	assert_bool(view._take_key(_key(KEY_ENTER))).is_true()
	assert_bool(view.tray.confirm_down()).is_true()
	assert_bool(view._take_key(_key(KEY_ENTER))).is_false()  # Already down: no second push.
	await get_tree().create_timer(view.tuning.confirm_down_ms / 1000.0 + 0.05).timeout
	await _frames(2)
	assert_array(confirmed).is_equal([RewardMachine.Chute.NEW_ITEMS])
	await _close(view)


## At the pick, 1-3 pick a ticket as its click does (prize_picked), once armed; a number past the
## row does nothing.
func test_the_number_keys_pick_a_ticket() -> void:
	var run: RunState = _passed_run(42)
	var view: RewardMachineView = await _open(run)
	assert_bool(MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	view.show_draw(run)
	view.show_at(view.plan.pick_at)
	var picked: Array[int] = []
	view.prize_picked.connect(func(index: int) -> void: picked.append(index))
	view._armed = false
	assert_bool(view._take_key(_key(KEY_1))).is_false()  # Not armed yet.
	view._armed = true
	var past: Key = [KEY_1, KEY_2, KEY_3, KEY_4][view.tickets.size()] as Key
	assert_bool(view._take_key(_key(past))).is_false()
	assert_bool(view._take_key(_key(KEY_3))).is_true()
	assert_array(picked).is_equal([2])
	assert_bool(view._take_key(_key(KEY_ENTER))).is_false()
	await _close(view)


## On the real screen, resumed at the machine: Esc lets a pressed key up and the pause stays shut;
## the next Esc opens the pause. The WELCOME BACK slip sits inside the screen, clear of the
## marquee, the keys and the prize bay.
func test_a_resume_at_the_machine_keeps_the_marquee_clear_and_esc_releases_a_key() -> void:
	var first: ShiftScreen = await _screen()
	_place_ids(first, PASSING_ROW)
	first._on_checkout_pressed()
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var resumed: ShiftScreen = runner.scene()
	await _frames(4)
	assert_int(resumed.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)
	var view: RewardMachineView = resumed._machine.view
	var slip: WelcomeSlip = resumed._pause.welcome
	assert_bool(slip.visible).is_true()
	var shown: Rect2 = slip.get_global_rect()
	var screen_rect: Rect2 = resumed._stage.get_global_rect()  # The stage in the window.
	assert_bool(screen_rect.encloses(shown)).override_failure_message(str(shown)).is_true()
	for part: Control in [view.head, view.display, view.key_bay, view.tray, view.bay]:
		var covered: Rect2 = part.get_global_rect()
		(
			assert_bool(shown.intersects(covered))
			. override_failure_message("%s %s over %s" % [part.name, shown, covered])
			. is_false()
		)
	for line: MachineLine in slip.lines():
		assert_bool(shown.encloses(line.get_global_rect())).is_true()
	view._armed = true
	view.press_key(RewardMachine.Chute.NEW_ITEMS)
	runner.simulate_key_pressed(KEY_ESCAPE)
	await _frames(3)
	assert_int(view.pressed_chute()).is_equal(-1)
	assert_bool(resumed._pause.is_open()).is_false()
	runner.simulate_key_pressed(KEY_ESCAPE)
	await _frames(3)
	assert_bool(resumed._pause.is_open()).is_true()
	resumed._pause.close()


## A resumed planning keeps the slip under the top bar.
func test_a_resume_in_planning_keeps_the_slip_under_the_top_bar() -> void:
	var first: ShiftScreen = await _screen()
	first._pause.save_and_quit()
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var resumed: ShiftScreen = runner.scene()
	await _frames(2)
	assert_bool(resumed._pause.welcome.visible).is_true()
	assert_float(resumed._pause.welcome.position.y).is_equal(WelcomeSlip.TOP)


## A revealed prize's tip is the game's one tip (TipCard) under its ticket: clear of every ticket,
## inside the stage, its words its prize's (the card's rule, an upgrade's new tier, a perk's
## effect); never before the ticket lands, gone after the pick.
func test_the_prize_tip_is_a_tip_card_clear_of_the_tickets() -> void:
	var cases: Array[Array] = [
		[_passed_run(37), RewardMachine.Chute.NEW_ITEMS],
		[_passed_run(38), RewardMachine.Chute.UPGRADE],
		[_passed_run(39, _premium), RewardMachine.Chute.UPGRADE],
	]
	var stage: Rect2 = Rect2(Vector2.ZERO, ShiftStage.SIZE)
	for case: Array in cases:
		var run: RunState = case[0]
		var view: RewardMachineView = await _open(run)
		assert_bool(MachineSteps.choose(run, case[1])).is_true()
		view.show_draw(run)
		var popup: PrizePopup = view.popup
		view.show_at(view.plan.choose_at)
		assert_bool(popup.open_for(view.tickets[0])).is_false()  # Not landed yet.
		view.show_at(view.plan.pick_at)
		await _frames(1)
		var prizes: Array[MachinePrize] = run.machine.prizes()
		for index: int in range(view.tickets.size()):
			var where: String = "chute %d ticket %d" % [case[1], index]
			view._on_ticket_hovered(index)
			await _frames(1)
			assert_bool(popup.visible).override_failure_message(where).is_true()
			assert_int(popup.ticket_index).is_equal(index)
			for rect: Rect2 in popup.shown_rects():
				var said: String = "%s: %s" % [where, rect]
				assert_bool(stage.encloses(rect)).override_failure_message(said).is_true()
				for ticket: PrizeTicket in view.tickets:
					var hit: bool = rect.intersects(ticket.get_global_rect())
					assert_bool(hit).override_failure_message(said).is_false()
			var card: TipCard = popup.tip_card()
			assert_float(card.size.y).is_greater(0.0)
			match prizes[index].kind:
				MachinePrize.Kind.REGISTER:
					assert_int(card.spec.kind).is_equal(TipSpec.Kind.PERK)
					assert_str(popup.rule_text()).contains(
						TipMarkup.plain(TipMarkup.auto(prizes[index].upgrade.effect_text))
					)
				MachinePrize.Kind.UPGRADE:
					var preview: MachinePreview = run.machine.preview(run, index)
					assert_str(card.spec.title).is_equal(preview.to_cards[0].display_name)
					assert_str(popup.rule_text()).is_equal(preview.to_cards[0].rule_text)
				_:
					assert_str(card.spec.title).is_equal(prizes[index].card.display_name)
					assert_str(popup.rule_text()).is_equal(prizes[index].card.rule_text)
			view._on_ticket_unhovered(index)
			assert_bool(popup.visible).is_false()
		view._on_ticket_hovered(0)
		view.land(MachineSteps.take(run, 0))
		assert_bool(popup.visible).is_false()
		await _close(view)


## The sill's legend draws the tickets' own pips (one dot, two diamonds, three stars) left of its
## words, inside the sill; a PREMIUM visit's 0% COMMON stand is shuttered, a classic visit's
## stands are not.
func test_the_odds_legend_uses_the_ticket_pips_and_a_zero_stand_is_shut() -> void:
	for rarity: int in range(3):
		var expected: int = (rarity + 1) * 6 - 1
		assert_int(StockWindow.legend_pip_width(rarity)).is_equal(expected)
	for premium: bool in [false, true]:
		var run: RunState = _passed_run(16, _premium) if premium else _passed_run(16)
		var view: RewardMachineView = await _open(run)
		var stock: StockWindow = view.stock
		var sill: Rect2 = StockWindow.sill_rect()
		for line: MachineLine in stock._legend:
			var rect: Rect2 = Rect2(line.position, line.size)
			assert_bool(sill.encloses(rect)).override_failure_message(str(rect)).is_true()
			var pips: float = StockWindow.legend_pip_width(stock._legend.find(line)) * 2.0
			assert_float(rect.position.x - pips - StockWindow.LEGEND_PIP_GAP * 2.0).is_greater(
				sill.position.x
			)
		for chute: int in RewardMachine.CHUTES:
			if not stock.column_lit(chute):
				continue
			var texts: PackedStringArray = stock.odds_texts(chute)
			assert_bool(stock.stand_shut(chute, 0)).is_equal(texts[0] == "0%")
			if premium:
				assert_str(texts[0]).is_equal("0%")
				assert_bool(stock.stand_shut(chute, 0)).is_true()
				var stand: Rect2 = stock.stand_rect(chute, 0)
				assert_bool(Rect2(Vector2.ZERO, StockWindow.SIZE).encloses(stand)).is_true()
			for rarity: int in [1, 2]:
				assert_bool(stock.stand_shut(chute, rarity)).is_false()
		await _close(view)


## The helper lines are hard pixel capitals inside their art: the display's sub line (OR SKIP THE
## DRAW; a PREMIUM visit's PICK A CHUTE, the marquee saying RARE OR LEGENDARY), the tray's TAKE
## YOUR PRIZE and the empty bay's 3 SEALED PRIZES DROP HERE.
func test_the_machine_helper_lines_are_pixel_capitals() -> void:
	var run: RunState = _passed_run(43, _premium)
	var view: RewardMachineView = await _open(run)
	var glass: Rect2 = MachineDisplay.GLASS_RECT
	var sub: MachineLine = view.display.sub_line()
	assert_object(sub).is_not_null()
	assert_str(sub.text()).is_equal("PICK A CHUTE")
	assert_bool(view.display.labels()[0].visible).is_false()
	assert_bool(glass.encloses(Rect2(sub.position, sub.size))).is_true()
	assert_str(MachineDisplay.pixel_sub(RewardMachineView.SKIP_SUB, 312.0)).is_equal(
		"OR SKIP THE DRAW"
	)
	assert_str(MachineDisplay.pixel_sub("a very long word ".repeat(4), 312.0)).is_empty()
	var take: MachineLine = view.tray.take_line()
	assert_object(take).is_not_null()
	assert_str(take.text()).is_equal(MachineTray.TAKE_TEXT)
	var mouth: Rect2 = MachineTray.MOUTH_RECT
	assert_bool(mouth.encloses(Rect2(take.position, take.size))).is_true()
	var hint: MachineLine = view.bay.get_node("Hint") as MachineLine
	assert_bool(hint.visible).is_true()
	assert_str(hint.text()).is_equal(PrizeBay.HINT % 3)
	var bay: Rect2 = Rect2(Vector2.ZERO, PrizeBay.SIZE)
	assert_bool(bay.encloses(Rect2(hint.position, hint.size))).is_true()
	view._armed = true
	view.press_key(RewardMachine.Chute.NEW_ITEMS)
	view.show_at(view.clock)
	take = view.tray.take_line()
	assert_object(take).is_not_null()
	assert_bool(mouth.encloses(Rect2(take.position, take.size))).is_true()
	await _close(view)


## TOY MACHINES: B opens the FIGURINE BOOK, B or Esc closes it.
func test_b_opens_and_closes_the_figurine_book() -> void:
	var screen: ToyMachinesScreen = await _toys(_counter(Kit.profile(3, 3)))
	screen._unhandled_key_input(Kit.key(KEY_B))
	assert_bool(screen.book().visible).is_true()
	screen.book()._unhandled_key_input(Kit.key(KEY_B))
	assert_bool(screen.book().visible).is_false()
	screen._unhandled_key_input(Kit.key(KEY_B))
	assert_bool(screen.book().visible).is_true()
	screen.book()._unhandled_key_input(Kit.key(KEY_ESCAPE))
	assert_bool(screen.book().visible).is_false()
	await _frames(2)  # The pages it dropped are freed.


## TOY MACHINES: Enter or Space draws from the picked machine as its click does (nothing with
## none picked, no echo, no second draw or book under the reveal).
func test_the_toy_keys_draw() -> void:
	var profile: ProfileState = Kit.profile(3, 3)
	var counter: CapsuleCounter = _counter(profile)
	var screen: ToyMachinesScreen = await _toys(counter)
	screen._unhandled_key_input(Kit.key(KEY_ENTER))
	assert_int(profile.coins).is_equal(3)  # None picked.
	assert_bool(screen.reveal().visible).is_false()
	screen._unhandled_key_input(Kit.key(KEY_RIGHT))
	var echo: InputEventKey = Kit.key(KEY_SPACE)
	echo.echo = true
	screen._unhandled_key_input(echo)
	assert_int(profile.coins).is_equal(3)
	screen._unhandled_key_input(Kit.key(KEY_SPACE))
	assert_int(profile.coins).is_equal(3 - counter.price())
	assert_bool(screen.reveal().visible).is_true()
	screen._unhandled_key_input(Kit.key(KEY_ENTER))
	screen._unhandled_key_input(Kit.key(KEY_B))
	assert_int(profile.coins).is_equal(3 - counter.price())  # Under the reveal: no second draw.
	assert_bool(screen.book().visible).is_false()


func _counter(profile: ProfileState) -> CapsuleCounter:
	return CapsuleCounter.new(
		profile, SaveService.new(_folder), Kit.balance(), Kit.event_log(), false, true
	)


func _toys(counter: CapsuleCounter) -> ToyMachinesScreen:
	get_tree().root.size = Vector2i(Kit.SCREEN_RECT.size)
	var screen: ToyMachinesScreen = ToyMachinesScreen.new()
	add_child(screen)
	auto_free(screen)
	screen.open(counter, Kit.balance())
	await _frames(3)
	return screen


func _open(run: RunState) -> RewardMachineView:
	var stage: Control = auto_free(Control.new())
	stage.size = ShiftStage.SIZE
	add_child(stage)
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	add_child(view)
	view.position = ShiftStage.MACHINE_RECT.position
	var receipt: Control = Control.new()
	receipt.position = Vector2(ShiftStage.RECEIPT_X, ShiftStage.RECEIPT_TOP)
	receipt.size = Vector2(
		ShiftStage.RECEIPT_WIDTH, ShiftStage.RECEIPT_BOTTOM - ShiftStage.RECEIPT_TOP
	)
	stage.add_child(receipt)
	view.open_visit(run, receipt, stage, false)
	view.fast_forward()
	await _frames(3)
	return view


func _close(view: RewardMachineView) -> void:
	view.close()
	await _frames(2)


func _screen() -> ShiftScreen:
	var scene: PackedScene = load(SCREEN)
	var screen: ShiftScreen = auto_free(scene.instantiate())
	screen.changes_scene = false
	scene_runner(screen)
	await _frames(4)
	return screen


func _place_ids(screen: ShiftScreen, ids: Array[String]) -> void:
	for id: String in ids:
		screen._debug.add_card(id)
		var card: CardInstance = screen.run.hand()[-1]
		for child: Node in screen._hand_box.get_children():
			var view: CardView = child as CardView
			if view != null and view.card == card and not view.is_queued_for_deletion():
				screen._on_hand_card_clicked(view)
		var click: InputEventMouseButton = Kit.left_click()
		screen._on_slot_input(click, screen.run.row.size())


static func _passed_run(seed_value: int, prepare: Callable = Callable()) -> RunState:
	var balance: BalanceDefinition = load(BALANCE)
	var deck: DeckDefinition = load(STARTER)
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(balance))
	if prepare.is_valid():
		prepare.call(run)
	run.start_shift()
	for id: String in PASSING_ROW:
		run.place(run.debug_add_to_hand(load("res://data/cards/%s.tres" % id)), run.row.size())
	run.checkout()
	return run


static func _premium(run: RunState) -> void:
	MachineSteps.premium_run(run, [1] as Array[int])


static func _key(keycode: Key, echo: bool = false) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	event.echo = echo
	return event


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame
