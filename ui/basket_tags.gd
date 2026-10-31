class_name BasketTags
extends Control
## The baskets' click targets and REDRAW tags in redraw mode (plan section 3.8; mock-up
## redraw_basket_v1.html, approved by the user on 2026-10-22). A stage layer over the basket
## fronts: while redraw mode is armed (show_tags) each basket that can be redrawn gets a hit area
## (HIT_TOP_Y to HIT_BOTTOM_Y: the items above the rim and the basket down to its feet) and a
## RedrawTag centred on its front (TAG_CENTRE_X from its left edge, its top at TAG_TOP_Y). An empty
## basket gets neither: it can't be clicked, and a click on it does nothing. Hovering a target
## makes its tag hot ("REDRAW 2" / "REDRAW 1": how many items the redraw swaps) and emits
## hovered_changed; a click emits basket_clicked. The tags follow their baskets' pose (set_pose,
## from BasketRedraw). Display and input only: the screen decides what a click does.
##
## The full redraw (#122, a badge pin): show_all puts a REDRAW ALL tag, its own click target,
## centred under the belt above the baskets (its top at ALL_TOP_Y); hovering it emits all_hovered
## and makes it hot ("REDRAW ALL 7"), a click emits all_clicked.

## A basket was clicked in redraw mode (its index, from the left).
signal basket_clicked(basket: int)
## The hovered basket changed (-1: none).
signal hovered_changed(basket: int)
## The REDRAW ALL tag was clicked (#122).
signal all_clicked
## The REDRAW ALL tag's hover changed (#122).
signal all_hovered(hot: bool)

const HIT_TOP_Y := 500.0
const HIT_BOTTOM_Y := 680.0
const TAG_CENTRE_X := 104.0
const TAG_TOP_Y := 620.0
const ALL_TOP_Y := 494.0
const ALL_WORD := "REDRAW ALL"

var _hits: Array[Control] = []
var _tags: Array[RedrawTag] = []
## How many items a redraw of each basket swaps (0: no tag, not clickable).
var _swaps: Array[int] = []
var _lefts: Array[float] = []
## Each tag's basket pose, kept to place the tag again when its size changes.
var _poses: Array[Transform2D] = []
var _hot: int = -1
## The REDRAW ALL tag (null: not shown) and how many items it swaps.
var _all: RedrawTag
var _all_swaps: int = 0


func _init() -> void:
	name = "BasketTags"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = ShiftStage.SIZE


## Shows a target and a tag on each basket at `lefts` (stage x of its rim's left edge) whose
## `counts` entry is above 0 (the items its redraw swaps). The hovered basket stays hot.
func show_tags(lefts: Array[float], counts: Array[int]) -> void:
	var hovered_before: int = _hot
	_clear_nodes()
	_lefts = lefts.duplicate()
	_swaps = []
	_poses = []
	for basket: int in range(lefts.size()):
		var count: int = counts[basket] if basket < counts.size() else 0
		_swaps.append(count)
		var target: Control = Control.new()
		target.name = "Hit%d" % basket
		target.position = Vector2(lefts[basket], HIT_TOP_Y)
		target.size = Vector2(HandRow.BASKET_WIDTH, HIT_BOTTOM_Y - HIT_TOP_Y)
		var stops: bool = count > 0
		target.mouse_filter = Control.MOUSE_FILTER_STOP if stops else Control.MOUSE_FILTER_IGNORE
		target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		target.mouse_entered.connect(_on_entered.bind(basket))
		target.mouse_exited.connect(_on_exited.bind(basket))
		target.gui_input.connect(_on_hit_input.bind(basket))
		add_child(target)
		_hits.append(target)
		var tag_node: RedrawTag = RedrawTag.new()
		tag_node.name = "Tag%d" % basket
		tag_node.visible = count > 0
		add_child(tag_node)
		_tags.append(tag_node)
		_poses.append(Transform2D.IDENTITY)
		# Its label measures with its real font once in the tree: placed again when it grows.
		tag_node.resized.connect(func() -> void: _place_tag(basket, _poses[basket]))
		_place_tag(basket, Transform2D.IDENTITY)
	_hot = -1
	if hovered_before >= 0 and hovered_before < _swaps.size() and _swaps[hovered_before] > 0:
		_set_hot(hovered_before)
	elif hovered_before >= 0:
		hovered_changed.emit(-1)


## Shows the REDRAW ALL tag swapping `count` items (0: takes it off), centred over the baskets
## show_tags placed. A tag already shown keeps its hover.
func show_all(count: int) -> void:
	_all_swaps = count
	if count <= 0 or _lefts.is_empty():
		_clear_all()
		return
	if _all == null:
		_all = RedrawTag.new()
		_all.name = "AllTag"
		_all.set_word(ALL_WORD)
		_all.mouse_filter = Control.MOUSE_FILTER_STOP
		_all.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_all.mouse_entered.connect(_on_all_hover.bind(true))
		_all.mouse_exited.connect(_on_all_hover.bind(false))
		_all.gui_input.connect(_on_all_input)
		_all.resized.connect(_place_all)
		add_child(_all)
	_place_all()


## The REDRAW ALL tag, or null when it isn't shown.
func all_tag() -> RedrawTag:
	return _all


## Takes every target and tag off (redraw mode ended, or the motion is playing).
func hide_tags() -> void:
	_clear_nodes()
	_clear_all()
	_swaps = []
	if _hot >= 0:
		_hot = -1
		hovered_changed.emit(-1)


func is_shown() -> bool:
	return not _hits.is_empty()


## Basket `basket`'s tag (shown or not), or null without targets.
func tag(basket: int) -> RedrawTag:
	return _tags[basket] if basket >= 0 and basket < _tags.size() else null


## Basket `basket`'s hit area, or null.
func hit(basket: int) -> Control:
	return _hits[basket] if basket >= 0 and basket < _hits.size() else null


## The hovered basket (-1: none).
func hovered() -> int:
	return _hot


## How many items a redraw of basket `basket` swaps, as shown (0: no tag).
func swaps(basket: int) -> int:
	return _swaps[basket] if basket >= 0 and basket < _swaps.size() else 0


## Moves basket `basket`'s tag with its pose (`pose`: the basket's transform on the stage).
func set_pose(basket: int, pose: Transform2D) -> void:
	if basket >= 0 and basket < _tags.size():
		_place_tag(basket, pose)


func _clear_nodes() -> void:
	for node: Control in _hits:
		remove_child(node)
		node.queue_free()
	for node: Control in _tags:
		remove_child(node)
		node.queue_free()
	_hits = []
	_tags = []


func _place_tag(basket: int, pose: Transform2D) -> void:
	var tag_node: RedrawTag = _tags[basket]
	_poses[basket] = pose
	var width: float = tag_node.tag_width()
	var at: Vector2 = Vector2(roundf(_lefts[basket] + TAG_CENTRE_X - width / 2.0), TAG_TOP_Y)
	tag_node.position = pose * at
	tag_node.rotation = pose.get_rotation()
	tag_node.scale = pose.get_scale()


func _clear_all() -> void:
	if _all == null:
		return
	var was_hot: bool = _all.is_hot()
	remove_child(_all)
	_all.queue_free()
	_all = null
	if was_hot:
		all_hovered.emit(false)


func _place_all() -> void:
	if _all == null:
		return
	var left: float = _lefts[0]
	var right: float = _lefts[_lefts.size() - 1] + HandRow.BASKET_WIDTH
	var at: float = roundf((left + right - _all.tag_width()) / 2.0)
	_all.position = Vector2(at, ALL_TOP_Y)


func _on_all_hover(hot: bool) -> void:
	if _all == null:
		return
	_all.set_hot(hot, _all_swaps if hot else 0)
	_place_all()
	all_hovered.emit(hot)


func _on_all_input(event: InputEvent) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		all_clicked.emit()


func _on_entered(basket: int) -> void:
	if basket < _swaps.size() and _swaps[basket] > 0:
		_set_hot(basket)


func _on_exited(basket: int) -> void:
	if _hot == basket:
		_set_hot(-1)


func _set_hot(basket: int) -> void:
	if _hot == basket:
		return
	_hot = basket
	for index: int in range(_tags.size()):
		var hot: bool = index == basket
		_tags[index].set_hot(hot, _swaps[index] if hot else 0)
		_place_tag(index, _poses[index])
	hovered_changed.emit(basket)


func _on_hit_input(event: InputEvent, basket: int) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		basket_clicked.emit(basket)
