extends GdUnitTestSuite
## The week medals' prizes shown by name (v1.40, the user's verdict of 2026-11-18 on mock-up
## docs/art/mockups/medal_prizes.html), on the real shift screen at 1280x720 and 1920x1080:
## - no text says SILVER or GOLD: the medal case's labels, the tips, the machine's stamps and the
##   final receipt name the prizes, "+1 DRAW" and "PREMIUM", and the case's labels fit their room;
## - a ×3 checkout staples both prize tags ON the receipt's foot: inside the paper, in its foot
##   band under its lines, apart, small, each with its embossed medal and its words inside it;
##   the paper still turns gold; a ×2 checkout staples the +1 DRAW tag alone on silver paper;
## - at the machine the receipt arrives with its tags; the +1 DRAW tag comes off, flies inside the
##   window and becomes the reader plate's extra lamp (one lamp until it lands, then two, the new
##   one lit); the PREMIUM tag comes off and slams into the sign: the machine is PREMIUM and its
##   stamp lands from the slam, never before, and no gold stub pops up in the slot; a payday
##   (PREMIUM by its shift) has no PREMIUM tag and turns after its read, as before.
## Clicks are sent to the handlers (headless runs deliver no input).

const SCREEN := "res://ui/shift_screen.tscn"
const Rush := preload("res://tests/ui/count_up_rush.gd")
## Milk, Multipack, Milk x5 = 109: ×3 the first shift's quota (30).
const X3_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
const WINDOWS: Array[Vector2] = [Vector2(1280, 720), Vector2(1920, 1080)]
const OLD_WORDS: Array[String] = ["SILVER", "GOLD", "MEDAL"]

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_medal_prizes_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The prizes' names replace the metals' in every medal text.
func test_the_texts_name_the_prizes() -> void:
	var machine: MachineDefinition = (
		(load("res://data/balance/balance.tres") as BalanceDefinition).machine
	)
	var visit: MachineVisit = MachineVisit.new()
	visit.kind = MachineVisit.Kind.OVERTIME
	visit.binned = true
	var texts: Array[String] = [
		OvertimeWords.SILVER_NAME,
		OvertimeWords.GOLD_NAME,
		OvertimeWords.SILVER_STAMP,
		OvertimeWords.GOLD_STAMP,
		OvertimeWords.GOLD_READ,
		OvertimeWords.SILVER_REASON,
		OvertimeWords.SILVER_KEY_LEAD,
		OvertimeWords.stamp_under(machine, false),
		OvertimeWords.stamp_under(machine, true),
		OvertimeWords.medal_tip(machine, false, OvertimeWords.STATE_AVAILABLE, 60),
		OvertimeWords.medal_tip(machine, true, OvertimeWords.STATE_USED, 90),
		str(TipWords.WORDS["MEDALS"][1]),
		FinalReceipt.visit_text(visit),
		MedalCase.NAMES[0],
		MedalCase.NAMES[1],
	]
	for text: String in texts:
		for old: String in OLD_WORDS:
			(
				assert_bool(text.to_upper().contains(old))
				. override_failure_message('"%s" still says %s' % [text, old])
				. is_false()
			)
	assert_str(OvertimeWords.SILVER_NAME).is_equal("+1 DRAW")
	assert_str(OvertimeWords.GOLD_NAME).is_equal("PREMIUM")
	assert_str(OvertimeWords.SILVER_STAMP).is_equal("+1 DRAW!")
	assert_str(OvertimeWords.GOLD_STAMP).is_equal("PREMIUM!")
	assert_array(MedalCase.NAMES).is_equal(["+1 DRAW", "PREMIUM"])
	assert_str(FinalReceipt.visit_text(visit)).starts_with("+1 DRAW · ")
	# The tips' titles are the prizes.
	var tip: String = OvertimeWords.medal_tip(machine, false, OvertimeWords.STATE_AVAILABLE, 60)
	assert_str(tip.split("\n")[0]).is_equal("+1 DRAW")
	# The 3x5 capitals print every character of the names (none a blank).
	for words: String in MedalCase.NAMES:
		for character: String in words.replace(" ", ""):
			var rows: Array = PixelWords.glyph_of(character, PixelWords.Sheet.CAPS)
			assert_bool("".join(rows).contains("#")).override_failure_message(character).is_true()


## The case's labels read the prizes and fit: each name and its line right of its medal, inside
## the drawer's front, the +1 DRAW's words clear of the PREMIUM's ribbon and medal.
func test_the_case_names_the_prizes_in_its_room() -> void:
	for window: Vector2 in WINDOWS:
		var screen: ShiftScreen = await _screen(window)
		var medals: MedalCase = screen._stage.medal_case
		var drawer: Rect2 = screen._stage.get_global_transform() * ShiftStage.DRAWER_RECT
		var to_global: Transform2D = medals.get_global_transform()
		var silver: Dictionary = medals.parts(false)
		var gold: Dictionary = medals.parts(true)
		var texts: Array[String] = []
		for label: Node in medals.find_children("*", "PixelWords", true, false):
			if (label as PixelWords).visible:
				texts.append((label as PixelWords).text)
		assert_array(texts).contains(["+1 DRAW", "PREMIUM"])
		for parts: Dictionary in [silver, gold]:
			for key: String in ["name", "line"]:
				var rect: Rect2 = to_global * (parts[key] as Rect2)
				var what: String = "%s at %s" % [key, window]
				assert_bool(rect.has_area()).override_failure_message(what).is_true()
				assert_bool(drawer.encloses(rect)).override_failure_message(what).is_true()
				assert_float(rect.position.x).is_greater_equal(
					(to_global * (parts["medal"] as Rect2)).end.x
				)
		for key: String in ["name", "line"]:
			var words: Rect2 = silver[key]
			assert_float(words.end.x).is_less((gold["ribbon"] as Rect2).position.x)
			assert_float(words.end.x).is_less((gold["medal"] as Rect2).position.x)


## A ×3 checkout: both tags stapled on the gold paper's foot, inside the paper, at both sizes.
func test_a_x3_checkout_staples_both_tags_on_the_foot_at_720p() -> void:
	await _x3_checkout(WINDOWS[0])


## The same at 1920x1080 (a run of its own: a second screen in one test would resume the first's).
func test_a_x3_checkout_staples_both_tags_on_the_foot_at_1080p() -> void:
	await _x3_checkout(WINDOWS[1])


func _x3_checkout(window: Vector2) -> void:
	var screen: ShiftScreen = await _screen(window)
	var paper: ReceiptView = screen._stage.receipt
	var tags: ReceiptPrizeTags = paper.gold.tags
	assert_float(tags.band()).is_equal(0.0)
	assert_bool(tags.tag_rect(false).has_area()).is_false()
	var plain_margin: float = paper.get_theme_stylebox("panel").get_margin(SIDE_BOTTOM)
	_place(screen, X3_ROW)
	await Rush.checkout(screen)
	assert_bool(screen.run.history[-1].overtime_ticket).is_true()
	assert_bool(screen.run.history[-1].overtime_premium).is_true()
	# The paper turns gold as before; both tags are on.
	assert_bool(paper.gold.is_gold()).is_true()
	assert_int(tags.state_of(false)).is_equal(ReceiptPrizeTags.State.ON)
	assert_int(tags.state_of(true)).is_equal(ReceiptPrizeTags.State.ON)
	assert_bool(tags.is_on(false) and tags.is_on(true)).is_true()
	assert_float(tags.band()).is_equal(ReceiptPrizeTags.BAND)
	var margin: float = paper.get_theme_stylebox("panel").get_margin(SIDE_BOTTOM)
	assert_float(margin).is_equal(plain_margin + ReceiptPrizeTags.BAND)
	_assert_on_foot(paper, [false, true], "x3 at %s" % window)


## A ×2 checkout: the +1 DRAW tag alone, on silver paper; the next shift's paper has no tag and
## its plain foot back.
func test_a_x2_checkout_staples_the_draw_tag_alone() -> void:
	var screen: ShiftScreen = await _screen(WINDOWS[1])
	var paper: ReceiptView = screen._stage.receipt
	var tags: ReceiptPrizeTags = paper.gold.tags
	var plain_margin: float = paper.get_theme_stylebox("panel").get_margin(SIDE_BOTTOM)
	_place(screen, X3_ROW)
	screen.run.limits.quota = floori(screen.run.preview().total / 2.0)
	await Rush.checkout(screen)
	assert_bool(screen.run.history[-1].overtime_ticket).is_true()
	assert_bool(screen.run.history[-1].overtime_premium).is_false()
	assert_bool(paper.gold.is_silver()).is_true()
	assert_bool(paper.gold.is_gold()).is_false()
	assert_int(tags.state_of(false)).is_equal(ReceiptPrizeTags.State.ON)
	assert_int(tags.state_of(true)).is_equal(ReceiptPrizeTags.State.OFF)
	assert_bool(tags.tag_rect(true).has_area()).is_false()
	_assert_on_foot(paper, [false], "x2")
	# Its machine visit has the +1 DRAW tag only: one lamp until it lands, classic all along.
	var view: RewardMachineView = screen._machine.view
	await _frames(2)
	var plan: MachinePlan = view.plan
	assert_bool(plan.tag_draw).is_true()
	assert_bool(plan.tag_premium).is_false()
	assert_float(plan.tag_premium_at).is_equal(MachinePlan.NOT_SET)
	assert_float(plan.premium_at).is_equal(MachinePlan.NOT_SET)
	view.show_at(plan.tag_draw_at - 0.01)
	assert_int(view.slot_plate.lamp_count()).is_equal(1)
	view.show_at(plan.tag_draw_end + 0.01)
	assert_int(view.slot_plate.lamp_count()).is_equal(2)
	assert_int(view.slot_plate.lamps_lit()).is_equal(1)
	assert_int(tags.state_of(false)).is_equal(ReceiptPrizeTags.State.TAKEN)
	# Both draws done, the next shift's paper is plain again.
	await _draw_twice(screen)
	assert_int(screen.run.phase).is_equal(RunState.Phase.PLANNING)
	await _frames(3)
	assert_int(tags.state_of(false)).is_equal(ReceiptPrizeTags.State.OFF)
	assert_float(tags.band()).is_equal(0.0)
	var margin: float = paper.get_theme_stylebox("panel").get_margin(SIDE_BOTTOM)
	assert_float(margin).is_equal(plain_margin)


## At the machine after a ×3: the tags ride the receipt, the +1 DRAW becomes the extra lamp, the
## PREMIUM slams into the sign and turns the machine, at both sizes.
func test_the_tags_come_off_at_the_machine_at_720p() -> void:
	await _machine_tags(WINDOWS[0])


## The same at 1920x1080.
func test_the_tags_come_off_at_the_machine_at_1080p() -> void:
	await _machine_tags(WINDOWS[1])


func _machine_tags(window: Vector2) -> void:
	var screen: ShiftScreen = await _screen(window)
	var paper: ReceiptView = screen._stage.receipt
	var tags: ReceiptPrizeTags = paper.gold.tags
	_place(screen, X3_ROW)
	await Rush.checkout(screen)
	await _frames(2)
	var view: RewardMachineView = screen._machine.view
	var plan: MachinePlan = view.plan
	var bounds: Rect2 = Rect2(Vector2.ZERO, window)
	assert_int(plan.kind).is_equal(MachineVisit.Kind.TICKET)
	assert_bool(plan.tag_draw and plan.tag_premium).is_true()
	assert_int(plan.draws).is_equal(2)
	# The receipt is the stage's own, over the slot with both tags still on its foot.
	view.show_at(plan.fly_end + 0.01)
	assert_object(view.receipt_feed.paper).is_same(paper)
	assert_int(tags.state_of(false)).is_equal(ReceiptPrizeTags.State.ON)
	assert_int(tags.state_of(true)).is_equal(ReceiptPrizeTags.State.ON)
	assert_int(view.slot_plate.lamp_count()).is_equal(1)
	assert_int(view.slot_plate.lamps_lit()).is_equal(0)
	assert_bool(view.tags.is_flying(false)).is_false()
	assert_bool(view.head.stamp_shown()).is_false()
	assert_bool(view.head.premium_face()).is_false()
	_assert_on_foot(paper, [false, true], "over the slot at %s" % window)
	# The +1 DRAW tag in flight: off the paper, inside the window, the lamp not there yet.
	for share: float in [0.1, 0.4, 0.75, 0.95]:
		view.show_at(lerpf(plan.tag_draw_at, plan.tag_draw_end, share))
		assert_bool(view.tags.is_flying(false)).is_true()
		assert_bool(view.tags.is_flying(true)).is_false()
		var flying: Rect2 = view.tags.get_global_transform() * view.tags.tag_rect(false)
		(
			assert_bool(bounds.encloses(flying))
			. override_failure_message(
				"+1 DRAW tag %s at %s of its flight, %s" % [flying, share, window]
			)
			. is_true()
		)
		assert_int(view.slot_plate.lamp_count()).is_equal(1)
	assert_int(tags.state_of(false)).is_equal(ReceiptPrizeTags.State.TAKEN)
	assert_bool(tags.is_on(false)).is_false()
	# It lands on the leftmost of the two lamps, which is lit; the display names it.
	view.show_at(plan.tag_draw_end + 0.01)
	assert_bool(view.tags.is_flying(false)).is_false()
	assert_int(view.slot_plate.lamp_count()).is_equal(2)
	assert_int(view.slot_plate.lamps_lit()).is_equal(1)
	var lamp: Rect2 = view.slot_plate.get_global_transform() * view.slot_plate.lamp_rect(0)
	var landing: Rect2 = view.tags.get_global_transform() * view.tags.landing_rect(false)
	assert_vector(landing.get_center()).is_equal_approx(lamp.get_center(), Vector2.ONE)
	assert_str(view.display.texts()[0]).is_equal(OvertimeWords.SILVER_NAME)
	assert_bool(view.head.premium_face()).is_false()
	# The PREMIUM tag in flight: the machine still classic, no stamp yet.
	for share: float in [0.1, 0.4, 0.75, 0.95]:
		view.show_at(lerpf(plan.tag_premium_at, plan.tag_premium_end, share))
		assert_bool(view.tags.is_flying(true)).is_true()
		var flying: Rect2 = view.tags.get_global_transform() * view.tags.tag_rect(true)
		(
			assert_bool(bounds.encloses(flying))
			. override_failure_message(
				"PREMIUM tag %s at %s of its flight, %s" % [flying, share, window]
			)
			. is_true()
		)
		assert_bool(view.head.stamp_shown()).is_false()
		assert_bool(view.head.premium_face()).is_false()
		assert_bool(MachineLook.at(plan, view.clock).premium()).is_false()
	assert_int(tags.state_of(true)).is_equal(ReceiptPrizeTags.State.TAKEN)
	# The slam: the stamp lands where the tag flew, the sign is PREMIUM, no stub in the slot.
	assert_float(plan.premium_at).is_equal(plan.tag_premium_end)
	view.show_at(plan.tag_premium_end + 0.02)
	assert_bool(view.tags.is_flying(true)).is_false()
	assert_bool(view.head.premium_face()).is_true()
	assert_bool(view.slot_plate.stub_shown()).is_false()
	assert_str(view.head.stamp_texts()[0]).is_equal(OvertimeWords.GOLD_STAMP)
	var stamp: Rect2 = view.head.get_global_transform() * view.head.stamp_rect()
	var slam: Rect2 = view.tags.get_global_transform() * view.tags.landing_rect(true)
	assert_vector(slam.get_center()).is_equal_approx(stamp.get_center(), Vector2.ONE)
	view.show_at(plan.tag_premium_end + 0.5)
	assert_bool(view.head.stamp_shown()).is_true()
	assert_bool(view.slot_plate.stub_shown()).is_false()
	# Then the receipt is fed and the draws go on as before: 2 lamps lit, gold keys.
	assert_float(plan.feed_at).is_greater(plan.tag_premium_end)
	await _until_armed(screen)
	assert_int(view.slot_plate.lamp_count()).is_equal(2)
	assert_int(view.slot_plate.lamps_lit()).is_equal(2)
	for key: ChuteKey in view.keys:
		assert_bool(key.gold).is_true()


## Each tag inside the paper, in the foot band under the lines' room, with its medal and its words
## inside it; two tags apart.
func _assert_on_foot(paper: ReceiptView, golds: Array[bool], message: String) -> void:
	var tags: ReceiptPrizeTags = paper.gold.tags
	var to_global: Transform2D = paper.get_global_transform()
	var sheet: Rect2 = Rect2(Vector2.ZERO, paper.size)
	var box: StyleBox = paper.get_theme_stylebox("panel")
	var content_foot: float = paper.size.y - box.get_margin(SIDE_BOTTOM)
	var band: Rect2 = Rect2(0.0, content_foot, paper.size.x, ReceiptPrizeTags.BAND)
	var shown: Array[Rect2] = []
	for gold: bool in golds:
		var what: String = "%s: %s tag" % [message, "PREMIUM" if gold else "+1 DRAW"]
		var rect: Rect2 = tags.tag_rect(gold)
		assert_bool(rect.has_area()).override_failure_message(what).is_true()
		assert_bool(sheet.encloses(rect)).override_failure_message(what + " in the paper").is_true()
		assert_bool(band.encloses(rect)).override_failure_message(what + " in the band").is_true()
		# On the foot: its foot within a few px of the paper's own.
		assert_float(paper.size.y - rect.end.y).is_less(16.0)
		# Small: a line high, under half the paper wide.
		assert_float(rect.size.y).is_less_equal(20.0)
		assert_float(rect.size.x).is_less(paper.size.x / 2.0)
		# Whole art pixels.
		assert_vector(rect.position / 2.0).is_equal((rect.position / 2.0).round())
		var inside: Rect2 = Rect2(Vector2.ZERO, rect.size)
		var cell: float = ReceiptPrizeTags.CELL
		var medal: Rect2 = PrizeTagArt.medal_rect(cell)
		var words: Rect2 = PrizeTagArt.words_rect(gold, cell)
		assert_bool(inside.grow(-cell).encloses(medal)).override_failure_message(what).is_true()
		assert_bool(inside.grow(-cell).encloses(words)).override_failure_message(what).is_true()
		assert_float(words.position.x).is_greater(medal.end.x)
		# On screen, inside the paper's on-screen rect.
		var on_screen: Rect2 = to_global * rect
		(
			assert_bool((to_global * sheet).encloses(on_screen))
			. override_failure_message(what)
			. is_true()
		)
		shown.append(rect)
	if shown.size() == 2:
		assert_bool(shown[0].intersects(shown[1])).override_failure_message(message).is_false()
		assert_float(shown[1].end.x).is_less(shown[0].position.x)


func _screen(window: Vector2) -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	screen.size = window
	screen._week.skip()
	await _frames(3)
	return screen


func _place(screen: ShiftScreen, row: Array[String]) -> void:
	for id: String in row:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())


## The ticket's draw, then the +1 DRAW's: an UPGRADE register prize each.
func _draw_twice(screen: ShiftScreen) -> void:
	var view: RewardMachineView = screen._machine.view
	for _draw: int in range(2):
		await _until_armed(screen)
		assert_bool(screen._machine._choose(RewardMachine.Chute.UPGRADE)).is_true()
		await _until_armed(screen)
		var index: int = MachineSteps.register_index(screen.run)
		assert_int(index).is_greater_equal(0)
		view.pick(index)
		screen._machine.on_deck_added()
		view.fast_forward()
		await _frames(2)


func _until_armed(screen: ShiftScreen) -> void:
	screen._machine.view.fast_forward()
	var start: int = Time.get_ticks_msec()
	while not screen._machine.view.is_armed() and Time.get_ticks_msec() - start < 3000:
		await get_tree().process_frame
	assert_bool(screen._machine.view.is_armed()).is_true()


func _frames(count: int) -> void:
	for _frame: int in range(count):
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
