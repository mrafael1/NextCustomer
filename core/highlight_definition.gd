class_name HighlightDefinition
extends Resource
## The final receipt's BEST line (v1.37, the approved direction A of
## docs/art/mockups/receipt_highlight.html): the bars a run's moments are measured against, which
## kinds take part in the pick and in what order, and their words. One file,
## data/balance/highlight.tres, referenced from BalanceDefinition.highlight; RunHighlight reads
## it. A moment's score is its value against its kind's bar, so a score of 1 meets the bar.

## The kinds in the automatic pick, highest first (RunHighlight.KIND_IDS: "biggest_payout",
## "over_quota", "longest_combo", "first_golden", "closest_call"). On equal scores the kind listed
## first wins. A kind left out never takes part, except Biggest payout as the fallback.
@export var kind_order: PackedStringArray = PackedStringArray()
## Biggest payout meets its bar at this share of its shift's quota (0.5: half the quota).
@export var payout_quota_share: float = 0.0
## Over quota meets its bar at this many times the quota (2.0: twice the quota).
@export var over_quota_ratio: float = 0.0
## Longest combo (a CHAIN, BATCH or MORNING) meets its bar at this many items.
@export var combo_length: int = 0
## Closest call meets its bar when a shift passed by this many euros or fewer.
@export var close_margin: int = 0
## The kinds' words on the receipt (the line reads "<word> · <subject> · <value>").
@export var payout_word: String = ""
@export var over_quota_word: String = ""
## Followed by the combo's keyword ("Longest CHAIN").
@export var combo_word: String = ""
@export var golden_word: String = ""
@export var close_word: String = ""
