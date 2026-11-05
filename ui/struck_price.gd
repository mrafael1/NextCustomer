class_name StruckPrice
extends Control
## A struck old price (#105): its text, right-aligned in its rect, and the strike low across it,
## ink with a paper rim (or paper on a `dark` ground) and a tomato strike (paper on a dark
## ground). The monitor's item column shows it beside a changed price (MonitorItemColumn); the
## tickets no longer strike a price (tickets v5: the printed price is in the window's tip).

const NODE_NAME := "Struck"
const HEIGHT := 17.0
## The strike STRIKE_DROP of the text size down, STRIKE_WIDTH thick, STRIKE_OUT past each end.
const STRIKE_DROP := 0.62
const STRIKE_WIDTH := 2.0
const STRIKE_OUT := 2.0

var text: String = ""
var dark: bool = false


func _init(shown: String, on_dark: bool) -> void:
	name = NODE_NAME
	text = shown
	dark = on_dark
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(ceilf(text_width(text)), HEIGHT)


## Its font: the number font's face at its weight, from the raster import (crisp at 15 px, where
## the MSDF import the count-up's slams need draws soft).
static func price_font() -> Font:
	return ArtStyle.bold_font(ArtStyle.NUMBER_WEIGHT)


static func text_width(shown: String) -> float:
	var font: Font = price_font()
	return font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, ArtStyle.STRUCK_PRICE_SIZE).x


## The strike's rect, in this control's coordinates.
func strike_rect() -> Rect2:
	return Rect2(
		-STRIKE_OUT,
		roundf(ArtStyle.STRUCK_PRICE_SIZE * STRIKE_DROP),
		size.x + 2.0 * STRIKE_OUT,
		STRIKE_WIDTH
	)


func strike_color() -> Color:
	return Palette.PAPER if dark else Palette.TOMATO


func text_color() -> Color:
	return Palette.PAPER if dark else Palette.INK


func _draw() -> void:
	var font: Font = price_font()
	var font_size: int = ArtStyle.STRUCK_PRICE_SIZE
	var ascent: float = font.get_ascent(font_size)
	var height: float = ascent + font.get_descent(font_size)
	var at: Vector2 = Vector2(0.0, roundf((size.y - height) / 2.0 + ascent))
	if not dark:
		draw_string_outline(
			font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 2, Palette.PAPER
		)
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, text_color())
	draw_rect(strike_rect(), strike_color())
