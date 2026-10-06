class_name CoinReceipt
extends VBoxContainer
## The coins printed at the bottom of the plain final receipt (full build plan 7.1), on the
## results screen: the shifts passed, the overtime, then the run's coins and the profile's
## total. It only displays a CoinPayout; core computes it.

## Characters per line, so the amounts line up in the monospace receipt font (every line has
## the same font size, or the columns would drift).
const WIDTH := 34
const FONT_SIZE := 16


func _init() -> void:
	add_theme_constant_override("separation", 0)


## `coins_owned` < 0 means the total isn't known (the profile couldn't be saved): "you have ?".
func show_payout(payout: CoinPayout, coins_owned: int) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	var printed: PackedStringArray = lines(payout, coins_owned)
	for index: int in range(printed.size()):
		var last: bool = index == printed.size() - 1
		var line: Label = UiKit.label(printed[index], FONT_SIZE, Palette.INK)
		line.add_theme_font_override("font", ReceiptView.MONO_FONT)
		if last:
			line.add_theme_color_override("font_color", Palette.TEAL)
		add_child(line)


## The receipt's lines: one per payout part, then the total.
static func lines(payout: CoinPayout, coins_owned: int) -> PackedStringArray:
	return PackedStringArray(
		[
			_line("Shifts passed %d" % payout.shifts_passed, "+%d" % payout.shift_coins),
			_line("Overtime €%d" % payout.overtime, "+%d" % payout.overtime_coins),
			_line("COINS +%d" % payout.total(), "you have " + _owned_text(coins_owned)),
		]
	)


## The line's texts (for tests).
func texts() -> PackedStringArray:
	var found: PackedStringArray = PackedStringArray()
	for child: Node in get_children():
		if child is Label and not child.is_queued_for_deletion():
			found.append((child as Label).text)
	return found


static func _owned_text(coins_owned: int) -> String:
	return str(coins_owned) if coins_owned >= 0 else "?"


static func _line(left: String, right: String) -> String:
	return left + " ".repeat(maxi(WIDTH - left.length() - right.length(), 1)) + right
