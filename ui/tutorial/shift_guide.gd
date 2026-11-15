class_name ShiftGuide
extends Node
## The tutorial's side of the shift screen (tutorial plan sections 1.2 to 1.6; WP-5): the gate
## the screen, the machine and the week card ask before they act on a player's input, the
## guide_event hooks they send, and the anchors' rects. A part of the shift screen, split out to
## keep that file short (like MachineFlow): it works on the screen's own members.
##
## The gate (`gate`, TutorialActions' Callable(action, args) -> bool) is set by the tutorial
## director for a guided run or a quick tutorial, and is null otherwise: a null gate allows
## everything, so a normal run behaves exactly as before. A refused action does nothing, plays no
## "denied" sound and sends `refused` instead (the director shakes its callout and shows the
## step's line again). The events (TutorialEvents) go out on ShiftScreen.guide_event at all times,
## guided or not: emitting changes nothing. PLANNING_READY and SCAN_HELD are read here each frame
## (the shift's planning taking input, the scanner's full scan); the rest come from the screen,
## the machine (MachineFlow) and the week card (WeekFlow).
##
## While a guided step or a tip shows (`showing`, the director's Callable() -> bool), the
## monitor's empty-belt hint (MonitorText.EMPTY_BELT) hides, and planning's notices (the bonus
## notice, the premium announce, the shift notice) and the day calendar's page change wait
## (WeekFlow.holds_planning). The director's overlay goes under a layer of its own (mount_overlay):
## below the hover tips and the handbook, and hidden while the handbook, the cart or the pause is
## open or the shift is counted.

## The gate refused `action` (with its `args`): the director's soft shake and its line again.
signal refused(action: StringName, args: Dictionary)

## TutorialActions' gate, Callable(action: StringName, args: Dictionary) -> bool; null: no tutorial.
var gate: Callable = Callable()
## Whether a guided step or a tip shows now: Callable() -> bool; null: none ever does.
var showing: Callable = Callable()
var _screen: ShiftScreen
## The screen's guide_event.
var _hooks: Signal
## The run and shift of the last PLANNING_READY (a new run or a resume sends it again).
var _ready_run: RunState
var _ready_shift: int = -1
## The last PROJECTED's total and quota (sent again only when they change).
var _projected: Array[int] = []
## The card whose full scan was last sent as SCAN_HELD (null: none since the scan ended).
var _scanned: CardInstance
## The monitor's empty-belt hint hidden while a step shows (null: none hidden).
var _hint: Label
## The layer that holds the director's overlay (mount_overlay), or null.
var _layer: Control
## The screen's handbook (watch), or null.
var _handbook: HandbookPage


## Adds the guide to `screen` (built first, so every part can ask it); `hooks` is its
## guide_event.
func _init(screen: ShiftScreen, hooks: Signal) -> void:
	name = "ShiftGuide"
	_screen = screen
	_hooks = hooks
	screen.add_child(self)


# --- Gates -------------------------------------------------------------------------------------


## Whether `action` may happen (TutorialActions.allows); a refusal sends `refused`.
func allows(action: StringName, args: Dictionary = {}) -> bool:
	if TutorialActions.allows(gate, action, args):
		return true
	refused.emit(action, args)
	return false


## Whether `action` may happen, asked quietly (a key's look, the drag's landing light).
func asks(action: StringName, args: Dictionary = {}) -> bool:
	return TutorialActions.allows(gate, action, args)


## Whether `card` may be picked up from its basket, or from the row (`from_row`: the guided run
## lets a placed card back only when the row left fits a step) (PICK_CARD); a refusal sends
## `refused`.
func may_pick(card: CardInstance, from_row: bool = false) -> bool:
	var args: Dictionary = card_args(card)
	args[TutorialEvents.ARG_FROM_ROW] = from_row
	return allows(TutorialActions.PICK_CARD, args)


## Whether `card` may land at the row's compacted index `slot` (PLACE_CARD); a refusal sends
## `refused` unless `quiet` (the drag's landing light asks on every move).
func may_place(card: CardInstance, slot: int, quiet: bool = false) -> bool:
	var args: Dictionary = card_args(card)
	args[TutorialEvents.ARG_SLOT] = slot
	if quiet:
		return asks(TutorialActions.PLACE_CARD, args)
	return allows(TutorialActions.PLACE_CARD, args)


## A card's args: its definition's id and its instance id.
static func card_args(card: CardInstance) -> Dictionary:
	var id: StringName = card.definition.id if card != null and card.definition != null else &""
	return {
		TutorialEvents.ARG_CARD: id,
		TutorialEvents.ARG_INSTANCE: card.instance_id if card != null else 0,
	}


# --- Events ------------------------------------------------------------------------------------


## Sends `event` with `args` on the screen's guide_event.
func emit(event: StringName, args: Dictionary = {}) -> void:
	_hooks.emit(event, args)


## A card was picked up, from the row or a basket (CARD_PICKED).
func picked(card: CardInstance, from_row: bool) -> void:
	var args: Dictionary = card_args(card)
	args[TutorialEvents.ARG_FROM_ROW] = from_row
	emit(TutorialEvents.CARD_PICKED, args)


## `card` landed in the row (CARD_PLACED, at its index now), or went back from it to its basket
## (`removed`: CARD_REMOVED).
func moved(card: CardInstance, removed: bool = false) -> void:
	var args: Dictionary = card_args(card)
	if removed:
		emit(TutorialEvents.CARD_REMOVED, args)
		return
	args[TutorialEvents.ARG_SLOT] = _screen.run.row.find(card)
	emit(TutorialEvents.CARD_PLACED, args)


## The row's projected total in planning: PROJECTED when it or the quota changed.
func projected(total: int, quota: int) -> void:
	var now: Array[int] = [total, quota]
	if now == _projected:
		return
	_projected = now
	emit(
		TutorialEvents.PROJECTED, {TutorialEvents.ARG_TOTAL: total, TutorialEvents.ARG_QUOTA: quota}
	)


## The count-up finished (COUNT_FINISHED), and MISS when the shift missed its quota.
func counted(run: RunState) -> void:
	emit(TutorialEvents.COUNT_FINISHED)
	if not run.history.is_empty() and not run.history[-1].passed:
		emit(TutorialEvents.MISS)


## The run's results opened (RESULTS): won or lost, and the coins the run paid.
func results(run: RunState) -> void:
	var won: bool = run.phase == RunState.Phase.WON
	var coins: int = CoinPayout.for_run(run).total()
	emit(TutorialEvents.RESULTS, {TutorialEvents.ARG_WON: won, TutorialEvents.ARG_COINS: coins})


## Sends HANDBOOK_OPENED whenever `page` opens; returns it.
func watch(page: HandbookPage) -> HandbookPage:
	_handbook = page
	if page != null:
		page.opened.connect(func(_entry: StringName) -> void: emit(TutorialEvents.HANDBOOK_OPENED))
	return page


## Whether a guided step or a tip shows now (`showing`).
func shows() -> bool:
	return showing.is_valid() and bool(showing.call())


# --- Overlay -----------------------------------------------------------------------------------


## Puts the director's `overlay` on the screen, in a layer of its own under the hover tips and
## the handbook (they draw over it). The layer hides while the handbook, the cart or the pause is
## open or the shift is counted; it keeps its process mode, so it freezes under the pause.
func mount_overlay(overlay: Control) -> void:
	if _layer == null:
		_layer = Control.new()
		_layer.name = "TutorialLayer"
		_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
		_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_screen.add_child(_layer)
		_screen.move_child(_layer, _screen._glyph_tips.get_index())
	_layer.add_child(overlay)
	_layer.visible = not overlay_covered()


## Whether something covers the tutorial's overlay now: the handbook, the cart, the pause or the
## count.
func overlay_covered() -> bool:
	var paused: bool = _screen._pause != null and _screen._pause.is_open()
	var deck: bool = _screen._deck_view != null and _screen._deck_view.visible
	var handbook: bool = _handbook != null and _handbook.is_open()
	return paused or deck or _screen._counting or handbook


## The overlay's layer (null before mount_overlay).
func layer() -> Control:
	return _layer


func _process(_delta: float) -> void:
	if _screen.run == null:
		return
	_watch_planning()
	_watch_scan()
	_hide_hint(shows())
	if _layer != null:
		_layer.visible = not overlay_covered()


## PLANNING_READY once per shift (and again after a resume or a new run) as planning takes input.
func _watch_planning() -> void:
	var run: RunState = _screen.run
	if run.phase != RunState.Phase.PLANNING or _screen._busy() or _screen._redraw_busy:
		return
	if _screen._cart_reveal.is_open() or (_ready_run == run and _ready_shift == run.shift_index):
		return
	_ready_run = run
	_ready_shift = run.shift_index
	_projected = []
	emit(TutorialEvents.PLANNING_READY, {TutorialEvents.ARG_SHIFT: run.shift_index + 1})


## SCAN_HELD once per item whose scan hold ended (ScanController.is_full after its hold_ms).
func _watch_scan() -> void:
	var scan: ScanController = _screen._scan
	var view: ItemView = scan.scanned()
	if view == null:
		_scanned = null
		return
	if not scan.is_full() or view.card == _scanned or view.card == null:
		return
	_scanned = view.card
	emit(TutorialEvents.SCAN_HELD, card_args(view.card))


## The monitor's empty-belt hint hides while a step shows (`hidden`) and comes back after.
func _hide_hint(hidden: bool) -> void:
	if not hidden:
		if _hint != null and is_instance_valid(_hint):
			_hint.visible = true
		_hint = null
		return
	var column: MonitorItemColumn = _screen._monitor.item_column()
	var hint: Label = column.get_node_or_null("Hint") as Label if column != null else null
	if hint != null and hint.text == MonitorText.EMPTY_BELT:
		hint.visible = false
		_hint = hint


# --- Anchors -----------------------------------------------------------------------------------


## The anchor `id`'s rect (TutorialAnchors) in global coordinates, Rect2() when it isn't shown.
func anchor_rect(id: StringName) -> Rect2:
	var stage: ShiftStage = _screen._stage
	var target: ReceiptTarget = _screen._receipt.target
	var rect: Rect2 = Rect2()
	match id:
		TutorialAnchors.QUOTA:
			var row: Control = target.get_node_or_null("AmountRow") as Control
			rect = rect_of_all([target.beat, target.caption, row]) if target.visible else Rect2()
		TutorialAnchors.PROJ:
			var parts: Array = [target.total_caption, target.hero, target.over_row]
			rect = rect_of_all(parts) if target.visible else Rect2()
		TutorialAnchors.TICKETS:
			rect = _all(TutorialAnchors.SLOT, _screen._slots.size())
		TutorialAnchors.BASKETS:
			rect = _all(TutorialAnchors.BASKET, stage.baskets.basket_lefts().size())
		TutorialAnchors.DAY_SLIP:
			rect = rect_of(_screen._week.slip) if _screen._week.slip.is_open() else Rect2()
		TutorialAnchors.WEEK_CARD:
			var card: WeekCard = _screen._week.card
			rect = rect_of(card.card()) if card.is_open() else Rect2()
		_:
			rect = _part_rect(id)
	return rect


## The rect of a control of the screen (a fixed anchor), a machine part, or an indexed anchor.
func _part_rect(id: StringName) -> Rect2:
	var parts: Dictionary[StringName, Control] = _parts()
	if parts.has(id):
		return rect_of(parts[id])
	if String(id).begins_with("machine_") or String(id).begins_with(TutorialAnchors.PRIZE):
		return _machine_rect(id)
	return _indexed_rect(id)


## The fixed anchors that are one control each.
func _parts() -> Dictionary[StringName, Control]:
	var stage: ShiftStage = _screen._stage
	var target: ReceiptTarget = _screen._receipt.target
	return {
		TutorialAnchors.RECEIPT: _screen._receipt,
		TutorialAnchors.CHECKOUT: _screen._checkout_button,
		TutorialAnchors.REDRAW: _screen._redraw_button,
		TutorialAnchors.WEEK: stage.week_glass,
		TutorialAnchors.CAL: stage.day_calendar,
		TutorialAnchors.MEDALS: stage.medal_case,
		TutorialAnchors.GAUGE: stage.gauge_panel,
		TutorialAnchors.LOYALTY: stage.loyalty_card,
		TutorialAnchors.CART: stage.deck_button,
		TutorialAnchors.MENU: stage.top_bar.menu_button,
		TutorialAnchors.MONITOR: stage.monitor,
		TutorialAnchors.MISS_STAMP: target.stamp,
		TutorialAnchors.RESULTS: _screen._results,
	}


## The machine's parts, while a visit is open (under the store camera's zoom).
func _machine_rect(id: StringName) -> Rect2:
	var view: RewardMachineView = _screen._machine.view
	if not _screen._machine.is_open():
		return Rect2()
	var rect: Rect2 = Rect2()
	match id:
		TutorialAnchors.MACHINE_KEYS:
			rect = rect_of_all(view.keys)
		TutorialAnchors.MACHINE_PUSH:
			var tray: MachineTray = view.tray
			var shown: bool = tray.is_visible_in_tree()
			rect = tray.get_global_transform() * tray.flap_rect() if shown else Rect2()
		TutorialAnchors.MACHINE_PRIZES:
			rect = rect_of_all(view.tickets)
		TutorialAnchors.MACHINE_SKIP:
			rect = rect_of(view.skip_bin)
		TutorialAnchors.MACHINE_SIGN:
			rect = rect_of(view.head)
		_:
			var key: int = TutorialAnchors.index_of(id, TutorialAnchors.MACHINE_KEY)
			var prize: int = TutorialAnchors.index_of(id, TutorialAnchors.PRIZE)
			if key >= 0 and key < view.keys.size():
				rect = rect_of(view.keys[key])
			elif prize >= 0 and prize < view.tickets.size():
				rect = rect_of(view.tickets[prize])
	return rect


## A slot's ticket, a hand place's item, a basket, a slot's whole spot, or a belt item's family
## icons or rule chip.
func _indexed_rect(id: StringName) -> Rect2:
	var spot: int = TutorialAnchors.index_of(id, TutorialAnchors.SPOT)
	if spot >= 0:
		return _spot_rect(spot)
	var slot: int = TutorialAnchors.index_of(id, TutorialAnchors.SLOT)
	var place: int = TutorialAnchors.index_of(id, TutorialAnchors.HAND)
	var basket: int = TutorialAnchors.index_of(id, TutorialAnchors.BASKET)
	var rect: Rect2 = Rect2()
	if slot >= 0 and slot < _screen._slots.size():
		var panel: PanelContainer = _screen._slots[slot]
		rect = panel.get_global_transform() * RowStrip.TICKET_RECT if _shown(panel) else Rect2()
	elif place >= 0:
		var view: ItemView = _screen._hand_box.view_at(place) as ItemView
		rect = view.get_global_transform() * view.hit_rect() if _shown(view) else Rect2()
	elif basket >= 0 and basket < _screen._stage.baskets.basket_lefts().size():
		var baskets: HandBaskets = _screen._stage.baskets
		rect = baskets.get_global_transform() * baskets.basket_rect(basket)
	else:
		rect = _sticker_rect(id)
	return rect


## Slot `slot`'s whole spot: its cell (the belt place and the ticket) and the item on it, lifted
## or not (SPOT: what a callout keeps clear).
func _spot_rect(slot: int) -> Rect2:
	if slot >= _screen._slots.size():
		return Rect2()
	var rect: Rect2 = rect_of(_screen._slots[slot])
	if slot < _screen._row_views.size():
		rect = _merge(rect, rect_of(_screen._row_views[slot] as Control))
	return rect


## A belt item's family icons (FAMILIES) or rule chip (RULE) on its ticket.
func _sticker_rect(id: StringName) -> Rect2:
	var families: int = TutorialAnchors.index_of(id, TutorialAnchors.FAMILIES)
	var rule: int = TutorialAnchors.index_of(id, TutorialAnchors.RULE)
	var slot: int = maxi(families, rule)
	if slot < 0 or slot >= _screen._row_views.size():
		return Rect2()
	var item: ItemView = _screen._row_views[slot] as ItemView
	if item == null:
		return Rect2()
	if families >= 0:
		return rect_of_all(item.sticker().glyphs())
	return rect_of(item.sticker().summary())


## Every indexed anchor `prefix` 0 .. count - 1 together.
func _all(prefix: String, count: int) -> Rect2:
	var rect: Rect2 = Rect2()
	for index: int in range(count):
		rect = _merge(rect, anchor_rect(TutorialAnchors.indexed(prefix, index)))
	return rect


## `control`'s rect in global coordinates (its scale and the camera's zoom included), Rect2()
## when it isn't visible.
static func rect_of(control: Control) -> Rect2:
	if not _shown(control):
		return Rect2()
	return control.get_global_transform() * Rect2(Vector2.ZERO, control.size)


## The shown ones of `controls` together (Rect2() when none shows).
static func rect_of_all(controls: Array) -> Rect2:
	var rect: Rect2 = Rect2()
	for control: Variant in controls:
		rect = _merge(rect, rect_of(control as Control))
	return rect


static func _shown(control: Control) -> bool:
	return control != null and is_instance_valid(control) and control.is_visible_in_tree()


static func _merge(into: Rect2, rect: Rect2) -> Rect2:
	if not rect.has_area():
		return into
	return rect if not into.has_area() else into.merge(rect)
