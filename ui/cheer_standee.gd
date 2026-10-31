class_name CheerStandee
extends Control
## One cardboard promo standee of the checkout cheering (#120, CheckoutCrowd): a pixel-art figure
## (art/standees/) at an integer scale that stands up behind the counter, its feet and easel
## hidden under the crowd's foot line. Its pose is three numbers the crowd's tweens move: `level`
## (0 out of sight under the foot line, 1 standing), `hop` (pixels up) and `fold` (1 upright, 0
## folded flat onto its foot). Every pose lands on the 2 px art grid, and the ink never rises
## above `min_top` (the crowd's limit under the monitor). It takes no clicks.

## The art grid every position snaps to.
const GRID := 2.0

## How hard the payout that popped it cheered (CountUpBeat.cheer_tier).
var tier: int = 1
## The art's integer scale.
var art_scale: int = 2
## Its single tween (CheckoutCrowd kills and replaces it, never stacks one), or null.
var tween: Tween
## While its pop (the rise and its own hop) runs: a crowd-wide hop leaves it alone.
var popping: bool = false
## The art pixels both frames cover (the cheer frame's raised arms included), in art px.
var ink: Rect2 = Rect2()
## Local y (in the crowd) of the art's top when standing (`level` 1) and out of sight (0).
var up_y: float = 0.0
var down_y: float = 0.0
## The crowd's foot line (its local y): the fold pivots on it.
var foot_y: float = 0.0
## The ink's top never goes above this crowd-local y (-INF: no limit).
var min_top: float = -INF
var level: float = 0.0:
	set(value):
		level = value
		_apply()
var hop: float = 0.0:
	set(value):
		hop = value
		_apply()
var fold: float = 1.0:
	set(value):
		fold = value
		_apply()
## Degrees it leans about its foot (a missed verdict's wilt), 0 upright.
var lean: float = 0.0:
	set(value):
		lean = value
		_apply()
var _rest: Texture2D
var _cheer: Texture2D
var _sprite: TextureRect


## A standee of the frames `rest` and `cheer` at `scale_factor` for a payout of `cheer_tier`.
func _init(rest: Texture2D, cheer: Texture2D, scale_factor: int, cheer_tier: int) -> void:
	name = "Standee"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rest = rest
	_cheer = cheer
	art_scale = scale_factor
	tier = cheer_tier
	ink = Rect2(rest.get_image().get_used_rect()).merge(Rect2(cheer.get_image().get_used_rect()))
	size = rest.get_size() * art_scale
	_sprite = UiKit.sprite(rest)
	_sprite.name = "Art"
	_sprite.size = size
	add_child(_sprite)


## Shows the arms-up cheer frame, or the rest frame.
func set_cheering(on: bool) -> void:
	_sprite.texture = _cheer if on else _rest


func is_cheering() -> bool:
	return _sprite.texture == _cheer


## The ink's rect in the crowd at the current pose, cut at the foot line (what can show).
func visible_rect() -> Rect2:
	# The fold scales about the foot line (pivot_offset).
	var top: float = foot_y + (position.y + ink.position.y * art_scale - foot_y) * scale.y
	var bottom: float = minf(
		foot_y, foot_y + (position.y + ink.end.y * art_scale - foot_y) * scale.y
	)
	var left: float = position.x + ink.position.x * art_scale
	return Rect2(left, top, ink.size.x * art_scale, maxf(0.0, bottom - top))


## Stops its tween, if any.
func stop() -> void:
	if tween != null and tween.is_valid():
		tween.kill()
	tween = null
	popping = false


## Its pop has run (a tween callback).
func end_pop() -> void:
	popping = false


func _apply() -> void:
	var y: float = lerpf(down_y, up_y, level) - hop
	var ink_top: float = ink.position.y * art_scale
	if y + ink_top < min_top:
		y = min_top - ink_top
	position.y = ceilf(y / GRID) * GRID
	pivot_offset = Vector2(0.0, foot_y - position.y)
	scale = Vector2(1.0, clampf(fold, 0.0, 1.0))
	pivot_offset.x = size.x / 2.0
	rotation = deg_to_rad(lean)
