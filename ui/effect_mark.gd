class_name EffectMark
extends Control
## A belt item's corner mark (#80, step 7; mock-up B2): one pixel disc on the sprite's visible
## top-right corner, a tomato fizzle disc when one of the item's steps that EffectChip.qualifies
## fizzled, else a green check for a bonus or factor another source gave it. One per item, no
## count. The disc is pixel art (13x13 @2); its one texel hard shadow is drawn here in ink at
## SHADOW_ALPHA. Decor only: it takes no clicks. ItemView places it (corner()); BeltChips shows
## and pops it.

## The disc and its shadow: 14x14 texels at 2x.
const SIZE := Vector2(28, 28)
const DISC_TEXELS := 13
## The disc's middle texel and radius, in texels (mock-up B2's pxDisc).
const DISC_MIDDLE := 6
const DISC_RADIUS := 6.4
const SHADOW_ALPHA := 0.35
## From the sprite's visible top-right corner to the mark's top-left (mock-up B2's markOn): 14 px
## over the art's top, 4 px past its right edge (the disc is 26 px wide).
const CORNER_OFFSET := Vector2(-22, -14)
## A landed mark pops in from this scale to 1 over POP_TIME (none under reduced motion).
const POP_SCALE := 1.3
const POP_TIME := 0.18

const FIZZLE_DISC := preload("res://art/icons/mark_fizzle.png")
const CHECK_DISC := preload("res://art/icons/mark_check.png")

var _fizzle: bool = false
var _disc: TextureRect


func _init(fizzle: bool = false) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	custom_minimum_size = SIZE
	pivot_offset = SIZE / 2.0
	_disc = UiKit.sprite(CHECK_DISC)
	_disc.size = Vector2(DISC_TEXELS, DISC_TEXELS) * ArtStyle.ART_SCALE
	add_child(_disc)
	set_fizzle(fizzle)


## The disc's hard shadow: the disc one texel down and right, where the disc itself is not.
func _draw() -> void:
	var pixel: float = ArtStyle.ART_SCALE
	var colour: Color = Color(Palette.INK, SHADOW_ALPHA)
	for row: int in range(DISC_TEXELS + 1):
		for column: int in range(DISC_TEXELS + 1):
			if not in_disc(column, row) and in_disc(column - 1, row - 1):
				draw_rect(Rect2(Vector2(column, row) * pixel, Vector2(pixel, pixel)), colour)


func set_fizzle(fizzle: bool) -> void:
	_fizzle = fizzle
	_disc.texture = FIZZLE_DISC if fizzle else CHECK_DISC


func is_fizzle() -> bool:
	return _fizzle


func disc() -> TextureRect:
	return _disc


## Pops the mark in from POP_SCALE, unless `reduced_motion`.
func pop(reduced_motion: bool) -> void:
	scale = Vector2.ONE
	if reduced_motion:
		return
	scale = Vector2(POP_SCALE, POP_SCALE)
	var tween: Tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, POP_TIME)


## Whether texel (`column`, `row`) is inside the 13x13 disc (the art's circle, mock-up B2).
static func in_disc(column: int, row: int) -> bool:
	if column < 0 or row < 0 or column >= DISC_TEXELS or row >= DISC_TEXELS:
		return false
	var offset: Vector2 = Vector2(column - DISC_MIDDLE, row - DISC_MIDDLE)
	return offset.length_squared() <= DISC_RADIUS * DISC_RADIUS


## The mark's top-left for a sprite drawn as `texture` in `sprite_rect` (any coordinates): on the
## art's visible top-right corner, on the 2 px grid.
static func corner(texture: Texture2D, sprite_rect: Rect2) -> Vector2:
	var box: Rect2i = ContactShadow.opaque_rect(texture)
	var texel: Vector2 = sprite_rect.size / Vector2(texture.get_size())
	var top_right: Vector2 = sprite_rect.position + Vector2(box.end.x, box.position.y) * texel
	return (top_right + CORNER_OFFSET).snappedf(ArtStyle.ART_SCALE)
