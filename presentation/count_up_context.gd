class_name CountUpContext
extends RefCounted
## What a count-up knows about the run besides the row (#60, D3): the shift, the best checkout
## so far, the player's speed setting, reduced motion, and the receipt's header (#75). The quota
## is never part of it, so a different quota can never change the count-up's intensity.

## The shift being checked out, 1-based.
var shift: int = 1
## The best checkout total of the run's EARLIER shifts (never the current one), 0 if none.
## CountUpPlan raises it to the tuning's first_best_floor.
var best_so_far: int = 0
## The player's count-up speed setting (ProfileState.settings "count_up_speed"): 1.0 or 1.5.
var speed_setting: float = 1.0
## Reduced motion (ProfileState.settings "reduced_motion"): no shakes or rattles.
var reduced_motion: bool = false
## The receipt's header lines (#75, ReceiptView.header_lines), printed at once when the count-up
## starts (ReceiptView.begin), so its lines print under the planning stub's header. None by
## default.
var receipt_header: PackedStringArray = PackedStringArray()
## A BONUS visit follows this shift's TICKET visit (#77 machine v2; since 2026-11-06 the receipt
## prints no stub for it: the machine's draw lamps count the draws). The shift screen sets it after
## the checkout.
var bonus_ticket: bool = false
## The shift was a payday (v0.68, Payday): its two draws are PREMIUM, read as one reward. The
## shift screen sets it after the checkout.
var payday: bool = false
## A missed quota the run goes on after (v0.68's training week): the slip's stamp ("SLIP 1/2"),
## else empty (a pass, or the miss that ends the run). The shift screen sets it after the
## checkout.
var write_up: String = ""
## The names of the shift's boon day events (v0.69): their steps' lines name them, but a boon is
## never an inspection, so the dessert's INSPECTION PASSED leaves them out. The shift screen sets
## it.
var boon_names: PackedStringArray = PackedStringArray()
## A Double checkout shift (#122, DoubleCheckoutFlow.dress): row 1's count stops after its last
## item (`more_rows`: no total, no verdict, no dessert); row 2's counts on from row 1's total
## (`start_total`, its steps' subtotals already past it: ScoreResult.continued).
var more_rows: bool = false
var start_total: int = 0
## The over-quota rewards (v1.03, OvertimeTickets): what the shift's checkout made of the extra
## ticket and of the PREMIUM transform (OvertimeTickets.State: NONE, EARNED, USED) and the laps
## each needs, for the week medals' flights and the receipt's silver and gold (ReceiptGoldFlow).
## The dessert prints no stub for any extra draw since 2026-11-06 (the receipt feeds the machine
## once). The shift screen sets them after the checkout (OvertimeCue.dress).
var overtime_ticket: int = 0
var overtime_premium: int = 0
var overtime_ticket_laps: int = 0
var overtime_premium_laps: int = 0


func _init(
	shift_number: int = 1,
	best: int = 0,
	speed: float = 1.0,
	reduce_motion: bool = false,
	header: PackedStringArray = PackedStringArray()
) -> void:
	shift = shift_number
	best_so_far = best
	speed_setting = speed
	reduced_motion = reduce_motion
	receipt_header = header


## The best total of every shift record but the last (the shift being counted), 0 for none.
static func best_earlier_total(history: Array[ShiftRecord]) -> int:
	var best: int = 0
	for index: int in range(history.size() - 1):
		best = maxi(best, history[index].total)
	return best
