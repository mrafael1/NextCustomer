class_name RedrawBonusRule
extends Rule
## The redraw tension (#128 v3): Clearance wants redraws, Snacks want none.
## ScoreState.cards_redrawn is the hand cards this shift's redraws replaced (each redraw a
## basket of BalanceDefinition.basket_size cards, extra redraws included), passed into scoring
## as context, so scoring stays pure. Dented can LEFTOVERS: +2 for each card redrawn
## (`bonus_each`). Crisps IMPULSE: +3 for each redraw the shift has left (`bonus`,
## ScoreState.redraws_left; the user's call of 2026-11-02: a scaling, not a flat +5).

@export var bonus_each: int = 0
@export var bonus: int = 0


func flat_bonus(state: ScoreState, _slot: int) -> int:
	return state.cards_redrawn * bonus_each + state.redraws_left * bonus


func wasted_reason(state: ScoreState, _slot: int) -> String:
	if bonus_each != 0 and state.cards_redrawn == 0:
		return "no card redrawn this shift"
	if bonus != 0 and state.redraws_left <= 0:
		return "no redraw left this shift"
	return ""
