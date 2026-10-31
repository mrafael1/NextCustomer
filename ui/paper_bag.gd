class_name PaperBag
extends Control
## The paper bag on the counter (#86 v6, mock-up count_up_86_v6_scan.html): the counted items go
## into it, one by one, as the belt ride bags them. Since #123 it is the store's kraft bag on the
## bagging shelf behind the scanner (ShiftStage.BAG_RECT), in three layers: the back wall of its
## open top (bag_back), then the contents (the bagged items peeking out of its mouth at 1x art, and
## the item hopping in), then its front (bag_front, the store's band and price-tag logo baked into
## the art: no text is printed on the counter). The bag squashes about its foot as an item lands in
## it (land), unless motion is reduced.
##
## The ride hops a copy of the item's art (art_of) into `contents`, toward next_peek_rect(), then
## hands it over (add_art); a resumed checkout shows the bagged items at once (show_items); clear()
## empties the bag for the next shift. Decor only: it takes no clicks.

## The bag's size: its art's (36x46 art px at 2x, the store's kraft bag of #123), its foot on the
## bagging shelf.
const SIZE := Vector2(72, 92)
## Its mouth (bag coordinates): the open top above the front's serrated top edge, between the back
## wall's ends, where the items go in and where a bagged item's effects start from.
const MOUTH_RECT := Rect2(4, 0, 64, 16)
## A bagged item peeks out at 1x art: half its belt sprite's size (2x art), so its texels stay
## whole.
const ITEM_SCALE := 0.5
const ITEM_SIZE := ItemView.SPRITE_SIZE * ITEM_SCALE
## Where each bagged item's art stands (its top left, bag coordinates), in bagging order and on
## the 2 px art grid, wrapping after the last: inside the bag's width, their tops over the mouth
## so the upper part of each shows above the front.
const PEEKS: Array[Vector2] = [
	Vector2(2, -8),
	Vector2(22, -4),
	Vector2(12, -12),
	Vector2(20, -10),
	Vector2(4, -4),
	Vector2(14, -6),
	Vector2(6, -12),
	Vector2(22, -8),
	Vector2(8, -2),
]
## The landing's squash (the mock-up's): a wobble decaying over SQUASH_S, SQUASH_RATE radians a
## second, widening by SQUASH_X and lowering by SQUASH_Y of the bag's size at its peak.
const SQUASH_S := 0.35
const SQUASH_RATE := 30.0
const SQUASH_X := 0.06
const SQUASH_Y := 0.08
const BACK_NAME := &"BagBack"
const CONTENTS_NAME := &"BagContents"
const FRONT_NAME := &"BagFront"

const BACK := preload("res://art/scenery/bag_back.png")
const FRONT := preload("res://art/scenery/bag_front.png")

## Makes the squash's tween when set (the count-up's tween_maker(), so its hit-stops and skips
## hold and speed it); else the bag makes its own.
var make_tween: Callable = Callable()
## The layer between the back wall and the front: the bagged items, and the item hopping in.
var contents: Control
var _items: Array[Control] = []
var _squash: Tween


func _init() -> void:
	name = "PaperBag"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SIZE
	pivot_offset = Vector2(SIZE.x / 2.0, SIZE.y)
	var back: TextureRect = UiKit.sprite(BACK)
	back.name = BACK_NAME
	back.size = SIZE
	add_child(back)
	contents = Control.new()
	contents.name = CONTENTS_NAME
	contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	contents.size = SIZE
	add_child(contents)
	var front: TextureRect = UiKit.sprite(FRONT)
	front.name = FRONT_NAME
	front.size = SIZE
	add_child(front)


## `definition`'s art for the bag: its belt art (ItemView.item_art) without the name printed on an
## art-pending box or an icon-less slip, as no text is printed on the counter (and text drawn at
## the hop's fractional scale would blur).
static func art_of(definition: CardDefinition) -> TextureRect:
	var art: TextureRect = ItemView.item_art(definition)
	var printed: Node = art.get_node_or_null(ItemView.PRINTED_NAME)
	if printed != null:
		art.remove_child(printed)
		printed.free()
	return art


## Bags `definition`'s item: its art (art_of) peeks out at the next place. Returns it.
func add_item(definition: CardDefinition) -> Control:
	var art: TextureRect = art_of(definition)
	add_art(art)
	return art


## Bags `art` (a belt sprite's art at 2x, e.g. the copy that hopped in): it moves into the
## contents and peeks out at the next place, at 1x.
func add_art(art: Control) -> void:
	var place: Vector2 = PEEKS[_items.size() % PEEKS.size()]
	if art.get_parent() != contents:
		if art.get_parent() != null:
			art.get_parent().remove_child(art)
		contents.add_child(art)
	art.rotation = 0.0
	art.scale = Vector2(ITEM_SCALE, ITEM_SCALE)
	art.position = place
	_items.append(art)


## Shows `definitions`' items in the bag at once, in order (a resumed checkout's end state).
func show_items(definitions: Array[CardDefinition]) -> void:
	clear()
	for definition: CardDefinition in definitions:
		add_item(definition)


## The bagged items' art, in bagging order.
func items() -> Array[Control]:
	return _items.duplicate()


## Where the next bagged item will peek out (global, at 1x): the hop's end.
func next_peek_rect() -> Rect2:
	var place: Vector2 = PEEKS[_items.size() % PEEKS.size()]
	return get_global_transform() * Rect2(place, ITEM_SIZE)


## The bag's mouth (global): where a bagged item's effects start from.
func mouth_rect() -> Rect2:
	return get_global_transform() * MOUTH_RECT


## An item landed in the bag: it squashes about its foot and wobbles back, unless `reduced`.
func land(reduced: bool = false) -> void:
	_stop_squash()
	if reduced or not (make_tween.is_valid() or is_inside_tree()):
		return
	_squash = make_tween.call() as Tween if make_tween.is_valid() else create_tween()
	_squash.tween_method(_set_squash, 0.0, 1.0, SQUASH_S)
	_squash.tween_callback(_end_squash)


## Whether the bag is squashing from a landing.
func is_squashing() -> bool:
	return _squash != null and _squash.is_valid()


## Empties the bag (its items and any item hopping in) and stops its squash.
func clear() -> void:
	_stop_squash()
	for child: Node in contents.get_children():
		contents.remove_child(child)
		child.queue_free()
	_items.clear()


## The squash `progress` (0 to 1) through its wobble.
func _set_squash(progress: float) -> void:
	var wobble: float = sin(progress * SQUASH_S * SQUASH_RATE) * (1.0 - progress)
	scale = Vector2(1.0 + wobble * SQUASH_X, 1.0 - wobble * SQUASH_Y)


func _end_squash() -> void:
	_squash = null
	scale = Vector2.ONE


func _stop_squash() -> void:
	if _squash != null:
		_squash.kill()
		_squash = null
	scale = Vector2.ONE
