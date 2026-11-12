class_name ToyReveal
extends Control
## The reveal of a drawn capsule (#63; 2026-11-11 polish, the user's ask): over a shade on the
## TOY MACHINES stage, only the item's icon (its sprite at 2x, 96x96, or its art-pending box with
## the name printed in it), centred at ICON_CENTRE. No medallion, rays, NEW!, name, aisle, stock
## line or OK: the lineup card and the book show those. The icon drops in DROP_ART art px over
## DROP_S, eased, in whole art px (at once when `still`) with the open sound. Then it stays alive
## through the hold (review fix: a second of nothing moving read as slow): it bobs BOB_ART art px
## every BOB_S and sparkles (effects/sparkle) twinkle round it one after another, TWINKLE_S each;
## under reduced motion it stands still.
##
## Nothing dismisses it: the shade takes every click while it is up (the machines, DONE and the
## book can't be pressed), and after HOLD_S seconds it emits `held`, once. The screen then plays
## the join (ToyLineupJoin), which flies the icon into its place on the lineup card and calls
## leave() to take the reveal away.

## The icon has been shown for HOLD_S: the join takes it from here.
signal held

const STAGE := Vector2(1280, 720)
## Where the icon's centre sits on the stage (the join's flight starts here), on the 2 px grid.
const ICON_CENTRE := Vector2(640, 310)
## How long the icon holds alone before the join flies it to the collection (seconds).
const HOLD_S := 1.0
## The drop in: from DROP_ART art px above, eased out over DROP_S seconds (every frame, whole
## art px).
const DROP_ART := 6
const DROP_S := 0.12
## The hold's life: a BOB_ART art px bob every BOB_S, and a sparkle at each of TWINKLE_AT (from the
## icon's centre, canvas px) in turn, each TWINKLE_S on.
const BOB_ART := 1
const BOB_S := 0.25
const SPARKLE := preload("res://art/effects/sparkle.png")
const SPARKLE_SIZE := Vector2(10, 10)
const TWINKLE_AT: Array[Vector2] = [
	Vector2(-58, -38), Vector2(56, -50), Vector2(62, 28), Vector2(-54, 44)
]
const TWINKLE_S := 0.15
## The shade over the whole stage while the icon holds: as strong as the handbook's
## (HandbookPage.SHADE_ALPHA), so the busy machine row behind recedes and the icon stands alone
## with no backing of its own (2026-11-11 review: 0.45 left it reading as stuck on a cabinet).
const SHADE := Color(ArtStyle.INK, 0.72)
const OPEN_SOUND := UiKit.OPEN_SOUND

## Reduced motion: the icon is in place at once (the hold stays).
var still: bool = false

var _shade: ColorRect
var _figurine: TextureRect
var _twinkles: Array[TextureRect] = []
## Seconds since show_card; -1 once `held` has been emitted (or nothing is shown).
var _shown_for: float = -1.0
var _leaving: bool = false


func _init() -> void:
	size = STAGE
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_shade = ColorRect.new()
	_shade.color = SHADE
	_shade.size = STAGE
	_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_shade)
	for at: Vector2 in TWINKLE_AT:
		var twinkle: TextureRect = UiKit.sprite(SPARKLE)
		twinkle.size = SPARKLE_SIZE
		twinkle.position = ICON_CENTRE + at - SPARKLE_SIZE / 2.0
		twinkle.visible = false
		add_child(twinkle)
		_twinkles.append(twinkle)


## Shows `card`'s icon over the shade; `held` follows after HOLD_S.
func show_card(card: CardDefinition) -> void:
	if _figurine != null:
		remove_child(_figurine)
		_figurine.queue_free()
	_figurine = ItemView.item_art(card)
	add_child(_figurine)
	_shown_for = 0.0
	_leaving = false
	_shade.color = SHADE
	visible = true
	_place_icon()
	Sfx.play_at(self, OPEN_SOUND)


## Up and not yet handed to the join.
func is_open() -> bool:
	return visible and not _leaving


## The icon is holding (before `held`).
func is_holding() -> bool:
	return is_open() and _shown_for >= 0.0


## Ends the hold now and emits `held` (the screen capture's stills; tests).
func finish_hold() -> void:
	if is_holding():
		_shown_for = HOLD_S
		_end_hold()


## The held reveal `progress` (0 to 1) of its way out: the icon gone at once (the join flies its
## own copy), the shade fading over all of it; hidden at 1.
func leave(progress: float) -> void:
	_leaving = true
	_shown_for = -1.0
	for twinkle: TextureRect in _twinkles:
		twinkle.visible = false
	if _figurine != null:
		_figurine.visible = false
	_shade.color = Color(SHADE, SHADE.a * (1.0 - clampf(progress, 0.0, 1.0)))
	if progress >= 1.0:
		visible = false
		_leaving = false
		_shade.color = SHADE


## The icon's centre on the stage (where the join's flight starts).
func icon_centre() -> Vector2:
	return ICON_CENTRE


## The icon (null before the first draw), for tests.
func figurine() -> TextureRect:
	return _figurine


## The hold's sparkles, for tests.
func twinkles() -> Array[TextureRect]:
	return _twinkles


func _process(delta: float) -> void:
	if not is_holding():
		return
	_shown_for += delta
	_place_icon()
	if _shown_for >= HOLD_S:
		_end_hold()


func _end_hold() -> void:
	_shown_for = -1.0
	_leaving = true
	_place_icon()
	held.emit()


## The icon at its place, or above it while it drops in, bobbing after (whole art px: the 2 px
## grid); the sparkles twinkle in turn after the drop.
func _place_icon() -> void:
	if _figurine == null:
		return
	var rise: int = 0
	var lively: bool = not still and _shown_for >= DROP_S
	if not still and _shown_for >= 0.0:
		var p: float = clampf(_shown_for / DROP_S, 0.0, 1.0)
		rise = roundi(DROP_ART * pow(1.0 - p, 3.0))
	if lively:
		rise += BOB_ART * (floori((_shown_for - DROP_S) / BOB_S) % 2)
	var lit: int = floori((_shown_for - DROP_S) / TWINKLE_S) % _twinkles.size() if lively else -1
	for index: int in _twinkles.size():
		_twinkles[index].visible = index == lit
	var top_left: Vector2 = ICON_CENTRE - ItemView.SPRITE_SIZE / 2.0
	_figurine.position = top_left - Vector2(0, rise * ArtStyle.ART_SCALE)
	_figurine.size = ItemView.SPRITE_SIZE
