class_name DeskCalendarArt
extends RefCounted
## The desk calendar's pixel art (left column v2, the user's pick of 2026-11-09: mock-up
## docs/art/mockups/left_column_v2.html, its desk() and deskChange()): a small flip calendar
## standing on the register's top, painted in art pixels into an Image (one image pixel per art
## pixel; DayCalendar draws it at DayCalendarArt.CELL stage px each). Two steel rings on top, a
## band in the day's kind's colour (DayCalendarArt.band: grey normal, tomato inspection, mustard
## review, green boon, teal for a passed inspection's EARNED), then the page: SHIFT at its top
## left, the kind's sign at its top right (warning, boon coin, check; none on a normal day) and
## the day's number big and centred in the bold digits (DIGITS at NUMBER_CELL font px per art
## px). No kind word: the band, the sign and the tooltip say it. Under the number the week's day
## pips (back after the user's play test of 2026-11-10: they show how far the week's last day
## is), one square per day of the week, centred: a hollow one for a day to come (the week's last
## day's in the review's mustard), today's gold in an ink frame, a passed day's green, a slip's
## tomato, a played day with no result grey. Under the page a paper edge while a day is left in
## the week (EDGES_MAX rows at most: the pips count the days), then its dark stand. The flip
## (paint_flip): the old page lifts up over the rings in whole art px rows, showing its back, the
## new page under it. On a payday (Page.payday; the user's pick of 2026-11-10, mock-up
## payday_day.html round 2, "Calendar, in the review band") the band grows down over the page's
## head (PAYDAY_ROWS rows, the review's mustard with a dark foot row) and carries PAYDAY in the
## chunky capitals in ink, in place of SHIFT and the sign; the number and the pips stay where they
## are. Palette colours only, no alpha. Display only.

## The calendar in art px, and the image's room above it for the flipping page's back.
const SIZE := 46
const FLIP_ROOM := 8
## The rings' top rows, the band's rows (BAND_Y .. PAGE_Y - 1) and the page's (PAGE_Y ..
## PAGE_FOOT, its ink foot row), the edges' first row and the stand's.
const BAND_Y := 3
const PAGE_Y := 7
const PAGE_FOOT := 42
const EDGES_Y := 43
const EDGES_MAX := 1
const STAND_Y := 44
## The rings' left columns.
const RINGS: Array[int] = [8, 35]
## The page's word (SHIFT since the words pass v1.33: the turn is a shift, never a day; in the 3x5
## capitals so it clears the sign), its sheet and its top left on the page (from PAGE_Y), the
## sign's top (from PAGE_Y) and right margin, the number's top (from PAGE_Y) and its font px per
## art px.
const PAGE_WORD := "SHIFT"
const PAGE_WORD_SHEET := PixelWords.Sheet.CAPS
const DAY_AT := Vector2i(3, 3)
const SIGN_TOP := 1
const SIGN_MARGIN := 2
const NUMBER_TOP := 13
const NUMBER_CELL := 2
## The week's pips: PIP art px squares from PIPS_TOP (from PAGE_Y), PIP_GAP apart (PIP_GAP_TIGHT
## when a long week would not fit the page), centred.
const PIP := 4
const PIP_GAP := 2
const PIP_GAP_TIGHT := 1
const PIPS_TOP := 30
## Payday's band on the page's head: its rows from the page's top (the last one its dark foot)
## and the word's top row (from PAGE_Y), centred.
const PAYDAY_WORD := "PAYDAY"
const PAYDAY_ROWS := 12
const PAYDAY_WORD_TOP := 2


## The calendar with `page` on it and `edges` paper edges under it, into `image` (SIZE wide,
## SIZE + FLIP_ROOM tall: the calendar's rows start FLIP_ROOM down).
static func paint_desk(image: Image, page: DayCalendarArt.Page, edges: int) -> void:
	image.fill(Color(0, 0, 0, 0))
	_paint_base(image, edges)
	paint_page(image, page, PAGE_Y + FLIP_ROOM)
	_paint_band(image, page.look)


## The flip `k` (0 .. 1) of the way from `old` to `page`: the first half lifts the old page's rows
## up toward the band (squashed in whole rows); the second shows its back rising over the rings.
## The new page shows under it all along.
static func paint_flip(
	image: Image, old: DayCalendarArt.Page, page: DayCalendarArt.Page, edges: int, k: float
) -> void:
	paint_desk(image, page, edges)
	var top: int = PAGE_Y + FLIP_ROOM
	var full: int = PAGE_FOOT - PAGE_Y + 1
	if k < 0.5:
		var rows: int = maxi(1, roundi(full * (1.0 - k * 2.0)))
		var sheet: Image = Image.create(SIZE, full, false, Image.FORMAT_RGBA8)
		paint_page(sheet, old, 0)
		for row: int in range(rows):
			var source: int = floori(row * full / float(rows))
			image.blit_rect(sheet, Rect2i(0, source, SIZE, 1), Vector2i(0, top + row))
	else:
		var rows: int = maxi(1, roundi(PAGE_Y * (k - 0.5) * 2.0 * 1.6))
		image.fill_rect(Rect2i(0, top - rows - 1, SIZE, rows + 1), Palette.INK)
		image.fill_rect(Rect2i(1, top - rows, SIZE - 2, rows), Palette.CREAM)
		image.fill_rect(Rect2i(1, top - rows, SIZE - 2, 1), Palette.CREAM_SHADE)
	_paint_band(image, page.look)


## One page at row `top` of `image`: ink sides and foot, paper with a cream top row, SHIFT, the
## sign and the number.
static func paint_page(image: Image, page: DayCalendarArt.Page, top: int) -> void:
	var rows: int = PAGE_FOOT - PAGE_Y + 1
	image.fill_rect(Rect2i(0, top, SIZE, rows), Palette.INK)
	image.fill_rect(Rect2i(1, top, SIZE - 2, rows - 1), Palette.PAPER)
	image.fill_rect(Rect2i(1, top, SIZE - 2, 1), Palette.CREAM)
	if page.day <= 0:
		return
	if page.payday:
		_paint_payday(image, top)
	else:
		DayCalendarArt.paint_words(
			image, PAGE_WORD, PAGE_WORD_SHEET, 1, DAY_AT + Vector2i(0, top), Palette.INK_LIGHT
		)
		var icon: Image = DayCalendarArt.icon(page.mark)
		if icon != null:
			DayCalendarArt.paint_icon(image, icon, sign_rect(page).position + Vector2i(0, top))
	var number: Rect2i = number_rect(page)
	DayCalendarArt.paint_words(
		image,
		str(page.day),
		PixelWords.Sheet.DIGITS,
		NUMBER_CELL,
		number.position + Vector2i(0, top),
		Palette.INK
	)
	var squares: Array[Rect2i] = pip_rects(page.pips.size())
	for index: int in range(squares.size()):
		var square: Rect2i = Rect2i(squares[index].position + Vector2i(0, top), squares[index].size)
		var colours: Array[Color] = pip_colours(page.pips[index], index == squares.size() - 1)
		image.fill_rect(square, colours[0])
		image.fill_rect(square.grow(-1), colours[1])


## The pips' rects on the page (art px from the page's top left) for a week of `count` days.
static func pip_rects(count: int) -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	if count <= 0:
		return rects
	var gap: int = PIP_GAP
	if count * PIP + (count - 1) * gap > SIZE - 4:
		gap = PIP_GAP_TIGHT
	var left: int = floori((SIZE - (count * PIP + (count - 1) * gap)) / 2.0)
	for index: int in range(count):
		rects.append(Rect2i(left + index * (PIP + gap), PIPS_TOP, PIP, PIP))
	return rects


## A pip's frame and inside: hollow for a day to come (`last`: the week's last day, in the
## review's mustard), gold in ink for today, green for PAID, tomato for a slip, grey for a played
## day with no result.
static func pip_colours(look: DayCalendarArt.PipLook, last: bool) -> Array[Color]:
	match look:
		DayCalendarArt.PipLook.TODAY:
			return [Palette.INK, Palette.MUSTARD]
		DayCalendarArt.PipLook.PAID:
			return [Palette.GREEN_DARK, Palette.GOOD]
		DayCalendarArt.PipLook.SLIP:
			return [Palette.TOMATO_DARK, Palette.TOMATO]
		DayCalendarArt.PipLook.PAST:
			return [Palette.INK_LIGHT, Palette.STEEL_LIGHT]
	return [Palette.MUSTARD_DARK if last else Palette.STEEL_LIGHT, Palette.PAPER]


## Payday's band on the head of the page at row `top`: the review band's mustard down
## PAYDAY_ROWS rows, its dark foot row, and PAYDAY in ink.
static func _paint_payday(image: Image, top: int) -> void:
	var colours: Array[Color] = DayCalendarArt.band(DayCalendarArt.Look.REVIEW)
	image.fill_rect(Rect2i(1, top, SIZE - 2, PAYDAY_ROWS), colours[0])
	image.fill_rect(Rect2i(1, top + PAYDAY_ROWS - 1, SIZE - 2, 1), colours[1])
	DayCalendarArt.paint_words(
		image,
		PAYDAY_WORD,
		PixelWords.Sheet.CHUNKY_CAPS,
		1,
		payday_word_rect().position + Vector2i(0, top),
		Palette.INK
	)


## Payday's band on the page (art px from the page's top left).
static func payday_band_rect() -> Rect2i:
	return Rect2i(1, 0, SIZE - 2, PAYDAY_ROWS)


## PAYDAY's rect on the page (art px from the page's top left), centred on the band.
static func payday_word_rect() -> Rect2i:
	var size: Vector2i = PixelWords.font_size_of(PAYDAY_WORD, PixelWords.Sheet.CHUNKY_CAPS)
	return Rect2i(Vector2i(floori((SIZE - size.x) / 2.0), PAYDAY_WORD_TOP), size)


## The sign's rect on the page (art px from the page's top left), empty for none (and on a
## payday: its band takes the head).
static func sign_rect(page: DayCalendarArt.Page) -> Rect2i:
	var icon: Image = DayCalendarArt.icon(page.mark)
	if icon == null or page.payday:
		return Rect2i()
	var size: Vector2i = icon.get_size()
	return Rect2i(Vector2i(SIZE - SIGN_MARGIN - size.x, SIGN_TOP), size)


## The number's rect on the page (art px from the page's top left), centred.
static func number_rect(page: DayCalendarArt.Page) -> Rect2i:
	var size: Vector2i = PixelWords.font_size_of(str(page.day), PixelWords.Sheet.DIGITS)
	size *= NUMBER_CELL
	return Rect2i(Vector2i(floori((SIZE - size.x) / 2.0), NUMBER_TOP), size)


## The page word's (SHIFT's) rect on the page (art px from the page's top left).
static func day_rect() -> Rect2i:
	return Rect2i(DAY_AT, PixelWords.font_size_of(PAGE_WORD, PAGE_WORD_SHEET))


## The edges shown for `days_left` days left in the week.
static func edges_for(days_left: int) -> int:
	return clampi(days_left, 0, EDGES_MAX)


## The stand and the back board under the page, and `edges` paper edges (cream and cream shade
## by turns) from the page's foot down.
static func _paint_base(image: Image, edges: int) -> void:
	var at: int = FLIP_ROOM
	image.fill_rect(Rect2i(1, at + EDGES_Y, SIZE - 2, STAND_Y - EDGES_Y), Palette.INK)
	image.fill_rect(Rect2i(1, at + STAND_Y, SIZE - 2, SIZE - STAND_Y), Palette.INK)
	image.fill_rect(Rect2i(2, at + STAND_Y, SIZE - 4, 1), Palette.INK_LIGHT)
	for index: int in range(edges_for(edges)):
		var colour: Color = Palette.CREAM if index % 2 == 0 else Palette.CREAM_SHADE
		image.fill_rect(Rect2i(1, at + EDGES_Y + index, SIZE - 2, 1), colour)


## The band in `look`'s colour (lit top row) in an ink frame, and the two rings over it.
static func _paint_band(image: Image, look: DayCalendarArt.Look) -> void:
	var at: int = FLIP_ROOM
	var colours: Array[Color] = DayCalendarArt.band(look)
	image.fill_rect(Rect2i(0, at + BAND_Y, SIZE, PAGE_Y - BAND_Y), Palette.INK)
	image.fill_rect(Rect2i(1, at + BAND_Y + 1, SIZE - 2, PAGE_Y - BAND_Y - 1), colours[0])
	image.fill_rect(Rect2i(1, at + BAND_Y + 1, SIZE - 2, 1), colours[2])
	for x: int in RINGS:
		image.fill_rect(Rect2i(x, at, 3, 5), Palette.INK)
		image.fill_rect(Rect2i(x + 1, at, 1, 4), Palette.STEEL_LIGHT)
		image.fill_rect(Rect2i(x + 1, at, 1, 1), Palette.STEEL_HIGHLIGHT)
