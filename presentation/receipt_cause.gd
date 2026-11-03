class_name ReceiptCause
extends RefCounted
## Who caused a score step, in the receipt's words (ReceiptView.source_text and its multiplier
## lines). Display only.


## A multiplier's cause as ReceiptView.source_text names it, less the factor its receipt text ends
## in ("Multipack ×3" is "Multipack"): its line prints the factor itself ("×3 Multipack").
static func multiplier(
	step: ScoreStep,
	upgrade_names: PackedStringArray,
	inspection_names: PackedStringArray = PackedStringArray()
) -> String:
	var text: String = step.text
	var at: int = text.rfind(ReceiptView.FACTOR_MARK)
	if at > 0 and text.substr(at + ReceiptView.FACTOR_MARK.length()).is_valid_int():
		text = text.substr(0, at)
	return of(step, text, upgrade_names, inspection_names)


## `step`'s cause with `text` as its rule's receipt text: an upgrade's line always names the
## upgrade (plan section 3.8), with its rule's text after it when that text is something else; an
## inspection's line starts with the inspection's name (plan section 3.9).
static func of(
	step: ScoreStep,
	text: String,
	upgrade_names: PackedStringArray,
	inspection_names: PackedStringArray
) -> String:
	match step.source_kind:
		ScoreStep.SourceKind.UPGRADE:
			if step.source_index < 0 or step.source_index >= upgrade_names.size():
				return text
			var upgrade_name: String = upgrade_names[step.source_index]
			if text.is_empty() or text == upgrade_name:
				return upgrade_name
			return "%s (%s)" % [text, upgrade_name]
		ScoreStep.SourceKind.INSPECTION:
			if step.source_index < 0 or step.source_index >= inspection_names.size():
				return text
			var inspection_name: String = inspection_names[step.source_index]
			if text.is_empty() or text == inspection_name:
				return inspection_name
			return "%s: %s" % [inspection_name, text]
	return text
