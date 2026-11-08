class_name TicketFace
extends RefCounted
## A ticket's art (tickets v5, V5a of mock-up shift_scene_polish_v5_tickets.html): 54x38 art, shown
## at 2x (PriceSticker.SIZE), the same height for every item (2026-11-05: a gained family's glyph
## joins the printed ones on the label's one row; the tall ticket went).
## An ink outline with its corners cut two steps; the face in the colours of the family the card
## works with (FamilyStyle, data): its light colour on the top row and the left column, its shade
## on the right column and the bottom row. A split ticket (two families) is a 45° pixel stair:
## a pixel past SPLIT_SUM takes the second family, the stair's seam (x + y == SPLIT_SUM + 1) the
## second family's light colour. A coupon's bottom row is perforated in paper.
##
## Three zones sit on the face. Top left, the icon label (LABEL: one row of two icons; LABEL_WIDE,
## three icons, for an item with two printed families and a gained one, `wide`) and top right, the
## price window's place (WINDOW, WINDOW_WIDE beside the wide label: PriceWindow draws it, painted
## paper here so a dimmed window fades to paper): two paper boxes framed by the face
## itself, one art px of the family's colours round each (the light row over them, the light
## column left, the shade column right, the face between them and under them; the user's play
## test of 2026-11-03: "badge and price sections should still have a border ... with family
## color"). A split ticket's frame follows its stair, so the window's frame is the second family's
## from the stair on. Under them, the rule plate (PLATE): cream with a cream-shade top
## row and left column. Built from the data's colours (no PNG per family), each look once (a cache
## by its colours and its label).

const ART_SIZE := Vector2i(54, 38)
const SPLIT_SUM := 41
## The icon label (art px), paper; the face's column between it and the window is at LABEL.end.x.
const LABEL := Rect2i(2, 2, 21, 11)
## A third icon's room: the label reaches 10 art px further (an icon's step), the window starts
## after it, one face column between them, and keeps its right edge.
const LABEL_WIDE := Rect2i(2, 2, 31, 11)
## The price window (art px, PriceWindow's rect at 2x), paper; the face's row under it is at
## WINDOW.end.y.
const WINDOW := Rect2i(24, 2, 28, 11)
const WINDOW_WIDE := Rect2i(34, 2, 18, 11)
## The rule plate (art px), the face's row over it at its top - 1.
const PLATE := Rect2i(3, 14, 48, 22)

static var _cache: Dictionary[String, ImageTexture] = {}


## The face of a ticket in `families` (one, or two for a split), perforated for a `coupon`, with the
## wide label for three icons (`wide`).
static func texture(families: Array[FamilyStyle], coupon: bool, wide: bool = false) -> Texture2D:
	var key: String = ("c" if coupon else "p") + ("w" if wide else "s")
	for family: FamilyStyle in families:
		key += "|%s%s%s" % [family.face.to_html(), family.light.to_html(), family.shade.to_html()]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(image(families, coupon, wide))
	return _cache[key]


## The icon label's rect (art px) on a ticket, wide (three icons) or not.
static func label_rect(wide: bool) -> Rect2i:
	return LABEL_WIDE if wide else LABEL


## The price window's rect (art px) on a ticket, beside the wide label or not.
static func window_rect(wide: bool) -> Rect2i:
	return WINDOW_WIDE if wide else WINDOW


## The face's art (see the class comment). Pure.
static func image(families: Array[FamilyStyle], coupon: bool, wide: bool = false) -> Image:
	var art: Vector2i = ART_SIZE
	var out: Image = Image.create_empty(art.x, art.y, false, Image.FORMAT_RGBA8)
	var split: bool = families.size() > 1
	var right: int = art.x - 1
	var bottom: int = art.y - 1
	for y: int in art.y:
		var inset: int = 2 if y == 0 or y == bottom else (1 if y == 1 or y == bottom - 1 else 0)
		for x: int in range(inset, art.x - inset):
			if x == inset or x == right - inset or y == 0 or y == bottom:
				_put(out, x, y, ArtStyle.INK)
				continue
			var family: FamilyStyle = families[1 if split and x + y > SPLIT_SUM else 0]
			var colour: Color = family.face
			if y == 1 or x == 1:
				colour = family.light
			elif y == bottom - 1 or x == right - 1:
				colour = family.shade
			if split and x + y == SPLIT_SUM + 1 and y > 1 and y < bottom - 1 and x < right - 1:
				colour = families[1].light
			if coupon and y == bottom - 1 and x >= 3 and x < right - 2 and x % 3 != 2:
				colour = Palette.PAPER
			_put(out, x, y, colour)
	_paint_zones(out, wide)
	return out


static func _paint_zones(out: Image, wide: bool) -> void:
	# The face round the two paper boxes is their frame.
	_fill(out, label_rect(wide), Palette.PAPER)
	_fill(out, window_rect(wide), Palette.PAPER)
	var plate: Rect2i = PLATE
	_fill(out, plate, Palette.CREAM)
	_fill(out, Rect2i(plate.position, Vector2i(plate.size.x, 1)), Palette.CREAM_SHADE)
	_fill(out, Rect2i(plate.position, Vector2i(1, plate.size.y)), Palette.CREAM_SHADE)


static func _fill(out: Image, rect: Rect2i, colour: Color) -> void:
	for y: int in range(rect.position.y, rect.end.y):
		for x: int in range(rect.position.x, rect.end.x):
			_put(out, x, y, colour)


## Writes `colour` at (x, y), each channel rounded to 8 bits (Image.set_pixel truncates, a step
## darker than the data's colour).
static func _put(out: Image, x: int, y: int, colour: Color) -> void:
	out.set_pixel(
		x,
		y,
		Color8(
			roundi(colour.r * 255.0),
			roundi(colour.g * 255.0),
			roundi(colour.b * 255.0),
			roundi(colour.a * 255.0)
		)
	)
