class_name HandRow
extends Control
## The hand in its tray (#55, decision 2; #75): the items side by side in the order they were
## added, each in an ItemView.TRAY_SIZE cell, laid out by this plain Control with an adaptive
## step. A full hand of 8 fits at the natural pitch (the cell and GAP) with no overlap; more
## items (debug) squeeze closer. Each item is drawn above the one before it, so an overlap hides
## only the right edge of the item before (its sticker's glyph corner), never the base value at
## its sticker's left. Only while items overlap, hovering one brings it to the front by child
## order, not only z_index, so clicks go to the item that is drawn on top; leaving it puts the
## order back.
##
## Add items with add_card() and remove them all with clear(); the items are its children, in
## hand order whenever no item is hovered.

## The gap between items when there is room for it.
const GAP := 4.0

## The items in hand order (the child order changes while one is hovered).
var _order: Array[Control] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_lay_out)


## Removes and frees every item. The hand order is emptied and each item let go of first: a
## hovered item's mouse_exited, sent while it leaves the tree, would otherwise reorder the
## children mid-removal (Godot refuses move_child then, with an error).
func clear() -> void:
	var views: Array[Control] = _order
	_order = []
	for view: Control in views:
		if not is_instance_valid(view):
			continue
		view.mouse_exited.disconnect(_restore_order)
		remove_child(view)
		view.queue_free()


## Adds an item at the end of the hand.
func add_card(view: Control) -> void:
	_order.append(view)
	add_child(view)
	view.mouse_entered.connect(_raise.bind(view))
	view.mouse_exited.connect(_restore_order)
	_lay_out()


## The items in hand order.
func cards() -> Array[Control]:
	return _order.duplicate()


## The distance from one item's left edge to the next for `count` items in `width` pixels.
static func step_for(count: int, width: float) -> float:
	var natural: float = ItemView.TRAY_SIZE.x + GAP
	if count <= 1:
		return natural
	return minf(natural, (width - ItemView.TRAY_SIZE.x) / (count - 1))


## Whether the items overlap (more than fit at the natural pitch).
func overlaps() -> bool:
	return step_for(_order.size(), size.x) < ItemView.TRAY_SIZE.x


func _lay_out() -> void:
	var step: float = step_for(_order.size(), size.x)
	for index: int in range(_order.size()):
		var view: Control = _order[index]
		view.position = Vector2(roundf(index * step), 0.0)
		view.size = ItemView.TRAY_SIZE


func _raise(view: Control) -> void:
	if not overlaps():
		return
	if is_instance_valid(view) and view.get_parent() == self and not view.is_queued_for_deletion():
		move_child(view, -1)


func _restore_order() -> void:
	for index: int in range(_order.size()):
		var view: Control = _order[index]
		if is_instance_valid(view) and view.get_parent() == self:
			move_child(view, index)
