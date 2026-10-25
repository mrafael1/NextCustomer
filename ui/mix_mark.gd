class_name MixMark
extends Control
## The mix highlight's mark on an item (#105 piece 3, mock-up readability v3 section 4, option A),
## drawn over its art and never greyed: FAINT a 2 px dashed outline in mustard light (FAINT_ALPHA)
## `inset` (INSET by default) into the item's bracket box `box`, over the grey (a match that comes
## only from a broad family, "×2 next Food"); NOW the count's green check
## (EffectSticker.CHECK_CELLS, ink outlined) at the box's top right (a pair that pays in the current
## order); PENALTY a tomato tile with an ink ring and a paper "!" there, on a drop shadow (a pair
## that zeroes one of them). Every other look draws nothing. It takes no clicks.

const INSET := 4.0
const LINE := 2.0
const DASH := 6.0
const GAP := 4.0
const FAINT_ALPHA := 0.6
## The check (18x16) and the "!" tile (16x18), from the box's top right corner.
const CHECK_AT := Vector2(-22, 2)
const PENALTY_AT := Vector2(-20, 2)
const PENALTY_SIZE := Vector2(16, 18)
const RING := 2.0
const BANG := "!"
const BANG_SIZE := 14
const BANG_WEIGHT := 800
const SHADOW := Vector2(2, 2)
const SHADOW_ALPHA := 0.35

var look: MixModel.Look = MixModel.Look.NONE
## The item's bracket box (the parent's coordinates: this mark covers its parent at (0, 0)).
var box: Rect2 = Rect2()
## How far inside the box the faint outline runs (0 on a box that already hugs the art).
var inset: float = INSET


func _init() -> void:
	name = "MixMark"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Shows `shown` for the bracket box `bracket_box`, a faint outline `outline_inset` inside it.
func show_look(shown: MixModel.Look, bracket_box: Rect2, outline_inset: float = INSET) -> void:
	look = shown
	box = bracket_box
	inset = outline_inset
	visible = shown in [MixModel.Look.FAINT, MixModel.Look.NOW, MixModel.Look.PENALTY]
	queue_redraw()


## The faint outline's rect (inside the box), the check's or the tile's, or an empty rect when
## the look draws none (this mark's coordinates).
func mark_rect() -> Rect2:
	match look:
		MixModel.Look.FAINT:
			return box.grow(-inset)
		MixModel.Look.NOW:
			return Rect2(Vector2(box.end.x, box.position.y) + CHECK_AT, EffectSticker.CHECK_SIZE)
		MixModel.Look.PENALTY:
			return Rect2(Vector2(box.end.x, box.position.y) + PENALTY_AT, PENALTY_SIZE)
	return Rect2()


func _draw() -> void:
	var rect: Rect2 = mark_rect()
	match look:
		MixModel.Look.FAINT:
			draw_dashed_rect(self, rect, Color(Palette.MUSTARD_LIGHT, FAINT_ALPHA))
		MixModel.Look.NOW:
			_draw_check(rect.position, Palette.INK, true)
			_draw_check(rect.position, Palette.GOOD, false)
		MixModel.Look.PENALTY:
			draw_rect(
				Rect2(rect.position + SHADOW, rect.size).grow(RING),
				Color(Palette.INK, SHADOW_ALPHA)
			)
			draw_rect(rect.grow(RING), Palette.INK)
			draw_rect(rect, Palette.TOMATO)
			var font: Font = ArtStyle.bold_font(BANG_WEIGHT)
			var ascent: float = font.get_ascent(BANG_SIZE)
			var descent: float = font.get_descent(BANG_SIZE)
			var baseline: float = rect.position.y + (rect.size.y + ascent - descent) / 2.0
			draw_string(
				font,
				Vector2(rect.position.x, roundf(baseline)),
				BANG,
				HORIZONTAL_ALIGNMENT_CENTER,
				rect.size.x,
				BANG_SIZE,
				Palette.PAPER
			)


## Draws `rect`'s outline on `canvas` in LINE px dashes, DASH long and GAP apart, on the 2 px grid.
static func draw_dashed_rect(canvas: CanvasItem, rect: Rect2, colour: Color) -> void:
	var edges: Array[Rect2] = [
		Rect2(rect.position, Vector2(rect.size.x, LINE)),
		Rect2(rect.position.x, rect.end.y - LINE, rect.size.x, LINE),
		Rect2(rect.position, Vector2(LINE, rect.size.y)),
		Rect2(rect.end.x - LINE, rect.position.y, LINE, rect.size.y),
	]
	for edge: Rect2 in edges:
		var across: bool = edge.size.x > edge.size.y
		var length: float = edge.size.x if across else edge.size.y
		var at: float = 0.0
		while at < length:
			var run: float = minf(DASH, length - at)
			var dash: Rect2 = (
				Rect2(edge.position + Vector2(at, 0), Vector2(run, LINE))
				if across
				else Rect2(edge.position + Vector2(0, at), Vector2(LINE, run))
			)
			canvas.draw_rect(dash, colour)
			at += DASH + GAP


## The check's cells at `origin`: grown one cell (its ink outline) when `outline`.
func _draw_check(origin: Vector2, colour: Color, outline: bool) -> void:
	var cell: float = ArtStyle.ART_SCALE
	for at: Vector2i in EffectSticker.CHECK_CELLS:
		var rect: Rect2 = Rect2(origin + Vector2(at) * cell, Vector2(cell, cell))
		draw_rect(rect.grow(cell if outline else 0.0), colour)
