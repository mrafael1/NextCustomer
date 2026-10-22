class_name ToyReveal
extends Control
## The plain reveal of a drawn capsule (#63, mock-up capsule_63_a.html; full build plan 7.1): over
## a shade on the TOY MACHINES stage, the figurine (the item's sprite at 2x, 96x96, or its
## art-pending box with the name printed in it) on a gold medallion before a sunburst, a NEW!
## burst, the name on a cream price-gun label, the aisle's glyph and name, the stock line ("In
## stock from your next run", or after the saved run) and OK. No rule text and no card: the shelf
## and the deck view show those. It pops in with UiKit.pop_in, the readable result #64's animated
## draw ends on.
##
## The draw click never closes it: it arms ResultsPanel.ARM_MS after it opens, once the mouse is
## up. Then OK, a click anywhere, Enter or Space hides it and emits `dismissed`.

signal dismissed

const STAGE := Vector2(1280, 720)
## The content box popped in at the stage's centre, and its pieces in the box's coordinates
## (the medallion's centre at stage (640, 310)).
const BOX_SIZE := Vector2(520, 500)
const CENTRE_X := 260.0
const MEDALLION := preload("res://art/effects/toy_medallion.png")
const BURST := preload("res://art/effects/sticker_burst.png")
const LABEL_FRAME := preload("res://art/effects/sticker_label.png")
const MEDALLION_CENTRE := Vector2(260, 200)
const MEDALLION_SIZE := Vector2(112, 112)
## The rays end above the aisle and stock lines, muted over the shade (the mock-up's look).
const SUNBURST_SIZE := Vector2(260, 260)
const SUNBURST_ALPHA := 0.35
## NEW! is stuck on the medallion's top right, over the figurine's corner (the mock-up's place).
const NEW_RECT := Rect2(296, 116, 93, 51)
const NEW_ROTATION := -8.0
const NAME_CENTRE_Y := 285.0
const NAME_HEIGHT := 52.0
const NAME_FONT_SIZE := 30
const AISLE_CENTRE_Y := 346.0
const AISLE_FONT_SIZE := 20
const GLYPH_SIZE := Vector2(18, 18)
const STOCK_CENTRE_Y := 386.0
const STOCK_FONT_SIZE := 18
const STOCK_ROTATION := -2.0
const OK_SIZE := Vector2(150, 48)
const OK_TOP := 418.0
const TIP_CENTRE_Y := 482.0
const TIP_FONT_SIZE := 14
const SHADE := Color(ArtStyle.INK, 0.45)
const NEW_TEXT := "NEW!"
const OK_TEXT := "OK"
const TIP_TEXT := "Click anywhere"

var _box: Control
var _sunburst: Sunburst
var _figurine: TextureRect
var _new: TextureRect
var _name_panel: PanelContainer
var _name: Label
var _aisle_row: HBoxContainer
var _glyph: TextureRect
var _aisle_name: Label
var _stock_panel: PanelContainer
var _stock: Label
var _ok: FramedButton
var _tip: Label
var _armed: bool = false
var _arm_at_ms: int = 0


func _init() -> void:
	size = STAGE
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var shade: ColorRect = ColorRect.new()
	shade.color = SHADE
	shade.size = STAGE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	_box = Control.new()
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.custom_minimum_size = BOX_SIZE
	add_child(_box)
	_sunburst = Sunburst.new(SUNBURST_SIZE, SUNBURST_SIZE / 2.0)
	_sunburst.set_met(true)
	# Rays only, with clear gaps (the mock-up's rays), so the texts under it stay readable.
	# The shader writes its colours as they are (modulate doesn't reach them), so the rays' alpha
	# is in the colour, and the radius stays inside the rect, so no ray is cut square.
	var rays: ShaderMaterial = _sunburst.material as ShaderMaterial
	rays.set_shader_parameter(&"gap_colour", Color(0, 0, 0, 0))
	rays.set_shader_parameter(&"ray_colour", Color(Sunburst.MET_RAY_COLOR, SUNBURST_ALPHA))
	rays.set_shader_parameter(&"radius", SUNBURST_SIZE.x / 2.0)
	_sunburst.position = MEDALLION_CENTRE - SUNBURST_SIZE / 2.0
	_box.add_child(_sunburst)
	var medallion: TextureRect = UiKit.sprite(MEDALLION)
	medallion.size = MEDALLION_SIZE
	medallion.position = MEDALLION_CENTRE - MEDALLION_SIZE / 2.0
	_box.add_child(medallion)
	_new = UiKit.sprite(BURST)
	_new.position = NEW_RECT.position
	_new.size = NEW_RECT.size
	_new.pivot_offset = NEW_RECT.size / 2.0
	_new.rotation_degrees = NEW_ROTATION
	_box.add_child(_new)
	var new_text: Label = UiKit.body_label(NEW_TEXT, 18, Palette.INK)
	new_text.add_theme_font_override("font", ArtStyle.bold_font(800))
	new_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	new_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	new_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_new.add_child(new_text)
	_build_texts()


## Shows `card` drawn from `aisle`'s machine with the stock line `stock`, popped in; armed once
## ResultsPanel.ARM_MS has passed and the mouse is up.
func show_card(card: CardDefinition, aisle: AisleDefinition, stock: String) -> void:
	if _figurine != null:
		_box.remove_child(_figurine)
		_figurine.queue_free()
	_figurine = ItemView.item_art(card)
	_figurine.position = MEDALLION_CENTRE - ItemView.SPRITE_SIZE / 2.0
	_box.add_child(_figurine)
	_box.move_child(_figurine, _new.get_index())
	_name.text = card.display_name
	_glyph.texture = load(ArtStyle.glyph_path(aisle)) as Texture2D
	_aisle_name.text = aisle.display_name
	_stock.text = stock
	_arm_at_ms = Time.get_ticks_msec() + ResultsPanel.ARM_MS
	_armed = false
	_ok.disabled = true
	visible = true
	_place_texts()
	UiKit.pop_in(_box)


func is_armed() -> bool:
	return _armed


## Hides the reveal and reports it (OK, a click anywhere, Enter or Space once armed).
func dismiss() -> void:
	if not visible or not _armed:
		return
	visible = false
	dismissed.emit()


## The pieces, for tests: the figurine, NEW!, the name, the aisle row, the stock line, OK, the
## tip, and the content box.
func figurine() -> TextureRect:
	return _figurine


func new_burst() -> TextureRect:
	return _new


func name_label() -> Label:
	return _name


func aisle_label() -> Label:
	return _aisle_name


func stock_label() -> Label:
	return _stock


func ok_button() -> FramedButton:
	return _ok


func tip_label() -> Label:
	return _tip


func sunburst() -> Sunburst:
	return _sunburst


func pieces() -> Array[Control]:
	return [_figurine, _new, _name_panel, _aisle_row, _stock_panel, _ok, _tip]


func _process(_delta: float) -> void:
	if not visible or _armed or Time.get_ticks_msec() < _arm_at_ms:
		return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_armed = true
		_ok.disabled = false


func _gui_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		dismiss()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if not visible or key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER or key.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		dismiss()


func _build_texts() -> void:
	_name_panel = UiKit.frame_panel(LABEL_FRAME, 3, Vector4(22, 0, 22, 4))
	_name_panel.custom_minimum_size.y = NAME_HEIGHT
	_box.add_child(_name_panel)
	_name = UiKit.display_label("", NAME_FONT_SIZE, false)
	_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_name_panel.add_child(_name)
	_aisle_row = HBoxContainer.new()
	_aisle_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aisle_row.add_theme_constant_override("separation", 8)
	_box.add_child(_aisle_row)
	_glyph = UiKit.sprite(null)
	_glyph.custom_minimum_size = GLYPH_SIZE
	_glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_aisle_row.add_child(_glyph)
	_aisle_name = UiKit.display_label("", AISLE_FONT_SIZE, true)
	_aisle_name.add_theme_constant_override("outline_size", 4)
	_aisle_row.add_child(_aisle_name)
	_stock_panel = PanelContainer.new()
	_stock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Palette.PANEL
	style.border_color = Palette.INK
	style.set_border_width_all(3)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 5
	style.content_margin_bottom = 7
	style.shadow_color = Color(Palette.INK, 0.35)
	style.shadow_offset = Vector2(3, 3)
	_stock_panel.add_theme_stylebox_override("panel", style)
	_stock_panel.rotation_degrees = STOCK_ROTATION
	_box.add_child(_stock_panel)
	_stock = UiKit.body_label("", STOCK_FONT_SIZE, Palette.PAPER)
	_stock.add_theme_font_override("font", ArtStyle.bold_font(700))
	_stock_panel.add_child(_stock)
	_ok = UiKit.framed_button(_box, OK_TEXT, dismiss, 22, UiKit.BUTTON_FRAME, OK_SIZE, "")
	_tip = UiKit.body_label(TIP_TEXT, TIP_FONT_SIZE, Palette.CREAM_SHADE)
	_tip.add_theme_font_override("font", ArtStyle.bold_font(600))
	_box.add_child(_tip)


## Centres every text row on the box's middle at its row's height.
func _place_texts() -> void:
	_centre(_name_panel, NAME_CENTRE_Y)
	_centre(_aisle_row, AISLE_CENTRE_Y)
	_centre(_stock_panel, STOCK_CENTRE_Y)
	_stock_panel.pivot_offset = _stock_panel.size / 2.0
	_ok.size = _ok.custom_minimum_size
	_ok.position = Vector2(CENTRE_X - _ok.size.x / 2.0, OK_TOP)
	_centre(_tip, TIP_CENTRE_Y)


func _centre(control: Control, centre_y: float) -> void:
	control.size = control.get_combined_minimum_size()
	control.position = (Vector2(CENTRE_X, centre_y) - control.size / 2.0).round()
