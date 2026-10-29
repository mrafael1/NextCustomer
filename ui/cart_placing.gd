class_name CartPlacing
extends Control
## Placing a machine prize in the cart (2026-10-29, mock-up pick_skip_cart.html): while the deck
## view shows the cart in placing mode, the picked prize's item rides on the pointer (a DeckCell
## of it, tilted, gold-ringed) and goes where it is dropped:
## - on a free spot (RoomSpot, one per place left in the cart; gold "+1" under the pointer): added;
## - on an item of the cart (its cell turns OUT ✕): it swaps one copy of that item out;
## - anywhere else, on Close, or with a right click or Escape: back to the machine, nothing picked.
## A full cart has no free spot, so a drop on an item is the only way in. The pick began with a
## press on the ticket: dragging carries the item and releasing drops it; a release where it was
## pressed leaves it on the pointer until the next click (click to pick up, click to drop).
## Top level over the view; it takes no clicks itself but reads the pointer (_input) while it holds.

signal added
signal swapped(card: CardInstance)
signal cancelled

enum Mode { IDLE, PRESSED, CLICKED }

## Moving this far (px) before the release makes the press a drag.
const DRAG_DISTANCE := 6.0
## The held item: its scale, tilt and where the pointer holds it (its middle, in its own
## coordinates); over a target it shrinks and thins so the target's OUT ✕ or +1 shows.
const HELD_SCALE := 0.9
const HELD_TILT := -4.0
const HELD_GRIP := Vector2(54, 100)
const HOT_SCALE := 0.55
const HOT_ALPHA := 0.8

var _mode: Mode = Mode.IDLE
var _start: Vector2 = Vector2.ZERO
var _moved: bool = false
var _held: DeckCell
var _cells: Array[DeckCell] = []
var _spots: Array[RoomSpot] = []
var _back: Control
var _hot: Control
var _hover: Callable


func _init() -> void:
	name = "CartPlacing"
	top_level = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10


## Holds `card` (a CardInstance of the prize, in `aisle`) over `cells` and `free_spots`; `back`
## is the Close button (a drop there goes back). `hover` (a DeckCell, or null) shows the item
## under it.
## A press still down (the pick's) makes it a drag, else it waits for a click.
func begin(
	card: CardInstance,
	aisle: AisleDefinition,
	cells: Array[DeckCell],
	free_spots: Array[RoomSpot],
	back: Control,
	hover: Callable
) -> void:
	end()
	_cells = cells
	_spots = free_spots
	_back = back
	_hover = hover
	_held = DeckCell.new(card, aisle, 1)
	_held.name = "HeldItem"
	_held.ringed = true
	_held.scale = Vector2.ONE * HELD_SCALE
	_held.rotation_degrees = HELD_TILT
	_held.pivot_offset = HELD_GRIP
	_held.propagate_call(&"set_mouse_filter", [Control.MOUSE_FILTER_IGNORE])
	add_child(_held)
	_mode = Mode.PRESSED if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) else Mode.CLICKED
	_start = get_global_mouse_position()
	_moved = false
	visible = true
	move_to(_start)


## Lets go of the held item (no drop).
func end() -> void:
	_mode = Mode.IDLE
	_set_hot(null)
	if _held != null:
		remove_child(_held)
		_held.queue_free()
	_held = null
	_cells = []
	_spots = []
	visible = false


func is_holding() -> bool:
	return _mode != Mode.IDLE


## The held item (null: none; for tests).
func held() -> DeckCell:
	return _held


## The free spots shown (for tests).
func spots() -> Array[RoomSpot]:
	return _spots


## The held item follows the pointer at `at` (global), marking what it is over.
func move_to(at: Vector2) -> void:
	if _held == null:
		return
	_held.position = at - HELD_GRIP
	_set_hot(target_at(at))


## What a drop at `at` (global) would land on: a free spot, a cart item's cell, or null (back).
func target_at(at: Vector2) -> Control:
	for spot: RoomSpot in _spots:
		if is_instance_valid(spot) and spot.get_global_rect().has_point(at):
			return spot
	for cell: DeckCell in _cells:
		if is_instance_valid(cell) and cell.get_global_rect().has_point(at):
			return cell
	return null


## Drops the held item at `at` (global): added, swapped or cancelled.
func drop_at(at: Vector2) -> void:
	if not is_holding():
		return
	var target: Control = null if _on_back(at) else target_at(at)
	end()
	if target is RoomSpot:
		added.emit()
	elif target is DeckCell:
		swapped.emit((target as DeckCell).item().card)
	else:
		cancelled.emit()


## Gives up the held item: back to the machine.
func cancel() -> void:
	if not is_holding():
		return
	end()
	cancelled.emit()


func _input(event: InputEvent) -> void:
	if not is_holding():
		return
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		cancel()
		return
	var at: Vector2 = get_global_mouse_position()
	if event is InputEventMouseMotion:
		if not _moved and at.distance_to(_start) > DRAG_DISTANCE:
			_moved = true
		move_to(at)
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button == null:
		return
	if button.button_index == MOUSE_BUTTON_RIGHT and button.pressed:
		get_viewport().set_input_as_handled()
		cancel()
	elif button.button_index != MOUSE_BUTTON_LEFT:
		return
	elif not button.pressed and _mode == Mode.PRESSED:
		get_viewport().set_input_as_handled()
		if _moved:
			drop_at(at)
		else:
			_mode = Mode.CLICKED
	elif button.pressed and _mode == Mode.CLICKED:
		get_viewport().set_input_as_handled()
		drop_at(at)


func _on_back(at: Vector2) -> bool:
	return _back != null and is_instance_valid(_back) and _back.get_global_rect().has_point(at)


func _set_hot(target: Control) -> void:
	if target == _hot:
		return
	if _hot != null and is_instance_valid(_hot):
		if _hot is RoomSpot:
			(_hot as RoomSpot).hot = false
		elif _hot is DeckCell:
			(_hot as DeckCell).out_marked = false
	_hot = target
	if _held != null:
		_held.scale = Vector2.ONE * (HOT_SCALE if _hot != null else HELD_SCALE)
		_held.modulate.a = HOT_ALPHA if _hot != null else 1.0
	if _hot is RoomSpot:
		(_hot as RoomSpot).hot = true
	elif _hot is DeckCell:
		(_hot as DeckCell).out_marked = true
	if _hover.is_valid():
		_hover.call(_hot as DeckCell)
