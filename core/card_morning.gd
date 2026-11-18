class_name CardMorning
extends RefCounted
## MORNING (#128, Breakfast's identity; the MORNING ZONE since the user's call of 2026-11-18): a
## product with the tag (Breakfast) standing in one of the row's first slots (MorningZone.slots,
## balance data) is a MORNING item. Nothing else counts: no run, no first-slot condition. A coupon
## in the zone just takes its slot, and a product without the tag there is no MORNING item (the
## Breakfast sticker's tag counts, ScoreState.has_tag). The zone is the row's own first slots,
## whatever the shift's events do to the row's end (Short belt) or to a slot's pay (Spot check).
## Read after the context pass; it depends only on the row, so every rule sees the same items.


## The MORNING items' slots, in row order (empty with no zone or no tagged product in it).
static func slots(state: ScoreState, tag: String, zone: MorningZone) -> PackedInt32Array:
	var found: PackedInt32Array = PackedInt32Array()
	if tag.is_empty() or zone == null:
		return found
	for slot: int in range(mini(zone.slots, state.size())):
		if state.is_product(slot) and state.has_tag(slot, tag):
			found.append(slot)
	return found


## The MORNING items the belt lights: their slots when a card in the row reads MORNING (a
## MorningCountRule, or a GrantChargedMultiplierRule with a `morning_zone`), the first such rule's
## tag and zone; empty otherwise.
static func read(state: ScoreState) -> PackedInt32Array:
	for slot: int in range(state.size()):
		for rule: Rule in state.definition(slot).rules:
			if zone_of_rule(rule) != null:
				return slots(state, tag_of_rule(rule), zone_of_rule(rule))
	return PackedInt32Array()


## The zone `cards` read (the first MORNING card's), or null when none reads MORNING: the belt
## prints the zone only for a cart that holds such a card.
static func zone_of(cards: Array[CardDefinition]) -> MorningZone:
	for card: CardDefinition in cards:
		if card == null:
			continue
		for rule: Rule in card.rules:
			var zone: MorningZone = zone_of_rule(rule)
			if zone != null:
				return zone
	return null


## The zone `rule` reads, or null: a rule that reads MORNING has a tag and a zone of 1 slot or more.
static func zone_of_rule(rule: Rule) -> MorningZone:
	var zone: MorningZone = null
	var count_rule: MorningCountRule = rule as MorningCountRule
	var grant_rule: GrantChargedMultiplierRule = rule as GrantChargedMultiplierRule
	if count_rule != null:
		zone = count_rule.zone
	elif grant_rule != null:
		zone = grant_rule.morning_zone
	if zone == null or zone.slots <= 0 or tag_of_rule(rule).is_empty():
		return null
	return zone


## The tag of a rule that reads MORNING ("" for any other rule).
static func tag_of_rule(rule: Rule) -> String:
	var count_rule: MorningCountRule = rule as MorningCountRule
	if count_rule != null:
		return count_rule.tag
	var grant_rule: GrantChargedMultiplierRule = rule as GrantChargedMultiplierRule
	if grant_rule != null and grant_rule.morning_zone != null:
		return grant_rule.tag
	return ""
