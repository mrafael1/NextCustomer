class_name ToyMachineView
extends Control
## One TOY MACHINE (#63, mock-up capsule_63_a.html look A; full build plan 7.1): a globe capsule
## machine of one aisle, 144x280 (the 72x140 art at 2x), standing on the exit's floor. Its body is
## the aisle's recolour of the machine (art/scenery/toy_machine_<aisle>.png, or the teal base for
## an aisle without one); the globe shows one capsule per item left (at most SLOTS' count), the
## sign carries the aisle's glyph and name, and a price-gun label says what a capsule costs.
##
## Its state (CapsuleCounter.State) always shows by more than colour: OK takes clicks (a pointing
## hand; hover lifts it LIFT px and brightens it); EMPTY wears the ALL COLLECTED rosette and no
## price; BROKE (not enough coins) is dimmed; OFF (the profile can't be saved) is darker and
## carries an OUT OF ORDER paper. Only an OK machine takes clicks: the others keep the arrow
## cursor. #64 animates the draw; here a click only reports `picked`.

signal picked(aisle: AisleDefinition)

const SIZE := Vector2(144, 280)
const BODY_PATH := "res://art/scenery/toy_machine_%s.png"
const BASE_BODY := preload("res://art/scenery/toy_machine.png")
const CAPSULE_PATH := "res://art/scenery/toy_capsule_%s.png"
const BASE_CAPSULE := preload("res://art/scenery/toy_capsule.png")
const COIN := preload("res://art/icons/coin.png")
const LABEL_FRAME := preload("res://art/effects/sticker_label.png")
const BURST := preload("res://art/effects/sticker_burst.png")
## The globe's capsule spots (centres, art px from the body's top left), filled in this order.
const SLOTS: Array[Vector2i] = [
	Vector2i(24, 69),
	Vector2i(36, 70),
	Vector2i(48, 69),
	Vector2i(30, 59),
	Vector2i(42, 59),
	Vector2i(19, 60),
	Vector2i(53, 60),
	Vector2i(36, 49),
]
## A capsule's art size (13x13) and its centre pixel.
const CAPSULE_ART := 13
const CAPSULE_CENTRE := 6
## The sign's text band (glyph and name) over the painted board, and its font sizes: the name
## shrinks from SIGN_FONT_MAX to SIGN_FONT_MIN until it fits SIGN_PADDING inside the band.
const SIGN_RECT := Rect2(0, 6, 144, 26)
const SIGN_FONT_MAX := 18
const SIGN_FONT_MIN := 14
const SIGN_PADDING := 6.0
const SIGN_OUTLINE := 4
const GLYPH_SIZE := Vector2(18, 18)
const SIGN_GAP := 6
## The "1 coin" label slapped on the globe, tilted; moved left when needed so it stays
## PRICE_MARGIN inside the machine's right edge.
const PRICE_POSITION := Vector2(64, 50)
const PRICE_MARGIN := 4.0
const PRICE_ROTATION := 9.0
const PRICE_FONT_SIZE := 14
const PRICE_ICON_SIZE := Vector2(24, 24)
## The ALL COLLECTED rosette over the globe (sticker_burst at 4x) and its tilt.
const ROSETTE_RECT := Rect2(10, 70, 124, 68)
const ROSETTE_ROTATION := -8.0
const ROSETTE_FONT_SIZE := 14
## The OUT OF ORDER paper taped over the globe.
const PAPER_POSITION := Vector2(30, 78)
const PAPER_WIDTH := 84.0
const PAPER_ROTATION := -4.0
const PAPER_FONT_SIZE := 16
const TAPE_SIZE := Vector2(22, 10)
## The machine's contact shadow on the floor, right of its base (the light is upper left).
const SHADOW_RECT := Rect2(30, 266, 108, 16)
const SHADOW_ALPHA := 0.18
## The clickable parts: the sign board and the globe with the body, not the empty margins.
const SIGN_HIT := Rect2(2, 0, 140, 38)
const BODY_HIT := Rect2(16, 38, 112, 242)
const LIFT := 4.0
const HOVER_MODULATE := Color(1.12, 1.12, 1.12)
const BROKE_MODULATE := Color(0.74, 0.74, 0.76)
const OFF_MODULATE := Color(0.66, 0.66, 0.66)
const ROSETTE_TEXT := "ALL\nCOLLECTED"
const PAPER_TEXT := "OUT OF\nORDER"
const PRICE_TEXT := "%d coin"
const PRICE_TEXT_PLURAL := "%d coins"

var _aisle: AisleDefinition
var _state: CapsuleCounter.State = CapsuleCounter.State.OK
var _hovered: bool = false
## Everything that lifts on hover; _art is dimmed by the state, the overlays never are.
var _lift: Control
var _art: Control
var _body: TextureRect
var _capsules: Control
var _sign: HBoxContainer
var _glyph: TextureRect
var _sign_label: Label
var _price: PanelContainer
var _price_label: Label
var _rosette: TextureRect
var _paper: Control


func _init() -> void:
	size = SIZE
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shadow: ContactShadow = ContactShadow.new(SHADOW_ALPHA)
	shadow.position = SHADOW_RECT.position
	shadow.size = SHADOW_RECT.size
	add_child(shadow)
	_lift = Control.new()
	_lift.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lift.size = SIZE
	add_child(_lift)
	_art = Control.new()
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.size = SIZE
	_lift.add_child(_art)
	_body = UiKit.sprite(BASE_BODY)
	_body.size = SIZE
	_art.add_child(_body)
	_capsules = Control.new()
	_capsules.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.add_child(_capsules)
	_build_sign()
	_build_price()
	_build_rosette()
	_build_paper()
	mouse_entered.connect(_on_hover.bind(true))
	mouse_exited.connect(_on_hover.bind(false))


## Shows the `shown` aisle's machine with `left` of its `total` items still in it, in
## `shown_state`, a capsule costing `price` coins.
func set_machine(
	shown: AisleDefinition, left: int, total: int, shown_state: CapsuleCounter.State, price: int
) -> void:
	_aisle = shown
	_state = shown_state
	_body.texture = _texture(BODY_PATH % shown.id, BASE_BODY)
	_place_capsules(_texture(CAPSULE_PATH % shown.id, BASE_CAPSULE), mini(left, SLOTS.size()))
	_glyph.texture = load(ArtStyle.glyph_path(shown)) as Texture2D
	_fit_sign(shown.display_name)
	_price_label.text = price_text(price)
	_price.size = _price.get_combined_minimum_size()
	_price.position.x = minf(PRICE_POSITION.x, SIZE.x - PRICE_MARGIN - _price.size.x)
	var ok: bool = shown_state == CapsuleCounter.State.OK
	_price.visible = ok or shown_state == CapsuleCounter.State.BROKE
	_rosette.visible = shown_state == CapsuleCounter.State.EMPTY
	_paper.visible = shown_state == CapsuleCounter.State.OFF
	mouse_default_cursor_shape = CURSOR_POINTING_HAND if ok else CURSOR_ARROW
	tooltip_text = ""
	accessibility_name = "%s, %d of %d left" % [shown.display_name, left, total]
	if not ok:
		_hovered = false
	_show_look()


## "1 coin" / "2 coins".
static func price_text(price: int) -> String:
	return (PRICE_TEXT if price == 1 else PRICE_TEXT_PLURAL) % price


func aisle() -> AisleDefinition:
	return _aisle


func state() -> CapsuleCounter.State:
	return _state


## The sign's name label, the price label, the rosette and the paper (for tests).
func sign_label() -> Label:
	return _sign_label


func sign_rect() -> Rect2:
	return Rect2(SIGN_RECT.position + global_position, SIGN_RECT.size)


func price_label() -> PanelContainer:
	return _price


func rosette() -> TextureRect:
	return _rosette


func paper() -> Control:
	return _paper


## How many capsules the globe shows.
func capsule_count() -> int:
	return _capsules.get_child_count()


func is_lifted() -> bool:
	return _lift.position.y < 0.0


func _has_point(point: Vector2) -> bool:
	return SIGN_HIT.has_point(point) or BODY_HIT.has_point(point)


func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	if _state == CapsuleCounter.State.OK and _aisle != null:
		picked.emit(_aisle)


func _on_hover(inside: bool) -> void:
	_hovered = inside and _state == CapsuleCounter.State.OK
	_show_look()


## The lift and brightness of hover, and the state's dimming.
func _show_look() -> void:
	_lift.position.y = -LIFT if _hovered else 0.0
	match _state:
		CapsuleCounter.State.BROKE:
			_art.modulate = BROKE_MODULATE
		CapsuleCounter.State.OFF:
			_art.modulate = OFF_MODULATE
		_:
			_art.modulate = HOVER_MODULATE if _hovered else Color.WHITE


func _build_sign() -> void:
	_sign = HBoxContainer.new()
	_sign.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sign.alignment = BoxContainer.ALIGNMENT_CENTER
	_sign.add_theme_constant_override("separation", SIGN_GAP)
	_sign.position = SIGN_RECT.position
	_sign.size = SIGN_RECT.size
	_lift.add_child(_sign)
	_glyph = UiKit.sprite(null)
	_glyph.custom_minimum_size = GLYPH_SIZE
	_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_sign.add_child(_glyph)
	_sign_label = UiKit.display_label("", SIGN_FONT_MAX, true)
	_sign_label.add_theme_constant_override("outline_size", SIGN_OUTLINE)
	_sign_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sign.add_child(_sign_label)


## The name at the largest size from SIGN_FONT_MAX down that fits the band with the glyph.
func _fit_sign(text: String) -> void:
	_sign_label.text = text
	var room: float = SIGN_RECT.size.x - 2.0 * SIGN_PADDING - GLYPH_SIZE.x - SIGN_GAP
	for font_size: int in range(SIGN_FONT_MAX, SIGN_FONT_MIN - 1, -1):
		_sign_label.add_theme_font_size_override("font_size", font_size)
		if _sign_label.get_minimum_size().x <= room:
			break
	_sign.size = SIGN_RECT.size


func _build_price() -> void:
	_price = UiKit.frame_panel(LABEL_FRAME, 3, Vector4(10, 4, 12, 6))
	_price.position = PRICE_POSITION
	_price.rotation_degrees = PRICE_ROTATION
	_lift.add_child(_price)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 4)
	_price.add_child(row)
	var coin: TextureRect = UiKit.sprite(COIN)
	coin.custom_minimum_size = PRICE_ICON_SIZE
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(coin)
	_price_label = UiKit.body_label("", PRICE_FONT_SIZE, Palette.INK)
	_price_label.add_theme_font_override("font", ArtStyle.bold_font(ArtStyle.NUMBER_WEIGHT))
	_price_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_price_label)


func _build_rosette() -> void:
	_rosette = UiKit.sprite(BURST)
	_rosette.position = ROSETTE_RECT.position
	_rosette.size = ROSETTE_RECT.size
	_rosette.pivot_offset = ROSETTE_RECT.size / 2.0
	_rosette.rotation_degrees = ROSETTE_ROTATION
	_rosette.visible = false
	_lift.add_child(_rosette)
	var text: Label = UiKit.body_label(ROSETTE_TEXT, ROSETTE_FONT_SIZE, Palette.INK)
	text.add_theme_font_override("font", ArtStyle.bold_font(800))
	text.add_theme_constant_override("line_spacing", -4)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rosette.add_child(text)


func _build_paper() -> void:
	_paper = Control.new()
	_paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_paper.position = PAPER_POSITION
	_paper.rotation_degrees = PAPER_ROTATION
	_paper.visible = false
	_lift.add_child(_paper)
	var sheet: PanelContainer = PanelContainer.new()
	sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.PAPER
	style.border_color = Palette.INK
	style.set_border_width_all(3)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 4
	style.content_margin_bottom = 6
	style.shadow_color = Color(Palette.INK, 0.3)
	style.shadow_offset = Vector2(3, 3)
	sheet.add_theme_stylebox_override("panel", style)
	sheet.custom_minimum_size.x = PAPER_WIDTH
	_paper.add_child(sheet)
	var text: Label = UiKit.display_label(PAPER_TEXT, PAPER_FONT_SIZE, false)
	text.add_theme_color_override("font_color", Palette.TOMATO_DARK)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sheet.add_child(text)
	_paper.size = sheet.get_combined_minimum_size()
	for side: int in [-1, 1]:
		var tape: ColorRect = ColorRect.new()
		tape.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tape.color = Color(Palette.MUSTARD_PALE, 0.85)
		tape.size = TAPE_SIZE
		tape.pivot_offset = TAPE_SIZE / 2.0
		tape.rotation_degrees = 30.0 * side
		tape.position = Vector2(-8.0 if side < 0 else PAPER_WIDTH - TAPE_SIZE.x + 8.0, -6.0)
		_paper.add_child(tape)


## One capsule sprite (2x) per item left, on the first `count` SLOTS.
func _place_capsules(texture: Texture2D, count: int) -> void:
	for child: Node in _capsules.get_children():
		_capsules.remove_child(child)
		child.queue_free()
	var scale_px: float = ArtStyle.ART_SCALE
	for index: int in range(count):
		var spot: Vector2i = SLOTS[index]
		var capsule: TextureRect = UiKit.sprite(texture)
		capsule.size = Vector2(CAPSULE_ART, CAPSULE_ART) * scale_px
		capsule.position = Vector2(spot - Vector2i(CAPSULE_CENTRE, CAPSULE_CENTRE)) * scale_px
		_capsules.add_child(capsule)


static func _texture(path: String, fallback: Texture2D) -> Texture2D:
	return load(path) as Texture2D if ResourceLoader.exists(path) else fallback
