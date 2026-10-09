class_name SimTimeLimit
extends RefCounted
## The balance simulator's time limit (--max-minutes): the time is shared out between its phases
## (each strategy's runs, then the coupon duel), so a run cut short still plays some of every
## strategy. A phase may use what earlier phases left over. A run or sample under way when its
## phase's time is up still finishes. 0 minutes: no limit.

var _limited: bool = false
var _end_msec: int = 0
var _phases_left: int = 0
var _phase_end_msec: int = 0
var _hit: bool = false


## Starts the clock at `now_msec` for `minutes` (0: no limit), shared out between `phases`.
func _init(minutes: float, phases: int, now_msec: int) -> void:
	_limited = minutes > 0.0
	_end_msec = now_msec + roundi(minutes * 60000.0)
	_phases_left = maxi(phases, 1)
	_phase_end_msec = now_msec


## The next phase begins at `now_msec`: it gets an equal share of the time left.
func begin_phase(now_msec: int) -> void:
	_phase_end_msec = (
		now_msec + floori(float(maxi(_end_msec - now_msec, 0)) / maxi(_phases_left, 1))
	)
	_phases_left = maxi(_phases_left - 1, 0)


## Whether the current phase's time is up at `now_msec` (never without a limit). Once it is, the
## limit counts as hit.
func is_phase_over(now_msec: int) -> bool:
	if not _limited or now_msec < _phase_end_msec:
		return false
	_hit = true
	return true


## When the current phase's time is up, in Time.get_ticks_msec() (0 without a limit): the row
## search stops there (SimRowSearch.stop_at_msec).
func phase_end_msec() -> int:
	return maxi(_phase_end_msec, 1) if _limited else 0


## Counts the limit as hit (a search it stopped).
func hit() -> void:
	_hit = true


## Whether any phase stopped early.
func was_hit() -> bool:
	return _hit
