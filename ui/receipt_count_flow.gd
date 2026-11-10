class_name ReceiptCountFlow
extends Node
## The shift screen's receipt following the count (main scene v2, H2 of 2026-11-08: mock-up
## docs/art/mockups/main_scene_v2.html). Decor like the quota crossing (QuotaCrossing): it only
## reflects what the count-up already plays (#60, #86: its beats, ticks and sounds stay as they
## are). The LED's reading (reading_changed, the number the monitor and the gauge show) moves the
## receipt's hero and the rolling row's amount (ReceiptView.show_running), so the printed rows add
## up to the TOTAL on every tick. At the quota crossing (the count-up's quota_met, the very moment
## #120's dip, flash, streak and ka-ching play, the register holds and the crowd cheers) the
## header's target turns green with its check and BEATEN! slams on; a met quota with no pop (a
## resume, a Double checkout's row 2 carried over row 1's crossing) shows it settled. Planning
## never shows it.

var _count_up: CountUp
var _receipt: ReceiptView


## Follows `count_up`'s counts and `led`'s reading for `receipt`.
func _init(count_up: CountUp, led: LedDisplay, receipt: ReceiptView) -> void:
	name = "ReceiptCountFlow"
	_count_up = count_up
	_receipt = receipt
	count_up.count_started.connect(func(_views: Array[CardView]) -> void: _begin())
	count_up.quota_met.connect(_on_met)
	led.reading_changed.connect(_on_reading)


func _begin() -> void:
	_receipt.reduced_motion = _still()


func _on_reading(amount: int, _quota: int, _met: bool) -> void:
	_receipt.show_running(amount)


func _on_met(pop: bool) -> void:
	_receipt.target.show_met(pop, _still())


func _still() -> bool:
	return _count_up.plan != null and _count_up.plan.reduced_motion
