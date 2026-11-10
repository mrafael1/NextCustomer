class_name MedalFlyer
extends Control
## A week medal in flight (MedalFlight): the medal case's medal (MedalArt.draw_medal, v1.17) on
## its art grid, as big as the rect it is placed in. Display only.

var gold: bool = false


func _init(medal_gold: bool) -> void:
	name = "MedalFlyer"
	gold = medal_gold
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Puts the coin in `rect` (its layer's coordinates).
func place(rect: Rect2) -> void:
	position = rect.position
	size = rect.size
	queue_redraw()


func _draw() -> void:
	MedalArt.draw_medal(self, Vector2.ZERO, MedalArt.SIZE, size.x / MedalArt.SIZE, gold)
