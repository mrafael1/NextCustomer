class_name PressReader
extends Node
## Reads the player's taps and holds of Space or the left mouse button while something plays
## (full build plan 6.2: the count-up's skip and fast-forward; the dessert, the capsule machine
## and the other long animations reuse it).
##
## Between begin() and end(), a press released before HOLD_THRESHOLD_MS is a tap (the tapped
## signal), and one held that long is a hold for as long as it stays down (is_holding()). Space
## and the mouse held together are one press: it ends when the last one is released. Presses are
## read from the input events, so a press and release within one frame, or around a long frame,
## are timed as they came. Events are never marked handled, so buttons still get them.
##
## What is not a press:
## - one already held when reading begins (such as the checkout click), up to its release
## - the second click of a double-click that started before reading began (the checkout's),
##   within CHECKOUT_DOUBLE_CLICK_MS of begin()
## - a mouse press on a button that can be pressed (an enabled BaseButton under the cursor)
## - a press whose release never came (the window lost focus): dropped, neither tap nor hold
##
## It processes before its users (process_priority -1), so a lost press is dropped before they
## read is_holding() in the same frame.

## A press was released before HOLD_THRESHOLD_MS: a tap, released at now_ms (clock ms).
signal tapped(now_ms: int)

## A press released before this (in ms of `clock`) is a tap; one held this long is a hold.
const HOLD_THRESHOLD_MS := 200
## A double-click's second press this soon (in ms) after begin() is the end of the double-click
## that started it (the checkout click), not a tap. Later ones are real taps (the second of two
## quick taps is a double-click too).
const CHECKOUT_DOUBLE_CLICK_MS := 500
## The sources of a press, as bits.
const PRESS_SPACE := 1
const PRESS_MOUSE := 2

## The time in ms (Time.get_ticks_msec() unless a test replaces it).
var clock: Callable = Time.get_ticks_msec
## When reading last began (clock ms), for CHECKOUT_DOUBLE_CLICK_MS.
var started_ms: int = 0
var _reading: bool = false
## The sources (PRESS_SPACE, PRESS_MOUSE) already held when reading began, such as the checkout
## click: ignored up to their release.
var _ignored: int = 0
## The sources down in the press being tracked: it ends when the last one is released.
var _down: int = 0
## When the press being tracked started (clock ms), or -1 while nothing is pressed.
var _press_ms: int = -1


func _init() -> void:
	process_priority = -1


## Starts reading. A source already held now is ignored up to its release.
func begin() -> void:
	_reading = true
	_down = 0
	_press_ms = -1
	_ignored = 0
	started_ms = _now()
	if Input.is_key_pressed(KEY_SPACE):
		_ignored |= PRESS_SPACE
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_ignored |= PRESS_MOUSE


## Stops reading and forgets every press: a release after this is no tap.
func end() -> void:
	_reading = false
	_down = 0
	_ignored = 0
	_press_ms = -1


func is_reading() -> bool:
	return _reading


## A press held past HOLD_THRESHOLD_MS (an ignored one never is: it is not tracked).
func is_holding() -> bool:
	return _press_ms >= 0 and _now() - _press_ms >= HOLD_THRESHOLD_MS


func _process(_delta: float) -> void:
	_drop_lost_presses()


func _input(event: InputEvent) -> void:
	var source: int = _press_source(event)
	if not _reading or source == 0:
		return
	var now: int = _now()
	if event.is_pressed():
		# A new press of an ignored source means its release was missed: it is tracked again.
		_ignored &= ~source
		if source == PRESS_MOUSE and not _is_tap_target():
			return
		if source == PRESS_MOUSE and _ends_checkout_double_click(event, now):
			_ignored |= PRESS_MOUSE  # Its release is dropped too.
			return
		if _down == 0:
			_press_ms = now
		_down |= source
		return
	if (_ignored & source) != 0:
		_ignored &= ~source
		return
	if (_down & source) == 0:
		return
	_down &= ~source
	if _down == 0:
		var press_ms: int = _press_ms
		_press_ms = -1
		if now - press_ms < HOLD_THRESHOLD_MS:
			tapped.emit(now)


## Forgets presses whose release never came (the window lost focus) and, while not reading,
## every press: neither is a tap or a hold.
func _drop_lost_presses() -> void:
	if not _reading:
		_down = 0
		_ignored = 0
	if not Input.is_key_pressed(KEY_SPACE):
		_down &= ~PRESS_SPACE
		_ignored &= ~PRESS_SPACE
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_down &= ~PRESS_MOUSE
		_ignored &= ~PRESS_MOUSE
	if _down == 0:
		_press_ms = -1


func _now() -> int:
	return clock.call()


## PRESS_SPACE or PRESS_MOUSE for a Space key (not an echo) or left mouse button event, else 0.
static func _press_source(event: InputEvent) -> int:
	var key: InputEventKey = event as InputEventKey
	if key != null:
		return PRESS_SPACE if key.keycode == KEY_SPACE and not key.echo else 0
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if mouse != null and mouse.button_index == MOUSE_BUTTON_LEFT:
		return PRESS_MOUSE
	return 0


## A mouse press counts anywhere except on a button that can be pressed (clicking Export log or
## Deck during the count is neither a tap nor a hold). A disabled button, such as CHECKOUT under
## the cursor during its own count, does nothing, so a press on it counts, except for the second
## click of a double-click on CHECKOUT (see _ends_checkout_double_click).
func _is_tap_target() -> bool:
	var button: BaseButton = get_viewport().gui_get_hovered_control() as BaseButton
	return button == null or button.disabled


## A double-click's second press within CHECKOUT_DOUBLE_CLICK_MS of begin(): the player
## double-clicked CHECKOUT, which is one intent to check out, not a tap.
func _ends_checkout_double_click(event: InputEvent, now: int) -> bool:
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	return mouse.double_click and now - started_ms < CHECKOUT_DOUBLE_CLICK_MS
