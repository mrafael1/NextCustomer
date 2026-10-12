class_name EffectMarker
extends PanelContainer
## A small chip that pins what an effect does onto a card (#60, decisions D8 and D9): its text
## ("×3") and, for a target marker, the card that causes it ("×3 · Multipack"), so it never
## relies on colour alone. The count-up parks one dimmed on each card an armed effect will land
## on and a pip (with a token icon) on the arming card; the planning screen can reuse it to show
## effects on cards before checkout.
##
## It only shows and follows: attach() pins it to a corner of a control, and while `following`
## it keeps to that corner every frame (it hides while the control is hidden, and when the
## control is gone). Whoever owns it animates it (flights, fades) and frees it.

enum Pin { TOP_RIGHT, TOP_LEFT }

## A dimmed marker's alpha: an effect still to come.
const DIMMED_ALPHA := 0.5
const FONT_SIZE := 12
const ICON_SIZE := 10.0
## How far the chip sticks out past the corner's side, and down from the corner's top.
const OUTSIDE := Vector2(6, -2)
const BACKGROUND := Color("fbf7ee")
const SPENT_BACKGROUND := Color("c9c1ae")

## The control whose corner it is pinned to, or null.
var target: Control
var pin: Pin = Pin.TOP_RIGHT
## Pixels below the corner, to stack several markers on one control.
var stack_offset: float = 0.0
## Keeps to the target's corner every frame (off while its owner flies it somewhere).
var following: bool = false
var _label: Label
var _icon: Panel
var _style: StyleBoxFlat
var _icon_style: StyleBoxFlat
var _spent: bool = false


## `text` is what it shows; `with_icon` adds the round token icon before it (the arming card's
## pip).
func _init(text: String = "", with_icon: bool = false) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.bg_color = BACKGROUND
	_style.border_color = Palette.TOMATO
	_style.set_border_width_all(2)
	_style.set_corner_radius_all(6)
	_style.content_margin_left = 5
	_style.content_margin_right = 5
	_style.content_margin_top = 1
	_style.content_margin_bottom = 1
	add_theme_stylebox_override("panel", _style)
	var row: HBoxContainer = HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 3)
	add_child(row)
	_icon = Panel.new()
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon_style = StyleBoxFlat.new()
	_icon_style.bg_color = Palette.TOMATO
	_icon_style.set_corner_radius_all(int(ICON_SIZE / 2.0))
	_icon.add_theme_stylebox_override("panel", _icon_style)
	_icon.visible = with_icon
	row.add_child(_icon)
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.text = text
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", Palette.INK)
	row.add_child(_label)


## Pins it to `at` of `to` (`offset_y` pixels lower, to stack markers) and starts following.
func attach(to: Control, at: Pin = Pin.TOP_RIGHT, offset_y: float = 0.0) -> void:
	target = to
	pin = at
	stack_offset = offset_y
	following = true
	_follow()


## Its text, as shown.
func shown_text() -> String:
	return _label.text


## Whether it has the token icon (a pip).
func has_icon() -> bool:
	return _icon.visible


## Dimmed (DIMMED_ALPHA) for an effect still to come; full for one landing now.
func set_dimmed(dimmed: bool) -> void:
	modulate.a = DIMMED_ALPHA if dimmed else 1.0


## Greyed for good: the effect fizzled (its WASTED step).
func set_spent(spent: bool) -> void:
	_spent = spent
	_style.bg_color = SPENT_BACKGROUND if spent else BACKGROUND
	_style.border_color = Palette.MUTED_INK if spent else Palette.TOMATO
	_icon_style.bg_color = Palette.MUTED_INK if spent else Palette.TOMATO
	_label.add_theme_color_override("font_color", Palette.MUTED_INK if spent else Palette.INK)


func is_spent() -> bool:
	return _spent


## Where it sits when pinned, in global coordinates (its top-left), for the current size.
func parked_position() -> Vector2:
	if not _has_target():
		return global_position
	var rect: Rect2 = target.get_global_rect()
	var chip: Vector2 = get_combined_minimum_size()
	var y: float = rect.position.y + OUTSIDE.y + stack_offset
	if pin == Pin.TOP_LEFT:
		return Vector2(rect.position.x - OUTSIDE.x, y)
	return Vector2(rect.end.x + OUTSIDE.x - chip.x, y)


func _enter_tree() -> void:
	# Following again just before drawing, after this frame's tweens moved the target, keeps the
	# chip on a lifting or shaking card instead of a frame behind it.
	RenderingServer.frame_pre_draw.connect(_on_frame_pre_draw)


func _exit_tree() -> void:
	RenderingServer.frame_pre_draw.disconnect(_on_frame_pre_draw)


func _process(_delta: float) -> void:
	if following:
		_follow()


func _on_frame_pre_draw() -> void:
	if following:
		_follow()


func _follow() -> void:
	if not _has_target():
		visible = false
		return
	visible = target.is_visible_in_tree()
	size = get_combined_minimum_size()
	# The layout position: a landing scales the marker on its centre.
	_move_to(parked_position())


## Moves the layout position (not the scaled one) so the top-left sits at `point` (global).
func _move_to(point: Vector2) -> void:
	var parent: CanvasItem = get_parent() as CanvasItem
	position = parent.get_global_transform().affine_inverse() * point if parent != null else point


func _has_target() -> bool:
	return target != null and is_instance_valid(target) and target.is_inside_tree()
