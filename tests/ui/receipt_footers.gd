extends RefCounted
## Reads the planning receipt back for the scan popup tests (#75, decision 1A): its printed lines,
## by the slot of the step that printed them, to compare with the belt popups' footers. Load it
## with preload("res://tests/ui/receipt_footers.gd") (no class_name: tests/ is not exported).


## The receipt's printed lines, read back from its labels, each on one row as
## ReceiptView.joined_line puts them: one per step that prints one, then the TOTAL line.
static func printed(receipt: ReceiptView) -> Array[String]:
	var lines: Array[String] = []
	for line: Node in receipt._lines.get_children():
		if line is HBoxContainer:
			lines.append(line_text(line as HBoxContainer))
	return lines


## The steps of `result` that print a receipt line, in order.
static func printing_steps(result: ScoreResult) -> Array[ScoreStep]:
	var names: PackedStringArray = PackedStringArray()
	for slot: int in range(result.payouts.size()):
		# Only whether a step prints a line is read, so any names do.
		names.append("x")
	var steps: Array[ScoreStep] = []
	for step: ScoreStep in result.steps:
		if not ReceiptView.step_text(step, names).is_empty():
			steps.append(step)
	return steps


## The receipt's printed lines by the slot of the step that printed them, leaving out BASE and
## PAYOUT. The caller checks first that printed() has one line per printing step and the TOTAL.
static func by_slot(
	receipt: ReceiptView, result: ScoreResult
) -> Dictionary[int, PackedStringArray]:
	var lines: Array[String] = printed(receipt)
	var steps: Array[ScoreStep] = printing_steps(result)
	var slots: Dictionary[int, PackedStringArray] = {}
	for index: int in range(mini(steps.size(), lines.size())):
		var step: ScoreStep = steps[index]
		if step.step_type in [ScoreStep.StepType.BASE, ScoreStep.StepType.PAYOUT]:
			continue
		if not slots.has(step.slot):
			slots[step.slot] = PackedStringArray()
		slots[step.slot].append(lines[index])
	return slots


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
