class_name FullRedrawFlow
extends RefCounted
## The full redraw on the shift screen (#122, a badge pin: RunPins): in redraw mode, while the run
## can redraw every basket at once, a REDRAW ALL tag shows under the belt (BasketTags.show_all) and
## the monitor explains it on hover. A click swaps every hand item at once for one redraw (logged
## as `redraw_all` and saved), then the baskets play the basket redraw's motion one after another,
## left first, every click blocked until the last ends. Split out of ShiftScreen to keep that file
## short; like StartChoice it is a part of the screen and works on its run and display.

var _screen: ShiftScreen
var _log: EventLogService
## The baskets still to play, each [basket, places, old views, new views], left first.
var _queue: Array[Array] = []
## The run's shift and redraws used when the queue was made: a queue left by a motion stopped
## early (a new shift, the screen closed) is dropped instead of played after a later redraw.
var _queued_at: Vector2i = Vector2i(-1, -1)


func _init(screen: ShiftScreen, event_log: EventLogService) -> void:
	_screen = screen
	_log = event_log
	_screen._basket_tags.all_clicked.connect(redraw_all)
	_screen._basket_tags.all_hovered.connect(_on_hovered)


## Shows the REDRAW ALL tag in redraw mode when the run can redraw every basket (call after the
## basket tags are shown).
func show_tag() -> void:
	var run: RunState = _screen.run
	var count: int = 0
	if RunPins.can_redraw_all(run):
		count = mini(RunPins.hand_places(run).size(), run.deck.draw_pile().size())
	_screen._basket_tags.show_all(count)
	if count > 0 and _screen._basket_tags.all_tag().is_hot():
		_on_hovered(true)


## The REDRAW ALL tag clicked: every hand item swapped at once, then the motion basket by basket.
func redraw_all() -> void:
	var screen: ShiftScreen = _screen
	var run: RunState = screen.run
	if not screen._redraw_mode or screen._redraw_busy or screen._busy():
		return
	var before: Array[CardInstance] = run.hand_places()
	var places: Array[int] = RunPins.redraw_all(run)
	if places.is_empty():
		return
	var after: Array[CardInstance] = run.hand_places()
	var replaced: Array[CardInstance] = []
	var received: Array[CardInstance] = []
	_queue = []
	for place: int in places:
		replaced.append(before[place])
		received.append(after[place])
		var basket: int = HandRow.basket_of(place)
		if _queue.is_empty() or _queue[-1][0] != basket:
			_queue.append([basket, [] as Array[int], [] as Array[Control], [] as Array[Control]])
		_queue[-1][1].append(place)
		_queue[-1][2].append(BasketRedraw.ghost(before[place], run.balance))
		_queue[-1][3].append(BasketRedraw.ghost(after[place], run.balance))
	_queued_at = Vector2i(run.shift_index, run.redraws_used)
	_log.log_event("redraw_all", RunEvents.redraw(-1, places, replaced, received))
	screen._redraw_mode = false
	screen._redraw_busy = true
	screen._save_run()
	screen._refresh()
	var left: int = run.redraws_allowed - run.redraws_used
	screen._monitor.show_redraw(
		RedrawNotice.redrawing(
			left, RedrawNotice.definitions(replaced), RedrawNotice.definitions(received)
		)
	)
	play_next()


## Plays the next basket's motion of a full redraw. False when none is left (or the queue is
## stale): the redraw is over.
func play_next() -> bool:
	var run: RunState = _screen.run
	if _queued_at != Vector2i(run.shift_index, run.redraws_used):
		_queue = []
	if _queue.is_empty():
		return false
	var step: Array = _queue.pop_front()
	var places: Array[int] = step[1]
	var old_views: Array[Control] = step[2]
	var new_views: Array[Control] = step[3]
	var redraw: BasketRedraw = _screen._basket_redraw
	var reduced: bool = _screen.profile.reduced_motion()
	var first: float = redraw.tuning.pop_start(0, reduced)
	var gap: float = redraw.tuning.pop_start(1, reduced) - first
	_screen._sfx.play("shuffle")
	_screen._sfx.play_series("card_place", new_views.size(), gap, first)
	redraw.play(step[0], places, old_views, new_views)
	return true


func _on_hovered(hot: bool) -> void:
	var screen: ShiftScreen = _screen
	if not screen._redraw_mode or screen._redraw_busy:
		return
	var run: RunState = screen.run
	if not hot:
		screen._monitor.show_redraw(RedrawNotice.of_run(run, screen._basket_tags.hovered()))
		return
	var items: Array[CardDefinition] = []
	var by_place: Array[CardInstance] = run.hand_places()
	for place: int in RunPins.hand_places(run):
		items.append(by_place[place].definition)
	var left: int = run.redraws_allowed - run.redraws_used
	var pile: int = run.deck.draw_pile().size()
	screen._monitor.show_redraw(RedrawNotice.all_hovered(left, items, pile))
