class_name MorningRibbon
extends Control
## The MORNING's ribbon on the belt (v1.06, KeywordMarks): a band HEIGHT tall under the MORNING
## tickets, BORDER of ink round the Breakfast mustard light (the MORNING chip's calm face) with a
## mustard pale light row along its top and a mustard row along its foot; on its left end the
## rising sun (art/icons/morning_sun.png at 2x: a tomato light disc and mustard dark rays, so it
## reads on the mustard face; its horizon on the band's foot) and the MORNING chip (KeywordChip:
## its tooltip, and right-click opens the handbook at MORNING). A ribbon too short for the chip
## shows the sun only.
##
## The marks that hang in the same band under the tickets (a slot's SlotMark, a chain's knot
## plate) cut it (set_width's `cuts`): the ribbon stops CUT_GAP short of each and starts again
## after it, each piece closed in ink, so it never covers them; the sun and the chip sit on the
## first piece they fit. Decor only: it takes no clicks.

const HEIGHT := 22.0
const BORDER := 2.0
const LIGHT_ROW := 2.0
const SUN := preload("res://art/icons/morning_sun.png")
const SUN_SIZE := Vector2(38, 20)
## The sun's left in from its piece's, and the chip's gap after the sun.
const SUN_LEFT := 4.0
const CHIP_GAP := 4.0
## The room left on each side of a cut, and the shortest piece drawn.
const CUT_GAP := 2.0
const MIN_PIECE := 12.0
const FACE := Palette.MUSTARD_LIGHT
const LIGHT := Palette.MUSTARD_PALE
const SHADE := Palette.MUSTARD

var _sun: TextureRect
var _chip: KeywordChip
## The pieces drawn (this control's coordinates), left to right.
var _pieces: Array[Rect2] = []


func _init() -> void:
	name = "MorningRibbon"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sun = UiKit.sprite(SUN)
	_sun.name = "Sun"
	_sun.size = SUN_SIZE
	add_child(_sun)
	_chip = KeywordChip.new(CardText.MORNING_WORD)
	add_child(_chip)
	set_width(SUN_SIZE.x + SUN_LEFT * 2.0)


## Sets the ribbon's width (the MORNING's tickets') and its `cuts` (x ranges in its coordinates:
## the marks it leaves open, each CUT_GAP wider on both sides); the sun and the chip go on the
## first piece they fit, the chip only when it fits there too.
func set_width(width: float, cuts: Array[Vector2] = []) -> void:
	size = Vector2(maxf(width, SUN_SIZE.x + SUN_LEFT * 2.0), HEIGHT)
	_pieces = pieces_of(size.x, cuts)
	_sun.visible = false
	_chip.visible = false
	for piece: Rect2 in _pieces:
		if piece.size.x < SUN_SIZE.x + SUN_LEFT * 2.0:
			continue
		_sun.visible = true
		_sun.position = Vector2(piece.position.x + SUN_LEFT, HEIGHT - BORDER - SUN_SIZE.y)
		_chip.position = Vector2(
			_sun.position.x + SUN_SIZE.x + CHIP_GAP, roundf((HEIGHT - KeywordChip.HEIGHT) / 2.0)
		)
		_chip.visible = _chip.position.x + _chip.size.x + BORDER * 2.0 <= piece.end.x
		break
	queue_redraw()


## The pieces of a ribbon `width` wide with `cuts` (x ranges) left open: what is left of it,
## each cut grown by CUT_GAP, rounded to the art grid, pieces under MIN_PIECE dropped.
static func pieces_of(width: float, cuts: Array[Vector2]) -> Array[Rect2]:
	var sorted: Array[Vector2] = cuts.duplicate()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var cut_up: Array[Rect2] = []
	var from: float = 0.0
	for cut: Vector2 in sorted:
		var stop: float = floorf((cut.x - CUT_GAP) / ArtStyle.ART_SCALE) * ArtStyle.ART_SCALE
		if stop - from >= MIN_PIECE:
			cut_up.append(Rect2(from, 0.0, minf(stop, width) - from, HEIGHT))
		from = maxf(from, ceilf((cut.y + CUT_GAP) / ArtStyle.ART_SCALE) * ArtStyle.ART_SCALE)
		if from >= width:
			break
	if width - from >= MIN_PIECE:
		cut_up.append(Rect2(from, 0.0, width - from, HEIGHT))
	return cut_up


func sun() -> TextureRect:
	return _sun


func chip() -> KeywordChip:
	return _chip


## The pieces drawn (this control's coordinates), left to right.
func pieces() -> Array[Rect2]:
	return _pieces.duplicate()


func _draw() -> void:
	for rect: Rect2 in _pieces:
		draw_rect(rect, Palette.INK)
		var face: Rect2 = rect.grow(-BORDER)
		draw_rect(face, FACE)
		draw_rect(Rect2(face.position, Vector2(face.size.x, LIGHT_ROW)), LIGHT)
		var foot: Vector2 = Vector2(face.position.x, face.end.y - LIGHT_ROW)
		draw_rect(Rect2(foot, Vector2(face.size.x, LIGHT_ROW)), SHADE)
