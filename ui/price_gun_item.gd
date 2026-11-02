class_name PriceGunItem
extends Control
## Price gun's labeller (#132; the 2026-11-02 play review: a little tool on the counter, not a
## key): the pixel-art gun (art/src/scenery/price_gun.txt, 40x22 texels drawn 2x) lying on the
## counter in front of the printer's right end at ShiftStage-space RECT, over its contact shadow
## (a stepped ink ellipse under its foot, ContactShadow), and a small paper tag on a string beside
## it reading the relabels left ("1 left"). PinFlow shows it in planning while the pin is worn
## (show_gun) and connects `pressed`.
##
## A hover lifts it a little; armed, it is picked up (lifted and tilted back) in a 1-ring mustard
## halo (ArtStyle.halo_material), its shadow shrinking and fading under it. With no relabel left
## it lies dimmed (SPENT_DIM, still in its colours, so it reads on the dark printer) and its tag
## stays paper, its text greyed (the tag's move or take-back stays free, so it still answers a
## click). Every change steps at once under reduced motion.

## Sent on a left click (after its click sound).
signal pressed

const TEXTURE := preload("res://art/scenery/price_gun.png")
## Where it lies, in stage coordinates: right of the receipt's foot, left of the belt, over the
## printer's right end and the bagging shelf's side, above the register column.
const RECT := Rect2(262, 348, 80, 44)
const TIP := "Price gun: click, then click an item to give it a family"
const TIP_SPENT := "Price gun: none left (click, then click the tagged item to move its tag)"
const LEFT_TEXT := "%d left"
## The tag on its string: its top left from the gun's, its font size; the string runs from the
## tag's top right to the gun's trigger (STRING_END, gun coordinates).
const TAG_AT := Vector2(-46, 20)
const TAG_FONT_SIZE := 11
const STRING_END := Vector2(42, 36)
## The contact shadow under its foot (gun coordinates), ink at SHADOW_ALPHA; picked up, it
## shrinks to SHADOW_LIFTED_SCALE and fades to SHADOW_LIFTED_ALPHA (of SHADOW_ALPHA).
const SHADOW_RECT := Rect2(6, 34, 72, 12)
const SHADOW_ALPHA := 0.45
const SHADOW_LIFTED_SCALE := 0.7
const SHADOW_LIFTED_ALPHA := 0.6
## The tag's own hard shadow.
const TAG_SHADOW_ALPHA := 0.35
## Hover and armed lifts, the armed tilt (radians, nozzle up) and the tween's length.
const HOVER_LIFT := 3.0
const ARMED_LIFT := 8.0
const ARMED_TILT := -0.16
const MOVE_SECONDS := 0.12
## With no relabel left: the gun's brightness, and its tag's text colour.
const SPENT_DIM := 0.72
const SPENT_TEXT := Palette.GREY_DARK
const CLICK_SOUND := "ui_click"

## True under reduced motion: the looks change at once.
var reduced_motion: Callable = Callable()

var _body: Control
var _sprite: TextureRect
var _halo: TextureRect
var _shadow: ContactShadow
var _tag: PanelContainer
var _tag_label: Label
var _string: Line2D
var _armed: bool = false
var _spent: bool = false
var _hovered: bool = false
var _tween: Tween


func _init() -> void:
	name = "PriceGun"
	position = RECT.position
	size = RECT.size
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = TIP
	_build_tag()
	_shadow = ContactShadow.new(SHADOW_ALPHA)
	_shadow.name = "Shadow"
	_shadow.position = SHADOW_RECT.position
	_shadow.size = SHADOW_RECT.size
	_shadow.pivot_offset = SHADOW_RECT.size / 2.0
	add_child(_shadow)
	_body = Control.new()
	_body.name = "Body"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.size = RECT.size
	# It tilts about the grip's foot, as a hand picks it up.
	_body.pivot_offset = Vector2(RECT.size.x - 12, RECT.size.y)
	add_child(_body)
	_halo = UiKit.sprite(TEXTURE)
	_halo.name = "Halo"
	var grow: float = 2.0 * ArtStyle.ART_SCALE
	_halo.position = -Vector2.ONE * grow
	_halo.size = RECT.size + Vector2.ONE * 2.0 * grow
	ArtStyle.set_look(_halo, ArtStyle.halo_material(1))
	_halo.visible = false
	_body.add_child(_halo)
	_sprite = UiKit.sprite(TEXTURE)
	_sprite.name = "Sprite"
	_sprite.size = RECT.size
	_body.add_child(_sprite)
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))


## Shows the gun with `left` relabels left this shift, picked up when `armed`.
func show_gun(left: int, armed: bool) -> void:
	_tag_label.text = LEFT_TEXT % left
	var spent: bool = left <= 0
	if spent != _spent:
		_spent = spent
		var dim: float = SPENT_DIM if spent else 1.0
		_sprite.self_modulate = Color(dim, dim, dim)
		_tag_label.add_theme_color_override("font_color", SPENT_TEXT if spent else Palette.INK)
		tooltip_text = TIP_SPENT if spent else TIP
	if armed != _armed:
		_armed = armed
		_halo.visible = armed
		_move()


## Whether it is picked up (armed).
func is_armed() -> bool:
	return _armed


## Whether it lies dimmed (no relabel left).
func is_spent() -> bool:
	return _spent


## The paper tag's label ("1 left").
func tag_label() -> Label:
	return _tag_label


## The paper tag on its string.
func tag() -> Control:
	return _tag


## The gun's art, lifted and tilted with it.
func body() -> Control:
	return _body


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	accept_event()
	Sfx.play_at(self, CLICK_SOUND)
	pressed.emit()


func _build_tag() -> void:
	_string = Line2D.new()
	_string.name = "String"
	_string.width = 2.0
	_string.default_color = Palette.CREAM_SHADE
	add_child(_string)
	_tag = PanelContainer.new()
	_tag.name = "LeftTag"
	_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Palette.PAPER
	box.border_color = Palette.INK
	box.set_border_width_all(2)
	box.set_corner_radius_all(2)
	box.content_margin_left = 5
	box.content_margin_right = 5
	box.content_margin_top = 1
	box.content_margin_bottom = 1
	box.shadow_color = Color(Palette.INK, TAG_SHADOW_ALPHA)
	box.shadow_offset = Vector2(2, 2)
	_tag.add_theme_stylebox_override("panel", box)
	_tag.position = TAG_AT
	add_child(_tag)
	_tag_label = UiKit.body_label("", TAG_FONT_SIZE, Palette.INK)
	_tag_label.add_theme_font_override("font", ArtStyle.bold_font(700))
	_tag.add_child(_tag_label)
	_tag.resized.connect(_tie_string)


## The string from the tag's top right corner to the gun's trigger.
func _tie_string() -> void:
	var knot: Vector2 = _tag.position + Vector2(_tag.size.x - 6, 2)
	_string.points = PackedVector2Array([knot, knot + Vector2(10, -8), STRING_END])


func _set_hover(on: bool) -> void:
	_hovered = on
	_move()


## Lifts (and, armed, tilts) the gun and shrinks and fades its shadow to match.
func _move() -> void:
	var lift: float = ARMED_LIFT if _armed else (HOVER_LIFT if _hovered else 0.0)
	var tilt: float = ARMED_TILT if _armed else 0.0
	var shadow: Vector2 = Vector2.ONE * (SHADOW_LIFTED_SCALE if _armed else 1.0)
	var fade: float = SHADOW_LIFTED_ALPHA if _armed else 1.0
	if _tween != null:
		_tween.kill()
		_tween = null
	var reduced: bool = reduced_motion.is_valid() and bool(reduced_motion.call())
	if reduced or not is_inside_tree():
		_body.position.y = -lift
		_body.rotation = tilt
		_shadow.scale = shadow
		_shadow.modulate.a = fade
		return
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_body, "position:y", -lift, MOVE_SECONDS)
	_tween.tween_property(_body, "rotation", tilt, MOVE_SECONDS)
	_tween.tween_property(_shadow, "scale", shadow, MOVE_SECONDS)
	_tween.tween_property(_shadow, "modulate:a", fade, MOVE_SECONDS)
