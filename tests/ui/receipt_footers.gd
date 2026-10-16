extends RefCounted
## Reads a row's itemised receipt back for the scan tests (#75, #80): its printed lines, and by
## the item each step printed under, the lines that item's scan should list (in the monitor's
## words), to compare with the belt items' scan footers. Load it
## with preload("res://tests/ui/receipt_footers.gd") (no class_name: tests/ is not exported).


## The receipt's printed lines, read back from its labels, each on one row as
## ReceiptView.joined_line puts them: one per item, one per other step that prints one, then
## the TOTAL line.
static func printed(receipt: ReceiptView) -> Array[String]:
	var lines: Array[String] = []
	for line: Node in receipt._lines.get_children():
		if line is HBoxContainer:
			lines.append(line_text(line as HBoxContainer))
	return lines


## The steps of `result` that print a receipt line, in order: each item's BASE (its item's line,
## which its PAYOUT fills in too) and every other step that prints a line of its own.
static func printing_steps(result: ScoreResult) -> Array[ScoreStep]:
	var names: PackedStringArray = PackedStringArray()
	for slot: int in range(result.payouts.size()):
		# Only whether a step prints a line is read, so any names do.
		names.append("x")
	var steps: Array[ScoreStep] = []
	for step: ScoreStep in result.steps:
		if step.step_type == ScoreStep.StepType.PAYOUT:
			continue
		if not ReceiptView.step_text(step, names).is_empty():
			steps.append(step)
	return steps


## What each belt item's scan should list (#80), by slot: ReceiptView.step_line of every step
## the receipt printed under that item (leaving out BASE and PAYOUT, which fill the item's line
## in), in receipt order. A step whose line is not printed under its item (wrong item, wrong
## words) is left out, so the scans' footers then hold fewer lines than the steps. The caller
## checks first that printed() has one line per printing step and the TOTAL.
static func by_slot(
	receipt: ReceiptView,
	result: ScoreResult,
	names: PackedStringArray,
	upgrade_names: PackedStringArray = PackedStringArray(),
	inspection_names: PackedStringArray = PackedStringArray()
) -> Dictionary[int, PackedStringArray]:
	var groups: Dictionary[int, Array] = _groups(receipt)
	var used: Dictionary[int, int] = {}
	var slots: Dictionary[int, PackedStringArray] = {}
	for step: ScoreStep in result.steps:
		if step.step_type in [ScoreStep.StepType.BASE, ScoreStep.StepType.PAYOUT]:
			continue
		var text: PackedStringArray = ReceiptView.step_text(
			step, names, upgrade_names, inspection_names
		)
		if text.is_empty():
			continue
		var group: Array = groups.get(step.slot, [])
		var at: int = used.get(step.slot, 0)
		var printed_as: String = "%s|%s" % [ReceiptView.hang_parts(text[0])[2], text[1]]
		if at >= group.size() or group[at] != printed_as:
			continue
		used[step.slot] = at + 1
		if not slots.has(step.slot):
			slots[step.slot] = PackedStringArray()
		slots[step.slot].append(ReceiptView.step_line(step, names, upgrade_names, inspection_names))
	return slots


## The receipt's step lines under each item's line ("left|right", the left label's text without
## its hung lead and marker), by slot, up to the TOTAL line.
static func _groups(receipt: ReceiptView) -> Dictionary[int, Array]:
	var groups: Dictionary[int, Array] = {}
	var slot: int = -1
	for line: Node in receipt._lines.get_children():
		if line == receipt._total_line:
			break
		if not line is HBoxContainer:
			continue
		var item: int = receipt._items.find_key(line) if receipt._items.values().has(line) else -1
		if item >= 0:
			slot = item
			groups[slot] = []
			continue
		if slot >= 0:
			var left: Label = line.get_child(0) as Label
			groups[slot].append("%s|%s" % [left.text, (line.get_child(1) as Label).text])
	return groups


## A receipt line's text on one row: its marker (if hung) and left text, then its right side.
static func line_text(line: HBoxContainer) -> String:
	var left: Label = line.get_child(0) as Label
	var right: Label = line.get_child(1) as Label
	var marker: Label = left.get_node_or_null("Marker") as Label
	var text: String = left.text if marker == null else "%s %s" % [marker.text, left.text]
	return ReceiptView.joined_line(text, right.text)


## Where the popups' `footers` differ from the receipt's `expected` lines, slot by slot, and
## whether they hold as many lines in all; none when they match. `message` names the row.
static func failures(
	expected: Dictionary[int, PackedStringArray],
	footers: Dictionary[int, PackedStringArray],
	message: String
) -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	var lines: int = 0
	for slot: int in footers:
		var want: PackedStringArray = expected.get(slot, PackedStringArray())
		lines += want.size()
		if footers[slot] != want:
			found.append("%s slot %d: %s != %s" % [message, slot, footers[slot], want])
	var receipt_lines: int = 0
	for slot: int in expected:
		receipt_lines += expected[slot].size()
	if lines != receipt_lines:
		found.append(
			"%s: the popups hold %d lines, the receipt %d" % [message, lines, receipt_lines]
		)
	return found
