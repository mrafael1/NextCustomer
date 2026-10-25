class_name BeltRide
extends Node
## The belt in the count (#86 v6, mock-up count_up_86_v6_scan approved by the user on 2026-10-19):
## the items come to the scanner, the row's first cell, one by one, and go into the paper bag on
## the counter once scanned. It follows the count-up (CountUp.ride, step_landed, beat_started) and
## moves nothing of its own accord: the count waits each ride gap while this plays it.
##
## A ride (CountUp.ride): the item scanned before hops into the bag (a copy of its art,
## PaperBag.art_of, arcs up HOP_ARC px and drops into the bag's mouth shrinking to 1x art, over
## the ride; its cell hides at once, and the bag squashes as it lands, PaperBag.land) while the row
## slides one cell left (RowStrip.ride_out hides the cells up to the arriving item's, which packs
## the rest left, and the box slides back from the width they left over the ride, smoothstep,
## snapped to the art grid) with the belt's slats in lockstep (BeltPanel.scroll). On arrival the
## scanner marks the item (ScanOverlay.pose_scanner) and sweeps it once. The last ride bags the
## last item and the scanner clears. Every motion is on the count-up's tweens (tween_maker), so
## hit-stops hold it and taps speed it; reduced motion snaps it (the item steps one cell, the
## bagged item shows in the bag at once, no sweep).
##
## The planning stickers ride on their items (PlanningEffects.show_count): as a step lands, the
## sticker of that step fires (EffectSticker.fire: a punch, a flash, then a check), and a loyalty
## upgrade's multiplier fires its slot's mark (SlotMark.fire: the Slot engine's talker); when an
## armed giver is scanned, gold sparks run from the scanner to the stickers of its targets still
## on the belt (GiverSparks), each charging as they land. No sparks or punches under reduced
## motion; the checks still show. The belt shows no paid chips in the count
## (ItemView.shows_paid_chip).
##
## As a giver's effect pays (CountUp.landing of a step whose source is another item), the rail
## light (#86, kept by #105 piece 2: RailLight, ShiftStage.rail_light) runs gold along the price
## rail from the giver's ticket (the rail's left end once it is bagged) to the target's.
##
## Where an item is now (source_rect, CountUp.source_rect while counting): its sprite on the belt,
## or the bag's mouth once bagged, for the count's flights and puffs. A resumed checkout shows the
## count's end (show_end_state: the belt empty, the items in the bag); reset() puts the row back
## and empties the bag for the next shift. Only the shift screen's stage is touched (ShiftStage:
## row_strip, belt, bag, scan_layer, planning_layer); nothing here scores.

## The hop's arc over the straight line from the scanner to the bag, at its middle (px).
const HOP_ARC := 60.0
## The scanner's sweep up the arriving item at speed 1 (s).
const SWEEP_S := 0.16
## A giver's sparks: each one's run at speed 1 (s) and the gap between targets.
const SPARK_S := 0.3
const SPARK_GAP_S := 0.06

var _count: CountUp
var _stage: ShiftStage
var _sparks: GiverSparks
var _result: ScoreResult
var _views: Array[CardView] = []
var _graph: EffectGraph
var _reduced: bool = false
## Between begin and the count's end: the rides play on the belt.
var _active: bool = false
## The slots hopped into the bag so far.
var _bagged: Dictionary[int, bool] = {}
## The slot at the scanner, or -1.
var _scanning: int = -1
var _slide: Tween
## The slide's width (px, the row's coordinates) and how far it has run.
var _slide_width: float = 0.0
var _slid: float = 0.0
var _hops: Array[Tween] = []


## Follows `count_up`'s rides, landed steps and beats on `stage`'s belt.
func setup(count_up: CountUp, stage: ShiftStage) -> void:
	_count = count_up
	_stage = stage
	_stage.bag.make_tween = count_up.tween_maker()
	# Over the stickers, under the planning hover's hot strips and the stack fan.
	_sparks = GiverSparks.new()
	_stage.planning_layer.add_under_hot(_sparks)
	count_up.ride.connect(_on_ride)
	count_up.step_landed.connect(_on_step_landed)
	count_up.beat_started.connect(_on_beat_started)
	count_up.landing.connect(_on_landing)
	count_up.finished.connect(_on_finished)
	if _stage.rail_light != null:
		_stage.rail_light.make_tween = count_up.tween_maker()


## The CHECKOUT click (after the refresh that rebuilt the belt items `views`): `result` is about
## to be counted. The bag empties, the cells with no item hide (they stay out of the ride), no
## item shows its paid chip, and the count's flights start where the items are (source_rect).
func begin(result: ScoreResult, views: Array[CardView], reduced_motion: bool) -> void:
	_stop()
	_result = result
	_views = views
	_graph = EffectGraph.build(result)
	_reduced = reduced_motion
	_active = true
	_bagged.clear()
	_scanning = -1
	_stage.bag.clear()
	for view: CardView in views:
		var item: ItemView = view as ItemView
		if item != null:
			item.shows_paid_chip = false
			item.hide_badge()
	var cells: Array[PanelContainer] = _cells()
	for cell: int in range(views.size(), cells.size()):
		cells[cell].visible = false
	_count.source_rect = source_rect


## Item `slot`'s ticket on the rail now (global), or an empty rect once it is bagged (or no item).
func ticket_rect(slot: int) -> Rect2:
	var item: ItemView = _item(slot)
	if item == null or _bagged.has(slot) or not item.is_visible_in_tree():
		return Rect2()
	var local: Rect2 = Rect2(ItemView.BELT_STICKER, PriceSticker.SIZE)
	var to_global: Transform2D = item.get_global_transform()
	return Rect2(to_global * local.position, local.size * to_global.get_scale())


## Where item `slot` is now (global): its sprite on the belt, or the bag's mouth once it is bagged
## (or when it is no item).
func source_rect(slot: int) -> Rect2:
	var item: ItemView = _item(slot)
	if item == null or _bagged.has(slot) or not item.is_visible_in_tree():
		return _stage.bag.mouth_rect()
	return sprite_rect(item)


## A resumed checkout's belt, as the count left it: every cell hidden, the items `views` show in
## the bag (in order), the scanner clear and no paid chip.
func show_end_state(views: Array[CardView]) -> void:
	_stop()
	_active = false
	_views = views
	var definitions: Array[CardDefinition] = []
	_bagged.clear()
	for slot: int in range(views.size()):
		var item: ItemView = _item(slot)
		if item != null:
			item.shows_paid_chip = false
			item.hide_badge()
			definitions.append(item.card.definition)
		_bagged[slot] = true
	for cell: PanelContainer in _cells():
		cell.visible = false
	_stage.row_strip.box.position = Vector2.ZERO
	_stage.bag.show_items(definitions)
	_stage.scan_layer.clear()


## The next shift (or a new run): every cell shows again with the row at rest, the bag empties and
## the sparks and the scanner clear.
func reset() -> void:
	_stop()
	_active = false
	_bagged.clear()
	_scanning = -1
	_views = []
	for cell: PanelContainer in _cells():
		cell.visible = true
	_stage.row_strip.box.position = Vector2.ZERO
	_stage.bag.clear()


## The slot at the scanner, or -1 (none yet, or the last one bagged).
func scanning() -> int:
	return _scanning


## Whether item `slot` has gone into the bag.
func is_bagged(slot: int) -> bool:
	return _bagged.has(slot)


## The giver sparks' layer.
func sparks() -> GiverSparks:
	return _sparks


## `item`'s sprite at rest on the belt (global), scaled as the row is drawn.
static func sprite_rect(item: ItemView) -> Rect2:
	var drawn: Vector2 = ItemView.SPRITE_SIZE * item.get_global_transform().get_scale()
	return Rect2(item.center() - drawn / 2.0, drawn)


## A ride (CountUp.ride): `bag_slot` hops into the bag while `scan_slot` slides into the scanner
## over `ride_ms` (at speed 1); a `scan_slot` of -1 ends the scan.
func _on_ride(bag_slot: int, scan_slot: int, ride_ms: int) -> void:
	if not _active:
		return
	var seconds: float = ride_ms / 1000.0
	_finish_slide()
	if bag_slot >= 0:
		_hop(bag_slot, seconds)
	if scan_slot < 0 or scan_slot >= _views.size():
		_scanning = -1
		_stage.scan_layer.clear()
		if bag_slot >= 0:
			_stage.row_strip.ride_out(bag_slot)
			_stage.row_strip.box.position.x = 0.0
			_stage.planning_layer.follow_views()
		return
	_scanning = scan_slot
	var width: float = _stage.row_strip.ride_out(scan_slot - 1) if scan_slot > 0 else 0.0
	var snaps: bool = width <= 0.0 or _reduced or seconds <= 0.0
	if snaps:
		_stage.row_strip.box.position.x = 0.0
	_stage.planning_layer.follow_views()
	if snaps:
		_arrive()
		return
	_stage.scan_layer.clear()
	_slide_width = width
	_slid = 0.0
	_slide = _count.tween_maker().call() as Tween
	_slide.tween_method(_slide_to, 0.0, 1.0, seconds)
	_slide.tween_callback(_arrive)


## The slide at `progress` (0 to 1, smoothstep): the box back from the width left toward 0 on the
## art grid, the slats running left as far as the items have.
func _slide_to(progress: float) -> void:
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	var left: float = snappedf(_slide_width * (1.0 - eased), ArtStyle.ART_SCALE)
	_stage.row_strip.box.position.x = left
	# The stickers follow their items in the same frame (the layer's own check runs before it).
	_stage.planning_layer.follow_views()
	# The slats lag the items where the slide is fast: BeltPanel.scroll moves at most MAX_STEP_PX
	# a frame, as a step past half the slat pitch would look like the belt running backwards.
	var moved: float = _slide_width - left
	if moved > _slid:
		_stage.belt.scroll(moved - _slid)
		_slid = moved


## The item reached the scanner: its marks and one sweep up it.
func _arrive() -> void:
	_slide = null
	var item: ItemView = _item(_scanning)
	if item == null:
		return
	_stage.scan_layer.pose_scanner(ScanOverlay.scan_frame(item))
	_stage.scan_layer.sweep(SWEEP_S, _reduced, _count.tween_maker())


## Ends a slide still running at once (a new ride starts), the row at rest.
func _finish_slide() -> void:
	if _slide != null and _slide.is_valid():
		_slide.kill()
		_slide = null
		_slide_to(1.0)


## `slot`'s item hops into the bag over `seconds`: a copy of its art from its sprite on the belt
## up an arc into the bag's next place, shrinking to 1x art; its cell hides at once. Under reduced
## motion (or with no time) it is in the bag at once.
func _hop(slot: int, seconds: float) -> void:
	var item: ItemView = _item(slot)
	_bagged[slot] = true
	if item == null:
		return
	var bag: PaperBag = _stage.bag
	var from: Rect2 = sprite_rect(item)
	var art: TextureRect = PaperBag.art_of(item.card.definition)
	bag.contents.add_child(art)
	if _reduced or seconds <= 0.0:
		bag.add_art(art)
		bag.land(true)
		return
	var to_local: Transform2D = bag.contents.get_global_transform().affine_inverse()
	var start: Vector2 = to_local * from.position
	# The bag's next place after the items in it and those still hopping in (they land in order).
	var place: int = (bag.contents.get_child_count() - 1) % PaperBag.PEEKS.size()
	var end: Vector2 = to_local * (bag.get_global_transform() * PaperBag.PEEKS[place])
	var start_scale: float = from.size.x / ItemView.SPRITE_SIZE.x
	_hop_to(0.0, art, start, end, start_scale)
	var hop: Tween = _count.tween_maker().call() as Tween
	hop.tween_method(_hop_to.bind(art, start, end, start_scale), 0.0, 1.0, seconds)
	hop.tween_callback(_land.bind(art))
	_hops.append(hop)


## The hop at `progress` (0 to 1): along the line from `start` to `end` (the bag's contents'
## coordinates, smoothstep) and up its arc, on the art grid, shrinking from `start_scale` to the
## bag's 1x.
func _hop_to(
	progress: float, art: TextureRect, start: Vector2, end: Vector2, start_scale: float
) -> void:
	var eased: float = progress * progress * (3.0 - 2.0 * progress)
	var at: Vector2 = start.lerp(end, eased) - Vector2(0, sin(progress * PI) * HOP_ARC)
	art.position = at.snappedf(ArtStyle.ART_SCALE)
	art.scale = Vector2.ONE * lerpf(start_scale, PaperBag.ITEM_SCALE, progress)


func _land(art: TextureRect) -> void:
	if not is_instance_valid(art) or art.get_parent() != _stage.bag.contents:
		return
	_stage.bag.add_art(art)
	_stage.bag.land(_reduced)


## Step `index` landed (CountUp.step_landed): the sticker of that step fires (the fold chip's,
## counting down, when it is folded into "+N").
func _on_step_landed(index: int) -> void:
	if not _active or _result == null or index < 0 or index >= _result.steps.size():
		return
	var step: ScoreStep = _result.steps[index]
	var sticker: EffectSticker = _sticker_of(step.slot, index)
	if sticker != null:
		sticker.fire(_reduced, _count.tween_maker())
	# A loyalty upgrade's multiplier on its marked slot (the Slot engine's slot 6) fires the mark.
	if (
		step.step_type == ScoreStep.StepType.MULTIPLIER
		and step.source_kind == ScoreStep.SourceKind.UPGRADE
	):
		var mark: SlotMark = _stage.row_strip.slot_mark(step.slot, step.source_index)
		if mark != null:
			mark.fire(_reduced, _count.tween_maker())


## A beat starts (CountUp.beat_started): an armed giver's beat sends its sparks from the scanner
## to the stickers of its targets still on the belt (its landings, and every effect it gives:
## EffectGraph.outgoing, for copies and resets too), each charging as its spark lands.
func _on_beat_started(
	beat: CountUpBeat, _step: ScoreStep, _line: String, _view: CardView, _items: int
) -> void:
	if not _active or _reduced or beat.kind != CountUpBeat.Kind.ARMED:
		return
	var from: Rect2 = source_rect(beat.slot)
	var start: Vector2 = Vector2(from.get_center().x, from.position.y)
	var sent: int = 0
	for sticker: EffectSticker in _targets_of(beat):
		var landed: Callable = sticker.charge.bind(false, _count.tween_maker())
		_sparks.send(start, sticker, SPARK_S, sent * SPARK_GAP_S, _count.tween_maker(), landed)
		sent += 1


## The stickers an armed `beat`'s giver sends sparks to: those of its landings' steps and of
## every effect it gives, on items still on the belt, each once, in step order.
func _targets_of(beat: CountUpBeat) -> Array[EffectSticker]:
	var steps: PackedInt32Array = PackedInt32Array()
	for target: int in beat.targets:
		if target >= 0 and target < _count.plan.beats.size():
			steps.append_array(_count.plan.beats[target].steps)
	for link: EffectLink in _graph.outgoing(beat.slot):
		steps.append(link.step_index)
	steps.sort()
	var found: Array[EffectSticker] = []
	for index: int in steps:
		if index < 0 or index >= _result.steps.size():
			continue
		var slot: int = _result.steps[index].slot
		if slot == beat.slot or _bagged.has(slot):
			continue
		var sticker: EffectSticker = _sticker_of(slot, index)
		if sticker != null and not found.has(sticker) and sticker.is_visible_in_tree():
			found.append(sticker)
	return found


## The sticker on `slot` of step `index`, the stack's fold chip ("+N") when that step's sticker is
## one it folded in (the slot's earliest), or null (a step with no sticker, such as a denial).
func _sticker_of(slot: int, index: int) -> EffectSticker:
	var stack: Array[EffectSticker] = _stage.planning_layer.stack(slot)
	for sticker: EffectSticker in stack:
		if sticker.spec().step_index == index:
			return sticker
	var model: PlanningModel = _stage.planning_layer.model()
	if stack.is_empty() or stack[0].spec().kind != StickerSpec.Kind.MORE or model == null:
		return null
	if slot >= model.slots.size():
		return null
	var specs: Array[StickerSpec] = model.slots[slot].stickers
	for spec: StickerSpec in specs.slice(0, specs.size() - (stack.size() - 1)):
		if spec.step_index == index:
			return stack[0]
	return null


## The count ended: the flights no longer ask where the items are.
func _on_finished() -> void:
	_active = false
	_count.source_rect = Callable()


## CountUp.landing: a giver's effect pays (a +N or a × from another item): the rail light runs
## from the giver's ticket (the rail's left end once it is bagged) to the target's.
func _on_landing(beat: CountUpBeat) -> void:
	var light: RailLight = _stage.rail_light
	if not _active or light == null or _result == null or beat.steps.is_empty():
		return
	if beat.land != CountUpBeat.Land.ADD and beat.land != CountUpBeat.Land.MUL:
		return
	var step: ScoreStep = _result.steps[beat.steps[0]]
	if step.source_kind != ScoreStep.SourceKind.CARD:
		return
	if step.source_slot < 0 or step.source_slot == step.slot:
		return
	var to_local: Transform2D = light.get_global_transform().affine_inverse()
	var giver: Rect2 = _to(to_local, ticket_rect(step.source_slot))
	var target: Rect2 = _to(to_local, ticket_rect(step.slot))
	if not target.has_area():
		return
	var rail_left: float = ShiftStage.BELT_RECT.position.x + BeltPanel.RAIL.position.x
	var from_x: float = giver.get_center().x if giver.has_area() else rail_left
	light.reduced_motion = func() -> bool: return _reduced
	light.run(from_x, target.get_center().x, giver, target)


static func _to(transform: Transform2D, rect: Rect2) -> Rect2:
	if not rect.has_area():
		return Rect2()
	return Rect2(transform * rect.position, rect.size * transform.get_scale())


## Stops the slide, the hops (their copies go) and the sparks, and clears the scanner.
func _stop() -> void:
	if _slide != null and _slide.is_valid():
		_slide.kill()
	_slide = null
	for hop: Tween in _hops:
		if hop.is_valid():
			hop.kill()
	_hops.clear()
	_sparks.clear()
	if _stage.rail_light != null:
		_stage.rail_light.clear()
	_stage.scan_layer.clear()


## Every cell of the row, in its order: the open slots, then the CLOSED cells.
func _cells() -> Array[PanelContainer]:
	return _stage.row_strip.slots + _stage.row_strip.closed


## The belt item in `slot`, or null (none, or freed by a refresh).
func _item(slot: int) -> ItemView:
	if slot < 0 or slot >= _views.size() or not is_instance_valid(_views[slot]):
		return null
	return _views[slot] as ItemView
