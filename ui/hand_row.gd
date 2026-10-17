class_name HandRow
extends Control
## The hand in its baskets (#80, mock-up B2, step 8): the items two to a basket in the order they
## were added, each in an ItemView.BASKET_SIZE cell at the left or right half of its basket. A
## hand of `hand_size` items fills ceil(hand_size / 2) baskets (reset()), BASKET_PITCH apart; the
## baskets left by the items placed on the belt stay, empty. More items than that (debug) add
## baskets and narrow the basket step so they all still fit the row, and then items overlap: only
## while they do, hovering one brings it to the front by child order, not only z_index, so clicks
## go to the item that is drawn on top; leaving it puts the order back.
##
## The baskets themselves are decor (HandBaskets, behind and in front of the items), drawn where
## basket_lefts() puts them; `laid_out` says when that changed. Add items with add_card() and
## remove them all with clear() or reset(); the items are its children, in hand order whenever no
## item is hovered.

## The items were laid out again (the basket count or step may have changed).
signal laid_out

## A basket's width at its rim, the distance from one basket's left edge to the next at the
## natural pitch (20 px of counter between two), and the items' places in a basket (from its left
## edge, two side by side).
const BASKET_WIDTH := 208.0
const BASKET_PITCH := 228.0
const ITEM_OFFSETS: Array[float] = [8.0, 104.0]
const ITEMS_PER_BASKET := 2
## The hand size before reset() names one (the balance's 8).
const DEFAULT_HAND_SIZE := 8

## The items in hand order (the child order changes while one is hovered).
var _order: Array[Control] = []
var _hand_size: int = DEFAULT_HAND_SIZE


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_lay_out)


## Removes every item and makes room for a hand of `hand_size` (the baskets it fills).
func reset(hand_size: int) -> void:
	clear()
	_hand_size = hand_size
	_lay_out()


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


## The baskets shown: enough for the hand size, or for more items (debug).
func basket_count() -> int:
	return ceili(maxi(_hand_size, _order.size()) / float(ITEMS_PER_BASKET))


## Each basket's left edge at its rim, in this row's coordinates, on the 2 px art grid.
func basket_lefts() -> Array[float]:
	var lefts: Array[float] = []
	var step: float = step_for(basket_count(), size.x)
	for index: int in range(basket_count()):
		lefts.append(snappedf(index * step, ArtStyle.ART_SCALE))
	return lefts


## The distance from one basket's left edge to the next for `count` baskets in `width` pixels:
## BASKET_PITCH, or less when that many would not fit.
static func step_for(count: int, width: float) -> float:
	if count <= 1:
		return BASKET_PITCH
	return minf(BASKET_PITCH, (width - BASKET_WIDTH) / (count - 1))


## Whether the items overlap (the basket step is too narrow for the items at its natural pitch).
func overlaps() -> bool:
	var reach: float = ITEM_OFFSETS[-1] + ItemView.BASKET_SIZE.x - ITEM_OFFSETS[0]
	return step_for(basket_count(), size.x) < reach


func _lay_out() -> void:
	var lefts: Array[float] = basket_lefts()
	for index: int in range(_order.size()):
		var view: Control = _order[index]
		var left: float = lefts[floori(float(index) / ITEMS_PER_BASKET)]
		view.position = Vector2(left + ITEM_OFFSETS[index % ITEMS_PER_BASKET], 0.0)
		view.size = ItemView.BASKET_SIZE
	laid_out.emit()


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
