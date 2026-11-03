class_name WinSticker
extends Control
## A LOYALTY prize ticket's LAST ROW / BEST ROW sticker (S1, v0.96, mock-up
## docs/art/mockups/machine_relook_v3.html; the price-gun sticker of #108 back on V3's ticket): a
## gold price-gun label slapped across the ticket's bottom edge at WIN_TILT, its right edge
## STICK_OUT past the ticket's and its top OVERLAP over the ticket's foot (sticker_rect), so it
## covers only the foot's margin and hangs over the pedestal, never the rule. One row per row of
## the run (the last row and, from shift 2, the best row this run): its label in Atkinson 800 10 px
## ink, its amount in the chunky digits (green dark), or a WASTED stamp (tomato dark) on a grey
## row when it would have won nothing; a dashed ink tear line between the rows, an ink edge and a
## 45% ink shadow.
##
## Its motion runs on the ticket's seconds since it landed (frame(since)): it slaps in at SLAP_AT
## (1.5x down to 1x on a back ease over SLAP_S), each row's amount rolls from 0 to its amount in
## ROLL_S from ROLL_AT + ROLL_STEP x its row (ease-out, whole euros), with a paper glint for
## GLINT_S at the roll's end, and a WASTED stamp thumps in (1.6x to 1x over STAMP_S) when its row
## would roll. Under reduced motion it shows whole as the ticket lands. Display only.

## The rows' names in win_texts (and on the sticker).
const WIN_LABELS: Array[String] = ["LAST ROW", "BEST ROW"]
const LABEL_SIZE := 10
const LABEL_WEIGHT := 800
## A row's height, the label's and the amount's inset, the gap a WASTED stamp adds round its word,
## the room between the label and the amount, and the sticker's edge round its rows.
const WIN_ROW := 22.0
const WIN_PAD := 6.0
const STAMP_PAD := 12.0
const WIN_GAP := 22.0
const EDGE := 2.0
## Where it hangs off the ticket: its right edge STICK_OUT past the ticket's right, its top
## OVERLAP above the ticket's foot; its tilt (degrees) and its shadow.
const STICK_OUT := 8.0
const OVERLAP := 8.0
const WIN_TILT := -4.0
const WIN_SHADOW := Vector2(4, 4)
const SHADOW_ALPHA := 0.45
## The motion (seconds after the ticket landed).
const SLAP_AT := 0.30
const SLAP_S := 0.2
const SLAP_FROM := 1.5
const ROLL_AT := 0.42
const ROLL_STEP := 0.18
const ROLL_S := 0.45
const GLINT_S := 0.35
const STAMP_S := 0.18
const STAMP_FROM := 1.6
const ZERO := "+0€"
const WASTED := "WASTED"
const GLINT: Array[String] = ["..#..", "..#..", "#####", "..#..", "..#.."]

var _gains: Array[int] = []
var _amounts: Array[MachineLine] = []
var _texts: PackedStringArray = PackedStringArray()
var _since: float = -1.0
var _rm: bool = false
var _label_width: float = 0.0


## A sticker for `gains` (one per row: the last row's, then the best row's), placed on a ticket
## of `ticket_size`.
func _init(gains: Array[int], ticket_size: Vector2) -> void:
	name = "WinSticker"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gains = gains
	var font: Font = ArtStyle.bold_font(LABEL_WEIGHT)
	var amount_width: float = 0.0
	for row: int in range(gains.size()):
		_texts.append("%s %s" % [WIN_LABELS[row], amount_text(gains[row])])
		_label_width = maxf(_label_width, MachineArt.text_width(WIN_LABELS[row], font, LABEL_SIZE))
		amount_width = maxf(amount_width, _amount_width(gains[row]))
		var line: MachineLine = MachineLine.make("WinAmount%d" % row, "", Palette.GREEN_DARK)
		line.visible = gains[row] > 0
		add_child(line)
		_amounts.append(line)
	var width: float = MachineArt.snap(ceilf(_label_width + amount_width + WIN_GAP))
	var rect: Rect2 = sticker_rect(gains.size(), width, ticket_size)
	position = rect.position
	size = rect.size
	pivot_offset = size / 2.0
	rotation_degrees = WIN_TILT
	visible = false


## The sticker's unrotated rect on a ticket of `ticket_size` for `rows` rows, `width` wide: its
## right edge STICK_OUT past the ticket's, its top OVERLAP over the ticket's foot.
static func sticker_rect(rows: int, width: float, ticket_size: Vector2) -> Rect2:
	var height: float = WIN_ROW * rows + 2.0 * EDGE
	return Rect2(ticket_size.x + STICK_OUT - width, ticket_size.y - OVERLAP, width, height)


## A win's amount as the sticker prints it: "+6€", or WASTED for nothing.
static func amount_text(gain: int) -> String:
	return MonitorText.gain(gain) if gain > 0 else WASTED


## The sticker's scale `since` seconds after the ticket landed (0: not shown yet).
static func scale_at(since: float, rm: bool) -> float:
	if since < (0.0 if rm else SLAP_AT):
		return 0.0
	if rm:
		return 1.0
	var k: float = MachineArt.seg(since, SLAP_AT, SLAP_AT + SLAP_S)
	return SLAP_FROM - (SLAP_FROM - 1.0) * MachineArt.ease_back(k)


## Row `row`'s amount as it rolls `since` seconds after the ticket landed, for a win of `gain`.
static func rolled_text(gain: int, row: int, since: float, rm: bool) -> String:
	if gain <= 0:
		return WASTED
	if rm:
		return amount_text(gain)
	var start: float = ROLL_AT + ROLL_STEP * row
	var roll: float = MachineArt.ease_out(MachineArt.seg(since, start, start + ROLL_S))
	if roll <= 0.0:
		return ZERO
	return amount_text(maxi(1, roundi(gain * roll)))


## Row `row`'s WASTED stamp's scale `since` seconds after the ticket landed (0: not stamped yet).
static func stamp_scale_at(row: int, since: float, rm: bool) -> float:
	if rm:
		return 1.0 if since >= 0.0 else 0.0
	var start: float = ROLL_AT + ROLL_STEP * row
	var k: float = MachineArt.seg(since, start, start + STAMP_S)
	if k <= 0.0:
		return 0.0
	return STAMP_FROM - (STAMP_FROM - 1.0) * MachineArt.ease_out(k)


## The rows' texts ("LAST ROW +6€", "BEST ROW WASTED").
func texts() -> PackedStringArray:
	return _texts


## The sticker's scale now (0: hidden).
func sticker_scale() -> float:
	return scale_at(_since, _rm)


## Row `row`'s amount as shown now.
func shown_amount(row: int) -> String:
	return rolled_text(_gains[row], row, _since, _rm)


## Row `row`'s WASTED stamp's scale now (0: not stamped yet; 1 for a won row).
func stamp_scale(row: int) -> float:
	return stamp_scale_at(row, _since, _rm) if _gains[row] <= 0 else 1.0


## The sticker `since` seconds after its ticket landed (below 0: not yet), `rm` under reduced
## motion.
func frame(since: float, rm: bool) -> void:
	_since = since
	_rm = rm
	var shown: float = sticker_scale()
	visible = shown > 0.0
	if not visible:
		return
	scale = Vector2.ONE * shown
	for row: int in range(_gains.size()):
		if _gains[row] <= 0:
			continue
		var text: String = shown_amount(row)
		var line: MachineLine = _amounts[row]
		if line.text() != text:
			line.show_text(text, Palette.GREEN_DARK)
			var top: float = EDGE + WIN_ROW * row + (WIN_ROW - 16.0) / 2.0 + MachineArt.PIXEL
			line.position = MachineArt.snap_point(Vector2(size.x - WIN_PAD - line.width(), top))
	queue_redraw()


func _amount_width(gain: int) -> float:
	if gain > 0:
		return MachineLine.width_of(amount_text(gain))
	var font: Font = ArtStyle.bold_font(LABEL_WEIGHT)
	return MachineArt.text_width(WASTED, font, LABEL_SIZE) + STAMP_PAD


func _draw() -> void:
	var p: float = MachineArt.PIXEL
	var rect: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(Rect2(WIN_SHADOW, size), Color(Palette.INK, SHADOW_ALPHA))
	draw_rect(rect, Palette.INK)
	var font: Font = ArtStyle.bold_font(LABEL_WEIGHT)
	var ascent: float = font.get_ascent(LABEL_SIZE)
	for row: int in range(_gains.size()):
		var top: float = EDGE + WIN_ROW * row
		var won: bool = _gains[row] > 0
		var fill: Rect2 = Rect2(EDGE, top, size.x - 2.0 * EDGE, WIN_ROW)
		draw_rect(fill, Palette.GOLD if won else Palette.GREY_LIGHT)
		var light: Color = Palette.MUSTARD_PALE if won else Palette.PAPER
		draw_rect(Rect2(fill.position, Vector2(fill.size.x, p)), light)
		if row > 0:
			var x: float = 2.0 * p
			while x < size.x - 3.0 * p:
				draw_rect(Rect2(x, top, 2.0 * p, p), Palette.INK)
				x += 4.0 * p
		var base: Vector2 = Vector2(
			WIN_PAD, roundf(top + (WIN_ROW - LABEL_SIZE) / 2.0 + ascent - 1.0)
		)
		draw_string(
			font, base, WIN_LABELS[row], HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_SIZE, Palette.INK
		)
		if won:
			_draw_glint(row, top)
		else:
			_draw_stamp(row, top, font)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## A paper glint at a won row's amount's top right for GLINT_S once its roll has ended.
func _draw_glint(row: int, top: float) -> void:
	if _rm:
		return
	var end: float = ROLL_AT + ROLL_STEP * row + ROLL_S
	if _since < end or _since > end + GLINT_S:
		return
	var p: float = MachineArt.PIXEL
	var origin: Vector2 = Vector2(size.x - WIN_PAD - 2.0 * p, top) - Vector2(2, 2) * p
	for y: int in range(GLINT.size()):
		for x: int in range(GLINT[y].length()):
			if GLINT[y][x] == "#":
				draw_rect(Rect2(origin + Vector2(x, y) * p, Vector2(p, p)), Palette.PAPER)


## The WASTED stamp on a row that would have won nothing: tomato dark round paper and its word,
## thumping in from STAMP_FROM.
func _draw_stamp(row: int, top: float, font: Font) -> void:
	var shown: float = stamp_scale(row)
	if shown <= 0.0:
		return
	var p: float = MachineArt.PIXEL
	var width: float = MachineArt.snap(MachineArt.text_width(WASTED, font, LABEL_SIZE) + STAMP_PAD)
	var stamp: Rect2 = Rect2(size.x - EDGE - p - width, top + p, width, WIN_ROW - 2.0 * p)
	var middle: Vector2 = stamp.get_center()
	draw_set_transform(middle * (1.0 - shown), 0.0, Vector2.ONE * shown)
	draw_rect(stamp, Palette.TOMATO_DARK)
	draw_rect(stamp.grow(-p), Palette.PAPER)
	MachineArt.centred_text(self, WASTED, middle, font, LABEL_SIZE, Palette.TOMATO_DARK)
	draw_set_transform_matrix(Transform2D.IDENTITY)
