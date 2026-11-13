class_name ReceiptHighlight
extends Label
## The final receipt's BEST line (v1.37, the approved direction A of
## docs/art/mockups/receipt_highlight.html): FinalReceipt's HIGHLIGHT line on a gold band, the gold
## BEST sticker and the moment's mini in its leading spaces (FinalReceipt.HIGHLIGHT_INDENT; the
## item's 7x7 mini; the combo diamond for a combo; the quota target for Over quota and Closest
## call), its text and its shift on the right. ResultsPanel prints it in its turn (play): the band
## wipes in, the sticker slams down with the stamp sound and holds for the hit-stop, then a glint
## crosses the band once; finish shows it in its final state at once (a tap, reduced motion).
## Its size is the text's, so the FITS search counts it like any line.

const STICKER := preload("res://art/effects/sticker_burst_best.png")
const COMBO_ICON := preload("res://art/icons/combo_diamond.png")
const QUOTA_ICON := preload("res://art/icons/target_euro.png")
const WORD := "BEST"
## The band's room above and below the text, as a share of the font size.
const PAD_SHARE := 0.35
## The band reaches this far past the text on both sides, in px.
const BLEED := 6.0
## The sticker, mini and gaps in the indent: the gap between them, in px.
const GAP := 3.0
## The sticker art's size in art pixels. It is drawn at the largest scale that fits the indent
## beside the mini and overhangs the band by at most STICKER_OVERHANG of the band's height above
## and below (the mock-up's burst overhangs its line), in steps of STICKER_SCALE_STEP (whole art
## pixels from 2: even NEAREST pixels), never under 1.
const STICKER_ART := Vector2i(38, 21)
const STICKER_OVERHANG := 0.35
const STICKER_SCALE_STEP := 0.5
## The mini's side as a share of the line's height, rounded to whole art pixels (7x7).
const MINI_SHARE := 0.6
## The slam starts this many times larger.
const SLAM_SCALE := 1.8
## The word on the sticker (cream with an ink outline), as a share of the sticker's height, its
## smallest size and its outline, in px.
const WORD_SHARE := 0.5
const WORD_MIN_SIZE := 9
const WORD_OUTLINE := 3
## The glint's width as a share of the band's, and its look.
const GLINT_SHARE := 0.08
const GLINT := Color(Palette.PAPER, 0.7)

var _band: ColorRect
var _glint: ColorRect
var _sticker: Control
var _sticker_art: TextureRect
var _word: Label
var _mini: TextureRect
var _font_size: int = 16
var _tween: Tween
## 0 to 1: how much of the band shows (its wipe).
var _wipe: float = 1.0


## `line` is FinalReceipt's HIGHLIGHT line, `font_size` the receipt's line size.
func _init(line: FinalReceipt.Line, font_size: int, font: Font) -> void:
	_font_size = font_size
	text = line.text
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_font_override("font", font)
	add_theme_font_size_override("font_size", font_size)
	add_theme_color_override("font_color", Palette.INK)
	var room: StyleBoxEmpty = StyleBoxEmpty.new()
	room.content_margin_top = roundf(font_size * PAD_SHARE)
	room.content_margin_bottom = roundf(font_size * PAD_SHARE)
	add_theme_stylebox_override("normal", room)
	_band = ColorRect.new()
	_band.name = "Band"
	_band.color = Palette.MUSTARD_LIGHT
	_band.show_behind_parent = true
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band)
	_glint = ColorRect.new()
	_glint.name = "Glint"
	_glint.color = GLINT
	_glint.show_behind_parent = true
	_glint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glint.visible = false
	add_child(_glint)
	_mini = TextureRect.new()
	_mini.name = "Mini"
	_mini.texture = icon_of(line.moment)
	_mini.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_mini.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_mini.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mini.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_mini)
	_sticker = Control.new()
	_sticker.name = "Sticker"
	_sticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sticker)
	_sticker_art = TextureRect.new()
	_sticker_art.texture = STICKER
	_sticker_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sticker_art.stretch_mode = TextureRect.STRETCH_SCALE
	_sticker_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sticker_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sticker_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sticker.add_child(_sticker_art)
	_word = UiKit.display_label(WORD, WORD_MIN_SIZE, true)
	_word.add_theme_constant_override("outline_size", WORD_OUTLINE)
	_word.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_word.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sticker.add_child(_word)
	resized.connect(_place)


## The mini a moment shows: its item's giver-badge mini (CardDefinition.badge_mini_ref), the combo
## diamond for a combo, the quota target otherwise (or an item with no mini).
static func icon_of(moment: RunHighlight.Moment) -> Texture2D:
	if moment != null and moment.card != null:
		var ref: String = moment.card.badge_mini_ref()
		if not ref.is_empty() and ResourceLoader.exists(ref):
			return load(ref) as Texture2D
	if moment != null and moment.kind == RunHighlight.Kind.LONGEST_COMBO:
		return COMBO_ICON
	return QUOTA_ICON


## Prints it in its turn: the band wipes in over `tuning`'s final_highlight_wipe_ms, then the
## sticker slams down (final_highlight_slam_ms, its last final_highlight_stop_ms still, the stamp
## sound at its landing), then the glint crosses the band (final_highlight_glint_ms). With
## `reduced_motion` it shows in its final state at once.
func play(tuning: CountUpTuning, reduced_motion: bool) -> void:
	_kill()
	if reduced_motion:
		finish()
		return
	_set_wipe(0.0)
	_sticker.visible = false
	_glint.visible = false
	var slam_s: float = maxi(tuning.final_highlight_slam_ms - tuning.final_highlight_stop_ms, 1)
	slam_s /= 1000.0
	_tween = create_tween()
	_tween.tween_method(_set_wipe, 0.0, 1.0, tuning.final_highlight_wipe_ms / 1000.0)
	_tween.tween_callback(_begin_slam)
	_tween.tween_property(_sticker, "scale", Vector2.ONE, slam_s).set_trans(Tween.TRANS_QUAD)
	_tween.tween_callback(_land)
	_tween.tween_interval(tuning.final_highlight_stop_ms / 1000.0)
	_tween.tween_callback(func() -> void: _glint.visible = true)
	_tween.tween_method(_set_glint, 0.0, 1.0, tuning.final_highlight_glint_ms / 1000.0)
	_tween.tween_callback(func() -> void: _glint.visible = false)


## Shows it in its final state at once: the whole band, the sticker down, no glint.
func finish() -> void:
	_kill()
	_set_wipe(1.0)
	_sticker.visible = true
	_sticker.scale = Vector2.ONE
	_glint.visible = false


## Whether its print is still playing (for tests).
func is_playing() -> bool:
	return _tween != null and _tween.is_valid() and _tween.is_running()


## The band's rect (for tests and layout checks).
func band_rect() -> Rect2:
	return _band.get_global_rect()


## The sticker's and the mini's rects (for tests and layout checks).
func sticker_rect() -> Rect2:
	return _sticker.get_global_rect()


func mini_rect() -> Rect2:
	return _mini.get_global_rect()


## How many characters its text starts in: the sticker's and the mini's room.
func indent_chars() -> int:
	return text.length() - text.lstrip(" ").length()


## The sticker's scale over its art (for tests).
func sticker_scale() -> float:
	return _sticker.size.x / STICKER_ART.x


## The mini's texture (for tests).
func mini_texture() -> Texture2D:
	return _mini.texture


func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


func _begin_slam() -> void:
	_sticker.visible = true
	_sticker.scale = Vector2.ONE * SLAM_SCALE


func _land() -> void:
	var sfx: Sfx = Sfx.find(self)
	if sfx != null:
		sfx.play("stamp")


func _set_wipe(value: float) -> void:
	_wipe = value
	_place()


func _set_glint(value: float) -> void:
	var band: Rect2 = _band_local()
	var width: float = band.size.x * GLINT_SHARE
	_glint.position = Vector2(band.position.x + (band.size.x + width) * value - width, 0.0)
	_glint.size = Vector2(width, size.y)


## The band's rect in its own coordinates: the line, BLEED wider on both sides.
func _band_local() -> Rect2:
	return Rect2(Vector2(-BLEED, 0.0), Vector2(size.x + 2.0 * BLEED, size.y))


## Lays out the band (as far as its wipe), the sticker and the mini in the indent.
func _place() -> void:
	var band: Rect2 = _band_local()
	_band.position = band.position
	_band.size = Vector2(band.size.x * _wipe, band.size.y)
	var font: Font = get_theme_font("font")
	var char_width: float = font.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
	var indent: float = char_width * indent_chars()
	var mini_side: float = 7.0 * maxi(1, roundi(size.y * MINI_SHARE / 7.0))
	var by_width: float = (indent - mini_side - 3.0 * GAP) / STICKER_ART.x
	var by_height: float = size.y * (1.0 + 2.0 * STICKER_OVERHANG) / STICKER_ART.y
	var scale_factor: float = minf(by_width, by_height)
	var step: float = 1.0 if scale_factor >= 2.0 else STICKER_SCALE_STEP
	scale_factor = maxf(1.0, floorf(scale_factor / step) * step)
	var sticker_size: Vector2 = Vector2(STICKER_ART) * scale_factor
	_sticker.size = sticker_size
	_sticker.position = Vector2(0.0, (size.y - sticker_size.y) / 2.0).round()
	_sticker.pivot_offset = sticker_size / 2.0
	var word_size: int = maxi(WORD_MIN_SIZE, roundi(sticker_size.y * WORD_SHARE))
	_word.add_theme_font_size_override("font_size", word_size)
	_mini.size = Vector2.ONE * mini_side
	# Centred between the sticker and the text.
	var mini_x: float = (sticker_size.x + indent - mini_side) / 2.0
	_mini.position = Vector2(maxf(mini_x, sticker_size.x + GAP), (size.y - mini_side) / 2.0).round()
