class_name CardChain
extends RefCounted
## A chain (#128, Produce links, the Produce family's verb): 2 or more of one chain product (the
## Banana, any tier: CardDefinition.is_same_product) linked one after another, after the context
## pass. A chain product is one whose card has a chain rule (AdjacentMatchBonusRule's
## `bonus_is_previous_price`). Two of them are linked when one is counted as just before the other
## (ScoreState.products_before: a neighbour, or a connector's link) or when a knot ties them
## (ScoreState.tie_knot: a Lemon between two Bananas, chain-only, so no other rule sees across
## it). Its length is the number of chain products; a knot is inside it but not counted. Where a
## helper sits by the chain is its job (ChainRoleRule): just before its first product, inside it,
## or just after its last.
##
## Static helpers only (no state): the rules that read chains call them on each score's state.

## Products a chain needs at all.
const MIN_SIZE := 2


## The chain holding `slot`, its chain products in slot order (knots left out), or an empty array
## when the slot holds no chain product or is linked to no other.
static func members(state: ScoreState, slot: int) -> PackedInt32Array:
	if not state.is_product(slot) or chain_rule(state.definition(slot)) == null:
		return PackedInt32Array()
	var card: CardDefinition = state.definition(slot)
	var found: PackedInt32Array = PackedInt32Array([slot])
	var at: int = 0
	while at < found.size():
		var linked: PackedInt32Array = state.products_beside(found[at])
		if state.knots != null:
			linked += state.knots.tied_before(found[at]) + state.knots.tied_after(found[at])
		for other: int in linked:
			if not found.has(other) and _is_link(state, card, other):
				found.append(other)
		at += 1
	if found.size() < MIN_SIZE:
		return PackedInt32Array()
	found.sort()
	return found


## The chain whose first product is counted as just after `slot` (its neighbour, or one a
## connector links to it), or an empty array.
static func starting_after(state: ScoreState, slot: int) -> PackedInt32Array:
	for after: int in CardBatch.products_after(state, slot):
		var chain: PackedInt32Array = members(state, after)
		if not chain.is_empty() and chain[0] == after:
			return chain
	return PackedInt32Array()


## The chain whose last product is counted as just before `slot`, or an empty array.
static func ending_before(state: ScoreState, slot: int) -> PackedInt32Array:
	for before: int in state.products_before(slot):
		var chain: PackedInt32Array = members(state, before)
		if not chain.is_empty() and chain[-1] == before:
			return chain
	return PackedInt32Array()


## Records every chain of the row on the score (ScoreState.chains) for the belt, each in slot
## order with the knots tying it, once each, with its knots' factors (ScoreState.knot_factors) and
## the FEED and TALLY helpers at their places by it (ScoreState.chain_feeds, chain_tallies; -1:
## none). Explain path only.
static func record_all(state: ScoreState) -> void:
	if not state.explain:
		return
	var knots: PackedInt32Array = state.knots.slots() if state.knots != null else PackedInt32Array()
	var seen: Dictionary[int, bool] = {}
	for slot: int in range(state.size()):
		if seen.has(slot):
			continue
		var chain: PackedInt32Array = members(state, slot)
		if chain.is_empty():
			continue
		var framed: PackedInt32Array = chain.duplicate()
		for member: int in chain:
			seen[member] = true
		for knot: int in knots:
			if _ties(state, chain, knot) and not framed.has(knot):
				framed.append(knot)
		framed.sort()
		for knot: int in framed:
			if not chain.has(knot):
				state.knot_factors[knot] = state.knots.factor_of(knot)
		state.chains.append(framed)
		state.chain_feeds.append(_helper(state, chain, ChainRoleRule.Role.FEED))
		state.chain_tallies.append(_helper(state, chain, ChainRoleRule.Role.TALLY))


## The products a chain counts as just before `slot`: ScoreState.products_before, plus those a
## knot ties to it (ScoreState.knots). Only the chain reads it.
static func linked_before(state: ScoreState, slot: int) -> PackedInt32Array:
	if state.knots == null:
		return state.products_before(slot)
	return state.products_before(slot) + state.knots.tied_before(slot)


## The products a chain counts as just after `slot` (CardBatch.products_after, plus knots').
static func linked_after(state: ScoreState, slot: int) -> PackedInt32Array:
	var found: PackedInt32Array = CardBatch.products_after(state, slot)
	return found if state.knots == null else found + state.knots.tied_after(slot)


## Chain context: the knot in slot `knot` (with `factor`) ties `before_slot` to `after_slot`.
static func tie(
	state: ScoreState, before_slot: int, after_slot: int, knot: int, factor: int
) -> void:
	if state.knots == null:
		state.knots = ChainKnots.new()
	state.knots.tie(before_slot, after_slot, knot, factor)


## The knot tying `before_slot` to `after_slot` (and only it: they are not also adjacent), or -1.
static func knot_between(state: ScoreState, before_slot: int, after_slot: int) -> int:
	if state.knots == null or state.products_before(after_slot).has(before_slot):
		return -1
	return state.knots.between(before_slot, after_slot)


## Whether a knot in `slot` ties two chain products.
static func is_knot(state: ScoreState, slot: int) -> bool:
	return state.knots != null and state.knots.has(slot)


## The card's chain rule (the Banana's: AdjacentMatchBonusRule with `bonus_is_previous_price`),
## or null.
static func chain_rule(card: CardDefinition) -> AdjacentMatchBonusRule:
	if card == null:
		return null
	for rule: Rule in card.rules:
		var match_rule: AdjacentMatchBonusRule = rule as AdjacentMatchBonusRule
		if match_rule != null and match_rule.bonus_is_previous_price:
			return match_rule
	return null


## The slot of the helper with `role` (FEED or TALLY, with a bonus) at its place by `chain`: just
## before its first product (FEED) or just after its last (TALLY), or -1.
static func _helper(state: ScoreState, chain: PackedInt32Array, role: ChainRoleRule.Role) -> int:
	for slot: int in range(state.size()):
		for rule: Rule in state.definition(slot).rules:
			var helper: ChainRoleRule = rule as ChainRoleRule
			if helper == null or helper.role != role or helper.bonus == 0:
				continue
			var placed: PackedInt32Array = (
				starting_after(state, slot)
				if role == ChainRoleRule.Role.FEED
				else ending_before(state, slot)
			)
			if placed == chain:
				return slot
	return -1


## Whether `other` holds a chain product of the same product as `card`.
static func _is_link(state: ScoreState, card: CardDefinition, other: int) -> bool:
	return state.is_product(other) and state.definition(other).is_same_product(card)


## Whether the knot in `knot` ties two products of `chain`.
static func _ties(state: ScoreState, chain: PackedInt32Array, knot: int) -> bool:
	for later: int in chain:
		for earlier: int in chain:
			if earlier < later and state.knots.between(earlier, later) == knot:
				return true
	return false
