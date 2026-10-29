class_name BonusTicket
extends Control
## The gold BONUS TICKET (#77 machine v2, Q2 = 2; docs/art/mockups/machine_77_v2.html): drawn,
## with its icon (art/icons/bonus_ticket.png, 2x), "BONUS TICKET" (Pixelify 24; a payday's second
## ticket, v0.68: "PREMIUM TICKET", smaller if it must) and a small line (bold Atkinson 11:
## "inspection passed · keep me", a payday's "review passed · 2 of 2"). Its gold body has a 2 px
## ink border. As the STUB (printed at the receipt's foot, ReceiptStub) its top edge is a 3 px
## dashed ink perforation; as the TICKET (snapped off, flying to the slot plate's dock, docked
## and fed in for the bonus visit; ReceiptFeed) it has stepped half-circle notches at its left
## and right middles on the 2 px grid and a dashed mustard dark line at NOTCH_LINE_X.
##
## Its art is SIZE high and as wide as the control; the control clips it, so a shorter control
## shows its top part (the stub printing, or snapping off). `shine` sweeps a glint across it (the
## bonus feed's). Decor only: it takes no click.

enum Form { STUB, TICKET }

const SIZE := Vector2(236, 62)
const TITLE := "BONUS TICKET"
const TITLE_SIZE := 24
const SUB_SIZE := 11
const BOLD_WEIGHT := 700
const INSPECTED_SUB := "inspection passed · keep me"
const EXTRA_SUB := "shift %d · keep me"
const ICON := preload("res://art/icons/bonus_ticket.png")
const ICON_POSITION := Vector2(10, 18)
const ICON_SCALE := 2.0
const TITLE_RECT := Rect2(52, 8, 180, 28)
const SUB_RECT := Rect2(52, 36, 180, 16)
const BORDER := 2.0
## The stub's perforated top edge: 3 px ink dashes DASH long, DASH apart.
const PERFORATION := 3.0
const DASH := 6.0
## The ticket's notches: a stepped half circle NOTCH_RADIUS px deep at each side's middle; its
## dashed line at NOTCH_LINE_X, inset NOTCH_LINE_INSET from the top and the bottom.
const NOTCH_RADIUS := 8.0
const NOTCH_LINE_X := 44.0
const NOTCH_LINE_INSET := 4.0
const GRID := 2.0
## The glint: a paper bar GLINT_WIDTH wide, skewed by GLINT_SKEW, at most GLINT_ALPHA.
const GLINT_WIDTH := 18.0
const GLINT_SKEW := 14.0
const GLINT_ALPHA := 0.6

var form: int = Form.STUB
## The glint's progress across (0 .. 1; none outside).
var shine: float = -1.0
var _art: Control
var _icon: TextureRect
var _title: Label
var _sub: Label


func _init(ticket_form: int = Form.STUB, sub: String = INSPECTED_SUB) -> void:
	name = "BonusTicket"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	size = SIZE
	_art = Control.new()
	_art.name = "Art"
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.size = SIZE
	_art.draw.connect(_draw_art)
	add_child(_art)
	_icon = UiKit.sprite(ICON)
	_icon.name = "Icon"
	_icon.position = ICON_POSITION
	_icon.size = Vector2(ICON.get_size()) * ICON_SCALE
	_art.add_child(_icon)
	var title: String = title_for(sub)
	_title = UiKit.display_label(title, _title_size(title), false)
	_title.name = "Title"
	_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	RewardMachineView.fit(_title, TITLE_RECT)
	_art.add_child(_title)
	_sub = UiKit.body_label(sub, SUB_SIZE, Palette.INK)
	_sub.name = "Sub"
	_sub.add_theme_font_override("font", ArtStyle.bold_font(BOLD_WEIGHT))
	_sub.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sub.clip_text = true
	RewardMachineView.fit(_sub, SUB_RECT)
	_art.add_child(_sub)
	resized.connect(_fit_art)
	set_form(ticket_form)


## The small line under the title: a payday's second PREMIUM ticket (v0.68, Payday.TICKET_SUB),
## an inspection's pass, or a bonus extra shift's number.
static func sub_line(inspected: bool, shift: int, payday: bool = false) -> String:
	if payday:
		return Payday.TICKET_SUB
	return INSPECTED_SUB if inspected else EXTRA_SUB % shift


## The title for a ticket with the small line `sub`: a payday's (Payday.TICKET_SUB) is the
## PREMIUM TICKET (v0.68), any other the BONUS TICKET.
static func title_for(sub: String) -> String:
	return Payday.TICKET_TITLE if sub == Payday.TICKET_SUB else TITLE


## The title's size: TITLE_SIZE, or smaller until `title` fits TITLE_RECT's width (a payday's
## PREMIUM TICKET).
static func _title_size(title: String) -> int:
	var font: Font = ArtStyle.DISPLAY_FONT
	var title_size: int = TITLE_SIZE
	while (
		title_size > SUB_SIZE
		and (
			font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x
			> TITLE_RECT.size.x
		)
	):
		title_size -= 2
	return title_size


## The stub (perforated top) or the ticket (notches, dashed line).
func set_form(ticket_form: int) -> void:
	form = ticket_form
	_art.queue_redraw()


## The glint's progress (0 .. 1), or none (below 0).
func set_shine(progress: float) -> void:
	if progress == shine:
		return
	shine = progress
	_art.queue_redraw()


## The title and the small line, for tests.
func texts() -> PackedStringArray:
	return PackedStringArray([_title.text, _sub.text])


## The labels, for layout tests.
func labels() -> Array[Label]:
	return [_title, _sub]


## The art's own rect (local): the whole ticket, however much of it the control shows.
func art_rect() -> Rect2:
	return Rect2(Vector2.ZERO, _art.size)


func _fit_art() -> void:
	_art.size = Vector2(size.x, SIZE.y)
	_art.queue_redraw()


func _draw_art() -> void:
	var width: float = _art.size.x
	var height: float = _art.size.y
	var row: float = 0.0
	while row < height:
		var inset: float = _notch_inset(row + GRID / 2.0) if form == Form.TICKET else 0.0
		var span: Rect2 = Rect2(inset, row, width - 2.0 * inset, GRID)
		_art.draw_rect(span, Palette.GOLD)
		_art.draw_rect(Rect2(inset, row, BORDER, GRID), Palette.INK)
		_art.draw_rect(Rect2(width - inset - BORDER, row, BORDER, GRID), Palette.INK)
		var above: float = _notch_inset(row - GRID / 2.0) if form == Form.TICKET else 0.0
		if form == Form.TICKET and above != inset:
			# The notch's stepped rim: ink across the step.
			var from: float = minf(above, inset)
			var to: float = maxf(above, inset)
			_art.draw_rect(Rect2(from, row, to - from + BORDER, GRID), Palette.INK)
			_art.draw_rect(Rect2(width - to - BORDER, row, to - from + BORDER, GRID), Palette.INK)
		row += GRID
	_art.draw_rect(Rect2(0, height - BORDER, width, BORDER), Palette.INK)
	if form == Form.STUB:
		var x: float = 0.0
		while x < width:
			_art.draw_rect(Rect2(x, 0, minf(DASH, width - x), PERFORATION), Palette.INK)
			x += DASH * 2.0
	else:
		_art.draw_rect(Rect2(0, 0, width, BORDER), Palette.INK)
		var y: float = NOTCH_LINE_INSET
		while y < height - NOTCH_LINE_INSET:
			_art.draw_rect(Rect2(NOTCH_LINE_X, y, GRID, GRID * 2.0), Palette.MUSTARD_DARK)
			y += GRID * 4.0
	if shine >= 0.0 and shine <= 1.0:
		var alpha: float = GLINT_ALPHA * sin(shine * PI)
		var x0: float = lerpf(-GLINT_WIDTH - GLINT_SKEW, width, shine)
		var glint: PackedVector2Array = [
			Vector2(x0 + GLINT_SKEW, 0.0),
			Vector2(x0 + GLINT_SKEW + GLINT_WIDTH, 0.0),
			Vector2(x0 + GLINT_WIDTH, height),
			Vector2(x0, height),
		]
		_art.draw_colored_polygon(glint, Color(Palette.PAPER, alpha))


## How far the notch cuts in at height `y`: a half circle at the middle, stepped to the grid.
func _notch_inset(y: float) -> float:
	var dy: float = y - _art.size.y / 2.0
	if absf(dy) >= NOTCH_RADIUS:
		return 0.0
	var reach: float = sqrt(NOTCH_RADIUS * NOTCH_RADIUS - dy * dy)
	return roundf(reach / GRID) * GRID
