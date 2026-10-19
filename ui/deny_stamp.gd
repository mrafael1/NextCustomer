class_name DenyStamp
extends Control
## The rubber stamp over a denied planning item (#71, mock-up h1, H1_BUILD_SPEC.md section 4.4): a
## tilted tomato stamp (art/effects/deny_stamp, the one piece with no ink outline) printed with the
## overridden pay ("€0") and the denier's name in capitals ("SPOT CHECK", or the card's own name
## for its own override). The two lines turn with the stamp (TILT_DEG about its centre). Drained
## (an unrelated item while another is hovered) its ink greys. Decor only: the amount is the
## PAYOUT_OVERRIDE step's value.

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

const STAMP := preload("res://art/effects/deny_stamp.png")

var _face: TextureRect
var _amount: Label
var _caption: Label
var _drained: bool = false


## A stamp printed `printed` (the amount) over `denier` (the caption).
func _init(printed: String, denier: String) -> void:
	name = "DenyStamp"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	custom_minimum_size = SIZE
	_face = UiKit.sprite(STAMP)
	_face.name = "Face"
	_face.size = SIZE
	add_child(_face)
	var lines: VBoxContainer = VBoxContainer.new()
	lines.name = "Lines"
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.add_theme_constant_override("separation", LINE_GAP)
	lines.size = SIZE
	lines.pivot_offset = SIZE / 2.0
	lines.rotation_degrees = TILT_DEG
	add_child(lines)
	_amount = UiKit.number_label(printed, AMOUNT_SIZE, false)
	_amount.name = "Amount"
	_amount.add_theme_font_override("font", ArtStyle.bold_font(AMOUNT_WEIGHT))
	_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(_amount)
	var font: Font = ArtStyle.spaced_display_font(CAPTION_SPACING)
	var fitted: Array = fit_caption(denier, font)
	_caption = UiKit.display_label(fitted[0], fitted[1], false)
	_caption.name = "Caption"
	_caption.add_theme_font_override("font", font)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lines.add_child(_caption)
	_colour()


## `denier` as it fits CAPTION_WIDTH in `font`: [text, size], at the first CAPTION_SIZES size it
## fits, else at the smallest, cut with ELLIPSIS.
static func fit_caption(denier: String, font: Font) -> Array:
	for font_size: int in CAPTION_SIZES:
		if _width(denier, font, font_size) <= CAPTION_WIDTH:
			return [denier, font_size]
	var smallest: int = CAPTION_SIZES[-1]
	var cut: String = denier
	while cut.length() > 1 and _width(cut + ELLIPSIS, font, smallest) > CAPTION_WIDTH:
		cut = cut.substr(0, cut.length() - 1)
	return [cut.strip_edges() + ELLIPSIS, smallest]


func amount() -> String:
	return _amount.text


func caption() -> String:
	return _caption.text


## Greys the stamp's ink (`drained`), or puts it back.
func set_drained(drained: bool) -> void:
	_drained = drained
	ArtStyle.set_look(_face, ArtStyle.grey_material(ArtStyle.Grey.DRAINED) if drained else null)
	_colour()


func is_drained() -> bool:
	return _drained


func _colour() -> void:
	var colour: Color = Palette.GREY_DARK if _drained else Palette.TOMATO_DARK
	for line: Label in [_amount, _caption]:
		line.add_theme_color_override("font_color", colour)


static func _width(text: String, font: Font, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
