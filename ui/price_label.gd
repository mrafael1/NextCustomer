class_name PriceLabel
extends Control
## A price window's stuck label (price leak, variant C "STUCK LABEL" of mock-up price_leak.html,
## the user's pick of 2026-11-10: yellow paper, a leak of at most 11 art px): the paper a price
## too wide for its window (PriceWindow) prints on, in the same 6x8 digits, stuck over the
## ticket's top-right corner. It is UP art px higher than the window and as tall, from the
## window's left edge on: a pinked right edge (teeth TOOTH_ROWS rows tall), an ink outline on
## three sides (none on the left, where it tucks under the face's divider), a hard 1 px shadow
## under it and in its teeth; the digits start DIGITS_LEFT art px from its left. It leaks to the
## right, past the ticket's edge, and up, never to the left.
##
## The leak (every art px drawn past the ticket's right edge) is at most cap()
## (PlanningTuning.price_leak_cap, data/balance/planning.tres). print_for is the ladder: the price
## in the 6x8 digits, in the window when it fits, else on a label within the cap; past the cap
## "Nk€" (rounded down) in 6x8, in the window or on a label; and last the 4x7 digits on a label.
## Digits are never drawn without paper under them.
##
## The node is its window's first child, under the digits: its rect is everything the label draws
## (art_rect), hidden while the price is in the window. Its paper is yellow(), greyed `grey` of
## the way with its item (the mix highlight's calm grey, ItemView: the sharp-pixel grey material
## cannot grey a drawn rect). It never draws gold: its yellow is a pale mustard, not the GOLDEN
## ring's gold, mustard or brass. Where a PriceLabelLayer draws a row's labels (draw_on: over the
## row's cells and frames, since the next cell is drawn after this one), the node leaves the
## drawing to it (`covered`): a label is drawn once.

## The label's paper, yellow(): the mock-up's price-label yellow (#f6e3a1) is no palette colour,
## and the mustard ramp's palest read as the ticket's cream (the review of 2026-11-10), so the
## paper is mustard light PAPER_MIX of the way to mustard pale (#f6e2a2), as the week card mixes
## its papers: apart from the window's paper, a ticket's cream plate and a Breakfast ticket's
## mustard face. Then its ink outline and its hard shadow.
const PAPER_FROM := Palette.MUSTARD_LIGHT
const PAPER_TO := Palette.MUSTARD_PALE
const PAPER_MIX := 0.6
const EDGE := Palette.INK
const SHADOW := Palette.INK_LIGHT
## A boosted pay's digits on the label, by PriceWindow.boost_step (1 to 3): [ink, shadow].
## PriceWindow.BOOST_INKS's mustard dark (2.6:1) and orange (2.2:1) fall under 3:1 on the yellow,
## so steps 1 and 2 print the next darker shade of their ramp (mustard darkest 4.9:1, orange dark
## 4.2:1) on a shadow darker again (their ramps end there: brass darkest, wood dark). Step 3's
## tomato (3.1:1) is the window's. The printed ink (11.9:1) and the lowered grey (3.0:1, a quiet
## ink by design) stay as in the window.
const BOOST_INKS: Array[Array] = [
	[Palette.MUSTARD_DARKEST, Palette.BRASS_DARKEST],
	[Palette.ORANGE_DARK, Palette.WOOD_DARK],
	[Palette.TOMATO, Palette.TOMATO_DARKEST],
]
## The label is this many art px higher than the window; its digits start DIGITS_LEFT art px from
## its left, and after them come TAIL columns: the digits' shadow's, a tooth's, the outline's.
const UP := 2
const DIGITS_LEFT := 1
const TAIL := 3
## The pinked edge: every TOOTH_PITCH rows, TOOTH_ROWS rows (from row TOOTH_FIRST) reach one art
## px further right.
const TOOTH_PITCH := 4
const TOOTH_ROWS := 2
const TOOTH_FIRST := 1
## The ticket's right edge is this many art px right of the window's (the face's shade column
## and the ink outline).
const TICKET_EDGE := TicketFace.ART_SIZE.x - TicketFace.WINDOW.end.x
## The tuning whose price_leak_cap caps the leak.
const TUNING_PATH := "res://data/balance/planning.tres"

static var _cap: int = 0
static var _cap_read: bool = false
## Each drawn shape's outline and shadow cells by (window width, leak, 1 with a left edge):
## [Array[Vector2i], Array[Vector2i]], built once.
static var _shapes: Dictionary[Vector3i, Array] = {}

## A PriceLabelLayer draws this label (over its row): the node draws nothing itself.
var covered: bool = false:
	set(value):
		if value != covered:
			covered = value
			queue_redraw()
## The outline runs down the left too: on a framed window (a drag's ghost carries its pay off a
## ticket), where no divider covers that side.
var left_edge: bool = false

## How grey the paper is (0: PAPER, 1: its grey).
var grey: float = 0.0:
	set(value):
		if not is_equal_approx(value, grey):
			grey = value
			queue_redraw()

## The label's leak in art px (0: none, hidden) on a window `_width` art px wide.
var _leak: int = 0
var _width: int = 0


func _init() -> void:
	name = "Label"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false


## How `amount` prints on a ticket whose window is `width` art px wide, its label leaking at
## most `most` art px (the tuning's cap() when negative): [text, PixelWords.Sheet, leak], leak 0
## for a price in the window, else its label's leak. The first that fits of: the price in the
## 6x8 digits, "Nk€" in 6x8 (from 1000€), the price in the 4x7 digits, "Nk€" in 4x7; each in the
## window when its room holds it, else on a label when its leak is within the cap. When nothing
## fits (no price the game reaches), the last form on a label past the cap. Pure.
static func print_for(amount: int, width: int, most: int = -1) -> Array:
	var limit: int = most if most >= 0 else cap()
	var room: int = width - (PriceWindow.ART.x - PriceWindow.DIGITS_RIGHT - 1)
	var whole: String = MonitorText.euros(amount)
	var short: String = PriceWindow.THOUSANDS % floori(amount / 1000.0)
	var forms: Array[Array] = [[whole, PixelWords.Sheet.DIGITS]]
	if amount >= 1000:
		forms.append([short, PixelWords.Sheet.DIGITS])
	forms.append([whole, PixelWords.Sheet.SMALL_DIGITS])
	if amount >= 1000:
		forms.append([short, PixelWords.Sheet.SMALL_DIGITS])
	var needed: int = 0
	for form: Array in forms:
		var digits: int = PixelWords.font_size_of(form[0], form[1]).x
		if digits <= room:
			return [form[0], form[1], 0]
		needed = leak_for(digits, width)
		if needed <= limit:
			return [form[0], form[1], needed]
	return [forms[-1][0], forms[-1][1], needed]


## How far a label holding digits `digits` art px wide leaks past the ticket's right edge, on a
## window `width` art px wide: its columns (the digits' inset, the digits, the shadow's, a
## tooth's and the outline's) less the ones up to the ticket's edge. Pure.
static func leak_for(digits: int, width: int) -> int:
	return DIGITS_LEFT + digits + TAIL - (width + TICKET_EDGE)


## The rect of everything a label leaking `leak_px` draws (art px from the top left of its
## window, `width` wide): from the window's left to the leak's end, from the outline's row over
## the paper down to the shadow's row under it. Pure.
static func art_rect(width: int, leak_px: int) -> Rect2i:
	return Rect2i(0, -UP - 1, width + TICKET_EDGE + leak_px, PriceWindow.ART.y + 3)


## A label's paper as one run per row: (row, first column, last column) in art px from its
## window's top left, the tooth rows one column further. Pure.
static func paper_rows(width: int, leak_px: int) -> Array[Vector3i]:
	var last: int = width + TICKET_EDGE + leak_px - TAIL
	var rows: Array[Vector3i] = []
	for row: int in PriceWindow.ART.y:
		var tooth: bool = posmod(row - TOOTH_FIRST, TOOTH_PITCH) < TOOTH_ROWS
		rows.append(Vector3i(row - UP, 0, last + (1 if tooth else 0)))
	return rows


## The most a label leaks past its ticket's right edge, in art px (the tuning's price_leak_cap,
## read once).
static func cap() -> int:
	if not _cap_read:
		_cap_read = true
		var tuning: PlanningTuning = load(TUNING_PATH) as PlanningTuning
		if tuning != null:
			_cap = tuning.price_leak_cap
	return _cap


## Shows the label leaking `leak_px` art px on a window `width` art px wide (its rect: art_rect,
## in the window's coordinates), or hides it (0).
func show_leak(width: int, leak_px: int) -> void:
	_width = width
	_leak = maxi(leak_px, 0)
	visible = _leak > 0
	var art: Rect2i = art_rect(width, _leak)
	position = Vector2(art.position) * ArtStyle.ART_SCALE
	size = Vector2(art.size) * ArtStyle.ART_SCALE
	queue_redraw()


## How far it reaches past the ticket's right edge, in art px (0: no label).
func leak() -> int:
	return _leak


## The label's yellow: PAPER_FROM, PAPER_MIX of the way to PAPER_TO. Pure.
static func yellow() -> Color:
	return PAPER_FROM.lerp(PAPER_TO, PAPER_MIX)


## Its paper now: yellow(), greyed `grey` of the way (to its luminance).
func paper() -> Color:
	var base: Color = yellow()
	var level: float = base.get_luminance()
	return base.lerp(Color(level, level, level), clampf(grey, 0.0, 1.0))


## Draws the label on `canvas` in its window's coordinates (a PriceLabelLayer sets the window's
## transform first), every colour times `tint`: the hard shadow, the ink outline and the paper,
## as the mock-up's variant C builds them (_shape). Then `words` (the window's shown shadow and
## digits, for a layer), their alpha times `words_alpha`.
func draw_on(
	canvas: CanvasItem,
	tint: Color = Color.WHITE,
	words: Array[PixelWords] = [],
	words_alpha: float = 1.0
) -> void:
	if _leak <= 0:
		return
	var px: float = ArtStyle.ART_SCALE
	var shape: Array = _shape(_width, _leak, left_edge)
	for cell: Vector2i in shape[1]:
		canvas.draw_rect(Rect2(Vector2(cell) * px, Vector2(px, px)), SHADOW * tint)
	for cell: Vector2i in shape[0]:
		canvas.draw_rect(Rect2(Vector2(cell) * px, Vector2(px, px)), EDGE * tint)
	var fill: Color = paper() * tint
	for run: Vector3i in paper_rows(_width, _leak):
		canvas.draw_rect(Rect2(run.y * px, run.x * px, (run.z - run.y + 1) * px, px), fill)
	for shown: PixelWords in words:
		_draw_words(canvas, shown, Color(tint, tint.a * words_alpha))


func _draw() -> void:
	if covered:
		return
	# draw_on's cells are in the window's coordinates.
	draw_set_transform(-position)
	draw_on(self)


## A label's outline and shadow cells (art px from its window's top left), built once per shape:
## [outline, shadow]. The outline is every cell right of, over or under the paper (left of it
## too with `left`); the shadow every cell one down and right of the paper or the outline that
## neither covers, up to the outline's last column.
static func _shape(width: int, leak_px: int, left: bool) -> Array:
	var key: Vector3i = Vector3i(width, leak_px, 1 if left else 0)
	if _shapes.has(key):
		return _shapes[key]
	var cells: Dictionary[Vector2i, bool] = {}
	for run: Vector3i in paper_rows(width, leak_px):
		for column: int in range(run.y, run.z + 1):
			cells[Vector2i(column, run.x)] = true
	var steps: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.UP]
	if left:
		steps.append(Vector2i.LEFT)
	var edge: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in cells:
		for step: Vector2i in steps:
			if not cells.has(cell + step):
				edge[cell + step] = true
	var right: int = art_rect(width, leak_px).end.x - 1
	var cast: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in cells.keys() + edge.keys():
		var under: Vector2i = cell + Vector2i.ONE
		if not cells.has(under) and not edge.has(under) and under.x <= right:
			cast[under] = true
	var outline: Array[Vector2i] = []
	outline.assign(edge.keys())
	var shadow: Array[Vector2i] = []
	shadow.assign(cast.keys())
	_shapes[key] = [outline, shadow]
	return _shapes[key]


## Draws `words` (the window's digits or their shadow) on `canvas` at their place in the window.
static func _draw_words(canvas: CanvasItem, words: PixelWords, tint: Color) -> void:
	var column: int = 0
	for character: String in words.text:
		var glyph: Array = PixelWords.glyph_of(character, words.sheet)
		for row: int in range(glyph.size()):
			var line: String = glyph[row]
			for index: int in range(line.length()):
				if line[index] == "#":
					var at: Vector2 = words.position + Vector2(column + index, row) * words.cell
					canvas.draw_rect(Rect2(at, Vector2.ONE * words.cell), words.color * tint)
		column += (glyph[0] as String).length() + PixelWords.GAP
