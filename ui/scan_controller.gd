class_name ScanController
extends Node
## The hover scanner on the shift screen (#75), opt-in since #80: hovering an item in the hand or on
## the belt is quiet: nothing shows, nothing on the monitor, no lift, no marks, no beep. Only once
## the pointer has stayed on that same item for the hold (ScanTuning.hold_ms, in
## data/balance/scan.tres) is it scanned: the item's sprite lifts, tomato brackets mark it (the
## stage's scan layer, ScanOverlay; B2 has no handheld scanner, #80), the scanner beeps and the hung
## monitor shows the item (MonitorView.show_scan) until the scan ends, when it goes back to its
## idle screen. A belt item's full scan also frames its line on the planning receipt
## (ReceiptView.highlight_slot) until the scan ends; a hand item's frames none. The pointer
## leaving the item cancels a pending hold, and back on the item the hold starts again; another
## item starts its own. Dragging an item ends the scan, a pending hold with it (`blocked`).
##
## ShiftScreen owns it, hands it the items after each refresh (watch) and the preview's
## ScoreResult (set_result), and says when scanning the counter is off (`blocked`: while
## counting, dragging, or with an offer or the deck view open).
##
## The offers are items too (#75, decision 4A): cover_offers() watches the RECEIPT REWARDS
## machine's prize items (#77) and scans them like hand items while the machine accepts clicks
## (RewardMachineView.can_scan: once it has armed). Their scan opens in a layer on the stage's hud
## (#77 machine v2: the machine is in the zoomed world, the layer never zooms): its own marks and
## the scan popup (ScanPopup), beside the item over the machine. There
## the popup takes the clicks on it and does nothing with them: it covers the neighbouring items
## (and can cover the machine's buttons), and a click while reading it must never pick an item the
## player can't see.
##
## The monitor (and an offer's popup) shows the card's rule text verbatim. A belt item's scan also
## shows its payout and every step of its slot but BASE and PAYOUT, worded as the receipt words
## them (ReceiptView.step_line, decision 1A), so every line of the planning receipt can be read by
## scanning its item. A belt item that gives to others (#71) gets a "gives" line first (GIVES_TEXT:
## its tokens, its targets and their summed gain, "×3 to Milk, Milk, Milk  +€114", from its rail
## strip, PlanningModel.strip_of). Its tag line shows the scored tags (granted ones too); a hand
## item's its card's own.
##
## The scan follows the pointer. While the pointer is inside an offer's popup, the scanned offer
## stays, so moving over the popup never switches to an item it covers. Once the pointer is over
## neither the item nor its popup, the scan moves to the item under it, or ends: the marks clear,
## the popup hides and the monitor goes back to its idle screen. It also ends when the pointer
## leaves the window and when the player leaves (FocusWatch.player_left; ShiftScreen calls clear).
## A refresh that rebuilds the items keeps the scan on the same card (its new view) while the
## pointer is on that view (or an offer's popup); a card the refresh moved away from the pointer (a
## belt item clicked out to the hand) ends the scan.
##
## The beep (Sfx "scan_hover", the scan sound at HOVER_DB) plays only when a hold ends in the full
## scan, at most once every THROTTLE_MS. Reduced motion leaves the beam's pulse off; the hold
## still ends in the full scan, which snaps into place, and the beep still plays. debug_scan (the
## screen capture's --scan) shows the full scan at once, with no hold: it captures the scan's
## look.
## Nothing here is awaited and nothing moves the count-up's timing: scanning is off while the
## shift is counted.

const HOVER_SOUND := "scan_hover"
## The beep is the count-up's scan, this much softer.
const HOVER_DB := -8.0
## At most one beep per this many ms (of real time, unless now_ms says otherwise).
const THROTTLE_MS := 120
## The scanner's tuning (the hold), unless `tuning` is set before setup().
const TUNING_PATH := "res://data/balance/scan.tres"
## A giver's "gives" line (#71): its tokens and its targets' names (up to GIVES_NAMES of them, else
## GIVES_MANY), then its targets' summed gain (cancelled ones left out) as the line's amount.
const GIVES_TEXT := "%s to %s"
const GIVES_AMOUNT := "+€%d"
const GIVES_NAMES := 3
const GIVES_MANY := "%d items"

## Returns true while scanning is off. Set by the owner; none means never.
var blocked: Callable = Callable()
## Returns the pointer's global position. Tests set it (headless runs never move the mouse); by
## default the viewport's mouse position.
var pointer: Callable = Callable()
## Returns true when the player asked for reduced motion: no beam pulse. None means false.
var reduced_motion: Callable = Callable()
## Returns the clock the throttle and the hold read, in ms. Tests set it; by default
## Time.get_ticks_msec.
var now_ms: Callable = Callable()
## The hold's length (ScanTuning.hold_ms). Loaded from TUNING_PATH by setup() unless set before.
var tuning: ScanTuning

var _stage: ShiftStage
var _overlay: ScanOverlay
var _monitor: MonitorView
## The stage's receipt: a belt item's scan frames its line.
var _receipt: ReceiptView
var _popup: ScanPopup
## The offers' panel (cover_offers), the layer over it that an offer's scan opens in, that
## layer's marks, and the offered items.
var _offer_panel: RewardMachineView
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
## Whether the shown item has the full scan (the monitor or the popup, the lift, the marks and
## the beep), not only its quiet hover (nothing shown).
var _full: bool = false
## The clock's time (_now) the pointer came onto the shown item, while its hold is pending; -1
## while the pointer is off it (or the scan is full).
var _hold_from: int = -1
## The clock's time (_now) of the last beep.
var _beep_ms: int = -THROTTLE_MS
## A refresh rebuilt the items: the scan is shown again once they are laid out (_reshow).
var _reshow_queued: bool = false
## Whether the scan framed a line on the receipt (_highlight).
var _framed: bool = false


func _ready() -> void:
	set_process(false)
	get_window().mouse_exited.connect(clear)


## Takes the stage's scan layer, monitor and popup layer: the popup (for the offers) is built
## once and parked hidden in the popup layer; an offer's scan moves it to the offers' layer
## (cover_offers) and shows it there.
func setup(stage: ShiftStage) -> void:
	if tuning == null:
		tuning = load(TUNING_PATH) as ScanTuning
	_stage = stage
	_overlay = stage.scan_layer
	_monitor = stage.monitor
	_receipt = stage.receipt
	_popup = ScanPopup.new()
	_popup.name = "ScanPopup"
	_popup.visible = false
	stage.popup_layer.add_child(_popup)


## Scans `panel`'s offered items too (see the class comment). The layer for their scan goes on the
## stage's hud (never zoomed, over the zoomed machine), with the stage's theme.
func cover_offers(panel: RewardMachineView) -> void:
	_offer_panel = panel
	_offer_layer = Control.new()
	_offer_layer.name = "OfferScanLayer"
	_offer_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_offer_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_offer_layer.theme = _stage.theme
	# On the stage's hud, never zoomed (#77 machine v2: the machine is in the zoomed world).
	_stage.add_child(_offer_layer)
	_offer_overlay = ScanOverlay.new()
	_offer_overlay.name = "OfferScanOverlay"
	_offer_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_offer_layer.add_child(_offer_overlay)
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


## Ends the scan: the item rests, the popup hides, the monitor goes back to idle and the marks
## clear.
func clear() -> void:
	if _is_shown(_shown):
		_shown.lifted = false
	_shown = null
	_shown_card = null
	_full = false
	_hold_from = -1
	_reshow_queued = false
	if _popup != null:
		_popup.visible = false
	if _monitor != null:
		_monitor.end_scan()
	_highlight(-1)
	for marks: ScanOverlay in [_overlay, _offer_overlay]:
		if marks != null:
			marks.dock()
	set_process(false)


## The item hovered (its hold pending) or scanned (is_full), or null.
func scanned() -> ItemView:
	return _shown if _is_shown(_shown) else null


## Whether the item scanned has the full scan: its hold ended (or debug_scan showed it).
func is_full() -> bool:
	return _full and scanned() != null


## The hold's length in ms (ScanTuning.hold_ms).
func hold_ms() -> int:
	return tuning.hold_ms


## The offers' scan popup.
func popup() -> ScanPopup:
	return _popup


## The monitor a belt or hand item's scan shows on.
func monitor() -> MonitorView:
	return _monitor


## The stage's scan layer: the marks over the counter's items.
func overlay() -> ScanOverlay:
	return _overlay


## The marks over the offers (cover_offers), or null.
func offer_overlay() -> ScanOverlay:
	return _offer_overlay


## Development tools only (the screen capture's --scan): scans `card`'s item on the counter as
## the player's hover would, with the pointer held on its sprite from then on, and shows the
## full scan at once (no hold), as the capture is of the scan's look. Returns false when no item
## on the counter shows that card.
func debug_scan(card: CardInstance) -> bool:
	for item: ItemView in _items:
		if item.card == card and _is_shown(item):
			var point: Vector2 = item.sprite().get_global_rect().get_center()
			pointer = func() -> Vector2: return point
			_on_hovered(item)
			if scanned() == item:
				_go_full()
			return true
	return false


## The steps a belt item's scan lists: every step of `slot` in `result` but its BASE and
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


## The "gives" line of the belt item at `slot` in `result` (see GIVES_TEXT; `names` are the row's
## names), or empty when it gives nothing.
static func gives_line(result: ScoreResult, slot: int, names: PackedStringArray) -> String:
	var strip: RailStripSpec = PlanningModel.strip_of(result, slot, names)
	if strip == null:
		return ""
	var tokens: PackedStringArray = PackedStringArray()
	var targets: PackedStringArray = PackedStringArray()
	var gain: int = 0
	for index: int in range(strip.targets.size()):
		for token: String in strip.tokens[index].split(" ", false):
			if not tokens.has(token):
				tokens.append(token)
		targets.append(names[strip.targets[index]])
		gain += maxi(strip.gains[index], 0)
	var named: String = ", ".join(targets)
	if targets.size() > GIVES_NAMES:
		named = GIVES_MANY % targets.size()
	var text: String = GIVES_TEXT % [" ".join(tokens), named]
	return ReceiptView.joined_line(text, GIVES_AMOUNT % gain if gain > 0 else "")


## Follows the pointer while an item is scanned: see the class comment.
func _process(_delta: float) -> void:
	if _reshow_queued:
		return
	if not _is_shown(_shown) or _is_blocked_for(_shown):
		clear()
		return
	var point: Vector2 = _pointer()
	var on_item: bool = _hits(_shown, point)
	if not _full:
		_follow_hold(on_item)
	if on_item or _on_popup(point):
		return
	if _is_shown(_under) and _under != _shown and _hits(_under, point):
		_scan(_under)
		return
	clear()


## Times the quiet scan's hold while the pointer is on the item (`on_item`): off it, the hold is
## cancelled; back on it, it starts again; once it lasts hold_ms, the full scan plays.
func _follow_hold(on_item: bool) -> void:
	if not on_item:
		_hold_from = -1
	elif _hold_from < 0:
		_hold_from = _now()
	elif _now() - _hold_from >= hold_ms():
		_go_full()


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
	var on_popup: bool = _on_popup(point)
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
	if _is_shown(_shown) and _on_popup(_pointer()):
		return
	_scan(view)


func _on_unhovered(view: ItemView) -> void:
	if _under == view:
		_under = null
	# _process ends the scan or moves it once the pointer is off the item and its popup: a
	# refresh that rebuilds the item under the pointer keeps it.


## Hovers `view` quietly (nothing shown), its hold starting now.
func _scan(view: ItemView) -> void:
	_full = false
	_hold_from = _now()
	_show(view)


## The hold ended: the shown item gets the full scan, and it beeps (throttled).
func _go_full() -> void:
	if _full or not _is_shown(_shown):
		return
	_full = true
	_hold_from = -1
	_show(_shown)
	_beep()


## With the full scan, lifts `view`, marks it and shows it: a counter item's on the monitor, an
## offer's in the popup, filled and placed in the layer over the offers, beside the item over its
## panel. Quiet, the item rests, the popup hides, the monitor shows its idle screen and nothing is
## marked.
func _show(view: ItemView) -> void:
	if _is_shown(_shown) and _shown != view:
		_shown.lifted = false
	_shown = view
	_shown_card = view.card
	view.lifted = _full
	set_process(true)
	if not _full:
		_popup.visible = false
		_monitor.end_scan()
		_highlight(-1)
		for docked: ScanOverlay in [_overlay, _offer_overlay]:
			if docked != null:
				docked.dock()
		return
	var definition: CardDefinition = view.card.definition
	var lines: PackedStringArray = PackedStringArray()
	var fizzles: Array[bool] = []
	var payout: int = -1
	var slot: int = _row.find(view)
	var gives: int = 0
	if view.form == ItemView.Form.BELT and _result != null and slot >= 0:
		if slot < _result.payouts.size():
			payout = _result.payouts[slot]
		var given: String = gives_line(_result, slot, _names)
		if not given.is_empty():
			lines.append(given)
			fizzles.append(false)
			gives = 1
		for step: ScoreStep in footer_steps(_result, slot):
			lines.append(ReceiptView.step_line(step, _names, _upgrade_names, _inspection_names))
			fizzles.append(step.step_type == ScoreStep.StepType.WASTED)
	var offer: bool = _offers.has(view)
	var marks: ScanOverlay = _offer_overlay if offer else _overlay
	var other: ScanOverlay = _overlay if offer else _offer_overlay
	if other != null:
		other.clear()
	var sprite: Rect2 = ScanOverlay.lifted_sprite(view)
	if offer:
		if _popup.get_parent() != _offer_layer:
			_popup.reparent(_offer_layer, false)
		# Over the offers, a click on the popup stops there (see the class comment).
		_popup.mouse_filter = Control.MOUSE_FILTER_STOP
		_popup.visible = true
		_popup.show_card(definition, view.tags())
		_popup.place_at(
			sprite, view.below_rect(), _stage.get_global_rect(), _offer_panel.get_global_rect()
		)
		_monitor.end_scan()
		_highlight(-1)
	else:
		_popup.visible = false
		_monitor.show_scan(definition, view.tags(), payout, lines, fizzles, gives)
		_highlight(slot if view.form == ItemView.Form.BELT else -1)
	marks.pose_hover(sprite)
	if _wants_reduced_motion():
		marks.stop_beam_loop()
	else:
		marks.start_beam_loop()


## Frames `slot`'s line on the planning receipt, or none for -1. Unframing only takes the scan's
## own frame off: a hovered item's (PlanningEffects, #71) stays.
func _highlight(slot: int) -> void:
	if _receipt == null or (slot < 0 and not _framed):
		return
	_framed = slot >= 0
	_receipt.highlight_slot(slot)


func _beep() -> void:
	var now: int = _now()
	if now - _beep_ms < THROTTLE_MS:
		return
	_beep_ms = now
	Sfx.play_at(self, HOVER_SOUND, HOVER_DB)


## Whether the pointer at `point` (global) is on the popup while it shows (an offer's scan).
func _on_popup(point: Vector2) -> bool:
	return _popup.visible and _popup.get_global_rect().has_point(point)


## Whether the pointer at `point` (global) is on `view`: its sprite (lifted or not) and
## sticker (ItemView.hit_rect; the mark and the paid chip are decor).
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
