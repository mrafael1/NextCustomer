class_name StackFan
extends Control
## The fan of a folded sticker stack (#105 piece 3, mock-up readability v3 section 3, fold A):
## hovering a belt stack whose earliest stickers fold into the "+N" chip (PlanningLayer) fans every
## sticker of the item out above it, in step order, each numbered 1 to N up and left of its top-left
## corner, clear of its giver's mini (EffectSticker.set_number). Rows hold at most PER_ROW, GAP
## apart on a gentle arch (the ends ARCH lower, each turned by its place up to TURN_DEG), ROW apart
## with the oldest row on top and read left to right; the lower row's centre stands ABOVE_SPRITE
## over the item's sprite. So a row is at most about 310 px wide; the whole fan moves sideways to
## stay inside the belt's x-range, and stays under the top bar and above the item's ticket (never
## over its price).
##
## It opens over OPEN_S: the shown stickers move out from the stack, the folded ones grow out of
## the chip's centre (from FOLDED_SCALE, fading in) and the numbers fade in over the last
## 1 - NUMBER_FROM of it; meanwhile the stack's stickers hide and the chip fades. It closes the
## same way once the pointer leaves both the stack and the fan. It watches the pointer itself
## (_input, never marking an event handled), like GlyphTips, so the item keeps its hover, drag and
## clicks. Off while `blocked` says so (outside planning, during a drag, with the Cart open) and in
## the count (the layer then tracks no stack); under the layer's reduced motion it opens and shuts
## at once. Decor only: it takes no clicks, and its stickers are copies of the item's
## (StickerSpec). It says when it opens and shuts (fanned_changed), so the planning hover
## (PlanningEffects) highlights the item and keeps it while the pointer reads the fan above it.

## The fan opened for `slot`'s stack, or shut (-1).
signal fanned_changed(slot: int)

const GAP := 76.0
const ROW := 46.0
const PER_ROW := 4
const ARCH := 10.0
## The arch's and the turn's reach: an end GAP x 1.5 from a row's centre is ARCH lower and turned
## TURN_DEG.
const ARCH_SPAN := GAP * 1.5
const TURN_DEG := 9.0
const ABOVE_SPRITE := 18.0
## The fan's room: the belt's x-range, from TOP_GAP under the top bar down to SPRITE_SLACK under
## the sprite's top.
const TOP_GAP := 8.0
const SPRITE_SLACK := 10.0
const OPEN_S := 0.18
const NUMBER_FROM := 0.6
const FOLDED_SCALE := 0.3
## How far round the stack and the fan the pointer may stray before the fan closes.
const HOVER_MARGIN := 4.0

## Returns true while no fan may open (PlanningEffects: outside planning, during a drag, with the
## Cart open).
var blocked: Callable = Callable()

var _stacks: Dictionary[int, Folded] = {}
## The slot fanned out (-1: none), its copies and where each starts (the stack's place, or the
## chip's centre) and ends (its fan place), as rects in the fan's coordinates.
var _slot: int = -1
var _copies: Array[EffectSticker] = []
var _from: Array[Rect2] = []
var _to: Array[Rect2] = []
var _folded_from: Array[bool] = []
## How far it is open (0 to 1), and whether it is opening (else closing).
var _progress: float = 0.0
var _opening: bool = false
var _tween: Tween
## The pointer's last place (the fan's coordinates), once it has moved.
var _point: Vector2 = Vector2.ZERO
var _has_point: bool = false


## A folded stack the fan may open (PlanningLayer, layer coordinates).
class Folded:
	extends RefCounted
	## Every sticker of the item, in step order.
	var specs: Array[StickerSpec] = []
	## The stack as shown: the fold chip, then the stickers left, top to bottom.
	var stack: Array[EffectSticker] = []
	## The item's sprite at rest.
	var sprite: Rect2 = Rect2()
	## (spec: StickerSpec) -> bool: whether its sticker is drained (the layer's focus).
	var drained: Callable = Callable()


func _init() -> void:
	name = "StackFan"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = ShiftStage.SIZE


## Where a fan of stickers of `sizes` (in step order) stands over `sprite` inside `bounds`: each
## sticker's rect, in rows of at most PER_ROW (see the class comment). The rows' turns are
## turn_of's.
static func fan_rects(sizes: Array[Vector2], sprite: Rect2, bounds: Rect2) -> Array[Rect2]:
	var count: int = sizes.size()
	var rects: Array[Rect2] = []
	if count == 0:
		return rects
	var rows: int = ceili(count / float(PER_ROW))
	var per: int = ceili(count / float(rows))
	var base: float = sprite.position.y - ABOVE_SPRITE
	var reach: Rect2 = Rect2()
	for index: int in range(count):
		var row: int = floori(float(index) / per)
		var off: float = _offset(count, index)
		var centre: Vector2 = Vector2(
			sprite.get_center().x + off,
			base - (rows - 1 - row) * ROW + ARCH * pow(off / ARCH_SPAN, 2.0)
		)
		var rect: Rect2 = Rect2(centre - sizes[index] / 2.0, sizes[index])
		rects.append(rect)
		var drawn: Rect2 = _drawn(rect)
		reach = drawn if index == 0 else reach.merge(drawn)
	var shift: Vector2 = Vector2.ZERO
	if reach.position.x < bounds.position.x:
		shift.x = bounds.position.x - reach.position.x
	elif reach.end.x > bounds.end.x:
		shift.x = bounds.end.x - reach.end.x
	if reach.position.y < bounds.position.y:
		shift.y = bounds.position.y - reach.position.y
	for index: int in range(count):
		var moved: Vector2 = (rects[index].position + shift).snappedf(ArtStyle.ART_SCALE)
		rects[index] = Rect2(moved, rects[index].size)
	return rects


## Sticker `index`'s turn (degrees) in a fan of `count`: by its place in its row.
static func turn_of(count: int, index: int) -> float:
	return _offset(count, index) / ARCH_SPAN * TURN_DEG


## The fan's room over `sprite` (layer coordinates): the belt's x-range, under the top bar and
## above SPRITE_SLACK under the sprite's top.
static func bounds_for(sprite: Rect2) -> Rect2:
	var top: float = ShiftStage.TOP_BAR_BOTTOM + TOP_GAP
	var belt: Rect2 = ShiftStage.BELT_RECT
	return Rect2(belt.position.x, top, belt.size.x, sprite.position.y + SPRITE_SLACK - top)


## The folded stacks the fan may open, by slot (PlanningLayer, after each layout; empty: none). An
## open fan whose stack changed or went shuts at once; then the pointer's last place is looked at
## again.
func track(stacks: Dictionary[int, Folded]) -> void:
	if _slot >= 0:
		var kept: Folded = stacks.get(_slot, null)
		var was: Folded = _stacks.get(_slot, null)
		if kept == null or was == null or kept.stack != was.stack or kept.sprite != was.sprite:
			_shut()
	_stacks = stacks
	_look()


## The pointer is at `global` (its motion, or a test's): opens the fan of the folded stack under
## it, keeps the open one while it stays on the stack or the fan, else closes it.
func point_at(global: Vector2) -> void:
	_point = get_global_transform().affine_inverse() * global
	_has_point = true
	_look()


## The slot fanned out (opening, open or closing), or -1.
func fanned() -> int:
	return _slot


## How far the fan is open (0 to 1).
func openness() -> float:
	return _progress


## The fanned copies, in step order (empty when none is fanned).
func copies() -> Array[EffectSticker]:
	return _copies.duplicate()


## Each copy's rect when fully open (the fan's coordinates, which are the layer's).
func fan_places() -> Array[Rect2]:
	return _to.duplicate()


## Puts the layer's focus look on the copies (a focus or a stamp drains them).
func repaint() -> void:
	var folded: Folded = _stacks.get(_slot, null)
	if folded == null or not folded.drained.is_valid():
		return
	for index: int in range(_copies.size()):
		_copies[index].set_drained(bool(folded.drained.call(folded.specs[index])))


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		point_at((event as InputEventMouseMotion).position)


## Opens, keeps or closes the fan for the pointer's last place.
func _look() -> void:
	if _is_blocked():
		_shut()
		return
	var wanted: int = -1
	if _has_point:
		if _slot >= 0 and _stacks.has(_slot) and _open_rect().has_point(_point):
			wanted = _slot
		else:
			for slot: int in _stacks:
				if _stack_rect(_stacks[slot]).grow(HOVER_MARGIN).has_point(_point):
					wanted = slot
					break
	if wanted >= 0 and wanted != _slot:
		_shut()
		_open(wanted)
	elif wanted >= 0 and not _opening:
		_animate(true)
	elif wanted < 0 and _slot >= 0 and _opening:
		_animate(false)


## Makes `slot`'s copies at their stack places and starts opening.
func _open(slot: int) -> void:
	var folded: Folded = _stacks[slot]
	_slot = slot
	var count: int = folded.specs.size()
	var sizes: Array[Vector2] = []
	for spec: StickerSpec in folded.specs:
		sizes.append(EffectSticker.size_for(spec))
	_to = fan_rects(sizes, folded.sprite, bounds_for(folded.sprite))
	var chip: Rect2 = _local(folded.stack[0])
	var shown: int = folded.stack.size() - 1
	for index: int in range(count):
		var copy: EffectSticker = EffectSticker.new(folded.specs[index], turn_of(count, index))
		copy.pivot_offset = copy.size / 2.0
		add_child(copy)
		_copies.append(copy)
		var in_stack: int = index - (count - shown)
		if in_stack >= 0:
			_from.append(_local(folded.stack[1 + in_stack]))
			_folded_from.append(false)
		else:
			_from.append(Rect2(chip.get_center() - copy.size / 2.0, copy.size))
			_folded_from.append(true)
	repaint()
	_place(0.0)
	_animate(true)
	fanned_changed.emit(slot)


## Tweens the fan open (`open`) or shut from where it is (at once under reduced motion); shut, the
## copies go and the stack shows again.
func _animate(open: bool) -> void:
	_opening = open
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	var target: float = 1.0 if open else 0.0
	var seconds: float = OPEN_S * absf(target - _progress)
	if _reduced() or seconds <= 0.0 or not is_inside_tree():
		_place(target)
		if not open:
			_shut()
		return
	_tween = create_tween()
	_tween.tween_method(_place, _progress, target, seconds)
	if not open:
		_tween.tween_callback(_shut)


## The fan at `progress` (0: the stack, 1: open), smoothstep.
func _place(progress: float) -> void:
	_progress = progress
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	var number_alpha: float = clampf((progress - NUMBER_FROM) / (1.0 - NUMBER_FROM), 0.0, 1.0)
	for index: int in range(_copies.size()):
		var copy: EffectSticker = _copies[index]
		var at: Vector2 = _from[index].position.lerp(_to[index].position, eased)
		copy.position = at.snappedf(ArtStyle.ART_SCALE)
		var start: float = FOLDED_SCALE if _folded_from[index] else 1.0
		copy.scale = Vector2.ONE * lerpf(start, 1.0, eased)
		copy.modulate.a = eased if _folded_from[index] else 1.0
		copy.visible = progress > 0.0
		copy.set_number(index + 1, number_alpha)
	var folded: Folded = _stacks.get(_slot, null)
	if folded == null:
		return
	for index: int in range(folded.stack.size()):
		var sticker: EffectSticker = folded.stack[index]
		if is_instance_valid(sticker):
			var alpha: float = 1.0 - eased if index == 0 else (1.0 if progress <= 0.0 else 0.0)
			sticker.modulate.a = alpha


## Shuts the fan at once: the copies go, the stack shows again.
func _shut() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	var folded: Folded = _stacks.get(_slot, null)
	if folded != null:
		for sticker: EffectSticker in folded.stack:
			if is_instance_valid(sticker):
				sticker.modulate.a = 1.0
	for copy: EffectSticker in _copies:
		remove_child(copy)
		copy.queue_free()
	_copies.clear()
	_from.clear()
	_to.clear()
	_folded_from.clear()
	var was: int = _slot
	_slot = -1
	_progress = 0.0
	_opening = false
	if was >= 0:
		fanned_changed.emit(-1)


## Where the pointer keeps the open fan: its stack and every fan place (with its number), and the
## room between, grown by HOVER_MARGIN.
func _open_rect() -> Rect2:
	var rect: Rect2 = _stack_rect(_stacks[_slot])
	for place: Rect2 in _to:
		rect = rect.merge(_drawn(place))
	return rect.grow(HOVER_MARGIN)


## The stack's stickers' rects merged (the fan's coordinates).
func _stack_rect(folded: Folded) -> Rect2:
	var rect: Rect2 = Rect2()
	for index: int in range(folded.stack.size()):
		var sticker: Rect2 = _local(folded.stack[index])
		rect = sticker if index == 0 else rect.merge(sticker)
	return rect


## `sticker`'s rect in the fan's coordinates.
func _local(sticker: EffectSticker) -> Rect2:
	var to_local: Transform2D = get_global_transform().affine_inverse()
	var global: Rect2 = sticker.get_global_rect()
	return Rect2(to_local * global.position, global.size * to_local.get_scale())


func _is_blocked() -> bool:
	return blocked.is_valid() and bool(blocked.call())


func _reduced() -> bool:
	var layer: PlanningLayer = get_parent() as PlanningLayer
	return layer != null and layer.reduced_motion


## Sticker `index`'s offset (px) from its row's centre in a fan of `count`.
static func _offset(count: int, index: int) -> float:
	var rows: int = ceili(count / float(PER_ROW))
	var per: int = ceili(count / float(rows))
	var row: int = floori(float(index) / per)
	var in_row: int = per if row < rows - 1 else count - per * (rows - 1)
	return (index % per - (in_row - 1) / 2.0) * GAP


## A sticker's `rect` with its order number (EffectSticker.NUMBER_AT, ringed) and the widest
## giver badge's reach (EffectSticker.LABEL_BADGE_X) on its left.
static func _drawn(rect: Rect2) -> Rect2:
	var number: Rect2 = Rect2(rect.position + EffectSticker.NUMBER_AT, EffectSticker.NUMBER_SIZE)
	var badge: float = -EffectSticker.LABEL_BADGE_X
	var reach: Rect2 = Rect2(rect.position.x - badge, rect.position.y, badge, rect.size.y)
	return rect.merge(number.grow(EffectSticker.NUMBER_RING)).merge(reach)
