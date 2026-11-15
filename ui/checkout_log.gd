class_name CheckoutLog
extends RefCounted
## The `checkout` event's fields (plan section 8), built at the click from the run just checked
## out: the shift, the committed order, the score against the quota, the next inspections, the
## write-ups, the checkout tracker's measures, the over-quota rewards (v1.03) and the BEST line's
## item (v1.37).


## The fields for `committed` (the row as it was checked out) scored `result`, with `tracker`'s
## measures.
static func event(
	run: RunState, committed: Array[CardInstance], result: ScoreResult, tracker: CheckoutTracker
) -> Dictionary:
	var checkout_data: Dictionary = {
		"shift": run.shift_index + 1,
		"final_order": RunEvents.card_ids(run.first_row + committed),
		"score": result.total,
		"quota": run.quota(),
		"passed": run.passed(),
		"next_inspection": RunEvents.first_inspection_id(run.next_inspections),
		"next_inspections": RunEvents.inspection_ids(run.next_inspections),
		"write_ups": run.write_ups,
	}
	checkout_data.merge(tracker.measures(committed.size()))
	checkout_data.merge(OvertimeCue.checkout_fields(run))  # v1.03: the over-quota rewards.
	checkout_data.merge(RunEvents.best_fields(run))  # v1.37: the BEST line's item.
	return checkout_data
