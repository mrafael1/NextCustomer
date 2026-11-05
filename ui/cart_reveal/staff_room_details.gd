class_name StaffRoomDetails
extends Control
## Small staff-room drawings live on their own canvas: the dial, or lanyard and trolley.

var is_clock: bool = false


func _init(clock: bool = false) -> void:
	is_clock = clock
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(30, 30) if clock else Vector2(1280, 720)


func _draw() -> void:
	if is_clock:
		draw_circle(Vector2(15, 15), 15.0, Palette.INK)
		draw_circle(Vector2(15, 15), 13.0, Palette.MUSTARD_LIGHT)
		draw_circle(Vector2(15, 15), 11.0, Palette.PAPER)
		draw_line(Vector2(15, 15), Vector2(15, 6), Palette.INK, 2.0)
		draw_line(Vector2(15, 15), Vector2(8, 15), Palette.INK, 2.0)
		draw_line(Vector2(15, 15), Vector2(20, 20), Palette.TOMATO, 2.0)
		return
	draw_rect(Rect2(140, 152, 18, 6), Palette.BRASS)
	draw_line(Vector2(146, 158), Vector2(130, 180), Palette.TEAL_LIGHT, 4.0)
	draw_line(Vector2(150, 158), Vector2(170, 180), Palette.TEAL_LIGHT, 4.0)
	draw_rect(Rect2(270, 600, 568, 60), Palette.RUBBER_DARK)
	for x: int in range(272, 838, 6):
		draw_line(Vector2(x, 608), Vector2(x, 660), Palette.STEEL_DARK, 2.0)
	for y: int in range(608, 662, 6):
		draw_line(Vector2(272, y), Vector2(840 - (y - 608) * 0.4, y), Palette.STEEL_DARK, 2.0)
	draw_rect(Rect2(268, 632, 574, 4), Palette.STEEL_LIGHT)
	draw_rect(Rect2(276, 658, 540, 4), Palette.STEEL)
	draw_circle(Vector2(302, 670), 8.0, Palette.INK)
	draw_circle(Vector2(806, 670), 8.0, Palette.INK)
	draw_circle(Vector2(302, 670), 4.0, Palette.STEEL)
	draw_circle(Vector2(806, 670), 4.0, Palette.STEEL)
