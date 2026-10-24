class_name TicketFace
extends RefCounted
## A full-colour ticket's face (#105, mock-up readability v3, frame3URL): 54x32 art, shown at 2x
## (PriceSticker.SIZE), in the colours of the family the card works with (FamilyStyle, data). An ink
## outline with its four corner pixels cut; the top row in the family's light colour, the right
## column and the bottom row in its shade, the rest its face. A split ticket (two families) is a
## 45° pixel stair: a pixel past SPLIT_SUM takes the second family, and the stair's seam (x + y ==
## SPLIT_SUM + 1) is the second family's light colour. A family coupon's top two rows are
## perforated in its shade and light. Built from the data's colours (no PNG per family), each look
## once (a cache by its colours).

const ART_SIZE := Vector2i(54, 32)
const SPLIT_SUM := 41

static var _cache: Dictionary[String, ImageTexture] = {}


## The face of a ticket in `families` (one, or two for a split), perforated for a `coupon`.
static func texture(families: Array[FamilyStyle], coupon: bool) -> Texture2D:
	var key: String = "c" if coupon else "p"
	for family: FamilyStyle in families:
		key += "|%s%s%s" % [family.face.to_html(), family.light.to_html(), family.shade.to_html()]
	if not _cache.has(key):
		_cache[key] = ImageTexture.create_from_image(image(families, coupon))
	return _cache[key]


## The face's art (see the class comment). Pure.
static func image(families: Array[FamilyStyle], coupon: bool) -> Image:
	var bytes: PackedByteArray = PackedByteArray()
	bytes.resize(ART_SIZE.x * ART_SIZE.y * 4)
	var split: bool = families.size() > 1
	var right: int = ART_SIZE.x - 1
	var bottom: int = ART_SIZE.y - 1
	for y: int in ART_SIZE.y:
		for x: int in ART_SIZE.x:
			var edge_x: bool = x == 0 or x == right
			var edge_y: bool = y == 0 or y == bottom
			if edge_x and edge_y:
				continue
			if edge_x or edge_y:
				_put(bytes, x, y, ArtStyle.INK)
				continue
			var family: FamilyStyle = families[1 if split and x + y > SPLIT_SUM else 0]
			var colour: Color = family.face
			if y == 1:
				colour = family.light
			elif y == bottom - 1 or x == right - 1:
				colour = family.shade
			if split and x + y == SPLIT_SUM + 1 and y > 1 and y < bottom - 1 and x < right - 1:
				colour = families[1].light
			if coupon and (y == 1 or y == 2):
				colour = family.shade if (x - 1) % 3 < 2 else family.light
			_put(bytes, x, y, colour)
	return Image.create_from_data(ART_SIZE.x, ART_SIZE.y, false, Image.FORMAT_RGBA8, bytes)


## Writes `colour` at (x, y), each channel rounded to 8 bits (Image.set_pixel truncates, a step
## darker than the data's colour).
static func _put(bytes: PackedByteArray, x: int, y: int, colour: Color) -> void:
	var at: int = (y * ART_SIZE.x + x) * 4
	bytes[at] = roundi(colour.r * 255.0)
	bytes[at + 1] = roundi(colour.g * 255.0)
	bytes[at + 2] = roundi(colour.b * 255.0)
	bytes[at + 3] = roundi(colour.a * 255.0)
