class_name KeepScreen
extends Control
## The Golden basket's keep screen (#132; the user's call of 2026-11-02: "golden basket in the
## center, the previous conveyor items listed, drag and drop inside it"). Over the shift screen
## after the count-up, before the machine: the shade, GOLDEN BASKET and its hint, the golden
## basket drawn as the hand's (its back, its places, the inside's darkening, its front) at
## BASKET_SCALE in the middle, and under it LAST CHECKOUT, the items the checkout put on the belt.
## An item dragged from the list into the basket is kept for the next shift's first basket
## (PinPlay.keep, up to keep_count); one dragged out of the basket back to the list lets it go. A
## click does the same (into the first free place, or back out). DONE closes it (`done`).
##
## The drag feels like the shift screen's (CardDrag; the user's 2026-11-02 review: "not as smooth
## as in the shift scene"): past DRAG_THRESHOLD a ghost of the item (ItemView.Form.GHOST, lifted
## and tilted) follows the mouse centred on it, its source fades, the target it would land on
## lights up with a slot tick (the basket brightens, and over it the ghost grows to the
## basket's size; the belt brightens), and a drop pops the item into its new place. A drop
## elsewhere flies the ghost back to where it came from.

## DONE was pressed.
signal done

enum Target { NONE, BASKET, LIST }

const TITLE := "GOLDEN BASKET"
const HINT := "Drag up to %d items into the basket: they start the next shift"
const LIST_TITLE := "LAST CHECKOUT"
const DONE_TEXT := "DONE"
const SHADE_ALPHA := 0.84
const TITLE_SIZE := 36
const HINT_SIZE := 16
const LIST_TITLE_SIZE := 14
const BUTTON_SIZE := 18
const BASKET_SCALE := 2.0
## The basket unit as the hand draws one (in its own coordinates, its rim's left at 0): the back,
## the item places, the inside's darkening and the front (HandBaskets, HandRow).
const UNIT_SIZE := Vector2(216, 164)
const BACK_AT := Vector2(0, 60)
const FRONT_AT := Vector2(0, 76)
const PLACE_AT: Array[Vector2] = [Vector2(12, 0), Vector2(108, 0)]
const PLACE_SIZE := Vector2(96, 96)
const INSIDE_STEPS: Array[Rect2] = [Rect2(8, 70, 200, 4), Rect2(8, 74, 200, 4)]
const INSIDE_ALPHAS: Array[float] = [0.14, 0.28]
## Where things sit on the 1280 x 720 screen: the title's and hint's tops, the basket's top, the
## list's top, and DONE's top.
const TITLE_Y := 48.0
const HINT_Y := 96.0
const BASKET_Y := 132.0
const LIST_Y := 488.0
const DONE_Y := 640.0
## The belt under the list: its padding, its steel edges, its width when it holds few items, and
## the widest it gets (cells shrink past BELT_MAX_WIDTH's ten items: a Double checkout's 14).
const CELL_SIZE := 96.0
const CELL_GAP := 10
const BELT_PADDING := Vector2(14, 10)
const BELT_EDGE := 6
const BELT_MIN_WIDTH := 560.0
const BELT_MAX_WIDTH := 1180.0
const DRAG_KIND := "keep_item"
## The drag (as CardDrag's): the ghost's alpha, the source's fade, the target's light, the
## ghost's grow time, the way back, and a landing's pop.
const GHOST_ALPHA := 0.92
const SOURCE_ALPHA := 0.3
const TARGET_LIGHT := Color(1.18, 1.14, 1.04)
const GROW_TIME := 0.12
const BACK_TIME := 0.14
const POP_SCALE := 1.25
const POP_TIME := 0.22

var _run: RunState
var _basket: Control
var _places: Array[Control] = []
var _belt: PanelContainer
var _list: HBoxContainer
var _cards: Array[CardInstance] = []
var _done_button: FramedButton
## The drag: the card pressed (null: none), whether it came from the basket, where the press was,
## whether it became a drag, its ghost, the faded source and the target under the mouse.
var _carried: CardInstance
var _from_basket: bool = false
var _press_at: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _ghost: ItemView
var _source: Control
var _target: Target = Target.NONE
var _swell: Tween
## The card whose new place pops at the next _show.
var _popped: CardInstance


## The screen for `run`'s checked-out items (PinPlay.keepable).
func _init(run: RunState) -> void:
	_run = run
	name = "KeepScreen"
	mouse_filter = Control.MOUSE_FILTER_STOP
	_cards = PinPlay.keepable(run)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(Palette.INK, SHADE_ALPHA)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var title: Label = UiKit.display_label(TITLE, TITLE_SIZE, true)
	title.add_theme_color_override("font_color", Palette.GOLD)
	_centre_label(title, TITLE_Y)
	var hint: Label = UiKit.body_label(HINT % PinPlay.keep_count(run), HINT_SIZE, Palette.PAPER)
	_centre_label(hint, HINT_Y)
	_build_basket()
	var list_title: Label = UiKit.display_label(LIST_TITLE, LIST_TITLE_SIZE, true)
	_centre_label(list_title, LIST_Y - 26.0)
	_build_belt()
	_done_button = UiKit.framed_button(null, DONE_TEXT, done.emit, BUTTON_SIZE)
	_done_button.name = "KeepDone"
	add_child(_done_button)
	_show()


func _ready() -> void:
	_place_parts()
	resized.connect(_place_parts)


## The basket's two places, left first (for tests: their global rects are the drop targets).
func places() -> Array[Control]:
	return _places.duplicate()


## The golden basket (for layout tests).
func basket() -> Control:
	return _basket


## The list's cells, one per item not kept (for tests).
func list_cells() -> Array[Control]:
	var cells: Array[Control] = []
	for child: Node in _list.get_children():
		cells.append(child as Control)
	return cells


func done_button() -> FramedButton:
	return _done_button


## Keeps `card` (a drop into the basket, or a click in the list); false when it can't be.
func keep(card: CardInstance) -> bool:
	if PinPlay.is_kept(_run, card) or not PinPlay.keep(_run, card):
		Sfx.play_at(self, "denied")
		return false
	Sfx.play_at(self, "card_place")
	_popped = card
	_show()
	return true


## Lets `card` go (a drag out of the basket, or a click on it there).
func release(card: CardInstance) -> bool:
	if not PinPlay.is_kept(_run, card) or not PinPlay.keep(_run, card):
		return false
	Sfx.play_at(self, "card_return")
	_popped = card
	_show()
	return true


func _build_basket() -> void:
	_basket = Control.new()
	_basket.name = "GoldenBasket"
	_basket.size = UNIT_SIZE
	_basket.scale = Vector2(BASKET_SCALE, BASKET_SCALE)
	_basket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_basket)
	_add_art(HandBaskets.BACK_LEFT_GOLDEN, BACK_AT)
	for index: int in PLACE_AT.size():
		var place: Control = Control.new()
		place.name = "Place%d" % index
		place.position = PLACE_AT[index]
		place.size = PLACE_SIZE
		place.mouse_filter = Control.MOUSE_FILTER_STOP
		place.gui_input.connect(_on_place_input.bind(index))
		_basket.add_child(place)
		_places.append(place)
	for step: int in INSIDE_STEPS.size():
		var inside: ColorRect = ColorRect.new()
		inside.color = Color(Palette.INK, INSIDE_ALPHAS[step])
		inside.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inside.position = INSIDE_STEPS[step].position
		inside.size = INSIDE_STEPS[step].size
		_basket.add_child(inside)
	_add_art(HandBaskets.FRONT_GOLDEN, FRONT_AT)


## The belt the list's items lie on (a drop anywhere on it lets a kept item go).
func _build_belt() -> void:
	_belt = PanelContainer.new()
	_belt.name = "LastCheckout"
	_belt.mouse_filter = Control.MOUSE_FILTER_STOP
	_belt.custom_minimum_size = Vector2(BELT_MIN_WIDTH, CELL_SIZE + 2.0 * BELT_PADDING.y)
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Palette.RUBBER
	box.border_color = Palette.STEEL_PALE
	box.border_width_top = BELT_EDGE
	box.border_width_bottom = BELT_EDGE
	box.set_corner_radius_all(6)
	box.content_margin_left = BELT_PADDING.x
	box.content_margin_right = BELT_PADDING.x
	box.content_margin_top = BELT_PADDING.y
	box.content_margin_bottom = BELT_PADDING.y
	_belt.add_theme_stylebox_override("panel", box)
	add_child(_belt)
	_list = HBoxContainer.new()
	_list.alignment = BoxContainer.ALIGNMENT_CENTER
	_list.add_theme_constant_override("separation", CELL_GAP)
	_list.mouse_filter = Control.MOUSE_FILTER_PASS
	_belt.add_child(_list)


func _add_art(texture: Texture2D, at: Vector2) -> void:
	var art: TextureRect = UiKit.sprite(texture)
	art.position = at
	art.size = texture.get_size()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_basket.add_child(art)


func _centre_label(label: Label, y: float) -> void:
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	label.position.y = y
	add_child(label)


func _place_parts() -> void:
	var width: float = size.x if size.x > 0.0 else get_viewport_rect().size.x
	_basket.position = Vector2((width - UNIT_SIZE.x * BASKET_SCALE) / 2.0, BASKET_Y)
	_belt.reset_size()
	_belt.position = Vector2((width - _belt.size.x) / 2.0, LIST_Y)
	_done_button.reset_size()
	_done_button.position = Vector2((width - _done_button.size.x) / 2.0, DONE_Y)


## Shows the kept items in the basket's places (kept order) and the others in the list.
func _show() -> void:
	var kept: Array[CardInstance] = _kept_cards()
	for index: int in _places.size():
		var place: Control = _places[index]
		for child: Node in place.get_children():
			place.remove_child(child)
			child.queue_free()
		place.tooltip_text = ""
		if index < kept.size():
			var art: TextureRect = ItemView.item_art(kept[index].definition)
			art.mouse_filter = Control.MOUSE_FILTER_IGNORE
			place.add_child(art)
			place.tooltip_text = kept[index].definition.display_name
			if kept[index] == _popped:
				_pop(art)
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var side: float = _cell_side(_cards.size() - kept.size())
	for card: CardInstance in _cards:
		if not kept.has(card):
			var cell: Control = _list_cell(card, side)
			_list.add_child(cell)
			if card == _popped:
				_pop(cell.get_child(0) as Control)
	_popped = null
	if is_inside_tree():
		_place_parts()


## A list cell's side: CELL_SIZE, or less when `count` cells would make the belt wider than
## BELT_MAX_WIDTH.
static func _cell_side(count: int) -> float:
	if count <= 0:
		return CELL_SIZE
	var room: float = BELT_MAX_WIDTH - 2.0 * BELT_PADDING.x - CELL_GAP * (count - 1)
	return minf(CELL_SIZE, floorf(room / count))


func _kept_cards() -> Array[CardInstance]:
	var kept: Array[CardInstance] = []
	for id: int in _run.kept:
		for card: CardInstance in _cards:
			if card.instance_id == id:
				kept.append(card)
	return kept


## A list cell: the item's art lying on the belt (scaled down to `side` when the belt is full);
## dragged into the basket (or clicked) it's kept.
func _list_cell(card: CardInstance, side: float) -> Control:
	var cell: Control = Control.new()
	cell.name = "Keep%d" % card.instance_id
	cell.tooltip_text = card.definition.display_name
	cell.custom_minimum_size = Vector2(side, side)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	cell.mouse_default_cursor_shape = Control.CURSOR_DRAG
	var art: TextureRect = ItemView.item_art(card.definition)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.scale = Vector2.ONE * (side / CELL_SIZE)
	cell.add_child(art)
	cell.gui_input.connect(_on_cell_input.bind(card))
	return cell


## Keeps the card a test drag `data` carries ({kind, card}; for tests, as a drop on the basket):
## whether it could be dropped there.
func can_drop_in(data: Variant) -> bool:
	var card: CardInstance = _card_of(data)
	if card == null or PinPlay.is_kept(_run, card):
		return false
	return _run.kept.size() < PinPlay.keep_count(_run)


## The ghost of the drag under way (for tests), or null.
func ghost() -> ItemView:
	return _ghost


static func _card_of(data: Variant) -> CardInstance:
	if data is Dictionary and (data as Dictionary).get("kind") == DRAG_KIND:
		return (data as Dictionary).get("card") as CardInstance
	return null


func _on_cell_input(event: InputEvent, card: CardInstance) -> void:
	if _is_press(event):
		var cell: Control = _list.get_node_or_null(NodePath("Keep%d" % card.instance_id))
		_arm(card, false, (event as InputEventMouseButton).global_position, cell)
		accept_event()


func _on_place_input(event: InputEvent, index: int) -> void:
	var kept: Array[CardInstance] = _kept_cards()
	if _is_press(event) and index < kept.size():
		_arm(kept[index], true, (event as InputEventMouseButton).global_position, _places[index])
		accept_event()


## A left button press.
static func _is_press(event: InputEvent) -> bool:
	var press: InputEventMouseButton = event as InputEventMouseButton
	return press != null and press.pressed and press.button_index == MOUSE_BUTTON_LEFT


## A press on `card` (from the basket when `from_basket`) at `at`, its art in `source`: a click
## or the start of a drag, whichever the mouse does next (_input).
func _arm(card: CardInstance, from_basket: bool, at: Vector2, source: Control) -> void:
	_cancel_drag()
	_carried = card
	_from_basket = from_basket
	_press_at = at
	_source = source


func _input(event: InputEvent) -> void:
	if _carried == null:
		return
	var motion: InputEventMouseMotion = event as InputEventMouseMotion
	if motion != null:
		if not motion.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_cancel_drag()  # The release was missed (outside the window).
		elif _dragging:
			_follow(motion.position)
		elif motion.position.distance_to(_press_at) >= CardDrag.DRAG_THRESHOLD:
			_start_drag(motion.position)
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT and not button.pressed:
		get_viewport().set_input_as_handled()
		_finish(button.position)


## The button is up at `at`: a click keeps or lets go of the card; a drag drops it on its target
## or flies back.
func _finish(at: Vector2) -> void:
	var card: CardInstance = _carried
	var from_basket: bool = _from_basket
	if not _dragging:
		_cancel_drag()
		if from_basket:
			release(card)
		else:
			keep(card)
		return
	var target: Target = _target_at(at)
	if target == Target.NONE:
		_fly_back()
		return
	_cancel_drag()
	if target == Target.BASKET:
		keep(card)
	else:
		release(card)


## The drag starts at `at`: the ghost (lifted, tilted, at its source's size) and the faded source.
func _start_drag(at: Vector2) -> void:
	_dragging = true
	var aisle: AisleDefinition = _run.balance.aisle_of(_carried.definition)
	_ghost = ItemView.new(_carried, aisle, ItemView.Form.GHOST)
	_ghost.name = "KeepGhost"
	_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ghost.z_index = 10
	add_child(_ghost)
	_ghost.body.scale = Vector2.ONE * _ghost_scale(_home_target())
	_ghost.body.rotation = deg_to_rad(CardDrag.GHOST_TILT)
	_ghost.body.modulate = Color(1, 1, 1, GHOST_ALPHA)
	if _source != null:
		_source.modulate.a = SOURCE_ALPHA
	Sfx.play_at(self, "card_pickup")
	_follow(at)


## The ghost follows the mouse, centred on it, and the target under it lights up.
func _follow(at: Vector2) -> void:
	_ghost.position = at - get_global_rect().position - ItemView.SPRITE_SIZE / 2.0
	_set_target(_target_at(at))


## The target a drop at `at` would land on: the basket for a listed card while it has room, the
## belt for a kept one; NONE elsewhere.
func _target_at(at: Vector2) -> Target:
	if _from_basket:
		return Target.LIST if _belt.get_global_rect().has_point(at) else Target.NONE
	var room: bool = _run.kept.size() < PinPlay.keep_count(_run)
	return Target.BASKET if room and _basket.get_global_rect().has_point(at) else Target.NONE


## Where the carried card came from, as a target.
func _home_target() -> Target:
	return Target.BASKET if _from_basket else Target.LIST


## Lights `target` (the other goes dark) with a tick, and grows or shrinks the ghost to its
## size there (back to its source's size off any target).
func _set_target(target: Target) -> void:
	if target == _target:
		return
	_target = target
	_basket.modulate = TARGET_LIGHT if target == Target.BASKET else Color.WHITE
	_belt.modulate = TARGET_LIGHT if target == Target.LIST else Color.WHITE
	if _swell != null:
		_swell.kill()
	if not is_inside_tree():
		return
	if _ghost != null:
		_swell = create_tween()
		var size_at: Target = _home_target() if target == Target.NONE else target
		var grown: Vector2 = Vector2.ONE * _ghost_scale(size_at)
		_swell.tween_property(_ghost.body, "scale", grown, GROW_TIME)
	if target != Target.NONE:
		Sfx.play_at(self, "slot_tick")


## The ghost's scale over `target`: the basket's items are drawn at BASKET_SCALE.
static func _ghost_scale(target: Target) -> float:
	return CardDrag.GHOST_SCALE * (BASKET_SCALE if target == Target.BASKET else 1.0)


## A drop off any target: the ghost flies back to its source and the drag ends there.
func _fly_back() -> void:
	var ghost_view: ItemView = _ghost
	_ghost = null
	var home: Vector2 = ghost_view.position
	if _source != null and is_instance_valid(_source):
		home = _source.get_global_rect().get_center() - get_global_rect().position
		home -= ItemView.SPRITE_SIZE / 2.0
	_cancel_drag()
	var back: Tween = ghost_view.create_tween()
	(
		back
		. tween_property(ghost_view, "position", home, BACK_TIME)
		. set_trans(Tween.TRANS_QUAD)
		. set_ease(Tween.EASE_OUT)
	)
	back.tween_callback(ghost_view.queue_free)


## Ends any drag: no ghost (unless _fly_back took it), the source and targets as they were.
func _cancel_drag() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	if _source != null and is_instance_valid(_source):
		_source.modulate.a = 1.0
	_source = null
	_carried = null
	_dragging = false
	_set_target(Target.NONE)


## A new place's item pops in.
func _pop(art: Control) -> void:
	if art == null or not is_inside_tree():
		return
	var rest: Vector2 = art.scale
	art.pivot_offset = art.size / 2.0
	art.scale = rest * POP_SCALE
	var pop: Tween = art.create_tween()
	pop.tween_property(art, "scale", rest, POP_TIME).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
