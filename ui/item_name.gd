class_name ItemName
extends RefCounted
## An item's name as the readability pass prints it (#105, mock-up readability v3): Pixelify Sans
## at its regular weight and native size (ArtStyle.ITEM_NAME_SIZE, one font pixel = 2 canvas px),
## its numbers in the number font (MixedLabel: "2 for 1"), and never smaller: a name too long for
## its row falls back to the bold body font (ArtStyle.NAME_FALLBACK_WEIGHT, as the Cart prints its
## names) at the first FALLBACK_SIZES size that fits (else the smallest, clipped).

const FALLBACK_SIZES: Array[int] = [18, 16, 14, 13, 12]


## How wide `text` is at `font_size` in the name's fonts (its number runs in the number font).
static func width_of(text: String, font_size: int) -> float:
	var pattern: RegEx = RegEx.create_from_string(MixedLabel.NUMBER_PATTERN)
	var width: float = 0.0
	var start: int = 0
	for found: RegExMatch in pattern.search_all(text):
		width += _width(
			ArtStyle.DISPLAY_FONT, text.substr(start, found.get_start() - start), font_size
		)
		width += _width(ArtStyle.number_font(), found.get_string(), font_size)
		start = found.get_end()
	return width + _width(ArtStyle.DISPLAY_FONT, text.substr(start), font_size)


## Whether `text` fits `width` px at the name's own size.
static func fits(text: String, width: float) -> bool:
	return width_of(text, ArtStyle.ITEM_NAME_SIZE) <= width


## The fallback's size for `text` in `width` px: the first of FALLBACK_SIZES that fits.
static func fallback_size(text: String, width: float) -> int:
	var font: Font = ArtStyle.bold_font(ArtStyle.NAME_FALLBACK_WEIGHT)
	for font_size: int in FALLBACK_SIZES:
		if _width(font, text, font_size) <= width:
			return font_size
	return FALLBACK_SIZES[-1]


## The name `text` on one row `width` x `height` (its text centred in the row), in `color`: a
## MixedLabel at the name's size when it fits, else a bold body-font Label.
static func make(text: String, width: float, height: float, color: Color) -> Control:
	var made: Control
	if fits(text, width):
		made = MixedLabel.new(text, ArtStyle.ITEM_NAME_SIZE, false, color)
	else:
		var label: Label = UiKit.body_label(text, fallback_size(text, width), color)
		label.add_theme_font_override("font", ArtStyle.bold_font(ArtStyle.NAME_FALLBACK_WEIGHT))
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.clip_text = true
		made = label
	made.name = "ItemName"
	made.size = Vector2(width, height)
	return made


## Whether `name_control` (from make) is in the name's own font (else the fallback).
static func is_display(name_control: Control) -> bool:
	return name_control is MixedLabel


## The labels `name_control` (from make) draws its text with.
static func labels(name_control: Control) -> Array[Label]:
	if name_control is MixedLabel:
		return (name_control as MixedLabel).labels()
	var found: Array[Label] = [name_control as Label]
	return found


## The text `name_control` (from make) shows.
static func text_of(name_control: Control) -> String:
	if name_control is MixedLabel:
		return (name_control as MixedLabel).text
	return (name_control as Label).text


static func _width(font: Font, text: String, font_size: int) -> float:
	return font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
