extends GdUnitTestSuite
## A promo's cut at checkout (#182 grade 5, the Picky regular; the user's review of 2026-11-24: the
## denied beat "is too much for a promo"): on the real shift screen at 1280x720, a promo item plays
## the PROMO beat, never the denied one (no tomato "0" over its art, no denied buzz, no warning
## icon): its red promo tag pops as it scores, it pays the score's promo price, and its receipt row
## wears the small promo tag. A real denial (the Spot check) keeps the denied beat. The saves and
## logs go to a temporary folder only.

const SCREEN := "res://ui/shift_screen.tscn"
const RECORDING_SFX := preload("res://tests/presentation/recording_sfx.gd")
const Rush := preload("res://tests/ui/count_up_rush.gd")
const SCREEN_RECT := Rect2(0, 0, 1280, 720)
## Milk (Dairy) on the promo, Bread not on it.
const PROMO_ROW: Array[String] = ["milk", "bread"]
## Milk, Bread, then Cheese in slot 3, which the Spot check pays 0.
const DENIED_ROW: Array[String] = ["milk", "bread", "cheese"]
const GRADE := 5
const CUT := 25

var _folder: String = ""
var _window_size: Vector2i
var _runner: GdUnitSceneRunner


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(SCREEN_RECT.size)


func after_test() -> void:
	Rush.restore()
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


func test_a_promo_item_pops_its_tag_and_is_never_denied() -> void:
	var screen: ShiftScreen = await _screen()
	var run: RunState = screen.run
	run.balance = GradeApply.balance_for(run.balance, GRADE)
	run.grade = GRADE
	run.shift_index = WeekSchedule.length(run.balance)  # Week 2: the Picky regular's from then.
	await _place(screen, PROMO_ROW)
	var shift: int = run.shift_index + 1
	run.twists.picky[shift] = "Dairy"
	run.twists.promo_cuts[shift] = CUT
	run.twists.clear_events()
	screen._refresh()
	await _frames(3)
	var milk: CardView = screen._row_views[0]
	var tag: PromoTag = PromoTag.of(milk)
	assert_object(tag).is_not_null()
	assert_str(tag.text).is_equal("-%d%%" % CUT)
	assert_object(PromoTag.of(screen._row_views[1])).is_null()
	var expected: ScoreResult = run.preview()
	var cut: ScoreStep = _override_on(expected, 0)
	assert_int(cut.promo_cut).is_equal(CUT)
	# The monitor's line icon for the cut is the small promo tag, not the warning sign.
	assert_object(MonitorView.source_icon(cut, null, [], run.inspections)).is_same(PromoTag.MINI)
	var seen: Dictionary = await _count(screen, 0)
	assert_array(seen["kinds"]).contains(["PROMO"])
	assert_array(seen["kinds"]).not_contains(["DENIED"])
	assert_int(seen["denied_sounds"]).is_equal(0)
	assert_bool(seen["zero_label"]).override_failure_message("a tomato 0 showed").is_false()
	assert_float(seen["tag_peak"]).is_greater(1.1)
	assert_vector(seen["tag_rest"] as Vector2).is_equal(Vector2.ONE)
	# It pays the score's promo price; the row's mark is the promo tag, inside the receipt.
	assert_int(expected.payouts[0]).is_less(load("res://data/cards/milk.tres").base as int)
	_assert_mark(seen, 0, ReceiptView.Mark.PROMO, ReceiptDecor.PROMO_ICON)


func test_a_real_denial_keeps_the_denied_beat() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.set_inspection("spot_check")
	await _place(screen, DENIED_ROW)
	var expected: ScoreResult = screen.run.preview()
	var denial: ScoreStep = _override_on(expected, 2)
	assert_int(denial.promo_cut).is_equal(0)
	assert_object(MonitorView.source_icon(denial, null, [], screen.run.inspections)).is_same(
		GiverBadge.WARNING
	)
	var seen: Dictionary = await _count(screen, -1)
	assert_array(seen["kinds"]).contains(["DENIED"])
	assert_array(seen["kinds"]).not_contains(["PROMO"])
	assert_int(seen["denied_sounds"]).is_greater(0)
	assert_bool(seen["zero_label"]).override_failure_message("no tomato 0 showed").is_true()
	_assert_mark(seen, 2, ReceiptView.Mark.DENIED, ReceiptDecor.WARNING_ICON)


func test_a_promo_price_of_0_wears_no_warning_sign_on_the_monitor() -> void:
	# A 1€ item at -25% pays 0€ (rounded down): its promo tag says why, not a denial's warning.
	var eggs: CardDefinition = load("res://data/cards/eggs.tres")
	for promo: bool in [true, false]:
		var column: MonitorItemColumn = auto_free(MonitorItemColumn.new())
		add_child(column)
		var shown: ScanController.ItemLines = ScanController.ItemLines.new()
		shown.payout = 0
		shown.promo = promo
		column.show_item(eggs, eggs.tags, shown)
		assert_bool(_payout_glyph(column)).is_equal(not promo)
		column.start_item(eggs, eggs.tags, false)
		column.set_value(0, false, promo)
		assert_bool(_payout_glyph(column)).is_equal(not promo)
		remove_child(column)


static func _payout_glyph(column: MonitorItemColumn) -> bool:
	var glyph: TextureRect = column.payout_view().find_child("Glyph", true, false) as TextureRect
	return glyph != null and glyph.visible


## Checks out and watches the count frame by frame: the beats' kinds, the denied sounds, whether a
## tomato "0" showed over the items (the denied beat's), the promo tag's largest scale on `slot`'s
## item (-1: none) and its last one, and each printed
## receipt row's last mark seen ([kind, texture, global rect], by row index).
func _count(screen: ShiftScreen, slot: int) -> Dictionary:
	var sfx: Sfx = RECORDING_SFX.new()
	screen.add_child(sfx)
	screen._count_up._sfx = sfx
	var kinds: Array[String] = []
	screen._count_up.beat_started.connect(
		func(beat: CountUpBeat, _s: ScoreStep, _l: String, _v: CardView, _i: int) -> void:
			kinds.append(CountUpBeat.Kind.keys()[beat.kind])
	)
	Rush.speed_up(_runner, 2.0)
	screen._on_checkout_pressed()
	var peak: float = 1.0
	var zero_label: bool = false
	var marks: Dictionary[int, Array] = {}
	var rest: Vector2 = Vector2.ONE
	var overlay: Control = screen._count_up._overlay
	while screen._counting:
		await get_tree().process_frame
		var views: Array[CardView] = screen._count_up._views
		var tag: PromoTag = PromoTag.of(views[slot]) if slot >= 0 and slot < views.size() else null
		if tag != null:
			peak = maxf(peak, tag.scale.x)
			rest = tag.scale
		for node: Node in overlay.find_children("*", "Label", true, false):
			var label: Label = node as Label
			if label.text == "0" and label.get_theme_color("font_color") == Palette.TOMATO:
				zero_label = true
		var rows: Array[Control] = screen._receipt.printed_rows()
		for index: int in range(rows.size()):
			var mark: TextureRect = rows[index].find_child("Mark", true, false) as TextureRect
			if mark != null:
				marks[index] = [mark.get_meta("mark"), mark.texture, mark.get_global_rect()]
	var denied: int = 0
	for entry: Dictionary in sfx.get("sounds"):
		if entry["sound"] == "denied":
			denied += 1
	return {
		"kinds": kinds,
		"denied_sounds": denied,
		"zero_label": zero_label,
		"tag_peak": peak,
		"tag_rest": rest,
		"marks": marks,
	}


## Row `slot` wore mark `kind` with `icon`, on screen.
func _assert_mark(seen: Dictionary, slot: int, kind: ReceiptView.Mark, icon: Texture2D) -> void:
	var marks: Dictionary[int, Array] = seen["marks"]
	assert_bool(marks.has(slot)).override_failure_message(str(marks)).is_true()
	if not marks.has(slot):
		return
	assert_int(marks[slot][0] as int).is_equal(kind)
	assert_object(marks[slot][1]).is_same(icon)
	var rect: Rect2 = marks[slot][2]
	assert_bool(SCREEN_RECT.encloses(rect)).override_failure_message(str(rect)).is_true()


static func _override_on(result: ScoreResult, slot: int) -> ScoreStep:
	for step: ScoreStep in result.steps:
		if step.slot == slot and step.step_type == ScoreStep.StepType.PAYOUT_OVERRIDE:
			return step
	return null


func _screen() -> ShiftScreen:
	_runner = scene_runner(SCREEN)
	var screen: ShiftScreen = _runner.scene()
	screen._week.skip()
	var machine: MachineDefinition = screen.run.machine.machine.duplicate()
	machine.overtime_ticket_per_week = 0
	machine.overtime_premium_per_week = 0
	screen.run.machine.machine = machine
	await _frames(2)
	return screen


func _place(screen: ShiftScreen, ids: Array[String]) -> void:
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(ids.size())
	await _frames(3)


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


static func _event_log() -> EventLogService:
	return Engine.get_main_loop().root.get_node("/root/EventLog") as EventLogService
