class_name FinalReceipt
extends RefCounted
## The run's final receipt (#61; full build plan 6.2 and 7.1): its lines, top to bottom, that
## the results screen prints one by one. The headline ("RUN WON!" or "RUN OVER"), a rule, one
## line per played shift (its number, total against quota, pass or fail) with a dim line per
## RECEIPT REWARDS visit after it (#77: "NEW ITEMS: Milk", "BONUS · UPGRADE: Eggs › GOLDEN",
## "UPGRADE: Coupon engine LV 2", "binned NEW ITEMS") and one for the inspection it was played
## under, the shortfall on a lost run, a rule, then the coins: the shifts passed, the run's
## coins and the profile's total ("you have ?" when the profile couldn't be saved). It only lays
## out text; core computes the payout and the margin. A missed shift the run went on
## after reads "slip" (v0.68's training week; "write-up" in v0.65), the miss that ended it "fail".
## A payday's second visit (v0.68) reads "PREMIUM · ", any other BONUS visit "BONUS · ", an
## over-quota extra ticket (v1.03) "OVERTIME · ". The
## compact receipt (when the full one can't fit the screen) folds each shift's inspection line
## into its shift line ("inspected", or "review" for a Manager's review).
##
## A run that reached its second week (v0.96's 16 shifts in 4 weeks) prints in week columns
## (`columns`, uses_columns): each week opens with a header ("WEEK 3 · HOLIDAY", the week event's
## chip name) and its shift and dim lines carry their week (Line.week), so the results screen
## sets the first half of the weeks it reached in a left column (left_weeks: weeks 1-2 of 3 or
## 4, week 1 of 2) and the rest in a right one; the shortfall
## closes the last week's column, and the rules and the coin lines span both (WIDE_WIDTH).

enum Tone { HEADLINE, RULE, SHIFT, DETAIL, SHORTFALL, COINS, COINS_TOTAL, WEEK }

## Characters per shift and coin line, so the columns line up in the monospace receipt font.
const WIDTH := 44
## The gap between two week columns, in characters, and a full-width line's width across both.
const COLUMN_GAP := 4
const WIDE_WIDTH := 2 * WIDTH + COLUMN_GAP
## A week's header: its number and its week event's chip name ("WEEK 1 · TRAINING"), or the
## number alone.
const WEEK_HEADER := "WEEK %d · %s"
const WEEK_HEADER_PLAIN := "WEEK %d"
## The coin sounds follow each other this far apart, in seconds; a big payout plays at most
## MAX_COIN_SOUNDS of them (#62).
const COIN_GAP := 0.07
const MAX_COIN_SOUNDS := 15
## The machine's chutes as the receipt names them (RewardMachine.Chute order).
const CHUTE_WORDS: Array[String] = ChuteKey.NAMES
## A shift's dim lines start this far in.
const DETAIL_INDENT := "     "


## One printed line: its text, how it is shown, whether its shift failed (red), and its 1-based
## week in a receipt in week columns (0: across the receipt, or a receipt in one column).
class Line:
	extends RefCounted
	var text: String
	var tone: FinalReceipt.Tone
	var failed: bool
	var week: int

	func _init(
		line_text: String,
		line_tone: FinalReceipt.Tone,
		line_failed: bool = false,
		line_week: int = 0
	) -> void:
		text = line_text
		tone = line_tone
		failed = line_failed
		week = line_week


## Whether `run`'s receipt prints in week columns: it played a shift of its second week or later.
static func uses_columns(run: RunState) -> bool:
	return left_weeks(run) > 0


## How many of the weeks `run` reached go in the left column (the first half, rounded up); 0 for
## a receipt in one column (a run that ended in its first week).
static func left_weeks(run: RunState) -> int:
	if run.history.is_empty():
		return 0
	var reached: int = WeekSchedule.week_of(run.balance, run.history[-1].shift) + 1
	return ceili(reached / 2.0) if reached >= 2 else 0


## The receipt of an ended run: `result` is its last checkout, `coins_owned` the profile's coins
## after the run (< 0 when unknown). `columns`: in week columns (uses_columns).
static func lines(
	run: RunState,
	result: ScoreResult,
	coins_owned: int,
	compact: bool = false,
	columns: bool = false
) -> Array[Line]:
	var won: bool = run.phase == RunState.Phase.WON
	var width: int = WIDE_WIDTH if columns else WIDTH
	var printed: Array[Line] = [Line.new("RUN WON!" if won else "RUN OVER", Tone.HEADLINE)]
	printed.append(Line.new(rule(width), Tone.RULE))
	var week: int = 0
	for record: ShiftRecord in run.history:
		var fatal: bool = not won and record == run.history[-1]
		var texts: PackedStringArray = shift_texts(record, compact, not fatal)
		if columns and WeekSchedule.week_of(run.balance, record.shift) + 1 != week:
			week = WeekSchedule.week_of(run.balance, record.shift) + 1
			printed.append(Line.new(week_header(run.balance, record.shift), Tone.WEEK, false, week))
		var in_week: int = week if columns else 0
		printed.append(Line.new(texts[0], Tone.SHIFT, not record.passed, in_week))
		for detail: String in texts.slice(1):
			printed.append(Line.new(detail, Tone.DETAIL, not record.passed, in_week))
	if not won:
		var margin: ShiftMargin = ShiftMargin.of(result.total, run.quota())
		var shortfall: String = (
			"Shift %d / %d: short by %d€"
			% [run.shift_index + 1, run.shift_count(), margin.amount()]
		)
		# In week columns it closes its week's column, under the shift that ended the run.
		printed.append(Line.new(shortfall, Tone.SHORTFALL, true, week if columns else 0))
	printed.append(Line.new(rule(width), Tone.RULE))
	var coins: PackedStringArray = coin_lines(CoinPayout.for_run(run), coins_owned, width)
	for index: int in range(coins.size()):
		var last: bool = index == coins.size() - 1
		printed.append(Line.new(coins[index], Tone.COINS_TOTAL if last else Tone.COINS))
	return printed


## A shift's line ("  4  30€ / 22€        pass") and its dim lines: one per machine visit
## after it (visit_text), then the inspections it was played under. A miss reads "slip" when the
## run went on after it (`went_on`; v0.65's "write-up"). `compact` folds the inspections into the
## shift line ("  4  30€ / 22€        pass  review").
static func shift_texts(
	record: ShiftRecord, compact: bool = false, went_on: bool = false
) -> PackedStringArray:
	var main: String = (
		"%3d  %-13s  %s"
		% [record.shift, "%d€ / %d€" % [record.total, record.quota], _result(record, went_on)]
	)
	var maluses: Array[InspectionDefinition] = InspectionDefinition.maluses(record.inspections)
	if compact and not maluses.is_empty():
		main = "%-28s  %s" % [main, "review" if maluses.size() > 1 else "inspected"]
	var texts: PackedStringArray = PackedStringArray([main])
	for visit: MachineVisit in record.visits:
		texts.append(DETAIL_INDENT + visit_text(visit))
	if not compact and not maluses.is_empty():
		texts.append(DETAIL_INDENT + "inspection " + ", ".join(InspectionTag.names(maluses)))
	# A boon day's event (v0.69), as its chip named it.
	var boons: Array[InspectionDefinition] = InspectionDefinition.boons(record.inspections)
	if not compact and not boons.is_empty():
		texts.append(DETAIL_INDENT + "today " + ", ".join(InspectionTag.names(boons)))
	return texts


## One machine visit, as the final receipt words it: the kind ("BONUS · "), the chute and what it
## gave ("NEW ITEMS: Milk", "UPGRADE: Eggs › GOLDEN", "UPGRADE: SHELF Milk ×3", "UPGRADE: Coupon
## engine LV 2"), or "binned NEW ITEMS".
static func visit_text(visit: MachineVisit) -> String:
	var chute: String = CHUTE_WORDS[visit.chute] if visit.chute >= 0 else "?"
	var prefix: String = ""
	if visit.kind == MachineVisit.Kind.BONUS:
		prefix = "PREMIUM · " if visit.premium else "BONUS · "
	elif visit.kind == MachineVisit.Kind.OVERTIME:
		prefix = "OVERTIME · "
	if visit.binned:
		return prefix + "binned " + chute
	var prize: MachinePrize = visit.picked_prize()
	var given: String = "—"
	if prize != null and prize.kind == MachinePrize.Kind.REGISTER:
		given = LoyaltyCard.perk_name(prize.upgrade)
	elif prize != null and prize.kind == MachinePrize.Kind.UPGRADE:
		given = _upgrade_text(prize, visit.upgraded.size())
	elif prize != null:
		given = prize.card.display_name
	return "%s%s: %s" % [prefix, chute, given]


## The coins at the bottom: one line per payout part, then the total, `width` characters each.
static func coin_lines(
	payout: CoinPayout, coins_owned: int, width: int = WIDTH
) -> PackedStringArray:
	return PackedStringArray(
		[
			_line("Shifts passed %d" % payout.shifts_passed, "+%d" % payout.shift_coins, width),
			_line("COINS +%d" % payout.total(), "you have " + _owned_text(coins_owned), width),
		]
	)


## The header of the week holding the 1-based `shift_number` ("WEEK 3 · HOLIDAY").
static func week_header(balance: BalanceDefinition, shift_number: int) -> String:
	var week: int = WeekSchedule.week_of(balance, shift_number) + 1
	var event: WeekEventDefinition = WeekSchedule.event_for(balance, shift_number)
	if event == null or event.chip_text.is_empty():
		return WEEK_HEADER_PLAIN % week
	return WEEK_HEADER % [week, event.chip_text]


## How many coin sounds a payout of `coins` plays.
static func coin_sounds(coins: int) -> int:
	return clampi(coins, 0, MAX_COIN_SOUNDS)


## An UPGRADES prize's line: one step, straight to GOLDEN, or every copy (SHELF).
static func _upgrade_text(prize: MachinePrize, copies: int) -> String:
	match prize.rarity:
		MachinePrize.Rarity.RARE:
			return "%s › GOLDEN" % prize.card.display_name
		MachinePrize.Rarity.LEGENDARY:
			return "SHELF %s ×%d" % [prize.card.display_name, copies]
	return "%s +1 step" % prize.card.display_name


## A dashed rule across the receipt, `width` characters.
static func rule(width: int = WIDTH) -> String:
	return "-".repeat(width)


static func _result(record: ShiftRecord, went_on: bool) -> String:
	if record.passed:
		return "pass"
	return "slip" if went_on else "fail"


static func _owned_text(coins_owned: int) -> String:
	return str(coins_owned) if coins_owned >= 0 else "?"


static func _line(left: String, right: String, width: int = WIDTH) -> String:
	return left + " ".repeat(maxi(width - left.length() - right.length(), 1)) + right
