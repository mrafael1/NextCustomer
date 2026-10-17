extends GdUnitTestSuite
## The reward print-out on the real shift screen (#61, RewardPanel.show_printout): at the
## dessert's printer feed the offer appears beside the receipt, whose register column (the
## cabinet and the receipt) stays unshaded, as does the hung monitor with its totals (#80), without
## the repeated headline; its
## cards lift into place and it arms once they have and the mouse is up.
## Checked: the budget from the verdict to the armed reward with no taps; the offer's timeline
## (it starts at the feed, presented_ms at the lift's end, armed_ms not before it,
## presentation_skipped only for a skipped print-out, kept after the deck view and the deck-full
## chooser); a dessert skipped earlier and a tap during the lift; reduced motion; the layout
## with the deck-full note and the inspection warning; and the print-out on the stage of a wide
## window (#55). The real saves, logs and Music bus level
## are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const SCREEN_RECT := Rect2(0, 0, 1280, 720)
## A 32:9 window: the stage sits centred in it, with bare wall either side.
const WIDE_SIZE := Vector2i(2560, 720)
## Milk, Multipack, Milk x5 = 109: passes the first five quotas.
const PASSING_ROW: Array[String] = ["milk", "multipack", "milk", "milk", "milk", "milk", "milk"]
## The agreed budget from the verdict to the armed print-out, at Normal speed with no taps, and
## its tolerance for frame boundaries (decided with the user, #61).
const BUDGET_MS := 1000
const TOLERANCE_MS := 150
## A tween counts game time from the frame before it started, so in wall-clock time it can end up
## to a frame early.
const FRAME_SLACK_MS := 50
const NOTICE := "Next shift: test notice"

var _folder: String = ""
var _window_size: Vector2i
var _bus_db: float = 0.0
var _tuning: CountUpTuning


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(SCREEN_RECT.size)
	_bus_db = AudioServer.get_bus_volume_db(AudioServer.get_bus_index(MusicService.BUS))
	_tuning = load(CountUp.TUNING_PATH)


func after_test() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(MusicService.BUS), _bus_db)
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## A pass with no taps at Normal speed: the print-out arms within the budget of the verdict. Its
## timeline starts at the printer feed; presented_ms is the lift's end and armed_ms comes after
## it; nothing was skipped, and the reward event logs the same.
func test_a_pass_arms_the_printout_within_the_budget() -> void:
	var screen: ShiftScreen = await _screen()
	await _pass_shift(screen)
	var panel: RewardPanel = screen._reward_panel
	var count_up: CountUp = screen._count_up
	assert_bool(panel.is_printout()).is_true()
	assert_bool(panel._headline.visible).is_false()
	assert_bool(count_up.dessert_skipped).is_false()
	assert_int(panel.timeline._shown_at).is_equal(count_up.printer_feed_ms)
	await _until_armed(panel)
	var times: Dictionary = panel.timeline.fields(Time.get_ticks_msec())
	var presented: int = int(times["presented_ms"])
	var armed: int = int(times["armed_ms"])
	var verdict_to_armed: int = count_up.printer_feed_ms - count_up.total_shown_ms + armed
	prints("#61 verdict to armed:", verdict_to_armed, "presented", presented, "armed", armed)
	assert_int(verdict_to_armed).is_less_equal(BUDGET_MS + TOLERANCE_MS)
	assert_int(presented).is_between(
		_tuning.printout_lift_ms - FRAME_SLACK_MS, _tuning.printout_lift_ms + TOLERANCE_MS
	)
	assert_int(armed).is_greater_equal(presented)
	assert_bool(times["presentation_skipped"]).is_false()
	screen._on_reward_skipped()
	var reward: Dictionary = _last_event("reward")
	assert_int(int(reward["presented_ms"])).is_equal(presented)
	assert_int(int(reward["armed_ms"])).is_equal(armed)
	assert_bool(reward["presentation_skipped"]).is_false()


## A dessert skipped by a second tap during the count skips the print-out too: its cards lift at
## the skip speed and the reward logs presentation_skipped.
func test_a_skipped_dessert_skips_the_printout() -> void:
	var screen: ShiftScreen = await _screen()
	_place(screen)
	screen._on_checkout_pressed()
	await _frames(2)
	screen._count_up._tap(Time.get_ticks_msec())
	screen._count_up._tap(Time.get_ticks_msec())
	while screen._counting:
		await get_tree().process_frame
	assert_bool(screen._count_up.dessert_skipped).is_true()
	var panel: RewardPanel = screen._reward_panel
	await _until_armed(panel)
	var times: Dictionary = panel.timeline.fields(Time.get_ticks_msec())
	# A lift at its own speed ends no earlier than a frame before printout_lift_ms.
	assert_int(int(times["presented_ms"])).is_less(_tuning.printout_lift_ms - FRAME_SLACK_MS)
	screen._on_reward_skipped()
	assert_bool(_last_event("reward")["presentation_skipped"]).is_true()


## A tap early in the lift skips the rest of it: the cards are presented within a frame of the
## tap, well before the lift's own end; the reward logs presentation_skipped.
func test_a_tap_during_the_lift_skips_it() -> void:
	var screen: ShiftScreen = await _screen()
	await _pass_shift(screen)
	var panel: RewardPanel = screen._reward_panel
	assert_bool(panel.is_lifting()).is_true()
	assert_bool(panel._reader.is_reading()).is_true()
	var tapped: int = Time.get_ticks_msec()
	panel._reader.tapped.emit(tapped)
	var tapped_ms: int = tapped - panel.timeline._shown_at
	assert_int(tapped_ms).is_less(_tuning.printout_lift_ms - 2 * FRAME_SLACK_MS)
	await _until_armed(panel)
	assert_bool(panel._reader.is_reading()).is_false()
	var presented: int = int(panel.timeline.fields(Time.get_ticks_msec())["presented_ms"])
	assert_int(presented).is_less(tapped_ms + FRAME_SLACK_MS)
	screen._on_reward_skipped()
	assert_bool(_last_event("reward")["presentation_skipped"]).is_true()


## Promo products carry the PROMO tag on their price sticker on the print-out (#75: the offer
## is tray items; offer_scan_test checks where the tag sits); coupons and the impulse rack's
## products don't.
func test_promo_products_carry_a_sticker() -> void:
	var screen: ShiftScreen = await _screen()
	await _pass_shift(screen)
	var panel: RewardPanel = screen._reward_panel
	var offer: Array[CardDefinition] = [_card("milk"), _card("multipack")]
	screen._reward_panel.show_printout(
		offer, 13, 15, "", screen._receipt, screen._stage, Time.get_ticks_msec()
	)
	var views: Array[ItemView] = panel.items()
	assert_int(views.size()).is_equal(2)
	for view: ItemView in views:
		assert_int(view.form).is_equal(ItemView.Form.TRAY)
	assert_object(RewardPanel.promo_sticker(views[0] as CardView)).is_not_null()
	assert_str(RewardPanel.promo_sticker(views[0] as CardView).text).is_equal("PROMO")
	assert_object(RewardPanel.promo_sticker(views[1] as CardView)).is_null()
	panel.show_offer(offer, "Impulse rack", 13, 15)
	assert_object(RewardPanel.promo_sticker(panel._cards.get_children()[0] as CardView)).is_null()


## Shown again after the deck view, the print-out doesn't lift again and keeps its timeline.
func test_the_deck_view_never_replays_the_printout() -> void:
	var screen: ShiftScreen = await _screen()
	await _pass_shift(screen)
	var panel: RewardPanel = screen._reward_panel
	await _until_armed(panel)
	var timeline: OfferTimeline = panel.timeline
	var at_rest: Rect2 = panel._cards.get_global_rect()
	screen._on_deck_button_pressed()
	assert_bool(screen._deck_view.visible).is_true()
	await _frames(1)
	# The deck view shades the whole screen, the receipt and the monitor too.
	assert_float(screen._shade.offset_right).is_equal(0.0)
	assert_bool(screen._shade.hole().has_area()).is_false()
	assert_array(screen._shade.shaded_rects()).is_equal([screen._shade.get_global_rect()])
	screen._on_deck_closed()
	await _frames(2)
	assert_bool(panel.is_lifting()).is_false()
	assert_bool(panel.is_arming()).is_false()
	assert_object(panel.timeline).is_same(timeline)
	assert_that(panel._cards.get_global_rect()).is_equal(at_rest)
	assert_float(panel._cards.modulate.a).is_equal(1.0)


## At the deck limit, the deck-full chooser neither replays the print-out nor restarts its
## timeline: closed, the print-out comes back at rest on the same timeline; a card chosen there
## logs the reward with the print-out's presented_ms and armed_ms.
func test_the_deck_full_chooser_keeps_the_printout_timeline() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	while not run.deck_is_full():
		run.deck.add_card(_card("soup"))
	await _pass_shift(screen)
	var panel: RewardPanel = screen._reward_panel
	await _until_armed(panel)
	var timeline: OfferTimeline = panel.timeline
	var times: Dictionary = timeline.fields(Time.get_ticks_msec())
	var at_rest: Rect2 = panel._cards.get_global_rect()
	screen._on_reward_picked(run.offer[0])
	assert_bool(screen._deck_view.visible).is_true()
	assert_bool(panel.visible).is_false()
	await _frames(1)
	screen._on_deck_closed()
	await _frames(2)
	assert_bool(panel.visible).is_true()
	assert_bool(panel.is_lifting()).is_false()
	assert_bool(panel.is_arming()).is_false()
	assert_object(panel.timeline).is_same(timeline)
	assert_that(panel._cards.get_global_rect()).is_equal(at_rest)
	screen._on_reward_picked(run.offer[0])
	var view: DeckView = screen._deck_view
	view._on_card_clicked(view.card_views()[0])
	assert_int(run.phase).is_not_equal(RunState.Phase.REWARD)
	var reward: Dictionary = _last_event("reward")
	assert_int(int(reward["presented_ms"])).is_equal(int(times["presented_ms"]))
	assert_int(int(reward["armed_ms"])).is_equal(int(times["armed_ms"]))
	assert_bool(reward["presentation_skipped"]).is_false()


## Under reduced motion the cards fade in in place: they never move or scale, and the timing is
## the same.
func test_reduced_motion_fades_the_cards_in_place() -> void:
	var screen: ShiftScreen = await _screen()
	await _pass_shift(screen)
	var panel: RewardPanel = screen._reward_panel
	await _until_armed(panel)
	var rest: Rect2 = panel._cards.get_global_rect()
	_print(screen, panel.warning_text(), true)
	var moved: Array[String] = []
	var alphas: Array[float] = []
	while panel.is_lifting():
		await get_tree().process_frame
		alphas.append(panel._cards.modulate.a)
		if panel._cards.get_global_rect() != rest or panel._cards.scale != Vector2.ONE:
			moved.append(
				"cards at %s, scale %s" % [panel._cards.get_global_rect(), panel._cards.scale]
			)
	assert_array(moved).override_failure_message("\n".join(moved)).is_empty()
	assert_int(alphas.size()).is_greater(2)
	assert_float(alphas[0]).is_less(1.0)
	var presented: int = int(panel.timeline.fields(Time.get_ticks_msec())["presented_ms"])
	assert_int(presented).is_greater_equal(_tuning.printout_lift_ms - FRAME_SLACK_MS)


## The print-out fits the 1280x720 screen beside the receipt and under the hung monitor without
## overlapping either (#80), with the deck-full note and the inspection warning, on every frame of
## its lift; its note, warning, items and buttons sit inside it, one under the other, the items
## side by side; the shade leaves the register column and the monitor unshaded.
func test_the_printout_sits_beside_the_receipt() -> void:
	var screen: ShiftScreen = await _screen()
	await _pass_shift(screen)
	var panel: RewardPanel = screen._reward_panel
	await _until_armed(panel)
	_print(screen, NOTICE, false, screen.run.balance.deck_limit)
	assert_str(panel.warning_text()).is_equal(NOTICE)
	assert_str(panel._note.text).contains("deck is full")
	var receipt: Rect2 = screen._receipt.get_global_rect()
	var monitor: Rect2 = screen._stage.get_global_transform() * MonitorView.DRAWN_RECT
	var failures: Array[String] = []
	while panel.is_lifting():
		await get_tree().process_frame
		var cards: Rect2 = _drawn_rect(panel._cards)
		if not SCREEN_RECT.encloses(cards):
			failures.append("cards outside the screen at %s" % cards)
		if cards.intersects(receipt):
			failures.append("cards over the receipt at %s" % cards)
		if cards.intersects(monitor) or panel.get_global_rect().intersects(monitor):
			failures.append("print-out over the monitor at %s" % panel.get_global_rect())
	assert_array(failures).override_failure_message("\n".join(failures)).is_empty()
	await _frames(3)
	var rect: Rect2 = panel.get_global_rect()
	prints("#61 print-out", rect, "receipt", receipt)
	assert_bool(SCREEN_RECT.encloses(rect)).override_failure_message(str(rect)).is_true()
	assert_bool(rect.intersects(receipt)).override_failure_message(str(rect)).is_false()
	assert_float(rect.position.y).is_greater_equal(RewardPanel.PRINTOUT_TOP)
	# Under the monitor's foot (its bezel and shade), by PRINTOUT_GAP at least.
	assert_bool(rect.intersects(monitor)).override_failure_message(str(rect)).is_false()
	assert_float(rect.position.y).is_greater_equal(monitor.end.y + RewardPanel.PRINTOUT_GAP)
	var above: Rect2 = Rect2()
	for part: Control in [panel._note, panel._warning, panel._cards, panel._skip_button]:
		var part_rect: Rect2 = part.get_global_rect()
		assert_bool(part_rect.size.y > 0.0).is_true()
		assert_bool(rect.encloses(part_rect)).override_failure_message(str(part_rect)).is_true()
		if above.size != Vector2.ZERO:
			assert_float(part_rect.position.y).is_greater_equal(above.end.y)
		above = part_rect
	var previous: Rect2 = Rect2()
	for view: ItemView in panel.items():
		var item: Rect2 = view.get_global_rect()
		assert_bool(rect.encloses(item)).override_failure_message(str(item)).is_true()
		assert_bool(item.intersects(previous)).override_failure_message(str(item)).is_false()
		previous = item
		for part: Control in [view.sprite(), view.sticker()]:
			assert_bool(rect.encloses(part.get_global_rect())).is_true()
		var sticker: Label = RewardPanel.promo_sticker(view)
		if sticker != null:
			assert_bool(rect.encloses(sticker.get_global_rect())).is_true()
	await _frames(3)
	_assert_column_unshaded(screen)


## On a wide window the stage sits centred, and the print-out stays on it, where it sits on the
## stage of a 1280x720 window; the register column and the monitor stay unshaded. The print-out
## follows the stage as the window resizes.
func test_the_printout_stays_on_a_wide_stage() -> void:
	var screen: ShiftScreen = await _screen()
	await _pass_shift(screen)
	var panel: RewardPanel = screen._reward_panel
	await _until_armed(panel)
	await _frames(2)
	var on_stage: Vector2 = panel.get_global_rect().position - screen._stage.global_position
	get_tree().root.size = WIDE_SIZE
	await _frames(3)
	var stage: Rect2 = screen._stage.get_global_rect()
	var rect: Rect2 = panel.get_global_rect()
	prints("#55 wide print-out", rect, "stage", stage)
	assert_float(stage.position.x).is_equal((WIDE_SIZE.x - SCREEN_RECT.size.x) / 2.0)
	assert_bool(stage.encloses(rect)).override_failure_message(str(rect)).is_true()
	assert_that(rect.position - stage.position).is_equal(on_stage)
	assert_bool(rect.intersects(screen._receipt.get_global_rect())).is_false()
	var monitor: Rect2 = screen._stage.get_global_transform() * MonitorView.DRAWN_RECT
	assert_bool(rect.intersects(monitor)).override_failure_message(str(rect)).is_false()
	_assert_column_unshaded(screen)


# --- Helpers ---------------------------------------------------------------------------------


## The shade is up and misses the register column (the cabinet at rest and the receipt) and the
## hung monitor with its totals (#80; everything it draws, its LED and the quota chip), while it
## dims the rest of the counter left of the column.
func _assert_column_unshaded(screen: ShiftScreen) -> void:
	assert_bool(screen._shade.visible).is_true()
	var shade: Rect2 = screen._shade.get_global_rect()
	var column: Array[Rect2] = [
		screen._cabinet.get_global_rect(),
		screen._receipt.get_global_rect(),
	]
	for part: Rect2 in column:
		var message: String = "shade %s over %s" % [shade, part]
		assert_bool(shade.intersects(part)).override_failure_message(message).is_false()
	var stage: Transform2D = screen._stage.get_global_transform()
	var monitor: Array[Rect2] = [
		stage * MonitorView.DRAWN_RECT,
		screen._monitor.get_global_rect(),
		screen._led.get_global_rect(),
	]
	var chip: QuotaChip = screen._count_up._quota_chip
	if chip != null and chip.visible:
		monitor.append(chip.get_global_rect())
	var shaded: Array[Rect2] = screen._shade.shaded_rects()
	assert_int(shaded.size()).is_greater(1)
	for band: Rect2 in shaded:
		assert_bool(shade.encloses(band)).is_true()
		for part: Rect2 in monitor:
			var message: String = "shade band %s over the monitor's %s" % [band, part]
			assert_bool(band.intersects(part)).override_failure_message(message).is_false()
	# The belt and the hand are still dimmed.
	var belt: Vector2 = (stage * ShiftStage.BELT_RECT).get_center()
	var dimmed: bool = shaded.any(func(band: Rect2) -> bool: return band.has_point(belt))
	assert_bool(dimmed).is_true()
	prints("#80 print-out", screen._reward_panel.get_global_rect(), "monitor", monitor[0])


## Prints the run's offer again beside the receipt, now, with `warning`, and the deck at
## `deck_size` (the run's when 0).
func _print(screen: ShiftScreen, warning: String, reduced_motion: bool, deck_size: int = 0) -> void:
	screen._reward_panel.show_printout(
		screen.run.offer,
		deck_size if deck_size > 0 else screen.run.deck.size(),
		screen.run.balance.deck_limit,
		warning,
		screen._receipt,
		screen._stage,
		Time.get_ticks_msec(),
		1.0,
		RewardPanel.Lift.NORMAL,
		reduced_motion
	)


static func _card(id: String) -> CardDefinition:
	return load("%s/%s.tres" % [ShiftDebug.CARDS_FOLDER, id]) as CardDefinition


## A control's rect as drawn: its size through its global transform (scale and pivot included).
static func _drawn_rect(control: Control) -> Rect2:
	var xform: Transform2D = control.get_global_transform()
	return Rect2(xform * Vector2.ZERO, Vector2.ZERO).expand(xform * control.size)


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._on_reward_skipped()  # Past the impulse rack.
	# No music: the Music autoload's bus is restored after each test anyway.
	screen._count_up.music = null
	await _frames(2)
	return screen


func _place(screen: ShiftScreen) -> void:
	for id: String in PASSING_ROW:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())


## Passes shift 1 through the real checkout: returns once the print-out has appeared.
func _pass_shift(screen: ShiftScreen) -> void:
	_place(screen)
	await _frames(2)
	await screen._on_checkout_pressed()
	assert_int(screen.run.phase).is_equal(RunState.Phase.REWARD)
	assert_bool(screen._reward_panel.visible).is_true()


## Waits until the panel accepts clicks (a generous wall-clock limit).
func _until_armed(panel: RewardPanel) -> void:
	var start: int = Time.get_ticks_msec()
	while panel.is_arming() and Time.get_ticks_msec() - start < 3000:
		await get_tree().process_frame
	assert_bool(panel.is_arming()).is_false()


func _frames(count: int) -> void:
	for frame: int in range(count):
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
