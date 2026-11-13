class_name DayCalendar
extends Control
## The day calendar (v1.17, in place of v0.70's day chip and the week chip's day pips), since
## left column v2 (the user's pick of 2026-11-09: mock-up docs/art/mockups/left_column_v2.html) a
## small desk flip calendar standing on the register's top at the column's right
## (ShiftStage.DESK_CALENDAR_RECT; DeskCalendarArt): two rings, a band in the day's kind's colour
## (grey normal, tomato inspection, mustard review, green boon), DAY and the day's number big,
## the kind's sign (warning, boon coin; none on a normal day) and no kind word; the week's day
## pips under the number, and a paper edge under the page while a day is left in the week. One
## size for every day, kind and name. A payday's page (show_inspections' `payday`; the user's pick
## of 2026-11-10) carries PAYDAY on a mustard band over its head, in place of DAY and the sign.
##
## It keeps the day chip's work: hovering it reports hovered / unhovered; resting the pointer on
## it for HOVER_OPEN_S opens today's slip (`long_hovered`, play test 2026-11-09: the slip in place
## of the native tooltip, which is gone) and tapping it drops or pins it (`pressed`, DaySlip);
## set_relation rings it in gold (#71: the hovered item's effect comes from a day event, its name
## on the page); the bonus
## ticket's pill and a Day off's SKIP tag stand over the pad, at its right (DayTags; a passed
## inspection's EARNED turns the band teal with the check mark). The week's day pips (show_week:
## today's result, the days left) are back on the page under the number (the user's play test of
## 2026-11-10; DeskCalendarArt.pip_rects): after a shift's verdict
## flash() rings the pad in the result's light (#119: green PAID, tomato slip) with PAID's sound or
## a slip's denied (only the sound under reduced motion); until then (hold_result) today's result
## waits.
##
## The day change: when the day shown goes up by one, the old page waits until WeekFlow says
## planning can show it (play_change), then flips up over the rings in whole art px rows
## (FLIP_SECONDS), the new page under it. A first show, a resume, a jump or reduced motion snaps to
## the new page.

## The pointer entered or left the pad.
signal hovered
signal unhovered
## The pad was tapped (today's slip drops, DaySlip).
signal pressed
## The pointer rested on the pad or its tags for HOVER_OPEN_S (today's slip opens, DaySlip).
signal long_hovered
## The SKIP tag was tapped (#132, a Day off pin).
signal skip_pressed

## The kinds' words (DayCalendarArt prints them in capitals).
const NORMAL_WORD := "Normal shift"
const EARNED_WORD := "Passed"
## The bonus ticket's line on today's slip (WeekFlow.bonus_line): the pill's whole words, or a
## passed inspection's.
const PILL_TIP := "QUOTA MET › +1 EXTRA DRAW"
const EARNED_TIP := "%s passed"
## The long hover that opens today's slip (s).
const HOVER_OPEN_S := 0.45
## The tags' gap over the pad.
const TAG_GAP := 4.0
## The gold ring (#71) and the flash's ring.
const RING_WIDTH := 2.0
## flash(): how long the light lasts (s), the glow's widest reach (px) and opacity.
const FLASH := 0.8
const GLOW_REACH := 8.0
const GLOW_ALPHA := 0.6
## The page's flip up over the rings.
const FLIP_SECONDS := 0.36
const CHANGE_END := FLIP_SECONDS

## Today's result waits for flash(): its pip shows as today's (WeekFlow.show_chips, counting).
var hold_result: bool = false
## No day change animation, no flash motion.
var reduced_motion: bool = false
## The bonus pill and the SKIP tag, right of the pad.
var tags: DayTags

var _page: DayCalendarArt.Page = DayCalendarArt.Page.new()
## The old page while a change waits or plays.
var _old: DayCalendarArt.Page
var _pending: bool = false
var _change_t: float = -1.0
var _inspections: Array[InspectionDefinition] = []
var _day: int = 0
var _max_day: int = 1
## The day is a payday: its page reads PAYDAY.
var _payday: bool = false
## The pad's width in art px (its shadow column aside): every kind's and name's.
var _width: int = 0
var _bonus: InspectionTag.Bonus = InspectionTag.Bonus.NONE
var _cause: int = -1
var _ringed: bool = false
var _squeezed: bool = false
## The long hover's wait (started as the pointer comes onto the pad or a tag; tests end it by
## emitting its timeout).
var _dwell: Timer
var _pips: Array[WeekCardModel.Pip] = []
var _flash_t: float = -1.0
var _flash_index: int = -1
var _image: Image
var _texture: ImageTexture


func _init() -> void:
	name = "DayCalendar"
	# PASS, not IGNORE: the hover needs the mouse.
	mouse_filter = Control.MOUSE_FILTER_PASS
	ArtStyle.use_pixel_material(self)
	_dwell = Timer.new()
	_dwell.name = "Dwell"
	_dwell.one_shot = true
	_dwell.wait_time = HOVER_OPEN_S
	_dwell.timeout.connect(_on_dwell)
	add_child(_dwell)
	hovered.connect(_start_dwell)
	unhovered.connect(_dwell.stop)
	tags = DayTags.new()
	add_child(tags)
	tags.skip_pressed.connect(skip_pressed.emit)
	tags.minimum_size_changed.connect(_place_tags)
	# The tags stand outside the pad's rect: hovering one hovers the calendar (the old chip held
	# them), and a tap on the pill passes up to the pad (_gui_input).
	for tag: Control in [tags.pill(), tags.skip_tag()]:
		tag.mouse_entered.connect(hovered.emit)
		tag.mouse_exited.connect(unhovered.emit)
	visible = false
	set_process(false)
	_resize()


## Shows the shift's day events by their kind: "Inspection", "Review" for several, a boon day's
## boon name, "Normal day" without one (hovering shows each one's name and notice). `day_number`
## (1-based; 0 for a run without weeks: only a day with events shows); `_pool` (every day event
## the run may draw) is no longer needed (the desk calendar prints no name); `max_day` is the run's
## last day; `payday`: the day is a payday (its page reads PAYDAY). A day one past the one shown
## waits for play_change.
func show_inspections(
	inspections: Array[InspectionDefinition],
	day_number: int = 0,
	_pool: Array[InspectionDefinition] = [],
	max_day: int = 0,
	payday: bool = false
) -> void:
	var before: DayCalendarArt.Page = _page.copy()
	var next_day: bool = _day > 0 and day_number == _day + 1
	if day_number != _day and not next_day:
		_snap()
	_day = day_number
	_max_day = maxi(maxi(max_day, day_number), 1)
	_inspections = inspections.duplicate()
	_payday = payday
	_cause = -1
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if day_number > 0 else CURSOR_ARROW
	tags.pill().mouse_default_cursor_shape = mouse_default_cursor_shape
	visible = not inspections.is_empty() or day_number > 0
	_width = DeskCalendarArt.SIZE
	_refresh_page()
	if next_day and not _pending and _change_t < 0.0:
		_old = before
		_pending = true
	_resize()


## The bonus ticket (#77 machine v2): NONE hides the pill; PROMISED shows "PASS › [ticket] +1
## BONUS TICKET"; EARNED turns the binding teal, the page "✓ PASSED", the pill "+1 BONUS TICKET".
func show_bonus(state: InspectionTag.Bonus) -> void:
	_bonus = state
	tags.show_bonus(state)
	_refresh_page()
	_place_tags()


func bonus_state() -> InspectionTag.Bonus:
	return _bonus


## Every text the calendar shows, the pill's included ("Inspection PASS › +1 BONUS TICKET").
func full_text() -> String:
	var pill: String = tags.pill_text()
	return text() if pill.is_empty() else "%s %s" % [text(), pill]


## Rings the pad in gold (#71), or takes the ring off. `cause`: the shift's day event (its index)
## that causes the hovered item's effect: the page shows its sign until the ring comes off (its
## name is the page's word).
func set_relation(related: bool, cause: int = -1) -> void:
	_ringed = related
	_cause = cause if related and cause >= 0 and cause < _inspections.size() else -1
	_refresh_page()


func has_relation() -> bool:
	return _ringed


## The day shown, 0 for none.
func day() -> int:
	return _day


## The page's word: the day's kind, the named cause's name, or EARNED_WORD.
func text() -> String:
	return _page.word


## Keeps the tags within `width` px (ShiftStage: the column's room left of the pad's right edge):
## the pad never shrinks; the pill gives up its "PASS ›", then its words down to "+1".
func fit_width(width: float) -> void:
	tags.fit(width)
	_squeezed = reserved_width() > width
	_place_tags()


## The width the tags over the pad keep (DayTags.width), at least the pad's.
func reserved_width() -> float:
	return maxf(size.x, tags.width())


## Whether fit_width had less than reserved_width even with the pill's short forms.
func is_shortened() -> bool:
	return _squeezed


## The page's look (DayCalendarArt.Look): the binding's colour.
func look() -> DayCalendarArt.Look:
	return _page.look


## Shows `model`'s day pips (WeekCardModel.pips): one per day of the week.
func show_week(model: WeekCardModel) -> void:
	_pips = model.pips()
	if hold_result:
		for index: int in range(_pips.size() - 1, -1, -1):
			if _pips[index] == WeekCardModel.Pip.PAID or _pips[index] == WeekCardModel.Pip.SLIP:
				_pips[index] = WeekCardModel.Pip.NOW
				break
	_refresh_page()


## The pips shown, in order.
func pips() -> Array[WeekCardModel.Pip]:
	return _pips.duplicate()


## Lights today's result pip (a shift's verdict, #119) with its sound: PAID's, or a SLIP's
## denied. With reduced motion only the sound plays. Nothing for a week with no result today.
func flash(reduced: bool) -> void:
	_flash_index = -1
	for index: int in range(_pips.size()):
		if _pips[index] == WeekCardModel.Pip.PAID or _pips[index] == WeekCardModel.Pip.SLIP:
			_flash_index = index  # The last result is today's.
	if _flash_index < 0:
		return
	Sfx.play_at(self, "stamp_paid" if _pips[_flash_index] == WeekCardModel.Pip.PAID else "denied")
	if reduced:
		return
	_flash_t = 0.0
	set_process(true)
	queue_redraw()


func is_flashing() -> bool:
	return _flash_t >= 0.0


## Moves the flash and the day change on by `seconds` (tests; _process moves them by the frame's).
func advance(seconds: float) -> void:
	if _flash_t >= 0.0:
		_flash_t += seconds
		if _flash_t >= FLASH:
			_flash_t = -1.0
	if _change_t >= 0.0:
		_change_t += seconds
		if _change_t >= CHANGE_END:
			_change_t = -1.0
			_old = null
	set_process(_flash_t >= 0.0 or _change_t >= 0.0)
	queue_redraw()


## Plays the waiting day change (the old page flips up over the rings; `animate` false or reduced
## motion: the new page at once). WeekFlow calls it once planning can show it.
func play_change(animate: bool) -> void:
	if not _pending:
		return
	_pending = false
	if not animate or reduced_motion:
		_snap()
		return
	_change_t = 0.0
	set_process(true)
	queue_redraw()


## Whether a day change waits or plays.
func is_changing() -> bool:
	return _pending or _change_t >= 0.0


## The parts' rects on the canvas (global), for layout tests: "pad", "number", "day" (DAY; empty
## on a payday), "payday" and "payday_band" (PAYDAY and its band; empty on other days),
## "signs" (an Array of Rect2: the sign, none on a normal day or a payday), "tags" (empty while
## none shows),
## "pips" (an Array of Rect2, one per day of the week), "flip" (the flipping page's room, empty
## when none flips); and "edges", the paper edges under the
## page (an int).
func part_rects() -> Dictionary:
	var to_global: Transform2D = get_global_transform()
	var cell: float = DayCalendarArt.CELL
	var page_top: Vector2i = Vector2i(0, DeskCalendarArt.PAGE_Y)
	var art: Callable = func(rect: Rect2i) -> Rect2:
		var at: Vector2i = rect.position + page_top
		return to_global * Rect2(Vector2(at) * cell, Vector2(rect.size) * cell)
	var signs: Array[Rect2] = []
	var mark: Rect2i = DeskCalendarArt.sign_rect(_page)
	if mark.has_area():
		signs.append(art.call(mark))
	var tag_rect: Rect2 = Rect2()
	if tags.get_children().any(func(part: Node) -> bool: return (part as Control).visible):
		tag_rect = tags.get_global_rect()
	var flip_rect: Rect2 = Rect2()
	if _change_t >= 0.0:
		var room: Vector2 = Vector2(0, -DeskCalendarArt.FLIP_ROOM) * cell
		var rows: int = DeskCalendarArt.PAGE_FOOT + 1 + DeskCalendarArt.FLIP_ROOM
		flip_rect = to_global * Rect2(room, Vector2(DeskCalendarArt.SIZE, rows) * cell)
	return {
		"pad": get_global_rect(),
		"number": art.call(DeskCalendarArt.number_rect(_page)),
		"day": Rect2() if _page.payday else art.call(DeskCalendarArt.day_rect()),
		"payday": art.call(DeskCalendarArt.payday_word_rect()) if _page.payday else Rect2(),
		"payday_band": art.call(DeskCalendarArt.payday_band_rect()) if _page.payday else Rect2(),
		"signs": signs,
		"pips": DeskCalendarArt.pip_rects(_page.pips.size()).map(art),
		"tags": tag_rect,
		"flip": flip_rect,
		"edges": DeskCalendarArt.edges_for(_days_left()),
	}


## The paper edges under the page: one per day left in the week after today (DeskCalendarArt
## shows EDGES_MAX at most).
func _days_left() -> int:
	var today: int = _pips.find(WeekCardModel.Pip.NOW)
	if today < 0:
		for index: int in range(_pips.size()):
			if _pips[index] != WeekCardModel.Pip.TODO:
				today = index
	return _pips.size() - 1 - today if today >= 0 else 0


func _process(delta: float) -> void:
	advance(delta)


func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if _day > 0 and press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_dwell.stop()  # A tap decides: the dwell never reopens a slip the player just closed.
		pressed.emit()


func _notification(what: int) -> void:
	# The pad's own rect: the tags report their own hover (_init).
	if what == NOTIFICATION_MOUSE_ENTER_SELF:
		hovered.emit()
	elif what == NOTIFICATION_MOUSE_EXIT_SELF:
		unhovered.emit()


func _draw() -> void:
	if _width <= 0:
		return
	var side: int = DeskCalendarArt.SIZE
	var full: Vector2i = Vector2i(side, side + DeskCalendarArt.FLIP_ROOM)
	if _image == null or _image.get_size() != full:
		_image = Image.create(full.x, full.y, false, Image.FORMAT_RGBA8)
		_texture = null
	if _pending and _old != null:
		DeskCalendarArt.paint_desk(_image, _old, _days_left() + 1)
	elif _change_t >= 0.0 and _old != null:
		var k: float = clampf(_change_t / FLIP_SECONDS, 0.0, 1.0)
		DeskCalendarArt.paint_flip(_image, _old, _page, _days_left(), k)
	else:
		DeskCalendarArt.paint_desk(_image, _page, _days_left())
	if _texture == null:
		_texture = ImageTexture.create_from_image(_image)
	else:
		_texture.update(_image)
	var cell: float = DayCalendarArt.CELL
	var room: float = DeskCalendarArt.FLIP_ROOM * cell
	draw_texture_rect(_texture, Rect2(Vector2(0, -room), Vector2(full) * cell), false)
	var ring: Rect2 = Rect2(Vector2.ZERO, size).grow(-RING_WIDTH / 2.0)
	if _flash_t >= 0.0 and _flash_index >= 0:
		_draw_light(ring)
	elif _ringed:
		draw_rect(ring, Palette.GOLD, false, RING_WIDTH)


## The result's light: the pad's ring and a square glow round it, widening and fading.
func _draw_light(ring: Rect2) -> void:
	var k: float = _flash_t / FLASH
	var light: Color = _light_of(_pips[_flash_index])
	var glow: Rect2 = ring.grow(roundf(GLOW_REACH * k))
	draw_rect(glow, Color(light, GLOW_ALPHA * (1.0 - k)), false, RING_WIDTH * 2.0)
	draw_rect(ring, Color(light, 1.0 - k), false, RING_WIDTH)


## The page for the state shown: EARNED's, a named cause's, else the day's kind.
func _refresh_page() -> void:
	var page: DayCalendarArt.Page = _kind_page(_inspections)
	if _bonus == InspectionTag.Bonus.EARNED:
		page.look = DayCalendarArt.Look.EARNED
		page.mark = DayCalendarArt.Sign.CHECK
		page.word = EARNED_WORD
		page.both_sides = false
	elif _cause >= 0:
		var cause: InspectionDefinition = _inspections[_cause]
		page.word = cause.display_name
		page.mark = DayCalendarArt.Sign.BOON if cause.is_boon() else DayCalendarArt.Sign.WARNING
		page.both_sides = false
	page.day = _day
	page.payday = _payday and _day > 0
	page.pips.clear()
	for pip: WeekCardModel.Pip in _pips:
		page.pips.append(DayCalendarArt.pip_look(pip))
	_page = page
	queue_redraw()


## The page of a day with `events`, by its kind.
static func _kind_page(events: Array[InspectionDefinition]) -> DayCalendarArt.Page:
	var page: DayCalendarArt.Page = DayCalendarArt.Page.new()
	page.word = NORMAL_WORD
	match WeekCardModel.kind_of(events):
		WeekCardModel.Kind.REVIEW:
			page.look = DayCalendarArt.Look.REVIEW
			page.word = InspectionTag.REVIEW_CAPTION
			page.mark = DayCalendarArt.Sign.WARNING
			page.both_sides = true
		WeekCardModel.Kind.MALUS:
			page.look = DayCalendarArt.Look.INSPECTION
			page.word = InspectionTag.CAPTION
			page.mark = DayCalendarArt.Sign.WARNING
		WeekCardModel.Kind.BOON:
			page.look = DayCalendarArt.Look.BOON
			page.word = InspectionTag.kind_text(events)
			page.mark = DayCalendarArt.Sign.BOON
	return page


## The new page at once: no change waits or plays.
func _snap() -> void:
	_pending = false
	_change_t = -1.0
	_old = null
	set_process(_flash_t >= 0.0)
	queue_redraw()


func _resize() -> void:
	var cell: float = DayCalendarArt.CELL
	var wanted: Vector2 = Vector2.ONE * DeskCalendarArt.SIZE * cell
	if size != wanted:
		custom_minimum_size = wanted
		size = wanted
	_place_tags()


## The tags over the pad, their right edge on its right edge.
func _place_tags() -> void:
	if tags == null:
		return
	tags.reset_size()
	tags.size = tags.get_combined_minimum_size()
	tags.position = Vector2(size.x - tags.size.x, -tags.size.y - TAG_GAP)


func _start_dwell() -> void:
	if _day > 0 and is_visible_in_tree():
		_dwell.start(HOVER_OPEN_S)


func _on_dwell() -> void:
	long_hovered.emit()


static func _light_of(pip: WeekCardModel.Pip) -> Color:
	return Palette.GREEN_LIGHT if pip == WeekCardModel.Pip.PAID else Palette.TOMATO
