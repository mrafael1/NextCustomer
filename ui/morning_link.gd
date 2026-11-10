class_name MorningLink
extends MorningMark
## A stretch of the MORNING's chain on the belt (v1.24, the user's note of 2026-11-10: "it should
## show the morning condition (having the item on the 1st slot and continuity, like banana)";
## KeywordMarks): the CHAIN's language at the pins' size, along the line from the anchor post
## (MorningPin.post) at the row's start through every pin of the MORNING, which draw over it.
## Under the tickets a cord (CORD: ink, face and ink, as the CHAIN's ring bands) runs along their
## feet; across each gap between two tickets (`gaps`: their middles) it goes through a ring like
## ChainFrame's links at the pins' size (RING: a BAND of ink and a BAND of face round an open
## hole, stepped corners, the face's top row light; the CHAIN's jump ring, which bridges a narrow
## gap alone), the cord hooked on its sides. Nothing of it is drawn outside its rect (RING.y
## tall): a stretch a hanging mark cuts ends short of it, as if the chain ran on behind the mark.

const RING := Vector2(24, 14)
const BAND := 2.0
const CORD := 6.0

## The middles of the gaps between tickets it crosses (this link's coordinates).
var gaps: PackedFloat32Array = PackedFloat32Array()


func _init() -> void:
	super()
	size = RING


## Sets the stretch `width` long, crossing the gaps between tickets at `gap_middles` (this link's
## coordinates: KeywordMarks passes the ones inside it).
func set_stretch(width: float, gap_middles: PackedFloat32Array) -> void:
	size = Vector2(width, RING.y)
	gaps = gap_middles
	queue_redraw()


## The rings' rects (this link's coordinates), one for each gap, in order (partly outside its rect
## when a cut is near).
func ring_rects() -> Array[Rect2]:
	var rects: Array[Rect2] = []
	for middle: float in gaps:
		var left: float = snappedf(middle - RING.x / 2.0, BAND)
		rects.append(Rect2(Vector2(left, 0.0), RING))
	return rects


func _draw() -> void:
	var rings: Array[Rect2] = ring_rects()
	# The cord, broken where a ring hangs (hooked on its sides).
	var cord_top: float = (RING.y - CORD) / 2.0
	var from: float = 0.0
	var pieces: Array[Vector2] = []
	for ring: Rect2 in rings:
		pieces.append(Vector2(from, ring.position.x + BAND))
		from = maxf(from, ring.end.x - BAND)
	pieces.append(Vector2(from, size.x))
	for piece: Vector2 in pieces:
		if piece.y <= piece.x:
			continue
		var width: float = piece.y - piece.x
		_clipped(Rect2(piece.x, cord_top, width, CORD), Palette.INK)
		_clipped(Rect2(piece.x, cord_top + BAND, width, CORD - BAND * 2.0), face_color())
	for ring: Rect2 in rings:
		_ring(ring)


## A ring at `rect`: the ink band with its corners cut, then the face band inside it, its top row
## light.
func _ring(rect: Rect2) -> void:
	var x: float = rect.position.x
	var w: float = rect.size.x
	var h: float = rect.size.y
	var b: float = BAND
	_clipped(Rect2(x + b, 0, w - b * 2.0, b), Palette.INK)
	_clipped(Rect2(x + b, h - b, w - b * 2.0, b), Palette.INK)
	_clipped(Rect2(x, b, b, h - b * 2.0), Palette.INK)
	_clipped(Rect2(x + w - b, b, b, h - b * 2.0), Palette.INK)
	_clipped(Rect2(x + b, b, w - b * 2.0, b), light_color())
	_clipped(Rect2(x + b, h - b * 2.0, w - b * 2.0, b), face_color())
	_clipped(Rect2(x + b, b * 2.0, b, h - b * 4.0), face_color())
	_clipped(Rect2(x + w - b * 2.0, b * 2.0, b, h - b * 4.0), face_color())


## Draws the part of `rect` inside the link's rect.
func _clipped(rect: Rect2, colour: Color) -> void:
	var shown: Rect2 = rect.intersection(Rect2(Vector2.ZERO, size))
	if shown.has_area():
		draw_rect(shown, colour)
