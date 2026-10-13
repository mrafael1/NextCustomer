class_name FinalReceipt
extends RefCounted
## The run's final receipt (#61; full build plan 6.2 and 7.1): its lines, top to bottom, that
## the results screen prints one by one. The headline ("RUN WON!" or "RUN OVER"), a rule, one
## line per played shift (its number, total against quota, pass or fail and the card picked)
## with the upgrade taken and the inspection played under on a dim second line, the shortfall on
## a lost run, a rule, then the coins: the shifts passed, the overtime, the run's coins and the
## profile's total ("you have ?" when the profile couldn't be saved). It only lays out text;
## core computes the payout and the margin.

enum Tone { HEADLINE, RULE, SHIFT, DETAIL, SHORTFALL, COINS, COINS_TOTAL }

## Characters per shift and coin line, so the columns line up in the monospace receipt font.
const WIDTH := 44
## The coin sounds follow each other this far apart, in seconds; a big payout plays at most
## MAX_COIN_SOUNDS of them (#62).
const COIN_GAP := 0.07
const MAX_COIN_SOUNDS := 15


## One printed line: its text, how it is shown, and whether its shift failed (red).
class Line:
	extends RefCounted
	var text: String
	var tone: FinalReceipt.Tone
	var failed: bool

	func _init(line_text: String, line_tone: FinalReceipt.Tone, line_failed: bool = false) -> void:
		text = line_text
		tone = line_tone
		failed = line_failed


## The receipt of an ended run: `result` is its last checkout, `coins_owned` the profile's coins
## after the run (< 0 when unknown).
static func lines(run: RunState, result: ScoreResult, coins_owned: int) -> Array[Line]:
	var won: bool = run.phase == RunState.Phase.WON
	var printed: Array[Line] = [Line.new("RUN WON!" if won else "RUN OVER", Tone.HEADLINE)]
	printed.append(Line.new(rule(), Tone.RULE))
	for record: ShiftRecord in run.history:
		var texts: PackedStringArray = shift_texts(record)
		printed.append(Line.new(texts[0], Tone.SHIFT, not record.passed))
		if not texts[1].is_empty():
			printed.append(Line.new(texts[1], Tone.DETAIL, not record.passed))
	if not won:
		var margin: ShiftMargin = ShiftMargin.of(result.total, run.quota())
		var shortfall: String = (
			"Shift %d / %d: short by €%d"
			% [run.shift_index + 1, run.shift_count(), margin.amount()]
		)
		printed.append(Line.new(shortfall, Tone.SHORTFALL, true))
	printed.append(Line.new(rule(), Tone.RULE))
	var coins: PackedStringArray = coin_lines(CoinPayout.for_run(run), coins_owned)
	for index: int in range(coins.size()):
		var last: bool = index == coins.size() - 1
		printed.append(Line.new(coins[index], Tone.COINS_TOTAL if last else Tone.COINS))
	return printed


## A shift's line ("  4  €30 / €22        pass  Bread") and its dim second line (the upgrade
## taken and the inspection, or "" without either).
static func shift_texts(record: ShiftRecord) -> PackedStringArray:
	var card: String = "—"
	if record.card_picked != null:
		card = record.card_picked.display_name
	elif record.reward_skipped:
		card = "skipped"
	var main: String = (
		"%3d  %-13s  %-4s  %s"
		% [record.shift, "€%d / €%d" % [record.total, record.quota], _result(record), card]
	)
	var details: PackedStringArray = PackedStringArray()
	if record.upgrade_taken != null:
		details.append("upgrade " + record.upgrade_taken.display_name)
	if record.inspection != null:
		details.append("inspection " + record.inspection.display_name)
	var detail: String = "" if details.is_empty() else " ".repeat(5) + " · ".join(details)
	return PackedStringArray([main, detail])


## The coins at the bottom: one line per payout part, then the total, WIDTH characters each.
static func coin_lines(payout: CoinPayout, coins_owned: int) -> PackedStringArray:
	return PackedStringArray(
		[
			_line("Shifts passed %d" % payout.shifts_passed, "+%d" % payout.shift_coins),
			_line("Overtime €%d" % payout.overtime, "+%d" % payout.overtime_coins),
			_line("COINS +%d" % payout.total(), "you have " + _owned_text(coins_owned)),
		]
	)


## How many coin sounds a payout of `coins` plays.
static func coin_sounds(coins: int) -> int:
	return clampi(coins, 0, MAX_COIN_SOUNDS)


## A dashed rule across the receipt.
static func rule() -> String:
	return "-".repeat(WIDTH)


static func _result(record: ShiftRecord) -> String:
	return "pass" if record.passed else "fail"


static func _owned_text(coins_owned: int) -> String:
	return str(coins_owned) if coins_owned >= 0 else "?"


static func _line(left: String, right: String) -> String:
	return left + " ".repeat(maxi(WIDTH - left.length() - right.length(), 1)) + right
