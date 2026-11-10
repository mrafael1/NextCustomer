extends GdUnitTestSuite
## Produce chains on the belt (#128 Produce links, the approved Linked frame:
## docs/art/mockups/produce_chain_128.html's 'rings'). The model holds every chain of the preview
## (plain Banana pairs too) in runs, with each chain's FEED and TALLY helpers at their places and
## its knots' factors, all from the score. On the real shift screen each chain gets one frame like
## the Bakery's (BatchFrame) round exactly its tickets, inside the screen and over the counter
## edge, running on behind each pinned pay tag; two interlocked rings cross each gap between its
## tickets, clear of every ticket's text, chips, glyphs and plain tags, the gaps beside a Lemon
## knot lemon yellow with the knot's factor on a plate under the Lemon; a Strawberries at its place
## hangs a clasp through the frame's left side, a Wonky carrot at its place one through its right
## side, and a helper out of place none. Hovering a CHAIN chip lights its chain's frame; a drag
## lays the frame out for its landing; the count shows none. A narrow gap (a scaled 8-slot row's)
## gets one jump ring. The real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const CARDS := "res://data/cards/%s.tres"
const SCREEN_RECT := Rect2(0, 0, 1280, 720)
## The approved capture rows: every job in place; then the Lemon and the Strawberries out of
## place round a plain pair; then two chains split by a Bread, the Wonky carrot after the second.
const GOOD_ROW: Array[String] = [
	"strawberries", "banana", "banana", "lemon", "banana", "wonky_carrot"
]
const LOOSE_ROW: Array[String] = ["lemon", "banana", "banana", "strawberries"]
const SPLIT_ROW: Array[String] = ["banana", "banana", "bread", "banana", "banana", "wonky_carrot"]

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


## The model's chains and their parts come from the score: the runs, the helpers at their places
## (-1 out of place or none) and the knots' factors (a GOLDEN Lemon's 3).
func test_the_model_holds_each_chains_parts(
	row: String,
	runs: Array,
	feeds: Array,
	tallies: Array,
	knots: Dictionary,
	_test_parameters := [
		["strawberries,banana,banana,lemon,banana,wonky_carrot", [[1, 2, 3, 4]], [0], [5], {3: 2}],
		["lemon,banana,banana,strawberries", [[1, 2]], [-1], [-1], {}],
		["banana,banana,bread,banana,banana,wonky_carrot", [[0, 1], [3, 4]], [-1, -1], [-1, 5], {}],
		["banana,lemon_golden,banana", [[0, 1, 2]], [-1], [-1], {1: 3}],
		["banana,banana", [[0, 1]], [-1], [-1], {}],
		["banana,bread", [], [], [], {}],
	]
) -> void:
	var model: PlanningModel = _model(row)
	var shown: Array = []
	for run: PackedInt32Array in model.chain_runs:
		shown.append(Array(run))
	assert_array(shown).is_equal(runs)
	assert_int(model.run_chain.size()).is_equal(model.chain_runs.size())
	assert_array(Array(model.chain_feeds)).is_equal(feeds)
	assert_array(Array(model.chain_tallies)).is_equal(tallies)
	assert_dict(model.knot_factors).is_equal(knots)


## The good row: one frame round exactly the four chain tickets (the Lemon's among them), its
## rings in the three gaps (the two beside the Lemon lemon yellow), a clasp through each side, the
## Lemon's "×2" plate (its factor from the score) on the frame's foot under the Lemon's ticket.
func test_the_frame_links_exactly_the_chain() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, GOOD_ROW)
	var layer: PlanningLayer = _layer(screen)
	assert_array(layer.frames()).is_empty()
	var frames: Array[ChainFrame] = _chain_frames(screen)
	assert_int(frames.size()).is_equal(1)
	var frame: ChainFrame = frames[0]
	assert_array(Array(frame.slots)).is_equal([1, 2, 3, 4])
	assert_bool(frame.visible).is_true()
	_assert_frame_geometry(screen, frame)
	assert_array(frame.knot_links()).is_equal([false, true, true])
	assert_bool(frame.is_fed()).is_true()
	assert_bool(frame.is_tallied()).is_true()
	_assert_clasps(screen, frame, true, true)
	var factor: int = layer.model().knot_factors[3]
	assert_int(factor).is_equal(2)
	assert_array(Array(frame.plate_texts())).is_equal([ChainFrame.PLATE_TEXT % factor])
	var plate: Rect2 = layer.get_global_transform() * frame.plate_rects()[0]
	var outer: Rect2 = layer.get_global_transform() * frame.frame_rect()
	var lemon: Rect2 = _ticket(screen, 3)
	assert_float(plate.end.y).is_equal(outer.end.y)
	assert_float(plate.position.x).is_greater_equal(lemon.position.x)
	assert_float(plate.end.x).is_less_equal(lemon.end.x)
	assert_bool(outer.encloses(plate)).is_true()
	# Calm: Produce green, the knot's parts lemon.
	assert_that(frame.paint_color(BatchFrame.Paint.FACE)).is_equal(Palette.GREEN_LIGHT)
	assert_that(frame.paint_color(BatchFrame.Paint.KNOT_FACE)).is_equal(ChainFrame.CALM_LEMON)
	assert_that(frame.paint_color(BatchFrame.Paint.KNOT_FACE)).is_not_equal(BatchFrame.CALM_MUSTARD)
	assert_that(frame.paint_color(BatchFrame.Paint.KNOT_FACE)).is_not_equal(BatchFrame.CALM_LIGHT)
	_assert_plate_cells(frame, 0)
	for slot: int in range(GOOD_ROW.size()):
		var sticker: PriceSticker = _item(screen, slot).sticker()
		for chip: KeywordChip in sticker.summary().keywords():
			assert_bool(chip.is_wasted()).is_false()


## A GOLDEN Lemon's plate reads its own factor, ×3.
func test_a_golden_lemons_plate_reads_its_factor() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["banana", "lemon_golden", "banana"])
	var frame: ChainFrame = _chain_frames(screen)[0]
	var factor: int = _layer(screen).model().knot_factors[1]
	assert_int(factor).is_equal(3)
	assert_array(Array(frame.plate_texts())).is_equal([ChainFrame.PLATE_TEXT % factor])
	_assert_plate_cells(frame, 0)
	assert_array(frame.knot_links()).is_equal([true, true])
	_assert_frame_geometry(screen, frame)


## Helpers out of place hang no clasp: the plain pair between the loose Lemon and the late
## Strawberries is framed alone; of two chains split by a Bread only the second, the Wonky
## carrot's, hangs a clasp, through its right side.
func test_a_helper_out_of_place_hangs_no_clasp() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, LOOSE_ROW)
	var loose: Array[ChainFrame] = _chain_frames(screen)
	assert_int(loose.size()).is_equal(1)
	assert_array(Array(loose[0].slots)).is_equal([1, 2])
	assert_array(loose[0].clasp_rects()).is_empty()
	assert_array(loose[0].plate_rects()).is_empty()
	_assert_frame_geometry(screen, loose[0])
	_runner = null
	screen = await _screen()
	await _place(screen, SPLIT_ROW)
	var split: Array[ChainFrame] = _chain_frames(screen)
	assert_int(split.size()).is_equal(2)
	assert_array(Array(split[0].slots)).is_equal([0, 1])
	assert_array(Array(split[1].slots)).is_equal([3, 4])
	_assert_clasps(screen, split[0], false, false)
	_assert_clasps(screen, split[1], false, true)
	for frame: ChainFrame in split:
		_assert_frame_geometry(screen, frame)
	assert_bool(split[0].frame_rect().intersects(split[1].frame_rect())).is_false()


## Hovering a CHAIN chip lights its chain's frame: a Banana's, the Strawberries' and the Wonky
## carrot's at their places; leaving puts it back. Lit, the green and lemon parts turn gold.
func test_hovering_a_chain_chip_lights_its_frame() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, GOOD_ROW)
	var tips: GlyphTips = screen._glyph_tips
	var frame: ChainFrame = _chain_frames(screen)[0]
	for slot: int in [0, 2, 3, 5]:
		var chip: KeywordChip = _item(screen, slot).sticker().summary().keywords()[0]
		assert_str(chip.keyword).is_equal(CardText.CHAIN_WORD)
		tips.point_at(chip.get_global_rect().get_center())
		tips.show_tip(chip)
		await _frames(1)
		assert_bool(frame.is_lit()).override_failure_message(str(slot)).is_true()
		assert_that(frame.paint_color(BatchFrame.Paint.FACE)).is_equal(Palette.GOLD)
		assert_that(frame.paint_color(BatchFrame.Paint.KNOT_FACE)).is_equal(Palette.GOLD)
		tips.hide_tip()
		await _frames(1)
		assert_bool(frame.is_lit()).is_false()
	assert_that(frame.paint_color(BatchFrame.Paint.FACE)).is_equal(Palette.GREEN_LIGHT)


## A drag lays the frame out for its landing, live: a Banana landing after the pair joins the
## chain, which stays framed round the pair's tickets (the ghost has none), its clasp-free sides
## RING outside them.
func test_a_drag_lays_out_the_frame_for_its_landing() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["banana", "banana", "bread"])
	assert_int(_chain_frames(screen).size()).is_equal(1)
	screen._debug.add_card("banana")
	var banana: CardInstance = screen.run.hand()[-1]
	screen._on_hand_card_clicked(_view_for(screen, banana))
	var to_global: Transform2D = _layer(screen).get_global_transform()
	_move(screen, _slot_center(screen, 2))
	await _frames(2)
	assert_int(screen._drag.hovered_slot()).is_equal(2)
	var joined: Array[ChainFrame] = _chain_frames(screen)
	assert_int(joined.size()).is_equal(1)
	assert_array(Array(joined[0].slots)).is_equal([0, 1, 2])
	assert_bool(joined[0].visible).is_true()
	var outer: Rect2 = to_global * joined[0].frame_rect()
	assert_float(outer.position.x).is_equal(_ticket(screen, 0).position.x - BatchFrame.RING)
	assert_float(outer.end.x).is_equal(_ticket(screen, 1).end.x + BatchFrame.RING)
	assert_float(outer.end.y).is_less_equal(BatchFrames.FOOT_Y)
	assert_array(joined[0].pairs()).is_equal([true])


## A drag's ghost landing inside a chain has no ticket: the gap across it gets no rings (the
## other gaps keep theirs), and the helpers at their places keep their clasps on the frame's sides.
func test_a_ghost_inside_a_chain_breaks_no_part() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["strawberries", "banana", "banana", "banana", "wonky_carrot"])
	screen._debug.add_card("banana")
	var banana: CardInstance = screen.run.hand()[-1]
	screen._on_hand_card_clicked(_view_for(screen, banana))
	_move(screen, _slot_center(screen, 2))
	await _frames(2)
	assert_int(screen._drag.hovered_slot()).is_equal(2)
	var frames: Array[ChainFrame] = _chain_frames(screen)
	assert_int(frames.size()).is_equal(1)
	var frame: ChainFrame = frames[0]
	assert_array(Array(frame.slots)).is_equal([1, 2, 3, 4])
	# Tickets 1, 3 and 4 shown (the belt's views 1, 2 and 3): the 1-3 gap is the ghost's, only
	# 3-4 is linked, its pair in the gap between views 2 and 3.
	assert_array(frame.pairs()).is_equal([true])
	var rings: Array[Rect2] = frame.link_rects()
	var to_global: Transform2D = _layer(screen).get_global_transform()
	var middle: float = (_ticket(screen, 2).end.x + _ticket(screen, 3).position.x) / 2.0
	var pair: Rect2 = (to_global * rings[0]).merge(to_global * rings[1])
	assert_float(absf(pair.get_center().x - middle)).is_less_equal(1.0)
	assert_bool(frame.is_fed()).is_true()
	assert_bool(frame.is_tallied()).is_true()
	assert_int(frame.clasp_rects().size()).is_equal(2)
	_assert_crossings(frame)


## The CHECKOUT click takes every chain frame off for the count.
func test_the_count_shows_no_chain_frame() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, GOOD_ROW)
	assert_array(_chain_frames(screen)).is_not_empty()
	screen._on_checkout_pressed()
	await _frames(2)
	assert_array(_chain_frames(screen)).is_empty()
	for part: Control in _layer(screen).parts():
		assert_bool(part is BatchFrame).is_false()


## A GOLDEN ticket a chain frame binds (inside the chain or at its end) wears the frame for its
## outline: its gold ring and sparkles hide (no gold reaches past the frame); a GOLDEN ticket
## outside any frame keeps them, and the count (no frames) shows them all again.
func test_a_framed_golden_ticket_hides_its_ring() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["banana", "banana_golden", "banana_golden", "bread", "banana_golden"])
	var frames: Array[ChainFrame] = _chain_frames(screen)
	assert_int(frames.size()).is_equal(1)
	assert_array(Array(frames[0].slots)).is_equal([0, 1, 2])
	for slot: int in [1, 2]:
		_assert_gold_shown(screen, slot, false)
	_assert_gold_shown(screen, 4, true)
	screen._on_checkout_pressed()
	await _frames(2)
	assert_array(_chain_frames(screen)).is_empty()
	for slot: int in [1, 2, 4]:
		_assert_gold_shown(screen, slot, true)


## A gap too narrow for a pair (a scaled 8-slot row's) gets one jump ring bridging it, LINK_REACH
## onto each ticket (half an art pixel more where the scaled tickets fall off the art grid); a
## pair's rings overlap by LINK_OVERLAP, centred on their gap.
func test_a_narrow_gap_gets_a_jump_ring() -> void:
	var frame: ChainFrame = auto_free(ChainFrame.new(PackedInt32Array([0, 1, 2])))
	add_child(frame)
	var scale: float = 0.95
	var slack: float = ArtStyle.ART_SCALE / 2.0
	var ticket: Vector2 = PriceSticker.SIZE * scale
	var tickets: Array[Rect2] = []
	for index: int in range(3):
		tickets.append(Rect2(Vector2(100.0 + index * (ticket.x + 8.0), 400.0), ticket))
	frame.lay_out(tickets, 1000.0)
	assert_array(frame.pairs()).is_equal([false, false])
	var rings: Array[Rect2] = frame.link_rects()
	assert_int(rings.size()).is_equal(2)
	for index: int in range(2):
		assert_float(rings[index].position.x).is_greater_equal(
			tickets[index].end.x - ChainFrame.LINK_REACH - slack
		)
		assert_float(rings[index].end.x).is_less_equal(
			tickets[index + 1].position.x + ChainFrame.LINK_REACH + slack
		)
		assert_float(rings[index].size.x).is_greater_equal(ChainFrame.JUMP_WIDTH)
	tickets.clear()
	for index: int in range(2):
		tickets.append(Rect2(Vector2(100.0 + index * 128.0, 400.0), PriceSticker.SIZE))
	frame.lay_out(tickets, 1000.0, PackedInt32Array([0, 1]))
	assert_array(frame.pairs()).is_equal([true])
	var pair: Array[Rect2] = frame.link_rects()
	assert_float(pair[0].end.x - pair[1].position.x).is_equal(ChainFrame.LINK_OVERLAP)
	var middle: float = (tickets[0].end.x + tickets[1].position.x) / 2.0
	assert_float(absf((pair[0].position.x + pair[1].end.x) / 2.0 - middle)).is_less_equal(1.0)


## `frame` links exactly its chain's tickets: its sides RING outside the first and last tickets,
## its top over theirs, its foot at most the counter edge and over the hand baskets, inside the
## screen, clear of every other ticket; each gap between its tickets holds a pair of rings (left
## over the right, LINK_OVERLAP apart) reaching at most LINK_REACH onto each ticket, inside the
## frame's rows; nothing drawn covers a ticket's text lines, a chip, a glyph or a plain price tag.
## It runs on behind each pinned pay tag of its tickets: the tag hangs over its top band, drawn
## after it.
func _assert_frame_geometry(screen: ShiftScreen, frame: ChainFrame) -> void:
	var layer: PlanningLayer = _layer(screen)
	var to_global: Transform2D = layer.get_global_transform()
	var first: Rect2 = _ticket(screen, frame.slots[0])
	var last: Rect2 = _ticket(screen, frame.slots[-1])
	var outer: Rect2 = to_global * frame.frame_rect()
	assert_float(outer.position.x).is_equal(first.position.x - BatchFrame.RING)
	assert_float(outer.end.x).is_equal(last.end.x + BatchFrame.RING)
	assert_float(outer.position.y).is_equal(first.position.y - BatchFrame.TOP_OUT)
	assert_float(outer.end.y).is_less_equal(BatchFrames.FOOT_Y)
	assert_float(outer.end.y).is_less_equal(ShiftStage.HAND_RECT.position.y)
	assert_bool(SCREEN_RECT.encloses(outer)).override_failure_message(str(outer)).is_true()
	for slot: int in range(screen._row_views.size()):
		if slot < frame.slots[0] or slot > frame.slots[-1]:
			var other: Rect2 = _ticket(screen, slot)
			assert_bool(outer.intersects(other)).override_failure_message(str(slot)).is_false()
	var rings: Array[Rect2] = frame.link_rects()
	for pair: bool in frame.pairs():
		assert_bool(pair).is_true()
	assert_int(rings.size()).is_equal(2 * (frame.slots.size() - 1))
	for gap: int in range(frame.slots.size() - 1):
		var left: Rect2 = to_global * rings[gap * 2]
		var right: Rect2 = to_global * rings[gap * 2 + 1]
		var here: Rect2 = _ticket(screen, frame.slots[gap])
		var next: Rect2 = _ticket(screen, frame.slots[gap + 1])
		assert_float(left.end.x - right.position.x).is_equal(ChainFrame.LINK_OVERLAP)
		assert_float(left.position.x).is_greater_equal(here.end.x - ChainFrame.LINK_REACH)
		assert_float(right.end.x).is_less_equal(next.position.x + ChainFrame.LINK_REACH)
		assert_bool(outer.encloses(left) and outer.encloses(right)).is_true()
	_assert_crossings(frame)
	var keep_clear: Array[Rect2] = []
	for slot: int in range(screen._row_views.size()):
		var sticker: PriceSticker = _item(screen, slot).sticker()
		var to_sticker: Transform2D = sticker.get_global_transform()
		keep_clear.append_array(_line_rects(sticker))
		for chip: KeywordChip in sticker.summary().keywords():
			keep_clear.append(chip.get_global_rect())
		for glyph: FamilyGlyph in sticker.glyphs():
			if glyph.visible:
				keep_clear.append(to_sticker * glyph.rim_rect())
		# The price window (tickets v5), paid or printed, sits inside the ticket, clear of the frame.
		keep_clear.append(sticker.window().get_global_rect())
	for drawn: Rect2 in frame.drawn_rects():
		var shown: Rect2 = to_global * drawn
		for rect: Rect2 in keep_clear:
			(
				assert_bool(shown.intersects(rect))
				. override_failure_message("%s over %s" % [shown, rect])
				. is_false()
			)


## `frame` hangs a clasp through its left side when `fed` and through its right side when
## `tallied`, and no other: a left clasp's ring starts outside the side and reaches just past its
## inner edge (the side passes through the ring), a right one the mirror; both clear of the
## neighbour ticket's text by LINK_REACH at most onto its outline.
func _assert_clasps(screen: ShiftScreen, frame: ChainFrame, fed: bool, tallied: bool) -> void:
	assert_bool(frame.is_fed()).is_equal(fed)
	assert_bool(frame.is_tallied()).is_equal(tallied)
	var to_global: Transform2D = _layer(screen).get_global_transform()
	var outer: Rect2 = to_global * frame.frame_rect()
	var clasps: Array[Rect2] = frame.clasp_rects()
	assert_int(clasps.size()).is_equal(int(fed) + int(tallied))
	var at: int = 0
	if fed:
		var clasp: Rect2 = to_global * clasps[at]
		at += 1
		assert_float(clasp.position.x).is_less(outer.position.x)
		assert_float(clasp.end.x).is_equal(
			outer.position.x + BatchFrame.RING + ChainFrame.CLASP_INSIDE
		)
		var helper: Rect2 = _ticket(screen, frame.slots[0] - 1)
		assert_float(clasp.position.x).is_greater_equal(helper.end.x - ChainFrame.LINK_REACH)
	if tallied:
		var clasp: Rect2 = to_global * clasps[at]
		assert_float(clasp.end.x).is_greater(outer.end.x)
		assert_float(clasp.position.x).is_equal(
			outer.end.x - BatchFrame.RING - ChainFrame.CLASP_INSIDE
		)
		var helper: Rect2 = _ticket(screen, frame.slots[-1] + 1)
		assert_float(clasp.end.x).is_less_equal(helper.position.x + ChainFrame.LINK_REACH)


## `frame`'s parts cross in draw order (drawn_rects and drawn_paints): in each pair the left ring
## runs over the right one on top (its ink on the right ring's top band) and under it at the
## bottom (the right ring's face on the left ring's band); a clasp's top runs under the frame's
## side (the side's ink on it) and its bottom over it (the clasp's face on the side's ink).
func _assert_crossings(frame: ChainFrame) -> void:
	var rings: Array[Rect2] = frame.link_rects()
	var at: int = 0
	for pair: bool in frame.pairs():
		if not pair:
			at += 1
			continue
		var left: Rect2 = rings[at]
		at += 2
		var column: float = left.end.x - ChainFrame.LINK_BAND + 1.0
		var faces: Array[int] = [BatchFrame.Paint.FACE, BatchFrame.Paint.KNOT_FACE]
		assert_int(_top_paint(frame, Vector2(column, left.position.y + 3.0))).is_equal(
			BatchFrame.Paint.INK
		)
		assert_bool(faces.has(_top_paint(frame, Vector2(column, left.end.y - 3.0)))).is_true()
	var outer: Rect2 = frame.frame_rect()
	for clasp: Rect2 in frame.clasp_rects():
		var side: float = outer.position.x + 1.0
		if clasp.end.x > outer.end.x:
			side = outer.end.x - 1.0
		assert_int(_top_paint(frame, Vector2(side, clasp.position.y + 3.0))).is_equal(
			BatchFrame.Paint.INK
		)
		assert_int(_top_paint(frame, Vector2(side, clasp.end.y - 3.0))).is_equal(
			BatchFrame.Paint.FACE
		)


## The paint drawn last at `point` (layer coordinates) of `frame`'s drawn rects, -1 for none.
static func _top_paint(frame: BatchFrame, point: Vector2) -> int:
	var rects: Array[Rect2] = frame.drawn_rects()
	var paints: PackedInt32Array = frame.drawn_paints()
	var top: int = -1
	for index: int in range(rects.size()):
		if rects[index].has_point(point):
			top = paints[index]
	return top


## The knot plate at `index` of `frame` sits on the art grid (an even box), its text drawn in
## ink cells of the art grid inside its face, as many as its text's PLATE_GLYPHS cells.
func _assert_plate_cells(frame: ChainFrame, index: int) -> void:
	var plate: Rect2 = frame.plate_rects()[index]
	var grid: float = ArtStyle.ART_SCALE
	for value: float in [plate.position.x, plate.position.y, plate.size.x, plate.size.y]:
		assert_float(fmod(value, grid)).override_failure_message(str(plate)).is_equal(0.0)
	assert_that(plate.size).is_equal(ChainFrame.plate_size(frame.plate_texts()[index]))
	var face: Rect2 = plate.grow(-ChainFrame.PLATE_BORDER)
	var expected: int = 0
	for character: String in frame.plate_texts()[index]:
		for line: String in ChainFrame.PLATE_GLYPHS[character]:
			expected += line.count("#")
	var cells: int = 0
	var rects: Array[Rect2] = frame.drawn_rects()
	var paints: PackedInt32Array = frame.drawn_paints()
	for at: int in range(rects.size()):
		if paints[at] == BatchFrame.Paint.INK and face.encloses(rects[at]):
			assert_that(rects[at].size).is_equal(Vector2.ONE * ChainFrame.PLATE_CELL)
			cells += 1
	assert_int(cells).is_equal(expected)


## Whether `slot`'s GOLDEN ticket shows its gold ring and both sparkles (`shown`), or hides them.
func _assert_gold_shown(screen: ShiftScreen, slot: int, shown: bool) -> void:
	var sticker: PriceSticker = _item(screen, slot).sticker()
	var ring: TextureRect = sticker.gold_ring()
	assert_object(ring).is_not_null()
	var message: String = "slot %d" % slot
	assert_bool(ring.is_visible_in_tree()).override_failure_message(message).is_equal(shown)
	assert_bool(sticker.is_framed()).override_failure_message(message).is_equal(not shown)
	for index: int in 2:
		var sparkle: CanvasItem = sticker.get_node(PriceSticker.SPARKLE_NAME % index) as CanvasItem
		assert_bool(sparkle.is_visible_in_tree()).override_failure_message(message).is_equal(shown)


## Each line of `sticker`'s short text: its pitch tall, as wide as its text (global).
static func _line_rects(sticker: PriceSticker) -> Array[Rect2]:
	var label: GlyphLabel = sticker.summary()
	var to_label: Transform2D = label.get_global_transform()
	var lines: Array[Rect2] = []
	for index: int in range(label.line_count()):
		var width: float = ceilf(label._line_end(label._lines[index]))
		lines.append(to_label * Rect2(0.0, index * label.pitch(), width, label.pitch()))
	return lines


func _model(row: String) -> PlanningModel:
	var cards: Array[CardDefinition] = []
	var instances: Array[CardInstance] = []
	for id: String in row.split(","):
		cards.append(_card(id))
		instances.append(CardInstance.new(cards[-1], instances.size() + 1))
	var result: ScoreResult = Scoring.score(instances)
	var none_upgrades: Array[UpgradeDefinition] = []
	var none_events: Array[InspectionDefinition] = []
	return PlanningModel.build(result, cards, none_upgrades, none_events, null)


static func _card(id: String) -> CardDefinition:
	return load(CARDS % id) as CardDefinition


static func _chain_frames(screen: ShiftScreen) -> Array[ChainFrame]:
	var found: Array[ChainFrame] = []
	for frame: BatchFrame in _layer(screen).frames(true):
		found.append(frame as ChainFrame)
	return found


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


func _move(screen: ShiftScreen, point: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	screen._drag._input(motion)


static func _slot_center(screen: ShiftScreen, slot: int) -> Vector2:
	return screen._slots[slot].get_global_rect().get_center()


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
