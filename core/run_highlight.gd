class_name RunHighlight
extends RefCounted
## The run's best moment, printed as the final receipt's BEST line (v1.37, the approved direction
## A of docs/art/mockups/receipt_highlight.html: "Biggest payout · Golden Milk · 264€"). Pure: it
## reads the run history (ShiftRecord, filled at each checkout by record_best) and the bars in a
## HighlightDefinition, and never uses randomness, so the same run always prints the same line.
##
## Each kind finds its best case in the run (moments): Biggest payout (one item's payout), Over
## quota (a passed shift's total against its quota), Longest combo (a CHAIN, BATCH or MORNING),
## First GOLDEN (the first GOLDEN card checked out) and Closest call (the smallest margin a shift
## passed by). A moment's score is its value against its kind's bar; the highest score in the
## definition's kind_order wins, the kind listed first on equal scores. When no kind reaches its
## bar (score under 1), Biggest payout prints anyway (the fallback), so every run that paid for an
## item gets a line, a lost one too. Within a kind the bigger value wins, then the later shift,
## then (within a shift, at record_best) the earlier slot. A Day off shift has no checkout and is
## skipped. A record saved before v1.37 has no payout or combo: those kinds miss its shift, and a
## run with no moment at its bar and no payout recorded gets no line.

enum Kind { BIGGEST_PAYOUT, OVER_QUOTA, LONGEST_COMBO, FIRST_GOLDEN, CLOSEST_CALL }

## The kinds' ids (Kind order), as HighlightDefinition.kind_order and the log name them.
const KIND_IDS: Array[String] = [
	"biggest_payout", "over_quota", "longest_combo", "first_golden", "closest_call"
]
## Scores this close are equal.
const EPSILON := 1e-9
## A combo is at least this long (a lone batch item is no combo).
const MIN_COMBO := 2
## The combos' keywords, as a record keeps them.
const COMBO_WORDS: Array[String] = [CardText.CHAIN_WORD, CardText.BATCH_WORD, CardText.MORNING_WORD]
## The line's parts are joined with this.
const JOIN := " · "
## A Closest call that misses its bar scores this share of its bar over its margin, so it stays
## under 1.
const CLOSE_MISS_FACTOR := 0.5


## One kind's best case in the run.
class Moment:
	extends RefCounted
	var kind: RunHighlight.Kind
	## The 1-based shift it happened on.
	var shift: int = 0
	## The item (Biggest payout, First GOLDEN), else null.
	var card: CardDefinition
	## Biggest payout: the item's payout; Longest combo: what the combo paid; else 0.
	var amount: int = 0
	## The shift's total and quota.
	var total: int = 0
	var quota: int = 0
	## Longest combo: its keyword (CardText.CHAIN_WORD, BATCH_WORD, MORNING_WORD) and length.
	var keyword: String = ""
	var length: int = 0
	## Its value against its kind's bar (1: at the bar).
	var score: float = 0.0
	## Printed as the fallback (no kind reached its bar).
	var fallback: bool = false

	func kind_id() -> String:
		return RunHighlight.KIND_IDS[kind]


## Fills `record`'s best_payout, best_card and best_combo from its checkout's `result` (a Double
## checkout's joined result covers both rows; `record.played` is in the result's slot order).
## The biggest single payout (the earlier slot on a tie; a SHELF's copies each pay on their own
## slot) and the longest CHAIN, BATCH or MORNING (then the bigger pay, then CHAIN before BATCH
## before MORNING, then the earlier start). Nothing for a payout of 0 or less, or no combo.
static func record_best(record: ShiftRecord, result: ScoreResult) -> void:
	record.best_payout = 0
	record.best_card = null
	record.best_combo_keyword = ""
	record.best_combo_length = 0
	record.best_combo_pay = 0
	if result == null or record.day_off:
		return
	var slots: int = mini(result.payouts.size(), record.played.size())
	for slot: int in range(slots):
		if result.payouts[slot] > record.best_payout:
			record.best_payout = result.payouts[slot]
			record.best_card = record.played[slot]
	var combos: Array[Array] = []
	for chain: PackedInt32Array in result.chains:
		combos.append([CardText.CHAIN_WORD, chain])
	for batch: PackedInt32Array in result.batches:
		combos.append([CardText.BATCH_WORD, batch])
	if not result.mornings.is_empty():
		combos.append([CardText.MORNING_WORD, result.mornings])
	for combo: Array in combos:
		var members: PackedInt32Array = combo[1]
		if members.size() < MIN_COMBO:
			continue
		var pay: int = 0
		for slot: int in members:
			if slot >= 0 and slot < result.payouts.size():
				pay += result.payouts[slot]
		var longer: bool = members.size() > record.best_combo_length
		var same: bool = members.size() == record.best_combo_length
		if longer or (same and pay > record.best_combo_pay):
			record.best_combo_keyword = combo[0]
			record.best_combo_length = members.size()
			record.best_combo_pay = pay


## The run's highlight: the best moment by `definition`'s bars and kind order, Biggest payout as
## the fallback, or null (no definition, or no moment at its bar and no payout recorded).
static func pick(history: Array[ShiftRecord], definition: HighlightDefinition) -> Moment:
	if definition == null:
		return null
	var found: Array[Moment] = moments(history, definition)
	var best: Moment = null
	var best_rank: int = -1
	for moment: Moment in found:
		var rank: int = definition.kind_order.find(moment.kind_id())
		if rank == -1:
			continue
		var higher: bool = best == null or moment.score > best.score + EPSILON
		var tied: bool = best != null and absf(moment.score - best.score) <= EPSILON
		if higher or (tied and rank < best_rank):
			best = moment
			best_rank = rank
	if best != null and best.score >= 1.0 - EPSILON:
		best.fallback = false
		return best
	for moment: Moment in found:
		if moment.kind == Kind.BIGGEST_PAYOUT:
			moment.fallback = true
			return moment
	return null


## Every kind's best case in `history` (Kind order; a kind with none is left out), scored against
## `definition`'s bars.
static func moments(history: Array[ShiftRecord], definition: HighlightDefinition) -> Array[Moment]:
	var found: Array[Moment] = []
	for moment: Moment in [
		_biggest_payout(history, definition),
		_over_quota(history, definition),
		_longest_combo(history, definition),
		_first_golden(history),
		_closest_call(history, definition),
	]:
		if moment != null:
			found.append(moment)
	return found


## The line's text: "Biggest payout · Golden Milk · 264€", "Over quota · Shift 14 · ×2.3",
## "Longest CHAIN · 5 items · 118€", "First GOLDEN · Golden Milk", "Closest call · Shift 9 ·
## 102€ / 101€".
static func text(moment: Moment, definition: HighlightDefinition) -> String:
	var parts: PackedStringArray = PackedStringArray()
	match moment.kind:
		Kind.BIGGEST_PAYOUT:
			parts = [definition.payout_word, moment.card.display_name, "%d€" % moment.amount]
		Kind.OVER_QUOTA:
			parts = [definition.over_quota_word, "Shift %d" % moment.shift, ratio_text(moment)]
		Kind.LONGEST_COMBO:
			parts = [
				"%s %s" % [definition.combo_word, moment.keyword],
				"%d items" % moment.length,
				"%d€" % moment.amount,
			]
		Kind.FIRST_GOLDEN:
			parts = [definition.golden_word, moment.card.display_name]
		Kind.CLOSEST_CALL:
			parts = [
				definition.close_word,
				"Shift %d" % moment.shift,
				"%d€ / %d€" % [moment.total, moment.quota],
			]
	return JOIN.join(parts)


## Over quota's value: the total against the quota, to one decimal ("×2.3").
static func ratio_text(moment: Moment) -> String:
	return "×%.1f" % (float(moment.total) / maxi(moment.quota, 1))


## The `highlight` of the run_end event: the kind, the shift, the value (Biggest payout and
## Longest combo: the euros paid; Over quota: the ratio to 2 decimals; Closest call: the margin;
## First GOLDEN: 0), the item's id when it names one, a combo's keyword and length, and whether it
## is the fallback. {} without a highlight.
static func log_fields(moment: Moment) -> Dictionary:
	if moment == null:
		return {}
	var value: Variant = moment.amount
	match moment.kind:
		Kind.OVER_QUOTA:
			value = snappedf(float(moment.total) / maxi(moment.quota, 1), 0.01)
		Kind.CLOSEST_CALL:
			value = moment.total - moment.quota
		Kind.FIRST_GOLDEN:
			value = 0
	var fields: Dictionary = {
		"kind": moment.kind_id(),
		"shift": moment.shift,
		"value": value,
		"fallback": moment.fallback,
	}
	if moment.card != null:
		fields["card"] = String(moment.card.id)
	if moment.kind == Kind.LONGEST_COMBO:
		fields["keyword"] = moment.keyword
		fields["length"] = moment.length
	return fields


## The shifts every kind reads: played, not a Day off.
static func _counted(history: Array[ShiftRecord]) -> Array[ShiftRecord]:
	return history.filter(func(record: ShiftRecord) -> bool: return not record.day_off)


static func _moment(kind: Kind, record: ShiftRecord) -> Moment:
	var moment: Moment = Moment.new()
	moment.kind = kind
	moment.shift = record.shift
	moment.total = record.total
	moment.quota = record.quota
	return moment


## The biggest single payout (then the later shift), against payout_quota_share of its quota.
static func _biggest_payout(history: Array[ShiftRecord], definition: HighlightDefinition) -> Moment:
	var best: ShiftRecord = null
	for record: ShiftRecord in _counted(history):
		if record.best_card == null or record.best_payout <= 0:
			continue
		if best == null or record.best_payout >= best.best_payout:
			best = record
	if best == null:
		return null
	var moment: Moment = _moment(Kind.BIGGEST_PAYOUT, best)
	moment.card = best.best_card
	moment.amount = best.best_payout
	var bar: float = definition.payout_quota_share * best.quota
	moment.score = best.best_payout / bar if bar > 0.0 else 0.0
	return moment


## The passed shift with the biggest total against its quota (then the later shift), against
## over_quota_ratio.
static func _over_quota(history: Array[ShiftRecord], definition: HighlightDefinition) -> Moment:
	var best: ShiftRecord = null
	for record: ShiftRecord in _counted(history):
		if not record.passed or record.quota <= 0:
			continue
		# record / quota >= best / its quota, in whole numbers.
		if best == null or record.total * best.quota >= best.total * record.quota:
			best = record
	if best == null:
		return null
	var moment: Moment = _moment(Kind.OVER_QUOTA, best)
	var ratio: float = float(best.total) / best.quota
	moment.score = ratio / definition.over_quota_ratio if definition.over_quota_ratio > 0 else 0.0
	return moment


## The longest combo (then the bigger pay, then the later shift), against combo_length.
static func _longest_combo(history: Array[ShiftRecord], definition: HighlightDefinition) -> Moment:
	var best: ShiftRecord = null
	for record: ShiftRecord in _counted(history):
		if record.best_combo_length < MIN_COMBO:
			continue
		if best == null or record.best_combo_length > best.best_combo_length:
			best = record
		elif record.best_combo_length == best.best_combo_length:
			if record.best_combo_pay >= best.best_combo_pay:
				best = record
	if best == null:
		return null
	var moment: Moment = _moment(Kind.LONGEST_COMBO, best)
	moment.keyword = best.best_combo_keyword
	moment.length = best.best_combo_length
	moment.amount = best.best_combo_pay
	var bar: int = definition.combo_length
	moment.score = float(best.best_combo_length) / bar if bar > 0 else 0.0
	return moment


## The first GOLDEN card checked out (the first in its row), always at its bar.
static func _first_golden(history: Array[ShiftRecord]) -> Moment:
	for record: ShiftRecord in _counted(history):
		for card: CardDefinition in record.played:
			if card.tier == CardDefinition.Tier.GOLDEN:
				var moment: Moment = _moment(Kind.FIRST_GOLDEN, record)
				moment.card = card
				moment.score = 1.0
				return moment
	return null


## The passed shift with the smallest margin (then the later shift): at its bar (score 1) when
## it passed by close_margin or less, else CLOSE_MISS_FACTOR × close_margin / margin.
static func _closest_call(history: Array[ShiftRecord], definition: HighlightDefinition) -> Moment:
	var best: ShiftRecord = null
	for record: ShiftRecord in _counted(history):
		if not record.passed:
			continue
		if best == null or record.total - record.quota <= best.total - best.quota:
			best = record
	if best == null:
		return null
	var moment: Moment = _moment(Kind.CLOSEST_CALL, best)
	var margin: int = best.total - best.quota
	if margin <= definition.close_margin:
		moment.score = 1.0
	else:
		moment.score = CLOSE_MISS_FACTOR * definition.close_margin / margin
	return moment
