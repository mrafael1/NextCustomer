class_name MonitorBaseLine
extends RefCounted
## The item column's base price line (PR #138 round 5, the user's "base price is too big"): the
## first line of the equation section, a row's height and pitch (MonitorStepRow.ROW_PITCH), read
## like the effect rows under it: the price tag icon (a row mark's size, MonitorStepRow.MARK_SIZE,
## so CAPTION starts at the effect names' indent; review of round 5), CAPTION in
## the rows' font in ink, a dotted leader (MonitorLeader), then the item's printed price right-
## aligned in the rows' amount column, in ink. A product's only, over at least one effect row
## (MonitorItemColumn decides). Pure maker: no state.

const CAPTION := "Base price"
const TAG_ICON := preload("res://art/icons/price_tag_mini.png")
const INK := Palette.INK


## The line for `amount` (the item's printed price), `width` px wide, in no parent yet: its parts
## named as a row's (Mark, Text, Amount, Leader) so the leader and the checks read it as one.
static func make(amount: int, width: float) -> Control:
	var line: Control = Control.new()
	line.name = "BaseLine"
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line.size = Vector2(width, MonitorStepRow.ROW_PITCH)
	line.set_meta(&"line", "%s %s" % [CAPTION, MonitorText.euros(amount)])
	var tag: TextureRect = UiKit.sprite(TAG_ICON)
	tag.name = "Mark"
	tag.size = MonitorStepRow.MARK_SIZE
	tag.position = Vector2(0, roundf((MonitorStepRow.ROW_PITCH - tag.size.y) / 2.0))
	line.add_child(tag)
	var shown: Label = MonitorKit.bold(
		MonitorText.euros(amount),
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
	var amount_width: float = (
		maxf(MonitorStepRow.AMOUNT_MIN, MonitorStepRow.text_width(shown))
		+ MonitorStepRow.AMOUNT_PAD
	)
	shown.position = Vector2(
		width - amount_width + MonitorStepRow.AMOUNT_PAD, MonitorStepRow.AMOUNT_RISE
	)
	shown.size = Vector2(amount_width - MonitorStepRow.AMOUNT_PAD, MonitorStepRow.ROW_PITCH)
	var indent: float = MonitorStepRow.MARK_SIZE.x + MonitorStepRow.MARK_GAP
	var room: float = width - indent - amount_width
	var text: Label = MonitorStepRow.row_text(CAPTION, INK, room, 1)
	line.add_child(text)
	text.position = Vector2(indent, 0)
	text.size = Vector2(room, MonitorStepRow.ROW_PITCH)
	line.add_child(MonitorLeader.new(line.size))
	return line
