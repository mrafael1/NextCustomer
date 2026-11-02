class_name ChainRoleRule
extends Rule
## A Produce helper's place by a chain (#128, Produce links: only Bananas are the chain, and each
## helper changes what flows down it). A chain is CardChain's: 2 or more Bananas linked one after
## another. Each role works only at its place by the chain, and fizzles (#45) anywhere else: a
## WASTED step that says why.
## - FEED (Strawberries): just before a chain's first Banana, +bonus to every Banana of that
##   chain. Each lands before the Banana's price is set, so it carries down the later links.
## - KNOT (Lemon): between two Bananas, it ties the Banana after it to the Banana before it, for
##   the chain only (CardChain.tie: no other rule sees across it), and that link's chain
##   bonus counts ×factor (AdjacentMatchBonusRule.knot_factor). The knot pays only its base.
## - TALLY (Wonky carrot): just after a chain's last Banana, +bonus for each Banana of the chain.
## A perk that gives a misplaced helper a job of its own (UpgradeRule.spares_waste: Lemon
## squeezer's loose Lemon) clears that helper's fizzle.

enum Role { NONE, FEED, KNOT, TALLY }

@export var role: Role = Role.NONE
## FEED: the bonus each Banana of the chain takes; TALLY: the bonus for each Banana.
@export var bonus: int = 0
## KNOT: what the tied link's chain bonus is multiplied by.
@export var factor: int = 1


func modify_chain(state: ScoreState, slot: int) -> void:
	if role != Role.KNOT or factor <= 1:
		return
	for before: int in state.products_before(slot):
		var card: CardDefinition = state.definition(before)
		if not state.is_product(before) or CardChain.chain_rule(card) == null:
			continue
		for after: int in CardBatch.products_after(state, slot):
			if state.is_product(after) and state.definition(after).is_same_product(card):
				CardChain.tie(state, before, after, slot, factor)


func flat_bonus(state: ScoreState, slot: int) -> int:
	if role != Role.TALLY or bonus == 0:
		return 0
	return CardChain.ending_before(state, slot).size() * bonus


func flat_support(state: ScoreState, slot: int) -> int:
	if role != Role.TALLY:
		return -1
	var chain: PackedInt32Array = CardChain.ending_before(state, slot)
	return chain[-1] if not chain.is_empty() else -1


func on_scanned(state: ScoreState, slot: int) -> void:
	if role != Role.FEED or bonus == 0:
		return
	var chain: PackedInt32Array = CardChain.starting_after(state, slot)
	if not chain.is_empty():
		var text: String = text_for(state.definition(slot))
		state.add_effect(
			SlotsBonusEffect.new(
				slot, text, chain, bonus, "its %s ended early" % CardText.CHAIN_WORD
			)
		)


func wasted_reason(state: ScoreState, slot: int) -> String:
	match role:
		Role.FEED when bonus != 0:
			if CardChain.starting_after(state, slot).is_empty():
				return "no %s just after it" % CardText.CHAIN_WORD
		Role.KNOT when factor > 1:
			if not CardChain.is_knot(state, slot) and not _spared(state, slot):
				return "not inside a %s" % CardText.CHAIN_WORD
		Role.TALLY when bonus != 0:
			if CardChain.ending_before(state, slot).is_empty():
				return "no %s just before it" % CardText.CHAIN_WORD
	return ""


func _spared(state: ScoreState, slot: int) -> bool:
	for upgrade_rule: UpgradeRule in state.upgrade_rules:
		if upgrade_rule.spares_waste(state, slot):
			return true
	return false
