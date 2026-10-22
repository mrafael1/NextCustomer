extends GdUnitTestSuite
## The RECEIPT REWARDS machine's feed and landings on the real shift screen (#77, build spec
## 4.2-4.6 and section 6, U3; machine v2 spec A3-A4): the receipt's copy (a second ReceiptView;
## the stage's receipt hides, torn off) travels with the camera into the machine's slot and feeds
## in under its clip, never shown for a resumed visit, cross-faded under reduced motion; an
## inspected pass stamps INSPECTION PASSED under PAID (with `stamp_notice`) and, with its BONUS
## visit to come, prints the gold stub, which snaps off at the machine into the slot plate's dock
## as the bonus ticket and is fed in by the BONUS visit; a new card flies
## into the cart drawer (right of the receipt, under the top bar, left of the machine) whose count
## chip goes n -> n+1 at the landing; an upgrade glints its copies one after another and changes
## them in place; a register flies to its LOYALTY card box, which is stamped (the plain landing
## is off); the machine's sounds follow the plan's moments, differ per rarity and never play on a
## jump. Clicks are sent to the handlers, because headless runs don't deliver input events.

const SCREEN := "res://ui/shift_screen.tscn"
const Rush := preload("res://tests/ui/count_up_rush.gd")
const RECORDING_SFX := preload("res://tests/presentation/recording_sfx.gd")
const MAX_VISITS := 6
## Milk, Multipack, Milk x5 = 109: passes the first five quotas.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
const STAGE_RECT := Rect2(0, 0, 1280, 720)
const TOP_BAR_BOTTOM := 64.0
## The geometry's tolerance (px): rounding, the 1 px roller jitter.
const PX := 2.0

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_machine_landing_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The split: the stamps live in ReceiptStamps; PAID on a pass's margin line, INSPECTION PASSED
## naming the inspection on its own line under it (as tall as the stamp, inside the receipt), none
## without an inspection or on a miss.
func test_the_receipt_stamps_paid_and_inspection_passed() -> void:
	assert_str(ReceiptView.PAID_TEXT).is_equal(ReceiptStamps.PAID_TEXT)
	var receipt: ReceiptView = _receipt_on_screen()
	receipt.show_shift_end(60, 40, "", "Spot check")
	await _frames(3)
	var stamp: PanelContainer = _inspection_stamp(receipt)
	assert_object(stamp).is_not_null()
	var texts: PackedStringArray = _texts(stamp)
	assert_array(Array(texts)).is_equal([ReceiptStamps.INSPECTION_TEXT, "Spot check"])
	var title: Label = stamp.find_child(ReceiptStamps.TITLE_NAME, true, false) as Label
	_assert_draws_check(title.get_theme_font("font"))
	assert_float(stamp.rotation).is_equal_approx(
		deg_to_rad(ReceiptStamps.INSPECTION_TILT_DEG), 0.001
	)
	var line: Control = stamp.get_parent().get_parent() as Control
	assert_float(line.size.y).is_greater_equal(stamp.size.y)
	# PAID stays on the margin line, above the stamp's line.
	var paid: Label = _label_with(receipt, ReceiptStamps.PAID_TEXT)
	assert_object(paid).is_not_null()
	assert_float(paid.get_global_rect().get_center().y).is_less(stamp.get_global_rect().position.y)
	assert_bool(receipt.get_global_rect().grow(PX).encloses(stamp.get_global_rect())).is_true()
	receipt.clear()
	receipt.show_shift_end(60, 40)
	assert_object(_inspection_stamp(receipt)).is_null()
	receipt.clear()
	receipt.show_shift_end(30, 40, "", "Spot check")
	assert_object(_inspection_stamp(receipt)).is_null()
	await _frames(2)  # The cleared lines are freed.


## The dessert of an inspected pass: PAID, then INSPECTION PASSED with `stamp_notice`, then the
## tear.
func test_an_inspected_pass_stamps_inspection_passed_in_the_dessert() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: Sfx = RECORDING_SFX.new()
	screen.add_child(sfx)
	screen._count_up._sfx = sfx
	_place_row(screen)
	await _frames(3)
	var count_up: CountUp = screen._count_up
	count_up.music = null
	count_up.play(
		screen.run.preview(),
		screen._row_views,
		ShiftScreen._names(screen.run.row),
		40,
		CountUpContext.new(1, 0),
		[],
		PackedStringArray(),
		[],
		PackedStringArray(["Spot check"]),
		""
	)
	Rush.rush(count_up)
	await _until(func() -> bool: return not count_up._playing, 30000)
	var heard: Array[String] = []
	for entry: Dictionary in sfx.get("sounds"):
		var sound: String = String(entry["sound"])
		if floori(int(entry["usec"]) / 1000.0) > count_up.total_shown_ms:
			if not sound.begins_with("ui_"):
				heard.append(sound)
	assert_array(heard).is_equal(["total", "pass", "stamp_paid", "stamp_notice", "rip"])
	var stamp: PanelContainer = _inspection_stamp(screen._receipt)
	assert_object(stamp).is_not_null()
	assert_array(Array(_texts(stamp))).contains(["Spot check"])


## The ticket's feed (#77 machine v2): the copy holds the stage receipt's lines and the stage's
## own hides (torn off); mid-travel the copy is between the printer and the slot; at the travel's
## end it is centred on the slot mouth's live rect (it follows the camera), its foot on the
## mouth's line, narrower than the receipt (feed_fit of the mouth); while fed it is clipped at
## the line; gone after the feed. Under reduced motion it cross-fades from the printer to the slot.
func test_the_receipt_travels_into_the_slot() -> void:
	var screen: ShiftScreen = await _passed_screen()
	var view: RewardMachineView = screen._machine.view
	var feed: ReceiptFeed = view.receipt_feed
	await _frames(2)
	assert_object(feed.paper).is_not_null()
	assert_object(feed.paper.stub).is_null()
	assert_array(Array(_texts(feed.paper))).is_equal(Array(_texts(screen._receipt)))
	assert_bool(screen._receipt.visible).is_false()
	var plan: MachinePlan = view.plan
	view.show_at(0.0)
	var rest: Rect2 = _stage_rect(screen, feed.paper)
	var stage_receipt: Rect2 = _stage_rect(screen, screen._receipt)
	assert_float(rest.position.x).is_equal_approx(stage_receipt.position.x, PX)
	assert_float(rest.end.y).is_equal_approx(stage_receipt.end.y, PX)
	view.show_at(plan.fly_end)
	var rect: Rect2 = _stage_rect(screen, feed.paper)
	var mouth: Rect2 = _stage_mouth(screen, view)
	assert_float(rect.get_center().x).is_equal_approx(mouth.get_center().x, PX)
	assert_float(rect.end.y).is_equal_approx(mouth.get_center().y, PX)
	assert_float(rect.size.x).is_less(stage_receipt.size.x)
	assert_float(rect.size.x).is_equal_approx(mouth.size.x * view.tuning.feed_fit, PX)
	view.show_at(plan.fly_end / 2.0)
	var mid: Rect2 = _stage_rect(screen, feed.paper)
	assert_float(mid.position.x).is_between(rest.position.x, rect.position.x)
	assert_float(mid.position.y).is_between(rect.position.y, rest.position.y)
	view.show_at((plan.fly_end + plan.feed_end) / 2.0)
	assert_bool(feed.clip.visible).is_true()
	assert_float(feed.clip.size.y).is_equal_approx(_stage_mouth(screen, view).get_center().y, PX)
	assert_float(_stage_rect(screen, feed.paper).position.y).is_greater(rect.position.y)
	view.show_at(plan.feed_end)
	assert_bool(feed.clip.visible).is_false()
	# Reduced motion: the cross-fade switches on the camera's cut, never a full-size receipt
	# over the zoomed machine.
	plan.reduced_motion = true
	var cut: float = plan.cut_at()
	var span: float = cut - plan.fly
	assert_float(cut).is_between(plan.fly, plan.fly_end)
	view.show_at(plan.fly + span / 2.0)
	var faded: Rect2 = _stage_rect(screen, feed.paper)
	assert_vector(faded.position).is_equal_approx(rest.position, Vector2(PX, PX))
	assert_float(feed.paper.get_parent().modulate.a).is_equal_approx(0.5, 0.01)
	assert_float(plan.camera_at(plan.fly + span / 2.0)).is_equal(0.0)
	view.show_at(cut)
	faded = _stage_rect(screen, feed.paper)
	var centre_x: float = _stage_mouth(screen, view).get_center().x
	assert_float(plan.camera_at(cut)).is_equal(1.0)
	assert_float(faded.get_center().x).is_equal_approx(centre_x, PX)
	assert_float(faded.size.x).is_less(stage_receipt.size.x)
	view.show_at(cut + span / 2.0)
	assert_float(feed.paper.get_parent().modulate.a).is_equal_approx(0.5, 0.01)


## A resumed visit's receipt is already fed: no copy, the stage's own torn off.
func test_a_resumed_visit_has_no_copy_in_the_slot() -> void:
	await _passed_screen()
	var resumed: ShiftScreen = await _screen()
	var view: RewardMachineView = resumed._machine.view
	assert_bool(view.plan.resumed).is_true()
	await _frames(3)
	assert_object(view.receipt_feed.paper).is_null()
	assert_bool(view.receipt_feed.clip.visible).is_false()
	assert_bool(resumed._receipt.visible).is_false()


## A pass with no bonus ticket to come (shift 1: no inspection): no stub on either receipt, no
## dock on the slot plate, no banner.
func test_no_stub_without_a_bonus() -> void:
	var screen: ShiftScreen = await _passed_screen()
	var view: RewardMachineView = screen._machine.view
	await _frames(2)
	assert_bool(view.plan.stub).is_false()
	assert_object(screen._receipt.stub).is_null()
	assert_object(view.receipt_feed.paper.stub).is_null()
	assert_object(screen._count_up._dessert.banner).is_null()
	var plan: MachinePlan = view.plan
	for t: float in [0.0, plan.fly_end, plan.choose_at]:
		view.show_at(t)
		assert_bool(view.slot_plate.dock_state()[0]).is_false()
		assert_object(view.receipt_feed.ticket).is_null()


## A NEW ITEMS pick: the prize flies from its cell into the drawer's new slot; the drawer (right
## edge 748, under the top bar, left of the machine, inside the stage) slides in before the flight,
## its count chip reads n/<deck_limit> then n+1 at the landing with the new slot filled and NEW IN
## CART stamped, and it is gone after its slide out.
func test_a_new_card_flies_into_the_cart_drawer() -> void:
	var screen: ShiftScreen = await _passed_screen()
	var view: RewardMachineView = screen._machine.view
	var run: RunState = screen.run
	await _pick(screen, RewardMachine.Chute.NEW_ITEMS)
	var plan: MachinePlan = view.plan
	var landing: MachineLanding = view.landing
	assert_int(plan.landing).is_equal(MachinePlan.Landing.NEW_CARD)
	var drawer: CartDrawer = view.cart_drawer
	var limit: int = run.balance.deck_limit
	view.show_at(plan.drawer_in + CartDrawer.SLIDE)
	assert_bool(drawer.visible).is_true()
	var rest: Rect2 = drawer.rest_rect()
	assert_float(rest.end.x).is_equal(ShiftStage.CART_DRAWER_RIGHT)
	assert_float(rest.position.y).is_greater_equal(TOP_BAR_BOTTOM)
	assert_bool(STAGE_RECT.encloses(rest)).is_true()
	assert_bool(rest.intersects(ShiftStage.MACHINE_RECT)).is_false()
	assert_float(_stage_rect(screen, drawer).end.x).is_equal_approx(rest.end.x, PX)
	assert_str(drawer.count_label.text).is_equal("%d/%d" % [landing.cart_before, limit])
	var new_slot: Dictionary = drawer.slots[-1]
	assert_bool(bool(new_slot["new"])).is_true()
	assert_bool((new_slot["sprite"] as Control).visible).is_false()
	assert_bool(drawer.stamp_label.visible).is_false()
	# The flight: from the picked cell to the new slot, full size.
	var flyer: MachineFlyer = view.flyer
	view.show_at(plan.fly_out + 0.001)
	assert_bool(flyer.visible).is_true()
	assert_float(_centre(flyer).distance_to(flyer.start_point())).is_less(PX + 1.0)
	view.show_at(plan.land - 0.001)
	assert_float(_centre(flyer).distance_to(drawer.dest())).is_less(PX + 1.0)
	assert_vector(flyer.scale).is_equal(Vector2.ONE)
	view.show_at(plan.land)
	assert_bool(flyer.visible).is_false()
	assert_str(drawer.count_label.text).is_equal("%d/%d" % [landing.cart_after, limit])
	assert_int(landing.cart_after).is_equal(landing.cart_before + 1)
	assert_bool((new_slot["sprite"] as Control).visible).is_true()
	assert_bool(drawer.stamp_label.visible).is_true()
	assert_str(drawer.stamp_label.text).is_equal(CartDrawer.NEW_STAMP)
	_assert_draws_check(drawer.stamp_label.get_theme_font("font"))
	view.show_at(plan.land + CartDrawer.POP)  # The new slot's pop is over.
	var slot_rect: Rect2 = _stage_rect(screen, new_slot["node"] as Control)
	assert_bool(rest.grow(PX).encloses(slot_rect)).is_true()
	view.show_at(plan.drawer_out + CartDrawer.SLIDE)
	assert_bool(drawer.visible).is_false()


## An UPGRADES landing (a drawer built on its own): the upgraded copies are ringed, glint one after
## another and change in place (PLAIN -> BIG) while the others stay; the count stays; UPGRADED
## lands at the glint's end less its tail.
func test_an_upgrade_glints_its_copies_and_changes_them_in_place() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	var lookup: ContentLookup = ContentLookup.new(run.balance)
	var plain: CardDefinition = lookup.card("milk")
	var big: CardDefinition = lookup.card("milk_big")
	var copies: Array[CardInstance] = []
	for _copy: int in range(3):
		copies.append(run.deck.add_card(plain))
	var landing: MachineLanding = MachineLanding.new()
	landing.prize = MachinePrize.new(MachinePrize.Kind.UPGRADE, MachinePrize.Rarity.RARE, big)
	landing.cart_before = run.deck.size()
	landing.cart_after = run.deck.size()
	for index: int in range(2):
		landing.upgraded.append([copies[index], run.deck.upgrade(copies[index], big)])
	var view: RewardMachineView = RewardMachineView.new()
	auto_free(view)
	view.run = run
	view.plan = MachinePlan.new(view.tuning, MachineVisit.Kind.TICKET, false)
	view.plan.set_draw([MachinePrize.Rarity.RARE])
	view.plan.set_landing(MachinePlan.Landing.UPGRADE, 2, MachinePlan.NO_VISIT)
	view.landing = landing
	var plan: MachinePlan = view.plan
	var drawer: CartDrawer = view.cart_drawer
	drawer.frame(plan.land)
	var targets: Array[Dictionary] = []
	for slot: Dictionary in drawer.slots:
		if int(slot["step"]) >= 0:
			targets.append(slot)
	assert_int(targets.size()).is_equal(2)
	assert_int(drawer.slots.size()).is_greater_equal(3)
	var step: float = MachineTuning.sec(view.tuning.glint_copy_ms)
	assert_float(step).is_greater(0.0)
	assert_float(drawer.glint_progress(0, plan.land + 0.01)).is_between(0.0, 1.0)
	assert_float(drawer.glint_progress(1, plan.land + 0.01)).is_equal(-1.0)
	drawer.frame(plan.glint)
	assert_str((targets[0]["tag"] as Label).text).is_equal("BIG")
	assert_str((targets[1]["tag"] as Label).text).is_equal("PLAIN")
	drawer.frame(plan.glint + step)
	assert_str((targets[1]["tag"] as Label).text).is_equal("BIG")
	assert_str(drawer.count_label.text).is_equal(
		"%d/%d" % [landing.cart_before, run.balance.deck_limit]
	)
	assert_str(drawer.note_label.text).is_equal("same count")
	var stamp_at: float = plan.glint_end - MachineTuning.sec(view.tuning.glint_tail_ms)
	drawer.frame(stamp_at - 0.01)
	assert_bool(drawer.stamp_label.visible).is_false()
	drawer.frame(stamp_at)
	assert_bool(drawer.stamp_label.visible).is_true()
	assert_str(drawer.stamp_label.text).is_equal(CartDrawer.UP_STAMP)


## An upgrade of more copies than the drawer shows (6 Milk, a SHELF upgrade): the drawer keeps the
## copy upgraded first (the flight's target) and is at its widest, still clear of the receipt.
func test_a_wide_upgrade_keeps_its_first_copy_and_clears_the_receipt() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	var lookup: ContentLookup = ContentLookup.new(run.balance)
	var plain: CardDefinition = lookup.card("milk")
	var big: CardDefinition = lookup.card("milk_big")
	var copies: Array[CardInstance] = []
	for _copy: int in range(6):
		copies.append(run.deck.add_card(plain))
	var landing: MachineLanding = MachineLanding.new()
	landing.prize = MachinePrize.new(MachinePrize.Kind.UPGRADE, MachinePrize.Rarity.RARE, big)
	landing.cart_before = run.deck.size()
	landing.cart_after = run.deck.size()
	for copy: CardInstance in copies:
		landing.upgraded.append([copy, run.deck.upgrade(copy, big)])
	var view: RewardMachineView = RewardMachineView.new()
	auto_free(view)
	view.run = run
	view.plan = MachinePlan.new(view.tuning, MachineVisit.Kind.TICKET, false)
	view.plan.set_draw([MachinePrize.Rarity.RARE])
	view.plan.set_landing(MachinePlan.Landing.UPGRADE, copies.size(), MachinePlan.NO_VISIT)
	view.landing = landing
	var drawer: CartDrawer = view.cart_drawer
	drawer.frame(view.plan.land)
	assert_int(drawer.slots.size()).is_equal(CartDrawer.MAX_SLOTS)
	var first: int = -1
	var steps: Array[int] = []
	for index: int in range(drawer.slots.size()):
		var step: int = int(drawer.slots[index]["step"])
		steps.append(step)
		if step == 0:
			first = index
	assert_int(first).is_greater_equal(0)
	assert_array(steps).not_contains([copies.size() - 1])  # The copy upgraded last is left out.
	var slot_centre: Vector2 = (
		drawer.rest_rect().position
		+ ((drawer.slots[first]["node"] as Control).position + CartDrawer.SLOT_SIZE / 2.0)
	)
	assert_float(drawer.dest().distance_to(slot_centre)).is_less(PX)
	# Left of the machine's first prize cell at 2x (#77 machine v2: the receipt is fed by then).
	assert_float(drawer.rest_rect().position.x).is_greater_equal(ShiftStage.CART_DRAWER_LEFT)
	assert_float(drawer.rest_rect().end.x).is_less_equal(ShiftStage.MACHINE_CELL_X[0])


## A REGISTER pick flies to its LOYALTY card box, shrinking, and the box's stamp slams down at the
## landing with one `stamp_loyalty` (the plain landing is off: no second sound); no drawer.
func test_a_register_flies_to_its_loyalty_box_and_is_stamped() -> void:
	var screen: ShiftScreen = await _screen()
	MachineSteps.boost_run(screen.run, [1])  # v0.47: only a BOOSTED visit lights REGISTER.
	await _pass(screen, true)
	var view: RewardMachineView = screen._machine.view
	assert_bool(view.plain_landing).is_false()
	var sfx: Sfx = RECORDING_SFX.new()
	screen.add_child(sfx)
	view.sfx = sfx
	screen._sfx = sfx
	assert_int(MachineSteps.first_lit(screen.run, RewardMachine.Chute.REGISTER)).is_equal(
		RewardMachine.Chute.REGISTER
	)
	await _pick(screen, RewardMachine.Chute.REGISTER)
	var plan: MachinePlan = view.plan
	assert_int(plan.landing).is_equal(MachinePlan.Landing.REGISTER)
	var flyer: MachineFlyer = view.flyer
	var box_index: int = view.landing.box_index
	# The flight, before the card shows the stamp: it heads for the still empty box.
	assert_float(view.clock).is_less(plan.fly_out)
	var empty: Control = screen._loyalty_card.any_box(box_index)
	assert_object(empty).is_not_null()
	assert_object(screen._loyalty_card.box(box_index)).is_null()
	var empty_centre: Vector2 = _stage_rect(screen, empty).get_center()
	view.show_at(plan.fly_out + 0.01)
	assert_bool(flyer.visible).is_true()
	assert_float(flyer.end_point().distance_to(empty_centre)).is_less(PX)
	view.show_at(plan.land - 0.001)
	assert_float(flyer.end_point().distance_to(empty_centre)).is_less(PX)
	assert_float(_centre(flyer).distance_to(empty_centre)).is_less(PX + 1.0)
	assert_float(flyer.scale.x).is_equal_approx(MachineFlyer.LOYALTY_SCALE, 0.01)
	await _until(func() -> bool: return view.clock >= plan.land or view.plan != plan, 5000)
	await _frames(1)
	var box: Control = screen._loyalty_card.box(box_index)
	assert_object(box).is_not_null()
	assert_float(box.scale.x).is_greater(1.01)  # Slamming down.
	assert_int(sfx.call("count", "stamp_loyalty")).is_equal(1)
	assert_int(sfx.call("count", "card_place")).is_equal(0)
	assert_bool(view.cart_drawer.visible).is_false()


## The sounds follow the plan: the feed's ticks (a series of 5) and slot tick, a note per lit key;
## the confirm, PACKED, a tape rip per box and each reveal's sounds; nothing on a jump or while
## skipping.
func test_the_sounds_follow_the_plan_and_never_play_on_a_jump() -> void:
	var screen: ShiftScreen = await _passed_screen()
	var view: RewardMachineView = screen._machine.view
	await _until(func() -> bool: return view.is_armed(), 5000)
	var sfx: Sfx = RECORDING_SFX.new()
	screen.add_child(sfx)
	var screen_sfx: Sfx = view.sfx
	view.sfx = sfx
	var sounds: MachineSounds = MachineSounds.new(view)
	var plan: MachinePlan = view.plan
	_step(sounds, 0.0, plan.choose_at)
	var series: Array = sounds.cues.filter(
		func(cue: Array) -> bool: return cue[1] == MachineSounds.SERIES
	)
	assert_array(series).is_equal([[plan.fly_end, MachineSounds.SERIES, "tick", 5]])
	assert_int(sfx.call("count", "slot_tick")).is_equal(1)
	var lit: Array[int] = []
	for chute: int in RewardMachine.CHUTES:
		if screen.run.machine.chute_info(screen.run, chute).state == RewardMachine.ChuteState.OPEN:
			lit.append(MachineSounds.KEY_NOTES[chute])
	assert_array(sfx.call("note_indices")).is_equal(lit)
	# A jump plays nothing.
	sfx.call("clear")
	var jumper: MachineSounds = MachineSounds.new(view)
	jumper.frame(0.0)
	sfx.call("clear")
	jumper.frame(plan.choose_at)
	assert_array(sfx.get("sounds")).is_empty()
	# The draw.
	assert_bool(screen._machine._choose(RewardMachine.Chute.NEW_ITEMS)).is_true()
	sfx.call("clear")
	_step(sounds, plan.choose_at, plan.pick_at)
	var names: Array[String] = sfx.call("sound_names")
	assert_str(names[0]).is_equal("ui_confirm")
	assert_int(names.count("stamp_1")).is_equal(1)
	assert_int(names.count("rip")).is_equal(plan.n_prizes)
	var expected_notes: int = plan.n_prizes  # The bay picks.
	for rarity: int in plan.rarities:
		for sound: String in MachineSounds.reveal_sounds(rarity):
			if sound.begins_with("note:"):
				expected_notes += 1
	assert_int((sfx.get("notes") as Array).size()).is_equal(expected_notes)
	# A beat fired while skipping mutes the next frame, even a short step.
	var muted: MachineSounds = MachineSounds.new(view)
	muted.frame(0.0)
	muted.frame(plan.feed_end - 0.01)
	sfx.call("clear")
	view.skipping = true
	view.beat.emit(&"read", plan.feed_end)
	view.skipping = false
	muted.frame(plan.feed_end + 0.01)
	assert_array(sfx.get("sounds")).is_empty()
	view.sfx = screen_sfx


## A new visit's sounds at 0 play on its first frame: STAMP DAY's `stamp_paid`; the BONUS
## TICKET's `stamp_notice` lands with the head's stamp as the ticket reaches the slot (#77 machine
## v2), and nothing prints; a visit resumed at its pick plays neither them nor a
## press for the resume, but the player's later pick press (`ui_click`) is heard.
func test_a_new_visits_first_sounds_play_and_a_resume_keeps_the_players_press() -> void:
	var screen: ShiftScreen = await _screen()
	var sfx: Sfx = RECORDING_SFX.new()
	screen.add_child(sfx)
	var view: RewardMachineView = RewardMachineView.new()
	auto_free(view)
	view.run = screen.run
	view.sfx = sfx
	var sounds: MachineSounds = MachineSounds.new(view)
	view.plan = MachinePlan.new(view.tuning, MachineVisit.Kind.BONUS, false)
	sounds.frame(0.0)
	var names: Array[String] = sfx.call("sound_names")
	assert_int(names.count("stamp_notice")).is_equal(0)
	_step(sounds, 0.0, view.plan.fly_end + 0.01)
	names = sfx.call("sound_names")
	assert_int(names.count("stamp_notice")).is_equal(1)
	assert_int(names.count("print")).is_equal(0)
	sfx.call("clear")
	view.plan = MachinePlan.new(view.tuning, MachineVisit.Kind.STAMP_DAY, false)
	sounds.frame(0.0)
	names = sfx.call("sound_names")
	assert_int(names.count("stamp_paid")).is_equal(1)
	# Resumed at its pick: the resume is silent, the pick press after it is not.
	sfx.call("clear")
	var ticket: MachinePlan = MachinePlan.new(view.tuning, MachineVisit.Kind.TICKET, false)
	ticket.set_draw([MachinePrize.Rarity.COMMON])
	view.plan = ticket.resume_at(MachinePlan.WaitPoint.PICK)
	sounds.frame(view.plan.start)
	assert_array(sfx.get("sounds")).is_empty()
	view.plan.set_landing(MachinePlan.Landing.NEW_CARD, 0, MachinePlan.NO_VISIT)
	sounds.frame(view.plan.start)
	names = sfx.call("sound_names")
	assert_array(names).is_equal(["ui_click"])


## Every rarity's reveal sounds differ (with a note count that rises with it).
func test_every_rarity_sounds_different() -> void:
	var common: PackedStringArray = MachineSounds.reveal_sounds(MachinePrize.Rarity.COMMON)
	var rare: PackedStringArray = MachineSounds.reveal_sounds(MachinePrize.Rarity.RARE)
	var legendary: PackedStringArray = MachineSounds.reveal_sounds(MachinePrize.Rarity.LEGENDARY)
	assert_array(Array(common)).is_not_equal(Array(rare))
	assert_array(Array(rare)).is_not_equal(Array(legendary))
	assert_array(Array(common)).is_not_equal(Array(legendary))
	assert_bool(legendary.has("rattle_l")).is_true()
	assert_int(rare.size()).is_greater(1)
	assert_int(legendary.size()).is_greater(rare.size())


## An inspected pass (seed 5's shift 3) with its BONUS visit to come (#77 machine v2, Q2 = 2): the
## dessert prints the gold stub (STUB form) as the receipt's last line above the tear, the
## ticket's height, across the receipt's scroll area; at the machine the stub snaps off while the
## paper's body stays on its anchor, and the bonus ticket leaves from the stub's rect and docks in
## the slot plate's dock, whose caption then hides; the BONUS visit feeds it in, clipped at the
## slot line.
func test_the_bonus_stub_prints_on_the_receipt_and_snaps_into_the_dock() -> void:
	var screen: ShiftScreen = await _screen()
	screen.start_new_run(5)
	await _frames(2)
	var docked: bool = false
	var fed: bool = false
	var sub: String = ""
	for _shift: int in range(screen.run.shift_count() - 1):
		await _pass(screen, true)
		for _visit: int in range(MAX_VISITS):
			var run: RunState = screen.run
			if not RunState.MACHINE_PHASES.has(run.phase):
				break
			var view: RewardMachineView = screen._machine.view
			await _frames(2)
			if view.plan.kind == MachineVisit.Kind.TICKET and view.plan.stub and not docked:
				docked = true
				# One wording throughout: the dessert's stub, the fed copy's and the docked ticket.
				var inspected: bool = run.history[-1].inspection != null
				sub = BonusTicket.sub_line(inspected, run.history[-1].shift)
				assert_str(screen._receipt.stub.ticket.texts()[1]).is_equal(sub)
				_assert_stub_on_the_receipt(screen._receipt)
				assert_str(view.receipt_feed.paper.stub.ticket.texts()[1]).is_equal(sub)
				_assert_stub_snaps_into_the_dock(screen, view)
				assert_str(view.receipt_feed.ticket.texts()[1]).is_equal(sub)
			elif view.plan.kind == MachineVisit.Kind.BONUS and docked and not fed:
				fed = true
				view.show_at(0.0)
				assert_str(view.receipt_feed.ticket.texts()[1]).is_equal(sub)
				_assert_ticket_feeds_in(screen, view)
			_end_visit(screen)
		if fed:
			break
	assert_bool(docked).override_failure_message("no ticket visit with a stub").is_true()
	assert_bool(fed).override_failure_message("no bonus visit").is_true()


func _assert_stub_on_the_receipt(receipt: ReceiptView) -> void:
	var stub: ReceiptStub = receipt.stub
	assert_object(stub).is_not_null()
	assert_int(stub.ticket.form).is_equal(BonusTicket.Form.STUB)
	assert_float(stub.full_height()).is_equal(BonusTicket.SIZE.y)
	var lines: Array[Node] = stub.get_parent().get_children()
	var at: int = lines.find(stub)
	assert_int(at).is_greater(0)
	var tear: Label = lines[at + 1].get_child(0) as Label
	assert_object(tear).is_not_null()
	assert_bool(tear.text.begins_with(ReceiptView.TEAR_PATTERN)).is_true()
	assert_object(_inspection_stamp(receipt)).is_not_null()
	var paper: Rect2 = receipt.get_global_rect()
	var shown: Rect2 = stub.get_global_transform() * stub.stub_rect()
	assert_float(shown.size.y).is_equal_approx(BonusTicket.SIZE.y, PX)
	# Across the receipt's scroll area, which clips its lines.
	assert_float(shown.size.x).is_equal_approx(receipt._scroll.get_global_rect().size.x, PX)
	assert_bool(paper.grow(PX).encloses(shown)).is_true()


func _assert_stub_snaps_into_the_dock(screen: ShiftScreen, view: RewardMachineView) -> void:
	var feed: ReceiptFeed = view.receipt_feed
	var plan: MachinePlan = view.plan
	assert_object(feed.paper).is_not_null()
	assert_object(feed.paper.stub).is_not_null()
	view.show_at(plan.snap - 0.05)
	assert_bool(view.slot_plate.dock_state()[0]).is_true()
	assert_bool(view.slot_plate.dock_state()[2]).is_true()
	# The paper's body stays on its anchor while its stub snaps off.
	var snap_ms: int = view.tuning.snap_delay_ms + view.tuning.snap_ms
	var snap_end: float = plan.snap + MachineTuning.sec(snap_ms)
	var full: float = feed.full_height()
	for t: float in [plan.snap, (plan.snap + snap_end) / 2.0, snap_end]:
		view.show_at(t)
		var anchor: Vector2 = feed.paper_anchor(t)["at"]
		var top_left: Vector2 = _stage_point(screen, feed.paper.get_global_transform().origin)
		assert_vector(top_left).is_equal_approx(anchor, Vector2.ONE)
		assert_float(feed.full_height()).is_equal_approx(full, 0.5)
	assert_float(feed.paper.stub.shown_height()).is_equal(0.0)
	# The ticket leaves from the stub's rect.
	view.show_at(plan.snap)
	var stub_rect: Rect2 = feed.paper.stub.get_global_transform() * feed.paper.stub.stub_rect()
	var ticket: BonusTicket = feed.ticket
	assert_object(ticket).is_not_null()
	assert_int(ticket.form).is_equal(BonusTicket.Form.TICKET)
	var centre: Vector2 = ticket.get_global_transform() * (BonusTicket.SIZE / 2.0)
	assert_vector(centre).is_equal_approx(stub_rect.get_center(), Vector2(PX, PX))
	# ... and docks.
	var landed: float = plan.snap + MachineTuning.sec(view.tuning.dock_flight_ms)
	view.show_at(landed)
	var dock: Rect2 = view.slot_plate.dock_global_rect()
	var at: Rect2 = ticket.get_global_rect()
	assert_vector(at.position).is_equal_approx(dock.position, Vector2.ONE)
	assert_vector(at.size).is_equal_approx(dock.size, Vector2.ONE)
	view.show_at(plan.fly_end + MachineTuning.sec(view.tuning.dock_label_ms))
	assert_bool(view.slot_plate.dock_state()[1]).is_true()
	assert_bool(view.slot_plate.dock_state()[2]).is_false()
	view.show_at(plan.choose_at)
	assert_vector(ticket.get_global_rect().position).is_equal_approx(dock.position, Vector2.ONE)
	_assert_odds_card_over_the_ticket(screen, view, ticket)


## Hovering a key whose odds card reaches the docked ticket draws the card over it: the ticket on
## the hud's feed layer (no top_level layer above it), the card on the machine's top_level card
## layer, which Godot draws after every item that isn't top_level; and the travelling receipt's
## layer under the top bar.
func _assert_odds_card_over_the_ticket(
	screen: ShiftScreen, view: RewardMachineView, ticket: BonusTicket
) -> void:
	view._armed = true  # Headless: no mouse release arms it.
	var shown: int = 0
	for chute: int in RewardMachine.CHUTES:
		var info: MachineChuteInfo = screen.run.machine.chute_info(screen.run, chute)
		if info.state != RewardMachine.ChuteState.OPEN:
			continue
		view._hide_odds()
		view._on_key_hovered(chute)
		var card: OddsCard = view.odds_card
		assert_bool(card.visible).is_true()
		shown += 1
		var rect: Rect2 = card.get_global_rect()
		assert_bool(view.get_global_rect().encloses(rect)).is_true()
		if rect.intersects(ticket.get_global_rect()):
			assert_bool(_under_top_level(ticket)).is_false()
			assert_bool(view.card_layer.top_level).is_true()
	view._hide_odds()
	assert_int(view.feed_layer.get_index()).is_less(screen._stage.top_bar.get_index())
	assert_object(view.feed_layer.get_parent()).is_same(screen._stage)
	assert_int(shown).is_greater(0)


static func _under_top_level(item: CanvasItem) -> bool:
	var node: Node = item
	while node != null:
		if node is CanvasItem and (node as CanvasItem).top_level:
			return true
		node = node.get_parent()
	return false


func _assert_ticket_feeds_in(screen: ShiftScreen, view: RewardMachineView) -> void:
	var feed: ReceiptFeed = view.receipt_feed
	var plan: MachinePlan = view.plan
	view.show_at(0.0)
	var dock: Rect2 = view.slot_plate.dock_global_rect()
	assert_object(feed.ticket).is_not_null()
	assert_vector(feed.ticket.get_global_rect().position).is_equal_approx(
		dock.position, Vector2.ONE
	)
	view.show_at((plan.fly_end + plan.feed_end) / 2.0)
	var line: float = _stage_mouth(screen, view).get_center().y
	assert_float(feed.ticket_clip.size.y).is_equal_approx(line, PX)
	var at: Rect2 = _stage_rect(screen, feed.ticket)
	assert_float(at.end.y).is_greater(line)
	assert_float(at.position.y).is_less(line)
	assert_float(feed.ticket.shine).is_between(0.0, 1.0)
	view.show_at(plan.feed_end)
	assert_bool(feed.ticket.visible).is_false()
	assert_bool(view.slot_plate.dock_state()[0]).is_false()


# --- helpers ---------------------------------------------------------------------------------


func _step(sounds: MachineSounds, from: float, to: float) -> void:
	var t: float = from
	while t < to:
		sounds.frame(t)
		t += 0.02
	sounds.frame(to)


## Chooses `chute` once the keys arm, fast-forwards the draw, picks the first prize (swapping
## the cart's first card out at the deck limit): the landing then plays.
func _pick(screen: ShiftScreen, chute: int) -> void:
	var view: RewardMachineView = screen._machine.view
	view.fast_forward()
	await _until(func() -> bool: return view.is_armed(), 5000)
	assert_bool(screen._machine._choose(chute)).is_true()
	view.fast_forward()
	await _until(func() -> bool: return view.is_armed(), 5000)
	var run: RunState = screen.run
	screen._machine._take(0, run.deck.cards[0] if run.deck_is_full() else null)
	assert_bool(view.plan.has_landing).is_true()


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
	# The last visit's glide back to the store (#77 machine v2) ends at once, as a tap ends it.
	screen._machine._end_return()


func _passed_screen() -> ShiftScreen:
	var screen: ShiftScreen = await _screen()
	await _pass(screen, true)
	return screen


func _screen() -> ShiftScreen:
	var scene: PackedScene = load(SCREEN)
	var screen: ShiftScreen = auto_free(scene.instantiate())
	scene_runner(screen)
	await _frames(4)
	return screen


func _place_row(screen: ShiftScreen) -> void:
	for id: String in PASSING_ROW:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())


func _pass(screen: ShiftScreen, rushed: bool) -> void:
	_place_row(screen)
	if rushed:
		await Rush.checkout(screen)
	else:
		await screen._on_checkout_pressed()
	assert_int(screen.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)


## A receipt alone on the screen's tree, as wide as the stage's.
func _receipt_on_screen() -> ReceiptView:
	var receipt: ReceiptView = auto_free(ReceiptView.new())
	receipt.size = Vector2(ShiftStage.RECEIPT_WIDTH, 300)
	get_tree().root.add_child(receipt)
	receipt.show_result(ScoreResult.new(), PackedStringArray())
	return receipt


## The stamps' ✓ is drawn by a font that has it (Pixelify has none: the mono font behind it).
func _assert_draws_check(font: Font) -> void:
	assert_bool(ArtStyle.DISPLAY_FONT.has_char("✓".unicode_at(0))).is_false()
	assert_bool(font.fallbacks.has(ArtStyle.MONO_FONT)).is_true()
	assert_bool(ArtStyle.MONO_FONT.has_char("✓".unicode_at(0))).is_true()


static func _inspection_stamp(receipt: ReceiptView) -> PanelContainer:
	var found: Array[Node] = receipt.find_children(ReceiptStamps.INSPECTION_NAME, "", true, false)
	for node: Node in found:
		if not node.is_queued_for_deletion():
			return node as PanelContainer
	return null


static func _label_with(root: Node, text: String) -> Label:
	for node: Node in root.find_children("*", "Label", true, false):
		if (node as Label).text == text and not node.is_queued_for_deletion():
			return node as Label
	return null


static func _texts(root: Node) -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for node: Node in root.find_children("*", "Label", true, false):
		if not node.is_queued_for_deletion() and not node.get_parent().is_queued_for_deletion():
			texts.append((node as Label).text)
	return texts


## A screen point in stage coordinates.
static func _stage_point(screen: ShiftScreen, point: Vector2) -> Vector2:
	return screen._stage.get_global_transform().affine_inverse() * point


## The slot plate's mouth in stage coordinates (it follows the camera).
static func _stage_mouth(screen: ShiftScreen, view: RewardMachineView) -> Rect2:
	return (
		screen._stage.get_global_transform().affine_inverse() * view.slot_plate.mouth_global_rect()
	)


## `control`'s rect in stage coordinates (its scale included).
static func _stage_rect(screen: ShiftScreen, control: Control) -> Rect2:
	return screen._stage.get_global_transform().affine_inverse() * control.get_global_rect()


static func _centre(control: Control) -> Vector2:
	return control.position + control.size / 2.0


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


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
