class_name OfferTimeline
extends RefCounted
## The presentation timeline of one offer (a reward, the impulse rack or the upgrade tickets),
## logged with its choice (plan section 8, since v0.20). Every time is in ms from the moment the
## offer starts presenting (its panel's show_offer), up to:
## - `presented_ms`: the offer is fully shown (today the end of the panel's pop-in, UiKit.pop_in;
##   later phase 3's print-out or kiosk ceremony);
## - `armed_ms`: the offer accepts clicks (today 350 ms after the show, once the mouse is released);
## - `decide_ms`: the choice is applied (at the deck limit, once the card to remove is chosen).
## A moment the choice came before is logged as NOT_REACHED (-1). An offer shown again after the
## deck view or the deck-full chooser keeps its timeline (it starts at the first show, as decide_ms
## always did); a resumed offer starts a new one at its show. An offer that was never shown (no
## rack, a debug replay of the rack applied at once, or a --demo-row run's skipped rack) logs 0 for
## every time. The top bar's Deck can't hide an offer before it arms, so armed_ms never includes
## time in the deck view.
##
## All times come in as Time.get_ticks_msec() values, passed in so tests can control them.

const NOT_REACHED := -1

## Set by a skippable presentation when the player skips it (the full build plan's measure of
## skipped presentations). Phase 1's pop-in can't be skipped, so it stays false until phase 3's
## print-out and kiosk ceremony set it.
var presentation_skipped: bool = false
## When the offer started presenting, or -1 for an offer that was never shown.
var _shown_at: int = -1
var _presented_at: int = -1
var _armed_at: int = -1


## `shown_at_ms` is when the offer starts presenting; leave it out for an offer never shown.
func _init(shown_at_ms: int = -1) -> void:
	_shown_at = shown_at_ms


## The offer is fully shown. Only the first call counts.
func mark_presented(now_ms: int) -> void:
	if _shown_at >= 0 and _presented_at < 0:
		_presented_at = now_ms


## Marks the offer presented when `presentation` (its pop-in, later its ceremony) finishes.
func presented_when(presentation: Tween) -> void:
	presentation.finished.connect(func() -> void: mark_presented(Time.get_ticks_msec()))


## The offer accepts clicks. Only the first call counts.
func mark_armed(now_ms: int) -> void:
	if _shown_at >= 0 and _armed_at < 0:
		_armed_at = now_ms


## The logged times for a choice made at `now_ms`: decide_ms, presented_ms, armed_ms and
## presentation_skipped, in that order.
func fields(now_ms: int) -> Dictionary:
	if _shown_at < 0:
		return {"decide_ms": 0, "presented_ms": 0, "armed_ms": 0, "presentation_skipped": false}
	return {
		"decide_ms": now_ms - _shown_at,
		"presented_ms": _since_shown(_presented_at, now_ms),
		"armed_ms": _since_shown(_armed_at, now_ms),
		"presentation_skipped": presentation_skipped,
	}


func _since_shown(at_ms: int, now_ms: int) -> int:
	if at_ms < 0 or at_ms > now_ms:
		return NOT_REACHED
	return at_ms - _shown_at
