class_name RegisterCabinet
extends Control
## The shift screen's cash register (#80, mock-up B2): the printer box on the counter top that
## the receipt rises from (pixel art, step 5; the slot's lip over the paper is the stage's
## ShiftStage.printer_lip, drawn above the receipt), and under it the register column (step 9):
## its wooden front, the charcoal key deck with the keys on it (CHECKOUT's bar key, Redraw, and
## Cancel in redraw mode, all RegisterKeys), the quiet keypad, the seed line under Redraw, and the
## cash drawer, static and slightly ajar so its coin tray shows. It stands at
## ShiftStage.REGISTER_RECT and is the count-up's rattle target, so the keys shake with it; its
## parts are placed in its own coordinates (the stage rects less its position). Only the keys
## take clicks: the stage connects them to its signals.

## The printer box (art/src/scenery/printer_box.txt), drawn 1:1 at ShiftStage.PRINTER_RECT with
## its paper slot at ShiftStage.PRINTER_SLOT_RECT.
const PRINTER_BOX := preload("res://art/scenery/printer_box.png")
## The column's wooden front and the key deck, 9-slices with COLUMN_MARGIN and DECK_MARGIN art px.
const COLUMN_FRAME := preload("res://art/frames/register_column.png")
const COLUMN_MARGIN := 4
const DECK_FRAME := preload("res://art/frames/register_deck.png")
const DECK_MARGIN := 3
## The deck's hard shadow on the column, down and right (ink at DECK_SHADOW_ALPHA): B2's
## 4 px band on the right and along the bottom, so it is DECK_SHADOW_SHORTER px shorter than the
## deck and ends 4 px above the drawer.
const DECK_SHADOW_OFFSET := Vector2(4, 6)
const DECK_SHADOW_SHORTER := 2.0
const DECK_SHADOW_ALPHA := 0.4
## The keypad and the drawer, drawn 1:1 at ShiftStage.KEYPAD_RECT and ShiftStage.DRAWER_RECT.
const KEYPAD := preload("res://art/scenery/register_keypad.png")
const DRAWER := preload("res://art/scenery/cash_drawer.png")
## CHECKOUT's caption as B2 sets it: the word in the display font, its glyphs CHECKOUT_SPACING
## px apart, then CHECKOUT_ARROW_GAP px on a smaller "›" (CHECKOUT_ARROW_SIZE), the pair centred.
const CHECKOUT_TEXT := "CHECKOUT"
const CHECKOUT_SPACING := 2
const CHECKOUT_ARROW := "›"
const CHECKOUT_ARROW_SIZE := 26
const CHECKOUT_ARROW_GAP := 14.0
## CHECKOUT's name for screen readers (its caption's "›" is decoration).
const CHECKOUT_NAME := "Checkout"
const CANCEL_TEXT := "Cancel"
const BUTTON_FONT_SIZE := 16
## The Redraw key's caption, as B2's .redraw sets it (the display font at 18 px).
const REDRAW_FONT_SIZE := 18
const CHECKOUT_FONT_SIZE := 30
## The seed line: B2's .foot, the body font at SEED_FONT_WEIGHT.
const SEED_FONT_SIZE := 11
const SEED_FONT_WEIGHT := 600

var checkout_key: RegisterKey
var redraw_key: RegisterKey
## Shown in redraw mode only (the screen shows it), over the keypad, which hides meanwhile.
var cancel_key: RegisterKey
var seed_label: Label
var keypad: TextureRect
## CHECKOUT's "›", a child of its caption label (so it sinks and fades with it).
var checkout_arrow: Label


func _init() -> void:
	name = "Register"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = ShiftStage.REGISTER_RECT.position
	size = ShiftStage.REGISTER_RECT.size
	var column: PanelContainer = UiKit.frame_panel(COLUMN_FRAME, COLUMN_MARGIN)
	_add(column, local_rect(ShiftStage.COLUMN_RECT)).name = "Column"
	_add(UiKit.sprite(PRINTER_BOX), local_rect(ShiftStage.PRINTER_RECT)).name = "Printer"
	var shadow: ColorRect = ColorRect.new()
	shadow.color = Color(Palette.INK, DECK_SHADOW_ALPHA)
	var shadow_rect: Rect2 = local_rect(ShiftStage.DECK_RECT)
	shadow_rect.position += DECK_SHADOW_OFFSET
	shadow_rect.size.y -= DECK_SHADOW_SHORTER
	_add(shadow, shadow_rect).name = "DeckShadow"
	var deck: PanelContainer = UiKit.frame_panel(DECK_FRAME, DECK_MARGIN)
	_add(deck, local_rect(ShiftStage.DECK_RECT)).name = "Deck"
	keypad = UiKit.sprite(KEYPAD)
	_add(keypad, local_rect(ShiftStage.KEYPAD_RECT)).name = "Keypad"
	_add(UiKit.sprite(DRAWER), local_rect(ShiftStage.DRAWER_RECT)).name = "Drawer"
	_build_keys()


func _ready() -> void:
	# A label's minimum size is its real one only in the tree (as ShiftStage's labels).
	var rect: Rect2 = local_rect(ShiftStage.SEED_RECT)
	seed_label.position = rect.position
	seed_label.size = rect.size


## Puts CHECKOUT down (the shift is being counted: its held look) or up.
func set_total_down(down: bool) -> void:
	checkout_key.held = down


## A stage rect in the cabinet's own coordinates.
static func local_rect(stage_rect: Rect2) -> Rect2:
	return Rect2(stage_rect.position - ShiftStage.REGISTER_RECT.position, stage_rect.size)


## CHECKOUT, Redraw and Cancel on the key deck, and the seed line under Redraw.
func _build_keys() -> void:
	cancel_key = _key(RegisterKey.Kind.CREAM, CANCEL_TEXT, ShiftStage.CANCEL_RECT)
	cancel_key.visible = false
	cancel_key.visibility_changed.connect(_on_cancel_shown)
	redraw_key = _key(RegisterKey.Kind.CREAM, "", ShiftStage.REDRAW_RECT, REDRAW_FONT_SIZE)
	checkout_key = _key(RegisterKey.Kind.CHECKOUT, CHECKOUT_TEXT, ShiftStage.CHECKOUT_RECT)
	checkout_key.accessibility_name = CHECKOUT_NAME
	_set_checkout_caption(checkout_key.caption_label())
	seed_label = UiKit.body_label("", SEED_FONT_SIZE, Color(Palette.CREAM_SHADE, 0.85))
	seed_label.add_theme_font_override("font", ArtStyle.bold_font(SEED_FONT_WEIGHT))
	seed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	seed_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_add(seed_label, local_rect(ShiftStage.SEED_RECT))


## CHECKOUT's spaced word in paper, and the "›" after it: the caption ends short of the key's
## right edge by the gap and the "›", so the word sits left of centre and the pair is centred.
func _set_checkout_caption(caption: Label) -> void:
	var word_font: Font = ArtStyle.spaced_display_font(CHECKOUT_SPACING)
	caption.add_theme_font_override("font", word_font)
	caption.add_theme_color_override("font_color", Palette.PAPER)
	caption.add_theme_constant_override("outline_size", 0)
	var arrow_width: float = (
		ArtStyle
		. DISPLAY_FONT
		. get_string_size(CHECKOUT_ARROW, HORIZONTAL_ALIGNMENT_LEFT, -1, CHECKOUT_ARROW_SIZE)
		. x
	)
	caption.offset_right = -(CHECKOUT_ARROW_GAP + arrow_width)
	var word_width: float = (
		word_font
		. get_string_size(CHECKOUT_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, CHECKOUT_FONT_SIZE)
		. x
	)
	checkout_arrow = UiKit.display_label(CHECKOUT_ARROW, CHECKOUT_ARROW_SIZE, false)
	checkout_arrow.name = "Arrow"
	checkout_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	checkout_arrow.add_theme_color_override("font_color", Palette.PAPER)
	checkout_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# The word is centred on the caption, so the "›" stands its half width and the gap after that.
	checkout_arrow.anchor_left = 0.5
	checkout_arrow.anchor_right = 0.5
	checkout_arrow.anchor_bottom = 1.0
	checkout_arrow.offset_left = word_width / 2.0 + CHECKOUT_ARROW_GAP
	checkout_arrow.offset_right = checkout_arrow.offset_left + arrow_width
	caption.add_child(checkout_arrow)


## A key of `kind` captioned `text` at the stage rect `rect` in `font_size` (CHECKOUT's always in
## CHECKOUT_FONT_SIZE); a cream key's caption is plain ink.
func _key(
	kind: RegisterKey.Kind, text: String, rect: Rect2, font_size: int = BUTTON_FONT_SIZE
) -> RegisterKey:
	if kind == RegisterKey.Kind.CHECKOUT:
		font_size = CHECKOUT_FONT_SIZE
	var key: RegisterKey = RegisterKey.new(kind, text, font_size, rect.size)
	if kind == RegisterKey.Kind.CREAM:
		key.caption_label().add_theme_color_override("font_color", Palette.INK)
		key.caption_label().add_theme_constant_override("outline_size", 0)
	key.position = local_rect(rect).position
	add_child(key)
	return key


## Cancel stands in the keypad's place: the keypad hides while Cancel shows.
func _on_cancel_shown() -> void:
	keypad.visible = not cancel_key.visible


func _add(node: Control, rect: Rect2) -> Control:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = rect.position
	node.size = rect.size
	add_child(node)
	return node
