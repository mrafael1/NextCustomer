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
## Mix highlight (#105 piece 3, mock-up readability v3 section 4, option A; MixModel): hovering a
## family glyph anywhere (a ticket, the monitor, a popup, the Cart: GlyphTips.shown_changed,
## watch_glyphs) lights every belt and hand item in that family and greys the rest; hovering an
## item on the belt or in the hand baskets, or holding one (the picked card, or the dragged one),
## lights the items it works with (CardAffinity: its rule's targets and the items that boost it),
## a pair paying now with a check, a penalty pair with a "!", a broad "next Food" match faint under
## a dashed outline, and greys the rest. A glyph wins over an item, a hovered item over the held
## one. The grey is the calm one (PlanningTuning's mix_brightness and mix_saturation, over
## mix_fade_s), which replaced #71's fade (DIM). It greys whole items: a greyed belt item's
## stickers take the same calm grey (_grey_stickers), its pay tag dims and its stamp drains, while
## a lit item keeps every sticker in colour (#71's sticker drain is for a loyalty box's or the
## inspection chip's hover only); the hovered belt item keeps #71's hot strips, ticket rings and
## receipt. A hand item's hover is the mix only (no strips, rings or receipt). Opening a folded
## stack's fan (StackFan.fanned_changed) hovers its item, and the pointer on the fan keeps it. The
## Cart greys its own cells (DeckView), and no hover reaches the counter while it is open. Off in
## the count.
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
## The top bar's week chip (v0.70): rung, not the day chip, when the cause is the week event.
var _week_chip: WeekChip
var _views: Array[CardView] = []
## The hand's items (#105 piece 3: the mix highlight lights and greys them too).
var _hand: Array[Control] = []
## Each belt slot's scored tags (a granted Breakfast included), for the mix highlight.
var _belt_tags: Array[PackedStringArray] = []
## The hovered family glyph's family on the counter (#105 piece 3), or "".
var _family: String = ""
## The card a drag carries, while it shows its landings.
var _dragged: CardInstance
## The Cart, whose glyphs light its own cells (watch_glyphs).
var _deck: DeckView
## The broad families (Food): a match through one of them shows faint.
var _broad: PackedStringArray = FamilyPalette.shared().quiet_families
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
## How far each belt sticker's calm grey is in (EffectSticker: 0 to 1), and its fade.
var _sticker_grey: Dictionary = {}
var _grey_tween: Tween


## Takes `stage`'s loyalty card, inspection chip, quota chip, planning layer, monitor (for a drag's
## PLAN number) and receipt (to explain the hover; the screen's layout part: ShiftScreen owns them),
## and follows `drag`'s landings and the top bar's hovers.
func setup(stage: ShiftStage, drag: CardDrag) -> void:
	_loyalty = stage.loyalty_card
	_tag = stage.inspection_tag
	_week_chip = stage.top_bar.week_chip
	_quota_meter = stage.top_bar.quota_meter
	_drag = drag
	_layer = stage.planning_layer
	_layer.tuning = tuning
	_layer.fan().blocked = _blocked
	_layer.fan().fanned_changed.connect(_on_fanned)
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
## (rebuilt by each refresh), with the hand's items `hand` for the mix highlight, and puts the
## focus back on the same card, box or chip at once.
func show_all(
	result: ScoreResult, views: Array[CardView], run: RunState, hand: Array[Control] = []
) -> void:
	_run = run
	_model = model_of(result, run.row, run, tuning)
	_total = result.total
	_quota = run.quota()
	_views = views
	_hand = hand
	_belt_tags = result.tags.duplicate()
	_shown = true
	_landing = -1
	var items: Array[ItemView] = _hand_items()
	for slot: int in range(views.size()):
		if _item(slot) != null:
			items.append(_item(slot))
	for item: ItemView in items:
		if not item.hovered.is_connected(_on_item_hovered):
			item.hovered.connect(_on_item_hovered)
			item.unhovered.connect(_on_left)
	_layer.reduced_motion = _reduced()
	_layer.show_model(_model, _items_in(views, -1, null))
	_layer.show_strips(true)
	_slapped = _layer.slap_new(_slapped)
	_apply_focus(false)


## The model of `result` for the cards `row` under `run`'s upgrades and events (its day events
## and its week event, v0.70: WeekSchedule.shift_events, as the result was scored).
static func model_of(
	result: ScoreResult, row: Array[CardInstance], run: RunState, planning: PlanningTuning
) -> PlanningModel:
	var cards: Array[CardDefinition] = []
	for card: CardInstance in row:
		cards.append(card.definition)
	var events: Array[InspectionDefinition] = WeekSchedule.shift_events(run)
	return PlanningModel.build(result, cards, run.upgrades, events, planning)


## A drag's landing: `model` (the preview with the dragged card at `landing`) on the belt items
## `views` as they stand: slots before `landing` on their views, `landing` on `ghost`, later ones
## on the view left of them. A `landing` of -1 shows `model` on `views` alone, and `ghost` plain.
## No item is related meanwhile: the focus and the rings are off, and the rail strips hide while
## the ghost is over the row. The dragged card (a drag's, _on_landing_changed) keeps its mix
## highlight on the items, with no "pays now" check (the order is only hypothetical).
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
	var looks: Dictionary[ItemView, MixModel.Look] = {}
	if _dragged != null:
		looks = _mix_looks(null, _dragged)
	_paint_items(looks, Callable(), PackedInt32Array(), -1, _fade(tuning.mix_fade_s))
	_grey_stickers(items, looks, 0.0)
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


## Watches `tips` for a family glyph's tooltip: while one shows, its family lights (the mix
## highlight); one in `deck` (the Cart) lights the Cart's cells instead.
func watch_glyphs(tips: GlyphTips, deck: DeckView = null) -> void:
	_deck = deck
	tips.shown_changed.connect(_on_tip_shown)


## The family glyph's family lit on the counter (for tests), or "".
func lit_family() -> String:
	return _family


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
	_family = ""
	_dragged = null
	_slapped.clear()
	if _grey_tween != null:
		_grey_tween.kill()
		_grey_tween = null
	_sticker_grey.clear()
	_layer.clear()
	_explain(-1, {})
	_paint_items({}, Callable(), PackedInt32Array(), -1, 0.0)
	_loyalty.clear_relations()
	_tag.set_relation(false)
	_week_chip.set_relation(false)


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
## else at once. Nothing dims unless something relates; a focused card no longer on the belt nor
## in the hand loses the focus. The mix highlight (a family glyph, a hovered or held item) decides
## which items grey when it lights anything, whole (no sticker drains: _grey_stickers); else #71's
## relations do.
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
			if focused < 0 and _hand_item(_focus_card) == null:
				_focus = Focus.NONE
				_focus_card = null
			elif focused >= 0:
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
			# The day chip's own events only: the week event's (after them) are the week chip's.
			var days: int = _run.inspections.size() if _run != null else 0
			for link: EffectLink in graph.links:
				if link.cause_kind == ScoreStep.SourceKind.INSPECTION and link.cause_index < days:
					_add_slot(related, link.target_slot)
			cause[0] = -1
			if not related.is_empty():
				lit = func(_slot: int, _spec: StickerSpec) -> bool: return false
	var looks: Dictionary[ItemView, MixModel.Look] = _mix_looks(graph, _mix_card())
	if not looks.is_empty():
		related = _lit_slots(looks)
		lit = func(_slot: int, _spec: StickerSpec) -> bool: return true
		if not _family.is_empty():
			hot = {}
			focused = -1
	var fade_time: float = tuning.focus_fade_s if fade and not _reduced() else 0.0
	var mix_fade: float = _fade(tuning.mix_fade_s if fade else 0.0)
	_paint_items(looks, lit, related, focused, mix_fade)
	if not lit.is_valid():
		related = PackedInt32Array()
		focused = -1
	_layer.apply_focus(lit, related, hot, fade_time, focused)
	_grey_stickers(_items_in(_views, -1, null), looks, mix_fade)
	_ring(boxes, cause[0])
	_explain(focused, _tokens(_model, focused))


## The items' looks: with mix `looks` (not empty) each belt and hand item's (SELF focused, a grey
## one DIM, the rest RELATED); else #71's on the belt (with `lit`: `focused` FOCUS, `related`
## RELATED, the rest DIM) and the hand plain. Fading over `fade` seconds.
func _paint_items(
	looks: Dictionary[ItemView, MixModel.Look],
	lit: Callable,
	related: PackedInt32Array,
	focused: int,
	fade: float
) -> void:
	var greyness: Vector2 = Vector2(tuning.mix_brightness, tuning.mix_saturation)
	for slot: int in range(_views.size()):
		var item: ItemView = _item(slot)
		if item == null:
			continue
		var relation: ItemView.Relation = ItemView.Relation.NONE
		if looks.is_empty() and lit.is_valid():
			relation = ItemView.Relation.RELATED if related.has(slot) else ItemView.Relation.DIM
			if slot == focused:
				relation = ItemView.Relation.FOCUS
		_relate(item, relation, looks.get(item, MixModel.Look.NONE), fade, greyness)
	for item: ItemView in _hand_items():
		_relate(item, ItemView.Relation.NONE, looks.get(item, MixModel.Look.NONE), fade, greyness)


## The calm grey on the belt's stickers by their items' mix `looks` (the view of each slot of the
## model shown: `items`): a greyed item's stickers grey with it, every other one goes plain, over
## `fade` seconds from where each is.
func _grey_stickers(
	items: Array[ItemView], looks: Dictionary[ItemView, MixModel.Look], fade: float
) -> void:
	var targets: Dictionary = {}
	for slot: int in range(items.size()):
		var item: ItemView = items[slot]
		var grey: bool = item != null and looks.has(item) and MixModel.greys(looks[item])
		for sticker: EffectSticker in _layer.stack(slot):
			targets[sticker] = 1.0 if grey else 0.0
	if _grey_tween != null:
		_grey_tween.kill()
		_grey_tween = null
	var starts: Dictionary = {}
	for sticker: Variant in targets:
		starts[sticker] = _sticker_grey.get(sticker, 0.0)
	_sticker_grey = starts.duplicate()
	if fade > 0.0 and is_inside_tree():
		_grey_tween = create_tween()
		_grey_tween.tween_method(_step_grey.bind(starts, targets), 0.0, 1.0, fade)
	else:
		_step_grey(1.0, starts, targets)


## The stickers' grey `progress` of the way from `starts` to `targets` (EffectSticker: amount).
func _step_grey(progress: float, starts: Dictionary, targets: Dictionary) -> void:
	var greyness: Vector2 = Vector2(tuning.mix_brightness, tuning.mix_saturation)
	for key: Variant in targets:
		if not is_instance_valid(key):
			continue
		var amount: float = lerpf(float(starts[key]), float(targets[key]), progress)
		_sticker_grey[key] = amount
		ArtStyle.set_mix_grey(key as EffectSticker, amount, greyness)


## The mix highlight's looks of the belt and hand items (empty: none): the hovered family's, else
## `card`'s (a hovered or held one; with `graph` the pairs paying now), else none.
func _mix_looks(graph: EffectGraph, card: CardInstance) -> Dictionary[ItemView, MixModel.Look]:
	var items: Array[ItemView] = []
	var entries: Array[MixModel.Entry] = []
	for slot: int in range(_views.size()):
		var item: ItemView = _item(slot)
		if item != null:
			var tags: PackedStringArray = (
				_belt_tags[slot] if slot < _belt_tags.size() else item.tags()
			)
			items.append(item)
			entries.append(MixModel.Entry.new(item.card, tags, slot))
	for item: ItemView in _hand_items():
		items.append(item)
		entries.append(MixModel.Entry.new(item.card, item.card.definition.tags))
	var shown: Array[MixModel.Look] = []
	if not _family.is_empty():
		shown = MixModel.for_family(entries, _family)
	elif card != null:
		var focus: MixModel.Entry = MixModel.Entry.new(card, card.definition.tags)
		for entry: MixModel.Entry in entries:
			if entry.card == card:
				focus = entry
		shown = MixModel.for_card(entries, focus, graph, _broad)
	var looks: Dictionary[ItemView, MixModel.Look] = {}
	for index: int in range(shown.size()):
		looks[items[index]] = shown[index]
	return looks


## The card whose matches the mix highlight lights: the hovered item's, else (no box or chip
## hovered) the held one's (the picked hand item), else null.
func _mix_card() -> CardInstance:
	if _focus == Focus.CARD:
		return _focus_card
	if _focus != Focus.NONE:
		return null
	for item: ItemView in _hand_items():
		if item.selected:
			return item.card
	return null


## The belt slots the mix `looks` keep lit (not greyed), ascending.
func _lit_slots(looks: Dictionary[ItemView, MixModel.Look]) -> PackedInt32Array:
	var slots: PackedInt32Array = PackedInt32Array()
	for slot: int in range(_views.size()):
		var item: ItemView = _item(slot)
		if item != null and looks.has(item) and not MixModel.greys(looks[item]):
			slots.append(slot)
	return slots


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


## Relates `item` to the focus: `relation` (fading over `fade` seconds to DIM's `greyness`) and
## the mix highlight's mark of `look` (a FOCUS for SELF, a DIM for a greying look).
static func _relate(
	item: ItemView, relation: ItemView.Relation, look: MixModel.Look, fade: float, greyness: Vector2
) -> void:
	var shown: ItemView.Relation = relation
	if look == MixModel.Look.SELF:
		shown = ItemView.Relation.FOCUS
	elif MixModel.greys(look):
		shown = ItemView.Relation.DIM
	elif look != MixModel.Look.NONE:
		shown = ItemView.Relation.RELATED
	item.relation_fade = fade
	item.dim_greyness = greyness
	item.relation = shown
	item.mix_look = look


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
## inspection chip (naming inspection `cause` when it is one), or the week chip when `cause` is
## the week event (v0.70: after the day events in WeekSchedule.shift_events).
func _ring(boxes: Dictionary[int, bool], cause: int) -> void:
	for index: int in range(_loyalty.stamped_boxes().size()):
		_loyalty.set_relation(index, boxes.has(index))
	var week: bool = _run != null and cause >= 0 and cause >= _run.inspections.size()
	_week_chip.set_relation(week)
	_tag.set_relation(cause >= -1 and not week, cause)


func _on_item_hovered(view: ItemView) -> void:
	if not _blocked():
		focus_card(view.card)


func _on_box_hovered(index: int) -> void:
	if not _blocked():
		focus_upgrade(index)


func _on_tag_hovered() -> void:
	if not _blocked():
		focus_inspection()


## A folded stack's fan opened over `slot`'s item (it hovers that item: the stack sits on its
## shoulder; already hovered, it stays), or shut (-1: the pointer left the fan, so the focus goes
## after the delay).
func _on_fanned(slot: int) -> void:
	var item: ItemView = _item(slot)
	if slot < 0 or item == null:
		_on_left()
	elif _focus == Focus.CARD and _focus_card == item.card:
		_unfocus_timer.stop()
	elif not _blocked():
		focus_card(item.card)


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
			var slot: int = _slot_of(_focus_card)
			if slot >= 0 and _layer.fan().fanned() == slot:
				return true
			var item: ItemView = _item(slot)
			if item == null:
				item = _hand_item(_focus_card)
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
	_dragged = card
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


## Hovers do nothing outside planning, while an item is dragged and while the Cart (the deck view
## watch_glyphs took) covers the counter.
func _blocked() -> bool:
	var covered: bool = _deck != null and _deck.visible
	return not _shown or _landing >= 0 or (_drag != null and _drag.is_dragging()) or covered


func _reduced() -> bool:
	return reduced_motion.is_valid() and reduced_motion.call()


## `seconds`, or 0 under reduced motion.
func _fade(seconds: float) -> float:
	return 0.0 if _reduced() else seconds


## A family glyph's tooltip shows (`target`; null: none): its family lights the Cart's cells
## when it is in the open Cart, else the counter's items (not while hovers are blocked).
func _on_tip_shown(target: TipTarget) -> void:
	var glyph: FamilyGlyph = target as FamilyGlyph
	var family: String = glyph.family if glyph != null else ""
	var in_deck: bool = _deck != null and target != null and _deck.is_ancestor_of(target)
	if _deck != null:
		_deck.mix_family = family if in_deck and _deck.visible else ""
	var counter: String = "" if in_deck or _blocked() else family
	if counter == _family:
		return
	_family = counter
	if _shown and _landing < 0:
		_apply_focus(true)


## The hand's items still shown.
func _hand_items() -> Array[ItemView]:
	var items: Array[ItemView] = []
	for control: Control in _hand:
		var item: ItemView = control as ItemView
		if item != null and is_instance_valid(item) and not item.is_queued_for_deletion():
			items.append(item)
	return items


## The hand's item of `card`, or null.
func _hand_item(card: CardInstance) -> ItemView:
	for item: ItemView in _hand_items():
		if item.card == card:
			return item
	return null


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
