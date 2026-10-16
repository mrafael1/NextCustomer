class_name PayoutPlaque
extends Label
## An item's payout plaque (#55, decision D2a; #75): "pays €N" in the number font on a brass
## face FACE_HEIGHT tall, at least MIN_WIDTH wide and centred on `centre_x`. A value of €0 (or
## one wiped by a denied beat) shows the muted face, a cream-shade plate with a solid brass-dark
## edge and brass-dark text (#55's look, kept over v2's dashed one), not a size change. The
## plaque is the item's badge: the count-up punches it, so it stays a Label, and the face is a
## child drawn behind its text with the sharp-pixel material that the text must not get. The
## value comes from the caller (the ScoreResult); the plaque never scores.

const WORD := "pays"
const FACE_HEIGHT := 22.0
const MIN_WIDTH := 80.0
const FONT_SIZE := 18
## Room between the face's sides and the text, in canvas pixels.
const PADDING := 8.0
## The Label's height, the face centred in it: at least the text's height, so the Label never
## grows past it and its rest y stays fixed.
const HEIGHT := 26.0

## The x the plaque centres on, in its parent's coordinates.
var centre_x: float = 0.0
var _face: Panel
var _brass_face: StyleBoxTexture
var _muted_face: StyleBoxFlat
var _muted: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_override("font", ArtStyle.number_font())
	add_theme_font_size_override("font_size", FONT_SIZE)
	add_theme_constant_override("outline_size", 0)
	visible = false
	_brass_face = ArtStyle.frame_style(UiKit.PLAQUE_FRAME, UiKit.PLAQUE_MARGIN)
	_muted_face = StyleBoxFlat.new()
	_muted_face.bg_color = Palette.CREAM_SHADE
	_muted_face.border_color = Palette.BRASS_DARK
	_muted_face.set_border_width_all(ArtStyle.ART_SCALE)
	_face = Panel.new()
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.show_behind_parent = true
	ArtStyle.use_pixel_material(_face)
	add_child(_face)
	show_value(0, false)
	visible = false


## Shows "pays €`value`", on the muted face when `muted` (€0, or a value a denied beat wiped).
## Its y is left alone: the count-up's scan may be lifting it.
func show_value(value: int, muted: bool) -> void:
	text = text_for(value)
	visible = true
	_muted = muted
	var look: StyleBox = _brass_face
	if muted:
		look = _muted_face
	_face.add_theme_stylebox_override("panel", look)
	add_theme_color_override("font_color", Palette.BRASS_DARK if muted else ArtStyle.INK)
	var width: float = maxf(MIN_WIDTH, get_minimum_size().x + 2.0 * PADDING)
	size = Vector2(width, HEIGHT)
	position.x = centre_x - width / 2.0
	pivot_offset = size / 2.0
	_face.position = Vector2(0, (HEIGHT - FACE_HEIGHT) / 2.0)
	_face.size = Vector2(width, FACE_HEIGHT)


func is_muted() -> bool:
	return _muted


## The face behind the text (for tests and layout checks).
func face() -> Control:
	return _face


## The plaque's text for a value.
static func text_for(value: int) -> String:
	return "%s €%d" % [WORD, value]


## The Label's y that puts the face's top at `face_y`.
static func rest_y(face_y: float) -> float:
	return face_y - (HEIGHT - FACE_HEIGHT) / 2.0
