class_name MenuPlate
extends FramedButton
## One entry of the title's menu (#56, mock-up title_premium_directions.html, direction C+): a
## cream shelf label (frames/menu_plate: a teal aisle stripe on its left, a brass ledge under it)
## with its caption in ink, or the primary plate (the tomato button.png) with a large paper
## caption and a sub-line under it in the number font (the run's shift, SHIFT 5/12).
##
## The marker on it lights it: the plate moves HOT_SHIFT px right onto its lit frame
## (menu_plate_lit, button_lit) and a tomato price-gun tick (icons/tick_marker) shows left of it.
## The menu or popup owning it sets `marked`, from the mouse (it marks the plate the mouse enters)
## and from the keys, so only `marked` lights it: a plate the keys left stays dark under a
## resting mouse, and the mouse and the keys never light two plates. Like every FramedButton it
## never takes focus, so Space can't press it behind the menu's back. Pressing sinks it one ledge
## step; a disabled plate shows its off frame and keeps the arrow cursor. Nothing here moves on
## its own, so reduced motion needs nothing from it: every change is one step, on input.
## The REWARDS plate carries a coin and the coin count at its right end (show_coins).

## PLATE: a cream shelf label; PRIMARY: the tomato plate with a sub-line (CONTINUE, START RUN).
enum Kind { PLATE, PRIMARY }

## The shelf-label frames (normal, lit, off): 9-slices with PLATE_MARGIN art px margins.
const PLATE_FRAME := preload("res://art/frames/menu_plate.png")
const PLATE_LIT_FRAME := preload("res://art/frames/menu_plate_lit.png")
const PLATE_OFF_FRAME := preload("res://art/frames/menu_plate_off.png")
const PLATE_MARGIN := 4
## The primary plate's frames (normal, lit): button.png's 9-slice (FRAME_MARGIN).
const PRIMARY_LIT_FRAME := preload("res://art/frames/button_lit.png")
const TICK := preload("res://art/icons/tick_marker.png")
const COIN := preload("res://art/icons/coin.png")
## Each variant's face size by default, in canvas px: a 120x21 art shelf label (an 18-row face
## and its 3-row ledge), a 152x40 art primary plate (room around its caption and sub-line).
const PLATE_SIZE := Vector2(240, 42)
const PRIMARY_SIZE := Vector2(304, 80)
## How far a lit plate moves right, in canvas px (2 art px).
const HOT_SHIFT := 4.0
## How far a pressed plate sinks, by variant, in canvas px: one art px for a shelf label, the
## primary's 2-pixel ledge.
const PLATE_SINK := 2.0
const PRIMARY_SINK := FramedButton.PRESS_DEPTH
## The captions: hard pixel words (UiKit.pixel_label), one font pixel 2 canvas px on a shelf
## label and 4 on the primary plate; the sub-line and the coin count in the number font.
const PLATE_TEXT_SCALE := 2
const PRIMARY_TEXT_SCALE := 4
const SUB_FONT_SIZE := 14
const COUNT_FONT_SIZE := 16
## Where the captions sit on the face, in canvas px from its top left: a shelf label's caption
## right of the stripe and centred on the face above its bottom row and ledge; the primary's
## caption in its top band, the sub-line under it.
const PLATE_CAPTION_LEFT := 18.0
const PLATE_FACE_TOP := 2.0
const PLATE_FACE_BOTTOM := 8.0
const PRIMARY_CAPTION_RECT := Rect2(24, 6, 0, 40)
## A shelf label's teal stripe ends this far into the face (its outline and 3 art px).
const STRIPE_RIGHT := 8.0
const SUB_RECT := Rect2(26, 50, 0, 14)
## The coin count: the coin (12x12 art at 2x), COUNT_GAP px before the number, the pair
## COUNT_RIGHT px inside the face's right edge.
const COIN_SIZE := Vector2(24, 24)
const COUNT_GAP := 4.0
const COUNT_RIGHT := 12.0
## The tick (5x7 art at 2x): its left edge TICK_LEFT px left of the plate (at rest), centred on
## the face's content (snapped to the 2 px grid).
const TICK_SIZE := Vector2(10, 14)
const TICK_LEFT := 22.0

## The keyboard marker is on this plate (the menu sets it): it looks lit, as under the mouse.
var marked: bool = false:
	set(value):
		marked = value
		queue_redraw()
## The primary plate's sub-line (empty: none). A shelf label has none.
var sub_line: String:
	get:
		return _sub_label.text
	set(value):
		_sub_label.text = value
		_sub_label.visible = not value.is_empty()
		accessibility_description = value

var _kind: Kind
var _face_size: Vector2
## The variant's frames as styles: normal, lit and (shelf label only) off.
var _styles: Array[StyleBoxTexture] = []
## The face's content (captions and coin count): it moves with the face.
var _content: Control
var _sub_label: Label
var _coin: TextureRect
var _count_label: Label
var _tick: TextureRect


## A plate captioned `caption_text`, its face `plate_size` canvas px (the variant's default when
## zero). The control is HOT_SHIFT wider and its sink deeper, so a lit or pressed face stays
## inside it.
func _init(
	caption_text: String = "", plate_kind: Kind = Kind.PLATE, plate_size: Vector2 = Vector2.ZERO
) -> void:
	var primary: bool = plate_kind == Kind.PRIMARY
	var default_size: Vector2 = PRIMARY_SIZE if primary else PLATE_SIZE
	var shown_size: Vector2 = default_size if plate_size == Vector2.ZERO else plate_size
	var sink: float = PRIMARY_SINK if primary else PLATE_SINK
	super(
		caption_text,
		ArtStyle.PIXEL_TEXT_SIZE,
		UiKit.BUTTON_FRAME if primary else PLATE_FRAME,
		shown_size + Vector2(HOT_SHIFT, sink)
	)
	_kind = plate_kind
	_face_size = shown_size
	if primary:
		_styles = [
			ArtStyle.frame_style(UiKit.BUTTON_FRAME, FRAME_MARGIN),
			ArtStyle.frame_style(PRIMARY_LIT_FRAME, FRAME_MARGIN),
		]
	else:
		_styles = [
			ArtStyle.frame_style(PLATE_FRAME, PLATE_MARGIN),
			ArtStyle.frame_style(PLATE_LIT_FRAME, PLATE_MARGIN),
			ArtStyle.frame_style(PLATE_OFF_FRAME, PLATE_MARGIN),
		]
	_build_content(primary)
	_tick = UiKit.sprite(TICK)
	_tick.size = TICK_SIZE
	_tick.position = Vector2(-TICK_LEFT, _tick_top())
	_tick.visible = false
	add_child(_tick, false, Node.INTERNAL_MODE_FRONT)
	_show_plate(DRAW_NORMAL)


## Button redraws on every state change (hover, press, disabled); `marked` asks for one too.
func _draw() -> void:
	_show_plate(get_draw_mode())


func kind() -> Kind:
	return _kind


## The face's size in canvas px (the control is HOT_SHIFT wider and its sink taller).
func face_size() -> Vector2:
	return _face_size


## The plate looks lit: marked, and not disabled.
func is_lit() -> bool:
	return _lit(get_draw_mode())


## Shows a coin and `count` (in the number font) at the face's right end; a negative count
## hides them.
func show_coins(count: int) -> void:
	_coin.visible = count >= 0
	_count_label.visible = count >= 0
	_count_label.text = str(maxi(count, 0))
	_place_count()


## Swaps the plate's frames (normal, lit; 9-slices with FRAME_MARGIN art px margins) for
## `frames`: the TOY MACHINES' FIGURINE SHELF is a primary plate in teal (v0.78).
func use_frames(frames: Array[Texture2D]) -> void:
	_styles = []
	for frame: Texture2D in frames:
		_styles.append(ArtStyle.frame_style(frame, FRAME_MARGIN))
	_show_plate(get_draw_mode())


## Centres the caption on the face (right of a shelf label's stripe, above the ledge), its font
## pixels `text_scale` canvas px (PLATE_TEXT_SCALE or PRIMARY_TEXT_SCALE; 0 keeps the variant's):
## a popup's keys (ABANDON, KEEP) are centred, where the menu's entries start at the left.
func centre_caption(text_scale: int = 0) -> void:
	var caption_node: Label = caption_label()
	if text_scale > 0:
		UiKit.use_pixel_text(caption_node, text_scale)
	caption_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var left: float = STRIPE_RIGHT if _kind == Kind.PLATE else 0.0
	var bottom: float = PLATE_FACE_BOTTOM if _kind == Kind.PLATE else PRIMARY_SINK + 4.0
	_put(
		caption_node,
		Rect2(left, PLATE_FACE_TOP, _face_size.x - left, _face_size.y - PLATE_FACE_TOP - bottom)
	)


func sub_label() -> Label:
	return _sub_label


func count_label() -> Label:
	return _count_label


func coin_icon() -> TextureRect:
	return _coin


func tick() -> TextureRect:
	return _tick


## The caption, sub-line and coin count on a content layer that moves with the face; the
## caption is FramedButton's label, restyled as hard pixel words (ink on cream, paper on tomato).
func _build_content(primary: bool) -> void:
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_content, false, Node.INTERNAL_MODE_FRONT)
	var caption_node: Label = caption_label()
	remove_child(caption_node)
	_content.add_child(caption_node)
	UiKit.use_pixel_text(caption_node, PRIMARY_TEXT_SCALE if primary else PLATE_TEXT_SCALE)
	caption_node.add_theme_color_override("font_color", Palette.PAPER if primary else Palette.INK)
	caption_node.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var caption_rect: Rect2 = PRIMARY_CAPTION_RECT
	if not primary:
		caption_rect = Rect2(
			PLATE_CAPTION_LEFT, PLATE_FACE_TOP, 0, _face_size.y - PLATE_FACE_TOP - PLATE_FACE_BOTTOM
		)
	_put(caption_node, caption_rect)
	_sub_label = UiKit.number_label("", SUB_FONT_SIZE, false)
	_sub_label.add_theme_constant_override("outline_size", 0)
	_sub_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sub_label.visible = false
	_content.add_child(_sub_label)
	_put(_sub_label, SUB_RECT)
	_coin = UiKit.sprite(COIN)
	_coin.size = COIN_SIZE
	_coin.visible = false
	_content.add_child(_coin)
	_count_label = UiKit.number_label("", COUNT_FONT_SIZE, false)
	_count_label.add_theme_constant_override("outline_size", 0)
	_count_label.add_theme_color_override("font_color", Palette.MUSTARD_DARK)
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.visible = false
	_content.add_child(_count_label)


## Applies the look of `mode` (a BaseButton.DrawMode) and `marked`.
func _show_plate(mode: DrawMode) -> void:
	var off: bool = mode == DRAW_DISABLED
	var down: bool = mode == DRAW_PRESSED or mode == DRAW_HOVER_PRESSED
	var lit: bool = _lit(mode)
	var sink_depth: float = PRIMARY_SINK if _kind == Kind.PRIMARY else PLATE_SINK
	var shift: float = HOT_SHIFT if lit else 0.0
	var sink: float = sink_depth if down else 0.0
	var face_panel: PanelContainer = face()
	for layer: Control in [face_panel, _content] as Array[Control]:
		layer.offset_left = shift
		layer.offset_right = shift - HOT_SHIFT
		layer.offset_top = sink
		layer.offset_bottom = sink - sink_depth
	var style: int = 1 if lit else 0
	if off and _styles.size() > 2:
		style = 2
	face_panel.add_theme_stylebox_override("panel", _styles[style])
	face_panel.modulate = Color.WHITE
	modulate = Color.WHITE
	_sub_label.add_theme_color_override("font_color", Palette.PAPER if lit else Palette.TOMATO_PALE)
	_tick.visible = lit
	mouse_default_cursor_shape = CURSOR_ARROW if off else CURSOR_POINTING_HAND


func _lit(mode: DrawMode) -> bool:
	return marked and mode != DRAW_DISABLED


## The tick's top: centred on the face's content (between its top row and its bottom rows and
## ledge), on the 2 px grid.
func _tick_top() -> float:
	var bottom: float = (
		_face_size.y - PLATE_FACE_BOTTOM if _kind == Kind.PLATE else _face_size.y - 6.0
	)
	var centre: float = (PLATE_FACE_TOP + bottom) / 2.0
	return 2.0 * roundf((centre - TICK_SIZE.y / 2.0) / 2.0)


## The coin and the count, right-aligned COUNT_RIGHT inside the face and centred on its content.
func _place_count() -> void:
	var text_size: Vector2 = _count_label.get_minimum_size()
	var content_height: float = _face_size.y - PLATE_FACE_TOP - PLATE_FACE_BOTTOM
	var right: float = _face_size.x - COUNT_RIGHT
	_put(_count_label, Rect2(right - text_size.x, PLATE_FACE_TOP, text_size.x, content_height))
	var coin_left: float = right - text_size.x - COUNT_GAP - COIN_SIZE.x
	var coin_top: float = (
		2.0 * roundf((PLATE_FACE_TOP + (content_height - COIN_SIZE.y) / 2.0) / 2.0)
	)
	_coin.position = Vector2(coin_left, coin_top)


## Puts `label` at `rect` (in face coordinates; a pixel caption's size in its font px); a zero
## width runs to the face's right edge.
func _put(label: Label, rect: Rect2) -> void:
	var width: float = rect.size.x if rect.size.x > 0.0 else _face_size.x - rect.position.x
	if label.scale.x > 1.0:
		UiKit.place_pixel_label(label, Rect2(rect.position, Vector2(width, rect.size.y)), true)
		return
	label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	label.position = rect.position
	label.size = Vector2(width, rect.size.y)
