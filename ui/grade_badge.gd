class_name GradeBadge
extends Control
## The difficulty grade's staff badge (#182, the user's pick of 2026-11-23: "GRADE" with a
## numbered staff badge): the tomato ID badge (icons/grade_badge, 16x20 art) drawn `art_scale`
## times larger, the grade's number in its paper window in the hard pixel number font (ink), one
## font px to one art px. The top bar shows it at 2x while a graded run plays; the grade card
## shows the picked grade's at 3x. Display only. The digit's drawn ink (PixelLine.glyph_ink) is
## centred in the window on the art grid (the user's 2026-11-23 polish: the font-metric centring
## sat the digit low and a narrow "1" off centre).

const ART := preload("res://art/icons/grade_badge.png")
## The badge's paper window, in art px from the badge's top left: the number is centred on it.
const WINDOW := Rect2(4, 7, 8, 10)

## The grade shown.
var grade: int = 0:
	set(value):
		grade = value
		_show_number()

var _art_scale: int = 2
var _number: Label
## The digit's drawn ink in canvas px from the badge's top left (digit_ink_rect).
var _ink: Rect2 = Rect2()


## A badge drawn `art_scale` times larger (2: the top bar, 3: the grade card).
func _init(art_scale: int = 2) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_scale = art_scale
	var shown: Vector2 = Vector2(ART.get_size()) * art_scale
	custom_minimum_size = shown
	size = shown
	var art: TextureRect = UiKit.sprite(ART)
	art.size = shown
	add_child(art)
	_number = Label.new()
	_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_number.add_theme_font_override("font", ArtStyle.pixel_number_font())
	_number.add_theme_font_size_override("font_size", ArtStyle.PIXEL_NUMBER_SIZE)
	_number.add_theme_constant_override("outline_size", 0)
	_number.add_theme_color_override("font_color", Palette.INK)
	ArtStyle.use_pixel_text_material(_number)
	_number.scale = Vector2.ONE * art_scale
	add_child(_number)
	_show_number()


## The number's label (tests read its text and place).
func number_label() -> Label:
	return _number


## The digit's drawn ink in canvas px from the badge's top left (tests check its centring).
func digit_ink_rect() -> Rect2:
	return _ink


## Shows the grade's digit (grades are 0-5: one glyph) with its ink centred in WINDOW, floored
## onto the badge's art grid (a 7 px wide 4 or a 3 px wide 1 sits half an art px left).
func _show_number() -> void:
	var digit: String = str(grade)
	_number.text = digit
	var ascent: float = ArtStyle.pixel_number_font().get_ascent(ArtStyle.PIXEL_NUMBER_SIZE)
	var glyph: Rect2i = PixelLine.glyph_ink(digit.left(1))
	var ink_size: Vector2 = Vector2(glyph.size)
	var at: Vector2 = WINDOW.position + ((WINDOW.size - ink_size) / 2.0).floor()
	_number.position = (at - Vector2(glyph.position.x, ascent + glyph.position.y)) * _art_scale
	_ink = Rect2(at * _art_scale, ink_size * _art_scale)
