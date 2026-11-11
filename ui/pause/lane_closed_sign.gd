class_name LaneClosedSign
extends Control
## The pause's LANE CLOSED sign (mock-up options_pause.html, direction A): a tomato board in a
## gold trim with the padlock and BACK IN A MOMENT, hung on two steel rods drawn in code like the
## aisle signs'. It drops in and settles in two swings over DROP_FRAMES' length (still under
## reduced motion). On SAVE & QUIT it flips to SAVED.

## The drop: the board's offset per frame (y, then x swings), each FRAME_TIME long.
const DROP_DY: Array[float] = [-330, -240, -150, -60, 10, 4, -4, -2, 2, 0, 0, 0]
const DROP_DX: Array[float] = [0, 0, 0, 0, 0, 4, 4, -2, -4, -2, 2, 0]
const FRAME_TIME := 0.046
const PADLOCK := preload("res://art/icons/padlock.png")
const HEIGHT := 106.0
const ROD_TOP := 64.0
const SUB_CLOSED := "BACK IN A MOMENT"

var _title: Label
var _sub: Label
var _lock: TextureRect
var _frame: int = DROP_DY.size() - 1
var _dropping: Tween
var _saved: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock = UiKit.sprite(PADLOCK)
	_lock.size = Vector2(32, 32)
	add_child(_lock)
	_title = UiKit.pixel_label("LANE CLOSED", 4, Palette.PAPER)
	add_child(_title)
	_sub = UiKit.pixel_label(SUB_CLOSED, 2, Palette.TOMATO_PALE)
	add_child(_sub)
	_layout()


## Drops the sign in (at once when `still`), its closed face showing.
func drop(still: bool) -> void:
	_saved = false
	_title.text = "LANE CLOSED"
	_sub.text = SUB_CLOSED
	_layout()
	if _dropping != null:
		_dropping.kill()
	if still:
		_show_frame(DROP_DY.size() - 1)
		return
	_dropping = create_tween()
	_show_frame(0)
	for i: int in range(1, DROP_DY.size()):
		_dropping.tween_callback(_show_frame.bind(i)).set_delay(FRAME_TIME)


## Flips the board to SAVED (SAVE & QUIT).
func show_saved() -> void:
	_saved = true
	_title.text = "SAVED"
	_sub.text = "SEE YOU SOON"
	_layout()


func is_settled() -> bool:
	return _frame == DROP_DY.size() - 1


func _show_frame(index: int) -> void:
	_frame = index
	position = Vector2(DROP_DX[index], DROP_DY[index]) + _home()
	queue_redraw()


func _home() -> Vector2:
	var parent: Control = get_parent_control()
	if parent == null:
		return Vector2.ZERO
	var centre: float = (parent.size.x + PauseMenu.REGISTER_COLUMN) / 2.0
	var top: float = parent.size.y / 2.0 + PauseMenu.PLATE_TOPS[0] - HEIGHT - 26.0
	return (Vector2(centre - size.x / 2.0, top) / 2.0).round() * 2.0


func _layout() -> void:
	var text_width: float = maxf(
		OptionChip.pixel_width(_title.text, 4), OptionChip.pixel_width(_sub.text, 2)
	)
	size = Vector2(2.0 * ceilf((16 + 32 + 16 + text_width + 24) / 2.0), HEIGHT)
	_lock.position = Vector2(20, 38)
	UiKit.place_pixel_label(_title, Rect2(68, 14, 0, 0))
	UiKit.place_pixel_label(_sub, Rect2(76, 66, 0, 0))
	if is_inside_tree():
		_show_frame(_frame)


func _draw() -> void:
	var w: float = size.x
	# The rods, from the ceiling's rail down to the board's top corners.
	var rod_top: float = ROD_TOP - position.y
	for x: float in [48.0, w - 50.0]:
		draw_rect(Rect2(x, rod_top, 2, -rod_top), Palette.STEEL_DARK)
		draw_rect(Rect2(x + 2, rod_top, 2, -rod_top), Palette.STEEL_LIGHT)
	draw_rect(Rect2(0, 0, w, HEIGHT), Palette.MUSTARD_DARK)
	draw_rect(Rect2(2, 2, w - 4, HEIGHT - 4), Palette.GOLD)
	draw_rect(Rect2(6, 6, w - 12, HEIGHT - 12), Palette.INK)
	var face: Color = Palette.GREEN_DARK if _saved else Palette.TOMATO
	draw_rect(Rect2(8, 8, w - 16, HEIGHT - 16), face)
	draw_rect(Rect2(8, HEIGHT - 14, w - 16, 6), Palette.TOMATO_DARK if not _saved else Palette.INK)
	draw_rect(Rect2(16, 34, 40, 40), Palette.INK)
	draw_rect(Rect2(18, 36, 36, 36), Palette.CREAM)
