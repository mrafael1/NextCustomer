class_name OfferTimeline
extends RefCounted
## The presentation timeline of one RECEIPT REWARDS machine visit (#77), logged with its pick or
## bin in the machine_visit event (plan section 8, since v0.20 for the offers before it). Every
## time is in ms from the moment the visit starts presenting: the ticket's at the receipt's
## flight to the machine's slot (the dessert's printer feed), the bonus ticket's and STAMP DAY's
## at their start. Up to:
## - `presented_ms`: the prizes are fully shown (the end of the last reveal);
## - `armed_ms`: the prizes accept clicks (after the last reveal, once the mouse is released);
## - `decide_ms`: the pick or bin is applied (at the deck limit, once the card to remove is
##   chosen).
## presented_ms and armed_ms leave out the chute wait (`chute_wait_ms`: from the chute keys
## arming to the CONFIRM; the player hovering keys and reading odds cards), so they measure the
## visit's non-interactive time (plan section 8); decide_ms keeps the whole time.
## A moment the choice came before is logged as NOT_REACHED (-1). A visit shown again after the
## deck view or the deck-full chooser keeps its timeline; a resumed visit starts a new one at its
## show (its prizes are shown revealed, presented at once). A visit that was never shown logs 0
## for every time.
##
## All times come in as Time.get_ticks_msec() values, passed in so tests can control them.

const NOT_REACHED := -1

## Set when the player fast-forwards the visit's presentation (the full build plan's measure of
## skipped presentations): a click during a non-interactive beat, or the shift's dessert skipped
## before the visit armed.
var presentation_skipped: bool = false
## When the offer started presenting, or -1 for an offer that was never shown.
var _shown_at: int = -1
var _presented_at: int = -1
var _armed_at: int = -1
## The chute wait: when it started (-1: not waiting) and its length so far.
var _wait_from: int = -1
var _waited: int = 0


## `shown_at_ms` is when the offer starts presenting; leave it out for an offer never shown.
func _init(shown_at_ms: int = -1) -> void:
	_shown_at = shown_at_ms


## The offer is fully shown. Only the first call counts.
func mark_presented(now_ms: int) -> void:
	if _shown_at >= 0 and _presented_at < 0:
		_presented_at = now_ms


## Marks the offer presented when `presentation` (its pop-in) finishes.
func presented_when(presentation: Tween) -> void:
	presentation.finished.connect(func() -> void: mark_presented(Time.get_ticks_msec()))


## The offer accepts clicks. Only the first call counts.
func mark_armed(now_ms: int) -> void:
	if _shown_at >= 0 and _armed_at < 0:
		_armed_at = now_ms


## The chute keys accept clicks: the interactive chute wait starts. Only while not waiting.
func start_wait(now_ms: int) -> void:
	if _shown_at >= 0 and _wait_from < 0 and _presented_at < 0:
		_wait_from = now_ms


## The chute is confirmed: the wait ends (nothing without a wait).
func end_wait(now_ms: int) -> void:
	if _wait_from >= 0:
		_waited += maxi(now_ms - _wait_from, 0)
		_wait_from = -1


## The logged times for a choice made at `now_ms`: decide_ms, presented_ms, armed_ms,
## presentation_skipped and chute_wait_ms, in that order.
func fields(now_ms: int) -> Dictionary:
	if _shown_at < 0:
		return {
			"decide_ms": 0,
			"presented_ms": 0,
			"armed_ms": 0,
			"presentation_skipped": false,
			"chute_wait_ms": 0,
		}
	return {
		"decide_ms": now_ms - _shown_at,
		"presented_ms": _since_shown(_presented_at, now_ms),
		"armed_ms": _since_shown(_armed_at, now_ms),
		"presentation_skipped": presentation_skipped,
		"chute_wait_ms": _waited,
	}


## From the show to `at_ms`, less the chute wait.
func _since_shown(at_ms: int, now_ms: int) -> int:
	if at_ms < 0 or at_ms > now_ms:
		return NOT_REACHED
	return at_ms - _shown_at - _waited
