class_name AdjacentMatchBonusRule
extends Rule
## A flat bonus when a matching product is adjacent, after the context pass.
## Cheese: +4 if immediately after Bread. Frozen peas: + its base if beside another Frozen
## product. Banana (the chain, #106, `bonus_is_previous_price`): + the previous Banana's price
## if immediately after another Banana, so 4 Bananas pay 2, 4, 6, 8; the Golden Banana adds it
## twice (`bonus_factor` 2). With no match it fizzles (#45): a WASTED step
## that names what was missing, the total unchanged. A pair rule (one matching its own product,
## SAME_CARD: the Banana and its tiers) fizzles only when no match is on EITHER side, so the
## pair's first Banana never shows WASTED: only a lone one does ("no Banana beside it"). Its
## bonus still needs the match just before it. With `per_match` (Carrier bag, #128) the bonus
## counts once for each matching product in the position (+8 for each Food product beside it).
## With `pair` (#128, Dairy's PAIR) a match beside it makes the product PAIRED (CardPairs), which
## Cream counts; its sticker names the PAIR keyword.

enum Match { NONE, SAME_CARD, CARD_ID, TAG }
enum Position { NONE, IMMEDIATELY_AFTER, BESIDE }

@export var match_by: Match = Match.NONE
## The card id (CARD_ID) or tag (TAG) to match. Unused for SAME_CARD.
@export var match_value: String = ""
@export var position: Position = Position.NONE
@export var bonus: int = 0
## If true, the bonus is the card's own base value instead of `bonus`.
@export var bonus_is_base: bool = false
## How many times the bonus counts (1: once). Golden Banana's chain bonus counts twice.
@export var bonus_factor: int = 1
## If true (the Banana chain, #106), the bonus is the matching product's price just before this
## card (counted `bonus_factor` times) instead of `bonus` or the base. That price is the
## chain's first product's final payout, multipliers included, or, further down the chain (a
## product that itself has a match just before it), its value before multipliers: a multiplier
## reaching the middle of a chain pays once and never carries to the next link. Meant for a
## same-product IMMEDIATELY_AFTER rule; anything between two matches starts a new chain, except a
## knot (#128, the Lemon: ChainRoleRule KNOT), which ties the Banana before it to the one after it
## for the chain only and multiplies that link's bonus by its factor (a flat bonus, so it carries).
@export var bonus_is_previous_price: bool = false
## If true (Carrier bag, #128), the bonus counts once for each matching product in `position`
## (a product counted beside it twice, by a link, counts once). Not with
## `bonus_is_previous_price`.
@export var per_match: bool = false
## If true (#128 Dairy), a match in `position` makes this product PAIRED (CardPairs).
@export var pair: bool = false


func flat_bonus(state: ScoreState, slot: int) -> int:
	if bonus_is_previous_price:
		var previous: int = previous_match(state, slot)
		if previous < 0:
			return 0
		state.chained[slot] = 1
		return chain_price(state, previous) * bonus_factor * knot_factor(state, previous, slot)
	if per_match:
		return _match_count(state, slot) * bonus_for(state.definition(slot).base)
	if not _has_match_at(state, slot, position):
		return 0
	return bonus_for(state.definition(slot).base)


func flat_support(state: ScoreState, slot: int) -> int:
	if bonus_is_previous_price:
		return previous_match(state, slot)
	var neighbours: PackedInt32Array = (
		state.products_beside(slot) if position == Position.BESIDE else state.products_before(slot)
	)
	for other: int in neighbours:
		if _matches(state, state.definition(slot), other):
			return other
	return -1


## Whether the product in `slot` has its partner in `position` (a PAIR when `pair`, #128).
func is_paired(state: ScoreState, slot: int) -> bool:
	return _has_match_at(state, slot, position)


## The partners the product in `slot` finds in `position` (its PAIR's other side, #128: the belt's
## PAIR clasps), in row order.
func partners(state: ScoreState, slot: int) -> PackedInt32Array:
	var found: PackedInt32Array = PackedInt32Array()
	if position == Position.NONE or match_by == Match.NONE:
		return found
	var card: CardDefinition = state.definition(slot)
	for other: int in _neighbours(state, slot, position):
		if _matches(state, card, other):
			found.append(other)
	found.sort()
	return found


## Explain path only (Scoring._report_fizzles). A rule paying nothing on a match (neutral
## numbers) never fizzles.
func wasted_reason(state: ScoreState, slot: int) -> String:
	if position == Position.NONE or match_by == Match.NONE:
		return ""
	if not _pays_on_match(state.definition(slot).base):
		return ""
	# A link a perk chained (Banana stand, #108) took its chain bonus.
	if bonus_is_previous_price and state.chained[slot] == 1:
		return ""
	var fizzle_position: Position = _fizzle_position()
	if _has_match_at(state, slot, fizzle_position):
		return ""
	var where: String = (
		"right before it" if fizzle_position == Position.IMMEDIATELY_AFTER else "beside it"
	)
	return "no %s %s" % [_match_name(state, slot), where]


## The bonus paid on a match by a card with this base value: its base when the bonus is the
## base, else `bonus`, counted `bonus_factor` times.
func bonus_for(base: int) -> int:
	return (base if bonus_is_base else bonus) * bonus_factor


## Whether a match pays anything for a card with this base (a rule with neutral numbers never
## does, so it never fizzles).
func _pays_on_match(base: int) -> bool:
	return bonus_factor != 0 if bonus_is_previous_price else bonus_for(base) != 0


## The price a chain link passes on (#106): a link's value before multipliers (its price,
## ScoreState.prices), or the chain's first product's final payout. A link is a slot that took a
## chain bonus (ScoreState.chained: its own, or Banana stand's, #108).
static func chain_price(state: ScoreState, link: int) -> int:
	return state.prices[link] if state.chained[link] == 1 else state.payouts[link]


## The factor a knot multiplies the chain bonus by (#128, the Lemon knot: ×2, Golden ×3) when
## `previous` is tied to `slot` by one only (CardChain.knot_between), else 1.
static func knot_factor(state: ScoreState, previous: int, slot: int) -> int:
	var knot: int = CardChain.knot_between(state, previous, slot)
	return state.knots.factor_of(knot) if knot >= 0 else 1


## The nearest already-scanned product matching the card in `slot` counted as just before it
## (`position`), or -1 for none. A chain (`bonus_is_previous_price`) also counts a product a knot
## ties to it (CardChain.linked_before, #128).
func previous_match(state: ScoreState, slot: int) -> int:
	if position == Position.NONE or match_by == Match.NONE:
		return -1
	var neighbours: PackedInt32Array = _neighbours(state, slot, position)
	var card: CardDefinition = state.definition(slot)
	var found: int = -1
	for other: int in neighbours:
		if other < slot and other > found and _matches(state, card, other):
			found = other
	return found


## Where a match spares the card its fizzle: the bonus's own position, except for a pair rule
## (SAME_CARD), which counts a match on either side (#45: only a lone Banana is WASTED).
func _fizzle_position() -> Position:
	return Position.BESIDE if match_by == Match.SAME_CARD else position


## Whether a product matching the card in `slot` is just before it or beside it (`where`).
func _has_match_at(state: ScoreState, slot: int, where: Position) -> bool:
	if where == Position.NONE or match_by == Match.NONE:
		return false
	var neighbours: PackedInt32Array = _neighbours(state, slot, where)
	var card: CardDefinition = state.definition(slot)
	for other: int in neighbours:
		if _matches(state, card, other):
			return true
	return false


## The products counted as just before `slot` or beside it (`where`); a chain's
## (`bonus_is_previous_price`) also count the products a knot ties to it (#128).
func _neighbours(state: ScoreState, slot: int, where: Position) -> PackedInt32Array:
	if bonus_is_previous_price:
		if where == Position.BESIDE:
			return CardChain.linked_before(state, slot) + CardChain.linked_after(state, slot)
		return CardChain.linked_before(state, slot)
	return state.products_beside(slot) if where == Position.BESIDE else state.products_before(slot)


## How many different products matching the card in `slot` are in `position`.
func _match_count(state: ScoreState, slot: int) -> int:
	if position == Position.NONE or match_by == Match.NONE:
		return 0
	var neighbours: PackedInt32Array = (
		state.products_beside(slot) if position == Position.BESIDE else state.products_before(slot)
	)
	var card: CardDefinition = state.definition(slot)
	var counted: Dictionary[int, bool] = {}
	for other: int in neighbours:
		if _matches(state, card, other):
			counted[other] = true
	return counted.size()


## What a match is, for the fizzle's reason: "Banana" (the same product), "Bread" (a card id,
## capitalized: a data test checks it is that card's display name) or "Bakery product" (a tag).
func _match_name(state: ScoreState, slot: int) -> String:
	match match_by:
		Match.SAME_CARD:
			return state.definition(slot).product_card().display_name
		Match.CARD_ID:
			return match_value.capitalize()
	return "%s item" % match_value


## Whether the product in `other` matches `card` (the card in the slot looking for a match).
func _matches(state: ScoreState, card: CardDefinition, other: int) -> bool:
	if not state.is_product(other):
		return false
	match match_by:
		Match.SAME_CARD:
			return state.definition(other).is_same_product(card)
		Match.CARD_ID:
			# A variant counts as its base card (plan section 3, "same product").
			return String(state.definition(other).product_card().id) == match_value
		Match.TAG:
			return state.has_tag(other, match_value)
	return false
