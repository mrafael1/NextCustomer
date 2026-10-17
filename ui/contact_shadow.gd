class_name ContactShadow
extends Control
## A contact shadow (#80, mock-up B2, step 6): one stepped pixel ellipse filling the node's rect
## on the 2 px art grid, in one flat colour with hard edges (ink at `alpha`), so whatever stands
## on the belt is grounded. The light comes from the top left, so callers put it a little right
## of what casts it. ItemView draws its own with draw_on(); the CLOSED cell's stanchions use this
## node. Decor only: it takes no clicks.

## A shadow's ink alpha (mock-up B2's contact shadows).
const ALPHA := 0.5

## Each texture's opaque box, in its own pixels (see opaque_rect).
static var _boxes: Dictionary[Texture2D, Rect2i] = {}

## The ink alpha this node's shadow is drawn at.
var alpha: float = ALPHA


func _init(shadow_alpha: float = ALPHA) -> void:
	alpha = shadow_alpha
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	draw_on(self, Rect2(Vector2.ZERO, size), alpha)


## Draws a stepped ellipse filling `rect` (`canvas`'s coordinates) at ink `shadow_alpha`: rows
## of whole art pixels, each as wide as the ellipse is at that row's middle.
static func draw_on(canvas: CanvasItem, rect: Rect2, shadow_alpha: float) -> void:
	var pixel: float = ArtStyle.ART_SCALE
	var columns: int = maxi(roundi(rect.size.x / pixel), 1)
	var rows: int = maxi(roundi(rect.size.y / pixel), 1)
	var colour: Color = Color(Palette.INK, shadow_alpha)
	for row: int in range(rows):
		var height: float = (row + 0.5 - rows / 2.0) / (rows / 2.0)
		var reach: float = sqrt(maxf(1.0 - height * height, 0.0)) * columns / 2.0
		# The pixels whose middles lie inside the ellipse on this row.
		var first: int = ceili(columns / 2.0 - reach - 0.5)
		var last: int = floori(columns / 2.0 + reach - 0.5)
		if last < first:
			continue
		var start: Vector2 = rect.position + Vector2(first * pixel, row * pixel)
		canvas.draw_rect(Rect2(start, Vector2((last - first + 1) * pixel, pixel)), colour)


## The row under `texture`'s lowest opaque pixel, in the texture's pixels (its height when it
## has none): where a sprite's art meets the ground.
static func opaque_bottom(texture: Texture2D) -> int:
	return opaque_rect(texture).end.y


## `texture`'s opaque box (Image.get_used_rect), in the texture's pixels: the whole texture when
## it has no opaque pixel or no image. Cached per texture. The belt items' marks and paid chips
## stand on its top (#80, step 7).
static func opaque_rect(texture: Texture2D) -> Rect2i:
	if not _boxes.has(texture):
		var image: Image = texture.get_image()
		var used: Rect2i = image.get_used_rect() if image != null else Rect2i()
		if used.size.x <= 0 or used.size.y <= 0:
			used = Rect2i(Vector2i.ZERO, Vector2i(texture.get_width(), texture.get_height()))
		_boxes[texture] = used
	return _boxes[texture]
