class_name CoinReceipt
extends VBoxContainer
## The coins printed at the bottom of the plain final receipt (full build plan 7.1), on the
## results screen: the shifts passed, the overtime, then the run's coins and the profile's
## total. It only displays a CoinPayout; core computes it. Each coin earned clinks (#62), one
## after another once the results panel has popped in, up to MAX_COIN_SOUNDS.

## Characters per line, so the amounts line up in the monospace receipt font (every line has
## the same font size, or the columns would drift).
const WIDTH := 34
const FONT_SIZE := 16
## The coin sounds start after the panel's pop-in and follow each other this far apart, in
## seconds; a big payout plays at most MAX_COIN_SOUNDS of them.
const COIN_GAP := 0.07
const MAX_COIN_SOUNDS := 15

## The shown payout's coin sounds (#62): the music stays ducked until they have all played.
var coin_sounds_shown: int = 0


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
	coin_sounds_shown = coin_sounds(payout.total())
	_play_coins(payout.total())


## How many coin sounds a payout of `coins` plays.
static func coin_sounds(coins: int) -> int:
	return clampi(coins, 0, MAX_COIN_SOUNDS)


## Seconds from the payout shown until one COIN_GAP after its last coin sound.
func coins_seconds() -> float:
	return UiKit.POP_IN_SECONDS + coin_sounds_shown * COIN_GAP


## One `coin` per coin earned (capped), in turn after the pop-in; nothing without an Sfx.
func _play_coins(coins: int) -> void:
	var sfx: Sfx = Sfx.find(self)
	if sfx != null:
		sfx.play_series("coin", coin_sounds(coins), COIN_GAP, UiKit.POP_IN_SECONDS)


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
