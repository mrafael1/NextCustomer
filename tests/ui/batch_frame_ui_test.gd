extends GdUnitTestSuite
## Bakery batches on the belt (#128, the approved Bound strip mock-up,
## docs/art/mockups/bakery_batch_128.html's 'stripb'). The model frames each batch of the
## preview that holds a Bakery job card (a batch card, its sticker naming the BATCH keyword) and
## none of plain Bakery only; a job card WASTED at its place has a wrong job. Its ticket prints
## BATCH as a chip whose tooltip says what a batch is; a wrong job turns the chip tomato with a
## cross, its tooltip the WASTED reason, and rings the ticket in tomato. On the real shift screen
## each framed batch gets one frame round exactly its tickets, inside the screen and over the
## counter edge, its binding bars in the gaps clear of every ticket's text, chips and price tags;
## hovering a BATCH chip lights its frame; a drag lays the frames out for its landing, binding
## the tickets round where the ghost lands; a link that skips products splits a batch's frame
## round its own tickets; a wrong job's ticket is never framed in tomato. The chip
## shows on the monitor and in the deck too. The count keeps the frame and shows no wrong job. The
## real saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const CARDS := "res://data/cards/%s.tres"
const SCREEN_RECT := Rect2(0, 0, 1280, 720)
## The approved capture rows: Bread opens the batch, so the Croissant's job is wrong; then
## Croissant opens it and every job works.
const WRONG_ROW: Array[String] = [
	"bread", "croissant", "baguette", "iced_bun", "stale_doughnut", "banana"
]
const GOOD_ROW: Array[String] = [
	"croissant", "bread", "baguette", "iced_bun", "stale_doughnut", "banana"
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


## The frames: a batch with a job card is framed, a batch of plain Bakery only (Birthday candles'
## Breads) is not, and two batches get two frames.
func test_the_model_frames_the_batches_with_a_job_card(
	row: String,
	framed: Array,
	_test_parameters := [
		["croissant,bread,baguette", [[0, 1, 2]]],
		["bread,croissant", [[0, 1]]],
		["birthday_candles,bread,bread,bread", []],
		["bread,bread,banana", []],
		["croissant,bread,banana,baguette,stale_doughnut", [[0, 1], [3, 4]]],
		["croissant,banana", []],
	]
) -> void:
	var model: PlanningModel = _model(row)
	var shown: Array = []
	for batch: PackedInt32Array in model.batches:
		shown.append(Array(batch))
	assert_array(shown).is_equal(framed)


## A batch a link joins across other products (the old Shelf swap of the frozen cards_v0_6 fixture,
## _old_shelf_swap: Bread, the row's first, counts as beside the Croissant after it; since v1.29 no
## live card links products that are not neighbours, but a link may) is framed in runs round its
## own tickets, the products between left out; a coupon between two of its products stays inside
## its run.
func test_a_link_that_skips_products_splits_the_frame(
	row: String,
	runs: Array,
	_test_parameters := [
		["bread,banana,old_shelf_swap,croissant", [[0], [3]]],
		["croissant,bread,banana,baguette,stale_doughnut", [[0, 1], [3, 4]]],
		["croissant,bread,baguette", [[0, 1, 2]]],
	]
) -> void:
	var model: PlanningModel = _model(row)
	var shown: Array = []
	for run: PackedInt32Array in model.runs:
		shown.append(Array(run))
	assert_array(shown).is_equal(runs)
	assert_int(model.run_batch.size()).is_equal(model.runs.size())
	for index: int in range(model.runs.size()):
		var batch: PackedInt32Array = model.batches[model.run_batch[index]]
		for slot: int in model.runs[index]:
			assert_bool(batch.has(slot)).is_true()
	# A coupon between two products of a batch stays in its run.
	var cards: Array[CardDefinition] = [_card("croissant"), _card("two_for_one"), _card("bread")]
	var joined: Array[PackedInt32Array] = PlanningModel.runs_of(PackedInt32Array([0, 2]), cards)
	assert_int(joined.size()).is_equal(1)
	assert_array(Array(joined[0])).is_equal([0, 2])


## A wrong job: a job card WASTED at its place has the WASTED reason as its tooltip; the same cards
## in their places have none, and a card with no BATCH line never has one.
func test_a_job_card_out_of_place_has_a_wrong_job(
	row: String,
	wrong: Array,
	_test_parameters := [
		["bread,croissant", ["", "WASTED · Not first in its Bakery batch"]],
		["croissant,bread", ["", ""]],
		["stale_doughnut,bread", ["WASTED · Not last in its Bakery batch", ""]],
		# A lone Banana is a CHAIN card out of place (#128 Produce links): its wrong job too.
		["croissant,banana", ["WASTED · No Bakery item beside it", "WASTED · No Banana beside it"]],
		["bread,iced_bun", ["", "WASTED · It closes its batch: nothing to glaze"]],
	]
) -> void:
	var model: PlanningModel = _model(row)
	var shown: Array = []
	for slot: PlanningSlot in model.slots:
		shown.append(slot.wrong_job)
	assert_array(shown).is_equal(wrong)


## Each batch card's ticket prints BATCH as one chip, in its text's box, its tooltip the keyword's;
## a card with no BATCH line has none.
func test_a_batch_cards_ticket_prints_the_batch_chip() -> void:
	for id: String in ["croissant", "baguette", "iced_bun", "stale_doughnut", "birthday_candles"]:
		var sticker: PriceSticker = auto_free(PriceSticker.new(_card(id)))
		add_child(sticker)
		var chips: Array[KeywordChip] = sticker.summary().keywords()
		assert_int(chips.size()).override_failure_message(id).is_equal(1)
		var chip: KeywordChip = chips[0]
		assert_str(chip.keyword).is_equal(CardText.BATCH_WORD)
		assert_str(chip.tip_text).is_equal(GlyphText.keyword_tip(CardText.BATCH_WORD))
		assert_str(chip.tip_text).starts_with("Put Bakery items side by side")
		assert_bool(chip.tip_below).is_true()
		assert_object(chip.tip_anchor).is_same(sticker)
		assert_bool(chip.is_wasted()).is_false()
		assert_that(chip.face_color()).is_equal(Palette.PAPER)
		assert_str(KeywordChip.PALETTE_PATH).is_equal(FamilyPalette.PATH)
		var bakery: FamilyStyle = FamilyPalette.shared().style("Bakery")
		assert_that(KeywordChip.dot_family(chip.keyword).face).is_equal(bakery.face)
		assert_bool(Rect2(Vector2.ZERO, chip.size).encloses(chip.dot_rect())).is_true()
		var dot: Rect2 = chip.dot_rect()
		var above: float = dot.position.y - KeywordChip.BORDER
		var below: float = chip.size.y - KeywordChip.BORDER - dot.end.y
		assert_float(above).override_failure_message("dot gap above").is_equal(below)
		assert_float(above).is_greater(0.0)
		var rect: Rect2 = Rect2(sticker.summary().position + chip.position, chip.size)
		var box: Rect2 = sticker.plate_rect()
		assert_bool(box.grow(1).encloses(rect)).override_failure_message(str(rect)).is_true()
		assert_bool(sticker.summary().fits()).override_failure_message(id).is_true()
		assert_str(sticker.summary().text).contains(CardText.BATCH_WORD)
		assert_bool(sticker.summary().text.contains("Bakery")).is_false()
	for id: String in ["bread", "milk", "eggs"]:
		var plain: PriceSticker = auto_free(PriceSticker.new(_card(id)))
		assert_array(plain.summary().keywords()).is_empty()
	# The Produce chain cards (#128 Produce links) print a CHAIN chip, paper when calm, its dot
	# Produce's.
	for id: String in ["banana", "strawberries", "lemon", "wonky_carrot"]:
		var chain: PriceSticker = auto_free(PriceSticker.new(_card(id)))
		add_child(chain)
		var chain_chips: Array[KeywordChip] = chain.summary().keywords()
		assert_int(chain_chips.size()).override_failure_message(id).is_equal(1)
		assert_str(chain_chips[0].keyword).is_equal(CardText.CHAIN_WORD)
		assert_str(chain_chips[0].tip_text).starts_with("Put Bananas side by side")
		assert_that(chain_chips[0].face_color()).is_equal(Palette.PAPER)
		var produce: FamilyStyle = FamilyPalette.shared().style("Produce")
		assert_that(KeywordChip.dot_family(CardText.CHAIN_WORD).face).is_equal(produce.face)
		assert_bool(chain.summary().fits()).override_failure_message(id).is_true()


## The chip's text and the next words share no pixels: the word after BATCH starts after the chip.
func test_the_chip_keeps_its_words_apart() -> void:
	var sticker: PriceSticker = auto_free(PriceSticker.new(_card("croissant")))
	add_child(sticker)
	var label: GlyphLabel = sticker.summary()
	var chip: KeywordChip = label.keywords()[0]
	assert_float(chip.position.x).is_equal(GlyphLabel.CHIP_MARGIN)
	var first: Rect2 = label.first_line_rect()
	assert_float(first.size.x).is_greater(chip.position.x + chip.size.x)
	# Every run after the chip on its line starts at or past its right edge.
	for run: Dictionary in label._lines[0]:
		if GlyphText.is_text(run):
			assert_float(float(run["x"])).is_greater_equal(chip.position.x + chip.size.x)


## A wrong job turns the chip tomato with a pixel cross, its tooltip the reason; the ticket gets
## no frame of its own (no ring, the same face: the user's play test of 2026-11-03); clearing it
## puts the calm chip back.
func test_a_wrong_job_turns_the_chip_tomato() -> void:
	var sticker: PriceSticker = auto_free(PriceSticker.new(_card("croissant")))
	add_child(sticker)
	var calm_width: float = sticker.summary().keywords()[0].size.x
	var calm_face: Texture2D = sticker.face().texture
	var children: int = sticker.get_child_count()
	var reason: String = "WASTED · Not first in its Bakery batch"
	sticker.set_wrong_job(reason)
	var chip: KeywordChip = sticker.summary().keywords()[0]
	assert_bool(chip.is_wasted()).is_true()
	assert_that(chip.face_color()).is_equal(Palette.TOMATO)
	assert_that(chip.ink_color()).is_equal(Palette.PAPER)
	assert_str(chip.tip_text).is_equal(reason)
	var cross: Rect2 = chip.cross_rect()
	assert_that(cross.size).is_equal(Vector2.ONE * KeywordChip.CROSS_CELLS)
	assert_bool(Rect2(Vector2.ZERO, chip.size).grow(-KeywordChip.BORDER).encloses(cross)).is_true()
	assert_float(chip.size.x).is_greater(calm_width)
	_assert_unframed(sticker)
	assert_object(sticker.face().texture).is_same(calm_face)
	assert_int(sticker.get_child_count()).is_equal(children)
	assert_bool(sticker.summary().fits()).is_true()
	sticker.set_wrong_job("")
	assert_bool(sticker.summary().keywords()[0].is_wasted()).is_false()


## No red frame on a wrong job's ticket (the user's play test of 2026-11-03): no child of the
## ticket but its keyword chips draws tomato, and no ring node.
func _assert_unframed(sticker: PriceSticker) -> void:
	assert_object(sticker.get_node_or_null("WrongRing")).is_null()
	for child: Node in sticker.get_children():
		var ring: bool = (
			child.name.contains("Ring")
			and not (child.name in [PriceSticker.GOT_RING_NAME, PriceSticker.GOLD_RING_NAME])
		)
		assert_bool(ring).override_failure_message(str(child.name)).is_false()


## The keyword's tip wraps on the card (the shared TipCard): the card's width, more than one line.
func test_the_keywords_tooltip_wraps() -> void:
	var tip: TipCard = auto_free(TipCard.new())
	add_child(tip)
	tip.show_spec(TipWords.box(CardText.BATCH_WORD))
	assert_float(tip.size.x).is_equal(TipCard.WIDTH)
	assert_int(tip.body().line_count()).is_greater(1)
	assert_str(tip.title_text()).is_equal(CardText.BATCH_WORD)


## On the shift screen the wrong row (Bread first) frames one batch, Bread to Stale doughnut,
## round exactly their tickets, over the counter edge and inside the screen; its bars sit in the
## gaps clear of every ticket's text and chips, and nothing of it covers a price tag. Croissant's
## chip is tomato, its ticket unframed; Bread's chips (none) stay calm.
func test_the_frame_binds_exactly_the_batch() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, WRONG_ROW)
	var layer: PlanningLayer = _layer(screen)
	var frames: Array[BatchFrame] = layer.frames()
	assert_int(frames.size()).is_equal(1)
	var frame: BatchFrame = frames[0]
	assert_array(Array(frame.slots)).is_equal([0, 1, 2, 3, 4])
	assert_bool(frame.visible).is_true()
	_assert_frame_geometry(screen, frame)
	var croissant: PriceSticker = _item(screen, 1).sticker()
	assert_bool(croissant.summary().keywords()[0].is_wasted()).is_true()
	_assert_unframed(croissant)
	assert_str(croissant.summary().keywords()[0].tip_text).is_equal(
		"WASTED · Not first in its Bakery batch"
	)
	var bread: PriceSticker = _item(screen, 0).sticker()
	for chip: KeywordChip in bread.summary().keywords():
		assert_bool(chip.is_wasted()).is_false()
	for slot: int in [2, 3, 4]:
		var sticker: PriceSticker = _item(screen, slot).sticker()
		assert_bool(sticker.summary().keywords()[0].is_wasted()).is_false()
	# The frame draws no tomato over a wrong job's ticket.
	for paint: int in frame.drawn_paints():
		assert_that(frame.paint_color(paint as BatchFrame.Paint)).is_not_equal(Palette.TOMATO)


## A framed ticket's stuck price label (price leak, 2026-11-10) lies over its frame: the row's
## label layer sits in the planning layer, after the batch and chain frames and their keyword
## marks and under every other part, and draws the label where the frame's band runs.
func test_a_stuck_price_label_lies_over_the_frame() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, WRONG_ROW)
	var layer: PlanningLayer = _layer(screen)
	var labels: PriceLabelLayer = screen._stage.row_strip.labels
	assert_object(labels.get_parent()).is_same(layer)
	var chains: Node = layer.get_node("ChainFrames")
	assert_int(labels.get_index()).is_equal(chains.get_index() + 1)
	assert_bool(labels.is_greater_than(layer.get_node("BatchFrames"))).is_true()
	assert_bool(labels.is_greater_than(KeywordMarks.of(layer))).is_true()
	assert_bool(labels.is_greater_than(_item(screen, 4))).is_true()
	assert_bool(layer.fan().is_greater_than(labels)).is_true()
	assert_bool(screen._stage.hand.is_greater_than(labels)).is_true()
	# The run's last ticket: its label crosses the frame's top band and its side band.
	var frame: BatchFrame = layer.frames()[0]
	var sticker: PriceSticker = _item(screen, frame.slots[-1]).sticker()
	sticker.set_pay(PlanningModel.Pay.BOOSTED, 9999)
	var window: PriceWindow = sticker.window()
	assert_array(labels.labelled()).contains([window])
	assert_bool(window.label().covered).is_true()
	await _frames(2)
	var shown: Rect2 = window.label().get_global_rect()
	var outer: Rect2 = layer.get_global_transform() * frame.frame_rect()
	assert_bool(outer.intersects(shown)).is_true()
	assert_float(shown.end.x).is_greater(outer.end.x)
	var drawn: Array[Rect2] = labels.drawn_rects()
	assert_int(drawn.size()).is_equal(1)
	assert_vector(drawn[0].position).is_equal_approx(shown.position, Vector2.ONE * 0.01)
	assert_vector(drawn[0].size).is_equal_approx(shown.size, Vector2.ONE * 0.01)


## In their places (Croissant first) no job is wrong, and the frame binds the same tickets. The
## lone Banana closing the row is a CHAIN card out of place (#128's Produce links): its CHAIN chip
## is wasted, its ticket unframed (the user's play test of 2026-11-03).
func test_the_good_row_has_no_wrong_job() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, GOOD_ROW)
	var frames: Array[BatchFrame] = _layer(screen).frames()
	assert_int(frames.size()).is_equal(1)
	_assert_frame_geometry(screen, frames[0])
	for slot: int in range(GOOD_ROW.size() - 1):
		var sticker: PriceSticker = _item(screen, slot).sticker()
		for chip: KeywordChip in sticker.summary().keywords():
			assert_bool(chip.is_wasted()).is_false()
	var banana: PriceSticker = _item(screen, GOOD_ROW.size() - 1).sticker()
	assert_bool(banana.summary().keywords()[0].is_wasted()).is_true()
	_assert_unframed(banana)


## The monitor's scan of belt slot 1, the Croissant (pinned, 2026-11-04: the default is the last
## placed item) prints its BATCH chip with the keyword's tooltip, and the Deck shows it on a
## Croissant's ticket in the cart.
func test_the_monitor_and_the_deck_show_the_chip() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, GOOD_ROW)
	screen._week.skip()  # The time card (v0.70) stays out of the scan's way.
	assert_bool(screen.debug_scan(screen.run.row[0])).is_true()
	await _frames(1)
	var column: MonitorItemColumn = screen._stage.monitor.item_column()
	assert_object(column.shown_definition()).is_same(_card("croissant"))
	var chips: Array[KeywordChip] = column.effect().keywords()
	assert_int(chips.size()).is_equal(1)
	assert_str(chips[0].keyword).is_equal(CardText.BATCH_WORD)
	assert_str(chips[0].tip_text).is_equal(GlyphText.keyword_tip(CardText.BATCH_WORD))
	assert_bool(chips[0].is_shown()).is_true()
	assert_bool(column.get_global_rect().encloses(chips[0].get_global_rect())).is_true()
	screen.run.deck.add_card(_card("croissant"))
	screen._on_deck_button_pressed()
	await _frames(2)
	var found: bool = false
	for cell: DeckCell in screen._deck_view.cells():
		if cell.card.id != &"croissant":
			continue
		found = true
		var deck_chips: Array[KeywordChip] = cell.item().sticker().summary().keywords()
		assert_int(deck_chips.size()).is_equal(1)
		assert_str(deck_chips[0].tip_text).is_equal(GlyphText.keyword_tip(CardText.BATCH_WORD))
		assert_bool(deck_chips[0].is_wasted()).is_false()
	assert_bool(found).is_true()


## Every batch card's effect on the monitor's item column prints one BATCH chip, inside the
## column: planning's full layout, the compact one (step lines that don't fit: the effect on one
## line, cut with an ellipsis) and the count's one line.
func test_the_monitor_column_prints_the_chip_in_every_layout() -> void:
	var column: MonitorItemColumn = auto_free(MonitorItemColumn.new())
	add_child(column)
	var many: PackedStringArray = PackedStringArray()
	var fizzles: Array[bool] = []
	for index: int in range(12):
		many.append("Breakfast sticker  WASTED")
		fizzles.append(true)
	for id: String in ["croissant", "baguette", "iced_bun", "stale_doughnut", "birthday_candles"]:
		var definition: CardDefinition = _card(id)
		column.show_item(definition, definition.tags, ScanController.ItemLines.new())
		_assert_one_chip(column, "%s planning" % id)
		var compact: ScanController.ItemLines = ScanController.ItemLines.new()
		compact.payout = definition.base
		compact.lines = many
		compact.fizzles = fizzles
		column.show_item(definition, definition.tags, compact)
		_assert_one_chip(column, "%s compact" % id)
		column.start_item(definition, definition.tags, false)
		_assert_one_chip(column, "%s counting" % id)
		# The column frees each layout's labels once out of the tree: let them go.
		await _frames(1)


func _assert_one_chip(column: MonitorItemColumn, what: String) -> void:
	var effect: GlyphLabel = column.effect()
	assert_object(effect).override_failure_message(what).is_not_null()
	var chips: Array[KeywordChip] = effect.keywords()
	assert_int(chips.size()).override_failure_message(what).is_equal(1)
	assert_str(chips[0].keyword).is_equal(CardText.BATCH_WORD)
	assert_bool(chips[0].is_wasted()).is_false()
	var box: Rect2 = Rect2(Vector2.ZERO, column.size)
	var rect: Rect2 = Rect2(effect.position + chips[0].position, chips[0].size)
	assert_bool(box.encloses(rect)).override_failure_message("%s %s" % [what, rect]).is_true()


## Two batches split by a Banana get two frames, each round its own tickets.
func test_two_batches_get_two_frames() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["croissant", "bread", "banana", "baguette", "stale_doughnut"])
	var frames: Array[BatchFrame] = _layer(screen).frames()
	assert_int(frames.size()).is_equal(2)
	assert_array(Array(frames[0].slots)).is_equal([0, 1])
	assert_array(Array(frames[1].slots)).is_equal([3, 4])
	for frame: BatchFrame in frames:
		_assert_frame_geometry(screen, frame)
	assert_bool(frames[0].frame_rect().intersects(frames[1].frame_rect())).is_false()


## A batch a link joins across the Banana (Bread, Banana, the old Shelf swap, Croissant: see
## test_a_link_that_skips_products_splits_the_frame) gets a frame round each of its own tickets,
## none round the Banana or the coupon; hovering the Croissant's chip lights both.
func test_a_linked_batch_frames_its_own_tickets() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["bread", "banana", "old_shelf_swap", "croissant"])
	var frames: Array[BatchFrame] = _layer(screen).frames()
	assert_int(frames.size()).is_equal(2)
	assert_array(Array(frames[0].slots)).is_equal([0])
	assert_array(Array(frames[1].slots)).is_equal([3])
	for frame: BatchFrame in frames:
		assert_array(Array(frame.batch)).is_equal([0, 3])
		assert_bool(frame.visible).is_true()
		assert_array(frame.bar_rects()).is_empty()
		_assert_frame_geometry(screen, frame)
	var tips: GlyphTips = screen._glyph_tips
	var chip: KeywordChip = _item(screen, 3).sticker().summary().keywords()[0]
	tips.point_at(chip.get_global_rect().get_center())
	tips.show_tip(chip)
	await _frames(1)
	for frame: BatchFrame in frames:
		assert_bool(frame.is_lit()).is_true()
	tips.hide_tip()


## Hovering a BATCH chip shows its tooltip and lights the chip and its batch's frame; leaving puts
## them back. A wrong job's chip tips its WASTED reason.
func test_hovering_a_batch_chip_lights_its_frame() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, WRONG_ROW)
	var tips: GlyphTips = screen._glyph_tips
	var frame: BatchFrame = _layer(screen).frames()[0]
	var chip: KeywordChip = _item(screen, 2).sticker().summary().keywords()[0]
	tips.point_at(chip.get_global_rect().get_center())
	tips.show_tip(chip)
	await _frames(1)
	assert_bool(chip.is_lit()).is_true()
	assert_that(chip.face_color()).is_equal(Palette.MUSTARD)
	assert_bool(frame.is_lit()).is_true()
	assert_str(tips.tip().tip_text()).is_equal(GlyphText.keyword_tip(CardText.BATCH_WORD))
	assert_bool(SCREEN_RECT.encloses(tips.tip().get_global_rect())).is_true()
	tips.hide_tip()
	await _frames(1)
	assert_bool(chip.is_lit()).is_false()
	assert_bool(frame.is_lit()).is_false()
	var wrong: KeywordChip = _item(screen, 1).sticker().summary().keywords()[0]
	tips.point_at(wrong.get_global_rect().get_center())
	tips.show_tip(wrong)
	await _frames(1)
	assert_str(tips.tip().tip_text()).is_equal("WASTED · Not first in its Bakery batch")
	assert_bool(frame.is_lit()).is_true()
	assert_that(wrong.face_color()).is_equal(Palette.TOMATO)
	tips.hide_tip()


## A drag lays the frames out for its landing, live: a batch the ghost would join is bound round
## its tickets on the belt (the ghost has none: it lands at the frame's end or between two of its
## tickets), one it leaves alone round its own tickets.
func test_a_drag_lays_out_the_frames_for_its_landing() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["croissant", "bread", "banana"])
	assert_int(_layer(screen).frames().size()).is_equal(1)
	screen._debug.add_card("baguette")
	var baguette: CardInstance = screen.run.hand()[-1]
	screen._on_hand_card_clicked(_view_for(screen, baguette))
	var croissant: Rect2 = _ticket(screen, 0)
	var bread: Rect2 = _ticket(screen, 1)
	var to_global: Transform2D = _layer(screen).get_global_transform()
	# Between Bread and Banana, then between Croissant and Bread: the ghost joins the batch, which
	# stays bound round the Croissant's and the Bread's tickets.
	for landing: int in [2, 1]:
		_move(screen, _slot_center(screen, landing))
		await _frames(2)
		assert_int(screen._drag.hovered_slot()).is_equal(landing)
		var joined: Array[BatchFrame] = _layer(screen).frames()
		assert_int(joined.size()).is_equal(1)
		assert_array(Array(joined[0].slots)).is_equal([0, 1, 2])
		assert_bool(joined[0].visible).override_failure_message(str(landing)).is_true()
		var outer: Rect2 = to_global * joined[0].frame_rect()
		assert_float(outer.position.x).is_equal(croissant.position.x - BatchFrame.RING)
		assert_float(outer.end.x).is_equal(bread.end.x + BatchFrame.RING)
		assert_float(outer.end.y).is_less_equal(BatchFrames.FOOT_Y)
		assert_int(joined[0].bar_rects().size()).is_equal(BatchFrame.BAR_TOPS.size())
		assert_bool(outer.intersects(_ticket(screen, 2))).is_false()
	# After Banana: the batch keeps its two tickets, framed.
	_move(screen, _slot_center(screen, 3))
	await _frames(2)
	assert_int(screen._drag.hovered_slot()).is_equal(3)
	var kept: Array[BatchFrame] = _layer(screen).frames()
	assert_int(kept.size()).is_equal(1)
	assert_array(Array(kept[0].slots)).is_equal([0, 1])
	assert_bool(kept[0].visible).is_true()
	_assert_frame_geometry(screen, kept[0])


## The CHECKOUT click takes every wrong job off for the count; the batch's frame stays for its
## bookends' beats (BatchBookends, 2026-11-12): once its first two items are bagged it binds the
## three tickets left on the belt (its sides RING outside them, its bars in their two gaps only),
## inside the screen and clear of the Banana's ticket.
func test_the_count_keeps_the_frame_and_no_wrong_job() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, WRONG_ROW)
	assert_array(_layer(screen).frames()).is_not_empty()
	screen._on_checkout_pressed()
	await _frames(2)
	var frames: Array[BatchFrame] = _layer(screen).frames()
	assert_int(frames.size()).is_equal(1)
	assert_bool(frames[0].visible).is_true()
	for view: CardView in screen._row_views:
		var sticker: PriceSticker = (view as ItemView).sticker()
		for chip: KeywordChip in sticker.summary().keywords():
			assert_bool(chip.is_wasted()).is_false()
	# As the first items go into the bag, the frame binds the batch's tickets left on the belt.
	var layer: PlanningLayer = _layer(screen)
	while screen._counting and not screen._ride.is_bagged(1):
		await get_tree().process_frame
	await _frames(1)
	var to_global: Transform2D = layer.get_global_transform()
	var outer: Rect2 = to_global * frames[0].frame_rect()
	var first: Rect2 = _ticket(screen, 2)
	var last: Rect2 = _ticket(screen, 4)
	assert_bool(frames[0].visible).is_true()
	assert_float(outer.position.x).is_equal_approx(first.position.x - BatchFrame.RING, 0.5)
	assert_float(outer.end.x).is_equal_approx(last.end.x + BatchFrame.RING, 0.5)
	assert_float(outer.position.y).is_equal_approx(first.position.y - BatchFrame.TOP_OUT, 0.5)
	assert_float(outer.end.y).is_less_equal(BatchFrames.FOOT_Y)
	assert_bool(outer.intersects(_ticket(screen, 5))).is_false()
	assert_bool(SCREEN_RECT.encloses(outer)).override_failure_message(str(outer)).is_true()
	assert_array(frames[0].bar_rects()).has_size(BatchFrame.BAR_TOPS.size() * 2)
	for bar: Rect2 in frames[0].bar_rects():
		assert_float((to_global * bar).position.x).is_greater(first.position.x)


## `frame` binds exactly its batch's tickets: its sides RING outside the first and last tickets,
## its top over theirs, its foot at most the counter edge and over the hand baskets, inside the
## screen, clear of every other ticket; each gap holds two bars reaching BAR_OVERLAP onto each
## ticket; nothing drawn covers a ticket's text, a chip, a glyph or a plain price tag. It runs on
## behind each pinned pay tag of its tickets: the tag hangs over its top band, drawn after it.
func _assert_frame_geometry(screen: ShiftScreen, frame: BatchFrame) -> void:
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
	# The frame's inside is the tickets' span: no other ticket inside it.
	for slot: int in range(screen._row_views.size()):
		if slot < frame.slots[0] or slot > frame.slots[-1]:
			var other: Rect2 = _ticket(screen, slot)
			assert_bool(outer.intersects(other)).override_failure_message(str(slot)).is_false()
	var bars: Array[Rect2] = frame.bar_rects()
	assert_int(bars.size()).is_equal(BatchFrame.BAR_TOPS.size() * (frame.slots.size() - 1))
	for index: int in range(bars.size()):
		var bar: Rect2 = to_global * bars[index]
		var gap: int = frame.slots[0] + floori(float(index) / BatchFrame.BAR_TOPS.size())
		var left: Rect2 = _ticket(screen, gap)
		var right: Rect2 = _ticket(screen, gap + 1)
		assert_float(bar.position.x).is_equal(left.end.x - BatchFrame.BAR_OVERLAP)
		assert_float(bar.end.x).is_equal(right.position.x + BatchFrame.BAR_OVERLAP)
		assert_bool(outer.encloses(bar)).is_true()
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
	if id == "old_shelf_swap":
		return _old_shelf_swap()
	return load(CARDS % id) as CardDefinition


## The pre-v1.29 Shelf swap (the cards_v0_6 fixture's rule: the next product also counts as just
## after the row's first product) on a copy of the live card, its art kept.
static func _old_shelf_swap() -> CardDefinition:
	var old: CardDefinition = (load(CARDS % "shelf_swap") as CardDefinition).duplicate()
	var rules: Array[Rule] = [FirstProductLinkRule.new()]
	old.rules = rules
	return old


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
		if id == "old_shelf_swap":
			# A fixture card the debug tools can't name: put into the hand as add_card does.
			screen.run.debug_add_to_hand(_card(id))
			screen._refresh()
		else:
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
