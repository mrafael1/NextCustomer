class_name DenyStamp
extends Control
## The rubber stamp over a denied planning item (#71, mock-up h1, H1_BUILD_SPEC.md section 4.4): a
## tilted tomato stamp (art/effects/deny_stamp, the one piece with no ink outline) printed with the
## overridden pay ("0€") and the denier's name in capitals ("SPOT CHECK", or the card's own name
## for its own override). The two lines turn with the stamp (TILT_DEG about its centre). Drained
## (an unrelated item while another is hovered) its ink greys. Decor only: the amount is the
## PAYOUT_OVERRIDE step's value.
##
## A written-off item (v1.29, Write-off; `written_off`) is not denied: it still pays (its ticket
## shows how much), so it wears no tomato stamp over its art but a small paper label hung across
## its art's foot (WRITTEN_OFF_AT), WRITTEN OFF on one line in a coupon giver's teal ink and rim
## (the Write-off coupon did it; never the tomato of a denial or a fizzle), tilted like a stamp.
## Drained, its ink greys too.

const SIZE := Vector2(96, 68)
const TILT_DEG := -9.0
const AMOUNT_SIZE := 28
const AMOUNT_WEIGHT := 800
## The caption: CAPTION_SIZES tried in turn until it fits CAPTION_WIDTH, then cut with "…".
const CAPTION_SIZES: Array[int] = [11, 10, 9]
const CAPTION_WIDTH := 60.0
const CAPTION_SPACING := 1
const LINE_GAP := 1
const ELLIPSIS := "…"
## The written-off label: its size, its place on the item's art (its foot), its tilt, the room its
## caption has and its rim.
const WRITTEN_OFF_SIZE := Vector2(86, 24)
const WRITTEN_OFF_AT := Vector2(5, 70)
const WRITTEN_OFF_TILT_DEG := -5.0
const WRITTEN_OFF_WIDTH := 76.0
const WRITTEN_OFF_RIM := 2
const WRITTEN_OFF_INK := Palette.TEAL_DARK
const WRITTEN_OFF_RIM_INK := Palette.TEAL

const STAMP := preload("res://art/effects/deny_stamp.png")

var _face: Control
var _amount: Label
var _caption: Label
var _drained: bool = false
var _written_off: bool = false
## The written-off label's paper and rim (null on a denial stamp).
var _label_box: StyleBoxFlat


## A stamp printed `printed` (the amount) over `denier` (the caption); `written_off`: the
## written-off label instead (its caption only, `printed` kept for amount()).
func _init(printed: String, denier: String, written_off: bool = false) -> void:
	name = "DenyStamp"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_written_off = written_off
	var stamp_size: Vector2 = WRITTEN_OFF_SIZE if written_off else SIZE
	size = stamp_size
	custom_minimum_size = stamp_size
	if written_off:
		_label_box = StyleBoxFlat.new()
		_label_box.bg_color = Palette.PAPER
		_label_box.set_border_width_all(WRITTEN_OFF_RIM)
		_label_box.set_corner_radius_all(3)
		_label_box.shadow_color = Color(Palette.INK, 0.35)
		_label_box.shadow_offset = Vector2(0, 2)
		var paper: Panel = Panel.new()
		paper.add_theme_stylebox_override("panel", _label_box)
		_face = paper
	else:
		_face = UiKit.sprite(STAMP)
	_face.name = "Face"
	_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_face.size = stamp_size
	_face.pivot_offset = stamp_size / 2.0
	_face.rotation_degrees = WRITTEN_OFF_TILT_DEG if written_off else 0.0
	add_child(_face)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.name = "Lines"
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override("separation", LINE_GAP)
	lines.size = stamp_size
	lines.pivot_offset = stamp_size / 2.0
	lines.rotation_degrees = WRITTEN_OFF_TILT_DEG if written_off else TILT_DEG
	add_child(lines)
	_amount = UiKit.number_label(printed, AMOUNT_SIZE, false)
	_amount.name = "Amount"
	_amount.add_theme_font_override("font", ArtStyle.bold_font(AMOUNT_WEIGHT))
	_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(_amount)
	_amount.visible = not written_off
	var font: Font = ArtStyle.spaced_display_font(CAPTION_SPACING)
	var room: float = WRITTEN_OFF_WIDTH if written_off else CAPTION_WIDTH
	var fitted: Array = fit_caption(denier, font, room)
	_caption = UiKit.display_label(fitted[0], fitted[1], false)
	_caption.name = "Caption"
	_caption.add_theme_font_override("font", font)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(_caption)
	_colour()


## `denier` as it fits `width` (CAPTION_WIDTH; the written-off label's WRITTEN_OFF_WIDTH) in
## `font`: [text, size], at the first CAPTION_SIZES size it fits, else at the smallest, cut with
## ELLIPSIS. A caption on several lines fits by its widest line.
static func fit_caption(denier: String, font: Font, width: float = CAPTION_WIDTH) -> Array:
	for font_size: int in CAPTION_SIZES:
		if _width(denier, font, font_size) <= width:
			return [denier, font_size]
	var smallest: int = CAPTION_SIZES[-1]
	var cut: String = denier
	while cut.length() > 1 and _width(cut + ELLIPSIS, font, smallest) > width:
		cut = cut.substr(0, cut.length() - 1)
	return [cut.strip_edges() + ELLIPSIS, smallest]


func amount() -> String:
	return _amount.text


func caption() -> String:
	return _caption.text


## Whether it is a written-off item's label (not a denial: the item's stickers stay lit).
func is_written_off() -> bool:
	return _written_off


## Where it sits on its item's art (a denial over the art at `denied_at`, a written-off label at
## its foot).
func art_offset(denied_at: Vector2) -> Vector2:
	return WRITTEN_OFF_AT if _written_off else denied_at


## Greys the stamp's ink (`drained`), or puts it back.
func set_drained(drained: bool) -> void:
	_drained = drained
	if _label_box == null:
		ArtStyle.set_look(_face, ArtStyle.grey_material(ArtStyle.Grey.DRAINED) if drained else null)
	_colour()


func is_drained() -> bool:
	return _drained


func _colour() -> void:
	var colour: Color = Palette.GREY_DARK if _drained else Palette.TOMATO_DARK
	if _label_box != null:
		colour = Palette.GREY_DARK if _drained else WRITTEN_OFF_INK
		_label_box.border_color = Palette.GREY if _drained else WRITTEN_OFF_RIM_INK
	for line: Label in [_amount, _caption]:
		line.add_theme_color_override("font_color", colour)


static func _width(text: String, font: Font, font_size: int) -> float:
	var widest: float = 0.0
	for line: String in text.split("\n"):
		widest = maxf(
			widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		)
	return widest
