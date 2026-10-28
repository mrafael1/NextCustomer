class_name LedDisplay
extends Node
## The register's reading (#55; a model since #105 piece 2): the one total the shift shows, which
## the monitor's checkout column (MonitorView, CheckoutColumn) and the top bar's gauge (QuotaMeter)
## both follow through reading_changed, so they read the same whole number at every moment. Blank
## in planning (show_projected is the preview's, the top bar shows it), SUBTOTAL from the checkout
## (the count-up's running total, CountUp) and TOTAL once the verdict is shown (also on a resumed
## checkout). It draws nothing: the LED panel and its count layout went with the single monitor
## screen of #105 piece 2 (mock-up readability_v3.html). Display only: the amounts are the
## caller's (a ScoreResult's total or the count-up's shown total), and nothing here scores.

## Emitted whenever the mode is set (show_projected, start_count, show_total, clear), even to the
## same mode.
signal mode_changed(mode: Mode)
## Each amount shown with its quota (start_count: 0) and whether the quota is met (the count-up's
## ding, or the projected total reaching it), for the top bar's QuotaMeter and the monitor.
signal reading_changed(amount: int, quota: int, met: bool)

enum Mode { BLANK, PROJECTED, SUBTOTAL, TOTAL }

## The quota's player-facing word and amount (#86: "SPEND €73+"); code and data keep "quota".
const QUOTA_WORD := "SPEND"
const QUOTA_AMOUNT := "€%d+"

var _mode: Mode = Mode.BLANK
var _quota: int = 0
var _amount: int = 0
## The quota is met (the count-up's ding, or the projected total reaching it).
var _met: bool = false


func _init() -> void:
	name = "Led"


## The preview's total `projected` against the shift's `shift_quota`, met once it reaches it.
func show_projected(projected: int, shift_quota: int) -> void:
	_quota = shift_quota
	_set_mode(Mode.PROJECTED)
	_met = projected >= shift_quota
	_amount = projected
	reading_changed.emit(projected, shift_quota, _met)


## A count-up starts against `shift_quota`, from 0 and not met. The amounts follow through
## show_subtotal().
func start_count(shift_quota: int) -> void:
	_quota = shift_quota
	_amount = 0
	_met = false
	_set_mode(Mode.SUBTOTAL)
	reading_changed.emit(0, shift_quota, false)


## The running total `shown` (`met`: the count-up has met the quota).
func show_subtotal(shown: int, met: bool) -> void:
	_met = met
	_amount = shown
	reading_changed.emit(shown, _quota, met)


## The verdict is shown: TOTAL over the amount already shown.
func show_total() -> void:
	_set_mode(Mode.TOTAL)


## Not met again (a new row).
func reset_colour() -> void:
	_met = false


## Blank (planning).
func clear() -> void:
	_amount = 0
	_met = false
	_set_mode(Mode.BLANK)


func mode() -> Mode:
	return _mode


## The amount shown now, its quota and whether it is met.
func amount() -> int:
	return _amount


func quota() -> int:
	return _quota


func is_met() -> bool:
	return _met


## Whether the reading is the count-up's (SUBTOTAL or TOTAL).
func is_counting() -> bool:
	return _mode == Mode.SUBTOTAL or _mode == Mode.TOTAL


func _set_mode(mode_set: Mode) -> void:
	_mode = mode_set
	mode_changed.emit(_mode)
