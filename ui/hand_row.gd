class_name HandRow
extends Control
## The hand on the counter (#55, decision 2): the cards side by side in the order they were
## added, laid out by this plain Control with an adaptive step. Up to 7 cards never overlap; a
## full hand of 8 overlaps by about 8 px; more cards (debug) squeeze closer. Each card is drawn
## above the one before it, so an overlap hides a card's right edge, never its title or its price
## sticker (top left, ArtCardView): every base value stays readable. Hovering a card brings it
## to the front by child order, not only z_index, so clicks go to the card that is drawn on top;
## leaving it puts the order back.
##
## Add cards with add_card() and remove them all with clear(); the cards are its children, in
## hand order whenever no card is hovered.

## The gap between cards when there is room for it.
const GAP := 10.0

## The cards in hand order (the child order changes while one is hovered).
var _order: Array[Control] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_lay_out)


## Removes and frees every card. The hand order is emptied and each card let go of first: a
## hovered card's mouse_exited, sent while it leaves the tree, would otherwise reorder the
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


## Adds a card at the end of the hand.
func add_card(view: Control) -> void:
	_order.append(view)
	add_child(view)
	view.mouse_entered.connect(_raise.bind(view))
	view.mouse_exited.connect(_restore_order)
	_lay_out()


## The cards in hand order.
func cards() -> Array[Control]:
	return _order.duplicate()


## The distance from one card's left edge to the next for `count` cards in `width` pixels.
static func step_for(count: int, width: float) -> float:
	var natural: float = ArtCardView.SIZE.x + GAP
	if count <= 1:
		return natural
	return minf(natural, (width - ArtCardView.SIZE.x) / (count - 1))


func _lay_out() -> void:
	var step: float = step_for(_order.size(), size.x)
	for index: int in range(_order.size()):
		var view: Control = _order[index]
		view.position = Vector2(roundf(index * step), 0.0)
		view.size = ArtCardView.SIZE


func _raise(view: Control) -> void:
	if is_instance_valid(view) and view.get_parent() == self and not view.is_queued_for_deletion():
		move_child(view, -1)


func _restore_order() -> void:
	for index: int in range(_order.size()):
		var view: Control = _order[index]
		if is_instance_valid(view) and view.get_parent() == self:
			move_child(view, index)
