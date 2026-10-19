class_name EffectSticker
extends Control
## One planning sticker on a belt item (#71, mock-up h1, H1_BUILD_SPEC.md section 4.1): an effect
## the item receives, slapped on it. ADD is a cream price-gun label ("+3"), MULTIPLY a gold
## starburst ("×3"), COPY a teal label ("=€6"), FIZZLE a grey "pfff" label and MORE the grey
## "…+N" label the earliest stickers of a too-tall stack fold into. The frame (and its shadow,
## ink at SHADOW_ALPHA at SHADOW_OFFSET) turns by `tilt_deg` about its centre on the texel grid
## (the sharp-pixel material keeps the texels hard); the text stays upright and centred. The
## giver's badge (GiverBadge) hangs off its left edge. Drained (another item hovered, or on a
## denied item) the frame, shadow and badge grey (ArtStyle.Grey.DRAINED) and the text steps back,
## all opaque: a see-through sticker would ghost over the art. A new sticker is slapped on (slap):
## it squashes and springs back about its bottom centre, its own rect unchanged. Decor only: it
## takes no clicks, and every number on it is a step's (StickerSpec).

const LABEL_HEIGHT := 28.0
## ADD, COPY and MORE are LABEL_WIDTHS[0] wide for up to 2 characters, [1] for 3, else their
## text's width plus LABEL_PADDING (on the 2 px grid).
const LABEL_WIDTHS: Array[float] = [46.0, 54.0]
const LABEL_PADDING := 16.0
const FIZZLE_SIZE := Vector2(60, 28)
const BURST_SIZE := Vector2(62, 34)
## The label 9-slices' margin, in art pixels.
const FRAME_MARGIN := 3
## Text sizes: the labels', the burst's (BURST_SMALL_SIZE from BURST_SMALL_CHARS characters) and
## the grey labels' (with FIZZLE_PADDING more on the left).
const LABEL_TEXT_SIZE := 21
const BURST_TEXT_SIZE := 22
const BURST_SMALL_SIZE := 18
const BURST_SMALL_CHARS := 4
const GREY_TEXT_SIZE := 15
const FIZZLE_PADDING := 6.0
## The badge hangs this far left of a burst, or of a label.
const BURST_BADGE_X := -8.0
const LABEL_BADGE_X := -14.0
const SHADOW_OFFSET := Vector2(2, 2)
const SHADOW_ALPHA := 0.42
## The slap's frames (scales), each held for the frame time slap() is given; it ends at 1.
const SLAP_SCALES: Array[Vector2] = [Vector2(1.2, 0.8), Vector2(0.92, 1.08)]

const LABEL_FRAME := preload("res://art/effects/sticker_label.png")
const GREY_FRAME := preload("res://art/effects/sticker_label_grey.png")
const TEAL_FRAME := preload("res://art/effects/sticker_label_teal.png")
const BURST := preload("res://art/effects/sticker_burst.png")

var _spec: StickerSpec
## Holds every part, so the slap scales them about the sticker's bottom centre.
var _inner: Control
var _frame: Control
var _shadow: Control
var _label: Label
var _badge: GiverBadge
var _drained: bool = false
var _slap_tween: Tween


## The sticker of `sticker_spec`, its frame turned `tilt_deg` degrees.
func _init(sticker_spec: StickerSpec, tilt_deg: float = 0.0) -> void:
	_spec = sticker_spec
	name = "EffectSticker"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = size_for(sticker_spec)
	custom_minimum_size = size
	_inner = Control.new()
	_inner.name = "Slap"
	_inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_inner.size = size
	_inner.pivot_offset = Vector2(size.x / 2.0, size.y)
	add_child(_inner)
	_shadow = _make_frame()
	_shadow.name = "Shadow"
	_shadow.position = SHADOW_OFFSET
	_shadow.self_modulate = Color(Palette.INK, SHADOW_ALPHA)
	_inner.add_child(_shadow)
	_frame = _make_frame()
	_frame.name = "Frame"
	_inner.add_child(_frame)
	for part: Control in [_shadow, _frame]:
		part.pivot_offset = size / 2.0
		part.rotation_degrees = tilt_deg
	_label = UiKit.number_label(_spec.text, _text_size(_spec), false)
	_label.name = "Text"
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var left: float = FIZZLE_PADDING if _grey() else 0.0
	_label.position = Vector2(left, 0)
	_label.size = Vector2(size.x - left, size.y)
	_inner.add_child(_label)
	if _spec.badge != GiverBadge.Kind.NONE:
		_badge = GiverBadge.new(_spec.badge, _spec.badge_text)
		var badge_x: float = (
			BURST_BADGE_X if _spec.kind == StickerSpec.Kind.MULTIPLY else LABEL_BADGE_X
		)
		var badge_y: float = snappedf((size.y - _badge.size.y) / 2.0, ArtStyle.ART_SCALE)
		_badge.position = Vector2(badge_x, badge_y)
		_inner.add_child(_badge)
	_colour_text()


## A sticker's size for `sticker_spec` (section 4.1).
static func size_for(sticker_spec: StickerSpec) -> Vector2:
	match sticker_spec.kind:
		StickerSpec.Kind.MULTIPLY:
			return BURST_SIZE
		StickerSpec.Kind.FIZZLE:
			return FIZZLE_SIZE
	var characters: int = sticker_spec.text.length()
	if characters <= 2:
		return Vector2(LABEL_WIDTHS[0], LABEL_HEIGHT)
	if characters == 3:
		return Vector2(LABEL_WIDTHS[1], LABEL_HEIGHT)
	var font: Font = ArtStyle.number_font()
	var text_width: float = (
		font
		. get_string_size(
			sticker_spec.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _text_size(sticker_spec)
		)
		. x
	)
	return Vector2(snappedf(text_width + LABEL_PADDING, ArtStyle.ART_SCALE), LABEL_HEIGHT)


## How far the badge reaches left of the sticker's left edge (0 without a badge).
static func badge_overhang(sticker_spec: StickerSpec) -> float:
	if sticker_spec.badge == GiverBadge.Kind.NONE:
		return 0.0
	return -(BURST_BADGE_X if sticker_spec.kind == StickerSpec.Kind.MULTIPLY else LABEL_BADGE_X)


func spec() -> StickerSpec:
	return _spec


## The giver's badge, or null for the item's own rule.
func badge() -> GiverBadge:
	return _badge


## The text shown.
func text() -> String:
	return _label.text


## Greys the frame, shadow and badge and steps the text back (`drained`), or puts the look back.
func set_drained(drained: bool) -> void:
	_drained = drained
	var look: ShaderMaterial = ArtStyle.grey_material(ArtStyle.Grey.DRAINED) if drained else null
	for part: Control in [_shadow, _frame]:
		ArtStyle.set_look(part, look)
	if _badge != null:
		_badge.set_drained(drained)
	_colour_text()


func is_drained() -> bool:
	return _drained


## Slaps the sticker on: SLAP_SCALES, each for `frame_s` seconds, then back to 1, about its bottom
## centre. Nothing under `reduced_motion` (or with no frame time); it never loops.
func slap(reduced_motion: bool, frame_s: float = 0.0) -> void:
	if _slap_tween != null:
		_slap_tween.kill()
		_slap_tween = null
	_inner.scale = Vector2.ONE
	if reduced_motion or frame_s <= 0.0 or not is_inside_tree():
		return
	_slap_tween = create_tween()
	for frame: Vector2 in SLAP_SCALES:
		_slap_tween.tween_callback(_inner.set_scale.bind(frame))
		_slap_tween.tween_interval(frame_s)
	_slap_tween.tween_callback(_inner.set_scale.bind(Vector2.ONE))


## Whether the slap is playing (for tests).
func is_slapping() -> bool:
	return _slap_tween != null and _slap_tween.is_running()


## Where the text's glyphs are drawn, in the sticker's coordinates.
func text_rect() -> Rect2:
	var font: Font = _label.get_theme_font("font")
	var font_size: int = _label.get_theme_font_size("font_size")
	var drawn: Vector2 = font.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var centre: Vector2 = _label.position + _label.size / 2.0
	return Rect2(centre - drawn / 2.0, drawn)


## The frame (or the shadow, its copy): the burst, or the kind's label 9-slice.
func _make_frame() -> Control:
	var part: Control
	if _spec.kind == StickerSpec.Kind.MULTIPLY:
		part = UiKit.sprite(BURST)
	else:
		var textures: Dictionary[StickerSpec.Kind, Texture2D] = {
			StickerSpec.Kind.COPY: TEAL_FRAME,
			StickerSpec.Kind.FIZZLE: GREY_FRAME,
			StickerSpec.Kind.MORE: GREY_FRAME,
		}
		var panel: Panel = Panel.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override(
			"panel", ArtStyle.frame_style(textures.get(_spec.kind, LABEL_FRAME), FRAME_MARGIN)
		)
		ArtStyle.use_pixel_material(panel)
		part = panel
	part.size = size
	return part


func _grey() -> bool:
	return _spec.kind == StickerSpec.Kind.FIZZLE or _spec.kind == StickerSpec.Kind.MORE


func _colour_text() -> void:
	var colour: Color = Palette.INK_LIGHT if _grey() else Palette.INK
	_label.add_theme_color_override("font_color", Palette.GREY_DARK if _drained else colour)


static func _text_size(sticker_spec: StickerSpec) -> int:
	match sticker_spec.kind:
		StickerSpec.Kind.MULTIPLY:
			if sticker_spec.text.length() >= BURST_SMALL_CHARS:
				return BURST_SMALL_SIZE
			return BURST_TEXT_SIZE
		StickerSpec.Kind.FIZZLE, StickerSpec.Kind.MORE:
			return GREY_TEXT_SIZE
	return LABEL_TEXT_SIZE
