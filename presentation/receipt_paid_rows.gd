class_name ReceiptPaidRows
extends RefCounted
## The shift screen's receipt through the count (2026-11-05, ReceiptView.anchored): the paper
## stays where planning left it, at its full length, and planning's rows are paid in place: no
## line is printed, moved or taken away. As the count starts every item's amount waits in muted
## ink (its projected payout); its BASE step and its bonuses then show its amount so far in ink,
## and its PAYOUT step its payout, which the count fades in (the row's amount label is what the
## step returns). The counted row is framed. The foot's PROJECTED becomes TOTAL with the total
## (total()); the dessert's verdict "total€ / quota€" takes its place, green or tomato
## (verdict()), and its margin line is planning's line against the quota under it, reworded
## (margin(): PAID lands on it). Its fizzle and denied marks stay as planning showed them; the
## monitor tells each step. Display only.

## An item's amount before its item is counted.
const WAITING_INK := Palette.MUTED_INK
const PAID_INK := Palette.INK

var _items: Dictionary[int, HBoxContainer] = {}
var _projected: HBoxContainer
var _against: HBoxContainer
## Frames a row (ReceiptView's frame), or none for null.
var _frame: Callable
## Each slot's amount so far (its base plus its bonus and copy amounts, or its override's).
var _sums: Dictionary[int, int] = {}


## Pays `items` (each slot's row) and the foot (`projected`, `against`: none when null) in place,
## framing the counted row through `frame`. Every amount waits in muted ink.
func _init(
	items: Dictionary[int, HBoxContainer],
	projected: HBoxContainer,
	against: HBoxContainer,
	frame: Callable
) -> void:
	_items = items
	_projected = projected
	_against = against
	_frame = frame
	for slot: int in _items:
		if is_instance_valid(_items[slot]):
			ReceiptDecor.relate(_items[slot], "")
			amount_of(slot).add_theme_color_override("font_color", WAITING_INK)
	_frame.call(null)


## Whether `items` are the rows of `count` items (a count can pay them in place).
static func fits(items: Dictionary[int, HBoxContainer], count: int) -> bool:
	if items.size() != count:
		return false
	for slot: int in range(count):
		if not items.has(slot) or not is_instance_valid(items[slot]):
			return false
	return true


## The items' rows (the paid rows: the dessert's lines print under the foot, never over one).
func rows() -> Array[Control]:
	var paid: Array[Control] = []
	for slot: int in _items:
		if is_instance_valid(_items[slot]):
			paid.append(_items[slot])
	return paid


## `slot`'s amount label, or null.
func amount_of(slot: int) -> Label:
	if not _items.has(slot) or not is_instance_valid(_items[slot]):
		return null
	return _items[slot].get_child(1) as Label


## Counts `step` on its row: a BASE, bonus, copy or override shows the item's amount so far, a
## PAYOUT its payout (returning the amount label, which the count fades in); every step frames
## its row and returns it. Null for a step with no row.
func step(counted: ScoreStep) -> Control:
	var amount: Label = amount_of(counted.slot)
	if amount == null:
		return null
	var row: HBoxContainer = _items[counted.slot]
	match counted.step_type:
		ScoreStep.StepType.BASE, ScoreStep.StepType.PAYOUT_OVERRIDE:
			_sums[counted.slot] = counted.value
			_show(amount, counted.value)
		ScoreStep.StepType.FLAT, ScoreStep.StepType.COPY:
			_sums[counted.slot] = _sums.get(counted.slot, 0) + counted.value
			_show(amount, _sums[counted.slot])
		ScoreStep.StepType.PAYOUT:
			_show(amount, counted.value)
			_frame.call(row)
			return amount
	_frame.call(row)
	return row


## The foot's PROJECTED reads `caption` (TOTAL) and `total`, in ink. Returns the line (null with
## no foot).
func total(total_euros: int, caption: String) -> HBoxContainer:
	_frame.call(null)
	if not is_instance_valid(_projected):
		return null
	(_projected.get_child(0) as Label).text = caption
	var amount: Label = _projected.get_child(1) as Label
	amount.text = ReceiptView.money(total_euros)
	amount.add_theme_color_override("font_color", PAID_INK)
	var lines: Control = _projected.get_parent() as Control
	ReceiptDecor.fit_amount(_projected, lines.size.x if lines != null else 0.0)
	return _projected


## The verdict: the TOTAL's amount reads "total€ / quota€" (ReceiptView.verdict_text), as big as
## fits beside its caption, green on a pass, tomato on a miss. Returns it (null with no foot).
func verdict(total_euros: int, quota: int) -> Label:
	if not is_instance_valid(_projected):
		return null
	var amount: Label = _projected.get_child(1) as Label
	amount.text = ReceiptView.verdict_text(total_euros, quota)
	var lines: Control = _projected.get_parent() as Control
	ReceiptDecor.fit_amount(_projected, lines.size.x if lines != null else 0.0)
	var passed: bool = ShiftMargin.of(total_euros, quota).passed()
	amount.add_theme_color_override("font_color", Palette.GOOD if passed else Palette.TOMATO)
	return amount


## The margin line: planning's line against the quota, reworded as the dessert's margin line
## (ReceiptTarget.margin_text, red when short, else green), its right label emptied for PAID.
## Null with no such line.
func margin(shift_margin: ShiftMargin) -> Control:
	if not is_instance_valid(_against):
		return null
	var color: Color = Palette.TOMATO
	if shift_margin.kind() != ShiftMargin.Kind.SHORT:
		color = Palette.GOOD
	var words: Label = _against.get_child(0) as Label
	words.text = ReceiptTarget.margin_text(shift_margin.kind(), shift_margin.amount())
	var right: Label = _against.get_child(1) as Label
	right.text = ""
	for label: Label in [words, right]:
		label.add_theme_color_override("font_color", color)
	return _against


func _show(amount: Label, euros: int) -> void:
	amount.text = ReceiptView.money(euros)
	amount.add_theme_color_override("font_color", PAID_INK)
