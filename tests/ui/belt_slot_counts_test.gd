extends GdUnitTestSuite
## The belt's slots line up at every supported slot count (v1.00, the user's play test of
## 2026-11-05: at 9 slots the overlay and the items no longer lined up): on the real shift screen
## with 6 open slots (Short belt's CLOSED cell after them), 7 (the usual row), 8 (Big basket) and
## 9 (Big basket and Extra till), every item stands centred on its cell, its ticket centred on the
## same line, every empty slot's footprint and blank ticket too; the rail's bolts and chevrons
## follow the row's own cells (a chevron centred under each ticket, a bolt at each cell's left
## edge, one of each per cell); every slot mark hangs inside its cell under its ticket; every
## item's sticker stack is scaled with the row, starts in its own cell, ends before the next
## stack starts and stays inside the viewport (at 9 slots full-size stacks ran over the next
## items, the stickers chaining into one band). A GOLDEN
## ticket's ring never hides a slot mark: Happy hour's "+3€" under a GOLDEN item hangs below the
## ring, its top tucked behind it by SlotMark.TUCKED only. Every rect is checked on screen, inside
## the viewport (the 1920x1080 window is the same layout scaled). The real saves and logs are
## never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const CARDS := "res://data/cards/%s.tres"
const SHORT_BELT := "res://data/inspections/short_belt.tres"
const EXTRA_TILL := "res://data/inspections/extra_till.tres"
const HAPPY_HOUR := "res://data/inspections/happy_hour.tres"
## Each case: its open slots, its upgrades, its day events.
const CASES: Array[Array] = [
	[6, [], [SHORT_BELT]],
	[7, [], []],
	[8, ["big_basket"], []],
	[9, ["big_basket"], [EXTRA_TILL]],
]
const ROW_IDS: Array[String] = [
	"bread", "milk", "eggs", "banana", "cheese", "croissant", "butter_golden", "coffee", "soup"
]
## How far two centres may differ: the row's float rounding, and the cues' whole pixels.
const TOLERANCE := 0.5
const CUE_TOLERANCE := 1.0
## Stickers stand on the 2 px art grid, and tilt a few degrees past their rects.
const STACK_TOLERANCE := 2.0

var _folder: String = ""


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)


func after_test() -> void:
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## Every supported slot count, its row full, then with only its first slots filled.
func test_every_slot_count_lines_up() -> void:
	var screen: ShiftScreen = await _screen()
	for case: Array in CASES:
		var count: int = case[0]
		await _set_up(screen, case)
		assert_int(screen._slots.size()).override_failure_message(str(count)).is_equal(count)
		for filled: int in [count, 3]:
			_fill(screen, filled)
			await _frames(3)
			var failures: PackedStringArray = _problems(
				screen, "%d slots, %d filled" % [count, filled]
			)
			assert_array(failures).override_failure_message("\n".join(failures)).is_empty()


## Happy hour's "+3€" mark under a GOLDEN item (its ring outside the ticket) hangs below the ring,
## tucked behind it by SlotMark.TUCKED only; under a plain item it hangs as before.
func test_a_golden_ring_never_hides_a_slot_mark() -> void:
	var screen: ShiftScreen = await _screen()
	await _set_up(screen, [7, [], [HAPPY_HOUR]])
	var plain_top: float = 0.0
	for last_id: String in ["butter", "butter_golden"]:
		screen.run.row.clear()
		_place(screen, ["bread", "milk", last_id])
		await _frames(3)
		var item: ItemView = screen._row_views[2] as ItemView
		var mark: SlotMark = screen._row_strip.inspection_mark(2)
		assert_object(mark).override_failure_message(last_id).is_not_null()
		var ticket: Rect2 = item.sticker().get_global_rect()
		var top: float = mark.get_global_rect().position.y
		if last_id == "butter":
			plain_top = top
			assert_object(item.sticker().gold_ring()).is_null()
			assert_float(top).is_equal_approx(ticket.end.y - SlotMark.TUCKED, TOLERANCE)
			continue
		var ring: TextureRect = item.sticker().gold_ring()
		assert_object(ring).is_not_null()
		var ring_foot: float = ticket.end.y + PriceSticker.GOLD_RING_ART * ArtStyle.ART_SCALE
		assert_float(ring.get_global_rect().end.y).is_less_equal(ring_foot + TOLERANCE)
		assert_float(top).is_equal_approx(ring_foot - SlotMark.TUCKED, TOLERANCE)
		assert_float(top).is_greater(plain_top)
		var cell: Rect2 = screen._slots[2].get_global_rect()
		assert_bool(_in_column(mark.get_global_rect(), cell)).is_true()
		assert_bool(_viewport(screen).encloses(mark.get_global_rect())).is_true()


## What is out of line on the screen now (`where` names the case).
func _problems(screen: ShiftScreen, where: String) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var viewport: Rect2 = _viewport(screen)
	var tickets: Array[Rect2] = []
	for slot: int in range(screen._slots.size()):
		var panel: PanelContainer = screen._slots[slot]
		var cell: Rect2 = panel.get_global_rect()
		var centre: float = cell.get_center().x
		var at: String = "%s, slot %d" % [where, slot + 1]
		if not viewport.encloses(cell):
			found.append("%s: cell %s off the viewport" % [at, cell])
		var ticket: Rect2
		if slot < screen._row_views.size():
			var item: ItemView = screen._row_views[slot] as ItemView
			ticket = item.sticker().get_global_rect()
			_check_centred(found, at + " item", item.body.get_global_rect(), centre)
		else:
			ticket = RowStrip.mat(panel).get_global_rect()
			_check_centred(
				found, at + " footprint", RowStrip.footprint(panel).get_global_rect(), centre
			)
		_check_centred(found, at + " ticket", ticket, centre)
		tickets.append(ticket)
		for mark: SlotMark in screen._row_strip._slot_marks(slot):
			var rect: Rect2 = mark.get_global_rect()
			var tucked: float = SlotMark.TUCKED * screen._row_strip.box.scale.y
			if not _in_column(rect, cell) or rect.position.y < ticket.end.y - tucked - TOLERANCE:
				found.append("%s: mark %s off its cell %s or over its ticket" % [at, rect, cell])
			if not viewport.encloses(rect):
				found.append("%s: mark %s off the viewport" % [at, rect])
	_check_stacks(screen, where, found)
	var belt: BeltPanel = screen._stage.belt
	for index: int in range(BeltPanel.BOLT_COUNT):
		var bolt: TextureRect = belt.get_node("Bolt%d" % index) as TextureRect
		var chevrons: TextureRect = belt.get_node("Chevrons%d" % index) as TextureRect
		var shown: bool = index < tickets.size() + screen._row_strip.closed.size()
		if bolt.visible != shown or chevrons.visible != shown:
			found.append("%s: cue %d shown %s" % [where, index, bolt.visible])
		if index >= tickets.size():
			continue
		var at: String = "%s, cue %d" % [where, index + 1]
		var cue: Rect2 = chevrons.get_global_rect()
		if absf(cue.get_center().x - tickets[index].get_center().x) > CUE_TOLERANCE:
			found.append("%s: chevrons %s not under ticket %s" % [at, cue, tickets[index]])
		var left: float = screen._slots[index].get_global_rect().position.x
		var head: Rect2 = bolt.get_global_rect()
		if head.end.x > left + head.size.x / 2.0 + CUE_TOLERANCE:
			found.append("%s: bolt %s past its cell's left edge %s" % [at, head, left])
		if (
			index > 0
			and head.position.x < tickets[index - 1].end.x - head.size.x / 2.0 - CUE_TOLERANCE
		):
			found.append("%s: bolt %s over ticket %s" % [at, head, tickets[index - 1]])
		if not viewport.encloses(head) or not viewport.encloses(cue):
			found.append("%s: cue off the viewport" % at)
	return found


## Each item's sticker stack (`where` names the case): at the row's scale, from its own cell,
## clear of the next item's stack, on screen.
static func _check_stacks(screen: ShiftScreen, where: String, found: PackedStringArray) -> void:
	var layer: PlanningLayer = screen._stage.planning_layer
	var row_scale: float = minf(screen._row_strip.box.scale.x, 1.0)
	var previous: Rect2 = Rect2()
	var stacks: int = 0
	for slot: int in range(screen._row_views.size()):
		var stack: Array[EffectSticker] = layer.stack(slot)
		if stack.is_empty():
			continue
		stacks += 1
		var at: String = "%s, stack %d" % [where, slot + 1]
		var rect: Rect2 = stack[0].get_global_rect()
		for sticker: EffectSticker in stack:
			rect = rect.merge(sticker.get_global_rect())
			if absf(sticker.scale.x - row_scale) > 0.01:
				found.append("%s: sticker scale %s, row %s" % [at, sticker.scale.x, row_scale])
		var cell: Rect2 = screen._slots[slot].get_global_rect()
		if rect.position.x < cell.position.x - STACK_TOLERANCE:
			found.append("%s: %s starts before its cell %s" % [at, rect, cell])
		if previous.has_area() and rect.position.x < previous.end.x - STACK_TOLERANCE:
			found.append("%s: %s over the previous stack %s" % [at, rect, previous])
		if not _viewport(screen).encloses(rect):
			found.append("%s: %s off the viewport" % [at, rect])
		previous = rect
	if screen._row_views.size() >= 3 and stacks == 0:
		found.append("%s: no sticker stack to check" % where)


static func _check_centred(
	found: PackedStringArray, what: String, rect: Rect2, centre: float
) -> void:
	if absf(rect.get_center().x - centre) > TOLERANCE:
		found.append("%s %s not centred on %s" % [what, rect, centre])


## Starts `case`'s shift: its upgrades and day events on a fresh run.
func _set_up(screen: ShiftScreen, case: Array) -> void:
	var run: RunState = screen.run
	run.upgrades.clear()
	for upgrade_id: String in case[1]:
		screen._debug.give_upgrade(upgrade_id)
	var events: Array[InspectionDefinition] = []
	for path: String in case[2]:
		events.append(load(path) as InspectionDefinition)
	run.inspections = events
	run.debug_skip_to_shift(run.shift_index)
	screen._on_shift_started()
	await _frames(3)


## Fills the first `filled` slots from ROW_IDS (cycled), in place of the row.
func _fill(screen: ShiftScreen, filled: int) -> void:
	screen.run.row.clear()
	var ids: Array[String] = []
	for slot: int in range(filled):
		ids.append(ROW_IDS[slot % ROW_IDS.size()])
	_place(screen, ids)


func _place(screen: ShiftScreen, card_ids: Array[String]) -> void:
	var run: RunState = screen.run
	for card_id: String in card_ids:
		var card: CardInstance = run.debug_add_to_hand(load(CARDS % card_id) as CardDefinition)
		assert_bool(run.place(card, run.row.size())).override_failure_message(card_id).is_true()
	screen._refresh()


func _screen() -> ShiftScreen:
	var runner: GdUnitSceneRunner = scene_runner(SCREEN)
	var screen: ShiftScreen = runner.scene()
	await _frames(3)
	return screen


## Whether `rect` stands in `cell`'s column (a mark hangs under the cell, in its width).
static func _in_column(rect: Rect2, cell: Rect2) -> bool:
	return rect.position.x >= cell.position.x - TOLERANCE and rect.end.x <= cell.end.x + TOLERANCE


static func _viewport(screen: ShiftScreen) -> Rect2:
	return screen.get_viewport().get_visible_rect()


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


static func _event_log() -> EventLogService:
	return (Engine.get_main_loop() as SceneTree).root.get_node("/root/EventLog")
