class_name ScanController
extends Node
## The hover scanner on the shift screen (#75): hovering an item in the hand or on the belt scans
## it. The item's sprite lifts, the handheld leaves its cradle and aims at it (the stage's scan
## layer, ScanOverlay, with tomato brackets and its beam), the one scan popup opens beside or
## above it (the stage's popup layer) and the scanner beeps. ShiftScreen owns it, hands it the
## items after each refresh (watch) and the preview's ScoreResult (set_result), and says when
## scanning the counter is off (`blocked`: while counting, dragging, or with an offer or the deck
## view open).
##
## The offers are items too (#75, decision 4A): cover_offers() watches the reward panel's items
## (the impulse rack and the reward print-out) and scans them like hand items while the panel
## accepts clicks (RewardPanel.can_scan: not while it pops in or its items lift out of the
## printer, nor while the deck view hides it). Their scan opens in a layer right above the panel,
## since the shade and the panel cover the stage's layers: its own marks, the same handheld out
## of its cradle and the same popup, beside the item over the panel. There the popup takes the
## clicks on it and does nothing with them: it covers the neighbouring items (and can cover the
## panel's buttons), and a click while reading it must never pick an item the player can't see.
##
## The popup shows the card's rule text verbatim. A belt item's popup also shows its payout and,
## in its footer, every step of its slot but BASE and PAYOUT, worded as the receipt words them
## (ReceiptView.step_line, decision 1A), so every line of the planning receipt can be read by
## scanning its item. Its tag line shows the scored tags (granted ones too); a hand item's its
## card's own.
##
## The scan follows the pointer. While the pointer is inside the popup, the scanned item stays,
## so moving over the popup never switches to an item it covers. Once the pointer is over neither
## the item nor its popup, the scan moves to the item under it, or ends: the scanner docks and
## the popup hides. It also ends when the pointer leaves the window and when the player leaves
## (FocusWatch.player_left; ShiftScreen calls clear). A refresh that rebuilds the items keeps the
## scan on the same card (its new view) while the pointer is on that view or the popup; a card the
## refresh moved away from the pointer (a belt item clicked out to the hand) ends the scan.
##
## The beep (Sfx "scan_hover", the scan sound at HOVER_DB) plays only when a new item is
## scanned, at most once every THROTTLE_MS: a sweep across the tray never chatters. Reduced
## motion leaves the beam's pulse off; the scan still snaps into place and the beep still plays.
## Nothing here is awaited and nothing moves the count-up's timing: scanning is off while the
## shift is counted.

const HOVER_SOUND := "scan_hover"
## The beep is the count-up's scan, this much softer.
const HOVER_DB := -8.0
## At most one beep per this many ms (of real time, unless now_ms says otherwise).
const THROTTLE_MS := 120

## Returns true while scanning is off. Set by the owner; none means never.
var blocked: Callable = Callable()
## Returns the pointer's global position. Tests set it (headless runs never move the mouse); by
## default the viewport's mouse position.
var pointer: Callable = Callable()
## Returns true when the player asked for reduced motion: no beam pulse. None means false.
var reduced_motion: Callable = Callable()
## Returns the clock the throttle reads, in ms. Tests set it; by default Time.get_ticks_msec.
var now_ms: Callable = Callable()

var _stage: ShiftStage
var _overlay: ScanOverlay
var _popup: ScanPopup
## The offers' panel (cover_offers), the layer over it that an offer's scan opens in, that
## layer's marks, and the offered items.
var _offer_panel: RewardPanel
var _offer_layer: Control
var _offer_overlay: ScanOverlay
var _offers: Array[ItemView] = []
## The belt's items in slot order, and every item watched (belt and hand).
var _row: Array[CardView] = []
var _items: Array[ItemView] = []
var _result: ScoreResult
var _names: PackedStringArray = PackedStringArray()
var _upgrade_names: PackedStringArray = PackedStringArray()
var _inspection_names: PackedStringArray = PackedStringArray()
## The item scanned and its card (a refresh's new view of that card takes the scan over).
var _shown: ItemView
var _shown_card: CardInstance
## The item the pointer last entered and hasn't left: where the scan goes once it leaves the
## scanned item and its popup.
var _under: ItemView
## The clock's time (_now) of the last beep.
var _beep_ms: int = -THROTTLE_MS
## A refresh rebuilt the items: the scan is shown again once they are laid out (_reshow).
var _reshow_queued: bool = false


func _ready() -> void:
	set_process(false)
	get_window().mouse_exited.connect(clear)


## Takes the stage's scan layer and popup layer: the popup is built once, hidden, and reused.
func setup(stage: ShiftStage) -> void:
	_stage = stage
	_overlay = stage.scan_layer
	_popup = ScanPopup.new()
	_popup.name = "ScanPopup"
	_popup.visible = false
	stage.popup_layer.add_child(_popup)


## Scans `panel`'s offered items too (see the class comment). The layer for their scan goes in
## right above the panel, as its next sibling, with the stage's theme.
func cover_offers(panel: RewardPanel) -> void:
	_offer_panel = panel
	_offer_layer = Control.new()
	_offer_layer.name = "OfferScanLayer"
	_offer_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offer_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_offer_layer.theme = _stage.theme
	panel.add_sibling(_offer_layer)
	_offer_overlay = ScanOverlay.new()
	_offer_overlay.name = "OfferScanOverlay"
	_offer_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_offer_layer.add_child(_offer_overlay)
	_offer_overlay.set_handheld(_stage.handheld)
	panel.items_shown.connect(_on_offers_shown)
	_on_offers_shown()


## The items on screen after a refresh: the belt's `row` (in slot order) and the hand's `hand`.
## Each one's hover is watched. A scan of a card that is still on screen moves to its new view,
## shown again (without a beep) once the new items are laid out; one whose card left ends.
func watch(row: Array[CardView], hand: Array[Control]) -> void:
	_row = row.duplicate()
	_items.clear()
	for view: CardView in row:
		_watch(view as ItemView)
	for view: Control in hand:
		_watch(view as ItemView)
	if not _is_shown(_under) or not (_items.has(_under) or _offers.has(_under)):
		_under = null
	_queue_reshow()


## The ScoreResult the belt shows (the preview's, or a resumed checkout's) and the names its
## steps need: the row's cards', the run's upgrades' and the shift's inspections'. A scan on
## screen is shown again with it once the refresh's items are laid out.
func set_result(
	result: ScoreResult,
	names: PackedStringArray,
	upgrade_names: PackedStringArray,
	inspection_names: PackedStringArray
) -> void:
	_result = result
	_names = names
	_upgrade_names = upgrade_names
	_inspection_names = inspection_names
	_queue_reshow()


## Ends the scan: the item rests, the popup hides and the scanner docks.
func clear() -> void:
	if _is_shown(_shown):
		_shown.lifted = false
	_shown = null
	_shown_card = null
	_reshow_queued = false
	if _popup != null:
		_popup.visible = false
	for marks: ScanOverlay in [_overlay, _offer_overlay]:
		if marks != null:
			marks.dock()
	set_process(false)


## The item scanned, or null.
func scanned() -> ItemView:
	return _shown if _is_shown(_shown) else null


func popup() -> ScanPopup:
	return _popup


## The stage's scan layer: the marks over the counter's items.
func overlay() -> ScanOverlay:
	return _overlay


## The marks over the offers (cover_offers), or null.
func offer_overlay() -> ScanOverlay:
	return _offer_overlay


## Development tools only (the screen capture's --scan): scans `card`'s item on the counter as
## the player's hover would, with the pointer held on its sprite from then on. Returns false
## when no item on the counter shows that card.
func debug_scan(card: CardInstance) -> bool:
	for item: ItemView in _items:
		if item.card == card and _is_shown(item):
			var point: Vector2 = item.sprite().get_global_rect().get_center()
			pointer = func() -> Vector2: return point
			_on_hovered(item)
			return true
	return false


## The steps a belt item's popup footer lists: every step of `slot` in `result` but its BASE and
## PAYOUT (and the armed effects, which print no line), in step order.
static func footer_steps(result: ScoreResult, slot: int) -> Array[ScoreStep]:
	var steps: Array[ScoreStep] = []
	for step: ScoreStep in result.steps:
		if step.slot != slot:
			continue
		match step.step_type:
			ScoreStep.StepType.BASE, ScoreStep.StepType.PAYOUT, ScoreStep.StepType.EFFECT_ARMED:
				continue
		steps.append(step)
	return steps


## Follows the pointer while an item is scanned: see the class comment.
func _process(_delta: float) -> void:
	if _reshow_queued:
		return
	if not _is_shown(_shown) or _is_blocked_for(_shown):
		clear()
		return
	var point: Vector2 = _pointer()
	if _popup.get_global_rect().has_point(point) or _hits(_shown, point):
		return
	if _is_shown(_under) and _under != _shown and _hits(_under, point):
		_scan(_under)
		return
	clear()


## Shows the scan again at the end of the frame, after the containers have laid out a refresh's
## new items (deferred calls run in order, after their sorts). An offer's scan needs none: a
## refresh never rebuilds the offers.
func _queue_reshow() -> void:
	if _shown_card == null or _reshow_queued or _offers.has(_shown):
		return
	_reshow_queued = true
	_reshow.call_deferred()


## The scanned card's view (a new one after a refresh) shown again while the pointer is on it or
## on the popup; the scan ends when the card left, moved away from the pointer, or scanning is
## off.
func _reshow() -> void:
	if not _reshow_queued:
		return
	_reshow_queued = false
	if _is_blocked():
		clear()
		return
	var point: Vector2 = _pointer()
	var on_popup: bool = _popup.visible and _popup.get_global_rect().has_point(point)
	for item: ItemView in _items:
		if item.card == _shown_card and _is_shown(item):
			if on_popup or _hits(item, point):
				_show(item)
				return
			break
	clear()


func _watch(view: ItemView) -> void:
	if view == null:
		return
	_items.append(view)
	_connect(view)


## The offers were built again: a scan of the old ones ends and the new ones are watched.
func _on_offers_shown() -> void:
	if _offers.has(_shown):
		clear()
	_offers = _offer_panel.items()
	for view: ItemView in _offers:
		_connect(view)


func _connect(view: ItemView) -> void:
	if not view.hovered.is_connected(_on_hovered):
		view.hovered.connect(_on_hovered)
		view.unhovered.connect(_on_unhovered)


func _on_hovered(view: ItemView) -> void:
	_under = view
	if _is_blocked_for(view) or view == _shown:
		return
	# Over the popup, the scanned item stays: the pointer is reading it.
	if _is_shown(_shown) and _popup.get_global_rect().has_point(_pointer()):
		return
	_scan(view)


func _on_unhovered(view: ItemView) -> void:
	if _under == view:
		_under = null
	# _process ends the scan or moves it once the pointer is off the item and its popup: a
	# refresh that rebuilds the item under the pointer keeps it.


## Scans `view`: a new item beeps (throttled).
func _scan(view: ItemView) -> void:
	var fresh: bool = view.card != _shown_card
	if _is_shown(_shown) and _shown != view:
		_shown.lifted = false
	_show(view)
	if fresh:
		_beep()


## Lifts `view`, fills and places the popup, and poses the scanner on the side away from a hand
## item's popup. An offer's scan opens in the layer over the offers, beside the item over its
## panel; a counter item's on the stage.
func _show(view: ItemView) -> void:
	if _is_shown(_shown) and _shown != view:
		_shown.lifted = false
	_shown = view
	_shown_card = view.card
	view.lifted = true
	var definition: CardDefinition = view.card.definition
	var lines: PackedStringArray = PackedStringArray()
	var fizzles: Array[bool] = []
	var payout: int = -1
	var slot: int = _row.find(view)
	if view.form == ItemView.Form.BELT and _result != null and slot >= 0:
		if slot < _result.payouts.size():
			payout = _result.payouts[slot]
		for step: ScoreStep in footer_steps(_result, slot):
			lines.append(ReceiptView.step_line(step, _names, _upgrade_names, _inspection_names))
			fizzles.append(step.step_type == ScoreStep.StepType.WASTED)
	var offer: bool = _offers.has(view)
	var layer: Control = _offer_layer if offer else _stage.popup_layer
	if _popup.get_parent() != layer:
		_popup.reparent(layer, false)
	# Over the offers, a click on the popup stops there (see the class comment).
	_popup.mouse_filter = Control.MOUSE_FILTER_STOP if offer else Control.MOUSE_FILTER_IGNORE
	var marks: ScanOverlay = _offer_overlay if offer else _overlay
	var other: ScanOverlay = _overlay if offer else _offer_overlay
	if other != null:
		other.clear()
	_popup.visible = true
	_popup.show_card(definition, view.aisle, view.tags(), payout, lines, fizzles)
	var sprite: Rect2 = view.sprite().get_global_rect()
	_popup.place_at(sprite, view.below_rect(), _offer_layout() if offer else _stage.scan_layout())
	marks.pose_hover(sprite, _popup.placement == ScanPopup.Placement.RIGHT)
	if _wants_reduced_motion():
		marks.stop_beam_loop()
	else:
		marks.start_beam_loop()
	set_process(true)


## Where an offer's popup may open (global): on the stage, beside the item over the offers'
## panel (as a hand item's opens over the tray), never above the panel's top.
func _offer_layout() -> ScanLayout:
	var panel: Rect2 = _offer_panel.get_global_rect()
	return ScanLayout.new(_stage.get_global_rect(), panel, panel.position.y)


func _beep() -> void:
	var now: int = _now()
	if now - _beep_ms < THROTTLE_MS:
		return
	_beep_ms = now
	Sfx.play_at(self, HOVER_SOUND, HOVER_DB)


## Whether the pointer at `point` (global) is on `view`: its sprite (lifted or not), sticker
## and chips.
static func _hits(view: ItemView, point: Vector2) -> bool:
	return (view.get_global_transform() * view.hit_rect()).has_point(point)


## Whether `view` is an item still on screen. Untyped: a freed item may be passed.
static func _is_shown(view: Variant) -> bool:
	return is_instance_valid(view) and (view as Node).is_inside_tree()


## Whether scanning `view` is off: an offer's while its panel can't be scanned, a counter
## item's while `blocked` says so.
func _is_blocked_for(view: ItemView) -> bool:
	if _offers.has(view):
		return not _offer_panel.can_scan()
	return _is_blocked()


func _is_blocked() -> bool:
	return blocked.is_valid() and bool(blocked.call())


func _wants_reduced_motion() -> bool:
	return reduced_motion.is_valid() and bool(reduced_motion.call())


func _now() -> int:
	if now_ms.is_valid():
		return int(now_ms.call())
	return Time.get_ticks_msec()


func _pointer() -> Vector2:
	if pointer.is_valid():
		return pointer.call()
	return get_viewport().get_mouse_position()
