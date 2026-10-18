class_name ArtOutline
extends RefCounted
## A selected hand item's outline (#80, mock-up B2, step 8): an art's silhouette grown by one
## pixel all round, in COLOUR, with the art's own pixels left clear, on a canvas one pixel larger
## on each side. ItemView draws it behind a selected basket item's sprite, at the sprite's scale,
## so it is one art pixel wide. Built from the art's image once and cached per art.

const COLOUR := Palette.MUSTARD
## A pixel this opaque or more is part of the silhouette.
const OPAQUE_ALPHA := 0.5

static var _textures: Dictionary[Texture2D, ImageTexture] = {}


## `art`'s outline texture (cached).
static func texture_for(art: Texture2D) -> ImageTexture:
	if _textures.has(art):
		return _textures[art]
	var image: Image = art.get_image()
	if image.is_compressed():
		image.decompress()
	var width: int = image.get_width()
	var height: int = image.get_height()
	var result: Image = Image.create_empty(width + 2, height + 2, false, Image.FORMAT_RGBA8)
	var sides: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for y: int in range(height + 2):
		for x: int in range(width + 2):
			if _opaque(image, x - 1, y - 1):
				continue
			for side: Vector2i in sides:
				if _opaque(image, x - 1 + side.x, y - 1 + side.y):
					result.set_pixel(x, y, COLOUR)
					break
	var texture: ImageTexture = ImageTexture.create_from_image(result)
	_textures[art] = texture
	return texture


static func _opaque(image: Image, x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return false
	return image.get_pixel(x, y).a >= OPAQUE_ALPHA
