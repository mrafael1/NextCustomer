class_name RegisterView
extends Control
## The register's front in style frame v2 (#75; round 2, delta section 6), over its cabinet: the
## velvet plate, the LED total, the key bed (a cream numeric pad, a velvet key and a green key),
## the big gold TOTAL key (down while counting: CHECKOUT was just pressed) and the printer slot
## the receipt hangs from. It spans the stage, so its parts are placed in stage coordinates. The
## LED shows what the caller passes (the ScoreResult's numbers); nothing here scores.

const PLATE_RECT := Rect2(960, 76, 288, 20)
const PLATE_TEXT := "NEXT CUSTOMER · REGISTER 3"
const PLATE_SIZE := 11
const LED_POSITION := Vector2(960, 100)
const KEYS_RECT := Rect2(960, 204, 288, 56)
## The big TOTAL key over the key bed's well; its label drops with it when it is down.
const TOTAL_KEY_RECT := Rect2(1116, 208, 128, 48)
const TOTAL_LABEL_RECT := Rect2(1116, 210, 128, 34)
const TOTAL_KEY_DROP := 4.0
const TOTAL_TEXT := "TOTAL"
const TOTAL_SIZE := 16
const PRINTER_SLOT_RECT := Rect2(952, 264, 304, 16)
const PRINTER_LIP := 12.0
const PRINTER_SLOT_INSET := 8.0

const BRASS_RAIL := preload("res://art/frames/brass_rail.png")
const KEYS := preload("res://art/scenery/register_keys_v2.png")
const TOTAL_KEY_UP := preload("res://art/scenery/register_total_key_up.png")
const TOTAL_KEY_DOWN := preload("res://art/scenery/register_total_key_down.png")

var _led: LedTotal
var _total_key: TextureRect
var _total_label: Label


## The register's front, its TOTAL key down when `total_down`.
func _init(total_down: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = StyleFrameV2.STAGE_SIZE
	var plate: ColorRect = ColorRect.new()
	plate.color = StyleFrameV2.VELVET_DARKEST
	_add(plate, PLATE_RECT).name = "Plate"
	var plate_text: Label = UiKit.display_label(PLATE_TEXT, PLATE_SIZE, false)
	plate_text.add_theme_color_override("font_color", StyleFrameV2.GOLD)
	plate_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	plate_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	plate_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	plate.add_child(plate_text)
	_led = LedTotal.new()
	_led.name = "Led"
	_led.position = LED_POSITION
	add_child(_led)
	_add(UiKit.sprite(KEYS), KEYS_RECT).name = "Keys"
	_total_key = UiKit.sprite(TOTAL_KEY_DOWN if total_down else TOTAL_KEY_UP)
	_add(_total_key, TOTAL_KEY_RECT).name = "TotalKey"
	_total_label = UiKit.display_label(TOTAL_TEXT, TOTAL_SIZE, false)
	_total_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_total_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var label_rect: Rect2 = TOTAL_LABEL_RECT
	if total_down:
		label_rect.position.y += TOTAL_KEY_DROP
	_add(_total_label, label_rect).name = "TotalLabel"
	var lip: Rect2 = Rect2(
		PRINTER_SLOT_RECT.position, Vector2(PRINTER_SLOT_RECT.size.x, PRINTER_LIP)
	)
	_add(rail(PRINTER_LIP), lip).name = "PrinterSlot"
	var slot: ColorRect = ColorRect.new()
	slot.color = StyleFrameV2.VELVET_DARKEST
	var slot_rect: Rect2 = Rect2(
		PRINTER_SLOT_RECT.position.x + PRINTER_SLOT_INSET,
		lip.end.y,
		PRINTER_SLOT_RECT.size.x - 2.0 * PRINTER_SLOT_INSET,
		PRINTER_SLOT_RECT.end.y - lip.end.y
	)
	_add(slot, slot_rect)


func led() -> LedTotal:
	return _led


func total_key() -> TextureRect:
	return _total_key


func total_label() -> Label:
	return _total_label


## Whether the TOTAL key is down.
func is_total_down() -> bool:
	return _total_key.texture == TOTAL_KEY_DOWN


## A brass rail `height` canvas pixels tall: the rail's top rows (paper glint, gold, brass), or
## its brass and dark brass for the 4 px picture rail. Every column is the same, so it stretches
## sideways.
static func rail(height: float) -> TextureRect:
	var region: AtlasTexture = AtlasTexture.new()
	region.atlas = BRASS_RAIL
	var top: float = 2.0 * ArtStyle.ART_SCALE if height <= 2.0 * ArtStyle.ART_SCALE else 0.0
	region.region = Rect2(0, top, BRASS_RAIL.get_width(), height)
	return UiKit.sprite(region)


func _add(node: Control, rect: Rect2) -> Control:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.position = rect.position
	node.size = rect.size
	add_child(node)
	return node
