class_name RuleReach
extends RefCounted
## Which belt items a card's rule counts for one family it names (tickets v5, the works-with
## chip's tip): the rule's direction read from its own fields, then the items' tags (granted and
## gained families included). Milk's "+2 per earlier Breakfast" reaches every earlier Breakfast
## item, Coffee's "+3 to the next Breakfast" the first later one, Eggs' "×2 next Food" the next
## `charges` Food items, a "beside" rule its neighbours, a "right after" rule the item before it,
## Birthday candles the batch just after them and a batch role its own batch. A rule whose reach
## is the whole row (a spread, MORNING) reaches every item of the family, as does a card with
## no rule naming the family; a tag grant (Breakfast sticker) reaches the product in the next
## slot.
##
## Presentation only, like CardAffinity: it never scores, and it reads the order the player set,
## not the score (which pays is EffectGraph's). Coupons are never reached.

enum Direction { NONE, EARLIER, NEXT, NEXT_SLOT, BEFORE, BESIDE, BATCH_AFTER, BATCH, ROW }

## The tip's "nothing matches" line for each direction.
const NONE_TEXT: Dictionary[Direction, String] = {
	Direction.EARLIER: "No %s item before it on the belt",
	Direction.NEXT: "No %s item after it on the belt",
	Direction.NEXT_SLOT: "No product in the next slot to take %s",
	Direction.BEFORE: "No %s item right before it",
	Direction.BESIDE: "No %s item beside it",
	Direction.BATCH_AFTER: "No %s batch right after it",
	Direction.BATCH: "No other %s item in its batch",
	Direction.ROW: "No other %s item on the belt",
}

## The direction of the card's first rule naming `family` (ROW when none does).
var direction: Direction = Direction.NONE
## The reached belt slots, ascending.
var slots: PackedInt32Array = PackedInt32Array()


## What `definition` (at belt `slot`) reaches for `family` on a belt of `tags` (one per slot) whose
## products are `products` (true for a product, false for a coupon or an empty slot).
static func of(
	definition: CardDefinition,
	slot: int,
	family: String,
	tags: Array[PackedStringArray],
	products: Array[bool]
) -> RuleReach:
	var reach: RuleReach = RuleReach.new()
	var found: Dictionary[int, bool] = {}
	for rule: Rule in definition.rules:
		var rule_direction: Direction = _direction(rule, family)
		if rule_direction == Direction.NONE:
			continue
		if reach.direction == Direction.NONE:
			reach.direction = rule_direction
		for other: int in _reached(rule, rule_direction, slot, family, tags, products):
			found[other] = true
	if reach.direction == Direction.NONE:
		reach.direction = Direction.ROW
		for other: int in _reached(null, Direction.ROW, slot, family, tags, products):
			found[other] = true
	var keys: Array[int] = found.keys()
	keys.sort()
	reach.slots = PackedInt32Array(keys)
	return reach


## The tip's line when nothing is reached, for `family_name`.
func none_text(family_name: String) -> String:
	return NONE_TEXT.get(direction, NONE_TEXT[Direction.ROW]) % family_name


static func _direction(rule: Rule, family: String) -> Direction:
	var grant: GrantTagToNextSlotRule = rule as GrantTagToNextSlotRule
	if grant != null:
		return Direction.NEXT_SLOT if _same(grant.tag, family) else Direction.NONE
	var adjacent: AdjacentMatchBonusRule = rule as AdjacentMatchBonusRule
	if adjacent != null:
		if adjacent.match_by != AdjacentMatchBonusRule.Match.TAG:
			return Direction.NONE
		if not _same(adjacent.match_value, family):
			return Direction.NONE
		if adjacent.position == AdjacentMatchBonusRule.Position.IMMEDIATELY_AFTER:
			return Direction.BEFORE
		return Direction.BESIDE
	var zeroed: ZeroPayoutBesideTagRule = rule as ZeroPayoutBesideTagRule
	if zeroed != null:
		return Direction.BESIDE if _same(zeroed.tag, family) else Direction.NONE
	if not _same(CardAffinity.family_of(rule), family):
		return Direction.NONE
	if rule is CountEarlierTagBonusRule:
		return Direction.EARLIER
	if rule is GrantNextTagBonusRule or rule is GrantChargedMultiplierRule:
		return Direction.NEXT
	if rule is PairBonusRule:
		return Direction.BESIDE
	if rule is BakedBatchBonusRule:
		return Direction.BATCH_AFTER
	if rule is BatchRoleRule:
		return Direction.BATCH
	return Direction.ROW


static func _reached(
	rule: Rule,
	direction_of: Direction,
	slot: int,
	family: String,
	tags: Array[PackedStringArray],
	products: Array[bool]
) -> PackedInt32Array:
	var reached: PackedInt32Array = PackedInt32Array()
	var order: PackedInt32Array = PackedInt32Array()
	for other: int in range(mini(tags.size(), products.size())):
		if products[other] or other == slot:
			order.append(other)
	var at: int = order.find(slot)
	var has: Callable = func(other: int) -> bool:
		return other != slot and products[other] and CardAffinity.in_family(tags[other], family)
	match direction_of:
		Direction.EARLIER:
			for other: int in order:
				if other < slot and has.call(other):
					reached.append(other)
		Direction.NEXT:
			var charges: int = 1
			var charged: GrantChargedMultiplierRule = rule as GrantChargedMultiplierRule
			if charged != null:
				charges = maxi(charged.charges, 1)
			for other: int in order:
				if reached.size() < charges and other > slot and has.call(other):
					reached.append(other)
		Direction.NEXT_SLOT:
			if slot + 1 < products.size() and products[slot + 1]:
				reached.append(slot + 1)
		Direction.BEFORE:
			if at > 0 and has.call(order[at - 1]):
				reached.append(order[at - 1])
		Direction.BESIDE:
			for step: int in [-1, 1]:
				var index: int = at + step
				if at >= 0 and index >= 0 and index < order.size() and has.call(order[index]):
					reached.append(order[index])
		Direction.BATCH_AFTER:
			var index: int = at + 1
			while at >= 0 and index < order.size() and has.call(order[index]):
				reached.append(order[index])
				index += 1
		Direction.BATCH:
			for step: int in [-1, 1]:
				var index: int = at + step
				while at >= 0 and index >= 0 and index < order.size() and has.call(order[index]):
					reached.append(order[index])
					index += step
		_:
			for other: int in order:
				if has.call(other):
					reached.append(other)
	return reached


static func _same(tag: String, family: String) -> bool:
	return not tag.is_empty() and tag.to_lower() == family.to_lower()
