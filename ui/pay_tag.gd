class_name PayTag
extends Control
## The real pay on a planning item's ticket (#71, mock-up h1, H1_BUILD_SPEC.md section 4.5): a
## gold burst for a boosted pay (a wide one from WIDE_CHARS characters), a cream tag for a
## lowered one, and a punched tomato "€0" tag with the warning glyph (an inspection's denial) or
## the paper fizzle glyph (a card's own denial, or a pay wiped by fizzles). Its shadow is the same
## art in ink at SHADOW_ALPHA, SHADOW_OFFSET down and right. PlanningLayer pins it on the ticket's
## top-right corner (#105, mock-up readability v3: the stacked price, the struck old price under
## it, PriceSticker), die-cut out of the ticket's colour (`cut`: a paper art pixel, then an ink one,
## round its art, ArtStyle.cut_material). Dimmed (an unrelated item while another is hovered) it
## fades to `dimmed_alpha`. Decor only: every number is a payout from the score. A ticket's own
## plain tag at rest (PriceSticker) is the LOWERED tag's look.

## A boosted pay this long or longer takes the wide burst.
const WIDE_CHARS := 4
const BURST_SIZE := Vector2(60, 32)
const WIDE_SIZE := Vector2(80, 36)
const TAG_SIZE := Vector2(52, 26)
## The burst's text (#105): BURST_TEXT_SIZE, or ArtStyle.BURST_PRICE_SIZE_3 for three characters
## ("€10").
const BURST_TEXT_SIZE := ArtStyle.BURST_PRICE_SIZE
## The wide burst's text: WIDE_TEXT_SIZE for WIDE_CHARS characters, WIDE_LONG_SIZE for more, still
## shrinking to WIDE_MIN_SIZE to fit its width less WIDE_PADDING.
const WIDE_TEXT_SIZE := 21
const WIDE_LONG_SIZE := 18
const WIDE_MIN_SIZE := 16
const WIDE_PADDING := 16.0
const TAG_TEXT_SIZE := 17
## On the €0 tag: the glyph at GLYPH_AT (the warning sign at 1x, WARNING_AT, so it fits the
## tag's face), the text from TEXT_LEFT.
const GLYPH_AT := Vector2(6, 6)
const FIZZLE_SIZE := Vector2(14, 14)
const WARNING_AT := Vector2(5, 8)
const WARNING_SIZE := Vector2(13, 11)
const TEXT_LEFT := 18.0
const TEXT_RIGHT := 4.0
const SHADOW_OFFSET := Vector2(3, 3)
const SHADOW_ALPHA := 0.42
const CUT_NAME := "Cut"
const STRUCK_NAME := "Struck"

const BURST := preload("res://art/effects/pay_burst.png")
const WIDE_BURST := preload("res://art/effects/pay_burst_wide.png")
const ZERO := preload("res://art/effects/pay_zero.png")
const PLAIN := preload("res://art/effects/pay_plain.png")
const FIZZLE := preload("res://art/effects/fizzle_paper.png")
const WARNING := preload("res://art/icons/warning.png")

## The alpha a dimmed tag fades to (PlanningTuning.dim_ticket_alpha).
var dimmed_alpha: float = 1.0
var pay: PlanningModel.Pay = PlanningModel.Pay.PLAIN
var glyph: PlanningModel.Glyph = PlanningModel.Glyph.NONE
var _label: Label
var _dimmed: bool = false
var _tween: Tween


## The tag of a `tag_pay` pay showing `shown`, with `tag_glyph` on a €0 tag, die-cut when
## `die_cut`.
func _init(
	tag_pay: PlanningModel.Pay,
	shown: String,
	tag_glyph: PlanningModel.Glyph = PlanningModel.Glyph.NONE,
	die_cut: bool = false
) -> void:
	pay = tag_pay
	glyph = tag_glyph
	name = "PayTag"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = size_for(tag_pay, shown)
	custom_minimum_size = size
	var texture: Texture2D = _texture(tag_pay, shown)
	var shadow: TextureRect = UiKit.sprite(texture)
	shadow.name = "Shadow"
	shadow.position = SHADOW_OFFSET
	shadow.size = size
	shadow.self_modulate = Color(Palette.INK, SHADOW_ALPHA)
	add_child(shadow)
	if die_cut:
		# The cut's outline is the tag's new edge: the shadow falls from it too.
		var grow: float = ArtStyle.RIM_TEXELS * ArtStyle.ART_SCALE
		var cut_shadow: TextureRect = UiKit.sprite(texture)
		cut_shadow.name = "CutShadow"
		cut_shadow.position = SHADOW_OFFSET - Vector2.ONE * grow
		cut_shadow.size = size + Vector2.ONE * 2.0 * grow
		var ink: Color = Color(Palette.INK, SHADOW_ALPHA)
		ArtStyle.set_look(cut_shadow, ArtStyle.rim_material(PackedColorArray([ink, ink])))
		add_child(cut_shadow)
		var rim: TextureRect = UiKit.sprite(texture)
		rim.name = CUT_NAME
		rim.position = -Vector2.ONE * grow
		rim.size = size + Vector2.ONE * 2.0 * grow
		ArtStyle.set_look(rim, ArtStyle.cut_material())
		add_child(rim)
	var face: TextureRect = UiKit.sprite(texture)
	face.name = "Face"
	face.size = size
	add_child(face)
	var zero: bool = tag_pay == PlanningModel.Pay.DENIED or tag_pay == PlanningModel.Pay.ZERO
	var left: float = 0.0
	if zero and tag_glyph != PlanningModel.Glyph.NONE:
		var warning: bool = tag_glyph == PlanningModel.Glyph.WARNING
		var icon: TextureRect = UiKit.sprite(WARNING if warning else FIZZLE)
		icon.name = "Glyph"
		icon.position = WARNING_AT if warning else GLYPH_AT
		icon.size = WARNING_SIZE if warning else FIZZLE_SIZE
		add_child(icon)
		left = TEXT_LEFT
	_label = UiKit.number_label(shown, _text_size(tag_pay, shown), false)
	_label.name = "Text"
	_label.add_theme_color_override("font_color", Palette.PAPER if zero else Palette.INK)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.position = Vector2(left, 0)
	_label.size = Vector2(size.x - left - (TEXT_RIGHT if left > 0.0 else 0.0), size.y)
	add_child(_label)


## The tag's size for a `tag_pay` pay showing `shown`: the burst, the wide burst or a tag.
static func size_for(tag_pay: PlanningModel.Pay, shown: String) -> Vector2:
	if tag_pay == PlanningModel.Pay.BOOSTED:
		return WIDE_SIZE if shown.length() >= WIDE_CHARS else BURST_SIZE
	return TAG_SIZE


## The text shown.
func text() -> String:
	return _label.text


## The text's label.
func label() -> Label:
	return _label


## Shows the ticket's struck old price (#105, PriceSticker.StruckPrice of `old_price`, paper on a
## `dark` ticket) over the tag at `at` (this tag's coordinates), scaled `struck_scale` (a scaled
## row's ticket): drawn after the tag, so its shadow never greys it, as the mock-up stacks them.
func show_struck(old_price: String, dark: bool, at: Vector2, struck_scale: Vector2) -> void:
	var shown: PriceSticker.StruckPrice = struck()
	if shown == null or shown.text != old_price or shown.dark != dark:
		if shown != null:
			remove_child(shown)
			shown.queue_free()
		shown = PriceSticker.StruckPrice.new(old_price, dark)
		add_child(shown)
	shown.position = at
	shown.scale = struck_scale
	shown.visible = true


func hide_struck() -> void:
	var shown: PriceSticker.StruckPrice = struck()
	if shown != null:
		shown.visible = false


## The struck old price over the tag, or null.
func struck() -> PriceSticker.StruckPrice:
	return get_node_or_null(STRUCK_NAME) as PriceSticker.StruckPrice


## Fades the tag to `dimmed_alpha` (`dimmed`) or back to full, over `fade` seconds (0: at once).
func set_dimmed(dimmed: bool, fade: float = 0.0) -> void:
	_dimmed = dimmed
	var alpha: float = dimmed_alpha if dimmed else 1.0
	if _tween != null:
		_tween.kill()
		_tween = null
	if fade > 0.0 and is_inside_tree() and not is_equal_approx(modulate.a, alpha):
		_tween = create_tween()
		_tween.tween_property(self, "modulate:a", alpha, fade)
	else:
		modulate.a = alpha


func is_dimmed() -> bool:
	return _dimmed


static func _texture(tag_pay: PlanningModel.Pay, shown: String) -> Texture2D:
	match tag_pay:
		PlanningModel.Pay.BOOSTED:
			return WIDE_BURST if shown.length() >= WIDE_CHARS else BURST
		PlanningModel.Pay.LOWERED:
			return PLAIN
	return ZERO


## The text's size: the burst's, the wide burst's (shrunk to fit), or a tag's.
static func _text_size(tag_pay: PlanningModel.Pay, shown: String) -> int:
	if tag_pay != PlanningModel.Pay.BOOSTED:
		return TAG_TEXT_SIZE
	if shown.length() < WIDE_CHARS:
		return BURST_TEXT_SIZE if shown.length() < 3 else ArtStyle.BURST_PRICE_SIZE_3
	var font: Font = ArtStyle.number_font()
	var largest: int = WIDE_TEXT_SIZE if shown.length() == WIDE_CHARS else WIDE_LONG_SIZE
	for font_size: int in range(largest, WIDE_MIN_SIZE - 1, -1):
		var width: float = font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if width <= WIDE_SIZE.x - WIDE_PADDING:
			return font_size
	return WIDE_MIN_SIZE
