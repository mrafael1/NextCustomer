class_name CardDrag
extends Node
## Drag-and-drop on top of click-to-place (full build plan section 3, phase 1). A press on a
## card still picks it up exactly as a click does; the shift screen then arms this node. Moving
## past DRAG_THRESHOLD with the button held turns the pick into a drag: a ghost of the card
## follows the mouse and the slot where it would land lights up. Releasing reports the slot under
## the mouse (or -1 for anywhere else) through `released`, and the shift screen places or lets go
## of the card through the same code as a click. A press and release without moving stays a
## click. A press on the card already picked up is armed to let go of it, but only on a release
## without a drag, so a picked card can still be dragged.

## The button was released: after a drag (`dragged`, `slot` the row slot under the mouse or
## -1), or without one on a card armed to let go on a click.
signal released(card: CardInstance, slot: int, dragged: bool)

## How far the mouse moves with the button held before a pick becomes a drag, in pixels.
const DRAG_THRESHOLD := 8.0
const GHOST_SCALE := 1.08
const GHOST_TILT := -4.0
## The landing slot: an empty panel brightens; a card that would be pushed right warms.
const HOVER_TINT := Color(1.7, 1.7, 1.4)
const PUSH_TINT := Color(1.0, 0.82, 0.5)

var _overlay: Control
var _slots: Array[PanelContainer] = []
var _hand_box: Control
## (card, slot) -> the slot the card would land in if dropped on `slot`, or -1 if it can't go
## in the row: the row is compacted, so a slot past the end means the end.
var _landing_slot: Callable
var _card: CardInstance
var _press_position: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _lets_go_on_click: bool = false
var _ghost: CardView
var _dimmed: CardView
var _hovered: int = -1


func setup(
	overlay: Control, slots: Array[PanelContainer], hand_box: Control, landing_slot: Callable
) -> void:
	_overlay = overlay
	_slots = slots
	_hand_box = hand_box
	_landing_slot = landing_slot


## Called on a press on `card`, now picked up: it becomes a drag if the mouse moves far enough
## before the button is released. `lets_go_on_click`: a release without a drag reports
## `released` too (a click on the card already picked up lets go of it).
func arm(card: CardInstance, press_position: Vector2, lets_go_on_click: bool = false) -> void:
	cancel()
	_card = card
	_press_position = press_position
	_lets_go_on_click = lets_go_on_click


func is_dragging() -> bool:
	return _dragging


## Stops tracking without reporting anything (a new shift, the count-up), and puts the
## carried card's look back.
func cancel() -> void:
	if is_instance_valid(_dimmed) and not _dimmed.is_queued_for_deletion():
		# A carried card is never marked for a redraw (redraw mode doesn't pick cards up).
		_dimmed.body.modulate = Color.WHITE
	_dimmed = null
	_card = null
	_dragging = false
	_lets_go_on_click = false
	_set_hovered(-1)
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null


func _input(event: InputEvent) -> void:
	if _card == null:
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion:
		if not motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			# The release was missed (outside the window): no drop, but a click still lets go.
			_finish(-1, false)
		elif _dragging:
			_follow(motion.position)
		elif motion.position.distance_to(_press_position) >= DRAG_THRESHOLD:
			_start(motion.position)
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		var was_dragging: bool = _dragging
		_finish(_slot_at(button.position), true)
		if was_dragging:
			get_viewport().set_input_as_handled()


## The button is up: reports a drag's drop (only when the release was seen), or a click on a
## card armed to let go.
func _finish(slot: int, seen: bool) -> void:
	var card: CardInstance = _card
	var dragged: bool = _dragging
	var report: bool = (dragged and seen) or (not dragged and _lets_go_on_click)
	cancel()
	if report:
		released.emit(card, slot if dragged else -1, dragged)


## The row slot under a screen position, or -1.
func _slot_at(screen_position: Vector2) -> int:
	for slot: int in range(_slots.size()):
		if _slots[slot].get_global_rect().has_point(screen_position):
			return slot
	return -1


func _start(mouse_position: Vector2) -> void:
	_dragging = true
	_ghost = CardView.new(_card)
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.z_index = 10
	_overlay.add_child(_ghost)
	_ghost.body.scale = Vector2(GHOST_SCALE, GHOST_SCALE)
	_ghost.body.rotation = deg_to_rad(GHOST_TILT)
	_ghost.body.modulate = Color(1, 1, 1, 0.92)
	_dim_source()
	_follow(mouse_position)


func _follow(mouse_position: Vector2) -> void:
	_ghost.position = mouse_position - CardView.CARD_SIZE / 2.0
	var slot: int = _slot_at(mouse_position)
	_set_hovered(-1 if slot < 0 else _landing_slot.call(_card, slot))


## The carried card's own view (in the hand, where a picked card waits) fades while it is
## carried, so the ghost reads as the card itself.
func _dim_source() -> void:
	for child: Node in _hand_box.get_children():
		var view: CardView = child as CardView
		if view != null and view.card == _card and not view.is_queued_for_deletion():
			view.body.modulate = Color(1, 1, 1, 0.3)
			_dimmed = view


## Lights up the landing slot: an empty panel, or the card there that would be pushed right
## (its frame only, so its text stays readable).
func _set_hovered(slot: int) -> void:
	if slot == _hovered:
		return
	if _hovered >= 0 and _hovered < _slots.size():
		_tint(_slots[_hovered], Color.WHITE, Color.WHITE)
	_hovered = slot
	if _hovered >= 0 and _hovered < _slots.size():
		_tint(_slots[_hovered], HOVER_TINT, PUSH_TINT)


static func _tint(panel: PanelContainer, panel_tint: Color, card_tint: Color) -> void:
	panel.self_modulate = panel_tint
	for child: Node in panel.get_children():
		var view: CardView = child as CardView
		if view != null and not view.is_queued_for_deletion():
			view.body.self_modulate = card_tint


## The landing slot shown (for tests), or -1.
func hovered_slot() -> int:
	return _hovered
