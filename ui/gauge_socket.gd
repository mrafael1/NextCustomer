class_name GaugeSocket
extends Control
## The quota gauge's empty socket on the top bar's band (polish batch 2, the audit's
## count-transitions: while the gauge is up out of the bar for the count the band read as an
## empty dark strip). It stands where the gauge rests (TopBar's gauge room, behind GaugePanel),
## a dim recess from the lap lamp's left to the bezel's right end, one art px darker inside a
## faintly lit foot, so it only shows while the gauge has slid away. Decor only: no clicks.

## The recess (ink at RECESS_ALPHA) and its lit foot (steel at LIP_ALPHA, one art px).
const RECESS_ALPHA := 0.32
const LIP_ALPHA := 0.22

var _gauge: GaugePanel


func _init(gauge: GaugePanel) -> void:
	name = "GaugeSocket"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge = gauge
	_gauge.resized.connect(fit)


## The socket's recess in its own coordinates (the gauge's at rest): from the lamp's left to the
## bezel's right end, as tall as the bezel.
func recess_rect() -> Rect2:
	var bezel: Rect2 = _gauge.bezel_rect()
	var left: float = GaugePanel.LAMP_AT.x
	return Rect2(left, bezel.position.y, maxf(bezel.end.x - left, 0.0), bezel.size.y)


## Stands where the gauge rests, as large (TopBar calls it after placing the gauge).
func fit() -> void:
	position = Vector2(_gauge.position.x, _gauge.rest_y())
	size = _gauge.size
	queue_redraw()


func _draw() -> void:
	var recess: Rect2 = recess_rect()
	if recess.size.x <= 2.0 * ArtStyle.ART_SCALE or recess.size.y <= 2.0 * ArtStyle.ART_SCALE:
		return
	var cell: float = ArtStyle.ART_SCALE
	var dim: Color = Color(Palette.INK, RECESS_ALPHA)
	# Its corners cut, as the bezel's: the middle full height, the end columns one art px shorter.
	draw_rect(recess.grow_individual(-cell, 0.0, -cell, 0.0), dim)
	draw_rect(
		Rect2(recess.position + Vector2(0.0, cell), Vector2(cell, recess.size.y - 2.0 * cell)), dim
	)
	draw_rect(
		Rect2(
			Vector2(recess.end.x - cell, recess.position.y + cell),
			Vector2(cell, recess.size.y - 2.0 * cell)
		),
		dim
	)
	var foot: Rect2 = Rect2(
		recess.position + Vector2(cell, recess.size.y - cell),
		Vector2(recess.size.x - 2.0 * cell, cell)
	)
	draw_rect(foot, Color(Palette.STEEL_LIGHT, LIP_ALPHA))
