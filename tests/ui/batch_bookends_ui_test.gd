extends GdUnitTestSuite
## A Bakery batch's bookends (2026-11-12, the approved batch_positions mock-up's A with D's icing
## drip): the model records each framed batch's job cards, what a Baguette counted and the glazed
## last item, from the score. On the real shift screen the FIRST cap stands on the frame's left
## side at the batch's first ticket and the LAST cap on its right side at its last, each reaching
## onto its ticket's outline only, their tabs across the frame's foot under the end tickets, clear
## of every ticket's text, chips, glyphs and price window; the icing drip pours over the LAST cap
## only when an Iced bun glazes the batch's last item. Hovering a job card lights the cap it reads
## (tomato when it is WASTED there, with its note), a Baguette's fill runs to its ticket and an
## Iced bun's dashed line to the LAST cap; any other item lights nothing. In the count a frame
## binds the batch's tickets still on the belt (no FIRST cap once the first is bagged), and a job
## card's step plays on the caps: the real count's steps reach them through BeltRide, the bagged
## items' pops tick in one counter at the frame's left end. A batch split over two frames plays
## each beat once; a drag's ghost at a batch end keeps that end's cap. Reduced motion lights and
## puts back at once. A chain's frame wears none. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const CARDS := "res://data/cards/%s.tres"
const SCREEN_RECT := Rect2(0, 0, 1280, 720)
## The mock-up's rows: every job works; then Bread opens the batch, so the Croissant's is wrong.
const GOOD_ROW: Array[String] = [
	"croissant", "bread", "baguette", "iced_bun", "stale_doughnut", "banana"
]
const WRONG_ROW: Array[String] = [
	"bread", "croissant", "baguette", "iced_bun", "stale_doughnut", "banana"
]

var _folder: String = ""
var _window_size: Vector2i
var _runner: GdUnitSceneRunner


func before_test() -> void:
	_folder = "user://test_logs_%d" % Time.get_ticks_usec()
	_event_log().use_folder(_folder)
	# The run and profile saves go there too, never to the real user:// saves.
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, _folder)
	_window_size = get_tree().root.size
	get_tree().root.size = Vector2i(SCREEN_RECT.size)


func after_test() -> void:
	_runner = null
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The model's job cards and what the score says of them: the Croissant opens, the Baguette counts
## 2 earlier items (its cap), the Iced bun glazes the Stale doughnut ×2; Bread has no job.
func test_the_model_records_the_job_cards() -> void:
	var model: PlanningModel = _model(GOOD_ROW)
	(
		assert_dict(model.batch_roles)
		. is_equal(
			{
				0: BatchRoleRule.Role.OPENER,
				2: BatchRoleRule.Role.BODY,
				3: BatchRoleRule.Role.GLAZE,
				4: BatchRoleRule.Role.CLOSER,
			}
		)
	)
	assert_dict(model.batch_counts).is_equal({2: 2})
	assert_dict(model.glazes).is_equal({4: 2})
	# An Iced bun that closes its batch glazes nothing.
	assert_dict(_model(["croissant", "bread", "iced_bun"]).glazes).is_empty()


## The caps stand at the batch's ends: the FIRST cap round the frame's left side at the first
## ticket, the LAST cap round its right side at the last, CAP_OUT outside the frame and onto the
## end ticket's outline only, CAP_RISE over the frame's top down to its foot; the tabs sit across
## the frame's foot under the end tickets, against their caps. Nothing of them covers another
## ticket, a ticket's text, chips, glyphs or price window, or leaves the screen.
func test_the_caps_stand_at_the_batch_ends() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, GOOD_ROW)
	var frame: BatchFrame = _layer(screen).frames()[0]
	var ends: BatchBookends = frame.bookends()
	assert_object(ends).is_not_null()
	var to_global: Transform2D = _layer(screen).get_global_transform()
	var outer: Rect2 = to_global * frame.frame_rect()
	var first: Rect2 = _ticket(screen, 0)
	var last: Rect2 = _ticket(screen, 4)
	assert_bool(ends.shows(BatchBookends.Cap.FIRST)).is_true()
	assert_bool(ends.shows(BatchBookends.Cap.LAST)).is_true()
	var first_cap: Rect2 = to_global * ends.cap_rect(BatchBookends.Cap.FIRST)
	var last_cap: Rect2 = to_global * ends.cap_rect(BatchBookends.Cap.LAST)
	assert_float(first_cap.position.x).is_equal(outer.position.x - BatchBookends.CAP_OUT)
	assert_float(last_cap.end.x).is_equal(outer.end.x + BatchBookends.CAP_OUT)
	for cap: Rect2 in [first_cap, last_cap]:
		assert_float(cap.size.x).is_equal(BatchBookends.CAP_WIDTH)
		assert_float(cap.position.y).is_equal(outer.position.y - BatchBookends.CAP_RISE)
		assert_float(cap.end.y).is_equal(outer.end.y)
		assert_bool(SCREEN_RECT.encloses(cap)).override_failure_message(str(cap)).is_true()
	# Each cap reaches onto its end ticket's outline, no further.
	assert_bool(first_cap.intersects(first)).is_true()
	assert_float(first_cap.end.x - first.position.x).is_less_equal(PriceSticker.OUTLINE)
	assert_bool(last_cap.intersects(last)).is_true()
	assert_float(last.end.x - last_cap.position.x).is_less_equal(PriceSticker.OUTLINE)
	var first_tab: Rect2 = to_global * ends.tab_rect(BatchBookends.Cap.FIRST)
	var last_tab: Rect2 = to_global * ends.tab_rect(BatchBookends.Cap.LAST)
	assert_bool(first_tab.intersects(first_cap)).is_true()
	assert_bool(last_tab.intersects(last_cap)).is_true()
	assert_float(first_tab.position.y).is_greater_equal(first.end.y - PriceSticker.OUTLINE)
	assert_float(last_tab.position.y).is_greater_equal(last.end.y - PriceSticker.OUTLINE)
	assert_float(first_tab.position.x).is_greater_equal(first_cap.position.x)
	assert_float(last_tab.end.x).is_less_equal(last_cap.end.x)
	var parts: Array[Rect2] = [first_cap, last_cap, first_tab, last_tab]
	for part: Rect2 in parts:
		assert_bool(SCREEN_RECT.encloses(part)).override_failure_message(str(part)).is_true()
		for slot: int in range(1, 4):
			assert_bool(part.intersects(_ticket(screen, slot))).is_false()
		assert_bool(part.intersects(_ticket(screen, 5))).is_false()
		for clear: Rect2 in _keep_clear(screen):
			(
				assert_bool(part.intersects(clear))
				. override_failure_message("%s over %s" % [part, clear])
				. is_false()
			)


## The icing drip pours over the LAST cap (from its top, DRIP_IN over its left side) when an Iced
## bun glazes the batch's last item, onto the last ticket's right half at most, clear of every other
## ticket and of every ticket's text, chips, glyphs and price window; with no Iced bun, or one that
## closes the batch itself, there is none.
func test_the_drip_shows_only_with_an_iced_bun_on_the_last() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, GOOD_ROW)
	var ends: BatchBookends = _layer(screen).frames()[0].bookends()
	assert_bool(ends.has_drip()).is_true()
	var cap: Rect2 = ends.cap_rect(BatchBookends.Cap.LAST)
	var drip: Rect2 = ends.drip_rect()
	assert_float(drip.position.x).is_equal(cap.position.x - BatchBookends.DRIP_IN)
	assert_float(drip.position.y).is_equal(cap.position.y)
	assert_float(drip.end.y).is_less(cap.end.y)
	assert_bool(drip.intersects(ends.cap_rect(BatchBookends.Cap.FIRST))).is_false()
	var on_screen: Rect2 = _layer(screen).get_global_transform() * drip
	var last: Rect2 = _ticket(screen, 4)
	assert_bool(SCREEN_RECT.encloses(on_screen)).override_failure_message(str(on_screen)).is_true()
	assert_float(on_screen.position.x).is_greater(last.get_center().x)
	for slot: int in [0, 1, 2, 3, 5]:
		assert_bool(on_screen.intersects(_ticket(screen, slot))).is_false()
	for clear: Rect2 in _keep_clear(screen):
		(
			assert_bool(on_screen.intersects(clear))
			. override_failure_message("drip %s over %s" % [on_screen, clear])
			. is_false()
		)
	for row: Array[String] in [
		["croissant", "bread", "baguette", "stale_doughnut"] as Array[String],
		["croissant", "bread", "iced_bun"] as Array[String],
	]:
		var plain: ShiftScreen = await _screen()
		await _place(plain, row)
		var plain_ends: BatchBookends = _layer(plain).frames()[0].bookends()
		assert_bool(plain_ends.shows(BatchBookends.Cap.LAST)).is_true()
		assert_bool(plain_ends.has_drip()).override_failure_message(str(row)).is_false()
		assert_bool(plain_ends.drip_rect().has_area()).is_false()


## Hovering a job card lights the cap it reads: the Croissant the FIRST cap, the Stale doughnut the
## LAST; a Baguette's fill runs along the frame's foot band to its ticket with its count's note; an
## Iced bun lights the LAST cap and draws its dashed line from its ticket to it. A Croissant out of
## place turns the FIRST cap tomato with its note. Leaving puts them back; an item with no job (the
## Bread in the batch, the Banana outside it) lights nothing and shows no note.
func test_hovering_a_job_card_lights_its_cap() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, GOOD_ROW)
	var layer: PlanningLayer = _layer(screen)
	var ends: BatchBookends = layer.frames()[0].bookends()
	var to_global: Transform2D = layer.get_global_transform()
	_hover(layer, 0)
	assert_int(ends.look(BatchBookends.Cap.FIRST)).is_equal(BatchBookends.Look.LIT)
	assert_int(ends.look(BatchBookends.Cap.LAST)).is_equal(BatchBookends.Look.CALM)
	_hover(layer, 4)
	assert_int(ends.look(BatchBookends.Cap.FIRST)).is_equal(BatchBookends.Look.CALM)
	assert_int(ends.look(BatchBookends.Cap.LAST)).is_equal(BatchBookends.Look.LIT)
	_hover(layer, 2)
	await _seconds(BatchBookends.PLAN_FILL_S + 0.1)
	var fill: Rect2 = to_global * ends.fill_rect()
	var outer: Rect2 = to_global * layer.frames()[0].frame_rect()
	assert_float(fill.position.x).is_equal(outer.position.x + BatchBookends.FILL_LEFT)
	assert_float(fill.end.x).is_equal(_ticket(screen, 2).get_center().x)
	assert_float(fill.position.y).is_equal(outer.end.y - BatchBookends.FILL_UP)
	assert_array(Array(ends.note_texts())).is_equal(["2 EARLIER"])
	_hover(layer, 3)
	assert_int(ends.look(BatchBookends.Cap.LAST)).is_equal(BatchBookends.Look.LIT)
	assert_bool(ends.fill_rect().has_area()).is_false()
	var dash: Rect2 = to_global * ends.dash_rect()
	assert_float(dash.position.x).is_equal(_ticket(screen, 3).get_center().x)
	assert_float(dash.end.x).is_equal(outer.end.x)
	assert_float(dash.position.y).is_greater_equal(outer.end.y)
	assert_array(Array(ends.note_texts())).is_equal(["×2 LAST"])
	_hover(layer, -1)
	assert_int(ends.look(BatchBookends.Cap.LAST)).is_equal(BatchBookends.Look.CALM)
	assert_bool(ends.dash_rect().has_area()).is_false()
	assert_array(Array(ends.note_texts())).is_empty()
	for slot: int in [1, 5]:
		_hover(layer, slot)
		await _seconds(BatchBookends.LOOK_S + 0.05)
		for cap: BatchBookends.Cap in [BatchBookends.Cap.FIRST, BatchBookends.Cap.LAST]:
			var look_now: int = ends.look(cap)
			assert_int(look_now).override_failure_message(str(slot)).is_equal(
				BatchBookends.Look.CALM
			)
			assert_float(ends._glows[cap]).is_equal(0.0)
		assert_array(Array(ends.note_texts())).is_empty()
		assert_bool(ends.fill_rect().has_area()).is_false()
		assert_bool(ends.dash_rect().has_area()).is_false()
	var wrong: ShiftScreen = await _screen()
	await _place(wrong, WRONG_ROW)
	var wrong_ends: BatchBookends = _layer(wrong).frames()[0].bookends()
	_hover(_layer(wrong), 1)
	assert_int(wrong_ends.look(BatchBookends.Cap.FIRST)).is_equal(BatchBookends.Look.BAD)
	assert_array(Array(wrong_ends.note_texts())).is_equal(["NOT FIRST"])


## The count keeps the frame: a job card's step lights its cap (the Croissant armed, the FIRST cap;
## then the LAST as the spark lands), and with the batch's first item bagged the frame binds the
## tickets left, wearing no FIRST cap.
func test_the_count_plays_on_the_caps() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, GOOD_ROW)
	screen._on_checkout_pressed()
	await _frames(2)
	var frame: BatchFrame = _layer(screen).frames()[0]
	var ends: BatchBookends = frame.bookends()
	var armed: ScoreStep = ScoreStep.new()
	armed.step_type = ScoreStep.StepType.EFFECT_ARMED
	armed.slot = 0
	armed.source_slot = 0
	frame.fire(armed)
	await _frames(2)
	assert_int(ends.look(BatchBookends.Cap.FIRST)).is_equal(BatchBookends.Look.LIT)
	await _seconds(BatchBookends.SPARK_LAND + 0.1)
	assert_int(ends.look(BatchBookends.Cap.LAST)).is_equal(BatchBookends.Look.LIT)
	# A bagged first item: the frame binds the rest.
	var frames: BatchFrames = BatchFrames.new()
	add_child(frames)
	frames.show_batches([PackedInt32Array([0, 1, 2])], [], _model(["croissant", "bread", "bread"]))
	frames.count()
	var second: Rect2 = Rect2(200, 100, PriceSticker.SIZE.x, PriceSticker.SIZE.y)
	var third: Rect2 = Rect2(320, 100, PriceSticker.SIZE.x, PriceSticker.SIZE.y)
	frames.lay_out({1: second, 2: third})
	var counted: BatchFrame = frames.frames()[0]
	assert_bool(counted.visible).is_true()
	assert_float(counted.frame_rect().position.x).is_equal(second.position.x - BatchFrame.RING)
	assert_bool(counted.bookends().shows(BatchBookends.Cap.FIRST)).is_false()
	assert_bool(counted.bookends().shows(BatchBookends.Cap.LAST)).is_true()
	frames.queue_free()


## A job card WASTED at its place turns its cap tomato with its note: a Stale doughnut that is not
## the batch's last ("NOT LAST" on the LAST cap), an Iced bun that is ("IS LAST"), a Baguette with
## no earlier item ("0 EARLIER" on the FIRST cap).
func test_a_wasted_job_card_turns_its_cap_tomato(
	row: Array,
	slot: int,
	cap: int,
	note: String,
	_test_parameters := [
		[["croissant", "stale_doughnut", "bread"], 1, BatchBookends.Cap.LAST, "NOT LAST"],
		[["croissant", "bread", "iced_bun"], 2, BatchBookends.Cap.LAST, "IS LAST"],
		[["baguette", "bread", "bread"], 0, BatchBookends.Cap.FIRST, "0 EARLIER"],
	]
) -> void:
	var ids: Array[String] = []
	ids.assign(row)
	var frames: BatchFrames = _standalone(ids)
	frames.lay_out(_rects(range(ids.size())))
	var ends: BatchBookends = frames.frames()[0].bookends()
	var other: int = (
		BatchBookends.Cap.FIRST if cap == BatchBookends.Cap.LAST else BatchBookends.Cap.LAST
	)
	assert_bool(ends.shows(cap as BatchBookends.Cap)).is_true()
	frames.focus(slot)
	assert_int(ends.look(cap as BatchBookends.Cap)).is_equal(BatchBookends.Look.BAD)
	assert_int(ends.look(other as BatchBookends.Cap)).is_equal(BatchBookends.Look.CALM)
	assert_array(Array(ends.note_texts())).is_equal([note])
	frames.focus(-1)
	assert_int(ends.look(cap as BatchBookends.Cap)).is_equal(BatchBookends.Look.CALM)


## The real count: BeltRide plays each job card's real step on the frame (the Baguette's fill, the
## closer's count, the glaze's slam), and as the items ride into the bag the frame binds the
## batch's tickets still on the belt: its sides RING outside the first and last of them, the FIRST
## cap gone with the batch's first ticket. Every pop shown stands over a ticket on the belt or, the
## bagged items' counter, at the frame's left end; no two share a place.
func test_the_real_count_plays_on_the_caps() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, GOOD_ROW)
	var layer: PlanningLayer = _layer(screen)
	var to_global: Transform2D = layer.get_global_transform()
	var failures: Array[String] = []
	var filled: Array[bool] = [false]
	var ticks: Dictionary[String, bool] = {}
	var lit_last: Array[bool] = [false]
	screen._on_checkout_pressed()
	while screen._counting:
		await get_tree().process_frame
		var frame: BatchFrame = layer.frames()[0]
		var on_belt: Array[int] = []
		for slot: int in range(5):
			if not screen._ride.is_bagged(slot) and _item(screen, slot).is_visible_in_tree():
				on_belt.append(slot)
		if on_belt.is_empty() or not frame.visible:
			continue
		var ends: BatchBookends = frame.bookends()
		var outer: Rect2 = to_global * frame.frame_rect()
		var first: Rect2 = _ticket(screen, on_belt[0])
		var last: Rect2 = _ticket(screen, on_belt[-1])
		if (
			absf(outer.position.x - (first.position.x - BatchFrame.RING)) > 0.5
			or absf(outer.end.x - (last.end.x + BatchFrame.RING)) > 0.5
		):
			failures.append("frame %s round %s" % [outer, on_belt])
		if ends.shows(BatchBookends.Cap.FIRST) != (on_belt[0] == 0):
			failures.append("FIRST cap with %s on the belt" % [on_belt])
		filled[0] = filled[0] or ends.fill_rect().has_area()
		lit_last[0] = lit_last[0] or ends.look(BatchBookends.Cap.LAST) == BatchBookends.Look.LIT
		var places: Dictionary[float, String] = {}
		for index: int in range(ends._pop_texts.size()):
			var life: float = ends._pop_lives[index]
			if life <= 0.0 or life >= 1.0 or ends._pop_factors[index]:
				continue
			var x: float = ends._pop_xs[index]
			var text: String = ends._pop_texts[index]
			if places.has(x):
				failures.append("pops %s and %s at %s" % [places[x], text, x])
			places[x] = text
			var over: int = -1
			for slot: int in on_belt:
				if absf(_ticket(screen, slot).get_center().x - (outer.position.x + x)) < 0.5:
					over = slot
			if over < 0:
				ticks[text] = true
				if x > ChainFrame.plate_size(text).x:
					failures.append("counter %s at %s, not the left end" % [text, x])
	assert_array(failures).is_empty()
	assert_bool(filled[0]).is_true()
	assert_bool(lit_last[0]).is_true()
	# The Baguette's earlier two and the closer's first four were bagged: they ticked.
	for text: String in ["2", "4"]:
		assert_bool(ticks.has(text)).override_failure_message(str(ticks)).is_true()


## The bagged items' pops tick in one counter at the frame's left end (each number replacing the
## last), the item still on the belt pops over its ticket; every pop waits its turn (none dropped
## before it starts). The Baguette's fill runs over what's left of the frame, to its ticket.
func test_the_bagged_items_tick_in_one_counter() -> void:
	var frames: BatchFrames = _standalone(["croissant", "bread", "baguette", "stale_doughnut"])
	frames.count()
	frames.lay_out(_rects([2, 3]))
	var frame: BatchFrame = frames.frames()[0]
	var ends: BatchBookends = frame.bookends()
	frame.fire(_step(ScoreStep.StepType.FLAT, 2))
	await _seconds(BatchBookends.COUNT_FILL_S)
	var fill: Rect2 = ends.fill_rect()
	assert_float(fill.position.x).is_equal(frame.frame_rect().position.x + BatchBookends.FILL_LEFT)
	assert_float(fill.end.x).is_less_equal(_rects([2])[2].get_center().x)
	await _seconds(BatchBookends.POP_S + 0.2)
	frames.lay_out(_rects([3]))
	frame.fire(_step(ScoreStep.StepType.FLAT, 3))
	# Two pops: the 4 over the doughnut's ticket and the counter for 1 to 3, both kept waiting.
	assert_array(Array(ends._pop_texts)).is_equal(["4", "1"])
	await _seconds(BatchBookends.CLOSER_POP_GAP * 2.0 + 0.05)
	assert_str(ends._pop_texts[1]).is_equal("3")
	assert_float(ends._pop_xs[1]).is_equal(ChainFrame.plate_size("3").x / 2.0)
	var ticket: Rect2 = _rects([3])[3]
	assert_float(ends._pop_xs[0] + frame.frame_rect().position.x).is_equal(ticket.get_center().x)
	# Every number pops in turn when all the items are on the belt: none is dropped.
	var whole: BatchFrames = _standalone(["croissant", "bread", "stale_doughnut"])
	whole.lay_out(_rects([0, 1, 2]))
	var whole_ends: BatchBookends = whole.frames()[0].bookends()
	whole.fire(_step(ScoreStep.StepType.FLAT, 2))
	assert_array(Array(whole_ends._pop_texts)).is_equal(["1", "2", "3"])


## A batch a Shelf swap splits over two frames (Croissant | Banana, Shelf swap | Stale doughnut)
## plays each beat once: the opener's spark on the frame with the FIRST cap, the closer's spark on
## the frame with the LAST; the closer's count pops over each ticket on its own frame (none piled at
## a frame's end). An Iced bun on the first frame (Iced bun | Banana, Shelf swap | Bread) draws its
## dashed line (hover and count) only on the frame with the LAST cap, from its left end.
func test_a_split_batch_plays_each_beat_once() -> void:
	var row: Array[String] = ["croissant", "banana", "shelf_swap", "stale_doughnut"]
	var frames: BatchFrames = _standalone(row)
	var tickets: Dictionary[int, Rect2] = _rects(range(row.size()))
	frames.lay_out(tickets)
	var split: Array[BatchFrame] = frames.frames()
	assert_int(split.size()).is_equal(2)
	assert_array(Array(split[1].batch)).is_equal([0, 3])
	var left: BatchBookends = split[0].bookends()
	var right: BatchBookends = split[1].bookends()
	assert_bool(left.shows(BatchBookends.Cap.FIRST)).is_true()
	assert_bool(left.shows(BatchBookends.Cap.LAST)).is_false()
	assert_bool(right.shows(BatchBookends.Cap.FIRST)).is_false()
	assert_bool(right.shows(BatchBookends.Cap.LAST)).is_true()
	frames.fire(_step(ScoreStep.StepType.EFFECT_ARMED, 0))
	await _frames(2)
	assert_bool(is_nan(left._spark)).is_false()
	assert_bool(is_nan(right._spark)).is_true()
	await _seconds(BatchBookends.SPARK_LAND + 0.1)
	frames.fire(_step(ScoreStep.StepType.FLAT, 3))
	await _frames(2)
	assert_bool(is_nan(left._spark)).is_true()
	assert_bool(is_nan(right._spark)).is_false()
	var all_ends: Array[BatchBookends] = [left, right]
	var slots: Array[int] = [0, 3]
	for side: int in range(2):
		var ends: BatchBookends = all_ends[side]
		var origin: float = split[side].frame_rect().position.x
		assert_array(Array(ends._pop_texts)).is_equal([str(side + 1)])
		var x: float = ends._pop_xs[0] + origin
		assert_float(x).is_equal(tickets[slots[side]].get_center().x)
	var glazed: BatchFrames = _standalone(["iced_bun", "banana", "shelf_swap", "bread"])
	glazed.lay_out(tickets)
	var glazed_split: Array[BatchFrame] = glazed.frames()
	assert_int(glazed_split.size()).is_equal(2)
	var bun_side: BatchBookends = glazed_split[0].bookends()
	var last_side: BatchBookends = glazed_split[1].bookends()
	assert_bool(last_side.has_drip()).is_true()
	glazed.focus(0)
	assert_bool(bun_side.dash_rect().has_area()).is_false()
	var outer: Rect2 = glazed_split[1].frame_rect()
	assert_float(last_side.dash_rect().position.x).is_equal(outer.position.x)
	assert_float(last_side.dash_rect().end.x).is_equal(outer.end.x)
	glazed.focus(-1)
	glazed.fire(_step(ScoreStep.StepType.EFFECT_ARMED, 0))
	await _frames(1)
	assert_bool(bun_side.dash_rect().has_area()).is_false()
	assert_bool(last_side.dash_rect().has_area()).is_true()


## A drag's ghost at the batch's first or last place has no ticket, but the frame keeps that end's
## cap (and the drip) at its own end.
func test_a_ghost_at_a_batch_end_keeps_its_cap() -> void:
	var frames: BatchFrames = _standalone(["croissant", "iced_bun", "bread"])
	frames.lay_out(_rects([1, 2]), PackedInt32Array([0]))
	var frame: BatchFrame = frames.frames()[0]
	var ends: BatchBookends = frame.bookends()
	assert_bool(frame.visible).is_true()
	assert_bool(ends.shows(BatchBookends.Cap.FIRST)).is_true()
	var first_cap: Rect2 = ends.cap_rect(BatchBookends.Cap.FIRST)
	var outer: Rect2 = frame.frame_rect()
	assert_float(first_cap.position.x).is_equal(outer.position.x - BatchBookends.CAP_OUT)
	frames.lay_out(_rects([0, 1]), PackedInt32Array([2]))
	outer = frame.frame_rect()
	assert_bool(ends.shows(BatchBookends.Cap.FIRST)).is_true()
	assert_bool(ends.shows(BatchBookends.Cap.LAST)).is_true()
	var last_cap: Rect2 = ends.cap_rect(BatchBookends.Cap.LAST)
	assert_float(last_cap.end.x).is_equal(outer.end.x + BatchBookends.CAP_OUT)
	assert_bool(ends.has_drip()).is_true()
	assert_bool(ends.drip_rect().intersects(last_cap)).is_true()


## Reduced motion: a hover lights the cap at once, its glow and enlarged tab included, and leaving
## puts them back at once. A hover leaving mid drip re-run leaves the drip whole.
func test_a_hover_ends_cleanly() -> void:
	var still: BatchFrames = _standalone(["croissant", "bread", "stale_doughnut"], true)
	still.lay_out(_rects([0, 1, 2]))
	var still_ends: BatchBookends = still.frames()[0].bookends()
	still.focus(0)
	assert_int(still_ends.look(BatchBookends.Cap.FIRST)).is_equal(BatchBookends.Look.LIT)
	assert_float(still_ends._glows[BatchBookends.Cap.FIRST]).is_equal(1.0)
	var lit_scale: float = still_ends._tab_scales[BatchBookends.Cap.FIRST]
	assert_float(lit_scale).is_equal(BatchBookends.TAB_LIT_SCALE)
	still.focus(-1)
	assert_float(still_ends._glows[BatchBookends.Cap.FIRST]).is_equal(0.0)
	assert_float(still_ends._tab_scales[BatchBookends.Cap.FIRST]).is_equal(1.0)
	var glazed: BatchFrames = _standalone(["croissant", "iced_bun", "bread"])
	glazed.lay_out(_rects([0, 1, 2]))
	var ends: BatchBookends = glazed.frames()[0].bookends()
	glazed.focus(1)
	await _frames(2)
	assert_float(ends._drip_share).is_less(1.0)
	glazed.focus(-1)
	assert_float(ends._drip_share).is_equal(1.0)


## A Produce chain's frame wears no bookends.
func test_a_chain_frame_has_no_bookends() -> void:
	var chain: ChainFrame = ChainFrame.new(PackedInt32Array([0, 1]))
	add_child(chain)
	var tickets: Array[Rect2] = [
		Rect2(200, 100, PriceSticker.SIZE.x, PriceSticker.SIZE.y),
		Rect2(320, 100, PriceSticker.SIZE.x, PriceSticker.SIZE.y),
	]
	chain.lay_out(tickets, 400.0)
	assert_object(chain.bookends()).is_null()
	chain.queue_free()


## Batch frames on their own (no screen), reading `row`'s model, each run's frame its batch's.
func _standalone(row: Array[String], reduced: bool = false) -> BatchFrames:
	var model: PlanningModel = _model(row)
	var frames: BatchFrames = auto_free(BatchFrames.new()) as BatchFrames
	frames.reduced_motion = reduced
	add_child(frames)
	var batches: Array[PackedInt32Array] = []
	for index: int in range(model.runs.size()):
		batches.append(model.batches[model.run_batch[index]])
	frames.show_batches(model.runs, batches, model)
	return frames


## A ticket's rect for each of `slots`, 120 px apart along a row.
static func _rects(slots: Array) -> Dictionary[int, Rect2]:
	var rects: Dictionary[int, Rect2] = {}
	for slot: int in slots:
		rects[slot] = Rect2(100 + slot * 120, 100, PriceSticker.SIZE.x, PriceSticker.SIZE.y)
	return rects


## A job card's step of `type` at `slot`, its own.
static func _step(type: ScoreStep.StepType, slot: int) -> ScoreStep:
	var step: ScoreStep = ScoreStep.new()
	step.step_type = type
	step.source_kind = ScoreStep.SourceKind.CARD
	step.slot = slot
	step.source_slot = slot
	return step


## What a frame's part must keep clear of on every ticket: its text, chips, glyphs and window.
func _keep_clear(screen: ShiftScreen) -> Array[Rect2]:
	var keep_clear: Array[Rect2] = []
	for slot: int in range(screen._row_views.size()):
		var sticker: PriceSticker = _item(screen, slot).sticker()
		var to_sticker: Transform2D = sticker.get_global_transform()
		var text: Rect2 = sticker.summary_text_rect()
		if text.has_area():
			keep_clear.append(to_sticker * text)
		for chip: KeywordChip in sticker.summary().keywords():
			keep_clear.append(chip.get_global_rect())
		for glyph: FamilyGlyph in sticker.glyphs():
			if glyph.visible:
				keep_clear.append(to_sticker * glyph.rim_rect())
		keep_clear.append(sticker.window().get_global_rect())
	return keep_clear


## The planning layer's focus on `slot`'s item (-1: none), as a hover gives it.
static func _hover(layer: PlanningLayer, slot: int) -> void:
	var lit: Callable = func(_slot: int, _spec: StickerSpec) -> bool: return true
	layer.apply_focus(lit if slot >= 0 else Callable(), PackedInt32Array(), {}, 0.0, slot)


func _model(row: Array[String]) -> PlanningModel:
	var cards: Array[CardDefinition] = []
	var instances: Array[CardInstance] = []
	for id: String in row:
		cards.append(load(CARDS % id) as CardDefinition)
		instances.append(CardInstance.new(cards[-1], instances.size() + 1))
	var result: ScoreResult = Scoring.score(instances)
	var none_upgrades: Array[UpgradeDefinition] = []
	var none_events: Array[InspectionDefinition] = []
	return PlanningModel.build(result, cards, none_upgrades, none_events, null)


## `slot`'s ticket's global rect.
static func _ticket(screen: ShiftScreen, slot: int) -> Rect2:
	var sticker: PriceSticker = _item(screen, slot).sticker()
	return sticker.get_global_transform() * Rect2(Vector2.ZERO, sticker.size)


static func _layer(screen: ShiftScreen) -> PlanningLayer:
	return screen._stage.planning_layer


static func _item(screen: ShiftScreen, slot: int) -> ItemView:
	return screen._row_views[slot] as ItemView


## A new run's screen: an earlier screen's run save in the test folder is removed first.
func _screen() -> ShiftScreen:
	if FileAccess.file_exists(_folder.path_join(SaveService.RUN_FILE)):
		DirAccess.remove_absolute(_folder.path_join(SaveService.RUN_FILE))
	_runner = scene_runner(SCREEN)
	var screen: ShiftScreen = _runner.scene()
	await _frames(2)
	return screen


## Places each card at the row's end as the player does: picked from the hand, then its slot
## clicked.
func _place(screen: ShiftScreen, ids: Array[String]) -> void:
	for id: String in ids:
		screen._debug.add_card(id)
		screen._on_hand_card_clicked(_view_for(screen, screen.run.hand()[-1]))
		screen._on_slot_input(_left_click(), screen.run.row.size())
	assert_int(screen.run.row.size()).is_equal(ids.size())
	await _frames(3)


func _frames(count: int) -> void:
	for _frame: int in range(count):
		await get_tree().process_frame


func _seconds(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


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
