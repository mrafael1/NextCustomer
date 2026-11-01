class_name RepackFlow
extends RefCounted
## The repack on the shift screen (#122, a badge pin: RunPins.repack). With the pin worn, a hand
## item picked up in planning makes every empty place of the other baskets a click target
## (RepackMark, invisible: no highlighted zone, the user's call of 2026-11-01); a click on one moves
## the item there. Dragged, the item can also drop on any place of another basket
## (CardDrag.set_place_target, which ticks as the place changes): an empty place takes it, an item
## there swaps with it. Each move is free, logged as `repack` and saved. Split out of
## ShiftScreen to keep that file short; like StartChoice it is a part of the screen and works on its
## run and display.

var _screen: ShiftScreen
var _log: EventLogService
## The click targets, on the empty places that take the picked item.
var _marks: Array[RepackMark] = []


func _init(screen: ShiftScreen, event_log: EventLogService) -> void:
	_screen = screen
	_log = event_log
	_screen._drag.set_place_target(_place_at)
	_screen._drag.place_dropped.connect(_on_place_dropped)


## Marks the empty places that take the picked hand item, or none (call after the hand is shown).
func refresh() -> void:
	_clear()
	var from: int = _picked_place()
	if from < 0:
		return
	var run: RunState = _screen.run
	var by_place: Array[CardInstance] = run.hand_places()
	for place: int in range(by_place.size()):
		if by_place[place] == null and RunPins.can_repack(run, from, place):
			var mark: RepackMark = _add_mark(place)
			mark.gui_input.connect(_on_mark_input.bind(place))
			_marks.append(mark)


## The marks shown (for tests), left first.
func marks() -> Array[RepackMark]:
	return _marks.duplicate()


## Moves the picked hand item to `place` (a click on a mark, a drop): logged, saved and shown.
## False, changing nothing, when the run refuses it.
func move_to(place: int) -> bool:
	var run: RunState = _screen.run
	var from: int = _picked_place()
	if from < 0 or not RunPins.can_repack(run, from, place):
		return false
	var card: CardInstance = run.deck.hand()[from]
	var other: CardInstance = run.deck.hand()[place]
	var on_belt: bool = run.row.has(other)
	if not RunPins.repack(run, from, place):
		return false
	_log.log_event("repack", RunEvents.repack(from, place, card, other, on_belt))
	_screen._picked = null
	_screen._picked_from_row = false
	_screen._sfx.play("card_place")
	_screen._refresh()
	_screen._save_run()
	return true


## The picked item's hand place while it can be repacked (the pin worn, planning, nothing else
## going on, a hand item picked rather than a belt one), or -1.
func _picked_place() -> int:
	var screen: ShiftScreen = _screen
	var run: RunState = screen.run
	if run == null or not RunPins.has_repack(run) or run.phase != RunState.Phase.PLANNING:
		return -1
	if screen._picked == null or screen._picked_from_row:
		return -1
	if screen._busy() or screen._redraw_mode or screen._redraw_busy:
		return -1
	return run.hand_places().find(screen._picked)


## The place of another basket under `screen_position` that takes `card`, or -1.
func _place_at(card: CardInstance, screen_position: Vector2) -> int:
	var from: int = _picked_place()
	if from < 0 or _screen._picked != card:
		return -1
	var hand: HandRow = _screen._hand_box
	var to_screen: Transform2D = hand.get_global_transform()
	for place: int in range(_screen.run.hand_places().size()):
		if not RunPins.can_repack(_screen.run, from, place):
			continue
		var corner: Vector2 = to_screen * hand.place_position(place)
		var rect: Rect2 = Rect2(corner, to_screen.basis_xform(ItemView.BASKET_SIZE))
		if rect.abs().has_point(screen_position):
			return place
	return -1


func _on_place_dropped(card: CardInstance, place: int) -> void:
	if _screen._picked != card or not move_to(place):
		if _screen._picked == card:
			_screen._let_go(true)


func _on_mark_input(event: InputEvent, place: int) -> void:
	var press: InputEventMouseButton = event as InputEventMouseButton
	if press and press.pressed and press.button_index == MOUSE_BUTTON_LEFT:
		_screen.get_viewport().set_input_as_handled()
		move_to(place)


func _add_mark(place: int) -> RepackMark:
	var hand: HandRow = _screen._hand_box
	var mark: RepackMark = RepackMark.new(place)
	hand.get_parent().add_child(mark)
	mark.position = hand.position + hand.place_position(place)
	return mark


func _clear() -> void:
	for mark: RepackMark in _marks:
		mark.queue_free()
	_marks = []
