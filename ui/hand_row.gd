class_name HandRow
extends Control
## The hand in its baskets (#80, mock-up B2, step 8): the items two to a basket at their hand places
## (plan section 3.8, the basket redraw: hand place p is the left or right half of basket p / 2),
## each in an ItemView.BASKET_SIZE cell. Places are fixed: an item placed on the belt leaves its
## place empty (the items beside it never pack left) and one taken back returns to its own place. A
## hand of `hand_size` items fills ceil(hand_size / 2) baskets (reset()), BASKET_PITCH apart; the
## baskets emptied by the items placed on the belt stay, empty. Places past that (debug) add
## baskets and narrow the basket step so they all still fit the row, and then items overlap: only
## while they do, hovering one brings it to the front by child order, not only z_index, so clicks
## go to the item that is drawn on top; leaving it puts the order back.
##
## The baskets themselves are decor (HandBaskets, behind and in front of the items), drawn where
## basket_lefts() puts them; `laid_out` says when that changed. Add items with add_card() and
## remove them all with clear() or reset(); the items are its children, in place order whenever no
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

## The items in place order (the child order changes while one is hovered), and each one's place.
var _order: Array[Control] = []
var _places: Array[int] = []
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
	_places = []
	for view: Control in views:
		if not is_instance_valid(view):
			continue
		view.mouse_exited.disconnect(_restore_order)
		remove_child(view)
		view.queue_free()


## Adds an item at hand place `place` (-1: the place after the last one).
func add_card(view: Control, place: int = -1) -> void:
	if place < 0:
		place = _places[-1] + 1 if not _places.is_empty() else 0
	var index: int = _places.bsearch(place)
	_order.insert(index, view)
	_places.insert(index, place)
	add_child(view)
	move_child(view, index)
	view.mouse_entered.connect(_raise.bind(view))
	view.mouse_exited.connect(_restore_order)
	_lay_out()


## The items in place order.
func cards() -> Array[Control]:
	return _order.duplicate()


## The places of the items, in the order of cards().
func places() -> Array[int]:
	return _places.duplicate()


## The item at hand place `place`, or null for an empty place.
func view_at(place: int) -> Control:
	var index: int = _places.find(place)
	return _order[index] if index >= 0 else null


## The basket that hand place `place` is in.
static func basket_of(place: int) -> int:
	return floori(float(place) / ITEMS_PER_BASKET)


## Where hand place `place`'s item stands, in this row's coordinates.
func place_position(place: int) -> Vector2:
	var lefts: Array[float] = basket_lefts()
	var basket: int = mini(basket_of(place), lefts.size() - 1)
	return Vector2(lefts[basket] + ITEM_OFFSETS[place % ITEMS_PER_BASKET], 0.0)


## The baskets shown: enough for the hand size, or for the places past it (debug).
func basket_count() -> int:
	var reach: int = _places[-1] + 1 if not _places.is_empty() else 0
	return ceili(maxi(_hand_size, reach) / float(ITEMS_PER_BASKET))


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
	for index: int in range(_order.size()):
		var view: Control = _order[index]
		view.position = place_position(_places[index])
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
