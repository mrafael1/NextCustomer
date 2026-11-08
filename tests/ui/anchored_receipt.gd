extends RefCounted
## The shift screen's receipt as an expected copy (2026-11-05, ReceiptView.anchored): planning's
## rows for `result`, as the screen showed them, which the count then pays in place. A suite
## builds its expected receipt with plan() and then show_result() and show_shift_end(), as the
## screen does. Load it with preload("res://tests/ui/anchored_receipt.gd") (no class_name: tests/
## is not exported).


## Shows planning's rows of `screen`'s run for `result` on `expected`, anchored at full length.
static func plan(expected: ReceiptView, screen: ShiftScreen, result: ScoreResult) -> void:
	expected.anchored = true
	expected.full_length = true
	expected.show_planning(
		screen.receipt_header(),
		result,
		CardInstance.names(screen.run.row),
		screen._receipt.planned_slots,
		screen.run.quota(),
		ReceiptInk.cards_of(screen.run.row)
	)
