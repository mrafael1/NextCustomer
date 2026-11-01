class_name BasketRedraw
extends Node
## The basket redraw's motion (plan section 3.8; mock-up redraw_basket_v1.html, approved by the
## user on 2026-10-22), every timing from RedrawTuning (data/balance/redraw.tres):
## - the hover in redraw mode (hover): the hovered basket and its items ease up and wobble about
##   the basket's centre-bottom, then settle; leaving eases them back;
## - the redraw (play): the picked basket squashes, tips toward the Cart about its right corner
##   (lifted and pulled left) and rights itself with an overshoot; its old items leave from where
##   they stand in the tipped basket, each on an arc into the Cart button (shrinking, spinning,
##   fading at the end) while the Cart bumps; the new items pop up out of the basket (hidden under
##   its front until they clear the rim, clipped at its foot) with sparks, land with a squash, and
##   the basket dips as each lands. Reduced motion: the old items fade out in place, then the new
##   ones fade in.
## The pose of a basket (pose()) moves its art in both basket layers (HandBaskets.set_pose), its
## REDRAW tag (BasketTags.set_pose) and its items in the hand. The flights and sparks are drawn
## in the stage's redraw layer (over the top bar); the old items before they fly and the new ones
## popping in its pop layer (between the hand and the basket fronts).
##
## Display only: the run was changed (logged and saved) at the click; this gets the views to show
## and never calls RunState. `finished` is emitted at the end, with every pose back at rest.

signal finished

const TUNING_PATH := "res://data/balance/redraw.tres"
## A basket's pivots (from its left edge, stage y): its centre-bottom (the squash and the hover's
## wobble) and its right corner (the tip).
const CENTRE_X := 104.0
const CORNER_X := 206.0
const PIVOT_Y := 688.0
## The sparks: their cell, their colours, where they start (the rim, an item's centre) and how
## the mock-up spreads them (x and y factors of their speed).
const SPARK_SIZE := 8.0
const SPARK_COLORS: Array[Color] = [Palette.GOLD, Palette.PAPER, Palette.TEAL_LIGHT]
const SPARK_Y := 604.0
const SPARK_SPREAD := Vector2(0.6, 0.7)
## A tipped basket's shadows are gone by this angle (degrees).
const SHADOW_FADE_DEG := 6.0

## The motion's timings.
var tuning: RedrawTuning
## Returns true when the player asked for reduced motion. None means false.
var reduced_motion: Callable = Callable()

var _stage: ShiftStage
## The hover: per basket whether it is hovered, when that changed and the pose it left from.
var _hover_on: Array[bool] = []
var _hover_t: Array[float] = []
var _hover_lift: Array[float] = []
var _hover_angle: Array[float] = []
var _time: float = 0.0
## The redraw playing: its basket, its start, the old ghosts (with their places), the new ghosts
## and the real views they become, the Cart's centre (stage) and whether it is reduced.
var _playing: bool = false
var _basket: int = -1
var _start: float = 0.0
var _places: Array[int] = []
var _old: Array[Control] = []
var _old_flying: Array[bool] = []
var _new: Array[Control] = []
var _cart: Vector2 = Vector2.ZERO
var _reduced: bool = false
var _sparks: Array[Rect2] = []
var _spark_colors: Array[Color] = []
## The baskets posed last frame (to put back at rest once they settle).
var _posed: Dictionary[int, bool] = {}


func _init() -> void:
	name = "BasketRedraw"
	tuning = load(TUNING_PATH)


## Follows `stage`: its baskets, hand, tags, Cart and the pop and redraw layers.
func setup(stage: ShiftStage) -> void:
	_stage = stage
	_stage.redraw_layer.draw.connect(_draw_sparks)


func is_playing() -> bool:
	return _playing


## A display-only copy of `card`'s basket item (its aisle from `balance`), for the motion.
static func ghost(card: CardInstance, balance: BalanceDefinition) -> Control:
	var view: ItemView = ItemView.new(card, balance.aisle_of(card.definition), ItemView.Form.BASKET)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return view


## The hovered basket in redraw mode (-1: none).
func hover(basket: int) -> void:
	for index: int in range(_hover_on.size(), maxi(basket + 1, _hover_on.size())):
		_hover_on.append(false)
		_hover_t.append(-INF)
		_hover_lift.append(0.0)
		_hover_angle.append(0.0)
	for index: int in range(_hover_on.size()):
		var on: bool = index == basket
		if on == _hover_on[index]:
			continue
		var lift_angle: Vector2 = _hover_pose(index)
		_hover_on[index] = on
		_hover_t[index] = _time
		_hover_lift[index] = lift_angle.x
		_hover_angle[index] = lift_angle.y


## Plays the redraw of basket `basket`: `places` are the hand places swapped (left first),
## `old_views` the views of the cards that leave (in the places' order) and `new_views` views of
## the cards that come, both ghosts built for the motion (not in the tree); the real views of the
## new cards are already in the hand at those places. Emits `finished` when done.
func play(
	basket: int, places: Array[int], old_views: Array[Control], new_views: Array[Control]
) -> void:
	_end_play()
	_playing = true
	_basket = basket
	_start = _time
	_places = places.duplicate()
	_reduced = _wants_reduced_motion()
	var cart: Control = _stage.deck_button
	var inverse: Transform2D = _stage.get_global_transform().affine_inverse()
	_cart = inverse * cart.get_global_rect().get_center()
	for index: int in range(places.size()):
		var real: Control = _real_view(index)
		if real != null:
			real.modulate.a = 0.0
		if index < old_views.size():
			_stage.pop_layer.add_child(old_views[index])
			old_views[index].size = ItemView.BASKET_SIZE
			_old.append(old_views[index])
			_old_flying.append(false)
		if index < new_views.size():
			_stage.pop_layer.add_child(new_views[index])
			new_views[index].size = ItemView.BASKET_SIZE
			new_views[index].modulate.a = 0.0
			_new.append(new_views[index])
	_step()


## Ends the motion at once (the screen closes or a new shift starts): everything at rest.
func stop() -> void:
	if _playing:
		_end_play()
		finished.emit()


func _process(delta: float) -> void:
	_time += delta
	if _playing and _time - _start >= tuning.duration(_reduced):
		_end_play()
		finished.emit()
		return
	_step()


## Poses every basket that moves this frame, and the redraw's ghosts.
func _step() -> void:
	if _stage == null:
		return
	var posed: Dictionary[int, bool] = {}
	for basket: int in range(_hover_on.size()):
		if _hover_on[basket] or _time - _hover_t[basket] < tuning.hover_in_s:
			posed[basket] = true
	if _playing and not _reduced:
		posed[_basket] = true
	for basket: int in _posed:
		if not posed.has(basket):
			_apply_pose(basket, Transform2D.IDENTITY, 0.0)
	for basket: int in posed:
		var lefts: Array[float] = _stage.baskets.basket_lefts()
		if basket >= lefts.size():
			continue
		var u: float = _time - _start if _playing and basket == _basket else INF
		var pose_now: Transform2D = _pose_of(basket, lefts[basket], u)
		_apply_pose(basket, pose_now, _tip(u, tuning))
	_posed = posed
	if _playing:
		_step_items()
	_step_cart()
	_stage.redraw_layer.queue_redraw()


## Basket `basket`'s pose: the redraw's (at `u` seconds into it; INF: none) and the hover's.
func _pose_of(basket: int, left: float, u: float) -> Transform2D:
	var hover_now: Vector2 = Vector2.ZERO if _reduced_now() else _hover_pose(basket)
	var incoming: int = _new.size() if u < INF else 0
	return pose(left, u, tuning, incoming, hover_now.x, hover_now.y)


## The hover's lift (x, px) and wobble (y, degrees) for basket `basket` now.
func _hover_pose(basket: int) -> Vector2:
	if basket >= _hover_on.size():
		return Vector2.ZERO
	var since: float = maxf(0.0, _time - _hover_t[basket])
	var ease_in: float = _ease_out(clampf(since / maxf(tuning.hover_in_s, 0.001), 0.0, 1.0))
	if _hover_on[basket]:
		var fade: float = clampf(1.0 - since / maxf(tuning.hover_wobble_s, 0.001), 0.0, 1.0)
		var wobble: float = tuning.hover_wobble_deg * sin(since * tuning.hover_wobble_rate) * fade
		return Vector2(tuning.hover_lift * ease_in, wobble)
	var back: float = 1.0 - ease_in
	return Vector2(_hover_lift[basket] * back, _hover_angle[basket] * back)


## A basket's pose on the stage (a Transform2D about its art) at `u` seconds into its redraw
## (INF or below 0: none), with `incoming` new items landing in it, lifted `lift` px and wobbled
## `wobble` degrees by the hover: the squash about its centre-bottom, the tip about its right
## corner (lifted and pulled left), the wobble about its centre-bottom, then the lift and the dips.
static func pose(
	left: float,
	u: float,
	timing: RedrawTuning,
	incoming: int = 0,
	lift: float = 0.0,
	wobble: float = 0.0
) -> Transform2D:
	var squash: Vector2 = Vector2.ONE
	var offset: Vector2 = Vector2(0.0, -lift)
	var tip: float = 0.0
	if u >= 0.0 and u < INF:
		var squash_end: float = timing.squash_s + timing.tip_in_s
		if u < timing.squash_s:
			var k: float = _ease_out(u / timing.squash_s)
			squash = Vector2(1.0 + timing.squash_x * k, 1.0 - timing.squash_y * k)
		elif u < squash_end:
			var back: float = 1.0 - _ease_out((u - timing.squash_s) / timing.tip_in_s)
			squash = Vector2(1.0 + timing.squash_x * back, 1.0 - timing.squash_y * back)
		tip = _tip(u, timing)
		offset += Vector2(-timing.tip_pull * tip, -timing.tip_lift * tip)
		for k: int in range(incoming):
			var landed: float = u - (timing.in_start_s + timing.in_gap_s * k + timing.in_s)
			var dip: float = _bump(landed, timing.dip_s)
			offset.y += timing.dip * dip
			squash.y *= 1.0 - timing.dip_squash * dip
	var centre: Vector2 = Vector2(left + CENTRE_X, PIVOT_Y)
	var corner: Vector2 = Vector2(left + CORNER_X, PIVOT_Y)
	var xform: Transform2D = _about(centre, Transform2D(0.0, squash, 0.0, Vector2.ZERO))
	xform = _about(corner, Transform2D(deg_to_rad(timing.tip_deg * tip), Vector2.ZERO)) * xform
	xform = _about(centre, Transform2D(deg_to_rad(wobble), Vector2.ZERO)) * xform
	return Transform2D(0.0, offset) * xform


## How far the basket is tipped (0 to 1, past 0 in the overshoot) at `u` seconds into its redraw.
static func _tip(u: float, timing: RedrawTuning) -> float:
	if u < timing.squash_s or u >= INF:
		return 0.0
	var tipped: float = timing.squash_s + timing.tip_in_s
	if u < tipped:
		return _ease_out((u - timing.squash_s) / timing.tip_in_s)
	var held: float = tipped + timing.hold_s
	if u < held:
		return 1.0
	if u < held + timing.right_s:
		return 1.0 - _ease_back((u - held) / timing.right_s, timing.right_overshoot)
	return 0.0


## Poses basket `basket` and what moves with it: its art in both layers, its tag and its items
## in the hand (the hidden new ones included).
func _apply_pose(basket: int, xform: Transform2D, tip: float) -> void:
	var shadow: float = 1.0 - clampf(absf(tip) * tuning.tip_deg / SHADOW_FADE_DEG, 0.0, 1.0)
	_stage.baskets.set_pose(basket, xform, shadow)
	_stage.basket_fronts.set_pose(basket, xform)
	_stage.basket_tags.set_pose(basket, xform)
	var per: int = HandRow.ITEMS_PER_BASKET
	for place: int in range(basket * per, (basket + 1) * per):
		var view: Control = _stage.hand.view_at(place)
		if view != null:
			_pose_view(view, _stage.hand.position, _stage.hand.place_position(place), xform)


## Places `view` (a child of a layer at `layer_origin`, its rest at `rest` in that layer) as its
## basket's `xform` moves it.
static func _pose_view(
	view: Control, layer_origin: Vector2, rest: Vector2, xform: Transform2D
) -> void:
	view.position = xform * (layer_origin + rest) - layer_origin
	view.rotation = xform.get_rotation()
	view.scale = xform.get_scale()


## The old items (in the basket, then flying) and the new ones (popping, then landing).
func _step_items() -> void:
	var u: float = _time - _start
	var lefts: Array[float] = _stage.baskets.basket_lefts()
	var left: float = lefts[_basket] if _basket < lefts.size() else 0.0
	var hand_origin: Vector2 = _stage.hand.position
	_sparks = []
	_spark_colors = []
	for k: int in range(_old.size()):
		var rest: Vector2 = hand_origin + _stage.hand.place_position(_places[k])
		if _reduced:
			_old[k].position = rest
			_old[k].modulate.a = 1.0 - clampf(u / maxf(tuning.rm_out_s, 0.001), 0.0, 1.0)
			continue
		var leaves: float = tuning.out_start_s + tuning.out_gap_s * k
		if u < leaves:
			_pose_view(_old[k], Vector2.ZERO, rest, _pose_of(_basket, left, u))
			continue
		_fly(k, rest, (u - leaves) / tuning.out_s, _pose_of(_basket, left, leaves))
	for k: int in range(_new.size()):
		_pop(k, u, hand_origin + _stage.hand.place_position(_places[k]), left)


## Old item `k` at `progress` (0 to 1) of its flight from where it stood (`rest` in the basket
## posed `from`) into the Cart.
func _fly(k: int, rest: Vector2, progress: float, from: Transform2D) -> void:
	var view: Control = _old[k]
	if not _old_flying[k]:
		_old_flying[k] = true
		view.reparent(_stage.redraw_layer, false)
	var t: float = clampf(progress, 0.0, 1.0)
	var centre: Vector2 = _centre_of(view)
	var start: Vector2 = from * rest
	var end: Vector2 = _cart - centre
	var control: Vector2 = Vector2(
		(start.x + end.x) / 2.0, minf(start.y, end.y) - tuning.arc_height
	)
	var eased: float = _ease_in_out(t)
	var at: Vector2 = start.lerp(control, eased).lerp(control.lerp(end, eased), eased)
	var spin: float = (1.0 if k % 2 == 0 else -1.0) * tuning.out_spin_deg * t * t
	var size_now: float = 1.0 - (1.0 - tuning.out_scale) * t
	var turn: float = from.get_rotation() + deg_to_rad(spin)
	# About its centre: the turned, shrunk centre stays where the unturned one would be.
	var turned: Transform2D = Transform2D(turn, Vector2.ONE * size_now, 0.0, Vector2.ZERO)
	view.position = at + centre - turned * centre
	view.rotation = turn
	view.scale = Vector2.ONE * size_now
	var fade_from: float = 1.0 - tuning.out_fade
	view.modulate.a = 1.0 if t <= fade_from else 1.0 - (t - fade_from) / tuning.out_fade
	view.visible = progress < 1.0


## New item `k` at `u` seconds into the redraw, its rest at `rest` (stage), in basket at `left`.
func _pop(k: int, u: float, rest: Vector2, left: float) -> void:
	var view: Control = _new[k]
	# Fetched every frame, not kept from play(): a hand refresh during the motion rebuilds the
	# views, and the new ones must stay hidden until their pop lands.
	var real: Control = _real_view(k)
	var starts: float = tuning.pop_start(k, _reduced)
	if _reduced:
		view.visible = false
		if real != null:
			real.modulate.a = clampf((u - starts) / maxf(tuning.rm_in_s, 0.001), 0.0, 1.0)
		return
	var landed: float = starts + tuning.in_s
	var settled: float = landed + tuning.land_in_s + tuning.land_out_s
	if u < starts or u >= settled:
		view.modulate.a = 0.0
		if real != null:
			real.modulate.a = 1.0 if u >= settled else 0.0
		return
	view.modulate.a = 1.0
	if real != null:
		real.modulate.a = 0.0
	var rise: float = 0.0
	var stretch: Vector2 = Vector2.ONE
	if u < landed:
		var k_in: float = (u - starts) / tuning.in_s
		rise = tuning.pop_rise * (1.0 - _ease_back(k_in, tuning.pop_overshoot))
		stretch = Vector2(
			lerpf(tuning.pop_scale_x, 1.0, k_in), lerpf(tuning.pop_scale_y, 1.0, k_in)
		)
	elif u < landed + tuning.land_in_s:
		var k_land: float = (u - landed) / tuning.land_in_s
		stretch = Vector2(1.0 + tuning.land_squash_x * k_land, 1.0 - tuning.land_squash_y * k_land)
	else:
		var back: float = 1.0 - _ease_out((u - landed - tuning.land_in_s) / tuning.land_out_s)
		stretch = Vector2(1.0 + tuning.land_squash_x * back, 1.0 - tuning.land_squash_y * back)
	var basket_pose: Transform2D = _pose_of(_basket, left, u)
	var foot: Vector2 = _foot_of(view)
	var local: Vector2 = rest + Vector2(0.0, rise) + foot - foot * stretch
	view.position = basket_pose * local
	view.rotation = basket_pose.get_rotation()
	view.scale = basket_pose.get_scale() * stretch
	if u - starts < tuning.spark_s:
		_add_sparks(k, u - starts, Vector2(rest.x + ItemView.SPRITE_SIZE.x / 2.0, SPARK_Y))


## The hand's current view at the k-th swapped place (null: none, or no stage).
func _real_view(k: int) -> Control:
	if _stage == null or k >= _places.size():
		return null
	var view: Control = _stage.hand.view_at(_places[k])
	return view if is_instance_valid(view) else null


## Item `k`'s sparks `age` seconds after its pop started, from `origin` (stage).
func _add_sparks(k: int, age: float, origin: Vector2) -> void:
	for index: int in range(tuning.sparks):
		var seed_value: int = index + tuning.sparks * k + (_places[k] % 2) * 6
		var span: int = maxi(roundi(tuning.spark_angle_span_deg), 1)
		var angle: float = deg_to_rad(tuning.spark_angle_from_deg + float((seed_value * 47) % span))
		var spread: float = fmod(float(seed_value * 37), maxf(tuning.spark_speed_spread, 1.0))
		var speed: float = tuning.spark_speed + spread
		var side: float = 1.0 if seed_value % 2 == 1 else -1.0
		var x: float = origin.x + cos(angle) * speed * age * side * SPARK_SPREAD.x
		var y: float = (
			origin.y
			+ sin(angle) * speed * age * SPARK_SPREAD.y
			+ tuning.spark_gravity / 2.0 * age * age
		)
		var cell: Vector2 = Vector2(roundf(x / 2.0) * 2.0, roundf(y / 2.0) * 2.0)
		_sparks.append(Rect2(cell, Vector2.ONE * SPARK_SIZE))
		var color: Color = SPARK_COLORS[seed_value % SPARK_COLORS.size()]
		color.a = 1.0 - age / (tuning.spark_s + 0.02)
		_spark_colors.append(color)


## The Cart button bumps as each old item lands in it and, less, as each new one leaves it.
func _step_cart() -> void:
	var cart: Control = _stage.deck_button
	if not _playing or _reduced:
		if cart.scale != Vector2.ONE:
			cart.scale = Vector2.ONE
		return
	var u: float = _time - _start
	var bump: float = 0.0
	for k: int in range(_old.size()):
		var lands: float = tuning.out_start_s + tuning.out_gap_s * k + tuning.out_s
		bump += _bump(u - lands, tuning.cart_bump_s)
	for k: int in range(_new.size()):
		bump += tuning.cart_leave * _bump(u - tuning.pop_start(k, false), tuning.cart_bump_s)
	cart.pivot_offset = cart.size / 2.0
	cart.scale = Vector2.ONE * (1.0 + tuning.cart_bump * clampf(bump, 0.0, 1.4))


func _draw_sparks() -> void:
	for index: int in range(_sparks.size()):
		_stage.redraw_layer.draw_rect(_sparks[index], _spark_colors[index])


## Ends the motion: the ghosts gone, the real views shown, every pose at rest.
func _end_play() -> void:
	for view: Control in _old + _new:
		if is_instance_valid(view):
			view.get_parent().remove_child(view)
			view.queue_free()
	for index: int in range(_places.size()):
		var real: Control = _real_view(index)
		if real != null:
			real.modulate.a = 1.0
	var was: int = _basket
	_playing = false
	_basket = -1
	_old = []
	_old_flying = []
	_new = []
	_places = []
	_sparks = []
	_spark_colors = []
	if _stage != null:
		if was >= 0:
			_apply_pose(was, Transform2D.IDENTITY, 0.0)
		_stage.deck_button.scale = Vector2.ONE
		_stage.redraw_layer.queue_redraw()


## The centre of `view`'s sprite, in its own coordinates.
static func _centre_of(view: Control) -> Vector2:
	var item: ItemView = view as ItemView
	if item == null or not item.is_inside_tree():
		return view.size / 2.0
	return item.get_global_transform().affine_inverse() * item.center()


## The foot of `view`'s sprite (its bottom centre), in its own coordinates.
static func _foot_of(view: Control) -> Vector2:
	var item: ItemView = view as ItemView
	if item == null or not item.is_inside_tree():
		return Vector2(view.size.x / 2.0, view.size.y)
	var inverse: Transform2D = item.get_global_transform().affine_inverse()
	var sprite_rect: Rect2 = item.sprite().get_global_rect()
	return inverse * Vector2(sprite_rect.get_center().x, sprite_rect.end.y)


func _reduced_now() -> bool:
	return (_playing and _reduced) or _wants_reduced_motion()


func _wants_reduced_motion() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())


static func _about(point: Vector2, xform: Transform2D) -> Transform2D:
	return Transform2D(0.0, point) * xform * Transform2D(0.0, -point)


static func _ease_out(k: float) -> float:
	return 1.0 - pow(1.0 - clampf(k, 0.0, 1.0), 3.0)


static func _ease_in_out(k: float) -> float:
	return 2.0 * k * k if k < 0.5 else 1.0 - pow(-2.0 * k + 2.0, 2.0) / 2.0


## The back ease (1 at k = 1, overshooting past it before) with `overshoot` as its c1.
static func _ease_back(k: float, overshoot: float) -> float:
	var c3: float = overshoot + 1.0
	var x: float = clampf(k, 0.0, 1.0) - 1.0
	return 1.0 + c3 * x * x * x + overshoot * x * x


## A sine bump over `length` seconds from v = 0 (0 outside it).
static func _bump(v: float, length: float) -> float:
	if v < 0.0 or v > length or length <= 0.0:
		return 0.0
	return sin(PI * v / length)
