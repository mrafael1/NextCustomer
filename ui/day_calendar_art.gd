class_name DayCalendarArt
extends RefCounted
## The day calendar's shared art pieces (v1.19: the desk calendar, DeskCalendarArt, paints the
## page itself): the page model, each look's band colours, the kind's sign icons, the chunky
## capitals painter and the week pips' looks. Palette colours only, no alpha. Display only.

## The pad's look: a day's kind, or a passed inspection's EARNED (#77 machine v2's bonus ticket).
enum Look { NORMAL, INSPECTION, REVIEW, BOON, EARNED }
## The page's sign: none, the warning sign, the boon coin, the check mark.
enum Sign { NONE, WARNING, BOON, CHECK }
## A day pip: a day to come, a past day (played, no result), today, a training week's slip, a
## passed day (PAID).
enum PipLook { TODO, PAST, TODAY, SLIP, PAID }

## Stage px per art px.
const CELL := 2
const WARNING := preload("res://art/icons/warning.png")
const BOON := preload("res://art/icons/boon.png")
const CHECK := preload("res://art/icons/mark_check.png")

static var _icons: Dictionary[int, Image] = {}


## One page of the pad: its day (0: none), look, word (printed in capitals), sign (both sides of
## the word for a review) and pips; `payday`: the page's head is the PAYDAY band (DeskCalendarArt).
class Page:
	extends RefCounted
	var day: int = 0
	var look: Look = Look.NORMAL
	var word: String = ""
	var mark: Sign = Sign.NONE
	var both_sides: bool = false
	var pips: Array[PipLook] = []
	var payday: bool = false

	func copy() -> Page:
		var other: Page = Page.new()
		other.day = day
		other.look = look
		other.word = word
		other.mark = mark
		other.both_sides = both_sides
		other.pips = pips.duplicate()
		other.payday = payday
		return other


## The look's band, its dark row, its lit row and the word's ink (the mock-up's KIND).
static func band(look: Look) -> Array[Color]:
	match look:
		Look.INSPECTION:
			return [Palette.TOMATO, Palette.TOMATO_DARK, Palette.TOMATO_LIGHT, Palette.TOMATO_DARK]
		Look.REVIEW:
			return [
				Palette.MUSTARD, Palette.MUSTARD_DARK, Palette.MUSTARD_LIGHT, Palette.BRASS_DARK
			]
		Look.BOON:
			return [Palette.GOOD, Palette.GREEN_DARK, Palette.GREEN_LIGHT, Palette.GREEN_DARK]
		Look.EARNED:
			return [Palette.TEAL_LIGHT, Palette.TEAL, Palette.TEAL_PALE, Palette.TEAL_SHADE]
	return [Palette.STEEL_LIGHT, Palette.STEEL, Palette.STEEL_HIGHLIGHT, Palette.INK_LIGHT]


## Sign `sign`'s art (an Image, read once), or null.
static func icon(mark: Sign) -> Image:
	if mark == Sign.NONE:
		return null
	if not _icons.has(mark):
		var texture: Texture2D = WARNING
		if mark == Sign.BOON:
			texture = BOON
		elif mark == Sign.CHECK:
			texture = CHECK
		var image: Image = texture.get_image()
		if image.is_compressed():
			image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		_icons[mark] = image
	return _icons[mark]


## `words` from `sheet`, each font px `cell` art px, top left at `at`, in `ink`.
static func paint_words(
	image: Image, words: String, sheet: PixelWords.Sheet, cell: int, at: Vector2i, ink: Color
) -> void:
	var x: int = 0
	for character: String in words:
		var rows: Array = PixelWords.glyph_of(character, sheet)
		for row: int in range(rows.size()):
			var line: String = rows[row]
			for column: int in range(line.length()):
				if line[column] == "#":
					var pixel: Vector2i = at + Vector2i(x + column, row) * cell
					image.fill_rect(Rect2i(pixel, Vector2i(cell, cell)), ink)
		x += (rows[0] as String).length() + PixelWords.GAP


## `art` (an icon's image) at `at`, its opaque pixels only.
static func paint_icon(image: Image, art: Image, at: Vector2i) -> void:
	if art == null:
		return
	image.blend_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), at)


## The calendar's look for a week pip (WeekCardModel.pips: DONE is a past day with no result).
static func pip_look(pip: WeekCardModel.Pip) -> PipLook:
	match pip:
		WeekCardModel.Pip.NOW:
			return PipLook.TODAY
		WeekCardModel.Pip.SLIP:
			return PipLook.SLIP
		WeekCardModel.Pip.TODO:
			return PipLook.TODO
		WeekCardModel.Pip.PAID:
			return PipLook.PAID
	return PipLook.PAST
