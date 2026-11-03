class_name ReceiptTarget
extends VBoxContainer
## The receipt's TODAY'S TARGET block (the shift scene polish, mock-up
## docs/art/mockups/shift_scene_polish_v2.html section 2, sized by v4's D): the printed caption,
## the shift's quota as a big tomato-dark number in the pixel digits, and a double tomato rule
## under it. It is pinned at the receipt's top (ReceiptView keeps it out of the scroll area), so
## it stays in view while the lines scroll. The target is a fixed fact (the user's pick B1): it
## never changes colour; being met is said by the receipt's foot (planning's "+N.00€ over target"
## or "N.00€ short", the dessert's margin line), the gauge's flag and the belt's light. Hidden
## until show_quota (a receipt without a quota, such as the tests' or a stub's, has none).
## Display only.

## The caption: the receipt's mono font at CAPTION_SIZE, letter-spaced, in tomato dark (mock-up
## shift_scene_polish_v4 D: 18 px at 1920x1080).
const CAPTION_TEXT := "TODAY'S TARGET"
const CAPTION_SIZE := 12
const CAPTION_SPACING := 2
## The quota as the block prints it: the whole euros (the receipt's amounts carry cents; the target
## does not) and the € after them ("80€", the user's of 2026-11-02), in the 6x8 bold pixel digits
## (PixelWords.Sheet.DIGITS, mock-up shift_scene_polish_v4 D: one font pixel is 3 art pixels, so
## they stand 48 px tall, 72 px at 1920x1080, with 2-art-px stems), centred across the block on
## the art's grid. A number too wide for the paper at AMOUNT_CELL steps down to AMOUNT_SMALL_CELL.
## The row is as tall as the digits plus AMOUNT_PAD px under them.
const AMOUNT_TEXT := "%d€"
const AMOUNT_CELL := 6.0
const AMOUNT_SMALL_CELL := 4.0
const AMOUNT_PAD := 4.0
const COLOR := Palette.TOMATO_DARK
## The double rule under the number: two RULE_WIDTH px tomato lines RULE_GAP px apart, inset
## RULE_INSET px from the block's sides.
const RULE_COLOR := Palette.TOMATO
const RULE_WIDTH := 2.0
const RULE_GAP := 2.0
const RULE_INSET := 2.0
const RULE_BELOW := 2.0
## The foot's line against the target (ReceiptView.show_planning) and the dessert's margin line
## (margin_text) share these words.
const OVER_TEXT := "+%s over target"
const SHORT_TEXT := "%s short"
const ON_TEXT := "on target"

var caption: Label
## The quota's digits and € (PixelWords).
var amount: PixelWords
var _row: Control
var _rule: Control
var _quota: int = -1


func _init() -> void:
	name = "Target"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	add_theme_constant_override("separation", 0)
	caption = Label.new()
	caption.text = CAPTION_TEXT
	var spaced: FontVariation = FontVariation.new()
	spaced.base_font = ReceiptView.MONO_FONT
	spaced.spacing_glyph = CAPTION_SPACING
	caption.add_theme_font_override("font", spaced)
	caption.add_theme_font_size_override("font_size", CAPTION_SIZE)
	caption.add_theme_color_override("font_color", COLOR)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(caption)
	amount = PixelWords.new("", PixelWords.Sheet.DIGITS, AMOUNT_CELL, COLOR)
	amount.name = "Amount"
	_row = Control.new()
	_row.name = "AmountRow"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.custom_minimum_size.y = _digits_height() + AMOUNT_PAD
	_row.add_child(amount)
	_row.resized.connect(_place_amount)
	add_child(_row)
	_rule = Control.new()
	_rule.name = "Rule"
	_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rule.custom_minimum_size.y = RULE_WIDTH * 2.0 + RULE_GAP + RULE_BELOW
	_rule.draw.connect(_draw_rule)
	add_child(_rule)


## Shows `quota` as the target (hides the block for a negative one).
func show_quota(quota: int) -> void:
	_quota = quota
	visible = quota >= 0
	amount.text = AMOUNT_TEXT % maxi(quota, 0)
	_place_amount()


## The quota shown, -1 for none.
func shown_quota() -> int:
	return _quota if visible else -1


## The foot's words for `total` against `quota` (the receipt's money(), with cents): how far over
## it ("+67.00€ over target"), how far short ("56.00€ short") or "on target".
static func against_text(total: int, quota: int) -> String:
	var margin: ShiftMargin = ShiftMargin.of(total, quota)
	match margin.kind():
		ShiftMargin.Kind.OVER:
			return OVER_TEXT % ReceiptView.money(margin.amount())
		ShiftMargin.Kind.SHORT:
			return SHORT_TEXT % ReceiptView.money(margin.amount())
	return ON_TEXT


## The colour of the foot's words for `total` against `quota`: green dark once met, tomato short.
static func against_color(total: int, quota: int) -> Color:
	return Palette.GREEN_DARK if ShiftMargin.of(total, quota).passed() else Palette.TOMATO


## The dessert's margin line under the total: "+N.00€ OVER TARGET", "SHORT N.00€" or "ON TARGET"
## (#61's line, in the words of TODAY'S TARGET since the shift scene polish).
static func margin_text(kind: ShiftMargin.Kind, euros: int) -> String:
	match kind:
		ShiftMargin.Kind.OVER:
			return "%s OVER TARGET" % ReceiptView.money(euros, true)
		ShiftMargin.Kind.SHORT:
			return "SHORT %s" % ReceiptView.money(euros)
	return "ON TARGET"


## Shows `euros` on a margin `line` of `kind`, as its count passes them.
static func show_margin(line: Control, kind: ShiftMargin.Kind, euros: int) -> void:
	(line.get_child(0) as Label).text = margin_text(kind, euros)


## The printed amount's rect in the block, the digits and the € (for tests: inside the paper,
## over the rule).
func digits_rect() -> Rect2:
	return Rect2(_row.position + amount.position, amount.get_combined_minimum_size())


static func _digits_height() -> float:
	return PixelWords.text_size("0", PixelWords.Sheet.DIGITS, AMOUNT_CELL).y


## The digits and the € centred across the row on the art's grid, their top at the row's top: at
## AMOUNT_CELL, or AMOUNT_SMALL_CELL when that is too wide for the row.
func _place_amount() -> void:
	var cell: float = AMOUNT_CELL
	if PixelWords.text_size(amount.text, amount.sheet, cell).x > _row.size.x and _row.size.x > 0:
		cell = AMOUNT_SMALL_CELL
	amount.cell = cell
	var width: float = PixelWords.text_size(amount.text, amount.sheet, cell).x
	amount.size = amount.get_combined_minimum_size()
	amount.position = Vector2(2.0 * floorf((_row.size.x - width) / 4.0), 0.0)


func _draw_rule() -> void:
	var width: float = _rule.size.x - RULE_INSET * 2.0
	for row: int in range(2):
		var y: float = row * (RULE_WIDTH + RULE_GAP)
		_rule.draw_rect(Rect2(RULE_INSET, y, width, RULE_WIDTH), RULE_COLOR)
