class_name CapsuleDraw
extends RefCounted
## One capsule from an aisle's TOY MACHINE (full build plan 7.1, #63): the aisle's key item
## (capsule_cards[0]) while it is locked, then a random item among those left, never a
## duplicate. Pure and static: the RNG is passed in (the profile's capsule stream, made outside
## core/ by EventLogService.capsule_stream; the balance simulator's chain stream), and it is used
## only for a random pick: one randi_range per draw after the key item, none for the key item or
## an empty machine. The balance simulator draws through here too, so its chained runs use the
## RNG exactly as before.


## The aisle's capsule items not unlocked yet, in data order.
static func items_left(
	aisle: AisleDefinition, unlocked: Dictionary[StringName, int]
) -> Array[CardDefinition]:
	var left: Array[CardDefinition] = []
	for card: CardDefinition in aisle.capsule_cards:
		if not unlocked.has(card.id):
			left.append(card)
	return left


## Whether the machine has nothing left: its collection is complete.
static func is_empty(aisle: AisleDefinition, unlocked: Dictionary[StringName, int]) -> bool:
	return items_left(aisle, unlocked).is_empty()


## One capsule: the key item while it is locked (no RNG use), otherwise
## items_left[rng.randi_range(0, size - 1)]. Null when the machine is empty (no RNG use).
## Changes nothing: the caller records the item.
static func draw(
	aisle: AisleDefinition, unlocked: Dictionary[StringName, int], rng: RandomNumberGenerator
) -> CardDefinition:
	var left: Array[CardDefinition] = items_left(aisle, unlocked)
	if left.is_empty():
		return null
	var key_item: CardDefinition = aisle.capsule_cards[0]
	if not unlocked.has(key_item.id):
		return key_item
	return left[rng.randi_range(0, left.size() - 1)]


## Every capsule item of the balance's aisles (the FIGURINES total).
static func capsule_count(balance: BalanceDefinition) -> int:
	var count: int = 0
	for aisle: AisleDefinition in balance.aisles:
		count += aisle.capsule_cards.size()
	return count
