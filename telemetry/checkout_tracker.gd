class_name CheckoutTracker
extends RefCounted
## Collects the checkout measures defined in plan section 8 for one shift.
## All times are in ms from Time.get_ticks_msec(), passed in so tests can control them.

var placements: int = 0
var removals: int = 0
## How cards were placed and taken out: "click", "drag" or "both" (plan section 8). A shift
## with no placements or removals counts as "click".
var input_method: String = "click"
var _clicked: bool = false
var _dragged: bool = false
var _start_ms: int = 0
var _unfocused_ms: int = 0
var _focus_lost_at: int = -1
var _checkout_ms: int = -1
## Row size -> {total: true}: the distinct preview totals seen for each row size.
var _totals_by_size: Dictionary = {}


## Starts tracking at shift_start. `focused` is false if the player is already away.
func begin(now_ms: int, focused: bool = true) -> void:
	placements = 0
	removals = 0
	input_method = "click"
	_clicked = false
	_dragged = false
	_start_ms = now_ms
	_unfocused_ms = 0
	_focus_lost_at = -1 if focused else now_ms
	_checkout_ms = -1
	_totals_by_size = {}


## A card put into a slot, including a card moved within the row; `dragged` when by drag.
func on_place(dragged: bool = false) -> void:
	placements += 1
	_note_method(dragged)


## A card taken out of the row (once, even though later cards shift left); `dragged` when by
## drag.
func on_remove(dragged: bool = false) -> void:
	removals += 1
	_note_method(dragged)


func _note_method(dragged: bool) -> void:
	if dragged:
		_dragged = true
	else:
		_clicked = true
	if _dragged and _clicked:
		input_method = "both"
	else:
		input_method = "drag" if _dragged else "click"


func on_preview(row_size: int, total: int) -> void:
	if not _totals_by_size.has(row_size):
		_totals_by_size[row_size] = {}
	_totals_by_size[row_size][total] = true


## Focus changes after the checkout click no longer count: planning time ends at the click.
func on_focus_lost(now_ms: int) -> void:
	if _checkout_ms >= 0:
		return
	if _focus_lost_at < 0:
		_focus_lost_at = now_ms


func on_focus_gained(now_ms: int) -> void:
	if _checkout_ms >= 0:
		return
	if _focus_lost_at >= 0:
		_unfocused_ms += now_ms - _focus_lost_at
		_focus_lost_at = -1


func on_checkout(now_ms: int) -> void:
	on_focus_gained(now_ms)
	_checkout_ms = now_ms


## From shift_start to the checkout click, minus time the window was unfocused.
func planning_ms() -> int:
	return maxi(0, _checkout_ms - _start_ms - _unfocused_ms)


## Extra placements beyond placing each committed card once.
func rearrangements(committed_cards: int) -> int:
	return maxi(0, placements - committed_cards)


## Distinct preview totals seen for rows with as many cards as the committed row.
func distinct_totals(committed_cards: int) -> int:
	return (_totals_by_size.get(committed_cards, {}) as Dictionary).size()


## The measures logged with the checkout. Count-up time comes later, in its own event.
func measures(committed_cards: int) -> Dictionary:
	return {
		"placements": placements,
		"removals": removals,
		"rearrangements": rearrangements(committed_cards),
		"distinct_projected_totals": distinct_totals(committed_cards),
		"planning_ms": planning_ms(),
		"input_method": input_method,
	}
