class_name RunHistoryView
extends GridContainer
## The run history on the results screen (plan section 3.8): one plain row per played shift
## with its total against the quota, pass or fail, the card picked, the upgrade taken and the
## inspection it was played under (plan section 3.9).

const HEADERS := ["Shift", "Total / Quota", "Result", "Card", "Upgrade", "Inspection"]


func _init() -> void:
	columns = HEADERS.size()
	add_theme_constant_override("h_separation", 22)
	add_theme_constant_override("v_separation", 2)


func show_history(history: Array[ShiftRecord]) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	for header: String in HEADERS:
		_cell(header, Palette.MUTED_INK)
	for record: ShiftRecord in history:
		for text: String in row_texts(record):
			_cell(text, Palette.INK if record.passed else Palette.TOMATO)


## One record's cells, in HEADERS order.
static func row_texts(record: ShiftRecord) -> PackedStringArray:
	var card: String = "—"
	if record.card_picked != null:
		card = record.card_picked.display_name
	elif record.reward_skipped:
		card = "skipped"
	var upgrade: String = record.upgrade_taken.display_name if record.upgrade_taken != null else "—"
	var inspection: String = record.inspection.display_name if record.inspection != null else "—"
	return PackedStringArray(
		[
			str(record.shift),
			"€%d / €%d" % [record.total, record.quota],
			"pass" if record.passed else "fail",
			card,
			upgrade,
			inspection,
		]
	)


## The rows' text, header first (for tests).
func cell_texts() -> PackedStringArray:
	var texts: PackedStringArray = PackedStringArray()
	for child: Node in get_children():
		if child is Label and not child.is_queued_for_deletion():
			texts.append((child as Label).text)
	return texts


func _cell(text: String, color: Color) -> void:
	add_child(UiKit.label(text, 15, color))
