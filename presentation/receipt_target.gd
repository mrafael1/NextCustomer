class_name ReceiptTarget
extends VBoxContainer
## The receipt's TODAY'S TARGET block (the shift scene polish, mock-up
## docs/art/mockups/shift_scene_polish_v2.html section 2): the printed caption, the shift's quota
## as a big tomato-dark number in the display font, and a double tomato rule under it. It is
## pinned at the receipt's top (ReceiptView keeps it out of the scroll area), so it stays in view
## while the lines scroll. The target is a fixed fact (the user's pick B1): it never changes colour;
## being met is said by the receipt's foot (planning's "+€N.00 over target" or "€N.00 short", the
## dessert's margin line), the gauge's flag and the belt's light. Hidden until show_quota (a
## receipt without a quota, such as the tests' or a stub's, has none). Display only.

## The caption: the receipt's mono font at CAPTION_SIZE, letter-spaced, in tomato dark.
const CAPTION_TEXT := "TODAY'S TARGET"
const CAPTION_SIZE := 11
const CAPTION_SPACING := 2
## The quota as the block prints it: the whole euros (the receipt's amounts carry cents; the target
## does not) and, after them, a small raised € (the mock-up's, and the user's "80€" of 2026-11-02),
## the digits in the display font's hard pixels (UiKit.pixel_label) drawn AMOUNT_SCALE times larger
## (one font pixel is 3 art pixels, so the 7-pixel digits stand 42 px tall on the art's grid), the
## € drawn (art/src/icons/target_euro.txt: Pixelify's own € reads as a 3 that small) CURRENCY_GAP
## px after them, their tops level. The row is as tall as the digits plus AMOUNT_PAD px under them.
const AMOUNT_TEXT := "%d"
const CURRENCY := preload("res://art/icons/target_euro.png")
const AMOUNT_SCALE := 6
const CURRENCY_GAP := 4.0
const AMOUNT_PAD := 2.0
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
var amount: Label
var currency: TextureRect
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
	amount = UiKit.pixel_label("", AMOUNT_SCALE, COLOR)
	amount.name = "Amount"
	currency = UiKit.sprite(CURRENCY)
	currency.name = "Currency"
	currency.size = CURRENCY.get_size() * ArtStyle.ART_SCALE
	_row = Control.new()
	_row.name = "AmountRow"
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_row.custom_minimum_size.y = _digits_height() + AMOUNT_PAD
	_row.add_child(amount)
	_row.add_child(currency)
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
## it ("+€67.00 over target"), how far short ("€56.00 short") or "on target".
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


## The dessert's margin line under the total: "+€N.00 OVER TARGET", "SHORT €N.00" or "ON TARGET"
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
	var width: float = _printed_width()
	var left: float = _row.position.x + _left()
	return Rect2(left, _row.position.y, width, _digits_height())


static func _digits_height() -> float:
	return float(ArtStyle.PIXEL_CAP_HEIGHT * AMOUNT_SCALE)


func _printed_width() -> float:
	var digits: float = UiKit.pixel_text_size(amount).x
	return digits + CURRENCY_GAP + currency.size.x


## Where the digits start in the row: the digits and the € centred across it, on the art's grid.
func _left() -> float:
	return 2.0 * floorf((_row.size.x - _printed_width()) / 4.0)


## The digits' caps fill the row's top and the €'s caps stand level with theirs.
func _place_amount() -> void:
	var left: float = _left()
	var digits: float = UiKit.pixel_text_size(amount).x
	UiKit.place_pixel_label(amount, Rect2(left, 0.0, digits + AMOUNT_SCALE, _digits_height()), true)
	currency.position = Vector2(left + digits + CURRENCY_GAP, 0.0)


func _draw_rule() -> void:
	var width: float = _rule.size.x - RULE_INSET * 2.0
	for row: int in range(2):
		var y: float = row * (RULE_WIDTH + RULE_GAP)
		_rule.draw_rect(Rect2(RULE_INSET, y, width, RULE_WIDTH), RULE_COLOR)
