extends GdUnitTestSuite
## The RECEIPT REWARDS machine's feed and landings on the real shift screen (#77, build spec 4.2-4.6
## and section 6, U3; machine v2 spec A3-A4): the receipt's copy (a second ReceiptView; the stage's
## receipt hides, torn off) travels with the camera into the machine's slot and feeds in under its
## clip, never shown for a resumed visit, cross-faded under reduced motion; an inspected pass stamps
## INSPECTION PASSED under PAID (with `stamp_notice`); with its BONUS visit to come no stub prints
## (2026-11-06: the receipt feeds once and pays every draw, the reader plate's lamps counting them,
## and the BONUS visit opens on AGAIN! with nothing fed); a new card flies into the cart drawer
## (right of the receipt, under the top bar, left of the machine) whose count chip goes n -> n+1 at
## the landing; an upgrade glints its copies one after another and changes them in place; a register
## flies to its LOYALTY card box, which is stamped (the plain landing is off); the machine's sounds
## follow the plan's moments, differ per rarity and never play on a jump. Clicks are sent to the
## handlers, because headless runs don't deliver input events.

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
## The live machine, put back after each test (the passing rows make ×2 and more, v1.03).
var _live_machine: MachineDefinition


func before_test() -> void:
	_live_machine = NoOvertime.live_off()
	_folder = "user://test_machine_landing_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	NoOvertime.live_restore(_live_machine)
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
	# The receipt's stamp carries no check.
	assert_str(title.text).is_equal("INSPECTION PASSED")
	assert_str(title.text).not_contains("✓")
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
		CardInstance.names(screen.run.row),
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


## The ticket's feed (#77 machine v2): the stage receipt itself travels (2026-11-05: its lines as
## the dessert left them); mid-travel it is between the printer and the slot; at the travel's
## end it is centred on the slot mouth's live rect (it follows the camera), its foot on the
## mouth's line, narrower than the receipt (feed_fit of the mouth); while fed it is clipped at
## the line; gone after the feed. Under reduced motion it cross-fades from the printer to the slot.
func test_the_receipt_travels_into_the_slot() -> void:
	var screen: ShiftScreen = await _passed_screen()
	var view: RewardMachineView = screen._machine.view
	var feed: ReceiptFeed = view.receipt_feed
	await _frames(2)
	assert_object(feed.paper).is_not_null()
	assert_object(feed.paper.find_child("BonusStub", true, false)).is_null()
	assert_array(Array(_texts(feed.paper))).is_equal(Array(_texts(screen._receipt)))
	# It keeps TODAY'S TARGET (the shift scene polish) pinned at its top.
	assert_int(feed.paper.target.shown_quota()).is_equal(screen._receipt.target.shown_quota())
	assert_int(feed.paper.target.shown_quota()).is_greater_equal(0)
	# The stage's paper itself (2026-11-05: the paper never changes on its way to the slot).
	assert_object(feed.paper).is_same(screen._receipt)
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
	# It heads for the slot's live mouth, which mid-glide is still on its way in (v0.98: the V3
	# counter fills the view, so the slot starts far right of where it ends; as store_camera_test):
	# between its rest and the furthest of its end and the plate's live right edge, give or take
	# the tear's tilt (half its height's sine).
	var tuning: MachineTuning = view.tuning
	var sway: float = rest.size.y / 2.0 * sin(deg_to_rad(tuning.tear_tilt_deg))
	var plate: Rect2 = _stage_rect(screen, view.slot_plate)
	var right: float = maxf(maxf(rest.position.x, rect.position.x), plate.end.x)
	assert_float(mid.position.x).is_between(rest.position.x - sway, right + sway)
	# Between its rest and the mouth, up to the tear's lift and tilt above them (v0.50: the slot sits
	# lower than the receipt's top, so the lift shows).
	var tilt: float = rest.size.x / 2.0 * sin(deg_to_rad(tuning.tear_tilt_deg))
	var top: float = minf(rect.position.y, rest.position.y) - tuning.tear_lift_px - tilt
	assert_float(mid.position.y).is_between(top, maxf(rect.position.y, rest.position.y))
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


## A pass with no later draw (shift 1: no inspection): no stub on either receipt, no banner, one
## draw lamp.
func test_no_stub_without_a_bonus() -> void:
	var screen: ShiftScreen = await _passed_screen()
	var view: RewardMachineView = screen._machine.view
	await _frames(2)
	assert_object(screen.find_child("BonusStub", true, false)).is_null()
	assert_object(screen.find_child("BonusBanner", true, false)).is_null()
	var plan: MachinePlan = view.plan
	assert_int(plan.draws).is_equal(1)
	view.show_at(plan.choose_at)
	assert_int(view.slot_plate.lamp_count()).is_equal(1)
	assert_int(view.slot_plate.lamps_lit()).is_equal(1)


## A NEW ITEMS pick: the prize flies from its ticket into the drawer's new slot; the drawer (V3:
## right edge CART_DRAWER_RIGHT, under the top bar, over the machine's stock window side and clear
## of its prize bay, inside the stage) slides in before the flight,
## its count chip reads n/<deck_limit> then n+1 at the landing with the new slot filled and NEW IN
## CART stamped, and it is gone after its slide out.
func test_a_new_card_flies_into_the_cart_drawer() -> void:
	var screen: ShiftScreen = await _passed_screen()
	var view: RewardMachineView = screen._machine.view
	var run: RunState = screen.run
	await _pick(screen, RewardMachine.Chute.NEW_ITEMS, MachinePrize.Kind.PRODUCT)
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
	var bay_left: float = ShiftStage.MACHINE_RECT.position.x + RewardMachineView.BAY_POSITION.x
	assert_float(rest.end.x).is_less_equal(bay_left)
	assert_float(_stage_rect(screen, drawer).end.x).is_equal_approx(rest.end.x, PX)
	assert_str(drawer.count_label.text).is_equal("%d/%d" % [landing.cart_before, limit])
	var new_slot: Dictionary = drawer.slots[-1]
	assert_bool(bool(new_slot["new"])).is_true()
	assert_bool((new_slot["sprite"] as Control).visible).is_false()
	assert_bool(drawer.stamp_label.visible).is_false()
	# The flight: from the picked ticket to the new slot, full size.
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
	# Left of the machine at 2x, at most over its edge (#77 machine v2: the receipt is fed by then).
	assert_float(drawer.rest_rect().position.x).is_greater_equal(ShiftStage.CART_DRAWER_LEFT)
	assert_float(drawer.rest_rect().end.x).is_less_equal(ShiftStage.CART_DRAWER_REACH)


## A REGISTER pick flies to its LOYALTY card box, shrinking, and the box's stamp slams down at the
## landing with one `stamp_loyalty` (the plain landing is off: no second sound); no drawer.
func test_a_register_flies_to_its_loyalty_box_and_is_stamped() -> void:
	var screen: ShiftScreen = await _screen()
	await _pass(screen, true)
	var view: RewardMachineView = screen._machine.view
	assert_bool(view.plain_landing).is_false()
	var sfx: Sfx = RECORDING_SFX.new()
	screen.add_child(sfx)
	view.sfx = sfx
	screen._sfx = sfx
	assert_int(MachineSteps.first_lit(screen.run, RewardMachine.Chute.UPGRADE)).is_equal(
		RewardMachine.Chute.UPGRADE
	)
	await _pick(screen, RewardMachine.Chute.UPGRADE, MachinePrize.Kind.REGISTER)
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


## A perk's level-up (v0.61, #108) flies to the box its perk already stamps and restamps it there
## with one `stamp_loyalty`: the box count stays, and its LV mark reads the new level inside the
## box.
func test_a_level_up_flies_to_its_own_box_and_shows_its_level() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	var engine: UpgradeDefinition = load("res://data/upgrades/coupon_engine.tres")
	run.upgrades.append(engine)
	run.machine.machine = run.machine.machine.duplicate() as MachineDefinition
	run.machine.machine.register_cap = 0  # The card is full: only level-ups.
	screen._refresh_loyalty_card()
	await _pass(screen, true)
	var view: RewardMachineView = screen._machine.view
	var sfx: Sfx = RECORDING_SFX.new()
	screen.add_child(sfx)
	view.sfx = sfx
	screen._sfx = sfx
	var owned: int = run.upgrades.find(engine)
	var boxes: int = screen._loyalty_card.stamped_boxes().size()
	await _pick(screen, RewardMachine.Chute.UPGRADE, MachinePrize.Kind.REGISTER)
	var plan: MachinePlan = view.plan
	assert_int(plan.landing).is_equal(MachinePlan.Landing.REGISTER)
	assert_bool(view.landing.level_up).is_true()
	assert_int(view.landing.box_index).is_equal(owned)
	var target: Vector2 = _stage_rect(screen, screen._loyalty_card.any_box(owned)).get_center()
	view.show_at(plan.land - 0.001)
	assert_float(view.flyer.end_point().distance_to(target)).is_less(PX)
	await _until(func() -> bool: return view.clock >= plan.land or view.plan != plan, 5000)
	await _frames(1)
	assert_int(sfx.call("count", "stamp_loyalty")).is_equal(1)
	view.fast_forward()  # The landing plays to its end.
	await _frames(2)
	assert_int(screen._loyalty_card.stamped_boxes().size()).is_equal(boxes)
	var mark: Control = screen._loyalty_card.level_mark(owned)
	assert_object(mark).is_not_null()
	assert_str((mark as Label).text).is_equal("2")
	var in_box: Array[Rect2] = screen._loyalty_card.level_mark_in_box(owned)
	(
		assert_bool(in_box[1].grow(0.01).encloses(in_box[0]))
		. override_failure_message(str(in_box))
		. is_true()
	)


## The sounds follow the plan: the feed's ticks (a series of 5) and slot tick, a note per lit key;
## the confirm, the packing, PACKED and each reveal's sounds; nothing on a jump or while
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
	assert_int(names.count("rattle_s")).is_equal(1)  # The tray packs (v0.50).
	var expected_notes: int = 0
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


## A new visit's first sounds: a later draw's `stamp_notice` lands with the head's stamp and
## AGAIN! at its start (2026-11-06: nothing is fed), and nothing prints; a visit resumed at its pick
## plays neither them nor a press for the resume, but the player's later pick press (`ui_click`)
## is heard.
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
	assert_int(names.count("stamp_notice")).is_equal(1)
	_step(sounds, 0.0, view.plan.read_end + 0.01)
	names = sfx.call("sound_names")
	assert_int(names.count("stamp_notice")).is_equal(1)
	assert_int(names.count("print")).is_equal(0)
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


## A passed review (seed 5's shift 4, a payday since v0.68) with its BONUS visit to come: the
## dessert prints no stub and no banner (2026-11-06), the receipt feeds once and lights a lamp per
## draw; the BONUS visit feeds nothing (no paper, no ticket): it opens on AGAIN! with one lamp
## fewer, the feed layer still under the top bar.
func test_a_review_pays_its_draws_from_one_receipt() -> void:
	var screen: ShiftScreen = await _screen()
	screen.start_new_run(5)
	await _frames(2)
	var fed: bool = false
	var again: bool = false
	for _shift: int in range(screen.run.shift_count() - 1):
		await _pass(screen, true)
		for _visit: int in range(MAX_VISITS):
			var run: RunState = screen.run
			if not RunState.MACHINE_PHASES.has(run.phase):
				break
			var view: RewardMachineView = screen._machine.view
			await _frames(2)
			var later: bool = not run.machine.pending_kinds().is_empty()
			if view.plan.kind == MachineVisit.Kind.TICKET and later and not fed:
				fed = true
				assert_object(screen.find_child("BonusStub", true, false)).is_null()
				assert_object(screen.find_child("BonusBanner", true, false)).is_null()
				assert_object(view.receipt_feed.paper).is_not_null()
				assert_int(view.plan.draws).is_equal(1 + run.machine.pending_kinds().size())
				view.show_at(view.plan.choose_at)
				assert_int(view.slot_plate.lamps_lit()).is_equal(view.plan.draws)
			elif view.plan.kind == MachineVisit.Kind.BONUS and fed and not again:
				again = true
				view.show_at(0.0)
				assert_bool(view.plan.is_again()).is_true()
				assert_float(view.plan.feed_end).is_equal(0.0)
				assert_object(view.receipt_feed.paper).is_null()
				assert_str(view.display.texts()[0]).is_equal(OvertimeWords.AGAIN)
				var left: int = view.plan.draws - view.plan.draw_index
				assert_int(view.slot_plate.lamps_lit()).is_equal(left)
				assert_int(view.feed_layer.get_index()).is_less(screen._stage.top_bar.get_index())
			_end_visit(screen)
		if again:
			break
	assert_bool(fed).override_failure_message("no ticket visit with a later draw").is_true()
	assert_bool(again).override_failure_message("no bonus visit").is_true()


# --- helpers ---------------------------------------------------------------------------------


func _step(sounds: MachineSounds, from: float, to: float) -> void:
	var t: float = from
	while t < to:
		sounds.frame(t)
		t += 0.02
	sounds.frame(to)


## Chooses `chute` once the keys arm, fast-forwards the draw, picks the first prize (swapping
## the cart's first card out at the deck limit): the landing then plays.
func _pick(screen: ShiftScreen, chute: int, kind: int = -1) -> void:
	var view: RewardMachineView = screen._machine.view
	view.fast_forward()
	await _until(func() -> bool: return view.is_armed(), 5000)
	assert_bool(screen._machine._choose(chute)).is_true()
	view.fast_forward()
	await _until(func() -> bool: return view.is_armed(), 5000)
	var run: RunState = screen.run
	var index: int = 0
	if kind >= 0:
		var kinds: Array = run.machine.prizes().map(func(p: MachinePrize) -> int: return p.kind)
		index = kinds.find(kind)
		assert_int(index).override_failure_message(str(kinds)).is_greater_equal(0)
	screen._machine._take(index, run.deck.cards[0] if run.deck_is_full() else null)
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
	screen._week.skip()  # The time card (v0.70) stays out of the way.
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
