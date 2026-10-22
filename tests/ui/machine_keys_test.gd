extends GdUnitTestSuite
## The RECEIPT REWARDS machine's cabinet half (#77, look F; build spec 4.2-4.3, U1): the head's
## stamps, the receipt slot, the display, the chute keys, the REGULAR punch meters and the odds
## card, each shown from the visit's plan at a time `t` (frame(t), view.show_at). The head's BONUS
## and STAMP DAY stamps blink in and land, then lift after the landing; the slot's scan bar blinks
## while it reads and its lamp lights at the feed's end; the keys light in turn (a BONUS visit's
## relight faster) and say why a chute is shut in words; the display plays the visit's lines
## between the wait points' messages; a rising meter keeps its old level until its punch opens
## the hole, with the jaw, the chad and the +1 tab; the odds card pops in on a hovered lit key,
## three rows above it, its tail at the key (#77 machine v2); a pressed key drops with its LED lit
## and the display's CONFIRM ›; a BONUS visit says INSPECTION PASSED. Reduced motion keeps every
## state without the motion. Layout asserts on-screen geometry on a 1280x720 stage (memory: UI
## tests check layout). The views are driven directly (no screen, no input events).

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
## passed; it lifts 0.6 s after the punch's end, STAMP DAY's 0.6 s
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
	view.plan.set_landing(MachinePlan.Landing.NEW_CARD, 1, true, MachinePlan.NO_VISIT)
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
	view.plan.set_landing(MachinePlan.Landing.REGISTER, 1, false, MachinePlan.NO_VISIT)
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
## is never lit, sits sunk and says why in words; the chosen key sinks while the odds card closes
## and a hovered lit key lifts while the chutes wait (neither under reduced motion).
func test_keys_light_in_turn_and_relight_on_a_bonus() -> void:
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	var keys: Array[ChuteKey] = view.keys
	for chute: int in range(3):
		keys[chute].show_state(RewardMachine.ChuteState.OPEN, 0, true)
	keys[3].show_state(RewardMachine.ChuteState.LOCKED_SHIFT, 3, true)
	assert_bool(keys[3].has_padlock()).is_true()
	assert_str(keys[3].sub_text()).is_equal("OPENS AFTER SHIFT 3")
	assert_str(keys[3].shown_labels()[1].text).is_equal("OPENS AFTER\nSHIFT 3")
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
		_frame_keys(keys, view.plan.lights + EPSILON)
		assert_array(_lit(keys)).is_equal([true, false, false, false])
		_frame_keys(keys, view.plan.lights + stagger + EPSILON)
		assert_array(_lit(keys)).is_equal([true, true, false, false])
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


## CARD FULL shows the card's stamps and no padlock; NOTHING TO IMPROVE has a padlock; the STAMP
## DAY tab shows on request. Every key's lines fit their boxes, in every state.
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
	register.set_tab(true)
	assert_bool(register.has_tab()).is_true()
	assert_str(register.tab().text).is_equal("SEE ODDS")
	for state: int in [
		RewardMachine.ChuteState.OPEN,
		RewardMachine.ChuteState.LOCKED_SHIFT,
		RewardMachine.ChuteState.CARD_FULL,
		RewardMachine.ChuteState.EMPTY,
	]:
		for key: ChuteKey in view.keys:
			key.show_state(state, 7, true)
			for label: Label in key.shown_labels():
				_assert_fits(label)
	_assert_fits(register.tab())
	await _frames(2)  # Let the parts' queued frees run (no orphans).


## The display's lines over a NEW ITEMS visit: READING…, the read (spend, quota), the spend and
## "pick a chute" at the wait; PACKING YOUR ORDER…, the prizes out (in Pixelify), each reveal's
## rarity and prize, the pick prompt with BIN IT (shown from the last reveal's end, as look F);
## ENJOY!, the landing's word with the cart count, the REGULAR level and SEE YOU NEXT SHIFT; BIN
## IT hides once the pick is made.
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
	view.show_at(plan.choose_at + EPSILON)
	assert_str(display.texts()[0]).is_equal("PACKING YOUR ORDER…")
	assert_bool(display.bin_button().visible).is_false()
	view.show_at(plan.reveal_at[0] - EPSILON)
	assert_str(display.texts()[0]).is_equal("%d PRIZES FROM NEW ITEMS" % plan.n_prizes)
	assert_bool(display.message_in_display_font()).is_true()
	assert_bool(display.bin_button().visible).is_false()
	var last: int = plan.n_prizes - 1
	view.show_at(plan.reveal_at[last])
	assert_bool(display.bin_button().visible).is_false()
	view.show_at(plan.reveal_at[last] + EPSILON)
	var prize: MachinePrize = run.machine.prizes()[last]
	assert_array(Array(display.texts())).is_equal(
		[MachineDisplay.RARITY_WORDS[prize.rarity], prize.card.display_name]
	)
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
	assert_str(display.texts()[0]).is_equal(
		"NEW ITEMS REGULAR 1/%d" % run.machine.machine.max_level()
	)
	assert_str(display.texts()[1]).starts_with("next visit here")
	view.show_at(plan.end_at - EPSILON)
	assert_str(display.texts()[0]).is_equal("SEE YOU NEXT SHIFT")


## A bin: BINNED ✕ until its punch, then the REGULAR level (bins raise it too).
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
	assert_str(view.display.texts()[0]).is_equal("COUPONS REGULAR 1/3")


## A real BONUS visit (inspected, and a bonus extra shift; #77 machine v2's B4): the head's
## BONUS TICKET! over INSPECTION PASSED (or "shift 1"), the display's BONUS TICKET with the ticket
## icon and "inspection passed · feeding in" until the stub is fed, then "… · 1 more prize · pick a
## chute" at the wait; the slip's BONUS #1b with the red INSPECTION PASSED ✓ over the inspection's
## name (BONUS TICKET ✓ over "shift 1"), its lines inside the slip; a pressed key's title sub
## says "bonus ticket".
func test_a_bonus_visit_says_its_inspection_passed() -> void:
	var spot: String = (load(SPOT_CHECK) as InspectionDefinition).display_name
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
		var slip: Array = Array(view.slip.texts())
		assert_str(slip[0]).contains("#1b")
		var check: String = (
			RewardMachineView.BONUS_CHECK if inspected else RewardMachineView.EXTRA_CHECK
		)
		assert_str(slip[1]).is_equal(check)
		assert_str(view.slip.why_text()).is_equal(spot if inspected else "shift 1")
		var paper: Rect2 = view.slip.get_global_rect()
		for label: Label in view.slip.check_labels():
			if label.visible:
				assert_bool(paper.encloses(label.get_global_rect())).is_true()
				_assert_fits(label)
		view._armed = true  # Headless: no mouse release arms it.
		view.press_key(RewardMachine.Chute.NEW_ITEMS)
		assert_array(Array(view.display.texts())).is_equal(
			["NEW ITEMS", "add to cart · bonus ticket · 3 prizes, keep 1"]
		)
		view.close()
		remove_child(view)
	await _frames(2)  # Let the parts' queued frees run (no orphans).


## STAMP DAY: its single-line head stamp, its free-stamp lines, "PICK 1 STAMP" at the pick; the
## REGISTER key's SEE ODDS shows, on hover, the card the draw came from (it goes with the pointer,
## and the landing closes it).
func test_stamp_day_shows_its_register_odds_read_only() -> void:
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
	var register: int = RewardMachine.Chute.REGISTER
	assert_bool(view.keys[register].has_tab()).is_true()
	view._armed = true  # Headless: no mouse release arms it.
	view.hover_key(RewardMachine.Chute.NEW_ITEMS)
	assert_bool(view.odds_card.visible).is_false()  # Only REGISTER's, at a STAMP DAY pick.
	view.hover_key(register)
	assert_bool(view.odds_card.visible).is_true()
	assert_int(view.odds_card.chute).is_equal(register)
	assert_int(view.odds_card.row_texts().size()).is_equal(3)
	view.press_key(register)  # Read-only: no key is pressed at a pick.
	assert_int(view.pressed_chute()).is_equal(-1)
	view._on_key_unhovered(register)
	assert_bool(view.odds_card.visible).is_false()
	view.hover_key(register)
	view.land(MachineSteps.take(run, 0))
	view.show_at(view.clock)
	assert_bool(view.odds_card.visible).is_false()
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
	assert_array(Array(view.display.texts())).is_equal(["UPGRADES", "OPENS AFTER SHIFT 3"])
	assert_array(Array(view.display.rest_texts())).is_equal(rest)
	view.show_at(view.clock)
	assert_str(view.display.texts()[0]).is_equal("UPGRADES")
	view.display._denied_at_ms -= MachineDisplay.DENIED_MS + 1
	view.show_at(view.clock)
	assert_array(Array(view.display.texts())).is_equal(rest)


## The odds card (#77 machine v2's B2): whole percents ("<1%" for a share that rounds to 0); on
## hover of a lit key at the chute wait, exactly three rows (COMMON grey, RARE! teal, LEGENDARY!!
## gold) reading the odds' rarity_share, a 0% row faded; above the key, its tail down at the key's
## centre, inside the machine, over every part; it pops in (reduced motion: at once). A shut key,
## the pressed key and the draw show none.
func test_the_odds_card_shows_three_rows_above_its_key() -> void:
	assert_str(OddsCard.whole_pct(1.0 / 3.0)).is_equal("33%")
	assert_str(OddsCard.whole_pct(0.4)).is_equal("40%")
	assert_str(OddsCard.whole_pct(0.004)).is_equal("<1%")
	assert_str(OddsCard.whole_pct(0.0)).is_equal("0%")
	for rm: bool in [false, true]:
		var run: RunState = _passed_run(29)
		var view: RewardMachineView = auto_free(RewardMachineView.new())
		view.reduced_motion = func() -> bool: return rm
		add_child(view)
		view.position = ShiftStage.MACHINE_RECT.position
		view.open_visit(run, null, null, false)
		view.fast_forward()
		view._armed = true  # Headless: no mouse release arms it.
		await _frames(2)
		var machine: Rect2 = view.get_global_rect()
		var card: OddsCard = view.odds_card
		assert_int(card.z_index).is_equal(OddsCard.Z)
		view.hover_key(RewardMachine.Chute.UPGRADES)  # Shut until shift 3.
		assert_bool(card.visible).is_false()
		for chute: int in [
			RewardMachine.Chute.NEW_ITEMS, RewardMachine.Chute.COUPONS, RewardMachine.Chute.REGISTER
		]:
			view.hover_key(chute)
			assert_bool(card.visible).is_true()
			assert_float(card.scale.x).is_equal_approx(1.0 if rm else OddsCard.POP_FROM, EPSILON)
			view.idle_time += 1.0
			card.frame(view.clock)
			assert_float(card.scale.x).is_equal(1.0)
			var shares: PackedFloat64Array = run.machine.chute_info(run, chute).odds.rarity_share
			var rows: Array[PackedStringArray] = card.row_texts()
			assert_int(rows.size()).is_equal(3)
			for rarity: int in range(3):
				assert_str(rows[rarity][0]).is_equal(OddsCard.RARITY_WORDS[rarity])
				assert_str(rows[rarity][1]).is_equal(OddsCard.whole_pct(shares[rarity]))
				assert_object(card.row_colour(rarity)).is_equal(OddsCard.ROW_COLOURS[rarity])
				var alpha: float = OddsCard.ZERO_ALPHA if shares[rarity] == 0.0 else 1.0
				assert_float(card.row_alpha(rarity)).is_equal_approx(alpha, EPSILON)
			var rect: Rect2 = card.get_global_rect()
			var key: Rect2 = view.keys[chute].get_global_rect()
			assert_float(rect.end.y + OddsCard.TAIL_LENGTH).is_less_equal(key.position.y)
			assert_float(rect.position.x).is_greater_equal(machine.position.x + OddsCard.MARGIN)
			assert_float(rect.end.x).is_less_equal(machine.end.x - OddsCard.MARGIN)
			var tip: Vector2 = card.global_position + card.tail_tip()
			assert_float(tip.x).is_equal_approx(key.get_center().x, 1.0)
			assert_float(tip.y).is_between(key.position.y - OddsCard.KEY_GAP - 1.0, key.position.y)
			for row: Panel in card.rows():
				assert_bool(rect.encloses(row.get_global_rect())).is_true()
			for label: Label in card.shown_labels():
				_assert_fits(label)
			view._on_key_unhovered(chute)
			assert_bool(card.visible).is_false()
		# The pressed key shows none; another lit key does.
		view.press_key(RewardMachine.Chute.NEW_ITEMS)
		view.hover_key(RewardMachine.Chute.NEW_ITEMS)
		assert_bool(card.visible).is_false()
		view.hover_key(RewardMachine.Chute.COUPONS)
		assert_bool(card.visible).is_true()
		# The draw: none.
		assert_bool(run.machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
		view.show_draw(run)
		view.show_at(view.plan.choose_at + EPSILON)
		assert_bool(card.visible).is_false()
		view.hover_key(RewardMachine.Chute.COUPONS)
		assert_bool(card.visible).is_false()
		view.close()
		remove_child(view)
	await _frames(2)


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
	var run: RunState = _passed_run(29, _at_level_three_with_a_full_cart)
	var view: RewardMachineView = auto_free(RewardMachineView.new())
	view.open_visit(run, null, null, false)
	assert_bool(run.machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
	view.show_draw(run)
	view.show_at(view.plan.pick_at)
	assert_str(view.display.texts()[1]).is_equal(OddsCard.CART_FULL_TEXT)
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
	for label: Label in view.odds_card.shown_labels():
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
	display.set_bin(true, false)
	for line: Array in [
		["PICK 1", "or bin them all"],
		["PICK 1 · ONLY 2 IN STOCK", OddsCard.CART_FULL_TEXT],
		["PACKING YOUR ORDER…", "bonus ticket"],
		["SPEND €999 ✓ THANK YOU!", "quota €999 met · Coupon slot closed passed"],
		["UPGRADES REGULAR 3/3", "next visit here: 100% / 100% / 100%"],
	]:
		display.show_message(line[0], line[1])
		for label: Label in display.labels():
			_assert_fits(label)
	display.show_message("PICK 1", "")
	assert_bool(display.message_in_display_font()).is_true()
	display.set_bin(false, false)
	display.show_message("PICK 1 STAMP", "")
	assert_bool(display.message_in_display_font()).is_true()


## A rising meter keeps its level until its punch opens the hole: the jaw and the chad around the
## punch, the +1 tab above; the other meters stay. Reduced motion: the hole opens at the punch.
func test_the_meter_punches_when_its_meter_rises() -> void:
	for rm: bool in [false, true]:
		var run: RunState = _passed_run(25)
		var view: RewardMachineView = auto_free(RewardMachineView.new())
		view.reduced_motion = func() -> bool: return rm
		view.open_visit(run, null, null, false)
		assert_bool(run.machine.choose(run, RewardMachine.Chute.NEW_ITEMS)).is_true()
		view.show_draw(run)
		view.land(MachineSteps.take(run, 0))
		var plan: MachinePlan = view.plan
		assert_bool(plan.rises).is_true()
		var meter: PunchMeter = view.meters[RewardMachine.Chute.NEW_ITEMS]
		view.show_at(plan.punch - EPSILON)
		assert_int(meter.shown_level()).is_equal(0)
		assert_bool(meter.is_punching()).is_false()
		if not rm:
			var length: float = MachineTuning.sec(view.tuning.punch_length_ms)
			view.show_at(plan.punch + 0.45 * PunchMeter.JAW_SPAN * length)
			assert_float(meter._jaw_at.y).is_equal(PunchMeter.BORDER + PunchMeter.JAW_DOWN)
		view.show_at(plan.punch + 0.05)
		assert_bool(meter.is_punching()).is_equal(not rm)
		assert_bool(meter.plus_shown()).is_equal(not rm)
		assert_int(meter.shown_level()).is_equal(1 if rm else 0)
		view.show_at(plan.punch_end)
		assert_int(meter.shown_level()).is_equal(1)
		assert_str(meter.text()).is_equal("REGULAR 1/3")
		view.show_at(plan.end_at - EPSILON)
		assert_bool(meter.is_punching()).is_false()
		assert_bool(meter.plus_shown()).is_false()
		for chute: int in [RewardMachine.Chute.COUPONS, RewardMachine.Chute.REGISTER]:
			assert_int(view.meters[chute].shown_level()).is_equal(0)


## On the stage: the head, slot, display, keys (with the STAMP DAY tab) and meters sit in the
## cabinet without overlapping (the odds card: test_the_odds_card_shows_three_rows_above_its_key).
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
		var on_stage: Rect2 = Rect2(Vector2.ZERO, ShiftStage.SIZE)
		var head: Rect2 = view.head.get_global_rect()
		assert_vector(head.position).is_equal(machine.position + Vector2(-10, -8))
		assert_bool(on_stage.encloses(head)).is_true()
		var display: Rect2 = view.display.get_global_rect()
		var parts: Array[Control] = [view.slot_plate, view.display]
		parts.append_array(view.keys)
		parts.append_array(view.meters)
		for part: Control in parts:
			(
				assert_bool(machine.encloses(part.get_global_rect()))
				. override_failure_message(str(part.name))
				. is_true()
			)
		assert_bool(view.slot_plate.get_global_rect().intersects(display)).is_false()
		for index: int in range(view.keys.size()):
			var key: Rect2 = view.keys[index].get_global_rect()
			var with_shadow: Rect2 = key.grow_side(SIDE_BOTTOM, ChuteKey.SHADOW)
			assert_bool(with_shadow.intersects(display)).is_false()
			assert_bool(with_shadow.intersects(view.meters[index].get_global_rect())).is_false()
			if index > 0:
				assert_bool(key.intersects(view.keys[index - 1].get_global_rect())).is_false()
		var register: ChuteKey = view.keys[RewardMachine.Chute.REGISTER]
		register.set_tab(true)
		var tab: Rect2 = register.tab().get_global_rect()
		assert_float(tab.position.y).is_greater_equal(display.end.y)
		assert_bool(machine.encloses(tab)).is_true()
		var upgrades: ChuteKey = view.keys[RewardMachine.Chute.UPGRADES]
		assert_bool(upgrades.has_padlock()).is_true()
		assert_str(upgrades.sub_text()).is_equal("OPENS AFTER SHIFT 3")
		var mouth: Rect2 = view.slot_plate.mouth_global_rect()
		assert_bool(machine.encloses(mouth)).is_true()
		assert_bool(machine.encloses(view.slot_plate.dock_global_rect())).is_true()
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
	var run: RunState = RunState.new(seed_value, deck, balance, RunStock.starting(deck, balance))
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


## NEW ITEMS at REGULAR 3 and the cart at the deck limit.
static func _at_level_three_with_a_full_cart(run: RunState) -> void:
	run.machine.levels[RewardMachine.Chute.NEW_ITEMS] = 3
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
