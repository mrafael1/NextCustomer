class_name EffectSticker
extends Control
## One planning sticker on a belt item (#71, mock-up h1, H1_BUILD_SPEC.md section 4.1): an effect
## the item receives, slapped on it. ADD is a cream price-gun label ("+3"), MULTIPLY a gold
## starburst ("×3"), COPY a teal label ("=€6"), FIZZLE a grey "WASTED" label and MORE the fold
## chip the earliest stickers of a stack fold into from its 4th (#105 piece 3, mock-up readability
## v3 fold A): a grey label turned FOLD_TILT_DEG with a card-fan mark and the count ("+3") in ink.
## The chip pops in and punches as more fold in (fold_punch); in the count it counts down as each
## folded sticker's step lands and shrinks away after the last (fire). A fanned-out copy
## (StackFan) wears its order number on its top edge (set_number). The frame (and its shadow,
## ink at SHADOW_ALPHA at SHADOW_OFFSET) turns by `tilt_deg` about its centre on the texel grid
## (the sharp-pixel material keeps the texels hard); the text stays upright and centred. The
## giver's badge (GiverBadge) hangs off its left edge. Drained (another item hovered, or on a
## denied item) the frame, shadow and badge grey (ArtStyle.Grey.DRAINED) and the text steps back,
## all opaque: a see-through sticker would ghost over the art. A new sticker is slapped on (slap):
## it squashes and springs back about its bottom centre, its own rect unchanged. In the count
## (#86 v6) it fires as its step lands (fire: a punch, a flash, then a small green check settles on
## its top right corner) and a giver's sparks charge it (charge: a lighter punch). Decor only: it
## takes no clicks, and every number on it is a step's (StickerSpec).

const LABEL_HEIGHT := 32.0
## ADD, COPY and MORE are LABEL_WIDTHS[0] wide for up to 2 characters, [1] for 3, else their
## text's width plus LABEL_PADDING (on the 2 px grid).
const LABEL_WIDTHS: Array[float] = [52.0, 62.0]
const LABEL_PADDING := 22.0
## Readability v3's WASTED: at least 92 px wide, its text plus 6 px and 18 px of padding.
const FIZZLE_SIZE := Vector2(92, 32)
const FIZZLE_TEXT_PADDING := 18.0
const BURST_SIZE := Vector2(76, 42)
## The label 9-slices' margin, in art pixels.
const FRAME_MARGIN := 4
## Text sizes: the labels', the burst's (BURST_SMALL_SIZE from BURST_SMALL_CHARS characters) and
## the grey labels' (with FIZZLE_PADDING more on the left).
const LABEL_TEXT_SIZE := 24
const BURST_TEXT_SIZE := 26
const BURST_SMALL_SIZE := 22
const BURST_SMALL_CHARS := 4
const GREY_TEXT_SIZE := 17
const FIZZLE_PADDING := 6.0
## WASTED's tomato underline, with a darker lower edge, above the label's shaded lip.
const FIZZLE_UNDERLINE_Y := 22.0
const FIZZLE_UNDERLINE_HEIGHT := 4.0
## The fold chip (MORE): FOLD_SIZE, or wider for its text (from FOLD_TEXT_X, plus FOLD_PADDING),
## its frame turned FOLD_TILT_DEG, the mark at FOLD_MARK_AT and the count in ink at FOLD_TEXT_SIZE.
const FOLD_SIZE := Vector2(64, 30)
const FOLD_TEXT_X := 38.0
const FOLD_PADDING := 8.0
const FOLD_TEXT_SIZE := 17
const FOLD_TILT_DEG := -3.0
const FOLD_MARK_AT := Vector2(6, 4)
## The chip's motion: it pops in from FOLD_POP_FROM over FOLD_POP_S, punches to 1 + FOLD_PUNCH
## easing back over FOLD_PUNCH_S, and shrinks to FOLD_POP_FROM, fading, over FOLD_POP_S once its
## count is down to 0 in the count.
const FOLD_POP_FROM := 0.3
const FOLD_POP_S := 0.12
const FOLD_PUNCH := 0.3
const FOLD_PUNCH_S := 0.22
## A fanned sticker's order number: a NUMBER_SIZE ink square in a NUMBER_RING paper ring, the
## number in paper at NUMBER_TEXT_SIZE, its top-left at NUMBER_AT: attached to the sticker's
## top edge, clear of the giver badge on its left.
const NUMBER_AT := Vector2(10, -10)
const NUMBER_SIZE := Vector2(16, 16)
const NUMBER_RING := 2.0
const NUMBER_TEXT_SIZE := 12
const NUMBER_NAME := &"Number"
## The badge hangs this far left of a burst, or of a label.
const BURST_BADGE_X := -14.0
const LABEL_BADGE_X := -20.0
const SHADOW_OFFSET := Vector2(2, 2)
const SHADOW_ALPHA := 0.42
## The slap's frames (scales), each held for the frame time slap() is given; it ends at 1.
const SLAP_SCALES: Array[Vector2] = [Vector2(1.2, 0.8), Vector2(0.92, 1.08)]
## The count's fire (#86 v6, mock-up count_up_86_v6_scan): a punch to 1 + FIRE_PUNCH easing back
## over FIRE_S, turned FIRE_TURN_DEG and back, brightened by FLASH for FLASH_S, then the check
## settles on the corner (from CHECK_POP over CHECK_SETTLE_S) at CHECK_AT. A giver's sparks
## charge it (charge): a lighter punch, CHARGE_PUNCH over FIRE_S, with the flash.
const FIRE_PUNCH := 0.55
const FIRE_S := 0.3
const FIRE_TURN_DEG := -6.0
const FLASH := 1.6
const FLASH_S := 0.12
const CHECK_AT := 0.34
const CHECK_POP := 1.6
const CHECK_SETTLE_S := 0.1
const CHARGE_PUNCH := 0.35
## The check's cells (art pixels, its top left at the origin), drawn in Palette.GOOD over a
## one-pixel ink outline, its top right on the sticker's top right corner, CHECK_OVERHANG out.
const CHECK_CELLS: Array[Vector2i] = [
	Vector2i(1, 3),
	Vector2i(1, 4),
	Vector2i(2, 4),
	Vector2i(2, 5),
	Vector2i(3, 5),
	Vector2i(3, 6),
	Vector2i(4, 4),
	Vector2i(4, 5),
	Vector2i(5, 3),
	Vector2i(5, 4),
	Vector2i(6, 2),
	Vector2i(6, 3),
	Vector2i(7, 1),
	Vector2i(7, 2),
]
const CHECK_SIZE := Vector2(18, 16)
const CHECK_OVERHANG := Vector2(6, 6)
const CHECK_NAME := &"Check"

const LABEL_FRAME := preload("res://art/effects/sticker_label_polished.png")
const GREY_FRAME := preload("res://art/effects/sticker_label_grey_polished.png")
const WASTED_FRAME := preload("res://art/effects/sticker_label_wasted_polished.png")
const TEAL_FRAME := preload("res://art/effects/sticker_label_teal_polished.png")
const BURST := preload("res://art/effects/sticker_burst_polished.png")
const FOLD_MARK := preload("res://art/effects/fold_mark.png")

var _spec: StickerSpec
## Holds every part, so the slap scales them about the sticker's bottom centre.
var _inner: Control
var _frame: Control
var _shadow: Control
var _label: Label
var _underline: Control
var _badge: GiverBadge
var _drained: bool = false
var _slap_tween: Tween
## The count's check (fire), hidden until the sticker fires.
var _check: Control
var _fired: bool = false
var _fire_tween: Tween
## The fold chip's mark, and how many of its folded stickers have not fired in the count.
var _mark: TextureRect
var _unfired: int = 0
## A fanned copy's order number (set_number), or null.
var _number: Control


## The sticker of `sticker_spec`, its frame turned `tilt_deg` degrees.
func _init(sticker_spec: StickerSpec, tilt_deg: float = 0.0) -> void:
	_spec = sticker_spec
	_unfired = sticker_spec.folds
	if _spec.kind == StickerSpec.Kind.MORE:
		tilt_deg = FOLD_TILT_DEG
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
	var left: float = FIZZLE_PADDING if _spec.kind == StickerSpec.Kind.FIZZLE else 0.0
	_label.position = Vector2(left, 0)
	_label.size = Vector2(size.x - left, size.y)
	if _spec.kind != StickerSpec.Kind.MULTIPLY:
		# Centre the digits on the face above the label's shaded bottom lip.
		_label.size.y = 26.0
	if _spec.kind != StickerSpec.Kind.MORE:
		_label.add_theme_color_override(
			"font_shadow_color",
			Palette.MUSTARD if _spec.kind == StickerSpec.Kind.MULTIPLY else Palette.CREAM_SHADE
		)
		_label.add_theme_constant_override("shadow_offset_x", 0)
		_label.add_theme_constant_override("shadow_offset_y", ArtStyle.ART_SCALE)
	if _spec.kind == StickerSpec.Kind.MORE:
		_mark = UiKit.sprite(FOLD_MARK)
		_mark.name = "FoldMark"
		_mark.position = FOLD_MARK_AT
		_mark.size = FOLD_MARK.get_size() * ArtStyle.ART_SCALE
		_inner.add_child(_mark)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_label.position = Vector2(FOLD_TEXT_X, 0)
		_label.size = Vector2(size.x - FOLD_TEXT_X, size.y - ArtStyle.ART_SCALE)
	_inner.add_child(_label)
	if _spec.kind == StickerSpec.Kind.FIZZLE:
		_label.add_theme_color_override("font_shadow_color", Palette.STEEL_HIGHLIGHT)
		_underline = Control.new()
		_underline.name = "WastedUnderline"
		_underline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var width: float = snappedf(_text_width(_spec) + 6.0, ArtStyle.ART_SCALE)
		_underline.size = Vector2(width, FIZZLE_UNDERLINE_HEIGHT)
		_underline.position = Vector2(
			snappedf((size.x - width) / 2.0, ArtStyle.ART_SCALE), FIZZLE_UNDERLINE_Y
		)
		_underline.draw.connect(_draw_underline)
		_inner.add_child(_underline)
		# V3's word and underline follow the face's tilt, about the same centre.
		for part: Control in [_label, _underline]:
			part.pivot_offset = size / 2.0 - part.position
			part.rotation_degrees = tilt_deg
	if _spec.badge != GiverBadge.Kind.NONE:
		_badge = GiverBadge.new(
			_spec.badge, _spec.badge_text, _spec.badge_mini, _spec.badge_run_colour
		)
		var badge_x: float = (
			BURST_BADGE_X if _spec.kind == StickerSpec.Kind.MULTIPLY else LABEL_BADGE_X
		)
		var badge_y: float = snappedf((size.y - _badge.size.y) / 2.0, ArtStyle.ART_SCALE)
		_badge.position = Vector2(badge_x, badge_y)
		_inner.add_child(_badge)
	_check = Control.new()
	_check.name = CHECK_NAME
	_check.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_check.size = CHECK_SIZE
	_check.pivot_offset = CHECK_SIZE / 2.0
	_check.position = Vector2(size.x - CHECK_SIZE.x + CHECK_OVERHANG.x, -CHECK_OVERHANG.y)
	_check.visible = false
	_check.draw.connect(_draw_check)
	_inner.add_child(_check)
	_colour_text()


## A sticker's size for `sticker_spec` (section 4.1).
static func size_for(sticker_spec: StickerSpec) -> Vector2:
	match sticker_spec.kind:
		StickerSpec.Kind.MULTIPLY:
			return BURST_SIZE
		StickerSpec.Kind.FIZZLE:
			var grey: float = _text_width(sticker_spec) + FIZZLE_PADDING + FIZZLE_TEXT_PADDING
			var width: float = maxf(FIZZLE_SIZE.x, snappedf(grey, ArtStyle.ART_SCALE))
			return Vector2(width, FIZZLE_SIZE.y)
		StickerSpec.Kind.MORE:
			var wide: float = FOLD_TEXT_X + _text_width(sticker_spec) + FOLD_PADDING
			var grid: float = ArtStyle.ART_SCALE
			return Vector2(maxf(FOLD_SIZE.x, ceilf(wide / grid) * grid), FOLD_SIZE.y)
	var characters: int = sticker_spec.text.length()
	if characters <= 2:
		return Vector2(LABEL_WIDTHS[0], LABEL_HEIGHT)
	if characters == 3:
		return Vector2(LABEL_WIDTHS[1], LABEL_HEIGHT)
	var padded: float = _text_width(sticker_spec) + LABEL_PADDING
	return Vector2(snappedf(padded, ArtStyle.ART_SCALE), LABEL_HEIGHT)


## The sticker's text width at its text size, in the number font.
static func _text_width(sticker_spec: StickerSpec) -> float:
	var font: Font = ArtStyle.number_font()
	var text_size: int = _text_size(sticker_spec)
	return font.get_string_size(sticker_spec.text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x


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
	for part: Control in [_shadow, _frame, _mark, _underline]:
		if part != null:
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


## Its step landed in the count (#86 v6): the sticker punches, flashes and turns back, then the
## green check settles on its corner, on `make_tween`'s tweens when given (the count-up's, so its
## hit-stops and skips hold and speed it). Under `reduced_motion` (or out of the tree) the check
## shows at once, with no punch or flash. A second fire punches again; the check stays. The fold
## chip gets no check: each fire counts it down by one folded sticker with a punch, and the last
## shrinks it away (at once under reduced motion).
func fire(reduced_motion: bool, make_tween: Callable = Callable()) -> void:
	_fired = true
	if _spec.kind == StickerSpec.Kind.MORE:
		_count_down(reduced_motion, make_tween)
		return
	var tween: Tween = _start_motion(reduced_motion, make_tween)
	if tween == null:
		_check.visible = true
		return
	tween.tween_method(_punch.bind(FIRE_PUNCH, true), 0.0, 1.0, FIRE_S)
	if _check.visible:
		return
	tween.tween_interval(maxf(CHECK_AT - FIRE_S, 0.0))
	tween.tween_callback(_check.set_visible.bind(true))
	tween.tween_method(_settle_check, CHECK_POP, 1.0, CHECK_SETTLE_S)


## A giver's sparks reached it (#86 v6): a light punch with the flash, on `make_tween`'s tweens
## when given; nothing under `reduced_motion`.
func charge(reduced_motion: bool, make_tween: Callable = Callable()) -> void:
	var tween: Tween = _start_motion(reduced_motion, make_tween)
	if tween != null:
		tween.tween_method(_punch.bind(CHARGE_PUNCH, false), 0.0, 1.0, FIRE_S)


## The fold chip's motion as more stickers fold into it while planning: a pop from FOLD_POP_FROM
## when it is `first` shown, else a punch; on `make_tween`'s tweens when given; nothing under
## `reduced_motion`.
func fold_punch(first: bool, reduced_motion: bool, make_tween: Callable = Callable()) -> void:
	var tween: Tween = _start_motion(reduced_motion, make_tween)
	if tween == null:
		return
	if first:
		_set_inner_scale(FOLD_POP_FROM)
		tween.tween_method(_set_inner_scale, FOLD_POP_FROM, 1.0, FOLD_POP_S)
	else:
		tween.tween_method(_bump, 0.0, 1.0, FOLD_PUNCH_S)


## Shows `number` (1 and up) on the top edge at `alpha`, or hides it (0 or less): a fanned
## sticker's order (StackFan).
func set_number(number: int, alpha: float = 1.0) -> void:
	if number <= 0:
		if _number != null:
			_number.visible = false
		return
	if _number == null:
		_number = Control.new()
		_number.name = NUMBER_NAME
		_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_number.position = NUMBER_AT
		_number.size = NUMBER_SIZE
		_number.draw.connect(_draw_number)
		var label: Label = UiKit.number_label("", NUMBER_TEXT_SIZE, false)
		label.add_theme_color_override("font_color", Palette.PAPER)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = NUMBER_SIZE
		_number.add_child(label)
		add_child(_number)
	(_number.get_child(0) as Label).text = str(number)
	_number.visible = true
	_number.modulate.a = clampf(alpha, 0.0, 1.0)


## The order number's rect (its ring included) in the sticker's coordinates, or an empty rect
## when none shows.
func number_rect() -> Rect2:
	if _number == null or not _number.visible:
		return Rect2()
	return Rect2(_number.position, _number.size).grow(NUMBER_RING)


## Whether its step has landed in the count (fire).
func is_fired() -> bool:
	return _fired


## The check (shown once fired) in the sticker's coordinates.
func check_rect() -> Rect2:
	return Rect2(_check.position, _check.size)


## Whether the check shows.
func has_check() -> bool:
	return _check.visible


## Whether a fire or a charge is moving it (for tests).
func is_firing() -> bool:
	return _fire_tween != null and _fire_tween.is_valid() and _fire_tween.is_running()


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
			StickerSpec.Kind.FIZZLE: WASTED_FRAME,
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


## Stops the slap and any fire or charge, the sticker at rest, and returns the next motion's
## tween (`make_tween`'s when given), or null for none: under `reduced_motion` or out of the tree.
func _start_motion(reduced_motion: bool, make_tween: Callable) -> Tween:
	if _slap_tween != null:
		_slap_tween.kill()
		_slap_tween = null
	if _fire_tween != null:
		_fire_tween.kill()
		_fire_tween = null
	_punch(1.0, 0.0, false)
	if reduced_motion or not is_inside_tree():
		return null
	_fire_tween = make_tween.call() as Tween if make_tween.is_valid() else create_tween()
	return _fire_tween


## The punch at `progress` (0 to 1): scaled 1 + `amount` easing back to 1, turned (`turn`) from
## FIRE_TURN_DEG back to 0, and flashed for the first FLASH_S.
func _punch(progress: float, amount: float, turn: bool) -> void:
	var left: float = 1.0 - progress
	_inner.scale = Vector2.ONE * (1.0 + amount * left * left)
	_inner.rotation_degrees = FIRE_TURN_DEG * left if turn else 0.0
	var flash: float = FLASH if amount > 0.0 and progress * FIRE_S < FLASH_S else 1.0
	_inner.modulate = Color(flash, flash, flash)


## The fold chip in the count: one folded sticker fired. The count drops by one with a punch; at
## 0 the chip shrinks and fades away (its alpha stays 0: the layer's layout only shows and hides).
func _count_down(reduced_motion: bool, make_tween: Callable) -> void:
	_unfired = maxi(_unfired - 1, 0)
	if _unfired > 0:
		_label.text = StickerSpec.MORE_TEXT % _unfired
	var tween: Tween = _start_motion(reduced_motion, make_tween)
	if _unfired > 0:
		if tween != null:
			tween.tween_method(_bump, 0.0, 1.0, FOLD_PUNCH_S)
		return
	if tween == null:
		modulate.a = 0.0
		return
	tween.tween_method(_vanish, 0.0, 1.0, FOLD_POP_S)


func _set_inner_scale(inner_scale: float) -> void:
	_inner.scale = Vector2.ONE * inner_scale


## The fold chip's punch at `progress` (0 to 1): 1 + FOLD_PUNCH easing back to 1.
func _bump(progress: float) -> void:
	var left: float = 1.0 - progress
	_set_inner_scale(1.0 + FOLD_PUNCH * left * left)


## The fold chip going at `progress` (0 to 1): shrinking to FOLD_POP_FROM and fading.
func _vanish(progress: float) -> void:
	_set_inner_scale(lerpf(1.0, FOLD_POP_FROM, progress))
	modulate.a = 1.0 - progress


## The order number: its paper ring, then the ink square (the number is its label).
func _draw_number() -> void:
	var square: Rect2 = Rect2(Vector2.ZERO, NUMBER_SIZE)
	_number.draw_rect(square.grow(NUMBER_RING), Palette.PAPER)
	_number.draw_rect(square, Palette.INK)


func _draw_underline() -> void:
	_underline.draw_rect(Rect2(Vector2.ZERO, _underline.size), Palette.TOMATO_DARK)
	_underline.draw_rect(
		Rect2(Vector2.ZERO, Vector2(_underline.size.x, ArtStyle.ART_SCALE)), Palette.TOMATO
	)


func _settle_check(check_scale: float) -> void:
	_check.scale = Vector2.ONE * check_scale


## The check: its cells in Palette.GOOD over their one-pixel ink outline.
func _draw_check() -> void:
	var cell: float = ArtStyle.ART_SCALE
	for colour: Color in [Palette.INK, Palette.GOOD]:
		var grow: float = cell if colour == Palette.INK else 0.0
		for at: Vector2i in CHECK_CELLS:
			var rect: Rect2 = Rect2(Vector2(at) * cell, Vector2(cell, cell))
			_check.draw_rect(rect.grow(grow), colour)


func _colour_text() -> void:
	var fizzle: bool = _spec.kind == StickerSpec.Kind.FIZZLE
	var colour: Color = Palette.INK_LIGHT if fizzle else Palette.INK
	_label.add_theme_color_override("font_color", Palette.GREY_DARK if _drained else colour)


static func _text_size(sticker_spec: StickerSpec) -> int:
	match sticker_spec.kind:
		StickerSpec.Kind.MULTIPLY:
			if sticker_spec.text.length() >= BURST_SMALL_CHARS:
				return BURST_SMALL_SIZE
			return BURST_TEXT_SIZE
		StickerSpec.Kind.FIZZLE:
			return GREY_TEXT_SIZE
		StickerSpec.Kind.MORE:
			return FOLD_TEXT_SIZE
	return LABEL_TEXT_SIZE
