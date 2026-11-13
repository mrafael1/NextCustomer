extends GdUnitTestSuite
## Point A of the user's monitor notes (2026-11-05): "Move the Repeat calculation to Repeat's scan.
## Keep Golden Milk's breakdown focused on how it earned its own payout. Replace the outgoing to
## Repeat equation with a quiet Copied by Repeat note beneath the total." In planning and in the
## count: both payouts stay the score's, the note shows only when a copy happens and takes no room
## from the rows, Repeat's scan names its source with the copied amount. Saves and logs go to a
## temporary folder.

const SCREEN := "res://ui/shift_screen.tscn"
const CARDS := "res://data/cards"
const MonitorParts := preload("res://tests/ui/monitor_parts.gd")

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_monitor_copy_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Point A (2026-11-05, the user's "Move the Repeat calculation to Repeat's scan"): Repeat copies
## Golden Milk. Milk's scan keeps its own breakdown (no "to Repeat" row) at the score's payout,
## with the quiet "Copied by Repeat" note in the payout zone, left of the total and clear of it;
## the note takes no room from the rows (the same rows, rects and pages without it). Repeat's scan
## reads "Copied from Golden Milk" with the copied amount (Milk's payout), its "+N€" the score's.
func test_a_copy_shows_on_the_copier_and_a_note_on_its_source() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["butter", "milk_golden", "repeat"])
	var result: ScoreResult = screen.run.preview()
	var names: PackedStringArray = CardInstance.names(screen.run.row)
	var milk: ScanController.ItemLines = screen._scan.item_lines(1)
	assert_str(milk.copied_by).is_equal(MonitorText.COPIED_BY % "Repeat")
	assert_int(milk.gives).is_equal(0)
	for line: String in milk.lines:
		assert_str(line).not_contains(ScanController.GIVES_TEXT % "Repeat")
	screen._monitor.show_scan(screen.run.row[1].definition, result.tags[1], milk)
	await _frames(1)
	var column: MonitorItemColumn = screen._monitor.item_column()
	assert_int(column.shown_value()).is_equal(result.payouts[1])
	var payout: MonitorPayout = column.payout_view()
	assert_str(payout.note_text()).is_equal("Copied by Repeat")
	var parts: Dictionary[String, Rect2] = column.part_rects()
	var note: Rect2 = parts["payout_note"]
	assert_bool(parts["footer"].grow(0.5).encloses(note)).is_true()
	assert_bool(note.intersects(parts["rows"])).is_false()
	for part: String in ["payout_equals", "payout_digits", "payout_shadow"]:
		if parts.has(part):
			assert_float(note.end.x).is_less_equal(parts[part].position.x)
	assert_float(note.end.y).is_less_equal(parts["payout_digits"].end.y + 0.5)
	assert_array(MonitorParts.problems(column)).is_empty()
	var with_note: Array[Rect2] = []
	for row: Control in column.step_rows():
		with_note.append(row.get_global_rect())
	var pages: int = column.pages.count()
	var plain: ScanController.ItemLines = screen._scan.item_lines(1)
	plain.copied_by = ""
	screen._monitor.show_scan(screen.run.row[1].definition, result.tags[1], plain)
	await _frames(1)
	assert_bool(payout.part_rects().has("Note")).is_false()
	assert_int(column.pages.count()).is_equal(pages)
	var without: Array[Rect2] = []
	for row: Control in column.step_rows():
		without.append(row.get_global_rect())
	assert_array(without).is_equal(with_note)
	var repeat: ScanController.ItemLines = screen._scan.item_lines(2)
	assert_str(repeat.copied_by).is_empty()
	var copied: String = MonitorText.copied_from(names[1], result.payouts[1])
	assert_str(copied).is_equal("Copied from Golden milk  %d€" % result.payouts[1])
	assert_bool(repeat.lines.has(copied)).is_true()
	screen._monitor.show_scan(screen.run.row[2].definition, result.tags[2], repeat)
	await _frames(1)
	var row: Control = column.step_rows()[0]
	assert_str((row.get_node("Text") as Label).text).is_equal("Copied from Golden milk")
	assert_str((row.get_node("Amount") as Label).text).is_equal("%d€" % result.payouts[1])
	assert_int(payout.given_amount()).is_equal(result.payouts[2])
	assert_int(payout.given_amount()).is_equal(PlanningModel.contribution(result, 2, names))
	assert_str(payout.note_text()).is_empty()


## Point A: a Repeat that copies nothing (slot 1: no item before it) leaves Golden Milk with no
## note, its rows and payout the score's; Repeat's scan says why it was wasted, no "Copied from".
func test_no_copy_no_note() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["repeat", "milk_golden", "butter"])
	var result: ScoreResult = screen.run.preview()
	assert_array(PlanningModel.copiers(result, 1)).is_empty()
	var milk: ScanController.ItemLines = screen._scan.item_lines(1)
	assert_str(milk.copied_by).is_empty()
	screen._monitor.show_scan(screen.run.row[1].definition, result.tags[1], milk)
	await _frames(1)
	var column: MonitorItemColumn = screen._monitor.item_column()
	assert_int(column.shown_value()).is_equal(result.payouts[1])
	assert_str(column.payout_view().note_text()).is_empty()
	assert_bool(column.part_rects().has("payout_note")).is_false()
	for line: String in screen._scan.item_lines(0).lines:
		assert_str(line).not_contains("Copied from")


## Point A (2026-11-05) in the count: Repeat copies Golden Milk. While Milk is in the bay its
## payout zone has the quiet "Copied by Repeat" note (no other item has one) and its rows never
## read "to Repeat"; Repeat's copy lands as "Copied from Golden Milk" with Milk's payout; each
## item's shown payout ends at the score's.
func test_the_count_shows_a_copy_on_the_copier_and_a_note_on_its_source() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["butter", "milk_golden", "repeat"])
	var result: ScoreResult = screen.run.preview()
	var monitor: MonitorView = screen._monitor
	monitor.reduced_motion = func() -> bool: return true
	var count: CountUp = screen._count_up
	var items: MonitorItemColumn = monitor.item_column()
	var notes: Dictionary[int, String] = {}
	var values: Dictionary[int, int] = {}
	var copies: PackedStringArray = PackedStringArray()
	var failures: Array[String] = []
	var on_start: Callable = func(
		beat: CountUpBeat, _beat_step: ScoreStep, _line: String, _view: CardView, _size: int
	) -> void:
		if beat.opens_slot and beat.scan_slot >= 0:
			notes[beat.scan_slot] = items.payout_view().note_text()
	var on_landed: Callable = func(index: int) -> void:
		var step: ScoreStep = result.steps[index]
		if step.slot != monitor._scanned:
			return
		values[step.slot] = items.shown_value()
		for text: String in items.step_texts():
			if text.contains(ScanController.GIVES_TEXT % "Repeat"):
				failures.append("A row read " + text)
		if step.step_type == ScoreStep.StepType.COPY:
			copies.append(items.step_texts()[-1])
	count.beat_started.connect(on_start)
	count.step_landed.connect(on_landed)
	var rush: Callable = func() -> void: count._tap(Time.get_ticks_msec())
	rush.call_deferred()
	await screen._on_checkout_pressed()
	assert_array(failures).is_empty()
	assert_str(notes.get(1, "?")).is_equal("Copied by Repeat")
	assert_str(notes.get(0, "?")).is_empty()
	assert_str(notes.get(2, "?")).is_empty()
	assert_array(copies).is_equal(
		PackedStringArray([MonitorText.copied_from("Golden milk", result.payouts[1])])
	)
	assert_int(values.get(1, -1)).is_equal(result.payouts[1])
	assert_int(values.get(2, -1)).is_equal(result.payouts[2])


## The screen on shift 1, its time card out of the way.
func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	screen._week.skip()
	await _frames(3)
	return screen


## Puts copies of cards into the row, in order, and refreshes the screen.
func _place(screen: ShiftScreen, card_ids: Array[String]) -> void:
	var run: RunState = screen.run
	for card_id: String in card_ids:
		var card: CardInstance = run.debug_add_to_hand(load("%s/%s.tres" % [CARDS, card_id]))
		assert_bool(run.place(card, run.row.size())).override_failure_message(card_id).is_true()
	screen._refresh()
	await _frames(2)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
