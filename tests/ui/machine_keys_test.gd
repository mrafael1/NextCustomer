extends GdUnitTestSuite
## The RECEIPT REWARDS machine's cabinet half (#77, look F; build spec 4.2-4.3, U1; v0.50 front-on
## redraw, mock-up premium_machine_v1.html): the head, the receipt slot, the display, the chute
## keys and the stock window, each shown from the visit's plan at a time `t` (frame(t),
## view.show_at). The head's BONUS and STAMP DAY stamps blink in and land, then lift after the
## landing; the slot's scan bar blinks while it reads and its lamp lights at the feed's end; the
## keys light in turn (a BONUS visit's relight faster) and say why a chute is shut in words (a
## PREMIUM visit stands LOYALTY and UPGRADES in the key bay, a Normal one NEW ITEMS and COUPONS);
## the display plays the visit's lines between the wait points' messages; the stock window shows
## sealed tickets over each lit chute's odds; a pressed key drops with its LED lit and the
## display's CONFIRM ›; a BONUS visit says INSPECTION PASSED; a BOOSTED visit turns the machine
## PREMIUM. Reduced motion keeps every state without the motion. Layout asserts on-screen geometry
## on a 1280x720 stage (memory: UI tests check layout). The views are driven directly (no screen,
## no input events).

const BALANCE := "res://data/balance/balance.tres"
const STARTER := "res://data/decks/starter.tres"
const SPOT_CHECK := "res://data/inspections/spot_check.tres"
## Milk, Multipack, then five Milks (109): passes shift 1.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
const EPSILON := 0.001

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_machine_keys_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## BONUS TICKET! blinks in once the ticket reaches the slot (machine v2), landing from 2.2x on a
## back ease, and covers the title (between the blinks too); at rest it carries the inspection
## passed; it lifts 0.6 s after the landing's settle (`punch_end`), STAMP DAY's 0.6 s
## after its landing. Reduced motion: at rest at once.
func test_the_head_stamps_land_and_lift() -> void:
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	var head: MachineHead = view.head
	head.set_stamp("BONUS TICKET!", "Spot check passed")
	view.plan = MachinePlan.new(view.tuning, MachineVisit.Kind.BONUS, false)
	head.frame(0.0)
	assert_bool(head.stamp_shown()).is_false()  # Machine v2: it waits for the ticket at the slot.
	var at: float = view.plan.fly_end
	assert_float(at).is_greater(0.0)
	head.frame(at)
	assert_bool(head.stamp_shown()).is_true()
	assert_float(head.stamp_scale()).is_equal_approx(MachineHead.BONUS_STAMP_FROM, EPSILON)
	head.frame(at + 0.15)
	assert_bool(head.stamp_shown()).is_false()  # Blinking in.
	for label: Label in head.title_labels():
		assert_bool(label.visible).is_false()  # No title between the blinks.
	head.frame(at + MachineTuning.sec(view.tuning.bonus_stamp_land_ms) + 0.01)
	assert_bool(head.stamp_shown()).is_true()
	assert_float(head.stamp_scale()).is_equal(1.0)
	for label: Label in head.title_labels():
		assert_bool(label.visible).is_false()
	assert_array(Array(head.stamp_texts())).is_equal(["BONUS TICKET!", "Spot check passed"])
	view.plan.set_draw([0, 0, 1] as Array[int])
	view.plan.set_landing(MachinePlan.Landing.NEW_CARD, 1, MachinePlan.NO_VISIT)
	assert_int(view.tuning.head_stamp_lift_ms).is_equal(600)
	var lift: float = MachineTuning.sec(view.tuning.head_stamp_lift_ms)
	assert_float(MachineHead.lift_time(view.plan)).is_equal_approx(
		view.plan.punch_end + lift, EPSILON
	)
	head.frame(view.plan.punch_end + lift - 0.1)
	assert_bool(head.stamp_shown()).is_true()
	head.frame(view.plan.punch_end + lift + 0.1)
	assert_bool(head.stamp_shown()).is_false()
	assert_bool(head.title_labels()[0].visible).is_true()
	# STAMP DAY's lifts after its landing.
	view.plan = MachinePlan.new(view.tuning, MachineVisit.Kind.STAMP_DAY, false)
	view.plan.set_draw([0, 1, 2] as Array[int])
	view.plan.set_landing(MachinePlan.Landing.REGISTER, 1, MachinePlan.NO_VISIT)
	head.set_stamp("STAMP DAY!", "")
	head.frame(view.plan.land + lift - 0.1)
	assert_bool(head.stamp_shown()).is_true()
	head.frame(view.plan.land + lift + 0.1)
	assert_bool(head.stamp_shown()).is_false()
	assert_bool(head.title_labels()[0].visible).is_true()
	# Reduced motion: no blink, no scale.
	view.plan = MachinePlan.new(view.tuning, MachineVisit.Kind.STAMP_DAY, true)
	head.set_stamp("STAMP DAY!", "")
	head.frame(0.15)
	assert_bool(head.stamp_shown()).is_true()
	assert_float(head.stamp_scale()).is_equal(1.0)
	head.set_stamp("", "")
	head.frame(0.5)
	assert_bool(head.stamp_shown()).is_false()
	assert_bool(head.title_labels()[0].visible).is_true()


## The scan bar shows from the paper's arrival to the read's end, blinking (steady under reduced
## motion); the lamp lights at the feed's end.
func test_the_slot_reads_the_receipt() -> void:
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	var slot: SlotPlate = view.slot_plate
	for rm: bool in [false, true]:
		view.plan = MachinePlan.new(view.tuning, MachineVisit.Kind.TICKET, rm)
		var plan: MachinePlan = view.plan
		slot.frame(plan.fly_end - EPSILON)
		assert_bool(slot.scan_bar_on()).is_false()
		assert_bool(slot.lamp_on()).is_false()
		var seen: Dictionary[bool, bool] = {}
		var t: float = plan.fly_end
		while t < plan.read_end:
			slot.frame(t)
			seen[slot.scan_bar_on()] = true
			t += 0.02
		assert_bool(seen.has(true)).is_true()
		assert_bool(seen.has(false)).override_failure_message("rm %s" % rm).is_equal(not rm)
		slot.frame(plan.feed_end)
		assert_bool(slot.lamp_on()).is_true()
		slot.frame(plan.read_end)
		assert_bool(slot.scan_bar_on()).is_false()
		assert_bool(slot.lamp_on()).is_true()
	# STAMP DAY has no feed: lit from its start.
	view.plan = MachinePlan.new(view.tuning, MachineVisit.Kind.STAMP_DAY, false)
	slot.frame(0.0)
	assert_bool(slot.lamp_on()).is_true()
	assert_bool(slot.scan_bar_on()).is_false()


## The open keys light in turn (TICKET 0.14 s apart, BONUS 0.08 s, none lit before); a shut key
## is never lit, sits sunk and says why in words; the chosen key sinks while the odds close
## and a hovered lit key lifts while the chutes wait (neither under reduced motion).
func test_keys_light_in_turn_and_relight_on_a_bonus() -> void:
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	var keys: Array[ChuteKey] = view.keys
	for chute: int in range(3):
		keys[chute].show_state(RewardMachine.ChuteState.OPEN, 0, true)
	keys[3].show_state(RewardMachine.ChuteState.UNLIT, 3, true)
	assert_bool(keys[3].has_padlock()).is_true()
	assert_str(keys[3].sub_text()).is_equal("PREMIUM AFTER SHIFT 3")
	assert_str(keys[3].shown_labels()[0].text).is_equal("UPGRADES\nPREMIUM AFTER SHIFT 3")
	assert_str(ChuteKey.unlit_text(RewardMachine.Chute.REGISTER, 0, false)).is_equal(
		"PREMIUM VISITS ONLY"
	)
	assert_str(ChuteKey.unlit_text(RewardMachine.Chute.COUPONS, 5, true)).is_equal(
		"NORMAL\nVISITS ONLY"
	)
	var kinds: Dictionary[int, int] = {
		MachineVisit.Kind.TICKET: view.tuning.key_stagger_ms,
		MachineVisit.Kind.BONUS: view.tuning.relight_stagger_ms,
	}
	assert_int(kinds[MachineVisit.Kind.TICKET]).is_equal(140)
	assert_int(kinds[MachineVisit.Kind.BONUS]).is_equal(80)
	for kind: int in kinds:
		view.plan = MachinePlan.new(view.tuning, kind, false)
		var stagger: float = MachineTuning.sec(kinds[kind])
		_frame_keys(keys, 0.0)
		assert_array(_lit(keys)).is_equal([false, false, false, false])
		_frame_keys(keys, view.plan.lights - EPSILON)
		assert_array(_lit(keys)).is_equal([false, false, false, false])
		# v0.50: the left keys (chutes 0 and 2) light first, the right ones a stagger later.
		_frame_keys(keys, view.plan.lights + EPSILON)
		assert_array(_lit(keys)).is_equal([true, false, true, false])
		_frame_keys(keys, view.plan.lights + stagger + EPSILON)
		assert_array(_lit(keys)).is_equal([true, true, true, false])
		_frame_keys(keys, view.plan.choose_at)
		assert_array(_lit(keys)).is_equal([true, true, true, false])
		assert_float(keys[3].face_offset()).is_equal(ChuteKey.SINK)
		assert_float(keys[0].face_offset()).is_equal(0.0)
	# Hovered while the chutes wait: lifted. Chosen (pressed): sunk through the draw, then up.
	for rm: bool in [false, true]:
		view.plan = MachinePlan.new(view.tuning, MachineVisit.Kind.TICKET, rm)
		keys[1]._on_mouse_entered()
		keys[1].frame(view.plan.choose_at)
		assert_float(keys[1].face_offset()).is_equal(0.0 if rm else -ChuteKey.LIFT)
		keys[1]._on_mouse_exited()
		view.plan.set_draw([0, 0, 1] as Array[int])
		for chute: int in range(3):
			keys[chute].show_state(RewardMachine.ChuteState.OPEN, 0, chute == 1)
		keys[1].set_pressed(true)  # Machine v2: the chosen key stays pressed through the draw.
		_frame_keys(keys, view.plan.choose_at + EPSILON)
		assert_array(_lit(keys)).is_equal([false, true, false, false])
		assert_float(keys[1].face_offset()).is_equal(ChuteKey.SINK)
		assert_float(keys[0].face_offset()).is_equal(0.0)
		_frame_keys(keys, view.plan.odds_close)
		assert_float(keys[1].face_offset()).is_equal(ChuteKey.SINK)
		keys[1].set_pressed(false)
		_frame_keys(keys, view.plan.odds_close)
		assert_float(keys[1].face_offset()).is_equal(0.0)
		for chute: int in range(3):
			keys[chute].show_state(RewardMachine.ChuteState.OPEN, 0, true)


## CARD FULL shows the card's stamps and no padlock; NOTHING TO IMPROVE has a padlock. Every key's
## lines fit their boxes, in every state.
func test_shut_keys_say_why_and_their_lines_fit() -> void:
	var run: RunState = _passed_run(21)
	for id: String in ["category_engine", "big_basket", "extra_coupon_slot"]:
		run.upgrades.append(load("res://data/upgrades/%s.tres" % id) as UpgradeDefinition)
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	view.open_visit(run, null, null, false)
	var register: ChuteKey = view.keys[RewardMachine.Chute.REGISTER]
	register.show_state(RewardMachine.ChuteState.CARD_FULL, 0, true)
	assert_bool(register.has_padlock()).is_false()
	assert_str(register.sub_text()).is_equal("CARD FULL")
	assert_bool(register.looks_lit()).is_false()
	assert_int(register.get_node("Face/CardStamps").get_child_count()).is_equal(
		mini(3, run.upgrades.size())
	)
	var upgrades: ChuteKey = view.keys[RewardMachine.Chute.UPGRADES]
	upgrades.show_state(RewardMachine.ChuteState.EMPTY, 0, true)
	assert_bool(upgrades.has_padlock()).is_true()
	assert_str(upgrades.sub_text()).is_equal("NOTHING TO IMPROVE")
	for state: int in [
		RewardMachine.ChuteState.OPEN,
		RewardMachine.ChuteState.UNLIT,
		RewardMachine.ChuteState.CARD_FULL,
		RewardMachine.ChuteState.EMPTY,
	]:
		# An UNLIT LOYALTY or UPGRADES key: "PREMIUM AFTER SHIFT n" and "PREMIUM VISITS ONLY".
		for opens_after: int in [7, 0]:
			for key: ChuteKey in view.keys:
				key.show_state(state, opens_after, true)
				for label: Label in key.shown_labels():
					_assert_fits(label)
	await _frames(2)  # Let the parts' queued frees run (no orphans).


## The display's lines over a NEW ITEMS visit: READING…, the read (spend, quota), the spend and
## "pick a chute" at the wait; PACKING… with the prizes' count (in Pixelify), each landed ticket's
## rarity and prize, the pick prompt with BIN IT (shown from the last effect's end);
## ENJOY!, the landing's word with the cart count (kept after the settle: no Regular level since
## v0.47) and SEE YOU NEXT SHIFT; BIN IT hides once the pick is made.
func test_the_display_follows_the_visit() -> void:
	var run: RunState = _passed_run(22)
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	view.open_visit(run, null, null, false)
	var display: MachineDisplay = view.display
	var plan: MachinePlan = view.plan
	view.show_at(plan.fly_end)
	assert_str(display.texts()[0]).is_equal("READING…")
	view.show_at(plan.feed_end + EPSILON)
	assert_array(Array(display.texts())).is_equal(
		["SPEND €%d ✓ THANK YOU!" % run.history[-1].total, "quota €%d met" % run.history[-1].quota]
	)
	view.show_at(plan.choose_at)
	assert_array(Array(display.texts())).is_equal(
		["SPEND €%d ✓ THANK YOU!" % run.history[-1].total, RewardMachineView.CHOOSE_SUB]
	)
	assert_bool(run.machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	view.show_draw(run)
	plan = view.plan
	# v0.50: PACKING… while the tray packs and the tickets fly out, then each landed ticket's
	# rarity and prize until its effect ends; BIN IT from the last effect's end.
	view.show_at(plan.choose_at + EPSILON)
	var from: String = "%d prizes from new items" % plan.n_prizes
	assert_array(Array(display.texts())).is_equal([MachineDisplay.PACKING, from])
	assert_bool(display.bin_button().visible).is_false()
	view.show_at(plan.reveal_at[0] - EPSILON)
	assert_array(Array(display.texts())).is_equal([MachineDisplay.PACKING, from])
	assert_bool(display.message_in_display_font()).is_true()
	assert_bool(display.bin_button().visible).is_false()
	var last: int = plan.n_prizes - 1
	view.show_at(plan.reveal_at[last] + EPSILON)
	var prize: MachinePrize = run.machine.prizes()[last]
	assert_array(Array(display.texts())).is_equal(
		[MachineDisplay.RARITY_WORDS[prize.rarity], prize.card.display_name]
	)
	assert_bool(display.bin_button().visible).is_false()
	view.show_at(plan.reveal_at[last] + plan.reveal_length[last] + EPSILON)
	assert_bool(display.bin_button().visible).is_true()
	view.show_at(plan.pick_at)
	assert_str(display.texts()[0]).is_equal(RewardMachineView.pick_prompt(plan.n_prizes, run))
	assert_bool(display.bin_button().visible).is_true()
	var landing: MachineLanding = MachineSteps.take(run, 0)
	view.land(landing)
	plan = view.plan
	assert_bool(display.bin_button().visible).is_false()
	view.show_at(plan.land - EPSILON)
	assert_str(display.texts()[0]).is_equal("ENJOY!")
	view.show_at(plan.land + EPSILON)
	assert_array(Array(display.texts())).is_equal(
		["NEW IN CART ✓", "cart %d/%d" % [run.deck.size(), run.balance.deck_limit]]
	)
	view.show_at(plan.punch + EPSILON)
	assert_array(Array(display.texts())).is_equal(
		["NEW IN CART ✓", "cart %d/%d" % [run.deck.size(), run.balance.deck_limit]]
	)
	view.show_at(plan.end_at - EPSILON)
	assert_str(display.texts()[0]).is_equal("SEE YOU NEXT SHIFT")


## A bin: BINNED ✕ through the landing (no Regular level since v0.47).
func test_the_display_shows_a_bin() -> void:
	var run: RunState = _passed_run(23)
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	view.open_visit(run, null, null, false)
	assert_bool(run.machine.choose(run, RewardMachine.Chute.COUPONS)).is_true()
	view.show_draw(run)
	assert_bool(run.machine.bin(run)).is_true()
	view.land(null)
	var plan: MachinePlan = view.plan
	view.show_at(plan.press + EPSILON)
	assert_str(view.display.texts()[0]).is_equal("BINNED ✕")
	assert_bool(view.display.bin_button().visible).is_false()
	view.show_at(plan.punch + EPSILON)
	assert_str(view.display.texts()[0]).is_equal("BINNED ✕")


## A real BONUS visit (inspected, and a bonus extra shift; #77 machine v2's B4): the head's
## BONUS TICKET! over INSPECTION PASSED (or "shift 1"), the display's BONUS TICKET with the ticket
## icon and "inspection passed · feeding in" until the stub is fed, then "… · 1 more prize · pick a
## chute" at the wait; never PREMIUM (v0.50); a pressed key's title sub says "bonus ticket".
func test_a_bonus_visit_says_its_inspection_passed() -> void:
	for inspected: bool in [true, false]:
		var run: RunState = _bonus_run(24, inspected)
		var why: String = "inspection passed" if inspected else "shift 1"
		var view: RewardMachineView = auto_free(RewardMachineView.new())
		add_child(view)
		view.open_visit(run, null, null, false)
		var plan: MachinePlan = view.plan
		assert_int(plan.kind).is_equal(MachineVisit.Kind.BONUS)
		var under: String = "INSPECTION PASSED" if inspected else "shift 1"
		assert_array(Array(view.head.stamp_texts())).is_equal(["BONUS TICKET!", under])
		view.show_at(0.1)
		assert_array(Array(view.display.texts())).is_equal(
			["BONUS TICKET", "%s · feeding in" % why]
		)
		var icon: TextureRect = view.display.ticket_icon()
		assert_bool(icon.visible).is_true()
		var message: Rect2 = view.display.labels()[0].get_global_rect()
		assert_float(icon.get_global_rect().end.x).is_less_equal(message.position.x)
		assert_bool(view.display.get_global_rect().encloses(icon.get_global_rect())).is_true()
		view.show_at(plan.choose_at)
		assert_array(Array(view.display.texts())).is_equal(
			[RewardMachineView.BONUS_TITLE, RewardMachineView.BONUS_SUB % why]
		)
		# A BONUS visit is never PREMIUM (v0.50): the classic face and keys.
		assert_bool(view.plan.premium).is_false()
		assert_bool(view.head.premium_face()).is_false()
		view._armed = true  # Headless: no mouse release arms it.
		view.press_key(RewardMachine.Chute.NEW_ITEMS)
		assert_array(Array(view.display.texts())).is_equal(
			["NEW ITEMS", "bonus ticket · 3 prizes, keep 1"]
		)
		view.close()
		remove_child(view)
	await _frames(2)  # Let the parts' queued frees run (no orphans).


## STAMP DAY: its single-line head stamp, its free-stamp lines, "PICK 1 STAMP" at the pick; the
## stock window lights LOYALTY's column with the odds the draw came from (v0.50).
func test_stamp_day_shows_its_loyalty_odds_read_only() -> void:
	var run: RunState = _passed_run(27, _with_stamp_day)
	assert_bool(run.machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	assert_bool(run.machine.bin(run)).is_true()
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_PICK)
	assert_int(run.machine.current_visit().kind).is_equal(MachineVisit.Kind.STAMP_DAY)
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	view.open_visit(run, null, null, false)
	assert_array(Array(view.head.stamp_texts())).is_equal(["STAMP DAY!", ""])
	view.show_at(0.5)
	assert_array(Array(view.display.texts())).is_equal(
		["STAMP DAY! A FREE STAMP", "your card is behind after shift 1"]
	)
	view.show_at(view.plan.pick_at)
	assert_str(view.display.texts()[0]).is_equal("PICK 1 STAMP")
	# v0.50: the LOYALTY pair is up and only LOYALTY's column is lit, with the odds its draw came
	# from; a key press is read-only at a pick.
	var register: int = RewardMachine.Chute.REGISTER
	assert_bool(view.stock.column_lit(register)).is_true()
	assert_bool(view.stock.column_lit(RewardMachine.Chute.NEW_ITEMS)).is_false()
	assert_int(view.stock.odds_texts(register).size()).is_equal(3)
	view._armed = true  # Headless: no mouse release arms it.
	view.press_key(register)
	assert_int(view.pressed_chute()).is_equal(-1)
	view.land(MachineSteps.take(run, 0))
	view.show_at(view.clock)
	await _frames(2)  # Let the parts' queued frees run (no orphans).


## A refused key's reason shows for a moment, then the wait point's own lines come back.
func test_a_refused_key_says_why_for_a_moment() -> void:
	var run: RunState = _passed_run(28)
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	view.open_visit(run, null, null, false)
	view.fast_forward()
	view._armed = true  # Headless: no mouse release arms it.
	var rest: Array = Array(view.display.texts())
	view.press_key(RewardMachine.Chute.UPGRADES)
	assert_int(view.pressed_chute()).is_equal(-1)
	assert_array(Array(view.display.texts())).is_equal(["UPGRADES", "PREMIUM AFTER SHIFT 3"])
	for label: Label in view.display.labels():
		_assert_fits(label)
	assert_array(Array(view.display.rest_texts())).is_equal(rest)
	view.show_at(view.clock)
	assert_str(view.display.texts()[0]).is_equal("UPGRADES")
	view.display._denied_at_ms -= MachineDisplay.DENIED_MS + 1
	view.show_at(view.clock)
	assert_array(Array(view.display.texts())).is_equal(rest)


## The stock window (v0.50, M4): no real prizes in it, only three SEALED tickets per lit chute's
## column, each over its odds (whole percents, "<1%" for a sliver: MachineChuteInfo.odds'
## rarity_share) and its rarity's word, the column right above its key; a shut chute's column is
## dark. A hovered lit key is the hovered chute; once a chute is chosen only its column stays lit.
## Every label fits and stays inside the window.
func test_the_stock_window_shows_sealed_odds_above_its_key() -> void:
	assert_str(StockWindow.percent_text(1.0 / 3.0)).is_equal("33%")
	assert_str(StockWindow.percent_text(0.4)).is_equal("40%")
	assert_str(StockWindow.percent_text(0.004)).is_equal("<1%")
	assert_str(StockWindow.percent_text(0.0)).is_equal("0%")
	# A column adds up to 100 (largest remainder), keeping "<1%" for a sliver.
	var thirds: PackedStringArray = StockWindow.percent_texts([0.335, 0.335, 0.33])
	assert_int(_percent_sum(thirds)).is_equal(100)
	assert_array(Array(StockWindow.percent_texts([0.666, 0.33, 0.004]))).is_equal(
		["67%", "33%", "<1%"]
	)
	assert_array(Array(StockWindow.percent_texts([0.7, 0.2, 0.1]))).is_equal(["70%", "20%", "10%"])
	var run: RunState = _passed_run(29)
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	add_child(view)
	view.position = ShiftStage.MACHINE_RECT.position
	view.open_visit(run, null, null, false)
	view.fast_forward()
	view._armed = true  # Headless: no mouse release arms it.
	await _frames(2)
	var window: Rect2 = view.stock.get_global_rect()
	for shut: int in RewardMachine.BOOSTED_CHUTES:  # Not up until shift 3's PREMIUM visit.
		assert_bool(view.stock.column_lit(shut)).is_false()
		assert_array(Array(view.stock.odds_texts(shut))).is_empty()
	for chute: int in RewardMachine.NORMAL_CHUTES:
		assert_bool(view.stock.column_lit(chute)).is_true()
		var shares: Array[float] = []
		shares.assign(Array(run.machine.chute_info(run, chute).odds.rarity_share))
		var texts: PackedStringArray = view.stock.odds_texts(chute)
		assert_array(Array(texts)).is_equal(Array(StockWindow.percent_texts(shares)))
		assert_int(_percent_sum(texts)).is_equal(100)
		# The column stands right above its key.
		var key: Rect2 = view.keys[chute].get_global_rect()
		var column: float = window.position.x + window.size.x / 4.0 * (2 * (chute % 2) + 1)
		assert_float(absf(column - key.get_center().x)).is_less(24.0)
		assert_float(window.end.y).is_less_equal(key.position.y)
		view.hover_key(chute)
		assert_int(view.hovered_chute()).is_equal(chute)
	for label: Label in view.stock.labels():
		if label.visible:
			assert_bool(window.encloses(label.get_global_rect())).is_true()
			_assert_fits(label)
	# The draw: only the chosen chute's column stays lit.
	assert_bool(run.machine.choose(run, RewardMachine.Chute.COUPONS)).is_true()
	view.show_draw(run)
	view.show_at(view.plan.choose_at + EPSILON)
	assert_bool(view.stock.column_lit(RewardMachine.Chute.COUPONS)).is_true()
	assert_bool(view.stock.column_lit(RewardMachine.Chute.NEW_ITEMS)).is_false()
	view.close()
	remove_child(view)
	await _frames(2)


## The stock window's shares follow the shift's odds level: the same chute's LEGENDARY share at
## the machine's top level is at least its first level's, COMMON's never more, and
## every column adds up to 100.
func test_the_stock_window_odds_rise_with_the_odds_level() -> void:
	var run: RunState = _passed_run(31)
	var machine: MachineDefinition = run.machine.machine
	var context: MachineContext = MachineContext.from_run(run, machine, true, true)
	var top: int = machine.max_level()
	assert_int(top).is_greater(0)
	for chute: int in RewardMachine.NORMAL_CHUTES:
		var shown: Array[PackedStringArray] = []
		for level: int in [0, top]:
			var window: StockWindow = auto_free(StockWindow.new())
			var infos: Array[MachineChuteInfo] = []
			for each: int in RewardMachine.CHUTES:
				var info: MachineChuteInfo = MachineChuteInfo.new()
				info.state = RewardMachine.ChuteState.OPEN
				info.odds = MachineOdds.card(each, context, level)
				infos.append(info)
			window.show_chutes(infos, -1)
			window.frame(0.0)
			var texts: PackedStringArray = window.odds_texts(chute)
			assert_int(texts.size()).is_equal(3)
			assert_int(_percent_sum(texts)).is_equal(100)
			shown.append(texts)
		var legendary: Array[int] = [_percent(shown[0][2]), _percent(shown[1][2])]
		assert_int(legendary[1]).override_failure_message(str(shown)).is_greater_equal(legendary[0])
		var common: Array[int] = [_percent(shown[0][0]), _percent(shown[1][0])]
		assert_int(common[1]).override_failure_message(str(shown)).is_less_equal(common[0])


## A pressed key (#77 machine v2's B3): it drops SINK, rings gold, lights its LED green and clicks;
## the display's title mode shows the chute's name and "<does> · 3 prizes, keep 1" left of the red
## CONFIRM › (CONFIRM_RECT inside the display, clear of the lines); a press on another key moves
## it, the same key lets it up; only CONFIRM confirms, after its confirm_down_ms down state.
func test_a_pressed_key_drops_and_confirm_confirms() -> void:
	var run: RunState = _passed_run(32)
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	add_child(view)
	view.position = ShiftStage.MACHINE_RECT.position
	view.open_visit(run, null, null, false)
	view.fast_forward()
	view._armed = true  # Headless: no mouse release arms it.
	await _frames(2)
	var confirmed: Array[int] = []
	view.chute_confirmed.connect(func(chute: int) -> void: confirmed.append(chute))
	var new_items: ChuteKey = view.keys[RewardMachine.Chute.NEW_ITEMS]
	var coupons: ChuteKey = view.keys[RewardMachine.Chute.COUPONS]
	var rest_y: float = new_items.face().global_position.y
	view.press_key(RewardMachine.Chute.NEW_ITEMS)
	view.show_at(view.clock)
	assert_bool(new_items.is_pressed()).is_true()
	assert_bool(new_items.looks_pressed()).is_true()
	assert_bool(new_items.led_lit()).is_true()
	assert_float(new_items.face().global_position.y - rest_y).is_equal_approx(ChuteKey.SINK, 0.01)
	assert_bool(new_items.get_global_rect().encloses(new_items.led_global_rect())).is_true()
	assert_bool(coupons.is_pressed() or coupons.led_lit()).is_false()
	var display: MachineDisplay = view.display
	assert_bool(display.in_title_mode()).is_true()
	assert_array(Array(display.texts())).is_equal(["NEW ITEMS", "add to cart · 3 prizes, keep 1"])
	var confirm: Rect2 = display.confirm_key().get_global_rect()
	var screen: Rect2 = display.get_global_rect()
	assert_bool(display.confirm_key().visible).is_true()
	assert_vector(confirm.position - screen.position).is_equal(MachineDisplay.CONFIRM_RECT.position)
	assert_vector(confirm.size).is_equal(MachineDisplay.CONFIRM_RECT.size)
	assert_bool(screen.encloses(confirm)).is_true()
	var caption: Label = display.confirm_key().caption_label()
	assert_bool(confirm.encloses(caption.get_global_rect())).is_true()
	_assert_fits(caption)
	for label: Label in display.labels():
		assert_bool(label.get_global_rect().intersects(confirm)).is_false()
		_assert_fits(label)
	_assert_glyphs(MachineDisplay.CONFIRM_TEXT, MachineDisplay.marked_font(0))
	# Another key moves the press; the same key lets it up.
	view.press_key(RewardMachine.Chute.COUPONS)
	assert_bool(new_items.is_pressed()).is_false()
	assert_bool(coupons.is_pressed()).is_true()
	assert_str(display.texts()[0]).is_equal("COUPONS")
	view.press_key(RewardMachine.Chute.COUPONS)
	assert_int(view.pressed_chute()).is_equal(-1)
	assert_bool(display.in_title_mode()).is_false()
	view.show_at(view.clock)
	assert_bool(display.confirm_key().visible).is_false()
	assert_array(confirmed).is_empty()
	# CONFIRM: down for confirm_down_ms, then the chute is confirmed.
	view.press_key(RewardMachine.Chute.NEW_ITEMS)
	display.press_confirm()
	assert_bool(display.confirm_down()).is_true()
	assert_bool(display.confirm_key().is_sunk()).is_true()
	assert_array(confirmed).is_empty()
	display._confirm_at_ms -= view.tuning.confirm_down_ms + 1
	view.show_at(view.clock)
	assert_array(confirmed).is_equal([RewardMachine.Chute.NEW_ITEMS])
	assert_bool(view.confirm_played).is_true()
	view.close()
	remove_child(view)
	await _frames(2)


## A full cart's pick says so in the pick's sub line.
func test_a_full_cart_pick_says_swap_one_out() -> void:
	var run: RunState = _passed_run(29, _with_a_full_cart)
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	view.open_visit(run, null, null, false)
	assert_bool(run.machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	view.show_draw(run)
	view.show_at(view.plan.pick_at)
	assert_str(view.display.texts()[1]).is_equal(RewardMachineView.CART_FULL_TEXT)
	for label: Label in view.display.labels():
		_assert_fits(label)
	await _frames(2)


## Every machine line is printed with glyphs its font has (Pixelify and Atkinson have no ✓ or ✕:
## the display falls back to JetBrains Mono for them, on desktop and the web alike); BIN IT is
## silent itself (MachineSounds plays the bin's sound).
func test_machine_lines_use_glyphs_their_fonts_have() -> void:
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	var display: MachineDisplay = view.display
	display.set_bin(true, true)
	assert_int(display.bin_button().pressed.get_connections().size()).is_equal(1)
	_assert_glyphs(display.bin_button().text, display.bin_button().get_theme_font("font"))
	for line: Array in [
		["SPEND €114 ✓ THANK YOU!", RewardMachineView.CHOOSE_SUB],
		["BINNED ✕", "no prize this time"],
		["NEW IN CART ✓", "1 swapped out · cart 15/15"],
		["UPGRADED ✓", "cart stays 15/15"],
		["STAMPED ✓", "Slot engine on your card"],
		["READING…", "quota €99 met · Spot check passed"],
		["SPEND €114 ✓ THANK YOU!", RewardMachineView.BOOSTED_SUB],
		["SPEND €114 ✓ THANK YOU!", "quota €99 met" + MachineDisplay.BOOSTED_READ],
		[RewardMachineView.BONUS_TITLE, RewardMachineView.BONUS_SUB % "inspection passed"],
		["BANANA › GOLDEN ✓", "cart stays 15/15"],
	]:
		display.show_message(line[0], line[1])
		for label: Label in display.labels():
			_assert_glyphs(label.text, label.get_theme_font("font"))
	var run: RunState = _passed_run(30)
	view.open_visit(run, null, null, false)
	view.fast_forward()
	view._armed = true  # Headless: no mouse release arms it.
	view.hover_key(RewardMachine.Chute.NEW_ITEMS)
	for label: Label in view.stock.labels():
		_assert_glyphs(label.text, label.get_theme_font("font"))
	view.press_key(RewardMachine.Chute.NEW_ITEMS)
	var confirm: RegisterKey = view.display.confirm_key()
	_assert_glyphs(MachineDisplay.CONFIRM_TEXT, MachineDisplay.marked_font(0))
	assert_bool(confirm.visible).is_true()
	for label: Label in view.display.labels():
		_assert_glyphs(label.text, label.get_theme_font("font"))
	for label: Label in view.head.title_labels():
		_assert_glyphs(label.text, label.get_theme_font("font"))


## The display's longest lines fit: Pixelify 24 when it fits beside BIN IT, else bold Atkinson.
func test_long_display_lines_fit() -> void:
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	var display: MachineDisplay = view.display
	# BIN IT shows beside the pick prompts only (from the last reveal to the pick).
	for line: Array in [
		["PICK 1", "or bin them all", true],
		["PICK 1 · ONLY 2 IN STOCK", RewardMachineView.CART_FULL_TEXT, true],
		[MachineDisplay.PACKING, "bonus ticket", false],
		["SPEND €999 ✓ THANK YOU!", "quota €999 met · Coupon slot closed passed", false],
		["SPEND €999 ✓ THANK YOU!", RewardMachineView.BOOSTED_SUB, false],
		["SPEND €999 ✓ THANK YOU!", "quota €999 met" + MachineDisplay.BOOSTED_READ, false],
	]:
		display.set_bin(line[2], false)
		display.show_message(line[0], line[1])
		for label: Label in display.labels():
			_assert_fits(label)
	display.set_bin(true, false)
	display.show_message("PICK 1", "")
	assert_bool(display.message_in_display_font()).is_true()
	display.set_bin(false, false)
	display.show_message("PICK 1 STAMP", "")
	assert_bool(display.message_in_display_font()).is_true()


## A BOOSTED visit turns the machine PREMIUM (v0.50, dressing A): the classic face until the
## receipt is read (the read says PREMIUM RECEIPT), then the transform (premium_at ..
## premium_end; the display blinks PREMIUM), after which the sign reads PREMIUM REWARDS over
## LOYALTY · UPGRADES, the gold trim, the gold stub in the slot and the gold tray show for the
## whole visit, and the LOYALTY / UPGRADES pair stands in the key bay (NEW ITEMS and COUPONS cream
## and idle until they sink, never padlocked; a press on one still says NORMAL VISITS ONLY); a
## pressed key's title says "premium"; every line fits.
## A Normal visit keeps the classic face and says when LOYALTY and UPGRADES come next.
func test_a_premium_visit_turns_the_machine_gold() -> void:
	for rm: bool in [false, true]:
		var run: RunState = _passed_run(25, _boosted_after_shift_one)
		assert_bool(run.machine.is_boosted()).is_true()
		var stage: Control = auto_free(Control.new())
		stage.size = ShiftStage.SIZE
		add_child(stage)
		var view: RewardMachineView = auto_free(RewardMachineView.new())
		view.reduced_motion = func() -> bool: return rm
		add_child(view)
		view.position = ShiftStage.MACHINE_RECT.position
		view.receipt_names = ShiftScreen._names(run.row)
		view.open_visit(run, stage, stage, false)
		await _frames(2)
		var plan: MachinePlan = view.plan
		var head: MachineHead = view.head
		assert_bool(plan.premium).is_true()
		assert_array(Array(head.stamp_texts())).is_equal(["", ""])  # No stamp: the face says it.
		view.show_at(plan.read_end - EPSILON)
		assert_str(view.display.texts()[1]).ends_with(MachineDisplay.BOOSTED_READ)
		assert_bool(head.premium_face()).is_false()
		# Before the transform the classic pair stands cream and idle (never padlocked) over its
		# stocked columns, as the mock-up's classic machine does until the keys sink.
		for chute: int in RewardMachine.NORMAL_CHUTES:
			assert_bool(view.keys[chute].visible).is_true()
			assert_bool(view.keys[chute].has_padlock()).is_false()
			assert_bool(view.keys[chute].lit).is_false()
			assert_bool(view.stock.column_lit(chute)).is_true()
		assert_float(view.cabinet.trim_shown()).is_equal(0.0)
		assert_bool(view.tray.is_gold()).is_false()
		if not rm:
			view.show_at(plan.premium_at + EPSILON)
			assert_array(["PREMIUM", ""]).contains([view.display.texts()[0]])
		view.show_at(plan.premium_end + EPSILON)
		assert_bool(head.premium_face()).is_true()
		assert_str(head.title_labels()[0].text).is_equal(MachineHead.PREMIUM_TITLE)
		assert_str(head.title_labels()[1].text).is_equal(MachineHead.PREMIUM_SUB)
		for label: Label in head.title_labels():
			_assert_fits(label)
			(
				assert_bool(Rect2(Vector2.ZERO, ShiftStage.SIZE).encloses(label.get_global_rect()))
				. is_true()
			)
		assert_float(view.cabinet.trim_shown()).is_equal(1.0)
		assert_bool(view.cabinet.night_plate()).is_true()
		assert_bool(view.slot_plate.stub_shown()).is_true()
		assert_bool(view.tray.is_gold()).is_true()
		view.show_at(plan.choose_at)
		assert_array(Array(view.display.texts())).is_equal(
			["SPEND €%d ✓ THANK YOU!" % run.history[-1].total, RewardMachineView.BOOSTED_SUB]
		)
		for label: Label in view.display.labels():
			_assert_fits(label)
		assert_array(_lit(view.keys)).is_equal([false, false, true, true])
		var bay: Rect2 = view.key_bay.get_global_rect()
		for chute: int in RewardMachine.BOOSTED_CHUTES:
			var key: ChuteKey = view.keys[chute]
			assert_bool(key.visible).is_true()
			assert_bool(bay.encloses(key.get_global_rect())).is_true()
			assert_bool(view.stock.column_lit(chute)).is_true()
		for chute: int in RewardMachine.NORMAL_CHUTES:  # Sunk out of sight, never padlocked.
			var key: ChuteKey = view.keys[chute]
			assert_bool(key.visible).is_false()
			assert_bool(key.has_padlock()).is_false()
			assert_bool(view.stock.column_lit(chute)).is_false()
		# Still PREMIUM at the end of the visit.
		assert_bool(run.machine.choose(run, RewardMachine.Chute.UPGRADES)).is_true()
		view.show_draw(run)
		view.show_at(view.plan.pick_at)
		assert_bool(head.premium_face()).is_true()
		assert_bool(view.tray.is_gold()).is_true()
		view.close()
		remove_child(view)
		remove_child(stage)
	# The title subs and a refused key on a PREMIUM visit.
	var boosted: RunState = _passed_run(25, _boosted_after_shift_one)
	var titled: RewardMachineView = auto_free(RewardMachineView.new())
	add_child(titled)
	titled.open_visit(boosted, null, null, false)
	titled.fast_forward()
	titled._armed = true  # Headless: no mouse release arms it.
	titled.press_key(RewardMachine.Chute.REGISTER)
	assert_array(Array(titled.display.texts())).is_equal(["LOYALTY", "premium · 3 prizes, keep 1"])
	titled.press_key(RewardMachine.Chute.NEW_ITEMS)  # Shut: refused.
	assert_array(Array(titled.display.texts())).is_equal(["NEW ITEMS", "NORMAL VISITS ONLY"])
	for chute: int in RewardMachine.CHUTES:
		assert_str(titled.title_sub(chute)).contains(RewardMachineView.TITLE_BOOSTED)
		titled.display.show_title(ChuteKey.NAMES[chute], titled.title_sub(chute), true)
		for label: Label in titled.display.labels():
			_assert_fits(label)
	titled.close()
	remove_child(titled)
	# A Normal visit: the classic face; LOYALTY and UPGRADES say when they come next.
	var normal: RunState = _passed_run(25)
	var normal_view: RewardMachineView = auto_free(RewardMachineView.new())
	normal_view.open_visit(normal, null, null, false)
	assert_bool(normal_view.plan.premium).is_false()
	normal_view.show_at(normal_view.plan.choose_at)
	assert_bool(normal_view.head.premium_face()).is_false()
	assert_str(normal_view.head.title_labels()[0].text).is_equal(MachineHead.TITLE)
	assert_array(_lit(normal_view.keys)).is_equal([true, true, false, false])
	for chute: int in RewardMachine.BOOSTED_CHUTES:
		var key: ChuteKey = normal_view.keys[chute]
		assert_bool(key.has_padlock()).is_true()
		assert_bool(key.visible).is_false()
		assert_str(key.sub_text()).is_equal("PREMIUM AFTER SHIFT 3")
	await _frames(2)  # Let the parts' queued frees run (no orphans).


## On the stage (v0.50, front-on): the marquee over the cabinet and on the stage; the display and
## the slot plate side by side on one strip; the stock window under them; the key bay under the
## window; the tray under the bay; the bonus dock on the kick panel: none overlapping, all inside
## the machine (the marquee may overhang it), the whole machine inside the 1280x720 view.
func test_the_cabinet_on_the_stage() -> void:
	for rm: bool in [false, true]:
		var run: RunState = _passed_run(26)
		var stage: Control = auto_free(Control.new())
		stage.size = ShiftStage.SIZE
		add_child(stage)
		var view: RewardMachineView = auto_free(RewardMachineView.new())
		view.reduced_motion = func() -> bool: return rm
		add_child(view)
		# Where the camera puts it at the machine (#77 machine v2): MACHINE_RECT at scale 1.
		view.position = ShiftStage.MACHINE_RECT.position
		view.open_visit(run, stage, stage, false)
		view.fast_forward()
		await _frames(3)
		assert_bool(view.is_armed()).is_true()
		var machine: Rect2 = view.get_global_rect()
		assert_vector(machine.position).is_equal(ShiftStage.MACHINE_RECT.position)
		var on_stage: Rect2 = Rect2(Vector2(0, ShiftStage.PANEL_TOP), ShiftStage.SIZE)
		on_stage.end = ShiftStage.SIZE
		assert_bool(on_stage.encloses(machine)).override_failure_message(str(machine)).is_true()
		var head: Rect2 = view.head.get_global_rect()
		assert_vector(head.position).is_equal(machine.position + RewardMachineView.HEAD_POSITION)
		assert_bool(on_stage.encloses(head)).is_true()
		var parts: Array[Control] = [
			view.display, view.slot_plate, view.stock, view.key_bay, view.tray
		]
		for index: int in range(parts.size()):
			var rect: Rect2 = parts[index].get_global_rect()
			(
				assert_bool(machine.encloses(rect))
				. override_failure_message(str(parts[index].name))
				. is_true()
			)
			(
				assert_bool(rect.intersects(head))
				. override_failure_message(str(parts[index].name))
				. is_false()
			)
			for other: int in range(index + 1, parts.size()):
				var tag: String = "%s / %s" % [parts[index].name, parts[other].name]
				var touching: bool = rect.intersects(parts[other].get_global_rect())
				assert_bool(touching).override_failure_message(tag).is_false()
		var bay: Rect2 = view.key_bay.get_global_rect()
		for chute: int in RewardMachine.NORMAL_CHUTES:
			assert_bool(bay.encloses(view.keys[chute].get_global_rect())).is_true()
		(
			assert_bool(view.keys[0].get_global_rect().intersects(view.keys[1].get_global_rect()))
			. is_false()
		)
		var upgrades: ChuteKey = view.keys[RewardMachine.Chute.UPGRADES]
		assert_bool(upgrades.has_padlock()).is_true()
		assert_str(upgrades.sub_text()).is_equal("PREMIUM AFTER SHIFT 3")
		var mouth: Rect2 = view.slot_plate.mouth_global_rect()
		assert_bool(machine.encloses(mouth)).is_true()
		var dock: Rect2 = view.cabinet.dock_global_rect()
		assert_bool(machine.encloses(dock)).is_true()
		assert_bool(dock.intersects(view.tray.get_global_rect())).is_false()
		view.close()
		remove_child(view)
		remove_child(stage)


func _frame_keys(keys: Array[ChuteKey], t: float) -> void:
	for key: ChuteKey in keys:
		key.frame(t)


func _lit(keys: Array[ChuteKey]) -> Array:
	return keys.map(func(key: ChuteKey) -> bool: return key.looks_lit())


## The label's text fits its box: one line within its width, or its wrapped lines within its
## height.
func _assert_fits(label: Label) -> void:
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	var failure: String = "%s: '%s' in %s" % [label.name, label.text, label.size]
	if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
		var widest: float = 0.0
		for line: String in label.text.split("\n"):
			widest = maxf(
				widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			)
		assert_float(widest).override_failure_message(failure).is_less_equal(label.size.x)
		return
	for word: String in label.text.replace(String.chr(10), " ").split(" "):
		var width: float = font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		assert_float(width).override_failure_message(failure).is_less_equal(label.size.x)
	var height: float = label.get_line_count() * font.get_height(font_size)
	assert_float(height).override_failure_message(failure).is_less_equal(label.size.y + 4.0)


## A run that passed shift 1 (`prepare`, when given, edits it first: its stock, deck, machine).
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


## A run waiting at a BONUS visit after shift 1's ticket took its first NEW ITEMS prize: earned
## by a passed Spot check (`inspected`), else by a bonus extra shift.
static func _bonus_run(seed_value: int, inspected: bool) -> RunState:
	var run: RunState = _passed_run(seed_value)
	if inspected:
		run.history[-1].inspection = load(SPOT_CHECK)
	else:
		run.machine.machine = run.machine.machine.duplicate() as MachineDefinition
		run.machine.machine.bonus_extra_shifts = PackedInt32Array([1])
	run.machine.begin_after_checkout(run)
	MachineSteps.choose(run, RewardMachine.Chute.NEW_ITEMS)
	MachineSteps.take(run, 0)
	return run


## The run's machine holds a STAMP DAY after shift 1.
static func _with_stamp_day(run: RunState) -> void:
	run.machine.machine = run.machine.machine.duplicate() as MachineDefinition
	run.machine.machine.stamp_day_shifts = PackedInt32Array([1])
	run.machine.machine.stamp_day_floor = PackedInt32Array([1])


## The run's machine makes shift 1's ticket visit BOOSTED (v0.47; the data's are 3, 5 and 7).
static func _boosted_after_shift_one(run: RunState) -> void:
	run.machine.machine = run.machine.machine.duplicate() as MachineDefinition
	run.machine.machine.boosted_shifts = PackedInt32Array([1])


## The cart at the deck limit.
static func _with_a_full_cart(run: RunState) -> void:
	var milk: CardDefinition = load("res://data/cards/milk.tres")
	while run.deck.size() < run.balance.deck_limit:
		run.deck.add_card(milk)


## Every character of `text` is in `font` (or its fallbacks).
func _assert_glyphs(text: String, font: Font) -> void:
	for index: int in range(text.length()):
		(
			assert_bool(font.has_char(text.unicode_at(index)))
			. override_failure_message("'%s' in '%s'" % [text[index], text])
			. is_true()
		)


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")


## The whole percents in `texts` added up ("<1%" counts 0).
static func _percent_sum(texts: PackedStringArray) -> int:
	var total: int = 0
	for text: String in texts:
		if not text.begins_with("<"):
			total += text.trim_suffix("%").to_int()
	return total


## A shown percent's whole number ("<1%": 0).
static func _percent(text: String) -> int:
	return 0 if text.begins_with("<") else text.trim_suffix("%").to_int()
