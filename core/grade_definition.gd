class_name GradeDefinition
extends Resource
## One difficulty grade (#182, decided with the user on 2026-11-23; full build plan 7.5): a rung
## of the ladder a won run climbs. Grade 0 is the game as it is; each grade adds one rule on top
## of the grades below it (GradeApply.balance_for stacks them in ladder order): -1 redraw per
## shift, Shrinkflation, Expiry dates, -1 belt slot, the Picky regular. Its rule changes one
## field of the balance data, or adds a twist (GradeTwist); a field left at -1 keeps what the
## grades below set.
##
## The grades are listed in balance data (BalanceDefinition.grades, data/grades/grade_<n>.tres),
## their place in the list their number.

@export var id: StringName = &""
## The grade's staff title ("SUPERVISOR"), on the grade card.
@export var display_name: String = ""
## The rule this grade adds, in one short line ("-1 redraw per shift"; a leading "-1" shows in
## tomato on the grade card, GradeCard.split_lead), for the grade card's stacked rules and the top
## bar badge's tip. Grade 0's line ("No extra rules") is shown alone.
@export var rule_text: String = ""
## The redraws every shift allows (BalanceDefinition.base_redraws); -1: keep.
@export var base_redraws: int = -1
## The belt's slots (BalanceDefinition.slot_count); -1: keep.
@export var slot_count: int = -1
## The grade's twist (Shrinkflation, Expiry dates, the Picky regular), or none:
## GradeApply.balance_for lists it on the graded balance (BalanceDefinition.twists) and GradeRules
## plays it.
@export var twist: GradeTwist
## Coins a won run at this grade adds to its payout (CoinPayout's grade_coins; +1 a grade).
@export var coin_bonus: int = 0
