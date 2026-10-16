class_name RegisterCabinet
extends Control
## The shift screen's register (#55, from style frame v2's RegisterView and cabinet): a cream
## marble cabinet between brass pilasters with a velvet "REGISTER 3" plate, the gold LED
## (LedDisplay), the key bed with the big TOTAL key, and the printer slot the receipt hangs from.
## It stands at ShiftStage.REGISTER_RECT and is the count-up's rattle target, so the LED shakes
## with it; its parts are placed in its own coordinates (the stage rects less its position).
## Display only: the TOTAL key is decor (down while a shift is counted), not a button, and it
## takes no clicks.

## The cabinet frame's margin, in art pixels (ShiftStage.PRINTER_SLOT_RECT spans its inside).
const BODY_MARGIN := 4
## The cabinet's plinth, in art pixels: taller than its other margins.
const FOOT_MARGIN := 6
const PLATE_TEXT := "NEXT CUSTOMER · REGISTER 3"
const PLATE_FONT_SIZE := 11
const PLATE_FACE := Palette.VELVET_DARKEST
const PLATE_TEXT_COLOR := Palette.GOLD
const TOTAL_TEXT := "TOTAL"
const TOTAL_FONT_SIZE := 16
## The TOTAL key's caption, on the key's face (from the key's top-left), dropping with it when
## the key is down.
const TOTAL_LABEL_RECT := Rect2(0, 2, 128, 34)
const TOTAL_KEY_DROP := 4.0
## The printer slot: a brass lip PRINTER_LIP tall over a dark slot, PRINTER_SLOT_INSET in from
## each end.
const PRINTER_LIP := 12.0
const PRINTER_SLOT_INSET := 8.0
const SLOT_COLOR := Palette.VELVET_DARKEST

const FRAME := preload("res://art/frames/register_v2.png")
const KEYS := preload("res://art/scenery/register_keys_v2.png")
const TOTAL_KEY_UP := preload("res://art/scenery/register_total_key_up.png")
const TOTAL_KEY_DOWN := preload("res://art/scenery/register_total_key_down.png")

## The LED on the cabinet's front.
var led: LedDisplay
var _total_key: TextureRect
var _total_label: Label


func _init() -> void:
	name = "Register"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	position = ShiftStage.REGISTER_RECT.position
	size = ShiftStage.REGISTER_RECT.size
	var body: PanelContainer = UiKit.frame_panel(FRAME, BODY_MARGIN)
	var style: StyleBoxTexture = body.get_theme_stylebox("panel") as StyleBoxTexture
	style.texture_margin_bottom = FOOT_MARGIN * ArtStyle.ART_SCALE
	_add(body, Rect2(Vector2.ZERO, size)).name = "Body"
	var plate: ColorRect = ColorRect.new()
	plate.color = PLATE_FACE
	_add(plate, local_rect(ShiftStage.PLATE_RECT)).name = "Plate"
	var plate_text: Label = UiKit.display_label(PLATE_TEXT, PLATE_FONT_SIZE, false)
	plate_text.add_theme_color_override("font_color", PLATE_TEXT_COLOR)
	plate_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	plate.add_child(plate_text)
	led = LedDisplay.new()
	_add(led, local_rect(ShiftStage.LED_RECT))
	_add(UiKit.sprite(KEYS), local_rect(ShiftStage.KEYS_RECT)).name = "Keys"
	_total_key = UiKit.sprite(TOTAL_KEY_UP)
	_add(_total_key, local_rect(ShiftStage.TOTAL_KEY_RECT)).name = "TotalKey"
	_total_label = UiKit.display_label(TOTAL_TEXT, TOTAL_FONT_SIZE, false)
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_add(_total_label, _total_label_rect(false)).name = "TotalLabel"
	var slot_rect: Rect2 = local_rect(ShiftStage.PRINTER_SLOT_RECT)
	var lip: Rect2 = Rect2(slot_rect.position, Vector2(slot_rect.size.x, PRINTER_LIP))
	_add(BoutiqueBackdrop.rail(PRINTER_LIP), lip).name = "PrinterSlot"
	var slot: ColorRect = ColorRect.new()
	slot.color = SLOT_COLOR
	var mouth: Rect2 = Rect2(
		slot_rect.position.x + PRINTER_SLOT_INSET,
		lip.end.y,
		slot_rect.size.x - 2.0 * PRINTER_SLOT_INSET,
		slot_rect.end.y - lip.end.y
	)
	_add(slot, mouth).name = "PrinterMouth"


func _ready() -> void:
	# A label's minimum size is only its real one in the tree.
	_total_label.position = _total_label_rect(is_total_down()).position
	_total_label.size = TOTAL_LABEL_RECT.size


## Puts the TOTAL key down (the shift is being counted) or up.
func set_total_down(down: bool) -> void:
	_total_key.texture = TOTAL_KEY_DOWN if down else TOTAL_KEY_UP
	_total_label.position = _total_label_rect(down).position


## Whether the TOTAL key is down.
func is_total_down() -> bool:
	return _total_key.texture == TOTAL_KEY_DOWN


func total_key() -> TextureRect:
	return _total_key


func total_label() -> Label:
	return _total_label


## A stage rect in the cabinet's own coordinates.
static func local_rect(stage_rect: Rect2) -> Rect2:
	return Rect2(stage_rect.position - ShiftStage.REGISTER_RECT.position, stage_rect.size)


func _total_label_rect(down: bool) -> Rect2:
	var rect: Rect2 = TOTAL_LABEL_RECT
	rect.position += local_rect(ShiftStage.TOTAL_KEY_RECT).position
	if down:
		rect.position.y += TOTAL_KEY_DROP
	return rect


func _add(node: Control, rect: Rect2) -> Control:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = rect.position
	node.size = rect.size
	add_child(node)
	return node
