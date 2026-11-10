extends GdUnitTestSuite
## The belt's MORNING and PAIR marks (v1.06, the keywords handbook: "MORNING and PAIR miss a
## visual on the ticket"). The score records the MORNING (when a card in the row reads it) and
## every PAIR (ScoreResult.mornings, pairs), the planning model passes them on, and on the real
## shift screen KeywordMarks draws the MORNING's line (v1.24: a pin on each of its tickets' feet,
## joined by one chain from a post at the row's start, clear of the marks hanging there) and puts
## a teal clasp across each PAIR's gap, inside the screen, clear of the tickets' text. The real
## saves and logs are never touched.

const SCREEN := "res://ui/shift_screen.tscn"
const CARDS := "res://data/cards/%s.tres"
const SCREEN_RECT := Rect2(0, 0, 1280, 720)
## A MORNING of three (Potatoes ends it) read by Tea bags and Coffee, then Butter beside Bread.
const ROW: Array[String] = ["tea_bags", "bread", "milk", "potatoes", "coffee", "butter", "bread"]
## How far under the tickets' feet v1.06's ribbon reached: nothing of the line hangs lower.
const RIBBON_REACH := 20.0

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
	_runner = null
	get_tree().root.size = _window_size
	ProjectSettings.set_setting(SaveService.FOLDER_SETTING, null)
	if DirAccess.dir_exists_absolute(_folder):
		for file_name: String in DirAccess.get_files_at(_folder):
			DirAccess.remove_absolute(_folder.path_join(file_name))
		DirAccess.remove_absolute(_folder)


## The score's MORNING (only when a card reads it; coupons neither join nor end it) and PAIRs
## (each paired product with its partner, once), passed on by the model.
func test_the_score_records_the_morning_and_the_pairs(
	row: String,
	morning: Array,
	pairs: Array,
	_test_parameters := [
		["tea_bags,bread,milk,potatoes,coffee", [0, 1, 2], []],
		["bread,milk,eggs", [], []],
		["coffee,two_for_one,milk,potatoes", [0, 2], []],
		["butter,bread,cheese", [], [Vector2i(0, 1), Vector2i(1, 2)]],
		["cheese,potatoes,bread", [], []],
		["cereal,milk,coffee", [0, 1, 2], [Vector2i(0, 1)]],
	]
) -> void:
	var model: PlanningModel = _model(row)
	assert_array(Array(model.mornings)).is_equal(morning)
	assert_array(model.pairs).is_equal(pairs)


## A Double checkout's joined result moves row 2's marks past row 1's slots.
func test_a_joined_result_moves_the_second_rows_marks() -> void:
	var first: ScoreResult = Scoring.score(_row("coffee,milk"))
	var second: ScoreResult = Scoring.score(_row("butter,bread"))
	var joined: ScoreResult = ScoreResult.joined(first, second, 2)
	assert_array(Array(joined.mornings)).is_equal([0, 1])
	assert_array(joined.pairs).is_equal([Vector2i(2, 3)])
	assert_array(ScoreResult.continued(second, 10).pairs).is_equal([Vector2i(0, 1)])


## The MORNING's line: a pin on each of its tickets, the first one's too, at the same place on each
## foot (PIN_LEFT in, PIN_OVER over it); the anchor post before the first ticket, in the belt's
## margin at the row's start, level with the pins; one chain from the post's middle to the last
## pin's, through the gaps between the run's tickets, under the pins. All of it inside the screen,
## no lower than v1.06's ribbon hung, clear of the tickets' text, and nothing on Potatoes, which
## ends the MORNING. A clasp crosses the Butter and Bread gap at the tickets' middle, clear of
## both tickets' text.
func test_the_marks_sit_on_the_belt() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ROW)
	var marks: KeywordMarks = _marks(screen)
	assert_array(Array(marks.morning_slots())).is_equal([0, 1, 2])
	assert_int(marks.pins().size()).is_equal(3)
	var first: Rect2 = _ticket(screen, 0)
	var parts: Array[Rect2] = []
	for index: int in range(3):
		var pin: MorningPin = marks.pins()[index]
		assert_bool(pin.is_visible_in_tree()).is_true()
		var ticket: Rect2 = _ticket(screen, index)
		var rect: Rect2 = pin.get_global_rect()
		assert_vector(rect.size).is_equal(Vector2(MorningPin.SIDE, MorningPin.SIDE))
		assert_float(rect.position.x).is_equal_approx(
			ticket.position.x + KeywordMarks.PIN_LEFT, 1.0
		)
		assert_float(rect.position.y).is_equal_approx(ticket.end.y - KeywordMarks.PIN_OVER, 1.0)
		# On the ticket's foot edge: it starts on the ticket and ends under it.
		assert_float(rect.position.y).is_less(ticket.end.y)
		assert_float(rect.end.y).is_greater(ticket.end.y)
		assert_float(rect.end.x).is_less(ticket.end.x)
		assert_bool(pin.face_color().is_equal_approx(Palette.MUSTARD)).is_true()
		parts.append(Rect2(rect.position, rect.size + MorningPin.SHADOW))
	# The post: before the first ticket, level with the pins, the line's start.
	var post: Rect2 = marks.post().get_global_rect()
	assert_bool(marks.post().is_visible_in_tree()).is_true()
	assert_float(post.end.x).is_less_equal(first.position.x)
	assert_float(post.position.x).is_equal_approx(first.position.x - KeywordMarks.POST_OUT, 1.0)
	assert_float(post.get_center().y).is_equal_approx(
		parts[0].position.y + MorningPin.SIDE / 2.0, 1.0
	)
	parts.append(Rect2(post.position, post.size + MorningPin.SHADOW))
	# One chain, from the post's middle to the last pin's, crossing every gap of the run.
	var links: Array[Rect2] = _link_rects(marks)
	assert_int(links.size()).is_equal(1)
	assert_float(links[0].position.x).is_equal_approx(post.get_center().x, 1.0)
	var last: Rect2 = marks.pins()[2].get_global_rect()
	assert_float(links[0].end.x).is_equal_approx(last.get_center().x, 1.0)
	assert_float(links[0].get_center().y).is_equal_approx(last.get_center().y, 1.0)
	# A ring links each two tickets of the run, in the middle of their gap.
	var link: MorningLink = marks.links()[0]
	assert_int(link.ring_rects().size()).is_equal(2)
	for gap: int in [0, 1]:
		var ring: Rect2 = link.get_global_transform() * link.ring_rects()[gap]
		var middle: float = (_ticket(screen, gap).end.x + _ticket(screen, gap + 1).position.x) / 2.0
		assert_float(ring.get_center().x).is_equal_approx(middle, 2.0)
		assert_bool(links[0].encloses(ring)).is_true()
	parts.append_array(links)
	# The pins and the post draw over the chain.
	for pin: MorningPin in marks.pins():
		assert_int(pin.get_index()).is_greater(marks.links()[0].get_index())
	assert_int(marks.post().get_index()).is_greater(marks.links()[0].get_index())
	for part: Rect2 in parts:
		assert_bool(SCREEN_RECT.encloses(part)).is_true()
		# No lower than the ribbon hung, so clear of the hand baskets as it was.
		assert_float(part.end.y).is_less_equal(first.end.y + RIBBON_REACH)
		assert_float(part.end.y).is_less_equal(first.end.y + KeywordMarks.PIN_REACH)
		# Not on Potatoes, which ends the MORNING.
		assert_float(part.end.x).is_less(_ticket(screen, 3).position.x)
	# Clear of each ticket's text.
	for slot: int in [0, 1, 2]:
		var summary: PriceSticker = _item(screen, slot).sticker()
		var words: Rect2 = summary.get_global_transform() * summary.summary_text_rect()
		for part: Rect2 in parts:
			assert_bool(part.intersects(words)).override_failure_message(str(slot)).is_false()
	assert_array(marks.clasp_gaps()).is_equal([Vector2i(5, 6)])
	var clasp: Rect2 = marks.clasps()[0].get_global_rect()
	var butter: Rect2 = _ticket(screen, 5)
	var bread: Rect2 = _ticket(screen, 6)
	assert_bool(marks.clasps()[0].is_visible_in_tree()).is_true()
	assert_float(clasp.position.x).is_less(butter.end.x)
	assert_float(clasp.end.x).is_greater(bread.position.x)
	assert_float(clasp.position.x).is_greater_equal(butter.end.x - 4.0)
	assert_float(clasp.end.x).is_less_equal(bread.position.x + 4.0)
	assert_float(clasp.position.y).is_greater(butter.position.y)
	assert_float(clasp.end.y).is_less(butter.end.y)
	for slot: int in [5, 6]:
		var sticker: PriceSticker = _item(screen, slot).sticker()
		var text: Rect2 = sticker.get_global_transform() * sticker.summary_text_rect()
		assert_bool(clasp.intersects(text)).override_failure_message(str(slot)).is_false()


## A MORNING of one is its pin, joined to the post at the row's start; a MORNING of five a pin on
## each of its tickets, all on one chain from the post.
func test_runs_of_one_and_five_are_one_line_from_the_row_start(
	row: String,
	run: int,
	_test_parameters := [
		["coffee,potatoes,milk", 1],
		["tea_bags,bread,milk,cereal,coffee,potatoes", 5],
	]
) -> void:
	var screen: ShiftScreen = await _screen()
	var ids: Array[String] = []
	ids.assign(row.split(","))
	await _place(screen, ids)
	var marks: KeywordMarks = _marks(screen)
	assert_int(marks.morning_slots().size()).is_equal(run)
	for index: int in range(run):
		var pin: MorningPin = marks.pins()[index]
		assert_bool(pin.is_visible_in_tree()).is_true()
		var ticket: Rect2 = _ticket(screen, marks.morning_slots()[index])
		var rect: Rect2 = pin.get_global_rect()
		assert_float(rect.position.x).is_equal_approx(
			ticket.position.x + KeywordMarks.PIN_LEFT, 1.0
		)
		assert_float(rect.position.y).is_equal_approx(ticket.end.y - KeywordMarks.PIN_OVER, 1.0)
	var start: float = marks.post().get_global_rect().get_center().x
	var end: float = marks.pins()[run - 1].get_global_rect().get_center().x
	_assert_continuous(_link_rects(marks), start, end, screen._row_strip.mark_rects())
	assert_float(start).is_less(_ticket(screen, 0).position.x)
	# Nothing past the run's last ticket.
	assert_float(_link_rects(marks)[-1].end.x).is_less(_ticket(screen, run - 1).end.x)
	# A ring in each gap the line crosses: one fewer than the run's tickets.
	var rings: int = 0
	for link: MorningLink in marks.links():
		rings += link.ring_rects().size()
	assert_int(rings).is_equal(run - 1)


## The line keeps clear of the marks hanging on the tickets' feet (the Spot check's sign under
## slot 3, the Slot engine's talker under slot 6, a chain's knot plate) and stays one line: a pin
## that would meet one steps aside on its ticket's foot, and the chain is cut round each mark and
## goes on after it, from the post at the row's start (before the coupons that open a row, whose
## tickets it crosses) to the last pin. Under a GOLDEN Breakfast ticket's gold ring its pin sits on
## the ring's foot.
func test_the_line_keeps_clear_of_the_hanging_marks(
	row: String,
	_test_parameters := [
		["tea_bags,bread,milk_golden,potatoes,coffee,butter,bread"],
		["tea_bags,bread,milk,cereal,coffee,milk,potatoes"],
		["tea_bags,bread_golden,milk,cereal,coffee,milk_golden,potatoes"],
		["two_for_one,multipack,milk,bread,coffee,potatoes"],
	]
) -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.give_upgrade("slot_engine")
	screen._debug.set_inspection("spot_check")
	var ids: Array[String] = []
	ids.assign(row.split(","))
	await _place(screen, ids)
	var marks: KeywordMarks = _marks(screen)
	var morning: PackedInt32Array = marks.morning_slots()
	assert_bool(morning.has(2)).override_failure_message(str(morning)).is_true()
	var hanging: Array[Rect2] = screen._row_strip.mark_rects()
	assert_array(hanging).is_not_empty()
	var parts: Array[Rect2] = _link_rects(marks)
	var end: float = NAN
	for index: int in range(morning.size()):
		var slot: int = morning[index]
		var ticket: Rect2 = _ticket(screen, slot)
		var foot: float = ticket.end.y
		var ring: TextureRect = _item(screen, slot).sticker().gold_ring()
		if ring != null and ring.is_visible_in_tree():
			foot = ring.get_global_rect().end.y
			assert_float(foot).is_greater(ticket.end.y)
		var pin: MorningPin = marks.pins()[index]
		var shown: String = "no pin on slot %d" % slot
		assert_bool(pin.is_visible_in_tree()).override_failure_message(shown).is_true()
		var part: Rect2 = Rect2(pin.get_global_position(), MorningPin.footprint())
		assert_float(part.position.y).is_equal_approx(foot - KeywordMarks.PIN_OVER, 1.0)
		assert_float(part.position.x).is_greater_equal(ticket.position.x)
		assert_float(part.end.x).is_less_equal(ticket.end.x)
		assert_float(part.end.y).is_less_equal(foot + RIBBON_REACH)
		parts.append(part)
		end = pin.get_global_rect().get_center().x
	var post: Rect2 = marks.post().get_global_rect()
	assert_float(post.end.x).is_less_equal(_ticket(screen, 0).position.x)
	parts.append(post)
	for part: Rect2 in parts:
		assert_bool(SCREEN_RECT.encloses(part)).is_true()
		for mark: Rect2 in hanging:
			var met: String = "%s meets %s" % [part, mark]
			assert_bool(part.intersects(mark)).override_failure_message(met).is_false()
	_assert_continuous(_link_rects(marks), post.get_center().x, end, hanging)
	if row.begins_with("two_for_one"):
		# The MORNING opens on slot 3, under the Spot check's sign: the chain runs from the row's
		# start under the coupons' tickets, and is cut round the sign.
		assert_float(post.end.x).is_less(_ticket(screen, 0).position.x + 1.0)
		assert_int(_link_rects(marks).size()).is_greater(1)


## A place on a ticket's foot (KeywordMarks._free_x): the usual one when free, else the nearest
## that keeps PIN_GAP clear of every hanging mark, inside the ticket; none when nothing is left.
func test_a_part_steps_aside_to_the_nearest_free_place() -> void:
	var ticket: Rect2 = Rect2(100, 400, 108, 76)
	var room: Rect2 = Rect2(0, 470, 20, 20)
	var none: Array[Rect2] = []
	assert_float(KeywordMarks._free_x(ticket, room, 1.0, none)).is_equal(110.0)
	# A mark far along the foot, or above or under the part's band, changes nothing.
	var far: Array[Rect2] = [
		Rect2(170, 474, 30, 22), Rect2(104, 440, 40, 28), Rect2(104, 492, 40, 9)
	]
	assert_float(KeywordMarks._free_x(ticket, room, 1.0, far)).is_equal(110.0)
	# A mark on the usual place: just after it when that is nearer, else just before it.
	var on_it: Array[Rect2] = [Rect2(104, 474, 20, 22)]
	assert_float(KeywordMarks._free_x(ticket, room, 1.0, on_it)).is_equal(126.0)
	var wide: Array[Rect2] = [Rect2(126, 474, 82, 22)]
	assert_float(KeywordMarks._free_x(ticket, room, 1.0, wide)).is_equal(104.0)
	# No room on either side: none.
	var full: Array[Rect2] = [Rect2(110, 474, 90, 22)]
	assert_bool(is_nan(KeywordMarks._free_x(ticket, room, 1.0, full))).is_true()


## The line stays one line whatever its pins do: a pin a mark pushes aside keeps its ticket and
## the chain still runs through it; a pin with no room hides, and the chain still runs to that
## ticket's pin place, cut only round the marks. A drag's ghost is skipped (the post moves to the
## first ticket left), and a ticket missing from the row hides the whole line.
func test_the_line_stays_continuous_when_pins_step_aside_or_hide() -> void:
	var marks: KeywordMarks = auto_free(KeywordMarks.new())
	add_child(marks)
	var model: PlanningModel = _model("tea_bags,bread,milk,potatoes")
	marks.show_marks(model)
	var tickets: Dictionary[int, Rect2] = {}
	for slot: int in range(4):
		tickets[slot] = Rect2(100.0 + 128.0 * slot, 400, 108, 76)
	var blocked: Array[Rect2] = [Rect2(104, 474, 20, 22)]
	marks.obstacles = func() -> Array[Rect2]: return blocked
	marks.lay_out(tickets)
	var pins: Array[MorningPin] = marks.pins()
	assert_float(pins[0].position.x).is_equal(126.0)
	assert_float(marks.post().position.x).is_equal(100.0 - KeywordMarks.POST_OUT)
	var start: float = marks.post().get_global_rect().get_center().x
	var end: float = pins[2].get_global_rect().get_center().x
	_assert_continuous(_link_rects(marks), start, end, blocked)
	assert_int(_link_rects(marks).size()).is_equal(2)
	# The last ticket's foot full: its pin hides, the chain runs on to its pin place.
	blocked.assign([Rect2(104, 474, 20, 22), Rect2(358, 474, 104, 22)])
	marks.lay_out(tickets)
	assert_bool(pins[2].visible).is_false()
	assert_bool(pins[1].visible).is_true()
	var place: float = 356.0 + KeywordMarks.PIN_LEFT + MorningPin.SIDE / 2.0
	_assert_continuous(_link_rects(marks), start, place, blocked)
	# The ghost's slot is skipped: no pin there, the line still from the row's first ticket left.
	blocked.clear()
	var dragged: Dictionary[int, Rect2] = tickets.duplicate()
	dragged.erase(0)
	marks.lay_out(dragged, PackedInt32Array([0]))
	assert_bool(pins[0].visible).is_false()
	assert_float(marks.post().position.x).is_equal(228.0 - KeywordMarks.POST_OUT)
	_assert_continuous(
		_link_rects(marks),
		marks.post().get_global_rect().get_center().x,
		pins[2].get_global_rect().get_center().x,
		blocked
	)
	tickets.erase(2)
	marks.lay_out(tickets)
	assert_bool(marks.post().visible).is_false()
	assert_array(marks.links()).is_empty()
	for pin: MorningPin in pins:
		assert_bool(pin.visible).is_false()


## On Big basket's scaled 8-slot row the line scales with the tickets: each pin keeps its place on
## its ticket's foot, the chain and the post scale with them and the chain still runs from the post
## to the last pin.
func test_the_line_follows_a_scaled_row() -> void:
	var screen: ShiftScreen = await _screen()
	screen._debug.give_upgrade("big_basket")
	await _frames(2)
	var ids: Array[String] = [
		"tea_bags", "bread", "milk", "cereal", "coffee", "milk", "bread", "potatoes"
	]
	await _place(screen, ids)
	var marks: KeywordMarks = _marks(screen)
	var morning: PackedInt32Array = marks.morning_slots()
	assert_int(morning.size()).is_equal(7)
	var first: Rect2 = _ticket(screen, 0)
	var by: float = first.size.y / PriceSticker.SIZE.y
	assert_float(by).is_less(1.0)
	var last_end: float = -INF
	for index: int in range(morning.size()):
		var pin: MorningPin = marks.pins()[index]
		assert_bool(pin.is_visible_in_tree()).is_true()
		var ticket: Rect2 = _ticket(screen, morning[index])
		var rect: Rect2 = pin.get_global_rect()
		assert_float(rect.size.x).is_equal_approx(MorningPin.SIDE * by, 0.01)
		assert_float(rect.position.x).is_equal_approx(
			ticket.position.x + KeywordMarks.PIN_LEFT * by, 1.0
		)
		assert_float(rect.position.y).is_equal_approx(
			ticket.end.y - KeywordMarks.PIN_OVER * by, 1.0
		)
		assert_float(rect.end.x).is_less(ticket.end.x)
		assert_float(rect.position.x).is_greater(last_end)
		assert_bool(SCREEN_RECT.encloses(rect)).is_true()
		last_end = rect.end.x
	var post: Rect2 = marks.post().get_global_rect()
	assert_float(post.size.y).is_equal_approx(MorningPin.SIDE * by, 0.01)
	assert_bool(SCREEN_RECT.encloses(post)).is_true()
	for link: MorningLink in marks.links():
		assert_float(link.get_global_rect().size.y).is_equal_approx(MorningLink.RING.y * by, 0.01)
	_assert_continuous(
		_link_rects(marks),
		post.get_center().x,
		marks.pins()[-1].get_global_rect().get_center().x,
		screen._row_strip.mark_rects()
	)


## The line is the MORNING keyword's own on the belt: resting on a pin, the post or the chain
## (their place tall enough to hit) shows MORNING's tooltip and lights the whole line gold (as a
## ticket's MORNING chip does), and a right-click then opens the handbook at MORNING.
func test_the_line_explains_the_morning() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ROW)
	var marks: KeywordMarks = _marks(screen)
	var tips: GlyphTips = screen._glyph_tips
	var page: HandbookPage = screen.find_child("HandbookPage", false, false) as HandbookPage
	var link: MorningLink = marks.links()[0]
	# Between two pins, on the chain.
	var on_chain: Vector2 = Vector2(
		(
			(marks.pins()[0].get_global_rect().end.x + marks.pins()[1].get_global_rect().position.x)
			/ 2.0
		),
		link.get_global_rect().get_center().y
	)
	assert_float(link.hover_rect().size.y).is_greater_equal(MorningMark.HOVER_HEIGHT)
	var targets: Dictionary[MorningMark, Vector2] = {
		marks.pins()[1]: marks.pins()[1].get_global_rect().get_center(),
		marks.post(): marks.post().get_global_rect().get_center(),
		link: on_chain,
	}
	for target: MorningMark in targets:
		assert_str(target.tip_text).is_equal(GlyphText.keyword_tip(CardText.MORNING_WORD))
		assert_object(tips.glyph_at(targets[target])).is_same(target)
		assert_bool(page.has_entry_for(target)).is_true()
		assert_str(page.entry_for_target(target).id).is_equal("morning")
	tips.point_at(on_chain)
	tips.show_tip(link)
	for part: MorningMark in _line(marks):
		assert_bool(part.is_lit()).is_true()
		assert_that(part.face_color()).is_equal(Palette.GOLD)
	tips.hide_tip()
	for part: MorningMark in _line(marks):
		assert_bool(part.is_lit()).is_false()
	# A ticket's own MORNING chip lights it too.
	var ticket_chip: KeywordChip = _item(screen, 0).sticker().summary().keywords()[0]
	assert_str(ticket_chip.keyword).is_equal(CardText.MORNING_WORD)
	tips.show_tip(ticket_chip)
	assert_bool(marks.pins()[1].is_lit()).is_true()
	assert_bool(link.is_lit()).is_true()
	tips.hide_tip()
	assert_bool(link.is_lit()).is_false()
	var pin: MorningPin = marks.pins()[2]
	tips.point_at(pin.get_global_rect().get_center())
	tips.show_tip(pin)
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = pin.get_global_rect().get_center()
	click.global_position = click.position
	tips._input(click)
	assert_bool(page.is_open()).is_true()
	assert_str(page.shown_entry().id).is_equal("morning")
	page.close()


## A PAIR clasp in a gap a batch or chain frame's side runs through draws over the frame, and it
## keeps clear of the frames' parts: the batch bars, the chain links, the chain's own clasps (a
## FEED's or TALLY's) and its knot plates; it still crosses its gap, clear of the tickets' text.
func test_a_pair_clasp_beside_a_frame_keeps_clear_of_its_parts(
	row: String,
	gap: Vector2i,
	_test_parameters := [
		["croissant,bread,butter", Vector2i(1, 2)],
		["yogurt,banana,banana", Vector2i(0, 1)],
		["strawberries,banana,banana,yogurt", Vector2i(2, 3)],
		["yogurt,banana,banana,strawberries", Vector2i(0, 1)],
		["yogurt,banana,banana,wonky_carrot", Vector2i(0, 1)],
	]
) -> void:
	var screen: ShiftScreen = await _screen()
	var ids: Array[String] = []
	ids.assign(row.split(","))
	await _place(screen, ids)
	var marks: KeywordMarks = _marks(screen)
	var index: int = marks.clasp_gaps().find(gap)
	assert_int(index).override_failure_message(str(marks.clasp_gaps())).is_not_equal(-1)
	if index < 0:
		return
	var clasp: TextureRect = marks.clasps()[index]
	assert_bool(clasp.is_visible_in_tree()).is_true()
	var rect: Rect2 = clasp.get_global_rect()
	var layer: PlanningLayer = _layer(screen)
	var to_global: Transform2D = layer.get_global_transform()
	var parts: Array[Rect2] = []
	var framed: bool = false
	for chains: bool in [false, true]:
		for frame: BatchFrame in layer.frames(chains):
			if not frame.visible:
				continue
			framed = framed or (to_global * frame.frame_rect()).intersects(rect)
			var shown: Array[Rect2] = frame.bar_rects().duplicate()
			var chain: ChainFrame = frame as ChainFrame
			if chain != null:
				shown.append_array(chain.link_rects())
				shown.append_array(chain.clasp_rects())
				shown.append_array(chain.plate_rects())
			for part: Rect2 in shown:
				parts.append(to_global * part)
	assert_bool(framed).override_failure_message("no frame beside the clasp").is_true()
	for part: Rect2 in parts:
		var met: String = "%s meets %s" % [rect, part]
		assert_bool(rect.intersects(part)).override_failure_message(met).is_false()
	# Over the frames: the batch box comes before the chains' box, the marks last in theirs.
	var chain_box: Node = marks.get_parent()
	assert_int(marks.get_index()).is_equal(chain_box.get_child_count() - 1)
	var batch_box: Node = layer.find_child("BatchFrames", false, false)
	assert_int(batch_box.get_index()).is_less(chain_box.get_index())
	var left: Rect2 = _ticket(screen, gap.x)
	var right: Rect2 = _ticket(screen, gap.y)
	assert_float(rect.position.x).is_less(left.end.x)
	assert_float(rect.end.x).is_greater(right.position.x)
	assert_float(rect.position.y).is_greater(left.position.y)
	assert_float(rect.end.y).is_less(left.end.y)
	for slot: int in [gap.x, gap.y]:
		var sticker: PriceSticker = _item(screen, slot).sticker()
		var text: Rect2 = sticker.get_global_transform() * sticker.summary_text_rect()
		assert_bool(rect.intersects(text)).override_failure_message(str(slot)).is_false()


## A row with neither shows no pin, no post, no chain and no clasp: Breakfast items open it, but
## no card reads the MORNING.
func test_a_plain_row_shows_no_marks() -> void:
	var screen: ShiftScreen = await _screen()
	await _place(screen, ["bread", "milk", "potatoes"])
	var marks: KeywordMarks = _marks(screen)
	assert_bool(marks.post().is_visible_in_tree()).is_false()
	assert_array(marks.links()).is_empty()
	assert_array(marks.pins()).is_empty()
	assert_array(marks.clasps()).is_empty()


static func _marks(screen: ShiftScreen) -> KeywordMarks:
	return KeywordMarks.of(_layer(screen))


static func _layer(screen: ShiftScreen) -> PlanningLayer:
	return screen._stage.planning_layer


## The chain's stretches shown, global rects, left to right.
static func _link_rects(marks: KeywordMarks) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for link: MorningLink in marks.links():
		rects.append(link.get_global_rect())
	rects.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.x < b.position.x)
	return rects


## Every part of the MORNING's line shown: its pins, post and chain.
static func _line(marks: KeywordMarks) -> Array[MorningMark]:
	var parts: Array[MorningMark] = []
	for pin: MorningPin in marks.pins():
		if pin.visible:
			parts.append(pin)
	parts.append(marks.post())
	parts.append_array(marks.links())
	return parts


## The chain `links` (global, left to right) covers `start` to `end` but for the hanging `marks`
## (each grown by KeywordMarks.PIN_GAP): every gap between two stretches, and an end left open,
## lies in one, and nothing of it runs past either end.
func _assert_continuous(links: Array[Rect2], start: float, end: float, marks: Array[Rect2]) -> void:
	assert_array(links).is_not_empty()
	if links.is_empty():
		return
	assert_float(links[0].position.x).is_equal_approx(start, 1.0)
	assert_float(links[-1].end.x).is_less_equal(end + 1.0)
	var at: float = start
	var spans: Array[Vector2] = []
	for link: Rect2 in links:
		spans.append(Vector2(link.position.x, link.end.x))
	spans.append(Vector2(end, end))
	for span: Vector2 in spans:
		if span.x > at + 1.0:
			var covered: bool = false
			for mark: Rect2 in marks:
				var grown: float = KeywordMarks.PIN_GAP + 1.0
				covered = (
					covered or (mark.position.x - grown <= at and mark.end.x + grown >= span.x)
				)
			var open: String = "the chain is open from %s to %s" % [at, span.x]
			assert_bool(covered).override_failure_message(open).is_true()
		at = maxf(at, span.y)


static func _row(ids: String) -> Array[CardInstance]:
	var row: Array[CardInstance] = []
	for id: String in ids.split(","):
		row.append(CardInstance.new(load(CARDS % id) as CardDefinition, row.size() + 1))
	return row


func _model(ids: String) -> PlanningModel:
	var row: Array[CardInstance] = _row(ids)
	var cards: Array[CardDefinition] = []
	for card: CardInstance in row:
		cards.append(card.definition)
	var none_upgrades: Array[UpgradeDefinition] = []
	var none_events: Array[InspectionDefinition] = []
	return PlanningModel.build(Scoring.score(row), cards, none_upgrades, none_events, null)


## `slot`'s ticket's global rect.
static func _ticket(screen: ShiftScreen, slot: int) -> Rect2:
	var sticker: PriceSticker = _item(screen, slot).sticker()
	return sticker.get_global_transform() * Rect2(Vector2.ZERO, sticker.size)


static func _item(screen: ShiftScreen, slot: int) -> ItemView:
	return screen._row_views[slot] as ItemView


func _screen() -> ShiftScreen:
	if FileAccess.file_exists(_folder.path_join(SaveService.RUN_FILE)):
		DirAccess.remove_absolute(_folder.path_join(SaveService.RUN_FILE))
	_runner = scene_runner(SCREEN)
	var screen: ShiftScreen = _runner.scene()
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
