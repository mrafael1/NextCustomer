class_name MonitorBaseLine
extends RefCounted
## The item column's base price line (PR #138 round 5, the user's "base price is too big"): the
## first line of the equation section, a row's height and pitch (MonitorStepRow.ROW_PITCH), read
## like the effect rows under it: the price tag icon (a row mark's size, MonitorStepRow.MARK_SIZE,
## so CAPTION starts at the effect names' indent; review of round 5), CAPTION in
## the rows' font in ink, a dotted leader (MonitorLeader), then the item's printed price right-
## aligned in the rows' amount column, in ink. A product's only, over at least one effect row
## (MonitorItemColumn decides). Pure maker: no state.
##
## v1.14 (the user's "fix the missing subtotal across pages"): a later page of rows starts with the
## carried line instead (make_carried): a return arrow drawn on the 2 px grid in CARRY_INK,
## CARRY_CAPTION muted (CARRY_INK, CARRY_WEIGHT), the leader, then the running value the item
## reached at the end of the page before (the score's own; MonitorItemColumn reads it from its
## rows) in ink in the amount column. The count's "+N earlier" fold uses it too, with its own
## caption.

const CAPTION := "Base price"
const CARRY_CAPTION := "Carried forward"
const TAG_ICON := preload("res://art/icons/price_tag_mini.png")
const INK := Palette.INK
const CARRY_INK := MonitorStepRow.NOTE_COLOR
const CARRY_WEIGHT := 700
## The return arrow's 2 px cells (x, y, w, h in a row mark's box): its stem, its foot, its tip
## and its head's two diagonals.
const CARRY_ARROW: Array[Rect2] = [
	Rect2(2, 0, 2, 6),
	Rect2(2, 6, 10, 2),
	Rect2(12, 6, 2, 2),
	Rect2(8, 2, 2, 2),
	Rect2(10, 4, 2, 2),
	Rect2(10, 8, 2, 2),
	Rect2(8, 10, 2, 2),
]


## The line for `amount` (the item's printed price), `width` px wide, in no parent yet: its parts
## named as a row's (Mark, Text, Amount, Leader) so the leader and the checks read it as one.
static func make(amount: int, width: float) -> Control:
	var tag: TextureRect = UiKit.sprite(TAG_ICON)
	var line: Control = _line(CAPTION, MonitorText.euros(amount), tag, INK, width)
	line.name = "BaseLine"
	line.set_meta(&"line", "%s %s" % [CAPTION, MonitorText.euros(amount)])
	return line


## A later page's first line: `caption` (CARRY_CAPTION) and the running value `amount` the item
## reached before the page (its meta "carried"); `amount` below 0: the caption alone, no leader.
static func make_carried(amount: int, width: float, caption: String = CARRY_CAPTION) -> Control:
	var shown: String = MonitorText.euros(amount) if amount >= 0 else ""
	var line: Control = _line(caption, shown, carry_mark(), CARRY_INK, width)
	line.name = "CarryLine"
	line.set_meta(&"line", ("%s %s" % [caption, shown]).strip_edges())
	line.set_meta(&"carried", amount)
	return line


## The carried line's return arrow (CARRY_ARROW in CARRY_INK), a row mark's size.
static func carry_mark() -> Control:
	var mark: Control = Control.new()
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.draw.connect(
		func() -> void:
			for cell: Rect2 in CARRY_ARROW:
				mark.draw_rect(cell, CARRY_INK)
	)
	return mark


## The line: `mark` (a row mark's size), `caption` in `caption_ink`, the leader and `amount` (""
## for none) in ink in the rows' amount column.
static func _line(
	caption: String, amount: String, mark: Control, caption_ink: Color, width: float
) -> Control:
	var line: Control = Control.new()
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.size = Vector2(width, MonitorStepRow.ROW_PITCH)
	mark.name = "Mark"
	mark.size = MonitorStepRow.MARK_SIZE
	mark.position = Vector2(0, roundf((MonitorStepRow.ROW_PITCH - mark.size.y) / 2.0))
	line.add_child(mark)
	var amount_width: float = 0.0
	if not amount.is_empty():
		var shown: Label = MonitorKit.bold(
			amount,
			MonitorStepRow.AMOUNT_SIZE,
			MonitorStepRow.AMOUNT_WEIGHT,
			INK,
			MonitorStepRow.ROW_PITCH
		)
		shown.name = "Amount"
		shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		shown.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		shown.custom_minimum_size = Vector2.ZERO
		line.add_child(shown)
		var shown_width: float = maxf(MonitorStepRow.text_width(shown), shown.get_minimum_size().x)
		amount_width = (
			maxf(MonitorStepRow.AMOUNT_MIN, ceilf(shown_width)) + MonitorStepRow.AMOUNT_PAD
		)
		shown.position = Vector2(
			width - amount_width + MonitorStepRow.AMOUNT_PAD, MonitorStepRow.AMOUNT_RISE
		)
		shown.size = Vector2(amount_width - MonitorStepRow.AMOUNT_PAD, MonitorStepRow.ROW_PITCH)
	var indent: float = MonitorStepRow.MARK_SIZE.x + MonitorStepRow.MARK_GAP
	var room: float = width - indent - amount_width
	var text: Label = MonitorStepRow.row_text(caption, caption_ink, room, 1)
	if caption_ink != INK:
		text.add_theme_font_override("font", ArtStyle.bold_font(CARRY_WEIGHT))
	line.add_child(text)
	text.position = Vector2(indent, 0)
	text.size = Vector2(room, MonitorStepRow.ROW_PITCH)
	line.add_child(MonitorLeader.new(line.size))
	return line
