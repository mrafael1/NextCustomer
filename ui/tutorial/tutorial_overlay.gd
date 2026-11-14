class_name TutorialOverlay
extends Control
## The tutorial's overlay kit (tutorial plan sections 1.3, 1.6 and 2, WP-2; mock-up
## docs/art/mockups/tutorial.html): it shows one StepView at a time over a screen, back to front:
##
## - the SpotlightShade, dimming the screen but the rings' holes, which let clicks through to the
##   targets (a click anywhere else shakes the callout: outside_clicked);
## - the LOCKED plates (LockPlate) over what the step blocks;
## - the rings (TutorialRing), the move's one with its CLICK tab;
## - the callout (TutorialCallout), opening on the step's side of its target ring (TipCard.place,
##   flipped or turned to another side when it would cover a ring), MARGIN inside the overlay's
##   rect, its tail pointing at the ring.
##
## It knows nothing of the game. A ring or lock that names an anchor id is resolved through
## `anchors` (a screen's `anchor_rect`: Callable(StringName) -> Rect2, global) every frame, and the
## overlay lays itself out again when a rect moves. Mount it over the whole screen, unscaled (its
## rect is the screen the callout keeps inside), under the handbook and the hover tips. Enter,
## Space and the keypad's Enter press the callout's key (NEXT ›, GOT IT); Esc is never taken.
## Reduced motion (`reduced_motion`, a Callable() -> bool) turns off the rings' pulse, the dim's
## fade and the shake. The text size follows UiKit.reading_scale (the callout's body and width).

signal button_pressed
signal more_pressed(page: StringName)
signal outside_clicked

const FADE_S := 0.18

## Callable(StringName) -> Rect2: an anchor's global rect (Rect2() when not shown).
var anchors: Callable = Callable()
## Callable() -> bool: true for reduced motion.
var reduced_motion: Callable = Callable()
var _view: StepView
var _shade: SpotlightShade
var _locks: Control
var _rings: Control
var _callout: TutorialCallout
var _fade: Tween
## The resolved global rects of the shown view's rings and locks (to see them move).
var _ring_rects: Array[Rect2] = []
var _lock_rects: Array[Rect2] = []


func _init() -> void:
	name = "TutorialOverlay"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	visible = false
	_shade = SpotlightShade.new()
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.outside_clicked.connect(refuse)
	add_child(_shade)
	# The LOCKED plates' grey reads the screen: copied here, after the dim, so the dim stays.
	var copy: BackBufferCopy = BackBufferCopy.new()
	copy.name = "DimCopy"
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(copy)
	_locks = _layer("Locks")
	_rings = _layer("Rings")
	_callout = TutorialCallout.new()
	_callout.visible = false
	_callout.button_pressed.connect(button_pressed.emit)
	_callout.more_pressed.connect(more_pressed.emit)
	add_child(_callout)
	resized.connect(_on_resized)


## Shows `step` (replacing what was shown): the dim fades in unless it was already up.
func show_view(step: StepView) -> void:
	var was_up: bool = visible and _view != null
	_view = step
	visible = true
	_shade.dimmed = step.dim
	for child: Node in _locks.get_children():
		_locks.remove_child(child)
		child.queue_free()
	for child: Node in _rings.get_children():
		_rings.remove_child(child)
		child.queue_free()
	for mark: StepView.Mark in step.locks:
		var plate: LockPlate = LockPlate.new(mark.label)
		plate.clicked.connect(refuse)
		_locks.add_child(plate)
	for index: int in range(step.rings.size()):
		var ring: TutorialRing = TutorialRing.new()
		ring.reduced_motion = reduced_motion
		ring.act = index == step.act
		_rings.add_child(ring)
	_callout.show_view(step, _room())
	_callout.visible = true
	_resolve()
	_lay_out()
	_fade_in(not was_up)


## Hides the overlay (nothing is shown until the next show_view).
func clear() -> void:
	_view = null
	visible = false
	_callout.visible = false
	if _fade != null:
		_fade.kill()
		_fade = null
	modulate = Color.WHITE


func is_showing() -> bool:
	return visible and _view != null


func view() -> StepView:
	return _view


## A refused move: the callout's soft shake (no sound; the director re-shows the line).
func refuse() -> void:
	if not is_showing():
		return
	_callout.shake(_reduced())
	outside_clicked.emit()


## Lays the overlay out again from the anchors (a screen that moved its targets).
func refresh() -> void:
	if not is_showing():
		return
	_resolve()
	_lay_out()


func shade() -> SpotlightShade:
	return _shade


func callout() -> TutorialCallout:
	return _callout


func rings() -> Array[TutorialRing]:
	var found: Array[TutorialRing] = []
	for child: Node in _rings.get_children():
		found.append(child as TutorialRing)
	return found


func locks() -> Array[LockPlate]:
	var found: Array[LockPlate] = []
	for child: Node in _locks.get_children():
		found.append(child as LockPlate)
	return found


## The rings' and locks' global rects as resolved now (for checks).
func ring_rects() -> Array[Rect2]:
	return _ring_rects.duplicate()


func lock_rects() -> Array[Rect2]:
	return _lock_rects.duplicate()


## The callout's side, for checks.
func callout_side() -> TipCard.Opens:
	return _callout.side


func _on_resized() -> void:
	if not is_showing():
		return
	_callout.show_view(_view, _room())
	_lay_out()


func _process(_delta: float) -> void:
	if not is_showing() or not anchors.is_valid():
		return
	var rings_before: Array[Rect2] = _ring_rects
	var locks_before: Array[Rect2] = _lock_rects
	_resolve()
	if rings_before != _ring_rects or locks_before != _lock_rects:
		_lay_out()


func _input(event: InputEvent) -> void:
	if not is_showing() or not is_visible_in_tree():
		return
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE] and _callout.press_button():
		get_viewport().set_input_as_handled()


func _resolve() -> void:
	_ring_rects = []
	_lock_rects = []
	if _view == null:
		return
	for mark: StepView.Mark in _view.rings:
		_ring_rects.append(StepView.resolve(mark, anchors))
	for mark: StepView.Mark in _view.locks:
		_lock_rects.append(StepView.resolve(mark, anchors))


func _lay_out() -> void:
	if _view == null:
		return
	var to_local: Transform2D = get_global_transform().affine_inverse()
	var to_global: Transform2D = get_global_transform()
	var holes: Array[Rect2] = []
	var ring_nodes: Array[TutorialRing] = rings()
	var targets: Array[Rect2] = []
	for index: int in range(ring_nodes.size()):
		var ring: TutorialRing = ring_nodes[index]
		var rect: Rect2 = _ring_rects[index] if index < _ring_rects.size() else Rect2()
		ring.visible = rect.has_area()
		if not ring.visible:
			continue
		ring.surround(to_local * rect)
		holes.append(to_global * Rect2(ring.position, ring.size))
		targets.append(ring.outer_rect())
	_shade.set_holes(holes)
	var plates: Array[LockPlate] = locks()
	for index: int in range(plates.size()):
		var rect: Rect2 = _lock_rects[index] if index < _lock_rects.size() else Rect2()
		plates[index].visible = rect.has_area()
		if rect.has_area():
			plates[index].cover(to_local * rect)
	_place_callout(ring_nodes, targets)


## Opens the callout on the view's side of its target ring, inside the overlay's rect: the first
## side (in the view's order) that covers no ring and no LOCKED plate, else the first that covers
## no ring, else the side asked; centred with no tail when nothing is ringed.
func _place_callout(ring_nodes: Array[TutorialRing], targets: Array[Rect2]) -> void:
	var screen: Rect2 = Rect2(Vector2.ZERO, size)
	var card: Vector2 = _callout.size
	var index: int = _view.target_index()
	var target: Rect2 = Rect2()
	if index >= 0 and index < ring_nodes.size() and ring_nodes[index].visible:
		target = Rect2(ring_nodes[index].position, ring_nodes[index].size)
	if not target.has_area():
		var middle: Vector2 = ((screen.size - card) / 2.0 / TipCard.PX).floor() * TipCard.PX
		_callout.put(middle, TipCard.Opens.BELOW, Rect2())
		return
	var plates: Array[Rect2] = targets.duplicate()
	for plate: LockPlate in locks():
		if plate.visible:
			plates.append(Rect2(plate.position, plate.size))
	var tries: Array[Array] = []
	for want: TipCard.Opens in _sides(_view.side):
		tries.append(TipCard.place(target, target, want, card, screen))
	var chosen: Array = tries[0]
	for avoid: Array[Rect2] in [plates, targets]:
		var found: Array = _first_clear(tries, avoid)
		if not found.is_empty():
			chosen = found
			break
	_callout.put((chosen[0] as Rect2).position, chosen[1], target)


## The first placement of `tries` ([Rect2, Opens]) whose card, shadow included, meets none of
## `avoid`; [] when none.
static func _first_clear(tries: Array[Array], avoid: Array[Rect2]) -> Array:
	for placed: Array in tries:
		var box: Rect2 = placed[0]
		var shadowed: Rect2 = box.merge(Rect2(box.position + TipCard.SHADOW, box.size))
		var meets: bool = false
		for rect: Rect2 in avoid:
			if shadowed.intersects(rect):
				meets = true
				break
		if not meets:
			return placed
	return []


## The sides to try for `side`, in order: it, its opposite, then the other two (AUTO: below,
## above, right, left).
static func _sides(side: StepView.Opening) -> Array[TipCard.Opens]:
	match side:
		StepView.Opening.ABOVE:
			return [
				TipCard.Opens.ABOVE, TipCard.Opens.BELOW, TipCard.Opens.RIGHT, TipCard.Opens.LEFT
			]
		StepView.Opening.RIGHT:
			return [
				TipCard.Opens.RIGHT, TipCard.Opens.LEFT, TipCard.Opens.BELOW, TipCard.Opens.ABOVE
			]
		StepView.Opening.LEFT:
			return [
				TipCard.Opens.LEFT, TipCard.Opens.RIGHT, TipCard.Opens.BELOW, TipCard.Opens.ABOVE
			]
	return [TipCard.Opens.BELOW, TipCard.Opens.ABOVE, TipCard.Opens.RIGHT, TipCard.Opens.LEFT]


## The callout's widest: the overlay's width less the margins and the shadow.
func _room() -> float:
	var width: float = size.x if size.x > 0.0 else get_viewport_rect().size.x
	return width - TipCard.MARGIN * 2.0 - TipCard.SHADOW.x


func _fade_in(fresh: bool) -> void:
	if _fade != null:
		_fade.kill()
		_fade = null
	if not fresh or _reduced() or not is_inside_tree():
		modulate = Color.WHITE
		return
	modulate = Color(1, 1, 1, 0)
	_fade = create_tween()
	_fade.tween_property(self, "modulate:a", 1.0, FADE_S)


func _reduced() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())


func _layer(layer_name: String) -> Control:
	var layer: Control = Control.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)
	return layer
