extends GdUnitTestSuite
## The upgrade step on the real shift screen (plan section 3.8): the ticket panel after the
## reward on upgrade shifts, the loyalty card, upgrade steps in the count-up and the receipt,
## the extra redraw, the run history on the results screen and the upgrade log events. Clicks
## are sent to the screen's handlers, because headless runs don't deliver input events.

const SCREEN := "res://ui/shift_screen.tscn"
const COUPON_ENGINE := "res://data/upgrades/coupon_engine.tres"
const CATEGORY_ENGINE := "res://data/upgrades/category_engine.tres"
const BREAD := "res://data/cards/bread.tres"

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	Engine.time_scale = 8.0


func after_test() -> void:
	Engine.time_scale = 1.0
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_tickets_follow_the_reward_only_on_upgrade_shifts() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var run: RunState = screen.run
	assert_bool(run.balance.upgrade_shifts.has(1)).is_false()
	assert_bool(run.balance.upgrade_shifts.has(2)).is_true()

	# Shift 1 is not an upgrade shift: the reward leads straight to shift 2.
	await _pass_shift(screen)
	assert_bool(screen._upgrade_panel.visible).is_false()
	screen._on_reward_skipped()
	assert_int(run.shift_index).is_equal(1)
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(screen._upgrade_panel.visible).is_false()

	# Shift 2 is: the tickets come after the reward, never with it.
	await _pass_shift(screen)
	assert_bool(screen._reward_panel.visible).is_true()
	assert_bool(screen._upgrade_panel.visible).is_false()
	screen._on_reward_skipped()
	assert_int(run.phase).is_equal(RunState.Phase.UPGRADE)
	assert_bool(screen._reward_panel.visible).is_false()
	assert_bool(screen._upgrade_panel.visible).is_true()
	await _frames(2)
	assert_bool(screen._shade.visible).is_true()
	# The panel fits its tickets once their wrapped lines are measured: it once stayed sized
	# to the unmeasured text (over 3,000 px tall) with the tickets off screen.
	await _frames(3)
	var panel_rect: Rect2 = screen._upgrade_panel.get_global_rect()
	assert_float(panel_rect.size.y).is_less_equal(
		screen._upgrade_panel.get_combined_minimum_size().y
	)
	assert_bool(screen.get_global_rect().encloses(panel_rect)).is_true()
	var tickets: Array[UpgradeTicket] = screen._upgrade_panel.tickets()
	assert_int(tickets.size()).is_equal(run.upgrade_offer.size())
	assert_int(tickets.size()).is_between(1, 3)
	# There is no skip: the panel has no button at all.
	assert_array(screen._upgrade_panel.find_children("*", "BaseButton", true, false)).is_empty()

	# The deck view (top bar) goes back to the tickets, never past them.
	screen._on_deck_button_pressed()
	assert_bool(screen._deck_view.visible).is_true()
	assert_bool(screen._upgrade_panel.visible).is_false()
	screen._deck_view._close()
	assert_bool(screen._upgrade_panel.visible).is_true()
	assert_int(run.phase).is_equal(RunState.Phase.UPGRADE)

	# A click before the panel is armed does nothing.
	var ticket: UpgradeTicket = tickets[0]
	screen._upgrade_panel._on_ticket_clicked(ticket)
	assert_int(run.phase).is_equal(RunState.Phase.UPGRADE)
	await _wait_wall_ms(450)
	screen._upgrade_panel._on_ticket_clicked(ticket)

	var picked: UpgradeDefinition = ticket.upgrade
	assert_array(run.upgrades).contains_exactly([picked])
	assert_int(run.shift_index).is_equal(2)
	assert_int(run.phase).is_equal(RunState.Phase.PLANNING)
	assert_bool(screen._upgrade_panel.visible).is_false()
	assert_object(run.history[1].upgrade_taken).is_same(picked)

	# The loyalty card's first box is stamped; hovering it tells what the upgrade does.
	var texts: PackedStringArray = screen._loyalty_card.box_texts()
	assert_int(texts.size()).is_equal(run.balance.upgrade_shifts.size())
	assert_str(texts[0]).is_equal(LoyaltyCard.initials(picked.display_name))
	assert_str(texts[1]).is_empty()
	var tooltip: String = screen._loyalty_card.box(0).tooltip_text
	assert_str(tooltip).contains(picked.display_name).contains(picked.effect_text)
	if not picked.condition_text.is_empty():
		assert_str(tooltip).contains(picked.condition_text)

	var types: Array = _events().map(func(event: Dictionary) -> String: return event["type"])
	assert_array(types.slice(-3)).is_equal(["reward", "upgrade", "shift_start"])
	var upgrade: Dictionary = _last_event("upgrade")
	assert_int(int(upgrade["shift"])).is_equal(2)
	assert_str(upgrade["picked"]).is_equal(String(picked.id))
	var offered: Array = upgrade["offered"]
	assert_int(offered.size()).is_equal(tickets.size())
	assert_str(offered[0]).is_equal(String(picked.id))
	assert_int(int(upgrade["decide_ms"])).is_greater_equal(450)


## Full build plan 7.3: a deck's starting upgrade takes a pre-stamped box of its own, before the
## upgrade-shift boxes.
func test_a_starting_upgrade_has_its_own_stamped_box() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var deck: DeckDefinition = (load("res://data/decks/starter.tres") as DeckDefinition).duplicate()
	deck.starting_upgrade = load(COUPON_ENGINE)
	screen.run = RunState.new(61, deck, screen.run.balance)
	screen.run.start_shift()
	screen._on_shift_started()
	var texts: PackedStringArray = screen._loyalty_card.box_texts()
	assert_int(texts.size()).is_equal(screen.run.balance.upgrade_shifts.size() + 1)
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
				"Supports: %s" % coupon_engine.supported_build,
			]
		)
	)
	# An empty condition still has its line.
	var plain: UpgradeDefinition = UpgradeDefinition.new()
	plain.display_name = "Plain"
	var plain_ticket: UpgradeTicket = auto_free(UpgradeTicket.new(plain))
	assert_str(plain_ticket.field_texts()[3]).is_equal("No condition")


func test_the_loyalty_card_has_one_empty_box_per_upgrade_shift() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	var texts: PackedStringArray = screen._loyalty_card.box_texts()
	assert_int(texts.size()).is_equal(screen.run.balance.upgrade_shifts.size())
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
	screen._on_debug_upgrade("coupon_engine")
	screen._on_debug_upgrade("category_engine")
	assert_int(screen.run.upgrades.size()).is_equal(2)
	_place_ids(screen, ["bread", "milk", "final_markdown"])
	var preview: ScoreResult = screen.run.preview()
	var upgrade_steps: Array[ScoreStep] = _upgrade_steps(preview)
	var kinds: Array = upgrade_steps.map(func(step: ScoreStep) -> int: return step.step_type)
	assert_array(kinds).contains([ScoreStep.StepType.MULTIPLIER, ScoreStep.StepType.FLAT])
	assert_str(_receipt_text(screen)).contains("× Coupon engine").contains("+ Category engine")

	await screen._on_checkout_pressed()
	assert_str(screen._subtotal_label.text).is_equal("€%d" % preview.total)
	assert_str(_receipt_text(screen)).contains("× Coupon engine").contains("+ Category engine")
	for step: ScoreStep in upgrade_steps:
		var box: Control = screen._loyalty_card.box(step.source_index)
		assert_object(box).is_not_null()
		assert_object(screen._count_up._source_control(step)).is_same(box)
		assert_object(screen._count_up._source_view(step)).is_null()
	# Card steps still come from their cards.
	for step: ScoreStep in screen.run.last_result.steps:
		if step.source_kind == ScoreStep.SourceKind.CARD:
			var source: Control = screen._count_up._source_control(step)
			assert_object(source).is_same(screen._row_views[step.source_slot])


## A first coupon that pays nothing: the Coupon engine fizzles from its box.
func test_an_upgrade_fizzle_plays_and_prints() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_debug_upgrade("coupon_engine")
	_place_ids(screen, ["bread", "multipack", "bread"])
	var wasted: Array[ScoreStep] = _upgrade_steps(screen.run.preview())
	assert_int(wasted.size()).is_equal(1)
	assert_int(wasted[0].step_type).is_equal(ScoreStep.StepType.WASTED)
	await screen._on_checkout_pressed()
	assert_str(_receipt_text(screen)).contains("Coupon engine: the first coupon paid nothing")
	assert_object(screen._count_up._source_control(wasted[0])).is_same(screen._loyalty_card.box(0))
	assert_bool(screen._counting).is_false()
	# The shake ends where it started: the box keeps its stamp tilt.
	assert_float(screen._loyalty_card.box(0).rotation).is_equal_approx(
		deg_to_rad(LoyaltyCard.STAMP_TILT), 0.001
	)


## Every stamped box rests at the same tilt, also after the boxes are rebuilt for a new stamp.
func test_every_stamped_box_keeps_its_tilt() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_debug_upgrade("coupon_engine")
	await _frames(2)
	screen._on_debug_upgrade("category_engine")
	await _frames(2)
	var boxes: Array[Control] = screen._loyalty_card.stamped_boxes()
	assert_int(boxes.size()).is_equal(2)
	for box: Control in boxes:
		assert_float(box.rotation).is_equal_approx(deg_to_rad(LoyaltyCard.STAMP_TILT), 0.001)
	var empty_box: Control = screen._loyalty_card._boxes.get_child(2) as Control
	assert_float(empty_box.rotation).is_equal(0.0)


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


func test_extra_redraw_gives_a_second_redraw() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	assert_str(screen._redraw_button.text).contains("(1 left)")
	screen._on_debug_upgrade("extra_redraw")
	assert_int(screen.run.redraws_allowed).is_equal(2)
	assert_str(screen._redraw_button.text).contains("(2 left)")
	assert_str(screen._loyalty_card.box_texts()[0]).is_equal("ExR")
	_redraw_first_card(screen)
	assert_int(screen.run.redraws_used).is_equal(1)
	assert_str(screen._redraw_button.text).contains("(1 left)")
	assert_bool(screen._redraw_button.disabled).is_false()
	_redraw_first_card(screen)
	assert_int(screen.run.redraws_used).is_equal(2)
	assert_str(screen._redraw_button.text).is_equal("Redraw used")
	assert_bool(screen._redraw_button.disabled).is_true()


func test_the_results_screen_lists_the_run_history() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _pass_shift(screen)
	screen._on_reward_skipped()
	await screen._on_checkout_pressed()
	assert_bool(screen._banner.visible).is_true()
	var cells: PackedStringArray = screen._history_view.cell_texts()
	var expected: Array = RunHistoryView.HEADERS.duplicate()
	expected.append_array(["1", "€27 / €10", "pass", "skipped", "—", "—"])
	expected.append_array(["2", "€0 / €13", "fail", "—", "—", "—"])
	assert_array(Array(cells)).is_equal(expected)
	# A full 8-shift history still fits the window.
	var full: Array[ShiftRecord] = []
	for shift: int in range(1, 9):
		full.append(ShiftRecord.new(shift, 48, 120))
	screen._history_view.show_history(full)
	await _frames(2)
	var height: int = ProjectSettings.get_setting("display/window/size/viewport_height")
	assert_float(screen._banner.get_combined_minimum_size().y).is_less_equal(height)
	var width: int = ProjectSettings.get_setting("display/window/size/viewport_width")
	assert_float(screen._banner.get_combined_minimum_size().x).is_less_equal(width)


func test_history_rows_name_the_card_upgrade_and_inspection() -> void:
	var record: ShiftRecord = ShiftRecord.new(4, 22, 30)
	record.card_picked = load(BREAD)
	record.upgrade_taken = load(CATEGORY_ENGINE)
	record.inspection = load("res://data/inspections/spot_check.tres")
	assert_array(Array(RunHistoryView.row_texts(record))).is_equal(
		["4", "€30 / €22", "pass", "Bread", "Category engine", "Spot check"]
	)


func test_run_end_lists_the_upgrades() -> void:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_debug_upgrade("coupon_engine")
	screen._on_debug_upgrade("category_engine")
	# An owned upgrade isn't given twice.
	screen._on_debug_upgrade("coupon_engine")
	assert_int(screen.run.upgrades.size()).is_equal(2)
	await screen._on_checkout_pressed()
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


## Places a row that passes the first two quotas: Bread, Multipack, Bread x4 = 27.
func _pass_shift(screen: ShiftScreen) -> void:
	_place_ids(screen, ["bread", "multipack", "bread", "bread", "bread", "bread"])
	await screen._on_checkout_pressed()
	assert_int(screen.run.phase).is_equal(RunState.Phase.REWARD)


## Adds the cards to the hand through the debug panel and places them at the end of the row.
func _place_ids(screen: ShiftScreen, ids: Array[String]) -> void:
	for id: String in ids:
		screen._on_debug_card(id)
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


## Every line of the receipt, joined.
static func _receipt_text(screen: ShiftScreen) -> String:
	var texts: PackedStringArray = PackedStringArray()
	for label: Node in screen._receipt.find_children("*", "Label", true, false):
		if not label.is_queued_for_deletion() and not label.get_parent().is_queued_for_deletion():
			texts.append((label as Label).text)
	return "\n".join(texts)


func _frames(count: int) -> void:
	for i: int in range(count):
		await get_tree().process_frame


## Waits on wall-clock time: the suite speeds up game time.
func _wait_wall_ms(ms: int) -> void:
	var start: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start < ms:
		await get_tree().process_frame
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
	var hand_box: HBoxContainer = screen._hand_box
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
