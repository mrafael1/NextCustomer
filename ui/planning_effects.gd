class_name PlanningEffects
extends Node
## The planning effects on the belt (#71, mock-up h1 approved by the user on 2026-10-18,
## H1_BUILD_SPEC.md): what each item receives, pays and gives in the preview, always on, and how
## it relates to the hovered item.
##
## Look (sections 2 and 4): a PlanningModel of the preview (stickers, pay, halo, stamp per slot),
## shown by the stage's PlanningLayer: each item wears its stickers in apply order ("+3", "×3",
## "=€6", "WASTED", each with its giver's badge unless it is its own rule), a boosted one stands
## raised in its halo with its pay in a gold burst on its ticket, a denied one greys under a rubber
## stamp with a tomato "€0" tag, and so on. Every number comes from the score's steps and payouts:
## nothing here scores.
##
## Hover (section 8): hovering an item, a loyalty box or the inspection chip highlights at once
## (fading in over the tuning's focus_fade_s, at once under reduced motion) what it relates to:
## the hovered item gets its gold brackets (FOCUS), its givers and targets stay (RELATED), every
## other item dims (DIM); only the related stickers stay lit (the rest drain grey), the unrelated
## pay tags dim and stamps drain; the boxes and the chip of its causes ring in gold (the chip names
## the inspection). The hovered item's ticket is ringed and its targets' tickets get the "got"
## face; its own rail strip turns hot on top in lane 0 with each target's gain ("+€14"), the strips
## giving to it turn hot with its gain, and every other strip dims (a box's or the chip's hover dims
## them all). The receipt frames the item's line, marks its targets' lines with their tokens and
## its footer names it ("Multipack hovered"). An item with no effect stays quiet, as #80's hover.
## The scan's hold is unchanged (its scan adds a "gives" line: ScanController). Leaving waits the
## tuning's unfocus_delay_s, so sweeping across the belt never flickers, and the focus is kept by
## card across a refresh.
##
## Rail strips (section 5): the layer draws a brass strip along the belt lip from each giver's
## ticket to its targets' (in two lanes where spans share a slot), changed only by a refresh
## (show_all), never by a drag.
##
## Drag (section 9): each new landing slot (CardDrag.landing_changed) shows the model of the drop
## (`preview`: RunState.preview with the card placed there) on the views as they stand, the ghost
## carrying the dropped card's stickers, halo, stamp and pay; the quota chip shows that total and
## its change, and the monitor's checkout column its PLAN number (#105 piece 2). The rail strips
## hide meanwhile. Off the row and at the drag's end the committed model comes back, strips
## included.
##
## Motion (none under reduced motion, and nothing loops): stickers new since the last refresh slap
## on, a halo steps out ring by ring, the strips' chevrons step once (PlanningLayer).
##
## The CHECKOUT click (show_count, #86 v6) keeps only the stickers (and a denied item's stamp) on
## the items for the count, where they fire as their steps land (BeltRide); the rail strips,
## halos, pay tags and the hover's highlight go, until the next planning refresh.

enum Focus { NONE, CARD, UPGRADE, INSPECTION }

const TUNING_PATH := "res://data/balance/planning.tres"

## (card: CardInstance, slot: int) -> ScoreResult: the preview with `card` placed at `slot`.
var preview: Callable = Callable()
## Returns true when the player asked for reduced motion: no fade, slap or step. None means false.
var reduced_motion: Callable = Callable()
## Returns the pointer's global position (tests set it); by default the viewport's.
var pointer: Callable = Callable()
## The halo ratios, fades and dims (data/balance/planning.tres).
var tuning: PlanningTuning = load(TUNING_PATH) as PlanningTuning

## The committed preview's model and total, its row and the run behind it, the belt items and
## the shift's quota.
var _model: PlanningModel = PlanningModel.new()
var _total: int = 0
var _quota: int = 0
var _run: RunState
var _views: Array[CardView] = []
## Between show_all and clear: planning is on screen.
var _shown: bool = false
## The landing slot whose effects show during a drag, or -1.
var _landing: int = -1
var _loyalty: LoyaltyCard
var _tag: InspectionTag
var _quota_meter: QuotaMeter
var _drag: CardDrag
var _layer: PlanningLayer
var _monitor: MonitorView
var _receipt: ReceiptView
var _unfocus_timer: Timer
var _focus: Focus = Focus.NONE
var _focus_card: CardInstance
## The focused upgrade's index (Focus.UPGRADE).
var _focus_index: int = -1
## The stickers' keys at the last refresh (only new ones slap).
var _slapped: Dictionary[String, bool] = {}


## Takes `stage`'s loyalty card, inspection chip, quota chip, planning layer, monitor (for a drag's
## PLAN number) and receipt (to explain the hover; the screen's layout part: ShiftScreen owns them),
## and follows `drag`'s landings and the top bar's hovers.
func setup(stage: ShiftStage, drag: CardDrag) -> void:
	_loyalty = stage.loyalty_card
	_tag = stage.inspection_tag
	_quota_meter = stage.top_bar.quota_meter
	_drag = drag
	_layer = stage.planning_layer
	_layer.tuning = tuning
	_monitor = stage.monitor
	_receipt = stage.receipt
	_unfocus_timer = Timer.new()
	_unfocus_timer.one_shot = true
	_unfocus_timer.wait_time = maxf(tuning.unfocus_delay_s, 0.001)
	_unfocus_timer.timeout.connect(_on_unfocus_timeout)
	add_child(_unfocus_timer)
	drag.landing_changed.connect(_on_landing_changed)
	_loyalty.box_hovered.connect(_on_box_hovered)
	_loyalty.box_unhovered.connect(_on_left)
	_tag.hovered.connect(_on_tag_hovered)
	_tag.unhovered.connect(_on_left)


## Planning's refresh: shows `result` (the preview of `run`'s row) on the belt items `views`
## (rebuilt by each refresh), and puts the focus back on the same card, box or chip at once.
func show_all(result: ScoreResult, views: Array[CardView], run: RunState) -> void:
	_run = run
	_model = model_of(result, run.row, run, tuning)
	_total = result.total
	_quota = run.quota()
	_views = views
	_shown = true
	_landing = -1
	for slot: int in range(views.size()):
		var item: ItemView = _item(slot)
		if item != null and not item.hovered.is_connected(_on_item_hovered):
			item.hovered.connect(_on_item_hovered)
			item.unhovered.connect(_on_left)
	_layer.reduced_motion = _reduced()
	_layer.show_model(_model, _items_in(views, -1, null))
	_layer.show_strips(true)
	_slapped = _layer.slap_new(_slapped)
	_apply_focus(false)


## The model of `result` for the cards `row` under `run`'s upgrades and inspections.
static func model_of(
	result: ScoreResult, row: Array[CardInstance], run: RunState, planning: PlanningTuning
) -> PlanningModel:
	var cards: Array[CardDefinition] = []
	for card: CardInstance in row:
		cards.append(card.definition)
	return PlanningModel.build(result, cards, run.upgrades, run.inspections, planning)


## A drag's landing: `model` (the preview with the dragged card at `landing`) on the belt items
## `views` as they stand: slots before `landing` on their views, `landing` on `ghost`, later ones
## on the view left of them. A `landing` of -1 shows `model` on `views` alone, and `ghost` plain.
## No item is related meanwhile: the focus and the rings are off, and the rail strips hide while
## the ghost is over the row.
func show_hypothetical(
	model: PlanningModel, views: Array[CardView], ghost: ItemView, landing: int
) -> void:
	_landing = landing
	_focus = Focus.NONE
	_focus_card = null
	_unfocus_timer.stop()
	var items: Array[ItemView] = _items_in(views, landing, ghost)
	_layer.reduced_motion = _reduced()
	_layer.show_model(model, items, ghost if landing >= 0 else null)
	_layer.show_strips(landing < 0)
	for slot: int in range(views.size()):
		var item: ItemView = _item_in(views, slot)
		if item != null:
			_relate(item, ItemView.Relation.NONE, 0.0, Vector2.ONE)
	_ring({}, -2)
	_explain(-1, {})


## Highlights what the card's item relates to (see the class comment).
func focus_card(card: CardInstance) -> void:
	_set_focus(Focus.CARD, card, -1)


## Highlights the items upgrade `index` (of the run's) acts on, and rings its box.
func focus_upgrade(index: int) -> void:
	_set_focus(Focus.UPGRADE, null, index)


## Highlights the items the shift's inspections act on, and rings the inspection chip.
func focus_inspection() -> void:
	_set_focus(Focus.INSPECTION, null, -1)


## Takes the hover's highlight off (fading, unless reduced motion).
func unfocus() -> void:
	_unfocus_timer.stop()
	_focus = Focus.NONE
	_focus_card = null
	_focus_index = -1
	if _shown and _landing < 0:
		_apply_focus(true)


## The CHECKOUT click: every sticker, pay tag, stamp, rail strip, halo, lift, grey, strike,
## relation and ring goes, and the focus with them, until the next planning refresh.
func clear() -> void:
	_unfocus_timer.stop()
	_shown = false
	_landing = -1
	_focus = Focus.NONE
	_focus_card = null
	_slapped.clear()
	_layer.clear()
	_explain(-1, {})
	for slot: int in range(_views.size()):
		var item: ItemView = _item(slot)
		if item != null:
			_relate(item, ItemView.Relation.NONE, 0.0, Vector2.ONE)
	_loyalty.clear_relations()
	_tag.set_relation(false)


## The CHECKOUT click (#86 v6), after the refresh that rebuilt the belt items `views`: everything
## goes (clear), then `result`'s stickers (and stamps) come back on the items for the count,
## without a slap (PlanningLayer.keep_stickers). Hovers stay off until the next show_all.
func show_count(result: ScoreResult, views: Array[CardView], run: RunState) -> void:
	clear()
	_views = views
	_layer.reduced_motion = _reduced()
	_layer.show_model(model_of(result, run.row, run, tuning), _items_in(views, -1, null))
	_layer.keep_stickers()


## The committed preview's model (for tests).
func committed_model() -> PlanningModel:
	return _model


## The card focused by a hover, or null (for tests).
func focused_card() -> CardInstance:
	return _focus_card if _focus == Focus.CARD else null


func _set_focus(focus: Focus, card: CardInstance, index: int) -> void:
	_unfocus_timer.stop()
	_focus = focus
	_focus_card = card
	_focus_index = index
	if _shown and _landing < 0:
		_apply_focus(true)


## The focus on the items, the layer and the top bar: fading in when `fade` (and motion is on),
## else at once. Nothing dims unless something relates; a focused card no longer on the belt loses
## the focus.
func _apply_focus(fade: bool) -> void:
	var related: PackedInt32Array = PackedInt32Array()
	var boxes: Dictionary[int, bool] = {}
	var cause: Array[int] = [-2]
	var focused: int = -1
	var lit: Callable = Callable()
	var hot: Dictionary[int, int] = {}
	var graph: EffectGraph = _model.graph if _model.graph != null else EffectGraph.new()
	match _focus:
		Focus.CARD:
			focused = _slot_of(_focus_card)
			if focused < 0:
				_focus = Focus.NONE
				_focus_card = null
			else:
				related = _model.related(focused)
				_card_causes(graph, focused, boxes, cause)
				var stickered: bool = (
					focused < _model.slots.size() and not _model.slots[focused].stickers.is_empty()
				)
				if related.size() > 1 or stickered or not boxes.is_empty() or cause[0] >= 0:
					var on: int = focused
					lit = func(slot: int, spec: StickerSpec) -> bool:
						return slot == on or spec.caused_by_card(on)
					hot = _hot_strips(_model, focused)
		Focus.UPGRADE:
			for link: EffectLink in graph.by_upgrade(_focus_index):
				_add_slot(related, link.target_slot)
			boxes[_focus_index] = true
			if not related.is_empty():
				var index: int = _focus_index
				lit = func(_slot: int, spec: StickerSpec) -> bool:
					return (
						spec.cause_kind == ScoreStep.SourceKind.UPGRADE
						and spec.cause_index == index
					)
		Focus.INSPECTION:
			for link: EffectLink in graph.links:
				if link.cause_kind == ScoreStep.SourceKind.INSPECTION:
					_add_slot(related, link.target_slot)
			cause[0] = -1
			if not related.is_empty():
				lit = func(_slot: int, _spec: StickerSpec) -> bool: return false
	var fade_time: float = tuning.focus_fade_s if fade and not _reduced() else 0.0
	for slot: int in range(_views.size()):
		var item: ItemView = _item(slot)
		if item == null:
			continue
		var relation: ItemView.Relation = ItemView.Relation.NONE
		if lit.is_valid():
			relation = ItemView.Relation.RELATED if related.has(slot) else ItemView.Relation.DIM
			if slot == focused:
				relation = ItemView.Relation.FOCUS
		var alphas: Vector2 = Vector2(tuning.dim_item_alpha, tuning.dim_ticket_alpha)
		_relate(item, relation, fade_time, alphas)
	if not lit.is_valid():
		related = PackedInt32Array()
		focused = -1
	_layer.apply_focus(lit, related, hot, fade_time, focused)
	_ring(boxes, cause[0])
	_explain(focused, _tokens(_model, focused))


## The rail strips hot while the item at `slot` is hovered (section 5.3): its own (every target's
## gain: -1) and those giving to it (its gain only: `slot`).
static func _hot_strips(model: PlanningModel, slot: int) -> Dictionary[int, int]:
	var hot: Dictionary[int, int] = {}
	for spec: RailStripSpec in model.strips:
		if spec.giver_slot == slot:
			hot[slot] = -1
		elif spec.targets.has(slot):
			hot[spec.giver_slot] = slot
	return hot


## The tokens the item at `slot` gives each target (target slot: "×3"), from its rail strip.
static func _tokens(model: PlanningModel, slot: int) -> Dictionary[int, String]:
	var tokens: Dictionary[int, String] = {}
	for spec: RailStripSpec in model.strips:
		if spec.giver_slot == slot:
			for index: int in range(spec.targets.size()):
				tokens[spec.targets[index]] = spec.tokens[index]
	return tokens


## The receipt's explanation of the hovered item at `slot` (-1: none): its line framed, its
## targets' lines marked with `tokens`, and the footer naming it.
func _explain(slot: int, tokens: Dictionary[int, String]) -> void:
	if _receipt == null:
		return
	if slot < 0 or _item(slot) == null:
		_receipt.show_relations(-1)
		return
	var hint: String = ReceiptView.HOVERED_HINT % _item(slot).card.definition.display_name
	_receipt.show_relations(slot, tokens, hint)


## Relates `item` to the focus: `relation`, fading over `fade` seconds to DIM's `alphas`.
static func _relate(
	item: ItemView, relation: ItemView.Relation, fade: float, alphas: Vector2
) -> void:
	item.relation_fade = fade
	item.dim_alphas = alphas
	item.relation = relation


## Fills `boxes` (the upgrades to ring) and `cause` (its first entry: the inspection to name, -2
## not to ring the chip) with the upgrades and inspections causing the effects on `slot`.
static func _card_causes(
	graph: EffectGraph, slot: int, boxes: Dictionary[int, bool], cause: Array[int]
) -> void:
	for link: EffectLink in graph.incoming(slot):
		match link.cause_kind:
			ScoreStep.SourceKind.UPGRADE:
				boxes[link.cause_index] = true
			ScoreStep.SourceKind.INSPECTION:
				cause[0] = link.cause_index


## Adds `slot` to the ascending `slots` unless it is there.
static func _add_slot(slots: PackedInt32Array, slot: int) -> void:
	var at: int = slots.bsearch(slot)
	if at >= slots.size() or slots[at] != slot:
		slots.insert(at, slot)


## Rings the loyalty boxes in `boxes` (and only those) and, for a `cause` of -1 or more, the
## inspection chip (naming inspection `cause` when it is one).
func _ring(boxes: Dictionary[int, bool], cause: int) -> void:
	for index: int in range(_loyalty.stamped_boxes().size()):
		_loyalty.set_relation(index, boxes.has(index))
	_tag.set_relation(cause >= -1, cause)


func _on_item_hovered(view: ItemView) -> void:
	if not _blocked():
		focus_card(view.card)


func _on_box_hovered(index: int) -> void:
	if not _blocked():
		focus_upgrade(index)


func _on_tag_hovered() -> void:
	if not _blocked():
		focus_inspection()


## The pointer left an item, a box or the chip: the focus goes after the unfocus delay, unless
## the pointer is back on something by then. Nothing while the screen leaves the tree (a scan
## torn down at quit says it left).
func _on_left(_left: Variant = null) -> void:
	if _focus != Focus.NONE and _unfocus_timer.is_inside_tree():
		_unfocus_timer.start()


## The hover's end, after the delay: kept while the pointer is on the focused thing (a refresh's
## new view of the focused card takes no mouse_entered until the pointer moves).
func _on_unfocus_timeout() -> void:
	if not _pointer_on_focus():
		unfocus()


func _pointer_on_focus() -> bool:
	var point: Vector2 = get_viewport().get_mouse_position()
	if pointer.is_valid():
		point = pointer.call()
	match _focus:
		Focus.CARD:
			var item: ItemView = _item(_slot_of(_focus_card))
			if item != null:
				return item.hit_rect().has_point(
					item.get_global_transform().affine_inverse() * point
				)
		Focus.UPGRADE:
			var stamped: Control = _loyalty.box(_focus_index)
			return stamped != null and stamped.get_global_rect().has_point(point)
		Focus.INSPECTION:
			return _tag.is_visible_in_tree() and _tag.get_global_rect().has_point(point)
	return false


## A drag's new landing slot (`card` null: the drag ended): its model and the quota chip's
## would-be total, or the committed preview off the row and at the end. A card the preview can't
## place (its result has no extra slot) shows the committed model.
func _on_landing_changed(card: CardInstance, slot: int) -> void:
	if not _shown:
		return
	var ghost: ItemView = _drag.ghost()
	var result: ScoreResult = null
	if card != null and slot >= 0 and preview.is_valid() and _run != null:
		result = preview.call(card, slot)
	if result == null or result.payouts.size() != _run.row.size() + 1:
		show_hypothetical(_model, _views, ghost, -1)
		_landing = -1
		_quota_meter.show_projected(_total, _quota)
		_monitor.show_plan(_total, _quota)
		return
	var landing: int = clampi(slot, 0, _run.row.size())
	var row: Array[CardInstance] = _run.row.duplicate()
	row.insert(landing, card)
	show_hypothetical(model_of(result, row, _run, tuning), _views, ghost, landing)
	_quota_meter.show_hypothetical(result.total, result.total - _total, _quota)
	_monitor.show_plan(result.total, _quota)


## Hovers do nothing outside planning and while an item is dragged.
func _blocked() -> bool:
	return not _shown or _landing >= 0 or (_drag != null and _drag.is_dragging())


func _reduced() -> bool:
	return reduced_motion.is_valid() and reduced_motion.call()


func _slot_of(card: CardInstance) -> int:
	for slot: int in range(_views.size()):
		var item: ItemView = _item(slot)
		if item != null and item.card == card:
			return slot
	return -1


## The belt item in `slot`, or null (not an item, or freed by a refresh).
func _item(slot: int) -> ItemView:
	return _item_in(_views, slot)


## The view showing each slot of a model on `views`: with a `landing` (0 or more) the slots
## before it on their views, the landing on `ghost` and later ones on the view left of them.
static func _items_in(views: Array[CardView], landing: int, ghost: ItemView) -> Array[ItemView]:
	var items: Array[ItemView] = []
	var count: int = views.size() + (1 if landing >= 0 else 0)
	for slot: int in range(count):
		var item: ItemView = ghost
		if landing < 0 or slot < landing:
			item = _item_in(views, slot)
		elif slot > landing:
			item = _item_in(views, slot - 1)
		items.append(item if item != null and is_instance_valid(item) else null)
	return items


static func _item_in(views: Array[CardView], slot: int) -> ItemView:
	if slot < 0 or slot >= views.size() or not is_instance_valid(views[slot]):
		return null
	return views[slot] as ItemView
