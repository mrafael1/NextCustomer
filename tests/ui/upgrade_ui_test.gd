extends GdUnitTestSuite
## Registers on the real shift screen (plan section 3.8; #77): a register picked from the RECEIPT
## REWARDS machine's REGISTER chute and stamped on the loyalty card, upgrade steps in the count-up
## and the receipt, the extra redraw, the run history on the results screen and the upgrade log
## events. Clicks are sent to the screen's handlers, because headless runs don't deliver input
## events.

const SCREEN := "res://ui/shift_screen.tscn"
## Checkouts rush their count (one tap): the suite tests what follows it.
const Rush := preload("res://tests/ui/count_up_rush.gd")
const COUPON_ENGINE := "res://data/upgrades/coupon_engine.tres"
const CATEGORY_ENGINE := "res://data/upgrades/category_engine.tres"
const BREAD := "res://data/cards/bread.tres"
const UPGRADES := "res://data/upgrades"

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The profile save goes there too, never to the real user:// profile.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The machine's REGISTER chute (#77): its prizes are registers; the Cart shows the deck and
## gives the machine back; the pick stamps the loyalty card's first box (its hover tells what the
## register does), applies from the next shift and is logged as machine_visit.
func test_a_register_from_the_machine_stamps_the_loyalty_card() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var run: RunState = screen.run
	await _pass_shift(screen)
	assert_bool(screen._machine.is_open()).is_true()
	await _frames(2)
	assert_bool(screen._shade.visible).is_true()
	assert_bool(screen._machine._choose(RewardMachine.Chute.REGISTER)).is_true()
	var prizes: Array[MachinePrize] = run.machine.prizes()
	assert_int(prizes.size()).is_between(1, 3)
	for prize: MachinePrize in prizes:
		assert_int(prize.kind).is_equal(MachinePrize.Kind.REGISTER)
	# The machine and its prize tickets fit the screen.
	await _frames(3)
	var machine: Rect2 = screen._machine.view.get_global_rect()
	assert_bool(screen.get_global_rect().encloses(machine)).is_true()
	for ticket: PrizeTicket in screen._machine.view.tickets:
		assert_bool(machine.encloses(ticket.get_global_rect())).is_true()
	# A click before the machine is armed does nothing.
	screen._machine.view._armed = false
	screen._machine.view.pick(0)
	screen._machine.view.fast_forward()  # The landing plays to its end.
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_PICK)
	await _until_armed(screen)

	# The deck view (top bar) goes back to the prizes, never past them.
	screen._on_deck_button_pressed()
	assert_bool(screen._deck_view.visible).is_true()
	assert_bool(screen._machine.view.visible).is_false()
	screen._deck_view._close()
	assert_bool(screen._machine.view.visible).is_true()
	assert_int(run.phase).is_equal(RunState.Phase.MACHINE_PICK)
	var picked: UpgradeDefinition = prizes[0].upgrade
	screen._machine.view.pick(0)
	screen._machine.view.fast_forward()  # The landing plays to its end.

	assert_array(run.upgrades).contains_exactly([picked])
	assert_int(run.shift_index).is_equal(1)
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(screen._machine.is_open()).is_false()
	assert_array(run.history[0].registers_taken()).is_equal([picked])

	# The loyalty card's first box is stamped; hovering it tells what the register does.
	var texts: PackedStringArray = screen._loyalty_card.box_texts()
	assert_int(texts.size()).is_equal(run.balance.machine.register_cap)
	assert_str(texts[0]).is_equal(LoyaltyCard.initials(picked.display_name))
	assert_str(texts[1]).is_empty()
	var tooltip: String = screen._loyalty_card.box(0).tooltip_text
	assert_str(tooltip).contains(picked.display_name).contains(picked.effect_text)
	if not picked.condition_text.is_empty():
		assert_str(tooltip).contains(picked.condition_text)

	var types: Array = _events().map(func(event: Dictionary) -> String: return event["type"])
	assert_array(types.slice(-2)).is_equal(["machine_visit", "shift_start"])
	var visit: Dictionary = _last_event("machine_visit")
	assert_int(int(visit["shift"])).is_equal(1)
	assert_str(visit["chute"]).is_equal("register")
	assert_int(int(visit["picked"])).is_equal(0)
	assert_str(visit["offered"][0]["id"]).is_equal(String(picked.id))
	assert_int((visit["offered"] as Array).size()).is_equal(prizes.size())
	assert_int(int(visit["registers_owned"])).is_equal(1)
	assert_int(int(visit["decide_ms"])).is_greater_equal(0)


## Full build plan 7.3: a deck's starting upgrade takes a pre-stamped box of its own, before the
## machine's register boxes.
func test_a_starting_upgrade_has_its_own_stamped_box() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var deck: DeckDefinition = (load("res://data/decks/starter.tres") as DeckDefinition).duplicate()
	deck.starting_upgrade = load(COUPON_ENGINE)
	screen.run = RunState.new(
		61, deck, screen.run.balance, RunStock.starting(deck, screen.run.balance)
	)
	screen.run.start_shift()
	screen._on_shift_started()
	var texts: PackedStringArray = screen._loyalty_card.box_texts()
	assert_int(texts.size()).is_equal(screen.run.balance.machine.register_cap + 1)
	assert_str(texts[0]).is_equal("CoE")
	assert_str(texts[1]).is_empty()
	assert_int(screen._loyalty_card.stamped_boxes().size()).is_equal(1)


## Every ticket shows the same fields in the same order (full build plan 5.2).
func test_a_ticket_shows_its_fields_in_order() -> void:
	var coupon_engine: UpgradeDefinition = load(COUPON_ENGINE)
	var ticket: UpgradeTicket = auto_free(UpgradeTicket.new(coupon_engine))
	(
		assert_array(Array(ticket.field_texts()))
		. is_equal(
			[
				coupon_engine.display_name,
				coupon_engine.type_label().to_upper(),
				coupon_engine.effect_text,
				coupon_engine.condition_text,
				"Supports: %s" % coupon_engine.build_names(),
			]
		)
	)
	# An empty condition still has its line.
	var plain: UpgradeDefinition = UpgradeDefinition.new()
	plain.display_name = "Plain"
	var plain_ticket: UpgradeTicket = auto_free(UpgradeTicket.new(plain))
	assert_str(plain_ticket.field_texts()[3]).is_equal("No condition")


## One empty box per register the machine can stamp (its register cap, #77).
func test_the_loyalty_card_has_one_empty_box_per_register() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var texts: PackedStringArray = screen._loyalty_card.box_texts()
	assert_int(texts.size()).is_equal(screen.run.balance.machine.register_cap)
	for text: String in texts:
		assert_str(text).is_empty()
	assert_array(screen._loyalty_card.stamped_boxes()).is_empty()
	# Similar names get different stamps.
	assert_str(LoyaltyCard.initials("Coupon engine")).is_equal("CoE")
	assert_str(LoyaltyCard.initials("Category engine")).is_equal("CaE")


## Coupon engine doubles Final markdown, Category engine pays on Milk (the last product): both
## come from their loyalty-card boxes, and the receipt names them.
func test_upgrade_steps_play_from_the_loyalty_card() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._debug.give_upgrade("coupon_engine")
	screen._debug.give_upgrade("category_engine")
	assert_int(screen.run.upgrades.size()).is_equal(2)
	_place_ids(screen, ["bread", "milk", "final_markdown"])
	var preview: ScoreResult = screen.run.preview()
	var upgrade_steps: Array[ScoreStep] = _upgrade_steps(preview)
	var kinds: Array = upgrade_steps.map(func(step: ScoreStep) -> int: return step.step_type)
	assert_array(kinds).contains([ScoreStep.StepType.MULTIPLIER, ScoreStep.StepType.FLAT])
	# The planning receipt lists only the items (#80): scanning them names the upgrades.
	assert_str(_receipt_text(screen)).not_contains("Coupon engine")
	assert_str(_scan_text(screen, 2)).contains("Coupon engine").contains("×")
	assert_str(_scan_text(screen, 1)).contains("Category engine").contains("+€")

	await Rush.checkout(screen)
	assert_str(screen._led.digits_label().text).is_equal(str(preview.total))
	assert_str(_receipt_text(screen)).contains("Coupon engine").contains("Category engine")
	for step: ScoreStep in upgrade_steps:
		var box: Control = screen._loyalty_card.box(step.source_index)
		assert_object(box).is_not_null()
		assert_object(screen._count_up._beats._source_control(step)).is_same(box)
		assert_object(screen._count_up._beats._source_view(step)).is_null()
	# Card steps still come from their cards.
	for step: ScoreStep in screen.run.last_result.steps:
		if step.source_kind == ScoreStep.SourceKind.CARD:
			var source: Control = screen._count_up._beats._source_control(step)
			assert_object(source).is_same(screen._row_views[step.source_slot])


## A first coupon that pays nothing: the Coupon engine fizzles from its box.
func test_an_upgrade_fizzle_plays_and_prints() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._debug.give_upgrade("coupon_engine")
	_place_ids(screen, ["bread", "multipack", "bread"])
	var wasted: Array[ScoreStep] = _upgrade_steps(screen.run.preview())
	assert_int(wasted.size()).is_equal(1)
	assert_int(wasted[0].step_type).is_equal(ScoreStep.StepType.WASTED)
	await Rush.checkout(screen)
	assert_str(_receipt_text(screen)).contains("Coupon engine: the first coupon paid nothing")
	assert_object(screen._count_up._beats._source_control(wasted[0])).is_same(
		screen._loyalty_card.box(0)
	)
	assert_bool(screen._counting).is_false()
	# The shake ends where it started: the box keeps its stamp tilt.
	assert_float(screen._loyalty_card.box(0).rotation).is_equal_approx(
		screen._loyalty_card.stamp_tilt(), 0.001
	)


## Every stamped box rests at the same tilt (the top bar's chip: upright, as B2), also after the
## boxes are rebuilt for a new stamp.
func test_every_stamped_box_keeps_its_tilt() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._debug.give_upgrade("coupon_engine")
	await _frames(2)
	screen._debug.give_upgrade("category_engine")
	await _frames(2)
	var boxes: Array[Control] = screen._loyalty_card.stamped_boxes()
	assert_int(boxes.size()).is_equal(2)
	assert_float(screen._loyalty_card.stamp_tilt()).is_equal(0.0)
	for box: Control in boxes:
		assert_float(box.rotation).is_equal_approx(screen._loyalty_card.stamp_tilt(), 0.001)
	# The final receipt's card keeps its tilt.
	var card: LoyaltyCard = auto_free(LoyaltyCard.new())
	assert_float(card.stamp_tilt()).is_equal_approx(deg_to_rad(LoyaltyCard.STAMP_TILT), 0.001)
	var empty_box: Control = screen._loyalty_card._boxes.get_child(2) as Control
	assert_float(empty_box.rotation).is_equal(0.0)


## Every upgrade's stamp is legible (#55 review #9): its initials are in the number font, paper
## with an ink outline on the dark tomato face, and fit inside the box's ink ring.
func test_every_stamp_fits_inside_its_ring() -> void:
	var upgrades: Array[UpgradeDefinition] = []
	for file_name: String in DirAccess.get_files_at(UPGRADES):
		if file_name.ends_with(".tres"):
			upgrades.append(load(UPGRADES.path_join(file_name)) as UpgradeDefinition)
	assert_int(upgrades.size()).is_greater(0)
	var card: LoyaltyCard = auto_free(LoyaltyCard.new())
	get_tree().root.add_child(card)
	card.show_upgrades(upgrades.size(), upgrades)
	await _frames(2)
	var inside: float = LoyaltyCard.BOX_SIZE.x - 2.0 * LoyaltyCard.STAMP_BORDER
	for box: Control in card.stamped_boxes():
		var face: StyleBoxFlat = box.get_theme_stylebox("panel") as StyleBoxFlat
		assert_object(face.bg_color).is_equal(Palette.TOMATO_DARK)
		var label: Label = box.get_child(0) as Label
		assert_object(label.get_theme_font("font")).is_same(ArtStyle.number_font())
		assert_object(label.get_theme_color("font_color")).is_equal(Palette.PAPER)
		assert_object(label.get_theme_color("font_outline_color")).is_equal(Palette.INK)
		assert_int(label.get_theme_constant("outline_size")).is_equal(LoyaltyCard.INITIALS_OUTLINE)
		(
			assert_float(label.get_minimum_size().x)
			. override_failure_message(
				(
					"%s is %.1f px wide, the ring holds %.1f"
					% [label.text, label.get_minimum_size().x, inside]
				)
			)
			. is_less_equal(inside)
		)


## The top bar's stamps (#80 step 10, mock-up B2; #59's glyphs not drawn yet): every upgrade's
## initials fall back into B2's 13x13 ring at 2x, mustard pale in the number font, at the largest
## size that fits inside both rings (the teal panel); an empty box is the dashed ring. The rings
## take no clicks but keep their hover text.
func test_every_chip_stamp_fits_inside_its_ring() -> void:
	var upgrades: Array[UpgradeDefinition] = []
	for file_name: String in DirAccess.get_files_at(UPGRADES):
		if file_name.ends_with(".tres"):
			upgrades.append(load(UPGRADES.path_join(file_name)) as UpgradeDefinition)
	var chip: LoyaltyCard = auto_free(LoyaltyCard.new(true))
	get_tree().root.add_child(chip)
	chip.show_upgrades(upgrades.size() + 1, upgrades)
	await _frames(2)
	var inside: float = LoyaltyCard.CHIP_BOX_SIZE.x - 2.0 * LoyaltyCard.CHIP_RING
	var stamped: Array[Control] = chip.stamped_boxes()
	assert_int(stamped.size()).is_equal(upgrades.size())
	for index: int in range(stamped.size()):
		var box: Control = stamped[index]
		assert_vector(box.size).is_equal(LoyaltyCard.CHIP_BOX_SIZE)
		var ring: StyleBoxTexture = box.get_theme_stylebox("panel") as StyleBoxTexture
		assert_object(ring.texture).is_same(LoyaltyCard.RING)
		var label: Label = box.get_child(0) as Label
		assert_str(label.text).is_equal(LoyaltyCard.initials(upgrades[index].display_name))
		assert_object(label.get_theme_font("font")).is_same(ArtStyle.number_font())
		assert_object(label.get_theme_color("font_color")).is_equal(Palette.MUSTARD_PALE)
		(
			assert_float(label.get_minimum_size().x)
			. override_failure_message("%s is too wide for the ring" % label.text)
			. is_less_equal(inside)
		)
		# The largest size that fits: the next size up (if any) would not.
		var font_size: int = label.get_theme_font_size("font_size")
		var at: int = LoyaltyCard.CHIP_INITIALS_SIZES.find(font_size)
		assert_int(at).is_not_equal(-1)
		if at > 0:
			label.add_theme_font_size_override("font_size", LoyaltyCard.CHIP_INITIALS_SIZES[at - 1])
			(
				assert_float(label.get_minimum_size().x)
				. override_failure_message("%s could be larger" % label.text)
				. is_greater(inside)
			)
			label.add_theme_font_size_override("font_size", font_size)
		assert_str(box.tooltip_text).contains(upgrades[index].display_name)
		assert_int(box.mouse_filter).is_equal(Control.MOUSE_FILTER_PASS)
	var empty: Control = chip._boxes.get_child(chip._boxes.get_child_count() - 1) as Control
	var empty_ring: StyleBoxTexture = empty.get_theme_stylebox("panel") as StyleBoxTexture
	assert_object(empty_ring.texture).is_same(LoyaltyCard.RING_EMPTY)
	assert_int(empty.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)


## A ticket already under the cursor lights up as soon as it is armed.
func test_a_hovered_ticket_lights_up_when_armed() -> void:
	var coupon_engine: UpgradeDefinition = load(COUPON_ENGINE)
	var ticket: UpgradeTicket = auto_free(UpgradeTicket.new(coupon_engine))
	ticket._set_hover(true)
	assert_object(ticket._style.border_color).is_equal(Palette.INK)
	ticket.armed = true
	assert_object(ticket._style.border_color).is_equal(Palette.TOMATO)
	ticket._set_hover(false)
	assert_object(ticket._style.border_color).is_equal(Palette.INK)


## A shift starts with the balance's 2 redraws; Extra redraw adds a third.
func test_extra_redraw_gives_a_third_redraw() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	assert_str(screen._redraw_button.caption).is_equal("Redraw")
	assert_str(screen._redraw_button.note()).is_equal("2 left")
	assert_str(screen._redraw_button.accessibility_name).is_equal("Redraw up to 2 items (2 left)")
	screen._debug.give_upgrade("extra_redraw")
	assert_int(screen.run.redraws_allowed).is_equal(3)
	assert_str(screen._redraw_button.note()).is_equal("3 left")
	assert_str(screen._loyalty_card.box_texts()[0]).is_equal("ExR")
	_redraw_first_card(screen)
	assert_int(screen.run.redraws_used).is_equal(1)
	assert_str(screen._redraw_button.note()).is_equal("2 left")
	_redraw_first_card(screen)
	assert_int(screen.run.redraws_used).is_equal(2)
	assert_str(screen._redraw_button.note()).is_equal("1 left")
	assert_bool(screen._redraw_button.disabled).is_false()
	_redraw_first_card(screen)
	assert_int(screen.run.redraws_used).is_equal(3)
	assert_str(screen._redraw_button.caption).is_equal("Redraw used")
	assert_str(screen._redraw_button.note()).is_empty()
	assert_str(screen._redraw_button.accessibility_name).is_equal("Redraw used")
	assert_bool(screen._redraw_button.disabled).is_true()


func test_the_results_screen_lists_the_run_history() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _pass_shift(screen)
	screen._machine.debug_skip()
	await Rush.checkout(screen)
	assert_bool(screen._results.visible).is_true()
	var texts: PackedStringArray = screen._results.texts()
	assert_str(texts[2]).is_equal("  1  €109 / €34     pass")
	assert_str(texts[3]).is_equal("     binned NEW ITEMS")
	assert_str(texts[4]).is_equal("  2  €0 / €35       fail")
	# The full 8-shift receipt's layout: tests/ui/results_panel_test.gd.


## A shift's dim lines: one per machine visit (#77), then the inspection.
func test_history_rows_name_the_visits_and_the_inspection() -> void:
	var record: ShiftRecord = ShiftRecord.new(4, 22, 30)
	record.passed = true
	var ticket: MachineVisit = MachineVisit.new()
	ticket.chute = RewardMachine.Chute.NEW_ITEMS
	var bread: Array[MachinePrize] = [
		MachinePrize.new(MachinePrize.Kind.PRODUCT, MachinePrize.Rarity.COMMON, load(BREAD))
	]
	ticket.set_drawn(bread)
	ticket.picked = 0
	var bonus: MachineVisit = MachineVisit.new(MachineVisit.Kind.BONUS, "spot_check")
	bonus.chute = RewardMachine.Chute.REGISTER
	var engine: Array[MachinePrize] = [
		MachinePrize.new(
			MachinePrize.Kind.REGISTER, MachinePrize.Rarity.COMMON, null, load(CATEGORY_ENGINE)
		)
	]
	bonus.set_drawn(engine)
	bonus.picked = 0
	record.visits.assign([ticket, bonus])
	record.inspection = load("res://data/inspections/spot_check.tres")
	(
		assert_array(Array(FinalReceipt.shift_texts(record)))
		. is_equal(
			[
				"  4  €30 / €22      pass",
				"     NEW ITEMS: Bread",
				"     BONUS · REGISTER: Category engine",
				"     inspection Spot check",
			]
		)
	)
	# Without a visit or an inspection, there is no dim line.
	assert_int(FinalReceipt.shift_texts(ShiftRecord.new(1, 10, 12)).size()).is_equal(1)


func test_run_end_lists_the_upgrades() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._debug.give_upgrade("coupon_engine")
	screen._debug.give_upgrade("category_engine")
	# An owned upgrade isn't given twice.
	screen._debug.give_upgrade("coupon_engine")
	assert_int(screen.run.upgrades.size()).is_equal(2)
	await Rush.checkout(screen)
	var run_end: Dictionary = _last_event("run_end")
	assert_array(run_end["upgrades"]).is_equal(["coupon_engine", "category_engine"])
	assert_str(_last_event("debug")["action"]).is_equal("give_upgrade")


## The receipt names an upgrade by its name, even when its rule's receipt text differs.
func test_the_receipt_names_the_upgrade() -> void:
	var step: ScoreStep = ScoreStep.new()
	step.source_kind = ScoreStep.SourceKind.UPGRADE
	step.source_index = 1
	step.text = "Category engine"
	var names: PackedStringArray = PackedStringArray(["Coupon engine", "Category engine"])
	assert_str(ReceiptView.source_text(step, names)).is_equal("Category engine")
	step.text = "tag bonus"
	assert_str(ReceiptView.source_text(step, names)).is_equal("tag bonus (Category engine)")
	step.source_kind = ScoreStep.SourceKind.CARD
	assert_str(ReceiptView.source_text(step, names)).is_equal("tag bonus")


## Places a row that passes the first five quotas: Milk, Multipack, Milk x5 = 109.
func _pass_shift(screen: ShiftScreen) -> void:
	_place_ids(screen, ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"])
	await Rush.checkout(screen)
	assert_int(screen.run.phase).is_equal(RunState.Phase.MACHINE_CHOOSE)


## Adds the cards to the hand through the debug panel and places them at the end of the row.
func _place_ids(screen: ShiftScreen, ids: Array[String]) -> void:
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())


func _redraw_first_card(screen: ShiftScreen) -> void:
	screen._on_redraw_pressed()
	screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[0]))
	screen._on_redraw_pressed()


static func _upgrade_steps(result: ScoreResult) -> Array[ScoreStep]:
	var found: Array[ScoreStep] = []
	for step: ScoreStep in result.steps:
		if step.source_kind == ScoreStep.SourceKind.UPGRADE:
			found.append(step)
	return found


## Scans the belt item in `slot` (the pointer on its sprite, its hover sent: headless runs never
## move the mouse; then its hold ends, #80) and returns its scan popup's footer, one line each,
## then ends the scan.
static func _scan_text(screen: ShiftScreen, slot: int) -> String:
	var view: ItemView = screen._row_views[slot] as ItemView
	var point: Vector2 = view.sprite().get_global_rect().get_center()
	screen._scan.pointer = func() -> Vector2: return point
	view.hovered.emit(view)
	screen._scan._go_full()
	# A belt item's scan shows on the hung monitor (#80).
	var text: String = "\n".join(screen._monitor.scan_footer().texts())
	screen._scan.clear()
	return text


## Every line of the receipt, joined.
static func _receipt_text(screen: ShiftScreen) -> String:
	var texts: PackedStringArray = PackedStringArray()
	for label: Node in screen._receipt.find_children("*", "Label", true, false):
		if label.is_queued_for_deletion() or label.get_parent().is_queued_for_deletion():
			continue
		if label.name == &"Marker":
			continue
		# A hung line prints its marker ("+", "×") in a child label beside its first row.
		var marker: Label = label.get_node_or_null("Marker") as Label
		var text: String = (label as Label).text
		texts.append(text if marker == null else "%s %s" % [marker.text, text])
	return "\n".join(texts)


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


func _last_event(type: String) -> Dictionary:
	var events: Array = _events()
	for index: int in range(events.size() - 1, -1, -1):
		if events[index]["type"] == type:
			return events[index]
	return {}


func _events() -> Array:
	var events: Array = []
	for line: String in EventLogWriter.join_logs(_folder).split("\n", false):
		events.append(JSON.parse_string(line))
	return events


static func _view_for(screen: ShiftScreen, card: CardInstance) -> CardView:
	var hand_box: Control = screen._hand_box
	for child: Node in hand_box.get_children():
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


## Big basket and Extra coupon slot make a 9-slot row: it is rebuilt with 9 slots, closes the
## gaps between its cells and is scaled to the width the screen was laid out for, so every slot
## stays on the belt, never overlapping the one before it, and clear of the receipt
## (shift_screen_layout_test checks the rest of the stage). The usual 7-slot row is never scaled.
func test_a_nine_slot_row_fits_the_screen() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await await_idle_frame()
	assert_int(screen._slots.size()).is_equal(7)
	assert_vector(screen._row_strip.box.scale).is_equal(Vector2.ONE)
	screen._debug.give_upgrade("big_basket")
	screen._debug.give_upgrade("extra_coupon_slot")
	for _frame: int in range(3):
		await await_idle_frame()
	assert_int(screen._slots.size()).is_equal(9)
	assert_float(screen._row_strip.box.scale.x).is_less(1.0)
	assert_int(screen._row_strip.box.get_theme_constant("separation")).is_equal(
		RowStrip.WIDE_SEPARATION
	)
	assert_int(screen.run.limits.slot_count).is_equal(7)
	assert_int(screen.run.limits.coupon_slot_count).is_equal(2)
	var belt: Rect2 = (
		Rect2(
			screen._stage.get_global_rect().position + ShiftStage.ROW_AREA.position,
			ShiftStage.ROW_AREA.size
		)
		. grow(0.01)
	)
	var receipt: Rect2 = screen._receipt.get_global_rect()
	var previous: Rect2 = Rect2()
	for slot: int in range(screen._slots.size()):
		var rect: Rect2 = screen._slots[slot].get_global_rect()
		assert_bool(belt.encloses(rect)).override_failure_message(str(rect)).is_true()
		assert_bool(rect.intersects(receipt)).override_failure_message(str(rect)).is_false()
		# (Touching cells, give or take the scale's float rounding.)
		if slot > 0:
			assert_float(rect.position.x).is_greater_equal(previous.end.x - 0.01)
		previous = rect


## Fast-forwards the machine to its wait point (as a tap would, unlogged), then waits (at most
## 3 s) for it to arm: the mouse is up, so it arms on its next frame.
func _until_armed(screen: ShiftScreen) -> void:
	screen._machine.view.fast_forward()
	var start: int = Time.get_ticks_msec()
	while not screen._machine.view.is_armed() and Time.get_ticks_msec() - start < 3000:
		await get_tree().process_frame
	assert_bool(screen._machine.view.is_armed()).is_true()
